-- Pure bounded random placement. A full-size bounding sphere reserves every
-- yaw/tilt of the authored mesh, including its later fracture/settling poses.
-- All coordinates supplied here are in the field's horizontal local space.
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
-- Loose pockets anchor the bias without carving the bed into fixed plots.
-- Their spacing leaves broad gaps for the uniform share of the population.
function P.pockets(width,depth,random)
 local pockets={}
 for _=1,48 do
  local x,z=random(-width*.40,width*.40),random(-depth*.37,depth*.37)
  local clear=true
  for _,other in ipairs(pockets) do
   if (x-other.x)^2+(z-other.z)^2<18^2 then clear=false;break end
  end
  if clear then
   table.insert(pockets,{x=x,z=z,radius=random(6.5,10.5)})
   if #pockets==10 then break end
  end
 end
 return pockets
end
function P.sample(width: number,depth: number,radius: number,occupied,random,clear,preferred,reference,referenceGap,
 bounds: {minX: number,maxX: number,minZ: number,maxZ: number}?, pockets)
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
 local attempts=preferred and 1 or P.MAX_ATTEMPTS
 for attempt=1,attempts do
  -- A grower's committed plan is rechecked exactly where it planted.
  local x,z
  if preferred then
   x,z=preferred.x,preferred.z
  elseif pockets and #pockets>0 and attempt<=8 and random(0,1)<.78 then
   local center=pockets[math.floor(random(0,#pockets))+1] or pockets[#pockets]
   local angle=random(0,math.pi*2)
   local distance=math.sqrt(random(0,1))*center.radius
   x,z=center.x+math.cos(angle)*distance,center.z+math.sin(angle)*distance
  else
   x,z=random(minX,maxX),random(minZ,maxZ)
  end
  local fits
  if reference then fits=fitsReference(x,z,halfX,halfZ,radius,occupied,referenceGap or 2)
  else fits=P.fits(x,z,width,depth,radius,occupied) end
  if fits and (not clear or clear(x,z,radius)) then
   return {x=x,z=z,radius=radius},attempt
  end
 end
 return nil,attempts
end
return P
