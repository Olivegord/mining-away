local Profile=require('../src/Profile')
local Cards=require('../src/Cards')
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local p=Profile.new(44,123);local d=p.fleet[1]
local original=Cards.stats(p,d)
near(original.warmup,3.2);near(d.base.warmup,.8)
local function entry(id)
 for _,c in ipairs(Cards.CATALOG) do if c.cardId==id then local v=Profile.clone(c);v.targetDroneId=d.id;return v end end
 error(id)
end
p.run.cards={entry('D05')}
local quick=Cards.stats(p,d)
near(quick.warmup,1.6);near(quick.miningDPS,original.miningDPS);near(quick.combatDPS,original.combatDPS)
table.insert(p.run.cards,entry('F07'));near(Cards.stats(p,d).warmup,3.2/2.5)
local id=d.id
for _=1,5 do p=Profile.migrate(p,44);d=p.fleet[1];assert(d.id==id);near(d.base.warmup,.8);near(Cards.stats(p,d).warmup,3.2/2.5) end
print('PASS longer charge, unchanged permanent traits, startup modifiers, active damage and reload stability')
