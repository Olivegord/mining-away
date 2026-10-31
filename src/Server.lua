-- Server simulation, validated intent, and durable profile boundaries.
-- The builder lexically provides Config/Feel/Mining/Rules/Profile/Cards/Persistence/World.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local RoleConfig: any,RoleEffects: any,DiscoveryService: any=DroneConfig,DroneRoleEffects,MiningDiscoveries
local C: any,R: any=Config,Rules
local Pro: any,Ca: any=Profile,Cards
local scene: any=World.initialize()
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
local loading: {[number]: any}={}
-- At most one replacement Player may wait per user. A reconnect cannot acquire
-- another lease until the retiring local session is saved and released.
local pendingJoins: {[number]: any}={}
local now=workspace:GetServerTimeNow()
local elapsed,snapshotElapsed,autosaveElapsed=0,0,0
local seed=Random.new()
local instanceId=(game.JobId~='' and game.JobId or Http:GenerateGUID(false))
local preview=RunService:IsStudio() or game.GameId==0
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
 local copy=Pro.clone(data(p));copy.capacity=Ca.capacity(copy);copy.cargoUnits=Pro.cargoUnits(copy);copy.nextPackPrice=Ca.price(copy);copy.prestigePreview=Pro.prestigePreview(copy)
 copy.deliveryUnits=0;for _,manifest in pairs(copy.run.deliveries) do for _,units in pairs(manifest.cargo) do copy.deliveryUnits+=units end end
 copy.droneStats={};copy.droneRoles={};for _,owned in ipairs(copy.fleet) do copy.droneStats[owned.id]=Ca.stats(copy,owned);copy.droneRoles[owned.id]=owned.role end
 local autoMine,autoHaul=false,false
 for _,d in ipairs(p.drones) do
  autoMine=autoMine or ((d.role~='Courier' and d.role~='Medic') and (d.stats.plotAuto or 0)>0);autoHaul=autoHaul or d.role=='Courier'
 end
 p.player:SetAttribute('BackpackUnits',copy.cargoUnits);p.player:SetAttribute('BackpackCapacity',copy.capacity)
 p.player:SetAttribute('AutomationMineEnabled',autoMine);p.player:SetAttribute('AutomationHaulEnabled',autoHaul)
 p.player:SetAttribute('QueuedOreCount',#(p.oreQueue or {}))
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
local function updateSlots(r)
 local count=0;for _ in pairs(r.slots) do count=count+1 end
 if r.part and r.part.Parent then r.part:SetAttribute('SlotsUsed',count) end
end
local function release(d: any,keepCombatEffects: boolean?,keepBreakContact: boolean?): ()
 if d.target then local r=d.target;r.slots[d.id]=nil;updateSlots(r) end
 d.target=nil;d.mining=false;d.beamSince=0;d.warmAt=nil;d.mineCharge=0;d.forkUntil=0;d.forkTargetId=nil;d.combatTarget=nil;d.targetPosition=nil
 if not keepBreakContact then d.mineBreakContact=nil end
 if not keepCombatEffects then d.chainUntil=0;d.chainTargetId=nil end
 if not keepCombatEffects then d.chargeAt=nil;d.chargeTarget=nil end
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
local function leaveField(p: any,keepField: number?,keepBreakContact: boolean?): ()
 p.oreQueue={}
 local runId=data(p).run.id
 for _,field in ipairs(patches) do
  if field.id~=keepField then
   R.removeUser(field.e,p.player.UserId,runId)
  end
 end
 for _,d in ipairs(p.drones) do release(d,false,keepBreakContact);spend(d);d.field=nil;d.autoField=nil;d.state=d.hp>0 and 'Return' or d.state end
end
local colors={Blue=Color3.fromRGB(86,190,255),Red=Color3.fromRGB(255,110,118),Green=Color3.fromRGB(116,230,157)}
local TEST_ROLES={}
for _,name in ipairs(RoleConfig.TypeOrder) do
 local role=RoleConfig.StudioRoles[name];colors[name]=RoleConfig.Types[name].Color
 table.insert(TEST_ROLES,{type=name,name=name,height=role.height,base=role.base})
end
local function runtimeFleet(p: any) return p.testFleet or data(p).fleet end
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
 return fleet
end
local function spawnDrone(p,owned,slot)
 local stats=Ca.stats(data(p),owned)
 local roleName=owned.role or owned.type
 local role=RoleConfig.StudioRoles[roleName]
 local flightHeight=owned.flightHeight or (role and role.height) or Feel.FollowHeight
 local pos=home+Vector3.new(0,flightHeight,0)+Feel.formation(slot,#runtimeFleet(p))
 local model,body,emitter=World.drone(droneFolder,RS:FindFirstChild('Drone'),pos,colors[owned.type] or colors.Blue)
 model,body,emitter=RoleConfig.decorate(model,roleName)
 model.Name='Drone_'..owned.id
 local d={id=owned.id,owner=p.player.UserId,owned=owned,name=owned.name,role=owned.role or owned.type,flightHeight=flightHeight,model=model,body=body,emitter=emitter,slot=slot,
  pos=pos,goal=pos,yaw=0,life=1,state='Follow',hp=stats.maxHealth,stats=stats,field=nil,target=nil,mining=false,
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
  local old=d.stats.maxHealth;local stats=Ca.stats(data(p),d.owned)
  if d.hp>0 then d.hp=math.min(stats.maxHealth,math.max(1,d.hp+math.max(0,stats.maxHealth-old))) end
  d.stats=stats
 end
end
local function kill(d)
 if d.hp<=0 then return end
 release(d);spend(d);d.field=nil;d.autoField=nil;R.reprint(d,now,C.Reprint+C.Assembly)
 d.model:SetAttribute('DeathSerial',(d.model:GetAttribute('DeathSerial') or 0)+1)
end
local function playerCanMine(p,field)
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
local function makeResource(field,position,kind,maxHealth,ore,visualSize)
 resourceSerial=resourceSerial+1
 local template=RS:FindFirstChild('Crystal');template=template and template:FindFirstChild('Mesh',true)
 local part
 if template and template:IsA('BasePart') then part=template:Clone()
 else part=World.part(field.model,'Crystal',position,Vector3.one,field.color,Enum.Material.Neon) end
 for _,v in ipairs(part:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Sound') then v:Destroy()
  elseif v:IsA('ParticleEmitter') or v:IsA('Beam') or v:IsA('Trail') then v.Enabled=false end
 end
 local shell=kind=='Geode';local size=visualSize or (maxHealth/(shell and 37.5 or 25))*(kind=='Shard' and .8 or 1)
 local fullSize=Vector3.one*size
 local start=Vector3.new(position.X,field.center.Y,position.Z)
 local finish=Vector3.new(position.X,field.center.Y+2+size/2,position.Z)
 part.Name=kind;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=true;part.Size=fullSize;part.Position=finish
 part.Color=shell and Color3.fromRGB(96,85,117) or field.color;part.Material=Enum.Material.SmoothPlastic;part.Reflectance=0;part.Parent=field.model
 local r={id=instanceId..':r'..resourceSerial,field=field,part=part,hp=maxHealth-10,maxHP=maxHealth,fullSize=fullSize,position=finish,start=start,
  slots={},limit=shell and 3 or 1,kind=kind,paid=false,ore=ore,hardness=field.cfg.Hardness or 1,spawnAt=now,readyAt=now+2,stage=0,stageSeed=seed:NextInteger(1,1000000),removeAt=nil}
 resources[r.id]=r;table.insert(field.resources,r)
 for k,v in pairs({ResourceId=r.id,FieldId=field.id,Kind=kind,Hardness=r.hardness,HP=maxHealth,MaxHP=maxHealth,Stage=0,StageSeed=r.stageSeed,SpawnAt=now,ReadyAt=r.readyAt,FullSize=fullSize,FullPosition=finish,StartPosition=start,BreakSerial=0,SlotCapacity=r.limit,SlotsUsed=0}) do part:SetAttribute(k,v) end
 return r
end
local function spawnResource(field,forceKind)
 local usage=nodeUsage(field);if usage>=field.cfg.Count then return false end
 local kind=forceKind or ((field.id>1 and field.cfg.Count-usage>=5 and seed:NextNumber()<.12) and 'Geode' or 'Crystal')
 if kind=='Geode' and field.cfg.Count-usage<5 then kind='Crystal' end
 local clearance=RaycastParams.new();clearance.FilterType=Enum.RaycastFilterType.Include;clearance.FilterDescendantsInstances={scene.map}
 local fieldTop=field.part.Position.Y+field.part.Size.Y/2
 local spot
 for _=1,18 do
  local inset=kind=='Geode' and 6 or 3
  local localPos=Vector3.new(seed:NextNumber(-field.part.Size.X/2+inset,field.part.Size.X/2-inset),0,seed:NextNumber(-field.part.Size.Z/2+inset,field.part.Size.Z/2-inset))
  local candidate=field.part.CFrame:PointToWorldSpace(localPos);local valid=true
  for _,r in ipairs(field.resources) do if not r.paid and (Vector3.new(candidate.X,0,candidate.Z)-Vector3.new(r.position.X,0,r.position.Z)).Magnitude<(kind=='Geode' and 7 or 4) then valid=false;break end end
  if valid then
   for _,t in ipairs(field.turrets) do
    if (Vector3.new(candidate.X,0,candidate.Z)-Vector3.new(t.body.Position.X,0,t.body.Position.Z)).Magnitude<(kind=='Geode' and 9 or 7) then valid=false;break end
   end
  end
  if valid then
   -- Query only the map's solid scenery, above the complete crystal volume.
   -- Decorative parts are non-queryable; field beds/nodes/guards are outside
   -- this filter. Start above the current cliffs so an inside-origin ray cannot
   -- miss an outcrop that would bury the resource. Sampling remains bounded.
   local origin=Vector3.new(candidate.X,field.center.Y+64,candidate.Z)
   if workspace:Raycast(origin,Vector3.new(0,fieldTop+.05-origin.Y,0),clearance) then valid=false end
  end
  if valid then spot=candidate;break end
 end
 if not spot then return false end
 local mineral=Mining.resource(seed:NextInteger(50,100),kind,field.cfg.Hardness)
 makeResource(field,spot,kind,mineral.maxHP,field.cfg.Ore,mineral.size)
 return true,kind=='Geode' and 5 or 1
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
end
local prices={};for _,field in ipairs(patches) do prices[field.cfg.Material or field.cfg.Key or field.cfg.Name]=field.cfg.Value end
local discoveries=DiscoveryService.new(root,RoleConfig.Discoveries,function(player)
 local p=profiles[player.UserId];if not healthy(p) then return nil end
 local hr=characterRoot(p);if not hr then return nil end
 return {root=hr,runId=data(p).run.id}
end)
local function award(d: any,r: any)
 local p=profiles[d.owner];if not healthy(p) or not playerCanMine(p,r.field) then return end
 local profile=data(p);local material=r.field.cfg.Material or r.field.cfg.Key or r.field.cfg.Name
 local amount=r.ore*d.stats.yieldMultiplier*discoveries:Multiplier(p.player,'Yield')+(profile.run.yieldRemainders[material] or 0)
 local units=math.floor(amount);profile.run.yieldRemainders[material]=amount-units
 Pro.addMiningCargo(profile,material,units,Ca.capacity(profile),d.id);p.dirty=true;p.publishDirty=true
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
hitResource=function(d: any,r: any,amount: number,secondary: boolean?,secondaryRange: number?)
 local p=profiles[d.owner]
 if not healthy(p) or d.hp<=0 or r.paid or r.hp<=0 or not r.part.Parent or not R.finite(amount) or amount<=0 or not r.slots[d.id] or not playerCanMine(p,r.field) or now<r.readyAt then return false end
 local recipient=d
 if secondary then
  for id in pairs(r.slots) do
   local worker=drones[id]
   if worker and worker~=d and worker.target==r then
    if worker.owner~=d.owner then return false end
    if recipient==d or worker.id<recipient.id then recipient=worker end
   end
  end
 end
 if d.role=='Courier' or d.role=='Medic' or Pro.cargoUnits(data(p))>=Ca.capacity(data(p)) then return false end
 if secondary then
  local primary=d.target
  -- The synchronous primary resolver alone can retain its contact through a
  -- final hit. No saved state/remote can authorize an echo from a retired node.
  if not primary or primary.field~=r.field or not primary.slots[d.id] or (primary.paid and primary.processingPrimary~=d.id) or (r.position-primary.position).Magnitude>(secondaryRange or d.stats.forkRange or 6) or (d.pos-r.position).Magnitude>d.stats.range or (d.pos-Feel.mineGoal(primary.position,d.targetSlot,primary.kind=='Geode',primary.fullSize)).Magnitude>1 or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
 elseif d.target~=r or (d.pos-Feel.mineGoal(r.position,d.targetSlot,r.kind=='Geode',r.fullSize)).Magnitude>1 or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
 local baseAmount=amount
 local discoverySpeed=discoveries:Multiplier(p.player,'Speed')
 amount=amount*discoverySpeed
 amount=amount*Mining.efficiency(d.owned.type,r.kind)
 if r.kind=='Geode' or r.kind=='Core' then amount=amount*(d.stats.geodeMultiplier or 1) end
 if secondary then d.forkTarget=r.position;d.forkTargetId=r.id;d.forkUntil=now+.18 end
 if not secondary then r.processingPrimary=d.id end
 local previous=r.stage
 local broken=R.damage(r,amount)
 local actual=r.paid and 0 or r.hp+10
 r.stage=Feel.stage(actual,r.maxHP)
 if r.stage~=previous then r.part:SetAttribute('Stage',r.stage) end
 r.part:SetAttribute('HP',actual)
 if not secondary and Mining.kind(d.owned.type)=='Red' then
  d.minePulseSerial=d.minePulseSerial+1;d.minePulseAt=now;d.minePulseTargetId=r.id
 end
 if broken then
  r.part:SetAttribute('BreakSerial',1);r.removeAt=now+2
  if r.kind=='Geode' then
   local core=Mining.resource(seed:NextInteger(50,100),'Core',r.hardness)
   makeResource(r.field,r.position,'Core',core.maxHP,r.ore*4,core.size)
   for n=1,4 do
    local a=n*math.pi/2;local shard=Mining.resource(seed:NextInteger(50,70),'Shard',r.hardness)
    makeResource(r.field,r.position+Vector3.new(math.cos(a)*4,0,math.sin(a)*4),'Shard',shard.maxHP,r.ore,shard.size)
   end
  else award(recipient,r);discoveries:TrySpawn(p.player,r.field.part);table.insert(r.field.respawnQueue,r.field.respawnClock+r.field.cfg.Respawn) end
 end
 if not secondary then
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
  for id in pairs(r.slots) do
   local worker=drones[id]
   if worker and worker.target==r then release(worker,false,not secondary and worker==d and d.mineBreakContact~=nil) else r.slots[id]=nil end
  end
  updateSlots(r)
 end
 return true
end
local function chooseResource(d: any,field: any): ()
 local best,score=nil,math.huge
 for _,r in ipairs(field.resources) do
  if not r.paid and r.hp>0 and r.part.Parent and now>=r.readyAt then
   local used=0;for _ in pairs(r.slots) do used=used+1 end
   if used<r.limit then
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
 return d.stats.maxStep60*(d.role=='Medic' and .68 or (d.role=='Courier' and (1+(d.stats.fullAuto or 0)) or 1))
end
local function move(d,goal,dt)
 local settling=(d.target~=nil and (d.state=='Travel' or d.state=='Mine')) or d.state=='Deliver' or d.state=='Collect'
 local weight=settling and math.clamp(((goal-d.pos).Magnitude-1)/5,0,1) or 1
 d.swarmOffset=Feel.swarmOffset(d.pos,d.id,swarmGrid,weight)
 goal=goal+d.swarmOffset
 d.goal=goal;local delta=goal-d.pos
 if delta.X*delta.X+delta.Z*delta.Z>1e-6 then
  local target=math.atan2(-delta.X,-delta.Z);local diff=(target-d.yaw+math.pi)%(math.pi*2)-math.pi
  d.yaw=d.yaw+diff*Feel.turnAlpha(dt)
 end
 local approach=((d.target and (d.state=='Travel' or d.state=='Mine')) or d.state=='Deliver') and Feel.approachWork or Feel.approach
 local speed=travelSpeed(d)
 d.pos=approach(d.pos,goal,speed,dt)
 -- Exact logical pose; no server presentation lerp, no body pitch.
 d.model:PivotTo(CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0))
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
 local goal=best and best.pos+Vector3.new(2,1,2) or hr.Position+Vector3.new(3,d.flightHeight,3)
 d.state='Support';d.mining=false;move(d,goal,dt)
 if best and best.hp<best.stats.maxHealth and now>=(d.healAt or 0) and (best.pos-d.pos).Magnitude<=RoleConfig.Types.Medic.AttackRange and los(d.pos,best.pos,best.model,{droneFolder,p.player.Character}) then
  best.hp=math.min(best.stats.maxHealth,best.hp+RoleConfig.Types.Medic.HealAmount)
  d.healAt=now+RoleConfig.Types.Medic.AttackCooldown;d.healTargetId=best.id;d.healUntil=now+.45
  best.model:SetAttribute('RepairSerial',(best.model:GetAttribute('RepairSerial') or 0)+1)
 end
 if now<(d.healUntil or 0) then d.state='Heal' else d.healTargetId=nil end
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
local function mineDrone(d: any,p: any,field: any,dt: number)
 if d.combatTarget or d.state=='Attack' then release(d);d.chargeAt=nil;d.chargeTarget=nil end
 if Pro.cargoUnits(data(p))>=Ca.capacity(data(p)) then
  d.mining=false;d.warmAt=nil;d.mineCharge=0
  d.state='Follow'
  local hr=characterRoot(p)
  move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
  return
 end
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 -- Only the Plot Scanner card chooses an unclicked next resource.
 if not d.target and d.autoField==field.id and (d.stats.plotAuto or 0)>0 then chooseResource(d,field) end
 local r=d.target
 if r then
  local goal=Feel.mineGoal(r.position,d.targetSlot,r.kind=='Geode',r.fullSize);d.state='Travel';move(d,goal,dt)
  if Feel.canMine((d.pos-goal).Magnitude,now>=r.readyAt,true,d.hp>0) and los(d.pos,r.position,r.part,{droneFolder}) then
   d.warmAt=d.warmAt or now;d.state='Mine'
   if now-d.warmAt>=d.stats.warmup then
    if not d.mining then d.beamSince=now end
    d.mining=true
    local damage,charge=Mining.step(d.owned.type,d.mineCharge,dt,d.stats.miningDPS);d.mineCharge=charge
    if damage>0 then hitResource(d,r,damage) end
   end
  else d.warmAt=nil;d.mineCharge=0;d.mining=false end
 else
  -- Workers without a current stone regroup with the player. Plot orders may
  -- find another stone later; manual clicks are dispatched next simulation step.
  d.state='Follow';d.mining=false
  if not d.autoField then local old=d.field;d.field=nil;dropFieldIfEmpty(p,old) end
  local hr=characterRoot(p)
  move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
 end
end
local function droneStep(d: any,dt: number)
 local p=profiles[d.owner];if not p then return end
 if d.hp<=0 then
  d.state=now>=d.readyAt-C.Assembly and 'Reprinting' or 'Destroyed';d.pos=scene.printer.Position+Vector3.new((d.slot-1)%4*2,3,math.floor((d.slot-1)/4)*2);d.goal=d.pos
  d.model:PivotTo(CFrame.new(d.pos))
  if R.finishReprint(d,now,d.stats.maxHealth) then d.field=nil;d.commandOutAt=nil end
  return
 end
 -- Freeze the job during a yielding save; no damage or profile mutation occurs.
 -- Shift the warmup clock so storage latency cannot skip weapon startup.
 if p.busy then
  if d.warmAt then d.warmAt=d.warmAt+dt end
  if d.chargeAt then d.chargeAt=d.chargeAt+dt end
  return
 end
 if not store:healthy(p.session) then release(d);return end
 local hr=characterRoot(p)
 if not hr then if d.field then leaveField(p) end;move(d,home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,d.flightHeight or Feel.FollowHeight,0),dt);return end
 local manifest=data(p).run.deliveries and data(p).run.deliveries[d.id]
 if manifest then
  if d.target or d.combatTarget then release(d) end
  d.state='Deliver';d.deliveryId=manifest.id
  local depot=scene.converter or scene.packStation
  local offset=Feel.formation(d.slot,#p.drones);if offset.Magnitude>6 then offset=offset.Unit*6 end
  local goal=depot.Position+offset+Vector3.new(0,d.flightHeight,0)
  move(d,goal,dt);d.deliveryArrived=(d.pos-goal).Magnitude<1
  return
 end
 if d.role=='Courier' then
  d.mining=false;d.field=nil
  if Pro.cargoUnits(data(p))>0 and now>=(d.collectAfter or 0) then
   d.state='Collect';move(d,hr.Position+Vector3.new(-1,d.flightHeight,1),dt)
   if (d.pos-hr.Position).Magnitude<=RoleConfig.Courier.PickupDistance then d.deliveryRequested=true end
  else
   d.state='Follow'
   move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
  end
  return
 elseif d.role=='Medic' then supportDrone(d,p,hr,dt);return end
 local field=d.field and patches[d.field]
 -- Cleared/safe mining orders are independent jobs. Combat still has the
 -- owner leash and server-owned guard participation.
 local idleManual=field and not d.autoField and not d.target
 if field and (not playerCanMine(p,field) or idleManual) and (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then
  d.commandOutAt=d.commandOutAt or now
  if now-d.commandOutAt>3 then leaveDroneField(p,d);field=nil end
 else d.commandOutAt=nil end
 if field then
  if field.e.phase=='Active' and R.participates(field.e,d,data(p).run.id) then
   attackDrone(d,field,dt)
  elseif playerCanMine(p,field) then
   if (hr.Position-field.center).Magnitude>RoleConfig.Mining.BackpackRange then
    -- Ore goes into a backpack carried by the owner. Leaving the plot brings
    -- the swarm along; saved jobs resume when the player returns to work.
    d.mining=false;d.warmAt=nil;d.mineCharge=0;d.state='Follow'
    move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)+Vector3.new(0,d.flightHeight-Feel.FollowHeight,0),dt)
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
 local profile=data(profiles[d.owner])
 local target=d.target
 if target and (target.paid or target.hp<=0 or not target.part.Parent) then release(d);target=nil end
 local breakContact=d.mineBreakContact
 if breakContact and (now>=breakContact.untilTime or not healthy(profiles[d.owner]) or d.hp<=0) then d.mineBreakContact=nil;breakContact=nil end
 if (d.forkUntil or 0)<=now then d.forkTargetId=nil end
 if (d.chainUntil or 0)<=now then d.chainTargetId=nil end
 local combatTarget=d.state=='Attack' and d.mining and d.combatTarget
 local combatId=combatTarget and combatTarget.hp>0 and combatTarget.model.Parent and combatTarget.model:GetAttribute('TurretId') or ''
 local mining=d.state=='Mine' and d.mining and target~=nil
 local values={Owner=d.owner,DroneId=d.id,DroneName=d.name,Name=d.name,Type=d.owned.type,Role=d.role,FlightHeight=d.flightHeight or Feel.FollowHeight,Life=d.life,State=d.state,HP=d.hp,MaxHP=d.stats.maxHealth,ChargeAt=d.chargeAt or 0,Firing=combatId~='',
  Position=d.pos,Goal=d.goal,SwarmOffset=d.swarmOffset or Vector3.zero,Yaw=d.yaw,MotionPaused=(profiles[d.owner].busy or not store:healthy(profiles[d.owner].session)) and d.hp>0,MaxStep60=travelSpeed(d),PhaseSeed=d.owned.base.maxStep60*200,FormationSlot=d.slot,FleetCount=#profiles[d.owner].drones,
  TargetId=target and target.id or '',CombatTargetId=combatId,TargetPosition=target and target.position or (combatId~='' and combatTarget.emitter.Position) or d.pos,Mining=mining,BeamSince=d.beamSince,WarmupStart=d.warmAt or 0,WarmupDuration=d.stats.warmup,
  MiningStyle=Mining.style(d.owned.type),MinePulseSerial=d.minePulseSerial,MinePulseAt=d.minePulseAt,MinePulseTargetId=d.minePulseTargetId,
  DeliveryUnits=Pro.deliveryUnits(profile,d.id),AutoFieldId=d.autoField or 0,
  Healing=d.hp>0 and d.healTargetId~=nil and now<(d.healUntil or 0),HealTargetId=d.healTargetId or '',
  AutomationMineEnabled=d.role~='Courier' and d.role~='Medic' and (d.stats.plotAuto or 0)>0,AutomationHaulEnabled=d.role=='Courier',WorkRole=Mining.workRole(d.role),
  MineBreakSerial=d.mineBreakSerial,MineBreakAt=breakContact and breakContact.at or 0,MineBreakUntil=breakContact and breakContact.untilTime or 0,
  MineBreakPrimaryId=breakContact and breakContact.primaryId or '',MineBreakSecondaryId=breakContact and breakContact.secondaryId or '',MineBreakBeamSince=breakContact and breakContact.beamSince or 0,
  ReprintAt=d.hp<=0 and d.readyAt or 0,SnapshotAt=now,ShotSerial=d.shotSerial,ShotAt=d.lastShotAt,LastCritAt=d.lastCritAt,Shield=d.shield,
  ForkTargetPosition=d.forkTarget or d.pos,ForkTargetId=(d.forkUntil or 0)>now and (d.forkTargetId or '') or '',ForkUntil=d.forkUntil or 0,
  ChainTargetPosition=d.chainTarget or d.pos,ChainTargetId=(d.chainUntil or 0)>now and (d.chainTargetId or '') or '',ChainUntil=d.chainUntil or 0,
  GeodeMultiplier=d.stats.geodeMultiplier,FinisherMultiplier=d.stats.finisherMultiplier,SalvageFraction=d.stats.salvageFraction,ChainRange=d.stats.splashRange}
 for k,v in pairs(values) do d.model:SetAttribute(k,v) end
end
-- Publish pause transitions immediately, not only on the periodic snapshot.
-- Resume position and goal are sent before the pause flag is cleared.
local function setMotionPaused(p: any,paused: boolean)
 for _,d in ipairs(p.drones) do
  if d.model and d.model.Parent and d.hp>0 then
   if paused then
    d.mineBreakContact=nil;d.model:SetAttribute('MineBreakUntil',0);d.model:SetAttribute('MineBreakPrimaryId','');d.model:SetAttribute('MineBreakSecondaryId','')
   end
   d.model:SetAttribute('Position',d.pos);d.model:SetAttribute('Goal',d.goal);d.model:SetAttribute('Yaw',d.yaw)
   d.model:SetAttribute('MotionPaused',paused)
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
local function assignOre(p: any,d: any,r: any): boolean
 local occupied={};for _,slot in pairs(r.slots) do occupied[slot]=true end
 local slot=1;while slot<=r.limit and occupied[slot] do slot+=1 end
 if slot>r.limit then return false end
 local old=d.field;release(d);spend(d)
 d.autoField=nil;d.field=r.field.id;d.target=r;d.targetSlot=slot;d.state='Travel';d.commandOutAt=nil
 r.slots[d.id]=slot;updateSlots(r)
 if old~=d.field then dropFieldIfEmpty(p,old) end
 return true
end
local function dispatchOreQueue(p: any)
 if not healthy(p) or not characterRoot(p) or activeAssault(p) then return end
 local queue=p.oreQueue or {};local index=1
 while index<=#queue do
  local r=resources[queue[index]]
  if not r or r.paid or r.hp<=0 or not r.part.Parent or not playerCanMine(p,r.field) then table.remove(queue,index);p.publishDirty=true
  else
   local best,distance=nil,math.huge
   for _,d in ipairs(p.drones) do
    if d.hp>0 and d.role~='Courier' and d.role~='Medic' and not d.target and Pro.cargoUnits(data(p))<Ca.capacity(data(p)) then
     local n=(d.pos-r.position).Magnitude
     if n<distance then best,distance=d,n end
    end
   end
   if not best then break end
   if assignOre(p,best,r) then table.remove(queue,index);p.publishDirty=true else index+=1 end
  end
 end
 p.oreQueue=queue
end
local function serviceDeliveries(p: any)
 if not healthy(p) or not characterRoot(p) or now<(p.nextDeliveryAction or 0) then return end
 local run=data(p).run
 for _,d in ipairs(p.drones) do
  local manifest=run.deliveries[d.id]
  if d.hp>0 and manifest and d.deliveryArrived and d.deliveryId==manifest.id and (d.pos-(scene.converter or scene.packStation).Position).Magnitude<=10 then
   local tx,runId,id=manifest.id,run.id,d.id
   p.nextDeliveryAction=now+.4
   transact(p,'deliveryFinish:'..tx,function(copy)
    local ok,result=Pro.finishDelivery(copy,id,prices,tx,runId);if ok then return result end;return nil,result
   end,function()
    local worker=drones[id]
    if worker and worker.owner==p.player.UserId then
     worker.deliveryArrived=false;worker.deliveryId=nil;worker.deliveryRequested=false
     worker.field=nil;worker.autoField=nil;worker.state='Collect';worker.collectAfter=now+RoleConfig.Courier.PickupCooldown
    end
    p.publishDirty=true
   end)
   return
  elseif d.role=='Courier' and d.hp>0 and d.deliveryRequested and not manifest and now>=(d.collectAfter or 0) then
   local hr=characterRoot(p)
   if Pro.cargoUnits(data(p))==0 or (d.pos-hr.Position).Magnitude>RoleConfig.Courier.PickupDistance then d.deliveryRequested=false
   else
    local tx,runId,id=Http:GenerateGUID(false),run.id,d.id
    p.nextDeliveryAction=now+1
    transact(p,'deliveryBegin:'..tx,function(copy)
     local ok,result=Pro.beginDelivery(copy,id,tx,runId,RoleConfig.Courier.BatchUnits);if ok then return result end;return nil,result
    end,function(result)
     local worker=drones[id]
     if worker and worker.owner==p.player.UserId then
      release(worker);worker.deliveryId=result.id;worker.deliveryArrived=false;worker.state='Deliver'
     end
     p.publishDirty=true
    end)
    return
   end
  end
 end
end
local function sellBackpack(p: any)
 if not atStation(p,scene.converter or scene.packStation,18) then notice(p,'Bring your backpack back to the Converter to sell.');return end
 if Pro.cargoUnits(data(p))==0 then notice(p,'Your backpack is empty.');return end
 local expected=data(p).run.id;local tx='sale:'..Http:GenerateGUID(false)
 transact(p,tx,function(copy) local ok,result=Pro.sell(copy,prices,tx,expected);if ok then return result end;return nil,result end,function(result)
  notice(p,'Backpack sold for '..tostring(result.credits)..' credits.');p.publishDirty=true
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
  p.oreQueue={};rebuildFleet(p);notice(p,'Prestige complete. One new permanent drone; a fresh run.')
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
local function commandPlayer(pl: any,action: any,payload: any)
 local p=profiles[pl.UserId];if not p or p.player~=pl then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerReply(pl,payload,'rejected','Fleet unavailable') end;return end
 if action=='ChooseCard' and committedOffer(p,payload) then offerReply(pl,payload,'accepted','Card installed');return end
 local duration=math.max(0,now-p.bucketAt);p.tokens=math.min(7,p.tokens+duration*3);p.bucketAt=now
 if p.tokens<1 then if now>=(p.nextCommandRejection or 0) then p.nextCommandRejection=now+.35;commandReply(pl,payload,'rejected','Too many commands');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Too many commands') end end;return end;p.tokens=p.tokens-1
 if type(action)~='string' or #action>24 or not healthy(p) or not characterRoot(p) then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Fleet unavailable') end;return end
 if action=='TestLoadout' then
  if not preview or now<(p.nextTestLoadout or 0) then return end
  p.nextTestLoadout=now+RoleConfig.Settings.RandomizeCooldown;pl:SetAttribute('MA_TestReadyAt',p.nextTestLoadout)
  leaveField(p);p.testFleet=randomTestFleet(p);rebuildFleet(p)
  notice(p,'Random test loadout ready — no scrap spent, no saved fleet changed.')
 elseif action=='Recall' then
  leaveField(p)
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
  if d.life~=payload.life or d.hp<=0 or not R.allowed(d.owner,pl.UserId,d.state) then reject('Drone reprinted or unavailable',nil,d);return end
  if action=='CancelDrone' then
   local old=d.field;release(d);spend(d);d.field=nil;d.autoField=nil;d.state='Return';dropFieldIfEmpty(p,old)
   commandReply(pl,payload,'accepted','Drone recalled',patches[old],d);return
  end
  if not R.finite(payload.fieldId) or payload.fieldId%1~=0 or type(payload.resourceId)~='string' or #payload.resourceId>160 then reject('Invalid request',nil,d);return end
  local field=patches[payload.fieldId];local r=resources[payload.resourceId]
  if not field or (characterRoot(p).Position-field.center).Magnitude>(C.CommandRadius or 90) then reject('Too far from field',field,d);return end
  if not playerCanMine(p,field) or activeAssault(p) then reject('Clear guards first',field,d);return end
  if (characterRoot(p).Position-field.center).Magnitude>RoleConfig.Mining.BackpackRange then reject('Move closer to the plot to mine',field,d);return end
  if field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if d.role=='Courier' or d.role=='Medic' then reject('Choose a mining drone',field,d);return end
  if Pro.cargoUnits(data(p))>=Ca.capacity(data(p)) then reject('Bring your full backpack to sell',field,d);return end
  if not r or r.field~=field or not r.part.Parent or r.paid or r.hp<=0 then reject('Crystal unavailable',field,d);return end
  if now<r.readyAt then reject('Crystal still growing',field,d,r);return end
  if d.target==r and d.field==field.id and r.slots[d.id] then commandReply(pl,payload,'accepted','Already assigned',field,d,r,r.slots[d.id]);return end
  local occupied={};for _,v in pairs(r.slots) do occupied[v]=true end
  local slot=1;while slot<=r.limit and occupied[slot] do slot=slot+1 end
  if slot>r.limit then reject('Resource is busy',field,d,r);return end
  local old=d.field;release(d);spend(d);d.autoField=nil;d.field=field.id;d.target=r;d.targetSlot=slot;r.slots[d.id]=slot;updateSlots(r);d.state='Travel';d.shotAt=now
  if old~=field.id then dropFieldIfEmpty(p,old) end
  commandReply(pl,payload,'accepted','Drone assigned',field,d,r,slot)
 elseif action=='MineOre' then
  if type(payload)~='string' or #payload>160 then return end
  local r=resources[payload];local hr=characterRoot(p)
  if not r or r.paid or r.hp<=0 or not r.part.Parent then return end
  if (hr.Position-r.field.center).Magnitude>RoleConfig.Mining.BackpackRange then notice(p,'Move closer to that ore.');return end
  if activeAssault(p) or not playerCanMine(p,r.field) then notice(p,'Clear the guards before mining.');return end
  if Pro.cargoUnits(data(p))>=Ca.capacity(data(p)) then notice(p,'Backpack full. Bring it back to sell.');return end
  if r.field.cfg.Turrets>0 and r.field.e.phase=='Cleared' then grantClear(p,r.field) end
  p.oreQueue=p.oreQueue or {}
  for _,d in ipairs(p.drones) do if d.target==r then return end end
  for _,id in ipairs(p.oreQueue) do if id==r.id then return end end
  if #p.oreQueue>=16 then notice(p,'Ore queue full. Let the workers finish or recall to clear it.');return end
  table.insert(p.oreQueue,r.id);dispatchOreQueue(p)
 elseif action=='ReturnCargo' then
  if payload~=nil and (type(payload)~='string' or #payload>160) then return end
  sellBackpack(p)
 elseif action=='Patch' then
  local fieldId=type(payload)=='table' and payload.fieldId or payload
  if type(payload)=='table' and not validCommandId(payload.requestId) then return end
  if not R.finite(fieldId) or fieldId%1~=0 then commandReply(pl,payload,'rejected','Invalid field');return end
  local field=patches[fieldId];local hr=characterRoot(p)
  if not field or (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then commandReply(pl,payload,'rejected','Too far from field',field);return end
  local can=playerCanMine(p,field)
  if can and field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if can then
   if (hr.Position-field.center).Magnitude>RoleConfig.Mining.BackpackRange then commandReply(pl,payload,'rejected','Move closer to the plot to mine',field);return end
   if activeAssault(p) then commandReply(pl,payload,'rejected','Recall fighting drones first',field);return end
   local assigned=0
   for _,d in ipairs(p.drones) do
    if d.hp>0 and d.role~='Medic' and d.role~='Courier' and (d.stats.plotAuto or 0)>0 and Pro.cargoUnits(data(p))<Ca.capacity(data(p)) then
     local old=d.field
     if old~=field.id then release(d);spend(d);d.field=field.id;d.state='Travel';d.shotAt=now end
     d.autoField=field.id;d.commandOutAt=nil;assigned+=1
     if old~=field.id then dropFieldIfEmpty(p,old) end
    end
   end
   if assigned==0 then commandReply(pl,payload,'rejected','Click individual ores, or install Plot Scanner for an available worker',field);notice(p,'Click ores first. Plot Scanner unlocks plot orders.');return end
   p.oreQueue={};commandReply(pl,payload,'accepted','Plot survey assigned',field)
  else
   local fleet={}
   for _,d in ipairs(p.drones) do
    if d.hp>0 and d.role~='Courier' and R.allowed(d.owner,pl.UserId,d.state) then table.insert(fleet,d) end
   end
   local fighters=0;for _,d in ipairs(fleet) do if d.role~='Medic' then fighters+=1 end end
   if fighters==0 then commandReply(pl,payload,'rejected','Reprint a fighting drone first',field);return end
   p.oreQueue={}
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
 pl:SetAttribute('MA_TestingEnabled',preview);pl:SetAttribute('MA_NoRestock',false)
 pl:SetAttribute('MA_TestLoadoutLabel','Use RANDOM LOADOUT for 2–5 random drones')
 local function character(ch)
  local hr=ch:WaitForChild('HumanoidRootPart',10)
  if not hr or not pl.Parent then return end
  local spawnAt=home+Vector3.new(0,4,0);local firstField=scene.fields[1].center
  leaveField(p);ch:PivotTo(CFrame.lookAt(spawnAt,Vector3.new(firstField.X,spawnAt.Y,firstField.Z)))
 end
 p.connection=pl.CharacterAdded:Connect(character)
 rebuildFleet(p);publish(p)
 if pl.Character then task.spawn(character,pl.Character) end
end
Players.PlayerAdded:Connect(function(pl) task.spawn(addPlayer,pl) end)
local function removePlayer(pl)
 local p=profiles[pl.UserId];if not p or p.leaving then return end
 p.leaving=true;leaveField(p);if p.connection then p.connection:Disconnect() end
 for _,d in ipairs(p.drones) do release(d);spend(d);d.model:Destroy();drones[d.id]=nil end
 -- Wait for the one ordered economy operation, then final save/unlock. No default fallback.
 local deadline=os.clock()+12
 while p.busy and os.clock()<deadline do task.wait(.1) end
 local released=false
 if not p.busy then
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
  for _,p in pairs(profiles) do dispatchOreQueue(p) end
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
   for i=#field.resources,1,-1 do local r=field.resources[i];if r.paid and r.removeAt and now>=r.removeAt then resources[r.id]=nil;r.part:Destroy();table.remove(field.resources,i) end end
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
  for _,p in pairs(profiles) do serviceDeliveries(p);p.player:SetAttribute('MA_InAssault',activeAssault(p));if not p.busy then settleRuntime(p) end;if p.publishDirty then p.publishDirty=false;publish(p) end end
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
