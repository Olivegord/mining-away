-- Appended to the actual server bundle. Native rendering/LOS are not simulated.
local roleChecks=0
local roleEvents={}
RoleEffects.Scan=function(from,target) table.insert(roleEvents,{kind='scan',from=from,target=target}) end
RoleEffects.BreakerPhase=function(position,target,phase) table.insert(roleEvents,{kind=phase,position=position,target=target}) end
RoleEffects.Ability=function(_,event) table.insert(roleEvents,{kind=event.kind}) end
RoleEffects.ClearAbility=function() end
discoveries.TrySpawn=function() end
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));roleChecks+=1;print('PASS role server '..name) end
local roleUid=93000
local function clock(dt) realTime+=dt;now=realTime end
local function fixture()
 roleUid+=1;local pl=player(roleUid);players.PlayerAdded:Fire(pl);local p=assert(profiles[roleUid])
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 local roles={};for _,d in ipairs(p.drones) do roles[d.role]=roles[d.role] or {};table.insert(roles[d.role],d) end
 return pl,p,roles
end
local function rock(hp,kind,offset)
 local r=makeResource(patches[1],patches[1].center+(offset or Vector3.zero),kind or 'Crystal',hp,10,3);r.readyAt=now;return r
end
local function ticks(d,seconds,snapshot)
 for _=1,math.ceil(seconds/C.Tick) do clock(C.Tick);droneStep(d,C.Tick);if snapshot then snapshotDrone(d) end end
end
check('Studio starts exactly eight active roles but still owns one permanent drone',function()
 local pl,p,roles=fixture();assert(preview and #p.drones==8 and #data(p).fleet==1)
 assert(#roles.Striker==1 and #roles.Courier==2 and #roles.Medic==1 and #roles.Dart==1 and #roles.Charger==1 and #roles.Orbiter==1 and #roles.Scrapper==1)
 assert(Pro.validate(data(p),pl.UserId));publish(p)
 local view=http:JSONDecode(pl:GetAttribute('MA_Profile'));assert(#view.activeFleet==8 and #view.fleet==1)
 for _,role in ipairs({'Dart','Medic','Courier','Orbiter','Scrapper'}) do assert(view.droneStats[roles[role][1].id].miningDPS==0) end
 assert(#Pro.new(42,123).fleet==1,'production ownership creation is unchanged')
end)
check('ore queue and direct assignments cannot give specialists ordinary mining jobs',function()
 local _,p,roles=fixture();local r=rock(800)
 for _,role in ipairs({'Dart','Medic','Courier','Orbiter','Scrapper'}) do
  local d=roles[role][1];assert(not assignOre(p,d,r));assert(not d.target)
 end
 p.oreQueue={r.id};dispatchOreQueue(p)
 for _,d in ipairs(p.drones) do if d.target then assert(DroneRoles.isWorker(d.role)) end end
end)
check('scout physically scans the exposed rock top without damage or a reservation',function()
 local _,p,roles=fixture();local r=rock(800);local d=roles.Dart[1];local hp=r.hp
 p.workField=1;d.pos=r.position+Vector3.new(1.8,5,0);ticks(d,1.1,true)
 assert(r.scoutedUntil>now and r.hp==hp and not next(r.slots) and not d.mining)
 local event=roleEvents[#roleEvents];assert(event.kind=='scan' and event.target.Y>r.position.Y)
 assert(DroneRoles.startupFactor(r.scoutedUntil,now)==.35)
end)
check('only the miner performs a continuous cutting beam after real warmup',function()
 local _,p,roles=fixture();local r=rock(1000);local d=roles.Striker[1];local hp=r.hp
 assert(assignOre(p,d,r));d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize)
 ticks(d,.3);assert(r.hp==hp and not d.mining)
 ticks(d,.8,true);assert(r.hp<hp and d.mining and d.model:GetAttribute('Mining')==true)
end)
check('breaker arrives winds up dives hits once and recovers even after a killing strike',function()
 local _,p,roles=fixture();local r=rock(20);local d=roles.Charger[1];local hp=r.hp
 assert(assignOre(p,d,r));d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize)+Vector3.new(0,2,0)
 ticks(d,.7,true);assert(r.hp==hp and not d.mining)
 local reached=false
 for _=1,150 do ticks(d,C.Tick,true);assert(not d.mining and d.model:GetAttribute('Mining')==false)
  if r.paid then reached=true;break end
 end
 assert(reached and (d.impactSerial or 0)==1 and d.breaker and d.breaker.phase=='Impact')
 snapshotDrone(d);assert(d.breaker,'retired target snapshots must preserve recovery')
 ticks(d,.3,true);assert(d.breaker and d.breaker.phase=='Recover')
 ticks(d,.6,true);assert(not d.breaker and d.impactSerial==1)
end)
check('recall and busy storage cancel or pause breaker and scout work',function()
 local _,p,roles=fixture();local r=rock(500);local d=roles.Charger[1];local hp=r.hp
 assert(assignOre(p,d,r));d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize)+Vector3.new(0,2,0)
 ticks(d,.2);local elapsed=now-d.breaker.phaseAt;p.busy=true;ticks(d,1)
 assert(math.abs((now-d.breaker.phaseAt)-elapsed)<1e-5 and r.hp==hp)
 p.busy=false;leaveField(p);assert(not d.target and not d.breaker and not p.workField)
 ticks(d,2);assert(r.hp==hp)
end)
check('two backpack emptiers own separate real parcels and sell each only once',function()
 local _,p,roles=fixture();data(p).run.cargo={Quartz=24}
 local hr=characterRoot(p)
 for i,d in ipairs(roles.Courier) do d.pos=hr.Position+Vector3.new(i==1 and -2.2 or 2.2,2.4,1);ticks(d,.7);serviceDeliveries(p);clock(1.1) end
 local a,b=roles.Courier[1],roles.Courier[2]
 assert(Pro.deliveryUnits(data(p),a.id)==8 and Pro.deliveryUnits(data(p),b.id)==8 and Pro.cargoUnits(data(p))==8)
 assert(data(p).run.deliveries[a.id].id~=data(p).run.deliveries[b.id].id)
 for _,d in ipairs(roles.Courier) do
  local manifest=data(p).run.deliveries[d.id];d.pos=(scene.converter or scene.packStation).Position+Vector3.new(0,3,0)
  d.deliveryId=manifest.id;d.deliveryArrived=true;clock(1.1);serviceDeliveries(p)
 end
 assert(data(p).run.wallet.Quartz==16 and Pro.cargoUnits(data(p))==8)
 clock(1.1);serviceDeliveries(p);assert(data(p).run.wallet.Quartz==16)
end)
check('orbital hardware automatically strikes a largest rock and persists its cooldown',function()
 local _,p,roles=fixture();local r=rock(5000);local d=roles.Orbiter[1]
 p.workField=1;d.pos=r.position+Vector3.new(0,12,0);ticks(d,.1,true)
 assert(p.ability and p.ability.charge and p.ability.charge.actorId==d.id and not d.target and not d.mining)
 local hp=r.hp;ticks(d,1.1);assert(r.hp==hp)
 ticks(d,.5,true);assert(r.paid and data(p).run.abilityCooldowns.Orbital>now)
 local untilTime=data(p).run.abilityCooldowns.Orbital;ticks(d,1,true);assert(p.ability.cooldowns.Orbital==untilTime and not d.mining)
end)
check('swarm hardware deploys four physical mini miners for exactly ten seconds',function()
 local _,p,roles=fixture();local r=rock(900);local d=roles.Scrapper[1];local hr=characterRoot(p)
 p.workField=1;d.pos=hr.Position+Vector3.new(4,4,-3);ticks(d,1.6,true)
 local swarm=assert(p.ability.swarm,'no deployed swarm: '..tostring(p.ability.charge and p.ability.charge.started)..' now '..now)
 assert(#swarm.bots==4,'bot count '..#swarm.bots);assert(swarm.actorId==d.id,'wrong actor');assert(math.abs(swarm.expires-swarm.started-10)<1e-7,'wrong lifetime')
 assert(not d.mining and not d.target and data(p).run.abilityCooldowns.Scrap>now)
 local hp=r.hp
 for _=1,120 do clock(C.Tick);DroneAbilities.step(p.ability,now,C.Tick,abilityContext(p,1,d)) end
 assert(r.hp<hp,'only the mini bots should mine')
 now=swarm.expires;realTime=now;DroneAbilities.step(p.ability,now,C.Tick,abilityContext(p,1,d));assert(not p.ability.swarm)
end)
check('healer preserves real ally repair and never acquires mining',function()
 local _,p,roles=fixture();local healer=roles.Medic[1];local miner=roles.Striker[1]
 miner.hp-=20;healer.pos=miner.pos+Vector3.new(2,1,2);local hp=miner.hp
 ticks(healer,.7,true);assert(miner.hp==hp+10 and not healer.mining and not healer.target)
end)
print(roleChecks..' actual production server role checks passed using API doubles; engine motion/multiplayer not verified')
