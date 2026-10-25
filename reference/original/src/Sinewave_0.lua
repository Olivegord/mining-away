local amplitude = 0.1 -- Amplitude of the sine wave (maximum distance from the initial position)
local frequency = 0.5 -- Frequency of the sine wave (number of oscillations per second)

local time = 0 -- Initialize time
--[[
while true do
	local deltaTime = wait(0.05) -- Adjust the wait time as desired for the smoothness of the motion

	time = time + deltaTime
	local Offset = amplitude * math.sin(2 * math.pi * frequency * time)
	
	script.Parent.OuterBeam.Width0 = 0.6 + Offset
	script.Parent.OuterBeam.Width1 = 0.6 + Offset
end
--]]
