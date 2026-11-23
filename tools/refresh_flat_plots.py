#!/usr/bin/env python3
"""Mirror tools/studio_flat_plots.lua into the canonical native file.

Appends ServerStorage.FlatMapArchive, moves Map.QuarryWorld.Terraces, Map.QuarryWorld.Mesas
and the old DigPit (under Map in this file, directly under MiningAway in shared Edit) into it,
then appends Map.PlotPit (the pit refitted around the
hole at 160,0) and Map.PlotRing (eight plot outlines). Every other instance, property and
Source is kept byte-identical. Dry run by default; --write replaces build/DRONE_GAME.rbxl.

    python3 tools/refresh_flat_plots.py <export-dir> --baseline-sha256 <sha>  [--write]

<export-dir> holds plots.b64, pit.b64, archive.b64 and moves.b64 read from
shared.FlatPlots.snapshot in shared Edit.
"""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import Native, read_section, write_parents, write_snapshot
from refresh_toy_world import MAP, append

ROOT = "Workspace.MiningAway"
ARCHIVE = "ServerStorage.FlatMapArchive"
MOVES = {
    MAP + ".QuarryWorld.Terraces": ("Folder", ARCHIVE),
    MAP + ".QuarryWorld.Mesas": ("Folder", ARCHIVE),
    ROOT + ".DigPit": ("Folder", ARCHIVE),
}


def merge(data, directory):
    original = Native(data)
    moves = json.loads(read_section(directory, "moves"))
    assert {m["path"]: (m["class"], m["to"]) for m in moves} == MOVES, "Move plan differs from the allowlist"
    children = {}
    for ref, parent in original.parents.items():
        children.setdefault(parent, []).append(ref)

    def count(ref):
        return sum(1 + count(child) for child in children.get(ref, []))

    planned = []
    for m in moves:
        path = m["path"]
        if path == ROOT + ".DigPit" and path not in original.paths:
            path = MAP + ".DigPit"
        ref = original.one(path)
        assert original.instances[ref][1] == m["class"], m
        assert count(ref) == m["descendants"], f"Unreconciled descendants under {m['path']}"
        planned.append(ref)

    result, archived = append(data, directory, "archive", "ServerStorage", "FlatMapArchive", {"Folder"})
    native = Native(result)
    target = native.one(ARCHIVE)
    result = write_parents(native, {**native.parents, **{ref: target for ref in planned}})
    # The old pit is out of the way now, so the refitted one can take its place.
    result, pit_count = append(result, directory, "pit", MAP, "PlotPit", {"Folder", "Part"})
    result, ring_count = append(result, directory, "plots", MAP, "PlotRing", {"Folder", "Part"})

    final = Native(result)
    assert original.instances.items() <= final.instances.items()
    assert all(final.parents[ref] == (target if ref in planned else p) for ref, p in original.parents.items())
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    assert not final.paths.get(ROOT + ".DigPit") and not final.paths.get(MAP + ".DigPit")
    final.one(MAP + ".PlotPit")
    final.one(MAP + ".PlotRing.Plot1")
    return final.data, {
        "moved_roots": len(planned),
        "new_instances": archived + pit_count + ring_count,
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
