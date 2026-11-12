-- Original 2023 motion and crystal timing, with explicit elapsed-time correction.
-- Scalar helpers stay engine-independent so the original equations are testable.
local F = {FollowHeight=3.2,ReferenceFollowHeight=7,ReferenceCrystalPivot=3,WorkHeight=10,WorkClearance=5,SwarmSpacing=3.5,SwarmRadius=6,SwarmMaxOffset=2.2}
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
function F.groundedRockFrame(position,size,ground,stage,seed,turn,reference)
 local center=Vector3.new(position.X,ground+size.Y*.5-.06,position.Z)
 return CFrame.new(center)*CFrame.Angles(0,F.rockYaw(seed,stage,turn,reference),0),ground+size.Y-.06
end
function F.inertialApproach(position,goal,velocity,maxStep60,dt,work,correction,response)
 -- Retain the original capped, distance-eased destination rule, but approach
 -- its requested velocity with thrust. New jobs, reversals and speed upgrades
 -- cannot replace momentum in a single frame. Substeps keep braking consistent
 -- across server ticks and 30/60/144 Hz observers.
 velocity=velocity or Vector3.zero
 if type(dt)~='number' or dt~=dt or dt<=0 then return position,velocity end
 local elapsed=math.min(dt,.1);local steps=math.max(1,math.ceil(elapsed*120));local h=elapsed/steps
 local cruise=math.max(0,maxStep60 or 0)*60
 response=math.clamp(response or 1,.3,8)
 local acceleration=math.max(10,cruise*1.6)*math.sqrt(response)
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
  local omega=ease*(1+proximity*.35)*response
  local requestedAcceleration=delta*(omega*omega)-velocity*(2*omega)
  local requestedVelocity=velocity+requestedAcceleration*h
  local speed=math.min(cap,math.sqrt(2*acceleration*distance))
  local requested=requestedVelocity
  if requested.Magnitude>speed then requested=requested.Unit*speed end
  if correction then
   requested+=correction
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
function F.followGoal(ownerPosition,slot,count,time,maxStep60,steady)
 local x,y,z=F.followOffset(slot,count,time,maxStep60,steady)
 return ownerPosition+Vector3.new(x,y,z)
end

function F.nomadPatrol(center,altitude,slot,owner,now)
 local angle=(now%112)*(2*math.pi/112)+slot*2.39996+(owner%211)/211*(2*math.pi)
 return center+Vector3.new(680*math.cos(angle),altitude,565*math.sin(angle))
end

function F.nomadPass(from,to,q)
 if q>=.72 then return to end
 local t=math.clamp(q/.72,0,1)
 return from:Lerp(to,t*t*(3-2*t))
end

function F.nomadYaw(yaw,target,dt)
 local delta=(target-yaw+math.pi)%(2*math.pi)-math.pi
 local limit=math.rad(9)*math.max(0,dt)
 return yaw+math.clamp(delta,-limit,limit)
end
local function swarmHash(id)
 local value=0
 for i=1,#id do value=(value*131+string.byte(id,i))%2147483647 end
 return value
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
function F.swarmOffset(position,id,grid,weight)
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
   local n=#bucket;local samples=math.min(12,n);local start=swarmHash(id..key)%n
   for i=0,samples-1 do
    local other=bucket[(start+math.floor(i*n/samples))%n+1]
    if other.id~=id then
     local delta=position-other.pos;local square=delta:Dot(delta)
     if square<cell*cell then
      local relative=velocity-(other.velocity or Vector3.zero);local motion=relative:Dot(relative)
      local closest=motion>.001 and math.clamp(-delta:Dot(relative)/motion,0,.45) or 0
      local future=delta+relative*closest
      local candidate={id=other.id,delta=delta,square=square,futureSquare=future:Dot(future),closest=closest}
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
 local force=Vector3.zero
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
  local currentPressure=(1-distance/cell)^2
  local futureDistance=math.sqrt(other.futureSquare or other.square)
  local anticipation=(other.closest or 0)>0 and (1-math.min(cell,futureDistance)/cell)^2*.8 or 0
  local pressure=math.max(currentPressure,anticipation)
  local tangent=Vector3.new(-normal.Z,0,normal.X)*(pair%2==0 and 1 or -1)
  local lane=side*((pair%3)-1)*.12
  force+=(normal*1.8+tangent*(anticipation>currentPressure and 1.4 or .48)+Vector3.new(0,lane,0))*pressure
 end
 force=Vector3.new(force.X,math.clamp(force.Y,-.24,.24),force.Z)
 if force.Magnitude>F.SwarmMaxOffset then force=force.Unit*F.SwarmMaxOffset end
 -- Add to the movement GOAL and pass through original capped easing. Settled
 -- mining passes zero weight so its exact overhead station/arrival gate wins.
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
function F.mineGoal(resourcePosition,slot,geode,fullSize,reference)
 -- Large original geodes can be eight studs tall. Keep the smaller worker
 -- above the original volume, with a visible beam gap throughout mining.
 local height=fullSize and math.max(F.WorkHeight,fullSize.Y*.5+F.WorkClearance) or nil
 -- Mining Away sends Crystal.Primary.Position + 10. The visible Mesh is
 -- welded three studs above that primary, so its center-to-drone gap is seven.
 if reference then height=F.WorkHeight-F.ReferenceCrystalPivot end
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
function F.crystalStageShape(stage,count)
 local loss=1-F.stageScale(stage,count)
 return Vector3.new(1-loss*.62,1-loss*.81,1-loss*.46)
end
function F.crystalShade(hp,maxHP,stage,count)
 local period=F.stageScale(stage,count)
 return math.clamp(hp/math.max(1,maxHP)/period-(1-period)/4,0,1)
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
return F
