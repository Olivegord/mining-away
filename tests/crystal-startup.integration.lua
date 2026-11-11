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
 for _,x in ipairs({-4,4}) do
  local crystal=makeResource(field,bed.Position+Vector3.new(x,0,0),'Crystal',75,10,3,3)
  crystal.readyAt=now
 end
 local run=data(crew).run
 command.OnServerEvent:Fire(runner,'PlaceSelector',{runId=run.id,fieldId=field.id,position=pin})
 assert(crew.miningSquare and crew.compactor)
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
 advance(18)
 assert(data(crew).run.wallet.Quartz==Workshop.PACK_BASE and not next(data(crew).run.deliveries))
 runner.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.yAxis*3))
 command.OnServerEvent:Fire(runner,'BuyPack',{runId=run.id,packIndex=0,txId='earned-first-pack'})
 assert(data(crew).run.pendingOffer and data(crew).run.wallet.Quartz==0)
 players.PlayerRemoving:Fire(runner)
 CF.__index=cfIndex
 print('PASS Crystal Run mines two rocks, leaves nearby cargo for the player and pays for the first pack through a partial Emptier trip')
end
