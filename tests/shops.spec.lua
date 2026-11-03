-- Executes production economy/profile/card logic; no Studio or visual claims.
local S=require('../src/Shops')
local P=require('../src/Profile')
local C=require('../src/Cards')
local passed=0
local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS shops '..name) end
local function fresh() return P.new(44,123) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function buy(p,id,tx,level,ctx)
 local e=S.BY_ID[id]
 return S.buy(p,id,level or 0,tx or id,p.run.id,ctx or {shop=e.shop,atShop=true})
end
local function access(p,index)
 local unlocks={'quartz_ruby','ruby_cobalt','cobalt_violet','violet_emerald'}
 for i=1,index-1 do local e=S.BY_ID[unlocks[i]];p.run.wallet[e.shop]=10000;assert(buy(p,e.id)) end
 p.run.wallet[S.ORDER[index]]=10000
end
test('new player has one permanent drone, only Quartz, zero separate balances',function()
 local p=fresh();eq(#p.fleet,1);eq(P.validate(p,44),true)
 for i,key in ipairs(S.ORDER) do eq(S.balance(p,key),0);eq(S.unlocked(p,key),i==1) end
end)
test('mixed backpack sells into matching mineral wallets with no exchange',function()
 local p=fresh();p.run.cargo={Quartz=10,Ruby=12,Cobalt=5}
 local ok,r=P.sell(p,{Quartz=1,Ruby=2,Cobalt=4},'mixed',p.run.id);eq(ok,true)
 eq(r.credits,54);eq(p.run.saleEarnings,54);eq(p.run.wallet.Quartz,10);eq(p.run.wallet.Ruby,12);eq(p.run.wallet.Cobalt,5);eq(P.cargoUnits(p),0)
end)
test('sale receipt does not duplicate currencies or sell the next bag',function()
 local p=fresh();p.run.cargo={Ruby=12};assert(P.sell(p,{Ruby=2},'sale',p.run.id));p.run.cargo={Ruby=12}
 assert(P.sell(p,{Ruby=2},'sale',p.run.id));eq(S.balance(p,'Ruby'),12);eq(P.cargoUnits(p),12)
end)
test('mixed deposit failure is atomic and preserves the whole backpack',function()
 local p=fresh();p.run.cargo={Quartz=10,Ruby=12};p.run.wallet.Ruby=1e14-5
 eq(P.sell(p,{Quartz=1,Ruby=2},'overflow',p.run.id),false);eq(S.balance(p,'Quartz'),0);eq(P.cargoUnits(p),22);eq(p.run.saleEarnings,0)
end)
test('unknown currencies cannot clear a backpack',function()
 local p=fresh();p.run.cargo={Fake=10};eq(P.sell(p,{Fake=1},'unknown',p.run.id),false);eq(P.cargoUnits(p),10)
end)
test('courier deposits exactly its real eight-unit parcel once',function()
 local p=fresh();p.run.cargo={Ruby=12};local id=p.fleet[1].id
 assert(P.beginDelivery(p,id,'parcel',p.run.id,8));eq(P.cargoUnits(p),4)
 assert(P.finishDelivery(p,id,{Ruby=2},'parcel',p.run.id));eq(S.balance(p,'Ruby'),8)
 assert(P.finishDelivery(p,id,{Ruby=2},'parcel',p.run.id));eq(S.balance(p,'Ruby'),8)
end)
test('Quartz buys Ruby access and cannot jump straight to Cobalt',function()
 local p=fresh();p.run.wallet.Quartz=10000;p.run.wallet.Ruby=10000
 eq(buy(p,'ruby_cobalt'),false);eq(S.unlocked(p,'Cobalt'),false)
 assert(buy(p,'quartz_ruby'));eq(S.unlocked(p,'Ruby'),true);eq(S.balance(p,'Quartz'),9920)
 assert(buy(p,'ruby_cobalt'));eq(S.unlocked(p,'Cobalt'),true);eq(S.balance(p,'Ruby'),9856)
end)
test('rich Quartz wallet cannot pay a Ruby upgrade',function()
 local p=fresh();access(p,2);p.run.wallet.Quartz=100000;p.run.wallet.Ruby=0
 eq(buy(p,'ruby_pack_speed'),false);eq(p.run.shopLevels.ruby_pack_speed,nil)
end)
test('shop distance/combat context and server level quote are mandatory',function()
 local p=fresh();p.run.wallet.Quartz=1000
 eq(buy(p,'quartz_backpack','away',0,{shop='Quartz',atShop=false}),false)
 eq(buy(p,'quartz_backpack','combat',0,{shop='Quartz',atShop=true,activeEncounter=true}),false)
 eq(buy(p,'quartz_backpack','wrong',0,{shop='Ruby',atShop=true}),false)
 eq(buy(p,'quartz_backpack','quote',1),false);eq(S.balance(p,'Quartz'),1000)
end)
test('duplicate purchase and stale level never charge another level',function()
 local p=fresh();p.run.wallet.Quartz=1000;assert(buy(p,'quartz_backpack','one'))
 assert(buy(p,'quartz_backpack','one'));eq(S.balance(p,'Quartz'),970);eq(p.run.shopLevels.quartz_backpack,1)
 eq(buy(p,'quartz_backpack','two',0),false);assert(buy(p,'quartz_backpack','three',1));eq(S.balance(p,'Quartz'),910)
end)
test('transaction collision and stale-run purchase are rejected',function()
 local p=fresh();p.run.wallet.Quartz=1000;assert(buy(p,'quartz_backpack','id'))
 eq(buy(p,'quartz_scanner','id'),false)
 eq(S.buy(p,'quartz_backpack',1,'stale','old-run',{shop='Quartz',atShop=true}),false);eq(p.run.shopLevels.quartz_backpack,1)
end)
test('capacity and targeting purchases apply through real card stat calculation',function()
 local p=fresh();p.run.wallet.Quartz=10000;local id=p.fleet[1]
 eq(C.stats(p,id).plotAuto,0);assert(buy(p,'quartz_scanner'));eq(C.stats(p,id).plotAuto,1)
 assert(buy(p,'quartz_backpack'));eq(C.capacity(p),60)
 assert(buy(p,'quartz_backpack','b2',1));assert(buy(p,'quartz_backpack','b3',2));eq(C.capacity(p),100)
 table.insert(p.run.cards,{scope='Player',effects={capacity=1}});eq(C.capacity(p),120)
 eq(buy(p,'quartz_backpack','b4',3),false)
end)
test('guaranteed shop upgrades refuse redundant card automation and capped backpacks',function()
 local p=fresh();p.run.wallet.Quartz=1000
 table.insert(p.run.cards,{scope='Fleet',effects={plotAuto=1}});eq(buy(p,'quartz_scanner'),false)
 table.insert(p.run.cards,{scope='Player',effects={capacity=2}});eq(buy(p,'quartz_backpack'),false);eq(S.balance(p,'Quartz'),1000)
end)
test('Emerald pack press works on its own and never requires another upgrade',function()
 local p=fresh();access(p,5);p.run.wallet.Emerald=1000;eq(S.packSpeed(p),1)
 assert(buy(p,'emerald_pack_speed'));eq(S.packSpeed(p),4);eq(buy(p,'ruby_pack_speed'),false)
 local other=fresh();access(other,2);assert(buy(other,'ruby_pack_speed'));eq(S.packSpeed(other),2)
end)
test('pack discount affects future Quartz price, never paid offer or choices',function()
 local p=fresh();access(p,3);p.run.wallet.Quartz=1000
 local ok,o=C.buy(p,'pack',p.run.id,{expectedPackIndex=0,atDepot=true,combatVisible=true});assert(ok);eq(o.price,40);eq(o.currency,'Quartz');eq(#o.choices,3);eq(S.balance(p,'Quartz'),960)
 assert(buy(p,'cobalt_pack_discount'));eq(C.price(p),68);eq(p.run.pendingOffer.price,40)
 local _,replay=C.buy(p,'replay',p.run.id,{expectedPackIndex=1,atDepot=true});eq(replay.id,o.id);eq(replay.choices[1].cardId,o.choices[1].cardId);eq(S.balance(p,'Quartz'),960)
 assert(C.select(p,o.id,2,'pick',p.run.id,{atDepot=true}));eq(#p.run.cards,1);eq(p.run.pendingOffer,nil)
end)
test('legacy universal counter cannot buy packs without Quartz',function()
 local p=fresh();p.run.credits=100000;eq(C.buy(p,'pack',p.run.id,{expectedPackIndex=0,atDepot=true}),false)
end)
test('wide relay and rapid orbital work without prerequisite upgrades',function()
 local p=fresh();access(p,5);p.run.wallet.Emerald=1000
 assert(buy(p,'emerald_relay'));local st=C.stats(p,p.fleet[1]);eq(st.forkFraction,.2);eq(st.forkRange,12)
 assert(buy(p,'emerald_orbital_cycle'));eq(S.abilityUnlocked(p,'Orbital'),true);eq(C.abilityPerks(p).orbitalCycle,true)
 eq(p.run.shopLevels.cobalt_orbital,nil);eq(p.run.shopLevels.cobalt_relay,nil)
end)
test('cooldowns and shop state survive a valid profile reload',function()
 local p=fresh();access(p,3);p.run.abilityCooldowns.Orbital=1800000045.25
 local restored=assert(P.migrate(p,44));eq(restored.run.abilityCooldowns.Orbital,1800000045.25);eq(restored.run.shops.Cobalt,true);eq(restored.fleet[1].id,p.fleet[1].id)
end)
test('v4 migration preserves fleet, cargo and credits without inventing Ruby',function()
 local p=fresh();p.schemaVersion=4;p.run.wallet=nil;p.run.shopLevels=nil;p.run.shops=nil;p.run.abilityCooldowns=nil
 p.run.credits=123;p.run.cargo={Ruby=12};p.clearedFields.Cobalt=true;local base=P.clone(p.fleet[1])
 local r=assert(P.migrate(p,44));eq(r.schemaVersion,P.SCHEMA);eq(r.run.wallet.Quartz,123);eq(r.run.wallet.Ruby,0);eq(r.run.cargo.Ruby,12);eq(S.unlocked(r,'Cobalt'),true);eq(r.fleet[1].id,base.id);eq(r.fleet[1].base.maxStep60,base.base.maxStep60)
end)
test('corrupt future wallet, unlock chain and cooldown fail closed',function()
 for _,corrupt in ipairs({function(p) p.run.wallet.Ruby=-1 end,function(p) p.run.wallet.Quartz=nil end,function(p) p.run.wallet.Fake=0 end,function(p) p.run.shops.Emerald=true end,function(p) p.run.abilityCooldowns.Orbital=0/0 end}) do
  local p=fresh();corrupt(p);eq(P.migrate(p,44),nil)
 end
end)
test('prestige resets shops, currencies, cooldowns and cards; keeps actual fleet and guards',function()
 local p=fresh();access(p,3);p.clearedFields.Cobalt=true;p.run.saleEarnings=160;p.run.wallet.Ruby=99;p.run.abilityCooldowns.Orbital=1800000045
 local id=p.fleet[1].id;assert(P.prestige(p,'prestige',p.run.id,{atDepot=true,confirmed=true}))
 eq(#p.fleet,2);eq(p.fleet[1].id,id);eq(p.clearedFields.Cobalt,true);eq(p.run.shops.Ruby,nil);eq(p.run.wallet.Ruby,0);eq(next(p.run.shopLevels),nil);eq(next(p.run.abilityCooldowns),nil)
end)
test('new specialized permanent roles are awarded without rerolling existing drones',function()
 local p=fresh();local first=p.fleet[1].base.maxStep60
 for n=1,5 do p.run.saleEarnings=P.milestone(p).earnings;p.clearedFields.Cobalt=true;p.clearedFields.Violet=true;assert(P.prestige(p,'p'..n,p.run.id,{atDepot=true,confirmed=true})) end
 eq(p.fleet[4].role,'Orbiter');eq(p.fleet[5].role,'Scrapper');eq(p.fleet[6].role,'Courier');eq(p.fleet[1].base.maxStep60,first);eq(P.validate(p,44),true)
end)
test('packs grant standalone abilities without any combo prerequisite',function()
 local catalog,fallback=C.CATALOG,C.FALLBACK;local chosen={}
 for _,entry in ipairs(catalog) do if entry.cardId=='G01' or entry.cardId=='G02' or entry.cardId=='F03' then table.insert(chosen,entry) end end
 C.CATALOG=chosen;C.FALLBACK={}
 local p=fresh();p.run.wallet.Quartz=1000
 local ok,offer=C.buy(p,'standalone',p.run.id,{expectedPackIndex=0,atDepot=true,combatVisible=true});assert(ok)
 local index
 for i,card in ipairs(offer.choices) do
  assert(card.cardId~='A03' and card.cardId~='A04')
  if card.cardId=='G01' then index=i;eq(card.effects.orbitalLaser,1) end
 end
 assert(index);assert(C.select(p,offer.id,index,'pick',p.run.id,{atDepot=true}));eq(S.abilityUnlocked(p,'Orbital'),true);eq(S.unlocked(p,'Cobalt'),false)
 C.CATALOG=catalog;C.FALLBACK=fallback
end)
test('retired paid combo offers refund exactly once and selected combos become standalone',function()
 local p=fresh();p.run.wallet.Quartz=200
 local ok,offer=C.buy(p,'old-pack',p.run.id,{expectedPackIndex=0,atDepot=true,combatVisible=true});assert(ok)
 p.schemaVersion=5;p.run.pendingOffer.choices[1]={cardId='A03',scope='Player',effects={orbitalRelay=1}}
 local restored=assert(P.migrate(p,44));eq(restored.run.pendingOffer,nil);eq(restored.run.wallet.Quartz,200)
 restored=assert(P.migrate(restored,44));eq(restored.run.wallet.Quartz,200)
 local selected=fresh();selected.schemaVersion=5;selected.run.cards={{cardId='A03',scope='Player',effects={orbitalRelay=1}},{cardId='A04',scope='Player',effects={scrapRecycle=1}}}
 selected=assert(P.migrate(selected,44));eq(selected.run.cards[1].cardId,'G01');eq(selected.run.cards[2].cardId,'G02')
 eq(S.abilityUnlocked(selected,'Orbital'),true);eq(S.abilityUnlocked(selected,'Scrap'),true)
 eq(selected.run.cards[1].effects.orbitalRelay,nil);eq(selected.run.cards[2].effects.scrapRecycle,nil)
end)
test('every mineral shop offers standalone hardware upgrades with correct role isolation',function()
 local p=fresh();for _,key in ipairs(S.ORDER) do p.run.shops[key]=true;p.run.wallet[key]=10000 end
 local courier=P.clone(p.fleet[1]);courier.role='Courier';courier.id='test:44:1:2';p.activeFleet={p.fleet[1],courier}
 assert(buy(p,'ruby_courier_hold'));eq(C.stats(p,courier).courierCapacity,32);eq(C.stats(p,p.fleet[1]).courierCapacity,0)
 p.run.cargo={Ruby=40};assert(P.beginDelivery(p,courier.id,'large-parcel',p.run.id,32));eq(P.droneCargoUnits(p,courier.id),32);eq(P.cargoUnits(p),8)
 assert(P.validate(p,44))
 local before=C.stats(p,p.fleet[1]).warmup;assert(buy(p,'quartz_miner_focus'));eq(C.stats(p,p.fleet[1]).warmup,before/2)
 local seen={};for _,entry in ipairs(S.CATALOG) do if entry.role then seen[entry.shop]=true end end
 for _,key in ipairs(S.ORDER) do assert(seen[key],key..' has no hardware upgrade') end
 eq(buy(p,'violet_repair_kit'),false)
end)
print(passed..' production shop/profile/card checks passed (not Studio visual/multiplayer evidence)')
