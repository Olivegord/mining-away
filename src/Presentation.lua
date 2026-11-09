-- Client-only animation and cosmetic debris. No remotes, damage or rewards.
-- Feedback is bundled immediately before this module by tools/build.py.
local P={};P.__index=P
local F=Feedback
local S=SentryMotion
local ICE=Color3.fromRGB(126,241,221)
local HOT=Color3.fromRGB(255,179,102)
local WHITE=Color3.fromRGB(255,249,230)
local RUIN=Color3.fromRGB(34,61,67)
local miningLooks={
 Cutter={color=Color3.fromRGB(255,208,69),core=Color3.fromRGB(255,244,179),width0=1.05,width1=.78},
 Percussion={color=Color3.fromRGB(245,105,85),core=Color3.fromRGB(255,226,202),width0=.85,width1=.72},
 Resonance={color=Color3.fromRGB(104,224,146),core=Color3.fromRGB(221,255,227),width0=.9,width1=.68},
}
local miningTypeColors={Dart=Color3.fromRGB(45,224,255),Striker=Color3.fromRGB(255,210,86),
 Medic=Color3.fromRGB(99,255,164),Charger=Color3.fromRGB(255,112,72)}
local segmentRanks={bottemseg=0,lowerseg=1,upperseg=2,topseg=3,eye=1,eyecase=1,spawnEye=1}
local requiredSegments={'bottemseg','lowerseg','upperseg','topseg','eye','eyecase','spawnEye'}
local function finalContact(sample,now)
 if sample.breakContactAt==nil then return sample,false end
 local at,untilAt=sample.breakContactAt,sample.breakContactUntil
 local valid=type(at)=='number' and type(untilAt)=='number' and at==at and untilAt==untilAt
  and now>=at and now<math.min(untilAt,at+.3) and sample.alive and not sample.paused
  and sample.part and sample.part.Parent and sample.part.Transparency<1
 if valid then return sample,true end
 local expired=table.clone(sample);expired.active=false;expired.key=nil;expired.part=nil
 expired.secondaryPart=nil;expired.secondaryKey=nil
 return expired,false
end
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
 return setmetatable({parent=options.parent,audio=options.audio,work=WorkEffects.new(options.parent),drones={},turrets={},fragments={},pulses={},scanCount=0,
  maxFragments=48,maxPulses=8,maxScans=8,beamRays=0,maxBeamRays=12,beamQueue={},beamOrder=0,closed=false},P)
end
-- One budget per render frame; cached anchors remain in the visible part's local
-- coordinates between queries, so a shrinking or tilted crystal carries its impact.
function P:beginFrame()
 self.beamRays=0;self.beamQueue={}
end
local function newLaserLayer(parent,name,color)
 return WorkEffects.newCylinder(parent,name,color)
end
local function branchOrigin(beam,part,point,normal)
 if beam.vertical then
  return Vector3.new(part.Position.X,math.max(beam.origin.WorldPosition.Y,part.Position.Y+part.Size.Magnitude*.5+.3),part.Position.Z)
 end
 return point+normal*.08
end
function P:createMiningBeam(view,emitter)
 local holder=Instance.new('Folder');holder.Name='MiningBeam';holder.Parent=self.parent
 local muzzle=Instance.new('Attachment');muzzle.Name='RenderedMuzzle';muzzle.Parent=emitter
 local body=view.PrimaryPart
 local optic=view:FindFirstChild('MiningOptic')
 if optic and optic:IsA('BasePart') then
  local exit=optic.CFrame:PointToWorldSpace(Vector3.new(-optic.Size.X*.5,0,0))
  muzzle.Position=emitter.CFrame:PointToObjectSpace(exit)
 elseif body then
  -- Keep the captured emission point for rigs with no separate visible optic.
  local bottom=body.CFrame:PointToWorldSpace(Vector3.new(0,-body.Size.Y*.5,0))
  muzzle.Position=emitter.CFrame:PointToObjectSpace(bottom)
 end
 local endpoint=barePart(holder,'MiningEndpoint');endpoint.Size=Vector3.one*.05;endpoint.Transparency=1
 local impact=barePart(holder,'ContactLight');impact.Shape=Enum.PartType.Ball
 impact.Size=Vector3.one*.14;impact.Transparency=1;impact.Color=ICE
 local extra=barePart(holder,'SecondaryEndpoint');extra.Size=Vector3.one*.05;extra.Transparency=1
 local halo=newLaserLayer(holder,'OuterBeam',ICE)
 local core=newLaserLayer(holder,'InnerBeam',WHITE)
 local branch=newLaserLayer(holder,'SecondaryBeam',ICE)
 return {holder=holder,origin=muzzle,endpoint=endpoint,marker=impact,secondaryPoint=extra,
  core=core,halo=halo,secondary=branch,envelope=F.newBeam(),surface={},secondarySurface={},lastKey=nil,lastKind=nil}
end
function P:destroyMiningBeam(beam)
 if not beam then return end
 if self.audio and self.audio.stopLoop then self.audio:stopLoop(beam) end
 self.work:destroyMining(beam)
 BeamVFX.destroy(beam.vfx);BeamVFX.destroy(beam.branchVFX)
 if beam.origin then beam.origin:Destroy() end
 if beam.holder then beam.holder:Destroy() end
end
-- Fit only parts advertised by the authoritative drone snapshot. These are
-- local pieces of the existing drone model, including for other observers.
function P:syncMiningHardware(d,alive)
 local source,beam=d.source,d.beam
 local double=source:GetAttribute('DoubleBeam')==true
 local boost=source:GetAttribute('TwinThrusters')==true
 local duplicate=source:GetAttribute('OreDuplicator')==true
 local key=(double and 1 or 0)+(boost and 2 or 0)+(duplicate and 4 or 0)
 if key~=beam.hardwareKey then
  beam.hardwareKey=key
  for _,part in ipairs(beam.hardwareParts or {}) do d.parts[part]=nil;part:Destroy() end
  beam.hardwareParts={};beam.thrusterTrails={};beam.twinOrigins=nil
  if key==0 then return end
  local base=d.emitter
  local at=beam.origin.Position
  local shell=d.view.PrimaryPart.Size
  local function piece(name,size,offset,color,material)
   local part=barePart(d.view,name);part.Size=size;part.CFrame=base.CFrame*CFrame.new(offset)
   part.Color=color;part.Material=material;part.Transparency=0;part.CastShadow=false
   table.insert(beam.hardwareParts,part);d.parts[part]=0
   return part
  end
  local dark=Color3.fromRGB(29,48,60)
  if double then
   beam.twinOrigins={}
   for i,side in ipairs({-1,1}) do
    local offset=at+Vector3.new(side*math.max(.54,shell.X*.29),-.11,0)
    piece('DoubleBeamHousing',Vector3.new(.50,.31,.61),offset+Vector3.yAxis*.10,dark,Enum.Material.Metal)
    local lens=piece('DoubleBeamLens',Vector3.new(.31,.09,.44),offset-Vector3.yAxis*.10,Color3.fromRGB(116,232,255),Enum.Material.Neon)
    local socket=Instance.new('Attachment');socket.Position=Vector3.new(0,-.045,0);socket.Parent=lens;beam.twinOrigins[i]=socket
   end
  end
  if boost then
   for _,side in ipairs({-1,1}) do
    local offset=Vector3.new(side*(shell.X*.5+.17),0,shell.Z*.23)
    piece('ThrusterPod',Vector3.new(.60,.35,.92),offset,Color3.fromRGB(226,104,36),Enum.Material.SmoothPlastic)
    local exhaust=piece('ThrusterExhaust',Vector3.new(.37,.20,.10),offset+Vector3.new(0,0,.47),HOT,Enum.Material.Neon)
    local a=Instance.new('Attachment');a.Position=Vector3.new(-.13,0,.06);a.Parent=exhaust
    local b=Instance.new('Attachment');b.Position=Vector3.new(.13,0,.06);b.Parent=exhaust
    local trail=Instance.new('Trail');trail.Attachment0=a;trail.Attachment1=b;trail.Color=ColorSequence.new(HOT)
    trail.Lifetime=.16;trail.MinLength=.08;trail.LightEmission=.7;trail.Transparency=NumberSequence.new(.18,1);trail.Enabled=false;trail.Parent=exhaust
    table.insert(beam.thrusterTrails,trail)
   end
  end
  if duplicate then
   local offset=Vector3.new(0,shell.Y*.5+.11,shell.Z*.16)
   piece('OreDuplicatorTray',Vector3.new(.94,.21,.78),offset,dark,Enum.Material.Metal)
   for _,side in ipairs({-1,1}) do
    local ore=piece('OreDuplicatorCell',Vector3.new(.25,.29,.38),offset+Vector3.new(side*.21,.16,0),Color3.fromRGB(255,210,84),Enum.Material.Glass)
    ore.CFrame*=CFrame.Angles(0,math.pi*.25,side*.22)
   end
  end
 end
 if boost then
  local moving=alive and (source:GetAttribute('Velocity') or Vector3.zero).Magnitude>7
  for _,trail in ipairs(beam.thrusterTrails) do trail.Enabled=moving end
 end
end
-- Mining Away attaches its beam to an off-center marker on Crystal.Mesh.
-- Keep its authored X/Z proportions; sample the actual visible surface below
-- that marker so damage geometry cannot leave the tip suspended above it.
local CRYSTAL_AIM_X = -.5675010681152344 / 3.135000228881836
local CRYSTAL_AIM_Z = -.24361419677734375 / 4.4872307777404785
local function followsCrystal(sample)
 return sample.isMining==true and sample.serverSource~=nil and sample.serverSource:GetAttribute('CubicRock')==false
end
function P:_surface(beam,cache,origin,part,serverSource,now,ignoredSource,noQuery,vertical)
 if not part or not part.Parent or part.Transparency>=1 then cache.anchor=nil;return nil end
 if cache.part~=part then cache.part=part;cache.anchor=nil;cache.nextSample=0;cache.dueSince=now;cache.lastSample=nil;cache.verifiedAt=nil;cache.fadeUntil=nil end
 if not noQuery and now>=(cache.nextSample or 0) and self.beamRays+2<=self.maxBeamRays then
  self.beamRays+=2;cache.nextSample=now+.08;cache.dueSince=cache.nextSample;cache.lastSample=now
  local attached=beam.followCrystal and cache==beam.surface
  local rayOrigin=origin
  local direction
  if attached then
   rayOrigin=part.CFrame:PointToWorldSpace(Vector3.new(CRYSTAL_AIM_X*part.Size.X,part.Size.Y*.5+.2,CRYSTAL_AIM_Z*part.Size.Z))
   direction=part.CFrame:VectorToWorldSpace(Vector3.new(0,-part.Size.Y-.4,0))
  else
   direction=vertical and Vector3.new(0,-math.max(.1,origin.Y-part.Position.Y+part.Size.Magnitude),0) or part.Position-origin
  end
  if direction.Magnitude<.01 then cache.anchor=nil;return nil end
  local include=RaycastParams.new();include.FilterType=Enum.RaycastFilterType.Include;include.FilterDescendantsInstances={part}
  -- Query the local rendered union/mesh, not the untouched server collider. The
  -- temporary query flag is reset even if the engine rejects the query.
  local previous=part.CanQuery;part.CanQuery=true
  local ok,hit=pcall(function() return workspace:Raycast(rayOrigin,direction*1.5,include) end)
  part.CanQuery=previous
  if not ok or not hit or hit.Instance~=part then cache.anchor=nil;return nil end
  local exclude=RaycastParams.new();exclude.FilterType=Enum.RaycastFilterType.Exclude
  local ignored={self.parent};if serverSource then table.insert(ignored,serverSource) end
  if ignoredSource and ignoredSource~=serverSource then table.insert(ignored,ignoredSource) end
  exclude.FilterDescendantsInstances=ignored
  -- Closely scattered reference crystals are noncolliding. Resolve the
  -- contact on the assigned crystal while still respecting authored walls.
  if serverSource and serverSource:GetAttribute('ReferenceCrystal')==true then exclude.RespectCanCollide=true end
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
 normal=normal.Unit
 if vertical then
  -- Reproject the verified surface plane onto the current emitter's vertical
  -- line. Shrink/rotation cannot steer the laser sideways between ray samples.
  if normal.Y<.1 then return nil end
  local y=point.Y+(normal.X*(point.X-origin.X)+normal.Z*(point.Z-origin.Z))/normal.Y
  point=Vector3.new(origin.X,y,origin.Z)
  local localPoint=part.CFrame:PointToObjectSpace(point)
  if y>=origin.Y or math.abs(localPoint.X)>part.Size.X*.5+.02 or math.abs(localPoint.Y)>part.Size.Y*.5+.02 or math.abs(localPoint.Z)>part.Size.Z*.5+.02 then return nil end
 end
 return point,normal
end
-- Mining Away's two flat beam ribbons. Render from the same verified contact
-- as other miners; the original warm palette and width curve are cosmetic.
local function drawReferenceBeam(beam,visible,width,sample,now)
 local origins=beam.twinOrigins
 if beam.reference and beam.referenceOrigins~=origins then
  for _,layer in ipairs(beam.reference) do layer:Destroy() end
  beam.reference=nil
 end
 if visible and not beam.reference then
  local tip=beam.referenceTip
  if not tip then tip=Instance.new('Attachment');tip.Parent=beam.endpoint;beam.referenceTip=tip end
  local layers={}
  for _,origin in ipairs(origins or {beam.origin}) do
   for i,name in ipairs({'ReferenceInner','ReferenceOuter'}) do
    local b=Instance.new('Beam');b.Name=origins and (i==1 and 'DoubleBeamCore' or 'DoubleBeamHalo') or name
    b.Attachment0=origin;b.Attachment1=tip;b.FaceCamera=true
   -- The enabled reference clones MiningFX.Beam, whose inner color differs
   -- from the unused beam embedded in the drone template.
    b.Color=ColorSequence.new(origins and (i==1 and Color3.fromRGB(196,250,255) or Color3.fromRGB(70,197,255)) or (i==1 and Color3.fromRGB(192,134,80) or Color3.new(1,.622278,.0959487)))
    b.Transparency=i==1 and NumberSequence.new(0) or NumberSequence.new(.85625,.85)
    b.LightEmission=i==1 and 1 or .1;b.LightInfluence=i==1 and 1 or .6
    b.Parent=beam.holder;table.insert(layers,b)
   end
  end
  beam.reference=layers;beam.referenceOrigins=origins
 end
 if not beam.reference then return end
 local t=math.clamp((now-(sample.since or now))/2,0,1)
 local inner=.3*(1-(1-t)^2)*width
 for i,b in ipairs(beam.reference) do
  local w=visible and (i%2==1 and inner or .5*width)*(origins and .64 or 1) or 0
  b.Width0=w;b.Width1=w;b.Enabled=w>.001
 end
end
function P:renderMiningBeam(beam,sample,now,noQuery)
 if self.closed or not beam or not beam.origin.Parent then return end
 local final;sample,final=finalContact(sample,now)
 beam.vertical=sample.isMining==true
 beam.followCrystal=followsCrystal(sample)
 if not sample.alive or beam.cachedLife~=sample.life or beam.cacheKey~=sample.key then
  beam.surface={};beam.secondarySurface={};beam.endY=nil;beam.visibility=0;beam.cachedLife=sample.life;beam.cacheKey=sample.key
 end
 local dt=beam.renderAt and math.clamp(now-beam.renderAt,0,.1) or 1/60;beam.renderAt=now
 local part=sample.part
 local point,normal
 -- A recall starting with a still-valid contact may finish its authored fade,
 -- even when its verification expires during those final 0.2 seconds.
 if sample.active then beam.surface.fadeUntil=nil
 elseif sample.alive and beam.envelope.active and beam.surface.verifiedAt and now-beam.surface.verifiedAt<=.75 then
  beam.surface.fadeUntil=now+.2
 end
 if sample.alive and part then point,normal=self:_surface(beam,beam.surface,beam.origin.WorldPosition,part,sample.serverSource,now,nil,noQuery,beam.vertical and not beam.followCrystal) end
 local valid=point~=nil and normal~=nil
 -- The server already supplied the charge deadline. Bridge only the small
 -- snapshot gap for continuous miners, cosmetically, with a verified contact.
 -- Never feed prediction into damage, work particles, audio or the fade state.
 local deadline=(sample.warmupStart or 0)+(sample.warmupDuration or .8)
 local predicted=sample.droneRole=='Striker' and sample.isMining and sample.alive
  and sample.charging and not sample.active and not sample.paused and valid
  and (sample.warmupStart or 0)>0 and now>=deadline and now<deadline+.15
 -- A break attribute can precede its contact snapshot. A released beam is
 -- already full width; only its existing stop fade needs reconstruction.
 if final and beam.envelope.key~=sample.key then beam.envelope=F.newBeam() end
 local width=F.beamStep(beam.envelope,{now=now,alive=sample.alive,valid=part~=nil and part.Parent~=nil and part.Transparency<1,
  key=sample.key,life=sample.life,active=sample.active,since=sample.since})
 if predicted then width=1 end
 if valid then
  beam.endpoint.Position=point;beam.marker.Position=point+normal*.07
  if sample.resource then sample.resource.lastContact={anchor=beam.surface.anchor,normal=beam.surface.normal} end
 end
 local style=sample.style or 'Cutter';local look=miningLooks[style] or miningLooks.Cutter
 local tint=miningTypeColors[sample.droneType] or look.color
 if beam.look~=look or beam.tint~=tint then
  beam.look=look;beam.tint=tint
  beam.core.Color=miningTypeColors[sample.droneType] and tint:Lerp(WHITE,.4) or look.core
  beam.halo.Color=tint;beam.marker.Color=tint
 end
 beam.miningCue=beam.miningCue or {}
 local pulse,newPulse=F.miningCue(beam.miningCue,sample,now)
 if style=='Cutter' then pulse=0;newPulse=false end
 local visible=valid and width>.001
 beam.visibility=visible and 1 or 0
 beam.core.Transparency=1;beam.halo.Transparency=1
 local reference=sample.droneRole=='Striker' and sample.isMining
 local charging=sample.alive and sample.charging and not sample.paused
 if not reference and (visible or charging) and not beam.vfx then beam.vfx=BeamVFX.new(beam.holder,sample.isMining and style or 'Combat',tint) end
 if beam.vfx then
  BeamVFX.style(beam.vfx,sample.isMining and style or 'Combat',tint)
  BeamVFX.startup(beam.vfx,BeamVFX.startupStyles[sample.droneRole or sample.droneType])
  -- draw writes every phase's visibility; avoid hide/show churn each frame.
 end
 if reference and beam.vfx then BeamVFX.destroy(beam.vfx);beam.vfx=nil end
 if visible then
  local origin=beam.origin.WorldPosition
  local vertical=beam.vertical and not beam.followCrystal
  if vertical then
   -- Only the downward endpoint eases. Both X/Z coordinates are always the
   -- emitter's, and the endpoint can never ease inside the verified surface.
   beam.endY=beam.endY and math.max(point.Y,beam.endY+(point.Y-beam.endY)*(1-math.exp(-dt*20))) or point.Y
  end
  local tip=vertical and Vector3.new(origin.X,beam.endY,origin.Z) or point
  local workerScale=.23;local alpha=beam.visibility
  if reference then beam.endpoint.Position=tip
  else
   WorkEffects.drawCylinder(beam.core,origin,tip,.11*width*workerScale,1-.62*alpha)
   WorkEffects.drawCylinder(beam.halo,origin,tip,(look.width0+(style=='Percussion' and .18 or .06)*pulse)*width*workerScale,1-.22*alpha)
  end
  if beam.vfx then
   beam.halo.Transparency=1
   local releaseAt=predicted and deadline or (style=='Percussion' and (sample.pulseAt or sample.since) or sample.since)
   BeamVFX.draw(beam.vfx,origin,tip,now,width*alpha,nil,now-(releaseAt or now),BeamVFX.MiningScale+pulse*.15)
  end
 elseif charging and beam.vfx then
  local q=math.clamp((now-(sample.warmupStart or now))/math.max(.01,sample.warmupDuration or .8),0,1)
  local origin=beam.origin.WorldPosition
  BeamVFX.draw(beam.vfx,origin,origin-Vector3.yAxis,now,0,q,nil,BeamVFX.MiningScale,sample.warmupDuration)
 elseif beam.vfx and sample.specialReleaseAt and now-sample.specialReleaseAt<.16 then
  local origin=beam.origin.WorldPosition
  BeamVFX.draw(beam.vfx,origin,origin-Vector3.yAxis,now,0,nil,now-sample.specialReleaseAt,BeamVFX.MiningScale)
 elseif beam.vfx then
  BeamVFX.destroy(beam.vfx);beam.vfx=nil
 end
 drawReferenceBeam(beam,reference and visible,width,sample,now)
 local glow=reference and visible and sample.active and not sample.paused
 if glow and not beam.referenceGlow then
  local halo=barePart(beam.holder,'ReferenceContactHalo');halo.Shape=Enum.PartType.Ball
  halo.Size=Vector3.one;halo.Color=Color3.fromRGB(180,192,173);halo.Material=Enum.Material.Neon
  beam.referenceGlow=halo
 end
 if beam.referenceGlow then
  beam.referenceGlow.Transparency=glow and .8 or 1
  if glow then beam.referenceGlow.Position=point end
 end
 if reference then
  beam.marker.Size=Vector3.one*.5
  beam.marker.Color=Color3.fromRGB(192,134,80);beam.marker.Material=Enum.Material.Neon
  if glow then beam.marker.Position=point end
  beam.marker.Transparency=glow and 0 or 1
 else
  beam.marker.Color=tint
  beam.marker.Size=Vector3.one*(.09+(style=='Percussion' and .11 or .04)*pulse)
  if valid then beam.marker.Position=point+normal*(beam.marker.Size.X*.5) end
  beam.marker.Transparency=visible and sample.contact and (.6+.4*(1-width)) or 1
 end
 if not reference then self.work:mining(beam,sample,point,normal,width,pulse,now) end
 if self.audio and self.audio.setLoop then
  if visible and sample.active and sample.isMining and not sample.paused and not reference then
   self.audio:setLoop(beam,'cutting_hum',point,.45+.55*width,.9+.1*width)
   beam.wasCutting=true
  else
   self.audio:stopLoop(beam)
   if beam.wasCutting and sample.alive and not sample.paused then self:_sound(beam.origin.WorldPosition,'laser_stop',now) end
   beam.wasCutting=false
  end
 end
 if visible and newPulse and style=='Percussion' and now>=(self.nextMiningSoundAt or 0) then
  self.nextMiningSoundAt=now+.12;self:_sound(point,'mining',now)
 elseif visible and newPulse and style=='Resonance' then self:_sound(point,'resonance',now)
 end
 beam.secondary.Transparency=1
 BeamVFX.hide(beam.branchVFX,true)
 local branchDrawn=false
 if visible and sample.active and sample.secondaryPart and sample.secondaryKey then
  local secondary,secondaryNormal=self:_surface(beam,beam.secondarySurface,branchOrigin(beam,sample.secondaryPart,point,normal),sample.secondaryPart,sample.secondarySource,now,sample.serverSource,noQuery,beam.vertical)
  if secondary and secondaryNormal then
   beam.secondaryPoint.Position=secondary;beam.secondary.Color=sample.secondaryColor or tint
   WorkEffects.drawCylinder(beam.secondary,branchOrigin(beam,sample.secondaryPart,point,normal),secondary,(style=='Resonance' and .11+.04*pulse or .085)*width*.58,.35)
   if not beam.branchVFX then beam.branchVFX=BeamVFX.new(beam.holder,'Branch',sample.secondaryColor or tint,false) end
   if beam.branchVFX then
    beam.secondary.Transparency=1;BeamVFX.style(beam.branchVFX,'Branch',sample.secondaryColor or tint)
    BeamVFX.draw(beam.branchVFX,branchOrigin(beam,sample.secondaryPart,point,normal),secondary,now,width,nil,nil)
    branchDrawn=true
   end
  end
 end
 if not branchDrawn then BeamVFX.destroy(beam.branchVFX);beam.branchVFX=nil end
end
-- Collect a frame before spending any rays. Oldest-due primary contacts are
-- given at least half of six contact slots and scheduled first. Branches receive
-- two slots, escalating to three under heavier load; unused slots return.
-- The .75s verified-cache deadline hides stale anchors during overload.
function P:queueMiningBeam(beam,sample,now)
 if self.closed or not beam or not beam.origin.Parent then return end
 local final;sample,final=finalContact(sample,now)
 beam.vertical=sample.isMining==true
 beam.followCrystal=followsCrystal(sample)
 if not sample.alive or beam.cachedLife~=sample.life or beam.cacheKey~=sample.key then
  beam.surface={};beam.secondarySurface={};beam.branchHold=nil;beam.endY=nil;beam.visibility=0;beam.cachedLife=sample.life;beam.cacheKey=sample.key
 end
 if final then
  -- This saved hit already has a hard .3s lifetime. It may use the still-visible
  -- fracture mesh at HP zero, but must never enter the ordinary 1.2s proc hold.
  beam.branchHold=nil
  table.insert(self.beamQueue,{beam=beam,sample=sample,now=now});return
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
 local function add(list,entry,cache,part,origin,source,ignored,vertical)
  if not part or not part.Parent or part.Transparency>=1 then cache.anchor=nil;return end
  if cache.part~=part then cache.part=part;cache.anchor=nil;cache.nextSample=0;cache.dueSince=entry.now;cache.lastSample=nil;cache.verifiedAt=nil;cache.fadeUntil=nil end
  if not cache.order then self.beamOrder+=1;cache.order=self.beamOrder end
  if entry.now>=(cache.nextSample or 0) then
   table.insert(list,{entry=entry,cache=cache,part=part,origin=origin,source=source,ignored=ignored,vertical=vertical})
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
    self:_surface(v.entry.beam,v.cache,v.origin,v.part,v.source,v.entry.now,v.ignored,false,v.vertical)
    v.served=true;used+=1
   end
  end
 end
 local branchCount=0;local primaryCount=0
 for _,e in ipairs(self.beamQueue) do
  local b,s=e.beam,e.sample
  if s.alive and s.active then
   primaryCount+=1
   add(primary,e,b.surface,s.part,b.origin.WorldPosition,s.serverSource,nil,b.vertical and not b.followCrystal)
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
   local point,normal=self:_surface(b,b.surface,b.origin.WorldPosition,s.part,s.serverSource,e.now,nil,true,b.vertical and not b.followCrystal)
   if point and normal then add(secondary,e,b.secondarySurface,s.secondaryPart,branchOrigin(b,s.secondaryPart,point,normal),s.secondarySource,s.serverSource,b.vertical) end
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
 part.Material=Enum.Material.SmoothPlastic;part.Size=Vector3.one*.1;part.Position=position;part.Color=color;part.Transparency=.82
 table.insert(self.pulses,{part=part,start=now,size=math.min(size,.8),duration=duration or .2})
end
function P:_sound(position,kind,now)
 if self.audio then self.audio:play(kind,position);return end
 -- Roblox Studio's shipped sounds were verified locally; no external asset IDs.
 if #self.pulses>=self.maxPulses then return end
 local anchor=barePart(self.parent,'ImpactAudio');anchor.Size=Vector3.one*.05
 anchor.Position=position;anchor.Transparency=1
 local sound=Instance.new('Sound');sound.Name='CosmeticImpact'
 sound.SoundId=kind=='death' and 'rbxasset://sounds/impact_explosion_03.mp3' or 'rbxasset://sounds/action_jump_land.mp3'
 sound.Volume=kind=='death' and .28 or (kind=='mining' and .065 or .12)
 sound.PlaybackSpeed=kind=='death' and 1.1 or (kind=='mining' and .85 or 1.6)
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
function P:_fragment(template,frame,color,transparency,scale,velocity,spin,floor,now,duration,priority,rock)
 if self.closed then return end
 if #self.fragments>=self.maxFragments then
  if not priority then return end
  -- A mineral shower cannot consume the space needed for a visible drone death.
  local replace=1
  for i,item in ipairs(self.fragments) do if not item.priority then replace=i;break end end
  self.fragments[replace].part:Destroy();table.remove(self.fragments,replace)
 end
 local part=rock and Instance.new('Part') or template:Clone();if not part then return end
 if rock then
  part.Size=template.Size;part.Material=template.Material;part.MaterialVariant=template.MaterialVariant
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 end
 -- Clone each real mesh once. Nested emitter parts and joints must not travel twice.
 for _,object in ipairs(part:GetDescendants()) do
  if object:IsA('BasePart') or object:IsA('LuaSourceContainer') or object:IsA('JointInstance')
   or object:IsA('Constraint') or object:IsA('WeldConstraint') or object:IsA('Beam')
   or object:IsA('Trail') or object:IsA('ParticleEmitter') or object:IsA('Sound')
   or object:IsA('BillboardGui') or object:IsA('SurfaceGui') then object:Destroy() end
 end
 passive(part);part.CastShadow=false;part.Name=rock and 'RockDebris' or 'AuthoredDebris';part.Size=part.Size*scale;part.CFrame=frame
 part.Color=color;part.Transparency=transparency;part.Parent=self.parent
 local ground=floor+(rock and part.Size.Magnitude*.5 or part.Size.Y*.3)
 local gravity=rock and 72 or 26
 local landing=(velocity.Y+math.sqrt(velocity.Y^2+2*gravity*math.max(0,frame.Position.Y-ground)))/gravity
 table.insert(self.fragments,{part=part,frame=frame,start=now,velocity=velocity,spin=spin,
  floor=ground,transparency=transparency,duration=math.max(duration or 1.5,landing+(rock and 1.25 or .35)),priority=priority,rock=rock})
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
 if self.audio and self.audio.updateDrone then self.audio:updateDrone(source,pose.Position,now) end
 local repairs=source:GetAttribute('RepairSerial') or 0
 if repairs>record.repairSerial and not record.events.dead then self:_pulse(pose.Position,Color3.fromRGB(131,235,168),2.4,now,.3) end
 record.repairSerial=repairs
 local shield=source:GetAttribute('Shield') or 0
 if shield<record.shield-.001 and not record.events.dead then self:_pulse(pose.Position,ICE,2.8,now,.22);self:_sound(pose.Position,'shield',now) end
 record.shield=shield
 local hit=F.flash(now-record.hitAt,.16);local recoil=F.recoil(now-record.shotAt)
 local rebuilding=state=='Reprinting'
 if rebuilding then
  local ready=source:GetAttribute('ReprintAt') or now
  local progress,reveal=F.assembly(now,ready,2)
  if not record.scan and self.scanCount<self.maxScans then
   record.scan=barePart(self.parent,'ReconstructionScan');record.scan.Color=ICE;record.scan.Material=Enum.Material.SmoothPlastic
   record.scan.Size=Vector3.new(1.48,.025,1.48);self.scanCount=self.scanCount+1
  end
  if record.scan then
   record.scan.CFrame=CFrame.new(pose.Position+Vector3.new(0,-.73+progress*1.46,0))*CFrame.Angles(0,progress*math.pi*.5,0)
   record.scan.Transparency=.8+reveal*.15
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
 if event.revived then self:_pulse(pose.Position,ICE,2.35,now,.28);self:_sound(pose.Position,'reprint',now) end
 if event.shot and not record.events.dead then
  local emitter=drone.view:FindFirstChild('Emmiter',true)
  if emitter and emitter:IsA('BasePart') then
   local critical=source:GetAttribute('Critical')==true or now-(source:GetAttribute('LastCritAt') or -100)<.15
   self:_pulse(emitter.Position,critical and HOT or ICE,critical and 1.25 or .65,now,.13)
   if now-(source:GetAttribute('ShotAt') or 0)<.35 then self:_sound(emitter.Position,'shot',now) end
  end
 end
 self.work:courier(drone,record,now)
 self.work:repair(drone,record,now)
 if source:GetAttribute('Role')~='Striker' then self.work:flight(drone,record,_dt,now) end
 if not record.events.dead then record.pose=pose end
end
function P:destroyDrone(drone)
 if self.audio and self.audio.forgetDrone then self.audio:forgetDrone(drone.source) end
 local record=self.drones[drone]
 if record then self:_removeScan(record);self.work:destroyDrone(record);self.drones[drone]=nil end
end
function P:_sentryAudio(position,kind,now)
 if #self.pulses>=self.maxPulses then return end
 local anchor=barePart(self.parent,'SentryAudio');anchor.Transparency=1;anchor.Position=position
 if self.audio then self.audio:play(kind,position)
 else
  local sound=Instance.new('Sound');sound.Name=kind=='impact' and 'StoneSlabThud' or 'SentryIgnition'
  sound.SoundId=kind=='wake' and 'rbxasset://sounds/action_get_up.mp3' or 'rbxasset://sounds/impact_explosion_03.mp3'
  sound.Volume=kind=='impact' and .65 or .5
  sound.PlaybackSpeed=kind=='impact' and .48 or (kind=='wake' and .65 or 1.65)
  sound.RollOffMinDistance=12;sound.RollOffMaxDistance=130;sound.Parent=anchor;sound:Play()
 end
 if kind=='impact' then
  local dust=Instance.new('ParticleEmitter');dust.Name='SlabImpactDust';dust.Rate=0
  dust.Texture='rbxasset://textures/particles/smoke_main.dds';dust.Color=ColorSequence.new(Color3.fromRGB(156,176,156))
  dust.Lifetime=NumberRange.new(.8,1.3);dust.Speed=NumberRange.new(1.5,4);dust.Drag=5
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
 beam.FaceCamera=true;beam.Color=ColorSequence.new(HOT);beam.LightEmission=.65;beam.LightInfluence=0
 beam.Transparency=NumberSequence.new(.7);beam.Segments=1;beam.Enabled=false;beam.Parent=view
 local core=beam:Clone();core.Name='SentryBeamCore';core.Color=ColorSequence.new(WHITE)
 core.Transparency=NumberSequence.new(.4);core.Parent=view
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
 if self.audio and self.audio.setLoop then
  if charging and source:GetAttribute('MotionPaused')~=true and (source:GetAttribute('FireAt') or 0)>now then
   self.audio:setLoop(record,'combat_charge',record.eye.Position,.85,1)
  else self.audio:stopLoop(record) end
 end
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
 record.light.Color=eyeColor;record.light.Range=5+ignite*2
 record.light.Brightness=awake and (.08+warm*.22+ignite*.25+shotFlash*.2) or 0
 record.flare.Enabled=false
 local aiming=typeof(aim)=='Vector3'
 record.beam.Enabled=awake and now>=activateAt and aiming and (charging or shotFlash>.01)
 record.beam.Width0=.014+warm*.028+shotFlash*.128;record.beam.Width1=.014+warm*.028+shotFlash*.088
 record.core.Enabled=record.beam.Enabled;record.core.Width0=.005+warm*.008+shotFlash*.04
 record.core.Width1=.005+warm*.008+shotFlash*.028
 if aiming then record.endpoint.Position=aim end
 if record.beam.Enabled then
  record.vfx=record.vfx or BeamVFX.new(record.view,'Sentry',HOT)
  if record.vfx then
   BeamVFX.draw(record.vfx,record.eye.Position,aim,now,shotFlash,charging and warm or nil,now-record.shotAt)
   record.core.Enabled=false -- retain the thin warning line until the shot
  end
 elseif record.vfx then BeamVFX.destroy(record.vfx);record.vfx=nil end
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
 if self.audio and self.audio.stopLoop then self.audio:stopLoop(record) end
 for part,original in pairs(record.hidden) do if part.Parent then part.LocalTransparencyModifier=original end end
 record.endpoint:Destroy();record.cue:Destroy();record.view:Destroy();self.turrets[record.source]=nil
end
function P:kick(position,strength,now)
 local camera=workspace.CurrentCamera;if not camera then return end
 local player=game:GetService('Players').LocalPlayer
 if player and (player:GetAttribute('ReducedMotion')==true or player:GetAttribute('MA_ReducedMotion')==true) then return end
 local character=player and player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local distance=((root and root.Position or camera.CFrame.Position)-position).Magnitude
 local amount=strength*math.clamp(1-distance/55,0,1)^2
 if amount<=.001 then return end
 local remaining=math.max(0,(self.shakeStrength or 0)*(1-math.clamp((now-(self.shakeAt or 0))/.4,0,1)))
 self.shakeStrength=math.min(.16,remaining+amount);self.shakeAt=now
end
function P:cameraOffset(now)
 local age=now-(self.shakeAt or -100);local envelope=math.max(0,1-age/.4)^2
 local strength=(self.shakeStrength or 0)*envelope
 return CFrame.new(math.sin(now*67)*strength,math.sin(now*83+.7)*strength*.65,0)
end
function P:update(_dt,now)
 if self.closed then return end
 self.work:update(now)
 for i=#self.fragments,1,-1 do
  local item=self.fragments[i];local age=now-item.start
  if age>=item.duration or not item.part.Parent then
   item.part:Destroy();table.remove(self.fragments,i)
  else
   if item.rock then
    local y,travel,bounces,impactAt,speed,settled,rest=F.rubble(age,item.floor-item.frame.Position.Y,item.velocity.Y,72)
    local rotation=item.spin*travel
    local turn=item.frame.Rotation*CFrame.Angles(rotation.X,rotation.Y,rotation.Z)
    if settled then
     local flatten=math.clamp(rest/.2,0,1);local _,yaw=turn:ToOrientation()
     turn=turn:Lerp(CFrame.Angles(0,yaw,0),flatten)
     y-=(item.part.Size.Magnitude-item.part.Size.Y)*.5*flatten
    end
    item.part.CFrame=CFrame.new(item.frame.Position+Vector3.new(item.velocity.X*travel,y,item.velocity.Z*travel))*turn
    if bounces>(item.bounces or 0) then
     item.bounces=bounces
     if age-impactAt<.12 and self.audio then self.audio:play('rock_clack',item.part.Position,{level=math.clamp(speed/22,.15,.75),pitch=math.clamp(1.2-item.part.Size.X*.2,.75,1.15)}) end
    end
   else
    local y,landed,flight=F.fragment(age,item.floor-item.frame.Position.Y,item.velocity.Y,26)
    local rotation=item.spin*flight
    item.part.CFrame=CFrame.new(item.frame.Position+Vector3.new(item.velocity.X*flight,y,item.velocity.Z*flight))*item.frame.Rotation*CFrame.Angles(rotation.X,rotation.Y,rotation.Z)
    if landed and not item.landed then
     item.landed=true
     if age-flight<.2 then self:_sound(item.part.Position,item.priority and 'metal_land' or 'rubble',now) end
    end
   end
   local fade=math.clamp((age-item.duration*.6)/(item.duration*.4),0,1)
   item.part.Transparency=item.transparency+(1-item.transparency)*fade
  end
 end
 for i=#self.pulses,1,-1 do
  local item=self.pulses[i];local progress=F.progress(now,item.start,item.duration)
  if progress>=1 or not item.part.Parent then item.part:Destroy();table.remove(self.pulses,i)
  elseif not item.audio then
   item.part.Size=Vector3.one*(.1+item.size*(1-(1-progress)^2));item.part.Transparency=.82+.18*progress
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
 self.work:destroy()
 self.fragments={};self.pulses={}
end
return P

