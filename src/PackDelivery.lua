-- One replicated delivery per paid, sealed offer. Only the owner can open it.
local Delivery = {}
Delivery.__index = Delivery

local function flat(vector)
 return Vector3.new(vector.X, 0, vector.Z)
end

function Delivery.new(options)
 local folder = Instance.new('Folder')
 folder.Name = 'PackDeliveries'
 folder.Parent = options.root
 return setmetatable({options=options, folder=folder}, Delivery)
end

function Delivery:spawn(p, offer, buyerPosition, now)
 if not offer or offer.opened~=false or p.leaving or p.packDelivery then return end
 local o=self.options
 local station=o.station.Position
 for _,candidate in ipairs(o.stations or {}) do if (candidate.Position-buyerPosition).Magnitude<(station-buyerPosition).Magnitude then station=candidate.Position end end
 local direction=flat(buyerPosition-station)
 if direction.Magnitude<9 then direction=flat(o.home-station) end
 if direction.Magnitude<.1 then direction=Vector3.new(0,0,1) end
 local forward=direction.Unit
 local sideways=Vector3.new(-forward.Z,0,forward.X)
 local center=station+forward*math.clamp(flat(buyerPosition-station).Magnitude*.55,7,11)
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Exclude
 local ignored={self.folder}
 for _,player in ipairs(o.players:GetPlayers()) do if player.Character then table.insert(ignored,player.Character) end end
 ray.FilterDescendantsInstances=ignored
 ray.RespectCanCollide=true
 local position
 for _,lane in ipairs({0,1,-1,2,-2,3,-3}) do
  local candidate=center+sideways*lane*2.8
  local occupied=false
  for _,other in ipairs(self.folder:GetChildren()) do
   if flat(other.Position-candidate).Magnitude<2.6 then occupied=true;break end
  end
  if not occupied then position=candidate;break end
 end
 if not position then return end
 local hit=workspace:Raycast(position+Vector3.new(0,3,0),Vector3.new(0,-18,0),ray)
 local ground=hit and hit.Position.Y or o.groundHeight(position.X,position.Z)
 position=Vector3.new(position.X,ground+.56,position.Z)
 local part=World.part(nil,'CompanyPack',position,Vector3.new(1.9,1.4,1.6),Color3.new())
 part.Transparency=1
 part:SetAttribute('OfferId',offer.id)
 part:SetAttribute('Owner',p.player.UserId)
 part:SetAttribute('Tier',offer.packTier)
 part:SetAttribute('Approach',sideways)
 part:SetAttribute('DeliveryAt',now)
 local prompt=Instance.new('ProximityPrompt')
 prompt.Name='OpenPack';prompt.ActionText='Open pack';prompt.ObjectText='Company delivery'
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
 prompt.MaxActivationDistance=Packs.Range;prompt.RequiresLineOfSight=false
 prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
 prompt.Style=Enum.ProximityPromptStyle.Custom
 prompt.HoldDuration=Packs.duration(offer.packTier);prompt.Enabled=false;prompt.Parent=part
 local delivery={part=part,prompt=prompt,id=offer.id,tier=offer.packTier,readyAt=now+Packs.DeliveryTime}
 p.packDelivery=delivery
 prompt.PromptButtonHoldBegan:Connect(function(player)
  local clock=o.getClock()
  if player~=p.player or delivery.opening or delivery.start or not self:canHold(p,delivery,clock) then return end
  delivery.start=clock;delivery.endAt=nil
  part:SetAttribute('HoldAt',clock)
 end)
 prompt.Triggered:Connect(function(player)
  local clock=o.getClock()
  if player~=p.player or delivery.opening or not delivery.start or not self:canHold(p,delivery,clock) then return end
  if clock-delivery.start+0.06<Packs.duration(delivery.tier) then self:release(delivery);return end
  delivery.start=nil;delivery.endAt=nil
  delivery.opening=true;prompt.Enabled=false
  o.open(p,delivery.id,function(status)
   if status=='rejected' and p.packDelivery==delivery then delivery.opening=false;self:release(delivery) end
  end)
 end)
 prompt.PromptButtonHoldEnded:Connect(function(player)
  if player==p.player and delivery.start and not delivery.opening then delivery.endAt=o.getClock()+.08 end
 end)
 part.Parent=self.folder
end

function Delivery:clear(p)
 local delivery=p.packDelivery
 if delivery then delivery.part:Destroy();p.packDelivery=nil end
end

function Delivery:release(delivery)
 delivery.start=nil
 delivery.endAt=nil
 delivery.part:SetAttribute('HoldAt',nil)
end

function Delivery:canHold(p, delivery, now)
 local o=self.options
 if now<delivery.readyAt or not o.healthy(p) or o.inAssault(p) then return false end
 local hr=o.characterRoot(p)
 return hr and (hr.Position-delivery.part.Position).Magnitude<=Packs.Range
end

function Delivery:step(p, now)
 if p.leaving then return end
 local o=self.options
 local offer=o.offer(p)
 local delivery=p.packDelivery
 if not delivery then
  if offer and offer.opened==false and o.healthy(p) then
   local hr=o.characterRoot(p)
   local near=hr and (hr.Position-o.station.Position).Magnitude<20
   for _,station in ipairs(o.stations or {}) do near=near or (hr and (hr.Position-station.Position).Magnitude<20) end
   if near and now>=(p.nextPackDelivery or 0) then
    p.nextPackDelivery=now+1
    self:spawn(p,offer,hr.Position,now)
   end
  end
  return
 end
 if not offer or offer.id~=delivery.id then self:clear(p);return end
 if offer.opened~=false then
  if not delivery.openedAt then
   delivery.openedAt=now
   delivery.part:SetAttribute('OpenedAt',now)
  elseif now-delivery.openedAt>1.15 then self:clear(p) end
  return
 end
 delivery.prompt.Enabled=now>=delivery.readyAt and not delivery.opening
 if delivery.start and delivery.endAt and now>=delivery.endAt then self:release(delivery) end
 if delivery.start and not self:canHold(p,delivery,now) then self:release(delivery) end
end

return Delivery
