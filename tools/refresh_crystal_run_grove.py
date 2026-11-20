#!/usr/bin/env python3
"""Mirror the authored trail trees into the existing native place."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT
from refresh_native_scenery import MAP, Native, merge, surface_inventory, write_snapshot


GROVE = f'{MAP}.CrystalRun.TrailGrove'
SCOPE = {'scenery': (f'{MAP}.CrystalRun', {'TrailGrove'}, {'Folder', 'Model', 'Part'})}
SITES = {'QuartzEdge': (-28, 139, .48), 'QuartzSapling': (-41, 142, .32),
         'CobaltApproach': (31, 252, .40), 'EmeraldEdge': (-30, 386, .43), 'EmeraldSapling': (-41, 389, .30)}


def refresh(base, directory):
    result, stats = merge(base, directory, addition=SCOPE)
    native = Native(result)
    assert stats['new_instances'] == 16
    assert stats['parts_updated'] == stats['archived_models'] == 0
    rows = surface_inventory(native, GROVE + '.')
    assert len(rows) == 10
    for tree, (x, z, scale) in SITES.items():
        for name, variant in (('Trunk', 'QuarryFoliage_Bark'), ('Canopy', 'QuarryPalette_LeafClumps')):
            relative = f'{tree}.{name}'
            (row,) = [item for item in rows if item[0] == relative]
            _, cls, position, size, _, actual_variant = row
            assert cls == 'Part' and actual_variant == variant
            if name == 'Trunk':
                assert abs(position[0] - x) < .01 and abs(position[2] - z) < .01
                assert abs(position[1] - size[1] / 2 - 4.025) < .01 and abs(size[1] - 24 * scale) < .01
            cid, _, index, _ = native.instances[native.one(f'{GROVE}.{relative}')]
            for prop in ('CanCollide', 'CanTouch', 'CanQuery', 'Anchored'):
                assert native.prop(cid, prop, 2)[index] == (prop == 'Anchored')
    return result, stats


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
        proof = json.loads((args.directory / 'verified.json').read_text())
        assert (proof['placeId'], proof['universeId']) == (124078027733625, 10774898335)
        assert (proof['trees'], proof['parts'], proof['floorSamples'], proof['clearance'], proof['signViews']) == (5, 10, 129, 150, 720)
        write_snapshot(base, result)
    print(json.dumps(dict(stats, sha256=sha256(result).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
