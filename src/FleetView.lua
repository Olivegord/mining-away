-- Client-only display stage. The avatar and crew in the mining field keep their
-- original positions, work orders and ownership while the camera is here.
local FleetView={}
FleetView.__index=FleetView

local RunService=game:GetService('RunService')
local Lighting=game:GetService('Lighting')
local UIS=game:GetService('UserInputService')
local GuiService=game:GetService('GuiService')
local Context=game:GetService('ContextActionService')
local Storage=game:GetService('ReplicatedStorage')
local STAGE=Vector3.new(0,12000,0)
local ZOOM_TIME=.72
local COVER_TIME=.18
local REVEAL_TIME=.24
local FOG=Color3.fromRGB(43,51,80)
local WHITE=Color3.fromRGB(248,251,255)
local CAMERA_BIND='MiningAwayFleetCamera'
local INPUT_BIND='MiningAwayFleetMovement'
local function ease(t)
 t=math.clamp(t,0,1)
 return t*t*(3-2*t)
end

local function block(parent,name,size,cf,color,material)
 local part=Instance.new('Part')
 part.Name=name;part.Size=size;part.CFrame=cf;part.Color=color;part.Material=material
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.CastShadow=false;part.Parent=parent
 return part
end

local function cloneRig(source,originalParts)
 if not source then return end
 local archivable=source.Archivable
 source.Archivable=true;local copy=source:Clone();source.Archivable=archivable
 if not copy then return end
 local originals=source:GetDescendants()
 local descendants=copy:GetDescendants()
 local sameOrder=#originals==#descendants
 for i,item in ipairs(descendants) do
  if item:IsA('LuaSourceContainer') or item:IsA('Sound') or item:IsA('Tool')
   or item:IsA('BillboardGui') or item:IsA('SurfaceGui') or item:IsA('Highlight') then item:Destroy()
  elseif item:IsA('BasePart') and sameOrder and originalParts and originalParts[originals[i]]==nil then item:Destroy()
  elseif item:IsA('BasePart') then
   item.Anchored=true;item.CanCollide=false;item.CanTouch=false;item.CanQuery=false;item.LocalTransparencyModifier=0
   if sameOrder and originalParts then
    local opacity=originalParts[originals[i]]
    if opacity~=nil then item.Transparency=opacity end
   end
  elseif item:IsA('ParticleEmitter') or item:IsA('Beam') or item:IsA('Trail') or item:IsA('Light') then item.Enabled=false
  elseif item:IsA('Humanoid') then item.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
 end
 return copy
end

local function crewFor(profile)
 local crew,seen={},{}
 for _,group in ipairs({profile.activeFleet or profile.fleet,profile.fleet}) do
  for _,drone in ipairs(group) do
   if not seen[drone.id] then
    seen[drone.id]=true
    table.insert(crew,drone)
   end
  end
 end
 return crew
end

local function applies(card,drone)
 local effect=card.effects or {}
 if not drone then return card.scope=='Player' or (effect.capacity or 0)>0 end
 if card.scope=='Individual' then return card.targetDroneId==drone.id end
 local role=DroneRoles.canonical(drone.role or drone.type)
 local worker=DroneRoles.isWorker(role)
 if card.scope=='Color' and card.type~=drone.type then return false end
 if card.scope=='Player' then
  if effect.batchPress or effect.denserPacking or effect.compactor then return role=='Compactor' end
  if effect.cargoRack or effect.fullAuto then return role=='Courier' end
  if effect.orbitalLaser then return role=='Orbiter' end
  if effect.scrapSwarm then return role=='Scrapper' end
  if effect.fieldCharge or effect.shiftRelay then return worker end
  return false
 end
 if effect.speed or effect.health or effect.reduction or effect.shield then return true end
 if effect.mining or effect.startup or effect.yield or effect.reclaim or effect.earlyDrop
  or effect.geode or effect.plotAuto or effect.battery or effect.combat or effect.rate or effect.range
  or effect.crit or effect.splash or effect.finisher or effect.salvage then return worker end
 if effect.deepCut or effect.liveWire or effect.fork or effect.aftershock then return DroneRoles.isMiner(role) end
 return card.scope=='Fleet' or card.scope=='Tradeoff' or card.scope=='Color'
end

function FleetView.new(options)
 local self=setmetatable({options=options,rigs={},poses={},rest={},muted={},nameplates={}},FleetView)
 local U=options.U
 local root=U.frame(options.parent,UDim2.fromScale(0,0),UDim2.fromScale(1,1))
 root.Name='FleetInspection';root.ZIndex=65;root.Active=true;root.Visible=false;root.BackgroundTransparency=1
 local tint=U.frame(options.parent,UDim2.fromScale(0,0),UDim2.fromScale(1,1),FOG)
 tint.Name='FleetCameraFade';tint.BackgroundTransparency=1;tint.ZIndex=90;tint.Active=true;tint.Visible=false
 self.root=root;self.tint=tint
 local header=U.frame(root,UDim2.fromOffset(12,12),UDim2.new(1,-72,0,58),U.palette.ink)
 header.BackgroundTransparency=.21;U.corner(header,8)
 self.title=U.text(header,UDim2.fromOffset(12,0),UDim2.new(1,-24,0,27),'Crew',23,WHITE,true)
 self.description=U.text(header,UDim2.fromOffset(12,26),UDim2.new(1,-24,0,30),'',15,WHITE)
 self.back=options.button(root,UDim2.new(1,-54,0,12),UDim2.fromOffset(44,44),'×',options.onBack,U.palette.paper)
 self.back.Name='CloseFleetInspection';self.back.TextSize=29
 self.prev=options.button(root,UDim2.new(.5,-151,1,-59),UDim2.fromOffset(52,54),'‹',function() self:cycle(-1) end,U.palette.paper)
 self.next=options.button(root,UDim2.new(.5,98,1,-59),UDim2.fromOffset(52,54),'›',function() self:cycle(1) end,U.palette.paper)
 self.prev.Name='PreviousDrone';self.next.Name='NextDrone';self.prev.TextSize=43;self.next.TextSize=43
 self.target=U.text(root,UDim2.new(.5,0,1,-107),UDim2.new(1,-125,0,30),'',19,WHITE,true)
 self.target.AnchorPoint=Vector2.new(.5,0);self.target.TextXAlignment=Enum.TextXAlignment.Center
 self.target.TextStrokeColor3=U.palette.ink;self.target.TextStrokeTransparency=.25;self.target.TextScaled=true
 local targetSize=Instance.new('UITextSizeConstraint');targetSize.MinTextSize=13;targetSize.MaxTextSize=19;targetSize.Parent=self.target
 local stack=Instance.new('ScrollingFrame')
 stack.Name='InstalledCards';stack.AnchorPoint=Vector2.new(1,.5);stack.Position=UDim2.new(1,-12,.49,0)
 stack.Size=UDim2.new(.29,0,.43,0);stack.BackgroundTransparency=1;stack.BorderSizePixel=0
 stack.CanvasSize=UDim2.fromOffset(0,0);stack.AutomaticCanvasSize=Enum.AutomaticSize.Y;stack.ScrollBarThickness=4
 stack.ZIndex=root.ZIndex+1;stack.Parent=root
 local bound=Instance.new('UISizeConstraint');bound.MinSize=Vector2.new(106,56);bound.MaxSize=Vector2.new(232,242);bound.Parent=stack
 local list=Instance.new('UIListLayout');list.Padding=UDim.new(0,2);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=stack
 self.stack=stack
 self.install=options.button(root,UDim2.new(.5,0,1,-12),UDim2.fromOffset(230,44),'Install upgrade',function()
  local target=self.targets and self.targets[self.index]
  self.options.onInstall(target)
 end,U.palette.mineral)
 self.install.Name='InstallOnTarget';self.install.AnchorPoint=Vector2.new(.5,1)
 self.status=U.text(root,UDim2.new(.5,0,1,-12),UDim2.new(1,-26,0,42),'',16,WHITE,true)
 self.status.AnchorPoint=Vector2.new(.5,1);self.status.TextXAlignment=Enum.TextXAlignment.Center
 return self
end

function FleetView:isOpen() return self.root.Visible end

function FleetView:buildStage(character,profile)
 local scene=Instance.new('Folder');scene.Name='LocalFleetStage';scene.Parent=self.options.world
 self.scene=scene
 block(scene,'Baseplate',Vector3.new(440,1,440),CFrame.new(STAGE-Vector3.yAxis*.5),Color3.fromRGB(82,87,113),Enum.Material.SmoothPlastic)
 for i=-12,12 do
  local line=Color3.fromRGB(86,93,118)
  block(scene,'Grid',Vector3.new(.07,.01,120),CFrame.new(STAGE+Vector3.new(i*5,0,0)),line,Enum.Material.SmoothPlastic)
  block(scene,'Grid',Vector3.new(120,.01,.07),CFrame.new(STAGE+Vector3.new(0,0,i*5)),line,Enum.Material.SmoothPlastic)
 end
 for _,side in ipairs({-1,1}) do
  block(scene,'Horizon',Vector3.new(440,220,1),CFrame.new(STAGE+Vector3.new(0,70,side*128)),FOG,Enum.Material.SmoothPlastic)
  block(scene,'Horizon',Vector3.new(1,220,440),CFrame.new(STAGE+Vector3.new(side*128,70,0)),FOG,Enum.Material.SmoothPlastic)
  local lamp=block(scene,'StageLight',Vector3.one,CFrame.new(STAGE+Vector3.new(side*9,8,side*5)),WHITE,Enum.Material.SmoothPlastic)
  lamp.Transparency=1
  local light=Instance.new('PointLight');light.Range=46;light.Brightness=1.9
  light.Color=side==1 and Color3.fromRGB(136,203,255) or Color3.fromRGB(216,161,255);light.Parent=lamp
 end
 local focus=Instance.new('DepthOfFieldEffect')
 focus.Name='FleetDepthOfField';focus.InFocusRadius=16;focus.FarIntensity=.76;focus.NearIntensity=.16;focus.Parent=Lighting
 self.focus=focus
 local avatar=cloneRig(character)
 if avatar then
  local root=avatar:FindFirstChild('HumanoidRootPart')
  if root then avatar.PrimaryPart=root end
  local original=character:FindFirstChild('HumanoidRootPart')
  local pose=CFrame.new(STAGE)*(original and original.CFrame.Rotation or CFrame.new())
  avatar:PivotTo(pose)
  local bounds,size=avatar:GetBoundingBox()
  avatar:PivotTo(pose+Vector3.yAxis*(STAGE.Y-bounds.Position.Y+size.Y*.5+.02))
  avatar.Name='CrewOwner';avatar.Parent=scene;self.avatar=avatar
  self.stageOffset=(root and root.Position or avatar:GetPivot().Position)-(original and original.Position or character:GetPivot().Position)
 end
 self.crew=crewFor(profile)
 local template=Storage:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
 for _,drone in ipairs(self.crew) do
  local original=self.options.resolve(drone.id)
  local rig=original and cloneRig(original.view,original.parts) or cloneRig(template)
  if rig then
   if not original then
    local role=drone.role or drone.type
    if role~='Striker' then self.options.droneConfig.decorate(rig,role,nil,true) end
    self.options.droneConfig.fitBody(rig,role)
   end
   rig.Name=drone.name or 'Drone';rig.Parent=scene;self.rigs[drone.id]=rig
   local label=Instance.new('BillboardGui');label.Name='CrewName';label.Size=UDim2.fromOffset(154,25)
   label.AlwaysOnTop=true;label.LightInfluence=0;label.MaxDistance=120;label.StudsOffsetWorldSpace=Vector3.yAxis*1.75
   label.Adornee=rig.PrimaryPart or rig:FindFirstChildWhichIsA('BasePart',true);label.Parent=rig
   local name=self.options.U.text(label,UDim2.fromScale(0,0),UDim2.new(1,0,0,19),rig.Name,13,WHITE,true)
   name.TextXAlignment=Enum.TextXAlignment.Center;name.TextStrokeTransparency=.28;name.TextStrokeColor3=Color3.new()
   local badges=self.options.U.frame(label,UDim2.new(1,-49,0,5),UDim2.fromOffset(49,11))
   badges.BackgroundTransparency=1
   self.nameplates[drone.id]={row=badges,name=name}
  end
 end
end

function FleetView:arrange()
 local count=#self.crew
 local span=math.min(11,math.max(4,count*.8))
 self.span=span
 for i,drone in ipairs(self.crew) do
  local rig=self.rigs[drone.id]
  if rig then
   local slot=i-1
   local theta=slot*2*math.pi/count
   local lane=math.floor(slot/20)
   local x,z=math.sin(theta)*(span+lane*1.5),math.cos(theta)*(span*.79+lane*1.5)
   local pose=CFrame.new(STAGE+Vector3.new(x,3.5+lane*1.7,z))*CFrame.Angles(0,math.pi,0)
   self.rest[rig]=pose;self.poses[rig]=pose;rig:PivotTo(pose)
  end
 end
 self.aim=STAGE+Vector3.yAxis*3.2
end

local function muteRig(self,rig,muted)
 if not rig or self.muted[rig]==muted then return end
 self.muted[rig]=muted
 for _,item in ipairs(rig:GetDescendants()) do
  if item:IsA('BasePart') or item:IsA('Decal') or item:IsA('Texture') then
   local part=item:IsA('BasePart')
   local original=item:GetAttribute('InspectionColor')
   if not original then
    original=part and item.Color or item.Color3
    item:SetAttribute('InspectionColor',original)
   end
   local value=original.R*.21+original.G*.72+original.B*.07
   local color=muted and Color3.new(value,value,value) or original
   if part then
    item.Color=color;item.LocalTransparencyModifier=muted and .5 or 0
   else
    item.Color3=color;item.LocalTransparencyModifier=muted and .5 or 0
   end
  end
 end
end

local function highlight(model,active)
 if not model then return end
 local effect=model:FindFirstChild('SelectedTarget')
 if not active then if effect then effect:Destroy() end;return end
 if not effect then
  effect=Instance.new('Highlight');effect.Name='SelectedTarget';effect.Adornee=model
  effect.DepthMode=Enum.HighlightDepthMode.Occluded;effect.OutlineColor=Color3.new()
  effect.FillColor=WHITE;effect.OutlineTransparency=0;effect.FillTransparency=.6;effect.Parent=model
 end
end

local function updateNameplate(U,plate,profile,drone,muted,selected)
 if not plate then return end
 plate.name.TextTransparency=muted and .43 or 0
 local entries,key={},{}
 for _,card in ipairs(profile.run.cards or {}) do
  if applies(card,drone) then
   table.insert(entries,card)
   table.insert(key,(card.cardId or '')..':'..tostring(card.rarity)..':'..tostring(card.level or 1))
  end
 end
 local fingerprint=table.concat(key,'|')..':'..tostring(muted)..':'..tostring(selected)
 if plate.key==fingerprint then return end
 plate.key=fingerprint
 plate.row:ClearAllChildren()
 local count=math.min(#entries,4)
 plate.name.Size=UDim2.new(1,count>0 and -(12*count+5+(#entries>count and 18 or 0)) or 0,0,19)
 plate.name.TextTruncate=Enum.TextTruncate.AtEnd;plate.name.TextWrapped=false
 plate.row.Position=UDim2.new(1,-(12*count+1+(#entries>count and 18 or 0)),0,5)
 plate.row.Visible=count>0
 for i=1,count do
  local tint=CardView.rarityColor(entries[i])
  local marker=U.frame(plate.row,UDim2.fromOffset((i-1)*12+2,1),UDim2.fromOffset(8,8),tint)
  marker.Name='UpgradeMark';marker.Rotation=45;marker.BackgroundTransparency=muted and .50 or 0
  U.corner(marker,2);U.stroke(marker,Color3.new(),selected and 2 or 1)
 end
 if #entries>count then
  local more=U.text(plate.row,UDim2.fromOffset(count*12+1,-2),UDim2.fromOffset(29,14),'+'..(#entries-count),11,WHITE,true)
  more.TextTransparency=muted and .50 or 0
 end
end

function FleetView:refresh(profile,available,reason,busy,notice)
 if not self:isOpen() then return end
 local U=self.options.U
 local picked=self.targets[self.index]
 local choice=self.choice
 self.title.Text=choice and choice.title or 'Your crew'
 self.title.TextColor3=choice and CardView.rarityColor(choice) or WHITE
 self.description.Text=choice and CardView.summary(choice):gsub('\n',' ') or 'Browse your drones and installed upgrades'
 local targetName=picked and (picked.name or picked.role or picked.type)
 if picked and choice and Workshop.isHardware(choice) then
  targetName=CardView.fitText(choice,picked,profile.droneStats and profile.droneStats[picked.id],false):gsub('\n','  ·  ')
 end
 self.target.Text=targetName or (choice and CardView.terms(choice):match('^[^·\n]+') or 'Your upgrades')
 self.prev.Visible=#self.targets>1;self.next.Visible=self.prev.Visible
 U.setEnabled(self.prev,not busy);U.setEnabled(self.next,not busy)
 local validTarget=not Workshop.isHardware(choice or {}) or picked~=nil
 self.install.Visible=choice~=nil and validTarget and (available or busy)
 self.install.Text=busy and 'Installing…' or 'Install upgrade'
 U.setEnabled(self.install,available and not busy and validTarget)
 self.status.Visible=choice~=nil and (notice~=nil or not self.install.Visible)
 self.status.Position=UDim2.new(.5,0,1,self.install.Visible and -59 or -12)
 self.status.Text=notice or (choice and reason) or ''
 if self.status.Text=='' and self.status.Visible and choice and Workshop.isHardware(choice) and not picked then
  self.status.Text='No compatible miner available'
 end
 local focusChoice=choice and not Workshop.isHardware(choice)
 highlight(self.avatar,not picked and (not focusChoice or applies(choice,nil)))
 local eligible={}
 if choice then
  for _,drone in ipairs(self.targets) do eligible[drone.id]=true end
 end
 for _,drone in ipairs(self.crew) do
  local rig=self.rigs[drone.id]
  local active=picked and picked.id==drone.id
  local affected=focusChoice and applies(choice,drone)
  if rig then
   highlight(rig,active or not picked and affected)
   local muted=choice~=nil and not (eligible[drone.id] or affected)
   muteRig(self,rig,muted)
   updateNameplate(U,self.nameplates[drone.id],profile,drone,muted,active)
   self.poses[rig]=self.rest[rig]+Vector3.yAxis*(active and 4 or 0)
  end
 end
 local cards={}
 local key={picked and picked.id or '',choice and choice.cardId or ''}
 for _,card in ipairs(profile.run.cards or {}) do
  local shown=applies(card,picked)
  if not picked and focusChoice and not applies(choice,nil) then
   for _,drone in ipairs(self.crew) do
    if applies(choice,drone) and applies(card,drone) then shown=true;break end
   end
  end
  if shown then
   table.insert(cards,card)
   table.insert(key,(card.cardId or card.title or '')..':'..tostring(card.level or 1)..':'..(card.targetDroneId or ''))
  end
 end
 key=table.concat(key,'|')
 if self.stackKey==key then return end
 self.stackKey=key;self.stack.CanvasPosition=Vector2.zero
 for _,row in ipairs(self.stack:GetChildren()) do if row:IsA('Frame') then row:Destroy() end end
 if #cards==0 then
  local row=U.frame(self.stack,UDim2.fromOffset(0,0),UDim2.new(1,-6,0,29),U.palette.ink)
  row.BackgroundTransparency=.24;U.corner(row,4)
  U.text(row,UDim2.fromOffset(9,0),UDim2.new(1,-18,1,0),'No installed cards',15,WHITE)
 end
 for i,card in ipairs(cards) do
  local rarity=CardView.rarityColor(card)
  local row=U.frame(self.stack,UDim2.fromOffset(0,0),UDim2.new(1,-6,0,28),rarity)
  row.Name='InstalledCard';row.LayoutOrder=i;U.corner(row,4)
  local count=(card.level or 1)>1 and '  ×'..card.level or ''
  local title=U.text(row,UDim2.fromOffset(9,0),UDim2.new(1,-18,1,0),(card.title or 'Upgrade')..count,16,U.palette.ink,true)
  title.TextTruncate=Enum.TextTruncate.AtEnd;title.TextWrapped=false
 end
end

function FleetView:cycle(delta)
 if not self:isOpen() or #self.targets<2 or not self.prev.Active then return end
 self.index=(self.index-1+delta)%#self.targets+1
 self.options.onTarget()
end

function FleetView:open(profile,choice,targets)
 local player=self.options.player
 local character=player.Character
 local camera=workspace.CurrentCamera
 if not character or not camera then return false end
 local humanoid=character:FindFirstChildOfClass('Humanoid')
 if not humanoid or humanoid.Health<=0 then return false end
 self:close(true)
 self.choice=choice;self.camera=camera;self.character=character
 self.cameraState={camera.CameraType,camera.CameraSubject,camera.CFrame,camera.Focus,camera.FieldOfView}
 self:buildStage(character,profile)
 self.targets=targets or self.crew;self.index=1
 self.stackKey=nil;self:arrange()
 local quiet=CardView.reducedMotion();local elapsed=quiet and ZOOM_TIME or 0
 local covered=quiet
 local shift=self.stageOffset or STAGE-character:GetPivot().Position
 local startFrame=self.cameraState[3]+shift
 local startFocus=self.cameraState[4]+shift
 local forward=startFrame.LookVector
 local distance=math.max(.5,(startFocus.Position-startFrame.Position):Dot(forward))
 local fieldOfView=self.cameraState[5]
 local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y)
 local halfHeight=math.tan(math.rad(fieldOfView*.5))
 local fitDistance=(self.span+3)/math.max(.17,halfHeight*math.min(1,aspect)*.8)
 local finishDistance=math.max(distance*.77,fitDistance)
 local finishFov=finishDistance>distance*.77 and fieldOfView*.94 or fieldOfView
 self.root.Visible=true
 local function cover(opacity)
  self.tint.BackgroundTransparency=1-opacity
  self.tint.Visible=opacity>0
 end
 cover(0)
 if not quiet then self.focus.Enabled=false end
 self.originalSelection=GuiService.SelectedObject
 if UIS.GamepadEnabled and UIS:GetLastInputType().Name:match('^Gamepad') then GuiService.SelectedObject=self.back end
 camera.CameraType=Enum.CameraType.Scriptable
 camera:SetAttribute('FleetCamera',true)
 Context:BindActionAtPriority(INPUT_BIND,function() return Enum.ContextActionResult.Sink end,false,
  Enum.ContextActionPriority.High.Value,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
  Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
 RunService:BindToRenderStep(CAMERA_BIND,Enum.RenderPriority.Camera.Value+5,function(dt)
  if workspace.CurrentCamera~=camera or player.Character~=character or humanoid.Health<=0 then
   self.options.onAbort();return
  end
  elapsed+=math.min(dt,.1)
  if elapsed>=ZOOM_TIME then
   local motion=quiet and 1 or 1-math.exp(-13*math.min(dt,.1))
   for rig,pose in pairs(self.poses) do
    local current=rig:GetPivot()
    if (current.Position-pose.Position).Magnitude>.005 then rig:PivotTo(current:Lerp(pose,motion)) end
   end
  end
  local lead=forward*math.min(1.6,distance*.08)
  if not covered then
   local t=ease(elapsed/COVER_TIME)
   camera.CFrame=self.cameraState[3]+lead*t;camera.Focus=self.cameraState[4]
   camera.FieldOfView=fieldOfView
   cover(t)
   if t>=1 then elapsed=COVER_TIME;covered=true end
   return
  end
  self.focus.Enabled=true
  local t=ease((elapsed-COVER_TIME)/(ZOOM_TIME-COVER_TIME))
  local aim=startFocus:Lerp(CFrame.new(self.aim)*startFocus.Rotation,t)
  local from=(startFrame.Position+(quiet and Vector3.zero or lead)):Lerp(self.aim-forward*finishDistance,t)
  camera.CFrame=CFrame.new(from)*startFrame.Rotation;camera.Focus=aim
  camera.FieldOfView=fieldOfView+(finishFov-fieldOfView)*t
  self.focus.FocusDistance=math.max(.5,(aim.Position-from):Dot(forward))
  cover(quiet and 0 or 1-ease((elapsed-COVER_TIME)/REVEAL_TIME))
 end)
 return true
end

function FleetView:close(immediate)
 if self.finishClose then
  if immediate then self.finishClose() end
  return
 end
 if not self:isOpen() then return end
 local camera,state=self.camera,self.cameraState
 local character=self.character
 local function restore()
  if camera==workspace.CurrentCamera and self.options.player.Character==character then
   if state[2] and state[2].Parent then camera.CameraSubject=state[2] end
   camera.CFrame=state[3];camera.Focus=state[4];camera.FieldOfView=state[5];camera.CameraType=state[1]
  end
 end
 local function finish()
  RunService:UnbindFromRenderStep(CAMERA_BIND);Context:UnbindAction(INPUT_BIND)
  if self.scene then restore();self.scene:Destroy();self.focus:Destroy() end
  camera:SetAttribute('FleetCamera',nil)
  self.tint.Visible=false;self.finishClose=nil
  self.stageOffset=nil;self.scene=nil;self.focus=nil;self.avatar=nil;self.choice=nil
  self.camera=nil;self.cameraState=nil;self.character=nil
 end
 self.finishClose=finish
 local selected=GuiService.SelectedObject
 if selected and selected:IsDescendantOf(self.root) then
  GuiService.SelectedObject=self.originalSelection and self.originalSelection.Parent and self.originalSelection or nil
 end
 self.root.Visible=false;self.choice=nil
 table.clear(self.rigs);table.clear(self.poses);table.clear(self.rest);table.clear(self.muted);table.clear(self.nameplates)
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 if immediate or CardView.reducedMotion() or camera~=workspace.CurrentCamera or self.options.player.Character~=character or not humanoid or humanoid.Health<=0 then
  finish();return
 end
 RunService:UnbindFromRenderStep(CAMERA_BIND)
 local elapsed=0
 local covered=false
 local startOpacity=1-self.tint.BackgroundTransparency
 self.tint.Visible=true
 RunService:BindToRenderStep(CAMERA_BIND,Enum.RenderPriority.Camera.Value+5,function(dt)
  if camera~=workspace.CurrentCamera or self.options.player.Character~=character or humanoid.Health<=0 then finish();return end
  elapsed+=math.min(dt,.1)
  if not covered then
   self.tint.BackgroundTransparency=(1-startOpacity)*(1-ease(elapsed/COVER_TIME))
   if elapsed>=COVER_TIME then elapsed=COVER_TIME;covered=true end
  else
   if self.scene then
    restore();self.scene:Destroy();self.focus:Destroy();self.scene=nil
    Context:UnbindAction(INPUT_BIND)
   end
   self.tint.BackgroundTransparency=ease((elapsed-COVER_TIME)/REVEAL_TIME)
   if elapsed>=COVER_TIME+REVEAL_TIME then finish() end
  end
 end)
end

function FleetView:destroy()
 self:close(true);self.tint:Destroy();self.root:Destroy()
end
return FleetView
