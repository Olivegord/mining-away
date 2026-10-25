-- Server simulation, validated intent, and durable profile boundaries.
-- The builder lexically provides Config/Feel/Rules/Profile/Cards/Persistence/World.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local C,R=Config,Rules
local scene=World.initialize()
local root,home=scene.root,scene.home
local function folder(parent,name)
 local f=Instance.new('Folder');f.Name=name;f.Parent=parent;return f
end
local droneFolder=root:FindFirstChild('Drones') or folder(root,'Drones')
local net=folder(RS,'MiningAway')
local command=Instance.new('RemoteEvent');command.Name='Command';command.Parent=net
local profiles,drones,patches,resources,loading={},{},{},{},{}
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
 newProfile=function(uid) return Profile.new(uid,seed:NextInteger(1,2147483000)) end,
 migrate=function(data,uid) return Profile.migrate(data,uid) end,validate=Profile.validate,
})
root:SetAttribute('PersistenceMode',preview and 'PREVIEW • isolated temporary profiles' or 'DataStore • session-locked')
root:SetAttribute('Build','restore-feel-prestige')
local function data(p) return p.session.data end
local function healthy(p) return p and not p.leaving and not p.busy and store:healthy(p.session) end
local function notice(p,message)
 if p.player.Parent then p.player:SetAttribute('MA_Notice',message) end
end
local function publish(p)
 if not p.player.Parent then return end
 local copy=Profile.clone(data(p));copy.capacity=Cards.capacity(copy);copy.nextPackPrice=Cards.price(copy);copy.prestigePreview=Profile.prestigePreview(copy)
 copy.droneStats={};for _,owned in ipairs(copy.fleet) do copy.droneStats[owned.id]=Cards.stats(copy,owned) end
 copy.seed=nil;copy.receipts=nil
 if copy.run.pendingOffer then copy.run.pendingOffer.seed=nil end
 copy.saveMode=preview and 'Preview — temporary profiles' or 'Saved profile';copy.pendingTransaction=p.busy or p.session.readOnly or false
 p.player:SetAttribute('MA_Profile',Http:JSONEncode(copy))
 p.player:SetAttribute('MA_SaveStatus',p.session.lost and 'Session lost — progress paused' or (p.session.readOnly and 'Save uncertain — reconciling' or (preview and 'PREVIEW • not saved across restarts' or 'Saved • autosave active')))
end
local function characterRoot(p)
 local ch=p.player.Character;local h=ch and ch:FindFirstChildOfClass('Humanoid');local hr=ch and ch:FindFirstChild('HumanoidRootPart')
 return h and h.Health>0 and hr or nil
end
local function atStation(p,station,radius)
 local hr=characterRoot(p);return hr and (hr.Position-station.Position).Magnitude<(radius or 18)
end
local function atHome(p)
 local hr=characterRoot(p);return hr and (hr.Position-home).Magnitude<30
end
local function release(d)
 if d.target then d.target.slots[d.id]=nil end
 d.target=nil;d.mining=false;d.beamSince=0;d.warmAt=nil
end
local function spend(d)
 for _,p in ipairs(patches) do R.spend(p.e,d.id) end
end
local function leaveField(p,keepField)
 local runId=data(p).run.id
 for _,field in ipairs(patches) do
  if field.id~=keepField then
   R.removeUser(field.e,p.player.UserId,runId)
   if not p.busy then data(p).run.entitlements[tostring(field.id)]=nil else p.entitlementSync=true end
  end
 end
 for _,d in ipairs(p.drones) do release(d);spend(d);d.field=nil;d.state=d.hp>0 and 'Return' or d.state end
end
local colors={Blue=Color3.fromRGB(86,190,255),Red=Color3.fromRGB(255,110,118),Green=Color3.fromRGB(116,230,157)}
local function spawnDrone(p,owned,slot)
 local stats=Cards.stats(data(p),owned)
 local pos=home+Vector3.new(0,7,0)+Feel.formation(slot,#data(p).fleet)
 local model,body,emitter=World.drone(droneFolder,RS:FindFirstChild('Drone'),pos,colors[owned.type])
 model.Name='Drone_'..owned.id
 local d={id=owned.id,owner=p.player.UserId,owned=owned,name=owned.name,model=model,body=body,emitter=emitter,slot=slot,
  pos=pos,goal=pos,yaw=0,life=1,state='Follow',hp=stats.maxHealth,stats=stats,field=nil,target=nil,mining=false,
  beamSince=0,readyAt=0,shotAt=0,shield=0,evade=0,commandOutAt=nil}
 drones[d.id]=d;table.insert(p.drones,d);return d
end
local function rebuildFleet(p)
 for _,d in ipairs(p.drones) do release(d);spend(d);drones[d.id]=nil;d.model:Destroy() end
 p.drones={}
 for i,owned in ipairs(data(p).fleet) do spawnDrone(p,owned,i) end
end
local function refreshStats(p)
 for _,d in ipairs(p.drones) do
  local old=d.stats.maxHealth;local stats=Cards.stats(data(p),d.owned)
  if d.hp>0 then d.hp=math.min(stats.maxHealth,math.max(1,d.hp+math.max(0,stats.maxHealth-old))) end
  d.stats=stats
 end
end
local function kill(d)
 if d.hp<=0 then return end
 release(d);spend(d);d.field=nil;R.reprint(d,now,C.Reprint+C.Assembly)
 d.model:SetAttribute('DeathSerial',(d.model:GetAttribute('DeathSerial') or 0)+1)
end
local function playerCanMine(p,field)
 if field.cfg.Turrets==0 then return true end
 local entitlement=data(p).run.entitlements[tostring(field.id)]
 return type(entitlement)=='table' and R.canMine(field.e,p.player.UserId,data(p).run.id,entitlement.encounterId)
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
local function makeResource(field,position,kind,maxHealth,ore)
 resourceSerial=resourceSerial+1
 local template=RS:FindFirstChild('Crystal');template=template and template:FindFirstChild('Mesh',true)
 local part
 if template and template:IsA('BasePart') then part=template:Clone()
 else part=World.part(field.model,'Crystal',position,Vector3.one,field.color,Enum.Material.Neon) end
 for _,v in ipairs(part:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Sound') then v:Destroy()
  elseif v:IsA('ParticleEmitter') or v:IsA('Beam') or v:IsA('Trail') then v.Enabled=false end
 end
 local shell=kind=='Geode';local size=(maxHealth/(shell and 37.5 or 25))*(kind=='Shard' and .8 or 1)
 local fullSize=Vector3.one*size
 local start=Vector3.new(position.X,field.center.Y,position.Z)
 local finish=Vector3.new(position.X,field.center.Y+2+size/2,position.Z)
 part.Name=kind;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=true;part.Size=fullSize;part.Position=finish
 part.Color=shell and Color3.fromRGB(96,85,117) or field.color;part.Parent=field.model
 local r={id=instanceId..':r'..resourceSerial,field=field,part=part,hp=maxHealth-10,maxHP=maxHealth,fullSize=fullSize,position=finish,start=start,
  slots={},limit=shell and 3 or 1,kind=kind,paid=false,ore=ore,spawnAt=now,readyAt=now+2,stage=0,stageSeed=seed:NextInteger(1,1000000),removeAt=nil}
 resources[r.id]=r;table.insert(field.resources,r)
 for k,v in pairs({ResourceId=r.id,FieldId=field.id,Kind=kind,HP=maxHealth,MaxHP=maxHealth,Stage=0,StageSeed=r.stageSeed,SpawnAt=now,ReadyAt=r.readyAt,FullSize=fullSize,FullPosition=finish,StartPosition=start,BreakSerial=0}) do part:SetAttribute(k,v) end
 return r
end
local function spawnResource(field,forceKind)
 local usage=nodeUsage(field);if usage>=field.cfg.Count then return false end
 local kind=forceKind or ((field.id>1 and field.cfg.Count-usage>=5 and seed:NextNumber()<.12) and 'Geode' or 'Crystal')
 if kind=='Geode' and field.cfg.Count-usage<5 then kind='Crystal' end
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
  if valid then spot=candidate;break end
 end
 if not spot then return false end
 makeResource(field,spot,kind,seed:NextInteger(50,100)*(kind=='Geode' and 3 or 1),field.cfg.Ore)
 return true,kind=='Geode' and 5 or 1
end
local function seedField(field)
 for _,r in ipairs(field.resources) do
  for id in pairs(r.slots) do if drones[id] then release(drones[id]) end end
  resources[r.id]=nil;r.part:Destroy()
 end
 field.resources={};field.respawnQueue={}
 for _=1,field.cfg.Count do if not spawnResource(field) then break end end
end
local function restoreTurrets(field)
 for _,t in ipairs(field.turrets) do
  t.hp=field.cfg.TurretHP;t.nextShot=now+1;t.fireAt=nil;t.lock=nil;t.aim=nil;t.shotSerial=0
  for part,transparency in pairs(t.originalTransparency) do if part.Parent then part.Transparency=transparency end end
  t.model:SetAttribute('HP',t.hp);t.model:SetAttribute('Telegraph',false);t.model:SetAttribute('Dead',false)
 end
end
for _,f in ipairs(scene.fields) do
 local settings=table.clone(C);settings.EncounterPrefix=instanceId..':field:'..f.id
 local field={id=f.id,cfg=f.cfg,center=f.center,part=f.part,model=f.model,color=Color3.fromRGB(unpack(f.cfg.Color)),resources={},turrets={},respawnQueue={},e=R.newEncounter(settings)}
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
local function award(d,r)
 local p=profiles[d.owner];if not healthy(p) or not playerCanMine(p,r.field) then return end
 local profile=data(p);local material=r.field.cfg.Material or r.field.cfg.Key or r.field.cfg.Name
 local amount=r.ore*d.stats.yieldMultiplier+(profile.run.yieldRemainders[material] or 0)
 local units=math.floor(amount);profile.run.yieldRemainders[material]=amount-units
 Profile.addCargo(profile,material,units,Cards.capacity(profile));p.dirty=true;p.publishDirty=true
end
local function hitResource(d,r,amount,secondary)
 local p=profiles[d.owner]
 if not healthy(p) or d.hp<=0 or not r.slots[d.id] or not playerCanMine(p,r.field) or now<r.readyAt then return false end
 if secondary then
  local primary=d.target
  if not primary or primary.paid or (r.position-primary.position).Magnitude>6 or (d.pos-r.position).Magnitude>d.stats.range or (d.pos-Feel.mineGoal(primary.position,d.targetSlot,primary.kind=='Geode')).Magnitude>1 or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
 elseif (d.pos-Feel.mineGoal(r.position,d.targetSlot,r.kind=='Geode')).Magnitude>1 then return false end
 local previous=r.stage
 local broken=R.damage(r,amount)
 local actual=r.paid and 0 or r.hp+10
 r.stage=Feel.stage(actual,r.maxHP)
 if r.stage~=previous then r.part:SetAttribute('Stage',r.stage) end
 r.part:SetAttribute('HP',actual)
 if broken then
  r.part:SetAttribute('BreakSerial',1);r.removeAt=now+2
  for id in pairs(r.slots) do if drones[id] and drones[id].target==r then release(drones[id]) else r.slots[id]=nil end end
  if r.kind=='Geode' then
   makeResource(r.field,r.position,'Core',seed:NextInteger(50,100),r.ore*4)
   for n=1,4 do local a=n*math.pi/2;makeResource(r.field,r.position+Vector3.new(math.cos(a)*4,0,math.sin(a)*4),'Shard',seed:NextInteger(50,70),r.ore) end
  else award(d,r);table.insert(r.field.respawnQueue,now+r.field.cfg.Respawn) end
 end
 return true
end
local function chooseResource(d,field)
 local best,distance=nil,math.huge
 for _,r in ipairs(field.resources) do
  if not r.paid and now>=r.readyAt then
   local used=0;for _ in pairs(r.slots) do used=used+1 end
   local n=(r.position-d.pos).Magnitude
   if used<r.limit and n<distance then best=r;distance=n end
  end
 end
 if best then
  local occupied={};for _,slot in pairs(best.slots) do occupied[slot]=true end
  local slot=1;while occupied[slot] do slot=slot+1 end
  best.slots[d.id]=slot;d.target=best;d.targetSlot=slot;d.warmAt=nil;d.mining=false
 end
end
local function eligible(d,field)
 local p=profiles[d.owner];return p and store:healthy(p.session) and characterRoot(p) and d.hp>0 and d.field==field.id and (d.pos-field.center).Magnitude<75
end
local function activeAssault(p)
 for _,field in ipairs(patches) do
  local u=field.e.users[p.player.UserId]
  if (field.e.phase=='Active' or field.e.phase=='Gathering') and u and not u.removed and u.runId==data(p).run.id then return true end
 end
 return false
end
local function resetField(field)
 restoreTurrets(field);seedField(field)
 for _,p in pairs(profiles) do if not p.busy then data(p).run.entitlements[tostring(field.id)]=nil else p.entitlementSync=true end;p.publishDirty=true end
 for _,d in pairs(drones) do if d.field==field.id then release(d);d.field=nil;if d.hp>0 then d.state='Return' end end end
end
local function grantClear(p,field,e)
 if e.runId~=data(p).run.id then return end
 if p.busy or not store:healthy(p.session) then p.pendingClears=p.pendingClears or {};p.pendingClears[e.encounterId]={field=field,entitlement=Profile.clone(e)};return end
 local run=data(p).run
 if field.e.phase=='Cleared' and field.e.id==e.encounterId and field.e.entitlements[p.player.UserId] then
  run.entitlements[tostring(field.id)]={encounterId=e.encounterId,runId=e.runId}
 end
 run.winReceipts=run.winReceipts or {}
 if not run.winReceipts[e.encounterId] then
  local key=field.cfg.Material or field.cfg.Key or field.cfg.Name
  run.wins[key]=(run.wins[key] or 0)+1;run.winReceipts[e.encounterId]=true
  run.winReceiptOrder=run.winReceiptOrder or {};table.insert(run.winReceiptOrder,e.encounterId)
  while #run.winReceiptOrder>128 do local retired=table.remove(run.winReceiptOrder,1);run.winReceipts[retired]=nil end
 end
 p.dirty=true;p.publishDirty=true;notice(p,field.cfg.Name..' cleared. Your run may now mine this expedition.')
end
local function settleRuntime(p)
 if p.busy or not store:healthy(p.session) then return end
 -- Reconcile runtime expedition tokens after asynchronous profile replacement.
 local entitlements={}
 for _,field in ipairs(patches) do
  local e=field.e.entitlements[p.player.UserId]
  if e and e.runId==data(p).run.id and field.e.phase=='Cleared' then entitlements[tostring(field.id)]=Profile.clone(e) end
 end
 data(p).run.entitlements=entitlements;p.entitlementSync=false
 local pending=p.pendingClears;p.pendingClears={}
 for _,entry in pairs(pending or {}) do grantClear(p,entry.field,entry.entitlement) end
end
local function encounterStep(field)
 if field.cfg.Turrets==0 then return end
 local alive,contact,active=0,false,0
 for id,record in pairs(field.e.roster) do
  local d=drones[id];local p=d and profiles[d.owner]
  local valid=d and p and record.life==d.life and record.runId==data(p).run.id and not field.e.spent[id] and eligible(d,field)
  if valid then alive=alive+1;contact=true
  elseif field.e.phase=='Active' then R.spend(field.e,id) end
 end
 for uid,entitlement in pairs(field.e.entitlements) do
  local p=profiles[uid]
  if p and entitlement.runId==data(p).run.id and characterRoot(p) and (characterRoot(p).Position-field.center).Magnitude<100 then
   for _,d in ipairs(p.drones) do if d.field==field.id and d.hp>0 then active=active+1;break end end
  end
 end
 local defeated=true;for _,t in ipairs(field.turrets) do if t.hp>0 then defeated=false end end
 local event=R.step(field.e,now,alive,contact,defeated,active)
 if event=='reset' then resetField(field)
 elseif event=='start' then
  for id,record in pairs(field.e.roster) do local d=drones[id];if d then d.shield=record.stats.entryShield or 0;d.shotAt=now end end
 elseif event=='clear' then
  for uid,e in pairs(field.e.entitlements) do
   local p=profiles[uid]
   if p then grantClear(p,field,e) end
  end
 elseif event=='guard' then restoreTurrets(field) end
end
local function hurtDrone(d,damage)
 local absorbed=math.min(d.shield or 0,damage);d.shield=(d.shield or 0)-absorbed;damage=damage-absorbed
 if damage<=0 then return end
 if damage>=d.hp then kill(d) else d.hp=d.hp-damage end
end
local function turretStep(field)
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
  t.model:SetAttribute('Telegraph',t.fireAt~=nil);t.model:SetAttribute('HP',t.hp);t.model:SetAttribute('Dead',t.hp<=0)
 end
end
local function combatHit(d,field,target,stats)
 local p=profiles[d.owner]
 if not healthy(p) or not R.participates(field.e,d,data(p).run.id) or target.hp<=0 then return end
 local damage=stats.shotDamage
 if (stats.critChance or 0)>0 and seed:NextNumber()<stats.critChance then damage=damage*2 end
 local dealt=math.min(target.hp,damage);target.hp=math.max(0,target.hp-damage)
 if dealt>0 then R.markContribution(field.e,d.owner,data(p).run.id) end
 if (stats.splashFraction or 0)>0 then
  for _,other in ipairs(field.turrets) do
   if other~=target and other.hp>0 and (other.emitter.Position-target.emitter.Position).Magnitude<=6 and (other.emitter.Position-d.pos).Magnitude<=stats.range and los(d.pos,other.emitter.Position,other.model,{droneFolder}) then
    other.hp=math.max(0,other.hp-damage*stats.splashFraction);break
   end
  end
 end
 target.model:SetAttribute('HP',target.hp);target.model:SetAttribute('Dead',target.hp<=0)
end
local function move(d,goal,dt)
 d.goal=goal;local delta=goal-d.pos
 if delta.X*delta.X+delta.Z*delta.Z>1e-6 then
  local target=math.atan2(-delta.X,-delta.Z);local diff=(target-d.yaw+math.pi)%(math.pi*2)-math.pi
  d.yaw=d.yaw+diff*Feel.turnAlpha(dt)
 end
 d.pos=Feel.approach(d.pos,goal,d.stats.maxStep60,dt)
 -- Exact logical pose; no server presentation lerp, no body pitch.
 d.model:PivotTo(CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0))
end
local function droneStep(d,dt)
 local p=profiles[d.owner];if not p then return end
 if d.hp<=0 then
  d.state=now>=d.readyAt-C.Assembly and 'Reprinting' or 'Destroyed';d.pos=scene.printer.Position+Vector3.new((d.slot-1)%4*2,3,math.floor((d.slot-1)/4)*2);d.goal=d.pos
  d.model:PivotTo(CFrame.new(d.pos))
  if R.finishReprint(d,now,d.stats.maxHealth) then d.field=nil;d.commandOutAt=nil end
  return
 end
 local hr=characterRoot(p)
 if not hr then if d.field then leaveField(p) end;move(d,home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,7,0),dt);return end
 if not store:healthy(p.session) or p.busy then release(d);return end
 local field=d.field and patches[d.field]
 if field and (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then
  d.commandOutAt=d.commandOutAt or now
  if now-d.commandOutAt>3 then leaveField(p);field=nil end
 else d.commandOutAt=nil end
 if field then
  if field.e.phase=='Gathering' then d.state='Travel';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt)
  elseif field.e.phase=='Active' and R.participates(field.e,d,data(p).run.id) then
   release(d);local target,dist=nil,math.huge
   for _,t in ipairs(field.turrets) do local n=(t.emitter.Position-d.pos).Magnitude;if t.hp>0 and n<dist then target=t;dist=n end end
   if target then
    local stats=field.e.roster[d.id].stats
    local side=d.evade%2==0 and 1 or -1
    local goal=target.emitter.Position+Vector3.new(side*(8+(d.slot%3)*3),5,9)
    d.state='Attack';move(d,goal,dt)
    if (d.pos-target.emitter.Position).Magnitude<=stats.range and los(d.pos,target.emitter.Position,target.model,{droneFolder}) then
     d.combatTarget=target;d.mining=true;d.targetPosition=target.emitter.Position
     if now>=d.shotAt then combatHit(d,field,target,stats);d.shotAt=now+stats.shotInterval end
    end
   end
  elseif playerCanMine(p,field) then
   if Profile.cargoUnits(data(p))>=Cards.capacity(data(p)) then leaveField(p)
   else
    if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
    if not d.target then chooseResource(d,field) end
    local r=d.target
    if r then
     local goal=Feel.mineGoal(r.position,d.targetSlot,r.kind=='Geode');d.state='Travel';move(d,goal,dt)
     if Feel.canMine((d.pos-goal).Magnitude,now>=r.readyAt,true,d.hp>0) and los(d.pos,r.position,r.part,{droneFolder}) then
      d.warmAt=d.warmAt or now;d.state='Mine'
      if now-d.warmAt>=d.stats.warmup then
       if not d.mining then d.beamSince=now end
       d.mining=true;hitResource(d,r,d.stats.miningDPS*dt)
       if d.target and (d.stats.forkFraction or 0)>0 then
        for _,other in ipairs(field.resources) do
         if other~=r and not other.paid and now>=other.readyAt and (other.position-r.position).Magnitude<=6 then
          local count=0;for _ in pairs(other.slots) do count=count+1 end
          if count<other.limit then
           other.slots[d.id]=1;hitResource(d,other,d.stats.miningDPS*dt*d.stats.forkFraction,true);other.slots[d.id]=nil;break
          end
         end
        end
       end
      end
     else d.warmAt=nil;d.mining=false end
    else d.state='Follow';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt) end
   end
  else leaveField(p) end
 else
  d.mining=false;d.combatTarget=nil
  local goal=d.state=='Return' and home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,7,0) or Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)
  move(d,goal,dt)
  if d.state=='Return' and (d.pos-goal).Magnitude<1 then d.state='Follow' end
  if d.state~='Return' then d.state='Follow' end
  if (d.pos-home).Magnitude<22 then d.hp=math.min(d.stats.maxHealth,d.hp+8*dt) end
 end
end
local function snapshotDrone(d)
 local target=d.target
 local values={Owner=d.owner,DroneId=d.id,DroneName=d.name,Name=d.name,Type=d.owned.type,Life=d.life,State=d.state,HP=d.hp,MaxHP=d.stats.maxHealth,
  Position=d.pos,Goal=d.goal,Yaw=d.yaw,MaxStep60=d.stats.maxStep60,PhaseSeed=d.owned.base.maxStep60*200,FormationSlot=d.slot,FleetCount=#profiles[d.owner].drones,
  TargetId=target and target.id or '',TargetPosition=target and target.position or d.targetPosition or d.pos,Mining=d.mining,BeamSince=d.beamSince,
  ReprintAt=d.hp<=0 and d.readyAt or 0,SnapshotAt=now}
 for k,v in pairs(values) do d.model:SetAttribute(k,v) end
end
local function resolveAfter(p,result)
 local after=p.pendingAfter;p.pendingAfter=nil
 if result and result.committed~=false and after and not p.leaving then after(result) end
end
local function transact(p,id,mutate,after)
 if p.leaving or p.busy or not store:healthy(p.session) then return false end
 p.busy=true;p.pendingAfter=after;publish(p)
 task.spawn(function()
  local ok,result=store:transaction(p.session,id,mutate)
  if ok then p.dirty=false;resolveAfter(p,result)
  else
   notice(p,tostring(result))
   if p.session.readOnly then
    local recovered,outcome=store:reconcile(p.session)
    if recovered then resolveAfter(p,outcome) end
   else p.pendingAfter=nil end
  end
  p.busy=false;settleRuntime(p);if not p.leaving then publish(p) end
 end)
 return true
end
local function validPayload(payload)
 return type(payload)=='table' and type(payload.txId)=='string' and #payload.txId>=1 and #payload.txId<=100 and type(payload.runId)=='string' and #payload.runId<=100
end
local function commandPlayer(pl,action,payload)
 local p=profiles[pl.UserId];if not p then return end
 local duration=math.max(0,now-p.bucketAt);p.tokens=math.min(7,p.tokens+duration*3);p.bucketAt=now
 if p.tokens<1 then return end;p.tokens=p.tokens-1
 if type(action)~='string' or #action>24 or not healthy(p) or not characterRoot(p) then return end
 if action=='Recall' then leaveField(p);notice(p,'Fleet recalled. Assault slots are retired.')
 elseif action=='Evade' then
  if now<(p.nextEvade or 0) then return end;p.nextEvade=now+2
  for _,d in ipairs(p.drones) do if d.field and R.participates(patches[d.field].e,d,data(p).run.id) then d.evade=d.evade+1 end end
 elseif action=='Patch' then
  if not R.finite(payload) or payload%1~=0 then return end
  local field=patches[payload];local hr=characterRoot(p)
  if not field or (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then return end
  local can=playerCanMine(p,field)
  if not can and (field.e.phase=='Active' or field.e.phase=='Cleared' or field.e.phase=='Resetting') then notice(p,'An expedition is in progress. Join the next fresh muster.');return end
  if not can and field.e.phase=='Gathering' and (field.e.users[pl.UserId] or now>=field.e.untilTime) then return end
  local fleet={};for _,d in ipairs(p.drones) do if d.hp>0 and R.allowed(d.owner,pl.UserId,d.state) then table.insert(fleet,d) end end
  if #fleet==0 then return end
  leaveField(p,can and field.id or nil)
  for _,d in ipairs(fleet) do release(d);d.field=field.id;d.state='Travel';d.shotAt=now end
  if not can then
   if field.e.phase=='Guarded' then R.gather(field.e,now) end
   R.enroll(field.e,pl.UserId,data(p).run.id,fleet)
  end
 elseif action=='Sell' then
  if activeAssault(p) then notice(p,'Recall your assault fleet before selling.');return end
  if not atStation(p,scene.converter or scene.packStation,18) then notice(p,'Return to the Converter to sell.');return end
  local expected=data(p).run.id;local tx='sale:'..Http:GenerateGUID(false)
  transact(p,tx,function(copy) local ok,r=Profile.sell(copy,prices,tx,expected);if ok then return r end;return nil,r end,function(r) notice(p,'Sold for '..r.credits..' credits.') end)
 elseif action=='BuyPack' or action=='ChooseCard' or action=='Prestige' then
  if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then return end
  if not atHome(p) then notice(p,'Use the pack machine or prestige beacon at the depot.');return end
  if action=='BuyPack' then
   if not R.finite(payload.packIndex) or payload.packIndex%1~=0 then return end
   if not atStation(p,scene.packStation,20) then return end
   transact(p,'buy:'..payload.txId,function(copy)
    local ok,r=Cards.buy(copy,payload.txId,payload.runId,{combatVisible=true,expectedPackIndex=payload.packIndex,atDepot=true,activeEncounter=false});if ok then return r end;return nil,r
   end,function() notice(p,'Choose one card. All three choices and targets are saved.') end)
  elseif action=='ChooseCard' then
   if type(payload.offerId)~='string' or #payload.offerId>160 or not R.finite(payload.index) or payload.index%1~=0 or payload.index<1 or payload.index>3 then return end
   transact(p,'choose:'..payload.txId,function(copy)
    local ok,r=Cards.select(copy,payload.offerId,payload.index,payload.txId,payload.runId,{atDepot=true,activeEncounter=false});if ok then return r end;return nil,r
   end,function() refreshStats(p);notice(p,'Card installed • this run only.') end)
  else
   if payload.confirm~=true or not atStation(p,scene.prestigeStation,20) then return end
   transact(p,'prestige:'..payload.txId,function(copy)
    local ok,r=Profile.prestige(copy,payload.txId,payload.runId,{atDepot=true,activeEncounter=activeAssault(p),confirmed=true});if ok then return r end;return nil,r
   end,function()
    -- Remove exactly this player's old run; shared teammates continue untouched.
    for _,field in ipairs(patches) do local u=field.e.users[pl.UserId];if u then R.removeUser(field.e,pl.UserId,u.runId) end end
    rebuildFleet(p);notice(p,'Prestige complete. One new permanent drone; a fresh run.')
   end)
  end
 end
 p.publishDirty=true
end
command.OnServerEvent:Connect(commandPlayer)
local function addPlayer(pl)
 if profiles[pl.UserId] or loading[pl.UserId] then return end
 loading[pl.UserId]=true
 pl:SetAttribute('MA_SaveStatus','Loading profile...')
 local session,err=store:load(pl.UserId)
 loading[pl.UserId]=nil
 if not session then pl:SetAttribute('MA_SaveStatus','Profile unavailable — no defaults written');pl:SetAttribute('MA_Notice',tostring(err));return end
 if not pl.Parent then store:release(session);return end
 -- A new server cannot inherit a previous server's world encounter token.
 session.data.run.entitlements={}
 local p={player=pl,session=session,drones={},tokens=7,bucketAt=now,busy=false,dirty=false,leaving=false,publishDirty=true}
 profiles[pl.UserId]=p
 local function character(ch)
  local hr=ch:WaitForChild('HumanoidRootPart',10)
  if not hr or not pl.Parent then return end
  leaveField(p);ch:PivotTo(CFrame.new(home+Vector3.new(0,4,0)))
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
 if not p.busy then
  p.session.data.run.entitlements={}
  for attempt=1,3 do
   if p.session.readOnly then local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end end
   if p.session.closed then break end
   local saved=store:release(p.session);if saved then break end
   if os.clock()>=deadline then break end;task.wait(.2*attempt)
  end
 end
 profiles[pl.UserId]=nil
end
Players.PlayerRemoving:Connect(removePlayer)
for _,pl in ipairs(Players:GetPlayers()) do task.spawn(addPlayer,pl) end
RunService.Heartbeat:Connect(function(dt)
 now=workspace:GetServerTimeNow()
 elapsed=math.min(elapsed+math.max(0,dt),C.Tick*(C.MaxCatchup or 6))
 local steps=0
 while elapsed>=C.Tick and steps<(C.MaxCatchup or 6) do
  elapsed=elapsed-C.Tick;steps=steps+1
  for _,field in ipairs(patches) do encounterStep(field) end
  for _,d in pairs(drones) do droneStep(d,C.Tick) end
  for _,field in ipairs(patches) do turretStep(field);encounterStep(field) end
 end
 snapshotElapsed=snapshotElapsed+dt;autosaveElapsed=autosaveElapsed+dt
 if snapshotElapsed>=C.Snapshot then
  snapshotElapsed=0
  for _,d in pairs(drones) do snapshotDrone(d) end
  for _,field in ipairs(patches) do
   field.model:SetAttribute('Phase',field.e.phase);field.model:SetAttribute('EncounterId',field.e.id);field.model:SetAttribute('PhaseEndsAt',field.e.untilTime)
   for i=#field.resources,1,-1 do local r=field.resources[i];if r.paid and r.removeAt and now>=r.removeAt then resources[r.id]=nil;r.part:Destroy();table.remove(field.resources,i) end end
   table.sort(field.respawnQueue)
   local replenished=0
   while #field.respawnQueue>0 and now>=field.respawnQueue[1] and replenished<field.cfg.Count do
    local due=0;for _,at in ipairs(field.respawnQueue) do if at<=now then due=due+1 end end
    -- A geode reserves five future nodes. Consume five due replenishment tokens,
    -- rather than leaving four immortal retries behind after every shell cycle.
    local spawned,cost=spawnResource(field,due<5 and 'Crystal' or nil)
    if not spawned then field.respawnQueue[1]=now+2;table.sort(field.respawnQueue);break end
    for _=1,cost do table.remove(field.respawnQueue,1) end
    replenished=replenished+cost
   end
  end
  for _,p in pairs(profiles) do if not p.busy then settleRuntime(p) end;if p.publishDirty then p.publishDirty=false;publish(p) end end
 end
 if autosaveElapsed>=30 then
  autosaveElapsed=0
  for _,p in pairs(profiles) do
   if not p.busy and not p.leaving then
    p.busy=true
    task.spawn(function()
     if p.session.readOnly then
      local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end
     end
     local ok,err=store:save(p.session)
     if not ok then
      notice(p,'Save delayed: '..tostring(err))
      if p.session.readOnly then local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end end
     else p.dirty=false end
     p.busy=false;settleRuntime(p);publish(p)
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
