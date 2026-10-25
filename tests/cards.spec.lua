local P=require('../src/Profile')
local C=require('../src/Cards')
local passed=0
local function test(name,f) local ok,err=pcall(f);assert(ok,name..': '..tostring(err));passed=passed+1;print('PASS cards '..name) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local function entry(id,target)
 for _,c in ipairs(C.CATALOG) do if c.cardId==id then local x=P.clone(c);x.targetDroneId=target;return x end end;error(id)
end
local function funded(seed) local p=P.new(44,seed or 123);p.run.credits=1000000;return p end
local function buy(p,id,visible)
 return C.buy(p,id,p.run.id,{expectedPackIndex=p.run.packIndex,combatVisible=visible~=false,atDepot=true})
end
local function ready(p) local m=P.milestone(p);p.run.saleEarnings=m.earnings;p.run.wins[m.field]=m.wins end
local function same(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not same(v,b[k]) then return false end end;for k in pairs(b) do if a[k]==nil then return false end end;return true
end
test('first six prices and explicit pack index',function()
 local p=funded();local expected={80,110,150,210,290,400,520,676}
 for i,price in ipairs(expected) do p.run.packIndex=i-1;eq(C.price(p),price) end
 eq(C.buy(p,'stale',p.run.id,{expectedPackIndex=0,combatVisible=true}),false)
end)
test('purchase creates three distinct resolved useful choices and debits once',function()
 local p=funded();local credits=p.run.credits;local ok,o=buy(p,'buy1');eq(ok,true);eq(#o.choices,3);eq(p.run.credits,credits-80);eq(p.run.packIndex,1)
 local seen={};for _,c in ipairs(o.choices) do assert(not seen[c.cardId]);seen[c.cardId]=true;assert(#c.preview>0);eq(c.expires,'This run');if c.scope=='Individual' then eq(c.targetDroneId,p.fleet[1].id) end end
 local ok2,replay=buy(p,'buy1');eq(ok2,true);assert(same(o,replay));eq(p.run.credits,credits-80)
end)
test('new purchase IDs while pending cannot reroll or charge',function()
 local p=funded();local _,o=buy(p,'buy1');local credits=p.run.credits
 for i=1,20 do local ok,n=buy(p,'other'..i);eq(ok,true);assert(same(n,o)) end;eq(p.run.credits,credits)
end)
test('reconnect exact offer and random target replay',function()
 local p=funded();local _,o=buy(p,'buy1');local loaded=P.migrate(p,44);assert(loaded);assert(same(o,loaded.run.pendingOffer))
 local ok,n=buy(loaded,'reopen');eq(ok,true);assert(same(n,o))
end)
test('choose exactly one, conflicting selection rejects, duplicate selection replays',function()
 local p=funded();local _,o=buy(p,'buy1');local ok,result=C.select(p,o.id,2,'pick1',p.run.id,{atDepot=true});eq(ok,true);eq(#p.run.cards,1);eq(p.run.cards[1].cardId,o.choices[2].cardId);eq(p.run.pendingOffer,nil)
 for i=1,10 do local a,b=C.select(p,o.id,2,'pick1',p.run.id,{atDepot=true});eq(a,true);assert(same(result,b)) end
 eq(C.select(p,o.id,1,'pick-conflict',p.run.id,{atDepot=true}),false);eq(#p.run.cards,1)
end)
test('invalid selection and own combat reject without closing offer',function()
 local p=funded();local _,o=buy(p,'buy1')
 for _,i in ipairs({0,-1,4,0/0,math.huge,'1',{}}) do eq(C.select(p,o.id,i,'bad'..tostring(i),p.run.id,{atDepot=true}),false) end
 eq(C.select(p,o.id,1,'combat',p.run.id,{activeEncounter=true}),false);eq(p.run.pendingOffer.id,o.id);eq(#p.run.cards,0)
end)
test('Blue wide speed affects all only Blue at additive base',function()
 local p=funded();ready(p);P.prestige(p,'p1',p.run.id,{atDepot=true,confirmed=true});ready(p);P.prestige(p,'p2',p.run.id,{atDepot=true,confirmed=true});ready(p);P.prestige(p,'p3',p.run.id,{atDepot=true,confirmed=true})
 p.run.cards={entry('C01'),entry('F02')}
 for _,d in ipairs(p.fleet) do near(C.stats(p,d).maxStep60,d.base.maxStep60*(d.type=='Blue' and 2.2 or 1.2)) end
end)
test('named startup halves warmup alone, never active damage',function()
 local p=funded();local d=p.fleet[1];local base=C.stats(p,d);p.run.cards={entry('D05',d.id)};local a=C.stats(p,d)
 near(a.warmup,base.warmup/2);near(a.miningDPS,base.miningDPS);near(a.combatDPS,base.combatDPS)
 table.insert(p.run.cards,entry('F07'));near(C.stats(p,d).warmup,d.base.warmup/2.3)
end)
test('run mods remain on same permanent ID through reprint/reload',function()
 local p=funded();local id=p.fleet[1].id;p.run.cards={entry('D05',id),entry('C01')};local stats=C.stats(p,p.fleet[1])
 for _=1,10 do p=P.migrate(p,44);eq(p.fleet[1].id,id);near(C.stats(p,p.fleet[1]).warmup,stats.warmup);near(C.stats(p,p.fleet[1]).maxStep60,stats.maxStep60) end
end)
test('all final modifier caps, positive startup floor and combined DPS cap',function()
 local p=funded();local d=p.fleet[1]
 p.run.cards={ {cardId='stress',scope='Fleet',effects={mining=100,speed=100,combat=100,rate=100,health=100,startup=100,range=100,yield=100,crit=100,reduction=100,splash=100,fork=100,shield=100,capacity=100}} }
 local s=C.stats(p,d);near(s.miningDPS,d.base.miningDPS*4);near(s.maxStep60,d.base.maxStep60*3);near(s.combatDPS,d.base.combatDPS*4);near(s.shotDamage/s.shotInterval,s.combatDPS);near(s.maxHealth,d.base.maxHealth*4);near(s.warmup,.08);near(s.yieldMultiplier,2);near(s.range,d.base.range*1.6);near(s.critChance,.3);near(s.damageReduction,.5);eq(s.capacity,360);assert(s.shotInterval>=.15)
end)
test('spent packs never reduce cumulative sale prestige progress',function()
 local p=funded();p.run.saleEarnings=2000;p.run.wins.Cobalt=1;local _,o=buy(p,'buy1');eq(p.run.saleEarnings,2000);C.select(p,o.id,1,'pick1',p.run.id,{atDepot=true});eq(P.prestigePreview(p).eligible,true)
end)
test('stale paid offer cannot apply after prestige',function()
 local p=funded();local old=p.run.id;local _,o=buy(p,'buy1');C.select(p,o.id,1,'pick1',old,{atDepot=true});ready(p);P.prestige(p,'p1',old,{atDepot=true,confirmed=true})
 eq(C.select(p,o.id,1,'different',old),false);eq(#p.run.cards,0);eq(#p.fleet,2)
end)
test('no absent type, no duplicate card, no inaccessible combat option',function()
 for seed=1,100 do
  local p=funded(seed);local ok,o=buy(p,'buy1',false);eq(ok,true)
  local seen={};for _,c in ipairs(o.choices) do assert(not seen[c.cardId]);seen[c.cardId]=true;if c.scope=='Color' then eq(c.type,'Blue') end;assert(not c.effects.combat and not c.effects.health or (c.effects.health or 0)<0);assert(not c.effects.reduction and not c.effects.crit and not c.effects.splash and not c.effects.rate and not c.effects.shield) end
 end
end)
test('offer protection never produces three offers without combat',function()
 local isCombat=function(c) local e=c.effects;return (e.combat or 0)>0 or (e.health or 0)>0 or (e.reduction or 0)>0 or (e.shield or 0)>0 or (e.crit or 0)>0 or (e.splash or 0)>0 or (e.rate or 0)>0 or (e.finisher or 0)>0 or (e.salvage or 0)>0 end
 for seed=1,40 do
  local p=funded(seed);local streak=0
  for i=1,8 do local ok,o=buy(p,'b'..i);eq(ok,true);local yes=false;for _,c in ipairs(o.choices) do yes=yes or isCombat(c) end;streak=yes and 0 or streak+1;assert(streak<=2);eq(p.run.offersWithoutCombat,streak);eq(C.select(p,o.id,1,'s'..i,p.run.id,{atDepot=true}),true) end
 end
end)
test('exhausted caps never debit for useless choices',function()
 local p=funded();p.run.cards={{cardId='caps',scope='Fleet',effects={mining=100,speed=100,combat=100,rate=100,health=100,startup=100,range=100,yield=100,crit=100,reduction=100,splash=100,fork=100,shield=100,capacity=100,finisher=100,geode=100,salvage=100,chain=100,forkRange=100}}}
 local credits=p.run.credits;eq(buy(p,'no-use'),false);eq(p.run.credits,credits);eq(p.run.pendingOffer,nil)
end)
test('bounded receipt eviction cannot replay stale purchase pack index',function()
 local p=funded();local _,o=buy(p,'buy1');C.select(p,o.id,1,'pick1',p.run.id,{atDepot=true})
 for i=1,100 do P.record(p,'Other','x'..i,{}) end
 eq(C.buy(p,'buy1',p.run.id,{expectedPackIndex=0,combatVisible=true}),false);eq(p.run.packIndex,1)
end)
test('choice effects are frozen rather than looked up in changed catalog',function()
 local p=funded();local _,o=buy(p,'buy1');local chosen=P.clone(o.choices[1]);local catalog=C.CATALOG;C.CATALOG={}
 local ok,r=C.select(p,o.id,1,'pick1',p.run.id,{atDepot=true});eq(ok,true);assert(same(r.card.effects,chosen.effects));C.CATALOG=catalog
end)
print(passed..' cards tests passed')
test('individual target randomness is persisted across six owned identities',function()
 local seen,offered={},0
 for seed=1,150 do
  local p=funded(seed)
  for i=1,5 do ready(p);P.prestige(p,'prestige'..i,p.run.id,{atDepot=true,confirmed=true}) end
  p.run.credits=1000000
  local ok,o=buy(p,'buy1');eq(ok,true)
  for _,c in ipairs(o.choices) do if c.cardId=='D05' then
   seen[c.targetDroneId]=true;offered=offered+1
   local owned=false;for _,d in ipairs(p.fleet) do if d.id==c.targetDroneId then owned=true;eq(c.targetName,d.name) end end;eq(owned,true)
   local loaded=P.migrate(p,44);assert(loaded);eq(loaded.run.pendingOffer.id,o.id)
  end end
 end
 local count=0;for _ in pairs(seen) do count=count+1 end;assert(offered>2);assert(count>=2,'Targets were not varied')
end)
test('owned stack limits and per-drone unique cards excluded',function()
 for seed=1,100 do
  local p=funded(seed);p.run.cards={entry('F01'),entry('F01'),entry('C01'),entry('D05',p.fleet[1].id)}
  local ok,o=buy(p,'buy1');eq(ok,true)
  for _,c in ipairs(o.choices) do assert(c.cardId~='F01' and c.cardId~='C01' and c.cardId~='D05') end
 end
end)
print(passed..' FINAL cards tests passed')
test('signature upgrades expose bounded distinct mechanics and survive saved offers',function()
 local p=funded();local d=p.fleet[1]
 for _,id in ipairs({'D13','D14','D15','D16','F09'}) do table.insert(p.run.cards,entry(id,d.id)) end
 local s=C.stats(p,d)
 near(s.finisherMultiplier,1.75);near(s.geodeMultiplier,1.8);near(s.salvageFraction,.3);near(s.splashRange,22);near(s.forkRange,12)
 near(s.splashFraction,.25);near(s.forkFraction,.2);near(s.maxStep60,d.base.maxStep60*.85)
 local loaded=assert(P.migrate(p,44));assert(same(loaded.run.cards,p.run.cards));eq(P.validate(loaded,44),true)
 local fresh=funded();local ok,o=buy(fresh,'described');eq(ok,true)
 for _,c in ipairs(o.choices) do assert(c.headline and c.purpose and c.tradeoff and c.stackText and c.category);for _,line in ipairs(c.preview) do assert(line.label~='Flight / 60Hz') end end
end)
print(passed..' TOTAL cards tests passed')
