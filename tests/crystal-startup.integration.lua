-- Start the real controller in Crystal Run mode, including its Heartbeat callback.
assert(scene.runStart and not scene.fieldTools)
local pl=player(98901);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local expected={'Striker','Striker','Striker','Needler','Ballcaster','Vacuum','Compactor','Courier','Courier'}
assert(#p.drones==#expected)
for i,d in ipairs(p.drones) do assert(d.role==expected[i] and d.slot==i) end

local center=characterRoot(p).Position
local function advance(seconds)
 for _=1,math.ceil(seconds/C.Tick) do
  realTime+=C.Tick;heartbeat:Fire(C.Tick)
 end
end
local function verifyRing()
 for i,d in ipairs(p.drones) do
  local delta=d.pos-center
  local radius=Vector3.new(delta.X,0,delta.Z).Magnitude
  assert(d.state=='Follow' and math.abs(radius-10)<.2,('slot %d, state %s, radius %.2f'):format(i,d.state,radius))
  assert(d.model:GetAttribute('FormationSlot')==i and d.model:GetAttribute('FleetCount')==#p.drones)
  local goal=Feel.followGoal(center,i,#p.drones,now,d.owned.base.maxStep60)
  assert((d.pos-goal).Magnitude<.4,'did not converge to follow slot '..i)
 end
end
advance(3);verifyRing()
center+=Vector3.new(20,0,-30);pl.Character:PivotTo(CFrame.new(center))
advance(8);verifyRing()

do
 local previousStation,previousIndicator=scene.chargingStation,scene.chargeIndicator
 local station=World.part(scene.map,'ChargingStation',center+Vector3.new(0,-2,-25),Vector3.new(9,.8,6),Color3.new(1,1,1))
 local indicator=World.part(scene.map,'ChargeIndicator',station.Position+Vector3.yAxis*.45,Vector3.new(7,.12,4),Color3.new(1,1,1))
 scene.chargingStation=station;scene.chargeIndicator=indicator
 local other=player(98904);players.PlayerAdded:Fire(other)
 other.Character:PivotTo(CFrame.new(center))
 local recharging={}
 for _,crew in ipairs({p,profiles[other.UserId]}) do
  for _,d in ipairs(crew.drones) do
   if d.stats.batteryCapacity>0 then
    d.battery=0;d.pos=station.Position+Vector3.new(0,3,9);d.velocity=Vector3.zero
    table.insert(recharging,d)
   end
  end
 end
 local charging,full=false,false
 for _=1,170 do
  advance(.1)
  local progress=indicator:GetAttribute('ChargeProgress')
  if progress then charging=charging or progress<1;full=full or progress==1 end
 end
 assert(#recharging==10 and charging and full and indicator:GetAttribute('ChargeProgress')==nil)
 for _,d in ipairs(recharging) do
  assert(not d.recharging and d.battery==d.stats.batteryCapacity,'swarm spacing stopped a drone from reaching the charger')
 end
 players.PlayerRemoving:Fire(other)
 scene.chargingStation=previousStation;scene.chargeIndicator=previousIndicator
 station:Destroy();indicator:Destroy()
 advance(5);verifyRing()
 print('PASS two crews reach a crowded charger, publish real pad progress and fly off with full batteries')
end

-- A legacy Orbiter and Scrapper can still exist in saved fleets or Studio previews.
p.testFleet=Pro.clone(data(p).fleet)
for i,role in ipairs({'Orbiter','Scrapper'}) do
 local def=RoleConfig.StudioRoles[role]
 table.insert(p.testFleet,{id='test:'..pl.UserId..':1:'..i,type=role,role=role,name=role,base=def.base})
end
rebuildFleet(p,center);advance(3);verifyRing()
print('PASS Crystal Run boots and the full crew follows across owner movement, including legacy ability drones')

-- Recreate the exact starter grant from the prior revision and earn a real prestige drone.
local uid=98902
local old=Pro.new(uid,901)
old.fleet={old.fleet[1]}
local previousRoles={'Charger','Medic','Dart','Orbiter','Scrapper','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator','Needler','Ballcaster','Vacuum','Compactor'}
for _,role in ipairs(previousRoles) do
 local serial=#old.fleet+1
 local kind=role=='Charger' and 'Red' or role=='Medic' and 'Green' or role
 old.fleet[serial]={id=uid..':drone:'..serial,type=kind,role=role,name=role,base=Pro.clone(RoleConfig.StudioRoles[role].base)}
end
old.starterDrones=#old.fleet;old.nextDroneSerial=#old.fleet+1
old.run.quartzEarnings=360
local choice=Pro.prestigePreview(old).droneChoices[1]
local ok,earned=Pro.prestige(old,'earned-before-repair',old.run.id,{atDepot=true,confirmed=true,droneType=choice.kind})
assert(ok and earned.droneId==uid..':drone:18')
local quartz=Workshop.cargoKey('Quartz',10)
old.run.droneCargo[old.fleet[2].id]={[quartz]=1}
old.run.wallet.Quartz=Workshop.PACK_BASE;old.run.credits=Workshop.PACK_BASE
local paid,offer=Ca.buy(old,'keep-purchase',old.run.id,{atDepot=true,expectedPackIndex=0,crystalRun=true})
assert(paid)
local migrated=assert(Pro.migrate(old,uid))
assert(#migrated.fleet==8 and migrated.starterDrones==7 and migrated.nextDroneSerial==21 and migrated.prestiges==1)
assert(migrated.fleet[1].id==old.fleet[1].id and migrated.fleet[2].id==old.fleet[14].id and migrated.fleet[6].id==earned.droneId)
assert(migrated.fleet[6].base.maxStep60==old.fleet[18].base.maxStep60)
assert(migrated.run.pendingOffer.id==offer.id and migrated.run.cargo[quartz]==1)
assert(Pro.receipt(migrated,'Prestige','earned-before-repair').droneId==earned.droneId)
assert(#assert(Pro.migrate(migrated,uid)).fleet==8 and #old.fleet==18)
print('PASS oversized starter repair preserves earned drone IDs and traits, cargo, paid offers and replay receipts')

do
 local cfIndex=CF.__index
 CF.__index=function(frame,key)
  if key=='RightVector' then return Vector3.new(math.cos(frame.yaw),0,-math.sin(frame.yaw)) end
  return cfIndex(frame,key)
 end
 local runner=player(98903);players.PlayerAdded:Fire(runner)
 local crew=profiles[runner.UserId]
 local pin=scene.packStation.Position+Vector3.new(0,0,125)
 local zone=Instance.new('Folder');zone.Name='FirstPackPlot';zone.Parent=scene.map
 local bed=World.part(zone,'Field',pin-Vector3.yAxis*.5,Vector3.new(30,1,30),Color3.new(1,0,0))
 local field={id=#patches+1,cfg={Key='Quartz',Material='Quartz',Value=1,SelectionOnly=true,AlwaysUnlocked=true,
  ReferenceCrystals=true,Hardness=1,Count=2,Ore=10,Turrets=0,Respawn=30},part=bed,model=zone,center=bed.Position,color=bed.Color,
  resources={},turrets={},respawnQueue={},e=R.newEncounter(C)}
 field.e.phase='Safe';patches[field.id]=field
 runner.Character:PivotTo(CFrame.new(pin+Vector3.yAxis*3))
 advance(10)
 local run=data(crew).run
 command.OnServerEvent:Fire(runner,'PlaceSelector',{runId=run.id,fieldId=field.id,position=pin})
 assert(crew.miningSquare and crew.compactor)
 assert(runner:GetAttribute('MA_SelectorStatus')=='NoCrystals')
 local emptier=crew.drones[8]
 droneStep(emptier,C.Tick)
 assert(emptier.state=='Follow' and (emptier.intentGoal-Feel.followGoal(characterRoot(crew).Position,8,#crew.drones,now,emptier.owned.base.maxStep60)).Magnitude<.001)
 for _,x in ipairs({-4,4}) do
  local crystal=makeResource(field,bed.Position+Vector3.new(x,0,0),'Crystal',75,10,3,3)
  crystal.readyAt=now+1
 end
 scene.publishSquareStatus(crew)
 assert(runner:GetAttribute('MA_SelectorStatus')=='Growing')
 local sent,bagStarted
 for _=1,math.ceil(15/C.Tick) do
  advance(C.Tick)
  bagStarted=bagStarted or crew.emptierBagSince
  sent=next(data(crew).run.deliveries)
  if sent then break end
 end
 local manifest=assert(data(crew).run.deliveries[sent],'two mined rocks never left for the Workshop')
 local cargo=Workshop.cargoKey('Quartz',10)
 assert(manifest.cargo[cargo]==2 and not crew.compactor.pressInputs,'the press took reachable starter ore')
 assert(bagStarted and now-bagStarted<Workshop.EMPTIER_WAIT,'shipment used the normal partial-load timeout')
 scene.publishSquareStatus(crew)
 assert(runner:GetAttribute('MA_SelectorStatus')=='Hauling')
 local departure=Http:JSONDecode(runner:GetAttribute('MA_Profile'))
 assert(departure.deliveryQuartz==Workshop.PACK_BASE and departure.run.wallet.Quartz==0)
 advance(18)
 assert(data(crew).run.wallet.Quartz==Workshop.PACK_BASE and not next(data(crew).run.deliveries))
 assert(Http:JSONDecode(runner:GetAttribute('MA_Profile')).deliveryQuartz==0)
 assert(runner:GetAttribute('MA_Notice')=='+20 Quartz · Pack Counter ready')
 runner.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.yAxis*3))
 command.OnServerEvent:Fire(runner,'BuyPack',{runId=run.id,packIndex=0,txId='earned-first-pack'})
 assert(data(crew).run.pendingOffer and data(crew).run.wallet.Quartz==0)
 scene.clearSquare(crew)
 local origin=pin+Vector3.new(0,1,0)
 scene.spawnOrePickup(bed,{owner=runner.UserId,runId=run.id,nodeId='settled-test',
  material=cargo,tierMaterial='Quartz',units=1,raw=true,value=10,floor=origin.Y-.75},
  origin,Vector3.new(5,14,0),Color3.new(1,0,0))
 local dropId=pickupSerial
 local drop=pickups[dropId]
 advance(3)
 local snapshot=drop.part:GetAttribute('SnapshotAt')
 assert(drop.landed and snapshot>drop.spawnAt and drop.vx==0 and drop.vz==0)
 advance(3)
 assert(drop.part:GetAttribute('SnapshotAt')==snapshot,'stationary cargo still published movement')
 runner.Character:PivotTo(CFrame.new(Vector3.new(drop.x+9,drop.y+2,drop.z)))
 advance(.2)
 assert(drop.part:GetAttribute('SnapshotAt')>snapshot and drop.part:GetAttribute('Homing'),'pickup failed to resume movement')
 pickups[dropId]=nil;drop.part:Destroy()
 local crate=assert(crew.packDelivery)
 runner.Character:PivotTo(CFrame.new(crate.part.Position+Vector3.yAxis))
 crate.prompt.Triggered:Fire(runner)
 local offered=assert(data(crew).run.pendingOffer)
 assert(offered.opened)
 command.OnServerEvent:Fire(runner,'ChooseCard',{runId=run.id,txId='first-part',offerId=offered.id,index=1,targetDroneId=crew.drones[1].id})
 assert(#data(crew).run.cards==1)
 local rubyCenter=pin+Vector3.new(0,0,40)
 local rubyZone=Instance.new('Folder');rubyZone.Name='SecondPackPlot';rubyZone.Parent=scene.map
 local rubyBed=World.part(rubyZone,'Field',rubyCenter-Vector3.yAxis*.5,Vector3.new(30,1,30),Color3.new(1,.3,.5))
 local ruby={id=#patches+1,cfg={Name='Ruby',Key='Ruby',Material='RunRuby',Value=4,SelectionOnly=true,AlwaysUnlocked=true,
  ReferenceCrystals=true,Hardness=3,Count=1,Ore=10,Turrets=0,Respawn=120},part=rubyBed,model=rubyZone,center=rubyBed.Position,color=rubyBed.Color,
  resources={},turrets={},respawnQueue={},e=R.newEncounter(C)}
 ruby.e.phase='Safe';patches[ruby.id]=ruby
 local stone=makeResource(ruby,rubyBed.Position,'Crystal',160,10,3,3)
 runner.Character:PivotTo(CFrame.new(rubyCenter+Vector3.yAxis*3))
 advance(12)
 command.OnServerEvent:Fire(runner,'PlaceSelector',{runId=run.id,fieldId=ruby.id,position=rubyCenter,leadId=stone.id})
 assert(crew.miningSquare and crew.miningSquare.field==ruby)
 local function saleFromOneSlot(value,label)
  local filled,saleStarted
  for _=1,math.ceil(45/C.Tick) do
   advance(C.Tick)
   filled=filled or crew.emptierBagSince
   local _,parcel=next(data(crew).run.deliveries)
   if parcel then
    saleStarted=now
    local material,count=next(parcel.cargo)
    assert(count==1 and next(parcel.cargo,material)==nil and Shops.quartzValue(material)==value)
    assert(not label:find('Prestige') or not Pro.prestigePreview(data(crew)).eligible,'prestige granted while cargo was in transit')
    break
   end
  end
  assert(filled and saleStarted and saleStarted-filled<Workshop.EMPTIER_WAIT,'milestone cargo waited for the normal timeout')
  for _=1,math.ceil(35/C.Tick) do
   if not next(data(crew).run.deliveries) then break end
   advance(C.Tick)
  end
  assert(not next(data(crew).run.deliveries) and runner:GetAttribute('MA_Notice')==('+'..value..' Quartz · '..label))
  print(string.format('MODEL %s single-slot pickup %.2fs, sale %.2fs after cargo entered backpack',label,saleStarted-filled,now-filled))
 end
 saleFromOneSlot(40,'Pack Counter ready')
 assert(stone.paid and data(crew).run.wallet.Quartz==40 and data(crew).run.quartzEarnings==60)
 scene.clearSquare(crew)
 local shortfall=Pro.milestone(data(crew)).earnings-data(crew).run.quartzEarnings
 local shipment=Workshop.cargoKey('RunCobalt',shortfall,true)
 assert(Pro.addCargo(data(crew),shipment,1,10)==1)
 saleFromOneSlot(shortfall,'Prestige ready')
 assert(Pro.prestigePreview(data(crew)).eligible)
 runner.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.yAxis*3))
 assert(Pro.addCargo(data(crew),cargo,1,10)==1)
 command.OnServerEvent:Fire(runner,'Sell')
 assert(not string.find(runner:GetAttribute('MA_Notice'),'Prestige ready',1,true))

 local before=data(crew)
 local preview=Pro.prestigePreview(before)
 local picked
 for _,entry in ipairs(preview.droneChoices) do
  if DroneCatalog.Types[entry.kind] then picked=entry;break end
 end
 assert(picked)
 runner.Character:PivotTo(CFrame.new(scene.prestigeStation.Position+Vector3.yAxis*3))
 command.OnServerEvent:Fire(runner,'Prestige',{runId=run.id,txId='first-prestige',confirm=true,droneType=picked.kind})
 local after=data(crew)
 local receipt=Http:JSONDecode(runner:GetAttribute('MA_DroneReward'))
 local worker=assert(drones[receipt.droneId])
 assert(after.prestiges==1 and after.run.id~=run.id and #after.fleet==#before.fleet+1 and worker.role==picked.kind)
 assert(after.fleet[1].id==before.fleet[1].id and worker.stats.miningDPS==worker.owned.base.miningDPS*1.25)
 assert(#after.run.cards==0 and after.run.wallet.Quartz==0 and after.run.stars==0)
 assert(crew.drones[1].stats.doubleBeam==0 and crew.drones[1].stats.miningDPS==37.5)

 local small=makeResource(ruby,rubyBed.Position-Vector3.xAxis*7,'Crystal',108,8,2.15,3)
 local rich=makeResource(ruby,rubyBed.Position+Vector3.xAxis*13,'Crystal',270,14,3.8,3)
 small.readyAt=now;rich.readyAt=now
 runner.Character:PivotTo(CFrame.new(rubyCenter+Vector3.yAxis*3))
 worker.pos=rubyCenter-Vector3.xAxis*8+Vector3.yAxis*8
 command.OnServerEvent:Fire(runner,'PlaceSelector',{runId=after.run.id,fieldId=ruby.id,position=rubyCenter})
 local began=now
 local gestureAt
 for _=1,math.ceil(45/C.Tick) do
  realTime+=C.Tick;now=realTime;droneStep(worker,C.Tick)
  if worker.specialJob and not gestureAt then
   gestureAt=worker.specialJob.startedAt
   assert(worker.target==rich and math.abs(gestureAt-worker.warmAt-.8)<=C.Tick+.001,'earned miner ignored the richer same-cycle cut or stalled before its gesture')
   snapshotDrone(worker)
   assert(worker.model:GetAttribute('WarmupDuration')==.8)
  end
  if rich.paid then break end
 end
 local released=nil
 for _,drop in pairs(pickups) do if drop.owner==runner.UserId and drop.runId==after.run.id then
  assert(released==nil);released=drop
 end end
 assert(gestureAt and rich.paid and small.hp==small.maxHP-10 and released and released.nodeId==rich.id)
 assert(released.units==1 and released.value==math.floor(14*4*DroneCatalog.Types[picked.kind].Yield))
 print(string.format('MODEL prestige %s began its gesture after %.2fs and released %d Quartz cargo %.2fs after pinning',picked.kind,gestureAt-began,released.value,now-began))
 scene.clearSquare(crew)
 runner.Character:PivotTo(CFrame.new(Vector3.new(released.x,released.y+3,released.z)))
 for _=1,math.ceil(35/C.Tick) do
  if data(crew).run.wallet.Quartz>=released.value then break end
  advance(C.Tick)
 end
 assert(data(crew).run.wallet.Quartz==released.value)
 runner.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.yAxis*3))
 command.OnServerEvent:Fire(runner,'BuyPack',{runId=after.run.id,packIndex=0,txId='run-two-pack'})
 assert(data(crew).run.pendingOffer and data(crew).run.wallet.Quartz==released.value-Workshop.PACK_BASE)
 players.PlayerRemoving:Fire(runner)
 CF.__index=cfIndex
 print('PASS Crystal Run mines two rocks, leaves nearby cargo for the player and pays for the first pack through a partial Emptier trip')
 print('PASS a mined Ruby funds pack two and a single valuable block funds prestige through early courier sales')
 print('PASS the chosen permanent prestige drone cuts, sells and funds a pack on its first run-two pin')
end
