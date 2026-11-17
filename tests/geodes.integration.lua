local pl=player(98880);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId];local run=data(p).run
local miner=p.drones[1];assert(miner.role=='Striker')
local zone=Instance.new('Folder');zone.Parent=scene.map
local bed=World.part(zone,'Field',Vector3.new(0,5,-60),Vector3.new(216,1,64),Color3.new(1,.5,0))
local field={id=#patches+1,cfg={SelectionOnly=true,ContinuousCrystals=true,Key='Amber',Material='Amber',AlwaysUnlocked=true,Turrets=0,Hardness=1,Ore=10,Respawn=8,Count=40},
 part=bed,center=bed.Position,model=zone,color=bed.Color,resources={},respawnQueue={},respawnClock=now,turrets={},e=R.newEncounter(C)}
field.e.phase='Safe';patches[field.id]=field
local center=bed.Position+Vector3.yAxis*.5
pl.Character:PivotTo(CFrame.new(center+Vector3.new(0,3,5)))
scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center})
local square=p.miningSquare;assert(square)
local function rock(kind,offset)
 local r=makeResource(field,center+Vector3.xAxis*(offset or 0),kind,1010,10,5,7)
 r.readyAt=now;r.gemReward=kind=='Geode';return r
end
local function station(d,r)
 release(d);d.target=r;d.targetSlot=1;d.field=field.id;d.squareJob=square
 r.slots[d.id]=1;d.workStation=scene.resourceStation(r,1);d.pos=d.workStation
 d.mining=true;d.beamSince=now;d.hp=100;d.battery=d.stats.batteryCapacity
end
local oldRay=workspace.Raycast
workspace.Raycast=function() return nil end
local other=player(98881);players.PlayerAdded:Fire(other);local foreign=profiles[other.UserId]
local discoveries=0
local originalTools=scene.fieldTools
scene.fieldTools={refreshStock=function() end,onRock=function(_,owner,resource)
 assert(owner==p and resource.paid,'discovery before committed opening')
 discoveries+=1
end}
local g=rock('Geode')
station(miner,g)
assert(hitResource(miner,g,10000),'initial geode contact rejected')
assert(not g.paid and math.abs(g.hp-900)<.001,'burst skipped first crack')
assert(g.part.Size==g.fullSize,'geode shrank')
now+=4.1;scene.stepGeode(g)
assert(g.hp==1000 and g.stage==0 and not miner.target and g.geodeRejectedOwner==pl.UserId,'underpowered shell did not reset/release')
assert(not chooseResource(miner,field,square),'rejected crew retried without a new focus order')
scene.focusResource(p,{runId=run.id,resourceId=g.id})
assert(square.directId==g.id and not g.geodeRejectedOwner,'focus did not reset attempt')
g.geodeRejectedOwner=pl.UserId;scene.publishSquareFocus(p,square)
assert(pl:GetAttribute('MA_SelectorFocus')=='Underpowered:'..g.id,'failed geode looks queued')
g.geodeRejectedOwner=nil
station(miner,g);hitResource(miner,g,100)
local firstCrack=g.hp
hitResource(miner,g,10000);assert(g.hp==firstCrack,'assembly grace counted free damage')
now=g.geodeTestAt
for i=1,8 do now+=.5;hitResource(miner,g,70) end
scene.stepGeode(g);assert(g.geodePassed,'sustained work failed')
hitResource(miner,g,10000)
assert(g.openReady and not g.paid and g.hp==1 and not miner.target,'geode did not stop ready')
assert(next(pickups)==nil,'geode paid before E')
scene.publishSquareFocus(p,square)
assert(pl:GetAttribute('MA_SelectorFocus')=='Ready:'..g.id and discoveries==0)
assert(not hitResource(miner,g,10000),'ready shell took more damage')
assert(not clusterEligible(miner,p,g,field),'ready geode entered an automatic cluster')
scene.regrow(g,50);assert(g.hp==1,'ready reward healed')
-- Stale runs, distance, obstruction and foreign players never open the claim.
scene.openResource(p,{runId='stale',resourceId=g.id});assert(not g.openingAt)
pl.Character:PivotTo(CFrame.new(center+Vector3.xAxis*60))
scene.openResource(p,{runId=run.id,resourceId=g.id});assert(not g.openingAt)
pl.Character:PivotTo(CFrame.new(center+Vector3.new(0,3,5)))
other.Character:PivotTo(CFrame.new(center+Vector3.new(0,3,5)))
scene.openResource(foreign,{runId=data(foreign).run.id,resourceId=g.id});assert(not g.openingAt)
workspace.Raycast=function() return {Instance=bed} end
scene.openResource(p,{runId=run.id,resourceId=g.id});assert(not g.openingAt,'opened through an obstruction')
workspace.Raycast=function() return nil end
scene.openResource(p,{runId=run.id,resourceId=g.id});local opens=g.openingAt;assert(opens and opens-now>.8)
scene.openResource(p,{runId=run.id,resourceId=g.id});assert(g.openingAt==opens,'duplicate E restarted windup')
scene.stepGeode(g);assert(not g.paid)
now=opens+.01;scene.stepGeode(g)
local count=0
for _,drop in pairs(pickups) do
 count+=1;assert(drop.owner==pl.UserId and drop.runId==run.id and drop.rareGem and not drop.stone and drop.tierMaterial=='Amber','wrong geode reward')
end
assert(count==6 and g.paid and #field.respawnQueue==1,'geode reward/respawn not exact')
scene.stepGeode(g);scene.openResource(p,{runId=run.id,resourceId=g.id})
local after=0;for _ in pairs(pickups) do after+=1 end;assert(after==count)
assert(discoveries==1,'geode must count as one discovery, not six or zero')
print('PASS first-crack gate, low-DPS recoil, retry, sustained power, E validation, six field gems, duplicate guard')
local gem=rock('Crystal',4);gem.gemReward=true
station(miner,gem);hitResource(miner,gem,10000)
assert(gem.openReady and not gem.paid and not gem.cargoProduced,'gem auto-broke or paid early')
assert(not clusterEligible(miner,p,gem,field),'ready gem entered an automatic cluster')
local stone=rock('Crystal',-4);stone.gemReward=false
station(miner,stone);hitResource(miner,stone,10000)
assert(stone.paid and stone.cargoProduced,'ordinary stone no longer automatic')
local naturalGem=rock('Crystal',6);naturalGem.gemReward=true
station(miner,naturalGem);hitResource(miner,naturalGem,10000)
scene.openResource(p,{runId=run.id,resourceId=naturalGem.id});now=naturalGem.openingAt+.01;scene.stepGeode(naturalGem)
assert(discoveries==3,'ordinary stone and natural gem must each count once')
local toolGem=rock('Crystal',7);toolGem.gemReward=true;toolGem.consumableWorked=true
station(miner,toolGem);hitResource(miner,toolGem,10000)
scene.openResource(p,{runId=run.id,resourceId=toolGem.id});now=toolGem.openingAt+.01;scene.stepGeode(toolGem)
assert(discoveries==3,'tool-mined gem manufactured more tools')
local abandoned=gem;local savedRun=run.id;run.id='new-run'
scene.stepGeode(abandoned);assert(not abandoned.openReady and abandoned.hp==1000,'old run kept ready claim')
run.id=savedRun
-- Focus ignores weak-first and helper delay, and permits mixed-role crew.
local focus=rock('Geode',2);local weak=rock('Crystal',-2)
weak.hp=20
scene.focusResource(p,{runId=run.id,resourceId=focus.id})
local workers=0
for _,d in ipairs(p.drones) do
 if DroneRoles.isWorker(d.role) then
  release(d);local chosen=chooseResource(d,field,square)
  assert(chosen==focus,'focus lost to a weaker rock or helper delay');d.squareJob=square;workers+=1
 end
end
assert(workers>=3)
scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center})
assert(p.miningSquare==square and not square.directId,'confirming current plot failed to release forced focus')
for _,d in ipairs(p.drones) do release(d) end
assert(chooseResource(miner,field,square)==weak,'automatic mining did not return to weakest rock')
scene.focusResource(p,{runId=run.id,resourceId=focus.id})
scene.focusResource(foreign,{runId=data(foreign).run.id,resourceId=focus.id})
for id in pairs(focus.slots) do assert(drones[id].owner==pl.UserId) end
print('PASS gems wait, stone stays automatic, stale claims reset, full mixed crew focuses without helper delay')
local spawned,cost,native=spawnResource(field,'Geode')
assert(spawned and cost==1 and native.kind=='Geode' and native.part.Shape==Enum.PartType.Ball,'continuous geode spawn failed')
assert(native.maxHP-10>=260 and native.fullSize.X==native.fullSize.Y,'geode work/round silhouette incorrect')
print('PASS production geode spawn uses one field slot, round geometry and extended work')
scene.fieldTools=originalTools
workspace.Raycast=oldRay
print('PASS one discovery per opened deposit, no tool recursion, honest focus status, return to automatic mining')

-- Exercise the click path and the full travel/warmup loop, not teleported contacts.
do
 local moving=rock('Geode',4)
 moving.maxHP=790;moving.hp=780 -- largest unmodified Quartz geode
 local runFolder=scene.map:FindFirstChild('CrystalRun')
 if not runFolder then runFolder=Instance.new('Folder');runFolder.Name='CrystalRun';runFolder.Parent=scene.map end
 zone.Parent=runFolder;bed:SetAttribute('FieldId',field.id)
 local localEffects=Instance.new('Folder');localEffects.Parent=workspace
 local sent
 local view=SelectorView.new({player=pl,world=root,parent=localEffects,hidden=function() return false end,
  profile=function() return data(p) end,command={FireServer=function(_,action,payload)
   sent={action=action,payload=payload};commandPlayer(pl,action,payload)
  end}})
 -- An unfinished area preview must not swallow a click inside the accepted plot.
 view.draft={field=field.id,point=center+Vector3.xAxis*20}
 workspace.Raycast=function() return {Instance=moving.part,Position=moving.position} end
 pl.Character:PivotTo(CFrame.new(center-Vector3.xAxis*43+Vector3.yAxis*3))
 local ray={Origin=moving.position+Vector3.new(0,20,20),Direction=Vector3.new(0,-1,-1).Unit}
 local _,_,_,inRange=view:aim(ray);assert(inRange==false,'fixture must hit beyond new-area range')
 local clicked=view:aimPreview(ray)
 assert(clicked and sent and sent.action=='FocusResource' and sent.payload.requestId,'click did not send an acknowledged focus command')
 assert(not view.draft and square.directId==moving.id,'draft or projected range swallowed rock click inside accepted area')
 pl.Character:PivotTo(CFrame.new(center+Vector3.new(0,3,5)))
 workspace.Raycast=function() return nil end
 local crew={};local basePower=0
 for _,d in ipairs(p.drones) do
  if DroneRoles.isWorker(d.role) and #crew<3 then
   release(d);d.pos=center+Vector3.new(26,4,(d.slot-2)*5);d.velocity=Vector3.zero
   d.hp=d.stats.maxHealth;d.battery=d.stats.batteryCapacity;d.recharging=nil;d.thinkUntil=nil
   crew[#crew+1]=d;basePower+=d.stats.miningDPS
  elseif DroneRoles.isWorker(d.role) then release(d);d.hp=0 end
 end
 for _,d in ipairs(crew) do scene.squareStep(p,d);assert(d.target==moving) end
 scene.planMiningStations()
 for _,d in ipairs(crew) do assert(scene.workPlans[moving].ranks[d],'focused miner left in serial approach queue') end
 assert(#crew==3,'starter regression must use exactly three miners')
 local deadline=now+45;local together=0;local miningPeak=0
 while now<deadline and not moving.openReady and not moving.geodeRejectedOwner do
  now+=.05;scene.planMiningStations()
  local mining=0
  for _,d in ipairs(crew) do droneStep(d,.05);if d.mining and d.target==moving then mining+=1 end end
  miningPeak=math.max(miningPeak,mining)
  if mining==#crew then together+=.05 end
  scene.stepGeode(moving)
 end
 assert(miningPeak==#crew,'crew never mined together: '..miningPeak..'/'..#crew)
 assert(moving.geodePassed and moving.openReady and not moving.paid,
  'traveling starter crew could not open Quartz geode; power='..basePower..' hp='..moving.hp..' state='..tostring(moving.geodeRejectedOwner))
 print('PASS real ray click with draft -> server command -> parallel travel/warmup -> '..#crew..' miners -> ready geode; power='..basePower)
 -- A focused but genuinely weak crew still gets the full trial, then snaps shut.
 local weakShell=rock('Geode',1)
 scene.focusResource(p,{runId=run.id,resourceId=weakShell.id})
 local rallyUntil=weakShell.geodeRallyUntil
 scene.focusResource(p,{runId=run.id,resourceId=weakShell.id})
 assert(weakShell.geodeRallyUntil==rallyUntil,'repeated focus extended trial grace')
 local saved={}
 for _,d in ipairs(crew) do saved[d]=d.stats.miningDPS;d.stats.miningDPS=10;d.battery=d.stats.batteryCapacity end
 deadline=now+45
 while now<deadline and not weakShell.geodeRejectedOwner do
  now+=.05;scene.planMiningStations()
  for _,d in ipairs(crew) do droneStep(d,.05) end
  scene.stepGeode(weakShell)
 end
 assert(weakShell.geodeRejectedOwner==pl.UserId and weakShell.hp==1000 and not weakShell.openReady,'rally grace removed the power requirement')
 for _,d in ipairs(crew) do d.stats.miningDPS=saved[d] end
 localEffects:Destroy();workspace.Raycast=oldRay
 print('PASS real low-power crew recoils; repeated clicks cannot extend assembly grace')
end
