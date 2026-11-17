-- A committed sale is a cosmetic receipt. Animation never grants or spends money.
local SaleLedger=require('./SaleLedger')
local Sale={};Sale.__index=Sale
local Lighting=game:GetService('Lighting')
local GuiService=game:GetService('GuiService')
local Input=game:GetService('UserInputService')
local Actions=game:GetService('ContextActionService')
local TextService=game:GetService('TextService')
local CONFIRM_ACTION='MiningAwayConfirmSale'
local PAGE_SIZE=4
local FIRST_HIT=.30
local BREAK_TIME=.08
local FINISH_HOLD=.65
local READOUT_TIME=1.68
local DUST_WAVE_STEP=.23
local GEM_WINDUP=.115
local MONEY=Color3.fromRGB(113,246,146)
local GOLD=Color3.fromRGB(255,218,104)
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function label(parent,text,color,size)
 local v=Instance.new('TextLabel');v.BackgroundTransparency=1;v.Text=text;v.TextColor3=color
 v.TextSize=size;v.Font=Enum.Font.SourceSansBold;v.TextStrokeTransparency=.45
 v.AnchorPoint=Vector2.new(.5,.5);v.Size=UDim2.fromOffset(100,24);v.Parent=parent
 return v
end
function Sale.new(refs)
 local self=setmetatable({refs=refs,queue={},seen={},seenOrder={},flights={},readouts={},tiles={},ledgerFlights={},random=Random.new(),closed=false},Sale)
 local gui=Instance.new('ScreenGui');gui.Name='OreSaleCascade';gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets;gui.DisplayOrder=13;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=refs.player.PlayerGui
 self.gui=gui
 local blocker=Instance.new('Frame');blocker.Name='SaleInputArea';blocker.BackgroundTransparency=.60;blocker.BackgroundColor3=Color3.fromRGB(15,18,28)
 blocker.Active=true;blocker.Visible=false;blocker.Size=UDim2.fromScale(1,1);blocker.Parent=gui
 self.blocker=blocker
 local prompt=Instance.new('TextButton');prompt.Name='ConfirmSale';prompt.Visible=false
 prompt.AnchorPoint=Vector2.new(.5,1);prompt.Position=UDim2.new(.5,0,1,-32)
 prompt.Size=UDim2.fromOffset(214,49);prompt.BackgroundTransparency=1;prompt.TextStrokeTransparency=.54
 prompt.ZIndex=4;prompt.BorderSizePixel=0;prompt.TextColor3=GOLD;prompt.TextSize=22;prompt.Font=Enum.Font.SourceSansBold;prompt.Parent=gui
 prompt.Activated:Connect(function() self:confirm() end)
 self.prompt=prompt
 self.itemName=label(gui,'',Color3.fromRGB(249,247,240),28);self.itemName.Name='CurrentOre';self.itemName.Visible=false
 self.itemDetail=label(gui,'',GOLD,18);self.itemDetail.Name='CurrentOreModifiers';self.itemDetail.Visible=false
 self.price=label(gui,'',MONEY,48);self.price.Name='SelectedOreWorth';self.price.Visible=false
 self.bonus=label(gui,'',GOLD,23);self.bonus.Name='SelectedOreModifiers';self.bonus.Visible=false
 self.materials=label(gui,'',Color3.fromRGB(235,239,244),20);self.materials.Name='SelectedOreMaterials';self.materials.Visible=false
 self.bonus.TextScaled=true
 local bonusLimit=Instance.new('UITextSizeConstraint');bonusLimit.MinTextSize=14;bonusLimit.MaxTextSize=23;bonusLimit.Parent=self.bonus
 self.pages={}
 for i,direction in ipairs({-1,1}) do
  local button=Instance.new('TextButton');button.Name='BackpackPage';button.BackgroundTransparency=1
  button.Text=direction<0 and '‹' or '›';button.TextColor3=GOLD;button.TextSize=30;button.Size=UDim2.fromOffset(40,36);button.Visible=false;button.ZIndex=4;button.Parent=gui
  button.Activated:Connect(function()
   if self.active and (self.active.kind=='preview' or self.finished) then self.inspectIndex=math.clamp((math.floor((self.inspectIndex-1)/(self.pageSize or PAGE_SIZE))+direction)*(self.pageSize or PAGE_SIZE)+1,1,#self.tiles) end
  end)
  self.pages[i]=button
 end
 local back=Instance.new('TextButton');back.Name='CancelSale';back.AnchorPoint=Vector2.new(.5,1)
 back.Position=UDim2.new(.5,0,1,-4);back.Size=UDim2.fromOffset(110,26);back.BackgroundTransparency=1
 back.Text='Cancel';back.TextColor3=Color3.new(1,1,1);back.TextSize=17;back.Font=Enum.Font.SourceSansBold
 back.ZIndex=4;back.Visible=false;back.Parent=gui;back.Activated:Connect(function() self:cancel() end);self.back=back
 return self
end
function Sale:isOpen()
 return self.active and self.active.full==true
end
function Sale:confirm()
 if self.finished then self:clearGrid();return end
 local active=self.active
 if not active or active.kind~='preview' or self.pendingAt or os.clock()-self.started<.24 then return end
 self.pendingAt=os.clock()
 if self.refs.audio then self.refs.audio:play('sale_confirm') end
 if self.refs.confirm then self.refs.confirm(active.id) end
end
function Sale:cancel()
 if self.active and self.active.kind=='preview' and not self.pendingAt then
  if self.refs.cancel then self.refs.cancel(self.active.id) end
  self:clearGrid()
 end
end
function Sale:bindInput()
 if not self.refs.confirm or self.bound then return end
 self.bound=true
 local service=game:GetService('ProximityPromptService')
 self.promptsEnabled=service.Enabled;service.Enabled=false
 Actions:BindActionAtPriority(CONFIRM_ACTION,function(_,state,input)
  if state==Enum.UserInputState.Begin then
   if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then
    if self.finished then self:clearGrid() else self:cancel() end
   else self:confirm() end
  end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+10,Enum.KeyCode.E,Enum.KeyCode.ButtonX,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
end
function Sale:receiveProfile(profile)
 local runId=profile.run.id
 if self.runId and self.runId~=runId then
  self:clearGrid()
  for _,token in ipairs(self.flights) do token.view:Destroy() end
  for _,readout in ipairs(self.readouts) do readout.view:Destroy() end
  table.clear(self.queue);table.clear(self.flights);table.clear(self.readouts)
 end
 self.runId=runId
 for _,receipt in ipairs(profile.recentSales or {}) do self:receive(receipt) end
end
function Sale:registerPayout(receipt)
 local amounts={}
 if (receipt.cash or 0)>0 then amounts.Money=receipt.cash end
 receipt.waves={}
 local wave=0
 for _,key in ipairs(Workshop.RESOURCE_ORDER) do
  local value=(receipt.resources or {})[key] or 0
  if value>0 then amounts[key]=value;receipt.waves[key]=wave;wave+=1 end
 end
 self.refs.hud:beginSale(receipt,amounts)
 if self.refs.onCommitted then self.refs.onCommitted(receipt) end
end
function Sale:receive(receipt)
 if self.closed or type(receipt)~='table' or type(receipt.id)~='string' then return end
 if self.runId and receipt.runId and receipt.runId~=self.runId then return end
 if receipt.kind=='rejected' then
  if self.active and self.active.id==receipt.id then self:clearGrid() end
  return
 end
 local preview=receipt.kind=='preview'
 local seenId=preview and 'preview:'..receipt.id or receipt.id
 if self.seen[seenId] or type(receipt.cargo)~='table' then return end
 self.seen[seenId]=true;table.insert(self.seenOrder,seenId)
 if #self.seenOrder>128 then self.seen[table.remove(self.seenOrder,1)]=nil end
 receipt=table.clone(receipt)
 if not preview and self.active and self.active.kind=='preview' and receipt.id==self.active.id then
  receipt.items=self.active.items;self.active=receipt
  if self.ledger then self.ledger:begin() end
  self:registerPayout(receipt)
  self.pendingAt=nil;self.cascadeAt=os.clock();self.prompt.Visible=false;self.back.Visible=false
  return
 end
 local entries={}
 for key,units in pairs(receipt.cargo) do
  local item=Workshop.saleItem(key)
  if not item and Shops.COLORS[key] then item={key=key,name=key,rank=8,color=Shops.COLORS[key],cash=0,dust=0,stoneUnits=0} end
  if item and units>0 then item.units=units;entries[#entries+1]=item end
 end
 table.sort(entries,function(a,b) if a.rank~=b.rank then return a.rank<b.rank end;return a.key<b.key end)
 -- Bound each grid to 40 visible objects; very large legacy bags use counted
 -- stacks. Every stack retains its exact committed money and material totals.
 local expanded={}
 for _,item in ipairs(entries) do
  local count=math.min(item.units,math.max(1,math.floor(40/math.max(1,#entries))))
  for i=1,count do
   local copy=table.clone(item)
   copy.units=math.floor(item.units/count)+(i<=item.units%count and 1 or 0)
   expanded[#expanded+1]=copy
  end
 end
 if #expanded==0 then return end
 receipt.items=expanded
 if receipt.kind=='preview' then
  receipt.full=true
  if self.active and not self.active.full then self:clearGrid() end
  if not self.active and not self.refs.hidden() then self:start(receipt,os.clock())
  elseif self.refs.cancel then self.refs.cancel(receipt.id) end
 elseif #self.queue<8 then
  self:registerPayout(receipt)
  table.insert(self.queue,receipt)
 end
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
 proxy:SetAttribute('Mineral',item.key);proxy:SetAttribute('StoneCargo',item.stone)
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
 ore.Parent=self.refs.parent

 return ore,gem
end
function Sale:start(receipt,now)
 self.active=receipt;self.started=now;self.tiles={}
 self.finished=false;self.pendingTerms=nil;self.nextBreakAt=nil;self.inspectIndex=1
 self.cascadeAt=receipt.kind~='preview' and now or nil
 if receipt.full then
  local focus=Instance.new('DepthOfFieldEffect');focus.Name='SellingFocus';focus.FocusDistance=4;focus.InFocusRadius=2.5
  focus.NearIntensity=0;focus.FarIntensity=0;focus.Parent=Lighting;self.focus=focus
  self.ledger=SaleLedger.new(self.gui,receipt.items)
  if receipt.kind=='preview' then self.ledger:quote(receipt.items) end
  self.blocker.Visible=true;self:bindInput()
 end
 self.breakIndex=1;self.lastBreakAt=nil
 self.breakInterval=receipt.full and math.clamp(2.3/#receipt.items,.14,.245) or .12
 self.firstHit=receipt.full and FIRST_HIT or .30
 self.gemWindup=receipt.full and math.min(GEM_WINDUP,1.15/#receipt.items) or 0
 for i,item in ipairs(receipt.items) do
  local ore,gem=self:makeOre(item)
  local caption=label(self.gui,item.name..(item.units>1 and ' ×'..item.units or ''),Color3.fromRGB(table.unpack(item.color)),16)
  caption.TextStrokeTransparency=.12;caption.TextTruncate=Enum.TextTruncate.AtEnd;caption.ZIndex=3
  local worth=receipt.full and label(self.gui,'$'..tostring(item.cash*item.units),MONEY,25) or nil
  local mods={}
  for _,name in ipairs({'Charged','Frosted','Big','Massive','Titan'}) do if bit32.btest(item.mask or 0,Mining.ROCK_MODIFIERS[name]) then mods[#mods+1]=name end end
  local modifier=receipt.full and label(self.gui,'',GOLD,18) or nil
  local material=receipt.full and label(self.gui,'',Color3.fromRGB(table.unpack(item.color)),17) or nil
  local inspect
  if receipt.full then
   inspect=Instance.new('TextButton');inspect.Name='InspectOre';inspect.Text='';inspect.BackgroundTransparency=1;inspect.ZIndex=4;inspect.Parent=self.gui
   inspect.Activated:Connect(function() if self.active and (self.active.kind=='preview' or self.finished) then self.inspectIndex=i end end)
  end
  local tint=gem and RockFinish.Gems.tint(item.key) or ore.Color
  local effect=RockModifierView.glow(item.mask or 0) or (item.stone and Color3.fromRGB(table.unpack(item.color))) or tint
  local drop={view=ore,seed=i,physical=true,stone=item.stone,modifiers=item.mask or 0,color=tint,effectColor=effect,sale=receipt.full}
  self.tiles[i]={item=item,ore=ore,gem=gem,caption=caption,worth=worth,modifier=modifier,material=material,inspect=inspect,size=ore.Size,transparency=ore.Transparency,
   display=receipt.full and PickupDisplay.new(self.refs.parent,i,item.stone) or nil,drop=drop}
 end

end
local function createToken(parent,money,color)
 local token=Instance.new('Frame')
 token.Name=money and 'MoneyCoin' or 'MaterialFleck'
 token.AnchorPoint=Vector2.new(.5,.5);token.BorderSizePixel=0;token.BackgroundColor3=color;token.ZIndex=5
 if money then
  local round=Instance.new('UICorner');round.CornerRadius=UDim.new(.5,0);round.Parent=token
  local rim=Instance.new('UIStroke');rim.Color=Color3.fromRGB(39,126,67);rim.Thickness=1.5;rim.Parent=token
  local mark=label(token,'$',Color3.fromRGB(20,96,47),11)
  mark.Size=UDim2.fromScale(1,1);mark.Position=UDim2.fromScale(.5,.5);mark.TextStrokeTransparency=1;mark.ZIndex=6
 else
  local facet=Instance.new('Frame');facet.Name='Facet';facet.BorderSizePixel=0
  facet.BackgroundColor3=color:Lerp(Color3.new(1,1,1),.55);facet.Size=UDim2.fromScale(.38,1)
  facet.ZIndex=6;facet.Parent=token
 end
 token.Parent=parent
 return token
end

local function payoutText(money,key,amount,width,full)
 local number=money and '+$'..tostring(amount) or '+'..string.format('%.2f',amount/100):gsub('0+$',''):gsub('%.$','')
 if not full then return money and number or number..' '..Workshop.RESOURCE_NAMES[key],money and 23 or 19 end
 local preferred=money and (width>=155 and 39 or 33) or (width>=155 and 27 or 23)
 if money then return number,preferred end
 local name=Workshop.RESOURCE_NAMES[key]
 local text=number..' '..name
 local size=TextService:GetTextSize(text,preferred,Enum.Font.SourceSansBold,Vector2.new(2000,100)).X
 -- At phone widths keep the amount legible and name the mineral. The
 -- destination row still carries the complete resource name.
 if size>width and width<150 then text=number..' '..key end
 return text,preferred
end

function Sale:payout(key,amount,from,line,width,now)
 if amount<=0 then return end
 local receipt=self.active
 local money=key=='Money'
 local color=money and MONEY or Color3.fromRGB(table.unpack(Workshop.RESOURCE_COLORS[key]))
 local contents,preferred=payoutText(money,key,amount,width,receipt.full)
 local caption=label(self.gui,contents,color,preferred)
 caption.Name='SaleAmount_'..key;caption.TextScaled=true;caption.TextStrokeTransparency=.11
 caption.Size=UDim2.fromOffset(width,preferred+5);caption.ZIndex=4
 local limits=Instance.new('UITextSizeConstraint');limits.MaxTextSize=preferred;limits.Parent=caption
 local spacing=receipt.full and (width>=155 and 30 or 26) or 22
 local textOrigin=from+Vector2.new(0,line*spacing-spacing)
 caption.Position=UDim2.fromOffset(textOrigin.X,textOrigin.Y)
 local scale=Instance.new('UIScale');scale.Parent=caption
 table.insert(self.readouts,{view=caption,scale=scale,from=textOrigin,at=now,duration=receipt.full and READOUT_TIME or 1.02})

 local random=self.random
 local reduced=self.refs.reducedMotion()
 local count=math.min(amount,(reduced or not receipt.full) and 1 or money and 3 or 2)
 local phase=random:NextNumber(-math.pi,math.pi)
 receipt.tokensRemaining=(receipt.tokensRemaining or 0)+count
 for i=1,count do
  local angle=phase+(i-1)*math.pi*2/count+random:NextNumber(-.26,.26)
  local speed=random:NextNumber(165,300)*(receipt.full and 1 or .55)
  local direction=Vector2.new(math.cos(angle),math.sin(angle)*.70-.24)
  local token=createToken(self.gui,money,color)
  local size=money and random:NextNumber(15,19) or random:NextNumber(8,12)
  token.Size=UDim2.fromOffset(size,size);token.Position=UDim2.fromOffset(from.X,from.Y)
  table.insert(self.flights,{view=token,key=key,receipt=receipt,amount=math.floor(amount/count)+(i<=amount%count and 1 or 0),
   from=from,at=now,velocity=direction*speed,size=size,rotation=money and random:NextNumber(-35,35) or random:NextNumber(20,70),spin=random:NextNumber(-135,135),
   delay=receipt.full and random:NextNumber(.31,.45) or random:NextNumber(.13,.21),curve=random:NextNumber(-.24,.24),wave=receipt.waves[key] or 0,
   timing=random:NextNumber(.86,1.14),pitch=random:NextNumber(.90,1.12)})
 end
end

local function saleTerms(item)
 local terms={}
 local function push(key,paid,bonus,modifier)
  if paid<=0 then return end
  terms[#terms+1]={key=key,base=(paid-bonus)*item.units,bonus=bonus*item.units,modifier=modifier}
 end
 push('Money',item.cash,item.cashBonus or 0,item.cashMods)
 if item.resource then push(item.resource,item.dust,item.dustBonus or 0,item.dustMods) end
 push('Stone',item.stoneUnits,0,'')
 return terms
end
function Sale:launchLedgerTokens(terms,point,now,duration)
 if not point or not self.gui then return end
 if self.refs.reducedMotion() or self.refs.player:GetAttribute('ReducedEffects')==true then return end
 for j,term in ipairs(terms) do
  local row=self.ledger.rows[term.key]
  for i=1,2 do
   local angle=-math.pi*.9+(j*2+i)*.61
   local token=createToken(self.gui,term.key=='Money',row.color)
   token.Size=UDim2.fromOffset(10,10)
   local trail=Instance.new('Frame');trail.Name='SaleVelocityTrail';trail.BorderSizePixel=0
   trail.AnchorPoint=Vector2.new(.5,.5);trail.BackgroundColor3=row.color;trail.ZIndex=4;trail.Parent=self.gui
   self.ledgerFlights[#self.ledgerFlights+1]={view=token,trail=trail,row=row,from=point,at=now,duration=duration,
    velocity=Vector2.new(math.cos(angle),math.sin(angle))*230}
  end
 end
end
function Sale:updateLedgerTokens(now,reduced)
 for i=#(self.ledgerFlights or {}),1,-1 do
  local token=self.ledgerFlights[i];local age=now-token.at
  if reduced or age>=token.duration then
   token.view:Destroy();token.trail:Destroy();table.remove(self.ledgerFlights,i)
  else
   local launch=.13;local decay=7
   local t=math.clamp((age-launch)/(token.duration-launch),0,1)
   local endLaunch=token.from+token.velocity*((1-math.exp(-decay*launch))/decay)
   local tangent=token.velocity*math.exp(-decay*launch)*(token.duration-launch)
   local target=token.row.total.AbsolutePosition+token.row.total.AbsoluteSize*.5-GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets).Min
   local position
   if age<launch then position=token.from+token.velocity*((1-math.exp(-decay*age))/decay)
   else position=endLaunch*(2*t^3-3*t*t+1)+tangent*(t^3-2*t*t+t)+target*(-2*t^3+3*t*t) end
   local delta=position-(token.last or position)
   local speed=delta.Magnitude/math.max(1/240,now-(token.lastAt or now))
   token.last=position;token.lastAt=now
   token.view.Position=UDim2.fromOffset(position.X,position.Y);token.view.Rotation=age*280
   token.trail.Position=UDim2.fromOffset(position.X-delta.X*.5,position.Y-delta.Y*.5)
   token.trail.Size=UDim2.fromOffset(math.clamp(speed*.018,0,32),2)
   token.trail.Rotation=math.deg(math.atan2(delta.Y,delta.X));token.trail.BackgroundTransparency=.45+t*.4
  end
 end
end

function Sale:updateLedger(now,reduced)
 local ledger=self.ledger
 local pending=self.pendingTerms
 if pending then
  if now>=pending.addAt then
   ledger:add(pending.terms,now)
   for _,term in ipairs(pending.terms) do
    self.refs.hud:currencyHit(self.active.id,term.key,term.base+term.bonus,reduced)
   end
   if self.refs.audio then self.refs.audio:play('sale_credit',nil,{pitch=.94+math.min(8,self.breakIndex or 1)*.035,level=1.15}) end
   self.pendingTerms=nil;self.nextBreakAt=now+.04

  end
 end
 self:updateLedgerTokens(now,reduced)
 ledger:update(now,reduced)
end
function Sale:breakRock(tile,index,point,now,cameraUp,width)
 local item=tile.item;local color=tile.drop.effectColor
 if self.active.full then
  local terms=saleTerms(item)
  -- Bonuses have already been revealed on the intact rock. Post the final addend.
  local adjusted={}
  for _,term in ipairs(terms) do adjusted[#adjusted+1]={key=term.key,base=term.base+term.bonus,bonus=0} end
  self.ledger:stage(adjusted,now,item)
  self.pendingTerms={terms=terms,point=point,addAt=now+.32}
  self.currentItem=item;self.currentIndex=index
  self:launchLedgerTokens(terms,point,now,.32)

 else
  self:payout('Money',item.cash*item.units,point,0,width,now)
  if item.resource then self:payout(item.resource,item.dust*item.units,point,1,width,now) end
  if item.stoneUnits>0 then self:payout('Stone',item.stoneUnits*item.units,point,2,width,now) end
  if index==#self.tiles then self.active.dustAt=now+.30 end
 end
 if self.refs.audio then self.refs.audio:play(item.stone and 'sale_stone' or 'sale_gem',nil,{pitch=.90+(index%7)*.043,level=item.stone and 1.05 or 1.25}) end
 if not self.refs.reducedMotion() then
  if self.active.full then
   local character=self.refs.player.Character
   local root=character and character:FindFirstChild('HumanoidRootPart')
   self.refs.presentation:cameraBeat('Sale',root and root.Position or tile.ore.Position,workspace:GetServerTimeNow(),item.stone and 1 or 1.45)
  end
  if self.refs.player:GetAttribute('ReducedEffects')~=true then
   local size=tile.ore.Size
   local scale=math.clamp(math.max(size.X,size.Y,size.Z)*.19,.06,.26)
   RoleVisuals.ImpactParticles(tile.ore.Position,color,scale,'GemReward',cameraUp,nil,self.refs.parent)
  end
 end
 tile.hitAt=now;self.lastBreakAt=now
end
local function removeTile(tile)
 tile.ore:Destroy();if tile.caption then tile.caption:Destroy() end;tile.sold=true
 if tile.display then tile.display.base:Destroy() end
 if tile.worth then tile.worth:Destroy();tile.modifier:Destroy();tile.material:Destroy();tile.inspect:Destroy() end
end
function Sale:clearGrid()
 if self.active and (self.active.tokensRemaining or 0)>0 and not self.active.dustAt then
  self.active.dustAt=os.clock()+.24
 end
 for _,tile in ipairs(self.tiles) do if not tile.sold then removeTile(tile) end end
 if self.ledger then self.ledger:destroy();self.ledger=nil end
 self.finished=false;self.pendingTerms=nil;self.nextBreakAt=nil
 self.tiles={};self.active=nil;self.pendingAt=nil;self.cascadeAt=nil
 self.prompt.Visible=false;self.back.Visible=false;self.blocker.Visible=false
 self.itemName.Visible=false;self.itemDetail.Visible=false;self.price.Visible=false;self.bonus.Visible=false;self.materials.Visible=false;self.currentItem=nil;self.currentIndex=nil
 for _,token in ipairs(self.ledgerFlights or {}) do token.view:Destroy();token.trail:Destroy() end
 self.ledgerFlights={}
 for _,button in ipairs(self.pages) do button.Visible=false end
 if self.bound then
  Actions:UnbindAction(CONFIRM_ACTION);self.bound=false
  game:GetService('ProximityPromptService').Enabled=self.promptsEnabled
 end
 if self.focus then self.focus:Destroy();self.focus=nil end
end
function Sale:update()
 if self.closed then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local now=os.clock();local reduced=self.refs.reducedMotion()
 if not self.active and #self.queue>0 and not self.refs.hidden() then self:start(table.remove(self.queue,1),now) end
 if self.active then
  local age=now-self.started;local count=#self.tiles;local full=self.active.full
  local preview=self.active.kind=='preview'
  if preview and (self.pendingAt and now-self.pendingAt>15) then self:clearGrid();return end
  if self.ledger then self:updateLedger(now,reduced) end
  if preview or self.finished then
   local input=Input:GetLastInputType()
   local action=self.finished and 'Close' or 'Sell ore'
   self.prompt.Text=self.pendingAt and 'Selling…' or input==Enum.UserInputType.Touch and action
    or input.Name:match('^Gamepad') and 'X   '..action or 'E   '..action
   self.prompt.Visible=age>=.24;self.back.Visible=preview and self.prompt.Visible and not self.pendingAt
  end
  local viewport=camera.ViewportSize
  local stacked=full and viewport.X<760
  local pageSize=stacked and 2 or PAGE_SIZE;self.pageSize=pageSize
  local selected=(preview or self.finished) and self.inspectIndex or (self.currentIndex or self.breakIndex)
  local page=full and math.floor((math.min(selected,count)-1)/pageSize) or 0
  local shownCount=full and math.min(pageSize,count-page*pageSize) or count
  local columns=full and math.min(2,shownCount) or math.min(5,shownCount)
  local rows=math.ceil(shownCount/columns)
  local spreadWidth=viewport.X*(stacked and .92 or .65)
  local top=viewport.Y*(stacked and .08 or .13)
  local spreadHeight=viewport.Y*(stacked and .55 or .66)
  local rowPitch=spreadHeight/math.max(stacked and 1 or 2,rows)
  local cell=full and math.max(32,math.min(180,spreadWidth/columns-28,rowPitch-110)) or 55
  local center=full and Vector2.new(viewport.X*(stacked and .5 or .36),top+spreadHeight*.5-45) or Vector2.new(viewport.X*.5,viewport.Y*.24)
  for i,button in ipairs(self.pages) do
   button.Visible=full and (preview or self.finished) and count>pageSize
   button.Position=UDim2.fromOffset(center.X+(i==1 and -65 or 25),top+spreadHeight-12)
  end
  -- Each rock owns its arithmetic; there is no second inspection panel.
  for _,v in ipairs({self.itemName,self.itemDetail,self.price,self.bonus,self.materials}) do v.Visible=false end
  if self.ledger then
   if stacked then self.ledger:layout(viewport.X*.08,viewport.Y*.69,viewport.X*.84,viewport.Y*.31-76)
   else self.ledger:layout(viewport.X*.73,viewport.Y*.20,viewport.X*.23,viewport.Y*.64) end
  end
  local lastHit=self.tiles[count].hitAt
  if self.focus then
   local fade=lastHit and smooth((now-lastHit-.77)/.38) or 0
   self.focus.FarIntensity=.34*smooth(age/.22)*(1-.36*fade)
  end
  local scheduledIndex=self.breakIndex
  local nextTile=self.tiles[scheduledIndex]
  local breakAt
  if self.cascadeAt and nextTile and not self.pendingTerms then
   if full then
    if not nextTile.focusAt then
     nextTile.focusAt=math.max(self.cascadeAt+self.firstHit,self.nextBreakAt or 0,now)
     self.currentItem=nextTile.item;self.currentIndex=scheduledIndex
    end
    local hasBonus=(nextTile.item.cashBonus or 0)>0 or (nextTile.item.dustBonus or 0)>0
    if hasBonus and not nextTile.bonusShown and now>=nextTile.focusAt+.22 then
     nextTile.bonusShown=true;nextTile.bonusAt=now
     if self.refs.audio then self.refs.audio:play('sale_dust_credit',nil,{pitch=1.06,level=1.2}) end
    end
    breakAt=nextTile.focusAt+(hasBonus and .58 or .24)
   else breakAt=self.lastBreakAt and self.lastBreakAt+self.breakInterval or self.cascadeAt+self.firstHit end
  end
  local depth=4;local unitsPerPixel=2*depth*math.tan(math.rad(camera.FieldOfView*.5))/viewport.Y
  for i,tile in ipairs(self.tiles) do if not tile.sold then
   local onPage=not full or math.floor((i-1)/pageSize)==page
   if full then
    tile.ore.LocalTransparencyModifier=onPage and 0 or 1
    for _,v in ipairs({tile.caption,tile.worth,tile.modifier,tile.material}) do v.Visible=onPage end
    tile.inspect.Visible=onPage and preview
    if not onPage then if tile.display then PickupDisplay.hide(tile.display) end;continue end
   end
   local slot=full and (i-1)%pageSize or i-1
   local row=math.floor(slot/columns);local column=slot%columns
   local point=center+Vector2.new((column-(columns-1)*.5)*(full and spreadWidth/columns or cell),(row-(rows-1)*.5)*(full and rowPitch or cell))
   local impactAge=now-(self.lastBreakAt or -100)
   if full and not reduced and impactAge<.20 then
    local impulse=math.exp(-impactAge*22)
    point+=Vector2.new(math.sin(impactAge*95)*7,-math.cos(impactAge*73)*5)*impulse
   end
   local rise=reduced and 1 or smooth((age-(i-1)*.008)/.27)
   point+=Vector2.new(0,(1-rise)*65)
   local ray=camera:ViewportPointToRay(point.X,point.Y)
   local position=ray.Origin+ray.Direction*(depth/math.max(.1,ray.Direction:Dot(camera.CFrame.LookVector)))
   local hit=tile.hitAt and math.clamp((now-tile.hitAt)/BREAK_TIME,0,1) or 0
   local familySize=Mining.ORE_SIZE_SCALE[Mining.sizeTier(tile.item.mask)]
   local active=full and not preview and i==self.currentIndex
   local focusAge=math.max(0,now-(tile.focusAt or now))
   local emphasis=active and (reduced and 1.18 or 1+.18*smooth(focusAge/.13)) or 1
   local scale=emphasis*cell*(full and .70*math.min(1.27,familySize^.36) or .70)*unitsPerPixel/math.max(tile.size.X,tile.size.Y,tile.size.Z)
   local winding=not reduced and full and breakAt and i==self.breakIndex and not tile.hitAt
   local anticipation=winding and smooth((now-breakAt+.15)/.15) or 0
   if tile.hitAt and not reduced then scale*=1+.12*math.sin(hit*math.pi)-.12*hit*hit end
   tile.ore.Size=tile.size*Vector3.new(1+.14*anticipation,1-.23*anticipation,1+.14*anticipation)*scale*(.7+.3*rise)
   tile.ore.CFrame=CFrame.new(position)*camera.CFrame.Rotation*CFrame.Angles(.16,(reduced and .3 or age*.45)+i*.6,.12)
   if tile.gem then RockFinish.Gems.update(tile.ore,rise*(1-hit*(full and .32 or 1)),camera.CFrame.Position) end
   if tile.hitAt then tile.ore.Transparency=tile.transparency+(1-tile.transparency)*hit*(full and .32 or 1) end
   if tile.caption then
    if full then
     local item=tile.item
     local width=spreadWidth/columns-16
     local y=point.Y+cell*.43+12
     local shown=preview or tile.bonusShown or tile.hitAt
     local base=(item.cash-(item.cashBonus or 0))*item.units
     local bonus=(item.cashBonus or 0)*item.units
     tile.caption.Position=UDim2.fromOffset(point.X,y);tile.caption.Size=UDim2.fromOffset(width,24)
     tile.caption.TextSize=18;tile.caption.TextTransparency=tile.settled and .25 or 0
     tile.worth.Position=UDim2.fromOffset(point.X,y+28);tile.worth.Size=UDim2.fromOffset(width,34)
     tile.worth.Text=bonus>0 and ('$'..base..' → $'..(shown and item.cash*item.units or base)) or '$'..item.cash*item.units
     local pulse=math.exp(-math.max(0,now-(tile.bonusAt or -100))*10)
     tile.worth.TextSize=28+(reduced and 0 or math.floor(6*pulse))
     tile.modifier.Position=UDim2.fromOffset(point.X,y+54);tile.modifier.Size=UDim2.fromOffset(width,24)
     tile.modifier.Text=bonus>0 and (item.cashMods..' +$'..bonus) or ''
     tile.modifier.TextSize=16;tile.modifier.TextTransparency=shown and 0 or .65
     local amounts={}
     if item.stoneUnits>0 then amounts[#amounts+1]=string.format('%g Stone',item.stoneUnits*item.units/100) end
     if item.resource and item.dust>0 then
      local dust=item.dust*item.units/100
      local extra=(item.dustBonus or 0)*item.units/100
      local amount=extra>0 and string.format('%g → %g',dust-extra,shown and dust or dust-extra) or string.format('%g',dust)
      amounts[#amounts+1]=amount..' '..Workshop.RESOURCE_NAMES[item.resource]
      if extra>0 then amounts[#amounts+1]=item.dustMods..' +'..string.format('%g',extra) end
     end
     tile.material.Text=table.concat(amounts,' · ');tile.material.TextWrapped=true
     tile.material.Position=UDim2.fromOffset(point.X,y+84);tile.material.Size=UDim2.fromOffset(width,38)
     tile.inspect.Visible=false
    else
     tile.caption.Position=UDim2.fromOffset(point.X,point.Y+cell*.39)
     tile.caption.Size=UDim2.fromOffset(cell*.96,26);tile.caption.TextSize=12
     tile.caption.TextTransparency=1-rise*(1-hit)
    end
   end
   if tile.display and not tile.hitAt then
    local effects=self.refs.player:GetAttribute('ReducedEffects')==true
    tile.drop.displayScale=math.max(.08,scale)*familySize
    PickupDisplay.draw(tile.display,tile.drop,(tile.ore.CFrame*CFrame.new(0,-tile.ore.Size.Y*.38,0)).Position,
     now,rise,reduced,effects)
    if tile.drop.modifiers~=0 and not effects and not reduced then
     RockModifierView.drop(tile.drop,now,1,self.refs.player:GetAttribute('ReducedFlashing')==true,tile.drop.displayScale)
    end
   elseif tile.display then PickupDisplay.hide(tile.display) end
   if tile.hitAt and hit>=1 and not tile.settled then
    tile.settled=true
    if not full then removeTile(tile) end
    self.breakIndex+=1
   elseif i==scheduledIndex and i==self.breakIndex and not tile.hitAt and breakAt and now>=breakAt then
    -- Advance only after the prior rock is gone, even when a frame stalls.
    self:breakRock(tile,i,point,now,camera.CFrame.UpVector,math.clamp(cell*.98,84,282))
   end
  end end
  if lastHit and not self.pendingTerms and now-lastHit>(full and FINISH_HOLD or .90) then
   if full then
    if not self.finished then
     self.finished=true;self.ledger:finish(self.active,now)
     for _,view in ipairs({self.itemName,self.itemDetail,self.price,self.bonus,self.materials}) do view.Visible=false end
     if self.refs.audio then self.refs.audio:play('sale_finish') end
    end
   else self:clearGrid() end
  end
 end
 self:updatePayouts(now,reduced)
end

-- Integrate a fast burst and a small residual drift. Both feed the velocity
-- at the start of the pull, so there is no stop or snap between phases.
local function drift(token,age,reduced)
 if reduced then return token.from,Vector2.zero end
 local fast=math.exp(-5.6*age)
 local slow=math.exp(-.78*age)
 local offset=(1-fast)/5.6+.065*(1-slow)/.78
 return token.from+token.velocity*offset,token.velocity*(fast+.065*slow)
end

function Sale:updatePayouts(now,reduced)
 local inset=GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets).Min
 for i=#self.flights,1,-1 do
  local token=self.flights[i]
  local money=token.key=='Money'
  local pullAt=money and token.at+token.delay or token.receipt.dustAt
  if pullAt and not money then pullAt+=token.wave*DUST_WAVE_STEP+(token.delay-(token.receipt.full and .31 or .13))*.84 end
  local target=self.refs.hud:currencyTarget(token.key)
  local age=math.max(0,now-token.at)
  local position=drift(token,age,reduced)
  local progress=0
  if pullAt and now>=pullAt and target then
   target-=inset
   if not token.pullAt then
    token.pullAt=math.max(pullAt,now-.05)
    token.origin,token.initial=drift(token,math.max(0,token.pullAt-token.at),reduced)
    local duration=token.receipt.full and math.clamp(.39+(target-token.origin).Magnitude/2300,.44,.73)
     or math.clamp(.27+(target-token.origin).Magnitude/2700,.29,.54)
    token.duration=duration*token.timing
   end
   progress=math.clamp((now-token.pullAt)/token.duration,0,1)
   if not reduced then
    local delta=target-token.origin
    local tangent=Vector2.new(-delta.Y,delta.X)
    local p1=token.origin+token.initial*(token.duration/3)
    local p2=target-delta*.48+tangent*token.curve
    local t=progress;local u=1-t
    position=token.origin*(u^3)+p1*(3*u*u*t)+p2*(3*u*t*t)+target*(t^3)
   end
  end
  if progress>=1 or (pullAt and now-pullAt>3) or age>18 then
   local receipt=token.receipt
   receipt.tokensRemaining-=1
   local last=progress>=1 and receipt.full and receipt.dustAt~=nil and receipt.tokensRemaining==0
   self.refs.hud:currencyHit(receipt.id,token.key,token.amount,reduced,last)
   if progress>=1 and self.refs.audio then
    local cue=last and 'sale_finish' or money and 'sale_credit' or 'sale_dust_credit'
    self.refs.audio:play(cue,nil,{pitch=last and 1 or token.pitch})
   end
   token.view:Destroy();table.remove(self.flights,i)
  else
   local stretch=reduced and 0 or progress*.32
   token.view.Position=UDim2.fromOffset(position.X,position.Y)
   token.view.Rotation=reduced and (money and 0 or 45) or token.rotation+token.spin*(1-math.exp(-2.4*age))/2.4
   local aspect=money and 1 or .73
   token.view.Size=UDim2.fromOffset(token.size*aspect*(1-stretch*.7),token.size*(1+stretch))
  end
 end
 for i=#self.readouts,1,-1 do
  local readout=self.readouts[i]
  local age=now-readout.at
  local t=math.clamp(age/readout.duration,0,1)
  if t>=1 then
   readout.view:Destroy();table.remove(self.readouts,i)
  else
   local rise=reduced and 0 or 11*smooth(t)
   readout.view.Position=UDim2.fromOffset(readout.from.X,readout.from.Y-rise)
   local fade=smooth((t-.77)/.23)
   readout.view.TextTransparency=fade;readout.view.TextStrokeTransparency=.11+.89*fade
   local pop=math.clamp(age/.17,0,1)
   readout.scale.Scale=reduced and 1 or 1+.13*math.sin(math.pi*pop)*(1-pop*.35)
  end
 end
end
function Sale:destroy()
 if self.closed then return end;self.closed=true;self:clearGrid()
 self.gui:Destroy();self.queue={};self.flights={};self.readouts={}
end
return Sale
