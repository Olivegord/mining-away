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

-- Gadget FX are consequences of the authoritative DroneAbilities state machine.
-- Sources replicate complete poses for late joiners; AbilityView interpolates
-- their local clones without feeding any rendered transform back into damage.
local swarms: {[number]: Folder} = {}
local markers: {[number]: Part} = {}
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
  local value=part();if not value then return end
  value.Name='GadgetCharge';value.Shape=Enum.PartType.Ball;value.Size=Vector3.one*.45
  value.Color=event.ability=='Orbital' and Color3.fromRGB(240,173,88) or Color3.fromRGB(178,202,151)
  value.Transparency=.5;value.Position=location(event.target)+Vector3.new(0,5,0)
  markers[owner]=value;Debris:AddItem(value,2.6)
 elseif kind=='orbital' then
  clearMarker(owner)
  local position=location(event.target);local color=Color3.fromRGB(255,189,91)
  column(position,34,3.2,color,.5,.78);column(position,34,.46,Color3.fromRGB(255,238,183),.35,.25)
  Effects.Pulse(position,color,.4,5,.35)
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

