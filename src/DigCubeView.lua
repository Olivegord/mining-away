--!strict
-- Client effects for the Dig Cube. The rock itself is solid server geometry
-- (blocks carved by each broken chunk's Voronoi cells, Roblox CSG), so this
-- view draws what happens on it:
--  * each drone's target is marked with a circle in that drone's color (the
--    chunk's real shape stays a surprise), pulsing while the drone claims it
--  * the crack: a closed loop that starts small at the beam's hit point and
--    grows, warping and gaining corners, until it matches the chunk's real
--    outline and cracks through
--  * beams with the field rocks' contact chips and ring pulses
--  * the break: chips and dust, a hold (the gamble), then a gem bursts out
--  * rock dust: glowing motes that settle on the pit floor and fly to their
--    owner when they come close (the server credits the rock then)
--  * a soft lamp on the player down in the pit, the launch pad and tap-to-focus
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
 local self=setmetatable({ctx=ctx,beams={},cracks={},splits={},debris={},banners={},dust={},motes=0,cube=nil,origin=Vector3.zero,
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
 local function watchDust(folder: Instance)
  for _,child in ipairs(folder:GetChildren()) do self:addDust(child,false) end
  table.insert(self.connections,folder.ChildAdded:Connect(function(child) self:addDust(child,true) end))
 end
 local folder=holder:FindFirstChild('Dust')
 if folder then watchDust(folder)
 else
  table.insert(self.connections,holder.ChildAdded:Connect(function(child) if child.Name=='Dust' then watchDust(child) end end))
 end
 table.insert(self.connections,holder.AttributeChanged:Connect(function(name)
  if name=='Generation' or name=='OpCount' or string.sub(name,1,3)=='Ops' then self:sync() end
 end))
 self:sync()
end

function V:reduced(): boolean
 return self.ctx.reduced~=nil and self.ctx.reduced()==true
end

function V:colorAt(y: number,x: number?,z: number?): Color3
 return rgb(DigCube.colorAt(self.cube,x or self.cube.width*.5,y,z or self.cube.width*.5))
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
  self:clearSparkles()
  return
 end
 local now=os.clock()
 while self.applied<count do
  local s=self:opAt(self.applied+1)
  if not s then break end
  self.applied+=1
  local key,tier,flag,depth=string.match(s,'^c([%d%.]+)|?(%d*)|?(%a?)(%d*)$')
  if key then
   local op={kind='c',cells=DigCube.parseKey(key),tier=tonumber(tier) or 0,treasure=flag=='T',layer=flag=='D' and tonumber(depth) or nil}
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

-- The break: chips and dust burst from the chunk, hold while the gem rolls,
-- then a gem bursts out (or a last puff of dust). No leftover rock pieces.
function V:split(op: any,now: number)
 local frame,size=self:cutBox(op)
 if not frame or not size then return end
 local center=frame.Position
 local color=self:colorAt(center.Y-self.origin.Y,center.X-self.origin.X,center.Z-self.origin.Z)
 local floor=center.Y-size.Y*.5
 local bulk=(size.X*size.Y*size.Z)^(1/3)
 table.insert(self.splits,{at=now,tier=op.tier or 0,treasure=op.treasure,layer=op.layer,color=color,center=center,floor=floor,size=bulk,revealed=false})
 local ctx=self.ctx
 if ctx.audio then
  ctx.audio:play('crystal_split',center,{rockSize=bulk})
  ctx.audio:play('crystal_release_tink',center,{level=.8})
 end
 self:chips(center+Vector3.yAxis*size.Y*.4,color,8+math.min(8,math.floor(bulk)),7,floor,now)
 if not self:reduced() then
  local strength=math.clamp(bulk/5,1,2.2)
  local serverNow=workspace:GetServerTimeNow()
  if ctx.effects then
   ctx.effects.ImpactParticles(center,color,strength*.8,'CrystalBreak',nil,color)
   ctx.effects.Pulse(Vector3.new(center.X,floor+.09,center.Z),color:Lerp(STONE_LIGHT,.36),strength*.5,strength*5.5,.5)
  end
  if ctx.impact then ctx.impact:fireworks(center,floor,color:Lerp(STONE_LIGHT,.3),strength,serverNow,4) end
  -- Bigger chunks hit harder.
  if ctx.beat then ctx.beat(bulk>6 and 'HeavySplit' or 'Split',center,serverNow,math.clamp(bulk/7,.55,1.35)) end
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
  if e.treasure then
   -- Jackpot: a treasure pocket pays several rare gems.
   self:banner(e.center+Vector3.yAxis*e.size*.5,'TREASURE!',Color3.fromRGB(255,214,90),1.5)
   if not self:reduced() and ctx.effects then
    for i=1,3 do task.delay(i*.12,function() ctx.effects.ImpactParticles(e.center+Vector3.yAxis*i*.5,rgb(DigCube.ORES[((e.tier+i-2)%#DigCube.ORES)+1].color),1.4,'GemReward') end) end
    ctx.effects.Pulse(e.center,Color3.fromRGB(255,214,90),.8,14,.6)
   end
   if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1.5,level=1}) end
   if ctx.beat then ctx.beat('HeavySplit',e.center,workspace:GetServerTimeNow(),1.4) end
  elseif e.layer then
   self:banner(e.center+Vector3.yAxis*e.size*.5,'LAYER '..e.layer..'! '..(TIER_NAMES[e.tier] or 'GEM!'),color,1.2)
  else
   self:banner(e.center+Vector3.yAxis*e.size*.5,TIER_NAMES[e.tier] or 'GEM!',color)
  end
 else
  if ctx.audio then ctx.audio:play('crystal_fall_tink',e.center,{pitch=.8,level=.7}) end
  self:chips(e.center,e.color,6,4,e.floor,now)
  if not self:reduced() and ctx.effects then
   ctx.effects.ImpactParticles(e.center,e.color,.9,'CrystalBreak',nil,e.color,nil,.3)
  end
 end
end

function V:banner(at: Vector3,text: string,color: Color3,big: number?)
 local anchor=fxPart(self.fx,'DigReveal',color);anchor.Transparency=1;anchor.Size=Vector3.one*.1;anchor.Position=at+Vector3.yAxis*2
 local k=big or 1
 local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromOffset(240*k,64*k);gui.AlwaysOnTop=true;gui.LightInfluence=0
 gui.MaxDistance=140;gui.Adornee=anchor;gui.Parent=anchor
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
 label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.Text=text;label.TextColor3=color
 label.TextStrokeTransparency=0;label.TextStrokeColor3=Color3.fromRGB(20,16,30);label.Parent=gui
 local scale=Instance.new('UIScale');scale.Scale=.2;scale.Parent=gui
 table.insert(self.banners,{anchor=anchor,label=label,scale=scale,at=os.clock(),from=anchor.Position})
end

function V:stepSplits(now: number)
 local pause=DigCube.PAUSE
 for i=#self.splits,1,-1 do
  local e=self.splits[i]
  local age=now-e.at
  if age>=pause and not e.revealed then self:reveal(e,now) end
  if age>=pause+.7 then table.remove(self.splits,i) end
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

-- A drone's target: a circle in the drone's color as soon as it is claimed,
-- so you cannot see which cells you are about to get. While it is cut, a
-- crack loop opens at the beam's hit point and grows outward: it starts as a
-- small warped diamond, gains corners as it spreads (each new point appears
-- on an edge and pushes out), and its warp settles until it lies exactly on
-- the chunk's real outline. Four snaps (CRACK_STAGES) along the way play a
-- crack sound with chips and dust and kick the warp; the last cracks the
-- real outline through and it opens with a dim ember glow inside.
local CRACK_STAGES={.12,.38,.62,.86}
local RUN_TIME=.16 -- seconds for the final crack to run around the outline
local CIRCLE_SEGMENTS=28
local function jitter(seed: number): number
 local x=math.sin(seed*12.9898)*43758.5453
 return (x-math.floor(x))*2-1
end
local function smoothstep(t: number): number
 t=math.clamp(t,0,1)
 return t*t*(3-2*t)
end
-- Distance from c along direction (dx,dz) to the nearest outline edge.
local function rayToOutline(edges: {any},c: Vector3,dx: number,dz: number): number?
 local best=nil
 for _,e in ipairs(edges) do
  local ax,az=e.a.X-c.X,e.a.Z-c.Z
  local ex,ez=e.b.X-e.a.X,e.b.Z-e.a.Z
  local den=dx*ez-dz*ex
  if math.abs(den)>1e-9 then
   local t=(ax*ez-az*ex)/den
   local u=(ax*dz-az*dx)/den
   if t>.05 and u>=-1e-6 and u<=1+1e-6 and (not best or t<best) then best=t end
  end
 end
 return best
end
function V:buildCrack(droneId: string,key: string,mine: boolean,color: Color3?,point: Vector3?)
 local ids=DigCube.parseKey(key)
 if #ids==0 or not self.cube then return nil end
 for _,id in ipairs(ids) do if not self.cube.cells[id] or self.cube.removed[id] then return nil end end
 local edges,y=self:outline(ids)
 local seed=0
 for _,id in ipairs(ids) do seed=(seed*31+id)%100003 end
 local area,cx,cz=DigCube.chunkArea(self.cube,ids)
 local middle=Vector3.new(self.origin.X+cx,y,self.origin.Z+cz)
 local center=point and Vector3.new(point.X,y,point.Z) or middle
 -- Loop points: fixed angles around the hit point, each knowing how far the
 -- real outline is in its direction.
 local perimeter=0
 for _,e in ipairs(edges) do perimeter+=e.len end
 local count=math.clamp(math.floor(perimeter/1.1+.5),14,40)
 local fallback=math.sqrt(area/math.pi)
 local pts={}
 for k=1,count do
  local angle=(k-1+.35*jitter(seed+k*3.1))/count*math.pi*2
  local dx,dz=math.cos(angle),math.sin(angle)
  local reach=rayToOutline(edges,center,dx,dz) or fallback
  pts[k]={dx=dx,dz=dz,reach=reach,warp=jitter(seed+k*7.3),drift=jitter(seed+k*1.7)*math.pi,t=0,anchor=false}
 end
 -- Order of appearance: four starting corners, then repeated bisection of
 -- the gaps, so the loop gains detail evenly all the way around.
 local order={}
 local active={}
 for q=0,3 do local k=math.floor(q*count/4)+1;if not active[k] then active[k]=true;table.insert(order,k) end end
 local changed=true
 while changed do
  changed=false
  local list=table.clone(order);table.sort(list)
  for i=1,#list do
   local a=list[i];local b=list[i%#list+1]
   local gap=(b-a)%count
   if gap>=2 then
    local k=(a-1+math.floor(gap/2))%count+1
    if not active[k] then active[k]=true;table.insert(order,k);changed=true end
   end
  end
 end
 for rank,k in ipairs(order) do
  if rank<=4 then pts[k].t=-1;pts[k].anchor=true
  else pts[k].t=.04+.7*(rank-4)/math.max(1,#order-4)+.03*jitter(seed+k) end
 end
 local radius=math.max(1.2,fallback*1.08)
 local crack={key=key,ids=ids,edges=edges,pts=pts,center=center,middle=middle,radius=radius,parts={},marks={},loop={},
  progress=0,shown=0,drawAt=os.clock(),seen=0,stage=0,stageAt={},since=os.clock(),mine=mine,color=color or HOT,y=y}
 self.cracks[droneId]=crack
 return crack
end

function V:dropCrack(droneId: string)
 local crack=self.cracks[droneId]
 if not crack then return end
 for _,p in pairs(crack.parts) do p:Destroy() end
 for _,p in pairs(crack.marks) do p:Destroy() end
 for _,p in pairs(crack.loop) do p:Destroy() end
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

-- One snap of the fracture: sound, chips and a little dust ring.
function V:crackSnap(crack: any,stage: number)
 local ctx=self.ctx
 local at=crack.center
 local tone=self:colorAt(at.Y-self.origin.Y,at.X-self.origin.X,at.Z-self.origin.Z)
 if ctx.audio then
  ctx.audio:play(stage>=4 and 'crystal_split' or 'crystal_impact',at,{pitch=.85+stage*.12,level=(crack.mine and .9 or .5)*(stage>=4 and .7 or 1),rockSize=2})
 end
 if self:reduced() then return end
 local serverNow=workspace:GetServerTimeNow()
 if ctx.impact then
  local rock=self.holder and self.holder:FindFirstChild('Rock')
  local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
  if surface then ctx.impact:chips(serverNow,at,Vector3.yAxis,surface,stage>=3 and 3 or 2,at.Y-.1) end
 end
 if ctx.effects then
  ctx.effects.Pulse(at+Vector3.yAxis*.08,tone:Lerp(STONE_LIGHT,.4),.25,1.2+stage*.7,.22,Vector3.yAxis,.8)
 end
 if ctx.presentation and ctx.presentation.work then
  ctx.presentation.work:burst(at,Vector3.yAxis,tone:Lerp(STONE_LIGHT,.3),2+stage,serverNow)
 end
end

function V:drawCrack(crack: any,now: number)
 local dt=math.min(.1,now-crack.drawAt);crack.drawAt=now
 -- Ease the shown progress toward the replicated one so growth is smooth.
 crack.shown+=(crack.progress-crack.shown)*math.min(1,dt*7)
 local p=crack.progress
 while crack.stage<#CRACK_STAGES and p>=CRACK_STAGES[crack.stage+1] do
  crack.stage+=1
  crack.stageAt[crack.stage]=now
  self:crackSnap(crack,crack.stage)
 end
 local through=crack.stage>=4
 local reduced=self:reduced()
 -- The target circle in the drone's color (brighter and pulsing for your
 -- own crew), until the chunk cracks through.
 local wave=.5+.5*math.cos((now-crack.since)*7.5)
 local markAlpha=through and 1 or (crack.mine and .5-.43*wave or .7)
 local markColor=crack.color:Lerp(Color3.new(1,1,1),.35)
 local ring=crack.radius*(1+(crack.mine and not reduced and .04*wave or 0))
 for i=1,CIRCLE_SEGMENTS do
  local a0=(i-1)/CIRCLE_SEGMENTS*math.pi*2;local a1=i/CIRCLE_SEGMENTS*math.pi*2
  local from=crack.middle+Vector3.new(math.cos(a0)*ring,.01,math.sin(a0)*ring)
  local to=crack.middle+Vector3.new(math.cos(a1)*ring,.01,math.sin(a1)*ring)
  crack.marks[i]=self:line(crack.marks[i],from,to,.15,markColor,markAlpha)
 end
 local open=through and math.clamp((p-CRACK_STAGES[4])/(1-CRACK_STAGES[4]),0,1) or 0
 local tremble=open>0 and not reduced and .05*open or 0
 local shake=tremble>0 and Vector3.new(math.sin(now*61)*tremble,0,math.cos(now*53)*tremble) or Vector3.zero
 local width=.13+.07*crack.stage/4+.12*open
 local color=CRACK:Lerp(HOT,.55*open)
 -- The growing loop (hidden once the real outline has cracked through).
 local pts=crack.pts;local n=#pts
 if through then
  for _,part in pairs(crack.loop) do part.Transparency=1 end
 else
  local q=math.clamp(crack.shown/CRACK_STAGES[4],0,1)
  local grow=.14+.86*q^.85
  -- Warp fades as the loop nears the outline; each snap kicks it briefly.
  local kick=0
  for _,at in pairs(crack.stageAt) do kick=math.max(kick,math.exp(-(now-at)*9)) end
  local amp=.3*(1-q)^.7+.12*kick
  local own={}
  for k,pt in ipairs(pts) do
   local wobble=reduced and 0 or .25*math.sin(now*2.3+pt.drift)
   local r=pt.reach*grow*(1+amp*(pt.warp+wobble*(1-q)))
   r=math.clamp(r,.25,pt.reach)
   own[k]=crack.center+Vector3.new(pt.dx*r,0,pt.dz*r)
  end
  -- Points not yet grown in sit on the edge between their grown neighbors,
  -- then push out to their own place: the loop gains corners.
  local final={}
  for k,pt in ipairs(pts) do
   local w=pt.anchor and 1 or smoothstep((crack.shown-pt.t)/.12)
   if w>=1 then final[k]=own[k]
   else
    local a,b=k,k
    local da,db=0,0
    repeat a=(a-2)%n+1;da+=1 until pts[a].anchor or crack.shown>=pts[a].t+.12 or da>=n
    repeat b=b%n+1;db+=1 until pts[b].anchor or crack.shown>=pts[b].t+.12 or db>=n
    local edge=own[a]:Lerp(own[b],da/(da+db))
    final[k]=edge:Lerp(own[k],w)
   end
  end
  local lift=Vector3.yAxis*.02
  for k=1,n do
   crack.loop[k]=self:line(crack.loop[k],final[k]+lift,final[k%n+1]+lift,width,color,0)
  end
 end
 -- The last snap cracks the real outline through, running out from the hit.
 local edgeRun=through and math.clamp((now-crack.stageAt[4])/RUN_TIME,0,1) or 0
 for i,e in ipairs(crack.edges) do
  if edgeRun<=0 then
   if crack.parts[i] then crack.parts[i].Transparency=1 end
  else
   local tip=e.a:Lerp(e.b,edgeRun)
   crack.parts[i]=self:line(crack.parts[i],e.a+Vector3.yAxis*.02+shake,tip+Vector3.yAxis*.02+shake,width,color,0)
  end
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
  crack=self:buildCrack(id,string.sub(key,2),player~=nil and source:GetAttribute('Owner')==player.UserId,color,point)
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
  local tone=self:colorAt(to.Y-self.origin.Y,to.X-self.origin.X,to.Z-self.origin.Z)
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

-- Rock dust from a broken chunk: glowing motes burst out, hang for the gem
-- roll, settle in a loose ring on the pit floor and bob there. When the
-- server credits the rock to its owner (they came close), the motes fly into
-- the owner's character. Motes are capped so huge digs stay cheap.
local MOTES_PER_UNIT=5
local MOTE_CAP=180
function V:addDust(part: Instance,live: boolean)
 if not part:IsA('BasePart') or self.dust[part] then return end
 local count=part:GetAttribute('Count') or 1
 local floor=part:GetAttribute('FloorY') or part.Position.Y-1
 local tint=part:GetAttribute('Color')
 local color=(typeof(tint)=='Color3' and tint or STONE_LIGHT):Lerp(Color3.fromRGB(255,248,226),.3)
 local now=os.clock()
 local from=part.Position
 local entry={part=part,owner=part:GetAttribute('Owner'),units=count,initial=count,motes={},born=live and now or now-10,flown=0}
 local total=math.min(count*MOTES_PER_UNIT,MOTE_CAP-self.motes)
 for i=1,total do
  local a=i*2.399963+self.random:NextNumber(0,.5)
  local r=.5+1.6*math.sqrt(i/math.max(1,total))
  local home=Vector3.new(from.X+math.cos(a)*r,floor+.3,from.Z+math.sin(a)*r)
  local peak=Vector3.new(from.X+math.cos(a)*r*1.6,from.Y+1.2+self.random:NextNumber(0,1.6),from.Z+math.sin(a)*r*1.6)
  local mote=fxPart(self.fx,'DigDustMote',color)
  ;(mote :: Part).Shape=Enum.PartType.Ball
  mote.Material=Enum.Material.Neon
  local size=self.random:NextNumber(.26,.42)
  mote.Size=Vector3.one*size
  mote.Position=live and from or home
  table.insert(entry.motes,{part=mote,home=home,peak=peak,from=from,phase=self.random:NextNumber(0,math.pi*2),size=size})
  self.motes+=1
 end
 self.dust[part]=entry
 table.insert(self.connections,part:GetAttributeChangedSignal('Count'):Connect(function()
  entry.units=part:GetAttribute('Count') or 0
 end))
end

function V:stepDust(now: number)
 local pause=DigCube.PAUSE
 local reduced=self:reduced()
 for part,entry in pairs(self.dust) do
  local age=now-entry.born
  -- How many motes should be on their way to the owner by now.
  local collected=1-math.clamp(entry.units/math.max(1,entry.initial),0,1)
  local want=math.floor(#entry.motes*collected+.5)
  if (part:GetAttribute('CollectedAt') or 0)>0 then want=#entry.motes end
  if entry.flown<want then
   for i=entry.flown+1,want do
    local m=entry.motes[i]
    if m and not m.flyAt then m.flyAt=now+(i-entry.flown-1)*.025;m.flyFrom=m.part.Position end
   end
   entry.flown=want
  end
  local gone=not part.Parent
  if gone and not entry.goneAt then entry.goneAt=now end
  local player=entry.owner and Players:GetPlayerByUserId(entry.owner)
  local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  local alive=0
  for _,m in ipairs(entry.motes) do
   if m.part.Parent then
    alive+=1
    local bob=reduced and 0 or .12*math.sin(now*2.2+m.phase)
    local rest=m.home+Vector3.new(0,.25+bob,0)
    local pos
    if m.flyAt and now>=m.flyAt and root and root:IsA('BasePart') then
     local t=math.clamp((now-m.flyAt)/.38,0,1)
     local e=t*t
     pos=m.flyFrom:Lerp(root.Position,e)+Vector3.yAxis*math.sin(t*math.pi)*1.4
     m.part.Size=Vector3.one*m.size*(1-.6*t)
     if t>=1 then m.part:Destroy();self.motes-=1;continue end
    elseif m.flyAt and now>=m.flyAt then
     m.part:Destroy();self.motes-=1;continue
    elseif age<.4 then
     local t=1-(1-age/.4)^2
     pos=m.from:Lerp(m.peak,t)
    elseif age<pause then
     pos=m.peak+Vector3.new(0,bob*2,0)
    elseif age<pause+.45 then
     local t=smoothstep((age-pause)/.45)
     pos=m.peak:Lerp(rest,t)
    else
     pos=rest
    end
    if entry.goneAt and not m.flyAt then
     local f=math.clamp((now-entry.goneAt)/.4,0,1)
     m.part.Transparency=f
     if f>=1 then m.part:Destroy();self.motes-=1;continue end
    end
    m.part.Position=pos
   end
  end
  if alive==0 and (gone or entry.flown>=#entry.motes) then self.dust[part]=nil end
 end
end

-- A soft warm lamp on the player while they are down in the cube: the pit
-- walls around you stay readable however deep the crater gets.
function V:stepLamp()
 if not self.cube then return end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local depth=0
 if root and root:IsA('BasePart') then
  local l=root.Position-self.origin
  local W=self.cube.width
  if l.X>=-2 and l.X<=W+2 and l.Z>=-2 and l.Z<=W+2 then
   depth=math.clamp((self.cube.height+3-l.Y)/(self.cube.height*.6),0,1)
  end
 end
 local lamp=self.lamp
 if depth<=0 then
  if lamp then lamp.Enabled=false end
  return
 end
 if not lamp or lamp.Parent~=root then
  if lamp then lamp:Destroy() end
  lamp=Instance.new('PointLight');lamp.Name='DigLamp';lamp.Shadows=false
  lamp.Color=Color3.fromRGB(255,234,200);lamp.Range=26
  lamp.Parent=root;self.lamp=lamp
 end
 lamp.Enabled=true
 lamp.Brightness=.5+1.3*depth
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

-- Gold sparkles on the rock surface above each treasure pocket still in the
-- rock: something to spot, tap and dig toward.
function V:clearSparkles()
 for _,sp in pairs(self.sparkles or {}) do sp.part:Destroy() end
 self.sparkles={}
end
function V:stepSparkles(now: number)
 if not self.cube or now<(self.sparkleAt or 0) then return end
 self.sparkleAt=now+.8
 self.sparkles=self.sparkles or {}
 local rock=self.holder and self.holder:FindFirstChild('Rock')
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances=rock and {rock} or {}
 for id in pairs(self.cube.treasure) do
  local sp=self.sparkles[id]
  if self.cube.removed[id] then
   if sp then sp.part:Destroy();self.sparkles[id]=nil end
  else
   local c=self.cube.cells[id]
   local top=self.origin+Vector3.new(c.cx,self.cube.height+8,c.cz)
   local hit=rock and workspace:Raycast(top,Vector3.new(0,-(self.cube.height+12),0),params)
   local at=hit and hit.Position or self.origin+Vector3.new(c.cx,self.cube.height,c.cz)
   if not sp then
    local part=fxPart(self.fx,'TreasureSparkle',Color3.fromRGB(255,214,90))
    part.Transparency=1;part.Size=Vector3.new(3,.2,3)
    local emitter=Instance.new('ParticleEmitter')
    emitter.Texture='rbxasset://textures/particles/sparkles_main.dds'
    emitter.Color=ColorSequence.new(Color3.fromRGB(255,222,120))
    emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(1,0)})
    emitter.Lifetime=NumberRange.new(.7,1.2);emitter.Rate=9;emitter.Speed=NumberRange.new(2,5)
    emitter.SpreadAngle=Vector2.new(25,25);emitter.LightEmission=.7
    emitter.EmissionDirection=Enum.NormalId.Top;emitter.Parent=part
    sp={part=part};self.sparkles[id]=sp
   end
   sp.part.CFrame=CFrame.new(at+Vector3.yAxis*.15)
  end
 end
end

function V:update()
 local now=os.clock()
 self:stepSparkles(now)
 self:stepCracks(now)
 self:stepSplits(now)
 self:stepDebris(now)
 self:stepDust(now)
 self:stepLamp()
 self:stepPad(now)
end

function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for id in pairs(self.cracks) do self:dropCrack(id) end
 if self.lamp then self.lamp:Destroy() end
 self.fx:Destroy()
end
return V
