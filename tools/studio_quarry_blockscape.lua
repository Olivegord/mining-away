-- Stage a sparse block quarry in the existing shared Edit document.
-- The first run exports the change without parenting anything. Apply only after
-- the native saver confirms the same archive plan against the canonical file.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing")
local root = workspace.MiningAway
local map = root.Map
local storage = game:GetService("ServerStorage")
local terraces = map.DronerevolutionTerraces
assert(root:GetAttribute("QuarrySceneryAuthored"))
assert(not map:FindFirstChild("QuarryBlockscape") and not storage:FindFirstChild("QuarryBlockscapeArchive"))
assert(not shared.QuarryBlockscape, "Clear the previous staged change")

local v, rgb = Vector3.new, Color3.fromRGB
local materials = game:GetService("MaterialService")
local function folder(name, parent)
    local result = Instance.new("Folder")
    result.Name, result.Parent = name, parent
    return result
end

local scenery = folder("QuarryBlockscape")
local archive = folder("QuarryBlockscapeArchive")
local terrain = folder("Steps", scenery)
local scatter = folder("Scatter", scenery)
local moves, handles = {}, {}
local archived = {}
local archivedParts = 0
local function xyz(point)
    return {point.X, point.Y, point.Z}
end

local function store(item, landform)
    local partCount = 0
    local descendants = item:GetDescendants()
    local contents = table.clone(descendants)
    table.insert(contents, item)
    for _, child in ipairs(contents) do
        assert(child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart")
            or child:IsA("SpecialMesh") or child:IsA("PointLight") or child:IsA("Weld"), "Protected instance " .. child:GetFullName())
        if child:IsA("Weld") then
            for _, part in {child.Part0 or item, child.Part1 or item} do
                assert(part == item or part:IsDescendantOf(item), "Weld crosses the archive boundary")
            end
        end
        if child:IsA("BasePart") then
            assert(child.Anchored and (landform or not child.CanCollide), child:GetFullName())
            partCount += 1
        end
    end
    local move = {
        path = item:GetFullName(), class = item.ClassName,
        descendants = #descendants, parts = partCount,
    }
    if item:IsA("BasePart") then
        move.anchor = xyz(item.Position)
    elseif item:IsA("Model") then
        local anchor = item:FindFirstChildWhichIsA("BasePart", true)
        if anchor and anchor.Parent == item then
            move.part, move.anchor = anchor.Name, xyz(anchor.Position)
        end
    end
    table.insert(moves, move)
    table.insert(handles, {item, item.Parent})
    archived[item] = true
    archivedParts += partCount
end

store(map.QuarryBasin, true)
for _, wall in ipairs(map.QuarryBlockRim:GetChildren()) do
    for _, part in ipairs(wall:GetChildren()) do
        if part.Name ~= "BasalRock" and part.Name ~= "GrassyBench" then
            store(part, true)
        end
    end
end

for _, item in ipairs({
    map.CobaltMushroomGrove, map.RubyCrimsonBluffs, terraces.StudPackCliffs,
    terraces.GroundArt.MineralSurfaceVariation, terraces.GroundArt.MeadowPatches,
    map.QuarryColorShapes, map.QuarryDepthPass.MaterialSamples,
    map.QuarryDepthPass.RubyEscarpment, map.QuarryDepthPass.VioletRidge,
    map.QuarryDepthPass.EmeraldShoreTerraces,
    map.QuarryDepthPass.CobaltForestExtension.Canopy,
    map.QuarryDepthPass.CobaltForestExtension.Understory,
}) do
    store(item)
end
for _, item in ipairs(map.QuarryArrivalAccents:GetChildren()) do
    if item.Name ~= "SpawnCyanWedge" and item.Name ~= "SpawnAmberDiscs" then store(item) end
end

local originalLandmarks = {
    QuartzScenery = {["01_Tree1"] = true, ["24_Flowers"] = true},
    ImpactTestScenery = {["02_Tree2"] = true, ["10_Rock"] = true},
    RubyScenery = {["01_Tree1"] = true, ["09_Rock"] = true},
    CobaltScenery = {["10_Rock"] = true},
    VioletScenery = {["01_Tree1"] = true, ["23_Flowers"] = true},
    EmeraldScenery = {["04_Tree1"] = true, ["09_Rock"] = true},
}
for name, keep in pairs(originalLandmarks) do
    for _, item in ipairs(terraces.AssetScenery[name]:GetChildren()) do
        if not keep[item.Name] then store(item) end
    end
end
for _, item in ipairs(terraces.MarketGardens:GetChildren()) do
    if item.Name ~= "GardenSoil" then store(item) end
end
for _, woodland in ipairs(map.QuarryWoodlands:GetChildren()) do
    -- Keep the walkable woodland shelf and its low-profile perimeter tree.
    local trees = {}
    for _, tree in ipairs(woodland:GetChildren()) do
        if tree:IsA("Model") then table.insert(trees, tree) end
    end
    table.sort(trees, function(a, b)
        return a:GetExtentsSize().Y < b:GetExtentsSize().Y
    end)
    for i = 2, #trees do store(trees[i]) end
end
for _, reach in ipairs(map.QuarryBiomeReaches:GetChildren()) do
    for _, shelf in ipairs(reach:GetChildren()) do
        for _, signature in ipairs(shelf:GetChildren()) do
            if signature.Name ~= "Signature" then continue end
            local clear = true
            for _, item in ipairs(signature:GetDescendants()) do
                if item:IsA("BasePart") and item.CanCollide then clear = false end
            end
            if clear then store(signature) end
        end
    end
end
for _, item in ipairs(map.EmeraldChalkLagoon:GetChildren()) do
    if item.Name == "LeafyShelf" or item.Name == "WindBentTrunk" or item.Name == "WindBentBranch"
        or item.Name == "WaterReed" or item.Name == "ReedLight" then
        store(item)
    end
end

local function block(parent, name, frame, size, variant, color, solid, shape)
    local part = Instance.new("Part")
    part.Name, part.CFrame, part.Size = name, frame, size
    part.Material, part.MaterialVariant = variant.BaseMaterial, variant.Name
    part.Color = color
    part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, solid, false, solid
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    if shape then part.Shape = shape end
    part.Parent = parent
    return part
end

local grass = materials.QuarryPhoto_Grass
local gravel = materials.QuarryPalette_Pebbles
local slate = materials.QuarryPhoto_Slate
local timber = materials.QuarryAccent_Timber
local brick = materials.QuarryAccent_Brick
local checker = materials.QuarryAccent_Checker
local ribbed = materials.QuarryAccent_Ribbed
local chalk = materials.QuarryBiome_Chalk
local leaf = materials.QuarryPalette_LeafClumps
local bark = materials.QuarryFoliage_Bark

-- Two straight, receding tiers per landform. Existing mining elevations,
-- woodland shelves, bridges and ramps provide the actual route structure.
local function bench(name, x, z, width, depth, level, dx, dz, rise, rockColor, grassColor, rock)
    local group = folder(name, terrain)
    local function tier(cx, cz, w, d, bottom, top, tint)
        block(group, "Stone", CFrame.new(cx, (bottom + top - 1.5)/2, cz),
            v(w, top - 1.5 - bottom, d), rock, tint, true)
        block(group, "Turf", CFrame.new(cx, top - .75, cz),
            v(w, 1.5, d), grass, grassColor, true)
    end
    tier(x, z, width, depth, level - 18, level, rockColor)
    tier(x + dx, z + dz, width * .64, depth * .60, level, level + rise,
        rockColor:Lerp(rgb(174, 180, 172), .20))
end

bench("QuartzWest", -151, 119, 53, 51, 4, -6, 4, 8, rgb(132, 138, 146), rgb(155, 188, 95), slate)
bench("QuartzSouth", -86, 170, 62, 38, 4.4, -8, 6, 5, rgb(127, 133, 144), rgb(159, 187, 99), slate)
bench("ImpactSouth", 83, 170, 64, 38, 4.5, 7, 5, 7, rgb(158, 143, 123), rgb(167, 185, 97), slate)
bench("RubyBack", -181, 64, 45, 43, 19.4, -6, 6, 10, rgb(144, 119, 117), rgb(171, 178, 102), slate)
bench("CobaltBack", 180, 86, 43, 35, 18.3, 5, 5, 8, rgb(111, 138, 159), rgb(126, 173, 126), slate)
bench("VioletBack", -58, -181, 63, 30, 38.2, -5, -5, 10, rgb(137, 128, 164), rgb(131, 172, 119), slate)
bench("EmeraldBack", 167, -185, 57, 29, 41.8, 8, -5, 8, rgb(197, 201, 179), rgb(131, 181, 117), chalk)

local function rectangle(part)
    local f, s = part.CFrame, part.Size / 2
    local right, up, look = f.RightVector, f.UpVector, f.LookVector
    return part.Position, v(
        math.abs(right.X)*s.X + math.abs(up.X)*s.Y + math.abs(look.X)*s.Z,
        0, math.abs(right.Z)*s.X + math.abs(up.Z)*s.Y + math.abs(look.Z)*s.Z)
end

local protected, probes = {}, {}
local function protect(part, samples, margin)
    local p, extent = rectangle(part)
    table.insert(protected, {p, extent + v(margin, 0, margin), part.Name})
    if not samples then return end
    for _, u in ipairs(samples) do
        for _, w in ipairs(samples) do
            local top = part.CFrame:PointToWorldSpace(v(u*part.Size.X, part.Size.Y/2, w*part.Size.Z))
            table.insert(probes, {top, part})
        end
    end
end
for _, field in ipairs(root.Fields:GetChildren()) do
    protect(field.Field, {-.44, -.22, 0, .22, .44}, 1)
end
for _, route in ipairs(terraces.WalkableRoutes:GetChildren()) do
    if not route.Name:find("Curb") then protect(route, {-.45, -.225, 0, .225, .45}, 1) end
end
for _, item in ipairs(map.EmeraldChalkLagoon:GetChildren()) do
    if item.Name == "LagoonCauseway" then protect(item, {-.4, 0, .4}, .4) end
end
for _, item in ipairs(map:GetDescendants()) do
    if item:IsA("ProximityPrompt") and item.Parent:IsA("BasePart") then protect(item.Parent, nil, 3) end
end

local params = RaycastParams.new()
params.RespectCanCollide = true
local exclusions = {}
for item in pairs(archived) do table.insert(exclusions, item) end
params.FilterDescendantsInstances = exclusions

local occupied = {}
local function findGround(x, z, y, radius)
    local center = v(x, y, z)
    for _, area in ipairs(protected) do
        local p, half = area[1], area[2]
        if math.abs(x-p.X) < half.X+radius and math.abs(z-p.Z) < half.Z+radius then return end
    end
    for _, p in ipairs(occupied) do
        if (v(x, 0, z) - p[1]).Magnitude < radius + p[2] + 3 then return end
    end
    local height
    for _, offset in ipairs({v(0,0,0), v(-radius,0,-radius), v(-radius,0,radius),
        v(radius,0,-radius), v(radius,0,radius)}) do
        local hit = workspace:Raycast(center + offset + v(0,2,0), v(0,-4.5,0), params)
        if not hit or hit.Normal.Y < .88 or math.abs(hit.Position.Y-y) > 1 then return end
        if height and math.abs(height-hit.Position.Y) > .32 then return end
        height = height or hit.Position.Y
    end
    table.insert(occupied, {v(x,0,z), radius})
    return CFrame.new(x, height + .025, z)
end

local function prop(parent, kind, frame, size, finish, color, yaw)
    if kind == "Paver" then
        block(parent, kind, frame * CFrame.new(0, .11, 0), v(size, .22, size), finish, color, false)
    else
        block(parent, kind, frame * CFrame.Angles(0, yaw, 0) * CFrame.new(0, size/2, 0),
            v(size, size, size), finish, color, false)
    end
end

local pink = rgb(230, 132, 158)
local blue = rgb(95, 155, 232)
local amber = rgb(238, 185, 85)
local cream = rgb(237, 218, 170)
local mint = rgb(129, 207, 168)
local coral = rgb(221, 113, 86)
local lilac = rgb(170, 134, 220)
local random = Random.new(66301)

-- Each tuple is one deliberately spaced point, with small rotations on the
-- blocks. Vary their size and finish instead of layering details on them.
local function populate(name, candidates)
    local group = folder(name, scatter)
    local count = 0
    for _, point in ipairs(candidates) do
        local x, z, y, kind, size, finish, tint = table.unpack(point)
        local at = findGround(x, z, y, size * (kind == "Paver" and .50 or .64))
        if at then
            prop(group, kind, at, size, finish, tint, random:NextNumber(-.48, .48))
            count += 1
        end
    end
    assert(count >= 2, "Too few clear ground anchors in " .. name .. " (" .. count .. ")")
end

populate("Hub", {
    {-18, 16, 4, "Paver", 7, checker, cream}, {20, 16, 4, "Cube", 3.8, brick, coral},
    {-21, 29, 4, "Cube", 4.7, timber, amber}, {20, 30, 4, "Paver", 5, checker, blue},
    {-32, 15, 4, "Cube", 3.4, ribbed, blue}, {32, 16, 4, "Paver", 5, checker, cream},
})
populate("Quartz", {
    {-61, 56, 4, "Cube", 6.2, gravel, pink}, {-106, 58, 4, "Paver", 6, checker, blue},
    {-106, 103, 4, "Cube", 3.1, timber, amber}, {-46, 136, 4, "Cube", 4.8, checker, cream},
    {-28, 122, 4, "Paver", 4.8, brick, coral},
})
populate("Impact", {
    {76, 55, 4, "Cube", 5.5, timber, amber}, {102, 64, 4, "Paver", 5, checker, cream},
    {108, 99, 4, "Cube", 4.5, brick, coral}, {82, 136, 4, "Cube", 3.8, ribbed, blue},
    {44, 136, 4, "Paver", 5, checker, blue},
})
populate("Ruby", {
    {-111, 40, 20, "Cube", 5.5, brick, coral}, {-150, 40, 20, "Paver", 6, checker, cream},
    {-158, 5, 20, "Cube", 4.5, gravel, lilac}, {-84, -39, 20, "Cube", 3.3, timber, amber},
    {-135, -40, 20, "Paver", 5, checker, pink},
})
populate("Cobalt", {
    {103, 40, 20, "Cube", 5.3, ribbed, blue}, {150, -40, 20, "Paver", 5.5, checker, cream},
    {158, 11, 20, "Cube", 3.5, gravel, pink}, {81, -34, 20, "Paver", 4.5, checker, blue},
})
populate("Violet", {
    {-47, -68, 38, "Cube", 5, ribbed, lilac}, {-83, -148, 38, "Paver", 6, checker, blue},
    {-106, -90, 38, "Cube", 3.8, timber, amber}, {-30, -133, 38, "Cube", 4.4, gravel, pink},
    {-37, -148, 38, "Paver", 4.6, checker, cream},
})
populate("Emerald", {
    {58, -68, 42, "Cube", 5, chalk, mint}, {38, -69, 42, "Paver", 5, checker, cream},
    {29, -102, 42, "Cube", 4, ribbed, blue}, {108, -135, 42, "Cube", 4.8, timber, amber},
    {59, -148, 42, "Paver", 6, checker, mint},
})

local function tree(x, z, y, size, tint)
    local group = scatter.Quartz
    local at = findGround(x, z, y, size * .5)
    if not at then return false end
    block(group, "Trunk", at * CFrame.new(0, size*.35, 0),
        v(size*.24, size*.7, size*.24), bark, rgb(139, 105, 72), false)
    for i, width in ipairs({1, .76, .5}) do
        block(group, "LeafTier", at * CFrame.new(0, size*(.53+i*.26), 0),
            v(size*width, size*.26, size*width), leaf, tint:Lerp(cream, .08*i), false)
    end
    return true
end
local planted = false
for _, point in ipairs({{-108,115},{-109,59},{-106,129},{-31,132},{-29,110},{-98,55},{-105,71},{-58,136}}) do
    if tree(point[1], point[2], 4, 5.2, rgb(131, 184, 76)) then
        planted = true
        break
    end
end
assert(planted, "No open Quartz tree location")

local mushroomCount = 0
local function mushroom(x, z, y, size, tint)
    local group = scatter.Cobalt
    local at = findGround(x, z, y, size * .49)
    if not at then return end
    local height = size*.91
    block(group, "Stem", at * CFrame.new(0, height/2, 0),
        v(size*.24, height, size*.24), chalk, cream, false)
    block(group, "CapRim", at * CFrame.new(0, height, 0),
        v(size, size*.17, size*.93), chalk, cream, false)
    block(group, "Cap", at * CFrame.new(0, height+size*.22, 0),
        v(size*.85, size*.29, size*.79), ribbed, tint, false)
    mushroomCount += 1
end
mushroom(156, -16, 20, 7.7, blue)
mushroom(135, 40, 20, 6.2, pink)
mushroom(83, 39, 20, 4.3, blue)
mushroom(201, -59, 20.6, 8, blue)
mushroom(217, -69, 20.8, 5.5, pink)
mushroom(190, 54, 19.7, 6.6, lilac)
assert(mushroomCount >= 3, "Too few open mushroom locations")

local finishes, finishHandles = {}, {}
local function finish(part, variant, tint)
    assert(materials[variant].BaseMaterial == part.Material, "Material would change collision properties")
    local function bytes(color)
        return {math.round(color.R*255), math.round(color.G*255), math.round(color.B*255)}
    end
    table.insert(finishHandles, {part, part.Color, part.MaterialVariant, tint, variant})
    table.insert(finishes, {path = part:GetFullName(), class = part.ClassName, anchor = xyz(part.Position),
        before = {color = bytes(part.Color), variant = part.MaterialVariant},
        after = {color = bytes(tint), variant = variant}})
end
local quartz = root.Fields.Quartz.Field
assert(quartz.MaterialVariant == "QuarryAccent_RoughBed")
finish(quartz, "QuarryPhoto_Pebble", rgb(205, 199, 205))
for _, part in ipairs(terraces:GetDescendants()) do
    if part.ClassName == "Part" and part.Name == "Turf" and
        (part.MaterialVariant == "QuarryPhoto_Grass" or part.MaterialVariant == "QuarryAccent_LushGrass") then
        finish(part, "QuarryPhoto_Grass", part.Color:Lerp(rgb(164, 181, 127), .34))
    end
end

local serialize = game:GetService("SerializationService")
local enc = game:GetService("EncodingService")
local http = game:GetService("HttpService")
local function encode(bytes)
    return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(bytes, Enum.CompressionAlgorithm.Zstd)))
end

assert(archivedParts > 7000, "Unexpectedly small archive plan")
local snapshot = {
    scenery = encode(serialize:SerializeInstancesAsync({scenery})),
    archive = encode(serialize:SerializeInstancesAsync({archive})),
    moves = encode(buffer.fromstring(http:JSONEncode(moves))),
    finishes = encode(buffer.fromstring(http:JSONEncode(finishes))),
}
local beforeParts = 0
for _, item in ipairs(map:GetDescendants()) do
    if item:IsA("BasePart") then beforeParts += 1 end
end
local newParts = 0
for _, item in ipairs(scenery:GetDescendants()) do
    if item:IsA("BasePart") then newParts += 1 end
end

local function undo()
    for _, edit in ipairs(finishHandles) do edit[1].Color, edit[1].MaterialVariant = edit[2], edit[3] end
    for _, handle in ipairs(handles) do handle[1].Parent = handle[2] end
    scenery.Parent, archive.Parent = nil, nil
end

local function apply()
    assert(not scenery.Parent and not archive.Parent, "Already installed")
    for _, handle in ipairs(handles) do
        assert(handle[1].Parent == handle[2], "Concurrent map change")
    end
    for _, edit in ipairs(finishHandles) do
        assert(edit[1].Color == edit[2] and edit[1].MaterialVariant == edit[3], "Concurrent finish change")
    end
    local ground = RaycastParams.new()
    ground.RespectCanCollide = true
    local function hitAt(point)
        return workspace:Raycast(point + v(0, 5, 0), v(0, -5.4, 0), ground)
    end
    local before = {}
    for i, probe in ipairs(probes) do before[i] = hitAt(probe[1]) or false end

    archive.Parent = storage
    for _, handle in ipairs(handles) do handle[1].Parent = archive end
    scenery.Parent = map
    for _, edit in ipairs(finishHandles) do edit[1].Color, edit[1].MaterialVariant = edit[4], edit[5] end
    local ok, problem = pcall(function()
        for i, probe in ipairs(probes) do
            local hit = hitAt(probe[1])
            local previous = before[i]
            assert((not hit and not previous) or (hit and previous
                and hit.Instance == previous.Instance and (hit.Position-previous.Position).Magnitude < .025),
                ("Changed protected surface %s near %s"):format(probe[2]:GetFullName(), tostring(probe[1])))
        end
        for _, part in ipairs(terrain:GetDescendants()) do
            if part:IsA("BasePart") then
                local p, extent = rectangle(part)
                for _, area in ipairs(protected) do
                    assert(math.abs(p.X-area[1].X) >= extent.X+area[2].X
                        or math.abs(p.Z-area[1].Z) >= extent.Z+area[2].Z,
                        ("New tier overlaps protected %s"):format(area[3]))
                end
            end
        end
    end)
    if not ok then undo(); error(problem) end
    return {beforeParts = beforeParts, archivedParts = archivedParts, newParts = newParts,
        afterParts = beforeParts - archivedParts + newParts, protectedProbes = #probes, mushrooms = mushroomCount, finishes = #finishes}
end
shared.QuarryBlockscape = {snapshot = snapshot, apply = apply, undo = undo}
return {archivedParts = archivedParts, newParts = newParts, moves = #moves,
    probes = #probes, sceneryBytes = #snapshot.scenery, movesBytes = #snapshot.moves}
