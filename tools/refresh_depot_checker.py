#!/usr/bin/env python3
"""Mirror the original checker onto the depot's authored walking surfaces."""
import argparse
from hashlib import sha256
import json
import math
from pathlib import Path

from build import CANONICAL_OUTPUT, chunk, script_inventory, string, u32
from import_lighting import pack_words, words
from refresh_native_scenery import MAP, Native, merge, patch_parts, write_parents, write_snapshot
from refresh_sign_lettering import float_word
from restore_reference_look import Values


MARKET = f'{MAP}.DronerevolutionTerraces.MarketSquare'
FILL = f'{MAP}.PlatformSurfaceFill.DronerevolutionTerraces_MarketSquare_'
BASEPLATE = f'{MAP}.MiningAwayReferenceGround.Baseplate'
HUB = f'{MAP}.SimpleFlatTestMap.HubPad'
DECK = f'{MAP}.DronerevolutionTerraces.LogisticsApron.ServiceDeck'
ROUTES = [f'{MARKET}.{name}' for name in ('ShopApron', 'NorthSouthWalk', 'EastWestWalk', 'UtilityWalk')]
ROUTES += [FILL + name for name in ('EastWestWalk_2', 'EastWestWalk_3', 'UtilityWalk_2', 'UtilityWalk_3')]
TEXTURES = {'Checker' + path.rsplit('.', 1)[1]: path for path in ROUTES}
TINT = (109, 106, 105)


def align_existing(native):
    prop = 'OffsetStudsU'
    updates = {}
    for surface, offset in ((HUB, 6), (DECK, 5)):
        cid, cls, index, _ = native.instances[native.one(surface + '.MiningAwayChecker')]
        assert cls == 'Texture'
        if cid not in updates:
            updates[cid] = words(native.prop(cid, prop, 4), len(native.classes[cid][1]))
        values = updates[cid]
        assert values[index] == 0
        values[index] = float_word(offset)
    output = [native.data[:32]]
    for kind, payload, raw in native.chunks:
        if kind == b'PROP' and (cid := u32(payload)) in updates:
            name, offset = string(payload, 4)
            if name == prop:
                raw = chunk(kind, payload[:offset+1] + pack_words(updates[cid]))
        output.append(raw)
    return b''.join(output), {(cid, prop) for cid in updates}


def refresh(base, directory):
    original = Native(base)
    values = Values(original)
    edits = []
    for path in ROUTES:
        ref = original.one(path)
        color = values.get(ref, 'Color3uint8')
        expected = TINT if 'UtilityWalk' in path else (163, 162, 165)
        assert tuple(color) == expected
        if expected != TINT:
            edits.append({'path': path, 'class': 'Part', 'anchor': values.get(ref, 'CFrame'),
                          'before': {'color': color}, 'after': {'color': TINT}})
    tinted, touched = patch_parts(original, edits, validate_edit=lambda edit: None)
    aligned, phase = align_existing(Native(tinted))
    staged, stats = merge(aligned, directory, addition={'scenery': (MAP, set(TEXTURES), {'Texture'})})
    native = Native(staged)
    parents = {native.one(f'{MAP}.{name}'): native.one(path) for name, path in TEXTURES.items()}
    final = Native(write_parents(native, {**native.parents, **parents}))
    assert stats['new_instances'] == 8
    assert original.instances.items() <= final.instances.items()
    assert all(final.parents[ref] == parent for ref, parent in original.parents.items())
    assert {k for k, value in original.props.items() if final.props[k] != value} == touched | phase
    assert script_inventory(original.chunks) == script_inventory(final.chunks)

    values = Values(final)
    texture = final.one(BASEPLATE + '.Texture')
    paths = {f'{parent}.{name}': parent for name, parent in TEXTURES.items()}
    paths.update({f'{surface}.MiningAwayChecker': surface for surface in (HUB, DECK)})
    for path, parent in paths.items():
        tex_ref, part_ref = final.one(path), final.one(parent)
        assert final.parents[tex_ref] == part_ref
        assert all(values.get(tex_ref, prop) == values.get(texture, prop)
                   for prop in ('Texture', 'Transparency', 'Color3', 'StudsPerTileU', 'StudsPerTileV'))
        tex_cid, _, tex_index, _ = final.instances[tex_ref]
        face = words(final.prop(tex_cid, 'Face', 0x12), len(final.classes[tex_cid][1]))[tex_index]
        assert face == 1  # Enum.NormalId.Top
        center, size = values.get(part_ref, 'CFrame'), values.get(part_ref, 'size')
        for axis, prop in ((0, 'OffsetStudsU'), (2, 'OffsetStudsV')):
            corner = center[axis] - size[axis] / 2
            assert math.isclose(math.remainder(values.get(tex_ref, prop)-corner, 8), 0, abs_tol=.001)
    return final.data, dict(stats, parts_updated=len(edits), phase_adjustments=2)


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
        assert (proof['textures'], proof['phaseAdjustments'], proof['floorSamples'], proof['tile']) == (8, 2, 221, 8)
        write_snapshot(base, result)
    print(json.dumps(dict(stats, sha256=sha256(result).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
