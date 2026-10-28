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
  maxFragments=48,maxPulses=10,maxScans=12,beamRays=0,maxBeamRays=12,beamQueue={},beamOrder=0,closed=false},P)
end
-- One budget per render frame; cached anchors remain in the visible part's local
-- coordinates between queries, so a shrinking or tilted crystal carries its impact.
function P:beginFrame()
 self.beamRays=0;self.beamQueue={}
end
local function newBeamLayer(parent,template,name,color,opacity,z)
 local beam=template and template:FindFirstChild(name,true)
 beam=beam and beam:IsA('Beam') and beam:Clone() or Instance.new('Beam')
 beam.Name=name;beam.Texture='';beam.CurveSize0=0;beam.CurveSize1=0
 beam.Segments=1;beam.FaceCamera=true;beam.LightEmission=.55;beam.LightInfluence=0
 beam.Color=ColorSequence.new(color);beam.Transparency=NumberSequence.new(opacity)
 beam.ZOffset=z;beam.Width0=0;beam.Width1=0;beam.Enabled=false;beam.Parent=parent
 return beam
end
function P:createMiningBeam(view,emitter)
 local holder=Instance.new('Folder');holder.Name='MiningBeam';holder.Parent=self.parent
 local muzzle=Instance.new('Attachment');muzzle.Name='RenderedMuzzle';muzzle.Parent=emitter
 local body=view.PrimaryPart
 if body then
  -- Original emitter is enclosed in the authored shell. Exit from the actual
  -- rendered underside, in emitter-local coordinates, and follow the viewmodel.
  local bottom=body.CFrame:PointToWorldSpace(Vector3.new(0,-body.Size.Y*.5,0))
  muzzle.Position=emitter.CFrame:PointToObjectSpace(bottom)
 end
 local endpoint=barePart(holder,'MiningEndpoint');endpoint.Size=Vector3.one*.05;endpoint.Transparency=1
 local target=Instance.new('Attachment');target.Parent=endpoint
 local impact=barePart(holder,'ContactLight');impact.Shape=Enum.PartType.Ball
 impact.Size=Vector3.one*.14;impact.Transparency=1;impact.Color=ICE
 local extra=barePart(holder,'SecondaryEndpoint');extra.Size=Vector3.one*.05;extra.Transparency=1
 local extraAttachment=Instance.new('Attachment');extraAttachment.Parent=extra
 local rs=game:GetService('ReplicatedStorage');local fx=rs:FindFirstChild('MiningFX');local template=fx and fx:FindFirstChild('Beam')
 local halo=newBeamLayer(holder,template,'OuterBeam',ICE,.84,0)
 local core=newBeamLayer(holder,template,'InnerBeam',WHITE,.08,.025)
 halo.Attachment0=muzzle;halo.Attachment1=target;core.Attachment0=muzzle;core.Attachment1=target
 local branch=newBeamLayer(holder,nil,'SecondaryBeam',ICE,.32,.01)
 branch.Attachment0=target;branch.Attachment1=extraAttachment
 return {holder=holder,origin=muzzle,endpoint=endpoint,marker=impact,secondaryPoint=extra,
  core=core,halo=halo,secondary=branch,envelope=F.newBeam(),surface={},secondarySurface={},lastKey=nil,lastKind=nil}
end
function P:destroyMiningBeam(beam)
 if not beam then return end
 if beam.origin then beam.origin:Destroy() end
 if beam.holder then beam.holder:Destroy() end
end
function P:_surface(beam,cache,origin,part,serverSource,now,ignoredSource,noQuery)
 if not part or not part.Parent or part.Transparency>=1 then cache.anchor=nil;return nil end
 if cache.part~=part then cache.part=part;cache.anchor=nil;cache.nextSample=0;cache.dueSince=now;cache.lastSample=nil;cache.verifiedAt=nil;cache.fadeUntil=nil end
 if not noQuery and now>=(cache.nextSample or 0) and self.beamRays+2<=self.maxBeamRays then
  self.beamRays+=2;cache.nextSample=now+.08;cache.dueSince=cache.nextSample;cache.lastSample=now
  local direction=part.Position-origin
  if direction.Magnitude<.01 then cache.anchor=nil;return nil end
  local include=RaycastParams.new();include.FilterType=Enum.RaycastFilterType.Include;include.FilterDescendantsInstances={part}
  -- Query the local rendered union/mesh, not the untouched server collider. The
  -- temporary query flag is reset even if the engine rejects the query.
  local previous=part.CanQuery;part.CanQuery=true
  local ok,hit=pcall(function() return workspace:Raycast(origin,direction*1.5,include) end)
  part.CanQuery=previous
  if not ok or not hit or hit.Instance~=part then cache.anchor=nil;return nil end
  local exclude=RaycastParams.new();exclude.FilterType=Enum.RaycastFilterType.Exclude
  local ignored={self.parent};if serverSource then table.insert(ignored,serverSource) end
  if ignoredSource and ignoredSource~=serverSource then table.insert(ignored,ignoredSource) end
  exclude.FilterDescendantsInstances=ignored
  local blocked=workspace:Raycast(origin,hit.Position-origin,exclude)
  if blocked and (blocked.Position-hit.Position).Magnitude>.12 then cache.anchor=nil;return nil end
  cache.anchor=F.surfaceAnchor(part.CFrame:PointToObjectSpace(hit.Position),part.Size)
  cache.normal=part.CFrame:VectorToObjectSpace(hit.Normal)
  cache.verifiedAt=now
 end
 -- A verified contact may bridge several frames of bounded contention, but it
 -- cannot remain visible indefinitely after a newly appeared obstruction.
 if cache.verifiedAt and now>math.max(cache.verifiedAt+.75,cache.fadeUntil or 0) then cache.anchor=nil;cache.normal=nil end
 if not cache.anchor or not cache.normal then return nil end
 local x,y,z=F.surfaceComponents(cache.anchor,part.Size)
 if not x then cache.anchor=nil;return nil end
 local point=part.CFrame:PointToWorldSpace(Vector3.new(x,y,z))
 local normal=part.CFrame:VectorToWorldSpace(cache.normal)
 if normal.Magnitude<.001 then return nil end
 return point,normal.Unit
end
function P:renderMiningBeam(beam,sample,now,noQuery)
 if self.closed or not beam or not beam.origin.Parent then return end
 if not sample.alive or beam.cachedLife~=sample.life or beam.cacheKey~=sample.key then
  beam.surface={};beam.secondarySurface={};beam.cachedLife=sample.life;beam.cacheKey=sample.key
 end
 local part=sample.part
 local point,normal
 -- A recall starting with a still-valid contact may finish its authored fade,
 -- even when its verification expires during those final 0.2 seconds.
 if sample.active then beam.surface.fadeUntil=nil
 elseif sample.alive and beam.envelope.active and beam.surface.verifiedAt and now-beam.surface.verifiedAt<=.75 then
  beam.surface.fadeUntil=now+.2
 end
 if sample.alive and part then point,normal=self:_surface(beam,beam.surface,beam.origin.WorldPosition,part,sample.serverSource,now,nil,noQuery) end
 local valid=point~=nil and normal~=nil
 local width=F.beamStep(beam.envelope,{now=now,alive=sample.alive,valid=valid,
  key=sample.key,life=sample.life,active=sample.active,since=sample.since})
 if valid then
  beam.endpoint.Position=point;beam.marker.Position=point+normal*.07
  if sample.resource then sample.resource.lastContact={anchor=beam.surface.anchor,normal=beam.surface.normal} end
 end
 local visible=valid and width>.001
 beam.core.Enabled=visible;beam.halo.Enabled=visible
 beam.core.Width0=.3*width;beam.core.Width1=.3*width
 beam.halo.Width0=.52*width;beam.halo.Width1=.42*width
 beam.marker.Transparency=visible and sample.contact and (.3+.7*(1-width)) or 1
 beam.secondary.Enabled=false
 if visible and sample.active and sample.secondaryPart and sample.secondaryKey then
  local secondary,secondaryNormal=self:_surface(beam,beam.secondarySurface,point+normal*.08,sample.secondaryPart,sample.secondarySource,now,sample.serverSource,noQuery)
  if secondary and secondaryNormal then
   beam.secondaryPoint.Position=secondary;beam.secondary.Color=ColorSequence.new(sample.secondaryColor or ICE)
   beam.secondary.Width0=.085*width;beam.secondary.Width1=.055*width;beam.secondary.Enabled=true
  end
 end
end
-- Collect a frame before spending any rays. Oldest-due primary contacts are
-- given at least half of six contact slots and scheduled first. Branches receive
-- two slots, escalating to three under heavier load; unused slots return.
-- The .75s verified-cache deadline hides stale anchors during overload.
function P:queueMiningBeam(beam,sample,now)
 if self.closed or not beam or not beam.origin.Parent then return end
 if not sample.alive or beam.cachedLife~=sample.life or beam.cacheKey~=sample.key then
  beam.surface={};beam.secondarySurface={};beam.branchHold=nil;beam.cachedLife=sample.life;beam.cacheKey=sample.key
 end
 -- A short-lived authoritative proc can end before its fair verification turn.
 -- Retain the observed target cosmetically for at most 1.2 s, and only until
 -- 0.12 s after its first successful verification. No gameplay is performed.
 local incoming=sample.alive and sample.active and sample.secondaryPart and sample.secondaryKey
 local incomingSource=sample.secondarySource
 local incomingHP=incomingSource and incomingSource:GetAttribute('HP')
 local incomingDead=incomingSource and incomingSource:GetAttribute('Dead')
 if incoming and (not sample.secondaryPart.Parent or (incomingSource and not incomingSource.Parent)
  or incomingDead==true or (type(incomingHP)=='number' and incomingHP<=0)) then
  sample=table.clone(sample);sample.secondaryPart=nil;sample.secondaryKey=nil;incoming=nil
 end
 local hold=beam.branchHold
 if incoming then
  if not hold or hold.key~=sample.secondaryKey or hold.part~=sample.secondaryPart then
   hold={key=sample.secondaryKey,part=sample.secondaryPart,source=sample.secondarySource,color=sample.secondaryColor}
   beam.branchHold=hold;beam.secondarySurface={}
  end
  hold.deadline=now+1.2
 elseif hold then
  local verified=hold.firstVerifiedAt
  local sourceHP=hold.source and hold.source:GetAttribute('HP')
  local sourceDead=hold.source and hold.source:GetAttribute('Dead')
  if not sample.alive or not sample.active or not hold.part.Parent or (hold.source and not hold.source.Parent)
   or sourceDead==true or (type(sourceHP)=='number' and sourceHP<=0)
   or now>hold.deadline or (verified and now>verified+.12) then
   beam.branchHold=nil;beam.secondarySurface={};hold=nil
  else
   sample=table.clone(sample)
   sample.secondaryPart=hold.part;sample.secondaryKey=hold.key
   sample.secondarySource=hold.source;sample.secondaryColor=hold.color
  end
 end
 table.insert(self.beamQueue,{beam=beam,sample=sample,now=now})
end
function P:flushMiningBeams()
 local primary={};local secondary={}
 local function add(list,entry,cache,part,origin,source,ignored)
  if not part or not part.Parent or part.Transparency>=1 then cache.anchor=nil;return end
  if cache.part~=part then cache.part=part;cache.anchor=nil;cache.nextSample=0;cache.dueSince=entry.now;cache.lastSample=nil;cache.verifiedAt=nil;cache.fadeUntil=nil end
  if not cache.order then self.beamOrder+=1;cache.order=self.beamOrder end
  if entry.now>=(cache.nextSample or 0) then
   table.insert(list,{entry=entry,cache=cache,part=part,origin=origin,source=source,ignored=ignored})
  end
 end
 local function run(list,limit)
  table.sort(list,function(a,b)
   local x,y=a.cache.dueSince or a.entry.now,b.cache.dueSince or b.entry.now
   return x==y and a.cache.order<b.cache.order or x<y
  end)
  local used=0
  for _,v in ipairs(list) do
   if used>=limit or self.beamRays+2>self.maxBeamRays then break end
   if not v.served then
    self:_surface(v.entry.beam,v.cache,v.origin,v.part,v.source,v.entry.now,v.ignored)
    v.served=true;used+=1
   end
  end
 end
 local branchCount=0;local primaryCount=0
 for _,e in ipairs(self.beamQueue) do
  local b,s=e.beam,e.sample
  if s.alive and s.active then
   primaryCount+=1
   add(primary,e,b.surface,s.part,b.origin.WorldPosition,s.serverSource,nil)
   if s.secondaryPart and s.secondaryKey then branchCount+=1 end
  end
 end
 local slots=math.floor(self.maxBeamRays/2)
 local frameNow=self.beamQueue[1] and self.beamQueue[1].now
 local dt=frameNow and self.lastBeamFrame and math.clamp(frameNow-self.lastBeamFrame,1/240,1/10) or 1/60
 if frameNow then self.lastBeamFrame=frameNow end
 local reserved=branchCount>0 and math.min(2,math.max(0,slots-1)) or 0
 -- Allocate according to both populations, preserving at least two primary
 -- and two branch slots where the budget permits. A 0.74s planning window
 -- leaves a small margin before the 0.75s verified-contact deadline.
 if reserved>0 then
  local primaryNeed=math.ceil(primaryCount*dt/.74)
  local branchNeed=math.ceil(branchCount*dt/.74)
  local primaryFloor=math.min(slots-2,math.max(2,primaryNeed))
  reserved=math.min(slots-primaryFloor,math.max(reserved,branchNeed))
 end
 run(primary,slots-reserved)
 for _,e in ipairs(self.beamQueue) do
  local b,s=e.beam,e.sample
  if s.alive and s.active and s.secondaryPart and s.secondaryKey then
   local point,normal=self:_surface(b,b.surface,b.origin.WorldPosition,s.part,s.serverSource,e.now,nil,true)
   if point and normal then add(secondary,e,b.secondarySurface,s.secondaryPart,point+normal*.08,s.secondarySource,s.serverSource) end
  end
 end
 run(secondary,reserved)
 -- If no usable branch was due, its reservation must not waste the budget.
 run(primary,slots)
 run(secondary,slots)
 for _,e in ipairs(self.beamQueue) do
  local hold=e.beam.branchHold
  if hold and not hold.firstVerifiedAt and e.beam.secondarySurface.verifiedAt then
   hold.firstVerifiedAt=e.beam.secondarySurface.verifiedAt
  end
 end
 for _,e in ipairs(self.beamQueue) do self:renderMiningBeam(e.beam,e.sample,e.now,true) end
 self.beamQueue={}
end
function P:_pulse(position,color,size,now,duration)
 if self.closed or #self.pulses>=self.maxPulses then return end
 local part=barePart(self.parent,'ImpactPulse');part.Shape=Enum.PartType.Ball
 part.Size=Vector3.one*.1;part.Position=position;part.Color=color;part.Transparency=.72
 table.insert(self.pulses,{part=part,start=now,size=math.min(size,1.1),duration=duration or .2})
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

 table.insert(self.pulses,{part=anchor,start=now,duration=4,size=0,audio=true})
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
 beam.Transparency=NumberSequence.new(.82);beam.Segments=1;beam.Texture='';beam.ZOffset=0;beam.Enabled=false;beam.Parent=view
 local core=beam:Clone();core.Name='SentryBeamCore';core.Color=ColorSequence.new(WHITE)
 core.Transparency=NumberSequence.new(.08);core.Texture='';core.ZOffset=.025;core.Parent=view
 local light=Instance.new('PointLight');light.Name='SentryCharge';light.Color=ICE;light.Range=7
 light.Shadows=false;light.Brightness=0;light.Parent=eye
 local initial=F.new(snapshot(source))
 local record={source=source,view=view,eye=eye,endpoint=endpoint,cue=cue,attachment=a,beam=beam,core=core,light=light,
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
 for _,item in ipairs(record.pieces) do
  record.parts[item.part]=true
  if item.part.Name=='eye' or item.part.Name=='eyecase' or item.part.Name=='spawnEye' then
   item.eyeRelative=eye.CFrame:ToObjectSpace(item.frame)
  end
 end
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
      -- Interpolate the socket as one rigid assembly even during closing and
      -- reconstruction. Independent world-space lerps would shrink its orbit.
      -- partsOf sorts eye before eyecase/spawnEye.
      if part==record.eye then record.rigidEyeFrame=frame
      else frame=record.rigidEyeFrame*item.eyeRelative end
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
 record.light.Color=eyeColor;record.light.Range=7+ignite*3
 record.light.Brightness=awake and (.3+warm*.55+ignite*.8+shotFlash*.55) or 0
 local aiming=typeof(aim)=='Vector3'
 record.beam.Enabled=awake and now>=activateAt and aiming and (charging or shotFlash>.01)
 record.beam.Width0=.028+warm*.04+shotFlash*.18;record.beam.Width1=.028+warm*.04+shotFlash*.14
 record.core.Enabled=record.beam.Enabled;record.core.Width0=.01+warm*.015+shotFlash*.065
 record.core.Width1=.01+warm*.015+shotFlash*.05
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
 local view=resource.view;local contact=resource.lastContact
 if not view or not view.Parent or not contact or not contact.anchor or not contact.normal then return end
 local x,y,z=F.surfaceComponents(contact.anchor,view.Size)
 if not x then return end
 local normal=view.CFrame:VectorToWorldSpace(contact.normal)
 if normal.Magnitude<.001 then return end
 normal=normal.Unit
 local point=view.CFrame:PointToWorldSpace(Vector3.new(x,y,z))
 local floor=self:_floor(point,resource.source)
 -- Use a couple of small pieces of the actual crystal. Their centres and initial
 -- velocities are outside and away from the struck surface. No textured quads.
 local amount=event=='break' and 3 or 1
 for i=1,amount do
  local full=resource.source:GetAttribute('FullSize') or view.Size
  local scale=(event=='break' and .11 or .065)*full.X/math.max(.01,view.Size.X)
  local radius=math.sqrt(view.Size.X^2+view.Size.Y^2+view.Size.Z^2)*scale*.5
  local frame=CFrame.new(point+normal*(radius+.04))*view.CFrame.Rotation
  local tangent=normal:Cross(Vector3.new(0,1,0))
  if tangent.Magnitude<.01 then tangent=normal:Cross(Vector3.new(1,0,0)) end
  tangent=tangent.Unit
  local offset=(i-(amount+1)/2)*.8
  self:_fragment(view,frame,resource.baseColor,0,scale,normal*(1.2+i*.45)+tangent*offset,
   Vector3.new(i*.75,.7,-i*.5),floor,now,event=='break' and .65 or .42)
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
   item.part.Size=Vector3.one*(.1+item.size*(1-(1-progress)^2));item.part.Transparency=.72+.28*progress
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
