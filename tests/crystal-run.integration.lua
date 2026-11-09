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
local f={id=#patches+1,cfg={Key='Quartz',SelectionOnly=true,AlwaysUnlocked=true,ReferenceCrystals=true,Hardness=1,Count=3,Ore=20,Turrets=0,Respawn=8},
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
scene.publishSquareStatus(rival);assert(other:GetAttribute('MA_SelectorStatus')=='Waiting')
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
assert(hitResource(d,b,65,false));local paid=b.extractedOre;assert(paid>0)
release(d)
local stage=b.stage
for _=1,15 do now+=.23;scene.regrow(b,.23) end
assert(b.hp==b.maxHP-10 and b.stage==0 and b.stage<stage and b.extractedOre==paid)
step(15);assert(d.target==b)
d.pos=Feel.mineGoal(b.position,d.targetSlot,false,b.fullSize,b.referenceCrystal)
assert(hitResource(d,b,65,false));assert(b.extractedOre==paid,'regrowth duplicated layer payout')

-- A depleted worker drops the reservation, physically approaches the pad,
-- charges there and resumes against the latest pin.
d.battery=0
step(1);assert(d.state=='ToCharge' and d.recharging and not d.target)
status('Recharging')
for _=1,1200 do step(1);if not d.recharging then break end end
assert(not d.recharging and d.battery==d.stats.batteryCapacity,'failed to recharge at the pad')
step(15);assert(d.target and d.squareJob==p.miningSquare,'charged worker failed to resume')
release(d);d.field=nil
local profile=data(p)
local full=Ca.capacity(profile)
Pro.addCargo(profile,'Quartz',full,full)
local oreBefore=pendingOre(p)
step(30);local overflowTarget=assert(d.target,'full backpack prevented a new mining job')
assert(d.squareJob==p.miningSquare)
d.pos=committedStation(d,overflowTarget)
step(32);assert(d.mining);status('Working')
for _=1,600 do step(1);if overflowTarget.paid then break end end
assert(overflowTarget.paid and pendingOre(p)>oreBefore,'mining a full bag did not leave collectible ore')
assert(Pro.cargoUnits(profile)==100 and full==100)
profile.run.stars=8
local function star(id,tx)
 command.OnServerEvent:Fire(pl,'BuyStarUpgrade',{runId=data(p).run.id,upgradeId=id,level=0,txId=tx})
end
star('autosell','remote')
assert(Workshop.starLevel(data(p),'autosell')==0,'remote Star Shop purchase succeeded')
pl.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.new(0,3,0)))
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
d.pos=committedStation(d,replacement)
assert(math.abs(d.pos.Y-replacement.cluster.Position.Y-10)<.001)
local before=replacement.hp
step(1);assert(d.state=='Warmup' and replacement.hp==before)
step(12);assert(d.mining and replacement.hp<before,'close cut still has the old pause')
release(d)
p.miningSquare={field=f,center=Vector3.new(0,5.5,-68),half=7}
d.pos=Vector3.new(0,14.5,-68)
assert(scene.holdSquare(d,p,C.Tick) and math.abs(d.intentGoal.Y-f.clusters[1].Position.Y-10)<.001)
print('PASS full reference-sized patch populations, refill locality, mining and standby heights')

-- Earn a first pack at the Workshop, then exercise all three actual choices.
scene.runStart=f.center
local shopper=player(98703);players.PlayerAdded:Fire(shopper)
local buyer=profiles[shopper.UserId];local miner=buyer.drones[1]
local function moveBuyer(position)
 shopper.Character:PivotTo(CFrame.new(position+Vector3.new(0,3,0)))
end
local function input(action,tx,fields)
 buyer.tokens=7;buyer.bucketAt=now
 local payload=fields or {};payload.txId=tx;payload.runId=data(buyer).run.id
 command.OnServerEvent:Fire(shopper,action,payload)
end
Pro.addCargo(data(buyer),'Quartz',20,100)
moveBuyer(f.center);input('Sell','remote')
assert(Pro.cargoUnits(data(buyer))==20 and data(buyer).run.wallet.Quartz==0,'sale worked away from the depot')
moveBuyer(shopStations.Quartz.Position);input('Sell','sale')
assert(Pro.cargoUnits(data(buyer))==0 and data(buyer).run.wallet.Quartz==20 and data(buyer).run.quartzEarnings==20)
input('BuyPack','first',{packIndex=0})
local first=assert(data(buyer).run.pendingOffer)
assert(first.packTier==2 and data(buyer).run.wallet.Quartz==0)
for i,id in ipairs(Workshop.FIRST_PACK) do assert(first.choices[i].cardId==id and #first.choices[i].preview>0) end
local resumed=assert(Pro.migrate(Pro.clone(data(buyer)),shopper.UserId))
assert(resumed.run.pendingOffer.id==first.id and resumed.run.pendingOffer.choices[1].cardId=='Q_TWIN_BEAM')
local delivery=assert(buyer.packDelivery)
realTime+=Packs.DeliveryTime+.1;now=realTime;packDelivery:step(buyer,now);moveBuyer(delivery.part.Position)
delivery.prompt.PromptButtonHoldBegan:Fire(shopper)
realTime+=Packs.duration(first.packTier)+.1;now=realTime
delivery.prompt.Triggered:Fire(shopper)
local opened=Pro.clone(data(buyer));assert(opened.run.pendingOffer.opened)
moveBuyer(shopStations.Quartz.Position);input('ChooseCard','first-choice',{offerId=first.id,index=1})
assert(data(buyer).run.stars==2 and #data(buyer).run.cards==1 and miner.stats.forkFraction==.2)
local function isolate()
 release(miner)
 for _,r in ipairs(f.resources) do r.paid=true;r.hp=0 end
end
local function hit(r,amount)
 assert(assignOre(buyer,miner,r));miner.pos=committedStation(miner,r)
 assert(hitResource(miner,r,amount))
end
isolate();local primary,adjacent=rock(0,100),rock(5,100)
local adjacentHP=adjacent.hp
hit(primary,20)
assert(math.abs(adjacentHP-adjacent.hp-4)<.001,'Twin Beam did not damage a second crystal')
local drill=Pro.clone(opened)
assert(Ca.select(drill,first.id,2,'drill',drill.run.id,{atDepot=true}))
buyer.session.data=drill;refreshStats(buyer)
isolate();local shallow=rock(0,100)
local shallowHP=shallow.hp;hit(shallow,20)
assert(shallowHP-shallow.hp==20,'Deep Drill changed starter Quartz damage')
isolate();f.cfg.Hardness=Workshop.DEEP_CUT_HARDNESS
local deep=rock(0,175);local deepHP=deep.hp;hit(deep,20)
assert(math.abs(deepHP-deep.hp-32)<.001,'Deep Drill did not improve deep crystal damage')
release(miner)
local magnet=Pro.clone(opened)
assert(Ca.select(magnet,first.id,3,'magnet',magnet.run.id,{atDepot=true}))
moveBuyer(f.center)
local dropPosition=characterRoot(buyer).Position+Vector3.new(36,-3,0)
local dropPart=World.part(pickupFolder,'MagnetTest',dropPosition,Vector3.one,Color3.new(1,1,1))
pickups[-1]={part=dropPart,owner=shopper.UserId,runId=magnet.run.id,material='Quartz',units=1,spawnAt=now,age=1,
 x=dropPosition.X,y=dropPosition.Y,z=dropPosition.Z,vx=0,vy=0,vz=0,floor=dropPosition.Y,landed=true}
pickupStep(C.Tick);assert(not pickups[-1].homing,'base pickup reached ore 36 studs away')
buyer.session.data=magnet;publish(buyer)
for _=1,180 do
 realTime+=C.Tick;now=realTime;pickupStep(C.Tick)
 if not pickups[-1] then break end
end
assert(not pickups[-1] and Pro.cargoUnits(data(buyer))==1,'Ore Magnet failed to bring distant ore into the backpack')
print('PASS Workshop sale, first paid crate, saved offer, Star reward, real Twin Beam, depth-specific laser damage and extended ore collection')
