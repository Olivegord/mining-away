-- Client-only authored-asset animation. No remotes, damage, rewards or simulation.
-- Feedback is bundled immediately before this module by tools/build.py.
local P={};P.__index=P
local F=Feedback
local ICE=Color3.fromRGB(151,235,231)
local HOT=Color3.fromRGB(255,199,158)
local WHITE=Color3.fromRGB(255,247,228)
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
 local a=Instance.new('Attachment');a.Name='ChargeOrigin';a.Parent=eye
 local b=Instance.new('Attachment');b.Parent=endpoint
 local beam=Instance.new('Beam');beam.Name='SentryTelegraph';beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.Color=ColorSequence.new(HOT);beam.LightEmission=1
 beam.Transparency=NumberSequence.new(.5);beam.Enabled=false;beam.Parent=view
 local light=Instance.new('PointLight');light.Name='SentryCharge';light.Color=HOT;light.Range=8
 light.Shadows=false;light.Brightness=0;light.Parent=eye
 local initial=F.new(snapshot(source))
 local record={source=source,view=view,eye=eye,endpoint=endpoint,attachment=a,beam=beam,light=light,
  parts={},pieces=partsOf(view),hidden={},accents={},events=initial,yaw=0,hitAt=-100,shotAt=-100,
  deathAt=initial.dead and now-10 or nil,restoreAt=nil,floor=base.Position.Y+base.Size.Y*.5,eyeCenter=eye.Position}
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
 if event.died then
  record.deathAt=now;record.restoreAt=nil;self:_pulse(record.eye.Position,HOT,5.4,now,.24)
  self:_sound(record.eye.Position,'death',now)
 elseif event.revived then record.restoreAt=now;record.deathAt=nil end
 if event.hit then record.hitAt=now end
 if event.shot then
  record.shotAt=now;self:_pulse(record.eye.Position,HOT,2.3,now,.16);self:_sound(record.eye.Position,'hit',now)
 end
 local dead=record.events.dead
 local charging=source:GetAttribute('Telegraph')==true and not dead
 local aim=source:GetAttribute('Aim')
 local fireAt=source:GetAttribute('FireAt') or now
 local charge=charging and math.clamp(1-(fireAt-now)/.8,0,1) or 0
 local flash=F.flash(now-record.shotAt,.16)
 local hit=F.flash(now-record.hitAt,.11)
 local recoil=F.recoil(now-record.shotAt)
 if typeof(aim)=='Vector3' and not dead then
  local delta=aim-record.eye.Position
  if delta.X*delta.X+delta.Z*delta.Z>.01 then
   local target=math.atan2(-delta.X,-delta.Z)
   local difference=math.atan2(math.sin(target-record.yaw),math.cos(target-record.yaw))
   record.yaw=record.yaw+difference*(1-.84^(60*math.min(math.max(dt,0),.1)))
  end
 end
 for index,item in ipairs(record.pieces) do
  local part=item.part
  if part.Parent then
   local rank=segmentRanks[part.Name]
   local frame=item.frame;local transparency=item.transparency
   local color=item.color:Lerp(WHITE,hit*.4)
   if rank then
    local angle=index*2.39996
    local ruin=CFrame.new(frame.Position+Vector3.new(math.cos(angle)*(rank+1)*.75,
     math.min(0,record.floor+item.size.Y*.32-frame.Position.Y),math.sin(angle)*(rank+1)*.75))
     *frame.Rotation*CFrame.Angles(math.sin(angle)*.36,angle*.11,math.cos(angle)*.48)
    if dead then
     local collapse=F.smooth(F.progress(now,(record.deathAt or now-10)+rank*.045,.8))
     frame=frame:Lerp(ruin,collapse);color=item.color:Lerp(Color3.fromRGB(38,46,48),.72*collapse)
     if part.Name=='eye' or part.Name=='spawnEye' then transparency=math.max(transparency,collapse*.85) end
    else
     local restoring=record.restoreAt and 1-F.smooth(F.progress(now,record.restoreAt,.85)) or 0
     local eyePart=part.Name=='eye' or part.Name=='eyecase' or part.Name=='spawnEye'
     local yaw=record.yaw*(eyePart and 1 or .055*(rank+1))
     local origin=eyePart and record.eyeCenter or frame.Position
     frame=CFrame.new(origin)*CFrame.Angles(0,yaw,0)*CFrame.new(-origin)*frame
     frame=frame*CFrame.new(0,charge*rank*.07-recoil*rank*.14,recoil*(eyePart and .17 or .03))
     if restoring>0 then frame=frame:Lerp(ruin,restoring);color=color:Lerp(ICE,restoring*.3) end
     if part.Name=='eye' or part.Name=='spawnEye' then
      color=item.color:Lerp(HOT,charge*.75):Lerp(WHITE,math.max(flash,hit*.4))
     end
    end
   end
   part.CFrame=frame;part.Color=color;part.Transparency=transparency
  end
 end
 record.light.Brightness=dead and 0 or charge*1.4+flash*2
 local aiming=typeof(aim)=='Vector3'
 record.beam.Enabled=not dead and aiming and (charging or flash>.01)
 record.beam.Width0=.025+charge*.035+flash*.18;record.beam.Width1=.025+charge*.035+flash*.24
 if aiming then record.endpoint.Position=aim end
end
function P:destroyTurret(record)
 if not record then return end
 for part,original in pairs(record.hidden) do if part.Parent then part.LocalTransparencyModifier=original end end
 record.endpoint:Destroy();record.view:Destroy();self.turrets[record.source]=nil
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
