-- The pack draft and repeat purchases live in one compact Quartz workshop.
local V={}
local function number(n) return string.format('%.3g',n) end
local function previewText(rows)
 local result={}
 for _,r in ipairs(rows or {}) do
  if #result<2 then table.insert(result,r.label..': '..number(r.before)..' → '..number(r.after)..(r.unit or '')) end
 end
 return table.concat(result,'\n')
end
function V.render(U,parent,options)
 local p,width=options.profile,options.width
 local ink=U.palette.ink;local rows=p.workshop or {};local slots=#Workshop.owned(p)
 local price=Workshop.price(p);local pending=p.run.pendingOffer
 local hero=U.panel(parent,UDim2.fromOffset(0,2),UDim2.fromOffset(width,144),Color3.fromRGB(81,210,188),14)
 U.text(hero,UDim2.fromOffset(14,9),UDim2.new(1,-28,0,26),'MINE → DRAFT → LEVEL UP → PRESTIGE',width<400 and 15 or 18,ink,true)
 U.text(hero,UDim2.fromOffset(14,37),UDim2.new(1,-28,0,43),'Choose 1 of 3 blueprints. Keep 3 this run.\nBuy their next levels here; each level costs more.',16,ink)
 local action=pending and (pending.opened==false and 'Open your delivered crate' or 'Choose your blueprint')
  or price and ('New blueprint · '..price..' Quartz  ('..slots..'/3 slots)') or 'Build chosen · level your blueprints'
 local buy=U.button(hero,UDim2.fromOffset(12,88),UDim2.new(1,-24,0,44),action,options.onPack,Color3.fromRGB(35,113,161))
 buy.Name='BuyWorkshopPack';buy.TextSize=16
 U.setEnabled(buy,options.canBuy and (pending~=nil or price~=nil and Shops.balance(p,'Quartz')>=price))
 local colors={{121,211,248},{255,210,86},{113,231,149},{209,150,255}}
 for i,name in ipairs(Workshop.TIERS) do
  local chip=U.panel(parent,UDim2.fromOffset((i-1)*width/4,156),UDim2.fromOffset(width/4-5,48),Color3.fromRGB(unpack(colors[i])),9)
  local label=U.text(chip,UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4),name..'\nLevel '..i,width<400 and 13 or 15,ink,true);label.TextXAlignment=Enum.TextXAlignment.Center
 end
 local columns=width>=620 and 3 or 1;local gap=10;local cellWidth=(width-gap*(columns-1))/columns
 for index=1,3 do
  local row=rows[index];local c=row and row.card;local entry=c and Workshop.BY_ID[c.cardId]
  local color=entry and Color3.fromRGB(unpack(entry.color)) or Color3.fromRGB(103,144,184)
  local cell=U.panel(parent,UDim2.fromOffset((index-1)%columns*(cellWidth+gap),218+math.floor((index-1)/columns)*204),UDim2.fromOffset(cellWidth,194),color,12)
  cell.Name='BlueprintSlot'..index
  U.icon(cell,entry and entry.icon or 'cards',UDim2.fromOffset(12,12),UDim2.fromOffset(28,28),ink)
  U.text(cell,UDim2.fromOffset(47,10),UDim2.new(1,-59,0,30),c and c.title or ('Build slot '..index),17,ink,true)
  U.text(cell,UDim2.fromOffset(12,43),UDim2.new(1,-24,0,22),c and ('Level '..c.level..' / '..c.maxLevel..' · '..c.rarity) or 'Filled by your next pack',14,ink,true)
  local detail=c and (row.next and previewText(row.next.preview) or 'Fully upgraded for this build.') or 'A new mechanic, or more levels in the ones you already picked?'
  U.text(cell,UDim2.fromOffset(12,72),UDim2.new(1,-24,0,64),detail,16,ink)
  if c then
   local text=row.reason or ('Level '..(c.level+1)..' · '..row.cost..' Quartz')
   local button=U.button(cell,UDim2.fromOffset(10,144),UDim2.new(1,-20,0,40),text,function() options.onBuy(c,c.level) end,color:Lerp(Color3.new(0,0,0),.62))
   button.Name='LevelBlueprint_'..c.cardId;button.TextSize=16
   U.setEnabled(button,options.canBuy and not pending and row.next~=nil and Shops.balance(p,'Quartz')>=row.cost)
  end
 end
 local y=218+math.ceil(3/columns)*204
 local pre=p.prestigePreview or {};local earned=pre.earnings or 0;local needed=pre.saleRequired or Workshop.PRESTIGE_BASE
 local progress=U.panel(parent,UDim2.fromOffset(0,y),UDim2.fromOffset(width,90),Color3.fromRGB(159,119,225),12)
 U.text(progress,UDim2.fromOffset(12,7),UDim2.new(1,-24,0,27),tostring(earned)..' / '..tostring(needed)..' Quartz sold · spending keeps progress',width<400 and 14 or 16,ink,true)
 local prestige=U.button(progress,UDim2.fromOffset(10,40),UDim2.new(1,-20,0,40),pre.eligible and 'Prestige ready · review your new drone' or 'Next prestige: +1 mining drone · review',options.onPrestige,Color3.fromRGB(96,52,160))
 prestige.Name='WorkshopPrestige';prestige.TextSize=16
end
return V
