-- A committed sale is a cosmetic receipt. Animation never grants or spends money.
local SaleLedger=require('./SaleLedger')
local Sale={};Sale.__index=Sale
local Lighting=game:GetService('Lighting')
local GuiService=game:GetService('GuiService')
local Input=game:GetService('UserInputService')
local Actions=game:GetService('ContextActionService')
local TextService=game:GetService('TextService')
local CONFIRM_ACTION='MiningAwayConfirmSale'
local FIRST_HIT=.58
local BREAK_TIME=.08
local FINISH_HOLD=1.48
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
 local blocker=Instance.new('Frame');blocker.Name='SaleInputArea';blocker.BackgroundTransparency=.72;blocker.BackgroundColor3=Color3.fromRGB(15,18,28)
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
 self.finished=false;self.pendingTerms=nil;self.nextBreakAt=nil
 self.cascadeAt=receipt.kind~='preview' and now or nil
 if receipt.full then
  local focus=Instance.new('DepthOfFieldEffect');focus.Name='SellingFocus';focus.FocusDistance=4;focus.InFocusRadius=2.5
  focus.NearIntensity=0;focus.FarIntensity=0;focus.Parent=Lighting;self.focus=focus
  self.ledger=SaleLedger.new(self.gui,receipt.items)
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
  local tint=gem and RockFinish.Gems.tint(item.key) or ore.Color
  local effect=RockModifierView.glow(item.mask or 0) or (item.stone and Color3.fromRGB(table.unpack(item.color))) or tint
  local drop={view=ore,seed=i,physical=true,stone=item.stone,modifiers=item.mask or 0,color=tint,effectColor=effect,sale=receipt.full}
  self.tiles[i]={item=item,ore=ore,gem=gem,caption=caption,size=ore.Size,transparency=ore.Transparency,
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
   local target=token.row.terms.AbsolutePosition+token.row.terms.AbsoluteSize-Vector2.new(24,12)-GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets).Min
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
  if pending.modifierAt and now>=pending.modifierAt then
   ledger:applyModifier(pending.terms,now)
   pending.modifierAt=nil;pending.addAt=now+.58
   self:launchLedgerTokens(pending.terms,pending.point,now,.58)
   if self.refs.audio then self.refs.audio:play('sale_dust_credit',nil,{pitch=.84}) end
  elseif not pending.modifierAt and now>=pending.addAt then
   ledger:add(pending.terms,now)
   for _,term in ipairs(pending.terms) do
    self.refs.hud:currencyHit(self.active.id,term.key,term.base+term.bonus,reduced)
   end
   if self.refs.audio then self.refs.audio:play('sale_credit',nil,{pitch=.94+math.min(8,self.breakIndex or 1)*.035,level=1.35}) end
   self.pendingTerms=nil;self.nextBreakAt=now+.24
  end
 end
 self:updateLedgerTokens(now,reduced)
 ledger:update(now,reduced)
end
function Sale:breakRock(tile,index,point,now,cameraUp,width)
 local item=tile.item;local color=tile.drop.effectColor
 if self.active.full then
  local terms=saleTerms(item)
  local hasBonus=false
  for _,term in ipairs(terms) do if term.bonus>0 then hasBonus=true;break end end
  self.ledger:stage(terms,now,item)
  self.pendingTerms={terms=terms,point=point,addAt=now+.48,modifierAt=hasBonus and now+.3 or nil}
  self.currentItem=item;self.currentIndex=index
  if not hasBonus then self:launchLedgerTokens(terms,point,now,.48) end
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
 self.itemName.Visible=false;self.itemDetail.Visible=false;self.currentItem=nil;self.currentIndex=nil
 for _,token in ipairs(self.ledgerFlights or {}) do token.view:Destroy();token.trail:Destroy() end
 self.ledgerFlights={}
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
  if preview and (age>44 or (self.pendingAt and now-self.pendingAt>15)) then self:clearGrid();return end
  if self.ledger then self:updateLedger(now,reduced) end
  if preview or self.finished then
   local input=Input:GetLastInputType()
   local action=self.finished and 'Close' or 'Sell ore'
   self.prompt.Text=self.pendingAt and 'Selling…' or input==Enum.UserInputType.Touch and action
    or input.Name:match('^Gamepad') and 'X   '..action or 'E   '..action
   self.prompt.Visible=age>=.24;self.back.Visible=preview and self.prompt.Visible and not self.pendingAt
  end
  local viewport=camera.ViewportSize
  local stacked=full and viewport.X<650
 local spreadWidth=viewport.X*(stacked and .76 or .39)
 local spreadHeight=viewport.Y*(stacked and .26 or .52)
 local columns=math.min(4,count,math.max(1,math.ceil(math.sqrt(count*1.15))))
  local rows=math.ceil(count/columns)
 local cell=full and math.min(160,spreadWidth/columns,spreadHeight/rows)
  or math.min(55,(viewport.X-40)/columns,viewport.Y*.48/rows)
  local center=full and Vector2.new(viewport.X*(stacked and .5 or .275),viewport.Y*(stacked and .205 or .50))
   or Vector2.new(viewport.X*.5,viewport.Y*.24)
  if full then
   self.itemName.Visible=true;self.itemDetail.Visible=true
   self.itemName.Position=UDim2.fromOffset(center.X,viewport.Y*(stacked and .355 or .82))
   self.itemName.Size=UDim2.fromOffset(spreadWidth+28,34);self.itemName.TextSize=stacked and 22 or 28
   self.itemDetail.Position=self.itemName.Position+UDim2.fromOffset(0,31)
   self.itemDetail.Size=UDim2.fromOffset(spreadWidth+28,28);self.itemDetail.TextSize=stacked and 15 or 18
   local current=self.currentItem or (self.tiles[self.breakIndex] and self.tiles[self.breakIndex].item)
   self.itemName.Text=self.finished and 'Backpack sold' or preview and 'Your backpack' or current and current.name or ''
   local mods={}
   if current then for _,name in ipairs({'Charged','Frosted','Big','Massive','Titan'}) do
    if bit32.btest(current.mask or 0,Mining.ROCK_MODIFIERS[name]) then mods[#mods+1]=name end
   end end
   self.itemDetail.Text=self.finished and 'All payouts added' or preview and tostring(count)..' pieces'
    or tostring(self.currentIndex or 1)..' / '..count..(#mods>0 and ' · '..table.concat(mods,' + ') or '')
  end
  if self.ledger then
   local left=viewport.X*(stacked and .06 or .52)
   local top=viewport.Y*(stacked and .44 or .13)
   self.ledger:layout(left,top,viewport.X-left-viewport.X*.055,math.max(100,viewport.Y-top-85))
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
   breakAt=self.nextBreakAt or (self.lastBreakAt and self.lastBreakAt+self.breakInterval or self.cascadeAt+self.firstHit)
   if not nextTile.item.stone then breakAt+=self.gemWindup end
  end
  local depth=4;local unitsPerPixel=2*depth*math.tan(math.rad(camera.FieldOfView*.5))/viewport.Y
  for i,tile in ipairs(self.tiles) do if not tile.sold then
   local row=math.floor((i-1)/columns);local column=(i-1)%columns
   local point=center+Vector2.new((column-(columns-1)*.5)*cell+(full and (row%2)*cell*.12 or 0),(row-(rows-1)*.5)*cell)
   local rise=reduced and 1 or smooth((age-(i-1)*.008)/.27)
   point+=Vector2.new(0,(1-rise)*65)
   local ray=camera:ViewportPointToRay(point.X,point.Y)
   local position=ray.Origin+ray.Direction*(depth/math.max(.1,ray.Direction:Dot(camera.CFrame.LookVector)))
   local hit=tile.hitAt and math.clamp((now-tile.hitAt)/BREAK_TIME,0,1) or 0
   local familySize=Mining.ORE_SIZE_SCALE[Mining.sizeTier(tile.item.mask)]
   local scale=cell*(full and .66*math.min(1.27,familySize^.36) or .70)*unitsPerPixel/math.max(tile.size.X,tile.size.Y,tile.size.Z)
   local winding=not reduced and full and breakAt and i==self.breakIndex and not tile.hitAt
   local anticipation=winding and smooth((now-breakAt+.15)/.15) or 0
   if tile.hitAt and not reduced then scale*=1+.16*math.sin(hit*math.pi)-.65*hit*hit end
   tile.ore.Size=tile.size*Vector3.new(1+.09*anticipation,1-.18*anticipation,1+.09*anticipation)*scale*(.7+.3*rise)
   tile.ore.CFrame=CFrame.new(position)*camera.CFrame.Rotation*CFrame.Angles(.16,(reduced and .3 or age*.45)+i*.6,.12)
   if tile.gem then RockFinish.Gems.update(tile.ore,rise*(1-hit),camera.CFrame.Position) end
   if tile.hitAt then tile.ore.Transparency=tile.transparency+(1-tile.transparency)*hit end
   if tile.caption then
    tile.caption.Position=UDim2.fromOffset(point.X,point.Y+cell*.43)
    tile.caption.Size=UDim2.fromOffset(cell*.96,26)
    tile.caption.TextSize=full and (cell<80 and 13 or 16) or 12;tile.caption.TextTransparency=1-rise*(1-hit)
    if full and self.cascadeAt then
     tile.caption.Text=(i==self.breakIndex and '› ' or '')..tile.item.name..(tile.item.units>1 and ' ×'..tile.item.units or '')
     if i~=self.breakIndex then tile.caption.TextTransparency=math.max(.35,tile.caption.TextTransparency) end
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
   if tile.hitAt and hit>=1 then
    removeTile(tile)
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
