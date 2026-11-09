#!/usr/bin/env python3
"""Mirror the Studio Edit wall archive and sign moves into the canonical game."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, merge, patch_parts, write_parents, write_snapshot

RUN = f'{MAP}.CrystalRun'
ARCHIVE = 'ServerStorage.CrystalRunDividers'
ZONES = ('Quartz', 'Ruby', 'Cobalt', 'Violet', 'Emerald')


def mirror(base, directory):
    original = Native(base)
    edits = []
    wall_refs = {original.one(f'{RUN}.EndWall'): ARCHIVE}
    for i, zone in enumerate(ZONES):
        path = f'{RUN}.{zone}'
        near = 126 + i * 64
        before = [-25, 5.84 if i == 0 else 8.54, near - 1.3]
        edits.append({'path': f'{path}.ZoneSign', 'class': 'Part', 'anchor': before,
                      'anchorSize': [16, 2.6, .22], 'before': {'position': before},
                      'after': {'position': [-58, 5.1, near + 5]}})
        if i > 0:
            caps = original.paths[f'{path}.WallCap']
            assert len(caps) == 2
            for ref in [*caps, original.one(f'{path}.WestWall'), original.one(f'{path}.EastWall')]:
                assert original.instances[ref][1] == 'Part'
                wall_refs[ref] = f'{ARCHIVE}.{zone}'
    assert len(wall_refs) == 17
    patched, touched = patch_parts(original, edits, validate_edit=lambda edit: None)
    staged, _ = merge(patched, directory, addition={'archive': ('ServerStorage', {'CrystalRunDividers'}, {'Folder'})})
    n = Native(staged)
    assert len(n.instances) == len(original.instances) + 5
    moves = {ref: n.one(path) for ref, path in wall_refs.items()}
    final = Native(write_parents(n, {**n.parents, **moves}))
    assert original.instances.items() <= final.instances.items()
    assert all(final.parents[ref] == moves.get(ref, parent) for ref, parent in original.parents.items())
    assert {key for key, value in original.props.items() if final.props[key] != value} == touched
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    assert not any(final.path(ref).startswith(RUN + '.') for ref in wall_refs)
    return final.data


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Reconcile the current canonical map first'
    result = mirror(base, args.directory)
    if args.write:
        proof = json.loads((args.directory/'verified.json').read_text())
        assert (proof['placeId'],proof['universeId']) == (124078027733625,10774898335)
        assert (proof['wallsRemoved'],proof['signsMoved'],proof['through'],proof['floor']) == (17,5,28,1120)
        write_snapshot(base, result)
    print(json.dumps({'sha256': sha256(result).hexdigest(), 'written': args.write, 'wallsArchived': 17, 'signsMoved': 5}))
