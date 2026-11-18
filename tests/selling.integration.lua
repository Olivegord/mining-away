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
assert(stone.stone and stone.arc and not stone.landed and stone.launchAt==now)
assert(stone.vy>=55 and stone.arc.contact>.5)
assert(stone.part:GetAttribute('StoneCargo') and stone.part.Material==Enum.Material.Slate and not OreDrops.collectible(stone))
for _=1,math.ceil((stone.arc.contact+1)/.04) do OreDrops.step(stone,{x=stone.x,y=stone.floor,z=stone.z},.04,false) end
assert(OreDrops.collectible(stone))
local crystal=drop(1)
assert(not crystal.stone and crystal.arc and crystal.arc.contact>.5 and not OreDrops.collectible(crystal))
assert(crystal.part:GetAttribute('RareGemReward') and not stone.part:GetAttribute('RareGemReward'))
local a,b=Workshop.saleItem(stone.material),Workshop.saleItem(crystal.material)
assert(a.dust/b.dust==.07 and a.cash<b.cash/8 and a.stoneUnits>0 and b.stoneUnits==0)
local profile=data(p);profile.run.cargo={[stone.material]=1,[crystal.material]=1}
pl.Character:PivotTo(CFrame.new(scene.packStation.Position))
local messages=RS.MiningAway.Sale.clientMessages
local function input(kind,id) command.OnServerEvent:Fire(pl,kind,id) end
local function refreshTokens() realTime+=3;now=realTime end
local money=profile.run.wallet.Quartz
pl.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.new(0,0,80)))
local before=#messages
input('Sell')
assert(#messages==before and Pro.cargoUnits(data(p))==2,'remote sale got through')
refreshTokens();pl.Character:PivotTo(CFrame.new(scene.packStation.Position))
profile.run.cargo[stone.material]=2
input('Sell')
local event=messages[#messages]
assert(#messages==before+1 and event.player==pl and event.payload.counter and event.payload.full and event.payload.units==3)
assert(event.payload.resources.Ruby==2*a.dust+b.dust and event.payload.resources.Stone==2*a.stoneUnits)
assert(event.payload.cash==2*a.cash+b.cash and Pro.cargoUnits(data(p))==0)
local replicated=Http:JSONDecode(pl:GetAttribute('MA_Profile'))
local credit=replicated.recentSales[1]
assert(credit.id==event.payload.id and credit.revision==replicated.revision and credit.cash==event.payload.cash)
assert(replicated.run.wallet.Quartz==money+credit.cash)
input('ReturnCargo');input('Sell')
assert(#messages==before+1 and data(p).run.wallet.Quartz==money+credit.cash,'empty or repeated action credited again')
Workshop.CRYSTAL_CHANCE=beforeChance
players.PlayerRemoving:Fire(pl)
print('PASS one-press counter sale: range, exact mixed payout, cleared bag and no second credit')
