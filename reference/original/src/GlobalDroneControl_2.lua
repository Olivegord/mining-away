local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local patches = game.Workspace:WaitForChild("Patches")
local players = game:GetService("Players")

local remoteEvents = rs.RemoteEvents

local function getUnitVector(angle)
	local x = math.cos(math.rad(angle))
	local z = math.sin(math.rad(angle))

	return Vector3.new(x, 0, z) * 10
end

print("?")




local patchDict = {}

patchDict["rubyPatch"] = { -- needs a name component
	name = "rubyPatch",
	maxCrystals = 16,
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




local MainModule = require(rs.MainModule)


local playerDict = {}

local Player = {}
Player.__index = Player

function Player.new(playerInstance, team)
	local self = setmetatable({}, Player)
	self.player = playerInstance
	self.id = playerInstance.UserId
	
	self.char = playerInstance.Character or playerInstance.CharacterAdded:Wait()
	-- Other player variables can be added here

	
	self.droneDict = {}
	
	self.droneAmount = math.random(2,5)
	
	for i = 1, self.droneAmount do
		
		
		self.droneDict[i] = {
			model = rs.Drone:Clone(),
			
			speed = math.random(30, 30)/1000,
			maxSpeed = math.random(20,50)/100,
	
			
			offset = getUnitVector((360 / self.droneAmount) * i),

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
						
			
			idleRotation = Vector3.new(0,0,0),
			

			isMining = false,
			
			playerId = self.id
		}
		
		self.droneDict[i].beam = {
			beamObject = MainModule.CreateBeam(self.droneDict[i].model),
			beamActive = false,
		}
		self.droneDict[i].model.Parent = game.Workspace.PlayerDrones[self.player.Name]
		--self.droneDict[i].position = self.droneDict[i].model.PrimaryPart.Position
		self.droneDict[i].position = Vector3.new(50,0,0)
		--self.droneDict[i].model.Transparency = 1
	end
	
	self.ores = 0
	self.currency = 0
	self.maxOres = 200
	self.isFull = false
	
	

	return self
end










players.PlayerAdded:Connect(function(plr)

	
	
	local folder = Instance.new("Folder")
	folder.Name = plr.Name
	folder.Parent = workspace.PlayerDrones
	
	playerDict[plr.UserId] =  Player.new(plr, "red")
	task.wait(1)
	remoteEvents.SetupPlayerInfo:FireAllClients(playerDict[plr.UserId])
end)

players.PlayerRemoving:Connect(function(plr) 
	local folder = workspace.PlayerDrones:FindFirstChild(plr.Name)
	
	if folder then
		folder:Destroy()
	end
end)










local function changeDroneCrystal(drone,destName, crystal, patch)
	drone.mode = "mining"
	--warn("yu should be doing shtuf")
	drone.isMining = false
	drone.destination.name = destName

	drone.patch = patchDict[patch]

	
	if destName == "crystal" then
		drone.destination.location = crystal.mesh.Position
		drone.crystal = crystal
		crystal.canBeMined = false
		print("DRONE IS MINING")
	end

	if destName == "idle" then
		warn(patch.mesh)
		drone.destination.location = patchDict[patch].mesh.Position

	end
	
	remoteEvents.UpdatePlayerList:FireAllClients( playerDict[drone.playerId] )




	

end


local function changeDroneModeFollowing(drone)
	drone.mode = "following"
	drone.destination.name = "player"

	drone.isMining = false
	if drone.crystal then
		drone.crystal.canBeMined = true
	end


	
end


local function callDroneMine(droneValue, patch, method, player)
--	print(droneValue)

	local shortestDistance = math.huge
	local nearestCrystal
	local distance

	local count = 0

	local reason = "no reason foo"

	local kys = false -- replace with return now that system is better

	local patchChange = false
	


	if droneValue.destination.name == "crystal" and droneValue.patch.name == patch then
		-- checks to see if the drone is already mining do avoid calling it twice.
		warn("Still mining...")
		kys = true

		return

	else 

		if droneValue.patch.name ~= patch then
			patchChange = true

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
			--crystalValue.mesh.Color = Color3.new(1,1,1)
		elseif crystalValue.canBeMined == false then
			teste = "false"
			--crystalValue.mesh.Color = Color3.new(0,0,0)


		else

		end



		--crystalValue.mesh.BillboardGui.Frame.TextLabel.Text = teste


		-- Check if the crystal is available (not being mined by another drone)
		if crystalValue.canBeMined == true and crystalValue.health > 10 then
			count += 1

			--	crystalValue.mesh.Color = Color3.new(0,1,0)

			--crystalValue.mesh.Color = Color3.new(0,1,1)
			distance = (droneValue.position - crystalValue.mesh.Position).Magnitude

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
--			droneValue.model.Parent.BillboardGui.Frame.TextLabel.Text = "I CAN FLY"
			--droneValue.model.Color = Color3.new(0,1,1)
			--warn(nearestCrystal.canBeMined)

			changeDroneCrystal(droneValue, "crystal" ,nearestCrystal, patch)
		elseif patchChange == true and method == "player" then
			if nearestCrystal then

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


local jim = Instance.new("Part")
jim.Parent = game.Workspace
jim.Anchored = true

local test = false
warn(":HDHDHHDHDHD")
local fu = true
local function rotateAndMoveForwardsToPlayer()
	
	for k, player in pairs(playerDict) do
		local playerPos = player.char.HumanoidRootPart.Position
		local desiredRotation
		local targetPosition


		for k, v in pairs(player.droneDict) do

			
			
			if v.mode == "following" then -- change to seitch case latetr
				targetPosition = playerPos + Vector3.new(v.offset.X, 7, v.offset.Z)


			elseif v.mode == "mining" then
				if v.isMining == true then

				end

				if v.destination.name == "crystal" then

					targetPosition = v.destination.location + Vector3.new(0,10,0)
					--		v.model.Color = Color3.new(0,1,0)
					

					if not v.crystal then

					end

				end

				if v.destination.name == "idle" then
					
					targetPosition = v.patch.mesh.Position + Vector3.new(v.offset.X, 10, v.offset.Z)
					--	v.model.Color = Color3.new(1,1,0)

				end
				--jim.Position = targetPosition
				if (targetPosition - v.position).Magnitude <= 1 and v.destination.name == "crystal" and v.crystal   then-- the and v.crystal part is a bad solution
					v.isMining = true
					

					if v.crystal.health > 10 then
						v.crystal.health -= .5
						
						
						local healthPercentage = v.crystal.health / v.crystal.maxHealth
						local healthPeriod = v.crystal.healthPeriod
						
						if healthPercentage > (healthPeriod - .25) then
							v.crystal.mesh.Size = Vector3.new(healthPeriod,healthPeriod,healthPeriod) * v.crystal.maxHealth/25
							v.crystal.mesh.Color = Color3.new(  (healthPercentage / healthPeriod) - (1 - healthPeriod)/4, 0, 0)
						else
							v.crystal.healthPeriod -= .25
							


						end
						
						
						
						
						
						
					else -- crystal depleted
						player.ores += 20
						print(player.ores)
						fu = false
						local minedCrystal = v.crystal
						v.crystal = nil

						v.isMining = false
						v.destination.name = "idle"

						minedCrystal.mesh.Transparency = 1
						--		warn(playerDict[player.id])
						if player.ores >= player.maxOres then
							player.isFull = true
							player.ores = player.maxOres
							for k, v in pairs(player.droneDict) do
								changeDroneModeFollowing(v)
							end 
						end
						
						if player.isFull == false then
							callDroneMine(v ,minedCrystal.patch)

						end
						
						
						

						table.insert(patchDict[minedCrystal.patch].availableIDs, minedCrystal.id)		
						
						
						
						
						local remove = spawn(function()
							remoteEvents.UpdatePlayerList:FireAllClients( playerDict[player.id])

							-- v.crystal can change by the time the remove function is called, this fixes a bug
							--warn(v.crystal)

							


							

							--print( "amount: " .. #patchDict[minedCrystal.patch.name].availableIDs)

							
							
							wait(2)
							minedCrystal.mesh:Destroy()
							
							wait(6)

				--			warn(#patchDict[minedCrystal.patch].availableIDs)
							
							if #patchDict[minedCrystal.patch].availableIDs <= patchDict[minedCrystal.patch].maxCrystals then
								patchDict[minedCrystal.patch].crystalDict = MainModule.SpawnCrystals(patchDict[minedCrystal.patch], 1) -- this could be moved to the uda skipt?
								
								

							end
							
							wait(2.2)
							if player.isFull == false then
								for k, v in pairs(player.droneDict) do
									callDroneMine(v ,minedCrystal.patch)
								end
							end
							

						end)



						

					end


				else
					v.isMining = false -- this might be buggy
				end




				desiredRotation = CFrame.new(v.position, v.position + Vector3.new(math.random(0,360), 0, math.random(0,360)))
			end


			--jim.Position = v.position

			-- Rotate towards dest

			-- Move forwards based on the distance from the player

			local distance = (targetPosition - v.position).magnitude
			local moveSpeed = v.speed

			local newPosition = v.position:Lerp(targetPosition, moveSpeed) -- where the cube wants to move



			if (newPosition - v.position).Magnitude < v.maxSpeed then -- how fast does the cube want to move, is it too fast?
				v.position = newPosition -- if slow enough than it can move to new position
			else
				v.position += (newPosition - v.position).Unit * v.maxSpeed -- if too fast than speed is clamped to max!
			end



		end

	end
	
	


	--player.PlayerGui.IngameGui.Frame.Frame.TextLabel.Text = #patchDict.rubyPatch.availableIDs

	

end









patchDict.rubyPatch.crystalDict = MainModule.SpawnCrystals(patchDict.rubyPatch, patchDict.rubyPatch.maxCrystals)

patchDict.cobaltPatch.crystalDict = MainModule.SpawnCrystals(patchDict.cobaltPatch, patchDict.cobaltPatch.maxCrystals)






-- Connect the rotateAndMoveForwardsToPlayer function to the RenderStepped event
game:GetService("RunService").Heartbeat:Connect(rotateAndMoveForwardsToPlayer)



--[[ names:


cascade

bitter

sussurus -- soft sound

redolent -- strongly reminicent

Eunoia -- pleasent mind


places: 

Querencia -- safe place



---]]

remoteEvents.RequestDroneModeMining.OnServerEvent:Connect(function(player, patchName, drone)
	if playerDict[player.UserId].maxOres > playerDict[player.UserId].ores then 
		callDroneMine(playerDict[player.UserId].droneDict[drone.id], patchName, "player")
		remoteEvents.UpdatePlayerList:FireAllClients( playerDict[player.UserId])
		warn("droneminingcalled")
	else
		playerDict[player.UserId].isFull = true;
		warn("full ores, no mining")
	end
	
	
end)

remoteEvents.RequestCurrency.OnServerInvoke = function(player, playerId)
	if playerDict[playerId].ores > 0 then
		playerDict[playerId].currency += playerDict[playerId].ores
		playerDict[playerId].ores = 0
		playerDict[playerId].isFull = false
		remoteEvents.UpdatePlayerList:FireAllClients(playerDict[playerId])
		
	end
	
	return playerDict[playerId].currency
end