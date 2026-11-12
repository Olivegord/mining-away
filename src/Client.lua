-- Presentation and bounded intent only. Gameplay never reads these local viewmodels.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local TweenService=game:GetService('TweenService')
local player=Players.LocalPlayer
local world=workspace:WaitForChild('MiningAway')
local command=RS:WaitForChild('MiningAway'):WaitForChild('Command')
local localFX=Instance.new('Folder');localFX.Name='MiningAwayPresentation';localFX.Parent=workspace
local soundscape=Soundscape.new(localFX)
local presentation=Presentation.new({parent=localFX,audio=soundscape})
local rockDamage=RockDamage.new()
-- Startup is silent. The established cut and contact cues remain spatial.
soundscape.chargeFromRenderer=true
BeamVFX.onCue=function(kind,position,now)
 if kind=='launch' then presentation:kick(position,.028,now) end
end
local pickupView=PickupView.new(world,localFX,soundscape,CrystalImpactView.reducedMotion)
local roleEffectView=RoleEffectView.new(soundscape)
rockDamage.feedback=CrystalImpactView.new(localFX,soundscape,function(position,strength,now)
 presentation:crystalKick(position,strength,now)
end)
local previousShake=CFrame.new();local shakeCamera=nil
local orbitalBurns={};local roleAudio={};local impactCues=setmetatable({},{__mode='k'})
RunService:BindToRenderStep('MiningAwayCameraRestore',Enum.RenderPriority.Camera.Value-1,function()
 if shakeCamera and workspace.CurrentCamera==shakeCamera then shakeCamera.CFrame=shakeCamera.CFrame*previousShake:Inverse() end
 previousShake=CFrame.new();shakeCamera=nil
end)
RunService:BindToRenderStep('MiningAwayCameraFeedback',Enum.RenderPriority.Camera.Value+1,function()
 local camera=workspace.CurrentCamera
 local now=workspace:GetServerTimeNow()
 for source,name in pairs(roleAudio) do
  if not source.Parent or now>(source:GetAttribute('AudioUntil') or 0) then soundscape:stopLoop(source);roleAudio[source]=nil
  else
   local progress=math.clamp((now-(source:GetAttribute('AudioAt') or now))/math.max(.1,(source:GetAttribute('AudioUntil') or now)-(source:GetAttribute('AudioAt') or now)),0,1)
   soundscape:setLoop(source,name,source.Position,.65+.35*progress,.75+.55*progress)
  end
 end
 for source,record in pairs(orbitalBurns) do
  if not source.Parent then soundscape:stopLoop(source);record.connection:Disconnect();orbitalBurns[source]=nil
  else
   local ended=source:GetAttribute('EndedAt')~=nil
   local active=not ended and now-(source:GetAttribute('ContactAt') or 0)<.3
   if active then soundscape:setLoop(source,'orbital_hum',source:GetAttribute('Position'),1,1)
   else soundscape:stopLoop(source) end
   local visibility=ended and 'fading' or active and 'active' or 'stale'
   if record.visibility~=visibility then
    record.visibility=visibility
    for _,part in ipairs(record.effects) do
     if part:IsA('BasePart') then part.LocalTransparencyModifier=(ended or active) and 0 or 1
     elseif part:IsA('ParticleEmitter') then part.Enabled=active end
    end
   end
  end
 end
 if camera and not CrystalImpactView.reducedMotion() then
  previousShake=presentation:cameraOffset(workspace:GetServerTimeNow());shakeCamera=camera;camera.CFrame=camera.CFrame*previousShake
 end
end)
local function roleImpact(source)
 if source:IsA('BasePart') then
  local at=source:GetAttribute('AudioAt');local now=workspace:GetServerTimeNow()
  local loop=source:GetAttribute('AudioLoop')
  if (loop=='orbital_charge' or loop=='swarm_charge') and AudioFeedback.fresh(at,now,2.6) then roleAudio[source]=loop end
  local cue=source:GetAttribute('AudioCue')
  if cue=='plant' and AudioFeedback.fresh(at,now,.35) then soundscape:play(cue,source.Position) end
 end
 if source:IsA('Folder') and source:GetAttribute('OrbitalBurn') then
  if orbitalBurns[source] then return end
  local record={effects={}}
  local function track(part)
   if part:IsA('BasePart') or part:IsA('ParticleEmitter') then table.insert(record.effects,part);record.visibility=nil end
  end
  for _,part in ipairs(source:GetDescendants()) do track(part) end
  record.connection=source.DescendantAdded:Connect(track)
  orbitalBurns[source]=record
  local now=workspace:GetServerTimeNow()
  local position=source:GetAttribute('Position')
  if position and AudioFeedback.fresh(source:GetAttribute('StartedAt'),now,.35) then
   soundscape:play('orbital',position)
   if not CrystalImpactView.reducedMotion() then presentation:crystalKick(position,.85,now) end
  end
 end
 if source:IsA('BasePart') and source:GetAttribute('MiningImpact') then
  local now=workspace:GetServerTimeNow();local at=source:GetAttribute('ImpactAt') or 0
  if now>=at and now-at<=.35 and not impactCues[source] then
   impactCues[source]=true
   local impact=source:GetAttribute('MiningImpact')
   if impact=='BreakerContact' then
    presentation:kick(source.Position,.09,now)
    soundscape:play('breaker_contact',source.Position)
   else
    presentation:kick(source.Position,impact=='Orbital' and .15 or .14,now)
    soundscape:play(impact=='Orbital' and 'orbital' or impact=='Breaker' and 'breaker_fracture' or 'mining',source.Position)
   end
  end
 end
end
local impactConnection=workspace.DescendantAdded:Connect(function(source)
 -- Cosmetic parts are parented beneath this local container; none carry
 -- authoritative role events. Do not schedule a task for every lens fragment.
 if source:IsDescendantOf(localFX) then return end
 if source:IsA('BasePart') or source:IsA('Folder') then task.defer(roleImpact,source) end
end)
local existingRoleFX=workspace:FindFirstChild('DroneRoleClientEffects')
if existingRoleFX then for _,source in ipairs(existingRoleFX:GetChildren()) do roleImpact(source) end end

local drones,resources,resourceIndex,turrets,connections={},{},{},{},{}
local droneIndex={}
local turretIndex={}
local hiddenParts={}
local pendingDroneSources={}
local templateRetryQueued=false
local profile=nil
local logisticsView=nil
local toolView=nil
local U=Interface
local palette=U.palette
local DroneConfig=require(RS:WaitForChild('Shared'):WaitForChild('DroneConfig'))
local TacticalHUD=require(RS.Shared:WaitForChild('TacticalHUD'))
local colors={Blue=Color3.fromRGB(99,198,246),Red=Color3.fromRGB(243,117,112),Green=Color3.fromRGB(122,219,163),Dart=Color3.fromRGB(87,220,255),Striker=Color3.fromRGB(255,210,86),Medic=Color3.fromRGB(99,255,164),Charger=Color3.fromRGB(255,112,72)}
for name,definition in pairs(DroneConfig.Types) do colors[name]=definition.Color end
local gui=Instance.new('ScreenGui');gui.Name='MiningAwayHUD';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=12;gui.Parent=player:WaitForChild('PlayerGui')
soundscape:bindUI(gui)
local safeRoot=U.frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1));safeRoot.Name='SafeContent';safeRoot.BackgroundTransparency=1
local historical={ScreenGui=true,IngameGui=true,lowPolyUI=true}
local function isolate(g) if g:IsA('ScreenGui') and historical[g.Name] then g.Enabled=false end end
for _,g in ipairs(gui.Parent:GetChildren()) do isolate(g) end
local function connect(signal,callback) local c=signal:Connect(callback);table.insert(connections,c);return c end
connect(gui.Parent.ChildAdded,isolate)
local function restoreCamera(ch)
 local hum=ch:WaitForChild('Humanoid',10)
 if hum and workspace.CurrentCamera then workspace.CurrentCamera.CameraType=Enum.CameraType.Custom;workspace.CurrentCamera.CameraSubject=hum end
end
connect(player.CharacterAdded,restoreCamera);if player.Character then task.spawn(restoreCamera,player.Character) end
local frame,label,corner=U.frame,U.text,U.corner
local function button(parent,pos,size,text,callback,color)
 local b=U.button(parent,pos,size,text,function() soundscape:play('click');if callback then callback() end end,color)
 b:SetAttribute('EnabledColor',color or palette.mineral);return b
end
local function enableAction(b,enabled) U.setEnabled(b,enabled) end
local openOffer,openPrestige,openFleet,openRunCards,openShop,openStars
local noticeUntil=0
local menuStation=nil
local hud=U.panel(safeRoot,UDim2.fromOffset(16,12),UDim2.fromOffset(290,64));hud.Name='Resources';hud.Active=true
local saveLabel=label(safeRoot,UDim2.new(1,-188,0,12),UDim2.fromOffset(172,22),'',16,palette.muted,true);saveLabel.Name='SaveStatus';saveLabel.Visible=false;saveLabel.TextXAlignment=Enum.TextXAlignment.Right
local cargoText=label(hud,UDim2.fromOffset(50,34),UDim2.new(1,-158,0,18),'Cargo 0 / 10 slots',11,palette.muted,true)
local cargoTrack=frame(hud,UDim2.fromOffset(50,53),UDim2.new(1,-164,0,4),palette.paper);corner(cargoTrack,2)
local cargoFill=frame(cargoTrack,UDim2.fromScale(0,0),UDim2.fromScale(0,1),palette.mineral);corner(cargoFill,3)
local toast=U.panel(safeRoot,UDim2.fromOffset(0,170),UDim2.fromOffset(420,50),palette.panel,12);toast.Name='Feedback';toast.ZIndex=80;toast.Visible=false
local notice=label(toast,UDim2.fromOffset(14,6),UDim2.new(1,-28,1,-12),'',13,palette.text,true);notice.TextXAlignment=Enum.TextXAlignment.Center
local recall=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(118,44),'Recall [R]',function() if not (logisticsView and logisticsView:recall()) then command:FireServer('Recall') end end,Color3.fromRGB(66,177,91));recall.Name='Recall'
local context=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(420,72),palette.panel,14);context.Name='ContextAction';context.Active=true;context.Visible=false
local modal=frame(safeRoot,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(3,9,18));modal.Name='MenuLayer';modal.BackgroundTransparency=.22;modal.Visible=false;modal.ZIndex=20;modal.Active=true
local fleetView
local function inspectingFleet() return fleetView and fleetView:isOpen() end
local function menusVisible() return modal.Visible or inspectingFleet() or (logisticsView and logisticsView:isOpen()) end
local selectorView=SelectorView.new({world=world,player=player,parent=localFX,command=command,profile=function() return profile end,
 hidden=function() return menusVisible() or (logisticsView and logisticsView.selected~=nil) or (toolView and toolView:selected()~=nil) end})
local sheet=U.panel(modal,UDim2.fromOffset(12,12),UDim2.fromOffset(1010,664),palette.panel,20);sheet.Name='MenuSheet';sheet.ZIndex=21
local sheetScale=Instance.new('UIScale');sheetScale.Parent=sheet
local modalEmblem=U.icon(sheet,'cards',UDim2.fromOffset(20,19),UDim2.fromOffset(54,54),palette.mineral)
local modalTitle=label(sheet,UDim2.fromOffset(90,18),UDim2.new(1,-158,0,39),'Build your next adventure',30,palette.text,true)
local modalSubtitle=label(sheet,UDim2.fromOffset(24,66),UDim2.new(1,-48,0,32),'',12,palette.muted)
local close=button(sheet,UDim2.new(1,-62,0,16),UDim2.fromOffset(44,44),'X',function() modal.Visible=false end,palette.danger);close.Name='CloseMenu';close.TextColor3=palette.white;close:FindFirstChildOfClass('UIGradient').Enabled=true
local body=Instance.new('ScrollingFrame');body.Name='MenuContent';body.Position=UDim2.fromOffset(24,112);body.Size=UDim2.new(1,-48,1,-136);body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=4;body.ScrollBarImageColor3=palette.muted;body.CanvasSize=UDim2.fromScale(0,0);body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.ZIndex=22;body.Parent=sheet
-- Native touch controls otherwise draw over the physical offer surface.
local previousTouchEnabled=nil
local function syncModalTouch()
 local controls=player.PlayerGui:FindFirstChild('TouchGui');if not controls then return end
 if menusVisible() then if previousTouchEnabled==nil then previousTouchEnabled=controls.Enabled end;controls.Enabled=false
 elseif previousTouchEnabled~=nil then controls.Enabled=previousTouchEnabled;previousTouchEnabled=nil end
end
connect(modal:GetPropertyChangedSignal('Visible'),syncModalTouch)
connect(player.PlayerGui.ChildAdded,function(child) if child.Name=='TouchGui' then syncModalTouch() end end)
local modalMode,modalSize=nil,nil
local actionPending=nil
local offerViews={};local offerIdentity=nil;local offerRenderSize=nil
local offerUI={}
local function clearBody()
 table.clear(offerViews);offerIdentity=nil;offerRenderSize=nil
 for _,x in ipairs(body:GetChildren()) do x:Destroy() end
 body.CanvasPosition=Vector2.zero
end
local function tx() return Http:GenerateGUID(false) end
local function send(action,data)
 if not profile or not profile.run or actionPending or profile.pendingTransaction then return false end
 data=data or {};data.txId=tx();data.runId=profile.run.id
 actionPending={kind=action,at=os.clock(),txId=data.txId,runId=profile.run.id,offerId=profile.run.pendingOffer and profile.run.pendingOffer.id,upgradeId=data.upgradeId,level=data.level,index=data.index}
 if action=='ChooseCard' then offerUI.claim=actionPending end
 command:FireServer(action,data);return true
end
local function comma(n) local s=tostring(math.floor(tonumber(n) or 0));local r=s:reverse():gsub('(%d%d%d)','%1,'):reverse();return (r:gsub('^,','')) end
local function cargoUnits(p)
 local published=tonumber(p.cargoUnits);if published then return math.max(0,published) end
 local n=0;local run=p.run or {}
 local function add(cargo) for _,v in pairs(cargo or {}) do if type(v)=='number' then n=n+v end end end
 add(run.cargo)
 return n
end
local function pending() return profile and profile.run and profile.run.pendingOffer end
local packView=PackView.new({
 player=player,world=world,parent=localFX,audio=soundscape,droneConfig=DroneConfig,
 hidden=menusVisible,busy=function() return not profile or profile.pendingTransaction or player:GetAttribute('MA_InAssault') end,
})
connect(modal:GetPropertyChangedSignal('Visible'),function() packView:setFocus(modal.Visible and modalMode=='offer' and not inspectingFleet()) end)
connect(RunService.RenderStepped,function() packView:update(workspace:GetServerTimeNow()) end)
local function sealedPack()
 local offer=pending()
 return offer and offer.opened==false
end
local function fieldUnlocked(field)
 return profile and type(profile.clearedFields)=='table' and field and profile.clearedFields[field.Name]==true or false
end
local function viewport()
 local size=safeRoot.AbsoluteSize
 if size.X>1 and size.Y>1 then return size end
 local camera=workspace.CurrentCamera;return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function currentLayout() local v=viewport();return UILayout.calculate(v.X,v.Y,UIS.TouchEnabled and not UIS.KeyboardEnabled) end
local function layoutModal()
 local v=viewport();local l=currentLayout()
 if l.short then l.headerHeight=64;l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-l.panelPadding) end
 if modalMode=='shop' then
  l.panelWidth=math.min(740,v.X-24);l.panelHeight=math.min(650,v.Y-24);l.panelPadding=16;l.headerHeight=l.short and 64 or 100
  l.bodyWidth=l.panelWidth-32;l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-16);l.panelX=(v.X-l.panelWidth)/2;l.panelY=(v.Y-l.panelHeight)/2
 end
 if modalMode=='reward' then
  l.panelWidth=math.min(520,l.panelWidth);l.panelHeight=math.min(360,l.panelHeight)
  l.headerHeight=72
  l.bodyWidth=l.panelWidth-2*l.panelPadding;l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-16)
  l.panelX=(v.X-l.panelWidth)/2;l.panelY=(v.Y-l.panelHeight)/2
 end
 if modalMode=='prestige' then
  l.panelWidth=math.min(l.short and 720 or 520,l.panelWidth);l.panelHeight=math.min(520,l.panelHeight)
  l.headerHeight=l.short and 58 or 64
  l.bodyWidth=math.max(1,l.panelWidth-2*l.panelPadding)
  l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-l.panelPadding)
  l.panelX=(v.X-l.panelWidth)/2;l.panelY=(v.Y-l.panelHeight)/2
 end
 if modalMode=='offer' then
  l.cardColumns=v.X>=650 and 3 or 1;l.cardGap=l.cardColumns==3 and 10 or 12
  l.panelWidth=math.min(l.cardColumns==3 and 770 or 432,l.panelWidth);l.panelPadding=8;l.bodyWidth=l.panelWidth-16
  l.headerHeight=49;l.offerFooter=10
  l.cardWidth=math.floor((l.bodyWidth-l.cardGap*(l.cardColumns-1))/l.cardColumns)
  l.cardHeight=l.cardColumns==3 and math.clamp(l.panelHeight-l.headerHeight-l.offerFooter-6,212,314) or 234
  l.panelX=(v.X-l.panelWidth)/2
  if l.cardColumns==3 then l.panelHeight=math.min(l.panelHeight,l.headerHeight+l.cardHeight+l.offerFooter+6) end
  l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-l.offerFooter)
  l.panelY=math.floor((v.Y-l.panelHeight)*.65)
 end
 sheet.Size=UDim2.fromOffset(l.panelWidth,l.panelHeight);sheet.Position=UDim2.fromOffset(l.panelX,l.panelY);modalSize=v
 body.Position=UDim2.fromOffset(l.panelPadding,l.headerHeight);body.Size=UDim2.fromOffset(l.bodyWidth,l.bodyHeight)
 modalTitle.TextSize=l.panelWidth<400 and 23 or 30
 modalTitle.Position=UDim2.fromOffset(l.panelWidth<400 and 74 or 90,16)
 modalTitle.Size=UDim2.new(1,l.panelWidth<400 and -136 or -158,0,43)
 modalEmblem.Size=UDim2.fromOffset(l.panelWidth<400 and 42 or 54,l.panelWidth<400 and 42 or 54)
 modalEmblem.Position=UDim2.fromOffset(18,18)
 modalSubtitle.Position=UDim2.fromOffset(l.panelPadding,l.short and 58 or 66)
 modalSubtitle.Size=UDim2.new(1,-l.panelPadding*2,0,l.short and 29 or 32)
 if l.short then
  modalEmblem.Size=UDim2.fromOffset(38,38);modalEmblem.Position=UDim2.fromOffset(18,10)
  local textX=l.panelWidth<400 and 74 or 90
  modalTitle.Position=UDim2.fromOffset(textX,6);modalTitle.Size=UDim2.new(1,l.panelWidth<400 and -136 or -158,0,32);modalTitle.TextSize=23
  modalSubtitle.Position=UDim2.fromOffset(textX,37);modalSubtitle.Size=UDim2.new(1,-textX-60,0,23)
 end
 return l
end
local menuTween=nil
local normalSubtitle=''
local function menu(mode,title,subtitle,icon)
 local entering=not modal.Visible or modalMode~=mode
 modalMode=mode;sheet:SetAttribute('MenuMode',mode);clearBody();local l=layoutModal();modalTitle.Text=title;modalSubtitle.Text=subtitle;normalSubtitle=subtitle
 local prestige=mode=='prestige'
 if mode~='shop' and not prestige then U.skin(sheet,palette.panel,20);U.skin(close,palette.danger,11) end
 local inOffer=mode=='offer';modal.BackgroundTransparency=inOffer and 1 or .22;sheet.BackgroundTransparency=inOffer and 1 or 0
 local colorful=true
 local texture=sheet:FindFirstChild('StudSurface');if texture then texture.Visible=not inOffer end
 body.ScrollBarThickness=inOffer and 0 or 4
 modalTitle.Visible=not inOffer
 modalSubtitle.Visible=not prestige
 modalSubtitle.TextXAlignment=inOffer and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
 close.BackgroundTransparency=inOffer and 1 or 0
 local closeTexture=close:FindFirstChild('StudSurface');if closeTexture then closeTexture.Visible=not prestige end
 local closeEdge=close:FindFirstChildOfClass('UIStroke');if closeEdge then closeEdge.Enabled=not inOffer end
 close.TextStrokeTransparency=inOffer and .4 or 1
 modalTitle.TextColor3=colorful and palette.white or palette.text;modalTitle.TextStrokeColor3=Color3.fromRGB(13,23,48);modalTitle.TextStrokeTransparency=colorful and .4 or 1
 modalSubtitle.TextColor3=inOffer and Color3.fromRGB(215,240,255) or palette.muted
 sheet.BackgroundColor3=palette.panel
 local rounded=sheet:FindFirstChildOfClass('UICorner');if rounded then rounded.CornerRadius=UDim.new(0,inOffer and 28 or 20) end
 local border=sheet:FindFirstChildOfClass('UIStroke');if border then border.Transparency=inOffer and 1 or 0;border.Color=inOffer and Color3.fromRGB(6,8,17) or palette.ink;border.Thickness=inOffer and 5 or 2 end
 if l.panelWidth<400 then
  local shortTitles={shop='Quartz Workshop',offer='Pick a card',fleet='Your crew',run='Run upgrades',prestige='Grow your fleet'}
  modalTitle.Text=shortTitles[mode] or title;modalTitle.TextSize=mode=='prestige' and 18 or 20
 end
 if modalEmblem then modalEmblem:Destroy() end
 modalEmblem=U.icon(sheet,icon,UDim2.fromOffset(18,l.short and 10 or 18),UDim2.fromOffset(l.short and 38 or l.panelWidth<400 and 42 or 54,l.short and 38 or l.panelWidth<400 and 42 or 54),colorful and Color3.fromRGB(255,210,85) or palette.mineral)
 local titles={shop='QUARTZ WORKSHOP',offer='PICK A CARD',fleet='YOUR FLEET',run='RUN UPGRADES',prestige='GROW YOUR FLEET'};modalTitle.Text=titles[mode] or title
 if colorful then modalTitle.Font=Enum.Font.Arcade;modalTitle.TextColor3=palette.white;modalTitle.TextStrokeTransparency=.45;modalSubtitle.TextColor3=Color3.fromRGB(202,209,231) else modalTitle.Font=Enum.Font.SourceSansBold end
 modalEmblem.Visible=not inOffer
 if inOffer then
  modalSubtitle.Position=UDim2.fromOffset(46,1)
  modalSubtitle.Size=UDim2.new(1,-92,0,44);modalSubtitle.TextSize=17
 else modalSubtitle.TextSize=12 end
 if mode=='shop' or mode=='stars' then
  ShopView.decorate(U,sheet,modalTitle,modalSubtitle,close);body.ScrollBarImageColor3=Color3.fromRGB(29,132,211)
  if mode=='stars' then modalTitle.Text='Star upgrades';modalTitle.TextColor3=Color3.fromRGB(139,91,17) end
  if mode=='shop' and l.panelWidth<400 then modalTitle.Text='Workshop' end
 end
 if prestige then
  for _,control in ipairs({sheet,close}) do
   local surface=control:FindFirstChild('StudSurface');if surface then surface.Visible=false end
   local shading=control:FindFirstChildOfClass('UIGradient');if shading then shading.Enabled=false end
  end
  corner(sheet,9);corner(close,5);U.stroke(sheet,palette.line,2)
  modalEmblem.Visible=false
  modalTitle.Text='Prestige';modalTitle.Font=Enum.Font.SourceSansBold;modalTitle.TextSize=l.short and 25 or 30
  modalTitle.Position=UDim2.fromOffset(l.panelPadding,10);modalTitle.Size=UDim2.new(1,-90,0,36)
  modalTitle.TextStrokeTransparency=1
 elseif mode=='reward' then
  modalEmblem.Visible=false
  modalTitle.Font=Enum.Font.SourceSansBold;modalTitle.TextSize=25
  modalTitle.Position=UDim2.fromOffset(l.panelPadding,9);modalTitle.Size=UDim2.new(1,-l.panelPadding-56,0,31)
  modalSubtitle.TextSize=16
  modalSubtitle.Position=UDim2.fromOffset(l.panelPadding,42);modalSubtitle.Size=UDim2.new(1,-2*l.panelPadding,0,24)
 end
 modal.Visible=true
 packView:setFocus(inOffer)
 if inOffer then
  if menuTween then menuTween:Cancel() end
  sheetScale.Scale=1
 elseif entering then
  if menuTween then menuTween:Cancel() end
  sheetScale.Scale=.98;menuTween=TweenService:Create(sheetScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1});menuTween:Play()
 end
 return l
end
local function availability(action)
 if not profile then return false,'Connecting…' end
 if actionPending or profile.pendingTransaction then return false,'Waiting for confirmation…' end
 if player:GetAttribute('MA_InAssault') then return false,'Recall your fighting drones first' end
 local name,range,where
 if action=='ChooseCard' then name,range,where='PackStation',24,'Pack Counter'
 elseif action=='BuyUpgrade' then name,range,where='QuartzShop',15,'Quartz Workshop'
 elseif action=='BuyStarUpgrade' then name,range,where='RubyShop',12,'Star Shop'
 elseif action=='Prestige' then name,range,where='PrestigeStation',15,'Prestige beacon'
 end
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local station=name and world.Map:FindFirstChild(name,true)
 if station and hr and (hr.Position-station.Position).Magnitude<range then return true,'' end
 return false,'Visit the '..(where or 'depot')
end
local function canAct(action) return availability(action or 'ChooseCard') end
local function number(n)
 if math.abs(n)>=1000 then return comma(n) end
 if math.abs(n-math.floor(n+.5))<.001 then return tostring(math.floor(n+.5)) end
 return string.format('%.3g',n)
end
local function targetText(choice)
 if choice.cardId=='A02' then return 'YOUR COURIERS' end
 if choice.scope=='Individual' then return 'ONE DRONE / '..(choice.targetName or 'Assigned drone') end
 if choice.scope=='Color' then return 'ALL '..string.upper(choice.type or '')..' DRONES' end
 return choice.scope=='Player' and 'YOUR BACKPACK' or 'ENTIRE FLEET'
end
local function progress(parent,y,width,title,detail,fraction,color,dark)
 label(parent,UDim2.fromOffset(0,y),UDim2.fromOffset(width,22),title,17,dark and palette.white or palette.text,true)
 label(parent,UDim2.fromOffset(0,y+27),UDim2.fromOffset(width,27),detail,12,dark and Color3.fromRGB(202,209,231) or palette.muted)
 local track=frame(parent,UDim2.fromOffset(0,y+62),UDim2.fromOffset(width,10),palette.paper);track.ClipsDescendants=true;corner(track,3)
 local fill=frame(track,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(fraction,0,1),1),color);corner(fill,3)
end
local function refreshFleetInspection()
 if not inspectingFleet() or not profile or fleetView.installed then return end
 local offer=pending()
 local busy=actionPending and actionPending.kind=='ChooseCard' or profile.pendingTransaction
 local available,reason=availability('ChooseCard')
 if fleetView.choice and not offer then available=false;reason='Upgrade installed' end
 local message=fleetView.choice and noticeUntil>os.clock() and notice.Text~='' and notice.Text or nil
 fleetView:refresh(profile,available,reason,busy,message)
end
local function closeFleetInspection(returnToOffer)
 if not inspectingFleet() then return end
 local wasChoice=fleetView.choice~=nil
 fleetView:close();fleetView.installed=nil
 if wasChoice and returnToOffer and pending() and pending().opened~=false then openOffer() end
 syncModalTouch()
end
fleetView=FleetView.new({
 U=U,parent=safeRoot,world=localFX,player=player,button=button,droneConfig=DroneConfig,
 resolve=function(id) return droneIndex[tostring(id)] end,
 onTarget=refreshFleetInspection,
 onBack=function() closeFleetInspection(true) end,
 onAbort=function() closeFleetInspection(false) end,
 onInstall=function(target)
  local offer=pending()
  if not fleetView.choice or not offer or offer.id~=offerUI.selectionId or not canAct() or not offerUI.index then return end
  local choice=offer.choices[offerUI.index]
  local hardware=Workshop.isHardware(choice)
  if hardware and not target then return end
  if send('ChooseCard',{offerId=offer.id,index=offerUI.index,targetDroneId=hardware and target.id or nil}) then
   noticeUntil=0;refreshFleetInspection()
  end
 end,
})
local function updateOfferControls()
 local offer=pending()
 if offer and offer.opened~=false then
  local stars=offer.packTier or 1
  normalSubtitle=(Packs.Tiers[stars] or 'Upgrade')..' pack · Pick one · +'..stars..(stars==1 and ' Star' or ' Stars')
  for _,view in ipairs(offerViews) do enableAction(view.button,not actionPending and not profile.pendingTransaction) end
 end
 refreshFleetInspection()
end
openOffer=function()
 local offer=pending();if not offer or inspectingFleet() then return end
 if offer.opened==false then
  modal.Visible=false;modalMode=nil
  return
 end
 local size=viewport()
 if modal.Visible and modalMode=='offer' and offerIdentity==offer.id and offerRenderSize and (offerRenderSize-size).Magnitude<1 then updateOfferControls();return end
 if offerUI.revealId~=offer.id then
  offerUI.revealId=offer.id;offerUI.revealAt=os.clock()+.23
  offerUI.index=nil;offerUI.selectionId=nil;offerUI.claim=nil;offerUI.completed=nil;noticeUntil=0
 end
 local stars=offer.packTier or 1
 local l=menu('offer','PICK AN UPGRADE',(Packs.Tiers[stars] or 'Upgrade')..' pack · Pick one · +'..stars..(stars==1 and ' Star' or ' Stars'),'cards')
 offerIdentity=offer.id;offerRenderSize=size
 local list=Instance.new('UIListLayout');list.FillDirection=l.cardColumns==3 and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical;list.Padding=UDim.new(0,l.cardGap);list.HorizontalAlignment=Enum.HorizontalAlignment.Center;list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 for index,choice in ipairs(offer.choices) do
  local view=CardView.create(U,body,choice,index,l.cardWidth-4,l.cardHeight,{
   revealStart=offerUI.revealAt,revealSpeed=profile.packSpeed or 1,target=targetText(choice),
   reelParent=modal,portrait=l.cardColumns~=3,
   onTick=function() soundscape:play('pack_step',nil,{pitch=.85+index*.09,level=.66}) end,
   onLand=function(tier) soundscape:play('pack_land',nil,{pitch=.96+tier*.16}) end,
   onChoose=function()
    if not pending() or pending().id~=offer.id or actionPending or profile.pendingTransaction then return end
    local targets=Workshop.targets(profile,choice)
    if choice.scope=='Individual' and not Workshop.isHardware(choice) then
     for _,drone in ipairs(profile.fleet) do if drone.id==choice.targetDroneId then table.insert(targets,drone);break end end
    end
    if fleetView:open(profile,choice,targets) then
     offerUI.index=index;offerUI.selectionId=offer.id
     modal.Visible=false
     syncModalTouch();refreshFleetInspection()
    end
   end,
  })
  offerViews[index]=view
 end
 updateOfferControls()
end
local fleetButton=button(safeRoot,UDim2.new(1,-72,0,12),UDim2.fromOffset(58,58),'',function()
 if not profile or menusVisible() then return end
 if fleetView:open(profile) then syncModalTouch();refreshFleetInspection() end
end,palette.paper)
fleetButton.Name='InspectCrew'
fleetButton.Visible=false
corner(fleetButton,8)
local fleetIcon=Instance.new('ImageLabel')
fleetIcon.Name='CrewIcon';fleetIcon.BackgroundTransparency=1;fleetIcon.Image=CardView.scopeIcon({scope='Individual'})
fleetIcon.Size=UDim2.fromOffset(28,28);fleetIcon.Position=UDim2.new(.5,-14,0,3);fleetIcon.ZIndex=fleetButton.ZIndex+3
fleetIcon.Parent=fleetButton
local fleetLabel=label(fleetButton,UDim2.fromOffset(0,30),UDim2.new(1,0,0,23),'Crew',15,palette.white,true)
fleetLabel.TextXAlignment=Enum.TextXAlignment.Center
openShop=function()
 if not profile or not profile.run.wallet then return end
 local allowed,reason=availability('BuyUpgrade')
 local l=menu('shop','Quartz Workshop',allowed and 'Improve your installed cards' or reason,'crystal')
 ShopView.render(U,body,{profile=profile,width=l.bodyWidth-4,canBuy=allowed,onBuy=function(c,level)
  if canAct('BuyUpgrade') and send('BuyUpgrade',{upgradeId=c.cardId,level=level}) then openShop() end
 end})
end
openStars=function()
 if not profile then return end
 local allowed,reason=availability('BuyStarUpgrade')
 local l=menu('stars','Star Shop',comma(profile.run.stars or 0)..' Stars · Resets on prestige'..(allowed and '' or ' · '..reason),'cards')
 ShopView.renderStars(U,body,{profile=profile,width=l.bodyWidth-4,canBuy=allowed,onBuy=function(id,level)
  if canAct('BuyStarUpgrade') and send('BuyStarUpgrade',{upgradeId=id,level=level}) then openStars() end
 end})
end
local function statTile(parent,x,y,width,title,value,color)
 local tile=frame(parent,UDim2.fromOffset(x,y),UDim2.fromOffset(width,55),palette.panel);tile.BackgroundTransparency=1
 label(tile,UDim2.fromOffset(10,5),UDim2.new(1,-20,0,15),title,14,palette.muted,true)
 label(tile,UDim2.fromOffset(10,24),UDim2.new(1,-20,0,26),value,20,color or palette.text,true)
end
local function tabs(width,mode)
 local a=button(body,UDim2.fromOffset(3,3),UDim2.fromOffset((width-14)/2,44),'Permanent fleet',openFleet,mode=='fleet' and palette.mineral or palette.paper)
 local b=button(body,UDim2.fromOffset((width-14)/2+11,3),UDim2.fromOffset((width-14)/2,44),'This run · '..#profile.run.cards,openRunCards,mode=='run' and palette.accent or palette.paper)
 a.Name='FleetTab';b.Name='RunTab'
end
openFleet=function()
 if not profile then return end
 local crew=profile.activeFleet or profile.fleet
 local l=menu('fleet','Meet your crew',profile.testCrewActive and ('Studio role test · '..#crew..' active drones') or (#profile.fleet..' permanent · '..#crew..' active this run'),'drone');local width=l.bodyWidth-6
 tabs(width,'fleet')
 local rosterY=64
 if player:GetAttribute('MA_TestingEnabled')==true then
  local half=(width-12)/2
  local reroll=button(body,UDim2.fromOffset(3,57),UDim2.fromOffset(half,44),'Random 2–5 [T]',function() command:FireServer('TestLoadout');modal.Visible=false end,palette.paper)
  reroll.Name='RerollTestCrew'
  local roles=button(body,UDim2.fromOffset(half+15,57),UDim2.fromOffset(half,44),profile.testCrewActive and 'Use saved fleet' or 'All drone types',function() command:FireServer(profile.testCrewActive and 'NormalLoadout' or 'RoleLoadout');modal.Visible=false end,palette.mineral);roles.Name='RestoreRoleCrew'
  if player:GetAttribute('MA_DevToolsEnabled')==true then
  local fill=button(body,UDim2.fromOffset(3,109),UDim2.fromOffset(width,40),'Fill backpack',function() command:FireServer('DevFillBag');modal.Visible=false end,palette.accent)
  fill.Name='DevFillBag'
  local choices={{'Striker','+ Miner'},{'Courier','+ Courier'},{'Medic','+ Healer'},{'Dart','+ Grower'},{'Charger','+ Smasher'},{'Orbiter','+ Orbital'},{'Ramiel','+ Ramiel'},{'Scrapper','+ Swarm'}}
  local columns=width>=560 and 4 or 2;local gap=8;local cell=(width-gap*(columns-1))/columns
  for index,choice in ipairs(choices) do
   local b=button(body,UDim2.fromOffset(3+((index-1)%columns)*(cell+gap),157+math.floor((index-1)/columns)*46),UDim2.fromOffset(cell,38),choice[2],function()
    command:FireServer('DevAddDrone',{role=choice[1]});modal.Visible=false
   end,colors[choice[1]] or palette.paper)
   b.Name='DevAdd'..choice[1]
  end
  rosterY=157+math.ceil(#choices/columns)*46+10
  else rosterY=114 end
 end
 local columns=width>=650 and 2 or 1;local gap=14;local rowWidth=(width-gap*(columns-1))/columns
 for index,d in ipairs(crew or {}) do
  local stats=(profile.droneStats and profile.droneStats[d.id]) or d.effective or d.base or {}
  local x=((index-1)%columns)*(rowWidth+gap)+3;local y=rosterY+math.floor((index-1)/columns)*276
  local tint=colors[d.type] or palette.mineral
  local row=U.panel(body,UDim2.fromOffset(x,y),UDim2.fromOffset(rowWidth,258),tint:Lerp(palette.panel,.36),14);row.Name='FleetDrone'..index
  U.icon(row,'drone',UDim2.fromOffset(13,14),UDim2.fromOffset(62,62),tint)
  label(row,UDim2.fromOffset(87,14),UDim2.new(1,-102,0,33),d.name or ('Drone '..index),24,palette.text,true)
  local source=d.id:sub(1,5)=='test:' and 'Test · ' or d.id:sub(1,#profile.run.id)==profile.run.id and 'This run · ' or ''
  local identity=label(row,UDim2.fromOffset(87,50),UDim2.new(1,-102,0,24),source..(d.role or d.type or 'Blue'),16,palette.muted,true)
  local count=0;for _,c in ipairs(profile.run.cards) do if c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Color' and c.type==d.type) or (c.scope=='Individual' and c.targetDroneId==d.id) then count=count+1 end end
  identity.Text=identity.Text..' · '..tostring(count)..' upgrades'
  local tileWidth=(rowWidth-42)/2
  local role=(profile.droneRoles and profile.droneRoles[d.id]) or d.role or d.type
  if role=='Medic' then
   statTile(row,14,91,tileWidth,'REPAIR',tostring(DroneConfig.Types.Medic.HealAmount)..' health')
   statTile(row,tileWidth+28,91,tileWidth,'INTERVAL',tostring(DroneConfig.Types.Medic.AttackCooldown)..' sec')
  elseif role=='Courier' then
   local crystalRun=world:GetAttribute('FieldToolsEnabled')==false
   statTile(row,14,91,tileWidth,'PARCEL',tostring(crystalRun and Workshop.emptierBatch(profile) or DroneConfig.Courier.BatchUnits)..' cargo')
   statTile(row,tileWidth+28,91,tileWidth,'JOB',crystalRun and 'Sell at Workshop' or 'Haul to storage')
  elseif role=='Compactor' then
   statTile(row,14,91,tileWidth,'INPUT','Up to '..Workshop.compactorBatch(profile)..' rocks')
   statTile(row,tileWidth+28,91,tileWidth,'OUTPUT','1 equal-value block')
  elseif role=='Dart' then
   statTile(row,14,91,tileWidth,'JOB','Grow rocks')
   statTile(row,tileWidth+28,91,tileWidth,'COOLDOWN',number(stats.growCooldown or 5)..' sec')
  elseif role=='Charger' then
   statTile(row,14,91,tileWidth,'JOB','Dive + impact')
   statTile(row,tileWidth+28,91,tileWidth,'IMPACT',number((stats.miningDPS or 30)*2.4)..' base')
  elseif role=='Orbiter' then
   statTile(row,14,91,tileWidth,'JOB','Orbital strike')
   statTile(row,tileWidth+28,91,tileWidth,'CYCLE','45s cooldown')
  elseif role=='Scrapper' then
   statTile(row,14,91,tileWidth,'JOB','Launch bots')
   statTile(row,tileWidth+28,91,tileWidth,'SWARM','10 seconds')
  elseif DroneCatalog.Types[role] then
   local entry=DroneCatalog.Types[role]
   statTile(row,14,91,tileWidth,'CYCLE',number(entry.Duration)..' sec')
   statTile(row,tileWidth+28,91,tileWidth,'RECOVERY',number(entry.Yield or 1)..'× ore')
  else
   statTile(row,14,91,tileWidth,'MINING',number(stats.miningDPS or 30)..' /s')
   statTile(row,tileWidth+28,91,tileWidth,'COMBAT',number(stats.combatDPS or 12)..' /s')
  end
  statTile(row,14,153,tileWidth,'MAX HULL',number(stats.maxHealth or 80))
  statTile(row,tileWidth+28,153,tileWidth,'FLIGHT',number((stats.maxStep60 or .35)*60)..' studs/s')
  label(row,UDim2.fromOffset(15,211),UDim2.new(1,-30,0,40),DroneCatalog.Types[role] and DroneCatalog.Types[role].Description or Mining.description(role),16,palette.muted)
 end
 local audioY=rosterY+math.ceil(#crew/columns)*276
 local music=button(body,UDim2.fromOffset(3,audioY),UDim2.fromOffset((width-12)/2,44),soundscape.musicMuted and 'Music: off' or 'Music: on',function() soundscape:toggleMusic();openFleet() end,palette.paper)
 music.Name='ToggleMusic'
 local effects=button(body,UDim2.fromOffset((width-12)/2+15,audioY),UDim2.fromOffset((width-12)/2,44),soundscape.effectsMuted and 'Effects: off' or 'Effects: on',function() soundscape:toggleEffects();openFleet() end,palette.paper)
 effects.Name='ToggleEffects'
end
openRunCards=function()
 if not profile then return end
 local l=menu('run','Your current build','Your upgrades stack together until prestige. Find more in packs or buy another stack.','cards');local width=l.bodyWidth-6
 tabs(width,'run')
 if #profile.run.cards==0 then
  U.icon(body,'cards',UDim2.fromOffset(math.max(0,(width-90)/2),84),UDim2.fromOffset(90,90),palette.mineral)
  local title=label(body,UDim2.fromOffset(6,196),UDim2.fromOffset(width-12,38),'Your first upgrade is waiting',26,palette.text,true);title.TextXAlignment=Enum.TextXAlignment.Center
  local detail=label(body,UDim2.fromOffset(12,247),UDim2.fromOffset(width-24,64),'Mine Quartz and sell it at SELL ORE. Open a pack and pick an upgrade. Find it again or buy another stack to make it stronger.',14,palette.muted);detail.TextXAlignment=Enum.TextXAlignment.Center
  label(body,UDim2.fromOffset(6,334),UDim2.fromOffset(width-12,30),'Visit the Quartz Workshop',16,palette.muted)
 else
  for index,c in ipairs(profile.run.cards) do
   local y=63+(index-1)*166
   local _,tint=CardView.identity(c)
   local row=U.panel(body,UDim2.fromOffset(3,y),UDim2.fromOffset(width,152),tint:Lerp(palette.panel,.42),12)
   label(row,UDim2.fromOffset(16,10),UDim2.new(1,-32,0,26),c.title or 'Run upgrade',20,palette.text,true)
   label(row,UDim2.fromOffset(16,37),UDim2.new(1,-32,0,55),CardView.summary(c),17,palette.text,true)
   label(row,UDim2.fromOffset(16,94),UDim2.new(1,-32,0,46),CardView.terms(c,targetText(c)),16,palette.muted)
  end
 end
end
openPrestige=function()
 if not profile then return end
 local l=menu('prestige','Prestige','','prestige')
 local pre=profile.prestigePreview or {}
 local width=l.bodyWidth-8
 local required=pre.saleRequired or Workshop.PRESTIGE_BASE
 local earnings=pre.earnings or profile.run.quartzEarnings or 0
 local allowed,blocked=availability('Prestige')
 local paid=pending()
 local can=pre.eligible==true and not paid and allowed
 local choices=pre.droneChoices or {}
 local selected=offerUI.prestigeRun==pre.runId and offerUI.prestigeChoice or nil
 local selectedName,confirm
 local marks={}
 local textService=game:GetService('TextService')
 local function heightFor(text,size,bold,availableWidth)
  local font=bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
  return math.ceil(textService:GetTextSize(text,size,font,Vector2.new(math.max(1,availableWidth),1000)).Y)+4
 end
 local y=4
 if #choices>0 then
  local heading='Choose one permanent drone'
  local headingHeight=math.max(28,heightFor(heading,20,true,width))
  label(body,UDim2.fromOffset(4,y),UDim2.fromOffset(width,headingHeight),heading,20,palette.text,true)
  y+=headingHeight+6
  local sideBySide=l.short and width>=608
  local rowWidth=sideBySide and math.floor((width-16)/3) or width
  local artSize=sideBySide and 46 or (width<235 and 46 or 58)
  local textX=sideBySide and 8 or artSize+16
  local textWidth=rowWidth-textX-9
  local nameY=sideBySide and artSize+4 or 5
  local jobY=nameY+22
  local tallest=0
  for i,entry in ipairs(choices) do
   local chosen=entry.kind==selected
   if chosen then selectedName=entry.name end
   local jobHeight=heightFor(entry.job,16,false,textWidth)
   local rowHeight=math.max(artSize+8,jobHeight+jobY+2)
   local x=4+(sideBySide and (i-1)*(rowWidth+8) or 0)
   local pick=button(body,UDim2.fromOffset(x,y),UDim2.fromOffset(rowWidth,rowHeight),'',function()
    if not can or actionPending then return end
    selected=entry.kind;selectedName=entry.name
    offerUI.prestigeRun=pre.runId;offerUI.prestigeChoice=entry.kind
    for kind,edge in pairs(marks) do edge.Enabled=kind==selected end
    confirm.Text='Prestige with '..selectedName;enableAction(confirm,true)
   end,palette.paper)
   U.unskin(pick);corner(pick,4)
   local artPosition=sideBySide and UDim2.new(.5,-artSize/2,0,4) or UDim2.fromOffset(5,math.floor((rowHeight-artSize)/2))
   CardView.dronePortrait(pick,artPosition,UDim2.fromOffset(artSize,artSize),entry.kind,palette.mineral)
   local name=label(pick,UDim2.fromOffset(textX,nameY),UDim2.fromOffset(textWidth,22),entry.name,18,palette.text,true)
   local job=label(pick,UDim2.fromOffset(textX,jobY),UDim2.fromOffset(textWidth,jobHeight),entry.job,16,palette.muted)
   if sideBySide then name.TextXAlignment=Enum.TextXAlignment.Center;job.TextXAlignment=Enum.TextXAlignment.Center end
   local edge=U.stroke(pick,Color3.fromRGB(161,237,185),2)
   edge.Enabled=chosen;marks[entry.kind]=edge
   pick.Name='PrestigeDrone'..i;enableAction(pick,can)
   if not sideBySide then y+=rowHeight+6 end
   tallest=math.max(tallest,rowHeight)
  end
  if sideBySide then
   for _,edge in pairs(marks) do edge.Parent.Size=UDim2.fromOffset(rowWidth,tallest) end
   y+=tallest+6
  end
 else
  label(body,UDim2.fromOffset(4,y),UDim2.fromOffset(width,28),'Quartz sold this run',20,palette.text,true)
  label(body,UDim2.fromOffset(4,y+30),UDim2.fromOffset(width,25),comma(earnings)..' / '..comma(required),18,palette.muted,true)
  local track=frame(body,UDim2.fromOffset(4,y+58),UDim2.fromOffset(width,6),palette.paper)
  frame(track,UDim2.fromOffset(0,0),UDim2.fromScale(math.clamp(earnings/math.max(1,required),0,1),1),palette.mineral)
  y+=76
 end
 local bonusBefore=math.floor((pre.miningBonusBefore or 0)*100)
 local bonusAfter=math.floor((pre.miningBonusAfter or .25)*100)
 local bonus=('+%d%% → +%d%% base mining power'):format(bonusBefore,bonusAfter)
 if #choices==0 then bonus='+1 permanent drone · '..bonus end
 local bonusHeight=math.max(25,heightFor(bonus,17,true,width))
 label(body,UDim2.fromOffset(4,y),UDim2.fromOffset(width,bonusHeight),bonus,17,Color3.fromRGB(161,237,185),true)
 y+=bonusHeight+5
 frame(body,UDim2.fromOffset(4,y),UDim2.fromOffset(width,1),palette.paper)
 y+=5
 local function terms(name,copy,tint)
  local height=heightFor(copy,16,false,width)
  label(body,UDim2.fromOffset(4,y),UDim2.fromOffset(width,height),copy,16,tint).Name=name
  y+=height+4
 end
 terms('PrestigeKeep','Keep all '..tostring(pre.fleetBefore or #profile.fleet)..' permanent drones, their traits, stored tools, transport and cleared plots.',palette.text)
 terms('PrestigeReset','Reset balances, all cargo, cards, Stars, run upgrades, field access, pack prices and sale progress.',palette.muted)
 y+=3
 if #choices==0 then
  local reason=paid and 'Choose your paid pack card first.' or ('Sell '..comma(math.max(0,required-earnings))..' more Quartz.')
  label(body,UDim2.fromOffset(4,y),UDim2.fromOffset(width,40),reason,17,palette.text,true)
  return
 end
 local waiting=actionPending and actionPending.kind=='Prestige'
 local reason=waiting and 'Starting new run…' or (not allowed and blocked or (selectedName and 'Prestige with '..selectedName or 'Select a drone'))
 confirm=button(body,UDim2.fromOffset(4,y),UDim2.fromOffset(width,46),reason,function()
  if selected and can and canAct('Prestige') and send('Prestige',{confirm=true,droneType=selected}) then
   confirm.Text='Starting new run…';enableAction(confirm,false)
  end
 end,palette.mineral)
 U.unskin(confirm);corner(confirm,5);confirm.Name='ConfirmPrestige';enableAction(confirm,can and selected~=nil and not waiting)
end
local function openDroneReward(reward,settled)
 local l=menu('reward','Drone unlocked','+25% base mining power','drone')
 CardView.revealDrone(U,body,l.bodyWidth,reward,soundscape,function()
  offerUI.droneReward=nil;modal.Visible=false;modalMode=nil
 end,settled)
end
local refreshSerial=0
local function refreshModal()
 if not modal.Visible then return end
 local savedScroll=body.CanvasPosition;local mode=modalMode
 refreshSerial=refreshSerial+1;local serial=refreshSerial
 if mode=='offer' then if pending() then openOffer() end
 elseif mode=='shop' then openShop()
 elseif mode=='stars' then openStars()
 elseif mode=='prestige' then openPrestige()
 elseif mode=='reward' then
  if not offerUI.droneReward or (modalSize and (viewport()-modalSize).Magnitude<=1) then return end
  openDroneReward(offerUI.droneReward,true)
 elseif mode=='fleet' then openFleet()
 elseif mode=='run' then openRunCards() end
 task.defer(function()
  RunService.Heartbeat:Wait()
  if serial==refreshSerial and modal.Visible and modalMode==mode and body.Parent then
   body.CanvasPosition=Vector2.new(0,math.min(savedScroll.Y,math.max(0,body.AbsoluteCanvasSize.Y-body.AbsoluteWindowSize.Y)))
  end
 end)
end
do
 local lastOffer=nil
 local resourceAccess=''
 local function menuContentKey(p)
  if not p or not p.run then return '' end
  local run=p.run;local values={tostring(run.id),tostring(run.packIndex or 0),tostring(p.nextPackPrice or 0),tostring(p.capacity or 0),tostring(p.pendingTransaction),#(run.cards or {})}
  if modalMode=='shop' then table.insert(values,cargoUnits(p)) end
  for _,key in ipairs(Shops.ORDER) do table.insert(values,Shops.balance(p,key));table.insert(values,tostring(Shops.unlocked(p,key))) end
  table.insert(values,run.stars or 0)
  for _,entry in ipairs(Workshop.STAR_CATALOG) do table.insert(values,Workshop.starLevel(p,entry.id)) end
  for _,c in ipairs(run.cards) do table.insert(values,tostring(c.cardId)..'='..tostring(c.level or 0)) end
  local pre=p.prestigePreview or {}
  for _,key in ipairs({'earnings','wins','eligible','saleRequired','fleetBefore','fleetAfter'}) do table.insert(values,tostring(pre[key])) end
  for i,value in ipairs(values) do values[i]=tostring(value) end
  return table.concat(values,':')
 end
 local function readProfile()
  local raw=player:GetAttribute('MA_Profile');if type(raw)~='string' then return end
  local ok,p=pcall(function() return Http:JSONDecode(raw) end);if not ok or type(p)~='table' or type(p.run)~='table' then return end
  local oldProfile=profile
  local changedRun=profile and profile.run.id~=p.run.id
  soundscape:observeProfile(oldProfile,p)
  profile=p
  if changedRun then closeFleetInspection(false) end
  local access={p.run.id}
  for _,key in ipairs(Shops.ORDER) do table.insert(access,tostring(Shops.unlocked(p,key))) end
  local accessKey=table.concat(access,':')
  if accessKey~=resourceAccess then
   resourceAccess=accessKey
   for _,record in pairs(resources) do record.dirty=true end
  end
  if actionPending then
   local offer=p.run.pendingOffer
   if changedRun or (actionPending.kind=='ChooseCard' and (not offer or offer.id~=actionPending.offerId)) or (actionPending.kind=='BuyUpgrade' and ((Workshop.find(p,actionPending.upgradeId) or {}).level or 0)>(actionPending.level or 0)) then actionPending=nil end
   if actionPending and actionPending.kind=='BuyStarUpgrade' and Workshop.starLevel(p,actionPending.upgradeId)>actionPending.level then actionPending=nil end
  end
  if changedRun and modalMode=='prestige' then modal.Visible=false end
  local offer=pending()
  if offer and offer.opened~=false and offer.id~=lastOffer then
   lastOffer=offer.id
   if oldProfile then
    closeFleetInspection(false)
    if logisticsView then logisticsView:close() end
    menuStation=nil;openOffer()
   end
  elseif not offer and modalMode=='offer' then
   if not offerUI.completed then
    local claim=offerUI.claim
    if claim and not changedRun and inspectingFleet() and fleetView.choice and offerUI.selectionId==claim.offerId then
     offerUI.completed=claim.offerId;offerUI.claim=nil
     notice.Text='Upgrade installed';noticeUntil=os.clock()+1.8
     refreshFleetInspection()
     fleetView.installed=true;fleetView.title.Text='Upgrade installed'
     task.delay(.70,function()
      if inspectingFleet() and fleetView.installed and offerUI.completed==claim.offerId then closeFleetInspection(false) end
      if modalMode=='offer' and not pending() then modalMode=nil end
     end)
    else
     closeFleetInspection(false);modal.Visible=false;modalMode=nil
    end
   end
  elseif modalMode=='offer' then -- A paid offer is immutable.
   updateOfferControls()
  elseif modalMode=='fleet' or modalMode=='run' then
   local oldMilestone=oldProfile and oldProfile.prestigePreview or {}
   local milestone=p.prestigePreview or {}
   local milestoneChanged=modalMode=='fleet' and (oldMilestone.earnings~=milestone.earnings or oldMilestone.wins~=milestone.wins or oldMilestone.eligible~=milestone.eligible)
   local oldCrew=oldProfile and (oldProfile.activeFleet or oldProfile.fleet) or {};local crew=p.activeFleet or p.fleet
   local crewChanged=#oldCrew~=#crew or (crew[1] and oldCrew[1] and crew[1].id~=oldCrew[1].id)
   if not oldProfile or changedRun or crewChanged or #oldProfile.fleet~=#p.fleet or #oldProfile.run.cards~=#p.run.cards or milestoneChanged then refreshModal() end
  elseif menuContentKey(oldProfile)~=menuContentKey(p) then refreshModal() end
  if inspectingFleet() and not fleetView.installed then refreshFleetInspection() end
 end
 connect(player:GetAttributeChangedSignal('MA_Profile'),readProfile);readProfile()
end
connect(player:GetAttributeChangedSignal('MA_ShowOffer'),function()
 if pending() and not sealedPack() then menuStation=nil;openOffer() end
end)
connect(player:GetAttributeChangedSignal('MA_DroneReward'),function()
 local ok,reward=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_DroneReward') or '')
 if not ok or type(reward)~='table' or not reward.rewardName then return end
 menuStation=nil
 closeFleetInspection(false)
 if logisticsView then logisticsView:close() end
 offerUI.droneReward=reward
 openDroneReward(reward)
end)
connect(player:GetAttributeChangedSignal('MA_Notice'),function()
 notice.Text=tostring(player:GetAttribute('MA_Notice') or '');noticeUntil=os.clock()+5
 if not actionPending or actionPending.kind~='ChooseCard' then actionPending=nil end
 refreshModal()
end)
connect(player.PlayerGui:GetAttributeChangedSignal('MA_OfferReceipt'),function()
 local claim=offerUI.claim
 local raw=player.PlayerGui:GetAttribute('MA_OfferReceipt')
 if not claim or type(raw)~='string' then return end
 local ok,reply=pcall(Http.JSONDecode,Http,raw)
 if not ok or type(reply)~='table' or reply.txId~=claim.txId or reply.runId~=claim.runId or reply.offerId~=claim.offerId then return end
 if reply.status=='rejected' then
  if actionPending==claim then actionPending=nil end
  offerUI.claim=nil;notice.Text=reply.reason or 'Upgrade could not be installed';noticeUntil=os.clock()+5
  updateOfferControls()
 elseif reply.status=='uncertain' then
  notice.Text='Checking your install…';noticeUntil=os.clock()+5
 end
end)

local abilityView=AbilityView.start({interface=U,parent=safeRoot,command=command,droneConfig=DroneConfig,profile=function() return profile end,hidden=menusVisible})
local crystalAudio=require(RS.Shared:WaitForChild('CrystalAudio')).new(localFX,soundscape.crystalGroup)
local function sanitize(model)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('SurfaceGui') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
  elseif v:IsA('Beam') or v:IsA('Trail') or v:IsA('ParticleEmitter') or v:IsA('Light') then v.Enabled=false end
 end
end
local function hidePart(part)
 if not hiddenParts[part] then hiddenParts[part]=true;part.LocalTransparencyModifier=1 end
end
local function hideModel(model)
 for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then hidePart(v) elseif v:IsA('Beam') then v.Enabled=false end end
end
local function localPart(parent,name,pos)
 local p=Instance.new('Part');p.Name=name;p.Size=Vector3.new(.05,.05,.05);p.Position=pos;p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=parent;return p
end
local function createBeam(view,emitter)
 return presentation:createMiningBeam(view,emitter)
end
local function registerDrone(source)
 if drones[source] then return true end
 if not source:IsA('Model') then return false end
 local id=source:GetAttribute('DroneId');local pos=source:GetAttribute('Position');local kind=source:GetAttribute('Type')
 if not id or typeof(pos)~='Vector3' or not colors[kind] or type(source:GetAttribute('Role'))~='string' then return false end
 pendingDroneSources[source]=true
 -- Render from the complete preserved asset, never a partially streamed gameplay model.
 -- The historical drone is a Part body plus its nested emitter; it has no SpecialMesh.
 local template=RS:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
 local mesh=template and template:FindFirstChild('Mesh')
 local templateEmitter=mesh and mesh:FindFirstChild('Emmiter')
 local originalBeam=mesh and mesh:FindFirstChild('Beam')
 if not template or not template:IsA('Model') or not mesh or not mesh:IsA('BasePart')
  or not templateEmitter or not templateEmitter:IsA('BasePart') or not mesh:FindFirstChild('Attachment')
  or not mesh:FindFirstChild('WeldConstraint') or not originalBeam
  or not originalBeam:FindFirstChild('InnerBeam') or not originalBeam:FindFirstChild('OuterBeam') then
  -- Never make a gameplay drone invisible just because the optional presentation asset is unavailable.
  return false
 end
 local clone=template:Clone();if not clone then return false end;clone.Name='View_'..tostring(id);sanitize(clone)
 clone.PrimaryPart=clone.PrimaryPart or clone:FindFirstChild('Mesh') or clone:FindFirstChildWhichIsA('BasePart',true)
 local role=source:GetAttribute('Role')
 local referenceMiner=role=='Striker'
 if not referenceMiner then DroneConfig.decorate(clone,role,nil,true) end
 DroneConfig.fitBody(clone)
 pendingDroneSources[source]=nil
 local pivot=clone.PrimaryPart or clone:FindFirstChildWhichIsA('BasePart',true);if not pivot then clone:Destroy();return false end
 clone.PrimaryPart=pivot;clone.Parent=localFX
 local emitter=clone:FindFirstChild('Emmiter',true) or clone:FindFirstChild('MiningEmitter',true) or clone:FindFirstChild('Emitter',true)
 if not emitter or not emitter:IsA('BasePart') then clone:Destroy();pendingDroneSources[source]=true;return false end
 for _,part in ipairs(clone:GetDescendants()) do
  if part:IsA('BasePart') and role~='Ramiel' then part.Reflectance=0 end
 end
 local typeColor=colors[source:GetAttribute('Role')] or colors[source:GetAttribute('Type')]
 emitter.Color=typeColor or emitter.Color
 -- The original 1-stud emitter is enclosed by its 2-stud body; a restrained tint stays visible.
 if referenceMiner then
  pivot.Color=Color3.fromRGB(75,117,175);pivot.Material=Enum.Material.SmoothPlastic;pivot.MaterialVariant=''
  emitter.Color=Color3.fromRGB(42,53,73);emitter.Material=pivot.Material;emitter.MaterialVariant=''
  local panel=localPart(clone,'MinerTopPanel',pivot.Position)
  panel.Size=Vector3.new(pivot.Size.X*.75,.11,pivot.Size.Z*.58);panel.Transparency=0
  panel.Color=Color3.fromRGB(231,239,231);panel.Material=Enum.Material.SmoothPlastic
  panel.CFrame=pivot.CFrame*CFrame.new(0,pivot.Size.Y*.5+.045,0)
 elseif typeColor and not clone:GetAttribute('RoleGeometry') then
  pivot.Color=Color3.fromRGB(111,120,123):Lerp(typeColor,.18)
  -- Keep the authored shell/emitter; small case seams make its type readable in flight.
  local trim=localPart(clone,'LowerChassis',pivot.Position);trim.Size=Vector3.new(pivot.Size.X*1.015,.055,pivot.Size.Z*1.015);trim.Transparency=0;trim.Color=Color3.fromRGB(23,35,46);trim.Material=Enum.Material.Metal;trim.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.35,0)
  for _,side in ipairs({-1,1}) do
   local optic=localPart(clone,'TypeOptic',pivot.Position);optic.Size=Vector3.new(pivot.Size.X*.52,.035,.015);optic.Transparency=0;optic.Color=typeColor;optic.Material=Enum.Material.SmoothPlastic;optic.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.24,side*(pivot.Size.Z*.5+.01))
  end
 end
 hideModel(source)
 local parts={};for _,p in ipairs(clone:GetDescendants()) do if p:IsA('BasePart') then parts[p]=p.Transparency end end
 for _,child in ipairs(pivot:GetChildren()) do
  if child:IsA('Decal') and child.Face==Enum.NormalId.Front then child:Destroy() end
 end
 local face=Instance.new('Decal');face.Name='Smile';face.Face=Enum.NormalId.Front
 if role~='Ramiel' then face.Texture='rbxasset://textures/face.png';face.Parent=pivot else face:Destroy() end
 local d={source=source,view=clone,emitter=emitter,pos=pos,velocity=source:GetAttribute('Velocity') or Vector3.zero,yaw=source:GetAttribute('Yaw') or 0,life=source:GetAttribute('Life'),parts=parts,lastState=source:GetAttribute('State'),beam=createBeam(clone,emitter)}
 d.shotMuzzle=clone:FindFirstChild('ShotMuzzle',true)
 d.specialMotion=SpecialDroneMotion.new(clone,source:GetAttribute('Role'))
 if source:GetAttribute('Role')=='Ramiel' then d.ramiel=DroneConfig.ramielRig(clone) end
 drones[source]=d;droneIndex[tostring(id)]=d
 clone:PivotTo(CFrame.new(pos)*CFrame.Angles(0,d.yaw,0))
 TacticalHUD.attachHealth(clone,source,typeColor or colors.Blue)
 presentation:registerDrone(d,workspace:GetServerTimeNow())
 return true
end
local function registerResource(source)
 if resources[source] or not source:IsA('BasePart') then return end
 local id=source:GetAttribute('ResourceId');if not id then return end
 hidePart(source)
 -- Initialize from a complete current snapshot so a late join cannot replay an old break.
 for _,attribute in ipairs({'HP','MaxHP','SpawnAt','ReadyAt','FullSize','FullPosition','Stage','BreakSerial','Kind'}) do
  if source:GetAttribute(attribute)==nil then return end
 end
 local view=source:Clone();view.Name='View_Resource_'..tostring(id)
 for _,v in ipairs(view:GetDescendants()) do if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Light') then v:Destroy() end end
 view.Anchored=true;view.CanCollide=false;view.CanTouch=false;view.CanQuery=false;view.LocalTransparencyModifier=0
 view.Reflectance=source.Reflectance;view.Parent=localFX;hidePart(source)
 if source:GetAttribute('Kind')=='Junk' then
  for _,decal in ipairs(source:GetChildren()) do if decal:IsA('Decal') then hidePart(decal) end end
 end
 resources[source]={source=source,view=view,id=tostring(id),baseColor=source.Color,cutFeedback=source:GetAttribute('ZoneName') and rockDamage.feedback or nil,dirty=true,lastContactAt=source:GetAttribute('CutContactAt') or 0,lastBreakAt=source:GetAttribute('CrystalBreakAt') or 0,visual=Feel.newStagePresentation(source:GetAttribute('Stage') or 0,(source:GetAttribute('BreakSerial') or 0)>0 or (source:GetAttribute('HP') or 1)<=0,workspace:GetServerTimeNow(),source:GetAttribute('StageCount') or 3)}
 resourceIndex[tostring(id)]=resources[source]
 rockDamage:register(resources[source])
end
local function registerTurret(source)
 if turrets[source] or not source:IsA('Model') or not (source:GetAttribute('Turret') or source:GetAttribute('TurretId')) then return end
 local t=presentation:registerTurret(source,workspace:GetServerTimeNow())
 if t then turrets[source]=t;turretIndex[tostring(source:GetAttribute('TurretId'))]=source;hideModel(source);TacticalHUD.attachHealth(t.view,source,palette.danger,true) end
end
local observed={}
local function observe(source)
 if not source.Parent then return end
 if source:IsA('Decal') then
  local record=resources[source.Parent]
  if record and record.source:GetAttribute('Kind')=='Junk' then
   if not record.view:FindFirstChild(source.Name) then
    local clone=source:Clone();clone.LocalTransparencyModifier=record.view.Transparency;clone.Parent=record.view
   end
   hidePart(source)
  end
 end
 if source:IsA('BasePart') then
  local ancestor=source.Parent
  while ancestor and ancestor~=world do
   if ancestor:IsA('Model') then
    if ancestor:GetAttribute('DroneId') then if registerDrone(ancestor) then hidePart(source) end end
    if ancestor:GetAttribute('Turret') then registerTurret(ancestor);hidePart(source) end
   end
   ancestor=ancestor.Parent
  end
 end
 if source:IsA('Model') and (source:GetAttribute('DroneId') or source.Parent.Name=='Drones') then
  registerDrone(source)
  if not observed[source] then observed[source]=source.AttributeChanged:Connect(function() registerDrone(source) end) end
 elseif source:IsA('BasePart') and (source:GetAttribute('ResourceId') or source.Parent.Name=='Resources' or source.Parent:GetAttribute('FieldId')) then
  registerResource(source)
  if not observed[source] then observed[source]=source.AttributeChanged:Connect(function()
   local record=resources[source]
   if record then record.dirty=true else registerResource(source) end
  end) end
 elseif source:IsA('BasePart') and source.Parent:IsA('Model') and drones[source.Parent] then hidePart(source)
 end
 if source:IsA('Model') and (source:GetAttribute('Turret') or source:GetAttribute('TurretId') or source.Parent.Name=='Turrets' or source.Parent:GetAttribute('FieldId')) then
  registerTurret(source)
  if not observed[source] then observed[source]=source.AttributeChanged:Connect(function() registerTurret(source) end) end
 end
end
connect(world.DescendantAdded,function(source) task.defer(observe,source) end)
connect(RS.DescendantAdded,function()
 if next(pendingDroneSources) and not templateRetryQueued then
  templateRetryQueued=true;task.defer(function()
   templateRetryQueued=false
   for source in pairs(pendingDroneSources) do if source.Parent then registerDrone(source) else pendingDroneSources[source]=nil end end
  end)
 end
end)
for _,source in ipairs(world:GetDescendants()) do observe(source) end
local function destroyDrone(d)
 droneIndex[tostring(d.source:GetAttribute('DroneId'))]=nil
 if d.healBeam then d.healBeam:Destroy() end
 BeamVFX.destroy(d.healVFX)
 if d.healMuzzle then d.healMuzzle:Destroy() end
 if d.healTarget then d.healTarget:Destroy() end
 presentation:destroyDrone(d)
 presentation:destroyMiningBeam(d.beam);d.view:Destroy()
end
connect(world.DescendantRemoving,function(source)
 pendingDroneSources[source]=nil
 if drones[source] then destroyDrone(drones[source]);drones[source]=nil end
 if resources[source] then rockDamage.feedback:forget(resources[source]);rockDamage:remove(resources[source]);resourceIndex[resources[source].id]=nil;resources[source].view:Destroy();resources[source]=nil end
 if turrets[source] then turretIndex[tostring(source:GetAttribute('TurretId'))]=nil;presentation:destroyTurret(turrets[source]);turrets[source]=nil end
 if observed[source] then observed[source]:Disconnect();observed[source]=nil end
 hiddenParts[source]=nil
end)
local function resourceById(id) return resourceIndex[tostring(id)] end
local function renderResource(r,now)
 -- Mature, unchanged rocks need no repeated attribute reads, trigonometry or
 -- geometry writes. Spawn growth is animated; mining size changes are snaps.
 if r.settled and not r.dirty then return end
 r.dirty=false
 local s=r.source;local view=r.view
 -- Locked fields remain visible destinations; the server still gates mining.
 local full=s:GetAttribute('FullSize') or s.Size
 if type(full)=='number' then full=Vector3.one*full end
 local final=s:GetAttribute('FullPosition') or s.Position
 local spawnAt=s:GetAttribute('SpawnAt') or now-2
 local readyAt=s:GetAttribute('ReadyAt') or spawnAt+2
 local junk=s:GetAttribute('Kind')=='Junk'
 local reference=s:GetAttribute('ReferenceCrystal')==true
 -- The open Mining Away uses the full-size crystal during its readiness delay.
 local growth=1
 if not junk and not reference then
  growth=Feel.growth(now,spawnAt)
  if readyAt-spawnAt~=2 then local g=math.clamp((now-spawnAt)/math.max(.01,readyAt-spawnAt),0,1);growth=1-(1-g)^2 end
 end
 local stageCount=s:GetAttribute('StageCount') or 3
 local authoritativeStage=math.clamp(s:GetAttribute('Stage') or 0,0,stageCount)
 local health=s:GetAttribute('HP') or 1
 local broken=(s:GetAttribute('BreakSerial') or 0)>0 or health<=0
 if r.cutFeedback and not r.visual.broken then
  if broken then
   local breakAt=s:GetAttribute('CrystalBreakAt') or s:GetAttribute('CutContactAt') or 0
   if breakAt>0 and CrystalImpactView.releaseAt(s,breakAt)>now then r.dirty=true;return end
  elseif authoritativeStage>r.visual.knownStage and s:GetAttribute('CutIsShot') then
   local contact=s:GetAttribute('CutContactAt') or 0
   if contact>now then r.dirty=true;return end
   if contact~=(r.fractureContact or 0) and now-contact<.21 and not CrystalImpactView.reducedMotion() then
    r.fractureContact=contact;r.fractureUntil=now+.045
   end
   if now<(r.fractureUntil or 0) then r.dirty=true;return end
  end
 end
 local healed=s:GetAttribute('RegrowAt') or 0
 if not broken and healed>0 then
  if authoritativeStage<r.visual.knownStage then
   r.visual=Feel.newStagePresentation(authoritativeStage,false,now,stageCount);r.crackHealth=nil
  end
  if healed~=(r.lastHeal or 0) and now-healed<.4 then selectorView:heal(view,now) end
  r.lastHeal=healed
 end
 local event=Feel.updateStagePresentation(r.visual,authoritativeStage,broken,now,stageCount)
 local stage=r.visual.stage
 local period=Feel.stageScale(stage,stageCount)
 if not r.visual.broken then
  view.Transparency=s:GetAttribute('Kind')=='Geode' and .04 or s.Transparency
  local heat=s:GetAttribute('MeltBand') or 0
  local shape=s:GetAttribute('ZoneName') and Feel.crystalStageShape(stage,stageCount) or period
  local displaySize=full*math.max(.005,growth)*shape*Feel.rockShape(s:GetAttribute('SliceScale'),heat)
  view.Size=displaySize*(r.damageScale or Vector3.one)
  local start=s:GetAttribute('StartPosition') or Vector3.new(final.X,final.Y-2-full.Y/2,final.Z)
  local pos=start:Lerp(final,growth)
  local seed=s:GetAttribute('StageSeed') or 0
  local ground=s:GetAttribute('GroundY')
  local frame
  if type(ground)=='number' then frame=Feel.groundedRockFrame(pos,displaySize,ground,stage,seed,s:GetAttribute('CubicRock')==false,reference)
  else frame=CFrame.new(pos)*CFrame.Angles(0,seed*.01,0) end
  if junk then
   if now<readyAt then
    frame=JunkField.fallPose(now-spawnAt,frame)
    if now<spawnAt then view.Transparency=1 end
   end
  end
  view.CFrame=frame*CFrame.new(displaySize*(r.damageOffset or Vector3.zero))
  local maxHealth=s:GetAttribute('MaxHP') or 1
  local color=r.baseColor:Lerp(Color3.fromRGB(237,105,46),heat*.11)
  if junk then
   view.Color=color:Lerp(Color3.new(0,0,0),Feel.junkDarkness(health,maxHealth,stage,stageCount))
  else
   -- Mining Away changes the size stage first and applies its new shade on the next hit.
   if event=='stage' then r.crackHealth=health end
   local shadeStage=r.crackHealth==health and stage-1 or stage
   local shadeHealth=shadeStage<stage and math.max(health,maxHealth*period) or health
   view.Color=color:Lerp(Color3.new(0,0,0),1-Feel.crystalShade(shadeHealth,maxHealth,shadeStage,stageCount))
  end
 else view.Transparency=1 end
 if junk then
  for _,decal in ipairs(view:GetChildren()) do
   if decal:IsA('Decal') then decal.LocalTransparencyModifier=view.Transparency end
  end
 end
 if not r.visual.broken then
  r.restPose=view.CFrame;r.restColor=view.Color
 end
 if event=='stage' then
  -- The source plays from Crystal.Primary, not the visible union.
  crystalAudio:playCrack(reference and (final-Vector3.yAxis*Feel.ReferenceCrystalPivot) or view.Position)
 end
 rockDamage:update(r,now)
 r.settled=now>=readyAt
end
local function resolveRenderedTarget(kind,id,allowBreaking)
 if type(id)~='string' or id=='' then return nil end
 if kind=='resource' then
  local r=resourceById(id)
  if r and r.source.Parent and (allowBreaking or ((r.source:GetAttribute('BreakSerial') or 0)==0 and (r.source:GetAttribute('HP') or 0)>0))
   and r.view.Parent and not r.visual.broken then return r.view,r.source,r end
 elseif kind=='turret' then
  for source,t in pairs(turrets) do
   if source.Parent and source:GetAttribute('TurretId')==id and source:GetAttribute('Dead')~=true and (source:GetAttribute('HP') or 0)>0
    and t.view and t.view.Parent then
    -- spawnEye is the original slightly larger visible eye shell around eye.
    local eye=t.view:FindFirstChild('spawnEye',true) or t.eye
    if eye and eye:IsA('BasePart') and eye.Parent and eye.Transparency<.99 then return eye,source,nil end
   end
  end
 end
 return nil
end
local function renderDrone(d,dt,now)
 local previousPosition=d.pos
 local s=d.source;local state=s:GetAttribute('State') or 'Follow'
 local referenceMiner=s:GetAttribute('Role')=='Striker'
 local logical=s:GetAttribute('Position');local goal=s:GetAttribute('Goal') or logical
 if typeof(logical)~='Vector3' or typeof(goal)~='Vector3' then return end
 d.lastState=state
 local life=s:GetAttribute('Life');local maxStep=s:GetAttribute('MaxStep60') or .35
 if life~=d.life then d.life=life;d.pos=logical;d.velocity=s:GetAttribute('Velocity') or Vector3.zero end
 local motionPaused=s:GetAttribute('MotionPaused')==true
 local owner=(referenceMiner or state=='Follow') and Players:GetPlayerByUserId(s:GetAttribute('Owner') or 0)
 local hr=owner and owner.Character and owner.Character:FindFirstChild('HumanoidRootPart')
 if state=='Follow' and not motionPaused then
  local slot=s:GetAttribute('FormationSlot');local count=s:GetAttribute('FleetCount')
  if hr and slot and count then
   goal=Feel.followGoal(hr.Position,slot,count,now,(s:GetAttribute('PhaseSeed') or maxStep*200)/200)
  end
 end
 if state=='Destroyed' or state=='Reprinting' then d.pos=logical;d.velocity=Vector3.zero
 elseif not motionPaused and (state=='BreakerDive' or state=='BreakerImpact') then
  -- A powered fall accelerates all the way into the surface. Evaluate the
  -- authoritative stroke directly: destination smoothing here brakes before
  -- contact and puts landing effects ahead of the visible weight.
  local impact=s:GetAttribute('BreakerImpact') or goal
  if state=='BreakerDive' then
   d.pos,d.velocity=Feel.powerDive(s:GetAttribute('BreakerDiveStart') or logical,impact,
    now-(s:GetAttribute('BreakerPhaseAt') or now),s:GetAttribute('BreakerDiveDuration') or .28)
  else
   -- The impact plane is a hard stop, followed by the server-owned weight hold.
   d.pos=impact;d.velocity=Vector3.zero
  end
 elseif not motionPaused then
  local workTravel=state=='ToCharge' or state=='Charging' or state=='Deliver' or state=='BreakerDive' or state=='BreakerRecover' or state=='Recover' or state=='Plant' or state=='GrowApproach' or (s:GetAttribute('TargetId') or '')~=''
  local error=logical-d.pos
  local correction=error.Magnitude>5 and error.Unit*math.min((error.Magnitude-5)*.8,maxStep*60*.25) or Vector3.zero
  if referenceMiner and world:GetAttribute('FieldToolsEnabled')==false then
   d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,maxStep,math.min(dt,.1),workTravel,correction,1.35)
  elseif referenceMiner then d.pos,d.velocity=Feel.referenceFlight(d.pos,goal,maxStep,math.min(dt,.1),correction)
  else d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,maxStep,math.min(dt,.1),workTravel,correction) end
 end
 if not motionPaused then
  local targetYaw=referenceMiner and state=='Follow' and Feel.referenceYaw(previousPosition,goal,maxStep,hr and hr.CFrame.LookVector,d.yaw)
   or Feel.flightYaw(d.pos,goal,d.velocity,d.yaw)
  if state=='Mine' and referenceMiner then targetYaw=d.workingYaw or d.yaw;d.workingYaw=targetYaw
  else d.workingYaw=nil end
  if d.shotMuzzle and (state=='Warmup' or state=='SpecialMine') then
   local aim=s:GetAttribute('TargetPosition')
   if typeof(aim)=='Vector3' then targetYaw=Feel.levelYaw(d.pos,aim,d.yaw) end
  end
  local difference=math.atan2(math.sin(targetYaw-d.yaw),math.cos(targetYaw-d.yaw))
  d.yaw=d.yaw+difference*Feel.turnAlpha(math.min(dt,.1))
 end
 local velocity=dt>0 and (d.pos-previousPosition)/dt or Vector3.zero
 local sideVelocity=CFrame.Angles(0,d.yaw,0):VectorToObjectSpace(velocity).X
 local desiredBank=(referenceMiner or state=='Mine' or state=='SpecialMine' or state=='BreakerDive' or state=='BreakerImpact' or state=='Destroyed' or state=='Reprinting' or motionPaused) and 0 or math.clamp(-sideVelocity*.005,-math.rad(3),math.rad(3))
 d.bank=state=='BreakerImpact' and 0 or (d.bank or 0)+(desiredBank-(d.bank or 0))*(1-math.exp(-math.min(dt,.1)*5))
 local grounded=d.ramiel and state=='SpecialMine' or state=='BreakerDive' or state=='BreakerImpact' or (s:GetAttribute('Role')=='Compactor' and (state=='Intake' or state=='Press'))
 local drift=(referenceMiner or state=='Destroyed' or state=='Reprinting' or motionPaused or grounded) and 0 or math.sin(now*1.6+(s:GetAttribute('PhaseSeed') or 0))*((state=='Mine' or state=='SpecialMine') and .05 or .10)
 -- The server issues one silent recall cue. A short lift and settling nod
 -- communicate the return before the familiar inertial following takes over.
 -- Reading server time makes every observer see the same hop, and late joins
 -- never replay an old recall.
 local recallAt=s:GetAttribute('RecallAt') or -100
 local recallAge=now-recallAt;local hop,recallPitch=0,0
 if not referenceMiner and not motionPaused and (state=='Follow' or state=='Return') and recallAge>=0 and recallAge<.72 then
  local p=recallAge/.72
  hop=math.sin(math.pi*p)^2*.9
  recallPitch=math.sin(2*math.pi*p)*math.rad(7)
 end
 d.view:PivotTo(CFrame.new(d.pos+Vector3.new(0,drift+hop,0))*CFrame.Angles(0,d.yaw,0)
  *CFrame.Angles(recallPitch,0,d.bank))
 if d.specialMotion then
  local target=resourceIndex[tostring(s:GetAttribute('TargetId') or '')]
  SpecialDroneMotion.step(d.specialMotion,s,target and target.source,now,dt,d.shotReceipt)
 end
 if d.ramiel and (BeamVFX.near(d.pos,120) or not d.ramielNeutral) then
  local near=BeamVFX.near(d.pos,120)
  d.ramielNeutral=not near
  local shot=near and d.shotReceipt
  local charge,recovery,aim=0,nil,nil
  local reduced=CrystalImpactView.reducedMotion()
  if shot and shot.Parent and (s:GetAttribute('HP') or 0)>0 then
   local started=shot:GetAttribute('StartedAt') or now
   local paused=shot:GetAttribute('PausedAt') or 0
   local age=(paused>0 and math.min(now,paused) or now)-started
   local windup=math.max(.01,shot:GetAttribute('Windup') or 1.94)
   local contactAt=shot:GetAttribute('ContactAt')
   local fireAge=contactAt and (paused>0 and math.min(now,paused) or now)-contactAt
   local waiting=age<windup+(shot:GetAttribute('Duration') or .06)+.29
   if age>=0 and (fireAge and fireAge<DroneConfig.RamielRecovery or not fireAge and waiting) then
    aim=shot:GetAttribute('Position')
    charge=math.clamp(age/windup,0,1)
    recovery=fireAge and fireAge>=0 and fireAge or nil
   end
  end
  local energy=DroneConfig.poseRamiel(d.ramiel,d.view:GetPivot(),aim,charge,recovery,reduced and 0 or now*.38%6.283,reduced)
  RoleEffectView.ramielCharge(d.ramiel,charge,energy,recovery,reduced or BeamVFX.reduced() or player:GetAttribute('ReducedFlashing')==true)
 end
 if s:GetAttribute('Role')=='Compactor' then
  local at=s:GetAttribute('PressAt') or 0
  if at>0 and now>=at+Workshop.PRESS_CONTACT and now-at<Workshop.PRESS_CONTACT+.18 and d.pressSoundAt~=at then
   d.pressSoundAt=at;soundscape:play('metal_land',d.emitter.Position,{pitch=.84,level=.68})
   presentation.work:burst(d.emitter.Position-Vector3.yAxis*.48,Vector3.yAxis,Color3.fromRGB(255,198,118),12,now)
  end
  if at>0 and now>=at+Workshop.PRESS_EJECT and now-at<Workshop.PRESS_EJECT+.18 and d.pressEjectAt~=at then
   d.pressEjectAt=at;soundscape:play('parcel_latch',d.emitter.Position,{pitch=1.12,level=.75})
   presentation.work:burst(d.emitter.Position,Vector3.yAxis,Color3.fromRGB(255,228,164),7,now)
  end
 end
 local reprintAt=s:GetAttribute('ReprintAt') or 0
 local alive=state~='Destroyed' and state~='Reprinting' and (s:GetAttribute('HP') or 1)>0
 presentation:syncMiningHardware(d,alive)
 for part,original in pairs(d.parts) do
  if state=='Destroyed' then part.Transparency=1
  elseif state=='Reprinting' then part.Transparency=math.max(original,math.clamp((reprintAt-now)/2,0,1))
  elseif not (d.ramiel and part.Parent and part.Parent.Name=='RamielGlass') then part.Transparency=original end
 end
 presentation:renderDrone(d,dt,now)
 local mining=s:GetAttribute('Mining')==true and s:GetAttribute('WorkPaused')~=true
 local attacking=state=='Attack' and s:GetAttribute('Firing')==true and s:GetAttribute('WorkPaused')~=true
 local active=alive and (mining or attacking)
 local charging=alive and state=='Warmup' and not mining and s:GetAttribute('WorkPaused')~=true and (s:GetAttribute('WarmupStart') or 0)>0
 local beam=d.beam
 local kind=state=='Attack' and 'turret' or 'resource'
 local id=s:GetAttribute(kind=='turret' and 'CombatTargetId' or 'TargetId')
 if active and type(id)=='string' and id~='' then beam.lastKey=id;beam.lastKind=kind
 elseif not active and not charging and state~='SpecialMine' and beam.lastKey then id=beam.lastKey;kind=beam.lastKind end
 local part,source,resource=resolveRenderedTarget(kind,id,active and kind=='resource')
 if d.shotMuzzle then
  RoleEffectView.aim(d,alive and not motionPaused and s:GetAttribute('WorkPaused')~=true
   and (state=='Warmup' or state=='SpecialMine') and resource or nil)
 end
 local procKind=state=='Attack' and 'turret' or 'resource'
 local procId=s:GetAttribute(procKind=='turret' and 'ChainTargetId' or 'ForkTargetId')
 local procUntil=s:GetAttribute(procKind=='turret' and 'ChainUntil' or 'ForkUntil') or 0
 local extra,extraSource
 if active and now<procUntil then extra,extraSource=resolveRenderedTarget(procKind,procId) end
 local beamSince=state=='Attack' and (s:GetAttribute('ShotAt') or now) or (s:GetAttribute('BeamSince') or now)
 local specialReleaseAt
 if state=='SpecialMine' and source and source:GetAttribute('EffectDrone')==s:GetAttribute('DroneId') then
  local started=source:GetAttribute('EffectStartedAt')
  if started and started>=now-.16 and started<=now then specialReleaseAt=started end
 end
 local breakAt,breakUntil
 -- A final hit retires the gameplay reservation immediately. Its short saved
 -- contact may finish the local fracture sequence while the drone moves on.
 -- Hold the previous visible contact through the split before showing a new
 -- assignment. A save pause, recall, death or hidden mesh clears the contact.
 local finalAt=s:GetAttribute('MineBreakAt') or 0
 local finalUntil=s:GetAttribute('MineBreakUntil') or 0
 if alive and not motionPaused and s:GetAttribute('WorkPaused')~=true and (s:GetAttribute('MineBreakSerial') or 0)>0
  and now>=finalAt and now<math.min(finalUntil,finalAt+.3) then
  local primaryId=s:GetAttribute('MineBreakPrimaryId')
  local finalPart,finalSource,finalResource=resolveRenderedTarget('resource',primaryId,true)
  if finalPart then
   part,source,resource=finalPart,finalSource,finalResource;id=primaryId;kind='resource';active=true;charging=false
   procId=s:GetAttribute('MineBreakSecondaryId')
   extra,extraSource=resolveRenderedTarget('resource',procId,true)
   beamSince=s:GetAttribute('MineBreakBeamSince') or now;breakAt=finalAt;breakUntil=finalUntil
  end
 end
 presentation:queueMiningBeam(beam,{alive=alive,active=active,key=id,life=life,
  contact=active,
  isMining=kind=='resource',charging=charging,specialReleaseAt=specialReleaseAt,
  warmupStart=s:GetAttribute('WarmupStart') or 0,warmupDuration=s:GetAttribute('WarmupDuration') or .8,mineralColor=resource and resource.baseColor,
  style=state=='Attack' and 'Cutter' or s:GetAttribute('MiningStyle'),droneType=s:GetAttribute('Type'),droneRole=s:GetAttribute('Role'),paused=s:GetAttribute('MotionPaused')==true or s:GetAttribute('WorkPaused')==true,
  pulseSerial=s:GetAttribute('MinePulseSerial') or 0,pulseAt=s:GetAttribute('MinePulseAt') or 0,pulseKey=s:GetAttribute('MinePulseTargetId'),
  since=beamSince,breakContactAt=breakAt,breakContactUntil=breakUntil,
  part=part,serverSource=source,resource=resource,secondaryPart=extra,secondarySource=extraSource,
  secondaryKey=procId,secondaryColor=state=='Attack' and Color3.fromRGB(255,179,102) or nil},now)

end
-- Every observer draws repair beams between the current rendered emitters.
-- Surface queries rotate through active healers; stale visibility expires.
local healCursor=0
local function renderHealing(now)
 local candidates={}
 for _,d in pairs(drones) do
  local id=d.source:GetAttribute('HealTargetId');local target=type(id)=='string' and droneIndex[id]
  local active=(d.source:GetAttribute('Healing')==true or d.source:GetAttribute('State')=='RepairCharge') and d.source:GetAttribute('MotionPaused')~=true and d.source:GetAttribute('WorkPaused')~=true
   and (d.source:GetAttribute('HP') or 0)>0 and target and (target.source:GetAttribute('HP') or 0)>0
   and d.emitter.Parent and target.emitter.Parent
  if active then table.insert(candidates,{drone=d,target=target})
  else
   if d.healBeam then d.healBeam.Transparency=1 end
   BeamVFX.destroy(d.healVFX);d.healVFX=nil
  end
 end
 table.sort(candidates,function(a,b) return tostring(a.drone.source:GetAttribute('DroneId'))<tostring(b.drone.source:GetAttribute('DroneId')) end)
 local count=#candidates
 for n=1,math.min(4,count) do
  local item=candidates[(healCursor+n-1)%count+1];local d,target=item.drone,item.target
  local from,to=d.emitter.Position,target.emitter.Position
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
  local ignore={localFX,world:FindFirstChild('Drones') or d.source}
  for _,owner in ipairs(Players:GetPlayers()) do if owner.Character then table.insert(ignore,owner.Character) end end
  params.FilterDescendantsInstances=ignore;params.IgnoreWater=true
  d.healVisible=(to-from).Magnitude<=16 and not workspace:Raycast(from,to-from,params)
  d.healCheckedAt=now;d.healCheckedTarget=target
 end
 if count>0 then healCursor=(healCursor+math.min(4,count))%count end
 for _,item in ipairs(candidates) do
  local d,target=item.drone,item.target
  if not d.healBeam then d.healBeam=WorkEffects.newCylinder(d.view,'RepairBeam',Color3.fromRGB(141,209,151)) end
  local visible=d.healVisible==true and d.healCheckedTarget==target and now-(d.healCheckedAt or 0)<.2
  local charging=d.source:GetAttribute('State')=='RepairCharge'
  local q=charging and math.clamp((now-(d.source:GetAttribute('RepairChargeAt') or now))/(d.source:GetAttribute('RepairChargeDuration') or .4),0,1) or 1
  if visible then
   d.healVFX=d.healVFX or BeamVFX.new(d.view,'Repair',Color3.fromRGB(141,209,151))
   if d.healVFX then
    d.healBeam.Transparency=1
    BeamVFX.draw(d.healVFX,d.emitter.Position,target.emitter.Position,now,charging and .18+.25*q or 1,charging and q or nil,nil)
   else WorkEffects.drawCylinder(d.healBeam,d.emitter.Position,target.emitter.Position,charging and .01+.014*q or .052,charging and (.8-.35*q) or .12) end
  else d.healBeam.Transparency=1;BeamVFX.hide(d.healVFX,true) end
 end
end

-- The carried inventory belongs to the character. These local, non-colliding
-- props are drawn for every player and follow their torso, including late joins.
local backpacks={}
local function renderBackpacks()
 local present={}
 for _,owner in ipairs(Players:GetPlayers()) do
  present[owner]=true
  local character=owner.Character
  local torso=character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'))
  local record=backpacks[owner]
  if record and (not torso or record.character~=character) then record.model:Destroy();backpacks[owner]=nil;record=nil end
  if torso and torso:IsA('BasePart') then
   if not record then
    local model=Instance.new('Model');model.Name='Backpack_'..owner.UserId;model.Parent=localFX
    local function piece(name,size,offset,color,material)
     local part=localPart(model,name,torso.Position);part.Size=size;part.Color=color;part.Material=material
     part.Reflectance=0;part.Transparency=0;part.CastShadow=true;part.CFrame=torso.CFrame*offset
     return {part=part,offset=offset}
    end
    record={model=model,character=character,parts={}}
    table.insert(record.parts,piece('Pack',Vector3.new(1.4,1.6,.65),CFrame.new(0,0,.8),Color3.fromRGB(88,97,76),Enum.Material.Fabric))
    table.insert(record.parts,piece('Flap',Vector3.new(1.46,.25,.71),CFrame.new(0,.65,.8),Color3.fromRGB(69,77,62),Enum.Material.Fabric))
    for _,side in ipairs({-1,1}) do table.insert(record.parts,piece('Strap',Vector3.new(.14,1.65,.08),CFrame.new(side*.46,0,1.16),Color3.fromRGB(52,56,48),Enum.Material.Fabric)) end
    backpacks[owner]=record
   end
   for _,item in ipairs(record.parts) do item.part.CFrame=torso.CFrame*item.offset end
  end
 end
 for owner,record in pairs(backpacks) do if not present[owner] then record.model:Destroy();backpacks[owner]=nil end end
end

local specialMiningFX=DroneFX.new(world,{resolve=function(source) local record=resources[source];return record and record.view end,
 focus=function() local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart');return hr and hr.Position end})
local laserShowcase=LaserShowcase.new(world,localFX,DroneConfig)
local chargerView=ChargerView.new(world,localFX,CrystalImpactView.reducedMotion)
connect(RunService.RenderStepped,function(dt)
 local now=workspace:GetServerTimeNow()
 local map=world:FindFirstChild('Map')
 local reserve=map and map:FindFirstChild('LiminalReserve')
 local clouds=reserve and reserve:FindFirstChild('CloudBlocks')
 if clouds then
  -- Authored blocks stay at their centers in Edit. Animate locally from a
  -- shared clock so the scenery needs no replicated transform updates.
  for _,cloud in ipairs(clouds:GetChildren()) do
   local center=cloud:GetAttribute('DriftCenter')
   local drift=cloud:GetAttribute('DriftVector')
   local period=cloud:GetAttribute('DriftPeriod')
   if cloud:IsA('BasePart') and center and drift and period and period>0 then
    local phase=(now%period)/period*(2*math.pi)+(cloud:GetAttribute('DriftPhase') or 0)
    cloud.Position=center+drift*math.sin(phase)
   end
  end
 end
 presentation:beginFrame()
 chargerView:update(dt)
 pickupView:update(dt,now)
 for _,r in pairs(resources) do
  local dirty=r.dirty
  renderResource(r,now)
  if dirty or (r.nextContactAt and now>=r.nextContactAt) or r.kick or r.breakSize or r.finalLoad or r.vibrating or (r.cutUntil or 0)>now then
   rockDamage.feedback:react(r,now)
  end
 end
 rockDamage.feedback:step(now)
 selectorView:updateHealing(now)
 rockDamage:step(now)
 specialMiningFX:step(now,dt)
 for _,t in pairs(turrets) do
  if fieldUnlocked(t.source.Parent) and (t.source:GetAttribute('HP') or 0)>0 then
   t.view.Parent=nil;t.cue.Transparency=1;t.beam.Enabled=false;t.flare.Enabled=false;t.light.Brightness=0
  else
   if not t.view.Parent then t.view.Parent=localFX end
   presentation:renderTurret(t,dt,now)
  end
 end
 for _,d in pairs(drones) do renderDrone(d,dt,now) end
 roleEffectView:step(now,droneIndex,resourceIndex)
 renderHealing(now);renderBackpacks()
 presentation:flushMiningBeams()
 rockDamage.feedback:applyTints(now)
 presentation:update(dt,now)
 laserShowcase:step(now,dt)
 if logisticsView then logisticsView:step(now,dt) end
 if toolView then toolView:step(dt,now) end
end)

local evade=button(safeRoot,UDim2.new(1,-136,1,-108),UDim2.fromOffset(118,38),'Evade  [Q]',function() command:FireServer('Evade') end,palette.accent);evade.Visible=false
local testLoadout=button(safeRoot,UDim2.new(1,-252,0,80),UDim2.fromOffset(236,44),'Random loadout · 2–5 [T]',function() command:FireServer('TestLoadout') end,Color3.fromRGB(139,83,224))
testLoadout.Name='RandomLoadoutTester';testLoadout.Visible=false
local function cargoAction()
 command:FireServer('Sell')
end
local unload=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(116,40),'Sell [U]',cargoAction,palette.paper)
unload.Name='ReturnCargo';unload.Visible=false
local enemyHUD=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(300,58),palette.panel,12);enemyHUD.Name='SentryHealth';enemyHUD.Visible=false
local enemyTitle=label(enemyHUD,UDim2.fromOffset(12,0),UDim2.new(1,-24,1,0),'PYRAMID SENTRY',12,palette.white,true)
local enemyHealth=frame(enemyHUD,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(53,55,57));enemyHealth.Name='HealthTrack';enemyHealth.ClipsDescendants=true;enemyHealth.BackgroundTransparency=1;corner(enemyHealth,3)
local enemyFill=frame(enemyHealth,UDim2.fromScale(0,0),UDim2.fromScale(1,1),palette.danger);enemyFill.Name='Fill';corner(enemyFill,3);U.gradient(enemyFill)
enemyTitle.ZIndex=enemyFill.ZIndex+2
local tacticalHUD=TacticalHUD.new({interface=U,root=safeRoot,gui=gui,modal=modal,recall=recall,unload=unload,test=testLoadout,evade=evade,resources=hud,context=context,enemy=enemyHUD,toast=toast,
 cargoText=cargoText,cargoTrack=cargoTrack,profile=function() return profile end,hidden=menusVisible,
 starterReachable=function() return selectorView:canReachStarterPlot() end,
 depotApproach=function(pin)
  local character=player.Character
  local hr=character and character:FindFirstChild('HumanoidRootPart')
  local counter=world:GetAttribute('PackCounterPosition')
  return hr and counter and Mining.onDepotApproach(hr.Position,pin,counter,
   world:GetAttribute('DepotFloorFrame'),world:GetAttribute('DepotFloorSize'))
 end})
logisticsView=LogisticsView.start({interface=U,parent=safeRoot,world=world,localFX=localFX,command=command,dock=tacticalHUD.dock,context=context,
 profile=function() return profile end,hidden=function() return modal.Visible or inspectingFleet() end,
 blocks=function(point) return tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) end,
 onOpen=function() modal.Visible=false end,onVisibility=syncModalTouch,
 openFleet=openFleet,openCards=openRunCards,
 notify=function(message) notice.Text=message;noticeUntil=os.clock()+5 end})
if world:GetAttribute('FieldToolsEnabled')==true then
 toolView=ToolView.new({interface=U,parent=safeRoot,world=world,localFX=localFX,command=command,
  audio=soundscape,presentation=presentation,hidden=menusVisible,
  blocks=function(point) return tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) or (toolView and toolView:blocks(point-game:GetService('GuiService'):GetGuiInset())) end,
  onSelect=function() logisticsView.selected=nil end})
end
local function ownerRoot() return player.Character and player.Character:FindFirstChild('HumanoidRootPart') end
local function stationAction(station)
 local kind=station:GetAttribute('Interaction')
 if kind=='Shop' then
  local key=station:GetAttribute('ShopKey')
  if key=='Quartz' and profile then return openShop end
  return nil
 elseif kind=='Stars' then
  return openStars
 elseif kind=='Printer' then return function() logisticsView:toggle() end,'Drone yard','Manage your permanent fleet and transport','Browse'
 elseif kind=='Prestige' then return openPrestige,'Prestige','Keep your drones · gain permanent mining power','Review'
 elseif kind=='Sell' then
  return cargoAction,'Sell ore','Your backpack becomes spendable minerals immediately','Sell'
 end
 return nil
end
local lastStationUse=0
local function performStation(station)
 local action=stationAction(station)
 local hr=ownerRoot();local prompt=station:FindFirstChildOfClass('ProximityPrompt')
 if not hr or not prompt or not prompt.Enabled or (hr.Position-station.Position).Magnitude>prompt.MaxActivationDistance+1 then return end
 if menusVisible() then return end
 if action and os.clock()-lastStationUse>.25 then lastStationUse=os.clock();menuStation=station;action() end
end
connect(game:GetService('ProximityPromptService').PromptTriggered,function(prompt,who)
 if (not who or who==player) and prompt.Parent and prompt.Parent:IsA('BasePart') then performStation(prompt.Parent) end
end)
local function requestField(id)
 if menusVisible() then return end
 if logisticsView and logisticsView:dispatchField(id) then return end
 local fields=world:FindFirstChild('Fields')
 if fields then for _,field in ipairs(fields:GetChildren()) do
  if (field:GetAttribute('FieldId') or field:GetAttribute('Tier'))==id then
   command:FireServer('Patch',id)
   return
  end
 end end
end
local commandView=CommandView.new({parent=localFX,resources=resourceIndex,drones=drones,command=command,
 profile=function() return profile end,hidden=function() return menusVisible() or logisticsView.selected~=nil or (toolView and toolView:selected()~=nil) end,
 touchPoint=function()
  local touch=selectorView.touch
  return touch and touch.active and touch.input.Position or nil
 end,
 blocks=function(point) return tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) end})
connect(RunService.RenderStepped,function(dt) commandView:update(dt,workspace:GetServerTimeNow()) end)
connect(gui.Parent:GetAttributeChangedSignal('MA_CommandState'),function()
 local ok,state=pcall(Http.JSONDecode,Http,gui.Parent:GetAttribute('MA_CommandState') or '')
 if not ok or type(state)~='table' then return end
 commandView:reply(state)
 soundscape:play(state.status=='rejected' and 'denied' or 'command')
 if state.status=='rejected' then notice.Text=state.reason or '';noticeUntil=os.clock()+2.2 end
end)
local function assignField(target)
 if menusVisible() then return end
 local node=target
 while node and node~=workspace do
  local resourceId=node:GetAttribute('ResourceId')
  if type(resourceId)=='string' and resourceId~='' then
   if node.Parent and node.Parent.Parent and node.Parent.Parent.Name=='CrystalRun' then return end
   local fieldId=node:GetAttribute('FieldId')
   if type(fieldId)=='number' and logisticsView and logisticsView.selected then requestField(fieldId);return end
   commandView:request(resourceId)
   return
  end
  local owner=node:GetAttribute('Owner')
  if owner==player.UserId and node:GetAttribute('DroneId') then return end
  local field=node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier')
  if node:GetAttribute('CrystalZone') or (node.Parent and node.Parent.Name=='CrystalRun') then return end
  if type(field)=='number' then requestField(field);return end
  node=node.Parent
 end
end
local mouse=player:GetMouse()
connect(RunService.RenderStepped,function(dt)
 local camera=workspace.CurrentCamera
 local ray
 if camera and not menusVisible() then
  local touch=selectorView.touch
  local input=UIS:GetLastInputType()
  if touch and touch.active then
   local point=touch.input.Position
   ray=camera:ViewportPointToRay(point.X,point.Y)
  elseif input.Name:match('^Gamepad') then
   local size=camera.ViewportSize
   ray=camera:ViewportPointToRay(size.X*.5,size.Y*.5)
  elseif UIS.MouseEnabled and input~=Enum.UserInputType.Touch then
   local point=UIS:GetMouseLocation()-game:GetService('GuiService'):GetGuiInset()
   if not tacticalHUD:blocksPoint(point) then ray=mouse.UnitRay end
  end
 end
 selectorView:showAim(dt,ray)
end)
connect(UIS.TouchTapInWorld,function(position,processed)
 if processed or menusVisible() or tacticalHUD:blocksPoint(position) then return end
 if toolView and toolView:click(position) then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local ray=camera:ScreenPointToRay(position.X,position.Y)
 if selectorView:commit(ray) then return end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={localFX,player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 if hit then assignField(hit.Instance) end
end)
connect(UIS.InputBegan,function(input,processed)
 if inspectingFleet() then
  local key=input.KeyCode
  if key==Enum.KeyCode.Escape or key==Enum.KeyCode.ButtonB then closeFleetInspection(true)
  elseif key==Enum.KeyCode.Left then fleetView:cycle(-1)
  elseif key==Enum.KeyCode.Right then fleetView:cycle(1) end
  return
 end
 if toolView and toolView:input(input,processed) then return end
 if input.KeyCode==Enum.KeyCode.Escape and logisticsView:isOpen() then logisticsView:close();return end
 if input.KeyCode==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false;return end
 if processed or UIS:GetFocusedTextBox() then return end
 if input.UserInputType==Enum.UserInputType.Touch then
  if selectorView.touch then selectorView.touch.active=false
  elseif not menusVisible() then selectorView.touch={input=input,start=input.Position,active=true} end
  return
 end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then
  local point=UIS:GetMouseLocation()
  if not tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) then
   if selectorView:commit(mouse.UnitRay) then return end
   commandView:beginDrag();assignField(mouse.Target)
  end
  return
 end
 local key=input.KeyCode
 if menusVisible() and not modal.Visible then return end
 if key==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false
 elseif not modal.Visible and (key==Enum.KeyCode.R or key==Enum.KeyCode.F or key==Enum.KeyCode.ButtonB) then if not logisticsView:recall() then command:FireServer('Recall') end
 elseif not modal.Visible and key==Enum.KeyCode.U then cargoAction()
 elseif not modal.Visible and key==Enum.KeyCode.L then command:FireServer('LaunchStorage')
 elseif not modal.Visible and key==Enum.KeyCode.C then logisticsView:cycle()
 elseif not modal.Visible and (key==Enum.KeyCode.Q or key==Enum.KeyCode.ButtonX) then command:FireServer('Evade')
 elseif not modal.Visible and (key==Enum.KeyCode.T or key==Enum.KeyCode.ButtonY) and player:GetAttribute('MA_TestingEnabled')==true then command:FireServer('TestLoadout')
 elseif key==Enum.KeyCode.ButtonR1 and not menusVisible() then
  local camera=workspace.CurrentCamera
  if camera then local ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2);if selectorView:commit(ray) then return end;local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={localFX,player.Character};local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params);if hit then assignField(hit.Instance) end end
 elseif not modal.Visible then
  -- Number keys belong to the custom tool hotbar. Field commands use rocks.
 end
end)
connect(UIS.InputChanged,function(input)
 local touch=selectorView.touch
 if touch and touch.input==input and (input.Position-touch.start).Magnitude>14 then touch.active=false end
end)
connect(UIS.InputEnded,function(input)
 if selectorView.touch and selectorView.touch.input==input then selectorView.touch=nil end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then commandView:endDrag() end
end)
local hudClock=0
local availabilitySignature=''
connect(RunService.Heartbeat,function(dt)
 hudClock=hudClock+dt;if hudClock<.2 then return end;hudClock=0
 local view=viewport();local l=currentLayout();local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 fleetButton.Visible=profile~=nil and not menusVisible()
 fleetButton.Position=UDim2.new(1,-74,0,view.X<680 and 84 or 12)
 if inspectingFleet() and not fleetView.installed then refreshFleetInspection() end
 if packView.counter and profile then
  local offer=pending()
  packView.counter.ActionText=offer and (offer.opened==false and 'Find your crate' or 'Choose card') or 'Buy pack'
  packView.counter.ObjectText=offer and 'Pack Counter' or (comma(profile.nextPackPrice or 20)..' Quartz')
 end
 if menuStation then
  local hr=ownerRoot();local prompt=menuStation:FindFirstChildOfClass('ProximityPrompt')
  if not menuStation.Parent or not hr or not prompt or (hr.Position-menuStation.Position).Magnitude>prompt.MaxActivationDistance+3 then
   if modalMode~='offer' then modal.Visible=false end
   logisticsView:close();menuStation=nil
  end
 end
 recall.Position=UDim2.fromOffset(l.recallX,l.recallY);evade.Position=UDim2.fromOffset(l.evadeX,l.evadeY)
 recall.Size=UDim2.fromOffset(l.recallWidth,44);evade.Size=recall.Size
 recall.Text=touch and 'Recall' or 'Recall [R]';recall.Visible=not menusVisible()
 local testWidth=math.min(236,view.X-86)
 testLoadout.Size=UDim2.fromOffset(testWidth,44);testLoadout.Position=UDim2.fromOffset(view.X-testWidth-(view.X<680 and 80 or 16),(view.X<680 or l.short) and 72 or 80)
 testLoadout.Text=touch and 'Random loadout · 2–5' or 'Random loadout · 2–5 [T]'
 testLoadout.Visible=player:GetAttribute('MA_TestingEnabled')==true and not menusVisible()
 if modal.Visible and (not modalSize or (modalSize-view).Magnitude>1) then refreshModal() end
 if modal.Visible and (modalMode=='offer' or modalMode=='prestige' or modalMode=='shop' or modalMode=='stars') then
  local action=modalMode=='offer' and 'ChooseCard' or modalMode=='shop' and 'BuyUpgrade' or modalMode=='stars' and 'BuyStarUpgrade' or 'Prestige'
  local allowed,reason=availability(action);local signature=modalMode..':'..tostring(allowed)..':'..reason
  if signature~=availabilitySignature then availabilitySignature=signature;if modalMode=='offer' then updateOfferControls() else refreshModal() end end
 end
 if actionPending and os.clock()-actionPending.at>10 and not (profile and profile.pendingTransaction) then
  if actionPending==offerUI.claim then offerUI.claim=nil end
  actionPending=nil;notice.Text='Still waiting for confirmation. You can retry.';noticeUntil=os.clock()+5;refreshModal()
 end
 if os.clock()>noticeUntil then notice.Text='' end
 local status=tostring(player:GetAttribute('MA_SaveStatus') or 'Loading'):lower()
 if status:find('preview') then saveLabel.Text=l.hudWidth<310 and 'UNSAVED PREVIEW' or 'PREVIEW · NOT SAVED'
 elseif status:find('loading') then saveLabel.Text='CONNECTING'
 elseif status:find('unavailable') then saveLabel.Text='PROFILE UNAVAILABLE'
 elseif status:find('saved') then saveLabel.Text='CREDITS · AUTOSAVED'
 else saveLabel.Text='SAVE PAUSED' end
 saveLabel.TextSize=12;saveLabel.Position=UDim2.new(1,-180,1,-24);saveLabel.Size=UDim2.fromOffset(168,20);saveLabel.TextXAlignment=Enum.TextXAlignment.Right
 saveLabel.Visible=not menusVisible() and (status:find('preview')~=nil or not status:find('saved'))
 saveLabel.TextColor3=status:find('preview') and Color3.fromRGB(255,211,96) or palette.muted
 if profile and profile.run then
  local amount=cargoUnits(profile);local capacity=profile.capacity or 10
  cargoText.Text=string.format('Cargo %s / %s slots',comma(amount),comma(capacity))
  cargoFill.Size=UDim2.fromScale(math.clamp(amount/math.max(1,capacity),0,1),1)
  cargoFill.BackgroundColor3=amount>=capacity and palette.accent or palette.mineral

 end
 local ownActive=false;local reprints={};local now=workspace:GetServerTimeNow()
 for source in pairs(drones) do
  if source:GetAttribute('Owner')==player.UserId then
   local state=source:GetAttribute('State');if state=='Attack' then ownActive=true end
   local at=source:GetAttribute('ReprintAt') or 0
   if at>now then table.insert(reprints,string.format('%s reprinting: %ds',source:GetAttribute('DroneName') or source:GetAttribute('Name') or 'Drone',math.ceil(at-now))) end
  end
 end
 evade.Visible=ownActive and not menusVisible();evade.Text=touch and 'Evade shot' or 'Evade [Q]'
 soundscape:setContext(ownActive,menusVisible())
 hud.Visible=not menusVisible() and not (l.short and ownActive)
 if not ownActive and (l.mobile or touch) and not l.actionAtTop then recall.Position=UDim2.fromOffset((view.X-l.recallWidth)/2,l.recallY) end
 if #reprints>0 and os.clock()>noticeUntil then notice.Text=#reprints>2 and tostring(#reprints)..' drones reprinting for free' or table.concat(reprints,' · ') end
 local hr=ownerRoot();local nearestEnemy,dist=nil,65
 if hr then for turret in pairs(turrets) do if turret.Parent then
  local hp=turret:GetAttribute('HP') or 0;local rootPart=turret.PrimaryPart or turret:FindFirstChildWhichIsA('BasePart',true)
  local n=rootPart and (rootPart.Position-hr.Position).Magnitude or math.huge
  if not fieldUnlocked(turret.Parent) and hp>0 and n<dist then nearestEnemy=turret;dist=n end
 end end end
 enemyHUD.Visible=nearestEnemy~=nil and ownActive and not menusVisible()
 local enemyWidth=math.min(300,view.X-24)
 enemyHUD.Size=UDim2.fromOffset(enemyWidth,58)
 enemyHUD.Position=(l.short or view.X<680) and UDim2.fromOffset(l.hudX,l.short and l.hudY or l.objectiveY) or UDim2.fromOffset(view.X-enemyWidth-16,12)
 if nearestEnemy then
  local hp=nearestEnemy:GetAttribute('HP') or 0;local maxHP=nearestEnemy:GetAttribute('MaxHP') or 1
  local charging=nearestEnemy:GetAttribute('Telegraph')
  enemyFill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,maxHP),0,1),1)
  enemyTitle.Text=charging and (touch and 'CHARGING · EVADE NOW' or 'CHARGING · EVADE [Q]') or string.format('PYRAMID SENTRY  %d / %d',math.ceil(hp),maxHP)
  enemyTitle.TextColor3=charging and Color3.fromRGB(255,195,195) or palette.white
 end
 local toastWidth=math.min(420,view.X-24)
 if l.short then toastWidth=l.hudWidth end
 toast.Size=UDim2.fromOffset(toastWidth,50)
 toast.Position=UDim2.fromOffset((view.X-toastWidth)/2,view.X>=1100 and 12 or (l.objectiveY+(enemyHUD.Visible and 66 or 0)))
 toast.Visible=notice.Text~='' and not menusVisible() and not (l.short and ownActive)
 if l.short then toast.Position=UDim2.fromOffset(l.hudX,l.hudY);if toast.Visible then hud.Visible=false end end
 if modal.Visible and notice.Text~='' and noticeUntil>os.clock() then
  modalSubtitle.Text=notice.Text;modalSubtitle.TextColor3=(modalMode=='offer' or modalMode=='pack') and palette.white or palette.text
 else modalSubtitle.Text=normalSubtitle;modalSubtitle.TextColor3=(modalMode=='offer' or modalMode=='pack') and Color3.fromRGB(202,209,231) or palette.muted end
 tacticalHUD:update(view,world,ownActive)
 unload.Text=touch and 'Sell' or 'Sell [U]'
 logisticsView:update(view,ownActive)
end)
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),refreshModal)
connect(gui.Destroying,function()
 local controls=player.PlayerGui:FindFirstChild('TouchGui');if controls and previousTouchEnabled~=nil then controls.Enabled=previousTouchEnabled end
 fleetView:destroy();packView:destroy();commandView:destroy();selectorView:destroy();pickupView:destroy();rockDamage:destroy();roleEffectView:destroy();impactConnection:Disconnect()
 specialMiningFX:destroy();laserShowcase:destroy();logisticsView:destroy();chargerView:destroy()
 rockDamage.feedback:destroy()
 for _,record in pairs(orbitalBurns) do record.connection:Disconnect() end
 orbitalBurns={}
 for source in pairs(roleAudio) do soundscape:stopLoop(source) end;roleAudio={}
 RunService:UnbindFromRenderStep('MiningAwayCameraRestore');RunService:UnbindFromRenderStep('MiningAwayCameraFeedback')
 if shakeCamera and workspace.CurrentCamera==shakeCamera then shakeCamera.CFrame=shakeCamera.CFrame*previousShake:Inverse() end
 abilityView.destroy()
 if toolView then toolView:destroy() end
 tacticalHUD:destroy()
 crystalAudio:destroy()
 soundscape:destroy()
 presentation:destroy()
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,c in pairs(observed) do c:Disconnect() end
 for part in pairs(hiddenParts) do if part.Parent then part.LocalTransparencyModifier=0 end end
 localFX:Destroy()
end)
