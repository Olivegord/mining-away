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
 return {items=items,units=units,cashBonus=cashBonus,materials=table.concat(materials,'  ·  '),bonuses=table.concat(bonuses,'  ·  ')}
end

-- One display stack per mineral and payout modifier set. Shown stacks run
-- from cheapest to best, so the most valuable rock resolves last.
function Ledger.groups(read,limit)
 local byId,list={},{}
 for _,item in ipairs(read.items) do
  local id=item.material..'|'..tostring(item.stone)..'|'..tostring(item.pressed)..'|'..item.bonusMask
  local group=byId[id]
  if not group then
   group={item=item,count=0,cash=0,bonus=0,dustBonus=0}
   byId[id]=group;list[#list+1]=group
  end
  group.count+=item.count;group.cash+=item.cash*item.count
  group.bonus+=item.cashBonus*item.count;group.dustBonus+=item.dustBonus*item.count
 end
 table.sort(list,function(a,b)
  if a.cash~=b.cash then return a.cash>b.cash end
  return a.item.key<b.item.key
 end)
 local shown,rest={},{count=0,cash=0,bonus=0}
 for i,group in ipairs(list) do
  if i<=limit then shown[#shown+1]=group
  else rest.count+=group.count;rest.cash+=group.cash;rest.bonus+=group.bonus end
 end
 table.sort(shown,function(a,b)
  if a.cash~=b.cash then return a.cash<b.cash end
  return a.item.key<b.item.key
 end)
 return shown,rest
end
return Ledger
