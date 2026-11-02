-- Appended to the actual server bundle. Native rendering/LOS are not simulated.
local roleChecks=0
local roleEvents={}
RoleEffects.Grow=function(from,target) table.insert(roleEvents,{kind='grow',from=from,target=target}) end
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
check('grower plants a real replacement with normal health yield growth and bounded population',function()
 local _,p,roles=fixture();local field=patches[1];local d=roles.Dart[1]
 field.respawnQueue={field.respawnClock+100};p.workField=1
 ticks(d,C.Tick);assert(d.growPlan and not d.mining)
 local spot=d.growPlan.spot;d.pos=Vector3.new(spot.X,field.part.Position.Y+field.part.Size.Y*.5+3.2,spot.Z)
 local before=#field.resources;ticks(d,1.2,true)
 assert(#field.resources==before+1 and #field.respawnQueue==0)
 local r=field.resources[#field.resources]
 assert(r.part:GetAttribute('GrownBy')==d.id and r.readyAt>now and r.ore==field.cfg.Ore)
 assert(r.hp==r.maxHP-10 and not d.target and not d.mining and not next(r.slots))
 local count=#field.resources;ticks(d,8);assert(#field.resources==count,'cannot generate rewards without a replacement token')
end)
check('recall cancels planting and two growers cannot overlap or exceed replacement tokens',function()
 local _,p,roles=fixture();local field=patches[1];local d=roles.Dart[1]
 field.respawnQueue={field.respawnClock+100};p.workField=1;ticks(d,C.Tick)
 local plan=assert(d.growPlan);leaveField(p);assert(not d.growPlan)
 local before=#field.resources;ticks(d,2);assert(#field.resources==before)
 p.workField=1;d.nextGrow=0;d.growPlan=plan
 d.pos=Vector3.new(plan.spot.X,field.part.Position.Y+field.part.Size.Y*.5+3.2,plan.spot.Z)
 d.velocity=Vector3.zero
 ticks(d,C.Tick);p.busy=true;local elapsed=now-d.growAt;ticks(d,2);assert(math.abs(now-d.growAt-elapsed)<1e-5)
 p.busy=false;ticks(d,1.2);assert(#field.resources==before+1)
 assert(not spawnResource(field,'Crystal',false,plan),'a second grower must not overlap the first rock')
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
check('recall and busy storage cancel or pause breaker and grower work',function()
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
 ticks(d,.5,true);assert(not r.paid and p.ability.burn and data(p).run.abilityCooldowns.Orbital>now)
 for _=1,250 do clock(C.Tick);DroneAbilities.step(p.ability,now,C.Tick,abilityContext(p,1,d)) end
 assert(r.paid and not p.ability.burn)
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
check('finished mining releases its reservation and lingers before choosing new work',function()
 local _,p,roles=fixture();local r=rock(20);local nextRock=rock(400,'Crystal',Vector3.new(12,0,0));local d=roles.Striker[1]
 assert(assignOre(p,d,r));d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize);d.goal=d.pos
 assert(hitResource(d,r,1000));assert(r.paid and not d.target and not next(r.slots))
 local untilTime=d.lingerUntil;assert(untilTime and math.abs(untilTime-now-1)<1e-8)
 p.oreQueue={nextRock.id}
 local worker=roles.Charger[1];worker.hp=0
 dispatchOreQueue(p);assert(not d.target and #p.oreQueue==1,'queued work skipped the recovery')
 p.oreQueue={}
 d.autoField=1;d.stats.plotAuto=1
 ticks(d,.8,true);assert(d.state=='Recover' and not d.target and not d.mining,'reacquired during recovery')
 now=untilTime+.01;realTime=now;droneStep(d,C.Tick)
 assert(d.target==nextRock,'earned auto mining did not resume after recovery')
end)
check('storage pauses preserve the remaining post-mining recovery time',function()
 local _,p,roles=fixture();local r=rock(20);local d=roles.Striker[1]
 assert(assignOre(p,d,r));d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize);d.goal=d.pos
 assert(hitResource(d,r,1000));local remaining=d.lingerUntil-now;p.busy=true;ticks(d,2)
 assert(math.abs(d.lingerUntil-now-remaining)<1e-7);p.busy=false
 ticks(d,.5);assert(d.state=='Recover')
end)
check('a new explicit order cancels the completed-rock linger',function()
 local _,p,roles=fixture();local r=rock(20);local other=rock(400,'Crystal',Vector3.new(12,0,0));local d=roles.Striker[1]
 assert(assignOre(p,d,r));d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize);d.goal=d.pos
 assert(hitResource(d,r,1000));assert(d.lingerUntil)
 assert(assignOre(p,d,other));assert(not d.lingerUntil and d.target==other)
end)
check('hardware shop upgrades change only their intended real role stats',function()
 local _,p,roles=fixture();local profile=data(p)
 profile.run.shopLevels.ruby_courier_hold=1;profile.run.shopLevels.quartz_miner_focus=1
 profile.run.shopLevels.ruby_breaker_head=1;profile.run.shopLevels.violet_repair_kit=1
 profile.run.shopLevels.cobalt_scout_memory=1;profile.run.shopLevels.emerald_swarm_bay=1
 refreshStats(p)
 assert(roles.Courier[1].stats.courierCapacity==32 and roles.Courier[2].stats.courierCapacity==32)
 assert(roles.Striker[1].stats.courierCapacity==0 and roles.Medic[1].stats.healAmount==20)
 assert(roles.Dart[1].stats.growCooldown==2.5 and roles.Striker[1].stats.growCooldown==5)
 assert(roles.Charger[1].stats.geodeMultiplier==1.8 and roles.Striker[1].stats.geodeMultiplier==1)
 local r=rock(1000);p.workField=1;local ctx=abilityContext(p,1,roles.Scrapper[1]);assert(ctx.perks.scrapBots==2)
 p.ability=DroneAbilities.new({},profile.run.id);assert(DroneAbilities.begin(p.ability,'Scrap',now,ctx))
 clock(.4);assert(DroneAbilities.confirm(p.ability,p.ability.charge.token,now,ctx));assert(#p.ability.swarm.bots==6)
end)
check('rock clicks confirm work queue and cancellation without replacing a busy job',function()
 local pl,p,roles=fixture();local gui=Instance.new('PlayerGui');gui.Parent=pl
 roles.Charger[1].hp=0
 local first=rock(1000);local second=rock(1000,'Crystal',Vector3.new(12,0,0));local miner=roles.Striker[1]
 local serial=0
 local function click(r,toggle,run)
  serial+=1;p.tokens=7;p.bucketAt=now
  commandPlayer(pl,'MineOre',{requestId='polish.'..serial,runId=run or data(p).run.id,resourceId=r.id,toggle=toggle})
  return http:JSONDecode(gui:GetAttribute('MA_CommandState'))
 end
 assert(click(first,true).status=='accepted' and miner.target==first)
 assert(click(second,true).status=='queued' and #p.oreQueue==1 and miner.target==first)
 publish(p);assert(http:JSONDecode(pl:GetAttribute('QueuedOreIds'))[1]==second.id)
 assert(click(second,true).status=='canceled' and #p.oreQueue==0 and miner.target==first)
 assert(click(first,true).status=='accepted' and miner.target==first,'repeat command must preserve work')
 assert(click(second,true,'old-run').status=='rejected' and #p.oreQueue==0)
 second.readyAt=now+2;assert(click(second,true).status=='rejected' and #p.oreQueue==0)
end)
print(roleChecks..' actual production server role checks passed using API doubles; engine motion/multiplayer not verified')
