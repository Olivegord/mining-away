#!/usr/bin/env python3
"""Mirror tools/studio_quarry_world.lua into the canonical native file.

Appends Workspace.MiningAway.Map.QuarryWorld and Lighting.QuarryAir, moves the
Toy World decorations and haze into ServerStorage.ToyWorldArchive, moves the
mineral display stands back onto the map, recolors the allowlisted gameplay
parts and sets seven Lighting properties after checking their old values.
Every other instance and Source is kept byte-identical. Dry run by default;
--write replaces build/DRONE_GAME.rbxl after the checks.
"""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import Native, patch_parts, read_section, write_parents, write_snapshot
from refresh_toy_world import LIGHTING, MAP, RECOLOR, append, check_edit, patch_lighting

SCENERY_CLASSES = {"Folder", "Part", "Attachment", "ParticleEmitter", "PointLight"}
ARCHIVE = "ServerStorage.ToyWorldArchive"
MOVES = {
    MAP + ".ToyWorld": ("Folder", ARCHIVE),
    "Lighting.ToyWorldAir": ("Atmosphere", ARCHIVE),
    ARCHIVE + ".MineralLineup": ("Folder", MAP),
}
LIGHT_PROPS = {**LIGHTING, "EnvironmentDiffuseScale": 0x04, "EnvironmentSpecularScale": 0x04}


def merge(data, directory):
    original = Native(data)
    moves = json.loads(read_section(directory, "moves"))
    edits = json.loads(read_section(directory, "edits"))
    assert {m["path"]: (m["class"], m["to"]) for m in moves} == MOVES, "Move plan differs from the allowlist"
    assert {e["path"] for e in edits} == RECOLOR, "Recolor plan differs from the allowlist"
    children = {}
    for ref, parent in original.parents.items():
        children.setdefault(parent, []).append(ref)

    def count(ref):
        return sum(1 + count(child) for child in children.get(ref, []))

    planned = []
    for m in moves:
        ref = original.one(m["path"])
        assert original.instances[ref][1] == m["class"], m
        assert count(ref) == m["descendants"], f"Unreconciled descendants under {m['path']}"
        planned.append((ref, m["to"]))
    # The Toy World beds were saved from fractional colors; Studio rounds a byte differently.
    result, touched = patch_parts(original, edits, validate_edit=check_edit, color_tolerance=1)
    result, lit = patch_lighting(result, json.loads(read_section(directory, "lighting")), LIGHT_PROPS)
    touched |= lit
    result, scenery_count = append(result, directory, "scenery", MAP, "QuarryWorld", SCENERY_CLASSES)
    result, _ = append(result, directory, "air", "Lighting", "QuarryAir", {"Atmosphere"})
    native = Native(result)
    relocated = {ref: native.one(to) for ref, to in planned}
    final = Native(write_parents(native, {**native.parents, **relocated}))
    assert original.instances.items() <= final.instances.items()
    assert touched == {key for key, value in original.props.items() if final.props[key] != value}
    assert all(final.parents[ref] == relocated.get(ref, p) for ref, p in original.parents.items())
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    final.one(MAP + ".MineralLineup")
    return final.data, {
        "moved_roots": len(planned),
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
