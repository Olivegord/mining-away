-- Compact Roblox-style upgrade rows: recognizable icon, stack count, effect and price.
local V={}
local INK=Color3.fromRGB(29,48,74)
local BLUE=Color3.fromRGB(29,132,211)
local WHITE=Color3.fromRGB(255,255,255)
local function rounded(U,parent,pos,size,color,edge)
 local box=U.frame(parent,pos,size,color);U.corner(box,12);U.stroke(box,edge or Color3.fromRGB(170,197,218),2)
 return box
end
local function label(U,parent,pos,size,text,pixels,bold)
 local t=U.text(parent,pos,size,text,pixels,INK,bold)
 t.Font=bold and Enum.Font.FredokaOne or Enum.Font.SourceSansSemibold
 return t
end
local function action(U,parent,pos,size,text,callback,enabled,color)
 local b=U.button(parent,pos,size,text,callback,color or Color3.fromRGB(124,227,69))
 U.unskin(b);U.corner(b,10);U.stroke(b,Color3.fromRGB(48,95,47),2)
 U.setEnabled(b,enabled);b.BackgroundColor3=enabled and (color or Color3.fromRGB(124,227,69)) or Color3.fromRGB(224,232,238)
 b.TextColor3=enabled and Color3.fromRGB(28,66,37) or Color3.fromRGB(94,115,131)
 b.TextStrokeTransparency=1;b.Font=Enum.Font.FredokaOne;b.TextSize=15;b.TextWrapped=true
 return b
end
local function percent(value) return string.format('%g%%',value*100) end
function V.effect(c)
 local e=c.effects;local parts={}
 if e.battery then table.insert(parts,'+'..e.battery..' battery') end
 if e.plotAuto then table.insert(parts,'Auto retarget in side fields') end
 if e.aftershock then table.insert(parts,'Laser cracks echo '..percent(e.aftershock)..' of rock health nearby') end
 if e.reclaim then table.insert(parts,'+'..e.reclaim..' battery per crystal broken') end
 if e.earlyDrop then table.insert(parts,'Cracks release +'..percent(e.earlyDrop)..' ore early with longer pickup reach') end
 if e.fieldCharge then table.insert(parts,'Recharge at the pin · '..e.fieldCharge..' battery/s') end
 if e.deepCut then table.insert(parts,'+'..percent(e.deepCut)..' laser damage in Ruby through Emerald') end
 if e.magnetRange then table.insert(parts,'+'..e.magnetRange..' studs of ore pickup reach') end
 for _,k in ipairs({'mining','startup','capacity','speed','yield','fork'}) do
  if e[k] then
   local names={mining='mining power',startup='startup rate',capacity='backpack',speed='flight speed',yield='ore yield',fork='nearby damage'}
   table.insert(parts,(k=='fork' and '' or '+')..percent(e[k])..' '..names[k])
  end
 end
 return table.concat(parts,' · ')
end
local function nextEffect(row)
 local r=row.next and row.next.preview and row.next.preview[1]
 if not r then return row.reason or 'Fully stacked' end
 local unit=r.unit or '';if unit~='' and unit~='%' and unit~='×' then unit=' '..unit end
 return string.format('Next: %s %g → %g%s',r.label,r.before,r.after,unit)
end
function V.decorate(U,sheet,title,subtitle,close)
 U.unskin(sheet);sheet.BackgroundColor3=Color3.fromRGB(247,252,255);U.corner(sheet,20);U.stroke(sheet,INK,4)
 title.Font=Enum.Font.FredokaOne;title.Text='Quartz Workshop';title.TextSize=22
 title.TextColor3=BLUE;title.TextStrokeTransparency=1
 subtitle.TextColor3=INK;subtitle.Font=Enum.Font.SourceSansSemibold;subtitle.TextSize=16
 U.unskin(close);U.corner(close,10);U.stroke(close,Color3.fromRGB(116,34,58),3)
 close.BackgroundColor3=Color3.fromRGB(244,78,113);close.TextColor3=WHITE;close.Font=Enum.Font.FredokaOne;close.TextSize=25;close.TextStrokeTransparency=1
end
local GOLD=Color3.fromRGB(255,221,119)
local PALE_BLUE=Color3.fromRGB(225,245,255)
local function tab(U,parent,width,title,onChange)
 action(U,parent,UDim2.fromOffset(2,2),UDim2.fromOffset(width-4,40),title,onChange,true,GOLD)
end
function V.render(U,parent,options)
 local p,width=options.profile,options.width
 local pending=p.run.pendingOffer
 local price,balance=Workshop.price(p),Shops.balance(p,'Quartz')
 local ore=options.cargo or p.cargoUnits or 0
 local narrow=width<560
 local y=2
 if options.onStars then
  tab(U,parent,width,'Automation  ·  '..(p.run.stars or 0)..' Stars',options.onStars)
  y=52
 end
 local packWidth=narrow and width-4 or math.floor((width-14)/2)
 local sale=rounded(U,parent,UDim2.fromOffset(2,y),UDim2.fromOffset(packWidth,122),WHITE)
 sale.Name='WorkshopSale'
 label(U,sale,UDim2.fromOffset(12,7),UDim2.fromOffset(packWidth-24,25),balance..' Quartz available',19,true)
 label(U,sale,UDim2.fromOffset(12,32),UDim2.fromOffset(packWidth-24,37),ore>0 and 'Sell what you picked up to fund upgrades.' or 'Collect ore in the field and bring it here.',15,false)
 local sell=action(U,sale,UDim2.fromOffset(12,75),UDim2.fromOffset(packWidth-24,37),
  ore>0 and 'Sell '..ore..' ore' or 'Backpack empty',options.onSell,options.onSell~=nil and options.canBuy and ore>0)
 sell.Name='SellWorkshopOre'
 local pack=rounded(U,parent,UDim2.fromOffset(narrow and 2 or packWidth+12,narrow and y+132 or y),UDim2.fromOffset(packWidth,122),PALE_BLUE,BLUE)
 pack.Name='UpgradePack'
 local starter=options.crystalRun and p.run.packIndex==0
 local packTitle=starter and 'First upgrade pack' or 'Upgrade pack'
 if pending then packTitle=pending.opened==false and 'Your crate is waiting' or 'Your three choices are ready' end
 label(U,pack,UDim2.fromOffset(12,7),UDim2.fromOffset(packWidth-24,25),packTitle,19,true)
 local detail=starter and 'Pick a mining upgrade and earn 2 Stars.' or 'Pick 1 of 3 upgrades and earn 1–4 Stars.'
 if pending then detail=pending.opened==false and 'Open the delivered crate beside the stand.' or 'Your pack already includes one upgrade.'
 elseif balance<price then detail='Sell '..(price-balance)..' more Quartz to afford this pack.' end
 label(U,pack,UDim2.fromOffset(12,32),UDim2.fromOffset(packWidth-24,37),detail,15,false)
 local packText=pending and (pending.opened==false and 'Return to crate' or 'Choose upgrade') or ('Buy pack · '..price..' Quartz')
 local buy=action(U,pack,UDim2.fromOffset(12,75),UDim2.fromOffset(packWidth-24,37),packText,
  options.onPack,options.canBuy and (pending~=nil or balance>=price))
 buy.Name='BuyWorkshopPack'
 y+=narrow and 266 or 134

 local pre=p.prestigePreview or {}
 local earned,needed=pre.earnings or 0,pre.saleRequired or Workshop.PRESTIGE_BASE
 local goalWidth=width-(narrow and 28 or 178)
 local goal=rounded(U,parent,UDim2.fromOffset(2,y),UDim2.fromOffset(width-4,narrow and 120 or 80),
  Color3.fromRGB(242,233,255),Color3.fromRGB(166,124,213))
 goal.Name='PrestigeProgress'
 label(U,goal,UDim2.fromOffset(12,7),UDim2.fromOffset(goalWidth,24),'Next reward · 1 permanent drone',18,true)
 label(U,goal,UDim2.fromOffset(12,31),UDim2.fromOffset(goalWidth,22),earned..' / '..needed..' Quartz sold',15,false)
 local bar=rounded(U,goal,UDim2.fromOffset(12,58),UDim2.fromOffset(goalWidth,6),WHITE,WHITE)
 local fill=U.frame(bar,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(earned/math.max(1,needed),0,1),1),Color3.fromRGB(154,104,215))
 U.corner(fill,4)
 action(U,goal,UDim2.fromOffset(narrow and 12 or width-154,narrow and 73 or 20),UDim2.fromOffset(narrow and width-28 or 140,38),
  pre.eligible and 'Prestige ready' or 'View prestige',options.onPrestige,true,Color3.fromRGB(211,177,255))
 y+=narrow and 130 or 90
 label(U,parent,UDim2.fromOffset(4,y),UDim2.fromOffset(width-8,29),'Installed upgrades · this run',18,true)
 y+=34

 local rows=p.workshop or {}
 if #rows==0 then
  label(U,parent,UDim2.fromOffset(4,y),UDim2.fromOffset(width-12,40),'Pick an upgrade from a pack to install it. Buy more stacks here.',15,false)
 end
 for _,row in ipairs(rows) do
  local c=row.card
  local entry=Workshop.BY_ID[c.cardId]
  local color=Color3.fromRGB(unpack(entry.color))
  local h=narrow and 144 or 106
  local card=rounded(U,parent,UDim2.fromOffset(2,y),UDim2.fromOffset(width-4,h),WHITE);card.Name='Upgrade_'..entry.id
  local icon=rounded(U,card,UDim2.fromOffset(10,12),UDim2.fromOffset(42,42),color:Lerp(WHITE,.65),color)
  U.icon(icon,entry.icon,UDim2.fromOffset(4,4),UDim2.fromOffset(34,34),color)
  local copyWidth=width-(narrow and 76 or 228)
  label(U,card,UDim2.fromOffset(62,6),UDim2.fromOffset(copyWidth,28),entry.title..'  '..c.level..'×',18,true)
  label(U,card,UDim2.fromOffset(62,34),UDim2.fromOffset(copyWidth,43),V.effect(c),15,false)
  label(U,card,UDim2.fromOffset(narrow and 12 or 62,narrow and 77 or 76),
   UDim2.fromOffset(narrow and width-28 or copyWidth,20),nextEffect(row),14,false)
  local cost=row.next and ('Add stack · '..row.cost..' Quartz') or 'Maxed'
  local b=action(U,card,UDim2.fromOffset(narrow and 12 or width-154,narrow and 101 or 30),UDim2.fromOffset(narrow and width-28 or 140,36),
   cost,function() options.onBuy(c,c.level) end,options.canBuy and not pending and row.next~=nil and balance>=row.cost)
  b.Name='AddStack_'..entry.id
  y+=h+9
 end
end
function V.renderStars(U,parent,options)
 local p,width=options.profile,options.width
 local balance=p.run.stars or 0
 tab(U,parent,width,'Back to Quartz upgrades',options.onBack)
 label(U,parent,UDim2.fromOffset(4,49),UDim2.fromOffset(width-8,44),'Choose a pack upgrade to earn Stars. Buy travel and automation perks here for this run.',15,false)
 local y=102
 for _,entry in ipairs(Workshop.STAR_CATALOG) do
  local level=Workshop.starLevel(p,entry.id)
  local price=Workshop.starPrice(entry,level)
  local card=rounded(U,parent,UDim2.fromOffset(3,y),UDim2.fromOffset(width-6,102),Color3.fromRGB(255,250,226),Color3.fromRGB(218,186,99))
  label(U,card,UDim2.fromOffset(12,7),UDim2.fromOffset(width-26,24),entry.title,19,true)
  local detail=entry.description
  if p.fieldCrewPreview and entry.id=='vacuum' then detail='Increases the test vacuum’s reach.' end
  if p.fieldCrewPreview and entry.id=='cultivator' then detail='The test planter replants more often.' end
  label(U,card,UDim2.fromOffset(12,33),UDim2.fromOffset(width-26,21),detail,15,false)
  label(U,card,UDim2.fromOffset(12,57),UDim2.fromOffset(width-146,36),level..' / '..entry.max..' owned',14,true)
  action(U,card,UDim2.fromOffset(width-124,57),UDim2.fromOffset(104,36),level>=entry.max and 'MAX' or price..' Stars',
   function() options.onBuy(entry.id,level) end,options.canBuy and level<entry.max and balance>=price,Color3.fromRGB(255,218,102))
  y+=111
 end
end
return V
