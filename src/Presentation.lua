-- Client-only authored-asset animation. No remotes, damage, rewards or simulation.
-- Feedback is bundled immediately before this module by tools/build.py.
local P={};P.__index=P
local F=Feedback
local S=SentryMotion
local ICE=Color3.fromRGB(126,241,221)
local HOT=Color3.fromRGB(255,179,102)
local WHITE=Color3.fromRGB(255,249,230)
local RUIN=Color3.fromRGB(34,61,67)
local segmentRanks={bottemseg=0,lowerseg=1,upperseg=2,topseg=3,eye=1,eyecase=1,spawnEye=1}
local requiredSegments={'bottemseg','lowerseg','upperseg','topseg','eye','eyecase','spawnEye'}
local function snapshot(source)
 return {state=source:GetAttribute('State'),life=source:GetAttribute('Life'),hp=source:GetAttribute('HP'),
  dead=source:GetAttribute('Dead'),serial=source:GetAttribute('ShotSerial') or 0}
end
local function passive(part)
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.LocalTransparencyModifier=0
end
local function clean(model)
 for _,object in ipairs(model:GetDescendants()) do
  if object:IsA('LuaSourceContainer') or object:IsA('BillboardGui') or object:IsA('SurfaceGui')
   or object:IsA('JointInstance') or object:IsA('WeldConstraint') or object:IsA('Constraint')
   or object:IsA('AnimationController') or object.Name=='AnimSaves' then object:Destroy()
  elseif object:IsA('BasePart') then passive(object)
  elseif object:IsA('Beam') or object:IsA('Trail') or object:IsA('ParticleEmitter') then object.Enabled=false end
 end
end
local function partsOf(model)
 local parts={};local pivot=model:GetPivot()
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA('BasePart') then
   table.insert(parts,{part=part,relative=pivot:ToObjectSpace(part.CFrame),frame=part.CFrame,
    color=part.Color,material=part.Material,transparency=part.Transparency,size=part.Size})
  end
 end
 table.sort(parts,function(a,b) return a.part.Name<b.part.Name end)
 return parts
end
local function barePart(parent,name)
 local part=Instance.new('Part');part.Name=name;passive(part);part.Material=Enum.Material.Neon
 part.CastShadow=false
 part.Parent=parent;return part
end
function P.new(options)
 assert(options and options.parent,'Presentation needs a local effect parent')
 return setmetatable({parent=options.parent,drones={},turrets={},fragments={},pulses={},scanCount=0,
  maxFragments=64,maxPulses=12,maxScans=16,closed=false},P)
end
function P:_pulse(position,color,size,now,duration)
 if self.closed or #self.pulses>=self.maxPulses then return end
 local part=barePart(self.parent,'ImpactPulse');part.Shape=Enum.PartType.Ball
 part.Size=Vector3.one*.1;part.Position=position;part.Color=color;part.Transparency=.4
 table.insert(self.pulses,{part=part,start=now,size=size,duration=duration or .2})
end
function P:_sound(position,kind,now)
 -- Roblox Studio's shipped sounds were verified locally; no external asset IDs.
 if #self.pulses>=self.maxPulses then return end
 local anchor=barePart(self.parent,'ImpactAudio');anchor.Size=Vector3.one*.05
 anchor.Position=position;anchor.Transparency=1
 local sound=Instance.new('Sound');sound.Name='CosmeticImpact'
 sound.SoundId=kind=='death' and 'rbxasset://sounds/impact_explosion_03.mp3' or 'rbxasset://sounds/action_jump_land.mp3'
 sound.Volume=kind=='death' and .28 or .12;sound.PlaybackSpeed=kind=='death' and 1.1 or 1.6
 sound.RollOffMinDistance=5;sound.RollOffMaxDistance=65;sound.Parent=anchor;sound:Play()
 -- The same bounded, frame-cleaned pool owns both pulse parts and audio anchors.
 table.insert(self.pulses,{part=anchor,start=now,size=0,duration=kind=='death' and 2.5 or 1,audio=true})
end
function P:_floor(position,exclude)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={self.parent,exclude}
 local result=workspace:Raycast(position+Vector3.new(0,1,0),Vector3.new(0,-100,0),params)
 return result and result.Position.Y or position.Y-9
end
function P:_fragment(template,frame,color,transparency,scale,velocity,spin,floor,now,duration,priority)
 if self.closed then return end
 if #self.fragments>=self.maxFragments then
  if not priority then return end
  -- A mineral shower cannot consume the space needed for a visible drone death.
  local replace=1
  for i,item in ipairs(self.fragments) do if not item.priority then replace=i;break end end
  self.fragments[replace].part:Destroy();table.remove(self.fragments,replace)
 end
 local part=template:Clone();if not part then return end
 -- Clone each real mesh once. Nested emitter parts and joints must not travel twice.
 for _,object in ipairs(part:GetDescendants()) do
  if object:IsA('BasePart') or object:IsA('LuaSourceContainer') or object:IsA('JointInstance')
   or object:IsA('Constraint') or object:IsA('WeldConstraint') or object:IsA('Beam')
   or object:IsA('Trail') or object:IsA('ParticleEmitter') or object:IsA('Sound')
   or object:IsA('BillboardGui') or object:IsA('SurfaceGui') then object:Destroy() end
 end
 passive(part);part.CastShadow=false;part.Name='AuthoredDebris';part.Size=part.Size*scale;part.CFrame=frame
 part.Color=color;part.Transparency=transparency;part.Parent=self.parent
 table.insert(self.fragments,{part=part,frame=frame,start=now,velocity=velocity,spin=spin,
  floor=floor+part.Size.Y*.3,transparency=transparency,duration=duration or 1.5,priority=priority})
end
function P:registerDrone(drone,now)
 if self.closed or self.drones[drone] then return end
 local current=snapshot(drone.source)
 if current.state==nil or current.hp==nil or current.life==nil then return end
 self.drones[drone]={events=F.new(current),parts=partsOf(drone.view),
  pose=drone.view:GetPivot(),hitAt=-100,shotAt=-100,repairSerial=drone.source:GetAttribute('RepairSerial') or 0,shield=drone.source:GetAttribute('Shield') or 0,scan=nil}
 -- Starting in Destroyed/Reprinting reconstructs that state; no previous death replay.
 self:renderDrone(drone,0,now)
end
function P:_droneDeath(drone,record,now)
 local origin=record.pose.Position;local floor=self:_floor(origin,drone.source)
 self:_pulse(origin,ICE,3.1,now,.18)
 self:_sound(origin,'death',now)
 local visible=0
 for _,item in ipairs(record.parts) do
  if item.transparency<.95 and visible<6 then
   visible=visible+1
   local angle=visible*2.4;local frame=record.pose*item.relative
   self:_fragment(item.part,frame,item.color,item.transparency,1,
    Vector3.new(math.cos(angle)*3.4,visible==1 and 1.3 or 3.5,math.sin(angle)*3.4),
    Vector3.new(visible%2==0 and -3.2 or 2.8,visible*.8,2.1),floor,now,1.65,true)
  end
 end
end
function P:_removeScan(record)
 if record.scan then record.scan:Destroy();record.scan=nil;self.scanCount=math.max(0,self.scanCount-1) end
end
function P:renderDrone(drone,_dt,now)
 local record=self.drones[drone]
 if not record then self:registerDrone(drone,now);return end
 if not drone.view.Parent then return end
 local source=drone.source;local state=source:GetAttribute('State') or 'Follow'
 local event=F.observe(record.events,snapshot(source))
 -- record.pose is the last rendered pre-destruction pose, before server reprint teleport.
 if event.died then self:_droneDeath(drone,record,now) end
 if event.hit then
  if now-record.hitAt>.22 then self:_sound(record.pose.Position,'hit',now) end
  record.hitAt=now
 end
 if event.shot then record.shotAt=now end
 local pose=drone.view:GetPivot()
 local repairs=source:GetAttribute('RepairSerial') or 0
 if repairs>record.repairSerial and not record.events.dead then self:_pulse(pose.Position,Color3.fromRGB(131,235,168),2.4,now,.3) end
 record.repairSerial=repairs
 local shield=source:GetAttribute('Shield') or 0
 if shield<record.shield-.001 and not record.events.dead then self:_pulse(pose.Position,ICE,2.8,now,.22) end
 record.shield=shield
 local hit=F.flash(now-record.hitAt,.16);local recoil=F.recoil(now-record.shotAt)
 local rebuilding=state=='Reprinting'
 if rebuilding then
  local ready=source:GetAttribute('ReprintAt') or now
  local progress,reveal=F.assembly(now,ready,2)
  if not record.scan and self.scanCount<self.maxScans then
   record.scan=barePart(self.parent,'ReconstructionScan');record.scan.Color=ICE
   record.scan.Size=Vector3.new(2.55,.045,2.55);self.scanCount=self.scanCount+1
  end
  if record.scan then
   record.scan.CFrame=CFrame.new(pose.Position+Vector3.new(0,-1.25+progress*2.5,0))*CFrame.Angles(0,progress*math.pi*.5,0)
   record.scan.Transparency=.45+reveal*.35
  end
  for _,item in ipairs(record.parts) do
   if item.part.Parent then
    item.part.Transparency=math.max(item.transparency,.88*(1-reveal))
    item.part.Color=item.color:Lerp(ICE,(1-reveal)*.45)
   end
  end
  drone.view:PivotTo(pose*CFrame.new(0,(1-reveal)*.35,0))
 else
  self:_removeScan(record)
  for _,item in ipairs(record.parts) do
   if item.part.Parent then
    item.part.Color=item.color:Lerp(WHITE,hit*.78)
    -- HP can replicate one frame before State. Never leave a dead body at the printer.
    item.part.Transparency=record.events.dead and 1 or item.transparency
   end
  end
  if not record.events.dead and (hit>0 or recoil>0) then
   drone.view:PivotTo(pose*CFrame.new(0,hit*.045,recoil*.12))
  end
 end
 if event.revived then self:_pulse(pose.Position,ICE,2.35,now,.28) end
 if event.shot and not record.events.dead then
  local emitter=drone.view:FindFirstChild('Emmiter',true)
  if emitter and emitter:IsA('BasePart') then
   local critical=source:GetAttribute('Critical')==true or now-(source:GetAttribute('LastCritAt') or -100)<.15
   self:_pulse(emitter.Position,critical and HOT or ICE,critical and 1.25 or .65,now,.13)
  end
 end
 if not record.events.dead then record.pose=pose end
end
function P:destroyDrone(drone)
 local record=self.drones[drone]
 if record then self:_removeScan(record);self.drones[drone]=nil end
end
function P:_sentryAudio(position,kind,now)
 if #self.pulses>=self.maxPulses then return end
 local anchor=barePart(self.parent,'SentryAudio');anchor.Transparency=1;anchor.Position=position
 local sound=Instance.new('Sound');sound.Name=kind=='impact' and 'StoneSlabThud' or 'SentryIgnition'
 sound.SoundId=kind=='wake' and 'rbxasset://sounds/action_get_up.mp3' or 'rbxasset://sounds/impact_explosion_03.mp3'
 sound.Volume=kind=='impact' and .65 or .5
 sound.PlaybackSpeed=kind=='impact' and .48 or (kind=='wake' and .65 or 1.65)
 sound.RollOffMinDistance=12;sound.RollOffMaxDistance=130;sound.Parent=anchor;sound:Play()
 if kind=='impact' then
  local dust=Instance.new('ParticleEmitter');dust.Name='SlabImpactDust';dust.Rate=0
  dust.Texture='rbxasset://textures/particles/smoke_main.dds';dust.Color=ColorSequence.new(Color3.fromRGB(156,176,156))
  dust.Lifetime=NumberRange.new(.45,.85);dust.Speed=NumberRange.new(3,8);dust.Drag=5
  dust.SpreadAngle=Vector2.new(75,75);dust.Acceleration=Vector3.new(0,-4,0)
  dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(.3,2.5),NumberSequenceKeypoint.new(1,4)})
  dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.4,.6),NumberSequenceKeypoint.new(1,1)})
  dust.Parent=anchor;dust:Emit(12)
 end
 table.insert(self.pulses,{part=anchor,start=now,duration=4,size=0,audio=true})
end
local function sentryFlare(eye)
 local flare=Instance.new('BillboardGui');flare.Name='SentryLensFlare';flare.Adornee=eye
 flare.Size=UDim2.fromScale(28,14);flare.AlwaysOnTop=false;flare.LightInfluence=0;flare.MaxDistance=160;flare.Enabled=false;flare.Parent=eye
 local glow=Instance.new('ImageLabel');glow.Name='Starburst';glow.BackgroundTransparency=1
 glow.Image='rbxasset://textures/sparkle.png';glow.ImageColor3=WHITE
 glow.Size=UDim2.fromScale(.5,1);glow.Position=UDim2.fromScale(.25,0);glow.Parent=flare
 local streak=Instance.new('Frame');streak.Name='AnamorphicStreak';streak.AnchorPoint=Vector2.new(.5,.5)
 streak.Position=UDim2.fromScale(.5,.5);streak.Size=UDim2.fromScale(1,.025);streak.BorderSizePixel=0;streak.BackgroundColor3=ICE;streak.Parent=flare
 local fade=Instance.new('UIGradient');fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.15),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.6,.15),NumberSequenceKeypoint.new(1,1)});fade.Parent=streak
 return flare,glow,streak
end
function P:_prepareSentryFall(record,now,late)
 record.fallGroups={}
 for _,item in ipairs(record.pieces) do
  local rank=segmentRanks[item.part.Name]
  if rank then
   local eyePart=item.part.Name=='eye' or item.part.Name=='eyecase' or item.part.Name=='spawnEye'
   local key=eyePart and 'socket' or item.part.Name
   local group=record.fallGroups[key]
   if not group then
    local start=eyePart and record.eye.CFrame or item.part.CFrame
    local angle=record.phase+rank*2.39996;local radius=eyePart and 3.7 or 4.5+rank*.9
    local rest=eyePart and CFrame.new(record.eyeCenter) or item.frame
    local xz=rest.Position+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
    local field=record.source.Parent and record.source.Parent:FindFirstChild('Field')
    local floor
    if field and field:IsA('BasePart') then
     local point=field.CFrame:PointToObjectSpace(xz)
     if math.abs(point.X)<=field.Size.X*.5 and math.abs(point.Z)<=field.Size.Z*.5 then
      floor=field.CFrame:PointToWorldSpace(Vector3.new(point.X,field.Size.Y*.5,point.Z)).Y
     end
    end
    floor=floor or self:_floor(xz,record.source)
    local rotation=rest.Rotation*CFrame.Angles((rank%2==0 and 1 or -1)*(.28+rank*.12),angle*.13,.2+rank*.1)
    local size=eyePart and record.view:FindFirstChild('eyecase',true).Size or item.size
    local support=(math.abs(rotation.RightVector.Y)*size.X+math.abs(rotation.UpVector.Y)*size.Y+math.abs(rotation.LookVector.Y)*size.Z)*.5
    local finish=CFrame.new(xz.X,floor+support*.65,xz.Z)*rotation
    local drop=math.max(0,start.Position.Y-finish.Position.Y)
    group={start=start,finish=finish,drop=drop,rank=rank,ground=Vector3.new(xz.X,floor,xz.Z),impact=false}
    if late then local _,landed=S.fall(now-record.deathAt,drop,rank);group.impact=landed end
    record.fallGroups[key]=group
   end
   item.fall=group;item.fallRelative=group.start:ToObjectSpace(item.part.CFrame)
  end
 end
end
function P:_sentryFallFrame(item,record,now)
 local group=item.fall
 local fraction,landed,impactAge=S.fall(now-record.deathAt,group.drop,group.rank)
 local frame
 if landed then frame=group.finish
 else
  local travel=math.sqrt(fraction);local p=group.start.Position:Lerp(group.finish.Position,travel)
  local y=group.start.Position.Y-group.drop*fraction
  frame=CFrame.new(p.X,y,p.Z)*group.start.Rotation:Lerp(group.finish.Rotation,F.smooth(travel))
 end
 if landed and not group.impact then
  group.impact=true
  -- A long suspended frame must not replay every historical impact at once.
  if impactAge<.22 then self:_sentryAudio(group.ground,'impact',now) end
 end
 return frame*item.fallRelative
end
function P:registerTurret(source,now)
 if self.closed or self.turrets[source] then return self.turrets[source] end
 if source:GetAttribute('HP')==nil or source:GetAttribute('Dead')==nil then return nil end
 -- Streamed partial models must not become partial turret viewmodels.
 for _,name in ipairs(requiredSegments) do
  local part=source:FindFirstChild(name,true)
  if not part or not part:IsA('BasePart') then return nil end
 end
 local base=source:FindFirstChild('basepart',true)
 if not base or not base:IsA('BasePart') then return nil end
 local view=source:Clone();if not view then return nil end
 clean(view);view.Name='View_'..source.Name;view.Parent=self.parent
 local eye=view:FindFirstChild('eye',true)
 local endpoint=barePart(self.parent,'SentryAim');endpoint.Size=Vector3.one*.05;endpoint.Transparency=1
 local cue=barePart(self.parent,'SentryChargeMark');cue.Shape=Enum.PartType.Cylinder
 cue.Size=Vector3.new(.025,7,7);cue.Color=HOT;cue.Transparency=1
 local a=Instance.new('Attachment');a.Name='ChargeOrigin';a.Parent=eye
 local b=Instance.new('Attachment');b.Parent=endpoint
 local beam=Instance.new('Beam');beam.Name='SentryTelegraph';beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.Color=ColorSequence.new(HOT);beam.LightEmission=1;beam.LightInfluence=0
 beam.Transparency=NumberSequence.new(.7);beam.Segments=1;beam.Enabled=false;beam.Parent=view
 local core=beam:Clone();core.Name='SentryBeamCore';core.Color=ColorSequence.new(WHITE)
 core.Transparency=NumberSequence.new(.15);core.Parent=view
 local light=Instance.new('PointLight');light.Name='SentryCharge';light.Color=ICE;light.Range=7
 light.Shadows=false;light.Brightness=0;light.Parent=eye
 local initial=F.new(snapshot(source))
 local flare,glow,streak=sentryFlare(eye)
 local record={source=source,view=view,eye=eye,endpoint=endpoint,cue=cue,attachment=a,beam=beam,core=core,light=light,
  flare=flare,glow=glow,streak=streak,
  parts={},pieces=partsOf(view),hidden={},accents={},events=initial,yaw=0,hitAt=-100,shotAt=-100,
  deathAt=initial.dead and now-10 or nil,restoreAt=nil,floor=base.Position.Y+base.Size.Y*.5,
  baseCenter=base.Position,eyeCenter=eye.Position,phase=base.Position.X*.17+base.Position.Z*.23}
 record.motion=S.new(now,record.phase)
 local stackCenter=base.Position.Y+base.Size.Y*.5
 local previousHeight=nil
 for _,name in ipairs({'bottemseg','lowerseg','upperseg','topseg'}) do
  for _,item in ipairs(record.pieces) do if item.part.Name==name then
   -- The authored lower shell has a deep eye cutout: touching bounding boxes
   -- still leaves that opening exposed. Telescope the rims into one another.
   stackCenter+=previousHeight and (previousHeight+item.size.Y)*.25 or item.size.Y*.5
   item.compact=stackCenter-item.frame.Position.Y;previousHeight=item.size.Y
  end end
 end
 record.lastAwake=source:GetAttribute('Awake')==true
 record.lastWake=source:GetAttribute('WakeAt') or 0
 local ignition=source:GetAttribute('ActivateAt') or record.lastWake+S.IGNITE
 record.ignited=now>=ignition;record.wakeSound=record.lastAwake
 if initial.dead then
  record.deathAt=source:GetAttribute('DeathAt') or now-10
  if record.deathAt<=0 then record.deathAt=now-10 end
  self:_prepareSentryFall(record,now,true)
 end
 for _,item in ipairs(record.pieces) do record.parts[item.part]=true end
 for _,name in ipairs({'eye','spawnEye'}) do
  local part=view:FindFirstChild(name,true);record.accents[part]=part.Color
 end
 self.turrets[source]=record
 self:_hideTurret(record)
 self:renderTurret(record,0,now)
 return record
end
function P:_hideTurret(record)
 -- Also covers parts arriving after the initial source clone through StreamingEnabled.
 for _,part in ipairs(record.source:GetDescendants()) do
  if part:IsA('BasePart') then
   if record.hidden[part]==nil then record.hidden[part]=part.LocalTransparencyModifier end
   part.LocalTransparencyModifier=1
  end
 end
end
function P:renderTurret(record,dt,now)
 if self.closed or not record.view.Parent then return end
 local source=record.source;local event=F.observe(record.events,snapshot(source))
 local dead=record.events.dead
 if event.died then
  local stamp=source:GetAttribute('DeathAt') or 0
  record.deathAt=stamp>0 and stamp or now;record.restoreAt=nil
  self:_prepareSentryFall(record,now,false)
 elseif event.revived then
  record.restoreAt=now;record.deathAt=nil;record.fallGroups=nil
  for _,item in ipairs(record.pieces) do item.rebuildFrom=item.part.CFrame end
 end
 if event.hit then record.hitAt=now end
 if event.shot then record.shotAt=now;self:_sound(record.eye.Position,'hit',now) end
 local awake=source:GetAttribute('Awake')
 -- Older in-memory preview servers have no new attributes. This fallback only
 -- derives presentation from their authoritative field phase, never local input.
 if awake==nil then
  local phase=source.Parent and source.Parent:GetAttribute('Phase')
  awake=phase=='Gathering' or phase=='Active' or source:GetAttribute('Telegraph')==true
 end
 awake=awake==true and not dead
 local wakeAt=source:GetAttribute('WakeAt')
 if not wakeAt or wakeAt<=0 then
  if awake and not record.lastAwake then record.observedWake=now end
  wakeAt=record.observedWake or now-S.WAKE_DURATION
 end
 local activateAt=source:GetAttribute('ActivateAt')
 if not activateAt or activateAt<=0 then activateAt=wakeAt+S.IGNITE end
 if not awake and record.lastAwake and not dead then
  record.sleepAt=now
  for _,item in ipairs(record.pieces) do item.sleepFrom=item.part.CFrame end
 elseif awake then record.sleepAt=nil end
 if awake and (not record.lastAwake or record.lastWake~=wakeAt) then
  record.ignited=now>activateAt+.8;record.wakeSound=false
 end
 record.lastAwake=awake;record.lastWake=wakeAt
 if awake and not record.wakeSound then
  record.wakeSound=true
  if now-wakeAt<.3 then self:_sentryAudio(record.baseCenter,'wake',now) end
 end
 if awake and not record.ignited and now>=activateAt then
  record.ignited=true
  if now-activateAt<.5 then self:_sentryAudio(record.eye.Position,'ignite',now);self:_pulse(record.eye.Position,WHITE,4.5,now,.3) end
 end
 local charging=source:GetAttribute('Telegraph')==true and awake
 local aim=source:GetAttribute('Aim')
 local followingShot=now-record.shotAt<.35
 local look=(charging or followingShot) and aim or source:GetAttribute('WatchPosition') or source:GetAttribute('WakeAim') or aim
 local fireAt=source:GetAttribute('FireAt') or now
 local charge=charging and math.clamp(1-(fireAt-now)/.8,0,1) or 0
 local aimYaw,aimPitch
 if typeof(look)=='Vector3' then
  local delta=look-(record.eyeCenter+Vector3.new(0,1.25,0))
  local horizontal=math.sqrt(delta.X*delta.X+delta.Z*delta.Z)
  if horizontal>.1 then aimYaw=math.atan2(-delta.X,-delta.Z);aimPitch=math.atan2(delta.Y,horizontal) end
 end
 local pose=S.step(record.motion,dt,now,record.phase,{dead=dead,awake=awake,wakeAt=wakeAt,
  charging=charging,charge=charge,aimYaw=aimYaw,aimPitch=aimPitch,
  shotAge=now-record.shotAt,hitAge=now-record.hitAt})
 local warm=pose.charge;local shotFlash=F.flash(now-record.shotAt,.22)
 local ignite=awake and F.flash(now-activateAt,.8) or 0
 local hit=F.flash(now-record.hitAt,.2)
 local eyeColor=ICE:Lerp(HOT,warm):Lerp(WHITE,math.max(ignite,shotFlash))
 for _,item in ipairs(record.pieces) do
  local part=item.part
  if part.Parent then
   local rank=segmentRanks[part.Name]
   local frame=item.frame;local transparency=item.transparency
   local color=item.color:Lerp(WHITE,hit*.65)
   if rank then
    local eyePart=part.Name=='eye' or part.Name=='eyecase' or part.Name=='spawnEye'
    if dead then
     if not item.fall then self:_prepareSentryFall(record,now,true) end
     frame=self:_sentryFallFrame(item,record,now);color=item.color:Lerp(RUIN,eyePart and .92 or .38)
     part.Size=item.size
     if eyePart then part.Material=Enum.Material.SmoothPlastic end
    else
     local motion=S.segment(rank,now,record.phase,pose,eyePart,item.compact or 0)
     local origin=eyePart and record.eyeCenter or Vector3.new(record.baseCenter.X,item.frame.Position.Y,record.baseCenter.Z)
     local rotation=CFrame.Angles(0,motion.yaw,0)*CFrame.Angles(motion.pitch,0,motion.roll)
     frame=CFrame.new(origin+Vector3.new(motion.side,motion.lift,motion.back))*rotation*CFrame.new(-origin)*item.frame
     if not awake and item.sleepFrom and record.sleepAt then
      local progress=F.smooth(F.progress(now,record.sleepAt+rank*.06,.95))
      frame=item.sleepFrom:Lerp(frame,progress)
      if progress>=1 then item.sleepFrom=nil end
     end
     if item.rebuildFrom and record.restoreAt then
      local progress=F.smooth(F.progress(now,record.restoreAt+rank*.07,1.15))
      frame=item.rebuildFrom:Lerp(frame,progress)
      if progress>=1 then item.rebuildFrom=nil end
     end
     if eyePart then
      part.Material=item.material
      transparency=math.max(transparency,1-motion.reveal)
      if part.Name~='eyecase' then
       color=eyeColor
       part.Size=Vector3.new(item.size.X,item.size.Y*(1-warm*.15),item.size.Z)
      end
     else color=color:Lerp(HOT,warm*.13):Lerp(WHITE,ignite*.3+shotFlash*.2) end
    end
   end
   part.CFrame=frame;part.Color=color;part.Transparency=transparency;item.lastFrame=frame
  end
 end
 record.light.Color=eyeColor;record.light.Range=12+ignite*16
 record.light.Brightness=awake and (1+warm*2.5+ignite*8+shotFlash*3) or 0
 local flare=awake and math.max(ignite,shotFlash*.3) or 0
 record.flare.Enabled=flare>.005;record.flare.Size=UDim2.fromScale(12+flare*20,6+flare*10)
 record.glow.ImageTransparency=1-flare;record.streak.BackgroundTransparency=1-flare*.95
 local aiming=typeof(aim)=='Vector3'
 record.beam.Enabled=awake and now>=activateAt and aiming and (charging or shotFlash>.01)
 record.beam.Width0=.035+warm*.07+shotFlash*.32;record.beam.Width1=.035+warm*.07+shotFlash*.22
 record.core.Enabled=record.beam.Enabled;record.core.Width0=.012+warm*.02+shotFlash*.1
 record.core.Width1=.012+warm*.02+shotFlash*.07
 if aiming then record.endpoint.Position=aim end
 if charging and aiming then
  if record.markAim~=aim then
   record.markAim=aim
   local field=source.Parent and source.Parent:FindFirstChild('Field');local ground=nil
   if field and field:IsA('BasePart') then
    local point=field.CFrame:PointToObjectSpace(aim)
    if math.abs(point.X)<=field.Size.X*.5 and math.abs(point.Z)<=field.Size.Z*.5 then
     ground=field.CFrame:PointToWorldSpace(Vector3.new(point.X,field.Size.Y*.5,point.Z)).Y
    end
   end
   record.cue.CFrame=CFrame.new(aim.X,(ground or self:_floor(aim,source))+.035,aim.Z)*CFrame.Angles(0,0,math.pi*.5)
  end
  record.cue.Transparency=.94-warm*.09
 else record.cue.Transparency=1;record.markAim=nil end
end
function P:destroyTurret(record)
 if not record then return end
 for part,original in pairs(record.hidden) do if part.Parent then part.LocalTransparencyModifier=original end end
 record.endpoint:Destroy();record.cue:Destroy();record.view:Destroy();self.turrets[record.source]=nil
end
function P:resourceImpact(resource,event,now)
 if self.closed or (event~='stage' and event~='break') then return end
 local view=resource.view;local floor=self:_floor(view.Position,resource.source)
 local amount=event=='break' and 5 or 2
 for i=1,amount do
  local angle=i*2.4+now*.1
  local full=resource.source:GetAttribute('FullSize') or view.Size
  local scale=(event=='break' and .16 or .07)*full.X/math.max(.01,view.Size.X)
  self:_fragment(view,view.CFrame,resource.baseColor,0,scale,
   Vector3.new(math.cos(angle)*(event=='break' and 4 or 2),2+i*.45,math.sin(angle)*3),
   Vector3.new(i*1.5,1,-i),floor,now,event=='break' and .9 or .55)
 end
end
function P:update(_dt,now)
 if self.closed then return end
 for i=#self.fragments,1,-1 do
  local item=self.fragments[i];local age=now-item.start
  if age>=item.duration or not item.part.Parent then
   item.part:Destroy();table.remove(self.fragments,i)
  else
   local y,_landed,flight=F.fragment(age,item.floor-item.frame.Position.Y,item.velocity.Y,26)
   local drift=Vector3.new(item.velocity.X*flight,y,item.velocity.Z*flight)
   local rotation=item.spin*flight
   item.part.CFrame=CFrame.new(item.frame.Position+drift)*item.frame.Rotation*CFrame.Angles(rotation.X,rotation.Y,rotation.Z)
   local fade=math.clamp((age-item.duration*.6)/(item.duration*.4),0,1)
   item.part.Transparency=item.transparency+(1-item.transparency)*fade
  end
 end
 for i=#self.pulses,1,-1 do
  local item=self.pulses[i];local progress=F.progress(now,item.start,item.duration)
  if progress>=1 or not item.part.Parent then item.part:Destroy();table.remove(self.pulses,i)
  elseif not item.audio then
   item.part.Size=Vector3.one*(.1+item.size*(1-(1-progress)^2));item.part.Transparency=.45+.55*progress
  end
 end
end
function P:destroy()
 if self.closed then return end
 self.closed=true
 for drone in pairs(self.drones) do self:destroyDrone(drone) end
 for _,record in pairs(self.turrets) do self:destroyTurret(record) end
 for _,item in ipairs(self.fragments) do item.part:Destroy() end
 for _,item in ipairs(self.pulses) do item.part:Destroy() end
 self.fragments={};self.pulses={}
end
return P
