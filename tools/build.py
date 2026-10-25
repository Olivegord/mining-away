#!/usr/bin/env python3
"""Lossless chunk-preserving Roblox binary source patcher for the supplied autosave.
Never imports or executes scripts embedded in the place. No network access.
"""
import argparse,hashlib,json,pathlib,struct,shutil
from inspect_original import lz4,string,u32
from import_lighting import append_model,refs
ROOT=pathlib.Path(__file__).resolve().parents[1]
EXPECTED='480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b'
def packstr(s):
 b=s.encode();return struct.pack('<I',len(b))+b
def chunks(b):
 i=32
 while i<len(b):
  start=i;kind=b[i:i+4];cl,ul,res=struct.unpack_from('<III',b,i+4);i+=16
  raw=b[i:i+(cl or ul)];i+=cl or ul
  yield kind,(lz4(raw,ul) if cl else raw),b[start:i]
def chunk(k,d):return k+struct.pack('<III',0,len(d),0)+d
def module_bundle(names):
 s='-- Mining Away • Olivegord/mining-away • generated from editable source.\n'
 for name in names:
  code=(ROOT/'src'/f'{name}.lua').read_text().replace('--!strict\n','')
  s+='local '+name+' = (function()\n'+code+'\nend)()\n'
 return s
def bundle():
 return module_bundle(('Config','Feel','Rules','Profile','Cards','Persistence','MapLayout','HarborLighting','Facets','World'))+(ROOT/'src/Server.lua').read_text()
def client_bundle():
 return module_bundle(('Feel','Feedback','SentryMotion','Presentation','UILayout','Interface','CardView','Foliage'))+(ROOT/'src/Client.lua').read_text()
def build(original,out):
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
 # Vendor the reviewed module and real rigged meshes; demo runners stay disabled.
 grass=ROOT/'reference/skinned-grass/SkinnedGrass.rbxm'
 assert hashlib.sha256(grass.read_bytes()).hexdigest()=='b43dfe3e064d0d2130e31f39732e9b76c94ef0890796e85db3b1b117ef7ed887'
 from import_foliage import prepare
 assert replicated_ref is not None
 merged=append_model(merged,prepare(grass.read_bytes(),ROOT/'reference/skinned-grass/src'),replicated_ref,chunks,chunk,u32,string,packstr)
 # Engine rendering options must also survive opening the file before Play.
 styles=[chunk(b'PROP',struct.pack('<I',lighting_cid)+packstr('LightingStyle')+b'\x12'+b'\0'*4),
         chunk(b'PROP',struct.pack('<I',lighting_cid)+packstr('PrioritizeLightingQuality')+b'\x02\x01')]
 final=[merged[:32]]
 for k,d,raw in chunks(merged):
  if k==b'PRNT':final.extend(styles)
  final.append(raw)
 out.write_bytes(b''.join(final))
 report={'original_sha256':EXPECTED,'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_bytes':len(b),'output_bytes':out.stat().st_size,'changed_sources':changed,'lighting_template_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'grass_template_sha256':hashlib.sha256(grass.read_bytes()).hexdigest(),'policy':'Original instance referents, parents, assets and property payloads are preserved except controller Source/Disabled. Native Harbor Lighting and SkinnedGrass templates (reviewed source, disabled demo runners) and two render settings are appended; SSTR/PRNT/header totals are rebased. Original source asset is unchanged.'}
 (out.parent/'build-report.json').write_text(json.dumps(report,indent=2));return report
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('original',type=pathlib.Path);p.add_argument('--output',type=pathlib.Path,default=ROOT/'build/Mining Away.rbxl');a=p.parse_args()
 assert a.original.resolve()!=a.output.resolve(),'Use a NEW output path'
 print(json.dumps(build(a.original,a.output),indent=2))
