#!/usr/bin/env python3
"""Mirror the four depot route tints and original checker into DRONE_GAME."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT
from refresh_native_scenery import MAP, Native, merge, patch_parts, write_snapshot

TERRACES = f'{MAP}.DronerevolutionTerraces'
DECK = f'{TERRACES}.LogisticsApron.ServiceDeck'
UTILITY = f'{MAP}.PlatformSurfaceFill.DronerevolutionTerraces_MarketSquare_UtilityWalk'
CHECKER = {'scenery': (DECK, {'MiningAwayChecker'}, {'Texture'})}
ROUTE = (
    (DECK, [0, 3.5, 87], [70, 1, 78]),
    (f'{TERRACES}.MarketSquare.UtilityWalk', [1, 4.035, 35.015], [39, .07, 19.97]),
    (f'{UTILITY}_2', [-33.25, 4.035, 35], [29.5, .07, 20]),
    (f'{UTILITY}_3', [34.25, 4.035, 35], [27.5, .07, 20]),
)


def refresh(base, directory):
    original = Native(base)
    edits = [{'path': path, 'class': 'Part', 'anchor': position, 'anchorSize': size,
              'before': {'color': [163, 162, 165]}, 'after': {'color': [109, 106, 105]}}
             for path, position, size in ROUTE]
    patched, touched = patch_parts(original, edits, validate_edit=lambda edit: None)
    assert touched and all(prop == 'Color3uint8' for _, prop in touched)
    result, stats = merge(patched, directory, addition=CHECKER)
    final = Native(result)
    assert stats['new_instances'] == 1
    assert final.instances[final.one(f'{DECK}.MiningAwayChecker')][1] == 'Texture'
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
        assert (proof['tinted'], proof['floorSamples'], proof['tile']) == (4, 99, 8)
        write_snapshot(base, result)
    print(json.dumps(dict(stats, parts_updated=4, sha256=sha256(result).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
