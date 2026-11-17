local pl=player(98880);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId];local run=data(p).run;local miner=p.drones[1]
local zone=Instance.new('Folder');zone.Parent=scene.map
local bed=World.part(zone,'Field',Vector3.new(0,5,-60),Vector3.new(216,1,64),Color3.new(1,.5,0))
local field={id=#patches+1,cfg={SelectionOnly=true,ContinuousCrystals=true,Key='Amber',Material='Amber',AlwaysUnlocked=true,Turrets=0,Hardness=1,Ore=10,Respawn=8,Count=40},
 part=bed,center=bed.Position,model=zone,color=bed.Color,resources={},respawnQueue={},respawnClock=now,turrets={},e=R.newEncounter(C)}
field.e.phase='Safe';patches[field.id]=field
local center=bed.Position+Vector3.yAxis*.5
pl.Character:PivotTo(CFrame.new(center+Vector3.new(0,3,5)))
scene.placeSquare(p,{runId=run.id,fieldId=field.id,position=center})
local square=p.miningSquare
local function rock(offset)
 local r=makeResource(field,center+Vector3.xAxis*(offset or 0),'Crystal',1010,10,5,3)
 r.readyAt=now;return r
end
local function station(r)
 release(miner);miner.target=r;miner.targetSlot=1;miner.field=field.id;miner.squareJob=square
 r.slots[miner.id]=1;miner.workStation=scene.resourceStation(r,1);miner.pos=miner.workStation
 miner.mining=true;miner.beamSince=now;miner.hp=100;miner.battery=miner.stats.batteryCapacity
end
workspace.Raycast=function() return nil end
local discoveries=0
scene.fieldTools={clear=function() end,refreshStock=function() end,onRock=function(_,owner,r) assert(r.paid);discoveries+=1 end}
local oldRandom=math.random
math.random=function(...) if select('#',...)==0 then return .01 end;return oldRandom(...) end
local original=rock();station(original)
assert(hitResource(miner,original,10000))
assert(original.paid and original.hp==0 and original.cargoProduced and not original.openReady,'drones failed to finish ordinary stone')
assert(not miner.target,'worker did not leave completed mining job')
assert(#field.respawnQueue==1 and discoveries==1,'mining must replenish/discover before opening')
local g
for _,r in ipairs(field.resources) do if r.sealedDrop then g=r end end
assert(g and g~=original and g.openReady and g.hp==1 and g.rewardCount==1)
assert(g.part:GetAttribute('SealedDrop') and not g.part:GetAttribute('RockModifiers'),'contents leaked before opening')
assert(nodeUsage(field)==0,'unopened discovery blocks replenishment')
local count=0
for _,drop in pairs(pickups) do count+=1;assert(drop.stone and not drop.rareGem,'mining paid a gem before opening') end
assert(count==1,'completed mining did not pay one ordinary rock')
assert(not hitResource(miner,g,10000) and not clusterEligible(miner,p,g,field),'drones can mine a sealed drop')
scene.regrow(g,50);assert(g.hp==1)
local other=player(98881);players.PlayerAdded:Fire(other);other.Character:PivotTo(CFrame.new(center))
scene.openResource(profiles[other.UserId],{runId=data(profiles[other.UserId]).run.id,resourceId=g.id});assert(not g.openingAt)
scene.openResource(p,{runId='old',resourceId=g.id});assert(not g.openingAt)
pl.Character:PivotTo(CFrame.new(center+Vector3.xAxis*60))
scene.openResource(p,{runId=run.id,resourceId=g.id});assert(not g.openingAt)
pl.Character:PivotTo(CFrame.new(center+Vector3.new(0,3,5)))
workspace.Raycast=function() return {Instance=bed} end
scene.openResource(p,{runId=run.id,resourceId=g.id});assert(not g.openingAt,'opened through wall')
workspace.Raycast=function() return nil end
scene.openResource(p,{runId=run.id,resourceId=g.id});local opens=g.openingAt;assert(opens and opens-now>.8)
scene.openResource(p,{runId=run.id,resourceId=g.id});assert(g.openingAt==opens)
scene.stepGeode(g);assert(not g.paid)
now=opens+.01;scene.stepGeode(g);assert(g.paid)
count=0;local gems=0
for _,drop in pairs(pickups) do count+=1;if drop.rareGem then gems+=1;assert(drop.tierMaterial=='Amber') end end
assert(count==2 and gems==1 and #field.respawnQueue==1 and discoveries==1,'opening duplicated progress or wrong reward')
scene.stepGeode(g);scene.openResource(p,{runId=run.id,resourceId=g.id})
local after=0;for _ in pairs(pickups) do after+=1 end;assert(after==count)
for _,case in ipairs({{.85,2},{.99,3}}) do
 math.random=function(...) if select('#',...)==0 then return case[1] end;return oldRandom(...) end
 local drop=scene.leaveGeode(miner,original,false);assert(drop.rewardCount==case[2])
 local saved=run.id;run.id='new';scene.stepGeode(drop);assert(drop.paid and drop.removeAt==now);run.id=saved
end
math.random=function(...) if select('#',...)==0 then return .99 end;return oldRandom(...) end
local plain=rock(-4);station(plain);hitResource(miner,plain,10000)
assert(plain.paid and plain.cargoProduced and not plain.openReady and #field.respawnQueue==2)
math.random=oldRandom
local spawned,_,native=spawnResource(field,'Geode');assert(spawned and native.kind=='Crystal','field still spawns mining challenge geodes')
print('PASS full stone break/payout, separate sealed discovery, hidden variable rewards, immediate replenishment, worker release, E range/owner/run/LOS/windup, duplicate guards, abandoned cleanup')
