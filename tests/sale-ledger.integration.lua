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
view:breakRock({item=modified,drop={}},1,nil,100,nil,nil)
assert(cash.history[1].view.Text=='+ $20' and ruby.history[1].view.Text=='+ 0.07')
view:updateLedger(100.14,false)
assert(cash.amount==0 and next(credits)==nil)
view:updateLedger(100.16,false)
assert(cash.history[1].view.Text=='Charged +$3  →  + $23')
assert(ruby.history[1].view.Text=='Frosted +0.02  →  + 0.09' and next(credits)==nil)
view:updateLedger(100.40,false)
assert(cash.amount==23 and credits.Money==23 and credits.Ruby==9)
view:breakRock({item=plain,drop={}},2,nil,101,nil,nil)
view:updateLedger(101.20,false)
assert(cash.history[1].view.Text=='+ $10' and cash.history[2].view.Text=='+ $23')
assert(cash.history[2].view.Position[4]<cash.history[1].view.Position[4])
assert(cash.amount==33 and ruby.amount==23 and stone.amount==300)
assert(credits.Money==33 and credits.Ruby==23 and credits.Stone==300 and not view.pendingTerms)
ledger:finish(receipt,102)
ledger:update(160,false)
assert(cash.total.Text=='$33' and ruby.total.Text=='0.23' and stone.total.Text=='3')
assert(ledger.progress.Text=='Sale complete')
print('PASS sale receipt: base term, modifier beat, upward addition history, exact HUD credit and persistent totals')
