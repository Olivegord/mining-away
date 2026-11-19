-- A full bag cashed out on the field: coins fly in and release exactly the
-- sale total, old replayed receipts credit quietly, reduced motion pays at once.
local UDim={new=function(a,b) return {Scale=a,Offset=b} end}
local stockNew=Instance.new
Color3.fromRGB=Color3.fromRGB or function(r,g,b) return Color3.new(r/255,g/255,b/255) end
local function vec2(x,y)
 return setmetatable({X=x,Y=y},{__add=function(a,b) return vec2(a.X+b.X,a.Y+b.Y) end,__sub=function(a,b) return vec2(a.X-b.X,a.Y-b.Y) end,
  __mul=function(a,b) if type(a)=='number' then a,b=b,a end;if type(b)=='number' then return vec2(a.X*b,a.Y*b) end;return vec2(a.X*b.X,a.Y*b.Y) end,
  __div=function(a,b) return vec2(a.X/b,a.Y/b) end,
  __index={Lerp=function(a,b,t) return vec2(a.X+(b.X-a.X)*t,a.Y+(b.Y-a.Y)*t) end}})
end
Vector2.new=vec2;Vector2.zero=vec2(0,0)
Instance.new=function(class)
 local i=stockNew(class)
 i.AbsolutePosition=vec2(0,0);i.AbsoluteSize=vec2(800,600)
 return i
end
function IM:FindFirstAncestorWhichIsA() return nil end
local paid,began={},0
local gui=Instance.new('Frame')
local bursts=0
RoleVisuals={ImpactParticles=function() bursts+=1 end}
local pl=player(3)
local reduced=false
local view=SaleView.new({player=pl,gui=gui,reducedMotion=function() return reduced end,onCommitted=function() end,
 hidden=function() return false end,audio={play=function() end},presentation={cameraBeat=function() end},
 hud={beginSale=function() began+=1 end,currencyTarget=function() return vec2(60,40) end,
  currencyHit=function(_,id,key,amount) paid[key]=(paid[key] or 0)+amount end}})
local receipt={id='auto-1',runId='run',full=false,auto=true,at=workspace:GetServerTimeNow(),cash=137,resources={Stone=12},cargo={}}
view:receive(receipt)
assert(began==1 and #view.cash==1 and bursts==1,'a fresh auto receipt starts a cash-out')
assert(not next(paid),'nothing is credited before the coins land')
local now=os.clock()
for _=1,200 do now+=1/60;view:update(now) end
assert(paid.Money==137 and paid.Stone==12,'coins must credit exactly the sale total')
assert(#view.cash==0,'cash-out cleans itself up')
-- An old receipt replayed on rejoin pays no animation.
local old={id='auto-0',runId='run',full=false,auto=true,at=workspace:GetServerTimeNow()-60,cash=50,resources={},cargo={}}
view:receive(old)
assert(#view.cash==0 and began==1,'old receipts must not replay a cash-out')
-- Reduced motion pays at once.
reduced=true
view:receive({id='auto-2',runId='run',full=false,auto=true,at=workspace:GetServerTimeNow(),cash=9,resources={},cargo={}})
assert(paid.Money==146,'reduced motion credits immediately')
print('PASS field cash-out credits the exact total once, skips old receipts, honors reduced motion (API doubles)')
