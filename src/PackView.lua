-- Each observer animates the same delivery from server timestamps.
local RS=game:GetService('ReplicatedStorage')
local TweenService=game:GetService('TweenService')
local UIS=game:GetService('UserInputService')
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

-- Keep Roblox's input/hold events; only the progress presentation is custom.
function PackView:bindPrompt(record,source)
 local prompt=source:FindFirstChild('OpenPack')
 if not prompt then return end
 record.prompt=prompt
 if source:GetAttribute('Owner')~=self.options.player.UserId then return end
 local gui=Instance.new('BillboardGui')
 gui.Name='PackOpeningPrompt';gui.Adornee=source;gui.Size=UDim2.fromOffset(196,58)
 gui.StudsOffsetWorldSpace=Vector3.new(0,2.05,0);gui.AlwaysOnTop=true;gui.Active=true;gui.Enabled=false
 local button=Instance.new('TextButton')
 button.Name='Hold';button.Size=UDim2.fromScale(1,1);button.BackgroundColor3=Color3.fromRGB(27,32,41)
 button.BackgroundTransparency=.12;button.BorderSizePixel=0;button.Text='';button.AutoButtonColor=false;button.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=button
 local label=Instance.new('TextLabel')
 label.Name='Action';label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(12,8)
 label.Size=UDim2.new(1,-24,0,28);label.Font=Enum.Font.GothamMedium;label.TextSize=17
 label.TextColor3=Color3.fromRGB(239,243,249);label.Text='Hold E  ·  Open pack';label.Parent=button
 local track=Instance.new('Frame');track.Name='Track';track.BorderSizePixel=0
 track.BackgroundColor3=Color3.fromRGB(69,77,90);track.Position=UDim2.fromOffset(12,42)
 track.Size=UDim2.new(1,-24,0,7);track.ClipsDescendants=true;track.Parent=button
 local fill=Instance.new('Frame');fill.Name='Progress';fill.BorderSizePixel=0
 fill.BackgroundColor3=idle;fill.Size=UDim2.fromScale(0,1);fill.Parent=track
 gui.Parent=self.options.player:WaitForChild('PlayerGui')
 record.indicator=gui;record.fill=fill
 local function finishPointer(input)
  if record.pointer~=input then return end
  record.pointer=nil;prompt:InputHoldEnd()
 end
 record.connections={
  prompt.PromptShown:Connect(function(inputType)
   record.shown=true
   label.Text=inputType==Enum.ProximityPromptInputType.Touch and 'Hold to open pack'
    or inputType==Enum.ProximityPromptInputType.Gamepad and 'Hold X  ·  Open pack' or 'Hold E  ·  Open pack'
  end),
  prompt.PromptHidden:Connect(function()
   record.shown=false;gui.Enabled=false
   if record.pointer then finishPointer(record.pointer) end
  end),
  prompt.PromptButtonHoldBegan:Connect(function()
   record.holdAt=workspace:GetServerTimeNow();record.releaseAt=nil;record.completed=false
  end),
  prompt.PromptButtonHoldEnded:Connect(function() record.releaseAt=workspace:GetServerTimeNow()+.08 end),
  prompt:GetPropertyChangedSignal('Enabled'):Connect(function()
   if prompt.Enabled and source:GetAttribute('HoldAt')==nil then record.completed=false end
  end),
  prompt.Triggered:Connect(function() record.completed=true end),
  button.InputBegan:Connect(function(input)
   if record.shown and not record.pointer and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then
    record.pointer=input;prompt:InputHoldBegin()
   end
  end),
   UIS.InputEnded:Connect(finishPointer),
 }
 -- Register visibility handlers before allowing the first PromptShown event.
 prompt.Enabled=false
end

local function chargeRing(record,pose,progress,stage,holding,openedAt,now)
 if not record.ring and not holding then return end
 if not record.ring then
  record.ring={}
  for i=1,32 do
   local part=block(record.model,'SealRing',Vector3.new(.245,.028,.055),idle,Enum.Material.Neon)
   part.CastShadow=false;table.insert(record.ring,part)
  end
 end
 local ageOpen=openedAt and math.max(0,now-openedAt)
 local visible=holding or ageOpen and ageOpen<.28
 local radius=1.32+(ageOpen and ageOpen*4 or .12*progress)
 for i,part in ipairs(record.ring) do
  local angle=(i-1)/#record.ring*math.pi*2
  part.CFrame=pose*CFrame.Angles(0,-angle,0)*CFrame.new(0,-.48,-radius)
  local fill=math.clamp(progress*#record.ring-i+1,0,1)
  part.Color=colors[stage] or idle
  part.Transparency=visible and (ageOpen and math.clamp(.15+ageOpen*3,0,1) or .85-.76*fill) or 1
 end
end

local function disposeRecord(record)
 if record.connections then for _,connection in ipairs(record.connections) do connection:Disconnect() end end
 if record.indicator then record.indicator:Destroy() end
 record.model:Destroy()
 if record.courier then record.courier:Destroy() end
end

function PackView:render(record,source,now,age,tier,progress,stage,holding)
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
 local color=openedAt and colors[tier] or colors[stage] or idle
 local heat=holding and progress or 0
 local moving=(holding or openedAt) and not CardView.reducedMotion()
 local tremor=holding and moving and math.sin(now*(22+heat*28))*heat or 0
 record.seam.Color=color;record.light.Color=color
 local lift,fade,recoil=0,0,0
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
  recoil=moving and math.sin(math.clamp(ageOpen/.12,0,1)*math.pi)*.08 or 0
  lift=1-(1-math.clamp((ageOpen-.06)/.32,0,1))^3
  fade=math.clamp((ageOpen-.28)/.72,0,1)
 end
 local swell=moving and (.12*heat-recoil) or 0
 local pose=CFrame.lookAt(boxPosition,boxPosition+side)*CFrame.new(.035*tremor,.52*swell,0)*CFrame.Angles(0,0,.027*tremor)
 record.body.Size=Vector3.new(1.88,1.12,1.58)*(1+swell)
 record.lid.Size=Vector3.new(1.94,.24,1.65)*(1+swell)
 record.seam.Size=Vector3.new(1.92,.055,1.62)*(1+swell)
 chargeRing(record,CFrame.lookAt(position,position+side),openedAt and 1 or progress,openedAt and tier or stage,holding,openedAt,now)

 record.body.CFrame=pose
 record.lid.CFrame=pose*CFrame.new(0,.66*(1+swell)+.4*lift+.055*heat,0)*CFrame.Angles(-lift*1.28,0,0)
 record.seam.CFrame=pose*CFrame.new(0,.54*(1+swell),0)
 record.light.Brightness=(openedAt and (.6+tier*.6) or (.4+2.1*heat))*(1-fade)
 record.sparks.Rate=openedAt and 0 or 3+14*heat
 if not openedAt then record.sparks.Color=ColorSequence.new(color) end
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
 local crateInReach=false
 if folder then for _,source in ipairs(folder:GetChildren()) do
  local stamp,tier=source:GetAttribute('DeliveryAt'),source:GetAttribute('Tier') or 1
  local owner=source:GetAttribute('Owner')==player.UserId
  local openedAt=source:GetAttribute('OpenedAt')
  local inReach=owner and hr and hum and hum.Health>0 and not openedAt and (hr.Position-source.Position).Magnitude<=Packs.Range
  if inReach then crateInReach=true end
  local eligible=inReach and source:GetAttribute('Ready')==true and not o.hidden()
  local prompt=source:FindFirstChild('OpenPack')
  if camera and stamp and (camera.CFrame.Position-source.Position).Magnitude<100 then
   local record=self.records[source]
   if not record then record=createCrate(o.parent);self.records[source]=record end
   if prompt and not record.prompt then self:bindPrompt(record,source) end
   local enabled=eligible==true and not o.busy()
   if prompt and prompt.Enabled~=enabled then prompt.Enabled=enabled end
   if enabled and source:GetAttribute('HoldAt')==nil and record.completed and record.releaseAt and now-record.releaseAt>.3 then
    record.holdAt=nil;record.completed=false
   end
   if record.releaseAt and now>=record.releaseAt and not record.completed then record.holdAt=nil;record.releaseAt=nil end
   if not enabled and not record.completed then record.holdAt=nil end
   local holdAt=source:GetAttribute('HoldAt')
   if owner then holdAt=record.holdAt end
   local holding=not openedAt and holdAt~=nil
   local holdTier=prompt and Packs.holdTier(prompt.HoldDuration) or tier
   local progress,stage=0,0
   if holding then progress,stage=Packs.sample(holdTier,now-holdAt) end
   if record.indicator then
    record.indicator.Enabled=enabled and record.shown==true
    record.fill.Size=UDim2.fromScale(record.completed and 1 or progress,1)
    record.fill.BackgroundColor3=colors[stage] or idle
    if holding and stage~=record.lastStage then o.audio:play('pack_step',source.Position,{pitch=.78+stage*.17}) end
    record.lastStage=stage
   end
   record.visible=true
   self:render(record,source,now,now-stamp,tier,progress,stage,holding)
  elseif prompt and prompt.Enabled then prompt.Enabled=false end
 end end
 local map=o.world:FindFirstChild('Map')
 if map and not self.counter then
  local station=map:FindFirstChild('PackStation',true)
  self.counter=station and station:FindFirstChildOfClass('ProximityPrompt')
 end
 if self.counter then
  local enabled=not crateInReach and not o.hidden() and not o.busy()
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
