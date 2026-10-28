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

-- Original line-work illustrations, authored from Roblox Frames rather than
-- borrowed card artwork. The motif describes a real mechanic on the saved card.
local function illustration(U,card,choice,category,width,height)
 local ink=Color3.fromRGB(35,47,48)
 local paper=Color3.fromRGB(242,224,183)
 local copper=Color3.fromRGB(181,105,66)
 local teal=Color3.fromRGB(56,126,118)
 local light=Color3.fromRGB(238,207,120)
 local art=U.frame(card,UDim2.fromOffset(6,7),UDim2.fromOffset(width-12,height),Color3.fromRGB(226,207,168))
 art.Name='MechanicArtwork'
 local border=U.stroke(art,ink,1);border.Transparency=.2
 local function shape(x,y,w,h,color,rotation,radius)
  local f=U.frame(art,UDim2.fromScale(x,y),UDim2.fromScale(w,h),color)
  if rotation then f.Rotation=rotation end
  if radius then U.corner(f,radius) end
  return f
 end
 local function drone(x,y,scale)
  local body=shape(x,y,.27*scale,.17*scale,ink,nil,5)
  shape(x+.035*scale,y+.035*scale,.2*scale,.09*scale,teal,nil,4)
  shape(x+.115*scale,y+.13*scale,.045*scale,.07*scale,light,nil,3)
  return body
 end
 local effects=choice.effects or {}
 local isLens=type(effects.range)=='number' and effects.range>0
 local isPrism=type(effects.fork)=='number' and effects.fork>0
 local isCombat=(type(effects.combat)=='number' and effects.combat>0) or (type(effects.splash)=='number' and effects.splash>0) or category=='COMBAT'
 if isLens then
  -- Lens aperture, emitter and a measured distant target.
  drone(.12,.13,1.35)
  shape(.34,.36,.055,.36,copper,22)
  local lens=shape(.31,.42,.38,.34,ink,nil,40)
  local glass=U.frame(lens,UDim2.fromScale(.12,.12),UDim2.fromScale(.76,.76),paper);U.corner(glass,40)
  local ring=U.stroke(glass,teal,3);ring.Transparency=.05
  shape(.68,.62,.035,.20,copper,-48)
  shape(.68,.27,.19,.035,ink,0)
 elseif isPrism then
  -- A primary laser continues to its crystal and splits to ONE more.
  drone(.34,.08,1.15)
  shape(.48,.27,.035,.25,copper)
  shape(.37,.48,.26,.26,teal,45)
  shape(.25,.69,.27,.025,copper,-26)
  shape(.52,.69,.27,.025,copper,26)
  shape(.13,.78,.16,.11,ink,45).Name='ForkCrystalPrimary'
  shape(.71,.78,.16,.11,ink,45).Name='ForkCrystalSecondary'
 elseif isCombat then
  -- Fleet formation facing the original stepped pyramid silhouette.
  drone(.08,.12,.8);drone(.38,.05,.8);drone(.67,.12,.8)
  shape(.48,.29,.025,.18,copper)
  shape(.31,.73,.38,.12,ink)
  shape(.35,.62,.30,.12,ink)
  shape(.40,.51,.20,.12,ink)
  shape(.46,.43,.08,.09,light,nil,8)
 elseif category=='SURVIVAL' then
  -- Hull plating surrounds a single permanent drone.
  shape(.24,.12,.52,.67,ink,nil,20)
  shape(.30,.19,.40,.53,paper,nil,16)
  drone(.34,.36,1.2)
  shape(.46,.57,.08,.13,teal)
 elseif category=='FLIGHT' then
  -- Motion trails sit behind a level drone silhouette.
  shape(.12,.31,.32,.035,copper)
  shape(.05,.45,.30,.035,copper)
  shape(.13,.59,.25,.035,copper)
  drone(.40,.35,1.5)
 elseif category=='LASER' or category=='STARTUP' then
  -- Emitter readiness around the drone, without implying extra damage.
  drone(.31,.13,1.4)
  shape(.48,.37,.045,.20,copper)
  shape(.28,.58,.09,.09,light,nil,8)
  shape(.45,.62,.09,.09,light,nil,8)
  shape(.62,.58,.09,.09,light,nil,8)
 elseif category=='CARGO' then
  drone(.36,.10,1.05)
  shape(.17,.43,.66,.40,ink,nil,4)
  shape(.22,.48,.56,.30,paper,nil,3)
  shape(.25,.51,.50,.04,copper)
  shape(.25,.68,.50,.04,copper)
  shape(.46,.50,.06,.29,teal)
 else
  -- Overhead mining: the original level drone, beam and mineral silhouette.
  drone(.34,.09,1.2)
  shape(.48,.29,.035,.30,copper)
  shape(.31,.60,.34,.28,teal,45)
  shape(.40,.68,.13,.11,light,45)
 end
 return art
end

local function compactCard(U,parent,choice,index,width,height,options)
 local p=U.palette
 local category=string.upper(options.category or choice.category or 'MINING')
 local look=categoryLooks[category] or categoryLooks.MINING
 local card=U.panel(parent,UDim2.fromOffset(3,6),UDim2.fromOffset(width,height),Color3.fromRGB(244,229,195),4)
 card.Name='CardChoice'..tostring(index);card.LayoutOrder=index
 -- Illustration occupies the face; details remain in the focused panel.
 local artHeight=math.max(42,math.floor(height*.52))
 local titleY=artHeight+9
 local hasSummary=width>=120 and height>=170
 local titleHeight=hasSummary and math.max(20,height-titleY-43) or math.max(30,height-titleY-6)
 illustration(U,card,choice,category,width,artHeight)
 local title=U.text(card,UDim2.fromOffset(6,titleY),UDim2.fromOffset(width-12,titleHeight),choice.title or 'Run card',16,p.ink,true)
 title.Name='CardTitle';title.TextXAlignment=Enum.TextXAlignment.Center
 local rows=options.previewRows or {}
 local summary=U.text(card,UDim2.fromOffset(6,height-41),UDim2.fromOffset(width-12,35),rows[1] or '',16,p.ink,true)
 summary.Name='CardSummary';summary.TextXAlignment=Enum.TextXAlignment.Center;summary.Visible=hasSummary and rows[1]~=nil
 local rarity=(choice.rarity=='Common' or choice.rarity=='Uncommon' or choice.rarity=='Rare') and choice.rarity or nil
 if rarity and width>=120 then
  -- An understated edge mark signals rarity without displacing the art.
  local mark=U.frame(card,UDim2.new(1,-13,0,10),UDim2.fromOffset(5,5),rarity=='Rare' and Color3.fromRGB(181,105,66) or look.color)
  mark.Name='RarityMark';U.corner(mark,3)
 end
 local focus=Instance.new('TextButton');focus.Name='FocusCard';focus.BackgroundTransparency=1;focus.Text='';focus.AutoButtonColor=false
 focus.Size=UDim2.fromScale(1,1);focus.Position=UDim2.fromScale(0,0);focus.ZIndex=card.ZIndex+20;focus.Selectable=true;focus.Parent=card
 local outline=card:FindFirstChildOfClass('UIStroke')
 local function selectCard() if focus.Active and options.onFocus then options.onFocus(index) end end
 focus.Activated:Connect(selectCard)
 focus.MouseEnter:Connect(selectCard)
 focus.SelectionGained:Connect(selectCard)
 local function setFocus(on,reducedMotion)
  if outline then outline.Color=on and p.ink or p.line;outline.Thickness=on and 3 or 2 end
  local goal=UDim2.fromOffset(3,on and 0 or 6)
  if reducedMotion then card.Position=goal else card:TweenPosition(goal,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,.10,true) end
 end
 return {root=card,button=focus,setFocus=setFocus,select=selectCard}
end

function CardView.create(U,parent,choice,index,width,height,options)
 options=options or {}
 if options.offerCompact then return compactCard(U,parent,choice,index,width,height or 374,options) end
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
