-- A Studio-only effects station. Its clock and geometry never feed gameplay.
local Preview={}
local PERIOD,RELEASE,FRONT=6.6,1.25,1.10
local GOLD=Color3.fromRGB(255,171,37)
local WHITE=Color3.fromRGB(255,248,205)
local ICE=Color3.fromRGB(135,210,255)
local STAR='rbxassetid://77624818077620'
local Y=Vector3.yAxis
local CLEAR=CFrame.new()
local TAU=math.pi*2
local function unit(t) return math.clamp(t,0,1) end
local function front(t) return .88*(1-math.exp(-7*t))+.12*t end
local function part(parent,name,position)
 local p=Instance.new('Part');p.Name=name;p.Size=Vector3.one*.05;p.Position=position
 p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=parent
 return p
end
local function star(parent,name,color)
 local gui=Instance.new('BillboardGui');gui.Name=name;gui.Parent=parent;gui.LightInfluence=0;gui.Enabled=false
 local image=Instance.new('ImageLabel');image.BackgroundTransparency=1;image.Size=UDim2.fromScale(1,1)
 image.Image=STAR;image.ImageColor3=color;image.Parent=gui
 return {gui=gui,image=image}
end
-- Geometry backs up the sprite so a missing or slow asset cannot hide the star.
local function rays(parent)
 local center=Instance.new('Attachment');center.Parent=parent
 local result={}
 for i=1,8 do
  local tip=Instance.new('Attachment');tip.Parent=parent
  local blade=Instance.new('Beam');blade.Name='CelestialStarRay';blade.Attachment0=center;blade.Attachment1=tip
  blade.Width1=.005;blade.FaceCamera=true;blade.LightInfluence=0;blade.LightEmission=1
  blade.Color=ColorSequence.new(WHITE,i%2==1 and GOLD or ICE);blade.Enabled=false;blade.Parent=parent
  result[i]={tip=tip,beam=blade}
 end
 return result
end
local function drawRays(starRays,camera,span,alpha)
 for i,r in ipairs(starRays) do
  local angle=(i-1)*TAU/8;local main=i%2==1
  r.tip.Position=(camera.RightVector*math.cos(angle)+camera.UpVector*math.sin(angle))*span*(main and 1 or .32)
  r.beam.Width0=span*(main and .21 or .09)
  r.beam.Enabled=alpha>.018
  if r.beam.Enabled then r.beam.Transparency=NumberSequence.new(1-unit(alpha),1) end
 end
end
local function glow(s,size,alpha)
 s.gui.Enabled=alpha>.01
 if alpha<=.01 then return end
 s.gui.Size=UDim2.fromScale(size,size);s.image.ImageTransparency=1-unit(alpha)
end
local function light(parent,range)
 local l=Instance.new('PointLight');l.Color=GOLD;l.Range=range;l.Brightness=0;l.Parent=parent;return l
end
local function emitter(parent,name,color,shape,direction,speed,life,size)
 local p=Instance.new('ParticleEmitter');p.Name=name;p.Texture=STAR;p.Enabled=false;p.Rate=0
 p.Color=color;p.Shape=shape;p.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
 p.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward;p.EmissionDirection=direction
 p.SpreadAngle=Vector2.new(70,70);p.Speed=speed;p.Lifetime=life;p.Size=size
 p.LightEmission=.85;p.LightInfluence=0;p.Brightness=1.6
 p.Rotation=NumberRange.new(-30,30);p.Drag=3
 p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.14),NumberSequenceKeypoint.new(.19,.31,.22),
  NumberSequenceKeypoint.new(.53,.62,.28),NumberSequenceKeypoint.new(.76,.43,.36),NumberSequenceKeypoint.new(1,1)})
 p.Parent=parent;return p
end
local function ribbon(parent,name,color)
 local a=Instance.new('Attachment');a.Parent=parent
 local b=Instance.new('Attachment');b.Parent=parent
 local beam=Instance.new('Beam');beam.Name=name;beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.Segments=12;beam.LightEmission=.88;beam.LightInfluence=0;beam.Brightness=2
 beam.Color=color;beam.Enabled=false;beam.Parent=parent
 return {a=a,b=b,beam=beam}
end
local function axis(pos,tangent)
 local x=tangent.Unit
 local ref=math.abs(x:Dot(Y))>.97 and Vector3.zAxis or Y
 local z=x:Cross(ref).Unit
 return CFrame.fromMatrix(pos,x,z:Cross(x),z)
end
local function trail(r,origin,pointAt,tangentAt,lo,hi,width,alpha)
 r.beam.Enabled=hi-lo>.005 and alpha>.008
 if not r.beam.Enabled then return end
 local first,last=tangentAt(lo),tangentAt(hi)
 r.a.CFrame=axis(pointAt(lo)-origin,first);r.b.CFrame=axis(pointAt(hi)-origin,last)
 r.beam.CurveSize0=first.Magnitude*(hi-lo)/3;r.beam.CurveSize1=last.Magnitude*(hi-lo)/3
 r.beam.Width0=width*.18;r.beam.Width1=width
 r.beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1-.19*alpha),
  NumberSequenceKeypoint.new(.34,1-.71*alpha),NumberSequenceKeypoint.new(1,1-alpha)})
end
local function surface(pos,params)
 return workspace:Raycast(pos+Y*12,-Y*44,params)
end
function Preview.new(world,parent,player,onRelease)
 local self={world=world,parent=parent,player=player,onRelease=onRelease,nextCheck=0}
 return setmetatable(self,{__index=Preview})
end
function Preview:locate(now)
 if self.center then return true end
 if now<self.nextCheck then return false end
 self.nextCheck=now+1
 local home=self.world:GetAttribute('DepotHome')
 if typeof(home)~='Vector3' then return false end
 local params=RaycastParams.new();params.RespectCanCollide=true
 params.FilterDescendantsInstances=self.player.Character and {self.parent,self.player.Character} or {self.parent}
 local look=self.world:GetAttribute('StarterLookAt')
 local forward=typeof(look)=='Vector3' and (look-home)*Vector3.new(1,0,1) or Vector3.new(0,0,-1)
 if forward.Magnitude<.01 then forward=Vector3.new(0,0,-1) end
 forward=forward.Unit
 local side=forward:Cross(Y)
 local pos=home+forward*22+side*12
 self.markerAt=home+forward*6+side*5
 local hit=surface(pos,params)
 if not hit then return false end
 self.center=hit.Position;self.origin=self.center+Y*9;self.params=params
 return true
end
function Preview:build(now)
 local root=Instance.new('Folder');root.Name='CelestialRainTest';root.Parent=self.parent
 self.root=root;self.start=now;self.strands={}
 local core=part(root,'ReleaseOrigin',self.origin)
 self.star=star(core,'GoldStar',GOLD);self.flash=star(core,'WhiteFlash',WHITE)
 self.rays=rays(core)
 self.airLight=light(core,24)
 self.fronts={PlaneBurst.create(core,ICE),PlaneBurst.create(core,WHITE),PlaneBurst.create(core,GOLD)}
 self.glitter=emitter(core,'SuspendedGlitter',ColorSequence.new(WHITE,ICE),Enum.ParticleEmitterShape.Sphere,
  Enum.NormalId.Top,NumberRange.new(9,32),NumberRange.new(1.3,3.7),NumberSequence.new(.13,.025))
 self.glitter.SpreadAngle=Vector2.new(180,180);self.glitter.Drag=2.5;self.glitter.Acceleration=Y*.35
 self.needleSpray=emitter(core,'BurstNeedles',ColorSequence.new(ICE,WHITE),Enum.ParticleEmitterShape.Sphere,
  Enum.NormalId.Top,NumberRange.new(36,74),NumberRange.new(.21,.52),NumberSequence.new(.37,.05))
 self.needleSpray.SpreadAngle=Vector2.new(180,180);self.needleSpray.Drag=4
 self.needleSpray.Orientation=Enum.ParticleOrientation.VelocityParallel
 self.needleSpray.Squash=NumberSequence.new(-.83);self.needleSpray.Rotation=NumberRange.new(0)
 local markerGround=surface(self.markerAt,self.params)
 local marker=part(root,'CelestialRainSpawnMarker',(markerGround and markerGround.Position or self.markerAt)+Y*4)
 local markerGui=Instance.new('BillboardGui');markerGui.Name='CelestialRainMarker';markerGui.Size=UDim2.fromOffset(200,44)
 markerGui.LightInfluence=0;markerGui.AlwaysOnTop=true;markerGui.MaxDistance=34;markerGui.Parent=marker
 local hint=Instance.new('TextLabel');hint.BackgroundTransparency=1;hint.Size=UDim2.fromScale(1,1)
 hint.Text='✦  CELESTIAL RAIN\nSTAR BURST TEST NEARBY';hint.Font=Enum.Font.GothamBold;hint.TextSize=14
 hint.TextColor3=WHITE;hint.TextStrokeTransparency=.22;hint.Parent=markerGui
 local labelAnchor=part(root,'CelestialRainTestMarker',self.center+Y*2.1)
 local targetLabel=markerGui:Clone();targetLabel.MaxDistance=95;targetLabel.AlwaysOnTop=false;targetLabel.Parent=labelAnchor
 targetLabel:FindFirstChildWhichIsA('TextLabel').Text='✦  CELESTIAL RAIN'
 local plaque=part(root,'CelestialRainPreviewSign',self.center+Vector3.new(0,.06,0))
 local signGround=surface(plaque.Position,self.params)
 if signGround then plaque.Position=signGround.Position+Y*.06 end
 plaque.Size=Vector3.new(12,.12,1.8);plaque.Transparency=0;plaque.Color=Color3.fromRGB(27,34,46)
 local surfaceGui=Instance.new('SurfaceGui');surfaceGui.Face=Enum.NormalId.Top;surfaceGui.CanvasSize=Vector2.new(720,110);surfaceGui.Parent=plaque
 local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
 label.Text='CELESTIAL RAIN  /  VFX TEST';label.Font=Enum.Font.GothamBold;label.TextSize=39;label.TextColor3=WHITE;label.Parent=surfaceGui
 local rng=Random.new(173)
 for i=1,15 do
  local angle=i*2.39996+rng:NextNumber(-.22,.22)
  local dir=Vector3.new(math.cos(angle),0,math.sin(angle))
  local radius=rng:NextNumber(5,14)
  local land=surface(self.center+dir*radius,self.params)
  if not land then continue end
  local point=land.Position+land.Normal*.055
  -- Quadratic with an almost horizontal launch and a steep finish at the surveyed contact.
  local source=self.origin;local control=source+dir*radius*.92+Y*rng:NextNumber(1,5)
  local spark=part(root,'StrandHead',source)
  local foot=part(root,'GroundContact',point);foot.CFrame=CFrame.fromMatrix(point,axis(point,land.Normal).UpVector,land.Normal)
  local splash=emitter(foot,'ImpactSparks',ColorSequence.new(WHITE,GOLD),Enum.ParticleEmitterShape.Box,
   Enum.NormalId.Top,NumberRange.new(7,18),NumberRange.new(.28,.72),NumberSequence.new(.21,.035))
  splash.SpreadAngle=Vector2.new(45,45);splash.Acceleration=-Y*25;splash.Drag=2
  self.strands[#self.strands+1]={
   point=point,normal=foot.CFrame:VectorToObjectSpace(land.Normal),fall=rng:NextNumber(1.05,1.62),launch=rng:NextNumber(.06,.48),
   pointAt=function(t) return source:Lerp(control,t):Lerp(control:Lerp(point,t),t) end,
   tangentAt=function(t) return ((control-source)*(1-t)+(point-control)*t)*2 end,
   ribbon=ribbon(core,'GoldFilament',ColorSequence.new(GOLD,WHITE)),head=spark,glint=star(spark,'FallingGlint',WHITE),
   foot=foot,splash=splash,flash=star(foot,'ContactFlash',WHITE),ring=PlaneBurst.create(foot,GOLD),
  }
 end
end
function Preview:step(now,camera)
 if not self:locate(now) then return end
 if (camera.CFrame.Position-self.center).Magnitude>125 then self:destroy();return end
 if not self.root then self:build(now) end
 local elapsed=now-self.start
 local cycle=math.floor(elapsed/PERIOD)
 local t=elapsed%PERIOD-RELEASE
 local prior=self.cycle==cycle and self.t or -RELEASE
 self.cycle=cycle;self.t=t
 local reduced=BeamVFX.reduced()
 local lowFlash=self.player:GetAttribute('ReducedFlashing')==true
 local _,visible=camera:WorldToViewportPoint(self.origin)
 local _,groundVisible=camera:WorldToViewportPoint(self.center)
 if prior<0 and t>=0 and t<.16 then
  self.glitter:Emit(reduced and 18 or 86)
  if not reduced then self.needleSpray:Emit(45) end
  if not lowFlash and not reduced and visible and self.onRelease then self.onRelease(self.origin) end
 end

 local q=unit(t/FRONT);local wave=front(q)
 local opacity=(1-q)^2
 local facing=camera.CFrame.Position-self.origin
 local normal=facing.Magnitude>.01 and facing.Unit or Y
 for i,ring in ipairs(self.fronts) do
  PlaneBurst.pose(ring,normal,.45+(18+i*.45)*wave,t>=0 and opacity*(i==2 and .48 or .20) or 0,
   (.13+(1-q)*.58)*(i==2 and 1 or 2))
 end
 if t<0 then
  local charge=unit(1+t/RELEASE)
  drawRays(self.rays,camera.CFrame,.32+.69*charge^3,.69)
  glow(self.star,.65+1.10*charge^3,.7);glow(self.flash,.1,0)
  self.airLight.Brightness=.1+charge*.7
 else
  local peak=math.exp(-t*8)
  drawRays(self.rays,camera.CFrame,.98+4.7*wave,math.exp(-t*3.8)*(lowFlash and .43 or .94))
  glow(self.star,1.8+8.6*wave,.82*math.exp(-t*2.5))
  glow(self.flash,1.55+4.4*wave,(lowFlash and .25 or 1)*peak)
  self.airLight.Brightness=(lowFlash and 1.1 or 6)*peak
 end

 local contacts=Vector3.zero
 for i,s in ipairs(self.strands) do
  local age=t-s.launch-s.fall
  local travel=unit((t-s.launch)/s.fall)
  local head=travel*(.77+.23*travel)
  local tail=unit(age/.39)
  local alpha=(1-tail)^.75*unit(travel*14)
  trail(s.ribbon,self.origin,s.pointAt,s.tangentAt,tail,head,.069,alpha)
  if travel>0 and age<0 then
   s.head.Position=s.pointAt(head)
   glow(s.glint,(i%3==0 and .75 or .44)*unit(travel*14),alpha)
  else s.glint.gui.Enabled=false end
  if age>=0 and age<.15 and prior<s.launch+s.fall then s.splash:Emit(reduced and 4 or i%3==0 and 17 or 9) end
  local fade=age>=0 and 1-unit(age/.48) or 0
  glow(s.flash,1+2.3*(1-fade),fade^3)
  PlaneBurst.pose(s.ring,s.normal,.22+2.4*front(1-fade),fade^2*.67,.12)
  if age>=0 and age<.47 then
   local _,visible=camera:WorldToViewportPoint(s.point)
   local weight=visible and (1-unit((camera.CFrame.Position-s.point).Magnitude/65)) or 0
   local hit=math.exp(-age*9)*unit(age/.026)*weight
   contacts+=Vector3.new(math.sin(age*96+i)*.15,math.cos(age*81+i)*.22,.13)*hit
  end
 end
 if reduced or CrystalImpactView.reducedMotion() then return CLEAR end
 local weight=(visible or groundVisible) and (1-unit(facing.Magnitude/91)) or 0
 -- The same two rates that expand the front drive the shove and its long release.
 local pressure=t>=0 and t<FRONT and unit(t/.035)*(1-q)*(.88*math.exp(-7*q)+.12) or 0
 local shove=normal*pressure*weight*3.35
 local rumble=t>=0 and t<FRONT and unit(t/.026)*(1-q)^1.4 or 0
 local jitter=Vector3.new(math.sin(t*76)*.52,math.cos(t*61)*.45,math.sin(t*43)*.16)*rumble*weight
 contacts=contacts.Magnitude>.40 and contacts.Unit*.40 or contacts
 return CFrame.new(camera.CFrame:VectorToObjectSpace(shove)+jitter+contacts)
end
function Preview:resume(held)
 if self.start and self.root then self.start+=held end
end
function Preview:destroy()
 if not self.root then return end
 self.root:Destroy();self.root=nil;self.cycle=nil;self.t=nil
end
return Preview
