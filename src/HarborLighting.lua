-- Retains the original stored sky reference; daytime values are tuned for Mining Away.
local H={}
H.SourcePlaceId=11490608035
H.settings={
 ["Ambient"]=Color3.fromRGB(105,111,123),
 ["Brightness"]=2,
 ["ClockTime"]=14,
 ["ColorShift_Bottom"]=Color3.new(0,0,0),
 ["ColorShift_Top"]=Color3.new(0,0,0),
 ["EnvironmentDiffuseScale"]=0.35,
 ["EnvironmentSpecularScale"]=0.15,
 ["ExposureCompensation"]=0,
 ["FogColor"]=Color3.new(0.7960785031318665,0.7725490927696228,0.7176470756530762),
 ["FogEnd"]=1000000,
 ["FogStart"]=0,
 ["GeographicLatitude"]=360,
 ["GlobalShadows"]=true,
 ["LightingStyle"]=Enum.LightingStyle.Realistic,
 ["OutdoorAmbient"]=Color3.fromRGB(134,142,154),
 ["Outlines"]=false,
 ["PrioritizeLightingQuality"]=true,
 ["ShadowColor"]=Color3.new(0.699999988079071,0.699999988079071,0.7200000286102295),
 ["ShadowSoftness"]=0.6000000238418579,
 ["TimeOfDay"]="14:00:00",
}
function H.apply()
 local lighting=game:GetService('Lighting')
 local template=game:GetService('ServerStorage'):FindFirstChild('AlabasterHarborLighting')
 assert(template,'Missing native Alabaster Harbor Lighting export in build')
 -- Keep the authored sky and every template object, but disable cloned
 -- post effects: the stored originals are never modified.
 for _,child in ipairs(lighting:GetChildren()) do child:Destroy() end
 for _,child in ipairs(template:GetChildren()) do
  local copy=child:Clone()
  if copy:IsA("PostEffect") then copy.Enabled=false end
  for _,nested in ipairs(copy:GetDescendants()) do
   if nested:IsA("PostEffect") then nested.Enabled=false end
  end
  copy.Parent=lighting
 end
 for property,value in pairs(H.settings) do
  -- LightingStyle/PrioritizeLightingQuality are persisted by the builder too;
  -- some engine versions restrict writing these rendering options at runtime.
  pcall(function() lighting[property]=value end)
 end
 lighting:SetAttribute('CopiedFromPlaceId',H.SourcePlaceId)
end
return H
