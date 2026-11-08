"""Mirror only the reviewed existing workshop labels/prompts; no geometry or Sources."""
import argparse,json
from hashlib import sha256
from pathlib import Path
from build import CANONICAL_OUTPUT,chunk,string,u32,string_values,packstr,script_inventory
from refresh_native_scenery import Native,MAP,write_snapshot

def refresh(data,plan):
 assert sha256(data).hexdigest()==plan['baseline'],'Native changed; reconcile before refreshing labels'
 original=Native(data);updates={}
 allowed={'Text','Enabled','ObjectText','ActionText'}
 for e in plan['properties']:
  path,prop=e['path'],e['property']
  assert path.startswith(MAP+'.') and prop in allowed
  assert any('.'+key+'.' in path for key in ('QuartzShop','RubyShop','CobaltShop','VioletShop','EmeraldShop','PackStation','Printer'))
  ref=original.one(path);cid,cls,i,_=original.instances[ref]
  assert (cls=='TextLabel' and prop=='Text') or (cls=='ProximityPrompt' and prop in allowed-{'Text'})
  dtype,raw=original.props[cid,prop];assert dtype in (1,2)
  values=updates.setdefault((cid,prop),[v.decode() for v in string_values(raw,0,len(original.classes[cid][1]))] if dtype==1 else [bool(v) for v in raw])
  assert values[i]==e['before'],(path,prop,values[i],e['before'])
  values[i]=e['after']
 out=[data[:32]];written=set()
 for kind,payload,raw in original.chunks:
  if kind==b'PROP':
   cid=u32(payload);prop,off=string(payload,4);key=(cid,prop)
   if key in updates:
    values=updates[key];encoded=b''.join(packstr(v) for v in values) if payload[off]==1 else bytes(values)
    raw=chunk(kind,payload[:off+1]+encoded);written.add(key)
  out.append(raw)
 result=b''.join(out);final=Native(result)
 assert written==updates.keys()
 assert original.instances==final.instances and original.parents==final.parents
 assert {k for k,v in original.props.items() if final.props[k]!=v}<=written
 assert script_inventory(original.chunks)==script_inventory(final.chunks)
 return result,{'properties':len(plan['properties']),'preserved_sources':len(script_inventory(final.chunks)),'sha256':sha256(result).hexdigest()}
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('plan',type=Path);a.add_argument('--write',action='store_true');args=a.parse_args()
 base=CANONICAL_OUTPUT.read_bytes();out,report=refresh(base,json.loads(args.plan.read_text()))
 if args.write:write_snapshot(base,out)
 print(json.dumps(dict(report,wrote=args.write),indent=2))
