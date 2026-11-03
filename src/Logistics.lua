-- Typed mineral storage and permanent transport ownership for the existing game.
-- Currency changes use working-copy transactions; ordinary mining deposits are
-- non-yielding and become part of the next fenced profile save.
local L: any={CAPACITY=120,LAUNCH_SECONDS=6,CARRIER_PRICE=1500,BACKPACK_PRICE=750}
local materials={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local mineral={Quartz=true,Ruby=true,Cobalt=true,Violet=true,Emerald=true}
local miningRoles={Striker=true,Charger=true,Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local function integer(n: any): any return type(n)=='number' and n==n and n>=0 and n<1e14 and n%1==0 end
local function clone(t: any): any local out={};for k,v in pairs(t or {}) do out[k]=type(v)=='table' and clone(v) or v end;return out end
function L.bagUnits(bag: any): any local n=0;for _,v in pairs(bag or {}) do n+=v end;return n end
local function validBag(bag: any): any
 if type(bag)~='table' then return false end
 local total=0
 for k,v in pairs(bag) do if not mineral[k] or not integer(v) then return false end;total+=v;if not integer(total) then return false end end
 return true
end
local function take(bag: any, maximum: any): (any, any)
 local out,remaining={},maximum
 for _,key in ipairs(materials) do
  local n=math.min(remaining,bag[key] or 0)
  if n>0 then out[key]=n;bag[key]-=n;remaining-=n;if bag[key]==0 then bag[key]=nil end end
 end
 return out,maximum-remaining
end
local function add(bag: any, other: any): () for k,n in pairs(other) do bag[k]=(bag[k] or 0)+n end end
local function runState(p: any): any return p.run and p.run.logistics end
local function ownedState(p: any): any return p.logistics end
local function findCarrier(p: any, id: any): any
 for _,c in ipairs(p.logistics.carriers) do if c.id==id then return c end end
 return nil
end
local function permanent(p: any, id: any): any
 for _,d in ipairs(p.fleet or {}) do if d.id==id then return d end end
 return nil
end

function L.depositInto(p: any, bag: any, capacity: any): (any, any)
 local state=runState(p);capacity=capacity or L.CAPACITY
 if not state or not validBag(bag) or not integer(capacity) then return {},0 end
 local copy=clone(bag);local accepted,units=take(copy,math.max(0,capacity-L.bagUnits(state.storage)))
 add(state.storage,accepted);return accepted,units
end
function L.depositMineral(p: any, key: any, amount: any, capacity: any): any
 if not mineral[key] or not integer(amount) then return 0 end
 local _,accepted=L.depositInto(p,{[key]=amount},capacity);return accepted
end
function L.beginLaunch(p: any, capacity: any): (any, any)
 local state=runState(p);capacity=capacity or L.CAPACITY
 if not state or not integer(capacity) or capacity<1 then return false,'Storage unavailable' end
 if L.bagUnits(state.launchCargo)>0 then return false,'A cargo capsule is already in flight' end
 if L.bagUnits(state.storage)<capacity then return false,'Fill storage before launching' end
 state.launchCargo=take(state.storage,capacity);state.launchRemaining=L.LAUNCH_SECONDS
 return true,{units=capacity,runId=p.run.id,launch=p.logistics.launches+1}
end
function L.finishLaunch(p: any, values: any): (any, any)
 local state=runState(p)
 if not state or L.bagUnits(state.launchCargo)==0 then return false,'No launch is pending' end
 if state.launchRemaining>0 then return false,'Cargo capsule is still in flight' end
 local units,earnings=L.bagUnits(state.launchCargo),0
 for key,n in pairs(state.launchCargo) do
  local value=values and values[key] or 1
  if not mineral[key] or not integer(n) or not integer(p.run.wallet[key]+n) or type(value)~='number' or value<0 or value~=value then return false,'Invalid launch manifest' end
  earnings+=n*value
 end
 earnings=math.floor(earnings)
 if not integer(earnings) or not integer(p.run.saleEarnings+earnings) then return false,'Launch earnings limit reached' end
 local manifest=clone(state.launchCargo)
 add(p.run.wallet,manifest);p.run.credits=p.run.wallet.Quartz;p.run.saleEarnings+=earnings
 state.launchCargo={};state.launchRemaining=0;p.logistics.launches+=1
 return true,{units=units,earnings=earnings,cargo=manifest,runId=p.run.id,launch=p.logistics.launches}
end
function L.pickupBackpack(p: any, capacity: any): (any, any)
 local state=runState(p)
 if not state or not p.logistics.backpack or not integer(capacity) or capacity<1 then return false,'Flying backpack unavailable' end
 if L.bagUnits(state.backpackCargo)>0 then return false,'Flying backpack is still carrying cargo' end
 if L.bagUnits(p.run.cargo)<capacity then return false,'Backpack is not full yet' end
 state.backpackCargo=take(p.run.cargo,capacity)
 return true,{units=L.bagUnits(state.backpackCargo),runId=p.run.id}
end
function L.deliverBackpack(p: any, capacity: any): any
 local state=runState(p);if not state then return 0 end
 local accepted,units=L.depositInto(p,state.backpackCargo,capacity)
 for key,n in pairs(accepted) do state.backpackCargo[key]-=n;if state.backpackCargo[key]==0 then state.backpackCargo[key]=nil end end
 return units
end
function L.buy(p: any, kind: any): (any, any)
 if not ownedState(p) then return false,'Transport ownership unavailable' end
 local price=kind=='Carrier' and L.CARRIER_PRICE or (kind=='Backpack' and L.BACKPACK_PRICE or nil)
 if not price then return false,'Unknown transport' end
 if kind=='Carrier' and #p.logistics.carriers>=3 then return false,'Carrier limit reached: three carriers' end
 if kind=='Backpack' and p.logistics.backpack then return false,'You already own a flying backpack' end
 if p.run.wallet.Quartz<price then return false,'Need '..price..' Quartz' end
 p.run.wallet.Quartz-=price;p.run.credits=p.run.wallet.Quartz
 if kind=='Backpack' then p.logistics.backpack=true;return true,{kind=kind,price=price} end
 local id=tostring(p.userId)..':carrier:'..p.logistics.nextCarrier;p.logistics.nextCarrier+=1
 table.insert(p.logistics.carriers,{id=id,droneIds={}})
 return true,{kind=kind,id=id,price=price}
end
function L.loadCarrier(p: any, id: any, ids: any): (any, any)
 if type(id)~='string' or type(ids)~='table' then return false,'Invalid loadout' end
 local c=findCarrier(p,id);if not c then return false,'Unknown carrier' end
 local count=0;for k in pairs(ids) do if type(k)~='number' or k%1~=0 or k<1 or k>4 then return false,'A carrier holds at most four miners' end;count+=1 end
 local selected={}
 for i=1,count do
  local key=ids[i];local d=type(key)=='string' and permanent(p,key)
  if not d or selected[key] then return false,'Select distinct owned permanent miners' end
  if not miningRoles[d.role] then return false,'Carriers deploy mining drones' end
  for _,other in ipairs(p.logistics.carriers) do if other.id~=id and table.find(other.droneIds,key) then return false,'Unload that miner from its other carrier first' end end
  selected[key]=true
 end
 c.droneIds=clone(ids);return true,{id=id,count=count}
end

function L.new(ctx: any): any
 local system: any={};local runtime: any,slots: any={},{}
 local C,W=ctx.C,ctx.W
 local capacity=C.StorageCapacity or L.CAPACITY
 local function profile(p: any): any return ctx.data(p) end
 local function canDeploy(p: any, field: any): any
  if not field then return false end
  if ctx.canDeploy then return ctx.canDeploy(p,field) end
  if ctx.canMine then return ctx.canMine(p,field) end
  local saved=profile(p)
  local unlocked=field.cfg.AlwaysUnlocked or not ctx.Shops or ctx.Shops.unlocked(saved,field.cfg.Key)
  return unlocked and (field.cfg.Turrets==0 or field.e.phase=='Cleared' or saved.clearedFields[field.cfg.Key]==true)
 end
 local function healthy(p: any): any
  if ctx.healthy then return ctx.healthy(p) end
  return not p.busy and not p.leaving
 end
 local function hr(p: any): any return ctx.characterRoot and ctx.characterRoot(p) or nil end
 local function announce(p: any, text: any): () if ctx.notice then ctx.notice(p,text) else p.player:SetAttribute('MA_Notice',text) end end
 local function dirty(p: any): () p.dirty=true;p.publishDirty=true end
 local function model(name: any, owner: any, class: any): any
  local m=Instance.new('Model');m.Name=name;m:SetAttribute('Owner',owner);m:SetAttribute('Class',class);m.Parent=ctx.root;return m
 end
 local function v(x: any, y: any, z: any): any return Vector3.new(x,y,z) end
 local ink=Color3.fromRGB(31,43,52);local gold=Color3.fromRGB(255,195,75);local cyan=Color3.fromRGB(95,226,222);local pale=Color3.fromRGB(218,233,221)
 local function part(m: any, name: any, pos: any, size: any, color: any, mat: any): any return W.part(m,name,pos,size,color,mat or Enum.Material.SmoothPlastic) end
 local function move(m: any, pos: any, force: any?): ()
  local now=ctx.getClock()
  if not force and now-(m:GetAttribute('PoseAt') or -math.huge)<.1 then return end
  local cf=CFrame.new(pos)
  local moving=m:GetAttribute('Pose')~=cf
  if not force and not moving and m:GetAttribute('PoseMoving')~=true then return end
  -- One final stationary sample cancels prediction after arrival.
  if moving then m:PivotTo(cf);m:SetAttribute('Pose',cf) end
  m:SetAttribute('PoseMoving',moving);m:SetAttribute('PoseAt',now)
 end
 local function approach(pos: any, goal: any, dt: any, speed: any): (any, any)
  local delta=goal-pos;local n=delta.Magnitude;if n<.001 then return goal,true end
  local step=math.min(n,dt*speed);return pos+delta/n*step,n<=step+.15
 end
 local function carrierAttrs(c: any): ()
  for _,target in ipairs({c.model,c.metadata}) do
   target:SetAttribute('State',c.state);target:SetAttribute('Patch',c.field or 0);target:SetAttribute('FieldId',c.field or 0)
   target:SetAttribute('LoadedIds',table.concat(c.ids,','));target:SetAttribute('LoadedCount',#c.ids)
  end
 end
 local function makeCarrier(p: any, rt: any, saved: any): any
  local at=rt.base+v(-8,6,-7);local m=model('Carrier_'..saved.id,p.player.UserId,'Carrier')
  local body=part(m,'Frame',at,v(8.5,.75,7),ink,Enum.Material.Metal);m.PrimaryPart=body
  part(m,'Spine',at+v(0,.5,0),v(.8,1.2,7.8),gold,Enum.Material.Metal)
  for i=1,4 do
   local x=i%2==1 and -2.6 or 2.6;local z=i<=2 and -2 or 2
   part(m,'Bay'..i,at+v(x,.6,z),v(2.4,.2,2.4),cyan,Enum.Material.Neon)
   part(m,'Engine'..i,at+v(x*1.45,-.25,z),v(1.1,1.2,1.2),gold,Enum.Material.Metal)
   part(m,'Jet'..i,at+v(x*1.45,-1,z),v(.7,.5,.8),cyan,Enum.Material.Neon)
  end
  m:SetAttribute('CarrierId',saved.id);m:SetAttribute('Capacity',4)
  local meta=Instance.new('Folder');meta.Name=saved.id;meta:SetAttribute('CarrierId',saved.id);meta:SetAttribute('Owner',p.player.UserId);meta:SetAttribute('Class','Carrier');meta.Parent=rt.metadata
  local c={id=saved.id,model=m,metadata=meta,pos=at,state='Home',ids=clone(saved.droneIds),field=nil,lives={},dead={}}
  rt.carriers[c.id]=c;carrierAttrs(c);move(m,at);return c
 end
 local function makeBackpack(p: any, rt: any): ()
  local at=rt.base+v(6,5,0);local m=model('FlyingBackpack_'..p.player.UserId,p.player.UserId,'Backpack')
  local body=part(m,'Pack',at,v(2.1,2.6,1.25),gold,Enum.Material.Metal);m.PrimaryPart=body
  part(m,'Pocket',at+v(0,-.35,-.8),v(1.7,1.1,.45),ink)
  for _,s in ipairs({-1,1}) do
   part(m,'Strap',at+v(s*.65,0,.75),v(.2,2.1,.2),pale)
   part(m,'Thruster',at+v(s*1.2,-.65,0),v(.5,.7,.65),ink,Enum.Material.Metal)
   part(m,'Jet',at+v(s*1.2,-1.15,0),v(.32,.45,.4),cyan,Enum.Material.Neon)
  end
  rt.backpack={model=m,pos=at,state='Follow'};move(m,at)
 end
 local function request(p: any, label: any, mutate: any, after: any?, fixedId: any?): any
  if not healthy(p) or not ctx.transact then return false end
  local runId=profile(p).run.id
  local id=fixedId or ('logistics:'..label..':'..ctx.guid())
  return ctx.transact(p,id,function(copy: any): (any, any)
   if copy.run.id~=runId then return nil,'Run changed' end
   local ok,result=mutate(copy)
   if not ok then return nil,result end
   return result or {runId=runId},nil
  end,function(result: any)
   system:refresh(p);if after then after(result) end;p.publishDirty=true
  end)
 end
 local function returnCarrier(p: any, c: any): ()
  for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==p.player.UserId then ctx.recall(d);d.deployedCarrier=false end end
  c.field=nil;c.state='Return';c.lives={};carrierAttrs(c)
 end
 function system:create(p: any): ()
  if runtime[p.player.UserId] then self:refresh(p);return end
  local slot=1;while slots[slot] do slot+=1 end;slots[slot]=p.player.UserId
  -- A compact pad joins the depot's existing ground; existing map geometry stays intact.
  local base=ctx.origin+v(((slot-1)%3-1)*21,0,-26-math.floor((slot-1)/3)*21)
  local function groundAt(x: any, z: any): any
   return ctx.groundHeight and ctx.groundHeight(x,z) or ctx.origin.Y-.5
  end
  -- Later player pads extend onto the existing hills. Level the entire pad
  -- above its highest footprint sample without cutting into authored terrain.
  local baseY=ctx.origin.Y
  for _,x in ipairs({-9,0,9}) do
   for _,z in ipairs({-9,0,9}) do baseY=math.max(baseY,groundAt(base.X+x,base.Z+z)+.5) end
  end
  base=v(base.X,baseY,base.Z)
  local rt={base=base,slot=slot,carriers={},runId=profile(p).run.id,nextPublish=0}
  runtime[p.player.UserId]=rt
  local metadata=Instance.new('Folder');metadata.Name='MA_Logistics';metadata.Parent=p.player;rt.metadata=metadata
  local building=model('OrbitalStorage_'..p.player.UserId,p.player.UserId,'Storage');rt.building=building
  local pad=part(building,'LaunchPad',base,v(18,1,18),ink,Enum.Material.Metal);pad.CanCollide=true;pad.CanQuery=true;building.PrimaryPart=pad
  for _,x in ipairs({-7.5,7.5}) do
   for _,z in ipairs({-7.5,7.5}) do
    local ground=groundAt(base.X+x,base.Z+z);local height=base.Y-.5-ground
    if height>.2 then
     local support=part(building,'FoundationSupport',v(base.X+x,ground+height/2,base.Z+z),v(1.2,height,1.2),ink,Enum.Material.Metal)
     support.CanCollide=true;support.CanQuery=true
    end
   end
  end
  for _,s in ipairs({-1,1}) do
   part(building,'Gantry',base+v(s*5.5,4.5,-6),v(.5,8,.5),gold,Enum.Material.Metal)
   part(building,'Signal',base+v(s*5.5,8.8,-6),v(.7,.7,.7),cyan,Enum.Material.Neon)
  end
  part(building,'Crossbar',base+v(0,8.4,-6),v(11,.5,.5),ink,Enum.Material.Metal)
  rt.label=W.label(pad,'ORBITAL STORAGE',v(0,10,0));rt.label.Parent.MaxDistance=42
  local cm=model('LaunchCapsule_'..p.player.UserId,p.player.UserId,'Capsule');rt.capsule=cm;rt.capsuleBase=base+v(0,3.7,0)
  local body=part(cm,'CargoPod',rt.capsuleBase,v(4.4,5,4.4),pale,Enum.Material.Metal);cm.PrimaryPart=body
  local nose=part(cm,'Nose',rt.capsuleBase+v(0,2.6,0),v(4.4,4.4,4.4),gold,Enum.Material.Metal);nose.Shape=Enum.PartType.Ball
  rt.jet=part(cm,'Exhaust',rt.capsuleBase+v(0,-3.7,0),v(2,3,2),cyan,Enum.Material.Neon);rt.jet.Transparency=1
  move(cm,rt.capsuleBase)
  for _,entry in ipairs({{'Deposit','Deposit cargo',Enum.KeyCode.E},{'LaunchStorage','Launch full storage',Enum.KeyCode.F}}) do
   local prompt=Instance.new('ProximityPrompt');prompt.Name=entry[1];prompt.ActionText=entry[2];prompt.ObjectText='Orbital storage';prompt.KeyboardKeyCode=entry[3];prompt.MaxActivationDistance=14;prompt.RequiresLineOfSight=false;prompt.Parent=pad
   if prompt.Triggered then prompt.Triggered:Connect(function(who: any) if who==p.player then self:command(p,entry[1]) end end) end
  end
  self:refresh(p)
 end
 function system:refresh(p: any): ()
  local rt=runtime[p.player.UserId];if not rt then return end
  local saved=profile(p);local current={}
  if rt.runId~=saved.run.id then
   rt.runId=saved.run.id
   for _,c in pairs(rt.carriers) do returnCarrier(p,c);c.state='Home';c.pos=rt.base+v(-8,6,-7);c.dead={} end
  end
  for _,record in ipairs(saved.logistics.carriers) do
   local c=rt.carriers[record.id] or makeCarrier(p,rt,record)
   local same=#c.ids==#record.droneIds
   if same then for i,id in ipairs(c.ids) do if record.droneIds[i]~=id then same=false;break end end end
   if not same then
    for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==p.player.UserId then d.carrierId=nil;d.deployedCarrier=false end end
    c.ids=clone(record.droneIds);c.dead={}
   end
   current[c.id]=true
   for _,id in ipairs(c.ids) do
    local d=ctx.drones[id]
    if d and d.owner==p.player.UserId then d.carrierId=c.id;if c.state~='Working' or c.dead[id] then d.deployedCarrier=false end end
   end
   carrierAttrs(c)
  end
  for id,c in pairs(rt.carriers) do if not current[id] then c.model:Destroy();c.metadata:Destroy();rt.carriers[id]=nil end end
  if saved.logistics.backpack and not rt.backpack then makeBackpack(p,rt) end
  if not saved.logistics.backpack and rt.backpack then rt.backpack.model:Destroy();rt.backpack=nil end
  p.publishDirty=true
 end
 function system:capacity(p: any): any return math.max(0,capacity-L.bagUnits(profile(p).run.logistics.storage)) end
 function system:storagePosition(p: any): any local rt=runtime[p.player.UserId];return rt and rt.base+v(6,4,0) or ctx.origin end
 function system:deposit(p: any, key: any, amount: any): (any, any)
  if not healthy(p) then return 0,nil end
  if type(key)=='table' then local bag,n=L.depositInto(profile(p),key,capacity);if n>0 then dirty(p) end;return bag,n end
  local n=L.depositMineral(profile(p),key,amount,capacity);if n>0 then dirty(p) end;return n,nil
 end
 function system:station(d: any): any
  if not d.carrierId then return nil end
  local rt=runtime[d.owner];local c=rt and rt.carriers[d.carrierId]
  if not c then d.carrierId=nil;d.deployedCarrier=false;return nil end
  if c.dead[d.id] then d.deployedCarrier=false;return ctx.origin+v(0,7,0) end
  if d.deployedCarrier and c.state=='Working' and d.field==c.field and c.lives[d.id]==d.life then return nil end
  d.deployedCarrier=false
  for i,id in ipairs(c.ids) do if id==d.id then return c.pos+v(i%2==1 and -2.6 or 2.6,2,i<=2 and -2 or 2) end end
  d.carrierId=nil;return nil
 end
 function system:atHome(d: any): any
  local rt=runtime[d.owner];local c=rt and d.carrierId and rt.carriers[d.carrierId]
  return c~=nil and (c.state=='Home' or c.dead[d.id]==true)
 end
 function system:view(p: any): any
  local rt=runtime[p.player.UserId];local out={}
  for id,c in pairs(rt and rt.carriers or {}) do out[id]={state=c.state,field=c.field or 0,droneIds=clone(c.ids)} end
  return out
 end
 function system:decorate(p: any): any
  local saved=profile(p);local s=saved.run.logistics
  return {Storage=L.bagUnits(s.storage),StorageCapacity=capacity,LaunchCargo=L.bagUnits(s.launchCargo),LaunchRemaining=s.launchRemaining,BackpackCargo=L.bagUnits(s.backpackCargo),HasBackpack=saved.logistics.backpack,Carriers=#saved.logistics.carriers,CarrierCount=#saved.logistics.carriers,AutoLaunch=saved.logistics.autoLaunch,Launches=saved.logistics.launches}
 end
 function system:save(p: any): any return clone(profile(p).run.logistics) end
 function system:remove(p: any): ()
  local rt=runtime[p.player.UserId];if not rt then return end
  for _,c in pairs(rt.carriers) do
   for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==p.player.UserId then d.carrierId=nil;d.deployedCarrier=false end end
   c.model:Destroy()
  end
  if rt.backpack then rt.backpack.model:Destroy() end
  rt.building:Destroy();rt.capsule:Destroy();rt.metadata:Destroy();slots[rt.slot]=nil;runtime[p.player.UserId]=nil
 end
 function system:command(p: any, action: any, value: any): any
  local rt=runtime[p.player.UserId]
  if not rt or not healthy(p) or not hr(p) then return false end
  local saved=profile(p);local state=saved.run.logistics
  local function reject(text: any): any announce(p,text);return true end
  local function nearStorage(): any
   return ctx.inHome(p) or (ctx.atDepotStation and ctx.atDepotStation(p)) or (hr(p).Position-rt.base).Magnitude<22
  end
  if action=='BuyCarrier' or action=='BuyBackpack' then
   if value~=nil then return true end
   if not ctx.inHome(p) then return reject('Return to the depot to buy transport.') end
   local kind=action=='BuyCarrier' and 'Carrier' or 'Backpack'
   request(p,'buy'..kind,function(copy: any) return L.buy(copy,kind) end,function() announce(p,kind=='Carrier' and 'Carrier ready. Load up to four permanent miners at the depot.' or 'Flying backpack ready. It collects your full bag and returns it to storage.') end)
  elseif action=='Deposit' or action=='Sell' then
   if value~=nil then return true end
   if not nearStorage() then return reject('Return to your storage or the depot to deposit cargo.') end
   if L.bagUnits(saved.run.cargo)==0 then return reject('Your backpack is empty.') end
   if self:capacity(p)==0 then return reject('Storage is full. Launch its cargo before depositing more.') end
   request(p,'deposit',function(copy: any)
    local accepted,n=L.depositInto(copy,copy.run.cargo,capacity)
    for k,units in pairs(accepted) do copy.run.cargo[k]-=units;if copy.run.cargo[k]==0 then copy.run.cargo[k]=nil end end
    return n>0,{units=n}
   end,function(result: any) announce(p,'Deposited '..result.units..' ore. Full storage can launch into space.') end)
  elseif action=='LaunchStorage' then
   if value~=nil then return true end
   if not nearStorage() then return reject('Return to your storage or the depot to launch cargo.') end
   if L.bagUnits(state.launchCargo)>0 then return reject('A cargo capsule is already in flight.') end
   if L.bagUnits(state.storage)<capacity then return reject('Fill storage before launching: '..L.bagUnits(state.storage)..' / '..capacity..'.') end
   request(p,'launch',function(copy: any) return L.beginLaunch(copy,capacity) end,function() rt.capsule:SetAttribute('LaunchedAt',ctx.getClock());announce(p,'Cargo launched. Its minerals enter their matching shop balances in space.') end)
  elseif action=='AutoLaunch' then
   if type(value)~='boolean' then return true end
   if not ctx.inHome(p) then return reject('Return to the depot to change automatic launching.') end
   if saved.logistics.launches==0 then return reject('Complete one manual storage launch to unlock automatic launching.') end
   request(p,'auto',function(copy: any) copy.logistics.autoLaunch=value;return true,{enabled=value} end,function() announce(p,value and 'Automatic storage launching enabled.' or 'Automatic storage launching disabled.') end)
  elseif action=='LoadCarrier' then
   if type(value)~='table' or type(value.carrierId)~='string' or type(value.droneIds)~='table' then return true end
   local c=rt.carriers[value.carrierId];if not c then return true end
   local check=clone(saved);local ok,reason=L.loadCarrier(check,value.carrierId,value.droneIds)
   if not ok then return reject(reason) end
   if not ctx.inHome(p) then return reject('Return to the depot to change a carrier loadout.') end
   if c.state~='Home' then return reject('Recall this carrier and wait for it to reach the depot first.') end
   for _,id in ipairs(value.droneIds) do local d=ctx.drones[id];if not d or d.hp<=0 or d.field then return reject('Recall the selected miners and wait for any reprints before loading.') end end
   local ids=clone(value.droneIds);local id=value.carrierId
   request(p,'load',function(copy: any) return L.loadCarrier(copy,id,ids) end,function() c.dead={};announce(p,'Carrier loadout saved: '..#ids..' / 4 miners.') end)
  elseif action=='CarrierPatch' then
   if type(value)~='table' or type(value.carrierId)~='string' or type(value.patch)~='number' or value.patch%1~=0 then return true end
   local c=rt.carriers[value.carrierId];local field=ctx.patches[value.patch];if not c or not field then return true end
   if c.state=='Working' and c.field==field.id then return reject('This carrier is already working that field.') end
   if #c.ids==0 then return reject('Load up to four permanent miners into this carrier at the depot.') end
   if (hr(p).Position-field.center).Magnitude>(C.CommandRadius or 95) then return reject('Walk closer to the field before dispatching the carrier.') end
   if c.state~='Home' and c.state~='Working' then return reject('The carrier is still travelling. Wait until it arrives or returns home.') end
   if not canDeploy(p,field) then return reject('Unlock this field and clear its guards before sending a carrier.') end
   returnCarrier(p,c);c.field=field.id;c.state='Travel';c.dead={};carrierAttrs(c);announce(p,'Carrier dispatched. Its miners deploy on arrival and keep working when you leave.')
  elseif action=='RecallCarrier' then
   if type(value)~='string' then return true end
   local c=rt.carriers[value];if c then returnCarrier(p,c);announce(p,'Carrier returning to the depot.') end
  else return false end
  return true
 end
 function system:tick(dt: any): ()
  for owner,rt in pairs(runtime) do
   local p=ctx.profiles[owner]
   if p and healthy(p) then
    local saved=profile(p);if rt.runId~=saved.run.id then self:refresh(p);saved=profile(p) end
    local state=saved.run.logistics;local now=ctx.getClock()
    if self:capacity(p)>0 and L.bagUnits(state.pendingCargo)>0 then
     local accepted,n=L.depositInto(saved,state.pendingCargo,capacity)
     for k,units in pairs(accepted) do state.pendingCargo[k]-=units;if state.pendingCargo[k]==0 then state.pendingCargo[k]=nil end end
     if n>0 then dirty(p) end
    end
    if L.bagUnits(state.launchCargo)>0 then
     state.launchRemaining=math.max(0,state.launchRemaining-dt);p.dirty=true
     local t=1-state.launchRemaining/L.LAUNCH_SECONDS
     move(rt.capsule,rt.capsuleBase+v(0,t*t*240,0));rt.jet.Transparency=.15
     rt.capsule:SetAttribute('Manifest',L.bagUnits(state.launchCargo))
     if state.launchRemaining==0 then
      if request(p,'launchFinish',function(copy: any) return L.finishLaunch(copy,ctx.prices) end,function() rt.jet.Transparency=1;rt.capsule:SetAttribute('Manifest',0);move(rt.capsule,rt.capsuleBase,true);announce(p,'Cargo reached space. Matching mineral balances credited.') end,'logisticsPay:'..saved.run.id..':'..(saved.logistics.launches+1)) then continue end
     end
    else rt.jet.Transparency=1;rt.capsule:SetAttribute('Manifest',0);move(rt.capsule,rt.capsuleBase) end
    if healthy(p) and saved.logistics.autoLaunch and saved.logistics.launches>0 and L.bagUnits(state.launchCargo)==0 and L.bagUnits(state.storage)>=capacity then
     if request(p,'autoLaunch',function(copy: any) return L.beginLaunch(copy,capacity) end,function() rt.capsule:SetAttribute('LaunchedAt',ctx.getClock()) end) then continue end
    end
    local bp=rt.backpack
    if healthy(p) and bp then
     local playerRoot=hr(p);local cargo=L.bagUnits(state.backpackCargo);local full=L.bagUnits(saved.run.cargo)>=(ctx.capacityOf and ctx.capacityOf(saved) or C.Capacity)
     local goal
     if cargo>0 then goal=self:storagePosition(p);bp.state=self:capacity(p)>0 and 'Deliver' or 'StorageFull'
     else goal=(playerRoot and playerRoot.Position or ctx.origin)+v(3,5,3);bp.state=full and 'Collect' or 'Follow' end
     local arrived;bp.pos,arrived=approach(bp.pos,goal,dt,30);move(bp.model,bp.pos);bp.model:SetAttribute('State',bp.state);bp.model:SetAttribute('Cargo',cargo)
     if arrived and cargo>0 and self:capacity(p)>0 then
      if request(p,'backpackDeliver',function(copy: any) local n=L.deliverBackpack(copy,capacity);return n>0,{units=n} end) then continue end
     elseif arrived and cargo==0 and full and playerRoot then
      if request(p,'backpackCollect',function(copy: any) return L.pickupBackpack(copy,ctx.capacityOf and ctx.capacityOf(copy) or C.Capacity) end) then continue end
     end
    end
    for _,c in pairs(rt.carriers) do
     for _,id in ipairs(c.ids) do
      local d=ctx.drones[id]
      if d and (d.hp<=0 or (c.lives[id] and c.lives[id]~=d.life)) then c.dead[id]=true;d.deployedCarrier=false end
     end
     if c.state=='Travel' then
      local field=c.field and ctx.patches[c.field]
      if not field then returnCarrier(p,c)
      else
       local arrived;c.pos,arrived=approach(c.pos,field.center+v(0,15,12),dt,25)
       if arrived then
        local fleet={}
        for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==owner and d.hp>0 and not c.dead[id] then table.insert(fleet,d) end end
        if #fleet>0 and ctx.assignFleet(p,field,fleet) then
         c.state='Working';for _,d in ipairs(fleet) do d.deployedCarrier=true;c.lives[d.id]=d.life end
        else returnCarrier(p,c);announce(p,'Carrier returned: unlock the field and clear its guards before deployment.') end
       end
      end
     elseif c.state=='Return' then
      local arrived;c.pos,arrived=approach(c.pos,rt.base+v(-8,6,-7),dt,25)
      if arrived then c.state='Home';c.dead={} end
     elseif c.state=='Working' and not canDeploy(p,ctx.patches[c.field]) then returnCarrier(p,c) end
     carrierAttrs(c);move(c.model,c.pos)
    end
    if now>=rt.nextPublish then
     rt.nextPublish=now+.25
     if state.launchRemaining>0 then p.publishDirty=true end
     rt.label.Text=string.format('ORBITAL STORAGE\n%d / %d%s',L.bagUnits(state.storage),capacity,L.bagUnits(state.launchCargo)>0 and ' · IN FLIGHT' or '')
     for _,piece in ipairs(rt.building:GetChildren()) do if piece.Name=='Signal' then piece.Color=L.bagUnits(state.storage)>=capacity and gold or cyan end end
     for key,value in pairs(self:decorate(p)) do p.player:SetAttribute('MA_'..key,value) end
    end
   end
  end
 end
 return system
end
return L
