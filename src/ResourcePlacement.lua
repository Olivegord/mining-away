-- Bounded resource placement in the field's horizontal local space.
local P={MAX_ATTEMPTS=18,RETRY_SECONDS=2,EDGE_MARGIN=.75,GAP=.65}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function P.radius(x,y,z,kind,upright)
 if not finite(x) or not finite(y) or not finite(z) or x<=0 or y<=0 or z<=0 then return nil end
 -- The starter crystals stay upright as they turn and shrink, so their
 -- horizontal diagonal is sufficient. Other rocks keep the full reservation.
 local radius=math.sqrt(x*x+z*z+(upright and 0 or y*y))*.5
 -- A shell reveals four shard centers four studs away. Reserve those actual
 -- future footprints too, so a small shell cannot grow shards into neighbors.
 if kind=='Geode' then radius=math.max(radius,4+math.sqrt(3)*(70/25*.8)*.5) end
 return radius
end
function P.leaningRadius(x,y,z,pitch,roll)
 -- Yaw can change during a fracture. The furthest horizontal corner keeps
 -- the same radius through any yaw, so project the fixed lean just once.
 local c=math.cos(pitch)
 local a,b,d=x*c*math.sin(roll),y*c*math.cos(roll),z*math.sin(pitch)
 local vertical=math.min(math.abs(b+a+d),math.abs(b+a-d),math.abs(b-a+d),math.abs(b-a-d))
 return math.sqrt(x*x+y*y+z*z-vertical*vertical)*.5
end
function P.fits(x,z,width,depth,radius,occupied)
 if not finite(x) or not finite(z) or not finite(width) or not finite(depth) or not finite(radius) or radius<=0 then return false end
 local margin=radius+P.EDGE_MARGIN
 if math.abs(x)+margin>width*.5 or math.abs(z)+margin>depth*.5 then return false end
 for _,other in ipairs(occupied or {}) do
  if finite(other.x) and finite(other.z) and finite(other.radius) and other.radius>0 then
   local dx,dz=x-other.x,z-other.z;local gap=radius+other.radius+P.GAP
   if dx*dx+dz*dz<gap*gap then return false end
  end
 end
 return true
end
local function fitsReference(x,z,halfX,halfZ,radius,occupied,gap)
 if not finite(x) or not finite(z) or x%1~=0 or z%1~=0 or math.abs(x)>halfX or math.abs(z)>halfZ then return false end
 for _,other in ipairs(occupied or {}) do
  local dx,dz=x-other.x,z-other.z
  -- The starter patch keeps Mining Away's spacing. Larger deposits reserve
  -- room for both meshes to turn when they fracture.
  local separation=other.radius and radius+other.radius or gap
  if dx*dx+dz*dz<separation*separation then return false end
 end
 return true
end
-- Small connected gaps leave more than one way through each 216 x 64 bed.
-- Their entrances flank the authored rock masses at the shared boundaries.
local entrances={{-48,37},{-60,24},{-22,78},{-70,26},{-53,58},{-22,69}}
P.seamOutcrops={
 {x=-19,halfX=22,halfZ=9},
 {x=30,halfX=23,halfZ=10},
 {x=-26,halfX=23,halfZ=10},
 {x=1,halfX=23,halfZ=10},
}
local beds={
 {
  gaps={{{-65,-15},{-47,3},{-63,20}},{{51,-17},{32,-3},{15,16}}},
  clumps={{-88,-9,20,15,'boulder'},{-89,15,15,12},{-48,-21,14,9},{-28,-6,17,14},
   {-12,9,19,11,'spire'},{3,-16,16,12,'spire'},{49,20,15,9},{46,1,12,12},{72,8,22,14,'boulder'},{88,-16,17,11}},
 },
 {
  gaps={{{-72,-17},{-49,-5},{-35,13}},{{39,-18},{57,-6},{67,14}}},
  clumps={{-88,8,19,18,'boulder'},{-59,20,13,10},{-40,-15,16,10},{-8,-11,21,12,'spire'},
   {10,7,20,12,'boulder'},{-94,-18,13,8},{36,14,16,10},{35,-5,15,14},{65,-22,15,8},{92,-9,12,15,'spire'},{91,16,13,12}},
 },
 {
  gaps={{{-34,-17},{-17,-2},{-43,13}},{{90,-12},{63,5},{36,19}}},
  clumps={{-89,-5,15,20,'boulder'},{-64,-17,17,10,'spire'},{-51,-4,12,12},{-25,19,13,9},
   {-87,18,13,10},{5,3,17,17,'boulder'},{25,-15,19,10},{35,1,17,11},{51,-16,15,12},{67,20,16,9},{91,17,13,12,'spire'}},
 },
 {
  gaps={{{-53,-17},{-70,-4},{-62,12}},{{40,-20},{18,0},{48,16}}},
  clumps={{-90,-14,16,11,'boulder'},{-88,16,16,13},{-48,14,16,13},{-29,1,18,15,'spire'},
   {0,-12,17,10,'spire'},{-11,14,11,11},{14,11,16,14},{62,-13,18,11},{82,4,21,15,'boulder'},{91,21,13,9}},
 },
 {
  gaps={{{-71,-17},{-57,5},{-41,20}},{{38,-18},{55,1},{68,17}}},
  clumps={{-89,0,17,20,'boulder'},{-70,20,14,9},{-33,-12,17,11,'spire'},{-31,7,14,13},
   {-4,23,16,9},{17,9,17,14,'boulder'},{42,17,14,11},{80,12,14,13},{86,-13,17,12,'spire'}},
 },
}
local function addPath(segments,points,scaleX,scaleZ,halfWidth)
 for i=2,#points do
  local a,b=points[i-1],points[i]
  local dx,dz=(b[1]-a[1])*scaleX,(b[2]-a[2])*scaleZ
  table.insert(segments,{x=a[1]*scaleX,z=a[2]*scaleZ,dx=dx,dz=dz,lengthSquared=dx*dx+dz*dz,halfWidth=halfWidth})
 end
end
function P.crystalLayout(width,depth,zone)
 zone=if beds[zone] then zone else 1
 local spec=beds[zone]
 local scaleX,scaleZ=width/216,depth/64
 local layout={clumps={},landmarks={},paths={},ridges={}}
 for side,bends in ipairs(spec.gaps) do
  local route={{entrances[zone][side],-32},table.unpack(bends)}
  table.insert(route,{entrances[zone+1][side],32})
  addPath(layout.paths,route,scaleX,scaleZ,2.5)
 end
 for side=-1,1,2 do
  local ridge=P.seamOutcrops[zone+(side-1)/2]
  if ridge then
   table.insert(layout.ridges,{x=ridge.x*scaleX,z=depth*.5*side,halfX=ridge.halfX*scaleX,halfZ=ridge.halfZ*scaleZ})
  end
 end
 for _,site in ipairs(spec.clumps) do
  local center={x=site[1]*scaleX,z=site[2]*scaleZ,wide=site[3]*scaleX,deep=site[4]*scaleZ,shape=site[5]}
  table.insert(layout.clumps,center)
  if center.shape then table.insert(layout.landmarks,center) end
 end
 return layout
end
function P.crystalPathClear(layout,x,z,radius)
 for _,ridge in ipairs(layout.ridges) do
  local dx=math.max(0,math.abs(x-ridge.x)-ridge.halfX)
  local dz=math.max(0,math.abs(z-ridge.z)-ridge.halfZ)
  if dx*dx+dz*dz<radius*radius then return false end
 end
 for _,segment in ipairs(layout.paths) do
  local dx,dz=x-segment.x,z-segment.z
  local t=math.clamp((dx*segment.dx+dz*segment.dz)/segment.lengthSquared,0,1)
  local reach=segment.halfWidth+radius
  if (dx-t*segment.dx)^2+(dz-t*segment.dz)^2<reach*reach then return false end
 end
 return true
end
function P.sample(width: number,depth: number,radius: number,occupied,random,clear,preferred,reference,referenceGap,
 bounds: {minX: number,maxX: number,minZ: number,maxZ: number}?, layout)
 if not finite(width) or not finite(depth) or not finite(radius) or radius<=0 then return nil,0 end
 local halfX,halfZ=width*.5-radius-P.EDGE_MARGIN,depth*.5-radius-P.EDGE_MARGIN
 if reference then halfX,halfZ=math.floor(width*.5),math.floor(depth*.5) end
 if halfX<0 or halfZ<0 then return nil,0 end
 local minX,maxX,minZ,maxZ=-halfX,halfX,-halfZ,halfZ
 if bounds and not preferred then
  local lowX,highX=math.max(minX,bounds.minX),math.min(maxX,bounds.maxX)
  local lowZ,highZ=math.max(minZ,bounds.minZ),math.min(maxZ,bounds.maxZ)
  minX=if reference then math.ceil(lowX) else lowX
  maxX=if reference then math.floor(highX) else highX
  minZ=if reference then math.ceil(lowZ) else lowZ
  maxZ=if reference then math.floor(highZ) else highZ
  if minX>maxX or minZ>maxZ then return nil,0 end
 end
 local clumps={}
 local shoulder=1.34
 if layout and not preferred then
  for _,center in ipairs(layout.clumps) do
   if center.x+center.wide*shoulder>=minX and center.x-center.wide*shoulder<=maxX
    and center.z+center.deep*shoulder>=minZ and center.z-center.deep*shoulder<=maxZ then
    table.insert(clumps,center)
   end
  end
 end
 local first=#clumps>0 and math.min(#clumps,math.floor(random(0,#clumps))+1) or 1
 local attempts=preferred and 1 or (layout and 42 or P.MAX_ATTEMPTS)
 for attempt=1,attempts do
  -- A grower's committed plan is rechecked exactly where it planted.
  local x,z
  if preferred then
   x,z=preferred.x,preferred.z
  elseif #clumps>0 and (not bounds or attempt<=28) then
   local center=clumps[(first+attempt-2)%#clumps+1]
   local angle=random(0,math.pi*2)
   local distance=if attempt<=30 then random(0,1) else random(0,1)^.74*shoulder
   x,z=center.x+math.cos(angle)*distance*center.wide,center.z+math.sin(angle)*distance*center.deep
  elseif not layout or bounds then
   x,z=random(minX,maxX),random(minZ,maxZ)
  else
   return nil,attempt-1
  end
  if finite(x) and finite(z) and x>=minX and x<=maxX and z>=minZ and z<=maxZ
   and (not layout or P.crystalPathClear(layout,x,z,radius)) then
   local fits=if reference then fitsReference(x,z,halfX,halfZ,radius,occupied,referenceGap or 2)
    else P.fits(x,z,width,depth,radius,occupied)
   if fits and (not clear or clear(x,z,radius)) then return {x=x,z=z,radius=radius},attempt end
  end
 end
 return nil,attempts
end
return P
