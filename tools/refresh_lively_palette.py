#!/usr/bin/env python3
"""A restrained regional color pass, preserving all textures, geometry and Sources.

Prepare, run stage.lua in Edit, call shared.LivelyPalette.apply(), inspect, then
repeat with --write. No native tests, new instances, or publication are performed.
"""
import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import Native, MAP, write_snapshot
from restore_reference_look import Values, LUA, merged

REGIONS={
 'Quartz': ((157,218,139),(163,151,177),(218,211,196)),
 'Impact': ((183,214,122),(191,150,108),(222,207,179)),
 'Ruby': ((175,207,123),(188,125,126),(206,186,178)),
 'Cobalt': ((133,208,179),(119,167,186),(182,207,210)),
 'Violet': ((163,207,157),(166,143,190),(199,185,216)),
 'Emerald': ((134,218,169),(215,222,185),(211,225,207)),
}
LEAF_VARIANTS={'QuarryFoliage_Canopy','QuarryFoliage_Evergreen','QuarryPalette_LeafClumps','QuarryPalette_LeafStipple','QuarryPalette_LeafRibs'}
def blend(a,b,t): return tuple(round(x*(1-t)+y*t) for x,y in zip(a,b))

def prepare(data):
 n=Native(data);v=Values(n);parts=[];counts=Counter()
 for ref,(cid,cls,i,name) in n.instances.items():
  path=n.path(ref)
  if cls not in {'Part','WedgePart'} or not path.startswith(MAP+'.'):continue
  if path.startswith(MAP+'.JunkCubeAreas.') or '.Oddities.' in path:continue
  old=v.get(ref,'Color3uint8');variant=v.get(ref,'MaterialVariantSerialized');new=None;category=None
  pos=v.get(ref,'CFrame')
  region=next((key for key in REGIONS if '.'+key+'.' in path or '.'+key+'_' in path),None)
  if '.QuarryContinuousGround.Terraces.' in path:
   region=path.split('.Terraces.')[1].split('.')[0]
   new=REGIONS[region][0 if name.startswith('Turf') else 1];category='terraces'
  elif '.QuarryMeadowLayers.' in path and variant.startswith('QuarryRestoredTurf'):
   # Alternate authored patches remain visible without a checkerboard recolor.
   new=blend(old,REGIONS.get(region,REGIONS['Quartz'])[0],.32);category='raised grass patches'
  elif variant.startswith('QuarryRestoredTurf'):
   new=blend(old,REGIONS.get(region,REGIONS['Quartz'])[0],.22);category='supporting grass'
  elif variant in LEAF_VARIANTS:
   # Preserve blue/coral mushrooms and existing regional leaf colors. Cooler
   # secondary foliage balances the warmer grass; no all-over neon tint.
   if old[1]>old[0]*.97 and old[1]>old[2]:
    target=(157,209,133) if sum(path.rsplit('.',1)[0].encode())%4 else (113,192,158)
    new=blend(old,target,.24);category='foliage'
  if new is not None and new!=old:
   parts.append(dict(ref=ref,path=path,**{'class':cls},anchor=pos,size=v.get(ref,'size'),before={'color':old},after={'color':new}))
   counts[category]+=1
 for region,palette in REGIONS.items():
  key='ImpactTest' if region=='Impact' else region
  path='Workspace.MiningAway.Fields.'+key+'.Field';ref=n.one(path);cid,cls,i,_=n.instances[ref]
  parts.append(dict(ref=ref,path=path,**{'class':cls},anchor=v.get(ref,'CFrame'),size=v.get(ref,'size'),
                    before={'color':v.get(ref,'Color3uint8')},after={'color':palette[2]}))
  counts['mining beds']+=1
 settings={
  'Lighting': {'TimeOfDay':'10:15:00','Brightness':2.35,'ExposureCompensation':.12,
               'Ambient':[156/255,178/255,198/255],'OutdoorAmbient':[191/255,207/255,220/255]},
  'Lighting.ColorCorrection': {'Saturation':.14,'Contrast':.035,'Brightness':.012},
 }
 properties=[]
 for path,values in settings.items():
  for key,value in values.items():
   properties.append(dict(path=path,property=key,before=v.get(n.one(path),key),after=value))
 return dict(baseline=sha256(data).hexdigest(),parts=parts,properties=properties,moves=[],counts=dict(counts))

def check_and_merge(data,plan):
 assert not plan['moves']
 assert all(e['before'].keys()==e['after'].keys()=={'color'} for e in plan['parts'])
 result,report=merged(data,plan)
 a,b=Native(data),Native(result)
 assert a.instances==b.instances and a.parents==b.parents
 assert script_inventory(a.chunks)==script_inventory(b.chunks)
 changed={k for k,value in a.props.items() if b.props[k]!=value}
 allowed={(a.instances[a.one(e['path'])][0],e['property']) for e in plan['properties']}
 assert all(key[1]=='Color3uint8' or key in allowed for key in changed)
 return result,report

def main():
 p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--write',action='store_true');args=p.parse_args()
 data=CANONICAL_OUTPUT.read_bytes();args.directory.mkdir(parents=True,exist_ok=True)
 path=args.directory/'plan.json'
 plan=json.loads(path.read_text()) if args.write else prepare(data)
 result,report=check_and_merge(data,plan)
 if args.write:write_snapshot(data,result)
 else:
  path.write_text(json.dumps(plan,indent=2)+'\n')
  code=LUA.replace('PLAN_JSON',json.dumps(plan,separators=(',',':'))).replace('shared.ReferenceLook','shared.LivelyPalette')
  # Yield between bounded batches without exposing a partially staged map.
  code=code.replace('for _,e in plan.parts do','for index,e in plan.parts do\n if index%200==0 then task.wait() end')
  code=code.replace('for _,h in edits do','for index,h in edits do\n if index%200==0 then task.wait() end')
  (args.directory/'stage.lua').write_text(code)
 print(json.dumps(dict(report,counts=plan['counts'],sha256=sha256(result).hexdigest(),wrote=args.write)))

if __name__=='__main__':main()
