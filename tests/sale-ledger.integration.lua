-- Drive the receipt presentation without opening Studio.
local paid,observed={},0
local origin=Vector3.new(4,2,1)
local root={Position=origin,CFrame={LookVector=Vector3.new(0,0,-1),RightVector=Vector3.new(1,0,0)}}
local view=SaleView.new({player={Character={FindFirstChild=function() return root end}},
 reducedMotion=function() return true end,onCommitted=function() observed+=1 end,
 audio={play=function() end},hud={beginSale=function() end,
 currencyHit=function(_,id,key,amount) paid[key]=amount end}})
function view:makeOre() return Instance.new('Part'),false end
local key=Workshop.saleCargo('RunRuby',5,true,7,100)
local receipt={id='sale',runId='run',cargo={[key]=100},resources={Ruby=7},cash=20,counter={10,2,1}}
view:receiveProfile({run={id='run'},recentSales={receipt}})
view:receive(receipt)
assert(#view.rocks==4 and observed==1)
for _,rock in ipairs(view.rocks) do
 assert(rock.target.X==10 and rock.origin.X==origin.X)
 rock.start=-10
end
view:update()
assert(#view.rocks==0 and paid.Money==20 and paid.Ruby==7)
print('PASS world-space sale endpoints, reduced motion cap, receipt deduplication and payout')
