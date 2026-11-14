#!/usr/bin/env python3
"""Mirror the approved depot sign edits and their native posts."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, chunk, script_inventory, string, u32
from import_lighting import pack_words, words
from refresh_crystal_run_signs import position
from refresh_native_scenery import MAP, Native, close, merge, patch_parts, write_snapshot
from refresh_sign_lettering import float_word


ACTIVE = {'Quartz': -36, 'Ruby': -18}
INACTIVE = ('Cobalt', 'Violet', 'Emerald')
POSTS = {'scenery': (MAP, {'ShopSignPosts'}, {'Folder', 'Part'})}


def refresh(base, directory):
    original = Native(base)
    moves = []
    edits = []
    for key, x in ACTIVE.items():
        board = f'{MAP}.{key}Shop.ShopSign'
        before = [x, 16.7, -31.7]
        moves.append({'path': board, 'class': 'Part', 'anchor': before, 'anchorSize': [14, 2.5, .3],
                      'before': {'position': before}, 'after': {'position': [x, 7.2, -31.7]}})
        edits.extend((f'{board}.{face}.ShopName', 'TextLabel', 'TextSize', 4, 54, 64)
                     for face in ('Front', 'Back'))
    for key in INACTIVE:
        board = f'{MAP}.{key}Shop.ShopSign'
        edits.append((board, 'Part', 'Transparency', 4, 0, 1))
        edits.extend((f'{board}.{face}', 'SurfaceGui', 'Enabled', 2, True, False)
                     for face in ('Front', 'Back'))
    fields = MAP.removesuffix('.Map') + '.Fields'
    edits.extend((f'{fields}.{key}.Field.TestLabel', 'BillboardGui', 'MaxDistance', 4, 230, 72)
                 for key in ('Ruby', *INACTIVE))
    moved, touched = patch_parts(original, moves, validate_edit=lambda edit: None)
    native = Native(moved)
    updates = {}
    for path, cls, prop, dtype, before, after in edits:
        cid, actual_class, index, _ = native.instances[native.one(path)]
        assert actual_class == cls
        if (cid, prop) not in updates:
            raw = native.prop(cid, prop, dtype)
            values = words(raw, len(native.classes[cid][1])) if dtype == 4 else list(raw)
            updates[cid, prop] = (dtype, values)
        values = updates[cid, prop][1]
        assert values[index] == (float_word(before) if dtype == 4 else before), path
        values[index] = float_word(after) if dtype == 4 else after

    output = [moved[:32]]
    written = set()
    for kind, payload, raw in native.chunks:
        if kind == b'PROP':
            cid = u32(payload)
            prop, offset = string(payload, 4)
            if (cid, prop) in updates:
                dtype, values = updates[cid, prop]
                raw = chunk(kind, payload[:offset+1] + (pack_words(values) if dtype == 4 else bytes(values)))
                written.add((cid, prop))
        output.append(raw)
    assert written == updates.keys()
    patched = Native(b''.join(output))
    assert original.instances == patched.instances and original.parents == patched.parents
    assert {k for k, value in original.props.items() if patched.props[k] != value} == written | touched

    result, stats = merge(patched.data, directory, addition=POSTS)
    final = Native(result)
    assert stats['new_instances'] == 5
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    for key, x in ACTIVE.items():
        assert close(position(final, f'{MAP}.{key}Shop.ShopSign'), [x, 7.2, -31.7])
        for suffix, dx in (('WestPost', -5.3), ('EastPost', 5.3)):
            path = f'{MAP}.ShopSignPosts.{key}{suffix}'
            assert close(position(final, path), [x+dx, 5.035, -31.7])
            cid, _, index, _ = final.instances[final.one(path)]
            for prop in ('Anchored', 'CanCollide', 'CanTouch', 'CanQuery'):
                assert final.prop(cid, prop, 2)[index] == (prop == 'Anchored')
    return result, dict(stats, property_edits=len(edits)+len(moves))


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
        assert (proof['edits'], proof['posts'], proof['sightlines'], proof['floorSamples']) == (19, 4, 30, 42)
        write_snapshot(base, result)
    print(json.dumps(dict(stats, sha256=sha256(result).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
