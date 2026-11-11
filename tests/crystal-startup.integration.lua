-- Start the real controller in Crystal Run mode, including its Heartbeat callback.
assert(scene.runStart and not scene.fieldTools)
assert(root:GetAttribute('PackCounterPosition')==scene.packStation.Position)
do
 local counter=root:GetAttribute('PackCounterPosition')
 local pin=counter+Vector3.new(38,0,382)
 assert(not Mining.onDepotApproach(pin+Vector3.yAxis*3,pin,counter))
 assert(not Mining.onDepotApproach(pin+Vector3.new(0,3,-35),pin,counter))
 assert(Mining.onDepotApproach(pin:Lerp(counter,.25)+Vector3.yAxis*3,pin,counter))
 assert(Mining.onDepotApproach(counter+Vector3.yAxis*3,pin,counter))
 assert(not Mining.onDepotApproach(pin+Vector3.new(0,3,48),pin,counter))
 assert(not Mining.onDepotApproach(pin:Lerp(counter,.5)+Vector3.new(63,3,0),pin,counter))
end
local cfIndex=CF.__index
CF.__index=function(frame,key)
 if key=='RightVector' then return Vector3.new(math.cos(frame.yaw),0,-math.sin(frame.yaw)) end
 return cfIndex(frame,key)
end
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
 data(profiles[other.UserId]).run.starUpgrades.charge=1
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

do
 local tester=player(98913);players.PlayerAdded:Fire(tester)
 local crew=profiles[tester.UserId];local worker=crew.drones[1]
 local oldPad=scene.chargingStation
 local pad=World.part(scene.map,'QuickChargePad',Vector3.new(0,4.4,25),Vector3.new(9,.8,6),Color3.new(1,1,1))
 scene.chargingStation=pad
 local zone=Instance.new('Folder');zone.Name='QuickChargeTest';zone.Parent=scene.map
 local bed=World.part(zone,'Field',Vector3.new(0,3.74,414),Vector3.new(108,.6,64),Color3.new(0,1,0))
 local field={id=#patches+1,cfg={Key='Emerald',Material='RunEmerald',SelectionOnly=true,ReferenceCrystals=true,AlwaysUnlocked=true,Hardness=81,Value=256,Turrets=0},
  part=bed,model=zone,center=bed.Position,color=bed.Color,resources={},turrets={},respawnQueue={},e=R.newEncounter(C)}
 field.e.phase='Safe';patches[field.id]=field
 local center=Vector3.new(0,4.04,420)
 local r=makeResource(field,center,'Crystal',5300,10,3,7);r.readyAt=now
 local function step()
  realTime+=C.Tick;now=realTime;droneStep(worker,C.Tick)
 end
 local function startTrip(site,rock)
  site=site or field;rock=rock or r
  release(worker);worker.field=nil;worker.recharging=nil;worker.chargeSite=nil;worker.squareSearchAt=nil
  local pin=Vector3.new(rock.position.X,site.part.Position.Y+site.part.Size.Y*.5,rock.position.Z)
  tester.Character:PivotTo(CFrame.new(pin+Vector3.yAxis*3))
  crew.miningSquare={field=site,center=pin,half=15}
  assert(assignOre(crew,worker,rock));worker.squareJob=crew.miningSquare
  worker.pos=committedStation(worker,rock);worker.velocity=Vector3.zero;worker.battery=0;worker.warmAt=now
 end
 local function roundTrip()
  startTrip()
  local start=now
  local arrival,full,back
  for _=1,math.ceil(100/C.Tick) do
   step()
   if worker.state=='Charging' and not arrival then arrival=now end
   if arrival and not worker.recharging and not full then full=now end
   if full and worker.target==r and worker.warmAt then back=now;break end
  end
  assert(arrival and full and back,'worker failed to resume the original Emerald cut')
  return arrival-start,full-arrival,back-full
 end
 local outbound,dock,inbound=roundTrip()
 data(crew).run.stars=3
 tester.Character:PivotTo(CFrame.new(shopStations.Ruby.Position+Vector3.yAxis*3))
 command.OnServerEvent:Fire(tester,'BuyStarUpgrade',{runId=data(crew).run.id,upgradeId='charge',level=0,txId='emerald-quick-charge'})
 assert(Workshop.starLevel(data(crew),'charge')==1 and data(crew).run.stars==0)
 local fasterOut,fasterDock,fasterIn=roundTrip()
 assert(fasterOut<outbound*.85 and fasterIn<inbound*.85 and fasterDock<dock*.85,'Quick Charge still only shortened one part of the trip')
 print(string.format('MODEL Emerald recharge round trip %.2fs -> %.2fs (out %.2f -> %.2f, pad %.2f -> %.2f, back %.2f -> %.2f)',
  outbound+dock+inbound,fasterOut+fasterDock+fasterIn,outbound,fasterOut,dock,fasterDock,inbound,fasterIn))

 local violetBed=World.part(zone,'VioletField',bed.Position-Vector3.zAxis*64,bed.Size,Color3.fromRGB(155,106,197))
 local violet=table.clone(field)
 violet.id=#patches+1;violet.part=violetBed;violet.center=violetBed.Position;violet.resources={};violet.respawnQueue={}
 violet.cfg=table.clone(field.cfg);violet.cfg.Key='Violet';violet.cfg.Material='RunViolet';violet.cfg.Hardness=27;violet.cfg.Value=64
 patches[violet.id]=violet
 local oldRock=makeResource(violet,center-Vector3.zAxis*64,'Crystal',1800,10,3,5);oldRock.readyAt=now
 startTrip(violet,oldRock)
 for _=1,math.ceil(60/C.Tick) do
  step();if worker.target==oldRock and not worker.recharging then break end
 end
 local oldPin=crew.miningSquare
 assert(worker.target==oldRock and worker.chargedPin==oldPin and worker.state=='Travel')
 tester.Character:PivotTo(CFrame.new(center+Vector3.yAxis*3))
 command.OnServerEvent:Fire(tester,'PlaceSelector',{runId=data(crew).run.id,fieldId=field.id,position=center})
 local switchedAt=now
 step()
 assert(crew.miningSquare~=oldPin and worker.target==r and not oldRock.slots[worker.id] and worker.state=='Travel')
 snapshotDrone(worker)
 assert(math.abs(worker.model:GetAttribute('MaxStep60')-worker.stats.maxStep60*1.95)<1e-8,'switching fields ended the charged return flight')
 for _=1,math.ceil(60/C.Tick) do step();if worker.warmAt then break end end
 assert(worker.warmAt and worker.target==r)
 print(string.format('MODEL charged Violet to Emerald redirect reached warmup in %.2fs',now-switchedAt))
 step();snapshotDrone(worker)
 assert(not worker.chargedPin and worker.model:GetAttribute('MaxStep60')==worker.stats.maxStep60,'the return boost survived the start of the cut')
 resources[oldRock.id]=nil;patches[violet.id]=nil;oldRock.part:Destroy();violetBed:Destroy()

 release(worker);worker.state='Follow'
 assert(travelSpeed(worker)==worker.stats.maxStep60,'Quick Charge sped up ordinary flight')
 table.insert(data(crew).run.cards,Workshop.card(Workshop.BY_ID.Q_FIELD_CHARGE,3));publish(crew)
 startTrip();step()
 assert(worker.state=='ToCharge' and travelSpeed(worker)==worker.stats.maxStep60*1.5,'Field Charger applied a depot-flight boost')
 worker.pos=worker.intentGoal;worker.velocity=Vector3.zero;step()
 assert(worker.chargeSite=='Field' and math.abs(worker.battery-28*1.3*C.Tick)<1e-8,'Quick Charge lost its rate at the portable charger')
 players.PlayerRemoving:Fire(tester);resources[r.id]=nil;patches[field.id]=nil;zone:Destroy();pad:Destroy();scene.chargingStation=oldPad
 print('PASS Quick Charge purchase shortens both depot legs and pad time while Field Charger stays local')
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
 crate.prompt.PromptButtonHoldBegan:Fire(runner)
 advance(crate.prompt.HoldDuration+.05)
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
 runner.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.yAxis*3))
 command.OnServerEvent:Fire(runner,'BuyPack',{runId=run.id,packIndex=1,txId='second-pack'})
 local second=assert(data(crew).run.pendingOffer)
 assert(second.price==27 and data(crew).run.wallet.Quartz==13)
 local paths={}
 for index,choice in ipairs(second.choices) do paths[choice.category]=index end
 assert(paths.mining and paths.flight and paths.cargo)
 local secondCrate=assert(crew.packDelivery)
 advance(2)
 runner.Character:PivotTo(CFrame.new(secondCrate.part.Position+Vector3.yAxis))
 secondCrate.prompt.PromptButtonHoldBegan:Fire(runner)
 advance(secondCrate.prompt.HoldDuration+.05)
 secondCrate.prompt.Triggered:Fire(runner)
 assert(data(crew).run.pendingOffer.opened)
 local flight=second.choices[paths.flight]
 local target=Workshop.isHardware(flight) and crew.drones[1].id or nil
 command.OnServerEvent:Fire(runner,'ChooseCard',{runId=run.id,txId='second-choice',offerId=second.id,index=paths.flight,targetDroneId=target})
 assert(Workshop.find(data(crew),flight.cardId,target) and not data(crew).run.pendingOffer)
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
 crew.shiftReadyRun=run.id
 command.OnServerEvent:Fire(runner,'Prestige',{runId=run.id,txId='first-prestige',confirm=true,droneType=picked.kind})
 local after=data(crew)
 local receipt=Http:JSONDecode(runner:GetAttribute('MA_DroneReward'))
 local worker=assert(drones[receipt.droneId])
 assert(after.prestiges==1 and after.run.id~=run.id and #after.fleet==#before.fleet+1 and worker.role==picked.kind)
 assert(after.fleet[1].id==before.fleet[1].id and worker.stats.miningDPS==worker.owned.base.miningDPS*1.25)
 assert(#after.run.cards==0 and after.run.wallet.Quartz==0 and after.run.stars==0)
 assert(not crew.shiftReadyRun,'prestige carried a ready surge into the new run')
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
 print('PASS Crystal Run mines two rocks, leaves nearby cargo for the player and pays for the first pack through a partial Emptier trip')
 print('PASS a mined Ruby funds a second pack with distinct upgrade paths, and one valuable block funds prestige')
 print('PASS the chosen permanent prestige drone cuts, sells and funds a pack on its first run-two pin')
end
do
 local runner=player(98905);players.PlayerAdded:Fire(runner)
 local crew=profiles[runner.UserId]
 local left,right=crew.drones[8],crew.drones[9]
 local at=scene.packStation.Position+Vector3.new(0,3,90)
 runner.Character:PivotTo(CFrame.new(at))
 left.pos=at+scene.emptierOffset(1);left.velocity=Vector3.zero
 right.pos=at+Vector3.new(9,3,1);right.velocity=Vector3.zero
 local parcel=Workshop.cargoKey('Quartz',20)
 assert(Pro.addCargo(data(crew),parcel,1,10)==1)
 advance(.15)
 assert(left.state=='Pickup' and right.state=='Follow','one parcel drew two Emptiers')
 right.pos=at+scene.emptierOffset(2);right.velocity=Vector3.zero
 advance(.15)
 assert(left.pickupAt and not right.pickupAt,'the assigned Emptier lost the pickup to a closer one')
 local raycast=workspace.Raycast
 workspace.Raycast=function(self,from,direction,params)
  if from.X<at.X-.5 and (from+direction-at).Magnitude<.01 then return {Instance=scene.packStation} end
  return raycast(self,from,direction,params)
 end
 advance(.55)
 workspace.Raycast=raycast
 assert(left.state=='Follow' and left.pickupRetryAt and (right.state=='Collect' or right.state=='Pickup'),'blocked pickup did not pass to the other Emptier')
 advance(3.5)
 assert(Pro.deliveryUnits(data(crew),right.id)==1 and not data(crew).run.deliveries[left.id] and Pro.cargoUnits(data(crew))==0)
 advance(20)
 assert(data(crew).run.wallet.Quartz==20 and not next(data(crew).run.deliveries),'the passed parcel did not sell once')

 left.pos=at+scene.emptierOffset(1);left.velocity=Vector3.zero
 right.pos=at+scene.emptierOffset(2);right.velocity=Vector3.zero
 assert(Pro.addCargo(data(crew),Workshop.cargoKey('Quartz',10),8,10)==8)
 advance(.15)
 assert(left.state=='Pickup' and right.state=='Pickup','two full parcels did not stage both Emptiers')
 assert(left.intentGoal.X<at.X and right.intentGoal.X>at.X,'two pickups shared the same side of the bag')
 advance(2.5)
 local deliveries=data(crew).run.deliveries
 assert(deliveries[left.id] and deliveries[right.id] and deliveries[left.id].id~=deliveries[right.id].id)
 assert(Pro.deliveryUnits(data(crew),left.id)==4 and Pro.deliveryUnits(data(crew),right.id)==4 and Pro.cargoUnits(data(crew))==0)
 advance(20)
 assert(data(crew).run.wallet.Quartz==100 and not next(data(crew).run.deliveries),'the two loads did not sell for their full value')
 players.PlayerRemoving:Fire(runner)
 print('PASS one Emptier holds a single pickup, passes a blocked job and shares the haul when both loads are full')
end
do
 local runner=player(98906);players.PlayerAdded:Fire(runner)
 local crew=profiles[runner.UserId]
 local miner,spare=crew.drones[1],crew.drones[2]
 local originalFloor,originalStar,originalCounter=scene.depotFloor,shopStations.Ruby.Position,scene.packStation.Position
 local zone=Instance.new('Folder');zone.Name='WidePinFixture';zone.Parent=scene.map
 scene.depotFloor=World.part(zone,'HubPad',Vector3.new(0,3.5,0),Vector3.new(100,1,96),Color3.new(1,1,1))
 shopStations.Ruby.Position=Vector3.new(-18,5.5,-30);scene.packStation.Position=Vector3.new(-38,5.5,32)
 local center=Vector3.new(0,4.04,148)
 local bed=World.part(zone,'Field',center-Vector3.yAxis*.3,Vector3.new(108,.6,64),Color3.new(1,0,0))
 local field={id=#patches+1,cfg={Name='Quartz',Key='Quartz',Material='Quartz',Value=1,SelectionOnly=true,AlwaysUnlocked=true,
  ReferenceCrystals=true,Hardness=1,Count=2,Ore=10,Turrets=0,Respawn=30},part=bed,model=zone,center=bed.Position,
  color=bed.Color,resources={},turrets={},respawnQueue={},e=R.newEncounter(C),clusters={bed}}
 field.e.phase='Safe';patches[field.id]=field
 local active=makeResource(field,center-Vector3.xAxis*4,'Crystal',1010,10,3,3)
 local rim=makeResource(field,center+Vector3.xAxis*17,'Crystal',110,10,2,3)
 active.readyAt=now;rim.readyAt=now
 local profile=data(crew);profile.run.stars=2
 local function widen()
  command.OnServerEvent:Fire(runner,'BuyStarUpgrade',{runId=profile.run.id,upgradeId='selector',level=0,txId='fixture-wide'})
 end
 runner.Character:PivotTo(CFrame.new(center+Vector3.yAxis*3))
 command.OnServerEvent:Fire(runner,'PlaceSelector',{runId=profile.run.id,fieldId=field.id,position=center,leadId=active.id})
 local square=assert(crew.miningSquare)
 assert(square.half==15 and runner:GetAttribute('MA_SelectorWidth')==30)
 scene.squareStep(crew,miner);miner.pos=committedStation(miner,active);miner.mining=true;miner.warmAt=now
 assert(hitResource(miner,active,25) and miner.target==active and active.lastHitAt==now)
 scene.squareStep(crew,spare);assert(not spare.target,'the outer rock was inside the old pin')
 widen();assert(Workshop.starLevel(data(crew),'selector')==0 and square.half==15,'a remote purchase widened the pin')
 for _,point in ipairs({Vector3.new(0,7,62),Vector3.new(40,7,57),Vector3.new(38,7,32),Vector3.new(-18,7,-30)}) do
  runner.Character:PivotTo(CFrame.new(point));recallFromField(crew)
  assert(crew.miningSquare==square and miner.target==active and miner.squareJob==square,'a depot visit recalled the crew')
 end
 widen()
 assert(Workshop.starLevel(data(crew),'selector')==1 and data(crew).run.stars==0)
 assert(crew.miningSquare==square and square.half==17 and runner:GetAttribute('MA_SelectorWidth')==34)
 assert(miner.target==active and active.slots[miner.id] and miner.warmAt and miner.squareJob==square)
 widen();assert(square.half==17 and runner:GetAttribute('MA_SelectorWidth')==34 and data(crew).run.stars==0)
 now+=.25
 scene.squareStep(crew,spare)
 assert(spare.target==rim and spare.squareJob==square,'the wider order did not claim the newly covered crystal')
 runner.Character:PivotTo(CFrame.new(Vector3.new(115,7,30)));recallFromField(crew)
 assert(not crew.miningSquare and not miner.target and not spare.target and not runner:GetAttribute('MA_SelectorWidth'))
 players.PlayerRemoving:Fire(runner)
 resources[active.id]=nil;resources[rim.id]=nil;zone:Destroy();patches[field.id]=nil
 scene.depotFloor,shopStations.Ruby.Position,scene.packStation.Position=originalFloor,originalStar,originalCounter
 print('PASS the saved Wider Selector upgrade expands the working pin during a depot visit and admits an outer crystal')
end
do
 local runner=player(98907);players.PlayerAdded:Fire(runner)
 local crew=profiles[runner.UserId]
 local left,right=crew.drones[8],crew.drones[9]
 runner.Character:PivotTo(CFrame.new(shopStations.Ruby.Position+Vector3.yAxis*3))
 data(crew).run.stars=6
 command.OnServerEvent:Fire(runner,'BuyStarUpgrade',{runId=data(crew).run.id,upgradeId='autosell',level=0,txId='fixture-auto-sell'})
 assert(Workshop.starLevel(data(crew),'autosell')==1 and data(crew).run.stars==0)

 local at=scene.packStation.Position+Vector3.new(0,3,90)
 runner.Character:PivotTo(CFrame.new(at))
 left.pos=at+scene.emptierOffset(1);left.velocity=Vector3.zero
 right.pos=at+scene.emptierOffset(2);right.velocity=Vector3.zero
 local full=Ca.capacity(data(crew))
 assert(Pro.addCargo(data(crew),'Quartz',full-1,full)==full-1)
 advance(.15)
 assert(left.pickupAt and right.pickupAt,'Auto Sell blocked pickups from a partial bag')
 -- A final ore drop can fill the bag after an Emptier has requested its load.
 left.pickupAt=now-RoleConfig.Courier.PickupHold-.05;left.deliveryRequested=true
 assert(Pro.addCargo(data(crew),'Quartz',1,full)==1)
 serviceDeliveries(crew)
 assert(Pro.cargoUnits(data(crew))==full and not next(data(crew).run.deliveries),'a queued Emptier took ore from a full Auto Sell bag')
 advance(.4)
 assert(Pro.cargoUnits(data(crew))==0 and data(crew).run.wallet.Quartz==full)
 assert(runner:GetAttribute('MA_Notice')=='Auto Sell · +'..full..' Quartz')

 local batch=Workshop.emptierBatch(data(crew))
 assert(Pro.addCargo(data(crew),'Quartz',batch,full)==batch)
 advance(2)
 local loaded=data(crew).run.deliveries[left.id] or data(crew).run.deliveries[right.id]
 assert(loaded and Pro.cargoUnits(data(crew))==0,'Auto Sell prevented a later partial pickup')
 assert(Pro.addCargo(data(crew),'Quartz',full,full)==full)
 advance(.4)
 assert(Pro.cargoUnits(data(crew))==0 and data(crew).run.wallet.Quartz==2*full)
 assert(runner:GetAttribute('MA_Notice')=='+'..full..' Quartz · Pack Counter ready')
 advance(20)
 assert(data(crew).run.wallet.Quartz==2*full+batch and not next(data(crew).run.deliveries),'the in-flight load failed to sell once')
 players.PlayerRemoving:Fire(runner)
 print('PASS Auto Sell takes a full bag while the Emptiers handle partial bags and finish existing loads')
end
CF.__index=cfIndex
