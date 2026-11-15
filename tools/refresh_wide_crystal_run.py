#!/usr/bin/env python3
"""Mirror the five checked Crystal Run bed resizes from Studio Edit."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, close, patch_parts, write_snapshot
from restore_reference_look import Values

ZONES = ("Quartz", "Ruby", "Cobalt", "Violet", "Emerald")
BEDS = {f"{MAP}.CrystalRun.{zone}.Field": 158 + 64 * i for i, zone in enumerate(ZONES)}


def check_edit(edit):
    z = BEDS[edit["path"]]
    before, after = edit["before"], edit["after"]
    assert edit["class"] == "Part" and before.keys() == after.keys() == {"position", "size"}
    assert close(edit["anchor"], (0, 3.74, z)) and close(before["position"], edit["anchor"])
    assert close(edit["anchorSize"], (108, .6, 64)) and close(before["size"], edit["anchorSize"])
    assert close(after["position"], (30, 3.74, z)) and close(after["size"], (216, .6, 64))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, "Canonical map changed after staging"
    edits = json.loads((args.export_dir / "edits.json").read_text())
    assert len(edits) == len(BEDS) and {edit["path"] for edit in edits} == BEDS.keys()
    original = Native(base)
    result, changed = patch_parts(original, edits, validate_edit=check_edit)
    final = Native(result)
    assert original.instances == final.instances and original.parents == final.parents
    assert original.props.keys() == final.props.keys()
    assert changed == {key for key, value in original.props.items() if final.props[key] != value}
    sources = script_inventory(final.chunks)
    assert script_inventory(original.chunks) == sources
    values = Values(final)
    for path, z in BEDS.items():
        bed = final.one(path)
        assert close(values.get(bed, "size"), (216, .6, 64))
        assert close(values.get(bed, "CFrame"), (30, 3.74, z))
    if args.write:
        receipt = json.loads((args.export_dir / "verified.json").read_text())
        assert receipt == {"place": 124078027733625, "universe": 10774898335,
                           "beds": 5, "width": 216, "surfaceChecks": 1485}
        write_snapshot(base, result)
    print(json.dumps({"beds": len(BEDS), "preserved_instances": len(final.instances),
                      "preserved_sources": len(sources), "sha256": sha256(result).hexdigest(),
                      "written": args.write}))


if __name__ == "__main__":
    main()
