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
local scene: any=World.initialize()
World.placeStart(scene)
local root,home=scene.root,scene.home
local function folder(parent,name)
 local f=Instance.new('Folder');f.Name=name;f.Parent=parent;return f
end
local droneFolder=root:FindFirstChild('Drones') or folder(root,'Drones')
local net=folder(RS,'MiningAway')
local command=Instance.new('RemoteEvent');command.Name='Command';command.Parent=net
-- Runtime entity graphs are mutually recursive. Keep their dynamic Roblox
-- boundaries explicit rather than expanding an unbounded inferred table type.
local profiles: {[number]: any}={}
local drones: {[string]: any}={}
local swarmGrid: any=nil
local patches: {any}={}
local resources: {[string]: any}={}
local logistics: any=nil
local consumableService: any=nil
local loading: {[number]: any}={}
-- At most one replacement Player may wait per user. A reconnect cannot acquire
-- another lease until the retiring local session is saved and released.
local pendingJoins: {[number]: any}={}
local now=workspace:GetServerTimeNow()
local elapsed,snapshotElapsed,autosaveElapsed=0,0,0
local seed=Random.new()
local instanceId=(game.JobId~='' and game.JobId or Http:GenerateGUID(false))
local preview=RunService:IsStudio() or game.GameId==0
-- Runtime-only test perks: never add cards, upgrades or fleet ownership to a save.
local testPerks=preview and {scope='Fleet',effects={plotAuto=1,capacity=C.Capacity/Ca.BASE_CAPACITY-1}} or nil
local adapter
if preview then adapter=Persistence.previewAdapter('MiningAwayPreview:'..instanceId)
else adapter=Persistence.dataStore(game:GetService('DataStoreService'):GetDataStore('MiningAwayProfiles_v2')) end
local store=Persistence.new(adapter,{
 owner=instanceId,now=os.time,wait=task.wait,leaseSeconds=180,maxAttempts=3,
 newProfile=function(uid) return Pro.new(uid,seed:NextInteger(1,2147483000)) end,
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
 copy.capacity=Ca.capacity(copy,testPerks);copy.cargoUnits=Pro.cargoUnits(copy);copy.nextPackPrice=Ca.price(copy);copy.packSpeed=Shops.packSpeed(copy);copy.packCurrency=Shops.PACK_CURRENCY;copy.prestigePreview=Pro.prestigePreview(data(p))
 copy.storageCapacity=Logistics.CAPACITY
 if logistics and logistics.view then copy.logisticsStates=logistics:view(p) end
 copy.deliveryUnits=0;for _,manifest in pairs(copy.run.deliveries) do for _,units in pairs(manifest.cargo) do copy.deliveryUnits+=units end end
 -- The active preview crew is presentation data, never permanent ownership.
 copy.activeFleet=p.testFleet and Pro.clone(p.testFleet) or nil
 copy.droneStats={};copy.droneRoles={};for _,d in ipairs(p.drones) do copy.droneStats[d.id]=d.stats;copy.droneRoles[d.id]=d.role end
 local autoMine,autoHaul=false,false
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
 if copy.run.pendingOffer then copy.run.pendingOffer.seed=nil end
 copy.saveMode=preview and 'Preview — temporary profiles' or 'Saved profile';copy.pendingTransaction=p.busy or p.session.readOnly or false
 p.player:SetAttribute('MA_Profile',Http:JSONEncode(copy))
 p.player:SetAttribute('MA_SaveStatus',p.session.lost and 'Session lost — progress paused' or (p.session.readOnly and 'Save uncertain — reconciling' or (preview and 'PREVIEW • not saved across restarts' or 'Saved • autosave active')))
end
local function characterRoot(p: any): any
 local ch=p.player.Character;local h=ch and ch:FindFirstChildOfClass('Humanoid');local hr=ch and ch:FindFirstChild('HumanoidRootPart')
 return h and h.Health>0 and hr or nil
end
local function atStation(p,station,radius)
 local hr=characterRoot(p);return hr and (hr.Position-station.Position).Magnitude<(radius or 18)
end
local function atHome(p)
 local hr=characterRoot(p);return hr and (hr.Position-home).Magnitude<30
end
-- Orders belong to a field footprint with a forgiving walking margin.
local function nearMiningField(position,field)
 local localPoint=field.part.CFrame:PointToObjectSpace(position)
 return math.abs(localPoint.X)<=field.part.Size.X*.5+18 and math.abs(localPoint.Z)<=field.part.Size.Z*.5+18 and math.abs(localPoint.Y)<=45
end
local function updateSlots(r)
 local count=0;for _ in pairs(r.slots) do count=count+1 end
 if r.part and r.part.Parent then r.part:SetAttribute('SlotsUsed',count) end
end
local function release(d: any,keepCombatEffects: boolean?,keepBreakContact: boolean?): ()
 if d.specialJob and d.target and not d.target.paid then
  d.target.part:SetAttribute('EffectCancelledSerial',d.specialJob.serial);d.target.part:SetAttribute('EffectType',nil)
 end
 if d.specialRecovery and d.specialRecovery.part.Parent then
  local part=d.specialRecovery.part
  part:SetAttribute('EffectPausedAt',0);part:SetAttribute('EffectCancelledSerial',d.specialRecovery.serial)
 end
 d.specialJob=nil;d.specialRecovery=nil;d.specialPausedAt=nil;d.obstructedAt=nil;d.manualTarget=nil
 d.specialClear=nil;d.specialQueryAt=nil
 if d.target then local r=d.target;r.slots[d.id]=nil;updateSlots(r) end
 d.target=nil;d.mining=false;d.beamSince=0;d.warmAt=nil;d.mineCharge=0;d.forkUntil=0;d.forkTargetId=nil;d.combatTarget=nil;d.targetPosition=nil
 d.breaker=nil;d.growPlan=nil;d.growAt=nil;d.workStation=nil;d.workTargetId=nil
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
  local p=profiles[d.owner];local hasNext=d.autoField~=nil or (p and #(p.oreQueue or {})>0)
  d.lingerUntil=now+(hasNext and .2 or 1);d.lingerGoal=station
 end
end
local function spend(d)
 for _,p in ipairs(patches) do R.spend(p.e,d.id) end
end
local function dropFieldIfEmpty(p: any,fieldId: any)
 if not fieldId then return end
 for _,d in ipairs(p.drones) do if d.hp>0 and d.field==fieldId then return end end
 local field=patches[fieldId]
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
local function recallFromField(p)
 if not healthy(p) then return end
 local hr=characterRoot(p);if not hr then return end
 local hasOrders=p.workField~=nil or #(p.oreQueue or {})>0
 local field=p.workField and patches[p.workField]
 if not field then
  for _,d in ipairs(p.drones) do if not d.carrierId and d.field and patches[d.field] then field=patches[d.field];hasOrders=true;break end end
 end
 if not hasOrders or not field or nearMiningField(hr.Position,field) then return end
 leaveField(p,nil,nil,true)
 p.recallSerial=(p.recallSerial or 0)+1
 p.player:SetAttribute('MA_RecallSerial',p.recallSerial);p.player:SetAttribute('MA_RecallAt',now)
 for _,d in ipairs(p.drones) do if d.hp>0 and not d.carrierId then
  d.state='Follow';d.recallSerial=(d.recallSerial or 0)+1;d.recallAt=now
  d.model:SetAttribute('RecallSerial',d.recallSerial);d.model:SetAttribute('RecallAt',now)
 end end
 p.publishDirty=true
end
local colors={Blue=Color3.fromRGB(86,190,255),Red=Color3.fromRGB(255,110,118),Green=Color3.fromRGB(116,230,157)}
local TEST_ROLES={}
for _,name in ipairs(RoleConfig.TypeOrder) do
 local role=RoleConfig.StudioRoles[name];colors[name]=RoleConfig.Types[name].Color
 table.insert(TEST_ROLES,{type=name,name=name,height=role.height,base=role.base})
end
local function runtimeFleet(p: any) return p.testFleet or data(p).fleet end
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
 local optional={Starforge=true,Frostbite=true,Resonator=true}
 for _,name in ipairs(DroneCatalog.Order) do if name~='Laser' and (not starterOnly or not optional[name]) then table.insert(order,name) end end
 for i,name in ipairs(order) do
  counts[name]=(counts[name] or 0)+1
  local role=RoleConfig.StudioRoles[name]
  local owned
  if DroneCatalog.Types[name] then for _,candidate in ipairs(data(p).fleet) do if candidate.role==name then owned=Pro.clone(candidate);break end end end
  table.insert(fleet,owned or {id=string.format('test:%d:%d:%d',p.player.UserId,p.testRoll,i),type=name,role=name,name=(names[name] or RoleConfig.Types[name].DisplayName)..(name=='Courier' and ' '..counts[name] or ''),flightHeight=role.height,base=Pro.clone(role.base)})
 end
 -- Keep the real first miner's identity so named cards also work in this test.
 local miner=Pro.clone(data(p).fleet[1]);miner.role='Striker';miner.name='Miner';fleet[1]=miner
 p.player:SetAttribute('MA_TestLoadoutLabel',(starterOnly and 'Core crew' or 'All drone types')..' · Plot Scanner · max backpack')
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
local function spawnDrone(p,owned,slot)
 local stats=Ca.stats(data(p),owned,testPerks)
 local roleName=owned.role or owned.type
 local role=RoleConfig.StudioRoles[roleName]
 local flightHeight=owned.flightHeight or (role and role.height) or Feel.FollowHeight
 -- Runtime presentation lift; never rewrite a permanent drone's base traits.
 if roleName~='Courier' and roleName~='Charger' then flightHeight+=1.8 end
 local pos=home+Vector3.new(0,flightHeight,0)+Feel.formation(slot,#runtimeFleet(p))
 local model,body,emitter=World.drone(droneFolder,RS:FindFirstChild('Drone'),pos,colors[owned.type] or colors.Blue)
 model,body,emitter=RoleConfig.decorate(model,roleName)
 model.Name='Drone_'..owned.id
 local d={id=owned.id,owner=p.player.UserId,owned=owned,name=owned.name,role=owned.role or owned.type,flightHeight=flightHeight,model=model,body=body,emitter=emitter,slot=slot,
  pos=pos,goal=pos,velocity=Vector3.zero,yaw=0,life=1,state='Follow',hp=stats.maxHealth,stats=stats,field=nil,target=nil,mining=false,
  beamSince=0,readyAt=0,shotAt=0,shield=0,evade=0,commandOutAt=nil,shotSerial=0,lastShotAt=0,lastCritAt=0,forkUntil=0,chainUntil=0,
  mineCharge=0,minePulseSerial=0,minePulseAt=0,minePulseTargetId='',mineBreakSerial=0,healAt=0,chargeAt=nil}
 drones[d.id]=d;table.insert(p.drones,d);return d
end
local function rebuildFleet(p)
 for _,d in ipairs(p.drones) do release(d);spend(d);drones[d.id]=nil;d.model:Destroy() end
 p.drones={}
 local ids={};for _,owned in ipairs(runtimeFleet(p)) do if owned.role=='Courier' then table.insert(ids,owned.id) end end
 if Pro.reconcileCargo(data(p),ids) then p.dirty=true end
 for i,owned in ipairs(runtimeFleet(p)) do spawnDrone(p,owned,i) end
end
local function refreshStats(p)
 for _,d in ipairs(p.drones) do
  local old=d.stats.maxHealth;local stats=Ca.stats(data(p),d.owned,testPerks)
  if d.hp>0 then d.hp=math.min(stats.maxHealth,math.max(1,d.hp+math.max(0,stats.maxHealth-old))) end
  d.stats=stats
 end
end
local function kill(d)
 if d.hp<=0 then return end
 release(d);spend(d);d.field=nil;d.autoField=nil;R.reprint(d,now,C.Reprint+C.Assembly)
 d.pickupAt=nil;d.launchAt=nil;d.unloadAt=nil;d.deliveryArrived=false;d.deliveryRequested=false
 d.repairChargeAt=nil;d.repairTarget=nil;d.healTargetId=nil;d.healUntil=0
 d.model:SetAttribute('DeathSerial',(d.model:GetAttribute('DeathSerial') or 0)+1)
end
local function playerCanMine(p,field)
 if not field.cfg.AlwaysUnlocked and not Shops.unlocked(data(p),field.cfg.Key) then return false end
 return field.cfg.Turrets==0 or field.e.phase=='Cleared' or data(p).clearedFields[field.cfg.Key]==true
end
local function unlockedMiners(field)
 for _,d in pairs(drones) do
  local p=profiles[d.owner]
  if d.field==field.id and d.hp>0 and healthy(p) and data(p).clearedFields[field.cfg.Key] then return true end
 end
 return false
end
local function los(a,b,target,ignore)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=ignore or {droneFolder}
 local hit=workspace:Raycast(a,b-a,params)
 return hit==nil or hit.Instance==target or (target and hit.Instance:IsDescendantOf(target))
end
local function abilityLineOfSight(p,from,r)
 return los(from,r.part.Position,r.part,{droneFolder,p.player.Character})
end
local resourceSerial=0
local function nodeUsage(field)
 local count=0;for _,r in ipairs(field.resources) do if not r.paid then count=count+(r.kind=='Geode' and 5 or 1) end end;return count
end
local function respawnRate(field: any)
 local count=0
 for _,d in pairs(drones) do
  local p=profiles[d.owner]
  if d.field==field.id and d.hp>0 and healthy(p) and characterRoot(p) then count+=1 end
 end
 local tuning=RoleConfig.Mining
 return math.min(tuning.RespawnRateMaximum,tuning.RespawnRateBase+math.max(0,count-1)*tuning.RespawnRatePerDrone),count
end
local function makeResource(field,position,kind,maxHealth,ore,visualSize,stageCount)
 maxHealth=(maxHealth-10)*(field.cfg.HealthMultiplier or 1)+10
 resourceSerial=resourceSerial+1
 -- The owner requested cubic mineable rocks. Keep the authored crystal asset
 -- intact in the native map; only runtime resource bodies change shape.
 local part=Instance.new('Part');part.Shape=Enum.PartType.Block
 part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 part:SetAttribute('CubicRock',true)
 local shell=kind=='Geode';local size=visualSize or (maxHealth/(shell and 37.5 or 25))*(kind=='Shard' and .8 or 1)
 local fullSize=Vector3.one*size
 local ground=field.part.Position.Y+field.part.Size.Y*.5
 local start=Vector3.new(position.X,ground,position.Z)
 local finish=Vector3.new(position.X,ground+fullSize.Y*.5-.06,position.Z)
 part.Name=kind;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=true;part.Size=fullSize;part.Position=finish
 part.Color=shell and Color3.fromRGB(96,85,117) or field.color;part.Material=shell and Enum.Material.Slate or Enum.Material.Rock;part.Reflectance=0
 if part:IsA('PartOperation') then part.UsePartColor=true end
 part.Parent=field.model
 local r={id=instanceId..':r'..resourceSerial,field=field,part=part,hp=maxHealth-10,maxHP=maxHealth,fullSize=fullSize,position=finish,start=start,
  slots={},limit=(shell or (stageCount or 3)>3) and 3 or 1,kind=kind,paid=false,ore=ore,hardness=field.cfg.Hardness or 1,spawnAt=now,readyAt=now+2,stage=0,stageCount=stageCount or 3,stageSeed=seed:NextInteger(1,1000000),removeAt=nil}
 part.CFrame=Feel.groundedRockFrame(finish,fullSize,ground,0,r.stageSeed)
 resources[r.id]=r;table.insert(field.resources,r)
 for k,v in pairs({ResourceId=r.id,FieldId=field.id,Kind=kind,Hardness=r.hardness,HP=maxHealth,MaxHP=maxHealth,Stage=0,StageCount=r.stageCount,Mineral=field.cfg.Material or field.cfg.Key,StageSeed=r.stageSeed,SpawnAt=now,ReadyAt=r.readyAt,FullSize=fullSize,FullPosition=finish,StartPosition=start,GroundY=ground,BreakSerial=0,SlotCapacity=r.limit,SlotsUsed=0}) do part:SetAttribute(k,v) end
 return r
end
local function spawnResource(field,forceKind,prepareOnly,plan)
 local usage=nodeUsage(field);if usage>=field.cfg.Count then return false end
 local kind=forceKind or ((field.id>1 and field.cfg.Count-usage>=5 and seed:NextNumber()<.12) and 'Geode' or 'Crystal')
 if kind=='Geode' and field.cfg.Count-usage<5 then kind='Crystal' end
 local boulder=not prepareOnly and not plan and kind=='Crystal' and (usage==0 or seed:NextNumber()<Mining.BOULDER_CHANCE)
 local clearance=RaycastParams.new();clearance.FilterType=Enum.RaycastFilterType.Exclude
 local excluded={field.model,droneFolder}
 for _,player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excluded,player.Character) end end
 clearance.FilterDescendantsInstances=excluded
 local fieldTop=field.part.Position.Y+field.part.Size.Y/2
 local mineral=plan and plan.mineral or Mining.resource(seed:NextInteger(50,100),kind,field.cfg.Hardness)
 local visualSize=mineral.size*(boulder and Mining.BOULDER_SIZE or 1)
 local radius=ResourcePlacement.radius(visualSize,visualSize,visualSize,kind)
 local occupied={}
 for _,r in ipairs(field.resources) do if not r.paid then
  local p=field.part.CFrame:PointToObjectSpace(r.position)
  occupied[#occupied+1]={x=p.X,z=p.Z,radius=ResourcePlacement.radius(r.fullSize.X,r.fullSize.Y,r.fullSize.Z,r.kind)}
 end end
 for _,t in ipairs(field.turrets) do
  local p=field.part.CFrame:PointToObjectSpace(t.body.Position)
  occupied[#occupied+1]={x=p.X,z=p.Z,radius=math.max(4,ResourcePlacement.radius(t.body.Size.X,t.body.Size.Y,t.body.Size.Z))}
 end
 local preferred
 if plan then local p=field.part.CFrame:PointToObjectSpace(plan.spot);preferred={x=p.X,z=p.Z} end
 local selected=ResourcePlacement.sample(field.part.Size.X,field.part.Size.Z,radius,occupied,
  function(a,b) return seed:NextNumber(a,b) end,function(x,z)
   local candidate=field.part.CFrame:PointToWorldSpace(Vector3.new(x,0,z))
   -- Authored trees also live outside Map. Check the footprint and overhead
   -- flight space against the actual world, including those branches.
   for _,offset in ipairs({Vector3.zero,Vector3.new(-.45,0,-.45),Vector3.new(.45,0,-.45),Vector3.new(-.45,0,.45),Vector3.new(.45,0,.45)}) do
    local origin=Vector3.new(candidate.X,field.center.Y+64,candidate.Z)+offset*visualSize
    if workspace:Raycast(origin,Vector3.new(0,fieldTop+.05-origin.Y,0),clearance) then return false end
   end
   return true
  end,preferred)
 if not selected then return false end
 local spot=field.part.CFrame:PointToWorldSpace(Vector3.new(selected.x,0,selected.z))
 if prepareOnly then return true,1,{spot=spot,field=field.id,mineral=mineral} end
 local work=mineral.work*(boulder and Mining.BOULDER_WORK or 1)
 local resource=makeResource(field,spot,kind,work+10,field.cfg.Ore*(boulder and Mining.BOULDER_WORK or 1),visualSize,boulder and 7 or 3)
 return true,kind=='Geode' and 5 or 1,resource
end
local function seedField(field)
 for _,r in ipairs(field.resources) do
  for id in pairs(r.slots) do if drones[id] then release(drones[id]) end end
  resources[r.id]=nil;r.part:Destroy()
 end
 field.resources={};field.respawnQueue={};field.respawnClock=now
 for _=1,field.cfg.Count do if not spawnResource(field) then break end end
 -- A blocked initial sampling pass must not permanently strand a safe field.
 -- Reserve one retry token for each missing unit of the population budget;
 -- geodes already count as five units through nodeUsage.
 for _=1,math.max(0,field.cfg.Count-nodeUsage(field)) do
  table.insert(field.respawnQueue,now+2)
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
 table.insert(patches,field);restoreTurrets(field);seedField(field)
 field.model:SetAttribute('AlwaysUnlocked',field.cfg.AlwaysUnlocked==true)
end
-- Visible depot counters, shared with edit-time and in-session repair tooling.
local shopStations=ShopStands.mount(scene.map,home,scene.packStation)
local prices={};for _,field in ipairs(patches) do prices[field.cfg.Material or field.cfg.Key or field.cfg.Name]=field.cfg.Value end
local discoveries=DiscoveryService.new(root,RoleConfig.Discoveries,function(player)
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
local function pendingOre(p)
 local units,nodes=0,{}
 for _,drop in pairs(pickups) do
  if drop.owner==p.player.UserId and drop.runId==data(p).run.id then units+=drop.units;nodes[drop.nodeId]=true end
 end
 local count=0;for _ in pairs(nodes) do count+=1 end
 return units,count
end
local function award(d: any,r: any,completedSpecial: boolean?)
 local p=profiles[d.owner];if not healthy(p) or not playerCanMine(p,r.field) then return end
 local profile=data(p);local material=r.field.cfg.Material or r.field.cfg.Key or r.field.cfg.Name
 local special=completedSpecial and d.specialJob and d.specialJob.targetId==r.id and DroneCatalog.Types[d.role]
 local amount=r.ore*d.stats.yieldMultiplier*(special and (special.Yield or 1) or 1)*discoveries:Multiplier(p.player,'Yield')+(profile.run.yieldRemainders[material] or 0)
 local units=math.floor(amount);profile.run.yieldRemainders[material]=amount-units
 if d.deployedCarrier and logistics then
  local accepted=logistics:deposit(p,material,units)
  local pending=profile.run.logistics.pendingCargo
  if accepted<units then pending[material]=(pending[material] or 0)+units-accepted end
  p.dirty=true;p.publishDirty=true;return
 end
 local ground=r.part:GetAttribute('GroundY') or r.field.part.Position.Y+r.field.part.Size.Y*.5
 local _,nodes=pendingOre(p)
 if nodes>=OreDrops.MAX_NODES then
  -- Full bags never stop mining. Coalesce further rewards of this mineral
  -- into one existing physical fragment without losing an integer ore unit.
  for _,drop in pairs(pickups) do
   if drop.owner==d.owner and drop.runId==profile.run.id and drop.material==material then
    drop.units+=units;drop.part:SetAttribute('Units',drop.units);p.dirty=true;p.publishDirty=true;return
   end
  end
 end
 for index,n in ipairs(OreDrops.partition(units)) do
  pickupSerial+=1
  local vx,vy,vz=OreDrops.scatter(index,pickupSerial)
  local position=Vector3.new(r.position.X,ground+.65,r.position.Z)
  local chip=r.part:Clone();for _,child in ipairs(chip:GetChildren()) do child:Destroy() end
  -- Never inherit ResourceId: pickups are not mineable replacement rocks.
  for key in pairs(chip:GetAttributes()) do chip:SetAttribute(key,nil) end
  chip.Name='OreFragment';chip.Size=Vector3.new(.48,.58,.44);chip.Position=position;chip.Material=Enum.Material.Rock
  -- Rewards retain their material hue independently of fracture shading.
  chip.Color=r.field.color
  chip.Anchored=true;chip.CanCollide=false;chip.CanTouch=false;chip.CanQuery=false;chip.Transparency=0
  chip:SetAttribute('Owner',d.owner);chip:SetAttribute('RunId',profile.run.id);chip:SetAttribute('Units',n);chip:SetAttribute('Mineral',material)
  chip:SetAttribute('SpawnAt',now);chip:SetAttribute('FadeAt',now+OreDrops.LIFETIME-OreDrops.FADE_SECONDS);chip:SetAttribute('ExpiresAt',now+OreDrops.LIFETIME);chip:SetAttribute('FloorY',ground+.22);chip:SetAttribute('Homing',false)
  chip:SetAttribute('PickupId',pickupSerial);chip:SetAttribute('Position',position);chip:SetAttribute('Velocity',Vector3.new(vx,vy,vz));chip:SetAttribute('SnapshotAt',now)
  chip.Parent=pickupFolder
  pickups[pickupSerial]={part=chip,owner=d.owner,runId=profile.run.id,nodeId=r.id,material=material,units=n,
   x=position.X,y=position.Y,z=position.Z,vx=vx,vy=vy,vz=vz,age=0,spawnAt=now,floor=ground+.22,fieldPart=r.field.part}
 end
 p.dirty=true;p.publishDirty=true
end
local function pickupStep(dt)
 for id,drop in pairs(pickups) do
  local p=profiles[drop.owner]
  if not p or p.leaving or data(p).run.id~=drop.runId or OreDrops.expired(drop.spawnAt,now) then
   drop.part:Destroy();pickups[id]=nil;if p then p.publishDirty=true end
  elseif healthy(p) then
   -- A chip can roll off a raised ore bed. Sample the real map floor only
   -- outside its original footprint, at bounded intervals while moving.
   if drop.fieldPart and now>=(drop.floorQueryAt or 0) then
    local localPoint=drop.fieldPart.CFrame:PointToObjectSpace(Vector3.new(drop.x,drop.y,drop.z))
    local outside=math.abs(localPoint.X)>drop.fieldPart.Size.X*.5 or math.abs(localPoint.Z)>drop.fieldPart.Size.Z*.5
    drop.floorQueryAt=now+.25
    if outside and (not drop.floorQueryX or (drop.x-drop.floorQueryX)^2+(drop.z-drop.floorQueryZ)^2>.25) then
     local include={scene.map};local base=workspace:FindFirstChild('Baseplate');if base then table.insert(include,base) end
     for _,field in ipairs(scene.fields) do table.insert(include,field.part) end
     local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances=include;query.RespectCanCollide=true
     local hit=workspace:Raycast(Vector3.new(drop.x,drop.y+2,drop.z),Vector3.new(0,-66,0),query)
     if hit then drop.floor=hit.Position.Y+.22;drop.part:SetAttribute('FloorY',drop.floor) end
     drop.floorQueryX=drop.x;drop.floorQueryZ=drop.z
    end
   end
   local hr=characterRoot(p);local target=hr and hr.Position or Vector3.new(drop.x,drop.y,drop.z)
   local from=Vector3.new(drop.x,drop.y,drop.z)
   local canCollect=hr~=nil and Pro.cargoUnits(data(p))<Ca.capacity(data(p),testPerks) and (target-from).Magnitude<=OreDrops.MAGNET_RANGE
   if canCollect then
    if now>=(drop.queryAt or 0) then drop.clearPath=los(from,target,hr.Parent,{pickupFolder,droneFolder});drop.queryAt=now+.15 end
    canCollect=drop.clearPath==true
   end
   local reached,groundSpeed=OreDrops.step(drop,{x=target.X,y=target.Y,z=target.Z},dt,canCollect)
   if groundSpeed and groundSpeed>1 then
    drop.groundSerial=(drop.groundSerial or 0)+1
    drop.part:SetAttribute('GroundImpactAt',now)
    drop.part:SetAttribute('GroundImpactSpeed',groundSpeed)
    drop.part:SetAttribute('GroundImpactPosition',Vector3.new(drop.x,drop.floor,drop.z))
    drop.part:SetAttribute('GroundImpactSerial',drop.groundSerial)
   end
   if reached and los(Vector3.new(drop.x,drop.y,drop.z),target,hr.Parent,{pickupFolder,droneFolder}) then
    local accepted=Pro.addCargo(data(p),drop.material,drop.units,Ca.capacity(data(p),testPerks))
    if accepted>0 then
     drop.units-=accepted;p.dirty=true;p.publishDirty=true
     p.collectSerial=(p.collectSerial or 0)+1
     p.collectTotal=(p.collectTotal or 0)+accepted
     p.player:SetAttribute('CollectedOreTotal',p.collectTotal)
     local color=drop.part.Color
     p.player:SetAttribute('MA_Collect',Http:JSONEncode({serial=p.collectSerial,total=p.collectTotal,at=now,units=accepted,pickupId=id,exhausted=drop.units==0,x=drop.x,y=drop.y,z=drop.z,
      r=math.floor(color.R*255),g=math.floor(color.G*255),b=math.floor(color.B*255)}))
     if drop.units==0 then
      drop.part:SetAttribute('Units',0);drop.part:SetAttribute('CollectedPosition',target);drop.part:SetAttribute('CollectedAt',now)
      drop.part.Transparency=1;Debris:AddItem(drop.part,.35);pickups[id]=nil
     else drop.part:SetAttribute('Units',drop.units);drop.clearPath=false;drop.queryAt=0 end
    end
   end
   if pickups[id] then
    local position=Vector3.new(drop.x,drop.y,drop.z)
    if now>=(drop.snapshotAt or 0) then
     drop.part.Position=position;drop.part.Transparency=OreDrops.fade(drop.spawnAt,now)
     drop.snapshotAt=now+C.Snapshot;drop.part:SetAttribute('Position',position)
     drop.part:SetAttribute('Velocity',Vector3.new(drop.vx,drop.vy,drop.vz));drop.part:SetAttribute('Homing',drop.homing==true);drop.part:SetAttribute('SnapshotAt',now)
    end
   end
  end
 end
end
local hitResource: any
local function secondaryMining(d: any,primary: any,amount: number,radius: number)
 local candidates={}
 for _,other in ipairs(primary.field.resources) do
  if other~=primary and not other.paid and now>=other.readyAt and other.part.Parent then
   local distance=(other.position-primary.position).Magnitude
   if distance<=radius then table.insert(candidates,{resource=other,distance=distance}) end
  end
 end
 table.sort(candidates,function(a,b) return a.distance==b.distance and a.resource.id<b.resource.id or a.distance<b.distance end)
 for _,candidate in ipairs(candidates) do
  local other=candidate.resource;local sameOwner=true
  for id in pairs(other.slots) do local worker=drones[id];if not worker or worker.owner~=d.owner then sameOwner=false end end
  -- A teammate may help a fully occupied node; no foreign reservation is
  -- displaced, and the worker holding the node receives its ore.
  if sameOwner and not other.slots[d.id] then
   other.slots[d.id]=1
   local accepted=hitResource(d,other,amount,true,radius)
   other.slots[d.id]=nil;updateSlots(other)
   -- An obstructed first candidate must not starve a reachable second one.
   if accepted then return other.id end
  end
 end
 return false
end
hitResource=function(d: any,r: any,amount: number,secondary: boolean?,secondaryRange: number?,abilityOrigin: any,contactKind: string?)
 local p=profiles[d.owner]
 if not healthy(p) or d.hp<=0 or r.paid or r.hp<=0 or not r.part.Parent or not R.finite(amount) or amount<=0 or (not abilityOrigin and not r.slots[d.id]) or not playerCanMine(p,r.field) or now<r.readyAt then return false end
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
 if not abilityOrigin and not DroneRoles.isMiner(d.role) and not special and not shell then return false end
 if abilityOrigin then
  local hr=characterRoot(p)
  local carrierImpact=d.deployedCarrier and contactKind=='Breaker'
  if (not carrierImpact and (not hr or not nearMiningField(hr.Position,r.field))) or not abilityLineOfSight(p,abilityOrigin,r) then return false end
  for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=d.owner then return false end end
 elseif secondary then
  local primary=d.target
  -- The synchronous primary resolver alone can retain its contact through a
  -- final hit. No saved state/remote can authorize an echo from a retired node.
  if not primary or primary.field~=r.field or not primary.slots[d.id] or (primary.paid and primary.processingPrimary~=d.id) or (r.position-primary.position).Magnitude>(secondaryRange or d.stats.forkRange or 6) or (d.pos-r.position).Magnitude>d.stats.range or (d.pos-Feel.mineGoal(primary.position,d.targetSlot,primary.limit>1,primary.fullSize)).Magnitude>1 or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
 elseif d.target~=r or (d.pos-Feel.mineGoal(r.position,d.targetSlot,r.limit>1,r.fullSize)).Magnitude>1 or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
 -- A specialist's committed job, never its caller, supplies the finite hit budget.
 if special then amount=job.damage end
 if contactKind=='Consumable' then r.consumableWorked=true end
 local baseAmount=amount
 local discoverySpeed=discoveries:Multiplier(p.player,'Speed')
 amount=amount*discoverySpeed
 if not abilityOrigin or contactKind=='Breaker' then amount*=Mining.contactMultiplier(d.role,r.kind,r.hardness,r.stage,r.stageCount) end
 amount=amount*(abilityOrigin and contactKind~='Breaker' and 1 or Mining.efficiency(d.role=='Charger' and 'Red' or 'Blue',r.kind))
 if r.kind=='Geode' or r.kind=='Core' then amount=amount*(d.stats.geodeMultiplier or 1) end
 if special then
  amount=DroneCatalog.capDamage(d.role,r.maxHP,amount)
  -- Quarter-work subtraction can leave a floating-point residue on minerals
  -- such as Ruby. Resolve only arithmetic dust, never another real chunk.
  if r.hp>amount and r.hp-amount<=math.max(1,r.maxHP)*1e-10 then amount=r.hp end
 end
 if secondary then d.forkTarget=r.position;d.forkTargetId=r.id;d.forkUntil=now+.18 end
 if not secondary and not abilityOrigin then r.processingPrimary=d.id end
 local previous=r.stage
 local revealed=nil
 local broken=R.damage(r,amount)
 -- Persistent cosmetic history is emitted only by accepted authoritative hits.
 -- Observers/late joiners reconstruct the same cavities without authorizing
 -- damage from local CSG geometry, bubbles or collision debris.
 if special and d.role=='Bubbler' then
  r.bubbleBites=math.min(6,(r.bubbleBites or 0)+1);r.part:SetAttribute('BubbleBites',r.bubbleBites)
 elseif contactKind=='Breaker' and d.role=='Charger' then
  r.smashDents=math.min(6,(r.smashDents or 0)+1);r.part:SetAttribute('SmashDents',r.smashDents)
 end
 if (special and d.role=='Bubbler') or (contactKind=='Breaker' and d.role=='Charger') then
  if not r.damageBaseScale then
   r.damageBaseScale=Feel.stageScale(previous,r.stageCount);r.damageBaseStage=previous
   r.part:SetAttribute('DamageBaseScale',r.damageBaseScale);r.part:SetAttribute('DamageBaseStage',previous)
  end
  local depth=math.clamp(1-r.hp/math.max(1,r.maxHP-10),0,1)
  r.smashPressure=(r.smashDents or 0)>=6 and math.floor(depth*6+1e-7)/6 or 0
  r.part:SetAttribute('DamageDepth',depth)
  r.part:SetAttribute('DamageAt',now)
 end
 if special then
  job.impacted=true
  r.part:SetAttribute('EffectDepleted',broken);r.part:SetAttribute('EffectDoneAt',now)
 end
 local actual=r.paid and 0 or r.hp+10
 r.stage=Feel.stage(actual,r.maxHP,r.stageCount)
 if r.stage~=previous then
  r.part:SetAttribute('Stage',r.stage)
  r.part.Size=r.fullSize*Feel.resourceScale(r.stage,r.stageCount,r.damageBaseScale,r.damageBaseStage)
  r.part.CFrame=Feel.groundedRockFrame(r.position,r.part.Size,r.part:GetAttribute('GroundY'),r.damageBaseStage or r.stage,r.stageSeed)
 end
 r.part:SetAttribute('HP',actual)
 if not secondary and not abilityOrigin and Mining.kind(d.owned.type)=='Red' then
  d.minePulseSerial=d.minePulseSerial+1;d.minePulseAt=now;d.minePulseTargetId=r.id
 end
 if broken then
  r.part:SetAttribute('BreakSerial',1);r.removeAt=now+2
  if r.kind=='Geode' then
   local core=Mining.resource(seed:NextInteger(50,100),'Core',r.hardness)
   revealed={makeResource(r.field,r.position,'Core',core.maxHP,r.ore*4,core.size)}
   for n=1,4 do
    local a=n*math.pi/2;local shard=Mining.resource(seed:NextInteger(50,70),'Shard',r.hardness)
    table.insert(revealed,makeResource(r.field,r.position+Vector3.new(math.cos(a)*4,0,math.sin(a)*4),'Shard',shard.maxHP,r.ore,shard.size))
   end
   for _,child in ipairs(revealed) do child.consumableWorked=r.consumableWorked end
  else
   award(recipient,r,special==true)
   -- Tools never manufacture more tools, including rocks later finished by a
   -- normal drone. The rock's ordinary ore payout remains unchanged.
   if not r.consumableWorked then discoveries:TrySpawn(p.player,r.field.part,Vector3.new(r.position.X,r.part:GetAttribute('GroundY') or r.position.Y,r.position.Z),r.field.id) end
   table.insert(r.field.respawnQueue,r.field.respawnClock+r.field.cfg.Respawn)
  end
 end
 if not secondary and not abilityOrigin then
  local secondaryId
  if (d.stats.forkFraction or 0)>0 then secondaryId=secondaryMining(d,r,baseAmount*d.stats.forkFraction,d.stats.forkRange or 6) end
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
  if broken and (secondaryId or Mining.kind(d.owned.type)=='Red') then
   -- This short record is presentation only: scalar IDs/timestamps, no target,
   -- reservation, damage permission or resource reference survives retirement.
   d.mineBreakSerial=d.mineBreakSerial+1
   d.mineBreakContact={at=now,untilTime=now+.3,primaryId=r.id,secondaryId=secondaryId or '',beamSince=d.beamSince}
  end
  r.processingPrimary=nil
 end
 if broken then
  local workers={};for id in pairs(r.slots) do table.insert(workers,id) end;table.sort(workers)
  for _,id in ipairs(workers) do
   local worker=drones[id]
   if worker and worker.target==r then
    local manual=worker.manualTarget~=nil
    if worker.specialJob and not special then
     r.part:SetAttribute('EffectCancelledSerial',worker.specialJob.serial);r.part:SetAttribute('EffectType',nil)
    end
    retireTarget(worker,not secondary and worker==d and d.mineBreakContact~=nil)
    -- Breaking a shell commits its existing crew to the actual revealed work.
    -- This is continuation of that ordered geode, not free field automation.
    -- New stones still have their normal growth/arrival/warmup gates.
    if revealed then
     for _,nextRock in ipairs(revealed) do
      if not next(nextRock.slots) then
       worker.target=nextRock;worker.targetSlot=1;nextRock.slots[id]=1
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
 return true
end
local function chooseResource(d: any,field: any): ()
 local best,score=nil,math.huge
 for _,r in ipairs(field.resources) do
  if not r.paid and r.hp>0 and r.part.Parent and now>=r.readyAt and (not r.blockedUntil or not r.blockedUntil[d.id] or now>=r.blockedUntil[d.id]) then
   local used=0;local foreign=false
   for id in pairs(r.slots) do used+=1;if not drones[id] or drones[id].owner~=d.owner then foreign=true end end
   if used<r.limit and not foreign then
    local neighbors=0
    if Mining.kind(d.owned.type)=='Green' then
     for _,other in ipairs(field.resources) do
      if other~=r and not other.paid and now>=other.readyAt and (other.position-r.position).Magnitude<=Mining.RESONANCE_RANGE then neighbors=neighbors+1;if neighbors==3 then break end end
     end
    end
    local value=Mining.targetScore(d.owned.type,d.stats,r,(r.position-d.pos).Magnitude,neighbors)
    if value<score then best=r;score=value end
   end
  end
 end
 if best then
  local occupied={};for _,slot in pairs(best.slots) do occupied[slot]=true end
  local slot=1;while occupied[slot] do slot=slot+1 end
  best.slots[d.id]=slot;updateSlots(best);d.target=best;d.targetSlot=slot;d.warmAt=nil;d.mineCharge=0;d.mining=false
 end
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
     t.shotSerial=t.shotSerial+1;t.model:SetAttribute('ShotSerial',t.shotSerial)
     if (d.pos-t.aim).Magnitude<=3.5 and (d.pos-t.emitter.Position).Magnitude<55 and los(t.emitter.Position,t.aim,d.model,{t.model,droneFolder}) then
      local stats=field.e.roster[d.id].stats;hurtDrone(d,field.cfg.Damage*(1-(stats.damageReduction or 0)))
     end
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
 return d.stats.maxStep60*(d.role=='Medic' and .68 or (d.role=='Courier' and (1+(d.stats.fullAuto or 0)) or (d.state=='BreakerDive' and 2.5 or 1)))
end
local function move(d,goal,dt)
 d.intentGoal=goal
 local settling=d.target~=nil or d.state=='BreakerRecover' or d.state=='GrowRecover' or d.state=='Deliver' or d.state=='Collect' or d.state=='Pickup' or d.state=='GrowApproach' or d.state=='Plant'
 local weight=d.state=='Recover' and 0 or (settling and math.clamp(((goal-d.pos).Magnitude-1)/5,0,1) or 1)
 local desired=Feel.swarmOffset(d.pos,d.id,swarmGrid,weight)
 d.swarmOffset=weight==0 and Vector3.zero or Feel.smoothSwarm(d.swarmOffset,desired,dt)
 goal=goal+d.swarmOffset
 d.goal=goal
 local work=d.target~=nil or d.state=='Deliver' or d.state=='BreakerDive' or d.state=='BreakerRecover' or d.state=='Recover' or d.state=='Plant' or d.state=='GrowApproach'
 local speed=travelSpeed(d)
 d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,speed,dt,work)
 d.yaw=Feel.approachYaw(d.yaw,Feel.flightYaw(d.pos,goal,d.velocity,d.yaw),dt)
 -- Fixed-rate logical motion; snapshotDrone publishes its physical proxy.
end
local function supportDrone(d: any,p: any,hr: any,dt: number)
 if d.target or d.combatTarget then release(d) end
 local best,score=nil,math.huge
 for _,ally in ipairs(p.drones) do
  if ally~=d and ally.hp>0 and ally.role~='Courier' then
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
    local goal=target.emitter.Position+Vector3.new(side*(8+(d.slot%3)*3),5+((d.flightHeight or Feel.FollowHeight)-Feel.FollowHeight),9)
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
local function committedStation(d,r)
 if d.workTargetId~=r.id then
  d.workTargetId=r.id
  d.workStation=Feel.mineGoal(r.position,d.targetSlot,r.limit>1,r.fullSize)
 end
 return d.workStation
end
local function mineDrone(d: any,p: any,field: any,dt: number)
 if d.combatTarget or d.state=='Attack' then release(d);d.chargeAt=nil;d.chargeTarget=nil end
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 -- Only the Plot Scanner card chooses an unclicked next resource.
 if not d.target and d.autoField==field.id and ((d.stats.plotAuto or 0)>0 or d.deployedCarrier) then chooseResource(d,field) end
 local r=d.target
 if r then
  local goal=committedStation(d,r);d.state='Travel';move(d,goal,dt)
  if Feel.canMine((d.pos-goal).Magnitude,now>=r.readyAt,true,d.hp>0) and los(d.pos,r.position,r.part,{droneFolder}) then
   d.obstructedAt=nil
   d.warmAt=d.warmAt or now;d.state='Warmup'
   if now-d.warmAt>=math.max(.08,d.stats.warmup) then
    if not d.mining then d.beamSince=now end
    d.state='Mine';d.mining=true
    local damage,charge=Mining.step('Blue',d.mineCharge,dt,d.stats.miningDPS);d.mineCharge=charge
    if damage>0 then hitResource(d,r,damage,false,nil,nil,DroneCatalog.Types[d.role] and r.kind=='Geode' and 'SpecialShell' or nil) end
   end
  else
   d.warmAt=nil;d.mineCharge=0;d.mining=false
   if (d.pos-goal).Magnitude<=1 and now>=r.readyAt then
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
  if d.deployedCarrier then d.state='Waiting';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt);return end
  if not d.autoField then local old=d.field;d.field=nil;dropFieldIfEmpty(p,old) end
  local hr=characterRoot(p)
  move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
 end
end
local function specialDrone(d: any,p: any,field: any,dt: number)
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 if not d.target and d.autoField==field.id and ((d.stats.plotAuto or 0)>0 or d.deployedCarrier) then chooseResource(d,field) end
 local r=d.target
 if not r or r.kind=='Geode' then mineDrone(d,p,field,dt);return end
 local goal=committedStation(d,r);d.state='Travel';d.mining=false;move(d,goal,dt)
 local arrived=Feel.canMine((d.pos-goal).Magnitude,now>=r.readyAt,true,d.hp>0)
 local job=d.specialJob
 local starting=not job and d.warmAt and now-d.warmAt>=math.max(.08,d.stats.warmup)
 local contacting=job and not job.impacted and now>=job.startedAt+job.duration*job.impact
 if arrived and (d.specialClear==nil or now>=(d.specialQueryAt or 0) or starting or contacting) then
  -- Monitor obstruction at snapshot cadence, with fresh checks at startup
  -- and the actual contact. Cosmetic recovery never adds damage.
  d.specialClear=los(d.pos,r.position,r.part,{droneFolder});d.specialQueryAt=now+C.Snapshot
 end
 if not arrived or not d.specialClear then
  if (d.pos-goal).Magnitude<=1 and now>=r.readyAt then
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+3;release(d)
  elseif d.specialJob then release(d) else d.warmAt=nil end;return
 end
 d.warmAt=d.warmAt or now;d.state='Warmup'
 if now-d.warmAt<math.max(.08,d.stats.warmup) then return end
 if not d.specialJob then
  local cycle=DroneCatalog.cycle(d.role,d.owned.base.miningDPS,d.stats.miningDPS)
  if not cycle then return end
  r.specialSerial=(r.specialSerial or 0)+1
  d.specialJob={targetId=r.id,serial=r.specialSerial,startedAt=now,duration=cycle.duration,impact=cycle.impact,damage=cycle.damage,impacted=false}
  for key,value in pairs({EffectType=d.role,EffectStartedAt=now,EffectDuration=cycle.duration,EffectImpact=cycle.impact,EffectDoneAt=0,EffectDepleted=false,EffectOwner=d.owner,EffectDrone=d.id,EffectPausedAt=0}) do r.part:SetAttribute(key,value) end
  r.part:SetAttribute('EffectSerial',r.specialSerial)
 end
 d.state='SpecialMine'
 job=d.specialJob
 if not job.impacted and now>=job.startedAt+job.duration*job.impact then
  hitResource(d,r,job.damage,false,nil,nil,'Special')
 end
 -- Keep the same reservation during recovery. A new serial can begin only
 -- after the current complete gesture; no extra warmup or overlapping hits.
 if d.specialJob==job and job.impacted and now>=job.startedAt+job.duration then d.specialJob=nil end
end
local roleAbilityStep
local function followRole(d,p,hr,dt,state)
 d.mining=false;d.state=state or 'Follow'
 move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
end
local function roleNodes(p,field,worker)
 local list={}
 for _,r in ipairs(field.resources) do
  local eligible=not worker or not r.blockedUntil or now>=(r.blockedUntil[worker.id] or 0);local count=0
  for id in pairs(r.slots) do count+=1;local worker=drones[id];if not worker or worker.owner~=p.player.UserId then eligible=false end end
  if r.part.Parent then table.insert(list,{id=r.id,hp=r.hp,maxHP=r.maxHP,kind=r.kind,x=r.position.X,y=r.position.Y,z=r.position.Z,readyAt=r.readyAt,paid=r.paid,eligible=eligible and count<r.limit}) end
 end
 return list
end
local function workingField(p,hr)
 local field=p.workField and patches[p.workField]
 if field and not activeAssault(p) and playerCanMine(p,field) and nearMiningField(hr.Position,field) then return field end
 return nil
end
local function growerDrone(d,p,hr,dt)
 d.mining=false
 local field=workingField(p,hr)
 if not field or #field.respawnQueue==0 or nodeUsage(field)>=field.cfg.Count then
  d.growPlan=nil;d.growAt=nil;d.field=nil;followRole(d,p,hr,dt);return
 end
 d.field=field.id
 if now<(d.nextGrow or 0) then
  d.state='GrowRecover';move(d,d.growRecoveryGoal or d.pos,dt);return
 end
 if not d.growPlan or d.growPlan.field~=field.id then
  d.growAt=nil
  local ok,_,plan=spawnResource(field,'Crystal',true)
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
 local ok,_,resource=spawnResource(field,'Crystal',false,d.growPlan)
 if ok then
  table.sort(field.respawnQueue);table.remove(field.respawnQueue,1)
  resource.part:SetAttribute('GrownBy',d.id)
  RoleEffects.Grow(d.pos,ground,true)
 end
 d.growRecoveryGoal=goal;d.growPlan=nil;d.growAt=nil;d.nextGrow=now+(ok and (d.stats.growCooldown or DroneRoles.GROWER.cooldown) or 1)
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
 local _,top=Feel.groundedRockFrame(r.position,r.part.Size,ground,r.damageBaseStage or r.stage,r.stageSeed)
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
 -- an ore/plot. The ordinary miner still needs the earned Plot Scanner.
 if not d.target and (p.workField==field.id or d.deployedCarrier) then
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
  if d.deployedCarrier then d.state='Waiting';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt)
  else followRole(d,p,hr,dt) end
  return
 end
 job=d.breaker
 if not job then
  local station=committedStation(d,r)+Vector3.new(0,2,0)
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
 if event=='windup' then publishBreakerPhase(d,job);RoleEffects.BreakerPhase(d.pos,job.contact,'Windup')
 elseif event=='dive' then job.diveStart=d.pos;publishBreakerPhase(d,job);RoleEffects.BreakerPhase(d.pos,job.contact,'Dive')
 elseif event=='contact' then
  d.velocity=Vector3.zero;d.pos=job.impact;d.goal=job.impact;d.intentGoal=job.impact
  d.contactSerial=(d.contactSerial or 0)+1;d.contactAt=now;publishBreakerPhase(d,job)
  RoleEffects.BreakerPhase(d.pos,job.contact,'Hold')
 elseif event=='impact' then
  d.velocity=Vector3.zero
  -- Hold the physical weight on the surface before this single delayed fracture.
  -- The longer weight hold earns a larger hit, retaining its pre-hold work
  -- rate while the shell/perk multipliers continue to define the specialist.
  if hitResource(d,r,d.stats.miningDPS*3.2,false,nil,d.pos,'Breaker') then
   d.impactSerial=(d.impactSerial or 0)+1;d.impactAt=now
   d.goal=job.station;d.intentGoal=job.station;publishBreakerPhase(d,job)
   RoleEffects.BreakerPhase(d.pos,job.contact,'Impact')
  else
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+6
   release(d)
  end
  d.breaker=job
 elseif event=='missed' or event=='canceled' then release(d) end
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
   else move(d,d.intentGoal or (d.goal-(d.swarmOffset or Vector3.zero)),dt) end
  end
  return
 end
 if not store:healthy(p.session) then release(d);return end
 if logistics then
  local station=logistics:station(d)
  if station then
   release(d);d.pos=station;d.goal=station;d.velocity=Vector3.zero;d.state='Docked'
   if logistics:atHome(d) then d.hp=math.min(d.stats.maxHealth,d.hp+8*dt) end
   return
  end
 end
 local hr=characterRoot(p)
 if not hr and d.deployedCarrier and d.field and patches[d.field] then hr={Position=patches[d.field].center} end
 if not hr then if d.field then leaveField(p,nil,nil,true) end;move(d,home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,d.flightHeight or Feel.FollowHeight,0),dt);return end
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
  local depot=scene.converter or scene.packStation
  local depotPosition=logistics and logistics:storagePosition(p) or depot.Position
  local offset=Feel.formation(d.slot,#p.drones);if offset.Magnitude>6 then offset=offset.Unit*6 end
  local goal=depotPosition+offset+Vector3.new(0,d.flightHeight,0)
  move(d,goal,dt)
  if (d.pos-goal).Magnitude<1 then
   d.unloadAt=d.unloadAt or now;d.state='Unload'
   d.deliveryArrived=now-d.unloadAt>=RoleConfig.Courier.UnloadHold
  else d.unloadAt=nil;d.deliveryArrived=false end
  return
 end
 if d.role=='Courier' then
  d.mining=false;d.field=nil
  if logistics:capacity(p)<=0 then
   d.deliveryRequested=false;d.pickupAt=nil;d.state='StorageFull'
   move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt);return
  end
  if Pro.cargoUnits(data(p))>0 and now>=(d.collectAfter or 0) then
   local rank=0;for _,other in ipairs(p.drones) do if other.role=='Courier' then rank+=1;if other==d then break end end end
   local side=rank%2==0 and 1 or -1
   d.state='Collect';move(d,hr.Position+Vector3.new(side*2.2,2.4,1),dt)
   if (d.pos-hr.Position).Magnitude<=RoleConfig.Courier.PickupDistance and los(d.pos,hr.Position,hr.Parent,{droneFolder}) then
    d.pickupAt=d.pickupAt or now;d.state='Pickup'
    d.deliveryRequested=now-d.pickupAt>=RoleConfig.Courier.PickupHold
   else d.pickupAt=nil;d.deliveryRequested=false end
  else
   d.pickupAt=nil;d.deliveryRequested=false
   d.state='Follow'
   move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
  end
  return
 elseif d.role=='Medic' then supportDrone(d,p,hr,dt);return
 elseif d.role=='Dart' then growerDrone(d,p,hr,dt);return
 elseif DroneRoles.ability(d.role) then roleAbilityStep(d,p,hr,dt);return end
 if d.role=='Charger' and not d.field then
  local selected=workingField(p,hr)
  if selected then d.field=selected.id end
 end
 local field=d.field and patches[d.field]
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
    release(d);d.state='StorageFull';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt)
   elseif not d.deployedCarrier and not nearMiningField(hr.Position,field) then
    -- Ore goes into a backpack carried by the owner. Leaving the plot brings
    -- the swarm along. The profile-level leash clears the order before work resumes.
    d.mining=false;d.warmAt=nil;d.mineCharge=0;d.state='Follow'
    move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
   elseif DroneCatalog.Types[d.role] then specialDrone(d,p,field,dt)
   elseif d.role=='Charger' then breakerDrone(d,p,hr,field,dt)
   else mineDrone(d,p,field,dt) end
  else leaveDroneField(p,d) end
 else
  d.mining=false;d.combatTarget=nil
  d.chargeAt=nil;d.chargeTarget=nil
  local height=d.flightHeight or Feel.FollowHeight
  local goal=d.state=='Return' and home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,height,0) or Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,height-Feel.FollowHeight,0)
  move(d,goal,dt)
  if d.state=='Return' and (d.pos-goal).Magnitude<1 then d.state='Follow' end
  if d.state~='Return' then d.state='Follow' end
  if (d.pos-home).Magnitude<22 then d.hp=math.min(d.stats.maxHealth,d.hp+8*dt) end
 end
end
local function snapshotDrone(d)
 local pose=CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0)
 if d.publishedPose~=pose then d.model:PivotTo(pose);d.publishedPose=pose end
 local profile=data(profiles[d.owner])
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
  Position=d.pos,Goal=d.goal,Velocity=d.velocity or Vector3.zero,SwarmOffset=d.swarmOffset or Vector3.zero,Yaw=d.yaw,WorkPaused=profiles[d.owner].busy,MotionPaused=not store:healthy(profiles[d.owner].session) and d.hp>0,MaxStep60=travelSpeed(d),PhaseSeed=d.owned.base.maxStep60*200,FormationSlot=d.slot,FleetCount=#profiles[d.owner].drones,
  TargetId=target and target.id or '',CombatTargetId=combatId,TargetPosition=target and target.position or (combatId~='' and combatTarget.emitter.Position) or d.pos,Mining=mining,BeamSince=d.beamSince,WarmupStart=d.warmAt or 0,WarmupDuration=target and math.max(.08,d.stats.warmup) or d.stats.warmup,
  MiningStyle=DroneRoles.isMiner(d.role) and 'Cutter' or 'None',MinePulseSerial=d.minePulseSerial,MinePulseAt=d.minePulseAt,MinePulseTargetId=d.minePulseTargetId,
  RecallSerial=d.recallSerial or 0,RecallAt=d.recallAt or 0,
  BreakerDiveStart=d.breaker and d.breaker.diveStart or d.pos,BreakerImpact=d.breaker and d.breaker.impact or d.pos,BreakerPhaseAt=d.breaker and d.breaker.phaseAt or 0,BreakerDiveDuration=DroneRoles.BREAKER.diveDuration,
  BreakerContactSerial=d.contactSerial or 0,BreakerContactAt=d.contactAt or 0,ImpactAt=d.impactAt or 0,
  DeliveryUnits=Pro.deliveryUnits(profile,d.id),DeliveryId=profile.run.deliveries[d.id] and profile.run.deliveries[d.id].id or '',AutoFieldId=d.autoField or 0,
  CourierPickupAt=d.pickupAt or 0,CourierPickupHold=RoleConfig.Courier.PickupHold,CourierLaunchAt=d.launchAt or 0,CourierLaunchHold=RoleConfig.Courier.LaunchHold,
  CourierUnloadAt=d.unloadAt or 0,CourierUnloadHold=RoleConfig.Courier.UnloadHold,CourierSaleSerial=d.saleSerial or 0,CourierSaleAt=d.saleAt or 0,SellPosition=(scene.converter or scene.packStation).Position,
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
   if paused then
    if effectJob and effectPart and not d.specialPausedAt then
     d.specialPausedAt=now;effectPart:SetAttribute('EffectPausedAt',now)
    end
    d.model:SetAttribute('Mining',false);d.model:SetAttribute('Firing',false)
    d.mineBreakContact=nil;d.model:SetAttribute('MineBreakUntil',0);d.model:SetAttribute('MineBreakPrimaryId','');d.model:SetAttribute('MineBreakSecondaryId','')
   elseif d.specialPausedAt then
    if effectJob and effectPart then
     local pausedFor=math.max(0,now-d.specialPausedAt)
     effectJob.startedAt+=pausedFor
     if effectJob.impacted then effectPart:SetAttribute('EffectDoneAt',(effectPart:GetAttribute('EffectDoneAt') or now)+pausedFor) end
     effectPart:SetAttribute('EffectStartedAt',effectJob.startedAt);effectPart:SetAttribute('EffectPausedAt',0)
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
 data=data,Pro=Pro,Profile=Pro,Shops=Shops,capacityOf=function(profile) return Ca.capacity(profile,testPerks) end,healthy=healthy,characterRoot=characterRoot,inHome=atHome,
 notice=notice,updateProfile=publish,getClock=function() return now end,transact=transact,
 atDepotStation=function(p) return atStation(p,scene.converter or scene.packStation,18) end,
 groundHeight=function(x,z) return logisticsTerrain:surface(x,z) end,
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
 if d.carrierId or not DroneRoles.isWorker(d.role) or d.target==r then return false end
 local occupied={};for id,slot in pairs(r.slots) do
  if not drones[id] or drones[id].owner~=p.player.UserId then return false end
  occupied[slot]=true
 end
 local slot=1;while slot<=r.limit and occupied[slot] do slot+=1 end
 if slot>r.limit then return false end
 local old=d.field;local resume=d.autoField~=nil;release(d);spend(d)
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
  if not r or r.paid or r.hp<=0 or not r.part.Parent or not playerCanMine(p,r.field) then table.remove(queue,index);p.publishDirty=true
  elseif now<r.readyAt or not nearMiningField(characterRoot(p).Position,r.field) then index+=1
  else
   local best,distance=nil,math.huge
   for _,d in ipairs(p.drones) do
    -- An explicit order may redirect automatic cutting/travel. Never cancel
    -- another manual order, a committed slam, or a specialist's physical job.
    local available=not d.target or (d.autoField and not d.manualTarget)
    if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) and available and d.target~=r and not d.breaker and not d.specialJob and not d.specialRecovery
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
local function serviceDeliveries(p: any)
 if not healthy(p) or not characterRoot(p) or now<(p.nextDeliveryAction or 0) then return end
 local run=data(p).run
 for _,d in ipairs(p.drones) do
  local manifest=run.deliveries[d.id]
  local destination=logistics:storagePosition(p) or (scene.converter or scene.packStation).Position
  if d.hp>0 and manifest and d.deliveryArrived and d.deliveryId==manifest.id and (d.pos-destination).Magnitude<=12 then
   local tx,runId,id=manifest.id,run.id,d.id
   p.nextDeliveryAction=now+.4
   transact(p,'deliveryFinish:'..tx,function(copy)
    local parcel=copy.run.deliveries[id]
    if copy.run.id~=runId or not parcel or parcel.id~=tx or parcel.runId~=runId then return nil,'Delivery changed' end
    local accepted=Logistics.depositInto(copy,parcel.cargo)
    for mineral,units in pairs(parcel.cargo) do
     local remainder=units-(accepted[mineral] or 0)
     if remainder>0 then copy.run.logistics.pendingCargo[mineral]=(copy.run.logistics.pendingCargo[mineral] or 0)+remainder end
    end
    copy.run.deliveries[id]=nil
    return {droneId=id,id=tx,runId=runId,stored=true}
   end,function()
    local worker=drones[id]
    if worker and worker.owner==p.player.UserId then
     worker.deliveryArrived=false;worker.deliveryId=nil;worker.deliveryRequested=false
     worker.pickupAt=nil;worker.launchAt=nil;worker.unloadAt=nil
     worker.saleSerial=(worker.saleSerial or 0)+1;worker.saleAt=now
     worker.field=nil;worker.autoField=nil;worker.state='Collect';worker.collectAfter=now+RoleConfig.Courier.PickupCooldown
    end
    p.publishDirty=true
   end)
   return
  elseif d.role=='Courier' and d.hp>0 and d.deliveryRequested and not manifest and now>=(d.collectAfter or 0) then
   local hr=characterRoot(p)
   if Pro.cargoUnits(data(p))==0 or (d.pos-hr.Position).Magnitude>RoleConfig.Courier.PickupDistance or not d.pickupAt or now-d.pickupAt<RoleConfig.Courier.PickupHold or not los(d.pos,hr.Position,hr.Parent,{droneFolder}) then d.deliveryRequested=false;d.pickupAt=nil
   else
    local tx,runId,id=Http:GenerateGUID(false),run.id,d.id
    p.nextDeliveryAction=now+1
    transact(p,'deliveryBegin:'..tx,function(copy)
     local ok,result=Pro.beginDelivery(copy,id,tx,runId,d.stats.courierCapacity or RoleConfig.Courier.BatchUnits);if ok then return result end;return nil,result
    end,function(result)
     local worker=drones[id]
     if worker and worker.owner==p.player.UserId then
      release(worker);worker.deliveryId=result.id;worker.deliveryArrived=false;worker.state='Launch';worker.launchAt=now;worker.unloadAt=nil;worker.deliveryRequested=false
     end
     p.publishDirty=true
    end)
    return
   end
  end
 end
end
local function sellBackpack(p: any)
 logistics:command(p,'Deposit')
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
local function committedOffer(p: any,payload: any): boolean
 if not p or not validPayload(payload) then return false end
 for _,receipt in ipairs(p.session.receipts or {}) do
  local result=receipt.result
  if receipt.id=='choose:'..payload.txId and type(result)=='table' and result.offerId==payload.offerId and result.runId==payload.runId then return true end
 end
 return false
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
local function chooseCard(p: any,pl: any,payload: any)
   if type(payload.offerId)~='string' or #payload.offerId>160 or not R.finite(payload.index) or payload.index%1~=0 or payload.index<1 or payload.index>3 then offerReply(pl,payload,'rejected','Invalid choice');return end
   p.pendingOfferTx=payload.txId
   local started=transact(p,'choose:'..payload.txId,function(copy: any)
    local ok: boolean,r: any=Ca.select(copy,payload.offerId,payload.index,payload.txId,payload.runId,{atDepot=true,activeEncounter=false});if ok then return r end;return nil,r
   end,function() refreshStats(p);notice(p,'Card installed • this run only.') end,function(status,reason) if status~='uncertain' then p.pendingOfferTx=nil end;offerReply(pl,payload,status,reason) end)
   if not started then p.pendingOfferTx=nil;offerReply(pl,payload,'rejected','Profile busy; try again') end
end
local function executePrestige(p: any,pl: any,payload: any)
 if payload.confirm~=true or not atStation(p,scene.prestigeStation,20) then return end
 local function applyPrestige(copy: any): (any, any)
  local context: any={atDepot=true,activeEncounter=activeAssault(p),confirmed=true}
  local ok: boolean,result: any=Pro.prestige(copy,payload.txId,payload.runId,context)
  if ok then return result end
  return nil,result
 end
 transact(p,'prestige:'..payload.txId,applyPrestige,function()
  for _,field in ipairs(patches) do local u=field.e.users[pl.UserId];if u then R.removeUser(field.e,pl.UserId,u.runId) end end
  p.oreQueue={};RoleEffects.ClearAbility(pl.UserId);rebuildFleet(p);logistics:refresh(p);notice(p,'Prestige complete. One new permanent drone; a fresh run.')
 end)
end
local function economyAction(p: any,pl: any,action: string,payload: any): boolean
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then
  if action=='ChooseCard' then offerReply(pl,payload,'rejected','Run changed or assault active') end
  return false
 end
 if not atHome(p) then
  notice(p,'Use the pack machine or prestige beacon at the depot.')
  if action=='ChooseCard' then offerReply(pl,payload,'rejected','Return to the depot') end
  return false
 end
 if action=='BuyPack' then
  if not R.finite(payload.packIndex) or payload.packIndex%1~=0 then return false end
  if not atStation(p,scene.packStation,20) then return false end
  local function buyCard(copy: any): (any, any)
   local options: any={combatVisible=true,expectedPackIndex=payload.packIndex,atDepot=true,activeEncounter=false}
   local ok: boolean,result: any=Ca.buy(copy,payload.txId,payload.runId,options)
   if ok then return result end
   return nil,result
  end
  transact(p,'buy:'..payload.txId,buyCard,function() notice(p,'Choose one card. All three choices and targets are saved.') end)
 elseif action=='ChooseCard' then
  chooseCard(p,pl,payload)
 else
  executePrestige(p,pl,payload)
 end
 return true
end
local function abilityContext(p,fieldId,operator,deployment)
 local function valid(id)
  local field=patches[id];local hr=characterRoot(p)
  return healthy(p) and hr~=nil and field~=nil and not activeAssault(p) and playerCanMine(p,field) and nearMiningField(hr.Position,field)
 end
 local state=deployment and deployment.state or p.ability
 local active=state and (state.burn or state.charge or state.swarm)
 local actor=operator or (active and active.actorId and drones[active.actorId])
 if not actor and not (active and active.actorId) then
  for _,d in ipairs(p.drones) do if d.hp>0 and (DroneRoles.isWorker(d.role) or DroneRoles.ability(d.role)) then actor=d;break end end
 end
 local hr=characterRoot(p);local origin=actor and actor.pos or (hr and hr.Position or home)
 if deployment then origin=deployment.position+Vector3.new(0,1,0) end
 local function unlocked(kind)
  if deployment then return kind==deployment.kind end
  if Shops.abilityUnlocked(data(p),kind) then return true end
  for _,d in ipairs(p.drones) do if d.hp>0 and DroneRoles.ability(d.role)==kind then return true end end
  return false
 end
 local function targetRecord(r)
  if not r or r.paid or r.hp<=0 or now<r.readyAt or not r.part.Parent then return nil end
  if deployment then
   local offset=r.position-deployment.position;local radius=Consumables.ITEMS[deployment.kind].radius
   if offset.X*offset.X+offset.Z*offset.Z>radius*radius then return nil end
  end
  for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=p.player.UserId then return nil end end
  -- Scars retain a larger shell and its original fracture orientation. Ability
  -- targeting must describe that current authoritative body, not the old
  -- quarter-scale/rotating presentation that ordinary unscarred rocks use.
  local top=select(2,Feel.groundedRockFrame(r.position,r.part.Size,r.part:GetAttribute('GroundY'),r.damageBaseStage or r.stage,r.stageSeed))
  return {id=r.id,hp=r.hp,maxHP=r.maxHP,ground=r.part:GetAttribute('GroundY'),radius=math.max(.1,r.part.Size.X*.5),x=r.position.X,y=top,z=r.position.Z}
 end
 return {runId=data(p).run.id,fieldId=fieldId,origin={x=origin.X,y=origin.Y,z=origin.Z},
  placement=deployment and {x=origin.X,y=origin.Y,z=origin.Z},perks=deployment and {scrapBots=2} or Ca.abilityPerks(data(p)),unlocked=unlocked,
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
   for _,r in ipairs(patches[id].resources) do
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
   local accepted=hitResource(actor,resource,math.min(damage,resource.maxHP+10),false,nil,Vector3.new(from.x,from.y,from.z),deployment and 'Consumable' or nil)
   if accepted and deployment and Consumables.accept(data(p).consumables) then p.dirty=true;p.publishDirty=true end
   return accepted,resource.paid==true
  end,
  emit=function(event) RoleEffects.Ability(deployment and (tostring(p.player.UserId)..':tool') or p.player.UserId,event,scene.droneTemplate) end}
end
consumableService=ConsumableService.new({data=data,healthy=healthy,saveHealthy=function(p) return store:healthy(p.session) end,
 notice=notice,transact=transact,abilities=DroneAbilities,effects=RoleEffects,root=root,now=function() return now end,
 context=function(p,record) return abilityContext(p,record.fieldId,nil,record) end,
 placement=function(p,payload)
  if not R.finite(payload.fieldId) or payload.fieldId%1~=0 or not R.finite(payload.x) or not R.finite(payload.z)
   or math.abs(payload.x)>100000 or math.abs(payload.z)>100000 then return nil,'Choose a position inside a mining field' end
  local field=patches[payload.fieldId];local hr=characterRoot(p)
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
 if not field then followRole(d,p,hr,dt);return end
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
  if now>=charge.started+1.4 then finishAbility(p,charge.token,context) end
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
   for _,node in ipairs(context.targets(field.id,'Orbital')) do if node.maxHP>largest then target=resources[node.id];largest=node.maxHP end end
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
  local ok=DroneAbilities.begin(ability,kind,now,context)
  if ok then ability.charge.actorId=d.id;ability.charge.automatic=true;p.publishDirty=true end
 end
end
local function miningAbility(p,payload)
 if type(payload)~='table' or payload.runId~=data(p).run.id or (payload.kind~='Orbital' and payload.kind~='Scrap') or not R.finite(payload.fieldId) or payload.fieldId%1~=0 or not patches[payload.fieldId] then return end
 if payload.op~='begin' then return end
 p.ability=p.ability or DroneAbilities.new(data(p).run.abilityCooldowns,data(p).run.id)
 local context=abilityContext(p,payload.fieldId)
 local ok,reason=DroneAbilities.begin(p.ability,payload.kind,now,context)
 if ok then data(p).run.abilityCooldowns=Pro.clone(p.ability.cooldowns);p.dirty=true end
 notice(p,reason);p.publishDirty=true
end
local function buyShopUpgrade(p,pl,payload)
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then return end
 local entry=type(payload.upgradeId)=='string' and Shops.BY_ID[payload.upgradeId]
 local station=entry and shopStations[entry.shop]
 if not station or not atStation(p,station,20) then notice(p,'Visit that mineral shop to buy upgrades.');return end
 transact(p,'shop:'..payload.txId,function(copy)
  local ok,result=Shops.buy(copy,payload.upgradeId,payload.level,payload.txId,payload.runId,{shop=entry.shop,atShop=true,activeEncounter=false,fleet=runtimeFleet(p)})
  if ok then return result end;return nil,result
 end,function() refreshStats(p);notice(p,entry.title..' installed.');p.publishDirty=true end)
end
local function commandPlayer(pl: any,action: any,payload: any)
 local p=profiles[pl.UserId];if not p or p.player~=pl then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerReply(pl,payload,'rejected','Fleet unavailable') end;return end
 if action=='ChooseCard' and committedOffer(p,payload) then offerReply(pl,payload,'accepted','Card installed');return end
 local duration=math.max(0,now-p.bucketAt);p.tokens=math.min(7,p.tokens+duration*3);p.bucketAt=now
 if p.tokens<1 then if now>=(p.nextCommandRejection or 0) then p.nextCommandRejection=now+.35;commandReply(pl,payload,'rejected','Too many commands');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Too many commands') end end;return end;p.tokens=p.tokens-1
 if type(action)~='string' or #action>24 or not healthy(p) or not characterRoot(p) then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Fleet unavailable') end;return end
 if action=='BuyDrone' then
  local kind=type(payload)=='table' and payload.droneType or payload
  if type(kind)~='string' or not DroneCatalog.Types[kind] or kind=='Laser' then return end
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
   logistics:refresh(p);notice(p,kind..' added to your permanent fleet.');p.publishDirty=true
  end)
 elseif action=='BuyCarrier' or action=='BuyBackpack' or action=='LoadCarrier' or action=='CarrierPatch' or action=='RecallCarrier' or action=='Deposit' or action=='LaunchStorage' or action=='AutoLaunch' then
  logistics:command(p,action,payload)
 elseif action=='MiningAbility' then
  miningAbility(p,payload)
 elseif action=='PlaceConsumable' then
  consumableService:command(p,payload)
 elseif action=='BuyUpgrade' then
  buyShopUpgrade(p,pl,payload)
 elseif action=='DevFillBag' then
  if not RunService:IsStudio() then return end
  local field=p.workField and patches[p.workField] or patches[1]
  local material=field.cfg.Material or field.cfg.Key or 'Quartz'
  local added=Pro.addCargo(data(p),material,math.max(0,Ca.capacity(data(p),testPerks)-Pro.cargoUnits(data(p))),Ca.capacity(data(p),testPerks))
  if added>0 then p.dirty=true;p.publishDirty=true end
 elseif action=='DevAddDrone' then
  if not RunService:IsStudio() or type(payload)~='table' or type(payload.role)~='string' then return end
  local role=RoleConfig.StudioRoles[payload.role]
  if not role or #p.drones>=24 then return end
  p.testFleet=p.testFleet or Pro.clone(data(p).fleet)
  p.testRoll=(p.testRoll or 0)+1
  local owned={id=string.format('test:%d:add:%d',pl.UserId,p.testRoll),type=payload.role,role=payload.role,name=RoleConfig.Types[payload.role].DisplayName,flightHeight=role.height,base=Pro.clone(role.base)}
  table.insert(p.testFleet,owned)
  local d=spawnDrone(p,owned,#p.testFleet);local hr=characterRoot(p)
  d.pos=Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0)
  d.goal=d.pos;d.model:PivotTo(CFrame.new(d.pos));snapshotDrone(d)
  pl:SetAttribute('MA_TestLoadoutLabel',tostring(#p.testFleet)..' preview drones')
  p.publishDirty=true
 elseif action=='TestLoadout' or action=='RoleLoadout' then
  if not preview or now<(p.nextTestLoadout or 0) then return end
  p.nextTestLoadout=now+RoleConfig.Settings.RandomizeCooldown;pl:SetAttribute('MA_TestReadyAt',p.nextTestLoadout)
  leaveField(p)
  for _,carrier in ipairs(data(p).logistics.carriers) do logistics:command(p,'RecallCarrier',carrier.id) end
  RoleEffects.ClearAbility(pl.UserId);p.ability=nil;p.testFleet=action=='RoleLoadout' and roleTestFleet(p) or randomTestFleet(p);rebuildFleet(p);logistics:refresh(p)
  notice(p,action=='RoleLoadout' and 'All drone types ready. Click a field to send every miner.' or 'Random test loadout ready — no saved fleet changed.')
 elseif action=='Recall' then
  leaveField(p)
  for _,carrier in ipairs(data(p).logistics.carriers) do logistics:command(p,'RecallCarrier',carrier.id) end
  for _,d in ipairs(p.drones) do if d.hp>0 then d.state='Follow' end end
  notice(p,'Orders cleared. Your backpack stays with you.');commandReply(pl,payload,'recalled','Orders cleared')
 elseif action=='Evade' then
  if now<(p.nextEvade or 0) then return end;p.nextEvade=now+2
  for _,d in ipairs(p.drones) do if d.field and R.participates(patches[d.field].e,d,data(p).run.id) then d.evade=d.evade+1 end end
 elseif action=='CancelDrone' or action=='AssignSlot' then
  local function reject(why,field,d,r) commandReply(pl,payload,'rejected',why,field,d,r) end
  if not validDroneIntent(payload) then reject('Invalid request');return end
  if payload.runId~=data(p).run.id then reject('Run changed');return end
  local d=drones[payload.droneId]
  if not d or d.owner~=pl.UserId then reject('Drone unavailable');return end
  if d.carrierId then reject('Select its carrier to give orders',nil,d);return end
  if d.life~=payload.life or d.hp<=0 or not R.allowed(d.owner,pl.UserId,d.state) then reject('Drone reprinted or unavailable',nil,d);return end
  if action=='CancelDrone' then
   local old=d.field;release(d);spend(d);d.field=nil;d.autoField=nil;d.state='Return';dropFieldIfEmpty(p,old)
   commandReply(pl,payload,'accepted','Drone recalled',patches[old],d);return
  end
  if not R.finite(payload.fieldId) or payload.fieldId%1~=0 or type(payload.resourceId)~='string' or #payload.resourceId>160 then reject('Invalid request',nil,d);return end
  local field=patches[payload.fieldId];local r=resources[payload.resourceId]
  if not field or (characterRoot(p).Position-field.center).Magnitude>(C.CommandRadius or 90) then reject('Too far from field',field,d);return end
  if not playerCanMine(p,field) or activeAssault(p) then reject('Clear guards first',field,d);return end
  if not nearMiningField(characterRoot(p).Position,field) then reject('Move closer to the plot to mine',field,d);return end
  if field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if not DroneRoles.isWorker(d.role) then reject('Choose the miner or breaker',field,d);return end
  if not r or r.field~=field or not r.part.Parent or r.paid or r.hp<=0 then reject('Crystal unavailable',field,d);return end
  if now<r.readyAt then reject('Crystal still growing',field,d,r);return end
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
  sellBackpack(p)
 elseif action=='Patch' then
  local fieldId=type(payload)=='table' and payload.fieldId or payload
  if type(payload)=='table' and not validCommandId(payload.requestId) then return end
  if not R.finite(fieldId) or fieldId%1~=0 then commandReply(pl,payload,'rejected','Invalid field');return end
  local field=patches[fieldId];local hr=characterRoot(p)
  if not field or (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then commandReply(pl,payload,'rejected','Too far from field',field);return end
  if not field.cfg.AlwaysUnlocked and not Shops.unlocked(data(p),field.cfg.Key) then commandReply(pl,payload,'rejected','Buy access in the previous mineral shop first',field);return end
  local can=playerCanMine(p,field)
  if can and field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if can then
   if not nearMiningField(hr.Position,field) then commandReply(pl,payload,'rejected','Move closer to the plot to mine',field);return end
   if activeAssault(p) then commandReply(pl,payload,'rejected','Recall fighting drones first',field);return end
   local assigned=0
   for _,d in ipairs(p.drones) do
    if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) and (d.stats.plotAuto or 0)>0 then
     local old=d.field
     if old~=field.id then release(d);spend(d);d.field=field.id;d.state='Travel';d.shotAt=now end
     d.autoField=field.id;d.commandOutAt=nil;assigned+=1
     if old~=field.id then dropFieldIfEmpty(p,old) end
    end
   end
   if assigned==0 then commandReply(pl,payload,'rejected','Click individual ores, or install Plot Scanner for an available worker',field);notice(p,'Click ores first. Plot Scanner unlocks plot orders.');return end
   if p.workField~=field.id then p.oreQueue={} end
   p.workField=field.id;commandReply(pl,payload,'accepted','Plot survey assigned',field)
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
    d.autoField=(d.stats.plotAuto or 0)>0 and field.id or nil
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
  sellBackpack(p)
 elseif action=='BuyPack' or action=='ChooseCard' or action=='Prestige' then
  if not economyAction(p,pl,action,payload) then return end
 end
 p.publishDirty=true
end
command.OnServerEvent:Connect(commandPlayer)
local addPlayer
local function failPendingJoin(uid,why)
 local waiting=pendingJoins[uid];pendingJoins[uid]=nil
 if waiting and waiting.Parent then
  waiting:SetAttribute('MA_SaveStatus','Previous profile session unavailable — no defaults written')
  waiting:SetAttribute('MA_Notice',why)
 end
end
local function drainPendingJoin(uid,previous)
 if profiles[uid] or loading[uid] then return end
 local waiting=pendingJoins[uid];pendingJoins[uid]=nil
 if waiting and waiting~=previous and waiting.Parent then task.spawn(addPlayer,waiting) end
end
addPlayer=function(pl)
 local current=profiles[pl.UserId]
 if current then
  -- PlayerAdded can race ahead of PlayerRemoving. A distinct same-ID Player
  -- must wait for the prior session even before its leave handler starts.
  if current.player~=pl and pl.Parent then pendingJoins[pl.UserId]=pl end
  return
 end
 if loading[pl.UserId] then
  if loading[pl.UserId]~=pl then pendingJoins[pl.UserId]=pl end
  return
 end
 loading[pl.UserId]=pl
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
   loading[pl.UserId]=nil
   if pl.Parent then pl:SetAttribute('MA_SaveStatus','Previous profile session unavailable — no defaults written');pl:SetAttribute('MA_Notice','Previous session still needs safe reconciliation; try again later.') end
   drainPendingJoin(pl.UserId,pl);return
  end
 end
 local session,err=store:load(pl.UserId)
 loading[pl.UserId]=nil
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
 local p={player=pl,session=session,drones={},tokens=7,bucketAt=now,busy=false,dirty=false,leaving=false,publishDirty=true}
 profiles[pl.UserId]=p
 pl:SetAttribute('MA_TestingEnabled',preview);pl:SetAttribute('MA_DevToolsEnabled',RunService:IsStudio());pl:SetAttribute('MA_NoRestock',false)
 pl:SetAttribute('MA_TestLoadoutLabel','Use RANDOM LOADOUT for 2–5 random drones')
 if preview then
  p.testFleet=roleTestFleet(p,true)
  local equipment=data(p).logistics;equipment.backpack=true
  if #equipment.carriers==0 then
   table.insert(equipment.carriers,{id=tostring(pl.UserId)..':carrier:'..equipment.nextCarrier,droneIds={}})
   equipment.nextCarrier+=1
  end
 end
 local function character(ch)
  local hr=ch:WaitForChild('HumanoidRootPart',10)
  if not hr or not pl.Parent then return end
  local spawnAt=(scene.spawnPosition or home)+Vector3.new(0,4,0);local firstField=scene.fields[1].center
  leaveField(p,nil,nil,true);ch:PivotTo(CFrame.lookAt(spawnAt,Vector3.new(firstField.X,spawnAt.Y,firstField.Z)))
 end
 p.connection=pl.CharacterAdded:Connect(character)
 rebuildFleet(p);logistics:create(p);publish(p)
 if pl.Character then task.spawn(character,pl.Character) end
end
Players.PlayerAdded:Connect(function(pl) task.spawn(addPlayer,pl) end)
local function removePlayer(pl)
 local p=profiles[pl.UserId];if not p or p.leaving then return end
 p.leaving=true;RoleEffects.ClearAbility(pl.UserId);leaveField(p);if p.connection then p.connection:Disconnect() end
 logistics:remove(p)
 for _,d in ipairs(p.drones) do release(d);spend(d);d.model:Destroy();drones[d.id]=nil end
 -- Wait for the one ordered economy operation, then final save/unlock. No default fallback.
 local deadline=os.clock()+12
 while p.busy and os.clock()<deadline do task.wait(.1) end
 local released=false
 if not p.busy then
  consumableService:clear(p)
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
 discoveries:Step()
 elapsed=math.min(elapsed+math.max(0,dt),C.Tick*(C.MaxCatchup or 6))
 local steps=0
 while elapsed>=C.Tick and steps<(C.MaxCatchup or 6) do
  elapsed=elapsed-C.Tick;steps=steps+1
  for _,field in ipairs(patches) do encounterStep(field) end
  logistics:tick(C.Tick)
  for _,p in pairs(profiles) do
   recallFromField(p)
   dispatchOreQueue(p)
   consumableService:step(p,C.Tick)
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
  swarmGrid=Feel.swarmGrid(drones)
  for _,d in pairs(drones) do droneStep(d,C.Tick) end
  for _,field in ipairs(patches) do turretStep(field);encounterStep(field) end
 end
 snapshotElapsed=snapshotElapsed+dt;autosaveElapsed=autosaveElapsed+dt
 if snapshotElapsed>=C.Snapshot then
  local snapshotDt=snapshotElapsed;snapshotElapsed=0
  for _,d in pairs(drones) do snapshotDrone(d) end
  for _,field in ipairs(patches) do
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
   local rate,count=respawnRate(field)
   field.model:SetAttribute('MiningDroneCount',count);field.model:SetAttribute('RespawnRate',rate)
   local replenishing=field.e.phase=='Safe' or field.e.phase=='Cleared' or unlockedMiners(field)
   if replenishing then field.respawnClock+=snapshotDt*rate end
   table.sort(field.respawnQueue)
   local replenished=0
   while replenishing and #field.respawnQueue>0 and field.respawnClock>=field.respawnQueue[1] and replenished<field.cfg.Count do
    local due=0;for _,at in ipairs(field.respawnQueue) do if at<=field.respawnClock then due=due+1 end end
    -- A geode reserves five future nodes. Consume five due replenishment tokens,
    -- rather than leaving four immortal retries behind after every shell cycle.
    local spawned,cost=spawnResource(field,due<5 and 'Crystal' or nil)
    if not spawned then
     -- One failed sample set establishes a field-level backoff for every token
     -- already due, rather than re-running 18 raycasts per snapshot for each
     -- blocked missing slot in turn. Future tokens keep their own due times.
     for i,at in ipairs(field.respawnQueue) do
      if at<=field.respawnClock then field.respawnQueue[i]=field.respawnClock+2 end
     end
     table.sort(field.respawnQueue);break
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
   serviceDeliveries(p);p.player:SetAttribute('MA_InAssault',activeAssault(p));if not p.busy then settleRuntime(p) end;if p.publishDirty then p.publishDirty=false;publish(p) end end
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
