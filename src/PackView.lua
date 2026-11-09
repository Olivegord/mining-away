-- Each observer animates the same delivery from server timestamps.
local RS=game:GetService('ReplicatedStorage')
local TweenService=game:GetService('TweenService')
local PackView={}
PackView.__index=PackView
local colors={}
for index,rgb in ipairs(Packs.Palette) do colors[index]=Color3.fromRGB(table.unpack(rgb)) end
local idle=Color3.fromRGB(75,209,220)
local function block(parent,name,size,color,material)
 local part=Instance.new('Part')
 part.Name=name;part.Size=size;part.Color=color;part.Material=material
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Parent=parent
 return part
end

local function createCrate(parent)
 local model=Instance.new('Model');model.Name='LocalCompanyCrate'
 local shell=Color3.fromRGB(32,119,133)
 local body=block(model,'Shell',Vector3.new(1.88,1.12,1.58),shell,Enum.Material.Metal)
 local lid=block(model,'Lid',Vector3.new(1.94,.24,1.65),Color3.fromRGB(255,193,76),Enum.Material.Metal)
 body.Material=Enum.Material.CorrodedMetal;body.MaterialVariant='QuarryDrone_Ribbed'
 lid.Material=Enum.Material.Slate;lid.MaterialVariant='QuarryDrone_Painted'
 local seam=block(model,'Seal',Vector3.new(1.92,.055,1.62),idle,Enum.Material.Neon)
 local light=Instance.new('PointLight');light.Range=7;light.Color=idle;light.Parent=seam
 local sparks=Instance.new('ParticleEmitter')
 sparks.Name='SealSparks';sparks.Texture='rbxasset://textures/particles/sparkles_main.dds'
 sparks.Color=ColorSequence.new(idle);sparks.LightEmission=.85
 sparks.Lifetime=NumberRange.new(.3,.65);sparks.Speed=NumberRange.new(.8,2.4)
 sparks.Rate=5;sparks.SpreadAngle=Vector2.new(55,55);sparks.Drag=2
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16),NumberSequenceKeypoint.new(1,0)})
 sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,1)})
 sparks.Parent=seam;model.PrimaryPart=body;model.Parent=parent
 return {model=model,body=body,lid=lid,seam=seam,light=light,sparks=sparks}
end

local function createDrone(parent,droneConfig)
 local template=workspace:FindFirstChild('Drone') or RS:FindFirstChild('Drone')
 if not template or not template:IsA('Model') then return nil end
 local drone=template:Clone()
 drone.Name='CompanyCourier'
 for _,item in ipairs(drone:GetDescendants()) do
  if item:IsA('LuaSourceContainer') or item:IsA('BillboardGui') or item:IsA('SurfaceGui')
   or item:IsA('Decal') or item:IsA('Texture') or item:IsA('Highlight') or item:IsA('Sound') then item:Destroy()
  elseif item:IsA('BasePart') then
   item.Anchored=true;item.CanCollide=false;item.CanTouch=false;item.CanQuery=false
   item.Material=Enum.Material.Metal;item.Color=Color3.fromRGB(116,123,133)
   if item:IsA('MeshPart') then item.TextureID='' end
  elseif item:IsA('SpecialMesh') then item.TextureId=''
  elseif item:IsA('Beam') or item:IsA('Trail') or item:IsA('ParticleEmitter') or item:IsA('Light') then item.Enabled=false end
 end
 drone:ScaleTo(drone:GetScale()*.69)
 if droneConfig then droneConfig.decorate(drone,'Courier',Color3.fromRGB(151,164,169)) end
 drone.Parent=parent
 return drone
end

function PackView.new(options)
 local self=setmetatable({options=options,records={}},PackView)
 local focus=Instance.new('DepthOfFieldEffect')
 focus.Name='PackWorldBlur';focus.FocusDistance=1.2;focus.InFocusRadius=.65
 focus.FarIntensity=0;focus.NearIntensity=0;focus.Parent=game:GetService('Lighting')
 self.focus=focus
 return self
end

function PackView:setFocus(active)
 if self.focusActive==active then return end
 self.focusActive=active
 if self.focusTween then self.focusTween:Cancel() end
 self.focusTween=TweenService:Create(self.focus,TweenInfo.new(.22),{FarIntensity=active and .95 or 0})
 self.focusTween:Play()
end

local function disposeRecord(record)
 record.model:Destroy()
 if record.courier then record.courier:Destroy() end
end

function PackView:origin(offerId)
 for part in pairs(self.records) do
  if part:GetAttribute('OfferId')==offerId then return part.Position+Vector3.new(0,.55,0) end
 end
end

function PackView:render(record,source,now,age,tier)
 local o=self.options
 local position=source.Position
 local side=source:GetAttribute('Approach') or Vector3.new(1,0,0)
 local top=position+Vector3.new(0,4.8,0)
 local dronePosition
 if age<Packs.DropTime then
  local q=math.clamp(age/Packs.DropTime,0,1)
  dronePosition=top-side*(19*(1-q)^3)+Vector3.new(0,6*(1-q)^2,0)
 elseif age<Packs.DepartTime then
  local q=(age-Packs.DropTime)/(Packs.DepartTime-Packs.DropTime)
  dronePosition=top+side*(20*q^2)+Vector3.new(0,9*q^2,0)
 end
 if dronePosition and not record.courier and not record.triedCourier then
  record.triedCourier=true;record.courier=createDrone(o.parent,o.droneConfig)
 end
 if record.courier then
  if dronePosition then record.courier:PivotTo(CFrame.lookAt(dronePosition,dronePosition+side))
  else record.courier:Destroy();record.courier=nil end
 end
 local boxPosition=position
 if age<Packs.DropTime then boxPosition=dronePosition-Vector3.new(0,1.25,0)
 elseif age<Packs.DeliveryTime then
  local q=(age-Packs.DropTime)/(Packs.DeliveryTime-Packs.DropTime)
  boxPosition=position+Vector3.new(0,3.55*(1-q*q),0)
 elseif age<Packs.DeliveryTime+.21 then
  local q=(age-Packs.DeliveryTime)/.21
  boxPosition=position+Vector3.new(0,math.sin(q*math.pi)*.16*(1-q),0)
 end
 if not record.landed and age>=Packs.DeliveryTime then
  record.landed=true
  if age<Packs.DeliveryTime+.22 then o.audio:play('pack_land',position);record.sparks:Emit(12) end
 end
 local openedAt=source:GetAttribute('OpenedAt')
 local color=openedAt and colors[tier] or idle
 record.seam.Color=color;record.light.Color=color
 local lift=0
 local fade=0
 if openedAt then
  local ageOpen=math.max(0,now-openedAt)
  if not record.opened then
   record.opened=true
   if ageOpen<.25 then
    o.audio:play('pack_open',position,{pitch=.9+tier*.075})
    record.sparks.Color=ColorSequence.new(color)
    record.sparks.Speed=NumberRange.new(4,8);record.sparks:Emit(10+tier*7)
   end
  end
  lift=math.clamp(ageOpen/.29,0,1)
  fade=math.clamp((ageOpen-.28)/.72,0,1)
 end
 local pose=CFrame.lookAt(boxPosition,boxPosition+side)
 record.body.CFrame=pose
 record.lid.CFrame=pose*CFrame.new(0,.66+.4*lift,0)*CFrame.Angles(-lift*1.28,0,0)
 record.seam.CFrame=pose*CFrame.new(0,.54,0)
 record.light.Brightness=(openedAt and (.6+tier*.6) or .4)*(1-fade)
 record.sparks.Rate=openedAt and 0 or 3
 record.body.Transparency=fade;record.lid.Transparency=fade;record.seam.Transparency=fade
 return openedAt
end

function PackView:update(now)
 local o=self.options
 local folder=o.world:FindFirstChild('PackDeliveries')
 local player=o.player
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 local camera=workspace.CurrentCamera
 self.target=nil
 if folder then for _,source in ipairs(folder:GetChildren()) do
  local stamp,tier=source:GetAttribute('DeliveryAt'),source:GetAttribute('Tier') or 1
  local owner=source:GetAttribute('Owner')==player.UserId
  local openedAt=source:GetAttribute('OpenedAt')
  local eligible=owner and source:GetAttribute('Ready')==true and hr and hum and hum.Health>0 and not openedAt
   and (hr.Position-source.Position).Magnitude<=Packs.Range and not o.hidden()
  if eligible then self.target=source end
  local prompt=source:FindFirstChild('OpenPack')
  if prompt then
   local enabled=eligible==true and not o.busy()
   if prompt.Enabled~=enabled then prompt.Enabled=enabled end
  end
  if camera and stamp and colors[tier] and (camera.CFrame.Position-source.Position).Magnitude<100 then
   local record=self.records[source]
   if not record then record=createCrate(o.parent);self.records[source]=record end
   record.visible=true
   self:render(record,source,now,now-stamp,tier)
  end
 end end
 local map=o.world:FindFirstChild('Map')
 if map and not self.counter then
  local station=map:FindFirstChild('PackStation',true)
  self.counter=station and station:FindFirstChildOfClass('ProximityPrompt')
 end
 if self.counter then
  local enabled=not self.target and not o.hidden() and not o.busy()
  if self.counter.Enabled~=enabled then self.counter.Enabled=enabled end
 end
 for source,record in pairs(self.records) do
  if not record.visible then
   disposeRecord(record)
   self.records[source]=nil
  else record.visible=false end
 end
end

function PackView:destroy()
 self.focus:Destroy()
 for _,record in pairs(self.records) do disposeRecord(record) end
 table.clear(self.records)
end
return PackView
