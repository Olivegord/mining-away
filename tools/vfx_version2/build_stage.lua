-- Edit-only: (re)build Workspace["VERSION 2"], the Pressure Strike showcase. Run through tools/studio_vfx_version2.py,
-- which fills in the two sources. Touches nothing outside its own model.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, 'Wrong place')
assert(not game:GetService('RunService'):IsRunning(), 'Stop Play before building')

local MODULE_SOURCE = __MODULE__
local REPLAY_SOURCE = __REPLAY__
local CENTER = Vector3.new(0, 3.8, 135) -- open baseplate south of the hub
local PREVIEW_AT = 1.74

local old = workspace:FindFirstChild('VERSION 2')
if old then
	old:Destroy()
end
if shared.V2 and shared.V2.rig then
	pcall(function()
		shared.V2.rig:Destroy()
	end)
	shared.V2 = nil
end

local model = Instance.new('Model')
model.Name = 'VERSION 2'
model:SetAttribute('Effect', 'Pressure Strike')
model:SetAttribute('Reference', 'https://www.youtube.com/watch?v=-RYr9ZNJPGM 30.07-33.30s')
model:SetAttribute('Scale', 1)

local function part(name, size, cframe, color)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = model
	return p
end

-- a dark floor so pale effects read in daylight, as on the reference's dark grid
local stage = part('Stage', Vector3.new(0.12, 70, 70), CFrame.new(CENTER + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(27, 28, 27))
stage.Shape = Enum.PartType.Cylinder
stage.Material = Enum.Material.Concrete -- matte: a glossy floor mirrors the strike light as a long smear
local top = CENTER + Vector3.new(0, 0.14, 0)

local origin = part('StrikeOrigin', Vector3.new(0.4, 0.05, 0.4), CFrame.new(top), Color3.fromRGB(27, 28, 27))
origin.Transparency = 1
origin.CanCollide = false
origin.CanQuery = false
origin.CanTouch = false
model.PrimaryPart = origin

-- a 5-stud stand-in beside the strike, where the caster stands in the reference
local dummy = Instance.new('Model')
dummy.Name = 'ScaleDummy'
dummy.Parent = model
local skin = Color3.fromRGB(226, 220, 204)
local feet = top + Vector3.new(12, 0, 5)
local function limb(name, size, offset)
	local p = part(name, size, CFrame.new(feet + offset), skin)
	p.CanCollide = false
	p.Parent = dummy
end
limb('LeftLeg', Vector3.new(0.9, 2, 0.9), Vector3.new(-0.5, 1, 0))
limb('RightLeg', Vector3.new(0.9, 2, 0.9), Vector3.new(0.5, 1, 0))
limb('Torso', Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
limb('LeftArm', Vector3.new(0.9, 2, 0.9), Vector3.new(-1.5, 3, 0))
limb('RightArm', Vector3.new(0.9, 2, 0.9), Vector3.new(1.5, 3, 0))
limb('Head', Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0))

-- one small sign on the hub side
local board = part('Sign', Vector3.new(9, 1.8, 0.25), CFrame.new(CENTER + Vector3.new(0, 3.4, -36.5)), Color3.fromRGB(22, 23, 24))
part('SignPost', Vector3.new(0.3, 2.6, 0.3), CFrame.new(CENTER + Vector3.new(0, 1.3, -36.5)), Color3.fromRGB(22, 23, 24))
for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
	local gui = Instance.new('SurfaceGui')
	gui.Name = 'Label'
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = 'VERSION 2  ·  Pressure Strike'
	label.TextColor3 = Color3.fromRGB(255, 251, 228)
	label.TextScaled = true
	label.Parent = gui
	local pad = Instance.new('UIPadding')
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.2, 0), UDim.new(0.2, 0)
	pad.Parent = label
end

local module = Instance.new('ModuleScript')
module.Name = 'PressureStrikeV2'
module.Source = MODULE_SOURCE
module.Parent = model

local replay = Instance.new('Script')
replay.Name = 'Replay'
replay.RunContext = Enum.RunContext.Client
replay.Source = REPLAY_SOURCE
replay.Parent = model

-- what Edit shows: the strike frozen mid-barrage. The replay script removes it when the game runs.
local preview = Instance.new('Folder')
preview.Name = 'EditPreview'
preview.Parent = model
local Strike = require(module:Clone())
local frozen = Strike.new(preview, origin.CFrame, 1)
frozen:Seek(PREVIEW_AT)

model.Parent = workspace

-- a second, unsaved rig for posing the strike at exact times while checking it against the video
local scratch = Instance.new('Folder')
scratch.Name = 'V2PoseScratch'
scratch.Archivable = false
scratch.Parent = workspace
for _, other in workspace:GetChildren() do
	if other.Name == 'V2PoseScratch' and other ~= scratch then
		other:Destroy()
	end
end
shared.V2 = { Strike = Strike, scratch = scratch, origin = origin.CFrame, preview = preview }
return 'built VERSION 2 at ' .. tostring(CENTER) .. ' with ' .. #model:GetDescendants() .. ' instances'
