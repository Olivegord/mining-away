#!/usr/bin/env python3
"""Restore scoped appearance from the smooth-turf revision; never restore its map/Sources.

prepare writes a reviewable property plan and an Edit staging script. write requires
the same baseline and a successful Studio apply/verify before mirroring the plan.
"""
import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import subprocess

from build import CANONICAL_OUTPUT, script_inventory, string_values, chunk, string, u32, packstr
from refresh_native_scenery import (Native, MAP, split_cframe, unpack_vectors,
                                    unpack_colors, write_parents, write_snapshot, read_section, pack_vectors, close)
from refresh_quarry_courtyard import unpack_floats
from refresh_quarry_sunshine import merge

REFERENCE = '077b76a'
ARCHIVES = [MAP+'.QuarryMotifScenery', MAP+'.QuarryNaturalMeadow.SunlitGrass',
            MAP+'.QuarryContinuousGround.PatternedAccents']
DISPLAY = MAP+'.JunkCubeAreas'
LIGHTING = {
    'Lighting': {'TimeOfDay','Brightness','ExposureCompensation','Ambient','OutdoorAmbient',
                 'ColorShift_Top','ColorShift_Bottom','GeographicLatitude','EnvironmentDiffuseScale',
                 'EnvironmentSpecularScale','ShadowSoftness','FogStart','FogEnd','FogColor'},
    'Lighting.ColorCorrection': {'Brightness','Contrast','Saturation','TintColor'},
}

class Values:
    def __init__(self, native): self.n,self.cache=native,{}
    def get(self, ref, prop):
        cid,_,i,_=self.n.instances[ref];key=cid,prop
        if key not in self.cache:
            dtype,data=self.n.props[key];count=len(self.n.classes[cid][1])
            if dtype==1: values=[v.decode() for v in string_values(data,0,count)]
            elif dtype==4: values=unpack_floats(data,count)
            elif dtype in (12,14): values=unpack_vectors(data,count)
            elif dtype==26: values=unpack_colors(data,count)
            elif dtype==16: values=unpack_vectors(split_cframe(data,count)[1],count)
            else: raise AssertionError((key,dtype))
            self.cache[key]=values
        return self.cache[key][i]

def excluded(path):
    return path.startswith(DISPLAY) or any(path==p or path.startswith(p+'.') for p in ARCHIVES)

def prepare(data):
    current=Native(data);old=Native(subprocess.check_output(['git','show',REFERENCE+':build/DRONE_GAME.rbxl']))
    now,was=Values(current),Values(old)
    parts=[]
    for ref,(cid,cls,i,name) in current.instances.items():
        path=current.path(ref)
        if cls not in {'Part','WedgePart'} or excluded(path): continue
        if not path.startswith((MAP+'.','Workspace.MiningAway.Fields.')): continue
        # Only transfer appearance to the same surviving native instance.
        if ref in old.instances and old.instances[ref]==current.instances[ref] and old.path(ref)==path:
            before,after={},{}
            for short,prop in [('color','Color3uint8'),('variant','MaterialVariantSerialized')]:
                a,b=now.get(ref,prop),was.get(ref,prop)
                if a!=b: before[short],after[short]=a,b
            if before:
                parts.append(dict(ref=ref,path=path,**{'class':cls},anchor=now.get(ref,'CFrame'),size=now.get(ref,'size'),before=before,after=after))
        elif now.get(ref,'MaterialVariantSerialized')=='QuarryPhoto_Grass':
            # Later island/meadow turf should use the same original photo tile.
            # Keep their authored regional colors and geometry.
            parts.append(dict(ref=ref,path=path,**{'class':cls},anchor=now.get(ref,'CFrame'),size=now.get(ref,'size'),
                              before={'variant':'QuarryPhoto_Grass'},after={'variant':'QuarryRestoredTurf_Grass'}))
    properties=[]
    for path,keys in LIGHTING.items():
        for key in sorted(keys):
            a,b=now.get(current.one(path),key),was.get(old.one(path),key)
            if path=='Lighting' and key=='ExposureCompensation': b=.10
            if path=='Lighting' and key in {'Ambient','OutdoorAmbient'}: b=[min(1,x+6/255) for x in b]
            if a!=b: properties.append(dict(path=path,property=key,before=a,after=b))
    moves=[]
    for path in ARCHIVES:
        if not current.paths[path]:
            assert current.paths['ServerStorage.'+path.rsplit('.',1)[1]]
            continue
        ref=current.one(path)
        assert not current.paths['ServerStorage.'+current.instances[ref][3]]
        moves.append({'path':path,'descendants':sum(p.startswith(path+'.') for p in map(current.path,current.instances))})
    return dict(baseline=sha256(data).hexdigest(),reference=REFERENCE,parts=parts,properties=properties,moves=moves)

def validate_part(e):
    assert e['path'].startswith((MAP+'.','Workspace.MiningAway.Fields.')) and not excluded(e['path'])
    assert e['before'].keys()==e['after'].keys() and e['after'].keys()<={'color','variant'}

def merged(data,plan):
    assert sha256(data).hexdigest()==plan['baseline'],'Native baseline changed'
    original=Native(data)
    # Native referents disambiguate overlapping leaf layers and triangulated
    # shore wedges. Live matching also checks size and expected appearance.
    updates={};values=Values(original)
    for e in plan['parts']:
        validate_part(e);ref=e['ref'];cid,cls,i,_=original.instances[ref]
        assert original.path(ref)==e['path'] and cls==e['class']
        assert list(values.get(ref,'CFrame'))==list(e['anchor']) and list(values.get(ref,'size'))==list(e['size'])
        for short,prop in [('color','Color3uint8'),('variant','MaterialVariantSerialized')]:
            if short not in e['after']:continue
            actual=values.get(ref,prop);expected=e['before'][short]
            assert (list(actual)==list(expected) if short=='color' else actual==expected)
            key=cid,prop
            if key not in updates:updates[key]=[values.get(r,prop) for r in original.classes[cid][1]]
            updates[key][i]=e['after'][short]
    output=[data[:32]]
    for kind,payload,raw in original.chunks:
        if kind==b'PROP':
            name,off=string(payload,4);key=u32(payload),name
            if key in updates:
                vals=updates[key]
                encoded=b''.join(packstr(v) for v in vals) if name=='MaterialVariantSerialized' else b''.join(bytes(axis) for axis in zip(*vals))
                raw=chunk(kind,payload[:off+1]+encoded)
        output.append(raw)
    appearance=Native(b''.join(output))
    assert {k for k,v in original.props.items() if appearance.props[k]!=v}<=updates.keys()
    result,report=merge(appearance.data,dict(parts=[],properties=plan['properties']),allowed_properties=LIGHTING)
    report['appearance_parts']=len(plan['parts'])
    n=Native(result);parents=dict(n.parents)
    assert len({e['path'] for e in plan['moves']})==len(plan['moves'])
    assert {e['path'] for e in plan['moves']}<=set(ARCHIVES)
    for move in plan['moves']:
        path=move['path'];ref=n.one(path)
        assert sum(p.startswith(path+'.') for p in map(n.path,n.instances))==move['descendants']
        parents[ref]=n.one('ServerStorage')
    final=Native(write_parents(n,parents))
    assert original.instances==final.instances
    assert script_inventory(original.chunks)==script_inventory(final.chunks)
    # Appearance-only merge already checks all unrelated properties; check the
    # complete property table again after the parent-only archive operation.
    assert final.props==n.props
    assert all(final.parents[r]==(parents[r]) for r in original.parents)
    return final.data,dict(report,archived_roots=len(plan['moves']))

def reconcile_tree(data,directory):
    """Copy the verified live tree transforms from native serialization, not a rebuild."""
    if not (directory/'tree.b64').exists():return data,0
    native=Native(data);export=Native(read_section(directory,'tree'))
    root=MAP+'.QuarryContinuousGround.OriginalDetails.Quartz.01_Tree1'
    old_refs=native.paths[root+'.Part'];new_refs=export.paths['01_Tree1.Part']
    assert len(old_refs)==len(new_refs)==14
    a,b=Values(native),Values(export)
    def rotations(n,cid):
        count=len(n.classes[cid][1]);prefix,_=split_cframe(n.prop(cid,'CFrame',16),count)
        result=[];offset=0
        for _ in range(count):
            size=1 if prefix[offset] else 37;result.append(prefix[offset:offset+size]);offset+=size
        assert offset==len(prefix);return result
    updates={};used=set()
    for r in old_refs:
        choices=[s for s in new_refs if s not in used and close(a.get(r,'size'),b.get(s,'size'),.0001)]
        assert len(choices)==1
        s=choices[0];used.add(s);cid,_,i,_=native.instances[r];scid,_,si,_=export.instances[s]
        assert a.get(r,'MaterialVariantSerialized')==b.get(s,'MaterialVariantSerialized')
        assert sum((x-y)**2 for x,y in zip(a.get(r,'CFrame'),b.get(s,'CFrame')))<400
        if cid not in updates:updates[cid]=[rotations(native,cid),[a.get(x,'CFrame') for x in native.classes[cid][1]]]
        updates[cid][0][i]=rotations(export,scid)[si];updates[cid][1][i]=b.get(s,'CFrame')
    out=[data[:32]]
    for kind,payload,raw in native.chunks:
        if kind==b'PROP':
            prop,off=string(payload,4);cid=u32(payload)
            if prop=='CFrame' and cid in updates:
                rot,pos=updates[cid];raw=chunk(kind,payload[:off+1]+b''.join(rot)+pack_vectors(pos))
        out.append(raw)
    final=Native(b''.join(out))
    assert final.instances==native.instances and final.parents==native.parents
    assert {k for k,v in native.props.items() if final.props[k]!=v}<={(cid,'CFrame') for cid in updates}
    assert script_inventory(final.chunks)==script_inventory(native.chunks)
    # Read every written position back; rotation bytes come directly from Studio.
    v=Values(final)
    for r in old_refs:
        cid,_,i,_=native.instances[r];assert close(v.get(r,'CFrame'),updates[cid][1][i],.0001)
    return final.data,len(old_refs)

LUA = r'''
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(game:GetService('RunService'):IsEdit(),'Stop Play first')
local plan=game.HttpService:JSONDecode([==[PLAN_JSON]==])
local function matches(path)
 local nodes={game}
 for name in path:gmatch('[^.]+') do
  local nextNodes={}
  for _,node in nodes do for _,child in node:GetChildren() do if child.Name==name then table.insert(nextNodes,child) end end end
  nodes=nextNodes
 end
 return nodes
end
local function one(path) local a=matches(path);assert(#a==1,path..': '..#a);return a[1] end
local function near(a,b) return math.abs(a-b)<.002 end
local function color(c,v) return math.abs(c.R*255-v[1])<=1.01 and math.abs(c.G*255-v[2])<=1.01 and math.abs(c.B*255-v[3])<=1.01 end
local function value(v) if type(v)=='table' then return Color3.new(unpack(v)) else return v end end
local function same(a,b)
 if typeof(a)=='Color3' then return near(a.R,b[1]) and near(a.G,b[2]) and near(a.B,b[3]) end
 return type(a)=='number' and near(a,b) or a==b
end
local edits={}
local relocated={}
for _,e in plan.parts do
 local candidates={}
 for _,p in matches(e.path) do
  if p.ClassName==e.class and (p.Position-Vector3.new(unpack(e.anchor))).Magnitude<.002 and (p.Size-Vector3.new(unpack(e.size))).Magnitude<.002 then table.insert(candidates,p) end
 end
 if #candidates==0 then
  for _,p in matches(e.path) do
   if p.ClassName==e.class and (p.Size-Vector3.new(unpack(e.size))).Magnitude<.002 then table.insert(candidates,p) end
  end
  assert(#candidates==1,e.path..': moved part is not unique')
  local p=candidates[1]
  assert(e.path:find('.OriginalDetails.',1,true) and (p.Position-Vector3.new(unpack(e.anchor))).Magnitude<20,'Unreconciled geometry: '..e.path)
  table.insert(relocated,{ref=e.ref,path=e.path,cframe={p.CFrame:GetComponents()}})
 end
 assert(#candidates>0,e.path..': missing')
 for _,p in candidates do
  if e.before.color then assert(color(p.Color,e.before.color),e.path..': color differs') end
  if e.before.variant then assert(p.MaterialVariant==e.before.variant,e.path..': material differs') end
  table.insert(edits,{p=p,e=e})
 end
end
local assigned={}
for _,h in edits do
 if assigned[h.p] then
  local other=assigned[h.p]
  assert((not h.e.after.color or color(Color3.fromRGB(unpack(other.after.color)),h.e.after.color)) and h.e.after.variant==other.after.variant,'Conflicting overlapping appearance')
 else assigned[h.p]=h.e end
end
local props={}
for _,e in plan.properties do local p=one(e.path);assert(same(p[e.property],e.before),e.path..'.'..e.property..': live differs');table.insert(props,{p=p,e=e}) end
local moves={}
for _,e in plan.moves do local p=one(e.path);assert(#p:GetDescendants()==e.descendants);assert(not game.ServerStorage:FindFirstChild(p.Name));table.insert(moves,{p=p,parent=p.Parent}) end
local map=workspace.MiningAway.Map
local display=map.JunkCubeAreas
local displayCount=#display:GetDescendants()
local support={}
for _,f in workspace.MiningAway.Fields:GetChildren() do
 local p=f:FindFirstChild('Field');if p then support[p]={p.CFrame,p.Size} end
end
local function verify()
 for _,h in edits do local p,e=h.p,h.e
  if e.after.color then assert(color(p.Color,e.after.color),e.path) end
  if e.after.variant then assert(p.MaterialVariant==e.after.variant,e.path) end
 end
 for _,h in props do assert(same(h.p[h.e.property],h.e.after)) end
 for _,h in moves do assert(h.p.Parent==game.ServerStorage) end
 for p,v in support do assert(p.CFrame==v[1] and p.Size==v[2]) end
 assert(display.Parent==map and #display:GetDescendants()==displayCount)
 return {parts=#edits,lighting=#props,archived=#moves,displayDescendants=displayCount,fields=6}
end
shared.ReferenceLook={plan=plan,relocated=relocated,verify=verify,apply=function()
 for _,h in edits do local p,e=h.p,h.e;if e.after.color then p.Color=Color3.fromRGB(unpack(e.after.color)) end;if e.after.variant then p.MaterialVariant=e.after.variant end end
 for _,h in props do h.p[h.e.property]=value(h.e.after) end
 for _,h in moves do h.p.Parent=game.ServerStorage end
 return verify()
end}
return {stagedParts=#edits,lighting=#props,archives=#moves,displayDescendants=displayCount,relocated=relocated}
'''

def main():
    p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
    data=CANONICAL_OUTPUT.read_bytes();a.directory.mkdir(parents=True,exist_ok=True)
    plan_path=a.directory/'plan.json'
    if a.write:
        plan=json.loads(plan_path.read_text());result,report=merged(data,plan)
        result,report['preserved_live_tree_parts']=reconcile_tree(result,a.directory)
        write_snapshot(data,result)
    else:
        plan=prepare(data);result,report=merged(data,plan)
        plan_path.write_text(json.dumps(plan,indent=2)+'\n')
        (a.directory/'stage.lua').write_text(LUA.replace('PLAN_JSON',json.dumps(plan,separators=(',',':'))))
    print(json.dumps(dict(report,wrote=a.write,baseline=plan['baseline'],sha256=sha256(result).hexdigest())))

if __name__=='__main__': main()
