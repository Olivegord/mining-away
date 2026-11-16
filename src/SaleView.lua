-- A committed sale is a cosmetic receipt. Animation never grants or spends money.
local Sale={};Sale.__index=Sale
local Lighting=game:GetService('Lighting')
local GuiService=game:GetService('GuiService')
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
 gui.IgnoreGuiInset=true;gui.DisplayOrder=13;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=refs.player.PlayerGui
 self.gui=gui
 self.title=label(gui,'',Color3.new(1,1,1),20);self.title.Visible=false
 return self
end
function Sale:receive(receipt)
 if self.closed or type(receipt)~='table' or type(receipt.id)~='string' or self.seen[receipt.id] or type(receipt.cargo)~='table' then return end
 self.seen[receipt.id]=true;table.insert(self.seenOrder,receipt.id)
 if #self.seenOrder>128 then self.seen[table.remove(self.seenOrder,1)]=nil end
 local entries={}
 for key,units in pairs(receipt.cargo) do
  local item=Workshop.saleItem(key)
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
 -- Courier trips stay small and never repeatedly blur the world or shake it.
 table.insert(self.queue,receipt)
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
 self.refs.hud:revealSale(receipt.resources or {},6)
 if receipt.full then
  local focus=Instance.new('DepthOfFieldEffect');focus.Name='SellingFocus';focus.FocusDistance=8;focus.InFocusRadius=4
  focus.NearIntensity=0;focus.FarIntensity=0;focus.Parent=Lighting;self.focus=focus
 end
 self.stepTime=receipt.full and math.clamp(1.1/#receipt.items,.028,.065) or .035
 for i,item in ipairs(receipt.items) do
  local ore,gem=self:makeOre(item)
  local caption=label(self.gui,item.units>1 and item.name..' ×'..item.units or item.name,Color3.fromRGB(table.unpack(item.color)),14)
  self.tiles[i]={item=item,ore=ore,gem=gem,caption=caption,size=ore.Size,at=.38+(i-1)*self.stepTime}
 end
 self.title.Text=receipt.full and ('SELLING '..tostring(#receipt.items)..' · +$'..tostring(receipt.cash)) or ''
 self.title.Visible=receipt.full
end
function Sale:fly(key,amount,from,color,now)
 if amount<=0 then return end
 local icon=label(self.gui,key=='Money' and '$' or '◆',color,key=='Money' and 21 or 17)
 icon.Size=UDim2.fromOffset(24,24)
 table.insert(self.flights,{view=icon,key=key,from=from,at=now,duration=.34,amount=amount})
end
function Sale:burst(tile,point,now)
 local item=tile.item;local color=Color3.fromRGB(table.unpack(item.color))
 self:fly('Money',item.cash*item.units,point,GOLD,now)
 self:fly(item.resource,item.dust*item.units,point+Vector2.new(12,5),color,now+.025)
 if item.stoneUnits>0 then self:fly('Stone',item.stoneUnits*item.units,point+Vector2.new(-10,4),Color3.fromRGB(171,164,151),now+.045) end
 if not self.refs.reducedMotion() then
  if self.active.full then
   self.refs.presentation:cameraBeat('Sale',tile.ore.Position,workspace:GetServerTimeNow(),item.stone and .65 or 1)
  end
  if self.refs.player:GetAttribute('ReducedEffects')~=true then
   for i=1,5 do
    local shard=Instance.new('Frame');shard.AnchorPoint=Vector2.new(.5,.5);shard.Size=UDim2.fromOffset(4+i%2*2,4+i%2*2)
    shard.BorderSizePixel=0;shard.BackgroundColor3=i%2==0 and GOLD or color;shard.Rotation=i*37;shard.Parent=self.gui
    local angle=i*2.399
    self.sparks[#self.sparks+1]={view=shard,from=point,velocity=Vector2.new(math.cos(angle),math.sin(angle))*(55+i*9),at=now}
   end
  end
 end
 tile.ore:Destroy();tile.caption:Destroy();tile.sold=true
end
function Sale:clearGrid()
 for _,tile in ipairs(self.tiles) do if not tile.sold then tile.ore:Destroy();tile.caption:Destroy() end end
 self.tiles={};self.active=nil;self.title.Visible=false
 if self.focus then self.focus:Destroy();self.focus=nil end
end
function Sale:update(dt)
 if self.closed then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local now=os.clock();local reduced=self.refs.reducedMotion()
 if not self.active and #self.queue>0 and not self.refs.hidden() then self:start(table.remove(self.queue,1),now) end
 if self.active then
  local age=now-self.started;local count=#self.tiles;local full=self.active.full
  local viewport=camera.ViewportSize
  local limit=full and (viewport.X<600 and 5 or 8) or 4
  local columns=math.min(limit,count<=5 and count or math.ceil(math.sqrt(count*2)))
  local rows=math.ceil(count/columns)
  local cell=math.min(full and 83 or 48,(viewport.X-40)/columns,(viewport.Y*.52)/rows)
  local center=full and Vector2.new(viewport.X*.53,viewport.Y*.48) or Vector2.new(viewport.X*.5,viewport.Y*.24)
  self.title.Position=UDim2.fromOffset(center.X,center.Y-rows*cell*.5-28)
  if self.focus then self.focus.FarIntensity=.22*smooth(age/.22)*(1-smooth((age-(.38+count*self.stepTime))/.3)) end
  local depth=8;local unitsPerPixel=2*depth*math.tan(math.rad(camera.FieldOfView*.5))/viewport.Y
  for i,tile in ipairs(self.tiles) do if not tile.sold then
   local row=math.floor((i-1)/columns);local column=(i-1)%columns
   local point=center+Vector2.new((column-(columns-1)*.5)*cell,(row-(rows-1)*.5)*cell)
   local rise=reduced and 1 or smooth((age-(i-1)*.008)/.27)
   point+=Vector2.new(0,(1-rise)*65)
   local ray=camera:ViewportPointToRay(point.X,point.Y)
   local position=ray.Origin+ray.Direction*(depth/math.max(.1,ray.Direction:Dot(camera.CFrame.LookVector)))
   local scale=cell*.57*unitsPerPixel/math.max(tile.size.X,tile.size.Y,tile.size.Z)
   tile.ore.Size=tile.size*scale*(.7+.3*rise)
   tile.ore.CFrame=CFrame.new(position)*camera.CFrame.Rotation*CFrame.Angles(.16,(reduced and .3 or age*.45)+i*.6,.12)
   if tile.gem then RockFinish.Gems.update(tile.ore,rise,camera.CFrame.Position) end
   tile.caption.Position=UDim2.fromOffset(point.X,point.Y+cell*.36)
   tile.caption.TextSize=cell<56 and 12 or 14;tile.caption.TextTransparency=1-rise
   if age>=tile.at then self:burst(tile,point,now) end
  end end
  if age>.38+count*self.stepTime+.48 then self:clearGrid() end
 end
 for i=#self.flights,1,-1 do
  local f=self.flights[i];local t=math.clamp((now-f.at)/f.duration,0,1)
  local target=self.refs.hud:currencyTarget(f.key)
  if target then
   target+=GuiService:GetGuiInset()
   local eased=t*t;local p=f.from:Lerp(target,eased)+Vector2.new(0,reduced and 0 or -math.sin(t*math.pi)*45)
   f.view.Position=UDim2.fromOffset(p.X,p.Y);f.view.TextTransparency=now<f.at and 1 or 0
  end
  if t>=1 or not target then self.refs.hud:currencyHit(f.key);f.view:Destroy();table.remove(self.flights,i) end
 end
 for i=#self.sparks,1,-1 do
  local s=self.sparks[i];local age=now-s.at;local t=age/.29
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
