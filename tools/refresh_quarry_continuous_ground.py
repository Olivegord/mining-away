#!/usr/bin/env python3
"""Mirror the checked continuous quarry ground and archive moves from Studio Edit."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, TERRACES, Native, read_section, write_parents, write_snapshot
from refresh_quarry_blockscape import append_export

SCENE = "QuarryContinuousGround"
ARCHIVE = "QuarryGroundArchive"
REPLACED = {
    MAP + ".QuarryBlockscape",
    MAP + ".QuarryBiomeReaches",
    MAP + ".QuarryWoodlands",
    MAP + ".QuarryDepthPass.CobaltForestExtension",
    TERRACES + "GrassyRims",
    TERRACES + "GroundArt.ExposedStrata",
    TERRACES + "AssetScenery.EmeraldScenery.09_Rock",
}
ALLOWED = {"Folder", "Model", "Part", "WedgePart", "PointLight"}


def merge(data, directory):
    original = Native(data)
    moves = json.loads(read_section(directory, "moves"))
    assert len(moves) == len(REPLACED) and {move["path"] for move in moves} == REPLACED
    refs = []
    for move in moves:
        path = move["path"]
        refs.append(original.one(path))
        descendants = [ref for name, refs_at_name in original.paths.items()
                       if name.startswith(path + ".") for ref in refs_at_name]
        assert len(descendants) == move["descendants"], f"Unreconciled Edit content under {path}"
        assert all(original.instances[ref][1] in ALLOWED for ref in descendants)

    result = append_export(data, directory, "scenery", MAP, SCENE, ALLOWED)
    result = append_export(result, directory, "archive", "ServerStorage", ARCHIVE, {"Folder"})
    updated = Native(result)
    relocated = dict.fromkeys(refs, updated.one("ServerStorage." + ARCHIVE))
    final = Native(write_parents(updated, {**updated.parents, **relocated}))
    assert original.instances.items() <= final.instances.items()
    assert original.props.items() <= final.props.items(), "Changed a baseline property"
    assert all(final.parents[ref] == relocated.get(ref, parent) for ref, parent in original.parents.items())
    sources = script_inventory(final.chunks)
    assert script_inventory(original.chunks) == sources
    return final.data, {"archived_roots": len(refs), "new_instances": len(final.instances)-len(original.instances),
                        "preserved_sources": len(sources)}


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
