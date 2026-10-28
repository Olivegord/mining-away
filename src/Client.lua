-- Presentation and bounded intent only. Gameplay never reads these local viewmodels.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local TweenService=game:GetService('TweenService')
local TextService=game:GetService('TextService')
local Debris=game:GetService('Debris')
local player=Players.LocalPlayer
local world=workspace:WaitForChild('MiningAway')
local command=RS:WaitForChild('MiningAway'):WaitForChild('Command')
local localFX=Instance.new('Folder');localFX.Name='MiningAwayPresentation';localFX.Parent=workspace
local presentation=Presentation.new({parent=localFX})
local drones,resources,resourceIndex,turrets,connections={},{},{},{},{}
local hiddenParts={}
local pendingDroneSources={}
local templateRetryQueued=false
local profile=nil
local U=Interface
local palette=U.palette
local colors={Blue=Color3.fromRGB(99,198,246),Red=Color3.fromRGB(243,117,112),Green=Color3.fromRGB(122,219,163)}
local gui=Instance.new('ScreenGui');gui.Name='MiningAwayHUD';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=12;gui.Parent=player:WaitForChild('PlayerGui')
local safeRoot=U.frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1));safeRoot.Name='SafeContent';safeRoot.BackgroundTransparency=1
local uiClick=Instance.new('Sound');uiClick.Name='InstrumentClick';uiClick.SoundId='rbxasset://sounds/volume_slider.ogg';uiClick.PlaybackSpeed=1.6;uiClick.Volume=.12;uiClick.Parent=gui
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
 local b=U.button(parent,pos,size,text,function() uiClick:Play();if callback then callback() end end,color)
 b:SetAttribute('EnabledColor',color or palette.mineral);return b
end
local function enableAction(b,enabled) U.setEnabled(b,enabled) end
local openOffer,openPack,openPrestige,openFleet,openRunCards
local beginDroneSelection,requestRecall
local hud=U.panel(safeRoot,UDim2.fromOffset(16,12),UDim2.fromOffset(360,88));hud.Name='Resources';hud.Active=true
U.icon(hud,'coin',UDim2.fromOffset(12,3),UDim2.fromOffset(30,30),palette.accent)
local creditsLabel=label(hud,UDim2.fromOffset(58,4),UDim2.new(1,-190,0,32),'0',28,palette.ink,true);creditsLabel.Name='Credits'
local saveLabel=label(hud,UDim2.fromOffset(14,35),UDim2.new(1,-145,0,18),'LOADING',16,palette.muted);saveLabel.Name='SaveStatus'
local cargoText=label(hud,UDim2.fromOffset(15,53),UDim2.new(1,-158,0,18),'Cargo 0/120',16,palette.ink,true);cargoText.Name='Cargo'
local cargoTrack=frame(hud,UDim2.fromOffset(14,76),UDim2.new(1,-158,0,6),palette.paper);corner(cargoTrack,3)
local cargoFill=frame(cargoTrack,UDim2.fromScale(0,0),UDim2.fromScale(0,1),palette.mineral);corner(cargoFill,3)
local fleetButton=button(hud,UDim2.new(1,-130,0,10),UDim2.fromOffset(52,64),'',function() if openFleet then openFleet() end end,palette.mineral:Lerp(palette.white,.48));fleetButton.Name='OpenFleet'
U.icon(fleetButton,'drone',UDim2.fromOffset(11,3),UDim2.fromOffset(30,30),colors.Blue)
local fleetCount=label(fleetButton,UDim2.fromOffset(0,34),UDim2.new(1,0,0,23),'1',16,palette.ink,true);fleetCount.TextXAlignment=Enum.TextXAlignment.Center
local runButton=button(hud,UDim2.new(1,-68,0,10),UDim2.fromOffset(52,64),'',function() if profile and profile.run.pendingOffer then openOffer() else openRunCards() end end,palette.accent:Lerp(palette.white,.45));runButton.Name='OpenRunCards'
U.icon(runButton,'cards',UDim2.fromOffset(11,3),UDim2.fromOffset(30,30),palette.accent)
local runCount=label(runButton,UDim2.fromOffset(0,34),UDim2.new(1,0,0,23),'0',16,palette.ink,true);runCount.TextXAlignment=Enum.TextXAlignment.Center
local objectiveBox=U.panel(safeRoot,UDim2.fromOffset(16,108),UDim2.fromOffset(360,48),palette.panel,10);objectiveBox.Name='NextStep'
U.icon(objectiveBox,'crystal',UDim2.fromOffset(9,9),UDim2.fromOffset(27,27),palette.mineral)
local objective=label(objectiveBox,UDim2.fromOffset(43,5),UDim2.new(1,-52,1,-10),'Mine a field, then sell your cargo.',16,palette.ink);objective.Name='Objective'
local toast=U.panel(safeRoot,UDim2.fromOffset(0,170),UDim2.fromOffset(420,50),palette.panel,12);toast.Name='Feedback';toast.ZIndex=80;toast.Visible=false
local notice=label(toast,UDim2.fromOffset(14,6),UDim2.new(1,-28,1,-12),'',16,palette.ink,true);notice.TextXAlignment=Enum.TextXAlignment.Center
local recall=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(118,44),'Recall [R]',function() if requestRecall then requestRecall() end end,palette.panel);recall.Name='Recall'
local context=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(420,72),palette.panel,14);context.Name='ContextAction';context.Active=true;context.Visible=false
local contextIcon=U.icon(context,'mining',UDim2.fromOffset(12,17),UDim2.fromOffset(34,34),palette.mineral)
local contextTitle=label(context,UDim2.fromOffset(12,4),UDim2.new(1,-132,0,26),'',18,palette.ink,true);contextTitle.Name='ContextTitle'
local contextDetail=label(context,UDim2.fromOffset(12,30),UDim2.new(1,-132,0,40),'',16,palette.muted);contextDetail.Name='ContextDetail'
local contextAction=nil
local contextButton=button(context,UDim2.new(1,-112,0,14),UDim2.fromOffset(100,44),'Use [E]',function() if contextAction then contextAction() end end)
contextButton.Name='UseContext'
local modal=frame(safeRoot,UDim2.fromScale(0,0),UDim2.fromScale(1,1),palette.ink);modal.Name='MenuLayer';modal.BackgroundTransparency=.22;modal.Visible=false;modal.ZIndex=20;modal.Active=true
local sheet=U.panel(modal,UDim2.fromOffset(12,12),UDim2.fromOffset(1010,664),palette.panel,20);sheet.Name='MenuSheet';sheet.ZIndex=21
local sheetScale=Instance.new('UIScale');sheetScale.Parent=sheet
local modalEmblem=U.icon(sheet,'cards',UDim2.fromOffset(20,19),UDim2.fromOffset(54,54),palette.mineral)
local modalTitle=label(sheet,UDim2.fromOffset(90,18),UDim2.new(1,-158,0,39),'Build your next adventure',30,palette.ink,true)
local modalSubtitle=label(sheet,UDim2.fromOffset(24,66),UDim2.new(1,-48,0,32),'',16,palette.muted)
local close=button(sheet,UDim2.new(1,-62,0,16),UDim2.fromOffset(44,44),'X',function() modal.Visible=false end,palette.danger);close.Name='CloseMenu';close.TextColor3=palette.white;close:FindFirstChildOfClass('UIGradient').Enabled=false
local body=Instance.new('ScrollingFrame');body.Name='MenuContent';body.Position=UDim2.fromOffset(24,112);body.Size=UDim2.new(1,-48,1,-136);body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=4;body.ScrollBarImageColor3=palette.muted;body.CanvasSize=UDim2.fromScale(0,0);body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.ZIndex=22;body.Parent=sheet
local modalMode,modalSize=nil,nil
local availabilitySignature=''
local actionPending=nil
local revealGeneration,revealTweens,lastRevealId=0,{},nil
local offerActions,offerButtons,offerReady,offerHosts={},{},{},{}
local skipOffer=nil
local offerExtras={}
local focusedOfferId,focusedIndex=nil,1
local pendingClaim,offerConfirmAction=nil,nil
local function cancelOfferReveal()
 revealGeneration+=1
 for _,tween in ipairs(revealTweens) do tween:Cancel() end
 revealTweens={};offerActions={};offerButtons={};offerReady={};offerHosts={}
 if skipOffer then skipOffer:Destroy();skipOffer=nil end
 for _,x in ipairs(offerExtras) do x:Destroy() end;offerExtras={}
 offerConfirmAction=nil
end
local function clearBody() cancelOfferReveal();for _,x in ipairs(body:GetChildren()) do x:Destroy() end;body.CanvasPosition=Vector2.zero end
connect(modal:GetPropertyChangedSignal('Visible'),function() if not modal.Visible then cancelOfferReveal() end end)
local function reducedMotion()
 if profile and profile.settings and profile.settings.reducedMotion==true then return true end
 local ok,value=pcall(function() return game:GetService('GuiService').ReducedMotionEnabled end)
 return ok and value==true
end
local function tx() return Http:GenerateGUID(false) end
local function send(action,data)
 if not profile or not profile.run or actionPending or profile.pendingTransaction then return false end
 data=data or {};data.txId=data.txId or tx();data.runId=profile.run.id
 actionPending={kind=action,at=os.clock(),runId=profile.run.id,packIndex=profile.run.packIndex,offerId=profile.run.pendingOffer and profile.run.pendingOffer.id}
 command:FireServer(action,data);return data.txId
end
local function comma(n) local s=tostring(math.floor(tonumber(n) or 0));local r=s:reverse():gsub('(%d%d%d)','%1,'):reverse();return (r:gsub('^,','')) end
local function cargoUnits(p) local n=0;for _,v in pairs((p.run and p.run.cargo) or {}) do if type(v)=='number' then n=n+v end end;return n end
local function pending() return profile and profile.run and profile.run.pendingOffer end
local function viewport()
 local size=safeRoot.AbsoluteSize
 if size.X>1 and size.Y>1 then return size end
 local camera=workspace.CurrentCamera;return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function currentLayout() local v=viewport();return UILayout.calculate(v.X,v.Y,UIS.TouchEnabled and not UIS.KeyboardEnabled) end
local function layoutModal()
 local v=viewport();local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 local l=modalMode=='offer' and UILayout.offer(v.X,v.Y,touch) or ((modalMode=='fleet' or modalMode=='run') and UILayout.inspector(v.X,v.Y,touch) or currentLayout())
 sheet.Size=UDim2.fromOffset(l.panelWidth,l.panelHeight);sheet.Position=UDim2.fromOffset(l.panelX,l.panelY);modalSize=v
 local isOffer=modalMode=='offer'
 local subtitleY=66
 local subtitleHeight=l.short and 29 or 32
 if not isOffer then
  local ok,bounds=pcall(function() return TextService:GetTextSize(modalSubtitle.Text,16,Enum.Font.GothamMedium,Vector2.new(math.max(1,l.bodyWidth),1000)) end)
  if ok then subtitleHeight=math.max(subtitleHeight,math.ceil(bounds.Y)+6) end
  l.headerHeight=math.max(l.headerHeight,subtitleY+subtitleHeight+8)
  l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-l.panelPadding)
 end
 body.Position=UDim2.fromOffset(isOffer and l.bodyX or l.panelPadding,isOffer and l.bodyY or l.headerHeight);body.Size=UDim2.fromOffset(l.bodyWidth,l.bodyHeight)
 body.AutomaticCanvasSize=isOffer and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
 body.ScrollingDirection=isOffer and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
 modal.BackgroundTransparency=isOffer and .94 or ((modalMode=='fleet' or modalMode=='run') and .9 or .22)
 sheet.BackgroundTransparency=isOffer and 1 or 0
 local stroke=sheet:FindFirstChildOfClass('UIStroke');if stroke then stroke.Enabled=not isOffer end
 modalTitle.Visible=not isOffer;modalSubtitle.Visible=not isOffer;close.Visible=not isOffer
 modalTitle.TextSize=isOffer and (UILayout.compactMenuTitles(l.panelWidth) and 19 or 22) or (UILayout.compactMenuTitles(l.panelWidth) and 23 or 30)
 modalTitle.Position=UDim2.fromOffset(isOffer and 57 or (UILayout.compactMenuTitles(l.panelWidth) and 74 or 90),isOffer and 12 or 16)
 modalTitle.Size=UDim2.new(1,isOffer and -221 or (UILayout.compactMenuTitles(l.panelWidth) and -136 or -158),0,isOffer and 34 or 43)
 modalEmblem.Size=UDim2.fromOffset(isOffer and 30 or (UILayout.compactMenuTitles(l.panelWidth) and 42 or 54),isOffer and 30 or (UILayout.compactMenuTitles(l.panelWidth) and 42 or 54))
 modalEmblem.Position=UDim2.fromOffset(18,18)
 modalSubtitle.Position=UDim2.fromOffset(l.panelPadding,isOffer and 63 or subtitleY)
 modalSubtitle.Size=UDim2.new(1,-l.panelPadding*2,0,isOffer and 23 or subtitleHeight)
 return l
end
local menuTween=nil
local normalSubtitle=''
local function menu(mode,title,subtitle,icon)
 local entering=not modal.Visible or modalMode~=mode
 modalMode=mode;sheet:SetAttribute('MenuMode',mode);clearBody();modalTitle.Text=title;modalSubtitle.Text=subtitle;normalSubtitle=subtitle;local l=layoutModal()
 if UILayout.compactMenuTitles(l.panelWidth) then
  local shortTitles={pack='Upgrade pack',offer='Pick one',fleet='Your crew',run='Run upgrades',prestige='Grow your fleet'}
  modalTitle.Text=shortTitles[mode] or title;modalTitle.TextSize=mode=='prestige' and 18 or 20
 end
 if modalEmblem then modalEmblem:Destroy() end
 modalEmblem=U.icon(sheet,icon,UDim2.fromOffset(18,18),UDim2.fromOffset(mode=='offer' and 30 or (UILayout.compactMenuTitles(l.panelWidth) and 42 or 54),mode=='offer' and 30 or (UILayout.compactMenuTitles(l.panelWidth) and 42 or 54)),palette.mineral)
 modalEmblem.Visible=mode~='offer'
 modal.Visible=true
 if entering then
  if menuTween then menuTween:Cancel() end
  if reducedMotion() then sheetScale.Scale=1 else sheetScale.Scale=.98;menuTween=TweenService:Create(sheetScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1});menuTween:Play() end
 end
 return l
end
local function atHomeUI()
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart');local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 return hr and spawn and (hr.Position-spawn.Position).Magnitude<30
end
local function availability(action)
 if not profile then return false,'Connecting…' end
 if actionPending or profile.pendingTransaction then return false,'Waiting for confirmation…' end
 if player:GetAttribute('MA_InAssault') then return false,'Recall your assault fleet first' end
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
    if title=='Shared cargo' then title='Cargo';unit='ore' end
    local separator=(unit=='' or unit=='%' or unit=='×') and '' or ' '
    table.insert(result,title..'  '..number(before)..' → '..number(after)..separator..unit)
    if #result==4 then break end
   end
  end
 end
 return result
end
local function targetText(choice)
 if choice.scope=='Individual' then return 'ONE DRONE / '..(choice.targetName or 'Assigned drone') end
 if choice.scope=='Color' then return 'ALL '..string.upper(choice.type or '')..' DRONES' end
 return choice.scope=='Player' and 'SHARED CARGO HOLD' or 'ENTIRE FLEET'
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
 label(parent,UDim2.fromOffset(0,y),UDim2.fromOffset(width,24),title,17,palette.ink,true)
 label(parent,UDim2.fromOffset(0,y+28),UDim2.fromOffset(width,48),detail,16,palette.muted)
 local track=frame(parent,UDim2.fromOffset(0,y+81),UDim2.fromOffset(width,10),palette.paper);corner(track,5)
 local fill=frame(track,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(fraction,0,1),1),color);corner(fill,5)
end
openOffer=function()
 local offer=pending();if not offer then return end
 local l=menu('offer','Choose one card','','cards')
 local motionOff=reducedMotion();U.setReducedMotion(motionOff)
 local animate=not motionOff and lastRevealId~=offer.id;lastRevealId=offer.id
 if focusedOfferId~=offer.id then focusedOfferId=offer.id;focusedIndex=1 end
 if pendingClaim and pendingClaim.offerId==offer.id then focusedIndex=pendingClaim.index end
 local generation=revealGeneration
 local allowed,reason=availability('ChooseCard');availabilitySignature='offer:'..tostring(allowed)..':'..reason
 local list=Instance.new('UIListLayout');list.FillDirection=Enum.FillDirection.Horizontal;list.Padding=UDim.new(0,l.cardGap);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 local padding=Instance.new('UIPadding');padding.PaddingLeft=UDim.new(0,math.max(0,math.floor((l.bodyWidth-(#offer.choices*(l.cardWidth+6)+(#offer.choices-1)*l.cardGap))/2)));padding.Parent=body
 local details=U.panel(sheet,UDim2.fromOffset(l.detailX,l.detailY),UDim2.fromOffset(l.detailWidth,l.detailHeight),palette.panel,9);details.Name='FocusedCardDetail';details.ZIndex=24;table.insert(offerExtras,details)
 local detailContent=Instance.new('ScrollingFrame');detailContent.BackgroundTransparency=1;detailContent.BorderSizePixel=0;detailContent.ScrollBarThickness=4;detailContent.Size=UDim2.new(1,-20,1,-16);detailContent.Position=UDim2.fromOffset(10,8);detailContent.AutomaticCanvasSize=Enum.AutomaticSize.Y;detailContent.CanvasSize=UDim2.fromScale(0,0);detailContent.ZIndex=25;detailContent.Parent=details
 local choose=button(sheet,UDim2.fromOffset(l.actionX,l.actionY),UDim2.fromOffset(l.actionWidth,44),'Choose',function() if offerConfirmAction then offerConfirmAction() end end,palette.accent);choose.Name='ConfirmCard';choose.TextSize=16;table.insert(offerExtras,choose)
 local later=button(sheet,UDim2.fromOffset(l.closeX,l.closeY),UDim2.fromOffset(l.closeWidth,44),'Later',function() modal.Visible=false end,palette.paper);later.Name='CloseOffer';later.TextSize=16;table.insert(offerExtras,later)
 local views={};local focusCard
 local function revealAll()
  for _,tween in ipairs(revealTweens) do tween:Cancel() end;revealTweens={}
  for n,h in pairs(offerHosts) do h.group.GroupTransparency=0;h.scale.Scale=1;offerReady[n]=true end
  choose.Text=allowed and 'Choose' or reason
  if focusCard then focusCard(focusedIndex,false) end
 end
 local function allReady() for i=1,#offer.choices do if not offerReady[i] then return false end end;return true end
 focusCard=function(index,scroll)
  if not offerReady[index] or not views[index] or not UILayout.offerFocusAllowed(offer.id,index,pendingClaim) then return end
  focusedIndex=index
  for n,v in pairs(views) do v.setFocus(n==index,motionOff) end
  for _,child in ipairs(detailContent:GetChildren()) do child:Destroy() end
  local layout=Instance.new('UIListLayout');layout.Padding=UDim.new(0,5);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=detailContent
  local choice=offer.choices[index]
  local order=0
  local function line(text,bold,size,color)
   if not text or text=='' then return end;order+=1
   local item=label(detailContent,UDim2.fromOffset(0,0),UDim2.new(1,-6,0,0),text,size,color or palette.ink,bold)
   item.LayoutOrder=order;item.AutomaticSize=Enum.AutomaticSize.Y;item.TextWrapped=true;item.TextYAlignment=Enum.TextYAlignment.Top;item.ZIndex=26
  end
  line(choice.title,true,18);line(targetText(choice),true,18)
  line(choice.description,false,16)
  for _,row in ipairs(previewRows(choice)) do line(row,true,18) end
  line(choice.tradeoff and ('Tradeoff: '..choice.tradeoff) or 'No stat penalty',false,16)
  line('THIS RUN • '..stackText(choice),false,16,palette.muted)
  if choice.rarity=='Common' or choice.rarity=='Uncommon' or choice.rarity=='Rare' then line(choice.rarity..' • '..categoryText(choice),false,16,palette.muted) end
  detailContent.CanvasPosition=Vector2.zero
  if scroll then local h=offerHosts[index].group;local x=h.AbsolutePosition.X-body.AbsolutePosition.X+body.CanvasPosition.X;body.CanvasPosition=Vector2.new(math.clamp(x-(l.bodyWidth-h.AbsoluteSize.X)/2,0,math.max(0,body.AbsoluteCanvasSize.X-body.AbsoluteWindowSize.X)),0) end
  if not l.shortOffer then local h=offerHosts[index].group;local x=h.AbsolutePosition.X-sheet.AbsolutePosition.X+h.AbsoluteSize.X/2-l.detailWidth/2;details.Position=UDim2.fromOffset(math.clamp(x,0,l.panelWidth-l.detailWidth),l.detailY) end
 end
 offerConfirmAction=function()
  if not allReady() then revealAll();return end
  if not offerReady[focusedIndex] or not pending() or pending().id~=offer.id or not canAct() or (pendingClaim and (pendingClaim.uncertain or pendingClaim.accepted)) then return end
  local choice=offer.choices[focusedIndex];local index=focusedIndex
  local claimTx=send('ChooseCard',{offerId=offer.id,index=index,txId=UILayout.claimRetryId(offer.id,index,pendingClaim)})
  if claimTx then
   pendingClaim={txId=claimTx,offerId=offer.id,runId=profile.run.id,index=index,cardId=choice.cardId,targetDroneId=choice.targetDroneId,cardCount=#profile.run.cards}
   choose.Text='Installing…';enableAction(choose,false)
  end
 end
 for index,choice in ipairs(offer.choices) do
  local host=Instance.new('CanvasGroup');host.Name='OfferSlot'..index;host.LayoutOrder=index;host.Size=UDim2.fromOffset(l.cardWidth+6,l.cardHeight+6);host.BackgroundTransparency=1;host.ZIndex=23;host.Parent=body
  host.GroupTransparency=animate and 1 or 0;local scale=Instance.new('UIScale');scale.Scale=animate and .98 or 1;scale.Parent=host
  views[index]=CardView.create(U,host,choice,index,l.cardWidth,l.cardHeight,{offerCompact=true,category=categoryText(choice),target=targetText(choice),previewRows=previewRows(choice),onFocus=function(n) focusCard(n,false) end})
  offerHosts[index]={group=host,scale=scale};offerReady[index]=not animate;offerActions[index]=function() focusCard(index,true) end;offerButtons[index]=views[index].button
  if animate then task.delay(UILayout.revealDelay(index,false),function()
   if generation~=revealGeneration or not modal.Visible or not pending() or pending().id~=offer.id or not host.Parent or offerReady[index] then return end
   local fade=TweenService:Create(host,TweenInfo.new(.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=0});local lift=TweenService:Create(scale,TweenInfo.new(.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1});table.insert(revealTweens,fade);table.insert(revealTweens,lift)
   fade.Completed:Connect(function(state) if state~=Enum.PlaybackState.Completed or generation~=revealGeneration or not host.Parent then return end;offerReady[index]=true;if index==focusedIndex then focusCard(index,false) end;if allReady() then choose.Text=allowed and 'Choose' or reason end end);fade:Play();lift:Play()
  end) end
 end
 choose.Text=animate and 'Reveal all' or (allowed and 'Choose' or reason)
 if not animate then task.defer(function() if generation==revealGeneration and modal.Visible then focusCard(focusedIndex,false) end end) end
 for index,b in pairs(offerButtons) do b.NextSelectionLeft=offerButtons[index-1];b.NextSelectionRight=offerButtons[index+1];b.NextSelectionDown=choose end
end
openPack=function()
 if pending() then openOffer();return end
 if not profile or not profile.run then return end
 local l=menu('pack','Upgrade pack','Three saved choices. Pick one for this run.','cards')
 local width=l.bodyWidth-6
 local hero=U.panel(body,UDim2.fromOffset(3,3),UDim2.fromOffset(width,168),palette.mineral:Lerp(palette.white,.72),16)
 U.icon(hero,'cards',UDim2.fromOffset(18,20),UDim2.fromOffset(58,58),palette.mineral)
 local price=profile.nextPackPrice or 80;local credits=profile.run.credits or 0;local affordable=credits>=price
 label(hero,UDim2.fromOffset(88,15),UDim2.new(1,-104,0,31),'PACK '..tostring(profile.run.packIndex+1),18,palette.muted,true)
 label(hero,UDim2.fromOffset(88,51),UDim2.new(1,-104,0,47),comma(price)..' credits',22,palette.ink,true)
 label(hero,UDim2.fromOffset(18,109),UDim2.new(1,-36,0,48),'Choose one upgrade. Cards reset at prestige.',16,palette.ink)
 progress(body,192,width,'Pack fund',comma(credits)..' / '..comma(price)..' credits',credits/math.max(1,price),palette.accent)
 local allowed,blocked=availability('BuyPack')
 local text=not allowed and blocked or (affordable and 'Open pack · '..comma(price)..' credits' or 'Sell '..comma(price-credits)..' more credits of ore')
 local buy
 buy=button(body,UDim2.fromOffset(3,302),UDim2.fromOffset(width,54),text,function()
  if canAct('BuyPack') and affordable and send('BuyPack',{packIndex=profile.run.packIndex}) then buy.Text='Opening…';enableAction(buy,false) end
 end,palette.accent);buy.Name='BuyPack';enableAction(buy,canAct('BuyPack') and affordable)
 label(body,UDim2.fromOffset(8,373),UDim2.fromOffset(width-10,50),'Your permanent drones stay yours.',16,palette.muted)
end
local function wrappedHeight(text,width,size,bold,minimum)
 local ok,bounds=pcall(function() return TextService:GetTextSize(text,size,bold and Enum.Font.FredokaOne or Enum.Font.GothamMedium,Vector2.new(math.max(1,width),1000)) end)
 return math.max(minimum or 0,ok and math.ceil(bounds.Y)+8 or 96)
end
local focusedFleetId=nil
local restoreFleetFocus=false
local function tabs(width,mode)
 local a=button(body,UDim2.fromOffset(3,2),UDim2.fromOffset(112,44),'Fleet ('..#profile.fleet..')',openFleet,mode=='fleet' and palette.mineral or palette.paper)
 local b=button(body,UDim2.fromOffset(121,2),UDim2.fromOffset(112,44),'Run ('..#profile.run.cards..')',openRunCards,mode=='run' and palette.accent or palette.paper)
 a.Name='FleetTab';b.Name='RunTab'
end
-- The actual preserved drone template is used when present. The viewport is
-- cosmetic only: it never sends commands or substitutes for server models.
local function fleetPortrait(parent,tint)
 local template=RS:FindFirstChild('Drone')
 if not template or not template:IsA('Model') then U.icon(parent,'drone',UDim2.fromOffset(10,12),UDim2.fromOffset(58,58),tint);return end
 local view=Instance.new('ViewportFrame');view.Name='OriginalDronePortrait';view.BackgroundTransparency=1;view.Size=UDim2.fromOffset(70,70);view.Position=UDim2.fromOffset(8,6);view.ZIndex=23;view.Parent=parent
 local ok=pcall(function()
  local model=template:Clone()
  for _,part in ipairs(model:GetDescendants()) do
   if part:IsA('LuaSourceContainer') or part:IsA('Sound') or part:IsA('ParticleEmitter') or part:IsA('Beam') or part:IsA('Trail') then part:Destroy()
   elseif part:IsA('BasePart') then part.Anchored=true;part.CanCollide=false end
  end
  local worldModel=Instance.new('WorldModel');worldModel.Parent=view;model.Parent=worldModel
  local center,size=model:GetBoundingBox();local radius=math.max(size.X,size.Y,size.Z,1)
  local camera=Instance.new('Camera');camera.CFrame=CFrame.lookAt(center.Position+Vector3.new(radius*1.3,radius*.9,radius*1.7),center.Position);camera.Parent=view;view.CurrentCamera=camera
 end)
 if not ok then view:Destroy();U.icon(parent,'drone',UDim2.fromOffset(10,12),UDim2.fromOffset(58,58),tint) end
end
openFleet=function()
 if not profile then return end
 local l=menu('fleet','Your crew','Drones are permanent; stats include run cards.','drone');local width=l.bodyWidth-6
 tabs(width,'fleet')
 local roster=Instance.new('ScrollingFrame');roster.Name='FleetRoster';roster.Position=UDim2.fromOffset(3,54);roster.Size=UDim2.fromOffset(width,49)
 roster.BackgroundTransparency=1;roster.BorderSizePixel=0;roster.ScrollBarThickness=3;roster.ScrollingDirection=Enum.ScrollingDirection.X;roster.AutomaticCanvasSize=Enum.AutomaticSize.X;roster.CanvasSize=UDim2.fromScale(0,0);roster.Parent=body
 local flow=Instance.new('UIListLayout');flow.FillDirection=Enum.FillDirection.Horizontal;flow.SortOrder=Enum.SortOrder.LayoutOrder;flow.Padding=UDim.new(0,6);flow.Parent=roster
 local selected=UILayout.focusFleet(profile.fleet,focusedFleetId);focusedFleetId=selected and selected.id or nil
 for index,d in ipairs(profile.fleet or {}) do
  local text=d.name or ('Drone '..index);local tab=button(roster,UDim2.fromOffset(0,0),UDim2.fromOffset(112,44),text,function() restoreFleetFocus=game:GetService('GuiService').SelectedObject~=nil;focusedFleetId=d.id;openFleet() end,d==selected and palette.mineral or palette.paper)
  tab.Name='FleetMember'..index;tab.LayoutOrder=index;tab.TextSize=16;tab:SetAttribute('Focused',d==selected)
  if d==selected then task.spawn(function() RunService.Heartbeat:Wait();if roster.Parent and tab.Parent then local x=math.max(0,(index-1)*118+112-roster.AbsoluteWindowSize.X);roster.CanvasPosition=Vector2.new(math.min(x,math.max(0,roster.AbsoluteCanvasSize.X-roster.AbsoluteWindowSize.X)),0);if restoreFleetFocus then game:GetService('GuiService').SelectedObject=tab;restoreFleetFocus=false end end end) end
 end
 if selected then
  local stats=(profile.droneStats and profile.droneStats[selected.id]) or selected.effective or selected.base or {}
  local tint=colors[selected.type] or palette.mineral
  local panel=U.panel(body,UDim2.fromOffset(3,111),UDim2.fromOffset(width,194),tint:Lerp(palette.white,.82),10);panel.Name='FleetDrone'
  fleetPortrait(panel,tint)
  local name=selected.name or 'Drone';local nameHeight=wrappedHeight(name,width-94,20,true,25)
  local identityHeight=wrappedHeight(selected.type or 'Blue',width-94,16,false,23)
  label(panel,UDim2.fromOffset(82,6),UDim2.new(1,-90,0,nameHeight),name,20,palette.ink,true)
  label(panel,UDim2.fromOffset(82,9+nameHeight),UDim2.new(1,-90,0,identityHeight),selected.type or 'Blue',16,palette.muted)
  local statsY=math.max(75,12+nameHeight+identityHeight)
  local col=(width-28)/2
  label(panel,UDim2.fromOffset(10,statsY),UDim2.fromOffset(col,25),'Mine  '..number(stats.miningDPS or 30)..'/s',16,palette.ink,true)
  label(panel,UDim2.fromOffset(14+col,statsY),UDim2.fromOffset(col,25),'Fight  '..number(stats.combatDPS or 12)..'/s',16,palette.ink,true)
  label(panel,UDim2.fromOffset(10,statsY+28),UDim2.fromOffset(col,25),'Hull  '..number(stats.maxHealth or 80),16,palette.ink,true)
  label(panel,UDim2.fromOffset(14+col,statsY+28),UDim2.fromOffset(col,25),'Warmup  '..number(stats.warmup or .8)..'s',16,palette.ink,true)
  local selectDrone=button(panel,UDim2.fromOffset(10,statsY+59),UDim2.fromOffset(math.min(width-20,150),44),'Select',function() beginDroneSelection(selected) end,palette.mineral);selectDrone.Name='SelectDrone';selectDrone.TextSize=16
  panel.Size=UDim2.fromOffset(width,statsY+113)
  local y=111+statsY+125
  local nextDrone=button(body,UDim2.fromOffset(3,y),UDim2.fromOffset(math.min(width,174),44),'Next drone',openPrestige,palette.accent);nextDrone.Name='NextDrone'
  local pre=profile.prestigePreview or {}
  label(body,UDim2.fromOffset(3,y+50),UDim2.fromOffset(width,50),comma(pre.earnings or 0)..' / '..comma(pre.saleRequired or 2000)..' sold · '..(pre.field or 'Cobalt')..' '..(pre.wins or 0)..' / '..(pre.winsRequired or 1),16,palette.muted)
 end
end
openRunCards=function()
 if not profile then return end
 local l=menu('run','Run cards','Cards survive reprints; prestige clears them.','cards');local width=l.bodyWidth-6
 tabs(width,'run')
 if #profile.run.cards==0 then
  label(body,UDim2.fromOffset(8,65),UDim2.fromOffset(width-16,54),'Mine and sell ore to choose a card.',16,palette.ink)
  button(body,UDim2.fromOffset(8,125),UDim2.fromOffset(math.min(width-16,150),44),'View pack',openPack,palette.accent)
 else
  local y=58
  for index,c in ipairs(profile.run.cards) do
   local title=c.title or 'Run upgrade';local target=targetText(c);local effect=c.description or c.headline or 'See its resolved stats in your fleet.'
   local titleHeight=wrappedHeight(title,width-24,18,true,25);local targetHeight=wrappedHeight(target,width-24,16,true,25);local effectHeight=wrappedHeight(effect,width-24,16,false,32)
   local rowHeight=titleHeight+targetHeight+effectHeight+22
   local row=U.panel(body,UDim2.fromOffset(3,y),UDim2.fromOffset(width,rowHeight),palette.paper,8);row.Name='RunCard'..index
   label(row,UDim2.fromOffset(10,5),UDim2.new(1,-20,0,titleHeight),title,18,palette.ink,true)
   label(row,UDim2.fromOffset(10,7+titleHeight),UDim2.new(1,-20,0,targetHeight),target,16,palette.muted,true)
   label(row,UDim2.fromOffset(10,10+titleHeight+targetHeight),UDim2.new(1,-20,0,effectHeight),effect,16,palette.ink)
   y+=rowHeight+8
  end
 end
end
openPrestige=function()
 if not profile then return end
 local l=menu('prestige','One more drone. A new run.','Review exactly what stays and resets.','prestige');local width=l.bodyWidth-6
 local pre=profile.prestigePreview or {};local before=pre.fleetBefore or #profile.fleet;local after=pre.fleetAfter or before+1
 local hero=U.panel(body,UDim2.fromOffset(3,3),UDim2.fromOffset(width,138),palette.accent:Lerp(palette.white,.63),16)
 U.icon(hero,'drone',UDim2.fromOffset(18,20),UDim2.fromOffset(48,48),colors[pre.newType] or palette.mineral)
 label(hero,UDim2.fromOffset(78,15),UDim2.new(1,-94,0,42),before..' → '..after..' drones',22,palette.ink,true)
 label(hero,UDim2.fromOffset(18,76),UDim2.new(1,-36,0,50),'Gain one permanent '..(pre.newType or 'new')..' drone. Keep your crew.',16,palette.ink)
 local pair=width>=560;local half=pair and (width-18)/2 or width
 local keepText='Every permanent drone\nBuilt-in types, IDs and base traits\nFree reprinting'
 local resetText=#profile.run.cards..' cards · '..comma(profile.run.credits)..' credits · '..cargoUnits(profile)..' ore\nPack prices and sale progress\nYour run’s field clearances'
 local keepHeight=wrappedHeight(keepText,half-28,16,false,96);local resetHeight=wrappedHeight(resetText,half-28,16,false,114)
 local keep=U.panel(body,UDim2.fromOffset(3,158),UDim2.fromOffset(half,keepHeight+56),palette.mineral:Lerp(palette.white,.68),12);keep.Name='PrestigeKeep'
 label(keep,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,26),'YOU KEEP',18,palette.ink,true)
 label(keep,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,keepHeight),keepText,16,palette.ink)
 local resetY=pair and 158 or (158+keepHeight+72)
 local reset=U.panel(body,UDim2.fromOffset(pair and half+21 or 3,resetY),UDim2.fromOffset(half,resetHeight+56),palette.danger:Lerp(palette.white,.83),12);reset.Name='PrestigeReset'
 label(reset,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,26),'YOU RESET',18,palette.ink,true)
 label(reset,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,resetHeight),resetText,16,palette.ink)
 local y=resetY+math.max(pair and keepHeight or 0,resetHeight)+76
 local required=pre.saleRequired or 2000;local earnings=pre.earnings or profile.run.saleEarnings or 0
 progress(body,y,width,'Permanent fleet milestone',comma(earnings)..' / '..comma(required)..' credits sold · '..(pre.field or 'Cobalt')..' clears '..(pre.wins or 0)..' / '..(pre.winsRequired or 1),earnings/math.max(1,required),palette.accent)
 local allowed,blocked=availability('Prestige')
 local can=pre.eligible==true and not pending() and allowed
 local reason=not allowed and blocked or (pending() and 'Choose your paid pack card first' or (can and 'Start new run · +1 permanent drone' or 'Complete both milestone requirements'))
 local confirm
 confirm=button(body,UDim2.fromOffset(3,y+112),UDim2.fromOffset(width,54),reason,function()
  if can and canAct('Prestige') and send('Prestige',{confirm=true}) then confirm.Text='Starting new run…';enableAction(confirm,false) end
 end,palette.accent);confirm.Name='ConfirmPrestige';enableAction(confirm,can)
 label(body,UDim2.fromOffset(8,y+179),UDim2.fromOffset(width-10,58),'Starting a new run clears the reset items above.',16,palette.muted)
end
local refreshSerial=0
local function refreshModal()
 if not modal.Visible then return end
 local savedScroll=body.CanvasPosition;local mode=modalMode
 refreshSerial=refreshSerial+1;local serial=refreshSerial
 if mode=='offer' then if pending() then openOffer() end
 elseif mode=='pack' then openPack()
 elseif mode=='prestige' then openPrestige()
 elseif mode=='fleet' then openFleet()
 elseif mode=='run' then openRunCards() end
 task.defer(function()
  RunService.Heartbeat:Wait()
  if serial==refreshSerial and modal.Visible and modalMode==mode and body.Parent then
   body.CanvasPosition=mode=='offer' and Vector2.new(math.min(savedScroll.X,math.max(0,body.AbsoluteCanvasSize.X-body.AbsoluteWindowSize.X)),0) or Vector2.new(0,math.min(savedScroll.Y,math.max(0,body.AbsoluteCanvasSize.Y-body.AbsoluteWindowSize.Y)))
  end
 end)
end
local lastOffer=nil
local function readProfile()
 local raw=player:GetAttribute('MA_Profile');if type(raw)~='string' then return end
 local ok,p=pcall(function() return Http:JSONDecode(raw) end);if not ok or type(p)~='table' or type(p.run)~='table' then return end
 local oldProfile=profile
 local changedRun=profile and profile.run.id~=p.run.id
 profile=p
 U.setReducedMotion(reducedMotion())
 if actionPending then
  local offer=p.run.pendingOffer
  if changedRun or (actionPending.kind=='ChooseCard' and (not offer or offer.id~=actionPending.offerId)) or (actionPending.kind=='BuyPack' and p.run.packIndex>actionPending.packIndex) then actionPending=nil end
 end
 if changedRun and modalMode=='prestige' then modal.Visible=false end
 local offer=pending()
 if offer and offer.id~=lastOffer then lastOffer=offer.id;openOffer()
 elseif not offer and modalMode=='offer' then
  local claim=pendingClaim;local cards=p.run.cards or {};local last=cards[#cards]
  local confirmed=claim and not changedRun and claim.runId==p.run.id and oldProfile and oldProfile.run.pendingOffer and oldProfile.run.pendingOffer.id==claim.offerId and #cards==claim.cardCount+1 and last and last.cardId==claim.cardId and last.targetDroneId==claim.targetDroneId
  pendingClaim=nil
  if confirmed and not reducedMotion() and offerHosts[claim.index] then
   local g=revealGeneration;local host=offerHosts[claim.index];local pulse=TweenService:Create(host.scale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1.05});table.insert(revealTweens,pulse);pulse:Play()
   task.delay(.18,function() if g==revealGeneration and modal.Visible and modalMode=='offer' and not pending() then modal.Visible=false;modalMode=nil end end)
  else modal.Visible=false;modalMode=nil end
 elseif modalMode=='offer' then -- A paid offer is immutable; cargo changes must not interrupt comparisons.
  if p.pendingTransaction~=(oldProfile and oldProfile.pendingTransaction) then refreshModal() end
 elseif modalMode=='fleet' or modalMode=='run' then
  local oldMilestone=oldProfile and oldProfile.prestigePreview or {}
  local milestone=p.prestigePreview or {}
  local milestoneChanged=modalMode=='fleet' and (oldMilestone.earnings~=milestone.earnings or oldMilestone.wins~=milestone.wins or oldMilestone.eligible~=milestone.eligible)
  if not oldProfile or changedRun or #oldProfile.fleet~=#p.fleet or #oldProfile.run.cards~=#p.run.cards or milestoneChanged then refreshModal() end
 else refreshModal() end
end
connect(player:GetAttributeChangedSignal('MA_Profile'),readProfile);readProfile()
local noticeUntil=0
-- Choice outcomes are correlated to the exact transaction and saved offer.
-- An uncertain save remains locked until server reconciliation resolves it.
connect(gui.Parent:GetAttributeChangedSignal('MA_OfferReceipt'),function()
 local raw=gui.Parent:GetAttribute('MA_OfferReceipt');if type(raw)~='string' then return end
 local ok,result=pcall(function() return Http:JSONDecode(raw) end);if not ok then return end
 local status,reason=UILayout.offerReceipt(pendingClaim,result)
 if not status then return end
 if status=='rejected' then
  if pendingClaim.accepted then return end -- durable acceptance cannot be undone by an older reply
  actionPending=nil;pendingClaim=nil;notice.Text=reason;noticeUntil=os.clock()+6;refreshModal()
 elseif status=='uncertain' then
  pendingClaim.uncertain=true;notice.Text=reason;noticeUntil=os.clock()+8;refreshModal()
 elseif status=='accepted' then
  pendingClaim.uncertain=nil;pendingClaim.accepted=true;notice.Text='Card saved • confirming…';noticeUntil=os.clock()+6;refreshModal()
 end
end)
connect(player:GetAttributeChangedSignal('MA_Notice'),function()
 local message=tostring(player:GetAttribute('MA_Notice') or '')
 notice.Text=message;noticeUntil=os.clock()+5
 -- A success notice can arrive before its profile snapshot: preserve the
 -- committed card until the authoritative saved choice is visible.
 if pendingClaim then
  -- MA_Notice has no transaction ID and may describe unrelated events.
  -- Keep the submitted choice locked until a matching profile outcome.
  refreshModal();return
 end
 actionPending=nil;refreshModal()
end)

local soundCount=0
local function safeSound(name,parent)
 if soundCount>=16 then return end
 local template=RS:FindFirstChild(name,true)
 local sound=template and template:IsA('Sound') and template:Clone() or Instance.new('Sound')
 if not template then sound.SoundId=name=='RockBreak' and 'rbxasset://sounds/impact_explosion_03.mp3' or 'rbxasset://sounds/action_jump_land.mp3';sound.Volume=name=='RockBreak' and .18 or .1;sound.PlaybackSpeed=name=='RockBreak' and 1.7 or 1.9 end
 soundCount=soundCount+1;sound.TimePosition=0;sound.RollOffMinDistance=3;sound.RollOffMaxDistance=55;sound.Parent=parent;sound:Play();Debris:AddItem(sound,3)
 task.delay(3,function() soundCount=math.max(0,soundCount-1) end)
end
local function sanitize(model)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('SurfaceGui') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
  elseif v:IsA('Beam') or v:IsA('Trail') or v:IsA('ParticleEmitter') then v.Enabled=false end
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
 if drones[source] or not source:IsA('Model') then return end
 local id=source:GetAttribute('DroneId');local pos=source:GetAttribute('Position');local kind=source:GetAttribute('Type')
 if not id or typeof(pos)~='Vector3' or not colors[kind] then return end
 pendingDroneSources[source]=true
 -- Render from the complete preserved asset, never a partially streamed gameplay model.
 -- The historical drone is a Part body plus its nested emitter; it has no SpecialMesh.
 local template=RS:FindFirstChild('Drone')
 local mesh=template and template:FindFirstChild('Mesh')
 local templateEmitter=mesh and mesh:FindFirstChild('Emmiter')
 local originalBeam=mesh and mesh:FindFirstChild('Beam')
 if not template or not template:IsA('Model') or not mesh or not mesh:IsA('BasePart')
  or not templateEmitter or not templateEmitter:IsA('BasePart') or not mesh:FindFirstChild('Attachment')
  or not mesh:FindFirstChild('WeldConstraint') or not originalBeam
  or not originalBeam:FindFirstChild('InnerBeam') or not originalBeam:FindFirstChild('OuterBeam') then
  hideModel(source);return
 end
 local clone=template:Clone();if not clone then return end;clone.Name='View_'..tostring(id);sanitize(clone)
 pendingDroneSources[source]=nil
 local pivot=clone.PrimaryPart or clone:FindFirstChildWhichIsA('BasePart',true);if not pivot then clone:Destroy();return end
 clone.PrimaryPart=pivot;clone.Parent=localFX
 local emitter=clone:FindFirstChild('Emmiter',true) or clone:FindFirstChild('MiningEmitter',true) or clone:FindFirstChild('Emitter',true)
 if not emitter or not emitter:IsA('BasePart') then clone:Destroy();pendingDroneSources[source]=true;return end
 local typeColor=colors[source:GetAttribute('Type')]
 emitter.Color=typeColor or emitter.Color
 -- The original 1-stud emitter is enclosed by its 2-stud body; a restrained tint stays visible.
 if typeColor then
  pivot.Color=pivot.Color:Lerp(typeColor,.55)
  -- Keep the authored shell/emitter; small case seams make its type readable in flight.
  local trim=localPart(clone,'LowerChassis',pivot.Position);trim.Size=Vector3.new(pivot.Size.X*1.015,.12,pivot.Size.Z*1.015);trim.Transparency=0;trim.Color=Color3.fromRGB(23,35,46);trim.Material=Enum.Material.Metal;trim.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.35,0)
  for _,side in ipairs({-1,1}) do
   local optic=localPart(clone,'TypeOptic',pivot.Position);optic.Size=Vector3.new(pivot.Size.X*.52,.055,.025);optic.Transparency=0;optic.Color=typeColor;optic.Material=Enum.Material.Neon;optic.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.24,side*(pivot.Size.Z*.5+.015))
  end
 end
 hideModel(source)
 local parts={};for _,p in ipairs(clone:GetDescendants()) do if p:IsA('BasePart') then parts[p]=p.Transparency end end
 local d={source=source,view=clone,pos=pos,yaw=source:GetAttribute('Yaw') or 0,life=source:GetAttribute('Life'),parts=parts,lastState=source:GetAttribute('State'),beam=createBeam(clone,emitter)}
 drones[source]=d
 clone:PivotTo(CFrame.new(pos)*CFrame.Angles(0,d.yaw,0))
 presentation:registerDrone(d,workspace:GetServerTimeNow())
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
 for _,v in ipairs(view:GetDescendants()) do if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Beam') or v:IsA('ParticleEmitter') then v:Destroy() end end
 view.Anchored=true;view.CanCollide=false;view.CanTouch=false;view.CanQuery=false;view.LocalTransparencyModifier=0;view.Parent=localFX;hidePart(source)
 resources[source]={source=source,view=view,id=tostring(id),baseColor=source.Color,visual=Feel.newStagePresentation(source:GetAttribute('Stage') or 0,(source:GetAttribute('BreakSerial') or 0)>0 or (source:GetAttribute('HP') or 1)<=0,workspace:GetServerTimeNow())}
 resourceIndex[tostring(id)]=resources[source]
end
local function registerTurret(source)
 if turrets[source] or not source:IsA('Model') or not (source:GetAttribute('Turret') or source:GetAttribute('TurretId')) then return end
 local t=presentation:registerTurret(source,workspace:GetServerTimeNow())
 if t then turrets[source]=t;hideModel(source) end
end
local observed={}
local function observe(source)
 if not source.Parent then return end
 if source:IsA('BasePart') then
  local ancestor=source.Parent
  while ancestor and ancestor~=world do
   if ancestor:IsA('Model') then
    if ancestor:GetAttribute('DroneId') then registerDrone(ancestor);hidePart(source) end
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
 presentation:destroyDrone(d)
 presentation:destroyMiningBeam(d.beam);d.view:Destroy()
end
connect(world.DescendantRemoving,function(source)
 pendingDroneSources[source]=nil
 if drones[source] then destroyDrone(drones[source]);drones[source]=nil end
 if resources[source] then resourceIndex[resources[source].id]=nil;resources[source].view:Destroy();resources[source]=nil end
 if turrets[source] then presentation:destroyTurret(turrets[source]);turrets[source]=nil end
 if observed[source] then observed[source]:Disconnect();observed[source]=nil end
 hiddenParts[source]=nil
end)
local function resourceById(id) return resourceIndex[tostring(id)] end
local function renderResource(r,now)
 local s=r.source;local view=r.view
 local full=s:GetAttribute('FullSize') or s.Size
 if type(full)=='number' then full=Vector3.one*full end
 local final=s:GetAttribute('FullPosition') or s.Position
 local spawnAt=s:GetAttribute('SpawnAt') or now-2
 local readyAt=s:GetAttribute('ReadyAt') or spawnAt+2
 -- Original TweenInfo default Quad/Out: size and rise share the same two-second envelope.
 local growth=Feel.growth(now,spawnAt)
 if readyAt-spawnAt~=2 then local g=math.clamp((now-spawnAt)/math.max(.01,readyAt-spawnAt),0,1);growth=1-(1-g)^2 end
 local authoritativeStage=math.clamp(s:GetAttribute('Stage') or 0,0,3)
 local health=s:GetAttribute('HP') or 1
 local broken=(s:GetAttribute('BreakSerial') or 0)>0 or health<=0
 local event=Feel.updateStagePresentation(r.visual,authoritativeStage,broken,now)
 local stage=r.visual.stage
 local period=1-stage*.25
 if not r.visual.broken then
  view.Transparency=s:GetAttribute('Kind')=='Geode' and .04 or 0
  view.Size=full*math.max(.005,growth*period)
  local start=s:GetAttribute('StartPosition') or Vector3.new(final.X,final.Y-2-full.Y/2,final.Z)
  local pos=start:Lerp(final,growth)
  local seed=s:GetAttribute('StageSeed') or 0
  local ax=stage==0 and 0 or math.rad(math.sin(seed+stage*3.17)*40)
  local az=stage==0 and 0 or math.rad(math.sin(seed*1.33+stage*5.19)*40)
  view.CFrame=CFrame.new(pos)*CFrame.Angles(ax,seed*.01,az)
  view.Color=r.baseColor:Lerp(Color3.new(.12,.12,.15),stage*.13)
 else view.Transparency=1 end
 if event=='stage' then safeSound('RockCrack',view);presentation:resourceImpact(r,event,now)
 elseif event=='break' then safeSound('RockBreak',view);presentation:resourceImpact(r,event,now) end
end
local function resolveRenderedTarget(kind,id)
 if type(id)~='string' or id=='' then return nil end
 if kind=='resource' then
  local r=resourceById(id)
  if r and r.source.Parent and (r.source:GetAttribute('BreakSerial') or 0)==0
   and r.view.Parent and not r.visual.broken then return r.view,r.source,r end
 elseif kind=='turret' then
  for source,t in pairs(turrets) do
   if source.Parent and source:GetAttribute('TurretId')==id and source:GetAttribute('Dead')~=true
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
 local s=d.source;local state=s:GetAttribute('State') or 'Follow'
 local logical=s:GetAttribute('Position');local goal=s:GetAttribute('Goal') or logical
 if typeof(logical)~='Vector3' or typeof(goal)~='Vector3' then return end
 d.lastState=state
 local life=s:GetAttribute('Life');local maxStep=s:GetAttribute('MaxStep60') or .35
 if life~=d.life then d.life=life;d.pos=logical end
 local motionPaused=s:GetAttribute('MotionPaused')==true
 if state=='Follow' and not motionPaused then
  local owner=Players:GetPlayerByUserId(s:GetAttribute('Owner') or 0)
  local hr=owner and owner.Character and owner.Character:FindFirstChild('HumanoidRootPart')
  local slot=s:GetAttribute('FormationSlot');local count=s:GetAttribute('FleetCount')
  if hr and slot and count then goal=Feel.followGoal(hr.Position,slot,count,now,(s:GetAttribute('PhaseSeed') or maxStep*200)/200) end
 end
 if state=='Destroyed' or state=='Reprinting' then d.pos=logical
 elseif not motionPaused then
  d.pos=Feel.approach(d.pos,goal,maxStep,math.min(dt,.1))
  local error=logical-d.pos
  -- Correct drift gradually, including after a delayed pause packet; never snap.
  if error.Magnitude>5 then d.pos=d.pos+error.Unit*math.min(error.Magnitude-5,maxStep*60*math.min(dt,.1)*.25) end
 end
 if not motionPaused then
  local targetYaw=Feel.levelYaw(d.pos,goal,d.yaw)
  local difference=math.atan2(math.sin(targetYaw-d.yaw),math.cos(targetYaw-d.yaw))
  d.yaw=d.yaw+difference*Feel.turnAlpha(math.min(dt,.1))
 end
 d.view:PivotTo(CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0))
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
 local beam=d.beam
 local kind=state=='Attack' and 'turret' or 'resource'
 local id=s:GetAttribute(kind=='turret' and 'CombatTargetId' or 'TargetId')
 if active and type(id)=='string' and id~='' then beam.lastKey=id;beam.lastKind=kind
 elseif not active and beam.lastKey then id=beam.lastKey;kind=beam.lastKind end
 local part,source,resource=resolveRenderedTarget(kind,id)
 local procKind=state=='Attack' and 'turret' or 'resource'
 local procId=s:GetAttribute(procKind=='turret' and 'ChainTargetId' or 'ForkTargetId')
 local procUntil=s:GetAttribute(procKind=='turret' and 'ChainUntil' or 'ForkUntil') or 0
 local extra,extraSource
 if active and now<procUntil then extra,extraSource=resolveRenderedTarget(procKind,procId) end
 presentation:queueMiningBeam(beam,{alive=alive,active=active,key=id,life=life,
  contact=active,
  since=state=='Attack' and (s:GetAttribute('ShotAt') or now) or (s:GetAttribute('BeamSince') or now),
  part=part,serverSource=source,resource=resource,secondaryPart=extra,secondarySource=extraSource,
  secondaryKey=procId,secondaryColor=state=='Attack' and Color3.fromRGB(255,179,102) or nil},now)

end
connect(RunService.RenderStepped,function(dt)
 local now=workspace:GetServerTimeNow()
 presentation:beginFrame()
 for _,r in pairs(resources) do renderResource(r,now) end
 -- Resolve the current animated eye before drawing any attack beams.
 for _,t in pairs(turrets) do presentation:renderTurret(t,dt,now) end
 for _,d in pairs(drones) do renderDrone(d,dt,now) end
 presentation:flushMiningBeams()
 presentation:update(dt,now)
end)

local evade=button(safeRoot,UDim2.new(1,-136,1,-108),UDim2.fromOffset(118,38),'Evade  [Q]',function() command:FireServer('Evade') end,palette.accent);evade.Visible=false
local enemyHUD=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(300,58),palette.panel,12);enemyHUD.Name='SentryHealth';enemyHUD.Visible=false
local enemyTitle=label(enemyHUD,UDim2.fromOffset(12,6),UDim2.new(1,-24,0,19),'PYRAMID SENTRY',16,nil,true)
local enemyHealth=frame(enemyHUD,UDim2.fromOffset(12,33),UDim2.new(1,-24,0,4),palette.line);corner(enemyHealth,2)
local enemyFill=frame(enemyHealth,UDim2.fromScale(0,0),UDim2.fromScale(1,1),colors.Red);corner(enemyFill,2)
local function ownerRoot() return player.Character and player.Character:FindFirstChild('HumanoidRootPart') end
local function nearbyInteraction()
 local hr=ownerRoot();if not hr then return nil end
 local nearest,best=nil,14
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') and (converter.Position-hr.Position).Magnitude<best then nearest=converter;best=(converter.Position-hr.Position).Magnitude end
 local map=world:FindFirstChild('Map')
 if map then
  for _,name in ipairs({'PackStation','PrestigeStation'}) do
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
 if kind=='Pack' then return openPack,'Upgrade your fleet',pending() and 'Your three saved cards are waiting' or ('3 cards. Keep 1.  /  '..comma(profile and profile.nextPackPrice or 80)..' credits'),pending() and 'Choose' or 'Pack'
 elseif kind=='Prestige' then return openPrestige,'Grow your fleet','Review the milestone and your next permanent drone','Review'
 elseif kind=='Sell' then return function() command:FireServer('Sell') end,'Mineral converter',profile and (comma(cargoUnits(profile))..' ore on board  /  sell for credits') or 'Bring minerals home to sell','Sell'
 end
 return nil
end
local selectedDrone,selectedResource,assignmentPending=nil,nil,nil
local cancelRequest=nil
local fieldPending=nil
local cancelDesired=false
local marker
local lastStationUse=0
local function performStation(station)
 local action=stationAction(station)
 if modal.Visible or selectedDrone then return end
 if action and os.clock()-lastStationUse>.25 then lastStationUse=os.clock();action() end
end
connect(game:GetService('ProximityPromptService').PromptTriggered,function(prompt,who)
 if (not who or who==player) and prompt.Parent and prompt.Parent:IsA('BasePart') then performStation(prompt.Parent) end
end)
local assignmentAcknowledgedUntil=0
local selectionDock=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(296,72),palette.panel,10);selectionDock.Name='SelectMiningTarget';selectionDock.Visible=false
local selectionTitle=label(selectionDock,UDim2.fromOffset(8,3),UDim2.new(1,-16,0,22),'Select a crystal',16,palette.ink,true)
local cycleCandidate,submitCandidate
local nextTarget=button(selectionDock,UDim2.fromOffset(5,26),UDim2.new(.33,-7,0,44),'Next [T]',function() cycleCandidate() end,palette.paper);nextTarget.TextSize=16
local assignTarget=button(selectionDock,UDim2.new(.33,0,0,26),UDim2.new(.34,-5,0,44),'Assign',function() submitCandidate() end,palette.mineral);assignTarget.TextSize=16
local function clearSelectionVisuals()
 if marker then marker.Enabled=false;marker.Adornee=nil end
 selectedResource=nil
end
local function cancelSelection()
 clearSelectionVisuals()
 if assignmentPending and selectedDrone and profile then
  cancelDesired=true
  if cancelRequest then return end
  for source in pairs(drones) do if source:GetAttribute('Owner')==player.UserId and source:GetAttribute('DroneId')==selectedDrone.id then
   local id=tx();cancelRequest=id;selectionTitle.Text='Cancelling…';notice.Text='Cancelling drone assignment…';noticeUntil=os.clock()+5
   command:FireServer('CancelDrone',{requestId=id,runId=profile.run.id,droneId=selectedDrone.id,life=source:GetAttribute('Life')})
   task.delay(8,function() if cancelRequest==id then cancelRequest=nil;selectionTitle.Text='Cancel unconfirmed • retry';notice.Text='Cancel unconfirmed • retry';noticeUntil=os.clock()+5 end end)
   return
  end end
  selectionTitle.Text='Drone unavailable • try cancel again';notice.Text=selectionTitle.Text;noticeUntil=os.clock()+5;return
 end
 notice.Text='Selection cancelled';noticeUntil=os.clock()+3
 assignmentPending=nil;cancelRequest=nil;cancelDesired=false;selectedDrone=nil;assignmentAcknowledgedUntil=0;selectionDock.Visible=false
end
local cancelTarget=button(selectionDock,UDim2.new(.67,0,0,26),UDim2.new(.33,-5,0,44),'Cancel',cancelSelection,palette.paper);cancelTarget.TextSize=16
marker=Instance.new('Highlight');marker.Name='SelectedCrystal';marker.FillTransparency=.8;marker.OutlineColor=palette.mineral;marker.DepthMode=Enum.HighlightDepthMode.Occluded;marker.Enabled=false;marker.Parent=localFX
local function updateSelectedResource(source)
 selectedResource=source;local r=source and resources[source];marker.Adornee=r and r.view or nil;marker.Enabled=r~=nil
 local count=source and math.max(0,(source:GetAttribute('SlotCapacity') or 1)-(source:GetAttribute('SlotsUsed') or 0)) or 0
 selectionTitle.Text=selectedDrone and ((selectedDrone.name or 'Drone')..' • '..(source and (tostring(count)..' open slots') or 'select a crystal')) or ''
end
beginDroneSelection=function(d)
 if fieldPending then notice.Text='Wait for fleet confirmation or recall';noticeUntil=os.clock()+5;return end
 if assignmentPending then notice.Text='Cancel the current assignment first';noticeUntil=os.clock()+5;return end
 selectedDrone=d;assignmentPending=nil;cancelRequest=nil;cancelDesired=false;assignmentAcknowledgedUntil=0;nextTarget.Visible=true;assignTarget.Visible=true;cancelTarget.Visible=true;updateSelectedResource(nil);modal.Visible=false;selectionDock.Visible=true
end
cycleCandidate=function()
 if assignmentPending or cancelDesired then return end
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart');local options={};local now=workspace:GetServerTimeNow()
 for source in pairs(resources) do if source.Parent and (source:GetAttribute('HP') or 0)>0 and (source:GetAttribute('ReadyAt') or math.huge)<=now and (source:GetAttribute('SlotsUsed') or 0)<(source:GetAttribute('SlotCapacity') or 1) and hr and (source.Position-hr.Position).Magnitude<=90 then table.insert(options,source) end end
 table.sort(options,function(a,b) return tostring(a:GetAttribute('ResourceId'))<tostring(b:GetAttribute('ResourceId')) end)
 if #options==0 then updateSelectedResource(nil);selectionTitle.Text='No ready slots nearby';return end
 local n=1;for i,v in ipairs(options) do if v==selectedResource then n=i%#options+1;break end end;updateSelectedResource(options[n])
end
submitCandidate=function()
 if not selectedDrone or not selectedResource or not profile or assignmentPending or cancelDesired then return end
 local source=nil;for d in pairs(drones) do if d:GetAttribute('Owner')==player.UserId and d:GetAttribute('DroneId')==selectedDrone.id then source=d;break end end
 if not source then selectionTitle.Text='Drone unavailable';return end
 local id=tx();assignmentPending=id;selectionTitle.Text='Assigning…'
 command:FireServer('AssignSlot',{requestId=id,runId=profile.run.id,fieldId=selectedResource:GetAttribute('FieldId'),droneId=selectedDrone.id,life=source:GetAttribute('Life'),resourceId=tostring(selectedResource:GetAttribute('ResourceId'))})
 task.delay(8,function() if assignmentPending==id and not cancelRequest then selectionTitle.Text='Unconfirmed • cancel to retry' end end)
end
local function fieldName(id)
 local folder=world:FindFirstChild('Fields')
 if folder then for _,field in ipairs(folder:GetChildren()) do
  if field:GetAttribute('FieldId')==id then return tostring(field:GetAttribute('DisplayName') or field.Name) end
 end end
 return 'Field '..tostring(id)
end
connect(gui.Parent:GetAttributeChangedSignal('MA_CommandState'),function()
 local raw=gui.Parent:GetAttribute('MA_CommandState');if type(raw)~='string' then return end
 local ok,result=pcall(function() return Http:JSONDecode(raw) end);if not ok then return end
 local fieldStatus,fieldMessage=UILayout.fieldReceipt(fieldPending and fieldPending.id,result,fieldPending and fieldPending.fieldId)
 if fieldStatus then
  local dest=fieldPending.fieldId and fieldName(fieldPending.fieldId);fieldPending=nil
  notice.Text=dest and (dest..' • '..fieldMessage) or fieldMessage;noticeUntil=os.clock()+5;return
 end
 if cancelRequest and result.requestId==cancelRequest then
  cancelRequest=nil
  if result.status=='accepted' then
   assignmentPending=nil;cancelDesired=false;selectedDrone=nil;clearSelectionVisuals();selectionTitle.Text='Drone recalled'
   assignmentAcknowledgedUntil=os.clock()+3;nextTarget.Visible=false;assignTarget.Visible=false;cancelTarget.Visible=false
  else selectionTitle.Text=tostring(result.reason or 'Cancel rejected')..' • retry cancel' end
  notice.Text=selectionTitle.Text;noticeUntil=os.clock()+5;return
 end
 local status,message=UILayout.assignmentReceipt(assignmentPending,result,selectedDrone and selectedDrone.name,cancelDesired)
 if not status then return end
 if cancelDesired then return end -- ignore an earlier assignment receipt until cancellation is confirmed
 assignmentPending=nil;selectionTitle.Text=message
 if status=='accepted' then
  selectedDrone=nil;clearSelectionVisuals()
  assignmentAcknowledgedUntil=os.clock()+3
  nextTarget.Visible=false;assignTarget.Visible=false;cancelTarget.Visible=false
 else assignmentAcknowledgedUntil=0 end
 notice.Text=message;noticeUntil=os.clock()+5
end)
connect(modal:GetPropertyChangedSignal('Visible'),function()
 if modal.Visible and selectedDrone then cancelSelection() end
end)
connect(player.CharacterRemoving,function()
 if selectedDrone then cancelSelection() end
 clearSelectionVisuals()
end)
local function watchSelectionDeath(character)
 local hum=character:FindFirstChildOfClass('Humanoid') or character:WaitForChild('Humanoid',10)
 if hum then connect(hum.Died,function() if selectedDrone then cancelSelection() end;clearSelectionVisuals() end) end
end
connect(player.CharacterAdded,watchSelectionDeath)
if player.Character then task.spawn(watchSelectionDeath,player.Character) end
local function queueFieldTimeout(request)
 task.delay(8,function()
  if fieldPending==request then request.timedOut=true;notice.Text='Unconfirmed • retry field or Recall';noticeUntil=os.clock()+5 end
 end)
end
local function requestField(fieldId)
 if selectedDrone or modal.Visible or type(fieldId)~='number' then return end
 if fieldPending then
  if fieldPending.timedOut and fieldPending.fieldId==fieldId then
   local retry={id=tx(),fieldId=fieldId};fieldPending=retry;notice.Text='Retrying '..fieldName(fieldId)..'…';noticeUntil=os.clock()+8
   command:FireServer('Patch',{fieldId=fieldId,requestId=retry.id});queueFieldTimeout(retry)
  else notice.Text='Wait for fleet confirmation or Recall';noticeUntil=os.clock()+5 end
  return
 end
 local request={id=tx(),fieldId=fieldId};fieldPending=request;notice.Text='Assigning '..fieldName(fieldId)..'…';noticeUntil=os.clock()+8
 command:FireServer('Patch',{fieldId=fieldId,requestId=request.id});queueFieldTimeout(request)
end
requestRecall=function()
 assignmentPending=nil;cancelRequest=nil;cancelDesired=false;selectedDrone=nil;clearSelectionVisuals();selectionDock.Visible=false
 -- Ordered Recall is an explicit server action, not a local assumption that a
 -- timed-out field request was cancelled. Track its separate acknowledgement.
 local request={id=tx(),recall=true};fieldPending=request;notice.Text='Recalling fleet…';noticeUntil=os.clock()+8
 command:FireServer('Recall',{requestId=request.id});queueFieldTimeout(request)
end
local function assignField(target)
 if modal.Visible then return end
 local node=target
 if selectedDrone then
  if assignmentPending or cancelDesired then return end
  while node and node~=workspace do if node:GetAttribute('ResourceId') and resources[node] then updateSelectedResource(node);submitCandidate();return end;node=node.Parent end
  selectionTitle.Text='Tap a crystal, or use Next';return
 end
 node=target
 while node and node~=workspace do
  local field=node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier')
  if type(field)=='number' then requestField(field);return end
  local owner=node:GetAttribute('Owner')
  if owner==player.UserId and node:GetAttribute('DroneId') then openFleet();return end
  node=node.Parent
 end
end
local mouse=player:GetMouse()
connect(UIS.TouchTapInWorld,function(position,processed)
 if processed or modal.Visible then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local ray=camera:ScreenPointToRay(position.X,position.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={localFX,player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 if hit then assignField(hit.Instance) end
end)
connect(UIS.InputBegan,function(input,processed)
 if input.KeyCode==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false;return end
 if processed or UIS:GetFocusedTextBox() then return end
 if selectedDrone and not modal.Visible then
  if input.KeyCode==Enum.KeyCode.T then cycleCandidate();return elseif input.KeyCode==Enum.KeyCode.Return then submitCandidate();return elseif input.KeyCode==Enum.KeyCode.Escape then cancelSelection();return end
  -- Suppress E, field hotkeys and other hidden context actions during targeting.
  if cancelDesired or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
 end
 if modal.Visible then
  if modalMode=='offer' then
   local shortcuts={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3}
   local index=shortcuts[input.KeyCode]
   if index and offerActions[index] then offerActions[index]() elseif (input.KeyCode==Enum.KeyCode.Return or input.KeyCode==Enum.KeyCode.KeypadEnter) and offerConfirmAction then offerConfirmAction() end
  end
  return
 end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then assignField(mouse.Target);return end
 local key=input.KeyCode
 if key==Enum.KeyCode.R then requestRecall()
 elseif key==Enum.KeyCode.Q then command:FireServer('Evade')
 elseif key==Enum.KeyCode.E and not modal.Visible then if contextAction then contextAction() end
 elseif not modal.Visible then
  local fields={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5}
  if fields[key] then requestField(fields[key]) end
 end
end)
local hudClock=0
local contextKind='mining'
connect(RunService.Heartbeat,function(dt)
 hudClock=hudClock+dt;if hudClock<.2 then return end;hudClock=0
 if selectedResource and (not selectedResource.Parent or not resources[selectedResource]) then clearSelectionVisuals() end
 if selectedDrone then
  for source in pairs(drones) do
   if source:GetAttribute('Owner')==player.UserId and source:GetAttribute('DroneId')==selectedDrone.id then
    local state=source:GetAttribute('State')
    if state=='Destroyed' or state=='Reprinting' or (source:GetAttribute('HP') or 1)<=0 then
     assignmentPending=nil;cancelRequest=nil;cancelDesired=false;selectedDrone=nil;clearSelectionVisuals();selectionDock.Visible=false
     notice.Text='Drone unavailable';noticeUntil=os.clock()+5
    end
    break
   end
  end
 end
 local view=viewport();local l=currentLayout();local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 hud.Position=UDim2.fromOffset(l.hudX,l.hudY);hud.Size=UDim2.fromOffset(l.hudWidth,l.hudHeight)
 creditsLabel.Size=UDim2.fromOffset(l.hudWidth-190,32);saveLabel.Size=UDim2.fromOffset(l.hudWidth-145,18)
 creditsLabel.TextSize=l.hudWidth<330 and 24 or 28
 cargoText.Size=UDim2.fromOffset(l.hudWidth-145,20);cargoText.Position=UDim2.fromOffset(15,l.short and 47 or 53)
 cargoTrack.Position=UDim2.fromOffset(14,l.short and 67 or 76)
 fleetButton.Size=UDim2.fromOffset(52,l.hudHeight-18);runButton.Size=fleetButton.Size
 objectiveBox.Size=UDim2.fromOffset(l.objectiveWidth,l.objectiveHeight)
 objectiveBox.Position=UDim2.fromOffset(l.hudX,l.objectiveY)
 objectiveBox.Visible=not modal.Visible and not l.short
 context.Size=UDim2.fromOffset(l.contextWidth,l.contextHeight);context.Position=UDim2.fromOffset(l.contextX,l.contextY)
 selectionDock.Size=UDim2.fromOffset(l.contextWidth,72);selectionDock.Position=UDim2.fromOffset(l.contextX,l.contextY+l.contextHeight-72);selectionDock.Visible=(selectedDrone~=nil or os.clock()<assignmentAcknowledgedUntil) and not modal.Visible
 if not selectedDrone then marker.Enabled=false;marker.Adornee=nil end
 contextButton.Position=UDim2.new(1,-112,0,(l.contextHeight-44)/2)
 contextTitle.TextSize=18
 contextDetail.TextSize=16
 contextIcon.Position=UDim2.fromOffset(12,(l.contextHeight-34)/2)
 recall.Position=UDim2.fromOffset(l.recallX,l.recallY);evade.Position=UDim2.fromOffset(l.evadeX,l.evadeY)
 recall.Size=UDim2.fromOffset(l.recallWidth,44);evade.Size=recall.Size
 recall.Text=touch and 'Recall' or 'Recall [R]';recall.Visible=not modal.Visible
 if modal.Visible and (not modalSize or (modalSize-view).Magnitude>1) then refreshModal() end
 if modal.Visible and (modalMode=='offer' or modalMode=='pack' or modalMode=='prestige') then
  local action=modalMode=='offer' and 'ChooseCard' or modalMode=='pack' and 'BuyPack' or 'Prestige'
  local allowed,reason=availability(action);local signature=modalMode..':'..tostring(allowed)..':'..reason
  if signature~=availabilitySignature then availabilitySignature=signature;refreshModal() end
 end
 if actionPending and os.clock()-actionPending.at>10 and not (profile and profile.pendingTransaction) and not (pendingClaim and (pendingClaim.uncertain or pendingClaim.accepted)) then
  actionPending=nil;notice.Text=pendingClaim and 'No confirmation. Retry the same card.' or 'Still waiting for confirmation. You can retry.';noticeUntil=os.clock()+5;refreshModal()
 end
 if os.clock()>noticeUntil then notice.Text='' end
 local status=tostring(player:GetAttribute('MA_SaveStatus') or 'Loading'):lower()
 if status:find('preview') then saveLabel.Text='NOT SAVED'
 elseif status:find('loading') then saveLabel.Text='LOADING'
 elseif status:find('unavailable') then saveLabel.Text='LOAD FAILED'
 elseif status:find('saved') then saveLabel.Text='SAVED'
 else saveLabel.Text='SAVE PAUSED' end
 saveLabel.TextSize=16
 saveLabel.TextColor3=status:find('preview') and Color3.fromRGB(137,91,37) or palette.muted
 if profile and profile.run then
  local amount=cargoUnits(profile);local capacity=profile.capacity or 120
  local credits=profile.run.credits or 0;local creditText=comma(credits)
  if credits>=1e9 then creditText=string.format('%.1fB',credits/1e9) elseif credits>=1e6 then creditText=string.format('%.1fM',credits/1e6) elseif credits>=10000 then creditText=string.format('%.1fk',credits/1000) end
  creditsLabel.Text=creditText
  fleetCount.Text=tostring(#(profile.fleet or {}));runCount.Text=pending() and 'Pick' or tostring(#profile.run.cards)
  local cargoDisplay=string.format('Cargo %s/%s',comma(amount),comma(capacity))
  local fitOK,fitBounds=pcall(function() return TextService:GetTextSize(cargoDisplay,16,Enum.Font.FredokaOne,Vector2.new(10000,20)) end)
  if fitOK and fitBounds.X>l.hudWidth-145 then cargoDisplay=string.format('%s/%s',comma(amount),comma(capacity)) end
  cargoText.Text=cargoDisplay
  cargoFill.Size=UDim2.fromScale(math.clamp(amount/math.max(1,capacity),0,1),1)
  cargoFill.BackgroundColor3=amount>=capacity and palette.accent or palette.mineral
  local pre=profile.prestigePreview;local price=profile.nextPackPrice or 80
  if pending() then objective.Text='Your paid pack is waiting.\nChoose your card at the depot.'
  elseif amount>=capacity then objective.Text='Cargo full! Recall your fleet,\nthen sell at the Converter.'
  elseif pre and pre.eligible then objective.Text='Your next permanent drone is ready!\nVisit the fleet uplink to prestige.'
  elseif credits>=price then objective.Text='Upgrade ready · '..comma(price)..' credits.\nOpen your next pack at the depot.'
  elseif (profile.run.packIndex or 0)==0 then objective.Text='Send your drone to a mineral field.\nMine → sell → choose your first upgrade.'
  elseif pre and (pre.earnings or 0)>=(pre.saleRequired or 2000) and (pre.wins or 0)<(pre.winsRequired or 1) then objective.Text=string.format('Defeat %s to grow your crew.\nSentry clears: %d / %d.',pre.field or 'Cobalt',pre.wins or 0,pre.winsRequired or 1)
  elseif pre then objective.Text=string.format('Next drone: %s / %s credits sold.\n%s clears: %d / %d.',comma(pre.earnings or 0),comma(pre.saleRequired or 2000),pre.field or 'Cobalt',pre.wins or 0,pre.winsRequired or 1)
  else objective.Text='Mine, sell and build a stronger crew.\nSentries guard the richest minerals.' end
 end
 -- Objectives may wrap to three lines at 320px. Measure the real copy at the
 -- available width, keeping the next action separate rather than clipping.
 local objectiveTextHeight=wrappedHeight(objective.Text,l.objectiveWidth-52,16,false,32)
 local objectiveHeight=UILayout.objectiveHeightFor(objectiveTextHeight)
 if not l.short then objectiveBox.Size=UDim2.fromOffset(l.objectiveWidth,objectiveHeight) end
 local ownActive=false;local reprints={};local now=workspace:GetServerTimeNow()
 for source in pairs(drones) do
  if source:GetAttribute('Owner')==player.UserId then
   local state=source:GetAttribute('State');if state=='Attack' then ownActive=true end
   local at=source:GetAttribute('ReprintAt') or 0
   if at>now then table.insert(reprints,string.format('%s reprinting: %ds',source:GetAttribute('DroneName') or source:GetAttribute('Name') or 'Drone',math.ceil(at-now))) end
  end
 end
 evade.Visible=ownActive and not modal.Visible;evade.Text=touch and 'Evade shot' or 'Evade [Q]'
 hud.Visible=not modal.Visible and not (l.short and ownActive)
 if not ownActive and (l.mobile or touch) and not l.actionAtTop then recall.Position=UDim2.fromOffset((view.X-l.recallWidth)/2,l.recallY) end
 if ownActive then objectiveBox.Visible=false end
 if #reprints>0 and os.clock()>noticeUntil then notice.Text=#reprints>2 and tostring(#reprints)..' drones reprinting for free' or table.concat(reprints,' · ') end
 local station=nearbyInteraction();contextAction=nil;context.Visible=false
 local desiredContext=station and ({Pack='cards',Prestige='prestige',Sell='cargo'})[station:GetAttribute('Interaction')] or 'mining'
 if desiredContext~=contextKind then contextKind=desiredContext;contextIcon:Destroy();contextIcon=U.icon(context,contextKind,UDim2.fromOffset(12,(l.contextHeight-34)/2),UDim2.fromOffset(34,34),palette.mineral) end
 if station and not modal.Visible then
  local action,title,detail,actionText=stationAction(station)
  if l.contextWidth<350 then
   local kind=station:GetAttribute('Interaction')
   if kind=='Pack' then title='Upgrade pack';detail=pending() and 'Your saved cards are ready' or '3 cards · choose 1'
   elseif kind=='Prestige' then title='Grow your fleet';detail='Keep fleet · gain one drone'
   elseif kind=='Sell' then title='Sell minerals';detail=profile and (comma(cargoUnits(profile))..' ore · convert to credits') or 'Bring your minerals home' end
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
    contextAction=function() requestField(id) end;contextTitle.Text=nearest:GetAttribute('DisplayName') or nearest.Name
    local phase=nearest:GetAttribute('Phase') or 'Safe'
    local actionText=(phase=='Guarded' or phase=='Active') and 'Fight' or (phase=='Gathering' and 'Join' or 'Mine')
    contextDetail.Text=(phase=='Active' and 'Starting crew only') or (phase=='Guarded' and 'Sentries block mining') or (phase=='Gathering' and 'Join before the fight starts') or 'Gather minerals with your fleet'
    contextButton.Text=actionText..(touch and '' or ' [E]');context.Visible=true
   end
  end
 end
 -- Reflow using the actual current title and text width, without shrinking the
 -- font or placing text beneath the 44px action. In very short landscape a
 -- long title takes priority over detail instead of clipping both.
 local textWidth=l.contextWidth-(l.contextWidth>=380 and 55 or 12)-120
 local titleHeight=math.max(22,wrappedHeight(contextTitle.Text,textWidth,18,true,22)-8)
 local c=UILayout.contextText(l.contextWidth,l.contextHeight,titleHeight)
 contextIcon.Visible=c.showIcon
 contextTitle.Position=UDim2.fromOffset(c.textX,c.titleY);contextTitle.Size=UDim2.fromOffset(c.textWidth,c.titleHeight)
 contextDetail.Position=UDim2.fromOffset(c.textX,c.detailY);contextDetail.Size=UDim2.fromOffset(c.textWidth,c.detailHeight);contextDetail.Visible=c.showDetail
 if selectedDrone or os.clock()<assignmentAcknowledgedUntil then context.Visible=false end
 if l.contextReplacesHUD and (context.Visible or selectionDock.Visible) then hud.Visible=false end
 local hr=ownerRoot();local nearestEnemy,dist=nil,65
 if hr then for turret in pairs(turrets) do if turret.Parent then
  local hp=turret:GetAttribute('HP') or 0;local rootPart=turret.PrimaryPart or turret:FindFirstChildWhichIsA('BasePart',true)
  local n=rootPart and (rootPart.Position-hr.Position).Magnitude or math.huge
  if hp>0 and n<dist then nearestEnemy=turret;dist=n end
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
  enemyTitle.TextColor3=charging and Color3.fromRGB(160,78,35) or palette.ink
 end
 local toastWidth=math.min(420,view.X-24)
 if l.short then toastWidth=l.hudWidth end
 toast.Size=UDim2.fromOffset(toastWidth,50)
 toast.Position=UDim2.fromOffset((view.X-toastWidth)/2,view.X>=1100 and 12 or (l.objectiveY+(enemyHUD.Visible and 66 or 0)))
 notice.TextSize=16
 toast.Visible=notice.Text~='' and (not modal.Visible or modalMode=='offer') and not (l.short and ownActive and not modal.Visible)
 if l.short then toast.Position=UDim2.fromOffset(l.hudX,l.hudY);if toast.Visible then hud.Visible=false end end
 if toast.Visible and view.X<1100 then objectiveBox.Visible=false end
 local previousSubtitle=modalSubtitle.Text
 if modal.Visible and notice.Text~='' and noticeUntil>os.clock() then
  modalSubtitle.Text=notice.Text;modalSubtitle.TextColor3=palette.ink
 else modalSubtitle.Text=normalSubtitle;modalSubtitle.TextColor3=palette.muted end
 if modal.Visible and modalMode~='offer' and modalSubtitle.Text~=previousSubtitle then layoutModal() end
end)
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),refreshModal)
connect(gui.Destroying,function()
 presentation:destroy()
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,c in pairs(observed) do c:Disconnect() end
 for part in pairs(hiddenParts) do if part.Parent then part.LocalTransparencyModifier=0 end end
 localFX:Destroy()
end)
