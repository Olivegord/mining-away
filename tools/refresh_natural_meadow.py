#!/usr/bin/env python3
"""Restore the prior palette and append checked, authored meadow planting."""
import argparse,json
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT,script_inventory
from refresh_native_scenery import Native,MAP,write_snapshot,unpack_colors
from refresh_quarry_blockscape import append_export
from refresh_quarry_sunshine import merge as patch
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--previous-palette',type=Path,required=True);p.add_argument('--write',action='store_true');a=p.parse_args()
data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()=='2beb2d81c315376973c205062c7e5208849189d047f9580825093d777b8192f3'
prior=a.previous_palette.read_bytes();assert sha256(prior).hexdigest()=='1478aa676449c2bc63a86c11d1a6a917bf6c0a252487bbdfbb4e006d23e7e7f1'
n,old=Native(data),Native(prior)
assert n.instances==old.instances and n.parents==old.parents
assert all(key[1]=='Color3uint8' for key,value in n.props.items() if old.props[key]!=value)
allowed={'Folder','Model','Part','WedgePart','MeshPart','UnionOperation','SpecialMesh','PointLight','SurfaceGui','Frame','UIGradient','Weld','WeldConstraint'}
def validate(e):
 assert e['path'].startswith(MAP+'.QuarryMeadowLayers.')
 assert e['before'].keys()==e['after'].keys()=={'color'}
pops=json.loads((a.directory/'pops.json').read_text());assert len(pops['parts'])==7 and not pops['properties']
for e in pops['parts']:
 cid,_,i,_=old.instances[old.one(e['path'])];c=list(unpack_colors(old.prop(cid,'Color3uint8',26),len(old.classes[cid][1]))[i])
 assert max(abs(a-b) for a,b in zip(c,e['before']['color']))<=1
 e['before']['color']=c
prior,_=patch(prior,pops,validate)
old=Native(prior)
result=append_export(prior,a.directory,'scenery',MAP,'QuarryNaturalMeadow',allowed)
final=Native(result)
assert old.instances.items()<=final.instances.items() and old.parents.items()<=final.parents.items()
assert all(final.props[k]==v for k,v in old.props.items())
assert script_inventory(final.chunks)==script_inventory(n.chunks)
if a.write:write_snapshot(data,result)
print(json.dumps({'new_instances':len(final.instances)-len(old.instances),'preserved_sources':len(script_inventory(final.chunks)),'wrote':a.write,'sha256':sha256(result).hexdigest()}))
