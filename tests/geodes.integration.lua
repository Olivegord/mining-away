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
station(miner,g);hitResource(miner,g,100)
for i=1,8 do now+=.5;hitResource(miner,g,70) end
scene.stepGeode(g);assert(g.geodePassed,'sustained work failed')
hitResource(miner,g,10000)
assert(g.openReady and not g.paid and g.hp==1 and not miner.target,'geode did not stop ready')
assert(next(pickups)==nil,'geode paid before E')
assert(not hitResource(miner,g,10000),'ready shell took more damage')
assert(not clusterEligible(miner,p,g,field),'ready geode entered an automatic cluster')
scene.regrow(g,50);assert(g.hp==1,'ready reward healed')
-- Stale runs, distance, obstruction and foreign players never open the claim.
scene.openResource(p,{runId='stale',resourceId=g.id});assert(not g.openingAt)
pl.Character:PivotTo(CFrame.new(center+Vector3.xAxis*60))
scene.openResource(p,{runId=run.id,resourceId=g.id});assert(not g.openingAt)
pl.Character:PivotTo(CFrame.new(center+Vector3.new(0,3,5)))
local other=player(98881);players.PlayerAdded:Fire(other);local foreign=profiles[other.UserId]
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
print('PASS first-crack gate, low-DPS recoil, retry, sustained power, E validation, six field gems, duplicate guard')
local gem=rock('Crystal',4);gem.gemReward=true
station(miner,gem);hitResource(miner,gem,10000)
assert(gem.openReady and not gem.paid and not gem.cargoProduced,'gem auto-broke or paid early')
assert(not clusterEligible(miner,p,gem,field),'ready gem entered an automatic cluster')
local stone=rock('Crystal',-4);stone.gemReward=false
station(miner,stone);hitResource(miner,stone,10000)
assert(stone.paid and stone.cargoProduced,'ordinary stone no longer automatic')
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
scene.focusResource(foreign,{runId=data(foreign).run.id,resourceId=focus.id})
for id in pairs(focus.slots) do assert(drones[id].owner==pl.UserId) end
print('PASS gems wait, stone stays automatic, stale claims reset, full mixed crew focuses without helper delay')
local spawned,cost,native=spawnResource(field,'Geode')
assert(spawned and cost==1 and native.kind=='Geode' and native.part.Shape==Enum.PartType.Ball,'continuous geode spawn failed')
assert(native.maxHP-10>=260 and native.fullSize.X==native.fullSize.Y,'geode work/round silhouette incorrect')
print('PASS production geode spawn uses one field slot, round geometry and extended work')
workspace.Raycast=oldRay
