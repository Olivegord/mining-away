-- Pure authoritative pickup trajectory. Uncollected world ore is owner/run bound;
-- only a server-confirmed arrival may put its conserved units in the backpack.
local O={MAGNET_RANGE=6,CARGO_REACH=9,PICKUP_DISTANCE=2.2,SCATTER_TIME=.72,MAX_NODES=16,LIFETIME=24,CARGO_MAX_AGE=180,GRAVITY=70,
 GEM_GRAVITY=178,GEM_CONTACT_HOLD=.24,AIR_DRAG=.9,GROUND_DRAG=18,RESTITUTION=.22}
O.BREAK_DELAY=.11
O.REWARD_DELAY=.135
function O.partition(units,limit)
 local out={};local count=math.min(4,units,limit or 4)
 if count<1 then return out end
 for i=1,count do out[i]=math.floor(units/count)+(i<=units%count and 1 or 0) end
 return out
end
function O.scatter(index,serial)
 local angle=index*2.399963+serial*.73
 -- Keep fragments in their usual pickup area with a higher, steeper arc.
 local speed=6.2+(serial%5)*.4
 return math.cos(angle)*speed,35+index*1.55,math.sin(angle)*speed
end
function O.launch(index,serial,sx,sy,sz)
 local vx,vy,vz=O.scatter(index,serial)
 local speed=math.sqrt(vx*vx+vz*vz)
 -- Outside the whole rotated footprint, above the top. The initial outward
 -- arc clears even a large carved boulder before homing is allowed to begin.
 local radius=math.sqrt(sx*sx+sz*sz)*.5+.4
 return vx/speed*radius,sy*.5+.35,vz/speed*radius,vx,vy,vz
end
-- A clear rise, apex and fall before the item can be collected.
function O.cargoLaunch(serial,block)
 local angle=block and .20 or serial*2.399963
 local speed=block and 5.3 or 7.3+(serial%3)*.35
 return math.cos(angle)*speed,block and 16 or 55+(serial%4)*.8,math.sin(angle)*speed
end
-- The server and observer sample the same flight and exact point of contact.
function O.rawArc(x,y,z,vx,vy,vz,floor)
 local speed=math.sqrt(vy*vy+2*O.GEM_GRAVITY*math.max(0,y-floor))
 local contact=(vy+speed)/O.GEM_GRAVITY
 local travel=(1-math.exp(-O.AIR_DRAG*contact))/O.AIR_DRAG
 return {x=x,y=math.max(y,floor),z=z,vx=vx,vy=vy,vz=vz,floor=floor,contact=contact,
  landX=x+vx*travel,landZ=z+vz*travel,speed=speed}
end
function O.rawPose(a,age)
 age=math.max(0,age)
 if age<a.contact then
  local decay=math.exp(-O.AIR_DRAG*age);local travel=(1-decay)/O.AIR_DRAG
  return a.x+a.vx*travel,a.y+a.vy*age-.5*O.GEM_GRAVITY*age*age,a.z+a.vz*travel,a.vx*decay,a.vy-O.GEM_GRAVITY*age,a.vz*decay
 end
 return a.landX,a.floor,a.landZ,0,0,0
end
function O.deadline(spawnAt,returnUntil) return math.max(spawnAt+O.LIFETIME,returnUntil or 0) end
function O.expired(spawnAt,now,returnUntil) return now>=O.deadline(spawnAt,returnUntil) end
function O.sellTripDeadline(spawnAt,now,walkingDistance,returnUntil)
 -- Default walking is 16 studs/s. Leave time for turns, unloading and the counter.
 local trip=math.min(O.CARGO_MAX_AGE-10,walkingDistance/14+20)
 if now+trip<=O.deadline(spawnAt,returnUntil) then return nil end
 local extended=math.min(spawnAt+O.CARGO_MAX_AGE,now+trip+10)
 if extended>O.deadline(spawnAt,returnUntil) then return extended end
 return nil
end
local function horizontal(s,dt,drag)
 local decay=math.exp(-drag*dt);local travel=(1-decay)/drag
 s.x+=s.vx*travel;s.z+=s.vz*travel;s.vx*=decay;s.vz*=decay
 -- Ground friction leaves less than .003 studs of travel at this speed.
 if drag==O.GROUND_DRAG and s.vx*s.vx+s.vz*s.vz<.05^2 then s.vx=0;s.vz=0 end
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
   s.landed=true;s.firstLandedAge=s.firstLandedAge or s.age;s.y=s.floor;s.vy=0
   if s.arc then s.vx=0;s.vz=0 end
   if s.vx~=0 or s.vz~=0 then horizontal(s,dt,O.GROUND_DRAG) end
   break
  end
  local contact=(s.vy+math.sqrt(s.vy*s.vy+2*O.GRAVITY*height))/O.GRAVITY
  local span=math.min(dt,contact)
  horizontal(s,span,O.AIR_DRAG)
  s.y+=s.vy*span-.5*O.GRAVITY*span*span;s.vy-=O.GRAVITY*span;dt-=span
  if contact>span then break end
  local speed=math.max(0,-s.vy)
  if speed>2 then impact=math.max(impact,speed) end
  s.landed=true;s.firstLandedAge=s.firstLandedAge or s.age;s.y=s.floor
  if s.arc then s.vx=0;s.vy=0;s.vz=0;break end
  s.vy=speed>2 and speed*(s.raw and .10 or O.RESTITUTION) or 0
  s.vx*=.62;s.vz*=.62
 end
 return impact
end
function O.step(s,target,dt,attract,magnetRange)
 if dt<=0 then return false end
 dt=math.min(dt,.05);s.age+=dt
 local dx,dy,dz=target.x-s.x,target.y-s.y,target.z-s.z
 local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
 local collectAt=s.raw and .40 or O.SCATTER_TIME
 if s.arc or s.raw then
  collectAt=math.max(collectAt,(s.firstLandedAge or 0)+(s.arc and O.GEM_CONTACT_HOLD or .075))
 end
 local pulling=attract and s.landed==true and s.age>=collectAt and distance<=(magnetRange or O.MAGNET_RANGE)
 local oldX,oldY,oldZ=s.x,s.y,s.z
 local impactSpeed=0
 if pulling then
  if s.arc then s.arcEnded=true end
  -- Accelerate into a critically damped homing path, fast enough to catch a
  -- walking player. No orbiting an indefinitely moving pickup target.
  local speed=math.min(42,18+distance*1.6,math.sqrt(200*distance))
  local k=1-math.exp(-dt*12);local scale=speed/math.max(.001,distance)
  s.vx+=(dx*scale-s.vx)*k;s.vy+=(dy*scale-s.vy)*k;s.vz+=(dz*scale-s.vz)*k
  s.x+=s.vx*dt;s.y+=s.vy*dt;s.z+=s.vz*dt
  if s.y<s.floor then s.y=s.floor;s.vy=math.max(0,s.vy) end
 elseif s.arc and not s.arcEnded then
  s.x,s.y,s.z,s.vx,s.vy,s.vz=O.rawPose(s.arc,s.age)
  if s.age>=s.arc.contact and not s.landed then
   s.landed=true;s.firstLandedAge=s.arc.contact;impactSpeed=s.arc.speed
  end
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
