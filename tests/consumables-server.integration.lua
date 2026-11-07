-- Appended to the real server. API doubles do not validate engine LOS or visuals.
local checks=0;local uid=81000;local events={}
RoleEffects.Ability=function(owner,event) table.insert(events,{owner=owner,kind=event.kind}) end
RoleEffects.ClearAbility=function() end
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS equipment server '..name) end
local function advance(seconds) for _=1,math.ceil(seconds*60) do realTime+=1/60;heartbeat:Fire(1/60) end end
local function fixture(kind,stock)
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=assert(profiles[uid])
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 if kind then data(p).consumables.counts[kind]=stock or 1;data(p).consumables.collected=2 end
 return pl,p
end
local function node(offset,health,kind)
 local r=makeResource(patches[1],patches[1].center+(offset or Vector3.zero),kind or 'Crystal',health or 1500,10,3);r.readyAt=now;return r
end
local function input(pl,kind,extra)
 local p=profiles[pl.UserId];local profile=data(p);p.tokens=7;p.bucketAt=now
 local payload={kind=kind,runId=profile.run.id,version=profile.consumables.version,txId=Http:GenerateGUID(false),fieldId=1,x=patches[1].center.X,z=patches[1].center.Z}
 for k,v in pairs(extra or {}) do payload[k]=v end
 command.OnServerEvent:Fire(pl,'PlaceConsumable',payload);return payload
end
check('legacy discovery pickup preserves earned stock without a multiplier',function()
 local pl,p=fixture();local d=p.drones[1]
 data(p).run.cargo.Quartz=Ca.capacity(data(p))
 for i=1,3 do local r=node();discoveries:TrySpawn(pl,r.field.part,r.position,1);if i<3 then assert(not discoveries.states[pl]) end end
 local drop=assert(discoveries.states[pl]);assert(drop.kind=='Orbital' and drop.part:GetAttribute('OwnerUserId')==pl.UserId)
 assert(math.abs(drop.origin.X-patches[1].center.X)<1e-7 and discoveries:Multiplier(pl,'Speed')==1 and discoveries:Multiplier(pl,'Yield')==1)
 advance(.8);assert(not discoveries.states[pl] and data(p).consumables.counts.Orbital==1)
 assert(Pro.cargoUnits(data(p))==Ca.capacity(data(p)),'equipment must fit even when ore bag is full')
 assert(data(p).consumables.collected==1 and not pl:GetAttribute('MA_DiscoveryKind'))
end)
check('drops belong to the miner; collection waits through a save and requires clear reach',function()
 local a,p=fixture();local b,q=fixture();local r=node();local d=p.drones[1]
 data(p).consumables.misses=2;discoveries:TrySpawn(a,r.field.part,r.position,1)
 a.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(25,3,0)));advance(.8)
 assert(discoveries.states[a] and data(q).consumables.counts.Orbital==0)
 a.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)));p.busy=true;advance(.3)
 assert(discoveries.states[a] and data(p).consumables.counts.Orbital==0);p.busy=false
 local old=workspace.Raycast;local wall=Instance.new('Part');wall.Parent=workspace
 workspace.Raycast=function(_,from,delta) return {Instance=wall,Position=from+delta*.5} end;advance(.2);assert(discoveries.states[a])
 workspace.Raycast=old;wall:Destroy();advance(.2);assert(data(p).consumables.counts.Orbital==1)
end)
check('empty pockets malformed placement stale run and locked fields never consume',function()
 local pl,p=fixture('Orbital',1);node()
 local stock=data(p).consumables.counts.Orbital
 for _,extra in ipairs({{x=0/0},{z=math.huge},{x=100001},{fieldId=1.2},{runId='stale'},{version=999},
  {fieldId=2,x=patches[2].center.X,z=patches[2].center.Z}}) do
  input(pl,'Orbital',extra);assert(not p.supply and data(p).consumables.counts.Orbital==stock)
 end
 input(pl,'Scrap');assert(not p.supply)
 input(pl,'Orbital',{x=patches[1].center.X+patches[1].part.Size.X});assert(not p.supply)
end)
check('foreign reservations and blocked targets cannot spend someone else’s tool',function()
 local pl,p=fixture('Orbital',1);local _,other=fixture();local r=node();r.slots[other.drones[1].id]=1
 input(pl,'Orbital');assert(not p.supply and data(p).consumables.counts.Orbital==1)
 r.slots[other.drones[1].id]=nil
 local old=workspace.Raycast;local wall=Instance.new('Part');wall.Parent=workspace
 workspace.Raycast=function(_,from,delta) return {Instance=wall,Position=from+delta*.5} end
 input(pl,'Orbital');assert(not p.supply and data(p).consumables.counts.Orbital==1)
 workspace.Raycast=old;wall:Destroy()
end)
check('orbital placement selects the nearby outlined rock instead of largest in the field',function()
 local pl,p=fixture('Orbital',2);local r=node(Vector3.new(2,0,0),1500);local far=node(Vector3.new(28,0,0),9000)
 data(p).run.abilityCooldowns.Orbital=now+500
 local payload=input(pl,'Orbital');assert(p.supply and data(p).consumables.counts.Orbital==1 and data(p).consumables.pending)
 local stored=runtimeStore.values['player:'..pl.UserId].data;assert(stored.consumables.counts.Orbital==1 and stored.consumables.pending)
 local hp=r.hp;assert(r.hp==hp and not p.supply.started,'damage must wait until save acknowledgement')
 advance(.1);assert(p.supply.state.charge.targetId==r.id)
 input(pl,'Orbital',payload);assert(data(p).consumables.counts.Orbital==1)
 advance(5.6);assert(r.paid and not far.paid and not p.supply and not data(p).consumables.pending)
 assert(data(p).run.abilityCooldowns.Orbital>now+400,'consumable must not rewrite permanent equipment cooldown')
 assert(data(p).consumables.rocks==0,'consumable kills cannot mint another tool')
 local seen=false;for _,event in ipairs(events) do if event.owner==tostring(pl.UserId)..':tool' and event.kind=='orbital' then seen=true end end;assert(seen)
 node();input(pl,'Orbital',{txId=payload.txId});assert(p.supply and data(p).consumables.counts.Orbital==0,'fresh version with reused tx must still spend')
 consumableService:clear(p);assert(data(p).consumables.counts.Orbital==1)
end)
check('save failures leave stock and rocks unchanged; lost acknowledgements reconcile once',function()
 local pl,p=fixture('Orbital',2);local r=node();local hp=r.hp
 runtimeStore.failBefore=3;input(pl,'Orbital');assert(not p.supply and data(p).consumables.counts.Orbital==2 and r.hp==hp)
 runtimeStore.failAfter=3;input(pl,'Orbital');assert(p.supply and data(p).consumables.counts.Orbital==1 and r.hp==hp)
 advance(.2);assert(p.supply.started and data(p).consumables.counts.Orbital==1)
 consumableService:clear(p);assert(data(p).consumables.counts.Orbital==2)
end)
check('empty charge canceled by movement or a newly blocked beam returns the charge',function()
 local pl,p=fixture('Orbital',1);local r=node();input(pl,'Orbital');advance(.1)
 pl.Character:PivotTo(CFrame.new(home));advance(1.8)
 assert(not p.supply and data(p).consumables.counts.Orbital==1 and not r.paid)
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)));input(pl,'Orbital');advance(.1)
 local old=workspace.Raycast;local wall=Instance.new('Part');wall.Parent=workspace;workspace.Raycast=function(_,from,delta) return {Instance=wall,Position=from+delta*.5} end
 advance(1.8);workspace.Raycast=old;wall:Destroy()
 assert(not p.supply and data(p).consumables.counts.Orbital==1)
end)
check('scrap capsule deploys six miners at the marker and affects only its radius',function()
 local pl,p=fixture('Scrap',1);local r=node(Vector3.new(2,0,0),300);local far=node(Vector3.new(30,0,0),300)
 input(pl,'Scrap');advance(1.7);local state=assert(p.supply).state;assert(state.swarm and #state.swarm.bots==6)
 local hp=r.hp;advance(3);assert(r.hp<hp and not data(p).consumables.pending)
 local paused=p.supply;local before=r.hp;p.busy=true;advance(.4);assert(p.supply==paused and r.hp==before);p.busy=false
 advance(9);assert(not p.supply and not far.paid and data(p).consumables.counts.Scrap==0)
end)
check('partial consumable work and geode descendants never create a drop loop',function()
 local pl,p=fixture('Orbital',1);local r=node(nil,5000,'Geode');input(pl,'Orbital');advance(5.8)
 assert(r.paid);advance(2.1)
 local children=0
 for _,child in ipairs(patches[1].resources) do if not child.paid and (child.kind=='Core' or child.kind=='Shard') then
  children+=1;assert(child.consumableWorked);assert(hitResource(p.drones[1],child,1e8,false,nil,child.position+Vector3.new(0,34,0)))
 end end
 assert(children==5 and data(p).consumables.rocks==0)
end)
check('disconnect refunds an unused saved reservation and destroys active deployment',function()
 local pl,p=fixture('Orbital',1);node();input(pl,'Orbital');advance(.1)
 players.PlayerRemoving:Fire(pl)
 local saved=runtimeStore.values['player:'..pl.UserId].data
 assert(saved.consumables.counts.Orbital==1 and not saved.consumables.pending and not p.supply)
end)
check('expired world equipment cleans up and retains the earned guarantee',function()
 local pl,p=fixture();local r=node();data(p).consumables.misses=2
 discoveries:TrySpawn(pl,r.field.part,r.position,1)
 pl.Character:PivotTo(CFrame.new(home));local state=assert(discoveries.states[pl])
 realTime=state.expires+.1;discoveries:Step();assert(not discoveries.states[pl] and data(p).consumables.misses>=3)
 assert(Consumables.onRock(data(p).consumables,1,.999,.999)=='Orbital')
end)
print(checks..' production consumable server checks; not Studio visual, networking or fun evidence')
