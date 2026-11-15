-- Original 2023 motion and crystal timing, with explicit elapsed-time correction.
-- Scalar helpers stay engine-independent so the original equations are testable.
local F = {FollowHeight=3.2,ReferenceFollowHeight=7,ReferenceCrystalPivot=3,WorkHeight=10,WorkClearance=5,
 SwarmSpacing=5,SwarmRadius=22,SwarmNear=7,SwarmMaxOffset=2.2,SwarmForce=36}
function F.alpha(a, dt)
 if type(dt)~='number' or dt~=dt or dt<=0 then return 0 end
 return 1-(1-a)^(60*dt)
end
function F.turnAlpha(dt) return F.alpha(.1,dt) end
function F.approachScalar(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position
 local distance=math.abs(delta)
 if distance<1e-5 then return goal end
 local step=math.min(distance*F.alpha(.03,dt),math.max(0,maxStep60)*60*dt,distance)
 return position+(delta<0 and -step or step)
end
function F.approach(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position;local distance=delta.Magnitude
 if distance<1e-5 then return goal end
 local step=math.min(distance*F.alpha(.03,dt),math.max(0,maxStep60)*60*dt,distance)
 return position+delta/distance*step
end
-- Shared by the server and every observer. No extra thrust or braking layer.
function F.referenceFlight(position,goal,maxStep60,dt,correction)
 if dt<=0 then return position,Vector3.zero end
 local nextPosition=F.approach(position,goal,maxStep60,dt)
 if correction then
  local step=nextPosition-position+correction*dt
  local cap=maxStep60*60*dt
  nextPosition=position+(step.Magnitude>cap and step.Unit*cap or step)
 end
 return nextPosition,(nextPosition-position)/dt
end
function F.approachWork(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position;local distance=delta.Magnitude
 if distance>16 then return F.approach(position,goal,maxStep60,dt) end
 if distance<1e-5 then return goal end
 -- A short hop between nearby jobs should settle promptly. The server and
 -- every observer use this same bounded ease, never a cosmetic teleport.
 local step=math.min(distance*F.alpha(.065,dt),math.max(0,maxStep60)*1.45*60*dt,distance)
 return position+delta/distance*step
end
-- Original crystals snap to a new facing on each crack. Seed + stage give
-- the same pose to the server collider, current observers and late joiners.
function F.rockYaw(seed,stage,turn,reference)
 local yaw=reference and 0 or (seed*.01)%(2*math.pi)
 if turn then
  for i=1,stage do
   local roll=(seed*131+i*271)%83
   yaw+=math.rad(55+roll)*((seed+i)%2==0 and 1 or -1)
  end
 end
 return yaw
end
function F.groundedRockFrame(position,size,ground,stage,seed,turn,reference,steady)
 local center=Vector3.new(position.X,ground+size.Y*.5-.06,position.Z)
 local yaw=steady and F.rockYaw(seed,0,false,false) or F.rockYaw(seed,stage,turn,reference)
 return CFrame.new(center)*CFrame.Angles(0,yaw,0),ground+size.Y-.06
end
function F.inertialApproach(position,goal,velocity,maxStep60,dt,work,correction,response,mass,steering)
 -- Retain the original capped, distance-eased destination rule, but approach
 -- its requested velocity with thrust. New jobs, reversals and speed upgrades
 -- cannot replace momentum in a single frame. Substeps keep braking consistent
 -- across server ticks and 30/60/144 Hz observers.
 velocity=velocity or Vector3.zero
 if type(dt)~='number' or dt~=dt or dt<=0 then return position,velocity end
 local elapsed=math.min(dt,.1);local steps=math.max(1,math.ceil(elapsed*120));local h=elapsed/steps
 local cruise=math.max(0,maxStep60 or 0)*60
 response=math.clamp(response or 1,.3,8)
 mass=math.clamp(mass or 1,.65,4)
 local inertia=math.sqrt(mass)
 local acceleration=math.max(10,cruise*1.6)*math.sqrt(response)/mass
 for _=1,steps do
  local delta=goal-position;local distance=delta.Magnitude
  -- Blend the near-work response continuously. The old distance<=16 switch
  -- changed both speed and easing abruptly at an invisible boundary.
  local proximity=work and math.clamp((16-distance)/12,0,1) or 0
  local cap=cruise
  local ease=-60*math.log(1-.03)
  -- A damped arrival controller brakes lateral momentum as well as forward
  -- speed. Pure pursuit with a fixed acceleration repeatedly crossed the
  -- station and reversed direction during warmup.
  local omega=ease*(1+proximity*.35)*response/inertia
  local requestedAcceleration=delta*(omega*omega)-velocity*(2*omega)
  local requestedVelocity=velocity+requestedAcceleration*h
  local speed=math.min(cap,math.sqrt(2*acceleration*distance))
  local requested=requestedVelocity
  if requested.Magnitude>speed then requested=requested.Unit*speed end
  if correction then
   requested+=correction*h
   if requested.Magnitude>cap then requested=requested.Unit*cap end
  end
  -- Neighbor pressure is a lateral thruster force, not a moving station.
  -- Apply it before the final cap so even evasive turns respect engine thrust.
  if steering then
   requested+=steering*(h/mass)
   if requested.Magnitude>cap then requested=requested.Unit*cap end
  end
  local change=requested-velocity;local limit=acceleration*h
  local nextVelocity=change.Magnitude>limit and velocity+change.Unit*limit or requested
  position+=(velocity+nextVelocity)*(.5*h);velocity=nextVelocity
 end
 return position,velocity
end
local hexDirections={{0,-1},{-1,0},{-1,1},{0,1},{1,0},{1,-1}}
local function hexRing(slot)
 return math.ceil((math.sqrt(12*(slot-1)+9)-3)/6)
end
local function hexPoint(slot)
 if slot<=1 then return 0,0 end
 local ring=hexRing(slot);local index=slot-2-3*ring*(ring-1)
 local q,r=ring,0
 for side,direction in ipairs(hexDirections) do
  local steps=math.min(ring,math.max(0,index-(side-1)*ring))
  q+=direction[1]*steps;r+=direction[2]*steps
 end
 return q,r
end
function F.formationXZ(slot,count)
 count=math.max(1,math.floor(count or 1));slot=math.clamp(math.floor(slot or 1),1,count)
 -- Hexagonal cells keep uniform spacing as a permanent fleet grows. Full
 -- inner rings sum to zero; sum only the partial outer ring to center the crew.
 -- Both lookups cost at most six sides, regardless of the fleet population.
 local cq,cr=0,0
 if count>1 then
  local ring=hexRing(count);local remaining=count-1-3*ring*(ring-1)
  local q,r=ring,0
  for _,direction in ipairs(hexDirections) do
   local n=math.min(ring,remaining)
   cq+=n*q+direction[1]*n*(n-1)/2;cr+=n*r+direction[2]*n*(n-1)/2
   q+=direction[1]*ring;r+=direction[2]*ring;remaining-=n
  end
 end
 local q,r=hexPoint(slot);q-=cq/count;r-=cr/count
 return (q+r*.5)*F.SwarmSpacing,r*(math.sqrt(3)/2)*F.SwarmSpacing
end
function F.formation(slot,count)
 local x,z=F.formationXZ(slot,count)
 return Vector3.new(x,0,z)
end
function F.hover(time,maxStep60) return math.sin(time+maxStep60*200)/3 end
function F.followOffset(slot,count,time,maxStep60,steady)
 local angle=2*math.pi*slot/math.max(1,count)
 return math.cos(angle)*10,F.ReferenceFollowHeight+(steady and 0 or F.hover(time,maxStep60)),math.sin(angle)*10
end
function F.followGoal(ownerPosition,slot,count,time,maxStep60,steady,altitude)
 local x,y,z=F.followOffset(slot,count,time,maxStep60,steady)
 return ownerPosition+Vector3.new(x,altitude or y,z)
end
function F.quarryFollowHeight(role,time,maxStep60)
 if role=='Ramiel' then return F.ReferenceFollowHeight+12 end
 return (role=='Courier' and 15.4 or 16.6)+F.hover(time,maxStep60)
end
local function swarmHash(id)
 local value=0
 for i=1,#id do value=(value*131+string.byte(id,i))%2147483647 end
 return value
end
function F.swarmTraits(id)
 local seed=swarmHash(tostring(id))
 -- Fleet IDs often differ only in their last digit. Mix nearby hashes so
 -- those drones don't end up with almost identical speeds and heights.
 seed=(bit32.bxor(seed,bit32.rshift(seed,16))*159733)%2147483647
 seed=(bit32.bxor(seed,bit32.rshift(seed,13))*224081)%2147483647
 return {phase=seed%6283*.001, lane=(math.floor(seed/17)%101)/50-1,
  height=(math.floor(seed/131)%101)/50-1, speed=.87+(math.floor(seed/1091)%101)*.0026,
  rate=.68+(math.floor(seed/8191)%101)*.0064}
end
function F.ringGoals(records,center)
 local crew={}
 for _,d in pairs(records) do
  if d.hp>0 and d.state=='Follow' and d.role~='Nomad' then
   local delta=d.pos-center
   local angle=delta.X^2+delta.Z^2>.01 and math.atan2(delta.Z,delta.X) or F.swarmTraits(d.id).phase
   crew[#crew+1]={id=d.id,angle=angle}
  end
 end
 table.sort(crew,function(a,b) return a.angle==b.angle and tostring(a.id)<tostring(b.id) or a.angle<b.angle end)
 local n=#crew;local goals={}
 if n==0 then return goals end
 -- Preserve spatial order, not ownership of a slot. Find the least-travel
 -- rotation of an evenly spaced ring. Neighbors yield along the ring;
 -- nobody has to cross through the crew to recover an old numbered station.
 local phase=0;local step=2*math.pi/n
 for i,d in ipairs(crew) do phase+=d.angle-(i-1)*step end
 phase/=n
 local radius=math.max(12,n*7.5/(2*math.pi))
 for i,d in ipairs(crew) do goals[d.id]={angle=phase+(i-1)*step,radius=radius} end
 return goals
end
function F.swarmFollow(center,velocity,slot,count,now,height,traits,cruise,dt,ring)
 local motion=Vector3.new(velocity.X,0,velocity.Z)
 local moving=math.clamp((motion.Magnitude-.7)/6,0,1)
 cruise=cruise or 0
 cruise+=(moving-cruise)*(1-math.exp(-dt*1.8))
 local angle=ring and ring.angle or 2*math.pi*slot/math.max(1,count)
 local ringRadius=ring and ring.radius or math.max(12,count*7.5/(2*math.pi))
 local idle=Vector3.new(math.cos(angle)*ringRadius,traits.height*.9,math.sin(angle)*ringRadius)
 -- Coherent translation with staggered depth/height. No time-driven loops,
 -- crossing sine paths, or orbit: organic movement comes from inertia.
 local direction=motion.Magnitude>.1 and motion.Unit or Vector3.zero
 local air=idle+Vector3.yAxis*(traits.height*2.3)-direction*(3+2*traits.lane)
 return center+Vector3.yAxis*height+idle:Lerp(air,cruise),cruise
end
function F.courierLoad(units)
 local load=math.clamp(units or 0,0,4)
 return 1.65+load*.56,1/(1+.26*load)
end
function F.gunImpulse(role,from,to,mass)
 local momentum=role=='Needler' and 7 or role=='Ballcaster' and 15 or 0
 local delta=from-to
 return delta.Magnitude>.001 and delta.Unit*(momentum/(mass or 1)) or Vector3.zero
end
local function swarmCell(x,y,z) return x..':'..y..':'..z end
local function intentVelocity(record)
 if record.velocity then return record.velocity end
 local goal=record.goal
 if not goal then return Vector3.zero end
 local delta=goal-record.pos;local distance=delta.Magnitude
 if distance<.001 then return Vector3.zero end
 local step=record.maxStep60 or (record.stats and record.stats.maxStep60) or .35
 return delta/distance*math.min(distance*1.8,math.max(0,step)*60)
end
function F.swarmGrid(records)
 -- Snapshot once before moving any worker, so update order cannot make the
 -- first drone push the last one differently. Buckets hold immutable poses.
 local grid={buckets={},velocities={}};local cell=F.SwarmRadius
 for _,record in pairs(records) do
  if record.id and record.pos and (record.hp==nil or record.hp>0) then
   local pos=record.pos;local key=swarmCell(math.floor(pos.X/cell),math.floor(pos.Y/cell),math.floor(pos.Z/cell))
   local bucket=grid.buckets[key]
   if not bucket then bucket={};grid.buckets[key]=bucket end
   local id=tostring(record.id);local velocity=intentVelocity(record)
   table.insert(bucket,{id=id,pos=pos,velocity=velocity});grid.velocities[id]=velocity
  end
 end
 -- Stable sampling in crowded cells must not depend on table iteration order.
 for _,bucket in pairs(grid.buckets) do table.sort(bucket,function(a,b) return a.id<b.id end) end
 return grid
end
function F.swarmOffset(position,id,grid,weight,flocking)
 weight=math.clamp(weight or 1,0,1)
 if weight==0 or not grid then return Vector3.zero end
 id=tostring(id)
 local cell=F.SwarmRadius;local x,y,z=math.floor(position.X/cell),math.floor(position.Y/cell),math.floor(position.Z/cell)
 local neighbors={}
 local velocity=(grid.velocities and grid.velocities[id]) or Vector3.zero
 -- Read only 27 local bins, at most 12 samples per bin and 12 final contacts.
 -- Even a crowd stacked at exactly one pose cannot cause a fleet-wide scan for
 -- each worker. Samples spread through the stable bucket using the caller ID.
 for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
  local key=swarmCell(x+dx,y+dy,z+dz);local bucket=grid.buckets[key]
  if bucket then
   local n=#bucket;local samples=math.min(12,n);local start=n>samples and swarmHash(id..key)%n or 0
   for i=0,samples-1 do
    local other=bucket[(start+math.floor(i*n/samples))%n+1]
    if other.id~=id then
     local delta=position-other.pos;local square=delta:Dot(delta)
     if square<cell*cell then
      local relative=velocity-(other.velocity or Vector3.zero);local motion=relative:Dot(relative)
      local closest=motion>.001 and math.clamp(-delta:Dot(relative)/motion,0,.65) or 0
      local future=delta+relative*closest
      local futureSquare=future:Dot(future)
      if square>=F.SwarmNear^2 and (closest==0 or futureSquare>=5.5^2) then continue end
      local candidate={id=other.id,delta=delta,square=square,futureSquare=futureSquare,closest=closest,velocity=other.velocity}
      if #neighbors<12 then table.insert(neighbors,candidate)
      else
       local worst=1
       for j=2,#neighbors do
        if neighbors[j].square>neighbors[worst].square or (neighbors[j].square==neighbors[worst].square and neighbors[j].id>neighbors[worst].id) then worst=j end
       end
       if square<neighbors[worst].square or (square==neighbors[worst].square and other.id<neighbors[worst].id) then neighbors[worst]=candidate end
      end
     end
    end
   end
  end
 end end end
 table.sort(neighbors,function(a,b) return a.id<b.id end)
 local force,alignment,nearby=Vector3.zero,Vector3.zero,0
 for _,other in ipairs(neighbors) do
  local first=id<other.id;local pair=swarmHash(first and (id..'/'..other.id) or (other.id..'/'..id))
  local side=first and 1 or -1;local delta=other.delta
  local flat=Vector3.new(delta.X,0,delta.Z);local distance=math.sqrt(other.square)
  local normal
  if flat.Magnitude>.001 then normal=flat/flat.Magnitude
  else
   -- Exact overlaps still produce equal and opposite, reproducible escape
   -- directions. No random rerolls or unstable zero-vector normalization.
   local angle=(pair%6283)/1000
   normal=Vector3.new(math.cos(angle)*side,0,math.sin(angle)*side)
  end
  -- Predict a crossing before the models overlap. Pair-stable tangents let
  -- head-on workers pass on opposite sides instead of stopping nose-to-nose.
  local currentPressure=math.max(0,1-distance/F.SwarmNear)^2
  local futureDistance=math.sqrt(other.futureSquare or other.square)
  local closing=(velocity-other.velocity).Magnitude
  local anticipation=(other.closest or 0)>0 and math.max(0,1-futureDistance/5.5)^2*.8*math.clamp((closing-2)/8,0,1) or 0
  local pressure=math.max(currentPressure,anticipation)
  local tangent=Vector3.new(-normal.Z,0,normal.X)*(pair%2==0 and 1 or -1)
  local lane=distance>.001 and math.clamp(delta.Y/distance,-1,1)*.95 or side*.35
  -- Static separation cannot inject sideways momentum and perpetual orbit.
  force+=normal*(currentPressure*1.9+anticipation*.65)+tangent*(anticipation*4.8)+Vector3.new(0,lane*pressure,0)
  if flocking and flocking>0 then
   local blend=math.max(0,1-distance/F.SwarmNear)
   alignment+=(other.velocity-velocity)*blend;nearby+=blend
  end
 end
 if nearby>0 then
  local match=alignment/nearby
  force+=match*(match.Magnitude>.42 and .42/match.Magnitude or 1)*flocking*math.min(1,nearby)
 end
 force=Vector3.new(force.X,math.clamp(force.Y,-.85,.85),force.Z)
 if force.Magnitude>F.SwarmMaxOffset then force=force.Unit*F.SwarmMaxOffset end
 -- Settled mining passes zero weight so its exact overhead station wins.
 return force*weight
end
function F.smoothSwarm(previous,desired,dt)
 -- Smooth steering pressure, not a second smoothing of the drone's position.
 -- Isolated movement therefore retains the original .03 capped equation.
 if dt<=0 then return previous or Vector3.zero end
 return (previous or Vector3.zero):Lerp(desired,1-math.exp(-math.min(dt,.1)*10))
end
function F.stationOffset(slot,geode,height)
 height=height or (geode and 8 or F.WorkHeight)
 if not geode then return 0,height,0 end
 -- Geodes share three small slots over the shell footprint, never behind the rock.
 local angle=2*math.pi*((slot or 1)-1)/3
 return math.cos(angle)*.85,height,math.sin(angle)*.85
end
function F.mineGoal(resourcePosition,slot,geode,fullSize,reference,quarry)
 -- Large original geodes can be eight studs tall. Keep the smaller worker
 -- above the original volume, with a visible beam gap throughout mining.
 local height=fullSize and math.max(F.WorkHeight,fullSize.Y*.5+F.WorkClearance) or nil
 -- Mining Away sends Crystal.Primary.Position + 10. The visible Mesh is
 -- welded three studs above that primary, so its center-to-drone gap is seven.
 if reference then height=F.WorkHeight-F.ReferenceCrystalPivot end
 if quarry and fullSize then
  -- Center the drone above the intact tip. The deck height keeps the
  -- original 2-stud miner shell clear even over the smallest crystals.
  height=math.max(7-fullSize.Y*.5,fullSize.Y*.5+3.1)+4
 end
 local x,y,z=F.stationOffset(slot,geode,height)
 return resourcePosition+Vector3.new(x,y,z)
end
function F.stage(hp,maxHP,count)
 count=math.clamp(math.floor(count or 3),1,7)
 if maxHP<=0 then return count end
 return math.clamp(math.floor((1-hp/maxHP)*(count+1)+1e-7),0,count)
end
function F.powerDive(start,impact,elapsed,duration)
 local delta=impact-start
 -- A powered weight gains speed all the way down. It has no arrival brake:
 -- contact stops the stroke, then the separate held phase carries its weight.
 -- Repeated/late samples stay exactly at contact with no residual velocity.
 if elapsed<=0 then return start,delta*0 end
 duration=math.max(.01,duration)
 if elapsed>=duration then return impact,delta*0 end
 local p=elapsed/duration
 return start:Lerp(impact,p^2.6),delta*(2.6*p^1.6/duration)
end
function F.stagesCrossed(previous,hp,maxHP)
 local result={}
 for stage=previous+1,F.stage(hp,maxHP) do table.insert(result,stage) end
 return result
end
function F.stageScale(stage,count) count=math.clamp(count or 3,1,7);return 1-math.clamp(stage,0,count)/(count+1) end
function F.crystalStageShape(stage,count,fullSize)
 local loss=1-F.stageScale(stage,count)
 local shape=Vector3.new(1-loss*.62,1-loss*.81,1-loss*.46)
 -- Add one stud at the final stage, keeping the intact silhouette and
 -- spreading the extra volume across the preceding fractures.
 local progress=math.clamp(stage/math.max(1,count or 3),0,1)
 return fullSize and shape+Vector3.yAxis*progress/fullSize or shape
end
F.MaxCrystalDarkness=.38
function F.crystalDarkness(hp,maxHP)
 local spent=1-math.clamp((hp-10)/math.max(1,maxHP-10),0,1)
 return F.MaxCrystalDarkness*spent^.88
end
function F.junkDarkness(hp,maxHP,stage,count)
 local progress=math.clamp((1-hp/math.max(1,maxHP))*(count+1)-stage,0,1)
 return .0832*progress^.8
end
function F.rockShape(slice,heat) return Vector3.new(1,(slice or 1)*(1-.0625*(heat or 0)),1) end
function F.growthProgress(now,spawnAt) return math.clamp((now-spawnAt)/2,0,1) end
function F.growth(now,spawnAt)
 -- TweenInfo.new(2) originally used Roblox's default Quad.Out easing.
 local t=F.growthProgress(now,spawnAt)
 return 1-(1-t)^2
end
function F.ready(now,spawnAt) return now>=spawnAt+2 end
function F.canMine(distance,ready,allowed,alive)
 return alive==true and ready==true and allowed==true and distance<=1
end
function F.flightYaw(position,goal,velocity,lastYaw)
 -- Use actual travel direction, retaining heading after arrival. A tiny
 -- steering residual must never spin a stationary miner through 180 degrees.
 if velocity and Vector3.new(velocity.X,0,velocity.Z).Magnitude>.35 then
  return F.levelYaw(position,position+velocity,lastYaw)
 end
 if Vector3.new(goal.X-position.X,0,goal.Z-position.Z).Magnitude>1 then return F.levelYaw(position,goal,lastYaw) end
 return lastYaw or 0
end
function F.referenceYaw(position,goal,maxStep60,ownerLook,lastYaw)
 if ownerLook and (goal-position).Magnitude*.03<maxStep60 then
  return F.levelYaw(Vector3.zero,ownerLook,lastYaw)
 end
 return F.levelYaw(position,goal,lastYaw)
end
function F.levelYaw(position,target,lastYaw)
 local dx,dz=target.X-position.X,target.Z-position.Z
 if dx*dx+dz*dz<1e-8 then return lastYaw or 0 end
 return math.atan2(-dx,-dz)
end
function F.approachYaw(yaw,target,dt)
 local delta=(target-yaw+math.pi)%(2*math.pi)-math.pi
 return yaw+delta*F.turnAlpha(dt)
end
-- Cosmetic-only quarter-stage sequencing. Server damage/rewards never wait for it.
function F.newStagePresentation(stage,broken,now,count)
 stage=math.clamp(math.floor(stage or 0),0,count or 3)
 return {stage=stage,knownStage=stage,broken=broken==true,knownBreak=broken==true,queue={},nextAt=now or 0}
end
function F.updateStagePresentation(p,authoritativeStage,broken,now,count)
 count=count or 3
 local target=broken and count or math.clamp(math.floor(authoritativeStage or 0),0,count)
 if p.knownBreak then return nil end
 if broken then
  p.stage=target;p.knownStage=target;p.knownBreak=true;p.broken=true;p.queue={}
  return 'break'
 end
 if target<=p.knownStage then return nil end
 p.stage=target;p.knownStage=target;p.scorched=false;p.queue={};p.nextAt=now
 return 'stage'
end
-- Only fade a hull between the camera and avatar, without moving the crew or
-- querying the world. The author-owned opacity and gameplay model stay intact.
function F.cameraObstruction(camera,focus,point,radius)
 local x,y,z=focus.X-camera.X,focus.Y-camera.Y,focus.Z-camera.Z
 local length=x*x+y*y+z*z
 if length<1e-6 then return 0 end
 local px,py,pz=point.X-camera.X,point.Y-camera.Y,point.Z-camera.Z
 local t=(px*x+py*y+pz*z)/length
 if t<=0 or t>=.96 then return 0 end
 local dx,dy,dz=px-x*t,py-y*t,pz-z*t
 local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
 return .86*math.clamp(1-distance/math.max(.5,radius),0,1)
end
return F
