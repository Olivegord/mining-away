--!strict
-- Simple replicated effects for Drone Blower Revolution role testing.
-- All parts are created by the server and cleaned automatically.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}
local MAX_LIVE = 160
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

return Effects

