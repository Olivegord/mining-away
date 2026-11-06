-- Pure production profile/logistics checks for the current live game's schema.
-- These tests do not simulate Roblox rendering, network transport, or DataStores.
local Profile=require('../src/Profile')
local Catalog=require('../src/DroneCatalog')
local Roles=require('../src/DroneRoles')
local Cards=require('../src/Cards')
local Logistics=require('../src/Logistics')
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS special/logistics '..name) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function profile(uid)
 local p=Profile.new(uid or 71001,123);p.run.wallet.Quartz=1000000;p.run.credits=p.run.wallet.Quartz;return p
end
local depot={atDepot=true,activeEncounter=false}
check('new owners auto-launch from their first shipment while saved manual preferences survive',function()
 local p=profile();assert(p.logistics.autoLaunch and p.logistics.launches==0)
 p.logistics.autoLaunch=false
 local restored,err=Profile.migrate(Profile.clone(p),p.userId);assert(restored,err)
 eq(restored.logistics.autoLaunch,false);assert(Profile.validate(restored,p.userId))
end)
check('schema-six migration preserves original identities traits material wallets and paid choices',function()
 local p=profile();local id=p.fleet[1].id;local speed=p.fleet[1].base.maxStep60
 p.run.cargo={Ruby=7};p.run.wallet.Ruby=23
 p.run.pendingOffer={id='saved-paid-offer',runId=p.run.id,price=40,currency='Quartz',choices={
  {cardId='F01',scope='Fleet',effects={mining=.15}},
  {cardId='F06',scope='Player',effects={capacity=.25}},
  {cardId='D05',scope='Individual',targetDroneId=id,effects={startup=1}},
 }}
 p.schemaVersion=6;p.purchasedDrones=nil;p.logistics=nil;p.run.logistics=nil
 local migrated,err=Profile.migrate(p,p.userId);assert(migrated,err)
 eq(migrated.schemaVersion,Profile.SCHEMA);eq(migrated.purchasedDrones,0);eq(#migrated.fleet,1)
 eq(migrated.fleet[1].id,id);eq(migrated.fleet[1].base.maxStep60,speed)
 eq(migrated.run.cargo.Ruby,7);eq(migrated.run.wallet.Ruby,23);eq(migrated.run.pendingOffer.id,'saved-paid-offer')
 eq(migrated.run.pendingOffer.choices[3].targetDroneId,id);assert(Profile.validate(migrated,p.userId))
end)
check('all seven new miners are permanent workers with distinct durations and costs',function()
 local p=profile();local initial=p.run.wallet.Quartz;local spent=0
 for _,kind in ipairs(Catalog.Order) do
  if kind~='Laser' then
   local definition=Catalog.Types[kind];assert(definition.Duration>0 and definition.Price>0)
   local ok,result=Profile.buyDrone(p,kind,'buy:'..kind,p.run.id,depot);assert(ok,result)
   local owned=p.fleet[#p.fleet]
   eq(owned.id,tostring(p.userId)..':drone:'..#p.fleet);eq(owned.type,kind);eq(owned.role,kind)
   eq(result.droneId,owned.id);eq(result.price,definition.Price);eq(result.currency,'Quartz')
   assert(Roles.isWorker(kind));assert(Cards.stats(p,owned).miningDPS>0)
   spent+=definition.Price;assert(Profile.validate(p,p.userId))
  end
 end
 eq(#p.fleet,8);eq(p.purchasedDrones,7);eq(p.run.wallet.Quartz,initial-spent)
end)
check('purchase receipts reject conflicting replay stale run foreign types missing funds and remote context',function()
 local p=profile();local ok,result=Profile.buyDrone(p,'Bubbler','stable-buy',p.run.id,depot);assert(ok,result)
 local balance=p.run.wallet.Quartz
 assert(Profile.buyDrone(p,'Bubbler','stable-buy',p.run.id,depot));eq(#p.fleet,2);eq(p.run.wallet.Quartz,balance)
 eq(Profile.buyDrone(p,'Halver','stable-buy',p.run.id,depot),false)
 eq(Profile.buyDrone(p,'Bubbler','fresh-stale','foreign-run',depot),false)
 eq(Profile.buyDrone(p,'Unknown','bad-kind',p.run.id,depot),false)
 eq(Profile.buyDrone(p,'Laser','free-miner',p.run.id,depot),false)
 eq(Profile.buyDrone(p,'Bubbler','remote-buy',p.run.id,{atDepot=false}),false)
 eq(Profile.buyDrone(p,'Bubbler','combat-buy',p.run.id,{atDepot=true,activeEncounter=true}),false)
 p.run.wallet.Quartz=0;p.run.credits=0;eq(Profile.buyDrone(p,'Bubbler','no-funds',p.run.id,depot),false)
 eq(#p.fleet,2)
end)
check('purchased growth preserves the live game permanent fleet invariant without a new fleet cap',function()
 local p=profile()
 for index=1,32 do assert(Profile.buyDrone(p,'Frostbite','growth:'..index,p.run.id,depot)) end
 eq(#p.fleet,33);eq(p.purchasedDrones,32);eq(p.nextDroneSerial,34);assert(Profile.validate(p,p.userId))
end)
check('prestige adds one earned drone while retaining purchased identities and base traits',function()
 local p=profile();assert(Profile.buyDrone(p,'Singularity','prestige-bought',p.run.id,depot))
 local bought=Profile.clone(p.fleet[2]);local before=#p.fleet
 local milestone=Profile.milestone(p);p.run.saleEarnings=milestone.earnings;p.clearedFields[milestone.field]=milestone.wins>0 or nil
 p.run.logistics.storage={Quartz=7};p.run.logistics.pendingCargo={Ruby=3}
 local ok,result=Profile.prestige(p,'special-prestige',p.run.id,{atDepot=true,activeEncounter=false,confirmed=true});assert(ok,result)
 eq(#p.fleet,before+1);eq(p.purchasedDrones,1);eq(p.prestiges,1)
 eq(p.fleet[2].id,bought.id);eq(p.fleet[2].role,bought.role);eq(p.fleet[2].base.miningDPS,bought.base.miningDPS)
 eq(next(p.run.logistics.storage),nil);eq(next(p.run.logistics.pendingCargo),nil);assert(Profile.validate(p,p.userId))
end)
check('typed deposits accept only free storage space without changing the source bag',function()
 local p=profile();local cap=Logistics.CAPACITY;p.run.logistics.storage={Quartz=cap-4}
 local bag={Ruby=7};local accepted,units=Logistics.depositInto(p,bag)
 eq(units,4);eq(accepted.Ruby,4);eq(bag.Ruby,7);eq(Logistics.bagUnits(p.run.logistics.storage),cap)
 eq(Logistics.depositMineral(p,'Emerald',5),0);eq(Logistics.depositMineral(p,'Unknown',5),0)
 eq(Logistics.depositMineral(p,'Ruby',0/0),0);eq(Logistics.depositMineral(p,'Ruby',-1),0)
 local rejected,n=Logistics.depositInto(p,{Foreign=9});eq(next(rejected),nil);eq(n,0)
end)
check('launch snapshots exactly one full typed manifest and pays matching mineral balances once',function()
 local p=profile();local cap=Logistics.CAPACITY;p.run.wallet.Quartz=0;p.run.credits=0
 eq(Logistics.beginLaunch(p),false);p.run.logistics.storage={Quartz=cap-20,Ruby=30}
 local ok,result=Logistics.beginLaunch(p);assert(ok,result);eq(result.units,cap)
 eq(p.run.logistics.launchCargo.Quartz,cap-20);eq(p.run.logistics.launchCargo.Ruby,20);eq(p.run.logistics.storage.Ruby,10)
 eq(Logistics.beginLaunch(p),false);eq(Logistics.finishLaunch(p,{Quartz=1,Ruby=2}),false)
 eq(Logistics.depositMineral(p,'Cobalt',cap),cap-10);p.run.logistics.launchRemaining=0
 ok,result=Logistics.finishLaunch(p,{Quartz=1,Ruby=2});assert(ok,result)
 eq(p.run.wallet.Quartz,cap-20);eq(p.run.wallet.Ruby,20);eq(p.run.credits,cap-20)
 eq(p.run.saleEarnings,cap+20);eq(p.logistics.launches,1);eq(Logistics.bagUnits(p.run.logistics.storage),cap)
 eq(Logistics.finishLaunch(p),false);eq(p.logistics.launches,1);eq(p.run.wallet.Ruby,20)
end)
check('flying backpack preserves mixed mineral overflow until storage becomes available',function()
 local p=profile();assert(Logistics.buy(p,'Backpack'));local bagCap=40;local cap=Logistics.CAPACITY
 p.run.cargo={Quartz=30,Ruby=20};p.run.logistics.storage={Quartz=cap-4}
 assert(Logistics.pickupBackpack(p,bagCap));eq(Profile.cargoUnits(p),10);eq(Logistics.bagUnits(p.run.logistics.backpackCargo),40)
 eq(Logistics.pickupBackpack(p,bagCap),false);eq(Logistics.deliverBackpack(p),4)
 eq(Logistics.bagUnits(p.run.logistics.backpackCargo),36);eq(Logistics.deliverBackpack(p),0)
 assert(Logistics.beginLaunch(p));eq(Logistics.deliverBackpack(p),36);eq(Logistics.bagUnits(p.run.logistics.backpackCargo),0)
 p.run.logistics.launchRemaining=0;assert(Logistics.finishLaunch(p))
 eq(Profile.cargoUnits(p)+Logistics.bagUnits(p.run.logistics.storage)+p.run.wallet.Quartz-1000000+Logistics.BACKPACK_PRICE,cap+46)
 assert(Profile.validate(p,p.userId))
end)
check('carrier loadouts reject duplicate foreign sparse excess nonworker and already-loaded identities',function()
 local p=profile();assert(Logistics.buy(p,'Carrier'));assert(Logistics.buy(p,'Carrier'))
 for index=1,4 do assert(Profile.buyDrone(p,'Frostbite','load-miner:'..index,p.run.id,depot)) end
 local c=p.logistics.carriers[1];local id=p.fleet[1].id
 for _,ids in ipairs({{id,id},{'foreign:drone:1'},{[2]=id},{id,p.fleet[2].id,p.fleet[3].id,p.fleet[4].id,p.fleet[5].id}}) do
  eq(Logistics.loadCarrier(p,c.id,ids),false);eq(#c.droneIds,0)
 end
 local worker=p.fleet[5];local oldRole=worker.role
 for _,role in ipairs({'Courier','Medic','Dart','Orbiter','Scrapper'}) do worker.role=role;eq(Logistics.loadCarrier(p,c.id,{worker.id}),false) end
 worker.role=oldRole
 local ids={};for index=1,4 do ids[index]=p.fleet[index].id end
 assert(Logistics.loadCarrier(p,c.id,ids));eq(#c.droneIds,4)
 eq(Logistics.loadCarrier(p,p.logistics.carriers[2].id,{id}),false);assert(Profile.validate(p,p.userId))
end)
check('prestige retains carriers backpack auto-launch ownership and earned-role sequence',function()
 local p=profile();assert(Logistics.buy(p,'Carrier'));assert(Logistics.buy(p,'Backpack'))
 for index=1,5 do assert(Profile.buyDrone(p,'Bubbler','prestige-miner:'..index,p.run.id,depot)) end
 assert(Logistics.loadCarrier(p,p.logistics.carriers[1].id,{p.fleet[2].id,p.fleet[3].id}))
 p.logistics.launches=2;p.logistics.autoLaunch=true
 local expected={{'Red','Charger'},{'Green','Medic'},{'Blue','Orbiter'}}
 for index,want in ipairs(expected) do
  local m=Profile.milestone(p);p.run.saleEarnings=m.earnings;if m.wins>0 then p.clearedFields[m.field]=true end
  local ok,result=Profile.prestige(p,'preserved-role:'..index,p.run.id,{atDepot=true,activeEncounter=false,confirmed=true});assert(ok,result)
  local d=p.fleet[#p.fleet];eq(d.type,want[1]);eq(d.role,want[2])
  eq(#p.logistics.carriers,1);eq(#p.logistics.carriers[1].droneIds,2);eq(p.logistics.backpack,true);eq(p.logistics.autoLaunch,true)
  assert(Profile.validate(p,p.userId))
 end
end)
print(checks..' current profile/logistics domain checks passed')
