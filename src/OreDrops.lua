-- Pure authoritative pickup trajectory. Uncollected world ore is owner/run bound;
-- only a server-confirmed arrival may put its conserved units in the backpack.
local O={MAGNET_RANGE=30,PICKUP_DISTANCE=2.2,SCATTER_TIME=.60,MAX_NODES=16,LIFETIME=18,FADE_SECONDS=5,GRAVITY=38,
 AIR_DRAG=.9,GROUND_DRAG=14,RESTITUTION=.28}
function O.partition(units)
 local out={};local count=math.min(4,units)
 if count<1 then return out end
 for i=1,count do out[i]=math.floor(units/count)+(i<=units%count and 1 or 0) end
 return out
end
function O.scatter(index,serial)
 local angle=index*2.399963+serial*.73
 local speed=4.8+(serial%5)*.45
 return math.cos(angle)*speed,7.5+index*.65,math.sin(angle)*speed
end
function O.expired(spawnAt,now) return now>=spawnAt+O.LIFETIME end
function O.fade(spawnAt,now) return math.clamp((now-spawnAt-(O.LIFETIME-O.FADE_SECONDS))/O.FADE_SECONDS,0,1) end
local function horizontal(s,dt,drag)
 local decay=math.exp(-drag*dt);local travel=(1-decay)/drag
 s.x+=s.vx*travel;s.z+=s.vz*travel;s.vx*=decay;s.vz*=decay
end
local function fall(s,dt)
 -- Integrate the flight up to its actual contact time, then consume the rest
 -- of the step after restitution. Landing height/energy no longer depends on
 -- which server tick happened to cross the floor.
 local impact=0
 for _=1,3 do
  if dt<=1e-6 then break end
  local height=math.max(0,s.y-s.floor)
  if height<1e-5 and s.vy<=.8 then
   s.y=s.floor;s.vy=0;horizontal(s,dt,O.GROUND_DRAG);break
  end
  local contact=(s.vy+math.sqrt(s.vy*s.vy+2*O.GRAVITY*height))/O.GRAVITY
  local span=math.min(dt,contact)
  horizontal(s,span,O.AIR_DRAG)
  s.y+=s.vy*span-.5*O.GRAVITY*span*span;s.vy-=O.GRAVITY*span;dt-=span
  if contact>span then break end
  local speed=math.max(0,-s.vy)
  if speed>2 then impact=math.max(impact,speed) end
  s.y=s.floor;s.vy=speed>2 and speed*O.RESTITUTION or 0
  s.vx*=.62;s.vz*=.62
 end
 return impact
end
function O.step(s,target,dt,attract)
 if dt<=0 then return false end
 dt=math.min(dt,.05);s.age+=dt
 local dx,dy,dz=target.x-s.x,target.y-s.y,target.z-s.z
 local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
 local pulling=attract and s.age>=O.SCATTER_TIME and distance<=O.MAGNET_RANGE
 local oldX,oldY,oldZ=s.x,s.y,s.z
 local impactSpeed=0
 if pulling then
  -- Accelerate into a critically damped homing path, fast enough to catch a
  -- walking player. No orbiting an indefinitely moving pickup target.
  local speed=math.min(42,18+distance*1.6,math.sqrt(200*distance))
  local k=1-math.exp(-dt*12);local scale=speed/math.max(.001,distance)
  s.vx+=(dx*scale-s.vx)*k;s.vy+=(dy*scale-s.vy)*k;s.vz+=(dz*scale-s.vz)*k
  s.x+=s.vx*dt;s.y+=s.vy*dt;s.z+=s.vz*dt
  if s.y<s.floor then s.y=s.floor;s.vy=math.max(0,s.vy) end
 else
  impactSpeed=fall(s,dt)
 end
 s.homing=pulling
 -- Test the full segment as well as its end, so low-FPS homing cannot skip
 -- through the owner and enter a repeated overshoot loop.
 local ex,ey,ez=s.x-oldX,s.y-oldY,s.z-oldZ;local length=ex*ex+ey*ey+ez*ez
 local t=length>0 and math.clamp((dx*ex+dy*ey+dz*ez)/length,0,1) or 0
 local near=math.sqrt((dx-ex*t)^2+(dy-ey*t)^2+(dz-ez*t)^2)
 return pulling and near<=O.PICKUP_DISTANCE,impactSpeed
end
return O
