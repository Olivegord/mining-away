-- World-space feedback for server-committed backpack sales.
local Sale={};Sale.__index=Sale

function Sale.new(refs)
 return setmetatable({refs=refs,seen={},order={},rocks={}},Sale)
end

function Sale:receiveProfile(profile)
 if self.runId~=profile.run.id then self:destroy();self.runId=profile.run.id end
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
 ore.Parent=self.refs.parent

 return ore,gem
end

function Sale.values(item,count)
 local value=item.cash or 1
 return (value-(item.cashBonus or 0))*count,value*count
end

function Sale:showReceipt(_,_,target)
 if self.anchor then self.anchor:Destroy() end
 local anchor=Instance.new('Part');anchor.Name='SaleCallout'
 anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
 anchor.Position=target;anchor.Parent=self.refs.parent
 local board=Instance.new('BillboardGui');board.Size=UDim2.fromScale(2.4,.85)
 board.AlwaysOnTop=false;board.LightInfluence=0;board.MaxDistance=90;board.Parent=anchor
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
 label.TextScaled=true;label.Font=Enum.Font.GothamBold;label.TextStrokeTransparency=.08
 label.TextStrokeColor3=Color3.fromRGB(34,26,36);label.Text='';label.Parent=board
 self.anchor=anchor;self.board=board;self.readout=label;self.hideAt=nil
end

function Sale:receive(receipt)
 if self.seen[receipt.id] or (self.runId and receipt.runId~=self.runId) then return end
 self.seen[receipt.id]=true;table.insert(self.order,receipt.id)
 if #self.order>128 then self.seen[table.remove(self.order,1)]=nil end
 self.refs.onCommitted(receipt)
 local root=self.refs.player.Character and self.refs.player.Character:FindFirstChild('HumanoidRootPart')
 if not receipt.counter or not root then return end
 local target=Vector3.new(table.unpack(receipt.counter))
 local origin=root.Position-root.CFrame.LookVector*.65+Vector3.yAxis*.55
 local reduced=self.refs.reducedMotion()
 local keys={}
 for key,n in pairs(receipt.cargo) do if n>0 then table.insert(keys,key) end end
 table.sort(keys)
 self:showReceipt(receipt,keys,target)
 local batch={}
 for _,key in ipairs(keys) do
  local item=Workshop.saleItem(key) or {key=key,name=key,color=Shops.COLORS[key]}
  table.insert(batch,item)
 end
 local now=os.clock()
 local amounts=table.clone(receipt.resources or {});amounts.Money=receipt.cash or 0
 if #batch>0 then self.refs.hud:beginSale(receipt,amounts) end
 local scoreAt=now+.48
 for i,item in ipairs(batch) do
  local base,final=Sale.values(item,receipt.cargo[item.key])
  local part,gem=self:makeOre(item)
  local extent=math.max(part.Size.X,part.Size.Y,part.Size.Z)
  part.Size*=math.min(1,1.25/extent)
  local slot=(i-1)%5
  local row=math.floor((i-1)/5)%3
  local finish=target+root.CFrame.RightVector*((slot-(math.min(#batch,5)-1)*.5)*1.08)
   +root.CFrame.LookVector*((row-1)*.85)+Vector3.yAxis*part.Size.Y*.38
  local launch=math.max(now+(i-1)*.085,scoreAt-1.45)
  table.insert(self.rocks,{part=part,gem=gem,size=part.Size,start=launch,scoreAt=scoreAt,
   base=base,final=final,modified=base~=final or (item.dustBonus or 0)>0,
   tint=Color3.fromRGB(table.unpack(item.color)),origin=origin,target=finish,index=i,
   stone=item.stone,reduced=reduced,readout=self.readout,
   payout=i==#batch and amounts or nil,id=receipt.id})
  part.Parent=nil
  scoreAt+=((base~=final or (item.dustBonus or 0)>0) and 1.08 or .62)
 end
end

function Sale:update()
 local now=os.clock()
 for i=#self.rocks,1,-1 do
  local r=self.rocks[i]
  local age=now-r.start
  if age<0 then continue end
  local flight=math.clamp(age/.44,0,1)
  local score=now-r.scoreAt
  local hit=r.modified and .54 or .23
  local depart=math.clamp((score-hit-.16)/.18,0,1)
  local arc=4*flight*(1-flight)
  local pos=r.origin:Lerp(r.target,flight)+Vector3.yAxis*(arc*(r.reduced and .4 or 2.3))
  local rebound=math.clamp((age-.44)/.18,0,1)
  local bounce=math.sin(rebound*math.pi)*(1-rebound)
  local charge=r.modified and math.clamp((score-.22)/.32,0,1) or 0
  local windup=charge<1 and charge*charge or 0
  local flash=math.max(0,1-math.abs(score-hit)/.14)
  local size=1-depart*.94
  if not r.reduced then
   pos+=Vector3.yAxis*(bounce*.52-depart*.48)
   size*=1+windup*.14+flash*.13
  end
  r.part.CFrame=CFrame.new(pos)*CFrame.Angles(r.reduced and 0 or flight*2.7,r.index*1.7+flight*.8,windup*.14)
  r.part.Size=r.size*size
  r.part.Parent=self.refs.parent
  if r.gem then RockFinish.Gems.update(r.part,1) end
  if flight==1 and not r.landed then
   r.landed=true;self.refs.audio:play(r.stone and 'sale_stone' or 'sale_gem',r.target,{level=.7})
  end
  if score>=0 and score<(r.modified and 1.08 or .62) and r.readout and r.readout==self.readout then
   self.owner=r;self.board.Enabled=true
   self.anchor.Position=r.target+Vector3.yAxis*(r.size.Y*.48+1.05+(r.reduced and 0 or flash*.16))
   self.readout.Text=tostring(score<hit and r.base or r.final)
   self.readout.TextColor3=Color3.fromRGB(255,247,215):Lerp(r.tint:Lerp(Color3.new(1,1,1),.35),math.max(windup,flash))
   local scale=r.reduced and 1 or 1-.12*windup+.32*flash
   self.board.Size=UDim2.fromScale(2.1*scale,.88*scale)
  end
  if score>=hit and not r.scored then
   r.scored=true;self.refs.audio:play(r.modified and 'sale_credit' or 'sale_stone',r.target,{pitch=r.modified and 1.18 or .94})
  end
  if score>=(r.modified and 1.08 or .62) then
   if self.owner==r then self.owner=nil;self.board.Enabled=false end
   r.part:Destroy();table.remove(self.rocks,i)
   if r.payout then
    for key,amount in pairs(r.payout) do
     if amount>0 then self.refs.hud:currencyHit(r.id,key,amount,r.reduced,true) end
    end
    self.refs.audio:play('sale_finish',r.target)
   end
  end
 end
end

function Sale:destroy()
 if self.board then self.board:Destroy();self.anchor:Destroy();self.board=nil;self.hideAt=nil;self.readout=nil end
 for _,rock in ipairs(self.rocks) do rock.part:Destroy() end
 table.clear(self.rocks)
end
return Sale
