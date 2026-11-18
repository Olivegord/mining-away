-- Format a committed manifest using the same per-rock economics as the server.
local Ledger={}

function Ledger.money(n)
 return '$'..string.format('%.0f',n):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
end

local function material(n)
 return (string.format('%.2f',n/100):gsub('0+$',''):gsub('%.$',''))
end

function Ledger.read(receipt)
 local items,materials={},{}
 local units,cashBonus=0,0
 local dustBoost={}
 for key,count in pairs(receipt.cargo) do
  units+=count
  local item=Workshop.saleItem(key)
  if item then
   item.count=count
   items[#items+1]=item
   cashBonus+=item.cashBonus*count
   dustBoost[item.resource]=(dustBoost[item.resource] or 0)+item.dustBonus*count
  else
   materials[#materials+1]=count..' '..key
  end
 end
 table.sort(items,function(a,b)
  if a.cash~=b.cash then return a.cash>b.cash end
  if a.dust~=b.dust then return a.dust>b.dust end
  return a.key<b.key
 end)
 table.sort(materials)
 local bonuses={}
 if cashBonus>0 then bonuses[#bonuses+1]=Ledger.money(cashBonus) end
 for _,key in ipairs(Workshop.RESOURCE_ORDER) do
  local n=(receipt.resources or {})[key] or 0
  if n>0 then materials[#materials+1]=material(n)..' '..Workshop.RESOURCE_NAMES[key] end
  if (dustBoost[key] or 0)>0 then bonuses[#bonuses+1]=material(dustBoost[key])..' '..Workshop.RESOURCE_NAMES[key] end
 end
 return {items=items,units=units,materials=table.concat(materials,'  ·  '),bonuses=table.concat(bonuses,'  ·  ')}
end
return Ledger
