-- Execute after mock-roblox, energy-effects.setup and production modules
-- Mining/Feedback/SentryMotion/WorkEffects/Presentation.
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS energy effects '..name) end
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local root=Instance.new('Folder');root.Parent=workspace
local camera=Instance.new('Camera');camera.CFrame=CFrame.new(0,20,0);workspace.CurrentCamera=camera
check('moving monochrome transparency stays ordered and bounded at every frame rate',function()
 for _,fps in ipairs({30,60,144}) do for frame=0,fps*2 do
  local sequence=WorkEffects.orbitalTransparency(frame/fps)
  assert(#sequence>=13 and #sequence<=15 and sequence[1].Time==0 and sequence[#sequence].Time==1)
  for i,key in ipairs(sequence) do
   assert(key.Value>=0 and key.Value<=1)
   if i>1 then assert(key.Time>sequence[i-1].Time,'duplicate or unordered ramp key') end
  end
 end end
 local first=WorkEffects.orbitalTransparency(0);local moved=WorkEffects.orbitalTransparency(.025)
 assert(math.abs(first[2].Time-moved[2].Time)>.001,'ramp did not move')
end)
check('break energy uses round glowing discs and bounded burst cleanup',function()
 local work=WorkEffects.new(root)
 for n=1,30 do work:burst(Vector3.zero,Vector3.yAxis,Color3.new(1,1,0),38,100) end
 assert(#work.bursts==work.maxBursts)
 local emitter=work.bursts[1].part:FindFirstChildWhichIsA('ParticleEmitter')
 assert(emitter.Texture=='rbxasset://textures/ui/VR/circleWhite.png' and emitter.LightEmission>=.5 and emitter.LightEmission<1)
 assert(emitter.Brightness>=1 and emitter.Brightness<=2,'common burst became an overbright white mass')
 assert(emitter.TimeScale==1 and emitter.FlipbookLayout==Enum.ParticleFlipbookLayout.None and not emitter.LockedToPart)
 assert(emitter.Size[2].Value-emitter.Size[2].Envelope>=.7 and emitter.Size[2].Value+emitter.Size[2].Envelope<=1.2)
 assert(emitter.Emitted==38 and emitter.Rate==0 and emitter.Lifetime.Min>=1 and emitter.Lifetime.Max==1.6)
 assert(emitter.Speed.Max<=5 and emitter.Drag>=1.8,'break particles spread too far')
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
 assert(impact.Size[2].Value-impact.Size[2].Envelope>=.5 and impact.Size[2].Value+impact.Size[2].Envelope<=.85+.000001)
 assert(impact.Brightness>=1 and impact.Brightness<=2 and impact.LightInfluence==0 and impact.LightEmission>=.5 and impact.LightEmission<1)
 assert(#beam.work.spheres==3 and beam.work.spheres[1].part.Transparency>=.5)
 local coreColor=beam.work.spheres[1].part.Color
 assert((coreColor.B or coreColor.Z)<.6,'sphere core lost its actual job color')
 assert(beam.work.sparks.Brightness<=1 and beam.work.glow.Brightness<=1,'origin stacks overpower the body')
 assert(beam.work.contact.Transparency>=.6 and beam.work.inner.Transparency>=.4,'contact balls form an opaque white lump')
 assert(impact.Lifetime.Min==.85 and impact.Lifetime.Max==1.35 and impact.Rate<=24)
 assert(impact.Speed.Min==2 and impact.Speed.Max<=4 and impact.Drag>=2.4,'ordinary particles travel too far')
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
 DroneRoleEffects.Grow(Vector3.new(0,8,0),Vector3.zero,true)
 local source=assert(workspace:FindFirstChild('DroneRoleServerEffects'))
 local grow=assert(source:FindFirstChild('CrystalSeedBloom'))
 local dust=grow:FindFirstChildWhichIsA('ParticleEmitter',true)
 assert(dust.Lifetime.Max==1.6 and dust.Speed.Max<=1.5 and grow.EnergyCleanup>dust.Lifetime.Max)
 DroneRoleEffects.BreakerPhase(Vector3.new(0,5,0),Vector3.zero,'Impact')
 local shock=assert(source:FindFirstChild('BreakerPressureWave'))
 local sparks=shock:FindFirstChildWhichIsA('ParticleEmitter',true)
 assert(sparks.Lifetime.Min==1 and sparks.Lifetime.Max==1.6 and sparks.Speed.Max<=5 and shock.EnergyCleanup>sparks.Lifetime.Max)
 DroneRoleEffects.Ability(991,{kind='orbital',target={x=0,y=2,z=0}},nil)
 local group=assert(source:FindFirstChild('OrbitalMelt'));local tick=delayedEnergy[#delayedEnergy]
 assert(group.EnergyCleanup==nil,'creation timer can truncate a later final tail')
 for _,emitter in ipairs(group:GetDescendants()) do if emitter:IsA('ParticleEmitter') then
  assert(emitter.Lifetime.Min==2 and emitter.Lifetime.Max<=3.5 and emitter.Speed.Max<=5 and emitter.Rate<=18)
 end end
 realTime=tick.at-.5;group:SetAttribute('ContactAt',realTime);realTime=tick.at;tick.fn()
 assert(group:GetAttribute('EndedAt')==nil and delayedEnergy[#delayedEnergy].at>realTime,'fresh strike expired')
 DroneRoleEffects.Ability(991,{kind='orbitalEnd'},nil)
 assert(group.EnergyCleanup>=4.4)
 local afterglow=0
 for _,emitter in ipairs(group:GetDescendants()) do if emitter:IsA('ParticleEmitter') then
  if emitter.Name=='OrbitalAfterglow' then afterglow+=1;assert(emitter.Lifetime.Max==4 and emitter.Emitted==2) end
  assert(group.EnergyCleanup>emitter.Lifetime.Max)
 end end
 assert(afterglow==12)
 source:Destroy()
 DroneRoleEffects.Ability(992,{kind='orbital',target={x=0,y=2,z=0}},nil)
 source=workspace:FindFirstChild('DroneRoleServerEffects');group=source:FindFirstChild('OrbitalMelt');tick=delayedEnergy[#delayedEnergy]
 realTime=tick.at;tick.fn();assert(group:GetAttribute('EndedAt') and group.EnergyCleanup>=4.4)
 for _,emitter in ipairs(group:GetDescendants()) do if emitter:IsA('ParticleEmitter') then assert(not emitter.Enabled) end end
 source:Destroy()
end)
check('orbital extends above high camera and collapses on authoritative end',function()
 local source=Instance.new('Folder');source.Name='DroneRoleServerEffects';source.Parent=workspace
 local group=Instance.new('Folder');group:SetAttribute('OrbitalBurn',true);group:SetAttribute('Position',Vector3.zero);group.Parent=source
 local core=Instance.new('Part');core.Name='MeltCore';core.LocalTransparencyModifier=.2;core.Parent=group
 local work=WorkEffects.new(root);camera.CFrame=CFrame.new(0,400,0);work:update(10)
 local fx=assert(work.orbitals[group]);assert(fx.top.Position.Y>=580)
 assert(core.LocalTransparencyModifier==1,'solid source washed out the clear ramp gaps')
 camera.CFrame=CFrame.new(0,400,0);work:update(10.1);assert(fx.top.Position.Y>=580)
 assert(fx.ramp.Color.R==1 and fx.ramp.Color.G==1 and fx.ramp.Color.B==1)
 group:SetAttribute('ContactAt',9);work:update(10.1);assert(not fx.ramp.Enabled,'stale strike kept drilling')
 core.LocalTransparencyModifier=0
 group:SetAttribute('ContactAt',10.1);work:update(10.1);assert(fx.ramp.Enabled,'fresh contact failed to resume')
 assert(core.LocalTransparencyModifier==1,'resume restored a solid column over the clear gaps')
 group:SetAttribute('EndedAt',10.1);work:update(10.34);assert(fx.ramp.Width0<.5)
 work:update(10.7);assert(work.orbitals[group]==nil and fx.holder.Parent==nil)
 assert(core.LocalTransparencyModifier==.2,'source visibility was not restored after collapse')
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
check('real fracture creates authored mesh chunks and honors pool limit',function()
 local source=Instance.new('UnionOperation');source:SetAttribute('FullSize',Vector3.one*4);source.Parent=workspace
 local view=source:Clone();view.Size=Vector3.one;view.Position=Vector3.new(0,2,0);view.Parent=root
 local renderer=Presentation.new({parent=root});renderer._floor=function() return 0 end
 local resource={source=source,view=view,baseColor=Color3.new(.5,.7,1)}
 renderer:resourceImpact(resource,'stage',100);assert(#renderer.fragments==3)
 renderer:resourceImpact(resource,'break',100.5);assert(#renderer.fragments==12)
 for _,fragment in ipairs(renderer.fragments) do
  assert(fragment.part:IsA('UnionOperation'),'lost original rock geometry')
  assert(fragment.velocity.Y>0 and fragment.duration>=.75 and not fragment.part.CanQuery)
 end
 for n=1,10 do renderer:resourceImpact(resource,'break',101+n*.1) end
 assert(#renderer.fragments==renderer.maxFragments)
 renderer:update(1,110);assert(#renderer.fragments==0);renderer:destroy();source:Destroy()
end)
root:Destroy();camera:Destroy()
print(checks..' production energy/fragment behavior checks with API doubles; Studio appearance remains separate')
