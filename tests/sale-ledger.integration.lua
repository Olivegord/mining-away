-- Receipt handling is driven by the committed event or the same replicated receipt.
local paid,observed,shown= {},0,0
local function text()
 return {Text='',TextTransparency=0,TextStrokeTransparency=0,TextColor3=nil}
end
local view=SaleView.new({player={},
 reducedMotion=function() return true end,onCommitted=function() observed+=1 end,
 hidden=function() return false end,audio={play=function() end},
 hud={beginSale=function() end,currencyHit=function(_,id,key,amount) paid[key]=(paid[key] or 0)+amount end}})
function view:show(batch)
 shown+=1
 assert(batch.read.materials=='2 Stone  ·  0.18 Ruby shards')
 assert(batch.read.bonuses=='$6  ·  0.04 Ruby shards')
 assert(batch.read.items[1].cash==23 and batch.read.items[1].count==2)
 assert(#batch.groups==1 and batch.groups[1].cash==46 and batch.groups[1].bonus==6)
 local total,summary=text(),text()
 batch.gui={Visible=true,Destroy=function() end};batch.total=total;batch.totalScale={Scale=1};batch.summary=summary
 batch.materials=text();batch.milestone=text();batch.labels={total,summary}
end
local key=Workshop.saleCargo('RunRuby',20,true,7,100,6,'Crown')
local receipt={id='sale',runId='run',full=true,cargo={[key]=2},resources={Ruby=18,Stone=200},cash=46}
view:receiveProfile({run={id='run'},recentSales={receipt}})
view:receive(receipt)
assert(observed==1 and shown==0 and not next(paid))
view:update(view.batch.start)
assert(shown==1 and paid.Money==46 and paid.Ruby==18 and paid.Stone==200)
assert(view.batch.total.Text=='+$46')
assert(view.batch.summary.Text:find('modifiers %+%$6'))
view:update(view.batch.start+4)
assert(view.batch==nil and paid.Money==46)
print('PASS exact modifier receipt, one reduced-motion credit and automatic dismissal')

-- Display stacks: grouped by mineral and payout modifiers, best resolves last.
local Ledger=SaleView.Ledger
local cargo={}
for i=1,7 do cargo[Workshop.saleCargo('Amber',i,true,7,100,i%2==0 and 2 or 0,'Crown')]=1 end
local read=Ledger.read({cargo=cargo,resources={}})
local shownGroups,rest=Ledger.groups(read,5)
assert(#shownGroups==2 and rest.count==0)
assert(shownGroups[1].cash<shownGroups[2].cash)
local mixed={}
for _,material in ipairs({'Amber','RunRuby','Amber'}) do
 for mask=0,6,2 do mixed[Workshop.saleCargo(material,material=='Amber' and 3 or 9,true,7,100,mask,'Crown')]=2 end
end
local wide=Ledger.read({cargo=mixed,resources={}})
local top,others=Ledger.groups(wide,5)
local sum=others.cash
for i,group in ipairs(top) do
 sum+=group.cash
 if i>1 then assert(top[i-1].cash<=group.cash) end
end
local expected=0;for _,item in ipairs(wide.items) do expected+=item.cash*item.count end
assert(#top==5 and others.count>0 and sum==expected)
print('PASS sale stacks group by modifiers, order cheapest to best and keep the exact total')
