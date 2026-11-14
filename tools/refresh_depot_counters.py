#!/usr/bin/env python3
"""Mirror the two verified shop counters into the canonical native place."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from import_lighting import words
from refresh_native_scenery import MAP, Native, close, merge, write_parents, write_snapshot
from restore_reference_look import Values


STATIONS = {'QuartzCounter': ('QuartzShop', -36), 'StarCounter': ('RubyShop', -18)}
TEMPLATE = f'{MAP}.SimpleFlatTestMap.PackStationAssembly'
PARTS = {'Base': ('PackStation', 4.795, (8.4, 1.49, 4.2)), 'Top': ('PackStationPad', 5.655, (9, .25, 4.8))}


def material(native, ref):
    cid, cls, index, _ = native.instances[ref]
    assert cls == 'Part'
    return words(native.prop(cid, 'Material', 0x12), len(native.classes[cid][1]))[index]


def refresh(base, directory):
    original = Native(base)
    staged, stats = merge(base, directory, addition={'scenery': (MAP, set(STATIONS), {'Model', 'Part'})})
    native = Native(staged)
    parents = {native.one(f'{MAP}.{name}'): native.one(f'{MAP}.{station}')
               for name, (station, _) in STATIONS.items()}
    final = Native(write_parents(native, {**native.parents, **parents}))
    assert stats['new_instances'] == 6
    assert original.instances.items() <= final.instances.items()
    assert all(final.parents[ref] == parent for ref, parent in original.parents.items())
    assert all(final.props[key] == value for key, value in original.props.items())
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    values = Values(final)
    top_colors = set()
    for name, (station, x) in STATIONS.items():
        for part, (template, y, size) in PARTS.items():
            ref = final.one(f'{MAP}.{station}.{name}.{part}')
            assert close(values.get(ref, 'CFrame'), (x, y, -30)) and close(values.get(ref, 'size'), size)
            assert material(final, ref) == material(original, original.one(f'{TEMPLATE}.{template}'))
            assert values.get(ref, 'Transparency') == 0
            cid, _, index, _ = final.instances[ref]
            for prop in ('Anchored', 'CanCollide', 'CanQuery', 'CanTouch'):
                assert final.prop(cid, prop, 2)[index] == (prop != 'CanTouch')
            if part == 'Top':
                top_colors.add(tuple(values.get(ref, 'Color3uint8')))
    assert len(top_colors) == 2
    return final.data, stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Reconcile the current canonical map first'
    result, stats = refresh(base, args.directory)
    if args.write:
        proof = json.loads((args.directory/'verified.json').read_text())
        assert (proof['placeId'], proof['universeId']) == (124078027733625, 10774898335)
        assert (proof['counters'], proof['aisleSamples'], proof['sightlines'], proof['promptSpots'], proof['topSamples']) == (2, 72, 18, 8, 18)
        write_snapshot(base, result)
    print(json.dumps(dict(stats, sha256=sha256(result).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
