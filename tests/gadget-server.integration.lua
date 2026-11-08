-- Appended to the actual production server bundle using the shared API double.
-- Tests real command validation, hitResource, backpack awards and persistence
-- plumbing; effect rendering, networking and Roblox engine LOS are not tested.
local checks=0
local effects={}
RoleEffects.Ability=function(owner,event) table.insert(effects,{owner=owner,kind=event.kind}) end
RoleEffects.ClearAbility=function() end
-- Discovery pickup UI is an independent engine-only system, outside this test.
discoveries.TrySpawn=function() end
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS gadget server '..name) end
local function advance(seconds)
 for _=1,math.floor(seconds*60+.5) do realTime+=1/60;heartbeat:Fire(1/60) end
end
local uid=70000
local function fixture()
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=assert(profiles[pl.UserId])
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 return pl,p
end
local function input(pl,kind,op,token,extra)
 local p=profiles[pl.UserId];p.tokens=7;p.bucketAt=now
 local payload={op=op,kind=kind,fieldId=1,token=token,runId=data(p).run.id}
 for k,v in pairs(extra or {}) do payload[k]=v end
 command.OnServerEvent:Fire(pl,'MiningAbility',payload)
end
local function largeNode()
 local r=makeResource(patches[1],patches[1].center,'Crystal',5000,10,3)
 advance(2.1);return r
end
check('locked gadgets and stale runs cannot create an authoritative charge',function()
 local pl,p=fixture();input(pl,'Orbital','begin');assert(p.ability and not p.ability.charge)
 data(p).run.shopLevels.cobalt_orbital=1
 input(pl,'Orbital','begin',nil,{runId='old-run'});assert(not p.ability.charge)
end)
check('actual command strike breaks largest node through normal reward path once',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1;local r=largeNode()
 -- Isolate this reward assertion from the separately tested neighboring-rock
 -- cascade, which can legitimately extract additional ore from nearby nodes.
 for _,other in ipairs(r.field.resources) do if other~=r then other.paid=true;other.hp=0 end end
 input(pl,'Orbital','begin');local charge=assert(p.ability.charge);assert(charge.targetId==r.id)
 local cargo=Pro.cargoUnits(data(p));advance(charge.readyAt-now+.05)
 assert(not r.paid and p.ability.burn,'one activation automatically starts sustained work')
 advance(2);assert(r.hp>0 and r.hp<r.maxHP*.6,'burn should still be melting halfway through')
 advance(2.1);assert(r.paid,'four seconds of accepted contacts should melt the target')
 advance(1.5);assert(Pro.cargoUnits(data(p))==cargo+r.ore,'nearby fragments must reach the owner')
 local after=Pro.cargoUnits(data(p));input(pl,'Orbital','confirm',charge.token);assert(Pro.cargoUnits(data(p))==after)
end)
check('foreign worker reservations are excluded from selection and reject direct gadget hits',function()
 local a,p=fixture();local b,q=fixture();data(p).run.shopLevels.cobalt_orbital=1;local r=largeNode()
 local worker=q.drones[1];worker.target=r;r.slots[worker.id]=1
 local context=abilityContext(p,1)
 for _,target in ipairs(context.targets(1)) do assert(target.id~=r.id) end
 local hp=r.hp;assert(not context.hit(r.id,100,'Orbital',{x=r.position.X,y=r.position.Y+34,z=r.position.Z}));assert(r.hp==hp)
 r.slots[worker.id]=nil;worker.target=nil
end)
check('leaving plot rejects contact while a full backpack permits mining',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1;local r=largeNode();local context=abilityContext(p,1)
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(RoleConfig.Mining.BackpackRange+20,0,0)));local hp=r.hp
 assert(not context.hit(r.id,100,'Orbital',{x=r.position.X,y=r.position.Y+34,z=r.position.Z}));assert(r.hp==hp)
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 assert(context.hit(r.id,100,'Orbital',{x=r.position.X,y=r.position.Y+34,z=r.position.Z}));assert(r.hp<hp)
end)
check('no living mining worker prevents gadget deployment',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1
 for _,d in ipairs(p.drones) do d.hp=0 end
 input(pl,'Orbital','begin');assert(not p.ability.charge)
end)
check('abilities follow the current retained shell after an authoritative physical hit',function()
 local _,p=fixture();local d=p.drones[1]
 local r=makeResource(patches[1],patches[1].center,'Crystal',1000,10,4);r.readyAt=now
 release(d);d.role='Charger';d.field=1;d.target=r;d.targetSlot=1;r.slots[d.id]=1
 d.pos=Feel.mineGoal(r.position,1,false,r.fullSize)
 assert(hitResource(d,r,800,false,nil,d.pos,'Breaker'))
 assert(r.stage==3 and r.damageBaseStage==0 and r.part:GetAttribute('SmashDents')==1)
 assert(math.abs(r.part.Size.X-3.28)<1e-7,'scarred shell uses retained scale')
 local context=abilityContext(p,1,d);local live=assert(context.target(r.id,1))
 local expectedY=r.part.Position.Y+r.part.Size.Y*.5
 assert(math.abs(live.radius-1.64)<1e-7 and math.abs(live.y-expectedY)<1e-7,'live target still used obsolete quarter size or tilt')
 for _,kind in ipairs({'Orbital','Scrap'}) do
  local surveyed
  for _,target in ipairs(context.targets(1,kind)) do if target.id==r.id then surveyed=target end end
  assert(surveyed and surveyed.radius==live.radius and surveyed.y==live.y,'survey and live contact disagree on physical shell')
 end
end)
check('scrap mining uses real hit path and persistence-busy periods preserve deployment',function()
 local pl,p=fixture();data(p).run.shopLevels.violet_scrap=1
 for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 local r=makeResource(patches[1],patches[1].center,'Crystal',800,10,3)
 advance(2.1);input(pl,'Scrap','begin');local charge=assert(p.ability.charge)
 advance(1.45);assert(p.ability.swarm)
 local initial=r.hp
 for _=1,40 do if r.hp<initial then break end;advance(.1) end
 assert(r.hp<initial,'physical bots must reach and mine before half their ten-second deployment')
 local swarm=p.ability.swarm;local before=r.hp;p.busy=true;advance(.3)
 assert(p.ability.swarm==swarm and r.hp==before,'saving must pause work without discarding the swarm')
 p.busy=false;advance(.4);assert(p.ability.swarm==swarm and r.hp<before)
end)
check('successful gadget cooldown is saved and rehydrated runtime rejects immediate reuse',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1;largeNode()
 input(pl,'Orbital','begin');local charge=assert(p.ability.charge);advance(charge.readyAt-now+.05)
 local saved=data(p).run.abilityCooldowns.Orbital;assert(saved and saved>now)
 p.ability=nil;input(pl,'Orbital','begin');assert(not p.ability.charge and p.ability.cooldowns.Orbital==saved)
end)
check('orbital survey and charge choose the largest reachable rock while preserving obstruction and scrap rules',function()
 local pl,p=fixture();for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 local blocked=makeResource(patches[1],patches[1].center+Vector3.new(-6,0,0),'Crystal',5000,10,3);blocked.readyAt=now
 local reachable=makeResource(patches[1],patches[1].center+Vector3.new(6,0,0),'Crystal',3000,10,3);reachable.readyAt=now
 local owned=Pro.clone(data(p).fleet[1]);owned.type='Orbiter';owned.role='Orbiter';owned.flightHeight=3.6;owned.base=Pro.clone(RoleConfig.StudioRoles.Orbiter.base)
 p.testFleet={owned};rebuildFleet(p);local d=p.drones[1];p.workField=1
 local oldRaycast=workspace.Raycast;local obstruction=Instance.new('Part');obstruction.Name='PreservedTreeTrunk';obstruction.Parent=workspace
 local rays=0
 workspace.Raycast=function(_,from,delta,params)
  rays+=1
  assert(params.FilterDescendantsInstances[1]==droneFolder and params.FilterDescendantsInstances[2]==pl.Character)
  if math.abs(from.X-blocked.position.X)<1e-7 and math.abs(from.Z-blocked.position.Z)<1e-7 then
   local top=select(2,Feel.groundedRockFrame(blocked.position,blocked.part.Size,blocked.part:GetAttribute('GroundY'),blocked.stage,blocked.stageSeed))
   assert(math.abs(from.Y-top-DroneAbilities.ORBITAL_ORIGIN_HEIGHT)<1e-7,'survey and hit origins differ')
   assert((from+delta-blocked.position).Magnitude<1e-7,'survey and hit endpoints differ')
   return {Instance=obstruction,Position=from+delta*.4}
  end
  return nil
 end
 local context=abilityContext(p,1,d);local orbital=context.targets(1,'Orbital');assert(#orbital==1 and orbital[1].id==reachable.id)
 assert(#context.targets(1,'Scrap')==2,'a roof must not remove targets from ground-working scrap bots')
 data(p).run.shopLevels.violet_scrap=1
 local scrap=DroneAbilities.new({},data(p).run.id);assert(DroneAbilities.begin(scrap,'Scrap',now,context));assert(scrap.charge.targetId==blocked.id)
 local goal=reachable.position+Vector3.new(0,math.max(12,reachable.fullSize.Y*.5+7),0);d.pos=goal;d.velocity=Vector3.zero
 roleAbilityStep(d,p,characterRoot(p),C.Tick)
 assert(p.ability.charge and p.ability.charge.targetId==reachable.id and (d.intentGoal-goal).Magnitude<1e-7,'survey still committed to the blocked largest rock')
 local blockedHP,reachableHP=blocked.hp,reachable.hp
 now=p.ability.charge.readyAt;realTime=now;DroneAbilities.step(p.ability,now,C.Tick,context)
 assert(p.ability.burn and p.ability.burn.accepted and reachable.hp<reachableHP and blocked.hp==blockedHP)
 local top=select(2,Feel.groundedRockFrame(blocked.position,blocked.part.Size,blocked.part:GetAttribute('GroundY'),blocked.stage,blocked.stageSeed))
 assert(not context.hit(blocked.id,100,'Orbital',{x=blocked.position.X,y=top+DroneAbilities.ORBITAL_ORIGIN_HEIGHT,z=blocked.position.Z}))
 assert(blocked.hp==blockedHP and rays>=4,'selection must not weaken authoritative geometry checks')
 workspace.Raycast=oldRaycast;obstruction:Destroy()
end)
check('fully obstructed orbital fields stay in survey without charge damage or cooldown loops',function()
 local pl,p=fixture();for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 local r=makeResource(patches[1],patches[1].center,'Crystal',5000,10,3);r.readyAt=now
 local owned=Pro.clone(data(p).fleet[1]);owned.type='Orbiter';owned.role='Orbiter';owned.flightHeight=3.6;owned.base=Pro.clone(RoleConfig.StudioRoles.Orbiter.base)
 p.testFleet={owned};rebuildFleet(p);local d=p.drones[1];p.workField=1;local hr=characterRoot(p)
 d.pos=hr.Position+Vector3.new(4,10,0);d.velocity=Vector3.zero
 local oldRaycast=workspace.Raycast;local obstruction=Instance.new('Part');obstruction.Name='PreservedCanopy';obstruction.Parent=workspace
 workspace.Raycast=function(_,from,delta) return {Instance=obstruction,Position=from+delta*.5} end
 local hp=r.hp;local eventCount=#effects
 for _=1,30 do now+=C.Tick;realTime=now;roleAbilityStep(d,p,hr,C.Tick) end
 assert(p.ability and not p.ability.charge and not p.ability.burn and not p.ability.cooldowns.Orbital)
 assert(r.hp==hp and d.state=='OrbitalSurvey' and #effects==eventCount,'obstructed field repeated charge/refund effects')
 assert(#abilityContext(p,1,d).targets(1,'Scrap')==1)
 workspace.Raycast=oldRaycast;obstruction:Destroy()
end)
check('new obstruction between charge and first contact cancels unspent orbital work safely',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1
 for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 local r=makeResource(patches[1],patches[1].center,'Crystal',5000,10,3);r.readyAt=now
 local context=abilityContext(p,1);local state=DroneAbilities.new({},data(p).run.id)
 assert(DroneAbilities.begin(state,'Orbital',now,context));now=state.charge.readyAt;realTime=now
 assert(DroneAbilities.confirm(state,state.charge.token,now,context));assert(state.burn and not state.burn.accepted)
 local oldRaycast=workspace.Raycast;local obstruction=Instance.new('Part');obstruction.Parent=workspace
 workspace.Raycast=function(_,from,delta) return {Instance=obstruction,Position=from+delta*.5} end
 local hp=r.hp;DroneAbilities.step(state,now,C.Tick,context)
 assert(not state.burn and state.cooldowns.Orbital==now and r.hp==hp)
 workspace.Raycast=oldRaycast;obstruction:Destroy()
end)
print(checks..' actual server gadget integration checks passed with API doubles; not Studio visual/multiplayer evidence')
