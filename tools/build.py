#!/usr/bin/env python3
"""Refresh the one existing native editable game, or export its Sources.
Capture builders are explicit temporary preservation-test fixtures only.
Never manufacture a competing playable file, execute embedded scripts or publish.
"""
import argparse,hashlib,json,pathlib,struct,shutil,subprocess,tempfile
from functools import lru_cache
from inspect_original import lz4,string,u32
from import_lighting import append_model,refs
ROOT=pathlib.Path(__file__).resolve().parents[1]
EXPECTED='480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b'
# The shared destination is distinct from the place that supplied the capture.
ACTIVE_PLACE_ID=124078027733625
ACTIVE_UNIVERSE_ID=10774898335
ACTIVE_EXPERIENCE_NAME='DRONEREVOLUTION'
REFERENCE_PLACE_ID=136098934779395
ACTIVE_EXPECTED='b08036b400c77451e609f5fa3a4f7f04cd5dcc2030f35a76de12ecc278f532cd'
ACTIVE_BASE=ROOT/'assets/drone-blower-revolution-base.rbxl'
CANONICAL_OUTPUT=ROOT/'build/DRONE_GAME.rbxl'
ACTIVE_OUTPUT=CANONICAL_OUTPUT
LEGACY_OUTPUT=ROOT/'build/Drone Blower revolution.rbxl'
@lru_cache(maxsize=1)
def native_zstd():
 """Reuse an installed decoder; do not spawn a process for every place chunk."""
 import ctypes,ctypes.util
 executable=shutil.which('zstd')
 candidates=[ctypes.util.find_library('zstd')]
 if executable:
  prefix=pathlib.Path(executable).resolve().parent.parent
  candidates.extend(str(prefix/'lib'/name) for name in ('libzstd.dylib','libzstd.so','zstd.dll'))
 for candidate in candidates:
  if not candidate:continue
  try:lib=ctypes.CDLL(candidate)
  except OSError:continue
  lib.ZSTD_decompress.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t]
  lib.ZSTD_decompress.restype=ctypes.c_size_t
  lib.ZSTD_isError.argtypes=[ctypes.c_size_t];lib.ZSTD_isError.restype=ctypes.c_uint
  return lib
 return None
@lru_cache(maxsize=1024)
def decompress(raw,size):
 if raw.startswith(b'\x28\xb5\x2f\xfd'):
  # Studio now writes Zstandard frames. A standard zstd CLI (tested 1.5.7)
  # suffices; the Python zstandard package is an optional equivalent decoder.
  try:
   import zstandard
  except ImportError:
   lib=native_zstd()
   if lib:
    import ctypes
    target=ctypes.create_string_buffer(size)
    count=lib.ZSTD_decompress(target,size,raw,len(raw))
    if lib.ZSTD_isError(count):raise RuntimeError('Invalid Zstandard place chunk')
    decoded=target.raw[:count]
   else:
    executable=shutil.which('zstd')
    if not executable: raise RuntimeError('Zstandard decoder missing: install zstd (tested 1.5.7) or Python zstandard')
    result=subprocess.run([executable,'--decompress','--stdout','--quiet'],input=raw,capture_output=True,check=True)
    decoded=result.stdout
  else: decoded=zstandard.ZstdDecompressor().decompress(raw,max_output_size=size)
  assert len(decoded)==size,'Zstandard chunk length mismatch'
  return decoded
 return lz4(raw,size)
def packstr(s):
 b=s.encode();return struct.pack('<I',len(b))+b
def chunks(b):
 i=32
 while i<len(b):
  start=i;kind=b[i:i+4];cl,ul,res=struct.unpack_from('<III',b,i+4);i+=16
  raw=b[i:i+(cl or ul)];i+=cl or ul
  assert len(raw)==(cl or ul),'Truncated place chunk'
  yield kind,(decompress(raw,ul) if cl else raw),b[start:i]
def chunk(k,d):return k+struct.pack('<III',0,len(d),0)+d
def module_bundle(names):
 if any(name in names for name in ('Shops','Cards','Profile','ShopView','World','PickupView','SpecialDroneMotion')) and 'Workshop' not in names:
  names=('Workshop',)+tuple(names)
 if 'Cards' in names and 'Packs' not in names:
  names=tuple(n for name in names for n in (('Packs','Cards') if name=='Cards' else (name,)))
 if 'Profile' in names and 'Consumables' not in names:
  names=tuple(n for name in names for n in (('Consumables','Profile') if name=='Profile' else (name,)))
 # The shared beam renderer owns startup leases in every production/test bundle.
 if 'BeamVFX' in names and 'StartupFX' not in names:
  names=tuple(n for name in names for n in (('StartupFX','BeamVFX') if name=='BeamVFX' else (name,)))
 if 'StartupFX' in names:
  names=tuple(n for name in names for n in (tuple(dep for dep in ('PullMotion','PlaneBurst','LaunchAftermath') if dep not in names)+(name,) if name=='StartupFX' else (name,)))
 if 'EnergyDisc' not in names and any(n in names for n in ('LaunchAftermath','BeamVFX','StartupFX','WorkEffects','RoleVisuals','RoleEffectView')):
  names=('EnergyDisc',)+tuple(names)
 s='--!strict\n-- Drone Blower revolution • Olivegord/mining-away • generated from editable source.\n'
 for name in names:
  code=(ROOT/'src'/f'{name}.lua').read_text().replace('--!strict\n','')
  if name=='World':
   # Keep World helpers scoped to World; the game controller is near Luau's local limit.
   biome=(ROOT/'src/QuarryBiomes.lua').read_text()
   code=code.replace("require('./QuarryBiomes')",'(function()\n'+biome+'\nend)()')
  if 'Workshop' in names[:names.index(name)]:code=code.replace("local Workshop=require('./Workshop')\n",'')
  if 'Packs' in names[:names.index(name)]:code=code.replace("local Packs=require('./Packs')\n",'')
  if 'Shops' in names[:names.index(name)]:code=code.replace("local Shops=require('./Shops')\n",'')
  if 'DroneRoles' in names[:names.index(name)]:code=code.replace("local DroneRoles=require('./DroneRoles')\n",'')
  if 'DroneCatalog' in names[:names.index(name)]:code=code.replace("local DroneCatalog=require('./DroneCatalog')\n",'')
  if 'Consumables' in names[:names.index(name)]:code=code.replace("local Consumables=require('./Consumables')\n",'')
  boundary=': any' if name=='World' else ''
  binding={'PlayerHazards':'ToolRules.Hazards','ToolService':'ToolRules.Service'}.get(name)
  s+=(binding or ('local '+name+boundary))+' = (function()\n'+code+'\nend)()\n'
 return s
def bundle():
 return module_bundle(('Shops','ShopStands','DroneAbilities','DroneCatalog','DroneRoles','Consumables','ConsumableService','ToolRules','PlayerHazards','ToolService','Config','Feel','Mining','ResourcePlacement','JunkField','CrystalCuts','OreDrops','Rules','Profile','Packs','Cards','Persistence','DroneConfig','DroneRoleEffects','MiningDiscoveries','MapLayout','HarborLighting','Daylight','Facets','NativeMeadow','World','Logistics','PackDelivery'))+(ROOT/'src/Server.lua').read_text()
def client_bundle():
 return module_bundle(('Shops','Feel','JunkField','Mining','Feedback','AudioFeedback','SentryMotion','Soundscape','BeamVFX','WorkEffects','DroneCatalog','CrystalGeometry','RockDamage','DroneFX','SpecialDroneMotion','MotionBuffer','RoleVisuals','RoleEffectView','PickupMotion','CrystalImpactView','Presentation','LaserShowcase','UILayout','Interface','Packs','CardView','DroneRoles','FleetView','PackView','ShopView','AbilityView','ToolRules','ToolArt','ToolView','OreDrops','PickupView','CommandView','LogisticsView','SelectorView','ChargerView'))+(ROOT/'src/Client.lua').read_text()
def editor_layout_script():
 """Materialize the requested map in Studio Edit without running gameplay."""
 return module_bundle(('Config','Shops','World','ShopStands'))+'''
assert(not game:GetService('RunService'):IsRunning(),'Stop Play before editing the map')
assert(game.PlaceId==124078027733625 or game.PlaceId==0,'Wrong experience: expected DRONEREVOLUTION or the canonical local file')
assert(game.PlaceId==0 or game.GameId==10774898335,'Wrong DRONEREVOLUTION universe')
local root=assert(workspace:FindFirstChild('MiningAway'),'Open the canonical DRONE_GAME.rbxl')
assert(root:GetAttribute('EditableMap'),'Expected the preserved editable map')
local map=assert(root:FindFirstChild('Map'));local fields=assert(root:FindFirstChild('Fields'))
local hub=assert(map:FindFirstChild('HubPad',true));local home=root:GetAttribute('DepotHome') or hub.Position
local history=game:GetService('ChangeHistoryService');history:SetWaypoint('Before editable mineral layout')
World.layoutFields(root,fields,home)
local metadata={}
for id,cfg in ipairs(Config.Fields) do
 local model=assert(fields:FindFirstChild(cfg.Key));local part=assert(model:FindFirstChild('Field'))
 table.insert(metadata,{id=id,cfg=cfg,model=model,part=part,center=part.Position})
end
local scene={root=root,map=map,home=home,fields=metadata}
World.placeStart(scene)
local stands=ShopStands.mount(map,home,assert(map:FindFirstChild('PackStation',true)))
history:SetWaypoint('Editable Quartz start and mineral shops')
local report={place_id=game.PlaceId,mode='Edit',spawn={scene.spawnPosition.X,scene.spawnPosition.Y,scene.spawnPosition.Z},fields={},shops={}}
for _,field in ipairs(metadata) do
 table.insert(report.fields,{key=field.cfg.Key,position={field.part.Position.X,field.part.Position.Y,field.part.Position.Z},from_spawn=(field.part.Position-scene.spawnPosition).Magnitude})
end
for key,part in pairs(stands) do report.shops[key]={part.Position.X,part.Position.Y,part.Position.Z} end
return report
'''
LIVE_SOURCES={
 'ServerScriptService.GlobalDroneControl':('Script','Server'),
 'StarterPlayer.StarterPlayerScripts.ClientDroneControl':('LocalScript','Client'),
 'ReplicatedStorage.Shared.DroneConfig':('ModuleScript','DroneConfig'),
 'ReplicatedStorage.Shared.TacticalHUD':('ModuleScript','TacticalHUD'),
 'ReplicatedStorage.Shared.CrystalAudio':('ModuleScript','CrystalAudio'),
 'ServerScriptService.DroneRoleEffects':('ModuleScript','DroneRoleEffects'),
 'ServerScriptService.MiningDiscoveries':('ModuleScript','MiningDiscoveries'),
}
def live_source_payload():
 """Exact-path payload for the existing place, also usable by Studio integration."""
 sources={}
 for path,(cls,module) in LIVE_SOURCES.items():
  source=bundle() if module=='Server' else client_bundle() if module=='Client' else (ROOT/'src'/f'{module}.lua').read_text()
  sources[path]={'class':cls,'source':source,'sha256':hashlib.sha256(source.encode()).hexdigest()}
 return {'place_id':ACTIVE_PLACE_ID,'universe_id':ACTIVE_UNIVERSE_ID,'experience_name':ACTIVE_EXPERIENCE_NAME,'canonical_file':str(CANONICAL_OUTPUT.relative_to(ROOT)),'captured_from_place_id':REFERENCE_PLACE_ID,'captured_base_sha256':ACTIVE_EXPECTED,'sources':sources}
def string_values(d,p,count):
 values=[]
 for _ in range(count):
  length=u32(d,p);p+=4;value=d[p:p+length]
  assert len(value)==length,'Truncated property string'
  values.append(value);p+=length
 assert p==len(d),'Unexpected property string suffix'
 return values
def script_inventory(cs):
 """Resolve actual hierarchy paths; backup scripts often share live names."""
 classes={};names={};sources={};parents={};instances={}
 for kind,d,_ in cs:
  if kind==b'INST':
   cid=u32(d);cls,p=string(d,4);count=u32(d,p+1)
   classes[cid]=(cls,refs(d[p+5:p+5+count*4],count))
  elif kind==b'PRNT':
   count=u32(d,1)
   parents=dict(zip(refs(d[5:5+count*4],count),refs(d[5+count*4:],count)))
 for kind,d,_ in cs:
  if kind!=b'PROP':continue
  cid=u32(d);prop,p=string(d,4)
  if prop in ('Name','Source'):
   assert d[p]==1,'Unsupported '+prop+' property encoding'
   values=string_values(d,p+1,len(classes[cid][1]))
   if prop=='Name':names[cid]=[value.decode('utf8') for value in values]
   else:sources[cid]=values
 for cid,(cls,ids) in classes.items():
  for index,ref in enumerate(ids):instances[ref]=(names[cid][index],cls,cid,index)
 def full_path(ref):
  pieces=[];seen=set()
  while ref>=0:
   assert ref not in seen,'Cyclic place hierarchy'
   seen.add(ref);pieces.append(instances[ref][0]);ref=parents[ref]
  return '.'.join(reversed(pieces))
 result=[]
 for ref,(_,cls,cid,index) in instances.items():
  if cls in ('Script','LocalScript','ModuleScript'):
   result.append({'path':full_path(ref),'class':cls,'cid':cid,'index':index,'ref':ref,'source':sources[cid][index]})
 return result
def build_live(original=ACTIVE_BASE,out=None):
 """Capture-preservation test fixture only; never create an alternate game."""
 assert out is not None,'Capture fixtures need an explicit temporary output; refresh the canonical editable workspace for the game'
 original=pathlib.Path(original);out=pathlib.Path(out)
 assert (ROOT/'build').resolve() not in out.resolve().parents,'Capture fixtures cannot write playable files into build; refresh the canonical editable workspace'
 assert (ROOT/'assets').resolve() not in out.resolve().parents and not out.is_symlink(),'Cannot write a fixture over source assets or a symlink'
 assert original.resolve()!=out.resolve(),'Input and output must differ'
 assert out.resolve()!=(ROOT/'assets/mining-away-base.rbxl').resolve(),'Cannot overwrite historical source'
 data=original.read_bytes()
 assert hashlib.sha256(data).hexdigest()==ACTIVE_EXPECTED,'Wrong active capture; refusing to alter an unverified place'
 cs=list(chunks(data));inventory=script_inventory(cs);payload=live_source_payload();edits={};changed=[]
 for path,entry in payload['sources'].items():
  matches=[item for item in inventory if item['path']==path]
  assert len(matches)==1 and matches[0]['class']==entry['class'],'Missing or ambiguous active script: '+path
  item=matches[0];replacement=entry['source'].encode()
  edits[(item['cid'],item['index'])]=replacement
  if replacement!=item['source']:
   changed.append({'path':path,'class':item['class'],'before_sha256':hashlib.sha256(item['source']).hexdigest(),'after_sha256':entry['sha256']})
 output=[data[:32]];changed_chunks=0
 for kind,d,raw in cs:
  if kind==b'PROP':
   cid=u32(d);prop,p=string(d,4)
   if prop=='Source' and any(key[0]==cid for key in edits):
    assert d[p]==1
    count=sum(1 for item in inventory if item['cid']==cid)
    values=string_values(d,p+1,count)
    replacement=[edits.get((cid,index),value) for index,value in enumerate(values)]
    if replacement!=values:
     encoded=d[:p+1]+b''.join(struct.pack('<I',len(value))+value for value in replacement)
     output.append(chunk(kind,encoded));changed_chunks+=1;continue
  output.append(raw)
 built=b''.join(output);out.parent.mkdir(parents=True,exist_ok=True)
 if out.exists():shutil.copy2(out,out.with_suffix(out.suffix+'.previous'))
 with tempfile.NamedTemporaryFile(dir=out.parent,prefix='.live-build-',delete=False) as temporary:
  temporary.write(built);temporary_path=pathlib.Path(temporary.name)
 temporary_path.replace(out)
 report={'place_id':ACTIVE_PLACE_ID,'original_sha256':ACTIVE_EXPECTED,'output_sha256':hashlib.sha256(built).hexdigest(),
  'original_bytes':len(data),'output_bytes':len(built),'source_allowlist':list(LIVE_SOURCES),'changed_sources':changed,'changed_source_chunks':changed_chunks,
  'policy':'Only seven explicitly identified live script Source values may change. All other raw chunks, script sources, Disabled values, hierarchy, terrain, assets, lighting and backup copies remain byte-identical. No publishing or new experience.'}
 (out.parent/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
 return report
def build(original,out):
 """Historical reference test fixture only; never an active game output."""
 assert (ROOT/'build').resolve() not in out.resolve().parents,'Historical fixtures cannot write playable files into build'
 assert (ROOT/'assets').resolve() not in out.resolve().parents and not out.is_symlink(),'Cannot write a fixture over source assets or a symlink'
 assert out.resolve()!=ACTIVE_OUTPUT.resolve(),'Historical builder cannot overwrite the active review place'
 assert original.resolve()!=out.resolve(),'Input and output must differ'
 out.parent.mkdir(parents=True,exist_ok=True)
 b=original.read_bytes();assert hashlib.sha256(b).hexdigest()==EXPECTED,'Wrong source; refusing to alter an unverified place'
 cs=list(chunks(b));classes={};names={}
 for k,d,_ in cs:
  if k==b'INST':
   cid=u32(d);name,p=string(d,4);classes[cid]=(name,u32(d,p+1))
  elif k==b'PROP':
   cid=u32(d);name,p=string(d,4)
   if name=='Name' and d[p]==1:
    vals=[];p+=1
    while p<len(d):v,p=string(d,p);vals.append(v)
    names[cid]=vals
 changed=[];seen_disabled=set();output=[b[:32]]
 for k,d,raw in cs:
  if k==b'PROP':
   cid=u32(d);prop,p=string(d,4);typ=d[p];p+=1
   cls,count=classes[cid]
   if cls in ('Script','LocalScript') and prop=='Source':
    assert typ==1
    vals=[]
    for i in range(count):v,p=string(d,p);vals.append(v)
    for i,name in enumerate(names[cid]):
     if cls=='Script' and name=='GlobalDroneControl': vals[i]=bundle();changed.append([cls,i,name,'replaced'])
     elif cls=='LocalScript' and name=='ClientDroneControl': vals[i]=client_bundle();changed.append([cls,i,name,'replaced'])
    output.append(chunk(k,struct.pack('<I',cid)+packstr(prop)+bytes([typ])+b''.join(packstr(v) for v in vals)));continue
   if cls in ('Script','LocalScript') and prop=='Disabled':
    assert typ==2
    enabled='GlobalDroneControl' if cls=='Script' else 'ClientDroneControl'
    output.append(chunk(k,d[:p]+bytes(0 if n==enabled else 1 for n in names[cid])));seen_disabled.add(cid);continue
  if k==b'PRNT':
   for cid,(cls,count) in classes.items():
    if cls in ('Script','LocalScript') and cid not in seen_disabled:
     enabled='GlobalDroneControl' if cls=='Script' else 'ClientDroneControl'
     output.append(chunk(b'PROP',struct.pack('<I',cid)+packstr('Disabled')+b'\x02'+bytes(0 if n==enabled else 1 for n in names[cid])))
  output.append(raw)
 if out.exists(): shutil.copy2(out,out.with_suffix(out.suffix+'.previous'))
 # Append the complete engine-exported Lighting template under existing storage.
 # Existing mesh/union/script history/property payloads retain their referents.
 native=ROOT/'reference/alabaster-harbor/Lighting.rbxm'
 assert hashlib.sha256(native.read_bytes()).hexdigest()=='73325de49e9a79e037f0b820e101eed9e4b18f5e6f7b7662e471ce985fb278af'
 storage_ref=None;replicated_ref=None;lighting_cid=None
 for k,d,_ in cs:
  if k==b'INST':
   cid=u32(d);name,p=string(d,4);n=u32(d,p+1)
   if name=='ServerStorage': storage_ref=refs(d[p+5:p+5+n*4],n)[0]
   if name=='ReplicatedStorage': replicated_ref=refs(d[p+5:p+5+n*4],n)[0]
   if name=='Lighting': lighting_cid=cid
 assert storage_ref is not None and lighting_cid is not None
 merged=append_model(b''.join(output),native.read_bytes(),storage_ref,chunks,chunk,u32,string,packstr)
 # Engine rendering options must also survive opening the file before Play.
 styles=[chunk(b'PROP',struct.pack('<I',lighting_cid)+packstr('LightingStyle')+b'\x12'+b'\0'*4),
         chunk(b'PROP',struct.pack('<I',lighting_cid)+packstr('PrioritizeLightingQuality')+b'\x02\x01')]
 final=[merged[:32]]
 for k,d,raw in chunks(merged):
  if k==b'PRNT':final.extend(styles)
  final.append(raw)
 out.write_bytes(b''.join(final))
 report={'original_sha256':EXPECTED,'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_bytes':len(b),'output_bytes':out.stat().st_size,'changed_sources':changed,'lighting_template_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'policy':'Original instance referents, parents, assets and property payloads are preserved except controller Source/Disabled. A native Harbor Lighting template and two render settings are appended; native grass uses the preserved Terrain decoration settings; SSTR/PRNT/header totals are rebased. Original source asset is unchanged.'}
 (out.parent/'build-report.json').write_text(json.dumps(report,indent=2));return report
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('original',nargs='?',type=pathlib.Path);p.add_argument('--output',type=pathlib.Path)
 p.add_argument('--legacy-reference',action='store_true',help='Retired: historical capture builds are temporary test fixtures only')
 p.add_argument('--source-payload',type=pathlib.Path,help='Write a source-only exact-path JSON payload for the existing active place')
 p.add_argument('--editor-layout-script',type=pathlib.Path,help='Write a Command Bar script that applies the layout directly in Studio Edit')
 previous=p.add_mutually_exclusive_group()
 previous.add_argument('--previous-commit',help='Exact previous Sources installed in the canonical editable workspace')
 previous.add_argument('--previous-payload',type=pathlib.Path,help='Exact previously installed source payload')
 a=p.parse_args()
 if a.editor_layout_script:
  a.editor_layout_script.parent.mkdir(parents=True,exist_ok=True);a.editor_layout_script.write_text(editor_layout_script())
  print(str(a.editor_layout_script))
 elif a.source_payload:
  a.source_payload.parent.mkdir(parents=True,exist_ok=True);a.source_payload.write_text(json.dumps(live_source_payload(),ensure_ascii=False))
  print(str(a.source_payload))
 elif a.legacy_reference:
  p.error('Historical capture builds are temporary test fixtures only; the sole game is the existing editable workspace')
 else:
  if a.original or (a.output and a.output.resolve()!=CANONICAL_OUTPUT.resolve()):
   p.error('The sole game is '+str(CANONICAL_OUTPUT)+'; alternate place inputs/outputs are not supported')
  from refresh_editable import refresh
  print(json.dumps(refresh(previous_commit=a.previous_commit,previous_payload=a.previous_payload),indent=2))
