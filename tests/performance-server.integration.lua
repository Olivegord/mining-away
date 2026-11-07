-- Production bundle API-call accounting. This is not Studio, FPS or energy data.
local calls={pivots=0,attributes=0,rays=0}
local originalPivot,originalAttribute,originalRay=IM.PivotTo,IM.SetAttribute,workspace.Raycast
function IM:PivotTo(cf)
 if self.Parent and self.Parent.Name=='Drones' then calls.pivots+=1 end
 return originalPivot(self,cf)
end
function IM:SetAttribute(key,value)
 if self.Parent and self.Parent.Name=='Drones' then calls.attributes+=1 end
 return originalAttribute(self,key,value)
end
function workspace:Raycast(...) calls.rays+=1;return originalRay(self,...) end
local function reset() calls.pivots=0;calls.attributes=0;calls.rays=0 end
local function report(name) print('METRIC',name,calls.pivots,calls.attributes,calls.rays) end
local function ticks(n)
 for _=1,n do realTime+=C.Tick;heartbeat:Fire(C.Tick) end
end
discoveries.TrySpawn=function() end
RoleEffects.Ability=function() end
local pl=player(99511);players.PlayerAdded:Fire(pl);local p=assert(profiles[pl.UserId])
p.testFleet=roleTestFleet(p);rebuildFleet(p) -- Stress all types even though the starting crew is curated.
publish(p) -- The preview crew is installed after the initial backpack snapshot.
assert(#p.drones==15 and #data(p).fleet==1 and pl:GetAttribute('BackpackCapacity')==120)
reset();ticks(120);report('idle')
local field=patches[1];pl.Character:PivotTo(CFrame.new(field.center+Vector3.new(0,3,0)))
for _,r in ipairs(field.resources) do r.hp=1000000;r.maxHP=1000000;r.readyAt=now end
p.workField=1;p.ability=DroneAbilities.new({Orbital=now+100,Scrap=now+100},data(p).run.id)
reset();ticks(120);report('cooldown')
local orbital;for _,d in ipairs(p.drones) do if d.role=='Orbiter' then orbital=d end end
assert(orbital);p.ability=DroneAbilities.new({},data(p).run.id)
local ctx=abilityContext(p,1,orbital)
assert(DroneAbilities.begin(p.ability,'Orbital',now,ctx))
realTime+=DroneAbilities.CHARGE_SECONDS+.01;now=realTime
assert(DroneAbilities.confirm(p.ability,p.ability.charge.token,now,ctx))
local r=resources[p.ability.burn.targetId];local before=r.hp
reset()
for _=1,120 do realTime+=C.Tick;now=realTime;DroneAbilities.step(p.ability,now,C.Tick,abilityContext(p,1,orbital)) end
assert(r.hp<before and p.ability.burn,'burn must still damage the same real rock')
report('burn')
leaveField(p)
local specialists={}
for _,d in ipairs(p.drones)do if DroneRoles.isSpecial(d.role)then table.insert(specialists,d)end end
for i,d in ipairs(specialists)do
 local target=field.resources[i];target.hp=1000000;target.maxHP=1000000;target.paid=false;target.readyAt=now
 assert(assignOre(p,d,target));d.pos=Feel.mineGoal(target.position,d.targetSlot,false,target.fullSize);d.velocity=Vector3.zero
end
reset()
for _=1,120 do realTime+=C.Tick;now=realTime;for _,d in ipairs(specialists)do droneStep(d,C.Tick)end end
for _,d in ipairs(specialists)do assert(d.specialJob and d.state=='SpecialMine' and d.target.hp==1000000)end
report('specialists')
-- A cached clear path must never authorize an obstructed completion.
local blocked=specialists[1];local target=blocked.target;local hp=target.hp
blocked.specialJob.startedAt=now-blocked.specialJob.duration;blocked.specialClear=true;blocked.specialQueryAt=now+100
local ray=workspace.Raycast;local obstacle=Instance.new('Part')
function workspace:Raycast()return {Instance=obstacle}end
droneStep(blocked,C.Tick);assert(not blocked.target and not blocked.specialJob and target.hp==hp,'cached visibility allowed an obstructed final hit')
workspace.Raycast=ray
-- Cached snapshots must not leave a stale false Mining flag after a save pause.
local miner;for _,d in ipairs(p.drones) do if d.role=='Striker' then miner=d end end
release(miner);assert(assignOre(p,miner,r));miner.state='Mine';miner.mining=true
snapshotDrone(miner);assert(miner.model:GetAttribute('Mining')==true)
setMotionPaused(p,true);assert(miner.model:GetAttribute('Mining')==false)
setMotionPaused(p,false);snapshotDrone(miner);assert(miner.model:GetAttribute('Mining')==true)
print('PASS production burn damage, specialist monitoring/final-hit obstruction and snapshot pause/resume coherence; API doubles only')
