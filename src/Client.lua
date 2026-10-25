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
local drones,resources,resourceIndex,turrets,connections={},{},{},{},{}
local hiddenParts={}
local pendingDroneSources={}
local templateRetryQueued=false
local profile=nil
local colors={Blue=Color3.fromRGB(99,198,246),Red=Color3.fromRGB(243,117,112),Green=Color3.fromRGB(122,219,163)}
local palette={ink=Color3.fromRGB(14,22,32),panel=Color3.fromRGB(23,35,46),muted=Color3.fromRGB(164,181,190),text=Color3.fromRGB(244,237,219),accent=Color3.fromRGB(237,181,97),mineral=Color3.fromRGB(107,214,224),line=Color3.fromRGB(62,79,89)}
local gui=Instance.new('ScreenGui');gui.Name='MiningAwayHUD';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=player:WaitForChild('PlayerGui')
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
local function corner(parent,r) local x=Instance.new('UICorner');x.CornerRadius=UDim.new(0,r or 3);x.Parent=parent end
local function stroke(parent,color) local x=Instance.new('UIStroke');x.Color=color or palette.line;x.Thickness=1;x.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;x.Parent=parent;return x end
local function layer(parent) return parent:IsA('GuiObject') and parent.ZIndex or 1 end
local function frame(parent,pos,size,color)
 local f=Instance.new('Frame');f.Position=pos;f.Size=size;f.BackgroundColor3=color or palette.ink;f.BorderSizePixel=0;f.ZIndex=layer(parent);f.Parent=parent;return f
end
local function label(parent,pos,size,text,sizePx,color,bold)
 local t=Instance.new('TextLabel');t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.Text=text or '';t.TextColor3=color or palette.text;t.TextSize=sizePx or 14;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Center;t.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;t.TextWrapped=true;t.ZIndex=layer(parent);t.Parent=parent;return t
end
local buttonBases=setmetatable({},{__mode='k'})
local buttonTweens=setmetatable({},{__mode='k'})
local function paintButton(b,color,duration)
 if buttonTweens[b] then buttonTweens[b]:Cancel() end
 local tween=TweenService:Create(b,TweenInfo.new(duration or .1),{BackgroundColor3=color});buttonTweens[b]=tween;tween:Play()
end
local function button(parent,pos,size,text,callback,color)
 local b=Instance.new('TextButton');b.Position=pos;b.Size=size;b.Text=text;b.TextColor3=palette.ink;b.TextStrokeTransparency=1;b.BackgroundColor3=color or palette.accent;b.BorderSizePixel=0;b.Font=Enum.Font.GothamBold;b.TextSize=13;b.AutoButtonColor=false;b.ZIndex=layer(parent);b.Parent=parent;corner(b,3)
 buttonBases[b]=b.BackgroundColor3
 local function shade(amount) if b.Active then paintButton(b,buttonBases[b]:Lerp(Color3.new(1,1,1),amount)) end end
 b.MouseEnter:Connect(function() shade(.1) end);b.MouseLeave:Connect(function() shade(0) end)
 b.MouseButton1Down:Connect(function() if b.Active then paintButton(b,buttonBases[b]:Lerp(palette.ink,.22),.06) end end)
 b.MouseButton1Up:Connect(function() shade(.1) end)
 b.Destroying:Connect(function() if buttonTweens[b] then buttonTweens[b]:Cancel() end;buttonTweens[b]=nil;buttonBases[b]=nil end)
 b.Activated:Connect(function() if b.Active then uiClick:Play();callback() end end);return b
end
local function enableAction(b,enabled)
 if buttonTweens[b] then buttonTweens[b]:Cancel() end
 b.Active=enabled;b.BackgroundColor3=enabled and palette.accent or palette.line;b.TextColor3=enabled and palette.ink or palette.muted;buttonBases[b]=b.BackgroundColor3
end
local hud=frame(gui,UDim2.fromOffset(18,16),UDim2.fromOffset(332,72));hud.Active=true;corner(hud);stroke(hud)
local creditsLabel=label(hud,UDim2.fromOffset(12,7),UDim2.fromOffset(212,29),'Loading expedition',21,nil,true)
local fleetButton=button(hud,UDim2.new(1,-100,0,9),UDim2.fromOffset(88,28),'Fleet  1',function() end,palette.panel);fleetButton.TextColor3=palette.text;stroke(fleetButton)
local cargoText=label(hud,UDim2.fromOffset(12,43),UDim2.fromOffset(158,17),'CARGO  0 / 120',11,palette.mineral)
local saveLabel=label(hud,UDim2.new(1,-151,0,43),UDim2.fromOffset(139,17),'CONNECTING',10,palette.muted);saveLabel.TextXAlignment=Enum.TextXAlignment.Right
local cargoTrack=frame(hud,UDim2.new(0,0,1,-3),UDim2.new(1,0,0,3),palette.line)
local cargoFill=frame(cargoTrack,UDim2.fromScale(0,0),UDim2.fromScale(0,1),palette.mineral)
local objective=label(gui,UDim2.fromOffset(20,96),UDim2.fromOffset(328,42),'Click a mineral field to send your drone.\nReturn to the Converter when your cargo is full.',13,palette.text)
objective.TextStrokeColor3=palette.ink;objective.TextStrokeTransparency=.25
local notice=label(gui,UDim2.new(.5,-220,0,92),UDim2.fromOffset(440,42),'',14,palette.text,true);notice.TextXAlignment=Enum.TextXAlignment.Center;notice.TextStrokeColor3=palette.ink;notice.TextStrokeTransparency=.15
local recall=button(gui,UDim2.new(1,-136,1,-62),UDim2.fromOffset(118,38),'Recall  [R]',function() command:FireServer('Recall') end,palette.ink);recall.TextColor3=palette.text;stroke(recall)
local context=frame(gui,UDim2.new(.5,-190,1,-84),UDim2.fromOffset(380,62));context.Active=true;corner(context);stroke(context);context.Visible=false
local contextTitle=label(context,UDim2.fromOffset(14,8),UDim2.new(1,-122,0,20),'',14,nil,true)
local contextDetail=label(context,UDim2.fromOffset(14,29),UDim2.new(1,-122,0,26),'',11,palette.muted)
local contextAction=nil
local contextButton=button(context,UDim2.new(1,-99,0,12),UDim2.fromOffset(85,38),'Use  [E]',function() if contextAction then contextAction() end end)
local modal=frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(0,0,0));modal.BackgroundTransparency=.3;modal.Visible=false;modal.ZIndex=20;modal.Active=true
local sheet=frame(modal,UDim2.new(.5,-470,.5,-260),UDim2.fromOffset(940,520));sheet.ZIndex=21;corner(sheet,4);stroke(sheet)
frame(sheet,UDim2.fromOffset(0,0),UDim2.new(1,0,0,3),palette.accent)
local modalTitle=label(sheet,UDim2.fromOffset(22,18),UDim2.new(1,-108,0,30),'Choose your next advantage',23,nil,true)
local modalSubtitle=label(sheet,UDim2.fromOffset(22,52),UDim2.new(1,-44,0,31),'Three cards. Keep one. Effects last for this expedition.',12,palette.muted)
local close=button(sheet,UDim2.new(1,-74,0,19),UDim2.fromOffset(52,28),'Close',function() modal.Visible=false end,palette.panel);close.TextColor3=palette.muted;close.TextSize=11
local body=Instance.new('ScrollingFrame');body.Position=UDim2.fromOffset(22,96);body.Size=UDim2.new(1,-44,1,-114);body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=3;body.ScrollBarImageColor3=palette.muted;body.CanvasSize=UDim2.fromScale(0,0);body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.ZIndex=sheet.ZIndex;body.Parent=sheet
local modalMode=nil
local function clearBody() for _,x in ipairs(body:GetChildren()) do x:Destroy() end;body.CanvasPosition=Vector2.zero end
local function tx() return Http:GenerateGUID(false) end
local function send(action,data)
 if not profile or not profile.run then return end
 data=data or {};data.txId=tx();data.runId=profile.run.id;command:FireServer(action,data)
end
local function comma(n) local s=tostring(math.floor(tonumber(n) or 0));local r=s:reverse():gsub('(%d%d%d)','%1,'):reverse();return (r:gsub('^,','')) end
local function cargoUnits(p) local n=0;for _,v in pairs((p.run and p.run.cargo) or {}) do if type(v)=='number' then n=n+v end end;return n end
local function pending() return profile and profile.run and profile.run.pendingOffer end
local function viewport()
 local camera=workspace.CurrentCamera;return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local modalSize=nil
local function layoutModal()
 local v=viewport();local mobile=v.X<760
 local width=math.min(940,math.max(248,v.X-24));local height=math.min(mobile and 650 or 570,math.max(200,v.Y-32))
 sheet.Size=UDim2.fromOffset(width,height);sheet.Position=UDim2.new(.5,-width/2,.5,-height/2);modalSize=v
 modalTitle.TextSize=width<380 and 19 or 23
 return mobile,width
end
local openOffer,openPack,openPrestige,openFleet
local function number(n)
 if math.abs(n)>=100 then return comma(n) end
 if math.abs(n-math.floor(n+.5))<.001 then return tostring(math.floor(n+.5)) end
 return string.format('%.2g',n)
end
local function previewLines(choice)
 local result={}
 for _,item in ipairs(choice.preview or {}) do
  if type(item)=='table' then
   local before,after=tonumber(item.before),tonumber(item.after)
   if before and after then
    local title,unit=item.label or 'Effect',item.unit or ''
    if title=='Flight / 60Hz' then title='Flight';before=before*60;after=after*60;unit=' studs/s' end
    if unit~='%' and (title=='Turret resistance' or title=='Critical chance' or title=='Combat splash' or title=='Mining fork') then before=before*100;after=after*100;unit='%' end
    if title=='Shared cargo' then title='Cargo';unit=' ore' end
    table.insert(result,title..'  '..number(before)..' → '..number(after)..unit)
    if #result==4 then break end
   end
  end
 end
 return table.concat(result,'\n')
end
local function targetText(choice)
 if choice.scope=='Individual' then return 'ONE DRONE  /  '..(choice.targetName or 'Assigned drone') end
 if choice.scope=='Color' then return 'ALL '..string.upper(choice.type or '')..' DRONES' end
 return choice.scope=='Player' and 'SHARED CARGO HOLD' or 'ENTIRE FLEET'
end
local function categoryText(choice)
 if choice.category then return string.upper(choice.category) end
 local e=choice.effects or {}
 if e.combat or e.rate or e.crit or e.splash then return 'COMBAT' end
 if e.health or e.reduction or e.shield then return 'SURVIVAL' end
 if e.capacity or e.yield then return 'CARGO' end
 if e.mining or e.fork then return 'MINING' end
 return e.startup and 'LASER' or 'FLIGHT'
end
local function stackText(choice)
 if choice.stackText then return choice.stackText end
 local count=0
 for _,owned in ipairs(profile.run.cards or {}) do if owned.cardId==choice.cardId and (choice.scope~='Individual' or owned.targetDroneId==choice.targetDroneId) then count=count+1 end end
 local reserve=string.sub(choice.cardId or '',1,1)=='R'
 local limit=(choice.scope=='Fleet' or choice.scope=='Player') and 2 or 1
 return reserve and 'Repeatable until its stat cap. This run only.' or string.format('Stack %d / %d this run. Adds to existing bonuses.',count+1,limit)
end
openOffer=function()
 local offer=pending();if not offer or not offer.choices then return end
 modalMode='offer';clearBody();modalTitle.Text='Choose one card';modalSubtitle.Text='PACK '..tostring(offer.packIndex or 1)..'  /  Take one card. These choices stay if you close this screen.'
 local mobile,width=layoutModal();local cardWidth=mobile and width-48 or (width-76)/3
 local list=Instance.new('UIListLayout');list.FillDirection=mobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal;list.Padding=UDim.new(0,14);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 for index,choice in ipairs(offer.choices) do
  local card=frame(body,UDim2.fromOffset(0,0),UDim2.fromOffset(cardWidth,440),palette.panel);card.LayoutOrder=index;corner(card,5);stroke(card)
  local category=categoryText(choice);local tint=colors[choice.type] or ((category=='COMBAT' or category=='SURVIVAL') and palette.accent or palette.mineral)
  frame(card,UDim2.fromOffset(0,0),UDim2.new(1,0,0,3),tint)
  label(card,UDim2.fromOffset(14,14),UDim2.new(1,-50,0,15),category,10,tint,true)
  local indexLabel=label(card,UDim2.new(1,-37,0,13),UDim2.fromOffset(23,18),string.format('%02d',index),11,palette.muted);indexLabel.TextXAlignment=Enum.TextXAlignment.Right
  local title=label(card,UDim2.fromOffset(14,37),UDim2.new(1,-28,0,46),choice.title or 'Run card',20,nil,true);title.TextYAlignment=Enum.TextYAlignment.Top
  label(card,UDim2.fromOffset(14,87),UDim2.new(1,-28,0,27),targetText(choice),10,tint,true)
  frame(card,UDim2.fromOffset(14,119),UDim2.new(1,-28,0,1),palette.line)
  local headline=label(card,UDim2.fromOffset(14,132),UDim2.new(1,-28,0,35),choice.headline or category..' ADVANTAGE',15,palette.text,true);headline.TextYAlignment=Enum.TextYAlignment.Top
  local purpose=label(card,UDim2.fromOffset(14,172),UDim2.new(1,-28,0,60),choice.description or choice.purpose or 'Changes apply to the target shown above.',13,palette.text);purpose.TextYAlignment=Enum.TextYAlignment.Top
  local downside=choice.tradeoff
  if not downside then
   local hasLoss=false;for _,v in pairs(choice.effects or {}) do if v<0 then hasLoss=true end end
   downside=hasLoss and ('TRADEOFF  '..(choice.description or 'See card effect.')) or 'No stat penalty.'
  end
  local tradeoff=label(card,UDim2.fromOffset(14,235),UDim2.new(1,-28,0,35),downside,11,palette.accent);tradeoff.TextYAlignment=Enum.TextYAlignment.Top
  local previewName=choice.previewTargetName or choice.targetName
  label(card,UDim2.fromOffset(14,274),UDim2.new(1,-28,0,16),previewName and ('STATS  /  '..previewName) or 'YOUR CURRENT STATS',10,palette.muted,true)
  local preview=label(card,UDim2.fromOffset(14,296),UDim2.new(1,-28,0,60),previewLines(choice),11,palette.text);preview.TextYAlignment=Enum.TextYAlignment.Top
  local stacks=label(card,UDim2.fromOffset(14,363),UDim2.new(1,-28,0,29),stackText(choice),10,palette.muted);stacks.TextYAlignment=Enum.TextYAlignment.Top
  local choose
  choose=button(card,UDim2.new(0,14,1,-46),UDim2.new(1,-28,0,34),'Take this card',function()
   if not pending() or pending().id~=offer.id then return end
   choose.Text='Applying…';enableAction(choose,false)
   send('ChooseCard',{offerId=offer.id,index=index})
  end)
 end
 modal.Visible=true
end
openPack=function()
 if pending() then openOffer();return end
 if not profile or not profile.run then return end
 modalMode='pack';clearBody();local _,width=layoutModal();modalTitle.Text='Build this run';modalSubtitle.Text='A pack gives three cards. Choose one. Every card lasts until prestige.'
 local price=profile.nextPackPrice or profile.packPrice or 80
 local credits=profile.run.credits or 0;local can=credits>=price
 label(body,UDim2.fromOffset(0,0),UDim2.new(1,0,0,19),'NEXT PACK  /  '..tostring((profile.run.packIndex or 0)+1),11,palette.muted,true)
 label(body,UDim2.fromOffset(0,30),UDim2.new(1,0,0,43),comma(price)..' credits',31,palette.accent,true)
 label(body,UDim2.fromOffset(0,85),UDim2.new(1,0,0,44),can and 'Ready to open. Pick the advantage your fleet needs next.' or ('Sell '..comma(price-credits)..' more credits of minerals at the Converter.'),15,palette.text)
 local buy
 buy=button(body,UDim2.fromOffset(0,148),UDim2.fromOffset(math.min(260,width-52),44),can and 'Open pack  /  '..comma(price) or 'Keep mining to afford a pack',function()
  if not can then return end
  buy.Text='Opening…';enableAction(buy,false)
  send('BuyPack',{packIndex=profile.run.packIndex,expectedPackIndex=profile.run.packIndex})
 end);enableAction(buy,can)
 label(body,UDim2.fromOffset(0,217),UDim2.new(1,-4,0,68),'Mining, combat, cargo or flight: commit to a stronger build, then challenge the guarded fields.\n\nYou keep every drone when you begin the next expedition.',13,palette.muted)
 modal.Visible=true
end
openPrestige=function()
 if not profile then return end
 modalMode='prestige';clearBody();local mobile=layoutModal();modalTitle.Text='Grow your fleet'
 local pre=profile.prestigePreview or profile.prestige or {}
 local before=pre.fleetBefore or #profile.fleet;local after=pre.fleetAfter or before+1
 modalSubtitle.Text='Start a fresh run. Every permanent drone stays with you.'
 local can=pre.eligible==true and not pending()
 label(body,UDim2.fromOffset(0,0),UDim2.new(1,0,0,38),string.format('%d → %d permanent drones',before,after),26,palette.text,true)
 label(body,UDim2.fromOffset(0,42),UDim2.new(1,0,0,24),'+1 '..(pre.newType or 'permanent')..' drone',15,colors[pre.newType] or palette.mineral,true)
 local boxWidth=mobile and UDim2.new(1,-4,0,106) or UDim2.new(.5,-9,0,114)
 local keep=frame(body,UDim2.fromOffset(0,82),boxWidth,palette.panel);corner(keep)
 label(keep,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,18),'KEEP',10,palette.mineral,true)
 label(keep,UDim2.fromOffset(14,34),UDim2.new(1,-28,0,62),'Every permanent drone\nBuilt-in types and base traits',14)
 local resetY=mobile and 202 or 82
 local reset=frame(body,mobile and UDim2.fromOffset(0,resetY) or UDim2.new(.5,5,0,resetY),boxWidth,palette.panel);corner(reset)
 label(reset,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,18),'RESET',10,palette.accent,true)
 label(reset,UDim2.fromOffset(14,34),UDim2.new(1,-28,0,68),string.format('%d run cards  /  %s credits  /  %d cargo\nPack prices, sale progress and field clearances',pre.cards or #(profile.run.cards or {}),comma(profile.run.credits),cargoUnits(profile)),12)
 local progressY=mobile and 325 or 214
 local progress=string.format('Sold %s / %s credits   •   %s clears %d / %d',comma(pre.earnings or profile.run.saleEarnings),comma(pre.saleRequired or 2000),tostring(pre.field or 'Cobalt'),pre.wins or 0,pre.winsRequired or 1)
 if pending() then progress='Take your saved pack card before starting a new expedition.' elseif can then progress='Milestone complete. Your next drone is ready.' end
 label(body,UDim2.fromOffset(0,progressY),UDim2.new(1,-4,0,45),progress,13,can and palette.mineral or palette.muted)
 local confirm=button(body,UDim2.fromOffset(0,progressY+60),UDim2.new(1,-4,0,44),can and 'Begin new expedition  /  +1 drone' or 'Complete the milestone to prestige',function()
  if can then send('Prestige',{confirm=true});modal.Visible=false end
 end);enableAction(confirm,can)
 modal.Visible=true
end
openFleet=function()
 if not profile then return end
 modalMode='fleet';clearBody();local mobile=layoutModal();modalTitle.Text='Your permanent fleet';modalSubtitle.Text='These drones are yours. Run cards change their stats until prestige.'
 local y=0
 for index,d in ipairs(profile.fleet or {}) do
  local stats=d.effective or (profile.droneStats and profile.droneStats[d.id]) or d.base or {}
  local rowHeight=mobile and 134 or 102
  local row=frame(body,UDim2.fromOffset(0,y),UDim2.new(1,-4,0,rowHeight),palette.panel);corner(row)
  frame(row,UDim2.fromOffset(0,0),UDim2.new(0,3,1,0),colors[d.type] or palette.mineral)
  label(row,UDim2.fromOffset(14,9),UDim2.new(1,-28,0,25),d.name or ('Drone '..index),18,colors[d.type] or palette.text,true)
  local count=0;for _,c in ipairs(profile.run.cards or {}) do if c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Color' and c.type==d.type) or (c.scope=='Individual' and c.targetDroneId==d.id) then count=count+1 end end
  label(row,UDim2.fromOffset(14,37),UDim2.new(1,-28,0,18),string.format('%s type  /  %d active run %s',d.type or 'Blue',count,count==1 and 'card' or 'cards'),11,palette.muted)
  local values=string.format('Mining  %.1f /s    •    Combat  %.1f /s%sHull  %.0f    •    Laser ready  %.2fs',stats.miningDPS or stats.mining or 30,stats.combatDPS or stats.combat or 8,mobile and '\n' or '    •    ',stats.maxHealth or stats.maxHP or stats.health or 80,stats.warmup or stats.startup or 2)
  label(row,UDim2.fromOffset(14,60),UDim2.new(1,-28,0,mobile and 58 or 32),values,12,palette.text)
  y=y+rowHeight+12
 end
 modal.Visible=true
end
fleetButton.Activated:Connect(openFleet)
local function refreshModal()
 if not modal.Visible then return end
 local mode=modalMode
 if mode=='offer' then if pending() then openOffer() end
 elseif mode=='pack' then openPack()
 elseif mode=='prestige' then openPrestige()
 elseif mode=='fleet' then openFleet() end
end
local lastOffer=nil
local function readProfile()
 local raw=player:GetAttribute('MA_Profile');if type(raw)~='string' then return end
 local ok,p=pcall(function() return Http:JSONDecode(raw) end);if not ok or type(p)~='table' then return end
 profile=p
 local offer=pending()
 if offer and offer.id~=lastOffer then lastOffer=offer.id;openOffer()
 elseif not offer and modalMode=='offer' then modal.Visible=false;modalMode=nil
 else refreshModal() end
end
connect(player:GetAttributeChangedSignal('MA_Profile'),readProfile);readProfile()
local noticeUntil=0
connect(player:GetAttributeChangedSignal('MA_Notice'),function() notice.Text=tostring(player:GetAttribute('MA_Notice') or '');noticeUntil=os.clock()+5;refreshModal() end)

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
  local trim=localPart(clone,'LowerChassis',pivot.Position);trim.Size=Vector3.new(pivot.Size.X*1.015,.12,pivot.Size.Z*1.015);trim.Transparency=0;trim.Color=palette.panel;trim.Material=Enum.Material.Metal;trim.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.35,0)
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

local evade=button(gui,UDim2.new(1,-136,1,-108),UDim2.fromOffset(118,38),'Evade  [Q]',function() command:FireServer('Evade') end,palette.accent);evade.Visible=false
local enemyHUD=frame(gui,UDim2.new(.5,-135,0,17),UDim2.fromOffset(270,54));corner(enemyHUD);stroke(enemyHUD);enemyHUD.Visible=false
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
 if processed then return end
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
connect(RunService.Heartbeat,function(dt)
 hudClock=hudClock+dt;if hudClock<.2 then return end;hudClock=0
 local view=viewport();local small=view.X<760;local short=view.Y<500;local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 local hudWidth=math.min(332,math.max(248,view.X-36))
 if short and view.X>=568 then hudWidth=math.min(332,math.max(248,view.X-324)) end
 hud.Size=UDim2.fromOffset(hudWidth,72)
 creditsLabel.Size=UDim2.fromOffset(hudWidth-120,29)
 cargoText.Size=UDim2.fromOffset(hudWidth-165,17)
 objective.Size=UDim2.fromOffset(math.min(328,view.X-40),48)
 local contextWidth=math.min(380,math.max(248,view.X-32))
 context.Size=UDim2.fromOffset(contextWidth,62);context.Position=UDim2.new(.5,-contextWidth/2,1,small and -224 or -84)
 recall.Position=UDim2.new(1,-136,1,small and -152 or -62);evade.Position=small and UDim2.new(1,-264,1,-152) or UDim2.new(1,-136,1,-108)
 recall.Text=touch and 'Recall fleet' or 'Recall  [R]'
 recall.Visible=not modal.Visible;objective.Visible=not modal.Visible
 local noticeWidth=math.min(440,math.max(248,view.X-32))
 notice.Size=UDim2.fromOffset(noticeWidth,48);notice.Position=UDim2.new(.5,-noticeWidth/2,0,view.X<1000 and 210 or 92)
 notice.TextXAlignment=Enum.TextXAlignment.Center
 enemyHUD.Position=UDim2.new(.5,-135,0,view.X<1000 and 150 or 17)
 if short then
  context.Position=UDim2.new(.5,-contextWidth/2,1,-82)
  recall.Position=UDim2.new(1,-136,1,-130);evade.Position=UDim2.new(1,-264,1,-130)
  notice.Position=UDim2.fromOffset(18,96);notice.Size=UDim2.fromOffset(math.min(332,view.X-36),48);notice.TextXAlignment=Enum.TextXAlignment.Left
  if view.X>=568 then enemyHUD.Position=UDim2.new(1,-288,0,16) end
 end
 if modal.Visible and (not modalSize or (modalSize-view).Magnitude>1) then refreshModal() end
 if os.clock()>noticeUntil then notice.Text='' end
 local status=tostring(player:GetAttribute('MA_SaveStatus') or 'Loading'):lower()
 if status:find('preview') then saveLabel.Text='PREVIEW / UNSAVED'
 elseif status:find('loading') then saveLabel.Text='CONNECTING'
 elseif status:find('unavailable') then saveLabel.Text='PROFILE UNAVAILABLE'
 elseif status:find('saved') then saveLabel.Text='AUTOSAVE ON'
 else saveLabel.Text='SAVE PAUSED' end
 saveLabel.TextColor3=status:find('preview') and palette.accent or palette.muted
 if profile and profile.run then
  local amount=cargoUnits(profile);local capacity=profile.capacity or 120
  local credits=profile.run.credits or 0;local creditText=comma(credits)
  if credits>=1e9 then creditText=string.format('%.1fB',credits/1e9) elseif credits>=1e6 then creditText=string.format('%.1fM',credits/1e6) elseif credits>=10000 then creditText=string.format('%.1fk',credits/1000) end
  creditsLabel.Text=creditText..' credits';creditsLabel.TextSize=hudWidth<300 and 19 or 21
  fleetButton.Text='Fleet  '..tostring(#(profile.fleet or {}))
  cargoText.Text=string.format('CARGO  %s / %s',comma(amount),comma(capacity))
  cargoFill.Size=UDim2.fromScale(math.clamp(amount/math.max(1,capacity),0,1),1)
  cargoFill.BackgroundColor3=amount>=capacity and palette.accent or palette.mineral
  local pre=profile.prestigePreview;local price=profile.nextPackPrice or 80
  local recallHint=touch and 'Recall' or 'Recall [R]'
  if pending() then objective.Text='Choose your saved card at the card machine.\nThree choices. One advantage for this expedition.'
  elseif amount>=capacity then objective.Text='Cargo full. '..recallHint..', then sell at home.\nThe Converter turns minerals into pack credits.'
  elseif pre and pre.eligible then objective.Text='Prestige ready: +1 permanent drone.\nVisit the beacon to grow your fleet.'
  elseif credits>=price then objective.Text='Your next pack is ready: '..comma(price)..' credits.\nVisit the card machine to upgrade your fleet.'
  elseif (profile.run.packIndex or 0)==0 then objective.Text='Click a mineral field to send your drone.\nMine → sell at home → buy your first pack.'
  elseif pre and (pre.earnings or 0)>=(pre.saleRequired or 2000) and (pre.wins or 0)<(pre.winsRequired or 1) then objective.Text=string.format('Clear %s to earn your next permanent drone.\nSentry victories: %d / %d.',pre.field or 'Cobalt',pre.wins or 0,pre.winsRequired or 1)
  elseif pre then objective.Text=string.format('Next drone: %s / %s credits sold.\n%s victories: %d / %d. Upgrade to break through.',comma(pre.earnings or 0),comma(pre.saleRequired or 2000),pre.field or 'Cobalt',pre.wins or 0,pre.winsRequired or 1)
  else objective.Text='Mine → sell → choose a stronger build.\nDefeat the sentries to reach richer minerals.' end
 end
 local ownActive=false;local reprints={};local now=workspace:GetServerTimeNow()
 for source in pairs(drones) do
  if source:GetAttribute('Owner')==player.UserId then
   local state=source:GetAttribute('State')
   if state=='Attack' then ownActive=true end
   local at=source:GetAttribute('ReprintAt') or 0
   if at>now then table.insert(reprints,string.format('%s reprinting: %ds',source:GetAttribute('DroneName') or source:GetAttribute('Name') or 'Drone',math.ceil(at-now))) end
  end
 end
 evade.Visible=ownActive and not modal.Visible;evade.Text=touch and 'Evade shot' or 'Evade  [Q]'
 if ownActive then objective.Text=touch and 'Watch the sentry charge line.\nTap Evade just before its shot lands.' or 'Watch the sentry charge line.\nEvade [Q] just before its shot lands.' end
 if #reprints>0 and os.clock()>noticeUntil then notice.Text=#reprints>2 and tostring(#reprints)..' drones reprinting for free' or table.concat(reprints,'  •  ') end
 if short and notice.Text~='' then objective.Visible=false end
 local station=nearbyInteraction()
 contextAction=nil;context.Visible=false
 if station and not modal.Visible then
  local action,title,detail,actionText=stationAction(station)
  if action then contextAction=function() performStation(station) end;contextTitle.Text=title;contextDetail.Text=detail;contextButton.Text=(actionText or 'Use')..(touch and '' or ' [E]');context.Visible=true end
 elseif not modal.Visible then
  local hr=ownerRoot();local nearest,best=nil,46
  local fields=world:FindFirstChild('Fields')
  if hr and fields then
   for _,field in ipairs(fields:GetChildren()) do
    local floor=field:FindFirstChild('FieldFloor') or field:FindFirstChildWhichIsA('BasePart')
    if floor then local n=(floor.Position-hr.Position).Magnitude;if n<best then nearest=field;best=n end end
   end
  end
  if nearest then
   local id=nearest:GetAttribute('FieldId') or nearest:GetAttribute('Tier')
   if id then
    contextAction=function() command:FireServer('Patch',id) end;contextTitle.Text=nearest:GetAttribute('DisplayName') or nearest.Name
    local phase=nearest:GetAttribute('Phase') or 'Safe'
    local actionText=(phase=='Guarded' or phase=='Active') and 'Fight' or (phase=='Gathering' and 'Join' or 'Mine')
    contextDetail.Text=(phase=='Active' and 'Sentries engaged. Starting crew only.') or (phase=='Guarded' and 'Defeat the sentries to unlock mining') or (phase=='Gathering' and 'Fleet gathering. Join before the fight.') or 'Send your fleet to gather minerals'
    contextButton.Text=actionText..(touch and '' or ' [E]');context.Visible=true
   end
  end
 end
 local hr=ownerRoot();local nearestEnemy,dist=nil,65
 if hr then
  for turret in pairs(turrets) do
   if turret.Parent then
    local hp=turret:GetAttribute('HP') or 0;local rootPart=turret.PrimaryPart or turret:FindFirstChildWhichIsA('BasePart',true)
    local n=rootPart and (rootPart.Position-hr.Position).Magnitude or math.huge
    if hp>0 and n<dist then nearestEnemy=turret;dist=n end
   end
  end
 end
 enemyHUD.Visible=nearestEnemy~=nil and ownActive and not modal.Visible
 if nearestEnemy then
  local hp=nearestEnemy:GetAttribute('HP') or 0;local maxHP=nearestEnemy:GetAttribute('MaxHP') or 1
  local charging=nearestEnemy:GetAttribute('Telegraph')
  enemyFill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,maxHP),0,1),1)
  enemyTitle.Text=charging and (touch and 'CHARGING  /  TAP EVADE' or 'CHARGING  /  EVADE [Q]') or string.format('PYRAMID SENTRY  %d / %d',math.ceil(hp),maxHP)
  enemyTitle.TextColor3=charging and palette.accent or palette.text
 end
end)
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),refreshModal)
connect(gui.Destroying,function()
 presentation:destroy()
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,c in pairs(observed) do c:Disconnect() end
 for part in pairs(hiddenParts) do if part.Parent then part.LocalTransparencyModifier=0 end end
 localFX:Destroy()
end)
