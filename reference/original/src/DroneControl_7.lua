local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local patches = game.Workspace:WaitForChild("Patches")

local function getUnitVector(angle)
	local x = math.cos(math.rad(angle))
	local z = math.sin(math.rad(angle))
	
	return Vector3.new(x, 0, z) * 10
end

print("?")
local droneDict = {}




local patchDict = {}

patchDict["rubyPatch"] = { -- needs a name component
	name = "rubyPatch",
	maxCrystals = 3,
	mesh = patches:WaitForChild("rubyPatch"),
	crystalDict = {},
	availableIDs = {}
}

patchDict["cobaltPatch"] = {
	name = "cobaltPatch",
	maxCrystals = 3,
	mesh = patches:WaitForChild("cobaltPatch"),
	crystalDict = {},
	availableIDs = {}
}

for i = 1, patchDict["rubyPatch"].maxCrystals do -- these must be optimized for more patches
	table.insert(patchDict.rubyPatch.availableIDs, i)
end

for i = 1, patchDict["cobaltPatch"].maxCrystals do -- see above
	table.insert(patchDict.cobaltPatch.availableIDs, i)
end

print(patchDict.rubyPatch.availableIDs)



droneCount = 8

local MainModule = require(rs.MainModule)


local player = game.Players.LocalPlayer


for i = 1, droneCount do 
	droneDict[i] = {
		model = rs.Drone:Clone().Mesh,
		speed = math.random(20, 30)/1000,
		maxSpeed = math.random(8,50)/100,
		
		id = i,
		
		mode = "following",
		patch = {
			name = "noPatch"
		},
		
		destination = {
			location = nil,
			name = ""
		},
		
		crystal = nil,
		
		beam = nil,
		
		isMining = false
	}
	droneDict[i].model.Parent.Parent = game.Workspace
	
end



local dictLength = 0-- make module later

for i, v in pairs(droneDict) do -- maybe use droneCount?
	dictLength += 1
end


local counter = 0
for i, v in pairs(droneDict) do
	counter += 1
	
	v.offset = getUnitVector((360 / dictLength) * counter)
end




local frame = 0










local function changeDroneCrystal(drone,destName, crystal, patch)
	drone.mode = "mining"
	
	
	drone.destination.name = destName
	
	drone.patch = patchDict[patch]

	
	if destName == "crystal" then
		drone.destination.location = crystal.mesh.Position
		drone.crystal = crystal
		crystal.canBeMined = false
	end
	
	if destName == "idle" then
		warn(patch.mesh)
		drone.destination.location = patchDict[patch].mesh.Position
		
	end
	
	
	
	if drone.beam then 
		MainModule.DestroyBeam(drone.beam)
		drone.beam = nil

	end

end


local function changeDroneModeFollowing(drone)
	drone.mode = "following"
	if drone.crystal then
		drone.crystal.canBeMined = true
	end
	
	
	if drone.beam then
		MainModule.DestroyBeam(drone.beam)
		drone.beam = nil
	end
end



local function callDroneMine(droneValue, patch)
	print("called")
	
	local shortestDistance = math.huge
	local nearestCrystal
	local distance

	local count = 0

	local reason = "no reason foo"

	local kys = false -- replace with return now that system is better
	
	local patchChange = false

	
	
	if droneValue.destination.name == "crystal" and droneValue.patch == patch then
		
		if droneValue.patch then
			warn(droneValue.destination.name .. droneValue.id)

		end
		kys = true

		return
		
	else 
		
		if droneValue.patch.name ~= patch then
				patchChange = true
			if droneValue.patch then
				warn(droneValue.patch.name .. "    " .. patch)

			end

		end
		 
	end
	
	
	for crystalIndex, crystalValue in pairs(patchDict[patch].crystalDict) do

		if crystalValue == nil  then
			warn("no crsytals?")
			reason = "nocrystals"
		--	return
		end

		local teste

		if crystalValue.canBeMined == true then
			crystalValue.mesh.Color = Color3.new(1,1,1)
		elseif crystalValue.canBeMined == false then
			teste = "false"
			crystalValue.mesh.Color = Color3.new(0,0,0)


		else

		end



		--crystalValue.mesh.BillboardGui.Frame.TextLabel.Text = teste


		-- Check if the crystal is available (not being mined by another drone)
		if crystalValue.canBeMined == true and crystalValue.health > 10 then
			count += 1

		--	crystalValue.mesh.Color = Color3.new(0,1,0)

			--crystalValue.mesh.Color = Color3.new(0,1,1)
			distance = (droneValue.model.Position - crystalValue.mesh.Position).Magnitude

			if distance < shortestDistance then
				shortestDistance = distance
				nearestCrystal = crystalValue
			end

		else
			--	print(crystalValue.canBeMined, crystalValue.health)
		end



	end
	
	if kys == false then
		if nearestCrystal and patchChange == false then
			droneValue.model.Parent.BillboardGui.Frame.TextLabel.Text = "I CAN FLY"
			droneValue.model.Color = Color3.new(0,1,1)
			warn(nearestCrystal.canBeMined)

			changeDroneCrystal(droneValue, "crystal" ,nearestCrystal, patch)
		elseif patchChange == true then
			if nearestCrystal then
				warn(nearestCrystal.canBeMined)

				changeDroneCrystal(droneValue, "crystal",nearestCrystal, patch)

			else
				warn("D")
				changeDroneCrystal(droneValue, "idle", nil,patch)
			end
		end
	else 
		warn("KYS")
	end
	
	--[[
	if patchChange == true then
		
		warn( droneValue.crystal )

		
		if droneValue.crystal ~= nil then
			droneValue.crystal.canBeMined = true

		end
		
		
		

	end

	if nearestCrystal and kys == false then
		droneValue.model.Parent.BillboardGui.Frame.TextLabel.Text = "I CAN FLY"
		droneValue.model.Color = Color3.new(0,1,1)

		nearestCrystal.canBeMined = false
		changeDroneCrystal(droneValue, nearestCrystal)
		
		

	else
		droneValue.model.Parent.BillboardGui.Frame.TextLabel.Text = "Inoooo"
		warn(reason)

	end
	
	print(patchChange)
	
	--]]


end







local function rotateAndMoveForwardsToPlayer()
	local playerPos = player.Character.HumanoidRootPart.Position
	local desiredRotation
	local targetPosition

	
	for k, v in pairs(droneDict) do

		
		if v.mode == "following" then -- change to seitch case latetr
			targetPosition = playerPos + Vector3.new(v.offset.X, 7, v.offset.Z)
			
			local lookVector = (targetPosition - v.model.Position).unit -- this is dogwater
			desiredRotation = CFrame.new(v.model.Position, v.model.Position + lookVector)
		--[[

		elseif v.mode == "traveling" then
			
			targetPosition = v.destination.location + Vector3.new(0,10,0)

			local lookVector = (targetPosition - v.model.Position).unit -- this is dogwater
			desiredRotation = CFrame.new(v.model.Position, v.model.Position + lookVector)
			
			
			
		--]]
			
		elseif v.mode == "mining" then
			
			if v.isMining == true then
				
			end
			
			if v.destination.name == "crystal" then
				v.model.Parent.BillboardGui.Frame.TextLabel.Text = v.destination.name

				targetPosition = v.destination.location + Vector3.new(0,10,0)
		--		v.model.Color = Color3.new(0,1,0)
				v.model.Beampart1.Position = v.destination.location
				v.model.Beampart2.Position = v.model.Position
				
				if not v.crystal then
				
				end
				
			end
			
			if v.destination.name == "idle" then
				v.model.Beampart2.Position = v.model.Position
				v.model.Beampart1.Position = v.model.Position
				v.model.Parent.BillboardGui.Frame.TextLabel.Text = v.destination.name
				targetPosition = v.patch.mesh.Position + Vector3.new(v.offset.X, 10, v.offset.Z)
			--	v.model.Color = Color3.new(1,1,0)

			end
			
			if (targetPosition - v.model.Position).Magnitude <= 1 and v.destination.name == "crystal" and v.crystal then -- the and v.crystal part is a bad solution
				print(v.crystal)
				if not v.beam then
					v.beam = MainModule.CreateBeam(v.model, v.crystal.mesh.Attachment)

				end
				
				v.isMining = true
				
				if v.crystal.health > 10 then
					v.crystal.health -= .05
				else -- crystal depleted

					table.insert(patchDict[v.crystal.patch].availableIDs, v.crystal.id)		 -- THIS IS BUGGED		

					local remove = spawn(function()
						local minedCrystal = v.crystal -- v.crystal can change by the time the remove function is called, this fixes a bug
						
						if v.beam then
							MainModule.DestroyBeam(v.beam)
							v.beam = nil

						end
						v.crystal = nil
						minedCrystal.mesh.Transparency = 1
						callDroneMine(v ,v.patch.name)

						
						local removeMesh = spawn(function()

							wait(2)
							minedCrystal.mesh:Destroy()

						end)
						
						--print( "amount: " .. #patchDict[minedCrystal.patch.name].availableIDs)
					

						wait(math.random(5,6))
						
						warn(#patchDict[minedCrystal.patch.name].availableIDs)
						
						if #patchDict[minedCrystal.patch.name].availableIDs <= patchDict[minedCrystal.patch.name].maxCrystals then
							patchDict[minedCrystal.patch.name].crystalDict = MainModule.SpawnCrystals(patchDict[minedCrystal.patch.name], 1) -- this could be moved to the uda skipt?
							for k, v in pairs(droneDict) do
								callDroneMine(v ,v.patch.name)
							end

						end
						

					end)
					

					
					v.isMining = false -- put into func
					
					v.destination.name = "idle"

				end

				local healthPercentage = v.crystal.health / v.crystal.maxHealth

				v.crystal.mesh.Size = Vector3.new(
					healthPercentage,
					healthPercentage, 
					healthPercentage) * v.crystal.maxHealth/25


				v.crystal.mesh.Position = Vector3.new(
					v.crystal.mesh.Position.X,
					v.crystal.mesh.Size.Y/2 + 2, 
					v.crystal.mesh.Position.Z) 

				v.crystal.mesh.Attachment.Position = Vector3.new(0,v.crystal.mesh.Size.Y/2,0) 

				if healthPercentage < .5 then
					v.crystal.mesh.Color = Color3.new( (healthPercentage + (healthPercentage)), 0, 0)
				end

				local teste

				if v.crystal.canBeMined == true then
					teste = "false"
				else
					teste = "false"
				end

				v.crystal.mesh.BillboardGui.Frame.TextLabel.Text = teste
			end
			
			

			
			desiredRotation = CFrame.new(v.model.Position, v.model.Position + Vector3.new(math.random(0,360), 0, math.random(0,360)))
		end
		
		

		-- Rotate towards dest
		v.model.CFrame = v.model.CFrame:Lerp(desiredRotation, 0.05) -- Adjust the last parameter to control the speed of rotation

		-- Move forwards based on the distance from the player
		local distance = (targetPosition - v.model.Position).magnitude
		local moveSpeed = v.speed
		local forwardDirection = v.model.CFrame.lookVector
		local turnPosition = v.model.Position + forwardDirection * distance -- constrains cube to turning
		local newPosition = v.model.Position:Lerp(targetPosition, moveSpeed) -- where the cube wants to move
		

		
		if (newPosition - v.model.Position).Magnitude < v.maxSpeed then -- how fast does the cube want to move, is it too fast?
			v.model.Position = newPosition -- if slow enough than it can move to new position
		else
			v.model.Position += (newPosition - v.model.Position).Unit * v.maxSpeed -- if too fast than speed is clamped to max!
		end
		
		
		
	end
	
	frame += 1
	
	
	player.PlayerGui.IngameGui.Frame.Frame.TextLabel.Text = #patchDict.rubyPatch.availableIDs
	
	--[[
	
	for k, v in pairs(patchDict.rubyPatch.crystalDict) do
		
		local teste

		if v.canBeMined == true then
			teste = "true"
		else
			teste = "false"
		end
		
		if v.mesh.BillboardGui then
			v.mesh.BillboardGui.Frame.TextLabel.Text = teste
		else
			print("kill me now")
		end
	end
	
	--]]
--	warn(patchDict.rubyPatch.crystalDict)

end





local function performRaycast()
	local mouse = game.Players.LocalPlayer:GetMouse()
	
	local rayParams = RaycastParams.new()
	
	rayParams.FilterDescendantsInstances = {player.Character}
		
	local ray = workspace:Raycast(workspace.CurrentCamera.CFrame.Position, mouse.UnitRay.Direction * 300, rayParams)

	if ray then
		return {object = ray.Instance, Position = ray.Position}

	end	
	
end

uis.InputBegan:Connect(function(input, isProcessed)
	if isProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputState == Enum.UserInputState.Begin then
		
		local raycastResult = performRaycast()
		
		if raycastResult.object.Parent == game.Workspace.Patches then
			
			for i, v in pairs(droneDict) do

				callDroneMine(v, raycastResult.object.name)

			end

		end
		--	changeDroneMode("travelingf", raycastResult.Position)
		
		
		
		
	end
	if input.KeyCode.Name == "G" then
		for i, v in pairs(droneDict) do
			changeDroneModeFollowing(v)
		end
	end
end)



patchDict.rubyPatch.crystalDict = MainModule.SpawnCrystals(patchDict.rubyPatch, patchDict.rubyPatch.maxCrystals)

patchDict.cobaltPatch.crystalDict = MainModule.SpawnCrystals(patchDict.cobaltPatch, patchDict.cobaltPatch.maxCrystals)




-- Connect the rotateAndMoveForwardsToPlayer function to the RenderStepped event
game:GetService("RunService").Stepped:Connect(rotateAndMoveForwardsToPlayer)



--[[ names:


cascade

bitter

sussurus -- soft sound

redolent -- strongly reminicent

Eunoia -- pleasent mind


places: 

Querencia -- safe place



---]]

