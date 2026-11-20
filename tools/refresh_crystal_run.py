#!/usr/bin/env python3
"""Mirror the scoped Crystal Run fixtures from shared Edit into the canonical place."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT
from refresh_native_scenery import MAP, Native, merge, patch_parts, write_snapshot

SCOPE = {"scenery": (MAP, {"CrystalRun"}, {"Folder", "Part", "SurfaceGui", "TextLabel"})}
ZONES = ("Quartz", "Ruby", "Cobalt", "Violet", "Emerald")
FOUNDATION = f"{MAP}.DronerevolutionTerraces.NorthOverlook.Earth"


def build(baseline, directory):
    edit = {
        "path": FOUNDATION, "class": "Part", "anchor": [0, 12.5, -108],
        "anchorSize": [30, 51, 30],
        "before": {"position": [0, 12.5, -108], "size": [30, 51, 30]},
        "after": {"position": [0, 31.5, -108], "size": [30, 13, 30]},
    }
    def check(entry):
        assert entry == edit and set(entry["after"]) == {"position", "size"}
    original = Native(baseline)
    opened, touched = patch_parts(original, [edit], validate_edit=check)
    result, report = merge(opened, directory, addition=SCOPE)
    final = Native(result)
    assert touched == {key for key, value in original.props.items() if final.props[key] != value}
    return result, {**report, "parts_updated": 1}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    baseline = CANONICAL_OUTPUT.read_bytes()
    assert sha256(baseline).hexdigest() == args.baseline_sha256, "Canonical file changed since staging"
    result, report = build(baseline, args.directory)
    model = Native(result)
    for zone in ZONES:
        model.one(f"{MAP}.CrystalRun.{zone}.Field")
    for zone in ZONES[1:]:
        for side in ("WestWall", "EastWall"):
            model.one(f"{MAP}.CrystalRun.{zone}.{side}")
    model.one(f"{MAP}.CrystalRun.ChargingStation")
    if args.write:
        write_snapshot(baseline, result)
    print(json.dumps({**report, "sha256": sha256(result).hexdigest(), "wrote": args.write}))


if __name__ == "__main__":
    main()
