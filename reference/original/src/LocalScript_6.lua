wait()

local cube = game.Workspace.DroneTest -- Assumes the script is a child of the cube object
local player = game.Players.LocalPlayer -- Gets the local player
local lerpSpeed = .2 -- Set the speed of interpolation (you can adjust this value)

local velocity = 0
local rotation = 0

local function moveCube()
	local direction = (player.Character.HumanoidRootPart.Position + Vector3.new(5, 0, 0)) - cube.Position
	local distance = direction.magnitude

	local movement = Vector3.new(.1, 0, 0)

	local direction = player.Character.HumanoidRootPart.Position - cube.Position
	local angleRadians = math.atan2(direction.X, direction.Z)
	local angleDegrees = math.deg(angleRadians)
	
	if angleDegrees < 0 then
		velocity -= .1
	elseif angleDegrees >0 then
		velocity += .1
	end
	
	rotation += velocity
	

	-- Modify the cube's rotation towards the player on the y-axis
	cube.CFrame = CFrame.new(cube.Position) * CFrame.Angles(0, math.rad(rotation), 0)
	

end

game:GetService("RunService").Heartbeat:Connect(moveCube)
