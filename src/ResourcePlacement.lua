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
-- Coordinates are authored in the 216 x 64 bed and scaled with the actual
-- part. Consecutive beds share one entrance. The clusters have distinct
-- shapes, and the branch bends through a different part of each bed.
local entrances={-10,10,-17,14,-18,12}
local beds={
 {
  walk={{-13,-18},{4,-4},{20,13}},
  branch={{4,-4},{31,-2},{55,10},{65,32}},
  clumps={{-87,-14,18,13,'boulder'},{-72,14,26,15},{-48,3,19,15},{-36,-17,18,10,'spire'},
   {-21,20,18,10},{30,-19,19,9},{54,-18,19,11,'boulder'},{86,-3,16,20},{88,19,15,10,'spire'}},
 },
 {
  walk={{28,-18},{12,-8},{-14,8}},
  branch={{12,-8},{-15,-9},{-37,-20},{-66,-32}},
  clumps={{-87,4,19,23},{-80,-19,17,10,'spire'},{-60,16,21,14,'boulder'},{-45,-3,15,11},
   {-29,-24,12,6},{13,15,18,14},{54,4,21,16,'spire'},{72,-17,24,10,'boulder'},{89,17,16,12}},
 },
 {
  walk={{-29,-20},{-21,-5},{3,13}},
  branch={{-21,-5},{-46,0},{-67,15},{-108,24}},
  clumps={{-88,-7,16,20,'boulder'},{-65,-14,14,13},{-60,24,14,6},{-32,15,12,12,'spire'},
   {4,-20,14,8},{41,-7,18,16,'boulder'},{58,16,21,13},{82,-14,17,10,'spire'},{93,10,11,18}},
 },
 {
  walk={{29,-19},{12,-4},{-11,13}},
  branch={{12,-4},{39,2},{62,3},{89,32}},
  clumps={{-89,13,15,16,'spire'},{-76,-15,18,12},{-53,-2,17,20,'boulder'},{-27,-15,17,12},
   {9,22,15,8},{37,18,18,11,'spire'},{55,-15,20,12},{82,-9,21,15,'boulder'},{96,11,10,10}},
 },
 {
  walk={{-22,-16},{-3,1},{29,13}},
  branch={{-3,1},{13,-12},{44,-13},{72,-32}},
  clumps={{-88,-13,16,14,'boulder'},{-72,12,23,17},{-49,-10,15,18,'spire'},{-21,19,16,10},
   {9,-25,14,6},{17,21,14,10},{52,9,16,19,'spire'},{78,-4,24,16,'boulder'},{93,19,13,11}},
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
 local spec=beds[zone] or beds[1]
 local scaleX,scaleZ=width/216,depth/64
 local layout={clumps={},landmarks={},paths={}}
 local walk={{entrances[zone] or entrances[1],-32},table.unpack(spec.walk)}
 table.insert(walk,{entrances[zone+1] or entrances[2],32})
 addPath(layout.paths,walk,scaleX,scaleZ,6)
 addPath(layout.paths,spec.branch,scaleX,scaleZ,4)
 for _,site in ipairs(spec.clumps) do
  local center={x=site[1]*scaleX,z=site[2]*scaleZ,wide=site[3]*scaleX,deep=site[4]*scaleZ,shape=site[5]}
  table.insert(layout.clumps,center)
  if center.shape then table.insert(layout.landmarks,center) end
 end
 return layout
end
function P.crystalPathClear(layout,x,z,radius)
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
 if layout and not preferred then
  for _,center in ipairs(layout.clumps) do
   if center.x+center.wide*1.22>=minX and center.x-center.wide*1.22<=maxX
    and center.z+center.deep*1.22>=minZ and center.z-center.deep*1.22<=maxZ then
    table.insert(clumps,center)
   end
  end
 end
 local first=#clumps>0 and math.min(#clumps,math.floor(random(0,#clumps))+1) or 1
 local attempts=preferred and 1 or (layout and 36 or P.MAX_ATTEMPTS)
 for attempt=1,attempts do
  -- A grower's committed plan is rechecked exactly where it planted.
  local x,z
  if preferred then
   x,z=preferred.x,preferred.z
  elseif #clumps>0 and (not bounds or attempt<=28) then
   local center=clumps[(first+attempt-2)%#clumps+1]
   local angle=random(0,math.pi*2)
   local distance=if attempt<=26 then random(0,1) else random(0,1)^.74*1.22
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
