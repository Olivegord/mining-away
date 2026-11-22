-- Server simulation, validated intent, and durable profile boundaries.
-- The builder lexically provides Config/Feel/Mining/Rules/Profile/Cards/Persistence/World.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Debris=game:GetService('Debris')
local RoleConfig: any,RoleEffects: any,DiscoveryService: any=DroneConfig,DroneRoleEffects,MiningDiscoveries
local C: any,R: any=Config,Rules
local Pro: any,Ca: any=Profile,Cards
-- An opt-in showroom cast. Nearby players share one clock and a single visual pass.
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
 if prompt.Name ~= "CastWindV1" then return end
 local root = workspace:FindFirstChild("VERSION 1")
 if not root or root:GetAttribute("WindVortexVersion") ~= 1 then return end
 local switch = root:FindFirstChild("Replay")
 if not switch or prompt.Parent ~= switch or not prompt.Enabled then return end
 local character = player.Character
 local body = character and character:FindFirstChild("HumanoidRootPart")
 if not body or (body.Position-switch.Position).Magnitude > prompt.MaxActivationDistance+2 then return end
 local now = workspace:GetServerTimeNow()
 local previous = root:GetAttribute("CastAt")
 if previous and now-previous < 4.6 then return end
 root:SetAttribute("CastAt", now + .10)
end)
local scene: any=World.initialize()
World.placeStart(scene)
World.applyQuarryTextures(scene)
local root,home=scene.root,scene.home
root:SetAttribute('FieldToolsEnabled',scene.runStart==nil)
if scene.flatFields then root:SetAttribute('WholeFields',true) end
if scene.runStart then root:SetAttribute('StarterLookAt',scene.runStart) end
if scene.runStart then
 root:SetAttribute('PackCounterPosition',scene.packStation.Position)
 local depot=scene.map:FindFirstChild('SimpleFlatTestMap')
 local floor=depot and depot:FindFirstChild('HubPad')
 if floor and floor:IsA('BasePart') then
  scene.depotFloor=floor
  root:SetAttribute('DepotFloorFrame',floor.CFrame);root:SetAttribute('DepotFloorSize',floor.Size)
 end
end
local function folder(parent,name)
 local f=Instance.new('Folder');f.Name=name;f.Parent=parent;return f
end
local droneFolder=root:FindFirstChild('Drones') or folder(root,'Drones')
local net=folder(RS,'MiningAway')
local command=Instance.new('RemoteEvent');command.Name='Command';command.Parent=net
do local event=Instance.new('RemoteEvent');event.Name='Sale';event.Parent=net end
-- Runtime entity graphs are mutually recursive. Keep their dynamic Roblox
-- boundaries explicit rather than expanding an unbounded inferred table type.
local profiles: {[number]: any}={}
local drones: {[string]: any}={}
local swarmGrid: any=nil
local patches: {any}={}
scene.patchById=scene.flatFields and {} or patches
scene.squareFields={}
scene.cubeCruiseHeight=20
local resources: {[string]: any}={}
local logistics: any=nil
local consumableService: any=nil
scene.loading={}
-- At most one replacement Player may wait per user. A reconnect cannot acquire
-- another lease until the retiring local session is saved and released.
scene.pendingJoins={}
local now=workspace:GetServerTimeNow()
local elapsed,snapshotElapsed,autosaveElapsed=0,0,0
local seed=Random.new()
local instanceId=(game.JobId~='' and game.JobId or Http:GenerateGUID(false))
local inStudio=RunService:IsStudio()
local preview=inStudio or game.GameId==0
-- Runtime-only test perks: never add cards, upgrades or fleet ownership to a save.
local testPerks={scope='Fleet',effects={plotAuto=1,capacity=C.Capacity/Ca.BASE_CAPACITY-1}}
local function previewPerks(p) return p and p.testFleet and testPerks or nil end
local adapter
if preview then adapter=Persistence.previewAdapter('MiningAwayPreview:'..instanceId)
else adapter=Persistence.dataStore(game:GetService('DataStoreService'):GetDataStore('MiningAwayProfiles_v2')) end
local store=Persistence.new(adapter,{
 owner=instanceId,now=os.time,wait=task.wait,leaseSeconds=180,maxAttempts=3,
 newProfile=function(uid)
  local profile=Pro.new(uid,seed:NextInteger(1,2147483000),scene.runStart and RoleConfig or nil,scene.flatFields)
  if scene.runStart then profile.run.cargo=Workshop.starterCargo(profile.seed) end
  return profile
 end,
 migrate=function(data,uid) return Pro.migrate(data,uid) end,validate=Pro.validate,
})
root:SetAttribute('PersistenceMode',preview and 'PREVIEW • isolated temporary profiles' or 'DataStore • session-locked')
root:SetAttribute('Build','restore-feel-prestige')
local function data(p: any): any return p.session.data end
local function healthy(p: any) return p and not p.leaving and not p.busy and store:healthy(p.session) end
local function notice(p,message)
 if p.player.Parent then p.player:SetAttribute('MA_Notice',message) end
end
local function publish(p)
 if not p.player.Parent then return end
 local copy={}
 for key,value in pairs(data(p)) do if key~='seed' and key~='receipts' then copy[key]=Pro.clone(value) end end
 copy.capacity=Ca.capacity(copy,previewPerks(p));copy.cargoUnits=Pro.cargoUnits(copy);copy.nextPackPrice=Ca.price(copy);copy.packSpeed=Shops.packSpeed(copy);copy.packCurrency=Shops.PACK_CURRENCY;copy.prestigePreview=Pro.prestigePreview(data(p))
 copy.workshop=Ca.workshopRows(copy)
 local magnetBonus=Ca.magnetBonus(copy)*Workshop.ORE_REACH_SCALE
 p.magnetRange=OreDrops.MAGNET_RANGE+magnetBonus;p.cargoReach=OreDrops.CARGO_REACH+magnetBonus
 p.fieldCharge=Workshop.effect(copy,'fieldCharge')
 p.pressDuration=Workshop.pressDuration(copy)
 p.shiftSeconds=Workshop.effect(copy,'shiftRelay')
 p.vacuumReach=Workshop.starLevel(copy,'vacuum')>0 and 76 or 64
 copy.storageCapacity=Logistics.CAPACITY
 if logistics and logistics.view then copy.logisticsStates=logistics:view(p) end
 copy.deliveryUnits=0;copy.deliveryQuartz=scene.runStart and Pro.deliveryQuartz(copy) or 0
 for _,manifest in pairs(copy.run.deliveries) do
  for _,units in pairs(manifest.cargo) do copy.deliveryUnits+=units end
 end
 -- The active preview crew is presentation data, never permanent ownership.
 if scene.runStart or p.testFleet or Workshop.starLevel(copy,'vacuum')>0 or Workshop.starLevel(copy,'cultivator')>0 then
  copy.activeFleet=Pro.clone(scene.runtimeFleet(p))
 end
 copy.testCrewActive=p.testFleet~=nil
 copy.droneStats={};copy.droneRoles={};for _,d in ipairs(p.drones) do copy.droneStats[d.id]=d.stats;copy.droneRoles[d.id]=d.role end
 local autoMine,autoHaul=scene.runStart~=nil,Workshop.starLevel(copy,'autosell')>0
 for _,d in ipairs(p.drones) do
  autoMine=autoMine or (DroneRoles.isWorker(d.role) and (d.stats.plotAuto or 0)>0);autoHaul=autoHaul or d.role=='Courier'
 end
 p.player:SetAttribute('BackpackUnits',copy.cargoUnits);p.player:SetAttribute('BackpackCapacity',copy.capacity)
 p.player:SetAttribute('StorageUnits',Logistics.bagUnits(copy.run.logistics.storage))
 p.player:SetAttribute('StorageCapacity',Logistics.CAPACITY)
 p.player:SetAttribute('LaunchCargoUnits',Logistics.bagUnits(copy.run.logistics.launchCargo))
 p.player:SetAttribute('AutomationMineEnabled',autoMine);p.player:SetAttribute('AutomationHaulEnabled',autoHaul)
 p.player:SetAttribute('QueuedOreCount',#(p.oreQueue or {}))
 p.player:SetAttribute('QueuedOreIds',Http:JSONEncode(p.oreQueue or {}))
 copy.seed=nil;copy.receipts=nil
 if p.recentSales then
  for _,receipt in ipairs(p.recentSales) do
   if receipt.runId==copy.run.id and now-receipt.at<12 then
    copy.recentSales=copy.recentSales or {}
    table.insert(copy.recentSales,receipt)
   end
  end
 end
 if scene.runStart then copy.consumables=nil end
 if copy.run.pendingOffer then
  copy.run.pendingOffer.seed=nil
  if copy.run.pendingOffer.opened==false then copy.run.pendingOffer.choices=nil end
 end
 copy.saveMode=preview and 'Preview — temporary profiles' or 'Saved profile';copy.pendingTransaction=p.busy or p.session.readOnly or false
 p.player:SetAttribute('MA_Profile',Http:JSONEncode(copy))
 if scene.fieldTools then scene.fieldTools:refreshStock(p) end
 p.player:SetAttribute('MA_SaveStatus',p.session.lost and 'Session lost — progress paused' or (p.session.readOnly and 'Save uncertain — reconciling' or (preview and 'PREVIEW • not saved across restarts' or 'Saved • autosave active')))
end
function scene.applyWalkSpeed(p)
 local humanoid=p.player.Character and p.player.Character:FindFirstChildOfClass('Humanoid')
 if humanoid then humanoid.WalkSpeed=16+2*Workshop.starLevel(data(p),'walk') end
end
local function characterRoot(p: any): any
 local ch=p.player.Character;local h=ch and ch:FindFirstChildOfClass('Humanoid');local hr=ch and ch:FindFirstChild('HumanoidRootPart')
 return h and h.Health>0 and hr or nil
end
local function atStation(p,station,radius)
 local hr=characterRoot(p);return hr and station and (hr.Position-station.Position).Magnitude<(radius or 18)
end
local function atHome(p)
 local hr=characterRoot(p);return hr and ((hr.Position-home).Magnitude<30 or (scene.printer and (hr.Position-scene.printer.Position).Magnitude<16))
end
-- Orders belong to a field footprint with a forgiving walking margin.
local function nearMiningField(position,field)
 local localPoint=field.part.CFrame:PointToObjectSpace(position)
 return math.abs(localPoint.X)<=field.part.Size.X*.5+18 and math.abs(localPoint.Z)<=field.part.Size.Z*.5+18 and math.abs(localPoint.Y)<=45
end
local function updateSlots(r)
 local count=0;for _ in pairs(r.slots) do count=count+1 end
 if r.part and r.part.Parent then
  r.part:SetAttribute('SlotsUsed',count)
  r.part:SetAttribute('SlotCapacity',math.max(r.limit or 1,count))
 end
end
local function sameRockType(d,r,allowCrewAssist: boolean?)
 -- Shared pin assignments and Aftershock may span roles within one crew.
 local role=DroneRoles.canonical(d.role)
 if r.clusterShot and r.clusterShot.drone~=d then return false end
 if role=='Nomad' and r.kind=='Geode' and not r.field.cfg.ContinuousCrystals then return false end
 for id in pairs(r.slots) do
  local worker=drones[id]
  if not worker or worker.owner~=d.owner or (not allowCrewAssist and DroneRoles.canonical(worker.role)~=role) then return false end
 end
 -- Autonomous orbital/scrap drones also occupy their real current job.
 -- Player-placed consumables have no actor reservation and remain tools.
 for _,p in pairs(profiles) do
  local ability=p.ability
  if ability and ability.runId==data(p).run.id then
   local function conflicts(id,target)
    local worker=id and drones[id]
    return target==r.id and worker and worker.hp>0 and (worker.owner~=d.owner or (not allowCrewAssist and DroneRoles.canonical(worker.role)~=role))
   end
   if ability.charge and now<=ability.charge.expires and conflicts(ability.charge.actorId,ability.charge.targetId) then return false end
   if ability.burn and ability.burn.remaining>0 and conflicts(ability.burn.actorId,ability.burn.targetId) then return false end
   if ability.swarm and now<ability.swarm.expires then
    for _,bot in ipairs(ability.swarm.bots) do if conflicts(ability.swarm.actorId,bot.targetId) then return false end end
   end
  end
 end
 return true
end
local function release(d: any,keepCombatEffects: boolean?,keepBreakContact: boolean?): ()
 if d.specialJob and d.specialJob.projectile and not d.specialJob.impacted then d.specialJob.projectile:Destroy() end
 if d.specialJob and d.target and not d.target.paid and d.target.part:GetAttribute('EffectDrone')==d.id then
  d.target.part:SetAttribute('EffectCancelledSerial',d.specialJob.serial);d.target.part:SetAttribute('EffectType',nil)
 end
 if d.specialRecovery and d.specialRecovery.part.Parent and d.specialRecovery.part:GetAttribute('EffectDrone')==d.id then
  local part=d.specialRecovery.part
  part:SetAttribute('EffectPausedAt',0);part:SetAttribute('EffectCancelledSerial',d.specialRecovery.serial)
 end
 d.specialJob=nil;d.nextNeedleAt=nil;d.specialRecovery=nil;d.specialPausedAt=nil;d.obstructedAt=nil;d.manualTarget=nil
 d.specialClear=nil;d.specialQueryAt=nil
 d.resumeResourceId=nil;d.resumePin=nil;d.chargedPin=nil;d.squareHelpAt=nil
 d.chargeSite=nil
 if d.target then local r=d.target;r.slots[d.id]=nil;updateSlots(r) end
 d.target=nil;d.squareJob=nil;d.mining=false;d.beamSince=0;d.warmAt=nil;d.mineCharge=0;d.forkUntil=0;d.forkTargetId=nil;d.combatTarget=nil;d.targetPosition=nil
 d.breaker=nil;d.growPlan=nil;d.growAt=nil;d.workStation=nil;d.workSeat=nil;d.workTargetId=nil;d.workYaw=nil
 d.lingerUntil=nil;d.lingerGoal=nil
 if not keepBreakContact then d.mineBreakContact=nil end
 if not keepCombatEffects then d.chainUntil=0;d.chainTargetId=nil end
 if not keepCombatEffects then d.chargeAt=nil;d.chargeTarget=nil end
end
local function retireTarget(d,keepBreakContact)
 local finished=d.target and d.target.paid and DroneRoles.isWorker(d.role)
 local station=finished and ((d.breaker and d.breaker.station) or d.goal or d.pos)
 local impact=d.breaker
 if impact and impact.phase=='Impact' then
  -- A teammate retired the stone during its weight hold. Lift safely without
  -- applying the delayed hit to a replacement target.
  impact.phase='Recover';impact.phaseAt=now
 elseif impact and impact.phase~='Recover' then impact=nil end
 release(d,false,keepBreakContact);d.breaker=impact
 if finished then
  local p=profiles[d.owner];local hasNext=d.autoField~=nil or (p and (p.miningSquare~=nil or #(p.oreQueue or {})>0))
  d.lingerUntil=now+(hasNext and .2 or 1);d.lingerGoal=station
 end
end
local function spend(d)
 for _,p in ipairs(patches) do R.spend(p.e,d.id) end
end
local function dropFieldIfEmpty(p: any,fieldId: any)
 if not fieldId then return end
 for _,d in ipairs(p.drones) do if d.hp>0 and d.field==fieldId then return end end
 local field=scene.patchById[fieldId]
 if field then
  R.removeUser(field.e,p.player.UserId,data(p).run.id)
 end
end
local function leaveDroneField(p: any,d: any)
 local old=d.field
 release(d);spend(d);d.field=nil;d.autoField=nil;d.commandOutAt=nil
 if d.hp>0 then d.state='Return' end
 dropFieldIfEmpty(p,old)
end
local function leaveField(p: any,keepField: number?,keepBreakContact: boolean?,keepCarriers: boolean?): ()
 p.oreQueue={};p.workField=nil
 scene.clearSquare(p)
 if consumableService then consumableService:clear(p) end
 if p.ability then DroneAbilities.cancel(p.ability);RoleEffects.ClearAbility(p.player.UserId) end
 local runId=data(p).run.id
 for _,field in ipairs(patches) do
  if field.id~=keepField then
   R.removeUser(field.e,p.player.UserId,runId)
  end
 end
 for _,d in ipairs(p.drones) do if not keepCarriers or not d.carrierId then release(d,false,keepBreakContact);spend(d);d.field=nil;d.autoField=nil;d.state=d.hp>0 and 'Return' or d.state end end
end
function scene.markRecall(d)
 d.recallSerial=(d.recallSerial or 0)+1;d.recallAt=now
 d.model:SetAttribute('RecallSerial',d.recallSerial);d.model:SetAttribute('RecallAt',now)
end
function scene.recallCue(p,keepCarriers)
 p.recallSerial=(p.recallSerial or 0)+1
 p.player:SetAttribute('MA_RecallSerial',p.recallSerial);p.player:SetAttribute('MA_RecallAt',now)
 for _,d in ipairs(p.drones) do
  if d.hp>0 and (not keepCarriers or not d.carrierId) then
   d.state='Follow';scene.markRecall(d)
  end
 end
end
local function recallFromField(p)
 if not healthy(p) then return end
 local hr=characterRoot(p);if not hr then return end
 local square=p.miningSquare
 if square then
  local delta=hr.Position-square.center
  if delta.X*delta.X+delta.Z*delta.Z<=Mining.SELECTOR_LEASH^2 and math.abs(delta.Y)<=32 then return end
  -- Depot visits leave the crew working, including the shops beyond the Pack Counter.
  local floor=scene.depotFloor
  if scene.runStart and square.field.cfg.SelectionOnly and scene.packStation
   and Mining.onSelectorDepotRoute(hr.Position,square.center,scene.packStation.Position,floor and floor.CFrame,floor and floor.Size) then return end
 end
 local hasOrders=p.workField~=nil or #(p.oreQueue or {})>0
 local field=p.workField and scene.patchById[p.workField]
 if not field then
  for _,d in ipairs(p.drones) do if not d.carrierId and d.field and scene.patchById[d.field] then field=scene.patchById[d.field];hasOrders=true;break end end
 end
 if not square and (not hasOrders or not field or nearMiningField(hr.Position,field)) then return end
 leaveField(p,nil,nil,true)
 if square then notice(p,'Too far from the pin. Crew following you.') end
 scene.recallCue(p,true)
 p.publishDirty=true
end
local colors={Blue=Color3.fromRGB(86,190,255),Red=Color3.fromRGB(255,110,118),Green=Color3.fromRGB(116,230,157)}
local TEST_ROLES={}
for _,name in ipairs(RoleConfig.TypeOrder) do
 local role=RoleConfig.StudioRoles[name];colors[name]=RoleConfig.Types[name].Color
 table.insert(TEST_ROLES,{type=name,name=name,height=role.height,base=role.base})
end
function scene.runtimeFleet(p: any)
 local profile=data(p)
 local base=p.testFleet or profile.fleet
 local fleet=table.clone(base)
 if scene.runStart then
  local role=RoleConfig.StudioRoles.Courier
  for slot=1,(scene.flatFields and 0 or Workshop.EMPTIERS) do
   table.insert(fleet,{id=Workshop.emptierId(profile.run.id,slot),type='Courier',role='Courier',name='Emptier '..slot,flightHeight=role.height,base=role.base})
  end
  local hasPress=false
  for _,owned in ipairs(base) do if owned.role=='Compactor' then hasPress=true;break end end
  if not hasPress and Workshop.effect(profile,'compactor')>0 then
   role=RoleConfig.StudioRoles.Compactor
   table.insert(fleet,{id=profile.run.id..':compactor',type='Compactor',role='Compactor',name='Compactor',flightHeight=role.height,base=role.base})
  end
 end
 for _,entry in ipairs(Workshop.STAR_CATALOG) do
  if not entry.role or Workshop.starLevel(profile,entry.id)==0 then continue end
  local present=false
  for _,owned in ipairs(base) do if owned.role==entry.role then present=true;break end end
  if not present then
   local role=RoleConfig.StudioRoles[entry.role]
   table.insert(fleet,{id=profile.run.id..':'..entry.id,type=entry.role,role=entry.role,name=RoleConfig.Types[entry.role].DisplayName,
    flightHeight=role.height,base=role.base})
  end
 end
 return fleet
end
local function includePurchasedSpecials(p: any,fleet: any)
 local present={};for _,owned in ipairs(fleet) do present[owned.id]=true end
 for _,owned in ipairs(data(p).fleet) do
  if DroneCatalog.Types[owned.role] and not present[owned.id] then table.insert(fleet,Pro.clone(owned));present[owned.id]=true end
 end
 return fleet
end
local function roleTestFleet(p: any,starterOnly: boolean?)
 p.testRoll=(p.testRoll or 0)+1
 local fleet,counts={},{}
 local names={Striker='Miner',Courier='Emptier',Medic='Healer',Dart='Grower',Charger='Breaker',Orbiter='Orbital',Scrapper='Swarm'}
 local order={'Striker','Courier','Courier','Medic','Dart','Charger','Orbiter','Scrapper'}
 local optional={Starforge=true,Frostbite=true,Resonator=true,Ramiel=true,Nomad=true}
 for _,name in ipairs(DroneCatalog.Order) do if name~='Laser' and (not starterOnly or not optional[name]) then table.insert(order,name) end end
 if scene.runStart and not starterOnly then table.insert(order,'Needler');table.insert(order,'Ballcaster') end
 for i,name in ipairs(order) do
  counts[name]=(counts[name] or 0)+1
  local role=RoleConfig.StudioRoles[name]
  local owned
  if DroneCatalog.Types[name] then for _,candidate in ipairs(data(p).fleet) do if candidate.role==name then owned=Pro.clone(candidate);break end end end
  table.insert(fleet,owned or {id=string.format('test:%d:%d:%d',p.player.UserId,p.testRoll,i),type=name,role=name,name=(names[name] or RoleConfig.Types[name].DisplayName)..(name=='Courier' and ' '..counts[name] or ''),flightHeight=role.height,base=Pro.clone(role.base)})
 end
 -- Keep the real first miner's identity so named cards also work in this test.
 local miner=Pro.clone(data(p).fleet[1]);miner.role='Striker';miner.name='Miner';fleet[1]=miner
 if not starterOnly then
  local ink=Pro.clone(miner);ink.id=string.format('test:%d:%d:%d',p.player.UserId,p.testRoll,#fleet+1)
  ink.name='Inkbeam';ink.type='Blue';ink.beamVariant='Inkbeam';table.insert(fleet,ink)
 end
 p.player:SetAttribute('MA_TestLoadoutLabel',(starterOnly and 'Core crew' or 'All drone types')..' · Rock Scanner · max backpack')
 return includePurchasedSpecials(p,fleet)
end
local function randomTestFleet(p: any)
 p.testRoll=(p.testRoll or 0)+1
 local picks={TEST_ROLES[2]} -- Every preview loadout can mine; support is random.
 for _=2,seed:NextInteger(RoleConfig.Settings.TestSquadMin,RoleConfig.Settings.TestSquadMax) do
  local weight=0;for _,role in ipairs(TEST_ROLES) do weight+=RoleConfig.Types[role.type].Weight end
  local pick=seed:NextNumber(0,weight)
  for _,role in ipairs(TEST_ROLES) do pick-=RoleConfig.Types[role.type].Weight;if pick<=0 then table.insert(picks,role);break end end
 end
 for i=#picks,2,-1 do local j=seed:NextInteger(1,i);picks[i],picks[j]=picks[j],picks[i] end
 local fleet,counts={},{};for _,role in ipairs(TEST_ROLES) do counts[role.type]=0 end
 for i,role in ipairs(picks) do
  counts[role.type]+=1
  table.insert(fleet,{id=string.format('test:%d:%d:%d',p.player.UserId,p.testRoll,i),type=role.type,role=role.type,name=role.name..' '..counts[role.type],flightHeight=role.height,base=Pro.clone(role.base)})
 end
 local labels={};for _,role in ipairs(TEST_ROLES) do if counts[role.type]>0 then table.insert(labels,role.name..' '..counts[role.type]) end end
 p.player:SetAttribute('MA_TestLoadoutLabel',table.concat(labels,' · '))
 return includePurchasedSpecials(p,fleet)
end
local function spawnDrone(p,owned,slot,origin)
 local stats=Ca.stats(data(p),owned,previewPerks(p))
 local roleName=owned.role or owned.type
 local role=RoleConfig.StudioRoles[roleName]
 local flightHeight=owned.flightHeight or (role and role.height) or Feel.FollowHeight
 -- Runtime presentation lift; never rewrite a permanent drone's base traits.
 if roleName=='Striker' then flightHeight=Feel.ReferenceFollowHeight
 elseif roleName=='Nomad' then flightHeight=RoleConfig.Prominent.Nomad.altitude
 elseif roleName~='Courier' and roleName~='Charger' then flightHeight+=1.8 end
 local hr=characterRoot(p)
 origin=origin or (hr and hr.Position) or (scene.spawnPosition or home)+Vector3.new(0,4,0)
 local followHeight=roleName=='Nomad' and flightHeight or scene.followHeight({role=roleName})
 local pos=Feel.followGoal(origin,slot,#scene.runtimeFleet(p),now,owned.base.maxStep60,roleName=='Ramiel',followHeight)
 if scene.flatFields then pos=Vector3.new(pos.X,home.Y+scene.cubeCruiseHeight,pos.Z) end
 local model,body,emitter
 if scene.flatFields then
  model,body,emitter=World.cubeDrone(droneFolder,pos)
 else
  model,body,emitter=World.drone(droneFolder,RS:FindFirstChild('Drone'),pos,colors[owned.type] or RoleConfig.Types[roleName] and RoleConfig.Types[roleName].Color or colors.Blue,roleName=='Striker')
  if roleName~='Striker' then model,body,emitter=RoleConfig.decorate(model,roleName) end
 end
 model.Name='Drone_'..owned.id
 local d={id=owned.id,owner=p.player.UserId,owned=owned,name=owned.name,role=owned.role or owned.type,flightHeight=flightHeight,model=model,body=body,emitter=emitter,slot=slot,
  pos=pos,goal=pos,velocity=Vector3.zero,yaw=0,life=1,state='Follow',hp=stats.maxHealth,stats=stats,field=nil,target=nil,mining=false,battery=stats.batteryCapacity,
  beamSince=0,readyAt=0,shotAt=0,shield=0,evade=0,commandOutAt=nil,shotSerial=0,lastShotAt=0,lastCritAt=0,forkUntil=0,chainUntil=0,
  mineCharge=0,minePulseSerial=0,minePulseAt=0,minePulseTargetId='',mineBreakSerial=0,healAt=0,chargeAt=nil,swarmTraits=Feel.swarmTraits(owned.id)}
 if roleName=='Vacuum' and not p.vacuum then p.vacuum=d end
 if roleName=='Compactor' and not p.compactor then p.compactor=d end
 drones[d.id]=d;table.insert(p.drones,d);return d
end
local function rebuildFleet(p,origin)
 for _,d in ipairs(p.drones) do release(d);spend(d);drones[d.id]=nil;d.model:Destroy() end
 p.drones={};p.vacuum=nil;p.vacuumTarget=nil;p.compactor=nil
 p.nextEmptierPlan=nil
 local fleet=scene.runtimeFleet(p)
 local ids={};for _,owned in ipairs(fleet) do if owned.role=='Courier' then table.insert(ids,owned.id) end end
 if Pro.reconcileCargo(data(p),ids,scene.runStart~=nil) then p.dirty=true end
 for i,owned in ipairs(fleet) do spawnDrone(p,owned,i,origin) end
end
local function refreshStats(p)
 for _,d in ipairs(p.drones) do
  local old=d.stats.maxHealth;local stats=Ca.stats(data(p),d.owned,previewPerks(p))
  if d.hp>0 then d.hp=math.min(stats.maxHealth,math.max(1,d.hp+math.max(0,stats.maxHealth-old))) end
  d.battery=math.min(stats.batteryCapacity,(d.battery or 0)+math.max(0,stats.batteryCapacity-d.stats.batteryCapacity))
  d.stats=stats
 end
end
local function kill(d)
 if d.hp<=0 then return end
 release(d);spend(d);d.field=nil;d.autoField=nil;d.recharging=nil;d.battery=d.stats.batteryCapacity;R.reprint(d,now,C.Reprint+C.Assembly)
 d.orePickupId=nil;d.pickupAt=nil;d.oreDock=nil;d.oreYaw=nil;d.oreSeatUntil=nil;d.launchAt=nil;d.unloadAt=nil;d.deliveryArrived=false;d.deliveryRequested=false
 d.repairChargeAt=nil;d.repairTarget=nil;d.healTargetId=nil;d.healUntil=0
 d.model:SetAttribute('DeathSerial',(d.model:GetAttribute('DeathSerial') or 0)+1)
end
local function playerCanMine(p,field)
 if not field.cfg.AlwaysUnlocked and not Shops.unlocked(data(p),field.cfg.Key) then return false end
 return field.cfg.Turrets==0 or field.e.phase=='Cleared' or data(p).clearedFields[field.cfg.Key]==true
end
function scene.unlockedMiners(field)
 for _,d in pairs(drones) do
  local p=profiles[d.owner]
  if d.field==field.id and d.hp>0 and healthy(p) and data(p).clearedFields[field.cfg.Key] then return true end
 end
 return false
end
local function los(a,b,target,ignore,physicalOnly,passCrystal)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 local reference=target and target:GetAttribute('ReferenceCrystal')==true
 if physicalOnly or reference then params.RespectCanCollide=true end
 local excluded=ignore or {droneFolder}
 params.FilterDescendantsInstances=excluded
 for attempt=1,12 do
  local hit=workspace:Raycast(a,b-a,params)
  if not hit or hit.Instance==target or (target and hit.Instance:IsDescendantOf(target)) then return true end
  -- Solid to avatars, but retain the previous soft obstruction rule for
  -- reference mining beams and loose ore. Scenery and junk still block them.
  if not ((passCrystal or reference) and hit.Instance:GetAttribute('ReferenceCrystal')==true) then return false end
  if attempt==1 then excluded=table.clone(excluded) end
  table.insert(excluded,hit.Instance);params.FilterDescendantsInstances=excluded
 end
 return false
end
local function abilityLineOfSight(p,from,r)
 return los(from,r.part.Position,r.part,{droneFolder,p.player.Character})
end
scene.hazards=ToolRules.Hazards.new({players=profiles,root=characterRoot,home=home,now=function() return now end,
 clear=function(from,to,character) return los(from,to,character,{droneFolder}) end})
scene.classicCrystal=game:GetService('ServerStorage'):FindFirstChild('MiningAwayCrystal')
RoleConfig.prepareRamielHull(RS)
if scene.runStart and scene.classicCrystal then
 scene.crystalCuts={variants={}}
 local fractures=folder(net,'CrystalFractures')
 for _,name in ipairs(CrystalCuts.variants) do
  local shape=CrystalCuts.build(name,scene.crystalCuts)
  if shape then
   scene.crystalCuts[name]=shape
   local halves=CrystalCuts.split(shape,name)
   if halves then
    halves.Parent=fractures
    table.insert(scene.crystalCuts.variants,name)
   end
  end
 end
 local shell=Instance.new('Part');shell.Shape=Enum.PartType.Ball;shell.Size=Vector3.one*6
 local geodeHalves=CrystalCuts.split(shell,'Geode');shell:Destroy()
 if geodeHalves then geodeHalves.Parent=fractures end
 local originalHalves=CrystalCuts.splitOriginal(scene.classicCrystal)
 if originalHalves then originalHalves.Parent=fractures end
 table.insert(scene.crystalCuts.variants,'Original')
 for _,name in ipairs(CrystalCuts.variants) do
  local shape=scene.crystalCuts[name]
  if shape then scene.crystalCuts[name]=CrystalCuts.inset(shape) end
 end
 scene.crystalCuts.Gem=CrystalCuts.build('Gem')
 -- Couriers show the cut cargo even while the original field is streamed out.
 local cargoShape=(scene.crystalCuts.Gem or scene.classicCrystal):Clone()
 for _,child in ipairs(cargoShape:GetChildren()) do child:Destroy() end
 cargoShape.Name='CargoCrystal';cargoShape.Parent=net
 local stoneShape=(scene.crystalCuts.Crown or scene.classicCrystal):Clone()
 for _,child in ipairs(stoneShape:GetChildren()) do child:Destroy() end
 stoneShape.Name='CargoStone';stoneShape.Parent=net
 local cuts=folder(net,'CargoStoneCuts')
 for _,name in ipairs(scene.crystalCuts.variants) do
  local template=scene.crystalCuts[name] or scene.classicCrystal
  local copy=template:Clone()
  for _,child in ipairs(copy:GetChildren()) do child:Destroy() end
  copy.Name=name;copy.Color=template.Color;copy.Parent=cuts
 end
 local palette=folder(net,'CargoFieldColors')
 for _,field in ipairs(scene.fields) do
  if Workshop.CRYSTAL_BY_MATERIAL[field.cfg.Material] then
   palette:SetAttribute(field.cfg.Material,Color3.fromRGB(table.unpack(field.cfg.Color)))
  end
 end
end
scene.chargeIndicator=scene.chargingStation and scene.chargingStation.Parent:FindFirstChild('ChargeIndicator')
local resourceSerial=0
local function nodeUsage(field)
 local count=0;for _,r in ipairs(field.resources) do if not r.paid and not r.sealedDrop then count=count+(r.kind=='Geode' and not field.cfg.ContinuousCrystals and 5 or 1) end end;return count
end
local function respawnRate(field: any)
 local count=0
 for _,d in pairs(drones) do
  local p=profiles[d.owner]
  if d.field==field.id and d.hp>0 and healthy(p) and characterRoot(p) then count+=1 end
 end
 if field.cfg.ReferenceCrystals then return 1,count end
 local tuning=RoleConfig.Mining
 return math.min(tuning.RespawnRateMaximum,tuning.RespawnRateBase+math.max(0,count-1)*tuning.RespawnRatePerDrone),count
end
function scene.poseResource(r)
 local cfg,part=r.field.cfg,r.part
 if r.kind=='Geode' then part.Size=r.fullSize;return end
 local scale=cfg.ContinuousCrystals and Feel.quarryStageShape(r.stage,r.stageCount)
  or cfg.SelectionOnly and Feel.crystalStageShape(r.stage,r.stageCount) or Feel.stageScale(r.stage,r.stageCount)
 part.Size=r.fullSize*scale*Feel.rockShape(r.slice,r.heatBand)
 part.CFrame=Feel.groundedRockFrame(r.position,part.Size,part:GetAttribute('GroundY'),r.stage,r.stageSeed,part:GetAttribute('CubicRock')==false,r.referenceCrystal,r.steady,r.variedPose)
 if r.cutOffset then part.CFrame*=CFrame.new(-part.Size*r.cutOffset) end
end
local function makeResource(field,position,kind,maxHealth,ore,visualSize,stageCount,junk,modifiers,mineral)
 maxHealth=(maxHealth-10)*(field.cfg.HealthMultiplier or 1)+10
 resourceSerial=resourceSerial+1
 local template=junk and ((field.junkTemplates and field.junkTemplates:FindFirstChild(junk.template)) or field.junk:FindFirstChild(junk.template,true))
 local original=not junk and kind=='Crystal' and ((stageCount or 3)==3 or field.cfg.SelectionOnly) and scene.classicCrystal
 local variant=original and mineral and mineral.cut
 local cut=variant and scene.crystalCuts[variant]
 local part=(template or cut or original) and (template or cut or original):Clone() or Instance.new('Part')
 if variant then part:SetAttribute('CrystalCut',variant) end
 if field.cfg.ContinuousCrystals then part:SetAttribute('QuarryCrystal',true) end
 if part:IsA('Part') then
  part.Shape=kind=='Geode' and Enum.PartType.Ball or Enum.PartType.Block
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 end
 part:SetAttribute('CubicRock',not original and kind~='Geode')
 local reference=field.cfg.ReferenceCrystals==true and kind=='Crystal'
 local shell=kind=='Geode';local size=visualSize or (reference and 3 or (maxHealth/(shell and 37.5 or 25))*(kind=='Shard' and .8 or 1))
 local fullSize=original and original.Size*(size/3) or Vector3.one*size
 if cut then fullSize*=CrystalCuts.proportions(cut,original) end
 if mineral and mineral.large then fullSize=CrystalCuts.fieldSize(fullSize,mineral.large,mineral.spire,mineral.landmark) end
 if field.cfg.WholeField then fullSize*=math.min(1,5.8/fullSize.Magnitude) end
 local variedPose=field.cfg.ContinuousCrystals==true and kind=='Crystal' and not junk
 if variedPose then part:SetAttribute('VariedRockPose',true) end
 local steady=field.cfg.ContinuousCrystals==true and (modifiers==Mining.ROCK_MODIFIERS.Massive or stageCount==4)
 if steady then part:SetAttribute('SteadyCrystal',true) end
 local ground=field.part.Position.Y+field.part.Size.Y*.5
 -- Anchor every size to the bottom of the reference mesh at its original scale.
 if reference and not field.cfg.ContinuousCrystals then ground=position.Y+Feel.ReferenceCrystalPivot-fullSize.Y*1.5/size+.06 end
 local start=Vector3.new(position.X,ground,position.Z)
 local finish=Vector3.new(position.X,ground+fullSize.Y*.5-.06,position.Z)
 part.Name=junk and junk.name or kind;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=not junk;part.Size=fullSize;part.Position=finish
 if junk then
  part.Transparency=0;part.CastShadow=true
  if not template then part.Color=Color3.fromRGB(unpack(junk.color));part.Material=Enum.Material.SmoothPlastic end
  part.Reflectance=0;part:SetAttribute('JunkName',junk.name)
 elseif reference then
  -- The reference clones its opaque red union with the authored finish.
  part.Color=field.color
  if not original then part.Material=Enum.Material.SmoothPlastic end
 elseif original then
  part.Color=field.cfg.Key=='Ruby' and original.Color or field.color
  part.Material=original.Material;part.MaterialVariant='';part.Reflectance=0
 else
  part.Color=shell and Color3.fromRGB(186,193,224):Lerp(field.color,.48) or Color3.fromRGB(228,239,248):Lerp(field.color,.66)
  part.Material=Enum.Material.Slate;part.Reflectance=0
  if scene.classicCrystal then part.Material=Enum.Material.SmoothPlastic
  else World.applyOreFinish(part,field.cfg.Key=='Quartz' or field.cfg.Key=='Cobalt' or field.cfg.Key=='ImpactTest') end
 end
 if part:IsA('PartOperation') then part.UsePartColor=true end
 part.Parent=field.model
 local r={id=instanceId..':r'..resourceSerial,field=field,part=part,referenceCrystal=reference,hp=maxHealth-10,maxHP=maxHealth,fullSize=fullSize,position=finish,start=start,
  slots={},limit=(shell or (not field.cfg.SelectionOnly and (stageCount or 3)>3)) and 3 or 1,kind=kind,paid=false,ore=ore,hardness=field.cfg.Hardness or 1,spawnAt=now,readyAt=now+2,stage=0,stageCount=stageCount or 3,steady=steady,variedPose=variedPose,
  stageSeed=mineral and mineral.poseSeed or seed:NextInteger(1,1000000),removeAt=nil}
 if variedPose then r.readyAt=now+Mining.FIELD_ROCK_READY_TIME end
 r.modifiers=modifiers
 if modifiers then part:SetAttribute('RockModifiers',modifiers) end
 if junk then
  r.spawnAt=now+.18*(junk.order-1)
  r.readyAt=r.spawnAt+JunkField.FallTime+JunkField.SettleTime
 end
 local frame,top=Feel.groundedRockFrame(finish,fullSize,ground,0,r.stageSeed,original~=nil and original~=false,reference,steady,variedPose)
 part.CFrame=frame
 if mineral and mineral.landmark then r.landmarkTop=top end
 if cut then
  r.cutOffset=cut.ExtentsCFrame.Position/cut.Size
  part.CFrame*=CFrame.new(-fullSize*r.cutOffset)
  part:SetAttribute('CrystalCutOffset',r.cutOffset)
 end
 if field.cfg.SelectionOnly then
  part:SetAttribute('ZoneName',field.cfg.Name or field.cfg.Key)
  part:SetAttribute('BaseOre',1)
  part:SetAttribute('OreValue',ore*(field.cfg.Value or 1))
 end
 resources[r.id]=r;table.insert(field.resources,r)
 for k,v in pairs({ResourceId=r.id,FieldId=field.id,Kind=kind,Hardness=r.hardness,HP=maxHealth,MaxHP=maxHealth,Stage=0,StageCount=r.stageCount,Mineral=field.cfg.Material or field.cfg.Key,StageSeed=r.stageSeed,SpawnAt=r.spawnAt,ReadyAt=r.readyAt,FullSize=fullSize,FullPosition=finish,StartPosition=start,ReferenceCrystal=reference,GroundY=ground,BreakSerial=0,SlotCapacity=r.limit,SlotsUsed=0}) do part:SetAttribute(k,v) end
 return r
end
function scene.resourceStation(r,slot,quarry)
 local station=Feel.mineGoal(r.position,slot,r.limit>1,r.fullSize,r.referenceCrystal,quarry or r.landmarkTop~=nil)
 if r.field.cfg.WholeField then
  local floor=r.field.part.Position.Y+r.field.part.Size.Y*.5
  return Vector3.new(station.X,math.max(floor+scene.cubeCruiseHeight,r.position.Y+r.fullSize.Y*.7+4.5),station.Z)
 end
 if r.landmarkTop and station.Y<r.landmarkTop+4.5 then
  return Vector3.new(station.X,r.landmarkTop+4.5,station.Z)
 end
 return station
end
function scene.junkLandingOccupied(position,radius)
 for _,pl in ipairs(Players:GetPlayers()) do
  local hr=pl.Character and pl.Character:FindFirstChild('HumanoidRootPart')
  if hr and math.abs(hr.Position.Y-position.Y)<10 then
   local dx,dz=hr.Position.X-position.X,hr.Position.Z-position.Z
   if dx*dx+dz*dz<(radius+2)^2 then return true end
  end
 end
 return false
end
function scene.rockCanSolidify(r,players)
 -- Do not turn on a growing collider inside a character. Use the current
 -- staged envelope, not the larger reservation footprint or the final size.
 local part=r.part;local half=part.Size*.5
 for _,player in ipairs(players) do
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  if hr then
   local localPosition=part.CFrame:PointToObjectSpace(hr.Position)
   if math.abs(localPosition.X)<half.X+1.2 and math.abs(localPosition.Z)<half.Z+1.2
    and localPosition.Y>-half.Y-1.5 and localPosition.Y<half.Y+2.9 then return false end
  end
 end
 return true
end
function scene.replenishJunk(field)
 if now<(field.nextJunkDrop or 0) then return end
 local occupied,available={},0
 for _,r in ipairs(field.resources) do
  if not r.paid and r.part.Parent then
   local p=field.part.CFrame:PointToObjectSpace(r.position)
   table.insert(occupied,{x=p.X,z=p.Z,radius=r.fullSize.Magnitude*.5})
   if not next(r.slots) then available+=1 end -- Includes incoming work.
  end
 end
 if available>JunkField.LowWork or #occupied>=JunkField.Cap then return end
 field.nextJunkDrop=now+2.4
 local clearance=RaycastParams.new();clearance.FilterType=Enum.RaycastFilterType.Exclude
 local excluded={droneFolder}
 for _,pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(excluded,pl.Character) end end
 clearance.FilterDescendantsInstances=excluded
 local top=field.part.Position.Y+field.part.Size.Y*.5
 local props=field.junkProps or JunkField.Props
 for order=1,math.min(JunkField.BatchSize,JunkField.Cap-#occupied) do
  local index=(field.junkSerial or 0)%#props+1
  local spec=table.clone(props[index]);spec.order=order
  local radius=Vector3.one.Magnitude*spec.size*.5
  local spot=ResourcePlacement.sample(field.part.Size.X,field.part.Size.Z,radius,occupied,
   function(a,b) return seed:NextNumber(a,b) end,function(x,z)
    local center=field.part.CFrame:PointToWorldSpace(Vector3.new(x,0,z))
    if scene.junkLandingOccupied(center,radius) then return false end
    -- Test support and the whole approach envelope against the authored map.
    for sx=-1,1 do for sz=-1,1 do
     local origin=Vector3.new(center.X+sx*radius,top+JunkField.DropHeight+radius,center.Z+sz*radius)
     local hit=workspace:Raycast(origin,Vector3.new(0,top-.25-origin.Y,0),clearance)
     if not hit or hit.Instance~=field.part then return false end
    end end
    return true
   end)
  if spot then
   local position=field.part.CFrame:PointToWorldSpace(Vector3.new(spot.x,0,spot.z))
   makeResource(field,position,'Junk',spec.work+10,spec.ore,spec.size,3,spec)
   table.insert(occupied,spot);field.junkSerial=(field.junkSerial or 0)+1
  end
 end
end
scene.modifierRandom=Random.new()
local function spawnResource(field,forceKind,prepareOnly,plan,nearPin,ordinaryOnly,vacancy)
 local usage=nodeUsage(field);if usage>=field.cfg.Count then return false end
 local kind=forceKind or ((not field.cfg.SelectionOnly and field.id>1 and field.cfg.Count-usage>=5 and seed:NextNumber()<.12) and 'Geode' or 'Crystal')
 if kind=='Geode' and not field.cfg.ContinuousCrystals and field.cfg.Count-usage<5 then kind='Crystal' end
 -- Crystal Run mines ordinary rocks; geodes are discoveries left by completed cuts.
 if field.cfg.ContinuousCrystals then kind='Crystal' end
 local reference=field.cfg.ReferenceCrystals==true and kind=='Crystal'
 local boulder=not field.cfg.ReferenceCrystals and not prepareOnly and not plan and kind=='Crystal' and (usage==0 or seed:NextNumber()<Mining.BOULDER_CHANCE)
 local clearance=RaycastParams.new();clearance.FilterType=Enum.RaycastFilterType.Exclude
 local excluded={field.model,droneFolder}
 for _,player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excluded,player.Character) end end
 clearance.FilterDescendantsInstances=excluded
 local fieldTop=field.part.Position.Y+field.part.Size.Y/2
 local continuous=field.cfg.ContinuousCrystals==true
 local landmark=vacancy and vacancy.landmark
 local mineral=plan and plan.mineral or vacancy and vacancy.landmarkMineral
 if not mineral then
  local roll=seed:NextInteger(landmark and 97 or 50,100)
  mineral=if continuous and kind=='Geode' then Mining.geode(roll,field.cfg.Hardness,field.cfg.Ore)
   elseif continuous then Mining.fieldCrystal(roll,field.cfg.Hardness,field.cfg.Ore)
   elseif reference and field.cfg.SelectionOnly and field.cfg.Hardness>1 then Mining.deepCrystal(roll,field.cfg.Hardness,field.cfg.Ore)
   else Mining.resource(roll,kind,field.cfg.Hardness)
  if continuous and kind~='Geode' then
   mineral.spire=roll%3==0
   mineral.poseSeed=seed:NextInteger(1,1000000)
   mineral.landmark=landmark and landmark.shape
   if scene.classicCrystal and scene.crystalCuts then
    local available=scene.crystalCuts.variants
    local choices=landmark and CrystalCuts.landmarkCuts[landmark.shape]
     or CrystalCuts.mineralCuts[field.cfg.Material or field.cfg.Key] or available
    local cut=choices[seed:NextInteger(1,#choices)]
    mineral.cut=if table.find(available,cut) then cut else available[seed:NextInteger(1,#available)]
   end
  end
 end
 local ordinarySize=reference and not continuous and (not field.cfg.SelectionOnly or field.cfg.Hardness<=1) and 3 or mineral.size*(boulder and Mining.BOULDER_SIZE or 1)
 local massive=if plan then plan.massive else not landmark and not ordinaryOnly and field.cfg.RockModifiers and kind=='Crystal'
  and scene.modifierRandom:NextNumber()<Mining.MASSIVE_CHANCE
 if continuous and massive and mineral.stages<4 then
  local large=Mining.fieldCrystal(100,field.cfg.Hardness,field.cfg.Ore)
  mineral=table.clone(mineral)
  mineral.size=large.size;mineral.stages=large.stages;mineral.work=large.work;mineral.ore=large.ore;mineral.large=1
  ordinarySize=mineral.size
 end
 local visualSize=ordinarySize*(massive and not continuous and Mining.MASSIVE_SCALE or 1)
 local original=kind=='Crystal' and not boulder and scene.classicCrystal
 local dimensions=original and original.Size*(visualSize/3) or Vector3.one*visualSize
 if continuous and kind~='Geode' then
  local cut=mineral.cut and scene.crystalCuts[mineral.cut]
  if cut then dimensions*=CrystalCuts.proportions(cut,original) end
  dimensions=CrystalCuts.fieldSize(dimensions,mineral.large,mineral.spire,mineral.landmark)
 end
 local radius=if continuous and kind=='Geode' then dimensions.X*.56
  elseif continuous then ResourcePlacement.leaningRadius(dimensions.X,dimensions.Y,dimensions.Z,Feel.rockLean(mineral.poseSeed))
  else ResourcePlacement.radius(dimensions.X,dimensions.Y,dimensions.Z,kind,reference)
 local patch=field.part
 local preferred,bounds=landmark,nil
 local siteIndex
 if field.cfg.WholeField then
  local used={}
  for _,r in ipairs(field.resources) do
   if r.siteIndex and (not r.paid or now<(r.splitAt or 0)) then used[r.siteIndex]=true end
  end
  local wanted=plan and plan.siteIndex or vacancy and vacancy.siteIndex
  if wanted and not used[wanted] then siteIndex=wanted end
  if not siteIndex then
   for slot=1,#field.rockSites do if not used[slot] then siteIndex=slot;break end end
  end
  if not siteIndex then return false end
  preferred=field.rockSites[siteIndex]
 end
 if plan and not preferred then
  local p=patch.CFrame:PointToObjectSpace(plan.spot)
  preferred={x=p.X,z=p.Z}
 end
 if nearPin and not preferred then
  local frame=patch.CFrame
  local center=frame:PointToObjectSpace(nearPin.center)
  local right,look=frame.RightVector,frame.LookVector
  local x=nearPin.half*(math.abs(right.X)+math.abs(right.Z))
  local z=nearPin.half*(math.abs(look.X)+math.abs(look.Z))
  bounds={minX=center.X-x,maxX=center.X+x,minZ=center.Z-z,maxZ=center.Z+z}
 end
 local occupied={}
 for _,r in ipairs(field.resources) do
  if r.sealedDrop or r.landmark or (r.paid and (r.splitAt or 0)<=now) then continue end
  local p=patch.CFrame:PointToObjectSpace(r.position)
  local reserved=r.placementRadius
  if not reserved and (not reference or continuous or field.cfg.SelectionOnly and field.cfg.Hardness>1) then
   reserved=ResourcePlacement.radius(r.fullSize.X,r.fullSize.Y,r.fullSize.Z,r.kind,reference)
  end
  occupied[#occupied+1]={x=p.X,z=p.Z,radius=reserved}
 end
 for site,reservation in pairs(field.landmarkReserves or {}) do
  if site~=landmark then table.insert(occupied,reservation) end
 end
 for _,t in ipairs(field.turrets) do
  local p=patch.CFrame:PointToObjectSpace(t.body.Position)
  occupied[#occupied+1]={x=p.X,z=p.Z,radius=math.max(4,ResourcePlacement.radius(t.body.Size.X,t.body.Size.Y,t.body.Size.Z))}
 end
 local integerGrid=reference and not continuous
 if continuous and not field.cfg.WholeField and not field.crystalLayout then
  field.crystalLayout=ResourcePlacement.crystalLayout(patch.Size.X,patch.Size.Z,patch:GetAttribute('CrystalZone') or 1)
 end
 local layout=continuous and field.crystalLayout or nil
 local function draw(a,b)
   if integerGrid then return seed:NextInteger(a,b) end
   return seed:NextNumber(a,b)
 end
 local function clear(x,z)
   local candidate=patch.CFrame:PointToWorldSpace(Vector3.new(x,0,z))
   if nearPin and not Mining.selectorContains(nearPin.center,nearPin.half,candidate) then return false end
   -- Sample the rock's turn clearance against authored fixtures and scenery.
   local height=field.cfg.SelectionOnly and math.max(20,dimensions.Y+radius+1) or 64
   for _,offset in ipairs({Vector3.zero,Vector3.new(-.707,0,-.707),Vector3.new(.707,0,-.707),Vector3.new(-.707,0,.707),Vector3.new(.707,0,.707)}) do
    local origin=Vector3.new(candidate.X,field.center.Y+height,candidate.Z)+offset*radius
    if workspace:Raycast(origin,Vector3.new(0,fieldTop+.05-origin.Y,0),clearance) then return false end
    if field.cfg.SelectionOnly and workspace:Raycast(Vector3.new(origin.X,fieldTop-.05,origin.Z),Vector3.new(0,height-1,0),clearance) then return false end
   end
   return true
 end
 local selected=siteIndex and preferred or nil
 if layout and vacancy and vacancy.position and not preferred then
  local p=patch.CFrame:PointToObjectSpace(vacancy.position)
  selected=ResourcePlacement.sample(patch.Size.X,patch.Size.Z,radius,occupied,draw,clear,
   {x=p.X,z=p.Z},false,nil,nil,layout)
 end
 selected=selected or ResourcePlacement.sample(patch.Size.X,patch.Size.Z,radius,occupied,draw,clear,preferred,integerGrid,nil,bounds,layout)
 local spot=selected and patch.CFrame:PointToWorldSpace(Vector3.new(selected.x,0,selected.z))
 if not spot then
  if massive and not plan then return spawnResource(field,kind,prepareOnly,nil,nearPin,true,vacancy) end
  return false
 end
 if prepareOnly then return true,1,{spot=spot,field=field.id,mineral=mineral,massive=massive,siteIndex=siteIndex} end
 local work=mineral.work*(boulder and Mining.BOULDER_WORK or 1)
 local ore=(mineral.ore or field.cfg.Ore)*(boulder and Mining.BOULDER_WORK or 1)
 local resource=makeResource(field,spot,kind,work+10,ore,visualSize,boulder and 7 or mineral.stages or field.cfg.Cracks or 3,nil,
  massive and Mining.ROCK_MODIFIERS.Massive or nil,mineral)
 if continuous then resource.placementRadius=radius end
 resource.siteIndex=siteIndex
 if landmark then
  field.landmarkReserves[landmark]=selected
  resource.landmark=landmark;resource.landmarkMineral=mineral
 end
 return true,kind=='Geode' and not continuous and 5 or 1,resource
end
function scene.respawnEarlier(a,b) return a.at<b.at end
function scene.rockInSquare(square,rock)
 return square.field==rock.field and Mining.selectorContains(square.center,square.half,rock.position)
end
function scene.stepRockModifiers(field)
 local random=scene.modifierRandom
 local nextAt=field.nextModifierAt
 if nextAt and now<nextAt then return end
 local crews={}
 for _,p in pairs(profiles) do
  local rootPart=healthy(p) and characterRoot(p)
  if rootPart and nearMiningField(rootPart.Position,field) then table.insert(crews,{root=rootPart,pin=p.miningSquare}) end
 end
 if #crews==0 then field.nextModifierAt=nil;return end
 if not nextAt then field.nextModifierAt=now+random:NextNumber(5,9);return end
 local bits=Mining.ROCK_MODIFIERS
 local modifier=random:NextNumber()<.6 and bits.Charged or bits.Frosted
 local best,bestScore,active=nil,0,0
 for _,rock in ipairs(field.resources) do
  if rock.paid or rock.kind~='Crystal' or not rock.part.Parent then continue end
  if bit32.btest(rock.modifiers or 0,modifier) then active+=1;continue end
  if rock.cargoProduced or rock.clusterShot or now<rock.readyAt then continue end
  local weight=0
  for _,crew in ipairs(crews) do
   if (rock.position-crew.root.Position).Magnitude<=46 then
    weight=math.max(weight,crew.pin and scene.rockInSquare(crew.pin,rock) and 5 or 1)
   end
  end
  if weight>0 then
   -- Favor the current work and let a few events visibly layer.
   if rock.modifiers then weight*=2 end
   local score=random:NextNumber()^(1/weight)
   if not best or score>bestScore then best,bestScore=rock,score end
  end
 end
 if active<6 and best then
  best.modifiers=bit32.bor(best.modifiers or 0,modifier)
  best.part:SetAttribute(modifier==bits.Charged and 'ChargedAt' or 'FrostedAt',now)
  best.part:SetAttribute('RockModifiers',best.modifiers)
 end
 field.nextModifierAt=now+random:NextNumber(14,24)
end
function scene.replacementDue(field,vacancy)
 return vacancy and now>=(vacancy.regrowAt or 0) and field.respawnClock>=vacancy.at
end
function scene.replacementSquare(field,vacancy)
 local owner=vacancy.owner and profiles[vacancy.owner]
 local square=owner and not owner.leaving and owner.miningSquare
 if square and square.field==field and Mining.selectorContains(square.center,square.half,vacancy.position) then return square end
 return nil
end
function scene.spawnReplacement(field,kind,vacancy)
 if vacancy.landmark then return spawnResource(field,'Crystal',false,nil,nil,true,vacancy) end
 local square=scene.replacementSquare(field,vacancy)
 if square then
  -- Give a cleared pin two cuts to return to. Once it has mature work,
  -- replenish the rest of the field through ordinary placement.
  local growing=0
  for _,r in ipairs(field.resources) do
   if not r.paid and r.part.Parent and scene.rockInSquare(square,r) then
    growing+=1
    if now>=r.readyAt or growing>=2 then return spawnResource(field,kind,false,nil,nil,nil,vacancy) end
   end
  end
  local spawned,cost=spawnResource(field,kind,false,nil,square,nil,vacancy)
  if spawned then return true,cost end
 end
 return spawnResource(field,kind,false,nil,nil,nil,vacancy)
end
local function seedField(field)
 for _,r in ipairs(field.resources) do
  for id in pairs(r.slots) do if drones[id] then release(drones[id]) end end
  resources[r.id]=nil;r.part:Destroy()
 end
 field.resources={};field.respawnQueue={};field.respawnClock=now
 if field.cfg.WholeField then
  local bed=field.part
  field.rockSites=ResourcePlacement.squareRockSites(bed.Size.X,bed.Size.Z,bed:GetAttribute('CrystalZone') or 1)
 elseif field.cfg.ContinuousCrystals then
  local patch=field.part
  field.crystalLayout=ResourcePlacement.crystalLayout(patch.Size.X,patch.Size.Z,patch:GetAttribute('CrystalZone') or 1)
  field.landmarkReserves={}
  for _,site in ipairs(field.crystalLayout.landmarks) do
   spawnResource(field,'Crystal',false,nil,nil,true,{landmark=site})
  end
 end
 local budget=field.cfg.Count*(field.cfg.ContinuousCrystals and 2 or 1)
 for _=1,budget do
  if nodeUsage(field)>=field.cfg.Count then break end
  if not spawnResource(field) and not field.cfg.ContinuousCrystals then break end
 end
 -- A blocked initial sampling pass must not permanently strand a safe field.
 -- Reserve one retry token for each missing unit of the population budget;
 -- geodes already count as five units through nodeUsage.
 for _=1,math.max(0,field.cfg.Count-nodeUsage(field)) do
  table.insert(field.respawnQueue,{at=now+2})
 end
end
local function restoreTurrets(field)
 for _,t in ipairs(field.turrets) do
  t.hp=field.cfg.TurretHP;t.nextShot=now+1;t.fireAt=nil;t.lock=nil;t.aim=nil;t.shotSerial=0
  t.awake=false;t.deathAt=nil;t.watcher=nil
  t.model:SetAttribute('Awake',false);t.model:SetAttribute('WakeAt',0);t.model:SetAttribute('ActivateAt',0);t.model:SetAttribute('DeathAt',0)
  t.model:SetAttribute('WakeAim',nil);t.model:SetAttribute('WatchPosition',nil);t.model:SetAttribute('Aim',nil)
  for part,transparency in pairs(t.originalTransparency) do if part.Parent then part.Transparency=transparency end end
  t.model:SetAttribute('HP',t.hp);t.model:SetAttribute('Telegraph',false);t.model:SetAttribute('Dead',false);t.model:SetAttribute('ShotSerial',0)
 end
end
local function wakeTurrets(field: any,pl: any)
 local hr=pl and pl.Character and pl.Character:FindFirstChild('HumanoidRootPart')
 for _,t in ipairs(field.turrets) do
  if not t.awake and t.hp>0 then
   t.awake=true;t.watcher=pl and pl.UserId
   t.model:SetAttribute('WakeAt',now);t.model:SetAttribute('ActivateAt',now+2.15)
   t.model:SetAttribute('WakeAim',hr and hr.Position or field.center)
   t.model:SetAttribute('WatchPosition',hr and hr.Position or field.center)
   t.model:SetAttribute('Awake',true)
  end
 end
end
local function publishTurretHealth(t: any)
 if t.hp<=0 and not t.deathAt then
  t.deathAt=now;t.model:SetAttribute('DeathAt',now)
  t.fireAt=nil;t.lock=nil;t.aim=nil;t.model:SetAttribute('Telegraph',false)
  for _,d in pairs(drones) do
   if d.combatTarget==t or d.chargeTarget==t then release(d);if d.hp>0 then d.state='Travel' end end
  end
 end
 t.model:SetAttribute('HP',t.hp);t.model:SetAttribute('Dead',t.hp<=0)
end
for _,f in ipairs(scene.fields) do
 local settings=table.clone(C);settings.EncounterPrefix=instanceId..':field:'..f.id
 local field={id=f.id,cfg=f.cfg,center=f.center,part=f.part,model=f.model,color=Color3.fromRGB(unpack(f.cfg.Color)),resources={},turrets={},respawnQueue={},e=R.newEncounter(settings)}
 field.model:SetAttribute('Hardness',f.cfg.Hardness or 1);field.model:SetAttribute('OreValue',f.cfg.Value)
 for n=1,f.cfg.Turrets do
  local pos=f.center+Vector3.new((n-(f.cfg.Turrets+1)/2)*17,f.part.Size.Y/2+.5,-f.part.Size.Z*.32)
  local model,body,emitter=World.turret(f.model,scene.turretTemplate,pos,Color3.fromRGB(210,100,145))
  model.Name='Pyramid_'..n;model:SetAttribute('TurretId',instanceId..':field:'..f.id..':turret:'..n);model:SetAttribute('FieldId',f.id);model:SetAttribute('Turret',true);model:SetAttribute('MaxHP',f.cfg.TurretHP)
  local t={model=model,body=body,emitter=emitter,hp=f.cfg.TurretHP,nextShot=0,fireAt=nil,lock=nil,shotSerial=0}
  -- An invisible queryable proxy binds damage/raycasting to the actual authored pyramid.
  t.hitbox=body;t.originalTransparency={}
  for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then t.originalTransparency[v]=v.Transparency end end
  table.insert(field.turrets,t)
 end
 if f.cfg.Turrets==0 then field.e.phase='Safe' end
 -- All playable fields use mineral rocks, including Studio preview. Photo and
 -- pattern templates remain available in the authored waterfront display.
 field.model:SetAttribute('JunkClearing',field.junk~=nil)
 field.model:SetAttribute('JunkTheme',field.junkTheme)
 table.insert(patches,field);scene.patchById[f.id]=field;restoreTurrets(field)
 if f.cfg.WholeField then table.insert(scene.squareFields,f.part) end
 if field.junk then
  field.nextJunkDrop=now+2.4
 else seedField(field) end
 field.model:SetAttribute('AlwaysUnlocked',field.cfg.AlwaysUnlocked==true)
end
-- Visible depot counters, shared with edit-time and in-session repair tooling.
local shopStations=ShopStands.mount(scene.map,home,scene.packStation)
local prices={};for _,field in ipairs(patches) do prices[field.cfg.Material or field.cfg.Key or field.cfg.Name]=field.cfg.Value end
local discoveries=DiscoveryService.new(root,RoleConfig.Discoveries,function(player)
 if scene.runStart then return nil end
 local p=profiles[player.UserId];if not healthy(p) then return nil end
 local hr=characterRoot(p);if not hr then return nil end
 return {root=hr,runId=data(p).run.id,
  roll=function(tier,roll,choice)
   local kind=Consumables.onRock(data(p).consumables,tier,roll,choice)
   p.dirty=true;p.publishDirty=true
   return kind,kind and Consumables.ITEMS[kind]
  end,
  collect=function(kind)
   if not healthy(p) or not Consumables.collect(data(p).consumables,kind) then return false end
   p.dirty=true;p.publishDirty=true;return true
  end,
  clearPath=function(position,part) return los(position,hr.Position,hr.Parent,{part,droneFolder}) end}
end)
local pickupFolder=folder(root,'OrePickups')
local pickups={}
local pickupSerial=0
function scene.oreExpired(drop,at)
 return (drop.modifiers or 0)==0 and OreDrops.expired(drop.refreshedAt or drop.spawnAt,at,drop.returnUntil)
end
function scene.outsidePickupBed(field,position)
 local point=field.CFrame:PointToObjectSpace(position)
 return math.abs(point.X)>field.Size.X*.5 or math.abs(point.Z)>field.Size.Z*.5
end
function scene.pickupFloorBelow(position)
 local include={scene.map};local base=workspace:FindFirstChild('Baseplate');if base then table.insert(include,base) end
 for _,field in ipairs(scene.fields) do table.insert(include,field.part) end
 local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances=include;query.RespectCanCollide=true
 local hit=workspace:Raycast(position+Vector3.yAxis*2,Vector3.new(0,-66,0),query)
 return hit and hit.Position.Y+.22
end
function scene.spawnOrePickup(template,drop,position,velocity,color)
 pickupSerial+=1
 local launchAt=now
 if drop.finishing and not drop.stone then
  local splitAt=template:GetAttribute('CrystalSplitAt') or now
  launchAt=splitAt+OreDrops.REWARD_DELAY
 end
 drop.launchAt=launchAt
 if drop.raw and (drop.rareGem or drop.lucky) then drop.returnUntil=math.max(drop.returnUntil or 0,launchAt+OreDrops.GEM_LIFETIME) end
 if drop.oreArc and not drop.compacted then
  if not drop.stone then template=scene.crystalCuts and scene.crystalCuts.Gem or template end
  local arc=OreDrops.rawArc(position.X,position.Y,position.Z,velocity.X,velocity.Y,velocity.Z,drop.floor)
  local landing=Vector3.new(arc.landX,arc.floor,arc.landZ)
  if drop.fieldPart and scene.outsidePickupBed(drop.fieldPart,landing) then
   local lowerFloor=scene.pickupFloorBelow(landing)
   if lowerFloor and lowerFloor<drop.floor then
    drop.floor=lowerFloor
    arc=OreDrops.rawArc(position.X,position.Y,position.Z,velocity.X,velocity.Y,velocity.Z,drop.floor)
   end
  end
  drop.arc=arc
 end
 local chip=template:Clone();for _,child in ipairs(chip:GetChildren()) do child:Destroy() end
 for key in pairs(chip:GetAttributes()) do chip:SetAttribute(key,nil) end
 chip.Name=drop.raw and (drop.compacted and 'PressedCargo' or 'RawCrystalCargo') or 'OreFragment'
 chip.Size=drop.raw and Vector3.new(table.unpack(drop.compacted and Workshop.BLOCK_SIZE or Workshop.ROCK_SIZE)) or Vector3.new(.97,.73,.88)
 if drop.raw and not drop.compacted then chip.Size*=Mining.ORE_SIZE_SCALE[Mining.sizeTier(drop.modifiers)] end
 chip.Position=position
 chip.Color=color
 chip.Material=drop.compacted and Enum.Material.Metal or Enum.Material.SmoothPlastic
 chip:SetAttribute('StoneCargo',drop.stone==true);chip:SetAttribute('RareGemReward',drop.rareGem==true)
 if drop.lucky then chip:SetAttribute('LuckyMultiplier',drop.lucky) end
 if drop.stone then chip.Color=drop.compactorOutput and color or Color3.fromRGB(88,84,81):Lerp(color,.32);chip.Material=Enum.Material.Slate end
 chip.MaterialVariant='';chip.Reflectance=(drop.compacted or drop.stone) and 0 or Workshop.RAW_CRYSTAL_REFLECTANCE
 if drop.raw then
  chip:SetAttribute('PhysicalCargo',true)
  chip:SetAttribute('CargoValue',drop.value)
 end
 chip.Anchored=true;chip.CanCollide=false;chip.CanTouch=false;chip.CanQuery=false;chip.Transparency=0
 chip:SetAttribute('Owner',drop.owner);chip:SetAttribute('RunId',drop.runId);chip:SetAttribute('Units',drop.units);chip:SetAttribute('Mineral',drop.material)
 if drop.modifiers and drop.modifiers~=0 then chip:SetAttribute('RockModifiers',drop.modifiers) end
 chip:SetAttribute('SpawnAt',launchAt);chip:SetAttribute('ExpiresAt',(drop.modifiers or 0)==0 and OreDrops.deadline(launchAt,drop.returnUntil) or nil);chip:SetAttribute('FloorY',drop.floor);chip:SetAttribute('Homing',false)
 chip:SetAttribute('PickupId',pickupSerial);chip:SetAttribute('Position',position);chip:SetAttribute('Velocity',velocity);chip:SetAttribute('SnapshotAt',launchAt)
 if drop.oreArc then
  chip:SetAttribute('OreLaunchOrigin',position)
  chip:SetAttribute('OreLaunchVelocity',velocity)
  if drop.arc then chip:SetAttribute('CleanCargoArc',true) end
  if drop.geode then chip:SetAttribute('GeodeGem',true) end
 end
 chip.Parent=pickupFolder
 drop.part=chip;drop.x=position.X;drop.y=position.Y;drop.z=position.Z
 drop.vx=velocity.X;drop.vy=velocity.Y;drop.vz=velocity.Z;drop.age=0;drop.spawnAt=launchAt
 drop.publishedPosition=position;drop.publishedVelocity=velocity
 drop.publishedHoming=false;drop.publishedFloor=drop.floor
 pickups[pickupSerial]=drop
end
function scene.snapshotOrePickup(drop)
 drop.snapshotAt=now+C.Snapshot
 local part=drop.part
 local position=drop.publishedPosition
 local velocity=drop.publishedVelocity
 local moved=not position or position.X~=drop.x or position.Y~=drop.y or position.Z~=drop.z
 local accelerated=not velocity or velocity.X~=drop.vx or velocity.Y~=drop.vy or velocity.Z~=drop.vz
 local homing=drop.homing==true
 local dronePull=homing and drop.dronePull==true
 if not moved and not accelerated and homing==drop.publishedHoming
  and dronePull==(drop.publishedDronePull==true) and drop.pressSocket==drop.publishedSocket and drop.floor==drop.publishedFloor then return end
 if moved then
  position=Vector3.new(drop.x,drop.y,drop.z)
  part.Position=position;part:SetAttribute('Position',position)
 end
 if accelerated then
  velocity=Vector3.new(drop.vx,drop.vy,drop.vz)
  part:SetAttribute('Velocity',velocity)
 end
 if homing~=drop.publishedHoming then part:SetAttribute('Homing',homing) end
 if dronePull~=(drop.publishedDronePull==true) then part:SetAttribute('DronePull',dronePull) end
 if drop.arcEnded and not drop.publishedArcEnd then
  drop.publishedArcEnd=true;part:SetAttribute('CargoArcEnded',true)
 end
 drop.publishedPosition=position;drop.publishedVelocity=velocity
 drop.publishedHoming=homing;drop.publishedSocket=drop.pressSocket;drop.publishedFloor=drop.floor
 drop.publishedDronePull=dronePull
 part:SetAttribute('SnapshotAt',now)
end
local function pendingOre(p)
 local units,nodes=0,{}
 for _,drop in pairs(pickups) do
  if drop.owner==p.player.UserId and drop.runId==data(p).run.id then units+=drop.units;nodes[drop.nodeId]=true end
 end
 local count=0;for _ in pairs(nodes) do count+=1 end
 return units,count
end
local function award(d: any,r: any,specialistCut: boolean?,extraction: boolean?)
 local p=profiles[d.owner];if not healthy(p) or not playerCanMine(p,r.field) or (r.kind=='Geode' and not r.manualOpened) then return end
 if r.gemReward and not r.manualOpened then return end
 local profile=data(p);local material=r.field.cfg.Material or r.field.cfg.Key or r.field.cfg.Name
 if r.field.cfg.SelectionOnly and Workshop.CRYSTAL_BY_MATERIAL[material] then
  if r.cargoProduced then return end
  local early=d.stats.earlyDrop or 0
  if extraction and (not DroneRoles.isWorker(d.role) or not Mining.looseSeamsReady(r.hp,r.maxHP,early)) then return end
  local tier=Workshop.CRYSTAL_BY_MATERIAL[material]
  local specialist=specialistCut and DroneCatalog.Types[d.role]
  local amount=r.ore*(specialist and specialist.Yield or 1)*d.stats.yieldMultiplier*tier.value+(profile.run.yieldRemainders[material] or 0)
  local crystal=r.gemReward
  if crystal==nil then crystal=math.random()<Workshop.CRYSTAL_CHANCE end
  local mass=math.max(1,math.floor(amount/tier.value+.5))
  local dust=math.min(1000000,mass*(crystal and 100 or Workshop.PITY_PERCENT))
  local stoneUnits=crystal and 0 or math.min(1000000,mass*100)
  local lucky=not r.gemReward and Mining.luckyMultiplier(math.random()) or 1
  local value=math.clamp(math.floor(amount*(crystal and 8 or .3)*lucky),1,1000000)
  profile.run.yieldRemainders[material]=amount-math.floor(amount)
  r.cargoProduced=true;r.extractedOre=r.ore;r.part:SetAttribute('CargoReward',crystal and 'Gem' or 'Stone');r.part:SetAttribute('ExtractedOre',r.ore)
  local fieldTop=r.field.part.Position.Y+r.field.part.Size.Y*.5
  local vx,vy,vz=OreDrops.cargoLaunch(pickupSerial+1,false)
  local out=Vector3.new(vx,0,vz).Unit
  -- The reward emerges from the split. Early extraction still clears a living rock.
  local edge=extraction and Vector3.new(r.part.Size.X,0,r.part.Size.Z).Magnitude*.5+.42 or .24
  local position=r.part.Position+out*edge+Vector3.yAxis*(r.part.Size.Y*.18+.18)
  local cut=not crystal and (r.part:GetAttribute('CrystalCut') or 'Original') or 'Original'
  local cargo=Workshop.saleCargo(material,value,not crystal,dust,stoneUnits,r.modifiers or 0,cut)
  scene.spawnOrePickup(r.part,{owner=d.owner,runId=profile.run.id,nodeId=r.id,
   material=cargo,tierMaterial=material,value=Workshop.saleItem(cargo).cash,
   stone=not crystal,rareGem=crystal,units=1,raw=true,oreArc=true,finishing=not extraction,
   floor=fieldTop+.22,fieldPart=r.field.part,reachBonus=early*14,modifiers=r.modifiers,lucky=lucky>1 and lucky or nil},
   position,Vector3.new(vx,vy,vz),r.field.color)
  p.dirty=true;p.publishDirty=true;return
 end
 local target=extraction and Mining.extractedOre(r.ore,r.stage,r.stageCount,d.stats.earlyDrop) or r.ore
 local reachBonus=extraction and (d.stats.earlyDrop or 0)*56 or 0
 local base=math.max(0,target-(r.extractedOre or 0));if base==0 then return end
 local special=not extraction and specialistCut and d.specialJob and d.specialJob.targetId==r.id and DroneCatalog.Types[d.role]
 -- Keep the existing whole-rock specialist bonus on the final collapse.
 -- Partial extraction advances one shared ledger, independent of worker.
 local bonus=special and r.ore*((special.Yield or 1)-1) or 0
 local amount=(base+bonus)*d.stats.yieldMultiplier*discoveries:Multiplier(p.player,'Yield')+(profile.run.yieldRemainders[material] or 0)
 local units=math.floor(amount);profile.run.yieldRemainders[material]=amount-units
 r.extractedOre=target;r.part:SetAttribute('ExtractedOre',target)
 if d.deployedCarrier and logistics then
  local accepted=logistics:deposit(p,material,units)
  local pending=profile.run.logistics.pendingCargo
  if accepted<units then pending[material]=(pending[material] or 0)+units-accepted end
  p.dirty=true;p.publishDirty=true;return
 end
 if units<=0 then p.dirty=true;return end
 local fieldTop=r.field.part.Position.Y+r.field.part.Size.Y*.5
 local ground=r.referenceCrystal and fieldTop or (r.part:GetAttribute('GroundY') or fieldTop)
 local _,nodes=pendingOre(p)
 local nodeDrops=0
 for _,drop in pairs(pickups) do
  if drop.owner==d.owner and drop.runId==profile.run.id and drop.nodeId==r.id and not drop.compacted
   and not scene.oreExpired(drop,now) then nodeDrops+=1 end
 end
 if nodes>=OreDrops.MAX_NODES or nodeDrops>=4 then
  -- Consolidate overflow at a nearby pile of the same ore. Renew the pile's
  -- lifetime without restarting the existing fragment's motion or spin.
  local nearest,nearestId,distance=nil,nil,math.huge
  for id,drop in pairs(pickups) do
   if drop.owner==d.owner and drop.runId==profile.run.id and drop.material==material and not drop.compacted
    and (nodeDrops<4 or drop.nodeId==r.id) and not scene.oreExpired(drop,now) then
    local delta=Vector3.new(drop.x,drop.y,drop.z)-r.position
    local dist=delta:Dot(delta)
    if not nearest or dist<distance or dist==distance and id<nearestId then
     nearest,nearestId,distance=drop,id,dist
    end
   end
  end
  if nearest then
   nearest.units+=units;nearest.refreshedAt=now
   if r.modifiers then
    nearest.modifiers=bit32.bor(nearest.modifiers or 0,r.modifiers)
    nearest.part:SetAttribute('RockModifiers',nearest.modifiers)
   end
   nearest.reachBonus=math.max(nearest.reachBonus or 0,reachBonus)
   nearest.part:SetAttribute('Units',nearest.units)
   nearest.part:SetAttribute('ExpiresAt',(nearest.modifiers or 0)==0 and now+OreDrops.LIFETIME or nil)
   p.dirty=true;p.publishDirty=true;return
  end
 end
 local limit=4-nodeDrops
 if r.field.cfg.SelectionOnly then limit=math.min(limit,math.max(1,math.floor(units/Workshop.COMPACTOR_BATCH))) end
 for index,n in ipairs(OreDrops.partition(units,limit)) do
  local ox,oy,oz,vx,vy,vz=OreDrops.launch(index,pickupSerial+1,r.part.Size.X,r.part.Size.Y,r.part.Size.Z)
  local position=r.part.Position+Vector3.new(ox,oy,oz)
  scene.spawnOrePickup(r.part,{owner=d.owner,runId=profile.run.id,nodeId=r.id,material=material,units=n,quiet=r.referenceCrystal,
   oreArc=true,floor=ground+.22,fieldPart=r.field.part,reachBonus=reachBonus,modifiers=r.modifiers},position,Vector3.new(vx,vy,vz),r.field.color)
 end
 p.dirty=true;p.publishDirty=true
end
function scene.pressSocket(position,yaw,slot)
 return (CFrame.new(position)*CFrame.Angles(0,yaw,0)):PointToWorldSpace(RoleConfig.PressSockets[slot])
end
function scene.resetPress(press,restore)
 local job=press.pressJob
 if not job then return end
 for slot,id in ipairs(job.ids) do
  local drop=pickups[id]
  if drop and drop.pressCarrier==press then
   drop.pressCarrier=nil;drop.pressSocket=nil;drop.pressMarked=nil;drop.homing=false;drop.dronePull=false
   drop.pressBlockedUntil=now+1
   if restore and drop.part.Parent then
    local origin=job.origins[slot]
    drop.x,drop.y,drop.z=origin.X,origin.Y,origin.Z
    drop.vx,drop.vy,drop.vz=0,0,0
    drop.part:SetAttribute('PressSocket',nil);drop.part:SetAttribute('PressMarked',nil)
    drop.part:SetAttribute('PressCastAt',nil);drop.part:SetAttribute('PressDrone',nil)
    drop.part:SetAttribute('PressSlot',nil);drop.part:SetAttribute('PressOrigin',nil)
    scene.snapshotOrePickup(drop)
   end
  end
 end
 if restore and job.castAt then press.model:SetAttribute('PressGripAt',nil) end
 press.pressJob=nil
end
function scene.finishPress(press,drops)
 local job=press.pressJob
 local first,second=drops[1],drops[2]
 local value=first.value+second.value
 local output={owner=first.owner,runId=first.runId,nodeId=first.nodeId,tierMaterial=first.tierMaterial,
  material=Workshop.cargoKey(first.tierMaterial,value),stone=first.stone,compactorOutput=true,value=value,units=1,raw=true,oreArc=true,
  floor=job.floor,fieldPart=first.fieldPart,modifiers=job.modifiers}
 local a,b=Workshop.saleItem(first.material),Workshop.saleItem(second.material)
 if a and b then
  local cashBonus,dustBonus=a.cashBonus+b.cashBonus,a.dustBonus+b.dustBonus
  output.material=Workshop.saleCargo(first.tierMaterial,value-cashBonus,first.stone,a.dust+b.dust-dustBonus,
   a.stoneUnits+b.stoneUnits,job.modifiers,a.cut or 'Original',cashBonus,dustBonus,bit32.bor(a.bonusMask,b.bonusMask))
 end
 local from=job.position+job.direction*1.5-Vector3.yAxis*1.25
 local velocity=job.direction*7.3+Vector3.yAxis*29
 scene.spawnOrePickup(first.part,output,from,velocity,first.part.Color)
 for _,id in ipairs(job.ids) do
  local drop=pickups[id]
  drop.part:SetAttribute('ProcessedPosition',job.position-Vector3.yAxis*1.3);drop.part:SetAttribute('ProcessedAt',now)
  drop.part.Transparency=1;Debris:AddItem(drop.part,Workshop.PRESS_CONTACT+.22);pickups[id]=nil
 end
 press.pressUntil=now+Workshop.PRESS_RECOVER
 press.model:SetAttribute('PressEjectPosition',from)
 press.model:SetAttribute('PressEjectDirection',job.direction)
 press.model:SetAttribute('PressEjectAt',now)
 scene.resetPress(press,false)
end
function scene.cargoInSquare(square,position)
 local reach=square.half+8
 return math.abs(position.X-square.center.X)<=reach and math.abs(position.Z-square.center.Z)<=reach
end
function scene.pressClearing(press,square,first,second,character)
 local a,b=first.position,second.position
 local middle=(a+b)*.5
 local across=Vector3.new(b.X-a.X,0,b.Z-a.Z)
 local axis=across.Magnitude>.02 and across.Unit or Vector3.zAxis
 local side=Vector3.yAxis:Cross(axis)
 if side:Dot(press.pos-middle)<0 then side=-side end
 local bed=square.field.part
 local floor=bed.Position.Y+bed.Size.Y*.5+.22
 local ignore={pickupFolder,droneFolder,character}
 local outputRadius=Mining.ORE_SIZE_SCALE[first.tier+1]
 -- Approach from the nearby side first. Diagonals and the center let the
 -- grapples work between clumps and when the pin sits near a bed edge.
 local offsets={side*4,-side*4,side*7,-side*7,
  side*5+axis*4,side*5-axis*4,-side*5+axis*4,-side*5-axis*4,Vector3.zero}
 for _,offset in ipairs(offsets) do
  local height=math.max(floor,a.Y,b.Y)+6.4
  local position=Vector3.new(middle.X,height,middle.Z)+offset
  local direction=offset.Magnitude>0 and offset.Unit or side
  local yaw=Feel.levelYaw(position,position+direction,press.yaw)
  if scene.outsidePickupBed(bed,position) or not los(press.pos,position,nil,ignore,true)
   or not los(position,position-Vector3.yAxis*3.5,nil,ignore,true)
   or not los(a,scene.pressSocket(position,yaw,1),nil,ignore,true)
   or not los(b,scene.pressSocket(position,yaw,2),nil,ignore,true) then continue end
  -- At the field edge, try ejecting back toward the bed as well.
  for _,out in ipairs({direction,-direction,axis,-axis}) do
   local launch=position+out*1.5-Vector3.yAxis*1.25
   local arc=OreDrops.rawArc(launch.X,launch.Y,launch.Z,out.X*7.3,29,out.Z*7.3,floor)
   local landing=Vector3.new(arc.landX,floor,arc.landZ)
   if scene.outsidePickupBed(bed,landing) then continue end
   local x,y,z=OreDrops.rawPose(arc,29/OreDrops.GEM_GRAVITY)
   local apex=Vector3.new(x,y,z)
   if not los(launch,apex,nil,ignore,true) or not los(apex,landing,nil,ignore,true) then continue end
   local clear=true
   for _,edge in ipairs({Vector3.xAxis,-Vector3.xAxis,Vector3.zAxis,-Vector3.zAxis}) do
    local corner=landing+edge*outputRadius
    if scene.outsidePickupBed(bed,corner) or not los(corner+Vector3.yAxis*4,corner,nil,ignore,true) then clear=false;break end
   end
   if clear then return position,yaw,out,floor end
  end
 end
end
function scene.pressCandidate(square,drop,position)
 return drop.raw and not drop.compacted and Mining.sizeTier(drop.modifiers)<4 and drop.fieldPart==square.field.part
  and scene.cargoInSquare(square,position)
end
function scene.pressHasPower(press)
 return not scene.chargingStation or press.battery+1e-6>=Workshop.PRESS_POWER_COST
end
function scene.pressPairingWindow(p,drop,position)
 local press=p.compactor
 local square=p.miningSquare
 if not press or press.hp<=0 or press.carrierId or not square or not scene.pressCandidate(square,drop,position) then return false end
 -- Hold Big and Massive ore for the next matching input while this pin is active.
 -- Plain ore gets a short chance to pair and can then move on to the Emptiers.
 if Mining.sizeTier(drop.modifiers)>1 then return true end
 return not press.recharging and scene.pressHasPower(press) and not press.pressJob and now>=(drop.pressBlockedUntil or 0)
  and drop.age-(drop.firstLandedAge or 0)<Workshop.COMPACTOR_PAIR_WINDOW
end
function scene.planPress(p,press,candidates)
 press.pressWaiting=not press.pressJob and #candidates>0
 table.sort(candidates,function(a,b)
  if a.tier~=b.tier then return a.tier>b.tier end
  if a.distance~=b.distance then return a.distance<b.distance end
  return a.id<b.id
 end)
 local probes=0
 for i,a in ipairs(candidates) do
  for j=i+1,#candidates do
   local b=candidates[j]
   if b.tier~=a.tier then break end
   if a.drop.tierMaterial~=b.drop.tierMaterial or (a.drop.stone==true)~=(b.drop.stone==true) or a.drop.value+b.drop.value>1000000
    or (a.position-b.position).Magnitude>Workshop.COMPACTOR_REACH then continue end
   local itemA,itemB=Workshop.saleItem(a.drop.material),Workshop.saleItem(b.drop.material)
   if itemA and itemB and (itemA.dust+itemB.dust>1000000 or itemA.stoneUnits+itemB.stoneUnits>1000000) then continue end
   probes+=1
   if probes>24 then return end
   local position,yaw,direction,floor=scene.pressClearing(press,p.miningSquare,a,b,p.player.Character)
   if position then
    -- A better pair can take over any claim before the visible cast begins.
    scene.resetPress(press,true)
    press.pressJob={ids={a.id,b.id},origins={a.position,b.position},square=p.miningSquare,
     position=position,yaw=yaw,direction=direction,floor=floor,
     arriveBy=math.max(now,press.thinkUntil or 0)+Workshop.COMPACTOR_ARRIVAL_TIME,
     tier=a.tier,modifiers=Mining.nextSizeMask(a.drop.modifiers,b.drop.modifiers)}
    press.pressWaiting=false
    for _,candidate in ipairs({a,b}) do
     local drop=candidate.drop
     drop.pressCarrier=press
     if (drop.modifiers or 0)==0 then
      local untilTime=press.pressJob.arriveBy+Workshop.GRAPPLE_MARK+Workshop.GRAPPLE_CAST+Workshop.GRAPPLE_REEL
       +(p.pressDuration or Workshop.PRESS_DURATION)+1
      drop.returnUntil=math.max(untilTime,drop.returnUntil or 0)
      drop.part:SetAttribute('ExpiresAt',OreDrops.deadline(drop.spawnAt,drop.returnUntil))
     end
     local courier=drop.courier
     if courier then courier.orePickupId=nil;courier.oreDock=nil;courier.pickupAt=nil;drop.courier=nil end
    end
    return
   end
  end
 end
end
function scene.stepPress(p,press)
 local job=press.pressJob
 local drops={pickups[job.ids[1]],pickups[job.ids[2]]}
 if press.hp<=0 or press.carrierId or not characterRoot(p) or (p.miningSquare~=job.square and not job.startedAt)
  or (not job.castAt and now>job.arriveBy) then scene.resetPress(press,true);return end
 for slot=1,2 do
  local drop=drops[slot]
  if not drop or not drop.part.Parent or drop.runId~=data(p).run.id or scene.oreExpired(drop,now) then
   scene.resetPress(press,true);return
  end
 end
 if not healthy(p) then
  -- Keep the earned inputs if a save pauses flight or work.
  scene.resetPress(press,true);return
 end
 if not job.startedAt and not scene.pressHasPower(press) then
  scene.resetPress(press,true);return
 end
 if not job.castAt then
  if now<(press.thinkUntil or 0) or (press.pos-job.position).Magnitude>.8 then return end
  local ignore={pickupFolder,droneFolder,p.player.Character}
  for slot=1,2 do
   if not los(job.origins[slot],scene.pressSocket(job.position,job.yaw,slot),nil,ignore,true) then
    scene.resetPress(press,true);return
   end
  end
  press.pos=job.position;press.yaw=job.yaw;job.castAt=now+Workshop.GRAPPLE_MARK
  for slot,drop in ipairs(drops) do
   drop.pressMarked=true
   drop.part:SetAttribute('PressMarked',true);drop.part:SetAttribute('PressDrone',press.id)
   drop.part:SetAttribute('PressSlot',slot);drop.part:SetAttribute('PressOrigin',job.origins[slot])
   drop.part:SetAttribute('PressCastAt',job.castAt)
  end
  press.model:SetAttribute('PressGripAt',job.castAt+Workshop.GRAPPLE_CAST)
 end
 if job.startedAt then
  if scene.chargingStation then
   local progress=math.clamp((now-job.startedAt)/(job.finishAt-job.startedAt),0,1)
   local spent=Workshop.PRESS_POWER_COST*progress
   press.battery=math.max(0,press.battery-(spent-(job.powerSpent or 0)))
   job.powerSpent=spent
  end
  if now>=job.finishAt then scene.finishPress(press,drops) end
  return
 end
 local t=math.clamp((now-job.castAt-Workshop.GRAPPLE_CAST)/Workshop.GRAPPLE_REEL,0,1)
 if t<=0 then return end
 for slot,drop in ipairs(drops) do
  local target=scene.pressSocket(job.position,job.yaw,slot)
  local position=Workshop.grapplePull(job.origins[slot],target,t)
  drop.x,drop.y,drop.z=position.X,position.Y,position.Z
  drop.vx,drop.vy,drop.vz=0,0,0;drop.homing=t<1;drop.dronePull=t<1
  if t>=1 then
   drop.pressSocket=slot;drop.pressMarked=nil
   drop.part:SetAttribute('PressSocket',slot);drop.part:SetAttribute('PressMarked',nil)
   -- Keep the cast receipt for clients playing the buffered motion or joining mid-reel.
  end
  if now>=(drop.snapshotAt or 0) or t>=1 then scene.snapshotOrePickup(drop) end
 end
 if t>=1 then
  job.startedAt=now;job.finishAt=now+(p.pressDuration or Workshop.PRESS_DURATION)
  press.model:SetAttribute('PressAt',now)
 end
end
function scene.orePullClear(drop,from,target,targetModel)
 if drop.pullTarget~=targetModel or now>=(drop.queryAt or 0)
  or (from-drop.pullFrom).Magnitude>1.25 or (target-drop.pullTo).Magnitude>1.25 then
  drop.clearPath=los(from,target,targetModel,{pickupFolder,droneFolder},true,true)
  drop.queryAt=now+.15;drop.pullTarget=targetModel;drop.pullFrom=from;drop.pullTo=target
 end
 return drop.clearPath==true
end
function scene.vacuumApproach(drop,from,hr)
 if drop.vacuumRouteRoot~=hr or now>=(drop.vacuumRouteAt or 0) then
  drop.vacuumRouteAt=now+.2;drop.vacuumRouteRoot=hr;drop.vacuumGoal=nil
  local ignore={pickupFolder,droneFolder}
  -- The raised intake can clear a bank while staying inside the pull radius.
  for _,height in ipairs({3.2,8}) do
   local goal=Vector3.new(from.X,drop.floor+height,from.Z)
   local intake=goal-Vector3.yAxis*.7
   if (intake-from).Magnitude<=13 and los(intake,hr.Position,hr.Parent,ignore) and los(from,intake,nil,ignore) then
    drop.vacuumGoal=goal;break
   end
  end
 end
 return drop.vacuumGoal
end
function scene.playerCanPickOre(p,drop,id,hr,from,reach)
 local job=drop.pressCarrier and drop.pressCarrier.pressJob
 return drop.raw and drop.owner==p.player.UserId and drop.runId==data(p).run.id
  and drop.part.Parent and drop.units>0 and not (job and job.castAt)
  and not (drop.homing and drop.dronePull) and OreDrops.collectible(drop)
  and now>=(drop.launchAt or 0) and not scene.oreExpired(drop,now)
  and (hr.Position-from).Magnitude<=reach and scene.orePullClear(drop,from,hr.Position,hr.Parent)
end
function scene.requestOrePickup(p,id)
 if not R.finite(id) or id%1~=0 then return end
 local drop=pickups[id]
 local hr=characterRoot(p)
 if not drop or not hr
  or Pro.cargoUnits(data(p))>=Ca.capacity(data(p),previewPerks(p)) then return end
 local from=Vector3.new(drop.x,drop.y,drop.z)
 local reach=(p.cargoReach or OreDrops.CARGO_REACH)+(drop.reachBonus or 0)*Workshop.ORE_REACH_SCALE
 drop.queryAt=0
 if not scene.playerCanPickOre(p,drop,id,hr,from,reach) then return end
 if drop.pressCarrier then scene.resetPress(drop.pressCarrier,true) end
 drop.playerPickup=true
 p.player:SetAttribute('MA_OrePickup',nil)
 local courier=drop.courier
 if courier and courier.orePickupId==id then
  courier.orePickupId=nil;courier.oreDock=nil;courier.oreYaw=nil;courier.pickupAt=nil
  drop.part:SetAttribute('CourierDocking',nil)
 end
 drop.courier=nil
end
function scene.offerOrePickup(p,id,distance)
 if distance<p.orePromptDistance or distance==p.orePromptDistance and id<p.orePromptId then
  p.orePromptId=id;p.orePromptDistance=distance
 end
end
local function pickupStep(dt)
 local activePresses={}
 local updatePrompt=now>=(scene.orePromptAt or 0)
 if updatePrompt then scene.orePromptAt=now+.10 end
 for _,p in pairs(profiles) do
  p.pinOreOutOfReach=nil
  if updatePrompt then p.orePromptId=nil;p.orePromptDistance=math.huge end
  if p.vacuum then
   p.previousVacuumTargetId=p.vacuumTarget and p.vacuumTarget.id
   p.vacuumTarget=nil;p.vacuumScore=math.huge
  end
  local press=p.compactor
  if not press then continue end
  if not p.miningSquare or press.hp<=0 or press.carrierId or press.recharging or not scene.pressHasPower(press)
   or not healthy(p) or not characterRoot(p) then
   press.pressWaiting=false
  elseif not (press.pressJob and (press.pressJob.castAt or press.pressJob.tier>=3))
   and now>=math.max(press.pressUntil or 0,press.pressSearchAt or 0) then
   -- Reserve the best available pair while the spinner is still visible.
   press.pressSearchAt=now+.18
   activePresses[press.owner]={}
  end
 end
 if next(activePresses) then
  for id,drop in pairs(pickups) do
   local candidates=activePresses[drop.owner]
   local p=candidates and profiles[drop.owner]
   if not p or drop.pressCarrier or drop.playerPickup or drop.homing
    or not OreDrops.collectible(drop) or not drop.part.Parent or now<(drop.launchAt or 0)
    or now<(drop.pressBlockedUntil or 0) or scene.oreExpired(drop,now)
    or now<(drop.relayUntil or 0) or (drop.courier and drop.courier.oreDock)
    or drop.runId~=data(p).run.id then continue end
   local position=Vector3.new(drop.x,drop.y,drop.z)
   local tier=Mining.sizeTier(drop.modifiers)
   if scene.pressCandidate(p.miningSquare,drop,position) and (not p.compactor.pressJob or tier>p.compactor.pressJob.tier) then
    local offset=p.compactor.pos-position
    table.insert(candidates,{id=id,drop=drop,tier=tier,position=position,
     distance=offset.X^2+offset.Z^2})
   end
  end
  for owner,candidates in pairs(activePresses) do
   local p=profiles[owner];scene.planPress(p,p.compactor,candidates)
  end
 end
 for _,p in pairs(profiles) do
  local press=p.compactor
  if press and press.pressJob then scene.stepPress(p,press) end
 end
 for id,drop in pairs(pickups) do
  local p=profiles[drop.owner]
  if p and drop.pressCarrier and drop.pressCarrier~=p.compactor then scene.resetPress(drop.pressCarrier,true) end
  if not p or p.leaving or data(p).run.id~=drop.runId or scene.oreExpired(drop,now) then
   drop.part:Destroy();pickups[id]=nil;if p then p.publishDirty=true end
  elseif healthy(p) and drop.pressCarrier then
   if updatePrompt then
    local hr=characterRoot(p)
    local from=Vector3.new(drop.x,drop.y,drop.z)
    local reach=(p.cargoReach or OreDrops.CARGO_REACH)+(drop.reachBonus or 0)*Workshop.ORE_REACH_SCALE
    if hr and Pro.cargoUnits(data(p))<Ca.capacity(data(p),previewPerks(p))
     and scene.playerCanPickOre(p,drop,id,hr,from,reach) then
     scene.offerOrePickup(p,id,(hr.Position-from).Magnitude)
    end
   end
  elseif healthy(p) and now>=(drop.launchAt or 0) then
   -- A chip can roll off a raised ore bed. Sample the real map floor only
   -- outside its original footprint, at bounded intervals while moving.
   if drop.fieldPart and (not drop.arc or drop.arcEnded) and now>=(drop.floorQueryAt or 0) then
    local position=Vector3.new(drop.x,drop.y,drop.z)
    local outside=scene.outsidePickupBed(drop.fieldPart,position)
    drop.floorQueryAt=now+.25
    if outside and (not drop.floorQueryX or (drop.x-drop.floorQueryX)^2+(drop.z-drop.floorQueryZ)^2>.25) then
     local floor=scene.pickupFloorBelow(position)
     if floor then drop.floor=floor;drop.part:SetAttribute('FloorY',floor) end
     drop.floorQueryX=drop.x;drop.floorQueryZ=drop.z
    end
   end
   local from=Vector3.new(drop.x,drop.y,drop.z)
   local hr=characterRoot(p);local target=hr and hr.Position or from
   local naturalReach=(drop.raw and (p.cargoReach or OreDrops.CARGO_REACH) or p.magnetRange)+(drop.reachBonus or 0)*Workshop.ORE_REACH_SCALE
   local hasSpace=hr~=nil and Pro.cargoUnits(data(p))<Ca.capacity(data(p),previewPerks(p))
   -- Protect an earned drop during a real depot visit, including buying a
   -- pack with a partially full bag. The same 180-second cap still applies.
   local depotVisit=false
   if drop.raw and drop.landed and hr and p.miningSquare and scene.runStart and scene.packStation then
    if now>=(p.pickupVisitCheckAt or 0) or p.pickupVisitSquare~=p.miningSquare then
     local floor=scene.depotFloor
     p.pickupVisitCheckAt=now+1;p.pickupVisitSquare=p.miningSquare
     p.pickupDepotVisit=(hr.Position-p.miningSquare.center).Magnitude>28
      and Mining.onSelectorDepotRoute(hr.Position,p.miningSquare.center,scene.packStation.Position,floor and floor.CFrame,floor and floor.Size)
    end
    depotVisit=p.pickupDepotVisit
   end
   if drop.raw and drop.landed and hr and (not hasSpace or depotVisit) and now>=(drop.returnCheckAt or 0) then
    drop.returnCheckAt=now+1
    local counter=scene.packStation.Position
    local walkingDistance=(target-counter).Magnitude+(from-counter).Magnitude
    local deadline=OreDrops.sellTripDeadline(drop.spawnAt,now,walkingDistance,drop.returnUntil)
    if deadline then
     drop.returnUntil=deadline
     drop.part:SetAttribute('ExpiresAt',deadline)
    end
   end
   local vacuum=Workshop.VACUUM_ENABLED and p.vacuum or nil
   local courier=drop.courier
   local docking=courier and courier.orePickupId==id and courier.oreDock~=nil and courier.hp>0
   local dockingId=docking and courier.id or nil
   if drop.part:GetAttribute('CourierDocking')~=dockingId then drop.part:SetAttribute('CourierDocking',dockingId) end
   local relay=Workshop.VACUUM_ENABLED and now<(drop.relayUntil or 0)
   local vacuuming=false
   local vacuumApproaching=false
   local relayReach=p.vacuumReach+12
   local reach=relay and math.max(relayReach,naturalReach) or naturalReach
   local withinReach=hasSpace and (drop.playerPickup or updatePrompt) and scene.playerCanPickOre(p,drop,id,hr,from,naturalReach)
   if updatePrompt and drop.part:GetAttribute('ManualPickupReady')~=(withinReach==true) then drop.part:SetAttribute('ManualPickupReady',withinReach==true) end
   local playerPull=drop.playerPickup and withinReach
   if drop.playerPickup and not playerPull then drop.playerPickup=nil end
   if updatePrompt and withinReach and not playerPull and not drop.pressCarrier and not scene.pressPairingWindow(p,drop,from) then
    -- Simulator-style magnet: anything you walk near flies into the bag.
    scene.requestOrePickup(p,id)
    playerPull=drop.playerPickup==true
   end
   if playerPull then
    reach=naturalReach
   elseif hasSpace and vacuum and vacuum.hp>0 and not vacuum.carrierId and not relay
    and not scene.pressPairingWindow(p,drop,from)
    and not (drop.courier and drop.courier.orePickupId==id and drop.courier.hp>0 and drop.courier.model.Parent)
    and drop.landed and drop.age>=OreDrops.SCATTER_TIME then
    local distance=(target-from).Magnitude
    local committed=id==p.previousVacuumTargetId
    local searchReach=committed and relayReach or p.vacuumReach
    local goal=distance<=searchReach and (distance>naturalReach or not scene.orePullClear(drop,from,target,hr.Parent)) and scene.vacuumApproach(drop,from,hr)
    if goal then
     local intake=vacuum.pos-Vector3.new(0,.7,0)
     local gap=(intake-from).Magnitude
     local score=committed and -1 or gap
     if score<p.vacuumScore or (score==p.vacuumScore and id<p.vacuumTarget.id) then
      p.vacuumScore=score;p.vacuumTarget={position=goal,id=id}
     end
     if gap<=13 then target=intake;reach=13;vacuuming=true
     else vacuumApproaching=true end
    end
   end
   local canCollect=not docking and (vacuuming or hasSpace and (playerPull or not drop.raw or relay))
    and (target-from).Magnitude<=reach
   local targetModel=vacuuming and vacuum.model or hr and hr.Parent
   if canCollect then
    canCollect=scene.orePullClear(drop,from,target,targetModel)
   end
   local square=p.miningSquare
   if not p.pinOreOutOfReach and square and drop.raw and drop.fieldPart==square.field.part
    and drop.landed and drop.age>=OreDrops.SCATTER_TIME and hasSpace and not canCollect
    and (target-from).Magnitude>naturalReach and not vacuumApproaching
    and scene.cargoInSquare(square,from) then
    p.pinOreOutOfReach=square
   end
   local pickupDt=drop.launchAt and math.min(dt,now-drop.launchAt) or dt
   drop.dronePull=vacuuming
   local reached,groundSpeed=OreDrops.step(drop,{x=target.X,y=target.Y,z=target.Z},pickupDt,canCollect,reach)
   if groundSpeed and groundSpeed>1 and not drop.firstImpactPublished then
    drop.firstImpactPublished=true
    drop.part:SetAttribute('GroundImpactAt',drop.arc and drop.launchAt+drop.arc.contact or now)
    drop.part:SetAttribute('GroundImpactSpeed',groundSpeed)
    drop.part:SetAttribute('GroundImpactPosition',Vector3.new(drop.arc and drop.arc.landX or drop.x,drop.floor,drop.arc and drop.arc.landZ or drop.z))
    drop.part:SetAttribute('GroundImpactSerial',1)
   end
   if reached and los(Vector3.new(drop.x,drop.y,drop.z),target,targetModel,{pickupFolder,droneFolder},true,true) then
    if vacuuming then
     local lifted=Vector3.new(drop.x,drop.y,drop.z)
     if los(lifted,hr.Position,hr.Parent,{pickupFolder,droneFolder}) then
      drop.relayUntil=now+3;drop.queryAt=0
     end
    else
    local accepted=Pro.addCargo(data(p),drop.material,drop.units,Ca.capacity(data(p),previewPerks(p)))
    if accepted>0 then
     drop.units-=accepted;p.dirty=true;p.publishDirty=true
     p.collectSerial=(p.collectSerial or 0)+1
     p.collectTotal=(p.collectTotal or 0)+accepted
     p.player:SetAttribute('CollectedOreTotal',p.collectTotal)
     local color=drop.part.Color
     p.player:SetAttribute('MA_Collect',Http:JSONEncode({serial=p.collectSerial,total=p.collectTotal,at=now,units=accepted,pickupId=id,exhausted=drop.units==0,quiet=drop.quiet,physical=drop.raw==true,x=drop.x,y=drop.y,z=drop.z,
      r=math.floor(color.R*255),g=math.floor(color.G*255),b=math.floor(color.B*255)}))
     if drop.units==0 then
      drop.part:SetAttribute('Units',0);drop.part:SetAttribute('CollectedPosition',target);drop.part:SetAttribute('CollectedAt',now)
      drop.part.Transparency=1;Debris:AddItem(drop.part,.35);pickups[id]=nil
     else drop.part:SetAttribute('Units',drop.units);drop.clearPath=false;drop.queryAt=0 end
    end
    end
   end
   if pickups[id] and now>=(drop.snapshotAt or 0) then scene.snapshotOrePickup(drop) end
  end
 end
 if updatePrompt then
  for _,p in pairs(profiles) do
   local candidate=pickups[p.orePromptId] and p.orePromptId
   if p.player:GetAttribute('MA_OrePickup')~=candidate then p.player:SetAttribute('MA_OrePickup',candidate) end
  end
 end
end
local hitResource: any
local function secondaryMining(d: any,primary: any,amount: number,radius: number,contactKind: string?)
 if primary.field.junk then return false end -- One claimed target per salvage job.
 local assist=contactKind=='Aftershock'
 local preferOre=assist and primary.field.cfg.SelectionOnly
 local looseSeams=d.stats.earlyDrop or 0
 local candidates={}
 for _,other in ipairs(primary.field.resources) do
  if other~=primary and not other.paid and now>=other.readyAt and other.part.Parent
   and (not d.squareJob or scene.rockInSquare(d.squareJob,other)) then
   local distance=(other.position-primary.position).Magnitude
   if distance<=radius then
    local workToOre=0
    if preferOre then
     workToOre=other.cargoProduced and math.huge or math.max(0,other.hp-(other.maxHP-10)*looseSeams)
    end
    table.insert(candidates,{resource=other,distance=distance,workToOre=workToOre})
   end
  end
 end
 table.sort(candidates,function(a,b)
  if a.workToOre~=b.workToOre then return a.workToOre<b.workToOre end
  return a.distance==b.distance and a.resource.id<b.resource.id or a.distance<b.distance
 end)
 for _,candidate in ipairs(candidates) do
  local other=candidate.resource
  if sameRockType(d,other,assist) and not other.slots[d.id] then
   if not assist then other.slots[d.id]=1 end
   local accepted=hitResource(d,other,amount,true,radius,nil,contactKind)
   if not assist then other.slots[d.id]=nil;updateSlots(other) end
   -- An obstructed first candidate must not starve a reachable second one.
   if accepted then return other.id end
  end
 end
 return false
end
function scene.recordToolScar(r,point,width,depth,heat)
 r.toolScars=r.toolScars or {}
 if ToolRules.addScar(r.toolScars,point,width,depth,heat) then
  r.part:SetAttribute('ToolScars',Http:JSONEncode(r.toolScars))
 end
end
function scene.shiftReady(p)
 return (p.shiftSeconds or 0)>0 and p.shiftReadyRun==data(p).run.id
end
function scene.reclaimBattery(d,r,broken,abilityOrigin,contactKind)
 -- Violet and Emerald have extra fracture layers. Regrowth does not restore their charge.
 local deepCrystal=r.kind=='Crystal' and r.field.cfg.SelectionOnly and r.stageCount>3
 local freshCrack=deepCrystal and not broken and r.stage>(r.deepestFracture or 0)
 if freshCrack then r.deepestFracture=r.stage end
 if not (broken or freshCrack) or (abilityOrigin and not (deepCrystal and contactKind=='Breaker'))
  or d.recharging or (d.stats.reclaim or 0)<=0 then return end
 local before=d.battery
 d.battery=math.min(d.stats.batteryCapacity,before+d.stats.reclaim)
 if d.battery-before>=1 then RoleEffects.Pulse(d.pos,Color3.fromRGB(134,221,129),.4,2.4,.20) end
end
-- Resolve the full ray before any crystal shrinks or loses CanQuery.
-- The same path drives the damage and the client beam endpoints.
local function clusterEligible(d,p,rock,field)
 return rock.field==field and not rock.openReady and not rock.openingAt and not rock.paid and rock.hp>0 and not rock.clusterShot
  and rock.part.Parent and now>=rock.readyAt and rock.kind~='Geode'
  and (not d.squareJob or scene.rockInSquare(d.squareJob,rock))
  and playerCanMine(p,rock.field) and sameRockType(d,rock,d.squareJob~=nil and d.target==rock and rock.slots[d.id]~=nil)
end
function scene.prismTrace(d,primary,station,stopAtPrimary)
 local p=profiles[d.owner]
 if not healthy(p) then return nil end
 local spec=DroneCatalog.Types.Ramiel
 local scale=RoleConfig.Prominent.Ramiel
 local aim=primary.part.CFrame:PointToWorldSpace(Vector3.yAxis*primary.part.Size.Y*.24)
 local flat=Vector3.new(aim.X-station.X,0,aim.Z-station.Z)
 local origin=station+Vector3.yAxis*scale.lift
 if flat.Magnitude>.01 then origin+=flat.Unit*(scale.span*.06) end
 local direction=(aim-origin).Unit*spec.BeamRange
 local endpoint=origin+direction
 local ignored={droneFolder,pickupFolder,p.player.Character}
 local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Exclude
 local hits,selected,groundNormal={},nil,nil
 for _=1,12 do
  query.FilterDescendantsInstances=ignored
  local hit=workspace:Raycast(origin,direction,query)
  if not hit then break end
  local part=hit.Instance
  local rock=resources[part:GetAttribute('ResourceId') or '']
  if rock and rock.part==part then
   if #hits>=spec.BeamTargets or not clusterEligible(d,p,rock,primary.field) then
    endpoint=hit.Position;break
   end
   local item={rock=rock,point=hit.Position,normal=hit.Normal}
   table.insert(hits,item)
   if rock==primary then
    selected=item
    if stopAtPrimary then return {origin=origin,endpoint=endpoint,hits=hits,selected=selected} end
   end
  elseif part==workspace.Terrain or not part:IsA('BasePart') or part.CanCollide then
   endpoint=hit.Position
   if hit.Normal.Y>=.55 then groundNormal=hit.Normal end
   break
  end
  table.insert(ignored,part)
 end
 return selected and {origin=origin,endpoint=endpoint,hits=hits,selected=selected,groundNormal=groundNormal} or nil
end
function scene.cutRange(d,r)
 if d.role=='Striker' and r.field.cfg.ContinuousCrystals then
  return scene.flatFields and .6 or 2.2
 end
 return 1
end
hitResource=function(d: any,r: any,amount: number,secondary: boolean?,secondaryRange: number?,abilityOrigin: any,contactKind: string?,fractureContext: any)
 local p=profiles[d.owner]
 local assist=secondary and not abilityOrigin and contactKind=='Aftershock' and r.field.cfg.SelectionOnly==true
 local clusterHit=fractureContext and fractureContext.clusterHit
 local shot=fractureContext and fractureContext.clusterShot
 local clusterRole=contactKind=='PrismFinish' and 'Ramiel' or contactKind=='NomadFinish' and 'Nomad'
 local clusterFinish=clusterRole==d.role and clusterHit and clusterHit.rock==r and shot and shot==r.clusterShot
  and shot.finishKind==contactKind and shot.drone==d and now>=shot.blastAt
 if r.clusterShot and not clusterFinish then return false end
 local square=if clusterFinish then shot.square else d.squareJob
 if square and not scene.rockInSquare(square,r) then return false end
 if not healthy(p) or d.hp<=0 or r.openReady or r.openingAt or r.geodeRejectedOwner==d.owner or r.paid or r.hp<=0 or not r.part.Parent or not R.finite(amount) or amount<=0 or (not abilityOrigin and not assist and not clusterFinish and not r.slots[d.id]) or not playerCanMine(p,r.field) or now<r.readyAt then return false end
 local shared=square~=nil and not secondary and d.target==r and r.slots[d.id]~=nil
 if contactKind~='Consumable' and contactKind~='FieldTool' and not sameRockType(d,r,assist or shared) then return false end
 local recipient=d
 local job=d.specialJob
 local special=contactKind=='Special' and DroneCatalog.Types[d.role] and r.kind~='Geode' and job and not job.impacted and job.targetId==r.id and now>=job.startedAt+job.duration*job.impact
 local shell=contactKind=='SpecialShell' and DroneCatalog.Types[d.role] and r.kind=='Geode'
 if secondary then
  for id in pairs(r.slots) do
   local worker=drones[id]
   if worker and worker~=d and worker.target==r then
    if worker.owner~=d.owner then return false end
    if recipient==d or worker.id<recipient.id then recipient=worker end
   end
  end
 end
 if not DroneRoles.isWorker(d.role) and not (abilityOrigin and DroneRoles.ability(d.role)) then return false end
 if not abilityOrigin and not DroneRoles.isMiner(d.role) and not special and not shell and not clusterFinish then return false end
 if abilityOrigin then
  local hr=characterRoot(p)
  local carrierImpact=d.deployedCarrier and contactKind=='Breaker'
  if (not carrierImpact and (not hr or not nearMiningField(hr.Position,r.field))) or not abilityLineOfSight(p,abilityOrigin,r) then return false end
  for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=d.owner then return false end end
 elseif secondary then
  local primary=d.target
  -- The synchronous primary resolver alone can retain its contact through a
  -- final hit. No saved state/remote can authorize an echo from a retired node.
  if not primary or primary.field~=r.field or not primary.slots[d.id] or (primary.paid and primary.processingPrimary~=d.id) or (r.position-primary.position).Magnitude>(secondaryRange or d.stats.forkRange or 6) or (d.pos-r.position).Magnitude>d.stats.range or (d.pos-(d.workStation or scene.resourceStation(primary,d.targetSlot))).Magnitude>scene.cutRange(d,primary) or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
  if assist and primary.processingPrimary~=d.id then return false end
 elseif not clusterFinish then
  local released=special and job.launched
  local station=d.workStation or scene.resourceStation(r,d.targetSlot)
  if d.target~=r or (d.pos-station).Magnitude>(released and 3 or scene.cutRange(d,r))
   or (not clusterHit and not los(released and job.from or d.pos,released and job.contact or r.position,r.part,{droneFolder})) then return false end
 end
 -- A specialist's committed job, never its caller, supplies the finite hit budget.
 if special then amount=job.damage end
 if contactKind=='Consumable' or contactKind=='FieldTool' then r.consumableWorked=true end
 local baseAmount=amount
 local discoverySpeed=discoveries:Multiplier(p.player,'Speed')
 amount=amount*discoverySpeed
 if not abilityOrigin or contactKind=='Breaker' then amount*=Mining.contactMultiplier(d.role,r.kind,r.hardness,r.stage,r.stageCount) end
 if not abilityOrigin and r.field.cfg.SelectionOnly then
  if r.hardness>=Workshop.DEEP_CUT_HARDNESS then
   amount*=d.stats.deepCutMultiplier or 1
  end
  if d.battery>d.stats.batteryCapacity*.5 then amount*=1+(d.stats.liveWire or 0) end
 end
 local shotKind=special and DroneCatalog.Types[d.role].Projectile or nil
 local shotPower=shotKind and r.field.cfg.SelectionOnly and r.hardness>=Workshop.DEEP_CUT_HARDNESS
  and DroneCatalog.projectileLayerPower(d.role,r.stage) or 1
 amount*=shotPower
 local pinnedWork=(not abilityOrigin or contactKind=='Breaker') and d.squareJob and d.squareJob==p.miningSquare
 local startShift=pinnedWork and not secondary and not clusterFinish and scene.shiftReady(p)
 if pinnedWork and (startShift or (d.squareJob==p.shiftSquare and now<(p.shiftUntil or 0))) then amount*=1.5 end
 amount=amount*(abilityOrigin and contactKind~='Breaker' and 1 or Mining.efficiency(d.role=='Charger' and 'Red' or 'Blue',r.kind))
 if (r.kind=='Geode' or r.kind=='Core') then amount=amount*(d.stats.geodeMultiplier or 1) end
 if clusterFinish then
  amount=r.hp
 elseif special then
  amount=DroneCatalog.capDamage(d.role,r.maxHP,amount)
  -- Quarter-work subtraction can leave a floating-point residue on minerals
  -- such as Ruby. Resolve only arithmetic dust, never another real chunk.
  if r.hp>amount and r.hp-amount<=math.max(1,r.maxHP)*1e-10 then amount=r.hp end
 end
 if secondary then d.forkTarget=r.position;d.forkTargetId=r.id;d.forkUntil=now+.18 end
 if secondary and not r.field.cfg.SelectionOnly then scene.hazards:beam(d.pos,r.part.Position,5,'laser') end
 if not secondary and not abilityOrigin and not clusterFinish then r.processingPrimary=d.id end
 local previous=r.stage
 local isShot=special==true or clusterFinish or contactKind=='Breaker'
 local cutStart=not secondary and not abilityOrigin and not special and d.mining and d.beamSince and d.lastCutFX~=d.beamSince
 local shapeChanged=false
 local revealed=nil
 local before=r.hp
 if r.field.cfg.ContinuousCrystals then r.gemReward=false end
 local waiting=false
 local broken=R.damage(r,amount)
 local actual=r.paid and 0 or r.hp+10
 local nextStage=if r.field.cfg.ContinuousCrystals then Feel.stage(r.hp,r.maxHP-10,r.stageCount)
  else Feel.stage(actual,r.maxHP,r.stageCount)
 local fractured=nextStage>previous and not broken
 if startShift and r.hp<before then
  p.shiftReadyRun=nil;p.shiftSquare=d.squareJob;p.shiftUntil=now+p.shiftSeconds
 end
 -- Capture the incoming surface before any fracture changes its size or facing.
 local hitSurface=clusterHit
 if not hitSurface and (shotKind or special or (r.field.cfg.SelectionOnly and (broken or fractured or isShot or cutStart))) then
  local hitFrom=shotKind and (job.from or d.pos) or d.pos
  local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={r.part}
  local delta=r.part.Position-hitFrom
  local direction=delta.Magnitude>.01 and delta.Unit or -Vector3.yAxis
  local hit=workspace:Raycast(hitFrom,delta,query)
  hitSurface={point=hit and hit.Position or (shotKind and job.contact) or r.part.Position-direction*r.part.Size.Y*.32,normal=hit and hit.Normal or -direction}
 end
 r.lastHitAt=now
 if r.field.cfg.SelectionOnly and (r.hardness>1 or r.steady) and d.squareJob then
  r.lastPin=d.squareJob;r.lastPinOwner=d.owner
 end
 local tool=fractureContext and fractureContext.toolKind
 if tool=='Greatsword' and not r.slice then
  r.slice=math.clamp(.5+r.part.CFrame:PointToObjectSpace(fractureContext.point).Y/r.part.Size.Y,.35,.65);r.part:SetAttribute('SliceScale',r.slice);shapeChanged=true
 end
 if tool=='Melt' or tool=='JellyGrenade' or (special and d.role=='Starforge') or (not r.referenceCrystal and not abilityOrigin and d.mining and d.role=='Striker') then
  local rate=tool=='Melt' and 5 or tool=='JellyGrenade' and 1.6 or special and 2 or .9
  r.heat=math.min(1,(r.heat or 0)+amount/math.max(1,r.maxHP-10)*rate)
  local heat=math.floor(r.heat*4+1e-6)
  local changed=heat~=(r.heatBand or 0)
  if not broken and not (fractureContext and fractureContext.noScar) and (changed or tool=='Melt' or tool=='JellyGrenade') then
   local contact=fractureContext and fractureContext.point or abilityOrigin
   local point=contact and r.part.CFrame:PointToObjectSpace(contact)/r.part.Size or Vector3.zero
   local band=math.max(1,heat)
   scene.recordToolScar(r,point,.48+.12*band,.35+.1*band,true)
  end
  if changed then
   r.heatBand=heat;r.part:SetAttribute('MeltBand',heat);shapeChanged=true
   if not broken then RoleEffects.Pulse(r.part.Position+Vector3.new(0,r.part.Size.Y*.5,0),Color3.fromRGB(255,125,56),.35,math.min(13,r.part.Size.X*1.35),.32) end
  end
 end
 if not broken and contactKind=='FieldTool' and (tool=='BowlingBall' or tool=='Crowbar' or tool=='Sledgehammer') then
  local point=r.part.CFrame:PointToObjectSpace(fractureContext.point or abilityOrigin)/r.part.Size
  if tool=='Sledgehammer' and not fractureContext.point then point=Vector3.new(0,.5,0) end
  local width=tool=='Crowbar' and .475 or tool=='Sledgehammer' and .885 or .755
  scene.recordToolScar(r,point,width,width*.78,false)
 end
 if not r.field.cfg.SelectionOnly then
  if contactKind=='Breaker' then scene.hazards:blast(r.part.Position+Vector3.new(0,r.part.Size.Y*.5+.3,0),6,20,'heavy')
  elseif special then scene.hazards:blast(r.part.Position+Vector3.new(0,r.part.Size.Y*.5+.3,0),5,14,'special') end
 end
 -- Persistent cosmetic history is emitted only by accepted authoritative hits.
 -- Observers/late joiners reconstruct the same cavities without authorizing
 -- damage from local CSG geometry, bubbles or collision debris.
 if special and d.role=='Bubbler' then
  r.bubbleBites=math.min(6,(r.bubbleBites or 0)+1);r.part:SetAttribute('BubbleBites',r.bubbleBites)
 elseif contactKind=='Breaker' and d.role=='Charger' then
  r.smashDents=math.min(6,(r.smashDents or 0)+1);r.part:SetAttribute('SmashDents',r.smashDents)
 end
 if (special and d.role=='Bubbler') or (contactKind=='Breaker' and d.role=='Charger') then
  local depth=math.clamp(1-r.hp/math.max(1,r.maxHP-10),0,1)
  r.smashPressure=(r.smashDents or 0)>=6 and math.floor(depth*6+1e-7)/6 or 0
  r.part:SetAttribute('DamageDepth',depth)
  r.part:SetAttribute('DamageAt',now)
 end
 if special then
  job.impacted=true
  if r.part:GetAttribute('EffectDrone')==d.id then
   r.part:SetAttribute('EffectContactPoint',hitSurface.point);r.part:SetAttribute('EffectContactNormal',hitSurface.normal)
   r.part:SetAttribute('EffectDepleted',broken);r.part:SetAttribute('EffectDoneAt',now)
  end
 end
 r.stage=nextStage
 if r.stage~=previous or shapeChanged then
  r.part:SetAttribute('Stage',r.stage)
  if not clusterFinish then scene.poseResource(r) end
 end
 r.part:SetAttribute('HP',actual)
 if (r.field.cfg.SelectionOnly or clusterFinish) and hitSurface then
  if cutStart then d.lastCutFX=d.beamSince end
  r.part:SetAttribute('CutContactPoint',hitSurface.point);r.part:SetAttribute('CutContactNormal',hitSurface.normal)
  local projectile=clusterHit and fractureContext.projectile or shotKind and job.projectile
  r.part:SetAttribute('CutProjectile',clusterFinish and DroneCatalog.Types[d.role].Projectile or shotKind or '')
  r.part:SetAttribute('CutProjectileFX',projectile~=nil and projectile.Parent~=nil)
  r.part:SetAttribute('CutFractured',fractured)
  r.part:SetAttribute('CutIsShot',isShot==true);r.part:SetAttribute('CutContactAt',now)
  if broken then
   r.part:SetAttribute('CrystalBreakOwner',recipient.owner)
   r.splitAt=now
   r.part:SetAttribute('CrystalSplitAt',r.splitAt)
   r.part:SetAttribute('CrystalBreakAt',now)
  end
 end
 if shotKind and hitSurface and not clusterHit then
  RoleEffects.ProjectileContact(job.projectile,hitSurface.point,hitSurface.normal,r.stage>previous,broken,shotPower>1,now)
 end
 -- An allied specialist keeps its cargo value if a laser's Aftershock finishes a layer for it.
 local specialistCut=special==true or clusterFinish or (assist and recipient~=d)
 if not broken and r.kind~='Geode' and (r.stage>previous or (r.field.cfg.SelectionOnly and not r.cargoProduced
  and Mining.looseSeamsReady(r.hp,r.maxHP,recipient.stats.earlyDrop))) then
  award(recipient,r,specialistCut,true)
 end
 if not secondary and not abilityOrigin and Mining.kind(d.owned.type)=='Red' then
  d.minePulseSerial=d.minePulseSerial+1;d.minePulseAt=now;d.minePulseTargetId=r.id
 end
 if not clusterFinish then scene.reclaimBattery(assist and recipient or d,r,broken or waiting,abilityOrigin,contactKind) end
 if broken then
  r.part:SetAttribute('BreakSerial',1);r.part.CanQuery=false;r.part.CanCollide=false;r.part.CanTouch=false;r.removeAt=now+2
  if r.kind=='Geode' then
   local core=Mining.resource(seed:NextInteger(50,100),'Core',r.hardness)
   revealed={makeResource(r.field,r.position,'Core',core.maxHP,r.ore*4,core.size)}
   for n=1,4 do
    local a=n*math.pi/2;local shard=Mining.resource(seed:NextInteger(50,70),'Shard',r.hardness)
    table.insert(revealed,makeResource(r.field,r.position+Vector3.new(math.cos(a)*4,0,math.sin(a)*4),'Shard',shard.maxHP,r.ore,shard.size))
   end
   for _,child in ipairs(revealed) do child.consumableWorked=r.consumableWorked end
  else
   award(recipient,r,specialistCut)
   -- Breaks made by an ability do not refill the buttons.
   if contactKind~='FieldTool' or not (fractureContext and (fractureContext.toolKind=='Barrage' or fractureContext.toolKind=='Shockwave')) then scene.crewBreak(recipient.owner) end
   if r.field.cfg.ContinuousCrystals and math.random()<Workshop.CRYSTAL_CHANCE then
    scene.leaveGeode(recipient,r,specialistCut)
   end
   if (recipient.stats.oreDuplicator or 0)>0 and not abilityOrigin then
    RoleEffects.Pulse(r.part.Position,Color3.fromRGB(255,211,93),.45,3.5,.20)
   end
   -- Tools never manufacture more tools, including rocks later finished by a
   -- normal drone. The rock's ordinary ore payout remains unchanged.
   if not r.consumableWorked then
    if scene.fieldTools then scene.fieldTools:onRock(p,r) end
   end
   if not r.field.junk then
    local respawnClock=r.field.cfg.ReferenceCrystals and now or r.field.respawnClock
    -- The legacy field clock can run faster with more drones. Keep the
    -- minimum delay on the server clock for both natural and planted rocks.
    -- Square fields regrow fast so the crew is never left with an empty field.
    local wait=r.field.cfg.WholeField and C.SquareRockRespawn or C.MinimumRockRespawn
    local vacancy={at=respawnClock+wait+(r.field.cfg.WholeField and 0 or r.field.cfg.Respawn),regrowAt=now+wait,siteIndex=r.siteIndex}
    if r.field.cfg.ContinuousCrystals then vacancy.position=r.position end
    vacancy.landmark=r.landmark;vacancy.landmarkMineral=r.landmarkMineral
    if r.field.cfg.SelectionOnly and d.squareJob and d.squareJob==p.miningSquare then
     vacancy.owner=d.owner;vacancy.position=r.position
    end
    table.insert(r.field.respawnQueue,vacancy)
   end
  end
 end
 if not secondary and not abilityOrigin and not clusterFinish then
  local secondaryId
  if (d.stats.forkFraction or 0)>0 then secondaryId=secondaryMining(d,r,baseAmount*d.stats.forkFraction,d.stats.forkRange or 6) end
  if (d.stats.aftershock or 0)>0 and (broken or r.stage>previous) then
   local echoed=secondaryMining(d,r,(r.maxHP-10)*d.stats.aftershock/discoverySpeed,9,r.field.cfg.SelectionOnly and 'Aftershock' or nil)
   if echoed then
    secondaryId=echoed
    RoleEffects.Pulse(r.part.Position,Color3.fromRGB(125,208,255),1,8,.23)
   end
  end
  if Mining.kind(d.owned.type)=='Green' and r.stage>previous then
   -- Convert the capped effective echo back to base units: hitResource applies
   -- the current discovery multiplier once to every accepted contact.
   local echo=Mining.resonanceDamage(r.maxHP,d.stats.miningDPS*discoverySpeed,r.stage-previous)/discoverySpeed
   local echoed=secondaryMining(d,r,echo,Mining.RESONANCE_RANGE)
   if echoed then
    secondaryId=echoed
    d.minePulseSerial=d.minePulseSerial+1;d.minePulseAt=now;d.minePulseTargetId=r.id
   end
  end
  if broken and (secondaryId or d.stats.doubleBeam==1 or Mining.kind(d.owned.type)=='Red') then
   -- This short record is presentation only: scalar IDs/timestamps, no target,
   -- reservation, damage permission or resource reference survives retirement.
   d.mineBreakSerial=d.mineBreakSerial+1
   d.mineBreakContact={at=now,untilTime=math.max(now+.3,(r.splitAt or now)+.19),primaryId=r.id,secondaryId=secondaryId or '',beamSince=d.beamSince}
  end
  r.processingPrimary=nil
 end
 if broken then
  local workers={};for id in pairs(r.slots) do table.insert(workers,id) end;table.sort(workers)
  for _,id in ipairs(workers) do
   local worker=drones[id]
   if worker and worker.target==r then
    local manual=worker.manualTarget~=nil
    local pin=worker.squareJob
    local contact=worker.mineBreakContact
    local keepContact=contact~=nil and contact.primaryId==r.id and contact.at==now
    if not keepContact and r.field.cfg.SelectionOnly and worker.state=='Mine' and worker.mining then
     -- Cutting drones keep their last visible contact while the broken
     -- crystal is held on screen. The reservation still retires immediately.
     worker.mineBreakSerial+=1
     worker.mineBreakContact={at=now,untilTime=math.max(now+.3,(r.splitAt or now)+.19),primaryId=r.id,secondaryId='',beamSince=worker.beamSince}
     keepContact=true
    end
    if worker.specialJob and worker~=d and r.part:GetAttribute('EffectDrone')==worker.id then
     r.part:SetAttribute('EffectCancelledSerial',worker.specialJob.serial);r.part:SetAttribute('EffectType',nil)
    end
    retireTarget(worker,keepContact);worker.finishedCut=true
    -- A retired pin only finishes its existing target. A current pin may
    -- reserve a revealed core or shard inside its own boundary.
    if revealed and (not pin or pin==p.miningSquare) then
     for _,nextRock in ipairs(revealed) do
      if not next(nextRock.slots) and (not pin or scene.rockInSquare(pin,nextRock)) then
       worker.target=nextRock;worker.targetSlot=1;nextRock.slots[id]=1
       worker.squareJob=pin
       worker.manualTarget=manual and nextRock.id or nil
       worker.lingerUntil=nil;worker.lingerGoal=nil;worker.state='Travel'
       updateSlots(nextRock);break
      end
     end
    end
   else r.slots[id]=nil end
  end
  updateSlots(r)
  if special then
   d.lingerUntil=math.max(d.lingerUntil or now,job.startedAt+job.duration)
   -- A dead rock owns no work reservation. Retain only its cosmetic timeline
   -- so a yielding save can freeze the last recovery just like earlier hits.
   d.specialRecovery={part=r.part,serial=job.serial,startedAt=job.startedAt,duration=job.duration,impacted=true}
  end
 end
 if waiting then scene.releaseOpenWorkers(r) end
 return true,broken,r.stage>previous
end
scene.clusterShots={}
function scene.queueCluster(d,profile,job,hits,blastAt,finishKind)
 local shot={drone=d,profile=profile,runId=data(profile).run.id,hits=hits,square=d.squareJob,
  projectile=job.projectile,blastAt=blastAt,finishKind=finishKind}
 scene.clusterShots[shot]=true
 job.impacted=true
 for _,hit in ipairs(hits) do
  hit.rock.clusterShot=shot
  hit.rock.part:SetAttribute('BlastClusterSize',#hits)
  hit.rock.part:SetAttribute('ClusterBlackAt',now)
 end
end
local function prismCluster(d,p,path,field,radius)
 local hits=table.clone(path.hits)
 local seen={}
 local ignore={droneFolder,pickupFolder,p.player.Character}
 for _,hit in ipairs(hits) do seen[hit.rock]=true end
 for _,rock in ipairs(field.resources) do ignore[#ignore+1]=rock.part end
 for _,rock in ipairs(field.resources) do
  if seen[rock] or not clusterEligible(d,p,rock,field) then continue end
  for _,direct in ipairs(path.hits) do
   local origin=direct.rock.part.Position
   local delta=rock.part.Position-origin
   if delta.Magnitude<=radius and los(origin,rock.part.Position,nil,ignore) then
    local normal=delta.Magnitude>.01 and -delta.Unit or Vector3.yAxis
    hits[#hits+1]={rock=rock,point=rock.part.Position,normal=normal}
    break
   end
  end
 end
 return hits
end
function scene.firePrism(d,primary,job)
 if job~=d.specialJob or job.impacted or not primary.slots[d.id] then return false end
 local path=scene.prismTrace(d,primary,d.pos,false)
 if not path then return false end
 local spec=DroneCatalog.Types.Ramiel
 local profile=profiles[d.owner]
 local hits=prismCluster(d,profile,path,primary.field,spec.BlastRadius)
 local beamEnd=now+spec.BeamHold
 scene.queueCluster(d,profile,job,hits,beamEnd+spec.BlackPause,'PrismFinish')
 job.prismFired=true
 d.prismReadyAt=beamEnd+RoleConfig.RamielCloseTime
 local contacts={}
 for _,hit in ipairs(path.hits) do
  if hit~=path.selected then table.insert(contacts,hit) end
 end
 local center=primary.part.Position
 local ground=Vector3.new(center.X,primary.part:GetAttribute('GroundY') or center.Y-primary.part.Size.Y*.5,center.Z)
 if path.groundNormal and (path.endpoint-ground).Magnitude<=spec.BlastRadius*.82 then ground=path.endpoint end
 RoleEffects.PrismContact(job.projectile,path.origin,path.endpoint,path.selected,contacts,now,path.groundNormal,ground,spec.BlastRadius)
 return true
end
function scene.fireNomad(d,primary,job)
 if job~=d.specialJob or job.impacted or d.hp<=0 or d.target~=primary or resources[primary.id]~=primary
  or not primary.slots[d.id] or now<job.startedAt+job.duration*job.impact then return false end
 local p=profiles[d.owner]
 local field=primary.field
 if not healthy(p) or not clusterEligible(d,p,primary,field) or not los(job.from,job.contact,primary.part,{droneFolder,pickupFolder,p.player.Character}) then return false end
 local spec=DroneCatalog.Types.Nomad
 local center=primary.part.Position
 local ground=primary.part:GetAttribute('GroundY') or center.Y-primary.part.Size.Y*.5
 local ignore={droneFolder,pickupFolder,p.player.Character}
 for _,rock in ipairs(field.resources) do ignore[#ignore+1]=rock.part end
 local neighbors={}
 for _,rock in ipairs(field.resources) do
  if rock==primary then continue end
  local delta=rock.part.Position-center
  local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
  if distance<=spec.BlastRadius and math.abs(delta.Y)<=6 and clusterEligible(d,p,rock,field)
   and los(center,rock.part.Position,nil,ignore) then
   neighbors[#neighbors+1]={rock=rock,point=rock.part.Position,normal=delta.Magnitude>.01 and delta.Unit or Vector3.yAxis,distance=distance}
  end
 end
 table.sort(neighbors,function(a,b)
  return a.distance==b.distance and a.rock.id<b.rock.id or a.distance<b.distance
 end)
 local hits={}
 for i=1,math.min(#neighbors,spec.BlastTargets-1) do hits[i]=neighbors[i] end
 hits[#hits+1]={rock=primary,point=job.contact,normal=(job.from-job.contact).Unit}
 local shot={drone=d,blastAt=now,finishKind='NomadFinish',square=d.squareJob}
 job.impacted=true
 d.nomadReadyAt=job.startedAt+job.duration
 RoleEffects.NomadContact(job.projectile,job.contact,Vector3.new(center.X,ground,center.Z),spec.BlastRadius,now)
 for _,hit in ipairs(hits) do
  local rock=hit.rock
  rock.clusterShot=shot
  hitResource(d,rock,rock.hp,false,nil,nil,'NomadFinish',{clusterHit=hit,projectile=job.projectile,clusterShot=shot})
  rock.clusterShot=nil
 end
 return true
end
function scene.stepClusterShots()
 for shot in pairs(scene.clusterShots) do
  if now<shot.blastAt then continue end
  local drone=shot.drone
  local profile=profiles[drone.owner]
  if profile==shot.profile and profile.busy and not profile.leaving then continue end
  scene.clusterShots[shot]=nil
  local valid=profile==shot.profile and healthy(profile) and data(profile).run.id==shot.runId
   and drones[drone.id]==drone and drone.hp>0
  local anyBroken=false
  for _,hit in ipairs(shot.hits) do
   local rock=hit.rock
   if rock.clusterShot~=shot then continue end
   local broken=false
   if valid and resources[rock.id]==rock then
    local accepted
    accepted,broken=hitResource(drone,rock,rock.hp,false,nil,nil,shot.finishKind,
     {clusterHit=hit,projectile=shot.projectile,clusterShot=shot})
    broken=accepted and broken
    anyBroken=anyBroken or broken
   end
   rock.clusterShot=nil
   if not broken and rock.part.Parent then
    rock.part:SetAttribute('ClusterBlackAt',nil);rock.part:SetAttribute('BlastClusterSize',nil)
   end
  end
  RoleEffects.ClusterShatter(shot.projectile,anyBroken and now or nil)
 end
end
function scene.nomadTargetScore(d,rock,distance)
 local p=profiles[d.owner]
 local spec=DroneCatalog.Types.Nomad
 local center=rock.part.Position
 local neighbors=0
 for _,other in ipairs(rock.field.resources) do
  if other==rock then continue end
  local delta=other.part.Position-center
  if delta.X^2+delta.Z^2<=spec.BlastRadius^2 and math.abs(delta.Y)<=6 and clusterEligible(d,p,other,rock.field) then
   neighbors+=1
   if neighbors==spec.BlastTargets-1 then break end
  end
 end
 return distance-7*neighbors
end
local function chooseResource(d: any,field: any,square: any?)
 local best,score,bestPriority=nil,math.huge,-math.huge
 local bestRank,bestHealth,bestUsed,hasHelp=math.huge,math.huge,math.huge,false
 local focused=square and resources[square.directId]
 if focused and (focused.paid or focused.openReady or focused.geodeRejectedOwner==d.owner or not focused.part.Parent) then square.directId=nil;focused=nil end
 local helpReady=focused~=nil or square and d.squareHelpAt and now>=d.squareHelpAt
 local definition=DroneCatalog.Types[d.role]
 local chunkCycle=square and field.cfg.SelectionOnly and definition and not definition.Projectile
  and DroneCatalog.cycle(d.role,d.owned.base.miningDPS,d.stats.miningDPS)
 for _,r in ipairs(field.resources) do
  if not r.openReady and not r.openingAt and r.geodeRejectedOwner~=d.owner and (not focused or r==focused) and not r.paid and r.hp>0 and not r.clusterShot and r.part.Parent and now>=r.readyAt and (not r.blockedUntil or not r.blockedUntil[d.id] or now>=r.blockedUntil[d.id])
   and (not square or scene.rockInSquare(square,r)) then
   local used=0
   for _ in pairs(r.slots) do used+=1 end
   local helping=square~=nil and used>0
   -- One worker per unclaimed rock, starting with the rock the player aimed
   -- the plot at. Once those are taken, reinforce the hardest remaining cut.
   local rank=if helping then 2 elseif square and square.leadId==r.id then 0 else 1
   local healthRank=helping and -r.hp or r.hp
   if square and (rank>bestRank or rank==bestRank
    and (healthRank>bestHealth or healthRank==bestHealth and used>bestUsed)) then continue end
   -- A cube laser has a vertical strike column. The old helper ring can
   -- sit beyond the rock while the simulation still credits its damage.
   local singleOverhead=field.cfg.WholeField or scene.flatFields and d.role=='Striker'
   local capacity=if singleOverhead then 1 elseif focused then math.max(10,#profiles[d.owner].drones) elseif square then 10 else r.limit
   if used<capacity and sameRockType(d,r,helping) then
    if helping and not helpReady then hasHelp=true;continue end
    local neighbors=0
    if Mining.kind(d.owned.type)=='Green' then
     for _,other in ipairs(field.resources) do
      if other~=r and not other.paid and now>=other.readyAt and (not square or scene.rockInSquare(square,other))
       and (other.position-r.position).Magnitude<=Mining.RESONANCE_RANGE then neighbors=neighbors+1;if neighbors==3 then break end end
     end
    end
    local distance=(r.position-d.pos).Magnitude
    local value=if chunkCycle and r.kind=='Crystal' then
     DroneCatalog.chunkTargetScore(d.role,chunkCycle,scene.miningWarmup(d,r),d.stats.maxStep60,r,distance)
     elseif d.role=='Nomad' then
     scene.nomadTargetScore(d,r,distance)
     elseif square and field.cfg.SelectionOnly and r.hardness>=Workshop.DEEP_CUT_HARDNESS and definition and definition.Projectile then
     DroneCatalog.projectileTargetScore(d.role,d.stats,r,distance)
     elseif square and d.role=='Charger' then
     distance*.7-math.min(r.hp,1000)*.08
     elseif d.role=='Striker' and not field.junk then
     distance+(used>0 and 10000 or 0)
     else Mining.targetScore(d.owned.type,d.stats,r,distance,neighbors)
    local priority=0
    if square and r.cargoProduced then priority=-1
    elseif square and r.lastPin==square and r.lastPinOwner==d.owner and r.hp<r.maxHP-10 then
     priority=(d.resumePin==square and d.resumeResourceId==r.id) and 2 or 1
    end
    if not best or (square and (rank<bestRank or healthRank<bestHealth or used<bestUsed))
     or priority>bestPriority or priority==bestPriority and value<score then
     best=r;score=value;bestPriority=priority
     bestRank=rank;bestHealth=healthRank;bestUsed=used
    end
   end
  end
 end
 if square then
  if best or not hasHelp then d.squareHelpAt=nil
  elseif not d.squareHelpAt then d.squareHelpAt=now+2.15+(d.slot%7)*.12 end
 end
 if best then
  local occupied={};for _,slot in pairs(best.slots) do occupied[slot]=true end
  local slot=1;while occupied[slot] do slot=slot+1 end
  best.slots[d.id]=slot;updateSlots(best);d.target=best;d.targetSlot=slot;d.warmAt=nil;d.mineCharge=0;d.mining=false
  if square and square.leadId==best.id then square.leadId=nil end
 end
 return best
end
function scene.clearSquare(p)
 if not p.miningSquare then return end
 p.miningSquare=nil
 for _,d in ipairs(p.drones) do d.thinkUntil=nil end
 p.previousSquare=nil
 p.shiftSquare=nil;p.shiftUntil=nil
 p.player:SetAttribute('MA_Selector',nil)
 p.player:SetAttribute('MA_SelectorField',nil)
 p.player:SetAttribute('MA_SelectorWidth',nil)
 p.player:SetAttribute('MA_SelectorWorking',nil)
 p.player:SetAttribute('MA_SelectorStatus',nil)
 p.player:SetAttribute('MA_SelectorFocus',nil)
 p.player:SetAttribute('MA_SelectorPrevious',nil)
 p.player:SetAttribute('MA_SelectorPreviousWidth',nil)
 p.player:SetAttribute('MA_SelectorCleared',nil)
 p.player:SetAttribute('MA_SelectorPreviousCleared',nil)
 p.player:SetAttribute('MA_SelectorTransition',nil)
end
function scene.squareInRange(position,square)
 return Mining.selectorInRange(position,square.center)
end
function scene.committedWork(d)
 return d.target~=nil and (d.warmAt~=nil or d.mining or d.specialJob~=nil
  or (d.breaker~=nil and d.breaker.phase~='Approach'))
end
function scene.finishingDiscreteCut(d)
 local field=d.field and scene.patchById[d.field]
 if not field or not field.cfg.SelectionOnly then return false end
 if d.specialJob then return true end
 local recovery=d.specialRecovery
 if recovery and now<recovery.startedAt+recovery.duration then return true end
 local phase=d.breaker and d.breaker.phase
 return phase=='Dive' or phase=='Impact' or phase=='Recover'
end
function scene.publishSquareFocus(p,square)
 local focus=resources[square.focusId]
 local receipt
 if focus and not focus.paid and focus.hp>0 and focus.part.Parent then
  local phase,foreign='Queued',false
  for id in pairs(focus.slots) do
   local worker=drones[id]
   if worker and worker.owner==p.player.UserId and worker.target==focus then
    if worker.mining or worker.specialJob or (worker.breaker and worker.breaker.phase~='Approach') then phase='Cutting';break end
    if worker.warmAt then phase='Starting' elseif phase=='Queued' then phase='Travel' end
   else foreign=true end
  end
  if focus.openingAt then phase='Opening'
  elseif focus.openReady then phase='Ready'
  elseif focus.geodeRejectedOwner==p.player.UserId then phase='Underpowered'
  elseif not healthy(p) then phase='Paused'
  elseif focus.geodeTestAt and focus.geodeTestAt>now then phase='Gathering'
  elseif foreign and phase=='Queued' then phase='Claimed' end
  receipt=phase..':'..focus.id
 elseif square.focusId then square.focusId=nil end
 if p.player:GetAttribute('MA_SelectorFocus')~=receipt then p.player:SetAttribute('MA_SelectorFocus',receipt) end
end
function scene.idleSquareStatus(p,square)
 local growing,claimed=false,false
 for _,r in ipairs(square.field.resources) do
  if r.paid or r.hp<=0 or not r.part.Parent or not scene.rockInSquare(square,r) then continue end
  if now<r.readyAt then
   growing=true
  else
   local foreign=false
   for id in pairs(r.slots) do
    local worker=drones[id]
    if worker and worker.owner~=p.player.UserId then foreign=true;break end
   end
   if not foreign then return 'Waiting' end
   claimed=true
  end
 end
 if growing then return 'Growing' end
 if claimed then return 'Claimed' end
 for _,vacancy in ipairs(square.field.respawnQueue) do
  if vacancy.owner==p.player.UserId and scene.replacementSquare(square.field,vacancy) then return 'Refilling' end
 end
 return 'NoCrystals'
end
function scene.squareCleared(square)
 for _,r in ipairs(square.field.resources) do
  if not r.paid and r.hp>0 and r.part.Parent and scene.rockInSquare(square,r) then
   square.hadRocks=true
   return false
  end
 end
 return square.hadRocks==true
end
-- Project the current jobs onto one player-facing status. This never grants
-- work or takes a reservation, and bag capacity is only a pickup concern.
function scene.publishSquareStatus(p)
 local square=p.miningSquare
 if not square then return end
 scene.publishSquareFocus(p,square)
 local working,moving,arrived,holdingTravel=false,false,false,false
 local finishing
 local available,recharging=0,0
 local cutting,shared={},false
 for _,d in ipairs(p.drones) do
  if d.hp<=0 or d.carrierId or not DroneRoles.isWorker(d.role) then continue end
  available+=1
  if d.recharging then recharging+=1 end
  if scene.committedWork(d) then
   if d.squareJob==square then
    working=true
    if d.mining or d.specialJob or d.breaker then
     shared=shared or cutting[d.target]==true
     cutting[d.target]=true
    end
   elseif d.squareJob then finishing=finishing or d.squareJob end
  elseif d.squareJob==square and d.target then moving=true
  elseif d.state=='HoldSelector' and d.holdPin==square and d.intentGoal then
   if (d.pos-d.intentGoal).Magnitude>2 then holdingTravel=true else arrived=true end
  elseif p.previousSquare and (d.lingerUntil or d.specialRecovery or d.breaker) then holdingTravel=true end
 end
 if working or arrived then square.arrived=true end
 local transition=if finishing then 'Finishing'
  elseif not square.arrived and (moving or holdingTravel or now<(square.placedAt or 0)+C.Snapshot) then 'Moving' else nil
 local previous=finishing or (transition and p.previousSquare) or nil
 p.previousSquare=previous
 local previousCenter=previous and previous.center
 local previousWidth=previous and previous.half*2
 local cleared=scene.squareCleared(square)
 local previousCleared=if previous then scene.squareCleared(previous) else nil
 if p.player:GetAttribute('MA_SelectorPreviousWidth')~=previousWidth then p.player:SetAttribute('MA_SelectorPreviousWidth',previousWidth) end
 if p.player:GetAttribute('MA_SelectorPrevious')~=previousCenter then p.player:SetAttribute('MA_SelectorPrevious',previousCenter) end
 if p.player:GetAttribute('MA_SelectorCleared')~=cleared then p.player:SetAttribute('MA_SelectorCleared',cleared) end
 if p.player:GetAttribute('MA_SelectorPreviousCleared')~=previousCleared then p.player:SetAttribute('MA_SelectorPreviousCleared',previousCleared) end
 if p.player:GetAttribute('MA_SelectorTransition')~=transition then p.player:SetAttribute('MA_SelectorTransition',transition) end
 local status=if not healthy(p) or not characterRoot(p) then 'Paused'
  elseif Pro.cargoUnits(data(p))>=Ca.capacity(data(p),previewPerks(p)) and Workshop.starLevel(data(p),'autosell')==0 then 'BagFull'
  elseif working and p.shiftSquare==square and now<(p.shiftUntil or 0) then 'Surge'
  elseif scene.shiftReady(p) then 'SurgeReady'
  elseif p.compactor and p.compactor.pressJob and p.compactor.pressJob.startedAt then 'Pressing'
  elseif p.pinOreOutOfReach==square then 'LooseOre'
  elseif shared then 'SharedCut'
  elseif working then 'Working'
  elseif finishing then 'FinishingCut'
  elseif moving then 'Moving'
  elseif available==0 then 'NoMiners'
  elseif recharging==available then 'Recharging'
  elseif next(data(p).run.deliveries) then 'Hauling'
  elseif p.vacuumTarget then 'Gathering'
  else scene.idleSquareStatus(p,square)
 if p.player:GetAttribute('MA_SelectorStatus')~=status then p.player:SetAttribute('MA_SelectorStatus',status) end
 if p.player:GetAttribute('MA_SelectorWorking')~=working then p.player:SetAttribute('MA_SelectorWorking',working) end
end
function scene.releaseSquareApproach(d)
 local chargedPin=d.chargedPin
 release(d)
 d.chargedPin=chargedPin;d.squareSearchAt=nil
end
function scene.squareStep(p,d)
 if not DroneRoles.isWorker(d.role) or d.carrierId then return end
 local square=p.miningSquare
 if d.resumePin~=square then d.resumePin=nil;d.resumeResourceId=nil end
 if d.squareJob and d.squareJob~=square and not scene.committedWork(d) then scene.releaseSquareApproach(d);d.field=nil end
 if not square or d.target or d.breaker or d.specialRecovery then return end
 d.field=nil;d.autoField=nil
 if d.squareSearched~=square then d.squareHelpAt=nil end
 if now<(d.squareSearchAt or 0) and d.squareSearched==square and not d.finishedCut then return end
 d.finishedCut=nil
 d.squareSearchAt=now+.22;d.squareSearched=square
 if chooseResource(d,square.field,square) then
  d.field=square.field.id;d.squareJob=square;d.state='Travel'
  d.resumePin=nil;d.resumeResourceId=nil
 end
end
function scene.regrow(r,dt)
 if r.kind=='Geode' or r.openReady or r.openingAt then return end
 if not r.field.cfg.SelectionOnly or r.paid or r.clusterShot or not r.lastHitAt or now-r.lastHitAt<.8 or next(r.slots) then return end
 local owner=r.lastPinOwner and profiles[r.lastPinOwner]
 if owner and not owner.leaving and owner.miningSquare==r.lastPin then return end
 local maxWork=r.maxHP-10
 if r.hp>=maxWork or now<(r.nextRegenAt or 0) then return end
 r.nextRegenAt=now+.2
 r.hp=math.min(maxWork,r.hp+maxWork*.42*math.max(.2,dt))
 local previous=r.stage
 r.stage=if r.field.cfg.ContinuousCrystals then Feel.stage(r.hp,maxWork,r.stageCount)
  else Feel.stage(r.hp+10,r.maxHP,r.stageCount)
 if r.stage~=previous then
  r.part:SetAttribute('Stage',r.stage)
  scene.poseResource(r)
 end
 r.part:SetAttribute('HP',r.hp+10)
 if now>=(r.nextHealCue or 0) then r.nextHealCue=now+.48;r.part:SetAttribute('RegrowAt',now) end
end
local function eligible(d,field)
 local p=profiles[d.owner];return p and store:healthy(p.session) and characterRoot(p) and d.hp>0 and d.field==field.id and (d.pos-field.center).Magnitude<75
end
local function activeAssault(p)
 for _,field in ipairs(patches) do
  if field.e.phase=='Active' then
   for _,d in ipairs(p.drones) do if d.field==field.id and R.participates(field.e,d,data(p).run.id) then return true end end
  end
 end
 return false
end
local function grantClear(p,field)
 local key=field.cfg.Key
 if data(p).clearedFields[key] then return end
 if p.busy or not store:healthy(p.session) then p.pendingClears=p.pendingClears or {};p.pendingClears[key]=field;return end
 data(p).clearedFields[key]=true
 data(p).run.wins[key]=math.max(1,data(p).run.wins[key] or 0)
 p.dirty=true;p.publishDirty=true
 notice(p,field.cfg.Name..' unlocked permanently. Crystals keep replenishing.')
end
local function settleRuntime(p)
 if p.busy or not store:healthy(p.session) then return end
 local pending=p.pendingClears;p.pendingClears={}
 for _,field in pairs(pending or {}) do grantClear(p,field) end
end
local function encounterStep(field)
 if field.cfg.Turrets==0 or field.e.phase=='Cleared' then return end
 local defeated=true
 for _,t in ipairs(field.turrets) do if t.hp>0 then defeated=false;break end end
 if defeated then
  field.e.phase='Cleared'
  for uid in pairs(field.e.users) do local p=profiles[uid];if p then grantClear(p,field) end end
  for _,d in pairs(drones) do
   if d.field==field.id then
    release(d);d.chargeAt=nil;d.chargeTarget=nil;d.chainUntil=0
    if d.hp>0 then d.state='Travel' end
   end
  end
  field.e.roster={};field.e.users={}
  return
 end
 local active=false
 for id,record in pairs(field.e.roster) do
  local d=drones[id];local p=d and profiles[d.owner]
  if not p or d.field~=field.id or not R.participates(field.e,d,data(p).run.id) then field.e.roster[id]=nil
  else active=true end
 end
 if not active and field.e.phase=='Active' then
  field.e.phase='Guarded'
  for _,t in ipairs(field.turrets) do
   t.awake=false;t.fireAt=nil;t.lock=nil;t.model:SetAttribute('Awake',false);t.model:SetAttribute('Telegraph',false)
  end
 end
end
local function hurtDrone(d,damage)
 local absorbed=math.min(d.shield or 0,damage);d.shield=(d.shield or 0)-absorbed;damage=damage-absorbed
 if damage<=0 then return end
 if damage>=d.hp then kill(d) else d.hp=d.hp-damage end
end
local function turretStep(field: any)
 if field.e.phase~='Active' then
  for _,t in ipairs(field.turrets) do t.fireAt=nil;t.lock=nil;t.model:SetAttribute('Telegraph',false) end;return
 end
 for _,t in ipairs(field.turrets) do
  if t.hp>0 then
   if t.fireAt then
    local d=t.lock;local p=d and profiles[d.owner]
    if p and p.busy then t.fireAt=now+.2;t.model:SetAttribute('FireAt',t.fireAt)
    elseif not d or not p or not R.participates(field.e,d,data(p).run.id) then t.fireAt=nil;t.lock=nil;t.nextShot=now+1
    elseif now>=t.fireAt then
     scene.hazards:beam(t.emitter.Position,t.aim,field.cfg.Damage,'turret')
     local hit=(d.pos-t.aim).Magnitude<=3.5 and (d.pos-t.emitter.Position).Magnitude<55 and los(t.emitter.Position,t.aim,d.model,{t.model,droneFolder})
     if hit then
      local stats=field.e.roster[d.id].stats;hurtDrone(d,field.cfg.Damage*(1-(stats.damageReduction or 0)))
     end
     t.model:SetAttribute('ShotContact',hit and d.pos or nil);t.model:SetAttribute('ShotAt',now)
     t.shotSerial=t.shotSerial+1;t.model:SetAttribute('ShotSerial',t.shotSerial)
     t.fireAt=nil;t.lock=nil;t.nextShot=now+(field.cfg.ShotCooldown or 1.6)
    end
   elseif now>=t.nextShot then
    local best,dist=nil,55
    for _,d in pairs(drones) do
     local p=profiles[d.owner];local n=(d.pos-t.emitter.Position).Magnitude
     if p and R.participates(field.e,d,data(p).run.id) and eligible(d,field) and n<dist and los(t.emitter.Position,d.pos,d.model,{t.model,droneFolder}) then best=d;dist=n end
    end
    if best then t.lock=best;t.aim=best.pos;t.fireAt=now+.8;t.model:SetAttribute('Aim',t.aim);t.model:SetAttribute('FireAt',t.fireAt) end
   end
  end
  t.model:SetAttribute('Telegraph',t.fireAt~=nil);publishTurretHealth(t)
 end
end
local function combatHit(d,field,target,stats)
 local p=profiles[d.owner]
 if not healthy(p) or not R.participates(field.e,d,data(p).run.id) or target.hp<=0 then return end
 local damage=stats.shotDamage
 if target.hp<=field.cfg.TurretHP*.35 then damage=damage*(stats.finisherMultiplier or 1) end
 if (stats.critChance or 0)>0 and seed:NextNumber()<stats.critChance then damage=damage*2;d.lastCritAt=now end
 d.shotSerial=(d.shotSerial or 0)+1;d.lastShotAt=now
 local dealt=math.min(target.hp,damage);target.hp=math.max(0,target.hp-damage)
 scene.hazards:beam(d.pos,target.emitter.Position,12,'combat')
 local kills=target.hp<=0 and 1 or 0
 if dealt>0 then R.markContribution(field.e,d.owner,data(p).run.id) end
 if (stats.splashFraction or 0)>0 then
  for _,other in ipairs(field.turrets) do
   if other~=target and other.hp>0 and (other.emitter.Position-target.emitter.Position).Magnitude<=(stats.splashRange or 6) and (other.emitter.Position-d.pos).Magnitude<=stats.range and los(d.pos,other.emitter.Position,other.model,{droneFolder}) then
    other.hp=math.max(0,other.hp-damage*stats.splashFraction);if other.hp<=0 then kills=kills+1 end
    publishTurretHealth(other)
    d.chainTarget=other.emitter.Position;d.chainTargetId=other.model:GetAttribute('TurretId');d.chainUntil=now+.2;break
   end
  end
 end
 if kills>0 and (stats.salvageFraction or 0)>0 then
  d.hp=math.min(d.stats.maxHealth,d.hp+d.owned.base.maxHealth*stats.salvageFraction*kills)
  d.model:SetAttribute('RepairSerial',(d.model:GetAttribute('RepairSerial') or 0)+1)
 end
 publishTurretHealth(target)
end
local function travelSpeed(d)
 local tuning=RoleConfig.Prominent[d.role]
 local roleScale=tuning and tuning.speed or 1
 local returning=d.state=='Travel' and d.chargedPin and d.chargedPin==d.squareJob
 if d.state=='ToCharge' or returning then
  local p=profiles[d.owner]
  local fieldCharge=p and p.miningSquare and (p.fieldCharge or 0)>0
  local boost=p and (returning or not fieldCharge) and Workshop.chargeSpeed(data(p)) or 1
  return d.stats.maxStep60*1.5*boost*roleScale
 end
 local baseSpeed=d.stats.maxStep60
 if d.state=='Follow' then
  local agility=scene.followAgility(d)
  local variation=d.swarmTraits and 1+(d.swarmTraits.speed-1)*.35*(d.swarmCruise or 0) or 1
  baseSpeed=math.min(math.max(baseSpeed,.39*agility)*variation*(1+.24*agility),math.max(.5,baseSpeed))
 end
 local speed=baseSpeed*roleScale*(d.role=='Medic' and .68 or (d.role=='Courier' and (d.loadSpeed or 1)*(1+(d.stats.fullAuto or 0)) or (d.state=='BreakerDive' and 2.5 or 1)))
 if scene.flatFields and d.state~='BreakerDive' then
  -- Drones are slower than the player and differ a little from each other.
  d.swarmTraits=d.swarmTraits or Feel.swarmTraits(d.id)
  speed=math.min(speed,Feel.droneCruiseStep(d.swarmTraits,d.goal and (d.goal-d.pos).Magnitude or 0))
 end
 return speed
end
local function move(d,goal,dt)
 d.intentGoal=goal
 local formation=d.state=='Follow' or d.state=='HoldSelector' or d.state=='Waiting'
 if formation or not scene.runStart or scene.flatFields then d.descentOrigin=nil
 elseif d.lastMoveFormation and d.pos.Y-goal.Y>2.5 then d.descentOrigin=d.pos end
 d.lastMoveFormation=formation
 local descentProgress=1
 if d.descentOrigin then
  goal,descentProgress=Feel.descentGoal(d.descentOrigin,d.pos,goal)
  if descentProgress>=1 then d.descentOrigin=nil end
 end
 local settling=d.target~=nil or d.state=='ToCharge' or d.state=='BreakerRecover' or d.state=='GrowRecover' or d.state=='Deliver' or d.state=='Collect' or d.state=='Pickup' or d.state=='GrowApproach' or d.state=='Plant' or d.state=='Intake'
  or d.state=='HoldSelector' or d.state=='Waiting' or d.state=='StorageFull' and d.deployedCarrier
 local weight=d.state=='Thinking' and 0 or (d.state=='Recover' or d.state=='Vacuum' and (goal-d.pos).Magnitude<1) and 0
  or (settling and math.clamp(((goal-d.pos).Magnitude-1)/5,0,1) or 1)
 -- Calm escort/holding pressure; strong predictive passing is for job travel.
 local escort=d.state=='Follow' or d.state=='HoldSelector' or d.state=='Waiting' or d.state=='StorageFull' and d.deployedCarrier
 local flock=scene.flatFields and (escort and 1 or .45) or nil
 local desired=Feel.swarmOffset(d.pos,d.id,swarmGrid,weight,flock)*Feel.SwarmForce*(escort and (flock and 1.1 or .22) or (flock and .45 or .18)+.82*descentProgress)
 if flock then desired=Vector3.new(desired.X,0,desired.Z) end
 d.flightSteering=weight==0 and Vector3.zero or Feel.smoothSwarm(d.flightSteering,desired,dt)
 d.goal=goal
 local work=d.target~=nil or d.state=='ToCharge' or d.state=='Deliver' or d.state=='BreakerDive' or d.state=='BreakerRecover' or d.state=='Recover' or d.state=='Plant' or d.state=='GrowApproach' or d.state=='Intake'
 local speed=travelSpeed(d)
 local flight=RoleConfig.Prominent[d.role]
 local response=d.orePickupId and d.state=='Collect' and Workshop.COURIER_APPROACH_RESPONSE or flight and flight.response
  or 1
 if d.state=='Follow' then response+=.28*scene.followAgility(d) end
 if scene.flatFields and not d.target then
  -- Softer, floatier thrust while cruising; each drone reacts at its own pace.
  d.swarmTraits=d.swarmTraits or Feel.swarmTraits(d.id)
  response*=.45+.35*(d.swarmTraits.rate-.68)/.64
 end
 d.flightResponse=response;d.flightWork=work;d.flightSpeed=speed
 d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,speed,dt,work,nil,response,d.flightMass,d.flightSteering)
 local yaw=Feel.flightYaw(d.pos,goal,d.velocity,d.yaw)
 d.yaw=Feel.approachYaw(d.yaw,yaw,dt*(flight and flight.turn or 1))
 -- Fixed-rate logical motion; snapshotDrone publishes its physical proxy.
end
function scene.followAgility(d)
 local prominent=RoleConfig.Prominent[d.role]
 local span=prominent and prominent.span or RoleConfig.HullSpans[d.role] or 2.75
 return math.clamp((2.8-span)/.65,0,1)
end
function scene.followHeight(d)
 if scene.flatFields then return scene.cubeCruiseHeight end
 local agility=scene.followAgility(d)
 if scene.runStart then
  return Feel.quarryFollowHeight(d.role,0,0)-7*agility
 end
 return Feel.ReferenceFollowHeight-3*agility
end
function scene.followGoal(d,position,count,velocity,dt)
 if d.role=='Nomad' and not scene.flatFields then return Feel.followGoal(position,d.slot,count,now,d.owned.base.maxStep60,false,d.flightHeight) end
 local goal
 d.swarmTraits=d.swarmTraits or Feel.swarmTraits(d.id)
 if scene.flatFields then
  goal=Feel.boidFollow(position,velocity or Vector3.zero,d.swarmTraits,now)
  return Vector3.new(goal.X,home.Y+scene.cubeCruiseHeight,goal.Z)
 end
 local p=profiles[d.owner]
 local ring=p and p.followRing and p.followRing[d.id]
 if not ring then
  local delta=d.pos-position
  local _,member=next(p and p.followRing or {})
  ring={angle=delta.X^2+delta.Z^2>.01 and math.atan2(delta.Z,delta.X) or d.swarmTraits.phase,radius=member and member.radius or Feel.ringRadius(0)}
 end
 goal,d.swarmCruise=Feel.swarmFollow(position,velocity or Vector3.zero,d.slot,count,now,
  scene.followHeight(d),d.swarmTraits,d.swarmCruise,dt or C.Tick,ring)
 if scene.flatFields then return Vector3.new(goal.X,home.Y+scene.cubeCruiseHeight,goal.Z) end
 return goal
end
function scene.movePlotQueue(queue,dt)
 local goals=Feel.plotQueueSlots(queue.drones,queue.edge,queue.axis,queue.length,queue.height)
 for _,worker in ipairs(queue.drones) do move(worker,goals[worker.id],dt) end
end
function scene.waitAtPlot(d,p,field,square,dt)
 local site=square or field
 p.plotWaitEdges=p.plotWaitEdges or {}
 local layout=square and square.waitEdge or not square and p.plotWaitEdges[field.id]
 if not layout then
  local frame,halfX,halfZ
  if square then frame=CFrame.new(square.center);halfX,halfZ=square.half,square.half
  else
   local size=field.part.Size
   frame=field.part.CFrame*CFrame.new(0,size.Y*.5,0);halfX,halfZ=size.X*.5,size.Z*.5
  end
  local hr=characterRoot(p)
  local edge,axis,length=Feel.plotQueueEdge(frame,halfX,halfZ,hr and hr.Position or home)
  layout={edge=edge,axis=axis,length=length,height=square and (scene.flatFields and scene.cubeCruiseHeight or scene.runStart and 19.6 or Feel.ReferenceFollowHeight) or 10}
  if square then square.waitEdge=layout else p.plotWaitEdges[field.id]=layout end
 end
 if not scene.plotQueues then
  scene.movePlotQueue({drones={d},edge=layout.edge,axis=layout.axis,length=layout.length,height=layout.height},dt)
  return
 end
 local bySite=scene.plotQueues[p]
 if not bySite then bySite={};scene.plotQueues[p]=bySite end
 local queue=bySite[site]
 if not queue then queue=table.clone(layout);queue.drones={};bySite[site]=queue end
 table.insert(queue.drones,d)
end
function scene.flushPlotQueues(dt)
 local queues=scene.plotQueues;scene.plotQueues=nil
 for _,bySite in pairs(queues) do
  for _,queue in pairs(bySite) do scene.movePlotQueue(queue,dt) end
 end
end
function scene.holdSquare(d,p,dt)
 local square=p.miningSquare
 if not square or d.carrierId then return false end
 d.mining=false;d.state='HoldSelector';d.holdPin=square
 scene.waitAtPlot(d,p,square.field,square,dt)
 return true
end
local function supportDrone(d: any,p: any,hr: any,dt: number)
 if d.target or d.combatTarget then release(d) end
 local best,score=nil,math.huge
 for _,ally in ipairs(p.drones) do
  if ally~=d and ally.hp>0 and ally.role~='Courier' and (not p.miningSquare or not ally.recharging and scene.squareInRange(ally.pos,p.miningSquare)) then
   local distance=(ally.pos-d.pos).Magnitude
   local injured=ally.hp<ally.stats.maxHealth
   local rank=(injured and -1000 or 0)+(ally.target and -100 or 0)+distance
   if rank<score then best,score=ally,rank end
  end
 end
 if d.repairTarget then
  if d.repairTarget.hp>0 and d.repairTarget.hp<d.repairTarget.stats.maxHealth then best=d.repairTarget
  else d.repairTarget=nil;d.repairChargeAt=nil;d.healTargetId=nil end
 end
 if (not best or (best.hp>=best.stats.maxHealth and not best.target)) and now>=(d.healUntil or 0) then
  d.state='Follow';d.mining=false;d.healTargetId=nil
  if scene.holdSquare(d,p,dt) then return end
  move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt);return
 end
 local goal=best and best.pos+Vector3.new(2,1,2) or hr.Position+Vector3.new(3,d.flightHeight,3)
 d.state='Support';d.mining=false;move(d,goal,dt)
 local inRange=best and best.hp>0 and best.hp<best.stats.maxHealth and (best.pos-d.pos).Magnitude<=RoleConfig.Types.Medic.AttackRange and los(d.pos,best.pos,best.model,{droneFolder,p.player.Character})
 if inRange and now>=(d.healAt or 0) then
  if not d.repairChargeAt then d.repairChargeAt=now;d.repairTarget=best;d.healTargetId=best.id end
  if now-d.repairChargeAt>=RoleConfig.Types.Medic.ChargeWindup then
   best.hp=math.min(best.stats.maxHealth,best.hp+(d.stats.healAmount or RoleConfig.Types.Medic.HealAmount))
   d.healAt=d.repairChargeAt+RoleConfig.Types.Medic.AttackCooldown;d.healTargetId=best.id;d.healUntil=now+.45
   d.repairChargeAt=nil;d.repairTarget=nil
   best.model:SetAttribute('RepairSerial',(best.model:GetAttribute('RepairSerial') or 0)+1)
  end
 else d.repairChargeAt=nil;d.repairTarget=nil end
 if d.repairChargeAt then d.state='RepairCharge'
 elseif now<(d.healUntil or 0) then d.state='Heal'
 else d.healTargetId=nil end
end
local function attackDrone(d: any,field: any,dt: number)
   release(d,true);local target,dist=nil,math.huge
   for _,t in ipairs(field.turrets) do local n=(t.emitter.Position-d.pos).Magnitude;if t.hp>0 and n<dist then target=t;dist=n end end
   if target then
    local stats=field.e.roster[d.id].stats
    local side=d.evade%2==0 and 1 or -1
    local offset=Vector3.new(side*(11+(d.slot%3)*3),10+((d.flightHeight or Feel.FollowHeight)-Feel.FollowHeight),11)
    local goal=target.emitter.Position+offset.Unit*math.min(offset.Magnitude,stats.range*.92)
    d.state='Attack';move(d,goal,dt)
    if (d.pos-target.emitter.Position).Magnitude<=stats.range and los(d.pos,target.emitter.Position,target.model,{droneFolder}) then
     d.combatTarget=target;d.mining=true;d.targetPosition=target.emitter.Position
     if d.role=='Charger' then
      if d.chargeTarget and d.chargeTarget~=target then d.chargeAt=nil;d.chargeTarget=nil end
      if not d.chargeAt and now>=d.shotAt then
       d.chargeAt=now+(RoleConfig.Types.Charger.ChargeWindup or .85);d.chargeTarget=target;RoleEffects.Charge(d.emitter.Position,target.emitter.Position,false)
      elseif d.chargeAt and now>=d.chargeAt then
       local charged=Pro.clone(stats);charged.shotDamage=stats.shotDamage*1.75
       RoleEffects.Charge(d.emitter.Position,target.emitter.Position,true);combatHit(d,field,target,charged)
       d.shotAt=now+stats.shotInterval;d.chargeAt=nil;d.chargeTarget=nil
      end
     elseif now>=d.shotAt then combatHit(d,field,target,stats);d.shotAt=now+stats.shotInterval end
    else d.chargeAt=nil;d.chargeTarget=nil end
   else d.chargeAt=nil;d.chargeTarget=nil end
end
function scene.overheadWorker(d,r)
 local definition=DroneCatalog.Types[d.role]
 return r.field.cfg.SelectionOnly and d.role~='Charger'
  and (not definition or not definition.Projectile or RoleConfig.DownwardGunDepth[d.role]~=nil)
end
function scene.planMiningStations()
 local plans={}
 for _,d in pairs(drones) do
  local r=d.target
  if not r or r.paid or d.hp<=0 or d.recharging or not scene.overheadWorker(d,r) then continue end
  local p=profiles[d.owner]
  if not healthy(p) or not characterRoot(p) or now<(d.thinkUntil or 0) then continue end
  local plan=plans[r]
  if not plan then plan={active={},ranks={},approachDistance=math.huge};plans[r]=plan end
  local focused=p.miningSquare and p.miningSquare.directId==r.id
  -- A focus command reserves a seat for every miner immediately. Ordinary
  -- automatic mining retains its single approaching drone and compact queue.
  if focused or (d.warmAt or d.specialJob or d.mining) and d.workTargetId==r.id and d.workStation then
   table.insert(plan.active,d)
  else
   d.workSeat=nil
   local distance=(d.pos-r.position).Magnitude
   local current=plan.approach
   local committed=r.approachingDrone
   if not current or (d==committed or current~=committed and (distance<plan.approachDistance
    or distance==plan.approachDistance and d.id<current.id)) then
    plan.approach=d;plan.approachDistance=distance
   end
  end
 end
 for r,plan in pairs(plans) do
  table.sort(plan.active,function(a,b)
   local left,right=a.workSeat or math.huge,b.workSeat or math.huge
   if left~=right then return left<right end
   return a.id<b.id
  end)
  for rank,d in ipairs(plan.active) do plan.ranks[d]=rank;d.workSeat=rank end
  if plan.approach then plan.ranks[plan.approach]=#plan.active+1 end
  r.approachingDrone=plan.approach
 end
 scene.workPlans=plans
end
function scene.awaitWorkStation(d,p,r,dt)
 if not scene.workPlans or not scene.overheadWorker(d,r) then return false end
 local plan=scene.workPlans[r]
 if not plan then
  plan={active={},ranks={[d]=1},approach=d};scene.workPlans[r]=plan;r.approachingDrone=d
  return false
 end
 if plan.ranks[d] then return false end
 if not plan.approach then
  plan.approach=d;plan.ranks[d]=#plan.active+1;r.approachingDrone=d
  return false
 end
 d.state='Waiting';d.mining=false;d.warmAt=nil
 scene.waitAtPlot(d,p,r.field,d.squareJob,dt)
 return true
end
function scene.overheadStation(d,r,dt)
 local plan=scene.workPlans and scene.workPlans[r]
 local rank=plan and plan.ranks[d] or 1
 local station=scene.resourceStation(r,1,r.field.cfg.ContinuousCrystals)
 if RoleConfig.DownwardGunDepth[d.role] then
  station=Vector3.new(r.part.Position.X,math.max(station.Y,r.part.Position.Y+8),r.part.Position.Z)
 end
 if rank>1 then
  local inner=rank<=5
  local angle=if inner then (rank-1.5)*math.pi*.5 else (rank-6)*2*math.pi/5
  local radius=inner and 4.5 or 9.2
  if rank>10 then angle=((rank-11)%10)*2*math.pi/10;radius=9.2+(math.floor((rank-11)/10)+1)*4.7 end
  station+=Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
 end
 -- Slide into a gap when someone leaves. Retain a launched shot's station
 -- through contact; a waiting reservation never leaves an empty seat.
 if d.workTargetId==r.id and d.workStation then
  if d.specialJob and d.specialJob.launched and not d.specialJob.impacted then return d.workStation end
  station=d.workStation:Lerp(station,math.min(1,(dt or C.Tick)*3.6))
 end
 d.workTargetId=r.id;d.workStation=station
 return station
end
local function committedStation(d,r,dt)
 if scene.overheadWorker(d,r) then return scene.overheadStation(d,r,dt) end
 if d.workTargetId~=r.id then
  d.workTargetId=r.id
 d.workStation=scene.resourceStation(r,d.targetSlot,r.field.cfg.ContinuousCrystals)
  local definition=DroneCatalog.Types[d.role]
  if definition and definition.Projectile=='Nomad' then
   local approach=r.position-d.pos
   d.workYaw=approach.X^2+approach.Z^2>1 and Feel.levelYaw(d.pos,r.position,d.yaw) or d.slot*2.4
   local ground=r.part:GetAttribute('GroundY') or r.position.Y
   local frame=CFrame.new(r.position.X,ground,r.position.Z)*CFrame.Angles(0,d.workYaw,0)
   d.workStation=frame:PointToWorldSpace(Vector3.new(0,definition.StationHeight,1.43))
  elseif definition and RoleConfig.DownwardGunDepth[d.role] and r.kind~='Geode' then
   local target=r.part.Position
   d.workStation=Vector3.new(target.X,math.max(d.workStation.Y,target.Y+8),target.Z)
  elseif definition and definition.Projectile then
   local direction=d.slot*2.4
   local approach=d.pos-r.position
   if r.field.cfg.SelectionOnly and approach.X^2+approach.Z^2>1 then
    direction=math.atan2(approach.Z,approach.X)
   end
   local prism=definition.Projectile=='Prism' and r.kind~='Geode'
   local offset=prism and definition.BeamStation or 9
   local bestCount=0
   for turn=0,3 do
    local angle=direction+turn*math.pi/2
    local station=r.position+Vector3.new(math.cos(angle)*offset,prism and 6.8 or 6.3,math.sin(angle)*offset)
    if turn==0 then d.workStation=station end
    if prism then
     local path=scene.prismTrace(d,r,station,false)
     if path and #path.hits>bestCount then
      d.workStation=station;bestCount=#path.hits
      if bestCount==definition.BeamTargets then break end
     end
    elseif los(station,r.position,r.part,{droneFolder}) then d.workStation=station;break end
   end
  end

 end
 return d.workStation
end
-- A laser miner's first ignition after a rest is the long, showy charge the
-- owner asked for; hopping to the next rock re-ignites quickly so mining pace
-- is unchanged once the crew is working. Flat fields only.
scene.FIRST_CHARGE=1.9
scene.FIRST_CHARGE_REST=6
function scene.miningWarmup(d,r)
 if r and scene.flatFields and not d.mining
  and not (DroneCatalog.Types[d.role] and DroneCatalog.Types[d.role].Projectile)
  and now-(d.lastBeamAt or -math.huge)>scene.FIRST_CHARGE_REST then
  return scene.FIRST_CHARGE
 end
 -- Quarry cutters charge during the last part of their approach.
 -- Ignition upgrades can still shorten the beat.
 if r and r.field.cfg.ContinuousCrystals and d.role=='Striker' then return math.max(.05,d.stats.warmup*.25) end
 local definition=DroneCatalog.Types[d.role]
 if r and (d.role=='Ramiel' or d.role=='Nomad') then return .08 end
 if r and definition and definition.Projectile then
  return r.field.cfg.ContinuousCrystals and math.max(.065,d.stats.warmup*.28) or math.max(.08,d.stats.warmup*.52)
 end
 if r and r.field.cfg.SelectionOnly and r.kind=='Crystal' and definition and not definition.Projectile then
  return math.max(.08,d.stats.warmup/Ca.LASER_CHARGE_SCALE)
 end
 return r and math.max(.08,d.stats.warmup) or d.stats.warmup
end
local function mineDrone(d: any,p: any,field: any,dt: number)
 if d.combatTarget or d.state=='Attack' then release(d);d.chargeAt=nil;d.chargeTarget=nil end
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 -- A field order keeps the fleet moving; individual orders remain precise.
 if not field.junk and not d.target and d.autoField==field.id then chooseResource(d,field) end
 local r=d.target
 if r then
  if scene.awaitWorkStation(d,p,r,dt) then return end
  local goal=committedStation(d,r,dt);d.state='Travel';move(d,goal,dt)
  local distance=(d.pos-goal).Magnitude
  if distance<=scene.cutRange(d,r) and now>=r.readyAt and d.hp>0 and los(d.pos,r.position,r.part,{droneFolder}) then
   d.obstructedAt=nil
   d.warmAt=d.warmAt or now;d.state='Warmup'
   if now-d.warmAt>=scene.miningWarmup(d,r) then
    if not d.mining then d.beamSince=now end
    d.state='Mine';d.mining=true;d.lastBeamAt=now
    local damage,charge=Mining.step('Blue',d.mineCharge,dt,d.stats.miningDPS);d.mineCharge=charge
    if damage>0 then hitResource(d,r,damage,false,nil,nil,DroneCatalog.Types[d.role] and r.kind=='Geode' and 'SpecialShell' or nil) end
   end
  else
   d.warmAt=nil;d.mineCharge=0;d.mining=false
   if distance<=1 and now>=r.readyAt then
    d.obstructedAt=d.obstructedAt or now
    if now-d.obstructedAt>=2 then
     r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+6;release(d)
    end
   end
  end
 else
  -- Workers without a current stone regroup with the player. Plot orders may
  -- find another stone later; manual clicks are dispatched next simulation step.
  d.state='Follow';d.mining=false
  if d.autoField==field.id then d.state='Waiting';scene.waitAtPlot(d,p,field,nil,dt);return end
  if not d.autoField then local old=d.field;d.field=nil;dropFieldIfEmpty(p,old) end
  local hr=characterRoot(p)
  move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt)
 end
end
local function specialDrone(d: any,p: any,field: any,dt: number)
 if d.specialJob and d.specialJob.prismFired and now<d.prismReadyAt then
  d.state='SpecialMine';d.mining=false
  return
 end
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 if not field.junk and not d.target and d.autoField==field.id then chooseResource(d,field) end
 local r=d.target
 if not r or r.kind=='Geode' then mineDrone(d,p,field,dt);return end
 local definition=DroneCatalog.Types[d.role]
 local projectile=definition.Projectile
 if scene.awaitWorkStation(d,p,r,dt) then return end
 local goal=committedStation(d,r,dt);local yaw=d.yaw;d.state='Travel';d.mining=false;move(d,goal,dt)
 local job=d.specialJob
 if d.role=='Needler' and job and job.impacted and now+1e-6>=job.startedAt+job.duration then
  d.nextNeedleAt=job.startedAt+job.duration;d.specialJob=nil;job=nil
 end
 local arrived=Feel.canMine((d.pos-goal).Magnitude,now>=r.readyAt,true,d.hp>0)
 -- A gun must earn its original firing station before it can launch. Once
 -- the shot is in flight, the hull is free to recoil within a bounded area.
 if job and job.launched and (d.pos-goal).Magnitude<=3 then arrived=true end
 if d.role=='Needler' and d.warmAt and (job or d.nextNeedleAt)
  and now>=r.readyAt and (d.pos-goal).Magnitude<=2.5 then arrived=true end
 if projectile and not RoleConfig.DownwardGunDepth[d.role] and arrived then
  d.yaw=Feel.approachYaw(yaw,d.workYaw or Feel.levelYaw(d.pos,r.position,yaw),dt*((RoleConfig.Prominent[d.role] or {}).turn or 1))
 end
 local warmup=scene.miningWarmup(d,r)+(projectile and not d.workShotStarted and ((d.slot*7)%11)*(r.field.cfg.ContinuousCrystals and .006 or .012) or 0)
 local starting=not job and d.warmAt and now-d.warmAt>=warmup
 local contacting=job and not job.impacted and now>=job.startedAt+job.duration*job.impact
 if arrived and (d.specialClear==nil or now>=(d.specialQueryAt or 0) or starting or contacting) then
  -- Monitor obstruction at snapshot cadence, with fresh checks at startup
  -- and the actual contact. Cosmetic recovery never adds damage.
  if projectile=='Prism' then
   d.specialClear=scene.prismTrace(d,r,d.pos,true)~=nil
  else d.specialClear=los(job and job.launched and job.from or d.pos,job and job.launched and job.contact or r.position,r.part,{droneFolder}) end
  d.specialQueryAt=now+C.Snapshot
 end
 if not arrived or not d.specialClear then
  if (d.pos-goal).Magnitude<=1 and now>=r.readyAt then
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+3;release(d)
  elseif d.specialJob then release(d) else d.warmAt=nil end;return
 end
 d.warmAt=d.warmAt or now;d.state='Warmup'
 if now-d.warmAt<warmup then return end
 if not d.specialJob then
  if projectile=='Prism' and now<(d.prismReadyAt or 0) or projectile=='Nomad' and now<(d.nomadReadyAt or 0) then return end
  if not projectile then
   local active=drones[r.part:GetAttribute('EffectDrone')]
   if active and active~=d and active.target==r and active.specialJob then return end
  end
  d.workShotStarted=true
  local cycle=DroneCatalog.cycle(d.role,d.owned.base.miningDPS,d.stats.miningDPS)
  if not cycle then return end
  r.specialSerial=(r.specialSerial or 0)+1
  local started=d.role=='Needler' and math.clamp(d.nextNeedleAt or now,now-C.Tick,now) or now
  d.specialJob={targetId=r.id,serial=r.specialSerial,startedAt=started,duration=cycle.duration,impact=cycle.impact,damage=cycle.damage,impacted=false}
  if projectile then
   local vector=r.part.Position-d.pos
   local from=projectile=='Nomad' and (CFrame.new(goal)*CFrame.Angles(0,d.workYaw,0)):PointToWorldSpace(RoleConfig.NomadDropOffset) or d.pos+vector.Unit*.9
   local depth=RoleConfig.DownwardGunDepth[d.role]
   if depth then from=d.pos-Vector3.yAxis*(depth*d.model:GetScale()) end
   local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={r.part}
   local target=r.part.Position
   local contact=workspace:Raycast(from,target-from,query)
   local aim=contact and contact.Position or target
   if depth and not los(from,aim,r.part,{droneFolder}) then
    release(d);r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+3;return
   end
   if projectile=='Prism' then
    local path=scene.prismTrace(d,r,d.pos,true)
    if path then from=path.origin;aim=path.selected.point end
   end
   -- Keep Ramiel's filmed beats on their original clock. Mining rate can
   -- shorten downtime but cannot speed up the transformation.
   local windup=(projectile=='Prism' or projectile=='Nomad') and definition.Windup or math.min(definition.Windup,cycle.duration*.38)
   local flight=definition.Flight
   local visualRecovery=definition.BeamHold and definition.BeamHold+RoleConfig.RamielCloseTime
   local recovery=visualRecovery and visualRecovery+.075 or definition.Recovery or .10
   d.specialJob.duration=math.max(cycle.duration,windup+flight+recovery);d.specialJob.impact=(windup+flight)/d.specialJob.duration
   d.specialJob.from=from;d.specialJob.contact=aim;d.specialJob.windup=windup
   local ground=projectile=='Nomad' and (r.part:GetAttribute('GroundY') or r.position.Y-r.part.Size.Y*.5) or nil
   d.specialJob.projectile=RoleEffects.Projectile(projectile,from,aim,RoleConfig.Types[d.role].Color,started,windup,flight,d.id,r.id,r.part.CFrame:PointToObjectSpace(aim)/r.part.Size,definition.BeamHold,visualRecovery,ground)
  else
   for key,value in pairs({EffectType=d.role,EffectStartedAt=now,EffectDuration=cycle.duration,EffectImpact=cycle.impact,EffectDoneAt=0,EffectDepleted=false,EffectOwner=d.owner,EffectDrone=d.id,EffectPausedAt=0}) do r.part:SetAttribute(key,value) end
   r.part:SetAttribute('EffectSerial',r.specialSerial)
  end
 end
 d.state='SpecialMine'
 job=d.specialJob
 if (d.role=='Needler' or d.role=='Ballcaster') and job.windup and not job.launched and now>=job.startedAt+job.windup then
  job.launched=true
  local impulse=Feel.gunImpulse(d.role,job.from,job.contact,d.flightMass)
  d.velocity+=impulse
  d.model:SetAttribute('FlightImpulse',impulse)
  d.model:SetAttribute('FlightImpulseAt',now)
 end
 if not job.impacted and now>=job.startedAt+job.duration*job.impact then
  local accepted
  if projectile=='Prism' then accepted=scene.firePrism(d,r,job)
  elseif projectile=='Nomad' then accepted=scene.fireNomad(d,r,job)
  else accepted=hitResource(d,r,job.damage,false,nil,nil,'Special') end
  if not accepted then
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+3;release(d);return
  end
 end
 -- Keep the same reservation during recovery. A new serial can begin only
 -- after the current complete gesture; no extra warmup or overlapping hits.
 if d.role~='Needler' and d.specialJob==job and job.impacted and now>=job.startedAt+job.duration then
  d.specialJob=nil
  if d.squareJob~=p.miningSquare then d.warmAt=nil end
 end
end
local roleAbilityStep
local function followRole(d,p,hr,dt,state)
 if scene.holdSquare(d,p,dt) then return end
 d.mining=false;d.state=state or 'Follow'
 move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt)
end
local function roleNodes(p,field,worker)
 local list={}
 for _,r in ipairs(field.resources) do
  local eligible=not worker or ((not r.blockedUntil or now>=(r.blockedUntil[worker.id] or 0)) and sameRockType(worker,r));local count=0
  for id in pairs(r.slots) do count+=1;local worker=drones[id];if not worker or worker.owner~=p.player.UserId then eligible=false end end
  if r.part.Parent then table.insert(list,{id=r.id,hp=r.hp,maxHP=r.maxHP,kind=r.kind,x=r.position.X,y=r.position.Y,z=r.position.Z,readyAt=r.readyAt,paid=r.paid,eligible=eligible and count<r.limit}) end
 end
 return list
end
local function workingField(p,hr)
 local field=p.workField and scene.patchById[p.workField]
 if field and not activeAssault(p) and playerCanMine(p,field) and nearMiningField(hr.Position,field) then return field end
 return nil
end
local function growerDrone(d,p,hr,dt)
 d.mining=false
 local square=p.miningSquare
 local field=square and square.field or workingField(p,hr)
 if d.growSquare~=square then d.growSquare=square;d.growPlan=nil;d.growAt=nil end
 local vacancy=field and field.respawnQueue[1]
 if not vacancy or vacancy.landmark or now<(vacancy.regrowAt or 0) or nodeUsage(field)>=field.cfg.Count then
  d.growPlan=nil;d.growAt=nil;d.field=nil;followRole(d,p,hr,dt);return
 end
 d.field=field.id
 if now<(d.nextGrow or 0) then
  if square then followRole(d,p,hr,dt);return end
  d.state='GrowRecover';move(d,d.growRecoveryGoal or d.pos,dt);return
 end
 if not d.growPlan or d.growPlan.field~=field.id then
  d.growAt=nil
  local ok,_,plan=spawnResource(field,'Crystal',true,nil,square)
  if not ok then d.nextGrow=now+1;followRole(d,p,hr,dt);return end
  d.growPlan=plan
 end
 local spot=d.growPlan.spot
 local ground=Vector3.new(spot.X,field.part.Position.Y+field.part.Size.Y*.5,spot.Z)
 local goal=ground+Vector3.new(0,3.2,0)
 d.state='GrowApproach';move(d,goal,dt)
 if (d.pos-goal).Magnitude>.8 then d.growAt=nil;return end
 if not los(d.pos,ground,field.part,{droneFolder}) then d.growPlan=nil;d.growAt=nil;d.nextGrow=now+1;return end
 d.state='Plant'
 if not d.growAt then d.growAt=now;RoleEffects.Grow(d.pos,ground,false) end
 if now-d.growAt<DroneRoles.GROWER.plantSeconds then return end
 -- Commit one real replacement token, rechecking population and placement.
 -- Multiple growers cannot grow on top of each other or inflate field rewards.
 local ok,_,resource=spawnResource(field,'Crystal',false,d.growPlan,square)
 if ok then
  table.remove(field.respawnQueue,1)
  resource.part:SetAttribute('GrownBy',d.id)
  RoleEffects.Grow(d.pos,ground,true)
 end
 local cooldown=d.stats.growCooldown or DroneRoles.GROWER.cooldown
 if Workshop.starLevel(data(p),'cultivator')>0 then cooldown=math.min(cooldown,3) end
 d.growRecoveryGoal=goal;d.growPlan=nil;d.growAt=nil;d.nextGrow=now+(ok and cooldown or 1)
end
local function publishBreakerPhase(d,job)
 -- Publish the full transition before its world contact effects. In particular,
 -- observers must receive the powered stroke instead of holding an old windup
 -- until the next 10 Hz snapshot. SnapshotAt is the final coherence marker.
 local model=d.model
 model:PivotTo(CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0));d.publishedAttributes=nil;d.publishedPose=nil
 model:SetAttribute('Position',d.pos);model:SetAttribute('Goal',d.goal);model:SetAttribute('Velocity',d.velocity or Vector3.zero)
 model:SetAttribute('BreakerDiveStart',job.diveStart or d.pos);model:SetAttribute('BreakerImpact',job.impact)
 model:SetAttribute('BreakerPhaseAt',job.phaseAt);model:SetAttribute('BreakerDiveDuration',DroneRoles.BREAKER.diveDuration)
 model:SetAttribute('BreakerContactSerial',d.contactSerial or 0);model:SetAttribute('BreakerContactAt',d.contactAt or 0)
 model:SetAttribute('ImpactSerial',d.impactSerial or 0);model:SetAttribute('ImpactAt',d.impactAt or 0)
 model:SetAttribute('State',d.state);model:SetAttribute('SnapshotAt',now)
end
local function breakerSurface(r)
 local ground=r.part:GetAttribute('GroundY') or r.position.Y-r.fullSize.Y*.5
 local _,top=Feel.groundedRockFrame(r.position,r.part.Size,ground,r.stage,r.stageSeed,r.part:GetAttribute('CubicRock')==false,r.referenceCrystal,r.steady,r.variedPose)
 local contact=Vector3.new(r.position.X,top,r.position.Z)
 local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={r.part}
 local origin=contact+Vector3.new(0,2,0)
 local hit=workspace:Raycast(origin,Vector3.new(0,-r.part.Size.Magnitude-3,0),query)
 if hit then contact=hit.Position end
 if (r.smashDents or 0)>0 then
  -- The center of the same nested ellipsoid rendered by RockDamage. The
  -- authority keeps its original query collider; contact intent follows the
  -- earned bowl floor so later strokes do not hover above an existing dent.
  local dent=r.part.CFrame:PointToWorldSpace(Vector3.new(.025,.31-.05*math.min(6,r.smashDents)-.09*(r.smashPressure or 0),.015)*r.part.Size)
  contact=Vector3.new(contact.X,math.max(ground+.08,math.min(contact.Y,dent.Y)),contact.Z)
 end
 return contact
end
local function breakerDrone(d,p,hr,field,dt)
 d.mining=false
 local job=d.breaker
 -- Recovery survives destruction of this stone, but never a recall/death.
 if job and job.phase=='Recover' then
  local phase,event=DroneRoles.stepBreaker(job,now,{valid=true,recovered=(d.pos-job.station).Magnitude<=.7 and (d.velocity or Vector3.zero).Magnitude<=1})
  d.state='BreakerRecover';move(d,job.station,dt)
  if event=='recover' then RoleEffects.BreakerPhase(d.pos,job.contact,'Recover') end
  if phase=='Complete' then d.breaker=nil end
  return
 end
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 -- Owning a breaker earns autonomous heavy-rock work after the owner chooses
 -- a rock. The ordinary miner still needs the earned Rock Scanner.
 if not field.junk and not field.cfg.SelectionOnly and not d.target and (p.workField==field.id or d.deployedCarrier) then
  local node=DroneRoles.chooseTarget('Charger',roleNodes(p,field,d),{x=d.pos.X,y=d.pos.Y,z=d.pos.Z},now)
  local r=node and resources[node.id]
  if r then
   local occupied={};for _,slot in pairs(r.slots) do occupied[slot]=true end
   local slot=1;while occupied[slot] do slot+=1 end
   r.slots[d.id]=slot;d.target=r;d.targetSlot=slot;updateSlots(r)
  end
 end
 local r=d.target
 if not r then
  if d.autoField==field.id then d.state='Waiting';scene.waitAtPlot(d,p,field,nil,dt)
  else followRole(d,p,hr,dt) end
  return
 end
 job=d.breaker
 if not job then
  local station=committedStation(d,r,dt)+Vector3.new(0,2,0)
  if not abilityLineOfSight(p,station,r) then
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+6;release(d);return
  end
  job=DroneRoles.newBreaker(r.id,now);d.breaker=job
  job.windup=math.max(.08,d.stats.warmup)
  job.station=station
  job.contact=breakerSurface(r);job.contactStage=r.stage;job.contactDents=r.smashDents;job.contactPressure=r.smashPressure
  local lowest=0;local pivot=d.model:GetPivot()
  for _,part in ipairs(d.model:GetDescendants()) do if part:IsA('BasePart') and part.Transparency<1 then
   local cf=part.CFrame;local half=part.Size*.5
   for _,x in ipairs({-half.X,half.X}) do for _,y in ipairs({-half.Y,half.Y}) do for _,z in ipairs({-half.Z,half.Z}) do
    lowest=math.min(lowest,pivot:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(x,y,z))).Y)
   end end end
  end end
  job.impactClearance=math.max(.45,-lowest+.12)
  job.impact=job.contact+Vector3.new(0,job.impactClearance,0)
 end
 -- A teammate may chip the shared crystal while this weight descends or
 -- rests on it. Follow the real current surface instead of hovering over its
 -- previous size or letting the body penetrate a newly rotated fragment.
 if job.contactStage~=r.stage or job.contactDents~=r.smashDents or job.contactPressure~=r.smashPressure then
  job.contact=breakerSurface(r);job.contactStage=r.stage;job.contactDents=r.smashDents;job.contactPressure=r.smashPressure
 end
 job.impact=job.contact+Vector3.new(0,job.impactClearance,0)
 local phase=job.phase;local pose=DroneRoles.breakerPose(job,now)
 local goal=job.station+Vector3.new(0,pose.lift,0)
 if phase=='Dive' then goal=job.impact elseif phase=='Impact' then goal=job.impact end
 d.state=phase=='Approach' and 'Travel' or 'Breaker'..phase
 if phase=='Dive' and job.diveStart then
  d.goal=job.impact;d.intentGoal=job.impact;d.pos,d.velocity=Feel.powerDive(job.diveStart,job.impact,now-job.phaseAt,DroneRoles.BREAKER.diveDuration)
 elseif phase=='Impact' then
  d.pos=job.impact;d.goal=job.impact;d.intentGoal=job.impact;d.velocity=Vector3.zero
 else move(d,goal,dt) end
 local event
 phase,event=DroneRoles.stepBreaker(job,now,{valid=not r.paid and now>=r.readyAt and r.slots[d.id]~=nil,targetId=r.id,arrived=(d.pos-job.station).Magnitude<=.7,impactReached=now-job.phaseAt>=DroneRoles.BREAKER.diveDuration and (d.pos-job.impact).Magnitude<=.15})
 if phase~='Approach' then d.state='Breaker'..phase end
 if event=='windup' then publishBreakerPhase(d,job);RoleEffects.BreakerPhase(d.pos,job.contact,'Windup',r.part.Size.X)
 elseif event=='dive' then job.diveStart=d.pos;publishBreakerPhase(d,job);RoleEffects.BreakerPhase(d.pos,job.contact,'Dive',r.part.Size.X)
 elseif event=='contact' then
  d.velocity=Vector3.zero;d.pos=job.impact;d.goal=job.impact;d.intentGoal=job.impact
  d.contactSerial=(d.contactSerial or 0)+1;d.contactAt=now;publishBreakerPhase(d,job)
  RoleEffects.BreakerPhase(d.pos,job.contact,'Hold',r.part.Size.X)
 elseif event=='impact' then
  d.velocity=Vector3.zero
  -- Hold the physical weight on the surface before this single delayed fracture.
  -- The longer weight hold earns a larger hit, retaining its pre-hold work
  -- rate while the shell/perk multipliers continue to define the specialist.
  local diameter=r.part.Size.X
  if hitResource(d,r,d.stats.miningDPS*3.2,false,nil,d.pos,'Breaker') then
   d.impactSerial=(d.impactSerial or 0)+1;d.impactAt=now
   d.goal=job.station;d.intentGoal=job.station;publishBreakerPhase(d,job)
   RoleEffects.BreakerPhase(d.pos,job.contact,'Impact',diameter,r.part:GetAttribute('GroundY'))
  else
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+6
   release(d)
  end
  d.breaker=job
 elseif event=='missed' or event=='canceled' then release(d) end
end
function scene.autoSellReady(p,profile,units)
 -- Square fields cash a full bag out where the player stands: no sell trip.
 -- The real bag size (not the Studio test perk) sets the rhythm.
 if scene.flatFields then return units>0 and units>=Ca.capacity(profile) and not activeAssault(p) end
 return Workshop.starLevel(profile,'autosell')>0 and units>=Ca.capacity(profile,previewPerks(p)) and not activeAssault(p)
end
function scene.emptierOffset(rank)
 return Vector3.new(rank%2==0 and 2.2 or -2.2,2.4,1)
end
function scene.emptierReady(d,profile)
 if not scene.runStart then return Pro.cargoUnits(profile)>0 end
 return Pro.droneCargoUnits(profile,d.id)>0
end
function scene.emptierCanCollect(p,drop,id,hr)
 if not drop or drop.owner~=p.player.UserId or drop.runId~=data(p).run.id
  or drop.playerPickup or not drop.raw or not Workshop.crystalCargo(drop.material) or not OreDrops.collectible(drop)
  or drop.homing or drop.pressCarrier or not drop.part.Parent
  or scene.oreExpired(drop,now) then return false end
 local position=Vector3.new(drop.x,drop.y,drop.z)
 -- Once the downward scan begins the courier owns this one stroke, even
 -- when the player places a new square before the claw closes.
 if drop.courier and drop.courier.orePickupId==id and drop.courier.oreDock and drop.courier.hp>0 then return true end
 if scene.pressPairingWindow(p,drop,position) then return false end
 local square=p.miningSquare
 return (square and drop.fieldPart==square.field.part and scene.cargoInSquare(square,position))
  or (hr.Position-position).Magnitude<=28
end
function scene.assignEmptierPickups(p)
 if not healthy(p) or now<(p.nextEmptierPlan or 0) then return end
 p.nextEmptierPlan=now+.20
 local hr=characterRoot(p)
 if not hr then return end
 local profile=data(p)
 local reserved,available={},{}
 local capacity=Workshop.emptierBatch(profile)
 for _,d in ipairs(p.drones) do
  if d.role~='Courier' then continue end
  if d.hp<=0 or d.carrierId or profile.run.deliveries[d.id]
   or d.oreSeatUntil or not d.oreDock and now<(d.thinkUntil or 0) or now<(d.collectAfter or 0) or scene.emptierReady(d,profile) then
   d.orePickupId=nil
   continue
  end
  local id=d.orePickupId
  if id and not reserved[id] and scene.emptierCanCollect(p,pickups[id],id,hr) then
   reserved[id]=true
  else
   d.orePickupId=nil
   table.insert(available,d)
  end
 end
 for _,d in ipairs(available) do
  local best,bestSize,bestDistance
  local space=capacity-Pro.droneCargoUnits(profile,d.id)
  for id,drop in pairs(pickups) do
   if reserved[id] or drop.units>space or not scene.emptierCanCollect(p,drop,id,hr)
    or (d.oreBlockedId==id and now<(d.pickupRetryAt or 0)) then continue end
   local position=Vector3.new(drop.x,drop.y,drop.z)
   local size=Mining.sizeTier(drop.modifiers)
   local distance=(d.pos-position).Magnitude
   if not best or size<bestSize or size==bestSize and (distance<bestDistance or distance==bestDistance and id<best) then
    best,bestSize,bestDistance=id,size,distance
   end
  end
  if best then d.orePickupId=best;d.pickupAt=nil;d.oreDock=nil;d.oreYaw=nil;reserved[best]=true;pickups[best].courier=d end
 end
end
function scene.courierDeliveryGoal(d,p)
 local depot=scene.converter or scene.packStation
 local destination=scene.runStart and scene.packStation.Position or (logistics and logistics:storagePosition(p) or depot.Position)
 local offset=Feel.formation(d.slot,#p.drones)
 if offset.Magnitude>6 then offset=offset.Unit*6 end
 return destination+offset+Vector3.yAxis*d.flightHeight
end
function scene.flyCourierPickup(d,dt,at)
 d.pos,d.velocity=Workshop.courierSwoop(d.oreDock,d.oreYaw,d.oreEntryOffset,d.oreEntryVelocity,
  (at or now)-d.pickupAt,d.oreApproachTime,d.oreReturnTurn)
 d.yaw=Feel.approachYaw(d.yaw,Feel.flightYaw(d.pos,d.pos,d.velocity,d.yaw),dt)
 d.goal=d.oreReturnGoal;d.intentGoal=d.goal
end
function scene.collectGroundCargo(d,p,hr,dt)
 local profile=data(p)
 d.deliveryRequested=now>=(d.oreSeatUntil or 0) and scene.emptierReady(d,profile)
 local id=d.orePickupId
 local drop=id and pickups[id]
 if d.oreSeatUntil then
  if now<d.oreSeatUntil then
   scene.flyCourierPickup(d,dt);d.state='Pickup';return true
  end
  -- Hand the solver the exact exit position and tangent. Integrate only the
  -- part of this tick after the exit so no time is spent twice at the seam.
  local remaining=math.clamp(now-d.oreSeatUntil,0,dt)
  scene.flyCourierPickup(d,dt-remaining,d.oreSeatUntil)
  dt=remaining
  d.oreSeatUntil=nil;d.oreDock=nil;d.oreYaw=nil;d.pickupAt=nil
 end
 if d.deliveryRequested then
  -- Keep the climb's momentum while the server seals the sale manifest.
  d.state='Deliver';move(d,scene.courierDeliveryGoal(d,p),dt);return true
 end
 if not id or not scene.emptierCanCollect(p,drop,id,hr) then
  d.orePickupId=nil;d.pickupAt=nil;d.oreDock=nil;d.oreYaw=nil
  return false
 end
 local position=Vector3.new(drop.x,drop.y,drop.z)
 local claw=Pro.droneCargoUnits(profile,d.id)+1
 local x,y,z,gripYaw=Workshop.courierClawOffset(claw)
 local yaw=d.oreYaw
 if not yaw then
  local delta=position-d.pos
  if delta.X^2+delta.Z^2>1 then yaw=Feel.levelYaw(d.pos,position,d.yaw)
  else yaw=Feel.levelYaw(position,scene.packStation.Position,d.yaw) end
 end
 local gem=Vector3.new(position.X,drop.floor-.22+drop.part.Size.Y*.5,position.Z)
 local hookOffset=CFrame.Angles(0,yaw,0):PointToWorldSpace(Vector3.new(x,-Workshop.COURIER_HOOK_DROP,z))
 local dock=d.oreDock or gem-hookOffset
 if not d.oreDock then
  local ignore={pickupFolder,droneFolder,hr.Parent}
  local entryVelocity=d.velocity or Vector3.zero
  local offset=d.pos-dock
  local approachTime=Workshop.courierApproachTime(offset)
  local deliveryGoal=scene.courierDeliveryGoal(d,p)
  local turn=Workshop.courierReturnTurn(dock,yaw,deliveryGoal)
  local duration=approachTime+Workshop.courierReturnDuration(turn)
  local previous=d.pos
  local samples=math.clamp(math.ceil(duration*5),6,40)
  for i=1,samples do
   local nextPosition=Workshop.courierSwoop(dock,yaw,offset,entryVelocity,duration*i/samples,approachTime,turn)
   if not los(previous,nextPosition,d.model,ignore,true,true) then
    d.oreBlockedId=id;d.pickupRetryAt=now+1.25;d.orePickupId=nil;d.oreYaw=nil;p.nextEmptierPlan=nil
    return false
   end
   previous=nextPosition
  end
  if not los(dock,gem,d.model,ignore,true,true) then
   d.oreBlockedId=id;d.pickupRetryAt=now+1.25;d.orePickupId=nil;d.oreYaw=nil;p.nextEmptierPlan=nil
   return false
  end
  d.oreDock=dock;d.oreYaw=yaw;d.oreEntryOffset=offset;d.oreEntryVelocity=entryVelocity
  d.oreApproachTime=approachTime;d.oreReturnTurn=turn;d.oreReturnGoal=deliveryGoal;d.pickupAt=now;d.oreHookPoint=gem
  d.lastMoveFormation=false;d.descentOrigin=nil
  drop.part:SetAttribute('CourierDocking',d.id)
  drop.part:SetAttribute('CourierDockYaw',yaw+gripYaw)
 end
 local age=now-d.pickupAt
 d.state='Pickup'
 scene.flyCourierPickup(d,dt)
 if age<d.oreApproachTime then return true end
 local clawCenter=dock+hookOffset
 if (clawCenter-gem).Magnitude>.8 or not los(dock,gem,d.model,{pickupFolder,droneFolder,hr.Parent},true,true) then
  d.oreBlockedId=id;d.pickupRetryAt=now+1.25;d.orePickupId=nil;d.oreDock=nil;d.oreYaw=nil;d.pickupAt=nil
  p.nextEmptierPlan=nil;return false
 end
 if Pro.loadGroundCargo(profile,d.id,drop.material,drop.units,Workshop.emptierBatch(profile)) then
  d.oreSeatUntil=d.pickupAt+d.oreApproachTime+Workshop.courierReturnDuration(d.oreReturnTurn)
  d.oreLoadedId=id;d.oreLoadedMaterial=drop.material;d.oreLoadedVisualAt=now
  d.deliveryRequested=false
  drop.part:SetAttribute('Units',0)
  drop.part:SetAttribute('CourierCollected',true)
  drop.part:SetAttribute('CourierDroneId',d.id)
  drop.part:SetAttribute('CollectedPosition',Vector3.new(position.X,drop.floor-.22+drop.part.Size.Y*.5,position.Z))
  drop.part:SetAttribute('CollectedAt',now)
  drop.part.Transparency=1;Debris:AddItem(drop.part,.35);pickups[id]=nil
  p.dirty=true;p.publishDirty=true
 end
 if not d.oreSeatUntil then d.pickupAt=nil;d.oreDock=nil;d.oreYaw=nil end
 d.orePickupId=nil;p.nextEmptierPlan=nil
 return true
end
-- Dig Cube: one huge block of Voronoi cells on the plain east of the hub.
-- Walk up to it (or onto it) and the crew digs craters around you; tap a cell
-- to move the crater there. Stone cells just break; ore cells drop a gem.
-- Geometry is built from the seed on every client; only removed cells replicate.
do
local DigCube=Config.DigCube
local OPS_PER_ATTRIBUTE=64
do
 local W=DigCube.WIDTH
 local origin=Vector3.new(DigCube.CENTER[1]-W*.5,DigCube.CENTER[2],DigCube.CENTER[3]-W*.5)
 local override=root:GetAttribute('DigCubeOrigin')
 if typeof(override)=='Vector3' then origin=override end
 local holder=root:FindFirstChild('DigCube') or Instance.new('Folder')
 holder.Name='DigCube';holder.Parent=root
 local template=Instance.new('Part');template.Name='DigGem';template.Size=Vector3.new(1,1,1)
 scene.dig={origin=origin,holder=holder,template=template,generation=0,recent={},random=Random.new(),
  dirty=false,publishAt=0,resetAt=nil,checkAt=0,claimed={},ops={},published=0,pending={},csg={},blocks={},dust={},dustAt=0,geodes={}}
 -- Collision groups for the clients' loose rubble: it lands on an invisible
 -- floor at the bottom of each hole and touches nothing else (players, the
 -- rock still being carved).
 pcall(function()
  local physics=game:GetService('PhysicsService')
  for _,name in ipairs({'DigRubble','DigRubbleFloor'}) do
   if not physics:IsCollisionGroupRegistered(name) then physics:RegisterCollisionGroup(name) end
  end
  physics:CollisionGroupSetCollidable('DigRubble','Default',false)
  physics:CollisionGroupSetCollidable('DigRubbleFloor','Default',false)
  physics:CollisionGroupSetCollidable('DigRubble','DigRubbleFloor',true)
  physics:CollisionGroupSetCollidable('DigRubble','DigRubble',true)
 end)
 local dustFolder=holder:FindFirstChild('Dust') or Instance.new('Folder')
 dustFolder.Name='Dust';dustFolder.Parent=holder
 scene.dig.dustFolder=dustFolder
end
function scene.digReset()
 local dig=scene.dig
 dig.generation+=1
 local seedValue=dig.random:NextInteger(1,2000000000)
 dig.cube=DigCube.build(seedValue);dig.recent={};dig.claimed={};dig.pending={};dig.resetAt=nil;dig.dirty=false;dig.csg={};dig.deepest=1
 dig.geodes={};dig.holder:SetAttribute('Geodes','')
 for _,dust in ipairs(dig.dust) do dust.part:Destroy() end
 dig.dust={}
 for _,d in pairs(drones) do d.digJob=nil;d.digCell=nil;d.digWarm=nil end
 local holder=dig.holder
 for i=1,math.ceil(#dig.ops/OPS_PER_ATTRIBUTE) do holder:SetAttribute('Ops'..i,nil) end
 dig.ops={};dig.published=0
 holder:SetAttribute('OpCount',0)
 holder:SetAttribute('Origin',dig.origin);holder:SetAttribute('Width',DigCube.WIDTH);holder:SetAttribute('Height',dig.cube.height)
 holder:SetAttribute('Seed',seedValue);holder:SetAttribute('Generation',dig.generation)
 scene.digBuildRock()
 for _,p in pairs(profiles) do
  local hr=characterRoot(p)
  if hr and scene.digInside(hr.Position,0) then hr.CFrame=CFrame.new(hr.Position.X,dig.origin.Y+dig.cube.height+4,hr.Position.Z) end
 end
end
-- The rock players see and walk on is real solid geometry on the server: one
-- block per layer per 11-stud tile, colored by depth. Each chunk that breaks
-- is subtracted from the blocks it reaches (its cells' prisms, Roblox CSG),
-- in order, and the result replicates to every player.
function scene.digBuildRock()
 local dig=scene.dig;local cube=dig.cube
 if dig.rock then dig.rock:Destroy() end
 local rock=Instance.new('Model');rock.Name='Rock'
 dig.blocks={}
 local T=DigCube.TILE;local n=math.ceil(cube.width/T)
 for _,layer in ipairs(cube.layers) do
  local y0,y1=layer.y0,layer.y1
  for gx=0,n-1 do
   for gz=0,n-1 do
    local x0,x1=gx*T,math.min(cube.width,(gx+1)*T)
    local z0,z1=gz*T,math.min(cube.width,(gz+1)*T)
    local c=DigCube.layerColor(cube,layer.index,(x0+x1)*.5,(z0+z1)*.5)
    local part=Instance.new('Part');part.Name='RockBlock'
    -- No cast shadows: the low morning sun would fill every pit with shadow.
    part.Anchored=true;part.CanTouch=false;part.CastShadow=false
    part.Material=Enum.Material.SmoothPlastic;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
    part.Color=Color3.fromRGB(c[1],c[2],c[3])
    part.Size=Vector3.new(x1-x0,y1-y0,z1-z0)
    part.CFrame=CFrame.new(dig.origin+Vector3.new((x0+x1)*.5,(y0+y1)*.5,(z0+z1)*.5))
    part.Parent=rock
    table.insert(dig.blocks,{part=part,lo=Vector3.new(x0,y0,z0),hi=Vector3.new(x1,y1,z1)})
   end
  end
 end
 rock.Parent=dig.holder;dig.rock=rock
end
-- Subtract broken cells from the blocks they reach. A job may hold the cells
-- of several chunks (everything queued while the last carve ran), and each
-- block is cut once with only the cells that touch it.
function scene.digCarve(job)
 local dig=scene.dig;local cube=dig.cube;local o=dig.origin
 if job.generation~=dig.generation then return end
 local made,wedges={},{}
 local function wedgesFor(id)
  local list=wedges[id]
  if list then return list end
  list={}
  for _,w in ipairs(DigCube.prismWedges(cube,{id})) do
   local p=Instance.new('WedgePart');p.Anchored=true;p.CanCollide=false
   p.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
   p.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
   table.insert(list,p);table.insert(made,p)
  end
  wedges[id]=list
  return list
 end
 -- Nested-stage shapes: wedges per part, with their bounds.
 local stageParts={}
 for _,part in ipairs(job.parts or {}) do
  local lo,hi=Vector3.new(math.huge,part.y0,math.huge),Vector3.new(-math.huge,part.y1,-math.huge)
  for _,v in ipairs(part.poly) do lo=Vector3.new(math.min(lo.X,v[1]),lo.Y,math.min(lo.Z,v[2]));hi=Vector3.new(math.max(hi.X,v[1]),hi.Y,math.max(hi.Z,v[2])) end
  local list={}
  for _,w in ipairs(DigCube.partWedges(cube,{part})) do
   local p=Instance.new('WedgePart');p.Anchored=true;p.CanCollide=false
   p.Size=Vector3.new(w.size[1],w.size[2],w.size[3])
   p.CFrame=CFrame.fromMatrix(o+Vector3.new(w.pos[1],w.pos[2],w.pos[3]),Vector3.new(w.right[1],w.right[2],w.right[3]),
    Vector3.new(w.up[1],w.up[2],w.up[3]),Vector3.new(w.back[1],w.back[2],w.back[3]))
   table.insert(list,p);table.insert(made,p)
  end
  table.insert(stageParts,{lo=lo,hi=hi,wedges=list})
 end
 for i=#dig.blocks,1,-1 do
  local block=dig.blocks[i]
  local negatives={}
  for _,sp in ipairs(stageParts) do
   if block.hi.X>sp.lo.X-.5 and block.lo.X<sp.hi.X+.5 and block.hi.Y>sp.lo.Y-.1 and block.lo.Y<sp.hi.Y+.6
    and block.hi.Z>sp.lo.Z-.5 and block.lo.Z<sp.hi.Z+.5 then
    for _,w in ipairs(sp.wedges) do table.insert(negatives,w) end
   end
  end
  for _,id in ipairs(job.ids) do
   local c=cube.cells[id]
   if block.hi.X>c.minX-.5 and block.lo.X<c.maxX+.5 and block.hi.Y>c.y0-.1 and block.lo.Y<c.y1+.6
    and block.hi.Z>c.minZ-.5 and block.lo.Z<c.maxZ+.5 then
    for _,w in ipairs(wedgesFor(id)) do table.insert(negatives,w) end
   end
  end
  if #negatives>0 then
   local ok,result=pcall(function()
    return block.part:SubtractAsync(negatives,Enum.CollisionFidelity.PreciseConvexDecomposition,Enum.RenderFidelity.Precise)
   end)
   if job.generation~=dig.generation then break end
   if ok and result then
    result.Anchored=true;result.CanTouch=false;result.CastShadow=false;result.UsePartColor=true;result.Color=block.part.Color
    result.Material=block.part.Material;result.Name='RockBlock'
    result.Parent=dig.rock
    block.part:Destroy();block.part=result
   elseif not ok and string.find(tostring(result),'empty') then
    block.part:Destroy();table.remove(dig.blocks,i)
   end
  end
 end
 for _,p in ipairs(made) do p:Destroy() end
end
-- Drain the carve queue in order; the worker starts when a chunk is queued.
function scene.digCarveLoop()
 local dig=scene.dig
 if dig.carving or #dig.csg==0 then return end
 dig.carving=true
 task.spawn(function()
  while #dig.csg>0 do
   -- Take everything queued for this cube in one pass: pieces break often,
   -- and one cut per block keeps the rock in step with the breaks.
   local job={generation=dig.csg[1].generation,ids={},parts={}}
   while #dig.csg>0 and dig.csg[1].generation==job.generation do
    local item=table.remove(dig.csg,1)
    for _,id in ipairs(item.ids) do table.insert(job.ids,id) end
    for _,part in ipairs(item.parts or {}) do table.insert(job.parts,part) end
   end
   local ok,err=pcall(scene.digCarve,job)
   if not ok and not dig.carveWarned then dig.carveWarned=true;(warn or print)('[DigCube] carve failed: '..tostring(err)) end
  end
  dig.carving=false
 end)
end
-- The rock surface below a point (the carved rock, or the ground).
function scene.digFloorAt(x,z,fromY)
 local dig=scene.dig
 local include={}
 if dig.rock then table.insert(include,dig.rock) end
 local base=workspace:FindFirstChild('Baseplate');if base then table.insert(include,base) end
 if #include==0 or not RaycastParams then return nil end
 local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances=include
 local hit=workspace:Raycast(Vector3.new(x,fromY,z),Vector3.new(0,-(fromY-dig.origin.Y+20),0),query)
 return hit and hit.Position.Y
end
function scene.digInside(position,margin)
 local dig=scene.dig;if not dig.cube then return false end
 local l=position-dig.origin
 return l.X>=-margin and l.X<=DigCube.WIDTH+margin and l.Z>=-margin and l.Z<=DigCube.WIDTH+margin and l.Y>=-2 and l.Y<=dig.cube.height+margin
end
-- On the cube, in a pit, or standing right next to it.
function scene.digActive(p)
 local dig=scene.dig;local hr=characterRoot(p)
 if not dig.cube or not hr then return false end
 local l=hr.Position-dig.origin
 return l.X>=-4 and l.X<=DigCube.WIDTH+4 and l.Z>=-4 and l.Z<=DigCube.WIDTH+4 and l.Y>=-3 and l.Y<=dig.cube.height+16
end
function scene.digRelease(p)
 for _,d in ipairs(p.drones) do
  scene.digDrop(d);d.digging=false
  if d.state=='Mine' or d.state=='Warmup' or d.state=='Travel' then d.state='Follow';d.mining=false end
 end
end
-- Forget a drone's chunk and its cell claims.
function scene.digDrop(d)
 local dig=scene.dig;local job=d.digJob
 if job then for _,id in ipairs(job.ids) do if dig.claimed[id]==d.id then dig.claimed[id]=nil end end end
 d.digJob=nil;d.digCell=nil;d.digWarm=nil;d.digProgress=nil;d.digWarmFor=nil
 if d.digging then d.warmAt=nil end
end
-- Pick a seed cell, then grow this drone's chunk around it right now: its
-- size comes from the drone (DigCube.chunkScale) times cut-size upgrades.
function scene.digPick(d,p)
 local dig=scene.dig;local cube=dig.cube
 local taken,points={},{}
 for id,droneId in pairs(dig.claimed) do
  local worker=drones[droneId]
  if worker and worker.hp>0 and worker.digJob then
   taken[id]=true
   if worker.digJob.left[1]==id then table.insert(points,{worker.digJob.cx,worker.digJob.cz}) end
  else dig.claimed[id]=nil end
 end
 -- Sealed gem cells wait for their owner; no drone cuts them.
 for id in pairs(dig.geodes or {}) do taken[id]=true end
 local hr=characterRoot(p)
 if not hr then return nil end
 -- Drones only cut near their player: a tapped spot steers the crater only
 -- when it is within reach, so walking is how you move the dig.
 local point=hr.Position
 local tapped=p.digFocus and now<(p.digFocusUntil or 0) and p.digFocus
 if tapped and Vector3.new(tapped.X-point.X,0,tapped.Z-point.Z).Magnitude<=DigCube.MINE_RADIUS then point=tapped end
 local random=function() return dig.random:NextNumber() end
 local opts={taken=taken,takenPoints=points,recent=dig.recent,now=now,random=random,
  anchorX=hr.Position.X-dig.origin.X,anchorZ=hr.Position.Z-dig.origin.Z}
 opts.focusX=math.clamp(point.X-dig.origin.X,0,DigCube.WIDTH);opts.focusZ=math.clamp(point.Z-dig.origin.Z,0,DigCube.WIDTH)
 local seed=DigCube.pick(cube,opts)
 if not seed then return nil end
 local scale=DigCube.chunkScale(d.role,d.id,d.slot)*(d.stats.cutSize or 1)
 local ids=DigCube.chunk(cube,seed,scale,taken,random)
 for _,id in ipairs(ids) do dig.claimed[id]=d.id end
 local _,cx,cz=DigCube.chunkArea(cube,ids)
 local hp=DigCube.chunkHp(cube,ids,scale)
 -- The chunk comes away in pieces from its middle outward; the beam works
 -- on the next piece to go.
 local job={ids=ids,left=table.clone(ids),key=DigCube.key(ids),cx=cx,cz=cz,hp=hp,maxHp=hp,
  pieces=DigCube.pieces(cube,ids),stage=0,rock=DigCube.rockDrops(DigCube.volume(cube,ids)),rockPaid=0}
 scene.digAim(job)
 return job
end
-- Point the beam at the chunk's center (DigCube.chunkCenter), where every
-- nested stage grows from: the rock surface there, below any stage already
-- carved out. The drone hovers straight above it.
function scene.digAim(job)
 local dig=scene.dig
 local cx,cz,id=DigCube.chunkCenter(dig.cube,job.ids)
 local c=dig.cube.cells[id]
 local carved=job.pieces and job.pieces[job.stage]
 local part=carved and carved.parts and carved.parts[1]
 local depth=part and (part.y1-part.y0) or 0
 job.contact=dig.origin+Vector3.new(cx,c.y1-depth,cz)
end
-- One piece of a chunk breaks off before the rest: it leaves the rock now
-- (ops flag P: no gem roll yet) and pays its share of the chunk's rock.
-- One nested stage of a chunk breaks out (a Voronoi cell around its middle,
-- shallower than the layer): it is carved now, the cells themselves stay
-- until the final break (ops flag S<stage>; every client recomputes the
-- shape from the chunk key) and it pays its share of the chunk's rock.
function scene.digChip(job,d,p)
 local dig=scene.dig;local cube=dig.cube
 job.stage+=1
 local piece=job.pieces[job.stage]
 table.insert(dig.ops,'c'..DigCube.key(job.ids)..'|0|S'..job.stage)
 dig.dirty=true
 table.insert(dig.csg,{generation=dig.generation,ids={},parts=piece.parts})
 scene.digCarveLoop()
 local share=math.floor(job.rock*piece.at)-job.rockPaid
 if share>0 then
  job.rockPaid+=share
  local _,px,pz=DigCube.chunkArea(cube,job.ids)
  local floor=piece.parts[1] and piece.parts[1].y0 or cube.cells[job.ids[1]].y0
  scene.digRock(p,d.owner,job.ids,share,dig.origin+Vector3.new(px,floor+1,pz))
 end
 scene.digAim(job)
end
function scene.digDrone(d,p,dt)
 local dig=scene.dig;local cube=dig.cube
 local hr=characterRoot(p)
 if not DroneRoles.isWorker(d.role) or d.hp<=0 then
  scene.digDrop(d);d.state='Follow';d.mining=false
  move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt);return
 end
 local job=d.digJob
 if job and (cube.removed[job.left[1]] or dig.claimed[job.left[1]]~=d.id) then scene.digDrop(d);job=nil end
 -- Walked away: let go of chunks left behind so the crew follows you.
 if job and hr then
  local lx,lz=hr.Position.X-dig.origin.X,hr.Position.Z-dig.origin.Z
  if math.sqrt((job.cx-lx)^2+(job.cz-lz)^2)>DigCube.MINE_RADIUS+8 then scene.digDrop(d);job=nil end
 end
 if not job and now>=(d.digPickAt or 0) then
  d.digPickAt=now+.2;d.digWarm=nil;d.digProgress=0
  job=scene.digPick(d,p)
  d.digJob=job;d.digCell=job and job.left[1] or nil
 end
 if not job then
  d.state='Follow';d.mining=false
  move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt);return
 end
 local top=job.contact
 -- Straight above the chunk's center, so the beam drops vertically onto it.
 local goal=top+Vector3.new(0,6.5,0)
 d.digPoint=top
 d.digging=true
 if (d.pos-goal).Magnitude>2.4 then d.state='Travel';d.mining=false;d.digWarm=nil;d.warmAt=nil;move(d,goal,dt);return end
 move(d,goal,dt)
 -- The field drones' charge-up: the published warmup start and length drive
 -- the same beam startup on every client.
 -- Long enough to see the charge (the owner asked for it back): about the
 -- drone's own warmup per chunk, longer for the first shot after a rest.
 if not d.digWarm then
  d.digWarm=now
  local rested=now-(d.lastBeamAt or -math.huge)>scene.FIRST_CHARGE_REST
  d.digWarmFor=rested and 1.3 or math.clamp(d.stats.warmup or .8,.7,1.1)
 end
 if not d.mining then d.warmAt=d.digWarm end
 if now-d.digWarm<d.digWarmFor then d.state='Warmup';d.mining=false;return end
 if not d.mining then d.beamSince=now end
 d.state='Mine';d.mining=true;d.lastBeamAt=now
 job.hp-=d.stats.miningDPS*dt
 d.digProgress=math.clamp(1-job.hp/job.maxHp,0,1)
 while job.hp>0 and job.stage<#job.pieces-1 and d.digProgress>=job.pieces[job.stage+1].at do scene.digChip(job,d,p) end
 if job.hp<=0 then scene.digBreak(job,d,p) end
end
-- The last piece of a chunk breaks (job.left; earlier pieces already left
-- the rock). The gem roll covers the whole chunk.
function scene.digBreak(job,d,p)
 local dig=scene.dig;local cube=dig.cube
 scene.digDrop(d);d.digPickAt=0;d.digProgress=0
 local last=job.left or job.ids
 -- The gamble: is there a gem in this chunk? (Rolled before anything leaves.)
 local tier=DigCube.gemRoll(cube,job.ids,function() return dig.random:NextNumber() end)
 local layer=cube.cells[job.ids[1]].layer
 -- Jackpots: a treasure pocket pays several rare gems; the first chunk into
 -- each new layer pays a guaranteed gem of that layer's tier.
 local treasure=DigCube.hasTreasure(cube,job.ids)
 local milestone=layer>(dig.deepest or 1)
 if milestone then dig.deepest=layer end
 local flag=''
 if treasure then
  tier=math.max(tier,3,math.min(#DigCube.ORES,DigCube.layerTier(layer)+1));flag='|T'
 elseif milestone then
  tier=math.max(tier,DigCube.layerTier(layer));flag='|D'..layer
 end
 -- A gem stays sealed in its cell (owner, Nov 22): that one cell is kept,
 -- cracked and glowing, until its owner jumps on it (scene.digGeodeStep).
 local sealed=nil
 if tier>0 then
  local cx,cz=DigCube.chunkCenter(cube,last)
  local best,score=nil,-math.huge
  for _,id in ipairs(last) do
   local c=cube.cells[id]
   -- Its ore cell if it has one; else the cell farthest from the middle,
   -- which the nested stages hollowed least.
   local value=(c.ore or 0)*1000+((c.cx-cx)^2+(c.cz-cz)^2)
   if not cube.removed[id] and value>score then best,score=id,value end
  end
  sealed=best
 end
 local broken={}
 for _,id in ipairs(last) do
  if id~=sealed then
   table.insert(broken,id)
   if DigCube.remove(cube,id) then dig.recent[id]=now end
  end
 end
 if #broken>0 then
  table.insert(dig.ops,'c'..DigCube.key(broken)..'|'..(sealed and 0 or tier)..(sealed and '' or flag))
  dig.dirty=true
  table.insert(dig.csg,{generation=dig.generation,ids=broken})
  scene.digCarveLoop()
 end
 scene.crewBreak(d.owner)
 local volume=DigCube.volume(cube,job.ids)
 local _,lx,lz=DigCube.chunkArea(cube,#broken>0 and broken or last)
 local _,floor=DigCube.contact(cube,#broken>0 and broken or last)
 local center=dig.origin+Vector3.new(lx,floor+1,lz)
 -- Rock comes out right away: bigger chunks drop more (less what the
 -- earlier pieces already paid).
 scene.digRock(p,d.owner,last,math.max(1,(job.rock or DigCube.rockDrops(volume))-(job.rockPaid or 0)),center)
 if sealed then
  dig.geodes[sealed]={id=sealed,tier=tier,treasure=treasure,owner=d.owner,p=p,volume=volume,at=now}
  -- A sealed cell may float: the crew can dig under it.
  cube.sealed=cube.sealed or {};cube.sealed[sealed]=true
  scene.digPublishGeodes()
 end
end
-- Sealed gem cells, replicated as "id:tier:owner;..." on the cube holder.
function scene.digPublishGeodes()
 local dig=scene.dig
 local list={}
 for id,g in pairs(dig.geodes) do table.insert(list,id..':'..g.tier..':'..g.owner..':'..(g.treasure and 1 or 0)) end
 table.sort(list)
 dig.holder:SetAttribute('Geodes',table.concat(list,';'))
end
-- Its owner landing on a sealed cell from a jump opens it: the cell breaks
-- (ops flag G, or X for a treasure pocket) and the gem flies out. The owner's
-- client sees its own landing first: it freezes the game that same frame
-- (the freeze is the pause) and asks with 'DigOpen'. The server's own check
-- below is the fallback. The gem launches GEODE_LAUNCH after the request,
-- about when the client's 12-frame freeze ends (it was sent a moment before).
local GEODE_LAUNCH=.12
local GEODE_LANDING=8 -- downward speed (studs/s) that counts as landing from a jump
function scene.digOpenGeode(id,g)
 local dig=scene.dig;local cube=dig.cube
 local c=cube.cells[id]
 dig.geodes[id]=nil
 if cube.sealed then cube.sealed[id]=nil end
 if DigCube.remove(cube,id) then dig.recent[id]=now end
 table.insert(dig.ops,'c'..id..'|'..g.tier..'|'..(g.treasure and 'X' or 'G'))
 dig.dirty=true
 table.insert(dig.csg,{generation=dig.generation,ids={id}})
 scene.digCarveLoop()
 local at=dig.origin+Vector3.new(c.cx,c.y1+.6,c.cz)
 for i=1,g.treasure and DigCube.TREASURE_GEMS or 1 do
  table.insert(dig.pending,{at=now+GEODE_LAUNCH+(i-1)*.15,p=g.p,owner=g.owner,tier=g.tier,volume=g.volume,position=at+Vector3.new(0,i*.3,0),high=true})
 end
 scene.digPublishGeodes()
end
-- Is this root over the sealed cell (on it, or in a stage hole cut in it)?
function scene.digOverGeode(hr,c,slack)
 local l=hr.Position-scene.dig.origin
 local above=l.Y-c.y1
 return math.sqrt((l.X-c.cx)^2+(l.Z-c.cz)^2)<=c.radius+1.2+slack and above>=1-(c.y1-c.y0)-slack and above<=5.5+slack
end
-- The owner's client asks to open a sealed cell it just landed on. Checked
-- loosely (latency): its owner, standing over it.
function scene.digRequestOpen(p,payload)
 local dig=scene.dig;local cube=dig.cube
 local id=type(payload)=='table' and tonumber(payload.id)
 local g=id and dig.geodes[id]
 local hr=characterRoot(p)
 if not g or g.p~=p or not hr or cube.removed[id] then return end
 if scene.digOverGeode(hr,cube.cells[id],3) then scene.digOpenGeode(id,g) end
end
function scene.digGeodeStep()
 local dig=scene.dig;local cube=dig.cube
 local changed=false
 for id,g in pairs(dig.geodes) do
  local p=profiles[g.owner]
  local hr=p and p==g.p and characterRoot(p)
  local c=cube.cells[id]
  if cube.removed[id] then dig.geodes[id]=nil;changed=true
  elseif hr and c then
   -- Landing on it from a jump (owner, Nov 22: you actually have to jump;
   -- walking or standing on it does nothing).
   local velocity=hr.AssemblyLinearVelocity
   local falling=velocity~=nil and velocity.Y<=-GEODE_LANDING
   if falling and scene.digOverGeode(hr,c,0) then scene.digOpenGeode(id,g) end
  end
 end
 if changed then scene.digPublishGeodes() end
end
-- Launch one cargo pickup in its arc and land it on the real rock surface.
function scene.digLaunch(p,owner,cargo,material,stone,rareGem,position,color,nodeId,high)
 local dig=scene.dig;local profile=data(p)
 local vx,vy,vz=OreDrops.cargoLaunch(pickupSerial+1,false)
 -- A gem out of a sealed cell flies much higher (owner, Nov 22).
 -- (Nov 22 follow-up: "much less tall" than the first x1.9+6.)
 if high then vx*=.8;vz*=.8;vy=vy*1.25+2 end
 local guess=position.Y-1
 -- The cube knows its own floor exactly; carving runs a moment behind, so a
 -- raycast would land drops on rock that is about to disappear (floating gems).
 local function floorAt(x,z)
  local top=DigCube.surfaceAt(dig.cube,x-dig.origin.X,z-dig.origin.Z)
  if top then return dig.origin.Y+top end
  return scene.digFloorAt(x,z,dig.origin.Y+dig.cube.height+6)
 end
 local arc=OreDrops.rawArc(position.X,position.Y,position.Z,vx,vy,vz,guess)
 local floor=floorAt(arc.landX,arc.landZ)
 if floor then
  arc=OreDrops.rawArc(position.X,position.Y,position.Z,vx,vy,vz,floor)
  floor=floorAt(arc.landX,arc.landZ) or floor
 end
 scene.spawnOrePickup(dig.template,{owner=owner,runId=profile.run.id,nodeId=nodeId,
  material=cargo,tierMaterial=material,value=Workshop.saleItem(cargo).cash,
  stone=stone,rareGem=rareGem,units=1,raw=true,oreArc=true,floor=(floor or guess)+.22,reachBonus=0,modifiers=0,geode=high==true},
  position,Vector3.new(vx,vy,vz),color)
end
-- Plain rock from a chunk, in the stone of its depth (deeper rock sells for
-- more). No physical pickups: the chunk leaves a little pile of glowing rock
-- dust on the pit floor that flies into your bag once you come close.
local DUST_RANGE=14
function scene.digRock(p,owner,ids,count,position)
 if not healthy(p) then return end
 local dig=scene.dig;local cube=dig.cube
 local first=cube.cells[ids[1]]
 local layer=first.layer
 local tierIndex=math.clamp(1+math.floor((layer-1)/2.2),1,#DigCube.ORES)
 local ore=DigCube.ORES[tierIndex]
 local tier=Workshop.CRYSTAL_BY_MATERIAL[ore.material]
 if not tier then return end
 local c=DigCube.layerColor(cube,layer,position.X-dig.origin.X,position.Z-dig.origin.Z)
 local value=math.max(1,math.floor(tier.value*.5+.5))
 local cargo=Workshop.saleCargo(ore.material,value,true,Workshop.PITY_PERCENT,150,0,'Original')
 local part=Instance.new('Part');part.Name='DigDust'
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.Transparency=1
 part.Size=Vector3.new(.2,.2,.2);part.Position=position
 part:SetAttribute('Owner',owner);part:SetAttribute('Count',count);part:SetAttribute('FloorY',dig.origin.Y+first.y0)
 part:SetAttribute('Color',Color3.fromRGB(c[1],c[2],c[3]));part:SetAttribute('Born',now)
 part.Parent=dig.dustFolder
 table.insert(dig.dust,{p=p,owner=owner,part=part,position=Vector3.new(position.X,dig.origin.Y+first.y0+.5,position.Z),
  cargo=cargo,units=count,readyAt=now+DigCube.PAUSE*.6,expires=now+150})
end
-- Rock dust flies into its owner's bag when they come within range.
function scene.digDustStep()
 local dig=scene.dig
 if now<dig.dustAt then return end
 dig.dustAt=now+.1
 for i=#dig.dust,1,-1 do
  local dust=dig.dust[i]
  local p=dust.p
  if profiles[dust.owner]~=p or now>=dust.expires or not dust.part.Parent then
   dust.part:Destroy();table.remove(dig.dust,i)
  elseif now>=dust.readyAt and healthy(p) then
   local hr=characterRoot(p)
   if hr and (hr.Position-dust.position).Magnitude<=math.max(DUST_RANGE,p.cargoReach or 0) then
    local accepted=Pro.addCargo(data(p),dust.cargo,dust.units,Ca.capacity(data(p),previewPerks(p)))
    if accepted>0 then
     dust.units-=accepted;p.dirty=true;p.publishDirty=true
     p.collectSerial=(p.collectSerial or 0)+1
     p.collectTotal=(p.collectTotal or 0)+accepted
     p.player:SetAttribute('CollectedOreTotal',p.collectTotal)
     local color=dust.part:GetAttribute('Color') or Color3.new(1,1,1)
     p.player:SetAttribute('MA_Collect',Http:JSONEncode({serial=p.collectSerial,total=p.collectTotal,at=now,units=accepted,pickupId=0,exhausted=dust.units==0,physical=true,
      x=dust.position.X,y=dust.position.Y,z=dust.position.Z,r=math.floor(color.R*255),g=math.floor(color.G*255),b=math.floor(color.B*255)}))
     dust.part:SetAttribute('Count',dust.units)
     if dust.units==0 then
      dust.part:SetAttribute('CollectedAt',now)
      Debris:AddItem(dust.part,2);table.remove(dig.dust,i)
     end
    end
   end
  end
 end
end
function scene.digGem(p,owner,tier,volume,position,high)
 if not healthy(p) then return end
 local ore=DigCube.ORES[tier]
 local material=ore and Workshop.CRYSTAL_BY_MATERIAL[ore.material]
 if not material then return end
 local size=math.clamp(volume/250,.6,3)
 local value=math.clamp(math.floor(8*material.value*size+.5),1,1000000)
 local cargo=Workshop.saleCargo(ore.material,value,false,100,0,0,'Original')
 scene.digLaunch(p,owner,cargo,ore.material,false,true,position,Color3.fromRGB(ore.color[1],ore.color[2],ore.color[3]),'dig:gem:'..#scene.dig.ops,high)
 p.dirty=true;p.publishDirty=true
end
-- Replicate new chunks at most ten times a second, 64 per attribute so only
-- the newest attribute changes; start a fresh cube once it is mostly dug out
-- or nothing is left to cut.
function scene.digStep()
 local dig=scene.dig
 if not dig.cube then scene.digReset();return end
 scene.digDustStep()
 scene.digGeodeStep()
 if dig.dirty and now>=dig.publishAt then
  dig.dirty=false;dig.publishAt=now+.1
  local first=math.floor(dig.published/OPS_PER_ATTRIBUTE)+1
  local last=math.ceil(#dig.ops/OPS_PER_ATTRIBUTE)
  for i=first,last do
   dig.holder:SetAttribute('Ops'..i,table.concat(dig.ops,';',(i-1)*OPS_PER_ATTRIBUTE+1,math.min(#dig.ops,i*OPS_PER_ATTRIBUTE)))
  end
  dig.published=#dig.ops
  dig.holder:SetAttribute('OpCount',#dig.ops)
 end
 for i=#dig.pending,1,-1 do
  local gem=dig.pending[i]
  if now>=gem.at then
   table.remove(dig.pending,i)
   if profiles[gem.owner]==gem.p then scene.digGem(gem.p,gem.owner,gem.tier,gem.volume,gem.position,gem.high) end
  end
 end
 if dig.resetAt then
  if now>=dig.resetAt then scene.digReset() end
 elseif now>=dig.checkAt then
  dig.checkAt=now+3
  local spent=dig.cube.removedCount>=#dig.cube.cells*.82
  if spent or not DigCube.pick(dig.cube,{random=function() return .5 end}) then dig.resetAt=now+4 end
 end
end
scene.digReset()
end
local function droneStep(d: any,dt: number)
 local p=profiles[d.owner];if not p then return end
 if d.specialRecovery and not d.specialPausedAt and (not d.specialRecovery.part.Parent or now>=d.specialRecovery.startedAt+d.specialRecovery.duration+1.15) then d.specialRecovery=nil end
 if d.hp<=0 then
  d.velocity=Vector3.zero
  d.state=now>=d.readyAt-C.Assembly and 'Reprinting' or 'Destroyed';d.pos=scene.printer.Position+Vector3.new((d.slot-1)%4*2,3,math.floor((d.slot-1)/4)*2);d.goal=d.pos
  if R.finishReprint(d,now,d.stats.maxHealth) then d.field=nil;d.commandOutAt=nil end
  return
 end
 -- Freeze the job during a yielding save; no damage or profile mutation occurs.
 -- Shift the warmup clock so storage latency cannot skip weapon startup.
 if p.busy then
  if d.warmAt then d.warmAt=d.warmAt+dt end
  if d.chargeAt then d.chargeAt=d.chargeAt+dt end
  if d.pickupAt then d.pickupAt=d.pickupAt+dt end
  if d.oreSeatUntil then d.oreSeatUntil+=dt end
  if d.launchAt then d.launchAt=d.launchAt+dt end
  if d.unloadAt then d.unloadAt=d.unloadAt+dt end
  if d.repairChargeAt then d.repairChargeAt=d.repairChargeAt+dt end
  if d.breaker and d.breaker.phase~='Dive' then d.breaker.phaseAt+=dt end
  if d.growAt then d.growAt+=dt end
  if d.lingerUntil then d.lingerUntil+=dt end
  -- Storage freezes work, not safe flight. No profile, damage, reservation or
  -- job transition is mutated here; travel retains its committed destination.
  if store:healthy(p.session) and d.goal then
   if d.breaker and d.breaker.phase=='Dive' and d.breaker.diveStart then
    local job=d.breaker;d.goal=job.impact;d.intentGoal=job.impact
    d.pos,d.velocity=Feel.powerDive(job.diveStart,job.impact,now-job.phaseAt,DroneRoles.BREAKER.diveDuration)
    if now-job.phaseAt>=DroneRoles.BREAKER.diveDuration then d.velocity=Vector3.zero end
   elseif not d.oreDock then move(d,d.intentGoal or d.goal,dt) end
  end
  return
 end
 if not store:healthy(p.session) then release(d);return end
 if d.role=='Courier' then
  d.flightMass,d.loadSpeed=Feel.courierLoad(Pro.droneCargoUnits(data(p),d.id))
 else
  d.flightMass=d.role=='Ballcaster' and 1.65 or d.role=='Needler' and 1.3 or 1.4
 end
 if logistics then
  local station=logistics:station(d)
  if station then
   release(d);d.pos=station;d.goal=station;d.velocity=Vector3.zero;d.state='Docked'
   if logistics:atHome(d) then d.hp=math.min(d.stats.maxHealth,d.hp+8*dt) end
   return
  end
 end
 local hr=characterRoot(p)
 if not hr and d.deployedCarrier and d.field and scene.patchById[d.field] then hr={Position=scene.patchById[d.field].center} end
 if not hr then
  if d.field then leaveField(p,nil,nil,true) end
  if d.state=='Follow' then
   local spawnAt=(scene.spawnPosition or home)+Vector3.new(0,4,0)
   move(d,scene.followGoal(d,spawnAt,#p.drones),dt)
  else
   move(d,home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,d.flightHeight or Feel.FollowHeight,0),dt)
  end
  return
 end
 if scene.digActive(p) then
  if not p.digging then p.digging=true;p.player:SetAttribute('MA_Digging',true);leaveField(p) end
  scene.digDrone(d,p,dt);return
 elseif p.digging then p.digging=false;p.player:SetAttribute('MA_Digging',false);scene.digRelease(p) end
 if scene.chargingStation and not d.carrierId and d.stats.batteryCapacity>0 then
  local committed=scene.committedWork(d)
  if d.chargedPin and (d.chargedPin~=p.miningSquare or committed) then d.chargedPin=nil end
  if committed and not d.recharging then
   d.battery=math.max(0,d.battery-2*dt)
  end
  -- Committed cuts and seated merges finish before the drone leaves to charge.
  local press=d.role=='Compactor'
  local needsCharge
  if press then
   local finishing=d.pressJob and d.pressJob.startedAt or now<(d.pressUntil or 0)
   needsCharge=not finishing and not scene.pressHasPower(d)
  else
   needsCharge=d.battery<=0 and not scene.finishingDiscreteCut(d)
  end
  if needsCharge and not d.recharging then
   local pin,target=d.squareJob,d.target
   if press then scene.resetPress(d,true) end
   release(d);d.recharging=true
   if pin and pin==p.miningSquare and target and target.hardness>=Workshop.DEEP_CUT_HARDNESS then
    d.resumePin=pin;d.resumeResourceId=target.id
   end
  end
  if d.recharging then
   local localCharge=p.miningSquare and (p.fieldCharge or 0)>0
   local pad=localCharge and p.miningSquare.center or scene.chargingStation.Position
   local limit=localCharge and 7 or 3
   local offset=Feel.formation(d.slot,#p.drones);if offset.Magnitude>limit then offset=offset.Unit*limit end
   local goal=pad+offset+Vector3.new(0,2.6,0)
   d.state='ToCharge';d.chargeSite=nil;move(d,goal,dt)
   if (d.pos-goal).Magnitude<1.4 then
    local rate=localCharge and p.fieldCharge or 35
    d.state='Charging';d.chargeSite=localCharge and 'Field' or 'Depot'
    d.battery=math.min(d.stats.batteryCapacity,d.battery+rate*Workshop.chargeSpeed(data(p))*dt)
    if d.battery>=d.stats.batteryCapacity then
     d.recharging=nil
     if not localCharge then d.chargedPin=p.miningSquare end
    end
   end
   return
  end
 end
 if now<(d.thinkUntil or 0) and not d.oreDock and not d.oreSeatUntil
  and not (d.pressJob and d.pressJob.startedAt) and not data(p).run.deliveries[d.id] then
  d.thinkPosition=d.thinkPosition or d.pos
  d.state='Thinking';d.mining=false;d.descentOrigin=nil;d.lastMoveFormation=false
  move(d,d.thinkPosition,dt)
  return
 end
 d.thinkPosition=nil
 if d.lingerUntil and not d.breaker then
  if now<d.lingerUntil then
   d.state='Recover';d.mining=false;move(d,d.lingerGoal or d.pos,dt);return
  end
  d.lingerUntil=nil;d.lingerGoal=nil
 end
 local manifest=data(p).run.deliveries and data(p).run.deliveries[d.id]
 if manifest then
  if d.target or d.combatTarget then release(d) end
  if d.launchAt and now<d.launchAt+RoleConfig.Courier.LaunchHold then
   d.state='Launch';d.goal=d.pos;return
  end
  d.state='Deliver';d.deliveryId=manifest.id
  local goal=scene.courierDeliveryGoal(d,p)
  move(d,goal,dt)
  if (d.pos-goal).Magnitude<1 then
   d.unloadAt=d.unloadAt or now;d.state='Unload'
   d.deliveryArrived=now-d.unloadAt>=RoleConfig.Courier.UnloadHold
  else d.unloadAt=nil;d.deliveryArrived=false end
  return
 end
 if d.role=='Courier' then
  d.mining=false;d.field=nil
  if scene.runStart then
   if not scene.collectGroundCargo(d,p,hr,dt) and not scene.holdSquare(d,p,dt) then
    d.state='Follow'
    move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt)
   end
   return
  end
  if logistics:capacity(p)<=0 then
   d.deliveryRequested=false;d.pickupAt=nil;d.state='StorageFull'
   if scene.holdSquare(d,p,dt) then return end
   move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt);return
  end
  if scene.emptierReady(d,data(p)) and now>=(d.collectAfter or 0) then
   local rank=0;for _,other in ipairs(p.drones) do if other.role=='Courier' then rank+=1;if other==d then break end end end
   d.state='Collect';move(d,hr.Position+scene.emptierOffset(rank),dt)
   if (d.pos-hr.Position).Magnitude<=RoleConfig.Courier.PickupDistance and los(d.pos,hr.Position,hr.Parent,{droneFolder}) then
    d.pickupAt=d.pickupAt or now;d.state='Pickup'
    d.deliveryRequested=now-d.pickupAt>=RoleConfig.Courier.PickupHold
   else d.pickupAt=nil;d.deliveryRequested=false end
  else
   d.pickupAt=nil;d.deliveryRequested=false
   if not scene.holdSquare(d,p,dt) then followRole(d,p,hr,dt) end
  end
  return
 elseif d.role=='Vacuum' then
  if p.vacuum==d and p.vacuumTarget then
   d.state='Vacuum';move(d,p.vacuumTarget.position,dt)
  else followRole(d,p,hr,dt) end
  return
 elseif d.role=='Compactor' then
  if now<(d.pressUntil or 0) then d.state='Press';d.goal=d.pos;d.velocity=Vector3.zero
  elseif d.pressJob and d.pressJob.castAt then
   d.state=d.pressJob.startedAt and 'Press' or 'Intake';d.goal=d.pressJob.position;d.intentGoal=d.goal;d.velocity=Vector3.zero
  elseif d.pressJob then
   d.state='Intake';move(d,d.pressJob.position,dt)
  elseif not scene.holdSquare(d,p,dt) then followRole(d,p,hr,dt) end
  return
 elseif d.role=='Medic' then supportDrone(d,p,hr,dt);return
 elseif d.role=='Dart' then growerDrone(d,p,hr,dt);return
 elseif DroneRoles.ability(d.role) then roleAbilityStep(d,p,hr,dt);return end
 scene.squareStep(p,d)
 if not d.target and not d.breaker and scene.holdSquare(d,p,dt) then return end
 if d.role=='Charger' and not d.field then
  local selected=workingField(p,hr)
  if selected then d.field=selected.id end
 end
 local field=d.field and scene.patchById[d.field]
 -- Cleared/safe mining orders are independent jobs. Combat still has the
 -- owner leash and server-owned guard participation.
 local idleManual=field and not d.autoField and not d.target
 if field and not d.deployedCarrier and (not playerCanMine(p,field) or idleManual) and (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then
  d.commandOutAt=d.commandOutAt or now
  if now-d.commandOutAt>3 then leaveDroneField(p,d);field=nil end
 else d.commandOutAt=nil end
 if field then
  if field.e.phase=='Active' and R.participates(field.e,d,data(p).run.id) then
   attackDrone(d,field,dt)
  elseif playerCanMine(p,field) then
   if d.deployedCarrier and logistics:capacity(p)<=0 then
    release(d);d.state='StorageFull';scene.waitAtPlot(d,p,field,nil,dt)
   elseif not d.deployedCarrier and not d.squareJob and not nearMiningField(hr.Position,field) then
    -- Ore goes into a backpack carried by the owner. Leaving the plot brings
    -- the swarm along. The profile-level leash clears the order before work resumes.
    if field.junk then leaveDroneField(p,d) end
    d.mining=false;d.warmAt=nil;d.mineCharge=0;d.state='Follow'
    move(d,scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt),dt)
   elseif DroneCatalog.Types[d.role] then specialDrone(d,p,field,dt)
   elseif d.role=='Charger' then breakerDrone(d,p,hr,field,dt)
   else mineDrone(d,p,field,dt) end
  else leaveDroneField(p,d) end
 else
  d.mining=false;d.combatTarget=nil
  d.chargeAt=nil;d.chargeTarget=nil
  local height=d.flightHeight or Feel.FollowHeight
  if d.state~='Return' then d.state='Follow' end
  local goal=d.state=='Return' and home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,height,0) or scene.followGoal(d,hr.Position,#p.drones,hr.AssemblyLinearVelocity,dt)
  move(d,goal,dt)
  if d.state=='Return' and (d.pos-goal).Magnitude<1 then d.state='Follow' end
  if (d.pos-home).Magnitude<22 then d.hp=math.min(d.stats.maxHealth,d.hp+8*dt) end
 end
end
function scene.publishCharger()
 local indicator=scene.chargeIndicator
 if not indicator then return end
 local focus=scene.chargerFocus
 if focus and (drones[focus.id]~=focus or focus.state~='Charging' or focus.chargeSite~='Depot' or focus.hp<=0) then
  if drones[focus.id]==focus and focus.hp>0 and focus.battery>=focus.stats.batteryCapacity then
   scene.chargerFullUntil=now+.28
  end
  focus=nil
 end
 local full=now<(scene.chargerFullUntil or 0)
 if not focus and not full then
  for id,d in pairs(drones) do
   if d.state=='Charging' and d.chargeSite=='Depot' and d.hp>0 and (not focus or id<focus.id) then focus=d end
  end
 end
 scene.chargerFocus=focus
 local progress=if full then 1 elseif focus then math.clamp(focus.battery/focus.stats.batteryCapacity,0,1) else nil
 if indicator:GetAttribute('ChargeProgress')~=progress then indicator:SetAttribute('ChargeProgress',progress) end
end
function scene.insideSquareField(position)
 for _,bed in ipairs(scene.squareFields) do
  if Mining.inField(position,bed) then return true end
 end
 return false
end
local function snapshotDrone(d)
 local pose=CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0)
 if d.publishedPose~=pose then d.model:PivotTo(pose);d.publishedPose=pose end
 local profile=data(profiles[d.owner])
 local delivery=profile.run.deliveries[d.id]
 local slots=scene.runStart and d.role=='Courier' and Workshop.emptierBatch(profile) or 0
 local counter=scene.runStart and scene.packStation or scene.converter or scene.packStation
 local salePosition=counter.Position
 if slots>0 then
  -- Alternate the two Emptiers across the field-facing side of the nameplate.
  local lane=(d.slot%2==0 and -1 or 1)*counter.Size.X*.22
  salePosition=counter.CFrame:PointToWorldSpace(Vector3.new(lane,counter.Size.Y*.5,counter.Size.Z*.22))
 end
 local deliveryId=delivery and delivery.id or ''
 local load=delivery and delivery.cargo or profile.run.droneCargo[d.id]
 local units=slots>0 and math.min(slots,Pro.droneCargoUnits(profile,d.id)) or Pro.deliveryUnits(profile,d.id)
 if slots>0 and (d.displayedDelivery~=deliveryId or d.displayedUnits~=units) then
  d.displayedDelivery=deliveryId;d.displayedUnits=units
  local materials,shown={},{}
  if load then
   for material in pairs(load) do table.insert(materials,material) end
   table.sort(materials)
   local remaining=table.clone(load)
   -- Preserve each occupied grip when a differently colored rock arrives.
   for _,material in ipairs(d.displayedMaterials or {}) do
    if (remaining[material] or 0)>0 and #shown<6 then
     table.insert(shown,material);remaining[material]-=1
    end
   end
   for _,material in ipairs(materials) do
    for _=1,math.min(remaining[material],6-#shown) do table.insert(shown,material) end
   end
  end
  d.displayedMaterials=shown
  d.deliveryMaterials=table.concat(shown,';')
 end
 local groundCargo=d.orePickupId and pickups[d.orePickupId]
 local target=d.target
 if target and (target.paid or target.hp<=0 or not target.part.Parent) then retireTarget(d);target=nil end
 local breakContact=d.mineBreakContact
 if breakContact and (now>=breakContact.untilTime or not healthy(profiles[d.owner]) or d.hp<=0) then d.mineBreakContact=nil;breakContact=nil end
 if (d.forkUntil or 0)<=now then d.forkTargetId=nil end
 if (d.chainUntil or 0)<=now then d.chainTargetId=nil end
 local combatTarget=d.state=='Attack' and d.mining and d.combatTarget
 local combatId=combatTarget and combatTarget.hp>0 and combatTarget.model.Parent and combatTarget.model:GetAttribute('TurretId') or ''
 local mining=not profiles[d.owner].busy and d.state=='Mine' and d.mining and target~=nil
 local values={Owner=d.owner,DroneId=d.id,DroneName=d.name,Name=d.name,Type=d.owned.type,Role=d.role,FlightHeight=d.flightHeight or Feel.FollowHeight,Life=d.life,State=d.state,HP=d.hp,MaxHP=d.stats.maxHealth,ChargeAt=d.chargeAt or 0,Firing=combatId~='',
  Battery=math.round((d.battery or 0)*10)/10,MaxBattery=d.stats.batteryCapacity,
  ThinkUntil=d.thinkUntil or 0,PressStarted=d.pressJob and d.pressJob.startedAt or 0,
  PressFinish=d.pressJob and d.pressJob.finishAt or 0,
  BatteryPowered=scene.chargingStation~=nil and d.stats.batteryCapacity>0,
  HideBattery=scene.insideSquareField(d.pos) or profiles[d.owner].digging==true,
  DigCell=d.digCell or 0,DigOp=d.digJob and ('c'..d.digJob.key) or '',DigChunkSize=d.digJob and Config.DigCube.chunkSize(d.role,d.id,d.slot) or '',DigPoint=d.digPoint or d.pos,DigProgress=d.digProgress or 0,
  DigMining=d.digCell~=nil and d.mining==true and not profiles[d.owner].busy,
  InMiningPlot=profiles[d.owner].miningSquare~=nil and Mining.selectorContains(profiles[d.owner].miningSquare.center,profiles[d.owner].miningSquare.half,d.pos),
  BatteryWorking=(d.role=='Compactor' and d.state=='Press') or scene.committedWork(d) or combatId~='',
  PressWaiting=d.pressWaiting==true,
  Position=d.pos,Goal=d.goal,Velocity=d.velocity or Vector3.zero,FlightSteering=d.flightSteering or Vector3.zero,
  FlightMass=d.flightMass or 1,FlightResponse=d.flightResponse or 1,FlightWork=d.flightWork==true,
  Yaw=d.yaw,WorkPaused=profiles[d.owner].busy,MotionPaused=not store:healthy(profiles[d.owner].session) and d.hp>0,MaxStep60=d.flightSpeed or travelSpeed(d),PhaseSeed=d.owned.base.maxStep60*200,FormationSlot=d.slot,FleetCount=#profiles[d.owner].drones,
  TargetId=target and target.id or '',CombatTargetId=combatId,TargetPosition=target and target.position or (combatId~='' and combatTarget.emitter.Position) or d.pos,Mining=mining,BeamSince=d.beamSince,WarmupStart=d.warmAt or 0,WarmupDuration=d.digWarmFor or scene.miningWarmup(d,target),
  DoubleBeam=d.stats.doubleBeam==1,TwinThrusters=d.stats.twinThrusters==1,OreDuplicator=d.stats.oreDuplicator==1,
  BeamVariant=d.owned.beamVariant,MiningStyle=DroneRoles.isMiner(d.role) and 'Cutter' or 'None',MinePulseSerial=d.minePulseSerial,MinePulseAt=d.minePulseAt,MinePulseTargetId=d.minePulseTargetId,
  RecallSerial=d.recallSerial or 0,RecallAt=d.recallAt or 0,
  BreakerDiveStart=d.breaker and d.breaker.diveStart or d.pos,BreakerImpact=d.breaker and d.breaker.impact or d.pos,BreakerPhaseAt=d.breaker and d.breaker.phaseAt or 0,BreakerDiveDuration=DroneRoles.BREAKER.diveDuration,
  BreakerContactSerial=d.contactSerial or 0,BreakerContactAt=d.contactAt or 0,ImpactAt=d.impactAt or 0,
  DeliveryUnits=units,DeliveryId=deliveryId,DeliverySlots=slots,DeliveryMaterials=d.deliveryMaterials or '',AutoFieldId=d.autoField or 0,
  CourierDock=d.oreDock or false,CourierDockYaw=d.oreYaw or false,
  CourierPickupPoint=d.oreDock and d.oreHookPoint or false,CourierGrappling=d.oreDock~=nil,
  CourierHookOre=d.oreDock and d.orePickupId or d.oreLoadedId or 0,
  CourierEntryOffset=d.oreDock and d.oreEntryOffset or Vector3.zero,
  CourierEntryVelocity=d.oreDock and d.oreEntryVelocity or false,
  CourierApproachTime=d.oreDock and d.oreApproachTime or false,CourierReturnTurn=d.oreDock and d.oreReturnTurn or false,
  CourierPacked=groundCargo and groundCargo.compacted==true or false,
  CourierLoadedOre=d.oreLoadedId or 0,CourierLoadedMaterial=d.oreLoadedMaterial or '',CourierLoadedAt=d.oreLoadedVisualAt or 0,
  CourierPickupAt=d.pickupAt or 0,CourierPickupHold=RoleConfig.Courier.PickupHold,CourierLaunchAt=d.launchAt or 0,CourierLaunchHold=RoleConfig.Courier.LaunchHold,
  CourierUnloadAt=d.unloadAt or 0,CourierUnloadHold=RoleConfig.Courier.UnloadHold,CourierSaleSerial=d.saleSerial or 0,CourierSaleAt=d.saleAt or 0,SellPosition=salePosition,
  Healing=d.hp>0 and d.healTargetId~=nil and now<(d.healUntil or 0),HealTargetId=d.healTargetId or '',
  RepairChargeAt=d.repairChargeAt or 0,RepairChargeDuration=RoleConfig.Types.Medic.ChargeWindup,
  CanMine=DroneRoles.isWorker(d.role),AutomationMineEnabled=DroneRoles.isWorker(d.role) and (d.stats.plotAuto or 0)>0,AutomationHaulEnabled=d.role=='Courier',WorkRole=DroneRoles.job(d.role),ImpactSerial=d.impactSerial or 0,
  MineBreakSerial=d.mineBreakSerial,MineBreakAt=breakContact and breakContact.at or 0,MineBreakUntil=breakContact and breakContact.untilTime or 0,
  MineBreakPrimaryId=breakContact and breakContact.primaryId or '',MineBreakSecondaryId=breakContact and breakContact.secondaryId or '',MineBreakBeamSince=breakContact and breakContact.beamSince or 0,
  ReprintAt=d.hp<=0 and d.readyAt or 0,SnapshotAt=now,ShotSerial=d.shotSerial,ShotAt=d.lastShotAt,LastCritAt=d.lastCritAt,Shield=d.shield,
  ForkTargetPosition=d.forkTarget or d.pos,ForkTargetId=(d.forkUntil or 0)>now and (d.forkTargetId or '') or '',ForkUntil=d.forkUntil or 0,
  ChainTargetPosition=d.chainTarget or d.pos,ChainTargetId=(d.chainUntil or 0)>now and (d.chainTargetId or '') or '',ChainUntil=d.chainUntil or 0,
  GeodeMultiplier=d.stats.geodeMultiplier,FinisherMultiplier=d.stats.finisherMultiplier,SalvageFraction=d.stats.salvageFraction,ChainRange=d.stats.splashRange}
 local published=d.publishedAttributes or {};d.publishedAttributes=published
 for k,v in pairs(values) do if published[k]~=v then d.model:SetAttribute(k,v);published[k]=v end end
 if published.CarrierId~=d.carrierId then d.model:SetAttribute('CarrierId',d.carrierId);published.CarrierId=d.carrierId end
 local deployed=d.deployedCarrier==true
 if published.DeployedCarrier~=deployed then d.model:SetAttribute('DeployedCarrier',deployed);published.DeployedCarrier=deployed end
end
-- Publish pause transitions immediately, not only on the periodic snapshot.
-- Resume position and goal are sent before the pause flag is cleared.
local function setMotionPaused(p: any,paused: boolean)
 for _,d in ipairs(p.drones) do
  if d.model and d.model.Parent and d.hp>0 then
   d.publishedAttributes=nil -- Immediate pause writes invalidate snapshot deltas.
   local effectJob=d.specialJob or d.specialRecovery
   local effectPart=d.specialJob and d.target and d.target.part or d.specialRecovery and d.specialRecovery.part
   if effectPart and not effectPart.Parent then effectJob=nil;effectPart=nil end
   local ownsEffect=effectPart and effectPart:GetAttribute('EffectDrone')==d.id
   if paused then
    if effectJob and effectPart and not d.specialPausedAt then
     d.specialPausedAt=now
     if ownsEffect then effectPart:SetAttribute('EffectPausedAt',now) end
     if effectJob.projectile and effectJob.projectile.Parent then effectJob.projectile:SetAttribute('PausedAt',now) end
    end
    d.model:SetAttribute('Mining',false);d.model:SetAttribute('Firing',false)
    d.mineBreakContact=nil;d.model:SetAttribute('MineBreakUntil',0);d.model:SetAttribute('MineBreakPrimaryId','');d.model:SetAttribute('MineBreakSecondaryId','')
   elseif d.specialPausedAt then
    if effectJob and effectPart then
     local pausedFor=math.max(0,now-d.specialPausedAt)
     effectJob.startedAt+=pausedFor
     if effectJob.projectile and effectJob.projectile.Parent then
      effectJob.projectile:SetAttribute('StartedAt',effectJob.startedAt);effectJob.projectile:SetAttribute('PausedAt',0)
     end
     if ownsEffect then
      if effectJob.impacted then effectPart:SetAttribute('EffectDoneAt',(effectPart:GetAttribute('EffectDoneAt') or now)+pausedFor) end
      effectPart:SetAttribute('EffectStartedAt',effectJob.startedAt);effectPart:SetAttribute('EffectPausedAt',0)
     end
     if d.specialRecovery then
      local retired=resources[effectPart:GetAttribute('ResourceId')]
      if retired and retired.removeAt then retired.removeAt+=pausedFor end
     end
    end
    d.specialPausedAt=nil
   end
   d.model:SetAttribute('Position',d.pos);d.model:SetAttribute('Goal',d.goal);d.model:SetAttribute('Yaw',d.yaw)
   d.model:SetAttribute('WorkPaused',paused)
   d.model:SetAttribute('MotionPaused',not store:healthy(p.session))
  end
 end
end
local function resolveAfter(p,result)
 local after=p.pendingAfter;p.pendingAfter=nil
 local outcome=p.pendingOutcome;p.pendingOutcome=nil
 local committed=result and result.committed~=false
 if committed and after and not p.leaving then after(result) end
 if outcome and not p.leaving then outcome(committed and 'accepted' or 'rejected',committed and 'Card installed' or 'Save confirmed no change; try again') end
end
local function transact(p: any,id: any,mutate: any,after: any,outcome: any)
 if p.leaving or p.busy or not store:healthy(p.session) then return false end
 p.busy=true;setMotionPaused(p,true);p.pendingAfter=after;p.pendingOutcome=outcome;publish(p)
 task.spawn(function()
  local ok,result=store:transaction(p.session,id,mutate)
  if ok then p.dirty=false;resolveAfter(p,result)
  else
   notice(p,tostring(result))
   if p.session.readOnly then
    if p.pendingOutcome then p.pendingOutcome('uncertain','Saving outcome is being checked') end
    local recovered,reconciled=store:reconcile(p.session)
    if recovered then resolveAfter(p,reconciled) end
   else
    p.pendingAfter=nil;local report=p.pendingOutcome;p.pendingOutcome=nil
    if report then report('rejected',tostring(result)) end
   end
  end
  p.busy=false;setMotionPaused(p,not store:healthy(p.session));settleRuntime(p);if not p.leaving then publish(p) end
 end)
 return true
end
local logisticsTerrain=MapLayout.plan(C.Fields,{home.X,home.Y,home.Z})
logistics=Logistics.new({C=C,R=R,W=World,root=root,origin=home,profiles=profiles,drones=drones,patches=patches,
 data=data,Pro=Pro,Profile=Pro,Shops=Shops,capacityOf=function(profile) return Ca.capacity(profile,previewPerks(profiles[profile.userId])) end,healthy=healthy,characterRoot=characterRoot,inHome=atHome,
 notice=notice,updateProfile=publish,getClock=function() return now end,transact=transact,
 atDepotStation=function(p) return atStation(p,scene.converter or scene.packStation,18) end,
 groundHeight=function(x,z)
  if root:GetAttribute('DronerevolutionMapVersion') then return root:GetAttribute('LogisticsSurfaceHeight') or 4 end
  return logisticsTerrain:surface(x,z)
 end,
 guid=function() return Http:GenerateGUID(false) end,prices=prices,release=release,
 recall=function(d) local p=profiles[d.owner];if p then leaveDroneField(p,d) end end,
 assignFleet=function(p,field,fleet)
  if not healthy(p) or not playerCanMine(p,field) or activeAssault(p) or #fleet==0 then return false end
  for _,d in ipairs(fleet) do if d.owner~=p.player.UserId or d.hp<=0 or not DroneRoles.isWorker(d.role) then return false end end
  for _,d in ipairs(fleet) do
   if d.field~=field.id then release(d);spend(d) end
   d.field=field.id;d.autoField=field.id;d.state='Travel';d.commandOutAt=nil
  end
  return true
 end,
 canMine=playerCanMine,canDeploy=playerCanMine,isWorker=function(d) return DroneRoles.isWorker(d.role) end})
local function assignOre(p: any,d: any,r: any): boolean
 if d.carrierId or not DroneRoles.isWorker(d.role) or d.target==r or not sameRockType(d,r) then return false end
 local occupied={};for id,slot in pairs(r.slots) do
  if not drones[id] or drones[id].owner~=p.player.UserId then return false end
  occupied[slot]=true
 end
 local slot=1;while slot<=r.limit and occupied[slot] do slot+=1 end
 if slot>r.limit then return false end
 local old=d.field;local resume=d.autoField~=nil or (d.stats.plotAuto or 0)>0;release(d);spend(d)
 d.autoField=resume and r.field.id or nil;d.manualTarget=r.id
 d.field=r.field.id;d.target=r;d.targetSlot=slot;d.state='Travel';d.commandOutAt=nil;p.workField=r.field.id
 r.slots[d.id]=slot;updateSlots(r)
 if old~=d.field then dropFieldIfEmpty(p,old) end
 return true
end
local function dispatchOreQueue(p: any)
 if not healthy(p) or not characterRoot(p) or activeAssault(p) then return {} end
 local assigned={};local queue=p.oreQueue or {};local index=1
 while index<=#queue do
  local r=resources[queue[index]]
  if not r or r.openReady or r.openingAt or r.paid or r.hp<=0 or not r.part.Parent or not playerCanMine(p,r.field) then table.remove(queue,index);p.publishDirty=true
  elseif now<r.readyAt or not nearMiningField(characterRoot(p).Position,r.field) then index+=1
  else
   local best,distance=nil,math.huge
   for _,d in ipairs(p.drones) do
    -- An explicit order may redirect automatic cutting/travel. Never cancel
    -- another manual order, a committed slam, or a specialist's physical job.
    local available=not d.target or (d.autoField and not d.manualTarget)
    if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) and available and d.target~=r and sameRockType(d,r) and not d.breaker and not d.specialJob and not d.specialRecovery
     and (not r.blockedUntil or now>=(r.blockedUntil[d.id] or 0)) then
     local n=(d.pos-r.position).Magnitude+(d.target and 10000 or 0)
     if n<distance then best,distance=d,n end
    end
   end
   if not best then index+=1
   elseif assignOre(p,best,r) then assigned[r.id]=best;table.remove(queue,index);p.publishDirty=true else index+=1 end
  end
 end
 p.oreQueue=queue
 return assigned
end
function scene.dispatchJunk(field)
 local crews={}
 for uid,p in pairs(profiles) do
  local hr=healthy(p) and characterRoot(p)
  if not hr then continue end
  local active,workers=0,{}
  for _,d in ipairs(p.drones) do
   if d.hp>0 and d.field==field.id and d.autoField==field.id and (d.deployedCarrier or (not d.carrierId and nearMiningField(hr.Position,field))) then
    local room=not d.deployedCarrier or logistics:capacity(p)>0
    if d.target and (not room or d.target.paid or not d.target.part.Parent) then release(d) end
    if d.target then active+=1
    elseif room and DroneRoles.isWorker(d.role) and not d.breaker and not d.lingerUntil and not d.specialRecovery then
     table.insert(workers,d)
    end
   end
  end
  if #workers>0 and active<JunkField.CrewCap then table.insert(crews,{id=uid,p=p,active=active,workers=workers,turn=p.junkTurn or 0}) end
 end
 JunkField.dispatch(crews,function(crew)
  for i,d in ipairs(crew.workers) do
   if chooseResource(d,field) then
    table.remove(crew.workers,i)
    scene.junkTurn=(scene.junkTurn or 0)+1;crew.p.junkTurn=scene.junkTurn;crew.turn=scene.junkTurn
    d.state='Travel'
    return true
   end
  end
  return false
 end)
end
function scene.saleMilestoneNotice(p,saleQuartz)
 if not scene.runStart or saleQuartz<=0 then return nil end
 local profile=data(p)
 local run=profile.run
 if run.pendingOffer then return nil end
 local balance=run.wallet.Quartz
 local price=Workshop.price(profile)
 local fundsPack=balance>=price and balance-saleQuartz<price
 local goal=Pro.milestone(profile).earnings
 local earnsPrestige=run.quartzEarnings>=goal and run.quartzEarnings-saleQuartz<goal
 if earnsPrestige and (run.packIndex>0 or not fundsPack) then
  return '+'..saleQuartz..' Quartz · Prestige ready'
 elseif fundsPack then
  return '+'..saleQuartz..' Quartz · Pack Counter ready'
 end
end
function scene.sendSaleReceipt(p,id,result,full,target,auto)
 local receipt={id=id,runId=result.runId,revision=data(p).revision,at=now,
  cargo=result.cargo,resources=result.resources,cash=result.quartz,full=full,auto=auto==true,units=result.units,
  milestone=full and scene.saleMilestoneNotice(p,result.quartz) or nil}
 if target then receipt.counter={target.X,target.Y,target.Z} end
 -- The profile also carries recent receipts so a balance snapshot arriving
 -- before its RemoteEvent cannot jump ahead of the visual credit.
 p.recentSales=p.recentSales or {}
 table.insert(p.recentSales,receipt)
 if #p.recentSales>6 then table.remove(p.recentSales,1) end
 RS.MiningAway.Sale:FireClient(p.player,receipt)
end
local function serviceDeliveries(p: any)
 if not healthy(p) or not characterRoot(p) or now<(p.nextDeliveryAction or 0) then return end
 local run=data(p).run
 for _,d in ipairs(p.drones) do
  local manifest=run.deliveries[d.id]
  local destination=scene.runStart and scene.packStation.Position or logistics:storagePosition(p) or (scene.converter or scene.packStation).Position
  if d.hp>0 and manifest and d.deliveryArrived and d.deliveryId==manifest.id and (d.pos-destination).Magnitude<=12 then
   local tx,runId,id=manifest.id,run.id,d.id
   p.nextDeliveryAction=now+.4
   transact(p,'deliveryFinish:'..tx,function(copy)
    if scene.runStart then
     local ok,result=Pro.finishDelivery(copy,id,prices,tx,runId)
     if ok then return result end;return nil,result
    end
    local parcel=copy.run.deliveries[id]
    if copy.run.id~=runId or not parcel or parcel.id~=tx or parcel.runId~=runId then return nil,'Delivery changed' end
    local accepted=Logistics.depositInto(copy,parcel.cargo)
    for mineral,units in pairs(parcel.cargo) do
     local remainder=units-(accepted[mineral] or 0)
     if remainder>0 then copy.run.logistics.pendingCargo[mineral]=(copy.run.logistics.pendingCargo[mineral] or 0)+remainder end
    end
    copy.run.deliveries[id]=nil
    return {droneId=id,id=tx,runId=runId,stored=true}
   end,function(result)
    local worker=drones[id]
    if worker and worker.owner==p.player.UserId then
     worker.deliveryArrived=false;worker.deliveryId=nil;worker.deliveryRequested=false
     worker.pickupAt=nil;worker.launchAt=nil;worker.unloadAt=nil
     worker.saleSerial=(worker.saleSerial or 0)+1;worker.saleAt=now
     worker.field=nil;worker.autoField=nil;worker.state='Collect'
     worker.collectAfter=now+(scene.runStart and Workshop.emptierCooldown(RoleConfig.Courier.PickupCooldown,data(p)) or RoleConfig.Courier.PickupCooldown)
    end
    if scene.runStart then
     scene.sendSaleReceipt(p,tx,result,false)
     local proceeds=result.quartz>0 and (' · +'..result.quartz..' Quartz') or ''
     if (p.shiftSeconds or 0)>0 then
      p.shiftReadyRun=result.runId
      proceeds..=' · Surge ready'
     end
     notice(p,scene.saleMilestoneNotice(p,result.quartz) or 'Emptier sold '..result.units..' cargo'..proceeds)
    end
    p.publishDirty=true
   end)
   return
  elseif d.role=='Courier' and d.hp>0 and d.deliveryRequested and not manifest and now>=(d.collectAfter or 0) then
   local hr=characterRoot(p)
   local ready=scene.emptierReady(d,data(p))
   if not scene.runStart then
    ready=ready and (d.pos-hr.Position).Magnitude<=RoleConfig.Courier.PickupDistance
     and d.pickupAt and now-d.pickupAt>=RoleConfig.Courier.PickupHold
     and los(d.pos,hr.Position,hr.Parent,{droneFolder})
   end
   if not ready then d.deliveryRequested=false;d.pickupAt=nil
   else
    local tx,runId,id=Http:GenerateGUID(false),run.id,d.id
    p.nextDeliveryAction=now+1
    transact(p,'deliveryBegin:'..tx,function(copy)
     if not scene.emptierReady(d,copy) then return nil,'Courier is waiting for cargo' end
     local batch=scene.runStart and Workshop.emptierBatch(copy) or d.stats.courierCapacity or RoleConfig.Courier.BatchUnits
     local ok,result=Pro.beginDelivery(copy,id,tx,runId,batch,scene.runStart~=nil,scene.runStart~=nil);if ok then return result end;return nil,result
    end,function(result)
     p.nextEmptierPlan=nil
     local worker=drones[id]
     if worker and worker.owner==p.player.UserId then
      release(worker);worker.deliveryId=result.id;worker.deliveryArrived=false
      worker.state=scene.runStart and 'Deliver' or 'Launch';worker.launchAt=not scene.runStart and now or nil
      worker.unloadAt=nil;worker.deliveryRequested=false
     end
     p.publishDirty=true
    end)
    return
   end
  end
 end
end
local function sellBackpack(p: any,automatic: boolean?)
 if activeAssault(p) then
  if not automatic then notice(p,'Recall your fighting drones before selling.') end
  return
 end
 local target
 if not automatic then
  local origin=characterRoot(p).Position
  local nearest=math.huge
  for _,entry in ipairs({{scene.converter or scene.packStation,18},{scene.packStation,20},{shopStations.Quartz,20}}) do
   local station,radius=entry[1],entry[2]
   if not station then continue end
   local distance=(station.Position-origin).Magnitude
   if distance<radius and distance<nearest then
    nearest=distance
    target=station.Position+Vector3.yAxis*(station.Size.Y*.5+.3)
   end
  end
  if not target then notice(p,'Sell your backpack at the Workshop or SELL ORE.');return end
 end
 if Pro.cargoUnits(data(p))==0 then
  if not automatic then notice(p,'Your backpack is empty.') end
  return
 end
 local tx,runId=Http:GenerateGUID(false),data(p).run.id
 transact(p,'sell:'..tx,function(copy)
  local ok,result=Pro.sell(copy,prices,tx,runId)
  if ok then return result end;return nil,result
 end,function(result)
  p.nextEmptierPlan=nil
  scene.sendSaleReceipt(p,tx,result,not automatic,target,automatic and scene.flatFields)
  if automatic then
   local amounts={}
   for _,key in ipairs(Shops.ORDER) do
    local n=key=='Quartz' and result.quartz or result.cargo[key]
    if n and n>0 then table.insert(amounts,tostring(n)..' '..key) end
   end
   notice(p,scene.saleMilestoneNotice(p,result.quartz) or (not scene.flatFields and 'Auto Sell · +'..table.concat(amounts,', ')) or '')
  else
   notice(p,'')
  end
  p.publishDirty=true
 end)
end
local function validPayload(payload)
 return type(payload)=='table' and type(payload.txId)=='string' and #payload.txId>=1 and #payload.txId<=100 and type(payload.runId)=='string' and #payload.runId<=100
end
local offerReceiptSerial=0
local function offerReply(pl: any,payload: any,status: string,reason: string)
 if not validPayload(payload) or type(payload.offerId)~='string' or #payload.offerId>160 then return end
 local gui=pl:FindFirstChildOfClass('PlayerGui');if not gui then return end
 offerReceiptSerial=offerReceiptSerial%1000000000+1
 gui:SetAttribute('MA_OfferReceipt',Http:JSONEncode({txId=payload.txId,runId=payload.runId,offerId=payload.offerId,status=status,reason=reason,serial=offerReceiptSerial}))
end
local function committedOffer(p: any,payload: any): (boolean,boolean)
 if not p or not validPayload(payload) then return false,false end
 for _,receipt in ipairs(p.session.receipts or {}) do
  local result=receipt.result
  if receipt.id=='choose:'..payload.txId and type(result)=='table' then
   local same=result.offerId==payload.offerId and result.runId==payload.runId and result.index==payload.index and result.selectedDroneId==payload.targetDroneId
   return same,not same
  end
 end
 return false,false
end
local function offerUnavailable(p: any,pl: any,payload: any,reason: string)
 if committedOffer(p,payload) then offerReply(pl,payload,'accepted','Card installed')
 elseif validPayload(payload) and p and p.pendingOfferTx==payload.txId then
  offerReply(pl,payload,'uncertain','Saving outcome is being checked')
 else offerReply(pl,payload,'rejected',reason) end
end
local function validCommandId(v)
 return type(v)=='string' and #v>0 and #v<=80 and v:match('^[%w_.:-]+$')~=nil
end
local function validDroneIntent(payload: any): boolean
 if type(payload)~='table' or not validCommandId(payload.requestId) then return false end
 if type(payload.runId)~='string' or #payload.runId>100 then return false end
 if type(payload.droneId)~='string' or #payload.droneId>160 then return false end
 return R.finite(payload.life) and payload.life%1==0
end
local function commandReply(pl: any,payload: any,status: any,reason: any,field: any,drone: any,resource: any,slot: any)
 if type(payload)~='table' or not validCommandId(payload.requestId) then return end
 local gui=pl:FindFirstChildOfClass('PlayerGui');if not gui then return end
 local count,available=0,0
 local p=profiles[pl.UserId]
 if field and p then
  for _,d in ipairs(p.drones) do if d.hp>0 and d.field==field.id then count=count+1 end end
  if playerCanMine(p,field) then for _,r in ipairs(field.resources) do
   if not r.paid and r.hp>0 and now>=r.readyAt then local used=0;for _ in pairs(r.slots) do used=used+1 end;available=available+math.max(0,r.limit-used) end
  end end
 end
 local state={requestId=payload.requestId,status=status,reason=reason,fieldId=field and field.id or nil,assignedCount=count,availableSlots=available,phase=field and field.e.phase or nil,droneId=drone and drone.id or nil,life=drone and drone.life or nil,resourceId=resource and resource.id or nil,slot=slot}
 gui:SetAttribute('MA_CommandState',Http:JSONEncode(state))
end
function scene.syncRuntimeFleet(p)
 for slot,owned in ipairs(scene.runtimeFleet(p)) do
  if not drones[owned.id] then snapshotDrone(spawnDrone(p,owned,slot)) end
 end
end
local function chooseCard(p: any,pl: any,payload: any)
   if type(payload.offerId)~='string' or #payload.offerId>160 or not R.finite(payload.index) or payload.index%1~=0 or payload.index<1 or payload.index>3 or (payload.targetDroneId~=nil and (type(payload.targetDroneId)~='string' or #payload.targetDroneId>100)) then offerReply(pl,payload,'rejected','Invalid choice');return end
   p.pendingOfferTx=payload.txId
   local started=transact(p,'choose:'..payload.txId,function(copy: any)
    local ok: boolean,r: any=Ca.select(copy,payload.offerId,payload.index,payload.txId,payload.runId,{atDepot=true,activeEncounter=false,targetDroneId=payload.targetDroneId});if ok then return r end;return nil,r
   end,function(result)
    scene.syncRuntimeFleet(p)
    refreshStats(p)
    local stars=result.stars or 0
    notice(p,stars>0 and ((result.selectedDroneId and (result.card.title..' fitted to '..result.card.targetName) or 'Upgrade installed')..' · +'..stars..' '..(stars==1 and 'Star' or 'Stars')) or 'Upgrade installed')
   end,function(status,reason) if status~='uncertain' then p.pendingOfferTx=nil end;offerReply(pl,payload,status,reason) end)
   if not started then p.pendingOfferTx=nil;offerReply(pl,payload,'rejected','Profile busy; try again') end
end
local function executePrestige(p: any,pl: any,payload: any)
 if payload.confirm~=true or type(payload.droneType)~='string' or #payload.droneType>24 or not atStation(p,scene.prestigeStation,15) then return end
 local function applyPrestige(copy: any): (any, any)
  local context: any={atDepot=true,activeEncounter=activeAssault(p),confirmed=true,droneType=payload.droneType}
  local ok: boolean,result: any=Pro.prestige(copy,payload.txId,payload.runId,context)
  if ok then return result end
  return nil,result
 end
 transact(p,'prestige:'..payload.txId,applyPrestige,function(result)
  for _,field in ipairs(patches) do local u=field.e.users[pl.UserId];if u then R.removeUser(field.e,pl.UserId,u.runId) end end
  p.oreQueue={};p.workField=nil;p.shiftReadyRun=nil;scene.clearSquare(p)
  p.testFleet=nil
  RoleEffects.ClearAbility(pl.UserId);rebuildFleet(p);logistics:refresh(p);scene.applyWalkSpeed(p)
  p.player:SetAttribute('MA_DroneReward',Http:JSONEncode(result))
 end)
end
local packDelivery=PackDelivery.new({
 root=root, players=Players, getClock=function() return now end, home=home, station=scene.packStation, healthy=healthy,
 inAssault=activeAssault, characterRoot=characterRoot,
 requireGround=scene.runStart~=nil and root:GetAttribute('EditableMap')==true,
 groundHeight=function(x,z) return logisticsTerrain:surface(x,z) end,
 offer=function(p) return data(p).run.pendingOffer end,
 open=function(p,id,outcome)
  if not transact(p,'open:'..id,function(copy)
   local ok,result=Ca.open(copy,id)
   if ok then return result end
   return nil,result
  end,nil,outcome) then outcome('rejected') end
 end,
})
local packPrompt=scene.packStation:FindFirstChildWhichIsA('ProximityPrompt')
local function economyAction(p: any,pl: any,action: string,payload: any,previewCounter: BasePart?): boolean
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then
  if action=='ChooseCard' then offerReply(pl,payload,'rejected','Run changed or assault active') end
  return false
 end
 if action=='ChooseCard' and not atStation(p,scene.packStation,24) then
  notice(p,'Return to the Pack Counter to choose your upgrade.')
  if action=='ChooseCard' then offerReply(pl,payload,'rejected','Return to the depot') end
  return false
 end
 if action=='BuyPack' then
  if not R.finite(payload.packIndex) or payload.packIndex%1~=0 then return false end
  local station=previewCounter or scene.packStation
  if not atStation(p,station,previewCounter and 8 or 12) then return false end
  local function buyCard(copy: any): (any, any)
   local options: any={expectedPackIndex=payload.packIndex,atDepot=true,activeEncounter=false,crystalRun=scene.runStart~=nil,legendaryPreview=previewCounter~=nil and inStudio}
   local ok: boolean,result: any=Ca.buy(copy,payload.txId,payload.runId,options)
   if ok then return result end
   return nil,result
  end
  local origin=characterRoot(p).Position
  transact(p,'buy:'..payload.txId,buyCard,function()
   local buyer=characterRoot(p)
   local position=buyer and (buyer.Position-station.Position).Magnitude<12 and buyer.Position or origin
   packDelivery:spawn(p,data(p).run.pendingOffer,position,now,previewCounter)
  end)
 elseif action=='ChooseCard' then
  chooseCard(p,pl,payload)
 else
  executePrestige(p,pl,payload)
 end
 return true
end
if packPrompt then packPrompt.Triggered:Connect(function(pl)
 local p=profiles[pl.UserId]
 if not healthy(p) or p.player~=pl or not atStation(p,scene.packStation,12) or activeAssault(p) or now<(p.nextPackPress or 0) then return end
 p.nextPackPress=now+.45
 local run=data(p).run
 local offer=run.pendingOffer
 if offer then
  if offer.opened~=false then pl:SetAttribute('MA_ShowOffer',Http:GenerateGUID(false))
  else packDelivery:spawn(p,offer,characterRoot(p).Position,now);notice(p,'Open your delivered pack beside the counter.') end
  return
 end
 economyAction(p,pl,'BuyPack',{txId=Http:GenerateGUID(false),runId=run.id,packIndex=run.packIndex})
end) end
do
 local stand=scene.map:FindFirstChild('LegendaryPreviewStand')
 local counter=stand and stand:FindFirstChild('Counter')
 if stand and not inStudio then stand:Destroy()
 elseif counter and counter:IsA('BasePart') then
  local prompt=Instance.new('ProximityPrompt')
  prompt.Name='LegendaryPreviewPrompt';prompt.ActionText='Get free pack';prompt.ObjectText='Legendary Preview'
  prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
  prompt.MaxActivationDistance=8;prompt.RequiresLineOfSight=false;prompt.Parent=counter
  prompt.Triggered:Connect(function(pl)
   local p=profiles[pl.UserId]
   if not healthy(p) or p.player~=pl or not atStation(p,counter,8) or activeAssault(p) or now<(p.nextPackPress or 0) then return end
   p.nextPackPress=now+.45
   local run=data(p).run
   if run.pendingOffer then
    if run.pendingOffer.opened~=false then pl:SetAttribute('MA_ShowOffer',Http:GenerateGUID(false))
    else notice(p,'Open your waiting crate first.') end
    return
   end
   economyAction(p,pl,'BuyPack',{txId=Http:GenerateGUID(false),runId=run.id,packIndex=run.packIndex},counter)
  end)
 end
end
local function abilityContext(p,fieldId,operator,deployment)
 local function valid(id)
  local field=scene.patchById[id];local hr=characterRoot(p)
  return healthy(p) and hr~=nil and field~=nil and not activeAssault(p) and playerCanMine(p,field) and nearMiningField(hr.Position,field)
 end
 local state=deployment and deployment.state or p.ability
 local active=state and (state.burn or state.charge or state.swarm)
 local actor=operator or (active and active.actorId and drones[active.actorId])
 if not actor and not (active and active.actorId) then
  for _,d in ipairs(p.drones) do if d.hp>0 and (DroneRoles.isWorker(d.role) or DroneRoles.ability(d.role)) then actor=d;break end end
 end
 local hr=characterRoot(p);local origin=actor and actor.pos or (hr and hr.Position or home)
 if deployment then
  origin=deployment.position+Vector3.new(0,1,0)
  if deployment.temporary then actor={id=tostring(p.player.UserId)..':drop-gadget',owner=p.player.UserId,hp=1,life=1,role='Striker',pos=origin,
   owned={type='Blue'},stats={yieldMultiplier=1,geodeMultiplier=1,miningDPS=0}} end
 end
 local function unlocked(kind)
  if deployment then return kind==deployment.kind end
  if Shops.abilityUnlocked(data(p),kind) then return true end
  for _,d in ipairs(p.drones) do if d.hp>0 and DroneRoles.ability(d.role)==kind then return true end end
  return false
 end
 local function targetRecord(r)
  if not r or r.openReady or r.openingAt or r.geodeRejectedOwner==p.player.UserId or r.paid or r.hp<=0 or now<r.readyAt or not r.part.Parent then return nil end
  if r.field.cfg.SelectionOnly and not deployment and (not p.miningSquare or not scene.rockInSquare(p.miningSquare,r)) then return nil end
  if not deployment and actor and not sameRockType(actor,r) then return nil end
  if deployment then
   local offset=r.position-deployment.position;local radius=Consumables.ITEMS[deployment.kind].radius
   if offset.X*offset.X+offset.Z*offset.Z>radius*radius then return nil end
  end
  for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=p.player.UserId then return nil end end
  -- Gadgets survey the current health-scaled body and actual cut height.
  local top=select(2,Feel.groundedRockFrame(r.position,r.part.Size,r.part:GetAttribute('GroundY'),r.stage,r.stageSeed,r.part:GetAttribute('CubicRock')==false,r.referenceCrystal,r.steady,r.variedPose))
  local click=deployment and deployment.kind=='Orbital' and deployment.targetId==r.id and deployment.position or r.position
  return {id=r.id,hp=r.hp,maxHP=r.maxHP,ground=r.part:GetAttribute('GroundY'),radius=math.max(.1,r.part.Size.X*.5),x=click.X,y=top,z=click.Z}
 end
 return {runId=data(p).run.id,fieldId=fieldId,origin={x=origin.X,y=origin.Y,z=origin.Z},
  orbiter=not deployment and actor and actor.role=='Orbiter' and scene.runStart~=nil,
  placement=deployment and {x=origin.X,y=origin.Y,z=origin.Z},selectedId=deployment and deployment.targetId,perks=deployment and {scrapBots=2} or Ca.abilityPerks(data(p)),unlocked=unlocked,
  valid=function(id) return actor~=nil and actor.hp>0 and actor.owner==p.player.UserId and valid(id) end,
  full=function() return false end,
  -- During a burn inspect only its fixed target. The normal ctx.hit path still
  -- performs a fresh authoritative obstruction query before every damage tick.
  target=function(id,field)
   local r=resources[id]
   if valid(field) and r and r.field.id==field then return targetRecord(r) end
   return nil
  end,
  targets=function(id,kind)
   local list={};if not valid(id) then return list end
   for _,r in ipairs(scene.patchById[id].resources) do
    local target=targetRecord(r)
    if target then
     -- Survey the same vertical path that the authoritative orbital hit uses.
     -- A taller blocked crystal must not starve reachable work forever. Tiny
     -- scrap miners keep their normal nearby target list and contact checks.
     if kind~='Orbital' or abilityLineOfSight(p,Vector3.new(target.x,target.y+DroneAbilities.ORBITAL_ORIGIN_HEIGHT,target.z),r) then
      table.insert(list,target)
     end
    end
   end
   return list
  end,
  hit=function(id,damage,_kind,from)
   local resource=resources[id]
   if not resource or not actor or actor.hp<=0 or not valid(resource.field.id) or type(from)~='table' or not targetRecord(resource) then return false end
   if not R.finite(from.x) or not R.finite(from.y) or not R.finite(from.z) then return false end
   local accepted=hitResource(actor,resource,math.min(damage,resource.maxHP+10),false,nil,Vector3.new(from.x,from.y,from.z),deployment and 'Consumable' or nil,_kind=='Orbital' and {toolKind='Melt',point=Vector3.new(from.x,resource.part.Position.Y,from.z),noScar=scene.runStart~=nil and actor.role=='Orbiter'} or nil)
   if accepted and not scene.runStart then scene.hazards:beam(Vector3.new(from.x,from.y,from.z),resource.part.Position,7,'laser') end
   if accepted and deployment and deployment.finishTemporary then
    deployment.finishTemporary(true);deployment.finishTemporary=nil
   end
   if accepted and deployment and not deployment.temporary and Consumables.accept(data(p).consumables) then p.dirty=true;p.publishDirty=true end
   return accepted,resource.paid==true
  end,
  emit=function(event) RoleEffects.Ability(deployment and (tostring(p.player.UserId)..':tool') or p.player.UserId,event,scene.droneTemplate) end}
end
-- The Crystal Run game uses the drone workflow. Legacy fixtures still load
-- the equipment services, and stored inventory stays valid for old saves.
if not scene.runStart then
 consumableService=ConsumableService.new({data=data,healthy=healthy,saveHealthy=function(p) return store:healthy(p.session) end,
  notice=notice,transact=transact,abilities=DroneAbilities,effects=RoleEffects,root=root,now=function() return now end,
  context=function(p,record) return abilityContext(p,record.fieldId,nil,record) end,
  placement=function(p,payload)
   if not R.finite(payload.fieldId) or payload.fieldId%1~=0 or not R.finite(payload.x) or not R.finite(payload.z)
    or math.abs(payload.x)>100000 or math.abs(payload.z)>100000 then return nil,'Choose a position inside a mining field' end
   local field=scene.patchById[payload.fieldId];local hr=characterRoot(p)
   if not field or not hr or activeAssault(p) or not playerCanMine(p,field) or not nearMiningField(hr.Position,field) then return nil,'Use tools beside an unlocked, unguarded field' end
   local localPoint=field.part.CFrame:PointToObjectSpace(Vector3.new(payload.x,field.center.Y,payload.z))
   if math.abs(localPoint.X)>field.part.Size.X*.5 or math.abs(localPoint.Z)>field.part.Size.Z*.5 then return nil,'Place the tool inside the field' end
   local ground=field.part.CFrame:PointToWorldSpace(Vector3.new(localPoint.X,field.part.Size.Y*.5,localPoint.Z))
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
   params.FilterDescendantsInstances={field.part,workspace.Terrain}
   local surface=workspace:Raycast(ground+Vector3.new(0,40,0),Vector3.new(0,-80,0),params)
   if surface then ground=surface.Position end
   if (hr.Position-ground).Magnitude>60 or not los(hr.Position,ground+Vector3.new(0,1.5,0),field.part,{droneFolder,p.player.Character}) then return nil,'Move closer to a clear placement spot' end
   return ground
  end})
 scene.toolRandom=Random.new()
 scene.fieldTools=ToolRules.Service.new({world=root,players=profiles,resources=resources,debris=Debris,healthy=healthy,
  root=characterRoot,run=function(p) return data(p).run.id end,encode=function(v) return Http:JSONEncode(v) end,
  now=function() return now end,random=function() return scene.toolRandom:NextNumber() end,notice=notice,hazards=scene.hazards,
  stock=function(p,kind) return data(p).consumables.counts[kind] or 0 end,
  eligible=function(p,r,position)
   if now<r.readyAt or not playerCanMine(p,r.field) or not nearMiningField(position,r.field) or activeAssault(p) then return false end
   for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=p.player.UserId then return false end end
   return true
  end,
  gadget=function(p,item,target,point)
   if not item.saved then
    return consumableService:drop(p,item.kind,target,point,function(used) scene.fieldTools:finishGadget(p,item,used) end)
   end
   local profile=data(p)
   return consumableService:command(p,{kind=item.kind,runId=profile.run.id,version=profile.consumables.version,txId=Http:GenerateGUID(false),fieldId=target.field.id},point,target.id)
  end,
  clear=function(from,to,character,target) return los(from,to,target,{droneFolder,character}) end,
  cast=function(from,to,radius,character)
   if (to-from).Magnitude<1e-6 then return nil end
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
   params.FilterDescendantsInstances={droneFolder,character,root.FieldTools,root.ToolImpacts}
   if radius==0 then return workspace:Raycast(from,to-from,params) end
   return workspace:Spherecast(from,radius,to-from,params)
  end,
  hit=function(p,r,amount,origin,kind,point)
   -- Equipment works without borrowing a live drone or changing its orders.
   local actor={id=tostring(p.player.UserId)..':field-tool',owner=p.player.UserId,hp=1,life=1,role='Striker',pos=origin,
    owned={type='Blue'},stats={yieldMultiplier=1,geodeMultiplier=1,miningDPS=0}}
   return hitResource(actor,r,amount,false,nil,origin,'FieldTool',{consumable=true,toolKind=kind,point=point})
  end})
end
do
 local function finishAbility(p,token,context)
  local charge=p.ability.charge
  local ok,reason=DroneAbilities.confirm(p.ability,token,now,context)
  if ok then
   if p.ability.swarm and charge then p.ability.swarm.actorId=charge.actorId end
   data(p).run.abilityCooldowns=Pro.clone(p.ability.cooldowns);p.dirty=true
  end
  p.publishDirty=true;return ok,reason
 end
 roleAbilityStep=function(d,p,hr,dt)
  d.mining=false
  local kind=DroneRoles.ability(d.role);local field=workingField(p,hr)
  if scene.runStart and kind=='Orbital' and not p.miningSquare then followRole(d,p,hr,dt);return end
  if not field or field.junk then followRole(d,p,hr,dt);return end
  p.ability=p.ability or DroneAbilities.new(data(p).run.abilityCooldowns,data(p).run.id)
  local ability=p.ability;local charge=ability.charge
  if now<(ability.cooldowns[kind] or 0) and not (charge and charge.actorId==d.id)
   and not (kind=='Orbital' and ability.burn and ability.burn.actorId==d.id)
   and not (kind=='Scrap' and ability.swarm and ability.swarm.actorId==d.id) then
   followRole(d,p,hr,dt,kind=='Orbital' and 'OrbitalCool' or 'SwarmCool');return
  end
  local context=abilityContext(p,field.id,d)
  if charge and charge.actorId==d.id then
   d.state=kind=='Orbital' and 'OrbitalCharge' or 'SwarmDeploy'
   if now>=charge.readyAt then finishAbility(p,charge.token,context) end
  elseif kind=='Orbital' and ability.burn and ability.burn.actorId==d.id then d.state='OrbitalBurn'
  elseif kind=='Scrap' and ability.swarm and ability.swarm.actorId==d.id then d.state='SwarmActive'
  elseif now<(ability.cooldowns[kind] or 0) then d.state=kind=='Orbital' and 'OrbitalCool' or 'SwarmCool'
  else d.state=kind=='Orbital' and 'OrbitalSurvey' or 'SwarmReady' end
  local goal
  if kind=='Orbital' then
   local target=ability.burn and ability.burn.actorId==d.id and resources[ability.burn.targetId] or (charge and charge.actorId==d.id and resources[charge.targetId]) or nil
   if not target and (d.surveyField~=field.id or now>=(d.nextSurveyAt or 0)) then
    d.surveyField=field.id;d.nextSurveyAt=now+C.Snapshot;d.surveyTargetId=nil
    local largest=-1
    for _,node in ipairs(context.targets(field.id,'Orbital')) do
     if node.maxHP>largest or node.maxHP==largest and node.id<target.id then target=resources[node.id];largest=node.maxHP end
    end
    d.surveyTargetId=target and target.id or nil
   end
   if not target then target=d.surveyTargetId and resources[d.surveyTargetId] end
   if target and (target.paid or target.hp<=0 or not target.part.Parent) then target=nil end
   goal=target and target.position+Vector3.new(0,math.max(12,target.fullSize.Y*.5+7),0) or hr.Position+Vector3.new(4,10,0)
  else goal=hr.Position+Vector3.new(4,4,-3) end
  move(d,goal,dt)
  -- Hardware performs the normal server gadget, sharing its saved cooldown and
  -- completing its charge automatically without a timing minigame.
  if not ability.charge and not (kind=='Orbital' and ability.burn) and not (kind=='Scrap' and ability.swarm) and now>=(ability.cooldowns[kind] or 0) and (d.pos-goal).Magnitude<1 then
   if kind=='Orbital' then
    if not d.surveyTargetId then return end
    context.selectedId=d.surveyTargetId
   end
   local ok=DroneAbilities.begin(ability,kind,now,context)
   if ok then ability.charge.actorId=d.id;ability.charge.automatic=true;p.publishDirty=true end
  end
 end
end
local function miningAbility(p,payload)
 if type(payload)~='table' or payload.runId~=data(p).run.id or (payload.kind~='Orbital' and payload.kind~='Scrap') or not R.finite(payload.fieldId) or payload.fieldId%1~=0 or not scene.patchById[payload.fieldId] then return end
 if payload.op~='begin' then return end
 p.ability=p.ability or DroneAbilities.new(data(p).run.abilityCooldowns,data(p).run.id)
 local context=abilityContext(p,payload.fieldId)
 local ok,reason=DroneAbilities.begin(p.ability,payload.kind,now,context)
 if ok then data(p).run.abilityCooldowns=Pro.clone(p.ability.cooldowns);p.dirty=true end
 notice(p,reason);p.publishDirty=true
end
local function buyShopUpgrade(p,pl,payload)
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then return end
 if not atStation(p,shopStations.Quartz,15) then notice(p,'Visit the Quartz Workshop.');return end
 transact(p,'shop:'..payload.txId,function(copy)
  local ok,result=Ca.upgrade(copy,payload.upgradeId,payload.level,payload.txId,payload.runId,{atDepot=true,activeEncounter=false})
  if ok then return result end;return nil,result
 end,function(result) refreshStats(p);notice(p,result.title..' · '..result.level..'×');p.publishDirty=true end)
end
function scene.buyStarUpgrade(p,payload)
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then return end
 if not atStation(p,shopStations.Ruby,12) then notice(p,'Visit the Star Shop.');return end
 transact(p,'stars:'..payload.txId,function(copy)
  local ok,result=Pro.buyStarUpgrade(copy,payload.upgradeId,payload.level,payload.txId,payload.runId)
  if ok then return result end;return nil,result
 end,function(result)
  scene.syncRuntimeFleet(p)
  if result.id=='selector' and p.miningSquare and not p.miningSquare.field.cfg.WholeField then
   local width=Workshop.selectorWidth(data(p))
   -- Keep the pin object so active cuts, deliveries and press jobs stay attached.
   p.miningSquare.half=width*.5
   scene.publishSquareStatus(p)
   p.player:SetAttribute('MA_SelectorWidth',width)
  end
  scene.applyWalkSpeed(p);notice(p,result.title..' · '..result.level..'×');p.publishDirty=true
 end)
end
function scene.moveSquareWork(p,current,square)
 if not current then return end
 -- A new destination can redirect an unfinished flight from the depot.
 for _,d in ipairs(p.drones) do
  if d.chargedPin==current then d.chargedPin=square end
 end
 local sameField=current.field==square.field
 local press=p.compactor
 if press and press.pressJob and not press.pressJob.startedAt then scene.resetPress(press,true) end
 if not sameField then return end
 local function staysInSquare(r)
  return r and not r.paid and r.part.Parent
   and scene.rockInSquare(square,r)
 end
 for _,r in ipairs(square.field.resources) do
  if r.lastPin==current and r.lastPinOwner==p.player.UserId and staysInSquare(r) then r.lastPin=square end
 end

end
-- Walking onto a square field puts the crew to work there; no click needed.
-- After a recall, the same field waits until the player leaves and returns.
function scene.autoField(p)
 if not scene.flatFields or now<(p.autoFieldAt or 0) or not healthy(p) then return end
 p.autoFieldAt=now+.4
 local hr=characterRoot(p);if not hr then return end
 local inside
 for _,field in ipairs(patches) do
  if field.cfg.WholeField and field.cfg.SelectionOnly then
   local point=field.part.CFrame:PointToObjectSpace(hr.Position)
   if math.abs(point.X)<=field.part.Size.X*.5 and math.abs(point.Z)<=field.part.Size.Z*.5 and point.Y>-2 and point.Y<12 then inside=field;break end
  end
 end
 if not inside then p.autoFieldSeen=nil;return end
 if p.autoFieldSeen==inside then return end
 p.autoFieldSeen=inside
 if p.miningSquare and p.miningSquare.field==inside then return end
 if activeAssault(p) or not playerCanMine(p,inside) then return end
 scene.placeSquare(p,{runId=data(p).run.id,fieldId=inside.id,position=inside.part.Position+Vector3.yAxis*inside.part.Size.Y*.5})
end
function scene.placeSquare(p,payload)
 if type(payload)~='table' or payload.runId~=data(p).run.id or not R.finite(payload.fieldId) or typeof(payload.position)~='Vector3' then
  commandReply(p.player,payload,'rejected','Field selection is unavailable.');return
 end
 local field=scene.patchById[payload.fieldId]
 if not field or not field.cfg.SelectionOnly then
  commandReply(p.player,payload,'rejected','Select a spot on the mining bed.');return
 end
 if activeAssault(p) then
  commandReply(p.player,payload,'rejected','Recall fighting drones before selecting an area.');return
 end
 local position=payload.position
 if not R.finite(position.X) or not R.finite(position.Z) then return end
 local part=field.part
 local center,fieldWidth=Mining.fieldSelection(position,part)
 if not center then commandReply(p.player,payload,'rejected','Select a spot on the mining bed.');return end
 local hr=characterRoot(p)
 local square={field=field,center=center,half=(fieldWidth or Workshop.selectorWidth(data(p)))*.5,placedAt=now}
 if not hr or not scene.squareInRange(hr.Position,square) then
  commandReply(p.player,payload,'rejected','Move closer to select that area.');return
 end
 local leadId=not fieldWidth and payload.leadId or nil
 local lead=type(leadId)=='string' and #leadId<=128 and resources[leadId]
 if lead and not lead.openReady and not lead.paid and not lead.cargoProduced and lead.hp>0 and lead.part.Parent and now>=lead.readyAt
  and scene.rockInSquare(square,lead) then
  if not next(lead.slots) then square.leadId=leadId;square.focusId=leadId
  else
   for id in pairs(lead.slots) do
    local worker=drones[id]
    if worker and worker.owner==p.player.UserId and worker.target==lead then square.focusId=leadId;break end
   end
  end
 end
 local current=p.miningSquare
 local samePin=current and current.field==field and current.half==square.half and (current.center-center).Magnitude==0
 if samePin and leadId~=nil and not square.focusId then
  commandReply(p.player,payload,'accepted');return
 end
 -- This is a command to the fleet within a validated bed and walking range.
 -- Mining itself still checks the worker's contact path and target ownership.
 if samePin then
  current.directId=nil -- Confirming the plot restores automatic crew assignment.
  current.leadId=square.leadId;current.focusId=square.focusId
  scene.publishSquareFocus(p,current)
  commandReply(p.player,payload,'accepted');return
 end
 scene.moveSquareWork(p,current,square)
 for _,d in ipairs(p.drones) do
  if d.hp<=0 or d.carrierId then continue end
  if current and d.squareJob==current and d.target and not d.target.paid and scene.rockInSquare(square,d.target) then
   d.squareJob=square
   continue
  end
  d.thinkPosition=d.pos;d.thinkUntil=now+seed:NextInteger(8,26)*.01
  if DroneRoles.isWorker(d.role) then
   if d.target or d.lingerUntil or d.breaker then scene.releaseSquareApproach(d) end
   d.field=nil;d.autoField=nil;d.squareSearchAt=nil
  elseif d.role=='Compactor' then
   d.pressSearchAt=nil
  elseif d.role=='Courier' and d.orePickupId and not d.oreDock then
   local drop=pickups[d.orePickupId]
   if drop and drop.courier==d then drop.courier=nil end
   d.orePickupId=nil
  end
 end
 p.previousSquare=p.previousSquare or current
 p.oreQueue={};p.workField=field.id;p.miningSquare=square
 scene.publishSquareStatus(p)
 p.player:SetAttribute('MA_SelectorField',field.id)
 p.player:SetAttribute('MA_SelectorWidth',square.half*2)
 p.player:SetAttribute('MA_Selector',center)
 commandReply(p.player,payload,'accepted')
end
-- Ready rewards are claimed by the mining owner/run. No remote supplies damage or payout.
function scene.releaseOpenWorkers(r)
 local workers={};for id in pairs(r.slots) do workers[#workers+1]=drones[id] end
 for _,worker in ipairs(workers) do if worker and worker.target==r then release(worker);worker.squareSearchAt=nil end end
end
-- Crew abilities: rock breaks fill one button per drone type; a full button fires.
do
 local fx=Instance.new('RemoteEvent');fx.Name='CrewFX';fx.Parent=net
 scene.crewFX=fx
end
function scene.crewRoles(p)
 local roles={}
 for _,d in ipairs(p.drones) do if DroneRoles.isWorker(d.role) then table.insert(roles,d.role) end end
 return roles
end
function scene.crewBreak(owner)
 local p=profiles[owner];if not p or not p.crew then return end
 CrewAbilities.onBreak(p.crew,scene.crewRoles(p))
end
function scene.crewRockOpen(p,r,square)
 if r.paid or r.hp<=0 or r.openReady or r.openingAt or r.kind=='Geode' or not r.part.Parent or now<r.readyAt then return false end
 if square and not scene.rockInSquare(square,r) then return false end
 for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=p.player.UserId then return false end end
 return true
end
function scene.crewAbility(p,payload)
 if type(payload)~='table' or type(payload.role)~='string' or #payload.role>24 or payload.runId~=data(p).run.id then return end
 local square=p.miningSquare
 local hr=characterRoot(p)
 if not square or not hr or activeAssault(p) or p.busy then notice(p,'Walk onto a field first.');return end
 local role=CrewAbilities.role(payload.role)
 local entry=CrewAbilities.ROLES[role];if not entry then return end
 local center
 if entry.kind=='Shockwave' then
  local focus=square.focusId and resources[square.focusId]
  if focus and scene.crewRockOpen(p,focus,square) then center=focus.position end
  if not center then
   local best=math.huge
   for _,r in ipairs(square.field.resources) do
    if scene.crewRockOpen(p,r,square) then
     local distance=(r.position-hr.Position).Magnitude
     if distance<best then best=distance;center=r.position end
    end
   end
  end
  if not center then notice(p,'No rocks here to blast.');return end
 end
 if entry.kind=='Barrage' then
  local any=false
  for _,r in ipairs(square.field.resources) do if scene.crewRockOpen(p,r,square) then any=true;break end end
  if not any then notice(p,'No rocks here to blast.');return end
 end
 local ok,_,kind=CrewAbilities.trigger(p.crew,role,scene.crewRoles(p),now)
 if not ok then notice(p,tostring(_));return end
 local color=Color3.fromRGB(table.unpack(entry.color))
 local owner=p.player.UserId
 local open={}
 for _,r in ipairs(square.field.resources) do if scene.crewRockOpen(p,r,square) then table.insert(open,r) end end
 local power=0
 local shooters={}
 for _,d in ipairs(p.drones) do
  if CrewAbilities.role(d.role)==role and d.hp>0 then
   power+=d.stats.miningDPS or 0
   table.insert(shooters,{id=d.id,position=d.pos,power=d.stats.miningDPS or 0})
  end
 end
 p.crewHits=p.crewHits or {}
 if entry.kind=='Barrage' then
  -- Every drone of this type fires one big shot at its own rock, in turn.
  local shots={}
  for i,pair in ipairs(CrewAbilities.barragePairs(open,shooters)) do
   local at=now+kind.lead+(i-1)*kind.stagger
   local shotPower=pair.shooter.power
   table.insert(p.crewHits,{at=at,rock=pair.rock,kind='Barrage',damage=function(r) return CrewAbilities.shotDamage(shotPower,r.hp) end})
   table.insert(shots,{drone=pair.shooter.id,position=pair.rock.position,at=at})
  end
  scene.crewFX:FireAllClients({kind='Barrage',role=role,name=entry.name,owner=owner,color=color,shots=shots,at=now})
 else
  local targets=CrewAbilities.shockTargets(open,center,kind.radius)
  scene.crewFX:FireAllClients({kind='Shockwave',role=role,name=entry.name,owner=owner,color=color,position=center,radius=kind.radius,at=now,impact=kind.impact})
  for _,r in ipairs(targets) do
   table.insert(p.crewHits,{at=now+kind.impact,rock=r,kind='Shockwave',damage=function(rock) return CrewAbilities.shockDamage(power,rock.hp,rock.maxHP) end})
  end
 end
 p.lastCrewJSON=nil
 commandReply(p.player,payload,'accepted')
end
function scene.crewStep(p)
 local hits=p.crewHits
 if not hits or #hits==0 then return end
 local owner=p.player.UserId
 local index=1
 while index<=#hits do
  local hit=hits[index]
  if now<hit.at then index+=1;continue end
  table.remove(hits,index)
  local r=hit.rock
  if healthy(p) and scene.crewRockOpen(p,r,nil) then
   local amount=hit.damage(r)
   if amount>0 then
    local origin=r.position+Vector3.yAxis*7
    local actor={id=tostring(owner)..':crew-ability',owner=owner,hp=1,life=1,role='Striker',pos=origin,
     owned={type='Blue'},stats={yieldMultiplier=1,geodeMultiplier=1,miningDPS=0}}
    hitResource(actor,r,amount,false,nil,origin,'FieldTool',{consumable=true,toolKind=hit.kind,point=r.position})
   end
  end
 end
end
function scene.focusResource(p,payload)
 if type(payload)~='table' or payload.runId~=data(p).run.id then return end
 local square=p.miningSquare
 local r=type(payload.resourceId)=='string' and resources[payload.resourceId]
 local hr=characterRoot(p)
 if not square or not r or r.paid or r.openReady or r.openingAt or now<r.readyAt or not r.part.Parent
  or not hr or not scene.squareInRange(hr.Position,square) or not scene.rockInSquare(square,r) or not playerCanMine(p,r.field) then
  commandReply(p.player,payload,'rejected','Select a nearby area containing an available rock.');return
 end
 for id in pairs(r.slots) do if drones[id] and drones[id].owner~=p.player.UserId then
  commandReply(p.player,payload,'rejected','Another crew is mining that rock.');return
 end end
 local newAttempt=square.directId~=r.id or r.geodeRejectedOwner==p.player.UserId
 if r.geodeRejectedOwner==p.player.UserId then r.geodeRejectedOwner=nil end
 if newAttempt and r.kind=='Geode' and not r.geodePassed then
  -- Bound assembly time; repeated clicks cannot postpone the power check.
  r.geodeRallyUntil=now+Mining.GEODE_RALLY_TIME
  if r.geodeTestAt then r.geodeTestAt=r.geodeRallyUntil;r.geodeTestDamage=0 end
 end
 square.directId=r.id;square.focusId=r.id
 for _,d in ipairs(p.drones) do
  if DroneRoles.isWorker(d.role) and not d.carrierId and d.target~=r then
   release(d);d.field=nil;d.autoField=nil;d.squareSearchAt=nil;d.thinkPosition=d.pos;d.thinkUntil=now+.045*(d.slot%5)
  end
 end
 scene.publishSquareFocus(p,square)
 commandReply(p.player,payload,'accepted')
end
-- A sealed discovery has its own identity and never occupies a mining/respawn slot.
function scene.leaveGeode(d,rock,specialist)
 local p=profiles[d.owner];if not healthy(p) then return end
 local bed=rock.field.part
 local localPoint=bed.CFrame:PointToObjectSpace(rock.position)+Vector3.new(3.5,0,3.5)
 localPoint=Vector3.new(math.clamp(localPoint.X,-bed.Size.X*.5+1.5,bed.Size.X*.5-1.5),0,
  math.clamp(localPoint.Z,-bed.Size.Z*.5+1.5,bed.Size.Z*.5-1.5))
 local r=makeResource(rock.field,bed.CFrame:PointToWorldSpace(localPoint),'Crystal',11,rock.ore,1.8,3,nil,nil,{cut=rock.part:GetAttribute('CrystalCut') or 'Original'})
 r.kind='Geode';r.referenceCrystal=false;r.part:SetAttribute('Kind','Geode');r.part:SetAttribute('ReferenceCrystal',false)
 r.sealedDrop=true;r.gemReward=true;r.openReady=true;r.openOwner=d.owner;r.openRun=data(p).run.id
 r.openActor={owner=d.owner,role=d.role,stats=Pro.clone(d.stats)};r.openSpecialist=specialist
 r.readyAt=now+.75;r.spawnAt=now-2;r.hp=1;r.consumableWorked=rock.consumableWorked
 -- Roll once on the server; do not replicate the contents before opening.
 local tierIndex,tier=Mining.rollGeodeTier(math.random())
 r.geodeTier=tierIndex;r.rewardCount=tier.gems
 r.modifiers=bit32.bor(rock.modifiers or 0,tier.modifiers)
 r.part.Color=Color3.fromRGB(76,67,58);r.part.Material=Enum.Material.Slate
 r.part:SetAttribute('SealedDrop',true);r.part:SetAttribute('OpenReady',true)
 r.part:SetAttribute('TierHint',math.max(1,(r.geodeTier or 1)-1))
 r.part:SetAttribute('OpenOwner',d.owner);r.part:SetAttribute('OpenReadyAt',now)
 r.part:SetAttribute('SpawnAt',r.spawnAt);r.part:SetAttribute('ReadyAt',r.readyAt)
 r.part:SetAttribute('DropFrom',rock.part.Position);r.part:SetAttribute('DropAt',now);r.part:SetAttribute('DropLandsAt',r.readyAt)
 r.part:SetAttribute('HP',1);r.part:SetAttribute('CrackProgress',0)
 return r
end
function scene.openResource(p,payload)
 if type(payload)~='table' or payload.runId~=data(p).run.id then return end
 local r=type(payload.resourceId)=='string' and resources[payload.resourceId]
 local hr=characterRoot(p)
 if not r or not r.openReady or r.openingAt or r.paid or now<r.readyAt or not r.part.Parent or not hr
  or r.openOwner~=p.player.UserId or r.openRun~=data(p).run.id or not playerCanMine(p,r.field)
  or (hr.Position-r.position).Magnitude>Mining.OPEN_REACH or not abilityLineOfSight(p,hr.Position,r) then return end
 scene.startStrike(r)
end
-- One order: the owner's crew charges a combined strike, then the shell bursts.
function scene.startStrike(r)
 if r.sealedDrop then
  r.openingAt=now+Mining.STRIKE_CHARGE
  r.part:SetAttribute('StrikeAt',now)
 else
  r.openingAt=now+(r.kind=='Geode' and .85 or .24)
 end
 r.part:SetAttribute('OpeningAt',r.openingAt)
 r.part:SetAttribute('OpenReady',false)
end
function scene.stepGeode(r)
 if r.paid then return end
 if r.openReady then
  local p=profiles[r.openOwner]
  if not p or p.leaving or data(p).run.id~=r.openRun then
   -- Retire abandoned discoveries; their original rocks already replenished.
   r.paid=true;r.removeAt=now;r.part.CanQuery=false;r.part.CanCollide=false
   return
  end
  if not r.openingAt and r.sealedDrop and now>=r.readyAt and healthy(p) then
   local hr=characterRoot(p)
   if hr and (hr.Position-r.position).Magnitude<=Mining.STRIKE_PROXIMITY and playerCanMine(p,r.field) then
    scene.startStrike(r);r.part:SetAttribute('OpenReady',false)
   end
  end
  if r.openingAt and now>=r.openingAt and healthy(p) then
   r.paid=true;r.hp=0;r.manualOpened=true;r.removeAt=now+3
   r.splitAt=now
   r.part:SetAttribute('HP',0);r.part:SetAttribute('CrystalSplitAt',now);r.part:SetAttribute('CrystalBreakAt',now)
   r.part:SetAttribute('CrystalBreakOwner',r.openOwner);r.part:SetAttribute('BreakSerial',1)
   if r.geodeTier then r.part:SetAttribute('GeodeTier',r.geodeTier);r.part:SetAttribute('GeodeGems',r.rewardCount or 1) end
   r.part.CanQuery=false;r.part.CanCollide=false;r.part.CanTouch=false
   local count=r.rewardCount or 1
   for _=1,count do r.cargoProduced=nil;award(r.openActor,r,r.openSpecialist,false) end
   -- Discovery credit and the field vacancy belong to the original completed rock.

  end
  return
 end

end
local function commandPlayer(pl: any,action: any,payload: any)
 local p=profiles[pl.UserId];if not p or p.player~=pl then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerReply(pl,payload,'rejected','Fleet unavailable') end;return end
 if action=='ChooseCard' then
  local committed,conflict=committedOffer(p,payload)
  if committed then offerReply(pl,payload,'accepted','Card installed');return end
  if conflict then offerReply(pl,payload,'rejected','This install was already used');return end
 end
 local duration=math.max(0,now-p.bucketAt);p.tokens=math.min(7,p.tokens+duration*3);p.bucketAt=now
 if p.tokens<1 then if now>=(p.nextCommandRejection or 0) then p.nextCommandRejection=now+.35;commandReply(pl,payload,'rejected','Too many commands');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Too many commands') end end;return end;p.tokens=p.tokens-1
 if type(action)~='string' or #action>24 or not healthy(p) or not characterRoot(p) then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Fleet unavailable') end;return end
 if p.miningSquare and (action=='MineOre' or action=='Patch' or action=='AssignSlot' or action=='CancelDrone') then
  local reason='Recall your fleet before giving it a different kind of order.'
  notice(p,reason);commandReply(pl,payload,'rejected',reason);return
 end
 if action=='BuyDrone' then
  local kind=type(payload)=='table' and payload.droneType or payload
  if type(kind)~='string' or not DroneCatalog.Types[kind] then return end
  if not atHome(p) or activeAssault(p) then notice(p,'Visit the depot to buy a permanent miner.');return end
  if type(payload)=='table' and (not validPayload(payload) or payload.runId~=data(p).run.id) then return end
  local txId=type(payload)=='table' and payload.txId or Http:GenerateGUID(false)
  local runId=data(p).run.id
  transact(p,'drone:'..txId,function(copy)
   local ok,result=Pro.buyDrone(copy,kind,txId,runId,{atDepot=true,activeEncounter=false})
   if ok then return result end;return nil,result
  end,function(result)
   local owned
   for _,entry in ipairs(data(p).fleet) do if entry.id==result.droneId then owned=entry;break end end
   if owned and not drones[owned.id] then
    if p.testFleet then table.insert(p.testFleet,Pro.clone(owned)) end
    spawnDrone(p,owned,#p.drones+1)
   end
   logistics:refresh(p);notice(p,DroneCatalog.Types[kind].Name..' added to your permanent fleet.');p.publishDirty=true
  end)
 elseif action=='BuyCarrier' or action=='BuyBackpack' or action=='LoadCarrier' or action=='CarrierPatch' or action=='RecallCarrier' or action=='Deposit' or action=='LaunchStorage' or action=='AutoLaunch' then
  logistics:command(p,action,payload)
 elseif action=='MiningAbility' then
  miningAbility(p,payload)
 elseif action=='PlaceConsumable' then
  if consumableService then consumableService:command(p,payload) end
 elseif action=='EquipFieldTool' or action=='UseFieldTool' then
  if scene.fieldTools then scene.fieldTools:command(p,action,payload) end
 elseif action=='BuyUpgrade' then
  buyShopUpgrade(p,pl,payload)
 elseif action=='BuyStarUpgrade' then
  scene.buyStarUpgrade(p,payload)
 elseif action=='PlaceSelector' then
  scene.placeSquare(p,payload)
 elseif action=='FocusResource' then
  scene.focusResource(p,payload)
 elseif action=='CrewAbility' then
  scene.crewAbility(p,payload)
 elseif action=='DigOpen' then
  scene.digRequestOpen(p,payload)
 elseif action=='DigFocus' then
  local point=type(payload)=='table' and payload.point
  if typeof(point)=='Vector3' and scene.digInside(point,2) then
   p.digFocus=point;p.digFocusUntil=now+15
   for _,d in ipairs(p.drones) do scene.digDrop(d);d.digPickAt=0 end
  end
 elseif action=='OpenResource' then
  scene.openResource(p,payload)
 elseif action=='PickupOre' then
  scene.requestOrePickup(p,payload)
 elseif action=='DevFillBag' then
  if not RunService:IsStudio() then return end
  local field=p.workField and scene.patchById[p.workField] or patches[1]
  local material=field.cfg.Material or field.cfg.Key or 'Quartz'
  local added=Pro.addCargo(data(p),material,math.max(0,Ca.capacity(data(p),previewPerks(p))-Pro.cargoUnits(data(p))),Ca.capacity(data(p),previewPerks(p)))
  if added>0 then p.dirty=true;p.publishDirty=true end
 elseif action=='DevAddDrone' then
  if not RunService:IsStudio() or type(payload)~='table' or type(payload.role)~='string' then return end
  local role=RoleConfig.StudioRoles[payload.role]
  if not role or #p.drones>=24 then return end
  p.testFleet=p.testFleet or Pro.clone(data(p).fleet)
  p.testRoll=(p.testRoll or 0)+1
  local owned={id=string.format('test:%d:add:%d',pl.UserId,p.testRoll),type=payload.role,role=payload.role,name=RoleConfig.Types[payload.role].DisplayName,flightHeight=role.height,base=Pro.clone(role.base)}
  table.insert(p.testFleet,owned)
  local d=spawnDrone(p,owned,#p.drones+1);snapshotDrone(d)
  pl:SetAttribute('MA_TestLoadoutLabel',tostring(#p.testFleet)..' preview drones')
  refreshStats(p);p.publishDirty=true
 elseif action=='NormalLoadout' then
  if not preview then return end
  leaveField(p);RoleEffects.ClearAbility(pl.UserId);p.ability=nil;p.testFleet=nil;rebuildFleet(p);logistics:refresh(p)
  notice(p,'Using your usual crew.');p.publishDirty=true
 elseif action=='TestLoadout' or action=='RoleLoadout' then
  if not preview or now<(p.nextTestLoadout or 0) then return end
  p.nextTestLoadout=now+RoleConfig.Settings.RandomizeCooldown;pl:SetAttribute('MA_TestReadyAt',p.nextTestLoadout)
  leaveField(p)
  for _,carrier in ipairs(data(p).logistics.carriers) do logistics:command(p,'RecallCarrier',carrier.id) end
  RoleEffects.ClearAbility(pl.UserId);p.ability=nil;p.testFleet=action=='RoleLoadout' and roleTestFleet(p) or randomTestFleet(p);rebuildFleet(p);logistics:refresh(p)
  notice(p,action=='RoleLoadout' and 'All drone types ready. Click a rock to start mining.' or 'Random test loadout ready — no saved fleet changed.')
 elseif action=='Recall' then
  leaveField(p)
  for _,carrier in ipairs(data(p).logistics.carriers) do logistics:command(p,'RecallCarrier',carrier.id) end
  scene.recallCue(p,false)
  notice(p,'Orders cleared. Your backpack stays with you.');commandReply(pl,payload,'recalled','Orders cleared')
 elseif action=='Evade' then
  if now<(p.nextEvade or 0) then return end;p.nextEvade=now+2
  for _,d in ipairs(p.drones) do if d.field and R.participates(scene.patchById[d.field].e,d,data(p).run.id) then d.evade=d.evade+1 end end
 elseif action=='CancelDrone' or action=='AssignSlot' then
  local function reject(why,field,d,r) commandReply(pl,payload,'rejected',why,field,d,r) end
  if not validDroneIntent(payload) then reject('Invalid request');return end
  if payload.runId~=data(p).run.id then reject('Run changed');return end
  local d=drones[payload.droneId]
  if not d or d.owner~=pl.UserId then reject('Drone unavailable');return end
  if d.carrierId then reject('Select its carrier to give orders',nil,d);return end
  if d.life~=payload.life or d.hp<=0 or not R.allowed(d.owner,pl.UserId,d.state) then reject('Drone reprinted or unavailable',nil,d);return end
  if action=='CancelDrone' then
   local old=d.field;release(d);spend(d);d.field=nil;d.autoField=nil;d.state='Return';scene.markRecall(d);dropFieldIfEmpty(p,old)
   commandReply(pl,payload,'accepted','Drone recalled',scene.patchById[old],d);return
  end
  if not R.finite(payload.fieldId) or payload.fieldId%1~=0 or type(payload.resourceId)~='string' or #payload.resourceId>160 then reject('Invalid request',nil,d);return end
  local field=scene.patchById[payload.fieldId];local r=resources[payload.resourceId]
  if field and field.cfg.SelectionOnly then reject('Place the mining square to select crystals',field,d);return end
  if not field or (characterRoot(p).Position-field.center).Magnitude>(C.CommandRadius or 90) then reject('Too far from field',field,d);return end
  if not playerCanMine(p,field) or activeAssault(p) then reject('Clear guards first',field,d);return end
  if not nearMiningField(characterRoot(p).Position,field) then reject('Move closer to the mining area',field,d);return end
  if field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if not DroneRoles.isWorker(d.role) then reject('Choose the miner or breaker',field,d);return end
  if not r or r.field~=field or not r.part.Parent or r.paid or r.hp<=0 then reject('Rock unavailable',field,d);return end
  if now<r.readyAt then reject('Rock is still settling',field,d,r);return end
  if not sameRockType(d,r) then reject('This rock is already assigned to another drone type or crew',field,d,r);return end
  if d.target==r and d.field==field.id and r.slots[d.id] then commandReply(pl,payload,'accepted','Already assigned',field,d,r,r.slots[d.id]);return end
  local occupied={};for _,v in pairs(r.slots) do occupied[v]=true end
  local slot=1;while slot<=r.limit and occupied[slot] do slot=slot+1 end
  if slot>r.limit then reject('Resource is busy',field,d,r);return end
  local old=d.field;release(d);spend(d);d.autoField=nil;d.field=field.id;d.target=r;d.targetSlot=slot;r.slots[d.id]=slot;updateSlots(r);d.state='Travel';d.shotAt=now;p.workField=field.id
  if old~=field.id then dropFieldIfEmpty(p,old) end
  commandReply(pl,payload,'accepted','Drone assigned',field,d,r,slot)
 elseif action=='MineOre' then
  local id=type(payload)=='table' and payload.resourceId or payload
  if type(payload)=='table' and not validCommandId(payload.requestId) then return end
  local function reply(status,reason,r,d)
   commandReply(pl,payload,status,reason,r and r.field,d,r)
   if status=='rejected' then notice(p,reason) end
  end
  if type(payload)=='table' and payload.runId~=data(p).run.id then reply('rejected','Run changed');return end
  if type(id)~='string' or #id>160 then reply('rejected','Invalid rock');return end
  local r=resources[id];local hr=characterRoot(p)
  if not r or r.paid or r.hp<=0 or not r.part.Parent then reply('rejected','That rock has already broken');return end
  if r.field.cfg.SelectionOnly then reply('rejected','Place the mining square to select crystals',r);return end
  p.oreQueue=p.oreQueue or {}
  for index,queued in ipairs(p.oreQueue) do if queued==id then
   if type(payload)=='table' and payload.toggle==true then
    table.remove(p.oreQueue,index);p.publishDirty=true;reply('canceled','Queued order canceled',r)
   else reply('queued','Already queued',r) end
   return
  end end
  if not nearMiningField(hr.Position,r.field) then reply('rejected','Move closer to that rock',r);return end
  if activeAssault(p) or not playerCanMine(p,r.field) then reply('rejected','Clear the guards before mining',r);return end
  if now<r.readyAt then reply('rejected','Rock is still growing',r);return end
  local hasWorker=false;for _,d in ipairs(p.drones) do if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) then hasWorker=true;break end end
  if not hasWorker then reply('rejected','A miner or breaker is needed',r);return end
  local used=0;local mine
  for workerId in pairs(r.slots) do
   used+=1;local worker=drones[workerId]
   if not worker or worker.owner~=pl.UserId then reply('rejected','Another crew is working this rock',r);return end
   mine=worker
  end
  if used>=r.limit then reply('accepted','Crew already working this rock',r,mine);return end
  if #p.oreQueue>=16 then reply('rejected','16 orders queued. Click a queued rock to cancel it',r);return end
  if r.field.cfg.Turrets>0 and r.field.e.phase=='Cleared' then grantClear(p,r.field) end
  p.workField=r.field.id;table.insert(p.oreQueue,r.id);p.publishDirty=true
  local sent=dispatchOreQueue(p)
  if sent[r.id] then reply('accepted',used>0 and 'Helper sent' or 'Miner sent',r,sent[r.id]);return end
  reply('queued','Queued · next available worker',r)
 elseif action=='ReturnCargo' then
  if payload~=nil and (type(payload)~='string' or #payload>160) then return end
  sellBackpack(p,false)
 elseif action=='Patch' then
  local fieldId=type(payload)=='table' and payload.fieldId or payload
  if type(payload)=='table' and not validCommandId(payload.requestId) then return end
  if not R.finite(fieldId) or fieldId%1~=0 then commandReply(pl,payload,'rejected','Invalid field');return end
  local field=scene.patchById[fieldId];local hr=characterRoot(p)
  if field and field.cfg.SelectionOnly then return end
  if not field or (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then commandReply(pl,payload,'rejected','Too far from field',field);return end
  if not field.cfg.AlwaysUnlocked and not Shops.unlocked(data(p),field.cfg.Key) then commandReply(pl,payload,'rejected','Buy access in the previous mineral shop first',field);return end
  local can=playerCanMine(p,field)
  if can and field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if can then
   if not nearMiningField(hr.Position,field) then commandReply(pl,payload,'rejected','Move closer to the mining area',field);return end
   if activeAssault(p) then commandReply(pl,payload,'rejected','Recall fighting drones first',field);return end
   local assigned=0
   for _,d in ipairs(p.drones) do
    if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) then
     local old=d.field
     if old~=field.id then release(d);spend(d);d.field=field.id;d.state='Travel';d.shotAt=now end
     d.autoField=field.id;d.commandOutAt=nil;assigned+=1
     if old~=field.id then dropFieldIfEmpty(p,old) end
    end
   end
   if assigned==0 then
    local reason='An available mining drone is needed'
    commandReply(pl,payload,'rejected',reason,field);notice(p,reason);return
   end
   if p.workField~=field.id then p.oreQueue={} end
   p.workField=field.id
   if field.junk then notice(p,'Crew assigned to '..(field.junkTheme or 'salvage')..'. Press Recall to stop.') end
   commandReply(pl,payload,'accepted',field.junk and 'Clearing order accepted' or 'Mining area assigned',field)
  else
   local fleet={}
   for _,d in ipairs(p.drones) do
    if not d.carrierId and d.hp>0 and (DroneRoles.combat(d.role) or d.role=='Medic') and R.allowed(d.owner,pl.UserId,d.state) then table.insert(fleet,d) end
   end
   local fighters=0;for _,d in ipairs(fleet) do if d.role~='Medic' then fighters+=1 end end
   if fighters==0 then commandReply(pl,payload,'rejected','Reprint a fighting drone first',field);return end
   p.oreQueue={};p.workField=nil
   -- Living replacements may join at any time. Repeating a guard order does
   -- not restart an existing attack or refresh its once-per-life entry shield.
   for _,d in ipairs(fleet) do
    local old=d.field
    if old~=field.id then release(d);spend(d);d.field=field.id;d.state='Travel';d.shotAt=now end
    d.autoField=field.id
    if old~=field.id then dropFieldIfEmpty(p,old) end
   end
   R.begin(field.e);wakeTurrets(field,pl)
   if R.enroll(field.e,pl.UserId,data(p).run.id,fleet) then
    for _,d in ipairs(fleet) do
     d.guardShieldLives=d.guardShieldLives or {}
     if d.guardShieldLives[field.id]~=d.life then
      d.shield=field.e.roster[d.id].stats.entryShield or 0;d.guardShieldLives[field.id]=d.life
     end
    end
   end
   commandReply(pl,payload,'accepted','Fighting guards',field)
  end
 elseif action=='Sell' then
  sellBackpack(p,false)
 elseif action=='BuyPack' or action=='ChooseCard' or action=='Prestige' then
  if not economyAction(p,pl,action,payload) then return end
 end
 p.publishDirty=true
end
command.OnServerEvent:Connect(commandPlayer)
local addPlayer
local function failPendingJoin(uid,why)
 local waiting=scene.pendingJoins[uid];scene.pendingJoins[uid]=nil
 if waiting and waiting.Parent then
  waiting:SetAttribute('MA_SaveStatus','Previous profile session unavailable — no defaults written')
  waiting:SetAttribute('MA_Notice',why)
 end
end
local function drainPendingJoin(uid,previous)
 if profiles[uid] or scene.loading[uid] then return end
 local waiting=scene.pendingJoins[uid];scene.pendingJoins[uid]=nil
 if waiting and waiting~=previous and waiting.Parent then task.spawn(addPlayer,waiting) end
end
addPlayer=function(pl)
 local current=profiles[pl.UserId]
 if current then
  -- PlayerAdded can race ahead of PlayerRemoving. A distinct same-ID Player
  -- must wait for the prior session even before its leave handler starts.
  if current.player~=pl and pl.Parent then scene.pendingJoins[pl.UserId]=pl end
  return
 end
 if scene.loading[pl.UserId] then
  if scene.loading[pl.UserId]~=pl then scene.pendingJoins[pl.UserId]=pl end
  return
 end
 scene.loading[pl.UserId]=pl
 pl:SetAttribute('MA_SaveStatus','Loading profile...')
 -- A prior bounded final-release attempt may have failed after its Player
 -- left. Recover that exact session before loading again; the manager's local
 -- lease guard would otherwise block every later reconnect in this server.
 local orphan=store.sessions[pl.UserId]
 if orphan and not orphan.closed then
  local resolved=true
  if orphan.readOnly then resolved=store:reconcile(orphan) end
  if resolved and not orphan.closed then resolved=store:release(orphan) end
  if not resolved then
   scene.loading[pl.UserId]=nil
   if pl.Parent then pl:SetAttribute('MA_SaveStatus','Previous profile session unavailable — no defaults written');pl:SetAttribute('MA_Notice','Previous session still needs safe reconciliation; try again later.') end
   drainPendingJoin(pl.UserId,pl);return
  end
 end
 local session,err=store:load(pl.UserId)
 scene.loading[pl.UserId]=nil
 if not session then
  if pl.Parent then pl:SetAttribute('MA_SaveStatus','Profile unavailable — no defaults written');pl:SetAttribute('MA_Notice',tostring(err)) end
  drainPendingJoin(pl.UserId,pl);return
 end
 if not pl.Parent then
  -- The first Player left while loading. Finish releasing its acquired lease
  -- before starting one queued replacement; uncertain storage never falls back
  -- to a new profile or bypasses that lease.
  local released=false
  for attempt=1,3 do
   if session.readOnly then store:reconcile(session) end
   if session.closed or store:release(session) then released=true;break end
   task.wait(.2*attempt)
  end
  if released then drainPendingJoin(pl.UserId,pl)
  else failPendingJoin(pl.UserId,'Previous session could not be safely released; try again later.') end
  return
 end
 -- Clear obsolete transient tokens; permanent plot unlocks are retained.
 session.data.run.entitlements={}
 local p={player=pl,session=session,drones={},tokens=7,bucketAt=now,busy=false,dirty=false,leaving=false,publishDirty=true,crew=CrewAbilities.new()}
 profiles[pl.UserId]=p
 pl:SetAttribute('MA_TestingEnabled',preview);pl:SetAttribute('MA_DevToolsEnabled',RunService:IsStudio());pl:SetAttribute('MA_NoRestock',false)
 pl:SetAttribute('MA_TestLoadoutLabel','Use RANDOM LOADOUT for 2–5 random drones')
 local spawnAt=(scene.spawnPosition or home)+Vector3.new(0,4,0)
 local function character(ch)
  local hr=ch:WaitForChild('HumanoidRootPart',10)
  if not hr or not pl.Parent then return end
  local firstField=scene.runStart or scene.fields[1].center
  if scene.fieldTools then scene.fieldTools:clear(p) end
  p.hazardAt={}
  if p.characterReady then leaveField(p,nil,nil,true) end
  p.characterReady=true
  scene.applyWalkSpeed(p)
  ch:PivotTo(CFrame.lookAt(spawnAt,Vector3.new(firstField.X,spawnAt.Y,firstField.Z)))
  if inStudio and scene.fieldTools and not p.previewToolsGranted then
   p.previewToolsGranted=true;scene.fieldTools:previewLoadout(p)
  end
 end
 p.connection=pl.CharacterAdded:Connect(character)
 rebuildFleet(p,spawnAt);logistics:create(p);publish(p)
 if pl.Character then task.spawn(character,pl.Character) end
end
Players.PlayerAdded:Connect(function(pl) task.spawn(addPlayer,pl) end)
local function removePlayer(pl)
 local p=profiles[pl.UserId];if not p or p.leaving then return end
 p.leaving=true;RoleEffects.ClearAbility(pl.UserId);leaveField(p);if p.connection then p.connection:Disconnect() end
 if scene.fieldTools then scene.fieldTools:clear(p) end
 logistics:remove(p);packDelivery:clear(p)
 for _,d in ipairs(p.drones) do release(d);spend(d);d.model:Destroy();drones[d.id]=nil end
 -- Wait for the one ordered economy operation, then final save/unlock. No default fallback.
 local deadline=os.clock()+12
 while p.busy and os.clock()<deadline do task.wait(.1) end
 local released=false
 if not p.busy then
  if consumableService then consumableService:clear(p) end
  p.session.data.run.entitlements={}
  for attempt=1,3 do
   if p.session.readOnly then local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end end
   if p.session.closed then released=true;break end
   local saved=store:release(p.session);if saved then released=true;break end
   if os.clock()>=deadline then break end;task.wait(.2*attempt)
  end
 end
 profiles[pl.UserId]=nil
 if released then drainPendingJoin(pl.UserId,pl)
 else failPendingJoin(pl.UserId,'Previous session could not be safely released; try again later.') end
end
Players.PlayerRemoving:Connect(removePlayer)
for _,pl in ipairs(Players:GetPlayers()) do task.spawn(addPlayer,pl) end
RunService.Heartbeat:Connect(function(dt: number)
 now=workspace:GetServerTimeNow()
 scene.stepClusterShots()
 discoveries:Step()
 elapsed=math.min(elapsed+math.max(0,dt),C.Tick*(C.MaxCatchup or 6))
 local steps=0
 while elapsed>=C.Tick and steps<(C.MaxCatchup or 6) do
  elapsed=elapsed-C.Tick;steps=steps+1
  for _,field in ipairs(patches) do encounterStep(field) end
  logistics:tick(C.Tick)
  for _,p in pairs(profiles) do
   packDelivery:step(p,now)
   scene.autoField(p)
   recallFromField(p)
   dispatchOreQueue(p)
   if consumableService then consumableService:step(p,C.Tick) end
   if p.ability and p.busy then DroneAbilities.pause(p.ability,C.Tick)
   elseif p.ability and healthy(p) and (p.ability.charge or p.ability.burn or p.ability.swarm) then
    local work=p.ability.burn or p.ability.swarm or p.ability.charge
    local swarm=p.ability.swarm;local burn=p.ability.burn;local charge=p.ability.charge
    DroneAbilities.step(p.ability,now,C.Tick,abilityContext(p,work and work.fieldId or 1,work and work.actorId and drones[work.actorId]),
     swarm and abilityContext(p,swarm.fieldId,swarm.actorId and drones[swarm.actorId]))
    if (burn and not p.ability.burn) or (charge and not p.ability.charge) then
     data(p).run.abilityCooldowns=Pro.clone(p.ability.cooldowns);p.dirty=true;p.publishDirty=true
    end
   end
  end
  pickupStep(C.Tick)
  scene.digStep()
  if scene.runStart then for _,p in pairs(profiles) do scene.assignEmptierPickups(p) end end
  for _,field in ipairs(patches) do if field.junk then scene.dispatchJunk(field) end end
  swarmGrid=Feel.swarmGrid(drones)
  for _,p in pairs(profiles) do
   local hr=characterRoot(p)
   local origin=hr and hr.Position
   if origin and scene.flatFields then origin=Vector3.new(origin.X,home.Y,origin.Z) end
   p.followRing=origin and Feel.ringGoals(p.drones,origin,p.followRing,scene.followHeight) or nil
  end
  scene.plotQueues={}
  scene.planMiningStations()
  for _,d in pairs(drones) do
   local warmAt,mining=d.warmAt,d.mining
   droneStep(d,C.Tick)
   -- Report the short charge and its release without waiting for the next
   -- periodic pose update, which can be longer than an upgraded ignition.
   if d.role=='Striker' and d.target and d.target.field.cfg.ContinuousCrystals
    and (d.state=='Warmup' and not warmAt or d.state=='Mine' and not mining) then
    snapshotDrone(d)
   end
  end
  scene.flushPlotQueues(C.Tick)
  if scene.fieldTools then scene.fieldTools:step(C.Tick) end
  for _,d in pairs(drones) do
   if d.hp>0 and d.mining and d.target and not d.target.paid and not d.target.field.cfg.SelectionOnly then scene.hazards:beam(d.pos,d.target.part.Position,4,'laser') end
  end
  for _,field in ipairs(patches) do turretStep(field);encounterStep(field) end
 end
 snapshotElapsed=snapshotElapsed+dt;autosaveElapsed=autosaveElapsed+dt
 if snapshotElapsed>=C.Snapshot then
  local snapshotDt=snapshotElapsed;snapshotElapsed=0
  local occupants
  for _,d in pairs(drones) do snapshotDrone(d) end
  if scene.flatFields then
   for _,p in pairs(profiles) do
    local hr=characterRoot(p)
    p.player:SetAttribute('MA_InSquareField',hr~=nil and scene.insideSquareField(hr.Position))
   end
  end
  scene.publishCharger()
  for _,field in ipairs(patches) do
   if field.cfg.RockModifiers and now>=(field.checkModifiersAt or 0) then
    field.checkModifiersAt=now+1
    scene.stepRockModifiers(field)
   end
   for _,r in ipairs(field.resources) do
    scene.stepGeode(r)
    scene.regrow(r,snapshotDt)
    local solid=not r.paid and not r.sealedDrop and now>=r.readyAt
    if field.junk then
     if r.part.CanQuery~=solid then r.part.CanQuery=solid end
     if solid and not r.part.CanCollide then solid=not scene.junkLandingOccupied(r.position,r.fullSize.Magnitude*.5) end
    elseif solid and not r.part.CanCollide then
     occupants=occupants or Players:GetPlayers()
     solid=scene.rockCanSolidify(r,occupants)
    end
    if r.part.CanCollide~=solid then r.part.CanCollide=solid;r.part.CanTouch=solid and not r.referenceCrystal end
   end
   field.model:SetAttribute('Phase',field.e.phase);field.model:SetAttribute('EncounterId',nil);field.model:SetAttribute('PhaseEndsAt',nil)
   for _,t in ipairs(field.turrets) do
    local watcher: any=t.watcher and profiles[t.watcher];local hr: any=watcher and characterRoot(watcher)
    if t.awake and not hr then
     for uid in pairs(field.e.users) do
      local p=profiles[uid];local candidate=p and characterRoot(p)
      if candidate then t.watcher=uid;hr=candidate;break end
     end
    end
    if t.awake and t.hp>0 and hr then t.model:SetAttribute('WatchPosition',hr.Position) end
   end
   for i=#field.resources,1,-1 do local r=field.resources[i];if r.paid and r.removeAt and now>=r.removeAt and (r.part:GetAttribute('EffectPausedAt') or 0)<=0 then resources[r.id]=nil;r.part:Destroy();table.remove(field.resources,i) end end
   if field.junk then scene.replenishJunk(field);continue end
   local rate,count=respawnRate(field)
   field.model:SetAttribute('MiningDroneCount',count);field.model:SetAttribute('RespawnRate',rate)
   local replenishing=field.e.phase=='Safe' or field.e.phase=='Cleared' or scene.unlockedMiners(field)
   if replenishing then
    if field.cfg.ReferenceCrystals then field.respawnClock=now
    else field.respawnClock+=snapshotDt*rate end
   end
   table.sort(field.respawnQueue,scene.respawnEarlier)
   local replenished=0
   while replenishing and replenished<field.cfg.Count and scene.replacementDue(field,field.respawnQueue[1]) do
    local due=0;for _,vacancy in ipairs(field.respawnQueue) do if scene.replacementDue(field,vacancy) then due+=1 else break end end
    -- A geode reserves five future nodes. Consume five due replenishment tokens,
    -- rather than leaving four immortal retries behind after every shell cycle.
    local spawned,cost=scene.spawnReplacement(field,not field.cfg.ContinuousCrystals and due<5 and 'Crystal' or nil,field.respawnQueue[1])
    if not spawned then
     -- One failed sample set establishes a field-level backoff for every token
     -- already due, rather than re-running 18 raycasts per snapshot for each
     -- blocked missing slot in turn. Future tokens keep their own due times.
     for i=1,due do field.respawnQueue[i].at=field.respawnClock+2 end
     table.sort(field.respawnQueue,scene.respawnEarlier);break
    end
    for _=1,cost do table.remove(field.respawnQueue,1) end
    replenished=replenished+cost
   end
  end
  for _,p in pairs(profiles) do
   if p.ability then
    local encoded=Http:JSONEncode(DroneAbilities.view(p.ability,now))
    if encoded~=p.lastAbilityJSON then p.lastAbilityJSON=encoded;p.player:SetAttribute('MA_Ability',encoded) end
   end
   do
    local encoded=Http:JSONEncode(CrewAbilities.view(p.crew,scene.crewRoles(p),now))
    if encoded~=p.lastCrewJSON then p.lastCrewJSON=encoded;p.player:SetAttribute('MA_Crew',encoded) end
   end
   scene.crewStep(p)
   serviceDeliveries(p);p.player:SetAttribute('MA_InAssault',activeAssault(p))
   scene.publishSquareStatus(p)
   if not p.busy then settleRuntime(p) end
   local profile=data(p)
   if healthy(p) and characterRoot(p) and scene.autoSellReady(p,profile,Pro.cargoUnits(profile)) then sellBackpack(p,true) end
   if p.publishDirty then p.publishDirty=false;publish(p) end
  end
 end
 if autosaveElapsed>=30 then
  autosaveElapsed=0
  for _,p in pairs(profiles) do
   if not p.busy and not p.leaving then
    p.busy=true;setMotionPaused(p,true)
    task.spawn(function()
     if p.session.readOnly then
      local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end
     end
     local ok,err=store:save(p.session)
     if not ok then
      notice(p,'Save delayed: '..tostring(err))
      if p.session.readOnly then local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end end
     else p.dirty=false end
     p.busy=false;setMotionPaused(p,not store:healthy(p.session));settleRuntime(p);publish(p)
    end)
   end
  end
 end
end)
game:BindToClose(function()
 local pending=0
 for _,p in pairs(profiles) do pending=pending+1;task.spawn(function() removePlayer(p.player);pending=pending-1 end) end
 local deadline=os.clock()+25;while pending>0 and os.clock()<deadline do task.wait(.1) end
end)
