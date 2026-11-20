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
-- further. Ore is hidden inside: every chunk rolls for a gem when it splits.
--
-- The rendered rock is real solid geometry carved on the server: each chunk's
-- cell prisms (D.prismWedges) are subtracted from solid blocks.
--
-- Digging (server): a cell can be cut only when the cells above its core are
-- gone, so pits open as stepped craters instead of drill shafts. Drones pick
-- seeds at random, weighted toward depth, toward the player, away from each
-- other and toward recent cuts: organic pits that deepen and merge.
local D={}
D.WIDTH=88
D.LAYERS=10
D.GAP=0 -- seamless: no crack lines until a drone cuts
D.CORE=.7 -- share of a cell (about its centroid) that must be open above before it can be cut
D.DEPTH_PULL=2.4 -- per-layer preference for going deeper
D.FOCUS_FALLOFF=15 -- studs; drones favor cells near the player or a tapped spot
D.RUN=3.6 -- studs the crater widens per layer (about 45 degree walls)
D.LEAD=2 -- the crater aims this many layers below its current floor
D.APEX_RADIUS=9 -- studs around the focus that set the current floor
D.CROWD_RADIUS=7
D.RECENT_TIME=20
D.CENTER={140,4,20} -- bottom center in world space (on the flat plane east of the hub)
D.HP_SCALE=.2
D.HARDNESS_PER_LAYER=.4 -- the bottom layer takes about 4.6x the work of the top
D.MINE_RADIUS=16 -- studs: drones only cut chunks this close to their player, so you move to keep digging
D.BASE_CUT_AREA=48 -- square studs of top face in a chunk at cutSize 1 (about 8 studs across)
D.MAX_CHUNK=40
D.PAUSE=1.1 -- seconds between the split and the gem-or-nothing reveal
D.TILE=11 -- intact stretches render as one block per tile
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

-- Rock color: every layer has its own bright hue (no darkening with depth, so
-- deep pits stay readable), and each layer shifts across its face toward a
-- second tone, so a single layer reads as a gradient rather than a flat slab.
D.LAYER_HUES={
 {238,208,142},{242,170,92},{228,122,86},{216,106,130},{180,110,192},
 {122,126,216},{88,162,216},{80,184,168},{126,198,114},{204,208,98},
}
D.LAYER_SHIFT=.5 -- how far a layer's second tone leans toward the next hue
local function mix(a: {number},b: {number},t: number): {number}
 return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
end
-- Color of layer L at cube-local x,z.
function D.layerColor(cube: any,L: number,x: number,z: number): {number}
 local n=#D.LAYER_HUES
 local a=D.LAYER_HUES[(L-1)%n+1]
 local b=mix(a,D.LAYER_HUES[L%n+1],D.LAYER_SHIFT)
 b=mix(b,{255,250,236},.18)
 local t=D.noise3(x/22,L*5.7,z/22,(cube and cube.seed or 1)%100000)
 t=math.clamp((t-.2)/.6,0,1)
 return mix(a,b,t)
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
function D.diggable(cube: any,id: number): boolean
 if cube.removed[id] then return false end
 for _,other in ipairs(D.shoulders(cube,id)) do if not cube.removed[other] then return false end end
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

-- Weighted random choice among cuttable cells. opts:
--  focusX/focusZ: local point the crew should favor (player or tapped spot)
--  taken: {[cellId]=true} claimed by other drones; takenPoints: {{x,z}} of those claims
--  recent: {[cellId]=time} of removals; now; random: () -> number
--  anchorX/anchorZ: the player's local position; only cells within radius
--  (default D.MINE_RADIUS) of it are cut, so the player has to move along
function D.pick(cube: any,opts: any): number?
 local total=0
 local choices,weights={},{}
 local random=opts.random or math.random
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
  apex=math.min(D.LAYERS,apex+D.LEAD)
 end
 for id in pairs(cube.frontier) do
  local cell=cube.cells[id]
  local near=not opts.anchorX or math.sqrt((cell.cx-opts.anchorX)^2+(cell.cz-opts.anchorZ)^2)-cell.radius<=(opts.radius or D.MINE_RADIUS)
  if near and not (opts.taken and opts.taken[id]) and D.diggable(cube,id) then
   local w=D.DEPTH_PULL^(cell.layer-1)
   if opts.focusX then
    local d=math.sqrt((cell.cx-opts.focusX)^2+(cell.cz-opts.focusZ)^2)
    local wanted=apex-math.max(0,d-cell.radius)/D.RUN
    if cell.layer>wanted+.5 then w*=.004 end
    w*=.05+math.exp(-d/D.FOCUS_FALLOFF)
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
   w*=.4+random()
   total+=w;table.insert(choices,id);table.insert(weights,w)
  end
 end
 if total<=0 then return nil end
 local roll=random()*total
 for i,id in ipairs(choices) do roll-=weights[i];if roll<=0 then return id end end
 return choices[#choices]
end

-- A chunk: the seed plus the closest cuttable same-layer neighbors until the
-- top face reaches the drone's cut area. cutSize scales the chunk's width.
function D.chunk(cube: any,seed: number,cutSize: number?,taken: {[number]:any}?,random: (() -> number)?): {number}
 local cut=math.max(.5,cutSize or 1)
 local roll=random and random() or .5
 local target=D.BASE_CUT_AREA*cut*cut*(.75+.5*roll)
 local s=cube.cells[seed]
 local ids={seed};local inside={[seed]=true};local area=s.area
 local open={}
 local function offer(id: number)
  for _,n in ipairs(cube.cells[id].neighbors) do
   if not inside[n] and not open[n] and not cube.removed[n] and not (taken and taken[n]) and D.diggable(cube,n) then open[n]=true end
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
  local c=cube.cells[best]
  -- Stop when adding this cell overshoots the target by more than it helps.
  if area+c.area*.5>target then break end
  open[best]=nil;inside[best]=true;table.insert(ids,best);area+=c.area
  offer(best)
 end
 table.sort(ids)
 return ids
end
function D.chunkHp(cube: any,ids: {number},cutSize: number?): number
 local hp=0
 for _,id in ipairs(ids) do hp+=cube.cells[id].hp end
 -- Bigger cuts take longer but move more rock per second than small ones.
 return hp/math.sqrt(math.max(.5,cutSize or 1))
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
local function halfPlane(poly: {{number}},cx: number,cz: number,nx: number,nz: number): {{number}}
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
  local A=halfPlane(poly,cx,cz,nx,nz);local B=halfPlane(poly,cx,cz,-nx,-nz)
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
