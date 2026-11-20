"""Verify deterministic builds, original instance preservation and native Lighting import."""
import hashlib,pathlib,sys,tempfile
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from build import build,chunks,u32,string,ROOT,bundle
from import_lighting import refs,words
original=ROOT/'assets/mining-away-base.rbxl'

def key(k,d):
 if k==b'PROP':return k,u32(d),string(d,4)[0]
 if k==b'INST':return k,u32(d)
 return (k,)

def parents(cs):
 d=next(d for k,d,_ in cs if k==b'PRNT');n=u32(d,1)
 return dict(zip(refs(d[5:5+n*4],n),refs(d[5+n*4:],n)))

with tempfile.TemporaryDirectory() as tmp:
 tmp=pathlib.Path(tmp);a=tmp/'a.rbxl';b=tmp/'b.rbxl'
 checksum=hashlib.sha256(original.read_bytes()).hexdigest()
 build(original,a);build(original,b)
 assert a.read_bytes()==b.read_bytes();print('PASS binary deterministic native-Lighting build')
 old=list(chunks(original.read_bytes()));new=list(chunks(a.read_bytes()))
 lookup={key(k,d):(d,raw) for k,d,raw in new}
 changes=[]
 for k,d,raw in old:
  nd,nraw=lookup[key(k,d)]
  if k in (b'SSTR',b'PRNT'):continue
  if raw!=nraw:
   assert k==b'PROP';cid=u32(d);name,p=string(d,4);assert cid in (39,66) and name in ('Source','Disabled');changes.append((cid,name))
 assert len(changes)==4
 old_parents,new_parents=parents(old),parents(new)
 assert all(new_parents[k]==v for k,v in old_parents.items())
 old_shared=next(d for k,d,_ in old if k==b'SSTR');new_shared=next(d for k,d,_ in new if k==b'SSTR')
 assert new_shared[8:8+len(old_shared)-8]==old_shared[8:]
 assert hashlib.sha256(original.read_bytes()).hexdigest()==checksum
 print('PASS binary every original instance parent and asset/property payload preserved except four controller properties')
 for k,d,raw in new:
  if k!=b'PROP':continue
  cid=u32(d);prop,p=string(d,4);typ=d[p];p+=1
  if cid in (39,66) and prop=='Disabled':
   assert typ==2
   assert list(d[p:])==([1,1,1,0,1,1,1,1,1] if cid==39 else [1,1,0,1])
  if cid==66 and prop=='Source':
   vals=[]
   while p<len(d):v,p=string(d,p);vals.append(v)
   assert vals[2]==bundle()
 print('PASS binary historical controllers disabled and server source round-trips')
 native=list(chunks((ROOT/'reference/alabaster-harbor/Lighting.rbxm').read_bytes()))
 max_cid=max(u32(d) for k,d,_ in old if k==b'INST');class_offset=max_cid+1
 ref_offset=max(old_parents)+1;shared_offset=u32(old_shared,4)
 native_classes={}
 for k,d,_ in native:
  if k==b'INST':
   cid=u32(d);name,p=string(d,4);native_classes[cid]=u32(d,p+1)
  elif k==b'PROP':
   cid=u32(d);name,p=string(d,4);nd,_=lookup[(k,cid+class_offset,name)];_,np=string(nd,4)
   assert d[p]==nd[np]
   value,nvalue=d[p+1:],nd[np+1:];n=native_classes[cid]
   if d[p]==0x13:assert refs(nvalue,n)==[r+ref_offset if r>=0 else r for r in refs(value,n)]
   elif d[p]==0x1c:assert words(nvalue,n)==[r+shared_offset for r in words(value,n)]
   else:assert value==nvalue,(cid,name)
 for name,typ,value in [('LightingStyle',0x12,b'\0'*4),('PrioritizeLightingQuality',2,b'\1')]:
  d,_=lookup[(b'PROP',38,name)];_,p=string(d,4);assert d[p]==typ and d[p+1:]==value
 print('PASS binary all native Harbor sky/effects/UI/script properties imported, references rebased, render settings persisted')
 from build import client_bundle
 assert 'Foliage.new' not in client_bundle() and 'RenderStepped' not in (ROOT/'src/NativeMeadow.lua').read_text()
 assert all(string(d,4)[0] != 'Bone' for k,d,_ in new if k==b'INST' and u32(d)>max_cid)
 print('PASS binary no imported skinned grass rigs or client foliage runner; original native terrain settings preserved')
 bad=tmp/'bad.rbxl';bad.write_bytes(b'not a place')
 try:build(bad,tmp/'bad-output.rbxl')
 except AssertionError:pass
 else:raise AssertionError('unverified input accepted')
 print('PASS binary unverified input rejected')
print('6 binary build tests passed; engine load is checked separately')
