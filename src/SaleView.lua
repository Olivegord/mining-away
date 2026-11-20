-- A manual sale lines the actual rocks up on the counter, prices each stack in
-- turn with its modifiers, then breaks them into one large running total.
local Ledger=require('./SaleLedger')
local Sale={};Sale.__index=Sale;Sale.Ledger=Ledger
local CASH=Color3.fromRGB(160,244,182)
local PAPER=Color3.fromRGB(251,248,234)
local BONUS=Color3.fromRGB(255,206,84)
local INK=Color3.fromRGB(14,20,16)
local SHOWN=5
local LAND,STAGGER=.34,.07
local FIRST,STEP,BONUS_DELAY=.55,.38,.16
local SHATTER_GAP,HOLD,FADE=.5,1.8,.4
local REDUCED_END=2.4

local function label(parent,contents,size,color,font)
 local text=Instance.new('TextLabel')
 text.BackgroundTransparency=1;text.Text=contents;text.TextScaled=true;text.RichText=true
 text.TextColor3=color;text.Font=font or Enum.Font.GothamBold;text.TextWrapped=true
 text.TextStrokeColor3=INK;text.TextStrokeTransparency=.3
 text.Parent=parent
 local limits=Instance.new('UITextSizeConstraint');limits.MinTextSize=10;limits.MaxTextSize=size;limits.Parent=text
 return text
end
local function hex(color)
 return string.format('#%02X%02X%02X',math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5))
end
local function pulse(age,duration)
 if age<0 or age>duration then return 0 end
 return math.sin(age/duration*math.pi)*(1-age/duration)
end
local function ease(t) t=math.clamp(t,0,1);return 1-(1-t)^3 end
local function settle(t)
 t=math.clamp(t,0,1)
 local c=1.6;return 1+(c+1)*(t-1)^3+c*(t-1)^2
end

-- Payout modifiers on this stack, in the order the server applies them.
local function chips(item)
 local styles={}
 for _,style in ipairs(RockModifierView.STYLES) do styles[style.name]=style.color end
 local list={}
 for _,mod in ipairs(Workshop.PAYOUT_MODS) do
  if bit32.btest(item.bonusMask,mod.bit) then
   local text=mod.cash and string.format('%s +%d%%',mod.name,math.floor(mod.cash*100+.5))
    or string.format('%s +%d%% dust',mod.name,math.floor(mod.dust*100+.5))
   list[#list+1]={text=text,color=styles[mod.name] or BONUS}
  end
 end
 return list
end

function Sale.new(refs)
 return setmetatable({refs=refs,seen={},order={}},Sale)
end

function Sale:receiveProfile(profile)
 if self.runId~=profile.run.id then self:clear();self.runId=profile.run.id end
 for _,receipt in ipairs(profile.recentSales or {}) do self:receive(receipt) end
end

function Sale:makeOre(item)
 local net=game:GetService('ReplicatedStorage'):FindFirstChild('MiningAway')
 local source=net and net:FindFirstChild(item.stone and 'CargoStone' or 'CargoCrystal')
 local cuts=net and net:FindFirstChild('CargoStoneCuts')
 if item.stone and item.cut and cuts then source=cuts:FindFirstChild(item.cut) or source end
 local folder=self.refs.world:FindFirstChild('Resources')
 if not source and folder then for _,p in ipairs(folder:GetChildren()) do if p:IsA('BasePart') then source=p;break end end end
 if not source then
  for _,p in ipairs(self.refs.world:GetDescendants()) do
   if p:IsA('BasePart') and p:GetAttribute('ResourceId') then source=p;break end
  end
 end
 local proxy=source and source:Clone() or Instance.new('Part')
 for _,child in ipairs(proxy:GetChildren()) do child:Destroy() end
 for key in pairs(proxy:GetAttributes()) do proxy:SetAttribute(key,nil) end
 proxy:SetAttribute('Mineral',item.material or item.key);proxy:SetAttribute('StoneCargo',item.stone)
 proxy:SetAttribute('RockModifiers',item.mask or 0)
 local palette=net and net:FindFirstChild('CargoFieldColors')
 local fieldTint=palette and item.material and palette:GetAttribute(item.material) or Color3.fromRGB(table.unpack(item.color))
 proxy.Size=Vector3.new(table.unpack(item.pressed and Workshop.BLOCK_SIZE or Workshop.ROCK_SIZE))*Mining.ORE_SIZE_SCALE[Mining.sizeTier(item.mask)]
 proxy.Color=item.stone and Color3.fromRGB(88,84,81):Lerp(fieldTint,.32) or fieldTint
 proxy.Material=item.stone and Enum.Material.Slate or item.pressed and Enum.Material.Metal or Enum.Material.SmoothPlastic
 proxy.MaterialVariant='';proxy.Reflectance=(item.stone or item.pressed) and 0 or Workshop.RAW_CRYSTAL_REFLECTANCE
 if item.pressed then proxy.Name='PressedCargo' end
 if proxy:IsA('PartOperation') then proxy.UsePartColor=true end
 local ore,gem=RockFinish.Gems.clone(proxy);proxy:Destroy()
 ore.Name='Selling_'..item.name;ore.Anchored=true;ore.CanCollide=false;ore.CanTouch=false;ore.CanQuery=false;ore.CastShadow=false
 ore.LocalTransparencyModifier=0;ore.Transparency=gem and 1-(ore:GetAttribute('GemOpacity') or .8) or 0

 return ore,gem
end

-- Large running total near the top of the screen.
function Sale:show(batch)
 local card=Instance.new('Frame');card.Name='OreSaleTotal'
 card.AnchorPoint=Vector2.new(.5,0);card.Position=UDim2.new(.5,0,.12,0)
 card.Size=UDim2.new(1,-32,0,150);card.BackgroundTransparency=1;card.Parent=self.refs.gui
 local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(620,150);limit.Parent=card
 local totalBox=Instance.new('Frame');totalBox.BackgroundTransparency=1;totalBox.Size=UDim2.new(1,0,0,78);totalBox.Parent=card
 local scale=Instance.new('UIScale');scale.Parent=totalBox
 local total=label(totalBox,'+$0',78,CASH,Enum.Font.GothamBlack);total.Size=UDim2.fromScale(1,1)
 total.TextStrokeTransparency=.12
 local summary=label(card,'',24,PAPER);summary.Position=UDim2.fromOffset(0,80);summary.Size=UDim2.new(1,0,0,28)
 local materials=label(card,'',18,PAPER);materials.Position=UDim2.fromOffset(0,110);materials.Size=UDim2.new(1,0,0,22)
 materials.TextTransparency=1;materials.TextStrokeTransparency=1
 local milestone=label(card,batch.receipt.milestone or '',16,BONUS);milestone.Position=UDim2.fromOffset(0,132);milestone.Size=UDim2.new(1,0,0,18)
 milestone.TextTransparency=1;milestone.TextStrokeTransparency=1
 batch.gui=card;batch.total=total;batch.totalScale=scale;batch.summary=summary
 batch.materials=materials;batch.milestone=milestone
 batch.labels={total,summary}
end

function Sale:summary(batch)
 local units=batch.read.units
 local text=string.format('<b>%d</b> %s sold',units,units==1 and 'rock' or 'rocks')
 if batch.bonusShown>0 then
  text..=string.format('  ·  <font color="%s">modifiers +%s</font>',hex(BONUS),Ledger.money(batch.bonusShown))
 end
 batch.summary.Text=text
end

local function rockLabel(ore,group,width)
 local gui=Instance.new('BillboardGui');gui.Name='SaleValue'
 gui.Size=UDim2.new(width,0,1.7,0);gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.MaxDistance=140
 gui.StudsOffsetWorldSpace=Vector3.yAxis*(ore.Size.Y*.5+1.15);gui.Adornee=ore;gui.Enabled=false
 local root=Instance.new('Frame');root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Parent=gui
 local scale=Instance.new('UIScale');scale.Parent=root
 local value=Instance.new('TextLabel');value.Name='Value';value.BackgroundTransparency=1
 value.Size=UDim2.fromScale(1,.58);value.TextScaled=true;value.RichText=true;value.Font=Enum.Font.GothamBlack
 value.TextColor3=CASH;value.TextStrokeColor3=INK;value.TextStrokeTransparency=.15;value.Text='';value.Parent=root
 local row=Instance.new('Frame');row.Name='Modifiers';row.BackgroundTransparency=1
 row.Position=UDim2.fromScale(0,.63);row.Size=UDim2.fromScale(1,.33);row.Visible=false;row.Parent=root
 local layout=Instance.new('UIListLayout');layout.FillDirection=Enum.FillDirection.Horizontal
 layout.HorizontalAlignment=Enum.HorizontalAlignment.Center;layout.Padding=UDim.new(.03,0);layout.Parent=row
 local list=chips(group.item)
 for i,chip in ipairs(list) do
  local text=Instance.new('TextLabel');text.LayoutOrder=i;text.Text=chip.text
  text.Size=UDim2.fromScale(math.min(.62,.96/#list-.03),1);text.TextScaled=true;text.Font=Enum.Font.GothamBold
  text.TextColor3=chip.color;text.BackgroundColor3=chip.color:Lerp(INK,.82);text.BackgroundTransparency=.08
  text.BorderSizePixel=0;text.Parent=row
  local pad=Instance.new('UIPadding');pad.PaddingLeft=UDim.new(.06,0);pad.PaddingRight=UDim.new(.06,0)
  pad.PaddingTop=UDim.new(.12,0);pad.PaddingBottom=UDim.new(.12,0);pad.Parent=text
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.3,0);corner.Parent=text
 end
 gui.Parent=ore
 return gui,value,row,scale,#list>0 and list[1].color or BONUS
end

function Sale:stage(batch,root)
 local target=Vector3.new(table.unpack(batch.receipt.counter))
 local camera=workspace.CurrentCamera
 local toward=root.Position-target;toward=Vector3.new(toward.X,0,toward.Z)
 local forward=toward.Magnitude>.001 and toward.Unit or Vector3.zAxis
 local right=camera and camera.CFrame.RightVector or forward:Cross(Vector3.yAxis)
 right=Vector3.new(right.X,0,right.Z)
 right=right.Magnitude>.001 and right.Unit or forward:Cross(Vector3.yAxis)
 batch.target=target;batch.rocks={}
 local slots,width={},0
 for i,group in ipairs(batch.groups) do
  local ore,gem=self:makeOre(group.item)
  local extent=math.max(ore.Size.X,ore.Size.Y,ore.Size.Z)
  -- Keep every rock legible while Big, Massive and Titan still read larger.
  local tier=Mining.sizeTier(group.item.mask)
  ore.Size*=(1.75*(1+(tier-1)*.22))/extent
  local slot=math.max(3.1,math.max(ore.Size.X,ore.Size.Z)+.9)
  slots[i]={ore=ore,gem=gem,slot=slot};width+=slot
 end
 local cursor=-width*.5
 for i,entry in ipairs(slots) do
  local group,ore=batch.groups[i],entry.ore
  local lane=cursor+entry.slot*.5;cursor+=entry.slot
  local position=target+right*lane+forward*1.2+Vector3.yAxis*(ore.Size.Y*.5+.35)
  local pose=CFrame.lookAt(Vector3.zero,-forward)*CFrame.Angles(.12,(i*1.37)%(2*math.pi),.08)
  ore.CFrame=CFrame.new(position+Vector3.yAxis*4)*pose;ore.Parent=self.refs.parent
  if entry.gem then RockFinish.Gems.update(ore,1) end
  local gui,value,row,scale,chipColor=rockLabel(ore,group,entry.slot-.25)
  local beat=FIRST+(i-1)*STEP
  batch.rocks[i]={ore=ore,gem=entry.gem,size=ore.Size,position=position,pose=pose,group=group,
   gui=gui,value=value,row=row,scale=scale,chipColor=chipColor,land=(i-1)*STAGGER,beat=beat,
   record={view=ore,modifiers=group.item.mask,seed=i}}
 end
end

function Sale:credit(batch)
 if batch.credited then return end
 batch.credited=true
 for key,amount in pairs(batch.amounts) do
  if amount>0 then self.refs.hud:currencyHit(batch.receipt.id,key,amount,batch.reduced,true) end
 end
end

function Sale:clear()
 local batch=self.batch
 if not batch then return end
 self:credit(batch)
 if batch.gui then batch.gui:Destroy() end
 for _,rock in ipairs(batch.rocks or {}) do rock.ore:Destroy() end
 self.batch=nil
end

function Sale:receive(receipt)
 if self.seen[receipt.id] or (self.runId and receipt.runId~=self.runId) then return end
 self.seen[receipt.id]=true;table.insert(self.order,receipt.id)
 if #self.order>128 then self.seen[table.remove(self.order,1)]=nil end
 self.refs.onCommitted(receipt)
 if not receipt.full then
  -- A full bag cashed out on the field: coins burst from the player.
  -- Replayed old receipts (rejoin) credit quietly.
  local fresh=type(receipt.at)=='number' and workspace:GetServerTimeNow()-receipt.at<6
  if receipt.auto and fresh then self:cashOut(receipt) end
  return
 end
 self:clear()
 local amounts=table.clone(receipt.resources or {});amounts.Money=receipt.cash or 0
 local read=Ledger.read(receipt)
 local groups,rest=Ledger.groups(read,SHOWN)
 local batch={receipt=receipt,read=read,groups=groups,rest=rest,amounts=amounts,start=os.clock(),
  reduced=self.refs.reducedMotion(),cashTarget=0,cashShown=0,bonusShown=0,bumpAt=-1,steps={}}
 self.batch=batch
 self.refs.hud:beginSale(receipt,amounts)
 local root=self.refs.player.Character and self.refs.player.Character:FindFirstChild('HumanoidRootPart')
 if root and receipt.counter and not batch.reduced and not self.refs.hidden() and #groups>0 then self:stage(batch,root) end
 if not batch.rocks or #batch.rocks==0 then batch.reduced=true end
 if batch.reduced then
  batch.shatterAt=0;batch.endAt=REDUCED_END
 else
  local last=FIRST+(#groups-1)*STEP
  if rest.count>0 then last+=STEP end
  batch.restAt=rest.count>0 and last or nil
  batch.shatterAt=last+SHATTER_GAP;batch.endAt=batch.shatterAt+HOLD+FADE
 end
end

function Sale:shatter(batch)
 batch.shattered=true
 batch.cashTarget=batch.receipt.cash or 0;batch.cashShown=batch.cashTarget
 batch.bonusShown=math.max(batch.bonusShown,batch.read.cashBonus or 0)
 batch.bumpAt=os.clock();batch.bumpSize=.24
 self:credit(batch)
 local point=batch.target or (batch.receipt.counter and Vector3.new(table.unpack(batch.receipt.counter)))
 if point and not batch.reduced then
  self.refs.audio:play('sale_finish',point,{level=1})
  local best=batch.groups[#batch.groups]
  if best then self.refs.audio:play(best.item.stone and 'sale_stone' or 'sale_gem',point,{level=.6}) end
  if self.refs.presentation then self.refs.presentation:cameraBeat('Sale',point,os.clock(),1.3) end
 end
 for _,rock in ipairs(batch.rocks or {}) do
  local tint=Color3.fromRGB(table.unpack(rock.group.item.color))
  RoleVisuals.ImpactParticles(rock.ore.Position,tint,.75+rock.size.Magnitude*.12,'CrystalBreak',nil,
   rock.group.item.stone and rock.ore.Color or nil)
  if rock.group.item.mask~=0 then RockModifierView.saleBurst(rock.record,'break') end
  rock.ore:Destroy()
 end
 batch.rocks=nil
end

function Sale:update(now)
 now=now or os.clock()
 if self.cash and #self.cash>0 then self:stepCash(now) end
 local batch=self.batch
 if not batch then return end
 local age=now-batch.start
 local dt=math.clamp(now-(batch.frame or now),0,.1);batch.frame=now
 if age>=batch.endAt then self:clear();return end
 local hidden=self.refs.hidden()
 if not batch.gui then self:show(batch) end
 -- Walking away settles the sale at once instead of leaving it behind.
 if not batch.shattered and batch.target then
  local character=self.refs.player.Character
  local root=character and character:FindFirstChild('HumanoidRootPart')
  if not root or (root.Position-batch.target).Magnitude>60 then
   batch.start=now-batch.shatterAt;age=batch.shatterAt
   batch.endAt=batch.shatterAt+HOLD+FADE
  end
 end
 local lowFlash=BeamVFX and BeamVFX.reduced and BeamVFX.reduced()
 for i,rock in ipairs(batch.rocks or {}) do
  local group=rock.group
  local fall=(age-rock.land)/LAND
  if fall>=1 and not rock.landed then
   rock.landed=true
   self.refs.audio:play('sale_stone',rock.position,{level=.28,pitch=.9+i*.04})
  end
  local drop=(1-settle(fall))*4
  local spin=math.max(0,age-rock.land)*.55
  local priced=age-rock.beat
  local bonusAge=priced-BONUS_DELAY
  local pop=1+.16*pulse(priced,.24)+(group.bonus>0 and .1*pulse(bonusAge,.24) or 0)
  rock.ore.Size=rock.size*pop
  rock.ore.CFrame=CFrame.new(rock.position+Vector3.yAxis*(drop+math.sin(age*2.1+i)*.06))*CFrame.Angles(0,spin,0)*rock.pose
  if rock.gem then RockFinish.Gems.update(rock.ore,1) end
  if rock.landed and group.item.mask~=0 then RockModifierView.drop(rock.record,now,fall*LAND-LAND,lowFlash,1.3) end
  -- Base price first, then the modifier lifts it to the paid amount.
  if priced>=0 and not rock.priced then
   rock.priced=true;rock.gui.Enabled=not hidden
   batch.cashTarget+=group.cash-group.bonus;batch.bumpAt=now;batch.bumpSize=.1
   self.refs.audio:play('sale_credit',rock.position,{level=.9,pitch=1+(i-1)*.07})
  end
  if group.bonus+group.dustBonus>0 and bonusAge>=0 and not rock.boosted then
   rock.boosted=true;rock.row.Visible=true
   batch.cashTarget+=group.bonus;batch.bonusShown+=group.bonus;batch.bumpAt=now;batch.bumpSize=.14
   self.refs.audio:play('sale_gem',rock.position,{level=.45,pitch=1.1+(i-1)*.05})
   RockModifierView.saleBurst(rock.record,'land')
  end
  if rock.priced then
   local lift=group.bonus>0 and ease(bonusAge/.22) or 0
   local cash=group.cash-group.bonus+group.bonus*lift
   local count=group.count>1 and string.format('<font color="%s">%d×</font> ',hex(PAPER),group.count) or ''
   rock.value.Text=count..Ledger.money(math.floor(cash+.5))
   rock.value.TextColor3=CASH:Lerp(rock.chipColor,group.bonus>0 and pulse(bonusAge,.5)*1.6 or 0)
   rock.scale.Scale=1+.22*pulse(priced,.22)+.12*pulse(bonusAge,.22)
   rock.gui.Enabled=not hidden
  end
 end
 if batch.restAt and age>=batch.restAt and not batch.restCounted then
  batch.restCounted=true
  batch.cashTarget+=batch.rest.cash;batch.bonusShown+=batch.rest.bonus;batch.bumpAt=now;batch.bumpSize=.1
  if batch.target then self.refs.audio:play('sale_credit',batch.target,{level=.9,pitch=1.4}) end
 end
 if age>=batch.shatterAt and not batch.shattered then self:shatter(batch) end
 -- The big total chases the priced amount so each beat visibly adds up.
 batch.cashShown+=(batch.cashTarget-batch.cashShown)*(1-math.exp(-dt*13))
 if math.abs(batch.cashTarget-batch.cashShown)<.5 then batch.cashShown=batch.cashTarget end
 local gui=batch.gui
 gui.Visible=not hidden
 batch.total.Text='+'..Ledger.money(math.floor(batch.cashShown+.5))
 if (batch.receipt.cash or 0)<=0 and batch.shattered then batch.total.Text='Sold' end
 batch.totalScale.Scale=1+(batch.bumpSize or 0)*pulse(now-batch.bumpAt,.26)
 self:summary(batch)
 local fade=math.clamp((age-(batch.endAt-FADE))/FADE,0,1)
 local after=batch.shattered and math.clamp((age-batch.shatterAt)/.25,0,1) or 0
 batch.total.TextColor3=CASH:Lerp(Color3.new(1,1,1),batch.shattered and pulse(age-batch.shatterAt,.4) or 0)
 for _,text in ipairs(batch.labels) do
  text.TextTransparency=fade;text.TextStrokeTransparency=.15+.85*fade
 end
 batch.materials.Text=batch.read.materials
 batch.materials.TextTransparency=1-after*(1-fade)*.85;batch.materials.TextStrokeTransparency=1-after*(1-fade)*.6
 if batch.receipt.milestone then
  batch.milestone.TextTransparency=1-after*(1-fade);batch.milestone.TextStrokeTransparency=1-after*(1-fade)*.6
 end
end

-- Cash-out: "+$X" pops over the player's head and drifts up while a fountain
-- of coins flies from the player into the money counter. Each coin that
-- lands releases its share of the balance. The number sits by the player,
-- not across the middle of the screen, so it never covers the digging.
local COIN=Color3.fromRGB(255,214,74)
local COINS=14
function Sale:cashOut(receipt)
 local hud=self.refs.hud
 local amounts=table.clone(receipt.resources or {});amounts.Money=receipt.cash or 0
 hud:beginSale(receipt,amounts)
 local reduced=self.refs.reducedMotion()
 local character=self.refs.player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local camera=workspace.CurrentCamera
 local gui=self.refs.gui
 local origin=gui.AbsolutePosition+gui.AbsoluteSize*Vector2.new(.5,.6)
 if root and camera then
  local v,onScreen=camera:WorldToViewportPoint(root.Position+Vector3.yAxis*2.5)
  local screen=gui:FindFirstAncestorWhichIsA('ScreenGui')
  local inset=(screen and screen.IgnoreGuiInset) and Vector2.zero or game:GetService('GuiService'):GetGuiInset()
  if onScreen then origin=Vector2.new(v.X,v.Y)-inset end
 end
 local cash={receipt=receipt,amounts=amounts,start=os.clock(),coins={},reduced=reduced,landed=0,paid=0}
 if root then
  RoleVisuals.ImpactParticles(root.Position+Vector3.yAxis*1.5,COIN,1,'CrystalBreak',nil,nil,nil,.6)
  self.refs.audio:play('sale_finish',root.Position,{level=.9})
  if self.refs.presentation and not reduced then self.refs.presentation:cameraBeat('Sale',root.Position,os.clock(),.8) end
 end
 local card=label(gui,'+'..Ledger.money(amounts.Money),54,CASH,Enum.Font.GothamBlack)
 local size=gui.AbsoluteSize
 local at=origin-gui.AbsolutePosition-Vector2.new(0,64)
 at=Vector2.new(math.clamp(at.X,130,math.max(130,size.X-130)),math.clamp(at.Y,90,math.max(90,size.Y-60)))
 card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromOffset(at.X,at.Y);card.Size=UDim2.fromOffset(260,60)
 card.TextStrokeTransparency=.05
 local scale=Instance.new('UIScale');scale.Parent=card
 cash.card=card;cash.scale=scale;cash.at=at
 if reduced then
  for key,amount in pairs(amounts) do if amount>0 then hud:currencyHit(receipt.id,key,amount,true,true) end end
  cash.paid=COINS
 else
  local count=amounts.Money>0 and COINS or 0
  for i=1,count do
   local coin=Instance.new('Frame');coin.Name='Coin';coin.AnchorPoint=Vector2.new(.5,.5);coin.Size=UDim2.fromOffset(22,22)
   coin.BackgroundColor3=COIN;coin.BorderSizePixel=0;coin.Parent=gui
   local round=Instance.new('UICorner');round.CornerRadius=UDim.new(1,0);round.Parent=coin
   local edge=Instance.new('UIStroke');edge.Color=Color3.fromRGB(176,118,22);edge.Thickness=2;edge.Parent=coin
   local mark=label(coin,'$',18,Color3.fromRGB(122,78,10));mark.Size=UDim2.fromScale(1,1);mark.TextStrokeTransparency=1
   local angle=(i/count)*math.pi*2+math.random()*.6
   local speed=170+math.random()*150
   table.insert(cash.coins,{gui=coin,from=origin-gui.AbsolutePosition,velocity=Vector2.new(math.cos(angle),math.sin(angle)-.6)*speed,
    delay=(i-1)*.035,flyAt=.42+(i-1)*.035,share=(i==count) and nil or math.floor(amounts.Money/count)})
  end
 end
 self.cash=self.cash or {}
 table.insert(self.cash,cash)
end
function Sale:stepCash(now)
 for index=#(self.cash or {}),1,-1 do
  local cash=self.cash[index]
  local age=now-cash.start
  local hud=self.refs.hud
  local target=hud:currencyTarget('Money')
  local gui=self.refs.gui
  for i,coin in ipairs(cash.coins) do
   if coin.done then continue end
   local t=age-coin.delay
   if t<0 then coin.gui.Visible=false;continue end
   coin.gui.Visible=not self.refs.hidden()
   local burst=math.min(t,coin.flyAt-coin.delay)
   -- Coins burst out, slow down, then home in on the counter.
   local spread=coin.from+coin.velocity*(1-math.exp(-burst*5))/5+Vector2.new(0,1)*120*burst*burst
   if t<coin.flyAt-coin.delay then
    coin.gui.Position=UDim2.fromOffset(spread.X,spread.Y);coin.spread=spread
   else
    local goal=target and (target-gui.AbsolutePosition) or Vector2.new(60,40)
    local k=math.clamp((t-(coin.flyAt-coin.delay))/.38,0,1)
    local eased=k*k*(3-2*k)
    local pos=(coin.spread or spread):Lerp(goal,eased)
    coin.gui.Position=UDim2.fromOffset(pos.X,pos.Y);coin.gui.Size=UDim2.fromOffset(22-8*eased,22-8*eased)
    if k>=1 then
     coin.done=true;coin.gui:Destroy();cash.landed+=1
     local last=cash.landed>=#cash.coins
     local share=last and math.max(0,cash.amounts.Money-cash.paid) or coin.share
     cash.paid+=share
     hud:currencyHit(cash.receipt.id,'Money',share,false,last)
     self.refs.audio:play('sale_credit',nil,{level=.5,pitch=.95+cash.landed*.045})
     if last then
      for key,amount in pairs(cash.amounts) do if key~='Money' and amount>0 then hud:currencyHit(cash.receipt.id,key,amount,false,true) end end
     end
    end
   end
  end
  if #cash.coins==0 and not cash.creditedRest then
   cash.creditedRest=true
   for key,amount in pairs(cash.amounts) do if amount>0 then hud:currencyHit(cash.receipt.id,key,amount,cash.reduced,true) end end
  end
  local pop=.5+.7*ease(age/.14)-.2*ease((age-.14)/.22)
  cash.scale.Scale=pop
  local fade=math.clamp((age-1.05)/.35,0,1)
  cash.card.TextTransparency=fade;cash.card.TextStrokeTransparency=.05+.95*fade
  if not cash.reduced then cash.card.Position=UDim2.fromOffset(cash.at.X,cash.at.Y-34*ease(age/1.4)) end
  cash.card.Visible=not self.refs.hidden()
  if age>2.4 then
   for _,coin in ipairs(cash.coins) do if not coin.done then coin.gui:Destroy() end end
   if cash.landed<#cash.coins then
    local rest=math.max(0,cash.amounts.Money-cash.paid)
    if rest>0 then hud:currencyHit(cash.receipt.id,'Money',rest,false,true) end
    for key,amount in pairs(cash.amounts) do if key~='Money' and amount>0 then hud:currencyHit(cash.receipt.id,key,amount,false,true) end end
   end
   cash.card:Destroy();table.remove(self.cash,index)
  end
 end
end

function Sale:destroy() self:clear() end
return Sale
