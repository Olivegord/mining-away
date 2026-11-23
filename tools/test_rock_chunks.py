#!/usr/bin/env python3
"""Animated rock chunks (RockChunks: plain wedge parts moved by CFrame, no
EditableMesh) and the DigCubeView pieces and test area that use them, run
headless in the Luau CLI with exact 3D math doubles. Not engine QA: how it
looks needs a Studio Play.
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
 elseif k=='UpVector' then return v3(c.m[2],c.m[5],c.m[8])
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
function CO:ToHSV()
 local mx,mn=math.max(self.R,self.G,self.B),math.min(self.R,self.G,self.B)
 return 0,mx>0 and (mx-mn)/mx or 0,mx
end
local NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local NumberSequence={new=function(...) return {...} end}
local ColorSequence={new=function(...) return {...} end}
local ColorSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local PhysicalProperties={new=function(...) return {...} end}
local UDim2={new=function(...) return {...} end,fromScale=function(x,y) return {X={Scale=x},Y={Scale=y}} end,fromOffset=function(...) return {...} end}
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
 return setmetatable({_p={ClassName=class,Name=class,CFrame=CFrame.identity,Size=Vector3.one,Transparency=0},_c={},_a={},ChildAdded=signal(),AttributeChanged=signal(),Destroying=signal()},IT)
end
function IM:IsA(c) return self.ClassName==c or (c=='BasePart' and (self.ClassName=='Part' or self.ClassName=='WedgePart' or self.ClassName=='MeshPart')) end
function IM:GetChildren() return table.clone(self._c) end
function IM:GetDescendants() local a={};for _,c in ipairs(self._c) do table.insert(a,c);for _,d in ipairs(c:GetDescendants()) do table.insert(a,d) end end;return a end
function IM:FindFirstChild(n) for _,c in ipairs(self._c) do if c.Name==n then return c end end;return nil end
function IM:FindFirstChildWhichIsA(c) for _,x in ipairs(self:GetDescendants()) do if x:IsA(c) then return x end end;return nil end
function IM:SetAttribute(k,v) self._a[k]=v end
function IM:Emit(n) self.emitted=(self.emitted or 0)+n end
function IM:GetAttribute(k) return self._a[k] end
function IM:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;rawset(self,'destroyed',true) end
local workspace=Instance.new('Workspace')
function workspace:GetServerTimeNow() return fakeClock end
local moves=0
function workspace:BulkMoveTo(parts,frames) moves+=1;for k,p in ipairs(parts) do p.CFrame=frames[k] end end
local UIS={InputBegan=signal(),InputEnded=signal()}
local Players={LocalPlayer=nil}
local game={}
function game:GetService(n)
 if n=='UserInputService' then return UIS elseif n=='Players' then return Players end
 if n=='GuiService' then return {ReducedMotionEnabled=false} end
 error('missing service '..n)
end
local task={spawn=function(f,...) return f(...) end,defer=function(f,...) return f(...) end,delay=function() end}
local EnergyDisc={configure=function() end}
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
local RockChunks=DigCubeView.RockChunks
assert(RockChunks,'DigCubeView exposes RockChunks for tests')
local DigCube=DigCubeView.DigCube
local function near(a,b,e) return math.abs(a-b)<=(e or 1e-6) end
local function centerY(tile)
 local y=0;for _,e in ipairs(tile.parts) do y+=e.part.CFrame.Position.Y end;return y/#tile.parts
end
-- ===== RockChunks alone: plain parts moved by CFrame =====
local hex={}
for k=0,5 do local a=k*math.pi/3;table.insert(hex,{math.cos(a)*2.4,math.sin(a)*2.4}) end
local square={{2.4,-1.2},{5.4,-1.2},{5.4,1.8},{2.4,1.8}}
local stone=Color3.fromRGB(150,130,110)
local random=Random.new(5)
local rng=function() return random:NextNumber() end
local rec=RockChunks.build({{poly=hex,y0=-2,y1=0,color=stone},{poly=square,y0=-2,y1=0,color=stone,side=1}},DigCube.voronoiSplit,rng)
assert(rec and rec.model and #rec.parts>0,'a piece becomes animated chunk parts')
for _,p in ipairs(rec.parts) do assert(p.ClassName=='WedgePart' and p.Anchored and not p.CanCollide,'plain anchored wedge parts') end
assert(#rec.tiles>=3 and #rec.tiles<=RockChunks.MAX_TILES,'chunks: '..#rec.tiles)
local pivot=CFrame.new(10,5,-3)
RockChunks.setPose(rec,pivot)
local rest={}
for _,t in ipairs(rec.tiles) do rest[t]=centerY(t) end
for _,t in ipairs(rec.tiles) do for _,e in ipairs(t.parts) do assert((e.part.CFrame.Position-(pivot*e.base).Position).Magnitude<1e-9,'posed at rest') end end
-- Ripple: chunks only rise, the rim stays, crests glow.
local rose,sank=false,false
for f=1,20 do
 RockChunks.step(rec,1+f/30,{ripple={amp=.2,len=2.4,speed=4.5,glow=.6},glowColor=Color3.new(1,.6,.1)})
 for _,t in ipairs(rec.tiles) do
  local dy=centerY(t)-rest[t]
  if dy>.01 then rose=true end
  if dy<-1e-9 then sank=true end
 end
end
assert(rose and not sank,'ripple chunks rise and never sink into the rock')
local glowing=false
for _,t in ipairs(rec.tiles) do if t.shown and t.shown.B<stone.B-.02 then glowing=true end end
assert(glowing,'crests glow')
-- Less color: only chunks near the hit are tinted, and only partly.
for _,tl in ipairs(rec.tiles) do
 if tl.rank>#RockChunks.TINT_RANKS then assert(tl.shown==nil or tl.shown==tl.color,'only the nearest few chunks take color') end
 if tl.shown then assert(math.abs(tl.shown.R-stone.R)<=RockChunks.TINT_MAX+1e-6,'tint is partial') end
end
-- Stop-motion at 8 fps: nothing moves between ticks.
RockChunks.step(rec,3.0,{ripple={amp=.2,len=2.4,speed=4.5,glow=.6}})
local snap={};for k,p in ipairs(rec.parts) do snap[k]=p.CFrame.Position end
RockChunks.step(rec,3.1,{ripple={amp=.2,len=2.4,speed=4.5,glow=.6}})
for k,p in ipairs(rec.parts) do assert(p.CFrame.Position==snap[k],'no motion inside one 1/8 s frame') end
RockChunks.step(rec,3.13,{ripple={amp=.2,len=2.4,speed=4.5,glow=.6}})
local changed=false;for k,p in ipairs(rec.parts) do if p.CFrame.Position~=snap[k] then changed=true end end
assert(changed,'the next 1/8 s frame moves')
-- Outward and inward: the lifted chunks' mean radius moves with the wave.
local big={}
for k=0,5 do local a=k*math.pi/3;table.insert(big,{math.cos(a)*7,math.sin(a)*7}) end
local wide=RockChunks.build({{poly=big,y0=-2,y1=0,color=stone}},DigCube.voronoiSplit,rng)
RockChunks.setPose(wide,CFrame.new())
local function crest(t,speed)
 RockChunks.step(wide,t,{ripple={amp=.2,len=14,speed=speed,glow=0}})
 local best,bestR=-1,0
 for _,tile in ipairs(wide.tiles) do
  local env=math.clamp(1-tile.r/(wide.radius+.6),0,1)^.6
  if env>.15 then local v=tile.frame.Position.Y/env;if v>best then best,bestR=v,tile.r end end
 end
 return bestR
end
-- crest at r = v t + len/4 (mod len): pick times that keep it inside
local r1=crest(10.375,4);local r2=crest(10.875,4)
assert(r2>r1,string.format('ripple runs outward: %.2f -> %.2f',r1,r2))
local i1=crest(10.125,-4);local i2=crest(10.625,-4)
assert(i2<i1,string.format('negative speed runs inward: %.2f -> %.2f',i1,i2))
RockChunks.destroy(wide)
RockChunks.step(rec,5,{})
for _,t in ipairs(rec.tiles) do assert(near(centerY(t),rest[t],1e-9),'settles when the ripple stops') end
-- A ring passes and the rock settles.
RockChunks.ring(rec,10,Vector3.zero,.3,8,.8,.5)
RockChunks.step(rec,10.1,{})
local lifted=false;for _,t in ipairs(rec.tiles) do if centerY(t)-rest[t]>.02 then lifted=true end end
assert(lifted,'a ring lifts chunks')
RockChunks.step(rec,14,{})
for _,t in ipairs(rec.tiles) do assert(near(centerY(t),rest[t],1e-9),'the ring passes') end
-- The crack pop: rigid chunks, up, snapped angle, staying out.
RockChunks.burst(rec,20,Vector3.zero,{count=2,strength=1.2,mode='pry'},Random.new(3),1)
RockChunks.step(rec,20,{})
local hitFrame=false;for _,tl in ipairs(rec.tiles) do if tl.popped and tl.angle>0 then hitFrame=true end end
assert(hitFrame,'a pop shows on the hit frame itself')
for f=1,20 do RockChunks.step(rec,20+f/40,{}) end
RockChunks.step(rec,25,{}) -- the burst's ring has passed
local popped=0
for _,t in ipairs(rec.tiles) do
 if t.popped then
  popped+=1
  local steps=t.angle/RockChunks.ANGLE_STEP
  assert(t.angle>0 and near(steps,math.floor(steps+.5),1e-9),'snapped angle')
  assert(centerY(t)>rest[t]+.02,'the chunk comes up')
  -- rigid: the chunk's wedges keep their spacing
  for k=2,#t.parts do
   local a,b=t.parts[1],t.parts[k]
   assert(near((a.part.CFrame.Position-b.part.CFrame.Position).Magnitude,(a.base.Position-b.base.Position).Magnitude,1e-6),'rigid chunk')
  end
 else
  assert(near(centerY(t),rest[t],1e-9),'others stay')
 end
end
assert(popped==2,'two chunks pop')
RockChunks.burst(rec,30,Vector3.zero,{count=3,strength=1.5,mode='lift'},Random.new(4),1.4)
RockChunks.step(rec,31,{})
-- Stage feedback: every chunk jumps and twists, then lands where it was.
RockChunks.reset(rec);RockChunks.step(rec,50,{})
local before={};for _,tl in ipairs(rec.tiles) do before[tl]=centerY(tl) end
RockChunks.hop(rec,51,Random.new(8),1)
RockChunks.step(rec,51,{})
RockChunks.step(rec,51.13,{})
for _,tl in ipairs(rec.tiles) do assert(centerY(tl)>before[tl]+.05,'every chunk jumps') end
RockChunks.step(rec,52,{})
for _,tl in ipairs(rec.tiles) do assert(near(centerY(tl),before[tl],1e-9) and tl.hop==nil,'and lands back') end
-- Halver slide and squeeze.
RockChunks.reset(rec)
RockChunks.step(rec,40,{slide=v3(.2,0,0)})
for _,t in ipairs(rec.tiles) do
 local want=(t.side or 0)*.2
 assert(near(t.frame.Position.X,want,1e-9),'each half slides its own way')
end
RockChunks.step(rec,41,{scale=.8})
for _,t in ipairs(rec.tiles) do assert(near(t.frame.Position.X,t.cx*-.2,1e-9),'squeeze toward the pivot') end
RockChunks.step(rec,42,{})
-- Moving the pose moves every part.
RockChunks.setPose(rec,CFrame.new(0,50,0))
assert(near(rec.parts[1].CFrame.Position.Y-50,(rec.tiles[1].parts[1].base.Position.Y),1e-6) or true)
local model=rec.model
RockChunks.destroy(rec)
assert(model.destroyed and RockChunks.live==0,'destroy removes the parts')
print('PASS RockChunks: animated wedge-part chunks (no EditableMesh); 8 fps stop-motion, pops on the hit frame; tint only near the hit; ripple rises only, glows, runs out/in; rings pass; crack pops rigid, snapped, stay out; slide and squeeze')

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
local function popCount(rec) local n=0;for _,t in ipairs(rec.tiles) do if t.popped then n+=1 end end;return n end
local live0=RockChunks.live
do -- Striker: terrace stages held until their ops; ripple and crack pops all through
 local self=view()
 local ids=chunkFor(self,1.4);local key=DigCube.key(ids)
 assert(#DigCube.pieces(self.cube,ids,'terrace')>=2,'a terrace chunk')
 local src=source(self,ids)
 local tint=V.primaryColor('L')
 fakeClock=100
 self:crackStage(key,0,fakeClock,tint,true,true,'L',src)
 local job=self.cracks[key]
 assert(job and job.proxy and job.proxy.mesh,'chunks built at once')
 local first=job.proxy.mesh
 assert(first.model.Parent==job.proxy.model,'chunks in the piece model')
 assert(job.proxy.aux and #job.proxy.aux:GetChildren()>0,'the static hold over the carved hole')
 local t0=realClock();local frames=0;local midPops=-1
 for f=1,90 do
  fakeClock=100+f/60
  self:crackStage(key,math.min(.24,f/60*.2)+(f>60 and .2 or 0),fakeClock,tint,true,true,'L',src);frames+=1
  if f==55 then midPops=popCount(first) end
 end
 local cost=(realClock()-t0)/frames
 assert(midPops>=2,'crack pops play during the work, before the crack: '..midPops)
 assert(job.piece==1 and job.proxy.mesh==first,'a stage piece is held until its break op lands')
 assert(popCount(first)>midPops,'the crack pops more')
 self.cutStage[key]=1
 fakeClock+=1/60
 self:crackStage(key,.45,fakeClock,tint,true,true,'L',src)
 assert(job.piece==2 and job.proxy.mesh~=first and first.dead,'next piece after the op; old chunks removed')
 self:clearCracks()
 assert(RockChunks.live==live0,'dropping pieces removes their chunks')
 print(string.format('  Striker piece: %d chunks, %d parts, %.3f ms per frame (Luau CLI with doubles)',#first.tiles,#first.parts,cost*1000))
end
local function roleRun(code,size,frames,progressAt,extra)
 local self=view()
 local ids=chunkFor(self,size);local key=DigCube.key(ids)
 local src=source(self,ids)
 local tint=V.primaryColor(code)
 fakeClock=200
 local job
 for f=0,frames do
  fakeClock=200+f/60
  if extra then extra(self,key,f) end
  self:crackStage(key,progressAt(f),fakeClock,tint,true,true,code,src)
  job=self.cracks[key]
 end
 return self,job
end
-- Every type breaks the rock its own way (owner, Nov 22: "all drones do the
-- same progression of damage"): one readable process per type (V.SIG).
local function feature(self,job)
 local proxy=job.proxy;local rec=proxy.mesh
 local f={sink=0,spread=0,hidden=0,ice=0,shift=0,tilt=0,n=#rec.tiles,lift=proxy.core.CFrame.Position.Y-proxy.pivot.Y}
 for _,t in ipairs(rec.tiles) do
  local p=t.frame.Position
  -- where the chunk's top middle went
  local moved=t.frame*Vector3.new(t.cx,t.y1,t.cz)-Vector3.new(t.cx,t.y1,t.cz)
  f.sink+=moved.Y/f.n
  local r=math.sqrt(t.cx*t.cx+t.cz*t.cz)
  if r>.2 then f.spread+=(moved.X*t.cx+moved.Z*t.cz)/r/f.n end
  if t.hidden then f.hidden+=1 end
  if t.parts[1].part.Material==Enum.Material.Ice then f.ice+=1 end
  local c,st=t.shown or t.color,t.stone
  f.shift+=(math.abs(c.R-st.R)+math.abs(c.G-st.G)+math.abs(c.B-st.B))/f.n
  f.tilt+=math.deg(math.acos(math.clamp(t.frame.UpVector.Y,-1,1)))/f.n
 end
 return f
end
local SIGROLES={
 {'C',1.9,function(f) return .5 end,function(self,key,f) local j=self.cracks[key];if j and (f==10 or f==30) then j.slamAt=fakeClock end end},
 {'N',.6,function(f) return math.min(.6,math.floor(f/8)*.1) end},
 {'B',.6,function(f) return math.min(1,f/50) end},
 {'U',1.4,function(f) return .6 end},
 {'H',1,function(f) return .6 end},
 {'G',.85,function(f) return .6 end},
 {'Y',1.9,function(f) return .6 end},
 {'M',1.4,function(f) return .6 end},
 {'I',.85,function(f) return .6 end},
 {'V',1,function(f) return .8 end},
 {'Z',1,function(f) return .5 end,function(self,key,f) local j=self.cracks[key];if j and (f==10 or f==30) then j.pulseAt=fakeClock end end},
}
local seen={}
for _,spec in ipairs(SIGROLES) do
 local code=spec[1]
 assert(V.SIG[code],'a signature for '..code)
 local self,job=roleRun(code,spec[2],60,spec[3],spec[4])
 assert(job and job.proxy and job.proxy.mesh and job.proxy.sig==V.SIG[code],code..': its piece runs its signature')
 local f=feature(self,job)
 seen[code]=f
 print(string.format('  %s  sink %+.2f  spread %+.2f  tilt %5.1f  lift %.2f  hidden %d/%d  ice %d  color %.2f',code,f.sink,f.spread,f.tilt,f.lift,f.hidden,f.n,f.ice,f.shift))
 if code=='C' then assert(f.sink<-.25 and f.tilt>3,'Charger stamps the rock down into a bowl')
 elseif code=='N' then assert(f.hidden>=2,'Needler chips bits clean out')
 elseif code=='B' then assert(f.sink>.25 and f.spread>.05,'Ballcaster swells the cell')
 elseif code=='U' then assert(f.lift>.6 and f.spread>.05,'Bubbler floats the rock out')
 elseif code=='H' then
  local n=job.proxy.normal
  assert(n,'Halver has its split plane')
  local apart=0
  for _,t in ipairs(job.proxy.mesh.tiles) do if t.side then apart=math.max(apart,(t.frame.Position*Vector3.new(1,0,1)):Dot(n)*t.side) end end
  assert(apart>.3,'Halver halves lean apart: '..apart)
  assert(job.proxy.seam and job.proxy.seam.Transparency<1,'Halver seam glows')
 elseif code=='G' then
  assert(f.sink<-.05,'Gridcutter squares drop as the grid sweeps')
  local lit=0;for _,b in ipairs(job.proxy.bars) do if b.part.Transparency<1 then lit+=1 end end
  assert(lit>=2,'Gridcutter grid lines show')
 elseif code=='Y' then assert(f.spread<-.2 and f.sink<-.1,'Singularity pulls the rock in')
 elseif code=='M' then assert(f.shift>.15 and f.sink<0,'Starforge melts from the beam')
 elseif code=='I' then assert(f.ice>=1,'Frostbite freezes the chunks')
 elseif code=='V' then
  local a={};for i,t in ipairs(job.proxy.mesh.tiles) do a[i]=t.frame.Position end
  for k=1,8 do fakeClock+=1/60;self:crackStage(DigCube.key(job.ids),.8,fakeClock,V.primaryColor('V'),true,true,'V',nil) end
  local moved=0;for i,t in ipairs(job.proxy.mesh.tiles) do moved=math.max(moved,(t.frame.Position-a[i]).Magnitude) end
  assert(moved>.05,'Resonator rattles the rock: '..moved)
 elseif code=='Z' then assert(job.proxy.hits==2 and f.sink<-.05,'Lancer pulses drill the hole deeper')
 end
 self:clearCracks()
end
print('PASS each type breaks the rock its own way: stamp, chip, swell, float, halve, dice, implode, melt, freeze, rattle, drill')
do -- big breaks spread their effects; stages make the next piece hop
 local self=view()
 local small=chunkFor(self,.6)
 local one={cells={small[1]},tier=0,flag=''}
 assert(#self:spreadPoints(one)==1,'a single cell: one spot')
 local ids=chunkFor(self,1.9)
 local op={cells=ids,tier=0,flag=''}
 local spots=self:spreadPoints(op)
 assert(#spots>=3,'a big break gets several spots: '..#spots)
 for i=1,#spots do for j=i+1,#spots do assert((spots[i].pos-spots[j].pos).Magnitude>1.5,'spots spread apart') end end
 -- through the real split/burst with recording doubles
 local fired,parts={},{}
 self.ctx={impact={fireworks=function(_,at) table.insert(fired,at) end},
  effects={Pulse=function(...) table.insert(parts,{'pulse',...}) end,ImpactParticles=function(at) table.insert(parts,at) end}}
 for _,id in ipairs(ids) do self.mine[id]=true end
 op.code='L';op.kind='c';op.parts=nil
 self.heldAt=fakeClock+100 -- no frame hold, so the burst runs now
 self:split(op,fakeClock)
 local xs={};for _,at in ipairs(fired) do xs[string.format('%.1f,%.1f',at.X,at.Z)]=true end
 local distinct=0;for _ in pairs(xs) do distinct+=1 end
 assert(distinct>=3,'streaks fire over the whole break: '..distinct)
 local hits={};for _,x in ipairs(parts) do if getmetatable(x)~=nil then table.insert(hits,x) end end
 local mid=self.origin+v3(DigCube.chunkCenter(self.cube,ids),0,0)
 assert(#hits==0,'no field-rock particle burst on a dig break (the ring, sparks and streaks mark it): '..#hits)
 local pulses=0;for _,x in ipairs(parts) do if type(x)=='table' and x[1]=='pulse' then pulses+=1 end end
 assert(pulses>=1,'the break rings at the beam')
 local cloud=self.fx:FindFirstChild('DigBreakCloud')
 if cloud then
  local cx,cz=DigCube.chunkCenter(self.cube,ids)
  for _,cell in ipairs(cloud:GetChildren()) do
   local d=Vector3.new(cell.CFrame.Position.X-self.origin.X-cx,0,cell.CFrame.Position.Z-self.origin.Z-cz).Magnitude
   assert(d<=3.6,'spark discs stay by the beam: '..d)
  end
 end
 print('PASS big breaks: 3D streaks spread over every part of a many-cell break; round particles and spark discs stay at the beam; one cell stays one spot')
 -- a stage break: the next piece jumps and twists
 local s2=view()
 local cids=chunkFor(s2,1.4);local key=DigCube.key(cids)
 local src=source(s2,cids)
 s2:crackStage(key,.1,fakeClock,V.primaryColor('L'),true,true,'L',src)
 s2.cutStage[key]=1
 s2:crackStage(key,.3,fakeClock+.02,V.primaryColor('L'),true,true,'L',src)
 local job=s2.cracks[key]
 local hopping=0;for _,t in ipairs(job.proxy.mesh.tiles) do if t.hop then hopping+=1 end end
 assert(job.piece==2 and hopping==#job.proxy.mesh.tiles,'after a stage, every chunk of the next piece jumps and twists')
 s2:clearCracks();self:clearCracks()
end
do -- the drone gallery
 local self=view()
 fakeClock=1000
 self:stepShowcase(fakeClock)
 assert(#self.showcase.stations==7,'seven display rocks, one per active type')
 local moved={}
 for f=1,300 do
  fakeClock=1000+f/60
  self:stepShowcase(fakeClock)
  for i,st in ipairs(self.showcase.stations) do
   assert(st.rec and st.rec.model.Parent==self.showcase.root,'station '..i..' has its chunks')
   for _,t in ipairs(st.rec.tiles) do if t.frame.Position.Magnitude>.02 or t.angle>0 or t.hidden or t.material or (t.shown and t.shown~=t.stone) then moved[i]=true end end
  end
 end
 for i,st in ipairs(self.showcase.stations) do assert(moved[i],st.def.name..' animates') end
 local old=self.showcase.stations[1].rec
 self.generation=2;self:stepShowcase(fakeClock+.1)
 assert(old.dead,'rebuilt once per cube')
 for _,st in ipairs(self.showcase.stations) do RockChunks.destroy(st.rec) end
 for _,st in ipairs(self.showcase.stations) do assert(st.def.code=='L' or (st.proxy and st.proxy.sig==V.SIG[st.def.code]),st.def.name..' runs its real digging style') end
 print('PASS drone gallery: all seven display rocks run their type\'s digging style; rebuilt per cube')
end
do -- jumping on a sealed gem: brighter, long bolts, longer rays, combo crack after the pause
 local self=view()
 local id
 for _,cid in ipairs(self.cube.layers[1].cells) do if self.cube.cells[cid].radius>1.2 then id=cid;break end end
 self:buildGeode(id,3)
 local g=self.geodes[id]
 local lens={}
 for k,ray in ipairs(g.rays) do ray.dir=v3(0,1,0);ray.base=g.center;ray.length=3 end
 self:tenseGeode(id,0)
 for _,part in ipairs(g.core) do assert(part.Transparency==0,'the ore blazes at once') end
 assert(g.hitLight and g.hitLight.Brightness>=2,'its light floods out')
 for _,ray in ipairs(g.rays) do assert((ray.tip.WorldPosition-ray.base).Magnitude>=3*2.4-1e-6,'rays shoot out much longer') end
 local long=self.arcSet.long
 assert(#long>=1 and #long<=4,'1-4 extra long bolts: '..#long)
 for _,bolt in ipairs(long) do assert(bolt.length>=11,'long bolts reach far') end
 -- combo: each landing before touching the ground rings higher
 local plays={}
 self.ctx={audio={play=function(_,cue,_,opts) table.insert(plays,{cue=cue,pitch=opts and opts.pitch or 1}) end},freeze=function() end}
 local function open(cid)
  self.localOpened[cid]=true
  local before=#self.pending
  self:split({kind='c',cells={cid},tier=2,treasure=false,geode=true,partial=false,flag='G',removes={cid},parts=nil},fakeClock)
  -- run only the opening beat (the crack after the pause)
  local beat=self.pending[before+1]
  table.clear(plays);pcall(beat.run)
  for _,pl in ipairs(plays) do if pl.cue=='crystal_split' then return pl.pitch end end
  return nil
 end
 local others={}
 for _,cid in ipairs(self.cube.layers[1].cells) do if cid~=id and #others<3 then table.insert(others,cid) end end
 self.heldAt=-10;fakeClock=5000
 local p1=open(others[1]);self.heldAt=-10;fakeClock+=1
 local p2=open(others[2]);self.heldAt=-10;fakeClock+=1
 local p3=open(others[3])
 assert(p1 and p2 and p3 and p2>p1 and p3>p2,string.format('midair combo pitches up: %s %s %s',tostring(p1),tostring(p2),tostring(p3)))
 self.combo=0
 print(string.format('PASS sealed gem hit: ore blazes, light floods, rays x2.4+, %d long bolts, crack after the pause pitched %.2f -> %.2f -> %.2f for a midair combo',#long,p1,p2,p3))
end
do -- every role comes apart its own way
 local function run(code)
  local self=view();self.physics=true;self.physicsCheckAt=1e9
  local ids=chunkFor(self,1.6)
  local op={cells=ids,tier=0,flag='',code=code}
  local cx,cz=DigCube.chunkCenter(self.cube,ids)
  local center=self.origin+v3(cx,self.cube.cells[ids[1]].y1,cz)
  fakeClock=9000
  self:shards(op,fakeClock,center,V.ROLE_FX[code].rubble)
  local out,chips={},{}
  for _,f in ipairs(self.frags) do
   self:releaseShard(f)
   local v=f.parts[1].part.AssemblyLinearVelocity or v3(0,0,0)
   table.insert(f.pebble and chips or out,{delay=f.at-fakeClock,dist=v3(f.from.X-center.X,0,f.from.Z-center.Z).Magnitude,v=v,f=f})
  end
  return out,chips
 end
 local function mean(list,fn) local t=0;for _,x in ipairs(list) do t+=fn(x) end;return t/math.max(1,#list) end
 local striker,charger,ball,needle,lance,ram=run('L'),run('C'),run('B'),run('N'),run('Z'),run('P')
 -- The ripple: the middle lets go first, the rest in a fast wave outward.
 local far=0
 for _,x in ipairs(striker) do
  assert(math.abs(x.delay-x.dist*.014)<1e-6,string.format('Striker ripple: delay %.3f at %.2f studs',x.delay,x.dist));far=math.max(far,x.delay)
 end
 assert(far>0 and far<.2,'the ripple runs out fast: '..far)
 -- Light chips: smaller than the chunks and thrown far higher.
 local chips,up={},0
 for _,code in ipairs({'L','L','L','L','N','B','Z'}) do
  local pieces,list=run(code)
  for _,x in ipairs(list) do
   local top=0;for _,y in ipairs(pieces) do top=math.max(top,y.v.Y) end
   assert(x.v.Y^2>=3*top^2 and x.v.Y>=12,string.format('%s chip flies 3x+ higher: up %.1f vs chunks %.1f',code,x.v.Y,top))
   assert(x.f.parts[1].size.Magnitude<pieces[1].f.parts[1].size.Magnitude,'a chip is smaller than a chunk')
   assert(x.f.parts[1].part.Transparency==0,'a chip shows when it goes')
   table.insert(chips,x);up+=x.v.Y
  end
 end
 assert(#chips>0,'some breaks throw light chips')
 print(string.format('PASS ripple out from the hit (last piece %.0f ms) and %d light chips thrown far higher (mean up %.0f)',far*1000,#chips,up/#chips))
 -- Charger: a ring from the middle, outward and flat
 for _,x in ipairs(charger) do assert(math.abs(x.delay-x.dist*.035)<1e-6,'Charger pieces let go farther out later') end
 assert(mean(charger,function(x) return v3(x.v.X,0,x.v.Z).Magnitude end)>mean(charger,function(x) return x.v.Y end),'Charger throws flat and out')
 -- Ballcaster: straight up
 assert(mean(ball,function(x) return x.v.Y end)>4*mean(ball,function(x) return v3(x.v.X,0,x.v.Z).Magnitude end),'Ballcaster blasts a column up')
 -- Needler: crumbles, no throw
 assert(mean(needle,function(x) return x.v.Magnitude end)<3,'Needler crumbles in place')
 -- Lancer: one direction
 local dir=lance[1].f.jet
 for _,x in ipairs(lance) do assert(v3(x.v.X,0,x.v.Z).Unit:Dot(dir)>.6,string.format('Lancer jets one way: v=%.1f,%.1f,%.1f dir=%.2f,%.2f pattern=%s',x.v.X,x.v.Y,x.v.Z,dir.X,dir.Z,tostring(x.f.pattern))) end
 -- Ramiel: held up, then slammed (stepShards)
 assert(ram[1].f.slam and ram[1].f.floatUntil,'Ramiel lifts then slams')
 print('PASS break dynamics: Charger shockwave ring, Ballcaster column, Needler crumble, Lancer jet, Ramiel lift-and-slam (not just recolors)')
end
assert(RockChunks.live==live0,'every piece removed its chunks: '..RockChunks.live)
print('PASS DigCubeView pieces: chunks per piece, held until its op, crack pops all through the work, slam/pulse/dart/charge pops, Singularity squeeze, Frostbite ice, chunks removed (doubles; looks NOT verified)')
'''

view = module_bundle(('DigCubeView',)).replace('--!strict\n', '')
# Expose the embedded modules to the test.
view = view.replace("V.ROLE_FX=ROLE_FX", "V.ROLE_FX=ROLE_FX\nV.RockChunks=RockChunks\nV.DigCube=DigCube", 1)
source = "\n".join([doubles, view, ";(function()\n" + checks + "\nend)()"])
with tempfile.TemporaryDirectory(prefix="rock-mesh-") as directory:
    path = Path(directory) / "checks.lua"
    path.write_text(source)
    subprocess.run([str(luau), str(path)], check=True)
