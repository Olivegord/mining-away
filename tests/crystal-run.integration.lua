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
local f={id=#patches+1,cfg={Key='Quartz',SelectionOnly=true,AlwaysUnlocked=true,ReferenceCrystals=true,Hardness=1,Turrets=0,Respawn=8},
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
local a,b,edge=rock(-10,175),rock(13,100),rock(21,100)
local function pin(x)
 command.OnServerEvent:Fire(pl,'PlaceSelector',{runId=data(p).run.id,fieldId=f.id,position=Vector3.new(x,5.5,-68)})
end
local function step(n)
 for _=1,n do realTime+=C.Tick;now=realTime;droneStep(d,C.Tick) end
end
pin(200);assert(not p.miningSquare,'out-of-range pin accepted')
pin(-34.5);assert(not p.miningSquare,'off-field point snapped back into the field')
pin(-9.4);assert(p.miningSquare and p.miningSquare.center.X==-10)
local pinned=p.miningSquare
pin(-10.6);assert(p.miningSquare==pinned,'same grid cell restarted the order')
step(1);assert(d.target==a)
d.pos=Feel.mineGoal(a.position,1,false,a.fullSize,a.referenceCrystal)
step(32);assert(d.mining,'worker never began its real cut')
local other=player(98701);players.PlayerAdded:Fire(other)
local rival=profiles[other.UserId]
other.Character:PivotTo(CFrame.new(Vector3.new(0,8,-68)))
command.OnServerEvent:Fire(other,'PlaceSelector',{runId=data(rival).run.id,fieldId=f.id,position=Vector3.new(-10,5.5,-68)})
droneStep(rival.drones[1],C.Tick)
assert(rival.miningSquare and not rival.drones[1].target,'overlapping selector stole another crew’s reservation')
players.PlayerRemoving:Fire(other)
pin(13.3);assert(p.miningSquare.center.X==14)
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
for _=1,1200 do step(1);if not d.recharging then break end end
assert(not d.recharging and d.battery==d.stats.batteryCapacity,'failed to recharge at the pad')
step(15);assert(d.target and d.squareJob==p.miningSquare,'charged worker failed to resume')
release(d);d.field=nil
local profile=data(p)
local full=Ca.capacity(profile)
Pro.addCargo(profile,'Quartz',full,full)
step(30);assert(not d.target and d.state=='HoldSelector','full backpack should leave the crew stationed at the square')
assert((d.goal-p.miningSquare.center).Magnitude<13,'idle crew left the square')
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
assert(Pro.cargoUnits(data(p))==0 and data(p).run.quartzEarnings==earnings+full,'Auto Sell did not sell the full bag exactly once')
pl.Character:PivotTo(CFrame.new(Vector3.new(0,8,20)))
command.OnServerEvent:Fire(pl,'Recall');step(1)
assert(not p.miningSquare and not d.target and d.state=='Follow' and d.goal.Z>0,'explicit recall failed to bring back the fleet')
print('PASS Crystal Run grid pin, station keeping, recall, edge overlap, reservations, committed work, regrowth, charging, full-bag pause and Star Shop effects')

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
scene.runWalls={{x=-32.5,halfX=23.5,z=190,halfZ=2.625,cruise=13.84},
 {x=32.5,halfX=23.5,z=190,halfZ=2.625,cruise=13.84}}
d.state='ToCharge'
d.pos=Vector3.new(0,8,215)
local charge=Vector3.new(0,8,170)
move(d,charge,C.Tick)
assert(d.intentGoal==charge,'worker climbed despite clear divider opening')
d.pos=Vector3.new(31,8,215)
move(d,Vector3.new(31,8,170),C.Tick)
assert(d.intentGoal.Z==215 and d.intentGoal.Y>13,'worker did not climb above solid divider')
print('PASS full reference-sized patch populations, refill locality, mining and standby heights, and two-way divider clearance')
