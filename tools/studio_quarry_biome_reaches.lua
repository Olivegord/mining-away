-- Extend the authored fields with connected ground and a longer silhouette taper.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local root = workspace.MiningAway
local map = root.Map
assert(map:FindFirstChild("QuarryBlockRim"), "Missing rectangular rim")
assert(not map:FindFirstChild("QuarryBiomeReaches"), "Reconcile the existing biome reaches")

local materials = game:GetService("MaterialService")
local v, rgb = Vector3.new, Color3.fromRGB
local grass = materials.QuarryPhoto_Grass
local loam = materials.QuarryBlend_RubyLoam
local slate = materials.QuarryPhoto_Slate
local chalk = materials.QuarryBiome_Chalk
local shale = materials.QuarryBiome_Shale
local wetMoss = materials.QuarryAccent_LushGrass

local function container(className, name, parent)
    local instance = Instance.new(className)
    instance.Name = name
    instance.Parent = parent
    return instance
end
local pass = container("Folder", "QuarryBiomeReaches", nil)

local function part(parent, name, at, size, variant, color, yaw, roll, solid)
    local block = Instance.new("Part")
    block.Name = name
    block.Size = size
    block.CFrame = CFrame.new(at) * CFrame.Angles(0, yaw or 0, roll or 0)
    block.Color = color
    block.Material = variant.BaseMaterial
    block.MaterialVariant = variant.Name
    block.Anchored = true
    block.CanCollide = solid == true
    block.CanQuery = solid == true
    block.CanTouch = false
    block.CastShadow = solid == true or size.Y > 5
    block.TopSurface = Enum.SurfaceType.Smooth
    block.BottomSurface = Enum.SurfaceType.Smooth
    block.Parent = parent
end

-- Each table is one reach from the established biome to its outer edge.
-- Rows give x, z, surface height, width, depth, and silhouette count.
-- Tighter spacing and the largest silhouettes are reserved for the first rows.
local specs = {
    {name = "Quartz", stone = slate, top = grass, ground = rgb(138, 188, 103), edge = rgb(182, 192, 122),
        rock = rgb(97, 125, 120), reaches = {{
            {-57, 144, 3.78, 32, 26, 4}, {-48, 161, 3.82, 35, 32, 3},
            {-35, 178, 3.72, 36, 31, 2}, {-24, 195, 3.62, 29, 27, 1}, {-15, 209, 3.50, 24, 23, 1},
        }}},
    {name = "Impact", stone = slate, top = grass, ground = rgb(192, 175, 113), edge = rgb(147, 179, 118),
        rock = rgb(124, 119, 108), reaches = {{
            {122, 130, 3.80, 42, 30, 4}, {145, 114, 3.70, 37, 30, 3},
            {165, 97, 3.60, 36, 29, 2}, {182, 82, 3.55, 30, 26, 1}, {193, 69, 3.50, 25, 22, 1},
        }}},
    {name = "Ruby", stone = shale, top = loam, ground = rgb(217, 112, 88), edge = rgb(142, 161, 120),
        rock = rgb(118, 110, 128), reaches = {{
            {-163, -46, 19.68, 41, 30, 4}, {-167, -66, 19.90, 45, 32, 4},
            {-163, -86, 20.34, 39, 30, 3}, {-154, -104, 20.86, 36, 29, 2}, {-142, -119, 21.43, 32, 24, 1},
        }}},
    {name = "Violet", stone = shale, top = grass, ground = rgb(152, 171, 143), edge = rgb(131, 160, 129),
        rock = rgb(142, 132, 165), reaches = {{
            {-126, -158, 37.70, 37, 33, 4}, {-145, -150, 37.47, 36, 33, 3},
            {-158, -134, 37.03, 35, 30, 3}, {-171, -119, 36.40, 33, 28, 2}, {-179, -104, 35.74, 28, 23, 1},
        }}},
    {name = "Emerald", stone = chalk, top = grass, ground = rgb(163, 205, 147), edge = rgb(133, 181, 146),
        rock = rgb(201, 219, 209), reaches = {{
            {109, -164, 41.88, 35, 31, 4}, {130, -170, 41.98, 39, 34, 4},
            {153, -171, 42.20, 40, 32, 3}, {178, -166, 42.18, 44, 34, 2}, {202, -162, 41.85, 41, 29, 1},
        }}},
    {name = "Cobalt", stone = shale, top = grass, ground = rgb(128, 177, 167), edge = rgb(153, 183, 134),
        rock = rgb(119, 146, 162), reaches = {{
            {201, -59, 20.58, 44, 27, 5}, {217, -69, 20.72, 41, 29, 4},
            {233, -79, 21.00, 37, 29, 3}, {247, -89, 21.26, 30, 24, 2}, {257, -99, 21.42, 22, 22, 1},
        }, {
            {190, 54, 19.69, 44, 30, 5}, {175, 68, 18.95, 41, 30, 4},
            {157, 81, 18.24, 38, 28, 3}, {139, 92, 17.55, 34, 25, 2}, {125, 99, 16.94, 27, 21, 1},
        }}},
}

local depth = map.QuarryDepthPass
local caps = depth.CobaltForestExtension.Canopy
local broadleaf = map.DronerevolutionTerraces.AssetScenery.QuartzScenery["01_Tree1"]
local evergreen = map.DronerevolutionTerraces.AssetScenery.QuartzScenery["03_Tree2"]
local function copySilhouette(parent, template, at, desiredHeight, turn)
    local silhouette = container("Model", "Signature", nil)
    template:Clone().Parent = silhouette
    -- The first part of a mushroom is a cylinder laid along its local X axis.
    -- An explicit upright pivot preserves the source orientation on rotation.
    local initialBox = silhouette:GetBoundingBox()
    silhouette.WorldPivot = CFrame.new(initialBox.Position)
    silhouette:ScaleTo(desiredHeight / silhouette:GetExtentsSize().Y)
    silhouette:PivotTo(CFrame.Angles(0, turn, 0))
    local rim = silhouette:FindFirstChild("CreamCapRim", true)
    assert(not rim or rim.CFrame.RightVector.Y > .95, "Mushroom cap lost its upright orientation")
    local box, size = silhouette:GetBoundingBox()
    silhouette:PivotTo(silhouette:GetPivot() + at - box.Position + v(0, size.Y / 2 - .18, 0))
    for _, block in ipairs(silhouette:GetDescendants()) do
        if block:IsA("BasePart") then
            block.Anchored = true
            block.CanCollide = false
            block.CanQuery = false
            block.CanTouch = false
            block.CastShadow = desiredHeight >= 20 and block.Size.Magnitude > 4
        end
    end
    silhouette.Parent = parent
end

local function rockSilhouette(parent, spec, at, scale, turn, index)
    local group = container("Model", "Signature", parent)
    local color = spec.rock
    if spec.name == "Ruby" then
        for i, proportion in ipairs({.73, 1, .55}) do
            local h = scale * proportion
            part(group, "BasaltFin", at + v((i - 2) * scale * .22, h * .5 - .35, (i - 2) * scale * .08),
                v(scale * .23, h, scale * .32), shale, color:Lerp(rgb(76, 85, 106), i * .08),
                turn + i * .1, (i - 2) * .065, true)
        end
        part(group, "OxideSeam", at + v(0, scale * .13, 0), v(scale * .69, scale * .12, scale * .43),
            loam, rgb(194, 106, 87), turn, 0, false)
    elseif spec.name == "Violet" then
        for i, width in ipairs({1, .84, .63}) do
            part(group, "SplitSlateLayer", at + v((i - 2) * scale * .095, scale * (.08 + (i - 1) * .155), 0),
                v(scale * width, scale * .17, scale * (.68 - i * .095)), shale,
                color:Lerp(rgb(196, 176, 202), i * .10), turn + i * .04, 0, true)
        end
    elseif spec.name == "Emerald" then
        for i, height in ipairs({.61, 1, .76}) do
            local h = scale * height
            local foot = at + v((i - 2) * scale * .25, 0, (i - 2) * scale * .10)
            part(group, "ChalkTooth", foot + v(0, h * .5 - .24, 0), v(scale * .31, h, scale * .39),
                chalk, color:Lerp(rgb(246, 245, 222), i * .1), turn, 0, true)
            if i == 2 or (i == 3 and index % 2 == 0) then
                part(group, "GrassCrown", foot + v(0, h - .06, 0), v(scale * .33, .45, scale * .41),
                    wetMoss, spec.ground, turn, 0, true)
            end
        end
    else
        for i, angle in ipairs({-.28, .37, .16}) do
            local size = v(scale * (.35 + i * .07), scale * (.44 - i * .08), scale * .32)
            part(group, "ImpactShard", at + v((i - 2) * scale * .33, size.Y * .39, (i % 2) * scale * .20),
                size, slate, color:Lerp(rgb(169, 136, 104), i * .09), turn + angle, angle, true)
        end
    end
end

local report = {}
for _, spec in ipairs(specs) do
    local biome = container("Folder", spec.name, pass)
    local shelves, count = 0, 0
    local length = 0
    for wing, reach in ipairs(spec.reaches) do
        local start, tip = reach[1], reach[#reach]
        local path = v(tip[1] - start[1], 0, tip[2] - start[2])
        length = math.max(length, path.Magnitude)
        local flank = path.Unit:Cross(Vector3.yAxis)
        for step, row in ipairs(reach) do
            local x, z, y, width, depthSize, signatures = table.unpack(row)
            local t = (step - 1) / (#reach - 1)
            local deck = container("Folder", ("Shelf%d_%d"):format(wing, step), biome)
            local tint = spec.ground:Lerp(spec.edge, t)
            local stoneTint = spec.rock:Lerp(rgb(109, 134, 131), t * .33)
            local topMaterial = t >= .75 and grass or spec.top
            local at = v(x, y, z)
            local h = 14 - t * 6
            part(deck, "TerraceStone", at - v(0, h / 2 + .42, 0), v(width, h, depthSize),
                spec.stone, stoneTint, 0, 0, true)
            part(deck, "TerraceSurface", at - v(0, .34, 0), v(width + .1, .68, depthSize + .1),
                topMaterial, tint, 0, 0, true)
            -- One offset, lower bench gives the contiguous rim a stepped edge.
            local lip = flank * (math.min(width, depthSize) * (step % 2 == 0 and .33 or -.33))
            local lowAt = at + lip - v(0, .66, 0)
            part(deck, "LowerStoneBench", lowAt - v(0, h * .29 + .33, 0),
                v(width * .77, h * .58, depthSize * .76), spec.stone, stoneTint, 0, 0, true)
            part(deck, "LowerGrassBench", lowAt - v(0, .22, 0), v(width * .78, .44, depthSize * .77),
                topMaterial, tint:Lerp(spec.edge, .18), 0, 0, true)
            shelves += 1

            for i = 1, signatures do
                local side = (i - (signatures + 1) / 2) / math.max(1, signatures - 1)
                local lateral = flank * side * math.min(width, depthSize) * .71
                local fore = path.Unit * ((i % 2 == 0 and -.24 or .17) * math.min(width, depthSize))
                local base = at + lateral + fore
                local variation = .83 + ((i + step) % 4) * .085
                local size = (1 - t * .78) * variation
                local yaw = i * .73 + step * .51
                if spec.name == "Cobalt" then
                    local canopyHeight = i == 1 or (step == 1 and i == signatures)
                    copySilhouette(deck, i % 3 == 0 and caps.Canopy05 or caps.Canopy14,
                        base, (canopyHeight and 31 or 14) * size, yaw)
                elseif spec.name == "Quartz" then
                    copySilhouette(deck, i % 2 == 0 and broadleaf or evergreen, base, 29 * size, yaw)
                else
                    local maxSize = ({Ruby = 21, Violet = 19, Emerald = 23, Impact = 17})[spec.name]
                    rockSilhouette(deck, spec, base, maxSize * size, yaw, i)
                end
                count += 1
            end
        end
    end
    report[spec.name] = {shelves = shelves, signatures = count, centerline = math.floor(length)}
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {pass}
local probes = 0
local function clear(partToProtect, xs, zs)
    for _, x in ipairs(xs) do
        for _, z in ipairs(zs) do
            local position = partToProtect.CFrame:PointToWorldSpace(v(
                x * partToProtect.Size.X, partToProtect.Size.Y / 2, z * partToProtect.Size.Z))
            local hit = workspace:Raycast(position + v(0, 130, 0), v(0, -129.8, 0), params)
            assert(not hit, ("Biome reach obstructs %s with %s"):format(
                partToProtect:GetFullName(), hit and hit.Instance:GetFullName() or ""))
            probes += 1
        end
    end
end
pass.Parent = map
local ok, result = pcall(function()
    for _, field in ipairs(root.Fields:GetChildren()) do
        local bed = field:FindFirstChild("Field")
        if bed then clear(bed, {-.48, -.24, 0, .24, .48}, {-.48, -.24, 0, .24, .48}) end
    end
    for _, route in ipairs(map.DronerevolutionTerraces.WalkableRoutes:GetChildren()) do
        if route:IsA("BasePart") and not route.Name:find("Curb") then
            clear(route, {-.44, 0, .44}, {-.47, -.24, 0, .24, .47})
        end
    end
    for _, route in ipairs(map.EmeraldChalkLagoon:GetDescendants()) do
        if route.Name == "LagoonCauseway" then clear(route, {-.42, 0, .42}, {-.40, 0, .40}) end
    end
    local serialization = game:GetService("SerializationService")
    local encoding = game:GetService("EncodingService")
    local bytes = serialization:SerializeInstancesAsync({pass})
    return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(bytes, Enum.CompressionAlgorithm.Zstd)))
end)
if not ok then
    pass:Destroy()
    error(result)
end
shared.QuarryBiomeReachesSnapshot = result
return {biomes = report, probes = probes, instances = #pass:GetDescendants() + 1, exportBytes = #result}
