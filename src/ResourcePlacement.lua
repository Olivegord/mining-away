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
function P.sample(width,depth,radius,occupied,random,clear,preferred,compact)
 if not finite(width) or not finite(depth) or not finite(radius) or radius<=0 then return nil,0 end
 local halfX,halfZ=width*.5-radius-P.EDGE_MARGIN,depth*.5-radius-P.EDGE_MARGIN
 if halfX<0 or halfZ<0 then return nil,0 end
 -- The compact starter field needs room for four miners to work in
 -- parallel. Visit distinct sites in random order instead of letting
 -- early random placements strand empty space between them.
 local sites
 if compact and not preferred and halfX>.45 and halfZ>.45 then
  sites={}
  for i=0,15 do sites[i+1]=i end
 end
 local attempts=preferred and 1 or (sites and #sites or P.MAX_ATTEMPTS)
 for attempt=1,attempts do
  -- A grower's committed plan is rechecked exactly where it planted. It does
  -- not roll a larger rock later or silently move its successful animation.
  local x,z
  if preferred then x,z=preferred.x,preferred.z
  elseif sites then
   local index=math.min(#sites,math.floor(random(0,#sites))+1)
   local site=table.remove(sites,index)
   x=(site%4/3*2-1)*(halfX-.45)+random(-.45,.45)
   z=(math.floor(site/4)/3*2-1)*(halfZ-.45)+random(-.45,.45)
  else x,z=random(-halfX,halfX),random(-halfZ,halfZ) end
  if P.fits(x,z,width,depth,radius,occupied) and (not clear or clear(x,z,radius)) then
   return {x=x,z=z,radius=radius},attempt
  end
 end
 return nil,attempts
end
return P
