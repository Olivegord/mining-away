-- Actual bundled server/API doubles; not engine/network playtesting.
local checks=0
RoleEffects.Ability=function() end;RoleEffects.ClearAbility=function() end;discoveries.TrySpawn=function() end
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS pickups server '..name) end
local uid=98000
local function fixture()
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=profiles[uid]
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 local r=makeResource(patches[1],patches[1].center,'Crystal',100,10,3);r.readyAt=now
 local d=p.drones[1];d.pos=Feel.mineGoal(r.position,1,false,r.fullSize,r.referenceCrystal);d.target=r;r.slots[d.id]=1
 return pl,p,d,r
end
local function steps(n) for _=1,n do realTime+=C.Tick;now=realTime;pickupStep(C.Tick) end end
check('break scatters conserved owner-only ore and cannot pay twice',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));assert(Pro.cargoUnits(data(p))==0);assert(pendingOre(p)==10)
 assert(not hitResource(d,r,500));assert(pendingOre(p)==10)
 steps(100);assert(Pro.cargoUnits(data(p))==10 and pendingOre(p)==0)
 steps(100);assert(Pro.cargoUnits(data(p))==10)
end)
check('real layer breaks release ore before death and the collapse pays only the remainder',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,30));assert(not r.paid and r.stage==1)
 assert(pendingOre(p)==1 and r.extractedOre==1)
 for _,drop in pairs(pickups) do if drop.owner==d.owner then assert(drop.y>r.part.Position.Y) end end
 assert(hitResource(d,r,.01));assert(pendingOre(p)==1,'same-layer hit repeated extraction')
 steps(100);assert(Pro.cargoUnits(data(p))==1 and not r.paid,'no useful collection before collapse')
 assert(hitResource(d,r,30));assert(pendingOre(p)==2 and r.extractedOre==3)
 assert(hitResource(d,r,500));assert(pendingOre(p)==9 and r.extractedOre==10)
 assert(not hitResource(d,r,500));steps(100);assert(Pro.cargoUnits(data(p))==10)
end)
check('skipped boulder layers and fractional yield conserve the full payout with bounded fragments',function()
 local _,p,d,r=fixture();r.stageCount=7;r.ore=101;d.stats.yieldMultiplier=1.25
 data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 for _=1,20 do if r.paid then break end;assert(hitResource(d,r,8)) end
 assert(r.paid and r.extractedOre==101 and pendingOre(p)==126)
 assert(math.abs(data(p).run.yieldRemainders.Quartz-.25)<1e-7)
 local n=0;for _,drop in pairs(pickups) do if drop.owner==d.owner then n+=1 end end
 assert(n<=4,'layer extraction grew unbounded physical pickups')
end)
check('specialist final bonus still uses the whole rock after extraction',function()
 local _,p,d,r=fixture();d.role='Bubbler';r.ore=11
 for _=1,4 do
  d.specialJob={targetId=r.id,startedAt=now-2,duration=1,impact=.5,damage=1000}
  assert(hitResource(d,r,1000,false,nil,nil,'Special'))
 end
 assert(r.paid and r.extractedOre==11 and pendingOre(p)==13)
 assert(math.abs(data(p).run.yieldRemainders.Quartz-.75)<1e-7,'lost whole-rock specialist bonus')
end)
check('geode shells and rejected hits never extract ore',function()
 local _,p,d,r=fixture();r.kind='Geode'
 assert(hitResource(d,r,30));assert(r.stage>0 and pendingOre(p)==0 and not r.extractedOre)
 assert(hitResource(d,r,500));assert(pendingOre(p)==0)
 local _,q,e,s=fixture();s.slots[e.id]=nil
 assert(not hitResource(e,s,30));assert(pendingOre(q)==0 and not s.extractedOre)
 s.slots[e.id]=1;q.busy=true;assert(not hitResource(e,s,30));q.busy=false
 assert(pendingOre(q)==0 and not s.extractedOre)
end)
check('another nearby player cannot attract or steal the owners fragments',function()
 local pl,p,d,r=fixture();local _,q=fixture();assert(hitResource(d,r,500))
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(70,3,0)));steps(100)
 assert(Pro.cargoUnits(data(p))==0 and Pro.cargoUnits(data(q))==0 and pendingOre(p)==10)
 pl.Character:PivotTo(CFrame.new(r.position+Vector3.new(0,2,0)));steps(100);assert(Pro.cargoUnits(data(p))==10)
end)
check('a full backpack leaves real fragments until selling makes space',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 steps(100);assert(pendingOre(p)==10 and Pro.cargoUnits(data(p))==Ca.capacity(data(p)))
 realTime+=60;now=realTime;pickupStep(C.Tick)
 assert(pendingOre(p)==10,'ore vanished during a sell trip')
 data(p).run.cargo={};steps(100);assert(pendingOre(p)==0 and Pro.cargoUnits(data(p))==10)
end)
check('a delayed Emerald sell trip leaves physical cargo available on return',function()
 local pl,p,_,r=fixture()
 local counter=scene.packStation
 local oldPosition=counter.Position
 counter.Position=Vector3.new(-38,5.5,32)
 local emerald=Vector3.new(0,7.2,420)
 local savedRun=data(p).run.id
 pl.Character:PivotTo(CFrame.new(emerald))
 data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 local material=Workshop.cargoKey('RunEmerald',2560)
 local born=now
 scene.spawnOrePickup(r.part,{owner=pl.UserId,runId=savedRun,nodeId='emerald-return',material=material,
  tierMaterial='RunEmerald',value=2560,units=1,raw=true,floor=4.26},emerald,Vector3.new(3,13,0),Color3.new(0,1,0))
 local id=pickupSerial
 steps(math.ceil(65/C.Tick))
 local drop=assert(pickups[id])
 local settled=drop.part.Position
 local snapshot=drop.part:GetAttribute('SnapshotAt')
 assert(drop.part:GetAttribute('ExpiresAt')>born+OreDrops.LIFETIME)
 local function walk(to)
  local from=characterRoot(p).Position
  local stride=math.ceil((to-from).Magnitude/(16*C.Tick))
  for i=1,stride do
   pl.Character:PivotTo(CFrame.new(from:Lerp(to,i/stride)));steps(1)
  end
 end
 walk(counter.Position+Vector3.yAxis*3)
 command.OnServerEvent:Fire(pl,'Sell')
 assert(Pro.cargoUnits(data(p))==0,'the depot sale did not make room')
 steps(math.ceil(10/C.Tick))
 -- The ore has already passed its original deadline before the return leg.
 assert(now>born+OreDrops.LIFETIME and pickups[id]==drop and drop.part.Transparency==0)
 assert(drop.part.Position==settled and drop.part:GetAttribute('SnapshotAt')==snapshot,'the deadline change relaunched the cargo')
 walk(settled+Vector3.yAxis*2)
 steps(100)
 assert(not pickups[id] and data(p).run.cargo[material]==1 and Pro.cargoUnits(data(p))==1)
 print(string.format('MODEL Emerald cargo still collected after %.1fs including a real depot sale',now-born))
 counter.Position=oldPosition
 players.PlayerRemoving:Fire(pl)
end)
check('the full-bag return grace clears abandoned cargo after three minutes',function()
 local pl,p,_,r=fixture()
 local point=scene.packStation.Position+Vector3.new(0,3,400)
 local material=Workshop.cargoKey('RunEmerald',2560)
 pl.Character:PivotTo(CFrame.new(point))
 data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 local born=now
 scene.spawnOrePickup(r.part,{owner=pl.UserId,runId=data(p).run.id,nodeId='abandoned',material=material,
  tierMaterial='RunEmerald',value=2560,units=1,raw=true,floor=point.Y-2},point,Vector3.zero,Color3.new(0,1,0))
 local id=pickupSerial
 steps(math.ceil((OreDrops.CARGO_MAX_AGE-2)/C.Tick))
 assert(pickups[id] and pickups[id].part:GetAttribute('ExpiresAt')==born+OreDrops.CARGO_MAX_AGE)
 steps(math.ceil(3/C.Tick))
 assert(not pickups[id] and not data(p).run.cargo[material])
 players.PlayerRemoving:Fire(pl)
end)
check('overflow adds to a nearby pile and extends its expiry without relaunching it',function()
 local _,p,d,starter=fixture()
 data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 local field=starter.field
 local function mineAt(x)
  local r=makeResource(field,field.center+Vector3.new(x,0,0),'Crystal',100,10,3)
  r.readyAt=now;release(d);d.target=r;d.targetSlot=1;r.slots[d.id]=1
  d.pos=committedStation(d,r)
  assert(hitResource(d,r,500))
  return r
 end
 local firstTime=now
 local near=mineAt(-12)
 for _=2,OreDrops.MAX_NODES do mineAt(12) end
 realTime+=65;now=realTime
 mineAt(-12)
 local units,nodes=pendingOre(p)
 assert(units==(OreDrops.MAX_NODES+1)*10 and nodes==OreDrops.MAX_NODES)
 local refreshed
 for _,drop in pairs(pickups) do if drop.owner==d.owner and drop.refreshedAt then refreshed=drop end end
 assert(refreshed and refreshed.nodeId==near.id and refreshed.spawnAt==firstTime)
 assert(refreshed.part:GetAttribute('ExpiresAt')==now+OreDrops.LIFETIME)
end)
check('save uncertainty pauses pickup without mutating or deleting rewards',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));p.busy=true;steps(100)
 assert(pendingOre(p)==10 and Pro.cargoUnits(data(p))==0)
 p.busy=false;steps(100);assert(pendingOre(p)==0 and Pro.cargoUnits(data(p))==10)
end)
check('walls block attraction and collection until an unobstructed route exists',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));local old=workspace.Raycast
 local wall=Instance.new('Part');workspace.Raycast=function(_,from) return {Instance=wall,Position=from+Vector3.new(0,0,.1)} end
 steps(100);assert(pendingOre(p)==10 and Pro.cargoUnits(data(p))==0)
 workspace.Raycast=old;steps(100);assert(pendingOre(p)==0 and Pro.cargoUnits(data(p))==10)
end)
check('old-run or disconnected drops cannot enter a later profile',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.id='next-run';steps(1)
 assert(pendingOre(p)==0 and Pro.cargoUnits(data(p))==0)
 local _,q,e,s=fixture();assert(hitResource(e,s,500));q.leaving=true;steps(1)
 for _,drop in pairs(pickups) do assert(drop.owner~=q.player.UserId) end
end)
check('new resources are grounded with health independent of their footprint',function()
 local _,_,_,reference=fixture()
 assert(math.abs(reference.position.Y-reference.field.center.Y-3)<1e-7)
 local field=patches[2]
 local r=makeResource(field,field.center,'Crystal',100,10,3)
 local ground=r.field.part.Position.Y+r.field.part.Size.Y*.5
 assert(math.abs(r.position.Y-r.fullSize.Y*.5-ground+.06)<1e-7)
 assert(r.part:GetAttribute('GroundY')==ground)
 local weak=Mining.resource(75,'Crystal',1);local hard=Mining.resource(75,'Crystal',8)
 assert(weak.work>0 and hard.work==8*weak.work and weak.size==hard.size)
end)
check('landing receipts describe real contacts and stop advancing at rest',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 steps(90)
 local serials={};local found=false
 for id,drop in pairs(pickups) do if drop.owner==p.player.UserId then
  found=true;local part=drop.part
  assert((part:GetAttribute('GroundImpactSerial') or 0)>=1)
  assert(part:GetAttribute('GroundImpactAt')>0 and part:GetAttribute('GroundImpactSpeed')>1)
  assert(part:GetAttribute('GroundImpactPosition').Y==drop.floor)
  serials[id]=part:GetAttribute('GroundImpactSerial')
 end end
 assert(found);steps(120)
 for id,serial in pairs(serials) do assert(pickups[id].part:GetAttribute('GroundImpactSerial')==serial) end
end)
check('full bags keep uncollected ore until its wall-clock expiry',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 local born=now;local found=false
 for _,drop in pairs(pickups) do if drop.owner==p.player.UserId then
  found=true;assert(drop.part:GetAttribute('SpawnAt')==born)
  assert(drop.part:GetAttribute('ExpiresAt')==born+OreDrops.LIFETIME)
 end end
 assert(found);now=born+OreDrops.LIFETIME-.8;realTime=now;pickupStep(C.Tick)
 for _,drop in pairs(pickups) do if drop.owner==p.player.UserId then assert(drop.part.Transparency==0) end end
 p.busy=true;now=born+OreDrops.LIFETIME;realTime=now;pickupStep(C.Tick)
 assert(pendingOre(p)==0 and Pro.cargoUnits(data(p))==Ca.capacity(data(p)))
end)
check('partial pickup receipts identify the real fragment and retain expiry of the remainder',function()
 local pl,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))-1}
 steps(100);assert(Pro.cargoUnits(data(p))==Ca.capacity(data(p)) and pendingOre(p)==9)
 local receipt=Http:JSONDecode(pl:GetAttribute('MA_Collect'));assert(receipt.units==1 and receipt.pickupId and receipt.exhausted==false)
 local drop=assert(pickups[receipt.pickupId]);assert(drop.units>0 and drop.part:GetAttribute('ExpiresAt')==drop.spawnAt+OreDrops.LIFETIME)
end)
check('ore leaving a raised field falls to the actual outside map floor',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 local drop;for _,v in pairs(pickups) do if v.owner==p.player.UserId then drop=v;break end end
 assert(drop);drop.x=r.field.part.Position.X+r.field.part.Size.X*.5+2;drop.y=drop.floor;drop.vx=2;drop.vy=0;drop.vz=0
 local original=workspace.Raycast;local queries=0
 workspace.Raycast=function(_,from,_,params)
  if params and params.FilterType==Enum.RaycastFilterType.Include then queries+=1;return {Position=Vector3.new(from.X,0,from.Z)} end
  return nil
 end
 steps(90);workspace.Raycast=original
 assert(drop.floor==.22 and drop.part:GetAttribute('FloorY')==.22 and math.abs(drop.y-.22)<.01,'chip hovered on its old raised plane')
 assert(queries>=1 and queries<=6,'stationary ore repeatedly queried the map')
 assert(pendingOre(p)==10,'terrain contact changed reward units')
end)
print(checks..' production pickup server checks with API doubles; not Studio validation')
