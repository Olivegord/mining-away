-- require the skinnedgrass module
local folder = script.Parent
local SkinnedGrass = require(folder.Parent:WaitForChild("SkinnedGrass"))
-- create a new grass object by calling .new
local grass = SkinnedGrass.new()

-- add all the meshes to the object
local models = folder:WaitForChild("Models")
local meshesToAdd = models:GetChildren()
grass:AddMeshes(meshesToAdd)
models.ChildAdded:Connect(function(child) -- if meshes aren't fully loaded in
	if table.find(meshesToAdd, child) then return end -- mesh already added to simulation
	table.insert(meshesToAdd, child)
	grass:AddMeshes({child})
end)

-- you can change the simulation settings at any time with UpdateSettings
-- grass:UpdateSettings({CollisionAngle = 60})

-- call :Step inside of RenderStepped
local player = game.Players.LocalPlayer
game:GetService("RunService").RenderStepped:Connect(function(deltaTime)
	local collisions = {}
	local character = player.Character
	if not character then return end
	local playerRoot = character.PrimaryPart
	if playerRoot then
		local collision = playerRoot.Position -- collision is a Vector3 position
		--local collisionWithSettings = {character.PrimaryPart.Position, {CollisionRadiusOuter = 10}} -- if you want custom settings on the collision, format like so and pass into table
		table.insert(collisions, collision) -- pass collisions into table
	end
	
	local simulationCenter = nil -- optional Vector3 to center simulation around. When nil the module uses local player position
	
	grass:Step(deltaTime, collisions, simulationCenter)
end)