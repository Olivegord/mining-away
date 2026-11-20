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
-- Nothing is drawn on the rock before it breaks (no target marks or crack
-- lines) and nothing here uses Neon.
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
 local self=setmetatable({ctx=ctx,beams={},splits={},frags={},banners={},dust={},puffs=0,mine={},flashes={},pending={},cube=nil,origin=Vector3.zero,
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
  self.frags={};self.mine={}
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

-- Rubble: the broken rock itself. Every cell of a broken piece is cracked
-- into many prisms cut from its own outline (its fan triangles, each split
-- again across its longest edge, then into an upper and a lower layer), so
-- for a moment the hole is filled with exactly the rock that was there,
-- cracked apart. The pieces are then pushed down: each one slumps to the
-- floor of the hole, tipping to a random orientation as it goes, rests a
-- beat, then shrinks and fades. The crack spreads outward from the middle of
-- the break. One small pebble per rock drop stays behind as the thing to
-- collect and flies to its owner when the server credits it.
local SHARD_FULL,SHARD_LAYERS,SHARD_COARSE=110,190,260 -- live pieces: detail steps down as these fill
local SHARD_DARK=Color3.fromRGB(46,38,36)
local SHARD_GAP=.93 -- pieces sit slightly apart, so the cracks between them show
local SHARD_FADE=.45
local function splitTriangle(tri: {{number}},t: number): ({{number}},{{number}})
 local best,longest=1,-1
 for k=1,3 do
  local a,b=tri[k],tri[k%3+1]
  local d=(a[1]-b[1])^2+(a[2]-b[2])^2
  if d>longest then best,longest=k,d end
 end
 local a,b,c=tri[best],tri[best%3+1],tri[(best+1)%3+1]
 local m={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t}
 return {a,m,c},{m,b,c}
end
function V:shards(op: any,now: number,center: Vector3)
 local o=self.origin;local cube=self.cube
 local made={}
 for _,id in ipairs(op.cells) do
  local c=cube.cells[id]
  local live=#self.frags
  if c and live<SHARD_COARSE then
   local poly=c.poly;local n=#poly
   local tris={}
   for k=2,n-1 do
    local tri={poly[1],poly[k],poly[k+1]}
    if live<SHARD_FULL then
     local left,right=splitTriangle(tri,self.random:NextNumber(.36,.64))
     table.insert(tris,left);table.insert(tris,right)
    else table.insert(tris,tri) end
   end
   local thick=c.y1-c.y0
   for _,tri in ipairs(tris) do
    local mx,mz=(tri[1][1]+tri[2][1]+tri[3][1])/3,(tri[1][2]+tri[2][2]+tri[3][2])/3
    local cut=live<SHARD_LAYERS and c.y0+thick*self.random:NextNumber(.38,.62) or nil
    local spans=cut and {{c.y0,cut},{cut,c.y1}} or {{c.y0,c.y1}}
    for _,span in ipairs(spans) do
     local mid=o+Vector3.new(mx,(span[1]+span[2])*.5,mz)
     -- The rock's own color, a little darker here and there so the pieces
     -- read as separate (and fresh-broken faces look deeper).
     local color=self:colorAt(c.y1-.01,mx,mz):Lerp(SHARD_DARK,self.random:NextNumber(.04,.3))
     local inverse=CFrame.new(mid):Inverse()
     local parts={}
     for _,w in ipairs(DigCube.polyWedges(tri,span[1],span[2])) do
      local part=fxPart(self.fx,'DigShard',color,'WedgePart');part.CastShadow=true
      local size=Vector3.new(w.size[1],w.size[2],w.size[3])
      local frame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
       Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
      table.insert(parts,{part=part,size=size,rel=inverse*frame})
     end
     if #parts>0 then
      local height=span[2]-span[1]
      local out=Vector3.new(mid.X-center.X,0,mid.Z-center.Z)
      local far=out.Magnitude
      local a=self.random:NextNumber(0,math.pi*2)
      out=far>.3 and out.Unit or Vector3.new(math.cos(a),0,math.sin(a))
      local axis=Vector3.new(self.random:NextNumber(-1,1),self.random:NextNumber(-.35,.35),self.random:NextNumber(-1,1))
      -- Pushed down to the floor of the hole, lying at whatever angle it lands.
      local rest=height*.5*SHARD_GAP*self.random:NextNumber(.45,.85)
      local landY=math.min(mid.Y,o.Y+c.y0+rest)
      local drop=mid.Y-landY
      local f={parts=parts,k=SHARD_GAP,scale=0,axis=axis.Magnitude>.05 and axis.Unit or Vector3.xAxis,
       turn=self.random:NextNumber(.5,2.4)*(self.random:NextNumber()<.5 and -1 or 1),
       from=mid,land=Vector3.new(mid.X,landY,mid.Z)+out*self.random:NextNumber(.1,.9),
       at=now+math.min(.14,far*.016)+self.random:NextNumber(0,.03),
       T=.24+math.sqrt(2*drop/GRAVITY)*1.15,hop=self.random:NextNumber(.35,.95),
       wait=self.random:NextNumber(.3,.7),born=now,pos=mid}
      table.insert(self.frags,f);table.insert(made,f)
     end
    end
   end
  end
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

function V:stepShards(now: number)
 for i=#self.frags,1,-1 do
  local f=self.frags[i]
  local t=now-f.at
  local pos=f.from
  local angle=0
  local k=f.k
  local clear=0
  if f.flyAt and now>=f.flyAt then
   local player=f.dust and f.dust.owner and Players:GetPlayerByUserId(f.dust.owner)
   local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
   local e=math.clamp((now-f.flyAt)/.36,0,1)
   if not root or not root:IsA('BasePart') or e>=1 then self:dropShard(f);table.remove(self.frags,i);continue end
   pos=f.flyFrom:Lerp(root.Position,e*e)+Vector3.yAxis*math.sin(e*math.pi)*1.6
   angle=f.turn+e*4
   k=(f.flyK or f.k)*(1-.7*e)
  elseif t>0 then
   local q=math.clamp(t/f.T,0,1)
   -- A small jolt up as it cracks free, then it is pushed down and tips over.
   pos=f.from:Lerp(f.land,q*q)+Vector3.yAxis*(f.hop*4*q*(1-q)*(1-q))
   angle=f.turn*(1-(1-q)^2)
   local age=t-f.T-f.wait
   if f.keeper and f.dust and not f.dust.goneAt then
    -- The pebble left to collect.
    k=f.k*(1-.55*math.clamp(age/SHARD_FADE,0,1))
   elseif age>0 then
    local fade=math.clamp(age/SHARD_FADE,0,1)
    k=f.k*(1-.75*fade);clear=fade*fade
    if fade>=1 then self:dropShard(f);table.remove(self.frags,i);continue end
   end
  end
  f.pos=pos
  local frame=CFrame.new(pos)*CFrame.fromAxisAngle(f.axis,angle)
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
function V:flash(op: any,untilAt: number)
 local o=self.origin
 local parts={}
 for n,id in ipairs(op.cells) do
  if n>6 then break end
  local c=self.cube.cells[id]
  for _,w in ipairs(DigCube.polyWedges(c.poly,c.y1+.04,c.y1+.12)) do
   local part=fxPart(self.fx,'DigBreakFlash',FLASH,'WedgePart');part.Transparency=.3
   part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
   part.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
   table.insert(parts,part)
  end
 end
 table.insert(self.flashes,{parts=parts,untilAt=untilAt})
end
function V:stepHolds(now: number)
 for i=#self.flashes,1,-1 do
  local f=self.flashes[i]
  if now>=f.untilAt then
   for _,part in ipairs(f.parts) do part:Destroy() end
   table.remove(self.flashes,i)
  end
 end
 for i=#self.pending,1,-1 do
  local e=self.pending[i]
  if now>=e.at then table.remove(self.pending,i);e.run() end
 end
end
function V:split(op: any,now: number)
 local cube=self.cube;local o=self.origin
 local first=cube.cells[op.cells[1]]
 if not first then return end
 local _,cx,cz=DigCube.chunkArea(cube,op.cells)
 local bulk=DigCube.volume(cube,op.cells)^(1/3)
 local center=o+Vector3.new(cx,(first.y0+first.y1)*.5,cz)
 local owned=false
 for _,id in ipairs(op.cells) do if self.mine[id] then owned=true;self.mine[id]=nil end end
 local strength=math.clamp(bulk*.36,.9,2.45)
 local heavy=owned and strength>=1.35
 local hold=0
 if owned and not self:reduced() and now-(self.heldAt or -10)>=(op.partial and .9 or .3) then
  hold=op.partial and HOLD_PIECE or heavy and HOLD_HEAVY or HOLD_SPLIT
  self.heldAt=now
  self:flash(op,now+hold)
 end
 self:shards(op,now+hold,center)
 local info={center=center,point=o+Vector3.new(cx,first.y1,cz),ground=o.Y+first.y0,bulk=bulk,strength=strength,owned=owned,heavy=heavy,
  color=self:colorAt(first.y1-.01,cx,cz)}
 if hold>0 then table.insert(self.pending,{at=now+hold,run=function() self:burst(op,info) end})
 else self:burst(op,info) end
 if not op.partial and op.tier>0 then
  table.insert(self.splits,{at=now+hold,tier=op.tier,treasure=op.treasure,center=center,size=bulk,revealed=false})
 end
end
function V:burst(op: any,e: any)
 local ctx=self.ctx
 local now=workspace:GetServerTimeNow()
 local point,ground,strength=e.point,e.ground,e.strength
 local volume=e.owned and 1 or .62
 -- Particles much lighter than the rock: in the rock's own color the burst
 -- disappears against the pit. Pieces are darker, like the shards.
 local vivid=e.color:Lerp(Color3.fromRGB(255,246,226),.62)
 local dark=e.color:Lerp(SHARD_DARK,.4)
 local lively=not self:reduced()
 local rock=self.holder and self.holder:FindFirstChild('Rock')
 local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
 if op.partial then
  -- Each piece of a chunk cracks a step higher, building to the full split.
  if ctx.audio then
   ctx.audio:play('crystal_impact',point,{pitch=.88+.14*(op.stage or 1)+self.random:NextNumber(-.03,.03),level=volume*.9,rockSize=e.bulk})
   ctx.audio:play('crystal_release_tink',point,{level=volume*.5,pitch=1+.1*(op.stage or 1)})
  end
  if lively then
   if ctx.impact then
    if surface then ctx.impact:chips(now,point,Vector3.yAxis,surface,4,ground) end
    ctx.impact:fireworks(point,ground,vivid,strength,now,3)
   end
   if ctx.effects then
    ctx.effects.ImpactParticles(point,vivid,strength,'CrystalBreak',nil,vivid,nil,.55)
    ctx.effects.Pulse(point+Vector3.yAxis*.1,vivid,.3,2.6*strength,.24,Vector3.yAxis,.78)
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
 if not lively then return end
 -- Combo counter and the camera hit, shared with the field rocks.
 if ctx.splitBeat then ctx.splitBeat(point,strength,now,false,e.owned,nil)
 elseif ctx.beat then ctx.beat(e.heavy and 'HeavySplit' or 'Split',point,now,math.clamp(strength*.58,.6,1.35)*volume) end
 if ctx.impact then
  ctx.impact:fireworks(point,ground,vivid,strength,now,8)
  ctx.impact:breakPieces(point,ground,dark,strength,now,e.owned,surface and surface.Material or nil)
 end
 if ctx.effects then
  ctx.effects.Pulse(Vector3.new(point.X,ground+.085,point.Z),vivid,strength*.55,strength*6.6,.58)
  ctx.effects.ImpactParticles(point,vivid,strength*.83,'CrystalBreak',nil,vivid)
 end
end

function V:reveal(e: any,now: number)
 e.revealed=true
 local ctx=self.ctx
 local color=rgb(DigCube.ORES[e.tier].color)
 if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1+e.tier*.08,level=1}) end
 if not self:reduced() then
  if ctx.effects then
   ctx.effects.ImpactParticles(e.center,color,1+e.tier*.2,'GemReward')
   ctx.effects.Pulse(e.center,color,.5,3+e.tier*1.6,.45)
  end
  if ctx.impact then ctx.impact:fireworks(e.center,e.center.Y-1.5,color,1.2+e.tier*.15,workspace:GetServerTimeNow(),6) end
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
local BEAM_BODY=NumberSequence.new({NumberSequenceKeypoint.new(0,.85),NumberSequenceKeypoint.new(.15,.55),NumberSequenceKeypoint.new(1,.42)})
local BEAM_CORE_FADE=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.15,.08),NumberSequenceKeypoint.new(1,0)})
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
  local body=ribbon('Body',mine and .6 or .36,tint,BEAM_BODY,.55)
  local core=ribbon('Core',mine and .18 or .1,tint:Lerp(BEAM_CORE,.7),mine and BEAM_CORE_FADE or BEAM_FAINT,.8)
  local sparks=Instance.new('ParticleEmitter');sparks.Name='Contact'
  EnergyDisc.configure(sparks,.3,.05,1,0,.35)
  sparks.LightEmission=.6;sparks.LightInfluence=0;sparks.Brightness=1.4
  sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(65,65)
  sparks.Speed=NumberRange.new(5,11);sparks.Lifetime=NumberRange.new(.18,.38);sparks.Drag=2
  sparks.Acceleration=Vector3.new(0,-26,0);sparks.Rate=mine and 26 or 10;sparks.Enabled=false;sparks.Parent=b
  -- The shared energy bloom gives beams and sparks their glow.
  local work=self.ctx.presentation and self.ctx.presentation.work
  if work and work.energyBloom then work:energyBloom() end
  beam={root=root,a=a,body=body,core=core,sparks=sparks,on=false,mine=mine}
  self.beams[id]=beam
 end
 -- Remember which cells this player's own drones are cutting: their breaks
 -- get the frame pause, full volume and the combo.
 if beam.mine and beam.key~=key then
  beam.key=key
  for _,cell in ipairs(DigCube.parseKey(string.sub(key,2))) do self.mine[cell]=true end
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
 -- The field rocks' contact feedback: chips knocked off where the beam
 -- hits and a small ring pulse on the surface.
 if now>=(beam.chipAt or 0) and not self:reduced() then
  beam.chipAt=now+.23+(now%.07)
  local serverNow=workspace:GetServerTimeNow()
  local rock=self.holder and self.holder:FindFirstChild('Rock')
  local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
  if self.ctx.impact and surface then self.ctx.impact:chips(serverNow,point,Vector3.yAxis,surface,1,point.Y-4) end
  if self.ctx.effects and now>=(beam.pulseAt or 0) then
   beam.pulseAt=now+.45
   self.ctx.effects.Pulse(point+Vector3.yAxis*.1,tint:Lerp(BEAM_CORE,.5),.19,1.65,.18,Vector3.yAxis,.78)
  end
 end
end
function V:stepBeams(now: number)
 for id,beam in pairs(self.beams) do
  local idle=now-(beam.seen or 0)
  if idle>.3 then self:hideBeam(beam) end
  if idle>20 then beam.root:Destroy();self.beams[id]=nil end
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
