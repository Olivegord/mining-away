#!/usr/bin/env python3
"""Replace the prior cube grid with the authored area samples and add Tech templates."""
import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
from re import fullmatch
import struct

from build import CANONICAL_OUTPUT, chunk, packstr, script_inventory, string, u32
from refresh_junk_cube_lineup import face_value
from refresh_native_scenery import Native, merge, write_snapshot
from import_lighting import pack_refs

MAP = "Workspace.MiningAway.Map"
LIBRARY = "ServerStorage.JunkCubeTemplates"
SCOPE = {
    "display": (MAP, {"JunkCubeAreas"}, {"Folder", "Part", "Decal", "SurfaceGui", "TextLabel"}),
    "tech": (LIBRARY, {"Tech"}, {"Folder", "Part", "Decal"}),
}


def replace_grid_and_candy(base, new_candy):
    native = Native(base)
    prefix = MAP + ".JunkCubeLineup"
    removed = {ref for path, refs in native.paths.items()
               if path == prefix or path.startswith(prefix + ".") for ref in refs}
    assert Counter(native.instances[ref][1] for ref in removed) == {"Folder": 1, "Part": 23, "Decal": 48}
    old_classes = {native.instances[ref][0] for ref in removed}
    assert all(set(native.classes[cid][1]) <= removed for cid in old_classes), "Grid classes are shared"
    parents = {ref: parent for ref, parent in native.parents.items() if ref not in removed}
    assert not removed.intersection(parents.values())
    updates = {}
    for face in ("Front", "Left", "Right", "Top", "Back", "Bottom"):
        cid, index, values = face_value(native, LIBRARY + ".GumballDispenser." + face)
        assert values[index] == b"rbxassetid://101810481156570", "Existing candy art changed"
        updates.setdefault(cid, [value.decode() for value in values])[index] = new_candy

    header = bytearray(base[:32])
    struct.pack_into("<II", header, 16, u32(base, 16)-len(old_classes), u32(base, 20)-len(removed))
    result = [bytes(header)]
    for kind, data, raw in native.chunks:
        if kind in {b"INST", b"PROP"} and u32(data) in old_classes:
            continue
        if kind == b"PROP" and u32(data) in updates:
            name, end = string(data, 4)
            if name == "Texture":
                raw = chunk(kind, data[:end+1] + b"".join(map(packstr, updates[u32(data)])))
        if kind == b"PRNT":
            raw = chunk(kind, b"\0" + struct.pack("<I", len(parents))
                        + pack_refs(parents) + pack_refs(parents.values()))
        result.append(raw)
    scoped = Native(b"".join(result))
    assert scoped.instances == {ref: row for ref, row in native.instances.items() if ref not in removed}
    assert scoped.parents == parents
    assert {key for key, prop in scoped.props.items() if prop != native.props[key]} == {
        (cid, "Texture") for cid in updates
    }
    return scoped.data


def build_areas(base, directory):
    candy = (directory / "gumballs.txt").read_text().strip()
    assert fullmatch(r"rbxassetid://[0-9]+", candy)
    scoped = replace_grid_and_candy(base, candy)
    result, stats = merge(scoped, directory, addition=SCOPE)
    native = Native(result)
    assert script_inventory(Native(base).chunks) == script_inventory(native.chunks)
    for name, expected in (("ArtsAndCrafts", 12), ("Tech", 8), ("Unassigned", 9)):
        root = native.one(MAP + ".JunkCubeAreas." + name)
        assert sum(parent == root for parent in native.parents.values()) == expected+1
    root = native.one(LIBRARY + ".Tech")
    assert sum(parent == root for parent in native.parents.values()) == 6
    return result, stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, "Canonical file changed"
    result, stats = build_areas(base, args.export_dir)
    if args.write:
        write_snapshot(base, result)
    print(json.dumps({**stats, "old_display_instances_removed": 72,
                      "sha256": sha256(result).hexdigest(), "wrote": args.write}, indent=2))


if __name__ == "__main__":
    main()
