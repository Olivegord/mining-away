--!strict
-- Client effects for the Dig Cube. The rock itself is solid server geometry
-- (blocks carved by each broken piece's Voronoi cells, Roblox CSG), so this
-- view draws what happens on it:
--  * a chunk comes away in pieces (the server breaks its middle first, then
--    the rock around it). Each piece that breaks shatters into shards cut
--    from its real cells: they pop out, tumble, land on the pit floor and fly
--    into their owner's bag when the server credits the rock
--  * one soft ribbon beam per drone with a few sparks where it touches
--  * one lit dust puff per break; a gem (after the hold) gets the gem burst
--    and a name banner
--  * a dim lamp on the player down in the pit, the launch pad and tap-to-focus
-- Nothing is drawn on the rock before it breaks: no target marks or crack
-- lines, and nothing here uses Neon, so gems stay the brightest thing.
local DigCube=require('./DigCube')
local UIS=game:GetService('UserInputService')
local Players=game:GetService('Players')
local V={}
V.__index=V
local BEAM_CORE=Color3.fromRGB(255,250,235)
local HOT=Color3.fromRGB(222,128,62)
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
 local self=setmetatable({ctx=ctx,beams={},splits={},frags={},banners={},dust={},puffs=0,cube=nil,origin=Vector3.zero,
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
 pad.Material=Enum.Material.SmoothPlastic;pad.Color=Color3.fromRGB(226,150,62);pad.Transparency=.2
 pad.Parent=self.fx
 local emitter=Instance.new('ParticleEmitter')
 emitter.Texture='rbxasset://textures/particles/sparkles_main.dds'
 emitter.Color=ColorSequence.new(Color3.fromRGB(255,206,120))
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,0)})
 emitter.Lifetime=NumberRange.new(.8,1.3);emitter.Rate=8;emitter.Speed=NumberRange.new(9,14)
 emitter.EmissionDirection=Enum.NormalId.Right;emitter.SpreadAngle=Vector2.new(8,8);emitter.LightEmission=.2
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
  for _,f in ipairs(self.frags) do self:dropShard(f) end
  self.frags={}
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
   local op={kind='c',cells=DigCube.parseKey(key),tier=tonumber(tier) or 0,treasure=flag=='T',partial=flag=='P',layer=flag=='D' and tonumber(depth) or nil}
   -- Out of the cube first, so shards land on the floor the break leaves.
   for _,id in ipairs(op.cells) do DigCube.remove(self.cube,id) end
   self:split(op,now)
  end
 end
end

-- Sparse, soft particles: a lit dust puff in the rock's color and a few
-- small bright discs. The dust takes the scene's light instead of glowing.
function V:puff(at: Vector3,color: Color3,scale: number,glints: number)
 if self:reduced() or self.puffs>=10 then return end
 local anchor=fxPart(self.fx,'DigPuff',color);anchor.Transparency=1;anchor.Size=Vector3.one*.05;anchor.Position=at
 self.puffs+=1
 anchor.Destroying:Connect(function() self.puffs-=1 end)
 local dust=Instance.new('ParticleEmitter');dust.Name='Dust'
 EnergyDisc.configure(dust,1.5*scale,.62,.45,1.7,.2)
 dust.LightEmission=0;dust.LightInfluence=1;dust.Brightness=1
 dust.Color=ColorSequence.new(color:Lerp(STONE_LIGHT,.25))
 dust.Enabled=false;dust.Rate=0
 dust.EmissionDirection=Enum.NormalId.Top;dust.SpreadAngle=Vector2.new(80,80)
 dust.Speed=NumberRange.new(3*scale,7*scale);dust.Lifetime=NumberRange.new(.35,.7);dust.Drag=4
 dust.Acceleration=Vector3.new(0,1,0)
 dust.Parent=anchor;dust:Emit(math.floor(5+3*scale))
 if glints>0 then
  local spark=Instance.new('ParticleEmitter');spark.Name='Glints'
  EnergyDisc.configure(spark,.24*scale,.08,1,0,.3)
  spark.LightEmission=.25;spark.LightInfluence=0;spark.Brightness=1
  spark.Color=ColorSequence.new(color:Lerp(Color3.fromRGB(255,246,224),.65))
  spark.Enabled=false;spark.Rate=0
  spark.EmissionDirection=Enum.NormalId.Top;spark.SpreadAngle=Vector2.new(70,70)
  spark.Speed=NumberRange.new(9,18);spark.Lifetime=NumberRange.new(.25,.5);spark.Drag=2
  spark.Acceleration=Vector3.new(0,-34,0)
  spark.Parent=anchor;spark:Emit(glints)
 end
 task.delay(1.3,function() anchor:Destroy() end)
end

-- Shards: every cell of a broken piece splits into prisms cut from its own
-- outline, so what flies out is the rock that was there. Each one is thrown
-- to a landing spot chosen on the real pit floor (never up onto a wall).
local SHARD_CAP=90
local SHARD_SCALE=.86
function V:throw(f: any,now: number,from: Vector3,target: Vector3,rise: number)
 local o=self.origin
 local top=DigCube.surfaceAt(self.cube,target.X-o.X,target.Z-o.Z) or 0
 local land=Vector3.new(target.X,o.Y+top+f.rest,target.Z)
 local apex=math.max(from.Y,land.Y)+rise
 local up=math.sqrt(2*GRAVITY*(apex-from.Y))
 local T=up/GRAVITY+math.sqrt(2*(apex-land.Y)/GRAVITY)
 f.at=now;f.from=from;f.T=T;f.land=land
 f.v=Vector3.new((land.X-from.X)/T,up,(land.Z-from.Z)/T)
end
function V:shards(op: any,now: number,center: Vector3)
 local o=self.origin;local cube=self.cube
 local made={}
 for _,id in ipairs(op.cells) do
  local c=cube.cells[id]
  if c and #self.frags<SHARD_CAP+20 then
   local poly=c.poly;local n=#poly
   -- Over budget: the cell flies as one smaller block.
   local whole=#self.frags+n-2>SHARD_CAP or n<=3
   local tris={}
   if whole then tris[1]=poly else for k=2,n-1 do table.insert(tris,{poly[1],poly[k],poly[k+1]}) end end
   for _,tri in ipairs(tris) do
    local mx,mz=0,0
    for _,v in ipairs(tri) do mx+=v[1];mz+=v[2] end
    mx/=#tri;mz/=#tri
    local mid=o+Vector3.new(mx,(c.y0+c.y1)*.5,mz)
    local color=self:colorAt(c.y1-.01,mx,mz):Lerp(Color3.new(0,0,0),self.random:NextNumber(0,.14))
    local inverse=CFrame.new(mid):Inverse()
    local parts={}
    for _,w in ipairs(DigCube.polyWedges(tri,c.y0,c.y1)) do
     local part=fxPart(self.fx,'DigShard',color,'WedgePart');part.CastShadow=true
     local size=Vector3.new(w.size[1],w.size[2],w.size[3])
     local frame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
      Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
     table.insert(parts,{part=part,size=size,rel=inverse*frame})
    end
    if #parts>0 then
     local k=whole and SHARD_SCALE*.55 or SHARD_SCALE
     local axis=Vector3.new(self.random:NextNumber(-1,1),self.random:NextNumber(-.3,.3),self.random:NextNumber(-1,1))
     local out=Vector3.new(mid.X-center.X,0,mid.Z-center.Z)
     local far=out.Magnitude
     local a=self.random:NextNumber(0,math.pi*2)
     out=far>.3 and out.Unit or Vector3.new(math.cos(a),0,math.sin(a))
     local f={parts=parts,k=k,scale=k,rest=math.min(c.y1-c.y0,2.4)*.5*k,axis=axis.Magnitude>.05 and axis.Unit or Vector3.xAxis,
      spin=self.random:NextNumber(3,7),born=now,pos=mid}
     -- Land near where it came from; pull in until the spot is no higher
     -- than this cell's floor (the pit, not the wall beside it).
     local reach=self.random:NextNumber(1.2,3.6)
     local target=mid
     for _=1,4 do
      local try=mid+out*reach
      local top=DigCube.surfaceAt(cube,try.X-o.X,try.Z-o.Z)
      if top and top<=c.y0+.6 then target=try;break end
      reach*=.5
     end
     self:throw(f,now+math.min(.09,far*.012),mid,target,(c.y1-c.y0)*.5+self.random:NextNumber(1.2,3.4))
     table.insert(self.frags,f);table.insert(made,f)
    end
   end
  end
 end
 -- Rock dust the server already dropped here claims these shards.
 for _,entry in pairs(self.dust) do
  if now-entry.born<2.5 and Vector3.new(entry.at.X-center.X,0,entry.at.Z-center.Z).Magnitude<10 then
   for _,f in ipairs(made) do f.dust=entry;table.insert(entry.frags,f) end
   break
  end
 end
end

function V:dropShard(f: any)
 f.dead=true
 for _,q in ipairs(f.parts) do q.part:Destroy() end
end

function V:stepShards(now: number)
 local o=self.origin
 local settle=now>=(self.settleAt or 0)
 if settle then self.settleAt=now+.25 end
 for i=#self.frags,1,-1 do
  local f=self.frags[i]
  local t=now-f.at
  local pos=f.from
  local angle=0
  local k=f.k
  if f.flyAt and now>=f.flyAt then
   local player=f.dust and f.dust.owner and Players:GetPlayerByUserId(f.dust.owner)
   local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
   local e=math.clamp((now-f.flyAt)/.36,0,1)
   if not root or not root:IsA('BasePart') or e>=1 then self:dropShard(f);table.remove(self.frags,i);continue end
   pos=f.flyFrom:Lerp(root.Position,e*e)+Vector3.yAxis*math.sin(e*math.pi)*1.6
   angle=f.spin*f.T+e*4
   k=f.k*(1-.7*e)
  elseif t<=0 then
   pos=f.from
  elseif t<f.T then
   pos=f.from+f.v*t-Vector3.yAxis*(GRAVITY*.5*t*t)
   angle=f.spin*t
  else
   local age=t-f.T
   pos=f.land+Vector3.yAxis*math.max(0,5*age-GRAVITY*.5*age*age)
   angle=f.spin*f.T
   -- The rock under it may break later: fall to the new floor.
   if settle and self.cube then
    local top=DigCube.surfaceAt(self.cube,pos.X-o.X,pos.Z-o.Z) or 0
    if o.Y+top+f.rest<f.land.Y-.3 then
     f.spun=(f.spun or 0)+angle;f.spin=0
     self:throw(f,now,pos,pos,0)
    end
   end
   -- Nobody is collecting it: it crumbles away.
   local gone=f.dust and f.dust.goneAt
   local fadeAt=gone or (not f.dust and f.at+f.T+1 or nil)
   if #self.frags>SHARD_CAP and not fadeAt then fadeAt=now end
   if fadeAt and not f.fadeAt then f.fadeAt=math.max(now,fadeAt) end
   if f.fadeAt then
    local fade=math.clamp((now-f.fadeAt)/.3,0,1)
    k=f.k*(1-fade)
    if fade>=1 then self:dropShard(f);table.remove(self.frags,i);continue end
   end
  end
  f.pos=pos
  local frame=CFrame.new(pos)*CFrame.fromAxisAngle(f.axis,(f.spun or 0)+angle)
  local resize=k~=f.scale
  f.scale=k
  for _,q in ipairs(f.parts) do
   if resize then q.part.Size=q.size*k end
   q.part.CFrame=frame*(q.rel.Rotation+q.rel.Position*k)
  end
 end
end

-- A piece breaks off: shards, one dust puff, a crack sound and a camera
-- beat. The last piece of a chunk is the bigger hit; if a gem is inside it
-- shows after the hold (the gamble).
function V:split(op: any,now: number)
 local cube=self.cube;local o=self.origin
 local first=cube.cells[op.cells[1]]
 if not first then return end
 local _,cx,cz=DigCube.chunkArea(cube,op.cells)
 local volume=DigCube.volume(cube,op.cells)
 local bulk=volume^(1/3)
 local center=o+Vector3.new(cx,(first.y0+first.y1)*.5,cz)
 local top=o+Vector3.new(cx,first.y1,cz)
 local color=self:colorAt(first.y1-.01,cx,cz)
 self:shards(op,now,center)
 local ctx=self.ctx
 local serverNow=workspace:GetServerTimeNow()
 if op.partial then
  if ctx.audio then ctx.audio:play('crystal_impact',top,{pitch=self.random:NextNumber(.9,1.2),level=.85,rockSize=bulk}) end
  self:puff(top,color,.8,4)
  if ctx.beat and not self:reduced() then ctx.beat('Split',center,serverNow,.4) end
  return
 end
 if ctx.audio then
  ctx.audio:play('crystal_split',top,{rockSize=bulk})
  ctx.audio:play('crystal_release_tink',top,{level=.8})
 end
 self:puff(top,color,1.25,8)
 if ctx.beat and not self:reduced() then ctx.beat(bulk>6 and 'HeavySplit' or 'Split',center,serverNow,math.clamp(.5+bulk/9,.6,1.25)) end
 if op.tier>0 then
  table.insert(self.splits,{at=now,tier=op.tier,treasure=op.treasure,center=center,size=bulk,revealed=false})
 end
end

function V:reveal(e: any,now: number)
 e.revealed=true
 local ctx=self.ctx
 local color=rgb(DigCube.ORES[e.tier].color)
 if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1+e.tier*.08,level=1}) end
 if not self:reduced() then
  if ctx.effects then ctx.effects.ImpactParticles(e.center,color,1+e.tier*.15,'GemReward') end
  if ctx.beat then ctx.beat(e.tier>=3 and 'HeavySplit' or 'Split',e.center,workspace:GetServerTimeNow(),math.min(1.2,.6+e.tier*.12)) end
 end
 if e.treasure then
  -- Jackpot: a treasure pocket pays several rare gems.
  self:banner(e.center+Vector3.yAxis*e.size*.5,'TREASURE!',Color3.fromRGB(255,214,90),1.5)
  if not self:reduced() and ctx.effects then
   for i=1,2 do task.delay(i*.14,function() ctx.effects.ImpactParticles(e.center+Vector3.yAxis*i*.6,rgb(DigCube.ORES[((e.tier+i-2)%#DigCube.ORES)+1].color),1.2,'GemReward') end) end
  end
  if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1.5,level=1}) end
 else
  self:banner(e.center+Vector3.yAxis*e.size*.5,TIER_NAMES[e.tier] or 'GEM!',color)
 end
end

function V:banner(at: Vector3,text: string,color: Color3,big: number?)
 local anchor=fxPart(self.fx,'DigReveal',color);anchor.Transparency=1;anchor.Size=Vector3.one*.1;anchor.Position=at+Vector3.yAxis*2
 local k=big or 1
 local gui=Instance.new('BillboardGui');gui.Size=UDim2.fromOffset(200*k,52*k);gui.AlwaysOnTop=true;gui.LightInfluence=0
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

-- One beam per digging drone, from its rendered emitter to its cut: a faint
-- wide ribbon and a thin core (soft edges, no glow rods), and a few small
-- sparks where it touches the rock. Other players' beams are fainter.
local BEAM_BODY=NumberSequence.new({NumberSequenceKeypoint.new(0,.9),NumberSequenceKeypoint.new(.15,.72),NumberSequenceKeypoint.new(1,.6)})
local BEAM_CORE_FADE=NumberSequence.new({NumberSequenceKeypoint.new(0,.7),NumberSequenceKeypoint.new(.15,.25),NumberSequenceKeypoint.new(1,.1)})
local BEAM_FAINT=NumberSequence.new({NumberSequenceKeypoint.new(0,.9),NumberSequenceKeypoint.new(.15,.7),NumberSequenceKeypoint.new(1,.6)})
function V:hideBeam(beam: any)
 if not beam.on then return end
 beam.on=false;beam.body.Enabled=false;beam.core.Enabled=false;beam.sparks.Enabled=false
end
function V:droneBeam(source: Instance,from: Vector3,now: number,color: Color3?)
 local id=source:GetAttribute('DroneId')
 if type(id)~='string' or not self.cube then return end
 local point=source:GetAttribute('DigPoint')
 local key=source:GetAttribute('DigOp')
 local active=type(key)=='string' and key~='' and source:GetAttribute('DigMining')==true and source:GetAttribute('WorkPaused')~=true
 local beam=self.beams[id]
 if not active or typeof(point)~='Vector3' or (point-from).Magnitude<.1 then
  if beam then self:hideBeam(beam) end
  return
 end
 local tint=color or HOT
 if not beam then
  local player=Players.LocalPlayer
  local mine=player~=nil and source:GetAttribute('Owner')==player.UserId
  local root=fxPart(self.fx,'DigBeam',tint);root.Transparency=1;root.Size=Vector3.one*.05
  local a=Instance.new('Attachment');a.Name='From';a.Parent=root
  local b=Instance.new('Attachment');b.Name='To';b.Parent=root
  local function ribbon(name: string,width: number,c: Color3,fade: NumberSequence,emission: number)
   local r=Instance.new('Beam');r.Name=name;r.Attachment0=a;r.Attachment1=b;r.FaceCamera=true;r.Segments=1
   r.Width0=width*.6;r.Width1=width;r.Color=ColorSequence.new(c);r.Transparency=fade
   r.LightEmission=emission;r.LightInfluence=0;r.Brightness=1;r.Enabled=false;r.Parent=root
   return r
  end
  local body=ribbon('Body',mine and .42 or .3,tint,BEAM_BODY,.3)
  local core=ribbon('Core',mine and .11 or .08,tint:Lerp(BEAM_CORE,.7),mine and BEAM_CORE_FADE or BEAM_FAINT,.45)
  local sparks=Instance.new('ParticleEmitter');sparks.Name='Contact'
  EnergyDisc.configure(sparks,.2,.1,1,0,.35)
  sparks.LightEmission=.25;sparks.LightInfluence=0;sparks.Brightness=1
  sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(65,65)
  sparks.Speed=NumberRange.new(5,11);sparks.Lifetime=NumberRange.new(.18,.38);sparks.Drag=2
  sparks.Acceleration=Vector3.new(0,-26,0);sparks.Rate=mine and 14 or 6;sparks.Enabled=false;sparks.Parent=b
  beam={root=root,a=a,body=body,core=core,sparks=sparks,on=false}
  self.beams[id]=beam
 end
 beam.root.CFrame=CFrame.new(point)
 beam.a.Position=from-point
 if beam.tint~=tint then
  beam.tint=tint
  local rock=self:colorAt(point.Y-self.origin.Y-.01,point.X-self.origin.X,point.Z-self.origin.Z)
  beam.body.Color=ColorSequence.new(tint);beam.core.Color=ColorSequence.new(tint:Lerp(BEAM_CORE,.7))
  beam.sparks.Color=ColorSequence.new(tint:Lerp(BEAM_CORE,.6),rock:Lerp(STONE_LIGHT,.3))
 end
 if not beam.on then
  beam.on=true;beam.body.Enabled=true;beam.core.Enabled=true;beam.sparks.Enabled=not self:reduced()
 end
 beam.seen=now
end
function V:stepBeams(now: number)
 for id,beam in pairs(self.beams) do
  local idle=now-(beam.seen or 0)
  if idle>.3 then self:hideBeam(beam) end
  if idle>20 then beam.root:Destroy();self.beams[id]=nil end
 end
end

-- Rock from a broken piece: the server leaves a (hidden) Dust part where it
-- broke and credits its owner when they are close. The shards from that
-- break belong to it: they wait on the pit floor and fly into the owner as
-- the rock is credited, or crumble if nobody ever collects it.
function V:addDust(part: Instance,live: boolean)
 if not part:IsA('BasePart') or self.dust[part] then return end
 local count=part:GetAttribute('Count') or 1
 local now=os.clock()
 local entry={part=part,owner=part:GetAttribute('Owner'),units=count,initial=count,frags={},born=live and now or now-10,flown=0,at=part.Position}
 if live then
  for _,f in ipairs(self.frags) do
   if not f.dust and not f.fadeAt and now-f.born<2.5 and Vector3.new(f.pos.X-entry.at.X,0,f.pos.Z-entry.at.Z).Magnitude<10 then
    f.dust=entry;table.insert(entry.frags,f)
   end
  end
 end
 self.dust[part]=entry
 table.insert(self.connections,part:GetAttributeChangedSignal('Count'):Connect(function()
  entry.units=part:GetAttribute('Count') or 0
 end))
end

function V:stepDust(now: number)
 for part,entry in pairs(self.dust) do
  -- How many shards should be on their way to the owner by now.
  local collected=1-math.clamp(entry.units/math.max(1,entry.initial),0,1)
  local want=math.floor(#entry.frags*collected+.5)
  if (part:GetAttribute('CollectedAt') or 0)>0 then want=#entry.frags end
  if entry.flown<want then
   for i=entry.flown+1,want do
    local f=entry.frags[i]
    if f and not f.dead and not f.flyAt then f.flyAt=now+(i-entry.flown-1)*.03;f.flyFrom=f.pos end
   end
   entry.flown=want
  end
  if not part.Parent then
   -- Shards already flying finish; the rest crumble.
   if entry.flown<#entry.frags and not entry.goneAt then entry.goneAt=now end
   entry.doneAt=entry.doneAt or now
   if now-entry.doneAt>3 then self.dust[part]=nil end
  end
 end
end

-- A dim warm lamp on the player while they are down in the cube, just
-- enough to keep the pit walls from going flat. Kept low: a bright lamp on
-- bright rock washed the whole pit out.
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
  lamp.Color=Color3.fromRGB(255,234,200);lamp.Range=22
  lamp.Parent=root;self.lamp=lamp
 end
 lamp.Enabled=true
 lamp.Brightness=.15+.4*depth
end

function V:stepPad(now: number)
 local pad=self.pad;if not pad or not self.cube then return end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 pad.Transparency=.2+.08*math.sin(now*3)
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
 self:puff(hit.Position+hit.Normal*.2,Color3.fromRGB(255,226,160),.6,5)
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
    emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.4),NumberSequenceKeypoint.new(1,0)})
    emitter.Lifetime=NumberRange.new(.7,1.2);emitter.Rate=5;emitter.Speed=NumberRange.new(2,5)
    emitter.SpreadAngle=Vector2.new(25,25);emitter.LightEmission=.3
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
 self:stepBeams(now)
 self:stepSplits(now)
 self:stepDust(now)
 self:stepShards(now)
 self:stepLamp()
 self:stepPad(now)
end

function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
  if self.lamp then self.lamp:Destroy() end
 self.fx:Destroy()
end
return V
