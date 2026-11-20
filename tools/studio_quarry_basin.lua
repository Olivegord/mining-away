-- Author the basin in the shared Edit place and return its scoped native export.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local root = workspace.MiningAway
local map = root.Map
assert(root:GetAttribute("QuarrySceneryAuthored") and map:FindFirstChild("QuarryDepthPass"), "Missing quarry baseline")
assert(not map:FindFirstChild("QuarryBasin"), "Reconcile the existing basin before rerunning")

local materials = game:GetService("MaterialService")
local rgb = Color3.fromRGB
local v = Vector3.new
local stone = materials.QuarryPhoto_Slate
local shale = materials.QuarryBiome_Shale
local grass = materials.QuarryPhoto_Grass
local lush = materials.QuarryAccent_LushGrass
local chalk = materials.QuarryBiome_Chalk
local basalt = rgb(70, 105, 117)
local jade = rgb(127, 213, 147)
local spring = rgb(192, 229, 118)
local fern = rgb(115, 181, 139)
local lichen = rgb(106, 171, 111)
local gold = rgb(215, 218, 125)

local function folder(name, parent)
    local result = Instance.new("Folder")
    result.Name = name
    result.Parent = parent
    return result
end

local basin = folder("QuarryBasin", nil)

-- A triangle is split against its longest edge, using two native wedge faces.
-- The terrain is editable and does not need a mesh asset or a runtime generator.
local function triangle(parent, name, a, b, c, material, color, collision)
    local ab, ac, bc = b - a, c - a, c - b
    if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then
        a, c = c, a
    elseif ac:Dot(ac) > bc:Dot(bc) then
        a, b = b, a
    end
    ab, ac, bc = b - a, c - a, c - b
    local normal = ac:Cross(ab)
    if normal.Magnitude < .01 then return end
    local right, back = normal.Unit, bc.Unit
    local up = back:Cross(right).Unit
    local height = math.abs(ab:Dot(up))
    local function wedge(point, xAxis, zAxis, length)
        if length < .035 or height < .035 then return end
        local part = Instance.new("WedgePart")
        part.Name = name
        part.Size = v(.36, height + .025, length + .025)
        part.CFrame = CFrame.fromMatrix(point, xAxis, up, zAxis)
        part.Anchored = true
        part.CanCollide = collision
        part.CanQuery = collision
        part.CanTouch = false
        part.CastShadow = true
        part.Material = material.BaseMaterial
        part.MaterialVariant = material.Name
        part.Color = color
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.Parent = parent
    end
    wedge((a + b) / 2, right, back, math.abs(ab:Dot(back)))
    wedge((a + c) / 2, -right, -back, math.abs(ac:Dot(back)))
end

local function quad(parent, name, a, b, c, d, material, color, collision)
    triangle(parent, name, a, b, c, material, color, collision)
    triangle(parent, name, a, c, d, material, color, collision)
end

local function soil(x, z, palette)
    local broad = .5 + .5 * math.sin(x * .031 + z * .024)
    local shade = .5 + .5 * math.cos(z * .055 - x * .043)
    return palette[1]:Lerp(palette[2], broad * .92):Lerp(palette[3], shade * .26)
end

local southern = {jade, spring, gold}
local western = {fern, spring, rgb(206, 177, 117)}
local northern = {fern, jade, rgb(164, 212, 157)}
local eastern = {rgb(102, 172, 152), rgb(174, 216, 150), rgb(174, 224, 208)}

-- Each profile runs from the visible talus foot to a wide high plateau. The
-- point table is x, z, low shelf elevation, skyline elevation.
local function rim(name, path, outward, palette, rock, tint)
    local group = folder(name, basin)
    local profile = {
        {0, 0, "Talus", rock, tint:Lerp(basalt, .33)},
        {9, .15, "MossApron", grass, lichen},
        {16, .18, "LowerShelf", grass, jade},
        {32, .20, "Escarpment", rock, tint},
        {31, .55, "MossLip", grass, lichen},
        {37, .60, "UpperShelf", lush, jade},
        {54, .62, "HighWall", rock, tint},
        {51, .95, "CrestMoss", grass, lichen},
        {57, 1, "Plateau", grass, jade},
        {95, .995, "FarFace", rock, tint},
        {106, -.60, "FarFace", rock, tint},
    }
    local function at(i, j)
        local p, section = path[i], profile[j]
        local fluting = math.sin(i * 2.37 + j * .72) * (j <= 2 and 2 or 5)
        local width = section[1] + fluting
        local level = p[3] + (p[4] - p[3]) * section[2]
        return v(p[1], level, p[2]) + outward * width
    end
    for i = 1, #path - 1 do
        for j = 1, #profile - 1 do
            local a, b, c, d = at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)
            local section = profile[j]
            local material, color = section[4], section[5]
            local center = (a + b + c + d) / 4
            if material == grass or material == lush then
                local meadow = soil(center.X, center.Z, palette)
                color = color:Lerp(meadow, section[3]:find("Moss") and .48 or .83)
            else
                color = color:Lerp(rgb(118, 147, 158), (.5 + .5 * math.sin(i * 1.71 + j)) * .20)
            end
            quad(group, section[3], a, b, c, d, material, color, j <= 7)
        end
    end
    for _, i in ipairs({1, #path}) do
        local p = path[i]
        local bottom = v(p[1], -42, p[2]) + outward * 56
        for j = 1, #profile - 1 do
            triangle(group, "RimEnd", bottom, at(i, j), at(i, j + 1), rock, tint, false)
        end
    end
end

rim("WestEscarpment", {
    {-145, 178, -17, 110}, {-154, 135, -10, 143}, {-171, 98, -8, 156},
    {-185, 60, 4, 172}, {-196, 21, 6, 185}, {-205, -20, 10, 172},
    {-178, -66, 5, 158}, {-170, -112, 14, 180}, {-173, -158, 24, 172},
    {-160, -205, 21, 147},
}, v(-1, 0, 0), western, shale, rgb(100, 127, 141))

rim("NorthCrown", {
    {-229, -157, 15, 149}, {-186, -161, 16, 181}, {-142, -166, 20, 168},
    {-97, -170, 25, 167}, {-52, -169, 28, 181}, {-7, -171, 30, 155},
    {39, -168, 28, 178}, {83, -170, 26, 188}, {126, -174, 18, 172},
    {170, -175, 17, 156}, {211, -173, 14, 152}, {257, -169, 12, 144},
    {289, -153, 3, 110},
}, v(0, 0, -1), northern, stone, rgb(103, 133, 151))

rim("EastChalkRim", {
    {249, -180, 15, 143}, {265, -143, 13, 175}, {271, -102, 8, 155},
    {260, -58, -1, 144}, {259, -17, -7, 167}, {258, 25, -6, 152},
    {232, 63, -9, 147}, {202, 100, -13, 159}, {181, 139, -15, 147},
    {176, 184, -18, 116},
}, v(1, 0, 0), eastern, chalk, rgb(122, 156, 157))

-- The south walls flank a lower outlet. Light can reach the basin floor while
-- the starting camera sees depth behind both of its nearby mineral plots.
rim("SouthwestGate", {
    {-204, 156, -14, 119}, {-168, 167, -9, 147}, {-128, 176, -12, 136},
    {-92, 190, -17, 121}, {-55, 200, -22, 102}, {-35, 212, -26, 75},
}, v(0, 0, 1), southern, stone, rgb(98, 133, 135))

rim("SoutheastGate", {
    {36, 209, -26, 73}, {70, 199, -21, 111}, {105, 188, -17, 134},
    {147, 176, -15, 152}, {181, 169, -18, 123},
}, v(0, 0, 1), southern, shale, rgb(100, 137, 143))

-- Nested polygon benches have actual walkable caps, flared stone feet, and a
-- moss band at each lip. Each higher ring recedes so lower shelves stay open.
local function terraces(name, x, z, width, depth, rotation, levels, palette, rock, tint)
    local group = folder(name, basin)
    local segments = 7
    local function ring(radius, y, offsetX, offsetZ, unevenness)
        local result = {}
        for i = 1, segments do
            local angle = (i - 1) * math.pi * 2 / segments + rotation
            local shape = 1 + .095 * math.sin(i * 2.1 + x) + .055 * math.cos(i * 3.4 + z)
            local relief = (unevenness or 0) * math.sin(i * 1.67 + x * .14)
            result[i] = v(x + offsetX + math.cos(angle) * width * radius * shape, y + relief,
                z + offsetZ + math.sin(angle) * depth * radius * shape)
        end
        return result
    end
    local function link(a, b, namePart, material, tintPart, ground)
        for i = 1, segments do
            local n = i % segments + 1
            local color = tintPart
            if ground then
                local at = (a[i] + a[n] + b[i] + b[n]) / 4
                color = soil(at.X, at.Z, palette)
            elseif namePart == "CutRock" then
                color = tintPart:Lerp(basalt, .07 + .18 * (.5 + .5 * math.sin(i * 1.37 + x)))
            end
            quad(group, namePart, a[i], a[n], b[n], b[i], material, color, true)
        end
    end
    local base = ring(1.04, levels[1][1] - 23, 0, 0)
    for i, data in ipairs(levels) do
        local y, radius, offsetX, offsetZ = table.unpack(data)
        local unevenness = i == 1 and .2 or math.min(1.65, i * .48)
        local top = ring(radius, y, offsetX, offsetZ, unevenness)
        local moss = ring(radius * 1.013, y - math.min(4.8, 1.6 + i * .8), offsetX, offsetZ, unevenness)
        link(base, moss, "CutRock", rock, tint:Lerp(basalt, .1 * (i - 1)), false)
        link(moss, top, "LivingEdge", grass, lichen:Lerp(palette[1], .35), false)
        local nextLevel = levels[i + 1]
        if nextLevel then
            local inner = ring(nextLevel[2] * 1.07, y, nextLevel[3], nextLevel[4], unevenness * .65)
            link(top, inner, "GrassBench", grass, jade, true)
            base = inner
        else
            local center = v(x + offsetX, y, z + offsetZ)
            for j = 1, segments do
                local a, b = top[j], top[j % segments + 1]
                local at = (a + b + center) / 3
                triangle(group, "GrassySummit", center, a, b, grass, soil(at.X, at.Z, palette), true)
            end
        end
    end
end

-- Four foreground and mid-distance forms put depth close to the existing walk.
-- Preserve a low outer landing on each starter field, then rise away from it.
terraces("QuartzWestSteps", -143, 115, 38, 39, .2, {
    {3.80, 1, 0, 0}, {10, .84, -3, 2}, {19, .63, -10, 4}, {63, .41, -13, 7},
}, southern, stone, rgb(78, 116, 124))

terraces("QuartzSouthSteps", -80, 164, 39, 29, .34, {
    {3.80, 1, 0, 0}, {10, .79, -4, 5}, {27, .56, -9, 9}, {45, .37, -14, 13},
}, southern, shale, rgb(84, 121, 129))

terraces("ImpactSouthSteps", 80, 159, 43, 25, .1, {
    {3.80, 1, 0, 0}, {11, .78, 2, 5}, {21, .58, 8, 8}, {47, .37, 13, 12},
}, southern, stone, rgb(80, 122, 131))

terraces("VioletOverlookSteps", -52, -169, 45, 26, .43, {
    {37.7, 1, 0, 0}, {48, .80, -4, -7}, {66, .58, -6, -11}, {104, .36, -9, -13},
}, northern, shale, rgb(100, 129, 151))

terraces("RubyGreenSpur", -167, 62, 26, 25, .32, {
    {17, 1, 0, 0}, {28, .82, -4, 4}, {51, .60, -8, 5}, {86, .37, -10, 8},
}, western, shale, rgb(94, 118, 132))

terraces("CobaltForestSpur", 174, 77, 37, 25, .23, {
    {18.6, 1, 0, 0}, {30, .81, 2, 6}, {48, .57, 7, 11}, {75, .38, 11, 12},
}, eastern, stone, rgb(90, 129, 143))

terraces("EmeraldCoveSteps", 169, -163, 44, 20, .25, {
    {34, 1, 0, 0}, {45, .83, 2, -5}, {60, .62, 6, -8}, {91, .38, 9, -11},
}, eastern, chalk, rgb(148, 177, 168))

-- Reuse the existing ground material variety and shift its tint by broad patches
-- across the old turf, so the new terraces read as part of the same landscape.
local groundEdits, handles = {}, {}
local function bytes(color)
    return {math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255)}
end
local function paletteAt(position)
    if position.Z > 44 then return southern end
    if position.X > 55 then return eastern end
    if position.Z < -73 then return northern end
    return western
end
for _, part in ipairs(map.DronerevolutionTerraces:GetDescendants()) do
    if part.ClassName == "Part" and part.Name == "Turf" and
        (part.MaterialVariant == grass.Name or part.MaterialVariant == lush.Name) then
        local at = part.Position
        local palette = paletteAt(at)
        local tint = soil(at.X, at.Z, palette)
        local nextColor = part.Color:Lerp(tint, .62)
        local before, after = bytes(part.Color), bytes(nextColor)
        if before[1] ~= after[1] or before[2] ~= after[2] or before[3] ~= after[3] then
            table.insert(handles, part)
            table.insert(groundEdits, {
                path = part:GetFullName(),
                class = part.ClassName,
                anchor = {at.X, at.Y, at.Z},
                before = {color = before},
                after = {color = after},
            })
        end
    end
end

-- Capture mining and route clearance before moving the authored geometry into
-- Workspace. Compare against actual collidable surfaces after parenting.
local probes = {}
local function probe(part, xs, zs)
    for _, x in ipairs(xs) do
        for _, z in ipairs(zs) do
            local top = part.CFrame:PointToWorldSpace(v(x * part.Size.X, part.Size.Y / 2, z * part.Size.Z))
            table.insert(probes, {top = top, name = part:GetFullName()})
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

local enc = game:GetService("EncodingService")
local serialization = game:GetService("SerializationService")
local http = game:GetService("HttpService")
local function encode(bufferValue)
    return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(bufferValue, Enum.CompressionAlgorithm.Zstd)))
end

assert(#groundEdits > 75, "Unexpected turf baseline")
local snapshot = {
    scenery = encode(serialization:SerializeInstancesAsync({basin})),
    edits = encode(buffer.fromstring(http:JSONEncode({edits = groundEdits, moves = {}}))),
}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {basin}
params.RespectCanCollide = true
basin.Parent = map
for _, probeInfo in ipairs(probes) do
    local top = probeInfo.top
    local hit = workspace:Raycast(top + v(0, 240, 0), v(0, -239.8, 0), params)
    if hit then
        basin.Parent = nil
        basin:Destroy()
        error(("Basin intersects protected surface %s at %s"):format(probeInfo.name, tostring(top)))
    end
end

for i, part in ipairs(handles) do
    part.Color = rgb(table.unpack(groundEdits[i].after.color))
end
shared.QuarryBasinSnapshot = snapshot
return {
    terrainInstances = #basin:GetDescendants(),
    groundEdits = #groundEdits,
    protectedProbes = #probes,
    exportBytes = {scenery = #snapshot.scenery, edits = #snapshot.edits},
}
