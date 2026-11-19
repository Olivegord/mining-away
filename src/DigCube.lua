--!strict
-- Dig Cube: one huge block cut into 3D Voronoi cells (convex polyhedra from
-- variable-radius Poisson sites), so cuts have real 3D shapes: slanted faces,
-- wedges and overhang-free stepped pits. Pure and deterministic from a seed:
-- the server and every client build the same cube; only removed cells replicate.
--
-- One cell per cut. Cut-size upgrades (stats.cutSize > 1) blast neighboring
-- cells out with it. Ore is hidden inside: every break rolls for a gem.
--
-- Digging (server): a cell can be cut only when it touches air and every cell
-- resting on it (across a face that points up) is gone, so nothing ever
-- floats and pits open as stepped craters. Drones pick at random, weighted
-- toward a cone-shaped crater around the player (or a tapped spot), deeper
-- first, away from each other and toward recent cuts.
local D={}
D.WIDTH=88
D.HEIGHT=44
D.CELL=7.6 -- typical distance between neighboring cell sites (studs)
D.SWING=.28 -- regional cell size swing: big boulders next to smaller blocks
D.CENTER={140,4,20} -- bottom center in world space (on the flat plane east of the hub)
D.HP_SCALE=.07 -- per cubic stud
D.DEPTH_HARD=.03 -- extra hardness per stud of depth
D.UP=.5 -- a face whose normal points up more than this holds a cell resting on this one
D.MAX_BLAST=12
D.RELAX=0 -- Lloyd relaxation steps (measured: barely changes slivers, doubles build time)
D.TINT=.09 -- per-rock tone swing on pit faces so neighboring rocks read apart
D.PAUSE=1.1 -- seconds between the split and the gem-or-nothing reveal
D.TILE=11 -- intact outer surface renders as one slab per tile
D.BAND=44/12 -- outer wall tile height
D.GEM_CHANCE_ORE=.55
D.GEM_CHANCE_STONE=.05
D.DEPTH_PULL=1.16 -- per stud of depth
D.FOCUS_FALLOFF=12
D.SLOPE=1.4 -- crater walls about 55 degrees
D.LEAD=8 -- studs the crater aims below its current floor
D.APEX_RADIUS=10
D.CROWD_RADIUS=8
D.RECENT_TIME=20
-- Ore tiers follow the existing crystal tiers (Workshop.CRYSTAL_TIERS).
D.ORES={
 {material='Amber',name='Amber',color={255,153,20}},
 {material='RunRuby',name='Ruby',color={226,62,78}},
 {material='RunQuartz',name='Quartz',color={97,177,224}},
 {material='RunViolet',name='Violet',color={152,98,222}},
 {material='Diamond',name='Diamond',color={236,226,246}},
}
-- Rock color by height: warm sand at the top to dark slate at the bottom.
D.GRADIENT={{242,222,180},{234,198,140},{218,162,104},{190,126,86},{152,100,84},{114,86,92},{80,76,98},{54,56,74}}
local ALPHA='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
-- Boundary labels: -1 bottom, -2 top, -3 west (x=0), -4 east (x=W), -5 south (z=0), -6 north (z=W). 0 = a split cut.
local BOTTOM,TOP=-1,-2

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
 local c000,c100=hash(ix,iy,iz,seed),hash(ix+1,iy,iz,seed)
 local c010,c110=hash(ix,iy+1,iz,seed),hash(ix+1,iy+1,iz,seed)
 local c001,c101=hash(ix,iy,iz+1,seed),hash(ix+1,iy,iz+1,seed)
 local c011,c111=hash(ix,iy+1,iz+1,seed),hash(ix+1,iy+1,iz+1,seed)
 return l(l(l(c000,c100,fx),l(c010,c110,fx),fy),l(l(c001,c101,fx),l(c011,c111,fx),fy),fz)
end
function D.gradient(y: number,height: number): {number}
 local t=math.clamp(1-y/height,0,1)*(#D.GRADIENT-1)
 local i=math.floor(t);local f=t-i
 local a=D.GRADIENT[i+1];local b=D.GRADIENT[math.min(#D.GRADIENT,i+2)]
 return {a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f,a[3]+(b[3]-a[3])*f}
end

local function key3(ix: number,iy: number,iz: number) return (ix*1031+iy)*1031+iz end

-- Variable-radius Poisson disk sampling in a box (Bridson, 3D).
local function poisson(R: any,W: number,H: number,radius: (number,number,number)->number,rmax: number)
 local bucket=rmax
 local grid={} :: {[number]:{number}}
 local pts={} :: {{x:number,y:number,z:number,r:number}}
 local active={} :: {number}
 local function free(x: number,y: number,z: number,r: number): boolean
  if x<0 or x>W or z<0 or z>W or y<0 or y>H then return false end
  local ix,iy,iz=math.floor(x/bucket),math.floor(y/bucket),math.floor(z/bucket)
  for gx=ix-1,ix+1 do for gy=iy-1,iy+1 do for gz=iz-1,iz+1 do
   local list=grid[key3(gx,gy,gz)]
   if list then
    for _,i in ipairs(list) do
     local p=pts[i];local need=(r+p.r)*.5
     if (p.x-x)^2+(p.y-y)^2+(p.z-z)^2<need*need then return false end
    end
   end
  end end end
  return true
 end
 local function add(x: number,y: number,z: number,r: number)
  table.insert(pts,{x=x,y=y,z=z,r=r})
  local k=key3(math.floor(x/bucket),math.floor(y/bucket),math.floor(z/bucket))
  local list=grid[k];if not list then list={};grid[k]=list end
  table.insert(list,#pts);table.insert(active,#pts)
 end
 local x0,y0,z0=R(0,W),R(0,H),R(0,W)
 add(x0,y0,z0,radius(x0,y0,z0))
 while #active>0 do
  local slot=math.floor(R()*#active)+1
  local p=pts[active[slot]]
  local found=false
  for _=1,20 do
   local u=R(-1,1);local a=R(0,math.pi*2);local s=math.sqrt(1-u*u)
   local dist=R(p.r,p.r*1.8)
   local x,y,z=p.x+s*math.cos(a)*dist,p.y+u*dist,p.z+s*math.sin(a)*dist
   local r=radius(math.clamp(x,0,W),math.clamp(y,0,H),math.clamp(z,0,W))
   if free(x,y,z,r) then add(x,y,z,r);found=true;break end
  end
  if not found then active[slot]=active[#active];active[#active]=nil end
 end
 return pts,grid,bucket
end

local function sub(a: {number},b: {number}) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function dot(a: {number},b: {number}) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function cross(a: {number},b: {number}) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function unit(a: {number}) local l=math.sqrt(dot(a,a));if l<1e-12 then return {0,0,0} end return {a[1]/l,a[2]/l,a[3]/l} end

-- Cut a convex polyhedron (list of faces) by a plane, keeping (v-m).n <= 0.
-- The new cap face gets `label` and outward normal n.
local function clipHull(faces: {any},m: {number},n: {number},label: number)
 local out={};local cap={}
 for _,f in ipairs(faces) do
  local vs=f.verts;local k=#vs;local nv={}
  for i=1,k do
   local a=vs[i];local b=vs[i%k+1]
   local da=(a[1]-m[1])*n[1]+(a[2]-m[2])*n[2]+(a[3]-m[3])*n[3]
   local db=(b[1]-m[1])*n[1]+(b[2]-m[2])*n[2]+(b[3]-m[3])*n[3]
   if da<=1e-9 then table.insert(nv,a);if da>=-1e-9 then table.insert(cap,a) end end
   if (da<-1e-9 and db>1e-9) or (da>1e-9 and db<-1e-9) then
    local t=da/(da-db)
    local p={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
    table.insert(nv,p);table.insert(cap,p)
   end
  end
  -- Drop near-duplicate vertices.
  local i=1
  while i<=#nv and #nv>=3 do
   local a=nv[i];local b=nv[i%#nv+1]
   if (a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2<1e-10 then table.remove(nv,i) else i+=1 end
  end
  if #nv>=3 then table.insert(out,{verts=nv,label=f.label}) end
 end
 -- Unique cap points, ordered around their center in the plane.
 local uniq={}
 for _,p in ipairs(cap) do
  local dup=false
  for _,q in ipairs(uniq) do if (p[1]-q[1])^2+(p[2]-q[2])^2+(p[3]-q[3])^2<1e-8 then dup=true;break end end
  if not dup then table.insert(uniq,p) end
 end
 if #uniq>=3 then
  local c={0,0,0}
  for _,p in ipairs(uniq) do c[1]+=p[1];c[2]+=p[2];c[3]+=p[3] end
  c={c[1]/#uniq,c[2]/#uniq,c[3]/#uniq}
  local nn=unit(n)
  local u=unit(sub(uniq[1],c));local v=cross(nn,u)
  table.sort(uniq,function(p,q)
   local dp,dq=sub(p,c),sub(q,c)
   return math.atan2(dot(dp,v),dot(dp,u))<math.atan2(dot(dq,v),dot(dq,u))
  end)
  table.insert(out,{verts=uniq,label=label})
 end
 return out
end

-- Normals, areas, centers and volume of a hull.
local function measure(faces: {any})
 local ref={0,0,0};local count=0
 for _,f in ipairs(faces) do for _,v in ipairs(f.verts) do ref[1]+=v[1];ref[2]+=v[2];ref[3]+=v[3];count+=1 end end
 ref={ref[1]/count,ref[2]/count,ref[3]/count}
 local volume=0;local cen={0,0,0}
 local minY,maxY=math.huge,-math.huge
 for _,f in ipairs(faces) do
  local vs=f.verts
  local nx,ny,nz=0,0,0
  local fc={0,0,0}
  for i=1,#vs do
   local a=vs[i];local b=vs[i%#vs+1]
   nx+=(a[2]-b[2])*(a[3]+b[3]);ny+=(a[3]-b[3])*(a[1]+b[1]);nz+=(a[1]-b[1])*(a[2]+b[2])
   fc[1]+=a[1];fc[2]+=a[2];fc[3]+=a[3]
   minY=math.min(minY,a[2]);maxY=math.max(maxY,a[2])
  end
  fc={fc[1]/#vs,fc[2]/#vs,fc[3]/#vs}
  local len=math.sqrt(nx*nx+ny*ny+nz*nz)
  local nrm=len>1e-12 and {nx/len,ny/len,nz/len} or {0,1,0}
  if dot(nrm,sub(fc,ref))<0 then nrm={-nrm[1],-nrm[2],-nrm[3]} end
  f.normal=nrm;f.area=len*.5;f.center=fc
  for i=2,#vs-1 do
   local a,b,c=vs[1],vs[i],vs[i+1]
   local tv=math.abs(dot(sub(a,ref),cross(sub(b,ref),sub(c,ref))))/6
   volume+=tv
   cen[1]+=tv*(ref[1]+a[1]+b[1]+c[1])*.25;cen[2]+=tv*(ref[2]+a[2]+b[2]+c[2])*.25;cen[3]+=tv*(ref[3]+a[3]+b[3]+c[3])*.25
  end
 end
 if volume>1e-9 then cen={cen[1]/volume,cen[2]/volume,cen[3]/volume} else cen=ref end
 return volume,cen,minY,maxY
end

local function boxFaces(W: number,H: number)
 return {
  {verts={{0,0,0},{W,0,0},{W,0,W},{0,0,W}},label=-1},
  {verts={{0,H,0},{0,H,W},{W,H,W},{W,H,0}},label=-2},
  {verts={{0,0,0},{0,0,W},{0,H,W},{0,H,0}},label=-3},
  {verts={{W,0,0},{W,H,0},{W,H,W},{W,0,W}},label=-4},
  {verts={{0,0,0},{0,H,0},{W,H,0},{W,0,0}},label=-5},
  {verts={{0,0,W},{W,0,W},{W,H,W},{0,H,W}},label=-6},
 }
end

function D.build(seed: number)
 local W,H=D.WIDTH,D.HEIGHT
 local R=D.rng(seed)
 local sizeSeed=math.floor(R(1,1000000))
 local oreSeed=math.floor(R(1,1000000))
 local rmax=D.CELL*(1+D.SWING)
 local function radius(x: number,y: number,z: number)
  local n=D.noise3(x/26,y/26,z/26,sizeSeed)
  return D.CELL*(1+D.SWING*(n*2-1))
 end
 local pts,grid,bucket=poisson(R,W,H,radius,rmax)
 local cube={seed=seed,width=W,height=H,cells={},removedCount=0}
 local function cells()
 cube.cells={}
 for i,p in ipairs(pts) do
  local near={}
  local ix,iy,iz=math.floor(p.x/bucket),math.floor(p.y/bucket),math.floor(p.z/bucket)
  for gx=ix-2,ix+2 do for gy=iy-2,iy+2 do for gz=iz-2,iz+2 do
   local list=grid[key3(gx,gy,gz)]
   if list then for _,j in ipairs(list) do if j~=i then
    local q=pts[j];table.insert(near,{j=j,d=(q.x-p.x)^2+(q.y-p.y)^2+(q.z-p.z)^2})
   end end end
  end end end
  table.sort(near,function(a,b) return a.d<b.d end)
  local faces=boxFaces(W,H)
  local site={p.x,p.y,p.z}
  for _,q in ipairs(near) do
   local far=0
   for _,f in ipairs(faces) do for _,v in ipairs(f.verts) do far=math.max(far,(v[1]-p.x)^2+(v[2]-p.y)^2+(v[3]-p.z)^2) end end
   if q.d*.25>far then break end
   local o=pts[q.j]
   faces=clipHull(faces,{(p.x+o.x)*.5,(p.y+o.y)*.5,(p.z+o.z)*.5},{o.x-p.x,o.y-p.y,o.z-p.z},q.j)
   if #faces<4 then break end
  end
  local volume,cen,minY,maxY=measure(faces)
  local kept={}
  for _,f in ipairs(faces) do if f.area>1e-3 then table.insert(kept,f) end end
  local r=0
  for _,f in ipairs(kept) do for _,v in ipairs(f.verts) do r=math.max(r,math.sqrt((v[1]-cen[1])^2+(v[3]-cen[3])^2)) end end
  cube.cells[i]={id=i,site=site,faces=kept,volume=volume,cx=cen[1],cy=cen[2],cz=cen[3],minY=minY,maxY=maxY,radius=r,
   neighbors={},up={},ore=0,hp=0}
 end
 end
 cells()
 -- One Lloyd step: move each site to its cell's center and rebuild. Cells
 -- come out rounder and more even, with far fewer thin sliver faces.
 for _=1,D.RELAX do
  grid={}
  for i,c in ipairs(cube.cells) do
   local p=pts[i];p.x,p.y,p.z=c.cx,c.cy,c.cz
   local k=key3(math.floor(p.x/bucket),math.floor(p.y/bucket),math.floor(p.z/bucket))
   local list=grid[k];if not list then list={};grid[k]=list end
   table.insert(list,i)
  end
  cells()
 end
 -- Neighbors across shared faces (kept only when both sides agree).
 local has={}
 for _,cell in ipairs(cube.cells) do
  local set={}
  for _,f in ipairs(cell.faces) do if f.label>0 then set[f.label]=true end end
  has[cell.id]=set
 end
 for _,cell in ipairs(cube.cells) do
  for _,f in ipairs(cell.faces) do
   if f.label>0 then
    if has[f.label][cell.id] then
     if not table.find(cell.neighbors,f.label) then table.insert(cell.neighbors,f.label) end
     if f.normal[2]>D.UP then table.insert(cell.up,f.label) end
    else f.label=0 end
   end
  end
  local depth=H-cell.cy
  local t=depth/H
  local n=D.noise3(cell.cx/13,cell.cy/9,cell.cz/13,oreSeed)
  if n>.74-.1*t then cell.ore=math.clamp(math.floor(1+t*4.2+R(-.7,.7)),1,#D.ORES) end
  cell.hp=math.max(4,cell.volume*D.HP_SCALE*(1+depth*D.DEPTH_HARD))
 end
 cube.removed={} :: {[number]:boolean}
 cube.frontier={} :: {[number]:boolean}
 for _,cell in ipairs(cube.cells) do
  for _,f in ipairs(cell.faces) do if f.label<-1 then cube.frontier[cell.id]=true;break end end
 end
 return cube
end

-- A face is open to air: a cut neighbor, or the cube's top or sides.
function D.faceOpen(cube: any,face: any): boolean
 local l=face.label
 if l>0 then return cube.removed[l]==true end
 return l<-1
end
function D.diggable(cube: any,id: number): boolean
 if cube.removed[id] then return false end
 local cell=cube.cells[id]
 for _,other in ipairs(cell.up) do if not cube.removed[other] then return false end end
 for _,f in ipairs(cell.faces) do if D.faceOpen(cube,f) then return true end end
 return false
end
function D.remove(cube: any,id: number)
 if cube.removed[id] then return false end
 cube.removed[id]=true;cube.removedCount+=1;cube.frontier[id]=nil
 for _,other in ipairs(cube.cells[id].neighbors) do if not cube.removed[other] then cube.frontier[other]=true end end
 return true
end
-- Where a beam meets the cell: the center of its most upward open face.
function D.contact(cube: any,id: number): ({number},{number})
 local cell=cube.cells[id]
 local best,score=nil,-math.huge
 for _,f in ipairs(cell.faces) do
  if D.faceOpen(cube,f) and f.normal[2]>score then best,score=f,f.normal[2] end
 end
 if not best then return {cell.cx,cell.maxY,cell.cz},{0,1,0} end
 return best.center,best.normal
end

-- Weighted random choice among cuttable cells. opts:
--  focusX/focusZ: local point the crew should favor (player or tapped spot)
--  taken: {[cellId]=true} claimed by other drones; takenPoints: {{x,z}} of those claims
--  recent: {[cellId]=time} of removals; now; random: () -> number
function D.pick(cube: any,opts: any): number?
 local H=cube.height
 local random=opts.random or math.random
 local open={}
 for id in pairs(cube.frontier) do
  if not (opts.taken and opts.taken[id]) and D.diggable(cube,id) then table.insert(open,id) end
 end
 table.sort(open)
 -- The crew carves a cone around the focus whose tip sits D.LEAD studs
 -- below the deepest cuttable cell there; the rim widens only as far as
 -- going deeper needs. Moving the focus starts a new crater.
 local apex=0
 if opts.focusX then
  for _,id in ipairs(open) do
   local c=cube.cells[id]
   if (c.cx-opts.focusX)^2+(c.cz-opts.focusZ)^2<=D.APEX_RADIUS*D.APEX_RADIUS then apex=math.max(apex,H-c.cy) end
  end
  apex+=D.LEAD
 end
 local total=0
 local weights={}
 for i,id in ipairs(open) do
  local cell=cube.cells[id]
  local depth=H-cell.cy
  local w=D.DEPTH_PULL^depth
  if opts.focusX then
   local d=math.sqrt((cell.cx-opts.focusX)^2+(cell.cz-opts.focusZ)^2)
   local wanted=apex-math.max(0,d-cell.radius)*D.SLOPE
   if depth>wanted+1 then w*=.004 end
   w*=.05+math.exp(-d/D.FOCUS_FALLOFF)
  end
  if opts.takenPoints then
   for _,p in ipairs(opts.takenPoints) do
    if (p[1]-cell.cx)^2+(p[2]-cell.cz)^2<D.CROWD_RADIUS*D.CROWD_RADIUS then w*=.2 end
   end
  end
  if opts.recent and opts.now then
   for _,other in ipairs(cell.neighbors) do
    local t=opts.recent[other];if t and opts.now-t<D.RECENT_TIME then w*=2;break end
   end
  end
  w*=.4+random()
  weights[i]=w;total+=w
 end
 if total<=0 then return nil end
 local roll=random()*total
 for i,id in ipairs(open) do roll-=weights[i];if roll<=0 then return id end end
 return open[#open]
end

-- The cut: one cell, plus neighbors blasted out with it when cutSize > 1
-- (about cutSize^3 times the cell's volume). Never leaves a cell floating.
function D.chunk(cube: any,seed: number,cutSize: number?,taken: {[number]:any}?,random: (() -> number)?): {number}
 local cut=cutSize or 1
 if cut<=1.02 then return {seed} end
 local roll=random and random() or .5
 local s=cube.cells[seed]
 local target=s.volume*cut^3*(.8+.4*roll)
 local ids={seed};local inside={[seed]=true};local volume=s.volume
 -- A neighbor joins with every cell still resting on it (the blast takes the
 -- rock above too), so nothing is left floating.
 local function closure(n: number): {number}?
  local out={n};local seen={[n]=true};local i=1
  while i<=#out do
   for _,u in ipairs(cube.cells[out[i]].up) do
    if not cube.removed[u] and not inside[u] and not seen[u] then
     if taken and taken[u] then return nil end
     seen[u]=true;table.insert(out,u)
     if #out>4 then return nil end
    end
   end
   i+=1
  end
  return out
 end
 while #ids<D.MAX_BLAST do
  local best,bestD,bestSet=nil,math.huge,nil
  for _,id in ipairs(ids) do
   for _,n in ipairs(cube.cells[id].neighbors) do
    if not inside[n] and not cube.removed[n] and not (taken and taken[n]) then
     local c=cube.cells[n];local d=(c.cx-s.cx)^2+(c.cy-s.cy)^2+(c.cz-s.cz)^2
     if d<bestD then
      local set=closure(n)
      if set then best,bestD,bestSet=n,d,set end
     end
    end
   end
  end
  if not best or not bestSet then break end
  local add=0
  for _,m in ipairs(bestSet) do add+=cube.cells[m].volume end
  if volume+add*.5>target or #ids+#bestSet>D.MAX_BLAST then break end
  for _,m in ipairs(bestSet) do inside[m]=true;table.insert(ids,m) end
  volume+=add
 end
 return ids
end
function D.chunkHp(cube: any,ids: {number},cutSize: number?): number
 local hp=0
 for _,id in ipairs(ids) do hp+=cube.cells[id].hp end
 -- Bigger blasts take longer but move more rock per second.
 return hp/math.sqrt(math.max(1,cutSize or 1))
end
-- Gem roll for a cut. Returns the ore tier (0 = nothing inside).
function D.gemRoll(cube: any,ids: {number},random: () -> number): number
 local miss=1;local tier=0;local deepest=0
 for _,id in ipairs(ids) do
  local c=cube.cells[id]
  deepest=math.max(deepest,cube.height-c.cy)
  if c.ore>0 then miss*=1-D.GEM_CHANCE_ORE;tier=math.max(tier,c.ore) else miss*=1-D.GEM_CHANCE_STONE end
 end
 if random()>=1-miss then return 0 end
 if tier>0 then return tier end
 local t=deepest/cube.height
 return math.clamp(math.floor(1+t*4.2+(random()*1.4-.7)),1,#D.ORES)
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

-- Split plane of a cell: through its center, mostly vertical, angle from its id.
function D.splitPlane(cube: any,id: number): ({number},{number})
 local cell=cube.cells[id]
 local a=(id*.6180339887)%1*math.pi*2
 return {cell.cx,cell.cy,cell.cz},unit({math.cos(a),.22,math.sin(a)})
end
-- Two closed halves of a cell. Cut faces carry label 0.
function D.split(cube: any,id: number)
 local m,n=D.splitPlane(cube,id)
 local faces=cube.cells[id].faces
 local copy={}
 for _,f in ipairs(faces) do table.insert(copy,{verts=f.verts,label=f.label}) end
 local a=clipHull(copy,m,n,0)
 local b=clipHull(copy,m,{-n[1],-n[2],-n[3]},0)
 measure(a);measure(b)
 return {center=m,normal=n,a=a,b=b}
end
-- Crack lines for a cell: its outline on the visible surface (edges of open
-- faces not shared with another open face of the same cell), each oriented
-- away from the beam contact, plus where the split plane will cross it.
function D.cracks(cube: any,id: number)
 local cell=cube.cells[id]
 local contact=D.contact(cube,id)
 local count={}
 local list={}
 local function k(a: {number},b: {number})
  local function r(v: {number}) return string.format('%.2f,%.2f,%.2f',v[1],v[2],v[3]) end
  local ka,kb=r(a),r(b)
  if ka<kb then return ka..'|'..kb end
  return kb..'|'..ka
 end
 for _,f in ipairs(cell.faces) do
  if D.faceOpen(cube,f) then
   local vs=f.verts
   for i=1,#vs do
    local a,b=vs[i],vs[i%#vs+1]
    local key=k(a,b)
    count[key]=(count[key] or 0)+1
    table.insert(list,{a=a,b=b,key=key,normal=f.normal})
   end
  end
 end
 local edges={}
 local far=0
 for _,e in ipairs(list) do
  if count[e.key]==1 then
   local da=math.sqrt(dot(sub(e.a,contact),sub(e.a,contact)))
   local db=math.sqrt(dot(sub(e.b,contact),sub(e.b,contact)))
   local a,b,d0,d1=e.a,e.b,da,db
   if db<da then a,b,d0,d1=e.b,e.a,db,da end
   local len=math.sqrt(dot(sub(b,a),sub(b,a)))
   if len>.05 then table.insert(edges,{a=a,b=b,start=d0,len=len,normal=e.normal});far=math.max(far,d1) end
  end
 end
 -- The split line across the open faces.
 local m,n=D.splitPlane(cube,id)
 local seams={}
 for _,f in ipairs(cell.faces) do
  if D.faceOpen(cube,f) then
   local hits={}
   local vs=f.verts
   for i=1,#vs do
    local a,b=vs[i],vs[i%#vs+1]
    local da,db=dot(sub(a,m),n),dot(sub(b,m),n)
    if (da<0 and db>0) or (da>0 and db<0) then
     local t=da/(da-db);table.insert(hits,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t})
    end
   end
   if #hits==2 then table.insert(seams,{a=hits[1],b=hits[2],normal=f.normal}) end
  end
 end
 return {edges=edges,reach=far,seams=seams,contact=contact}
end

-- One flat color per rock: the depth gradient at the rock's center with a
-- small per-rock tone, so every face of a rock matches and neighboring rocks
-- read apart. Outer-surface faces use the gradient at their own height so the
-- intact top and walls stay seamless.
function D.faceColor(cube: any,cellId: number,face: any): {number}
 if face.label<0 then return D.gradient(face.center[2],cube.height) end
 local cell=cube.cells[cellId]
 local c=D.gradient(cell.cy,cube.height)
 local light=1+D.TINT*(hash(cellId,7,13,cube.seed)*2-1)
 return {math.clamp(c[1]*light,0,255),math.clamp(c[2]*light,0,255),math.clamp(c[3]*light,0,255)}
end

-- Intact stretches of the top and the four walls render as one slab per tile.
-- A tile breaks into the faces under it once any of their cells is cut or targeted.
-- Each tile: side label, rect in its plane's (u,v) and a list of {cell, face index}.
local function planeUV(label: number,v: {number}): (number,number)
 if label==-2 then return v[1],v[3] end
 if label==-3 or label==-4 then return v[3],v[2] end
 return v[1],v[2]
end
function D.tiles(cube: any)
 local W,H=cube.width,cube.height
 local T=D.TILE;local n=math.ceil(W/T);local bands=math.ceil(H/D.BAND-1e-6)
 local tiles,faceTiles={},{}
 local function tileKey(side: number,i: number,j: number) return -side*100000+i*100+j end
 for _,side in ipairs({-2,-3,-4,-5,-6}) do
  for i=0,n-1 do
   for j=0,(side==-2 and n or bands)-1 do
    local key=tileKey(side,i,j)
    local u0,u1=i*T,math.min(W,(i+1)*T)
    local v0,v1
    if side==-2 then v0,v1=j*T,math.min(W,(j+1)*T) else v0,v1=j*D.BAND,math.min(H,(j+1)*D.BAND) end
    tiles[key]={key=key,side=side,u0=u0,u1=u1,v0=v0,v1=v1,faces={}}
   end
  end
 end
 for _,cell in ipairs(cube.cells) do
  local perFace={}
  for fi,f in ipairs(cell.faces) do
   if f.label<-1 then
    local umin,umax,vmin,vmax=math.huge,-math.huge,math.huge,-math.huge
    for _,v in ipairs(f.verts) do
     local u,w=planeUV(f.label,v)
     umin=math.min(umin,u);umax=math.max(umax,u);vmin=math.min(vmin,w);vmax=math.max(vmax,w)
    end
    local list={}
    local stepV=f.label==-2 and T or D.BAND
    for i=math.max(0,math.floor(umin/T)),math.min(n-1,math.floor((umax-1e-6)/T)) do
     for j=math.max(0,math.floor(vmin/stepV)),math.floor((vmax-1e-6)/stepV) do
      local tile=tiles[tileKey(f.label,i,j)]
      if tile then table.insert(tile.faces,{cell.id,fi});table.insert(list,tile.key) end
     end
    end
    perFace[fi]=list
   end
  end
  faceTiles[cell.id]=perFace
 end
 return tiles,faceTiles
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

-- A triangle in any orientation as two right-triangle wedges of thickness
-- `thick`, pushed inward so the outer face sits on the triangle's plane.
-- Each wedge: {pos, right, up, back, size} with size={X thickness, Y, Z}.
local function triangle(a: {number},b: {number},c: {number},outward: {number},thick: number,out: {any})
 local ab,ac,bc=sub(b,a),sub(c,a),sub(c,b)
 local abd,acd,bcd=dot(ab,ab),dot(ac,ac),dot(bc,bc)
 if abd>acd and abd>bcd then c,a=a,c elseif acd>bcd and acd>abd then a,b=b,a end
 ab,ac,bc=sub(b,a),sub(c,a),sub(c,b)
 local right=unit(cross(ac,ab));local up=unit(cross(bc,right));local back=unit(bc)
 local height=math.abs(dot(ab,up))
 if height<.03 then return end
 local shift={-outward[1]*thick*.5,-outward[2]*thick*.5,-outward[3]*thick*.5}
 local d1,d2=math.abs(dot(ab,back)),math.abs(dot(ac,back))
 local cy=(a[2]+b[2]+c[2])/3
 if d1>.03 then table.insert(out,{pos={(a[1]+b[1])*.5+shift[1],(a[2]+b[2])*.5+shift[2],(a[3]+b[3])*.5+shift[3]},right=right,up=up,back=back,size={thick,height,d1},y=cy}) end
 if d2>.03 then table.insert(out,{pos={(a[1]+c[1])*.5+shift[1],(a[2]+c[2])*.5+shift[2],(a[3]+c[3])*.5+shift[3]},right={-right[1],-right[2],-right[3]},up=up,back={-back[1],-back[2],-back[3]},size={thick,height,d2},y=cy}) end
end
-- Wedges for one face (cube-local coordinates).
function D.faceWedges(face: any,thick: number?)
 local out={}
 local vs=face.verts
 for i=2,#vs-1 do triangle(vs[1],vs[i],vs[i+1],face.normal,thick or .4,out) end
 return out
end
return D
