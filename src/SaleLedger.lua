-- Counter readout for a server-priced manifest. Material amounts are in hundredths.
local Ledger={}

function Ledger.money(n)
 return '$'..string.format('%.0f',n):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
end

local function material(n)
 return (string.format('%.2f',n/100):gsub('0+$',''):gsub('%.$',''))
end

function Ledger.payout(cash,resources,wallet)
 local values={}
 if cash>0 then values[#values+1]=Ledger.money(cash) end
 for _,key in ipairs(Workshop.RESOURCE_ORDER) do
  local amount=resources[key] or 0
  if amount>0 then values[#values+1]=material(amount)..' '..Workshop.RESOURCE_NAMES[key] end
 end
 for _,key in ipairs(Shops.ORDER) do
  if wallet and wallet[key] then values[#values+1]=wallet[key]..' '..key end
 end
 return table.concat(values,'  ·  ')
end

function Ledger.items(cargo)
 local items,wallet={},{}
 for key,count in pairs(cargo) do
  if count<=0 then continue end
  local item=Workshop.saleItem(key)
  if not item then
   wallet[key]=count
   item={key=key,name=key,color=Shops.COLORS[key],rank=100,cash=0,resource=key,legacy=true}
  end
  item.count=count
  item.total=item.cash*count
  local resources={}
  if not item.legacy then
   resources[item.resource]=item.dust*count
   resources.Stone=(resources.Stone or 0)+item.stoneUnits*count
  end
  item.payout=Ledger.payout(0,resources,item.legacy and {[key]=count})
  items[#items+1]=item
 end
 table.sort(items,function(a,b)
  if a.rank~=b.rank then return a.rank<b.rank end
  if a.total~=b.total then return a.total>b.total end
  return a.key<b.key
 end)
 return items,wallet
end

function Ledger.detail(item)
 if item.legacy then return item.payout end
 local lines={Ledger.money(item.cash)..' each'}
 if item.cashBonus>0 then
  lines[#lines+1]=item.cashMods..' +'..Ledger.money(item.cashBonus)..' each'
 end
 if item.dustBonus>0 then
  lines[#lines+1]=item.dustMods..' +'..material(item.dustBonus)..' '..Workshop.RESOURCE_NAMES[item.resource]..' each'
 end
 return table.concat(lines,'\n')
end

return Ledger
