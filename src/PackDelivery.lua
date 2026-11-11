-- One replicated delivery per paid, sealed offer. Only the owner can open it.
local Delivery = {}
Delivery.__index = Delivery
local lanes={0,1,-1,2,-2,3,-3}

local function flat(vector)
 return Vector3.new(vector.X, 0, vector.Z)
end

local function supportsCrate(position, forward, sideways, ground, ray)
 for _,x in ipairs({-.96,.96}) do
  for _,z in ipairs({-.82,.82}) do
   local corner=position+forward*x+sideways*z
   local hit=workspace:Raycast(corner+Vector3.yAxis*4,-Vector3.yAxis*16,ray)
   if not hit or math.abs(hit.Position.Y-ground)>.18 then return false end
  end
 end
 return true
end

function Delivery.new(options)
 local folder = Instance.new('Folder')
 folder.Name = 'PackDeliveries'
 folder.Parent = options.root
 return setmetatable({options=options, folder=folder}, Delivery)
end

function Delivery:landing(buyerPosition)
 local o=self.options
 local counter=o.station
 local station=counter.Position
 local direction=flat(buyerPosition-station)
 if direction.Magnitude<.1 then direction=flat(o.home-station) end
 if direction.Magnitude<.1 then direction=Vector3.new(0,0,1) end
 local forward=direction.Unit
 local sideways=Vector3.new(-forward.Z,0,forward.X)
 local localDirection=counter.CFrame:PointToObjectSpace(station+forward)
 local edge=math.min(counter.Size.X*.5/math.max(.001,math.abs(localDirection.X)),counter.Size.Z*.5/math.max(.001,math.abs(localDirection.Z)))
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Exclude
 local ignored={self.folder}
 for _,player in ipairs(o.players:GetPlayers()) do if player.Character then table.insert(ignored,player.Character) end end
 ray.FilterDescendantsInstances=ignored
 ray.RespectCanCollide=true
 local floorY=station.Y-counter.Size.Y*.5
 local position,score=nil,math.huge
 local occupiedCrates=self.folder:GetChildren()
 for _,setback in ipairs({1.6,4.4}) do
  local center=station+forward*(edge+setback)
  for _,lane in ipairs(lanes) do
   local candidate=center+sideways*lane*2.8
   if flat(buyerPosition-candidate).Magnitude<2.4 then continue end
   local occupied=false
   for _,other in ipairs(occupiedCrates) do
    if flat(other.Position-candidate).Magnitude<2.6 then occupied=true;break end
   end
   if occupied then continue end
   local hit=workspace:Raycast(candidate+Vector3.yAxis*4,-Vector3.yAxis*16,ray)
   if not hit and o.requireGround then continue end
   local ground=hit and hit.Position.Y or o.groundHeight(candidate.X,candidate.Z)
   if hit and (hit.Normal.Y<.88 or math.abs(ground-floorY)>1.4) then continue end
   local landing=Vector3.new(candidate.X,ground+.56,candidate.Z)
   local distance=(buyerPosition-landing).Magnitude
   if distance>=score then continue end
   local blocked=workspace:Raycast(buyerPosition,landing-buyerPosition,ray)~=nil
   local cost=distance+(blocked and Packs.Range*2 or 0)
   if cost>=score then continue end
   if o.requireGround and not supportsCrate(candidate,forward,sideways,ground,ray) then continue end
   position,score=landing,cost
  end
  if score<=Packs.Range-2 then break end
 end
 return position,sideways
end

function Delivery:spawn(p, offer, buyerPosition, now)
 if not offer or offer.opened~=false or p.leaving or p.packDelivery then return end
 local o=self.options
 local position,sideways=self:landing(buyerPosition)
 if not position then return end
 local part=World.part(nil,'CompanyPack',position,Vector3.new(1.9,1.4,1.6),Color3.new())
 part.Transparency=1
 part:SetAttribute('OfferId',offer.id)
 part:SetAttribute('Owner',p.player.UserId)
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
  local now=o.getClock()
  if player~=p.player or delivery.opening or not self:canOpen(p,delivery,now) then return end
  if delivery.holdAt and not delivery.releasedAt then return end
  delivery.holdAt=now;delivery.releasedAt=nil;part:SetAttribute('HoldAt',now)
 end)
 prompt.PromptButtonHoldEnded:Connect(function(player)
  if player==p.player and delivery.holdAt and not delivery.opening then
   delivery.releasedAt=delivery.releasedAt or o.getClock()
  end
 end)
 prompt.Triggered:Connect(function(player)
  local now=o.getClock()
  if player~=p.player or delivery.opening or not delivery.holdAt or not self:canOpen(p,delivery,now) then return end
  -- Roblox can deliver HoldEnded first in the completion frame. Use its
  -- timestamp so releasing early and waiting cannot complete the hold.
  local released=delivery.releasedAt
  if released and now-released>.12 or (released or now)-delivery.holdAt+.06<prompt.HoldDuration then
   self:release(delivery);return
  end
  delivery.opening=true;prompt.Enabled=false
  o.open(p,delivery.id,function(status)
   if p.packDelivery~=delivery then return end
   if status=='rejected' then delivery.opening=false;self:release(delivery)
   elseif status=='accepted' then self:reveal(delivery,o.getClock()) end
  end)
 end)
 part.Parent=self.folder
end

function Delivery:release(delivery)
 delivery.holdAt=nil;delivery.releasedAt=nil
 delivery.part:SetAttribute('HoldAt',nil)
end

function Delivery:clear(p)
 local delivery=p.packDelivery
 if delivery then delivery.part:Destroy();p.packDelivery=nil end
end

function Delivery:canOpen(p, delivery, now)
 local o=self.options
 local offer=o.offer(p)
 if not offer or offer.id~=delivery.id or offer.opened~=false or now<delivery.readyAt or not o.healthy(p) or o.inAssault(p) then return false end
 local hr=o.characterRoot(p)
 return hr and (hr.Position-delivery.part.Position).Magnitude<=Packs.Range
end

function Delivery:reveal(delivery,now)
 delivery.openedAt=now
 delivery.part:SetAttribute('Tier',delivery.tier)
 delivery.part:SetAttribute('OpenedAt',now)
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
   self:reveal(delivery,now)
  elseif now-delivery.openedAt>1.15 then self:clear(p) end
  return
 end
 if now>=delivery.readyAt and not delivery.ready then delivery.ready=true;delivery.part:SetAttribute('Ready',true) end
 delivery.prompt.Enabled=delivery.ready==true and not delivery.opening
 if delivery.holdAt and not delivery.opening and
  ((delivery.releasedAt and now-delivery.releasedAt>.12) or not self:canOpen(p,delivery,now)) then
  self:release(delivery)
 end
end

return Delivery
