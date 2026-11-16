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
-- Two connected walks divide each bed into four banks. Each bank has two
-- Voronoi sites, with a narrow spur along their shared cell boundary.
function P.crystalLayout(width,depth,fieldId)
 local turn=fieldId%2==0 and 1 or -1
 local drift=(fieldId%5-2)*.008
 local layout={clumps={},spurs={},bendX=width*.24,bendZ=math.min(4,depth*.065)*turn}
 for _,side in ipairs({-1,1}) do
  layout.spurs[side]={}
  for _,bank in ipairs({-1,1}) do
   local stagger=bank*turn
   local inner={x=width*(side*.155+stagger*.018+drift),z=depth*(bank*.275-side*.042),
    wide=width*.096,deep=depth*.16}
   local outer={x=width*(side*.365-stagger*.014+drift),z=depth*(bank*.325+side*.035),
    wide=width*.089,deep=depth*.14}
   table.insert(layout.clumps,inner)
   table.insert(layout.clumps,outer)
   local dx,dz=outer.x-inner.x,outer.z-inner.z
   local length=math.sqrt(dx*dx+dz*dz)
   layout.spurs[side][bank]={x=(inner.x+outer.x)*.5,z=(inner.z+outer.z)*.5,nx=dx/length,nz=dz/length}
  end
 end
 return layout
end
function P.crystalPathClear(layout,x,z,radius)
 local halfPath=4.5
 local along=math.clamp(x/layout.bendX,-1,1)
 local crosswalkZ=layout.bendZ*along
 local slope=math.abs(x)<=layout.bendX+radius+halfPath and layout.bendZ/layout.bendX or 0
 if math.abs(x)<halfPath+radius or math.abs(z-crosswalkZ)<(halfPath+radius)*math.sqrt(1+slope*slope) then return false end
 local spur=layout.spurs[x<0 and -1 or 1][z<crosswalkZ and -1 or 1]
 return math.abs((x-spur.x)*spur.nx+(z-spur.z)*spur.nz)>=1.8+radius
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
   if center.x+center.wide>=minX and center.x-center.wide<=maxX
    and center.z+center.deep>=minZ and center.z-center.deep<=maxZ then
    table.insert(clumps,center)
   end
  end
 end
 local first=#clumps>0 and math.min(#clumps,math.floor(random(0,#clumps))+1) or 1
 local attempts=preferred and 1 or (layout and 28 or P.MAX_ATTEMPTS)
 for attempt=1,attempts do
  -- A grower's committed plan is rechecked exactly where it planted.
  local x,z
  if preferred then
   x,z=preferred.x,preferred.z
  elseif #clumps>0 and attempt<=20 then
   local center=clumps[(first+attempt-2)%#clumps+1]
   local angle=random(0,math.pi*2)
   local distance=random(0,1)^.68*(attempt<=12 and 1 or 1.20)
   x,z=center.x+math.cos(angle)*distance*center.wide,center.z+math.sin(angle)*distance*center.deep
  else
   x,z=random(minX,maxX),random(minZ,maxZ)
  end
  local fits
  if reference then fits=fitsReference(x,z,halfX,halfZ,radius,occupied,referenceGap or 2)
  else fits=P.fits(x,z,width,depth,radius,occupied) end
  if fits and x>=minX and x<=maxX and z>=minZ and z<=maxZ
   and (not layout or P.crystalPathClear(layout,x,z,radius)) and (not clear or clear(x,z,radius)) then
   return {x=x,z=z,radius=radius},attempt
  end
 end
 return nil,attempts
end
return P
