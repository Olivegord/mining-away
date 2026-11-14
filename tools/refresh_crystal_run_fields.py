#!/usr/bin/env python3
"""Mirror the verified Crystal Run marker/sign archive without touching the beds."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, write_parents, write_snapshot
from refresh_quarry_blockscape import append_export

RUN = MAP + ".CrystalRun"
ARCHIVE = "CrystalRunFieldArchive"
ZONES = ("Quartz", "Ruby", "Cobalt", "Violet", "Emerald")
EXPECTED = {
    **{f"{RUN}.{zone}.{name}": "Part" for zone in ZONES
       for name in ("Patch1", "Patch2", "Patch3", "ZoneSign")},
    **{f"{RUN}.{name}": cls for name, cls in (
        ("ZoneSignPosts", "Folder"), ("DepotWayfinder", "Folder"),
        ("TrailSign", "Part"), ("ChargingSign", "Part"))},
}


def merge(data, directory):
    base = Native(data)
    manifest = json.loads((directory / "manifest.json").read_text())
    assert manifest.keys() == EXPECTED.keys(), "Unexpected Studio map changes"
    moves = {}
    for path, cls in EXPECTED.items():
        ref = base.one(path)
        assert base.instances[ref][1] == cls
        count = sum(len(items) for name, items in base.paths.items() if name.startswith(path + "."))
        assert count == manifest[path], f"Reconcile Studio changes under {path}"
        moves[ref] = path
    export = append_export(data, directory, "archive", "ServerStorage", ARCHIVE, {"Folder"})
    appended = Native(export)
    assert len(appended.instances) == len(base.instances)+1
    archive = appended.one("ServerStorage." + ARCHIVE)
    result = write_parents(appended, {**appended.parents, **dict.fromkeys(moves, archive)})
    final = Native(result)
    assert all(final.parents[ref] == (archive if ref in moves else parent) for ref, parent in base.parents.items())
    assert base.instances.items() <= final.instances.items()
    assert base.props.items() <= final.props.items()
    assert all(path not in final.paths for path in EXPECTED)
    assert all(base.one(f"{RUN}.{zone}.Field") == final.one(f"{RUN}.{zone}.Field") for zone in ZONES)
    assert script_inventory(base.chunks) == script_inventory(final.chunks)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, "Canonical map changed"
    result = merge(base, args.directory)
    if args.write:
        proof = json.loads((args.directory / "verified.json").read_text())
        assert (proof["place"], proof["universe"]) == (124078027733625, 10774898335)
        assert (proof["archived"], proof["groundSamples"]) == (len(EXPECTED), 75)
        write_snapshot(base, result)
    print(json.dumps({"archived": len(EXPECTED), "sha256": sha256(result).hexdigest(), "wrote": args.write}))


if __name__ == "__main__":
    main()
