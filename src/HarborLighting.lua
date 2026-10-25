-- Exact Lighting settings captured read-only from Alabaster Harbor, place 11490608035.
local H={}
H.SourcePlaceId=11490608035
H.settings={
 ["Ambient"]=Color3.new(1,0.9294118285179138,0.7529412508010864),
 ["Brightness"]=2,
 ["ClockTime"]=7,
 ["ColorShift_Bottom"]=Color3.new(0,0,0),
 ["ColorShift_Top"]=Color3.new(0.4274509847164154,0.32156863808631897,0),
 ["EnvironmentDiffuseScale"]=0.699999988079071,
 ["EnvironmentSpecularScale"]=0.6290000081062317,
 ["ExposureCompensation"]=0.30000001192092896,
 ["FogColor"]=Color3.new(0.7960785031318665,0.7725490927696228,0.7176470756530762),
 ["FogEnd"]=1000000,
 ["FogStart"]=0,
 ["GeographicLatitude"]=360,
 ["GlobalShadows"]=true,
 ["LightingStyle"]=Enum.LightingStyle.Realistic,
 ["OutdoorAmbient"]=Color3.new(0.5764706134796143,0.4274509847164154,0),
 ["Outlines"]=false,
 ["PrioritizeLightingQuality"]=true,
 ["ShadowColor"]=Color3.new(0.699999988079071,0.699999988079071,0.7200000286102295),
 ["ShadowSoftness"]=0.6000000238418579,
 ["TimeOfDay"]="07:00:00",
}
function H.apply()
 local lighting=game:GetService('Lighting')
 local template=game:GetService('ServerStorage'):FindFirstChild('AlabasterHarborLighting')
 assert(template,'Missing native Alabaster Harbor Lighting export in build')
 -- The template includes every original child, including the inactive lowPolyUI.
 -- Cloning preserves the authored sky/effects and all nested property values.
 for _,child in ipairs(lighting:GetChildren()) do child:Destroy() end
 for _,child in ipairs(template:GetChildren()) do child:Clone().Parent=lighting end
 for property,value in pairs(H.settings) do
  -- LightingStyle/PrioritizeLightingQuality are persisted by the builder too;
  -- some engine versions restrict writing these rendering options at runtime.
  pcall(function() lighting[property]=value end)
 end
 lighting:SetAttribute('CopiedFromPlaceId',H.SourcePlaceId)
end
return H
