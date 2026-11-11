local P=require('../src/Profile')
local C=require('../src/Cards')
local W=require('../src/Workshop')
local Roles=require('../src/DroneRoles')
local Mining=require('../src/Mining')
local DroneCatalog=require('../src/DroneCatalog')
local tests=0
local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));tests+=1;print('PASS workshop '..name) end
local function prestige(p,tx,runId)
 return P.prestige(p,tx,runId,{atDepot=true,confirmed=true,droneType=P.prestigePreview(p).droneChoices[1].kind})
end
local function funded(seed)
 local p=P.new(44,seed or 17);p.run.wallet.Quartz=10000;p.run.credits=10000;return p
end
local function buy(p,tx) return C.buy(p,tx,p.run.id,{atDepot=true,expectedPackIndex=p.run.packIndex}) end
local function choose(p,o,index,tx) assert(C.open(p,o.id));return C.select(p,o.id,index,tx,p.run.id,{atDepot=true}) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
 if type(a)~='table' then return a==b end
 if type(b)~='table' then return false end
 for k,v in pairs(a) do if not same(v,b[k]) then return false end end
 for k,v in pairs(b) do if not same(v,a[k]) then return false end end
 return true
end
test('three basic starter miners, no free packs or money',function()
 local p=P.new(44);eq(#p.fleet,3);eq(p.starterDrones,3);eq(p.nextDroneSerial,4)
 for serial,d in ipairs(p.fleet) do
  eq(d.id,'44:drone:'..serial);eq(d.type,'Blue')
  assert(Roles.isMiner(d.role) and d.base.maxStep60>=.2 and d.base.maxStep60<=.5)
 end
 local legacy=P.clone(p);legacy.fleet={legacy.fleet[1]};legacy.starterDrones=1;legacy.nextDroneSerial=2
 assert(same(legacy,assert(P.migrate(legacy,44))))
 eq(p.run.wallet.Quartz,0);eq(C.price(p),20);eq(buy(p,'empty'),false);eq(p.run.packIndex,0)
 assert(P.validate(p,44))
end)
test('first pack dispatch uses the actual manifest and counts only Quartz proceeds',function()
 local p=P.new(44)
 local rock=W.cargoKey('Quartz',10)
 local block=W.cargoKey('RunRuby',55,true)
 p.run.cargo={Cobalt=1,[rock]=2}
 assert(not P.firstPackDeliveryReady(p,2) and P.firstPackDeliveryReady(p,3))
 p.run.cargo={[block]=1}
 assert(P.firstPackDeliveryReady(p,4))
 local id=W.emptierId(p.run.id,1)
 assert(P.beginDelivery(p,id,'first-trip',p.run.id,4))
 p.run.cargo={[rock]=2}
 assert(not P.firstPackDeliveryReady(p,4),'an outstanding sale started a second rush trip')
 assert(P.finishDelivery(p,id,{},'first-trip',p.run.id))
 eq(p.run.wallet.Quartz,55)
 assert(not P.firstPackDeliveryReady(p,4))
 p.run.wallet.Quartz=10;p.run.credits=10;p.run.cargo={[rock]=1}
 assert(P.firstPackDeliveryReady(p,4),'a top-up failed to fund the pack')
 p.run.packIndex=1
 assert(not P.firstPackDeliveryReady(p,4))
end)
test('shared pool allows more than three owned upgrades and stable repeated drafts across 150 seeds',function()
 for seed=1,150 do
  local p=funded(seed)
  for pack=1,8 do
   local before=p.run.wallet.Quartz;local price=W.price(p)
   local ok,o=buy(p,'buy'..pack);assert(ok,o);eq(#o.choices,3);eq(before-p.run.wallet.Quartz,price)
   local seen={};local index=1;local smallest=math.huge
   for i,c in ipairs(o.choices) do
    assert(c.workshop and W.validate(c));assert(not seen[c.cardId]);seen[c.cardId]=true
    local owned=W.find(p,c.cardId);eq(c.stackBefore,owned and owned.level or 0)
    eq(c.level,1);assert(c.upgradeTier<=o.packTier);assert(#c.preview>0)
    if c.stackBefore<smallest then smallest=c.stackBefore;index=i end
   end
   local saved=P.clone(o);p=assert(P.migrate(p,44));assert(same(p.run.pendingOffer,saved))
   local again,replayed=buy(p,'other'..pack);assert(again);assert(same(saved,replayed));eq(p.run.wallet.Quartz,before-price)
   local selected=o.choices[index];assert(choose(p,o,index,'pick'..pack))
   eq(W.find(p,selected.cardId).level,selected.stackBefore+selected.level);assert(P.validate(p,44))
  end
  assert(#W.owned(p)>3,'former three-upgrade restriction survived')
 end
end)
test('every rarity grants one duplicate copy and guarantees a matching-tier option',function()
 for tier=1,4 do
  local entry;for _,e in ipairs(W.CATALOG) do if e.tier==tier then entry=e;break end end
  local p=funded();p.run.cards={W.card(entry,tier)}
  local choices,index
  for seed=1,100 do
   local offered=C.workshopOffer(p,tier,C.hash('duplicate:'..seed..':'..tier));assert(offered)
   local guaranteed=false
   for i,c in ipairs(offered) do
    eq(c.level,1);assert(c.upgradeTier<=tier);guaranteed=guaranteed or c.upgradeTier==tier
    if c.cardId==entry.id then choices,index=offered,i end
   end
   assert(guaranteed)
   if index then break end
  end
  assert(index,'owned upgrade never appeared again: '..entry.id)
  p.run.pendingOffer={id='saved:'..tier,runId=p.run.id,price=20,packIndex=1,packTier=tier,contentVersion=13,opened=true,choices=choices}
  p.run.wallet.Quartz=0;p.run.credits=0 -- The initial pack payment is the only payment.
  assert(P.validate(p,44));assert(C.select(p,p.run.pendingOffer.id,index,'pick',p.run.id,{atDepot=true}))
  eq(#W.owned(p),1);eq(W.find(p,entry.id).level,2);eq(p.run.wallet.Quartz,0)
  assert(P.validate(p,44));local restored=assert(P.migrate(p,44));assert(same(restored,p))
  local saved=P.clone(p);assert(C.select(p,'saved:'..tier,index,'pick',p.run.id,{atDepot=true}));assert(same(saved,p))
 end
 local p=funded();local prices={20,27,36,49,66,90}
 for i,price in ipairs(prices) do p.run.packIndex=i-1;eq(W.price(p),price) end
end)
test('hardware fits chosen permanent miners once each and clears on prestige',function()
 local p=funded()
 local first,second=p.fleet[1],p.fleet[2]
 local ok,offer=C.buy(p,'fit-pack',p.run.id,{atDepot=true,expectedPackIndex=0,crystalRun=true})
 assert(ok);eq(offer.choices[1].cardId,'Q_DOUBLE_BEAM');eq(#W.targets(p,offer.choices[1]),3)
 p=assert(P.migrate(p,44));assert(same(offer,p.run.pendingOffer));assert(C.open(p,offer.id))
 local function install(o,index,tx,target)
  return C.select(p,o.id,index,tx,p.run.id,{atDepot=true,targetDroneId=target})
 end
 assert(install(offer,1,'fit-one',second.id));assert(P.validate(p,44))
 eq(C.stats(p,p.fleet[1]).doubleBeam,0);eq(C.stats(p,p.fleet[2]).doubleBeam,1)
 eq(#W.targets(p,offer.choices[1]),2)
 assert(install(offer,1,'fit-one',second.id));eq(install(offer,1,'fit-one',first.id),false)
 local nextOffer=P.clone(offer);nextOffer.id='repeat-fit';nextOffer.opened=true
 p.run.pendingOffer=nextOffer
 eq(install(nextOffer,1,'already-fit',second.id),false);assert(install(nextOffer,1,'fit-two',first.id))
 eq(#p.run.cards,2);assert(P.validate(p,44));assert(same(p,assert(P.migrate(p,44))))
 local duplicate=P.clone(p);table.insert(duplicate.run.cards,P.clone(duplicate.run.cards[1]))
 eq(P.validate(duplicate,44),false)
 p.run.quartzEarnings=360
 assert(prestige(p,'reset-hardware',p.run.id))
 eq(#p.run.cards,0);eq(p.fleet[2].id,second.id);eq(C.stats(p,p.fleet[2]).doubleBeam,0)
end)
test('Crystal Run drafts trigger effects and offers Denser Packing only after Compactor',function()
 local p=funded()
 local function review(ownsPress)
  local sawBatch=false
  for tier=1,4 do for seed=1,80 do
   local offer=assert(C.workshopOffer(p,tier,C.hash('crystal:'..seed..':draft:'..tier),true))
   local trigger,rarity=false,false
   for _,choice in ipairs(offer) do
    trigger=trigger or W.TRIGGER_CARDS[choice.cardId]==true
    rarity=rarity or choice.upgradeTier==tier
    if choice.cardId=='Q_DENSER_PACK' then sawBatch=true end
   end
   assert(trigger and rarity)
  end end
  eq(sawBatch,ownsPress)
 end
 review(false)
 local ok,offer=C.buy(p,'first-press',p.run.id,{atDepot=true,expectedPackIndex=0,crystalRun=true})
 assert(ok);eq(offer.choices[3].cardId,'Q_CARGO');eq(offer.choices[2].rarity,'Common');eq(offer.choices[1].rarity,'Rare')
 -- Preserve a pack which was paid before Compactor left the catalog.
 p.run.pendingOffer.choices[3]=W.card(W.BY_ID.Q_COMPACTOR,2,0)
 p=assert(P.migrate(p,44));assert(choose(p,offer,3,'hire-press'))
 review(true)
 eq(W.compactorBatch(p,W.card(W.BY_ID.Q_DENSER_PACK,3)),5)
 eq(W.compactorBatch(p,W.card(W.BY_ID.Q_BATCH_PRESS,3)),2)
 eq(W.emptierBatch(p,W.card(W.BY_ID.Q_CARGO_RACK,2)),5)
 eq(W.emptierReady(4,4,nil,0),true)
 eq(W.emptierReady(2,4,10,15.99),false)
 eq(W.emptierReady(2,4,10,16),true)
 p.run.quartzEarnings=360
 assert(prestige(p,'reset-press',p.run.id));eq(W.hasCompactor(p),false)
end)
test('Crystal Run work compounds without resizing and refined sales fund Quartz progression',function()
 local starter=Mining.resource(75,'Crystal',1)
 for i,tier in ipairs(W.CRYSTAL_TIERS) do
  local rock=Mining.resource(75,'Crystal',tier.hardness)
  eq(rock.work,starter.work*3^(i-1));eq(rock.size,starter.size);eq(tier.value,4^(i-1))
 end
 local p=P.new(44)
 p.run.cargo={Quartz=2,Ruby=3,RunRuby=4,RunEmerald=1}
 local sold,receipt=P.sell(p,{Quartz=1,Ruby=2},'refined-sale',p.run.id)
 assert(sold);eq(receipt.credits,280);eq(p.run.wallet.Quartz,274);eq(p.run.wallet.Ruby,3);eq(p.run.quartzEarnings,274)
 assert(P.sell(p,{},'refined-sale',p.run.id));eq(p.run.wallet.Quartz,274);assert(P.validate(p,44))
end)
test('prestige exposes three stable choices and commits exactly one',function()
 local observed={}
 for seed=1,2048 do
  local choices=DroneCatalog.prestigeChoices(seed,1)
  eq(#choices,3);assert(same(choices,DroneCatalog.prestigeChoices(seed,1)))
  assert(choices[1].kind~=choices[2].kind and choices[2].kind~=choices[3].kind and choices[1].kind~=choices[3].kind)
  for _,entry in ipairs(choices) do observed[entry.kind]=true end
 end
 for _,reward in ipairs(DroneCatalog.PrestigeRewards) do assert(observed[reward.kind]) end
 local p=funded();p.run.quartzEarnings=360
 local preview=P.prestigePreview(p);assert(preview.eligible)
 local oldRun=p.run.id
 local context={atDepot=true,confirmed=true,droneType='unoffered'}
 assert(not P.prestige(p,'invalid',oldRun,context));eq(#p.fleet,3)
 context.droneType=preview.droneChoices[2].kind
 local ok,reward=P.prestige(p,'reward',oldRun,context)
 assert(ok);eq(reward.droneType,context.droneType);eq(reward.droneId,p.fleet[4].id)
 local replay,previous=P.prestige(p,'reward',oldRun,context)
 assert(replay and same(previous,reward));eq(#p.fleet,4)
 context.droneType=preview.droneChoices[1].kind
 assert(not P.prestige(p,'reward',oldRun,context));eq(#p.fleet,4)
end)
test('physical cargo takes one slot and sales preserve old ore and pressed value',function()
 local p=P.new(44)
 eq(C.capacity(p),10)
 local rock=W.cargoKey('Quartz',10)
 local deep=W.cargoKey('RunRuby',40)
 local block=W.cargoKey('RunCobalt',120,true)
 assert(P.addCargo(p,rock,8,10)==8)
 assert(P.addCargo(p,deep,1,10)==1)
 assert(P.addCargo(p,block,1,10)==1)
 assert(P.addCargo(p,deep,1,10)==0)
 assert(P.validate(p,44))
 local ok,sale=P.sell(p,{Quartz=1},'cargo-sale',p.run.id)
 assert(ok);eq(sale.units,10);eq(sale.quartz,240)
 p.run.stars=8
 assert(not P.buyStarUpgrade(p,'vacuum',0,'fresh-body',p.run.id))
 assert(not P.buyStarUpgrade(p,'cultivator',0,'another-body',p.run.id))
 eq(p.run.stars,8)
 p.run.starUpgrades.vacuum=1
 assert(P.validate(p,44));eq(W.starLevel(assert(P.migrate(p,44)),'vacuum'),1)
end)
test('Legendary is affordable after spending the last Quartz and exhausted tiers leave the roll',function()
 local sawLegendary=false
 for seed=1,1000 do
  local p=P.new(44,seed);p.run.wallet.Quartz=20;p.run.credits=20
  local ok,o=buy(p,'paid');assert(ok,o);eq(p.run.wallet.Quartz,0)
  local guaranteed=false
  for _,c in ipairs(o.choices) do guaranteed=guaranteed or c.upgradeTier==o.packTier end
  assert(guaranteed);assert(P.validate(p,44))
  if o.packTier==4 then
   local index;for i,c in ipairs(o.choices) do if c.upgradeTier==4 then index=i;break end end
   p=assert(P.migrate(p,44));assert(choose(p,o,index,'legendary'));eq(p.run.wallet.Quartz,0)
   eq(p.run.cards[1].level,1);eq(p.run.cards[1].rarity,'Legendary');sawLegendary=true;break
  end
 end
 assert(sawLegendary,'deterministic roll never generated Legendary')
 local p=funded();for _,e in ipairs(W.CATALOG) do if e.tier==1 then local c=W.card(e,1);c.level=e.max;c.effects=W.effects(c,c.level);table.insert(p.run.cards,c) end end
 local ok,o=buy(p,'exhausted-common');assert(ok,o);assert(o.packTier>1);assert(P.validate(p,44))
end)
test('rare mechanics do not appear beside strictly inferior versions in the same offer',function()
 local p=funded()
 local function values(c)
  local st=C.stats(p,p.fleet[1],c);st.backpack=C.capacity(p,c);st.warmup=-st.warmup;return st
 end
 for tier=1,4 do for seed=1,60 do
  local choices=C.workshopOffer(p,tier,C.hash('choice:'..seed..':'..tier));assert(choices)
  for i=1,2 do for j=i+1,3 do
   local a,b=values(choices[i]),values(choices[j]);local aBetter,bBetter=false,false
   for k,v in pairs(a) do if type(v)=='number' then
    if v>b[k]+1e-8 then aBetter=true elseif v<b[k]-1e-8 then bBetter=true end
   end end
   assert(aBetter and bBetter,'strictly inferior choice in paid pack')
  end end
 end end
end)
test('owned count and paid choices fail closed when altered; v11 paid upgrades survive',function()
 local p=funded();p.run.cards={W.card(W.CATALOG[1],1)}
 local choices=C.workshopOffer(p,1,42)
 p.run.pendingOffer={id='frozen',runId=p.run.id,price=20,packIndex=1,packTier=1,contentVersion=13,opened=true,choices=choices}
 assert(P.validate(p,44));p.run.pendingOffer.choices[1].stackBefore+=1;eq(P.validate(p,44),false)
 p=funded();local legacy={W.card(W.CATALOG[1],2),W.card(W.CATALOG[2],2),W.card(W.CATALOG[3],2)}
 for _,c in ipairs(legacy) do c.stackVersion=nil;c.upgradeTier=nil;c.level=2;c.rarity='Rare';c.effects=W.effects(c,2) end
 p.run.pendingOffer={id='legacy11',runId=p.run.id,price=45,packIndex=2,packTier=2,contentVersion=11,opened=true,choices=legacy}
 local saved=P.clone(p.run.pendingOffer);p=assert(P.migrate(p,44));assert(same(p.run.pendingOffer,saved))
 assert(C.select(p,'legacy11',1,'legacy-choice',p.run.id,{atDepot=true}));eq(W.find(p,'Q_POWER').level,2)
end)
test('repeat prices rise, every accepted level improves stats, caps do not charge',function()
 for _,entry in ipairs(W.CATALOG) do
  local p=funded();p.run.cards={W.card(entry,1)};local last=0
  for level=1,entry.max-1 do
   local cost=W.levelCost(p.run.cards[1]);assert(cost>last);last=cost
   local wallet=p.run.wallet.Quartz;local ok,r=C.upgrade(p,entry.id,level,'level'..level,p.run.id,{atDepot=true});assert(ok,r)
   eq(p.run.wallet.Quartz,wallet-cost);eq(r.level,level+1);eq(p.run.credits,p.run.wallet.Quartz);assert(P.validate(p,44))
   local replay,receipt=C.upgrade(p,entry.id,level,'level'..level,p.run.id,{atDepot=true});assert(replay);assert(same(receipt,r));eq(p.run.wallet.Quartz,wallet-cost)
   eq(C.upgrade(p,entry.id,level,'new stale',p.run.id,{atDepot=true}),false)
  end
  local wallet=p.run.wallet.Quartz;eq(C.upgrade(p,entry.id,entry.max,'max',p.run.id,{atDepot=true}),false);eq(p.run.wallet.Quartz,wallet)
 end
end)
test('unowned, unfunded, remote, combat and conflicting receipts fail without mutations',function()
 local p=funded();local before=P.clone(p)
 eq(C.upgrade(p,'Q_POWER',1,'hack',p.run.id,{atDepot=true}),false);assert(same(p,before))
 p.run.cards={W.card(W.CATALOG[1],1)}
 eq(C.upgrade(p,'Q_POWER',1,'hack',p.run.id,{}),false)
 eq(C.upgrade(p,'Q_POWER',1,'hack',p.run.id,{atDepot=true,activeEncounter=true}),false)
 p.run.wallet.Quartz=0;p.run.credits=0;eq(C.upgrade(p,'Q_POWER',1,'poor',p.run.id,{atDepot=true}),false)
 p.run.wallet.Quartz=100;p.run.credits=100;assert(C.upgrade(p,'Q_POWER',1,'tx',p.run.id,{atDepot=true}))
 eq(C.upgrade(p,'Q_CARGO',1,'tx',p.run.id,{atDepot=true}),false)
 local ok,o=buy(p,'pending');assert(ok);eq(C.upgrade(p,'Q_POWER',2,'pending-up',p.run.id,{atDepot=true}),false)
 assert(choose(p,o,1,'select'));eq(C.select(p,o.id,2,'select',p.run.id,{atDepot=true}),false)
end)
test('existing caps exclude useless drafts and prevent charging for capped levels',function()
 local p=funded();p.run.cards={{cardId='old',scope='Fleet',effects={mining=3,capacity=2,yield=1}}}
 local o=C.workshopOffer(p,4,42);assert(o)
 for _,c in ipairs(o) do assert(c.cardId~='Q_POWER' and c.cardId~='Q_CARGO' and c.cardId~='Q_YIELD') end
 table.insert(p.run.cards,W.card(W.CATALOG[1],1));local wallet=p.run.wallet.Quartz
 eq(C.upgrade(p,'Q_POWER',1,'cap',p.run.id,{atDepot=true}),false);eq(p.run.wallet.Quartz,wallet)
 p.run.cards={{cardId='old',scope='Fleet',effects={mining=3,capacity=2,yield=1,speed=2,startup=100,fork=.4,forkRange=6,plotAuto=1}}}
 local capped=W.card(W.BY_ID.Q_SPLIT,2);capped.level=4;capped.effects=W.effects(capped,4);table.insert(p.run.cards,capped)
 eq(buy(p,'exhausted'),false);eq(p.run.wallet.Quartz,wallet)
end)
test('Quartz alone advances prestige, upgrades do not subtract progress, resets retain exact fleet',function()
 local p=P.new(44);local id=p.fleet[1].id;local base=P.clone(p.fleet[1].base)
 p.run.cargo={Ruby=40};assert(P.sell(p,{Quartz=1,Ruby=2},'ruby',p.run.id));eq(p.run.quartzEarnings,0);eq(P.prestigePreview(p).eligible,false)
 p.run.cargo={Quartz=360};assert(P.sell(p,{Quartz=1},'quartz',p.run.id));eq(p.run.quartzEarnings,360)
 local ok,o=buy(p,'buy');assert(ok);eq(P.prestigePreview(p).eligible,false);assert(choose(p,o,1,'pick'))
 assert(P.prestigePreview(p).eligible);eq(p.run.quartzEarnings,360)
 local oldRun=p.run.id;assert(prestige(p,'prestige',oldRun));eq(#p.fleet,4);eq(p.fleet[1].id,id);assert(same(p.fleet[1].base,base))
 eq(#p.run.cards,0);eq(p.run.wallet.Quartz,0);eq(p.run.quartzEarnings,0);eq(C.price(p),20);assert(Roles.isWorker(p.fleet[4].role));eq(C.stats(p,p.fleet[1]).miningDPS,37.5)
 assert(P.validate(p,44));local restored=assert(P.migrate(p,44));assert(same(p,restored))
 eq(C.upgrade(p,o.choices[1].cardId,1,'stale',oldRun,{atDepot=true}),false)
 for i=2,12 do
  p.run.quartzEarnings=P.milestone(p).earnings;p.run.saleEarnings=p.run.quartzEarnings
  assert(prestige(p,'prestige'..i,p.run.id));assert(Roles.isWorker(p.fleet[#p.fleet].role));assert(P.validate(p,44))
 end
end)
test('v8 profiles keep all ownership, modifiers and already-paid offers exactly',function()
 local p=funded();p.schemaVersion=8;p.run.quartzEarnings=nil;p.run.saleEarnings=177
 p.starterDrones=nil;p.fleet={p.fleet[1]};p.nextDroneSerial=2
 p.run.shopLevels.quartz_power=2
 p.run.cards={{cardId='F01',scope='Fleet',effects={mining=.25},rarity='Common'}}
 local old={id=p.run.id..':pack:legacy',runId=p.run.id,price=80,packIndex=1,contentVersion=10,choices={
  {cardId='F06',scope='Player',effects={capacity=.35}},
  {cardId='D05',scope='Individual',targetDroneId=p.fleet[1].id,effects={startup=1}},
  {cardId='F08',scope='Fleet',effects={yield=.20}},
 }}
 p.run.pendingOffer=P.clone(old);local restored=assert(P.migrate(p,44));eq(restored.schemaVersion,P.SCHEMA);eq(restored.starterDrones,1);eq(C.capacity(restored),10);eq(restored.run.quartzEarnings,177)
 assert(same(restored.fleet,p.fleet));assert(same(restored.run.cards,p.run.cards));assert(same(restored.run.pendingOffer,old))
 local ok,o=buy(restored,'legacy');assert(ok);assert(same(o,old));assert(C.select(restored,o.id,2,'legacy-pick',restored.run.id,{atDepot=true}))
 eq(restored.run.shopLevels.quartz_power,2);assert(P.validate(restored,44))
 restored.run.cards[1].workshop=true;eq(P.validate(restored,44),false)
end)
test('pack Stars credit once, Star Shop survives reload, and prestige resets both',function()
 local p=funded();local ok,offer=buy(p,'star-pack');assert(ok)
 local chosen,result=choose(p,offer,1,'star-pick');assert(chosen)
 eq(result.stars,offer.packTier);eq(p.run.stars,offer.packTier)
 assert(C.select(p,offer.id,1,'star-pick',p.run.id,{atDepot=true}));eq(p.run.stars,offer.packTier)
 p.run.stars=6
 assert(P.buyStarUpgrade(p,'selector',0,'wide',p.run.id));eq(p.run.stars,4);eq(W.selectorWidth(p),34)
 assert(P.buyStarUpgrade(p,'selector',0,'wide',p.run.id));eq(p.run.stars,4)
 eq(P.buyStarUpgrade(p,'selector',0,'stale',p.run.id),false);eq(p.run.stars,4)
 eq(P.buyStarUpgrade(p,'autosell',0,'unfunded',p.run.id),false)
 p=assert(P.migrate(p,44));eq(p.run.stars,4);eq(W.selectorWidth(p),34)
 p.run.quartzEarnings=360
 assert(prestige(p,'prestige-stars',p.run.id))
 eq(p.run.stars,0);eq(W.selectorWidth(p),30);eq(#p.fleet,4)
end)
test('pacing model quantifies first-level tradeoffs including selling travel',function()
 local p=P.new(44);local d=p.fleet[1]
 local function rate(profile)
  local st=C.stats(profile,d);local node=Mining.resource(75,'Crystal',1)
  local seconds=2.5/st.speedMultiplier+st.warmup+Mining.duration('Blue','Crystal',node.work,st.miningDPS)
  local ore=10*st.yieldMultiplier
  -- 14s round-trip walking/sale overhead; no fork or automatic-target benefit assumed.
  return 60*ore/(seconds+14*ore/C.capacity(profile)),seconds
 end
 local baseline,seconds=rate(p)
 print(string.format('MODEL baseline %.2f Quartz/min, %.2fs/job incl flight/warmup; excludes human decision time and cascades',baseline,seconds))
 for _,entry in ipairs(W.CATALOG) do
  local q=P.clone(p);q.run.cards={W.card(entry,1)}
  if W.isHardware(q.run.cards[1]) then q.run.cards[1].targetDroneId=q.fleet[1].id end
  local first=rate(q)
  local delta=first/baseline-1
  print(string.format('MODEL %s level1 %.2f Quartz/min (%+.1f%%)',entry.id,first,delta*100))
  if entry.id=='Q_POWER' or entry.id=='Q_IGNITION' or entry.id=='Q_CARGO' or entry.id=='Q_YIELD' then assert(delta>0,entry.id..' must improve the modeled loop') end
 end
end)
print(tests..' WORKSHOP checks passed (logic/model; not human enjoyment or native multiplayer)')
