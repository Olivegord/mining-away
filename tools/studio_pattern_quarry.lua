-- Apply the selective patterns to the authored map after installing variants.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning())
local map=workspace.MiningAway.Map
local materials=game:GetService('MaterialService')
local herringbone=assert(materials:FindFirstChild('QuarryPattern_Herringbone'))
local checker=assert(materials:FindFirstChild('QuarryPattern_Checker'))
local count=0
local function finish(part,variant,color)
 assert(part:IsA('BasePart'))
 if not part.CustomPhysicalProperties then part.CustomPhysicalProperties=part.CurrentPhysicalProperties end
 part.Material=variant.BaseMaterial;part.MaterialVariant=variant.Name;part.Color=color;part.Reflectance=0
 count+=1
end
for _,name in ipairs({'NorthSouthWalk','EastWestWalk','UtilityWalk','ShopApron'}) do
 finish(map.DronerevolutionTerraces.MarketSquare[name],herringbone,Color3.fromRGB(190,205,240))
end
for _,name in ipairs({'Printer','PackStation','PrestigeStation'}) do
 finish(map.SimpleFlatTestMap[name..'Assembly'][name..'Pad'],checker,Color3.fromRGB(233,234,216))
end
assert(count==7)
return {patternedSurfaces=count,hubVariant=map.SimpleFlatTestMap.HubPad.MaterialVariant}
