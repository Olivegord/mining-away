--!strict
-- Client effects for the Dig Cube. The rock itself is solid server geometry
-- (blocks carved by each broken chunk's Voronoi cells, Roblox CSG), so this
-- view draws what happens on it:
--  * each drone's chunk is marked on the rock in that drone's color, pulsing
--    like a field rock under attack, as soon as the drone claims it
--  * cracks run around the chunk's outline as it is cut, then the split line
--  * beams with the field rocks' contact chips and ring pulses
--  * the break: the field rocks' own split halves, scaled to the chunk, jump
--    apart with chips and dust, hold (the gamble), then a gem bursts out or
--    the halves crumble
--  * the launch pad and tap-to-focus
-- The cube (built from the replicated seed) supplies chunk outlines.
local DigCube=require('./DigCube')
local UIS=game:GetService('UserInputService')
local Players=game:GetService('Players')
local V={}
V.__index=V
local BEAM_CORE=Color3.fromRGB(255,250,235)
local HOT=Color3.fromRGB(222,128,62)
local CRACK=Color3.fromRGB(34,26,22)
local STONE_LIGHT=Color3.fromRGB(188,177,164) -- RockFinish.StoneLight
local POP=.2
local GRAVITY=70
local TIER_NAMES={'AMBER!','RUBY!','QUARTZ!','VIOLET!','DIAMOND!'}

local function rgb(t: {number}) return Color3.fromRGB(t[1],t[2],t[3]) end
local function fxPart(parent: Instance,name: string,color: Color3,class: string?): BasePart
 local p=Instance.new((class or 'Part') :: any) :: BasePart
 p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.TopSurface=Enum.SurfaceType.Smooth
 p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end

function V.new(ctx: any)
 local self=setmetatable({ctx=ctx,beams={},cracks={},splits={},debris={},banners={},cube=nil,origin=Vector3.zero,
  generation=-1,applied=0,random=Random.new(),connections={},tapAt=0},V)
 local fx=Instance.new('Folder');fx.Name='DigCubeFX';fx.Parent=workspace
 self.fx=fx
 self:watch()
 table.insert(self.connections,ctx.world.ChildAdded:Connect(function(child) if child.Name=='DigCube' then self:watch() end end))
 table.insert(self.connections,UIS.InputBegan:Connect(function(input,processed) self:inputBegan(input,processed) end))
 table.insert(self.connections,UIS.InputEnded:Connect(function(input,processed) self:inputEnded(input,processed) end))
 return self
end

function V:watch()
 local holder=self.ctx.world:FindFirstChild('DigCube')
 if not holder or holder==self.holder then return end
 self.holder=holder
 table.insert(self.connections,holder.AttributeChanged:Connect(function(name)
  if name=='Generation' or name=='OpCount' or string.sub(name,1,3)=='Ops' then self:sync() end
 end))
 self:sync()
end

function V:reduced(): boolean
 return self.ctx.reduced~=nil and self.ctx.reduced()==true
end

function V:colorAt(y: number): Color3
 return rgb(DigCube.gradient(y,self.cube.height))
end

function V:buildPad()
 if self.pad then self.pad:Destroy() end
 local W=self.cube.width
 local at=self.origin+Vector3.new(-5,0,W*.5)
 local pad=Instance.new('Part');pad.Name='DigLaunchPad'
 pad.Shape=Enum.PartType.Cylinder;pad.Size=Vector3.new(.5,7,7)
 pad.CFrame=CFrame.new(at+Vector3.new(0,.25,0))*CFrame.Angles(0,0,math.rad(90))
 pad.Anchored=true;pad.CanCollide=false;pad.CanQuery=false;pad.CanTouch=false
 pad.Material=Enum.Material.Neon;pad.Color=Color3.fromRGB(255,176,72);pad.Transparency=.15
 pad.Parent=self.fx
 local emitter=Instance.new('ParticleEmitter')
 emitter.Texture='rbxasset://textures/particles/sparkles_main.dds'
 emitter.Color=ColorSequence.new(Color3.fromRGB(255,206,120))
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,0)})
 emitter.Lifetime=NumberRange.new(.8,1.3);emitter.Rate=14;emitter.Speed=NumberRange.new(9,14)
 emitter.EmissionDirection=Enum.NormalId.Right;emitter.SpreadAngle=Vector2.new(8,8);emitter.LightEmission=.6
 emitter.Parent=pad
 self.pad=pad;self.padAt=at
end

-- Operation n of the replicated list (64 per attribute), or nil if not here yet.
function V:opAt(n: number): string?
 local chunk=self.holder:GetAttribute('Ops'..(math.floor((n-1)/64)+1))
 if type(chunk)~='string' then return nil end
 local i=0
 local want=(n-1)%64+1
 for entry in string.gmatch(chunk,'[^;]+') do i+=1;if i==want then return entry end end
 return nil
end

function V:sync()
 local holder=self.holder
 if not holder then return end
 local seed=holder:GetAttribute('Seed');local generation=holder:GetAttribute('Generation') or 0
 local origin=holder:GetAttribute('Origin')
 if type(seed)~='number' or typeof(origin)~='Vector3' then return end
 local count=holder:GetAttribute('OpCount') or 0
 if generation~=self.generation then
  for id in pairs(self.cracks) do self:dropCrack(id) end
  self.generation=generation;self.origin=origin
  self.cube=DigCube.build(seed)
  -- Cuts made before this client saw the cube play no effects.
  self.applied=0
  while self.applied<count do
   local entry=self:opAt(self.applied+1)
   if not entry then break end
   self.applied+=1
   local key=string.match(entry,'^c([%d%.]+)')
   if key then for _,id in ipairs(DigCube.parseKey(key)) do DigCube.remove(self.cube,id) end end
  end
  self:buildPad()
  return
 end
 local now=os.clock()
 while self.applied<count do
  local s=self:opAt(self.applied+1)
  if not s then break end
  self.applied+=1
  local key,tier=string.match(s,'^c([%d%.]+)|?(%d*)$')
  if key then
   local op={kind='c',cells=DigCube.parseKey(key),tier=tonumber(tier) or 0}
   self:split(op,now)
   for _,id in ipairs(op.cells) do DigCube.remove(self.cube,id) end
  end
 end
end

-- The rock an op takes out, as a box: center, size and frame (world space).
function V:cutBox(op: any): (CFrame?,Vector3?)
 local o=self.origin
 if op.kind=='c' then
  local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,id in ipairs(op.cells) do
   local c=self.cube.cells[id]
   if c then lo=lo:Min(Vector3.new(c.minX,c.y0,c.minZ));hi=hi:Max(Vector3.new(c.maxX,c.y1,c.maxZ)) end
  end
  if lo.X==math.huge then return nil end
  return CFrame.new(o+(lo+hi)*.5),hi-lo
 elseif op.kind=='s' then
  local top=op.y+op.r*.35
  local depth=top-(op.y-op.r)
  return CFrame.new(o+Vector3.new(op.x,top-depth*.5,op.z)),Vector3.new(op.r*1.7,depth,op.r*1.7)
 elseif op.kind=='y' then
  local top=op.y+op.h*.5-.5
  local depth=math.max(.5,top-(op.y-op.h*.5))
  return CFrame.new(o+Vector3.new(op.x,top-depth*.5,op.z)),Vector3.new(op.r*2,depth,op.r*2)
 else
  local top=op.y+op.sy*.5-.5
  local depth=math.max(.5,top-(op.y-op.sy*.5))
  return CFrame.fromMatrix(o+Vector3.new(op.x,top-depth*.5,op.z),Vector3.new(math.cos(op.yaw),0,math.sin(op.yaw)),Vector3.yAxis),Vector3.new(op.sx,depth,op.sz)
 end
end

-- The field rocks' split halves (CrystalFractures template), scaled to the cut.
function V:halves(frame: CFrame,size: Vector3,color: Color3)
 local template=self.ctx.fractures and (self.ctx.fractures('Original') or nil)
 local left=template and template:FindFirstChild('Left')
 local right=template and template:FindFirstChild('Right')
 local out={}
 local foot=Vector3.yAxis*((template and template:GetAttribute('HingeY') or -.5)*size.Y)
 local hinge=frame*CFrame.new(foot)
 for index=1,2 do
  local original=index==1 and left or right
  local half: BasePart
  local center: Vector3
  if original and original:IsA('BasePart') then
   half=original:Clone()
   for _,child in ipairs(half:GetChildren()) do child:Destroy() end
   local sizeRatio=original:GetAttribute('SizeRatio');local centerRatio=original:GetAttribute('CenterRatio')
   half.Size=typeof(sizeRatio)=='Vector3' and sizeRatio*size or size*Vector3.new(.5,1,1)
   center=typeof(centerRatio)=='Vector3' and centerRatio*size or Vector3.new((index==1 and -.25 or .25)*size.X,0,0)
  else
   half=Instance.new('Part');half.Size=size*Vector3.new(.5,1,1)
   center=Vector3.new((index==1 and -.25 or .25)*size.X,0,0)
  end
  half.Name='DigHalf';half.Anchored=true;half.CanCollide=false;half.CanQuery=false;half.CanTouch=false
  half.Material=Enum.Material.SmoothPlastic;half.Color=color;half.CastShadow=true;half.Transparency=0
  half.CFrame=frame*CFrame.new(center);half.Parent=self.fx
  table.insert(out,{part=half,side=index==1 and -1 or 1,offset=center-foot,size=half.Size})
 end
 return out,hinge
end

-- Small rock chips that fly, tumble, land, bounce once and fade.
function V:chips(at: Vector3,color: Color3,count: number,speed: number,floor: number,now: number)
 if self:reduced() then return end
 for i=1,count do
  if #self.debris>=90 then break end
  local s=self.random:NextNumber(.35,.8)
  local chip=fxPart(self.fx,'DigChip',color:Lerp(STONE_LIGHT,self.random:NextNumber(0,.2)),'WedgePart')
  chip.Size=Vector3.new(s*.7,s,s*1.2);chip.CastShadow=true
  local a=i*2.399963+self.random:NextNumber(0,.6)
  local v=Vector3.new(math.cos(a),0,math.sin(a))*speed*self.random:NextNumber(.5,1)+Vector3.yAxis*self.random:NextNumber(12,20)
  local axis=Vector3.new(self.random:NextNumber(-1,1),self.random:NextNumber(-1,1),self.random:NextNumber(-1,1))
  table.insert(self.debris,{part=chip,at=now,from=at,v=v,axis=axis.Magnitude>.05 and axis.Unit or Vector3.xAxis,
   spin=self.random:NextNumber(6,12),floor=floor+s*.5,life=self.random:NextNumber(1,1.4),size=chip.Size})
 end
end

function V:stepDebris(now: number)
 for i=#self.debris,1,-1 do
  local d=self.debris[i];local t=now-d.at
  if t>=d.life then d.part:Destroy();table.remove(self.debris,i)
  else
   local pos=d.from+d.v*t-Vector3.yAxis*(GRAVITY*.5*t*t)
   if pos.Y<=d.floor then
    if not d.landed then
     d.landed=t;d.landAt=Vector3.new(pos.X,d.floor,pos.Z);d.bounce=math.min(8,math.abs(d.v.Y-GRAVITY*t)*.25)
    end
    local age=t-d.landed
    pos=d.landAt+Vector3.new(d.v.X*.08*age,math.max(0,d.bounce*age-GRAVITY*.5*age*age),d.v.Z*.08*age)
   end
   local spin=d.spin*(d.landed or t)
   local fade=math.clamp((t/d.life-.6)/.4,0,1)
   d.part.Size=d.size*(1-.6*fade)
   d.part.CFrame=CFrame.new(pos)*CFrame.fromAxisAngle(d.axis,spin)
   d.part.Transparency=fade
  end
 end
end

-- The break: the field rocks' halves at the cut jump apart, hold while the
-- gem rolls, then burst (gem) or crumble (nothing). Calm: no glow or flash.
function V:split(op: any,now: number)
 local frame,size=self:cutBox(op)
 if not frame or not size then return end
 local center=frame.Position
 local color=self:colorAt(center.Y-self.origin.Y)
 -- Turn the halves to the op's split plane so each cut opens its own way.
 local yaw=((op.cells and op.cells[1] or 1)*.6180339887)%1*math.pi*2
 local turned=CFrame.new(center)*CFrame.Angles(0,-yaw,0)
 local edge=math.max(size.X,size.Z)
 local halves,hinge=self:halves(turned,Vector3.new(edge,size.Y,math.min(size.X,size.Z)),color)
 local floor=center.Y-size.Y*.5
 local bulk=(size.X*size.Y*size.Z)^(1/3)
 table.insert(self.splits,{at=now,tier=op.tier or 0,hinge=hinge,halves=halves,color=color,center=center,floor=floor,size=bulk,revealed=false})
 local ctx=self.ctx
 if ctx.audio then ctx.audio:play('crystal_split',center,{rockSize=bulk}) end
 self:chips(center+Vector3.yAxis*size.Y*.4,color,8+math.min(8,math.floor(bulk)),7,floor,now)
 if not self:reduced() then
  local strength=math.clamp(bulk/5,1,2.2)
  local serverNow=workspace:GetServerTimeNow()
  if ctx.effects then
   ctx.effects.ImpactParticles(center,color,strength*.8,'CrystalBreak',nil,color)
   ctx.effects.Pulse(Vector3.new(center.X,floor+.09,center.Z),color:Lerp(STONE_LIGHT,.36),strength*.5,strength*5.5,.5)
  end
  if ctx.impact then ctx.impact:fireworks(center,floor,color:Lerp(STONE_LIGHT,.3),strength,serverNow,4) end
  if ctx.beat then ctx.beat('Split',center,serverNow,math.clamp(bulk/9,.5,1.1)) end
 end
end

function V:reveal(e: any,now: number)
 e.revealed=true
 local ctx=self.ctx
 if e.tier>0 then
  local color=rgb(DigCube.ORES[e.tier].color)
  if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1+e.tier*.08,level=1}) end
  self:chips(e.center,e.color,10,10,e.floor,now)
  if not self:reduced() then
   if ctx.effects then
    ctx.effects.ImpactParticles(e.center,color,1+e.tier*.2,'GemReward')
    ctx.effects.Pulse(e.center,color,.5,3+e.tier*1.6,.45)
   end
   if ctx.impact then ctx.impact:fireworks(e.center,e.floor,color,1.2+e.tier*.15,workspace:GetServerTimeNow(),6) end
   if ctx.beat then ctx.beat(e.tier>=3 and 'HeavySplit' or 'Split',e.center,workspace:GetServerTimeNow(),math.min(1.2,.6+e.tier*.12)) end
  end
  self:banner(e.center+Vector3.yAxis*e.size*.5,TIER_NAMES[e.tier] or 'GEM!',color)
 else
  if ctx.audio then ctx.audio:play('crystal_fall_tink',e.center,{pitch=.8,level=.7}) end
  self:chips(e.center,e.color,6,4,e.floor,now)
  if not self:reduced() and ctx.effects then
   ctx.effects.ImpactParticles(e.center,e.color,.9,'CrystalBreak',nil,e.color,nil,.3)
  end
 end
end

function V:banner(at: Vector3,text: string,color: Color3)
 local anchor=fxPart(self.fx,'DigReveal',color);anchor.Transparency=1;anchor.Size=Vector3.one*.1;anchor.Position=at+Vector3.yAxis*2
 local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromOffset(220,64);gui.AlwaysOnTop=true;gui.LightInfluence=0
 gui.MaxDistance=140;gui.Adornee=anchor;gui.Parent=anchor
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
 label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.Text=text;label.TextColor3=color
 label.TextStrokeTransparency=0;label.TextStrokeColor3=Color3.fromRGB(20,16,30);label.Parent=gui
 local scale=Instance.new('UIScale');scale.Scale=.2;scale.Parent=gui
 table.insert(self.banners,{anchor=anchor,label=label,scale=scale,at=os.clock(),from=anchor.Position})
end

function V:stepSplits(now: number)
 local pause=DigCube.PAUSE
 local reduced=self:reduced()
 for i=#self.splits,1,-1 do
  local e=self.splits[i]
  local age=now-e.at
  if age>=pause and not e.revealed then self:reveal(e,now) end
  if age>=pause+.7 then
   for _,h in ipairs(e.halves) do h.part:Destroy() end
   table.remove(self.splits,i)
  else
   -- Same motion as a field rock's split: open around the shared lower seam.
   local pop=reduced and 1 or 1-(1-math.clamp(age/POP,0,1))^3
   local gap,lift,open=.5*pop,.5*pop,.35*pop
   local fade,shrink=0,1
   if age>=pause then
    local q=math.clamp((age-pause)/.6,0,1)
    if e.tier>0 then
     local fly=1-(1-q)^2
     gap+=2.5*fly;lift+=1.2*fly-3*q*q;open+=.7*fly
    else
     lift-=e.size*.6*q*q;open+=.15*q;shrink=1-.4*q
    end
    fade=math.clamp((q-.4)/.6,0,1)
   end
   for _,h in ipairs(e.halves) do
    local f=e.hinge*CFrame.new(h.side*gap,lift,0)*CFrame.Angles(0,0,-h.side*open)
    h.part.CFrame=f*CFrame.new(h.offset*shrink)
    h.part.Size=h.size*shrink
    h.part.Transparency=fade
   end
  end
 end
 for i=#self.banners,1,-1 do
  local b=self.banners[i];local t=now-b.at
  if t>=1.6 then b.anchor:Destroy();table.remove(self.banners,i)
  else
   b.scale.Scale=t<.18 and .2+1.1*(t/.18) or 1.3-.3*math.clamp((t-.18)/.15,0,1)
   b.anchor.Position=b.from+Vector3.yAxis*(t*1.4)
   local fade=math.clamp((t-1.1)/.5,0,1)
   b.label.TextTransparency=fade;b.label.TextStrokeTransparency=fade
  end
 end
end

-- A chunk's outline on the surface: its outer cell edges, ordered around it.
function V:outline(ids: {number}): ({any},number)
 local o=self.origin
 local edges=DigCube.outline(self.cube,ids)
 local y=o.Y+self.cube.cells[ids[1]].y1+.06
 local out={}
 for _,e in ipairs(edges) do table.insert(out,{a=Vector3.new(o.X+e.ax,y,o.Z+e.az),b=Vector3.new(o.X+e.bx,y,o.Z+e.bz),len=e.len}) end
 return out,y
end

-- A drone's chunk: marked in the drone's color as soon as it is claimed,
-- then cracks run around its outline as it is cut, then the split line.
function V:buildCrack(droneId: string,key: string,mine: boolean,color: Color3?)
 local ids=DigCube.parseKey(key)
 if #ids==0 or not self.cube then return nil end
 for _,id in ipairs(ids) do if not self.cube.cells[id] or self.cube.removed[id] then return nil end end
 local edges,y=self:outline(ids)
 local total=0
 for _,e in ipairs(edges) do e.start=total;total+=e.len end
 local sp=DigCube.split(self.cube,ids)
 local seams={}
 for _,c in ipairs(sp.chords) do
  table.insert(seams,{a=Vector3.new(self.origin.X+c.ax,y+.01,self.origin.Z+c.az),b=Vector3.new(self.origin.X+c.bx,y+.01,self.origin.Z+c.bz)})
 end
 local crack={key=key,ids=ids,edges=edges,total=math.max(.5,total),seams=seams,parts={},marks={},seamParts={},progress=0,seen=0,
  dustAt=0,since=os.clock(),mine=mine,color=color or HOT}
 self.cracks[droneId]=crack
 return crack
end

function V:dropCrack(droneId: string)
 local crack=self.cracks[droneId]
 if not crack then return end
 for _,p in pairs(crack.parts) do p:Destroy() end
 for _,p in pairs(crack.marks) do p:Destroy() end
 for _,p in pairs(crack.seamParts) do p:Destroy() end
 self.cracks[droneId]=nil
end

function V:line(part: BasePart?,a: Vector3,b: Vector3,width: number,color: Color3,transparency: number): BasePart?
 local length=(b-a).Magnitude
 if length<.03 then if part then part.Transparency=1 end;return part end
 if not part then part=fxPart(self.fx,'DigCrack',color) end
 local p=part :: BasePart
 p.Size=Vector3.new(width,.06,length+width*.5)
 p.CFrame=CFrame.lookAt((a+b)*.5,b)
 p.Color=color;p.Transparency=transparency
 return p
end

function V:drawCrack(crack: any,now: number)
 local p=crack.progress
 -- The mark: the whole outline in the drone's color, pulsing like a field
 -- rock under attack (brighter for your own crew).
 local wave=.5+.5*math.cos((now-crack.since)*7.5)
 local markAlpha=crack.mine and .50-.43*wave or .7
 for i,e in ipairs(crack.edges) do
  crack.marks[i]=self:line(crack.marks[i],e.a+Vector3.yAxis*.01,e.b+Vector3.yAxis*.01,.16,crack.color:Lerp(Color3.new(1,1,1),.35),markAlpha)
 end
 -- Cracks run around the outline as the cut goes, darkening the mark.
 local heat=math.clamp((p-.74)/.26,0,1)
 local color=CRACK:Lerp(HOT,heat*.8)
 local width=.12+.1*p
 local reach=math.clamp((p-.02)/.7,0,1)*crack.total
 local tipAt
 for i,e in ipairs(crack.edges) do
  local r=math.clamp((reach-e.start)/e.len,0,1)
  if r<=0 then
   if crack.parts[i] then crack.parts[i].Transparency=1 end
  else
   local tip=e.a:Lerp(e.b,r)
   crack.parts[i]=self:line(crack.parts[i],e.a+Vector3.yAxis*.02,tip+Vector3.yAxis*.02,width,color,0)
   if r<1 then tipAt=tip end
  end
 end
 if tipAt and now>=crack.dustAt and not self:reduced() and self.ctx.presentation and self.ctx.presentation.work then
  crack.dustAt=now+.16
  self.ctx.presentation.work:burst(tipAt,Vector3.yAxis,self:colorAt(tipAt.Y-self.origin.Y):Lerp(STONE_LIGHT,.3),3,workspace:GetServerTimeNow())
 end
 local g=math.clamp((p-.7)/.22,0,1)
 for i,sm in ipairs(crack.seams) do
  if g>0 then
   local m=(sm.a+sm.b)*.5
   crack.seamParts[i]=self:line(crack.seamParts[i],m:Lerp(sm.a,g),m:Lerp(sm.b,g),width,color,0)
  elseif crack.seamParts[i] then crack.seamParts[i].Transparency=1 end
 end
end

-- One beam per digging drone, from its rendered emitter to its cut.
function V:droneBeam(source: Instance,from: Vector3,now: number,color: Color3?)
 local id=source:GetAttribute('DroneId')
 if type(id)~='string' or not self.cube then return end
 local key=source:GetAttribute('DigOp')
 if type(key)~='string' then key='' end
 local point=source:GetAttribute('DigPoint')
 local crack=self.cracks[id]
 if crack and 'c'..crack.key~=key then self:dropCrack(id);crack=nil end
 if not crack and key~='' and typeof(point)=='Vector3' then
  local player=Players.LocalPlayer
  crack=self:buildCrack(id,string.sub(key,2),player~=nil and source:GetAttribute('Owner')==player.UserId,color)
 end
 local progress=source:GetAttribute('DigProgress') or 0
 if crack then crack.progress=math.max(crack.progress,progress);crack.seen=now end
 local active=crack~=nil and source:GetAttribute('DigMining')==true and source:GetAttribute('WorkPaused')~=true
 local beam=self.beams[id]
 if not active or typeof(point)~='Vector3' then
  if beam then beam.core.Transparency=1;beam.glow.Transparency=1;beam.spot.Transparency=1 end
  return
 end
 if not beam then
  local function rod(name: string,c: Color3)
   local p=fxPart(self.fx,name,c);(p :: Part).Shape=Enum.PartType.Cylinder;p.Material=Enum.Material.Neon
   return p
  end
  beam={core=rod('DigBeamCore',BEAM_CORE),glow=rod('DigBeamGlow',color or HOT),spot=rod('DigBeamSpot',color or HOT)};
  (beam.spot :: Part).Shape=Enum.PartType.Ball
  self.beams[id]=beam
 end
 local to=point
 local length=(to-from).Magnitude
 if length<.1 then return end
 local mid=(from+to)*.5
 local frame=CFrame.lookAt(mid,to)*CFrame.Angles(0,math.rad(90),0)
 local pulse=.5+.5*math.sin(now*38)
 beam.core.Size=Vector3.new(length,.16+.04*pulse,.16+.04*pulse);beam.core.CFrame=frame;beam.core.Transparency=0
 beam.glow.Color=color or HOT
 beam.glow.Size=Vector3.new(length,.5+.12*pulse,.5+.12*pulse);beam.glow.CFrame=frame;beam.glow.Transparency=.55
 beam.spot.Color=(color or HOT):Lerp(BEAM_CORE,.4)
 local r=.8+.5*progress+.15*pulse
 beam.spot.Size=Vector3.new(r,r,r);beam.spot.CFrame=CFrame.new(to);beam.spot.Transparency=.3
 -- The field rocks' contact feedback: chips knocked off where the beam
 -- hits, and a small ring pulse on the surface.
 if now>=(beam.sparkAt or 0) then
  beam.sparkAt=now+.23+(now%.07)
  local serverNow=workspace:GetServerTimeNow()
  local tone=self:colorAt(to.Y-self.origin.Y)
  if self.ctx.impact then
   local surface=self.holder and self.holder:FindFirstChild('Rock') and self.holder.Rock:FindFirstChildWhichIsA('BasePart')
   if surface then self.ctx.impact:chips(serverNow,to,Vector3.yAxis,surface,1,to.Y-4) end
  end
  if self.ctx.effects and now>=(beam.pulseAt or 0) then
   beam.pulseAt=now+.4
   self.ctx.effects.Pulse(to+Vector3.yAxis*.1,tone:Lerp(STONE_LIGHT,.38),.19,1.65,.18,Vector3.yAxis,.78)
  end
 end
end

function V:stepCracks(now: number)
 for id,crack in pairs(self.cracks) do
  if now-crack.seen>.3 then self:dropCrack(id) else self:drawCrack(crack,now) end
 end
end

function V:stepPad(now: number)
 local pad=self.pad;if not pad or not self.cube then return end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 pad.Transparency=.15+.12*math.sin(now*4)
 if not root or not root:IsA('BasePart') or now<(self.launchedAt or 0)+1.2 then return end
 local offset=root.Position-self.padAt
 if Vector3.new(offset.X,0,offset.Z).Magnitude<3.6 and offset.Y<6 then
  self.launchedAt=now
  local rise=self.cube.height+8
  local up=math.sqrt(2*workspace.Gravity*rise)
  root.AssemblyLinearVelocity=Vector3.new(16,up,0)
  if self.ctx.audio then self.ctx.audio:play('crystal_split',root.Position,{rockSize=3}) end
 end
end

function V:inputBegan(input: InputObject,processed: boolean)
 if processed then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  self.pressAt=os.clock();self.pressPosition=Vector2.new(input.Position.X,input.Position.Y)
 end
end

function V:inputEnded(input: InputObject,processed: boolean)
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 local at,position=self.pressAt,self.pressPosition
 self.pressAt=nil
 if processed or not at or not position or os.clock()-at>.45 then return end
 if (Vector2.new(input.Position.X,input.Position.Y)-position).Magnitude>14 then return end
 if os.clock()<self.tapAt+.3 then return end
 local rock=self.holder and self.holder:FindFirstChild('Rock')
 local camera=workspace.CurrentCamera;if not camera or not rock then return end
 local ray=camera:ViewportPointToRay(position.X,position.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={rock}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*400,params)
 if not hit then return end
 self.tapAt=os.clock()
 self.ctx.command:FireServer('DigFocus',{point=hit.Position})
 if self.ctx.presentation and self.ctx.presentation.work then
  self.ctx.presentation.work:burst(hit.Position,hit.Normal,Color3.fromRGB(255,232,170),10,workspace:GetServerTimeNow())
 end
end

function V:update()
 local now=os.clock()
 self:stepCracks(now)
 self:stepSplits(now)
 self:stepDebris(now)
 self:stepPad(now)
end

function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for id in pairs(self.cracks) do self:dropCrack(id) end
 self.fx:Destroy()
end
return V
