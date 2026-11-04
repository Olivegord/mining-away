--!strict
-- Client-only role visuals. The server publishes compact effect descriptions.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}
local animations={}
local beamTimelines={}
local chargeTimelines={}
local eventAt=nil
local function clock() return eventAt or workspace:GetServerTimeNow() end
function Effects.setTime(at) eventAt=at end
local function animate(value,duration,style,direction,properties)
 local initial={};for key in pairs(properties) do initial[key]=value[key] end
 animations[value]={at=clock(),duration=duration,style=style,direction=direction,initial=initial,goal=properties}
end
function Effects.step(now)
 for rig,t in pairs(beamTimelines) do
  local age=now-t.at
  if not rig.root.Parent or age>t.duration+rig.profile.tail then
   BeamVFX.destroy(rig);beamTimelines[rig]=nil
  elseif age<0 then BeamVFX.hide(rig)
  elseif age<t.duration then
   local expansion=math.min(1,age/.035)
   local collapse=1-math.clamp((age/t.duration-.62)/.38,0,1)
   BeamVFX.draw(rig,t.from,t.to,now,expansion*collapse,nil,age,t.scale)
  else BeamVFX.after(rig,t.from,t.to,now,age-t.duration,t.scale) end
 end
 for group,t in pairs(chargeTimelines) do
  if not group.Parent then BeamVFX.destroy(t.rig);chargeTimelines[group]=nil
  else
   local q=math.clamp((now-t.at)/t.duration,0,1)
   BeamVFX.draw(t.rig,t.position,t.position-Vector3.yAxis,now,0,q,nil)
  end
 end
 for value,animation in pairs(animations) do
  if not value.Parent then animations[value]=nil
  else
   local t=math.clamp((now-animation.at)/animation.duration,0,1)
   local alpha=TweenService:GetValue(t,animation.style,animation.direction)
   for key,goal in pairs(animation.goal) do
    local first=animation.initial[key]
    value[key]=type(goal)=='number' and first+(goal-first)*alpha or first:Lerp(goal,alpha)
   end
   if t>=1 then animations[value]=nil end
  end
 end
end
local MAX_LIVE = 256
local live = 0
local ENERGY='rbxasset://textures/ui/VR/circleWhite.png'
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local ORBITAL_HEIGHT=260
local ORBITAL_COLOR=Color3.new(1,1,1)
local ORBITAL_TAIL=4.4

local function folder(): Folder
	local existing = workspace:FindFirstChild("DroneRoleClientEffects")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "DroneRoleClientEffects"
	created.Parent = workspace
	return created
end

local function part(): Part?
	if live >= MAX_LIVE then
		return nil
	end
	local value = Instance.new("Part")
	value.Name = "RoleEffect"
	value.Anchored = true
	value.CanCollide = false
	value.CanQuery = false
	value.CanTouch = false
	value.CastShadow = false
	value.Material = Enum.Material.Neon
	value.Parent = folder()
	live += 1
	local counted = true
	value.Destroying:Connect(function()
		if counted then
			counted = false
			live -= 1
		end
	end)
	return value
end

function Effects.Beam(from: Vector3, to: Vector3, color: Color3, width: number?, lifetime: number?, style: string?)
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return
	end
	local duration = lifetime or 0.16
	local thickness = width or 0.18
	local at=clock();local now=workspace:GetServerTimeNow()
	local profile=BeamVFX.styles[style or 'Lance'] or BeamVFX.styles.Lance
	if now-at>duration+profile.tail then return end
	local rig=BeamVFX.new(folder(),style or 'Lance',color)
	if rig then
	 beamTimelines[rig]={at=at,duration=duration,from=from,to=to,scale=thickness/profile.body}
	elseif now-at<duration then
	 -- Saturated cosmetic budget retains a simple readable shot.
	 local value=part();if not value then return end
	 value.Color=color;value.Size=Vector3.new(thickness*.35,thickness*.35,delta.Magnitude)
	 value.CFrame=CFrame.lookAt(from:Lerp(to,.5),to);value.Transparency=.45
	 animate(value,math.max(.01,duration-(now-at)),Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Transparency=1})
	 Debris:AddItem(value,math.max(.01,duration-(now-at))+.05)
	end
end

function Effects.Pulse(position: Vector3, color: Color3, startSize: number?, endSize: number?, lifetime: number?)
	local value = part()
	if not value then
		return
	end
	local duration = lifetime or 0.3
	local first = startSize or 0.8
	local last = endSize or 5
	value.Shape = Enum.PartType.Ball
	value.Color = color
	-- Keep the event readable without an opaque neon sphere washing out its rock.
	value.Transparency = 0.42
	value.Size = Vector3.one * first
	value.Position = position
	animate(value,duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{
		Transparency = 1,
		Size = Vector3.one * last,
	})
	Debris:AddItem(value, duration + 0.05)
end

function Effects.Heal(from: Vector3, to: Vector3)
	local color = Color3.fromRGB(99, 255, 164)
	Effects.Beam(from, to, color, 0.14, 0.2,'Repair')
	Effects.Pulse(to, color, 0.5, 2.5, 0.24)
end

function Effects.Charge(position: Vector3, target: Vector3, impact: boolean?)
	local color = Color3.fromRGB(255, 137, 70)
	if impact then
		Effects.Beam(position, target, color, 0.3, 0.2,'Combat')
		Effects.Pulse(target, color, .7, 4.2, 0.28)
	else
		Effects.Pulse(position, Color3.fromRGB(255, 218, 105), 0.5, 3.4, 0.8)
	end
end

-- Seeding dust falls from the actual grower; the bloom confirms a real spawn.
function Effects.Grow(from: Vector3,target: Vector3,planted: boolean)
 local green=Color3.fromRGB(152,231,158)
 local value=part();if not value then return end
 value.Name=planted and 'CrystalSeedBloom' or 'CrystalSeedFall';value.Transparency=1
 if planted then value:SetAttribute('AudioCue','plant');value:SetAttribute('AudioAt',clock()) end
 value.Position=planted and target or from
 local tip=Instance.new('Attachment');tip.Parent=value
 local dust=Instance.new('ParticleEmitter');dust.Texture=SPARK
 dust.Rate=0;dust.Color=ColorSequence.new(green);dust.LightEmission=1;dust.Brightness=.95;dust.LightInfluence=0
 dust.Lifetime=NumberRange.new(1,1.6);dust.Speed=NumberRange.new(.5,1.5)
 dust.EmissionDirection=planted and Enum.NormalId.Top or Enum.NormalId.Bottom;dust.SpreadAngle=Vector2.new(22,22)
 dust.Acceleration=Vector3.new(0,planted and .1 or -.3,0);dust.Drag=1.8;dust.WindAffectsDrag=false
 dust.Rotation=NumberRange.new(-180,180);dust.RotSpeed=NumberRange.new(-65,65)
 dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.14,.02),NumberSequenceKeypoint.new(.2,.24,.03),NumberSequenceKeypoint.new(1,0)})
 dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.45,.55),NumberSequenceKeypoint.new(1,1)})
 dust.Parent=tip;dust:Emit(planted and 14 or 9);Debris:AddItem(value,1.8)
 if planted then Effects.Pulse(target+Vector3.new(0,.25,0),green,.2,1.6,.45) end
end

-- These are one-shot phase cues. The authoritative drone moves through its
-- windup/dive/recovery; none of these effects is a steady mining beam.
function Effects.BreakerPhase(position: Vector3,target: Vector3,phase: string)
 local amber=Color3.fromRGB(220,164,81)
 if phase=='Windup' then
  Effects.Pulse(target,amber,.2,1.4,.75)
 elseif phase=='Dive' then
  Effects.Pulse(target,Color3.fromRGB(239,211,154),1.1,.25,.25)
 elseif phase=='Impact' then
  local cue=part();if cue then cue.Name='ConfirmedMiningImpact';cue.Transparency=1;cue.Position=target;cue:SetAttribute('MiningImpact','Breaker');cue:SetAttribute('ImpactAt',clock());Debris:AddItem(cue,1) end
  Effects.Pulse(target,Color3.fromRGB(244,207,142),.35,3.2,.18)
  local shock=part()
  if shock then
   shock.Name='BreakerPressureWave';shock.Shape=Enum.PartType.Cylinder;shock.Color=Color3.fromRGB(221,196,142)
   shock.Transparency=.68;shock.Size=Vector3.new(.055,.6,.6);shock.CFrame=CFrame.new(target)*CFrame.Angles(0,0,math.pi/2)
   local attachment=Instance.new('Attachment');attachment.CFrame=CFrame.Angles(0,0,-math.pi/2);attachment.Parent=shock
   local dust=Instance.new('ParticleEmitter');dust.Name='BreakerDust';dust.Texture=SMOKE
   dust.Color=ColorSequence.new(Color3.fromRGB(118,108,91));dust.LightEmission=0;dust.LightInfluence=.65;dust.Brightness=1
   dust.Rate=0;dust.Lifetime=NumberRange.new(1,1.6)
   dust.Speed=NumberRange.new(.6,1.6);dust.Drag=3;dust.Acceleration=Vector3.new(0,.25,0);dust.WindAffectsDrag=false
   dust.Rotation=NumberRange.new(-180,180);dust.RotSpeed=NumberRange.new(-50,50)
   dust.EmissionDirection=Enum.NormalId.Top;dust.SpreadAngle=Vector2.new(80,80)
   dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.2,.04),NumberSequenceKeypoint.new(.3,.5,.08),NumberSequenceKeypoint.new(1,.75,.1)})
   dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(.3,.45),NumberSequenceKeypoint.new(1,1)});dust.Parent=attachment;dust:Emit(16)
   animate(shock,.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Size=Vector3.new(.055,8,8),Transparency=1})
   Debris:AddItem(shock,1.8)
  end
  -- The actual fracture creates authored crystal fragments in Presentation.
  -- Avoid a second shower of generic weightless balls on the same event.
 elseif phase=='Hold' then
  -- This is physical touchdown, distinct from the later damaging fracture.
  -- A single server receipt drives both the local thud and camera impulse.
  local cue=part();if cue then cue.Name='ConfirmedBreakerContact';cue.Transparency=1;cue.Position=target;cue:SetAttribute('MiningImpact','BreakerContact');cue:SetAttribute('ImpactAt',clock());Debris:AddItem(cue,1) end
  Effects.Pulse(target,Color3.fromRGB(244,211,155),.3,1.8,.12)
  Effects.Pulse(target,Color3.fromRGB(255,206,107),.2,.7,.9)
 elseif phase=='Recover' then
  Effects.Pulse(position,Color3.fromRGB(168,155,123),.15,.7,.2)
 end
end

-- Gadget FX are consequences of the authoritative DroneAbilities state machine.
-- RoleEffectView supplies the replicated intent; no local pose feeds damage.
local swarms: {[any]: Folder} = {}
local markers: {[any]: Instance} = {}
local function clearSwarm(owner: any)
 local old=swarms[owner]
 if old then swarms[owner]=nil;old:Destroy() end
end
local function clearMarker(owner: any)
 local old=markers[owner];markers[owner]=nil
 if old then old:Destroy() end
end
local function location(p: any): Vector3 return Vector3.new(p.x,p.y,p.z) end
local function column(position: Vector3,height: number,width: number,color: Color3,duration: number)
 Effects.Beam(position+Vector3.yAxis*height,position,color,width,duration,'Resonance')
end
local burns: {[any]: Folder} = {}
local function clearBurn(owner: any)
 local old=burns[owner];burns[owner]=nil
 if not old or not old.Parent then return end
 -- Stop work immediately, but let the column collapse into suspended embers.
 -- Every observer evaluates the same authoritative end time locally.
 old:SetAttribute('EndedAt',clock())
 for _,effect in ipairs(old:GetDescendants()) do
  if effect:IsA('ParticleEmitter') then effect.Enabled=false end
 end
 local core=old:FindFirstChild('MeltCore')
 if core and core:IsA('BasePart') then
  -- A full volume leaves a continuous vertical trail, rather than twelve
  -- isolated pairs of dots. Its fixed carrier must not shrink with the laser.
  local trail=part()
  if trail then
   trail.Name='OrbitalResidualColumn';trail.Transparency=1;trail.Shape=Enum.PartType.Cylinder
   trail.Size=Vector3.new(ORBITAL_HEIGHT,2.25,2.25);trail.CFrame=core.CFrame;trail.Parent=old
   local embers=Instance.new('ParticleEmitter');embers.Name='OrbitalAfterglow'
   embers.Texture=ENERGY;embers.Enabled=false;embers.Rate=0;embers.LightEmission=.8;embers.LightInfluence=0;embers.Brightness=1.1
   embers.Color=ColorSequence.new(ORBITAL_COLOR)
   embers.Shape=Enum.ParticleEmitterShape.Cylinder;embers.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
   embers.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward;embers.ShapePartial=1;embers.EmissionDirection=Enum.NormalId.Right
   embers.Lifetime=NumberRange.new(2.5,4);embers.Speed=NumberRange.new(.05,.35);embers.Drag=2.5;embers.WindAffectsDrag=false
   embers.LockedToPart=false;embers.VelocityInheritance=0
   embers.SpreadAngle=Vector2.new(180,180);embers.Rotation=NumberRange.new(-180,180);embers.RotSpeed=NumberRange.new(-45,45)
   embers.Acceleration=Vector3.new(0,.08,0)
   embers.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16,.04),NumberSequenceKeypoint.new(.2,.3,.06),NumberSequenceKeypoint.new(1,0)})
   embers.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(.55,.55),NumberSequenceKeypoint.new(1,1)})
   embers.Parent=trail;embers:Emit(312)
  end
 end
 for _,value in ipairs(old:GetChildren()) do if value:IsA('BasePart') and value.Name~='OrbitalResidualColumn' then
  local size=value.Name=='MeltContact' and Vector3.one*.03 or Vector3.new(value.Size.X,.015,.015)
  animate(value,.48,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Size=size,Transparency=1})
 end end
 Debris:AddItem(old,ORBITAL_TAIL)
end
-- A fixed timer from the strike's creation could cut off its last motes after
-- a storage pause. One watchdog per live group instead begins cleanup only
-- after contacts stop, then preserves a full final particle lifetime.
local function watchBurn(owner: any,group: Folder)
 task.delay(8,function()
  if not group.Parent or group:GetAttribute('EndedAt') then return end
  local at=group:GetAttribute('ContactAt') or 0
  if clock()-at<8 then watchBurn(owner,group);return end
  if burns[owner]==group then burns[owner]=nil end
  group:SetAttribute('EndedAt',clock())
  for _,object in ipairs(group:GetDescendants()) do
   if object:IsA('ParticleEmitter') then object.Enabled=false
   elseif object:IsA('BasePart') then object.Transparency=1 end
  end
  Debris:AddItem(group,ORBITAL_TAIL)
 end)
end
local function targetSight(owner: any,target: any,duration: number?)
 local group=Instance.new('Folder');group.Name='OrbitalTargetSight';group.Parent=folder();markers[owner]=group
 local value=part();if not value then group:Destroy();return end
 local radius=math.clamp((target.radius or 1)+.7,1.4,8)
 value.Name='ThinRedTargetCylinder';value.Shape=Enum.PartType.Cylinder
 value:SetAttribute('AudioLoop','orbital_charge');value:SetAttribute('AudioAt',clock());value:SetAttribute('AudioUntil',clock()+2.6)
 value.Color=Color3.fromRGB(242,38,44);value.Transparency=.88
 value.Size=Vector3.new(.035,radius*2,radius*2)
 value.CFrame=CFrame.new(target.x,(target.ground or target.y)+.045,target.z)*CFrame.Angles(0,0,math.pi/2)
 value.Parent=group
 local rig=BeamVFX.new(group,'Orbital',Color3.fromRGB(172,113,255))
 if rig then
  chargeTimelines[group]={rig=rig,at=clock(),duration=duration or 1.4,position=location(target)+Vector3.new(0,2.5,0)}
 end
 animate(value,1.35,Enum.EasingStyle.Sine,Enum.EasingDirection.In,{Transparency=.74})
 Debris:AddItem(group,2.6)
end
local function sustainedStrike(owner: any,event: any)
 local group=burns[owner]
 if group and not group.Parent then burns[owner]=nil;group=nil end
 if not group then
  group=Instance.new('Folder');group.Name='OrbitalMelt';burns[owner]=group
  group:SetAttribute('OrbitalBurn',true)
  group:SetAttribute('StartedAt',event.startedAt or clock())
  for index,width in ipairs({2.25,.65}) do
   local value=part();if not value then break end
   value.Name=index==1 and 'MeltHalo' or 'MeltCore';value.Shape=Enum.PartType.Cylinder
   value.Color=ORBITAL_COLOR
   value.Transparency=index==1 and .9 or .6;value.Size=Vector3.new(ORBITAL_HEIGHT,width,width);value.Parent=group
   value:SetAttribute('BurnTransparency',value.Transparency)
   if index==2 then
    local energy=Instance.new('ParticleEmitter');energy.Name='TurbulentColumnEnergy';energy.Texture=ENERGY
    energy.Color=ColorSequence.new(ORBITAL_COLOR);energy.LightEmission=1;energy.LightInfluence=0;energy.Brightness=1.25
    energy.Rate=10;energy.Lifetime=NumberRange.new(2,3.5);energy.Speed=NumberRange.new(.4,1.4);energy.Drag=1.8
    energy.Shape=Enum.ParticleEmitterShape.Cylinder;energy.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume;energy.EmissionDirection=Enum.NormalId.Right
    energy.SpreadAngle=Vector2.new(180,180);energy.Acceleration=Vector3.new(0,-.1,0);energy.WindAffectsDrag=false
    energy.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16,.04),NumberSequenceKeypoint.new(.15,.32,.06),NumberSequenceKeypoint.new(1,0)})
    energy.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.32),NumberSequenceKeypoint.new(.5,.6),NumberSequenceKeypoint.new(1,1)});energy.Parent=value
   end
  end
  local contact=part()
  if contact then
   contact.Name='MeltContact';contact.Shape=Enum.PartType.Ball;contact.Color=ORBITAL_COLOR
   contact.Transparency=.78;contact.Size=Vector3.one*.55;contact.Parent=group;contact:SetAttribute('BurnTransparency',.78)
   local tip=Instance.new('Attachment');tip.Parent=contact
   local sparks=Instance.new('ParticleEmitter');sparks.Name='MoltenSparks';sparks.Texture=SPARK;sparks.Squash=NumberSequence.new(.65);sparks.Rotation=NumberRange.new(-180,180)
   sparks.Color=ColorSequence.new(ORBITAL_COLOR);sparks.LightEmission=1;sparks.LightInfluence=0;sparks.Brightness=1.15
   sparks.Lifetime=NumberRange.new(2,3.5);sparks.Speed=NumberRange.new(.8,2);sparks.Drag=2.2;sparks.WindAffectsDrag=false
   sparks.Acceleration=Vector3.new(0,-.4,0);sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(60,60)
   sparks.Rate=8;sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.14,.03),NumberSequenceKeypoint.new(.12,.28,.04),NumberSequenceKeypoint.new(1,0)})
   sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.48),NumberSequenceKeypoint.new(.5,.68),NumberSequenceKeypoint.new(1,1)});sparks.Parent=tip
  end
  group:SetAttribute('Position',location(event.target));group:SetAttribute('ContactAt',clock())
  group.Parent=folder();watchBurn(owner,group)
 end
 local position=location(event.target)
 group:SetAttribute('Position',position);group:SetAttribute('ContactAt',clock())
 local fresh=workspace:GetServerTimeNow()-clock()<=.3
 local suspended=not fresh
 if group:GetAttribute('Suspended')~=suspended then
  group:SetAttribute('Suspended',suspended)
  for _,v in ipairs(group:GetDescendants()) do if v:IsA('ParticleEmitter') then v.Enabled=fresh end end
 end
 for _,value in ipairs(group:GetChildren()) do if value:IsA('BasePart') then
  local pose=value.Name=='MeltContact' and CFrame.new(position) or CFrame.new(position+Vector3.new(0,ORBITAL_HEIGHT*.5,0))*CFrame.Angles(0,0,math.pi/2)
  value.CFrame=pose
  value.Transparency=not fresh and 1 or (value:GetAttribute('BurnTransparency') or value.Transparency)
 end end
 group:SetAttribute('Placed',true)
end
function Effects.ClearAbility(owner: any)
 clearSwarm(owner);clearMarker(owner);clearBurn(owner)
end
function Effects.Ability(owner: any,event: any,template: Model?)
 local kind=event.kind
 if kind=='clear' then Effects.ClearAbility(owner)
 elseif kind=='clearCharge' then clearMarker(owner)
 elseif kind=='clearScrap' then clearSwarm(owner)
 elseif kind=='orbitalEnd' then clearBurn(owner)
 elseif kind=='charge' then
  clearMarker(owner)
  if event.ability=='Orbital' then targetSight(owner,event.target,event.duration);return end
  local value=part();if not value then return end
  value.Name='GadgetCharge';value.Shape=Enum.PartType.Ball;value.Size=Vector3.one*.45
  value:SetAttribute('AudioLoop','swarm_charge');value:SetAttribute('AudioAt',clock());value:SetAttribute('AudioUntil',clock()+2.6)
  value.Color=event.ability=='Orbital' and Color3.fromRGB(240,173,88) or Color3.fromRGB(178,202,151)
  value.Transparency=.7;value.Position=location(event.target)+Vector3.new(0,5,0)
  markers[owner]=value;Debris:AddItem(value,2.6)
 elseif kind=='orbital' then
  clearMarker(owner)
  sustainedStrike(owner,event)
 elseif kind=='relay' then
  local position=location(event.target)
  column(position,9,.18,Color3.fromRGB(176,218,255),.3)
  Effects.Pulse(position,Color3.fromRGB(176,218,255),.2,1.7,.3)
 elseif kind=='scrapStart' then clearMarker(owner)
 elseif kind=='recycle' then Effects.Pulse(location(event.target),Color3.fromRGB(173,222,146),.4,2.8,.4)

 end
end

function Effects.destroy()
 for rig in pairs(beamTimelines) do BeamVFX.destroy(rig) end
 for _,t in pairs(chargeTimelines) do BeamVFX.destroy(t.rig) end
 table.clear(beamTimelines);table.clear(chargeTimelines)
 table.clear(animations);table.clear(markers);table.clear(burns);table.clear(swarms)
 eventAt=nil
 local root=workspace:FindFirstChild('DroneRoleClientEffects');if root then root:Destroy() end
end
return Effects

