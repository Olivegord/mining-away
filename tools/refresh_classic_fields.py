#!/usr/bin/env python3
"""Mirror the restored route and resized square fields into the canonical file."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, close, patch_parts, write_parents, write_snapshot

ARCHIVE = "ServerStorage.FlatFieldsArchive"
FIELDS = "Workspace.MiningAway.Fields"
CLASSIC = f"{ARCHIVE}.CrystalRun"
NAMES = ("Quartz", "Ruby", "Cobalt", "Violet", "Emerald")
SQUARES = {f"{MAP}.CrystalRun.{name}.Field" for name in NAMES}


def checked_edit(edit):
    assert edit["path"] in SQUARES
    before, after = edit["before"], edit["after"]
    assert before.keys() == after.keys() == {"size"}
    assert close(before["size"], [46, .8, 46])
    assert close(after["size"], [32, .8, 32])


def merge(data, edits):
    original = Native(data)
    assert len(edits) == 5 and {edit["path"] for edit in edits} == SQUARES
    assert f"{FIELDS}.CrystalRun" not in original.paths
    assert all(original.one(f"{CLASSIC}.{name}.Field") for name in NAMES)
    moves = {
        original.one(CLASSIC): original.one(FIELDS),
        original.one(f"{ARCHIVE}.MiningAwayReferenceGround.Baseplate"): original.one(FIELDS),
        original.one(f"{CLASSIC}.ChargingStation"): original.one(ARCHIVE),
        original.one(f"{CLASSIC}.ChargeIndicator"): original.one(ARCHIVE),
    }
    patched, touched = patch_parts(original, edits, validate_edit=checked_edit)
    result = write_parents(Native(patched), {**original.parents, **moves})
    final = Native(result)
    assert final.instances == original.instances
    assert {key for key in original.props if original.props[key] != final.props[key]} == touched
    assert final.parents == {**original.parents, **moves}
    assert all(final.one(f"{FIELDS}.CrystalRun.{name}.Field") for name in NAMES)
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("edits", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, "Canonical revision changed"
    result = merge(data, json.loads(args.edits.read_text()))
    if args.write:
        write_snapshot(data, result)
    print(json.dumps({"classic_fields": 5, "resized_fields": 5, "wrote": args.write,
                      "sha256": sha256(result).hexdigest()}, indent=2))


if __name__ == "__main__":
    main()
