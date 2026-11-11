#!/usr/bin/env python3
"""Mirror the five existing sign moves and native post export into DRONE_GAME."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, close, merge, patch_parts, split_cframe, unpack_vectors, write_snapshot

RUN = f'{MAP}.CrystalRun'
ZONES = ('Quartz', 'Ruby', 'Cobalt', 'Violet', 'Emerald')
POSTS = {'scenery': (RUN, {'ZoneSignPosts'}, {'Folder', 'Part'})}


def position(native, path):
    cid, cls, index, _ = native.instances[native.one(path)]
    assert cls == 'Part'
    count = len(native.classes[cid][1])
    _, coords = split_cframe(native.prop(cid, 'CFrame', 0x10), count)
    return unpack_vectors(coords, count)[index]


def refresh(base, directory):
    original = Native(base)
    edits = []
    for index, zone in enumerate(ZONES):
        start = 126 + 64 * index
        before = [-58, 5.1, start + 5]
        after = [-16, 6.59, start + (2 if index == 0 else 4)]
        edits.append({'path': f'{RUN}.{zone}.ZoneSign', 'class': 'Part', 'anchor': before,
                      'anchorSize': [16, 2.6, .22], 'before': {'position': before}, 'after': {'position': after}})
    patched, touched = patch_parts(original, edits, validate_edit=lambda edit: None)
    moved = Native(patched)
    assert len(touched) == 1 and all(prop == 'CFrame' for _, prop in touched)
    assert original.instances == moved.instances and original.parents == moved.parents
    result, stats = merge(patched, directory, addition=POSTS)
    final = Native(result)
    assert stats['new_instances'] == 11
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    for zone, edit in zip(ZONES, edits):
        x, _, z = edit['after']['position']
        assert close(position(final, edit['path']), edit['after']['position'])
        for name, offset in (('WestPost', -6.1), ('EastPost', 6.1)):
            assert close(position(final, f'{RUN}.ZoneSignPosts.{zone}{name}'), [x + offset, 4.9, z + .18])
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
        assert (proof['signs'], proof['posts'], proof['sightlines']) == (5, 10, 45)
        assert proof['maxAngle'] < 36
        write_snapshot(base, result)
    print(json.dumps(dict(stats, signs_moved=5, sha256=sha256(result).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
