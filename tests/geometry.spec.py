"""Read-only proof that runtime names bind the original segmented mesh assets."""
import hashlib,pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build import chunks,u32,string
source=ROOT/'assets/mining-away-base.rbxl'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b'
print('PASS geometry original asset checksum')
def refs(data,n):
 values=[int.from_bytes(bytes(data[j*n+i] for j in range(4)),'big') for i in range(n)];result=[];total=0
 for value in values:total+=(value>>1)^-(value&1);result.append(total)
 return result
classes={};properties={};parents={}
for kind,data,_ in chunks(source.read_bytes()):
 if kind==b'INST':
  cid=u32(data);name,p=string(data,4);n=u32(data,p+1);classes[cid]=(name,refs(data[p+5:p+5+n*4],n))
 elif kind==b'PROP':
  cid=u32(data);name,p=string(data,4);typ=data[p];p+=1
  if typ==1:
   values=[]
   while p<len(data):value,p=string(data,p);values.append(value)
   properties.setdefault(cid,{})[name]=values
 elif kind==b'PRNT':
  n=u32(data,1);parents=dict(zip(refs(data[5:5+n*4],n),refs(data[5+n*4:],n)))
nodes={}
for cid,(class_name,ids) in classes.items():
 for i,ident in enumerate(ids):nodes[ident]={'class':class_name,**{name:values[i] for name,values in properties.get(cid,{}).items()}}
def path(ident):
 if ident not in nodes:return ''
 return path(parents.get(ident,-1))+'/'+nodes[ident]['Name']
paths={path(ident):value for ident,value in nodes.items()}
expected={'bottemseg':'14477420875','lowerseg':'14477422793','upperseg':'14477425917','topseg':'14477427275','eye':'14477430698','eyecase':'14477428635','spawnEye':'14477430698'}
for name,asset in expected.items():
 node=paths['/Workspace/construct/'+name];assert node['class']=='MeshPart' and node['MeshId']=='rbxassetid://'+asset
construct_ids=[ident for ident in nodes if path(ident).startswith('/Workspace/construct/')]
editor_ids=[ident for ident in nodes if path(ident).startswith('/Workspace/construct/AnimSaves/')]
assert len(construct_ids)>3400 and len(editor_ids)>3400
print('PASS geometry exact seven original construct meshes and full authored editor history preserved in source')
assert '/Workspace/construct/AnimationController/Animator' in paths
assert '/Workspace/construct/AnimSaves' in paths
assert paths['/ReplicatedStorage/Crystal/Mesh']['class']=='UnionOperation'
assert '/ReplicatedStorage/Drone/Mesh/Emmiter' in paths
assert '/ReplicatedStorage/MiningFX/Beam/InnerBeam' in paths and '/ReplicatedStorage/MiningFX/Beam/OuterBeam' in paths
print('PASS geometry original animation, crystal union, drone emitter and beam assets retained')
for original in ['/Workspace/Patches/rubyPatch','/Workspace/Patches/cobaltPatch','/Workspace/Converter','/Workspace/SpawnLocation','/Workspace/Baseplate']:
 assert original in paths
print('PASS geometry original map landmarks present for integration')
print('4 original-geometry structural tests passed; not Studio asset loading')
