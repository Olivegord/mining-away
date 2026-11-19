--!strict
-- Dig Cube: one huge block made of stacked layers of Voronoi cells.
-- Every layer has its own cell pattern and cell size, so cracks never line up
-- vertically (brick-bond strata) and cuts range from big slabs to small chips.
-- Pure and deterministic from a seed: the server and every client build the
-- same cube, and only the set of removed cells is replicated.
--
-- Digging (server): a cell can be cut only when the cells above it within a
-- slope radius are gone, so pits open as stepped craters instead of drill
-- shafts. Drones pick among those cells at random, weighted toward depth,
-- toward the player, away from each other and toward recent cuts. That mix
-- gives several organic pits that deepen and merge, never layer-by-layer.
local D={}
D.WIDTH=88
D.LAYERS=10
D.GAP=.14 -- visible crack between cells
D.CORE=.55 -- share of a cell (about its centroid) that must be open above before it can be cut
D.DEPTH_PULL=2.4 -- per-layer preference for going deeper
D.FOCUS_FALLOFF=15 -- studs; drones favor cells near the player or a tapped spot
D.RUN=3.6 -- studs the crater widens per layer (about 45 degree walls)
D.LEAD=2 -- the crater aims this many layers below its current floor
D.APEX_RADIUS=9 -- studs around the focus that set the current floor
D.CROWD_RADIUS=7
D.RECENT_TIME=20
D.CENTER={140,4,20} -- bottom center in world space (on the flat plane east of the hub)
D.HP_SCALE=.14
D.ORE_HP=2.2
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
  local size=L==1 and R(7.2,9) or R(4.8,9.6)
  local swing=R(.18,.42)
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
     minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ,y0=y0,y1=y1,neighbors={},boundary=false,ore=0,hp=0,shade=R(-.05,.05),sink=R(0,.22)}
    table.insert(cube.cells,cell);cell.id=#cube.cells
    table.insert(layer.cells,cell.id)
   end
  end
  -- Map seed index -> cell id for same-layer neighbors.
  local bySeed={}
  for _,id in ipairs(layer.cells) do bySeed[cube.cells[id].seedIndex]=id end
  for _,id in ipairs(layer.cells) do
   local cell=cube.cells[id]
   for _,lab in ipairs(cell.labels) do
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
   local hardness=1+.15*(L-1)
   cell.hp=math.max(12,cell.area*(y1-y0)*D.HP_SCALE*hardness*(cell.ore>0 and D.ORE_HP or 1))
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
  if not (opts.taken and opts.taken[id]) and D.diggable(cube,id) then
   local cell=cube.cells[id]
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
   if cell.ore>0 then w*=1.3 end
   w*=.4+random()
   total+=w;table.insert(choices,id);table.insert(weights,w)
  end
 end
 if total<=0 then return nil end
 local roll=random()*total
 for i,id in ipairs(choices) do roll-=weights[i];if roll<=0 then return id end end
 return choices[#choices]
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

-- Geometry for rendering. Polygon shrunk toward its centroid to open a crack line.
function D.shrunk(cell: any,gap: number?)
 local g=gap or D.GAP;local out={}
 for _,v in ipairs(cell.poly) do
  local dx,dz=v[1]-cell.cx,v[2]-cell.cz
  local len=math.sqrt(dx*dx+dz*dz)
  local f=len>g*2 and (len-g)/len or .5
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
 local poly=D.shrunk(cell)
 local y1=cell.y1-(cell.layer==1 and cell.sink or cell.sink*.3)
 local y0=cell.y0
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
