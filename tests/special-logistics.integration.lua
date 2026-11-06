-- Appended to the CURRENT game's complete server bundle and existing API double.
-- No engine, live DataStore, real networking, visual quality, or fun claims.
local specialChecks=0
local function specialCheck(name,fn)
 local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));specialChecks+=1;print('PASS special/logistics server '..name)
end
local function specialEq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local specialUid=97000
local function specialClock(dt) realTime+=dt;now=realTime end
local function specialInput(pl,p,action,payload)
 p.tokens=7;p.bucketAt=now;command.OnServerEvent:Fire(pl,action,payload)
end
local function specialOwner()
 specialUid+=1;local pl=player(specialUid);players.PlayerAdded:Fire(pl);local p=assert(profiles[specialUid])
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)))
 data(p).run.wallet.Quartz=1000000;data(p).run.credits=1000000
 return pl,p
end
local function specialBuy(pl,p,kind,tx)
 specialInput(pl,p,'BuyDrone',{droneType=kind,txId=tx or ('special:'..kind),runId=data(p).run.id})
 for _,d in ipairs(p.drones) do if d.role==kind then return d end end
 error('No purchased runtime '..kind..': '..tostring(pl:GetAttribute('MA_Notice')))
end
local function specialTicks(d,seconds)
 for _=1,math.ceil(seconds/C.Tick) do specialClock(C.Tick);droneStep(d,C.Tick) end
end
local function specialRock(p,d,kind,hp,ore,fieldOverride)
 local field=fieldOverride or patches[1]
 for _,r in ipairs(field.resources) do r.paid=true;r.hp=0 end
 p.player.Character:PivotTo(CFrame.new(field.center+Vector3.new(0,3,0)))
 local r=makeResource(field,field.center,kind or 'Crystal',hp or 20000,ore or 11,3)
 r.readyAt=now;assert(assignOre(p,d,r));d.pos=Feel.mineGoal(r.position,d.targetSlot,r.kind=='Geode',r.fullSize)
 d.goal=d.pos;d.velocity=Vector3.zero
 return r,field
end
discoveries.TrySpawn=function() end
specialCheck('nine simultaneous storage yards stand above the authored terrain footprint',function()
 local terrain=MapLayout.plan(C.Fields,{home.X,home.Y,home.Z});local owners={};local raised=false
 for _=1,9 do local pl,p=specialOwner();table.insert(owners,{pl=pl,p=p}) end
 for _,owner in ipairs(owners) do
  local building=assert(root:FindFirstChild('OrbitalStorage_'..owner.pl.UserId))
  local pad=assert(building:FindFirstChild('LaunchPad'));local bottom=pad.Position.Y-pad.Size.Y/2
  for _,x in ipairs({-pad.Size.X/2,0,pad.Size.X/2}) do
   for _,z in ipairs({-pad.Size.Z/2,0,pad.Size.Z/2}) do
    assert(bottom+1e-6>=terrain:surface(pad.Position.X+x,pad.Position.Z+z),'storage pad intersects authored terrain')
   end
  end
  if pad.Position.Y>home.Y+1 then raised=true end
  for _,piece in ipairs(building:GetChildren()) do
   if piece:IsA('BasePart') and piece.Name~='FoundationSupport' then
    assert(piece.Position.Y-piece.Size.Y/2+1e-6>=terrain:surface(piece.Position.X,piece.Position.Z),'visible storage structure is buried')
   elseif piece.Name=='FoundationSupport' then
    local ground=terrain:surface(piece.Position.X,piece.Position.Z)
    assert(math.abs(piece.Position.Y-piece.Size.Y/2-ground)<1e-6,'foundation does not reach terrain')
    assert(math.abs(piece.Position.Y+piece.Size.Y/2-bottom)<1e-6,'foundation does not support pad')
   end
  end
  local capsule=assert(root:FindFirstChild('LaunchCapsule_'..owner.pl.UserId))
  local body=assert(capsule:FindFirstChild('CargoPod'))
  assert(body.Position.Y-body.Size.Y/2>=pad.Position.Y+pad.Size.Y/2,'capsule intersects launch platform')
  for _,piece in ipairs(capsule:GetChildren()) do
   if piece:IsA('BasePart') and piece.Transparency<1 then
    assert(piece.Position.Y-piece.Size.Y/2>=terrain:surface(piece.Position.X,piece.Position.Z),'visible capsule body is buried')
   end
  end
 end
 assert(raised,'fixture did not exercise the elevated seventh-to-ninth player terrain')
 for _,owner in ipairs(owners) do players.PlayerRemoving:Fire(owner.pl) end
end)
specialCheck('new production owner still has one original drone and preserves the current map and systems',function()
 local pl,p=specialOwner();specialEq(preview,false);specialEq(#data(p).fleet,1);specialEq(#p.drones,1)
 specialEq(data(p).fleet[1].type,'Blue');specialEq(data(p).fleet[1].role,'Striker')
 assert(scene.fields[1].cfg.Key=='Quartz' and #scene.fields==#C.Fields)
 assert(scene.root==root and scene.map.Parent==root and scene.packStation.Parent)
 assert(Pro.validate(data(p),pl.UserId));publish(p)
 local view=http:JSONDecode(pl:GetAttribute('MA_Profile'));specialEq(view.storageCapacity,Logistics.CAPACITY)
end)
specialCheck('permanent miner purchase validates run context range ownership and exactly-once durable retry',function()
 local pl,p=specialOwner();local initial=#data(p).fleet;local wallet=data(p).run.wallet.Quartz
 specialInput(pl,p,'BuyDrone',{droneType='Bubbler',txId='stale-buy',runId='foreign-run'});specialEq(#data(p).fleet,initial)
 pl.Character:PivotTo(CFrame.new(patches[1].center));specialInput(pl,p,'BuyDrone','Bubbler');specialEq(#data(p).fleet,initial)
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)))
 runtimeStore.failAfter=1
 local d=specialBuy(pl,p,'Bubbler','lost-response-buy');specialEq(#data(p).fleet,initial+1)
 specialEq(data(p).run.wallet.Quartz,wallet-DroneCatalog.Types.Bubbler.Price)
 specialInput(pl,p,'BuyDrone',{droneType='Bubbler',txId='lost-response-buy',runId=data(p).run.id})
 specialEq(#data(p).fleet,initial+1);specialEq(#p.drones,initial+1);specialEq(d.id,data(p).fleet[initial+1].id)
 specialInput(pl,p,'BuyDrone',{droneType='Halver',txId='lost-response-buy',runId=data(p).run.id});specialEq(#data(p).fleet,initial+1)
end)
local function specialWaitForJob(d,afterSerial)
 for _=1,600 do
  if d.specialJob and (not afterSerial or d.specialJob.serial>afterSerial) then return d.specialJob end
  specialTicks(d,C.Tick)
 end
 error('Timed out waiting for specialist cycle')
end
local function specialUntil(d,at)
 while now+C.Tick<at-1e-7 do specialTicks(d,C.Tick) end
end
specialCheck('all seven miners extract from four authoritative chunks and retain their final yield bonus',function()
 for _,kind in ipairs(DroneCatalog.Order) do if kind~='Laser' then
  local pl,p=specialOwner();local d=specialBuy(pl,p,kind);local r=specialRock(p,d,'Crystal',210,11)
  local hp=r.hp;local before=pendingOre(p)
  specialTicks(d,.3);specialEq(r.hp,hp);assert(not d.specialJob)
  local previousSerial=0
  for cycle=1,4 do
   local earned=pendingOre(p)
   local job=specialWaitForJob(d,previousSerial)
   specialEq(job.serial,previousSerial+1);previousSerial=job.serial
   specialEq(r.part:GetAttribute('EffectType'),kind);specialEq(r.part:GetAttribute('EffectDrone'),d.id)
   assert(math.abs(job.duration-DroneCatalog.Types[kind].Duration)<1e-6)
   specialEq(r.part:GetAttribute('EffectImpact'),.68)
   specialUntil(d,job.startedAt+job.duration*job.impact)
   specialEq(r.hp,hp);specialEq(pendingOre(p),earned)
   specialTicks(d,C.Tick*2)
   specialEq(r.hp,hp-50);hp=r.hp
   assert(r.part:GetAttribute('EffectDoneAt')>=job.startedAt+job.duration*job.impact)
   specialEq(r.part:GetAttribute('EffectDepleted'),cycle==4)
   if cycle<4 then
    assert(not r.paid and d.specialJob==job and r.slots[d.id])
    specialEq(pendingOre(p)-before,Mining.extractedOre(11,r.stage,r.stageCount))
    local after=r.hp
    specialEq(hitResource(d,r,999999,false,nil,nil,'Special'),false)
    specialEq(r.hp,after)
    specialUntil(d,job.startedAt+job.duration)
    specialEq(r.hp,after);specialEq(d.specialJob,job)
   end
  end
  assert(r.paid and not d.specialJob)
  specialEq(pendingOre(p)-before,math.floor(11*DroneCatalog.Types[kind].Yield))
  assert(d.lingerUntil>=now,'final impact still has a recovery hold')
  specialEq(hitResource(d,r,20000,false,nil,nil,'Special'),false)
  specialEq(pendingOre(p)-before,math.floor(11*DroneCatalog.Types[kind].Yield))
 end end
end)
specialCheck('real fractional Ruby hardness finishes on its fourth chunk without an extra dust cycle',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Bubbler');local field=patches[2]
 data(p).run.shops.Ruby=true;data(p).run.shopLevels.quartz_ruby=1
 local ruby=Mining.resource(52,'Crystal',field.cfg.Hardness)
 local r=specialRock(p,d,'Crystal',ruby.maxHP,11,field)
 assert(math.abs(r.hp-226.8)<1e-10,'fixture must exercise fractional Ruby work')
 local serial=0
 for strike=1,4 do
  local job=specialWaitForJob(d,serial);serial=job.serial
  specialUntil(d,job.startedAt+job.duration*job.impact);specialTicks(d,C.Tick*2)
  if strike<4 then assert(not r.paid and r.hp>0) end
 end
 assert(r.paid and r.hp==0 and serial==4,'floating residue forced a fifth complete gesture')
 specialEq(r.part:GetAttribute('BreakSerial'),1)
end)
specialCheck('huge rocks retain a finite work budget and modifiers cannot bypass the final chunk cap',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Singularity');local r=specialRock(p,d,'Core',20010,11)
 local originalMultiplier=discoveries.Multiplier
 discoveries.Multiplier=function() return 1 end
 local job=specialWaitForJob(d);local hp=r.hp
 specialUntil(d,job.startedAt+job.duration*job.impact);specialTicks(d,C.Tick*2)
 assert(r.hp>hp*.99 and not r.paid,'huge rock was scaled away by percent-only damage')
 assert(math.abs(hp-r.hp-job.damage)<1e-6,'finite committed budget changed')
 local firstSerial=job.serial
 local nextJob=specialWaitForJob(d,firstSerial);hp=r.hp
 d.stats.geodeMultiplier=100000
 discoveries.Multiplier=function() return 100000 end
 specialUntil(d,nextJob.startedAt+nextJob.duration*nextJob.impact);specialTicks(d,C.Tick*2)
 assert(not r.paid);assert(math.abs(hp-r.hp-(r.maxHP-10)*.25)<1e-6,'modifier bypassed chunk cap')
 discoveries.Multiplier=originalMultiplier
end)
specialCheck('mining cards accelerate repeated cycles once and retain per-hit budget',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Gridcutter');local r=specialRock(p,d,'Crystal',10010,11)
 d.stats.miningDPS=d.owned.base.miningDPS*4
 local job=specialWaitForJob(d)
 assert(math.abs(job.duration-DroneCatalog.Types.Gridcutter.Duration/4)<1e-6)
 assert(math.abs(job.damage-d.owned.base.miningDPS*DroneCatalog.Types.Gridcutter.Duration*DroneCatalog.Types.Gridcutter.Power)<1e-6)
 local hp=r.hp;specialUntil(d,job.startedAt+job.duration*job.impact);specialTicks(d,C.Tick*2)
 assert(math.abs(hp-r.hp-job.damage)<1e-6,'mining card doubled both rate and hit budget')
end)
specialCheck('special mining requires authoritative overhead arrival and clear line of sight',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Bubbler');local r=specialRock(p,d)
 local hp=r.hp;d.pos=r.position+Vector3.new(4,6,5);specialTicks(d,C.Tick);assert(not d.specialJob);specialEq(r.hp,hp)
 d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize)
 local original=workspace.Raycast;workspace.Raycast=function() return {Instance=scene.packStation} end
 specialTicks(d,1.5);assert(not d.specialJob);specialEq(r.hp,hp);workspace.Raycast=original
end)
specialCheck('fresh line of sight at the impact defeats an otherwise cached clear work hold',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Bubbler');local r=specialRock(p,d,'Crystal',210,11)
 local job=specialWaitForJob(d);local hp=r.hp
 specialUntil(d,job.startedAt+job.duration*job.impact)
 d.specialQueryAt=now+10;d.specialClear=true
 local original=workspace.Raycast;workspace.Raycast=function() return {Instance=scene.packStation} end
 specialTicks(d,C.Tick*2)
 workspace.Raycast=original
 specialEq(r.hp,hp);assert(not d.specialJob and not r.slots[d.id])
 specialEq(r.part:GetAttribute('EffectCancelledSerial'),job.serial)
end)
specialCheck('recall cancels choreography without payout and releases its reservation',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Halver');local r=specialRock(p,d)
 local job=specialWaitForJob(d);local before=pendingOre(p)
 specialInput(pl,p,'Recall');assert(not d.target and not d.specialJob and not r.slots[d.id])
 specialEq(r.part:GetAttribute('EffectCancelledSerial'),job.serial);specialTicks(d,9)
 specialEq(r.paid,false);specialEq(pendingOre(p),before)
end)
specialCheck('yielding saves freeze anticipation and recovery without duplicating or skipping chunks',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Gridcutter');local r=specialRock(p,d,'Crystal',210,11)
 local job=specialWaitForJob(d);local started=job.startedAt;local hp=r.hp
 specialTicks(d,.2)
 p.busy=true;setMotionPaused(p,true);specialTicks(d,3)
 specialEq(r.hp,hp);specialEq(job.startedAt,started);assert(r.part:GetAttribute('EffectPausedAt')>0)
 p.busy=false;setMotionPaused(p,false)
 assert(math.abs(job.startedAt-started-3)<C.Tick*.1);specialEq(r.part:GetAttribute('EffectPausedAt'),0)
 specialUntil(d,job.startedAt+job.duration*job.impact);specialEq(r.hp,hp)
 specialTicks(d,C.Tick*2);specialEq(r.hp,hp-50);assert(job.impacted)
 local impactedAt=r.part:GetAttribute('EffectDoneAt');started=job.startedAt
 p.busy=true;setMotionPaused(p,true);specialTicks(d,4)
 specialEq(r.hp,hp-50);specialEq(d.specialJob,job)
 p.busy=false;setMotionPaused(p,false)
 assert(math.abs(job.startedAt-started-4)<C.Tick*.1)
 assert(math.abs(r.part:GetAttribute('EffectDoneAt')-impactedAt-4)<C.Tick*.1)
 specialUntil(d,job.startedAt+job.duration);specialEq(r.hp,hp-50)
 local nextJob=specialWaitForJob(d,job.serial);specialEq(nextJob.serial,job.serial+1)
 specialEq(r.hp,hp-50)
end)
specialCheck('yielding save freezes the lethal recovery without retaining damage authority or losing its source',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Halver');local r=specialRock(p,d,'Crystal',210,11)
 local serial=0
 for _=1,4 do
  local job=specialWaitForJob(d,serial);serial=job.serial
  specialUntil(d,job.startedAt+job.duration*job.impact);specialTicks(d,C.Tick*2)
 end
 assert(r.paid and not d.target and not d.specialJob and not r.slots[d.id])
 local recovery=assert(d.specialRecovery);local started=recovery.startedAt
 local impact=r.part:GetAttribute('EffectDoneAt');local removeAt=r.removeAt
 p.busy=true;setMotionPaused(p,true)
 local pausedAt=r.part:GetAttribute('EffectPausedAt');assert(pausedAt>0)
 specialTicks(d,3)
 -- Exercise actual snapshot cleanup after the normal two-second removal deadline.
 heartbeat:Fire(.11)
 assert(r.part.Parent and resources[r.id]==r and d.specialRecovery==recovery,'save removed a frozen final effect')
 specialEq(r.part:GetAttribute('EffectDoneAt'),impact)
 specialEq(r.part:GetAttribute('EffectStartedAt'),started)
 local elapsedPause=now-pausedAt
 p.busy=false;setMotionPaused(p,false)
 assert(math.abs(recovery.startedAt-started-elapsedPause)<1e-8)
 assert(math.abs(r.part:GetAttribute('EffectDoneAt')-impact-elapsedPause)<1e-8)
 assert(math.abs(r.removeAt-removeAt-elapsedPause)<1e-8)
 specialEq(r.part:GetAttribute('EffectPausedAt'),0)
 assert(r.removeAt>now and d.lingerUntil>now)
 specialEq(hitResource(d,r,999999,false,nil,nil,'Special'),false)
 specialEq(r.part:GetAttribute('BreakSerial'),1)
 release(d);assert(not d.specialRecovery);specialEq(r.part:GetAttribute('EffectPausedAt'),0)
end)
specialCheck('special workers use ordinary shared shell mining and cannot instantly remove geodes',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Singularity');local r=specialRock(p,d,'Geode',10000,0)
 local hp=r.hp;specialTicks(d,d.stats.warmup+.6);assert(r.hp<hp and not r.paid);assert(not d.specialJob)
 specialEq(r.part:GetAttribute('EffectType'),nil)
end)
local function specialState(p) return data(p).run.logistics end
local function specialRuntime(p,seconds)
 for _=1,math.ceil(seconds/.1) do
  specialClock(.1);logistics:tick(.1);recallFromField(p)
  for _,d in ipairs(p.drones) do droneStep(d,.1) end
 end
end
specialCheck('deposit stores typed ore and space launch pays its frozen manifest only after arrival',function()
 local pl,p=specialOwner();local cap=Logistics.CAPACITY
 data(p).run.cargo={Quartz=cap-20,Ruby=20};local quartz=data(p).run.wallet.Quartz;local ruby=data(p).run.wallet.Ruby
 pl.Character:PivotTo(CFrame.new(patches[4].center+Vector3.new(1000,0,0)))
 specialInput(pl,p,'Deposit');specialEq(Pro.cargoUnits(data(p)),cap);specialEq(Logistics.bagUnits(specialState(p).storage),0)
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));specialInput(pl,p,'Deposit')
 specialEq(Pro.cargoUnits(data(p)),0);specialEq(Logistics.bagUnits(specialState(p).storage),cap)
 specialEq(data(p).run.wallet.Quartz,quartz);specialEq(data(p).run.wallet.Ruby,ruby)
 runtimeStore.failAfter=1;specialInput(pl,p,'LaunchStorage')
 specialEq(Logistics.bagUnits(specialState(p).launchCargo),cap);specialEq(Logistics.bagUnits(specialState(p).storage),0)
 specialInput(pl,p,'LaunchStorage');specialEq(Logistics.bagUnits(specialState(p).launchCargo),cap)
 specialEq(logistics:deposit(p,'Cobalt',17),17);specialRuntime(p,5.7)
 specialEq(data(p).run.wallet.Quartz,quartz);specialEq(data(p).run.wallet.Ruby,ruby)
 runtimeStore.failAfter=1;specialRuntime(p,.5)
 specialEq(data(p).run.wallet.Quartz,quartz+cap-20);specialEq(data(p).run.wallet.Ruby,ruby+20)
 specialEq(specialState(p).storage.Cobalt,17);specialEq(data(p).logistics.launches,1)
 specialRuntime(p,1);specialEq(data(p).logistics.launches,1);specialEq(data(p).run.wallet.Ruby,ruby+20)
end)
specialCheck('carrier reward overflow stays typed and fills the next capsule without losing ore',function()
 local pl,p=specialOwner();local d=p.drones[1];local cap=Logistics.CAPACITY
 specialInput(pl,p,'AutoLaunch',false)
 specialEq(logistics:deposit(p,'Cobalt',cap-4),cap-4)
 local field=patches[1];local r=makeResource(field,field.center,'Crystal',100,13,3)
 d.deployedCarrier=true;award(d,r,false);d.deployedCarrier=false
 specialEq(Logistics.bagUnits(specialState(p).storage),cap);specialEq(specialState(p).pendingCargo.Quartz,9)
 specialRuntime(p,.2);specialEq(specialState(p).pendingCargo.Quartz,9)
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));specialInput(pl,p,'LaunchStorage');specialRuntime(p,.1)
 specialEq(specialState(p).storage.Quartz,9);specialEq(Logistics.bagUnits(specialState(p).pendingCargo),0)
 specialEq(Logistics.bagUnits(specialState(p).launchCargo)+Logistics.bagUnits(specialState(p).storage),cap+9)
end)
specialCheck('first full storage auto-launches and preserves refill during flight without a manual prerequisite',function()
 local pl,p=specialOwner();local cap=Logistics.CAPACITY
 specialEq(data(p).logistics.autoLaunch,true);specialEq(data(p).logistics.launches,0)
 logistics:deposit(p,'Quartz',cap);specialRuntime(p,.1);specialEq(Logistics.bagUnits(specialState(p).launchCargo),cap)
 logistics:deposit(p,'Ruby',cap);specialRuntime(p,6.2);specialEq(data(p).logistics.launches,1)
 specialEq(Logistics.bagUnits(specialState(p).launchCargo),cap);specialRuntime(p,6.2)
 specialEq(data(p).logistics.launches,2);specialEq(Logistics.bagUnits(specialState(p).launchCargo),0)
end)
specialCheck('manual launching can be selected before the first shipment and still requires the depot',function()
 local pl,p=specialOwner();local cap=Logistics.CAPACITY
 specialInput(pl,p,'AutoLaunch',false);specialEq(data(p).logistics.autoLaunch,false)
 logistics:deposit(p,'Quartz',cap);specialRuntime(p,7)
 specialEq(Logistics.bagUnits(specialState(p).storage),cap);specialEq(data(p).logistics.launches,0)
 pl.Character:PivotTo(CFrame.new(patches[4].center+Vector3.new(1000,0,0)))
 specialInput(pl,p,'AutoLaunch',true);specialEq(data(p).logistics.autoLaunch,false)
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));specialInput(pl,p,'AutoLaunch',true)
 specialRuntime(p,.1);specialEq(Logistics.bagUnits(specialState(p).launchCargo),cap)
end)
specialCheck('flying backpack reaches the owner before pickup and keeps cargo when storage fills',function()
 local pl,p=specialOwner();specialInput(pl,p,'BuyBackpack');assert(data(p).logistics.backpack)
 specialInput(pl,p,'AutoLaunch',false)
 local bagCap=Ca.capacity(data(p));local storageCap=Logistics.CAPACITY
 data(p).run.cargo={Quartz=bagCap-7,Ruby=7};specialState(p).storage={Quartz=storageCap-4}
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)));specialRuntime(p,.1)
 specialEq(Pro.cargoUnits(data(p)),bagCap);specialEq(Logistics.bagUnits(specialState(p).backpackCargo),0)
 for _=1,400 do if Logistics.bagUnits(specialState(p).backpackCargo)>0 then break end;specialRuntime(p,.1) end
 specialEq(Pro.cargoUnits(data(p)),0);specialEq(Logistics.bagUnits(specialState(p).backpackCargo),bagCap)
 for _=1,400 do if Logistics.bagUnits(specialState(p).storage)==storageCap then break end;specialRuntime(p,.1) end
 specialEq(Logistics.bagUnits(specialState(p).storage),storageCap);specialEq(Logistics.bagUnits(specialState(p).backpackCargo),bagCap-4)
 p.busy=true;local remaining=Logistics.bagUnits(specialState(p).backpackCargo);specialRuntime(p,1)
 specialEq(Logistics.bagUnits(specialState(p).backpackCargo),remaining);p.busy=false
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));specialInput(pl,p,'LaunchStorage');specialRuntime(p,1)
 specialEq(Logistics.bagUnits(specialState(p).backpackCargo),0);specialEq(Logistics.bagUnits(specialState(p).storage),bagCap-4)
end)
specialCheck('carrier rejects foreign invalid and guarded loads then deploys four owned miners after travel',function()
 local pl,p=specialOwner();specialInput(pl,p,'BuyCarrier');local carrier=assert(data(p).logistics.carriers[1])
 for index=1,4 do specialBuy(pl,p,'Frostbite','carrier-miner:'..index) end
 local ids={};for index=2,5 do ids[index-1]=p.drones[index].id end
 local function loaded() return data(p).logistics.carriers[1].droneIds end
 for _,invalid in ipairs({{ids[1],ids[1]},{'foreign:drone:1'},{[2]=ids[1]},{ids[1],ids[2],ids[3],ids[4],p.drones[1].id}}) do
  specialInput(pl,p,'LoadCarrier',{carrierId=carrier.id,droneIds=invalid});specialEq(#loaded(),0)
 end
 specialInput(pl,p,'LoadCarrier',{carrierId='foreign:carrier:1',droneIds=ids});specialEq(#loaded(),0)
 specialInput(pl,p,'LoadCarrier',{carrierId=carrier.id,droneIds=ids});specialEq(#loaded(),4)
 for _,id in ipairs(ids) do specialEq(drones[id].carrierId,carrier.id);droneStep(drones[id],C.Tick);specialEq(drones[id].state,'Docked') end
 pl.Character:PivotTo(CFrame.new(patches[3].center));specialInput(pl,p,'CarrierPatch',{carrierId=carrier.id,patch=3})
 specialEq(logistics:view(p)[carrier.id].state,'Home')
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(5000,0,0)));specialInput(pl,p,'CarrierPatch',{carrierId=carrier.id,patch=1})
 specialEq(logistics:view(p)[carrier.id].state,'Home')
 local field=patches[1];for _,r in ipairs(field.resources) do r.paid=true;r.hp=0 end
 for index=1,4 do local r=makeResource(field,field.center+Vector3.new((index-2.5)*9,0,0),'Crystal',800,10,3);r.readyAt=now end
 pl.Character:PivotTo(CFrame.new(field.center));specialInput(pl,p,'CarrierPatch',{carrierId=carrier.id,patch=1})
 specialEq(logistics:view(p)[carrier.id].state,'Travel')
 for _,id in ipairs(ids) do assert(not drones[id].deployedCarrier);assert(not drones[id].field) end
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)))
 for _=1,500 do if logistics:view(p)[carrier.id].state=='Working' then break end;specialRuntime(p,.1) end
 specialEq(logistics:view(p)[carrier.id].state,'Working')
 for _,id in ipairs(ids) do specialEq(drones[id].field,1);specialEq(drones[id].autoField,1);specialEq(drones[id].deployedCarrier,true) end
 -- Exercise the real owner leash while carrier jobs survive it.
 p.workField=1;recallFromField(p);assert(not p.workField)
 for _,id in ipairs(ids) do specialEq(drones[id].field,1) end
 local d=drones[ids[1]]
 for _=1,250 do if d.specialJob then break end;specialRuntime(p,.1) end
 local job=assert(d.specialJob);local started=job.startedAt;local serial=job.serial
 pl.Character:PivotTo(CFrame.new(field.center));specialInput(pl,p,'CarrierPatch',{carrierId=carrier.id,patch=1})
 specialEq(logistics:view(p)[carrier.id].state,'Working');specialEq(d.specialJob.serial,serial);specialEq(d.specialJob.startedAt,started)
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));pl.Character:FindFirstChildOfClass('Humanoid').Health=0
 local before=Logistics.bagUnits(specialState(p).storage);local target=d.target;local workBefore=target.hp
 specialRuntime(p,10)
 assert(target.hp<workBefore,'deployed miners stopped chunk work when owner left/died')
 for _=1,500 do if Logistics.bagUnits(specialState(p).storage)>before then break end;specialRuntime(p,.1) end
 assert(Logistics.bagUnits(specialState(p).storage)>before,'completed carrier mining did not reach storage')
 specialEq(Pro.cargoUnits(data(p)),0)
 -- Free reprints remain at home until a deliberate new deployment.
 kill(d);specialRuntime(p,.1);specialEq(d.deployedCarrier,false)
 assert(R.finishReprint(d,now+C.Reprint+C.Assembly,d.stats.maxHealth));droneStep(d,C.Tick)
 specialEq(d.deployedCarrier,false);specialEq(d.state,'Docked');assert(not d.field)
 assert((d.pos-home).Magnitude<20)
 pl.Character:FindFirstChildOfClass('Humanoid').Health=100
 specialInput(pl,p,'RecallCarrier',carrier.id)
 for _=1,500 do if logistics:view(p)[carrier.id].state=='Home' then break end;specialRuntime(p,.1) end
 specialEq(logistics:view(p)[carrier.id].state,'Home')
 for _,id in ipairs(ids) do assert(not drones[id].field and not drones[id].deployedCarrier) end
end)
specialCheck('busy or uncertain save sessions freeze launches deposits and transport commands',function()
 local pl,p=specialOwner();local cap=Logistics.CAPACITY
 specialState(p).storage={Quartz=cap};specialInput(pl,p,'LaunchStorage');specialRuntime(p,.5)
 local remaining=specialState(p).launchRemaining;local balance=data(p).run.wallet.Quartz
 p.busy=true;specialRuntime(p,2);specialEq(specialState(p).launchRemaining,remaining)
 specialInput(pl,p,'BuyCarrier');specialEq(#data(p).logistics.carriers,0);specialEq(logistics:deposit(p,'Ruby',3),0)
 p.busy=false;p.session.readOnly=true;specialRuntime(p,1);specialEq(specialState(p).launchRemaining,remaining)
 p.session.readOnly=false;p.session.lost=true;specialRuntime(p,1);specialEq(specialState(p).launchRemaining,remaining)
 p.session.lost=false;specialRuntime(p,6);specialEq(data(p).run.wallet.Quartz,balance+cap)
end)
specialCheck('reconnect preserves permanent types carriers loadout and typed in-flight manifests',function()
 local pl,p=specialOwner();local bought=specialBuy(pl,p,'Resonator','reconnect-special')
 specialInput(pl,p,'BuyCarrier');specialInput(pl,p,'BuyBackpack');local carrier=data(p).logistics.carriers[1]
 specialInput(pl,p,'LoadCarrier',{carrierId=carrier.id,droneIds={bought.id}})
 specialState(p).storage={Ruby=Logistics.CAPACITY};specialInput(pl,p,'LaunchStorage');specialRuntime(p,1)
 specialState(p).pendingCargo={Cobalt=9};specialState(p).backpackCargo={Emerald=3}
 local uid=pl.UserId;local id=bought.id;local ruby=data(p).run.wallet.Ruby
 players.PlayerRemoving:Fire(pl);specialEq(profiles[uid],nil)
 local replacement=player(uid);players.PlayerAdded:Fire(replacement);p=assert(profiles[uid])
 local found=false;for _,d in ipairs(p.drones) do if d.id==id then found=d.role=='Resonator';specialEq(d.carrierId,carrier.id) end end;assert(found)
 specialEq(data(p).logistics.backpack,true);specialEq(data(p).logistics.carriers[1].droneIds[1],id)
 specialEq(specialState(p).launchCargo.Ruby,Logistics.CAPACITY);specialEq(specialState(p).pendingCargo.Cobalt,9)
 specialEq(specialState(p).backpackCargo.Emerald,3);specialRuntime(p,6)
 specialEq(data(p).run.wallet.Ruby,ruby+Logistics.CAPACITY);specialEq(data(p).logistics.launches,1)
end)
specialCheck('a teammate finishing an unfinished special target grants ordinary yield and cancels its effect',function()
 local pl,p=specialOwner();local special=specialBuy(pl,p,'Bubbler');local target=specialRock(p,special,'Crystal',20000,11)
 local job=specialWaitForJob(special)
 local miner=p.drones[1];local primary=makeResource(patches[1],target.position+Vector3.new(4,0,0),'Crystal',1000,10,3);primary.readyAt=now
 assert(assignOre(p,miner,primary));miner.pos=Feel.mineGoal(primary.position,miner.targetSlot,false,primary.fullSize);miner.goal=miner.pos
 local before=pendingOre(p);specialEq(secondaryMining(miner,primary,99999,6),target.id)
 assert(target.paid and not special.specialJob and not special.target)
 specialEq(target.part:GetAttribute('EffectCancelledSerial'),job.serial);specialEq(target.part:GetAttribute('EffectType'),nil)
 specialEq(target.part:GetAttribute('EffectDoneAt'),0);specialEq(pendingOre(p)-before,11)
end)
print(specialChecks..' current production server special/logistics checks passed using API doubles')
