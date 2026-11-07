-- Each observer animates the same delivery from server timestamps.
local RS=game:GetService('ReplicatedStorage')
local UIS=game:GetService('UserInputService')
local TweenService=game:GetService('TweenService')
local PackView={}
PackView.__index=PackView
local colors={
 Color3.fromRGB(181,190,201),
 Color3.fromRGB(255,213,82),
 Color3.fromRGB(86,255,141),
 Color3.fromRGB(185,110,255),
}
local idle=Color3.fromRGB(115,135,150)
local function block(parent,name,size,color,material)
 local part=Instance.new('Part')
 part.Name=name;part.Size=size;part.Color=color;part.Material=material
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Parent=parent
 return part
end

local function createCrate(parent)
 local model=Instance.new('Model');model.Name='LocalCompanyCrate'
 local shell=Color3.fromRGB(39,47,58)
 local body=block(model,'Shell',Vector3.new(1.88,1.12,1.58),shell,Enum.Material.Metal)
 local lid=block(model,'Lid',Vector3.new(1.94,.24,1.65),Color3.fromRGB(67,78,91),Enum.Material.Metal)
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

local function createDrone(parent)
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
 drone.Parent=parent
 return drone
end

function PackView.new(options)
 local self=setmetatable({options=options,records={}},PackView)
 local focus=Instance.new('DepthOfFieldEffect')
 focus.Name='PackWorldBlur';focus.FocusDistance=1.2;focus.InFocusRadius=.65
 focus.FarIntensity=0;focus.NearIntensity=0;focus.Parent=game:GetService('Lighting')
 self.focus=focus
 self.connections={UIS.WindowFocusReleased:Connect(function()
  for _,record in pairs(self.records) do if record.prompt then record.prompt:InputHoldEnd() end end
 end)}
 self.suppressed={}
 return self
end

function PackView:setFocus(active)
 if self.focusActive==active then return end
 self.focusActive=active
 if self.focusTween then self.focusTween:Cancel() end
 self.focusTween=TweenService:Create(self.focus,TweenInfo.new(.22),{FarIntensity=active and .95 or 0})
 self.focusTween:Play()
end

-- Keep Roblox's input/hold events; only the progress presentation is custom.
function PackView:bindPrompt(record,source)
 local prompt=source:FindFirstChild('OpenPack')
 if not prompt then return end
 record.prompt=prompt
 if source:GetAttribute('Owner')~=self.options.player.UserId then return end
 local gui=Instance.new('BillboardGui')
 gui.Name='PackOpeningPrompt';gui.Adornee=source;gui.Size=UDim2.fromOffset(220,62)
 gui.StudsOffsetWorldSpace=Vector3.new(0,2.3,0);gui.AlwaysOnTop=true;gui.Active=true;gui.Enabled=false
 local button=Instance.new('TextButton')
 button.Name='Hold';button.Size=UDim2.fromScale(1,1);button.BackgroundColor3=Color3.fromRGB(27,32,41)
 button.BackgroundTransparency=.12;button.BorderSizePixel=0;button.Text='';button.AutoButtonColor=false;button.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=button
 local label=Instance.new('TextLabel')
 label.Name='Action';label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(12,8)
 label.Size=UDim2.new(1,-24,0,28);label.Font=Enum.Font.GothamMedium;label.TextSize=17
 label.TextColor3=Color3.fromRGB(239,243,249);label.Text='[E]  Open pack';label.Parent=button
 local track=Instance.new('Frame');track.Name='Track';track.BorderSizePixel=0
 track.BackgroundColor3=Color3.fromRGB(69,77,90);track.Position=UDim2.fromOffset(12,44)
 track.Size=UDim2.new(1,-24,0,6);track.ClipsDescendants=true;track.Parent=button
 local fill=Instance.new('Frame');fill.Name='Progress';fill.BorderSizePixel=0
 fill.BackgroundColor3=idle;fill.Size=UDim2.fromScale(0,1);fill.Parent=track
 gui.Parent=self.options.player:WaitForChild('PlayerGui')
 record.indicator=gui;record.fill=fill
 local function finishPointer(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
 end
 record.connections={
  prompt.PromptShown:Connect(function(inputType)
   record.shown=true
   label.Text=inputType==Enum.ProximityPromptInputType.Touch and 'Hold to open pack'
    or inputType==Enum.ProximityPromptInputType.Gamepad and '[X]  Open pack' or '[E]  Open pack'
  end),
  prompt.PromptHidden:Connect(function() record.shown=false;gui.Enabled=false end),
  prompt.PromptButtonHoldBegan:Connect(function()
   record.holdAt=workspace:GetServerTimeNow();record.releaseAt=nil;record.completed=false
  end),
  prompt.PromptButtonHoldEnded:Connect(function() record.releaseAt=workspace:GetServerTimeNow()+.08 end),
  prompt.Triggered:Connect(function() record.completed=true end),
  button.InputBegan:Connect(function(input)
   if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then prompt:InputHoldBegin() end
  end),
  button.InputEnded:Connect(finishPointer),
  UIS.InputEnded:Connect(finishPointer),
 }
 -- Register visibility handlers before allowing the first PromptShown event.
 prompt.Enabled=false
end

local function disposeRecord(record)
 if record.connections then for _,connection in ipairs(record.connections) do connection:Disconnect() end end
 if record.indicator then record.indicator:Destroy() end
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
  record.triedCourier=true;record.courier=createDrone(o.parent)
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
 local holdAt=source:GetAttribute('HoldAt')
 local openedAt=source:GetAttribute('OpenedAt')
 local progress,stage=0,0
 if openedAt then progress,stage=1,tier
 elseif holdAt then progress,stage=Packs.sample(tier,now-holdAt) end
 local color=colors[stage] or idle
 if stage~=record.stage then
  record.stage=stage
  record.seam.Color=color;record.light.Color=color;record.sparks.Color=ColorSequence.new(color)
  if stage>0 and not openedAt then
   record.sparks:Emit(7+stage*3)
   o.audio:play('pack_step',position,{pitch=.78+stage*.16})
  end
 end
 local lift=0
 local fade=0
 if openedAt then
  local ageOpen=math.max(0,now-openedAt)
  if not record.opened then
   record.opened=true
   if ageOpen<.25 then
    o.audio:play('pack_open',position,{pitch=.9+tier*.075})
    record.sparks.Speed=NumberRange.new(4,8);record.sparks:Emit(12+tier*6)
   end
  end
  lift=math.clamp(ageOpen/.29,0,1)
  fade=math.clamp((ageOpen-.28)/.72,0,1)
 end
 local pose=CFrame.lookAt(boxPosition,boxPosition+side)
 record.body.CFrame=pose
 record.lid.CFrame=pose*CFrame.new(0,.66+.4*lift,0)*CFrame.Angles(-lift*1.28,0,0)
 record.seam.CFrame=pose*CFrame.new(0,.54,0)
 record.light.Brightness=(.4+progress*1.5)*(1-fade)
 record.sparks.Rate=openedAt and 0 or (stage>0 and 10+stage*5 or 5)
 record.body.Transparency=fade;record.lid.Transparency=fade;record.seam.Transparency=fade
 return progress,color,holdAt,openedAt
end

function PackView:update(now)
 local o=self.options
 local folder=o.world:FindFirstChild('PackDeliveries')
 local player=o.player
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 local camera=workspace.CurrentCamera
 self.target=nil
 if folder and camera then for _,source in ipairs(folder:GetChildren()) do
  local stamp,tier=source:GetAttribute('DeliveryAt'),source:GetAttribute('Tier')
  if stamp and colors[tier] and (camera.CFrame.Position-source.Position).Magnitude<100 then
   local record=self.records[source]
   if not record then record=createCrate(o.parent);self.records[source]=record end
   if not record.prompt then self:bindPrompt(record,source) end
   record.visible=true
   local age=now-stamp
   local _,_,_,openedAt=self:render(record,source,now,age,tier)
   if source:GetAttribute('Owner')==player.UserId and hr and hum and hum.Health>0 and not openedAt
    and age>=Packs.DeliveryTime and (hr.Position-source.Position).Magnitude<=Packs.Range and not o.hidden() then
    self.target=source

   end
  end
 end end
 for source,record in pairs(self.records) do
  if record.prompt then
   local enabled=source==self.target and not o.busy()
   record.prompt.Enabled=enabled
   if record.indicator then
    record.indicator.Enabled=enabled and record.shown==true
    if record.releaseAt and now>=record.releaseAt and not record.completed then record.holdAt=nil end
    if not enabled and not record.completed then record.holdAt=nil end
    local progress,stage=0,0
    if record.completed then progress,stage=1,source:GetAttribute('Tier')
    elseif record.holdAt then progress,stage=Packs.sample(source:GetAttribute('Tier'),now-record.holdAt) end
    record.fill.Size=UDim2.fromScale(progress,1)
    record.fill.BackgroundColor3=colors[stage] or idle
   end
  end
 end
 local map=o.world:FindFirstChild('Map')
 if self.target and map then
  if not self.suppressing then
   for _,prompt in ipairs(map:GetDescendants()) do
    if prompt:IsA('ProximityPrompt') then self.suppressed[prompt]=prompt.Enabled;prompt.Enabled=false end
   end
   self.suppressing=true
  end
 elseif self.suppressing then
  for prompt,enabled in pairs(self.suppressed) do if prompt.Parent then prompt.Enabled=enabled end end
  table.clear(self.suppressed);self.suppressing=false
 end
 for source,record in pairs(self.records) do
  if not record.visible then
   disposeRecord(record)
   self.records[source]=nil
  else record.visible=false end
 end
end

function PackView:destroy()
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 self.focus:Destroy()
 for prompt,enabled in pairs(self.suppressed) do if prompt.Parent then prompt.Enabled=enabled end end
 for _,record in pairs(self.records) do disposeRecord(record) end
 table.clear(self.records)
end
return PackView
