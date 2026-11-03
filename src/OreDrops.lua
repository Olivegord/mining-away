-- Pure authoritative pickup trajectory. Uncollected world ore is owner/run bound;
-- only a server-confirmed arrival may put its conserved units in the backpack.
local O={MAGNET_RANGE=30,PICKUP_DISTANCE=2.2,SCATTER_TIME=.60,MAX_NODES=16,LIFETIME=18,FADE_SECONDS=5,GRAVITY=38}
function O.partition(units)
 local out={};local count=math.min(4,units)
 if count<1 then return out end
 for i=1,count do out[i]=math.floor(units/count)+(i<=units%count and 1 or 0) end
 return out
end
function O.scatter(index,serial)
 local angle=index*2.399963+serial*.73
 return math.cos(angle)*5.6,7.5+index*.65,math.sin(angle)*5.6
end
function O.expired(spawnAt,now) return now>=spawnAt+O.LIFETIME end
function O.fade(spawnAt,now) return math.clamp((now-spawnAt-(O.LIFETIME-O.FADE_SECONDS))/O.FADE_SECONDS,0,1) end
function O.step(s,target,dt,attract)
 if dt<=0 then return false end
 dt=math.min(dt,.05);s.age+=dt
 local dx,dy,dz=target.x-s.x,target.y-s.y,target.z-s.z
 local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
 local pulling=attract and s.age>=O.SCATTER_TIME and distance<=O.MAGNET_RANGE
 if pulling then
  -- Accelerate into a critically damped homing path, fast enough to catch a
  -- walking player. No orbiting an indefinitely moving pickup target.
  local speed=math.min(42,18+distance*1.6,math.sqrt(200*distance))
  local k=1-math.exp(-dt*12);local scale=speed/math.max(.001,distance)
  s.vx+=(dx*scale-s.vx)*k;s.vy+=(dy*scale-s.vy)*k;s.vz+=(dz*scale-s.vz)*k
 else
  local drag=math.exp(-dt*4);s.vx*=drag;s.vz*=drag;s.vy-=O.GRAVITY*dt
 end
 s.homing=pulling
 local x,y,z=s.x+s.vx*dt,s.y+s.vy*dt,s.z+s.vz*dt
 local impactSpeed=0
 if y<s.floor then
  -- Return the real downward contact once; resting floor clamps are silent.
  if s.vy < -2 then impactSpeed=-s.vy end
  y=s.floor;s.vy=math.abs(s.vy)>2 and math.abs(s.vy)*.26 or 0
 end
 -- Test the full segment as well as its end, so low-FPS homing cannot skip
 -- through the owner and enter a repeated overshoot loop.
 local ex,ey,ez=x-s.x,y-s.y,z-s.z;local length=ex*ex+ey*ey+ez*ez
 local t=length>0 and math.clamp((dx*ex+dy*ey+dz*ez)/length,0,1) or 0
 local near=math.sqrt((dx-ex*t)^2+(dy-ey*t)^2+(dz-ez*t)^2)
 s.x,s.y,s.z=x,y,z
 return pulling and near<=O.PICKUP_DISTANCE,impactSpeed
end
return O
