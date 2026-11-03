--!strict
-- Simple replicated effects for Drone Blower Revolution role testing.
-- All parts are created by the server and cleaned automatically.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}
local MAX_LIVE = 256
local live = 0

local function folder(): Folder
	local existing = workspace:FindFirstChild("DroneRoleServerEffects")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "DroneRoleServerEffects"
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

function Effects.Beam(from: Vector3, to: Vector3, color: Color3, width: number?, lifetime: number?)
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return
	end
	local value = part()
	if not value then
		return
	end
	local duration = lifetime or 0.16
	local thickness = width or 0.18
	value.Color = color
	value.Size = Vector3.new(thickness, thickness, delta.Magnitude)
	value.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.02, 0.02, delta.Magnitude),
	}):Play()
	Debris:AddItem(value, duration + 0.05)
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
	value.Transparency = 0.12
	value.Size = Vector3.one * first
	value.Position = position
	TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.one * last,
	}):Play()
	Debris:AddItem(value, duration + 0.05)
end

function Effects.Heal(from: Vector3, to: Vector3)
	local color = Color3.fromRGB(99, 255, 164)
	Effects.Beam(from, to, color, 0.22, 0.2)
	Effects.Pulse(to, color, 0.5, 2.5, 0.24)
end

function Effects.Charge(position: Vector3, target: Vector3, impact: boolean?)
	local color = Color3.fromRGB(255, 137, 70)
	if impact then
		Effects.Beam(position, target, color, 0.42, 0.2)
		Effects.Pulse(target, color, 1, 6, 0.28)
	else
		Effects.Pulse(position, Color3.fromRGB(255, 218, 105), 0.7, 4.8, 0.8)
	end
end

-- Seeding dust falls from the actual grower; the bloom confirms a real spawn.
function Effects.Grow(from: Vector3,target: Vector3,planted: boolean)
 local green=Color3.fromRGB(152,231,158)
 local value=part();if not value then return end
 value.Name=planted and 'CrystalSeedBloom' or 'CrystalSeedFall';value.Transparency=1
 if planted then value:SetAttribute('AudioCue','plant');value:SetAttribute('AudioAt',workspace:GetServerTimeNow()) end
 value.Position=planted and target or from
 local tip=Instance.new('Attachment');tip.Parent=value
 local dust=Instance.new('ParticleEmitter');dust.Texture='rbxasset://textures/particles/sparkles_main.dds'
 dust.Rate=0;dust.Color=ColorSequence.new(green,Color3.fromRGB(234,255,201));dust.LightEmission=.7
 dust.Lifetime=NumberRange.new(.5,planted and 1.1 or .9);dust.Speed=NumberRange.new(planted and 1 or 3,planted and 4 or 5)
 dust.EmissionDirection=planted and Enum.NormalId.Top or Enum.NormalId.Bottom;dust.SpreadAngle=Vector2.new(22,22)
 dust.Acceleration=Vector3.new(0,planted and 2 or -4,0);dust.Drag=1
 dust.Rotation=NumberRange.new(-180,180);dust.RotSpeed=NumberRange.new(-65,65)
 dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.14,.08),NumberSequenceKeypoint.new(1,0)})
 dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(1,1)})
 dust.Parent=tip;dust:Emit(planted and 22 or 14);Debris:AddItem(value,1.3)
 if planted then Effects.Pulse(target+Vector3.new(0,.25,0),green,.2,2.1,.45) end
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
  local cue=part();if cue then cue.Name='ConfirmedMiningImpact';cue.Transparency=1;cue.Position=target;cue:SetAttribute('MiningImpact','Breaker');cue:SetAttribute('ImpactAt',workspace:GetServerTimeNow());Debris:AddItem(cue,1) end
  Effects.Pulse(target,Color3.fromRGB(252,231,179),.4,4.6,.18)
  local shock=part()
  if shock then
   shock.Name='BreakerPressureWave';shock.Shape=Enum.PartType.Cylinder;shock.Color=Color3.fromRGB(221,196,142)
   shock.Transparency=.45;shock.Size=Vector3.new(.055,.6,.6);shock.CFrame=CFrame.new(target)*CFrame.Angles(0,0,math.pi/2)
   local attachment=Instance.new('Attachment');attachment.CFrame=CFrame.Angles(0,0,-math.pi/2);attachment.Parent=shock
   local dust=Instance.new('ParticleEmitter');dust.Texture='rbxasset://textures/particles/smoke_main.dds'
   dust.Color=ColorSequence.new(Color3.fromRGB(156,145,122));dust.Rate=0;dust.Lifetime=NumberRange.new(.25,.5)
   dust.Speed=NumberRange.new(5,11);dust.Drag=5;dust.EmissionDirection=Enum.NormalId.Top;dust.SpreadAngle=Vector2.new(80,80)
   dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.4),NumberSequenceKeypoint.new(1,1.3)})
   dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.65),NumberSequenceKeypoint.new(1,1)});dust.Parent=attachment;dust:Emit(14)
   TweenService:Create(shock,TweenInfo.new(.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(.055,8,8),Transparency=1}):Play()
   Debris:AddItem(shock,.65)
  end
  -- Debris-like points communicate an impact, rather than a long emitter ray.
  for index=1,9 do
   local chip=part();if not chip then break end
   local angle=index*2.399963
   chip.Name='BreakerChip';chip.Shape=Enum.PartType.Ball;chip.Material=Enum.Material.Slate
   chip.Color=Color3.fromRGB(142,131,109);chip.Size=Vector3.one*(.14+(index%3)*.10);chip.Position=target
   TweenService:Create(chip,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
    Position=target+Vector3.new(math.cos(angle)*(2+index*.3),.7+(index%4)*.45,math.sin(angle)*(2+index*.3)),Transparency=1,
   }):Play()
   Debris:AddItem(chip,.35)
  end
 elseif phase=='Recover' then
  Effects.Pulse(position,Color3.fromRGB(168,155,123),.15,.7,.2)
 end
end

-- Gadget FX are consequences of the authoritative DroneAbilities state machine.
-- Sources replicate complete poses for late joiners; AbilityView interpolates
-- their local clones without feeding any rendered transform back into damage.
local swarms: {[number]: Folder} = {}
local markers: {[number]: Instance} = {}
local function clearSwarm(owner: number)
 local old=swarms[owner]
 if old then swarms[owner]=nil;old:Destroy() end
end
local function clearMarker(owner: number)
 local old=markers[owner];markers[owner]=nil
 if old then old:Destroy() end
end
local function location(p: any): Vector3 return Vector3.new(p.x,p.y,p.z) end
local function column(position: Vector3,height: number,width: number,color: Color3,duration: number,transparency: number)
 local value=part();if not value then return end
 value.Shape=Enum.PartType.Cylinder;value.Color=color;value.Transparency=transparency
 value.Size=Vector3.new(height,width,width)
 value.CFrame=CFrame.new(position+Vector3.new(0,height*.5,0))*CFrame.Angles(0,0,math.pi/2)
 TweenService:Create(value,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=1,Size=Vector3.new(height,.02,.02)}):Play()
 Debris:AddItem(value,duration+.05)
end
local burns: {[number]: Folder} = {}
local function clearBurn(owner: number)
 local old=burns[owner];burns[owner]=nil
 if not old or not old.Parent then return end
 -- Stop work immediately, but let the column collapse into suspended embers.
 -- EndedAt also stops client shake; the server tween remains visible to everyone.
 old:SetAttribute('EndedAt',workspace:GetServerTimeNow())
 for _,effect in ipairs(old:GetDescendants()) do
  if effect:IsA('ParticleEmitter') then effect.Enabled=false end
 end
 local core=old:FindFirstChild('MeltCore')
 if core and core:IsA('BasePart') then
  for index=0,13 do
   local tip=Instance.new('Attachment');tip.Name='CoolingEmbers'
   tip.Position=Vector3.new(-17+index*34/13,math.noise(index*.81,owner)*.65,math.noise(owner,index*.67)*.65);tip.Parent=core
   local embers=Instance.new('ParticleEmitter');embers.Name='OrbitalAfterglow'
   embers.Texture='rbxasset://textures/particles/sparkles_main.dds';embers.Rate=0;embers.LightEmission=1
   embers.Color=ColorSequence.new(Color3.fromRGB(255,225,153),Color3.fromRGB(236,78,40))
   embers.Lifetime=NumberRange.new(.45,1.1);embers.Speed=NumberRange.new(.8,3.8);embers.Drag=2
   embers.SpreadAngle=Vector2.new(180,180);embers.Rotation=NumberRange.new(-180,180);embers.RotSpeed=NumberRange.new(-100,100)
   embers.Acceleration=Vector3.new(0,1.5,0)
   embers.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16,.1),NumberSequenceKeypoint.new(.3,.24,.13),NumberSequenceKeypoint.new(1,0)})
   embers.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(.55,.45),NumberSequenceKeypoint.new(1,1)})
   embers.Parent=tip;embers:Emit(5)
  end
 end
 for _,value in ipairs(old:GetChildren()) do if value:IsA('BasePart') then
  local size=value.Name=='MeltContact' and Vector3.one*.03 or Vector3.new(value.Size.X,.015,.015)
  TweenService:Create(value,TweenInfo.new(.48,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=size,Transparency=1}):Play()
 end end
 Debris:AddItem(old,1.3)
end
local function targetSight(owner: number,target: any)
 local group=Instance.new('Folder');group.Name='OrbitalTargetSight';group.Parent=folder();markers[owner]=group
 local value=part();if not value then group:Destroy();return end
 local radius=math.clamp((target.radius or 1)+.7,1.4,8)
 value.Name='ThinRedTargetCylinder';value.Shape=Enum.PartType.Cylinder
 value:SetAttribute('AudioLoop','orbital_charge');value:SetAttribute('AudioAt',workspace:GetServerTimeNow());value:SetAttribute('AudioUntil',workspace:GetServerTimeNow()+2.6)
 value.Color=Color3.fromRGB(242,38,44);value.Transparency=.8
 value.Size=Vector3.new(.035,radius*2,radius*2)
 value.CFrame=CFrame.new(target.x,(target.ground or target.y)+.045,target.z)*CFrame.Angles(0,0,math.pi/2)
 value.Parent=group
 TweenService:Create(value,TweenInfo.new(1.35,Enum.EasingStyle.Sine,Enum.EasingDirection.In),{Transparency=.55}):Play()
 Debris:AddItem(group,2.6)
end
local function sustainedStrike(owner: number,event: any)
 local group=burns[owner]
 if group and not group.Parent then burns[owner]=nil;group=nil end
 if not group then
  group=Instance.new('Folder');group.Name='OrbitalMelt';burns[owner]=group
  group:SetAttribute('OrbitalBurn',true)
  for index,width in ipairs({2.8,.8}) do
   local value=part();if not value then break end
   value.Name=index==1 and 'MeltHalo' or 'MeltCore';value.Shape=Enum.PartType.Cylinder
   value.Color=index==1 and Color3.fromRGB(252,66,43) or Color3.fromRGB(255,233,176)
   value.Transparency=index==1 and .65 or .13;value.Size=Vector3.new(34,width,width);value.Parent=group
   value:SetAttribute('BurnTransparency',value.Transparency)
  end
  local contact=part()
  if contact then
   contact.Name='MeltContact';contact.Shape=Enum.PartType.Ball;contact.Color=Color3.fromRGB(255,183,77)
   contact.Transparency=.25;contact.Size=Vector3.one*1.2;contact.Parent=group;contact:SetAttribute('BurnTransparency',.25)
   local tip=Instance.new('Attachment');tip.Parent=contact
   local sparks=Instance.new('ParticleEmitter');sparks.Name='MoltenSparks';sparks.Texture='rbxasset://textures/particles/sparkles_main.dds'
   sparks.Color=ColorSequence.new(Color3.fromRGB(255,230,144),Color3.fromRGB(240,76,35));sparks.LightEmission=1
   sparks.Lifetime=NumberRange.new(.2,.45);sparks.Speed=NumberRange.new(10,21);sparks.Drag=2
   sparks.Acceleration=Vector3.new(0,-32,0);sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(75,75)
   sparks.Rate=95;sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,0)})
   sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(1,1)});sparks.Parent=tip
  end
  group:SetAttribute('Position',location(event.target));group:SetAttribute('ContactAt',workspace:GetServerTimeNow())
  group.Parent=folder();Debris:AddItem(group,12)
 end
 local position=location(event.target)
 group:SetAttribute('Position',position);group:SetAttribute('ContactAt',workspace:GetServerTimeNow())
 for _,value in ipairs(group:GetChildren()) do if value:IsA('BasePart') then
  local pose=value.Name=='MeltContact' and CFrame.new(position) or CFrame.new(position+Vector3.new(0,17,0))*CFrame.Angles(0,0,math.pi/2)
  if not group:GetAttribute('Placed') then value.CFrame=pose
  else TweenService:Create(value,TweenInfo.new(.1,Enum.EasingStyle.Linear),{CFrame=pose}):Play() end
 end end
 group:SetAttribute('Placed',true)
end
function Effects.ClearAbility(owner: number)
 clearSwarm(owner);clearMarker(owner);clearBurn(owner)
end
function Effects.Ability(owner: number,event: any,template: Model?)
 local kind=event.kind
 if kind=='clear' then Effects.ClearAbility(owner)
 elseif kind=='clearCharge' then clearMarker(owner)
 elseif kind=='clearScrap' then clearSwarm(owner)
 elseif kind=='orbitalEnd' then clearBurn(owner)
 elseif kind=='charge' then
  clearMarker(owner)
  if event.ability=='Orbital' then targetSight(owner,event.target);return end
  local value=part();if not value then return end
  value.Name='GadgetCharge';value.Shape=Enum.PartType.Ball;value.Size=Vector3.one*.45
  value:SetAttribute('AudioLoop','swarm_charge');value:SetAttribute('AudioAt',workspace:GetServerTimeNow());value:SetAttribute('AudioUntil',workspace:GetServerTimeNow()+2.6)
  value.Color=event.ability=='Orbital' and Color3.fromRGB(240,173,88) or Color3.fromRGB(178,202,151)
  value.Transparency=.5;value.Position=location(event.target)+Vector3.new(0,5,0)
  markers[owner]=value;Debris:AddItem(value,2.6)
 elseif kind=='orbital' then
  clearMarker(owner)
  sustainedStrike(owner,event)
 elseif kind=='relay' then
  local position=location(event.target)
  column(position,9,.22,Color3.fromRGB(176,218,255),.3,.4)
  Effects.Pulse(position,Color3.fromRGB(176,218,255),.25,2.3,.3)
 elseif kind=='scrapStart' then clearMarker(owner)
 elseif kind=='recycle' then Effects.Pulse(location(event.target),Color3.fromRGB(173,222,146),.4,2.8,.4)
 elseif kind=='scrapPose' then
  local group=swarms[owner]
  if group and not group.Parent then clearSwarm(owner);group=nil end
  if not group then
   -- One group of at most six bots per connected owner. Do not silently omit
   -- another player's authoritative work after a fixed first-N visual cap.
   if not template or not template:IsA('Model') then return end
   group=Instance.new('Folder');group.Name='ScrapSwarm_'..owner;group:SetAttribute('ScrapSwarm',true);group:SetAttribute('Owner',owner)
   group.Parent=folder();swarms[owner]=group;Debris:AddItem(group,13)
  end
  group:SetAttribute('Expires',event.expires)
  for index,bot in ipairs(event.bots) do
   if index>6 then break end
   local name='ScrapBot_'..bot.id;local model=group:FindFirstChild(name) :: Model?
   if not model then
    model=template:Clone();model.Name=name
    for _,object in ipairs(model:GetDescendants()) do
     if object:IsA('LuaSourceContainer') or object:IsA('BillboardGui') or object:IsA('SurfaceGui') or object:IsA('Sound') then object:Destroy()
     elseif object:IsA('BasePart') then
      object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false
      object.Reflectance=0;object.CastShadow=false
     elseif object:IsA('Trail') or object:IsA('Beam') or object:IsA('ParticleEmitter') then object.Enabled=false end
    end
    model:ScaleTo(model:GetScale()*.18);model:SetAttribute('ScrapBot',true);model.Parent=group
   end
   local position=Vector3.new(bot.x,bot.y,bot.z)
   model:SetAttribute('Position',position);model:SetAttribute('Active',bot.active)
   model:SetAttribute('TargetPosition',bot.target and location(bot.target) or position)
   model:SetAttribute('Pulse',bot.pulse);model:PivotTo(CFrame.new(position))
  end
 end
end

return Effects

