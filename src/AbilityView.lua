-- Compact gadget controls and smooth, all-observer scrap-bot rendering.
-- One activation sends intent. The server owns the charge, release, targets, damage and rewards.
local View={}
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local SCRAP_TIP=Color3.fromRGB(185,174,126)
local SCRAP_HIT=Color3.fromRGB(255,232,154)
local function enabled(profile,kind)
 return profile and profile.run and Shops.abilityUnlocked(profile,kind) or false
end

function View.start(options)
 local player=Players.LocalPlayer
 local U=options.interface;local root=options.parent
 local panel=U.panel(root,UDim2.fromOffset(16,160),UDim2.fromOffset(220,56),U.palette.panel,12)
 panel.Name='MiningGadgets';panel.Visible=false
 local state: any={cooldowns={}};local connections={};local dead=false;local lastSend=0
 local function connect(signal,fn) table.insert(connections,signal:Connect(fn)) end
 local function decode()
  local raw=player:GetAttribute('MA_Ability')
  if type(raw)=='string' then local ok,value=pcall(function() return Http:JSONDecode(raw) end);if ok and type(value)=='table' then state=value end end
 end
 decode();connect(player:GetAttributeChangedSignal('MA_Ability'),decode)
 local function nearestField(profile)
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  local world=workspace:FindFirstChild('MiningAway');local fields=world and world:FindFirstChild('Fields')
  local best,id=math.huge,nil
  if hr and fields and profile and not player:GetAttribute('MA_InAssault') then for _,field in ipairs(fields:GetChildren()) do
   local phase=field:GetAttribute('Phase')
   local unlocked=field:GetAttribute('AlwaysUnlocked') or Shops.unlocked(profile,field.Name)
   local cleared=phase=='Safe' or phase=='Cleared' or field.Name=='Quartz' or field.Name=='Ruby'
    or (profile.clearedFields and profile.clearedFields[field.Name])
   local floor=unlocked and cleared and (field:FindFirstChild('Field') or field:FindFirstChild('FieldFloor') or field:FindFirstChildWhichIsA('BasePart'))
   if floor then
    local point=floor.CFrame:PointToObjectSpace(hr.Position)
    if math.abs(point.X)<=floor.Size.X*.5+18 and math.abs(point.Z)<=floor.Size.Z*.5+18 and math.abs(point.Y)<=45 then
     local d=point.Magnitude;if d<best then best=d;id=field:GetAttribute('FieldId') or field:GetAttribute('Tier') end
    end
   end
  end end
  return id
 end
 local function activate(kind)
  if options.hidden() or os.clock()-lastSend<.15 then return end
  local profile=options.profile();if not enabled(profile,kind) or profile.pendingTransaction then return end
  local charge=state.runId==profile.run.id and state.charge or nil
  if charge then return end
  local fieldId=nearestField(profile);if not fieldId then return end
  lastSend=os.clock()
  options.command:FireServer('MiningAbility',{op='begin',kind=kind,fieldId=fieldId,runId=profile.run.id})
 end
 local orbital=U.button(panel,UDim2.fromOffset(8,7),UDim2.fromOffset(98,42),'Orbital [G]',function() activate('Orbital') end,Color3.fromRGB(208,47,70))
 orbital.Name='OrbitalGadget';orbital.TextSize=16
 local scrap=U.button(panel,UDim2.fromOffset(114,7),UDim2.fromOffset(98,42),'Scrap [B]',function() activate('Scrap') end,Color3.fromRGB(133,53,211))
 scrap.Name='ScrapGadget';scrap.TextSize=16
 connect(UIS.InputBegan,function(input,processed)
  if processed or UIS:GetFocusedTextBox() then return end
  if input.KeyCode==Enum.KeyCode.G then activate('Orbital') elseif input.KeyCode==Enum.KeyCode.B then activate('Scrap') end
 end)
 -- Server records carry poses only; each observer clones the original art locally.
 local visualRoot=Instance.new('Folder');visualRoot.Name='ScrapBotPresentation';visualRoot.Parent=workspace
 local bots={}
 local function remove(source,record)
  record.view:Destroy();record.beam:Destroy()
  -- The tiny tool retires immediately; its already emitted world-space motes
  -- get their full tail instead of being cut off at swarm expiry.
  record.core:Destroy();bots[source]=nil
 end
 local function observe(source)
  if bots[source] or not source:IsA('Folder') or source:GetAttribute('ScrapBot')~=true then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local reference=source.Parent and source.Parent:FindFirstChild('Template')
  local template=reference and reference.Value
  if not template or not template:IsA('Model') then return end
  local view=template:Clone();view.Name='LocalScrapBot'
  for _,node in ipairs(view:GetDescendants()) do
   if node:IsA('LuaSourceContainer') or node:IsA('BillboardGui') or node:IsA('SurfaceGui') or node:IsA('Sound') then node:Destroy()
   elseif node:IsA('Beam') or node:IsA('Trail') or node:IsA('ParticleEmitter') then node.Enabled=false
   elseif node:IsA('BasePart') then node.Anchored=true;node.CastShadow=false;node.Reflectance=0 end
  end
  view:ScaleTo(view:GetScale()*.18)
  if options.droneConfig then options.droneConfig.decorate(view,'Dart',Color3.fromRGB(179,176,113)) end
  for _,part in ipairs(view:GetDescendants()) do if part:IsA('BasePart') then part.LocalTransparencyModifier=0;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end end
  view.Parent=visualRoot;view:PivotTo(CFrame.new(position))
  local function beam(width,color)
   local part=Instance.new('Part');part.Name='TinyScrapChisel';part.Shape=Enum.PartType.Cylinder
   part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
   part.Material=Enum.Material.CorrodedMetal;part.MaterialVariant='QuarryDrone_Ribbed'
   part.Color=color;part.Transparency=1;part.Size=Vector3.new(.01,width,width);part.Parent=visualRoot;return part
  end
  local chisel=beam(.05,SCRAP_TIP)
  bots[source]={view=view,pos=position,beam=beam(.16,Color3.fromRGB(99,111,103)),core=chisel,alpha=0,yaw=0,samples={}}
 end
 local function scan()
  local folder=workspace:FindFirstChild('DroneRoleState')
  if folder then for _,group in ipairs(folder:GetChildren()) do if group:GetAttribute('ScrapSwarm') then for _,source in ipairs(group:GetChildren()) do observe(source) end end end end
 end
 local scanAt=0;local nearby=false
 connect(RunService.RenderStepped,function(dt)
  if dead or options.held and options.held() then return end
  local now=workspace:GetServerTimeNow();local profile=options.profile()
  local hasOrbital,hasScrap=enabled(profile,'Orbital'),enabled(profile,'Scrap')
  panel.Visible=(hasOrbital or hasScrap) and nearby and not options.hidden()
  local short=root.AbsoluteSize.Y<390
  local compact=short and root.AbsoluteSize.X>=568
  local panelWidth=compact and 180 or 220
  panel.Position=UDim2.fromOffset(math.min(12,math.max(0,root.AbsoluteSize.X-panelWidth)),short and 64 or 160)
  orbital.Size=UDim2.fromOffset(compact and 78 or 98,42)
  scrap.Position=UDim2.fromOffset(compact and 94 or 114,7);scrap.Size=orbital.Size
  local charge=profile and state.runId==profile.run.id and state.charge or nil
  panel.Size=UDim2.fromOffset(panelWidth,56)
  local function paint(button,kind,unlocked,key)
   button.Visible=unlocked
   local remaining=math.max(0,math.ceil(((state.cooldowns or {})[kind] or 0)-now))
   local charging=charge and charge.kind==kind
   local busy=profile and profile.pendingTransaction
   U.setEnabled(button,unlocked and not busy and remaining==0 and not charge)
   button.Text=busy and 'Saving…' or charging and (kind..'…') or remaining>0 and (kind..' '..remaining..'s') or (kind..(UIS.TouchEnabled and '' or ' ['..key..']'))
  end
  paint(orbital,'Orbital',hasOrbital,'G');paint(scrap,'Scrap',hasScrap,'B')
  if now>=scanAt then scanAt=now+.2;nearby=(hasOrbital or hasScrap) and nearestField(profile)~=nil;scan() end
  for source,record in pairs(bots) do
   if not source.Parent or not source.Parent.Parent or now>=(source.Parent:GetAttribute('Expires') or 0) then remove(source,record)
   else
    local position=source:GetAttribute('Position') or record.pos
    local target=source:GetAttribute('TargetPosition') or position
    MotionBuffer.push(record.samples,source:GetAttribute('PoseAt'),CFrame.new(position))
    local pose=MotionBuffer.pose(record.samples,now)
    local nextPosition=pose and pose.Position or position
    local delta=nextPosition-record.pos
    record.pos=nextPosition
    if delta.X*delta.X+delta.Z*delta.Z>.001 then
     local yaw=math.atan2(-delta.X,-delta.Z);local diff=(yaw-record.yaw+math.pi)%(2*math.pi)-math.pi
     record.yaw+=diff*(1-math.exp(-math.min(dt,.1)*8))
    end
    record.view:PivotTo(CFrame.new(record.pos)*CFrame.Angles(0,record.yaw,0))
    local active=source:GetAttribute('Active')==true
    record.alpha+=( (active and 1 or 0)-record.alpha)*(1-math.exp(-math.min(dt,.1)*22))
    -- Solid miniature chisels tap on confirmed damage pulses; these bots do
    -- close mechanical work rather than projecting the miner's laser again.
    local serial=source:GetAttribute('Pulse') or 0
    if serial~=(record.serial or serial) then
     local hitAt=source:GetAttribute('HitAt');local point=source:GetAttribute('HitPosition')
     if hitAt and point and now-hitAt<.23 then
      record.hitAt=now
      RoleVisuals.ImpactParticles(point,SCRAP_HIT,.36,'Scrap')
      if options.audio then options.audio:play('scrap_tap',point,{pitch=1+serial%3*.06}) end
     end
    end
    record.serial=serial
    local tap=math.max(0,1-(now-(record.hitAt or -100))/.18)
    local height=math.min(1.3,math.max(.1,record.pos.Y-target.Y))
    local base=Vector3.new(record.pos.X,record.pos.Y-.18-tap*.14,record.pos.Z)
    local pose=CFrame.new(base-Vector3.new(0,height*.5,0))*CFrame.Angles(0,0,math.pi/2)
    record.beam.Size=Vector3.new(height,.065,.065);record.beam.CFrame=pose
    record.beam.Color=Color3.fromRGB(99,111,103);record.beam.Transparency=1-record.alpha
    record.core.Size=Vector3.new(.16,.22,.22);record.core.CFrame=CFrame.new(base-Vector3.new(0,height-.08,0))*CFrame.Angles(0,0,math.pi/2)
    record.core.Color=SCRAP_TIP:Lerp(SCRAP_HIT,tap);record.core.Transparency=1-record.alpha
    if active then record.view:PivotTo(CFrame.new(record.pos+Vector3.new(0,-tap*.08,0))*CFrame.Angles(0,record.yaw,0)) end
   end
  end
 end)
 return {destroy=function()
  if dead then return end;dead=true
  for _,connection in ipairs(connections) do connection:Disconnect() end
  for source,record in pairs(bots) do remove(source,record) end
  panel:Destroy();visualRoot:Destroy()
 end}
end
return View
