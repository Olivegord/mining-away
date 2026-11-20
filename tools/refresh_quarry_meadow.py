#!/usr/bin/env python3
"""Save the rectangular meadow layers and scoped daylight/palette edits."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, write_snapshot
from refresh_quarry_sunshine import merge as edit_properties, ALLOWED
from refresh_quarry_blockscape import append_export

def validate_part(e):
    allowed=(r'QuarryContinuousGround\.Terraces\.(Quartz|Impact|Ruby|Cobalt|Violet|Emerald)\.Turf\d+',r'SimpleFlatTestMap\.HubPad',r'DronerevolutionTerraces\.MarketGardens\.GardenSoil',r'QuarryCourtyard\.(Hub|Quartz|Impact|Ruby|Cobalt|Violet|Emerald)\.CrossFlowers\.Petals')
    assert any(re.fullmatch(re.escape(MAP)+r'\.'+p,e['path']) for p in allowed),e['path']
    assert e['before'].keys()==e['after'].keys()=={'color'}

def merge(data,directory):
    allowed={k:set(v) for k,v in ALLOWED.items()}
    allowed['Lighting']|={'EnvironmentDiffuseScale','EnvironmentSpecularScale'}
    edited,report=edit_properties(data,json.loads((directory/'edits.json').read_text()),validate_part,allowed)
    result=append_export(edited,directory,'scenery',MAP,'QuarryMeadowLayers',{'Folder','Part','Texture'})
    old,new=Native(data),Native(result)
    assert old.instances.items()<=new.instances.items() and old.parents.items()<=new.parents.items()
    assert script_inventory(old.chunks)==script_inventory(new.chunks)
    report['surface_parts']=report.pop('tree_parts')
    report['new_instances']=len(new.instances)-len(old.instances)
    return result,report

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--baseline-sha256',required=True);p.add_argument('--write',action='store_true');a=p.parse_args()
    data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()==a.baseline_sha256
    result,report=merge(data,a.directory)
    if a.write:write_snapshot(data,result)
    print(json.dumps(dict(report,wrote=a.write,sha256=sha256(result).hexdigest())))
