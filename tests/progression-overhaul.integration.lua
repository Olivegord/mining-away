local originalCFIndex=CF.__index
CF.__index=function(frame,key)
 if key=='RightVector' then return Vector3.new(math.cos(frame.yaw),0,-math.sin(frame.yaw)) end
 return originalCFIndex(frame,key)
end
-- The actual server controller, with an explicit API-double fixture, not Studio.
assert(scene.runStart and root:GetAttribute('StarterLookAt')==scene.runStart)
local pl=player(731204);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local expected={'Striker','Striker','Striker','Needler','Ballcaster','Vacuum','Compactor','Courier','Courier'}
assert(#p.drones==#expected)
for i,d in ipairs(p.drones) do assert(d.role==expected[i]) end
local function advance(seconds)
 for _=1,math.ceil(seconds/C.Tick) do realTime+=C.Tick;heartbeat:Fire(C.Tick) end
end
local function input(action,payload)
 p.tokens=7;p.bucketAt=now;command.OnServerEvent:Fire(pl,action,payload)
end
local function quote(id,extra)
 local payload={txId=id,runId=data(p).run.id};for k,v in pairs(extra or {}) do payload[k]=v end;return payload
end
local group=Instance.new('Folder');group.Name='OverhaulFixture';group.Parent=scene.map
local at=scene.packStation.Position+Vector3.new(0,0,80)
local bed=World.part(group,'TestBed',at,Vector3.new(108,1,64),Color3.new(1,0,0))
local field={id=#patches+1,cfg={Key='Quartz',Material='Quartz',Name='Quartz',Value=1,SelectionOnly=true,
 ReferenceCrystals=true,AlwaysUnlocked=true,Count=1,Ore=1,Hardness=1,Turrets=0,Respawn=65},
 part=bed,center=at,model=group,color=bed.Color,resources={},turrets={},respawnQueue={},e=R.newEncounter(C),clusters={bed}}
field.e.phase='Safe';patches[field.id]=field
pl.Character:PivotTo(CFrame.new(at+Vector3.yAxis*3))
local r=makeResource(field,at,'Crystal',80,1,3,3);r.readyAt=now
input('PlaceSelector',{runId=data(p).run.id,fieldId=field.id,position=at})
assert(p.miningSquare)
local miner=p.drones[1]
scene.squareStep(p,miner);assert(miner.target==r)
miner.pos=committedStation(miner,r)
assert(hitResource(miner,r,9999) and r.paid)
local drop
for _,item in pairs(pickups) do if item.owner==pl.UserId then assert(not drop);drop=item end end
assert(drop and drop.raw and drop.units==1 and drop.value==1)
scene.clearSquare(p)
for _,worker in ipairs(p.drones) do release(worker);worker.field=nil end
-- Let the actual drop land without approaching it, then stand eight studs away.
pl.Character:PivotTo(CFrame.new(at+Vector3.new(22,3,0)))
advance(1.3);assert(drop.landed)
pl.Character:PivotTo(CFrame.new(drop.x+8,drop.floor+2,drop.z))
local started=now
while Pro.cargoUnits(data(p))==0 and now-started<2 do
 realTime+=C.Tick;now=realTime;pickupStep(C.Tick)
end
assert(Pro.cargoUnits(data(p))==1,'nearby earned ore did not reach the player')
assert(data(p).run.wallet.Quartz==0,'pickup bypassed selling')
print('PASS overhaul server a real crystal drop lands, homes from eight studs, and still requires a sale')

-- A partially filled backpack must not erase the rest of the pin during a shop visit.
pl.Character:PivotTo(CFrame.new(at+Vector3.yAxis*3))
input('PlaceSelector',{runId=data(p).run.id,fieldId=field.id,position=at})
local cargo=Workshop.cargoKey('Quartz',1)
local spare={owner=pl.UserId,runId=data(p).run.id,units=1,material=cargo,value=1,tierMaterial='Quartz',raw=true,
 floor=at.Y+1,fieldPart=bed}
scene.spawnOrePickup(r.part,spare,at+Vector3.new(15,1,0),Vector3.zero,Color3.new(1,0,0))
spare.landed=true;spare.firstLandedAge=0;spare.age=2;spare.vx=0;spare.vy=0;spare.vz=0
pl.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.yAxis*3))
local original=spare.spawnAt+OreDrops.LIFETIME
realTime+=C.Tick;now=realTime;pickupStep(C.Tick)
assert(Pro.cargoUnits(data(p))<Ca.capacity(data(p)))
assert(spare.returnUntil and spare.returnUntil>original and spare.returnUntil<=spare.spawnAt+OreDrops.CARGO_MAX_AGE)
print('PASS overhaul server a partial-bag depot visit protects earned loose ore under the existing bounded lifetime')

-- Use the real durable sale and pack commands, then the actual prestige remote.
scene.clearSquare(p)
data(p).run.cargo={[Workshop.cargoKey('Quartz',160)]=1}
input('Sell')
assert(data(p).run.quartzEarnings==160 and data(p).run.wallet.Quartz==160)
input('BuyPack',quote('overhaul-pack',{packIndex=0}))
local offer=assert(data(p).run.pendingOffer)
assert(offer.price==20 and data(p).run.wallet.Quartz==140 and not Pro.prestigePreview(data(p)).eligible)
assert(Ca.open(data(p),offer.id)) -- The delivery/hold path is covered by workshop.integration.lua.
input('ChooseCard',quote('overhaul-pick',{offerId=offer.id,index=2}))
assert(not data(p).run.pendingOffer and Pro.prestigePreview(data(p)).eligible)
local old=Pro.clone(data(p));local reward=Pro.prestigePreview(old).droneChoices[1]
pl.Character:PivotTo(CFrame.new(scene.prestigeStation.Position+Vector3.yAxis*3))
local request=quote('overhaul-prestige',{confirm=true,droneType=reward.kind})
input('Prestige',request)
local after=data(p)
assert(after.prestiges==1 and #after.fleet==#old.fleet+1 and #after.run.cards==0 and after.run.wallet.Quartz==0)
assert(after.fleet[1].id==old.fleet[1].id and p.drones[1].stats.miningDPS==45)
input('Prestige',request);assert(#data(p).fleet==#old.fleet+1)
assert(Pro.validate(data(p),pl.UserId))
players.PlayerRemoving:Fire(pl);players.PlayerAdded:Fire(pl);p=profiles[pl.UserId]
assert(data(p).prestiges==1 and #data(p).fleet==#old.fleet+1 and p.drones[1].stats.miningDPS==45)
players.PlayerRemoving:Fire(pl)
print('PASS overhaul server spending preserves the earned milestone, prestige grants once, and reconnect preserves the stronger crew')
