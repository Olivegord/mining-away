#!/usr/bin/env python3
"""Save outer basin slopes and grass crowns, preserving the gameplay map."""
import argparse,json,re
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT,script_inventory
from refresh_native_scenery import Native,MAP,write_snapshot
from refresh_quarry_sunshine import merge as patch
from refresh_quarry_blockscape import append_export
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
def check(e):
 assert re.fullmatch(re.escape(MAP)+r'\.QuarryBlockRim\.(WestEscarpment|EastChalkRim|NorthCrown|SouthwestGate|SoutheastGate)\.BasalRock',e['path'])
 assert e['before'].keys()==e['after'].keys()=={'position','size'}
 assert e['after']['size'][1]<=e['before']['size'][1]
 assert abs(e['before']['position'][1]-e['before']['size'][1]/2-e['after']['position'][1]+e['after']['size'][1]/2)<.001
original=CANONICAL_OUTPUT.read_bytes();assert sha256(original).hexdigest()=='01489d80d52b7e3281275187c13fb49b2647f147f946b9eaeba12a70ec29cf94'
e=json.loads((a.directory/'edits.json').read_text());assert not e['properties']
result,report=patch(original,e,check)
base=Native(result)
result=append_export(result,a.directory,'scenery',MAP,'QuarryBasinFoothills',{'Folder','Model','Part','WedgePart','SpecialMesh'})
final=Native(result)
assert base.instances.items()<=final.instances.items() and base.parents.items()<=final.parents.items()
assert all(final.props[k]==v for k,v in base.props.items())
assert script_inventory(final.chunks)==script_inventory(base.chunks)
if a.write:write_snapshot(original,result)
print(json.dumps({'lowered_wall_parts':len(e['parts']),'added_instances':len(final.instances)-len(base.instances),'wrote':a.write,'sha256':sha256(result).hexdigest()}))
