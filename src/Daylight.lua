-- Clear, parts-built Roblox daylight. Preserve the captured sky and effects.
local Daylight = {}
function Daylight.apply()
 local lighting = game:GetService('Lighting')
 lighting.ClockTime = 13.5
 lighting.GeographicLatitude = 35
 lighting.Brightness = 2
 lighting.ExposureCompensation = 0
 lighting.Ambient = Color3.fromRGB(105,110,123)
 lighting.OutdoorAmbient = Color3.fromRGB(145,150,160)
 lighting.ColorShift_Top = Color3.fromRGB(0,0,0)
 lighting.ColorShift_Bottom = Color3.fromRGB(0,0,0)
 lighting.EnvironmentDiffuseScale = .65
 lighting.EnvironmentSpecularScale = .12
 lighting.GlobalShadows = true
 lighting.ShadowSoftness = .35
 lighting.FogColor = Color3.fromRGB(195,216,235)
 lighting.FogStart = 600
 lighting.FogEnd = 2400
 -- Some Studio versions restrict render-path writes; the other settings work
 -- independently and never require replacing the original sky.
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
   effect.Density = .12; effect.Offset = .1
   effect.Color = Color3.fromRGB(210,225,240)
   effect.Decay = Color3.fromRGB(150,171,195)
   effect.Glare = 0; effect.Haze = .4
  end
 end
end
return Daylight
