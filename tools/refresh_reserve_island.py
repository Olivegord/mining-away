#!/usr/bin/env python3
"""Save the reserve coastline and archive only the three former perimeter layers."""
import argparse
import json
from hashlib import sha256
from pathlib import Path
import re

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, patch_parts, read_section, write_parents, write_snapshot
from refresh_quarry_blockscape import append_export

ARCHIVE = "IslandShoreArchive"
RIMS = {
    "LiminalReserve.Enclosure": 136,
    "QuarryBlockRim": 87,
    "QuarryBasinFoothills.GrassRim": 41,
}


def check_tree(edit):
    path = edit["path"]
    assert re.fullmatch(re.escape(MAP) + r"\.QuarryBasinFoothills\.\w+\.ShelfTree\.\w+", path), path
    assert edit["class"] == "Part" and edit["before"].keys() == edit["after"].keys() == {"position"}
    old, new = edit["before"]["position"], edit["after"]["position"]
    assert old == edit["anchor"] and old[::2] == new[::2] and 0.85 <= old[1] - new[1] < 40, path


def merge(data, directory):
    before = Native(data)
    relocated = {}
    for relative, expected in RIMS.items():
        path = f"{MAP}.{relative}"
        ref = before.one(path)
        assert before.instances[ref][1] == "Folder", path
        descendants = sum(len(refs) for key, refs in before.paths.items() if key.startswith(path + "."))
        assert descendants == expected, f"Changed perimeter inventory at {path}"
        relocated[ref] = descendants

    edits = json.loads(read_section(directory, "trees"))
    result, touched = patch_parts(before, edits, validate_edit=check_tree)
    result = append_export(result, directory, "scenery", MAP, "ReserveIsland", {"Folder", "Part", "WedgePart"})
    result = append_export(result, directory, "archive", "ServerStorage", ARCHIVE, {"Folder"})
    native = Native(result)
    archive = native.one("ServerStorage." + ARCHIVE)
    assert archive not in native.parents.values(), "Expected empty archive folder"
    moved = dict.fromkeys(relocated, archive)
    final = Native(write_parents(native, {**native.parents, **moved}))
    assert before.instances.items() <= final.instances.items()
    assert touched == {key for key, value in before.props.items() if final.props[key] != value}
    assert all(final.parents[ref] == moved.get(ref, parent) for ref, parent in before.parents.items())
    assert script_inventory(before.chunks) == script_inventory(final.chunks)
    return final.data, {
        "added": len(final.instances) - len(before.instances),
        "archived_roots": len(moved),
        "archived_descendants": sum(relocated.values()),
        "tree_parts_lowered": len(edits),
        "preserved_sources": len(script_inventory(final.chunks)),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, "Canonical file changed; reconcile before saving"
    result, report = merge(data, args.directory)
    if args.write:
        write_snapshot(data, result)
    print(json.dumps(dict(report, wrote=args.write, sha256=sha256(result).hexdigest()), indent=2))
