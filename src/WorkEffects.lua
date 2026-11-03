-- Attached, bounded work choreography. Server timestamps drive every phase;
-- these visuals never remove ore, credit a sale, heal, or advance mining.
local W={};W.__index=W
local Players=game:GetService('Players')
local GOLD=Color3.fromRGB(244,193,89)
local WHITE=Color3.fromRGB(236,249,255)
local ENERGY='rbxasset://textures/ui/VR/circleWhite.png'
local YELLOW=Color3.fromRGB(255,208,69)
local ENERGY_TAIL=1.8
local function part(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Size=Vector3.one*.05;p.Transparency=1
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
 -- A soft plain disc instead of stars/smoke: the energy reads as light,
 -- including at small screen sizes. Keep the original asset templates intact.
 p.Texture=ENERGY;p.Squash=NumberSequence.new(0)
 p.Color=ColorSequence.new(color);p.LightEmission=.8;p.LightInfluence=0;p.Brightness=1.8
 p.TimeScale=1;p.LockedToPart=false;p.VelocityInheritance=0;p.FlipbookLayout=Enum.ParticleFlipbookLayout.None
 p.EmissionDirection=Enum.NormalId.Front;p.Orientation=Enum.ParticleOrientation.FacingCamera
 p.Lifetime=NumberRange.new(.65,1.2);p.Speed=NumberRange.new(.4,1.2);p.Drag=2.4
 p.SpreadAngle=Vector2.new(45,45);p.Acceleration=Vector3.new(0,-.6,0);p.WindAffectsDrag=true
 p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.4),NumberSequenceKeypoint.new(.2,.65),NumberSequenceKeypoint.new(1,0)})
 p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(.55,.42),NumberSequenceKeypoint.new(1,1)})
 p.Parent=parent;return p
end
-- Three concentric sphere Parts, not orbiting rings. Different phases keep
-- the nested glow breathing without sudden size or transparency changes.
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
 for _,sphere in ipairs(record.spheres) do
  local breathing=1+.16*math.sin(now*4+sphere.index*.85)
  local size=sphere.size*(record.scale or 1)*(.75+.25*charge)*breathing*(1+pulse*.12)
  sphere.part.Size=Vector3.one*math.max(.01,size)
  sphere.part.CFrame=record.anchor.CFrame*CFrame.new(0,0,-.08)
  sphere.part.Color=sphere.index==1 and color:Lerp(WHITE,.18) or color
  local opacity=({.45,.22,.08})[sphere.index]
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
 if #self.bursts>=self.maxBursts or not cameraNear(position,140) then return end
 self:energyBloom()
 local anchor=part(self.parent,'WorkBurst');anchor.CFrame=facing(position,normal)
 local sparks=particle(anchor,'WorkSparks',color);sparks.Speed=NumberRange.new(2,5)
 sparks.Lifetime=NumberRange.new(1,1.6);sparks.Drag=1.8;sparks.Acceleration=Vector3.new(0,-.8,0)
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.7,.08),NumberSequenceKeypoint.new(.18,1.05,.15),NumberSequenceKeypoint.new(1,0)})
 sparks.SpreadAngle=Vector2.new(65,65)
 sparks:Emit(math.min(42,count));table.insert(self.bursts,{part=anchor,untilAt=now+ENERGY_TAIL})
end
function W:destroyMining(beam)
 local fx=beam.work
 if not fx then return end
 fx.impact:Destroy();if fx.tip then fx.tip:Destroy() end;fx.anchor:Destroy();beam.work=nil;self.miningBeams[beam]=nil;self.miningCount=math.max(0,self.miningCount-1)
end
function W:mining(beam,sample,point,normal,width,pulse,now)
 local charging=sample.charging and not sample.paused and sample.warmupStart>0
 local working=sample.active and sample.isMining and not sample.paused and point~=nil and width>.001
 local visible=sample.alive and sample.isMining and (charging or working or width>.001) and cameraNear(beam.origin.WorldPosition,95)
 local fx=beam.work
 if not visible then
  if fx then
   fx.sparks.Enabled=false;fx.glow.Enabled=false;fx.impact.Enabled=false
   if fx.contact then fx.contact.Transparency=1 end
   if fx.inner then fx.inner.Transparency=1 end
   for _,sphere in ipairs(fx.spheres) do sphere.part.Transparency=1 end
   if sample.paused or not sample.alive then fx.sparks:Clear();fx.glow:Clear();fx.impact:Clear() end
   if not sample.alive or now-fx.lastAt>ENERGY_TAIL then self:destroyMining(beam) end
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
  fx.glow.Speed=NumberRange.new(0);fx.glow.Lifetime=NumberRange.new(.5,1);fx.glow.Size=NumberSequence.new(.3)
  fx.tip=Instance.new('Attachment');fx.tip.Name='RockContact';fx.tip.Parent=beam.marker
  fx.impact=particle(fx.tip,'CuttingSparks',YELLOW)
  fx.impact.Lifetime=NumberRange.new(.85,1.35);fx.impact.Speed=NumberRange.new(2,4)
  fx.impact.Drag=2.4;fx.impact.Acceleration=Vector3.new(0,-2,0);fx.impact.SpreadAngle=Vector2.new(80,80)
  fx.impact.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35,.03),NumberSequenceKeypoint.new(.15,.55,.05),NumberSequenceKeypoint.new(1,0)})
  fx.impact.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(.7,.45),NumberSequenceKeypoint.new(1,1)})
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
  if fx.life~=sample.life then fx.sparks:Clear();fx.glow:Clear();fx.impact:Clear() end
  fx.key=sample.key;fx.life=sample.life
  fx.pulseSerial=sample.pulseSerial or 0
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
 fx.sparks.Rate=charging and (1+3*q) or 2;fx.sparks.Enabled=charging or working
 fx.glow.Rate=charging and 1.5 or .8;fx.glow.Enabled=charging or working
 local resonance=sample.style=='Resonance'
 fx.impact.Color=ColorSequence.new(resonance and (beam.tint or WHITE) or YELLOW)
 -- Smooth low-frequency sideways acceleration gives each tool its own
 -- turbulence without moving contacts or inventing damage events.
 local noise=math.noise(now*(resonance and 2.5 or .8),origin.X*.11,origin.Z*.11)
 local turbulence=resonance and 1 or .25
 fx.impact.Acceleration=Vector3.new(noise*turbulence,resonance and -.6 or -2,math.noise(origin.Z*.17,now*.9)*turbulence)
 fx.impact.Drag=resonance and 2 or 2.4
 fx.impact.Rate=continuous and (resonance and 10 or 12) or 0;fx.impact.Enabled=working and continuous
 if point and normal then
  beam.marker.CFrame=facing(point+normal*.2,normal)
  if fx.contact then
   fx.contact.CFrame=CFrame.new(point+normal*.05)
   fx.contact.Size=Vector3.one*(.22+.18*width+.08*pulse)
   fx.contact.Color=beam.tint or WHITE;fx.contact.Transparency=working and (.68-.05*pulse) or 1
   if fx.inner then
    fx.inner.CFrame=CFrame.new(point+normal*.06);fx.inner.Size=Vector3.one*(.09+.05*pulse)
    fx.inner.Color=(beam.tint or WHITE):Lerp(WHITE,.25);fx.inner.Transparency=working and .45 or 1
   end
  end
 end
 if sample.pulseSerial~=fx.pulseSerial then
  if working and sample.pulseAt and now-sample.pulseAt<.25 then fx.impact:Emit(16);fx.sparks:Emit(5) end
  fx.pulseSerial=sample.pulseSerial
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
   jet.Lifetime=NumberRange.new(.6,1.1);jet.Acceleration=Vector3.new(0,1.2,0);jet.Rate=20;jet.LightEmission=.7;jet.Brightness=1.4
   jet.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.34),NumberSequenceKeypoint.new(1,0)})
   table.insert(record.rockets,{attachment=nozzle,jet=jet})
  end
 end
 for _,rocket in ipairs(record.rockets or {}) do rocket.jet.Enabled=powered end
 local fx=record.flight
 if not fx then
  fx={objects={},trails={},position=root.Position,life=source:GetAttribute('Life')};record.flight=fx
  local role=source:GetAttribute('Role')
  local span=role=='Medic' and .25 or role=='Courier' and .48 or math.max(.25,root.Size.X*.34)
  for _,side in ipairs({-1,1}) do
   local a=Instance.new('Attachment');a.Name='FlightTrailTop';a.Position=Vector3.new(side*span,-.03,span*.65);a.Parent=root
   local b=Instance.new('Attachment');b.Name='FlightTrailBottom';b.Position=a.Position-Vector3.new(0,.065,0);b.Parent=root
   local trail=Instance.new('Trail');trail.Name='DroneFlightTrail';trail.Attachment0=a;trail.Attachment1=b
   trail.Lifetime=.65;trail.MinLength=.04;trail.FaceCamera=true;trail.LightEmission=.2
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
   wisp.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.07),NumberSequenceKeypoint.new(.55,.26),NumberSequenceKeypoint.new(1,.35)})
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
  trail.Enabled=alive and not paused and speed>.6 and not reset
 end
 if fx.wisp then
  if reset then fx.wisp:Clear() end
  fx.wisp.Enabled=alive and not paused and cameraNear(root.Position,100)
  fx.wisp.Rate=1+math.min(3,speed*.25)
 end
 fx.position=root.Position;fx.life=source:GetAttribute('Life')
end
function W:repair(drone,record,now)
 local s=drone.source;local charging=s:GetAttribute('State')=='RepairCharge'
 local healing=s:GetAttribute('Healing')==true
 local active=s:GetAttribute('Role')=='Medic' and not record.events.dead and s:GetAttribute('MotionPaused')~=true and s:GetAttribute('WorkPaused')~=true and (charging or healing) and cameraNear(drone.pos,90)
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
 local enabled=source:GetAttribute('Role')=='Courier' and not record.events.dead and cameraNear(drone.pos,200)
 local fx=record.courier
 if not enabled then self:destroyCourier(record);return end
 local parcelUnits=source:GetAttribute('DeliveryUnits') or 0
 local busy=state=='Pickup' or state=='Unload' or parcelUnits>0
 if not busy and not fx then return end
 if fx and not busy and now-fx.lastAt>ENERGY_TAIL then self:destroyCourier(record);return end
 if not fx then
  local detailed=self.courierCount<self.maxCouriers
  local root=Instance.new('Folder');root.Name='CourierWork';root.Parent=self.parent
  local anchor=part(root,'TransferOrigin');local contact=part(root,'BackpackContact')
  local tether=W.newCylinder(root,'PickupTether',GOLD)
  local parcel=part(root,'CourierParcel');parcel.Size=Vector3.new(.62,.42,.5);parcel.Material=Enum.Material.WoodPlanks;parcel.Color=Color3.fromRGB(171,139,79)
  parcel.TopSurface=Enum.SurfaceType.Studs
  local band=part(root,'ParcelLatch');band.Size=Vector3.new(.65,.07,.53);band.Material=Enum.Material.Metal;band.Color=GOLD
  local drive=part(root,'CourierWake');local trails={}
  if detailed then for _,side in ipairs({-1,1}) do
   local top=Instance.new('Attachment');top.Position=Vector3.new(side*.38,.025,.25);top.Parent=drive
   local bottom=Instance.new('Attachment');bottom.Position=Vector3.new(side*.38,-.025,.25);bottom.Parent=drive
   local trail=Instance.new('Trail');trail.Name='LoadedFlightTrail';trail.Attachment0=top;trail.Attachment1=bottom
   trail.Lifetime=.6;trail.MinLength=.04;trail.FaceCamera=true;trail.LightEmission=.25
   trail.Color=ColorSequence.new(GOLD);trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,1)})
   trail.Enabled=false;trail.Parent=root;table.insert(trails,trail)
  end end
  fx={root=root,anchor=anchor,contact=contact,tether=tether,parcel=parcel,band=band,drive=drive,trails=trails,spheres=detailed and spheres(anchor,GOLD) or {},detailed=detailed,sale=source:GetAttribute('CourierSaleSerial') or 0,loadId=source:GetAttribute('DeliveryId') or '',lastAt=now}
  if detailed then
   fx.sparks=particle(anchor,'CourierSparks',GOLD);fx.sparks.Brightness=1.2;fx.sparks.LightEmission=.65;self.courierCount+=1
  end
  record.courier=fx
 end
 if busy then fx.lastAt=now end
 local paused=source:GetAttribute('MotionPaused')==true or source:GetAttribute('WorkPaused')==true
 local pivot=drone.view:GetPivot();local mount=pivot:PointToWorldSpace(Vector3.new(0,-.52,0))
 for _,trail in ipairs(fx.trails) do trail.Enabled=state=='Deliver' and parcelUnits>0 and not paused and now-(source:GetAttribute('SnapshotAt') or 0)<.5 end
 local backpack=backpackPosition(source)
 local sale=source:GetAttribute('CourierSaleSerial') or 0;local sell=source:GetAttribute('SellPosition')
 if sale>fx.sale and typeof(sell)=='Vector3' and now-(source:GetAttribute('CourierSaleAt') or 0)<.7 then self:burst(sell+Vector3.new(0,1,0),Vector3.yAxis,GOLD,18,now) end
 fx.sale=sale
 local pickup=state=='Pickup' and backpack~=nil and (backpack-mount).Magnitude<=6 and not paused and now-(source:GetAttribute('SnapshotAt') or 0)<.5
 local unload=state=='Unload' and typeof(sell)=='Vector3'
 local launch=source:GetAttribute('CourierLaunchAt') or 0
 local pickupAt=source:GetAttribute('CourierPickupAt') or 0
 local q=pickup and progress(now,pickupAt,source:GetAttribute('CourierPickupHold') or .55) or 1
 local loadId=source:GetAttribute('DeliveryId') or ''
 if loadId~='' and loadId~=fx.loadId and launch>0 and now-launch<.5 then self:burst(mount,Vector3.new(0,-1,0),GOLD,8,now) end
 fx.loadId=loadId
 if pickup then drone.view:PivotTo(pivot*CFrame.new(0,-.10*q,0))
 elseif state=='Launch' and launch>0 then
  local t=progress(now,launch,source:GetAttribute('CourierLaunchHold') or .25)
  drone.view:PivotTo(pivot*CFrame.new(0,math.sin(t*math.pi)*.18,0))
 end
 pivot=drone.view:GetPivot();mount=pivot:PointToWorldSpace(Vector3.new(0,-.52,0))
 fx.drive.CFrame=pivot;fx.anchor.CFrame=facing(mount,Vector3.new(0,-1,0))
 drawSpheres(fx,now,pickup and .3+.7*q or unload and .7 or 0,q,0,GOLD)
 if pickup then W.drawCylinder(fx.tether,mount,backpack,.045+.025*q,.5-.2*q) else fx.tether.Transparency=1 end
 if fx.sparks then
  fx.sparks.Rate=pickup and 4+q*5 or unload and 6 or 0;fx.sparks.Enabled=not paused and (pickup or unload)
  if paused then fx.sparks:Clear() end
 end
 local parcelScale=math.clamp((math.max(1,parcelUnits)/8)^(1/3),1,1.6)
 fx.parcel.Size=Vector3.new(.62,.42,.5)*parcelScale;fx.band.Size=Vector3.new(.65,.07,.53)*parcelScale
 fx.parcel.Transparency=parcelUnits>0 and 0 or 1
 fx.band.Transparency=fx.parcel.Transparency
 if parcelUnits>0 then
  local position=mount
  local transfer=launch>0 and progress(now,launch,source:GetAttribute('CourierLaunchHold') or .25) or 1
  if transfer<1 and backpack and (backpack-mount).Magnitude<=6 then
   local t=transfer*transfer*(3-2*transfer)
   position=backpack:Lerp(mount,t)+Vector3.new(0,math.sin(t*math.pi)*.35,0)
  elseif unload then
   local t=paused and (fx.unloadProgress or 0) or progress(now,source:GetAttribute('CourierUnloadAt') or now,source:GetAttribute('CourierUnloadHold') or .65)
   fx.unloadProgress=t
   -- Hold the parcel just above the converter until the server confirms sale.
   local finish=sell+Vector3.new(0,1.25,0)
   position=mount:Lerp(finish,t*.9)+Vector3.new(math.sin(t*math.pi)*.18,math.sin(t*math.pi)*.3,0)
  end
  fx.parcel.CFrame=CFrame.new(position)*pivot.Rotation
  fx.band.CFrame=fx.parcel.CFrame
 end
end
-- A monochrome beam with alternating opaque/clear bands. Shift the sequence
-- along its normalized length, so the pulse remains fast at every frame rate.
-- Fourteen or fewer keys stay inside Roblox's twenty-key NumberSequence limit.
function W.orbitalTransparency(now)
 local phase=(now*7)%1
 local function opacity(t)
  local x=(t*3+phase)%1
  if x<.22 then return .04 elseif x<.32 then return .04+.96*(x-.22)/.1
  elseif x<.88 then return 1 else return 1-.96*(x-.88)/.12 end
 end
 local keys={NumberSequenceKeypoint.new(0,opacity(0))}
 for i=-1,4 do for _,point in ipairs({{0,.04},{.22,.04},{.32,1},{.88,1}}) do
  local t=(i+point[1]-phase)/3
  if t>0 and t<1 then table.insert(keys,NumberSequenceKeypoint.new(t,point[2])) end
 end end
 table.insert(keys,NumberSequenceKeypoint.new(1,opacity(1)))
 return NumberSequence.new(keys)
end
function W:orbital(now)
 if now>=self.scanAt then
  self.scanAt=now+.2
  local source=workspace:FindFirstChild('DroneRoleServerEffects')
  if source then for _,group in ipairs(source:GetChildren()) do
   local position=group:GetAttribute('Position')
   if group:GetAttribute('OrbitalBurn') and not self.orbitals[group] and not group:GetAttribute('EndedAt')
    and typeof(position)=='Vector3' and cameraAbove(position,180) then
    local holder=part(self.parent,'OrbitalEnergyRamp')
    local bottom=Instance.new('Attachment');bottom.Parent=holder
    local top=Instance.new('Attachment');top.Parent=holder
    local ramp=Instance.new('Beam');ramp.Name='DescendingWhiteClearEnergy'
    ramp.Attachment0=bottom;ramp.Attachment1=top;ramp.FaceCamera=true;ramp.Segments=48
    ramp.Color=ColorSequence.new(Color3.new(1,1,1));ramp.LightEmission=1;ramp.LightInfluence=0;ramp.Brightness=1.6
    ramp.Width0=1.8;ramp.Width1=1.8;ramp.Parent=holder
    local hidden={}
    for _,column in ipairs(group:GetChildren()) do
     if column:IsA('BasePart') and (column.Name=='MeltCore' or column.Name=='MeltHalo') then
      hidden[column]=column.LocalTransparencyModifier or 0;column.LocalTransparencyModifier=1
     end
    end
    self.orbitals[group]={holder=holder,bottom=bottom,top=top,ramp=ramp,nextRamp=0,hidden=hidden}
    self:energyBloom()
   end
  end end
 end
 for group,record in pairs(self.orbitals) do
  local position=group:GetAttribute('Position')
  local ended=group:GetAttribute('EndedAt')
  local strength=ended and (1-progress(now,ended,.48))^2 or 1
  if not group.Parent or typeof(position)~='Vector3' or strength<.002 then
   for column,value in pairs(record.hidden) do if column.Parent then column.LocalTransparencyModifier=value end end
   record.holder:Destroy();self.orbitals[group]=nil
  else
   local camera=workspace.CurrentCamera
   for column in pairs(record.hidden) do if column.Parent then column.LocalTransparencyModifier=1 end end
   local contactAt=group:GetAttribute('ContactAt')
   -- A yielding save or a stalled contact stream must not leave a cosmetic
   -- strike drilling after authoritative work has paused.
   record.ramp.Enabled=ended~=nil or contactAt==nil or now-contactAt<.3
   local height=math.max(260,(camera and camera.CFrame.Position.Y or position.Y)-position.Y+180)
   record.holder.CFrame=CFrame.new(position)
   record.bottom.Position=Vector3.zero;record.top.Position=Vector3.new(0,height,0)
   record.ramp.Width0=1.8*strength;record.ramp.Width1=record.ramp.Width0
   if now>=record.nextRamp then record.nextRamp=now+.04;record.ramp.Transparency=W.orbitalTransparency(now) end
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
  for column,value in pairs(record.hidden) do if column.Parent then column.LocalTransparencyModifier=value end end
  record.holder:Destroy()
 end;self.orbitals={}
 if self.ownsBloom and self.bloom then self.bloom:Destroy() end;self.bloom=nil
end
return W
