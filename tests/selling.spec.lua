local P=require('../src/Profile')
local W=require('../src/Workshop')
local S=require('../src/Shops')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local p=P.new(44,17)
local rock=W.saleCargo('RunRuby',3,true,7,100)
local gem=W.saleCargo('RunRuby',80,false,100,0)
local diamond=W.saleCargo('Diamond',76,true,7,100)
p.run.cargo={[rock]=2,[gem]=1,[diamond]=1}
local ok,sale=P.sell(p,{},'sale-a',p.run.id);assert(ok)
eq(sale.quartz,162);eq(p.run.resources.Stone,300);eq(p.run.resources.Ruby,114);eq(p.run.resources.Diamond,7)
eq(p.run.wallet.Quartz,162);eq(P.cargoUnits(p),0)
local _,again=P.sell(p,{},'sale-a',p.run.id);eq(again.quartz,162);eq(p.run.resources.Ruby,114)
assert(P.validate(p,44));local loaded=assert(P.migrate(p,44));eq(loaded.run.resources.Ruby,114)
local carrier=W.emptierId(p.run.id,1)
p.run.cargo={[rock]=1}
assert(P.beginDelivery(p,carrier,'trip-a',p.run.id,1))
assert(P.finishDelivery(p,carrier,{},'trip-a',p.run.id));eq(p.run.resources.Ruby,121)
assert(P.finishDelivery(p,carrier,{},'trip-a',p.run.id));eq(p.run.resources.Ruby,121)
local old=P.new(45,18);old.schemaVersion=12;old.run.resources=nil;old.run.wallet.Quartz=777;old.run.credits=777
old.run.cargo={[W.cargoKey('Diamond',256)]=2}
local migrated=assert(P.migrate(old,45));eq(migrated.run.wallet.Quartz,777);eq(migrated.run.cargo[W.cargoKey('Diamond',256)],2)
eq(migrated.fleet[1].id,old.fleet[1].id);assert(next(migrated.run.resources)==nil)
local corrupt=P.clone(p);corrupt.run.resources.Ruby=-1;assert(not P.validate(corrupt,44));assert(not P.migrate(corrupt,44))
corrupt=P.clone(p);corrupt.run.resources.Ruby=0/0;assert(not P.validate(corrupt,44))
corrupt=P.clone(p);corrupt.run.resources.Ruby=1.1;assert(not P.validate(corrupt,44))
local cap=P.new(46,20);cap.run.resources.Ruby=1e14-1
local before=cap.run.wallet.Quartz
assert(not S.deposit(cap.run,{[rock]=1}));eq(cap.run.wallet.Quartz,before);eq(cap.run.resources.Ruby,1e14-1)
local a,b=W.saleItem(rock),W.saleItem(rock)
local merged=W.saleCargo('RunRuby',a.cash+b.cash,true,a.dust+b.dust,a.stoneUnits+b.stoneUnits)
local x,y=P.new(47),P.new(48)
assert(S.deposit(x.run,{[rock]=2}));assert(S.deposit(y.run,{[merged]=1}))
eq(x.run.resources.Stone,y.run.resources.Stone);eq(x.run.resources.Ruby,y.run.resources.Ruby);eq(x.run.wallet.Quartz,y.run.wallet.Quartz)
for _,tier in ipairs(W.CRYSTAL_TIERS) do
 local actual=W.saleItem(W.saleCargo(tier.material,tier.value*8,false,100,0))
 local pity=W.saleItem(W.saleCargo(tier.material,math.max(1,math.floor(tier.value*.3)),true,7,100))
 assert(pity.dust/actual.dust>=.04 and pity.dust/actual.dust<=.10)
 assert(actual.cash>=pity.cash*8);assert(pity.rank<actual.rank)
end
print('PASS selling: mixed rewards, exact 7% dust, replay safety, courier parity, reload, migration, fail-closed validation, atomic overflow and merge conservation')
