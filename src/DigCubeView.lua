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
--  * a gem cell stays sealed (cracked, wiggling, glowing) until its owner
--    jumps on it; then it breaks with the gem burst. No on-screen text
--  * a dim lamp on the player down in the pit, the launch pad and tap-to-focus
--  * before each piece breaks it cracks in two stages, like the reference
--    rocks: it darkens under the beam, then pops loose (lifts, tilts, turns)
--    with its color back, a crack sound, chips and dust. No drawn lines
--  * every worker digs its own way (DigCube.STYLES): the op's role code picks
--    the piece's treatment while it is worked, its rubble and its break beat
--    (ROLE_FX below); the Lancer fires short pulse lasers (pulseShot)
-- Nothing here uses Neon.
local DigCube=require('./DigCube')
local RockChunks=require('./RockChunks')
RockChunks.wedges=DigCube.polyWedges
local ROCK,ROCK_VARIANT=DigCube.rockLook()
RockChunks.material=ROCK;RockChunks.variant=ROCK_VARIANT
local UIS=game:GetService('UserInputService')
local Players=game:GetService('Players')
local V={}
V.__index=V
local BEAM_CORE=Color3.fromRGB(255,250,235)
local HOT=Color3.fromRGB(222,128,62)
local GRAVITY=70

local function rgb(t: {number}) return Color3.fromRGB(t[1],t[2],t[3]) end

-- Statics shared with the client glue (Client.lua): a role's dig style and
-- its primary attack color (beam, projectile, flash, ring, belly glow).
V.PRIMARY={} :: {[string]:Color3}
function V.style(role: any): any
 return DigCube.style(type(role)=='string' and role or nil)
end
function V.primaryColor(role: any): Color3
 local style=V.style(role)
 local color=V.PRIMARY[style.code]
 if not color then color=rgb(style.color);V.PRIMARY[style.code]=color end
 return color
end

-- Per-role client treatment, by style code (spec §4.3, §4.4, §12):
--  proxy: the piece while it is worked. tone/cap: shade toward tone up to cap,
--   by `within` the crack step (default), the charge (src='progress') or its
--   last 30% (src='late'); slam/pulse: a jolt down on each hit; tremble,
--   jitter, vibrate: shakes; lift: extra rise with progress; ball: a growing
--   bubble; halves: the final piece slides apart; flat: no tilt or turn;
--   compress: shrinks toward the pivot; light: a heat glow; ice: Ice from there.
--  carve: historical (B, N, P, A carved ahead first); every role's piece is
--   carved ahead now, grown to cover the cut over a static collision copy.
--  mesh: what the RockChunks piece does (animated parts) (V:stepMesh): ripple={amp,len,speed
--   (negative runs inward),square,glow,beat} while a beam cuts; bulge; hits
--   (each jump in the work pops a chunk); charge (chunks pop from that share
--   of the charge on) and tremble. Slams and pulses ring and pop by kernel.
--  rubble: per/min/max pieces by area (or halves/grid), up/out/spin ranges,
--   dark base, near (darker by the hit), dcap, scorch tone, count (per break),
--   seed (thrown from the seed cell top) and the extras.
--  contact: the own-break contact (nil = the projectile/pulse effect carries
--   it); sounds; light; hold class; streak lift/speed multipliers.
local C3=Color3.fromRGB
local ROLE_FX={
 L={proxy={mesh={ripple={amp=.09,len=2.4,speed=4.5,glow=.55}}},
  rubble={per=2.2,min=1,max=6,up={10,15},out={4,8},spin={4,8},dark={.06,.2},near=.6,dcap=.85},
  contact='Striker',sounds='classic',light=true,hold='auto',lift=1,speed=1},
 C={proxy={tone=C3(90,72,58),cap=.4,slam=true,mesh={}},
  rubble={per=3.6,min=1,max=4,up={4,7},out={14,22},spin={2,4},dark={.06,.15},near=.3,dcap=.6,scorch=C3(118,108,91),friction=.3,pattern='ring'},
  contact='Charger',sounds={{cue='breaker_fracture',pitch=.9},{cue='crystal_split',rock=9}},light=true,hold='heavy',lift=.7,speed=1.3},
 B={proxy={tone=C3(25,12,45),cap=.55,src='progress',tremble=.03,mesh={charge=.25,tremble=.05}},carve=true,
  rubble={per=4,min=2,max=4,up={24,34},out={2,5},spin={10,18},dark={.3,.4},near=.6,dcap=.9,scorch=C3(38,18,58),pattern='column'},
  sounds={{cue='crystal_split',pitch=.9}},hold='split',lift=1.4,speed=1},
 N={proxy={cap=.15,mesh={hits=true}},carve=true,
  rubble={per=.9,min=2,max=6,up={0,2},out={0,1},spin={1,3},dark={.05,.1},near=.15,dcap=.3,pattern='crumble'},
  sounds={{cue='crystal_split',pitch=1.25,level=.7}},hold='piece',lift=1,speed=1},
 U={proxy={cap=.1,ball=true,mesh={ripple={amp=.07,len=3,speed=2.5,glow=.4},bulge=.3}},
  rubble={per=2.2,min=1,max=5,up={4,6},out={1,3},spin={2,4},dark={.02,.06},near=.1,dcap=.2,scorch=C3(200,240,245),float=.7},
  contact='Bubbler',sounds={{cue='crystal_split',pitch=.8}},light=true,hold='split',lift=1,speed=.8},
 H={proxy={halves=true,mesh={ripple={amp=.08,len=2,speed=5.5,glow=.5}}},
  rubble={halves=true,per=5,min=1,max=3,up={8,11},out={6,10},spin={3,5},dark={.06,.2},near=.6,dcap=.85},
  contact='Halver',sounds={{cue='crystal_split'}},light=true,hold='heavy',lift=.9,speed=1.1},
 G={proxy={flat=true,mesh={ripple={amp=.08,len=1.8,speed=4,square=true,glow=.6}}},
  rubble={grid=1.8,up={9,13},out={2,5},spin={1,3},dark={.1,.2},near=.3,dcap=.5,pattern='rows'},
  contact='Gridcutter',sounds={{cue='crystal_electric',pitch=.85,seq=.06}},light=true,hold='piece',lift=1,speed=1},
 Y={proxy={tone=C3(20,8,40),cap=.55,compress=.1,mesh={ripple={amp=.1,len=2.2,speed=-4.5,glow=.6}}},
  rubble={per=2.2,min=1,max=6,up={14,20},out={1,3},spin={6,10},dark={.2,.3},near=.6,dcap=.9,scorch=C3(20,8,32),implode=.12},
  contact='Singularity',sounds={{cue='crystal_impact',pitch=.76}},light=true,hold='heavy',lift=1.3,speed=.6},
 M={proxy={tone=C3(255,120,40),cap=0,pow=1.5,light=true,mesh={ripple={amp=.07,len=2.8,speed=3,glow=.85,beat=1.4}}},
  rubble={per=2.2,min=1,max=5,up={22,30},out={1,3},spin={2,4},dark={.06,.2},near=.6,dcap=.85,molten=C3(255,150,60),pattern='fountain'},
  contact='Starforge',sounds={{cue='tool_sizzle',pitch=.87}},light=true,hold='split',lift=.8,speed=1},
 I={proxy={tone=C3(190,235,255),cap=0,pow=1,mesh={ripple={amp=.06,len=2.6,speed=2.2,glow=.5,beat=1.2}}},
  rubble={per=.6,min=3,max=10,count=34,up={8,12},out={12,20},spin={14,24},dark={.3,.4},near=0,dcap=.4,scorch=C3(190,235,255),glass=true,friction=.05,pattern='shatter'},
  contact='Frostbite',sounds={{cue='crystal_snap',pitch=1.31},{cue='crystal_split',pitch=1.15}},light=true,hold='split',lift=1,speed=1.2},
 V={proxy={vibrate={.01,.09},mesh={ripple={amp=.12,len=1.6,speed=7,glow=.6,beat=4}}},
  rubble={per=2.2,min=1,max=5,up={13,17},out={1,3},spin={1,2},dark={.06,.2},near=.6,dcap=.85,jitter=.12,pattern='waves'},
  contact='Resonator',sounds={{cue='coil_hit',pitch=1.19,seq=.12}},light=true,hold='split',lift=1,speed=1},
 P={proxy={tone=C3(12,6,10),cap=.9,src='late',mesh={charge=.45,tremble=.06}},carve=true,
  rubble={per=1.6,min=1,max=6,count=30,up={4,6},out={1,3},spin={2,4},dark={.7,.8},near=.2,dcap=.9,scorch=C3(12,6,10),seed=true,pattern='levitate'},
  sounds={{cue='crystal_split',rock=9}},hold='heavy',lift=1.2,speed=1.1},
 A={proxy={mesh={charge=.45,tremble=.05}},carve=true,
  rubble={per=3,min=1,max=4,count=30,up={18,26},out={16,26},spin={10,18},dark={.1,.2},near=.5,dcap=.8,scorch=C3(30,26,24),seed=true,pattern='blast'},
  sounds={{cue='crystal_split',rock=9}},hold='heavy',lift=1.5,speed=1.2},
 Z={proxy={pulse=true,mesh={}},
  rubble={per=2.2,min=1,max=5,up={6,9},out={18,26},spin={4,8},dark={.1,.2},near=.5,dcap=.85,scorch=C3(60,40,20),pattern='jet'},
  sounds={{cue='crystal_split',pitch=1.1}},hold='split',lift=1.1,speed=1.1},
}
V.ROLE_FX=ROLE_FX
-- Each type's own way of breaking the rock (filled in below, by V.BURST).
local SIG={} :: {[string]:any}
-- SpecialistContact plays its own cue; the break's sounds come from ROLE_FX.
local MUTE={play=function() end}
local function fxPart(parent: Instance,name: string,color: Color3,class: string?): BasePart
 local p=Instance.new((class or 'Part') :: any) :: BasePart
 p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.TopSurface=Enum.SurfaceType.Smooth
 p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end

function V.new(ctx: any)
 local self=setmetatable({ctx=ctx,beams={},splits={},frags={},banners={},dust={},puffs=0,mine={},cellColor={},cellCode={},cellAccent={},cutStage={},flashes={},pending={},floors={},cracks={},crackCells={},sinks={},cube=nil,origin=Vector3.zero,
  generation=-1,applied=0,random=Random.new(),connections={},tapAt=0,geodes={},geodeOwner={},localOpened={},sealedIds={},chains={},frost={},hints={},shots={}},V)
 local fx=Instance.new('Folder');fx.Name='DigCubeFX';fx.Parent=workspace
 self.fx=fx
 self:watch()
 table.insert(self.connections,ctx.world.ChildAdded:Connect(function(child) if child.Name=='DigCube' then self:watch() end end))
 -- Needler hints (gem cells near its breaks) for this player: markers soon.
 if Players.LocalPlayer then
  table.insert(self.connections,Players.LocalPlayer:GetAttributeChangedSignal('DigHints'):Connect(function() self.sparkleAt=0 end))
 end
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
  if name=='Geodes' then self:syncGeodes() end
  if name=='Brittle' then self:syncBrittle() end
 end))
 self:sync()
 self:syncBrittle()
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
  self.frags={};self.mine={};self.cellColor={};self.cellCode={};self.cellAccent={};self.cutStage={}
  self.sealedIds={};self.chains={}
  self:clearCracks()
  self:clearFrost()
  self.generation=generation;self.origin=origin
  self.cube=DigCube.build(seed)
  -- Cuts made before this client saw the cube play no effects.
  self.applied=0
  while self.applied<count do
   local entry=self:opAt(self.applied+1)
   if not entry then break end
   self.applied+=1
   local op=DigCube.parseOp(entry)
   if op then
    if op.staged then self:markStage(op) end
    self:markSealed(op)
    DigCube.applyOp(self.cube,op)
   end
  end
  self:buildPad()
  self:clearSparkles()
  self:clearGeodes()
  self:syncGeodes()
  self:syncBrittle()
  return
 end
 local now=os.clock()
 while self.applied<count do
  local s=self:opAt(self.applied+1)
  if not s then break end
  self.applied+=1
  -- One parser for the server, the clients and the tests (DigCube op grammar v2).
  local op=DigCube.parseOp(s)
  if op then
   op.kind='c';op.partial=op.staged
   -- The rock that breaks here, cut the way the role cuts (its pieces mode):
   -- a nested stage's shell, or what is left of the cells after the last
   -- stage (the same shapes the server carved). Sealed and opened cells,
   -- and sequence breaks, go whole.
   local pieces=DigCube.pieces(self.cube,op.cells,self:opMode(op))
   if op.staged then
    local piece=pieces[op.stage or 1]
    op.parts=piece and piece.shell or nil
    self:markStage(op)
   elseif op.geode or op.sealed then
    op.parts=nil
   else
    local final=pieces[#pieces]
    local parts=final and final.parts or {}
    if op.except then
     local kept={}
     for _,part in ipairs(parts) do if not op.except[part.cell] then table.insert(kept,part) end end
     parts=kept
    end
    op.parts=parts
   end
   self:markSealed(op)
   -- Out of the cube first, so shards land on the floor the break leaves.
   for _,id in ipairs(DigCube.applyOp(self.cube,op)) do self:cellGone(id) end
   if op.sealed then self:sealBeat(op,now)
   -- A sealed cell this client already opened on landing: its break played.
   elseif not (op.geode and self.localOpened[op.cells[1]]) then self:split(op,now) end
  end
 end
end
-- How an op's rock comes apart: sequence breaks, seals and opened geodes go
-- as whole cells; otherwise the role's pieces mode (terrace without a code).
function V:opMode(op: any): string
 if op.flag=='C' or op.sealed or op.geode then return 'none' end
 local style=op.code and DigCube.STYLES_BY_CODE[op.code]
 return style and style.pieces or 'terrace'
end
-- The role that broke it: the op's code, else the code last seen cutting
-- one of its cells, else a Striker.
function V:opStyle(op: any): any
 if op.code and DigCube.STYLES_BY_CODE[op.code] then return DigCube.STYLES_BY_CODE[op.code] end
 for _,id in ipairs(op.cells) do
  local code=self.cellCode[id]
  if code and DigCube.STYLES_BY_CODE[code] then return DigCube.STYLES_BY_CODE[code] end
 end
 return DigCube.STYLES.Striker
end
-- Cells that sealed into geodes (K) stay in the cube until they open, but
-- are never cut again: no proxy is built over them, even from a drone's
-- DigOp that still names them for a frame after the seal.
function V:markSealed(op: any)
 if op.sealed then
  for _,id in ipairs(op.cells) do self.sealedIds[id]=true end
 elseif op.geode then
  for _,id in ipairs(op.cells) do self.sealedIds[id]=nil end
 end
end
-- A terrace stage that broke stays broken: its proxy never comes back.
function V:markStage(op: any)
 local key=DigCube.key(op.cells)
 self.cutStage[key]=math.max(self.cutStage[key] or 0,op.stage or 1)
end
-- A cell left the cube: its hint marker and frost go with it.
function V:cellGone(id: number)
 local hint=self.hints[id]
 if hint then hint:Destroy();self.hints[id]=nil end
 local slab=self.frost[id]
 if slab and not slab.fadeAt then slab.fadeAt=os.clock() end
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
local RUBBLE_REST=1.15 -- seconds the pile rests before the bottom pieces start to go
local RUBBLE_STEP=.07 -- one piece every this many seconds, lowest first
local RUBBLE_VANISH=.18 -- each shrinks away this fast
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
-- Gridcutter rubble: a convex polygon cut by axis-aligned lines every `step`
-- studs (cube-local grid), widened until it makes at most `most` pieces.
local function gridSplit(poly: {{number}},step: number,most: number): {{{number}}}
 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for _,v in ipairs(poly) do minX=math.min(minX,v[1]);maxX=math.max(maxX,v[1]);minZ=math.min(minZ,v[2]);maxZ=math.max(maxZ,v[2]) end
 local s=step
 while (math.floor(maxX/s)-math.floor(minX/s)+1)*(math.floor(maxZ/s)-math.floor(minZ/s)+1)>most do s*=1.25 end
 local out={}
 for gx=math.floor(minX/s),math.floor(maxX/s) do
  local column=cutPoly(cutPoly(poly,gx*s,0,-1,0),(gx+1)*s,0,1,0)
  if #column>=3 then
   for gz=math.floor(minZ/s),math.floor(maxZ/s) do
    local cell=cutPoly(cutPoly(column,0,gz*s,0,-1),0,(gz+1)*s,0,1)
    if #cell>=3 and DigCube.polyArea(cell)>.03 then table.insert(out,cell) end
   end
  end
 end
 return #out>0 and out or {poly}
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
-- `rf` is the breaking role's ROLE_FX rubble: how many pieces, how high and
-- far they fly, how they spin, how scorched they are and any extras (Halver
-- halves, Gridcutter grid, Singularity implosion, Starforge molten, Bubbler
-- float, Resonator jitter). `center` is where the hit came from.
function V:shards(op: any,now: number,center: Vector3,rf: any?)
 local o=self.origin;local cube=self.cube
 local fx=rf or ROLE_FX.L.rubble
 local loose=self:physicsReady()
 local made={}
 local lo,hi=Vector3.new(math.huge,0,math.huge),Vector3.new(-math.huge,0,-math.huge)
 local floorY=math.huge
 local random=function() return self.random:NextNumber() end
 local function U(r: {number}): number return self.random:NextNumber(r[1],r[2]) end
 -- Biggest parts first: the per-break cap keeps the big pieces.
 local order=table.clone(self:opParts(op))
 table.sort(order,function(a,b) return DigCube.polyArea(a.poly)>DigCube.polyArea(b.poly) end)
 local cap=fx.count or 18
 local plane=fx.halves and DigCube.split(cube,op.cells) or nil
 local hot=0
 -- One direction for a jet (Lancer), one sweep axis for rows (Gridcutter).
 local ja=self.random:NextNumber(0,math.pi*2)
 local jetAxis=Vector3.new(math.cos(ja),0,math.sin(ja))
 for i,c in ipairs(order) do
  if #self.frags>=SHARD_MAX or #made>=cap then break end
  for _,v in ipairs(c.poly) do
   lo=Vector3.new(math.min(lo.X,v[1]),0,math.min(lo.Z,v[2]));hi=Vector3.new(math.max(hi.X,v[1]),0,math.max(hi.Z,v[2]))
  end
  floorY=math.min(floorY,c.y0)
  -- Each part breaks into pieces of its own, the way the role cuts.
  local cut=#self.frags<SHARD_CUT
  local budget=math.max(1,cap-#made-(#order-i))
  local pieces={}
  if plane then
   -- Halver: each part in two along the chunk's split plane, then a few pieces.
   for side=-1,1,2 do
    local half=cutPoly(c.poly,plane.cx,plane.cz,-side*plane.nx,-side*plane.nz)
    if #half>=3 and DigCube.polyArea(half)>.03 then
     local n=cut and math.clamp(math.floor(DigCube.polyArea(half)/fx.per+.5),fx.min,fx.max) or 1
     for _,q in ipairs(DigCube.voronoiSplit(half,n,random)) do table.insert(pieces,{poly=q,side=side}) end
    end
   end
  elseif fx.grid then
   for _,q in ipairs(cut and gridSplit(c.poly,fx.grid,12) or {c.poly}) do table.insert(pieces,{poly=q}) end
  else
   local n=cut and math.clamp(math.floor(DigCube.polyArea(c.poly)/fx.per+.5),fx.min,fx.max) or 1
   for _,q in ipairs(DigCube.voronoiSplit(c.poly,math.min(n,math.max(budget,fx.min)),random)) do table.insert(pieces,{poly=q}) end
  end
  for _,piece in ipairs(pieces) do
   if #made>=cap or #self.frags>=SHARD_MAX then break end
   local poly=piece.poly
   local _,mx,mz=middle(poly)
   local mid=o+Vector3.new(mx,(c.y0+c.y1)*.5,mz)
   -- The rock's own color, a little darker here and there so the pieces
   -- read as separate (and fresh-broken faces look deeper).
   -- Darker the closer it was to the hit (owner, Nov 22): scorched where
   -- the beam hit, fading to the plain rock tone a few studs out (Halver:
   -- along its cut).
   local near
   if plane then near=.6*math.exp(-math.abs((mx-plane.cx)*plane.nx+(mz-plane.cz)*plane.nz)/1.6)
   else near=fx.near*math.exp(-Vector3.new(mid.X-center.X,0,mid.Z-center.Z).Magnitude/2.6) end
   local color=self:colorAt(c.y1-.01,mx,mz):Lerp(fx.scorch or SHARD_DARK,math.min(fx.dcap,U(fx.dark)+near))
   local k=SHARD_GAP*(fx.implode and .75 or 1)
   local inverse=CFrame.new(mid):Inverse()
   local parts={}
   for _,w in ipairs(DigCube.polyWedges(poly,c.y0,c.y1)) do
    local part=fxPart(self.fx,'DigShard',color,'WedgePart');part.CastShadow=true;part.Material=ROCK;part.MaterialVariant=ROCK_VARIANT
    if fx.glass then part.Material=Enum.Material.Glass end
    local size=Vector3.new(w.size[1],w.size[2],w.size[3])
    local frame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
     Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
    local rel=inverse*frame
    part.Size=size*k;part.CFrame=CFrame.new(mid)*(rel.Rotation+rel.Position*k)
    table.insert(parts,{part=part,size=size,rel=rel})
   end
   if #parts>0 then
    local height=c.y1-c.y0
    local out
    if plane then out=Vector3.new(plane.nx,0,plane.nz)*piece.side
    else
     out=Vector3.new(mid.X-center.X,0,mid.Z-center.Z)
     local a=self.random:NextNumber(0,math.pi*2)
     out=out.Magnitude>.3 and out.Unit or Vector3.new(math.cos(a),0,math.sin(a))
    end
    -- Tips away from the hit (the hand-animated fallback too).
    local axis=Vector3.yAxis:Cross(out)+Vector3.new(self.random:NextNumber(-.3,.3),self.random:NextNumber(-.2,.2),self.random:NextNumber(-.3,.3))
    local rest=height*.5*SHARD_GAP*self.random:NextNumber(.45,.85)
    local landY=math.min(mid.Y,o.Y+c.y0+rest)
    local drop=mid.Y-landY
    -- All at once, the moment the pause ends (owner, Nov 22); an implosion
    -- or a jitter plays first, held in place.
    local delay=(fx.implode or fx.jitter or 0)
    -- Each role comes apart its own way (owner: not reskins): when each
    -- piece lets go.
    local flat=Vector3.new(mid.X-center.X,0,mid.Z-center.Z)
    local dist=flat.Magnitude
    local pattern=fx.pattern
    if pattern=='ring' then delay+=dist*.035          -- a shockwave from the slam
    elseif pattern=='waves' then delay+=math.floor(dist/1.5)*.12 -- ringing out in steps
    elseif pattern=='rows' then delay+=math.max(0,(flat:Dot(jetAxis)+8))*.045 -- a sweep across
    elseif pattern=='crumble' then delay+=self.random:NextNumber(0,.35)
    elseif pattern=='fountain' then delay+=self.random:NextNumber(0,.4)
    elseif pattern=='levitate' then delay+=self.random:NextNumber(0,.12) end
    local f={parts=parts,pattern=pattern,jet=jetAxis,k=k,scale=k,axis=axis.Magnitude>.05 and axis.Unit or Vector3.xAxis,
     turn=self.random:NextNumber(.6,1.8),
     from=mid,land=Vector3.new(mid.X,landY,mid.Z)+out*self.random:NextNumber(.1,.9),
     at=now+delay,pre=delay>0,center=center,fx=fx,
     T=.24+math.sqrt(2*drop/GRAVITY)*1.15,hop=self.random:NextNumber(.35,.95),
     wait=self.random:NextNumber(.3,.7),born=now,pos=mid,out=out,floor=o.Y+c.y0}
    -- Starforge: the rock by the hit comes out molten and cools.
    if fx.molten and near>.3 and hot<20 then
     hot+=1;f.hot={from=fx.molten,to=color,at=now}
     for _,q in ipairs(parts) do q.part.Color=fx.molten end
    end
    if loose then
     -- Loose pieces stay physical until their turn to go (bottom first).
     -- Welded at the release (releaseShard), so a held pre-pose is exact.
     f.loose=true;f.life=8
     local physical=fx.friction and PhysicalProperties.new(2.6,fx.friction,.12,1,1) or RUBBLE
     for _,q in ipairs(parts) do
      q.part.CollisionGroup='DigRubble';q.part.CustomPhysicalProperties=physical;q.part.CanCollide=true
     end
    end
    table.insert(self.frags,f);table.insert(made,f)
   end
  end
 end
 -- The invisible floor the loose pieces land and pile on.
 if loose and #made>0 then
  local size=Vector3.new(hi.X-lo.X+10,2,hi.Z-lo.Z+10)
  local floor=fxPart(self.fx,'DigRubbleFloor',SHARD_DARK);floor.Transparency=1;floor.CanCollide=true
  floor.CollisionGroup='DigRubbleFloor';floor.Size=size
  floor.CFrame=CFrame.new(o.X+(lo.X+hi.X)*.5,o.Y+floorY-1,o.Z+(lo.Z+hi.Z)*.5)
  table.insert(self.floors,{part=floor,untilAt=now+RUBBLE_REST+RUBBLE_STEP*#made+2})
 end
 -- Bottom up, one by one: once the pile has landed, the lowest piece goes
 -- first, then the next lowest, so the rest sink and fall into the hole.
 if loose and #made>0 then
  table.insert(self.sinks,{frags=made,nextAt=now+RUBBLE_REST})
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

-- Cracks free: welded into one piece, a small pop up and out, a spin, then
-- gravity. Thrown and tipped away from where the hit came from (owner, Nov
-- 22), so it is clear what cracked it: out from that point, rolling outward
-- about the axis across that direction, plus a little tumble. An upward pop
-- first, so it reads as knocked loose (owner, Nov 22). The role's ranges.
function V:releaseShard(f: any)
 f.released=true
 local fx=f.fx or ROLE_FX.L.rubble
 local parts=f.parts
 local primary=parts[1].part
 for n=2,#parts do
  local weld=Instance.new('WeldConstraint');weld.Part0=primary;weld.Part1=parts[n].part;weld.Parent=primary
 end
 for _,q in ipairs(parts) do q.part.Anchored=false end
 local r=self.random
 primary.CFrame+=Vector3.yAxis*.12
 primary.AssemblyLinearVelocity=f.out*r:NextNumber(fx.out[1],fx.out[2])+Vector3.yAxis*r:NextNumber(fx.up[1],fx.up[2])
 local pattern=f.pattern
 if pattern=='jet' then
  -- All down one line, like the lance blew through it.
  primary.AssemblyLinearVelocity=f.jet*r:NextNumber(fx.out[1],fx.out[2])+f.out*r:NextNumber(0,3)+Vector3.yAxis*r:NextNumber(fx.up[1],fx.up[2])
 elseif pattern=='crumble' then
  -- No throw: it just falls apart where it was.
  primary.CFrame-=Vector3.yAxis*.12
  primary.AssemblyLinearVelocity=Vector3.new(r:NextNumber(-1,1),-r:NextNumber(0,2),r:NextNumber(-1,1))
 elseif pattern=='levitate' then
  -- Lifted and held up, then slammed down (stepShards).
  f.floatUntil=os.clock()+r:NextNumber(.45,.7);f.slam=true
 elseif pattern=='shatter' then
  local away=(f.out+Vector3.new(r:NextNumber(-.6,.6),0,r:NextNumber(-.6,.6))).Unit
  primary.AssemblyLinearVelocity=away*r:NextNumber(fx.out[1],fx.out[2])+Vector3.yAxis*r:NextNumber(fx.up[1],fx.up[2])
 end
 local roll=Vector3.yAxis:Cross(f.out)
 local w=fx.spin[2]*.25
 primary.AssemblyAngularVelocity=roll*r:NextNumber(fx.spin[1],fx.spin[2])+Vector3.new(r:NextNumber(-w,w),r:NextNumber(-w,w),r:NextNumber(-w,w))
 if pattern=='shatter' or pattern=='blast' then
  primary.AssemblyAngularVelocity=Vector3.new(r:NextNumber(-1,1),r:NextNumber(-1,1),r:NextNumber(-1,1)).Unit*r:NextNumber(fx.spin[1],fx.spin[2])
 end
 if fx.float then f.floatUntil=os.clock()+fx.float end
end
-- Held in place before the release: a Singularity piece pulls toward the
-- middle (it starts smaller), a Resonator piece shivers.
function V:prePose(f: any,now: number)
 local fx=f.fx
 local e=math.clamp((now-f.born)/math.max(f.at-f.born,.01),0,1)
 local pos=f.from
 if fx.implode then pos=f.from:Lerp(Vector3.new(f.center.X,f.from.Y,f.center.Z),.4*(1-(1-e)^2)) end
 if fx.jitter and not self:reduced() then
  pos+=Vector3.new(self.random:NextNumber(-.08,.08),self.random:NextNumber(-.04,.04),self.random:NextNumber(-.08,.08))
 end
 local frame=CFrame.new(pos)
 for _,q in ipairs(f.parts) do q.part.CFrame=frame*(q.rel.Rotation+q.rel.Position*f.k) end
end
function V:stepSinks(now: number)
 for i=#self.sinks,1,-1 do
  local sink=self.sinks[i]
  if now>=sink.nextAt then
   local lowest,lowY=nil,math.huge
   for _,f in ipairs(sink.frags) do
    if not f.dead and not f.vanishing and not (f.keeper and f.dust and not f.dust.goneAt) then
     local y=f.parts[1] and f.parts[1].part.Position.Y or math.huge
     if y<lowY then lowest,lowY=f,y end
    end
   end
   if not lowest then table.remove(self.sinks,i)
   else
    lowest.vanishing=true
    if lowest.loose and not lowest.settled then self:settle(lowest) end
    lowest.settledAt=now;lowest.fadeT=RUBBLE_VANISH
    sink.nextAt=now+RUBBLE_STEP
   end
  end
 end
end
function V:stepShards(now: number)
 self:stepSinks(now)
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
  if f.hot then
   -- Molten rock cooling to its scorched tone.
   local u=math.clamp((now-f.hot.at)/1.6,0,1)
   local color=f.hot.from:Lerp(f.hot.to,u)
   for _,q in ipairs(f.parts) do q.part.Color=color end
   if u>=1 then f.hot=nil end
  end
  if f.loose and not f.settled then
   local primary=f.parts[1].part
   if t<0 and f.pre then self:prePose(f,now) end
   if t>=0 and not f.released then self:releaseShard(f) end
   -- Bubbler: the pieces float up for a moment before they fall.
   if f.floatUntil and now<f.floatUntil and primary.Parent then
    local v=primary.AssemblyLinearVelocity
    primary.AssemblyLinearVelocity=Vector3.new(v.X*.9,f.slam and 4 or 2.5,v.Z*.9)
   elseif f.slam and not f.slammed and f.floatUntil and primary.Parent then
    -- Ramiel: the lifted rock is hurled down.
    f.slammed=true
    local v=primary.AssemblyLinearVelocity
    primary.AssemblyLinearVelocity=Vector3.new(v.X*.4,-48,v.Z*.4)
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
    local fade=math.clamp(age/(f.fadeT or SHARD_FADE),0,1)
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

-- A break plays one beat, the breaking role's (ROLE_FX):
--  * a frame pause first (your own breaks only): the piece flashes in the
--    role's color and holds for the role's few frames before anything moves
--  * then, together: the role's sounds, the camera hit, up to five 3D streak
--    boxes, the role's contact (ring and particles) and a dim light; the
--    shards (the real rock) fly the role's way.
-- A piece that breaks before the last (a terrace stage) is a small beat.
-- Shorter (owner, Nov 22: the pause was too long): about 5-8 frames is a
-- medium hit; past ~20 reads as a bug.
local HOLD_PIECE,HOLD_SPLIT,HOLD_HEAVY,HOLD_GEM=1/60,2/60,3/60,6/60
local HOLD_GEODE=8/60 -- the full-game freeze after you land on a sealed gem
local FLASH=Color3.fromRGB(255,249,216)
local FLASH_FADE=.2
-- Every break lights the whole segment that is coming out in the color of
-- the drone that cut it (white-hot if unknown), so it is clear exactly what
-- is being removed; it holds through the frame pause, then fades over the
-- rubble.
-- The rock a break takes out, as {poly,y0,y1} parts.
function V:opParts(op: any): {any}
 if op.parts then return op.parts end
 local out={}
 for _,id in ipairs(op.cells) do
  local c=self.cube.cells[id]
  if c then table.insert(out,{poly=c.poly,y0=c.y0,y1=c.y1,cell=id}) end
 end
 return out
end
-- `glow`: your own full breaks and gems get a slightly stronger flash. No
-- Neon: with the bloom it read as a flashbang (owner, Nov 22).
function V:flash(op: any,now: number,holdUntil: number,color: Color3,glow: boolean?)
 local o=self.origin
 local parts={}
 local base=glow and .3 or .45
 for n,c in ipairs(self:opParts(op)) do
  if n>16 then break end
  for _,w in ipairs(DigCube.polyWedges(DigCube.grown(c.poly,.06),c.y0+.02,c.y1+.08)) do
   local part=fxPart(self.fx,'DigBreakFlash',color,'WedgePart');part.Transparency=base
   part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
   part.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
   table.insert(parts,part)
  end
 end
 table.insert(self.flashes,{parts=parts,base=base,holdUntil=holdUntil,untilAt=holdUntil+FLASH_FADE})
end
-- Light does the popping instead of more particles: a short colored point
-- light where something breaks lights up the pit walls around it. Pooled.
local LIGHT_MAX=6
-- Owner, Nov 22: the first pass was "like a flashbang". Every break light
-- is scaled down and capped.
local LIGHT_SCALE,LIGHT_PEAK=.22,1.6
function V:lightFlash(at: Vector3,color: Color3,range: number,brightness: number,life: number)
 if self:reduced() then return end
 self.lights=self.lights or {}
 local entry
 if #self.lights>=LIGHT_MAX then entry=table.remove(self.lights,1)
 else
  local anchor=fxPart(self.fx,'DigBreakLight',color);anchor.Transparency=1;anchor.Size=Vector3.one*.05
  local light=Instance.new('PointLight');light.Shadows=false;light.Parent=anchor
  entry={anchor=anchor,light=light}
 end
 entry.anchor.Position=at;entry.light.Color=color;entry.light.Range=range;entry.light.Enabled=true
 entry.peak=math.min(brightness*LIGHT_SCALE,LIGHT_PEAK);entry.at=os.clock();entry.life=life;entry.light.Brightness=entry.peak
 table.insert(self.lights,entry)
end
function V:stepLights(now: number)
 for _,entry in ipairs(self.lights or {}) do
  local t=(now-entry.at)/entry.life
  if t>=1 then
   if entry.light.Enabled then entry.light.Enabled=false end
  else
   -- A fast attack is the flash itself; the light then eases out.
   entry.light.Brightness=entry.peak*(1-t)^2
  end
 end
end
function V:stepHolds(now: number)
 for i=#self.flashes,1,-1 do
  local f=self.flashes[i]
  if now>=f.untilAt then
   for _,part in ipairs(f.parts) do part:Destroy() end
   table.remove(self.flashes,i)
  elseif now>f.holdUntil then
   local fade=(now-f.holdUntil)/FLASH_FADE
   for _,part in ipairs(f.parts) do part.Transparency=f.base+(1-f.base)*fade*fade end
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
-- drawn as its own prisms over the rock. It darkens with damage, and late in
-- its share of the work (CRACK_POP) it pops loose: it lifts out of the rock,
-- tilts and turns a little, casting a real shadow, its color snaps back, and
-- the crack plays with chips. Then it strains (a growing jitter) until it
-- breaks off. Each role works it its own way (ROLE_FX proxy).
local CRACK_STEPS=2 -- per stage: one crack, then it breaks out
local CRACK_POP=.85 -- the crack comes late in each piece's share of the work, so it strains, then breaks
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
   -- One crack per piece, late (CRACK_POP): darkens, pops loose, strains.
   local s=f>=CRACK_POP and 1 or 0
   local within=s==0 and f/CRACK_POP or (f-CRACK_POP)/(1-CRACK_POP)
   return (k-1)*CRACK_STEPS+s,within
  end
  prev=piece.at
 end
 return #job.pieces*CRACK_STEPS,0
end
function V:dropProxy(proxy: any)
 if proxy.dead then return end
 proxy.dead=true
 if proxy.mesh then RockChunks.destroy(proxy.mesh);proxy.mesh=nil end
 proxy.model:Destroy()
 if proxy.aux then proxy.aux:Destroy() end
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
-- The piece, slightly grown so it covers the carved rock. Every role's hole
-- is carved ahead now (the server cuts the piece a moment before its break,
-- owner Nov 22: no gap between the break and the rubble), so every piece is
-- grown to cover the cut and gets an invisible static copy the player stands
-- on until the break. Drawn as animated rock chunks (RockChunks: plain parts
-- moved by CFrame, rippling and popping); the old wedge prisms are the
-- fallback when a piece has no chunk.
local PROXY_GROW=.3
function V:proxyWedges(proxy: any,shapes: {any})
 local o=self.origin
 for _,c in ipairs(shapes) do
  for _,w in ipairs(DigCube.polyWedges(c.grown,c.y0+.02,c.y1+.03)) do
   local part=fxPart(proxy.model,'DigCrack',c.stone,'WedgePart')
   part.CastShadow=true;part.Material=ROCK;part.MaterialVariant=ROCK_VARIANT
   part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
   part.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
   table.insert(proxy.parts,{part=part,stone=c.stone,size=part.Size,side=c.side,base=CFrame.new(proxy.pivot):ToObjectSpace(part.CFrame)})
  end
 end
 if proxy.iced then for _,e in ipairs(proxy.parts) do e.part.Material=Enum.Material.Ice end end
 proxy.shade=-1
end
function V:buildProxy(piece: any,owned: boolean,chunk: {number},code: string?): any?
 local cube=self.cube;local o=self.origin
 local fx=ROLE_FX[code or 'L'] or ROLE_FX.L
 local pfx=fx.proxy
 local ids={}
 for _,id in ipairs(chunk) do
  if not cube.removed[id] and not self.crackCells[id] and not self.sealedIds[id] and not self.geodes[id] then table.insert(ids,id) end
 end
 if #ids==0 then return nil end
 -- Halver: the final piece in two halves along the chunk's split plane.
 local plane=pfx.halves and piece.final and DigCube.split(cube,chunk) or nil
 local shapes={}
 local area,sx,sz,top,bottom=0,0,0,-math.huge,math.huge
 local function add(poly: {{number}},c: any,side: number?)
  local a,mx,mz=middle(poly)
  if a<=.02 then return end
  area+=a;sx+=mx*a;sz+=mz*a;top=math.max(top,c.y1);bottom=math.min(bottom,c.y0)
  table.insert(shapes,{poly=poly,grown=DigCube.grown(poly,PROXY_GROW),y0=c.y0,y1=c.y1,side=side,stone=self:colorAt(c.y1-.01,mx,mz)})
 end
 for _,c in ipairs(piece.shell or piece.parts) do
  if plane then
   for side=-1,1,2 do
    local half=cutPoly(c.poly,plane.cx,plane.cz,-side*plane.nx,-side*plane.nz)
    if #half>=3 then add(half,c,side) end
   end
  else add(c.poly,c,nil) end
 end
 if area<=0 then return nil end
 local model=Instance.new('Model');model.Name='DigCrackPiece'
 local pivot=o+Vector3.new(sx/area,top,sz/area)
 -- The carved-ahead hole is held shut for players until the break.
 local aux=Instance.new('Folder');aux.Name='DigCrackHold'
 for _,c in ipairs(shapes) do
  for _,w in ipairs(DigCube.polyWedges(c.grown,c.y0+.02,c.y1+.03)) do
   local hold=fxPart(aux,'DigCrackFloor',c.stone,'WedgePart')
   hold.Transparency=1;hold.CanCollide=true;hold.CanQuery=false;hold.CanTouch=false;hold.CollisionGroup='Default'
   hold.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
   hold.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
  end
 end
 -- An invisible core at the pivot carries the lights and the outline's
 -- Adornee model while the mesh is still being made.
 local core=fxPart(model,'DigCrackCore',shapes[1].stone);core.Transparency=1;core.Size=Vector3.one*.05;core.CFrame=CFrame.new(pivot)
 model.Parent=self.fx
 -- The old pulsing outline: your own crew's piece breathes an outline in
 -- the rock's own color, lifted toward white (owner, Nov 22: rock, not drone).
 local highlight
 if owned then
  highlight=Instance.new('Highlight');highlight.Name='DigTarget';highlight.DepthMode=Enum.HighlightDepthMode.Occluded
  highlight.FillTransparency=1;highlight.OutlineColor=shapes[1].stone:Lerp(Color3.new(1,1,1),.4)
  highlight.OutlineTransparency=.5;highlight.Adornee=model;highlight.Parent=model
 end
 local proxy={parts={},ids=ids,pivot=pivot,step=0,shade=0,joltAt=-10,model=model,core=core,highlight=highlight,since=os.clock(),outline=highlight and highlight.OutlineColor,
  turn=self.random:NextNumber(.7,1)*(self.random:NextInteger(0,1)*2-1),tipAxis=self.random:NextNumber(0,math.pi*2),
  fx=pfx,code=code,tone=pfx.tone or BLACK,seed=self.random:NextNumber(1,100),scale=1,progress=0,within=0,owned=owned,
  primary=V.primaryColor(code),hit=Vector3.zero,pops=0,sig=SIG[code or 'L'],
  vibAxis=CFrame.Angles(0,self.random:NextNumber(0,math.pi*2),0).LookVector,
  normal=plane and Vector3.new(plane.nx,0,plane.nz) or nil,radius=math.sqrt(area/math.pi),thick=top-bottom,
  planeAt=plane and o+Vector3.new(plane.cx,top-.1,plane.cz) or nil}
 if pfx.ball then
  -- Bubbler: a glassy bubble grows inside the piece as it is worked.
  local ball=fxPart(aux,'DigBubble',V.primaryColor(code),'Part')
  ball.Shape=Enum.PartType.Ball;ball.Material=Enum.Material.Glass;ball.Transparency=.75;ball.Size=Vector3.one*.05
  ball.CFrame=CFrame.new(pivot-Vector3.yAxis*proxy.thick*.3)
  proxy.ball=ball;proxy.ballSize=0
 end
 if pfx.light then
  -- Starforge: the piece heats up and glows a little on the pit walls.
  local light=Instance.new('PointLight');light.Name='DigHeat';light.Shadows=false
  light.Color=Color3.fromRGB(255,140,60);light.Range=8;light.Brightness=0;light.Parent=core
  proxy.light=light
 end
 aux.Parent=self.fx;proxy.aux=aux
 for _,id in ipairs(ids) do self.crackCells[id]=proxy end
 -- The animated chunks (pivot-local shapes); wedges if there are none.
 local meshShapes={}
 for _,c in ipairs(shapes) do
  local poly={}
  for _,v in ipairs(c.grown) do table.insert(poly,{o.X+v[1]-pivot.X,o.Z+v[2]-pivot.Z}) end
  table.insert(meshShapes,{poly=poly,y0=o.Y+c.y0+.02-pivot.Y,y1=o.Y+c.y1+.03-pivot.Y,color=c.stone,side=c.side})
 end
 local random=function() return self.random:NextNumber() end
 local sig=proxy.sig
 local rec=RockChunks.build(meshShapes,DigCube.voronoiSplit,random,sig and sig.tileArea,sig and sig.maxTiles)
 if rec then
  proxy.mesh=rec;rec.model.Parent=model
  proxy.shade=-1
 else
  self:proxyWedges(proxy,shapes)
 end
 if sig and sig.build then sig.build(self,proxy) end
 return proxy
end
-- Where the piece sits at its current stage (plus the pop after a crack),
-- with the role's own motion: a slam or pulse jolting it down, trembles and
-- jitters, the Bubbler's rise, the Halver halves sliding apart, the
-- Gridcutter's step down and the Singularity's squeeze. After the pop it
-- strains (a growing 40 Hz jitter) until it breaks.
function V:poseProxy(proxy: any,now: number)
 local fx=proxy.fx or {}
 local s=proxy.step+1
 local t=(now-proxy.joltAt)/CRACK_JOLT
 local pop=t<1 and .32*math.sin(math.pi*math.clamp(t,0,1))*(1-t*.5) or 0
 local lift,turn,tip=CRACK_LIFT[s]+pop,CRACK_TURN[s]*proxy.turn,CRACK_TIP[s]
 local progress=math.clamp(proxy.progress or 0,0,1)
 if fx.flat then lift=s>1 and -.06 or 0;turn=0;tip=0 end
 -- A signature type moves its own chunks (SIG); the piece itself only
 -- rises if that type floats it (the Bubbler), never the shared crack pop.
 local sig=proxy.sig
 if sig then lift=sig.lift and sig.lift(progress) or 0;turn=0;tip=0 end
 if fx.lift then lift+=fx.lift[1]+(fx.lift[2]-fx.lift[1])*progress end
 if fx.slam and proxy.slamAt then
  local u=now-proxy.slamAt
  if u>=0 and u<.18 then lift-=.15*math.sin(math.pi*u/.18) end
 end
 if fx.pulse and proxy.pulseAt then
  local u=now-proxy.pulseAt
  if u>=0 and u<.12 then lift-=.1*math.sin(math.pi*u/.12) end
 end
 -- The mesh pops its own chunks, so the whole piece lifts a little less.
 if proxy.mesh and not sig then lift*=.55 end
 local shake=Vector3.zero
 if not self:reduced() then
  local amp=(s>1 and not sig) and .035*math.clamp(proxy.within or 0,0,1) or 0
  if fx.jitter then amp+=fx.jitter[1]+(fx.jitter[2]-fx.jitter[1])*progress end
  if fx.tremble then amp+=fx.tremble*math.clamp((progress-.7)/.3,0,1) end
  if amp>0 then
   local q=math.floor(now*40)*.37
   shake=Vector3.new(math.noise(q,proxy.seed,.1),0,math.noise(proxy.seed,q,.7))*(2*amp)
  end
  if fx.vibrate then
   shake+=proxy.vibAxis*((fx.vibrate[1]+(fx.vibrate[2]-fx.vibrate[1])*progress)*math.sin(now*34*2*math.pi))
  end
 end
 local pose=CFrame.new(proxy.pivot+Vector3.yAxis*lift+shake)
  *CFrame.Angles(0,turn,0)
  *CFrame.Angles(math.cos(proxy.tipAxis)*tip,0,math.sin(proxy.tipAxis)*tip)
 local scale=proxy.scale or 1
 local slide=0
 if proxy.normal and s>1 and not sig then slide=.18*(1-(1-math.clamp(t,0,1))^2) end
 proxy.slideVec=slide>0 and proxy.normal*slide or nil
 proxy.core.CFrame=pose
 if proxy.mesh then
  RockChunks.setPose(proxy.mesh,pose)
 else
  for _,e in ipairs(proxy.parts) do
   local base=scale~=1 and (e.base.Rotation+e.base.Position*scale) or e.base
   if e.side and slide>0 then base=CFrame.new(proxy.normal*(e.side*slide))*base end
   e.part.CFrame=pose*base
  end
 end
 if proxy.ball then proxy.ball.CFrame=CFrame.new(pose.Position-Vector3.yAxis*proxy.thick*.3) end
end
function V:shadeProxy(proxy: any,shade: number)
 if math.abs(shade-proxy.shade)<.01 then return end
 proxy.shade=shade
 if proxy.mesh then RockChunks.shade(proxy.mesh,proxy.tone,shade,proxy.hit);return end
 for _,e in ipairs(proxy.parts) do e.part.Color=e.stone:Lerp(proxy.tone,shade) end
end
-- The rock doing things while it is worked (RockChunks), the role's way
-- (ROLE_FX proxy.mesh): beam roles send a pulsing ripple out from the beam's
-- point with a glowing crest; slams and pulses send one shock ring and pop
-- chunks out; darts pop the chunk they hit; charged shots and volleys make
-- the rock shiver and pop chunks as the charge builds; every crack pops a
-- few chunks loose. Your own pieces animate at 30 Hz, others' at 12 Hz.
local MESH_DEFAULT={ripple={amp=.09,len=2.4,speed=4.5,glow=.5}}
-- The crack pop, each role's own way (RockChunks.burst): how many chunks, how
-- hard, pried up on an edge or lifted out, and its shock ring (speed < 0
-- runs inward). Plays all through the work, bigger at each crack.
local BURST={
 L={count=2,strength=1.1,mode='pry',ring=.2,speed=11},
 C={count=3,strength=1.3,mode='lift',ring=.32,speed=15,width=1.2,glow=.55},
 B={count=1,strength=1,mode='lift',ring=.14,speed=9},
 N={count=1,strength=.8,mode='pry',ring=.08,speed=10,width=.6},
 U={count=2,strength=.8,mode='lift',ring=.18,speed=6,width=1.3},
 H={count=2,strength=1.35,mode='pry',ring=.22,speed=13},
 G={count=2,strength=.9,mode='lift',ring=.16,speed=12},
 Y={count=2,strength=1.4,mode='pry',ring=.24,speed=-10},
 M={count=2,strength=1,mode='lift',ring=.2,speed=8,glow=.95},
 I={count=3,strength=1.5,mode='pry',ring=.18,speed=16,width=.6},
 V={count=3,strength=.9,mode='pry',ring=.2,speed=18,width=.7},
 P={count=2,strength=1.4,mode='pry',ring=.26,speed=14},
 A={count=2,strength=1.5,mode='lift',ring=.3,speed=12},
 Z={count=2,strength=1,mode='pry',ring=.22,speed=20,width=.8,glow=.85},
}
V.BURST=BURST
-- Every drone type breaks the rock its own way (owner, Nov 22: "all drones
-- do the same progression of damage, and look the exact same"). Before,
-- every type darkened its piece, popped it loose at 85% and broke it out
-- in terrace stages; only small parameters differed. Now each type has one
-- process that reads from the play camera, driven by its chunk's progress.
-- These types work their whole chunk as one piece (DigCube.STYLES pieces
-- 'none') and the server cuts the cells as soon as the drone is on station
-- (STYLES early), so whatever sinks, leans or flies away shows the hole:
--  C Charger     stamp    each slam drives the rock down into a bowl; the rim tips out
--  N Needler     chip     each dart knocks one small bit clean out of the rock
--  B Ballcaster  swell    the cell swells and shivers, darkening, until the ball pops it
--  U Bubbler     float    the rock lifts out of its bed and drifts apart inside a bubble
--  H Halver      halve    a seam glows across it and the two halves lean apart
--  G Gridcutter  dice     a grid sweeps across it; each square drops as it is cut
--  Y Singularity implode  the rock spirals in toward the middle and sinks
--  M Starforge   melt     a molten front spreads from the beam and the rock sags
--  I Frostbite   freeze   ice spreads from the beam, then the frozen rock shivers
--  V Resonator   rattle   the rock shakes harder and harder, rings running out
--  Z Lancer      drill    every pulse punches the hole under the lance deeper
-- The Striker keeps the classic terrace cut (pits stepping down, ripple,
-- crack pops); Ramiel and Nomad keep their charge pops.
do
 local ICE=Color3.fromRGB(214,240,255)
 local MOLTEN=Color3.fromRGB(255,122,36)
 local WHITEHOT=Color3.fromRGB(255,228,160)
 local function ease(t: number): number t=math.clamp(t,0,1);return t*t*(3-2*t) end
 local function dist(tile: any,h: Vector3): number return math.sqrt((tile.cx-h.X)^2+(tile.cz-h.Z)^2) end
 -- The chunks nearest the hit first, fixed once so the process is steady.
 local function order(proxy: any,rec: any): {any}
  if proxy.order then return proxy.order end
  local h=proxy.hit or Vector3.zero
  local key={}
  local list=table.clone(rec.tiles)
  for _,t in ipairs(list) do key[t]=dist(t,h)+math.random()*.7 end
  table.sort(list,function(a,b) return key[a]<key[b] end)
  proxy.order=list
  return list
 end
 local function neon(parent: Instance,name: string,color: Color3): BasePart
  local p=fxPart(parent,name,color);p.Material=Enum.Material.Neon;p.Transparency=1
  return p
 end
 SIG.C={ring={amp=.4,speed=16,width=1.5,glow=.35},tiles=function(self,proxy,rec,p)
  local R=math.max(rec.radius,1)
  local depth=math.min(1.8,proxy.thick*.45)*p
  local tilt=math.rad(28)*p
  return function(tile)
   local r=math.sqrt(tile.cx*tile.cx+tile.cz*tile.cz)
   local k=math.clamp(r/R,0,1)
   local ux,uz=1,0
   if r>1e-3 then ux,uz=tile.cx/r,tile.cz/r end
   return Vector3.new(0,-depth*(1-.7*k),0),CFrame.fromAxisAngle(Vector3.new(-uz,0,ux),tilt*k)
  end
 end}
 SIG.N={tileArea=1.3,maxTiles=12,tiles=function(self,proxy,rec,p,now)
  local list=order(proxy,rec)
  local gone=math.floor(p*#list*.92+.001)
  proxy.goneAt=proxy.goneAt or {}
  for i=1,math.min(gone,#list) do if not proxy.goneAt[list[i]] then proxy.goneAt[list[i]]=now end end
  return function(tile)
   local at=proxy.goneAt[tile]
   if not at then return nil end
   local u=(now-at)/.22
   if u>=1 then return nil,nil,nil,true end
   -- Knocked out: up and away from the middle, tumbling.
   local r=math.max(.3,math.sqrt(tile.cx*tile.cx+tile.cz*tile.cz))
   return Vector3.new(tile.cx/r*1.3*u,1.5*u-1.1*u*u,tile.cz/r*1.3*u),CFrame.Angles(2.4*u,0,1.5*u)
  end
 end}
 SIG.B={tiles=function(self,proxy,rec,p)
  local e=p*p
  return function(tile) return Vector3.new(tile.cx*.16*e,.55*e,tile.cz*.16*e) end
 end}
 SIG.U={lift=function(p: number): number return 1.8*ease(p) end,tiles=function(self,proxy,rec,p,now)
  local e=ease(p)
  return function(tile,i)
   return Vector3.new(tile.cx*.22*e,math.sin(now*2.4+i*1.7)*.16*e,tile.cz*.22*e),CFrame.Angles(.14*e*math.sin(i),0,.14*e*math.cos(i))
  end
 end}
 SIG.H={build=function(self,proxy)
  proxy.seam=neon(proxy.model,'HalverSeam',proxy.primary:Lerp(Color3.new(1,1,1),.35))
 end,tiles=function(self,proxy,rec,p)
  local n=proxy.normal
  if not n then return nil end
  local e=ease(p)
  local d=Vector3.yAxis:Cross(n)
  return function(tile)
   if not tile.side then return nil end
   return n*(tile.side*.85*e)-Vector3.yAxis*(.2*e),CFrame.fromAxisAngle(d,tile.side*math.rad(17)*e)
  end
 end,extra=function(self,proxy,rec,p)
  local seam=proxy.seam
  if not seam or not proxy.normal or not proxy.planeAt then return end
  local len=2.1*math.max(rec.radius,1)*ease(math.min(1,p*1.4))
  seam.Transparency=len>.05 and .15 or 1
  seam.Size=Vector3.new(.16,.08,math.max(.05,len))
  -- Size Z runs along the seam (the frame's Z axis is normal x up).
  seam.CFrame=CFrame.fromMatrix(proxy.planeAt,proxy.normal,Vector3.yAxis)
 end}
 SIG.G={build=function(self,proxy)
  proxy.bars={}
  local R=math.max(proxy.radius,1)
  for axis=1,2 do
   for k=1,5 do
    local at=-R+(k-.5)*(2*R/5)
    if math.abs(at)<R*.95 then
     table.insert(proxy.bars,{part=neon(proxy.model,'GridLine',proxy.primary:Lerp(Color3.new(1,1,1),.3)),axis=axis,at=at,chord=2*math.sqrt(R*R-at*at),start=(at+R)/(2*R)})
    end
   end
  end
 end,tiles=function(self,proxy,rec,p)
  if not proxy.sweepSet then
   proxy.sweepSet=true
   local lo,hi=math.huge,-math.huge
   for _,t in ipairs(rec.tiles) do local s=t.cx+t.cz*.3;lo=math.min(lo,s);hi=math.max(hi,s) end
   for _,t in ipairs(rec.tiles) do t.sweepAt=hi>lo and ((t.cx+t.cz*.3)-lo)/(hi-lo)*.8 or 0 end
  end
  return function(tile)
   local u=math.clamp((p-(tile.sweepAt or 0))/.14,0,1)
   if u<=0 then return nil end
   return Vector3.new(0,-.45*u,0),nil,tile.stone:Lerp(proxy.primary,.22*u):Lerp(Color3.new(0,0,0),.16*u)
  end
 end,extra=function(self,proxy,rec,p)
  local top=proxy.pivot+Vector3.yAxis*.07
  for _,b in ipairs(proxy.bars or {}) do
   -- Lines along one axis sweep in first, then the cross lines.
   local u=math.clamp((p*(b.axis==1 and 1.5 or 1.2)-(b.axis==1 and 0 or .3)-b.start*.5)/.4,0,1)
   local len=b.chord*u
   b.part.Transparency=len>.05 and .2 or 1
   if b.axis==1 then
    b.part.Size=Vector3.new(.08,.06,math.max(.05,len));b.part.CFrame=CFrame.new(top+Vector3.new(b.at,0,0))
   else
    b.part.Size=Vector3.new(math.max(.05,len),.06,.08);b.part.CFrame=CFrame.new(top+Vector3.new(0,0,b.at))
   end
  end
 end}
 SIG.Y={tiles=function(self,proxy,rec,p)
  local e=ease(p)
  local spin=1.4*e
  local pull=.62*e
  local R=math.max(rec.radius,1)
  local c,s=math.cos(spin),math.sin(spin)
  return function(tile)
   local x,z=tile.cx,tile.cz
   local nx,nz=(x*c-z*s)*(1-pull),(x*s+z*c)*(1-pull)
   local r=math.sqrt(x*x+z*z)/R
   return Vector3.new(nx-x,-.9*e*(1-.5*r),nz-z),CFrame.Angles(0,-spin,0)
  end
 end}
 SIG.M={tiles=function(self,proxy,rec,p)
  local h=proxy.hit or Vector3.zero
  local front=(rec.radius+1.2)*p^.85
  local e=ease(p)
  return function(tile)
   local d=dist(tile,h)
   local heat=math.clamp((front-d)/1.8,0,1)
   if heat<=0 then return nil end
   local col=tile.stone:Lerp(MOLTEN,.52*heat)
   if d<1.3 then col=col:Lerp(WHITEHOT,.4*heat) end
   return Vector3.new(0,-.6*heat*e,0),CFrame.Angles(.06*heat*math.sin(tile.cx*3),0,.06*heat*math.cos(tile.cz*3)),col
  end
 end}
 SIG.I={tiles=function(self,proxy,rec,p,now)
  local h=proxy.hit or Vector3.zero
  local front=(rec.radius+.8)*math.min(1,p*1.25)
  local shiver=math.clamp((p-.75)/.25,0,1)
  local frame=math.floor(now*8)
  return function(tile,i)
   if dist(tile,h)>front then return nil end
   local off=nil
   if shiver>0 then
    local q=frame*1.7+i*2.3
    off=Vector3.new(math.noise(q,i,.1),math.noise(i,q,.4)*.5,math.noise(q,.5,i))*(.12*shiver)
   end
   return off,nil,tile.stone:Lerp(ICE,.62),nil,Enum.Material.Ice
  end
 end}
 SIG.V={every=.42,ring={amp=.24,speed=14,width=.9,glow=.45},tiles=function(self,proxy,rec,p,now)
  local a=.02+.18*p^1.4
  local frame=math.floor(now*8)
  return function(tile,i)
   local q=frame*.91+i*3.7
   return Vector3.new(math.noise(q,i,.2),math.noise(i,q,.6)*.6,math.noise(.3,i,q))*(a*2)
  end
 end}
 SIG.Z={ring={amp=.3,speed=20,width=.8,glow=.5},tiles=function(self,proxy,rec,p,now)
  local h=proxy.hit or Vector3.zero
  local n=proxy.hits or 0
  local reach=.9+.45*n
  local deep=math.min(2.4,.45*n)
  local flash=math.clamp(1-(now-(proxy.hitAt or -9))/.16,0,1)
  return function(tile)
   local k=math.clamp(1-dist(tile,h)/reach,0,1)
   if k<=0 then return nil end
   return Vector3.new(0,-deep*k,0),nil,flash>0 and tile.color:Lerp(proxy.primary,.5*flash*k) or nil
  end
 end}
end
V.SIG=SIG
-- A signature type's piece: its hits ring the rock, its process runs on
-- the stop-motion grid with the rest of the chunk work.
function V:stepSignature(proxy: any,rec: any,now: number,cutting: boolean?)
 local def=proxy.sig
 local reduced=self:reduced()
 local function hit()
  proxy.hits=(proxy.hits or 0)+1;proxy.hitAt=now
  local r=def.ring
  if r and not reduced then RockChunks.ring(rec,now,proxy.hit,r.amp,r.speed,r.width,r.glow) end
 end
 if proxy.slamAt and proxy.slamAt~=proxy.meshSlam then proxy.meshSlam=proxy.slamAt;hit() end
 if proxy.pulseAt and proxy.pulseAt~=proxy.meshPulse then proxy.meshPulse=proxy.pulseAt;hit() end
 if def.every and cutting and not reduced and now-(proxy.ringAt or -9)>=def.every then
  proxy.ringAt=now
  local r=def.ring
  RockChunks.ring(rec,now,proxy.hit,r.amp,r.speed,r.width,r.glow)
 end
 if now-(proxy.meshAt or -1)<(proxy.owned and 1/31 or 1/12) then return end
 proxy.meshAt=now
 local p=math.clamp(proxy.progress or 0,0,1)
 local fn=def.tiles(self,proxy,rec,p,now)
 if fn and reduced then
  -- Reduced Motion: the colors and the result, less of the motion.
  local inner=fn
  fn=function(tile,i,t)
   local off,turn,col,hide,mat=inner(tile,i,t)
   return off and off*.4 or nil,nil,col,hide,mat
  end
 end
 if def.extra then def.extra(self,proxy,rec,p) end
 local tremble=(proxy.code=='B' and not reduced) and .015+.08*p*p or nil
 RockChunks.step(rec,now,{glowColor=proxy.primary:Lerp(Color3.new(1,1,1),.25),sig=fn,tremble=tremble})
end
function V:stepMesh(proxy: any,now: number,cutting: boolean?)
 local rec=proxy.mesh
 if not rec or proxy.dead then return end
 if proxy.sig then self:stepSignature(proxy,rec,now,cutting);return end
 local reduced=self:reduced()
 local m=proxy.fx.mesh or MESH_DEFAULT
 local progress=math.clamp(proxy.progress or 0,0,1)
 local kernel=DigCube.style(proxy.code).kernel
 local random=self.random
 local burst=BURST[proxy.code or 'L'] or BURST.L
 local small=reduced and .5 or 1
 -- Hits: a slam, a pulse, a dart (a jump in the work): the crack pop.
 if proxy.slamAt and proxy.slamAt~=proxy.meshSlam then
  proxy.meshSlam=proxy.slamAt
  RockChunks.burst(rec,now,proxy.hit,burst,random,1.3*small)
 end
 if proxy.pulseAt and proxy.pulseAt~=proxy.meshPulse then
  proxy.meshPulse=proxy.pulseAt
  RockChunks.burst(rec,now,proxy.hit,burst,random,small)
 end
 local last=proxy.meshProgress or progress
 proxy.meshProgress=progress
 if m.hits and progress-last>=.02 then
  local a=random:NextNumber(0,math.pi*2);local r=random:NextNumber(0,proxy.radius*.8)
  RockChunks.burst(rec,now,proxy.hit,burst,random,small,Vector3.new(math.cos(a)*r,0,math.sin(a)*r))
 end
 if m.charge then
  -- Chunks work loose as the charge builds: none before m.charge, about
  -- half the tiles by the end, each a small crack pop.
  local want=math.floor(math.clamp((progress-m.charge)/(1-m.charge),0,1)*#rec.tiles*.5)
  if want>proxy.pops then
   proxy.pops+=1
   RockChunks.burst(rec,now,proxy.hit,burst,random,(.6+.6*progress)*small)
  end
 end
 -- Beam roles: small crack pops all through each piece's work (at each
 -- third of the way to its crack), then the big one at the crack (crackHit).
 if kernel=='beam' and cutting then
  local mark=(proxy.step or 0)==0 and math.floor(math.clamp(proxy.within or 0,0,.999)*3) or 3
  local key=(proxy.piece or 0)*10+mark
  if mark>0 and mark<3 and key~=proxy.burstMark then
   proxy.burstMark=key
   RockChunks.burst(rec,now,proxy.hit,burst,random,.7*small)
  end
 end
 -- Throttle the vertex work: your own at 30 Hz, others' at 12 Hz.
 if now-(proxy.meshAt or -1)<(proxy.owned and 1/31 or 1/12) then return end
 proxy.meshAt=now
 local state={glowColor=proxy.primary:Lerp(Color3.new(1,1,1),.25),slide=proxy.slideVec,scale=proxy.scale}
 if m.ripple and kernel=='beam' and cutting and not reduced then
  local r=m.ripple
  local beat=.7+.3*math.sin(now*math.pi*2*(r.beat or 2.2))
  state.ripple={amp=1.8*r.amp*(.55+.45*math.clamp(proxy.within or 0,0,1))*beat,len=r.len,speed=r.speed,square=r.square,glow=r.glow,center=proxy.hit}
 end
 if m.bulge then state.bulge=m.bulge*progress end
 if m.tremble and not reduced then state.tremble=m.tremble*progress*progress end
 RockChunks.step(rec,now,state)
end
-- Called every frame per cutting drone with its chunk's progress. `key` is
-- the chunk's ids string, `code` the role's style code (its pieces mode and
-- ROLE_FX treatment). A terrace stage that already broke (cutStage) never
-- shows again, even while the progress catches up.
function V:crackStage(key: string,progress: number,now: number,tint: Color3,owned: boolean,cutting: boolean?,code: string?,source: Instance?)
 local job=self.cracks[key]
 if job and job.code~=code then
  if job.proxy then self:dropProxy(job.proxy) end
  job=nil
 end
 if not job then
  job={ids=DigCube.parseKey(key),code=code}
  job.pieces=DigCube.pieces(self.cube,job.ids,DigCube.style(code).pieces)
  self.cracks[key]=job
  -- A chunk already part-cut when first seen starts at its stage, without the hit.
  job.stage=self:crackIndex(job,math.min(progress,.9999))
 end
 job.seen=now
 -- Full progress keeps the last piece up (popped, straining) until its break op.
 local index,within=self:crackIndex(job,math.min(progress,.9999))
 local k=math.floor(index/CRACK_STEPS)+1
 local step=index%CRACK_STEPS
 local cut=self.cutStage[key] or 0
 if k<=cut then k=cut+1;step=0;within=0;index=(k-1)*CRACK_STEPS end
 -- A piece stays up (popped, straining) until its own break op: the server
 -- carves it ahead, so the next piece must not show before that op lands.
 if k>cut+1 then k=cut+1;step=CRACK_STEPS-1;within=1;index=(k-1)*CRACK_STEPS+step end
 local piece=job.pieces[k]
 if not piece then return end
 if job.proxy and (job.proxy.dead or job.piece~=k) then
  if not job.proxy.dead then self:dropProxy(job.proxy) end
  job.proxy=nil
 end
 if not job.proxy then
  job.proxy=self:buildProxy(piece,owned,job.ids,code);job.piece=k
  if job.proxy then
   job.proxy.step=step;self:poseProxy(job.proxy,now)
   -- The stage before this one just broke: the whole piece jumps and twists.
   if k>1 and job.proxy.mesh and not self:reduced() then RockChunks.hop(job.proxy.mesh,now,self.random,1) end
  end
 end
 local proxy=job.proxy
 if not proxy then return end
 local fx=proxy.fx
 progress=math.clamp(progress,0,1)
 proxy.progress=progress;proxy.within=within
 local point=source and source:GetAttribute('DigPoint')
 if typeof(point)=='Vector3' then proxy.hit=Vector3.new(point.X-proxy.pivot.X,0,point.Z-proxy.pivot.Z) end
 proxy.slamAt=job.slamAt;proxy.pulseAt=job.pulseAt
 if proxy.highlight then
  -- Pulses while the drone works on it (owner, Nov 22), a quick strong beat
  -- toward white; steady and faint while it only charges or travels.
  if cutting then
   proxy.pulseStart=proxy.pulseStart or now
   local wave=.5+.5*math.cos((now-proxy.pulseStart)*9)
   proxy.highlight.OutlineTransparency=.7-.68*wave
   proxy.highlight.OutlineColor=proxy.outline:Lerp(Color3.new(1,1,1),.55*wave)
  else
   proxy.pulseStart=nil
   proxy.highlight.OutlineTransparency=.55;proxy.highlight.OutlineColor=proxy.outline
  end
 end
 -- Darker as the drone works, back to full color at each crack (or the
 -- role's own tone and curve: over a charge, or only at its end).
 local amount
 if fx.src=='progress' then amount=progress
 elseif fx.src=='late' then amount=math.clamp((progress-.7)/.3,0,1)
 else amount=math.clamp(within,0,1)^(fx.pow or .88) end
 self:shadeProxy(proxy,(fx.cap or CRACK_SHADE)*amount)
 if proxy.light then proxy.light.Brightness=proxy.sig and 2.2*progress or .9*math.clamp(within,0,1)^1.5 end
 if fx.ice and progress>=fx.ice and not proxy.iced then
  proxy.iced=true
  for _,e in ipairs(proxy.parts) do e.part.Material=Enum.Material.Ice end
  if proxy.mesh then RockChunks.setMaterial(proxy.mesh,Enum.Material.Ice) end
 end
 if fx.compress then
  local scale=1-fx.compress*progress
  if math.abs(scale-proxy.scale)>.01 then
   proxy.scale=scale
   for _,e in ipairs(proxy.parts) do e.part.Size=e.size*scale end
  end
 end
 if proxy.ball then
  local size=2.3*proxy.radius*progress
  if math.abs(size-proxy.ballSize)>.02 then proxy.ballSize=size;proxy.ball.Size=Vector3.one*math.max(.05,size) end
 end
 if index>job.stage then
  job.stage=index
  if step>0 and step~=proxy.step then
   proxy.step=step;proxy.joltAt=now
   self:crackHit(proxy,step,k,{tint=tint,owned=owned})
  end
 end
 self:poseProxy(proxy,now)
 self:stepMesh(proxy,now,cutting)
end
function V:crackHit(proxy: any,step: number,k: number,hit: any)
 local point=proxy.pivot+Vector3.yAxis*(CRACK_LIFT[step+1]+.1)
 local volume=hit.owned and 1 or .55
 if proxy.sig then
  -- A signature type's process is its own feedback; the crack is heard.
  if self.ctx.audio then self.ctx.audio:play('crystal_impact',point,{pitch=.8+self.random:NextNumber(-.03,.03),level=volume*.4}) end
  return
 end
 if proxy.mesh then
  local now=os.clock()
  local burst=BURST[proxy.code or 'L'] or BURST.L
  RockChunks.burst(proxy.mesh,now,proxy.hit,burst,self.random,(self:reduced() and .5 or 1)*(1.2+.3*k))
  if not self:reduced() then RockChunks.hop(proxy.mesh,now,self.random,.7) end
 end
 local ctx=self.ctx
 if ctx.crack then ctx.crack:playCrack(point) end
 if ctx.audio then
  ctx.audio:play('crystal_impact',point,{pitch=.72+.09*step+.04*k+self.random:NextNumber(-.03,.03),level=volume*(.32+.14*step)})
 end
 -- A crack is a small beat: the piece pops loose (the motion is the effect),
 -- a crack sound, a couple of chips. No ring or dust; those belong to breaks.
 if self:reduced() or not hit.owned then return end
 local serverNow=workspace:GetServerTimeNow()
 local rock=self.holder and self.holder:FindFirstChild('Rock')
 local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
 if ctx.impact and surface then ctx.impact:chips(serverNow,point,Vector3.yAxis,surface,1+step,point.Y-4) end
 if ctx.beat then ctx.beat('Split',point,serverNow,.14+.08*step) end
end
-- A piece nobody is cutting any more goes quickly (its break op normally
-- clears it first): no outline hangs on after the rock has gone.
function V:stepCracks(now: number)
 for key,job in pairs(self.cracks) do
  if now-(job.seen or now)>.3 then
   self.cracks[key]=nil
   if job.proxy then self:dropProxy(job.proxy) end
  elseif job.proxy and not job.proxy.dead and now-job.proxy.joltAt<CRACK_JOLT then
   self:poseProxy(job.proxy,now)
  end
 end
end
function V:split(op: any,now: number)
 local cube=self.cube;local o=self.origin
 local parts=self:opParts(op)
 if #parts==0 then return end
 local area,cx,cz,volume,top,bottom=0,0,0,0,-math.huge,math.huge
 for _,q in ipairs(parts) do
  local a,mx,mz=middle(q.poly)
  area+=a;cx+=mx*a;cz+=mz*a;volume+=a*(q.y1-q.y0)
  top=math.max(top,q.y1);bottom=math.min(bottom,q.y0)
 end
 if area<=0 then return end
 cx/=area;cz/=area
 local bulk=math.max(volume,.5)^(1/3)
 local center=o+Vector3.new(cx,(top+bottom)*.5,cz)
 -- The role that broke it sets the colors, the rubble and the beat.
 local style=self:opStyle(op)
 local fx=ROLE_FX[style.code] or ROLE_FX.L
 local primary=V.primaryColor(style.code)
 local owned,accent=false,nil
 for _,id in ipairs(op.cells) do
  self:clearCrack(id)
  if self.mine[id] then owned=true end
  if op.geode then
   local player=Players.LocalPlayer
   owned=self.localOpened[id]==true or (self.geodeOwner[id]~=nil and player~=nil and self.geodeOwner[id]==player.UserId)
   -- Your own stays on screen through the freeze (it shakes); others go now.
   if not owned or self:reduced() then self:dropGeode(id) elseif self.geodes[id] then self.geodes[id].opening=true end
  end
  accent=accent or self.cellAccent[id]
  -- A nested stage leaves the chunk's cells (and who is cutting them) in
  -- place; so do the cells that sealed (their K beat still needs them).
  if not op.staged and not (op.except and op.except[id]) then
   self.mine[id]=nil;self.cellColor[id]=nil;self.cellCode[id]=nil;self.cellAccent[id]=nil
  end
 end
 accent=accent or primary
 -- Resonator chain links pop without a pause of their own. The server
 -- breaks them itself (neighbour cells, never in a DigOp), so one right
 -- after your own Resonator break counts as yours.
 local link=op.flag=='C' and style.code=='V'
 if link and not owned then owned=self:ownChainLink(op.cells[1],now)
 elseif style.code=='V' and owned and op.flag~='C' and not op.partial and not op.geode then self:markChain(op.cells,now) end
 local strength=math.clamp(bulk*.36,.9,2.45)
 local heavy=owned and strength>=1.35
 local hold=0
 if owned and not self:reduced() and (op.tier>0 or now-(self.heldAt or -10)>=(op.partial and .9 or .3)) then
  -- A gem always gets the long pause; otherwise the role's hold class.
  local class=fx.hold
  if op.geode then hold=HOLD_GEODE
  elseif op.tier>0 then hold=HOLD_GEM
  elseif op.partial then hold=HOLD_PIECE
  elseif link then hold=0
  elseif class=='piece' then hold=HOLD_PIECE
  elseif class=='split' then hold=HOLD_SPLIT
  elseif class=='heavy' then hold=HOLD_HEAVY
  else hold=heavy and HOLD_HEAVY or HOLD_SPLIT end
  if hold>0 then self.heldAt=now end
 end
 -- Opening your sealed gem: the whole game freezes for the hold (the client
 -- hit-stop: world, drones, particles, you and the camera), then it breaks
 -- and bounces you straight up.
 local gem=op.tier>0 and rgb(DigCube.ORES[math.clamp(op.tier,1,#DigCube.ORES)].color) or nil
 local tense=op.geode and owned and hold>0
 if tense then
  -- The freeze reads as tension, not lag: the sealed cell keeps shaking
  -- (hard at first, settling), its cracks blaze up, the rays flare, a deep
  -- crack sounds on the very first frame, and the camera punches in.
  local id=op.cells[1]
  -- The loudest crack cuts (the large rock pool), at full level, with the
  -- crystal crack and a heavy impact under them, on the very first frame.
  if self.ctx.audio then
   self.ctx.audio:play('crystal_split',center,{level=1.7,rockSize=9})
   self.ctx.audio:play('crystal_impact',center,{pitch=.8,level=1.4,rockSize=9})
  end
  if self.ctx.crack then self.ctx.crack:playCrack(center) end
  if self.ctx.freeze then
   self.ctx.freeze(hold,{tint=gem,onFrame=function(u) self:tenseGeode(id,u) end})
  end
 end
 if op.geode and owned then
  local at=center;local id=op.cells[1]
  -- Jumping from one sealed gem to the next without touching the ground
  -- is a combo: each crack after the pause rings a step higher (owner,
  -- Nov 22). stepGeodes resets it once you stand on solid ground.
  local combo=tense and self:geodeCombo() or 1
  table.insert(self.pending,{at=now+hold,run=function()
   self:dropGeode(id);self:bounce(at)
   local audio=self.ctx.audio
   local pitch=math.min(2.2,1+.12*(combo-1))
   if audio then
    audio:play('crystal_split',at,{pitch=pitch,level=1.5+.08*math.min(combo,6),rockSize=9})
    audio:play('crystal_release_tink',at,{pitch=pitch*1.05,level=1.1})
   end
  end})
 end
 local glow=owned and (gem~=nil or not op.partial)
 -- Gems override the role's color.
 local flashColor=gem and gem:Lerp(FLASH,.2) or primary:Lerp(FLASH,.3)
 if tense then
  -- Flash and rubble come with the break, after the freeze.
  table.insert(self.pending,{at=now+hold,run=function() self:flash(op,os.clock(),os.clock()+.04,flashColor,glow) end})
 else
  self:flash(op,now,now+hold+.04,flashColor,glow)
 end
 -- Loose physics rubble only for the final cut (owner, Nov 22); a nested
 -- stage is just its outline growing (the flash over its shell).
 -- Rubble flies out from where the hit was: the chunk's center (the
 -- drone's contact point), or the top of a volley's seed cell.
 if not op.partial then
  local from
  local seed=fx.rubble.seed and cube.cells[op.cells[1]]
  if seed then from=o+Vector3.new(seed.cx,seed.y1,seed.cz)
  else
   local bx,bz=DigCube.chunkCenter(cube,op.cells)
   from=o+Vector3.new(bx,center.Y,bz)
  end
  if tense then table.insert(self.pending,{at=now+hold,run=function() self:shards(op,os.clock(),from,fx.rubble) end})
  else self:shards(op,now+hold,from,fx.rubble) end
 end
 -- Spread over a big break (spreadPoints); its reach from the middle.
 local spots=op.partial and {} or self:spreadPoints(op)
 local extent=0
 for _,q in ipairs(parts) do for _,v in ipairs(q.poly) do extent=math.max(extent,math.sqrt((v[1]-cx)^2+(v[2]-cz)^2)) end end
 local info={center=center,point=o+Vector3.new(cx,top,cz),ground=o.Y+bottom,bulk=bulk,strength=strength,owned=owned,heavy=heavy,spots=spots,extent=extent,role=style.role,
  color=self:colorAt(top-.01,cx,cz),primary=primary,accent=accent,fx=fx,link=link}
 -- The break's particles take the drone type's look (a gem's stay its own).
 local function beat()
  if self.ctx.withRole and op.tier<=0 then self.ctx.withRole(style.role,function() self:burst(op,info) end)
  else self:burst(op,info) end
 end
 if hold>0 then table.insert(self.pending,{at=now+hold,run=beat})
 else beat() end
end
-- Your own Resonator break: its cells and their same-layer neighbours, the
-- only cells its chain links can be (up to three, .15 s apart), for a
-- moment. A link op landing in one of them is yours.
local CHAIN_WINDOW=.8
function V:markChain(cells: {number},now: number)
 self:ownChainLink(-1,now) -- drops the expired ones
 local set={}
 for _,id in ipairs(cells) do
  set[id]=true
  local c=self.cube.cells[id]
  if c then for _,n in ipairs(c.neighbors) do set[n]=true end end
 end
 table.insert(self.chains,{at=now,cells=set})
end
function V:ownChainLink(id: number,now: number): boolean
 local mine=false
 for i=#self.chains,1,-1 do
  local chain=self.chains[i]
  if now-chain.at>=CHAIN_WINDOW then table.remove(self.chains,i)
  elseif chain.cells[id] then mine=true end
 end
 return mine
end
-- A cell that sealed into a geode (K): the crack-seal beat. The piece stops,
-- a gem-colored flash over the cell, a crack and a couple of chips. No
-- rubble and no streaks; the sealed cell itself comes from syncGeodes.
function V:sealBeat(op: any,now: number)
 local ctx=self.ctx
 local owned=false
 for _,id in ipairs(op.cells) do
  self:clearCrack(id)
  if self.mine[id] then owned=true end
  self.mine[id]=nil;self.cellColor[id]=nil;self.cellCode[id]=nil;self.cellAccent[id]=nil
 end
 local c=self.cube.cells[op.cells[1]]
 if not c then return end
 local gem=rgb(DigCube.ORES[math.clamp(op.tier,1,#DigCube.ORES)].color)
 local hold=0
 if owned and not self:reduced() and now-(self.heldAt or -10)>=.3 then hold=HOLD_PIECE;self.heldAt=now end
 self:flash(op,now,now+hold+.04,gem:Lerp(FLASH,.2),owned)
 local point=self.origin+Vector3.new(c.cx,c.y1+.1,c.cz)
 if ctx.crack then ctx.crack:playCrack(point) end
 if ctx.audio then ctx.audio:play('crystal_impact',point,{pitch=.8,level=.9*(owned and 1 or .62)}) end
 if self:reduced() then return end
 local rock=self.holder and self.holder:FindFirstChild('Rock')
 local surface=rock and rock:FindFirstChildWhichIsA('BasePart')
 if ctx.impact and surface then ctx.impact:chips(workspace:GetServerTimeNow(),point,Vector3.yAxis,surface,2,point.Y-4) end
end
-- The break's sparks (primary to accent), from a box the size of each broken
-- cell, so they start exactly in the rock that broke. The spinning
-- rectangles are gone: the 3D streaks (burst) are the one lingering layer.
local CLOUD_CELLS=4 -- fewer, so a break reads as one beat, not a cloud
function V:breakCloud(op: any,e: any,big: boolean)
 if self:reduced() or (self.clouds or 0)>=8 then return end
 local o=self.origin
 local cells={}
 -- The round spark discs stay by the beam (owner, Nov 22): the cells
 -- nearest the chunk's middle, within a few studs.
 local hub=op.hub or Vector3.zero
 local near={}
 for _,q in ipairs(self:opParts(op)) do
  local _,mx,mz=middle(q.poly)
  local d=(mx-hub.X)^2+(mz-hub.Z)^2
  if not op.hub or d<=3.5*3.5 then table.insert(near,{q=q,d=d}) end
 end
 table.sort(near,function(a,b) return a.d<b.d end)
 for i,entry in ipairs(near) do
  if i>CLOUD_CELLS then break end
  local q=entry.q
  local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
  for _,v in ipairs(q.poly) do minX=math.min(minX,v[1]);maxX=math.max(maxX,v[1]);minZ=math.min(minZ,v[2]);maxZ=math.max(maxZ,v[2]) end
  local _,mx,mz=middle(q.poly)
  if maxX-minX>.2 and maxZ-minZ>.2 then
   table.insert(cells,{minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ,y0=q.y0,y1=q.y1,cx=mx,cz=mz})
  end
 end
 if #cells==0 then return end
 local holder=Instance.new('Folder');holder.Name='DigBreakCloud';holder.Parent=self.fx
 self.clouds=(self.clouds or 0)+1
 holder.Destroying:Connect(function() self.clouds-=1 end)
 local k=big and 1 or .65
 local bulk=math.clamp(e.bulk,1.5,5)
 local share=1/#cells
 local function count(n: number): number
  -- Spread across the cells, at least one each when there is any to give.
  local x=n*k*share
  return math.floor(x)+(self.random:NextNumber()<x%1 and 1 or 0)
 end
 for _,c in ipairs(cells) do
  local box=fxPart(holder,'Cell',e.primary);box.Transparency=1
  box.Size=Vector3.new(math.max(.4,(c.maxX-c.minX)*.8),math.max(.4,(c.y1-c.y0)*.8),math.max(.4,(c.maxZ-c.minZ)*.8))
  box.Position=o+Vector3.new(c.cx,(c.y0+c.y1)*.5,c.cz)
  -- Sparks in the role's colors: bright and quick; they carry the glow.
  local sparks=Instance.new('ParticleEmitter');sparks.Name='Sparks';sparks.Enabled=false;sparks.Rate=0
  sparks.Shape=Enum.ParticleEmitterShape.Box;sparks.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
  sparks.LockedToPart=false;sparks.Parent=box
  EnergyDisc.configure(sparks,.5*k,.05,1,0,.35)
  sparks.LightEmission=.7;sparks.LightInfluence=0;sparks.Brightness=1.5
  sparks.Color=ColorSequence.new(e.primary:Lerp(BEAM_CORE,.35),e.accent)
  sparks.Lifetime=NumberRange.new(.4,.8);sparks.Speed=NumberRange.new(14,28);sparks.SpreadAngle=Vector2.new(70,70)
  sparks.EmissionDirection=Enum.NormalId.Top;sparks.Acceleration=Vector3.new(0,-30,0);sparks.Drag=1.5
  if self.ctx.styleParticle and e.role then pcall(self.ctx.styleParticle,sparks,e.role) end
  sparks:Emit(count(4+1.5*bulk))
 end
 task.delay(1.2,function() holder:Destroy() end)
end
-- Where a break's effects go (owner, Nov 22: a drone that breaks a TON of
-- cells needs its effects spread over all of them, not one cell's worth in
-- the middle): up to 6 points over the broken rock, about one per 12 square
-- studs, picked far apart (the biggest part first). Each {pos=top surface,
-- area=its share}. One point for an ordinary single-cell break.
function V:spreadPoints(op: any,most: number?): {any}
 local o=self.origin
 local parts={}
 local total=0
 for _,q in ipairs(self:opParts(op)) do
  local a,mx,mz=middle(q.poly)
  if a>.05 then table.insert(parts,{a=a,x=mx,z=mz,y=q.y1,poly=q.poly,y0=q.y0});total+=a end
 end
 if #parts==0 then return {} end
 local n=math.clamp(math.floor(total/12+.5),1,most or 6)
 table.sort(parts,function(a,b) return a.a>b.a end)
 local picked={parts[1]}
 while #picked<math.min(n,#parts) do
  local best,score=nil,-1
  for _,q in ipairs(parts) do
   local d=math.huge
   for _,p in ipairs(picked) do d=math.min(d,(q.x-p.x)^2+(q.z-p.z)^2) end
   if d>score then best,score=q,d end
  end
  if not best or score<=1e-6 then break end
  table.insert(picked,best)
 end
 local out={}
 for _,q in ipairs(picked) do table.insert(out,{pos=o+Vector3.new(q.x,q.y,q.z),area=total/#picked,part=q}) end
 return out
end
-- One clear beat per break, in the breaking role's way (ROLE_FX): its
-- sounds, its contact (a ring and particles; none for projectile roles,
-- whose ring and burst RoleEffectView draws, or the Lancer's pulse), a light,
-- the 3D streaks (at most five boxes) and the camera hit. Your own breaks
-- get the light, the contact and the second streak color; other players'
-- breaks play smaller and without them, so your own crew's work stands out.
function V:burst(op: any,e: any)
 local ctx=self.ctx
 local now=workspace:GetServerTimeNow()
 local point,ground,strength=e.point,e.ground,e.strength
 local volume=e.owned and 1 or .62
 local vivid=e.color:Lerp(Color3.fromRGB(255,246,226),.62)
 local primary=e.primary or vivid
 local fx=e.fx or ROLE_FX.L
 local lively=not self:reduced()
 local gem=op.tier>0
 if op.partial then
  -- A stage of a chunk breaks: a step toward the full split, kept small.
  if ctx.audio then
   ctx.audio:play('crystal_impact',point,{pitch=.88+.14*(op.stage or 1)+self.random:NextNumber(-.03,.03),level=volume*.9,rockSize=e.bulk})
   ctx.audio:play('crystal_release_tink',point,{level=volume*.5,pitch=1+.1*(op.stage or 1)})
  end
  if lively then
   if e.owned then
    self:lightFlash(e.center,primary,10+2*e.bulk,4,.3)
    if ctx.beat then ctx.beat('Split',point,now,.45) end
   end
  end
  return
 end
 if ctx.audio then
  if fx.sounds=='classic' then
   ctx.audio:play('crystal_split',point,{level=volume,rockSize=e.bulk})
   ctx.audio:play('crystal_impact',point,{level=volume*math.clamp(strength,.9,1.25)})
   ctx.audio:play('crystal_release_tink',point,{level=volume})
  else
   for _,cue in ipairs(fx.sounds) do
    -- Sequence breaks climb (the Gridcutter zipper, Resonator chain links).
    ctx.audio:play(cue.cue,point,{pitch=(cue.pitch or 1)+(cue.seq or 0)*(op.seq or 0),level=volume*(cue.level or 1),rockSize=cue.rock or e.bulk})
   end
  end
 end
 -- A gem bursts out with the rock, not after it, and its color takes over.
 if gem then self:reveal({tier=op.tier,treasure=op.treasure,center=e.center+Vector3.yAxis*1.2,ground=ground,size=e.bulk,owned=e.owned,op=op},os.clock()) end
 if not lively then return end
 if not gem and fx.contact then
  op.hub=e.point-self.origin
  self:breakCloud(op,{primary=primary,accent=e.accent or primary,bulk=e.bulk,role=e.role},e.owned)
 end
 -- The 3D streaks (owner: the old rectangles): in the rock's tone, plus two
 -- in the role's color for your own breaks; at most five, so only the
 -- streak boxes (no embers). A gem's reveal carries its own.
 if not gem and ctx.impact then
  local opts={life=1.3,lift=fx.lift or 1,speed=fx.speed or 1,cap=24}
  local spots=e.spots or {}
  if #spots>1 then
   -- A big break: streaks over every part of it, sized for each part.
   for i,spot in ipairs(spots) do
    local s=math.clamp(math.sqrt(spot.area)*.36,.8,1.8)
    ctx.impact:fireworks(spot.pos,ground,vivid,s*2.4,now,2,opts)
    if e.owned and i<=3 then ctx.impact:fireworks(spot.pos,ground,primary,s*2.4,now,1,opts) end
   end
  else
   ctx.impact:fireworks(point,ground,vivid,strength*2.4,now,3,opts)
   if e.owned then ctx.impact:fireworks(point,ground,primary,strength*2.4,now,2,opts) end
  end
 end
 -- The camera hit (and the climbing tink of a streak), shared with the
 -- field rocks; a chain link is a small one.
 local beat=e.link and strength*.6 or strength
 if ctx.splitBeat then ctx.splitBeat(point,beat,now,false,e.owned,nil)
 elseif ctx.beat then ctx.beat(e.heavy and 'HeavySplit' or 'Split',point,now,math.clamp(beat*.58,.6,1.35)*volume) end
 if not e.owned or gem then return end
 if fx.light then self:lightFlash(e.center,primary,14+3*e.bulk,7,.45) end
 local effects=ctx.effects
 local contact=fx.contact
 if not effects or not contact then return end
 local floor=Vector3.new(point.X,ground+.085,point.Z)
 -- The round things (contact particles, rings, specialist contacts) stay
 -- at the beam (owner, Nov 22); only the 3D streaks spread over a big break.
 if contact=='Striker' then
  effects.Pulse(floor,primary:Lerp(BEAM_CORE,.3),strength*.55,strength*6.6,.58)
  -- The field rocks' CrystalBreak burst is gone from dig breaks (owner,
  -- Nov 22: effects should show things, not be overused): its lingering
  -- drifting dust became big gold blobs over the dig, on top of the break's
  -- own sparks, ring and streaks, which still mark it.
 elseif contact=='Charger' then
  effects.Pulse(floor,primary,strength*.55,strength*8,.58,nil,1.6)
  -- (No Touchdown burst: the ring and the stamped crater say it.)
 elseif contact=='Resonator' and e.link then
  effects.Pulse(floor,primary,.3,3,.3)
 elseif effects.SpecialistContact then
  if contact=='Bubbler' then
   -- The rubble floats up, then the bubble pops.
   local at=point+Vector3.yAxis*1.2
   table.insert(self.pending,{at=os.clock()+.7,run=function() effects.SpecialistContact('Bubbler',at,Vector3.yAxis,false,MUTE,primary) end})
  else
   effects.SpecialistContact(contact,point,Vector3.yAxis,false,MUTE,primary)
  end
  if contact=='Resonator' then
   -- Two rings, a beat apart, ringing out across the pit.
   local accent=e.accent or primary
   effects.Pulse(floor,accent,.4,10,.45)
   table.insert(self.pending,{at=os.clock()+.08,run=function() effects.Pulse(floor+Vector3.yAxis*.04,primary,.4,10,.45) end})
  end
 end
end

-- A gem: the one thing that should outshine everything else. Its color
-- takes over the break (flash, light, particles, rings), a light lingers on
-- the pit walls, and the camera hits twice. The dropped gem then carries its
-- own aura (PickupView).
function V:reveal(e: any,now: number)
 local ctx=self.ctx
 local color=rgb(DigCube.ORES[e.tier].color)
 local light=color:Lerp(Color3.new(1,1,1),.4)
 local serverNow=workspace:GetServerTimeNow()
 local weight=e.owned==false and .6 or 1
 if ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1+e.tier*.08,level=1}) end
 if not self:reduced() then
  local k=1+e.tier*.2
  self:lightFlash(e.center,color,(20+e.tier*3)*weight,10*weight,1.4)
  if ctx.effects then
   -- Gems get more than a plain break (owner, Nov 22): two waves of gem
   -- particles, discs in the gem's light color and two rings.
   ctx.effects.ImpactParticles(e.center,color,k*1.3,'GemReward')
   ctx.effects.ImpactParticles(e.center,light,k*1.1,'CrystalBreak',nil,color)
   ctx.effects.Pulse(Vector3.new(e.center.X,e.ground+.1,e.center.Z),color,.6,(4+e.tier*1.8)*weight,.55)
   task.delay(.1,function()
    ctx.effects.ImpactParticles(e.center+Vector3.yAxis*.6,light,k,'GemReward')
    ctx.effects.Pulse(e.center,light,.35,(2.5+e.tier)*weight,.35)
   end)
  end
  if ctx.impact then ctx.impact:fireworks(e.center,e.ground,light,(1.3+e.tier*.15)*2.2*weight,serverNow,e.owned==false and 6 or 12) end
  -- The rock's own break particles, in the gem's colors.
  if e.op then self:breakCloud(e.op,{primary=light,accent=color,bulk=math.max(3,e.size or 3)},e.owned~=false) end
  if e.op and e.op.geode then self:geodeBlast(e.center,e.ground,color,light,e.tier,weight,serverNow) end
  -- An impact you feel: a heavy shake, then a second hit a beat later.
  if ctx.beat then
   ctx.beat('HeavySplit',e.center,serverNow,(1.5+e.tier*.2)*weight)
   task.delay(.12,function() ctx.beat('Split',e.center,workspace:GetServerTimeNow(),(1+e.tier*.12)*weight) end)
  end
 end
 if e.treasure and not self:reduced() and ctx.effects then
  -- Jackpot: a treasure pocket pays several rare gems (no on-screen text).
  for i=1,2 do task.delay(i*.14,function() ctx.effects.ImpactParticles(e.center+Vector3.yAxis*i*.6,rgb(DigCube.ORES[((e.tier+i-2)%#DigCube.ORES)+1].color),1.2,'GemReward') end) end
 end
 if e.treasure and ctx.audio then ctx.audio:play('gem_reveal',e.center,{pitch=1.5,level=1}) end
end

-- Sealed gem cells (owner, Nov 22). When a chunk holds a gem, the server
-- keeps that one cell until its owner jumps on it. Here it is drawn split
-- into its pieces, each wiggling a little with anticipation (faster the
-- longer it waits), with a gem-colored glow showing through the cracks,
-- tiny glowing motes drifting up and short god-ray beams bursting out in
-- every direction, so there is clearly something good inside. Owner is replicated on
-- the holder ("id:tier:owner;..."); it is kept after the cell leaves the
-- list, because the opening op can arrive a moment later.
local GEODE_PIECES=5
local GEODE_GAP=.93 -- pieces drawn slightly smaller, so the cracks show
local GEODE_WAIT=.6 -- seconds a vanished geode keeps drawing until its op lands
local RAY_COUNT=9
local RAY_FADE=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(.35,.7),NumberSequenceKeypoint.new(1,1)})
function V:clearGeodes()
 for id in pairs(self.geodes) do self:dropGeode(id) end
 self.geodes={};self.geodeOwner={};self.localOpened={}
end
function V:dropGeode(id: number)
 local g=self.geodes[id]
 if not g then return end
 g.model:Destroy();self.geodes[id]=nil
end
function V:syncGeodes()
 if not self.holder or not self.cube then return end
 local list=self.holder:GetAttribute('Geodes')
 local seen={}
 if type(list)=='string' then
  for id,tier,owner,treasure in string.gmatch(list,'(%d+):(%d+):(%-?%d+):?(%d?)') do
   local n=tonumber(id) :: number
   seen[n]=true
   self.geodeOwner[n]=tonumber(owner)
   -- The sealed cell is no longer being worked: no outline or proxy on it.
   self:clearCrack(n)
   if not self.geodes[n] and not self.cube.removed[n] and self.cube.cells[n] and not self.localOpened[n] then
    self:buildGeode(n,tonumber(tier) or 1)
    self.geodes[n].tier=tonumber(tier) or 1;self.geodes[n].treasure=treasure=='1'
   end
  end
 end
 for id,g in pairs(self.geodes) do
  if not seen[id] and not g.leftAt then g.leftAt=os.clock() end
 end
end
function V:buildGeode(id: number,tier: number)
 local c=self.cube.cells[id];local o=self.origin
 local color=rgb(DigCube.ORES[math.clamp(tier,1,#DigCube.ORES)].color)
 local model=Instance.new('Model');model.Name='DigSealedGem'
 local polys=DigCube.voronoiSplit(c.poly,GEODE_PIECES,function() return self.random:NextNumber() end)
 local pieces={}
 local centers={}
 for _,poly in ipairs(polys) do
  local _,mx,mz=middle(poly)
  local mid=o+Vector3.new(mx,(c.y0+c.y1)*.5+.04,mz)
  local stone=self:colorAt(c.y1-.01,mx,mz):Lerp(SHARD_DARK,self.random:NextNumber(.05,.22))
  local inverse=CFrame.new(mid):Inverse()
  local parts={}
  for _,w in ipairs(DigCube.polyWedges(DigCube.grown(poly,.02),c.y0+.02,c.y1+.08)) do
   local part=fxPart(model,'GeodePiece',stone,'WedgePart');part.CastShadow=true;part.Material=ROCK;part.MaterialVariant=ROCK_VARIANT
   local size=Vector3.new(w.size[1],w.size[2],w.size[3])
   local frame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
   local rel=inverse*frame
   -- Narrower only (wedge X is the vertical extrusion), so the tops stay
   -- above the real rock and the cracks between them open onto the glow.
   part.Size=Vector3.new(size.X,size.Y*GEODE_GAP,size.Z*GEODE_GAP)
   table.insert(parts,{part=part,rel=rel.Rotation+rel.Position*Vector3.new(GEODE_GAP,1,GEODE_GAP)})
  end
  table.insert(pieces,{mid=mid,parts=parts,phase=self.random:NextNumber(0,math.pi*2),axis=Vector3.new(self.random:NextNumber(-1,1),0,self.random:NextNumber(-1,1)).Unit})
  table.insert(centers,{mx,mz})
 end
 -- The glow inside, seen only through the cracks: a thin glowing sheet just
 -- under the pieces' tops (the real rock fills the cell below it).
 local core={}
 for _,w in ipairs(DigCube.polyWedges(DigCube.grown(c.poly,-.04),c.y1+.005,c.y1+.045)) do
  local part=fxPart(model,'GeodeGlow',color:Lerp(Color3.new(1,1,1),.15),'WedgePart');part.Material=Enum.Material.Neon
  part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
  part.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
   Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
  table.insert(core,part)
 end
 local top=o+Vector3.new(c.cx,c.y1+.1,c.cz)
 local anchor=fxPart(model,'GeodeTop',color);anchor.Transparency=1
 anchor.Size=Vector3.new(math.max(.5,c.radius*1.4),.2,math.max(.5,c.radius*1.4));anchor.CFrame=CFrame.new(top)
 local motes,rays,haloImage,glintsMade
 if not self:reduced() then
  motes=Instance.new('ParticleEmitter');motes.Name='GeodeMotes'
  motes.Texture='rbxasset://textures/particles/sparkles_main.dds'
  motes.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.5),color)
  motes.LightEmission=1;motes.LightInfluence=0;motes.Brightness=1.6
  motes.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.25,.22),NumberSequenceKeypoint.new(1,0)})
  motes.Lifetime=NumberRange.new(1.1,1.9);motes.Speed=NumberRange.new(1,2.6);motes.SpreadAngle=Vector2.new(25,25)
  motes.EmissionDirection=Enum.NormalId.Top;motes.Acceleration=Vector3.new(0,.5,0);motes.Drag=.6
  motes.Rotation=NumberRange.new(0,360);motes.RotSpeed=NumberRange.new(-90,90)
  motes.Shape=Enum.ParticleEmitterShape.Box;motes.Rate=24;motes.Parent=anchor
  -- Quick bright glints popping out of the cracks (owner, Nov 22: more glow).
  glintsMade=Instance.new('ParticleEmitter');local glints=glintsMade;glints.Name='GeodeGlints'
  EnergyDisc.configure(glints,.28,.05,1,0,.3)
  glints.LightEmission=1;glints.LightInfluence=0;glints.Brightness=2
  glints.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.6),color)
  glints.Lifetime=NumberRange.new(.22,.45);glints.Speed=NumberRange.new(3,7);glints.SpreadAngle=Vector2.new(70,70)
  glints.EmissionDirection=Enum.NormalId.Top;glints.Acceleration=Vector3.new(0,-14,0);glints.Drag=2
  glints.Shape=Enum.ParticleEmitterShape.Box;glints.Rate=10;glints.Parent=anchor
  -- A soft halo over the cell, breathing with the glow.
  local halo=Instance.new('BillboardGui');halo.Name='GeodeHalo';halo.LightInfluence=0;halo.Brightness=1.4
  local size=math.max(4,c.radius*3.4);halo.Size=UDim2.fromScale(size,size);halo.MaxDistance=140;halo.Parent=anchor
  local image=Instance.new('ImageLabel');image.BackgroundTransparency=1;image.Image='rbxasset://textures/ui/AvatarExperience/glowLight.png'
  image.ImageColor3=color;image.Size=UDim2.fromScale(1,1);image.ImageTransparency=.5;image.Parent=halo
  haloImage=image
  -- God rays bursting out in every direction (owner, Nov 22): short, each
  -- living a second or two, fading out and coming back pointing elsewhere.
  rays={}
  for k=1,RAY_COUNT do
   local a0=Instance.new('Attachment');a0.Parent=anchor
   local a1=Instance.new('Attachment');a1.Parent=anchor
   local beam=Instance.new('Beam');beam.Attachment0=a0;beam.Attachment1=a1;beam.FaceCamera=true;beam.Segments=4
   beam.Width0=.14;beam.Width1=.75;beam.LightEmission=1;beam.LightInfluence=0;beam.Brightness=1.2
   beam.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.45),color);beam.Transparency=RAY_FADE;beam.Parent=anchor
   table.insert(rays,{beam=beam,from=a0,tip=a1,born=-10,life=1})
  end
 end
 local center=o+Vector3.new(c.cx,c.y1+.05,c.cz)
 model.Parent=self.fx
 self.geodes[id]={model=model,pieces=pieces,rays=rays,core=core,halo=haloImage,motes=motes,glints=glintsMade,born=os.clock(),center=center,radius=c.radius,color=color}
end
-- Owner, Nov 22 (latest): too much on screen. A sealed gem you are not
-- near sits calm (its glowing cracks, a soft halo, a few motes); the god
-- rays, glints and the full shimmer come on as you get close, so they
-- point you to the one you are heading for instead of lighting up the pit.
local GEODE_NEAR=20
function V:stepGeodes(now: number)
 local still=self:reduced()
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local me=root and (root :: any).Position or nil
 for id,g in pairs(self.geodes) do
  if g.leftAt and now-g.leftAt>GEODE_WAIT then self:dropGeode(id);continue end
  if g.opening or self:landedOn(id,g) then continue end
  local near=me==nil or (me-g.center).Magnitude<GEODE_NEAR
  if near~=g.near then
   g.near=near
   if g.motes then g.motes.Rate=near and 24 or 4 end
   if g.glints then g.glints.Rate=near and 10 or 0 end
  end
  local age=now-g.born
  -- A fast, tight shiver (owner, Nov 22: less displacement, faster), a
  -- little stronger the longer it waits.
  local eager=math.clamp(age/3,0,1)
  local amp=still and 0 or .007+.007*eager
  for i,piece in ipairs(g.pieces) do
   local t=now*(30+14*eager)
   local rx=math.noise(t,i*3.1,.5)*2;local rz=math.noise(i*1.7,t,.25)*2
   local dy=math.noise(t,.75,i*2.3)*amp*1.5
   local frame=CFrame.new(piece.mid+Vector3.yAxis*dy)*CFrame.Angles(rx*amp,0,rz*amp)
   for _,q in ipairs(piece.parts) do q.part.CFrame=frame*q.rel end
  end
  local glow=.3-.15*math.sin(now*3.1)
  for _,part in ipairs(g.core) do part.Transparency=glow end
  if g.halo then g.halo.ImageTransparency=(near and .6 or .78)-.15*math.sin(now*3.1) end
  for _,ray in ipairs(g.rays or {}) do
   if not near then ray.beam.Enabled=false;ray.born=-10;ray.life=1;continue end
   local u=(now-ray.born)/ray.life
   if u>=1 then
    -- A new ray: any direction from flat out to straight up, from a point
    -- on the cell's top.
    ray.born=now+self.random:NextNumber(0,.35);ray.life=self.random:NextNumber(.9,1.8);u=-1
    local az=self.random:NextNumber(0,math.pi*2);local el=math.rad(self.random:NextNumber(-5,85))
    ray.dir=Vector3.new(math.cos(az)*math.cos(el),math.sin(el),math.sin(az)*math.cos(el))
    ray.spin=self.random:NextNumber(-.5,.5)
    ray.length=self.random:NextNumber(2.2,4)
    local off=self.random:NextNumber(0,g.radius*.6)
    ray.base=g.center+Vector3.new(math.cos(az)*off,0,math.sin(az)*off)
   end
   if u<0 then ray.beam.Enabled=false
   else
    ray.beam.Enabled=true
    local env=math.sin(math.pi*u)
    local dir=CFrame.Angles(0,ray.spin*u,0):VectorToWorldSpace(ray.dir)
    ray.from.WorldPosition=ray.base
    ray.tip.WorldPosition=ray.base+dir*ray.length*(.7+.3*env)
    ray.beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1-.6*env),NumberSequenceKeypoint.new(.4,1-.4*env),NumberSequenceKeypoint.new(1,1)})
   end
  end
 end
end
-- Midair combo (owner, Nov 22): the count of sealed gems opened since the
-- player last stood on the ground (a quarter second on solid footing, or 4 s
-- with no opening, ends it).
function V:geodeCombo(): number
 local now=os.clock()
 if now-(self.comboAt or -10)>4 then self.combo=0 end
 self.combo=(self.combo or 0)+1;self.comboAt=now
 return self.combo
end
function V:stepCombo(now: number)
 if (self.combo or 0)==0 then return end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local grounded=humanoid~=nil and humanoid.FloorMaterial~=Enum.Material.Air
 if grounded and now-(self.comboAt or 0)>.3 then
  self.groundSince=self.groundSince or now
  if now-self.groundSince>.25 then self.combo=0;self.groundSince=nil end
 else self.groundSince=nil end
end
-- Your own landing on your sealed cell, seen here first: the game freezes
-- this very frame (the freeze is the pause, owner Nov 22), the break plays
-- locally, and the server is asked to open it (it launches the gem).
local LANDING_SPEED=8
function V:landedOn(id: number,g: any): boolean
 local player=Players.LocalPlayer
 -- Yours, or public (owner 0: its owner left or stopped digging): anyone may open it.
 local owner=self.geodeOwner[id]
 if g.leftAt or g.opening or self.localOpened[id] or not player or (owner~=player.UserId and owner~=0) then return false end
 local character=player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local c=self.cube.cells[id]
 if not root or not root:IsA('BasePart') or not c then return false end
 if root.AssemblyLinearVelocity.Y>-LANDING_SPEED then return false end
 local l=root.Position-self.origin
 local above=l.Y-c.y1
 if math.sqrt((l.X-c.cx)^2+(l.Z-c.cz)^2)>c.radius+1.2 or above<1-(c.y1-c.y0) or above>5.5 then return false end
 self.localOpened[id]=true
 self.ctx.command:FireServer('DigOpen',{id=id})
 DigCube.remove(self.cube,id)
 self:split({kind='c',cells={id},tier=g.tier or 1,treasure=g.treasure==true,geode=true,partial=false,flag='G',removes={id}},os.clock())
 return true
end
-- The sealed cell's explosion (owner, Nov 22: much better, LOTS more
-- particles, some lingering, some quick). On top of the gem break: quick
-- hot sparks and streaks, two more waves of the gem burst, the 3D streak
-- fireworks, two more rings, and a cloud of glitter that hangs and drifts
-- for a few seconds. The real rubble replaced the tumbling stand-ins.
function V:geodeBlast(at: Vector3,ground: number,color: Color3,light: Color3,tier: number,weight: number,serverNow: number)
 local ctx=self.ctx
 local holder=fxPart(self.fx,'GeodeBlast',color);holder.Transparency=1;holder.Size=Vector3.new(2,1,2);holder.Position=at
 local function emitter(name: string): ParticleEmitter
  local p=Instance.new('ParticleEmitter');p.Name=name;p.Enabled=false;p.Rate=0;p.LightInfluence=0
  p.Shape=Enum.ParticleEmitterShape.Sphere;p.Parent=holder
  return p
 end
 local quick=emitter('QuickSparks')
 EnergyDisc.configure(quick,.4,.05,1,0,.35)
 quick.LightEmission=1;quick.Brightness=2.4;quick.Color=ColorSequence.new(light,color)
 quick.Lifetime=NumberRange.new(.18,.4);quick.Speed=NumberRange.new(30,55);quick.SpreadAngle=Vector2.new(180,180)
 quick.Drag=4;quick.Acceleration=Vector3.new(0,-20,0)
 quick:Emit(math.floor(60*weight))
 local streaks=emitter('Streaks')
 streaks.Texture='rbxasset://textures/particles/sparkles_main.dds';streaks.LightEmission=1;streaks.Brightness=2
 streaks.Color=ColorSequence.new(Color3.new(1,1,1),color);streaks.Squash=NumberSequence.new(-2.2)
 streaks.Orientation=Enum.ParticleOrientation.VelocityParallel
 streaks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,0)})
 streaks.Lifetime=NumberRange.new(.3,.55);streaks.Speed=NumberRange.new(24,40);streaks.SpreadAngle=Vector2.new(180,180);streaks.Drag=3
 streaks:Emit(math.floor(36*weight))
 local linger=emitter('LingeringGlitter')
 linger.Texture='rbxasset://textures/particles/sparkles_main.dds';linger.LightEmission=1;linger.Brightness=1.6
 linger.Color=ColorSequence.new(light,color)
 linger.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.1,.35),NumberSequenceKeypoint.new(.8,.25),NumberSequenceKeypoint.new(1,0)})
 linger.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.7,.2),NumberSequenceKeypoint.new(1,1)})
 linger.Lifetime=NumberRange.new(2.4,4.2);linger.Speed=NumberRange.new(6,16);linger.SpreadAngle=Vector2.new(180,180)
 linger.Drag=3.2;linger.Acceleration=Vector3.new(0,-.8,0);linger.Rotation=NumberRange.new(0,360);linger.RotSpeed=NumberRange.new(-120,120)
 linger:Emit(math.floor(70*weight))
 local motes=emitter('LingeringMotes')
 EnergyDisc.configure(motes,.32,.2,1,.2,.3)
 motes.LightEmission=.9;motes.Brightness=1.5;motes.Color=ColorSequence.new(color)
 motes.Lifetime=NumberRange.new(1.8,3.2);motes.Speed=NumberRange.new(4,10);motes.SpreadAngle=Vector2.new(180,180)
 motes.Drag=2.5;motes.Acceleration=Vector3.new(0,1.2,0)
 motes:Emit(math.floor(30*weight))
 task.delay(4.5,function() holder:Destroy() end)
 local k=1+tier*.2
 if ctx.effects then
  for i,delay in ipairs({.06,.18}) do
   task.delay(delay,function()
    ctx.effects.ImpactParticles(at+Vector3.yAxis*(.4*i),i==1 and color or light,k*1.2,'GemReward')
    ctx.effects.Pulse(Vector3.new(at.X,ground+.1+i*.05,at.Z),i==1 and light or color,.5,(6+tier*2+i*3)*weight,.5+.1*i)
   end)
  end
  ctx.effects.ImpactParticles(at,light,k*1.4,'CrystalBreak',nil,color,nil,1.3)
 end
 if ctx.impact then
  ctx.impact:fireworks(at,ground,color,(1.4+tier*.15)*2.4*weight,serverNow,16)
 end
end
-- The sealed cell during the full-game freeze (u: 0 at the landing, 1 at
-- the break). Sakurai's hit-stop shake: biggest at the start, shrinking to
-- the end. The pieces also strain apart a little, the glow under them goes
-- full and every ray flares wider, so the stillness around it is clearly
-- holding its breath.
function V:tenseGeode(id: number,u: number)
 local g=self.geodes[id]
 if not g then return end
 -- Frantic (owner, Nov 22): a big, fast, random shake every frame for the
 -- whole freeze, easing only a little toward the break.
 local amp=.17*(1-.35*u)
 local t=os.clock()*97
 for i,piece in ipairs(g.pieces) do
  local out=Vector3.new(piece.mid.X-g.center.X,0,piece.mid.Z-g.center.Z)
  out=out.Magnitude>.05 and out.Unit or Vector3.zero
  local jitter=Vector3.new(math.noise(t,i*1.3,.1),math.noise(i*2.1,t,.6)*.6,math.noise(.4,i*.9,t))*amp
  local frame=CFrame.new(piece.mid+out*(.18*u)+jitter)*CFrame.Angles(math.noise(t,i,.9)*amp,math.noise(i,t,.3)*amp*.6,math.noise(i,.2,t)*amp)
  for _,q in ipairs(piece.parts) do q.part.CFrame=frame*q.rel end
 end
 -- Hit (owner, Nov 22): the ore blazes brighter at once, its light floods
 -- the pit, the rays shoot out much longer and 1-4 long bolts fork away.
 local white=Color3.new(1,1,1)
 for _,part in ipairs(g.core) do part.Transparency=0;part.Color=(g.color or white):Lerp(white,.35+.25*u) end
 for _,piece in ipairs(g.pieces) do for _,q in ipairs(piece.parts) do
  if not q.lit then q.lit=q.part.Color;q.part.Color=q.lit:Lerp(g.color or white,.35) end
 end end
 if not g.hitLight then
  local light=Instance.new('PointLight');light.Name='GeodeHitLight';light.Shadows=false
  light.Color=(g.color or white):Lerp(white,.3);light.Range=16;light.Brightness=3
  local holder=g.model and g.model:FindFirstChild('GeodeTop')
  if holder then light.Parent=holder;g.hitLight=light end
 end
 if g.hitLight then g.hitLight.Brightness=3*(1-.3*u) end
 self:arcs(g,u)
 if g.halo then
  g.halo.ImageTransparency=.15-.15*u
  local gui=g.halo.Parent
  if gui and gui:IsA('BillboardGui') then
   g.haloSize=g.haloSize or gui.Size
   gui.Size=UDim2.fromScale(g.haloSize.X.Scale*(1.6+.6*u),g.haloSize.Y.Scale*(1.6+.6*u))
  end
 end
 for _,ray in ipairs(g.rays or {}) do
  if ray.dir and ray.base then
   ray.beam.Enabled=true
   ray.beam.Width1=.75*(1.6+1.4*u)
   ray.tip.WorldPosition=ray.base+ray.dir*(ray.length or 3)*(2.4+2.1*u)
   ray.beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35-.3*u),NumberSequenceKeypoint.new(.4,.55-.3*u),NumberSequenceKeypoint.new(1,1)})
  end
 end
end
-- Electric arcs out of the sealed cell during the freeze (owner, Nov 22):
-- short jagged bolts (about the cell's size, 1.8 to 3.6 studs) that
-- re-strike every frame or two, from the cell's middle out in all
-- directions, then crackle on for a moment after the break.
local ARC_COUNT,ARC_SEGMENTS,ARC_AFTER=5,5,.35
local LONG_SEGMENTS=10 -- the 1-4 extra long bolts of a hit
function V:arcs(g: any,u: number)
 if self:reduced() then return end
 local set=self.arcSet
 if not set or set.geode~=g then
  if set then set.anchor:Destroy() end
  local anchor=fxPart(self.fx,'GeodeArcs',g.color or FLASH);anchor.Transparency=1;anchor.Size=Vector3.one*.05;anchor.Position=g.center
  local bolts={}
  for b=1,ARC_COUNT do
   local points={}
   for i=0,ARC_SEGMENTS do local a=Instance.new('Attachment');a.Parent=anchor;points[i]=a end
   local beams={}
   for i=1,ARC_SEGMENTS do
    local beam=Instance.new('Beam');beam.Attachment0=points[i-1];beam.Attachment1=points[i];beam.FaceCamera=true;beam.Segments=1
    beam.LightEmission=1;beam.LightInfluence=0;beam.Brightness=1.8
    beam.Color=ColorSequence.new(Color3.new(1,1,1):Lerp(g.color or FLASH,.35))
    local w=.16*(1-(i-1)/ARC_SEGMENTS)+.04;beam.Width0=w;beam.Width1=w*.8;beam.Parent=anchor
    beams[i]=beam
   end
   bolts[b]={points=points,beams=beams}
  end
  -- 1-4 extra long bolts, each in its own random direction for this hit.
  local long={}
  for _=1,self.random:NextInteger(1,4) do
   local points={}
   for i=0,LONG_SEGMENTS do local a=Instance.new('Attachment');a.Parent=anchor;points[i]=a end
   local beams={}
   for i=1,LONG_SEGMENTS do
    local beam=Instance.new('Beam');beam.Attachment0=points[i-1];beam.Attachment1=points[i];beam.FaceCamera=true;beam.Segments=1
    beam.LightEmission=1;beam.LightInfluence=0;beam.Brightness=2.2
    beam.Color=ColorSequence.new(Color3.new(1,1,1):Lerp(g.color or FLASH,.25))
    local w=.26*(1-(i-1)/LONG_SEGMENTS)+.05;beam.Width0=w;beam.Width1=w*.85;beam.Parent=anchor
    beams[i]=beam
   end
   local az=self.random:NextNumber(0,math.pi*2);local el=math.rad(self.random:NextNumber(5,55))
   table.insert(long,{points=points,beams=beams,dir=Vector3.new(math.cos(az)*math.cos(el),math.sin(el),math.sin(az)*math.cos(el)),length=self.random:NextNumber(11,19)})
  end
  set={geode=g,anchor=anchor,bolts=bolts,long=long,strikeAt=0};self.arcSet=set
 end
 local now=os.clock()
 set.untilAt=now+ARC_AFTER
 if now<set.strikeAt then return end
 set.strikeAt=now+1/45
 for b,bolt in ipairs(set.bolts) do
  local on=self.random:NextNumber()<.85
  local az=self.random:NextNumber(0,math.pi*2);local el=math.rad(self.random:NextNumber(-15,70))
  local dir=Vector3.new(math.cos(az)*math.cos(el),math.sin(el),math.sin(az)*math.cos(el))
  local side=dir:Cross(Vector3.yAxis);side=side.Magnitude>.05 and side.Unit or Vector3.xAxis
  local up=side:Cross(dir).Unit
  local length=math.clamp((g.radius or 2)*self.random:NextNumber(.6,1),1.8,3.6)*(1+.2*u)
  local from=g.center+Vector3.yAxis*.2
  for i=0,ARC_SEGMENTS do
   local f=i/ARC_SEGMENTS
   local kink=(i==0 or i==ARC_SEGMENTS) and 0 or .35*math.sin(f*math.pi)
   bolt.points[i].WorldPosition=from+dir*length*f+side*self.random:NextNumber(-kink,kink)+up*self.random:NextNumber(-kink,kink)
  end
  for _,beam in ipairs(bolt.beams) do beam.Enabled=on end
 end
 -- The long bolts keep their direction and re-kink every strike, reaching
 -- further as the freeze builds.
 for _,bolt in ipairs(set.long or {}) do
  local side=bolt.dir:Cross(Vector3.yAxis);side=side.Magnitude>.05 and side.Unit or Vector3.xAxis
  local up=side:Cross(bolt.dir).Unit
  local length=bolt.length*(.75+.25*u)
  local from=g.center+Vector3.yAxis*.3
  for i=0,LONG_SEGMENTS do
   local f=i/LONG_SEGMENTS
   local kink=(i==0) and 0 or .9*math.sin(f*math.pi)+.2
   bolt.points[i].WorldPosition=from+bolt.dir*length*f+side*self.random:NextNumber(-kink,kink)+up*self.random:NextNumber(-kink,kink)
  end
  for _,beam in ipairs(bolt.beams) do beam.Enabled=true end
 end
end
function V:stepArcs(now: number)
 local set=self.arcSet
 if not set then return end
 if now>=set.untilAt then set.anchor:Destroy();self.arcSet=nil;return end
 -- After the break the arcs keep crackling from where the cell was.
 if now>=set.strikeAt then
  set.strikeAt=now+1/30
  local fade=(set.untilAt-now)/ARC_AFTER
  local all=table.clone(set.bolts)
  for _,bolt in ipairs(set.long or {}) do table.insert(all,bolt) end
  for _,bolt in ipairs(all) do
   local on=self.random:NextNumber()<fade
   for i=0,#bolt.points do
    if i>0 then bolt.points[i].WorldPosition+=Vector3.new(self.random:NextNumber(-.15,.15),self.random:NextNumber(-.15,.15),self.random:NextNumber(-.15,.15)) end
   end
   for _,beam in ipairs(bolt.beams) do beam.Enabled=on end
  end
 end
end
-- Straight up when your sealed gem breaks under you (client-owned physics).
function V:bounce(at: Vector3)
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if not root or not root:IsA('BasePart') then return end
 local offset=root.Position-at
 if Vector3.new(offset.X,0,offset.Z).Magnitude>9 or math.abs(offset.Y)>10 then return end
 local v=root.AssemblyLinearVelocity
 root.AssemblyLinearVelocity=Vector3.new(v.X*.25,62,v.Z*.25)
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
-- touches the rock, sparks in the beam's own color; and under every drone
-- over the cube a red targeting line, straight
-- down along its beam, ending in a soft dot that tightens and brightens
-- while the drone charges and pulses while it cuts.
local SIGHT=Color3.fromRGB(255,56,72)
local SIGHT_HOT=Color3.fromRGB(255,170,176)
local DOT='rbxasset://textures/ui/VR/circleWhite.png'
local SIGHT_FADE=NumberSequence.new({NumberSequenceKeypoint.new(0,.92),NumberSequenceKeypoint.new(.45,.5),NumberSequenceKeypoint.new(1,.12)})
local SIGHT_GLOW=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.88),NumberSequenceKeypoint.new(1,.7)})
-- The style code a drone digs with: its DigOp's code, else its role's.
local function digCode(source: Instance): string
 local key=source:GetAttribute('DigOp')
 local code=type(key)=='string' and string.match(key,'~(%u)') or nil
 if code and DigCube.STYLES_BY_CODE[code] then return code end
 return V.style(source:GetAttribute('Role')).code
end
function V:beamTarget(source: Instance): BasePart?
 local id=source:GetAttribute('DroneId')
 local key=source:GetAttribute('DigOp');local point=source:GetAttribute('DigPoint')
 local beam=type(id)=='string' and self.beams[id]
 -- Only beam roles cut with the mining beam; shots, slams, volleys and
 -- pulses draw their own attack.
 if not beam or not self.cube or type(key)~='string' or key=='' or typeof(point)~='Vector3' or DigCube.style(digCode(source)).kernel~='beam' then
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
function V:newBeam(color: Color3,mine: boolean,role: string?)
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
 sparks.Acceleration=Vector3.new(0,-26,0);sparks.Rate=mine and 7 or 3;sparks.Enabled=false;sparks.Parent=b
 -- The drone type's own particle look (FunFX.ROLE_PARTICLE).
 if self.ctx.styleParticle then pcall(self.ctx.styleParticle,sparks,role) end
 return {root=root,a=a,b=b,core=core,glow=glow,gui=gui,halo=halo,dot=dot,sparks=sparks,mine=mine,tint=color,edge=color,on=false}
end
function V:hideBeam(beam: any)
 if not beam.on then return end
 beam.on=false;beam.core.Enabled=false;beam.glow.Enabled=false;beam.gui.Enabled=false;beam.sparks.Enabled=false
end
-- Every frame per drone. `accent` is the drone's secondary color (its cube
-- look); the attack color is the role's primary (V.primaryColor).
function V:droneBeam(source: Instance,from: Vector3,now: number,accent: Color3?)
 local id=source:GetAttribute('DroneId')
 if type(id)~='string' or not self.cube then return end
 local primary=V.primaryColor(source:GetAttribute('Role'))
 local edge=accent or primary
 local beam=self.beams[id]
 if not beam then
  local player=Players.LocalPlayer
  beam=self:newBeam(primary,player~=nil and source:GetAttribute('Owner')==player.UserId,source:GetAttribute('Role'))
  self.beams[id]=beam
 end
 local clock=os.clock() -- the step functions run on os.clock; `now` here is server time
 beam.seen=clock
 if beam.tint~=primary or beam.edge~=edge then
  beam.tint=primary;beam.edge=edge;beam.sparks.Color=ColorSequence.new(primary:Lerp(BEAM_CORE,.3),edge)
 end
 local key=source:GetAttribute('DigOp')
 local ids=type(key)=='string' and string.match(key,'^c([%d%.]+)') or nil
 local code=digCode(source)
 local style=DigCube.style(code)
 local state=source:GetAttribute('State')
 local digMining=source:GetAttribute('DigMining')==true
 local alive=(source:GetAttribute('HP') or 1)>0
 local point=source:GetAttribute('DigPoint')
 -- The dig this drone was last on, before this frame. The slam or pulse
 -- that breaks a chunk replicates together with DigOp cleared (digBreak
 -- drops the job in the same tick), or already with the next job's key.
 local lastKey,lastPoint=beam.key,beam.lastPoint
 local recent=ids~=nil or clock-(beam.digAt or -10)<.5
 -- Remember which cells each drone is cutting (its role and colors), and
 -- which are this player's own: their breaks get the pause and the combo.
 if ids and beam.key~=key then
  beam.key=key
  for _,cell in ipairs(DigCube.parseKey(ids)) do
   self.cellColor[cell]=primary;self.cellCode[cell]=code;self.cellAccent[cell]=edge
   if beam.mine then self.mine[cell]=true end
  end
 end
 if ids then
  beam.digAt=clock
  if typeof(point)=='Vector3' then beam.lastPoint=point end
 end
 -- Where a slam or pulse seen this frame landed: the chunk it broke when
 -- the dig cleared or moved on this frame, else the current DigPoint.
 local moved=ids==nil or (lastKey~=nil and lastKey~=key)
 local hitPoint=(moved and lastPoint) or (typeof(point)=='Vector3' and point) or nil
 -- A Charger's slam lands (ImpactSerial) and a Lancer pulse fires
 -- (MinePulseSerial): the piece jolts down. First sight only records them.
 local impactSerial=source:GetAttribute('ImpactSerial') or 0
 local slam=beam.impactSerial~=nil and impactSerial~=beam.impactSerial and code=='C' and recent
 beam.impactSerial=impactSerial
 local pulseSerial=source:GetAttribute('MinePulseSerial') or 0
 local pulse=beam.pulseSerial~=nil and pulseSerial~=beam.pulseSerial and code=='Z' and recent
  and workspace:GetServerTimeNow()-(source:GetAttribute('MinePulseAt') or 0)<.5
 beam.pulseSerial=pulseSerial
 if ids and not moved and (slam or pulse) then
  -- (a hit that broke the last chunk does not jolt the next one)
  local job=self.cracks[ids]
  if job then
   if slam then job.slamAt=clock end
   if pulse then job.pulseAt=clock end
  end
 end
 if slam and beam.mine and self.ctx.audio then
  self.ctx.audio:play('breaker_contact',hitPoint or from,{level=.7})
 end
 -- Stage cracks on the chunk this drone is cutting. The outline pulses
 -- while it works on it: the beam, or any other attack once it is there.
 if ids and alive then
  local cutting=digMining or (style.kernel~='beam' and state~='Travel')
  self:crackStage(ids,source:GetAttribute('DigProgress') or 0,clock,primary,beam.mine,cutting,code,source)
 end
 -- Only over the cube, alive and not in a menu pause.
 local l=from-self.origin
 local W=self.cube.width
 alive=alive and state~='Destroyed' and source:GetAttribute('WorkPaused')~=true
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
 if pulse then self:pulseShot(from,hitPoint or tip,primary,edge,beam.mine) end
 if from.Y-tip.Y<.4 then self:hideBeam(beam);return end
 local locked=ids~=nil
 local cutting=locked and digMining
 local charging=locked and (state=='Warmup' or state=='BreakerWindup')
 if not beam.on then beam.on=true end
 -- The red targeting laser shows only while the drone charges, right before
 -- it fires (or a Charger winds up); then the real attack takes its place.
 -- No sightline any more (owner, Nov 22: "you can probably remove it
 -- altogether"): the red targeting line and dot never show; the charge-up
 -- and the attack itself say where a drone is about to hit.
 if beam.core.Enabled or beam.glow.Enabled or beam.gui.Enabled then beam.core.Enabled=false;beam.glow.Enabled=false;beam.gui.Enabled=false end
 beam.root.CFrame=CFrame.new(tip+Vector3.yAxis*.05)
 beam.a.Position=from-tip
 local size,core,halo
 if cutting then
  local wave=.5+.5*math.sin(now*14)
  size=.9+.15*wave;core=.0;halo=.6-.15*wave
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
 -- Where the beam touches the rock: a steady stream of sparks in the role's
 -- color fading to the drone's accent. The contact glow and light come from
 -- the mining beam itself; the old extra chips and rings only added noise.
 local sparking=cutting and not self:reduced()
 if beam.sparks.Enabled~=sparking then beam.sparks.Enabled=sparking end
end
function V:stepBeams(now: number)
 for id,beam in pairs(self.beams) do
  local idle=now-(beam.seen or 0)
  if idle>.3 then self:hideBeam(beam) end
  if beam.plate and now-(beam.plateAt or 0)>.3 then beam.plate.Transparency=1 end
  if idle>20 then beam.root:Destroy();if beam.plate then beam.plate:Destroy() end;self.beams[id]=nil end
 end
end
-- The Lancer's pulse laser (owner's reference video, "squash, stretch,
-- shake"): a thin white needle stabs down, stretches in a few frames to a fat
-- core (white inside, the role's color around it, a red and a cyan fringe to
-- either side), shakes sideways while fat, holds, squashes to a hairline and
-- is gone, all in about a third of a second. Where it lands: a hollow square
-- shock frame (turned 45 degrees) grows and fades, quick gold sparks, a small
-- dark crater, and a line of tiny motes lingers and drifts where the beam
-- was. Kept dim (low light emission, no full-screen flash). At most six shots
-- live; their parts are pooled and reused.
local SHOT={MAX=6,LIFE=.34,BUSY=.64,NEEDLE=.035,FAT=.08,HOLD=.2,SQUASH=.3,WIDTH=1.1,HAIR=.03,SHAKE=.12,FRINGE=.12,
 WHITE=Color3.fromRGB(255,252,240),RED=Color3.fromRGB(255,70,86),CYAN=Color3.fromRGB(70,226,255),
 GOLD=Color3.fromRGB(255,206,110),SCORCH=Color3.fromRGB(22,24,42)}
function V:shotRig(): any
 local root=fxPart(self.fx,'LancerShot',SHOT.WHITE);root.Transparency=1;root.Size=Vector3.one*.05
 local function attach(): Attachment local a=Instance.new('Attachment');a.Parent=root;return a end
 local rig={root=root,top=attach(),bottom=attach(),redTop=attach(),redBottom=attach(),cyanTop=attach(),cyanBottom=attach(),at=-10,idle=true}
 local function ray(name: string,a0: Attachment,a1: Attachment,color: Color3,z: number): Beam
  local b=Instance.new('Beam');b.Name=name;b.Attachment0=a0;b.Attachment1=a1;b.FaceCamera=true;b.Segments=1
  b.Color=ColorSequence.new(color);b.LightEmission=.25;b.LightInfluence=0;b.Brightness=1;b.ZOffset=z
  b.Enabled=false;b.Parent=root
  return b
 end
 rig.core=ray('Core',rig.top,rig.bottom,SHOT.WHITE,.02)
 rig.mid=ray('Mid',rig.top,rig.bottom,SHOT.WHITE,.01)
 rig.red=ray('FringeRed',rig.redTop,rig.redBottom,SHOT.RED,0)
 rig.cyan=ray('FringeCyan',rig.cyanTop,rig.cyanBottom,SHOT.CYAN,0)
 rig.frame={}
 for i=1,4 do local side=fxPart(self.fx,'LancerFrame',SHOT.WHITE);side.Transparency=1;side.Size=Vector3.new(.1,.03,.1);rig.frame[i]=side end
 local crater=fxPart(self.fx,'LancerCrater',SHOT.SCORCH);crater.Shape=Enum.PartType.Cylinder;crater.Transparency=1;crater.Size=Vector3.new(.04,.1,.1)
 rig.crater=crater
 local spot=fxPart(self.fx,'LancerSparks',SHOT.GOLD);spot.Transparency=1;spot.Size=Vector3.one*.3
 local sparks=Instance.new('ParticleEmitter');sparks.Name='Sparks'
 EnergyDisc.configure(sparks,.24,.05,1,0,.3)
 sparks.LightEmission=.5;sparks.LightInfluence=0;sparks.Brightness=1.2;sparks.Enabled=false;sparks.Rate=0
 sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(75,75)
 sparks.Speed=NumberRange.new(10,20);sparks.Lifetime=NumberRange.new(.14,.32);sparks.Drag=3
 sparks.Acceleration=Vector3.new(0,-34,0);sparks.Parent=spot
 rig.spot=spot;rig.sparks=sparks
 local trail=fxPart(self.fx,'LancerMotes',SHOT.WHITE);trail.Transparency=1;trail.Size=Vector3.one*.2
 local motes=Instance.new('ParticleEmitter');motes.Name='Motes'
 EnergyDisc.configure(motes,.13,.2,1,0,.3)
 motes.LightEmission=.5;motes.LightInfluence=0;motes.Brightness=1;motes.Enabled=false;motes.Rate=0
 motes.Shape=Enum.ParticleEmitterShape.Box;motes.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
 motes.SpreadAngle=Vector2.new(180,180);motes.Speed=NumberRange.new(.2,.9);motes.Drag=1.2
 motes.Lifetime=NumberRange.new(1,1.6);motes.Acceleration=Vector3.new(0,.7,0);motes.Parent=trail
 rig.trail=trail;rig.motes=motes
 return rig
end
function V:pulseShot(from: Vector3,to: Vector3,primary: Color3,accent: Color3?,owned: boolean?)
 if not self.cube or self:reduced() or (from-to).Magnitude<.5 then return end
 local now=os.clock()
 local rig
 for _,r in ipairs(self.shots) do if now-r.at>=SHOT.BUSY then rig=r;break end end
 if not rig then
  if #self.shots<SHOT.MAX then rig=self:shotRig();table.insert(self.shots,rig)
  else
   -- All six busy: the oldest one fires again.
   rig=self.shots[1]
   for _,r in ipairs(self.shots) do if r.at<rig.at then rig=r end end
  end
 end
 local edge=accent or primary
 rig.at=now;rig.from=from;rig.to=to;rig.owned=owned==true;rig.idle=false;rig.landed=false;rig.lingered=false
 rig.mid.Color=ColorSequence.new(primary)
 for _,side in ipairs(rig.frame) do side.Color=primary end
 rig.sparks.Color=ColorSequence.new(SHOT.GOLD,primary)
 rig.motes.Color=ColorSequence.new(primary:Lerp(SHOT.WHITE,.45),edge)
 rig.primary=primary
 self:stepShot(rig,now)
end
function V:stepShot(rig: any,now: number)
 local t=now-rig.at
 if t>=SHOT.BUSY then
  -- Done: everything hidden until the rig fires again (the motes, already
  -- emitted in world space, keep drifting).
  rig.idle=true
  rig.core.Enabled=false;rig.mid.Enabled=false;rig.red.Enabled=false;rig.cyan.Enabled=false
  for _,side in ipairs(rig.frame) do side.Transparency=1 end
  rig.crater.Transparency=1
  return
 end
 local from,to=rig.from,rig.to
 local ground=to+Vector3.yAxis*.06
 local on=t<SHOT.LIFE
 if rig.core.Enabled~=on then rig.core.Enabled=on;rig.mid.Enabled=on;rig.red.Enabled=on;rig.cyan.Enabled=on end
 if on then
  -- Needle, stretch, hold (shaking), squash, out.
  local width,reach=SHOT.HAIR*2,1
  if t<SHOT.NEEDLE then reach=t/SHOT.NEEDLE
  elseif t<SHOT.FAT then local u=(t-SHOT.NEEDLE)/(SHOT.FAT-SHOT.NEEDLE);width=width+(SHOT.WIDTH-width)*(1-(1-u)^2)
  elseif t<SHOT.HOLD then width=SHOT.WIDTH
  elseif t<SHOT.SQUASH then local u=(t-SHOT.HOLD)/(SHOT.SQUASH-SHOT.HOLD);width=SHOT.HAIR+(SHOT.WIDTH-SHOT.HAIR)*(1-u*u)
  else width=SHOT.HAIR end
  local fade=math.clamp((t-SHOT.SQUASH)/(SHOT.LIFE-SHOT.SQUASH),0,1)
  local dir=(to-from).Unit
  local camera=workspace.CurrentCamera
  local look=camera and camera.CFrame.LookVector or Vector3.zAxis
  local side=dir:Cross(look)
  side=side.Magnitude>.05 and side.Unit or Vector3.xAxis
  local shake=Vector3.zero
  if t>=SHOT.FAT and t<SHOT.HOLD then shake=side*self.random:NextNumber(-SHOT.SHAKE,SHOT.SHAKE) end
  local top=from+shake
  local bottom=from:Lerp(to,reach)+shake*.5
  rig.top.WorldPosition=top;rig.bottom.WorldPosition=bottom
  local fringe=side*SHOT.FRINGE*math.clamp(width/SHOT.WIDTH,0,1)
  rig.redTop.WorldPosition=top+fringe;rig.redBottom.WorldPosition=bottom+fringe
  rig.cyanTop.WorldPosition=top-fringe;rig.cyanBottom.WorldPosition=bottom-fringe
  rig.core.Width0=width*.55;rig.core.Width1=width*.55
  rig.mid.Width0=width;rig.mid.Width1=width
  rig.red.Width0=width*.85;rig.red.Width1=width*.85
  rig.cyan.Width0=width*.85;rig.cyan.Width1=width*.85
  if fade~=rig.fade then
   rig.fade=fade
   rig.core.Transparency=NumberSequence.new(.05+.95*fade)
   rig.mid.Transparency=NumberSequence.new(.4+.6*fade)
   rig.red.Transparency=NumberSequence.new(.62+.38*fade)
   rig.cyan.Transparency=NumberSequence.new(.62+.38*fade)
  end
 end
 if t>=SHOT.NEEDLE and not rig.landed then
  -- The needle lands: sparks, and a short dim light for your own.
  rig.landed=true
  rig.spot.CFrame=CFrame.new(ground)
  rig.sparks:Emit(10)
  if rig.owned then self:lightFlash(ground+Vector3.yAxis*.6,rig.primary,9,3.5,.22) end
 end
 if rig.landed then
  -- The square shock frame grows from 1 to 6 studs and fades over .4 s.
  local u=math.clamp((t-SHOT.NEEDLE)/.4,0,1)
  local size=1+5*(1-(1-u)^2)
  local thick=.1*(1-u)+.04
  for i,part in ipairs(rig.frame) do
   if u>=1 then part.Transparency=1
   else
    part.Transparency=.3+.7*u
    part.Size=Vector3.new(size+thick,.03,thick)
    part.CFrame=CFrame.new(ground)*CFrame.Angles(0,math.pi/4+(i-1)*math.pi/2,0)*CFrame.new(0,0,size*.5)
   end
  end
  -- The small dark crater fades over .6 s.
  local c=math.clamp((t-SHOT.NEEDLE)/.6,0,1)
  rig.crater.Transparency=.25+.75*c^1.5
  rig.crater.Size=Vector3.new(.04,1.2+.5*(1-(1-c)^3),1.2+.5*(1-(1-c)^3))
  rig.crater.CFrame=CFrame.new(to+Vector3.yAxis*.03)*CFrame.Angles(0,0,math.pi/2)
 end
 if t>=SHOT.HOLD and not rig.lingered then
  -- Motes along the path, as the beam starts to squash; they drift on.
  rig.lingered=true
  local length=(to-from).Magnitude
  rig.trail.Size=Vector3.new(.18,.18,math.max(.2,length))
  rig.trail.CFrame=CFrame.lookAt(from:Lerp(to,.5),to)
  rig.motes:Emit(math.clamp(math.floor(length*2),6,16))
 end
end
function V:stepShots(now: number)
 for _,rig in ipairs(self.shots) do
  if not rig.idle then self:stepShot(rig,now) end
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

-- Down in the pit the light changes: the open-sky fill drops and the
-- exposure comes down a little, so the pit reads as a shaded hole and the
-- beams, gems and break lights are the bright things in it. Client-local;
-- the authored daylight is restored when the player climbs out (and on
-- teardown). A dim warm lamp on the player keeps the walls near them from
-- going flat.
-- Gentler than before (owner: the pastel look, not a dark hole): the pit
-- still dims a little so glowing things stand out down there.
local PIT_FILL=.72 -- ambient light kept at full depth
local PIT_EXPOSURE=-.18 -- exposure change at full depth
function V:stepPitLight(depth: number,dt: number)
 local lighting=game:GetService('Lighting')
 local was=self.pitDepth or 0
 local target=self:reduced() and 0 or depth
 local shade=was+(target-was)*math.clamp(dt*2.5,0,1)
 if math.abs(shade-target)<.002 then shade=target end
 if shade==was and (shade==0 or self.pitBase) then return end
 if not self.pitBase then
  if shade<=0 then return end
  self.pitBase={ambient=lighting.Ambient,outdoor=lighting.OutdoorAmbient,exposure=lighting.ExposureCompensation}
 end
 self.pitDepth=shade
 local base=self.pitBase
 local fill=1-(1-PIT_FILL)*shade
 lighting.Ambient=base.ambient:Lerp(Color3.new(0,0,0),1-fill)
 lighting.OutdoorAmbient=base.outdoor:Lerp(Color3.new(0,0,0),1-fill)
 lighting.ExposureCompensation=base.exposure+PIT_EXPOSURE*shade
 if shade<=0 then self:restorePitLight() end
end
function V:restorePitLight()
 local base=self.pitBase
 if not base then return end
 local lighting=game:GetService('Lighting')
 lighting.Ambient=base.ambient;lighting.OutdoorAmbient=base.outdoor;lighting.ExposureCompensation=base.exposure
 self.pitBase=nil;self.pitDepth=0
end
function V:stepLamp(dt: number)
 if not self.cube then return end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local depth=0
 if root and root:IsA('BasePart') then
  local l=root.Position-self.origin
  local W=self.cube.width
  if l.X>=-2 and l.X<=W+2 and l.Z>=-2 and l.Z<=W+2 then
   -- 0 on the ground beside the pit, 1 about twelve studs down and below.
   depth=math.clamp((self.cube.height+1-l.Y)/12,0,1)
   -- The layer under your feet and its ore, for the HUD's Depth row
   -- (owner, Nov 22: the loop was not fun; going deeper is where the
   -- money is, so say how deep you are and what is down there).
   local L=DigCube.layerAt(self.cube,math.clamp(l.Y-3.2,0,self.cube.height-.01))
   local ore=DigCube.ORES[math.clamp(1+math.floor((L-1)/2.2),1,#DigCube.ORES)]
   local player=Players.LocalPlayer
   if player:GetAttribute('MA_DigLayer')~=L then
    player:SetAttribute('MA_DigLayer',L);player:SetAttribute('MA_DigLayers',#self.cube.layers)
    player:SetAttribute('MA_DigOre',ore.name);player:SetAttribute('MA_DigOreColor',Color3.fromRGB(ore.color[1],ore.color[2],ore.color[3]))
   end
  end
 end
 self:stepPitLight(depth,dt)
 -- Owner, Nov 22: "make sure rocks never block the camera when you are
 -- digging, they just become sorta transparent". On the cube the camera
 -- uses Roblox's Invisicam: rock between the camera and you fades to see-
 -- through instead of the camera zooming in. Off the cube it goes back.
 local player=Players.LocalPlayer
 local over=false
 if root and root:IsA('BasePart') then
  local l=root.Position-self.origin;local W=self.cube.width
  over=l.X>=-4 and l.X<=W+4 and l.Z>=-4 and l.Z<=W+4 and l.Y<=self.cube.height+14
 end
 if player and over~=(self.invisicam~=nil) then
  pcall(function()
   if over then
    self.invisicam=player.DevCameraOcclusionMode
    player.DevCameraOcclusionMode=Enum.DevCameraOcclusionMode.Invisicam
   else
    player.DevCameraOcclusionMode=self.invisicam or Enum.DevCameraOcclusionMode.Zoom
    self.invisicam=nil
   end
  end)
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
 lamp.Brightness=.15+.5*depth
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

function V:clearSparkles()
 for _,sp in pairs(self.sparkles or {}) do sp.part:Destroy() end
 self.sparkles={}
 for _,part in pairs(self.hints) do part:Destroy() end
 self.hints={}
end
-- A soft column of sparkles over a cell (no light, no text).
function V:sparkle(name: string,color: Color3,size: number,rate: number,span: number): BasePart
 local part=fxPart(self.fx,name,color)
 part.Transparency=1;part.Size=Vector3.new(span,.2,span)
 local emitter=Instance.new('ParticleEmitter')
 emitter.Texture='rbxasset://textures/particles/sparkles_main.dds'
 emitter.Color=ColorSequence.new(color)
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size),NumberSequenceKeypoint.new(1,0)})
 emitter.Lifetime=NumberRange.new(.7,1.2);emitter.Rate=rate;emitter.Speed=NumberRange.new(2,5)
 emitter.SpreadAngle=Vector2.new(25,25);emitter.LightEmission=.3
 emitter.EmissionDirection=Enum.NormalId.Top;emitter.Parent=part
 return part
end
-- Where a cell shows on the rock from above: the first rock surface over
-- its middle (the cell's own top once it is open).
function V:surfaceOver(id: number,params: RaycastParams,rock: Instance?): Vector3
 local c=self.cube.cells[id]
 local top=self.origin+Vector3.new(c.cx,self.cube.height+8,c.cz)
 local hit=rock and workspace:Raycast(top,Vector3.new(0,-(self.cube.height+12),0),params)
 return hit and hit.Position or self.origin+Vector3.new(c.cx,c.y1,c.cz)
end
-- Gold sparkles on the rock surface above each treasure pocket still in the
-- rock: something to spot, tap and dig toward. A Needler's hints (the
-- player's DigHints, 'id:tier;..') mark gem cells near its breaks with a
-- smaller sparkle in the gem's own color until they expire or break.
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
   local at=self:surfaceOver(id,params,rock)
   if not sp then
    sp={part=self:sparkle('TreasureSparkle',Color3.fromRGB(255,222,120),.4,5,3)};self.sparkles[id]=sp
   end
   sp.part.CFrame=CFrame.new(at+Vector3.yAxis*.15)
  end
 end
 local list=Players.LocalPlayer and Players.LocalPlayer:GetAttribute('DigHints')
 local want={}
 if type(list)=='string' then
  for id,tier in string.gmatch(list,'(%d+):(%d+)') do want[tonumber(id) :: number]=tonumber(tier) end
 end
 for id,part in pairs(self.hints) do
  if not want[id] or self.cube.removed[id] then part:Destroy();self.hints[id]=nil end
 end
 for id,tier in pairs(want) do
  local c=self.cube.cells[id]
  if c and not self.cube.removed[id] then
   local part=self.hints[id]
   if not part then
    local ore=DigCube.ORES[math.clamp(tier,1,#DigCube.ORES)]
    part=self:sparkle('DigHint',rgb(ore.color),.25,4,math.clamp(c.radius,.8,2.5));self.hints[id]=part
   end
   part.CFrame=CFrame.new(self:surfaceOver(id,params,rock)+Vector3.yAxis*.12)
  end
 end
end

-- Frostbite leaves the rock around its breaks brittle (the holder's
-- 'Brittle' list): each brittle cell wears a thin frost slab on its top,
-- which fades when the cell recovers or breaks.
local FROST=Color3.fromRGB(200,240,255)
function V:clearFrost()
 for _,slab in pairs(self.frost) do slab.model:Destroy() end
 self.frost={}
end
function V:syncBrittle()
 if not self.holder or not self.cube then return end
 local list=self.holder:GetAttribute('Brittle')
 local want={}
 if type(list)=='string' then for id in string.gmatch(list,'%d+') do want[tonumber(id) :: number]=true end end
 local now=os.clock()
 for id,slab in pairs(self.frost) do
  if not want[id] and not slab.fadeAt then slab.fadeAt=now end
 end
 for id in pairs(want) do
  local slab=self.frost[id]
  local c=self.cube.cells[id]
  if slab and slab.fadeAt and not self.cube.removed[id] then
   slab.fadeAt=nil
   for _,part in ipairs(slab.parts) do part.Transparency=.6 end
  elseif not slab and c and not self.cube.removed[id] then
   local model=Instance.new('Model');model.Name='DigFrost'
   local parts={}
   for _,w in ipairs(DigCube.polyWedges(DigCube.grown(c.poly,.05),c.y1+.005,c.y1+.065)) do
    local part=fxPart(model,'FrostSlab',FROST,'WedgePart')
    part.Material=Enum.Material.Ice;part.Transparency=.6
    part.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
    part.CFrame=CFrame.fromMatrix(self.origin+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
     Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
    table.insert(parts,part)
   end
   model.Parent=self.fx
   self.frost[id]={model=model,parts=parts}
  end
 end
end
function V:stepFrost(now: number)
 for id,slab in pairs(self.frost) do
  if not slab.fadeAt and self.cube and self.cube.removed[id] then slab.fadeAt=now end
  if slab.fadeAt then
   local u=(now-slab.fadeAt)/.4
   if u>=1 then slab.model:Destroy();self.frost[id]=nil
   else for _,part in ipairs(slab.parts) do part.Transparency=.6+.4*u end end
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
 self:stepLights(now)
 self:stepGeodes(now)
 self:stepCombo(now)
 self:stepArcs(now)
 self:stepShots(now)
 self:stepFrost(now)
 self:stepLamp(math.clamp(now-(self.lastStep or now),0,.25))
 self.lastStep=now
 self:stepPad(now)
 self:stepShowcase(now)
end

-- The drone gallery (replaces the Nov 22 rock mesh test area, whose big
-- overlapping signs showed from the whole dig): a row of display rocks on
-- the open ground west of the dig cube, each looping one drone type's own
-- way of breaking rock (the same SIG process the real pieces run), with a
-- small sign readable only from beside it. Local only: no drones, rewards
-- or collisions.
-- Only the six active types (owner: "6 drones or less" for now).
local SHOWCASE={
 {code='L',name='STRIKER',sub='cuts terraced pits'},
 {code='Z',name='LANCER',sub='drills a hole'},
 {code='C',name='CHARGER',sub='stamps a crater'},
 {code='N',name='NEEDLER',sub='chips bits out'},
 {code='B',name='BALLCASTER',sub='swells, then pops'},
 {code='I',name='FROSTBITE',sub='freezes it'},
}
local SHOW_PERIOD=4.4
local SHOW_WORK=3.2 -- seconds of work; the rest holds the result
V.SHOWCASE=SHOWCASE
function V:buildShowcase()
 local o=self.origin
 local ground=o.Y+self.cube.height
 local root=Instance.new('Folder');root.Name='DroneGallery';root.Parent=self.fx
 self.showcase={root=root,stations={}}
 local stone=self:colorAt(self.cube.height-.01)
 for i,def in ipairs(SHOWCASE) do
  local at=Vector3.new(o.X-9,ground,o.Z+4+(i-1)*8)
  local plinth=fxPart(root,'GalleryPlinth',Color3.fromRGB(96,98,112));plinth.Size=Vector3.new(6.2,1,6.2)
  plinth.CFrame=CFrame.new(at+Vector3.new(0,.5,0));plinth.CastShadow=true
  local pivot=at+Vector3.new(0,2.6,0)
  local sign=Instance.new('BillboardGui');sign.Name='GallerySign';sign.Adornee=plinth;sign.Size=UDim2.fromOffset(150,38)
  sign.StudsOffsetWorldSpace=Vector3.new(0,4.6,0);sign.MaxDistance=34;sign.LightInfluence=0;sign.Parent=plinth
  local title=Instance.new('TextLabel');title.BackgroundTransparency=1;title.Size=UDim2.new(1,0,.58,0);title.Font=Enum.Font.GothamBold
  title.TextScaled=true;title.TextColor3=V.primaryColor(def.code):Lerp(Color3.new(1,1,1),.3);title.TextStrokeTransparency=.55;title.Text=def.name;title.Parent=sign
  local sub=Instance.new('TextLabel');sub.BackgroundTransparency=1;sub.Position=UDim2.fromScale(0,.58);sub.Size=UDim2.new(1,0,.42,0);sub.Font=Enum.Font.GothamMedium
  sub.TextScaled=true;sub.TextColor3=Color3.fromRGB(240,242,248);sub.TextStrokeTransparency=.6;sub.Text=def.sub;sub.Parent=sign
  local station={def=def,pivot=pivot}
  table.insert(self.showcase.stations,station)
  -- An octagon of rock, like a small dug chunk (two halves for the Halver).
  local poly={}
  for k=0,7 do local a=k*math.pi/4+math.pi/8;table.insert(poly,{math.cos(a)*2.7,math.sin(a)*2.7}) end
  local random=Random.new(i*977)
  local rnd=function() return random:NextNumber() end
  local shapes={}
  if def.code=='H' then
   for side=-1,1,2 do table.insert(shapes,{poly=cutPoly(poly,0,0,-side,0),y0=-1.6,y1=0,color=stone,side=side}) end
  else
   for n,q in ipairs(DigCube.voronoiSplit(poly,3,rnd)) do
    table.insert(shapes,{poly=q,y0=-1.6,y1=0,color=stone:Lerp(Color3.new(0,0,0),.05*(n-1))})
   end
  end
  local sig=SIG[def.code]
  local rec=RockChunks.build(shapes,DigCube.voronoiSplit,rnd,sig and sig.tileArea,sig and sig.maxTiles)
  if rec then
   rec.model.Parent=root;RockChunks.setPose(rec,CFrame.new(pivot));station.rec=rec
   if sig then
    -- A stand-in for a worked piece, so the gallery runs the real process.
    station.proxy={code=def.code,sig=sig,hit=Vector3.zero,thick=1.6,radius=2.7,primary=V.primaryColor(def.code),model=root,
     pivot=pivot,owned=true,mesh=rec,normal=def.code=='H' and Vector3.xAxis or nil,planeAt=pivot+Vector3.new(0,-.1,0)}
    if sig.build then sig.build(self,station.proxy) end
   end
  end
 end
end
-- Progress over one loop, the way each type's work actually arrives:
-- slams and pulses in steps, darts in small steps, beams smoothly.
local function showProgress(code: string,t: number): number
 local u=math.clamp(t/SHOW_WORK,0,1)
 if code=='C' then return math.min(1,math.floor(t/.75)*.25)
 elseif code=='Z' then return math.min(1,math.floor(t/.6)*.2)
 elseif code=='N' then return math.min(1,math.floor(t/.25)*.08)
 end
 return u
end
function V:stepShowcase(now: number)
 if not self.cube then return end
 if not self.showcase or self.showcase.generation~=self.generation then
  if self.showcase then
   for _,st in ipairs(self.showcase.stations) do if st.rec then RockChunks.destroy(st.rec) end end
   self.showcase.root:Destroy()
  end
  self:buildShowcase();self.showcase.generation=self.generation
 end
 local camera=workspace.CurrentCamera
 if now-(self.showcase.stepAt or -1)<1/30 then return end
 self.showcase.stepAt=now
 local reduced=self:reduced()
 for _,st in ipairs(self.showcase.stations) do
  local rec=st.rec
  if rec and not rec.dead and (not camera or (camera.CFrame.Position-st.pivot).Magnitude<80) then
   local def=st.def
   local t=now%SHOW_PERIOD
   local cycle=math.floor(now/SHOW_PERIOD)
   if cycle~=st.cycle then
    st.cycle=cycle;st.fired={};RockChunks.reset(rec)
    local proxy=st.proxy
    if proxy then
     proxy.order=nil;proxy.goneAt=nil;proxy.hits=0;proxy.hitAt=nil;proxy.sweepSet=nil;proxy.ringAt=nil
     proxy.slamAt=nil;proxy.pulseAt=nil;proxy.meshSlam=nil;proxy.meshPulse=nil;proxy.meshAt=nil
    end
   end
   local function once(key: string,at: number): boolean
    if t>=at and not st.fired[key] then st.fired[key]=true;return true end
    return false
   end
   local proxy=st.proxy
   if proxy then
    local p=showProgress(def.code,t)
    if p~=proxy.progress and (def.code=='C' or def.code=='Z') and p>0 then
     if def.code=='C' then proxy.slamAt=now else proxy.pulseAt=now end
    end
    proxy.progress=p
    local lift=proxy.sig.lift and proxy.sig.lift(p) or 0
    RockChunks.setPose(rec,CFrame.new(st.pivot+Vector3.yAxis*lift))
    self:stepSignature(proxy,rec,now,t<SHOW_WORK)
   else
    -- The Striker: the classic ripple and crack pops, with the stage jump.
    local random=self.random
    if t<SHOW_WORK and not reduced then
     local r=MESH_DEFAULT.ripple
     local beat=.7+.3*math.sin(now*math.pi*2*2.2)
     RockChunks.step(rec,now,{ripple={amp=r.amp*1.4*beat,len=r.len,speed=r.speed,glow=r.glow,center=Vector3.zero},glowColor=V.primaryColor('L')})
    else
     RockChunks.step(rec,now,{})
    end
    if once('a',.8) then RockChunks.burst(rec,now,Vector3.zero,BURST.L,random,1);RockChunks.hop(rec,now,random,.7) end
    if once('b',2) then RockChunks.burst(rec,now,Vector3.zero,BURST.L,random,1.3);RockChunks.hop(rec,now,random,1) end
    if once('c',3.1) then RockChunks.burst(rec,now,Vector3.zero,BURST.L,random,1.4);RockChunks.hop(rec,now,random,1) end
   end
  end
 end
end
function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
  if self.lamp then self.lamp:Destroy() end
 self:restorePitLight()
 if self.invisicam then pcall(function() Players.LocalPlayer.DevCameraOcclusionMode=self.invisicam end);self.invisicam=nil end
 self.fx:Destroy()
end
return V
