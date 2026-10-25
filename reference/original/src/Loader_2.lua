local logo = game.Players.LocalPlayer.PlayerGui:WaitForChild("ScreenGui").Frame.Logo
logo.Parent.Parent.Enabled = false
local mcircle1 = logo.Mediumcircle1
local mcircle2 = logo.Mediumcircle2
local scircle = logo.Smallcircle
local bcircle = logo
local sball = logo.Smallcircle.SBall2

local function rotateCircle(circle, rotationSpeed)
	local endRotation = circle.Rotation + 360 
	local tweenInfo = TweenInfo.new(rotationSpeed, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

	local tween = game:GetService("TweenService"):Create(circle, tweenInfo, { Rotation = endRotation })
	tween:Play()

	tween.Completed:Connect(function()
		circle.Rotation = 0 
		rotateCircle(circle, rotationSpeed) 
	end)
end

local function rotateCircleQuartic(circle, rotationSpeed)
	local endRotation = circle.Rotation + 360 
	local tweenInfo = TweenInfo.new(rotationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local tween = game:GetService("TweenService"):Create(circle, tweenInfo, { Rotation = endRotation })
	tween:Play()

	tween.Completed:Connect(function()
		circle.Rotation = 0 
		rotateCircle(circle, rotationSpeed) 
	end)
end

--[[
local easingTweenInfo = TweenInfo.new(2, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut)
local tween1 = game:GetService("TweenService"):Create(sball, easingTweenInfo, { Size = UDim2.new(0,35,0,35) })
local tween2 = game:GetService("TweenService"):Create(sball, easingTweenInfo, { Size = UDim2.new(1,0,0,35) })

tween2:Play()
tween2.Completed:Connect(function()
	tween1:Play()
end)

tween1.Completed:Connect(function()
	tween2:Play()
end)
--]]

rotateCircleQuartic(mcircle1, 7)
rotateCircleQuartic(mcircle2, 7)
rotateCircle(scircle, 11)
rotateCircle(bcircle, 5)



wait(5)



local TweenService = game:GetService("TweenService")

local guiObject = game.Players.LocalPlayer.PlayerGui.ScreenGui.Frame -- Replace "ScreenGui" and "Frame" with the actual names of your ScreenGui and Frame objects.

local properties = {
	BackgroundTransparency = 1 -- This is the final value of the BackgroundTransparency property.
}

local propertiesTwo = {
	Position = UDim2.new(0.5, 0, -1, 0)
}

local tweenInfo = TweenInfo.new(
	1, -- Duration of the tween in seconds
	Enum.EasingStyle.Linear, -- Easing style of the tween (Linear means constant speed)
	Enum.EasingDirection.Out -- Easing direction of the tween (Out means starting fast and slowing down)
)

local secondTweenInfo = TweenInfo.new(
	1.5,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut
)

local tween = TweenService:Create(guiObject, tweenInfo, properties)
local tween2 = TweenService:Create(guiObject.Logo, secondTweenInfo, propertiesTwo)
local tween3 = TweenService:Create(guiObject.Logo.Smallcircle, tweenInfo, properties)

tween3:Play()
tween2:Play()
tween:Play()


