#!/usr/bin/env python3
"""Mirror the verified Studio pack preview stand into the existing native map."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, close, merge, write_snapshot
from restore_reference_look import Values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Reconcile the current canonical map first'
    before = Native(base)
    name = 'LegendaryPreviewStand'
    merged, stats = merge(base, args.directory, addition={
        'scenery': (MAP, {name}, {'Model', 'Part', 'SurfaceGui', 'TextLabel'}),
    })
    after = Native(merged)
    assert stats['new_instances'] == 10
    assert before.instances.items() <= after.instances.items()
    assert before.parents.items() <= after.parents.items()
    assert before.props.items() <= after.props.items()
    assert script_inventory(before.chunks) == script_inventory(after.chunks)
    values = Values(after)
    for part, y in {'Counter': 4.7, 'GoldTop': 5.56, 'Sign': 7.35}.items():
        ref = after.one(f'{MAP}.{name}.{part}')
        assert close(values.get(ref, 'CFrame'), (-38, y, 19.5))
    if args.write:
        proof = json.loads((args.directory/'verified.json').read_text())
        assert (proof['placeId'], proof['universeId']) == (124078027733625, 10774898335)
        assert (proof['parts'], proof['approaches']) == (3, 4)
        write_snapshot(base, merged)
    print(json.dumps(dict(stats, sha256=sha256(merged).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
