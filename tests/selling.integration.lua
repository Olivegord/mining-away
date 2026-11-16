local pl=player(98333);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId];local d=p.drones[1]
local f=patches[1];f.cfg.SelectionOnly=true;f.cfg.AlwaysUnlocked=true;f.cfg.Material='RunRuby';f.color=Color3.new(1,.2,.4)
f.e.phase='Safe'
pl.Character:PivotTo(CFrame.new(f.center))
local beforeChance=Workshop.CRYSTAL_CHANCE
local function drop(chance)
 Workshop.CRYSTAL_CHANCE=chance
 local r=makeResource(f,f.center,'Crystal',100,10,3,3);r.readyAt=now
 local previous=pickupSerial
 award(d,r,false,false)
 assert(pickupSerial==previous+1)
 award(d,r,false,false);assert(pickupSerial==previous+1,'repeat award duplicated ore')
 return pickups[pickupSerial]
end
local stone=drop(0)
assert(stone.stone and stone.instant and stone.landed and not stone.arc)
assert(stone.vx==0 and stone.vy==0 and stone.vz==0 and stone.launchAt==now)
assert(stone.part:GetAttribute('StoneCargo') and stone.part.Material==Enum.Material.Slate and OreDrops.collectible(stone))
local crystal=drop(1)
assert(not crystal.stone and crystal.arc and crystal.vy>0 and not OreDrops.collectible(crystal))
local a,b=Workshop.saleItem(stone.material),Workshop.saleItem(crystal.material)
assert(a.dust/b.dust==.07 and a.cash<b.cash/8 and a.stoneUnits>0 and b.stoneUnits==0)
local profile=data(p);profile.run.cargo={[stone.material]=1,[crystal.material]=1}
pl.Character:PivotTo(CFrame.new(scene.packStation.Position))
local before=#RS.MiningAway.Sale.clientMessages
sellBackpack(p)
assert(#RS.MiningAway.Sale.clientMessages==before+1)
local event=RS.MiningAway.Sale.clientMessages[#RS.MiningAway.Sale.clientMessages]
assert(event.player==pl and event.payload.full and event.payload.resources.Ruby==a.dust+b.dust)
assert(event.payload.cash==a.cash+b.cash and Pro.cargoUnits(data(p))==0)
sellBackpack(p);assert(#RS.MiningAway.Sale.clientMessages==before+1,'empty sale emitted a reward')
Workshop.CRYSTAL_CHANCE=beforeChance
players.PlayerRemoving:Fire(pl)
print('PASS production selling: instant stone, launched rare crystal, one drop per cut, correct resource ratio, committed private receipt and empty-sale protection')
