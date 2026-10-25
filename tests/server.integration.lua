-- These tests append to the ACTUAL production server bundle in the API double.
-- Synthetic named geometry proves binding/logic, not Roblox rendering/network quality.
local checks,fixtureSerial=0,0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function close(a,b,tolerance) assert(math.abs(a-b)<=(tolerance or 1e-6),tostring(a)..' not close to '..tostring(b)) end
local function check(name,fn)
 local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks=checks+1;print('PASS server '..name)
end
local function advance(seconds,step)
 step=step or 1/60
 local n=math.floor(seconds/step+1e-6)
 for _=1,n do realTime=realTime+step;heartbeat:Fire(step) end
 local left=seconds-n*step;if left>1e-7 then realTime=realTime+left;heartbeat:Fire(left) end
end
local function input(pl,action,payload)
 local p=profiles[pl.UserId];p.tokens=7;p.bucketAt=now;command.OnServerEvent:Fire(pl,action,payload)
end
local function teleport(pl,position) pl.Character:PivotTo(CFrame.new(position)) end
local function payload(pl,id,extra)
 local r={txId=id,runId=data(profiles[pl.UserId]).run.id}
 for k,v in pairs(extra or {}) do r[k]=v end;return r
end
local function fixture(count)
 local leaving={};for _,p in pairs(profiles) do table.insert(leaving,p.player) end
 for _,pl in ipairs(leaving) do players.PlayerRemoving:Fire(pl);pl.Parent=nil end
 fixtureSerial=fixtureSerial+1
 for _,f in ipairs(patches) do
  f.e=R.newEncounter({EncounterPrefix='fixture-'..fixtureSerial..'-field-'..f.id})
  if f.cfg.Turrets==0 then f.e.phase='Safe' end
  restoreTurrets(f);seedField(f)
 end
 local list={}
 for i=1,(count or 1) do local pl=player(fixtureSerial*10+i);players.PlayerAdded:Fire(pl);assert(profiles[pl.UserId]);table.insert(list,pl) end
 advance(.15)
 return table.unpack(list)
end
local function profile(pl) return profiles[pl.UserId] end
local function first(pl) return profile(pl).drones[1] end
local function funding(pl,n) data(profile(pl)).run.credits=n end
local function station(pl,which) teleport(pl,which.Position+Vector3.new(0,3,0)) end
local function newResource(field,kind,hp,ore,at)
 return makeResource(field,at or field.center,kind or 'Crystal',hp or 80,ore or field.cfg.Ore)
end
local function assignExact(pl,field,r,offset)
 local d=first(pl);release(d);d.field=field.id;d.target=r;d.targetSlot=1;r.slots[d.id]=1
 d.pos=Feel.mineGoal(r.position,1,r.kind=='Geode')+(offset or Vector3.zero);d.goal=Feel.mineGoal(r.position,1,r.kind=='Geode');d.state='Mine'
 teleport(pl,field.center+Vector3.new(0,3,0));return d
end
local function enlist(field,list)
 if field.e.phase=='Guarded' then R.gather(field.e,now) end
 for _,pl in ipairs(list) do
  local p=profile(pl);teleport(pl,field.center+Vector3.new(0,4,0))
  for _,d in ipairs(p.drones) do release(d);d.hp=d.stats.maxHealth;d.field=field.id;d.pos=field.center+Vector3.new(0,10,0) end
  eq(R.enroll(field.e,pl.UserId,data(p).run.id,p.drones),true)
 end
 R.step(field.e,now+field.e.gatherDuration,#list,true,false,0)
 eq(field.e.phase,'Active')
end
local function clearFor(field,list)
 enlist(field,list)
 for _,pl in ipairs(list) do R.markContribution(field.e,pl.UserId,data(profile(pl)).run.id) end
 for _,t in ipairs(field.turrets) do t.hp=0 end
 encounterStep(field);eq(field.e.phase,'Cleared')
end
check('fresh profile is one permanent Blue with replicated complete state',function()
 local a=fixture();local p=profile(a);local d=first(a)
 eq(#data(p).fleet,1);eq(#p.drones,1);eq(data(p).prestiges,0);eq(d.owned.type,'Blue');eq(#data(p).run.cards,0)
 eq(d.model.Parent,droneFolder);eq(d.model:GetAttribute('Owner'),a.UserId);eq(d.model:GetAttribute('DroneId'),d.id);eq(d.model:GetAttribute('Life'),1)
 assert(d.model:GetAttribute('Position'));assert(d.model:GetAttribute('Goal'));assert(d.model:GetAttribute('SnapshotAt'))
 local snapshot=Http:JSONDecode(a:GetAttribute('MA_Profile'));eq(#snapshot.fleet,1);eq(snapshot.nextPackPrice,80)
end)
check('map binds the original named construct and never generic turret box',function()
 fixture()
 eq(root:GetAttribute('SourceSceneIntegrated'),true);eq(root:GetAttribute('FieldCount'),5);close(home.Y,.5)
 for _,f in ipairs(patches) do
  for _,t in ipairs(f.turrets) do
   eq(t.model:GetAttribute('OriginalConstruct'),true);eq(t.model:FindFirstChild('AnimSaves'),nil)
   for name,id in pairs(segmentIds) do eq(t.model:FindFirstChild(name,true).MeshId,'rbxassetid://'..id) end
  end
 end
 eq(scene.turretTemplate:FindFirstChild('AnimSaves')~=nil,true);eq(workspace:FindFirstChild('construct'):FindFirstChild('AnimSaves')~=nil,true)
end)
check('random field crystals use variable health scaled original union and two-second growth',function()
 fixture();local f=patches[1];local positions,healths={},{ }
 for _,r in ipairs(f.resources) do
  eq(r.part.ClassName,'UnionOperation');assert(r.maxHP>=50 and r.maxHP<=100);close(r.fullSize.X,r.maxHP/25);close(r.readyAt-r.spawnAt,2)
  positions[#positions+1]=r.position.X;healths[r.maxHP]=true
 end
 local variety=0;for _ in pairs(healths) do variety=variety+1 end;assert(variety>1)
 local old=positions[1];seedField(f);assert(f.resources[1].position.X~=old)
 for _,r in ipairs(f.resources) do assert(math.abs(r.position.X-f.center.X)<=f.part.Size.X/2);assert(math.abs(r.position.Z-f.center.Z)<=f.part.Size.Z/2) end
end)
check('ordinary mining rejects growth and any station farther than one stud',function()
 local a=fixture();local f=patches[1];local r=newResource(f,'Crystal',80,10)
 local d=assignExact(a,f,r,Vector3.new(1.01,0,0));local hp=r.hp
 eq(hitResource(d,r,100),false);eq(r.hp,hp)
 d.pos=Feel.mineGoal(r.position,1,false);eq(hitResource(d,r,100),false);eq(r.hp,hp)
 advance(2.01);release(d);assignExact(a,f,r,Vector3.new(1.01,0,0));eq(hitResource(d,r,1),false)
 d.pos=Feel.mineGoal(r.position,1,false);eq(hitResource(d,r,1),true);eq(r.hp,hp-1)
end)
check('beam and damage start only after exact overhead arrival and warmup',function()
 local a=fixture();local f=patches[1];local r=newResource(f,'Crystal',80,10);advance(2.01)
 local d=assignExact(a,f,r);local hp=r.hp
 droneStep(d,1/60);eq(d.mining,false);eq(r.hp,hp)
 realTime=realTime+d.stats.warmup-.01;now=realTime;droneStep(d,1/60);eq(d.mining,false);eq(r.hp,hp)
 realTime=realTime+.02;now=realTime;droneStep(d,1/60);eq(d.mining,true);assert(r.hp<hp);close(d.goal.X,r.position.X);close(d.goal.Z,r.position.Z);close(d.goal.Y-r.position.Y,10)
end)
check('all quarter stages and one final reward execute on production resource path',function()
 local a=fixture();local f=patches[1];local r=newResource(f,'Crystal',100,10);advance(2.01);local d=assignExact(a,f,r)
 eq(r.stage,0);hitResource(d,r,25);eq(r.stage,1);eq(r.part:GetAttribute('Stage'),1)
 hitResource(d,r,25);eq(r.stage,2);hitResource(d,r,25);eq(r.stage,3)
 local before=Profile.cargoUnits(data(profile(a)));hitResource(d,r,25);eq(r.paid,true);eq(r.part:GetAttribute('BreakSerial'),1)
 eq(Profile.cargoUnits(data(profile(a))),before+10);eq(hitResource(d,r,25),false);eq(Profile.cargoUnits(data(profile(a))),before+10);eq(d.target,nil)
end)
check('geode concurrency opens one core set without shell or duplicate rewards',function()
 local a=fixture();local f=patches[2];local r=newResource(f,'Geode',200,12);advance(2.01);local d=assignExact(a,f,r)
 local count=#f.resources;local cargo=Profile.cargoUnits(data(profile(a)))
 hitResource(d,r,99999);hitResource(d,r,99999);hitResource(d,r,99999)
 eq(#f.resources,count+5);eq(Profile.cargoUnits(data(profile(a))),cargo);eq(r.paid,true);eq(next(r.slots),nil)
 local core=0;local shards=0;for i=count+1,#f.resources do if f.resources[i].kind=='Core' then core=core+1 else shards=shards+1 end end
 eq(core,1);eq(shards,4)
end)
check('single crystal and three-slot shell selectors honor reservations',function()
 local a,b=fixture(2);local f=patches[1];seedField(f)
 for _,r in ipairs(f.resources) do r.paid=true end
 local rock=newResource(f,'Crystal',80,10);advance(2.01)
 local da,db=first(a),first(b);release(da);release(db);da.pos=rock.position;db.pos=rock.position
 chooseResource(da,f);chooseResource(db,f);eq(da.target,rock);eq(db.target,nil)
 release(da);rock.paid=true;local shell=newResource(f,'Geode',200,10);advance(2.01)
 local selected=0
 for i=1,4 do local d={id='selector'..i,pos=shell.position};chooseResource(d,f);if d.target then selected=selected+1 end end
 eq(selected,3)
end)
check('sell is invoker-owned at actual Converter and advances cumulative earnings',function()
 local a,b=fixture(2);local pa,pb=profile(a),profile(b)
 Profile.addCargo(data(pa),'Quartz',20,120);Profile.addCargo(data(pb),'Ruby',10,120)
 teleport(a,patches[4].center);input(a,'Sell',b);eq(data(pa).run.credits,0)
 station(a,scene.converter);input(a,'Sell',b);eq(data(pa).run.credits,20);eq(data(pa).run.saleEarnings,20);eq(Profile.cargoUnits(data(pa)),0)
 eq(Profile.cargoUnits(data(pb)),10);eq(data(pb).run.credits,0)
end)
check('pack debit three saved choices replay stable target and choose exactly one',function()
 local a=fixture();local p=profile(a);funding(a,500);station(a,scene.packStation)
 local buy=payload(a,'pack-one',{packIndex=0});input(a,'BuyPack',buy)
 local offer=Profile.clone(data(p).run.pendingOffer);assert(offer);eq(#offer.choices,3);eq(data(p).run.credits,420)
 input(a,'BuyPack',buy);eq(data(p).run.credits,420);eq(data(p).run.pendingOffer.id,offer.id)
 for i,c in ipairs(offer.choices) do eq(data(p).run.pendingOffer.choices[i].cardId,c.cardId);eq(data(p).run.pendingOffer.choices[i].targetDroneId,c.targetDroneId) end
 local select=payload(a,'choose-one',{offerId=offer.id,index=1});input(a,'ChooseCard',select);eq(#data(p).run.cards,1);eq(data(p).run.pendingOffer,nil)
 select.index=2;input(a,'ChooseCard',select);eq(#data(p).run.cards,1);eq(data(p).run.cards[1].cardId,offer.choices[1].cardId)
end)
check('reconnect restores exact pending offer no UI-close reroll or extra debit',function()
 local a=fixture();funding(a,400);station(a,scene.packStation);input(a,'BuyPack',payload(a,'persist-pack',{packIndex=0}))
 local p=profile(a);local before=Profile.clone(data(p).run.pendingOffer);local id=first(a).id;local credits=data(p).run.credits
 players.PlayerRemoving:Fire(a);players.PlayerAdded:Fire(a)
 p=profile(a);eq(first(a).id,id);eq(data(p).run.credits,credits);eq(data(p).run.pendingOffer.id,before.id)
 for i,c in ipairs(before.choices) do eq(data(p).run.pendingOffer.choices[i].cardId,c.cardId);eq(data(p).run.pendingOffer.choices[i].targetDroneId,c.targetDroneId) end
end)
check('same-run free reprint preserves permanent identity and targeted startup modifier',function()
 local a=fixture();local p=profile(a);local d=first(a);local id=d.id;local base=d.stats.miningDPS
 table.insert(data(p).run.cards,{cardId='D05',scope='Individual',targetDroneId=id,effects={startup=1}});refreshStats(p)
 local warmup=d.stats.warmup;close(warmup,d.owned.base.warmup/2);close(d.stats.miningDPS,base)
 data(p).run.credits=123;Profile.addCargo(data(p),'Quartz',11,120);local life=d.life;kill(d)
 eq(d.target,nil);eq(d.field,nil);advance(C.Reprint+C.Assembly+.1)
 eq(d.id,id);eq(d.life,life+1);eq(#data(p).fleet,1);close(d.stats.warmup,warmup);eq(data(p).run.credits,123);eq(Profile.cargoUnits(data(p)),11)
 assert((d.pos-scene.printer.Position).Magnitude<15)
end)
check('prestige creates second-run two permanent drones and resets every run card',function()
 local a=fixture();local p=profile(a);local original=first(a).id
 data(p).run.saleEarnings=2000;data(p).run.wins.Cobalt=1;funding(a,500);Profile.addCargo(data(p),'Ruby',12,120)
 table.insert(data(p).run.cards,{cardId='D05',scope='Individual',targetDroneId=original,effects={startup=1}});refreshStats(p)
 local oldRun=data(p).run.id;station(a,scene.prestigeStation)
 input(a,'Prestige',payload(a,'prestige-once',{confirm=true}))
 eq(#data(p).fleet,2);eq(#p.drones,2);eq(data(p).prestiges,1);eq(data(p).fleet[1].id,original);eq(data(p).fleet[2].type,'Red');assert(data(p).run.id~=oldRun)
 eq(#data(p).run.cards,0);eq(data(p).run.credits,0);eq(Profile.cargoUnits(data(p)),0);eq(data(p).run.saleEarnings,0);eq(data(p).run.packIndex,0)
 for _,d in ipairs(p.drones) do close(d.stats.warmup,d.owned.base.warmup);eq(d.field,nil) end
 input(a,'Prestige',{txId='prestige-once',runId=oldRun,confirm=true});eq(#data(p).fleet,2)
 -- Complete a real second-run purchase and mining assignment with both units.
 funding(a,200);station(a,scene.packStation);input(a,'BuyPack',payload(a,'run-two-pack',{packIndex=0}));assert(data(p).run.pendingOffer)
 local offer=data(p).run.pendingOffer;input(a,'ChooseCard',payload(a,'run-two-choice',{offerId=offer.id,index=1}));eq(#data(p).run.cards,1)
 teleport(a,patches[1].center);input(a,'Patch',1);eq(p.drones[1].field,1);eq(p.drones[2].field,1)
end)
check('pending paid offer blocks prestige and stale offer cannot affect new run',function()
 local a=fixture();local p=profile(a);funding(a,300);data(p).run.saleEarnings=2000;data(p).run.wins.Cobalt=1;station(a,scene.packStation)
 input(a,'BuyPack',payload(a,'pending-pack',{packIndex=0}));local offer=data(p).run.pendingOffer;local oldRun=data(p).run.id
 station(a,scene.prestigeStation);input(a,'Prestige',payload(a,'blocked-prestige',{confirm=true}));eq(data(p).prestiges,0);eq(data(p).run.pendingOffer.id,offer.id)
 input(a,'ChooseCard',payload(a,'resolve-pack',{offerId=offer.id,index=1}));input(a,'Prestige',payload(a,'allowed-prestige',{confirm=true}));eq(data(p).prestiges,1)
 input(a,'ChooseCard',{txId='old-choice',runId=oldRun,offerId=offer.id,index=2});eq(#data(p).run.cards,0)
end)
check('uncertain committed prestige rebuilds world fleet exactly once after reconciliation',function()
 local a=fixture();local p=profile(a);data(p).run.saleEarnings=2000;data(p).run.wins.Cobalt=1
 local original=first(a).id;station(a,scene.prestigeStation);runtimeStore.failAfter=3
 input(a,'Prestige',payload(a,'lost-prestige',{confirm=true}))
 eq(data(p).prestiges,1);eq(#data(p).fleet,2);eq(#p.drones,2);eq(p.drones[1].id,original);eq(p.session.readOnly,false)
 local owned=0;for _,d in pairs(drones) do if d.owner==a.UserId then owned=owned+1 end end;eq(owned,2)
end)
check('failed precommit prestige leaves old run and fleet usable without grant',function()
 local a=fixture();local p=profile(a);data(p).run.saleEarnings=2000;data(p).run.wins.Cobalt=1;local oldRun=data(p).run.id
 station(a,scene.prestigeStation);runtimeStore.failBefore=3;input(a,'Prestige',payload(a,'fail-prestige',{confirm=true}))
 eq(data(p).prestiges,0);eq(#p.drones,1);eq(data(p).run.id,oldRun);eq(p.session.readOnly,false)
 eq(data(p).run.saleEarnings,2000)
end)
check('committed card response loss refreshes effective world stats once',function()
 local a=fixture();local p=profile(a);funding(a,500);station(a,scene.packStation)
 input(a,'BuyPack',payload(a,'lost-card-buy',{packIndex=0}));local offer=data(p).run.pendingOffer;assert(offer)
 local before=Profile.clone(first(a).stats);runtimeStore.failAfter=3
 input(a,'ChooseCard',payload(a,'lost-card-select',{offerId=offer.id,index=1}))
 eq(#data(p).run.cards,1);eq(p.session.readOnly,false)
 local expected=Cards.stats(data(p),data(p).fleet[1]);close(first(a).stats.miningDPS,expected.miningDPS);close(first(a).stats.maxStep60,expected.maxStep60);close(first(a).stats.warmup,expected.warmup)
 assert(before and first(a).stats)
end)
check('guarded damage and cargo blocked without current run entitlement',function()
 local a=fixture();local p=profile(a);local f=patches[3];local r=newResource(f,'Crystal',80,15);advance(2.01);local d=assignExact(a,f,r)
 local hp=r.hp;eq(hitResource(d,r,9999),false);eq(r.hp,hp);eq(Profile.cargoUnits(data(p)),0)
 f.e.phase='Cleared';data(p).run.entitlements[tostring(f.id)]={runId='old-run',encounterId='foreign'}
 eq(playerCanMine(p,f),false);eq(hitResource(d,r,9999),false)
end)
check('cooperative victory gives contributor run entitlements but no outsider inheritance',function()
 local a,b,c=fixture(3);local f=patches[3];clearFor(f,{a,b})
 eq(playerCanMine(profile(a),f),true);eq(playerCanMine(profile(b),f),true);eq(playerCanMine(profile(c),f),false)
 eq(data(profile(a)).run.wins.Cobalt,1);eq(data(profile(b)).run.wins.Cobalt,1)
 teleport(c,f.center);input(c,'Patch',3);eq(first(c).field,nil);eq(f.e.users[c.UserId],nil)
 local late=player(fixtureSerial*10+9);players.PlayerAdded:Fire(late);advance(.1)
 eq(playerCanMine(profile(late),f),false);eq(f.model:GetAttribute('Phase'),'Cleared');assert(first(a).model:GetAttribute('Position'))
end)
check('reassigning a cleared field preserves that run expedition entitlement',function()
 local a=fixture();local f=patches[3];clearFor(f,{a});local entitlement=data(profile(a)).run.entitlements['3'].encounterId
 input(a,'Patch',3);eq(first(a).field,3);eq(playerCanMine(profile(a),f),true);eq(data(profile(a)).run.entitlements['3'].encounterId,entitlement)
end)
check('prestige removes only owner entitlement while teammate expedition continues',function()
 local a,b=fixture(2);local f=patches[3];clearFor(f,{a,b});local encounter=f.e.id
 local pa,pb=profile(a),profile(b);data(pa).run.saleEarnings=2000
 input(a,'Recall');station(a,scene.prestigeStation);input(a,'Prestige',payload(a,'co-op-prestige',{confirm=true}))
 eq(data(pa).prestiges,1);eq(f.e.phase,'Cleared');eq(f.e.id,encounter);eq(playerCanMine(pb,f),true);eq(first(b).field,3);eq(playerCanMine(pa,f),false)
end)
check('same-run reprint and reconnect cannot reinforce an active shared roster',function()
 local a,b=fixture(2);local f=patches[3];enlist(f,{a,b});local d=first(a);local life=d.life;kill(d)
 -- Keep the surviving friend's roster alive; suppress unrelated gunfire while waiting.
 for _,t in ipairs(f.turrets) do t.nextShot=now+100 end
 for _=1,math.ceil((C.Reprint+C.Assembly+.1)*60) do realTime=realTime+1/60;now=realTime;droneStep(d,1/60) end
 eq(d.life,life+1);eq(R.participates(f.e,d,data(profile(a)).run.id),false)
 input(a,'Patch',3);eq(d.field,nil);eq(f.e.phase,'Active')
 players.PlayerRemoving:Fire(a);players.PlayerAdded:Fire(a);eq(R.participates(f.e,first(a),data(profile(a)).run.id),false);eq(f.e.phase,'Active')
end)
check('ten weak repeated wipe attempts restore every turret and earn no protected ore',function()
 local a=fixture();local p=profile(a);local f=patches[5]
 for attempt=1,10 do
  f.e=R.newEncounter({EncounterPrefix='weak-'..attempt});restoreTurrets(f);local d=first(a);d.hp=d.stats.maxHealth;d.state='Follow';d.life=d.life+1
  enlist(f,{a});f.turrets[1].hp=0;f.turrets[2].hp=1;kill(d);encounterStep(f)
  eq(f.e.phase,'Resetting');for _,t in ipairs(f.turrets) do eq(t.hp,f.cfg.TurretHP) end
  eq(Profile.cargoUnits(data(p)),0);eq(playerCanMine(p,f),false);eq(#data(p).fleet,1)
 end
end)
check('clear during yielding owner save queues and applies win after commit',function()
 local a,b=fixture(2);local f=patches[3];enlist(f,{a,b})
 local pa=profile(a);R.markContribution(f.e,a.UserId,data(pa).run.id);R.markContribution(f.e,b.UserId,data(profile(b)).run.id)
 runtimeStore.hook=function()
  for _,t in ipairs(f.turrets) do t.hp=0 end
  encounterStep(f)
  eq(pa.busy,true);eq(data(pa).run.wins.Cobalt,nil)
 end
 -- Exercise the same ordered transaction boundary as autosave; combat sale is intentionally forbidden.
 transact(pa,'integration-yield-save',function() return {saved=true} end)
 eq(data(pa).run.wins.Cobalt,1);eq(playerCanMine(pa,f),true);eq(data(profile(b)).run.wins.Cobalt,1)
end)
check('invalid and stale commands reject without modifying authoritative economy',function()
 local a,b=fixture(2);local p=profile(a);funding(a,1000);station(a,scene.packStation)
 local before=data(p).run.credits
 for _,id in ipairs({0/0,math.huge,-1,999,1.1,'3',{}}) do input(a,'Patch',id) end
 input(a,'BuyPack',{txId='x',runId='stale',packIndex=0});input(a,'BuyPack',{txId='x',runId=data(p).run.id,packIndex=0/0});input(a,'ChooseCard',{txId='x',runId=data(p).run.id,offerId='fake',index=1})
 input(a,'Upgrade','power');input(a,'Damage',{owner=b.UserId,damage=99999});eq(data(p).run.credits,before);eq(data(p).run.pendingOffer,nil);eq(#data(p).run.cards,0)
 p.tokens=0;command.OnServerEvent:Fire(a,'BuyPack',payload(a,'flood',{packIndex=0}));eq(data(p).run.pendingOffer,nil)
end)
check('server LOS blocks combat attacks and telegraphed turret damage',function()
 local a=fixture();local f=patches[3];enlist(f,{a});local d=first(a);local t=f.turrets[1]
 d.pos=t.emitter.Position+Vector3.new(0,8,0);local original=workspace.Raycast;workspace.Raycast=function() return {Instance=scene.packStation} end
 local hp=t.hp;droneStep(d,1/60);eq(t.hp,hp)
 t.lock=d;t.aim=d.pos;t.fireAt=now;t.nextShot=0;local hull=d.hp;turretStep(f);eq(d.hp,hull);eq(t.lock,nil)
 workspace.Raycast=original
end)
check('timed evade can move away from fixed telegraph without stat purchases',function()
 local a=fixture();local f=patches[3];enlist(f,{a});local d=first(a);local t=f.turrets[1]
 d.pos=t.emitter.Position+Vector3.new(0,8,0);t.lock=d;t.aim=d.pos;t.fireAt=now+.8
 local aim=t.aim;input(a,'Evade');for _=1,48 do realTime=realTime+1/60;now=realTime;droneStep(d,1/60) end
 local hull=d.hp;assert((d.pos-aim).Magnitude>3.5);turretStep(f);eq(d.hp,hull)
end)
check('joining during mining and reprint receives current snapshot without replayed rewards',function()
 local a=fixture();local f=patches[1];local r=newResource(f,'Crystal',100,10);advance(2.01);local d=assignExact(a,f,r)
 d.warmAt=now-d.stats.warmup-.01;droneStep(d,1/60);snapshotDrone(d)
 local oldOre=Profile.cargoUnits(data(profile(a)));local late=player(fixtureSerial*10+9);players.PlayerAdded:Fire(late)
 eq(d.model:GetAttribute('Mining'),true);eq(d.model:GetAttribute('TargetId'),r.id);eq(Profile.cargoUnits(data(profile(a))),oldOre)
 kill(d);snapshotDrone(d);eq(d.model:GetAttribute('State'),'Destroyed');assert(d.model:GetAttribute('ReprintAt')>now);eq(#data(profile(late)).fleet,1)
end)
check('leave saves durable run and removes all server models and reservations',function()
 local a=fixture();local p=profile(a);data(p).run.credits=341;local id=first(a).id
 players.PlayerRemoving:Fire(a);eq(profiles[a.UserId],nil);eq(drones[id],nil)
 eq(runtimeStore.values['player:'..a.UserId].data.run.credits,341);eq(runtimeStore.values['player:'..a.UserId].lock,nil)
 players.PlayerAdded:Fire(a);eq(data(profile(a)).run.credits,341);eq(first(a).id,id)
end)
check('large frame stall runs bounded movement steps rather than unlimited catchup',function()
 local a=fixture();local d=first(a);local start=d.pos;teleport(a,start+Vector3.new(200,0,0));local cap=d.stats.maxStep60
 realTime=realTime+10;heartbeat:Fire(10);assert((d.pos-start).Magnitude<=cap*8+.001)
end)
check('failed runtime profile load spawns no replacement defaults and writes no profile',function()
 fixture();local pl=player(900001);runtimeStore.failBefore=3
 players.PlayerAdded:Fire(pl);eq(profiles[pl.UserId],nil);eq(runtimeStore.values['player:'..pl.UserId],nil)
 assert(string.find(pl:GetAttribute('MA_SaveStatus'),'no defaults'))
 for _,d in pairs(drones) do assert(d.owner~=pl.UserId) end
end)
check('speed modifiers do not reroll the permanent original hover phase',function()
 local a=fixture();local p=profile(a);local d=first(a);snapshotDrone(d)
 local phase=d.model:GetAttribute('PhaseSeed');local original=d.stats.maxStep60
 table.insert(data(p).run.cards,{cardId='C01',scope='Color',type='Blue',effects={speed=1}})
 refreshStats(p);snapshotDrone(d);close(d.stats.maxStep60,original*2);close(d.model:GetAttribute('PhaseSeed'),phase)
end)
check('geode replenishment consumes its full five-node budget without growing retry backlog',function()
 local a=fixture();local f=patches[2];local oldCount=f.cfg.Count;f.cfg.Count=5
 for _,r in ipairs(f.resources) do resources[r.id]=nil;r.part:Destroy() end;f.resources={};f.respawnQueue={}
 local originalNext=seed.NextNumber
 seed.NextNumber=function(self,lo,hi) if lo==nil then return .01 end;return originalNext(self,lo,hi) end
 for cycle=1,10 do
  f.respawnQueue={now,now,now,now,now};advance(.2)
  eq(#f.respawnQueue,0);eq(nodeUsage(f),5)
  local shell;for _,r in ipairs(f.resources) do if not r.paid then shell=r end end
  eq(shell.kind,'Geode');shell.readyAt=now-1;assignExact(a,f,shell);eq(hitResource(first(a),shell,99999),true)
  for _,r in ipairs(table.clone(f.resources)) do
   if not r.paid then r.readyAt=now-1;assignExact(a,f,r);eq(hitResource(first(a),r,99999),true) end
  end
  eq(#f.respawnQueue,5);eq(nodeUsage(f),0);data(profile(a)).run.cargo={}
  -- This fixture advances the pending due instants, without changing production spawn logic.
  for i=1,#f.respawnQueue do f.respawnQueue[i]=now end
 end
 seed.NextNumber=originalNext;f.cfg.Count=oldCount
end)
print(checks..' actual production server integration tests passed using API doubles; Roblox engine/network/rendering remain untested')
