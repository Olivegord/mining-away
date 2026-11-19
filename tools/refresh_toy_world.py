#!/usr/bin/env python3
"""Mirror tools/studio_toy_world.lua into the canonical native file.

Appends Workspace.MiningAway.Map.ToyWorld and ServerStorage.ToyWorldArchive,
moves only the allowlisted props into the archive, and recolors only the
allowlisted gameplay parts (geometry unchanged). Every other instance and
Source is kept byte-identical. Dry run by default; --write replaces
build/DRONE_GAME.rbxl after the checks.
"""
import argparse
from hashlib import sha256
import json
import math
from pathlib import Path
import struct

from build import CANONICAL_OUTPUT, chunk, chunks, packstr, script_inventory, string, u32
from import_lighting import append_model
from refresh_calm_scenery import pack_floats, unpack_floats
from refresh_native_scenery import Native, patch_parts, read_section, write_parents, write_snapshot

MAP = "Workspace.MiningAway.Map"
SCENERY = "ToyWorld"
ARCHIVE = "ToyWorldArchive"
SCENERY_CLASSES = {"Folder", "Part", "Attachment", "ParticleEmitter", "PointLight"}
MOVES = {
    "Workspace.MiningAway.Fields.CrystalRun": "Folder",
    MAP + ".MineralLineup": "Folder",
    MAP + ".DepotStationPlates": "Folder",
    MAP + ".ShopSignPosts": "Folder",
    "Workspace.MiningAway.Fields.Baseplate.Texture": "Texture",
    MAP + ".SimpleFlatTestMap.HubPad.MiningAwayChecker": "Texture",
    "Lighting.Sky": "Sky",
    "Lighting.Atmosphere": "Atmosphere",
}
LIGHTING = {"TimeOfDay": 0x01, "Brightness": 0x04, "ExposureCompensation": 0x04, "Ambient": 0x0C, "OutdoorAmbient": 0x0C}
RECOLOR = {
    "Workspace.MiningAway.Fields.Baseplate",
    MAP + ".CrystalRun.FlatGround",
    MAP + ".SimpleFlatTestMap.HubPad",
    MAP + ".SimpleFlatTestMap.PackStationAssembly.PackStationPad",
    MAP + ".SimpleFlatTestMap.PackStationAssembly.PackStation",
    MAP + ".SimpleFlatTestMap.PrinterAssembly.PrinterPad",
    MAP + ".SimpleFlatTestMap.PrinterAssembly.Printer",
    MAP + ".SimpleFlatTestMap.PrestigeStationAssembly.PrestigeStationPad",
    MAP + ".SimpleFlatTestMap.PrestigeStationAssembly.PrestigeStation",
    "Workspace.Converter",
    MAP + ".CrystalRun.ChargingStation",
    MAP + ".QuartzShop.QuartzCounter.Base",
    MAP + ".QuartzShop.QuartzCounter.Top",
    MAP + ".QuartzShop.ShopSign",
    MAP + ".RubyShop.StarCounter.Base",
    MAP + ".RubyShop.StarCounter.Top",
    MAP + ".RubyShop.ShopSign",
} | {f"{MAP}.CrystalRun.{name}.Field" for name in ("Quartz", "Ruby", "Cobalt", "Violet", "Emerald")}


def check_edit(edit):
    assert edit["path"] in RECOLOR, f"Recolor outside the allowlist: {edit['path']}"
    assert edit["class"] == "Part" and edit["before"].keys() == edit["after"].keys() == {"color"}, edit


def append(data, directory, name, parent, root, allowed):
    model = read_section(directory, name)
    assert model.startswith(b"<roblox!\x89\xff\r\n\x1a\n"), "Expected Studio's native binary model export"
    export = Native(model)
    roots = [ref for ref, p in export.parents.items() if p < 0]
    assert [export.instances[ref][3] for ref in roots] == [root], f"{name} must contain only {root}"
    assert {cls for cls, _ in export.classes.values()} <= allowed, f"Unexpected classes in {name}"
    native = Native(data)
    assert parent + "." + root not in native.paths, f"{parent}.{root} already exists"
    return append_model(data, model, native.one(parent), chunks, chunk, u32, string, packstr), len(export.instances)


def patch_lighting(data, plan):
    """Replace five Lighting properties after checking their old values."""
    native = Native(data)
    (cid,) = [c for c, (cls, ids) in native.classes.items() if cls == "Lighting"]
    assert len(native.classes[cid][1]) == 1
    assert plan["before"].keys() == plan["after"].keys() == LIGHTING.keys(), plan
    replacements = {}
    for name, dtype in LIGHTING.items():
        raw = native.prop(cid, name, dtype)
        before, after = plan["before"][name], plan["after"][name]
        if dtype == 0x01:
            assert string(raw, 0)[0] == before, (name, raw)
            value = packstr(after)
        elif dtype == 0x04:
            assert math.isclose(unpack_floats(raw, 1)[0], before, abs_tol=1e-4), name
            value = pack_floats([after])
        else:
            old = [unpack_floats(raw[i * 4:(i + 1) * 4], 1)[0] for i in range(3)]
            assert all(math.isclose(a, b, abs_tol=2e-3) for a, b in zip(old, before)), (name, old, before)
            value = b"".join(pack_floats([c]) for c in after)
        replacements[name] = chunk(b"PROP", struct.pack("<I", cid) + packstr(name) + bytes([dtype]) + value)
    out = [native.data[:32]]
    for kind, decoded, raw in native.chunks:
        if kind == b"PROP" and u32(decoded) == cid:
            raw = replacements.get(string(decoded, 4)[0], raw)
        out.append(raw)
    return b"".join(out), {(cid, name) for name in LIGHTING}


def merge(data, directory):
    original = Native(data)
    moves = json.loads(read_section(directory, "moves"))
    edits = json.loads(read_section(directory, "edits"))
    assert {m["path"]: m["class"] for m in moves} == MOVES, "Archive plan differs from the allowlist"
    assert {e["path"] for e in edits} == RECOLOR, "Recolor plan differs from the allowlist"
    descendants = {}
    for ref, parent in original.parents.items():
        descendants.setdefault(parent, []).append(ref)

    def count(ref):
        return sum(1 + count(child) for child in descendants.get(ref, []))

    moved = []
    for m in moves:
        ref = original.one(m["path"])
        assert original.instances[ref][1] == m["class"], m
        assert count(ref) == m["descendants"], f"Unreconciled descendants under {m['path']}"
        moved.append(ref)
    result, touched = patch_parts(original, edits, validate_edit=check_edit)
    result, lit = patch_lighting(result, json.loads(read_section(directory, "lighting")))
    touched |= lit
    result, scenery_count = append(result, directory, "scenery", MAP, SCENERY, SCENERY_CLASSES)
    result, _ = append(result, directory, "archive", "ServerStorage", ARCHIVE, {"Folder"})
    result, _ = append(result, directory, "sky", "Lighting", "ToyWorldSky", {"Sky"})
    result, _ = append(result, directory, "air", "Lighting", "ToyWorldAir", {"Atmosphere"})
    native = Native(result)
    target = native.one("ServerStorage." + ARCHIVE)
    relocated = dict.fromkeys(moved, target)
    final = Native(write_parents(native, {**native.parents, **relocated}))
    # No original instance was rewritten, only the listed colors changed,
    # only the listed roots moved, and every Source is untouched.
    assert original.instances.items() <= final.instances.items()
    assert touched == {key for key, value in original.props.items() if final.props[key] != value}
    assert all(final.parents[ref] == relocated.get(ref, p) for ref, p in original.parents.items())
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    for path in RECOLOR:
        final.one(path)
    return final.data, {
        "archived_roots": len(moved),
        "recolored_parts": len(edits),
        "new_instances": scenery_count + 1,
        "preserved_sources": len(script_inventory(final.chunks)),
    }


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
