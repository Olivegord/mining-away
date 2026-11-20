-- Replays the Pressure Strike on its stage for anyone nearby. Runs on each client; nothing here touches gameplay.
local RunService = game:GetService('RunService')

local model = script.Parent
local Strike = require(model:WaitForChild('PressureStrikeV2'))
local origin = model:WaitForChild('StrikeOrigin')

local preview = model:FindFirstChild('EditPreview') -- the frozen pose shown in Edit
if preview then
	preview:Destroy()
end

local REST = 1.6 -- quiet gap between replays
local RANGE = 420 -- studs; farther away the rig sleeps
local cycle = Strike.DURATION + REST
local rig = Strike.new(model, origin.CFrame, model:GetAttribute('Scale') or 1)
local started = os.clock()
local asleep = false

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - origin.Position).Magnitude > RANGE then
		if not asleep then
			asleep = true
			rig:Seek(-1)
		end
		return
	end
	if asleep then
		asleep = false
		started = os.clock()
	end
	rig:Step((os.clock() - started) % cycle)
end)
