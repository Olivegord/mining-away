-- Executes actual server jobs, not a parallel gameplay implementation.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS committed mining '..name) end
RoleEffects.Grow=function() end;RoleEffects.BreakerPhase=function() end;discoveries.TrySpawn=function() end
local uid=97000
local function fixture()
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=assert(profiles[uid])
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 local roles={};for _,d in ipairs(p.drones) do roles[d.role]=d end
 return pl,p,roles
end
local function tick(d,n)
 for _=1,n do realTime+=C.Tick;now=realTime;droneStep(d,C.Tick) end
end
local function rock(offset,kind,hp)
 local r=makeResource(patches[1],patches[1].center+offset,kind or 'Crystal',hp or 5000,10,3);r.readyAt=now;return r
end
check('save latency preserves committed travel and freezes damage only',function()
 local _,p,roles=fixture();local d=roles.Striker;local r=rock(Vector3.zero)
 assert(assignOre(p,d,r));local station=committedStation(d,r)
 d.pos=station+Vector3.new(-25,0,0);d.velocity=Vector3.new(8,0,0);tick(d,1)
 local before=d.pos;local hp=r.hp;p.busy=true;setMotionPaused(p,true);tick(d,120);snapshotDrone(d)
 assert((d.pos-before).Magnitude>1,'healthy storage stopped flight')
 assert(d.target==r and r.slots[d.id] and d.workStation==station and r.hp==hp)
 assert(d.model:GetAttribute('MotionPaused')==false and d.model:GetAttribute('WorkPaused')==true)
 p.busy=false;setMotionPaused(p,false);tick(d,300)
 assert(r.hp<hp and d.target==r,'work failed to resume at its committed rock')
end)
check('warmup has an honest arrival gate and a separate replicated phase',function()
 local _,p,roles=fixture();local d=roles.Striker;local r=rock(Vector3.zero);assert(assignOre(p,d,r))
 local station=committedStation(d,r);d.pos=station+Vector3.new(-30,0,0);d.velocity=Vector3.zero
 local hp=r.hp;tick(d,30);assert(r.hp==hp and not d.warmAt,'work during approach')
 for _=1,600 do tick(d,1);if d.warmAt then break end end
 assert(d.warmAt and d.state=='Warmup' and not d.mining and r.hp==hp)
 snapshotDrone(d);assert(d.model:GetAttribute('State')=='Warmup')
 local warmAt=d.warmAt;p.busy=true;tick(d,120);p.busy=false
 assert(math.abs((now-d.warmAt)-(now-2-warmAt))<1e-5 and r.hp==hp)
 tick(d,90);assert(d.mining and d.state=='Mine' and r.hp<hp)
end)
check('queued orders and nearby owner travel never replace a running job',function()
 local pl,p,roles=fixture();local d=roles.Striker;roles.Charger.hp=0
 local a=rock(Vector3.zero);local b=rock(Vector3.new(10,0,0));assert(assignOre(p,d,a))
 p.oreQueue={b.id};local station=committedStation(d,a)
 for n=1,180 do
  pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(math.sin(n*.03)*12,3,0)))
  dispatchOreQueue(p);tick(d,1)
  assert(d.target==a and d.workStation==station and #p.oreQueue==1)
 end
end)
check('already queued work has bounded completion release rather than an idle second',function()
 local _,p,roles=fixture();local d=roles.Striker;roles.Charger.hp=0
 local a=rock(Vector3.zero,'Crystal',20);local b=rock(Vector3.new(10,0,0));assert(assignOre(p,d,a))
 d.pos=committedStation(d,a);d.goal=d.pos;d.intentGoal=d.pos;p.oreQueue={b.id}
 assert(hitResource(d,a,1000));assert(a.paid and not next(a.slots) and d.lingerUntil-now<=.201)
 tick(d,15);dispatchOreQueue(p);assert(d.target==b and not d.lingerUntil)
end)
check('breaker cannot start another windup while still returning from impact',function()
 local _,p,roles=fixture();local d=roles.Charger;local r=rock(Vector3.zero);assert(assignOre(p,d,r))
 d.pos=committedStation(d,r)+Vector3.new(0,2,0);d.velocity=Vector3.zero
 for _=1,300 do tick(d,1);if d.breaker and d.breaker.phase=='Recover' then break end end
 local job=assert(d.breaker);assert(job.phase=='Recover')
 local hp=r.hp;d.pos=job.station+Vector3.new(0,-8,0);d.velocity=Vector3.zero
 tick(d,45);assert(d.breaker==job and d.breaker.phase=='Recover' and r.hp==hp)
 for _=1,600 do tick(d,1);if d.breaker~=job then break end end
 assert(d.breaker~=job,'never returned to overhead work')
end)
check('a save during a powered dive finishes flight without damage or a resume rewind',function()
 local _,p,roles=fixture();local d=roles.Charger;local r=rock(Vector3.zero);assert(assignOre(p,d,r))
 d.pos=committedStation(d,r)+Vector3.new(0,2,0);d.velocity=Vector3.zero
 for _=1,300 do tick(d,1);if d.breaker and d.breaker.phase=='Dive' then break end end
 local job=assert(d.breaker);assert(job.phase=='Dive');local hp=r.hp
 p.busy=true;tick(d,60);assert(r.hp==hp and (d.pos-job.impact).Magnitude<1e-7)
 local held=d.pos;p.busy=false;tick(d,1)
 assert((d.pos-held).Magnitude<1e-7 and r.hp<hp and d.impactSerial==1,'resume rewound or duplicated dive')
end)
check('layer mechanics make hard-shell breakers and exposed-layer cutters distinct',function()
 local outer=Mining.contactMultiplier('Charger','Geode',8,0,3)
 local inner=Mining.contactMultiplier('Charger','Core',8,3,3)
 assert(outer==2.5 and inner==1)
 assert(Mining.contactMultiplier('Striker','Core',8,3,3)==1.35)
 assert(Mining.contactMultiplier('Striker','Crystal',1,0,3)==1)
 local _,p,roles=fixture();local d=roles.Striker;local r=rock(Vector3.zero);assert(assignOre(p,d,r));d.pos=committedStation(d,r)
 r.stage=3;local hp=r.hp;assert(hitResource(d,r,10));assert(math.abs(hp-r.hp-13.5)<1e-6)
end)
check('unhealthy persistence still freezes movement and awards',function()
 local _,p,roles=fixture();local d=roles.Striker;local r=rock(Vector3.zero);assert(assignOre(p,d,r));tick(d,1)
 p.session.readOnly=true;p.busy=true;setMotionPaused(p,true);local before=d.pos;local hp=r.hp
 tick(d,120);snapshotDrone(d);assert((d.pos-before).Magnitude==0 and r.hp==hp and d.model:GetAttribute('MotionPaused'))
end)
check('a manually ordered shell continues into its real growing core without granting plot automation',function()
 local _,p,roles=fixture();local d=roles.Striker;local shell=rock(Vector3.zero,'Geode',20)
 assert(assignOre(p,d,shell));d.pos=committedStation(d,shell)
 assert(hitResource(d,shell,1000));local core=assert(d.target)
 assert(shell.paid and not next(shell.slots) and core.kind=='Core' and core.slots[d.id]==1)
 assert(not d.autoField and not d.lingerUntil and core.readyAt>now)
 local hp=core.hp;tick(d,60);assert(core.hp==hp,'mined a growing core')
 tick(d,420);assert(core.hp<hp,'never completed arrival/warmup on the revealed core')
end)
print(checks..' production mining-flight checks using API doubles; not engine or fun evidence')
