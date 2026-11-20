#!/usr/bin/env python3
"""Restore original foliage/bark finishes, retaining only brighter part tints."""
import argparse,json
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT,chunk,packstr,string,u32,string_values
from refresh_native_scenery import write_snapshot,MAP,Native,split_cframe,unpack_vectors,unpack_colors,close
from refresh_quarry_sunshine import merge
p=argparse.ArgumentParser();p.add_argument('export',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
def check(e):
 assert e['path'].startswith(MAP+'.QuarryContinuousGround.OriginalDetails.') or e['path'].startswith(MAP+'.QuarryCourtyard.')
 assert e['before']['variant'] in {'QuarryPack_Leaf','QuarryPack_Trunk'}
 assert e['after']['variant'].startswith(('QuarryFoliage_','QuarryPalette_'))
 assert e['after'].keys()==e['before'].keys()=={'color','variant'}
data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()=='0f8002c4bdf9685bc70071a39241121077da3c63835b188662c67748592e6987'
e=json.loads(a.export.read_text());assert not e['properties']
n=Native(data);old=Native(Path('/private/tmp/pre-pack-native.bin').read_bytes());updates={};used=set();cache={}
for edit in e['parts']:
 check(edit)
 for ref in n.paths[edit['path']]:
  if ref in used:continue
  cid,_,i,_=n.instances[ref];count=len(n.classes[cid][1])
  if cid not in cache:
   _,coords=split_cframe(n.prop(cid,'CFrame',16),count)
   cache[cid]=(unpack_vectors(coords,count),[v.decode() for v in string_values(old.prop(cid,'MaterialVariantSerialized',1),0,count)])
  pos,variants=cache[cid]
  if close(pos[i],edit['anchor']) and variants[i]==edit['after']['variant']:break
 else:raise AssertionError(edit['path'])
 used.add(ref)
 for prop in ['MaterialVariantSerialized','Color3uint8']:
  key=(cid,prop)
  if key not in updates:updates[key]=([v.decode() for v in string_values(n.prop(cid,prop,1),0,count)] if prop=='MaterialVariantSerialized' else list(unpack_colors(n.prop(cid,prop,26),count)))
  updates[key][i]=edit['after']['variant'] if prop=='MaterialVariantSerialized' else edit['after']['color']
out=[data[:32]]
for kind,payload,raw in n.chunks:
 if kind==b'PROP':
  name,off=string(payload,4);key=(u32(payload),name)
  if key in updates:
   vals=updates[key];encoded=b''.join(packstr(v) for v in vals) if name=='MaterialVariantSerialized' else b''.join(bytes(axis) for axis in zip(*vals))
   raw=chunk(kind,payload[:off+1]+encoded)
 out.append(raw)
result=b''.join(out);report={'restored_parts':len(used)}
from build import script_inventory
final=Native(result)
assert final.instances==n.instances and final.parents==n.parents
assert {k for k,v in n.props.items() if final.props[k]!=v}<=updates.keys()
assert script_inventory(final.chunks)==script_inventory(n.chunks)
if a.write:write_snapshot(data,result)
print(json.dumps(dict(report,wrote=a.write,sha256=sha256(result).hexdigest())))
