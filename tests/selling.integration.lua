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
input('QuoteSale','too-far')
assert(messages[#messages].payload.kind=='rejected' and Pro.cargoUnits(data(p))==2)
refreshTokens();pl.Character:PivotTo(CFrame.new(scene.packStation.Position))
input('QuoteSale','first')
local first=messages[#messages].payload
assert(first.kind=='quote' and first.request=='first' and first.cash==a.cash+b.cash)
assert(Pro.cargoUnits(data(p))==2 and data(p).run.wallet.Quartz==money,'quote mutated the profile')
input('Sell','forged')
assert(messages[#messages].payload.kind=='rejected' and Pro.cargoUnits(data(p))==2)
profile.run.cargo[stone.material]=2
input('Sell',first.id)
assert(messages[#messages].payload.kind=='rejected' and Pro.cargoUnits(data(p))==3,'stale quote sold a changed bag')
refreshTokens()
input('QuoteSale','second')
local second=messages[#messages].payload
assert(second.kind=='quote' and second.units==3)
pl.Character:PivotTo(CFrame.new(scene.packStation.Position+Vector3.new(0,0,80)))
input('Sell',second.id)
assert(messages[#messages].payload.kind=='rejected' and Pro.cargoUnits(data(p))==3,'left the counter before confirming')
pl.Character:PivotTo(CFrame.new(scene.packStation.Position))
input('Sell',second.id)
local event=messages[#messages]
assert(event.player==pl and event.payload.id==second.id and event.payload.counter and event.payload.full)
assert(event.payload.resources.Ruby==second.resources.Ruby and second.resources.Ruby==2*a.dust+b.dust)
assert(event.payload.cash==second.cash and second.cash==2*a.cash+b.cash and Pro.cargoUnits(data(p))==0)
local replicated=Http:JSONDecode(pl:GetAttribute('MA_Profile'))
local credit=replicated.recentSales[1]
assert(credit.id==event.payload.id and credit.revision==replicated.revision and credit.cash==event.payload.cash)
assert(replicated.run.wallet.Quartz==money+credit.cash)
input('Sell',second.id)
assert(messages[#messages].payload.kind=='rejected' and data(p).run.wallet.Quartz==money+credit.cash)
input('QuoteSale','empty')
assert(messages[#messages].payload.kind=='rejected')
Workshop.CRYSTAL_CHANCE=beforeChance
players.PlayerRemoving:Fire(pl)
print('PASS production selling: quotes are read-only, changed bags and out-of-range confirmations fail, mixed committed payouts match the quote, and replay cannot double-pay')
