local UserInputService = game:GetService("UserInputService")

-- Function to handle the raycast result
local function handleRaycastResult(rayResult)
	if rayResult then
		local hitPart = rayResult.Instance
		local hitPosition = rayResult.Position
		print("Hit Position:", hitPosition)
		
		local cube1 = Instance.new("Part")
		cube1.Position = game.Workspace.DroneTest.Position
		cube1.Parent = workspace
		cube1.Anchored = true
		
		local cube2 = Instance.new("Part")
		cube2.Position = hitPosition
		cube2.Parent = workspace
		cube2.Anchored = true
		cube2.Size = Vector3.new(0.1,0.1,0.1)
		
		local attachment = Instance.new("Attachment")
		attachment.Parent = cube1
		
		local attachment2 = Instance.new("Attachment")
		attachment2.Parent = cube2
		
		local bem = game.ReplicatedStorage.MiningFX.Beampart1.Beam:Clone()
		local bem2 = game.ReplicatedStorage.MiningFX.Beampart1.OuterBeam:Clone()
		local miningEffect = game.ReplicatedStorage.MiningFX["Mining Particles"]:Clone()
		miningEffect.Parent = workspace 
		miningEffect.Position = cube2.Position + Vector3.new(0,0,0)
		bem.Parent = cube1
		bem2.Parent = cube1
		
		bem.Attachment0 = attachment
		bem.Attachment1 = attachment2
		bem2.Attachment0 = attachment
		bem2.Attachment1 = attachment2
		
		local amplitude = 0.1 -- Amplitude of the sine wave (maximum distance from the initial position)
		local frequency = 0.5 -- Frequency of the sine wave (number of oscillations per second)

		local time = 0 -- Initialize time

		while true do
			local deltaTime = wait(0.05) -- Adjust the wait time as desired for the smoothness of the motion

			time = time + deltaTime
			local Offset = amplitude * math.sin(2 * math.pi * frequency * time)

			bem2.Width0 = 0.6 + Offset
			bem2.Width1 = 0.6 + Offset
		end


	else
		print("Raycast hit nothing.")
	end
end

-- Function to perform the raycast
local function performRaycast()
	local mouse = game.Players.LocalPlayer:GetMouse()
	local ray = Ray.new(
		workspace.CurrentCamera.CFrame.p,
		(mouse.Hit.p - workspace.CurrentCamera.CFrame.p).unit * 300 -- Maximum distance of the raycast
	)
	local part, position = workspace:FindPartOnRay(ray, game.Players.LocalPlayer.Character, false, true)
	return {o = part, Position = position}
end
-- DO NOT EDIT
-- Listen for mouse click events
UserInputService.InputBegan:Connect(function(input, isProcessed)
	if isProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local raycastResult = performRaycast()
		handleRaycastResult(raycastResult)
	end
end)




