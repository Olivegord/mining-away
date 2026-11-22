--!strict
-- Client effects for the Dig Cube. The rock itself is solid server geometry
-- (blocks carved by each broken piece's Voronoi cells, Roblox CSG), so this
-- view draws what happens on it:
--  * a chunk comes away in pieces (the server breaks its middle first, then
--    the rock around it). Each piece that breaks is cracked into rubble cut
--    from its real cells, which slumps into the hole, tips over and fades;
--    one pebble stays to collect and flies to its owner when credited
--  * each break plays the field rocks' break: frame pause, sounds, combo,
--    camera hit, sparks, shock ring, particle burst, tumbling pieces
--  * one ribbon beam per drone with chips and sparks where it touches
--  * a gem (after the hold) gets the gem burst and a name banner
--  * a dim lamp on the player down in the pit, the launch pad and tap-to-focus
--  * before each piece breaks it cracks in two stages, like the reference
--    rocks: it darkens under the beam, then pops loose (lifts, tilts, turns)
--    with its color back, a crack sound, chips and dust. No drawn lines
-- Nothing here uses Neon.
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
 local self=setmetatable({ctx=ctx,beams={},splits={},frags={},banners={},dust={},puffs=0,mine={},cellColor={},flashes={},pending={},floors={},cracks={},crackCells={},cube=nil,origin=Vector3.zero,
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
 local at=self.origin+Vector3.new(-5,self.cube.height,W*.5) -- on the ground beside the pit
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
  self.frags={};self.mine={};self.cellColor={}
  self:clearCracks()
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
   local op={kind='c',cells=DigCube.parseKey(key),tier=tonumber(tier) or 0,treasure=flag=='T',partial=flag=='P',stage=flag=='P' and tonumber(depth) or nil,layer=flag=='D' and tonumber(depth) or nil}
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
 EnergyDisc.configure(dust,1.1*scale,.42,.5,1.6,.25)
 dust.LightEmission=0;dust.LightInfluence=1;dust.Brightness=1
 dust.Color=ColorSequence.new(color:Lerp(Color3.fromRGB(255,246,226),.5))
 dust.Enabled=false;dust.Rate=0
 dust.EmissionDirection=Enum.NormalId.Top;dust.SpreadAngle=Vector2.new(80,80)
 dust.Speed=NumberRange.new(4*scale,10*scale);dust.Lifetime=NumberRange.new(.3,.55);dust.Drag=5
 dust.Acceleration=Vector3.new(0,1,0)
 dust.Parent=anchor;dust:Emit(math.floor(6+4*scale))
 if glints>0 then
  local spark=Instance.new('ParticleEmitter');spark.Name='Glints'
  EnergyDisc.configure(spark,.3*scale,.05,1,0,.3)
  spark.LightEmission=.6;spark.LightInfluence=0;spark.Brightness=1
  spark.Color=ColorSequence.new(color:Lerp(Color3.fromRGB(255,246,224),.65))
  spark.Enabled=false;spark.Rate=0
  spark.EmissionDirection=Enum.NormalId.Top;spark.SpreadAngle=Vector2.new(70,70)
  spark.Speed=NumberRange.new(9,18);spark.Lifetime=NumberRange.new(.25,.5);spark.Drag=2
  spark.Acceleration=Vector3.new(0,-34,0)
  spark.Parent=anchor;spark:Emit(glints)
 end
 task.delay(1.3,function() anchor:Destroy() end)
end

-- Rubble: the broken rock itself. Each cell of a broken piece is cracked
-- into two or three chunky pieces (cut through its middle at random angles),
-- each a prism of the cell's own outline, so for a moment the hole holds
-- exactly the rock that was there. When the server has registered the
-- rubble collision groups the pieces are real loose parts: they pop free,
-- fall, tumble and pile up on an invisible floor at the bottom of the hole
-- (they touch nothing else, so players and the rock still being carved
-- cannot fling them), then shrink and fade. Without the groups they slump
-- and tip by hand. One pebble per rock drop stays to collect and flies to
-- its owner when the server credits it.
local SHARD_CUT,SHARD_MAX=60,110 -- live pieces: cells stop being cut up, then stop making rubble
local SHARD_DARK=Color3.fromRGB(46,38,36)
local SHARD_GAP=.9 -- pieces start slightly apart, so the cracks between them show
local SHARD_FADE=.45
local SHARD_LIFE=1.25 -- seconds of tumbling before a loose piece fades
local RUBBLE=PhysicalProperties.new(2.6,.8,.12,1,1)
-- The part of a convex polygon on the side (v-c).n <= 0.
local function cutPoly(poly: {{number}},cx: number,cz: number,nx: number,nz: number): {{number}}
 local out={}
 local n=#poly
 for k=1,n do
  local a,b=poly[k],poly[k%n+1]
  local da=(a[1]-cx)*nx+(a[2]-cz)*nz;local db=(b[1]-cx)*nx+(b[2]-cz)*nz
  if da<=0 then table.insert(out,a) end
  if (da<0 and db>0) or (da>0 and db<0) then
   local t=da/(da-db)
   table.insert(out,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t})
  end
 end
 return out
end
local function middle(poly: {{number}}): (number,number,number)
 local area,cx,cz=0,0,0
 local n=#poly
 for k=1,n do
  local a,b=poly[k],poly[k%n+1]
  local cross=a[1]*b[2]-b[1]*a[2]
  area+=cross;cx+=(a[1]+b[1])*cross;cz+=(a[2]+b[2])*cross
 end
 if math.abs(area)<1e-6 then
  local x,z=0,0
  for _,v in ipairs(poly) do x+=v[1];z+=v[2] end
  return 0,x/n,z/n
 end
 return math.abs(area)*.5,cx/(3*area),cz/(3*area)
end
-- Two or three chunky convex pieces of a cell outline.
function V:crackCell(poly: {{number}},pieces: number,fixed: number?,twist: number?): {{{number}}}
 local _,cx,cz=middle(poly)
 local angle=fixed or self.random:NextNumber(0,math.pi)
 local nx,nz=math.cos(angle),math.sin(angle)
 local a,b=cutPoly(poly,cx,cz,nx,nz),cutPoly(poly,cx,cz,-nx,-nz)
 local out={}
 for _,piece in ipairs({a,b}) do if #piece>=3 then table.insert(out,piece) end end
 if pieces>=3 and #out==2 then
  local big=middle(out[1])>middle(out[2]) and 1 or 2
  local _,px,pz=middle(out[big])
  local turn=angle+math.pi*.5+(twist or self.random:NextNumber(-.4,.4))
  local mx,mz=math.cos(turn),math.sin(turn)
  local c,d=cutPoly(out[big],px,pz,mx,mz),cutPoly(out[big],px,pz,-mx,-mz)
  if #c>=3 and #d>=3 then table.remove(out,big);table.insert(out,c);table.insert(out,d) end
 end
 return #out>0 and out or {poly}
end
function V:physicsReady(): boolean
 local now=os.clock()
 if self.physics==nil or (not self.physics and now>=(self.physicsCheckAt or 0)) then
  self.physicsCheckAt=now+5
  local ok,ready=pcall(function()
   local physics=game:GetService('PhysicsService')
   return physics:IsCollisionGroupRegistered('DigRubble') and physics:IsCollisionGroupRegistered('DigRubbleFloor')
  end)
  self.physics=ok and ready==true
 end
 return self.physics==true
end
function V:shards(op: any,now: number,center: Vector3)
 local o=self.origin;local cube=self.cube
 local loose=self:physicsReady()
 local made={}
 local lo,hi=Vector3.new(math.huge,0,math.huge),Vector3.new(-math.huge,0,-math.huge)
 local floorY=math.huge
 for _,id in ipairs(op.cells) do
  local c=cube.cells[id]
  if c and #self.frags<SHARD_MAX then
   lo=Vector3.new(math.min(lo.X,c.minX),0,math.min(lo.Z,c.minZ));hi=Vector3.new(math.max(hi.X,c.maxX),0,math.max(hi.Z,c.maxZ))
   floorY=math.min(floorY,c.y0)
   local polys=#self.frags<SHARD_CUT and self:crackCell(c.poly,c.area>14 and 3 or 2) or {c.poly}
   for _,poly in ipairs(polys) do
    local _,mx,mz=middle(poly)
    local mid=o+Vector3.new(mx,(c.y0+c.y1)*.5,mz)
    -- The rock's own color, a little darker here and there so the pieces
    -- read as separate (and fresh-broken faces look deeper).
    local color=self:colorAt(c.y1-.01,mx,mz):Lerp(SHARD_DARK,self.random:NextNumber(.06,.3))
    local inverse=CFrame.new(mid):Inverse()
    local parts={}
    for _,w in ipairs(DigCube.polyWedges(poly,c.y0,c.y1)) do
     local part=fxPart(self.fx,'DigShard',color,'WedgePart');part.CastShadow=true
     local size=Vector3.new(w.size[1],w.size[2],w.size[3])
     local frame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
      Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
     local rel=inverse*frame
     part.Size=size*SHARD_GAP;part.CFrame=CFrame.new(mid)*(rel.Rotation+rel.Position*SHARD_GAP)
     table.insert(parts,{part=part,size=size,rel=rel})
    end
    if #parts>0 then
     local height=c.y1-c.y0
     local out=Vector3.new(mid.X-center.X,0,mid.Z-center.Z)
     local far=out.Magnitude
     local a=self.random:NextNumber(0,math.pi*2)
     out=far>.3 and out.Unit or Vector3.new(math.cos(a),0,math.sin(a))
     local axis=Vector3.new(self.random:NextNumber(-1,1),self.random:NextNumber(-.35,.35),self.random:NextNumber(-1,1))
     local rest=height*.5*SHARD_GAP*self.random:NextNumber(.45,.85)
     local landY=math.min(mid.Y,o.Y+c.y0+rest)
     local drop=mid.Y-landY
     local f={parts=parts,k=SHARD_GAP,scale=SHARD_GAP,axis=axis.Magnitude>.05 and axis.Unit or Vector3.xAxis,
      turn=self.random:NextNumber(.5,2.4)*(self.random:NextNumber()<.5 and -1 or 1),
      from=mid,land=Vector3.new(mid.X,landY,mid.Z)+out*self.random:NextNumber(.1,.9),
      at=now+math.min(.14,far*.016)+self.random:NextNumber(0,.03),
      T=.24+math.sqrt(2*drop/GRAVITY)*1.15,hop=self.random:NextNumber(.35,.95),
      wait=self.random:NextNumber(.3,.7),born=now,pos=mid,out=out,floor=o.Y+c.y0}
     if loose then
      f.loose=true;f.life=SHARD_LIFE+self.random:NextNumber(0,.35)
      local primary=parts[1].part
      for i=2,#parts do
       local weld=Instance.new('WeldConstraint');weld.Part0=primary;weld.Part1=parts[i].part;weld.Parent=primary
      end
      for _,q in ipairs(parts) do
       q.part.CollisionGroup='DigRubble';q.part.CustomPhysicalProperties=RUBBLE;q.part.CanCollide=true
      end
     end
     table.insert(self.frags,f);table.insert(made,f)
    end
   end
  end
 end
 -- The invisible floor the loose pieces land and pile on.
 if loose and #made>0 then
  local size=Vector3.new(hi.X-lo.X+10,2,hi.Z-lo.Z+10)
  local floor=fxPart(self.fx,'DigRubbleFloor',SHARD_DARK);floor.Transparency=1;floor.CanCollide=true
  floor.CollisionGroup='DigRubbleFloor';floor.Size=size
  floor.CFrame=CFrame.new(o.X+(lo.X+hi.X)*.5,o.Y+floorY-1,o.Z+(lo.Z+hi.Z)*.5)
  table.insert(self.floors,{part=floor,untilAt=now+SHARD_LIFE+3})
 end
 -- Rock dust the server already dropped here claims these pieces.
 for _,entry in pairs(self.dust) do
  if now-entry.born<2.5 and Vector3.new(entry.at.X-center.X,0,entry.at.Z-center.Z).Magnitude<10 then
   for _,f in ipairs(made) do self:claim(entry,f) end
   break
  end
 end
end

-- A piece joins the rock dust it came from. The first one is the keeper: it
-- stays as a small pebble until the rock is collected (then flies to its
-- owner) or the dust expires.
function V:claim(entry: any,f: any)
 f.dust=entry;table.insert(entry.frags,f)
 if not entry.keeper then entry.keeper=f;f.keeper=true end
end
function V:dropShard(f: any)
 f.dead=true
 for _,q in ipairs(f.parts) do q.part:Destroy() end
end
-- A loose piece stops being simulated: it is held where physics left it, so
-- it can shrink, fade or fly by hand.
function V:settle(f: any)
 f.settled=true
 local primary=f.parts[1].part
 local first=f.parts[1]
 local scaled=first.rel.Rotation+first.rel.Position*f.k
 f.base=primary.CFrame*scaled:Inverse()
 for _,q in ipairs(f.parts) do
  for _,child in ipairs(q.part:GetChildren()) do if child:IsA('WeldConstraint') then child:Destroy() end end
  q.part.Anchored=true;q.part.CanCollide=false
 end
 f.settledAt=os.clock()
end

function V:stepShards(now: number)
 for i=#self.floors,1,-1 do
  local floor=self.floors[i]
  if now>=floor.untilAt then floor.part:Destroy();table.remove(self.floors,i) end
 end
 for i=#self.frags,1,-1 do
  local f=self.frags[i]
  local t=now-f.at
  local k=f.k
  local clear=0
  local frame
  if f.loose and not f.settled then
   local primary=f.parts[1].part
   if t>=0 and not f.released then
    -- Cracks free: a small pop up and out, a random spin, then gravity.
    f.released=true
    for _,q in ipairs(f.parts) do q.part.Anchored=false end
    primary.AssemblyLinearVelocity=f.out*self.random:NextNumber(2,6)+Vector3.yAxis*self.random:NextNumber(5,11)
    primary.AssemblyAngularVelocity=Vector3.new(self.random:NextNumber(-7,7),self.random:NextNumber(-4,4),self.random:NextNumber(-7,7))
   end
   f.pos=primary.Position
   if primary.Position.Y<f.floor-8 or not primary.Parent then self:dropShard(f);table.remove(self.frags,i);continue end
   if t>=f.life or (f.flyAt and now>=f.flyAt) then self:settle(f) else continue end
  end
  if f.flyAt and now>=f.flyAt then
   local player=f.dust and f.dust.owner and Players:GetPlayerByUserId(f.dust.owner)
   local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
   local e=math.clamp((now-f.flyAt)/.36,0,1)
   if not root or not root:IsA('BasePart') or e>=1 then self:dropShard(f);table.remove(self.frags,i);continue end
   local pos=f.flyFrom:Lerp(root.Position,e*e)+Vector3.yAxis*math.sin(e*math.pi)*1.6
   local spin=(f.base and f.base.Rotation or CFrame.fromAxisAngle(f.axis,f.turn))*CFrame.Angles(e*4,0,0)
   frame=CFrame.new(pos)*spin
   k=(f.flyK or f.k)*(1-.7*e)
  else
   local age
   if f.settled then
    frame=f.base;age=now-f.settledAt
   elseif t>0 then
    local q=math.clamp(t/f.T,0,1)
    -- A small jolt up as it cracks free, then it is pushed down and tips over.
    local pos=f.from:Lerp(f.land,q*q)+Vector3.yAxis*(f.hop*4*q*(1-q)*(1-q))
    frame=CFrame.new(pos)*CFrame.fromAxisAngle(f.axis,f.turn*(1-(1-q)^2))
    age=t-f.T-f.wait
   else
    frame=CFrame.new(f.from);age=-1
   end
   if f.keeper and f.dust and not f.dust.goneAt then
    -- The pebble left to collect.
    k=f.k*(1-.55*math.clamp(age/SHARD_FADE,0,1))
   elseif age>0 then
    local fade=math.clamp(age/SHARD_FADE,0,1)
    k=f.k*(1-.75*fade);clear=fade*fade
    if fade>=1 then self:dropShard(f);table.remove(self.frags,i);continue end
   end
  end
  f.pos=frame.Position
  local resize=k~=f.scale
  f.scale=k
  for _,q in ipairs(f.parts) do
   if resize then q.part.Size=q.size*k end
   if clear~=f.clear then q.part.Transparency=clear end
   q.part.CFrame=frame*(q.rel.Rotation+q.rel.Position*k)
  end
  f.clear=clear
 end
end

-- A break plays the field rocks' whole break, in the same order:
--  * a frame pause first (your own breaks only): the piece flashes hot and
--    holds for a few frames before anything moves (ImpactFreeze held a field
--    rock one or two frames; held a little longer here so it is felt)
--  * then, together: split, impact and tink sounds; the combo counter and
--    camera hit; eight spark streaks and embers; the ground shock ring; the
--    break particle burst; eight tumbling pieces that tink as they land; the
--    pop. The shards (the real rock) stand in for the two opening halves.
-- A piece that breaks before the last is the old crack beat (seam burst):
-- chips, two sparks, a lighter particle burst and the small ring.
local HOLD_PIECE,HOLD_SPLIT,HOLD_HEAVY=2/60,3/60,5/60
local FLASH=Color3.fromRGB(255,249,216)
local FLASH_FADE=.2
-- Every break lights the whole segment that is coming out in the color of
-- the drone that cut it (white-hot if unknown), so it is clear exactly what
-- is being removed; it holds through the frame pause, then fades over the
-- rubble.
function V:flash(op: any,now: number,holdUntil: number,color: Color3)
 local o=self.origin
 local parts={}
 for n,id in ipairs(op.cells) do
  if n>10 then break end
  local c=self.cube.cells[id]
  for _,w in ipairs(DigCube.polyWedges(DigCube.grown(c.poly,.06),c.y0+.02,c.y1+.08)) do
   local part=fxPart(self.fx,'DigBreakFlash',color,'WedgePart');part.Transparency=.12
   part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
   part.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
   table.insert(parts,part)
  end
 end
 table.insert(self.flashes,{parts=parts,holdUntil=holdUntil,untilAt=holdUntil+FLASH_FADE})
end
function V:stepHolds(now: number)
 for i=#self.flashes,1,-1 do
  local f=self.flashes[i]
  if now>=f.untilAt then
   for _,part in ipairs(f.parts) do part:Destroy() end
   table.remove(self.flashes,i)
  elseif now>f.holdUntil then
   local fade=(now-f.holdUntil)/FLASH_FADE
   for _,part in ipairs(f.parts) do part.Transparency=.12+.88*fade*fade end
  end
 end
 for i=#self.pending,1,-1 do
  local e=self.pending[i]
  if now>=e.at then table.remove(self.pending,i);e.run() end
 end
end
-- Stage cracks, the way the reference rocks do it: no drawn lines. A Mining
-- Away rock darkens while the laser works on it, then cracks: it shrinks a
-- step and turns, and its color comes back. Here the piece about to break is
-- drawn as its own prisms over the rock. It darkens with damage, and at each
-- crack stage (a third and two thirds of its share of the work) it pops
-- loose: it lifts out of the rock, tilts and turns a little further each
-- time, casting a real shadow, its color snaps back, and the crack plays with
-- chips and dust. Then it breaks off as before.
local CRACK_STEPS=3 -- per piece: two crack stages, then it breaks off
local CRACK_SHADE=.34 -- darkest just before a crack (the reference's shade curve)
local CRACK_LIFT={0,.28,.62} -- studs out of the rock at each stage
local CRACK_TURN={0,.06,.13} -- radians of turn at each stage
local CRACK_TIP={0,.025,.055} -- radians of tilt at each stage
local CRACK_JOLT=.2 -- seconds of the pop and settle
local BLACK=Color3.new(0,0,0)
function V:crackIndex(job: any,progress: number): (number,number)
 local prev=0
 for k,piece in ipairs(job.pieces) do
  if progress<piece.at then
   local f=(progress-prev)/math.max(piece.at-prev,1e-6)
   local s=math.clamp(math.floor(f*CRACK_STEPS),0,CRACK_STEPS-1)
   return (k-1)*CRACK_STEPS+s,f*CRACK_STEPS-s
  end
  prev=piece.at
 end
 return #job.pieces*CRACK_STEPS,0
end
function V:dropProxy(proxy: any)
 if proxy.dead then return end
 proxy.dead=true
 for _,e in ipairs(proxy.parts) do e.part:Destroy() end
 for _,id in ipairs(proxy.ids) do if self.crackCells[id]==proxy then self.crackCells[id]=nil end end
end
function V:clearCrack(id: number)
 local proxy=self.crackCells[id]
 if proxy then self:dropProxy(proxy) end
end
function V:clearCracks()
 for _,job in pairs(self.cracks) do if job.proxy then self:dropProxy(job.proxy) end end
 self.cracks={};self.crackCells={}
end
-- The piece as its own prisms, slightly grown so they cover the carved rock.
function V:buildProxy(piece: any): any?
 local cube=self.cube;local o=self.origin
 local parts,ids={},{}
 local area,sx,sz,top=0,0,0,-math.huge
 for _,id in ipairs(piece.ids) do
  local c=cube.cells[id]
  if c and not cube.removed[id] and not self.crackCells[id] then
   table.insert(ids,id)
   area+=c.area;sx+=c.cx*c.area;sz+=c.cz*c.area;top=math.max(top,c.y1)
   local stone=self:colorAt(c.y1-.01,c.cx,c.cz)
   for _,w in ipairs(DigCube.polyWedges(DigCube.grown(c.poly,.03),c.y0+.02,c.y1+.03)) do
    local part=fxPart(self.fx,'DigCrack',stone,'WedgePart')
    part.CastShadow=true
    part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
    part.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
     Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
    table.insert(parts,{part=part,stone=stone})
   end
  end
 end
 if area<=0 then return nil end
 local pivot=o+Vector3.new(sx/area,top,sz/area)
 for _,e in ipairs(parts) do e.base=CFrame.new(pivot):ToObjectSpace(e.part.CFrame) end
 local proxy={parts=parts,ids=ids,pivot=pivot,step=0,shade=0,joltAt=-10,
  turn=self.random:NextNumber(.7,1)*(self.random:NextInteger(0,1)*2-1),tipAxis=self.random:NextNumber(0,math.pi*2)}
 for _,id in ipairs(ids) do self.crackCells[id]=proxy end
 return proxy
end
-- Where the piece sits at its current stage (plus the pop after a crack).
function V:poseProxy(proxy: any,now: number)
 local s=proxy.step+1
 local t=(now-proxy.joltAt)/CRACK_JOLT
 local pop=t<1 and .32*math.sin(math.pi*math.clamp(t,0,1))*(1-t*.5) or 0
 local tip=CRACK_TIP[s]
 local pose=CFrame.new(proxy.pivot+Vector3.yAxis*(CRACK_LIFT[s]+pop))
  *CFrame.Angles(0,CRACK_TURN[s]*proxy.turn,0)
  *CFrame.Angles(math.cos(proxy.tipAxis)*tip,0,math.sin(proxy.tipAxis)*tip)
 for _,e in ipairs(proxy.parts) do e.part.CFrame=pose*e.base end
end
function V:shadeProxy(proxy: any,shade: number)
 if math.abs(shade-proxy.shade)<.01 then return end
 proxy.shade=shade
 for _,e in ipairs(proxy.parts) do e.part.Color=e.stone:Lerp(BLACK,shade) end
end
-- Called every frame per cutting drone with its chunk's progress.
function V:crackStage(key: string,progress: number,now: number,tint: Color3,owned: boolean)
 local job=self.cracks[key]
 if not job then
  job={pieces=DigCube.pieces(self.cube,DigCube.parseKey(string.sub(key,2)))}
  self.cracks[key]=job
  -- A chunk already part-cut when first seen starts at its stage, without the hit.
  job.stage=self:crackIndex(job,progress)
 end
 job.seen=now
 local index,within=self:crackIndex(job,progress)
 local k=math.floor(index/CRACK_STEPS)+1
 local step=index%CRACK_STEPS
 local piece=job.pieces[k]
 if not piece then return end
 if job.proxy and (job.proxy.dead or job.piece~=k) then
  if not job.proxy.dead then self:dropProxy(job.proxy) end
  job.proxy=nil
 end
 if not job.proxy and progress>0 then
  job.proxy=self:buildProxy(piece);job.piece=k
  if job.proxy then job.proxy.step=step;self:poseProxy(job.proxy,now) end
 end
 local proxy=job.proxy
 if not proxy then return end
 -- Darker as the beam works, back to full color at each crack.
 self:shadeProxy(proxy,CRACK_SHADE*math.clamp(within,0,1)^.88)
 if index>job.stage then
  job.stage=index
  if step>0 and step~=proxy.step then
   proxy.step=step;proxy.joltAt=now
   self:crackHit(proxy,step,k,{tint=tint,owned=owned})
  end
 end
 self:poseProxy(proxy,now)
end
function V:crackHit(proxy: any,step: number,k: number,hit: any)
 local point=proxy.pivot+Vector3.yAxis*(CRACK_LIFT[step+1]+.1)
 local stone=proxy.parts[1] and proxy.parts[1].stone or STONE_LIGHT
 local volume=hit.owned and 1 or .55
 local ctx=self.ctx
 if ctx.crack then ctx.crack:playCrack(point) end
 if ctx.audio then
  ctx.audio:play('crystal_impact',point,{pitch=.72+.09*step+.04*k+self.random:NextNumber(-.03,.03),level=volume*(.32+.14*step)})
 end
 if self:reduced() then return end
 local serverNow=workspace:GetServerTimeNow()
 local rock=self.holder and self.holder:FindFirstChild('Rock')
 local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
 if ctx.impact and surface then ctx.impact:chips(serverNow,point,Vector3.yAxis,surface,2+2*step,point.Y-4) end
 self:puff(point,stone,.5+.2*step,1+step)
 if ctx.effects then ctx.effects.Pulse(point,hit.tint:Lerp(BEAM_CORE,.35),.22,1.6+.9*step,.2,Vector3.yAxis,.78) end
 if hit.owned and ctx.beat then ctx.beat('Split',point,serverNow,.18+.1*step) end
end
function V:stepCracks(now: number)
 for key,job in pairs(self.cracks) do
  if now-(job.seen or now)>2 then
   self.cracks[key]=nil
   if job.proxy then self:dropProxy(job.proxy) end
  elseif job.proxy and not job.proxy.dead and now-job.proxy.joltAt<CRACK_JOLT then
   self:poseProxy(job.proxy,now)
  end
 end
end
function V:split(op: any,now: number)
 local cube=self.cube;local o=self.origin
 local first=cube.cells[op.cells[1]]
 if not first then return end
 local _,cx,cz=DigCube.chunkArea(cube,op.cells)
 local bulk=DigCube.volume(cube,op.cells)^(1/3)
 local center=o+Vector3.new(cx,(first.y0+first.y1)*.5,cz)
 local owned,beam=false,nil
 for _,id in ipairs(op.cells) do
  self:clearCrack(id)
  if self.mine[id] then owned=true;self.mine[id]=nil end
  beam=beam or self.cellColor[id];self.cellColor[id]=nil
 end
 local strength=math.clamp(bulk*.36,.9,2.45)
 local heavy=owned and strength>=1.35
 local hold=0
 if owned and not self:reduced() and now-(self.heldAt or -10)>=(op.partial and .9 or .3) then
  hold=op.partial and HOLD_PIECE or heavy and HOLD_HEAVY or HOLD_SPLIT
  self.heldAt=now
 end
 self:flash(op,now,now+hold+.04,beam and beam:Lerp(FLASH,.3) or FLASH)
 self:shards(op,now+hold,center)
 local info={center=center,point=o+Vector3.new(cx,first.y1,cz),ground=o.Y+first.y0,bulk=bulk,strength=strength,owned=owned,heavy=heavy,
  color=self:colorAt(first.y1-.01,cx,cz),beam=beam}
 if hold>0 then table.insert(self.pending,{at=now+hold,run=function() self:burst(op,info) end})
 else self:burst(op,info) end
end
-- The break's own particles, bigger and longer-lived than the shared
-- cocktail, emitted from the whole volume of the rock that broke (a box the
-- size of the piece), so they come from exactly where it broke: chunky
-- debris in the rock's tone, a dust cloud that hangs and drifts, bright
-- sparks in the beam's color and slow glitter that lingers.
local SQUARE='rbxasset://textures/particles/SquareParticle.png'
function V:breakCloud(op: any,e: any,big: boolean)
 if self:reduced() or (self.clouds or 0)>=8 then return end
 local cube=self.cube;local o=self.origin
 local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,id in ipairs(op.cells) do
  local c=cube.cells[id]
  if c then
   lo=Vector3.new(math.min(lo.X,c.minX),math.min(lo.Y,c.y0),math.min(lo.Z,c.minZ))
   hi=Vector3.new(math.max(hi.X,c.maxX),math.max(hi.Y,c.y1),math.max(hi.Z,c.maxZ))
  end
 end
 if lo.X>hi.X then return end
 local box=fxPart(self.fx,'DigBreakCloud',e.color);box.Transparency=1
 box.Size=Vector3.new(math.max(.5,hi.X-lo.X),math.max(.5,hi.Y-lo.Y),math.max(.5,hi.Z-lo.Z))
 box.Position=o+(lo+hi)*.5
 self.clouds=(self.clouds or 0)+1
 box.Destroying:Connect(function() self.clouds-=1 end)
 local k=big and 1 or .65
 local bulk=math.clamp(e.bulk,1.5,5)
 local function emitter(name: string): ParticleEmitter
  local p=Instance.new('ParticleEmitter');p.Name=name;p.Enabled=false;p.Rate=0
  p.Shape=Enum.ParticleEmitterShape.Box;p.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
  p.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward;p.LockedToPart=false
  p.Parent=box
  return p
 end
 -- Debris: chunky square bits in the rock's tone, thrown up and falling.
 local debris=emitter('Debris');debris.Texture=SQUARE
 debris.Color=ColorSequence.new(e.color:Lerp(SHARD_DARK,.25),e.color:Lerp(SHARD_DARK,.45))
 debris.LightEmission=0;debris.LightInfluence=1;debris.Brightness=1.2
 debris.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.55*k,.2),NumberSequenceKeypoint.new(.8,.45*k,.15),NumberSequenceKeypoint.new(1,0)})
 debris.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.75,0),NumberSequenceKeypoint.new(1,1)})
 debris.Lifetime=NumberRange.new(.9,1.6);debris.Speed=NumberRange.new(10,22);debris.SpreadAngle=Vector2.new(55,55)
 debris.EmissionDirection=Enum.NormalId.Top;debris.Acceleration=Vector3.new(0,-48,0);debris.Drag=.6
 debris.Rotation=NumberRange.new(0,360);debris.RotSpeed=NumberRange.new(-260,260)
 debris:Emit(math.floor((10+6*bulk)*k))
 -- Dust: a few small puffs in the rock's own tone that hang a moment. Kept
 -- small and not lightened: big pale clouds washed over the whole dig.
 local dust=emitter('Dust')
 EnergyDisc.configure(dust,(1+.2*bulk)*k,.5,.5,1.5,.3)
 dust.LightEmission=0;dust.LightInfluence=1;dust.Brightness=1
 dust.Color=ColorSequence.new(e.color:Lerp(SHARD_DARK,.15))
 dust.Lifetime=NumberRange.new(1,1.6);dust.Speed=NumberRange.new(2,5);dust.SpreadAngle=Vector2.new(70,70)
 dust.EmissionDirection=Enum.NormalId.Top;dust.Acceleration=Vector3.new(0,1,0);dust.Drag=2.4
 dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(.6,.6),NumberSequenceKeypoint.new(1,1)})
 dust:Emit(math.floor((3+bulk)*k))
 -- Sparks in the beam's color: bright, quick, they carry the glow.
 local sparks=emitter('Sparks')
 EnergyDisc.configure(sparks,.75*k,.05,1,0,.35)
 sparks.LightEmission=1;sparks.LightInfluence=0;sparks.Brightness=2.2
 sparks.Color=ColorSequence.new(e.beam:Lerp(BEAM_CORE,.35),e.beam)
 sparks.Lifetime=NumberRange.new(.45,.9);sparks.Speed=NumberRange.new(14,28);sparks.SpreadAngle=Vector2.new(70,70)
 sparks.EmissionDirection=Enum.NormalId.Top;sparks.Acceleration=Vector3.new(0,-30,0);sparks.Drag=1.5
 sparks:Emit(math.floor((10+4*bulk)*k))
 -- Glitter that lingers: slow falling bright flecks, the last thing to go.
 local glitter=emitter('Glitter')
 EnergyDisc.configure(glitter,.32*k,.1,1,.4,.4)
 glitter.LightEmission=.8;glitter.LightInfluence=0;glitter.Brightness=1.8
 glitter.Color=ColorSequence.new(e.beam:Lerp(BEAM_CORE,.6),e.color:Lerp(BEAM_CORE,.5))
 glitter.Lifetime=NumberRange.new(2.2,3.4);glitter.Speed=NumberRange.new(3,8);glitter.SpreadAngle=Vector2.new(85,85)
 glitter.EmissionDirection=Enum.NormalId.Top;glitter.Acceleration=Vector3.new(0,-2.2,0);glitter.Drag=2.6
 glitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.8,.25),NumberSequenceKeypoint.new(1,1)})
 glitter:Emit(math.floor((8+3*bulk)*k))
 task.delay(3.6,function() box:Destroy() end)
end
function V:burst(op: any,e: any)
 local ctx=self.ctx
 local now=workspace:GetServerTimeNow()
 local point,ground,strength=e.point,e.ground,e.strength
 local volume=e.owned and 1 or .62
 -- Particles much lighter than the rock: in the rock's own color the burst
 -- disappears against the pit. Pieces are darker, like the shards. Some of
 -- the sparks take the color of the drone's beam.
 local vivid=e.color:Lerp(Color3.fromRGB(255,246,226),.62)
 local dark=e.color:Lerp(SHARD_DARK,.4)
 local beam=e.beam or vivid
 local lively=not self:reduced()
 local rock=self.holder and self.holder:FindFirstChild('Rock')
 local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
 if op.partial then
  -- Each piece of a chunk cracks a step higher, building to the full split.
  self:breakCloud(op,{color=vivid,beam=beam,bulk=e.bulk},false)
  if ctx.audio then
   ctx.audio:play('crystal_impact',point,{pitch=.88+.14*(op.stage or 1)+self.random:NextNumber(-.03,.03),level=volume*.9,rockSize=e.bulk})
   ctx.audio:play('crystal_release_tink',point,{level=volume*.5,pitch=1+.1*(op.stage or 1)})
  end
  if lively then
   if ctx.impact then
    if surface then ctx.impact:chips(now,point,Vector3.yAxis,surface,4,ground) end
    ctx.impact:fireworks(point,ground,vivid,strength*2.2,now,4)
    ctx.impact:fireworks(point,ground,beam,strength*2.2,now,4)
   end
   if ctx.effects then
    ctx.effects.ImpactParticles(point,vivid,strength*1.5,'CrystalBreak',nil,vivid,nil,.8)
    ctx.effects.ImpactParticles(point,beam,strength*1.2,'CrystalBreak',nil,beam,nil,.5)
    ctx.effects.Pulse(point+Vector3.yAxis*.1,beam,.3,2.6*strength,.24,Vector3.yAxis,.78)
   end
   if ctx.beat then ctx.beat('Split',point,now,.55*volume) end
  end
  return
 end
 if ctx.audio then
  ctx.audio:play('crystal_split',point,{level=volume,rockSize=e.bulk})
  ctx.audio:play('crystal_impact',point,{level=volume*math.clamp(strength,.9,1.25)})
  ctx.audio:play('crystal_release_tink',point,{level=volume})
 end
 -- A gem bursts out with the rock, not after it.
 if op.tier>0 then self:reveal({tier=op.tier,treasure=op.treasure,center=e.center+Vector3.yAxis*1.2,ground=ground,size=e.bulk},os.clock()) end
 if not lively then return end
 self:breakCloud(op,{color=vivid,beam=beam,bulk=e.bulk},true)
 -- Combo counter and the camera hit, shared with the field rocks.
 if ctx.splitBeat then ctx.splitBeat(point,strength,now,false,e.owned,nil)
 elseif ctx.beat then ctx.beat(e.heavy and 'HeavySplit' or 'Split',point,now,math.clamp(strength*.58,.6,1.35)*volume) end
 if ctx.impact then
  ctx.impact:fireworks(point,ground,vivid,strength*2.4,now,8)
  ctx.impact:fireworks(point,ground,beam,strength*2.4,now,7)
  ctx.impact:breakPieces(point,ground,dark,strength,now,e.owned,surface and surface.Material or nil)
 end
 if ctx.effects then
  ctx.effects.Pulse(Vector3.new(point.X,ground+.085,point.Z),vivid,strength*.55,strength*6.6,.58)
  ctx.effects.ImpactParticles(point,vivid,strength*1.5,'CrystalBreak',nil,vivid,nil,1.3)
  ctx.effects.ImpactParticles(point,beam,strength*1.2,'CrystalBreak',nil,beam,nil,.8)
 end
end

-- A gem: a burst of particles in its own color on top of the rock break.
function V:reveal(e: any,now: number)
 local ctx=self.ctx
 local color=rgb(DigCube.ORES[e.tier].color)
 local light=color:Lerp(Color3.new(1,1,1),.4)
 local serverNow=workspace:GetServerTimeNow()
 if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1+e.tier*.08,level=1}) end
 if not self:reduced() then
  local k=1+e.tier*.2
  if ctx.effects then
   ctx.effects.ImpactParticles(e.center,color,k,'GemReward')
   ctx.effects.ImpactParticles(e.center,light,k*1.1,'CrystalBreak',nil,color)
   ctx.effects.Pulse(Vector3.new(e.center.X,e.ground+.1,e.center.Z),color,.6,4+e.tier*1.8,.55)
   ctx.effects.Pulse(e.center,light,.4,2.5+e.tier,.35)
   task.delay(.09,function() ctx.effects.ImpactParticles(e.center+Vector3.yAxis*.6,light,k,'GemReward') end)
  end
  if ctx.impact then
   ctx.impact:fireworks(e.center,e.ground,color,1.3+e.tier*.15,serverNow,8)
   ctx.impact:fireworks(e.center,e.ground,light,1.1+e.tier*.1,serverNow,6)
  end
  self:puff(e.center,color,1.2,14)
  if ctx.beat then ctx.beat(e.tier>=3 and 'HeavySplit' or 'Split',e.center,serverNow,math.min(1.2,.6+e.tier*.12)) end
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

-- Digging beams are drawn by the field mining beam (Presentation), so they
-- charge up and start like every other drone's: beamTarget hands it a
-- hidden landing plate at the drone's cut. This view adds, where the beam
-- touches the rock, sparks in the beam's own color, rock chips and a small
-- ring; and under every drone over the cube a red targeting line, straight
-- down along its beam, ending in a soft dot that tightens and brightens
-- while the drone charges and pulses while it cuts.
local SIGHT=Color3.fromRGB(255,56,72)
local SIGHT_HOT=Color3.fromRGB(255,170,176)
local DOT='rbxasset://textures/ui/VR/circleWhite.png'
local SIGHT_FADE=NumberSequence.new({NumberSequenceKeypoint.new(0,.92),NumberSequenceKeypoint.new(.45,.5),NumberSequenceKeypoint.new(1,.12)})
local SIGHT_GLOW=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.88),NumberSequenceKeypoint.new(1,.7)})
function V:beamTarget(source: Instance): BasePart?
 local id=source:GetAttribute('DroneId')
 local key=source:GetAttribute('DigOp');local point=source:GetAttribute('DigPoint')
 local beam=type(id)=='string' and self.beams[id]
 if not beam or not self.cube or type(key)~='string' or key=='' or typeof(point)~='Vector3' then
  if beam and beam.plate then beam.plate.Transparency=1 end
  return nil
 end
 if not beam.plate then
  local plate=fxPart(self.fx,'DigBeamTarget',SIGHT);plate.Size=Vector3.new(4,.1,4)
  beam.plate=plate
 end
 beam.plate.Transparency=.995
 beam.plate.CFrame=CFrame.new(point+Vector3.yAxis*.05)
 beam.plateAt=os.clock()
 return beam.plate
end
function V:newBeam(color: Color3,mine: boolean)
 local root=fxPart(self.fx,'DigSight',SIGHT);root.Transparency=1;root.Size=Vector3.one*.05
 local a=Instance.new('Attachment');a.Name='From';a.Parent=root
 local b=Instance.new('Attachment');b.Name='To';b.Parent=root
 local function line(name: string,width: number,fade: NumberSequence)
  local r=Instance.new('Beam');r.Name=name;r.Attachment0=a;r.Attachment1=b;r.FaceCamera=true;r.Segments=1
  r.Width0=width*.7;r.Width1=width;r.Color=ColorSequence.new(SIGHT,SIGHT_HOT);r.Transparency=fade
  r.LightEmission=1;r.LightInfluence=0;r.Brightness=1.4;r.Enabled=false;r.Parent=root
  return r
 end
 local core=line('SightLine',mine and .07 or .05,SIGHT_FADE)
 local glow=line('SightGlow',mine and .3 or .2,SIGHT_GLOW)
 local gui=Instance.new('BillboardGui');gui.Name='SightDot';gui.Adornee=root;gui.LightInfluence=0
 gui.Size=UDim2.new(1,0,1,0);gui.MaxDistance=120;gui.Enabled=false;gui.Parent=root
 local halo=Instance.new('ImageLabel');halo.BackgroundTransparency=1;halo.Image=DOT;halo.ImageColor3=SIGHT
 halo.ImageTransparency=.72;halo.AnchorPoint=Vector2.new(.5,.5);halo.Position=UDim2.fromScale(.5,.5);halo.Size=UDim2.fromScale(1,1);halo.Parent=gui
 local dot=Instance.new('ImageLabel');dot.BackgroundTransparency=1;dot.Image=DOT;dot.ImageColor3=SIGHT_HOT
 dot.ImageTransparency=.05;dot.AnchorPoint=Vector2.new(.5,.5);dot.Position=UDim2.fromScale(.5,.5);dot.Size=UDim2.fromScale(.32,.32);dot.Parent=gui
 local sparks=Instance.new('ParticleEmitter');sparks.Name='Contact'
 EnergyDisc.configure(sparks,.3,.05,1,0,.35)
 sparks.LightEmission=.6;sparks.LightInfluence=0;sparks.Brightness=1.4
 sparks.Color=ColorSequence.new(color:Lerp(BEAM_CORE,.3),color)
 sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(65,65)
 sparks.Speed=NumberRange.new(6,13);sparks.Lifetime=NumberRange.new(.2,.42);sparks.Drag=2
 sparks.Acceleration=Vector3.new(0,-26,0);sparks.Rate=mine and 30 or 12;sparks.Enabled=false;sparks.Parent=b
 return {root=root,a=a,b=b,core=core,glow=glow,gui=gui,halo=halo,dot=dot,sparks=sparks,mine=mine,tint=color,on=false}
end
function V:hideBeam(beam: any)
 if not beam.on then return end
 beam.on=false;beam.core.Enabled=false;beam.glow.Enabled=false;beam.gui.Enabled=false;beam.sparks.Enabled=false
end
function V:droneBeam(source: Instance,from: Vector3,now: number,color: Color3?)
 local id=source:GetAttribute('DroneId')
 if type(id)~='string' or not self.cube then return end
 local tint=color or HOT
 local beam=self.beams[id]
 if not beam then
  local player=Players.LocalPlayer
  beam=self:newBeam(tint,player~=nil and source:GetAttribute('Owner')==player.UserId)
  self.beams[id]=beam
 end
 beam.seen=os.clock() -- the step functions run on os.clock; `now` here is server time
 if beam.tint~=tint then beam.tint=tint;beam.sparks.Color=ColorSequence.new(tint:Lerp(BEAM_CORE,.3),tint) end
 local key=source:GetAttribute('DigOp')
 -- Remember which cells each drone is cutting (and the beam's color), and
 -- which are this player's own: their breaks get the pause and the combo.
 if type(key)=='string' and key~='' and beam.key~=key then
  beam.key=key
  for _,cell in ipairs(DigCube.parseKey(string.sub(key,2))) do
   self.cellColor[cell]=tint
   if beam.mine then self.mine[cell]=true end
  end
 end
 -- Stage cracks on the chunk this drone is cutting.
 if type(key)=='string' and key~='' and (source:GetAttribute('HP') or 1)>0 then
  self:crackStage(key,source:GetAttribute('DigProgress') or 0,os.clock(),tint,beam.mine)
 end
 -- Only over the cube, alive and not in a menu pause.
 local l=from-self.origin
 local W=self.cube.width
 local alive=(source:GetAttribute('HP') or 1)>0 and source:GetAttribute('State')~='Destroyed' and source:GetAttribute('WorkPaused')~=true
 if not alive or l.X<-3 or l.X>W+3 or l.Z<-3 or l.Z>W+3 or l.Y<-2 then self:hideBeam(beam);return end
 -- Straight down, like the beam: where it would cut.
 if now>=(beam.rayAt or 0) or not beam.tip then
  beam.rayAt=now+.06
  local rock=self.holder and self.holder:FindFirstChild('Rock')
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=rock and {rock} or {}
  local hit=rock and workspace:Raycast(from,Vector3.new(0,-(l.Y+6),0),params)
  beam.tip=hit and hit.Position or Vector3.new(from.X,self.origin.Y,from.Z)
 end
 local tip=Vector3.new(from.X,beam.tip.Y,from.Z)
 if from.Y-tip.Y<.4 then self:hideBeam(beam);return end
 local state=source:GetAttribute('State')
 local cutting=type(key)=='string' and key~='' and source:GetAttribute('DigMining')==true
 local charging=type(key)=='string' and key~='' and state=='Warmup'
 if not beam.on then beam.on=true end
 -- The red targeting laser shows only while the drone charges, right before
 -- it fires; then the real beam takes its place.
 local aiming=charging and not cutting
 if beam.core.Enabled~=aiming then beam.core.Enabled=aiming;beam.glow.Enabled=aiming;beam.gui.Enabled=aiming end
 beam.root.CFrame=CFrame.new(tip+Vector3.yAxis*.05)
 beam.a.Position=from-tip
 local locked=type(key)=='string' and key~=''
 local size,core,halo
 if cutting then
  local pulse=.5+.5*math.sin(now*14)
  size=.9+.15*pulse;core=.0;halo=.6-.15*pulse
 elseif charging then
  local start=source:GetAttribute('WarmupStart') or 0
  local length=math.max(.05,source:GetAttribute('WarmupDuration') or .8)
  local q=math.clamp((workspace:GetServerTimeNow()-start)/length,0,1)
  size=1.5-.7*q;core=.35-.33*q;halo=.85-.3*q
 elseif locked then
  size=1.1;core=.2;halo=.75
 else
  size=.7;core=.45;halo=.88
 end
 beam.gui.Size=UDim2.new(size,0,size,0);beam.dot.ImageTransparency=core;beam.halo.ImageTransparency=halo
 beam.core.Transparency=locked and SIGHT_FADE or SIGHT_GLOW
 -- Where the beam touches the rock: beam-colored sparks, chips, a ring.
 local sparking=cutting and not self:reduced()
 if beam.sparks.Enabled~=sparking then beam.sparks.Enabled=sparking end
 if cutting and now>=(beam.chipAt or 0) and not self:reduced() then
  beam.chipAt=now+.23+(now%.07)
  local serverNow=workspace:GetServerTimeNow()
  local rock=self.holder and self.holder:FindFirstChild('Rock')
  local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
  if self.ctx.impact and surface then self.ctx.impact:chips(serverNow,tip,Vector3.yAxis,surface,1,tip.Y-4) end
  if self.ctx.effects and now>=(beam.pulseAt or 0) then
   beam.pulseAt=now+.45
   self.ctx.effects.Pulse(tip+Vector3.yAxis*.1,tint:Lerp(BEAM_CORE,.4),.19,1.65,.18,Vector3.yAxis,.78)
  end
 end
end
function V:stepBeams(now: number)
 for id,beam in pairs(self.beams) do
  local idle=now-(beam.seen or 0)
  if idle>.3 then self:hideBeam(beam) end
  if beam.plate and now-(beam.plateAt or 0)>.3 then beam.plate.Transparency=1 end
  if idle>20 then beam.root:Destroy();if beam.plate then beam.plate:Destroy() end;self.beams[id]=nil end
 end
end

-- Rock to collect: the server leaves a (hidden) Dust part where a piece
-- broke and credits its owner when they are close. One pebble of that
-- piece's rubble marks it and flies to the owner when it is credited.
function V:addDust(part: Instance,live: boolean)
 if not part:IsA('BasePart') or self.dust[part] then return end
 local count=part:GetAttribute('Count') or 1
 local now=os.clock()
 local entry={part=part,owner=part:GetAttribute('Owner'),units=count,initial=count,frags={},born=live and now or now-10,flown=0,at=part.Position}
 if live then
  for _,f in ipairs(self.frags) do
   if not f.dust and now-f.born<.5 and Vector3.new(f.pos.X-entry.at.X,0,f.pos.Z-entry.at.Z).Magnitude<10 then
    self:claim(entry,f)
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
  local keeper=entry.keeper
  local collected=entry.units<entry.initial or (part:GetAttribute('CollectedAt') or 0)>0
  if collected and keeper and not keeper.dead and not keeper.flyAt then
   keeper.flyAt=now;keeper.flyFrom=keeper.pos;keeper.flyK=keeper.scale
  end
  if not part.Parent then
   -- Never collected: the pebble crumbles like the rest.
   if not entry.goneAt then
    entry.goneAt=now
    if keeper and not keeper.dead and not keeper.flyAt then keeper.at=math.min(keeper.at,now-keeper.T-keeper.wait) end
   end
   if now-entry.goneAt>3 then self.dust[part]=nil end
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
 self:stepHolds(now)
 self:stepCracks(now)
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
