-- Drive the quote and receipt state machine with UI doubles.
local paid,observed,sent={},0,{}
local root={Position=Vector3.new(4,2,1)}
local view=SaleView.new({player={Character={FindFirstChild=function() return root end}},
 requestId=function() return 'quote-request' end,
 send=function(action,id) sent[#sent+1]={action,id} end,
 reducedMotion=function() return true end,onCommitted=function() observed+=1 end,
 notify=function() error('unexpected rejection') end,audio={play=function() end},
 hud={beginSale=function() end,currencyHit=function(_,id,key,amount) paid[key]=amount end}})
function view:show(quote)
 self.quote=quote;self.phase='quote'
 self.confirmButton={};self.heading={};self.status={}
end
local key=Workshop.saleCargo('RunRuby',20,true,7,100,6,'Crown')
local quote={kind='quote',request='quote-request',id='sale',runId='run',cargo={[key]=2},units=2,
 resources={Ruby=18,Stone=200},cash=46,station={4,2,1},radius=20,expires=100}
view:receiveProfile({run={id='run'}})
view:open()
view:receive(table.clone(quote))
view:receive(table.clone(quote))
assert(view.quote.id=='sale' and #sent==1 and sent[1][1]=='QuoteSale' and observed==0)
view:confirm();view:confirm()
assert(#sent==2 and sent[2][1]=='Sell' and sent[2][2]=='sale' and next(paid)==nil)
local receipt={id='sale',runId='run',full=true,cargo=quote.cargo,resources=quote.resources,cash=quote.cash,counter={4,2,1}}
view:receiveProfile({run={id='run'},recentSales={receipt}})
view:receive(receipt)
assert(observed==1 and paid.Money==46 and paid.Ruby==18 and paid.Stone==200)
assert(view.phase=='sold' and view.heading.Text=='Sold   ·   2 pieces')
view:confirm();assert(not view.quote and #sent==2)
print('PASS counter quote confirmation, receipt deduplication, exact credits and dismissal')
