-- Actual bundled server/API doubles; not engine/network playtesting.
local checks=0
RoleEffects.Ability=function() end;RoleEffects.ClearAbility=function() end;discoveries.TrySpawn=function() end
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS pickups server '..name) end
local uid=98000
local function fixture()
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=profiles[uid]
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 local r=makeResource(patches[1],patches[1].center,'Crystal',100,10,3);r.readyAt=now
 local d=p.drones[1];d.pos=Feel.mineGoal(r.position,1,false,r.fullSize);d.target=r;r.slots[d.id]=1
 return pl,p,d,r
end
local function steps(n) for _=1,n do realTime+=C.Tick;now=realTime;pickupStep(C.Tick) end end
check('break scatters conserved owner-only ore and cannot pay twice',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));assert(Pro.cargoUnits(data(p))==0);assert(pendingOre(p)==10)
 assert(not hitResource(d,r,500));assert(pendingOre(p)==10)
 steps(100);assert(Pro.cargoUnits(data(p))==10 and pendingOre(p)==0)
 steps(100);assert(Pro.cargoUnits(data(p))==10)
end)
check('another nearby player cannot attract or steal the owners fragments',function()
 local pl,p,d,r=fixture();local _,q=fixture();assert(hitResource(d,r,500))
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(70,3,0)));steps(100)
 assert(Pro.cargoUnits(data(p))==0 and Pro.cargoUnits(data(q))==0 and pendingOre(p)==10)
 pl.Character:PivotTo(CFrame.new(r.position+Vector3.new(0,2,0)));steps(100);assert(Pro.cargoUnits(data(p))==10)
end)
check('a full backpack leaves real fragments until selling makes space',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 steps(100);assert(pendingOre(p)==10 and Pro.cargoUnits(data(p))==40)
 data(p).run.cargo={};steps(100);assert(pendingOre(p)==0 and Pro.cargoUnits(data(p))==10)
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
 local _,_,_,r=fixture();local ground=r.field.part.Position.Y+r.field.part.Size.Y*.5
 assert(math.abs(r.position.Y-r.fullSize.Y*.5-ground+.06)<1e-7)
 assert(r.part:GetAttribute('GroundY')==ground and r.part.Material==Enum.Material.Rock)
 local weak=Mining.resource(75,'Crystal',1);local hard=Mining.resource(75,'Crystal',8)
 assert(weak.work==195 and hard.work==1560 and weak.size==hard.size)
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
check('full bags cannot stockpile rewards beyond the wall-clock expiry',function()
 local _,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))}
 local born=now;local found=false
 for _,drop in pairs(pickups) do if drop.owner==p.player.UserId then
  found=true;assert(drop.part:GetAttribute('SpawnAt')==born)
  assert(drop.part:GetAttribute('FadeAt')==born+OreDrops.LIFETIME-OreDrops.FADE_SECONDS)
  assert(drop.part:GetAttribute('ExpiresAt')==born+OreDrops.LIFETIME)
 end end
 assert(found);now=born+OreDrops.LIFETIME-2;realTime=now;pickupStep(C.Tick)
 for _,drop in pairs(pickups) do if drop.owner==p.player.UserId then assert(drop.part.Transparency>.5 and drop.part.Transparency<1) end end
 p.busy=true;now=born+OreDrops.LIFETIME;realTime=now;pickupStep(C.Tick)
 assert(pendingOre(p)==0 and Pro.cargoUnits(data(p))==Ca.capacity(data(p)))
end)
check('partial pickup receipts identify the real fragment and retain expiry of the remainder',function()
 local pl,p,d,r=fixture();assert(hitResource(d,r,500));data(p).run.cargo={Quartz=Ca.capacity(data(p))-1}
 steps(100);assert(Pro.cargoUnits(data(p))==Ca.capacity(data(p)) and pendingOre(p)==9)
 local receipt=Http:JSONDecode(pl:GetAttribute('MA_Collect'));assert(receipt.units==1 and receipt.pickupId and receipt.exhausted==false)
 local drop=assert(pickups[receipt.pickupId]);assert(drop.units>0 and drop.part:GetAttribute('ExpiresAt')==drop.spawnAt+OreDrops.LIFETIME)
end)
print(checks..' production pickup server checks with API doubles; not Studio validation')
