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
 input(pl,'Orbital','begin');local charge=assert(p.ability.charge);assert(charge.targetId==r.id)
 local cargo=Pro.cargoUnits(data(p));advance(.4);input(pl,'Orbital','confirm',charge.token)
 assert(r.paid and Pro.cargoUnits(data(p))==cargo,'break creates ore on the ground, never immediate cargo')
 local pending=pendingOre(p);assert(pending==r.ore)
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
check('leaving plot and full backpack reject the real authoritative contact',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1;local r=largeNode();local context=abilityContext(p,1)
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(RoleConfig.Mining.BackpackRange+20,0,0)));local hp=r.hp
 assert(not context.hit(r.id,100,'Orbital',{x=r.position.X,y=r.position.Y+34,z=r.position.Z}));assert(r.hp==hp)
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 assert(not context.hit(r.id,100,'Orbital',{x=r.position.X,y=r.position.Y+34,z=r.position.Z}));assert(r.hp==hp)
end)
check('no living mining worker prevents gadget deployment',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1
 for _,d in ipairs(p.drones) do d.hp=0 end
 input(pl,'Orbital','begin');assert(not p.ability.charge)
end)
check('scrap mining uses real hit path and persistence-busy periods preserve deployment',function()
 local pl,p=fixture();data(p).run.shopLevels.violet_scrap=1
 for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 local r=makeResource(patches[1],patches[1].center,'Crystal',800,10,3)
 advance(2.1);input(pl,'Scrap','begin');local charge=assert(p.ability.charge)
 advance(.4);input(pl,'Scrap','confirm',charge.token);assert(p.ability.swarm)
 local initial=r.hp;advance(1.5);assert(r.hp<initial,'physical bots should reach and mine the controlled rock')
 local swarm=p.ability.swarm;local before=r.hp;p.busy=true;advance(.3)
 assert(p.ability.swarm==swarm and r.hp==before,'saving must pause work without discarding the swarm')
 p.busy=false;advance(.4);assert(p.ability.swarm==swarm and r.hp<before)
end)
check('successful gadget cooldown is saved and rehydrated runtime rejects immediate reuse',function()
 local pl,p=fixture();data(p).run.shopLevels.cobalt_orbital=1;largeNode()
 input(pl,'Orbital','begin');local charge=assert(p.ability.charge);advance(.4);input(pl,'Orbital','confirm',charge.token)
 local saved=data(p).run.abilityCooldowns.Orbital;assert(saved and saved>now)
 p.ability=nil;input(pl,'Orbital','begin');assert(not p.ability.charge and p.ability.cooldowns.Orbital==saved)
end)
print(checks..' actual server gadget integration checks passed with API doubles; not Studio visual/multiplayer evidence')
