#!/usr/bin/env python3
"""Mirror scoped native lettering edits on the authored Crystal Run sign faces."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import struct

from build import CANONICAL_OUTPUT, chunk, packstr, script_inventory, string, string_values, u32
from import_lighting import pack_words, words
from refresh_native_scenery import MAP, Native, write_snapshot

RUN = f'{MAP}.CrystalRun'
ZONES = ('Quartz', 'Ruby', 'Cobalt', 'Violet', 'Emerald')
BOARDS = {
    f'{RUN}.{zone}.ZoneSign': (37, 64)
    for zone in ZONES
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


def face_label(native, path, face):
    matches = []
    for ref in native.paths[path]:
        cid, cls, index, _ = native.instances[native.parents[ref]]
        assert cls == 'SurfaceGui'
        count = len(native.classes[cid][1])
        if words(native.prop(cid, 'Face', 0x12), count)[index] == FACES[face]:
            matches.append(ref)
    assert len(matches) == 1
    cid, cls, index, _ = native.instances[matches[0]]
    assert cls == 'TextLabel'
    return cid, index, len(native.classes[cid][1])


def rewrite(original, updates):
    output = [original.data[:32]]
    written = set()
    for kind, payload, raw in original.chunks:
        if kind == b'PROP':
            name, offset = string(payload, 4)
            key = (u32(payload), name)
            if key in updates:
                raw = chunk(kind, payload[:offset + 1] + updates[key])
                written.add(key)
        output.append(raw)
    result = b''.join(output)
    final = Native(result)
    assert original.instances == final.instances and original.parents == final.parents
    assert {key for key, value in original.props.items() if value != final.props[key]} == written == updates.keys()
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    return result


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
        cid, index, count = face_label(original, path, face)
        labels = string_values(original.prop(cid, 'Text', 1), 0, count)
        assert labels[index].decode() == edit['text']
        values = updates.setdefault(cid, words(original.prop(cid, 'TextSize', 4), count))
        assert values[index] == float_word(edit['before'])
        values[index] = float_word(edit['after'])
    assert visited == {(board, face) for board in BOARDS for face in FACES}
    return rewrite(original, {(cid, 'TextSize'): pack_words(values) for cid, values in updates.items()})


def refresh_payouts(base, edits):
    native = Native(base)
    expected = {
        f'{RUN}.{zone}.ZoneSign.Sign.TextLabel': f'{number:02d}   {zone.upper()}'
        for number, zone in enumerate(ZONES, 1)
    }
    text, sizes, rich, payouts, visited = {}, {}, {}, {}, set()
    for edit in edits:
        path, face = edit['path'], edit['face']
        assert (path, face) not in visited
        visited.add((path, face))
        old = expected[path]
        assert edit['before'] == old and edit['min'] > 0 and edit['max'] >= edit['min']
        payout = f"{edit['min']:,}" if edit['min'] == edit['max'] else f"{edit['min']:,}–{edit['max']:,}"
        assert payouts.setdefault(path, payout) == payout
        new = f'<font size="64">{old}</font>\n{payout} QUARTZ / ROCK'
        assert edit['after'] == new
        cid, index, count = face_label(native, path, face)
        if cid not in text:
            text[cid] = [value.decode() for value in string_values(native.prop(cid, 'Text', 1), 0, count)]
            sizes[cid] = words(native.prop(cid, 'TextSize', 4), count)
            rich[cid] = bytearray(native.prop(cid, 'RichText', 2))
        assert text[cid][index] == old and sizes[cid][index] == float_word(64) and rich[cid][index] == 0
        text[cid][index] = new
        sizes[cid][index] = float_word(34)
        rich[cid][index] = 1
    assert visited == {(path, face) for path in expected for face in FACES}
    updates = {}
    for cid in text:
        updates[cid, 'Text'] = b''.join(packstr(value) for value in text[cid])
        updates[cid, 'TextSize'] = pack_words(sizes[cid])
        updates[cid, 'RichText'] = bytes(rich[cid])
    return rewrite(native, updates)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--payouts', action='store_true', help='Mirror the base payout line on the five field boards')
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Reconcile the current canonical map first'
    edits = json.loads((args.directory / 'edits.json').read_text())
    result = refresh_payouts(base, edits) if args.payouts else refresh(base, edits)
    if args.write:
        proof = json.loads((args.directory / 'verified.json').read_text())
        assert (proof['placeId'], proof['universeId']) == (124078027733625, 10774898335)
        if args.payouts:
            assert (proof['boards'], proof['faces']) == (len(ZONES), len(edits))
            assert proof['edits'] == edits and proof['minVerticalRoom'] >= 12
        else:
            assert (proof['boards'], proof['faces']) == (len(BOARDS), len(edits))
            assert proof['maxFill'] <= .87
        write_snapshot(base, result)
    print(json.dumps({'faces': len(edits), 'sha256': sha256(result).hexdigest(), 'written': args.write}))


if __name__ == '__main__':
    main()
