-- The real Studio preview crew must retain purchased permanent miners on reconnect.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS special preview '..name) end
local uid=98801
discoveries.TrySpawn=function() end -- This fixture exercises mining, not discovery GUI APIs.
check('Studio begins with the actual one-drone economy',function()
 local pl=player(uid);players.PlayerAdded:Fire(pl);local p=assert(profiles[uid])
 assert(preview and #p.drones==1 and #data(p).fleet==1 and not p.testFleet)
 assert(pl:GetAttribute('BackpackCapacity')==40 and pl:GetAttribute('AutomationMineEnabled')==false)
 assert(not data(p).logistics.backpack and #data(p).logistics.carriers==0)
 assert(data(p).run.wallet.Quartz==100 and #data(p).run.cards==0 and not next(data(p).run.shopLevels))
 assert(p.player:GetAttribute('MA_DevToolsEnabled')==true and store.mode:sub(1,7)=='Preview')
 command.OnServerEvent:Fire(pl,'RoleLoadout');publish(p)
 assert(#p.drones==15 and #data(p).fleet==1)
 assert(pl:GetAttribute('BackpackCapacity')==C.Capacity and pl:GetAttribute('AutomationMineEnabled')==true)
 assert(not data(p).logistics.backpack and #data(p).logistics.carriers==0,'preview roles granted permanent gear')
 local workers=0;for _,d in ipairs(p.drones) do if DroneRoles.isWorker(d.role) then workers+=1;assert(d.stats.plotAuto==1) end end
 assert(workers==9 and Pro.validate(data(p),uid))
end)
check('permanent special purchase appears beside preview roles and survives reconnect',function()
 local p=profiles[uid];local pl=p.player
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));data(p).run.wallet.Quartz=10000;data(p).run.credits=10000
 p.tokens=7;p.bucketAt=now
 command.OnServerEvent:Fire(pl,'BuyDrone',{droneType='Bubbler',txId='preview-permanent',runId=data(p).run.id})
 assert(#data(p).fleet==2 and #p.drones==16)
 local owned=data(p).fleet[2];assert(owned.role=='Bubbler')
 local id=owned.id;players.PlayerRemoving:Fire(pl);assert(not profiles[uid])
 local replacement=player(uid);players.PlayerAdded:Fire(replacement);p=assert(profiles[uid])
 assert(#data(p).fleet==2 and #p.drones==2)
 local count=0;for _,d in ipairs(p.drones) do if d.role=='Bubbler' then assert(d.id==id);count+=1 end end
 assert(count==1 and not p.testFleet and Pro.validate(data(p),uid))
end)
check('one plot command assigns every miner and each reserves distinct real work',function()
 local pl=player(uid+1);players.PlayerAdded:Fire(pl);local p=assert(profiles[uid+1]);local field=patches[1]
 command.OnServerEvent:Fire(pl,'RoleLoadout')
 pl.Character:PivotTo(CFrame.new(field.center+Vector3.new(0,3,0)))
 for _,r in ipairs(field.resources) do r.paid=true;r.hp=0 end
 for i=1,field.cfg.Count do
  local r=makeResource(field,field.center+Vector3.new((i%4-1.5)*5,0,(math.floor((i-1)/4)-1)*5),'Crystal',5000,10,3)
  r.readyAt=now
 end
 command.OnServerEvent:Fire(pl,'Patch',1)
 local count=0;local targets={}
 for _,d in ipairs(p.drones) do if DroneRoles.isWorker(d.role) then
  assert(d.field==1 and d.autoField==1,'plot order omitted '..d.role)
  droneStep(d,C.Tick)
  local r=assert(d.target,'no assigned rock for '..d.role)
  assert(not targets[r.id] and r.slots[d.id]);targets[r.id]=true;count+=1
  snapshotDrone(d);assert(d.model:GetAttribute('CanMine')==true and d.model:GetAttribute('AutoFieldId')==1)
 else snapshotDrone(d);assert(d.model:GetAttribute('CanMine')==false) end end
 assert(count==9)
 -- Completed specialists keep the plot order and select another ready rock.
 for _,d in ipairs(p.drones) do if DroneRoles.isSpecial(d.role) then
  local previous=d.target;d.pos=Feel.mineGoal(previous.position,d.targetSlot,false,previous.fullSize)
  droneStep(d,C.Tick);now+=d.stats.warmup+C.Tick;realTime=now;droneStep(d,C.Tick)
  local job=assert(d.specialJob);local hp=previous.hp
  now=job.startedAt+job.duration*job.impact+C.Tick;realTime=now;droneStep(d,C.Tick)
  assert(not previous.paid and previous.hp<hp,'first cycle must remove a finite chunk, not the whole hard rock')
  local maxCycles=math.ceil(hp/math.min(job.damage,(previous.maxHP-10)*.25))+4
  for _=1,maxCycles do
   if previous.paid then break end
   job=assert(d.specialJob)
   now=job.startedAt+job.duration+C.Tick;realTime=now;droneStep(d,C.Tick)
   now+=C.Tick;realTime=now;droneStep(d,C.Tick)
   job=assert(d.specialJob)
   now=job.startedAt+job.duration*job.impact+C.Tick;realTime=now;droneStep(d,C.Tick)
  end
  assert(previous.paid,'repeated finite specialist cycles did not finish bounded work')
  d.lingerUntil=nil;droneStep(d,C.Tick)
  assert(d.autoField==1 and d.target and d.target~=previous,'specialist stopped after one rock')
  break
 end end
end)
check('test capacity governs actual collection and survives stat refresh without a saved upgrade',function()
 local p=profiles[uid+1];local pl=p.player
 command.OnServerEvent:Fire(pl,'DevFillBag');publish(p)
 assert(Pro.cargoUnits(data(p))==C.Capacity and pl:GetAttribute('BackpackCapacity')==C.Capacity)
 refreshStats(p);for _,d in ipairs(p.drones) do if DroneRoles.isWorker(d.role) then assert(d.stats.plotAuto==1) end end
 assert(#data(p).run.cards==0 and not next(data(p).run.shopLevels) and #data(p).fleet==1)
 local production=Pro.new(uid+2,42)
 assert(Ca.capacity(production)==Ca.BASE_CAPACITY and Ca.stats(production,production.fleet[1]).plotAuto==0)
end)
print(checks..' Studio-preview ownership logic checks passed with API doubles; not Studio execution')
