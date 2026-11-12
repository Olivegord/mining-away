-- Observe server-authored receipts. Every client renders locally, regardless
-- of ownership. State records also cover late joins and canceled abilities.
local View={}
local Players=game:GetService('Players')
local Lighting=game:GetService('Lighting')
local WHITE=Color3.fromRGB(255,248,231)
local PRISM_RED=Color3.fromRGB(249,22,60)
local SIGHT_RED=Color3.fromRGB(255,56,72)
local TRAIL_LIMIT,SHOT_LIMIT,BURST_LIMIT=12,18,12
local liveRamielFields=0
local livePrismAims=0

local function smooth(t)
 t=math.clamp(t,0,1);return t*t*(3-2*t)
end

local function shotPart(parent,name,size,color,ball,transparency)
 local part=Instance.new('Part')
 part.Name=name;part.Size=size;part.Color=color;part.Material=Enum.Material.Neon
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 if ball then part.Shape=Enum.PartType.Ball end
 part.Transparency=transparency or 0;part.Parent=parent
 return part
end

local PRISM_AIM_CORE=ColorSequence.new(Color3.fromRGB(255,166,202),Color3.fromRGB(255,98,137))
local PRISM_AIM_GLOW=ColorSequence.new(Color3.fromRGB(241,33,107),PRISM_RED)
local prismAimAlpha={}
for i=0,16 do
 local strength=i/16
 prismAimAlpha[i]={
  NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.09,1-strength*.84),
   NumberSequenceKeypoint.new(.91,1-strength*.74),NumberSequenceKeypoint.new(1,1-strength*.52)}),
  NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.16,1-strength*.28),
   NumberSequenceKeypoint.new(.89,1-strength*.21),NumberSequenceKeypoint.new(1,1)}),
 }
end

local function clearPrismAim(record)
 if not record.prismAim then return end
 record.prismAim.root:Destroy();record.prismAim=nil
end

local function drawPrismAim(record,camera,origin,target,strength,lowEffects)
 local aim=record.prismAim
 if aim and aim.root.Parent~=camera then clearPrismAim(record);aim=nil end
 if not aim then
  if livePrismAims>=6 then return end
  local root=shotPart(camera,'RamielChargeAim',Vector3.one*.025,PRISM_RED,false,1)
  livePrismAims+=1;root.Destroying:Connect(function() livePrismAims-=1 end)
  local start=Instance.new('Attachment');start.Parent=root
  local tip=Instance.new('Attachment');tip.Parent=root
  local function ribbon(name,color)
   local line=Instance.new('Beam')
   line.Name=name;line.Attachment0=start;line.Attachment1=tip
   line.FaceCamera=true;line.LightEmission=1;line.LightInfluence=0;line.Segments=16;line.Color=color
   line.Parent=root;return line
  end
  aim={root=root,start=start,tip=tip,core=ribbon('AimNeedle',PRISM_AIM_CORE),glow=ribbon('AimGlow',PRISM_AIM_GLOW),
   dot=shotPart(root,'AimContact',Vector3.one*.16,Color3.fromRGB(255,126,163),true,1)}
  record.prismAim=aim
 end
 local alpha=prismAimAlpha[math.clamp(math.round(strength*16),1,16)]
 local width=.045+.085*strength
 aim.start.WorldPosition=origin:Lerp(target,.025)
 aim.tip.WorldPosition=target
 aim.core.Width0=width;aim.core.Width1=width*.78;aim.core.Transparency=alpha[1]
 aim.glow.Enabled=not lowEffects
 aim.glow.Width0=width*4.2;aim.glow.Width1=width*2.6;aim.glow.Transparency=alpha[2]
 aim.dot.Position=target:Lerp(origin,.006)
 aim.dot.Size=Vector3.one*(.13+.24*strength)
 aim.dot.Transparency=1-strength*.78
end

local SIGHT_SECTION=12
local function sightPattern(seed)
 local function nextValue()
  seed=(seed*48271)%2147483647
  return seed/2147483647
 end
 local sections={}
 for section=1,4 do
  local keys={{0,.91,0}}
  for i=0,3 do
   local from=i*3+.21+nextValue()*.62
   local to=from+.82+nextValue()*1.13
   local opacity=.16+nextValue()*.29
   local phase=nextValue()*math.pi*2
   keys[#keys+1]={from,.94,phase}
   keys[#keys+1]={from+.14,opacity,phase}
   keys[#keys+1]={to,opacity,phase}
   keys[#keys+1]={to+.12,.94,phase}
  end
  keys[#keys+1]={SIGHT_SECTION,.91,0}
  sections[section]=keys
 end
 return sections
end

local function revealPattern(points,length,now,section)
 -- Key positions are studs from this section's origin. Clipping at the tip
 -- changes their normalized coordinates, never their world-space spacing.
 local function alpha(point)
  local contrast=.54+.46*(.5+.5*math.sin(now*9.3+point[3]+section*1.7))
  local drift=.5+.5*math.sin(now*4.7-point[1]*.71+section*2.2)
  return 1-(1-point[2])*contrast*(.56+.44*drift)
 end
 local function position(point)
  if point[1]==0 or point[1]==SIGHT_SECTION then return point[1] end
  return point[1]+.14*math.sin(now*5.6+point[3]+section*.37)
 end
 local keys={NumberSequenceKeypoint.new(0,alpha(points[1]))}
 for i=2,#points do
  local before,point=points[i-1],points[i]
  local x=position(point)
  if x>=length then
   local prior=position(before)
   local t=math.clamp((length-prior)/(x-prior),0,1)
   keys[#keys+1]=NumberSequenceKeypoint.new(1,alpha(before)+(alpha(point)-alpha(before))*t)
   break
  end
  keys[#keys+1]=NumberSequenceKeypoint.new(x/length,alpha(point))
 end
 return NumberSequence.new(keys)
end

local function newSight(drone)
 local id=tostring(drone.source:GetAttribute('DroneId') or '')
 local seed=1
 for i=1,#id do seed=(seed*31+string.byte(id,i))%2147483646+1 end
 local dot=shotPart(drone.beam.holder,'ProjectileAimDot',Vector3.one*.135,SIGHT_RED,true,1)
 local lines={}
 for i=1,4 do
  local from=drone.shotMuzzle
  if i>1 then from=Instance.new('Attachment');from.Parent=dot end
  local tip=Instance.new('Attachment');tip.Parent=dot
  local line=Instance.new('Beam');line.Name='SegmentedProjectileSight'..i
  line.Attachment0=from;line.Attachment1=tip;line.FaceCamera=true;line.Segments=48
  line.Width0=.052;line.Width1=.065
  line.Color=ColorSequence.new(SIGHT_RED,Color3.fromRGB(255,94,102))
  line.LightEmission=.88;line.LightInfluence=0
  line.Enabled=false;line.Parent=dot;lines[i]=line
 end
 return {dot=dot,line=lines[1],lines=lines,patterns=sightPattern(seed)}
end

local function aimPoint(origin,part,anchor)
 if typeof(anchor)=='Vector3' then return part.CFrame:PointToWorldSpace(anchor*part.Size) end
 -- Before the first shot receipt, use the visible hull's near face.
 local localOrigin=part.CFrame:PointToObjectSpace(origin)
 local extent=localOrigin/part.Size
 local edge=math.max(math.abs(extent.X),math.abs(extent.Y),math.abs(extent.Z))
 return part.CFrame:PointToWorldSpace(localOrigin*(.44/math.max(.5,edge)))
end

function View.aim(drone,target,now)
 now=now or workspace:GetServerTimeNow()
 local sight=drone.sight
 local part=target and target.view
 local origin=drone.shotMuzzle.WorldPosition
 local visible=part and part.Parent and part.Transparency<1 and target.source:GetAttribute('Kind')~='Geode'
  and (target.source:GetAttribute('HP') or 0)>0 and BeamVFX.near(origin,85) and (part.Position-origin).Magnitude<45
 local receipt=drone.shotReceipt
 local matched=receipt and receipt.Parent and target and receipt:GetAttribute('TargetId')==target.id
 local started=matched and receipt:GetAttribute('StartedAt')
 local firing=started and started+(receipt:GetAttribute('Windup') or 0)
 if firing and now>=firing+.085 then visible=false end
 if not visible then
  if sight then
   for _,line in ipairs(sight.lines) do line.Enabled=false end
   sight.dot.Transparency=1;sight.target=nil
  end
  return
 end
 local point=aimPoint(origin,part,matched and receipt:GetAttribute('TargetAnchor'))
 if not sight then sight=newSight(drone);drone.sight=sight end
 if sight.target~=target or started and sight.receipt and sight.receipt~=receipt then
  sight.target=target;sight.lockAt=now
 end
 if matched then sight.receipt=receipt end
 local delta=point-origin;local distance=delta.Magnitude
 if distance<=.01 then return end
 local length=math.min(distance,math.max(.035,now-sight.lockAt)*64)
 local direction=delta.Unit
 sight.dot.Position=point:Lerp(origin,.006)
 sight.dot.Transparency=length>=distance-.1 and .16 or 1
 local refresh=now>=(sight.nextPattern or 0) or math.abs(length-(sight.length or 0))>.025
 for i,line in ipairs(sight.lines) do
  local offset=(i-1)*SIGHT_SECTION
  local span=math.min(SIGHT_SECTION,length-offset)
  line.Enabled=span>.02
  if line.Enabled then
   if i>1 then line.Attachment0.WorldPosition=origin+direction*offset end
   line.Attachment1.WorldPosition=origin+direction*(offset+span)
   if refresh then line.Transparency=revealPattern(sight.patterns[i],span,now,i) end
  end
 end
 if refresh then sight.nextPattern=now+.045;sight.length=length end
end

-- Observed at 30 fps in the first shot of US5yoHbv-6Q. Time zero is the
-- first white frame at 24.0356. The radius is normalized to the final local
-- bloom; the actual frame is clipped by white at the upper end.
local RAMIEL_FLARE={
 {-2.70,0}, {-2.30,.033}, {-1.78,.072}, {-1.22,.13}, {-.74,.21}, {-.42,.31},
 {-.25,.47}, {-.105,.86}, {0,1.98},
}
local RAMIEL_STAR_ANGLE={
 {-2.70,-21}, {-1.78,2}, {-.82,25}, {-.36,40}, {-.17,61}, {-.065,99}, {0,143},
 {.09,219}, {.21,273}, {.35,311}, {.55,336}, {.79,348},
}
local function curveVelocity(a,b,c)
 local left=(b[2]-a[2])/(b[1]-a[1])
 local right=(c[2]-b[2])/(c[1]-b[1])
 return 2*left*right/(left+right)
end
local function sampleCurve(keys,elapsed)
 if elapsed<=keys[1][1] then return keys[1][2] end
 if elapsed>=keys[#keys][1] then return keys[#keys][2] end
 local i=1
 while elapsed>keys[i+1][1] do i+=1 end
 local a,b=keys[i],keys[i+1]
 local span=b[1]-a[1]
 local q=(elapsed-a[1])/span
 local start=i>1 and curveVelocity(keys[i-1],a,b)*span or 0
 local finish=i+2<=#keys and curveVelocity(a,b,keys[i+2])*span or 0
 local q2,q3=q*q,q*q*q
 return math.clamp((2*q3-3*q2+1)*a[2]+(q3-2*q2+q)*start
  +(3*q2-2*q3)*b[2]+(q3-q2)*finish,a[2],b[2])
end

local function starRays(root)
 local center=Instance.new('Attachment');center.Parent=root
 local rays={}
 local function spoke(tip,color)
  local beam=Instance.new('Beam')
  beam.Attachment0=center;beam.Attachment1=tip;beam.FaceCamera=true;beam.Segments=4
  beam.Width1=0;beam.LightEmission=1;beam.LightInfluence=0
  beam.Color=ColorSequence.new(color);beam.Parent=root
  return beam
 end
 for i=1,4 do
  local tip=Instance.new('Attachment');tip.Parent=root
  rays[i]={tip=tip,halo=spoke(tip,Color3.fromRGB(255,116,208)),core=spoke(tip,Color3.fromRGB(255,249,255))}
 end
 return rays
end

local function drawStar(rays,position,right,up,angle,radius,scale,alpha)
 local function rayAlpha(opacity)
  return NumberSequence.new({NumberSequenceKeypoint.new(0,1-opacity),
   NumberSequenceKeypoint.new(.56,1-opacity*.57),NumberSequenceKeypoint.new(1,1)})
 end
 local coreAlpha,haloAlpha=rayAlpha(alpha),rayAlpha(alpha*.46)
 local length=(.047+radius*2.45)*scale
 for i,ray in ipairs(rays) do
  local theta=math.rad(angle)+(i-1)*math.pi*.5
  ray.tip.WorldPosition=position+(right*math.cos(theta)+up*math.sin(theta))*length*(i%2==1 and 1.18 or .78)
  ray.core.Width0=(.025+radius*.094)*scale
  ray.halo.Width0=ray.core.Width0*3.6
  ray.core.Transparency=coreAlpha;ray.halo.Transparency=haloAlpha
 end
end

function View.ramielCharge(rig,charge,untilContact,reduced,beamHold)
 local field=rig.chargeField
 beamHold=beamHold or DroneCatalog.Types.Ramiel.BeamHold
 if reduced or charge<=0 or not untilContact or untilContact>2.70 or untilContact<=-beamHold then
  if field then field.root:Destroy();rig.chargeField=nil end
  return
 end
 if not field then
  if liveRamielFields>=6 then return end
  local root=shotPart(rig.core,'RamielFlare',Vector3.one*.025,WHITE,false,1)
  liveRamielFields+=1
  root.Destroying:Connect(function() liveRamielFields-=1 end)
  local gui=Instance.new('BillboardGui');gui.Name='Flare';gui.Adornee=root
  gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.MaxDistance=150;gui.Parent=root
  local function star(name,color)
   local image=Instance.new('ImageLabel');image.Name=name;image.Image='rbxasset://textures/sparkle.png'
   image.AnchorPoint=Vector2.new(.5,.5);image.Position=UDim2.fromScale(.5,.5)
   image.BackgroundTransparency=1;image.ImageColor3=color;image.Parent=gui
   return image
  end
  local outer=star('PinkFlare',Color3.fromRGB(255,82,185));outer.Size=UDim2.fromScale(1,1)
  local inner=star('WhiteFlare',Color3.fromRGB(255,244,250));inner.Size=UDim2.fromScale(.77,.77)
  local ring=PlaneBurst.create(root,Color3.fromRGB(255,161,221))
  local wake=PlaneBurst.create(root,Color3.fromRGB(255,132,213))
  local lamp=Instance.new('PointLight')
  lamp.Name='RamielStarLight';lamp.Range=23;lamp.Color=Color3.fromRGB(255,241,252)
  lamp.Brightness=0;lamp.Enabled=false;lamp.Parent=root
  local motes={}
  for i=1,6 do motes[i]=EnergyDisc.sprite(root,'RamielInflow') end
  field={root=root,gui=gui,inner=inner,outer=outer,halo=EnergyDisc.sprite(root,'FlareHalo'),ring=ring,wake=wake,
   rays=starRays(root),lamp=lamp,motes=motes}
  rig.chargeField=field
 end
 local elapsed=-untilContact
 local launchFade=1-smooth((elapsed-.13)/.72)
 local firing=1-smooth((elapsed-(beamHold-.24))/.24)
 local radius=sampleCurve(RAMIEL_FLARE,elapsed)
 local bloom=1-smooth((elapsed-.055)/.31)
 local scale=rig.scale
 field.root.CFrame=rig.core.CFrame*CFrame.new(0,0,-.22)
 local width=(.06+radius*3.9)*scale
 local flashFlicker=elapsed>=0 and (.72+.28*math.cos(elapsed*135+1.2*math.sin(elapsed*83))) or 1
 local alpha=(.34+.66*smooth(radius/.32))*launchFade*firing*flashFlicker*smooth(radius/.05)
 local angle=sampleCurve(RAMIEL_STAR_ANGLE,elapsed)+20*smooth((elapsed-.58)/1.7)
 field.gui.Size=UDim2.fromScale(width,width)
 field.inner.Rotation=angle;field.outer.Rotation=angle
 field.inner.ImageTransparency=1-alpha*bloom
 field.outer.ImageTransparency=1-.73*alpha*bloom
 EnergyDisc.place(field.halo,field.root.Position,width*.78,Color3.fromRGB(255,102,197),.52*alpha*bloom*smooth(radius/.32))
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.xAxis
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 drawStar(field.rays,field.root.Position,right,up,angle,radius,scale,alpha)
 local sustain=smooth((elapsed-.12)/.27)*firing
 if sustain>0 or field.sustainRays then
  if not field.sustainRays then field.sustainRays=starRays(field.root) end
  local size=.61+.10*math.sin(elapsed*109+.8*math.sin(elapsed*63))
  local opacity=(.70+.25*math.sin(elapsed*97+1.6))*sustain
  drawStar(field.sustainRays,field.root.Position,right,up,angle+13,size,scale,opacity)
 end
 for i,mote in ipairs(field.motes) do
  local delay=(i-1)*.17
  local q=math.clamp((elapsed+2.60-delay)/(2.48-delay),0,1)
  local spiral=q^3
  local theta=i*math.pi/3+spiral*2.4
  local span=(2.45-2.13*spiral)*scale
  local offset=(right*math.cos(theta)+up*math.sin(theta))*span
  local visible=smooth(q/.23)*(1-smooth((q-.78)/.22))
  EnergyDisc.place(mote,field.root.Position+offset,(.12+.17*q)*scale,Color3.fromRGB(255,141,218),visible*.69)
 end
 local white=smooth((radius-.13)/1.85)*bloom
 field.lamp.Enabled=white>.01
 field.lamp.Brightness=white*9
 local rim=smooth((radius-.10)/.30)*launchFade
 PlaneBurst.pose(field.ring,Vector3.zAxis,scale*(.11+radius*1.27),rim*.76,scale*(.014+rim*.019))
 local pressure=smooth((elapsed+.09)/.13)*(1-smooth((elapsed-.15)/.64))
 local expansion=1-(1-math.clamp((elapsed+.09)/.94,0,1))^4
 PlaneBurst.pose(field.wake,Vector3.zAxis,scale*(.62+6.2*expansion),pressure*.70,scale*(.025+.045*pressure))
end

local function releaseLighting(self,at,weight,nomad)
 local flash=self.prismFlash
 if flash and math.abs(at-flash.at)<.22 then
  flash.weight=math.max(weight,flash.weight)
  if nomad then flash.at=at;flash.nomad=true end
  return
 end
 if not flash then
  local correction=Instance.new('ColorCorrectionEffect');correction.Name=nomad and 'NomadImpactExposure' or 'RamielReleaseExposure';correction.Enabled=false;correction.Parent=Lighting
  local bloom=Instance.new('BloomEffect');bloom.Name=nomad and 'NomadImpactBloom' or 'RamielReleaseBloom';bloom.Enabled=false;bloom.Parent=Lighting
  flash={correction=correction,bloom=bloom};self.prismFlash=flash
 end
 flash.at=at;flash.weight=weight;flash.nomad=nomad
end

local function stepReleaseLighting(self,now)
 local flash=self.prismFlash
 if not flash then return end
 local age=now-flash.at
 local player=Players.LocalPlayer
 if age>=.44 or BeamVFX.reduced() or player and player:GetAttribute('ReducedFlashing')==true then
  flash.correction:Destroy();flash.bloom:Destroy();self.prismFlash=nil
  return
 end
 local strength
 if flash.nomad then strength=(1-.76*smooth((age-.039)/.16))*(1-smooth((age-.14)/.29))*flash.weight
 else strength=(1-.82*smooth((age-.025)/.14))*(1-smooth((age-.12)/.32))*flash.weight end
 flash.correction.Brightness=(flash.nomad and 1 or .94)*strength
 flash.correction.Contrast=flash.nomad and -.24*strength*(1-strength) or -.19*strength
 flash.correction.Saturation=-.94*strength
 flash.bloom.Threshold=.69-.45*strength
 flash.bloom.Intensity=3.1*strength;flash.bloom.Size=54
 flash.correction.Enabled=true;flash.bloom.Enabled=true
end

local function clearLoad(self,r)
 if not r.load then return end
 r.load.root:Destroy();r.load=nil;self.loads-=1
end

local function gunCharge(self,r,origin,target,color,ball,q)
 if not r.load then
  if self.loads>=12 then return end
  local camera=workspace.CurrentCamera;if not camera then return end
  local root=shotPart(camera,'ProjectileCharge',Vector3.one*.025,color,false,1)
  local core=shotPart(root,'ChargedRound',Vector3.one*.04,color,true,1)
  local ring=ball and PlaneBurst.create(root,color) or nil
  local motes={}
  for i=1,ball and 3 or 2 do motes[i]=EnergyDisc.sprite(root,ball and 'CoilInflow' or 'NeedleInflow') end
  r.load={root=root,core=core,ring=ring,motes=motes};self.loads+=1
 end
 local load=r.load
 local frame=CFrame.lookAt(origin,target)
 local build=smooth((q-.10)/.61)
 local squeeze=smooth((q-.82)/.18)
 local focus=build*(1-.14*squeeze)
 local forward=(ball and .27 or .23)*smooth((q-.53)/.47)
 load.root.CFrame=frame*CFrame.new(0,0,-forward)
 load.core.CFrame=load.root.CFrame
 load.core.Color=color:Lerp(WHITE,.36+.55*build)
 load.core.Size=ball and Vector3.one*(.22+.62*focus) or Vector3.new(.19,.19,.54)*(.48+.70*focus)
 load.core.Transparency=1-focus*.92
 if load.ring then
  PlaneBurst.pose(load.ring,Vector3.zAxis,1.05-.54*smooth((q-.32)/.68),focus*.92,.13)
 end
 for i,mote in ipairs(load.motes) do
  local time=smooth((q-.12-i*.10)/.55)
  local angle=i*math.pi*2/3+time*1.45
  local radius=(1.27-.97*time)*(ball and 1 or .68)
  local point=load.root.CFrame:PointToWorldSpace(Vector3.new(math.cos(angle)*radius,math.sin(angle)*radius,-.72*(1-time)))
  EnergyDisc.place(mote,point,(ball and .78 or .52)*(.7+.3*time),color:Lerp(WHITE,.25+.43*time),
   smooth(time/.20)*(1-smooth((time-.72)/.28))*.58)
 end
end

local function addRibbon(part,color,ball)
 local a=Instance.new('Attachment');a.Position=Vector3.new(0,ball and -.26 or -.085,.08);a.Parent=part
 local b=Instance.new('Attachment');b.Position=Vector3.new(0,ball and .26 or .085,.08);b.Parent=part
 local trail=Instance.new('Trail');trail.Name=ball and 'EnergyWake' or 'NeedleTrace'
 trail.Attachment0=a;trail.Attachment1=b;trail.FaceCamera=true;trail.LightInfluence=0;trail.LightEmission=.88
 trail.Lifetime=ball and .26 or .14;trail.MinLength=.055;trail.MaxLength=ball and 7 or 4.8
 trail.Color=ColorSequence.new(color:Lerp(WHITE,.35),color)
 trail.WidthScale=NumberSequence.new(1,0)
 trail.Transparency=NumberSequence.new(.16,1);trail.Parent=part
 return trail
end

local function burst(self,from,direction,color,ball,impact,grade,at)
 local camera=workspace.CurrentCamera
 if not camera or #self.bursts>=BURST_LIMIT or BeamVFX.reduced() or not BeamVFX.near(from,76) then return end
 local node=shotPart(camera,'ShotSparks',Vector3.one*.025,color,false,1)
 node.CFrame=CFrame.lookAt(from,from+direction)
 local sparks=Instance.new('ParticleEmitter')
 EnergyDisc.configure(sparks,math.min(2.1,(ball and (impact and 1.43 or 1.08) or .75)*grade),impact and .47 or .59,.58,.64)
 sparks.Enabled=false;sparks.Rate=0
 local spread=impact and (ball and 76 or 37) or (ball and 34 or 17)
 sparks.EmissionDirection=Enum.NormalId.Front;sparks.SpreadAngle=Vector2.new(spread,spread)
 sparks.Color=ColorSequence.new(color:Lerp(WHITE,.38),color)
 sparks.Lifetime=NumberRange.new(.23,ball and .56 or .41)
 sparks.Speed=NumberRange.new(impact and 7 or 4,(ball and 13 or 15)*grade);sparks.Drag=ball and 4.8 or 6
 sparks.Acceleration=Vector3.new(0,-5,0)
 sparks.Parent=node;sparks:Emit(ball and math.min(10,math.floor((impact and 7 or 4)*grade)) or (impact and 5 or 3))
 local flash=shotPart(node,'ShotFlash',Vector3.one*.04,color:Lerp(WHITE,.57),ball,.09)
 flash.CFrame=node.CFrame
 local ring=ball and PlaneBurst.create(node,color) or nil
 self.bursts[#self.bursts+1]={node=node,flash=flash,ring=ring,direction=direction,at=at,scale=(ball and (impact and 1 or .47) or .46)*grade,ball=ball}
end
local function stepBursts(self,now)
 for i=#self.bursts,1,-1 do
  local b=self.bursts[i];local age=math.max(0,now-b.at)
  if age>=.61 or not b.node.Parent or BeamVFX.reduced() then
   b.node:Destroy();table.remove(self.bursts,i)
  else
   local flash=1-smooth(age/(b.ball and .13 or .09))
   local player=Players.LocalPlayer
   b.flash.Transparency=1-(player and player:GetAttribute('ReducedFlashing') and .23 or .82)*flash
   b.flash.Size=(b.ball and Vector3.one*1.25 or Vector3.new(.53,.53,1.95))*math.max(.04,b.scale*(1.15-.53*flash))
   if b.ring then PlaneBurst.draw(b.ring,b.direction,age/.24,b.scale*.88) end
  end
 end
end

local function clearProjectile(self,r,now,carryTail)
 local part=r.projectile or r.after
 if r.trail and carryTail and r.projectile then
  part.Transparency=1;if r.shell then r.shell.Transparency=1 end
  r.trail.Enabled=false;r.after=part;r.afterUntil=now+r.trail.Lifetime
 else
  if part then part:Destroy() end
  if part then self.heads-=1 end
  if r.trail then self.trails-=1;r.trail=nil end
  r.after=nil
 end
 r.projectile=nil
end

function View.new(audio,onPrism,onNomadImpact,onPrismCharge)
 local self={records={},connections={},root=nil,trails=0,heads=0,loads=0,bursts={}}
 local function nomadFlash(position,at)
  local camera=workspace.CurrentCamera
  if not camera then return end
  local player=Players.LocalPlayer
  local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  local cameraDistance=(camera.CFrame.Position-position).Magnitude
  local distance=root and math.max((root.Position-position).Magnitude,cameraDistance*.65) or cameraDistance
  if distance<115 then releaseLighting(self,at,1-smooth((distance-25)/90),true) end
 end
 local function attach(root)
  if self.root==root then return end
  self.root=root
  local function observe(node)
   if node:IsA('Folder') then self.records[node]={samples={}} end
  end
  for _,node in ipairs(root:GetChildren()) do observe(node) end
  self.connections[#self.connections+1]=root.ChildAdded:Connect(observe)
 end
 local root=workspace:FindFirstChild('DroneRoleState');if root then attach(root) end
 self.connections[#self.connections+1]=workspace.ChildAdded:Connect(function(node) if node.Name=='DroneRoleState' then attach(node) end end)
 function self:step(now,droneIndex,resources)
  for node,r in pairs(self.records) do
   local kind=node:GetAttribute('Kind');local owner=node -- isolate overlapping old/new effects for the same player
   if not node.Parent then
    if not r.detached then
     r.detached=true
     if r.projectile then clearProjectile(self,r,now,true) end
     clearLoad(self,r)
     clearPrismAim(r)
     if audio and audio.stopLoop then audio:stopLoop(node) end
     if r.started and kind=='AbilityCharge' then RoleVisuals.Ability(owner,{kind='clearCharge'}) end
     if r.started and kind=='Orbital' and not r.ended then RoleVisuals.Ability(owner,{kind='orbitalEnd'}) end
    end
    if NomadView.detach(r,now) and (not r.after or now>=r.afterUntil) then
     clearProjectile(self,r,now,false);self.records[node]=nil
    end
   elseif kind=='MiningShot' then
    if r.after and now>=r.afterUntil then clearProjectile(self,r,now,false) end
    local from=node:GetAttribute('From');local to=node:GetAttribute('Position')
    local at=node:GetAttribute('StartedAt');local duration=node:GetAttribute('Duration');local paused=node:GetAttribute('PausedAt') or 0
    if typeof(from)~='Vector3' or typeof(to)~='Vector3' or type(at)~='number' or type(duration)~='number' or duration<=0 or (to-from).Magnitude<.01 then continue end
    local windup=node:GetAttribute('Windup') or 0
    local age=(paused>0 and math.min(paused,now) or now)-at
    local progress=(age-windup)/duration
    local drone=droneIndex and droneIndex[node:GetAttribute('Actor')]
    local contactAt=node:GetAttribute('ContactAt')
    local landed=contactAt and now>=contactAt
    local shape=node:GetAttribute('Shape')
    local hold=shape=='Prism' and (node:GetAttribute('BeamHold') or DroneCatalog.Types.Ramiel.BeamHold) or 0
    local activePrism=shape=='Prism' and (landed and now-contactAt<hold or not landed and age<windup+.35)
    if drone and not r.bound and age>=0 and (progress<1 and not landed or activePrism) then
     r.bound=true
     local previous=drone.shotReceipt
     if not previous or at>(previous:GetAttribute('StartedAt') or 0) then drone.shotReceipt=node end
    end
    local anchor=node:GetAttribute('TargetAnchor')
    local target=resources and resources[node:GetAttribute('TargetId') or '']
    if shape=='Nomad' then
     NomadView.step(r,node,now,from,to,age,windup,progress,audio,onNomadImpact,nomadFlash)
     continue
    end
    if typeof(anchor)=='Vector3' and target and target.view.Parent and target.view.Transparency<1 then
     to=target.view.CFrame:PointToWorldSpace(anchor*target.view.Size)
    end
    local ball=shape=='Ball'
    local color=node:GetAttribute('Color')
    if not color then continue end
    if shape=='Prism' then
     local aperture=drone and (drone.ramiel and drone.ramiel.core.Position or drone.view:GetPivot().Position) or from
     local point=node:GetAttribute('ContactPoint') or to
     local origin=node:GetAttribute('PrismFrom') or aperture
     local endpoint=node:GetAttribute('PrismEnd') or point
     local travel=endpoint-origin
     local firingAge=landed and now-contactAt
     local q=windup>0 and math.clamp(age/windup,0,1) or 0
     local charging=not landed and q>.12 and age<windup+duration+.22
     local camera=workspace.CurrentCamera
     if charging and camera and travel.Magnitude>.1 and BeamVFX.near(origin:Lerp(endpoint,.5),140) then
      local player=Players.LocalPlayer
      local lowEffects=BeamVFX.reduced() or (player and player:GetAttribute('ReducedFlashing')==true)
      local strength=smooth((q-.12)/.16)*(.36+.64*q^2)
      drawPrismAim(r,camera,origin,endpoint,lowEffects and strength*.66 or strength,lowEffects)
      if onPrismCharge and paused<=0 and q>.79 then onPrismCharge(origin,endpoint,smooth((q-.79)/.21),now) end
     else clearPrismAim(r) end
     if audio and audio.setLoop then
      if firingAge and firingAge<hold then
       local camera=workspace.CurrentCamera
       local player=Players.LocalPlayer
       local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
       local listener=root and root.Position or (camera and camera.CFrame.Position) or origin
       local along=math.clamp((listener-origin):Dot(travel)/math.max(.01,travel:Dot(travel)),.08,.94)
       local settle=smooth(firingAge/.31)
       local fade=smooth((hold-firingAge)/.26)
       audio:setLoop(node,'prism_sustain',origin+travel*along,(1.34-.19*settle)*fade,.93-.16*settle)
      elseif not landed and age>=0 and age<windup+duration+.22 and paused<=0 and q>.30 then
       local rise=smooth((q-.30)/.70)
       audio:setLoop(node,'prism_charge',aperture,.13+.95*rise,.65+.63*rise^3)
      else audio:stopLoop(node,landed==true) end
     end
     local shatterAt=node:GetAttribute('ShatterAt')
     local ground=node:GetAttribute('BlastGround')
     local radius=node:GetAttribute('BlastRadius') or 7
     if shatterAt and shatterAt<=now and typeof(ground)=='Vector3' and not r.shattered then
      r.shattered=true
      RoleVisuals.setTime(shatterAt)
      RoleVisuals.PrismShatter(ground,radius,shatterAt,travel)
      if audio and now-shatterAt<.24 and BeamVFX.near(ground,135) then audio:play('prism_blast',ground,{level=1.18,pitch=.88}) end
     end
     if landed and not r.impacted then
      r.impacted=true
      if now-contactAt<hold and travel.Magnitude>.1 and BeamVFX.near(origin:Lerp(endpoint,.48),150) then
       RoleVisuals.setTime(contactAt)
       local reduced=BeamVFX.reduced() or Players.LocalPlayer:GetAttribute('ReducedFlashing')==true
       local gap=math.min(travel.Magnitude*.14,1.22)
       local groundNormal=node:GetAttribute('PrismGroundNormal')
       RoleVisuals.Beam(origin+travel.Unit*gap,endpoint,PRISM_RED,reduced and .88 or 1.52,hold,'Prism',groundNormal)
       if typeof(ground)=='Vector3' then RoleVisuals.PrismWave(ground,radius,hold) end
       if onPrism then onPrism(origin,endpoint,contactAt,hold) end
       if now-contactAt>=.18 then continue end
       if not reduced then
        local camera=workspace.CurrentCamera
        local distance=camera and (camera.CFrame.Position-origin).Magnitude or math.huge
        if distance<90 and now-contactAt<.14 then releaseLighting(self,contactAt,1-smooth((distance-31)/59)) end
        burst(self,origin,travel.Unit,PRISM_RED,true,false,1.82,now)
        local normal=node:GetAttribute('ContactNormal') or -travel.Unit
        burst(self,point+normal*.22,normal,PRISM_RED,true,true,1.60,now)
        for i=1,math.clamp(node:GetAttribute('PrismHits') or 0,0,3) do
         local contact=node:GetAttribute('PrismHit'..i)
         local surface=node:GetAttribute('PrismNormal'..i) or -travel.Unit
         if contact then burst(self,contact+surface*.18,surface,PRISM_RED,true,true,1.23-(i-1)*.10,now) end
        end
       end
       if audio then audio:play('prism_fire',origin);audio:play('coil_hit',point,{level=1.35,pitch=.68}) end
      end
     end
     continue
    end
    local muzzle=drone and drone.shotMuzzle and drone.shotMuzzle.WorldPosition
    if muzzle and ((muzzle-from).Magnitude>=2.5 or (to-muzzle).Magnitude<=1) then muzzle=nil end
    if age>=0 and progress<0 and not landed then
     local q=age/windup
     if not r.loaded then
      r.loaded=true
      if paused<=0 and age<.13 and audio then audio:play(ball and 'coil_load' or 'needle_cock',muzzle or from) end
     end
     if not BeamVFX.reduced() and BeamVFX.near(muzzle or from,95) then
      gunCharge(self,r,muzzle or from,to,color,ball,q)
     else clearLoad(self,r) end
    else
     clearLoad(self,r)
    end
    if landed and not r.impacted then
     r.impacted=true
     local point=node:GetAttribute('ContactPoint') or to
     local travel=point-(r.launchFrom or from)
     if now-contactAt<.16 and travel.Magnitude>.01 then
      local normal=node:GetAttribute('ContactNormal') or -travel.Unit
      local fractured=node:GetAttribute('ContactFracture') or node:GetAttribute('ContactBroken')
      local grade=fractured and 1.3 or (node:GetAttribute('ContactPowered') and 1.12 or .88)
      burst(self,point+normal*(ball and .34 or .065),normal,color,ball,true,grade,now)
      if audio then audio:play(ball and 'coil_hit' or 'needle_hit',point,{level=grade,pitch=fractured and .91 or 1}) end
     end
    end
    local resolved=landed or (not contactAt and (progress>1+.16/duration or (not target and progress>=1)))
    if resolved then
     if r.projectile then clearProjectile(self,r,now,true) end
     r.started=true
    elseif progress>=0 and not r.started and (r.projectile or BeamVFX.near(from,140)) then
     local value=r.projectile
     if not value and self.heads<SHOT_LIMIT then
      local camera=workspace.CurrentCamera
      if not camera then continue end
      value=shotPart(camera,'MiningProjectile',ball and Vector3.one*.81 or Vector3.new(.15,.15,1.48),color:Lerp(WHITE,.53),ball)
      r.projectile=value;self.heads+=1
      if ball and not BeamVFX.reduced() then r.shell=shotPart(value,'EnergyShell',Vector3.one*1.07,color,true,.47) end
      r.launchFrom=muzzle or from
      if self.trails<TRAIL_LIMIT and not BeamVFX.reduced() then
       r.trail=addRibbon(value,color,ball);self.trails+=1
      end
     end
     from=r.launchFrom or from
     local delta=to-from
     if delta.Magnitude<.01 then continue end
     local direction=delta.Unit
     if not r.fired then
      r.fired=true
      if paused<=0 and age-windup<.12 then
       burst(self,from+direction*.17,direction,color,ball,false,1,now)
       if audio then audio:play(ball and 'coil_fire' or 'needle_fire',from) end
      end
     end
     if not value then continue end
     local t=math.clamp(progress,0,1)
     local lead=t*(.52+.48*(2*t-t*t))
     local stretch=1+(ball and .36 or .31)*smooth(t/.21)*(1-smooth((t-.26)/.58))
     value.Size=ball and Vector3.new(.81,.81,.81*stretch) or Vector3.new(.15,.15,1.48*stretch)
     local center=from:Lerp(to,lead)-direction*(value.Size.Z*.5)
     value.CFrame=CFrame.lookAt(center,center+direction)
     if r.shell then r.shell.CFrame=value.CFrame;r.shell.Size=Vector3.new(1.06,1.06,1.06*stretch) end
    end
   elseif kind=='Orbital' then
    local at=node:GetAttribute('ContactAt');local position=node:GetAttribute('Position');local ended=node:GetAttribute('EndedAt')
    if typeof(position)=='Vector3' and type(at)=='number' and now>=at then
     local ground=node:GetAttribute('Ground')
     local radius=node:GetAttribute('Radius') or 1
     if ended and now>=ended and node:GetAttribute('Completed')==true and not r.rubble then
      r.rubble=true
      RoleVisuals.Crater(Vector3.new(position.X,ground or position.Y,position.Z),math.clamp(4.8+radius*1.15,6,10),'Orbital',ended)
     end
     MotionBuffer.push(r.samples,at,CFrame.new(position))
     local pose=MotionBuffer.pose(r.samples,now)
     -- Do not replay completed strikes to a late joiner.
     if not ended or r.started then
      if not r.ended then
       RoleVisuals.setTime(at)
       RoleVisuals.Ability(owner,{kind='orbital',startedAt=node:GetAttribute('StartedAt') or at,target={x=pose.Position.X,y=pose.Position.Y,z=pose.Position.Z,
        ground=node:GetAttribute('Ground'),radius=node:GetAttribute('Radius')}})
       r.started=true
       if ended then RoleVisuals.setTime(ended);RoleVisuals.Ability(owner,{kind='orbitalEnd'});r.ended=true end
      end
     end
    end
   elseif not r.started and kind and kind~='ScrapSwarm' then
    local at=node:GetAttribute('StartedAt');local position=node:GetAttribute('Position')
    local from=node:GetAttribute('From')
    local needsFrom=kind=='Beam' or kind=='Heal' or kind=='Charge' or kind=='Grow' or kind=='Breaker'
    local ready=not needsFrom or typeof(from)=='Vector3'
    if kind=='Beam' or kind=='Pulse' then ready=ready and node:GetAttribute('Color')~=nil and type(node:GetAttribute('Duration'))=='number' end
    if kind=='Beam' then ready=ready and type(node:GetAttribute('Width'))=='number' end
    if kind=='Pulse' then ready=ready and type(node:GetAttribute('First'))=='number' and type(node:GetAttribute('Last'))=='number' end
    if kind=='Grow' then ready=ready and type(node:GetAttribute('Planted'))=='boolean' end
    if kind=='Charge' then ready=ready and type(node:GetAttribute('Impact'))=='boolean' end
    if kind=='Breaker' then ready=ready and type(node:GetAttribute('Phase'))=='string' end
    if kind=='AbilityCharge' or kind=='AbilityPulse' then ready=ready and type(node:GetAttribute('Ability'))=='string' end
    if ready and type(at)=='number' and typeof(position)=='Vector3' and now>=at then
     r.started=true
     local age=now-at
     local expires=node:GetAttribute('ExpiresAt') or at+1
     if kind=='Breaker' and node:GetAttribute('Phase')=='Impact' then
      local ground=node:GetAttribute('Ground')
      if type(ground)=='number' then
       local scale=math.clamp((node:GetAttribute('Diameter') or 3)/3,.65,3)
       RoleVisuals.Crater(Vector3.new(position.X,ground,position.Z),math.clamp(3.4*scale,2.8,6.8),'Breaker',at,position-from)
      end
     end
     -- Short contact cues are never replayed as fresh hits after a late join.
     if now<expires and (age<=.35 or kind=='AbilityCharge' or kind=='Pulse' or kind=='Beam') then
      RoleVisuals.setTime(at)
      local from=node:GetAttribute('From');local color=node:GetAttribute('Color')
      if kind=='Beam' then RoleVisuals.Beam(from,position,color,node:GetAttribute('Width'),node:GetAttribute('Duration'))
      elseif kind=='Pulse' then RoleVisuals.Pulse(position,color,node:GetAttribute('First'),node:GetAttribute('Last'),node:GetAttribute('Duration'))
      elseif kind=='Heal' then RoleVisuals.Heal(from,position)
      elseif kind=='Charge' then RoleVisuals.Charge(from,position,node:GetAttribute('Impact'))
      elseif kind=='Grow' then RoleVisuals.Grow(from,position,node:GetAttribute('Planted'))
      elseif kind=='Breaker' then RoleVisuals.BreakerPhase(from,position,node:GetAttribute('Phase'),node:GetAttribute('Diameter'))
      elseif kind=='AbilityCharge' or kind=='AbilityPulse' then
       RoleVisuals.Ability(owner,{kind=kind=='AbilityCharge' and 'charge' or node:GetAttribute('Ability'),ability=node:GetAttribute('Ability'),duration=node:GetAttribute('Duration') or 1.4,target={x=position.X,y=position.Y,z=position.Z,ground=node:GetAttribute('Ground'),radius=node:GetAttribute('Radius')}})
      end
     end
    end
   end
  end
  stepBursts(self,now)
  stepReleaseLighting(self,now)
  RoleVisuals.setTime(nil);RoleVisuals.step(now)
 end
 function self:destroy()
  stepReleaseLighting(self,math.huge)
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  for node,r in pairs(self.records) do
   clearProjectile(self,r,0,false);clearLoad(self,r);clearPrismAim(r)
   NomadView.clear(r)
   if audio and audio.stopLoop then audio:stopLoop(node) end
  end
  for _,b in ipairs(self.bursts) do b.node:Destroy() end
  table.clear(self.bursts);table.clear(self.records);RoleVisuals.destroy()
 end
 return self
end
return View
