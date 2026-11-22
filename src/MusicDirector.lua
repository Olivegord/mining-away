-- Per-listener scheduling. Mining and sales are observations of game state.
local Music = {}
Music.__index = Music

-- opening: optional track contexts; one is picked at random and plays as
-- soon as it loads (the owner asked for this at the start, for testing).
function Music.new(random, now, opening)
 local self=setmetatable({
  random=random, quietUntil=now+random:NextNumber(55,95),
  lastSample=now, workTime=0, saleTimes={}, saleIds={},
 }, Music)
 if type(opening)=='table' and #opening>0 then
  self.opening=opening[random:NextInteger(1,#opening)]
  self.quietUntil=now
 end
 return self
end

function Music:observe(now,field,working)
 local elapsed=math.clamp(now-self.lastSample,0,1.5)
 self.lastSample=now
 if field~=self.field then
  self.field=field
  self.workTime=0
  self.workAt=nil
  self.workTarget=self.random:NextNumber(75,120)
  elapsed=0
 end
 if not field then return end
 if self.workAt and now-self.workAt>12 then self.workTime=0;self.workAt=nil end
 if working then
  self.workTime+=elapsed
  self.workAt=now
 end
end

function Music:sale(now,receipt)
 if type(receipt)~='table' or receipt.full~=true or type(receipt.id)~='string'
  or type(receipt.cash)~='number' or not (receipt.cash>0) then return end
 local sales=self.saleTimes
 while sales[1] and now-sales[1].at>300 do
  local old=table.remove(sales,1)
  self.saleIds[old.id]=nil
 end
 if self.saleIds[receipt.id] then return end
 self.saleIds[receipt.id]=true
 table.insert(sales,{id=receipt.id,at=now})
 if #sales>=3 and not sales[#sales-2].used then self.sellUntil=now+55 end
end

function Music:eligible(now)
 if now<self.quietUntil then return nil end
 if self.opening then return self.opening end
 if self.sellUntil and now<=self.sellUntil then return 'Sell' end
 if self.field and self.workAt and now-self.workAt<=12 and self.workTime>=self.workTarget then
  return self.field
 end
end

function Music:started(context)
 if context==self.opening then self.opening=nil;return end
 if context=='Sell' then
  -- Keep receipt IDs for dedupe, but require another three fresh sales.
  for _,sale in ipairs(self.saleTimes) do sale.used=true end
  self.sellUntil=nil
 else
  self.workTime=0
  self.workTarget=self.random:NextNumber(75,120)
 end
end

function Music:finished(now)
 self.quietUntil=now+self.random:NextNumber(150,300)
end

return Music
