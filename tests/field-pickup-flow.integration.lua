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
workspace.Raycast=initialRay

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

local drop,id=loose(center+Vector3.yAxis*.22)
local extra,extraId=loose(center+Vector3.new(-5,.22,0))
local gem=Vector3.new(drop.x,drop.floor-.22+drop.part.Size.Y*.5,drop.z)
local dock=gem+Vector3.yAxis*1.14
d.pos=dock+Vector3.yAxis*Workshop.COURIER_CLEARANCE;d.velocity=Vector3.zero
scene.assignEmptierPickups(p)
assert(d.orePickupId==id and drop.courier==d,'nearest ore was not reserved')
scene.collectGroundCargo(d,p,hr,C.Tick)
local high=d.pos
assert(d.state=='Pickup' and (high-dock).Magnitude>5.9 and d.oreDock and pickups[id])
snapshotDrone(d)
assert((d.model:GetAttribute('CourierPickupPoint')-gem).Magnitude<.01)
scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center+Vector3.xAxis*36})
assert(p.miningSquare.center.X==36)
pl.Character:PivotTo(CFrame.new(center+Vector3.new(56,3,0)))
now+=Workshop.COURIER_SCAN*.75
scene.assignEmptierPickups(p)
scene.collectGroundCargo(d,p,hr,C.Tick)
assert((d.pos-high).Magnitude<.02 and pickups[id],'scan should hold above the reserved ore through a new pin')
now=d.pickupAt+Workshop.COURIER_SCAN+Workshop.COURIER_LOWER+.05
scene.collectGroundCargo(d,p,hr,C.Tick)
assert((d.pos-dock).Magnitude<.02 and pickups[id],'ore collected before the claw closed')
now=d.pickupAt+Workshop.COURIER_CONTACT+.01
scene.collectGroundCargo(d,p,hr,C.Tick)
assert(not pickups[id] and pickups[extraId] and Pro.droneCargoUnits(data(p),d.id)==1)
now=d.oreSeatUntil+.01
scene.collectGroundCargo(d,p,hr,C.Tick)
assert((d.pos-high).Magnitude<.02 and d.deliveryRequested,'one ore should trigger delivery after climb')
serviceDeliveries(p)
assert(Pro.deliveryUnits(data(p),d.id)==1 and Pro.cargoUnits(data(p))==1)
now+=3;droneStep(d,C.Tick)
assert(d.flightMass>1.5 and d.loadSpeed<.8,'the saved one-ore manifest did not load down the courier')
d.pos=d.goal;d.velocity=Vector3.zero;droneStep(d,C.Tick)
now+=2;droneStep(d,C.Tick);serviceDeliveries(p)
assert(data(p).run.wallet.Quartz==7 and not data(p).run.deliveries[d.id],'one ore failed to sell')
serviceDeliveries(p)
assert(data(p).run.wallet.Quartz==7,'sale was credited twice')
print('PASS raised bed commands, physical pickup path, overhead scan, repin during pickup, one-ore sale')

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
