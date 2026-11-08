local P=require('../src/Profile')
local C=require('../src/Cards')
local W=require('../src/Workshop')
local Roles=require('../src/DroneRoles')
local Mining=require('../src/Mining')
local tests=0
local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));tests+=1;print('PASS workshop '..name) end
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
test('four real starter miners, no free packs or money',function()
 local p=P.new(44);eq(#p.fleet,4);for _,d in ipairs(p.fleet) do assert(Roles.isMiner(d.role) and d.base.maxStep60>=.2 and d.base.maxStep60<=.5) end;eq(p.run.wallet.Quartz,0);eq(C.price(p),20);eq(buy(p,'empty'),false);eq(p.run.packIndex,0)
 assert(P.validate(p,44))
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
 local oldRun=p.run.id;assert(P.prestige(p,'prestige',oldRun,{atDepot=true,confirmed=true}));eq(#p.fleet,5);eq(p.fleet[1].id,id);assert(same(p.fleet[1].base,base))
 eq(#p.run.cards,0);eq(p.run.wallet.Quartz,0);eq(p.run.quartzEarnings,0);eq(C.price(p),20);assert(Roles.isWorker(p.fleet[5].role));eq(C.stats(p,p.fleet[1]).miningDPS,37.5)
 assert(P.validate(p,44));local restored=assert(P.migrate(p,44));assert(same(p,restored))
 eq(C.upgrade(p,o.choices[1].cardId,1,'stale',oldRun,{atDepot=true}),false)
 for i=2,12 do
  p.run.quartzEarnings=P.milestone(p).earnings;p.run.saleEarnings=p.run.quartzEarnings
  assert(P.prestige(p,'prestige'..i,p.run.id,{atDepot=true,confirmed=true}));assert(Roles.isWorker(p.fleet[#p.fleet].role));assert(P.validate(p,44))
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
 p.run.pendingOffer=P.clone(old);local restored=assert(P.migrate(p,44));eq(restored.schemaVersion,11);eq(restored.starterDrones,1);eq(C.capacity(restored),40);eq(restored.run.quartzEarnings,177)
 assert(same(restored.fleet,p.fleet));assert(same(restored.run.cards,p.run.cards));assert(same(restored.run.pendingOffer,old))
 local ok,o=buy(restored,'legacy');assert(ok);assert(same(o,old));assert(C.select(restored,o.id,2,'legacy-pick',restored.run.id,{atDepot=true}))
 eq(restored.run.shopLevels.quartz_power,2);assert(P.validate(restored,44))
 restored.run.cards[1].workshop=true;eq(P.validate(restored,44),false)
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
  local q=P.clone(p);q.run.cards={W.card(entry,1)};local first=rate(q)
  local delta=first/baseline-1
  print(string.format('MODEL %s level1 %.2f Quartz/min (%+.1f%%)',entry.id,first,delta*100))
  if entry.id=='Q_POWER' or entry.id=='Q_IGNITION' or entry.id=='Q_CARGO' or entry.id=='Q_YIELD' then assert(delta>0,entry.id..' must improve the modeled loop') end
 end
end)
print(tests..' WORKSHOP checks passed (logic/model; not human enjoyment or native multiplayer)')
