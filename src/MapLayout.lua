-- Pure, deterministic terrain and route plan. No Roblox instances or gameplay state.
-- Coordinates use the original spawn (-56,.5,-11); the complete plan follows it.
local L={Scale=1.9,FieldScale=1.4,Cell=8,Origin={-128,-104},Columns=26,Rows=26}
L.Routes={
 {name='Quartz approach',width=12,points={{-44,.34,-2},{-37,1.64,6},{-37,1.64,12}}},
 {name='Converter lane',width=10,points={{-66,.34,-24},{-78,.34,-29},{-85,.34,-29}}},
 {name='Ruby switchback',width=11,points={{-69,.34,1},{-85,5,10},{-107,9,18},{-107,13.14,26},{-107,13.14,34},{-99,13.14,34}}},
 {name='Grove loop',width=10,points={{-37,1.64,37},{-43,5.5,43},{-49,5.5,49},{-55,5.5,55},{-65,13.14,55},{-70,13.14,51},{-78,13.14,51}}},
 {name='Cobalt ascent',width=12,points={{-43,.34,-23},{-26,6,-32},{-24,12,-57},{-30,20.14,-74},{-43,20.14,-74}}},
 {name='High pass',width=11,points={{-55,20.14,-76},{-55,20.14,-85},{-31,24,-89},{-11,28,-86},{-10,30.14,-74},{-10,30.14,-65}}},
 {name='Emerald traverse',width=11,points={{13,30.14,-47},{28,33,-40},{42,36,-32},{44,40.14,-19},{44,40.14,-8}}},
 {name='Fern stair',width=11,points={{25,40.14,18},{25,40.14,29},{8,33,41},{-1,24,56},{-20,14,62},{-34,8,60},{-43,5.5,53},{-49,5.5,49}}},
 {name='Ruby overlook',width=9,points={{-101,13.14,56},{-112,20,67},{-100,27,78},{-79,34,77},{-66,34,77}}},
}
-- Forests are authored clusters, not a uniform scatter. The tall Ruby trees
-- surround the whole clearing and continue up the cliff's stepped shoulders.
L.Trees={
 {-116,32,27,2},{-117,47,30,2},{-112,57,24,2},{-106,69,28,2},{-98,71,30,2},
 {-82,68,25,2},{-72,68,29,2},{-65,45,28,2},{-67,32,24,2},{-82,21,23,2},
 {-96,22,28,2},{-115,16,24,2},{-122,65,29,2},{-114,80,27,2},{-96,89,25,2},{-75,89,29,2},
 {-49,26,15,1},{-53,38,19,1},{-45,6,17,1},{-21,0,17,1},{-5,14,20,1},{-1,31,16,1},
 {-12,47,18,1},{-34,65,20,1},{-49,66,16,1},{-67,14,15,1},{-78,-4,20,1},{-97,-8,21,1},
 {-105,-27,24,1},{-110,-44,19,1},{-95,-49,22,3},{-82,-67,23,3},{-80,-84,26,3},
 {-66,-88,22,3},{-48,-89,25,3},{-30,-91,20,3},{-22,-59,18,3},{-31,-21,18,3},
 {-16,-89,24,4},{2,-83,23,4},{20,-77,28,4},{25,-58,22,4},{-22,-35,20,4},{-7,-29,18,4},
 {34,-62,27,4},{48,-49,22,4},{58,-28,27,5},{66,-9,28,5},{62,13,24,5},
 {52,32,28,5},{34,32,25,5},{20,38,26,5},{13,54,24,5},{-2,67,20,5},
 {-109,-65,24,3},{-96,-88,23,3},{40,-87,24,4},{60,-67,26,4},{68,47,26,5},
 {-118,-1,22,1},{-111,0,18,1},{-11,77,21,1},{-46,82,19,2},{-61,86,26,2},
}
local function distance(x,z,a,b)
 local dx,dz=b[1]-a[1],b[3]-a[3]
 local t=math.clamp(((x-a[1])*dx+(z-a[3])*dz)/(dx*dx+dz*dz),0,1)
 local px,pz=a[1]+dx*t,a[3]+dz*t
 return math.sqrt((x-px)^2+(z-pz)^2),a[2]+(b[2]-a[2])*t
end
L.distance=distance
-- Round the horizontal AND vertical bend together. Straight overlapping slabs
-- and large flat joint discs create a raised lip; these short smooth chords do not.
function L.rounded(route)
 local result={route.points[1]}
 local function mix(a,b,t) return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t} end
 for i=2,#route.points-1 do
  local a,b,c=route.points[i-1],route.points[i],route.points[i+1]
  local la=math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2)
  local lc=math.sqrt((c[1]-b[1])^2+(c[3]-b[3])^2)
  local trim=math.min(route.width*.75,la*.28,lc*.28)
  local entry,exit=mix(b,a,trim/la),mix(b,c,trim/lc)
  table.insert(result,entry)
  for n=1,6 do local t=n/6;table.insert(result,mix(mix(entry,b,t),mix(b,exit,t),t)) end
 end
 table.insert(result,route.points[#route.points])
 return result
end
function L.plan(config: any,home: any): any
 home=home or {-56,.5,-11}
 local dx,dy,dz=home[1]+56,home[2]-.5,home[3]+11
 local p={fields={},routes={},terrain={},cells={},trees={},dx=dx,dy=dy,dz=dz}
 function p:point(x: number,z: number) return -56+(x+56)*L.Scale+dx,-11+(z+11)*L.Scale+dz end
 function p:biomePoint(id: number,x: number,z: number)
  local f=self.fields[id];local base=config[id].Offset
  local ox,oz=-56+base[1]/L.Scale,-11+base[3]/L.Scale
  return f.x+(x-ox)*L.FieldScale,f.z+(z-oz)*L.FieldScale
 end
 function p:hubClear(x,z,radius)
  local rx,rz=50+(radius or 0),46+(radius or 0)
  return ((x-home[1])/rx)^2+((z-home[3])/rz)^2>=1
 end
 for _,f in ipairs(config) do
  table.insert(p.fields,{x=home[1]+f.Offset[1],y=home[2]+f.Offset[2],z=home[3]+f.Offset[3],w=f.Size[1],d=f.Size[3],top=home[2]+f.Offset[2]+f.Size[2]/2})
 end
 for _,r in ipairs(L.Routes) do
  local route={name=r.name,width=r.width*1.2,points={}}
  for _,v in ipairs(r.points) do
   local x,z=p:point(v[1],v[3])
   -- Preserve a full-height connection into resized fields at route endpoints.
   for id,f in ipairs(config) do
    local fx,fz=-56+f.Offset[1]/L.Scale,-11+f.Offset[3]/L.Scale
    if math.abs(v[1]-fx)<f.Size[1]/L.FieldScale/2 and math.abs(v[3]-fz)<f.Size[3]/L.FieldScale/2 then x,z=p:biomePoint(id,v[1],v[3]);break end
   end
   table.insert(route.points,{x,v[2]+dy,z})
  end
  route.samples=L.rounded(route)
  table.insert(p.routes,route)
 end
 function p:routeClear(x,z,radius)
  for _,r in ipairs(self.routes) do for i=1,#r.samples-1 do
   if distance(x,z,r.samples[i],r.samples[i+1])<r.width/2+radius then return false end
  end end
  return true
 end
 function p:fieldClear(x,z,radius)
  for _,f in ipairs(self.fields) do if math.abs(x-f.x)<f.w/2+radius and math.abs(z-f.z)<f.d/2+radius then return false end end
  return true
 end
 local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
 local function mound(x,z,cx,cz,rx,rz,h)
  local d=math.sqrt(((x-cx)/rx)^2+((z-cz)/rz)^2)
  return h*(1-smooth((d-.15)/.85))
 end
 local function height(x,z)
  local h=math.max(
   mound(x,z,-99,78,37,31,51),mound(x,z,-117,47,21,39,30),mound(x,z,-73,86,22,23,40),
   mound(x,z,-64,-79,47,38,36),mound(x,z,-92,-86,24,25,47),
   mound(x,z,14,-86,47,35,58),mound(x,z,-3,-55,37,38,35),
   mound(x,z,57,-18,35,53,49),mound(x,z,35,12,39,37,43),mound(x,z,10,38,32,37,28))
  -- Small broad undulations break up regular silhouettes without noisy spikes.
  h=math.max(0,h+(math.sin(x*.089+z*.047)*2.8+math.cos(z*.13-x*.04)*1.8)*math.min(1,h/12))
  local edge=math.min(x-L.Origin[1],L.Origin[1]+L.Columns*L.Cell-x,z-L.Origin[2],L.Origin[2]+L.Rows*L.Cell-z)
  return h*smooth(edge/14)
 end
 local step=L.Cell*L.Scale
 local radius=step*math.sqrt(2)
 local vertices={}
 local function vertex(ix,iz) return vertices[iz*(L.Columns+1)+ix+1] end
 for iz=0,L.Rows do for ix=0,L.Columns do
  local rawX,rawZ=L.Origin[1]+ix*L.Cell,L.Origin[2]+iz*L.Cell
  local x,z=p:point(rawX,rawZ);local h=height(rawX,rawZ)+dy
  -- Broad level field shoulders give way to forested slopes, then outer cliffs.
  local nearest,biome=math.huge,1
  for id,f in ipairs(p.fields) do
   local fieldDistance=math.max(math.abs(x-f.x)-f.w/2,math.abs(z-f.z)-f.d/2,0)
   if fieldDistance<nearest then nearest=fieldDistance;biome=id end
   if fieldDistance<28 then
    local mix=smooth(fieldDistance/28)
    h=h*mix+math.max(0,f.top-2.1)*(1-mix)
   end
   -- Entire triangles that touch a clearing stay below its ore surface.
   if math.abs(x-f.x)<f.w/2+step+2 and math.abs(z-f.z)<f.d/2+step+2 then h=math.min(h,f.top-2.1) end
  end
  -- Conservative vertex clearance also clears triangle interiors between vertices.
  for _,r in ipairs(p.routes) do for i=1,#r.samples-1 do
   local d,y=distance(x,z,r.samples[i],r.samples[i+1])
   if d<r.width/2+radius+2 then
    local a,b=r.samples[i],r.samples[i+1]
    local gradient=math.abs(b[2]-a[2])/math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2)
    h=math.min(h,y-radius*gradient-.55)
   end
  end end
  if not p:hubClear(x,z,radius) then h=0 end
  if math.abs(x-(-86+dx))<12+radius and math.abs(z-(-37.5+dz))<12+radius then h=0 end
  local mx,mz=p:biomePoint(2,-88,66)
  if math.abs(x-mx)<12+step and math.abs(z-mz)<9+step then h=math.min(h,12.5+dy) end
  vertices[iz*(L.Columns+1)+ix+1]={x,math.max(0,h),z,biome}
 end end
 p.vertices=vertices
 for iz=0,L.Rows-1 do for ix=0,L.Columns-1 do
  local a,b,c,d=vertex(ix,iz),vertex(ix+1,iz),vertex(ix+1,iz+1),vertex(ix,iz+1)
  local cell={a=a,b=b,c=c,d=d,alternate=(ix+iz)%2==1,h=math.max(a[2],b[2],c[2],d[2]),biome=a[4]}
  p.cells[iz*L.Columns+ix+1]=cell
  if cell.h>.05 then
   cell.faces=cell.alternate and {{a,b,c},{a,c,d}} or {{a,b,d},{b,c,d}}
   table.insert(p.terrain,cell)
  end
 end end
 function p:surface(x: number,z: number)
  local ox,oz=self:point(L.Origin[1],L.Origin[2])
  local ix,iz=math.floor((x-ox)/step),math.floor((z-oz)/step)
  if ix<0 or ix>=L.Columns or iz<0 or iz>=L.Rows then return 0 end
  local c=self.cells[iz*L.Columns+ix+1]
  local u,v=(x-ox)/step-ix,(z-oz)/step-iz
  local a,b,d,e=c.a[2],c.b[2],c.c[2],c.d[2]
  if c.alternate then
   if v<=u then return a+(b-a)*(u-v)+(d-a)*v end
   return a+(d-a)*u+(e-a)*(v-u)
  end
  if u+v<=1 then return a+(b-a)*u+(e-a)*v end
  return d+(e-d)*(1-u)+(b-d)*(1-v)
 end
 -- Rock faces are short irregular clusters, never global horizontal bands.
 p.rocks={}
 for i,r in ipairs({{-119,72,16,11,12,17},{-99,91,22,14,15,-11},{-69,88,15,18,14,24},
  {-94,-86,21,14,17,-13},{-64,-99,24,12,15,19},{8,-95,23,18,17,-16},
  {39,-81,18,12,16,26},{60,-63,16,17,13,-19},{70,-16,15,18,17,12},{58,40,20,13,14,-23}}) do
  local x,z=p:point(r[1],r[2]);local clearance=math.sqrt(r[3]^2+r[5]^2)/2+2
  if p:hubClear(x,z,clearance) and p:routeClear(x,z,clearance) and p:fieldClear(x,z,clearance) then
   table.insert(p.rocks,{x=x,z=z,y=p:surface(x,z),w=r[3],h=r[4],d=r[5],yaw=r[6],biome=i<=3 and 2 or 3})
  end
 end
 -- One continuous native meadow. A 4-stud terrain raster follows the same
 -- open-land mask as the dense mesh version, with no isolated lawn squares.
 p.grass={}
 local function grassHeight(x,z)
  if math.abs(x-home[1])<24 and math.abs(z-home[3])<21 then return nil end
  if not p:fieldClear(x,z,4) or not p:routeClear(x,z,3) then return nil end
  local near=(x-home[1])^2+(z-home[3])^2<90^2
  for _,f in ipairs(p.fields) do
   if math.abs(x-f.x)<f.w/2+38 and math.abs(z-f.z)<f.d/2+38 then near=true;break end
  end
  if not near then return nil end
  local h=p:surface(x,z)
  local slope=math.max(math.abs(p:surface(x+.75,z)-h),math.abs(p:surface(x-.75,z)-h),math.abs(p:surface(x,z+.75)-h),math.abs(p:surface(x,z-.75)-h))
  if slope>.55 then return nil end
  return h
 end
 local ox,oz=p:point(L.Origin[1],L.Origin[2]);local edge=L.Columns*L.Cell*L.Scale
 for x=math.floor(ox/4)*4,ox+edge-4,4 do for z=math.floor(oz/4)*4,oz+edge-4,4 do
  local bx,bz=x+2,z+2;local h=grassHeight(bx,bz)
  if h then
   local tone=math.clamp(.45+.32*(math.sin(bx*.019+math.cos(bz*.011)*1.8)+math.cos(bz*.024-bx*.007)),0,1)
   local scatter=(math.sin(bx*17.13+bz*7.91)*43758.5453)%1
   -- Dry soil blends into grass, with grass blades retained across each band.
   local dry=scatter<math.max(0,tone-.55)*1.2
   table.insert(p.grass,{x=bx,z=bz,y=h,w=4,d=4,tone=tone,dry=dry})
  end
 end end
 for i,t in ipairs(L.Trees) do
  local x,z=p:biomePoint(t[4],t[1],t[2])
  if p:hubClear(x,z,t[3]*.3) and p:routeClear(x,z,3) and p:fieldClear(x,z,t[3]*.27) then
   table.insert(p.trees,{x=x,z=z,h=t[3],biome=t[4],ground=p:surface(x,z),yaw=i*.73})
  end
 end
 return p
end
return L
