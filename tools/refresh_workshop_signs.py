"""Mirror reviewed workshop labels and the two authored depot nameplates."""
import argparse,json
from hashlib import sha256
from pathlib import Path
from build import CANONICAL_OUTPUT,chunk,string,u32,string_values,packstr,script_inventory
from import_lighting import words
from refresh_native_scenery import Native,MAP,merge,write_snapshot

DEPOT_LABELS={
 MAP+'.SimpleFlatTestMap.PackStationAssembly.PackStation.TestLabel',
 MAP+'.SimpleFlatTestMap.PrestigeStationAssembly.PrestigeStation.TestLabel',
}
DEPOT_PLATES={'scenery':(MAP,{'DepotStationPlates'},{'Folder','Part','SurfaceGui','TextLabel'})}
RETURN_LABEL=MAP+'.CrystalRun.DepotWayfinder.Board.Sign.TextLabel'

def refresh(data,plan):
 assert sha256(data).hexdigest()==plan['baseline'],'Native changed; reconcile before refreshing labels'
 original=Native(data);updates={}
 allowed={'Text','Enabled','ObjectText','ActionText'}
 for e in plan['properties']:
  path,prop=e['path'],e['property']
  assert path.startswith(MAP+'.') and prop in allowed
  if path==RETURN_LABEL:
   assert e['face']=='Back' and prop=='Text' and e['before']=='CRYSTAL RUN  ↑' and e['after']=='←  PACK COUNTER'
   faces=[]
   for candidate in original.paths[path]:
    parent_class,cls,parent_index,_=original.instances[original.parents[candidate]]
    assert cls=='SurfaceGui'
    face=words(original.prop(parent_class,'Face',0x12),len(original.classes[parent_class][1]))[parent_index]
    if face==2:  # Enum.NormalId.Back
     faces.append(candidate)
   assert len(faces)==1
   ref=faces[0]
  else:
   ref=original.one(path)
  cid,cls,i,_=original.instances[ref]
  if path==RETURN_LABEL:
   assert cls=='TextLabel'
  elif cls=='BillboardGui':
   assert path in DEPOT_LABELS and prop=='Enabled' and e['before'] is True and e['after'] is False
  else:
   assert any('.'+key+'.' in path for key in ('QuartzShop','RubyShop','CobaltShop','VioletShop','EmeraldShop','PackStation','Printer'))
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
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('plan',type=Path)
 parser.add_argument('--plates',type=Path,help='Directory containing the native depot plate export')
 parser.add_argument('--write',action='store_true')
 args=parser.parse_args()
 base=CANONICAL_OUTPUT.read_bytes()
 plan=json.loads(args.plan.read_text())
 out,report=refresh(base,plan)
 if args.plates:
  assert len(plan['properties'])==3
  assert {e['path'] for e in plan['properties']}==DEPOT_LABELS|{RETURN_LABEL}
  out,stats=merge(out,args.plates,addition=DEPOT_PLATES)
  assert stats['new_instances']==11
  report.update(stats,sha256=sha256(out).hexdigest())
 if args.write:
  write_snapshot(base,out)
 print(json.dumps(dict(report,wrote=args.write),indent=2))


if __name__=='__main__':
 main()
