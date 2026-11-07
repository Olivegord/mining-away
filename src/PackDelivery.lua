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
 part.Parent=self.folder
 p.packDelivery={part=part,id=offer.id,tier=offer.packTier,readyAt=now+Packs.DeliveryTime}
end

function Delivery:clear(p)
 local delivery=p.packDelivery
 if delivery then delivery.part:Destroy();p.packDelivery=nil end
end

function Delivery:release(delivery)
 delivery.start=nil
 delivery.untilAt=nil
 delivery.renewed=nil
 delivery.part:SetAttribute('HoldAt',nil)
end

function Delivery:canHold(p, delivery, now)
 local o=self.options
 if now<delivery.readyAt or not o.healthy(p) or o.inAssault(p) then return false end
 local hr=o.characterRoot(p)
 return hr and (hr.Position-delivery.part.Position).Magnitude<=Packs.Range
end

function Delivery:input(p, payload, now)
 local delivery=p.packDelivery
 if not delivery or type(payload)~='table' or payload.offerId~=delivery.id then return end
 if payload.phase=='End' then
  if delivery.start then
   if not self:finish(p,delivery,now) then self:release(delivery) end
  end
  return
 end
 if delivery.opening or not self:canHold(p,delivery,now) then return end
 if payload.phase=='Begin' and not delivery.start and now>=(delivery.nextBegin or 0) then
  delivery.nextBegin=now+.16
  delivery.start=now
  delivery.untilAt=now+Packs.HoldLease
  delivery.part:SetAttribute('HoldAt',now)
 elseif payload.phase=='Keep' and delivery.start and now<=delivery.untilAt then
  delivery.untilAt=now+Packs.HoldLease
  delivery.renewed=true
 end
end

function Delivery:finish(p,delivery,now)
 if not delivery.renewed or now>delivery.untilAt or now-delivery.start<Packs.duration(delivery.tier) or not self:canHold(p,delivery,now) then return false end
 delivery.opening=true
 delivery.start=nil
 self.options.open(p,delivery.id,function(status)
  if status=='rejected' and p.packDelivery==delivery then
   delivery.opening=false;self:release(delivery)
  end
 end)
 return true
end

function Delivery:step(p, now)
 if p.leaving then return end
 local o=self.options
 local offer=o.offer(p)
 local delivery=p.packDelivery
 if not delivery then
  if offer and offer.opened==false and o.healthy(p) then
   local hr=o.characterRoot(p)
   if hr and (hr.Position-o.station.Position).Magnitude<20 and now>=(p.nextPackDelivery or 0) then
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
 if not delivery.start then return end
 if now>delivery.untilAt or not self:canHold(p,delivery,now) then self:release(delivery);return end
 self:finish(p,delivery,now)
end

return Delivery
