-- A committed sale is a cosmetic receipt. Animation never grants or spends money.
local Sale={};Sale.__index=Sale
local Lighting=game:GetService('Lighting')
local GuiService=game:GetService('GuiService')
local Input=game:GetService('UserInputService')
local Actions=game:GetService('ContextActionService')
local CONFIRM_ACTION='MiningAwayConfirmSale'
local FIRST_HIT=.38
local HIT_HOLD=.085
local ICON_HOLD=.38
local GOLD=Color3.fromRGB(255,218,104)
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function label(parent,text,color,size)
 local v=Instance.new('TextLabel');v.BackgroundTransparency=1;v.Text=text;v.TextColor3=color
 v.TextSize=size;v.Font=Enum.Font.SourceSansBold;v.TextStrokeTransparency=.45
 v.AnchorPoint=Vector2.new(.5,.5);v.Size=UDim2.fromOffset(100,24);v.Parent=parent
 return v
end
function Sale.new(refs)
 local self=setmetatable({refs=refs,queue={},seen={},seenOrder={},flights={},sparks={},tiles={},closed=false},Sale)
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
function Sale:receive(receipt)
 if self.closed or type(receipt)~='table' then return end
 if receipt.kind=='rejected' then
  if self.active and self.active.id==receipt.id then self:clearGrid() end
  return
 end
 if self.active and self.active.kind=='preview' and receipt.kind~='preview' and receipt.id==self.active.id then
  self.active.kind=nil;self.active.resources=receipt.resources
  self.pendingAt=nil;self.cascadeAt=os.clock();self.prompt.Visible=false;self.back.Visible=false
  self.refs.hud:revealSale(receipt.resources or {},8)
  return
 end
 if type(receipt.id)~='string' or self.seen[receipt.id] or type(receipt.cargo)~='table' then return end
 self.seen[receipt.id]=true;table.insert(self.seenOrder,receipt.id)
 if #self.seenOrder>128 then self.seen[table.remove(self.seenOrder,1)]=nil end
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
 if receipt.kind~='preview' then self.refs.hud:revealSale(receipt.resources or {},8) end
 if receipt.full then
  local focus=Instance.new('DepthOfFieldEffect');focus.Name='SellingFocus';focus.FocusDistance=4;focus.InFocusRadius=2.5
  focus.NearIntensity=0;focus.FarIntensity=0;focus.Parent=Lighting;self.focus=focus
  self.blocker.Visible=true;self:bindInput()
 end
 self.stepTime=receipt.full and math.clamp(1.65/#receipt.items,.055,.15) or .045
 local count=0
 for i,item in ipairs(receipt.items) do
  local ore,gem=self:makeOre(item)
  local caption=label(self.gui,item.units>1 and item.name..' ×'..item.units or item.name,Color3.fromRGB(table.unpack(item.color)),14)
  count+=item.units
  self.tiles[i]={item=item,ore=ore,gem=gem,caption=caption,size=ore.Size,at=FIRST_HIT+(i-1)*self.stepTime}
 end
 self.title.Text='Backpack  ·  '..count..' ore'
 self.title.Visible=receipt.full
end
function Sale:fly(key,amount,from,color,now)
 if amount<=0 then return end
 local number=key=='Money' and tostring(amount) or string.format('%.2f',amount/100):gsub('0+$',''):gsub('%.$','')
 local icon=label(self.gui,(key=='Money' and '+$' or '◆ +')..number,color,key=='Money' and 23 or 18)
 icon.Size=UDim2.fromOffset(110,28);icon.ZIndex=3
 icon.Position=UDim2.fromOffset(from.X,from.Y)
 table.insert(self.flights,{view=icon,key=key,from=from,at=now,hold=self.active.full and ICON_HOLD or .10,duration=.42})
end
function Sale:burst(tile,point,now)
 local item=tile.item;local color=Color3.fromRGB(table.unpack(item.color))
 self:fly('Money',item.cash*item.units,point,GOLD,now)
 if item.resource then self:fly(item.resource,item.dust*item.units,point+Vector2.new(15,21),color,now+.025) end
 if item.stoneUnits>0 then self:fly('Stone',item.stoneUnits*item.units,point+Vector2.new(-12,43),Color3.fromRGB(226,214,192),now+.045) end
 if self.refs.audio then self.refs.audio:play(item.stone and 'sale_stone' or 'sale_gem',nil,{pitch=.89+(tile.index%8)*.045}) end
 if not self.refs.reducedMotion() then
  if self.active.full then
   local character=self.refs.player.Character
   local root=character and character:FindFirstChild('HumanoidRootPart')
   self.refs.presentation:cameraBeat('Sale',root and root.Position or tile.ore.Position,workspace:GetServerTimeNow(),item.stone and .8 or 1.2)
  end
  if self.refs.player:GetAttribute('ReducedEffects')~=true then
   for i=1,item.stone and 10 or 17 do
    local shard=Instance.new('Frame');shard.AnchorPoint=Vector2.new(.5,.5);shard.Size=UDim2.fromOffset(4+i%2*2,4+i%2*2)
    shard.BorderSizePixel=0;shard.BackgroundColor3=i%2==0 and GOLD or color;shard.Rotation=i*37;shard.Parent=self.gui
    local angle=i*2.399
    self.sparks[#self.sparks+1]={view=shard,from=point,velocity=Vector2.new(math.cos(angle),math.sin(angle))*(68+(i%6)*24),at=now}
   end
  end
 end
 tile.hitAt=now
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
function Sale:update(dt)
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
  local lastHit=FIRST_HIT+(count-1)*self.stepTime
  if self.focus then self.focus.FarIntensity=.34*smooth(age/.22)*(1-smooth(((cascadeAge or 0)-(lastHit+.50))/.24)) end
  local depth=4;local unitsPerPixel=2*depth*math.tan(math.rad(camera.FieldOfView*.5))/viewport.Y
  for i,tile in ipairs(self.tiles) do if not tile.sold then
   local row=math.floor((i-1)/columns);local column=(i-1)%columns
   local point=center+Vector2.new((column-(columns-1)*.5)*cell,(row-(rows-1)*.5)*cell)
   local rise=reduced and 1 or smooth((age-(i-1)*.008)/.27)
   point+=Vector2.new(0,(1-rise)*65)
   local ray=camera:ViewportPointToRay(point.X,point.Y)
   local position=ray.Origin+ray.Direction*(depth/math.max(.1,ray.Direction:Dot(camera.CFrame.LookVector)))
   local hit=tile.hitAt and math.clamp((now-tile.hitAt)/HIT_HOLD,0,1) or 0
   local scale=cell*(full and .88 or .70)*unitsPerPixel/math.max(tile.size.X,tile.size.Y,tile.size.Z)
   if tile.hitAt and not reduced then scale*=1+.11*(1-hit) end
   tile.ore.Size=tile.size*scale*(.7+.3*rise)
   tile.ore.CFrame=CFrame.new(position)*camera.CFrame.Rotation*CFrame.Angles(.16,(reduced and .3 or age*.45)+i*.6,.12)
   if tile.gem then RockFinish.Gems.update(tile.ore,rise,camera.CFrame.Position) end
   tile.caption.Position=UDim2.fromOffset(point.X,point.Y+cell*.43)
   tile.caption.TextSize=cell<56 and 12 or full and 17 or 14;tile.caption.TextTransparency=1-rise
   if tile.hitAt and hit>=1 then
    tile.ore:Destroy();tile.caption:Destroy();tile.sold=true
   elseif not tile.hitAt and cascadeAge and cascadeAge>=tile.at then
    tile.index=i;self:burst(tile,point,now)
   end
  end end
  if cascadeAge and cascadeAge>lastHit+.98 then self:clearGrid() end
 end
 for i=#self.flights,1,-1 do
  local f=self.flights[i];local t=math.clamp((now-f.at-f.hold)/f.duration,0,1)
  local target=self.refs.hud:currencyTarget(f.key)
  if target then
   target-=GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets).Min
   local drift=reduced and 0 or 14*smooth((now-f.at)/f.hold)
   local p=(f.from-Vector2.new(0,drift)):Lerp(target,smooth(t))+Vector2.new(0,reduced and 0 or -math.sin(t*math.pi)*46)
   f.view.Position=UDim2.fromOffset(p.X,p.Y);f.view.TextTransparency=now<f.at and 1 or t*.30
  end
  if t>=1 or not target then
   if f.key=='Money' and self.refs.audio then self.refs.audio:play('sale_credit') end
   self.refs.hud:currencyHit(f.key);f.view:Destroy();table.remove(self.flights,i)
  end
 end
 for i=#self.sparks,1,-1 do
  local s=self.sparks[i];local age=now-s.at;local t=age/.53
  if t>=1 then s.view:Destroy();table.remove(self.sparks,i)
  else
   local p=s.from+s.velocity*age+Vector2.new(0,80*age*age)
   s.view.Position=UDim2.fromOffset(p.X,p.Y);s.view.BackgroundTransparency=t;s.view.Rotation+=dt*110
  end
 end
end
function Sale:destroy()
 if self.closed then return end;self.closed=true;self:clearGrid()
 self.gui:Destroy();self.queue={};self.flights={};self.sparks={}
end
return Sale
