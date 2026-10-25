"""Verify exact binary preservation and deterministic, fail-closed builds."""
import hashlib,pathlib,sys,tempfile
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from build import build,chunks,u32,string,ROOT,bundle
original=ROOT/'assets/mining-away-base.rbxl'
with tempfile.TemporaryDirectory() as tmp:
 tmp=pathlib.Path(tmp);a=tmp/'a.rbxl';b=tmp/'b.rbxl'
 build(original,a);build(original,b)
 assert a.read_bytes()==b.read_bytes();print('PASS binary deterministic build')
 old=list(chunks(original.read_bytes()));new=list(chunks(a.read_bytes()))
 assert len(old)==len(new)
 changes=[]
 for (k,d,raw),(nk,nd,nraw) in zip(old,new):
  assert k==nk
  if raw!=nraw:
   assert k==b'PROP';cid=u32(d);name,p=string(d,4);assert cid in (39,66) and name in ('Source','Disabled');changes.append((cid,name))
 assert len(changes)==4;print('PASS binary all asset, hierarchy and other property chunks byte-identical')
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
 print('PASS binary only new server and client entrypoints enabled, sources round-trip')
 bad=tmp/'bad.rbxl';bad.write_bytes(b'not a place')
 try:build(bad,tmp/'bad-output.rbxl')
 except AssertionError:pass
 else:raise AssertionError('unverified input accepted')
 print('PASS binary unverified input rejected')
print('4 binary build tests passed')
