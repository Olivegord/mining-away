-- Compact gadget controls and smooth, all-observer scrap-bot rendering.
-- Buttons send intent only. Targets, timing judgement, damage and rewards are server-owned.
local View={}
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local function enabled(profile,kind)
 if not profile or not profile.run then return false end
 local levels=profile.run.shopLevels or {}
 if (levels[kind=='Orbital' and 'cobalt_orbital' or 'violet_scrap'] or 0)>0 then return true end
 for _,drone in ipairs(profile.fleet or {}) do
  if drone.role==(kind=='Orbital' and 'Orbiter' or 'Scrapper') then return true end
 end
 return false
end
function View.start(options)
 local player=Players.LocalPlayer
 local U=options.interface;local root=options.parent
 local panel=U.panel(root,UDim2.fromOffset(16,160),UDim2.fromOffset(220,110),U.palette.panel,4)
 panel.Name='MiningGadgets';panel.Visible=false
 local state: any={cooldowns={}};local connections={};local dead=false;local lastSend=0
 local function connect(signal,fn) table.insert(connections,signal:Connect(fn)) end
 local function decode()
  local raw=player:GetAttribute('MA_Ability')
  if type(raw)=='string' then local ok,value=pcall(function() return Http:JSONDecode(raw) end);if ok and type(value)=='table' then state=value end end
 end
 decode();connect(player:GetAttributeChangedSignal('MA_Ability'),decode)
 local function nearestField()
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  local world=workspace:FindFirstChild('MiningAway');local fields=world and world:FindFirstChild('Fields')
  local best,id=math.huge,nil
  if hr and fields then for _,field in ipairs(fields:GetChildren()) do
   local floor=field:FindFirstChild('Field') or field:FindFirstChild('FieldFloor') or field:FindFirstChildWhichIsA('BasePart')
   if floor then local d=(floor.Position-hr.Position).Magnitude;if d<best then best=d;id=field:GetAttribute('FieldId') or field:GetAttribute('Tier') end end
  end end
  return best<=70 and id or nil
 end
 local function activate(kind)
  if options.hidden() or os.clock()-lastSend<.15 then return end
  local profile=options.profile();if not enabled(profile,kind) or profile.pendingTransaction then return end
  local charge=state.runId==profile.run.id and state.charge or nil
  local fieldId=nearestField();if not fieldId then return end
  lastSend=os.clock()
  options.command:FireServer('MiningAbility',{op=charge and 'confirm' or 'begin',kind=kind,fieldId=fieldId,
   token=charge and charge.token or nil,runId=profile.run.id})
 end
 local orbital=U.button(panel,UDim2.fromOffset(8,7),UDim2.fromOffset(98,42),'Orbital [G]',function() activate('Orbital') end,U.palette.accent)
 orbital.Name='OrbitalGadget';orbital.TextSize=16
 local scrap=U.button(panel,UDim2.fromOffset(114,7),UDim2.fromOffset(98,42),'Scrap [B]',function() activate('Scrap') end,U.palette.mineral)
 scrap.Name='ScrapGadget';scrap.TextSize=16
 local hint=U.text(panel,UDim2.fromOffset(8,53),UDim2.fromOffset(204,32),'',16,U.palette.ink,false)
 hint.Name='GadgetTimingHint';hint.TextXAlignment=Enum.TextXAlignment.Center
 local track=U.frame(panel,UDim2.fromOffset(8,90),UDim2.fromOffset(204,12),U.palette.paper)
 track.Name='TimingTrack';track.Visible=false
 local sweet=U.frame(track,UDim2.fromScale(.28,0),UDim2.fromScale(.2,1),Color3.fromRGB(90,164,98))
 sweet.Name='PrecisionWindow'
 local cursor=U.frame(track,UDim2.fromScale(0,0),UDim2.new(0,3,1,0),U.palette.ink);cursor.Name='TimingCursor'
 connect(UIS.InputBegan,function(input,processed)
  if processed or UIS:GetFocusedTextBox() then return end
  if input.KeyCode==Enum.KeyCode.G then activate('Orbital') elseif input.KeyCode==Enum.KeyCode.B then activate('Scrap') end
 end)
 -- Sources remain on the server; local clones interpolate each complete pose.
 local visualRoot=Instance.new('Folder');visualRoot.Name='ScrapBotPresentation';visualRoot.Parent=workspace
 local bots={}
 local function remove(source,record)
  record.view:Destroy();record.beam:Destroy();record.core:Destroy();bots[source]=nil
  if source.Parent then for _,part in ipairs(source:GetDescendants()) do if part:IsA('BasePart') then part.LocalTransparencyModifier=0 end end end
 end
 local function observe(source)
  if bots[source] or not source:IsA('Model') or source:GetAttribute('ScrapBot')~=true then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='LocalScrapBot'
  for _,part in ipairs(source:GetDescendants()) do if part:IsA('BasePart') then part.LocalTransparencyModifier=1 end end
  for _,part in ipairs(view:GetDescendants()) do if part:IsA('BasePart') then part.LocalTransparencyModifier=0;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end end
  view.Parent=visualRoot;view:PivotTo(CFrame.new(position))
  local function beam(width,color)
   local part=Instance.new('Part');part.Name='TinyScrapLaser';part.Shape=Enum.PartType.Cylinder
   part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
   part.Material=Enum.Material.Neon;part.Color=color;part.Transparency=1;part.Size=Vector3.new(.01,width,width);part.Parent=visualRoot;return part
  end
  bots[source]={view=view,pos=position,beam=beam(.16,Color3.fromRGB(171,221,133)),core=beam(.05,Color3.fromRGB(237,255,206)),alpha=0,yaw=0}
 end
 local function scan()
  local folder=workspace:FindFirstChild('DroneRoleServerEffects')
  if folder then for _,group in ipairs(folder:GetChildren()) do if group:GetAttribute('ScrapSwarm') then for _,source in ipairs(group:GetChildren()) do observe(source) end end end end
 end
 local scanAt=0;local nearby=false
 connect(RunService.RenderStepped,function(dt)
  if dead then return end
  local now=workspace:GetServerTimeNow();local profile=options.profile()
  local hasOrbital,hasScrap=enabled(profile,'Orbital'),enabled(profile,'Scrap')
  panel.Visible=(hasOrbital or hasScrap) and nearby and not options.hidden()
  -- Keep below the existing objective while respecting a narrow safe rectangle.
  local short=root.AbsoluteSize.Y<390
  local x=short and math.max(0,(root.AbsoluteSize.X-220)/2) or math.min(16,math.max(0,root.AbsoluteSize.X-220))
  panel.Position=UDim2.fromOffset(x,short and (root.AbsoluteSize.X>=740 and 12 or 76) or 160)
  local charge=profile and state.runId==profile.run.id and state.charge or nil
  local function paint(button,kind,unlocked,key)
   button.Visible=unlocked
   local remaining=math.max(0,math.ceil(((state.cooldowns or {})[kind] or 0)-now))
   local charging=charge and charge.kind==kind
   local busy=profile and profile.pendingTransaction
   U.setEnabled(button,unlocked and not busy and (charging or remaining==0) and not (charge and not charging))
   button.Text=busy and 'Saving…' or charging and 'TAP!' or remaining>0 and (kind..' '..remaining..'s') or (kind..(UIS.TouchEnabled and '' or ' ['..key..']'))
  end
  paint(orbital,'Orbital',hasOrbital,'G');paint(scrap,'Scrap',hasScrap,'B')
  track.Visible=charge~=nil
  if charge then
   hint.Text=charge.kind=='Orbital' and 'Green: crack a nearby rock' or 'Green: launch 2 extra bots'
   local span=math.max(.01,charge.expires-charge.started)
   sweet.Position=UDim2.fromScale((charge.sweetStart-charge.started)/span,0)
   sweet.Size=UDim2.fromScale((charge.sweetEnd-charge.sweetStart)/span,1)
   cursor.Position=UDim2.new(math.clamp((now-charge.started)/span,0,1),-1,0,0)
  elseif (state.swarmUntil or 0)>now then hint.Text='Scrap swarm · '..math.ceil(state.swarmUntil-now)..'s'
  else hint.Text='Charge, then tap in green' end
  if now>=scanAt then scanAt=now+.2;nearby=nearestField()~=nil;scan() end
  for source,record in pairs(bots) do
   if not source.Parent or not source.Parent.Parent or now>=(source.Parent:GetAttribute('Expires') or 0) then remove(source,record)
   else
    local position=source:GetAttribute('Position') or record.pos
    local target=source:GetAttribute('TargetPosition') or position
    local delta=position-record.pos;local alpha=1-math.exp(-math.min(dt,.1)*16)
    record.pos=record.pos:Lerp(position,alpha)
    if delta.X*delta.X+delta.Z*delta.Z>.001 then
     local yaw=math.atan2(-delta.X,-delta.Z);local diff=(yaw-record.yaw+math.pi)%(2*math.pi)-math.pi
     record.yaw+=diff*(1-math.exp(-math.min(dt,.1)*8))
    end
    record.view:PivotTo(CFrame.new(record.pos)*CFrame.Angles(0,record.yaw,0))
    local active=source:GetAttribute('Active')==true
    record.alpha+=( (active and 1 or 0)-record.alpha)*(1-math.exp(-math.min(dt,.1)*22))
    -- A tiny laser remains vertical even while a bot settles into place.
    local height=math.max(.01,record.pos.Y-target.Y)
    local beamPose=CFrame.new(record.pos.X,record.pos.Y-height*.5,record.pos.Z)*CFrame.Angles(0,0,math.pi/2)
    for index,beam in ipairs({record.beam,record.core}) do
     local width=index==1 and .16 or .05;beam.Size=Vector3.new(height,width*math.max(.01,record.alpha),width*math.max(.01,record.alpha))
     beam.CFrame=beamPose;beam.Transparency=1-record.alpha*(index==1 and .35 or .8)
    end
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
