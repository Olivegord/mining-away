-- Execute after mock-roblox, energy-effects.setup and production modules
-- Mining/Feedback/SentryMotion/WorkEffects/Presentation.
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS energy effects '..name) end
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local function round(emitter,min,max)
 assert(emitter.Texture=='rbxasset://textures/ui/VR/circleWhite.png')
 assert(emitter.Orientation==Enum.ParticleOrientation.FacingCamera and not emitter.WindAffectsDrag and not emitter.LockedToPart)
 assert(emitter.Size[2].Value>=min and emitter.Size[2].Value+emitter.Size[2].Envelope<=max)
 assert(emitter.Transparency[2].Value>=.4 and emitter.Transparency[#emitter.Transparency].Value==1)
end
local root=Instance.new('Folder');root.Parent=workspace
local camera=Instance.new('Camera');camera.CFrame=CFrame.new(0,20,0);workspace.CurrentCamera=camera
check('moving monochrome transparency stays ordered and bounded at every frame rate',function()
 for _,fps in ipairs({30,60,144}) do for frame=0,fps*2 do
  local sequence=WorkEffects.orbitalTransparency(frame/fps)
  assert(#sequence>=9 and #sequence<=10 and sequence[1].Time==0 and sequence[#sequence].Time==1)
  for i,key in ipairs(sequence) do
   assert(key.Value>=0 and key.Value<=1)
   if i>1 then assert(key.Time>sequence[i-1].Time,'duplicate or unordered ramp key') end
  end
 end end
 local first=WorkEffects.orbitalTransparency(0);local moved=WorkEffects.orbitalTransparency(.025)
 assert(math.abs(first[2].Time-moved[2].Time)>.001,'ramp did not move')
end)
check('large translucent utility discs preserve bounded burst cleanup',function()
 local work=WorkEffects.new(root)
 for n=1,30 do work:burst(Vector3.zero,Vector3.yAxis,Color3.new(1,1,0),38,100) end
 assert(#work.bursts==work.maxBursts)
 local emitter=work.bursts[1].part:FindFirstChildWhichIsA('ParticleEmitter')
 round(emitter,.8,1.2)
 assert(emitter.LightEmission<.5)
 assert(emitter.Brightness>=1 and emitter.Brightness<=2,'common burst became an overbright white mass')
 assert(emitter.TimeScale==1 and emitter.FlipbookLayout==Enum.ParticleFlipbookLayout.None and not emitter.LockedToPart)
 assert(emitter.Emitted<=12 and emitter.Rate==0 and not emitter.Enabled and emitter.Lifetime.Max<=1.6)
 assert(emitter.Speed.Max<=12 and emitter.Drag>=6,'break particles spread too far')
 assert(work.bursts[1].untilAt>=100+emitter.Lifetime.Max)
 local bloom=game:GetService('Lighting'):FindFirstChild('MiningEnergyBloom')
 assert(bloom and bloom.Enabled and bloom.Intensity>0 and bloom.Intensity<=.6 and bloom.Size<=22 and bloom.Threshold>=1.2)
 work:update(101.5);assert(#work.bursts==work.maxBursts,'burst parent clipped a living tail')
 work:update(101.9);assert(#work.bursts==0);work:destroy();assert(bloom.Parent==nil)
end)
check('existing named bloom is retuned without stacking or deleting unrelated lighting',function()
 local lighting=game:GetService('Lighting');local bloom=Instance.new('BloomEffect');bloom.Name='MiningEnergyBloom'
 bloom.Intensity=1.25;bloom.Enabled=false;bloom.Parent=lighting
 local unrelated=Instance.new('BloomEffect');unrelated.Name='PreservedOtherBloom';unrelated.Intensity=.1;unrelated.Parent=lighting
 local work=WorkEffects.new(root);work:energyBloom()
 assert(work.bloom==bloom and bloom.Enabled and bloom.Intensity<=.6)
 local count=0;for _,effect in ipairs(lighting:GetChildren()) do if effect.Name=='MiningEnergyBloom' then count+=1 end end
 assert(count==1 and unrelated.Intensity==.1)
 work:destroy();assert(bloom.Parent==lighting and unrelated.Parent==lighting)
 bloom:Destroy();unrelated:Destroy()
end)
check('nearby owner sees fresh full-speed mining discs while zoomed far out',function()
 local oldPlayer=players.LocalPlayer;local player=Instance.new('Player');local character=Instance.new('Model')
 local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Position=Vector3.zero;body.Parent=character;player.Character=character
 players.LocalPlayer=player;camera.CFrame=CFrame.new(0,400,0)
 local templates=Instance.new('Folder');templates.Name='MiningFX';templates.Parent=rs
 local particles=Instance.new('Folder');particles.Name='MiningParticles';particles.Parent=templates
 local source=Instance.new('ParticleEmitter');source.Name='Largeparticles';source.TimeScale=.2;source.FlipbookLayout='badInheritedFlipbook';source.Parent=particles
 local contact=Instance.new('Part');contact.Name='MiningEffect';contact.Parent=templates
 local inner=Instance.new('Part');inner.Name='InnerMiningEffect';inner.Parent=contact
 local work=WorkEffects.new(root);local holder=Instance.new('Folder');holder.Parent=root
 local marker=Instance.new('Part');marker.Parent=holder
 local beam={holder=holder,marker=marker,origin={WorldPosition=Vector3.new(0,5,0)},tint=Color3.new(1,.8,.2)}
 local sample={alive=true,isMining=true,active=true,paused=false,warmupStart=0,key='rock',life=1,style='Cutter',pulseSerial=0}
 work:mining(beam,sample,Vector3.zero,Vector3.yAxis,1,0,100)
 local impact=assert(beam.work and beam.work.impact,'zoom swallowed nearby work effects')
 assert(impact.Enabled and impact.TimeScale==1 and impact.FlipbookLayout==Enum.ParticleFlipbookLayout.None)
 round(impact,.8,1.45)
 assert(impact.Acceleration.X==0 and impact.Acceleration.Z==0)
 assert(impact.Brightness>=1 and impact.Brightness<=2 and impact.LightInfluence==0 and impact.LightEmission<.5)
 assert(#beam.work.spheres==3 and beam.work.spheres[1].part.Transparency>=.5)
 local coreColor=beam.work.spheres[1].part.Color
 assert((coreColor.B or coreColor.Z)<.6,'sphere core lost its actual job color')
 assert(beam.work.sparks.Brightness<=1 and beam.work.glow.Brightness<=1,'origin stacks overpower the body')
 assert(beam.work.contact.Transparency>=.6 and beam.work.inner.Transparency>=.4,'contact balls form an opaque white lump')
 assert(impact.Lifetime.Max<=1 and impact.Rate<=6)
 assert(impact.Speed.Max<=12 and impact.Drag>=4,'ordinary particles travel too far')
 impact.Cleared=false;sample.key='next-rock'
 work:mining(beam,sample,Vector3.new(3,0,0),Vector3.yAxis,1,0,100.1)
 assert(not impact.Cleared,'target switch destroyed the previous world-space tail')
 sample.active=false;work:mining(beam,sample,nil,nil,0,0,101.4)
 assert(beam.work and not impact.Enabled,'inactive rig clipped the long tail or kept emitting')
 work:mining(beam,sample,nil,nil,0,0,102);assert(not beam.work and impact.Parent==nil)
 assert(source.TimeScale==.2 and source.FlipbookLayout=='badInheritedFlipbook','preserved template was overwritten')
 work:destroy();holder:Destroy();templates:Destroy();character:Destroy();player:Destroy();players.LocalPlayer=oldPlayer;camera.CFrame=CFrame.new(0,20,0)
end)
check('role burst and orbital cleanup retain their longest particle lifetimes',function()
 RoleVisuals.Grow(Vector3.new(0,8,0),Vector3.zero,true)
 local source=assert(workspace:FindFirstChild('DroneRoleClientEffects'))
 local grow=assert(source:FindFirstChild('CrystalSeedBloom'))
 local dust=grow:FindFirstChildWhichIsA('ParticleEmitter',true)
 round(dust,.75,1.2)
 assert(dust.Lifetime.Max==1.6 and dust.Speed.Max<=5 and dust.Drag>=8 and grow.EnergyCleanup>dust.Lifetime.Max)
 RoleVisuals.BreakerPhase(Vector3.new(0,5,0),Vector3.zero,'Impact')
 local shock=assert(source:FindFirstChild('BreakerPressureWave'))
 local sparks=shock:FindFirstChildWhichIsA('ParticleEmitter',true)
 round(sparks,1,1.5)
 assert(sparks.Lifetime.Min==1 and sparks.Lifetime.Max==1.6 and sparks.Speed.Max==11 and sparks.Drag>=7 and shock.EnergyCleanup>sparks.Lifetime.Max)
 RoleVisuals.Ability(991,{kind='orbital',target={x=0,y=2,z=0}},nil)
 local group=assert(source:FindFirstChild('OrbitalMelt'));local tick=delayedEnergy[#delayedEnergy]
 assert(group.EnergyCleanup==nil,'creation timer can truncate a later final tail')
 local active=assert(group:FindFirstChildWhichIsA('ParticleEmitter',true))
 round(active,1,2.8)
 assert(active.Name=='MoltenSparks' and active.Rate<=8 and active.Lifetime.Max<=1.4)
 realTime=tick.at-.5;group:SetAttribute('ContactAt',realTime);realTime=tick.at;tick.fn()
 assert(group:GetAttribute('EndedAt')==nil and delayedEnergy[#delayedEnergy].at>realTime,'fresh strike expired')
 RoleVisuals.Ability(991,{kind='orbitalEnd'},nil)
 assert(group.EnergyCleanup>=4.4)
 local afterglow=0
 for _,emitter in ipairs(group:GetDescendants()) do if emitter:IsA('ParticleEmitter') then
  assert(not emitter.WindAffectsDrag and emitter.Acceleration.X==0 and emitter.Acceleration.Z==0,'shared wind in orbital cloud')
  if emitter.Name=='OrbitalAfterglow' then
   afterglow+=1;assert(emitter.Lifetime.Max==4 and emitter.Emitted>=18 and emitter.Emitted<=30)
   round(emitter,1.3,2)
   assert(emitter.Shape==Enum.ParticleEmitterShape.Cylinder and emitter.ShapeStyle==Enum.ParticleEmitterShapeStyle.Volume)
   assert(emitter.Parent:IsA('BasePart') and emitter.Parent.Size.X==26 and emitter.Parent.Size.Y==emitter.Parent.Size.Z)
   assert(emitter.Parent.EnergyTween==nil,'afterglow carrier collapses before its particles finish')
   assert(emitter.Rate==0 and not emitter.Enabled and emitter.Speed.Max<=2.5)
  end
  assert(group.EnergyCleanup>emitter.Lifetime.Max)
 end end
 assert(afterglow==1)
 source:Destroy()
 RoleVisuals.Ability(992,{kind='orbital',target={x=0,y=2,z=0}},nil)
 source=workspace:FindFirstChild('DroneRoleClientEffects');group=source:FindFirstChild('OrbitalMelt');tick=delayedEnergy[#delayedEnergy]
 realTime=tick.at;tick.fn();assert(group:GetAttribute('EndedAt') and group.EnergyCleanup>=4.4)
 for _,emitter in ipairs(group:GetDescendants()) do if emitter:IsA('ParticleEmitter') then assert(not emitter.Enabled) end end
 source:Destroy()
end)
check('orbital extends above high camera and collapses on authoritative end',function()
 local source=Instance.new('Folder');source.Name='DroneRoleClientEffects';source.Parent=workspace
 local group=Instance.new('Folder');group:SetAttribute('OrbitalBurn',true);group:SetAttribute('Position',Vector3.zero);group.Parent=source
 local core=Instance.new('Part');core.Name='MeltCore';core.LocalTransparencyModifier=.2;core.Parent=group
 local work=WorkEffects.new(root);camera.CFrame=CFrame.new(0,400,0);work:update(10)
 local fx=assert(work.orbitals[group]);assert(fx.top.Position.Y>=580)
 assert(core.LocalTransparencyModifier==.2,'physical cylinder was hidden by the ramp');assert(fx.ramp.Width0==.72)
 camera.CFrame=CFrame.new(0,400,0);work:update(10.1);assert(fx.top.Position.Y>=580)
 assert(fx.ramp.Color.R==1 and fx.ramp.Color.G==1 and fx.ramp.Color.B==1)
 group:SetAttribute('ContactAt',9);work:update(10.1);assert(not fx.ramp.Enabled,'stale strike kept drilling')
 core.LocalTransparencyModifier=0
 group:SetAttribute('ContactAt',10.1);work:update(10.1);assert(fx.ramp.Enabled,'fresh contact failed to resume')
 assert(core.LocalTransparencyModifier==0,'resume hid the physical cylinder')
 group:SetAttribute('EndedAt',10.1);work:update(10.34);assert(fx.ramp.Width0<1)
 work:update(10.7);assert(work.orbitals[group]==nil and fx.holder.Parent==nil)
 assert(core.LocalTransparencyModifier==0,'ramp cleanup changed physical source visibility')
 work:destroy();source:Destroy();camera.CFrame=CFrame.new(0,20,0)
end)
check('nearby character feels the impact at far camera zoom and reduced motion opts out',function()
 local renderer=Presentation.new({parent=root});local oldPlayer=players.LocalPlayer
 local player=Instance.new('Player');local character=Instance.new('Model')
 local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Position=Vector3.new(0,3,0);body.Parent=character;player.Character=character
 players.LocalPlayer=player;camera.CFrame=CFrame.new(0,400,0)
 renderer:kick(Vector3.zero,.09,100);assert(renderer.shakeStrength>.07,'camera zoom swallowed nearby impact')
 local before=renderer.shakeStrength;player:SetAttribute('ReducedMotion',true)
 renderer:kick(Vector3.zero,.14,100.01);assert(renderer.shakeStrength==before)
 renderer:destroy();players.LocalPlayer=oldPlayer;character:Destroy();player:Destroy();camera.CFrame=CFrame.new(0,20,0)
end)
check('ordinary camera beats stay level, local and bounded even in a volley',function()
 local renderer=Presentation.new({parent=root})
 local position=camera.CFrame.Position+Vector3.new(5,0,0)
 renderer:cameraBeat('NeedleFire',position,100)
 local small=renderer:cameraOffset(100.016).Position.Magnitude
 assert(small>.006 and small<.025)
 for _=1,30 do renderer:cameraBeat('BallHit',position,101) end
 renderer:cameraBeat('Split',position,101,1.35)
 assert(#renderer.cameraBeats==10 and renderer.cameraBeats[10].duration==.23)
 for i=0,30 do
  local offset=renderer:cameraOffset(101+i/144)
  assert(offset.yaw==0 and offset.Position.Magnitude<=.13501)
 end
 assert(renderer:cameraOffset(101.24).Position.Magnitude==0 and #renderer.cameraBeats==0)
 renderer:cameraBeat('Split',position+Vector3.xAxis*75,102)
 assert(renderer:cameraOffset(102.04).Position.Magnitude==0)
 local old=players.LocalPlayer
 local player=Instance.new('Player');players.LocalPlayer=player
 player:SetAttribute('ReducedMotion',true)
 renderer:cameraBeat('BallFire',position,103)
 assert(#renderer.cameraBeats==0)
 players.LocalPlayer=old;player:Destroy();renderer:destroy()
end)
check('Prism fires a brief level tremor and a much stronger rock blast',function()
 local renderer=Presentation.new({parent=root})
 local from,to=Vector3.new(-25,20,0),Vector3.new(25,20,0)
 renderer:prismChargePressure(from,to,.8,99.93)
 local charge=renderer:cameraOffset(99.95)
 assert(charge.Position.Magnitude>.012 and charge.Position.Magnitude<.062 and charge.yaw==0)
 renderer:prismPressure(from,to,100,.42)
 assert(not renderer.prismChargeShake,'the charge shake overlapped the firing beat')
 for _,time in ipairs({100.08,100.17,100.24}) do
  local offset=renderer:cameraOffset(time)
  assert(offset.Position.Magnitude>.025 and offset.Position.Magnitude<.19 and offset.yaw==0)
 end
 local crossings,previous=0,0
 for i=0,36 do
  local x=renderer:cameraOffset(100.04+i/120).Position.X
  if x*previous<0 then crossings+=1 end
  previous=x
 end
 assert(crossings>=7,'Prism camera motion lost the fast firing tremor')
 assert(renderer:cameraOffset(100.43).Position.Magnitude==0)
 renderer:crystalKick(Vector3.new(0,20,0),2,100.50,true)
 local peak=0
 for i=1,55 do
  local offset=renderer:cameraOffset(100.50+i/120)
  assert(offset.yaw==0,'the blast tilted the camera')
  peak=math.max(peak,offset.Position.Magnitude)
 end
 assert(peak>.48 and renderer:cameraOffset(100.97).Position.Magnitude==0,
  'the rock blast lacked a strong, finite camera impulse')
 renderer:destroy()
end)
check('Prism is visible at contact and fades immediately before leaving char',function()
 RoleVisuals.setTime(realTime)
 local from,to=Vector3.new(0,20,0),Vector3.new(0,0,-36)
 RoleVisuals.Beam(from,to,Color3.new(1,.08,.12),1.52,.42,'Prism',Vector3.yAxis)
 local at=realTime
 local group=assert(workspace:FindFirstChild('DroneRoleClientEffects'))
 local impact=assert(group:FindFirstChild('PrismImpactLight',true))
 local lamp=assert(impact:FindFirstChildOfClass('PointLight'))
 local sparks=assert(impact:FindFirstChildOfClass('ParticleEmitter'))
 local scorch=assert(group:FindFirstChild('PrismScorch'))
 local char=assert(scorch:FindFirstChild('CharredGround'))
 assert(not group:FindFirstChild('PrismHeat',true) and impact.Transparency==1 and char.Transparency==1)
 local beamRoot=impact.Parent
 local main=beamRoot:FindFirstChild('TaperedBody')
 RoleVisuals.step(at)
 local core=beamRoot:FindFirstChild('NeedleCore')
 local corona=beamRoot:FindFirstChild('PrismCorona')
 assert(main.Enabled and main.Width0>.64 and main.Width1>.50,'Prism lost width across its path')
 assert(core.Width0>.19 and core.Brightness>=2 and corona.Width0>3,'Prism lost the bright core or outer glow')
 assert(lamp.Enabled and lamp.Brightness>2 and sparks.Enabled and sparks.Rate>18)
 local first=main.Transparency[2].Value
 RoleVisuals.step(at+.05)
 local nextAlpha=main.Transparency[2].Value
 assert(nextAlpha>first+.10,'the red beam held its full opacity after release')
 RoleVisuals.step(at+.25)
 assert(main.Transparency[2].Value>nextAlpha and lamp.Brightness<2 and sparks.Rate<18)
 RoleVisuals.step(at+.43)
 assert(not beamRoot.Parent and not impact.Parent and scorch.Parent,'the beam or contact effects lingered into the pause')
 assert(char.Transparency<.61 and not char.CanCollide and not char.CanQuery)
 RoleVisuals.step(at+17.1)
 assert(not scorch.Parent,'ground mark leaked after cooling')
 RoleVisuals.setTime(nil)
 RoleVisuals.destroy()
end)
check('Heavy impact slabs appear at full opacity and stay planted until they sink',function()
 local map=Instance.new('Folder');map.Name='MiningAway';map.Parent=workspace
 local scenery=Instance.new('Folder');scenery.Name='Map';scenery.Parent=map
 local bed=Instance.new('Part');bed.Material=Enum.Material.Slate;bed.Parent=scenery
 local savedRaycast=workspace.Raycast
 function workspace:Raycast(from)
  return {Position=Vector3.new(from.X,0,from.Z),Normal=Vector3.yAxis,Instance=bed,Material=bed.Material}
 end
 local fromMatrix=CFrame.fromMatrix
 function CFrame.fromMatrix(position,right,up,back)
  return fromMatrix(position,right,up,back or right:Cross(up))
 end
 CF.__sub=function(frame,offset) return CFrame.new(frame.Position-offset)*frame.Rotation end
 assert(ImpactRubble.spawn(root,Vector3.zero,11,'Prism',200,200))
 local ring=assert(root:FindFirstChild('PrismCrater'))
 local poses={}
 for _,slab in ipairs(ring:GetChildren()) do
  if slab.Name=='BrokenSlab' then
   assert(slab.Transparency==0 and not slab.CanCollide)
   poses[slab]=slab.CFrame
  end
 end
 assert(next(poses),'the ring contained no slabs')
 ImpactRubble.step(200.25)
 for slab,frame in pairs(poses) do assert(slab.CFrame==frame and slab.Transparency==0) end
 ImpactRubble.step(203.2)
 for slab,frame in pairs(poses) do
  assert(slab.CFrame.Position.Y<frame.Position.Y and slab.Transparency>0)
 end
 ImpactRubble.step(204.66)
 assert(not ring.Parent,'the ring survived its cleanup deadline')
 workspace.Raycast=savedRaycast;CFrame.fromMatrix=fromMatrix;CF.__sub=nil
 map:Destroy()
end)
root:Destroy();camera:Destroy()
print(checks..' production energy/fragment behavior checks with API doubles; Studio appearance remains separate')
