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

-- A scout identifies work without pretending to cut it. The small nested
-- spheres mark that real server target; there is deliberately no laser beam.
function Effects.Scan(from: Vector3,target: Vector3,lifetime: number?)
 local duration=math.clamp(lifetime or 8,.2,10)
 local blue=Color3.fromRGB(103,194,227)
 Effects.Pulse(from,blue,.18,.85,.25)
 for index,size in ipairs({.18,.32,.5}) do
  local marker=part();if not marker then break end
  marker.Name='ScoutMark';marker.Shape=Enum.PartType.Ball;marker.Color=blue
  marker.Position=target+Vector3.new(0,.45,0);marker.Size=Vector3.one*size
  marker.Transparency=.22+index*.15
  TweenService:Create(marker,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
   Transparency=1,Size=Vector3.one*size*.65,
  }):Play()
  Debris:AddItem(marker,duration+.05)
 end
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
  Effects.Pulse(target,Color3.fromRGB(252,231,179),.25,2.8,.22)
  -- Debris-like points communicate an impact, rather than a long emitter ray.
  for index=1,3 do
   local chip=part();if not chip then break end
   local angle=index*2.399963
   chip.Name='BreakerChip';chip.Shape=Enum.PartType.Ball;chip.Material=Enum.Material.Slate
   chip.Color=Color3.fromRGB(142,131,109);chip.Size=Vector3.one*(.15+index*.035);chip.Position=target
   TweenService:Create(chip,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
    Position=target+Vector3.new(math.cos(angle)*1.7,.5+index*.2,math.sin(angle)*1.7),Transparency=1,
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
local function confirmedImpact(position: Vector3,kind: string)
 local value=part();if not value then return end
 value.Name='ConfirmedMiningImpact';value.Transparency=1;value.Size=Vector3.one*.05;value.Position=position
 value:SetAttribute('MiningImpact',kind);value:SetAttribute('ImpactAt',workspace:GetServerTimeNow());Debris:AddItem(value,1)
end
local function targetSight(owner: number,target: any)
 local group=Instance.new('Folder');group.Name='OrbitalTargetSight';group.Parent=folder();markers[owner]=group
 local position=location(target);local radius=math.clamp((target.radius or 1)+.7,1.4,4)
 local ground=target.ground or position.Y
 for index=1,4 do
  local angle=(index-1)*math.pi/2;
  local value=part();if not value then break end
  value.Name='RedTargetBracket';value.Color=Color3.fromRGB(238,63,63);value.Transparency=.22
  value.Size=Vector3.new(.12,.055,radius*.8);value.CFrame=CFrame.new(position.X,ground+.045,position.Z)*CFrame.Angles(0,-angle,0)*CFrame.new(radius,0,0)
  value.Parent=group
  TweenService:Create(value,TweenInfo.new(1.35,Enum.EasingStyle.Sine,Enum.EasingDirection.In),{CFrame=value.CFrame*CFrame.new(-.35,0,0),Transparency=.05}):Play()
 end
 for index=1,2 do
  local value=part();if not value then break end
  value.Name='RedTargetCrosshair';value.Color=Color3.fromRGB(255,82,72);value.Transparency=.3
  value.Size=Vector3.new(.65,.05,.07);value.CFrame=CFrame.new(position.X,ground+.06,position.Z)*CFrame.Angles(0,index*math.pi/2,0);value.Parent=group
 end
 Debris:AddItem(group,2.6)
end
local function descendingStrike(position: Vector3)
 local red=Color3.fromRGB(248,78,61)
 for index,width in ipairs({2.4,.42}) do
  local value=part();if not value then break end
  value.Name='OrbitalRain';value.Shape=Enum.PartType.Cylinder;value.Color=index==1 and red or Color3.fromRGB(255,235,194)
  value.Transparency=index==1 and .68 or .12;value.Size=Vector3.new(.05,width,width)
  value.CFrame=CFrame.new(position+Vector3.new(0,34,0))*CFrame.Angles(0,0,math.pi/2)
  TweenService:Create(value,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
   Size=Vector3.new(34,width,width),CFrame=CFrame.new(position+Vector3.new(0,17,0))*CFrame.Angles(0,0,math.pi/2),
  }):Play()
  task.delay(.12,function() if value.Parent then
   TweenService:Create(value,TweenInfo.new(.32,Enum.EasingStyle.Sine),{Transparency=1,Size=Vector3.new(34,.02,.02)}):Play()
  end end)
  Debris:AddItem(value,.5)
 end
 task.delay(.12,function() confirmedImpact(position,'Orbital');Effects.Pulse(position,red,.35,4.2,.3) end)
end
function Effects.ClearAbility(owner: number)
 clearSwarm(owner);clearMarker(owner)
end
function Effects.Ability(owner: number,event: any,template: Model?)
 local kind=event.kind
 if kind=='clear' then Effects.ClearAbility(owner)
 elseif kind=='clearCharge' then clearMarker(owner)
 elseif kind=='clearScrap' then clearSwarm(owner)
 elseif kind=='charge' then
  clearMarker(owner)
  if event.ability=='Orbital' then targetSight(owner,event.target);return end
  local value=part();if not value then return end
  value.Name='GadgetCharge';value.Shape=Enum.PartType.Ball;value.Size=Vector3.one*.45
  value.Color=event.ability=='Orbital' and Color3.fromRGB(240,173,88) or Color3.fromRGB(178,202,151)
  value.Transparency=.5;value.Position=location(event.target)+Vector3.new(0,5,0)
  markers[owner]=value;Debris:AddItem(value,2.6)
 elseif kind=='orbital' then
  clearMarker(owner)
  descendingStrike(location(event.target))
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

