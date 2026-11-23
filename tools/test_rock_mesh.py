#!/usr/bin/env python3
"""The deformable dig rock (RockMesh) and the DigCubeView piece that uses it,
run headless in the Luau CLI with exact 3D math doubles and an EditableMesh
double that records every vertex, face, normal and color.

Checks: a piece becomes one closed mesh of Voronoi tiles (top faces up, sides
out, bounds pinned symmetric about the pivot); a beam's ripple moves only the
tops, fades to nothing at the piece's edge, is continuous across tiles and
runs outward (inward for the Singularity); a shock ring travels; a popped
chunk moves rigidly, rises and turns by a snapped angle, stays out, and its
normals follow; a missing API falls back to wedges for good while a memory
budget miss does not. Then the real DigCubeView: each role's piece builds a
mesh, a stage piece is held until its break op lands, cracks/slams/pulses/
darts/charges pop chunks, Halver halves slide, Singularity squeezes,
Frostbite ices, dropping the piece frees the mesh, the wedge fallback still
poses and shades, and the per-frame cost is printed.
Not engine QA: how it looks and how fast it really is need a Studio Play.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

from build import ROOT, module_bundle

luau = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/mining-away-luau") / "luau"

doubles = r'''
local realClock=os.clock
local fakeClock=0
local os={clock=function() return fakeClock end,time=function() return 0 end}
local function signal()
 local s={list={}}
 function s:Connect(f) local c={f=f};function c:Disconnect() end;table.insert(self.list,c);return c end
 function s:Fire(...) for _,c in ipairs(self.list) do c.f(...) end end
 return s
end
-- Vector3
local VM={}
local function v3(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},VM) end
VM.__index=function(v,k)
 if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)
 elseif k=='Unit' then local m=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z);return v3(v.X/m,v.Y/m,v.Z/m) end
 return VM[k]
end
VM.__add=function(a,b) return v3(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
VM.__sub=function(a,b) return v3(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
VM.__unm=function(a) return v3(-a.X,-a.Y,-a.Z) end
VM.__mul=function(a,b)
 if type(a)=='number' then a,b=b,a end
 if type(b)=='table' then return v3(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
 return v3(a.X*b,a.Y*b,a.Z*b)
end
VM.__div=function(a,b) if type(b)=='table' then return v3(a.X/b.X,a.Y/b.Y,a.Z/b.Z) end;return v3(a.X/b,a.Y/b,a.Z/b) end
VM.__eq=function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
function VM:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function VM:Cross(b) return v3(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function VM:Lerp(b,t) return self+(b-self)*t end
function VM:Min(b) return v3(math.min(self.X,b.X),math.min(self.Y,b.Y),math.min(self.Z,b.Z)) end
function VM:Max(b) return v3(math.max(self.X,b.X),math.max(self.Y,b.Y),math.max(self.Z,b.Z)) end
local Vector3={new=v3}
Vector3.zero=v3(0,0,0);Vector3.one=v3(1,1,1);Vector3.xAxis=v3(1,0,0);Vector3.yAxis=v3(0,1,0);Vector3.zAxis=v3(0,0,1)
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
-- CFrame: position + rotation matrix rows
local CM={}
local function cf(p,m) return setmetatable({p=p,m=m},CM) end
local I3={1,0,0,0,1,0,0,0,1}
local function mm(a,b)
 local r={}
 for i=0,2 do for j=0,2 do r[i*3+j+1]=a[i*3+1]*b[j+1]+a[i*3+2]*b[3+j+1]+a[i*3+3]*b[6+j+1] end end
 return r
end
local function mv(m,v) return v3(m[1]*v.X+m[2]*v.Y+m[3]*v.Z,m[4]*v.X+m[5]*v.Y+m[6]*v.Z,m[7]*v.X+m[8]*v.Y+m[9]*v.Z) end
local function tr(m) return {m[1],m[4],m[7],m[2],m[5],m[8],m[3],m[6],m[9]} end
CM.__index=function(c,k)
 if k=='Position' then return c.p
 elseif k=='Rotation' then return cf(Vector3.zero,c.m)
 elseif k=='LookVector' then return v3(-c.m[3],-c.m[6],-c.m[9])
 elseif k=='X' then return c.p.X elseif k=='Y' then return c.p.Y elseif k=='Z' then return c.p.Z end
 return CM[k]
end
CM.__mul=function(a,b)
 if getmetatable(b)==VM then return a.p+mv(a.m,b) end
 return cf(a.p+mv(a.m,b.p),mm(a.m,b.m))
end
CM.__add=function(a,v) return cf(a.p+v,a.m) end
CM.__sub=function(a,v) return cf(a.p-v,a.m) end
CM.__eq=function(a,b)
 if a.p~=b.p then return false end
 for i=1,9 do if a.m[i]~=b.m[i] then return false end end
 return true
end
function CM:Inverse() local t=tr(self.m);return cf(-mv(t,self.p),t) end
function CM:ToObjectSpace(o) return self:Inverse()*o end
function CM:PointToWorldSpace(v) return self*v end
function CM:PointToObjectSpace(v) return self:Inverse()*v end
local CFrame={}
CFrame.identity=cf(Vector3.zero,I3)
function CFrame.new(x,y,z)
 if x==nil then return CFrame.identity end
 if getmetatable(x)==VM then return cf(x,I3) end
 return cf(v3(x,y,z),I3)
end
local function rx(a) local c,s=math.cos(a),math.sin(a);return {1,0,0,0,c,-s,0,s,c} end
local function ry(a) local c,s=math.cos(a),math.sin(a);return {c,0,s,0,1,0,-s,0,c} end
local function rz(a) local c,s=math.cos(a),math.sin(a);return {c,-s,0,s,c,0,0,0,1} end
function CFrame.Angles(a,b,c) return cf(Vector3.zero,mm(mm(rx(a or 0),ry(b or 0)),rz(c or 0))) end
function CFrame.fromAxisAngle(axis,angle)
 local u=axis.Unit;local c,s=math.cos(angle),math.sin(angle);local t=1-c
 local x,y,z=u.X,u.Y,u.Z
 return cf(Vector3.zero,{t*x*x+c,t*x*y-s*z,t*x*z+s*y, t*x*y+s*z,t*y*y+c,t*y*z-s*x, t*x*z-s*y,t*y*z+s*x,t*z*z+c})
end
function CFrame.fromMatrix(p,r,u,b) b=b or r:Cross(u);return cf(p,{r.X,u.X,b.X,r.Y,u.Y,b.Y,r.Z,u.Z,b.Z}) end
local Color3={}
local CO={}
CO.__index=CO
function Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b},CO) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function CO:Lerp(o,t) return Color3.new(self.R+(o.R-self.R)*t,self.G+(o.G-self.G)*t,self.B+(o.B-self.B)*t) end
CO.__eq=function(a,b) return a.R==b.R and a.G==b.G and a.B==b.B end
local NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local NumberSequence={new=function(...) return {...} end}
local ColorSequence={new=function(...) return {...} end}
local ColorSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local PhysicalProperties={new=function(...) return {...} end}
local UDim2={new=function(...) return {...} end,fromScale=function(...) return {...} end,fromOffset=function(...) return {...} end}
local Enum=setmetatable({},{__index=function(t,k) local e=setmetatable({},{__index=function(_,x) return k..'.'..x end});rawset(t,k,e);return e end})
local function typeof(x)
 local m=getmetatable(x)
 if m==VM then return 'Vector3' elseif m==CM then return 'CFrame' elseif m==CO then return 'Color3' end
 return type(x)
end
-- Instances
local IM={}
local IT={}
IT.__index=function(i,k)
 if IM[k] then return IM[k] end
 local v=rawget(i,'_p')[k]
 if v~=nil then return v end
 for _,c in ipairs(rawget(i,'_c')) do if c.Name==k then return c end end
 return nil
end
IT.__newindex=function(i,k,v)
 if k=='Parent' then
  local old=i._p.Parent
  if old then for n,c in ipairs(old._c) do if c==i then table.remove(old._c,n);break end end end
  i._p.Parent=v;if v then table.insert(v._c,i) end
 elseif k=='Position' then i._p.CFrame=cf(v,(i._p.CFrame or CFrame.identity).m)
 else i._p[k]=v end
end
local instances=0
local Instance={}
function Instance.new(class)
 instances+=1
 return setmetatable({_p={ClassName=class,Name=class,CFrame=CFrame.identity,Size=Vector3.one,Transparency=0},_c={},_a={},ChildAdded=signal(),AttributeChanged=signal()},IT)
end
function IM:IsA(c) return self.ClassName==c or (c=='BasePart' and (self.ClassName=='Part' or self.ClassName=='WedgePart' or self.ClassName=='MeshPart')) end
function IM:GetChildren() return table.clone(self._c) end
function IM:GetDescendants() local a={};for _,c in ipairs(self._c) do table.insert(a,c);for _,d in ipairs(c:GetDescendants()) do table.insert(a,d) end end;return a end
function IM:FindFirstChild(n) for _,c in ipairs(self._c) do if c.Name==n then return c end end;return nil end
function IM:FindFirstChildWhichIsA(c) for _,x in ipairs(self:GetDescendants()) do if x:IsA(c) then return x end end;return nil end
function IM:SetAttribute(k,v) self._a[k]=v end
function IM:GetAttribute(k) return self._a[k] end
function IM:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;rawset(self,'destroyed',true) end
local workspace=Instance.new('Workspace')
function workspace:GetServerTimeNow() return fakeClock end
-- EditableMesh double: every call recorded; failure modes switchable.
local meshMode='ok'
local meshes={}
local EM={}
EM.__index=EM
function EM:AddVertex(p) table.insert(self.v,p);return #self.v end
function EM:AddTriangle(a,b,c) assert(self.v[a] and self.v[b] and self.v[c],'triangle on unknown vertex');table.insert(self.f,{a,b,c});return #self.f end
function EM:AddNormal(n) table.insert(self.n,n or false);return #self.n end
function EM:SetFaceNormals(f,ids) assert(self.f[f]);for _,id in ipairs(ids) do assert(self.n[id]~=nil) end;self.fn[f]=ids end
function EM:AddColor(c,a) table.insert(self.c,{c,a});return #self.c end
function EM:SetFaceColors(f,ids) assert(self.f[f] and #ids==3);for _,id in ipairs(ids) do assert(self.c[id],'unknown color') end;self.fc[f]=ids end
function EM:SetPosition(id,p) assert(self.v[id]);self.v[id]=p;self.writes+=1 end
function EM:GetPosition(id) return self.v[id] end
function EM:SetNormal(id,n) assert(self.n[id]~=nil);self.n[id]=n;self.writes+=1 end
function EM:SetColor(id,c) assert(self.c[id]);self.c[id][1]=c;self.writes+=1 end
function EM:Destroy() self.dead=true end
local Content={fromObject=function(x) return {object=x} end}
local AssetService={}
function AssetService:CreateEditableMesh()
 if meshMode=='denied' then error('EditableMesh is not accessible') end
 if meshMode=='budget' then error('Failed to create EditableMesh: out of memory budget') end
 local m=setmetatable({v={},f={},n={},fn={},c={},fc={},writes=0},EM)
 table.insert(meshes,m)
 return m
end
function AssetService:CreateMeshPartAsync(content,opts)
 local m=content.object
 local lo,hi=v3(math.huge,math.huge,math.huge),v3(-math.huge,-math.huge,-math.huge)
 for _,p in ipairs(m.v) do lo=lo:Min(p);hi=hi:Max(p) end
 local part=Instance.new('MeshPart');part.Size=hi-lo;part.MeshSize=hi-lo;part.MeshCenter=(lo+hi)*.5;part.mesh=m
 return part
end
local UIS={InputBegan=signal(),InputEnded=signal()}
local Players={LocalPlayer=nil}
local game={}
function game:GetService(n)
 if n=='AssetService' then return AssetService elseif n=='UserInputService' then return UIS elseif n=='Players' then return Players end
 if n=='GuiService' then return {ReducedMotionEnabled=false} end
 error('missing service '..n)
end
local task={spawn=function(f,...) return f(...) end,defer=function(f,...) return f(...) end}
local Random={}
function Random.new(seed)
 local r={s=seed or 1}
 function r:NextNumber(a,b) self.s=(self.s*16807)%2147483647;local x=self.s/2147483647;if a==nil then return x end;return a+x*(b-a) end
 function r:NextInteger(a,b) return math.floor(self:NextNumber(a,b+1)) end
 return r
end
local RaycastParams={new=function() return {} end}
'''

checks = r'''
local RockMesh=DigCubeView.RockMesh
assert(RockMesh,'DigCubeView exposes RockMesh for tests')
local DigCube=DigCubeView.DigCube
local function near(a,b,e) return math.abs(a-b)<=(e or 1e-6) end
local function normalOf(m,f)
 local t=m.f[f];local a,b,c=m.v[t[1]],m.v[t[2]],m.v[t[3]]
 return (b-a):Cross(c-a)
end
-- ===== RockMesh alone =====
local hex={}
for k=0,5 do local a=k*math.pi/3;table.insert(hex,{math.cos(a)*2.4,math.sin(a)*2.4}) end
local square={{2.4,-1.2},{5.4,-1.2},{5.4,1.8},{2.4,1.8}}
local stone=Color3.fromRGB(150,130,110)
local random=Random.new(5)
local rng=function() return random:NextNumber() end
local rec=RockMesh.build({{poly=hex,y0=-2,y1=0,color=stone},{poly=square,y0=-2,y1=0,color=stone,side=1}},DigCube.voronoiSplit,rng)
assert(rec and rec.part and rec.mesh,'a piece becomes one mesh part')
local m=rec.mesh
assert(#rec.tiles>=3 and #rec.tiles<=RockMesh.MAX_TILES,'tiles: '..#rec.tiles)
-- Bounds: pinned symmetric about the pivot, so the part centre is the pivot.
assert(near(rec.part.MeshCenter.X,0,1e-4) and near(rec.part.MeshCenter.Y,0,1e-4) and near(rec.part.MeshCenter.Z,0,1e-4),'bounds centred on the pivot')
local size0=rec.part.MeshSize
-- Every face: its stored normal matches its winding and points the right way.
local tops,sides=0,0
for _,f in ipairs(rec.faces) do
 local n=normalOf(m,f.id)
 assert(n.Magnitude>1e-9,'no degenerate face')
 local stored=m.n[f.n]
 assert((n.Unit-stored).Magnitude<1e-6,'stored normal = face normal')
 if f.side then
  sides+=1
  assert(math.abs(n.Unit.Y)<1e-6,'sides are vertical')
  local mid=(f.a.base+f.b.base+f.c.base)/3
  assert(n:Dot(v3(mid.X-f.tile.cx,0,mid.Z-f.tile.cz))>0,'sides face out of their tile')
 else tops+=1;assert(n.Unit.Y>.999,'tops face up') end
 assert(m.fc[f.id],'every face colored')
end
assert(tops>0 and sides>0,'tops and sides')
-- One step without effects writes the rest pose and nothing moves.
fakeClock=1
RockMesh.step(rec,fakeClock,{})
for _,v in ipairs(rec.verts) do assert(v.pos==v.base,'rest pose') end
-- Ripple: tops move, bottoms never; nothing at the rim; continuous across tiles.
local moved,maxEdge=0,0
local byPos={}
for t=1,12 do
 fakeClock=1+t/30
 RockMesh.step(rec,fakeClock,{ripple={amp=.12,len=2.4,speed=4.5,glow=.5},glowColor=Color3.new(1,.6,.1)})
 for _,v in ipairs(rec.verts) do
  if not v.top then assert(v.pos==v.base,'bottoms stay') else
   local dy=v.pos.Y-v.base.Y
   if math.abs(dy)>1e-4 then moved+=1 end
   local r=math.sqrt(v.base.X^2+v.base.Z^2)
   if r>=rec.radius-1e-6 then maxEdge=math.max(maxEdge,math.abs(dy)) end
   assert(math.abs(dy)<=.12+1e-9,'ripple within its amplitude')
  end
 end
end
assert(moved>0,'the ripple moves the tops')
assert(maxEdge<.03,string.format('the ripple dies out at the rim: %.3f',maxEdge))
for _,v in ipairs(rec.verts) do
 if v.top then
  local key=string.format('%.4f,%.4f',v.base.X,v.base.Z)
  local other=byPos[key]
  if other and other.tile~=v.tile then assert(near(other.pos.Y,v.pos.Y,1e-9),'continuous across tiles') end
  byPos[key]=v
 end
end
-- The crest glows toward the attack color.
local glowing=false
for _,entry in ipairs(rec.topColors) do if entry.last and entry.last.B<stone.B-.02 and entry.last.R>stone.R then glowing=true end end
assert(glowing,'ripple crests glow')
-- Outward: the crest moves out over time (inward with a negative speed).
local big={}
for k=0,5 do local a=k*math.pi/3;table.insert(big,{math.cos(a)*6.5,math.sin(a)*6.5}) end
local wide=RockMesh.build({{poly=big,y0=-2,y1=0,color=stone}},DigCube.voronoiSplit,rng)
local function crestRadius(rr,t,speed)
 RockMesh.step(rr,t,{ripple={amp=.1,len=9,speed=speed,glow=0}})
 local best,bestR=-math.huge,0
 for _,v in ipairs(rr.verts) do
  if v.top then
   local r=math.sqrt(v.base.X^2+v.base.Z^2)
   local env=math.clamp(1-r/(rr.radius+.3),0,1)^.6
   if r>.5 and r<5.5 and env>.1 then
    local value=(v.pos.Y-v.base.Y)/env
    if value>best then best,bestR=value,r end
   end
  end
 end
 return bestR
end
local r1=crestRadius(wide,11.0625,4);local r2=crestRadius(wide,11.4625,4)
assert(r2>r1+.6,string.format('ripple runs outward: %.2f -> %.2f',r1,r2))
local i1=crestRadius(wide,10.8125,-4);local i2=crestRadius(wide,11.2125,-4)
assert(i2<i1-.6,string.format('a negative speed runs inward: %.2f -> %.2f',i1,i2))
RockMesh.step(wide,30,{})
-- Shock ring: its front travels.
RockMesh.ring(wide,40,Vector3.zero,.3,8,.6,.5)
local function ringFront(t)
 RockMesh.step(wide,t,{})
 local best,bestR=0,0
 for _,v in ipairs(wide.verts) do if v.top and v.pos.Y-v.base.Y>best then best,bestR=v.pos.Y-v.base.Y,math.sqrt(v.base.X^2+v.base.Z^2) end end
 return bestR,best
end
local f1,h1=ringFront(40.02);local f2,h2=ringFront(40.2)
assert(h1>.05 and f2>f1,string.format('ring front moves out: %.2f -> %.2f',f1,f2))
RockMesh.step(wide,45,{})
for _,v in ipairs(wide.verts) do assert(near(v.pos.Y,v.base.Y,1e-9),'the ring passes and the rock settles') end
-- Pops: rigid, up, snapped angle, stays out; normals follow; bounds fixed.
fakeClock=50
RockMesh.step(rec,fakeClock,{})
RockMesh.pop(rec,2,1.2,fakeClock,Random.new(3),'pry')
local popped={}
for _,t in ipairs(rec.tiles) do if t.popped then table.insert(popped,t) end end
assert(#popped==2,'two chunks pop')
for k=1,20 do fakeClock=50+k/40;RockMesh.step(rec,fakeClock,{}) end
for _,t in ipairs(popped) do
 assert(t.anim==nil,'pop animation done')
 local steps=t.angle/RockMesh.ANGLE_STEP
 assert(t.angle>0 and near(steps,math.floor(steps+.5),1e-9),'snapped angle: '..math.deg(t.angle))
 local cy=0;local n=0
 for _,v in ipairs(t.verts) do if v.top then cy+=v.pos.Y-v.base.Y;n+=1 end end
 assert(cy/n>.05,'the chunk rises: '..cy/n)
 -- rigid: distances between its vertices unchanged
 for i=2,#t.verts do
  local a,b=t.verts[1],t.verts[i]
  assert(near((a.pos-b.pos).Magnitude,(a.base-b.base).Magnitude,1e-6),'a popped chunk moves rigidly')
 end
end
for _,f in ipairs(rec.faces) do
 local n=normalOf(m,f.id);assert((n.Unit-m.n[f.n]).Magnitude<1e-6,'normals follow the pop')
end
for _,t in ipairs(rec.tiles) do if not t.popped then for _,v in ipairs(t.verts) do assert(v.pos==v.base,'other chunks stay') end end end
local lo,hi=v3(math.huge,math.huge,math.huge),v3(-math.huge,-math.huge,-math.huge)
for _,p in ipairs(m.v) do lo=lo:Min(p);hi=hi:Max(p) end
assert(((hi-lo)-size0).Magnitude<1e-9,'bounds never change')
-- Lift pops stay within the pinned bounds.
for _=1,6 do RockMesh.pop(rec,3,1.6,fakeClock,Random.new(9),'lift');fakeClock+=.3;RockMesh.step(rec,fakeClock,{}) end
for _,p in ipairs(m.v) do assert(math.abs(p.Y)<=rec.bounds.Y+1e-9,'pops stay inside the bounds') end
-- Halver slide moves each half its own way; scale squeezes toward the pivot.
local left={{-3,-1},{0,-1},{0,1},{-3,1}}
local halves=RockMesh.build({{poly=left,y0=-1,y1=0,color=stone,side=-1},{poly=square,y0=-1,y1=0,color=stone,side=1},{poly=hex,y0=-1,y1=0,color=stone}},DigCube.voronoiSplit,rng)
RockMesh.step(halves,60,{slide=v3(.2,0,0)})
for _,v in ipairs(halves.verts) do
 local want=v.base+v3(.2,0,0)*(v.tile.side or 0)
 assert((v.pos-want).Magnitude<1e-9,'each half slides its own way, the rest stays')
end
RockMesh.step(halves,61,{scale=.8})
for _,v in ipairs(halves.verts) do
 assert(near(v.pos.X,v.base.X*.8,1e-9) and near(v.pos.Z,v.base.Z*.8,1e-9) and near(v.pos.Y,v.base.Y,1e-9),'squeeze toward the pivot')
end
RockMesh.step(halves,62,{})
for _,v in ipairs(halves.verts) do assert(v.pos==v.base,'back at rest') end
RockMesh.destroy(halves)
RockMesh.destroy(rec);RockMesh.destroy(wide)
assert(m.dead and RockMesh.live==0,'destroy frees the mesh')
-- Failure modes.
meshMode='budget'
assert(RockMesh.build({{poly=hex,y0=-2,y1=0,color=stone}},DigCube.voronoiSplit,rng)==nil and not RockMesh.failed,'a budget miss is not permanent')
meshMode='denied'
assert(RockMesh.build({{poly=hex,y0=-2,y1=0,color=stone}},DigCube.voronoiSplit,rng)==nil and RockMesh.failed,'a missing API turns meshes off')
RockMesh.failed=false;meshMode='ok'
print('PASS RockMesh: closed tile mesh with pinned bounds and true normals; ripple tops-only, rim-faded, continuous, outward/inward; ring travels and settles; pops rigid, snapped, stay out; failure modes')

-- ===== DigCubeView pieces =====
local V=DigCubeView
local function view()
 local self=setmetatable({ctx={},beams={},splits={},frags={},banners={},dust={},puffs=0,mine={},cellColor={},cellCode={},cellAccent={},cutStage={},flashes={},pending={},floors={},cracks={},crackCells={},sinks={},
  generation=1,applied=0,random=Random.new(11),connections={},tapAt=0,geodes={},geodeOwner={},localOpened={},sealedIds={},chains={},frost={},hints={},shots={}},V)
 self.fx=Instance.new('Folder');self.fx.Parent=workspace
 self.cube=DigCube.build(424242);self.origin=v3(100,-40,20)
 return self
end
local function chunkFor(self,size)
 local cube=self.cube
 local best,score=nil,math.huge
 for _,id in ipairs(cube.layers[1].cells) do local c=cube.cells[id];local s=(c.cx-44)^2+(c.cz-44)^2;if s<score then best,score=id,s end end
 return DigCube.chunk(cube,best,size,nil,function() return .5 end)
end
local function source(self,ids)
 local s=Instance.new('Model')
 local cx,cz=DigCube.chunkCenter(self.cube,ids)
 s:SetAttribute('DigPoint',self.origin+v3(cx,self.cube.cells[ids[1]].y1,cz))
 return s
end
local live0=RockMesh.live
-- A Striker chunk: terrace stages, held until each stage op.
do
 local self=view()
 local ids=chunkFor(self,1.4);local key=DigCube.key(ids)
 local pieces=DigCube.pieces(self.cube,ids,'terrace')
 assert(#pieces>=2,'a terrace chunk')
 local src=source(self,ids)
 local tint=V.primaryColor('L')
 fakeClock=100
 local writes0=0
 self:crackStage(key,0,fakeClock,tint,true,true,'L',src)
 local job=self.cracks[key]
 assert(job and job.proxy and job.proxy.mesh,'a mesh piece is built at once (async build, synchronous double)')
 local first=job.proxy.mesh
 assert(first.part.Parent==job.proxy.model,'the mesh is in the piece model')
 assert(job.proxy.aux and #job.proxy.aux:GetChildren()>0,'every role gets the static hold over its carved-ahead hole')
 -- Work it past the first stage's share without its op: still the first piece.
 local t0=realClock()
 local frames=0
 for f=1,90 do
  fakeClock=100+f/60
  self:crackStage(key,math.min(.24,f/60*.2)+(f>60 and .2 or 0),fakeClock,tint,true,true,'L',src);frames+=1
 end
 local cost=(realClock()-t0)/frames
 assert(job.piece==1 and job.proxy.mesh==first,'a stage piece is held until its break op lands')
 local rippled=false
 for _,v in ipairs(first.verts) do if v.top and math.abs(v.pos.Y-v.base.Y)>1e-3 then rippled=true end end
 assert(rippled,'the beam ripples the piece')
 local anyPop=false
 for _,t in ipairs(first.tiles) do if t.popped then anyPop=true end end
 assert(anyPop,'the crack popped chunks loose')
 -- The stage op lands: the next piece, the old mesh freed.
 self.cutStage[key]=1
 fakeClock+=1/60
 self:crackStage(key,.45,fakeClock,tint,true,true,'L',src)
 assert(job.piece==2 and job.proxy.mesh~=first and first.dead,'next piece after the op; old mesh freed')
 -- Charging (not cutting): no ripple writes beyond the settle.
 local m2=job.proxy.mesh
 for f=1,10 do fakeClock+=1/60;self:crackStage(key,.46,fakeClock,tint,true,false,'L',src) end
 local w=m2.mesh.writes
 for f=1,10 do fakeClock+=1/60;self:crackStage(key,.46,fakeClock,tint,true,false,'L',src) end
 assert(m2.mesh.writes-w<=#m2.topColors+#m2.tiles,'an idle piece costs almost nothing')
 self:clearCracks()
 assert(m2.dead and RockMesh.live==live0,'dropping pieces frees their meshes')
 print(string.format('  Striker piece: %d tiles, %d verts, %.3f ms per frame (Luau CLI with doubles)',#first.tiles,#first.verts,cost*1000))
end
-- Each other role: its own mesh behaviour.
local function roleRun(code,size,frames,progressAt,extra)
 local self=view()
 local ids=chunkFor(self,size);local key=DigCube.key(ids)
 local src=source(self,ids)
 local tint=V.primaryColor(code)
 fakeClock=200
 local job
 for f=0,frames do
  fakeClock=200+f/60
  local progress=progressAt(f)
  if extra then extra(self,key,f) end
  self:crackStage(key,progress,fakeClock,tint,true,true,code,src)
  job=self.cracks[key]
 end
 return self,job
end
local function popCount(rec) local n=0;for _,t in ipairs(rec.tiles) do if t.popped then n+=1 end end;return n end
do -- Charger: each slam rings and lifts chunks
 local self,job=roleRun('C',1.9,40,function(f) return .1 end,function(self,key,f)
  local job=self.cracks[key];if job and (f==10 or f==30) then job.slamAt=fakeClock end
 end)
 assert(popCount(job.proxy.mesh)>=4,'Charger slams pop chunks: '..popCount(job.proxy.mesh))
 self:clearCracks()
end
do -- Lancer: each pulse rings and pries a chunk
 local self,job=roleRun('Z',1,40,function(f) return .1 end,function(self,key,f)
  local job=self.cracks[key];if job and (f==10 or f==30) then job.pulseAt=fakeClock end
 end)
 assert(popCount(job.proxy.mesh)>=2,'Lancer pulses pop chunks')
 self:clearCracks()
end
do -- Needler: each dart (a jump in the work) pops a chunk
 local self,job=roleRun('N',.6,40,function(f) return math.floor(f/8)*.1 end)
 assert(popCount(job.proxy.mesh)>=3,'Needler darts pop chunks: '..popCount(job.proxy.mesh))
 self:clearCracks()
end
do -- Ballcaster: chunks work loose as the charge builds; the piece shivers
 local self,job=roleRun('B',.6,120,function(f) return f/120 end)
 local rec=job.proxy.mesh
 assert(popCount(rec)>=math.floor(#rec.tiles*.5)-1,'Ballcaster charge pops about half the chunks: '..popCount(rec)..'/'..#rec.tiles)
 self:clearCracks()
end
do -- Halver: final piece in halves that slide apart
 local self=view()
 local ids=chunkFor(self,1);local key=DigCube.key(ids)
 local src=source(self,ids)
 self.cutStage[key]=#DigCube.pieces(self.cube,ids,'terrace')-1
 fakeClock=300
 for f=0,30 do fakeClock=300+f/60;self:crackStage(key,.9+f/300,fakeClock,V.primaryColor('H'),true,true,'H',src) end
 local proxy=self.cracks[key].proxy
 local sided=0;for _,t in ipairs(proxy.mesh.tiles) do if t.side then sided+=1 end end
 assert(sided>0 and proxy.normal,'Halver halves')
 self:clearCracks()
end
do -- Singularity squeezes, Frostbite ices
 local self,job=roleRun('Y',1.9,60,function(f) return .1+f/200 end)
 assert(job.proxy.scale<1,'Singularity squeezes')
 self:clearCracks()
 local self2,job2=roleRun('I',.85,60,function(f) return .3+f/100 end)
 assert(job2.proxy.mesh.part.Material==Enum.Material.Ice,'Frostbite ices the mesh')
 self2:clearCracks()
end
-- The test area: nine looping display rocks west of the cube, each moving.
do
 local self=view()
 local before=RockMesh.live
 fakeClock=1000
 self:stepShowcase(fakeClock)
 assert(#self.showcase.stations==9,'nine display rocks')
 local moved={}
 for f=1,300 do
  fakeClock=1000+f/60
  self:stepShowcase(fakeClock)
  for i,st in ipairs(self.showcase.stations) do
   assert(st.rec and st.rec.part.Parent==self.showcase.root,'station '..i..' has its mesh')
   for _,v in ipairs(st.rec.verts) do if (v.pos-v.base).Magnitude>.02 then moved[i]=true end end
  end
 end
 for i,st in ipairs(self.showcase.stations) do assert(moved[i],st.def.name..' animates') end
 assert(self.showcase.stations[1].pivot.X<self.origin.X and self.showcase.stations[1].pivot.Y>self.origin.Y+self.cube.height,'west of the cube, above the ground')
 -- A new cube rebuilds the row and frees the old meshes.
 local old=self.showcase.stations[1].rec
 self.generation=2;self:stepShowcase(fakeClock+.1)
 assert(old.dead and RockMesh.live==before+9,'rebuilt once per cube')
 for _,st in ipairs(self.showcase.stations) do RockMesh.destroy(st.rec) end
 -- Meshes off: the sign says so.
 RockMesh.failed=true
 local off=view();off:stepShowcase(fakeClock)
 assert(string.find(off.showcase.stations[1].sub.Text,'MESH EFFECTS OFF'),'the sign reports meshes off')
 RockMesh.failed=false
 print('PASS test area: nine display rocks loop ripple/inward/square/fast ripples, crack pops, slam, pulse, charge, darts; rebuilt per cube; sign shows when meshes are off')
end
-- Wedge fallback when meshes are off: posed and shaded as before.
do
 RockMesh.failed=true
 local self,job=roleRun('L',1,30,function(f) return f/200 end)
 local proxy=job.proxy
 assert(proxy.mesh==nil and #proxy.parts>0,'wedges when meshes are off')
 assert(proxy.parts[1].part.Parent==proxy.model,'wedges in the piece model')
 self:clearCracks()
 RockMesh.failed=false
end
assert(RockMesh.live==live0,'every piece freed its mesh: '..RockMesh.live)
print('PASS DigCubeView pieces: one mesh per piece, held until its op, beam ripple and crack pops, slam/pulse/dart/charge pops, Halver halves, Singularity squeeze, Frostbite ice, meshes freed, wedge fallback (doubles; looks and real cost NOT verified)')
'''

view = module_bundle(('DigCubeView',)).replace('--!strict\n', '')
# Expose the embedded modules to the test.
view = view.replace("V.ROLE_FX=ROLE_FX", "V.ROLE_FX=ROLE_FX\nV.RockMesh=RockMesh\nV.DigCube=DigCube", 1)
source = "\n".join([doubles, view, ";(function()\n" + checks + "\nend)()"])
with tempfile.TemporaryDirectory(prefix="rock-mesh-") as directory:
    path = Path(directory) / "checks.lua"
    path.write_text(source)
    subprocess.run([str(luau), str(path)], check=True)
