-- Production server functions with API doubles; not an engine playtest.
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS core gameplay '..name) end
RoleEffects.BreakerPhase=function() end;discoveries.TrySpawn=function() end
local uid=210000
local function fixture()
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=profiles[uid];local f=patches[1]
 pl.Character:PivotTo(CFrame.new(f.center+Vector3.new(0,3,0)))
 for _,r in ipairs(f.resources) do r.paid=true;r.hp=0 end
 local workers={}
 for _,d in ipairs(p.drones) do
  release(d);d.autoField=nil
  if DroneRoles.isWorker(d.role) then table.insert(workers,d) end
 end
 return pl,p,f,workers
end
local function rock(f,stages,x)
 local r=makeResource(f,f.center+Vector3.new(x or 0,0,0),'Crystal',1000,10,stages==7 and 7 or 3,stages or 3)
 r.readyAt=now;return r
end
local function click(pl,p,r)
 p.tokens=10;p.bucketAt=now;command.OnServerEvent:Fire(pl,'MineOre',r.id)
end
check('three explicit clicks recruit helpers without restarting existing work',function()
 local pl,p,f,w=fixture();local r=rock(f,7)
 click(pl,p,r);local first
 for _,d in ipairs(w) do if d.target==r then first=d end end
 assert(first);first.warmAt=now-1
 click(pl,p,r);click(pl,p,r)
 local count=0;for _ in pairs(r.slots) do count+=1 end
 assert(count==3 and first.warmAt==now-1 and r.part:GetAttribute('SlotsUsed')==3)
 click(pl,p,r);assert(#p.oreQueue==0 and first.warmAt==now-1,'full owned rock restarted work')
end)
check('manual priority interrupts automatic travel then resumes the field',function()
 local pl,p,f,w=fixture();local d=w[1];for i=2,#w do w[i].hp=0 end
 local a,b=rock(f,3),rock(f,3,12)
 d.field=f.id;d.autoField=f.id;chooseResource(d,f);local old=d.target
 assert(old);local target=old==a and b or a
 click(pl,p,target)
 assert(d.target==target and d.manualTarget==target.id and d.autoField==f.id and not old.slots[d.id])
 d.pos=committedStation(d,target);assert(hitResource(d,target,10000))
 assert(d.autoField==f.id and not d.manualTarget)
 chooseResource(d,f);assert(d.target==old,'automatic work did not resume')
end)
check('manual shell continuation remains protected even with automatic orders',function()
 local _,p,f,w=fixture();local d=w[1];for i=2,#w do w[i].hp=0 end
 local shell=makeResource(f,f.center,'Geode',20,10,3);shell.readyAt=now
 local other=rock(f,3,12);d.autoField=f.id;assert(assignOre(p,d,shell));d.pos=committedStation(d,shell)
 assert(hitResource(d,shell,10000));local core=assert(d.target)
 assert(core.kind=='Core' and d.manualTarget==core.id and d.autoField==f.id)
 p.oreQueue={other.id};dispatchOreQueue(p);assert(d.target==core and #p.oreQueue==1)
end)
check('painted queue does not interrupt a manual order or committed slam',function()
 local _,p,f,w=fixture();local d=w[1];for i=2,#w do w[i].hp=0 end
 local a,b=rock(f,3),rock(f,3,12);d.autoField=f.id;assert(assignOre(p,d,a))
 p.oreQueue={b.id};dispatchOreQueue(p);assert(d.target==a and #p.oreQueue==1)
 d.manualTarget=nil;d.breaker={phase='Dive'};dispatchOreQueue(p);assert(d.target==a and #p.oreQueue==1)
end)
check('shared boulders never allow another player to steal a work slot',function()
 local _,p,f,w=fixture();local r=rock(f,7);assert(assignOre(p,w[1],r))
 local pl2,p2,_,w2=fixture();r.paid=false;r.hp=990
 click(pl2,p2,r);assert(not w2[1].target and #p2.oreQueue==0)
 chooseResource(w2[1],f);assert(w2[1].target~=r)
end)
check('blocked breaker releases reservation and skips the same rock',function()
 local _,p,f,w=fixture();local d
 for _,worker in ipairs(w) do if worker.role=='Charger' then d=worker end end
 assert(d);local r=rock(f,7);assert(assignOre(p,d,r))
 local raycast=workspace.Raycast;local blocker=Instance.new('Part');blocker.Parent=workspace
 function workspace:Raycast() return {Instance=blocker,Position=blocker.Position} end
 breakerDrone(d,p,characterRoot(p),f,C.Tick)
 workspace.Raycast=raycast
 assert(not d.target and not d.breaker and not r.slots[d.id] and r.blockedUntil[d.id]>now)
 for _,n in ipairs(roleNodes(p,f,d)) do if n.id==r.id then assert(not n.eligible) end end
 blocker:Destroy()
end)
check('spawn clearance includes authored branches outside the map container',function()
 local _,_,f=fixture();local raycast=workspace.Raycast;local calls=0
 local branch=Instance.new('Part');branch.Parent=workspace
 function workspace:Raycast(_,_,params)
  calls+=1;assert(params.FilterType==Enum.RaycastFilterType.Exclude)
  assert(params.FilterDescendantsInstances[1]==f.model)
  return {Instance=branch,Position=branch.Position}
 end
 local ok=spawnResource(f,'Crystal')
 workspace.Raycast=raycast;branch:Destroy();assert(not ok and calls>0)
end)
print(checks..' core gameplay contracts passed with API doubles')
