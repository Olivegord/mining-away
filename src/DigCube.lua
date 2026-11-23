--!strict
-- Dig Cube: one huge block made of stacked layers of 2D Voronoi cells
-- (vertical prisms). Every layer has its own cell pattern, so cracks never
-- line up between layers. Pure and deterministic from a seed: the server and
-- every client build the same cube; only cut chunks replicate.
--
-- Each cut takes out one chunk, marked on the rock before it goes: a seed
-- cell plus its nearest cuttable neighbors in the same layer, grown to the
-- drone's chunk size. Drones differ: some cut tiny chunks fast, others big
-- slabs that drop more rock (D.chunkScale), and cut-size upgrades scale it
-- further. Ore is hidden inside: the server places secret gems per cell
-- (D.placeGems) that come out when their cell breaks. Each worker role digs
-- its own way (D.STYLES); breaks replicate as ops (D.formatOp/D.parseOp).
--
-- The rendered rock is real solid geometry carved on the server: each chunk's
-- cell prisms (D.prismWedges) are subtracted from solid blocks.
--
-- Digging (server): a cell can be cut only when the cells above its core are
-- gone, so pits open as stepped craters instead of drill shafts. Drones pick
-- seeds at random, weighted toward depth, toward the player, away from each
-- other and toward recent cuts: organic pits that deepen and merge.
local D={}
local halfPlaneOf: (poly: {{number}},cx: number,cz: number,nx: number,nz: number) -> {{number}}
D.WIDTH=88
D.LAYERS=10
D.GAP=0 -- seamless: no crack lines until a drone cuts
D.CORE=.7 -- share of a cell (about its centroid) that must be open above before it can be cut
D.DEPTH_PULL=2 -- per-layer preference for going deeper
D.FOCUS_FALLOFF=15 -- studs; drones favor cells near the player or a tapped spot
-- Owner, Nov 22 (latest): the crew sank narrow shafts that swallowed the
-- player and the camera. A broad bowl instead: gentler walls (about 40
-- degrees) and a floor that steps down one layer at a time.
D.RUN=5.5 -- studs the crater widens per layer
D.LEAD=1 -- the crater aims this many layers below its current floor
D.APEX_RADIUS=9 -- studs around the focus that set the current floor
D.CROWD_RADIUS=7
D.RECENT_TIME=20
D.GROUND=3.8 -- top of the ground plate around the cube
D.HEIGHT=44 -- every cube is this deep; its layers vary in thickness inside it
-- Bottom center in world space. The cube is sunk into a pit in the ground
-- east of the hub, its top flush with the ground, so drones mine down into it.
D.CENTER={140,D.GROUND-D.HEIGHT,20}
-- Owner, Nov 22: "the first layer should be a lot hardier, and the others
-- too. it should not melt through them super fast": 2.5x the old first layer
-- (was .2), and steeper with depth (was .4).
D.HP_SCALE=.5
D.HARDNESS_PER_LAYER=.55 -- the bottom layer takes about 6x the work of the top
D.MINE_RADIUS=16 -- studs: drones only cut chunks this close to their player, so you move to keep digging
D.BASE_CUT_AREA=48 -- square studs of top face in a chunk at cutSize 1 (about 8 studs across)
D.MAX_CHUNK=40
D.PAUSE=1.1 -- seconds between the split and the gem-or-nothing reveal
D.TILE=11 -- intact stretches render as one block per tile
-- The dig rock's look, shared by the server blocks and the client pieces,
-- rubble and sealed gem pieces so they always match. Owner, Nov 22: no rock
-- texture, but keep the surface relief and shine: the authored MaterialVariant
-- ROCK_VARIANT (no color map; a normal and a roughness map) when the place
-- has it, else plain SmoothPlastic.
-- Owner, after the relief variant: "the lighting and textures are very ugly.
-- it looked better in pastel". No variant: clean matte rock in the pastel
-- strata below (set ROCK_VARIANT to an authored MaterialVariant name to
-- bring a surface back).
D.ROCK_VARIANT=''
function D.rockLook(): (Enum.Material,string)
 if D.ROCK_VARIANT=='' then return Enum.Material.SmoothPlastic,'' end
 local ok,material,variant=pcall(function()
  local v=game:GetService('MaterialService'):FindFirstChild(D.ROCK_VARIANT)
  if v and v:IsA('MaterialVariant') then return v.BaseMaterial,v.Name end
  return Enum.Material.SmoothPlastic,''
 end)
 if ok then return material,variant end
 return Enum.Material.SmoothPlastic,''
end
D.GEM_CHANCE_ORE=.5 -- per hidden ore cell in a chunk
D.GEM_CHANCE_STONE=.05 -- per plain cell: a lucky find anywhere
D.ROCK_PER_UNIT=150 -- cubic studs of rock per rock drop (bigger chunks drop more)
D.MAX_ROCK_DROPS=4
D.TREASURES=6 -- hidden jackpot cells per cube
D.TREASURE_GEMS=3
-- Ore tiers follow the existing crystal tiers (Workshop.CRYSTAL_TIERS).
D.ORES={
 {material='Amber',name='Amber',color={255,153,20}},
 {material='RunRuby',name='Ruby',color={226,62,78}},
 {material='RunQuartz',name='Quartz',color={97,177,224}},
 {material='RunViolet',name='Violet',color={152,98,222}},
 {material='Diamond',name='Diamond',color={236,226,246}},
}
-- Sand at the top to slate at the bottom: each layer reads as its own stratum.
D.STRATA={
 {222,198,158},{210,184,146},{196,170,136},{182,158,128},{166,147,124},
 {150,136,120},{133,124,116},{116,110,108},{99,96,100},{84,83,92},
}
local ALPHA='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- Rock color: every layer has its own hue (no darkening with depth, so deep
-- pits stay readable), and each layer shifts across its face toward a second
-- tone, so a single layer reads as a gradient rather than a flat slab. The
-- hues are muted toward stone and lowered in value (LAYER_MUTE, LAYER_VALUE):
-- at full strength the rock was brighter than the effects on top of it.
-- Owner, Nov 22: everything read as one tan-and-gold mush (tan rock, gold
-- beams, amber gems). The strata are now one cool pastel family, pale
-- lilac at the top deepening through periwinkle and powder blue to slate
-- violet at the bottom: depth reads at a glance, the palette stays calm
-- (not candyland), and the warm beams and ores pop against it.
D.LAYER_HUES={
 {176,174,206},{160,166,210},{148,168,210},{136,170,204},{126,164,194},
 {116,148,190},{108,128,184},{100,108,170},{92,92,152},{80,76,130},
}
D.LAYER_SHIFT=.5 -- how far a layer's second tone leans toward the next hue
D.LAYER_MUTE=.14 -- share of neutral stone mixed into every hue (the rock stays below the beams and gems)
D.LAYER_VALUE=.86 -- overall brightness of the rock
local STONE_TONE={150,150,166}
local function mix(a: {number},b: {number},t: number): {number}
 return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
end
-- Color of layer L at cube-local x,z.
function D.layerColor(cube: any,L: number,x: number,z: number): {number}
 local n=#D.LAYER_HUES
 local a=D.LAYER_HUES[(L-1)%n+1]
 local b=mix(a,D.LAYER_HUES[L%n+1],D.LAYER_SHIFT)
 b=mix(b,{255,250,236},.08)
 local t=D.noise3(x/22,L*5.7,z/22,(cube and cube.seed or 1)%100000)
 t=math.clamp((t-.2)/.6,0,1)
 local c=mix(mix(a,b,t),STONE_TONE,D.LAYER_MUTE)
 return {c[1]*D.LAYER_VALUE,c[2]*D.LAYER_VALUE,c[3]*D.LAYER_VALUE}
end
-- Layer index holding height y (cube-local).
function D.layerAt(cube: any,y: number): number
 for L,layer in ipairs(cube.layers) do if y>=layer.y0-1e-6 then return L end end
 return #cube.layers
end
function D.colorAt(cube: any,x: number,y: number,z: number): {number}
 return D.layerColor(cube,D.layerAt(cube,y),x,z)
end
-- How big a chunk each drone takes (times BASE_CUT_AREA, squared). Tiny
-- chunks break fast; big ones take longer but drop more rock per break.
D.CHUNK_SIZES={tiny=.6,small=.85,medium=1,large=1.4,huge=1.9}
D.ROLE_CHUNK={Charger='huge',Singularity='huge',Bubbler='large',Starforge='large',Gridcutter='large',Ramiel='medium',
 Halver='medium',Nomad='large',Frostbite='small',Resonator='medium',Needler='tiny',Ballcaster='small'}
-- Starter Strikers spread across sizes by fleet slot so every crew shows them.
D.STRIKER_CHUNKS={'tiny','medium','large','huge'}
local function stringHash(s: string): number
 local h=7
 for i=1,#s do h=(h*31+string.byte(s,i))%1000003 end
 return h
end
function D.chunkSize(role: string?,droneId: string?,slot: number?): string
 local named=role and D.ROLE_CHUNK[role]
 if named then return named end
 if slot then return D.STRIKER_CHUNKS[(slot-1)%#D.STRIKER_CHUNKS+1] end
 return D.STRIKER_CHUNKS[stringHash(droneId or '')%#D.STRIKER_CHUNKS+1]
end
function D.chunkScale(role: string?,droneId: string?,slot: number?): number
 return D.CHUNK_SIZES[D.chunkSize(role,droneId,slot)]
end

-- Dig roles, shared by the server, the client view and the tests: how each
-- worker attacks the rock, what it picks, what it breaks and its color.
-- color = primary attack RGB (beam, projectile, flash, ring, light, role particles, cube belly glow).
-- beam = BeamVFX style published as MiningStyle while digging (nil = no laser).
-- kernel: 'beam' | 'shot' | 'slam' | 'volley' | 'pulse'. size: CHUNK_SIZES key | nil (Striker slot) | 'cell' | 'line' | 'cluster'.
-- pieces: 'terrace' (D.pieces today) | 'none' (one final piece). rockCarry nil = true.
-- pieces: 'terrace' (the Striker's classic stepped pit) or 'none' (the
-- chunk is worked as one piece). early: the cells are cut as soon as the
-- drone is on station, so its own way of breaking the rock (DigCubeView
-- SIG: sinking, chipping, splitting, spiralling...) shows the hole under
-- the piece instead of solid rock (owner, Nov 22: every drone did the same
-- progression of damage).
D.STYLES={
 Striker={code='L',kernel='beam',pick='cone',pieces='terrace',power=1,color={255,159,24},beam='Cutter',rockCarry=false},
 Charger={code='C',kernel='slam',pick='cone',size='huge',pieces='none',early=true,power=1,color={255,92,40},rockCarry=false,
  slam={hover=7,lift=13.5,windup=1.1,dive=.2,hold=.32,recover=.5,clear=1.05},quake={share=.08,radius=10,every=.5}},
 Ballcaster={code='B',kernel='shot',pick='small',size='cell',pieces='none',power=1,color={150,84,255},shape='Ball',carveAhead=true,hintBias=4,
  shot={hover=7,chargeMin=.35,chargeMax=2,chargeDiv=1.4,rested=.4,flight=.26,recover=.15}},
 Needler={code='N',kernel='shot',pick='near',size='cell',pieces='none',power=1,color={255,195,94},shape='Dart',carveAhead=true,
  shot={hover=4.5,first=.25,rested=.6,interval=.2,windup=.05,flight=.04,adjacent=.25,deepPower=1.25,deepLayer=3,maxLive=2},
  near={radius=7,falloff=5,adjacent=6,exposed=2},hints={radius=6,max=12,life=8}},
 Bubbler={code='U',kernel='beam',pick='cone',size='large',pieces='none',early=true,power=.95,color={60,232,212},beam='Repair',collect={ready=.25,range=1e6}},
 Halver={code='H',kernel='beam',pick='wall',size='medium',pieces='none',early=true,power=.8,color={80,100,255},beam='Lance',rockMul=1.5,wall={edge=4,other=.3}},
 -- Owner references, Nov 22: three painted attacks (StrikeArt) in the
 -- slots of dormant types (saved fleets keep the kind names).
 -- Crescent (Gridcutter slot): angled crescent slashes, each one shears a
 -- piece of the chunk loose.
 Gridcutter={code='G',kernel='pulse',pick='cone',size='medium',pieces='none',early=true,power=.9,color={196,150,255},
  pulse={charge=.55,interval=.8,bite=.3,hover=8}},
 Singularity={code='Y',kernel='beam',pick='deep',size='huge',pieces='none',early=true,power=1,color={205,60,255},beam='Singularity',depthPow=2,lead=3},
 -- Starfall (Starforge slot): charges a star that meanders down on a
 -- feathery trail and lands in a small blue pressure strike; it can still
 -- raise a gem a tier.
 Starforge={code='M',kernel='shot',pick='cone',size='small',pieces='none',power=.9,color={110,150,255},shape='Star',carveAhead=true,forge=.4,hintBias=3,
  shot={hover=9,chargeMin=.45,chargeMax=1.8,chargeDiv=1.3,rested=.4,flight=.72,recover=.2}},
 Frostbite={code='I',kernel='beam',pick='cone',size='small',pieces='none',early=true,power=1,color={150,230,255},beam='Sentry',brittle={life=10,mul=.6,max=48}},
 -- Stormcaller (Resonator slot): living lightning strikes; each break
 -- still arcs on into a few small neighbours.
 Resonator={code='V',kernel='pulse',pick='cone',size='medium',pieces='none',early=true,power=.85,color={170,90,255},chain={links=3,budget=.4,maxArea=22,gap=.15},
  pulse={charge=.6,interval=1.05,bite=.38,hover=10}},
 -- Ramiel charges on its original 4.94 s clock (the glass rig's filmed beats);
 -- the bigger budget keeps its rate (cycle 3.7 s -> 6.0 s).
 Ramiel={code='P',kernel='volley',pick='ore',size='cluster',pieces='none',power=1,color={249,22,60},shape='Prism',carveAhead=true,oreBias=6,
  volley={hover=10,charge=4.94,flight=.06,beamHold=.42,breakDelay=.4,recover=.5,budget=5.4,radius=9,maxCells=8,preferOre=true}},
 Nomad={code='A',kernel='volley',pick='cone',size='cluster',pieces='none',power=1,color={70,160,255},shape='Nomad',carveAhead=true,
  volley={hover=16,charge=2.2,flight=.95,breakDelay=0,recover=.4,budget=3.4,radius=5.5,maxCells=7,preferOre=false,blastRadius=4}},
 -- Pulse laser (owner's reference video): short punchy pulses, each bites a big piece out.
 Lancer={code='Z',kernel='pulse',pick='cone',size='medium',pieces='none',early=true,power=1,color={255,236,170},pulse={charge=.45,interval=.7,bite=.36,hover=7}},
} :: {[string]:any}
D.STYLES_BY_CODE={} :: {[string]:any} -- code -> style; each style also gets .role=<key>
for role,style in pairs(D.STYLES) do
 style.role=role
 D.STYLES_BY_CODE[style.code]=style
end
-- The style for a role name or a one-letter code; unknown roles dig like a Striker.
function D.style(roleOrCode: string?): any
 return roleOrCode and (D.STYLES[roleOrCode] or D.STYLES_BY_CODE[roleOrCode]) or D.STYLES.Striker
end
D.BRITTLE_BIAS=3;D.DEPTH_BITE=.35;D.SEAL_PER_BREAK=3;D.SEAL_LIVE=4
-- A little rarer (owner, Nov 22): x.75, about 0.95 per 1000 cubic studs.
D.GEM_P_ORE=.30;D.GEM_P_STONE=.026;D.GEM_VOL=77;D.GEM_VALUE_K=1.4

-- Park-Miller generator: exact in doubles, identical on server and clients.
function D.rng(seed: number)
 local s=math.floor(math.abs(seed))%2147483646+1
 return function(a: number?,b: number?): number
  s=(s*48271)%2147483647
  local u=(s-1)/2147483646
  if a and b then return a+(b-a)*u end
  return u
 end
end
local function hash(ix: number,iy: number,iz: number,seed: number): number
 local h=bit32.bxor(ix*73856093%4294967296,iy*19349663%4294967296,iz*83492791%4294967296,seed*2654435761%4294967296)
 h=bit32.bxor(h,bit32.rshift(h,15))
 h=(h*2246822519)%4294967296
 h=bit32.bxor(h,bit32.rshift(h,13))
 h=(h*3266489917)%4294967296
 h=bit32.bxor(h,bit32.rshift(h,16))
 return h/4294967295
end
local function smooth(t: number): number return t*t*(3-2*t) end
function D.noise3(x: number,y: number,z: number,seed: number): number
 local ix,iy,iz=math.floor(x),math.floor(y),math.floor(z)
 local fx,fy,fz=smooth(x-ix),smooth(y-iy),smooth(z-iz)
 local function l(a: number,b: number,t: number) return a+(b-a)*t end
 local v=0
 local c000,c100=hash(ix,iy,iz,seed),hash(ix+1,iy,iz,seed)
 local c010,c110=hash(ix,iy+1,iz,seed),hash(ix+1,iy+1,iz,seed)
 local c001,c101=hash(ix,iy,iz+1,seed),hash(ix+1,iy,iz+1,seed)
 local c011,c111=hash(ix,iy+1,iz+1,seed),hash(ix+1,iy+1,iz+1,seed)
 v=l(l(l(c000,c100,fx),l(c010,c110,fx),fy),l(l(c001,c101,fx),l(c011,c111,fx),fy),fz)
 return v
end

-- Variable-radius Poisson disk sampling (Bridson). radius(x,z) sets local cell size.
local function poisson(R: any,W: number,radius: (number,number)->number,rmin: number,rmax: number)
 local bucket=math.max(.5,rmin)
 local reach=math.ceil(rmax/bucket)
 local grid={} :: {[number]:{number}}
 local pts={} :: {{x:number,z:number,r:number}}
 local active={} :: {number}
 local function key(ix: number,iz: number) return ix*4099+iz end
 local function free(x: number,z: number,r: number): boolean
  if x<0 or x>W or z<0 or z>W then return false end
  local ix,iz=math.floor(x/bucket),math.floor(z/bucket)
  for gx=ix-reach,ix+reach do
   for gz=iz-reach,iz+reach do
    local list=grid[key(gx,gz)]
    if list then
     for _,i in ipairs(list) do
      local p=pts[i];local need=(r+p.r)*.5
      if (p.x-x)^2+(p.z-z)^2<need*need then return false end
     end
    end
   end
  end
  return true
 end
 local function add(x: number,z: number,r: number)
  table.insert(pts,{x=x,z=z,r=r})
  local k=key(math.floor(x/bucket),math.floor(z/bucket))
  local list=grid[k];if not list then list={};grid[k]=list end
  table.insert(list,#pts);table.insert(active,#pts)
 end
 local x0,z0=R(0,W),R(0,W)
 add(x0,z0,radius(x0,z0))
 while #active>0 do
  local slot=math.floor(R()*#active)+1
  local p=pts[active[slot]]
  local found=false
  for _=1,18 do
   local angle=R(0,math.pi*2);local distance=R(p.r,p.r*1.9)
   local x,z=p.x+math.cos(angle)*distance,p.z+math.sin(angle)*distance
   local r=radius(math.clamp(x,0,W),math.clamp(z,0,W))
   if free(x,z,r) then add(x,z,r);found=true;break end
  end
  if not found then active[slot]=active[#active];active[#active]=nil end
 end
 return pts
end

-- Keep the half-plane closer to p than q; label the new edge with `lab`.
local function clip(poly: {{number}},labels: {number},px: number,pz: number,qx: number,qz: number,lab: number)
 local mx,mz=(px+qx)*.5,(pz+qz)*.5;local nx,nz=qx-px,qz-pz
 local outV,outL={},{}
 local n=#poly
 for k=1,n do
  local a=poly[k];local b=poly[k%n+1];local L=labels[k]
  local da=(a[1]-mx)*nx+(a[2]-mz)*nz;local db=(b[1]-mx)*nx+(b[2]-mz)*nz
  if da<=0 then
   table.insert(outV,a);table.insert(outL,L)
   if db>0 then
    local t=da/(da-db)
    table.insert(outV,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t});table.insert(outL,lab)
   end
  elseif db<=0 then
   local t=da/(da-db)
   table.insert(outV,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t});table.insert(outL,L)
  end
 end
 -- Drop near-duplicate vertices left by points exactly on a bisector.
 local i=1
 while i<=#outV and #outV>3 do
  local a=outV[i];local b=outV[i%#outV+1]
  if (a[1]-b[1])^2+(a[2]-b[2])^2<1e-8 then table.remove(outV,i);table.remove(outL,i) else i+=1 end
 end
 return outV,outL
end

local function polygonStats(poly: {{number}})
 local area,cx,cz=0,0,0
 local n=#poly
 for k=1,n do
  local a=poly[k];local b=poly[k%n+1]
  local cross=a[1]*b[2]-b[1]*a[2]
  area+=cross;cx+=(a[1]+b[1])*cross;cz+=(a[2]+b[2])*cross
 end
 area*=.5
 if math.abs(area)<1e-9 then return 0,poly[1][1],poly[1][2] end
 return math.abs(area),cx/(6*area),cz/(6*area)
end

local function voronoi(pts: {{x:number,z:number,r:number}},W: number,rmax: number)
 local bucket=math.max(1,rmax)
 local grid={} :: {[number]:{number}}
 local function key(ix: number,iz: number) return ix*4099+iz end
 for i,p in ipairs(pts) do
  local k=key(math.floor(p.x/bucket),math.floor(p.z/bucket))
  local list=grid[k];if not list then list={};grid[k]=list end
  table.insert(list,i)
 end
 local cells={}
 for i,p in ipairs(pts) do
  local near={}
  local ix,iz=math.floor(p.x/bucket),math.floor(p.z/bucket)
  for gx=ix-3,ix+3 do
   for gz=iz-3,iz+3 do
    local list=grid[key(gx,gz)]
    if list then for _,j in ipairs(list) do if j~=i then table.insert(near,{j=j,d=(pts[j].x-p.x)^2+(pts[j].z-p.z)^2}) end end end
   end
  end
  table.sort(near,function(a,b) return a.d<b.d end)
  -- Boundary edges carry negative labels: -1 south, -2 east, -3 north, -4 west.
  local poly={{0,0},{W,0},{W,W},{0,W}}
  local labels={-1,-2,-3,-4}
  for _,q in ipairs(near) do
   local far=0
   for _,v in ipairs(poly) do far=math.max(far,(v[1]-p.x)^2+(v[2]-p.z)^2) end
   if q.d*.25>far then break end
   poly,labels=clip(poly,labels,p.x,p.z,pts[q.j].x,pts[q.j].z,q.j)
   if #poly<3 then break end
  end
  cells[i]={poly=poly,labels=labels}
 end
 return cells
end

local function bucketKey(ix: number,iz: number) return ix*4099+iz end
local BUCKET=6

function D.build(seed: number)
 local W=D.WIDTH
 local R=D.rng(seed)
 local cube={seed=seed,width=W,layers={},cells={},removedCount=0}
 local top=0
 local thick={}
 for L=1,D.LAYERS do thick[L]=R(3.6,5.2);top+=thick[L] end
 -- Scale the layers to the fixed depth so the top always meets the ground.
 for L=1,D.LAYERS do thick[L]*=D.HEIGHT/top end
 top=D.HEIGHT
 cube.height=top
 local oreNoiseSeed=math.floor(R(1,1000000))
 local sizeSeed=math.floor(R(1,1000000))
 for L=1,D.LAYERS do
  local y1=top;local y0=top-thick[L];top=y0
  -- Each layer gets its own cut size: big slabs, medium blocks or small chips,
  -- with a regional swing so one layer mixes large and small cells.
  local size=L==1 and R(3.1,3.5) or R(2.9,4)
  local swing=R(.12,.3)
  local rmin,rmax=size*(1-swing),size*(1+swing)
  local function radius(x: number,z: number)
   local n=D.noise3(x/24,L*3.1,z/24,sizeSeed)
   return size*(1+swing*(n*2-1))
  end
  local pts=poisson(R,W,radius,rmin,rmax)
  local raw=voronoi(pts,W,rmax)
  local layer={index=L,y0=y0,y1=y1,thickness=y1-y0,size=size,cells={},grid={},offset=#cube.cells}
  cube.layers[L]=layer
  for i,c in ipairs(raw) do
   if #c.poly>=3 then
    local area,cx,cz=polygonStats(c.poly)
    local radiusMax=0
    local minX,minZ,maxX,maxZ=math.huge,math.huge,-math.huge,-math.huge
    for _,v in ipairs(c.poly) do
     radiusMax=math.max(radiusMax,math.sqrt((v[1]-cx)^2+(v[2]-cz)^2))
     minX=math.min(minX,v[1]);maxX=math.max(maxX,v[1]);minZ=math.min(minZ,v[2]);maxZ=math.max(maxZ,v[2])
    end
    local cell={id=0,layer=L,seedIndex=i,poly=c.poly,labels=c.labels,area=area,cx=cx,cz=cz,radius=radiusMax,
     minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ,y0=y0,y1=y1,neighbors={},across={},boundary=false,ore=0,hp=0,shade=0,sink=0}
    table.insert(cube.cells,cell);cell.id=#cube.cells
    table.insert(layer.cells,cell.id)
   end
  end
  -- Map seed index -> cell id for same-layer neighbors.
  local bySeed={}
  for _,id in ipairs(layer.cells) do bySeed[cube.cells[id].seedIndex]=id end
  for _,id in ipairs(layer.cells) do
   local cell=cube.cells[id]
   for k,lab in ipairs(cell.labels) do
    cell.across[k]=lab>0 and bySeed[lab] or 0
    if lab<0 then cell.boundary=true
    elseif bySeed[lab] then table.insert(cell.neighbors,bySeed[lab]) end
   end
   for gx=math.floor(cell.minX/BUCKET),math.floor(cell.maxX/BUCKET) do
    for gz=math.floor(cell.minZ/BUCKET),math.floor(cell.maxZ/BUCKET) do
     local k=bucketKey(gx,gz);local list=layer.grid[k];if not list then list={};layer.grid[k]=list end
     table.insert(list,id)
    end
   end
   -- Ore veins: a 3D noise threshold that loosens with depth; deeper veins hold rarer ore.
   local t=(L-1)/math.max(1,D.LAYERS-1)
   local mid=(y0+y1)*.5
   local n=D.noise3(cell.cx/13,mid/7,cell.cz/13,oreNoiseSeed)
   if n>.75-.12*t then
    cell.ore=math.clamp(math.floor(1+t*4.2+R(-.7,.7)),1,#D.ORES)
   end
   local hardness=1+D.HARDNESS_PER_LAYER*(L-1)
   cell.hp=math.max(2,cell.area*(y1-y0)*D.HP_SCALE*hardness)
  end
 end
 -- Treasure pockets: a few cells deep in the rock pay a jackpot. Their
 -- sparkles on the surface above give players something to hunt for.
 cube.treasure={} :: {[number]:boolean}
 local placed=0
 for _=1,400 do
  if placed>=D.TREASURES then break end
  local L=math.floor(R(3,D.LAYERS+.999))
  local layer=cube.layers[math.min(D.LAYERS,L)]
  local id=layer.cells[math.floor(R(1,#layer.cells+.999))]
  local c=id and cube.cells[id]
  if c and not cube.treasure[id] and c.cx>8 and c.cx<W-8 and c.cz>8 and c.cz<W-8 then
   local apart=true
   for other in pairs(cube.treasure) do
    local o=cube.cells[other]
    if (o.cx-c.cx)^2+(o.cz-c.cz)^2<18*18 then apart=false;break end
   end
   if apart then cube.treasure[id]=true;placed+=1 end
  end
 end
 cube.removed={} :: {[number]:boolean}
 cube.frontier={} :: {[number]:boolean}
 for _,id in ipairs(cube.layers[1].cells) do cube.frontier[id]=true end
 cube.memo={below={},above={},shoulders={}}
 return cube
end

-- Convex polygon overlap with a small tolerance: touching edges do not count.
local function separated(a: {{number}},b: {{number}}): boolean
 for pass=1,2 do
  local poly=pass==1 and a or b
  local n=#poly
  for k=1,n do
   local p,q=poly[k],poly[k%n+1]
   local nx,nz=q[2]-p[2],p[1]-q[1]
   local len=math.sqrt(nx*nx+nz*nz);if len<1e-9 then continue end
   nx/=len;nz/=len
   local amin,amax,bmin,bmax=math.huge,-math.huge,math.huge,-math.huge
   for _,v in ipairs(a) do local s=v[1]*nx+v[2]*nz;amin=math.min(amin,s);amax=math.max(amax,s) end
   for _,v in ipairs(b) do local s=v[1]*nx+v[2]*nz;bmin=math.min(bmin,s);bmax=math.max(bmax,s) end
   if amax<=bmin+.05 or bmax<=amin+.05 then return true end
  end
 end
 return false
end
local function candidates(cube: any,L: number,minX: number,maxX: number,minZ: number,maxZ: number)
 local layer=cube.layers[L];local seen={};local out={}
 if not layer then return out end
 for gx=math.floor(minX/BUCKET),math.floor(maxX/BUCKET) do
  for gz=math.floor(minZ/BUCKET),math.floor(maxZ/BUCKET) do
   local list=layer.grid[bucketKey(gx,gz)]
   if list then for _,id in ipairs(list) do if not seen[id] then seen[id]=true;table.insert(out,id) end end end
  end
 end
 return out
end
local function overlapping(cube: any,id: number,L: number)
 local cell=cube.cells[id];local out={}
 for _,other in ipairs(candidates(cube,L,cell.minX,cell.maxX,cell.minZ,cell.maxZ)) do
  if not separated(cell.poly,cube.cells[other].poly) then table.insert(out,other) end
 end
 return out
end
function D.below(cube: any,id: number)
 local m=cube.memo.below[id]
 if not m then m=overlapping(cube,id,cube.cells[id].layer+1);cube.memo.below[id]=m end
 return m
end
function D.above(cube: any,id: number)
 local m=cube.memo.above[id]
 if not m then m=overlapping(cube,id,cube.cells[id].layer-1);cube.memo.above[id]=m end
 return m
end
-- Cells of the layer above that must be gone before this one can be cut: the
-- ones over this cell's core (its polygon scaled by D.CORE about the centroid).
-- Cells above the rim may stay as a short overhanging ledge, so each layer
-- down the crater wall steps in by a fraction of a cell: steep stepped walls,
-- but never a one-cell drill shaft (a cut always needs its whole core open).
function D.shoulders(cube: any,id: number)
 local m=cube.memo.shoulders[id]
 if m then return m end
 local cell=cube.cells[id];m={}
 if cell.layer>1 then
  local core={}
  for _,v in ipairs(cell.poly) do table.insert(core,{cell.cx+(v[1]-cell.cx)*D.CORE,cell.cz+(v[2]-cell.cz)*D.CORE}) end
  for _,other in ipairs(D.above(cube,id)) do
   if not separated(core,cube.cells[other].poly) then table.insert(m,other) end
  end
 end
 cube.memo.shoulders[id]=m
 return m
end
-- Would `upper` still rest on rock under its middle once `id` (and the cells
-- in `gone`, a chunk being grown) are removed?
local function supported(cube: any,upper: number,id: number,gone: {[number]:any}?): boolean
 local cell=cube.cells[upper]
 local core={}
 for _,v in ipairs(cell.poly) do table.insert(core,{cell.cx+(v[1]-cell.cx)*D.CORE,cell.cz+(v[2]-cell.cz)*D.CORE}) end
 for _,b in ipairs(D.below(cube,upper)) do
  -- A sealed gem cell may float itself, so it never holds anything up:
  -- otherwise digging under it leaves whole layered stacks hanging on it.
  if b~=id and not cube.removed[b] and not (gone and gone[b]) and not (cube.sealed and cube.sealed[b]) and not separated(core,cube.cells[b].poly) then return true end
 end
 return false
end
D.supported=supported
-- Does this cell rest on anything under its middle (the bottom layer rests
-- on the floor)? A sealed gem cell holds nothing up (it may float itself,
-- owner Nov 22). `gone`: cells treated as removed.
-- Convex clip (Sutherland-Hodgman): the part of `subject` inside `clip`.
local function convexClip(subject: {{number}},clip: {{number}}): {{number}}
 local n=#clip
 local s=0
 for i=1,n do local a,b=clip[i],clip[i%n+1];s+=a[1]*b[2]-b[1]*a[2] end
 local sign=s>=0 and 1 or -1
 local out=subject
 for i=1,n do
  if #out==0 then break end
  local a,b=clip[i],clip[i%n+1]
  local ex,ey=b[1]-a[1],b[2]-a[2]
  local function inside(p: {number}): boolean return sign*(ex*(p[2]-a[2])-ey*(p[1]-a[1]))>=-1e-9 end
  local input=out;out={}
  local prev=input[#input]
  for _,cur in ipairs(input) do
   local ci,pi=inside(cur),inside(prev)
   if ci~=pi then
    local dx,dy=cur[1]-prev[1],cur[2]-prev[2]
    local den=dx*ey-dy*ex
    if math.abs(den)>1e-12 then
     local t=((a[1]-prev[1])*ey-(a[2]-prev[2])*ex)/den
     table.insert(out,{prev[1]+dx*t,prev[2]+dy*t})
    end
   end
   if ci then table.insert(out,cur) end
   prev=cur
  end
 end
 return out
end
-- How much of each cell below lies under this one: {{id,area}}, cached.
function D.overlaps(cube: any,id: number): {any}
 cube.memo.overlap=cube.memo.overlap or {}
 local m=cube.memo.overlap[id]
 if m then return m end
 m={}
 local poly=cube.cells[id].poly
 for _,b in ipairs(D.below(cube,id)) do
  local piece=convexClip(poly,cube.cells[b].poly)
  local area=#piece>=3 and D.polyArea(piece) or 0
  if area>1e-4 then table.insert(m,{b,area}) end
 end
 cube.memo.overlap[id]=m
 return m
end
-- At least this share of a regular cell's footprint must sit on rock, or it
-- reads as floating (owner, Nov 22). The old test passed a cell whose middle
-- touched any rock below, even a sliver.
D.RESTING_SHARE=.45
function D.resting(cube: any,id: number,gone: {[number]:any}?): boolean
 local cell=cube.cells[id]
 if cell.layer>=#cube.layers then return true end
 local need=D.polyArea(cell.poly)*D.RESTING_SHARE
 local held=0
 for _,o in ipairs(D.overlaps(cube,id)) do
  local b=o[1]
  if not cube.removed[b] and not (gone and gone[b]) and not (cube.sealed and cube.sealed[b]) then
   held+=o[2]
   if held>=need then return true end
  end
 end
 return false
end
-- No regular cell floats (owner, Nov 22: "floating rocks/cells cannot exist, they
-- look horrible"; sealed gem cells may). After `seeds` are removed, every
-- regular cell above them left
-- with nothing under its middle falls too, and so on up the stack. Removes
-- them and returns them in order (at most `most`, default 96).
function D.collapse(cube: any,seeds: {number},most: number?): {number}
 local fallen={}
 local queue=table.clone(seeds)
 local i=1
 while i<=#queue and #fallen<(most or 96) do
  local id=queue[i];i+=1
  for _,up in ipairs(D.above(cube,id)) do
   if not cube.removed[up] and not (cube.sealed and cube.sealed[up]) and not D.resting(cube,up) then
    D.remove(cube,up);table.insert(fallen,up);table.insert(queue,up)
   end
  end
 end
 return fallen
end
-- A cell can be cut once nothing rests on its middle, and only if no other
-- cell would be left floating with nothing under its middle (owner, Nov 22:
-- regular cells never float). Sealed gem cells (`cube.sealed`, set by the
-- server) may float: they neither block the cells under them nor need them.
function D.diggable(cube: any,id: number,gone: {[number]:any}?): boolean
 if cube.removed[id] then return false end
 local sealed=cube.sealed
 for _,other in ipairs(D.shoulders(cube,id)) do if not cube.removed[other] and not (sealed and sealed[other]) then return false end end
 for _,upper in ipairs(D.above(cube,id)) do
  if not cube.removed[upper] and not (sealed and sealed[upper]) and not supported(cube,upper,id,gone) then return false end
 end
 return true
end
-- A cell needs rendering when air touches it: top layer, or a cut cell beside, above or below it.
function D.visible(cube: any,id: number): boolean
 if cube.removed[id] then return false end
 local cell=cube.cells[id]
 if cell.layer==1 then return true end
 for _,other in ipairs(cell.neighbors) do if cube.removed[other] then return true end end
 for _,other in ipairs(D.above(cube,id)) do if cube.removed[other] then return true end end
 for _,other in ipairs(D.below(cube,id)) do if cube.removed[other] then return true end end
 return false
end
-- Cells whose visibility can change when `id` is removed.
function D.affected(cube: any,id: number)
 local out={}
 for _,other in ipairs(cube.cells[id].neighbors) do table.insert(out,other) end
 for _,other in ipairs(D.below(cube,id)) do table.insert(out,other) end
 for _,other in ipairs(D.above(cube,id)) do table.insert(out,other) end
 return out
end
function D.remove(cube: any,id: number)
 if cube.removed[id] then return false end
 cube.removed[id]=true;cube.removedCount+=1;cube.frontier[id]=nil
 for _,other in ipairs(D.below(cube,id)) do if not cube.removed[other] then cube.frontier[other]=true end end
 return true
end

-- Two sets read as one (live: either may still grow). Cells claimed by other
-- drones count as gone in every support check, so two jobs never jointly
-- leave a cell above them floating (likely with 13 drones at work).
local function union(a: {[number]:any}?,b: {[number]:any}?): {[number]:any}?
 if not a then return b end
 if not b then return a end
 local x,y=a,b
 return setmetatable({},{__index=function(_,k) return x[k] or y[k] end})
end

-- Weighted random choice among cuttable cells. opts:
--  focusX/focusZ: local point the crew should favor (player or tapped spot)
--  taken: {[cellId]=true} claimed by other drones; takenPoints: {{x,z}} of those claims
--   (claimed cells also count as gone when checking what the rest rests on)
--  recent: {[cellId]=time} of removals; now; random: () -> number
--  anchorX/anchorZ: the player's local position; only cells within radius
--  (default D.MINE_RADIUS) of it are cut, so the player has to move along
--  depthPow: depth preference exponent (default 1: weight DEPTH_PULL^((layer-1)*depthPow))
--  lead: layers the crater aims below its floor (default D.LEAD)
--  falloff: studs of the focus preference (default D.FOCUS_FALLOFF)
--  weight(id,cell,apex): an extra weight multiplier (0 rules a cell out)
--  gone: {[cellId]=true} treated as removed (never picked, hold nothing up)
function D.pick(cube: any,opts: any): number?
 local total=0
 local choices,weights={},{}
 local random=opts.random or math.random
 local depthPow=opts.depthPow or 1
 local falloff=opts.falloff or D.FOCUS_FALLOFF
 local weight: ((number,any,number) -> number?)?=opts.weight
 local gone=union(opts.gone,opts.taken)
 -- The crew carves toward a cone around the focus whose tip sits D.LEAD layers
 -- below the deepest floor reached there. Cells inside the cone are wanted
 -- (deeper first); the rim widens only as far as going deeper needs. Moving
 -- the focus starts a new crater that later merges with the old ones.
 local apex=1
 if opts.focusX then
  for id in pairs(cube.frontier) do
   local cell=cube.cells[id]
   if cell.layer>apex and (cell.cx-opts.focusX)^2+(cell.cz-opts.focusZ)^2<=D.APEX_RADIUS*D.APEX_RADIUS then apex=cell.layer end
  end
  apex=math.min(D.LAYERS,apex+(opts.lead or D.LEAD))
 end
 for id in pairs(cube.frontier) do
  local cell=cube.cells[id]
  local near=not opts.anchorX or math.sqrt((cell.cx-opts.anchorX)^2+(cell.cz-opts.anchorZ)^2)-cell.radius<=(opts.radius or D.MINE_RADIUS)
  if near and not (opts.taken and opts.taken[id]) and not (opts.gone and opts.gone[id]) and D.diggable(cube,id,gone) then
   local w=D.DEPTH_PULL^((cell.layer-1)*depthPow)
   if opts.focusX then
    local d=math.sqrt((cell.cx-opts.focusX)^2+(cell.cz-opts.focusZ)^2)
    local wanted=apex-math.max(0,d-cell.radius)/D.RUN
    if cell.layer>wanted+.5 then w*=.004 end
    w*=.05+math.exp(-d/falloff)
   end
   if opts.takenPoints then
    for _,p in ipairs(opts.takenPoints) do
     if (p[1]-cell.cx)^2+(p[2]-cell.cz)^2<D.CROWD_RADIUS*D.CROWD_RADIUS then w*=.2 end
    end
   end
   if opts.recent and opts.now then
    local fresh=false
    for _,other in ipairs(cell.neighbors) do local t=opts.recent[other];if t and opts.now-t<D.RECENT_TIME then fresh=true;break end end
    if not fresh then for _,other in ipairs(D.above(cube,id)) do local t=opts.recent[other];if t and opts.now-t<D.RECENT_TIME then fresh=true;break end end end
    if fresh then w*=2 end
   end
   if weight then w*=weight(id,cell,apex) or 1 end
   w*=.4+random()
   if w>0 then total+=w;table.insert(choices,id);table.insert(weights,w) end
  end
 end
 if total<=0 then return nil end
 local roll=random()*total
 for i,id in ipairs(choices) do roll-=weights[i];if roll<=0 then return id end end
 return choices[#choices]
end

-- A chunk: the seed plus the closest cuttable same-layer neighbors until the
-- top face reaches the drone's cut area. cutSize scales the chunk's width.
-- Depth bite: harder (deeper) layers come away in smaller chunks, area times
-- (1+HARDNESS_PER_LAYER*(L-1))^-DEPTH_BITE (x0.585 at the bottom layer).
-- Cells in `taken` (claimed by other drones) count as gone for support.
function D.chunk(cube: any,seed: number,cutSize: number?,taken: {[number]:any}?,random: (() -> number)?): {number}
 local cut=math.max(.5,cutSize or 1)
 local roll=random and random() or .5
 local s=cube.cells[seed]
 local bite=(1+D.HARDNESS_PER_LAYER*(s.layer-1))^-D.DEPTH_BITE
 local target=D.BASE_CUT_AREA*cut*cut*(.75+.5*roll)*bite
 local ids={seed};local inside={[seed]=true};local area=s.area
 local gone=union(inside,taken)
 local open={}
 local function offer(id: number)
  for _,n in ipairs(cube.cells[id].neighbors) do
   if not inside[n] and not open[n] and not cube.removed[n] and not (taken and taken[n]) and D.diggable(cube,n,gone) then open[n]=true end
  end
 end
 offer(seed)
 while #ids<D.MAX_CHUNK do
  local best,bestD=nil,math.huge
  for id in pairs(open) do
   local c=cube.cells[id];local d=(c.cx-s.cx)^2+(c.cz-s.cz)^2
   if d<bestD then best,bestD=id,d end
  end
  if not best then break end
  -- Re-check against the chunk as it is now: two cells may each hold up the
  -- same cell above alone, but not both go.
  if not D.diggable(cube,best,gone) then open[best]=nil;continue end
  local c=cube.cells[best]
  -- Stop when adding this cell overshoots the target by more than it helps.
  if area+c.area*.5>target then break end
  open[best]=nil;inside[best]=true;table.insert(ids,best);area+=c.area
  offer(best)
 end
 table.sort(ids)
 return ids
end
-- mul(id): an optional per-cell HP multiplier (a brittle cell takes .6).
function D.chunkHp(cube: any,ids: {number},cutSize: number?,mul: ((number) -> number)?): number
 local hp=0
 for _,id in ipairs(ids) do hp+=cube.cells[id].hp*(mul and mul(id) or 1) end
 -- Bigger cuts take longer but move more rock per second than small ones.
 return hp/math.sqrt(math.max(.5,cutSize or 1))
end
-- A volley's cluster (Ramiel, Nomad): the seed plus exposed frontier cells
-- whose centre lies within `radius` (horizontal) of the seed's; ore first
-- when preferOre, then nearest. A cell joins only while it can be cut with
-- the cluster (and the claimed cells) gone, the HP sum stays within `budget`
-- and there are fewer than maxCells. o={radius,maxCells,budget,taken,preferOre,mul}.
-- The seed always comes first; the rest in the order they joined (not sorted).
function D.cluster(cube: any,seed: number,o: any?): {number}
 local opts=o or {}
 local radius=opts.radius or 6
 local maxCells=opts.maxCells or 6
 local budget=opts.budget or math.huge
 local taken=opts.taken
 local mul=opts.mul
 local preferOre=opts.preferOre==true
 local sealed=cube.sealed
 local s=cube.cells[seed]
 local function hpOf(id: number): number return cube.cells[id].hp*(mul and mul(id) or 1) end
 local ids={seed};local inside={[seed]=true}
 local gone=union(inside,taken)
 local hp=hpOf(seed)
 local list: {{id: number,d: number,ore: boolean}}={}
 for id in pairs(cube.frontier) do
  if id~=seed and not cube.removed[id] and not (taken and taken[id]) and not (sealed and sealed[id]) then
   local c=cube.cells[id]
   local d=math.sqrt((c.cx-s.cx)^2+(c.cz-s.cz)^2)
   if d<=radius and D.visible(cube,id) then table.insert(list,{id=id,d=d,ore=c.ore>0}) end
  end
 end
 table.sort(list,function(a: {id: number,d: number,ore: boolean},b: {id: number,d: number,ore: boolean}): boolean
  if preferOre and a.ore~=b.ore then return a.ore end
  if a.d~=b.d then return a.d<b.d end
  return a.id<b.id
 end)
 for _,e in ipairs(list) do
  if #ids>=maxCells then break end
  local h=hpOf(e.id)
  if hp+h<=budget and D.diggable(cube,e.id,gone) then
   table.insert(ids,e.id);inside[e.id]=true;hp+=h
  end
 end
 return ids
end
-- A Gridcutter line: from the seed, walk same-layer neighbours along
-- sign*axis, each step taking the neighbour that advances least while its
-- centre stays within `width` of the axis line through the seed and it can
-- be cut with the line (and the claimed cells) gone. Fewer than `min` cells:
-- also walk back from the seed (prepended, so the list stays contiguous).
-- At most `max` cells, in walk order. o={axis='x'|'z',sign=1|-1,min,max,width,taken}.
function D.line(cube: any,seed: number,o: any?): {number}
 local opts=o or {}
 local alongX=opts.axis~='z'
 local sign=(opts.sign or 1)<0 and -1 or 1
 local minN=opts.min or 3
 local maxN=opts.max or 6
 local width=opts.width or 2
 local taken=opts.taken
 local sealed=cube.sealed
 local s=cube.cells[seed]
 local ids={seed};local inside={[seed]=true}
 local gone=union(inside,taken)
 local function along(c: any): number return alongX and c.cx or c.cz end
 local function across(c: any): number return alongX and c.cz or c.cx end
 local axisLine=across(s)
 local function walk(dir: number,front: boolean)
  local cur=s
  while #ids<maxN do
   local best,bestAdvance=nil,math.huge
   for _,n in ipairs(cur.neighbors) do
    if not inside[n] and not cube.removed[n] and not (taken and taken[n]) and not (sealed and sealed[n]) then
     local c=cube.cells[n]
     local advance=dir*(along(c)-along(cur))
     if advance>0 and advance<bestAdvance and math.abs(across(c)-axisLine)<=width and D.diggable(cube,n,gone) then
      best,bestAdvance=n,advance
     end
    end
   end
   if not best then break end
   inside[best]=true
   if front then table.insert(ids,1,best) else table.insert(ids,best) end
   cur=cube.cells[best]
  end
 end
 walk(sign,false)
 if #ids<minN then walk(-sign,true) end
 return ids
end
function D.cellVolume(cube: any,id: number): number
 local c=cube.cells[id]
 return c.area*(c.y1-c.y0)
end
-- A chunk breaks in nested stages before its real cells go (owner, Nov 22):
-- first a small Voronoi cell around its middle, then a bigger one turned a
-- little, each shallower than the layer, then the actual cells. A stage cell
-- is the Voronoi cell of the chunk's center among a ring of sites, clipped to
-- the chunk's cells. Each entry is {at, parts={{poly,y0,y1}}, ids}: it breaks
-- once the chunk's damage reaches `at`; the last one (final=true, ids=the
-- chunk) is what is left of the cells once the last stage is out.
D.STAGE_SITES=6
local function hashIds(ids: {number}): number
 local h=0
 for _,id in ipairs(ids) do h=(h*31+id)%1000003 end
 return h
end
-- Keep the part of convex `poly` inside convex `cell` (both counter- or clockwise).
local function clipConvex(poly: {{number}},cell: {{number}}): {{number}}
 local n=#cell
 local mx,mz=0,0
 for _,v in ipairs(cell) do mx+=v[1];mz+=v[2] end
 mx/=n;mz/=n
 local out=poly
 for k=1,n do
  local a,b=cell[k],cell[k%n+1]
  local nx,nz=b[2]-a[2],-(b[1]-a[1])
  if (mx-a[1])*nx+(mz-a[2])*nz>0 then nx,nz=-nx,-nz end
  out=halfPlaneOf(out,a[1],a[2],nx,nz)
  if #out<3 then return {} end
 end
 return out
end
-- The Voronoi cell of (cx,cz) among a ring of sites about 2r away.
local function stageCell(cx: number,cz: number,r: number,angle: number,seed: number): {{number}}
 local R=D.rng(seed)
 local poly={{cx-6*r,cz-6*r},{cx+6*r,cz-6*r},{cx+6*r,cz+6*r},{cx-6*r,cz+6*r}}
 for i=1,D.STAGE_SITES do
  local a=angle+(i-1)*2*math.pi/D.STAGE_SITES+R(-.3,.3)
  local d=2*r*R(.85,1.2)
  local px,pz=cx+math.cos(a)*d,cz+math.sin(a)*d
  local nx,nz=px-cx,pz-cz
  local l=math.sqrt(nx*nx+nz*nz)
  poly=halfPlaneOf(poly,(cx+px)*.5,(cz+pz)*.5,nx/l,nz/l)
 end
 return poly
end
local function polyArea(poly: {{number}}): number
 local a=0
 for k=1,#poly do local p,q=poly[k],poly[k%#poly+1];a+=p[1]*q[2]-q[1]*p[2] end
 return math.abs(a)*.5
end
D.polyArea=polyArea
-- What is left of convex `cell` outside convex `hole`, as convex pieces.
local function outside(cell: {{number}},hole: {{number}}): {{{number}}}
 local n=#hole
 local mx,mz=0,0
 for _,v in ipairs(hole) do mx+=v[1];mz+=v[2] end
 mx/=n;mz/=n
 local rest=cell
 local out={}
 for k=1,n do
  local a,b=hole[k],hole[k%n+1]
  local nx,nz=b[2]-a[2],-(b[1]-a[1])
  if (mx-a[1])*nx+(mz-a[2])*nz>0 then nx,nz=-nx,-nz end
  local piece=halfPlaneOf(rest,a[1],a[2],-nx,-nz)
  if #piece>=3 and polyArea(piece)>.04 then table.insert(out,piece) end
  rest=halfPlaneOf(rest,a[1],a[2],nx,nz)
  if #rest<3 then break end
 end
 return out
end
-- mode: 'terrace' (default: the nested stages above) or 'none' (one final
-- piece of whole cells). Every part carries cell=<id> of the cell it is cut from.
function D.pieces(cube: any,ids: {number},mode: string?): {any}
 if mode=='none' then
  local P={}
  for i,id in ipairs(ids) do local c=cube.cells[id];P[i]={poly=c.poly,y0=c.y0,y1=c.y1,cell=id} end
  return {{stage=1,at=1,parts=P,shell=P,ids=table.clone(ids),final=true}}
 end
 local area=D.chunkArea(cube,ids)
 local cx,cz=D.chunkCenter(cube,ids)
 local first=cube.cells[ids[1]]
 local thick=first.y1-first.y0
 local seed=hashIds(ids)
 local radius=math.sqrt(area/math.pi)
 local stages=area<9 and 1 or 2
 local base=(seed*.6180339887)%1*math.pi*2
 -- Terraces (owner, Nov 22: keep the earlier stages for more depth): each
 -- stage cuts its whole cell one step down AND deepens everything the
 -- earlier stages opened by another step, so the first hole stays as a
 -- deeper pit inside the next. Steps are shallow (owner: a little more
 -- shallow); the middle ends at stages*step.
 local step=thick*(stages==1 and .34 or .22)
 local out={}
 local polys={}
 for k=1,stages do
  local size=stages==1 and .5 or (k==1 and .38 or .66)
  -- Each stage turned a little from the one before.
  local poly=stageCell(cx,cz,radius*size,base+k*.45,seed+k*7919)
  local last=polys[#polys]
  local prev=step*(k-1) -- depth of the earlier stages' middle before this one
  local parts,shell={},{}
  for _,id in ipairs(ids) do
   local c=cube.cells[id]
   local q=clipConvex(poly,c.poly)
   if #q>=3 and polyArea(q)>.04 then
    table.insert(parts,{poly=q,y0=c.y1-step,y1=c.y1,cell=id})
    if last then
     -- The ring this stage opens, and the earlier pit one step deeper.
     for _,r in ipairs(outside(q,last)) do table.insert(shell,{poly=r,y0=c.y1-step,y1=c.y1,cell=id}) end
     local inner=clipConvex(q,last)
     if #inner>=3 and polyArea(inner)>.04 then
      table.insert(parts,{poly=inner,y0=c.y1-prev-step,y1=c.y1,cell=id})
      table.insert(shell,{poly=inner,y0=c.y1-prev-step,y1=c.y1-prev,cell=id})
     end
    else
     table.insert(shell,{poly=q,y0=c.y1-step,y1=c.y1,cell=id})
    end
   end
  end
  if #parts>0 then
   table.insert(out,{stage=k,at=stages==1 and .4 or (k==1 and .25 or .55),parts=parts,shell=shell,ids={},centerDepth=prev+step})
   table.insert(polys,poly)
  end
 end
 -- The actual cells: the rock under and around the terraces.
 local n=#polys
 local deepest=step*n
 local parts={}
 for _,id in ipairs(ids) do
  local c=cube.cells[id]
  if n>0 then
   table.insert(parts,{poly=c.poly,y0=c.y0,y1=c.y1-deepest,cell=id})
   for _,q in ipairs(outside(c.poly,polys[n])) do table.insert(parts,{poly=q,y0=c.y1-deepest,y1=c.y1,cell=id}) end
   -- Each terrace ring: from the bottom up to its own floor.
   for j=n,2,-1 do
    local inside=clipConvex(polys[j],c.poly)
    if #inside>=3 then
     for _,q in ipairs(outside(inside,polys[j-1])) do table.insert(parts,{poly=q,y0=c.y1-deepest,y1=c.y1-step*(n-j+1),cell=id}) end
    end
   end
  else
   table.insert(parts,{poly=c.poly,y0=c.y0,y1=c.y1,cell=id})
  end
 end
 table.insert(out,{stage=#out+1,at=1,parts=parts,shell=parts,ids=table.clone(ids),final=true})
 return out
end
-- A convex polygon cut into about n Voronoi cells (sites placed at random
-- inside it), each convex. For rubble that breaks like the rock it came from.
function D.voronoiSplit(poly: {{number}},n: number,random: () -> number): {{{number}}}
 if n<=1 or polyArea(poly)<1 then return {poly} end
 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for _,v in ipairs(poly) do minX=math.min(minX,v[1]);maxX=math.max(maxX,v[1]);minZ=math.min(minZ,v[2]);maxZ=math.max(maxZ,v[2]) end
 local inside=function(x: number,z: number): boolean
  local sign=0
  for k=1,#poly do
   local a,b=poly[k],poly[k%#poly+1]
   local c=(b[1]-a[1])*(z-a[2])-(b[2]-a[2])*(x-a[1])
   if c~=0 then
    local sg=c>0 and 1 or -1
    if sign==0 then sign=sg elseif sg~=sign then return false end
   end
  end
  return true
 end
 local sites={}
 for _=1,n*12 do
  if #sites>=n then break end
  local x,z=minX+(maxX-minX)*random(),minZ+(maxZ-minZ)*random()
  if inside(x,z) then table.insert(sites,{x,z}) end
 end
 if #sites<2 then return {poly} end
 local out={}
 for i,a in ipairs(sites) do
  local cell=poly
  for j,b in ipairs(sites) do
   if i~=j then
    local nx,nz=b[1]-a[1],b[2]-a[2]
    local l=math.sqrt(nx*nx+nz*nz)
    if l>1e-6 then cell=halfPlaneOf(cell,(a[1]+b[1])*.5,(a[2]+b[2])*.5,nx/l,nz/l) end
    if #cell<3 then break end
   end
  end
  if #cell>=3 and polyArea(cell)>.03 then table.insert(out,cell) end
 end
 return #out>0 and out or {poly}
end
-- Wedges filling a list of {poly,y0,y1} parts, grown a little so neighbors
-- overlap when subtracted (like prismWedges).
function D.partWedges(cube: any,parts: {any}): {any}
 local out={}
 for _,part in ipairs(parts) do
  local y1=part.y1+(part.y1>=cube.height-.01 and .5 or .03)
  for _,w in ipairs(D.polyWedges(D.grown(part.poly,D.CARVE_OVERLAP*.5),part.y0-.03,y1)) do
   w.size[2]+=.16;w.size[3]+=.16
   table.insert(out,w)
  end
 end
 return out
end
function D.volume(cube: any,ids: {number}): number
 local v=0
 for _,id in ipairs(ids) do local c=cube.cells[id];v+=c.area*(c.y1-c.y0) end
 return v
end
-- Rock drops for a chunk of this volume.
function D.rockDrops(volume: number): number
 return math.clamp(math.floor(volume/D.ROCK_PER_UNIT+.5),1,D.MAX_ROCK_DROPS)
end
-- Where the beam hits a chunk: the center of its top, and its floor.
function D.contact(cube: any,ids: {number}): ({number},number)
 local _,cx,cz=D.chunkArea(cube,ids)
 local first=cube.cells[ids[1]]
 return {cx,first.y1,cz},first.y0
end
-- Solid wedges filling each cell of a chunk, for subtracting from the
-- rendered rock. Grown a little so neighbors overlap: wedges that only touch
-- edge to edge leave paper-thin walls along their seams when subtracted.
-- The top layer reaches above the surface so no skin is left on top.
function D.prismWedges(cube: any,ids: {number}): {any}
 local out={}
 for _,id in ipairs(ids) do
  local cell=cube.cells[id]
  local poly=D.grown(cell.poly,D.CARVE_OVERLAP)
  local y1=cell.y1+(cell.layer==1 and .5 or .03)
  for _,w in ipairs(D.polyWedges(poly,cell.y0-.03,y1)) do
   w.size[2]+=.16;w.size[3]+=.16
   table.insert(out,w)
  end
 end
 return out
end
-- The point a chunk is worked from (owner, Nov 22: everything centered under
-- the drone): its area centroid when that lies in one of its cells, else the
-- middle of its cell nearest the centroid. The nested stages grow from here,
-- the drone hovers straight above it and its beam lands on it.
local function inConvex(poly: {{number}},x: number,z: number): boolean
 local sign=0
 for k=1,#poly do
  local a,b=poly[k],poly[k%#poly+1]
  local c=(b[1]-a[1])*(z-a[2])-(b[2]-a[2])*(x-a[1])
  if c~=0 then
   local sg=c>0 and 1 or -1
   if sign==0 then sign=sg elseif sg~=sign then return false end
  end
 end
 return true
end
function D.chunkCenter(cube: any,ids: {number}): (number,number,number)
 local _,cx,cz=D.chunkArea(cube,ids)
 local best,bestD=ids[1],math.huge
 for _,id in ipairs(ids) do
  local c=cube.cells[id]
  if inConvex(c.poly,cx,cz) then return cx,cz,id end
  local d=(c.cx-cx)^2+(c.cz-cz)^2
  if d<bestD then best,bestD=id,d end
 end
 local c=cube.cells[best]
 return c.cx,c.cz,best
end
function D.chunkArea(cube: any,ids: {number}): (number,number,number)
 local area,cx,cz=0,0,0
 for _,id in ipairs(ids) do local c=cube.cells[id];area+=c.area;cx+=c.cx*c.area;cz+=c.cz*c.area end
 if area<=0 then return 0,0,0 end
 return area,cx/area,cz/area
end
-- Gem roll for a chunk. Returns the ore tier (0 = nothing inside).
-- Did this chunk crack a treasure pocket?
function D.hasTreasure(cube: any,ids: {number}): boolean
 for _,id in ipairs(ids) do if cube.treasure[id] then return true end end
 return false
end
-- Gem tier for a layer (deeper layers hold richer ore).
function D.layerTier(layer: number): number
 local t=(layer-1)/math.max(1,D.LAYERS-1)
 return math.clamp(math.floor(1+t*4.2),1,#D.ORES)
end
function D.gemRoll(cube: any,ids: {number},random: () -> number): number
 local miss=1;local tier=0;local deepest=1
 for _,id in ipairs(ids) do
  local c=cube.cells[id]
  deepest=math.max(deepest,c.layer)
  if c.ore>0 then miss*=1-D.GEM_CHANCE_ORE;tier=math.max(tier,c.ore) else miss*=1-D.GEM_CHANCE_STONE end
 end
 if random()>=1-miss then return 0 end
 if tier>0 then return tier end
 local t=(deepest-1)/math.max(1,D.LAYERS-1)
 return math.clamp(math.floor(1+t*4.2+(random()*1.4-.7)),1,#D.ORES)
end
-- Secret gems, placed per cell by the server when it builds a cube (never
-- replicated): {[id]={tier,count,treasure}}. A cell's chance grows with its
-- volume (clamped), so gems per volume dug are the same for every drone and
-- every crack size. Ore cells hold their own ore; plain cells a tier by
-- depth. Treasure pockets always hold TREASURE_GEMS gems of a rich tier.
-- About 0.074 per cell, 0.95 per 1000 cubic studs.
function D.placeGems(cube: any,random: () -> number): {[number]:any}
 local gems={}
 local ores=#D.ORES
 for id,c in ipairs(cube.cells) do
  if cube.treasure and cube.treasure[id] then
   gems[id]={tier=math.max(3,math.min(ores,D.layerTier(c.layer)+1)),count=D.TREASURE_GEMS,treasure=true}
  else
   local v=c.area*(c.y1-c.y0)
   local p=math.clamp(v/D.GEM_VOL,.5,1.6)*(c.ore>0 and D.GEM_P_ORE or D.GEM_P_STONE)
   if random()<p then
    local tier=c.ore
    if tier<=0 then
     local t=(c.layer-1)/math.max(1,D.LAYERS-1)
     tier=math.clamp(math.floor(1+t*4.2+random()*1.4-.7),1,ores)
    end
    gems[id]={tier=tier,count=1,treasure=false}
   end
  end
 end
 return gems
end
-- Value scale of a gem from the volume of the cell that held it.
function D.gemSize(volume: number): number
 return D.GEM_VALUE_K*math.clamp(volume/D.GEM_VOL,.75,1.35)
end
local function contains(poly: {{number}},x: number,z: number): boolean
 local sign=0
 local n=#poly
 for k=1,n do
  local a,b=poly[k],poly[k%n+1]
  local c=(b[1]-a[1])*(z-a[2])-(b[2]-a[2])*(x-a[1])
  if c>1e-9 or c<-1e-9 then
   local s=c>0 and 1 or -1
   if sign==0 then sign=s elseif s~=sign then return false end
  end
 end
 return true
end
-- The cell of layer L under local x,z.
function D.cellAt(cube: any,L: number,x: number,z: number): number?
 local layer=cube.layers[L]
 if not layer then return nil end
 local list=layer.grid[bucketKey(math.floor(x/BUCKET),math.floor(z/BUCKET))]
 if list then for _,id in ipairs(list) do if contains(cube.cells[id].poly,x,z) then return id end end end
 return nil
end
-- Top of the remaining rock at local x,z (0 when dug to the bottom), or nil
-- off the cube. Exact from the cube itself, so drops land on the real floor
-- even before the server finishes carving the geometry.
function D.surfaceAt(cube: any,x: number,z: number): number?
 if x<0 or x>cube.width or z<0 or z>cube.width then return nil end
 for L=1,#cube.layers do
  local id=D.cellAt(cube,L,x,z)
  if id and not cube.removed[id] then return cube.cells[id].y1 end
 end
 return 0
end
function D.key(ids: {number}): string
 local out=table.create(#ids)
 for i,id in ipairs(ids) do out[i]=tostring(id) end
 return table.concat(out,'.')
end
function D.parseKey(s: string): {number}
 local ids={}
 for part in string.gmatch(s,'%d+') do table.insert(ids,tonumber(part) :: number) end
 return ids
end
-- Op grammar v2, one parser for the server, the clients and the tests:
-- c<ids>[~<code>]|<tier>[|<flag>[<arg>]], ids dot-separated, code one
-- uppercase letter (STYLES code). Flags and the cells each op removes:
--  ''           final break: all cells
--  S<k>         terrace stage k: none
--  K            crack-seal, the cells became sealed geodes (tier = gem tier): none
--  E<ids>       final break whose listed cells sealed (K ops follow): the cells minus those
--  C<n>         sequence break n (Gridcutter line cell, Resonator chain link; 1 cell): all
--  G / X        geode opened (X = treasure), sent without a code: all
--  T, D<n>, P<k> legacy, still parsed: all
-- The DigOp drone attribute is c<ids>~<code> with no tier (not an op).
D.OP_PATTERN='^c([%d%.]+)~?(%u?)|(%d+)|?(%u?)([%d%.]*)$'
function D.formatOp(ids: {number},code: string?,tier: number?,flag: string?,arg: (string | number)?): string
 return 'c'..D.key(ids)..(code and code~='' and '~'..code or '')..'|'..tostring(math.floor(tier or 0))
  ..(flag and flag~='' and '|'..flag..tostring(arg or '') or '')
end
local FINAL_FLAGS={['']=true,C=true,G=true,X=true,T=true,D=true,P=true}
function D.parseOp(s: string): any?
 if type(s)~='string' then return nil end
 local key,code,tier,flag,arg=string.match(s,D.OP_PATTERN)
 if not key then return nil end
 local cells=D.parseKey(key)
 if #cells==0 then return nil end
 local op={cells=cells,code=code~='' and code or nil,tier=tonumber(tier) or 0,flag=flag,arg=arg,removes={},
  sealed=flag=='K',staged=flag=='S',geode=flag=='G' or flag=='X',treasure=flag=='T' or flag=='X'}
 if flag=='S' then
  op.stage=tonumber(arg)
 elseif flag=='E' then
  local except={}
  for _,id in ipairs(D.parseKey(arg)) do except[id]=true end
  op.except=except
  for _,id in ipairs(cells) do if not except[id] then table.insert(op.removes,id) end end
 elseif FINAL_FLAGS[flag] then
  op.removes=table.clone(cells)
  if flag=='C' then op.seq=tonumber(arg) end
 elseif flag~='K' then
  return nil
 end
 return op
end
-- Remove an op's cells from a cube (a parsed op or its string); returns the
-- ids actually removed.
function D.applyOp(cube: any,op: any): {number}
 local parsed=if type(op)=='string' then D.parseOp(op) else op
 local removed={}
 if not parsed then return removed end
 local removes: {number}=parsed.removes
 for _,id in ipairs(removes) do
  if cube.cells[id] and D.remove(cube,id) then table.insert(removed,id) end
 end
 return removed
end
-- Outer edges of a chunk (between a member and a non-member or the cube side),
-- ordered by angle around the chunk center so a crack can run around it.
function D.outline(cube: any,ids: {number})
 local member={}
 for _,id in ipairs(ids) do member[id]=true end
 local _,cx,cz=D.chunkArea(cube,ids)
 local edges={}
 for _,id in ipairs(ids) do
  local cell=cube.cells[id];local n=#cell.poly
  for k=1,n do
   if not member[cell.across[k] or 0] then
    local a,b=cell.poly[k],cell.poly[k%n+1]
    local len=math.sqrt((b[1]-a[1])^2+(b[2]-a[2])^2)
    if len>.05 then
     local mx,mz=(a[1]+b[1])*.5,(a[2]+b[2])*.5
     table.insert(edges,{ax=a[1],az=a[2],bx=b[1],bz=b[2],len=len,angle=math.atan2(mz-cz,mx-cx)})
    end
   end
  end
 end
 table.sort(edges,function(p,q) return p.angle<q.angle end)
 return edges,cx,cz
end
-- Keep the part of a convex polygon where (v-c).n <= 0.
function halfPlaneOf(poly: {{number}},cx: number,cz: number,nx: number,nz: number): {{number}}
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
-- Two halves of a chunk along a vertical plane through its center. The angle
-- comes from the chunk itself, so the crack preview and the split agree.
function D.split(cube: any,ids: {number})
 local _,cx,cz=D.chunkArea(cube,ids)
 local h=0
 for _,id in ipairs(ids) do h=(h*31+id)%1000003 end
 local angle=(h*.6180339887)%1*math.pi
 local nx,nz=math.cos(angle),math.sin(angle)
 local first=cube.cells[ids[1]]
 local result={cx=cx,cz=cz,nx=nx,nz=nz,y0=first.y0,y1=first.y1,layer=first.layer,a={},b={},chords={}}
 for _,id in ipairs(ids) do
  local poly=cube.cells[id].poly
  local A=halfPlaneOf(poly,cx,cz,nx,nz);local B=halfPlaneOf(poly,cx,cz,-nx,-nz)
  if #A>=3 then table.insert(result.a,A) end
  if #B>=3 then table.insert(result.b,B) end
  if #A>=3 and #B>=3 then
   local hits={}
   local n=#poly
   for k=1,n do
    local a,b=poly[k],poly[k%n+1]
    local da=(a[1]-cx)*nx+(a[2]-cz)*nz;local db=(b[1]-cx)*nx+(b[2]-cz)*nz
    if (da<0 and db>0) or (da>0 and db<0) then
     local t=da/(da-db);table.insert(hits,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t})
    end
   end
   if #hits==2 then table.insert(result.chords,{ax=hits[1][1],az=hits[1][2],bx=hits[2][1],bz=hits[2][2]}) end
  end
 end
 return result
end
-- Intact stretches of the top face and the outer walls render as one block
-- per tile; a tile breaks into its cells once any cell over it is cut or targeted.
function D.tiles(cube: any)
 local W=cube.width;local T=D.TILE
 local n=math.ceil(W/T)
 local tiles,cellTiles={},{}
 for L,layer in ipairs(cube.layers) do
  for gx=0,n-1 do
   for gz=0,n-1 do
    if L==1 or gx==0 or gz==0 or gx==n-1 or gz==n-1 then
     local key=L*10000+gx*100+gz
     tiles[key]={key=key,layer=L,x0=gx*T,x1=math.min(W,(gx+1)*T),z0=gz*T,z1=math.min(W,(gz+1)*T),y0=layer.y0,y1=layer.y1,cells={}}
    end
   end
  end
  for _,id in ipairs(layer.cells) do
   local c=cube.cells[id];local list={}
   for gx=math.max(0,math.floor(c.minX/T)),math.min(n-1,math.floor((c.maxX-1e-6)/T)) do
    for gz=math.max(0,math.floor(c.minZ/T)),math.min(n-1,math.floor((c.maxZ-1e-6)/T)) do
     local tile=tiles[L*10000+gx*100+gz]
     if tile then table.insert(tile.cells,id);table.insert(list,tile.key) end
    end
   end
   cellTiles[id]=list
  end
 end
 return tiles,cellTiles
end

-- Removed set as a compact string: 6 cells per character.
function D.encode(cube: any): string
 local out=table.create(math.ceil(#cube.cells/6))
 for i=1,#cube.cells,6 do
  local v=0
  for b=0,5 do if cube.removed[i+b] then v+=2^b end end
  table.insert(out,string.sub(ALPHA,v+1,v+1))
 end
 return table.concat(out)
end
function D.decode(cube: any,s: string): {[number]:boolean}
 local set={}
 for c=1,#s do
  local v=(string.find(ALPHA,string.sub(s,c,c),1,true) or 1)-1
  for b=0,5 do
   if v%2==1 then local id=(c-1)*6+b+1;if cube.cells[id] then set[id]=true end end
   v=math.floor(v/2)
  end
 end
 return set
end

-- A convex polygon pushed out by d along every edge normal (mitred corners,
-- capped for sharp ones). Carving with these overlaps every neighbor, so no
-- sliver survives at a seam or at a corner where three cells meet: those
-- slivers stood as thin spires once the rock under them was dug away.
D.CARVE_OVERLAP=.3
function D.grown(poly: {{number}},d: number): {{number}}
 local n=#poly
 local signed=0
 for k=1,n do local a,b=poly[k],poly[k%n+1];signed+=a[1]*b[2]-b[1]*a[2] end
 local flip=signed>=0 and 1 or -1
 local normals={}
 for k=1,n do
  local a,b=poly[k],poly[k%n+1]
  local ex,ez=b[1]-a[1],b[2]-a[2]
  local len=math.sqrt(ex*ex+ez*ez)
  -- Zero-length edges get a zero normal and borrow the neighbor's below.
  if len<1e-9 then normals[k]={0,0} else normals[k]={ez/len*flip,-ex/len*flip} end
 end
 local out={}
 for k=1,n do
  local prev=normals[(k-2)%n+1];local nxt=normals[k]
  local v=poly[k]
  if prev[1]==0 and prev[2]==0 then prev=nxt end
  if nxt[1]==0 and nxt[2]==0 then nxt=prev end
  if nxt[1]==0 and nxt[2]==0 then table.insert(out,{v[1],v[2]})
  else
   local mx,mz=prev[1]+nxt[1],prev[2]+nxt[2]
   local denom=1+prev[1]*nxt[1]+prev[2]*nxt[2]
   local f=denom>.15 and d/denom or d/.15
   table.insert(out,{v[1]+mx*f,v[2]+mz*f})
  end
 end
 return out
end
-- Geometry for rendering. Polygon shrunk toward its centroid to open a crack line.
function D.shrunk(cell: any,gap: number?)
 local g=gap or D.GAP;local out={}
 for _,v in ipairs(cell.poly) do
  local dx,dz=v[1]-cell.cx,v[2]-cell.cz
  local len=math.sqrt(dx*dx+dz*dz)
  local f=(g<0 or len>g*2) and (len-g)/len or .5
  table.insert(out,{cell.cx+dx*f,cell.cz+dz*f})
 end
 return out
end
local function sub(a: {number},b: {number}) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function dot(a: {number},b: {number}) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function cross(a: {number},b: {number}) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function unit(a: {number}) local l=math.sqrt(dot(a,a));if l<1e-9 then return {0,0,0} end return {a[1]/l,a[2]/l,a[3]/l} end
local function neg(a: {number}) return {-a[1],-a[2],-a[3]} end
-- A horizontal triangle extruded to `thick`, as two right-triangle wedges.
-- Each wedge: {pos, right, up, back, size} with size={X thickness, Y, Z}.
local function triangle(a: {number},b: {number},c: {number},thick: number,out: {any})
 local ab,ac,bc=sub(b,a),sub(c,a),sub(c,b)
 local abd,acd,bcd=dot(ab,ab),dot(ac,ac),dot(bc,bc)
 if abd>acd and abd>bcd then c,a=a,c elseif acd>bcd and acd>abd then a,b=b,a end
 ab,ac,bc=sub(b,a),sub(c,a),sub(c,b)
 local right=unit(cross(ac,ab));local up=unit(cross(bc,right));local back=unit(bc)
 local height=math.abs(dot(ab,up))
 if height<.03 then return end
 local d1,d2=math.abs(dot(ab,back)),math.abs(dot(ac,back))
 if d1>.03 then table.insert(out,{pos={(a[1]+b[1])*.5,(a[2]+b[2])*.5,(a[3]+b[3])*.5},right=right,up=up,back=back,size={thick,height,d1}}) end
 if d2>.03 then table.insert(out,{pos={(a[1]+c[1])*.5,(a[2]+c[2])*.5,(a[3]+c[3])*.5},right=neg(right),up=up,back=neg(back),size={thick,height,d2}}) end
end
-- Wedges for one cell in cube-local coordinates (x,z in [0,W], y up from the bottom).
function D.wedges(cell: any)
 return D.polyWedges(D.shrunk(cell),cell.y0,cell.y1)
end
function D.polyWedges(poly: {{number}},y0: number,y1: number)
 local mid=(y0+y1)*.5;local thick=y1-y0
 local out={}
 local p1={poly[1][1],mid,poly[1][2]}
 for k=2,#poly-1 do
  triangle(p1,{poly[k][1],mid,poly[k][2]},{poly[k+1][1],mid,poly[k+1][2]},thick,out)
 end
 return out
end
-- Flat outer-face panels for a hidden boundary cell (one per boundary edge).
function D.panels(cell: any)
 local out={}
 local n=#cell.poly
 for k=1,n do
  if cell.labels[k]<0 then
   local a,b=cell.poly[k],cell.poly[k%n+1]
   local dx,dz=b[1]-a[1],b[2]-a[2]
   local len=math.sqrt(dx*dx+dz*dz)
   if len>.2 then
    table.insert(out,{mx=(a[1]+b[1])*.5,mz=(a[2]+b[2])*.5,dx=dx/len,dz=dz/len,length=math.max(.05,len-D.GAP*2),side=cell.labels[k]})
   end
  end
 end
 return out
end
-- Outward normal of a boundary side label.
function D.sideNormal(side: number): (number,number)
 if side==-1 then return 0,-1 elseif side==-2 then return 1,0 elseif side==-3 then return 0,1 end
 return -1,0
end
return D
