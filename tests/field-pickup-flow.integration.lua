-- Production server flow with API doubles, starting in Crystal Run mode.
local cfIndex=CF.__index
CF.__index=function(c,k)
 if k=='RightVector' then return Vector3.new(math.cos(c.yaw),0,-math.sin(c.yaw)) end
 return cfIndex(c,k)
end
local pl=player(98760);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local hr=characterRoot(p)
local d
for _,worker in ipairs(p.drones) do if worker.role=='Courier' then d=worker;break end end
assert(d)
local run=data(p).run
inStudio=true
local studioCrew=scene.runtimeFleet(p)
inStudio=false
local starterRoles={}
for _,worker in ipairs(studioCrew) do starterRoles[worker.role]=true end
assert(#studioCrew==9 and #data(p).fleet==7 and starterRoles.Needler and starterRoles.Ballcaster,
 'both guns should join the regular Studio starter crew without mutating ownership')
local zone=Instance.new('Folder');zone.Parent=scene.map
local bed=World.part(zone,'Field',Vector3.new(0,5,-60),Vector3.new(216,1,64),Color3.new(1,.5,0))
local field={id=#patches+1,cfg={SelectionOnly=true},part=bed,resources={},respawnQueue={},e=R.newEncounter(C)}
field.e.phase='Safe';patches[field.id]=field
local center=bed.Position+Vector3.yAxis*.5
pl.Character:PivotTo(CFrame.new(center+Vector3.new(20,3,0)))
local initialRay=workspace.Raycast
workspace.Raycast=function() return {Instance=bed} end
scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center})
assert((p.miningSquare.center-center).Magnitude<.001,'raised bed blocked a legal command')
scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center-Vector3.xAxis*28})
assert((p.miningSquare.center-center).Magnitude<.001,'out-of-range command changed the pin')
assert((Mining.selectorCenter(center+Vector3.xAxis*108.001,bed.CFrame,bed.Size)-(center+Vector3.xAxis*108)).Magnitude<.001)
assert(not Mining.selectorCenter(center+Vector3.xAxis*108.1,bed.CFrame,bed.Size),'server accepted an off-bed position')
workspace.Raycast=initialRay

-- Let production droneStep decide who is waiting. The line uses only those
-- drones, and remains on the original edge when the player crosses the pin.
local function queueGoals()
 scene.plotQueues={}
 for _,worker in ipairs(p.drones) do droneStep(worker,C.Tick) end
 scene.flushPlotQueues(C.Tick)
 local order={}
 for _,worker in ipairs(p.drones) do if worker.state=='HoldSelector' then table.insert(order,worker) end end
 table.sort(order,function(a,b) return a.intentGoal.Z<b.intentGoal.Z end)
 return order
end
local order=queueGoals()
assert(#order==#p.drones and order[#order].role=='Courier' and order[#order-1].role=='Courier','couriers did not queue together')
local edgeX=center.X+p.miningSquare.half+5
local altitude=order[1].intentGoal.Y
for i,worker in ipairs(order) do
 assert(math.abs(worker.intentGoal.X-edgeX)<.001 and worker.intentGoal.Y==altitude,'waiting drone did not stay on the padded edge line')
 if i>1 then assert(worker.intentGoal.Z-order[i-1].intentGoal.Z>=4.49,'line stacked neighboring drones') end
end
pl.Character:PivotTo(CFrame.new(center+Vector3.new(-20,3,0)))
assert(queueGoals()[1].intentGoal.X==edgeX,'walking around a plot flipped the queue')
pl.Character:PivotTo(CFrame.new(center+Vector3.new(20,3,0)))
local miner=p.drones[1]
assert(miner.role=='Striker' and scene.followHeight(miner)+4.5<scene.followHeight(d),'small miners should escort below the carriers')
local previousState=miner.state
miner.state='Follow';local followSpeed=travelSpeed(miner)
miner.state='Travel';assert(followSpeed>travelSpeed(miner)*1.2,'small miners should accelerate their escort pace')
miner.state=previousState

do
 local destination=Vector3.new(-48,9,0)
 local start=Vector3.new(-18,15,0)
 local approach=Workshop.courierApproachTime(start)
 local turn=Workshop.courierReturnTurn(Vector3.zero,-math.pi/2,destination)
 assert(math.abs(turn)>math.pi,'a counter behind the grab should get a wide return arc')
 local turnStart=approach
 local _,left=Workshop.courierSwoop(Vector3.zero,-math.pi/2,start,Vector3.xAxis*4,approach-.001,approach,turn)
 local _,at=Workshop.courierSwoop(Vector3.zero,-math.pi/2,start,Vector3.xAxis*4,approach,approach,turn)
 local _,right=Workshop.courierSwoop(Vector3.zero,-math.pi/2,start,Vector3.xAxis*4,approach+.001,approach,turn)
 assert(((at-left)-(right-at)).Magnitude<.001 and math.abs(right.Z)>.005 and right.Y>.015,'the turn and climb must share the contact tangent and acceleration')
 local previous=Vector3.xAxis
 for i=0,120 do
  local time=turnStart+Workshop.courierTurnTime(turn)*i/120
  local pose,velocity=Workshop.courierSwoop(Vector3.zero,-math.pi/2,start,Vector3.xAxis*4,time,approach,turn)
  local flat=Vector3.new(velocity.X,0,velocity.Z)
  assert(flat.Magnitude>10.9 and previous:Dot(flat.Unit)>.99,'the wide return lost speed or snapped its heading')
  previous=flat.Unit
  if i==120 then
   local toCounter=destination-pose
   assert(Vector3.new(toCounter.X,0,toCounter.Z).Unit:Dot(previous)>.999,'the exit tangent missed the counter')
  end
 end
end

local material=Workshop.cargoKey('Amber',7)
local function loose(position)
 scene.spawnOrePickup(bed,{owner=pl.UserId,runId=data(p).run.id,nodeId='test',units=1,raw=true,
   tierMaterial='Amber',material=material,value=7,floor=position.Y,fieldPart=bed},position,Vector3.zero,bed.Color)
 local drop=pickups[pickupSerial]
 drop.landed=true;drop.age=1
 return drop,pickupSerial
end
local rock=Instance.new('Part');rock.CanCollide=true;rock.Parent=zone;rock:SetAttribute('ReferenceCrystal',true)
rock.Size=Vector3.new(3,2,3);rock.CFrame=CFrame.new(hr.Position-Vector3.yAxis*2)
assert(not scene.rockCanSolidify({part=rock},{pl}),'a growing rock would trap a player')
rock.CFrame=CFrame.new(center)
assert(scene.rockCanSolidify({part=rock},{pl}),'a clear rock cannot turn solid')
local near,nearId=loose(hr.Position-Vector3.yAxis*2)
workspace.Raycast=function(_,_,_,params)
 return not table.find(params.FilterDescendantsInstances,rock) and {Instance=rock} or nil
end
for _=1,12 do now+=C.Tick;pickupStep(C.Tick) end
assert(not pickups[nearId] and Pro.cargoUnits(data(p))==1,'solid mineable rock blocked player pickup')
workspace.Raycast=initialRay

do
 local movingGem=hr.Position-Vector3.yAxis*2
 local offered,offeredId=loose(movingGem)
 offered.firstLandedAge=.65
 local wall=Instance.new('Part')
 wall.CanCollide=true;wall.Parent=zone
 offered.courier=d;d.orePickupId=offeredId;d.oreDock=movingGem+Vector3.yAxis*5
 workspace.Raycast=function() return {Instance=wall} end
 now+=C.Tick;pickupStep(C.Tick)
 assert(pickups[offeredId] and d.orePickupId==offeredId and not offered.homing,'blocked pickup took priority through scenery')
 workspace.Raycast=initialRay
 -- Move before the cached obstructed ray expires; collection should respond now.
 pl.Character:PivotTo(CFrame.new(hr.Position+Vector3.zAxis*1.5))
 now+=C.Tick;pickupStep(C.Tick)
 assert(not d.orePickupId and not d.oreDock and not offered.part:GetAttribute('CourierDocking'),'nearby player did not take over a reserved pickup')
 for _=1,12 do now+=C.Tick;pickupStep(C.Tick) end
 assert(not pickups[offeredId] and Pro.cargoUnits(data(p))==2 and Pro.droneCargoUnits(data(p),d.id)==0,'pickup did not credit the player exactly once')
 run.cargo[material]-=1
 pl.Character:PivotTo(CFrame.new(center+Vector3.new(20,3,0)))
 wall:Destroy()
end

local drop,id=loose(center+Vector3.yAxis*.22)
local extra,extraId=loose(center+Vector3.new(5,.22,0))
local gem=Vector3.new(drop.x,drop.floor-.22+drop.part.Size.Y*.5,drop.z)
local dock=gem+Vector3.yAxis*Workshop.COURIER_HOOK_DROP
d.pos=dock-Vector3.xAxis*18+Vector3.yAxis*15;d.velocity=Vector3.xAxis*4
scene.assignEmptierPickups(p)
assert(d.orePickupId==id and drop.courier==d,'nearest ore was not reserved')
d.oreYaw=-math.pi/2
scene.collectGroundCargo(d,p,hr,C.Tick)
local high=d.pos
assert(d.state=='Pickup' and (high-dock).Magnitude>5.9 and d.oreDock and pickups[id])
assert(d.velocity.X>3.9,'swoop should begin directly from the flying approach')
local idle=queueGoals()
assert(d.state=='Pickup' and #idle>0 and #idle<#p.drones,'active couriers should leave the idle line')
assert(math.abs((idle[1].intentGoal.Z+idle[#idle].intentGoal.Z)*.5-center.Z)<.001,'working drones left a hole in the line')
snapshotDrone(d)
assert((d.model:GetAttribute('CourierPickupPoint')-gem).Magnitude<.01)
scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center+Vector3.xAxis*36})
assert(p.miningSquare.center.X==36)
pl.Character:PivotTo(CFrame.new(center+Vector3.new(56,3,0)))
now+=Workshop.COURIER_SCAN*.75
scene.assignEmptierPickups(p)
scene.collectGroundCargo(d,p,hr,C.Tick)
assert(d.pos.X>high.X+.15 and d.pos.Y<high.Y and pickups[id],'swoop stopped or lost its reservation through a new pin')
now=d.pickupAt+d.oreApproachTime-.05
scene.collectGroundCargo(d,p,hr,C.Tick)
assert(d.pos.X<dock.X and d.velocity.X>8 and pickups[id],'ore attached ahead of contact or the claw stopped')
now=d.pickupAt+d.oreApproachTime+.01
scene.collectGroundCargo(d,p,hr,C.Tick)
assert(not pickups[id] and pickups[extraId] and Pro.droneCargoUnits(data(p),d.id)==1)
assert(d.pos.X>dock.X and d.velocity.X>8,'cargo contact interrupted forward flight')
now=d.pickupAt+d.oreApproachTime+1
scene.collectGroundCargo(d,p,hr,C.Tick)
assert(d.pos.X>dock.X+6 and d.pos.Y>dock.Y+4 and d.velocity.Magnitude>10,'climb lost its forward momentum before clearing the pickup')
now=d.oreSeatUntil+.01
scene.collectGroundCargo(d,p,hr,C.Tick)
assert(d.pos.Y>dock.Y+5 and d.velocity.Magnitude>5 and d.deliveryRequested,'one ore should continue out of the swoop into delivery')
serviceDeliveries(p)
assert(Pro.deliveryUnits(data(p),d.id)==1 and Pro.cargoUnits(data(p))==1)
now+=3;droneStep(d,C.Tick)
assert(d.flightMass>1.5 and d.loadSpeed<.8,'the saved one-ore manifest did not load down the courier')
d.pos=d.goal;d.velocity=Vector3.zero;droneStep(d,C.Tick)
now+=2;droneStep(d,C.Tick);serviceDeliveries(p)
assert(data(p).run.wallet.Quartz==7 and not data(p).run.deliveries[d.id],'one ore failed to sell')
serviceDeliveries(p)
assert(data(p).run.wallet.Quartz==7,'sale was credited twice')
print('PASS Studio test crew, plot queue, moving grip, repin during swoop, and one-ore sale')

field.center=bed.Position;field.model=zone;field.color=bed.Color
field.cfg.AlwaysUnlocked=true;field.cfg.Key='Quartz'
field.cfg.Value=1;field.cfg.Hardness=1;field.cfg.Turrets=0;field.cfg.ReferenceCrystals=true
pl.Character:PivotTo(CFrame.new(center+Vector3.yAxis*3))
scene.clearSquare(p)
local kicks={}
for _,role in ipairs({'Needler','Ballcaster'}) do
 local gun
 for _,worker in ipairs(p.drones) do if worker.role==role then gun=worker;break end end
 assert(gun,'missing starter '..role)
 local target=makeResource(field,center+Vector3.xAxis*8,'Crystal',1000,1,3,3)
 target.readyAt=now
 assert(assignOre(p,gun,target))
 local station=committedStation(gun,target);gun.pos=station;gun.velocity=Vector3.zero
 local hp=target.hp;local shot
 for _=1,130 do
  now+=C.Tick;droneStep(gun,C.Tick)
  shot=shot or gun.specialJob
  if target.hp<hp then break end
 end
 local kickAt=gun.model:GetAttribute('FlightImpulseAt')
 local kick=gun.model:GetAttribute('FlightImpulse')
 assert(shot and shot.launched and shot.impacted and target.hp<hp and kickAt<now,role..' lost a valid shot after recoil')
 local backward=(shot.from-shot.contact).Unit
 local retreat=(gun.pos-station):Dot(backward)
 assert(kick.Unit:Dot(backward)>.99 and retreat>.3,role..' did not push back its logical hull')
 kicks[role]=kick.Magnitude
 for _=1,8 do now+=C.Tick;droneStep(gun,C.Tick) end
 assert(gun.model:GetAttribute('FlightImpulseAt')==kickAt,'one projectile pushed twice')
 local recoverStart=(gun.pos-station).Magnitude
 for _=1,120 do now+=C.Tick;move(gun,station,C.Tick) end
 assert((gun.pos-station).Magnitude<recoverStart*.45,'thrusters never returned the gun to the station')
 release(gun)
end
assert(kicks.Ballcaster>kicks.Needler*1.4)
print('PASS physical gun recoil, one impulse per launch, committed contact, and damped recovery')
