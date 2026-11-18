-- Manual sales get one counter impact and a short, non-interactive receipt.
local Ledger=require('./SaleLedger')
local Sale={};Sale.__index=Sale
local CASH=Color3.fromRGB(160,244,182)
local PAPER=Color3.fromRGB(251,248,234)

local function label(parent,contents,size,color)
 local text=Instance.new('TextLabel')
 text.BackgroundTransparency=1;text.Text=contents;text.TextScaled=true
 text.TextColor3=color;text.Font=Enum.Font.GothamBold;text.TextWrapped=true
 text.TextStrokeColor3=Color3.fromRGB(18,24,19);text.TextStrokeTransparency=.34
 text.Parent=parent
 local limits=Instance.new('UITextSizeConstraint');limits.MinTextSize=10;limits.MaxTextSize=size;limits.Parent=text
 return text
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



function Sale:show(batch)
 local sale,read=batch.receipt,batch.read
 local card=Instance.new('Frame');card.Name='OreSaleReceipt'
 card.AnchorPoint=Vector2.new(.5,1);card.Position=UDim2.new(.5,0,.89,0)
 card.Size=UDim2.new(1,-28,0,100);card.BackgroundTransparency=1;card.Parent=self.refs.gui
 local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(520,100);limit.Parent=card
 local payout=(sale.cash or 0)>0 and '+'..Ledger.money(sale.cash) or 'Sold '..read.units..' ore'
 local money=label(card,payout,36,CASH);money.Size=UDim2.new(1,0,0,42)
 local materials=label(card,read.materials,17,PAPER);materials.Position=UDim2.fromOffset(0,42)
 materials.Size=UDim2.new(1,0,0,28)
 local detail=sale.milestone
 if not detail and read.bonuses~='' then detail='Modifier bonus  +'..read.bonuses end
 if not detail then
  local best=read.items[1]
  if best and #read.items<=2 then
   detail=best.name..'  '..Ledger.money(best.cash)..' each'
  else
   detail=read.units..(read.units==1 and ' piece sold' or ' pieces sold')
  end
 end
 local note=label(card,detail,14,PAPER);note.Position=UDim2.fromOffset(0,71);note.Size=UDim2.new(1,0,0,24)
 batch.gui=card;batch.labels={money,materials,note}
end

function Sale:stage(batch,root)
 local target=Vector3.new(table.unpack(batch.receipt.counter))
 local toward=root.Position-target;toward=Vector3.new(toward.X,0,toward.Z)
 local forward=toward.Magnitude>.001 and toward.Unit or Vector3.zAxis
 local right=forward:Cross(Vector3.yAxis)
 local count=math.min(4,#batch.read.items)
 batch.target=target;batch.rocks={}
 for i=1,count do
  local item=batch.read.items[i]
  local ore,gem=self:makeOre(item)
  local extent=math.max(ore.Size.X,ore.Size.Y,ore.Size.Z)
  ore.Size*=math.min(1.1,1.18/extent)
  local lane=(i-(count+1)*.5)
  local offset=right*(lane*.92)+forward*(i%2==0 and .14 or -.15)
  local pose=CFrame.Angles(.17*((i%3)-1),i*1.7,-lane*.16)
  local position=target+offset+Vector3.yAxis*ore.Size.Y*.55
  ore.CFrame=CFrame.new(position+Vector3.yAxis*.72)*pose
  ore.Parent=self.refs.parent
  if gem then RockFinish.Gems.update(ore,1) end
  batch.rocks[i]={ore=ore,gem=gem,size=ore.Size,position=position,pose=pose,offset=offset}
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
 if not receipt.full then return end
 self:clear()
 local amounts=table.clone(receipt.resources or {});amounts.Money=receipt.cash or 0
 local batch={receipt=receipt,read=Ledger.read(receipt),amounts=amounts,start=os.clock(),
  reduced=self.refs.reducedMotion()}
 self.batch=batch
 self.refs.hud:beginSale(receipt,amounts)
 local root=self.refs.player.Character and self.refs.player.Character:FindFirstChild('HumanoidRootPart')
 if root and receipt.counter and not batch.reduced and not self.refs.hidden() then self:stage(batch,root) end
 if not batch.rocks or #batch.rocks==0 then batch.reduced=true end
end

function Sale:update(now)
 local batch=self.batch
 if not batch then return end
 local age=(now or os.clock())-batch.start
 if age>=3.8 then self:clear();return end
 local impact=batch.reduced and 0 or .32
 if age>=impact and not batch.credited then
  self:credit(batch)
  if not self.refs.hidden() then self:show(batch) end
  if batch.receipt.counter then
   local point=batch.target or Vector3.new(table.unpack(batch.receipt.counter))
   self.refs.audio:play('sale_finish',point,{level=.9})
   local best=batch.read.items[1]
   if batch.target and best then
    local tint=Color3.fromRGB(table.unpack(best.color))
    self.refs.audio:play(best.stone and 'sale_stone' or 'sale_gem',point,{level=.48})
    RoleVisuals.ImpactParticles(point,tint,.40,'CrystalBreak')
   end
  end
 end
 for _,rock in ipairs(batch.rocks or {}) do
  local fall=math.clamp(age/.32,0,1)
  local collect=math.clamp((age-.32)/.18,0,1)
  local offset=Vector3.yAxis*(.72*(1-fall*fall)-collect*.38)-rock.offset*collect^2
  rock.ore.CFrame=CFrame.new(rock.position+offset)*rock.pose
  rock.ore.Size=rock.size*math.max(.01,1-collect^2)
  rock.ore.Transparency=math.max(rock.ore.Transparency,collect)
  if rock.gem then RockFinish.Gems.update(rock.ore,1-collect) end
 end
 if age>=.50 and batch.rocks then
  for _,rock in ipairs(batch.rocks) do rock.ore:Destroy() end
  batch.rocks=nil
 end
 if batch.gui then
  batch.gui.Visible=not self.refs.hidden()
  local fade=math.clamp((age-3.2)/.6,0,1)
  for _,text in ipairs(batch.labels) do
   text.TextTransparency=fade;text.TextStrokeTransparency=.34+.66*fade
  end
 end
end

function Sale:destroy() self:clear() end
return Sale
