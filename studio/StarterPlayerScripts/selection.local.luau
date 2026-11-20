

local highlightPrefab = game.ReplicatedStorage.HighlightPrefab -- Reference to the Highlight prefab in Workspace (create this beforehand)
local highlightDuration = 1 -- Highlight duration in seconds

-- Function to create a new highlight object
local TweenService = game:GetService("TweenService")

-- Adjust the tween duration (in seconds) as per your preference.


local function createHighlight(hitPart)
	local highlight = highlightPrefab:Clone()
	highlight.Parent = hitPart
	local tweenDuration = 0.3
	-- Set the initial fill transparency to 1 (fully transparent)
	highlight.FillTransparency = 1

	-- Set the initial outline transparency to 1 (fully transparent)
	highlight.OutlineTransparency = 1

	-- Define the target fill transparency (fully opaque)
	local targetFillTransparency = 0.5

	-- Define the target outline transparency (fully opaque)
	local targetOutlineTransparency = 0.3

	-- Create a tween to smoothly change the fill transparency
	local fillTweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)
	local fillTween = TweenService:Create(highlight, fillTweenInfo, { FillTransparency = targetFillTransparency })

	-- Create a tween to smoothly change the outline transparency
	local outlineTweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)
	local outlineTween = TweenService:Create(highlight, outlineTweenInfo, { OutlineTransparency = targetOutlineTransparency })

	-- Play both tweens together
	fillTween:Play()
	outlineTween:Play()

	return highlight
end


-- Function to remove the highlight object
local function removeHighlight(highlight)
	local targetFillTransparency = 1

	-- Define the target outline transparency (fully transparent)
	local targetOutlineTransparency = 1

	-- Set the duration for the tweens (adjust this value to control the speed of disappearance)
	local tweenDuration = 1

	-- Create a tween to smoothly change the fill transparency
	local fillTweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)
	local fillTween = TweenService:Create(highlight, fillTweenInfo, { FillTransparency = targetFillTransparency })

	-- Create a tween to smoothly change the outline transparency
	local outlineTweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)
	local outlineTween = TweenService:Create(highlight, outlineTweenInfo, { OutlineTransparency = targetOutlineTransparency })
	
	local function destroyObjectAfterTweens()
		highlight:Destroy()
	end
	
	fillTween.Completed:Connect(destroyObjectAfterTweens)
	outlineTween.Completed:Connect(destroyObjectAfterTweens)


	-- Play both tweens together
	fillTween:Play()
	outlineTween:Play()
end

-- Function to handle the raycast hit
local function onRaycastHit(hitPart, hitPosition)
	if hitPart and hitPart:IsA("BasePart") then
		--local highlight = createHighlight(hitPart)
		wait(highlightDuration)
		--removeHighlight(highlight)
	end
end

-- Function to handle the raycast miss (nothing hit)
local function onRaycastMiss()
	print("Raycast missed!")
end

-- Raycast function
local function raycast()
	local mouse = game.Players.LocalPlayer:GetMouse()
	local ray = Ray.new(mouse.UnitRay.Origin, mouse.UnitRay.Direction * 300) -- Adjust the distance (300) as needed
	local hitPart, position = workspace:FindPartOnRay(ray, game.Players.LocalPlayer.Character, false, true)


	if hitPart then
		onRaycastHit(hitPart, position)
	else
		onRaycastMiss()
	end
end

-- Connect the raycast function to the MouseButton1Click event (you can change this to any other event)
game.Players.LocalPlayer:GetMouse().Button1Down:Connect(raycast)

