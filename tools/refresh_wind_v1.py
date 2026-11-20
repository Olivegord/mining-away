#!/usr/bin/env python3
"""Check the scoped Version 1 Studio export and append it to the canonical map."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT
from import_lighting import refs
from refresh_native_scenery import Native, close, merge, write_snapshot
from restore_reference_look import Values

ROOT = "Workspace.VERSION 1"
CLASSES = {"Model", "Folder", "Part", "Attachment", "Beam", "ParticleEmitter", "ProximityPrompt", "SurfaceGui", "TextLabel"}


def check(data):
    native = Native(data)
    values = Values(native)
    origin = native.one(ROOT + ".VortexOrigin")
    switch = native.one(ROOT + ".Replay")
    assert close(values.get(origin, "CFrame"), (-17, 4, -7), .2)
    assert close(values.get(switch, "CFrame"), (-14, 4.68, 11), .2)
    native.one(ROOT + ".Replay.CastWindV1")
    for name in ("DustShelf", "StoneGrit"):
        native.one(ROOT + ".VortexOrigin." + name)
    for group, count in (("Chip", 26), ("Plate", 13)):
        for i in range(1, count + 1):
            native.one(f"{ROOT}.Debris.{group}{i}")
    checked = 0
    for cid, (cls, ids) in native.classes.items():
        if cls != "Beam" or not any(native.parents[r] == origin for r in ids):
            continue
        starts, ends = (refs(native.prop(cid, prop, 0x13), len(ids)) for prop in ("Attachment0", "Attachment1"))
        for beam, start, end in zip(ids, starts, ends):
            if native.parents[beam] != origin:
                continue
            name = native.instances[beam][3]
            assert start == native.one(f"{ROOT}.VortexOrigin.{name}Root")
            assert end == native.one(f"{ROOT}.VortexOrigin.{name}Tip")
            checked += 1
    assert checked == 94, checked
    return checked


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, "Canonical changed; reconcile first"
    result, report = merge(base, args.directory, addition={"scenery": ("Workspace", {"VERSION 1"}, CLASSES)})
    beams = check(result)
    if args.write:
        proof = json.loads((args.directory / "verified.json").read_text())
        assert (proof["place"], proof["universe"], proof["beams"], proof["descendants"] + 1) == (
            124078027733625, 10774898335, beams, report["new_instances"])
        write_snapshot(base, result)
    print(json.dumps(dict(report, beams=beams, sha256=sha256(result).hexdigest(), written=args.write)))


if __name__ == "__main__":
    main()
