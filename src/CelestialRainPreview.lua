-- A Studio-only effects station. Its clock and geometry never feed gameplay.
local Preview={}
local PERIOD,RELEASE,FRONT=6.6,1.45,.86
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
function Preview.new(world,parent,player)
 local self={world=world,parent=parent,player=player,nextCheck=0}
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
 local pos=home+Vector3.new(-45,0,-10)
 local hit=surface(pos,params)
 if not hit then return false end
 self.center=hit.Position;self.origin=self.center+Y*19;self.params=params
 return true
end
function Preview:build(now)
 local root=Instance.new('Folder');root.Name='CelestialRainTest';root.Parent=self.parent
 self.root=root;self.start=now;self.strands={}
 local core=part(root,'ReleaseOrigin',self.origin)
 self.star=star(core,'GoldStar',GOLD);self.flash=star(core,'WhiteFlash',WHITE)
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
 local plaque=part(root,'CelestialRainPreviewSign',self.center+Vector3.new(0,.06,7))
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
 if BeamVFX.reduced() or (camera.CFrame.Position-self.center).Magnitude>76 then self:destroy();return end
 if not self.root then self:build(now) end
 local elapsed=now-self.start
 local cycle=math.floor(elapsed/PERIOD)
 local t=elapsed%PERIOD-RELEASE
 local prior=self.cycle==cycle and self.t or -RELEASE
 self.cycle=cycle;self.t=t
 if prior<0 and t>=0 and t<.16 then self.glitter:Emit(126);self.needleSpray:Emit(38) end

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
  glow(self.star,.65+1.10*charge^3,.7+.16*math.sin(24*t)^2);glow(self.flash,.1,0)
  self.airLight.Brightness=.1+charge*.7
 else
  local peak=math.exp(-t*8)
  glow(self.star,.9+3.6*wave,.72*math.exp(-t*1.9));glow(self.flash,.55+3.1*wave,peak)
  self.airLight.Brightness=5*peak
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
  if age>=0 and age<.15 and prior<s.launch+s.fall then s.splash:Emit(i%3==0 and 19 or 11) end
  local fade=age>=0 and 1-unit(age/.48) or 0
  glow(s.flash,1+2.3*(1-fade),fade^3)
  PlaneBurst.pose(s.ring,s.normal,.22+2.4*front(1-fade),fade^2*.67,.12)
  if age>=0 and age<.33 then
   local _,visible=camera:WorldToViewportPoint(s.point)
   local weight=visible and (1-unit((camera.CFrame.Position-s.point).Magnitude/65)) or 0
   local hit=math.exp(-age*13)*unit(age/.026)*weight
   contacts+=Vector3.new(math.sin(age*96+i)*.15,math.cos(age*81+i)*.22,.13)*hit
  end
 end
 if CrystalImpactView.reducedMotion() then return CLEAR end
 local _,visible=camera:WorldToViewportPoint(self.origin)
 local _,groundVisible=camera:WorldToViewportPoint(self.center)
 local weight=(visible or groundVisible) and (1-unit(facing.Magnitude/77)) or 0
 -- The same two rates that expand the front drive the shove and its long release.
 local pressure=t>=0 and t<FRONT and unit(t/.035)*(1-q)*(.88*math.exp(-7*q)+.12) or 0
 local shove=normal*pressure*weight*1.75
 local jitter=Vector3.new(math.sin(t*99)*.26,math.cos(t*76)*.31,0)*pressure*weight
 contacts=contacts.Magnitude>.40 and contacts.Unit*.40 or contacts
 return CFrame.new(camera.CFrame:VectorToObjectSpace(shove)+jitter+contacts)
end
function Preview:destroy()
 if not self.root then return end
 self.root:Destroy();self.root=nil;self.cycle=nil;self.t=nil
end
return Preview
