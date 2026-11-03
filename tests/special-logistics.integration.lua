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
local function specialRock(p,d,kind,hp,ore)
 local field=patches[1]
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
specialCheck('all seven special miners wait for startup and full timed work before one-shot reward',function()
 for _,kind in ipairs(DroneCatalog.Order) do if kind~='Laser' then
  local pl,p=specialOwner();local d=specialBuy(pl,p,kind);local r=specialRock(p,d,'Crystal',20000,11)
  local hp=r.hp;local before=pendingOre(p)
  specialTicks(d,.3);specialEq(r.hp,hp);assert(not d.specialJob)
  for _=1,180 do if d.specialJob then break end;specialTicks(d,C.Tick) end
  local job=assert(d.specialJob,'no '..kind..' work cycle');specialEq(r.hp,hp)
  specialEq(r.part:GetAttribute('EffectType'),kind);specialEq(r.part:GetAttribute('EffectDrone'),d.id)
  assert(math.abs(job.duration-DroneCatalog.Types[kind].Duration)<1e-6)
  while now+C.Tick<job.startedAt+job.duration-.001 do specialTicks(d,C.Tick) end
  specialEq(r.hp,hp);specialEq(pendingOre(p),before)
  specialTicks(d,.1);specialEq(r.paid,true);assert(r.part:GetAttribute('EffectDoneAt')>0)
  specialEq(pendingOre(p)-before,11*(DroneCatalog.Types[kind].Yield or 1))
  specialEq(hitResource(d,r,20000,false,nil,nil,'Special'),false)
  specialEq(pendingOre(p)-before,11*(DroneCatalog.Types[kind].Yield or 1));assert(not d.specialJob)
 end end
end)
specialCheck('special mining requires authoritative overhead arrival and clear line of sight',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Bubbler');local r=specialRock(p,d)
 local hp=r.hp;d.pos=r.position+Vector3.new(4,6,5);specialTicks(d,C.Tick);assert(not d.specialJob);specialEq(r.hp,hp)
 d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize)
 local original=workspace.Raycast;workspace.Raycast=function() return {Instance=scene.packStation} end
 specialTicks(d,1.5);assert(not d.specialJob);specialEq(r.hp,hp);workspace.Raycast=original
end)
specialCheck('recall cancels choreography without payout and releases its reservation',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Halver');local r=specialRock(p,d)
 specialTicks(d,1.2);local job=assert(d.specialJob);local before=pendingOre(p)
 specialInput(pl,p,'Recall');assert(not d.target and not d.specialJob and not r.slots[d.id])
 specialEq(r.part:GetAttribute('EffectCancelledSerial'),job.serial);specialTicks(d,9)
 specialEq(r.paid,false);specialEq(pendingOre(p),before)
end)
specialCheck('yielding save pauses authoritative special time and resumes the remaining work',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Gridcutter');local r=specialRock(p,d)
 specialTicks(d,1.2);local job=assert(d.specialJob);local started=job.startedAt
 p.busy=true;setMotionPaused(p,true);specialTicks(d,3)
 specialEq(r.paid,false);specialEq(job.startedAt,started);assert(r.part:GetAttribute('EffectPausedAt')>0)
 p.busy=false;setMotionPaused(p,false)
 assert(math.abs(job.startedAt-started-3)<C.Tick*.1);specialEq(r.part:GetAttribute('EffectPausedAt'),0)
 specialTicks(d,1);specialEq(r.paid,false)
 while not r.paid do specialTicks(d,C.Tick) end
 assert(r.part:GetAttribute('EffectDoneAt')>=job.startedAt+job.duration)
end)
specialCheck('special workers use ordinary shared shell mining and cannot instantly remove geodes',function()
 local pl,p=specialOwner();local d=specialBuy(pl,p,'Singularity');local r=specialRock(p,d,'Geode',10000,0)
 local hp=r.hp;specialTicks(d,1.4);assert(r.hp<hp and not r.paid);assert(not d.specialJob)
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
 specialEq(logistics:deposit(p,'Cobalt',cap-4),cap-4)
 local field=patches[1];local r=makeResource(field,field.center,'Crystal',100,13,3)
 d.deployedCarrier=true;award(d,r,false);d.deployedCarrier=false
 specialEq(Logistics.bagUnits(specialState(p).storage),cap);specialEq(specialState(p).pendingCargo.Quartz,9)
 specialRuntime(p,.2);specialEq(specialState(p).pendingCargo.Quartz,9)
 pl.Character:PivotTo(CFrame.new(home+Vector3.new(0,4,0)));specialInput(pl,p,'LaunchStorage');specialRuntime(p,.1)
 specialEq(specialState(p).storage.Quartz,9);specialEq(Logistics.bagUnits(specialState(p).pendingCargo),0)
 specialEq(Logistics.bagUnits(specialState(p).launchCargo)+Logistics.bagUnits(specialState(p).storage),cap+9)
end)
specialCheck('automatic launches unlock after the first manual shipment and preserve refill during flight',function()
 local pl,p=specialOwner();local cap=Logistics.CAPACITY
 specialInput(pl,p,'AutoLaunch',true);specialEq(data(p).logistics.autoLaunch,false)
 logistics:deposit(p,'Quartz',cap);specialInput(pl,p,'LaunchStorage');specialRuntime(p,6.2)
 specialEq(data(p).logistics.launches,1);specialInput(pl,p,'AutoLaunch',true);specialEq(data(p).logistics.autoLaunch,true)
 logistics:deposit(p,'Quartz',cap);specialRuntime(p,.1);specialEq(Logistics.bagUnits(specialState(p).launchCargo),cap)
 logistics:deposit(p,'Ruby',cap);specialRuntime(p,6.2);specialEq(data(p).logistics.launches,2)
 specialEq(Logistics.bagUnits(specialState(p).launchCargo),cap);specialRuntime(p,6.2)
 specialEq(data(p).logistics.launches,3);specialEq(Logistics.bagUnits(specialState(p).launchCargo),0)
end)
specialCheck('flying backpack reaches the owner before pickup and keeps cargo when storage fills',function()
 local pl,p=specialOwner();specialInput(pl,p,'BuyBackpack');assert(data(p).logistics.backpack)
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
 local before=Logistics.bagUnits(specialState(p).storage);specialRuntime(p,10)
 assert(Logistics.bagUnits(specialState(p).storage)>before,'deployed miners stopped when owner left/died')
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
 specialTicks(special,1.2);local job=assert(special.specialJob)
 local miner=p.drones[1];local primary=makeResource(patches[1],target.position+Vector3.new(4,0,0),'Crystal',1000,10,3);primary.readyAt=now
 assert(assignOre(p,miner,primary));miner.pos=Feel.mineGoal(primary.position,miner.targetSlot,false,primary.fullSize);miner.goal=miner.pos
 local before=pendingOre(p);specialEq(secondaryMining(miner,primary,99999,6),target.id)
 assert(target.paid and not special.specialJob and not special.target)
 specialEq(target.part:GetAttribute('EffectCancelledSerial'),job.serial);specialEq(target.part:GetAttribute('EffectType'),nil)
 specialEq(target.part:GetAttribute('EffectDoneAt'),0);specialEq(pendingOre(p)-before,11)
end)
print(specialChecks..' current production server special/logistics checks passed using API doubles')
