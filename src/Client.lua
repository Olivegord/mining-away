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
local drones,resources,resourceIndex,turrets,connections={},{},{},{},{}
local hiddenParts={}
local pendingDroneSources={}
local templateRetryQueued=false
local profile=nil
local colors={Blue=Color3.fromRGB(99,198,246),Red=Color3.fromRGB(243,117,112),Green=Color3.fromRGB(122,219,163)}
local palette={ink=Color3.fromRGB(18,27,35),muted=Color3.fromRGB(167,188,194),text=Color3.fromRGB(240,247,239),accent=Color3.fromRGB(154,224,174),line=Color3.fromRGB(58,80,82)}
local gui=Instance.new('ScreenGui');gui.Name='MiningAwayHUD';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=player:WaitForChild('PlayerGui')
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
local function corner(parent,r) local x=Instance.new('UICorner');x.CornerRadius=UDim.new(0,r or 10);x.Parent=parent end
local function stroke(parent,color) local x=Instance.new('UIStroke');x.Color=color or palette.line;x.Thickness=1;x.Parent=parent;return x end
local function frame(parent,pos,size,color)
 local f=Instance.new('Frame');f.Position=pos;f.Size=size;f.BackgroundColor3=color or palette.ink;f.BorderSizePixel=0;f.Parent=parent;return f
end
local function label(parent,pos,size,text,sizePx,color,bold)
 local t=Instance.new('TextLabel');t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.Text=text or '';t.TextColor3=color or palette.text;t.TextSize=sizePx or 14;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Center;t.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;t.TextWrapped=true;t.Parent=parent;return t
end
local function button(parent,pos,size,text,callback,color)
 local b=Instance.new('TextButton');b.Position=pos;b.Size=size;b.Text=text;b.TextColor3=palette.ink;b.BackgroundColor3=color or palette.accent;b.BorderSizePixel=0;b.Font=Enum.Font.GothamBold;b.TextSize=14;b.AutoButtonColor=true;b.Parent=parent;corner(b,7)
 b.Activated:Connect(callback);return b
end
local hud=frame(gui,UDim2.fromOffset(18,18),UDim2.fromOffset(310,102));corner(hud);stroke(hud)
label(hud,UDim2.fromOffset(14,8),UDim2.fromOffset(150,18),'MINING AWAY',11,palette.muted,true)
local saveLabel=label(hud,UDim2.new(1,-110,0,8),UDim2.fromOffset(96,18),'Loading',10,palette.muted);saveLabel.TextXAlignment=Enum.TextXAlignment.Right
local creditsLabel=label(hud,UDim2.fromOffset(14,28),UDim2.fromOffset(174,26),'— credits',21,nil,true)
local fleetButton=button(hud,UDim2.new(1,-99,0,29),UDim2.fromOffset(85,25),'1 drone',function() end,Color3.fromRGB(55,81,85));fleetButton.TextColor3=palette.text;fleetButton.TextSize=12
local cargoText=label(hud,UDim2.fromOffset(14,59),UDim2.new(1,-28,0,17),'Cargo 0 / 120',11,palette.muted)
local cargoTrack=frame(hud,UDim2.fromOffset(14,83),UDim2.new(1,-28,0,4),palette.line);corner(cargoTrack,2)
local cargoFill=frame(cargoTrack,UDim2.fromScale(0,0),UDim2.fromScale(0,1),palette.accent);corner(cargoFill,2)
local objective=label(gui,UDim2.fromOffset(23,128),UDim2.fromOffset(310,36),'Mine a nearby field. Return to the Converter to sell.',12,palette.text)
local notice=label(gui,UDim2.new(.5,-220,0,28),UDim2.fromOffset(440,42),'',14,palette.text,true);notice.TextXAlignment=Enum.TextXAlignment.Center
local recall=button(gui,UDim2.new(1,-116,1,-61),UDim2.fromOffset(98,36),'Recall  R',function() command:FireServer('Recall') end,Color3.fromRGB(36,54,60));recall.TextColor3=palette.text
local context=frame(gui,UDim2.new(.5,-168,1,-78),UDim2.fromOffset(336,57));corner(context);stroke(context);context.Visible=false
local contextTitle=label(context,UDim2.fromOffset(12,7),UDim2.new(1,-114,0,19),'',14,nil,true)
local contextDetail=label(context,UDim2.fromOffset(12,28),UDim2.new(1,-114,0,24),'',11,palette.muted)
local contextAction=nil
button(context,UDim2.new(1,-96,0,11),UDim2.fromOffset(84,34),'Use  E',function() if contextAction then contextAction() end end)
local modal=frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(0,0,0));modal.BackgroundTransparency=.35;modal.Visible=false;modal.ZIndex=10
local sheet=frame(modal,UDim2.new(.5,-445,.5,-184),UDim2.fromOffset(890,368));sheet.ZIndex=11;corner(sheet,14);stroke(sheet)
local modalTitle=label(sheet,UDim2.fromOffset(24,19),UDim2.new(1,-86,0,27),'Choose your run',22,nil,true)
local modalSubtitle=label(sheet,UDim2.fromOffset(24,49),UDim2.new(1,-48,0,24),'Three choices. Keep one. Every modifier ends at prestige.',12,palette.muted)
local close=button(sheet,UDim2.new(1,-53,0,18),UDim2.fromOffset(30,28),'×',function() modal.Visible=false end,Color3.fromRGB(45,62,68));close.TextColor3=palette.text;close.TextSize=22
local body=Instance.new('ScrollingFrame');body.Position=UDim2.fromOffset(24,88);body.Size=UDim2.new(1,-48,1,-108);body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=3;body.ScrollBarImageColor3=palette.muted;body.CanvasSize=UDim2.fromScale(0,0);body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.Parent=sheet
local modalMode=nil
local function clearBody() for _,x in ipairs(body:GetChildren()) do x:Destroy() end end
local function tx() return Http:GenerateGUID(false) end
local function send(action,data)
 if not profile or not profile.run then return end
 data=data or {};data.txId=tx();data.runId=profile.run.id;command:FireServer(action,data)
end
local function comma(n) local s=tostring(math.floor(tonumber(n) or 0));local r=s:reverse():gsub('(%d%d%d)','%1,'):reverse();return r:gsub('^,','') end
local function cargoUnits(p) local n=0;for _,v in pairs((p.run and p.run.cargo) or {}) do if type(v)=='number' then n=n+v end end;return n end
local function pending() return profile and profile.run and profile.run.pendingOffer end
local function viewport()
 local camera=workspace.CurrentCamera;return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function layoutModal()
 local v=viewport();local mobile=v.X<720
 local width=math.min(890,math.max(280,v.X-32));local height=mobile and math.min(620,v.Y-48) or math.min(384,v.Y-48)
 sheet.Size=UDim2.fromOffset(width,height);sheet.Position=UDim2.new(.5,-width/2,.5,-height/2)
 return mobile,width
end
local openOffer
local function previewLines(choice)
 local result={}
 for _,item in ipairs(choice.preview or {}) do
  if type(item)=='table' then
   local before=tonumber(item.before);local after=tonumber(item.after)
   if before and after then table.insert(result,string.format('%s  %.2g → %.2g%s',item.label or 'Effect',before,after,item.unit or '')) end
  end
 end
 return table.concat(result,'\n')
end
openOffer=function()
 local offer=pending();if not offer or not offer.choices then return end
 modalMode='offer';clearBody();modalTitle.Text='Choose one modifier';modalSubtitle.Text='This paid offer is saved. Closing or rejoining will keep the same choices.'
 local mobile,width=layoutModal();local cardWidth=mobile and width-48 or (width-72)/3
 local list=Instance.new('UIListLayout');list.FillDirection=mobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal;list.Padding=UDim.new(0,12);list.Parent=body
 for index,choice in ipairs(offer.choices) do
  local card=frame(body,UDim2.fromOffset(0,0),UDim2.fromOffset(cardWidth,248),Color3.fromRGB(29,44,49));corner(card,9);stroke(card)
  local tint=colors[choice.type] or palette.accent
  local rule=frame(card,UDim2.fromOffset(12,13),UDim2.fromOffset(25,3),tint);corner(rule,2)
  label(card,UDim2.fromOffset(12,25),UDim2.new(1,-24,0,39),choice.title or choice.cardId,17,nil,true)
  local target=choice.targetName and (choice.targetName..' • '..tostring(choice.targetDroneId)) or (choice.type and ('All '..choice.type..' drones') or (choice.scope=='Player' and 'Your cargo hold' or 'Your fleet'))
  label(card,UDim2.fromOffset(12,67),UDim2.new(1,-24,0,28),target,11,tint,true)
  local effect=label(card,UDim2.fromOffset(12,102),UDim2.new(1,-24,0,58),choice.description or 'Run modifier',13);effect.TextYAlignment=Enum.TextYAlignment.Top
  local preview=label(card,UDim2.fromOffset(12,165),UDim2.new(1,-24,0,31),previewLines(choice),10,palette.muted);preview.TextYAlignment=Enum.TextYAlignment.Top
  label(card,UDim2.fromOffset(12,211),UDim2.fromOffset(85,22),'THIS RUN',9,palette.muted,true)
  local choose
  choose=button(card,UDim2.new(1,-112,1,-42),UDim2.fromOffset(100,30),'Choose',function()
   if not pending() or pending().id~=offer.id then return end
   choose.Text='Saving…';choose.Active=false
   send('ChooseCard',{offerId=offer.id,index=index})
  end,tint)
 end
 modal.Visible=true
end
local function openPack()
 if pending() then openOffer();return end
 modalMode='pack';clearBody();layoutModal();modalTitle.Text='Build this run';modalSubtitle.Text='Spend earned credits. Three eligible cards; choose exactly one.'
 label(body,UDim2.fromOffset(0,0),UDim2.new(1,0,0,54),'A stronger laser, a faster Scout, or a tougher fighter?\nEach pack is a different direction for your current fleet.',16)
 local price=profile and (profile.nextPackPrice or profile.packPrice) or 80
 label(body,UDim2.fromOffset(0,73),UDim2.new(1,0,0,34),comma(price)..' credits',26,palette.accent,true)
 label(body,UDim2.fromOffset(0,116),UDim2.new(1,0,0,40),'Choices and individual drone targets are saved before you see them. No paid rerolls.',12,palette.muted)
 button(body,UDim2.fromOffset(0,177),UDim2.fromOffset(182,39),'Open pack',function() send('BuyPack',{packIndex=profile.run.packIndex,expectedPackIndex=profile.run.packIndex}) end)
 modal.Visible=true
end
local function openPrestige()
 if not profile then return end
 modalMode='prestige';clearBody();local mobile=layoutModal();modalTitle.Text='Begin a new expedition'
 local pre=profile.prestigePreview or profile.prestige or {}
 local before=pre.fleetBefore or #profile.fleet
 local after=pre.fleetAfter or before+1
 modalSubtitle.Text=string.format('Keep %d permanent %s. Add one %s drone.',before,before==1 and 'drone' or 'drones',pre.newType or 'permanent')
 local can=pre.eligible==true and not pending()
 label(body,UDim2.fromOffset(0,0),UDim2.new(1,0,0,35),string.format('%d → %d permanent drones',before,after),26,palette.accent,true)
 label(body,UDim2.fromOffset(0,50),UDim2.new(1,0,0,mobile and 105 or 60),string.format('Reset %d run cards, %s credits and %d cargo, plus pack prices, sale progress and your clearances. Keep every existing permanent drone and built-in trait.',pre.cards or #(profile.run.cards or {}),comma(profile.run.credits),cargoUnits(profile)),14)
 local progress=pre.reason or (comma(pre.earnings or profile.run.saleEarnings)..' / '..comma(pre.saleRequired or 2000)..' run sale earnings')
 if pending() then progress='Choose your paid pack card before prestiging.' end
 label(body,UDim2.fromOffset(0,mobile and 170 or 122),UDim2.new(1,0,0,40),progress,12,palette.muted)
 local confirm=button(body,UDim2.fromOffset(0,mobile and 240 or 183),UDim2.fromOffset(230,39),can and 'Confirm prestige +1 drone' or 'Milestone not complete',function()
  if can then send('Prestige',{confirm=true});modal.Visible=false end
 end,can and palette.accent or palette.line);confirm.Active=can
 modal.Visible=true
end
local function openFleet()
 if not profile then return end
 modalMode='fleet';clearBody();layoutModal();modalTitle.Text='Your permanent fleet';modalSubtitle.Text='Built-in traits persist. Card effects expire when you prestige.'
 local y=0
 for _,d in ipairs(profile.fleet or {}) do
  local stats=d.effective or (profile.droneStats and profile.droneStats[d.id]) or d.base or {}
  local row=frame(body,UDim2.fromOffset(0,y),UDim2.new(1,-4,0,94),Color3.fromRGB(29,44,49));corner(row,8)
  label(row,UDim2.fromOffset(12,8),UDim2.new(1,-24,0,22),(d.name or d.id)..'  /  '..(d.type or 'Blue'),15,colors[d.type] or palette.accent,true)
  label(row,UDim2.fromOffset(12,31),UDim2.new(1,-24,0,18),'Permanent ID '..tostring(d.id),10,palette.muted)
  label(row,UDim2.fromOffset(12,54),UDim2.new(1,-24,0,30),string.format('Mine %.1f   •   Combat %.1f   •   Hull %.0f   •   Startup %.2fs',stats.miningDPS or stats.mining or 30,stats.combatDPS or stats.combat or 8,stats.maxHealth or stats.maxHP or stats.health or 80,stats.warmup or stats.startup or 2),11,palette.text)
  y=y+106
 end
 modal.Visible=true
end
fleetButton.Activated:Connect(openFleet)
local lastOffer=nil
local function readProfile()
 local raw=player:GetAttribute('MA_Profile');if type(raw)~='string' then return end
 local ok,p=pcall(function() return Http:JSONDecode(raw) end);if not ok or type(p)~='table' then return end
 profile=p
 local offer=pending()
 if offer and offer.id~=lastOffer then lastOffer=offer.id;openOffer()
 elseif not offer and modalMode=='offer' then modal.Visible=false;modalMode=nil end
end
connect(player:GetAttributeChangedSignal('MA_Profile'),readProfile);readProfile()
local noticeUntil=0
connect(player:GetAttributeChangedSignal('MA_Notice'),function() notice.Text=tostring(player:GetAttribute('MA_Notice') or '');noticeUntil=os.clock()+5;if modal.Visible and modalMode=='offer' and pending() then openOffer() end end)

local sparkCount=0
local function sparkBurst(pos,color,amount)
 for _=1,math.min(amount,math.max(0,48-sparkCount)) do
  sparkCount=sparkCount+1
  local p=Instance.new('Part');p.Name='MineralChip';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Size=Vector3.new(.14,.14,.3);p.Material=Enum.Material.Neon;p.Color=color;p.Position=pos;p.Parent=localFX
  TweenService:Create(p,TweenInfo.new(.35),{Position=pos+Vector3.new(math.random(-4,4),math.random(2,5),math.random(-4,4)),Transparency=1,Size=Vector3.new(.03,.03,.03)}):Play()
  task.delay(.4,function() p:Destroy();sparkCount=sparkCount-1 end)
 end
end
local function safeSound(name,parent)
 local template=RS:FindFirstChild(name,true)
 if not template or not template:IsA('Sound') then return end
 local sound=template:Clone();sound.TimePosition=0;sound.Parent=parent;sound:Play();Debris:AddItem(sound,8)
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
 return {model=beamModel,origin=anchor,endpoint=endpoint,beams=beams,impact=impact,width=0,view=view,active=false,particleClock=0}
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
 if typeColor then pivot.Color=pivot.Color:Lerp(typeColor,.25) end
 hideModel(source)
 local parts={};for _,p in ipairs(clone:GetDescendants()) do if p:IsA('BasePart') then parts[p]=p.Transparency end end
 local d={source=source,view=clone,pos=pos,yaw=source:GetAttribute('Yaw') or 0,life=source:GetAttribute('Life'),parts=parts,lastState=source:GetAttribute('State'),beam=createBeam(clone,emitter)}
 drones[source]=d
 clone:PivotTo(CFrame.new(pos)*CFrame.Angles(0,d.yaw,0))
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
 local eye=source:FindFirstChild('eye',true) or source.PrimaryPart
 if not eye or not eye:IsA('BasePart') then return end
 local endpoint=localPart(localFX,'SentryAim',eye.Position)
 local a=Instance.new('Attachment');a.Name='ChargeOrigin';a.Parent=eye
 local b=Instance.new('Attachment');b.Parent=endpoint
 local template=RS:FindFirstChild('MiningFX');template=template and template:FindFirstChild('Beam');template=template and template:FindFirstChild('InnerBeam',true)
 local beam=template and template:Clone() or Instance.new('Beam');beam.Name='SentryTelegraph';beam.FaceCamera=true;beam.Color=ColorSequence.new(colors.Red);beam.Transparency=NumberSequence.new(.45);beam.Attachment0=a;beam.Attachment1=b;beam.Enabled=false;beam.LightEmission=1;beam.Parent=localFX
 local accents={};local parts={}
 for _,part in ipairs(source:GetDescendants()) do if part:IsA('BasePart') then parts[part]=true end end
 for _,name in ipairs({'eye','spawnEye'}) do local part=source:FindFirstChild(name,true);if part and part:IsA('BasePart') then accents[part]=part.Color end end
 turrets[source]={source=source,eye=eye,endpoint=endpoint,attachment=a,beam=beam,accents=accents,parts=parts,serial=source:GetAttribute('ShotSerial') or 0,dead=source:GetAttribute('Dead')==true,flashUntil=0}
end
local observed={}
local function observe(source)
 if not source.Parent then return end
 if source:IsA('BasePart') then
  local ancestor=source.Parent
  while ancestor and ancestor~=world do
   if ancestor:IsA('Model') then
    if ancestor:GetAttribute('DroneId') then registerDrone(ancestor);hidePart(source) end
    if ancestor:GetAttribute('Turret') then registerTurret(ancestor);if turrets[ancestor] then
     turrets[ancestor].parts[source]=true
     if source.Name=='eye' or source.Name=='spawnEye' then turrets[ancestor].accents[source]=source.Color end
    end end
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
 d.view:Destroy();d.beam.model:Destroy();d.beam.endpoint:Destroy()
end
connect(world.DescendantRemoving,function(source)
 pendingDroneSources[source]=nil
 if drones[source] then destroyDrone(drones[source]);drones[source]=nil end
 if resources[source] then resourceIndex[resources[source].id]=nil;resources[source].view:Destroy();resources[source]=nil end
 if turrets[source] then local t=turrets[source];t.endpoint:Destroy();t.attachment:Destroy();t.beam:Destroy();turrets[source]=nil end
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
 if event=='stage' then safeSound('RockCrack',view);sparkBurst(view.Position,r.baseColor,2)
 elseif event=='break' then safeSound('RockBreak',view);sparkBurst(view.Position,r.baseColor,8) end
end
local function renderDrone(d,dt,now)
 local s=d.source;local state=s:GetAttribute('State') or 'Follow'
 local logical=s:GetAttribute('Position');local goal=s:GetAttribute('Goal') or logical
 if typeof(logical)~='Vector3' or typeof(goal)~='Vector3' then return end
 if state=='Destroyed' and d.lastState~='Destroyed' and d.lastState~='Reprinting' then sparkBurst(d.pos,Color3.fromRGB(132,219,235),6) end
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
 beam.particleClock=beam.particleClock+dt
 if active and beam.particleClock>.08 then beam.impact:Emit(1);beam.particleClock=0 end
end
local function renderTurret(t,now)
 local source=t.source
 local serial=source:GetAttribute('ShotSerial') or 0
 local aim=source:GetAttribute('Aim')
 local dead=source:GetAttribute('Dead')==true or (source:GetAttribute('HP') or 0)<=0
 if dead and not t.dead then sparkBurst(t.eye.Position,colors.Red,8) end
 t.dead=dead
 for part in pairs(t.parts) do if part.Parent then part.LocalTransparencyModifier=dead and .78 or 0 else t.parts[part]=nil end end
 local charging=source:GetAttribute('Telegraph')==true and not dead
 if typeof(aim)=='Vector3' then t.endpoint.Position=aim end
 if serial>t.serial then t.serial=serial;t.flashUntil=now+.13;if typeof(aim)=='Vector3' then sparkBurst(aim,colors.Red,4) end end
 local firing=now<t.flashUntil
 t.beam.Enabled=(charging or firing) and typeof(aim)=='Vector3'
 t.beam.Width0=firing and .22 or .035;t.beam.Width1=firing and .3 or .035
 local fireAt=source:GetAttribute('FireAt') or now
 local charge=charging and math.clamp(1-(fireAt-now)/.8,0,1) or 0
 for part,baseColor in pairs(t.accents) do part.Color=dead and Color3.fromRGB(49,53,58) or (firing and Color3.new(1,1,1) or baseColor:Lerp(Color3.new(1,.75,.65),charge*.8)) end
end
connect(RunService.RenderStepped,function(dt)
 local now=workspace:GetServerTimeNow()
 for _,r in pairs(resources) do renderResource(r,now) end
 for _,d in pairs(drones) do renderDrone(d,dt,now) end
 for _,t in pairs(turrets) do renderTurret(t,now) end
end)

local evade=button(gui,UDim2.new(1,-116,1,-105),UDim2.fromOffset(98,36),'Evade  Q',function() command:FireServer('Evade') end,Color3.fromRGB(111,66,65));evade.TextColor3=palette.text;evade.Visible=false
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
   local v=map:FindFirstChild(name)
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
 if kind=='Pack' then return openPack,'Card machine','Open a pack or resolve your saved choice'
 elseif kind=='Prestige' then return openPrestige,'Prestige beacon','Keep your fleet. Begin a new run.'
 elseif kind=='Sell' then return function() command:FireServer('Sell') end,'Converter','Sell carried minerals for run credits'
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
connect(mouse.Button1Down,function() assignField(mouse.Target) end)
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
 local view=viewport();local small=view.X<720
 local hudWidth=math.min(310,math.max(220,view.X-36))
 hud.Size=UDim2.fromOffset(hudWidth,102)
 creditsLabel.Size=UDim2.fromOffset(math.max(90,hudWidth-128),26)
 creditsLabel.TextSize=hudWidth<300 and 18 or 21
 objective.Size=UDim2.fromOffset(math.max(220,view.X<360 and view.X-46 or 310),42)
 local contextWidth=math.min(336,math.max(220,view.X-32))
 context.Size=UDim2.fromOffset(contextWidth,57);context.Position=UDim2.new(.5,-contextWidth/2,1,small and -135 or -78)
 local noticeWidth=math.min(440,math.max(220,view.X-32))
 notice.Size=UDim2.fromOffset(noticeWidth,48);notice.Position=UDim2.new(.5,-noticeWidth/2,0,small and 176 or 28)
 if small then enemyHUD.Position=UDim2.new(.5,-135,0,230) else enemyHUD.Position=UDim2.new(.5,-135,0,17) end
 if os.clock()>noticeUntil then notice.Text='' end
 local status=tostring(player:GetAttribute('MA_SaveStatus') or 'Loading')
 saveLabel.Text=status:lower():find('preview') and 'PREVIEW • NOT SAVED' or (status:lower():find('saved') and 'SAVED' or 'SAVE PAUSED')
 saveLabel.TextColor3=status:lower():find('preview') and Color3.fromRGB(237,201,127) or palette.muted
 if profile and profile.run then
  local amount=cargoUnits(profile);local capacity=profile.capacity or 120
  creditsLabel.Text=comma(profile.run.credits)..' credits';fleetButton.Text=tostring(#(profile.fleet or {}))..(#(profile.fleet or {})==1 and ' drone' or ' drones')
  cargoText.Text=string.format('Cargo %d / %d   •   Run %d',amount,capacity,profile.run.index or 1)
  cargoFill.Size=UDim2.fromScale(math.clamp(amount/math.max(1,capacity),0,1),1)
  local pre=profile.prestigePreview
  if pending() then objective.Text='A paid pack is waiting. Visit the card machine to choose one modifier.'
  elseif pre and pre.eligible then objective.Text='Prestige ready. Visit the beacon for +1 permanent drone.'
  elseif pre then objective.Text=string.format('Prestige: %s / %s sale earnings • %s %d / %d',comma(pre.earnings or profile.run.saleEarnings),comma(pre.saleRequired),tostring(pre.field or 'Cobalt'),pre.wins or 0,pre.winsRequired or 1)
  else objective.Text='Mine → sell → choose run cards. Clear Cobalt to reach your first prestige.' end
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
 evade.Visible=ownActive and not modal.Visible
 if #reprints>0 and os.clock()>noticeUntil then notice.Text=#reprints>2 and tostring(#reprints)..' drones reprinting for free' or table.concat(reprints,'  •  ') end
 local station=nearbyInteraction()
 contextAction=nil;context.Visible=false
 if station and not modal.Visible then
  local action,title,detail=stationAction(station)
  if action then contextAction=function() performStation(station) end;contextTitle.Text=title;contextDetail.Text=detail;context.Visible=true end
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
    contextDetail.Text=(phase=='Active' and 'Assault locked • original crew only') or (phase=='Guarded' and 'Assign to challenge the sentries') or (phase=='Gathering' and 'Muster open • join this expedition') or 'Assign your fleet to this field'
    context.Visible=true
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
  enemyFill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,maxHP),0,1),1)
  enemyTitle.Text=nearestEnemy:GetAttribute('Telegraph') and 'SENTRY CHARGING  •  EVADE Q' or string.format('PYRAMID SENTRY  %d / %d',math.ceil(hp),maxHP)
 end
end)
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),function() if modal.Visible then layoutModal() end end)
connect(gui.Destroying,function()
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,c in pairs(observed) do c:Disconnect() end
 for part in pairs(hiddenParts) do if part.Parent then part.LocalTransparencyModifier=0 end end
 localFX:Destroy()
end)
