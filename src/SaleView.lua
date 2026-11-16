-- A committed sale is a cosmetic receipt. Animation never grants or spends money.
local Sale={};Sale.__index=Sale
local Lighting=game:GetService('Lighting')
local GuiService=game:GetService('GuiService')
local Input=game:GetService('UserInputService')
local Actions=game:GetService('ContextActionService')
local CONFIRM_ACTION='MiningAwayConfirmSale'
local FIRST_HIT=.38
local BREAK_TIME=.065
local FINISH_HOLD=.95
local READOUT_TIME=.92
local DUST_WAVE_STEP=.16
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
 local self=setmetatable({refs=refs,queue={},seen={},seenOrder={},flights={},readouts={},tiles={},random=Random.new(),closed=false},Sale)
 local gui=Instance.new('ScreenGui');gui.Name='OreSaleCascade';gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets;gui.DisplayOrder=13;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=refs.player.PlayerGui
 self.gui=gui
 local blocker=Instance.new('Frame');blocker.Name='SaleInputArea';blocker.BackgroundTransparency=1
 blocker.Active=true;blocker.Visible=false;blocker.Size=UDim2.fromScale(1,1);blocker.Parent=gui
 self.blocker=blocker
 self.title=label(gui,'',Color3.new(1,1,1),24);self.title.Visible=false
 self.title.Size=UDim2.fromOffset(300,34);self.title.ZIndex=2
 local prompt=Instance.new('TextButton');prompt.Name='ConfirmSale';prompt.Visible=false
 prompt.AnchorPoint=Vector2.new(.5,1);prompt.Position=UDim2.new(.5,0,1,-32)
 prompt.Size=UDim2.fromOffset(214,49);prompt.BackgroundColor3=Color3.fromRGB(33,27,20)
 prompt.ZIndex=4;prompt.BorderSizePixel=0;prompt.TextColor3=GOLD;prompt.TextSize=22;prompt.Font=Enum.Font.SourceSansBold;prompt.Parent=gui
 local stroke=Instance.new('UIStroke');stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 stroke.Color=GOLD;stroke.Transparency=.2;stroke.Thickness=2;stroke.Parent=prompt
 prompt.Activated:Connect(function() self:confirm() end)
 self.prompt=prompt
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
   if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then self:cancel()
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
 proxy.Size=Vector3.new(1,.82,1);proxy.Color=Color3.fromRGB(88,84,81):Lerp(Color3.fromRGB(table.unpack(item.color)),.32)
 proxy.Material=Enum.Material.Slate;proxy.MaterialVariant='';proxy.Reflectance=0
 if proxy:IsA('PartOperation') then proxy.UsePartColor=true end
 local ore,gem=RockFinish.Gems.clone(proxy);proxy:Destroy()
 ore.Name='Selling_'..item.name;ore.Anchored=true;ore.CanCollide=false;ore.CanTouch=false;ore.CanQuery=false;ore.CastShadow=false
 ore.LocalTransparencyModifier=0;ore.Transparency=gem and 1-(ore:GetAttribute('GemOpacity') or .8) or 0
 ore.Parent=self.refs.parent
 local outline
 if item.stone then
  outline=Instance.new('Highlight');outline.Adornee=ore;outline.FillTransparency=1
  outline.OutlineColor=Color3.fromRGB(table.unpack(item.color));outline.OutlineTransparency=.1
  outline.DepthMode=Enum.HighlightDepthMode.Occluded;outline.Parent=ore
 end
 return ore,gem
end
function Sale:start(receipt,now)
 self.active=receipt;self.started=now;self.tiles={}
 self.cascadeAt=receipt.kind~='preview' and now or nil
 if receipt.full then
  local focus=Instance.new('DepthOfFieldEffect');focus.Name='SellingFocus';focus.FocusDistance=4;focus.InFocusRadius=2.5
  focus.NearIntensity=0;focus.FarIntensity=0;focus.Parent=Lighting;self.focus=focus
  self.blocker.Visible=true;self:bindInput()
 end
 self.breakIndex=1;self.lastBreakAt=nil
 self.breakInterval=receipt.full and math.clamp(1.25/#receipt.items,.085,.13) or .085
 local count=0
 for i,item in ipairs(receipt.items) do
  local ore,gem=self:makeOre(item)
  local caption=label(self.gui,item.units>1 and item.name..' ×'..item.units or item.name,Color3.fromRGB(table.unpack(item.color)),14)
  count+=item.units
  self.tiles[i]={item=item,ore=ore,gem=gem,caption=caption,size=ore.Size,transparency=ore.Transparency}
 end
 self.title.Text='Backpack  ·  '..count..' ore'
 self.title.Visible=receipt.full
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

function Sale:payout(key,amount,from,line,width,now)
 if amount<=0 then return end
 local money=key=='Money'
 local color=money and MONEY or Color3.fromRGB(table.unpack(Workshop.RESOURCE_COLORS[key]))
 local number=money and tostring(amount) or string.format('%.2f',amount/100):gsub('0+$',''):gsub('%.$','')
 local caption=label(self.gui,money and '+$'..number or '+'..number..' '..Workshop.RESOURCE_NAMES[key],color,money and 21 or 16)
 caption.Name='SaleAmount_'..key;caption.TextScaled=true;caption.TextStrokeTransparency=.22
 caption.Size=UDim2.fromOffset(width,money and 25 or 20);caption.ZIndex=4
 local limits=Instance.new('UITextSizeConstraint');limits.MaxTextSize=money and 21 or 18;limits.Parent=caption
 local textOrigin=from+Vector2.new(0,line*20-17)
 caption.Position=UDim2.fromOffset(textOrigin.X,textOrigin.Y)
 table.insert(self.readouts,{view=caption,from=textOrigin,at=now})

 local receipt=self.active
 local random=self.random
 local reduced=self.refs.reducedMotion()
 local count=math.min(amount,(reduced or not receipt.full) and 1 or money and 3 or 2)
 local phase=random:NextNumber(-math.pi,math.pi)
 for i=1,count do
  local angle=phase+(i-1)*math.pi*2/count+random:NextNumber(-.26,.26)
  local speed=random:NextNumber(165,300)*(receipt.full and 1 or .55)
  local direction=Vector2.new(math.cos(angle),math.sin(angle)*.70-.24)
  local token=createToken(self.gui,money,color)
  local size=money and random:NextNumber(13,16) or random:NextNumber(6.5,10)
  token.Size=UDim2.fromOffset(size,size);token.Position=UDim2.fromOffset(from.X,from.Y)
  table.insert(self.flights,{view=token,key=key,receipt=receipt,amount=math.floor(amount/count)+(i<=amount%count and 1 or 0),
   from=from,at=now,velocity=direction*speed,size=size,rotation=money and random:NextNumber(-35,35) or random:NextNumber(20,70),spin=random:NextNumber(-135,135),
   delay=random:NextNumber(.11,.22),curve=random:NextNumber(-.24,.24),wave=receipt.waves[key] or 0,
   timing=random:NextNumber(.86,1.14),pitch=random:NextNumber(.90,1.12)})
 end
end

function Sale:breakRock(tile,index,point,now,cameraUp,width)
 local item=tile.item;local color=Color3.fromRGB(table.unpack(item.color))
 self:payout('Money',item.cash*item.units,point,0,width,now)
 if item.resource then self:payout(item.resource,item.dust*item.units,point,1,width,now) end
 if item.stoneUnits>0 then self:payout('Stone',item.stoneUnits*item.units,point,2,width,now) end
 if index==#self.tiles then self.active.dustAt=now+(self.active.full and .30 or .26) end
 if self.refs.audio then self.refs.audio:play(item.stone and 'sale_stone' or 'sale_gem',nil,{pitch=.89+(index%8)*.045}) end
 if not self.refs.reducedMotion() then
  if self.active.full then
   local character=self.refs.player.Character
   local root=character and character:FindFirstChild('HumanoidRootPart')
   self.refs.presentation:cameraBeat('Sale',root and root.Position or tile.ore.Position,workspace:GetServerTimeNow(),item.stone and .8 or 1.2)
  end
  if self.refs.player:GetAttribute('ReducedEffects')~=true then
   local size=tile.ore.Size
   local scale=math.clamp(math.max(size.X,size.Y,size.Z)*.19,.06,.26)
   RoleVisuals.ImpactParticles(tile.ore.Position,color,scale,'GemReward',cameraUp,nil,self.refs.parent)
  end
 end
 tile.hitAt=now;self.lastBreakAt=now
end
function Sale:clearGrid()
 for _,tile in ipairs(self.tiles) do if not tile.sold then tile.ore:Destroy();tile.caption:Destroy() end end
 self.tiles={};self.active=nil;self.title.Visible=false;self.pendingAt=nil;self.cascadeAt=nil
 self.prompt.Visible=false;self.back.Visible=false;self.blocker.Visible=false
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
  local cascadeAge=self.cascadeAt and now-self.cascadeAt
  if preview then
   local input=Input:GetLastInputType()
   self.prompt.Text=self.pendingAt and 'Selling…' or input==Enum.UserInputType.Touch and 'Sell ore'
    or input.Name:match('^Gamepad') and 'X   Sell ore' or 'E   Sell ore'
   self.prompt.Visible=age>=.24;self.back.Visible=self.prompt.Visible and not self.pendingAt
  end
  local viewport=camera.ViewportSize
  local limit=full and (viewport.X<600 and 5 or 8) or 4
  local aspect=math.clamp(viewport.X/math.max(1,viewport.Y),.55,1.85)
  local columns=math.min(limit,count,math.max(1,math.ceil(math.sqrt(count*aspect))))
  local rows=math.ceil(count/columns)
  local cell=math.min(full and viewport.Y*.46 or 55,(viewport.X-40)/columns,(viewport.Y*(full and .65 or .48))/rows)
  local center=full and Vector2.new(viewport.X*.5,viewport.Y*.465) or Vector2.new(viewport.X*.5,viewport.Y*.24)
  self.title.Position=UDim2.fromOffset(center.X,math.max(35,center.Y-rows*cell*.5-13))
  local lastHit=self.tiles[count].hitAt
  if self.focus then
   local fade=lastHit and smooth((now-lastHit-.52)/.25) or 0
   self.focus.FarIntensity=.34*smooth(age/.22)*(1-fade)
  end
  local depth=4;local unitsPerPixel=2*depth*math.tan(math.rad(camera.FieldOfView*.5))/viewport.Y
  for i,tile in ipairs(self.tiles) do if not tile.sold then
   local row=math.floor((i-1)/columns);local column=(i-1)%columns
   local point=center+Vector2.new((column-(columns-1)*.5)*cell,(row-(rows-1)*.5)*cell)
   local rise=reduced and 1 or smooth((age-(i-1)*.008)/.27)
   point+=Vector2.new(0,(1-rise)*65)
   local ray=camera:ViewportPointToRay(point.X,point.Y)
   local position=ray.Origin+ray.Direction*(depth/math.max(.1,ray.Direction:Dot(camera.CFrame.LookVector)))
   local hit=tile.hitAt and math.clamp((now-tile.hitAt)/BREAK_TIME,0,1) or 0
   local scale=cell*(full and .88 or .70)*unitsPerPixel/math.max(tile.size.X,tile.size.Y,tile.size.Z)
   if tile.hitAt and not reduced then scale*=1-.40*hit end
   tile.ore.Size=tile.size*scale*(.7+.3*rise)
   tile.ore.CFrame=CFrame.new(position)*camera.CFrame.Rotation*CFrame.Angles(.16,(reduced and .3 or age*.45)+i*.6,.12)
   if tile.gem then RockFinish.Gems.update(tile.ore,rise*(1-hit),camera.CFrame.Position) end
   if tile.hitAt then tile.ore.Transparency=tile.transparency+(1-tile.transparency)*hit end
   tile.caption.Position=UDim2.fromOffset(point.X,point.Y+cell*.43)
   tile.caption.TextSize=cell<56 and 12 or full and 17 or 14;tile.caption.TextTransparency=1-rise*(1-hit)
   if tile.hitAt and hit>=1 then
    tile.ore:Destroy();tile.caption:Destroy();tile.sold=true
    self.breakIndex+=1
   elseif i==self.breakIndex and not tile.hitAt and cascadeAge and cascadeAge>=FIRST_HIT
    and (not self.lastBreakAt or now-self.lastBreakAt>=self.breakInterval) then
    -- Advance only after the prior rock is gone, even when a frame stalls.
    self:breakRock(tile,i,point,now,camera.CFrame.UpVector,math.clamp(cell*.95,72,204))
   end
  end end
  if lastHit and now-lastHit>FINISH_HOLD then self:clearGrid() end
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
  if pullAt and not money then pullAt+=token.wave*DUST_WAVE_STEP+(token.delay-.11)*.73 end
  local target=self.refs.hud:currencyTarget(token.key)
  local age=math.max(0,now-token.at)
  local position=drift(token,age,reduced)
  local progress=0
  if pullAt and now>=pullAt and target then
   target-=inset
   if not token.pullAt then
    token.pullAt=math.max(pullAt,now-.05)
    token.origin,token.initial=drift(token,math.max(0,token.pullAt-token.at),reduced)
    token.duration=math.clamp(.24+(target-token.origin).Magnitude/2750,.26,.52)*token.timing
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
  if progress>=1 or age>8 then
   self.refs.hud:currencyHit(token.receipt.id,token.key,token.amount,reduced)
   if progress>=1 and self.refs.audio then
    self.refs.audio:play(money and 'sale_credit' or 'sale_dust_credit',nil,{pitch=token.pitch})
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
  local t=math.clamp((now-readout.at)/READOUT_TIME,0,1)
  if t>=1 then
   readout.view:Destroy();table.remove(self.readouts,i)
  else
   local rise=reduced and 0 or 11*smooth(t)
   readout.view.Position=UDim2.fromOffset(readout.from.X,readout.from.Y-rise)
   local fade=smooth((t-.65)/.35)
   readout.view.TextTransparency=fade;readout.view.TextStrokeTransparency=.22+.78*fade
  end
 end
end
function Sale:destroy()
 if self.closed then return end;self.closed=true;self:clearGrid()
 self.gui:Destroy();self.queue={};self.flights={};self.readouts={}
end
return Sale
