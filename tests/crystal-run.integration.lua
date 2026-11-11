-- Real command dispatch, movement/work, pickup ledger, and charge state with
-- Roblox API doubles. Native fixture collision is verified separately in Edit.
local cfIndex=CF.__index
CF.__index=function(c,k)
 if k=='RightVector' then return Vector3.new(math.cos(c.yaw),0,-math.sin(c.yaw)) end
 return cfIndex(c,k)
end
local run=Instance.new('Folder');run.Name='CrystalRun';run.Parent=scene.map
local zone=Instance.new('Folder');zone.Name='TestZone';zone.Parent=run
local bed=World.part(zone,'Field',Vector3.new(0,5,-68),Vector3.new(68,1,48),Color3.new(1,1,1))
scene.chargingStation=World.part(run,'ChargingStation',Vector3.new(0,5,-41),Vector3.new(4,1,4),Color3.new(1,1,1))
local f={id=#patches+1,cfg={Key='Quartz',Value=1,SelectionOnly=true,AlwaysUnlocked=true,ReferenceCrystals=true,Hardness=1,Count=3,Ore=20,Turrets=0,Respawn=8},
 part=bed,model=zone,center=bed.Position,color=Color3.new(1,0,0),resources={},turrets={},respawnQueue={},e=R.newEncounter(C)}
f.e.phase='Safe';patches[f.id]=f
local pl=player(98700);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId];local d=p.drones[1]
for i=2,#p.drones do p.drones[i].hp=0 end
pl.Character:PivotTo(CFrame.new(Vector3.new(0,8,-68)))
local function rock(x,hp)
 local r=makeResource(f,f.center+Vector3.new(x,0,0),'Crystal',hp,20,3,3)
 r.readyAt=now
 return r
end
local a,b,edge=rock(-10,175),rock(13,100),rock(29,100)
local function pin(x)
 command.OnServerEvent:Fire(pl,'PlaceSelector',{runId=data(p).run.id,fieldId=f.id,position=Vector3.new(x,5.5,-68)})
end
local function step(n)
 for _=1,n do realTime+=C.Tick;now=realTime;droneStep(d,C.Tick) end
end
local function status(expected)
 scene.publishSquareStatus(p)
 local actual=pl:GetAttribute('MA_SelectorStatus')
 assert(actual==expected,'selector status: expected '..tostring(expected)..', got '..tostring(actual))
end
pin(200);assert(not p.miningSquare,'out-of-range pin accepted')
status(nil)
pin(-34.5);assert(not p.miningSquare,'off-field point snapped back into the field')
pin(-9.4);assert(p.miningSquare and p.miningSquare.center.X==-10 and p.miningSquare.half==15)
assert(pl:GetAttribute('MA_SelectorStatus')=='Waiting','initial status must publish with the pin')
status('Waiting')
d.carrierId='carrier-test';status('NoMiners');d.carrierId=nil
local pinned=p.miningSquare
pin(-10.6);assert(p.miningSquare==pinned,'same grid cell restarted the order')
step(1);assert(d.target==a);status('Moving')
d.pos=Feel.mineGoal(a.position,1,false,a.fullSize,a.referenceCrystal)
step(32);assert(d.mining,'worker never began its real cut')
status('Working');assert(pl:GetAttribute('MA_SelectorWorking')==true)
p.busy=true;status('Paused');assert(d.target==a);p.busy=false
status('Working')
local other=player(98701);players.PlayerAdded:Fire(other)
local rival=profiles[other.UserId]
other.Character:PivotTo(CFrame.new(Vector3.new(0,8,-68)))
command.OnServerEvent:Fire(other,'PlaceSelector',{runId=data(rival).run.id,fieldId=f.id,position=Vector3.new(-10,5.5,-68)})
droneStep(rival.drones[1],C.Tick)
assert(rival.miningSquare and not rival.drones[1].target,'overlapping selector stole another crew’s reservation')
scene.publishSquareStatus(rival);assert(other:GetAttribute('MA_SelectorStatus')=='Claimed')
players.PlayerRemoving:Fire(other)
pin(13.3);assert(p.miningSquare.center.X==14)
assert(pl:GetAttribute('MA_SelectorStatus')=='FinishingCut' and pl:GetAttribute('MA_SelectorWorking')==false)
step(1);assert(d.target==a,'moving the square interrupted a live cut')
pl.Character:PivotTo(CFrame.new(Vector3.new(0,8,20)))
for _=1,600 do step(1);if a.paid then break end end
assert(a.paid,'first committed target did not finish')
step(80);assert(d.target==b,'the crew did not keep working at the moved square after the player left')
assert(Mining.selectorTouches(p.miningSquare.center,p.miningSquare.half,edge.part.CFrame,edge.part.Size),'boundary overlap must count')
assert(not Mining.selectorTouches(p.miningSquare.center,p.miningSquare.half,a.part.CFrame,a.part.Size))

-- Mining regenerates health and restores its stage, with a single ore ledger.
d.pos=Feel.mineGoal(b.position,d.targetSlot,false,b.fullSize,b.referenceCrystal)
assert(hitResource(d,b,65,false));local paid=b.extractedOre;assert(paid==nil,'a crack duplicated the ordinary final cargo reward')
release(d)
local stage=b.stage
for _=1,15 do now+=.23;scene.regrow(b,.23) end
assert(b.hp==b.maxHP-10 and b.stage==0 and b.stage<stage and b.extractedOre==paid)
step(15);assert(d.target==b)
d.pos=Feel.mineGoal(b.position,d.targetSlot,false,b.fullSize,b.referenceCrystal)
b.hardness=3
assert(hitResource(d,b,65,false));assert(b.extractedOre==paid,'regrowth duplicated layer payout')

-- A depleted worker drops the reservation, physically approaches the pad,
-- charges there and resumes against the latest pin.
d.battery=0
step(1);assert(d.state=='ToCharge' and d.recharging and not d.target)
assert(d.resumeResourceId==b.id and not next(b.slots),'the interrupted cut must remain available to other crews')
status('Recharging')
local nearer=rock(1,100)
nearer.lastPin=p.miningSquare;nearer.lastPinOwner=d.owner;nearer.hp=nearer.maxHP-15
for _=1,1200 do step(1);if not d.recharging then break end end
assert(not d.recharging and d.battery==d.stats.batteryCapacity,'failed to recharge at the pad')
step(1);assert(d.target==b and d.squareJob==p.miningSquare,'charged worker picked a different unfinished cut')
assert(d.state=='Travel' and travelSpeed(d)==d.stats.maxStep60*1.5,'return to the field lost the charger travel speed')
resources[nearer.id]=nil;nearer.part:Destroy()
release(d);d.field=nil
local profile=data(p)
local full=Ca.capacity(profile)
Pro.addCargo(profile,'Quartz',full,full)
local oreBefore=pendingOre(p)
step(30);local overflowTarget=assert(d.target,'full backpack prevented a new mining job')
assert(d.squareJob==p.miningSquare)
d.pos=committedStation(d,overflowTarget);d.velocity=Vector3.zero
for _=1,100 do step(1);if d.mining then break end end
assert(d.mining);status('BagFull')
for _=1,600 do step(1);if overflowTarget.paid then break end end
assert(overflowTarget.paid and pendingOre(p)>oreBefore,'mining a full bag did not leave collectible ore')
assert(Pro.cargoUnits(profile)==10 and full==10)
profile.run.stars=8
local function star(id,tx)
 command.OnServerEvent:Fire(pl,'BuyStarUpgrade',{runId=data(p).run.id,upgradeId=id,level=0,txId=tx})
end
star('autosell','remote')
assert(Workshop.starLevel(data(p),'autosell')==0,'remote Star Shop purchase succeeded')
pl.Character:PivotTo(CFrame.new(shopStations.Ruby.Position+Vector3.new(0,3,0)))
star('autosell','autofull');star('walk','fast')
assert(data(p).run.stars==0 and Workshop.starLevel(data(p),'autosell')==1)
assert(pl.Character:FindFirstChildOfClass('Humanoid').WalkSpeed==18,'walk speed upgrade was not applied')
pl.Character:PivotTo(CFrame.new(Vector3.new(0,8,-68)))
local earnings=data(p).run.quartzEarnings
for _=1,4 do realTime+=.13;heartbeat:Fire(.13) end
assert(Pro.cargoUnits(data(p))<full and data(p).run.quartzEarnings==earnings+full,'Auto Sell did not sell the full bag exactly once')
pl.Character:PivotTo(CFrame.new(Vector3.new(0,8,20)))
command.OnServerEvent:Fire(pl,'Recall');step(1)
assert(not p.miningSquare and not d.target and d.state=='Follow' and d.goal.Z>0,'explicit recall failed to bring back the fleet')
assert(pl:GetAttribute('MA_Selector')==nil and pl:GetAttribute('MA_SelectorWorking')==nil)
status(nil)
print('PASS Crystal Run pin, status transitions, reservations, recall, edge overlap, committed work, regrowth, charging, full-bag mining and Star Shop effects')


-- Exercise the larger route's population budget and station geometry with
-- the production spawner. A busy patch must not shift its rocks into a lane.
f.cfg.Count,f.cfg.Ore=48,10
f.clusters={}
for i,x in ipairs({0,-34,34}) do
 f.clusters[i]=World.part(zone,'Patch'..i,Vector3.new(x,4.512,-68),Vector3.new(30,2,30),f.color)
end
seedField(f)
assert(#f.resources==48 and #f.respawnQueue==0)
local counts,positions={},{}
for _,r in ipairs(f.resources) do
 local patch=r.cluster;local pos=r.position-patch.Position
 assert(math.abs(pos.X)<=15 and math.abs(pos.Z)<=15 and pos.X%1==0 and pos.Z%1==0)
 assert(math.abs(pos.Y-3)<.001)
 local key=string.format('%d,%d',r.position.X,r.position.Z)
 assert(not positions[key],'coincident reference crystals');positions[key]=true
 counts[patch]=(counts[patch] or 0)+1
 assert(math.abs((Feel.mineGoal(r.position,1,false,r.fullSize,r.referenceCrystal)-r.position).Y-7)<.001)
end
for _,patch in ipairs(f.clusters) do assert(counts[patch]==16) end
local crewPlayer=player(98702);players.PlayerAdded:Fire(crewPlayer)
local crew=profiles[crewPlayer.UserId]
crewPlayer.Character:PivotTo(CFrame.new(Vector3.new(0,8,-68)))
command.OnServerEvent:Fire(crewPlayer,'PlaceSelector',{runId=data(crew).run.id,fieldId=f.id,position=Vector3.new(0,5.5,-68)})
assert(#crew.drones==3 and crew.miningSquare.half*2==f.clusters[1].Size.X)
for _,r in ipairs(f.resources) do
 if r.cluster==f.clusters[1] then
  assert(Mining.selectorTouches(crew.miningSquare.center,crew.miningSquare.half,r.part.CFrame,r.part.Size))
 end
 r.readyAt=now
end
local reserved={}
for _,worker in ipairs(crew.drones) do
 droneStep(worker,C.Tick)
 assert(worker.target and worker.target.cluster==f.clusters[1] and not reserved[worker.target])
 reserved[worker.target]=true
end
players.PlayerRemoving:Fire(crewPlayer)
local retired=f.resources[23]
retired.paid=true
local ok,_,plan=spawnResource(f,'Crystal',true)
assert(ok and plan.cluster==retired.cluster,'grower preview must use the patch with a vacancy')
local planted,_,replacement=spawnResource(f,'Crystal',false,plan)
assert(planted and replacement.cluster==retired.cluster and nodeUsage(f)==48)
replacement.readyAt=now
assert(assignOre(p,d,replacement))
p.miningSquare={field=f,center=Vector3.new(replacement.position.X,5.5,replacement.position.Z),half=7}
d.squareJob=p.miningSquare;d.lingerUntil=nil
d.pos=committedStation(d,replacement);d.velocity=Vector3.zero
assert(math.abs(d.pos.Y-replacement.cluster.Position.Y-10)<.001)
local before=replacement.hp
step(1);assert(d.state=='Warmup' and replacement.hp==before)
step(12);assert(d.mining and replacement.hp<before,'close cut still has the old pause')
release(d)
p.miningSquare={field=f,center=Vector3.new(0,5.5,-68),half=7}
d.pos=Vector3.new(0,14.5,-68)
assert(scene.holdSquare(d,p,C.Tick) and math.abs(d.intentGoal.Y-f.clusters[1].Position.Y-10)<.001)
print('PASS full reference-sized patch populations, refill locality, mining and standby heights')

do
 local deep=table.clone(f)
 deep.cfg=table.clone(f.cfg)
 deep.cfg.Key='Ruby';deep.cfg.Material='RunRuby';deep.cfg.Hardness=3;deep.cfg.Value=4
 deep.resources={}
 seedField(deep)
 assert(#deep.resources==48,'deep patches failed to fill at mixed crystal sizes')
 local low,high=math.huge,0
 for i,r in ipairs(deep.resources) do
  local base=r.part:GetAttribute('GroundY')
  assert(math.abs(base-(r.cluster.Position.Y+Feel.ReferenceCrystalPivot-1.5+.06))<.001)
  assert(r.part:GetAttribute('OreValue')==r.ore*deep.cfg.Value)
  low=math.min(low,r.ore);high=math.max(high,r.ore)
  for j=1,i-1 do
   local other=deep.resources[j]
   if r.cluster~=other.cluster then continue end
   local a=ResourcePlacement.radius(r.fullSize.X,r.fullSize.Y,r.fullSize.Z,r.kind,true)
   local b=ResourcePlacement.radius(other.fullSize.X,other.fullSize.Y,other.fullSize.Z,other.kind,true)
   local delta=r.position-other.position
   assert(Vector3.new(delta.X,0,delta.Z).Magnitude>=a+b,'deep deposits overlapped their turn clearance')
   assert((r.hp-other.hp)*(r.fullSize.Y-other.fullSize.Y)>=0,'size did not predict work')
  end
  resources[r.id]=nil;r.part:Destroy()
 end
 assert(low<=8 and high>=14,'deep field never offered both short and rich cuts')
 print('PASS deep fields expose work and sale value through planted crystal size and keep separate turn clearance')
end

-- Earn a first pack at the Workshop, then exercise all three actual choices.
local shopper=player(98703);players.PlayerAdded:Fire(shopper)
scene.runStart=f.center
local buyer=profiles[shopper.UserId];scene.syncRuntimeFleet(buyer)
local miner=buyer.drones[1]
local function moveBuyer(position)
 shopper.Character:PivotTo(CFrame.new(position+Vector3.new(0,3,0)))
end
local function input(action,tx,fields)
 buyer.tokens=7;buyer.bucketAt=now
 local payload=fields or {};payload.txId=tx;payload.runId=data(buyer).run.id
 command.OnServerEvent:Fire(shopper,action,payload)
end
Pro.addCargo(data(buyer),Workshop.cargoKey('Quartz',10),2,10)
moveBuyer(f.center);input('Sell','remote')
assert(Pro.cargoUnits(data(buyer))==2 and data(buyer).run.wallet.Quartz==0,'sale worked away from the depot')
moveBuyer(shopStations.Quartz.Position);input('Sell','sale')
assert(Pro.cargoUnits(data(buyer))==0 and data(buyer).run.wallet.Quartz==20 and data(buyer).run.quartzEarnings==20)
moveBuyer(scene.packStation.Position)
input('BuyPack','first',{packIndex=0})
local first=assert(data(buyer).run.pendingOffer)
assert(first.packTier==2 and data(buyer).run.wallet.Quartz==0)
for i,id in ipairs(Workshop.FIRST_PACK) do assert(first.choices[i].cardId==id and #first.choices[i].preview>0) end
local resumed=assert(Pro.migrate(Pro.clone(data(buyer)),shopper.UserId))
assert(resumed.run.pendingOffer.id==first.id and resumed.run.pendingOffer.choices[1].cardId=='Q_DOUBLE_BEAM')
assert(not resumed.run.pendingOffer.choices[1].targetDroneId,'paid offer preassigned the part')
local delivery=assert(buyer.packDelivery)
realTime+=Packs.DeliveryTime+.1;now=realTime;packDelivery:step(buyer,now);moveBuyer(delivery.part.Position)
delivery.prompt.Triggered:Fire(shopper)
local opened=Pro.clone(data(buyer));assert(opened.run.pendingOffer.opened)
local otherMiner=buyer.drones[2]
local baselineDPS=miner.stats.miningDPS
moveBuyer(scene.packStation.Position)
input('ChooseCard','no-target',{offerId=first.id,index=1})
input('ChooseCard','foreign-target',{offerId=first.id,index=1,targetDroneId='98700:drone:1'})
assert(data(buyer).run.pendingOffer and data(buyer).run.stars==0,'invalid fit consumed a paid pack')
input('ChooseCard','first-choice',{offerId=first.id,index=1,targetDroneId=miner.id})
local installed=data(buyer).run.cards[1]
assert(data(buyer).run.stars==2 and #data(buyer).run.cards==1 and installed.targetDroneId==miner.id)
assert(miner.stats.doubleBeam==1 and miner.stats.miningDPS==2*baselineDPS and otherMiner.stats.doubleBeam==0)
local saved=assert(Pro.migrate(Pro.clone(data(buyer)),shopper.UserId))
assert(saved.run.cards[1].targetDroneId==miner.id)
input('ChooseCard','first-choice',{offerId=first.id,index=1,targetDroneId=otherMiner.id})
assert(#data(buyer).run.cards==1 and data(buyer).run.stars==2 and otherMiner.stats.doubleBeam==0)
snapshotDrone(miner);snapshotDrone(otherMiner)
assert(miner.model:GetAttribute('DoubleBeam')==true and otherMiner.model:GetAttribute('DoubleBeam')==false)

local function isolate()
 release(miner)
 for _,r in ipairs(f.resources) do r.paid=true;r.hp=0 end
end
local function fitLegacyPart(id)
 local copy=Pro.clone(opened)
 copy.run.pendingOffer.choices[2]=Workshop.card(Workshop.BY_ID[id],2,0)
 assert(Pro.validate(copy,shopper.UserId))
 assert(Ca.select(copy,first.id,2,'test-variant-'..id,copy.run.id,{atDepot=true,targetDroneId=miner.id}))
 buyer.session.data=copy;refreshStats(buyer)
end
local function hit(r,amount)
 assert(assignOre(buyer,miner,r));miner.pos=committedStation(miner,r)
 assert(hitResource(miner,r,amount))
end
local function timedCut()
 isolate()
 local rock=rock(0,1000)
 assert(assignOre(buyer,miner,rock));miner.pos=committedStation(miner,rock);miner.velocity=Vector3.zero
 mineDrone(miner,buyer,f,C.Tick)
 miner.warmAt=now-10
 local hp=rock.hp
 for _=1,20 do realTime+=C.Tick;now=realTime;mineDrone(miner,buyer,f,C.Tick) end
 return hp-rock.hp
end
local doubleDamage=timedCut()
buyer.session.data=Pro.clone(opened);refreshStats(buyer)
local singleDamage=timedCut()
assert(singleDamage>0 and math.abs(doubleDamage-2*singleDamage)<1e-8,'production laser ticks did not deal 2× damage')
fitLegacyPart('Q_TURBO_ROTOR');snapshotDrone(miner)
assert(travelSpeed(miner)==2*miner.owned.base.maxStep60 and miner.model:GetAttribute('TwinThrusters')==true)
assert(not miner.model:GetAttribute('DoubleBeam') and otherMiner.stats.twinThrusters==0)
fitLegacyPart('Q_ORE_DUPLICATOR');snapshotDrone(miner);isolate()
local oreBefore=pendingOre(buyer)
local rich=rock(0,100)
hit(rich,40);assert(hitResource(miner,rich,200))
assert(miner.model:GetAttribute('OreDuplicator')==true and otherMiner.stats.oreDuplicator==0)
assert(pendingOre(buyer)-oreBefore==1,'one crystal created more than one reward object')
local reward=assert(pickups[pickupSerial])
assert(reward.value==2*rich.ore and reward.units==1 and rich.part:GetAttribute('CrystalBreakAt')==now,
 'double value and immediate break receipt must accompany one cargo')

moveBuyer(f.center)
input('PlaceSelector','pin',{fieldId=f.id,position=Vector3.new(0,5.5,-68)})
assert(buyer.miningSquare)
moveBuyer(f.center+Vector3.new(80,0,0));recallFromField(buyer)
assert(buyer.miningSquare,'nearby selling trip lost the pin')
moveBuyer(f.center+Vector3.new(101,0,0));recallFromField(buyer)
assert(not buyer.miningSquare and not miner.target and miner.state=='Follow','distant player did not get the crew back')

moveBuyer(f.center)
input('PlaceSelector','charger-pin',{fieldId=f.id,position=Vector3.new(0,5.5,-68)})
table.insert(data(buyer).run.cards,Workshop.card(Workshop.BY_ID.Q_FIELD_CHARGE,3))
publish(buyer)
miner.battery=0
droneStep(miner,C.Tick)
assert(miner.recharging and (miner.intentGoal-buyer.miningSquare.center).Magnitude<10,'Field Charger still sent the drone to the depot')
miner.pos=miner.intentGoal;droneStep(miner,C.Tick)
assert(miner.battery>0 and miner.state=='Charging' and miner.chargeSite=='Field')
print('PASS paid hardware draft, durable miner target, exact double primary damage/flight limit/ore, field charging and distance recall')

moveBuyer(shopStations.Ruby.Position)
input('BuyStarUpgrade','hire-vacuum',{upgradeId='vacuum',level=0})
input('BuyStarUpgrade','hire-planter',{upgradeId='cultivator',level=0})
assert(data(buyer).run.stars==2 and not buyer.vacuum and #buyer.drones==5)
data(buyer).run.starUpgrades.vacuum=1;data(buyer).run.starUpgrades.cultivator=1
buyer.session.data=assert(Pro.migrate(Pro.clone(data(buyer)),shopper.UserId))
scene.syncRuntimeFleet(buyer)
local planter=buyer.drones[7]
assert(planter.role=='Dart' and buyer.vacuum and #data(buyer).fleet==3 and Pro.validate(data(buyer),shopper.UserId))
moveBuyer(f.center)
local count,queued=nodeUsage(f),#f.respawnQueue
growerDrone(planter,buyer,characterRoot(buyer),C.Tick)
assert(planter.growPlan and planter.growPlan.cluster==f.clusters[1],'planter picked another patch')
planter.pos=planter.intentGoal
for _=1,100 do
 realTime+=C.Tick;now=realTime;growerDrone(planter,buyer,characterRoot(buyer),C.Tick)
 if nodeUsage(f)>count then break end
end
assert(nodeUsage(f)==count+1 and #f.respawnQueue==queued-1,'planter did not consume one actual vacancy')
print('PASS Star purchases cannot grant drones; saved legacy automation still works')

inStudio=true
function runService:IsStudio() return true end
local tester=player(98704);players.PlayerAdded:Fire(tester)
local testCrew=profiles[tester.UserId]
tester.Character:PivotTo(CFrame.new(f.center+Vector3.new(0,3,0)))
assert(#testCrew.drones==9 and #data(testCrew).fleet==7 and Ca.capacity(data(testCrew),previewPerks(testCrew))==10)
local starterActors={}
for _,actor in ipairs(testCrew.drones) do starterActors[actor.role]=actor end
for _,role in ipairs(Workshop.STARTER_SPECIALISTS) do assert(starterActors[role],'missing starter role '..role) end
local saved=assert(Pro.migrate(Pro.clone(data(testCrew)),tester.UserId))
assert(#saved.fleet==7 and Workshop.hasCompactor(saved) and not testCrew.testFleet)
saved.run.quartzEarnings=360
local choice=Pro.prestigePreview(saved).droneChoices[1]
assert(Pro.prestige(saved,'mixed-starter-prestige',saved.run.id,{confirmed=true,atDepot=true,droneType=choice.kind}))
assert(#saved.fleet==8 and Pro.validate(saved,tester.UserId))
for i,role in ipairs({'Needler','Ballcaster'}) do
 local actor=starterActors[role];local target=rock(i*4,150)
 assert(assignOre(testCrew,actor,target))
 local station=committedStation(actor,target)
 local offset=station-target.position
 assert(math.abs(Vector3.new(offset.X,0,offset.Z).Magnitude-9)<.001,'projectile was not aimed from the side')
 actor.pos=station
 local before=target.hp
 for _=1,50 do
  realTime+=C.Tick;now=realTime;droneStep(actor,C.Tick)
  if actor.specialJob then break end
 end
 assert(actor.specialJob and actor.specialJob.projectile and target.hp==before,'shot damaged before it traveled')
 for _=1,60 do
  realTime+=C.Tick;now=realTime;droneStep(actor,C.Tick)
  if target.hp<before then break end
 end
 assert(target.hp<before,'projectile failed to apply authoritative work')
 assert(target.part:GetAttribute('CutIsShot') and target.part:GetAttribute('CutContactAt')==now)
 assert(actor.specialJob.projectile:GetAttribute('ContactAt')==now)
 release(actor)
end
do
 local deep=table.clone(f)
 deep.id=#patches+1;deep.cfg=table.clone(f.cfg);deep.cfg.Hardness=9
 deep.resources={};deep.respawnQueue={};patches[deep.id]=deep
 local small=makeResource(deep,f.center+Vector3.new(-6,0,0),'Crystal',400,8,2.3,3)
 local large=makeResource(deep,f.center+Vector3.new(6,0,0),'Crystal',910,15,3.7,3)
 small.readyAt=now;large.readyAt=now
 small.hp=90;small.stage=3
 local pin={field=deep,center=f.center,half=15}
 local needler,ballcaster=starterActors.Needler,starterActors.Ballcaster
 needler.pos=f.center;ballcaster.pos=f.center
 assert(chooseResource(needler,deep,pin)==small,'Needler did not pick the quick finish')
 release(needler)
 assert(chooseResource(ballcaster,deep,pin)==large,'Ballcaster did not pick the thick shell')
 ballcaster.field=deep.id
 local station=committedStation(ballcaster,large)
 assert(station.X<large.position.X,'Ballcaster flew past the rock for its opening shot')
 ballcaster.pos=station;ballcaster.velocity=Vector3.zero
 local base=DroneCatalog.cycle('Ballcaster',ballcaster.owned.base.miningDPS,ballcaster.stats.miningDPS).damage
 local function shot()
  local before=large.hp
  for _=1,120 do
   realTime+=C.Tick;now=realTime;droneStep(ballcaster,C.Tick)
   if large.hp<before then return before-large.hp end
  end
  error('Ballcaster missed a committed deep shot')
 end
 assert(math.abs(shot()-base*1.5)<1e-6,'a landed ball did not gain its shell damage')
 for _=1,12 do if large.stage<2 then shot() else break end end
 assert(large.stage==2 and math.abs(shot()-base)<1e-6,'the shell bonus stayed on an exposed core')
 release(ballcaster);ballcaster.field=nil
 for _,r in ipairs(deep.resources) do resources[r.id]=nil;r.part:Destroy() end
 patches[deep.id]=nil
 print('PASS projectile miners choose different deep targets; Ballcaster lands stronger shell hits from its approach side')
end
for id,drop in pairs(pickups) do
 if drop.owner==tester.UserId then drop.part:Destroy();pickups[id]=nil end
end
do
 local square={field=f,center=f.center,half=15}
 testCrew.miningSquare=square
 local position=f.center+Vector3.new(0,.7,0)
 local part=World.part(pickupFolder,'PackedOreForPickup',position,Vector3.one,Color3.new(1,1,1))
 pickups[-2]={part=part,owner=tester.UserId,runId=data(testCrew).run.id,material=Workshop.cargoKey('Quartz',20,true),
  units=1,raw=true,compacted=true,fieldPart=bed,spawnAt=now,age=1,x=position.X,y=position.Y,z=position.Z,
  vx=0,vy=0,vz=0,floor=position.Y,landed=true,firstLandedAge=.65}
 tester.Character:PivotTo(CFrame.new(position+Vector3.new(68,2,0)))
 pickupStep(C.Tick);scene.publishSquareStatus(testCrew)
 assert(tester:GetAttribute('MA_SelectorStatus')=='LooseOre' and not testCrew.vacuumTarget)
 tester.Character:PivotTo(CFrame.new(position+Vector3.new(11,2,0)))
 pickupStep(C.Tick);scene.publishSquareStatus(testCrew)
 assert(pickups[-2].homing and not testCrew.vacuumTarget,'Vacuum intercepted ore already on its way to the bag')
 assert(tester:GetAttribute('MA_SelectorStatus')~='LooseOre','pickup hint survived after the player reached the ore')
 part:Destroy();pickups[-2]=nil
 scene.clearSquare(testCrew)
 tester.Character:PivotTo(CFrame.new(f.center+Vector3.new(0,3,0)))
 print('PASS settled cargo beyond the Vacuum prompts a walk; reachable ore goes straight to the backpack')
end
local dropPosition=characterRoot(testCrew).Position+Vector3.new(40,-2,0)
local dropPart=World.part(pickupFolder,'VacuumTest',dropPosition,Vector3.one,Color3.new(1,1,1))
pickups[-1]={part=dropPart,owner=tester.UserId,runId=data(testCrew).run.id,material='Quartz',units=2,spawnAt=now,age=1,
 x=dropPosition.X,y=dropPosition.Y,z=dropPosition.Z,vx=0,vy=0,vz=0,floor=dropPosition.Y,landed=true}
pickupStep(C.Tick)
assert(testCrew.vacuumTarget and testCrew.vacuumTarget.id==-1 and not pickups[-1].homing)
testCrew.vacuum.pos=testCrew.vacuumTarget.position
local relayed=false
for _=1,200 do
 realTime+=C.Tick;now=realTime;pickupStep(C.Tick)
 if not pickups[-1] then break end
 if pickups[-1].relayUntil then relayed=true end
end
assert(relayed and not pickups[-1] and Pro.cargoUnits(data(testCrew))==2,string.format('vacuum relay=%s, drop=%s, backpack=%d',tostring(relayed),tostring(pickups[-1]),Pro.cargoUnits(data(testCrew))))
assert(Pro.validate(data(testCrew),tester.UserId))
print('PASS curated starter fleet, stable prestige ownership, projectile flight and vacuum relay')

buyer.session.data=Pro.clone(opened);refreshStats(buyer)
moveBuyer(scene.packStation.Position)
input('ChooseCard','aftershock',{offerId=first.id,index=3})
isolate()
local source,neighbor,farther=rock(0,1000),rock(5,1000),rock(9,1000)
hit(source,270)
assert(math.abs(neighbor.hp-(990-990*.12))<1e-8 and farther.hp==990,'Aftershock must reach exactly one neighbor')
assert(hitResource(miner,source,1) and math.abs(neighbor.hp-(990-990*.12))<1e-8,'Aftershock procced without a crack')

buyer.session.data=Pro.clone(opened);refreshStats(buyer)
data(buyer).run.pendingOffer.choices[3]=Workshop.card(Workshop.BY_ID.Q_COMPACTOR,2,0)
input('ChooseCard','hire-press',{offerId=first.id,index=3})
local press=assert(buyer.compactor)
assert(press.role=='Compactor' and #data(buyer).fleet==3 and #buyer.drones==8)
input('ChooseCard','hire-press',{offerId=first.id,index=3})
assert(#buyer.drones==8 and Workshop.hasCompactor(assert(Pro.migrate(Pro.clone(data(buyer)),shopper.UserId))))
moveBuyer(f.center+Vector3.new(33,0,0))
input('PlaceSelector','press-pin',{fieldId=f.id,position=Vector3.new(0,5.5,-68)})
assert(buyer.miningSquare)
for id,drop in pairs(pickups) do if drop.owner==shopper.UserId then drop.part:Destroy();pickups[id]=nil end end
local floor=f.center+Vector3.new(0,.75,0)
local function pressOre(material,value,owner,position)
 scene.spawnOrePickup(bed,{owner=owner or shopper.UserId,runId=data(buyer).run.id,nodeId='press-test',
  material=Workshop.cargoKey(material,value),tierMaterial=material,value=value,raw=true,units=1,
  floor=floor.Y,fieldPart=bed},position or floor,Vector3.zero,Color3.new(1,0,0))
 local drop=pickups[pickupSerial];drop.age=1;drop.landed=true
 return drop
end
tester.Character:PivotTo(CFrame.new(f.center+Vector3.new(-130,3,0)))
local foreign=pressOre('Quartz',70,tester.UserId);foreign.runId=data(testCrew).run.id
Pro.addCargo(data(buyer),'Quartz',10,10)
press.pos=floor+Vector3.new(0,3.2,0)
local function pressTicks(count)
 for _=1,count do realTime+=C.Tick;now=realTime;pickupStep(C.Tick) end
end
local lone=pressOre('Quartz',5)
local remote=pressOre('Quartz',6,nil,floor+Vector3.new(20,0,0))
pressTicks(20)
assert(not buyer.compactorTarget and not lone.pressSocket and not remote.pressSocket,'isolated rocks started a batch')
local relaying=pressOre('Quartz',7)
relaying.relayUntil=now+1
pressTicks(20)
assert(not buyer.compactorTarget and not relaying.pressSocket,'press interrupted an in-flight Vacuum relay')
for _,drop in ipairs({lone,remote,relaying}) do
 pickups[drop.part:GetAttribute('PickupId')]=nil;drop.part:Destroy()
end
local raw={pressOre('Quartz',10),pressOre('Quartz',12),pressOre('Quartz',14),pressOre('Quartz',16)}
for _=1,50 do
 pressTicks(1)
 if raw[2].pressSocket then break end
end
assert(raw[1].pressSocket==1 and raw[2].pressSocket==2 and not raw[3].pressSocket)
assert(raw[1].x~=raw[2].x or raw[1].z~=raw[2].z,'press inputs overlapped')
pressTicks(70)
local pressedOre=pickups[pickupSerial]
assert(pressedOre.units==1 and pressedOre.tierMaterial=='Quartz' and pressedOre.compacted)
assert(pressedOre.value==36,'press lost value or minted Quartz')
pressTicks(math.ceil(1.5/C.Tick))
assert(not raw[4].pressSocket and raw[4].part.Parent and not buyer.compactorTarget,'a single rock was trapped')
assert(foreign.part.Parent and Pro.cargoUnits(data(buyer))==10,'press changed foreign ore or a full bag')

pressOre('RunEmerald',2560);pressOre('RunEmerald',2700)
pressTicks(math.ceil(2.75/C.Tick))
local deepBlock=pickups[pickupSerial]
assert(deepBlock.tierMaterial=='RunEmerald' and deepBlock.compacted and deepBlock.units==1 and deepBlock.value==5260)
assert(pressedOre.part.Parent and pressedOre.units==1,'already compacted cargo entered the press again')
print('PASS Compactor leaves isolated rocks and Vacuum relays alone, and ejects two-rock batches sooner')

table.insert(data(buyer).run.cards,Workshop.card(Workshop.BY_ID.Q_BATCH_PRESS,3));publish(buyer)
pressOre('RunRuby',40);pressOre('RunRuby',41)
pressTicks(90)
local upgraded=pickups[pickupSerial]
assert(upgraded.tierMaterial=='RunRuby' and upgraded.units==1 and upgraded.value==81)

local legacyPress=table.remove(data(buyer).run.cards)
table.insert(data(buyer).run.cards,Workshop.card(Workshop.BY_ID.Q_DENSER_PACK,3));publish(buyer)
assert(buyer.compactorBatch==5)
for value=50,54 do pressOre('RunCobalt',value) end
pressTicks(150)
local dense=pickups[pickupSerial]
assert(dense.tierMaterial=='RunCobalt' and dense.compacted and dense.units==1 and dense.value==260,
 'a partial timer fired before the five-rock batch finished')
table.remove(data(buyer).run.cards);table.insert(data(buyer).run.cards,legacyPress);publish(buyer)

-- Actual movement consumes one parcel and unloads its manifest exactly once.
local emptier=buyer.drones[4]
assert(emptier.role=='Courier')
table.insert(data(buyer).run.cards,Workshop.card(Workshop.BY_ID.Q_SHIFT_RELAY,3));publish(buyer)
data(buyer).run.cargo={RunRuby=Workshop.EMPTIER_BATCH}
local hr=characterRoot(buyer);emptier.pos=hr.Position+Vector3.new(2.2,2.4,1)
droneStep(emptier,C.Tick);now+=1;droneStep(emptier,C.Tick);serviceDeliveries(buyer)
local manifest=assert(data(buyer).run.deliveries[emptier.id])
assert(manifest.cargo.RunRuby==Workshop.EMPTIER_BATCH and Pro.cargoUnits(data(buyer))==0)
snapshotDrone(emptier)
local counter=scene.packStation
local landing=counter.CFrame:PointToObjectSpace(emptier.model:GetAttribute('SellPosition'))
assert(math.abs(landing.Y-counter.Size.Y*.5)<.001 and math.abs(landing.Z-counter.Size.Z*.22)<.001)
local secondEmptier=buyer.drones[5]
assert(secondEmptier.role=='Courier')
snapshotDrone(secondEmptier)
local otherLanding=counter.CFrame:PointToObjectSpace(secondEmptier.model:GetAttribute('SellPosition'))
assert(math.abs(landing.X+otherLanding.X)<.001 and math.abs(landing.X)>1,'both couriers unloaded into the same lane')
assert(Pro.validate(assert(Pro.migrate(Pro.clone(data(buyer)),shopper.UserId)),shopper.UserId))
now+=1;emptier.pos=scene.packStation.Position
droneStep(emptier,C.Tick);emptier.pos=emptier.goal
droneStep(emptier,C.Tick);now+=1;droneStep(emptier,C.Tick)
local prior=data(buyer).run.quartzEarnings
serviceDeliveries(buyer);serviceDeliveries(buyer)
assert(not data(buyer).run.deliveries[emptier.id] and data(buyer).run.quartzEarnings==prior+4*Workshop.EMPTIER_BATCH)
assert(data(buyer).run.wallet.Ruby==0 and data(buyer).run.wallet.Quartz==4*Workshop.EMPTIER_BATCH)
assert(buyer.shiftUntil==now+12 and buyer.shiftSquare==buyer.miningSquare)
table.insert(data(buyer).run.cards,Workshop.card(Workshop.BY_ID.Q_CARGO_RACK,2));publish(buyer)
data(buyer).run.cargo={[Workshop.cargoKey('RunEmerald',5260,true)]=1}
now+=3;emptier.pos=hr.Position+Vector3.new(2.2,2.4,1)
droneStep(emptier,C.Tick);assert(not emptier.pickupAt)
now+=Workshop.EMPTIER_WAIT;droneStep(emptier,C.Tick)
now+=1;droneStep(emptier,C.Tick);serviceDeliveries(buyer)
assert(Pro.deliveryUnits(data(buyer),emptier.id)==1 and Pro.cargoUnits(data(buyer))==0)
snapshotDrone(emptier)
assert(emptier.model:GetAttribute('DeliverySlots')==5 and emptier.model:GetAttribute('DeliveryMaterials')=='Block:RunEmerald:5260')
isolate()
local boosted=rock(0,1000)
assert(assignOre(buyer,miner,boosted));miner.squareJob=buyer.miningSquare;miner.pos=committedStation(miner,boosted)
assert(hitResource(miner,boosted,10) and boosted.hp==975)
now=buyer.shiftUntil;assert(hitResource(miner,boosted,10) and boosted.hp==965)

isolate()
local deep=rock(0,Mining.resource(75,'Crystal',81).maxHP)
deep.hardness=81
assert(assignOre(buyer,miner,deep));miner.squareJob=buyer.miningSquare;miner.pos=committedStation(miner,deep)
assert(hitResource(miner,deep,100));local hp=deep.hp
release(miner);now+=5;scene.regrow(deep,.23)
assert(deep.hp==hp,'charging lost progress on a pinned deep crystal')
local fresh=rock(1,deep.maxHP);fresh.hardness=81;miner.pos=fresh.position
assert(chooseResource(miner,f,buyer.miningSquare)==deep,'returning drone ignored its unfinished deep cut')
release(miner);scene.clearSquare(buyer);now+=5;scene.regrow(deep,.23)
assert(deep.hp>hp,'recalling failed to restore ordinary healing')
table.insert(data(buyer).run.cards,Workshop.card(Workshop.BY_ID.Q_LIVE_WIRE,3));refreshStats(buyer)
local live=rock(0,1000)
miner.battery=miner.stats.batteryCapacity;hit(live,10)
assert(live.hp==975,'Live Wire did not amplify a high-battery hit')
miner.battery=miner.stats.batteryCapacity*.5
assert(hitResource(miner,live,10) and live.hp==965,'Live Wire activated below its battery threshold')
print('PASS Aftershock, Live Wire, Compactor conversion, durable Emptier sales, Shift Relay timing and deep-cut recharge')

do
 local tester=player(98692);players.PlayerAdded:Fire(tester)
 local other=player(98693);players.PlayerAdded:Fire(other)
 local crew,rival=profiles[tester.UserId],profiles[other.UserId]
 local worker=crew.drones[1]
 local center=bed.Position+Vector3.new(0,.5,12)
 local quick=makeResource(f,center+Vector3.new(0,0,-2),'Crystal',75,7,2.2,3)
 local rich=makeResource(f,center+Vector3.new(0,0,9),'Crystal',200,15,3.7,3)
 local third=makeResource(f,center+Vector3.new(8,0,9),'Crystal',145,12,3,3)
 quick.readyAt=now;rich.readyAt=now;third.readyAt=now
 tester.Character:PivotTo(CFrame.new(center+Vector3.yAxis*3))
 worker.pos=quick.position+Vector3.yAxis*4
 local function request(leadId,position)
  scene.placeSquare(crew,{runId=data(crew).run.id,fieldId=f.id,position=position or center,leadId=leadId})
 end
 local outside=makeResource(f,center+Vector3.new(25,0,0),'Crystal',100,10,3,3)
 request(outside.id)
 assert(crew.miningSquare and not crew.miningSquare.leadId,'an out-of-square target became the lead')
 request(rich.id,center+Vector3.new(0,0,66))
 assert(not crew.miningSquare.leadId,'remote focus bypassed pin range')
 rich.slots[rival.drones[1].id]=1
 request(rich.id)
 assert(not crew.miningSquare.leadId,'a claimed target became the lead')
 rich.slots[rival.drones[1].id]=nil
 local current=crew.miningSquare
 request(rich.id)
 assert(crew.miningSquare==current and current.leadId==rich.id,'same-cell focus did not update the pin')
 scene.squareStep(crew,worker)
 assert(worker.target==rich and not current.leadId and rich.slots[worker.id],'the selected valuable crystal did not get one real assignment')
 worker.warmAt=now
 request(third.id)
 scene.squareStep(crew,worker)
 assert(worker.target==rich and worker.warmAt and current.leadId==third.id,'a same-cell lead interrupted an active cut')
 release(worker)
 now+=.25
 scene.squareStep(crew,worker)
 assert(worker.target==third and not current.leadId,'the next free worker did not take the new lead')
 release(worker)
 now+=.25
 scene.squareStep(crew,worker)
 assert(worker.target==quick,'the consumed lead changed ordinary square dispatch')
 players.PlayerRemoving:Fire(tester);players.PlayerRemoving:Fire(other)
 for _,r in ipairs({quick,rich,third,outside}) do resources[r.id]=nil;r.part:Destroy() end
end
print('PASS direct crystal focus assigns one available worker without stealing or interrupting cuts')

do
 local tester=player(98694);players.PlayerAdded:Fire(tester)
 local other=player(98695);players.PlayerAdded:Fire(other)
 local crew,rival=profiles[tester.UserId],profiles[other.UserId]
 local first,second,third=table.unpack(crew.drones,1,3)
 local folder=Instance.new('Folder');folder.Name='DeepPair';folder.Parent=run
 local surface=World.part(folder,'Field',Vector3.new(80,5,-68),Vector3.new(48,1,48),Color3.new(0,1,0))
 local field={id=#patches+1,cfg={Key='Emerald',Material='RunEmerald',Value=256,Hardness=81,SelectionOnly=true,
  AlwaysUnlocked=true,ReferenceCrystals=true,Turrets=0,Respawn=8},part=surface,model=folder,center=surface.Position,
  color=surface.Color,resources={},turrets={},respawnQueue={},e=R.newEncounter(C)}
 field.e.phase='Safe';patches[field.id]=field
 local center=surface.Position+Vector3.yAxis*.5
 local primary=makeResource(field,center,'Crystal',3900,9,2.8,7)
 local neighbor=makeResource(field,center+Vector3.new(9,0,0),'Crystal',4500,10,3,7)
 primary.readyAt=now;neighbor.readyAt=now
 tester.Character:PivotTo(CFrame.new(center+Vector3.yAxis*3))
 other.Character:PivotTo(CFrame.new(center+Vector3.yAxis*3))
 local function pin(p,leadId)
  scene.placeSquare(p,{runId=data(p).run.id,fieldId=field.id,position=center,leadId=leadId})
 end
 first.pos=primary.position
 pin(crew);local square=crew.miningSquare
 scene.squareStep(crew,first)
 assert(first.target==primary and not square.pairId)
 first.warmAt=now
 pin(rival,primary.id)
 assert(rival.miningSquare and not rival.miningSquare.pairId,'a second crew paired with a foreign cut')
 pin(crew,primary.id)
 assert(crew.miningSquare==square and square.pairId==primary.id and first.warmAt==now)
 scene.squareStep(crew,second);scene.squareStep(crew,third)
 assert(second.target==primary and second.targetSlot==2 and third.target==neighbor,'pair did not use exactly two slots')
 first.pos=committedStation(first,primary);second.pos=committedStation(second,primary)
 assert(math.abs((first.pos-second.pos).Magnitude-3.2)<.001,'two laser stations overlapped')
 first.mining=true;second.mining=true
 scene.publishSquareStatus(crew)
 assert(tester:GetAttribute('MA_SelectorStatus')=='PairCut')
 pin(crew)
 assert(crew.miningSquare==square and not square.pairId and first.target==primary and second.target==primary,'ground pin cut off committed lasers')
 assert(hitResource(first,primary,50) and hitResource(second,primary,50) and primary.hp==3790)
 assert(hitResource(second,primary,10000) and primary.paid and not next(primary.slots))
 assert(not hitResource(first,primary,10000) and pendingOre(crew)==1,'paired finish granted cargo twice')
 players.PlayerRemoving:Fire(tester);players.PlayerRemoving:Fire(other)
end
print('PASS two lasers can share a selected deep cut with separate stations, one reward and no foreign slot')
