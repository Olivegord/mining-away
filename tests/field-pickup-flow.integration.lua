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
local thinkTimes={}
for _,worker in ipairs(p.drones) do
 snapshotDrone(worker)
 local ready=worker.model:GetAttribute('ThinkUntil')
 assert(ready>=now+.32-1e-6 and ready<=now+1.05+1e-6)
 thinkTimes[ready]=true
end
assert(next(thinkTimes,next(thinkTimes)),'target decisions were not staggered')
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
 field.model=zone;field.center=center;field.color=bed.Color;field.respawnClock=now
 field.cfg.Key='Quartz';field.cfg.AlwaysUnlocked=true;field.cfg.Turrets=0;field.cfg.Respawn=8
 local strong=makeResource(field,center,'Crystal',5410,10,3,3)
 local weak=makeResource(field,center+Vector3.xAxis*10,'Crystal',2110,5,2,3)
 local medium=makeResource(field,center-Vector3.xAxis*10,'Crystal',3810,7,2.5,3)
 strong.readyAt=now;weak.readyAt=now;medium.readyAt=now
 local crew={};local originalCount=#p.drones
 local gun
 for _,worker in ipairs(p.drones) do
  if DroneRoles.isWorker(worker.role) then table.insert(crew,worker) end
  if worker.role=='Needler' then gun=worker end
 end
 while #crew<10 do
  local owned=Pro.clone(miner.owned);owned.id='assist-test:'..#crew
  table.insert(crew,spawnDrone(p,owned,#p.drones+1))
 end
 local function searchAll()
  for _,worker in ipairs(crew) do scene.squareStep(p,worker) end
 end
 local function assigned()
  local total=0
  for _,worker in ipairs(crew) do if worker.target then total+=1 end end
  return total
 end
 local function count(rock)
  local total=0
  for _ in pairs(rock.slots) do total+=1 end
  return total
 end
 miner.pos=strong.position
 now+=.25
 scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center,leadId=strong.id})
 local started=now
 searchAll()
 assert(assigned()==3 and miner.target==weak and crew[2].target==medium and crew[3].target==strong,
  'new assignments did not spread across rocks in remaining-health order')
 now=started+1.95;searchAll()
 assert(assigned()==3,'helpers joined before the delay')
 now=started+2.35;searchAll()
 assert(assigned()>3 and assigned()<10,'helpers did not stagger their departures')
 now=started+3.15;searchAll()
 assert(assigned()==10 and count(weak)==1 and count(medium)==1 and count(strong)==8,
  'helpers did not prioritize the highest-health occupied rock')
 local sharedRock=gun.target
 local laser
 for _,worker in ipairs(crew) do
  if worker.target==sharedRock and worker.role=='Striker' then laser=worker;break end
 end
 -- The traveling reservation with the first slot must not take the center.
 -- Move the laser in on its own, then let the selected gun join it.
 for _,worker in ipairs(crew) do if worker.target==sharedRock then worker.pos=sharedRock.position+Vector3.zAxis*45 end end
 laser.pos=sharedRock.position
 now+=1.1
 scene.planMiningStations()
 assert(scene.workPlans[sharedRock].approach==laser,'nearby worker did not get the next station')
 local single=committedStation(laser,sharedRock,C.Tick)
 assert(math.abs(single.X-sharedRock.position.X)<.001 and math.abs(single.Z-sharedRock.position.Z)<.001)
 laser.pos=single;laser.warmAt=now
 sharedRock.approachingDrone=nil;gun.pos=sharedRock.position
 scene.planMiningStations()
 assert(#scene.workPlans[sharedRock].active==1 and scene.workPlans[sharedRock].approach==gun)
 gun.pos=committedStation(gun,sharedRock,C.Tick);gun.warmAt=now
 assert((laser.pos-gun.pos).Magnitude>=4.49,'mixed-role stations overlapped')
 local rival=player(98761);players.PlayerAdded:Fire(rival)
 local rivalProfile=profiles[rival.UserId]
 rival.Character:PivotTo(CFrame.new(hr.Position))
 scene.placeSquare(rivalProfile,{runId=data(rivalProfile).run.id,fieldId=field.id,position=center})
 scene.squareStep(rivalProfile,rivalProfile.drones[1])
 now+=3.2;scene.squareStep(rivalProfile,rivalProfile.drones[1])
 assert(not rivalProfile.drones[1].target,'another crew joined a claimed crystal')
 players.PlayerRemoving:Fire(rival)
 laser.mining=true
 local before=sharedRock.hp
 gun.specialJob={targetId=sharedRock.id,serial=1,startedAt=now-1,duration=1,impact=.5,damage=20,contact=sharedRock.part.Position}
 sharedRock.part:SetAttribute('EffectDrone',laser.id);sharedRock.part:SetAttribute('EffectDoneAt',0)
 assert(hitResource(laser,sharedRock,20) and hitResource(gun,sharedRock,20,false,nil,nil,'Special') and sharedRock.hp<before-30,
  'mixed-role reservations prevented real contacts on a shared rock')
 assert(sharedRock.part:GetAttribute('EffectDoneAt')==0,'a supporting shot overwrote another drone’s effect receipt')
 scene.publishSquareStatus(p)
 assert(pl:GetAttribute('MA_SelectorStatus')=='SharedCut','shared cutting did not reach the HUD')
 local regrowth=makeResource(field,weak.position+Vector3.zAxis*8,'Crystal',55,5,2,3)
 regrowth.readyAt=now
 scene.squareStep(p,laser)
 assert(assigned()==10 and laser.target==sharedRock,'a new rock interrupted active collaboration')
 local idle=crew[#crew];release(idle)
 scene.squareStep(p,idle)
 assert(idle.target==regrowth,'an available worker did not prioritize the newly ready rock')
 for _,worker in ipairs(crew) do release(worker) end
 for _,other in ipairs({weak,medium,regrowth}) do other.paid=true end
 now+=.25;searchAll()
 assert(assigned()==1,'only one worker should launch immediately at the last rock')
 now+=3.15;searchAll()
 assert(assigned()==10 and count(strong)==10,'the final healthy rock left spare workers idle')
 for _,worker in ipairs(crew) do worker.pos=strong.position+Vector3.zAxis*45 end
 for i=1,#crew do
  scene.planMiningStations()
  local plan=scene.workPlans[strong]
  assert(#plan.active==i-1,'a traveling reservation counted as a mining drone')
  local worker=assert(plan.approach)
  worker.pos=committedStation(worker,strong,C.Tick);worker.warmAt=now
  for _,other in ipairs(plan.active) do assert((worker.pos-other.pos).Magnitude>=4.49,'shared stations overlapped') end
 end
 scene.planMiningStations()
 local plan=scene.workPlans[strong]
 local leaving,sliding=plan.active[1],plan.active[2]
 release(leaving)
 scene.planMiningStations()
 local goal
 for _=1,160 do goal=committedStation(sliding,strong,C.Tick) end
 sliding.pos=goal
 assert(math.abs(goal.X-strong.position.X)<.01 and math.abs(goal.Z-strong.position.Z)<.01,'departure left a phantom station in the center')
 scene.workPlans=nil
 local finalLaser
 for _,worker in ipairs(crew) do if worker.target==strong and worker.role=='Striker' then finalLaser=worker;break end end
 assert(finalLaser and hitResource(finalLaser,strong,10000) and strong.paid and not next(strong.slots),'depletion did not retire every worker')
 assert(not hitResource(miner,strong,10000),'a depleted shared rock accepted a second payout contact')
 for id,drop in pairs(pickups) do drop.part:Destroy();pickups[id]=nil end
 for _,rock in ipairs(field.resources) do resources[rock.id]=nil;rock.part:Destroy() end
 table.clear(field.resources);table.clear(field.respawnQueue)
 for _,worker in ipairs(p.drones) do release(worker);worker.lingerUntil=nil end
 for i=#p.drones,originalCount+1,-1 do
  local worker=p.drones[i]
  drones[worker.id]=nil;worker.model:Destroy();table.remove(p.drones,i)
 end
end
print('PASS weak-first dispatch, highest-health reinforcements, staggered sharing, mixed contacts, and foreign claim protection')

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
 local exit=approach+Workshop.courierReturnDuration(turn)
 local first,enter=Workshop.courierSwoop(Vector3.zero,-math.pi/2,start,Vector3.xAxis*4,exit,approach,turn)
 local later,exitVelocity=Workshop.courierSwoop(Vector3.zero,-math.pi/2,start,Vector3.xAxis*4,exit+.14,approach,turn)
 assert((later-first).Magnitude>1.5 and enter:Dot(exitVelocity)>120,'a pending delivery snapshot stopped the exit tangent')
end

local material=Workshop.cargoKey('Amber',7)
local function loose(position,modifiers)
 scene.spawnOrePickup(bed,{owner=pl.UserId,runId=data(p).run.id,nodeId='test',units=1,raw=true,
   tierMaterial='Amber',material=material,value=7,modifiers=modifiers,floor=position.Y,fieldPart=bed},position,Vector3.zero,bed.Color)
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
local spare,spareId=loose(hr.Position+Vector3.xAxis*4-Vector3.yAxis*2)
workspace.Raycast=function(_,_,_,params)
 return not table.find(params.FilterDescendantsInstances,rock) and {Instance=rock} or nil
end
for _=1,12 do now+=C.Tick;pickupStep(C.Tick) end
assert(pickups[nearId] and not near.homing and Pro.cargoUnits(data(p))==0,'nearby rock collected without E')
assert(pl:GetAttribute('MA_OrePickup')==nearId,'reachable ore did not expose its pickup action')
commandPlayer(pl,'PickupOre',nearId)
for _=1,12 do now+=C.Tick;pickupStep(C.Tick) end
assert(not pickups[nearId] and Pro.cargoUnits(data(p))==1,'E pickup did not pass a solid mineable rock')
assert(pickups[spareId] and not spare.homing,'one pickup press pulled more than one rock')
spare.part:Destroy();pickups[spareId]=nil
workspace.Raycast=initialRay

do
 local movingGem=hr.Position-Vector3.yAxis*2
 local offered,offeredId=loose(movingGem)
 offered.firstLandedAge=.65
 local wall=Instance.new('Part')
 wall.CanCollide=true;wall.Parent=zone
 offered.courier=d;d.orePickupId=offeredId;d.oreDock=movingGem+Vector3.yAxis*5
 workspace.Raycast=function() return {Instance=wall} end
 now+=.12;pickupStep(C.Tick)
 commandPlayer(pl,'PickupOre',offeredId)
 assert(pickups[offeredId] and d.orePickupId==offeredId and not offered.homing,'blocked pickup took priority through scenery')
 workspace.Raycast=initialRay
 -- Move before the cached obstructed ray expires; collection should respond now.
 pl.Character:PivotTo(CFrame.new(hr.Position+Vector3.zAxis*1.5))
 now+=.12;pickupStep(C.Tick)
 assert(pl:GetAttribute('MA_OrePickup')==offeredId and d.orePickupId==offeredId and not offered.homing,'the prompt preempted a courier before E')
 commandPlayer(pl,'PickupOre',offeredId)
 assert(not d.orePickupId and not d.oreDock and not offered.part:GetAttribute('CourierDocking'),'nearby player did not take over a reserved pickup')
 for _=1,12 do now+=C.Tick;pickupStep(C.Tick) end
 assert(not pickups[offeredId] and Pro.cargoUnits(data(p))==2 and Pro.droneCargoUnits(data(p),d.id)==0,'pickup did not credit the player exactly once')
 run.cargo[material]-=1
 pl.Character:PivotTo(CFrame.new(center+Vector3.new(20,3,0)))
 wall:Destroy()
end

local drop,id=loose(center+Vector3.yAxis*.22)
local extra,extraId=loose(center+Vector3.new(5,.22,0))
drop.age=Workshop.COMPACTOR_PAIR_WINDOW+.1;extra.age=drop.age
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
local exitAt=d.oreSeatUntil
local exitPosition,exitVelocity=Workshop.courierSwoop(d.oreDock,d.oreYaw,d.oreEntryOffset,d.oreEntryVelocity,
 exitAt-d.pickupAt,d.oreApproachTime,d.oreReturnTurn)
now=exitAt+.01
scene.collectGroundCargo(d,p,hr,C.Tick)
assert(math.abs((d.pos-exitPosition):Dot(exitVelocity.Unit)-.11)<.012 and d.velocity:Dot(exitVelocity.Unit)>10.5
 and d.deliveryRequested,'the flight solver lost momentum or integrated the exit tick twice')
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

do
 for id,drop in pairs(pickups) do drop.part:Destroy();pickups[id]=nil end
 local press=assert(p.compactor)
 local spot=p.miningSquare.center+Vector3.yAxis*.22
 local first,firstId=loose(spot-Vector3.xAxis*2)
 local second,secondId=loose(spot+Vector3.xAxis*2)
 local big=Mining.ROCK_MODIFIERS.Big
 local charged=Mining.ROCK_MODIFIERS.Charged
 local third,thirdId=loose(spot-Vector3.xAxis*3,bit32.bor(big,charged))
 local fourth,fourthId=loose(spot+Vector3.xAxis*3,big)
 local tint=Color3.fromRGB(255,153,20)
 third.part.Color=tint
 assert(not third.part:GetAttribute('ExpiresAt') and not scene.oreExpired(third,now+3600),'modified rocks can still fade')
 assert(scene.oreExpired(first,now+3600),'normal rocks stopped expiring')
 press.pos=spot+Vector3.new(13,8,0);press.velocity=Vector3.zero
 pickupStep(C.Tick)
 local job=assert(press.pressJob,'nearby matching rocks were ignored')
 assert((press.pos-job.position).Magnitude>3 and not job.castAt,'press grappled before flying to its clearing')
 assert(table.find(job.ids,thirdId) and table.find(job.ids,fourthId) and not first.pressCarrier and not second.pressCarrier,
  'the larger matching pair did not take priority')
 local before=press.pos
 droneStep(press,C.Tick)
 assert((press.pos-before).Magnitude>0 and press.state=='Intake','press did not fly toward the clearing')
 press.pos=job.position
 now+=.1;pickupStep(C.Tick)
 assert(third.part:GetAttribute('PressMarked') and fourth.part:GetAttribute('PressMarked') and job.castAt>now,'the two rocks were not marked before launch')
 now=job.castAt+Workshop.GRAPPLE_CAST+Workshop.GRAPPLE_REEL*.5;pickupStep(C.Tick)
 assert(third.homing and fourth.homing and third.y>spot.Y and fourth.y>spot.Y,'the grapples did not reel both rocks')
 scene.resetPress(press,true)
 assert(not third.pressCarrier and not fourth.pressCarrier and third.y==spot.Y and not third.part:GetAttribute('PressMarked'),
  'an interrupted pull did not return both rocks and clear their marks')
 now+=1.1;pickupStep(C.Tick)
 job=assert(press.pressJob)
 press.pos=job.position
 pickupStep(C.Tick)
 now=job.castAt+Workshop.GRAPPLE_CAST+Workshop.GRAPPLE_REEL+.01;pickupStep(C.Tick)
 assert(third.pressSocket and fourth.pressSocket and job.finishAt>now,'both rocks must be seated before the timer starts')
 snapshotDrone(press)
 assert(press.model:GetAttribute('PressFinish')==job.finishAt and press.model:GetAttribute('PressStarted')==job.startedAt)
 now=job.finishAt-.01;pickupStep(C.Tick)
 assert(pickups[thirdId] and pickups[fourthId],'the output arrived before processing finished')
 now=job.finishAt+.01;pickupStep(C.Tick)
 local merged=assert(pickups[pickupSerial])
 local key,value,isBlock=Workshop.crystalCargo(merged.material)
 assert(not pickups[thirdId] and not pickups[fourthId] and pickups[firstId] and pickups[secondId])
 assert(key=='Amber' and value==14 and not isBlock and merged.part.Color==tint,'merging changed mineral, value or tint')
 assert(Mining.sizeTier(merged.modifiers)==3 and bit32.btest(merged.modifiers,charged) and merged.arc and merged.part.Size.X>third.part.Size.X)
 assert(not Mining.nextSizeMask(big,0) and Mining.sizeTier(Mining.nextSizeMask(0,0))==2
  and Mining.sizeTier(Mining.nextSizeMask(1,1))==4 and not Mining.nextSizeMask(16,16))
 for id,drop in pairs(pickups) do drop.part:Destroy();pickups[id]=nil end
end
print('PASS Compactor flies before marking and reeling the largest matching pair, preserves inputs on cancellation, and ejects a lasting larger ore')

do
 local press=assert(p.compactor)
 local spot=p.miningSquare.center+Vector3.yAxis*.22
 now+=Workshop.PRESS_RECOVER+1
 press.pos=spot+Vector3.new(36,20,-18);press.velocity=Vector3.zero
 local first,firstId=loose(spot-Vector3.xAxis*9)
 local firstPosition=Vector3.new(first.x,first.y,first.z)
 assert(not scene.emptierCanCollect(p,first,firstId,hr),
  'an Emptier could take the first rock before the Compactor gets a pair')
 pl.Character:PivotTo(CFrame.new(firstPosition+Vector3.yAxis*3))
 first.queryAt=0
 assert(scene.playerCanPickOre(p,first,firstId,hr,firstPosition,9),'the pairing window blocked manual pickup')
 pickupStep(C.Tick)
 snapshotDrone(press)
 assert(not press.pressJob and press.model:GetAttribute('PressWaiting'))
 for _=1,120 do now+=C.Tick;pickupStep(C.Tick) end
 local second,secondId=loose(spot+Vector3.xAxis*9)
 assert((press.pos-firstPosition).Magnitude>32,'fixture did not exercise the old distance limit')
 local serial=pickupSerial
 for _=1,math.ceil((Workshop.COMPACTOR_ARRIVAL_TIME+5)/C.Tick) do
  now+=C.Tick
  pickupStep(C.Tick);droneStep(press,C.Tick)
  if pickupSerial>serial then break end
 end
 local output=assert(pickups[serial+1],'Compactor did not fly to opposite sides of the pin and merge the pair on real ticks')
 assert(not pickups[firstId] and not pickups[secondId] and Mining.sizeTier(output.modifiers)==2)
 assert(output.value==first.value+second.value)
 output.part:Destroy();pickups[serial+1]=nil
 now+=Workshop.PRESS_RECOVER+.5
 local lone,loneId=loose(spot)
 lone.age=Workshop.COMPACTOR_PAIR_WINDOW+.1
 assert(scene.emptierCanCollect(p,lone,loneId,hr),'a lone rock never became available for sale')
 lone.part:Destroy();pickups[loneId]=nil
end
print('PASS Compactor gets first chance at fresh ore while E stays usable, flies to distant pairs, and releases unpaired rocks for sale')

do
 local press=assert(p.compactor)
 local spot=p.miningSquare.center+Vector3.yAxis*.22
 local big,massive,titan=Mining.ROCK_MODIFIERS.Big,Mining.ROCK_MODIFIERS.Massive,Mining.ROCK_MODIFIERS.Titan
 press.pos=spot+Vector3.new(0,6,-8);press.thinkUntil=now+1.0
 local first,firstId=loose(spot-Vector3.xAxis*3)
 local second=loose(spot+Vector3.xAxis*3)
 first.age=10;second.age=10
 pickupStep(C.Tick)
 assert(first.pressCarrier==press and second.pressCarrier==press and not press.pressJob.castAt,
  'the thinking drone failed to claim its pair privately')
 assert(not first.part:GetAttribute('PressMarked') and not scene.emptierCanCollect(p,first,firstId,hr))
 local middleA=loose(spot-Vector3.xAxis*4,big)
 local middleB=loose(spot+Vector3.xAxis*4,big)
 local largeA,largeId=loose(spot-Vector3.xAxis*7,massive)
 largeA.age=22;largeA.firstLandedAge=.5
 assert(not scene.emptierCanCollect(p,largeA,largeId,hr),'an unmatched Massive rock was sold before a pair could form')
 now+=.2;pickupStep(C.Tick)
 assert(press.pressJob.tier==2 and middleA.pressCarrier==press and middleB.pressCarrier==press and not first.pressCarrier)
 local largeB=loose(spot+Vector3.xAxis*7,massive)
 now+=.2;pickupStep(C.Tick)
 assert(press.pressJob.tier==3 and largeA.pressCarrier==press and largeB.pressCarrier==press
  and not middleA.pressCarrier and not press.pressJob.castAt,'a larger pair could not replace the smaller claim while thinking')
 pl.Character:PivotTo(CFrame.new(Vector3.new(largeA.x,largeA.y+2,largeA.z)))
 scene.orePromptAt=nil;pickupStep(C.Tick)
 assert(pl:GetAttribute('MA_OrePickup')==largeId,'the private mark blocked the player pickup prompt')
 scene.requestOrePickup(p,largeId)
 assert(largeA.playerPickup and not press.pressJob and not largeB.pressCarrier,
  'manual pickup should release the untouched partner before casting')
 for id,drop in pairs(pickups) do drop.part:Destroy();pickups[id]=nil end
 local _,hugeId=loose(spot,titan)
 local small,smallId=loose(spot+Vector3.xAxis*6)
 small.age=10
 now+=1.6
 d.pos=spot+Vector3.yAxis*6;d.oreDock=nil;d.orePickupId=nil;p.nextEmptierPlan=nil
 scene.assignEmptierPickups(p)
 assert(d.orePickupId==smallId and d.orePickupId~=hugeId,'the Emptier chose nearer Titan ore over smaller ore')
 for id,drop in pairs(pickups) do drop.part:Destroy();pickups[id]=nil end
end
print('PASS private thinking claims, upgrades to the largest pair, manual override and smaller Emptier priority')

do
 local press=assert(p.compactor)
 local pin=p.miningSquare
 local spot=pin.center+Vector3.yAxis*.22
 local originalCharger=scene.chargingStation
 scene.chargingStation=World.part(zone,'BatteryTestPad',spot+Vector3.zAxis*42,Vector3.new(4,1,4),bed.Color)
 press.pos=spot+Vector3.new(0,7,-7);press.velocity=Vector3.zero
 press.thinkUntil=nil;press.pressSearchAt=nil
 assert(press.stats.batteryCapacity==100 and press.battery==100,'a new Compactor must start with two merges worth of power')
 local function stepUntil(predicate,seconds,message)
  for _=1,math.ceil(seconds/C.Tick) do
   now+=C.Tick;pickupStep(C.Tick);droneStep(press,C.Tick)
   if predicate() then return end
  end
  error(message)
 end
 for merge=1,2 do
  local inputA,inputAId=loose(spot-Vector3.xAxis*3)
  local inputB,inputBId=loose(spot+Vector3.xAxis*3)
  local initial=press.battery
  local serial=pickupSerial
  stepUntil(function() return press.pressJob and press.pressJob.startedAt end,7,'press never seated both inputs')
  local job=press.pressJob
  assert(press.battery==initial,'search, approach and grapples consumed power')
  stepUntil(function() return now>=(job.startedAt+job.finishAt)*.5 end,3,'press never reached the middle of its merge')
  snapshotDrone(press)
  assert(press.model:GetAttribute('BatteryPowered') and press.model:GetAttribute('BatteryWorking'))
  assert(math.abs(press.battery-(initial-25))<1 and pickups[inputAId]==inputA and pickups[inputBId]==inputB,
   'charge did not drain during the merge or the pair ejected early')
  stepUntil(function() return pickupSerial>serial end,3,'press never ejected at the end of the merge')
  assert(math.abs(press.battery-(100-merge*50))<1e-6,'a completed merge must cost exactly 50 charge')
  local output=pickups[serial+1];output.part:Destroy();pickups[serial+1]=nil
  if merge==1 then assert(not press.recharging,'the first merge sent a half-full drone to charge') end
 end

 local waitingA=loose(spot-Vector3.xAxis*3)
 local waitingB=loose(spot+Vector3.xAxis*3)
 stepUntil(function() return press.state=='ToCharge' end,1,'an empty Compactor did not fly to the charger')
 assert(press.recharging and not press.pressJob and not waitingA.pressCarrier and not waitingB.pressCarrier and p.miningSquare==pin)
 press.pos=press.goal;press.velocity=Vector3.zero
 stepUntil(function() return press.state=='Charging' and press.battery>0 end,.5,'the charger did not refill the empty Compactor')
 assert(not press.pressJob,'the drone claimed another pair during recharge')
 stepUntil(function() return not press.recharging end,4,'the charger did not finish refilling')
 assert(press.battery==100)
 stepUntil(function() return press.pressJob~=nil end,.5,'the fully charged Compactor did not resume its plot')
 assert(waitingA.pressCarrier==press and waitingB.pressCarrier==press)
 scene.resetPress(press,true)
 for id,drop in pairs(pickups) do drop.part:Destroy();pickups[id]=nil end
 scene.chargingStation:Destroy();scene.chargingStation=originalCharger
end
print('PASS real Compactor charge drains over two merges, routes to the pad and resumes its plot on a full battery')

field.center=bed.Position;field.model=zone;field.color=bed.Color
field.cfg.AlwaysUnlocked=true;field.cfg.Key='Quartz'
field.cfg.Value=1;field.cfg.Hardness=1;field.cfg.Turrets=0;field.cfg.ReferenceCrystals=true
pl.Character:PivotTo(CFrame.new(center+Vector3.yAxis*3))
local priorRecall=p.recallSerial or 0
commandPlayer(pl,'Recall',{requestId='recall-spinner'})
assert(not p.miningSquare and pl:GetAttribute('MA_RecallSerial')==priorRecall+1)
for _,worker in ipairs(p.drones) do
 assert(worker.model:GetAttribute('RecallAt')==now,'Recall did not send a spinner receipt for '..worker.role)
end
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
 assert(kick.Unit:Dot(backward)>.99 and retreat>(role=='Needler' and .04 or .3),role..' did not push back its logical hull')
 kicks[role]=kick.Magnitude
 for _=1,2 do now+=C.Tick;droneStep(gun,C.Tick) end
 assert(gun.model:GetAttribute('FlightImpulseAt')==kickAt,'one projectile pushed twice')
 if role=='Needler' then
  local last=kickAt;local shots=1
  for _=1,121 do
   now+=C.Tick;droneStep(gun,C.Tick)
   local at=gun.model:GetAttribute('FlightImpulseAt')
   if at~=last then
    assert(at-last>=.149 and at-last<=.184,'Needler interval '..tostring(at-last)..' effective '..gun.stats.miningDPS..' base '..gun.owned.base.miningDPS)
    shots+=1;last=at
   end
  end
  local cut=DroneCatalog.cycle(role,gun.owned.base.miningDPS,gun.owned.base.miningDPS)
  assert(shots>=12 and math.abs(cut.damage/cut.duration-gun.owned.base.miningDPS*1.12)<1e-8,'Needler did not preserve its work per second')
 end
 local recoverStart=(gun.pos-station).Magnitude
 for _=1,120 do now+=C.Tick;move(gun,station,C.Tick) end
 assert((gun.pos-station).Magnitude<recoverStart*.45,'thrusters never returned the gun to the station')
 release(gun)
end
assert(kicks.Ballcaster>kicks.Needler*1.4)
print('PASS physical gun recoil, one impulse per launch, committed contact, and damped recovery')
