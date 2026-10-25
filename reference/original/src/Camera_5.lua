
local zoom = 30
local FieldOfView = 7
local zoomSpeed = 10
local rotationSpeedMultiplier = 0.2 -- Adjust this value to control the rotation speed sensitivity
local UserInputService = game:GetService("UserInputService")

--//Do not edit unless you know what you're doing//--
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local humanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = game.Workspace.CurrentCamera
Camera.CameraType = Enum.CameraType.Scriptable
local RunService = game:GetService("RunService")

local lastMousePos = UserInputService:GetMouseLocation()
local angle = 0

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = game.Workspace.CurrentCamera -- Assuming the camera is a child of the Workspace
local Character = game.Players.LocalPlayer.Character
local humanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")

local zoom = 10 -- Adjust this value to control the camera distance from the character
local angle = 0
local isRightClicking = false
local lastMousePos = Vector2.new()

UserInputService.InputBegan:Connect(function(input, isProcessed)
	if not isProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRightClicking = true
		lastMousePos = UserInputService:GetMouseLocation()
	end
end)

UserInputService.InputEnded:Connect(function(input, isProcessed)
	if not isProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRightClicking = false
	end
end)

RunService.RenderStepped:Connect(function()
	Camera.FieldOfView = FieldOfView
	if Character and humanoidRootPart then
		-- Camera follow logic
		local offset = Vector3.new(zoom * math.cos(math.rad(angle)), zoom / 1.5, zoom * math.sin(math.rad(angle)))
		Camera.CFrame = CFrame.new(humanoidRootPart.Position + offset, humanoidRootPart.Position)

		-- Camera rotation logic (only when right-clicking)
		if isRightClicking then
			local currentMousePos = UserInputService:GetMouseLocation()
			local mouseDelta = currentMousePos - lastMousePos
			local mousespeed = mouseDelta / 50

			angle = angle + mousespeed.X

			lastMousePos = currentMousePos
		end
	end
end)

UserInputService.InputChanged:Connect(function(input, isProcessed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not isProcessed then
		zoom = zoom - input.Position.Z * zoomSpeed
	end
end)
