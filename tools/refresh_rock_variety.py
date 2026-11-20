#!/usr/bin/env python3
"""Replace only the authored specimen row, retaining the old row in ServerStorage."""
import argparse
import json
from hashlib import sha256
from pathlib import Path
from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import Native, MAP, MINERAL_LINEUP_SCOPE, write_parents, write_snapshot
from refresh_quarry_blockscape import append_export

def merge(data, directory):
    original = Native(data)
    old = original.one(MAP + '.MineralLineup')
    result = append_export(data, directory, 'archive', 'ServerStorage', 'RockVarietyArchive', {'Folder'})
    current = Native(result)
    archive = current.one('ServerStorage.RockVarietyArchive')
    result = write_parents(current, {**current.parents, old: archive})
    result = append_export(result, directory, 'scenery', MAP, 'MineralLineup', MINERAL_LINEUP_SCOPE['scenery'][2])
    final = Native(result)
    assert original.instances.items() <= final.instances.items()
    assert original.props.items() <= final.props.items()
    assert all(final.parents[r] == (archive if r == old else parent) for r, parent in original.parents.items())
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    for key in ('Amber','Ruby','Quartz','Violet','Diamond'):
        final.one(MAP + '.MineralLineup.' + key + '.SpecimenAnchor')
    final.one(MAP + '.MineralLineup.CoreSpecimen.Shell')
    return result, {'preserved_instances': len(original.instances), 'new_instances': len(final.instances)-len(original.instances), 'preserved_sources': len(script_inventory(final.chunks))}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export_dir',type=Path)
    parser.add_argument('--baseline-sha256',required=True)
    parser.add_argument('--write',action='store_true')
    args=parser.parse_args()
    data=CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest()==args.baseline_sha256, 'Canonical changed'
    result,stats=merge(data,args.export_dir)
    if args.write: write_snapshot(data,result)
    print(json.dumps({**stats,'wrote':args.write,'sha256':sha256(result).hexdigest()},indent=2))
if __name__=='__main__': main()
