#!/usr/bin/env python3
"""Mirror only the world poses of the existing mineral display parts."""
import argparse
from collections import defaultdict
from hashlib import sha256
import json
from pathlib import Path
import struct

from build import CANONICAL_OUTPUT, chunk, string, u32
from refresh_native_scenery import MAP, Native, close, pack_vectors, split_cframe, unpack_vectors, write_snapshot

ROW = MAP + '.MineralLineup.'


def mirror(data, edits):
    native = Native(data)
    targets = {p for p, refs in native.paths.items() if p.startswith(ROW)
               and native.instances[refs[0]][1] in {'Part', 'UnionOperation'} and not p.endswith('.CoreGeometry')}
    assert len(edits) == len(targets) == 22 and {e['path'] for e in edits} == targets
    updates = defaultdict(dict)
    for e in edits:
        cid, cls, index, _ = native.instances[native.one(e['path'])]
        assert cls == e['class']
        before, after = e['before'], e['after']
        assert len(before) == len(after) == 12
        x, y, z = before[:3]
        assert close((after[0], after[2]), (44+z, -5-x))
        assert -.021 <= after[1]-y <= .061
        # The export must be a +90° yaw, preserving each part's local rotation.
        assert close(after[3:], (*before[9:12], *before[6:9], *(-v for v in before[3:6])))
        updates[cid][index] = (before, after)

    output = [data[:32]]
    touched = set()
    for kind, payload, raw in native.chunks:
        if kind == b'PROP' and u32(payload) in updates:
            cid = u32(payload)
            name, offset = string(payload, 4)
            if name == 'CFrame':
                count = len(native.classes[cid][1])
                prefix, coords = split_cframe(native.prop(cid, name, 0x10), count)
                positions = unpack_vectors(coords, count)
                cursor = 0
                rotations = []
                for i in range(count):
                    end = cursor + (1 if prefix[cursor] else 37)
                    encoded = prefix[cursor:end]
                    cursor = end
                    if i in updates[cid]:
                        before, after = updates[cid][i]
                        assert close(positions[i], before[:3]), 'Native and Studio disagree on old position'
                        if encoded[0] == 0:
                            assert close(struct.unpack('<9f', encoded[1:]), before[3:])
                        else:
                            # Only the unrotated pads use a compressed rotation.
                            assert encoded == b'\x02' and close(before[3:], (1,0,0,0,1,0,0,0,1))
                        positions[i] = after[:3]
                        encoded = b'\0' + struct.pack('<9f', *after[3:])
                    rotations.append(encoded)
                raw = chunk(kind, payload[:offset+1]+b''.join(rotations)+pack_vectors(positions))
                touched.add(cid)
        output.append(raw)
    assert touched == updates.keys()
    result = b''.join(output)
    check = Native(result)
    assert check.instances == native.instances and check.parents == native.parents
    assert {key for key in native.props if native.props[key] != check.props[key]} == {(cid,'CFrame') for cid in touched}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256
    result = mirror(data, json.loads(args.export.read_text()))
    if args.write:
        write_snapshot(data, result)
    print(json.dumps({'moved':22,'written':args.write,'sha256':sha256(result).hexdigest()}))


if __name__ == '__main__':
    main()
