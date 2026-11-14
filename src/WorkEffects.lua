-- Attached, bounded work choreography. Server timestamps drive every phase;
-- these visuals never remove ore, credit a sale, heal, or advance mining.
local W={};W.__index=W
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local GOLD=Color3.fromRGB(244,193,89)
local WHITE=Color3.fromRGB(236,249,255)
local YELLOW=Color3.fromRGB(255,208,69)
local ENERGY_TAIL=1.8
local function part(parent,name,template)
 local p=(template and template:Clone()) or Instance.new('Part')
 if template then
  for _,child in ipairs(p:GetChildren()) do child:Destroy() end
  p.LocalTransparencyModifier=0
 end
 p.Name=name;p.Size=Vector3.one*.05;p.Transparency=1
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent
 return p
end
local function progress(now,at,duration)
 return math.clamp((now-at)/math.max(.01,duration),0,1)
end
local function facing(position,direction)
 local normal=direction.Magnitude>.001 and direction.Unit or Vector3.new(0,-1,0)
 local up=math.abs(normal.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 return CFrame.lookAt(position,position+normal,up)
end
local function cameraNear(position,radius)
 local camera=workspace.CurrentCamera
 if camera and (camera.CFrame.Position-position).Magnitude<radius then return true end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 return root and (root.Position-position).Magnitude<radius or false
end
local function cameraAbove(position,radius)
 local camera=workspace.CurrentCamera
 if not camera then return false end
 local delta=camera.CFrame.Position-position
 return delta.X*delta.X+delta.Z*delta.Z<radius*radius
end
local function particle(parent,name,color)
 -- Energy uses a fresh emitter: the preserved Largeparticles template runs at
 -- TimeScale .2 and must not silently slow newly authored work effects.
 local p=Instance.new('ParticleEmitter')
 p.Name=name;p.Enabled=false;p.Rate=0
 EnergyDisc.configure(p,.36,.58)
 p.Color=ColorSequence.new(color)
 p.TimeScale=1;p.VelocityInheritance=0
 p.EmissionDirection=Enum.NormalId.Front
 p.Lifetime=NumberRange.new(.65,1.2);p.Speed=NumberRange.new(.4,1.2);p.Drag=2.4
 p.SpreadAngle=Vector2.new(45,45);p.Acceleration=Vector3.zero;p.WindAffectsDrag=false
 p.Parent=parent;return p
end
local function cargoDust(cargo)
 local dust=particle(cargo,'CarriedOreDust',cargo.Color)
 dust.Color=ColorSequence.new(cargo.Color:Lerp(WHITE,.52),cargo.Color)
 EnergyDisc.configure(dust,.19,.32,1,.16,.21)
 dust.EmissionDirection=Enum.NormalId.Back
 dust.Lifetime=NumberRange.new(.34,.62);dust.Speed=NumberRange.new(.45,1.6)
 dust.Acceleration=Vector3.new(0,-4.5,0);dust.SpreadAngle=Vector2.new(50,50)
 return dust
end
local cargoRawSize=Vector3.new(table.unpack(Workshop.ROCK_SIZE))
local cargoBlockSize=Vector3.new(table.unpack(Workshop.BLOCK_SIZE))
local function drawClaw(slot,frame,size,closed,visible)
 slot.hub.CFrame=frame*CFrame.new(0,.56,0)
 slot.hub.Transparency=visible and 0 or 1
 for i,finger in ipairs(slot.fingers) do
  local x=i%2==1 and -1 or 1
  local z=i<3 and -1 or 1
  local hinge=Vector3.new(x*.22,.52,z*.19)
  local spread=(1-closed)*.21
  local elbow=Vector3.new(x*(size.X*.5+.055+spread),.09,z*(size.Z*.27+spread))
  local tip=Vector3.new(x*(size.X*.36+spread),-.20+spread*.4,z*(size.Z*.24+spread))
  for j,segment in ipairs(finger) do
   local a,b=hinge,elbow
   if j==2 then a,b=elbow,tip end
   segment.Size=Vector3.new(.12,.12,(b-a).Magnitude+.07)
   segment.CFrame=frame*CFrame.lookAt((a+b)*.5,b)
   segment.Transparency=visible and 0 or 1
  end
 end
end
-- Three concentric spheres breathe at different rates.
local function spheres(parent,color)
 local out={}
 for index,size in ipairs({.24,.46,.76}) do
  local globe=part(parent,'MiningSphere'..index);globe.Shape=Enum.PartType.Ball
  globe.Material=Enum.Material.Neon;globe.Color=index==1 and color:Lerp(WHITE,.18) or color
  table.insert(out,{part=globe,size=size,index=index})
 end
 return out
end
local function drawSpheres(record,now,strength,charge,pulse,color)
 if BeamVFX.reduced() then strength=0 end
 for _,sphere in ipairs(record.spheres) do
  local breathing=1+.035*math.sin(now*2.4+sphere.index*.85)
  local size=sphere.size*(record.scale or 1)*(.38+.18*charge)*breathing*(1+pulse*.08)
  sphere.part.Size=Vector3.one*math.max(.01,size)
  sphere.part.CFrame=record.anchor.CFrame*CFrame.new(0,0,-.08)
  sphere.part.Color=sphere.index==1 and color:Lerp(WHITE,.18) or color
  local opacity=({.30,.10,.025})[sphere.index]
  sphere.part.Transparency=1-math.clamp(strength,0,1)*opacity
 end
end
-- Roblox cylinders run along local X. One function owns all Part-laser poses.
function W.newCylinder(parent,name,color)
 local cylinder=part(parent,name);cylinder.Shape=Enum.PartType.Cylinder
 cylinder.Material=Enum.Material.Neon;cylinder.Color=color;cylinder.Reflectance=0
 return cylinder
end
function W.drawCylinder(cylinder,origin,target,diameter,transparency)
 local delta=target-origin;local length=delta.Magnitude
 if diameter<.002 or length<.015 then cylinder.Transparency=1;return end
 local axis=delta/length;local reference=math.abs(axis.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=axis:Cross(reference).Unit;local up=back:Cross(axis).Unit
 cylinder.Size=Vector3.new(length,diameter,diameter)
 cylinder.CFrame=CFrame.fromMatrix((origin+target)*.5,axis,up,back)
 cylinder.Transparency=math.clamp(transparency,0,1)
end
function W.new(parent)
 return setmetatable({parent=parent,miningBeams={},miningCount=0,maxMining=16,courierCount=0,maxCouriers=12,repairCount=0,maxRepairs=12,flightCount=0,maxFlightParticles=64,bursts={},maxBursts=14,orbitals={},scanAt=0},W)
end
function W:energyBloom()
 if self.bloom and self.bloom.Parent then return end
 local lighting=game:GetService('Lighting')
 local existing=lighting:FindFirstChild('MiningEnergyBloom')
 local bloom=existing or Instance.new('BloomEffect');bloom.Name='MiningEnergyBloom'
 bloom.Enabled=true;bloom.Intensity=.5;bloom.Size=20;bloom.Threshold=1.25;bloom.Parent=lighting
 self.bloom=bloom;self.ownsBloom=existing==nil
end
function W:burst(position,normal,color,count,now)
 if #self.bursts>=self.maxBursts or BeamVFX.reduced() or not cameraNear(position,140) then return end
 self:energyBloom()
 local anchor=part(self.parent,'WorkBurst');anchor.CFrame=facing(position,normal)
 local sparks=particle(anchor,'WorkSparks',color);sparks.Speed=NumberRange.new(6,11)
 sparks.Lifetime=NumberRange.new(.72,1.34);sparks.Drag=7;sparks.Acceleration=Vector3.zero
 EnergyDisc.configure(sparks,.90,.58,.53,.72)
 sparks.SpreadAngle=Vector2.new(65,65)
 sparks:Emit(math.min(12,math.ceil(count*.6)));table.insert(self.bursts,{part=anchor,untilAt=now+ENERGY_TAIL})
end
function W:cutAccent(position,normal,color,now)
 if #self.bursts>=self.maxBursts or BeamVFX.reduced() or not cameraNear(position,76) then return end
 local anchor=part(self.parent,'MiningContactAccent');anchor.CFrame=facing(position+normal*.11,normal)
 EnergyDisc.accent(anchor,'FacetStreaks',color:Lerp(WHITE,.52),.50,'streak',Enum.NormalId.Front,52):Emit(3)
 table.insert(self.bursts,{part=anchor,untilAt=now+.28})
end
function W:destroyMining(beam)
 local fx=beam.work
 if not fx then return end
 fx.impact:Destroy();if fx.tip then fx.tip:Destroy() end;fx.anchor:Destroy();beam.work=nil;self.miningBeams[beam]=nil;self.miningCount=math.max(0,self.miningCount-1)
end
function W:mining(beam,sample,point,normal,width,pulse,now)
 local charging=sample.charging and not sample.paused and sample.warmupStart>0
 local ink=sample.beamVariant=='Inkbeam'
 local working=sample.active and sample.isMining and not sample.paused and point~=nil and width>.001
 local visible=not BeamVFX.reduced() and sample.alive and sample.isMining and (charging or working or width>.001) and cameraNear(beam.origin.WorldPosition,95)
 local fx=beam.work
 if not visible then
  if fx then
   fx.sparks.Enabled=false;fx.glow.Enabled=false;fx.impact.Enabled=false
   if fx.contact then fx.contact.Transparency=1 end
   if fx.inner then fx.inner.Transparency=1 end
   for _,sphere in ipairs(fx.spheres) do sphere.part.Transparency=1 end
   if now-fx.lastAt>ENERGY_TAIL then self:destroyMining(beam) end
  end
  return
 end
 if not fx then
  if self.miningCount>=self.maxMining then return end
  self:energyBloom()
  local anchor=part(beam.holder,'OriginalMiningOrigin')
  fx={anchor=anchor,spheres=spheres(anchor,beam.tint or WHITE),lastAt=now,pulseSerial=sample.pulseSerial or 0}
  fx.sparks=particle(anchor,'OriginParticles',beam.tint or WHITE)
  fx.sparks.Brightness=1;fx.sparks.LightEmission=.55
  fx.glow=particle(anchor,'OriginGlow',beam.tint or WHITE)
  fx.glow.Brightness=.8;fx.glow.LightEmission=.4
  fx.glow.Speed=NumberRange.new(0);fx.glow.Lifetime=NumberRange.new(.5,1);fx.glow.Size=NumberSequence.new(.48)
  fx.tip=Instance.new('Attachment');fx.tip.Name='RockContact';fx.tip.Parent=beam.marker
  fx.impact=particle(fx.tip,'CuttingSparks',YELLOW)
  if ink then
   fx.accents={
    EnergyDisc.accent(anchor,'CyanDrops',Color3.fromRGB(49,246,237),.56,'mote',Enum.NormalId.Front,82),
    EnergyDisc.accent(anchor,'InkSplinters',Color3.fromRGB(16,8,33),.82,'ink',Enum.NormalId.Front,63),
    EnergyDisc.accent(fx.tip,'CyanContactMotes',Color3.fromRGB(57,246,225),.46,'mote',Enum.NormalId.Front,69),
    EnergyDisc.accent(fx.tip,'HotContactGlints',Color3.fromRGB(242,255,77),.68,'glint',Enum.NormalId.Front,54),
    EnergyDisc.accent(fx.tip,'YellowCutStreaks',Color3.fromRGB(255,225,50),.74,'streak',Enum.NormalId.Front,34),
   }
  end
  EnergyDisc.configure(fx.impact,.94,.47,.56,.63,.48)
  fx.impact.Lifetime=NumberRange.new(.48,.91);fx.impact.Speed=NumberRange.new(5,11)
  fx.impact.Acceleration=Vector3.new(0,-3,0);fx.impact.SpreadAngle=Vector2.new(72,72)
  -- Reuse the preserved original two-ball contact glows, at the real contact.
  local templates=game:GetService('ReplicatedStorage'):FindFirstChild('MiningFX')
  local template=templates and templates:FindFirstChild('MiningEffect')
  if template and template:IsA('BasePart') then
   fx.contact=template:Clone()
   for _,child in ipairs(fx.contact:GetChildren()) do child:Destroy() end
   fx.contact.Anchored=true;fx.contact.CanCollide=false;fx.contact.CanTouch=false;fx.contact.CanQuery=false;fx.contact.CastShadow=false
   fx.contact.Transparency=1;fx.contact.Parent=anchor
   local inner=template:FindFirstChild('InnerMiningEffect')
   if inner and inner:IsA('BasePart') then
    fx.inner=inner:Clone();fx.inner.Anchored=true;fx.inner.CanCollide=false;fx.inner.CanTouch=false;fx.inner.CanQuery=false
    fx.inner.CastShadow=false;fx.inner.Transparency=1;fx.inner.Parent=anchor
   end
  end
  beam.work=fx;self.miningBeams[beam]=true;self.miningCount+=1
 end
 if fx.key~=sample.key or fx.life~=sample.life then
  -- Already-emitted world-space light belongs to the previous contact. Let it
  -- finish naturally when changing rocks; only a new life invalidates the tail.
  if fx.life~=sample.life then fx.sparks:Clear();fx.glow:Clear();fx.impact:Clear();for _,e in ipairs(fx.accents or {}) do e:Clear() end end
  fx.key=sample.key;fx.life=sample.life
  fx.pulseSerial=sample.pulseSerial or 0;fx.biteAt=nil
 end
 if fx.contact then fx.contact.Transparency=1 end
 if fx.inner then fx.inner.Transparency=1 end
 fx.lastAt=now
 local origin=beam.origin.WorldPosition
 local direction=point and point-origin or Vector3.new(0,-1,0)
 if direction.Magnitude<.01 then direction=Vector3.new(0,-1,0) end
 direction=direction.Unit;fx.anchor.CFrame=facing(origin,direction)
 local q=charging and math.clamp(progress(now,sample.warmupStart,sample.warmupDuration)/.78,0,1) or 1
 if working and sample.style=='Percussion' then
  local at=(sample.pulseAt or 0)>0 and sample.pulseAt or sample.since
  q=math.clamp(progress(now,at or now,Mining.PULSE_INTERVAL)/.78,0,1)
 end
 local strength=charging and (.25+.75*q) or width
 drawSpheres(fx,now,strength,q,pulse,beam.tint or WHITE)
 local continuous=sample.style~='Percussion'
 fx.sparks.Rate=2;fx.sparks.Enabled=working
 fx.glow.Rate=charging and 1.5 or .8;fx.glow.Enabled=working
 local resonance=sample.style=='Resonance'
 local impactColor=sample.mineralColor or (resonance and (beam.tint or WHITE) or YELLOW)
 if fx.impactColor~=impactColor then fx.impactColor=impactColor;fx.impact.Color=ColorSequence.new(impactColor) end
 -- Random emission directions give individual sparks variety without a
 -- shared lateral force pushing the whole cloud like wind.
 fx.impact.Acceleration=resonance and Vector3.zero or Vector3.new(0,-3,0)
 fx.impact.Drag=resonance and 5 or 4
 -- Keep the large discs readable when an entire pinned field lights up.
 local crowded=self.miningCount>8
 fx.impact.Rate=continuous and (crowded and 3 or (ink or resonance) and 4 or 6) or 0
 fx.impact.Enabled=working and continuous
 if point and normal then beam.marker.CFrame=facing(point+normal*.2,normal) end
 if fx.accents and working then
  if (not fx.nextInkAccent or now>=fx.nextInkAccent) then
   fx.nextInkAccent=now+.29
   fx.inkAccent=(fx.inkAccent or 0)+1
   local index=fx.inkAccent%3
   fx.accents[index==0 and 1 or index==1 and 3 or 4]:Emit(1)
  end
 end
 if working and fx.releaseAt~=sample.since then
  fx.releaseAt=sample.since
  if sample.since and now>=sample.since and now-sample.since<.15 then
   fx.biteAt=now;fx.impact:Emit(crowded and 4 or 8);fx.sparks:Emit(crowded and 1 or 3)
   if fx.accents then for i,e in ipairs(fx.accents) do e:Emit(i==1 and 3 or 2) end end
  end
 end
 if sample.pulseSerial~=fx.pulseSerial then
  if working and sample.pulseAt and now-sample.pulseAt<.25 then
   fx.biteAt=now;fx.impact:Emit(crowded and 4 or 8);fx.sparks:Emit(crowded and 1 or 3)
  end
  fx.pulseSerial=sample.pulseSerial
 end
 if point and normal then
  if fx.contact then
   local bite=math.max(0,1-(now-(fx.biteAt or -100))/.13)^2
   fx.contact.CFrame=CFrame.new(point+normal*.05)
   fx.contact.Size=Vector3.one*(.22+.18*width+.08*pulse+.26*bite)
   fx.contact.Color=(beam.tint or WHITE):Lerp(YELLOW,bite*.32);fx.contact.Transparency=working and (.68-.05*pulse-.15*bite) or 1
   if fx.inner then
    fx.inner.CFrame=CFrame.new(point+normal*.06);fx.inner.Size=Vector3.one*(.09+.05*pulse+.15*bite)
    fx.inner.Color=(beam.tint or WHITE):Lerp(WHITE,.25+.53*bite);fx.inner.Transparency=working and (.45-.15*bite) or 1
   end
  end
 end
end
local function backpackPosition(source)
 local owner=Players:GetPlayerByUserId(source:GetAttribute('Owner') or 0)
 local ch=owner and owner.Character
 local torso=ch and (ch:FindFirstChild('UpperTorso') or ch:FindFirstChild('Torso') or ch:FindFirstChild('HumanoidRootPart'))
 return torso and torso.CFrame:PointToWorldSpace(Vector3.new(0,.15,.9))
end
function W:destroyCourier(record)
 if record.courier then
  if record.courier.detailed then self.courierCount=math.max(0,self.courierCount-1) end
  BeamVFX.destroy(record.courier.tetherVFX)
  record.courier.root:Destroy();record.courier=nil
 end
end
function W:destroyDrone(record)
 for _,rocket in ipairs(record.rockets or {}) do rocket.attachment:Destroy() end;record.rockets=nil
 self:destroyCourier(record)
 if record.repair then record.repair.anchor:Destroy();record.repair=nil;self.repairCount=math.max(0,self.repairCount-1) end
 if record.flight then
  for _,object in ipairs(record.flight.objects) do object:Destroy() end
  if record.flight.wisp then self.flightCount=math.max(0,self.flightCount-1) end
  record.flight=nil
 end
end
function W:flight(drone,record,dt,now)
 local root=drone.view.PrimaryPart or drone.emitter
 if not root or not root.Parent then return end
 local source=drone.source
 local powered=source:GetAttribute('State')=='BreakerDive' and source:GetAttribute('MotionPaused')~=true and source:GetAttribute('WorkPaused')~=true
 if powered and not record.rockets then
  record.rockets={}
  for _,side in ipairs({-1,1}) do
   local nozzle=Instance.new('Attachment');nozzle.Name='BreakerRocket';nozzle.Position=Vector3.new(side*.4,.35,0);nozzle.Parent=root
   local jet=particle(nozzle,'RocketExhaust',Color3.fromRGB(255,178,66))
   jet.EmissionDirection=Enum.NormalId.Top;jet.SpreadAngle=Vector2.new(9,9);jet.Speed=NumberRange.new(4,8);jet.Drag=3.5
   jet.Lifetime=NumberRange.new(.16,.32);jet.Acceleration=Vector3.new(0,1.2,0);jet.Rate=20;jet.LightEmission=.7;jet.Brightness=1.4
   jet.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,0)})
   table.insert(record.rockets,{attachment=nozzle,jet=jet})
  end
 end
 for _,rocket in ipairs(record.rockets or {}) do rocket.jet.Enabled=powered and not BeamVFX.reduced() end
 local fx=record.flight
 if not fx then
  fx={objects={},trails={},position=root.Position,life=source:GetAttribute('Life')};record.flight=fx
  local role=source:GetAttribute('Role')
  local span=role=='Medic' and .25 or role=='Courier' and .48 or math.max(.25,root.Size.X*.34)
  for _,side in ipairs({-1,1}) do
   local a=Instance.new('Attachment');a.Name='FlightTrailTop';a.Position=Vector3.new(side*span,-.03,span*.65);a.Parent=root
   local b=Instance.new('Attachment');b.Name='FlightTrailBottom';b.Position=a.Position-Vector3.new(0,.065,0);b.Parent=root
   local trail=Instance.new('Trail');trail.Name='DroneFlightTrail';trail.Attachment0=a;trail.Attachment1=b
   trail.Lifetime=.28;trail.MinLength=.04;trail.FaceCamera=true;trail.LightEmission=.2
   trail.Color=ColorSequence.new(drone.emitter.Color)
   trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.45,.8),NumberSequenceKeypoint.new(1,1)})
   trail.Enabled=false;trail.Parent=root
   table.insert(fx.objects,a);table.insert(fx.objects,b);table.insert(fx.objects,trail);table.insert(fx.trails,trail)
  end
  if self.flightCount<self.maxFlightParticles then
   local a=Instance.new('Attachment');a.Name='HoverExhaust'
   a.Position=(role~='Medic' and role~='Courier' and drone.beam and drone.beam.origin.Position) or Vector3.zero;a.Parent=drone.emitter
   local wisp=particle(a,'FlightWisp',drone.emitter.Color)
   wisp.EmissionDirection=Enum.NormalId.Bottom
   wisp.Lifetime=NumberRange.new(.6,1.1);wisp.Speed=NumberRange.new(.15,.35);wisp.Acceleration=Vector3.new(0,-.12,0);wisp.Drag=2.2
   wisp.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(.55,.12),NumberSequenceKeypoint.new(1,.16)})
   wisp.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.82),NumberSequenceKeypoint.new(1,1)})
   wisp.LightEmission=.15;wisp.Brightness=.8;wisp.Rate=3;fx.wisp=wisp;self.flightCount+=1;table.insert(fx.objects,a)
  end
 end
 local distance=(root.Position-fx.position).Magnitude
 local speed=dt>0 and distance/math.max(dt,1/240) or 0
 local state=source:GetAttribute('State');local alive=not record.events.dead and state~='Destroyed' and state~='Reprinting'
 -- Flight remains visible during healthy storage; only work effects pause.
 local paused=source:GetAttribute('MotionPaused')==true
 local reset=fx.life~=source:GetAttribute('Life') or distance>8 or not alive
 for _,trail in ipairs(fx.trails) do
  if reset then trail:Clear() end
  trail.Enabled=alive and not paused and not BeamVFX.reduced() and speed>.6 and not reset
 end
 if fx.wisp then
  if reset then fx.wisp:Clear() end
  fx.wisp.Enabled=alive and not paused and not BeamVFX.reduced() and cameraNear(root.Position,100)
  fx.wisp.Rate=1+math.min(3,speed*.25)
 end
 fx.position=root.Position;fx.life=source:GetAttribute('Life')
end
function W:repair(drone,record,now)
 local s=drone.source;local charging=s:GetAttribute('State')=='RepairCharge'
 local healing=s:GetAttribute('Healing')==true
 local active=not BeamVFX.reduced() and s:GetAttribute('Role')=='Medic' and not record.events.dead and s:GetAttribute('MotionPaused')~=true and s:GetAttribute('WorkPaused')~=true and (charging or healing) and cameraNear(drone.pos,90)
 local fx=record.repair
 if not active then
  if fx then
   fx.sparks.Enabled=false
   drawSpheres(fx,now,0,0,0,WHITE)
   if now-fx.lastAt>ENERGY_TAIL then fx.anchor:Destroy();record.repair=nil;self.repairCount=math.max(0,self.repairCount-1) end
  end
  return
 end
 local color=Color3.fromRGB(126,233,160)
 if not fx then
  if self.repairCount>=self.maxRepairs then return end
  local anchor=part(self.parent,'RepairCapacitor');fx={anchor=anchor,spheres=spheres(anchor,color),scale=.42,lastAt=now}
  fx.sparks=particle(anchor,'RepairParticles',color);fx.sparks.Brightness=1.2;fx.sparks.LightEmission=.65
  record.repair=fx;self.repairCount+=1
 end
 fx.lastAt=now;fx.anchor.CFrame=facing(drone.emitter.Position,Vector3.new(0,-1,0))
 local q=charging and progress(now,s:GetAttribute('RepairChargeAt') or now,s:GetAttribute('RepairChargeDuration') or .4) or 1
 drawSpheres(fx,now,charging and .3+.7*q or 1,q,healing and .5 or 0,color)
 fx.sparks.Rate=charging and 3+q*4 or 8;fx.sparks.Enabled=true
end
function W:courier(drone,record,now)
 local source=drone.source;local state=source:GetAttribute('State')
 local snapPosition
 drone.cargoMount=nil
 local enabled=source:GetAttribute('Role')=='Courier' and not record.events.dead and cameraNear(drone.pos,200)
 local fx=record.courier
 if not enabled then self:destroyCourier(record);return end
 local parcelUnits=source:GetAttribute('DeliveryUnits') or 0
 local slots=source:GetAttribute('DeliverySlots') or 0
 local busy=state=='Pickup' or state=='Unload' or parcelUnits>0 or slots>0 and cameraNear(drone.pos,105)
 if not busy and not fx then return end
 if fx and not busy and now-fx.lastAt>ENERGY_TAIL then self:destroyCourier(record);return end
 if not fx then
  local detailed=self.courierCount<self.maxCouriers
  local root=Instance.new('Folder');root.Name='CourierWork';root.Parent=self.parent
  local anchor=part(root,'TransferOrigin');local contact=part(root,'BackpackContact')
  local tether=W.newCylinder(root,'PickupTether',GOLD)
  local parcel=part(root,'CourierParcel');parcel.Size=Vector3.new(.62,.42,.5);parcel.Material=Enum.Material.WoodPlanks;parcel.Color=Color3.fromRGB(171,139,79)
  local band=part(root,'ParcelLatch');band.Size=Vector3.new(.65,.07,.53);band.Material=Enum.Material.Metal;band.Color=GOLD
  local drive=part(root,'CourierWake');local trails={}
  if detailed then for _,side in ipairs({-1,1}) do
   local top=Instance.new('Attachment');top.Position=Vector3.new(side*.38,.025,.25);top.Parent=drive
   local bottom=Instance.new('Attachment');bottom.Position=Vector3.new(side*.38,-.025,.25);bottom.Parent=drive
   local trail=Instance.new('Trail');trail.Name='LoadedFlightTrail';trail.Attachment0=top;trail.Attachment1=bottom
   trail.Lifetime=.32;trail.MinLength=.04;trail.FaceCamera=true;trail.LightEmission=.25
   trail.Color=ColorSequence.new(GOLD);trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,1)})
   trail.Enabled=false;trail.Parent=root;table.insert(trails,trail)
  end end
  fx={root=root,anchor=anchor,contact=contact,tether=tether,parcel=parcel,band=band,drive=drive,trails=trails,mounts={},spheres=detailed and spheres(anchor,GOLD) or {},detailed=detailed,closedOre=0,sale=source:GetAttribute('CourierSaleSerial') or 0,loadId=source:GetAttribute('DeliveryId') or '',lastAt=now}
  if detailed then
   fx.sparks=particle(anchor,'CourierSparks',GOLD);fx.sparks.Brightness=1.2;fx.sparks.LightEmission=.65;self.courierCount+=1
  end
  record.courier=fx
 end
 if busy then fx.lastAt=now end
 local paused=source:GetAttribute('MotionPaused')==true or source:GetAttribute('WorkPaused')==true
 local reduced=BeamVFX.reduced()
 local mountScale=drone.view:GetScale()/.94
 local pivot=drone.view:GetPivot();local mount=pivot:PointToWorldSpace(Vector3.new(0,-.86,0)*mountScale)
 for _,trail in ipairs(fx.trails) do trail.Enabled=not reduced and state=='Deliver' and parcelUnits>0 and not paused and now-(source:GetAttribute('SnapshotAt') or 0)<.5 end
 local pickupPoint
 if slots==0 and (state=='Pickup' or state=='Launch') then pickupPoint=backpackPosition(source) end
 local sale=source:GetAttribute('CourierSaleSerial') or 0;local sell=source:GetAttribute('SellPosition')
 local saleAge=now-(source:GetAttribute('CourierSaleAt') or 0)
 if sale>fx.sale and typeof(sell)=='Vector3' and saleAge>=-.1 and saleAge<.7 then
  self:burst(sell+Vector3.yAxis*(slots>0 and .18 or 1),Vector3.yAxis,GOLD,slots>0 and 7 or 18,now)
 end
 fx.sale=sale
 local pickup=state=='Pickup' and typeof(pickupPoint)=='Vector3' and (pickupPoint-mount).Magnitude<=6 and not paused and now-(source:GetAttribute('SnapshotAt') or 0)<.5
 local unload=state=='Unload' and typeof(sell)=='Vector3'
 if unload then
  local sampleAt=paused and (source:GetAttribute('SnapshotAt') or now) or now
  fx.unloadProgress=paused and fx.unloadProgress or progress(sampleAt,source:GetAttribute('CourierUnloadAt') or now,source:GetAttribute('CourierUnloadHold') or .65)
 else fx.unloadProgress=nil end
 local launch=source:GetAttribute('CourierLaunchAt') or 0
 local pickupAt=source:GetAttribute('CourierPickupAt') or 0
 local q=pickup and progress(now,pickupAt,source:GetAttribute('CourierPickupHold') or .55) or 1
 local loadId=source:GetAttribute('DeliveryId') or ''
 if loadId~='' and loadId~=fx.loadId and launch>0 and now-launch<.5 then self:burst(mount,Vector3.new(0,-1,0),GOLD,8,now) end
 fx.loadId=loadId
 if pickup then drone.view:PivotTo(pivot*CFrame.new(0,-.10*math.sin(q*math.pi),0))
 elseif state=='Launch' and launch>0 then
  local t=progress(now,launch,source:GetAttribute('CourierLaunchHold') or .25)
  drone.view:PivotTo(pivot*CFrame.new(0,math.sin(t*math.pi)*.18,0))
 end
 pivot=drone.view:GetPivot();mount=pivot:PointToWorldSpace(Vector3.new(0,-.86,0)*mountScale)
 fx.drive.CFrame=pivot;fx.anchor.CFrame=facing(mount,Vector3.new(0,-1,0))
 drawSpheres(fx,now,pickup and .3+.7*q or unload and slots==0 and .7 or 0,q,0,GOLD)
 if pickup then
  fx.tetherVFX=fx.tetherVFX or BeamVFX.new(fx.root,'Courier',GOLD)
  if fx.tetherVFX then
   fx.tether.Transparency=1;BeamVFX.draw(fx.tetherVFX,mount,pickupPoint,now,.45+.55*q,nil,nil)
  else W.drawCylinder(fx.tether,mount,pickupPoint,.045+.025*q,.5-.2*q) end
 else
  fx.tether.Transparency=1;BeamVFX.destroy(fx.tetherVFX);fx.tetherVFX=nil
 end
 if fx.sparks then
  fx.sparks.Rate=pickup and 4+q*5 or unload and slots==0 and 6 or 0
  fx.sparks.Enabled=not paused and not reduced and (pickup or unload and slots==0)
 end
 local parcelScale=math.clamp((math.max(1,parcelUnits)/8)^(1/3),1,1.6)
 fx.parcel.Size=Vector3.new(1.05,.66,.83)*parcelScale;fx.band.Size=Vector3.new(1.08,.09,.86)*parcelScale
 fx.parcel.Transparency=parcelUnits>0 and slots==0 and 0 or 1
 fx.band.Transparency=fx.parcel.Transparency
 if parcelUnits>0 then
  local position=mount
  local transfer=launch>0 and progress(now,launch,source:GetAttribute('CourierLaunchHold') or .25) or 1
  if transfer<1 and slots==0 and pickupPoint and (pickupPoint-mount).Magnitude<=6 then
   local t=transfer*transfer*(3-2*transfer)
   position=pickupPoint:Lerp(mount,t)+Vector3.new(0,math.sin(t*math.pi)*.35,0)
  elseif unload then
   local t=fx.unloadProgress
   -- Hold the parcel just above the converter until the server confirms sale.
   local finish=sell+Vector3.new(0,1.25,0)
   position=mount:Lerp(finish,t*.9)+Vector3.new(math.sin(t*math.pi)*.18,math.sin(t*math.pi)*.3,0)
  end
  fx.parcel.CFrame=CFrame.new(position)*pivot.Rotation
  fx.band.CFrame=fx.parcel.CFrame
 end
 if slots>0 then
  local materials=source:GetAttribute('DeliveryMaterials') or ''
  if materials~=fx.materials then fx.materials=materials;fx.load=string.split(materials,';') end
  local count=math.min(6,math.max(slots,parcelUnits))
  if saleAge>=0 and saleAge<.21 then count=math.max(count,#fx.mounts) end
  local loadedId=source:GetAttribute('CourierLoadedOre')
  local loadedMaterial=source:GetAttribute('CourierLoadedMaterial')
  local loadAge=now-(source:GetAttribute('CourierLoadedAt') or 0)
  local loadingSlot
  if loadedId and loadedId>0 and loadAge<.55 and not unload then
   for i=math.min(parcelUnits,6),1,-1 do
    if fx.load[i]==loadedMaterial then loadingSlot=i;break end
   end
  end
  local docking=state=='Pickup' and typeof(source:GetAttribute('CourierDock'))=='Vector3'
  local dockClock=paused and (source:GetAttribute('SnapshotAt') or now) or now
  local pickupAge=drone.pickupAge or dockClock-pickupAt
  local _,grip=Workshop.courierStroke(pickupAge)
  local speed=drone.velocity and drone.velocity.Magnitude or 0
  local moving=fx.detailed and not reduced and not paused and not unload and speed>2.4
   and now-(source:GetAttribute('SnapshotAt') or 0)<.5
  if count>4 and not fx.rackExtensions then
   fx.rackExtensions={}
   for i=1,2 do
    local rail=part(fx.root,'ClawRackExtension');rail.Size=Vector3.new(.19,.20,2.1)
    rail.Material=Enum.Material.Metal;rail.Color=Color3.fromRGB(58,68,80)
    fx.rackExtensions[i]=rail
   end
  end
  for i,rail in ipairs(fx.rackExtensions or {}) do
   rail.CFrame=pivot*CFrame.new(i==1 and -.98 or .98,-.38,-1.74)
   rail.Transparency=count>4 and 0 or 1
  end
  for i=1,count do
   local slot=fx.mounts[i]
   if not slot then
    local hub=part(fx.root,'ClawHub');hub.Size=Vector3.new(.63,.23,.60)
    hub.Material=Enum.Material.Metal;hub.Color=Color3.fromRGB(75,84,93)
    slot={hub=hub,fingers={}};fx.mounts[i]=slot
    for j=1,4 do
     local link=part(fx.root,'ClawFinger');link.Material=Enum.Material.Metal;link.Color=Color3.fromRGB(119,133,145)
     local tip=part(fx.root,'ClawTip');tip.Material=Enum.Material.Metal;tip.Color=Color3.fromRGB(66,78,90)
     slot.fingers[j]={link,tip}
    end
   end
   local side=i%2==1 and -1 or 1
   local row=math.floor((i-1)/2)
   local x,y,z,yaw=Workshop.courierClawOffset(i)
   local cargoFrame=pivot*CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0)
   local size=slot.cargo and slot.cargo.Size or cargoRawSize
   local closed=i<=parcelUnits and 1 or .72
   local beforeContact=docking and pickupAge<Workshop.COURIER_CONTACT
   local receiving=docking and i==parcelUnits+1 and not loadingSlot
   if i==loadingSlot then
    if beforeContact then closed=grip end
    if not beforeContact and loadAge>=0 and fx.closedOre~=loadedId then
     fx.closedOre=loadedId
     if loadAge<.23 then snapPosition=cargoFrame.Position end
    end
   elseif receiving then
    closed=grip
    size=source:GetAttribute('CourierPacked') and cargoBlockSize or cargoRawSize
   elseif unload then
    closed=1-math.clamp((fx.unloadProgress-(i-1)*.045)/.19,0,1)
   end
   if i<=parcelUnits then
    local material=fx.load[i] or ''
    if slot.material~=material then
     slot.material=material
     local key,_,packed=Workshop.crystalCargo(material)
     local tier=key and Workshop.CRYSTAL_BY_MATERIAL[key]
     packed=packed==true
     if not slot.cargo or slot.packed~=packed then
      if slot.cargo then slot.cargo:Destroy() end
      local mesh
      if not packed then
       local net=RS:FindFirstChild('MiningAway')
       local original=workspace:FindFirstChild('Crystal')
       mesh=(net and net:FindFirstChild('CargoCrystal')) or (original and original:FindFirstChild('Mesh'))
      end
      slot.cargo=part(fx.root,'MountedCargo',mesh and mesh:IsA('UnionOperation') and mesh or nil)
      if slot.cargo:IsA('PartOperation') then slot.cargo.UsePartColor=true end
      slot.cargo.Material=packed and Enum.Material.Metal or Enum.Material.SmoothPlastic
      slot.cargo.MaterialVariant='';slot.cargo.Reflectance=packed and 0 or Workshop.RAW_CRYSTAL_REFLECTANCE
      slot.dust=fx.detailed and cargoDust(slot.cargo) or nil
     end
     local rgb=Shops.COLORS[tier and tier.name or material]
     slot.cargo.Color=not packed and Color3.fromRGB(table.unpack(Workshop.RAW_CRYSTAL_COLOR))
      or rgb and Color3.fromRGB(table.unpack(rgb)) or GOLD
     slot.cargo.Size=packed and cargoBlockSize or cargoRawSize
     if slot.dust then slot.dust.Color=ColorSequence.new(slot.cargo.Color:Lerp(WHITE,.52),slot.cargo.Color) end
     slot.packed=packed
    end
    local cargo=slot.cargo
    cargo.Transparency=(i==loadingSlot and beforeContact) and 1 or 0
    local position=cargoFrame.Position
    local rotation=cargoFrame.Rotation
    size=cargo.Size
    if unload then
     local t=math.clamp((fx.unloadProgress-(i-1)*.045)/.64,0,1)
     local ease=t*t*(3-2*t)
     local finish=sell+Vector3.new(side*.93,cargo.Size.Y*.5+.015,row*1.65-.8)
     position=position:Lerp(finish,ease)
     if not reduced then position+=Vector3.yAxis*(math.sin(t*math.pi)*.32) end
     rotation=rotation:Lerp(CFrame.Angles(0,yaw,0),ease)
    end
    cargo.CFrame=CFrame.new(position)*rotation
    if i==loadingSlot and not beforeContact then
     local mount=fx.loadingMount or {}
     fx.loadingMount=mount;mount.id=loadedId;mount.frame=cargo.CFrame
     drone.cargoMount=mount
    end
    if slot.dust then
     slot.dust.Enabled=moving and cargo.Transparency<1 and i<=4
     slot.dust.Rate=math.clamp(speed*.68,3,11)
    end
   elseif slot.cargo then
    slot.cargo.Transparency=saleAge>=0 and saleAge<.21 and math.clamp(saleAge/.21,0,1) or 1
    if slot.dust then slot.dust.Enabled=false end
   end
   drawClaw(slot,cargoFrame,size,closed,i<=parcelUnits or receiving)
  end
  for i=count+1,#fx.mounts do
   local slot=fx.mounts[i];slot.hub.Transparency=1
   for _,finger in ipairs(slot.fingers) do for _,segment in ipairs(finger) do segment.Transparency=1 end end
   if slot.cargo then slot.cargo.Transparency=1 end
   if slot.dust then slot.dust.Enabled=false end
  end
 end
 return snapPosition
end
-- A monochrome beam with alternating opaque/clear bands. Shift the sequence
-- along its normalized length, so the pulse remains fast at every frame rate.
-- Two broad bands give the ramp more scale without hiding the physical core.
-- Ten or fewer keys stay inside Roblox's twenty-key NumberSequence limit.
function W.orbitalTransparency(now,minimum)
 local phase=(now*7)%1
 local function opacity(t)
  local x=(t*2+phase)%1
  if x<.22 then return .04 elseif x<.32 then return .04+.96*(x-.22)/.1
  elseif x<.88 then return 1 else return 1-.96*(x-.88)/.12 end
 end
 local keys={NumberSequenceKeypoint.new(0,opacity(0))}
 for i=-1,4 do for _,point in ipairs({{0,.04},{.22,.04},{.32,1},{.88,1}}) do
  local t=(i+point[1]-phase)/2
  if t>0 and t<1 then table.insert(keys,NumberSequenceKeypoint.new(t,point[2])) end
 end end
 table.insert(keys,NumberSequenceKeypoint.new(1,opacity(1)))
 if minimum then
  for i,key in ipairs(keys) do keys[i]=NumberSequenceKeypoint.new(key.Time,minimum+(1-minimum)*key.Value) end
 end
 return NumberSequence.new(keys)
end
function W:orbital(now)
 if now>=self.scanAt then
  self.scanAt=now+.2
  local source=workspace:FindFirstChild('DroneRoleClientEffects')
  if source then for _,group in ipairs(source:GetChildren()) do
   local position=group:GetAttribute('Position')
   if group:GetAttribute('OrbitalBurn') and not self.orbitals[group] and not group:GetAttribute('EndedAt')
    and typeof(position)=='Vector3' and cameraAbove(position,180) then
    local holder=part(self.parent,'OrbitalEnergyRamp')
    local bottom=Instance.new('Attachment');bottom.Parent=holder
    local top=Instance.new('Attachment');top.Parent=holder
    local ramp=Instance.new('Beam');ramp.Name='DescendingWhiteClearEnergy'
    ramp.Attachment0=bottom;ramp.Attachment1=top;ramp.FaceCamera=true;ramp.Segments=48
    ramp.Color=ColorSequence.new(Color3.new(1,1,1));ramp.LightEmission=1;ramp.LightInfluence=0;ramp.Brightness=.7
    ramp.Width0=.72;ramp.Width1=.72;ramp.Parent=holder
    -- The local physical cylinder stays visible through the clear ramp bands.
    self.orbitals[group]={holder=holder,bottom=bottom,top=top,ramp=ramp,
     vfx=BeamVFX.new(holder,'Orbital',Color3.fromRGB(171,111,255))}
    self:energyBloom()
   end
  end end
 end
 for group,record in pairs(self.orbitals) do
  local position=group:GetAttribute('Position')
  local ended=group:GetAttribute('EndedAt')
  local strength=ended and (1-progress(now,ended,.48))^2 or 1
  if not group.Parent or typeof(position)~='Vector3' or strength<.002 then
   BeamVFX.destroy(record.vfx);record.holder:Destroy();self.orbitals[group]=nil
  else
   local camera=workspace.CurrentCamera
   local contactAt=group:GetAttribute('ContactAt')
   -- A yielding save or a stalled contact stream must not leave a cosmetic
   -- strike drilling after authoritative work has paused.
   record.ramp.Enabled=ended~=nil or contactAt==nil or now-contactAt<.3
   local height=math.max(260,(camera and camera.CFrame.Position.Y or position.Y)-position.Y+180)
   record.holder.CFrame=CFrame.new(position)
   record.bottom.Position=Vector3.zero;record.top.Position=Vector3.new(0,height,0)
   record.ramp.Width0=.72*strength;record.ramp.Width1=record.ramp.Width0
   record.ramp.Transparency=W.orbitalTransparency(now,.7)
   if ended then
    BeamVFX.after(record.vfx,position+Vector3.yAxis*.12,position+Vector3.yAxis*height,now,now-ended)
   elseif record.ramp.Enabled then
    BeamVFX.draw(record.vfx,position+Vector3.yAxis*.12,position+Vector3.yAxis*height,now,strength,nil,now-(group:GetAttribute('StartedAt') or now))
   else BeamVFX.hide(record.vfx,true) end
  end
 end
end
function W:update(now)
 self:orbital(now)
 for i=#self.bursts,1,-1 do
  local item=self.bursts[i]
  if now>=item.untilAt then item.part:Destroy();table.remove(self.bursts,i) end
 end
end
function W:destroy()
 for beam in pairs(self.miningBeams) do self:destroyMining(beam) end
 for _,item in ipairs(self.bursts) do item.part:Destroy() end;self.bursts={}
 for _,record in pairs(self.orbitals) do
  BeamVFX.destroy(record.vfx);record.holder:Destroy()
 end;self.orbitals={}
 if self.ownsBloom and self.bloom then self.bloom:Destroy() end;self.bloom=nil
end
return W
