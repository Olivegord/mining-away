-- Presentation and bounded intent only. Gameplay never reads these local viewmodels.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local TweenService=game:GetService('TweenService')
local Debris=game:GetService('Debris')
local player=Players.LocalPlayer
local world=workspace:WaitForChild('MiningAway')
local command=RS:WaitForChild('MiningAway'):WaitForChild('Command')
local localFX=Instance.new('Folder');localFX.Name='MiningAwayPresentation';localFX.Parent=workspace
local soundscape=Soundscape.new(localFX)
local presentation=Presentation.new({parent=localFX,audio=soundscape})
local pickupView=PickupView.new(world,localFX,soundscape)
local previousShake=CFrame.new();local shakeCamera=nil
local orbitalBurns={};local burnShakeAt=0
RunService:BindToRenderStep('MiningAwayCameraRestore',Enum.RenderPriority.Camera.Value-1,function()
 if shakeCamera and workspace.CurrentCamera==shakeCamera then shakeCamera.CFrame=shakeCamera.CFrame*previousShake:Inverse() end
 previousShake=CFrame.new();shakeCamera=nil
end)
RunService:BindToRenderStep('MiningAwayCameraFeedback',Enum.RenderPriority.Camera.Value+1,function()
 local camera=workspace.CurrentCamera
 local now=workspace:GetServerTimeNow()
 for source in pairs(orbitalBurns) do
  if not source.Parent then orbitalBurns[source]=nil
  else
   local ended=source:GetAttribute('EndedAt')~=nil
   local active=not ended and now-(source:GetAttribute('ContactAt') or 0)<.3
   for _,part in ipairs(source:GetDescendants()) do
    if ended then
     if part:IsA('BasePart') then part.LocalTransparencyModifier=0 end
     -- Emit(5) afterglow particles continue after the work emitter stops.
     continue
    end
    if part:IsA('BasePart') then part.LocalTransparencyModifier=active and 0 or 1
    elseif part:IsA('ParticleEmitter') then part.Enabled=active end
   end
   if active and now>=burnShakeAt then
    presentation:kick(source:GetAttribute('Position') or Vector3.zero,.13,now)
   end
  end
 end
 if now>=burnShakeAt then burnShakeAt=now+.075 end
 if camera and player:GetAttribute('ReducedMotion')~=true and player:GetAttribute('MA_ReducedMotion')~=true then
  previousShake=presentation:cameraOffset(workspace:GetServerTimeNow());shakeCamera=camera;camera.CFrame=camera.CFrame*previousShake
 end
end)
local function roleImpact(source)
 if source:IsA('Folder') and source:GetAttribute('OrbitalBurn') then
  orbitalBurns[source]=true;soundscape:play('orbital',source:GetAttribute('Position'))
 end
 if source:IsA('BasePart') and source:GetAttribute('MiningImpact') then
  local now=workspace:GetServerTimeNow();local at=source:GetAttribute('ImpactAt') or 0
  if math.abs(now-at)<.7 then
   presentation:kick(source.Position,source:GetAttribute('MiningImpact')=='Orbital' and .15 or .14,now)
   soundscape:play(source:GetAttribute('MiningImpact')=='Orbital' and 'orbital' or 'mining',source.Position)
  end
 end
end
local impactConnection=workspace.DescendantAdded:Connect(function(source) if source:IsA('BasePart') or source:IsA('Folder') then task.defer(roleImpact,source) end end)
local existingRoleFX=workspace:FindFirstChild('DroneRoleServerEffects')
if existingRoleFX then for _,source in ipairs(existingRoleFX:GetChildren()) do roleImpact(source) end end

local drones,resources,resourceIndex,turrets,connections={},{},{},{},{}
local droneIndex={}
local renderSwarmGrid=nil
local turretIndex={}
local hiddenParts={}
local pendingDroneSources={}
local templateRetryQueued=false
local profile=nil
local U=Interface
local palette=U.palette
local DroneConfig=require(RS:WaitForChild('Shared'):WaitForChild('DroneConfig'))
local TacticalHUD=require(RS.Shared:WaitForChild('TacticalHUD'))
local colors={Blue=Color3.fromRGB(99,198,246),Red=Color3.fromRGB(243,117,112),Green=Color3.fromRGB(122,219,163),Dart=Color3.fromRGB(87,220,255),Striker=Color3.fromRGB(255,210,86),Medic=Color3.fromRGB(99,255,164),Charger=Color3.fromRGB(255,112,72)}
for _,name in ipairs(DroneConfig.TypeOrder) do colors[name]=DroneConfig.Types[name].Color end
local gui=Instance.new('ScreenGui');gui.Name='MiningAwayHUD';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=12;gui.Parent=player:WaitForChild('PlayerGui')
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
local openOffer,openPack,openPrestige,openFleet,openRunCards,openShop
local activeShop,shopInfo='Quartz',nil
local hud=U.panel(safeRoot,UDim2.fromOffset(16,12),UDim2.fromOffset(290,64));hud.Name='Resources';hud.Active=true
U.icon(hud,'crystal',UDim2.fromOffset(9,10),UDim2.fromOffset(34,34),Color3.fromRGB(255,208,70))
local creditsLabel=label(hud,UDim2.fromOffset(50,5),UDim2.new(1,-158,0,28),'Quartz 0',18,palette.ink,true);creditsLabel.Name='Credits'
local shopButton=button(safeRoot,UDim2.new(1,-150,0,6),UDim2.fromOffset(44,44),'Shops',function() if openShop then openShop(activeShop) end end,palette.mineral);shopButton.Name='OpenShops';shopButton.TextSize=16
local saveLabel=label(safeRoot,UDim2.new(1,-188,0,12),UDim2.fromOffset(172,22),'',16,palette.muted,true);saveLabel.Name='SaveStatus';saveLabel.Visible=false;saveLabel.TextXAlignment=Enum.TextXAlignment.Right
local cargoText=label(hud,UDim2.fromOffset(50,34),UDim2.new(1,-158,0,18),'Backpack 0 / 40',11,palette.muted,true)
local cargoTrack=frame(hud,UDim2.fromOffset(50,53),UDim2.new(1,-164,0,4),palette.paper);corner(cargoTrack,2)
local cargoFill=frame(cargoTrack,UDim2.fromScale(0,0),UDim2.fromScale(0,1),palette.mineral);corner(cargoFill,3)
local fleetButton=button(hud,UDim2.new(1,-104,0,10),UDim2.fromOffset(46,44),'',function() if openFleet then openFleet() end end,Color3.fromRGB(48,145,221));fleetButton.Name='OpenFleet'
U.icon(fleetButton,'drone',UDim2.fromOffset(13,2),UDim2.fromOffset(22,22),colors.Blue)
local fleetCount=label(fleetButton,UDim2.fromOffset(0,24),UDim2.new(1,0,0,17),'Fleet',9,palette.ink,true);fleetCount.TextXAlignment=Enum.TextXAlignment.Center
local runButton=button(hud,UDim2.new(1,-54,0,10),UDim2.fromOffset(46,44),'',function() if profile and profile.run.pendingOffer then openOffer() else openRunCards() end end,Color3.fromRGB(139,83,224));runButton.Name='OpenRunCards'
U.icon(runButton,'cards',UDim2.fromOffset(13,2),UDim2.fromOffset(22,22),palette.accent)
local runCount=label(runButton,UDim2.fromOffset(0,24),UDim2.new(1,0,0,17),'Cards',9,palette.ink,true);runCount.TextXAlignment=Enum.TextXAlignment.Center
local objectiveBox=U.panel(safeRoot,UDim2.fromOffset(16,108),UDim2.fromOffset(360,48),palette.panel,10);objectiveBox.Name='NextStep'
U.icon(objectiveBox,'crystal',UDim2.fromOffset(9,9),UDim2.fromOffset(27,27),palette.mineral)
local objective=label(objectiveBox,UDim2.fromOffset(43,5),UDim2.new(1,-52,1,-10),'Mine rocks, collect the fragments, then sell.',12,palette.ink)
local toast=U.panel(safeRoot,UDim2.fromOffset(0,170),UDim2.fromOffset(420,50),palette.panel,12);toast.Name='Feedback';toast.ZIndex=80;toast.Visible=false
local notice=label(toast,UDim2.fromOffset(14,6),UDim2.new(1,-28,1,-12),'',13,palette.ink,true);notice.TextXAlignment=Enum.TextXAlignment.Center
local recall=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(118,44),'Recall [R]',function() command:FireServer('Recall') end,Color3.fromRGB(66,177,91));recall.Name='Recall'
local context=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(420,72),palette.panel,14);context.Name='ContextAction';context.Active=true;context.Visible=false
local contextIcon=U.icon(context,'mining',UDim2.fromOffset(12,17),UDim2.fromOffset(34,34),palette.mineral)
local contextTitle=label(context,UDim2.fromOffset(55,6),UDim2.new(1,-174,0,30),'',18,palette.ink,true)
local contextDetail=label(context,UDim2.fromOffset(55,35),UDim2.new(1,-174,0,27),'',11,palette.muted)
local contextAction=nil
local contextButton=button(context,UDim2.new(1,-112,0,14),UDim2.fromOffset(100,44),'Use [E]',function() if contextAction then contextAction() end end)
contextButton.Name='UseContext'
local modal=frame(safeRoot,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(3,9,18));modal.Name='MenuLayer';modal.BackgroundTransparency=.22;modal.Visible=false;modal.ZIndex=20;modal.Active=true
local sheet=U.panel(modal,UDim2.fromOffset(12,12),UDim2.fromOffset(1010,664),palette.panel,20);sheet.Name='MenuSheet';sheet.ZIndex=21
local sheetScale=Instance.new('UIScale');sheetScale.Parent=sheet
local offerHeader=U.panel(sheet,UDim2.fromOffset(0,0),UDim2.new(1,0,0,100),palette.panel,4);offerHeader.Name='OfferHeader';offerHeader.ZIndex=sheet.ZIndex;offerHeader.Visible=false
local modalEmblem=U.icon(sheet,'cards',UDim2.fromOffset(20,19),UDim2.fromOffset(54,54),palette.mineral)
local modalTitle=label(sheet,UDim2.fromOffset(90,18),UDim2.new(1,-158,0,39),'Build your next adventure',30,palette.ink,true)
local modalSubtitle=label(sheet,UDim2.fromOffset(24,66),UDim2.new(1,-48,0,32),'',12,palette.muted)
local close=button(sheet,UDim2.new(1,-62,0,16),UDim2.fromOffset(44,44),'X',function() modal.Visible=false end,palette.danger);close.Name='CloseMenu';close.TextColor3=palette.white;close:FindFirstChildOfClass('UIGradient').Enabled=false
local body=Instance.new('ScrollingFrame');body.Name='MenuContent';body.Position=UDim2.fromOffset(24,112);body.Size=UDim2.new(1,-48,1,-136);body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=4;body.ScrollBarImageColor3=palette.muted;body.CanvasSize=UDim2.fromScale(0,0);body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.ZIndex=22;body.Parent=sheet
local modalMode,modalSize=nil,nil
local actionPending=nil
local function clearBody() for _,x in ipairs(body:GetChildren()) do x:Destroy() end;body.CanvasPosition=Vector2.zero end
local function tx() return Http:GenerateGUID(false) end
local function send(action,data)
 if not profile or not profile.run or actionPending or profile.pendingTransaction then return false end
 data=data or {};data.txId=tx();data.runId=profile.run.id
 actionPending={kind=action,at=os.clock(),runId=profile.run.id,packIndex=profile.run.packIndex,offerId=profile.run.pendingOffer and profile.run.pendingOffer.id,upgradeId=data.upgradeId,level=data.level}
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
 if modalMode=='shop' then
  l.panelWidth=math.min(760,v.X-24);l.panelHeight=math.min(566,v.Y-24);l.panelPadding=16;l.headerHeight=100
  l.bodyWidth=l.panelWidth-32;l.bodyHeight=math.max(1,l.panelHeight-116);l.panelX=(v.X-l.panelWidth)/2;l.panelY=(v.Y-l.panelHeight)/2
 end
 if modalMode=='offer' and l.cardColumns==3 then
  l.panelHeight=math.min(l.panelHeight,l.headerHeight+l.cardHeight+32)
  l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-l.panelPadding)
  l.panelY=math.floor((v.Y-l.panelHeight)*.65)
 end
 sheet.Size=UDim2.fromOffset(l.panelWidth,l.panelHeight);sheet.Position=UDim2.fromOffset(l.panelX,l.panelY);modalSize=v
 offerHeader.Size=UDim2.new(1,0,0,l.headerHeight-12)
 body.Position=UDim2.fromOffset(l.panelPadding,l.headerHeight);body.Size=UDim2.fromOffset(l.bodyWidth,l.bodyHeight)
 modalTitle.TextSize=l.panelWidth<400 and 23 or 30
 modalTitle.Position=UDim2.fromOffset(l.panelWidth<400 and 74 or 90,16)
 modalTitle.Size=UDim2.new(1,l.panelWidth<400 and -136 or -158,0,43)
 modalEmblem.Size=UDim2.fromOffset(l.panelWidth<400 and 42 or 54,l.panelWidth<400 and 42 or 54)
 modalEmblem.Position=UDim2.fromOffset(18,18)
 modalSubtitle.Position=UDim2.fromOffset(l.panelPadding,l.short and 58 or 66)
 modalSubtitle.Size=UDim2.new(1,-l.panelPadding*2,0,l.short and 29 or 32)
 return l
end
local menuTween=nil
local normalSubtitle=''
local function menu(mode,title,subtitle,icon)
 local entering=not modal.Visible or modalMode~=mode
 modalMode=mode;clearBody();local l=layoutModal();modalTitle.Text=title;modalSubtitle.Text=subtitle;normalSubtitle=subtitle
 local inOffer=mode=='offer';modal.BackgroundTransparency=inOffer and 1 or .22;sheet.BackgroundTransparency=inOffer and 1 or 0;offerHeader.Visible=inOffer
 local border=sheet:FindFirstChildOfClass('UIStroke');if border then border.Transparency=inOffer and 1 or 0 end
 if l.panelWidth<400 then
  local shortTitles={shop=activeShop..' shop',pack='Upgrade pack',offer='Pick a card',fleet='Your crew',run='Run upgrades',prestige='Grow your fleet'}
  modalTitle.Text=shortTitles[mode] or title;modalTitle.TextSize=mode=='prestige' and 18 or 20
 end
 if modalEmblem then modalEmblem:Destroy() end
 modalEmblem=U.icon(sheet,icon,UDim2.fromOffset(18,18),UDim2.fromOffset(l.panelWidth<400 and 42 or 54,l.panelWidth<400 and 42 or 54),palette.mineral)
 modal.Visible=true
 if entering then
  if menuTween then menuTween:Cancel() end
  sheetScale.Scale=.98;menuTween=TweenService:Create(sheetScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1});menuTween:Play()
 end
 return l
end
local function atHomeUI()
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart');local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local hub=world.Map:FindFirstChild('HubPad',true)
 local depot=world:GetAttribute('DepotHome') or (hub and hub.Position) or (spawn and spawn.Position)
 return hr and depot and (hr.Position-depot).Magnitude<30
end
local function availability(action)
 if not profile then return false,'Connecting…' end
 if actionPending or profile.pendingTransaction then return false,'Waiting for confirmation…' end
 if player:GetAttribute('MA_InAssault') then return false,'Recall your fighting drones first' end
 if action=='BuyUpgrade' then
  if not Shops.unlocked(profile,activeShop) then
   local index=table.find(Shops.ORDER,activeShop) or 1
   return false,'Unlock '..activeShop..' in the '..Shops.ORDER[math.max(1,index-1)]..' shop'
  end
  local station=world.Map:FindFirstChild(activeShop..'Shop',true)
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  if not station or not hr or (station.Position-hr.Position).Magnitude>=20 then return false,'Visit the '..activeShop..' shop to buy' end
  return true,''
 end
 if not atHomeUI() then return false,'Return to the depot' end
 local stationName=action=='BuyPack' and 'PackStation' or action=='Prestige' and 'PrestigeStation' or nil
 if stationName then
  local station=world.Map:FindFirstChild(stationName,true)
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  if not station or not hr or (hr.Position-station.Position).Magnitude>=20 then return false,action=='BuyPack' and 'Visit the card machine to open' or 'Visit the fleet uplink to prestige' end
 end
 return true,''
end
local function canAct(action) return availability(action or 'ChooseCard') end
local function number(n)
 if math.abs(n)>=1000 then return comma(n) end
 if math.abs(n-math.floor(n+.5))<.001 then return tostring(math.floor(n+.5)) end
 return string.format('%.3g',n)
end
local function previewRows(choice)
 local result={}
 for _,item in ipairs(choice.preview or {}) do
  if type(item)=='table' then
   local before,after=tonumber(item.before),tonumber(item.after)
   if before and after then
    local title,unit=item.label or 'Effect',item.unit or ''
    if title=='Flight / 60Hz' then title='Flight';before=before*60;after=after*60;unit='studs/s' end
    if unit~='%' and (title=='Turret resistance' or title=='Critical chance' or title=='Combat splash' or title=='Mining fork') then before=before*100;after=after*100;unit='%' end
    if title=='Shared cargo' then title='Backpack';unit='ore' end
    local separator=(unit=='' or unit=='%' or unit=='×') and '' or ' '
    if title=='Plot targeting' or title=='Auto empty' then
     table.insert(result,title..'  '..(before>0 and 'Automatic' or 'Manual')..' → '..(after>0 and 'Automatic' or 'Manual'))
    else table.insert(result,title..'  '..number(before)..' → '..number(after)..separator..unit) end
    if #result==4 then break end
   end
  end
 end
 return result
end
local function targetText(choice)
 if choice.cardId=='A02' then return 'YOUR COURIERS' end
 if choice.scope=='Individual' then return 'ONE DRONE / '..(choice.targetName or 'Assigned drone') end
 if choice.scope=='Color' then return 'ALL '..string.upper(choice.type or '')..' DRONES' end
 return choice.scope=='Player' and 'YOUR BACKPACK' or 'ENTIRE FLEET'
end
local function categoryText(choice)
 local e=choice.effects or {}
 local function gain(k) return type(e[k])=='number' and e[k]>0 end
 -- Category reflects the benefit, not a negative hull/mining tradeoff in an old saved payload.
 if gain('combat') or gain('rate') or gain('crit') or gain('splash') or gain('finisher') then return 'COMBAT' end
 if gain('health') or gain('reduction') or gain('shield') or gain('salvage') then return 'SURVIVAL' end
 if gain('capacity') or gain('yield') then return 'CARGO' end
 if gain('mining') or gain('fork') or gain('geode') then return 'MINING' end
 if gain('startup') then return 'LASER' end
 return 'FLIGHT'
end
local function stackText(choice)
 if choice.stackText then return choice.stackText end
 local count=0
 for _,owned in ipairs(profile.run.cards or {}) do if owned.cardId==choice.cardId and (choice.scope~='Individual' or owned.targetDroneId==choice.targetDroneId) then count=count+1 end end
 local reserve=string.sub(choice.cardId or '',1,1)=='R'
 local limit=(choice.scope=='Fleet' or choice.scope=='Player') and 2 or 1
 return reserve and 'Repeatable until its stat cap.' or string.format('Copy %d / %d · adds to base',count+1,limit)
end
local function progress(parent,y,width,title,detail,fraction,color)
 label(parent,UDim2.fromOffset(0,y),UDim2.fromOffset(width,22),title,17,palette.ink,true)
 label(parent,UDim2.fromOffset(0,y+27),UDim2.fromOffset(width,27),detail,12,palette.muted)
 local track=frame(parent,UDim2.fromOffset(0,y+62),UDim2.fromOffset(width,10),palette.paper);track.ClipsDescendants=true;corner(track,3)
 local fill=frame(track,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(fraction,0,1),1),color);corner(fill,3)
end
openOffer=function()
 local offer=pending();if not offer then return end
 local l=menu('offer','Pick a card','Choose one · This run','cards')
 local list=Instance.new('UIListLayout');list.FillDirection=l.cardColumns==3 and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical;list.Padding=UDim.new(0,l.cardGap);list.HorizontalAlignment=Enum.HorizontalAlignment.Center;list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 for index,choice in ipairs(offer.choices) do
  local view
  view=CardView.create(U,body,choice,index,l.cardColumns==3 and l.cardWidth-4 or math.min(460,l.cardWidth-6),l.cardHeight,{revealSpeed=profile.packSpeed or 1,category=categoryText(choice),target=targetText(choice),previewRows=previewRows(choice),stackText=stackText(choice),onChoose=function()
   if not pending() or pending().id~=offer.id or not canAct() then return end
   if send('ChooseCard',{offerId=offer.id,index=index}) then
    for _,card in ipairs(body:GetChildren()) do if card:IsA('Frame') then local b=card:FindFirstChild('ChooseCard');if b then enableAction(b,false);b.Text=card==view.root and 'Installing…' or 'Please wait' end end end
   end
  end})
  local usable=canAct();enableAction(view.button,usable)
  if not usable then local _,reason=availability('ChooseCard');view.button.Text=reason end
 end
end
openPack=function()
 if pending() then openOffer();return end
 if not profile or not profile.run then return end
 local l=menu('pack','A stronger build starts here','Three cards. Pick the upgrade your crew needs.','cards')
 local width=l.bodyWidth-6
 local narrow=l.bodyWidth<400
 local hero=U.panel(body,UDim2.fromOffset(3,3),UDim2.fromOffset(width,180),palette.mineral:Lerp(palette.white,.72),16)
 U.icon(hero,'cards',UDim2.fromOffset(narrow and 18 or 20,24),UDim2.fromOffset(narrow and 64 or 90,narrow and 64 or 90),palette.mineral)
 local price=profile.nextPackPrice or 40;local credits=Shops.balance(profile,'Quartz');local affordable=credits>=price
 local priceText=comma(price)
 local heroTextX=narrow and 94 or 125
 label(hero,UDim2.fromOffset(heroTextX,17),UDim2.new(1,narrow and -heroTextX-16 or -145,0,25),'UPGRADE PACK '..tostring(profile.run.packIndex+1),13,palette.muted,true)
 local priceSize=narrow and (#priceText>12 and 14 or (#priceText>8 and 18 or 23)) or 35
 label(hero,UDim2.fromOffset(heroTextX,47),UDim2.new(1,narrow and -heroTextX-16 or -145,0,narrow and 62 or 45),priceText..(narrow and '\nQuartz' or ' Quartz'),priceSize,palette.ink,true)
 label(hero,UDim2.fromOffset(22,126),UDim2.new(1,-44,0,39),narrow and 'Three saved choices. Pick one upgrade for this run.' or 'Mining power, combat tricks or a smarter cargo run. All three choices are saved before you pick.',12,palette.ink)
 progress(body,207,width,'Your pack fund',comma(credits)..' / '..comma(price)..' Quartz',credits/math.max(1,price),palette.accent)
 local allowed,blocked=availability('BuyPack')
 local text=not allowed and blocked or (affordable and 'Open pack · '..comma(price)..' Quartz' or 'Sell '..comma(price-credits)..' more Quartz')
 local buy
 buy=button(body,UDim2.fromOffset(3,302),UDim2.fromOffset(width,50),text,function()
  if canAct('BuyPack') and affordable and send('BuyPack',{packIndex=profile.run.packIndex}) then buy.Text='Opening…';enableAction(buy,false) end
 end,palette.accent);buy.Name='BuyPack';enableAction(buy,canAct('BuyPack') and affordable)
 label(body,UDim2.fromOffset(8,374),UDim2.fromOffset(width-10,50),'Cards reset at prestige. Your permanent drones stay yours.',12,palette.muted)
end
openShop=function(key,info)
 if not profile or not profile.run.wallet then return end
 activeShop=Shops.COLORS[key or activeShop] and (key or activeShop) or 'Quartz';shopInfo=info
 local allowed,reason=availability('BuyUpgrade')
 local l=menu('shop',activeShop..' shop',allowed and 'Pick an upgrade. Info explains the full effect.' or reason,'crystal')
 ShopView.render(U,body,{profile=profile,shop=activeShop,width=l.bodyWidth-4,info=shopInfo,canBuy=allowed,
  onShop=function(nextShop) openShop(nextShop) end,onInfo=function(id) openShop(activeShop,id) end,
  onBuy=function(entry,level)
   if canAct('BuyUpgrade') and send('BuyUpgrade',{upgradeId=entry.id,level=level}) then openShop(activeShop,shopInfo) end
  end})
end
local function statTile(parent,x,y,width,title,value,color)
 local tile=frame(parent,UDim2.fromOffset(x,y),UDim2.fromOffset(width,55),palette.panel);corner(tile,9)
 label(tile,UDim2.fromOffset(10,5),UDim2.new(1,-20,0,15),title,10,palette.muted,true)
 label(tile,UDim2.fromOffset(10,24),UDim2.new(1,-20,0,26),value,20,color or palette.ink,true)
end
local function tabs(width,mode)
 local a=button(body,UDim2.fromOffset(3,3),UDim2.fromOffset((width-14)/2,44),'Permanent fleet',openFleet,mode=='fleet' and palette.mineral or palette.paper)
 local b=button(body,UDim2.fromOffset((width-14)/2+11,3),UDim2.fromOffset((width-14)/2,44),'This run · '..#profile.run.cards,openRunCards,mode=='run' and palette.accent or palette.paper)
 a.Name='FleetTab';b.Name='RunTab'
end
openFleet=function()
 if not profile then return end
 local crew=profile.activeFleet or profile.fleet
 local l=menu('fleet','Meet your crew',profile.activeFleet and ('Studio role test · '..#crew..' active drones · '..#profile.fleet..' permanent owned') or 'Your drones stay with you. Run upgrades change the stats below.','drone');local width=l.bodyWidth-6
 tabs(width,'fleet')
 local rosterY=64
 if player:GetAttribute('MA_TestingEnabled')==true then
  local half=(width-12)/2
  local reroll=button(body,UDim2.fromOffset(3,57),UDim2.fromOffset(half,44),'Random 2–5 [T]',function() command:FireServer('TestLoadout');modal.Visible=false end,palette.paper)
  reroll.Name='RerollTestCrew';rosterY=114
  local roles=button(body,UDim2.fromOffset(half+15,57),UDim2.fromOffset(half,44),'Role crew · 8',function() command:FireServer('RoleLoadout');modal.Visible=false end,palette.mineral);roles.Name='RestoreRoleCrew'
 end
 local columns=width>=650 and 2 or 1;local gap=14;local rowWidth=(width-gap*(columns-1))/columns
 for index,d in ipairs(crew or {}) do
  local stats=(profile.droneStats and profile.droneStats[d.id]) or d.effective or d.base or {}
  local x=((index-1)%columns)*(rowWidth+gap)+3;local y=rosterY+math.floor((index-1)/columns)*276
  local tint=colors[d.type] or palette.mineral
  local row=U.panel(body,UDim2.fromOffset(x,y),UDim2.fromOffset(rowWidth,258),tint:Lerp(palette.white,.80),14);row.Name='FleetDrone'..index
  U.icon(row,'drone',UDim2.fromOffset(13,14),UDim2.fromOffset(62,62),tint)
  label(row,UDim2.fromOffset(87,14),UDim2.new(1,-102,0,33),d.name or ('Drone '..index),24,palette.ink,true)
  local identity=label(row,UDim2.fromOffset(87,50),UDim2.new(1,-102,0,24),(profile.activeFleet and 'TEST CREW' or 'PERMANENT')..' · '..string.upper(d.role or d.type or 'Blue'),10,palette.muted,true)
  local count=0;for _,c in ipairs(profile.run.cards) do if c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Color' and c.type==d.type) or (c.scope=='Individual' and c.targetDroneId==d.id) then count=count+1 end end
  identity.Text=identity.Text..' · '..tostring(count)..' cards'
  local tileWidth=(rowWidth-42)/2
  local role=(profile.droneRoles and profile.droneRoles[d.id]) or d.role or d.type
  if role=='Medic' then
   statTile(row,14,91,tileWidth,'REPAIR',tostring(DroneConfig.Types.Medic.HealAmount)..' health')
   statTile(row,tileWidth+28,91,tileWidth,'INTERVAL',tostring(DroneConfig.Types.Medic.AttackCooldown)..' sec')
  elseif role=='Courier' then
   statTile(row,14,91,tileWidth,'PARCEL',tostring(DroneConfig.Courier.BatchUnits)..' ore')
   statTile(row,tileWidth+28,91,tileWidth,'JOB','Sell for you')
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
  else
   statTile(row,14,91,tileWidth,'MINING',number(stats.miningDPS or 30)..' /s')
   statTile(row,tileWidth+28,91,tileWidth,'COMBAT',number(stats.combatDPS or 12)..' /s')
  end
  statTile(row,14,153,tileWidth,'MAX HULL',number(stats.maxHealth or 80))
  statTile(row,tileWidth+28,153,tileWidth,'FLIGHT',number((stats.maxStep60 or .35)*60)..' studs/s')
  label(row,UDim2.fromOffset(15,211),UDim2.new(1,-30,0,40),Mining.description(role),16,palette.muted)
 end
 local index=#crew+1;local x=((index-1)%columns)*(rowWidth+gap)+3;local y=rosterY+math.floor((index-1)/columns)*276
 local nextDrone=U.panel(body,UDim2.fromOffset(x,y),UDim2.fromOffset(rowWidth,258),palette.accent:Lerp(palette.white,.76),14)
 local narrowTile=rowWidth<330;local tileTextX=narrowTile and 70 or 81
 U.icon(nextDrone,'prestige',UDim2.fromOffset(14,16),UDim2.fromOffset(narrowTile and 45 or 55,narrowTile and 45 or 55),palette.accent)
 label(nextDrone,UDim2.fromOffset(tileTextX,17),UDim2.new(1,-tileTextX-15,0,31),narrowTile and 'Next drone' or 'Next crewmate',narrowTile and 21 or 24,palette.ink,true)
 label(nextDrone,UDim2.fromOffset(tileTextX,54),UDim2.new(1,-tileTextX-15,0,20),'+1 PERMANENT DRONE',10,palette.muted,true)
 local pre=profile.prestigePreview or {};local earned=pre.earnings or 0;local required=pre.saleRequired or 2000
 label(nextDrone,UDim2.fromOffset(16,97),UDim2.new(1,-32,0,24),comma(earned)..' / '..comma(required)..' credits sold',13,palette.ink,true)
 local guardRequirement=(pre.winsRequired or 1)>0 and ((pre.field or 'Cobalt')..((pre.wins or 0)>0 and ' · Unlocked' or ' · Defeat guards once')) or 'No sentry clear required'
 label(nextDrone,UDim2.fromOffset(16,130),UDim2.new(1,-32,0,22),guardRequirement,16,palette.muted)
 local review=button(nextDrone,UDim2.fromOffset(14,173),UDim2.new(1,-28,0,46),'Review fleet milestone',openPrestige,palette.accent);review.Name='ReviewMilestone'
 local audioY=rosterY+math.ceil((#crew+1)/columns)*276
 local music=button(body,UDim2.fromOffset(3,audioY),UDim2.fromOffset((width-12)/2,44),soundscape.musicMuted and 'Music: off' or 'Music: on',function() soundscape:toggleMusic();openFleet() end,palette.paper)
 music.Name='ToggleMusic'
 local effects=button(body,UDim2.fromOffset((width-12)/2+15,audioY),UDim2.fromOffset((width-12)/2,44),soundscape.effectsMuted and 'Effects: off' or 'Effects: on',function() soundscape:toggleEffects();openFleet() end,palette.paper)
 effects.Name='ToggleEffects'
end
openRunCards=function()
 if not profile then return end
 local l=menu('run','Your current build','Temporary upgrades last through reprints and reconnects. Prestige clears them.','cards');local width=l.bodyWidth-6
 tabs(width,'run')
 if #profile.run.cards==0 then
  U.icon(body,'cards',UDim2.fromOffset(math.max(0,(width-90)/2),84),UDim2.fromOffset(90,90),palette.mineral)
  local title=label(body,UDim2.fromOffset(6,196),UDim2.fromOffset(width-12,38),'Your first upgrade is waiting',26,palette.ink,true);title.TextXAlignment=Enum.TextXAlignment.Center
  local detail=label(body,UDim2.fromOffset(12,247),UDim2.fromOffset(width-24,64),'Mine crystals, sell minerals at the Converter, and open a pack at the depot. Choose one of three cards to shape this run.',14,palette.muted);detail.TextXAlignment=Enum.TextXAlignment.Center
  button(body,UDim2.fromOffset(6,334),UDim2.fromOffset(width-12,48),'View next pack',openPack,palette.accent)
 else
  for index,c in ipairs(profile.run.cards) do
   local y=63+(index-1)*145
   local row=U.panel(body,UDim2.fromOffset(3,y),UDim2.fromOffset(width,130),palette.paper,12)
   label(row,UDim2.fromOffset(16,12),UDim2.new(1,-32,0,55),CardView.summary(c),22,palette.ink,true)
   label(row,UDim2.fromOffset(16,72),UDim2.new(1,-32,0,46),CardView.terms(c,targetText(c)),16,palette.muted)
  end
 end
end
openPrestige=function()
 if not profile then return end
 local l=menu('prestige','One more drone. A new run.','Your drones and unlocked plots stay with you when you prestige.','prestige');local width=l.bodyWidth-6
 local narrow=width<400
 local pre=profile.prestigePreview or {};local before=pre.fleetBefore or #profile.fleet;local after=pre.fleetAfter or before+1
 local hero=U.panel(body,UDim2.fromOffset(3,3),UDim2.fromOffset(width,118),palette.accent:Lerp(palette.white,.63),16)
 U.icon(hero,'drone',UDim2.fromOffset(18,25),UDim2.fromOffset(narrow and 48 or 62,narrow and 48 or 62),colors[pre.newType] or palette.mineral)
 label(hero,UDim2.fromOffset(narrow and 80 or 98,16),UDim2.new(1,narrow and -96 or -116,0,43),before..' → '..after..(narrow and ' drones' or ' permanent drones'),narrow and 21 or 30,palette.ink,true)
 label(hero,UDim2.fromOffset(narrow and 18 or 98,narrow and 78 or 66),UDim2.new(1,narrow and -36 or -116,0,32),narrow and ('+1 permanent '..(pre.newRole or pre.newType or 'new')..' drone.\nKeep your whole crew.') or ('Gain one '..(pre.newRole or pre.newType or 'new')..' drone. Keep your whole crew.'),12,palette.ink)
 local pair=width>=560;local half=pair and (width-18)/2 or width
 local keep=U.panel(body,UDim2.fromOffset(3,141),UDim2.fromOffset(half,119),palette.mineral:Lerp(palette.white,.68),12)
 label(keep,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,24),'YOU KEEP',17,palette.ink,true)
 label(keep,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,61),'Every permanent drone\nBuilt-in types and base traits\nUnlocked plots and free reprinting',12,palette.ink)
 local resetY=pair and 141 or 274
 local reset=U.panel(body,UDim2.fromOffset(pair and half+21 or 3,resetY),UDim2.fromOffset(half,119),palette.danger:Lerp(palette.white,.83),12)
 label(reset,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,24),'YOU RESET',17,palette.ink,true)
 label(reset,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,61),'Cards, shop upgrades and access\nAll mineral balances and backpack ore\nPack prices and sale progress',12,palette.ink)
 local y=pair and 284 or 417
 local required=pre.saleRequired or 2000;local earnings=pre.earnings or profile.run.saleEarnings or 0
 local guardRequirement=(pre.winsRequired or 1)>0 and (' · '..(pre.field or 'Cobalt')..((pre.wins or 0)>0 and ' unlocked' or ' locked')) or ''
 progress(body,y,width,'Your permanent fleet milestone',comma(earnings)..' / '..comma(required)..' credits sold'..guardRequirement,earnings/math.max(1,required),palette.accent)
 local allowed,blocked=availability('Prestige')
 local can=pre.eligible==true and not pending() and allowed
 local reason=not allowed and blocked or (pending() and 'Choose your paid pack card first' or (can and 'Start new run · +1 permanent drone' or 'Complete the fleet milestone'))
 local confirm
 confirm=button(body,UDim2.fromOffset(3,y+95),UDim2.fromOffset(width,50),reason,function()
  if can and canAct('Prestige') and send('Prestige',{confirm=true}) then confirm.Text='Starting new run…';enableAction(confirm,false) end
 end,palette.accent);confirm.Name='ConfirmPrestige';enableAction(confirm,can)
 label(body,UDim2.fromOffset(8,y+160),UDim2.fromOffset(width-10,31),'This confirmation begins a new run and clears the reset items above.',11,palette.muted)
end
local refreshSerial=0
local function refreshModal()
 if not modal.Visible then return end
 local savedScroll=body.CanvasPosition;local mode=modalMode
 refreshSerial=refreshSerial+1;local serial=refreshSerial
 if mode=='offer' then if pending() then openOffer() end
 elseif mode=='shop' then openShop(activeShop,shopInfo)
 elseif mode=='pack' then openPack()
 elseif mode=='prestige' then openPrestige()
 elseif mode=='fleet' then openFleet()
 elseif mode=='run' then openRunCards() end
 task.defer(function()
  RunService.Heartbeat:Wait()
  if serial==refreshSerial and modal.Visible and modalMode==mode and body.Parent then
   body.CanvasPosition=Vector2.new(0,math.min(savedScroll.Y,math.max(0,body.AbsoluteCanvasSize.Y-body.AbsoluteWindowSize.Y)))
  end
 end)
end
local lastOffer=nil
local function readProfile()
 local raw=player:GetAttribute('MA_Profile');if type(raw)~='string' then return end
 local ok,p=pcall(function() return Http:JSONDecode(raw) end);if not ok or type(p)~='table' or type(p.run)~='table' then return end
 local oldProfile=profile
 local changedRun=profile and profile.run.id~=p.run.id
 soundscape:observeProfile(oldProfile,p)
 profile=p
 if actionPending then
  local offer=p.run.pendingOffer
  if changedRun or (actionPending.kind=='ChooseCard' and (not offer or offer.id~=actionPending.offerId)) or (actionPending.kind=='BuyPack' and p.run.packIndex>actionPending.packIndex) or (actionPending.kind=='BuyUpgrade' and (p.run.shopLevels[actionPending.upgradeId] or 0)>(actionPending.level or 0)) then actionPending=nil end
 end
 if changedRun and modalMode=='prestige' then modal.Visible=false end
 local offer=pending()
 if offer and offer.id~=lastOffer then lastOffer=offer.id;openOffer()
 elseif not offer and modalMode=='offer' then modal.Visible=false;modalMode=nil
 elseif modalMode=='offer' then -- A paid offer is immutable; cargo changes must not interrupt comparisons.
  if p.pendingTransaction~=(oldProfile and oldProfile.pendingTransaction) then refreshModal() end
 elseif modalMode=='fleet' or modalMode=='run' then
  local oldMilestone=oldProfile and oldProfile.prestigePreview or {}
  local milestone=p.prestigePreview or {}
  local milestoneChanged=modalMode=='fleet' and (oldMilestone.earnings~=milestone.earnings or oldMilestone.wins~=milestone.wins or oldMilestone.eligible~=milestone.eligible)
  local oldCrew=oldProfile and (oldProfile.activeFleet or oldProfile.fleet) or {};local crew=p.activeFleet or p.fleet
  local crewChanged=#oldCrew~=#crew or (crew[1] and oldCrew[1] and crew[1].id~=oldCrew[1].id)
  if not oldProfile or changedRun or crewChanged or #oldProfile.fleet~=#p.fleet or #oldProfile.run.cards~=#p.run.cards or milestoneChanged then refreshModal() end
 else refreshModal() end
end
connect(player:GetAttributeChangedSignal('MA_Profile'),readProfile);readProfile()
local noticeUntil=0
connect(player:GetAttributeChangedSignal('MA_Notice'),function()
 notice.Text=tostring(player:GetAttribute('MA_Notice') or '');noticeUntil=os.clock()+5;actionPending=nil;refreshModal()
end)

local abilityView=AbilityView.start({interface=U,parent=safeRoot,command=command,profile=function() return profile end,hidden=function() return modal.Visible end})
local crystalAudio=require(RS.Shared:WaitForChild('CrystalAudio')).new(localFX,soundscape.effectsGroup)
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
 clone:ScaleTo(clone:GetScale()*(source:GetAttribute('ModelScale') or DroneConfig.Swarm.ModelScale))
 DroneConfig.decorate(clone,source:GetAttribute('Role') or kind)
 pendingDroneSources[source]=nil
 local pivot=clone.PrimaryPart or clone:FindFirstChildWhichIsA('BasePart',true);if not pivot then clone:Destroy();return false end
 clone.PrimaryPart=pivot;clone.Parent=localFX
 local emitter=clone:FindFirstChild('Emmiter',true) or clone:FindFirstChild('MiningEmitter',true) or clone:FindFirstChild('Emitter',true)
 if not emitter or not emitter:IsA('BasePart') then clone:Destroy();pendingDroneSources[source]=true;return false end
 for _,part in ipairs(clone:GetDescendants()) do
  if part:IsA('BasePart') then part.Reflectance=0 end
 end
 local typeColor=colors[source:GetAttribute('Role')] or colors[source:GetAttribute('Type')]
 emitter.Color=typeColor or emitter.Color
 -- The original 1-stud emitter is enclosed by its 2-stud body; a restrained tint stays visible.
 if typeColor and not clone:GetAttribute('RoleGeometry') then
  pivot.Color=Color3.fromRGB(111,120,123):Lerp(typeColor,.18)
  -- Keep the authored shell/emitter; small case seams make its type readable in flight.
  local trim=localPart(clone,'LowerChassis',pivot.Position);trim.Size=Vector3.new(pivot.Size.X*1.015,.055,pivot.Size.Z*1.015);trim.Transparency=0;trim.Color=Color3.fromRGB(23,35,46);trim.Material=Enum.Material.Metal;trim.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.35,0)
  for _,side in ipairs({-1,1}) do
   local optic=localPart(clone,'TypeOptic',pivot.Position);optic.Size=Vector3.new(pivot.Size.X*.52,.035,.015);optic.Transparency=0;optic.Color=typeColor;optic.Material=Enum.Material.SmoothPlastic;optic.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.24,side*(pivot.Size.Z*.5+.01))
  end
 end
 hideModel(source)
 local parts={};for _,p in ipairs(clone:GetDescendants()) do if p:IsA('BasePart') then parts[p]=p.Transparency end end
 local d={source=source,view=clone,emitter=emitter,pos=pos,velocity=source:GetAttribute('Velocity') or Vector3.zero,yaw=source:GetAttribute('Yaw') or 0,life=source:GetAttribute('Life'),parts=parts,lastState=source:GetAttribute('State'),beam=createBeam(clone,emitter)}
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
 view.Reflectance=0;view.Parent=localFX;hidePart(source)
 resources[source]={source=source,view=view,id=tostring(id),baseColor=source.Color,visual=Feel.newStagePresentation(source:GetAttribute('Stage') or 0,(source:GetAttribute('BreakSerial') or 0)>0 or (source:GetAttribute('HP') or 1)<=0,workspace:GetServerTimeNow(),source:GetAttribute('StageCount') or 3)}
 resourceIndex[tostring(id)]=resources[source]
end
local function registerTurret(source)
 if turrets[source] or not source:IsA('Model') or not (source:GetAttribute('Turret') or source:GetAttribute('TurretId')) then return end
 local t=presentation:registerTurret(source,workspace:GetServerTimeNow())
 if t then turrets[source]=t;turretIndex[tostring(source:GetAttribute('TurretId'))]=source;hideModel(source);TacticalHUD.attachHealth(t.view,source,palette.danger,true) end
end
local observed={}
local function observe(source)
 if not source.Parent then return end
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
  if not observed[source] then observed[source]=source.AttributeChanged:Connect(function() registerResource(source) end) end
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
 if d.healMuzzle then d.healMuzzle:Destroy() end
 if d.healTarget then d.healTarget:Destroy() end
 presentation:destroyDrone(d)
 presentation:destroyMiningBeam(d.beam);d.view:Destroy()
end
connect(world.DescendantRemoving,function(source)
 pendingDroneSources[source]=nil
 if drones[source] then destroyDrone(drones[source]);drones[source]=nil end
 if resources[source] then resourceIndex[resources[source].id]=nil;resources[source].view:Destroy();resources[source]=nil end
 if turrets[source] then turretIndex[tostring(source:GetAttribute('TurretId'))]=nil;presentation:destroyTurret(turrets[source]);turrets[source]=nil end
 if observed[source] then observed[source]:Disconnect();observed[source]=nil end
 hiddenParts[source]=nil
end)
local function resourceById(id) return resourceIndex[tostring(id)] end
local function renderResource(r,now)
 local s=r.source;local view=r.view
 local key=s:GetAttribute('Mineral') or Shops.ORDER[s:GetAttribute('FieldId') or 1]
 if profile and not Shops.unlocked(profile,key) then view.Transparency=1;return end
 local full=s:GetAttribute('FullSize') or s.Size
 if type(full)=='number' then full=Vector3.one*full end
 local final=s:GetAttribute('FullPosition') or s.Position
 local spawnAt=s:GetAttribute('SpawnAt') or now-2
 local readyAt=s:GetAttribute('ReadyAt') or spawnAt+2
 -- Original TweenInfo default Quad/Out: size and rise share the same two-second envelope.
 local growth=Feel.growth(now,spawnAt)
 if readyAt-spawnAt~=2 then local g=math.clamp((now-spawnAt)/math.max(.01,readyAt-spawnAt),0,1);growth=1-(1-g)^2 end
 local stageCount=s:GetAttribute('StageCount') or 3
 local authoritativeStage=math.clamp(s:GetAttribute('Stage') or 0,0,stageCount)
 local health=s:GetAttribute('HP') or 1
 local broken=(s:GetAttribute('BreakSerial') or 0)>0 or health<=0
 local event=Feel.updateStagePresentation(r.visual,authoritativeStage,broken,now,stageCount)
 local stage=r.visual.stage
 local period=Feel.stageScale(stage,stageCount)
 if not r.visual.broken then
  view.Transparency=s:GetAttribute('Kind')=='Geode' and .04 or 0
  view.Size=full*math.max(.005,growth*period)
  local start=s:GetAttribute('StartPosition') or Vector3.new(final.X,final.Y-2-full.Y/2,final.Z)
  local pos=start:Lerp(final,growth)
  local seed=s:GetAttribute('StageSeed') or 0
  local ground=s:GetAttribute('GroundY')
  if type(ground)=='number' then view.CFrame=Feel.groundedRockFrame(pos,view.Size,ground,stage,seed)
  else view.CFrame=CFrame.new(pos)*CFrame.Angles(0,seed*.01,0) end
  local darkness=r.visual.scorched and 1 or Feel.stageDarkness(health,s:GetAttribute('MaxHP') or 1,stage,stageCount)
  view.Color=r.baseColor:Lerp(Color3.fromRGB(7,8,10),darkness)
 else view.Transparency=1 end
 if event=='stage' then crystalAudio:play(view.Position,event,stage,s:GetAttribute('Kind')=='Geode');presentation:resourceImpact(r,event,now)
 elseif event=='break' then crystalAudio:play(view.Position,event,stage,s:GetAttribute('Kind')=='Geode');presentation:resourceImpact(r,event,now) end
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
 local logical=s:GetAttribute('Position');local goal=s:GetAttribute('Goal') or logical
 if typeof(logical)~='Vector3' or typeof(goal)~='Vector3' then return end
 d.lastState=state
 local life=s:GetAttribute('Life');local maxStep=s:GetAttribute('MaxStep60') or .35
 if life~=d.life then d.life=life;d.pos=logical;d.velocity=s:GetAttribute('Velocity') or Vector3.zero end
 local motionPaused=s:GetAttribute('MotionPaused')==true
 if state=='Follow' and not motionPaused then
  local owner=Players:GetPlayerByUserId(s:GetAttribute('Owner') or 0)
  local hr=owner and owner.Character and owner.Character:FindFirstChild('HumanoidRootPart')
  local slot=s:GetAttribute('FormationSlot');local count=s:GetAttribute('FleetCount')
  if hr and slot and count then
   local desired=renderSwarmGrid and Feel.swarmOffset(d.pos,tostring(s:GetAttribute('DroneId')),renderSwarmGrid,1) or s:GetAttribute('SwarmOffset') or Vector3.zero
   d.swarmSteer=Feel.smoothSwarm(d.swarmSteer,desired,dt)
   goal=Feel.followGoal(hr.Position,slot,count,now,(s:GetAttribute('PhaseSeed') or maxStep*200)/200)+Vector3.new(0,(s:GetAttribute('FlightHeight') or Feel.FollowHeight)-Feel.FollowHeight,0)+d.swarmSteer
  end
 end
 if state=='Destroyed' or state=='Reprinting' then d.pos=logical;d.velocity=Vector3.zero
 elseif not motionPaused and state=='BreakerImpact' then
  d.pos=s:GetAttribute('BreakerImpact') or logical;d.velocity=Vector3.zero
 elseif not motionPaused and state=='BreakerDive' then
  d.pos,d.velocity=Feel.powerDive(s:GetAttribute('BreakerDiveStart') or logical,s:GetAttribute('BreakerImpact') or goal,now-(s:GetAttribute('BreakerPhaseAt') or now),.28)
 elseif not motionPaused then
  local workTravel=state=='Deliver' or state=='BreakerDive' or state=='BreakerRecover' or state=='Recover' or state=='Plant' or state=='GrowApproach' or (s:GetAttribute('TargetId') or '')~=''
  local error=logical-d.pos
  local correction=error.Magnitude>5 and error.Unit*math.min((error.Magnitude-5)*.8,maxStep*60*.25) or Vector3.zero
  d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,maxStep,math.min(dt,.1),workTravel,correction)
 end
 if not motionPaused then
  local targetYaw=Feel.levelYaw(d.pos,goal,d.yaw)
  local difference=math.atan2(math.sin(targetYaw-d.yaw),math.cos(targetYaw-d.yaw))
  d.yaw=d.yaw+difference*Feel.turnAlpha(math.min(dt,.1))
 end
 local velocity=dt>0 and (d.pos-previousPosition)/dt or Vector3.zero
 local sideVelocity=CFrame.Angles(0,d.yaw,0):VectorToObjectSpace(velocity).X
 local desiredBank=(state=='Mine' or state=='Destroyed' or state=='Reprinting' or motionPaused) and 0 or math.clamp(-sideVelocity*.005,-math.rad(3),math.rad(3))
 d.bank=(d.bank or 0)+(desiredBank-(d.bank or 0))*(1-math.exp(-math.min(dt,.1)*5))
 local drift=(state=='Destroyed' or state=='Reprinting' or motionPaused) and 0 or math.sin(now*1.6+(s:GetAttribute('PhaseSeed') or 0))*(state=='Mine' and .05 or .10)
 d.view:PivotTo(CFrame.new(d.pos+Vector3.new(0,drift,0))*CFrame.Angles(0,d.yaw,0)*CFrame.Angles(0,0,d.bank))
 local reprintAt=s:GetAttribute('ReprintAt') or 0
 for part,original in pairs(d.parts) do
  if state=='Destroyed' then part.Transparency=1
  elseif state=='Reprinting' then part.Transparency=math.max(original,math.clamp((reprintAt-now)/2,0,1))
  else part.Transparency=original end
 end
 presentation:renderDrone(d,dt,now)
 local mining=s:GetAttribute('Mining')==true
 local attacking=state=='Attack' and s:GetAttribute('Firing')==true
 local alive=state~='Destroyed' and state~='Reprinting' and (s:GetAttribute('HP') or 1)>0
 local active=alive and (mining or attacking)
 local charging=alive and state=='Mine' and not mining and (s:GetAttribute('WarmupStart') or 0)>0
 local beam=d.beam
 local kind=state=='Attack' and 'turret' or 'resource'
 local id=s:GetAttribute(kind=='turret' and 'CombatTargetId' or 'TargetId')
 if active and type(id)=='string' and id~='' then beam.lastKey=id;beam.lastKind=kind
 elseif not active and not charging and beam.lastKey then id=beam.lastKey;kind=beam.lastKind end
 local part,source,resource=resolveRenderedTarget(kind,id)
 local procKind=state=='Attack' and 'turret' or 'resource'
 local procId=s:GetAttribute(procKind=='turret' and 'ChainTargetId' or 'ForkTargetId')
 local procUntil=s:GetAttribute(procKind=='turret' and 'ChainUntil' or 'ForkUntil') or 0
 local extra,extraSource
 if active and now<procUntil then extra,extraSource=resolveRenderedTarget(procKind,procId) end
 local beamSince=state=='Attack' and (s:GetAttribute('ShotAt') or now) or (s:GetAttribute('BeamSince') or now)
 local breakAt,breakUntil
 -- A final hit retires the gameplay reservation immediately. Its short saved
 -- contact may finish the local fracture sequence while the drone moves on.
 -- A new active job wins, and no contact outlives either visible crystal.
 local finalAt=s:GetAttribute('MineBreakAt') or 0
 local finalUntil=s:GetAttribute('MineBreakUntil') or 0
 if alive and not active and not motionPaused and (s:GetAttribute('MineBreakSerial') or 0)>0
  and now>=finalAt and now<math.min(finalUntil,finalAt+.3) then
  local primaryId=s:GetAttribute('MineBreakPrimaryId')
  local finalPart,finalSource,finalResource=resolveRenderedTarget('resource',primaryId,true)
  if finalPart then
   part,source,resource=finalPart,finalSource,finalResource;id=primaryId;kind='resource';active=true
   procId=s:GetAttribute('MineBreakSecondaryId')
   extra,extraSource=resolveRenderedTarget('resource',procId,true)
   beamSince=s:GetAttribute('MineBreakBeamSince') or now;breakAt=finalAt;breakUntil=finalUntil
  end
 end
 presentation:queueMiningBeam(beam,{alive=alive,active=active,key=id,life=life,
  contact=active,
  isMining=kind=='resource',charging=charging,
  warmupStart=s:GetAttribute('WarmupStart') or 0,warmupDuration=s:GetAttribute('WarmupDuration') or .8,mineralColor=resource and resource.baseColor,
  style=state=='Attack' and 'Cutter' or s:GetAttribute('MiningStyle'),droneType=s:GetAttribute('Type'),paused=s:GetAttribute('MotionPaused')==true,
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
  local active=(d.source:GetAttribute('Healing')==true or d.source:GetAttribute('State')=='RepairCharge') and d.source:GetAttribute('MotionPaused')~=true
   and (d.source:GetAttribute('HP') or 0)>0 and target and (target.source:GetAttribute('HP') or 0)>0
   and d.emitter.Parent and target.emitter.Parent
  if active then table.insert(candidates,{drone=d,target=target})
  elseif d.healBeam then d.healBeam.Transparency=1 end
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
  if visible then WorkEffects.drawCylinder(d.healBeam,d.emitter.Position,target.emitter.Position,charging and .025+.035*q or .13,charging and (.8-.35*q) or .12)
  else d.healBeam.Transparency=1 end
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

connect(RunService.RenderStepped,function(dt)
 local now=workspace:GetServerTimeNow()
 presentation:beginFrame()
 pickupView:update(dt,now)
 for _,r in pairs(resources) do renderResource(r,now) end
 for _,t in pairs(turrets) do
  if fieldUnlocked(t.source.Parent) and (t.source:GetAttribute('HP') or 0)>0 then
   t.view.Parent=nil;t.cue.Transparency=1;t.beam.Enabled=false;t.flare.Enabled=false;t.light.Brightness=0
  else
   if not t.view.Parent then t.view.Parent=localFX end
   presentation:renderTurret(t,dt,now)
  end
 end
 local swarmRecords={}
 for _,d in pairs(drones) do table.insert(swarmRecords,{id=tostring(d.source:GetAttribute('DroneId')),pos=d.pos,velocity=d.velocity,hp=d.source:GetAttribute('HP') or 0,goal=d.source:GetAttribute('Goal'),maxStep60=d.source:GetAttribute('MaxStep60')}) end
 renderSwarmGrid=Feel.swarmGrid(swarmRecords)
 for _,d in pairs(drones) do renderDrone(d,dt,now) end
 renderHealing(now);renderBackpacks()
 presentation:flushMiningBeams()
 presentation:update(dt,now)
end)

local evade=button(safeRoot,UDim2.new(1,-136,1,-108),UDim2.fromOffset(118,38),'Evade  [Q]',function() command:FireServer('Evade') end,palette.accent);evade.Visible=false
local testLoadout=button(safeRoot,UDim2.new(1,-252,0,80),UDim2.fromOffset(236,44),'Random loadout · 2–5 [T]',function() command:FireServer('TestLoadout') end,Color3.fromRGB(139,83,224))
testLoadout.Name='RandomLoadoutTester';testLoadout.Visible=false
local unload=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(116,40),'Sell backpack [U]',function() command:FireServer('Sell') end,palette.paper)
unload.Name='ReturnCargo';unload.Visible=false
local enemyHUD=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(300,58),palette.panel,12);enemyHUD.Name='SentryHealth';enemyHUD.Visible=false
local enemyTitle=label(enemyHUD,UDim2.fromOffset(12,0),UDim2.new(1,-24,1,0),'PYRAMID SENTRY',12,palette.white,true)
local enemyHealth=frame(enemyHUD,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(53,55,57));enemyHealth.Name='HealthTrack';enemyHealth.ClipsDescendants=true;corner(enemyHealth,3)
local enemyFill=frame(enemyHealth,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(104,45,51));enemyFill.Name='Fill';corner(enemyFill,3)
enemyTitle.ZIndex=enemyFill.ZIndex+2
local tacticalHUD=TacticalHUD.new({root=safeRoot,gui=gui,modal=modal,recall=recall,unload=unload,test=testLoadout,evade=evade,resources=hud,objective=objectiveBox,context=context,enemy=enemyHUD,toast=toast,
 credits=creditsLabel,cargoText=cargoText,cargoTrack=cargoTrack,fleet=fleetButton,cards=runButton,fleetText=fleetCount,cardsText=runCount,
 objectiveText=objective,contextTitle=contextTitle,contextDetail=contextDetail,contextButton=contextButton})
local function ownerRoot() return player.Character and player.Character:FindFirstChild('HumanoidRootPart') end
local function nearbyInteraction()
 local hr=ownerRoot();if not hr then return nil end
 local nearest,best=nil,14
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') and (converter.Position-hr.Position).Magnitude<best then nearest=converter;best=(converter.Position-hr.Position).Magnitude end
 local map=world:FindFirstChild('Map')
 if map then
  for _,name in ipairs({'PackStation','PrestigeStation','QuartzShop','RubyShop','CobaltShop','VioletShop','EmeraldShop'}) do
   local v=map:FindFirstChild(name,true)
   if v and v:IsA('BasePart') then
    local distance=(v.Position-hr.Position).Magnitude
    if distance<best then nearest=v;best=distance end
   end
  end
 end
 return nearest
end
local function stationAction(station)
 local kind=station:GetAttribute('Interaction')
 if kind=='Shop' then
  local key=station:GetAttribute('ShopKey')
  if profile then return function() openShop(key) end,key..' shop',Shops.unlocked(profile,key) and ('Spend '..key..' on upgrades') or 'Locked · buy access in the previous shop','Shop' end
  return nil
 elseif kind=='Pack' then return openPack,'Upgrade your fleet',pending() and 'Your three saved cards are waiting' or ('3 cards. Keep 1.  /  '..comma(profile and profile.nextPackPrice or 80)..' Quartz'),pending() and 'Choose' or 'Pack'
 elseif kind=='Prestige' then return openPrestige,'Grow your fleet','Review the milestone and your next permanent drone','Review'
 elseif kind=='Sell' then return function() command:FireServer('Sell') end,'Sell backpack','Bring your backpack to the depot','Sell'
 end
 return nil
end
local lastStationUse=0
local function performStation(station)
 local action=stationAction(station)
 if modal.Visible then return end
 if action and os.clock()-lastStationUse>.25 then lastStationUse=os.clock();action() end
end
connect(game:GetService('ProximityPromptService').PromptTriggered,function(prompt,who)
 if (not who or who==player) and prompt.Parent and prompt.Parent:IsA('BasePart') then performStation(prompt.Parent) end
end)
local function availableAutomaticWorker()
 if not profile then return false end
 for source in pairs(drones) do
  if source:GetAttribute('Owner')==player.UserId and source:GetAttribute('AutomationMineEnabled')==true
   and (source:GetAttribute('HP') or 0)>0 and source:GetAttribute('State')~='Reprinting' and source:GetAttribute('State')~='Deliver'
   and source:GetAttribute('Role')~='Medic' and source:GetAttribute('Role')~='Courier' then return true end
 end
 return false
end
local function requestPlot(id)
 local fields=world:FindFirstChild('Fields');local guarded=false
 if fields then for _,field in ipairs(fields:GetChildren()) do
  if (field:GetAttribute('FieldId') or field:GetAttribute('Tier'))==id then
   local phase=field:GetAttribute('Phase');guarded=not fieldUnlocked(field) and (phase=='Guarded' or phase=='Active');break
  end
 end end
 if not guarded and player:GetAttribute('AutomationMineEnabled')~=true then
  notice.Text='Click an ore. Plot Scanner unlocks automatic stone selection.';noticeUntil=os.clock()+4;return
 end
 if not guarded and not availableAutomaticWorker() then
  notice.Text='Choose an available miner with Plot Scanner.';noticeUntil=os.clock()+4;return
 end
 command:FireServer('Patch',id)
end
local commandView=CommandView.new({parent=localFX,resources=resourceIndex,drones=drones,command=command,
 profile=function() return profile end,hidden=function() return modal.Visible end,
 blocks=function(point) return tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) end})
connect(RunService.RenderStepped,function(dt) commandView:update(dt,workspace:GetServerTimeNow()) end)
connect(gui.Parent:GetAttributeChangedSignal('MA_CommandState'),function()
 local ok,state=pcall(Http.JSONDecode,Http,gui.Parent:GetAttribute('MA_CommandState') or '')
 if not ok or type(state)~='table' then return end
 commandView:reply(state)
 notice.Text=state.reason or '';noticeUntil=os.clock()+2.2
end)
local function assignField(target)
 if modal.Visible then return end
 local node=target
 while node and node~=workspace do
  local resourceId=node:GetAttribute('ResourceId')
  if type(resourceId)=='string' and resourceId~='' then
   commandView:request(resourceId);return
  end
  local owner=node:GetAttribute('Owner')
  if owner==player.UserId and node:GetAttribute('DroneId') then openFleet();return end
  local field=node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier')
  if type(field)=='number' then requestPlot(field);return end
  node=node.Parent
 end
end
local mouse=player:GetMouse()
connect(UIS.TouchTapInWorld,function(position,processed)
 if processed or modal.Visible or tacticalHUD:blocksPoint(position) then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local ray=camera:ScreenPointToRay(position.X,position.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={localFX,player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 if hit then assignField(hit.Instance) end
end)
connect(UIS.InputBegan,function(input,processed)
 if input.KeyCode==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false;return end
 if processed or UIS:GetFocusedTextBox() then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then if not tacticalHUD:blocksPoint(UIS:GetMouseLocation()-game:GetService('GuiService'):GetGuiInset()) then assignField(mouse.Target) end;return end
 local key=input.KeyCode
 if key==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false
 elseif not modal.Visible and key==Enum.KeyCode.M then openShop(activeShop)
 elseif not modal.Visible and (key==Enum.KeyCode.R or key==Enum.KeyCode.F or key==Enum.KeyCode.ButtonB) then command:FireServer('Recall')
 elseif not modal.Visible and key==Enum.KeyCode.U then command:FireServer('Sell')
 elseif not modal.Visible and (key==Enum.KeyCode.Q or key==Enum.KeyCode.ButtonX) then command:FireServer('Evade')
 elseif not modal.Visible and (key==Enum.KeyCode.T or key==Enum.KeyCode.ButtonY) and player:GetAttribute('MA_TestingEnabled')==true then command:FireServer('TestLoadout')
 elseif (key==Enum.KeyCode.E or key==Enum.KeyCode.ButtonR2) and not modal.Visible then if contextAction then contextAction() end
 elseif key==Enum.KeyCode.ButtonR1 and not modal.Visible then
  local camera=workspace.CurrentCamera
  if camera then local ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2);local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={localFX,player.Character};local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params);if hit then assignField(hit.Instance) end end
 elseif not modal.Visible then
  local fields={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5}
  if fields[key] then requestPlot(fields[key]) end
 end
end)
local hudClock=0
local availabilitySignature=''
local contextKind='mining'
connect(RunService.Heartbeat,function(dt)
 hudClock=hudClock+dt;if hudClock<.2 then return end;hudClock=0
 local view=viewport();local l=currentLayout();local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 hud.Position=UDim2.fromOffset(l.hudX,l.hudY);hud.Size=UDim2.fromOffset(l.hudWidth,l.hudHeight)
 creditsLabel.Size=UDim2.fromOffset(l.hudWidth-156,28);saveLabel.Size=UDim2.fromOffset(l.hudWidth-156,13)
 creditsLabel.TextSize=l.hudWidth<330 and 24 or 28
 cargoText.Size=UDim2.fromOffset(l.hudWidth-158,18);cargoText.Position=UDim2.fromOffset(50,34)
 cargoTrack.Position=UDim2.fromOffset(50,53)
 fleetButton.Size=UDim2.fromOffset(46,44);runButton.Size=fleetButton.Size
 objectiveBox.Size=UDim2.fromOffset(l.objectiveWidth,l.objectiveHeight)
 objectiveBox.Position=UDim2.fromOffset(l.hudX,l.objectiveY)
 objectiveBox.Visible=not modal.Visible and not l.short
 context.Size=UDim2.fromOffset(l.contextWidth,l.contextHeight);context.Position=UDim2.fromOffset(l.contextX,l.contextY)
 contextButton.Position=UDim2.new(1,-112,0,(l.contextHeight-44)/2)
 contextTitle.TextSize=l.contextWidth<350 and 13 or 18
 contextDetail.TextSize=l.contextWidth<350 and 10 or 11
 contextIcon.Position=UDim2.fromOffset(12,(l.contextHeight-34)/2)
 recall.Position=UDim2.fromOffset(l.recallX,l.recallY);evade.Position=UDim2.fromOffset(l.evadeX,l.evadeY)
 recall.Size=UDim2.fromOffset(l.recallWidth,44);evade.Size=recall.Size
 recall.Text=touch and 'Recall' or 'Recall [R]';recall.Visible=not modal.Visible
 local testWidth=math.min(236,view.X-24)
 testLoadout.Size=UDim2.fromOffset(testWidth,44);testLoadout.Position=UDim2.fromOffset(view.X-testWidth-16,(view.X<680 or l.short) and 72 or 80)
 testLoadout.Text=touch and 'Random loadout · 2–5' or 'Random loadout · 2–5 [T]'
 testLoadout.Visible=player:GetAttribute('MA_TestingEnabled')==true and not modal.Visible
 if modal.Visible and (not modalSize or (modalSize-view).Magnitude>1) then refreshModal() end
 if modal.Visible and (modalMode=='offer' or modalMode=='pack' or modalMode=='prestige' or modalMode=='shop') then
  local action=modalMode=='offer' and 'ChooseCard' or modalMode=='pack' and 'BuyPack' or modalMode=='shop' and 'BuyUpgrade' or 'Prestige'
  local allowed,reason=availability(action);local signature=modalMode..':'..tostring(allowed)..':'..reason
  if signature~=availabilitySignature then availabilitySignature=signature;if modalMode~='offer' then refreshModal() end end
 end
 if actionPending and os.clock()-actionPending.at>10 and not (profile and profile.pendingTransaction) then
  actionPending=nil;notice.Text='Still waiting for confirmation. You can retry.';noticeUntil=os.clock()+5;refreshModal()
 end
 if os.clock()>noticeUntil then notice.Text='' end
 local status=tostring(player:GetAttribute('MA_SaveStatus') or 'Loading'):lower()
 if status:find('preview') then saveLabel.Text=l.hudWidth<310 and 'UNSAVED PREVIEW' or 'PREVIEW · NOT SAVED'
 elseif status:find('loading') then saveLabel.Text='CONNECTING'
 elseif status:find('unavailable') then saveLabel.Text='PROFILE UNAVAILABLE'
 elseif status:find('saved') then saveLabel.Text='CREDITS · AUTOSAVED'
 else saveLabel.Text='SAVE PAUSED' end
 saveLabel.TextSize=16;saveLabel.Position=UDim2.fromOffset(12,42);saveLabel.TextXAlignment=Enum.TextXAlignment.Left
 shopButton.Position=UDim2.new(1,-150,0,6);shopButton.Visible=not modal.Visible
 saveLabel.Visible=not modal.Visible and (status:find('preview')~=nil or not status:find('saved'))
 saveLabel.TextColor3=status:find('preview') and Color3.fromRGB(137,91,37) or palette.muted
 if profile and profile.run then
  local amount=cargoUnits(profile);local capacity=profile.capacity or 40
  local credits=Shops.balance(profile,'Quartz');local creditText=comma(credits)
  if credits>=1e9 then creditText=string.format('%.1fB',credits/1e9) elseif credits>=1e6 then creditText=string.format('%.1fM',credits/1e6) elseif credits>=10000 then creditText=string.format('%.1fk',credits/1000) end
  creditsLabel.Text='Quartz '..creditText
  fleetCount.Text='Fleet';runCount.Text=pending() and 'Pick' or 'Cards'
  cargoText.Text=string.format('Backpack %s / %s',comma(amount),comma(capacity))
  cargoFill.Size=UDim2.fromScale(math.clamp(amount/math.max(1,capacity),0,1),1)
  cargoFill.BackgroundColor3=amount>=capacity and palette.accent or palette.mineral
  local pre=profile.prestigePreview;local price=profile.nextPackPrice or 40
  if pending() then objective.Text='Your paid pack is waiting.\nChoose your card at the depot.'
  elseif amount>=capacity then objective.Text='Backpack full · mining continues.\nSell to collect waiting fragments.'
  elseif pre and pre.eligible then objective.Text='Your next permanent drone is ready!\nVisit the fleet uplink to prestige.'
  elseif credits>=price then objective.Text='Upgrade ready · '..comma(price)..' Quartz.\nOpen your next pack at the depot.'
  elseif player:GetAttribute('AutomationMineEnabled')~=true then objective.Text='Click rocks to send workers.\nGold = queued · green = working.'
  elseif pre and (pre.earnings or 0)>=(pre.saleRequired or 2000) and (pre.wins or 0)<(pre.winsRequired or 1) then objective.Text=string.format('Unlock %s to grow your crew.\nDefeat its guards once.',pre.field or 'Cobalt')
  elseif pre and (pre.winsRequired or 1)>0 then objective.Text=string.format('Next drone: %s / %s credits sold.\n%s: %s.',comma(pre.earnings or 0),comma(pre.saleRequired or 2000),pre.field or 'Cobalt',(pre.wins or 0)>0 and 'Unlocked' or 'Defeat guards once')
  elseif pre then objective.Text=string.format('Next drone: %s / %s credits sold.',comma(pre.earnings or 0),comma(pre.saleRequired or 160))
  else objective.Text='Click a plot to automate mining.\nBring your backpack back to sell.' end
 end
 local ownActive=false;local reprints={};local now=workspace:GetServerTimeNow()
 for source in pairs(drones) do
  if source:GetAttribute('Owner')==player.UserId then
   local state=source:GetAttribute('State');if state=='Attack' then ownActive=true end
   local at=source:GetAttribute('ReprintAt') or 0
   if at>now then table.insert(reprints,string.format('%s reprinting: %ds',source:GetAttribute('DroneName') or source:GetAttribute('Name') or 'Drone',math.ceil(at-now))) end
  end
 end
 evade.Visible=ownActive and not modal.Visible;evade.Text=touch and 'Evade shot' or 'Evade [Q]'
 soundscape:setContext(ownActive,modal.Visible)
 hud.Visible=not modal.Visible and not (l.short and ownActive)
 if not ownActive and (l.mobile or touch) and not l.actionAtTop then recall.Position=UDim2.fromOffset((view.X-l.recallWidth)/2,l.recallY) end
 if ownActive then objectiveBox.Visible=false end
 if #reprints>0 and os.clock()>noticeUntil then notice.Text=#reprints>2 and tostring(#reprints)..' drones reprinting for free' or table.concat(reprints,' · ') end
 local station=nearbyInteraction();contextAction=nil;context.Visible=false
 local desiredContext=station and ({Pack='cards',Prestige='prestige',Sell='cargo',Shop='crystal'})[station:GetAttribute('Interaction')] or 'mining'
 if desiredContext~=contextKind then contextKind=desiredContext;contextIcon:Destroy();contextIcon=U.icon(context,contextKind,UDim2.fromOffset(12,(l.contextHeight-34)/2),UDim2.fromOffset(34,34),palette.mineral) end
 if station and not modal.Visible then
  local action,title,detail,actionText=stationAction(station)
  if l.contextWidth<350 then
   local kind=station:GetAttribute('Interaction')
   if kind=='Pack' then title='Upgrade pack';detail=pending() and 'Your saved cards are ready' or '3 cards · choose 1'
   elseif kind=='Prestige' then title='Grow your fleet';detail='Keep fleet · gain one drone'
   elseif kind=='Sell' then title='Sell backpack';detail='Sell the ore you carried here' end
  end
  if action then contextAction=function() performStation(station) end;contextTitle.Text=title;contextDetail.Text=detail;contextButton.Text=(actionText or 'Use')..(touch and '' or ' [E]');context.Visible=true end
 elseif not modal.Visible then
  local hr=ownerRoot();local nearest,best=nil,46;local fields=world:FindFirstChild('Fields')
  if hr and fields then for _,field in ipairs(fields:GetChildren()) do
   local floor=field:FindFirstChild('FieldFloor') or field:FindFirstChildWhichIsA('BasePart')
   if floor then local n=(floor.Position-hr.Position).Magnitude;if n<best then nearest=field;best=n end end
  end end
  if nearest then
   local id=nearest:GetAttribute('FieldId') or nearest:GetAttribute('Tier')
   if id then
    local phase=nearest:GetAttribute('Phase') or 'Safe'
    local guarded=not fieldUnlocked(nearest) and (phase=='Guarded' or phase=='Active')
    local assigned=false
    for source in pairs(drones) do
     local state=source:GetAttribute('State')
     if source:GetAttribute('Owner')==player.UserId and source:GetAttribute('AutoFieldId')==id
      and (state=='Mine' or state=='Travel' or state=='Deliver' or state=='Full' or state=='Attack') then assigned=true;break end
    end
    if not assigned and (guarded or availableAutomaticWorker()) then
     contextAction=function() requestPlot(id) end;contextTitle.Text=nearest:GetAttribute('DisplayName') or nearest.Name
     local actionText=guarded and 'Fight' or 'Automate'
     contextDetail.Text=guarded and 'Defeat guards once to unlock' or (number(nearest:GetAttribute('Hardness') or 1)..'× work · crystals replenish')
     contextButton.Text=actionText..(touch and '' or ' [E]');context.Visible=true
    end
   end
  end
 end
 if l.contextReplacesHUD and context.Visible then hud.Visible=false end
 local hr=ownerRoot();local nearestEnemy,dist=nil,65
 if hr then for turret in pairs(turrets) do if turret.Parent then
  local hp=turret:GetAttribute('HP') or 0;local rootPart=turret.PrimaryPart or turret:FindFirstChildWhichIsA('BasePart',true)
  local n=rootPart and (rootPart.Position-hr.Position).Magnitude or math.huge
  if not fieldUnlocked(turret.Parent) and hp>0 and n<dist then nearestEnemy=turret;dist=n end
 end end end
 enemyHUD.Visible=nearestEnemy~=nil and ownActive and not modal.Visible
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
 toast.Visible=notice.Text~='' and not modal.Visible and not (l.short and ownActive)
 if l.short then toast.Position=UDim2.fromOffset(l.hudX,l.hudY);if toast.Visible then hud.Visible=false end end
 if toast.Visible and view.X<1100 then objectiveBox.Visible=false end
 if modal.Visible and notice.Text~='' and noticeUntil>os.clock() then
  modalSubtitle.Text=notice.Text;modalSubtitle.TextColor3=palette.ink
 else modalSubtitle.Text=normalSubtitle;modalSubtitle.TextColor3=palette.muted end
 tacticalHUD:update(view,world,ownActive)
end)
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),refreshModal)
connect(gui.Destroying,function()
 commandView:destroy();pickupView:destroy();impactConnection:Disconnect()
 RunService:UnbindFromRenderStep('MiningAwayCameraRestore');RunService:UnbindFromRenderStep('MiningAwayCameraFeedback')
 if shakeCamera and workspace.CurrentCamera==shakeCamera then shakeCamera.CFrame=shakeCamera.CFrame*previousShake:Inverse() end
 abilityView.destroy()
 tacticalHUD:destroy()
 crystalAudio:destroy()
 soundscape:destroy()
 presentation:destroy()
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,c in pairs(observed) do c:Disconnect() end
 for part in pairs(hiddenParts) do if part.Parent then part.LocalTransparencyModifier=0 end end
 localFX:Destroy()
end)

