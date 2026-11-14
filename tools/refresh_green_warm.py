#!/usr/bin/env python3
"""Save only richer grass and warm dirt tints; retain materials and lighting."""
import argparse,json
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT
from refresh_native_scenery import MAP,write_snapshot,Native,split_cframe,unpack_vectors,unpack_colors,close
from refresh_quarry_sunshine import merge
p=argparse.ArgumentParser();p.add_argument('export',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
def check(e):
 assert e['path'].startswith(MAP+'.')
 assert e['before'].keys()==e['after'].keys()=={'color'}
data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()=='1478aa676449c2bc63a86c11d1a6a917bf6c0a252487bbdfbb4e006d23e7e7f1'
e=json.loads(a.export.read_text());assert not e['properties']
n=Native(data);cache={}
for edit in e['parts']:
 for ref in n.paths[edit['path']]:
  cid,_,i,_=n.instances[ref];count=len(n.classes[cid][1])
  if cid not in cache:
   _,coords=split_cframe(n.prop(cid,'CFrame',16),count)
   cache[cid]=(unpack_vectors(coords,count),unpack_colors(n.prop(cid,'Color3uint8',26),count))
  positions,colors=cache[cid]
  if not close(positions[i],edit['anchor']):continue
  actual=list(colors[i]);assert max(abs(x-y) for x,y in zip(actual,edit['before']['color']))<=1,(edit['path'],actual,edit['before'])
  edit['before']['color']=actual;break
result,report=merge(data,e,check)
if a.write:write_snapshot(data,result)
print(json.dumps(dict(report,wrote=a.write,sha256=sha256(result).hexdigest())))
