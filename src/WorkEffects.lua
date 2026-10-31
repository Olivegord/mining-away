-- Attached, bounded work choreography. Server timestamps drive every phase;
-- these visuals never remove ore, credit a sale, heal, or advance mining.
local W={};W.__index=W
local Players=game:GetService('Players')
local GOLD=Color3.fromRGB(244,193,89)
local WHITE=Color3.fromRGB(236,249,255)
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
 return camera and (camera.CFrame.Position-position).Magnitude<radius
end
local function particle(parent,name,color)
 local fx=game:GetService('ReplicatedStorage'):FindFirstChild('MiningFX')
 local source=fx and fx:FindFirstChild('MiningParticles')
 source=source and source:FindFirstChild(name=='OriginGlow' and 'Mainglow' or 'Largeparticles')
 local p=source and source:IsA('ParticleEmitter') and source:Clone() or Instance.new('ParticleEmitter')
 p.Name=name;p.Enabled=false;p.Rate=0
 -- Keep the authored emitter sprites at the origin; cutting/transport sparks
 -- use a shipped transparent texture and remain readable without asset access.
 p.Texture=source and (name=='OriginParticles' or name=='OriginGlow') and source.Texture or 'rbxasset://textures/particles/sparkles_main.dds'
 p.Color=ColorSequence.new(color);p.LightEmission=.55;p.LightInfluence=0
 p.EmissionDirection=Enum.NormalId.Front;p.Orientation=Enum.ParticleOrientation.FacingCamera
 p.Lifetime=NumberRange.new(.16,.32);p.Speed=NumberRange.new(1.4,3.5);p.Drag=4
 p.SpreadAngle=Vector2.new(55,55);p.Acceleration=Vector3.new(0,-6,0)
 p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.045),NumberSequenceKeypoint.new(.25,.13),NumberSequenceKeypoint.new(1,0)})
 p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(.65,.45),NumberSequenceKeypoint.new(1,1)})
 p.Parent=parent;return p
end
local function rings(parent,color)
 local out={}
 for index=1,3 do
  local ring={arcs={},index=index}
  for segment=1,4 do
   local a=Instance.new('Attachment');a.Parent=parent
   local b=Instance.new('Attachment');b.Parent=parent
   local beam=Instance.new('Beam');beam.Name='MiningCircle'..index;beam.Attachment0=a;beam.Attachment1=b
   beam.FaceCamera=true;beam.Segments=8;beam.LightEmission=.65;beam.LightInfluence=0
   beam.Color=ColorSequence.new(color);beam.Transparency=NumberSequence.new(.3)
   beam.Enabled=false;beam.Parent=parent
   table.insert(ring.arcs,{a=a,b=b,beam=beam,segment=segment})
  end
  local dot=part(parent,'OrbitParticle');dot.Material=Enum.Material.Neon;dot.Shape=Enum.PartType.Ball
  dot.Color=WHITE;ring.dot=dot;table.insert(out,ring)
 end
 return out
end
local function drawRings(record,now,strength,charge,pulse,color)
 for _,ring in ipairs(record.rings) do
  local index=ring.index;local spin=now*(index%2==0 and -1.7 or 1.3)+index
  local radius=((.30+index*.13)*(1+(1-charge)*.75)+pulse*.10)*(record.scale or 1)
  local z=-.045-index*(.10+(1-charge)*.11)
  for _,arc in ipairs(ring.arcs) do
   local a=(arc.segment-1)*math.pi/2+spin;local b=a+math.pi/2-.11
   local function frame(angle)
    local c,s=math.cos(angle),math.sin(angle)
    return CFrame.fromMatrix(Vector3.new(c*radius,s*radius,z),Vector3.new(-s,c,0),Vector3.new(-c,-s,0),Vector3.zAxis)
   end
   arc.a.CFrame=frame(a);arc.b.CFrame=frame(b)
   arc.beam.CurveSize0=radius*.53;arc.beam.CurveSize1=radius*.53
   arc.beam.Width0=(.025+charge*.015+pulse*.02)*strength;arc.beam.Width1=arc.beam.Width0
   arc.beam.Color=ColorSequence.new(color:Lerp(WHITE,index==1 and .4 or .1))
   arc.beam.Transparency=NumberSequence.new(1-strength*(.60+charge*.3));arc.beam.Enabled=strength>.015
  end
  ring.dot.Size=Vector3.one*(.04+.045*charge)
  ring.dot.CFrame=record.anchor.CFrame*CFrame.new(math.cos(spin)*radius,math.sin(spin)*radius,z)
  ring.dot.Transparency=1-strength*.9
 end
end
function W.new(parent)
 return setmetatable({parent=parent,mining={},miningCount=0,maxMining=16,courierCount=0,maxCouriers=12,repairCount=0,maxRepairs=12,bursts={},maxBursts=14},W)
end
function W:burst(position,normal,color,count,now)
 if #self.bursts>=self.maxBursts or not cameraNear(position,140) then return end
 local anchor=part(self.parent,'WorkBurst');anchor.CFrame=facing(position,normal)
 local sparks=particle(anchor,'WorkSparks',color);sparks.Speed=NumberRange.new(2,5)
 sparks:Emit(math.min(20,count));table.insert(self.bursts,{part=anchor,untilAt=now+.65})
end
function W:destroyMining(beam)
 local fx=beam.work
 if not fx then return end
 fx.impact:Destroy();fx.anchor:Destroy();beam.work=nil;self.mining[beam]=nil;self.miningCount=math.max(0,self.miningCount-1)
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
   for _,ring in ipairs(fx.rings) do for _,arc in ipairs(ring.arcs) do arc.beam.Enabled=false end;ring.dot.Transparency=1 end
   if sample.paused or not sample.alive then fx.sparks:Clear();fx.glow:Clear();fx.impact:Clear() end
   if not sample.alive or now-fx.lastAt>1 then self:destroyMining(beam) end
  end
  return
 end
 if not fx then
  if self.miningCount>=self.maxMining then return end
  local anchor=part(beam.holder,'OriginalMiningOrigin')
  fx={anchor=anchor,rings=rings(anchor,beam.tint or WHITE),lastAt=now,pulseSerial=sample.pulseSerial or 0}
  fx.sparks=particle(anchor,'OriginParticles',beam.tint or WHITE)
  fx.glow=particle(anchor,'OriginGlow',beam.tint or WHITE)
  fx.glow.Speed=NumberRange.new(0);fx.glow.Lifetime=NumberRange.new(.15,.25);fx.glow.Size=NumberSequence.new(.24)
  fx.impact=particle(beam.marker,'CuttingSparks',sample.mineralColor or beam.tint or WHITE)
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
  beam.work=fx;self.mining[beam]=true;self.miningCount+=1
 end
 if fx.key~=sample.key or fx.life~=sample.life then
  fx.sparks:Clear();fx.glow:Clear();fx.impact:Clear();fx.key=sample.key;fx.life=sample.life
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
 drawRings(fx,now,strength,q,pulse,beam.tint or WHITE)
 local continuous=sample.style~='Percussion'
 fx.sparks.Rate=charging and (6+20*q) or 20;fx.sparks.Enabled=charging or working
 fx.glow.Rate=charging and 5 or 3;fx.glow.Enabled=charging or working
 fx.impact.Color=ColorSequence.new(sample.mineralColor or beam.tint or WHITE)
 fx.impact.Rate=continuous and 26 or 0;fx.impact.Enabled=working and continuous
 if point and normal then
  beam.marker.CFrame=facing(point+normal*.045,normal)
  if fx.contact then
   fx.contact.CFrame=CFrame.new(point+normal*.05)
   fx.contact.Size=Vector3.one*(.20+.22*width+.12*pulse)
   fx.contact.Color=beam.tint or WHITE;fx.contact.Transparency=working and (.72-.15*pulse) or 1
   if fx.inner then
    fx.inner.CFrame=CFrame.new(point+normal*.06);fx.inner.Size=Vector3.one*(.09+.05*pulse)
    fx.inner.Color=WHITE;fx.inner.Transparency=working and .15 or 1
   end
  end
 end
 if sample.pulseSerial~=fx.pulseSerial then
  if working and sample.pulseAt and now-sample.pulseAt<.25 then fx.impact:Emit(12);fx.sparks:Emit(6) end
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
 self:destroyCourier(record)
 if record.repair then record.repair.anchor:Destroy();record.repair=nil;self.repairCount=math.max(0,self.repairCount-1) end
end
function W:repair(drone,record,now)
 local s=drone.source;local charging=s:GetAttribute('State')=='RepairCharge'
 local healing=s:GetAttribute('Healing')==true
 local active=s:GetAttribute('Role')=='Medic' and not record.events.dead and s:GetAttribute('MotionPaused')~=true and (charging or healing) and cameraNear(drone.pos,90)
 local fx=record.repair
 if not active then
  if fx then
   fx.sparks.Enabled=false
   drawRings(fx,now,0,0,0,WHITE)
   if now-fx.lastAt>.6 then fx.anchor:Destroy();record.repair=nil;self.repairCount=math.max(0,self.repairCount-1) end
  end
  return
 end
 local color=Color3.fromRGB(126,233,160)
 if not fx then
  if self.repairCount>=self.maxRepairs then return end
  local anchor=part(self.parent,'RepairCapacitor');fx={anchor=anchor,rings=rings(anchor,color),scale=.42,lastAt=now}
  fx.sparks=particle(anchor,'RepairParticles',color);record.repair=fx;self.repairCount+=1
 end
 fx.lastAt=now;fx.anchor.CFrame=facing(drone.emitter.Position,Vector3.new(0,-1,0))
 local q=charging and progress(now,s:GetAttribute('RepairChargeAt') or now,s:GetAttribute('RepairChargeDuration') or .4) or 1
 drawRings(fx,now,charging and .3+.7*q or 1,q,healing and .5 or 0,color)
 fx.sparks.Rate=charging and 8+q*10 or 24;fx.sparks.Enabled=true
end
function W:courier(drone,record,now)
 local source=drone.source;local state=source:GetAttribute('State')
 local enabled=source:GetAttribute('Role')=='Courier' and not record.events.dead and cameraNear(drone.pos,200)
 local fx=record.courier
 if not enabled then self:destroyCourier(record);return end
 local parcelUnits=source:GetAttribute('DeliveryUnits') or 0
 local busy=state=='Pickup' or state=='Unload' or parcelUnits>0
 if not busy and not fx then return end
 if fx and not busy and now-fx.lastAt>.8 then self:destroyCourier(record);return end
 if not fx then
  local detailed=self.courierCount<self.maxCouriers
  local root=Instance.new('Folder');root.Name='CourierWork';root.Parent=self.parent
  local anchor=part(root,'TransferOrigin');local contact=part(root,'BackpackContact')
  local a=Instance.new('Attachment');a.Parent=anchor;local b=Instance.new('Attachment');b.Parent=contact
  local tether=Instance.new('Beam');tether.Name='PickupTether';tether.Attachment0=a;tether.Attachment1=b
  tether.FaceCamera=true;tether.Segments=12;tether.Color=ColorSequence.new(GOLD)
  tether.Width0=.045;tether.Width1=.08;tether.LightEmission=.5;tether.Transparency=NumberSequence.new(.35);tether.Enabled=false;tether.Parent=root
  local parcel=part(root,'CourierParcel');parcel.Size=Vector3.new(.62,.42,.5);parcel.Material=Enum.Material.WoodPlanks;parcel.Color=Color3.fromRGB(171,139,79)
  parcel.TopSurface=Enum.SurfaceType.Studs
  local band=part(root,'ParcelLatch');band.Size=Vector3.new(.65,.07,.53);band.Material=Enum.Material.Metal;band.Color=GOLD
  local drive=part(root,'CourierWake');local trails={}
  if detailed then for _,side in ipairs({-1,1}) do
   local top=Instance.new('Attachment');top.Position=Vector3.new(side*.38,.025,.25);top.Parent=drive
   local bottom=Instance.new('Attachment');bottom.Position=Vector3.new(side*.38,-.025,.25);bottom.Parent=drive
   local trail=Instance.new('Trail');trail.Name='LoadedFlightTrail';trail.Attachment0=top;trail.Attachment1=bottom
   trail.Lifetime=.32;trail.MinLength=.04;trail.FaceCamera=true;trail.LightEmission=.45
   trail.Color=ColorSequence.new(GOLD);trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,1)})
   trail.Enabled=false;trail.Parent=root;table.insert(trails,trail)
  end end
  fx={root=root,anchor=anchor,contact=contact,tether=tether,parcel=parcel,band=band,drive=drive,trails=trails,rings=detailed and rings(anchor,GOLD) or {},detailed=detailed,sale=source:GetAttribute('CourierSaleSerial') or 0,loadId=source:GetAttribute('DeliveryId') or '',lastAt=now}
  if detailed then fx.sparks=particle(anchor,'CourierSparks',GOLD);self.courierCount+=1 end
  record.courier=fx
 end
 if busy then fx.lastAt=now end
 local paused=source:GetAttribute('MotionPaused')==true
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
 drawRings(fx,now,pickup and .3+.7*q or unload and .7 or 0,q,0,GOLD)
 fx.tether.Enabled=pickup
 if pickup then fx.contact.Position=backpack;fx.tether.CurveSize0=.25*(1-q);fx.tether.CurveSize1=-.25*(1-q) end
 if fx.sparks then
  fx.sparks.Rate=pickup and 12+q*12 or unload and 16 or 0;fx.sparks.Enabled=not paused and (pickup or unload)
  if paused then fx.sparks:Clear() end
 end
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
function W:update(now)
 for i=#self.bursts,1,-1 do
  local item=self.bursts[i]
  if now>=item.untilAt then item.part:Destroy();table.remove(self.bursts,i) end
 end
end
function W:destroy()
 for beam in pairs(self.mining) do self:destroyMining(beam) end
 for _,item in ipairs(self.bursts) do item.part:Destroy() end;self.bursts={}
end
return W
