-- Replace the outer rim in Edit and taper the woodland away from the fields.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local root = workspace.MiningAway
local map = root.Map
local storage = game:GetService("ServerStorage")
local basin = map.QuarryBasin
local woodlands = map.QuarryWoodlands
assert(not map:FindFirstChild("QuarryBlockRim") and not storage:FindFirstChild("QuarryRimArchive"),
    "Reconcile an existing block rim before rerunning")

local v, rgb = Vector3.new, Color3.fromRGB
local materials = game:GetService("MaterialService")
local slate = materials.QuarryPhoto_Slate
local shale = materials.QuarryBiome_Shale
local chalk = materials.QuarryBiome_Chalk
local grass = materials.QuarryPhoto_Grass
local moss = materials.QuarryAccent_LushGrass

local function folder(name, parent)
    local item = Instance.new("Folder")
    item.Name = name
    item.Parent = parent
    return item
end
local rim = folder("QuarryBlockRim", nil)
local archive = folder("QuarryRimArchive", nil)
local archivedWalls = folder("FormerRim", archive)
local archivedTrees = folder("OuterTrees", archive)

local function rockPart(parent, name, frame, size, material, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = frame
    part.Anchored = true
    part.CanTouch = false
    part.Material = material.BaseMaterial
    part.MaterialVariant = material.Name
    part.Color = color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
end

-- Each line is a run of orthogonal cliff sections. Entries describe the
-- horizontal interval, face setback, heights of the two benches, and crest.
-- Blocks overlap behind the face so the stepped silhouette has a solid core.
local function cliff(name, out, segments, stone, rock, soil)
    local group = folder(name, rim)
    local along = v(out.Z, 0, -out.X)
    local basis = CFrame.fromMatrix(Vector3.zero, along, Vector3.yAxis, out)
    for index, data in ipairs(segments) do
        local from, to, face, bench, shoulder, crest = table.unpack(data)
        local width = to - from
        local center = (from + to) / 2
        local tint = rock:Lerp(rgb(140, 162, 166), .06 + .16 * (.5 + .5 * math.sin(index * 2.34)))
        local function block(label, shift, widthScale, front, depth, bottom, top, variant, color)
            local at = along * (center + shift) + out * (face + front + depth / 2)
            at += v(0, (bottom + top) / 2, 0)
            rockPart(group, label, basis + at, v(width * widthScale, top - bottom, depth), variant, color)
        end

        block("BasalRock", 0, 1.08, 1, 58, -29, bench, stone, tint:Lerp(rgb(55, 76, 88), .27))
        block("GrassyBench", 0, 1.08, .4, 43, bench - 3.6, bench + .4, grass, soil)
        block("Escarpment", 0, 1.06, 13, 59, bench - 2, shoulder, stone, tint)
        block("ShoulderGrass", 0, 1.06, 12.3, 46, shoulder - 3, shoulder + .2, moss, soil)
        block("CrownRock", 0, 1.06, 32, 64, shoulder - 2, crest, stone, tint:Lerp(rock, .36))
        block("CrownGrass", 0, 1.06, 31.4, 65, crest - 3, crest + .25, grass, soil)
        local shift = width * ((index % 3 - 1) * .19)
        local buttressHeight = shoulder + (crest - shoulder) * (.25 + (index % 3) * .13)
        block("FracturedColumn", shift, .25, 8, 28, bench - 1, buttressHeight, stone,
            tint:Lerp(rgb(53, 78, 94), .28))
        block("ColumnMoss", shift, .25, 7.5, 27, buttressHeight - 2.8, buttressHeight + .25, moss, soil)
        if index % 3 ~= 1 then
            block("RockStratum", -shift, .48, 11.5, 14, shoulder - 13, shoulder - 7.5, slate,
                tint:Lerp(rgb(73, 95, 105), .29))
        end
        if index % 3 ~= 0 then
            block("FootBlock", -shift, .37, -5, 13, -22, bench - 8, stone,
                tint:Lerp(rgb(76, 105, 112), .32))
        end
    end
end

-- West: local length goes south. North and south use opposite local X axes.
cliff("WestEscarpment", v(-1, 0, 0), {
    {-211, -168, 220, 56, 114, 154}, {-168, -126, 206, 43, 104, 166},
    {-126, -82, 204, 34, 92, 148}, {-82, -35, 219, 51, 120, 174},
    {-35, 8, 241, 47, 126, 183}, {8, 52, 239, 36, 101, 169},
    {52, 97, 221, 28, 86, 148}, {97, 138, 204, 35, 102, 156},
    {138, 182, 196, 25, 74, 135}, {182, 219, 186, 21, 60, 113},
}, shale, rgb(87, 111, 128), rgb(110, 167, 104))

cliff("NorthCrown", v(0, 0, -1), {
    {-293, -250, 198, 38, 94, 132}, {-250, -209, 203, 42, 99, 156},
    {-209, -163, 200, 43, 111, 169}, {-163, -119, 208, 57, 117, 184},
    {-119, -74, 214, 63, 133, 196}, {-74, -28, 213, 54, 119, 176},
    {-28, 20, 203, 42, 103, 157}, {20, 66, 211, 52, 117, 175},
    {66, 110, 213, 60, 130, 189}, {110, 157, 205, 47, 105, 170},
    {157, 199, 201, 41, 97, 154}, {199, 242, 213, 44, 107, 161},
}, slate, rgb(89, 121, 135), rgb(117, 166, 111))

cliff("EastChalkRim", v(1, 0, 0), {
    {-224, -183, 198, 22, 77, 117}, {-183, -140, 204, 25, 87, 137},
    {-140, -96, 221, 28, 92, 154}, {-96, -53, 240, 37, 108, 167},
    {-53, -8, 271, 34, 97, 152}, {-8, 37, 278, 43, 115, 174},
    {37, 80, 282, 48, 122, 178}, {80, 123, 291, 39, 103, 159},
    {123, 168, 282, 51, 122, 171}, {168, 216, 273, 47, 109, 155},
}, chalk, rgb(130, 158, 154), rgb(110, 168, 122))

cliff("SouthwestGate", v(0, 0, 1), {
    {-225, -183, 208, 27, 87, 140}, {-183, -142, 219, 35, 108, 158},
    {-142, -99, 224, 24, 90, 139}, {-99, -63, 230, 19, 72, 115},
    {-63, -31, 232, 13, 49, 82},
}, slate, rgb(79, 114, 123), rgb(139, 182, 102))

cliff("SoutheastGate", v(0, 0, 1), {
    {33, 70, 235, 14, 51, 81}, {70, 113, 228, 22, 78, 113},
    {113, 155, 221, 28, 98, 148}, {155, 200, 215, 30, 108, 159},
}, shale, rgb(86, 120, 133), rgb(128, 176, 106))

local moves, handles = {}, {}
local function move(item, destination, details)
    local record = details or {}
    record.path = item:GetFullName()
    record.parent = "ServerStorage.QuarryRimArchive." .. destination.Name
    table.insert(moves, record)
    table.insert(handles, {item, item.Parent, destination})
end
for name, count in pairs({
    WestEscarpment = 400, NorthCrown = 520, EastChalkRim = 400, SouthwestGate = 240, SoutheastGate = 200,
}) do
    local section = assert(basin:FindFirstChild(name), name)
    assert(#section:GetChildren() == count, "Reconcile changed rim section " .. name)
    move(section, archivedWalls)
end

local tallies = {}
local kept = {}
for _, region in ipairs(woodlands:GetChildren()) do
    local name = region.Name:gsub("Woodland$", "")
    local bed = root.Fields[name == "Impact" and "ImpactTest" or name].Field
    local trees = {}
    for _, model in ipairs(region:GetChildren()) do
        if model:IsA("Model") then
            local box = model:GetBoundingBox()
            local dx = math.max(0, math.abs(box.X - bed.Position.X) - bed.Size.X / 2)
            local dz = math.max(0, math.abs(box.Z - bed.Position.Z) - bed.Size.Z / 2)
            table.insert(trees, {model = model, at = box.Position, distance = math.sqrt(dx * dx + dz * dz)})
        end
    end
    table.sort(trees, function(a, b) return a.distance < b.distance end)
    local stayed, before, after = {}, {0, 0, 0}, {0, 0, 0}
    for _, tree in ipairs(trees) do
        local band = tree.distance < 20 and 1 or (tree.distance < 45 and 2 or 3)
        before[band] += 1
        -- As the forest recedes, widen crown spacing continuously. A nearby
        -- tree in an earlier band also counts toward the farther spacing.
        local gap = math.clamp(8 + (tree.distance - 20) * .46, 8, 32)
        local open = true
        if band > 1 then
            for _, position in ipairs(stayed) do
                local delta = tree.at - position
                if delta.X * delta.X + delta.Z * delta.Z < gap * gap then
                    open = false
                    break
                end
            end
        end
        if open then
            after[band] += 1
            table.insert(stayed, tree.at)
            table.insert(kept, tree.at)
        else
            -- Several trees have the same model name. An exact child part
            -- location identifies the original model in the native snapshot.
            local anchor = assert(tree.model:FindFirstChildWhichIsA("BasePart"))
            local p = anchor.Position
            move(tree.model, archivedTrees, {anchor = {p.X, p.Y, p.Z}, part = anchor.Name})
        end
    end
    tallies[name] = {before = before, after = after}
end

local serialize = game:GetService("SerializationService")
local encoding = game:GetService("EncodingService")
local function encode(bytes)
    return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(bytes, Enum.CompressionAlgorithm.Zstd)))
end
local snapshot = {
    rim = encode(serialize:SerializeInstancesAsync({rim})),
    archive = encode(serialize:SerializeInstancesAsync({archive})),
    moves = encode(buffer.fromstring(game:GetService("HttpService"):JSONEncode(moves))),
}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {rim}
local function clearAbove(point)
    return not workspace:Raycast(point + v(0, 230, 0), v(0, -229.8, 0), params)
end
rim.Parent = map
local ok, probes = pcall(function()
    local n = 0
    local function probe(part, xs, zs)
        for _, x in ipairs(xs) do
            for _, z in ipairs(zs) do
                local top = part.CFrame:PointToWorldSpace(v(x * part.Size.X, part.Size.Y / 2, z * part.Size.Z))
                assert(clearAbove(top), "Block rim obstructs " .. part:GetFullName())
                n += 1
            end
        end
    end
    for _, field in ipairs(root.Fields:GetChildren()) do
        local part = field:FindFirstChild("Field")
        if part then probe(part, {-.44, -.22, 0, .22, .44}, {-.44, -.22, 0, .22, .44}) end
    end
    for _, part in ipairs(map.DronerevolutionTerraces.WalkableRoutes:GetChildren()) do
        if part:IsA("BasePart") and not part.Name:find("Curb") then
            probe(part, {-.36, 0, .36}, {-.46, -.23, 0, .23, .46})
        end
    end
    for _, position in ipairs(kept) do
        assert(clearAbove(position - v(0, 8, 0)), "Block rim overlaps a kept tree at " .. tostring(position))
    end
    return n
end)
if not ok then
    rim:Destroy()
    archive:Destroy()
    error(probes)
end

archive.Parent = storage
for _, row in ipairs(handles) do
    row[1].Parent = row[3]
end
shared.QuarryBlockRimSnapshot = snapshot
return {
    blocks = #rim:GetDescendants() - #rim:GetChildren(),
    probes = probes, trees = tallies, archivedTrees = #archivedTrees:GetChildren(),
    exportBytes = {rim = #snapshot.rim, archive = #snapshot.archive, moves = #snapshot.moves},
}
