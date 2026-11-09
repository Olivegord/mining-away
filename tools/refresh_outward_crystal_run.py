#!/usr/bin/env python3
"""Mirror the outward route from a verified, scoped Studio Edit export."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, close, merge, patch_parts, write_parents, write_snapshot
from restore_reference_look import Values

RUN = MAP + '.CrystalRun'
ARCHIVE = 'ServerStorage.PreOutwardCrystalRun'
GROVE = MAP + '.MiningAwayReferenceGround.OriginalGrove.'
PIERS = RUN + '.OverlookPiers'
OVERLOOK = MAP + '.DronerevolutionTerraces.NorthOverlook'
ZONES = ('Quartz', 'Ruby', 'Cobalt', 'Violet', 'Emerald')
CHARGER = ('ChargingStation', 'ChargeIndicator', 'ChargingSign')


def check_edit(edit):
    path = edit['path']
    before, after = edit['before'], edit['after']
    assert edit['class'] == 'Part' and close(edit['anchor'], before['position'])
    x, y, z = before['position']
    if path.startswith(GROVE):
        assert set(before) == set(after) == {'position'}
        assert close(after['position'], (x-124, y, z))
    else:
        assert path == PIERS + '.Pier'
        assert set(before) == set(after) == {'position', 'size'}
        w, h, d = before['size']
        assert close(after['position'], (x, y-.12, z)) and close(after['size'], (w, h+.24, d))


def mirror(base, directory):
    original = Native(base)
    edits = json.loads((directory/'translations.json').read_text())
    assert sum(e['path'].startswith(GROVE) for e in edits) == 19 and len(edits) == 23
    patched, touched = patch_parts(original, edits, validate_edit=check_edit)
    old = original.one(RUN)
    kept = {name: original.one(RUN+'.'+name) for name in CHARGER}
    piers = original.one(PIERS)
    staged, _ = merge(patched, directory, addition={'archive': ('ServerStorage', {'PreOutwardCrystalRun'}, {'Folder'})})
    n = Native(staged)
    moved = {old: n.one(ARCHIVE), piers: n.one(OVERLOOK)}
    staged = write_parents(n, {**n.parents, **moved})
    staged, _ = merge(staged, directory, addition={'route': (MAP, {'CrystalRun'}, {'Folder','Part','SurfaceGui','TextLabel','Texture'})})
    n = Native(staged)
    moved.update({ref: n.one(RUN) for ref in kept.values()})
    final = Native(write_parents(n, {**n.parents, **moved}))
    assert original.instances.items() <= final.instances.items()
    assert all(final.parents[ref] == moved.get(ref, p) for ref, p in original.parents.items())
    assert {key for key, value in original.props.items() if final.props[key] != value} == touched
    scripts = script_inventory(final.chunks)
    assert script_inventory(original.chunks) == scripts
    vals = Values(final)
    for i, zone in enumerate(ZONES):
        path = RUN+'.'+zone
        field = final.one(path+'.Field')
        assert close(vals.get(field,'CFrame'), (0,3.74,158+i*64))
        assert close(vals.get(field,'size'), (108,.6,64))
        texture = final.one(path+'.Field.Texture')
        assert vals.get(texture,'Texture') == 'rbxassetid://6372755229'
        assert all(vals.get(texture,k) == 8 for k in ('StudsPerTileU','StudsPerTileV'))
        for j in range(1,4):
            assert close(vals.get(final.one(path+f'.Patch{j}'),'size'), (30,2,30))
        if i:
            for name in ('WestWall','EastWall'):
                assert vals.get(final.one(path+'.'+name),'CFrame')[2] == 126+i*64
    return final.data, dict(scenery_added=len(final.instances)-len(original.instances), old_instances_moved=len(moved),
                            parts_adjusted=len(edits), preserved_sources=len(scripts), sha256=sha256(final.data).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Canonical map changed after staging'
    result, report = mirror(base, args.directory)
    if args.write:
        edit = json.loads((args.directory/'verified.json').read_text())
        assert (edit['id'],edit['universe']) == (124078027733625,10774898335)
        assert (edit['fields'],edit['patches'],edit['firstZ'],edit['lastZ']) == (5,15,126,446)
        assert edit['bedChecks'] >= 600 and edit['patchChecks'] == 375 and edit['aisleChecks'] >= 100
        write_snapshot(base, result)
    print(json.dumps({**report,'written':args.write}))


if __name__ == '__main__':
    main()
