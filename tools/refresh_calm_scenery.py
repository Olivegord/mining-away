#!/usr/bin/env python3
"""Mirror tools/studio_calm_scenery.lua into the canonical native file.

Darkens the 20 SeamOutcrops unions toward (52,50,54) by half and sets the seven
floor textures to 16-stud tiles at 0.9 transparency. Every other chunk is kept
byte-identical. Dry run by default; --write replaces build/DRONE_GAME.rbxl.
"""
import argparse
import struct
from hashlib import sha256

from build import CANONICAL_OUTPUT, chunk, packstr, string, u32
from refresh_native_scenery import Native, unpack_colors

TARGET, MIX = (52, 50, 54), .5
ROOT = 'Workspace.MiningAway.'
TEXTURES = [ROOT+'Fields.Baseplate.Texture', ROOT+'Map.SimpleFlatTestMap.HubPad.MiningAwayChecker'] + [
    ROOT+f'Fields.CrystalRun.{k}.Field.Texture' for k in ('Quartz', 'Ruby', 'Cobalt', 'Violet', 'Emerald')]
OUTCROPS = ROOT+'Fields.CrystalRun.SeamOutcrops.'


def unpack_floats(data, count):
    out = []
    for i in range(count):
        v = struct.unpack('>I', bytes(data[j*count+i] for j in range(4)))[0]
        v = ((v >> 1) | ((v & 1) << 31)) & 0xffffffff
        out.append(struct.unpack('>f', struct.pack('>I', v))[0])
    return out


def pack_floats(values):
    words = []
    for value in values:
        v = struct.unpack('>I', struct.pack('>f', value))[0]
        words.append(((v << 1) | (v >> 31)) & 0xffffffff)
    raw = [struct.pack('>I', w) for w in words]
    return bytes(raw[i][j] for j in range(4) for i in range(len(raw)))


def mix(value, target):
    return int((value+(target-value)*MIX)+.5)


def calm(base):
    native = Native(base)
    replacements, report = {}, {'outcrops': 0, 'textures': 0}
    colors, floats = {}, {}
    for ref, (cid, cls, index, _) in native.instances.items():
        path = native.path(ref)
        if cls == 'UnionOperation' and path.startswith(OUTCROPS):
            count = len(native.classes[cid][1])
            values = colors.setdefault(cid, unpack_colors(native.prop(cid, 'Color3uint8', 0x1a), count))
            values[index] = tuple(mix(c, t) for c, t in zip(values[index], TARGET))
            report['outcrops'] += 1
        elif cls == 'Texture' and path in TEXTURES:
            count = len(native.classes[cid][1])
            table = floats.setdefault(cid, {k: unpack_floats(native.prop(cid, k, 4), count)
                                            for k in ('StudsPerTileU', 'StudsPerTileV', 'Transparency')})
            assert table['StudsPerTileU'][index] == table['StudsPerTileV'][index] == 8, f'unexpected tiles on {path}'
            table['StudsPerTileU'][index] = table['StudsPerTileV'][index] = 16.0
            table['Transparency'][index] = .9
            report['textures'] += 1
    assert report == {'outcrops': 20, 'textures': 7}, report
    for cid, values in colors.items():
        raw = b''.join(bytes(axis) for axis in zip(*values))
        replacements[cid, 'Color3uint8'] = chunk(b'PROP', struct.pack('<I', cid)+packstr('Color3uint8')+bytes([0x1a])+raw)
    for cid, table in floats.items():
        for name, values in table.items():
            replacements[cid, name] = chunk(b'PROP', struct.pack('<I', cid)+packstr(name)+bytes([4])+pack_floats(values))
    out = [base[:32]]
    used = set()
    for kind, decoded, raw in native.chunks:
        if kind == b'PROP':
            key = (u32(decoded), string(decoded, 4)[0])
            if key in replacements:
                raw = replacements[key];used.add(key)
        out.append(raw)
    assert used == set(replacements)
    return b''.join(out), report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'canonical file changed; re-check before applying'
    result, report = calm(base)
    again = Native(result)
    assert again.instances.keys() == Native(base).instances.keys()
    print(report, 'new sha256', sha256(result).hexdigest())
    if args.write:
        CANONICAL_OUTPUT.write_bytes(result)
        print('Wrote', CANONICAL_OUTPUT)


if __name__ == '__main__':
    main()
