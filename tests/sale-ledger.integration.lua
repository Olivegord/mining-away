-- Receipt handling is driven by the committed event or the same replicated receipt.
local paid,observed,shown= {},0,0
local view=SaleView.new({player={},
 reducedMotion=function() return true end,onCommitted=function() observed+=1 end,
 hidden=function() return false end,audio={play=function() end},
 hud={beginSale=function() end,currencyHit=function(_,id,key,amount) paid[key]=(paid[key] or 0)+amount end}})
function view:show(batch)
 shown+=1
 assert(batch.read.materials=='2 Stone  ·  0.18 Ruby shards')
 assert(batch.read.bonuses=='$6  ·  0.04 Ruby shards')
 assert(batch.read.items[1].cash==23 and batch.read.items[1].count==2)
end
local key=Workshop.saleCargo('RunRuby',20,true,7,100,6,'Crown')
local receipt={id='sale',runId='run',full=true,cargo={[key]=2},resources={Ruby=18,Stone=200},cash=46}
view:receiveProfile({run={id='run'},recentSales={receipt}})
view:receive(receipt)
assert(observed==1 and shown==0 and not next(paid))
view:update(view.batch.start)
assert(shown==1 and paid.Money==46 and paid.Ruby==18 and paid.Stone==200)
view:update(view.batch.start+4)
assert(view.batch==nil and paid.Money==46)
print('PASS exact modifier receipt, one reduced-motion credit and automatic dismissal')
