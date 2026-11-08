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
test('one real starter drone, no free packs or money',function()
 local p=P.new(44);eq(#p.fleet,1);eq(p.run.wallet.Quartz,0);eq(C.price(p),20);eq(buy(p,'empty'),false);eq(p.run.packIndex,0)
 assert(P.validate(p,44))
end)
test('three distinct useful choices, bounded slots, stable persisted delivery across 150 seeds',function()
 for seed=1,150 do
  local p=funded(seed)
  for slot=1,3 do
   local before=p.run.wallet.Quartz;local price=W.PACK_PRICES[slot]
   local ok,o=buy(p,'buy'..slot);assert(ok,o);eq(#o.choices,3);eq(before-p.run.wallet.Quartz,price)
   local seen={}
   for _,c in ipairs(o.choices) do
    assert(c.workshop and W.validate(c));assert(not seen[c.cardId]);seen[c.cardId]=true
    assert(not W.find(p,c.cardId));eq(c.level,o.packTier);assert(#c.preview>0)
   end
   local saved=P.clone(o);p=assert(P.migrate(p,44));assert(same(p.run.pendingOffer,saved))
   local again,replayed=buy(p,'other'..slot);assert(again);assert(same(saved,replayed));eq(p.run.wallet.Quartz,before-price)
   local index=seed%3+1;assert(choose(p,o,index,'pick'..slot));eq(#W.owned(p),slot);assert(P.validate(p,44))
  end
  local wallet=p.run.wallet.Quartz;eq(buy(p,'fourth'),false);eq(p.run.wallet.Quartz,wallet);eq(W.price(p),nil)
 end
end)
test('rarity guarantees 1/2/3/4 real starting levels for every blueprint',function()
 for _,entry in ipairs(W.CATALOG) do
  local previous=0
  for tier=1,4 do
   local p=funded();local c=W.card(entry,tier);assert(W.validate(c));p.run.cards={c}
   local st=C.stats(p,p.fleet[1]);local value
   if entry.id=='Q_POWER' then value=st.miningDPS
   elseif entry.id=='Q_IGNITION' then value=1/st.warmup
   elseif entry.id=='Q_CARGO' then value=C.capacity(p)
   elseif entry.id=='Q_YIELD' then value=st.yieldMultiplier
   elseif entry.id=='Q_SCANNER' then value=st.maxStep60;eq(st.plotAuto,1)
   else value=st.forkFraction;eq(st.forkRange,12) end
   assert(value>previous,entry.id..' rarity has no consequence');previous=value
  end
 end
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
 local o=C.workshopOffer(p,1,42);assert(o)
 for _,c in ipairs(o) do assert(c.cardId~='Q_POWER' and c.cardId~='Q_CARGO' and c.cardId~='Q_YIELD') end
 table.insert(p.run.cards,W.card(W.CATALOG[1],1));local wallet=p.run.wallet.Quartz
 eq(C.upgrade(p,'Q_POWER',1,'cap',p.run.id,{atDepot=true}),false);eq(p.run.wallet.Quartz,wallet)
 p.run.cards={{cardId='old',scope='Fleet',effects={mining=3,capacity=2,yield=1,speed=2,startup=100,fork=.2,forkRange=6,plotAuto=1}}}
 eq(buy(p,'exhausted'),false);eq(p.run.wallet.Quartz,wallet)
end)
test('Quartz alone advances prestige, upgrades do not subtract progress, resets retain exact fleet',function()
 local p=P.new(44);local id=p.fleet[1].id;local base=P.clone(p.fleet[1].base)
 p.run.cargo={Ruby=40};assert(P.sell(p,{Quartz=1,Ruby=2},'ruby',p.run.id));eq(p.run.quartzEarnings,0);eq(P.prestigePreview(p).eligible,false)
 p.run.cargo={Quartz=360};assert(P.sell(p,{Quartz=1},'quartz',p.run.id));eq(p.run.quartzEarnings,360)
 local ok,o=buy(p,'buy');assert(ok);eq(P.prestigePreview(p).eligible,false);assert(choose(p,o,1,'pick'))
 assert(P.prestigePreview(p).eligible);eq(p.run.quartzEarnings,360)
 local oldRun=p.run.id;assert(P.prestige(p,'prestige',oldRun,{atDepot=true,confirmed=true}));eq(#p.fleet,2);eq(p.fleet[1].id,id);assert(same(p.fleet[1].base,base))
 eq(#p.run.cards,0);eq(p.run.wallet.Quartz,0);eq(p.run.quartzEarnings,0);eq(C.price(p),20);assert(Roles.isWorker(p.fleet[2].role));eq(C.stats(p,p.fleet[1]).miningDPS,37.5)
 assert(P.validate(p,44));local restored=assert(P.migrate(p,44));assert(same(p,restored))
 eq(C.upgrade(p,o.choices[1].cardId,1,'stale',oldRun,{atDepot=true}),false)
 for i=2,12 do
  p.run.quartzEarnings=P.milestone(p).earnings;p.run.saleEarnings=p.run.quartzEarnings
  assert(P.prestige(p,'prestige'..i,p.run.id,{atDepot=true,confirmed=true}));assert(Roles.isWorker(p.fleet[#p.fleet].role));assert(P.validate(p,44))
 end
end)
test('v8 profiles keep all ownership, modifiers and already-paid offers exactly',function()
 local p=funded();p.schemaVersion=8;p.run.quartzEarnings=nil;p.run.saleEarnings=177
 p.run.shopLevels.quartz_power=2
 p.run.cards={{cardId='F01',scope='Fleet',effects={mining=.25},rarity='Common'}}
 local old={id=p.run.id..':pack:legacy',runId=p.run.id,price=80,packIndex=1,contentVersion=10,choices={
  {cardId='F06',scope='Player',effects={capacity=.35}},
  {cardId='D05',scope='Individual',targetDroneId=p.fleet[1].id,effects={startup=1}},
  {cardId='F08',scope='Fleet',effects={yield=.20}},
 }}
 p.run.pendingOffer=P.clone(old);local restored=assert(P.migrate(p,44));eq(restored.schemaVersion,9);eq(restored.run.quartzEarnings,177)
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
  if entry.id~='Q_SPLIT' and entry.id~='Q_SCANNER' then assert(delta>.07,entry.id..' first level is imperceptible in pacing model') end
 end
end)
print(tests..' WORKSHOP checks passed (logic/model; not human enjoyment or native multiplayer)')
