--!strict
-- Dig Cube: one huge breakable block, built for any kind of cut.
--
-- The block is first cut into cells by a tessellation (3D Voronoi by default;
-- layered columns and bricks are built in too). Every cell is a convex
-- polyhedron. Cells are stored as live convex *pieces*, and every change to the
-- rock is an operation that any drone can perform:
--   cell  : crack whole cells out along the tessellation (plus blasted neighbors)
--   sphere: scoop a round chunk
--   box   : cut a straight rectangular trench
--   core  : bore a round vertical plug
-- Any convex cutter works the same way: each piece it touches is split into the
-- part inside (removed) and convex parts outside (kept), so new cutter shapes
-- are just new plane sets (see D.opPlanes).
--
-- Pure and deterministic: the server and every client build the same cube from
-- the seed and apply the same replicated operation list in order, so they hold
-- identical geometry. Ore is hidden inside cells; every cut rolls for a gem.
--
-- Digging (server): a cell can be targeted when it touches air and every cell
-- resting on it (across a face pointing up) is gone. Drones pick at random,
-- weighted toward a cone-shaped crater around the player (or a tapped spot),
-- deeper first, away from each other and toward recent cuts.
local D={}
D.WIDTH=88
D.HEIGHT=44
D.CELL=7.6 -- typical distance between neighboring Voronoi sites (studs)
D.SWING=.28 -- regional cell size swing: big boulders next to smaller blocks
D.CENTER={140,4,20} -- bottom center in world space (on the flat plane east of the hub)
D.HP_SCALE=.07 -- per cubic stud removed
D.DEPTH_HARD=.03 -- extra hardness per stud of depth
D.UP=.5 -- a face whose normal points up more than this holds a cell resting on this one
D.MAX_BLAST=12
D.MIN_PIECE=4 -- cubic studs: smaller leftovers crumble with the cut
D.CRUMBLE=.3 -- a cell crumbles away once less than this share of it remains
D.TINT=.16 -- per-rock tone swing so neighboring rocks read apart in bright sun
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
D.TESSELLATIONS={'voronoi','strata','bricks'}
D.DEFAULT_TESSELLATION='voronoi'
-- Cutter shapes at cutSize 1 (cut-size upgrades scale them).
D.CUTTERS={
 cell={name='Crack-out'},
 sphere={name='Round blast',radius=4.3},
 box={name='Trench',size={8,3.2,3.4}},
 core={name='Core bore',radius=2.8,height=5.5,sides=12},
}
-- Which cut each drone type makes. Strikers (the starter miners) each keep one
-- cut of their own, fixed by their permanent identity.
D.ROLE_CUTTER={Charger='sphere',Bubbler='sphere',Singularity='sphere',Ballcaster='sphere',Starforge='sphere',
 Gridcutter='box',Ramiel='box',Halver='core',Nomad='core',Needler='core',Frostbite='cell',Resonator='cell'}
D.STRIKER_CUTTERS={'cell','sphere','box','core'}
-- Ore tiers follow the existing crystal tiers (Workshop.CRYSTAL_TIERS).
D.ORES={
 {material='Amber',name='Amber',color={255,153,20}},
 {material='RunRuby',name='Ruby',color={226,62,78}},
 {material='RunQuartz',name='Quartz',color={97,177,224}},
 {material='RunViolet',name='Violet',color={152,98,222}},
 {material='Diamond',name='Diamond',color={236,226,246}},
}
-- Rock color by height: sand at the top through orange, rust and mauve to slate.
D.GRADIENT={{226,196,150},{214,160,104},{192,120,78},{160,92,70},{124,80,76},{92,74,86},{66,64,84},{46,48,64}}
D.GRADIENT_CURVE=.55 -- below 1: color changes fastest near the top, where pits start
-- Face labels: >0 neighbor cell, -1 bottom, -2 top, -3 west, -4 east, -5 south,
-- -6 north, 0 = a cut surface (air), -9 = between two kept pieces (hidden),
-- -77 = not yet matched to its neighbor (build only).
local CUT,INNER,PENDING=0,-9,-77

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
 local t=math.clamp(1-y/height,0,1)^D.GRADIENT_CURVE*(#D.GRADIENT-1)
 local i=math.floor(t);local f=t-i
 local a=D.GRADIENT[i+1];local b=D.GRADIENT[math.min(#D.GRADIENT,i+2)]
 return {a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f,a[3]+(b[3]-a[3])*f}
end
local function stringHash(s: string): number
 local h=7
 for i=1,#s do h=(h*31+string.byte(s,i))%1000003 end
 return h
end
-- Which cut a drone makes. Typed drones keep theirs (D.ROLE_CUTTER). Starter
-- Strikers: the first drone in a fleet is a multi-tool that rotates through
-- every cut, one after another (`serial` counts its cuts); the others each
-- keep one by slot (round blast, trench, core bore, ...), so every player's
-- crew shows every shape. Without a slot, the drone id picks a fixed cut.
function D.cutterFor(role: string?,droneId: string?,slot: number?,serial: number?): string
 local kind=role and D.ROLE_CUTTER[role]
 if kind then return kind end
 if role==nil or role=='Striker' or role=='Blue' then
  local list=D.STRIKER_CUTTERS
  if slot==1 then return list[(serial or 0)%#list+1] end
  if slot then return list[(slot-2)%(#list-1)+2] end
  return list[stringHash(droneId or '')%#list+1]
 end
 return 'cell'
end

local function key3(ix: number,iy: number,iz: number) return (ix*1031+iy)*1031+iz end
local function sub(a: {number},b: {number}) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function dot(a: {number},b: {number}) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function cross(a: {number},b: {number}) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function unit(a: {number}) local l=math.sqrt(dot(a,a));if l<1e-12 then return {0,0,0} end return {a[1]/l,a[2]/l,a[3]/l} end
local function scale(a: {number},s: number) return {a[1]*s,a[2]*s,a[3]*s} end

-- Variable-radius Poisson disk sampling (Bridson) in a box; `flat` keeps y=0 (2D).
local function poisson(R: any,W: number,H: number,radius: (number,number,number)->number,rmax: number,flat: boolean?)
 local bucket=rmax
 local grid={} :: {[number]:{number}}
 local pts={} :: {any}
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
 local x0,y0,z0=R(0,W),flat and 0 or R(0,H),R(0,W)
 add(x0,y0,z0,radius(x0,y0,z0))
 while #active>0 do
  local slot=math.floor(R()*#active)+1
  local p=pts[active[slot]]
  local found=false
  for _=1,20 do
   local u=flat and 0 or R(-1,1);local a=R(0,math.pi*2);local s=math.sqrt(1-u*u)
   local dist=R(p.r,p.r*1.8)
   local x,y,z=p.x+s*math.cos(a)*dist,p.y+u*dist,p.z+s*math.sin(a)*dist
   local r=radius(math.clamp(x,0,W),math.clamp(y,0,H),math.clamp(z,0,W))
   if free(x,y,z,r) then add(x,y,z,r);found=true;break end
  end
  if not found then active[slot]=active[#active];active[#active]=nil end
 end
 return pts,grid,bucket
end

-- Clip a convex polygon, keeping (v-m).n <= 0.
local function clipPolygon(poly: {{number}},m: {number},n: {number}): {{number}}
 local out={}
 local k=#poly
 for i=1,k do
  local a=poly[i];local b=poly[i%k+1]
  local da=(a[1]-m[1])*n[1]+(a[2]-m[2])*n[2]+(a[3]-m[3])*n[3]
  local db=(b[1]-m[1])*n[1]+(b[2]-m[2])*n[2]+(b[3]-m[3])*n[3]
  if da<=1e-9 then table.insert(out,a) end
  if (da<-1e-9 and db>1e-9) or (da>1e-9 and db<-1e-9) then
   local t=da/(da-db)
   table.insert(out,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t})
  end
 end
 local i=1
 while i<=#out and #out>=3 do
  local a=out[i];local b=out[i%#out+1]
  if (a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2<1e-10 then table.remove(out,i) else i+=1 end
 end
 return out
end

-- Cut a convex polyhedron (list of faces) by a plane, keeping (v-m).n <= 0.
-- The new cap face gets `label`.
local function clipHull(faces: {any},m: {number},n: {number},label: number)
 local out={};local cap={}
 -- A face lying in the plane: if it faces along n the hull is already on the
 -- kept side (keep everything, no cap); if it faces against n nothing is kept.
 for _,f in ipairs(faces) do
  local flat=true
  for _,v in ipairs(f.verts) do
   if math.abs((v[1]-m[1])*n[1]+(v[2]-m[2])*n[2]+(v[3]-m[3])*n[3])>1e-7 then flat=false;break end
  end
  if flat then
   local inner={0,0,0};local count=0
   for _,g in ipairs(faces) do for _,v in ipairs(g.verts) do inner[1]+=v[1];inner[2]+=v[2];inner[3]+=v[3];count+=1 end end
   inner={inner[1]/count-m[1],inner[2]/count-m[2],inner[3]/count-m[3]}
   if inner[1]*n[1]+inner[2]*n[2]+inner[3]*n[3]<0 then return faces end
   return {}
  end
 end
 for _,f in ipairs(faces) do
  local vs=f.verts;local k=#vs
  for i=1,k do
   local a=vs[i];local b=vs[i%k+1]
   local da=(a[1]-m[1])*n[1]+(a[2]-m[2])*n[2]+(a[3]-m[3])*n[3]
   local db=(b[1]-m[1])*n[1]+(b[2]-m[2])*n[2]+(b[3]-m[3])*n[3]
   if math.abs(da)<=1e-9 then table.insert(cap,a) end
   if (da<-1e-9 and db>1e-9) or (da>1e-9 and db<-1e-9) then
    local t=da/(da-db)
    table.insert(cap,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t})
   end
  end
  local nv=clipPolygon(vs,m,n)
  if #nv>=3 then table.insert(out,{verts=nv,label=f.label}) end
 end
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

local function polyArea(vs: {{number}}): (number,{number})
 local nx,ny,nz=0,0,0
 for i=1,#vs do
  local a=vs[i];local b=vs[i%#vs+1]
  nx+=(a[2]-b[2])*(a[3]+b[3]);ny+=(a[3]-b[3])*(a[1]+b[1]);nz+=(a[1]-b[1])*(a[2]+b[2])
 end
 local len=math.sqrt(nx*nx+ny*ny+nz*nz)
 return len*.5,len>1e-12 and {nx/len,ny/len,nz/len} or {0,1,0}
end

-- Normals, areas, centers, volume and bounds of a hull.
local function measure(faces: {any})
 local ref={0,0,0};local count=0
 for _,f in ipairs(faces) do for _,v in ipairs(f.verts) do ref[1]+=v[1];ref[2]+=v[2];ref[3]+=v[3];count+=1 end end
 if count==0 then return 0,{0,0,0},{0,0,0},{0,0,0} end
 ref={ref[1]/count,ref[2]/count,ref[3]/count}
 local volume=0;local cen={0,0,0}
 local lo={math.huge,math.huge,math.huge};local hi={-math.huge,-math.huge,-math.huge}
 for _,f in ipairs(faces) do
  local vs=f.verts
  local fc={0,0,0}
  for _,a in ipairs(vs) do
   fc[1]+=a[1];fc[2]+=a[2];fc[3]+=a[3]
   for k=1,3 do lo[k]=math.min(lo[k],a[k]);hi[k]=math.max(hi[k],a[k]) end
  end
  fc={fc[1]/#vs,fc[2]/#vs,fc[3]/#vs}
  local area,nrm=polyArea(vs)
  if dot(nrm,sub(fc,ref))<0 then nrm={-nrm[1],-nrm[2],-nrm[3]} end
  f.normal=nrm;f.area=area;f.center=fc
  for i=2,#vs-1 do
   local a,b,c=vs[1],vs[i],vs[i+1]
   local tv=math.abs(dot(sub(a,ref),cross(sub(b,ref),sub(c,ref))))/6
   volume+=tv
   cen[1]+=tv*(ref[1]+a[1]+b[1]+c[1])*.25;cen[2]+=tv*(ref[2]+a[2]+b[2]+c[2])*.25;cen[3]+=tv*(ref[3]+a[3]+b[3]+c[3])*.25
  end
 end
 if volume>1e-9 then cen={cen[1]/volume,cen[2]/volume,cen[3]/volume} else cen=ref end
 return volume,cen,lo,hi
end

-- An axis-aligned box as faces; labels {bottom,top,west,east,south,north}.
local function boxFaces(x0: number,x1: number,y0: number,y1: number,z0: number,z1: number,l: {number})
 return {
  {verts={{x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1}},label=l[1]},
  {verts={{x0,y1,z0},{x0,y1,z1},{x1,y1,z1},{x1,y1,z0}},label=l[2]},
  {verts={{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0}},label=l[3]},
  {verts={{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},{x1,y0,z1}},label=l[4]},
  {verts={{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},{x1,y0,z0}},label=l[5]},
  {verts={{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1}},label=l[6]},
 }
end
local function sideLabels(x0: number,x1: number,y0: number,y1: number,z0: number,z1: number,W: number,H: number)
 local function edge(v: number,at: number,label: number) return math.abs(v-at)<1e-6 and label or PENDING end
 return {edge(y0,0,-1),edge(y1,H,-2),edge(x0,0,-3),edge(x1,W,-4),edge(z0,0,-5),edge(z1,W,-6)}
end

-- Clip each site's region by bisector planes of its nearest sites (Voronoi).
local function voronoiRegions(pts: {any},grid: any,bucket: number,base: (any)->{any},reach: number)
 local raw={}
 for i,p in ipairs(pts) do
  local near={}
  local ix,iy,iz=math.floor(p.x/bucket),math.floor(p.y/bucket),math.floor(p.z/bucket)
  for gx=ix-reach,ix+reach do for gy=iy-reach,iy+reach do for gz=iz-reach,iz+reach do
   local list=grid[key3(gx,gy,gz)]
   if list then for _,j in ipairs(list) do if j~=i then
    local q=pts[j];table.insert(near,{j=j,d=(q.x-p.x)^2+(q.y-p.y)^2+(q.z-p.z)^2})
   end end end
  end end end
  table.sort(near,function(a,b) return a.d<b.d end)
  local faces=base(p)
  for _,q in ipairs(near) do
   local far=0
   for _,f in ipairs(faces) do for _,v in ipairs(f.verts) do far=math.max(far,(v[1]-p.x)^2+(v[2]-p.y)^2+(v[3]-p.z)^2) end end
   if q.d*.25>far then break end
   local o=pts[q.j]
   faces=clipHull(faces,{(p.x+o.x)*.5,(p.y+o.y)*.5,(p.z+o.z)*.5},{o.x-p.x,o.y-p.y,o.z-p.z},o.id or q.j)
   if #faces<4 then break end
  end
  raw[i]=faces
 end
 return raw
end

-- Tessellations: each returns a list of raw cells (face lists) filling the box.
local TESS={}
function TESS.voronoi(R: any,W: number,H: number)
 local sizeSeed=math.floor(R(1,1000000))
 local rmax=D.CELL*(1+D.SWING)
 local function radius(x: number,y: number,z: number)
  return D.CELL*(1+D.SWING*(D.noise3(x/26,y/26,z/26,sizeSeed)*2-1))
 end
 local pts,grid,bucket=poisson(R,W,H,radius,rmax)
 return voronoiRegions(pts,grid,bucket,function() return boxFaces(0,W,0,H,0,W,{-1,-2,-3,-4,-5,-6}) end,2)
end
-- Layered columns: each stratum has its own 2D Voronoi pattern and cell size,
-- so cracks never line up between layers.
function TESS.strata(R: any,W: number,H: number)
 local thick={};local total=0
 for L=1,10 do thick[L]=R(3.6,5.2);total+=thick[L] end
 local raw={}
 local top=H
 for L=1,10 do
  local t=thick[L]*H/total
  local y1=top;local y0=L==10 and 0 or top-t;top=y0
  local size=R(5.2,8.4);local swing=R(.15,.3)
  local seed=math.floor(R(1,1000000))
  local function radius(x: number,_y: number,z: number) return size*(1+swing*(D.noise3(x/24,L*3.1,z/24,seed)*2-1)) end
  local pts,grid,bucket=poisson(R,W,0,radius,size*(1+swing),true)
  local offset=#raw
  for _,p in ipairs(pts) do p.id=nil end
  for j,p in ipairs(pts) do p.id=offset+j end
  local regions=voronoiRegions(pts,grid,bucket,function()
   return boxFaces(0,W,y0,y1,0,W,{L==10 and -1 or PENDING,L==1 and -2 or PENDING,-3,-4,-5,-6})
  end,3)
  for j=1,#pts do raw[offset+j]=regions[j] end
 end
 return raw
end
-- Staggered bricks, half a brick offset row to row and layer to layer.
function TESS.bricks(R: any,W: number,H: number)
 local raw={}
 local layers=10;local rows=11;local length=11
 local lh=H/layers;local depth=W/rows
 for L=0,layers-1 do
  for r=0,rows-1 do
   local shift=((L+r)%2)*length*.5
   local x=-shift
   while x<W-1e-6 do
    local x0=math.max(0,x);local x1=math.min(W,x+length)
    if x1-x0>1 then
     local y0,y1,z0,z1=L*lh,(L+1)*lh,r*depth,(r+1)*depth
     table.insert(raw,boxFaces(x0,x1,y0,y1,z0,z1,sideLabels(x0,x1,y0,y1,z0,z1,W,H)))
    end
    x+=length
   end
  end
 end
 return raw
end

-- Faces built without a neighbor label (layer and brick interfaces) are split
-- into one face per neighbor they actually touch.
local function clipToPolygon(poly: {{number}},clip: {{number}},normal: {number}): {{number}}
 local c={0,0,0}
 for _,v in ipairs(clip) do c[1]+=v[1];c[2]+=v[2];c[3]+=v[3] end
 c={c[1]/#clip,c[2]/#clip,c[3]/#clip}
 local out=poly
 for i=1,#clip do
  local a,b=clip[i],clip[i%#clip+1]
  local e=cross(sub(b,a),normal)
  if dot(e,sub(c,a))>0 then e={-e[1],-e[2],-e[3]} end
  out=clipPolygon(out,a,e)
  if #out<3 then return out end
 end
 return out
end
local function conform(cells: {any})
 local G=8
 local grid={}
 for i,c in ipairs(cells) do
  for gx=math.floor(c.lo[1]/G),math.floor(c.hi[1]/G) do for gy=math.floor(c.lo[2]/G),math.floor(c.hi[2]/G) do for gz=math.floor(c.lo[3]/G),math.floor(c.hi[3]/G) do
   local k=key3(gx,gy,gz);local list=grid[k];if not list then list={};grid[k]=list end
   table.insert(list,i)
  end end end
 end
 local fixed={}
 for i,c in ipairs(cells) do
  local out={}
  for _,f in ipairs(c.faces) do
   if f.label~=PENDING then table.insert(out,f) else
    local lo={math.huge,math.huge,math.huge};local hi={-math.huge,-math.huge,-math.huge}
    for _,v in ipairs(f.verts) do for k=1,3 do lo[k]=math.min(lo[k],v[k]);hi[k]=math.max(hi[k],v[k]) end end
    local seen={}
    for gx=math.floor(lo[1]/G),math.floor(hi[1]/G) do for gy=math.floor(lo[2]/G),math.floor(hi[2]/G) do for gz=math.floor(lo[3]/G),math.floor(hi[3]/G) do
     for _,j in ipairs(grid[key3(gx,gy,gz)] or {}) do
      if j~=i and not seen[j] then
       seen[j]=true
       for _,g in ipairs(cells[j].faces) do
        if dot(g.normal,f.normal)<-.999 and math.abs(dot(f.normal,sub(g.center,f.center)))<1e-4 then
         local part=clipToPolygon(f.verts,g.verts,g.normal)
         if #part>=3 and polyArea(part)>1e-3 then table.insert(out,{verts=part,label=j}) end
        end
       end
      end
     end
    end end end
   end
  end
  fixed[i]=out
 end
 for i,c in ipairs(cells) do c.faces=fixed[i] end
end

function D.build(seed: number,tessellation: string?)
 local W,H=D.WIDTH,D.HEIGHT
 local R=D.rng(seed)
 local oreSeed=math.floor(R(1,1000000))
 local kind=tessellation and TESS[tessellation] and tessellation or D.DEFAULT_TESSELLATION
 local raw=TESS[kind](R,W,H)
 local cube={seed=seed,tessellation=kind,width=W,height=H,cells={},pieces={},cellPieces={},removed={},touched={},
  frontier={},removedCount=0,removedVolume=0,totalVolume=W*W*H,nextPiece=0,opCount=0}
 for i,faces in ipairs(raw) do
  local volume,cen,lo,hi=measure(faces)
  cube.cells[i]={id=i,faces=faces,volume=volume,cx=cen[1],cy=cen[2],cz=cen[3],lo=lo,hi=hi,minY=lo[2],maxY=hi[2],
   neighbors={},up={},ore=0,hp=0}
 end
 local pending=false
 for _,c in ipairs(cube.cells) do for _,f in ipairs(c.faces) do if f.label==PENDING then pending=true end end end
 if pending then conform(cube.cells) end
 local has={}
 for _,cell in ipairs(cube.cells) do
  local kept={}
  for _,f in ipairs(cell.faces) do if (f.area or polyArea(f.verts))>1e-3 then table.insert(kept,f) end end
  cell.faces=kept
  measure(cell.faces)
  local set={}
  for _,f in ipairs(cell.faces) do if f.label>0 then set[f.label]=true end end
  has[cell.id]=set
 end
 for _,cell in ipairs(cube.cells) do
  local r=0
  for _,f in ipairs(cell.faces) do
   for _,v in ipairs(f.verts) do r=math.max(r,math.sqrt((v[1]-cell.cx)^2+(v[3]-cell.cz)^2)) end
   if f.label>0 then
    if has[f.label][cell.id] then
     if not table.find(cell.neighbors,f.label) then table.insert(cell.neighbors,f.label) end
     if f.normal[2]>D.UP and not table.find(cell.up,f.label) then table.insert(cell.up,f.label) end
    else f.label=INNER end
   end
  end
  cell.radius=r
  local depth=H-cell.cy
  local t=depth/H
  local n=D.noise3(cell.cx/13,cell.cy/9,cell.cz/13,oreSeed)
  if n>.74-.1*t then cell.ore=math.clamp(math.floor(1+t*4.2+R(-.7,.7)),1,#D.ORES) end
  cell.hp=math.max(4,cell.volume*D.HP_SCALE*(1+depth*D.DEPTH_HARD))
  -- Every cell starts as one whole piece.
  cube.cellPieces[cell.id]={}
  D.addPiece(cube,cell.id,cell.faces)
  for _,f in ipairs(cell.faces) do if f.label<-1 and f.label>-7 then cube.frontier[cell.id]=true;break end end
 end
 return cube
end

-- Pieces: the live convex parts of each cell.
function D.addPiece(cube: any,cellId: number,faces: {any}): any
 local volume,cen,lo,hi=measure(faces)
 cube.nextPiece+=1
 local piece={id=cube.nextPiece,cell=cellId,faces=faces,volume=volume,cx=cen[1],cy=cen[2],cz=cen[3],lo=lo,hi=hi}
 cube.pieces[piece.id]=piece
 cube.cellPieces[cellId][piece.id]=true
 return piece
end
local function dropPiece(cube: any,piece: any)
 cube.pieces[piece.id]=nil
 cube.cellPieces[piece.cell][piece.id]=nil
end
function D.cellVolume(cube: any,cellId: number): number
 local v=0
 for id in pairs(cube.cellPieces[cellId]) do v+=cube.pieces[id].volume end
 return v
end
function D.piecesOf(cube: any,cellId: number): {any}
 local list={}
 for id in pairs(cube.cellPieces[cellId]) do table.insert(list,cube.pieces[id]) end
 table.sort(list,function(a,b) return a.id<b.id end)
 return list
end

-- Open to air (strict): a cut surface, a removed neighbor, or the top or sides.
function D.faceOpen(cube: any,face: any): boolean
 local l=face.label
 if l==CUT then return true end
 if l>0 then return cube.removed[l]==true end
 return l<-1 and l>-7
end
-- Possibly visible (for drawing): also faces toward a neighbor that was cut into.
function D.faceVisible(cube: any,face: any): boolean
 local l=face.label
 if l>0 then return cube.removed[l]==true or cube.touched[l]==true end
 return D.faceOpen(cube,face)
end
function D.diggable(cube: any,id: number): boolean
 if cube.removed[id] then return false end
 local cell=cube.cells[id]
 for _,other in ipairs(cell.up) do if not cube.removed[other] then return false end end
 for pid in pairs(cube.cellPieces[id]) do
  for _,f in ipairs(cube.pieces[pid].faces) do if D.faceOpen(cube,f) then return true end end
 end
 return false
end
-- Where a cut meets the cell: the center of its most upward open face.
function D.contact(cube: any,id: number): ({number},{number})
 local cell=cube.cells[id]
 local best,score=nil,-math.huge
 for pid in pairs(cube.cellPieces[id]) do
  for _,f in ipairs(cube.pieces[pid].faces) do
   if D.faceOpen(cube,f) and (f.normal[2]+f.area*1e-4)>score then best,score=f,f.normal[2]+f.area*1e-4 end
  end
 end
 if not best then return {cell.cx,cell.maxY,cell.cz},{0,1,0} end
 return best.center,best.normal
end

-- Weighted random choice among cells to target. opts:
--  focusX/focusZ: local point the crew should favor (player or tapped spot)
--  taken: {[cellId]=true} claimed by other drones; takenPoints: {{x,z}} of those claims
--  recent: {[cellId]=time} of cuts; now; random: () -> number
function D.pick(cube: any,opts: any): number?
 local H=cube.height
 local random=opts.random or math.random
 local open={}
 for id in pairs(cube.frontier) do
  if not (opts.taken and opts.taken[id]) and D.diggable(cube,id) then table.insert(open,id) end
 end
 table.sort(open)
 -- A cone around the focus whose tip sits D.LEAD studs below the deepest
 -- cuttable cell there; the rim widens only as far as going deeper needs.
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
   if cube.touched[id] then w*=2.5 end
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

-- Cells cracked out together: the seed plus, when cutSize > 1, the nearest
-- neighbors (each with every cell still resting on it) up to cutSize^3 volume.
function D.chunk(cube: any,seed: number,cutSize: number?,taken: {[number]:any}?,random: (() -> number)?): {number}
 local cut=cutSize or 1
 if cut<=1.02 then return {seed} end
 local roll=random and random() or .5
 local s=cube.cells[seed]
 local target=s.volume*cut^3*(.8+.4*roll)
 local ids={seed};local inside={[seed]=true};local volume=D.cellVolume(cube,seed)
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
  for _,m in ipairs(bestSet) do add+=D.cellVolume(cube,m) end
  if volume+add*.5>target or #ids+#bestSet>D.MAX_BLAST then break end
  for _,m in ipairs(bestSet) do inside[m]=true;table.insert(ids,m) end
  volume+=add
 end
 return ids
end

-- Operations ----------------------------------------------------------------
-- op = {kind='c', cells={...}} | {kind='s', x,y,z,r} | {kind='b', x,y,z,yaw,sx,sy,sz}
--    | {kind='y', x,y,z,r,h}; plus tier (gem roll) once it has happened.
local function round(v: number): number return math.floor(v*100+.5)/100 end
local SPHERE_DIRS=(function()
 local dirs={}
 for _,v in ipairs({{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1},
  {1,1,0},{1,-1,0},{-1,1,0},{-1,-1,0},{1,0,1},{1,0,-1},{-1,0,1},{-1,0,-1},{0,1,1},{0,1,-1},{0,-1,1},{0,-1,-1}}) do
  table.insert(dirs,unit(v))
 end
 return dirs
end)()
-- Convex cutter as planes {n, point}: inside is (v-point).n <= 0. Also a bounding box.
function D.opPlanes(op: any): ({any},{number},{number})
 local planes={}
 local c={op.x,op.y,op.z}
 local reach
 if op.kind=='s' then
  for _,n in ipairs(SPHERE_DIRS) do table.insert(planes,{n=n,p={c[1]+n[1]*op.r,c[2]+n[2]*op.r,c[3]+n[3]*op.r}}) end
  reach=op.r*1.3
 elseif op.kind=='b' then
  local right={math.cos(op.yaw),0,math.sin(op.yaw)};local fwd={-math.sin(op.yaw),0,math.cos(op.yaw)};local up={0,1,0}
  for _,pair in ipairs({{right,op.sx},{up,op.sy},{fwd,op.sz}}) do
   local a,h=pair[1],pair[2]*.5
   table.insert(planes,{n=a,p={c[1]+a[1]*h,c[2]+a[2]*h,c[3]+a[3]*h}})
   table.insert(planes,{n=scale(a,-1),p={c[1]-a[1]*h,c[2]-a[2]*h,c[3]-a[3]*h}})
  end
  reach=math.sqrt(op.sx^2+op.sy^2+op.sz^2)*.5+.1
 else
  local sides=D.CUTTERS.core.sides
  for i=1,sides do
   local a=(i-.5)/sides*math.pi*2
   local n={math.cos(a),0,math.sin(a)}
   table.insert(planes,{n=n,p={c[1]+n[1]*op.r,c[2],c[3]+n[3]*op.r}})
  end
  table.insert(planes,{n={0,1,0},p={c[1],c[2]+op.h*.5,c[3]}})
  table.insert(planes,{n={0,-1,0},p={c[1],c[2]-op.h*.5,c[3]}})
  reach=math.sqrt(op.r^2*1.1+(op.h*.5)^2)+.1
 end
 return planes,{c[1]-reach,c[2]-reach,c[3]-reach},{c[1]+reach,c[2]+reach,c[3]+reach}
end
function D.encodeOp(op: any): string
 local body
 if op.kind=='c' then
  local parts={};for i,id in ipairs(op.cells) do parts[i]=tostring(id) end
  body='c'..table.concat(parts,'.')
 elseif op.kind=='s' then body=string.format('s%g,%g,%g,%g',op.x,op.y,op.z,op.r)
 elseif op.kind=='b' then body=string.format('b%g,%g,%g,%g,%g,%g,%g',op.x,op.y,op.z,op.yaw,op.sx,op.sy,op.sz)
 else body=string.format('y%g,%g,%g,%g,%g',op.x,op.y,op.z,op.r,op.h) end
 if op.tier then body..='|'..tostring(op.tier) end
 return body
end
function D.decodeOp(s: string): any
 local body,tier=string.match(s,'^([^|]+)|?(%d*)$')
 if not body then return nil end
 local kind=string.sub(body,1,1)
 local rest=string.sub(body,2)
 local nums={}
 local op: any={kind=kind,tier=tier~='' and tonumber(tier) or nil}
 if kind=='c' then
  op.cells={}
  for v in string.gmatch(rest,'%d+') do table.insert(op.cells,tonumber(v)) end
  return #op.cells>0 and op or nil
 end
 for v in string.gmatch(rest,'[^,]+') do table.insert(nums,tonumber(v)) end
 for _,v in ipairs(nums) do if type(v)~='number' or v~=v then return nil end end
 if kind=='s' and #nums==4 then op.x,op.y,op.z,op.r=nums[1],nums[2],nums[3],nums[4]
 elseif kind=='b' and #nums==7 then op.x,op.y,op.z,op.yaw,op.sx,op.sy,op.sz=table.unpack(nums)
 elseif kind=='y' and #nums==5 then op.x,op.y,op.z,op.r,op.h=table.unpack(nums)
 else return nil end
 return op
end

-- Plan a drone's cut at a target cell, in the drone's own cutter shape.
-- Shapes sit on the cell's most upward open face, sunk into the rock.
function D.planCut(cube: any,kind: string,cellId: number,cutSize: number?,yaw: number?,taken: any?,random: (() -> number)?): any
 local cut=math.clamp(cutSize or 1,.5,3)
 local p,n=D.contact(cube,cellId)
 if kind=='sphere' then
  local r=D.CUTTERS.sphere.radius*cut
  return {kind='s',x=round(p[1]-n[1]*r*.35),y=round(p[2]-n[2]*r*.35),z=round(p[3]-n[3]*r*.35),r=round(r)}
 elseif kind=='box' then
  local s=D.CUTTERS.box.size
  local sy=s[2]*cut
  return {kind='b',x=round(p[1]),y=round(p[2]-sy*.3),z=round(p[3]),yaw=round(yaw or 0),sx=round(s[1]*cut),sy=round(sy),sz=round(s[3]*cut)}
 elseif kind=='core' then
  local c=D.CUTTERS.core
  local h=c.height*cut
  return {kind='y',x=round(p[1]),y=round(p[2]-h*.3),z=round(p[3]),r=round(c.radius*cut),h=round(h)}
 end
 return {kind='c',cells=D.chunk(cube,cellId,cut,taken,random)}
end

local function insideAll(faces: {any},planes: {any}): {any}
 local rem=faces
 for _,pl in ipairs(planes) do
  rem=clipHull(rem,pl.p,pl.n,INNER)
  if #rem<4 then return {} end
 end
 return rem
end
local function overlaps(piece: any,lo: {number},hi: {number}): boolean
 return piece.hi[1]>=lo[1] and piece.lo[1]<=hi[1] and piece.hi[2]>=lo[2] and piece.lo[2]<=hi[2] and piece.hi[3]>=lo[3] and piece.lo[3]<=hi[3]
end
local function sortedPieces(cube: any): {any}
 local list={}
 for _,p in pairs(cube.pieces) do table.insert(list,p) end
 table.sort(list,function(a,b) return a.id<b.id end)
 return list
end

-- Volume an op would remove and the cells it reaches, without changing anything.
function D.preview(cube: any,op: any): (number,{number})
 local volume=0;local cells={}
 if op.kind=='c' then
  for _,id in ipairs(op.cells) do
   if not cube.removed[id] then volume+=D.cellVolume(cube,id);table.insert(cells,id) end
  end
  return volume,cells
 end
 local planes,lo,hi=D.opPlanes(op)
 local seen={}
 for _,piece in ipairs(sortedPieces(cube)) do
  if overlaps(piece,lo,hi) then
   local core=insideAll(piece.faces,planes)
   if #core>=4 then
    local v=measure(core)
    if v>1e-6 then volume+=v;if not seen[piece.cell] then seen[piece.cell]=true;table.insert(cells,piece.cell) end end
   end
  end
 end
 return volume,cells
end

-- Apply an op. Returns what changed:
--  removed: list of {cell, faces} chunks taken out (for the break animation)
--  gone/added: piece ids; cells: cells touched; volume removed; cellVolume per cell
function D.apply(cube: any,op: any): any
 local result={removed={},gone={},added={},cells={},volume=0,cellVolume={},center={0,0,0}}
 local touchedSet={}
 local function note(cellId: number,v: number)
  result.volume+=v
  result.cellVolume[cellId]=(result.cellVolume[cellId] or 0)+v
  if not touchedSet[cellId] then touchedSet[cellId]=true;table.insert(result.cells,cellId) end
 end
 local function take(piece: any)
  dropPiece(cube,piece)
  table.insert(result.gone,piece.id)
  table.insert(result.removed,{cell=piece.cell,faces=piece.faces})
  note(piece.cell,piece.volume)
 end
 if op.kind=='c' then
  for _,id in ipairs(op.cells) do
   if cube.cells[id] and not cube.removed[id] then
    for _,piece in ipairs(D.piecesOf(cube,id)) do take(piece) end
   end
  end
 else
  local planes,lo,hi=D.opPlanes(op)
  for _,piece in ipairs(sortedPieces(cube)) do
   if overlaps(piece,lo,hi) and #insideAll(piece.faces,planes)>=4 then
    dropPiece(cube,piece)
    table.insert(result.gone,piece.id)
    -- Keep the convex parts outside each cutter plane; the rest is the cut.
    local rem=piece.faces
    for _,pl in ipairs(planes) do
     local out=clipHull(rem,pl.p,scale(pl.n,-1),CUT)
     rem=clipHull(rem,pl.p,pl.n,INNER)
     if #out>=4 then
      local v=measure(out)
      if v>=D.MIN_PIECE then
       local kept=D.addPiece(cube,piece.cell,out)
       table.insert(result.added,kept.id)
      elseif v>1e-6 then
       table.insert(result.removed,{cell=piece.cell,faces=out});note(piece.cell,v)
      end
     end
     if #rem<4 then break end
    end
    if #rem>=4 then
     local v=measure(rem)
     if v>1e-6 then table.insert(result.removed,{cell=piece.cell,faces=rem});note(piece.cell,v) end
    end
   end
  end
  -- A cell that is mostly gone crumbles away completely.
  for _,id in ipairs(table.clone(result.cells)) do
   if D.cellVolume(cube,id)<cube.cells[id].volume*D.CRUMBLE then
    for _,piece in ipairs(D.piecesOf(cube,id)) do
     take(piece)
     local at=table.find(result.added,piece.id)
     if at then table.remove(result.added,at);table.remove(result.gone,#result.gone) end
    end
   end
  end
 end
 for _,id in ipairs(result.cells) do
  cube.touched[id]=true
  if next(cube.cellPieces[id])==nil and not cube.removed[id] then
   cube.removed[id]=true;cube.removedCount+=1;cube.frontier[id]=nil
  elseif not cube.removed[id] then cube.frontier[id]=true end
  for _,other in ipairs(cube.cells[id].neighbors) do if not cube.removed[other] then cube.frontier[other]=true end end
 end
 cube.removedVolume+=result.volume
 cube.opCount+=1
 local w,c=0,{0,0,0}
 for _,chunk in ipairs(result.removed) do
  local v,cen=measure(chunk.faces)
  w+=v;c[1]+=cen[1]*v;c[2]+=cen[2]*v;c[3]+=cen[3]*v
 end
 if w>0 then result.center={c[1]/w,c[2]/w,c[3]/w} end
 return result
end

function D.hp(cube: any,volume: number,depth: number,cutSize: number?): number
 -- Bigger cutters take longer but move more rock per second.
 return math.max(4,volume*D.HP_SCALE*(1+depth*D.DEPTH_HARD))/math.sqrt(math.max(1,cutSize or 1))
end
-- Gem roll for a cut. Returns the ore tier (0 = nothing inside).
function D.gemRoll(cube: any,result: any,random: () -> number): number
 local miss=1;local tier=0;local deepest=0
 for cellId,v in pairs(result.cellVolume) do
  local c=cube.cells[cellId]
  deepest=math.max(deepest,cube.height-c.cy)
  if c.ore>0 then
   miss*=1-D.GEM_CHANCE_ORE*math.min(1,v/c.volume*1.6)
   tier=math.max(tier,c.ore)
  end
 end
 miss*=1-D.GEM_CHANCE_STONE*math.clamp(result.volume/600,.4,2.5)
 if result.volume<=0 or random()>=1-miss then return 0 end
 if tier>0 then return tier end
 local t=deepest/cube.height
 return math.clamp(math.floor(1+t*4.2+(random()*1.4-.7)),1,#D.ORES)
end

-- Split plane of an op: through its center, mostly vertical, angle from the op.
function D.splitPlane(op: any,center: {number}): {number}
 local h=stringHash(D.encodeOp({kind=op.kind,cells=op.cells,x=op.x,y=op.y,z=op.z,r=op.r,h=op.h,yaw=op.yaw,sx=op.sx,sy=op.sy,sz=op.sz}))
 local a=(h*.6180339887)%1*math.pi*2
 return unit({math.cos(a),.22,math.sin(a)})
end
-- Two halves of removed chunks along a plane (for the break animation).
function D.splitChunks(chunks: {any},m: {number},n: {number}): ({any},{any})
 local a,b={},{}
 for _,chunk in ipairs(chunks) do
  local copy={}
  for _,f in ipairs(chunk.faces) do table.insert(copy,{verts=f.verts,label=f.label}) end
  local A=clipHull(copy,m,n,INNER);local B=clipHull(copy,m,scale(n,-1),INNER)
  if #A>=4 then measure(A);table.insert(a,{cell=chunk.cell,faces=A}) end
  if #B>=4 then measure(B);table.insert(b,{cell=chunk.cell,faces=B}) end
 end
 return a,b
end

-- Crack lines for a planned cut: the outline of the region it will remove on
-- the visible surface (oriented away from the contact point so cracks run
-- outward), plus where the split plane will cross it.
function D.outline(cube: any,op: any,contact: {number})
 local polys={}
 if op.kind=='c' then
  for _,id in ipairs(op.cells) do
   if not cube.removed[id] then
    for _,piece in ipairs(D.piecesOf(cube,id)) do
     for _,f in ipairs(piece.faces) do if D.faceOpen(cube,f) then table.insert(polys,{verts=f.verts,normal=f.normal}) end end
    end
   end
  end
 else
  local planes,lo,hi=D.opPlanes(op)
  for _,piece in ipairs(sortedPieces(cube)) do
   if overlaps(piece,lo,hi) then
    for _,f in ipairs(piece.faces) do
     if D.faceOpen(cube,f) then
      local poly=f.verts
      for _,pl in ipairs(planes) do poly=clipPolygon(poly,pl.p,pl.n);if #poly<3 then break end end
      if #poly>=3 then table.insert(polys,{verts=poly,normal=f.normal}) end
     end
    end
   end
  end
 end
 local count,list={},{}
 local function r(v: {number}) return string.format('%.1f,%.1f,%.1f',v[1],v[2],v[3]) end
 local center={0,0,0};local nv=0
 for _,poly in ipairs(polys) do
  local vs=poly.verts
  for i=1,#vs do
   local a,b=vs[i],vs[i%#vs+1]
   local ka,kb=r(a),r(b)
   local key=ka<kb and ka..'|'..kb or kb..'|'..ka
   count[key]=(count[key] or 0)+1
   table.insert(list,{a=a,b=b,key=key,normal=poly.normal})
   center[1]+=a[1];center[2]+=a[2];center[3]+=a[3];nv+=1
  end
 end
 if nv>0 then center={center[1]/nv,center[2]/nv,center[3]/nv} end
 local edges={};local far=0
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
 local n=D.splitPlane(op,center)
 local seams={}
 for _,poly in ipairs(polys) do
  local hits={}
  local vs=poly.verts
  for i=1,#vs do
   local a,b=vs[i],vs[i%#vs+1]
   local da,db=dot(sub(a,center),n),dot(sub(b,center),n)
   if (da<0 and db>0) or (da>0 and db<0) then
    local t=da/(da-db);table.insert(hits,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t})
   end
  end
  if #hits==2 then table.insert(seams,{a=hits[1],b=hits[2],normal=poly.normal}) end
 end
 return {edges=edges,reach=far,seams=seams}
end

-- Flat color for a face: one color per rock (the depth gradient at the rock's
-- center with a per-rock tone) so each rock reads as one object; outer-surface
-- faces use the gradient at their own height so the intact block stays seamless.
function D.faceColor(cube: any,cellId: number,face: any): {number}
 if face.label<0 and face.label>-7 then return D.gradient(face.center[2],cube.height) end
 local cell=cube.cells[cellId]
 local c=D.gradient(cell.cy,cube.height)
 local light=1+D.TINT*(hash(cellId,7,13,cube.seed)*2-1)
 if face.label==CUT or face.label==INNER then light*=1.06 end
 return {math.clamp(c[1]*light,0,255),math.clamp(c[2]*light,0,255),math.clamp(c[3]*light,0,255)}
end

-- Intact stretches of the top and the four walls render as one slab per tile.
-- Each tile lists the {cell, face index} outer faces under it.
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
   if f.label<-1 and f.label>-7 then
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

-- A triangle in any orientation as two right-triangle wedges of thickness
-- `thick`, pushed inward so the outer face sits on the triangle's plane.
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
-- Wedges for one face (cube-local coordinates). Thin, so a face never pokes
-- out past a neighboring face that meets it at a sharp angle.
D.SEAM_OVERLAP=.01 -- studs a face grows past edges it shares with a neighbor's flat surface
-- Wedges for one face of a piece (cube-local coordinates). Where the face
-- meets the cube's flat outer surface, its edge is pulled in by the wedge
-- thickness so its rim stays hidden under that surface (no colored lines
-- along pit rims); elsewhere it grows a hair so neighbors leave no gaps.
function D.pieceWedges(faces: {any},index: number,thick: number?): {any}
 local t=thick or .12
 local face=faces[index]
 local function k(v: {number}) return string.format('%.2f,%.2f,%.2f',v[1],v[2],v[3]) end
 local outer={}
 local here=face.label<-1 and face.label>-7
 if not here then
  for fi,g in ipairs(faces) do
   if fi~=index and g.label<-1 and g.label>-7 then
    for _,v in ipairs(g.verts) do outer[k(v)]=true end
   end
  end
 end
 local src=face.verts
 local c={0,0,0}
 for _,v in ipairs(src) do c[1]+=v[1];c[2]+=v[2];c[3]+=v[3] end
 c={c[1]/#src,c[2]/#src,c[3]/#src}
 local poly={}
 for i,v in ipairs(src) do
  local d=sub(v,c);local len=math.sqrt(dot(d,d))
  poly[i]=len>1e-6 and {v[1]+d[1]/len*D.SEAM_OVERLAP,v[2]+d[2]/len*D.SEAM_OVERLAP,v[3]+d[3]/len*D.SEAM_OVERLAP} or v
 end
 for i=1,#src do
  local a,b=src[i],src[i%#src+1]
  if outer[k(a)] and outer[k(b)] then
   -- Pull this edge in: keep only points at least t inside it.
   local e=unit(sub(b,a))
   local inward=unit(cross(face.normal,e))
   if dot(inward,sub(c,a))<0 then inward=scale(inward,-1) end
   poly=clipPolygon(poly,{a[1]+inward[1]*t,a[2]+inward[2]*t,a[3]+inward[3]*t},scale(inward,-1))
   if #poly<3 then return {} end
  end
 end
 local out={}
 for i=2,#poly-1 do triangle(poly[1],poly[i],poly[i+1],face.normal,t,out) end
 return out
end
function D.faceWedges(face: any,thick: number?)
 return D.pieceWedges({face},1,thick)
end
return D
