#!/usr/bin/env python3
"""Mirror the authored junk grid and replace the approved template face URLs."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import re

from build import CANONICAL_OUTPUT, chunk, packstr, script_inventory, string, string_values, u32
from refresh_native_scenery import Native, merge, write_snapshot

MAP = "Workspace.MiningAway.Map"
LIBRARY = "ServerStorage.JunkCubeTemplates."
SCOPE = {"lineup": (MAP, {"JunkCubeLineup"}, {"Folder", "Part", "Decal"})}
PHOTOGRAPHS = {
    "GumballDispenser": "Gumballs", "AlphabetBlock": "Alphabet Block",
    "BoxFan": "Box Fan", "CubeAquarium": "Cube Aquarium", "IceCube": "Ice Cube",
    "TicketBox": "Ticket Box",
}
FACES = {"Front", "Left", "Right", "Top", "Back", "Bottom"}


def face_value(native, path):
    cid, cls, index, _ = native.instances[native.one(path)]
    assert cls == "Decal", path
    values = string_values(native.prop(cid, "Texture", 1), 0, len(native.classes[cid][1]))
    return cid, index, values


def replace_faces(base, edits):
    native = Native(base)
    keys = {(edit["template"], edit["face"]) for edit in edits}
    assert len(edits) == len(keys) and keys == {(name, face) for name in PHOTOGRAPHS for face in FACES}
    updates = {}
    for edit in edits:
        path = LIBRARY + edit["template"] + "." + edit["face"]
        cid, index, values = face_value(native, path)
        assert values[index].decode() == edit["before"], path
        assert re.fullmatch(r"rbxassetid://[0-9]+", edit["after"]), path
        updates.setdefault(cid, [value.decode() for value in values])[index] = edit["after"]
    result = [base[:32]]
    for kind, data, raw in native.chunks:
        if kind == b"PROP" and u32(data) in updates:
            name, end = string(data, 4)
            if name == "Texture":
                raw = chunk(kind, data[:end+1] + b"".join(map(packstr, updates[u32(data)])))
        result.append(raw)
    after = Native(b"".join(result))
    assert native.instances == after.instances and native.parents == after.parents
    assert {key for key, prop in native.props.items() if after.props[key] != prop} == {
        (cid, "Texture") for cid in updates
    }
    return after.data


def build_grid(base, directory):
    edits = json.loads((directory / "face-edits.json").read_text())
    result, stats = merge(replace_faces(base, edits), directory, addition=SCOPE)
    native = Native(result)
    parent = native.one(MAP + ".JunkCubeLineup")
    parts = [ref for ref, owner in native.parents.items() if owner == parent]
    assert len(parts) == 23 and stats["new_instances"] == 72
    assert all(native.instances[part][1] == "Part" for part in parts)
    assert script_inventory(Native(base).chunks) == script_inventory(native.chunks)
    for edit in edits:
        name, face = edit["template"], edit["face"]
        for path in (LIBRARY + name, MAP + ".JunkCubeLineup." + PHOTOGRAPHS[name]):
            _, index, values = face_value(native, path + "." + face)
            assert values[index].decode() == edit["after"], path
    return result, {**stats, "template_faces_updated": len(edits), "sha256": sha256(result).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, "Canonical snapshot changed"
    result, stats = build_grid(base, args.export_dir)
    if args.write:
        write_snapshot(base, result)
    print(json.dumps({**stats, "wrote": args.write}, indent=2))


if __name__ == "__main__":
    main()
