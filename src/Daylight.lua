-- Clear quarry daylight. Native sky/effects remain preserved in the file;
-- the mismatched sunset sky is archived only in the running server.
local Daylight = {}
function Daylight.apply()
 local authored = workspace:FindFirstChild('MiningAway')
 local lighting = game:GetService('Lighting')
 if authored and authored:GetAttribute('DronerevolutionMapVersion') then
  -- Keep the authored dawn, sky and grading. The sky's zero-size sun disk
  -- hid the light source even though its SunRays effect was already enabled.
  local sky=lighting:FindFirstChildOfClass('Sky')
  if sky then sky.SunAngularSize=8 end
  local rays=lighting:FindFirstChildOfClass('SunRaysEffect')
  if rays then rays.Intensity=.17;rays.Spread=.85;rays.Enabled=true end
  return
 end
 local storage=game:GetService('ServerStorage')
 local archive=storage:FindFirstChild('OriginalQuarrySky')
 if not archive then archive=Instance.new('Folder');archive.Name='OriginalQuarrySky';archive.Parent=storage end
 for _,child in ipairs(lighting:GetChildren()) do
  if child:IsA('Sky') and child.Name~='QuarryDaySky' then child.Parent=archive end
 end
 if not lighting:FindFirstChild('QuarryDaySky') then
  -- Engine-bundled blue/cloud sky: no external permission or texture download.
  local sky=Instance.new('Sky');sky.Name='QuarryDaySky';sky.StarCount=0
  sky.SunAngularSize=11;sky.MoonAngularSize=0;sky.Parent=lighting
 end
 if not lighting:FindFirstChildOfClass('Atmosphere') then
  local atmosphere=Instance.new('Atmosphere');atmosphere.Name='QuarryAir';atmosphere.Parent=lighting
 end
 lighting.ClockTime = 14
 lighting.GeographicLatitude = 35
 lighting.Brightness = 2
 lighting.ExposureCompensation = 0
 lighting.Ambient = Color3.fromRGB(112,122,132)
 lighting.OutdoorAmbient = Color3.fromRGB(153,163,167)
 lighting.ColorShift_Top = Color3.fromRGB(0,0,0)
 lighting.ColorShift_Bottom = Color3.fromRGB(0,0,0)
 lighting.EnvironmentDiffuseScale = .65
 lighting.EnvironmentSpecularScale = .12
 lighting.GlobalShadows = true
 lighting.ShadowSoftness = .35
 lighting.FogColor = Color3.fromRGB(185,217,234)
 lighting.FogStart = 600
 lighting.FogEnd = 2400
 -- Some Studio versions restrict render-path writes; the remaining settings
 -- still apply independently.
 pcall(function() lighting.LightingStyle = Enum.LightingStyle.Soft end)
 for _,effect in ipairs(lighting:GetChildren()) do
  if effect:IsA('BloomEffect') or effect:IsA('DepthOfFieldEffect')
   or effect:IsA('SunRaysEffect') or effect:IsA('BlurEffect') then
   effect.Enabled = false
  elseif effect:IsA('ColorCorrectionEffect') then
   effect.Enabled = true
   effect.Brightness = 0; effect.Contrast = .03; effect.Saturation = .02
   effect.TintColor = Color3.new(1,1,1)
  elseif effect:IsA('Atmosphere') then
   effect.Density = .19; effect.Offset = .18
   effect.Color = Color3.fromRGB(202,225,238)
   effect.Decay = Color3.fromRGB(129,171,187)
   effect.Glare = 0; effect.Haze = .6
  end
 end
end
return Daylight
