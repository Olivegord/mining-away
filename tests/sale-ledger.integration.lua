-- Exercise the production receipt beats without starting a Studio session.
local modified=Workshop.saleItem(Workshop.saleCargo('RunRuby',20,true,7,100,6,'Crown'))
local plain=Workshop.saleItem(Workshop.saleCargo('RunRuby',5,true,7,100))
modified.units=1;plain.units=2
local ledger=Ledger.new(Instance.new('ScreenGui'),{modified,plain})
ledger:layout(550,82,400,425)
local cash,ruby,stone=ledger.rows.Money,ledger.rows.Ruby,ledger.rows.Stone
local credits={}
local receipt={id='sale',full=true,cash=33,resources={Ruby=23,Stone=300}}
local view=setmetatable({active=receipt,ledger=ledger,refs={reducedMotion=function() return true end,
 hud={currencyHit=function(_,id,key,amount)
  assert(id==receipt.id)
  credits[key]=(credits[key] or 0)+amount
 end}}},SaleView)
ledger:quote({modified,plain})
assert(cash.total.Text=='$33' and ruby.total.Text=='0.23' and cash.amount==0, 'quote must not credit anything')
ledger:begin();assert(cash.total.Text=='$0')
view:breakRock({item=modified,drop={}},1,nil,100,nil,nil)
assert(cash.history[1].view.Text=='+ $23' and ruby.history[1].view.Text=='+ 0.09')
view:updateLedger(100.25,false)
assert(cash.amount==0 and next(credits)==nil)
view:updateLedger(100.33,false)
assert(cash.amount==23 and credits.Money==23 and credits.Ruby==9)
view:breakRock({item=plain,drop={}},2,nil,101,nil,nil)
view:updateLedger(101.20,false)
assert(cash.amount==23 and credits.Money==23,'plain ore must retain its payout travel beat')
view:updateLedger(101.33,false)
assert(cash.history[1].view.Text=='+ $10' and cash.history[2].view.Text=='$23')
assert(cash.history[2].view.Position[4]<cash.history[1].view.Position[4])
assert(cash.amount==33 and ruby.amount==23 and stone.amount==300)
assert(credits.Money==33 and credits.Ruby==23 and credits.Stone==300 and not view.pendingTerms)
ledger:finish(receipt,102)
ledger:update(160,false)
assert(cash.total.Text=='$33' and ruby.total.Text=='0.23' and stone.total.Text=='3')
assert(#ledger.rules==3)
print('PASS sale receipt: quoted totals, final addend, upward addition history, exact HUD credit and persistent totals')

assert(cash.title.Text=='Total' and ruby.title.Text=='Ruby shards' and stone.title.Text=='Stone')
assert(cash.rule.Parent==cash.root and ruby.rule.Parent==ruby.root and cash.rule~=ruby.rule)
assert(cash.history[1].itemName==plain.name..' ×2')
for i=1,4 do
 ledger:stage({{key='Money',base=10,bonus=0}},110+i,plain)
 ledger:add({{key='Money',base=10,bonus=0}},110+i)
end
local visible=cash.carried
for _,line in ipairs(cash.history) do visible+=line.value end
assert(visible==cash.amount and cash.earlier.Text~='', 'hidden history must remain in the displayed arithmetic')
ledger:layout(20,300,320,280)
assert(cash.root.Size[1]==320 and ruby.root.Position[1]==0 and ruby.root.Position[2]>0)
assert(not cash.terms.Visible and not cash.earlier.Visible and not cash.rule.Visible, 'summary must not duplicate the per-rock arithmetic')
ledger:update(160,true)
assert(cash.total.TextSize==35 and cash.totalScale.Scale==1)
local hidden=cash.carried
for i,line in ipairs(cash.history) do if i>cash.visibleHistory then hidden+=line.value end end
assert(cash.earlier.Text=='Earlier  + $'..hidden, 'compact stacks lost their hidden addends')
print('PASS separate named stacks, source ore identity, carried arithmetic, narrow layout and reduced-motion settling')
