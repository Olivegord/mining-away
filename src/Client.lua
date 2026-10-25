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
local presentation=Presentation.new({parent=localFX})
local foliage=Foliage.new(world,localFX)
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
local hud=U.panel(safeRoot,UDim2.fromOffset(16,12),UDim2.fromOffset(360,88));hud.Name='Resources';hud.Active=true
U.icon(hud,'coin',UDim2.fromOffset(10,9),UDim2.fromOffset(40,40),palette.accent)
local creditsLabel=label(hud,UDim2.fromOffset(58,4),UDim2.new(1,-190,0,32),'0',28,palette.ink,true);creditsLabel.Name='Credits'
local saveLabel=label(hud,UDim2.fromOffset(58,35),UDim2.new(1,-190,0,13),'CONNECTING',9.5,palette.muted);saveLabel.Name='SaveStatus'
local cargoText=label(hud,UDim2.fromOffset(15,53),UDim2.new(1,-158,0,18),'CARGO  0 / 120',12,palette.ink,true)
local cargoTrack=frame(hud,UDim2.fromOffset(14,76),UDim2.new(1,-158,0,6),palette.paper);corner(cargoTrack,3)
local cargoFill=frame(cargoTrack,UDim2.fromScale(0,0),UDim2.fromScale(0,1),palette.mineral);corner(cargoFill,3)
local fleetButton=button(hud,UDim2.new(1,-130,0,10),UDim2.fromOffset(52,64),'',function() if openFleet then openFleet() end end,palette.mineral:Lerp(palette.white,.48));fleetButton.Name='OpenFleet'
U.icon(fleetButton,'drone',UDim2.fromOffset(11,3),UDim2.fromOffset(30,30),colors.Blue)
local fleetCount=label(fleetButton,UDim2.fromOffset(0,34),UDim2.new(1,0,0,23),'Fleet 1',11,palette.ink,true);fleetCount.TextXAlignment=Enum.TextXAlignment.Center
local runButton=button(hud,UDim2.new(1,-68,0,10),UDim2.fromOffset(52,64),'',function() if profile and profile.run.pendingOffer then openOffer() else openRunCards() end end,palette.accent:Lerp(palette.white,.45));runButton.Name='OpenRunCards'
U.icon(runButton,'cards',UDim2.fromOffset(11,3),UDim2.fromOffset(30,30),palette.accent)
local runCount=label(runButton,UDim2.fromOffset(0,34),UDim2.new(1,0,0,23),'Cards 0',11,palette.ink,true);runCount.TextXAlignment=Enum.TextXAlignment.Center
local objectiveBox=U.panel(safeRoot,UDim2.fromOffset(16,108),UDim2.fromOffset(360,48),palette.panel,10);objectiveBox.Name='NextStep'
U.icon(objectiveBox,'crystal',UDim2.fromOffset(9,9),UDim2.fromOffset(27,27),palette.mineral)
local objective=label(objectiveBox,UDim2.fromOffset(43,5),UDim2.new(1,-52,1,-10),'Mine a field, then sell your cargo.',12,palette.ink)
local toast=U.panel(safeRoot,UDim2.fromOffset(0,170),UDim2.fromOffset(420,50),palette.panel,12);toast.Name='Feedback';toast.ZIndex=80;toast.Visible=false
local notice=label(toast,UDim2.fromOffset(14,6),UDim2.new(1,-28,1,-12),'',13,palette.ink,true);notice.TextXAlignment=Enum.TextXAlignment.Center
local recall=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(118,44),'Recall [R]',function() command:FireServer('Recall') end,palette.panel);recall.Name='Recall'
local context=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(420,72),palette.panel,14);context.Name='ContextAction';context.Active=true;context.Visible=false
local contextIcon=U.icon(context,'mining',UDim2.fromOffset(12,17),UDim2.fromOffset(34,34),palette.mineral)
local contextTitle=label(context,UDim2.fromOffset(55,6),UDim2.new(1,-174,0,30),'',18,palette.ink,true)
local contextDetail=label(context,UDim2.fromOffset(55,35),UDim2.new(1,-174,0,27),'',11,palette.muted)
local contextAction=nil
local contextButton=button(context,UDim2.new(1,-112,0,14),UDim2.fromOffset(100,44),'Use [E]',function() if contextAction then contextAction() end end)
contextButton.Name='UseContext'
local modal=frame(safeRoot,UDim2.fromScale(0,0),UDim2.fromScale(1,1),palette.ink);modal.Name='MenuLayer';modal.BackgroundTransparency=.22;modal.Visible=false;modal.ZIndex=20;modal.Active=true
local sheet=U.panel(modal,UDim2.fromOffset(12,12),UDim2.fromOffset(1010,664),palette.panel,20);sheet.Name='MenuSheet';sheet.ZIndex=21
local sheetScale=Instance.new('UIScale');sheetScale.Parent=sheet
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
 actionPending={kind=action,at=os.clock(),runId=profile.run.id,packIndex=profile.run.packIndex,offerId=profile.run.pendingOffer and profile.run.pendingOffer.id}
 command:FireServer(action,data);return true
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
 local v=viewport();local l=currentLayout()
 sheet.Size=UDim2.fromOffset(l.panelWidth,l.panelHeight);sheet.Position=UDim2.fromOffset(l.panelX,l.panelY);modalSize=v
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
 if l.panelWidth<400 then
  local shortTitles={pack='Upgrade pack',offer='Pick a card',fleet='Your crew',run='Run upgrades',prestige='Grow your fleet'}
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
 label(parent,UDim2.fromOffset(0,y),UDim2.fromOffset(width,22),title,17,palette.ink,true)
 label(parent,UDim2.fromOffset(0,y+27),UDim2.fromOffset(width,27),detail,12,palette.muted)
 local track=frame(parent,UDim2.fromOffset(0,y+62),UDim2.fromOffset(width,10),palette.paper);corner(track,5)
 local fill=frame(track,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(fraction,0,1),1),color);corner(fill,5)
end
openOffer=function()
 local offer=pending();if not offer then return end
 local l=menu('offer','Pick your upgrade','Pack '..offer.packIndex..' · Choose one. These paid choices stay saved when you close.','cards')
 local list=Instance.new('UIListLayout');list.FillDirection=l.cardColumns==3 and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical;list.Padding=UDim.new(0,l.cardGap);list.HorizontalAlignment=Enum.HorizontalAlignment.Center;list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 for index,choice in ipairs(offer.choices) do
  local view
  view=CardView.create(U,body,choice,index,l.cardColumns==3 and l.cardWidth-4 or math.min(460,l.cardWidth-6),l.cardHeight,{category=categoryText(choice),target=targetText(choice),previewRows=previewRows(choice),stackText=stackText(choice),onChoose=function()
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
 local price=profile.nextPackPrice or 80;local credits=profile.run.credits or 0;local affordable=credits>=price
 local priceText=comma(price)
 local heroTextX=narrow and 94 or 125
 label(hero,UDim2.fromOffset(heroTextX,17),UDim2.new(1,narrow and -heroTextX-16 or -145,0,25),'UPGRADE PACK '..tostring(profile.run.packIndex+1),13,palette.muted,true)
 local priceSize=narrow and (#priceText>12 and 14 or (#priceText>8 and 18 or 23)) or 35
 label(hero,UDim2.fromOffset(heroTextX,47),UDim2.new(1,narrow and -heroTextX-16 or -145,0,narrow and 62 or 45),priceText..(narrow and '\ncredits' or ' credits'),priceSize,palette.ink,true)
 label(hero,UDim2.fromOffset(22,126),UDim2.new(1,-44,0,39),narrow and 'Three saved choices. Pick one upgrade for this run.' or 'Mining power, combat tricks or a smarter cargo run. All three choices are saved before you pick.',12,palette.ink)
 progress(body,207,width,'Your pack fund',comma(credits)..' / '..comma(price)..' credits',credits/math.max(1,price),palette.accent)
 local allowed,blocked=availability('BuyPack')
 local text=not allowed and blocked or (affordable and 'Open pack · '..comma(price)..' credits' or 'Sell '..comma(price-credits)..' more credits of ore')
 local buy
 buy=button(body,UDim2.fromOffset(3,302),UDim2.fromOffset(width,50),text,function()
  if canAct('BuyPack') and affordable and send('BuyPack',{packIndex=profile.run.packIndex}) then buy.Text='Opening…';enableAction(buy,false) end
 end,palette.accent);buy.Name='BuyPack';enableAction(buy,canAct('BuyPack') and affordable)
 label(body,UDim2.fromOffset(8,374),UDim2.fromOffset(width-10,50),'Cards reset at prestige. Your permanent drones stay yours.',12,palette.muted)
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
 local l=menu('fleet','Meet your crew','Your drones stay with you. Run upgrades change the stats below.','drone');local width=l.bodyWidth-6
 tabs(width,'fleet')
 local columns=width>=650 and 2 or 1;local gap=14;local rowWidth=(width-gap*(columns-1))/columns
 for index,d in ipairs(profile.fleet or {}) do
  local stats=(profile.droneStats and profile.droneStats[d.id]) or d.effective or d.base or {}
  local x=((index-1)%columns)*(rowWidth+gap)+3;local y=64+math.floor((index-1)/columns)*254
  local tint=colors[d.type] or palette.mineral
  local row=U.panel(body,UDim2.fromOffset(x,y),UDim2.fromOffset(rowWidth,236),tint:Lerp(palette.white,.80),14);row.Name='FleetDrone'..index
  U.icon(row,'drone',UDim2.fromOffset(13,14),UDim2.fromOffset(62,62),tint)
  label(row,UDim2.fromOffset(87,14),UDim2.new(1,-102,0,33),d.name or ('Drone '..index),24,palette.ink,true)
  label(row,UDim2.fromOffset(87,50),UDim2.new(1,-102,0,24),'PERMANENT · '..string.upper(d.type or 'Blue'),10,palette.muted,true)
  local count=0;for _,c in ipairs(profile.run.cards) do if c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Color' and c.type==d.type) or (c.scope=='Individual' and c.targetDroneId==d.id) then count=count+1 end end
  local tileWidth=(rowWidth-42)/2
  statTile(row,14,91,tileWidth,'MINING',number(stats.miningDPS or 30)..' /s')
  statTile(row,tileWidth+28,91,tileWidth,'COMBAT',number(stats.combatDPS or 12)..' /s')
  statTile(row,14,153,tileWidth,'MAX HULL',number(stats.maxHealth or 80))
  statTile(row,tileWidth+28,153,tileWidth,'LASER START',number(stats.warmup or .8)..' sec')
  label(row,UDim2.fromOffset(15,213),UDim2.new(1,-30,0,16),tostring(count)..' matching run cards · reprints free',10,palette.muted)
 end
 local index=#profile.fleet+1;local x=((index-1)%columns)*(rowWidth+gap)+3;local y=64+math.floor((index-1)/columns)*254
 local nextDrone=U.panel(body,UDim2.fromOffset(x,y),UDim2.fromOffset(rowWidth,236),palette.accent:Lerp(palette.white,.76),14)
 local narrowTile=rowWidth<330;local tileTextX=narrowTile and 70 or 81
 U.icon(nextDrone,'prestige',UDim2.fromOffset(14,16),UDim2.fromOffset(narrowTile and 45 or 55,narrowTile and 45 or 55),palette.accent)
 label(nextDrone,UDim2.fromOffset(tileTextX,17),UDim2.new(1,-tileTextX-15,0,31),narrowTile and 'Next drone' or 'Next crewmate',narrowTile and 21 or 24,palette.ink,true)
 label(nextDrone,UDim2.fromOffset(tileTextX,54),UDim2.new(1,-tileTextX-15,0,20),'+1 PERMANENT DRONE',10,palette.muted,true)
 local pre=profile.prestigePreview or {};local earned=pre.earnings or 0;local required=pre.saleRequired or 2000
 label(nextDrone,UDim2.fromOffset(16,97),UDim2.new(1,-32,0,24),comma(earned)..' / '..comma(required)..' credits sold',13,palette.ink,true)
 label(nextDrone,UDim2.fromOffset(16,130),UDim2.new(1,-32,0,22),(pre.field or 'Cobalt')..' clears '..(pre.wins or 0)..' / '..(pre.winsRequired or 1),12,palette.muted)
 local review=button(nextDrone,UDim2.fromOffset(14,173),UDim2.new(1,-28,0,46),'Review fleet milestone',openPrestige,palette.accent);review.Name='ReviewMilestone'
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
   U.icon(row,categoryText(c)=='LASER' and 'startup' or string.lower(categoryText(c)),UDim2.fromOffset(12,13),UDim2.fromOffset(40,40),colors[c.type] or palette.mineral)
   label(row,UDim2.fromOffset(64,10),UDim2.new(1,-80,0,27),c.title or 'Run upgrade',21,palette.ink,true)
   label(row,UDim2.fromOffset(64,41),UDim2.new(1,-80,0,22),targetText(c),10,palette.muted,true)
   label(row,UDim2.fromOffset(15,73),UDim2.new(1,-30,0,43),c.description or c.headline or 'See its resolved stat bonuses in your fleet.',12,palette.ink)
  end
 end
end
openPrestige=function()
 if not profile then return end
 local l=menu('prestige','One more drone. A new run.','Review what stays with you before starting your next expedition.','prestige');local width=l.bodyWidth-6
 local narrow=width<400
 local pre=profile.prestigePreview or {};local before=pre.fleetBefore or #profile.fleet;local after=pre.fleetAfter or before+1
 local hero=U.panel(body,UDim2.fromOffset(3,3),UDim2.fromOffset(width,118),palette.accent:Lerp(palette.white,.63),16)
 U.icon(hero,'drone',UDim2.fromOffset(18,25),UDim2.fromOffset(narrow and 48 or 62,narrow and 48 or 62),colors[pre.newType] or palette.mineral)
 label(hero,UDim2.fromOffset(narrow and 80 or 98,16),UDim2.new(1,narrow and -96 or -116,0,43),before..' → '..after..(narrow and ' drones' or ' permanent drones'),narrow and 21 or 30,palette.ink,true)
 label(hero,UDim2.fromOffset(narrow and 18 or 98,narrow and 78 or 66),UDim2.new(1,narrow and -36 or -116,0,32),narrow and ('+1 permanent '..(pre.newType or 'new')..' drone.\nKeep your whole crew.') or ('Gain one '..(pre.newType or 'new')..' drone. Keep your whole crew.'),12,palette.ink)
 local pair=width>=560;local half=pair and (width-18)/2 or width
 local keep=U.panel(body,UDim2.fromOffset(3,141),UDim2.fromOffset(half,119),palette.mineral:Lerp(palette.white,.68),12)
 label(keep,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,24),'YOU KEEP',17,palette.ink,true)
 label(keep,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,61),'Every permanent drone\nBuilt-in types, IDs and base traits\nFree reprinting',12,palette.ink)
 local resetY=pair and 141 or 274
 local reset=U.panel(body,UDim2.fromOffset(pair and half+21 or 3,resetY),UDim2.fromOffset(half,119),palette.danger:Lerp(palette.white,.83),12)
 label(reset,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,24),'YOU RESET',17,palette.ink,true)
 label(reset,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,61),#profile.run.cards..' cards · '..comma(profile.run.credits)..' credits · '..cargoUnits(profile)..' ore\nPack prices and sale progress\nYour run’s field clearances',12,palette.ink)
 local y=pair and 284 or 417
 local required=pre.saleRequired or 2000;local earnings=pre.earnings or profile.run.saleEarnings or 0
 progress(body,y,width,'Your permanent fleet milestone',comma(earnings)..' / '..comma(required)..' credits sold · '..(pre.field or 'Cobalt')..' clears '..(pre.wins or 0)..' / '..(pre.winsRequired or 1),earnings/math.max(1,required),palette.accent)
 local allowed,blocked=availability('Prestige')
 local can=pre.eligible==true and not pending() and allowed
 local reason=not allowed and blocked or (pending() and 'Choose your paid pack card first' or (can and 'Start new run · +1 permanent drone' or 'Complete both milestone requirements'))
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
 profile=p
 if actionPending then
  local offer=p.run.pendingOffer
  if changedRun or (actionPending.kind=='ChooseCard' and (not offer or offer.id~=actionPending.offerId)) or (actionPending.kind=='BuyPack' and p.run.packIndex>actionPending.packIndex) then actionPending=nil end
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
  if not oldProfile or changedRun or #oldProfile.fleet~=#p.fleet or #oldProfile.run.cards~=#p.run.cards or milestoneChanged then refreshModal() end
 else refreshModal() end
end
connect(player:GetAttributeChangedSignal('MA_Profile'),readProfile);readProfile()
local noticeUntil=0
connect(player:GetAttributeChangedSignal('MA_Notice'),function()
 notice.Text=tostring(player:GetAttribute('MA_Notice') or '');noticeUntil=os.clock()+5;actionPending=nil;refreshModal()
end)

local sparkCount=0
local function sparkBurst(pos,color,amount)
 for _=1,math.min(amount,math.max(0,48-sparkCount)) do
  sparkCount=sparkCount+1
  local p=Instance.new('Part');p.Name='MineralChip';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Size=Vector3.new(.14,.14,.3);p.Material=Enum.Material.Neon;p.Color=color;p.Position=pos;p.Parent=localFX
  TweenService:Create(p,TweenInfo.new(.35),{Position=pos+Vector3.new(math.random(-4,4),math.random(2,5),math.random(-4,4)),Transparency=1,Size=Vector3.new(.03,.03,.03)}):Play()
  task.delay(.4,function() p:Destroy();sparkCount=sparkCount-1 end)
 end
end
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
 local anchor=Instance.new('Attachment');anchor.Name='RenderedBeamOrigin';anchor.Parent=emitter
 local endpoint=localPart(localFX,'BeamImpact',emitter.Position)
 local endAttachment=Instance.new('Attachment');endAttachment.Parent=endpoint
 local secondaryPoint=localPart(localFX,'SecondaryImpact',emitter.Position)
 local secondaryAttachment=Instance.new('Attachment');secondaryAttachment.Parent=secondaryPoint
 local secondary=Instance.new('Beam');secondary.Name='PrismArc';secondary.Attachment0=endAttachment;secondary.Attachment1=secondaryAttachment;secondary.FaceCamera=true;secondary.LightEmission=.9;secondary.Width0=.12;secondary.Width1=.06;secondary.Enabled=false;secondary.Color=ColorSequence.new(Color3.fromRGB(110,225,247));secondary.Transparency=NumberSequence.new(.15);secondary.Parent=endpoint
 local miningFX=RS:FindFirstChild('MiningFX')
 local template=miningFX and miningFX:FindFirstChild('Beam')
 local beamModel=template and template:Clone() or Instance.new('Model');beamModel.Name='RenderedMiningBeam';beamModel.Parent=localFX;sanitize(beamModel)
 local beams={}
 for _,v in ipairs(beamModel:GetDescendants()) do
  if v:IsA('BasePart') then v.Transparency=1
  elseif v:IsA('Beam') then table.insert(beams,v) end
 end
 if #beams==0 then
  for i=1,2 do
   local b=Instance.new('Beam');b.Name=i==1 and 'InnerBeam' or 'OuterBeam';b.Color=ColorSequence.new(i==1 and Color3.new(1,1,1) or Color3.fromRGB(114,222,246));b.Transparency=NumberSequence.new(i==1 and .05 or .7);b.FaceCamera=true;b.LightEmission=1;b.Parent=beamModel;table.insert(beams,b)
  end
 end
 for _,b in ipairs(beams) do b.Attachment0=anchor;b.Attachment1=endAttachment;b.Width0=0;b.Width1=0;b.Enabled=true end
 local impact=Instance.new('ParticleEmitter');impact.Name='BoundedImpact';impact.Texture='rbxasset://textures/particles/sparkles_main.dds';impact.Rate=0;impact.Lifetime=NumberRange.new(.12,.25);impact.Speed=NumberRange.new(1,3);impact.SpreadAngle=Vector2.new(80,80);impact.LightEmission=.8;impact.Size=NumberSequence.new(.12);impact.Color=ColorSequence.new(Color3.fromRGB(167,234,240));impact.Parent=endAttachment
 return {model=beamModel,origin=anchor,endpoint=endpoint,beams=beams,impact=impact,secondary=secondary,secondaryPoint=secondaryPoint,width=0,view=view,active=false,particleClock=0}
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
 d.view:Destroy();d.beam.model:Destroy();d.beam.endpoint:Destroy();d.beam.secondaryPoint:Destroy()
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
 if event=='stage' then safeSound('RockCrack',view);sparkBurst(view.Position,r.baseColor,2);presentation:resourceImpact(r,event,now)
 elseif event=='break' then safeSound('RockBreak',view);sparkBurst(view.Position,r.baseColor,8);presentation:resourceImpact(r,event,now) end
end
local function renderDrone(d,dt,now)
 local s=d.source;local state=s:GetAttribute('State') or 'Follow'
 local logical=s:GetAttribute('Position');local goal=s:GetAttribute('Goal') or logical
 if typeof(logical)~='Vector3' or typeof(goal)~='Vector3' then return end
 d.lastState=state
 local life=s:GetAttribute('Life');local maxStep=s:GetAttribute('MaxStep60') or .35
 if life~=d.life then d.life=life;d.pos=logical end
 if state=='Follow' then
  local owner=Players:GetPlayerByUserId(s:GetAttribute('Owner') or 0)
  local hr=owner and owner.Character and owner.Character:FindFirstChild('HumanoidRootPart')
  local slot=s:GetAttribute('FormationSlot');local count=s:GetAttribute('FleetCount')
  if hr and slot and count then goal=Feel.followGoal(hr.Position,slot,count,now,(s:GetAttribute('PhaseSeed') or maxStep*200)/200) end
 end
 if state=='Destroyed' or state=='Reprinting' then d.pos=logical
 else
  d.pos=Feel.approach(d.pos,goal,maxStep,math.min(dt,.1))
  local error=logical-d.pos
  -- Reconcile only material drift. Do not low-pass the server pose a second time.
  if error.Magnitude>25 then d.pos=logical
  elseif error.Magnitude>5 then d.pos=d.pos+error.Unit*math.min(error.Magnitude-5,maxStep*60*math.min(dt,.1)*.25) end
 end
 local targetYaw=Feel.levelYaw(d.pos,goal,d.yaw)
 local difference=math.atan2(math.sin(targetYaw-d.yaw),math.cos(targetYaw-d.yaw))
 d.yaw=d.yaw+difference*Feel.turnAlpha(math.min(dt,.1))
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
 local active=(mining or attacking) and state~='Destroyed' and state~='Reprinting'
 local r=resourceById(s:GetAttribute('TargetId'))
 local target=s:GetAttribute('TargetPosition')
 if r and r.view.Parent and r.view.Transparency<1 then target=r.view.CFrame:PointToWorldSpace(Vector3.new(0,r.view.Size.Y/2,0)) end
 if typeof(target)~='Vector3' then active=false end
 local beam=d.beam
 if active then
  local since=s:GetAttribute('BeamSince') or now
  local progress=math.clamp((now-since)/2,0,1)
  beam.width=1-(1-progress)^2
  beam.endpoint.Position=target
 else beam.width=math.max(0,beam.width-dt/.2) end
 for _,b in ipairs(beam.beams) do
  local inner=b.Name=='InnerBeam'
  b.Width0=(inner and .3 or .65)*beam.width;b.Width1=(inner and .3 or .65)*beam.width;b.Enabled=beam.width>0.001
 end
 local fork=state=='Mine' and now<(s:GetAttribute('ForkUntil') or 0)
 local chain=state=='Attack' and now<(s:GetAttribute('ChainUntil') or 0)
 local secondaryTarget=s:GetAttribute(chain and 'ChainTargetPosition' or 'ForkTargetPosition')
 beam.secondary.Enabled=active and (fork or chain) and typeof(secondaryTarget)=='Vector3'
 if beam.secondary.Enabled then beam.secondaryPoint.Position=secondaryTarget;beam.secondary.Color=ColorSequence.new(chain and Color3.fromRGB(255,194,104) or Color3.fromRGB(110,225,247)) end
 beam.particleClock=beam.particleClock+dt
 if active and beam.particleClock>.08 then beam.impact:Emit(1);beam.particleClock=0 end
end
connect(RunService.RenderStepped,function(dt)
 local now=workspace:GetServerTimeNow()
 for _,r in pairs(resources) do renderResource(r,now) end
 for _,d in pairs(drones) do renderDrone(d,dt,now) end
 for _,t in pairs(turrets) do presentation:renderTurret(t,dt,now) end
 presentation:update(dt,now)
end)

local evade=button(safeRoot,UDim2.new(1,-136,1,-108),UDim2.fromOffset(118,38),'Evade  [Q]',function() command:FireServer('Evade') end,palette.accent);evade.Visible=false
local enemyHUD=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(300,58),palette.panel,12);enemyHUD.Name='SentryHealth';enemyHUD.Visible=false
local enemyTitle=label(enemyHUD,UDim2.fromOffset(12,6),UDim2.new(1,-24,0,19),'PYRAMID SENTRY',12,nil,true)
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
local lastStationUse=0
local function performStation(station)
 local action=stationAction(station)
 if modal.Visible then return end
 if action and os.clock()-lastStationUse>.25 then lastStationUse=os.clock();action() end
end
connect(game:GetService('ProximityPromptService').PromptTriggered,function(prompt,who)
 if (not who or who==player) and prompt.Parent and prompt.Parent:IsA('BasePart') then performStation(prompt.Parent) end
end)
local function assignField(target)
 if modal.Visible then return end
 local node=target
 while node and node~=workspace do
  local field=node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier')
  if type(field)=='number' then command:FireServer('Patch',field);return end
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
 if input.UserInputType==Enum.UserInputType.MouseButton1 then assignField(mouse.Target);return end
 local key=input.KeyCode
 if key==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false
 elseif key==Enum.KeyCode.R then command:FireServer('Recall')
 elseif key==Enum.KeyCode.Q then command:FireServer('Evade')
 elseif key==Enum.KeyCode.E and not modal.Visible then if contextAction then contextAction() end
 elseif not modal.Visible then
  local fields={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5}
  if fields[key] then command:FireServer('Patch',fields[key]) end
 end
end)
local hudClock=0
local availabilitySignature=''
local contextKind='mining'
connect(RunService.Heartbeat,function(dt)
 hudClock=hudClock+dt;if hudClock<.2 then return end;hudClock=0
 local view=viewport();local l=currentLayout();local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 hud.Position=UDim2.fromOffset(l.hudX,l.hudY);hud.Size=UDim2.fromOffset(l.hudWidth,l.hudHeight)
 creditsLabel.Size=UDim2.fromOffset(l.hudWidth-190,32);saveLabel.Size=UDim2.fromOffset(l.hudWidth-190,13)
 creditsLabel.TextSize=l.hudWidth<330 and 24 or 28
 cargoText.Size=UDim2.fromOffset(l.hudWidth-158,18);cargoText.Position=UDim2.fromOffset(15,l.short and 47 or 53)
 cargoTrack.Position=UDim2.fromOffset(14,l.short and 67 or 76)
 fleetButton.Size=UDim2.fromOffset(52,l.hudHeight-18);runButton.Size=fleetButton.Size
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
 if modal.Visible and (not modalSize or (modalSize-view).Magnitude>1) then refreshModal() end
 if modal.Visible and (modalMode=='offer' or modalMode=='pack' or modalMode=='prestige') then
  local action=modalMode=='offer' and 'ChooseCard' or modalMode=='pack' and 'BuyPack' or 'Prestige'
  local allowed,reason=availability(action);local signature=modalMode..':'..tostring(allowed)..':'..reason
  if signature~=availabilitySignature then availabilitySignature=signature;refreshModal() end
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
 if l.hudWidth<310 then saveLabel.TextSize=8 else saveLabel.TextSize=9.5 end
 saveLabel.TextColor3=status:find('preview') and Color3.fromRGB(137,91,37) or palette.muted
 if profile and profile.run then
  local amount=cargoUnits(profile);local capacity=profile.capacity or 120
  local credits=profile.run.credits or 0;local creditText=comma(credits)
  if credits>=1e9 then creditText=string.format('%.1fB',credits/1e9) elseif credits>=1e6 then creditText=string.format('%.1fM',credits/1e6) elseif credits>=10000 then creditText=string.format('%.1fk',credits/1000) end
  creditsLabel.Text=creditText
  fleetCount.Text='Fleet '..tostring(#(profile.fleet or {}));runCount.Text=pending() and 'Pick 1!' or ('Cards '..#profile.run.cards)
  cargoText.Text=string.format('CARGO  %s / %s',comma(amount),comma(capacity))
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
    contextAction=function() command:FireServer('Patch',id) end;contextTitle.Text=nearest:GetAttribute('DisplayName') or nearest.Name
    local phase=nearest:GetAttribute('Phase') or 'Safe'
    local actionText=(phase=='Guarded' or phase=='Active') and 'Fight' or (phase=='Gathering' and 'Join' or 'Mine')
    contextDetail.Text=(phase=='Active' and 'Starting crew only') or (phase=='Guarded' and 'Sentries block mining') or (phase=='Gathering' and 'Join before the fight starts') or 'Gather minerals with your fleet'
    contextButton.Text=actionText..(touch and '' or ' [E]');context.Visible=true
   end
  end
 end
 if l.contextReplacesHUD and context.Visible then hud.Visible=false end
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
 toast.Visible=notice.Text~='' and not modal.Visible and not (l.short and ownActive)
 if l.short then toast.Position=UDim2.fromOffset(l.hudX,l.hudY);if toast.Visible then hud.Visible=false end end
 if toast.Visible and view.X<1100 then objectiveBox.Visible=false end
 if modal.Visible and notice.Text~='' and noticeUntil>os.clock() then
  modalSubtitle.Text=notice.Text;modalSubtitle.TextColor3=palette.ink
 else modalSubtitle.Text=normalSubtitle;modalSubtitle.TextColor3=palette.muted end
end)
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),refreshModal)
connect(gui.Destroying,function()
 foliage:destroy()
 presentation:destroy()
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,c in pairs(observed) do c:Disconnect() end
 for part in pairs(hiddenParts) do if part.Parent then part.LocalTransparencyModifier=0 end end
 localFX:Destroy()
end)
