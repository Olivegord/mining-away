#!/usr/bin/env python3
"""Save the scoped Studio courtyard, surface finishes and lighting grade."""
import argparse
from collections import defaultdict
from hashlib import sha256
import json
from pathlib import Path
import re
import struct

from build import CANONICAL_OUTPUT, chunk, chunks, packstr, script_inventory, string, u32
from import_lighting import append_model, pack_words, words
from refresh_native_scenery import (
    MAP, TERRACES, Native, close, pack_vectors, patch_parts, read_section, unpack_vectors,
    write_snapshot,
)
from refresh_quarry_blockscape import append_export

VARIANTS = {f"QuarryCourtyard_{name}" for name in ("Turf", "Garden", "Brick", "RoseStone")}
PROPERTIES = {
    "Lighting": {"Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient", "ColorShift_Top"},
    "Lighting.ColorCorrection": {"Contrast", "Saturation"},
    "Lighting.Bloom": {"Intensity"},
    MAP + ".QuarryLanterns.WarmLamp.LocalGlow": {"Brightness"},
}
PARTS = (
    re.escape(MAP) + r"\.SimpleFlatTestMap\.HubPad",
    re.escape(TERRACES) + r"MarketGardens\.GardenSoil",
    re.escape(TERRACES) + r"MarketSquare\.(?:EastWestWalk|NorthSouthWalk|UtilityWalk|ShopApron)",
    re.escape(TERRACES) + r"LogisticsApron\.ServiceDeck",
    re.escape(MAP) + r"\.QuarryContinuousGround\.Terraces\.(?:Quartz|Impact|Ruby|Cobalt|Violet|Emerald)\.(?:Turf|Earth)\d+",
    re.escape(MAP) + r"\.QuarryBlockRim\.(?:WestEscarpment|NorthCrown|EastChalkRim|SouthwestGate|SoutheastGate)\.BasalRock",
    re.escape(MAP) + r"\.QuarryMotifScenery\.(?:Hub|Quartz|Impact|Ruby|Cobalt|Violet|Emerald)\.(?:BrickLow|RoseCube)",
    r"Workspace\.MiningAway\.Fields\.(?:Quartz|ImpactTest|Ruby|Cobalt|Violet|Emerald)\.Field",
)


def validate_finish(edit):
    assert any(re.fullmatch(pattern, edit["path"]) for pattern in PARTS), edit["path"]
    assert edit["before"].keys() == edit["after"].keys() == {"color", "variant"}
    assert edit["after"]["variant"] in VARIANTS | {edit["before"]["variant"], "QuarryField_Aggregate"}


def pack_floats(values):
    # The native format rotates the sign bit to the least significant bit.
    bits = (struct.unpack(">I", struct.pack(">f", f))[0] for f in values)
    return pack_words([((x << 1) | (x >> 31)) & 0xffffffff for x in bits])


def unpack_floats(data, count):
    bits = ((x >> 1) | ((x & 1) << 31) for x in words(data, count))
    return [struct.unpack(">f", struct.pack(">I", x))[0] for x in bits]


def patch_lighting(base, edits):
    expected = {(path, key) for path, names in PROPERTIES.items() for key in names}
    assert len(edits) == len(expected) and {(e["path"], e["property"]) for e in edits} == expected
    updates = defaultdict(dict)
    for e in edits:
        matches = base.paths[e["path"]]
        assert len(matches) == e["count"] == (12 if e["path"].endswith(".LocalGlow") else 1)
        for ref in matches:
            cid, _, index, _ = base.instances[ref]
            updates[cid, e["property"]][index] = (e["before"], e["after"])
    result = [base.data[:32]]
    written = set()
    for kind, payload, raw in base.chunks:
        if kind == b"PROP":
            cid = u32(payload)
            name, offset = string(payload, 4)
            key = (cid, name)
            if key in updates:
                dtype = payload[offset]
                count = len(base.classes[cid][1])
                assert dtype in (4, 12) and key not in written
                values = unpack_vectors(payload[offset+1:], count) if dtype == 12 else unpack_floats(payload[offset+1:], count)
                for i, (old, new) in updates[key].items():
                    assert close(values[i], old) if dtype == 12 else abs(values[i]-old)<.00001, (name, i)
                    values[i] = new
                encoded = pack_vectors(values) if dtype == 12 else pack_floats(values)
                raw = chunk(kind, payload[:offset+1] + encoded)
                written.add(key)
        result.append(raw)
    assert written == updates.keys()
    return b"".join(result), written


def merge(data, directory):
    original = Native(data)
    edits = json.loads(read_section(directory, "edits"))
    result, finish_keys = patch_parts(original, edits["parts"], contrast=True, validate_edit=validate_finish)
    result, light_keys = patch_lighting(Native(result), edits["properties"])
    result = append_export(result, directory, "scenery", MAP, "QuarryCourtyard", {"Folder", "Part", "Texture"})
    # Each variant is a separate root in this native export.
    model = read_section(directory, "variants")
    imported = Native(model)
    assert {imported.instances[ref][3] for ref, parent in imported.parents.items() if parent < 0} == VARIANTS
    assert len(imported.instances) == len(VARIANTS)
    assert all(cls == "MaterialVariant" for cls, _ in imported.classes.values())
    current = Native(result)
    assert not any("MaterialService." + name in current.paths for name in VARIANTS)
    final = Native(append_model(result, model, current.one("MaterialService"), chunks, chunk, u32, string, packstr))
    assert original.instances.items() <= final.instances.items()
    assert original.parents.items() <= final.parents.items()
    assert {key for key, value in original.props.items() if final.props[key] != value} <= finish_keys | light_keys
    sources = script_inventory(final.chunks)
    assert script_inventory(original.chunks) == sources
    return final.data, {"surface_edits": len(edits["parts"]), "lighting_properties": len(edits["properties"]),
                        "new_instances": len(final.instances)-len(original.instances), "preserved_sources": len(sources)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, "Canonical file changed"
    result, stats = merge(data, args.export_dir)
    if args.write:
        write_snapshot(data, result)
    print(json.dumps({**stats, "wrote": args.write, "sha256": sha256(result).hexdigest()}, indent=2))


if __name__ == "__main__":
    main()
