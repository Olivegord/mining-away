#!/usr/bin/env python3
"""Mirror the native TextSize edits on the authored Crystal Run sign faces."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import struct

from build import CANONICAL_OUTPUT, chunk, script_inventory, string, string_values, u32
from import_lighting import pack_words, words
from refresh_native_scenery import MAP, Native, write_snapshot

RUN = f'{MAP}.CrystalRun'
BOARDS = {
    f'{RUN}.{zone}.ZoneSign': (37, 64)
    for zone in ('Quartz', 'Ruby', 'Cobalt', 'Violet', 'Emerald')
}
BOARDS.update({
    f'{RUN}.TrailSign': (37, 64),
    f'{RUN}.DepotWayfinder.Board': (48, 60),
    f'{RUN}.ChargingSign': (40, 60),
    f'{MAP}.DepotStationPlates.PackStationPlate': (56, 64),
    f'{MAP}.DepotStationPlates.PrestigeStationPlate': (56, 64),
})
FACES = {'Front': 5, 'Back': 2}


def float_word(value):
    bits = struct.unpack('>I', struct.pack('>f', value))[0]
    return ((bits << 1) | (bits >> 31)) & 0xffffffff


def refresh(base, edits):
    original = Native(base)
    updates = {}
    visited = set()
    for edit in edits:
        path, face = edit['path'], edit['face']
        board, face_name, label_name = path.rsplit('.', 2)
        assert label_name == 'TextLabel' and face_name in {'Sign', face}
        assert (edit['before'], edit['after']) == BOARDS[board]
        assert (board, face) not in visited
        visited.add((board, face))
        matches = []
        for ref in original.paths[path]:
            cid, cls, index, _ = original.instances[original.parents[ref]]
            assert cls == 'SurfaceGui'
            count = len(original.classes[cid][1])
            if words(original.prop(cid, 'Face', 0x12), count)[index] == FACES[face]:
                matches.append(ref)
        assert len(matches) == 1
        cid, cls, index, _ = original.instances[matches[0]]
        assert cls == 'TextLabel'
        count = len(original.classes[cid][1])
        labels = string_values(original.prop(cid, 'Text', 1), 0, count)
        assert labels[index].decode() == edit['text']
        values = updates.setdefault(cid, words(original.prop(cid, 'TextSize', 4), count))
        assert values[index] == float_word(edit['before'])
        values[index] = float_word(edit['after'])
    assert visited == {(board, face) for board in BOARDS for face in FACES}
    output = [base[:32]]
    written = set()
    for kind, payload, raw in original.chunks:
        if kind == b'PROP':
            cid = u32(payload)
            name, offset = string(payload, 4)
            if name == 'TextSize' and cid in updates:
                raw = chunk(kind, payload[:offset + 1] + pack_words(updates[cid]))
                written.add((cid, name))
        output.append(raw)
    result = b''.join(output)
    final = Native(result)
    assert original.instances == final.instances and original.parents == final.parents
    assert {key for key, value in original.props.items() if value != final.props[key]} == written
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Reconcile the current canonical map first'
    edits = json.loads((args.directory / 'edits.json').read_text())
    result = refresh(base, edits)
    if args.write:
        proof = json.loads((args.directory / 'verified.json').read_text())
        assert (proof['placeId'], proof['universeId']) == (124078027733625, 10774898335)
        assert (proof['boards'], proof['faces']) == (len(BOARDS), len(edits))
        assert proof['maxFill'] <= .87
        write_snapshot(base, result)
    print(json.dumps({'faces': len(edits), 'sha256': sha256(result).hexdigest(), 'written': args.write}))


if __name__ == '__main__':
    main()
