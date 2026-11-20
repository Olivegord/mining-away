#!/usr/bin/env python3
"""Mirror the 30-stud starter patch from shared Edit without reserializing the place."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, chunk, script_inventory, string, u32
from refresh_native_scenery import MAP, Native, close, patch_parts, write_parents, write_snapshot
from refresh_quarry_courtyard import pack_floats, unpack_floats
from restore_reference_look import Values

BASELINE = 'd69a8b3eb7c1f577afa1d02bc940212d746b3b7bdb97e655cc8785ac80e909a0'
FIELD = 'Workspace.MiningAway.Fields.Quartz.Field'
PLATE = MAP + '.MiningAwayReferenceGround.Baseplate'
ARCHIVE = 'ServerStorage.PreMiningAwayLook'
TERRACES = MAP + '.DronerevolutionTerraces.'
ARCHIVED = (
    MAP + '.QuarryContinuousGround.Terraces.Quartz',
    *(MAP + '.PlatformSurfaceFill.QuarryContinuousGround_Terraces_Quartz_Turf1_' + str(i)
      for i in (2, 3, 4)),
    TERRACES + 'QuartzTerrace',
    TERRACES + 'WalkableRoutes.QuartzBridge',
    TERRACES + 'WalkableRoutes.QuartzBridgeCurb',
    FIELD + '.TestLabel',
)


def plan_for(n):
    v = Values(n)
    ref = n.one(FIELD)
    before = dict(position=v.get(ref, 'CFrame'), size=v.get(ref, 'size'), color=v.get(ref, 'Color3uint8'))
    plate = n.one(PLATE)
    floor = v.get(plate, 'CFrame')[1] + v.get(plate, 'size')[1] / 2
    x, _, z = before['position']
    # Keep the reference's 2-stud thickness, mostly embedded in the floor,
    # so its visible tinted face avoids flicker and players can walk onto it.
    after = dict(position=[x, floor + .06 - 1, z], size=[30, 2, 30], color=[180, 136, 127])
    moves = []
    for path in ARCHIVED:
        refs = n.paths[path]
        assert len(refs) == (2 if path.endswith('Curb') else 1), path
        for ref in refs:
            cls = n.instances[ref][1]
            row = dict(ref=ref, path=path, cls=cls)
            if cls == 'Part':
                row.update(position=v.get(ref, 'CFrame'), size=v.get(ref, 'size'))
            moves.append(row)
    return dict(field=dict(path=FIELD, **{'class': 'Part'}, anchor=before['position'],
                           before=before, after=after),
                transparency=dict(before=v.get(n.one(FIELD), 'Transparency'), after=.8),
                moves=moves, archive=ARCHIVE, plate=PLATE, floor=floor)


def mirror(n, plan):
    def validate(edit):
        assert edit['path'] == FIELD and edit['after']['size'] == [30, 2, 30]
        assert set(edit['after']) == {'position', 'size', 'color'}

    result, touched = patch_parts(n, [plan['field']], validate_edit=validate)
    scoped = Native(result)
    ref = scoped.one(FIELD)
    cid, _, index, _ = scoped.instances[ref]
    key = cid, 'Transparency'
    edited = [result[:32]]
    for tag, data, raw in scoped.chunks:
        if tag == b'PROP' and (u32(data), string(data, 4)[0]) == key:
            _, off = string(data, 4)
            values = list(unpack_floats(data[off+1:], len(scoped.classes[cid][1])))
            assert values[index] == plan['transparency']['before']
            values[index] = plan['transparency']['after']
            raw = chunk(tag, data[:off+1] + pack_floats(values))
        edited.append(raw)

    scoped = Native(b''.join(edited))
    archive = scoped.one(ARCHIVE)
    moves = {row['ref']: archive for row in plan['moves']}
    final = Native(write_parents(scoped, {**scoped.parents, **moves}))
    assert final.instances == n.instances
    assert all(final.parents[r] == moves.get(r, parent) for r, parent in n.parents.items())
    assert {k for k, value in n.props.items() if final.props[k] != value} == touched | {key}
    assert script_inventory(final.chunks) == script_inventory(n.chunks)
    v = Values(final)
    assert list(v.get(ref, 'size')) == plan['field']['after']['size']
    assert close(v.get(ref, 'CFrame'), plan['field']['after']['position'])
    assert v.get(ref, 'Color3uint8') == tuple(plan['field']['after']['color'])
    assert abs(v.get(ref, 'Transparency') - .8) < 1e-6
    return final.data


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory', type=Path)
    p.add_argument('--write', action='store_true')
    args = p.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == BASELINE, 'Canonical baseline changed; reconcile first'
    n = Native(data)
    plan = plan_for(n)
    args.directory.mkdir(parents=True, exist_ok=True)
    template = Path(__file__).with_name('studio_starter_patch.lua').read_text()
    (args.directory / 'stage.lua').write_text(template.replace('[==[PLAN_JSON]==]',
        '[==[' + json.dumps(plan, separators=(',', ':')) + ']==]'))
    result = mirror(n, plan)
    if args.write:
        receipt = json.loads((args.directory / 'verified.json').read_text())
        assert (receipt['place'], receipt['universe']) == (124078027733625, 10774898335)
        assert receipt['size'] == [30, 2, 30] and receipt['probes'] == 1089
        assert receipt['baseplateHits'] == 864 and receipt['fieldHits'] == 225
        assert receipt['archived'] == len(plan['moves'])
        write_snapshot(data, result)
    print(json.dumps(dict(sha256=sha256(result).hexdigest(), size=plan['field']['after']['size'],
                          archived=len(plan['moves']), wrote=args.write), indent=2))


if __name__ == '__main__':
    main()
