-- Run in the reconciled DRONEREVOLUTION Edit document. This updates native
-- finishes in place; the authored map, physics and seven Sources stay intact.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, 'Wrong shared place')
assert(not game:GetService('RunService'):IsRunning(), 'Stop Play before editing quarry materials')
local root = assert(workspace:FindFirstChild('MiningAway'))
assert(root:GetAttribute('QuarrySceneryAuthored'), 'Expected the authored quarry')
local fields = assert(root:FindFirstChild('Fields'))
local materials = game:GetService('MaterialService')
local dry = 'rbxassetid://78519593640803'
local aggregate = '102016069607159'
local aggregateScale = 17
local organic = Enum.MaterialPattern.Organic
local regular = Enum.MaterialPattern.Regular

-- Expected asset, replacement asset, studs per tile, and mapping method.
local finishes = {
 QuarryPhoto_Grass = {'136005318797247', '134439792116456', 12, organic},
 QuarryPhoto_LeafyGrass = {'136005318797247', '134439792116456', 10, organic},
 QuarryPhoto_Pebble = {'83637161982243', aggregate, aggregateScale, regular},
 QuarryPhoto_Sandstone = {'110682071054939', '85691036287394', 29, organic},
 QuarryPhoto_Rock = {'102819978839821', '140053828439773', 17, organic},
 QuarryPhoto_Slate = {'102819978839821', '140053828439773', 19, organic},
 QuarryPhoto_Pavement = {'104656144918864', '129610805568567', 16, regular},
 QuarryFoliage_Canopy = {'87224951749815', '87224951749815', 6, organic},
 QuarryFoliage_Evergreen = {'88408188951983', '88408188951983', 5.5, organic},
 QuarryBiome_Crimson = {'100289458480761', '100289458480761', 11, organic},
 QuarryOre_Polished = {'101826947844494', '84604323769040', 4.8, regular},
}
local rgb = Color3.fromRGB
local beds = {
 Quartz = {'QuarryPhoto_Pebble', 'QuarryPhoto_Pebble', rgb(232,221,207)},
 ImpactTest = {'QuarryPhoto_Pebble', 'QuarryPhoto_Pebble', rgb(234,224,213)},
 Violet = {'QuarryPhoto_Pebble', 'QuarryPhoto_Pebble', rgb(224,210,223)},
 Ruby = {'QuarryBiome_Shale', 'QuarryField_Aggregate', rgb(211,205,203)},
 Cobalt = {'QuarryBiome_Shale', 'QuarryField_Aggregate', rgb(197,207,222)},
}
local newVariantName = 'QuarryField_Aggregate'
assert(not materials:FindFirstChild(newVariantName), 'Reconcile existing field finish first')

local variants, fieldParts, assetIds, unique = {}, {}, {}, {}
for name, spec in pairs(finishes) do
 local variant = assert(materials:FindFirstChild(name), name)
 assert(variant:IsA('MaterialVariant') and variant.ColorMap == 'rbxassetid://' .. spec[1],
  'Material changed since the v42 baseline: ' .. name)
 variants[name] = variant
 local id = 'rbxassetid://' .. spec[2]
 if not unique[id] and spec[1] ~= spec[2] then
  table.insert(assetIds, id)
  unique[id] = true
 end
end
for name, bed in pairs(beds) do
 local part = assert(assert(fields:FindFirstChild(name), name):FindFirstChild('Field'), name)
 assert(part:IsA('BasePart') and part.MaterialVariant == bed[1], 'Field finish changed: ' .. name)
 local target = bed[2] == newVariantName and materials.QuarryBiome_Shale or variants[bed[2]]
 assert(target.BaseMaterial == part.Material, 'Field base material would change: ' .. name)
 fieldParts[name] = part
end

local loaded, previews = {}, {}
for _, id in ipairs(assetIds) do
 local decal = Instance.new('Decal')
 decal.Texture = id
 table.insert(previews, decal)
end
game:GetService('ContentProvider'):PreloadAsync(previews, function(id, status)
 loaded[id] = status.Name
end)
for _, decal in ipairs(previews) do decal:Destroy() end
for _, id in ipairs(assetIds) do assert(loaded[id] == 'Success', 'Could not preload ' .. id) end

for name, spec in pairs(finishes) do
 local variant = variants[name]
 variant.ColorMap = 'rbxassetid://' .. spec[2]
 variant.StudsPerTile = spec[3]
 variant.MaterialPattern = spec[4]
end

local fieldFinish = materials.QuarryBiome_Shale:Clone()
fieldFinish.Name = newVariantName
fieldFinish.ColorMap = 'rbxassetid://' .. aggregate
fieldFinish.StudsPerTile = aggregateScale
fieldFinish.MaterialPattern = regular
fieldFinish.RoughnessMap = dry
fieldFinish.Parent = materials
for name, part in pairs(fieldParts) do
 local bed = beds[name]
 part.MaterialVariant = bed[2]
 part.Color = bed[3]
end
return {loaded = loaded, revisedVariants = 11, addedFieldVariant = newVariantName, revisedFields = 5}
