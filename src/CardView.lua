-- Presentation only: offers, targets and resolved previews remain server-owned.
local CardView={HEIGHT=520,MIN_HEIGHT=430}

local categoryLooks={
 MINING={icon='mining',color=Color3.fromRGB(167,222,191)},
 COMBAT={icon='combat',color=Color3.fromRGB(249,186,158)},
 SURVIVAL={icon='survival',color=Color3.fromRGB(171,207,229)},
 CARGO={icon='cargo',color=Color3.fromRGB(246,217,137)},
 LASER={icon='startup',color=Color3.fromRGB(221,199,236)},
 STARTUP={icon='startup',color=Color3.fromRGB(221,199,236)},
 FLIGHT={icon='flight',color=Color3.fromRGB(185,222,235)},
}

local function topText(U,parent,position,size,value,textSize,color,bold)
 local label=U.text(parent,position,size,value,textSize,color,bold)
 label.TextWrapped=true
 label.TextXAlignment=Enum.TextXAlignment.Left
 label.TextYAlignment=Enum.TextYAlignment.Top
 return label
end

function CardView.create(U,parent,choice,index,width,height,options)
 options=options or {}
 -- Short desktop screens show all three actions without a vertical scroll.
 -- Phone lists retain the roomier card and its descriptive headline.
 height=math.max(height or CardView.HEIGHT,CardView.MIN_HEIGHT)
 local compact=height<CardView.HEIGHT
 local p=U.palette
 local category=string.upper(options.category or choice.category or 'MINING')
 local look=categoryLooks[category] or categoryLooks.MINING
 local card=U.panel(parent,UDim2.fromOffset(0,0),UDim2.fromOffset(width,height),p.paper,18)
 card.Name='CardChoice'..tostring(index)
 card.LayoutOrder=index
 local header=U.frame(card,UDim2.fromOffset(3,3),UDim2.new(1,-6,0,compact and 50 or 70),look.color)
 header.Name='CategoryHeader'
 U.corner(header,14)
 U.icon(card,look.icon,UDim2.fromOffset(16,compact and 8 or 13),UDim2.fromOffset(compact and 38 or 45,compact and 38 or 45),p.ink)
 U.badge(card,UDim2.fromOffset(compact and 65 or 73,compact and 15 or 20),UDim2.new(1,compact and -111 or -119,0,compact and 25 or 29),category,p.paper)
 local number=U.text(card,UDim2.new(1,-37,0,compact and 17 or 24),UDim2.fromOffset(22,21),tostring(index),15,p.ink,true)
 number.TextXAlignment=Enum.TextXAlignment.Center

 local title=topText(U,card,UDim2.fromOffset(16,compact and 63 or 83),UDim2.new(1,-32,0,compact and 45 or 49),choice.title or 'Run card',compact and 21 or 23,p.ink,true)
 title.Name='CardTitle'
 local target=U.badge(card,UDim2.fromOffset(16,compact and 114 or 138),UDim2.new(1,-32,0,compact and 28 or 33),options.target or 'ENTIRE FLEET',look.color)
 target.Name='CardTarget'

 if not compact then
  topText(U,card,UDim2.fromOffset(16,181),UDim2.new(1,-32,0,31),choice.headline or category..' UPGRADE',13,p.ink,true)
 end
 topText(U,card,UDim2.fromOffset(16,compact and 151 or 217),UDim2.new(1,-32,0,compact and 48 or 47),choice.description or choice.purpose or 'Applies to the target shown above.',compact and 11.5 or 12,p.text,false)

 local tradeoff=choice.tradeoff or 'No stat penalty'
 local hasPenalty=not string.find(string.lower(tradeoff),'no stat penalty',1,true)
 local tradeoffText=hasPenalty and ('TRADEOFF: '..tradeoff) or tradeoff
 local downside=topText(U,card,UDim2.fromOffset(16,compact and 204 or 269),UDim2.new(1,-32,0,compact and 28 or 31),tradeoffText,11.5,hasPenalty and p.danger:Lerp(p.ink,.4) or p.muted,false)
 downside.Name='CardTradeoff'

 local previewName=choice.previewTargetName or choice.targetName
 local previewTitle=previewName and ('STATS / '..previewName) or 'YOUR CURRENT STATS'
 topText(U,card,UDim2.fromOffset(16,compact and 238 or 305),UDim2.new(1,-32,0,14),previewTitle,10,p.muted,true)
 local rows=options.previewRows or {}
 for row=1,4 do
  local rowHeight=compact and 18 or 21
  local y=(compact and 256 or 323)+(row-1)*rowHeight
  if rows[row] then
   local line=U.frame(card,UDim2.fromOffset(16,y-1),UDim2.new(1,-32,0,rowHeight),row%2==1 and p.panel or p.paper)
   line.Name='StatRow'..tostring(row)
   topText(U,line,UDim2.fromOffset(6,compact and 2 or 3),UDim2.new(1,-12,1,compact and -2 or -3),rows[row],compact and 11 or 11.5,p.ink,false)
  end
 end
 if #rows==0 then
  topText(U,card,UDim2.fromOffset(22,compact and 259 or 326),UDim2.new(1,-44,0,compact and 64 or 68),'Special effect shown above. Applies to the target shown above.',11.5,p.muted,false)
 end
 local stacking=topText(U,card,UDim2.fromOffset(16,compact and 332 or 412),UDim2.new(1,-32,0,compact and 24 or 30),options.stackText or choice.stackText or 'Adds to your current run bonuses.',compact and 10 or 10.5,p.muted,false)
 stacking.Name='CardStacking'
 local expiry=U.text(card,UDim2.fromOffset(16,compact and 358 or 446),UDim2.new(1,-32,0,compact and 13 or 16),'THIS RUN · RESETS AT PRESTIGE',9.5,p.muted,true)
 expiry.TextXAlignment=Enum.TextXAlignment.Center
 local choose=U.button(card,UDim2.new(0,16,1,-56),UDim2.new(1,-32,0,44),'Choose card',options.onChoose,p.accent)
 choose.Name='ChooseCard'
 return {root=card,button=choose}
end

return CardView
