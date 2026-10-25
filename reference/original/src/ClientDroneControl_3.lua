local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local patches = game.Workspace:WaitForChild("Patches")

local remoteEvents = rs.RemoteEvents

local localPlayer = game.Players.LocalPlayer

coc = game.Workspace:WaitForChild("Test")

print("?")


local playerDict = {}

local converter = game.Workspace:WaitForChild("Converter");

local patchDict = {}

local bob = game.Workspace.Cat

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


local test = false

local function gameLoop()

	for k, player in pairs(playerDict) do
		
		for k, drone in pairs(player.droneDict) do -- make a variable for prmary part later...
			
			-- sets up vars, needs to be made better
			local playerCFrame = player.char.HumanoidRootPart.CFrame
			local targetCFrame
			local droneCFrame = drone.model.PrimaryPart.CFrame
			local hoverOffset = math.sin(time() + (drone.maxSpeed)*200)/3 
				
			if drone.mode == "following" then 
				
				targetCFrame =  playerCFrame + Vector3.new(drone.offset.X, 7 + hoverOffset, drone.offset.Z) 
				
			elseif drone.mode == "mining" then
				
				local targetPos

				if drone.destination.name == "crystal" then
					
					targetPos = drone.destination.location + Vector3.new(0,10,0)
					targetCFrame = CFrame.new(targetPos)
					
				end

				if drone.destination.name == "idle" then
					
					targetPos = drone.patch.mesh.Position + Vector3.new(drone.offset.X, 10, drone.offset.Z)
					targetCFrame = CFrame.new(targetPos)

				end
				
				if (targetPos - droneCFrame.Position).Magnitude <= 1  -- if deone is near to crystal
					
					and drone.destination.name == "crystal" 
					and drone.crystal then -- the and drone.crystal part is a bad solution
					
					if drone.beam.beamActive == false then
						
						drone.beam.beamActive = true
						MainModule.ShowBeam(drone.beam.beamObject, drone.crystal.mesh.Attachment)		
						drone.isMining = true

						
					end
					
					local healthPercentage = drone.crystal.health / drone.crystal.maxHealth
					local healthPeriod = drone.crystal.healthPeriod
					
				
					drone.crystal.mesh.Attachment.Position = Vector3.new(0,drone.crystal.mesh.Size.Y/2,0) -- this should be avoided by finding a way to scale models
					drone.beam.beamObject.MiningEffect.Position =  Vector3.new(0,drone.crystal.mesh.Size.Y/2,0) + (drone.crystal.mesh.Position)
					drone.beam.beamObject.MiningEffect.InnerMiningEffect.Position =  Vector3.new(0,drone.crystal.mesh.Size.Y/2,0) + (drone.crystal.mesh.Position)

					
					if drone.crystal.health > 10 then
						drone.crystal.health -= .3
					else 
						drone.crystal = nil -- remove later? idk if it work
					end

				end
			end
			
			-- below handles movement and rotation for client ---------------------------------------------------------------------------------------------------------------------------------------------
			
			local distance = (targetCFrame.Position - droneCFrame.Position).magnitude
			local moveSpeed = drone.speed
			local newPosition = droneCFrame.Position:Lerp(targetCFrame.Position,moveSpeed) -- where the cube wants to move
			local pointPos = Vector3.new(targetCFrame.Position.X, droneCFrame.Position.Y, targetCFrame.Position.Z) -- where cube needs to point
			local newCFrame
			
			if (newPosition - droneCFrame.Position).Magnitude < drone.maxSpeed then -- how fast does the cube want to move, is it too fast?
				
				local smoothedRotation = droneCFrame.Rotation:Lerp(player.char.HumanoidRootPart.CFrame.Rotation, 0.1)
				newCFrame = CFrame.new(newPosition) * smoothedRotation
				
			else
				
				local clampPosition = (targetCFrame.Position - droneCFrame.Position).Unit * drone.maxSpeed + droneCFrame.Position
				
				local smoothedRotation = droneCFrame.Rotation:Lerp(CFrame.lookAt(droneCFrame.Position, pointPos).Rotation, 0.1)
				newCFrame = CFrame.new(clampPosition) * smoothedRotation
		
			end
			
			drone.model:PivotTo(newCFrame)
			
		end
	end
end

local function performRaycast()
	local mouse = game.Players.LocalPlayer:GetMouse()

	local rayParams = RaycastParams.new()

	rayParams.FilterDescendantsInstances = {localPlayer.Character}

	local ray = workspace:Raycast(workspace.CurrentCamera.CFrame.Position, mouse.UnitRay.Direction * 300, rayParams)

	if ray then
		return {object = ray.Instance, Position = ray.Position}

	end	

end

game:GetService("RunService").Stepped:Connect(gameLoop)





remoteEvents.UpdatePlayerList.OnClientEvent:Connect(function(plr)
	
	local oldActive
	
	
	
	
	local newPlayerDict = playerDict[plr.id]
	
	newPlayerDict.player = plr.player
	newPlayerDict.droneDict = plr.droneDict
	
	for i, v in pairs(newPlayerDict.droneDict)do
	--	jim.Position = v.destination.location
	end
	newPlayerDict.char = plr.char
	newPlayerDict.ores = plr.ores



	

	
	
	playerDict[plr.id].player.PlayerGui.IngameGui.Frame.OreFrame.OreText.Text = plr.ores -- fix pls
	
	for i, v in pairs(plr.droneDict) do
		
		
		
		if playerDict[plr.id] then
			
			if v.isMining == false  then
				MainModule.HideBeam(v.beam.beamObject)
				v.beam.beamActive = false
			--	warn("hide")

			end
			--	v.beam.beamActive = false

			
		end
		
	end
	

	
	
	
end)

remoteEvents.SetupPlayerInfo.OnClientEvent:Connect(function(plr)
	playerDict[plr.id] = plr
end)






uis.InputBegan:Connect(function(input, isProcessed)
	if isProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputState == Enum.UserInputState.Begin then

		local raycastResult = performRaycast()

		if raycastResult.object.Parent == game.Workspace.Patches then
			
			for i, v in pairs(playerDict[localPlayer.UserId].droneDict) do
				remoteEvents.RequestDroneModeMining:FireServer(raycastResult.object.Name, v)

			end


		end
		--	changeDroneMode("travelingf", raycastResult.Position)




	end
	if input.KeyCode.Name == "G" then
		for i, v in pairs(playerDict[localPlayer.UserId].droneDict) do
			--remoteEvents.AskServerRaycast:FireServer()
		end
	end
end)


converter.ProximityPrompt.Triggered:Connect(function()
	local newCurrencyValue = remoteEvents.RequestCurrency:InvokeServer(localPlayer.UserId)
	print(newCurrencyValue)
	localPlayer.PlayerGui.IngameGui.Frame.CurrencyFrame.CurrencyLabel.CurrencyText.Text = newCurrencyValue -- fix pls
end)






--[[ names:


cascade

bitter

sussurus -- soft sound

redolent -- strongly reminicent

Eunoia -- pleasent mind


places: 

Querencia -- safe place



---]]