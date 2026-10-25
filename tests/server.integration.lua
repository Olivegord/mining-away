-- Appended to the actual bundled Server.lua inside the API-double environment.
local checks=0
local function check(name,f)
 local ok,err=pcall(f);assert(ok,name..': '..tostring(err));checks=checks+1;print('PASS integration '..name)
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function advance(seconds)
 for i=1,math.ceil(seconds/.1) do realTime=realTime+.1;heartbeat:Fire(.1) end
end
local alice=player(101);players.PlayerAdded:Fire(alice)
local bob=player(202);players.PlayerAdded:Fire(bob)
local function input(pl,action,value)
 profiles[pl.UserId].tokens=6;command.OnServerEvent:Fire(pl,action,value)
end
local function teleport(pl,pos) pl.Character.PrimaryPart.Position=pos end
check('three server-owned replicated drones and late-join state',function()
 eq(#profiles[101].drones,3);eq(#profiles[202].drones,3)
 advance(.1)
 for _,d in pairs(drones) do eq(d.model.Parent,root);eq(d.model:GetAttribute('Owner'),d.owner);eq(d.model:GetAttribute('State'),d.state) end
 eq(patches[2].model:GetAttribute('Phase'),'Guarded')
end)
check('remote rejects invalid patches and out-of-range order',function()
 input(alice,'Patch',0/0);input(alice,'Patch',math.huge);input(alice,'Patch','2');input(alice,'Patch',{});input(alice,'Patch',-1);input(alice,'Patch',1)
 eq(profiles[101].drones[1].patch,nil)
end)
check('remote flood bucket bounds commands',function()
 local p=profiles[101];p.tokens=0
 input(alice,'Unsupported');p.tokens=0;command.OnServerEvent:Fire(alice,'Recall');eq(p.tokens,0)
end)
check('shared geode shell generates five children once',function()
 local p=patches[1];local r=p.resources[#p.resources];local d=profiles[101].drones[1]
 local before=#p.resources;d.patch=1;r.slots[d.id]=true;d.target=r
 for i=1,3 do hitResource(d,p,r,99999) end
 eq(#p.resources,before+5);eq(r.paid,true);eq(d.target,nil);eq(profiles[101].ore,0)
end)
check('dead drones cannot damage or reserve geodes',function()
 local d=profiles[101].drones[1];local p=patches[1];local r=p.resources[1];d.target=r;r.slots[d.id]=true;kill(d)
 local hp=r.hp;hitResource(d,p,r,999);eq(r.hp,hp);eq(r.slots[d.id],nil);eq(d.target,nil)
end)
check('free reprint is at home, keeps inventory and both upgrades',function()
 local p=profiles[101];local d=p.drones[1];p.ore=44;p.credits=333;p.power=2;p.hull=2;d.maxHP=182
 advance(12.1);eq(d.hp>0,true);eq(d.life,2);eq(d.patch,nil);eq(p.ore,44);eq(p.credits,333);eq(p.power,2);eq(p.hull,2);assert((d.pos-origin).Magnitude<30)
end)
check('sale belongs to invoker and requires home range',function()
 local a,b=profiles[101],profiles[202];a.ore=50;b.ore=70;a.credits=0;b.credits=0
 teleport(alice,patches[2].center);input(alice,'Sell',bob);eq(a.ore,50);eq(b.ore,70)
 teleport(alice,origin);input(alice,'Sell',bob);eq(a.credits,50);eq(a.ore,0);eq(b.credits,0);eq(b.ore,70)
end)
check('credit funded upgrades reject bad type and remote location',function()
 local a=profiles[101];a.credits=999;a.power=0
 input(alice,'Upgrade','damage');eq(a.credits,999)
 teleport(alice,patches[2].center);input(alice,'Upgrade','power');eq(a.power,0)
 teleport(alice,origin);for _,d in ipairs(a.drones) do recall(d) end
 input(alice,'Upgrade','power');eq(a.power,1);eq(a.credits,879)
end)
check('ordinary resources reserve only one slot in actual selector',function()
 local p=patches[1];clearResources(p);local r=resource(p,p.center+Vector3.new(0,5,0),10,20,false,false)
 local a,b=profiles[101].drones[1],profiles[202].drones[1];release(a);release(b);a.pos=r.part.Position;b.pos=r.part.Position
 chooseResource(a,p);chooseResource(b,p);eq(a.target,r);eq(b.target,nil);eq(r.limit,1)
 release(a)
end)
check('simultaneous ordinary hits credit only one owner',function()
 local p=patches[1];local r=p.resources[1];local a,b=profiles[101].drones[1],profiles[202].drones[1]
 r.slots[a.id]=true;a.target=r;local before=profiles[101].ore;local other=profiles[202].ore
 hitResource(a,p,r,999);hitResource(b,p,r,999);eq(profiles[101].ore,before+20);eq(profiles[202].ore,other)
end)
check('all turret health including killed defenses resets on wipe',function()
 local p=patches[2];p.e=R.newEncounter();R.gather(p.e,clock)
 local a=profiles[101];for _,d in ipairs(a.drones) do d.pos=p.center+Vector3.new(0,10,0);d.patch=2 end
 R.enroll(p.e,101,a.drones);R.step(p.e,clock+4,3,true,false)
 p.turrets[1].hp=0;p.turrets[2].hp=1
 for _,d in ipairs(a.drones) do kill(d) end
 tickEncounter(p);eq(p.e.phase,'Resetting');for _,t in ipairs(p.turrets) do eq(t.hp,p.cfg.TurretHP) end
end)
check('friend cannot recruit free replacements during active assault',function()
 advance(12.1)
 local p=patches[2];p.e=R.newEncounter();R.gather(p.e,clock)
 local a,b=profiles[101],profiles[202]
 for _,d in ipairs(a.drones) do d.patch=2;d.pos=p.center+Vector3.new(0,10,0) end
 for _,d in ipairs(b.drones) do d.patch=2;d.pos=p.center+Vector3.new(0,10,0) end
 R.enroll(p.e,101,a.drones);R.enroll(p.e,202,b.drones);R.step(p.e,clock+4,6,true,false)
 local d=a.drones[1];kill(d);R.finishReprint(d,clock+12,d.maxHP)
 teleport(alice,p.center);input(alice,'Patch',2);eq(d.patch,nil);eq(R.participates(p.e,d),false)
 -- Avoid progress in this fixture; group remains active at the time of rejection.
 eq(p.e.phase,'Active')
end)
check('retreat and reconnect cannot recover original roster life',function()
 local p=patches[2];local b=profiles[202].drones[1];recall(b);eq(R.participates(p.e,b),false)
 local old=profiles[101].drones[2];local id=old.id
 players.PlayerRemoving:Fire(alice);players.PlayerAdded:Fire(alice)
 local d=drones[id];eq(d~=nil,true);eq(R.participates(p.e,d),false);eq(profiles[101].power,1)
end)
check('clear window cancels mining and resets geodes on expiry',function()
 local p=patches[2];p.e.phase='Cleared';p.e.untilTime=clock+.1
 local d=profiles[202].drones[2];d.patch=2;local r=p.resources[1];r.slots[d.id]=true;d.target=r
 advance(.2);eq(p.e.phase,'Resetting');eq(d.target,nil);eq(d.patch,nil);for _,t in ipairs(p.turrets) do eq(t.hp,p.cfg.TurretHP) end
end)
check('server fixed-step catchup is bounded to three damage ticks',function()
 local before=clock;heartbeat:Fire(10);assert(clock-before<=.301)
end)
print(checks..' actual-server integration tests passed using API doubles; not Studio')
local function trial(tier,level)
 local a=profiles[101]
 for _,p in ipairs(patches) do p.e=R.newEncounter();if p.id==1 then p.e.phase='Safe' end;restoreTurrets(p);seed(p) end
 for _,p in pairs(profiles) do for _,d in ipairs(p.drones) do release(d);d.patch=nil;markSpent(d);d.state='Follow' end end
 local p=patches[tier];a.power=level;a.hull=level;a.ore=0
 teleport(alice,p.center+Vector3.new(0,4,10));teleport(bob,origin)
 for _,d in ipairs(a.drones) do d.hp=C.Hull*(1+level*.8);d.maxHP=d.hp;d.pos=p.center+Vector3.new((d.slot-2)*4,10,15);d.model:PivotTo(CFrame.new(d.pos));d.state='Follow' end
 input(alice,'Patch',tier)
 local started=clock
 while clock-started<96 and (p.e.phase=='Gathering' or p.e.phase=='Active') do advance(.1) end
 print(string.format('BALANCE tier=%d level=%d result=%s elapsed=%.1f remainingHP=%.1f',tier,level,p.e.phase,clock-started,a.drones[1].hp+a.drones[2].hp+a.drones[3].hp))
 return p.e.phase
end
check('unupgraded fleet cannot brute force Amber in actual simulation',function() eq(trial(3,0),'Resetting') end)
check('recommended Cobalt fleet can defeat defenses',function() eq(trial(2,1),'Cleared') end)
check('recommended Amber fleet can defeat defenses',function() eq(trial(3,3),'Cleared') end)
check('failed repeated Amber attempts restart every turret at full health',function()
 for attempt=1,3 do
  eq(trial(3,0),'Resetting')
  for _,t in ipairs(patches[3].turrets) do eq(t.hp,patches[3].cfg.TurretHP) end
 end
end)
check('server line of sight blocks both sides combat damage',function()
 local p=patches[2];p.e=R.newEncounter();restoreTurrets(p);R.gather(p.e,clock)
 local a=profiles[101];local d=a.drones[1];d.hp=70;d.patch=2;d.pos=p.turrets[1].part.Position+Vector3.new(0,5,8);d.state='Attack';R.enroll(p.e,101,{d});R.step(p.e,clock+4,1,true,false)
 local original=workspace.Raycast;workspace.Raycast=function() return {Instance=home} end
 local before=p.turrets[1].hp;tickDrone(d);eq(p.turrets[1].hp,before)
 local t=p.turrets[1];t.lock=d;t.fireAt=clock;t.nextShot=0
 tickTurrets(p);eq(d.hp,70);eq(t.lock,nil);workspace.Raycast=original
end)
print(checks..' total actual-server integration tests passed using API doubles; not Studio')
check('dead fleet cannot start an empty guarded encounter',function()
 local p=patches[3];p.e=R.newEncounter();local a=profiles[101]
 for _,d in ipairs(a.drones) do kill(d) end
 teleport(alice,p.center);input(alice,'Patch',3);eq(p.e.phase,'Guarded')
end)
check('remote bucket blocks repeated upgrade mutation',function()
 local a=profiles[202];teleport(bob,origin);a.power=0;a.credits=1000;a.tokens=1;a.bucketAt=clock
 for _,d in ipairs(a.drones) do recall(d) end
 command.OnServerEvent:Fire(bob,'Upgrade','power');command.OnServerEvent:Fire(bob,'Upgrade','power')
 eq(a.power,1);eq(a.credits,880)
end)
check('geode selector caps three simultaneous drones',function()
 local p=patches[1];clearResources(p);local r=resource(p,p.center+Vector3.new(0,5,0),100,0,true,false)
 local selected=0
 for i=1,6 do
  local d={id='test-slot-'..i,pos=r.part.Position};chooseResource(d,p);if d.target then selected=selected+1 end
 end
 eq(selected,3)
end)
print(checks..' FINAL actual-server integration tests passed using API doubles; not Studio')
