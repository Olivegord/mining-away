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
 local batch={}
 local limit=reduced and 4 or 16
 -- Round-robin keeps small, distinct stacks visible in a mixed backpack.
 for pass=1,limit do
  for _,key in ipairs(keys) do
   if receipt.cargo[key]>=pass and #batch<limit then
    local item=Workshop.saleItem(key)
    if not item and Shops.COLORS[key] then item={key=key,name=key,color=Shops.COLORS[key]} end
    if item then table.insert(batch,item) end
   end
  end
  if #batch>=limit then break end
 end
 local now=os.clock()
 local amounts=table.clone(receipt.resources or {});amounts.Money=receipt.cash or 0
 if #batch>0 then self.refs.hud:beginSale(receipt,amounts) end
 for i,item in ipairs(batch) do
  local part,gem=self:makeOre(item)
  local side=root.CFrame.RightVector*math.sin(i*2.4)*(reduced and .25 or 1.8)
  local bend=(origin+target)*.5+side+Vector3.yAxis*(reduced and .7 or 3+i%3*.5)
  part.CFrame=CFrame.new(origin);part.Parent=nil
  table.insert(self.rocks,{part=part,gem=gem,size=part.Size,start=now+(i-1)*.045,
   origin=origin,bend=bend,target=target,index=i,stone=item.stone,reduced=reduced,
   payout=i==#batch and amounts or nil,id=receipt.id})
 end
end

function Sale:update()
 local now=os.clock()
 for i=#self.rocks,1,-1 do
  local rock=self.rocks[i]
  local t=(now-rock.start)/(rock.reduced and .32 or .56)
  if t>=1 then
   rock.part:Destroy();table.remove(self.rocks,i)
   if rock.payout then
    for key,amount in pairs(rock.payout) do
     if amount>0 then self.refs.hud:currencyHit(rock.id,key,amount,rock.reduced,true) end
    end
   end
   self.refs.audio:play(rock.payout and 'sale_finish' or rock.stone and 'sale_stone' or 'sale_gem',rock.target,{pitch=.94+rock.index*.018})
  elseif t>=0 then
   local pos=rock.origin:Lerp(rock.bend,t):Lerp(rock.bend:Lerp(rock.target,t),t)
   local spin=rock.reduced and 0 or t*3
   rock.part.CFrame=CFrame.new(pos)*CFrame.Angles(spin,rock.index+spin,0)
   rock.part.Size=rock.size*(1-.83*math.clamp((t-.72)/.28,0,1))
   if rock.gem then RockFinish.Gems.update(rock.part,1) end
   rock.part.Parent=self.refs.parent
  end
 end
end

function Sale:destroy()
 for _,rock in ipairs(self.rocks) do rock.part:Destroy() end
 table.clear(self.rocks)
end
return Sale
