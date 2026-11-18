-- Backpack trade-in. Preview is a quote and only committed receipts credit the HUD.
local Ledger=require('./SaleLedger')
local Sale={};Sale.__index=Sale
local INK=Color3.fromRGB(21,29,28)
local PANEL=Color3.fromRGB(36,48,44)
local TEXT=Color3.fromRGB(246,247,237)
local MUTED=Color3.fromRGB(186,204,197)
local CASH=Color3.fromRGB(160,244,182)

local function rounded(parent,radius)
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,radius);corner.Parent=parent
end

local function text(parent,contents,size,color,strong)
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1;label.Text=contents
 label.Font=strong and Enum.Font.GothamBold or Enum.Font.Gotham
 label.TextSize=size;label.TextColor3=color;label.TextXAlignment=Enum.TextXAlignment.Left
 label.Parent=parent
 return label
end

local function button(parent,contents,action)
 local control=Instance.new('TextButton');control.Text=contents;control.Font=Enum.Font.GothamBold
 control.TextSize=16;control.BackgroundColor3=PANEL;control.TextColor3=TEXT
 control.AutoButtonColor=true;control.Parent=parent;rounded(control,8)
 control.Activated:Connect(action)
 return control
end

function Sale.new(refs)
 return setmetatable({refs=refs,seen={},order={}},Sale)
end

function Sale:receiveProfile(profile)
 if self.runId~=profile.run.id then
  if self.runId then self:close() end
  self.runId=profile.run.id
 end
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


function Sale:isOpen()
 return self.panel~=nil
end

function Sale:close()
 if self.panel then self.panel:Destroy() end
 self.panel=nil;self.quote=nil;self.request=nil;self.pending=nil
 self.phase=nil;self.highlight=nil;self.previewOre=nil
end

function Sale:open()
 if self.pending or self.request then return end
 self:close()
 self.request=self.refs.requestId();self.deadline=os.clock()+6
 self.refs.send('QuoteSale',self.request)
end

function Sale:confirm()
 if self.phase=='sold' then self:close();return end
 if self.phase=='retry' then self:open();return end
 if self.phase~='quote' or self.pending then return end
 self.pending=self.quote.id;self.deadline=os.clock()+20
 self.confirmButton.Text='Selling…';self.confirmButton.AutoButtonColor=false
 self.refs.send('Sell',self.pending)
end

function Sale:details(item,row)
 if self.previewOre then self.previewOre:Destroy() end
 if self.highlight then self.highlight.BackgroundColor3=INK end
 self.highlight=row;row.BackgroundColor3=PANEL
 self.itemName.Text=item.name
 self.itemDetail.Text=Ledger.detail(item)
 if item.legacy then self.previewOre=nil;return end
 local ore,gem=self:makeOre(item)
 local extent=math.max(ore.Size.X,ore.Size.Y,ore.Size.Z)
 ore.Size*=2.8/extent
 ore.CFrame=CFrame.Angles(.25,.62,-.16)
 if gem then RockFinish.Gems.update(ore,1) end
 ore.Parent=self.viewport
 self.previewOre=ore
end

function Sale:show(quote,message)
 if self.panel then self.panel:Destroy() end
 self.highlight=nil;self.previewOre=nil
 self.quote=quote;self.phase=quote and 'quote' or 'retry'
 local layer=Instance.new('Frame');layer.Name='SellOre';layer.Size=UDim2.fromScale(1,1)
 layer.BackgroundColor3=Color3.fromRGB(7,13,12);layer.BackgroundTransparency=.44
 layer.Active=true;layer.ZIndex=35;layer.Parent=self.refs.gui
 self.panel=layer
 local tray=Instance.new('Frame');tray.Name='TradeIn';tray.AnchorPoint=Vector2.new(.5,.5)
 tray.Position=UDim2.fromScale(.5,.5);tray.Size=UDim2.new(1,-24,1,-32)
 tray.BackgroundColor3=INK;tray.BorderSizePixel=0;tray.Parent=layer;rounded(tray,16)
 local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(600,488);limit.Parent=tray
 self.heading=text(tray,quote and ('Sell ore   ·   '..quote.units..' pieces') or 'Sell ore',22,TEXT,true)
 self.heading.Position=UDim2.fromOffset(16,8);self.heading.Size=UDim2.new(1,-70,0,38)
 local close=button(tray,'×',function() self:close() end)
 close.Position=UDim2.new(1,-50,0,10);close.Size=UDim2.fromOffset(36,34)
 self.status=text(tray,message or 'Backpack payout',14,MUTED,false)
 self.status.Position=UDim2.new(0,16,1,-125);self.status.Size=UDim2.new(1,-32,0,30);self.status.TextWrapped=true
 self.confirmButton=button(tray,quote and 'Sell backpack  [E]' or 'Get price  [E]',function() self:confirm() end)
 self.confirmButton.Position=UDim2.new(0,16,1,-52);self.confirmButton.Size=UDim2.new(1,-32,0,40)
 self.confirmButton.BackgroundColor3=CASH;self.confirmButton.TextColor3=INK
 if not quote then return end
 local items,wallet=Ledger.items(quote.cargo)
 local list=Instance.new('ScrollingFrame');list.Name='OreStacks';list.BackgroundTransparency=1;list.BorderSizePixel=0
 list.Position=UDim2.fromOffset(12,54);list.Size=UDim2.new(.57,-16,1,-182)
 list.ScrollBarThickness=4;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.fromOffset(0,0)
 list.ScrollingDirection=Enum.ScrollingDirection.Y;list.Parent=tray
 local stack=Instance.new('UIListLayout');stack.SortOrder=Enum.SortOrder.LayoutOrder;stack.Padding=UDim.new(0,3);stack.Parent=list
 local viewport=Instance.new('ViewportFrame');viewport.Name='OrePreview';viewport.BackgroundColor3=PANEL
 viewport.Position=UDim2.new(.57,4,0,54);viewport.Size=UDim2.new(.43,-16,1,-252)
 viewport.Ambient=Color3.fromRGB(182,188,181);viewport.LightColor=TEXT
 viewport.LightDirection=Vector3.new(-1,-1,-1);viewport.Parent=tray;rounded(viewport,10)
 local camera=Instance.new('Camera');camera.CFrame=CFrame.lookAt(Vector3.new(0,.65,6.6),Vector3.zero)
 camera.FieldOfView=44;camera.Parent=viewport;viewport.CurrentCamera=camera;self.viewport=viewport
 local function fitPreview()
  local size=viewport.AbsoluteSize
  local zoom=math.max(1,size.Y/math.max(1,size.X))
  camera.CFrame=CFrame.lookAt(Vector3.new(0,.65,6.6)*zoom,Vector3.zero)
 end
 viewport:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitPreview);fitPreview()
 self.itemName=text(tray,'',15,TEXT,true);self.itemName.TextTruncate=Enum.TextTruncate.AtEnd
 self.itemName.Position=UDim2.new(.57,7,1,-196);self.itemName.Size=UDim2.new(.43,-20,0,22)
 self.itemDetail=text(tray,'',12,MUTED,false);self.itemDetail.TextWrapped=true
 self.itemDetail.TextYAlignment=Enum.TextYAlignment.Top;self.itemDetail.TextScaled=true
 local detailBounds=Instance.new('UITextSizeConstraint');detailBounds.MinTextSize=9;detailBounds.MaxTextSize=13;detailBounds.Parent=self.itemDetail
 self.itemDetail.Position=UDim2.new(.57,7,1,-172);self.itemDetail.Size=UDim2.new(.43,-20,0,46)
 local function fitTray()
  local compact=tray.AbsoluteSize.Y<350
  local bottom=compact and 171 or 204
  viewport.Size=UDim2.new(.43,-16,0,math.max(0,tray.AbsoluteSize.Y-bottom-57))
  self.itemName.Position=UDim2.new(.57,7,1,-bottom)
  self.itemDetail.Position=UDim2.new(.57,7,1,22-bottom)
  self.itemDetail.Size=UDim2.new(.43,-20,0,bottom-141)
 end
 tray:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitTray);fitTray()
 for i,item in ipairs(items) do
  local row
  row=button(list,'',function() self:details(item,row) end)
  row.LayoutOrder=i;row.Size=UDim2.new(1,-6,0,51);row.BackgroundColor3=INK
  local name=text(row,item.name..' ×'..item.count,14,Color3.fromRGB(table.unpack(item.color)):Lerp(TEXT,.32),true)
  name.Position=UDim2.fromOffset(8,3);name.Size=UDim2.new(1,item.legacy and -16 or -78,0,23)
  name.TextTruncate=Enum.TextTruncate.AtEnd
  if not item.legacy then
   local value=text(row,Ledger.money(item.total),15,CASH,true)
   value.TextXAlignment=Enum.TextXAlignment.Right;value.Position=UDim2.new(1,-76,0,3);value.Size=UDim2.fromOffset(68,23)
   value.TextScaled=true
   local bounds=Instance.new('UITextSizeConstraint');bounds.MinTextSize=9;bounds.MaxTextSize=15;bounds.Parent=value
  end
  local payout=text(row,item.payout,12,MUTED,false)
  payout.Position=UDim2.fromOffset(8,25);payout.Size=UDim2.new(1,-16,0,21);payout.TextTruncate=Enum.TextTruncate.AtEnd
  if i==1 then self:details(item,row) end
 end
 self.total=text(tray,Ledger.payout(quote.cash,quote.resources,wallet),16,CASH,true)
 self.total.Position=UDim2.new(0,16,1,-96);self.total.Size=UDim2.new(1,-32,0,40)
 self.total.TextWrapped=true;self.total.TextScaled=true
 local bounds=Instance.new('UITextSizeConstraint');bounds.MinTextSize=10;bounds.MaxTextSize=18;bounds.Parent=self.total
end

function Sale:receive(message)
 if self.runId and message.runId and self.runId~=message.runId then return end
 if message.kind=='quote' then
  if message.request~=self.request then return end
  self.request=nil;self:show(message);return
 end
 if message.kind then
  if message.request~=self.request and message.request~=self.pending then return end
  if message.kind=='uncertain' then
   if self.status then self.status.Text=message.message end
   return
  end
  local wasPending=self.pending~=nil
  self.request=nil;self.pending=nil
  if wasPending then self:show(nil,message.message) else self.refs.notify(message.message) end
  return
 end
 if self.seen[message.id] then return end
 self.seen[message.id]=true;table.insert(self.order,message.id)
 if #self.order>128 then self.seen[table.remove(self.order,1)]=nil end
 self.refs.onCommitted(message)
 if not message.full then return end
 local reduced=self.refs.reducedMotion()
 local amounts=table.clone(message.resources or {});amounts.Money=message.cash or 0
 self.refs.hud:beginSale(message,amounts)
 for key,amount in pairs(amounts) do
  if amount>0 then self.refs.hud:currencyHit(message.id,key,amount,reduced,true) end
 end
 if self.pending~=message.id then return end
 self.pending=nil;self.phase='sold'
 self.heading.Text='Sold   ·   '..self.quote.units..' pieces'
 self.status.Text=message.milestone or 'Added to your wallet'
 if not reduced then
  self.total.TextColor3=TEXT
  game:GetService('TweenService'):Create(self.total,TweenInfo.new(.42,Enum.EasingStyle.Quad),{TextColor3=CASH}):Play()
 end
 self.confirmButton.Text='Done  [E]';self.confirmButton.AutoButtonColor=true
 if message.counter then self.refs.audio:play('sale_finish',Vector3.new(table.unpack(message.counter))) end
end

function Sale:update()
 if self.quote then
  local root=self.refs.player.Character and self.refs.player.Character:FindFirstChild('HumanoidRootPart')
  if not root or (root.Position-Vector3.new(table.unpack(self.quote.station))).Magnitude>=self.quote.radius then self:close();return end
  if self.phase=='quote' and not self.pending and workspace:GetServerTimeNow()>=self.quote.expires then
   self:show(nil,'Price expired. Get a new price.')
  end
 end
 if (self.request or self.pending) and os.clock()>=self.deadline then
  self.request=nil;self.pending=nil;self:show(nil,'Still waiting for the counter. Get a new price.')
 end
end

function Sale:destroy() self:close() end
return Sale
