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
 b.TextStrokeTransparency=1;b.Font=Enum.Font.FredokaOne;b.TextSize=15
 return b
end
local function percent(value) return string.format('%g%%',value*100) end
function V.effect(c)
 local e=c.effects;local parts={}
 if e.battery then table.insert(parts,'+'..e.battery..' battery') end
 if e.plotAuto then table.insert(parts,'Auto retarget') end
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
 if not r then return 'Fully stacked' end
 local unit=r.unit or '';if unit~='' and unit~='%' and unit~='×' then unit=' '..unit end
 return string.format('Next: %s %g → %g%s',r.label,r.before,r.after,unit)
end
function V.decorate(U,sheet,title,subtitle,close)
 U.unskin(sheet);sheet.BackgroundColor3=Color3.fromRGB(247,252,255);U.corner(sheet,20);U.stroke(sheet,INK,4)
 title.Font=Enum.Font.FredokaOne;title.Text='Upgrades!';title.TextSize=30
 title.TextColor3=BLUE;title.TextStrokeTransparency=1
 subtitle.TextColor3=INK;subtitle.Font=Enum.Font.SourceSansSemibold;subtitle.TextSize=16
 U.unskin(close);U.corner(close,10);U.stroke(close,Color3.fromRGB(116,34,58),3)
 close.BackgroundColor3=Color3.fromRGB(244,78,113);close.TextColor3=WHITE;close.Font=Enum.Font.FredokaOne;close.TextSize=25;close.TextStrokeTransparency=1
end
function V.render(U,parent,options)
 local p,width=options.profile,options.width;local narrow=width<500
 local rows={};for _,r in ipairs(p.workshop or {}) do rows[r.card.cardId]=r end
 local pending=p.run.pendingOffer;local price=Workshop.price(p);local balance=Shops.balance(p,'Quartz')
 local packHeight=narrow and 166 or 118
 local pack=rounded(U,parent,UDim2.fromOffset(2,2),UDim2.fromOffset(width-4,packHeight),Color3.fromRGB(225,245,255),BLUE);pack.Name='UpgradePack'
 U.icon(pack,'cards',UDim2.fromOffset(12,14),UDim2.fromOffset(narrow and 44 or 62,narrow and 44 or 62),Color3.fromRGB(63,171,243))
 local textX=narrow and 67 or 88
 label(U,pack,UDim2.fromOffset(textX,10),UDim2.fromOffset(width-textX-(narrow and 14 or 164),28),'UPGRADE PACK',narrow and 20 or 23,true)
 label(U,pack,UDim2.fromOffset(textX,40),UDim2.fromOffset(width-textX-(narrow and 14 or 164),38),'Choose 1 of 3 and earn 1–4 Stars.',15,false)
 local buyText=pending and (pending.opened==false and 'Open crate' or 'Choose upgrade') or ('Buy · '..price..' Quartz')
 local buy=action(U,pack,UDim2.fromOffset(narrow and 12 or width-164,narrow and 82 or 22),UDim2.fromOffset(narrow and width-28 or 148,44),buyText,options.onPack,options.canBuy and (pending~=nil or balance>=price))
 buy.Name='BuyWorkshopPack'
 label(U,pack,UDim2.fromOffset(12,narrow and 130 or 82),UDim2.fromOffset(width-28,28),'Rarity guarantees an upgrade of that tier. No extra charge.',narrow and 12 or 14,false)
 local y=packHeight+18
 if options.onStars then
  action(U,parent,UDim2.fromOffset(4,y),UDim2.fromOffset(width-8,42),'Star Shop  ·  '..(p.run.stars or 0)..' Stars',options.onStars,true,Color3.fromRGB(255,221,119))
  y+=53
 end
 label(U,parent,UDim2.fromOffset(4,y),UDim2.fromOffset(width-8,30),'YOUR UPGRADE POOL',18,true);y+=38
 local entries={}
 for _,entry in ipairs(Workshop.CATALOG) do if rows[entry.id] then table.insert(entries,entry) end end
 for _,entry in ipairs(Workshop.CATALOG) do if not rows[entry.id] then table.insert(entries,entry) end end
 for _,entry in ipairs(entries) do
  local row=rows[entry.id];local c=row and row.card;local color=Color3.fromRGB(unpack(entry.color))
  local h=narrow and (entry.tier>=3 and 154 or 134) or 88
  local card=rounded(U,parent,UDim2.fromOffset(2,y),UDim2.fromOffset(width-4,h),c and WHITE or Color3.fromRGB(238,245,250));card.Name='Upgrade_'..entry.id
  local icon=rounded(U,card,UDim2.fromOffset(10,14),UDim2.fromOffset(narrow and 46 or 54,narrow and 46 or 54),color:Lerp(WHITE,.65),color)
  U.icon(icon,entry.icon,UDim2.fromOffset(5,5),UDim2.fromOffset(narrow and 36 or 44,narrow and 36 or 44),color)
  local x=narrow and 67 or 78
  label(U,card,UDim2.fromOffset(x,9),UDim2.fromOffset(width-x-(narrow and 76 or 238),30),entry.title,narrow and 17 or 20,true)
  local count=rounded(U,card,UDim2.fromOffset(width-(narrow and 70 or 222),11),UDim2.fromOffset(54,29),c and color:Lerp(WHITE,.45) or WHITE,c and color or Color3.fromRGB(187,205,218))
  local number=label(U,count,UDim2.fromOffset(2,0),UDim2.new(1,-4,1,0),c and c.level..'×' or 'NEW',c and 20 or 13,true);number.TextXAlignment=Enum.TextXAlignment.Center
  local detail=c and V.effect(c) or V.effect(Workshop.card(entry,1))
  if not c then detail=Workshop.TIERS[entry.tier]..' · '..detail
  elseif entry.tier>=2 then detail=Workshop.TIERS[entry.tier]..' · '..detail end
  if c and not narrow and entry.tier<3 then detail..='\n'..nextEffect(row) end
  label(U,card,UDim2.fromOffset(x,39),UDim2.fromOffset(width-x-(narrow and 14 or 164),narrow and (entry.tier>=3 and 57 or 37) or 40),detail,14,false)
  local pos=UDim2.fromOffset(width-154,narrow and h-52 or 24)
  if c then
   local cost=row.next and ('+1 · '..row.cost..' Quartz') or 'MAX'
   local b=action(U,card,pos,UDim2.fromOffset(140,44),cost,function() options.onBuy(c,c.level) end,options.canBuy and not pending and row.next~=nil and balance>=row.cost)
   b.Name='AddStack_'..entry.id
   if narrow then label(U,card,UDim2.fromOffset(12,h-50),UDim2.fromOffset(width-176,40),row.next and 'Buy another stack' or 'Fully stacked',13,false) end
  else
   local t=label(U,card,pos,UDim2.fromOffset(140,44),'Find in packs',15,true);t.TextColor3=BLUE;t.TextXAlignment=Enum.TextXAlignment.Center
  end
  y+=h+9
 end
 local pre=p.prestigePreview or {};local earned=pre.earnings or 0;local needed=pre.saleRequired or Workshop.PRESTIGE_BASE
 local foot=rounded(U,parent,UDim2.fromOffset(2,y+5),UDim2.fromOffset(width-4,narrow and 128 or 83),Color3.fromRGB(242,233,255),Color3.fromRGB(166,124,213));foot.Name='PrestigeProgress'
 label(U,foot,UDim2.fromOffset(12,9),UDim2.fromOffset(width-(narrow and 28 or 172),25),'NEXT: +1 PERMANENT DRONE',narrow and 15 or 17,true)
 label(U,foot,UDim2.fromOffset(12,36),UDim2.fromOffset(width-(narrow and 28 or 172),25),earned..' / '..needed..' Quartz sold',15,false)
 local bar=rounded(U,foot,UDim2.fromOffset(12,65),UDim2.fromOffset(width-(narrow and 28 or 176),6),WHITE,WHITE)
 local fill=U.frame(bar,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(earned/math.max(1,needed),0,1),1),Color3.fromRGB(154,104,215));U.corner(fill,4)
 action(U,foot,UDim2.fromOffset(narrow and 12 or width-154,narrow and 78 or 20),UDim2.fromOffset(narrow and width-28 or 140,40),pre.eligible and 'Prestige ready!' or 'View reward',options.onPrestige,true,Color3.fromRGB(211,177,255))
end
function V.renderStars(U,parent,options)
 local p,width=options.profile,options.width
 local balance=p.run.stars or 0
 action(U,parent,UDim2.fromOffset(4,3),UDim2.fromOffset(width-8,42),'Back to Quartz Workshop',options.onBack,true,Color3.fromRGB(174,218,255))
 local y=56
 for _,entry in ipairs(Workshop.STAR_CATALOG) do
  local level=Workshop.starLevel(p,entry.id)
  local price=Workshop.starPrice(entry,level)
  local card=rounded(U,parent,UDim2.fromOffset(3,y),UDim2.fromOffset(width-6,102),Color3.fromRGB(255,250,226),Color3.fromRGB(218,186,99))
  label(U,card,UDim2.fromOffset(12,7),UDim2.fromOffset(width-26,24),entry.title,19,true)
  label(U,card,UDim2.fromOffset(12,33),UDim2.fromOffset(width-26,21),entry.description,15,false)
  label(U,card,UDim2.fromOffset(12,57),UDim2.fromOffset(width-146,36),level..' / '..entry.max..' owned',14,true)
  action(U,card,UDim2.fromOffset(width-124,57),UDim2.fromOffset(104,36),level>=entry.max and 'MAX' or price..' Stars',
   function() options.onBuy(entry.id,level) end,options.canBuy and level<entry.max and balance>=price,Color3.fromRGB(255,218,102))
  y+=111
 end
end
return V
