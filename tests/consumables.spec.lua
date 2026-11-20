local C=require('../src/Consumables')
local P=require('../src/Profile')
local passed=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS consumables '..name) end
check('first tools teach both actions without a lucky roll',function()
 local s=C.fresh();assert(C.validate(s))
 for i=1,2 do assert(C.onRock(s,1,0,0)==nil) end
 assert(C.onRock(s,1,.999,.999)=='Orbital');assert(C.collect(s,'Orbital'))
 for i=1,4 do assert(C.onRock(s,1,0,0)==nil) end
 assert(C.onRock(s,1,.999,0)=='Scrap');assert(C.collect(s,'Scrap'))
 assert(s.counts.Orbital==1 and s.counts.Scrap==1 and s.rocks==8 and s.misses==0)
end)
check('unlucky streak has an eight-rock ceiling and a full pocket cannot waste a reward',function()
 local s=C.fresh();s.collected=2;s.counts.Orbital=3
 for _=1,7 do assert(C.onRock(s,1,.999,0)==nil) end
 assert(C.onRock(s,1,.999,0)=='Scrap');assert(C.collect(s,'Scrap'))
 s.counts.Scrap=3;local rocks=s.rocks;assert(C.onRock(s,5,0,0)==nil and s.rocks==rocks)
end)
check('late fields improve discovery odds but ordinary breaks remain useful',function()
 local a,b=C.fresh(),C.fresh();a.collected=2;b.collected=2
 assert(C.onRock(a,1,.25,0)==nil);assert(C.onRock(b,5,.25,0)=='Orbital')
end)
check('reservation prevents replay and reserves refund space',function()
 local s=C.fresh();s.counts.Orbital=3
 assert(C.reserve(s,'Orbital',s.version,'tx','run'));assert(s.counts.Orbital==2)
 assert(not C.reserve(s,'Orbital',s.version,'tx2','run'));assert(not C.collect(s,'Orbital'))
 assert(C.validate(s));assert(C.refund(s));assert(s.counts.Orbital==3 and not C.refund(s))
 assert(not C.reserve(s,'Orbital',0,'tx','run'))
end)
check('only the first accepted contact spends a reserved charge',function()
 local s=C.fresh();s.counts.Scrap=2
 assert(C.reserve(s,'Scrap',0,'tx','run'));assert(C.accept(s));assert(not C.accept(s));assert(not C.refund(s))
 assert(s.counts.Scrap==1 and C.validate(s))
end)
check('v7 migration preserves fleet cargo cards and creates empty separate pockets',function()
 local p=P.new(44,123);p.schemaVersion=7;p.consumables=nil;p.run.cargo.Quartz=17
 p.fleet={p.fleet[1]};p.starterDrones=nil;p.nextDroneSerial=2
 p.run.cards={{cardId='F01',scope='Fleet',effects={mining=.15}}}
 local n=assert(P.migrate(p,44));assert(n.schemaVersion==P.SCHEMA and n.consumables.counts.Orbital==0)
 assert(n.run.cargo.Quartz==17 and n.run.cards[1].cardId=='F01' and n.fleet[1].id==p.fleet[1].id and #n.fleet==1)
end)
check('invalid future data fails closed rather than replacing inventory',function()
 for _,bad in ipairs({-1,4,.5,math.huge,0/0}) do local p=P.new(44,123);p.consumables.counts.Orbital=bad;assert(not P.migrate(p,44)) end
 local p=P.new(44,123);p.consumables.counts.Fake=1;assert(not P.migrate(p,44))
 p=P.new(44,123);p.consumables.pending={kind='Fake',txId='x',runId=p.run.id};assert(not P.migrate(p,44))
end)
check('reload recovers an unstarted reservation once and preserves earned stock',function()
 local p=P.new(44,123);p.consumables.counts.Orbital=2
 assert(C.reserve(p.consumables,'Orbital',0,'tx',p.run.id))
 local n=assert(P.migrate(p,44));assert(n.consumables.counts.Orbital==2 and not n.consumables.pending)
 local again=assert(P.migrate(n,44));assert(again.consumables.counts.Orbital==2)
 C.reserve(n.consumables,'Orbital',n.consumables.version,'tx2',n.run.id);C.accept(n.consumables)
 assert(P.migrate(n,44).consumables.counts.Orbital==1)
end)
check('prestige keeps consumables but resets run cards and adds exactly one drone',function()
 local p=P.new(44,123);p.consumables.counts.Orbital=2;p.consumables.collected=4
 p.run.cards={{cardId='F01',scope='Fleet',effects={mining=.15}}}
 local milestone=P.milestone(p);p.run.saleEarnings=milestone.earnings;p.run.quartzEarnings=milestone.earnings;if milestone.wins>0 then p.clearedFields[milestone.field]=true end
 assert(P.prestige(p,'prestige',p.run.id,{atDepot=true,confirmed=true}))
 assert(#p.fleet==4 and #p.run.cards==0 and p.consumables.counts.Orbital==2 and p.consumables.collected==4)
 assert(P.validate(p,44))
end)
-- Reproducible opportunity pacing, not a fun/retention measurement.
local seed=12345;local function random() seed=seed*16807%2147483647;return seed/2147483647 end
for tier=1,5 do
 local s=C.fresh();s.collected=2;local gaps={};local gap=0;local total=0
 for _=1,20000 do
  gap+=1;local kind=C.onRock(s,tier,random(),random())
  if kind then C.collect(s,kind);s.counts[kind]=0;table.insert(gaps,gap);total+=gap;gap=0 end
 end
 table.sort(gaps);assert(gaps[#gaps]<=8)
 print(string.format('PACING tier %d: mean %.2f eligible breaks; median %d; p90 %d; max %d',tier,total/#gaps,gaps[math.ceil(#gaps*.5)],gaps[math.ceil(#gaps*.9)],gaps[#gaps]))
end
print(passed..' consumable rule/profile checks; simulation is not player enjoyment evidence')
