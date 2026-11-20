-- Extend the authored quarry with walkable forest shelves and clustered trees.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local root = workspace.MiningAway
local map = root.Map
local terraces = map.DronerevolutionTerraces
local basin = assert(map:FindFirstChild("QuarryBasin"), "Missing basin")
assert(not map:FindFirstChild("QuarryWoodlands"), "Reconcile the existing woodland before rerunning")

local materials = game:GetService("MaterialService")
local v, rgb = Vector3.new, Color3.fromRGB
local grass = materials.QuarryPhoto_Grass
local shale = materials.QuarryBiome_Shale
local slate = materials.QuarryPhoto_Slate
local chalk = materials.QuarryBiome_Chalk
local random = Random.new(139623)
local quartz = terraces.AssetScenery.QuartzScenery
local broadleaf = assert(quartz:FindFirstChild("01_Tree1"), "Missing authored broadleaf tree")
local evergreen = assert(quartz:FindFirstChild("03_Tree2"), "Missing authored evergreen tree")

local function folder(name, parent)
    local result = Instance.new("Folder")
    result.Name = name
    result.Parent = parent
    return result
end
local woodlands = folder("QuarryWoodlands", nil)

-- Native wedge facets use the same construction as the authored basin.
local function triangle(parent, name, a, b, c, material, color)
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
        part.CanCollide = true
        part.CanTouch = false
        part.Material = material.BaseMaterial
        part.MaterialVariant = material.Name
        part.Color = color
        part.Parent = parent
    end
    wedge((a + b) / 2, right, back, math.abs(ab:Dot(back)))
    wedge((a + c) / 2, -right, -back, math.abs(ac:Dot(back)))
end

local function quad(parent, name, a, b, c, d, material, color)
    triangle(parent, name, a, b, c, material, color)
    triangle(parent, name, a, c, d, material, color)
end

local meadow = {rgb(132, 190, 113), rgb(199, 218, 128)}
local amber = {rgb(136, 182, 102), rgb(209, 201, 120)}
local cove = {rgb(101, 174, 137), rgb(163, 210, 141)}
local fern = {rgb(109, 164, 115), rgb(170, 205, 141)}

local function groundTint(point, colors)
    local variation = .5 + .5 * math.sin(point.X * .052 + point.Z * .035)
    return colors[1]:Lerp(colors[2], variation * .84)
end

local function shelf(parent, height, center, outline, rock, rockTint, palette)
    local ground = folder("ForestShelf", parent)
    local inner, edge, lip, foot = {}, {}, {}, {}
    for i, point in ipairs(outline) do
        local x, z = point[1], point[2]
        local dx, dz = x - center[1], z - center[2]
        local y = height + (point[3] or 0)
        edge[i] = v(x, y, z)
        inner[i] = v(x - dx * .52, height + math.sin(i * 1.3) * .46, z - dz * .52)
        lip[i] = v(x + dx * .016, y - 1.8, z + dz * .016)
        foot[i] = v(x + dx * .12, height - 17, z + dz * .12)
    end
    local middle = v(center[1], height + .55, center[2])
    for i = 1, #outline do
        local j = i % #outline + 1
        local tint = groundTint((edge[i] + edge[j]) / 2, palette)
        quad(ground, "ForestGround", edge[i], edge[j], inner[j], inner[i], grass, tint)
        triangle(ground, "ForestGround", middle, inner[i], inner[j], grass,
            groundTint((middle + inner[i] + inner[j]) / 3, palette))
        quad(ground, "RootedLedge", lip[i], lip[j], edge[j], edge[i], grass,
            tint:Lerp(rgb(82, 143, 93), .43))
        quad(ground, "WoodlandRockFace", foot[i], foot[j], lip[j], lip[i], rock,
            rockTint:Lerp(rgb(82, 120, 129), .27 * (.5 + .5 * math.sin(i * 2.17))))
    end
end

local quartzWoods = folder("QuartzWoodland", woodlands)
local impactWoods = folder("ImpactWoodland", woodlands)
local rubyWoods = folder("RubyWoodland", woodlands)
local violetWoods = folder("VioletWoodland", woodlands)
local emeraldWoods = folder("EmeraldWoodland", woodlands)

-- Two broad low foothills extend the starter plots toward the south rim.
shelf(quartzWoods, 3.38, {-118, 152}, {
    {-151, 77, .30}, {-125, 84, .20}, {-119, 107, .18}, {-109, 132, .20},
    {-78, 136, .22}, {-43, 135, .26}, {-34, 155, .55}, {-34, 183, 1.03},
    {-57, 206, .90}, {-100, 213, 1.0}, {-146, 200, .86}, {-182, 176, .7},
    {-189, 146, .42}, {-171, 104, .32},
}, slate, rgb(103, 134, 135), meadow)
shelf(impactWoods, 3.42, {110, 163}, {
    {104, 101, .21}, {129, 108, .34}, {154, 129, .67}, {171, 157, .78},
    {157, 185, 1.06}, {127, 212, 1.23}, {84, 215, .97}, {53, 197, .64},
    {36, 171, .48}, {39, 139, .20}, {68, 132, .19}, {92, 130, .20},
}, slate, rgb(108, 139, 143), fern)

-- The upper woodlands continue the existing biome edges and overlook the basin.
shelf(rubyWoods, 19.29, {-183, 8}, {
    {-196, -63, .47}, {-167, -49, .42}, {-155, -24, .24}, {-150, 4, .25},
    {-150, 32, .23}, {-148, 52, .30}, {-171, 73, .53}, {-207, 67, .83},
    {-231, 43, 1.3}, {-229, 3, 1.1}, {-216, -37, .72},
}, shale, rgb(128, 126, 138), amber)
shelf(violetWoods, 37.31, {-73, -170}, {
    {-132, -153, .30}, {-109, -141, .25}, {-75, -142, .28}, {-39, -142, .24},
    {-17, -151, .54}, {-20, -174, .89}, {-44, -195, 1.2}, {-82, -203, 1.2},
    {-118, -191, .8}, {-140, -171, .60},
}, shale, rgb(111, 129, 151), fern)
shelf(emeraldWoods, 41.28, {71, -171}, {
    {31, -151, .32}, {47, -142, .26}, {75, -143, .23}, {101, -143, .28},
    {120, -158, .63}, {116, -177, .89}, {97, -198, 1.2}, {62, -201, 1.0},
    {31, -188, .76}, {22, -169, .56},
}, chalk, rgb(138, 164, 155), cove)

-- Clearance covers the projected canopy, not just the trunk. Retain the
-- player-facing entrance and leave clear sky over the mining and route volumes.
local function footprint(part, margin)
    local frame, size = part.CFrame, part.Size / 2
    local right, up, look = frame.RightVector, frame.UpVector, frame.LookVector
    local halfX = math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z + margin
    local halfZ = math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z + margin
    return {x = frame.X, z = frame.Z, hx = halfX, hz = halfZ}
end

local protected, probes = {}, {}
local function protect(part, margin, lateral, along)
    table.insert(protected, footprint(part, margin))
    for _, x in ipairs(lateral) do
        for _, z in ipairs(along) do
            local p = part.CFrame:PointToWorldSpace(v(x * part.Size.X, part.Size.Y / 2, z * part.Size.Z))
            table.insert(probes, {p, part:GetFullName()})
        end
    end
end
for _, field in ipairs(root.Fields:GetChildren()) do
    local part = field:FindFirstChild("Field")
    if part then protect(part, 1.8, {-.44, -.22, 0, .22, .44}, {-.44, -.22, 0, .22, .44}) end
end
for _, part in ipairs(terraces.WalkableRoutes:GetChildren()) do
    if part:IsA("BasePart") and not part.Name:find("Curb") then
        protect(part, 1, {-.36, 0, .36}, {-.46, -.23, 0, .23, .46})
    end
end

local occupied = {}
for _, item in ipairs(terraces.AssetScenery:GetDescendants()) do
    if item:IsA("Model") and item.Name:lower():find("tree") then
        local frame = item:GetBoundingBox()
        table.insert(occupied, frame.Position)
    end
end
local groundNames = {
    Turf = true, ForestGround = true, GrassBench = true, GrassySummit = true,
    LowerShelf = true, UpperShelf = true, Plateau = true, LoamShelf = true,
}
local groundParams = RaycastParams.new()
groundParams.RespectCanCollide = true
local function surface(x, z, low, high)
    local hit = workspace:Raycast(v(x, high + .4, z), v(0, low - high - .4, 0), groundParams)
    if hit and groundNames[hit.Instance.Name] and hit.Normal.Y > .82 then
        return hit.Position.Y
    end
    return nil
end

local function plant(parent, x, z, low, high, scale, palette, front)
    local y = surface(x, z, low, high)
    if not y then return false end
    for _, other in ipairs(occupied) do
        local dx, dz = x - other.X, z - other.Z
        if dx * dx + dz * dz < (front and 7.6 or 10.5)^2 then return false end
    end

    local template = random:NextNumber() < .61 and broadleaf or evergreen
    local tree = template:Clone()
    local heading = random:NextNumber(-math.pi, math.pi)
    tree:ScaleTo(tree:GetScale() * scale)
    tree:PivotTo(CFrame.new() * CFrame.Angles(0, heading, 0))
    local box, size = tree:GetBoundingBox()
    local dx = math.abs(box.RightVector.X) * size.X / 2 + math.abs(box.LookVector.X) * size.Z / 2
    local dz = math.abs(box.RightVector.Z) * size.X / 2 + math.abs(box.LookVector.Z) * size.Z / 2
    for _, area in ipairs(protected) do
        if math.abs(x - area.x) < dx + area.hx and math.abs(z - area.z) < dz + area.hz then
            tree:Destroy()
            return false
        end
    end

    local tint = groundTint(v(x, y, z), palette)
    local leafBlend = random:NextNumber(.14, .48)
    for _, part in ipairs(tree:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            local leaves = part.Material == Enum.Material.LeafyGrass
            part.CastShadow = front and (not leaves or part.Size.Magnitude > 7)
            if leaves then part.Color = part.Color:Lerp(tint, leafBlend) end
        end
    end
    local offset = v(x - box.X, y - (box.Y - size.Y / 2) - .15, z - box.Z)
    tree:PivotTo(tree:GetPivot() + offset)
    tree.Name = template == broadleaf and "CanopyTree" or "Evergreen"
    tree.Parent = parent
    table.insert(occupied, v(x, y, z))
    return true
end

local function grove(parent, rows, palette)
    local front, rear = 0, 0
    for _, row in ipairs(rows) do
        local x, z, dx, dz, count, low, high, nearest = table.unpack(row)
        for i = 0, count - 1 do
            local factor = nearest and random:NextNumber(.99, 1.27) or random:NextNumber(1.18, 1.64)
            if plant(parent, x + i * dx + random:NextNumber(-1.65, 1.65),
                z + i * dz + random:NextNumber(-1.65, 1.65), low, high, factor, palette, nearest) then
                if nearest then front += 1 else rear += 1 end
            end
        end
    end
    return {front = front, rear = rear}
end

local groundParamsForNew = RaycastParams.new()
groundParamsForNew.RespectCanCollide = true
groundParamsForNew.FilterType = Enum.RaycastFilterType.Include
groundParamsForNew.FilterDescendantsInstances = {woodlands}
woodlands.Parent = map
local function populate()
    for _, probe in ipairs(probes) do
        local hit = workspace:Raycast(probe[1] + v(0, 115, 0), v(0, -114.8, 0), groundParamsForNew)
        assert(not hit, ("Woodland shelf obstructs %s at %s"):format(probe[2], tostring(probe[1])))
    end

    -- Stagger the front edge and the taller uphill canopy. The south and west
    -- rows overlap at the corner to read as one continuous wooded backdrop.
    local counts = {}
    counts.Quartz = grove(quartzWoods, {
        {-113, 83, -1.15, 9.8, 6, 1, 13, true},
        {-105, 142, 10.6, .1, 7, 1, 13, true},
        {-121, 62, 10.1, -1.2, 8, 1, 11, true},
        {-133, 79, -.5, 12, 8, 1, 43, false},
        {-151, 82, -1.3, 13, 8, 1, 66, false},
        {-174, 118, 1.9, 14, 5, 1, 38, false},
        {-153, 158, 12.4, -1, 10, 1, 62, false},
        {-154, 180, 13.2, 1.1, 9, 1, 54, false},
        {-130, 196, 13.1, -.4, 6, 1, 24, false},
    }, meadow)
    counts.Impact = grove(impactWoods, {
        {110, 78, .4, 11, 6, 1, 14, true},
        {42, 143, 11.6, 1.1, 7, 1, 14, true},
        {123, 116, 1.1, 13, 5, 1, 49, false},
        {52, 161, 12.6, .6, 8, 1, 50, false},
        {62, 189, 14.2, .8, 7, 1, 52, false},
        {74, 203, 14.6, -.8, 5, 1, 48, false},
    }, fern)
    counts.Ruby = grove(rubyWoods, {
        {-162, -37, -.7, 11.2, 8, 17, 31, true},
        {-178, -53, -.6, 12.8, 9, 18, 36, false},
        {-207, -46, -.5, 13.8, 8, 18, 40, false},
        {-153, 46, 7, 4, 3, 17, 34, true},
    }, amber)
    counts.Violet = grove(violetWoods, {
        {-109, -152, 11, -.2, 8, 35, 51, true},
        {-122, -166, 12.8, -.8, 8, 36, 67, false},
        {-113, -185, 14.5, 0, 7, 36, 105, false},
    }, fern)
    counts.Emerald = grove(emeraldWoods, {
        {34, -153, 10.9, .4, 8, 40, 52, true},
        {31, -172, 12.8, -.6, 7, 40, 67, false},
        {44, -189, 14.3, 0, 5, 40, 85, false},
    }, cove)
    assert(counts.Quartz.front >= 10 and counts.Quartz.rear >= 15, "Quartz tree line is too sparse")
    return counts
end

local ok, counts = pcall(populate)
if not ok then
    woodlands:Destroy()
    error(counts)
end
local serialize = game:GetService("SerializationService")
local enc = game:GetService("EncodingService")
local snapshotOk, snapshot = pcall(function()
    local bytes = serialize:SerializeInstancesAsync({woodlands})
    return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(bytes, Enum.CompressionAlgorithm.Zstd)))
end)
if not snapshotOk then
    woodlands:Destroy()
    error(snapshot)
end
shared.QuarryWoodlandsSnapshot = snapshot
return {trees = counts, probes = #probes, instances = #woodlands:GetDescendants() + 1, exportBytes = #snapshot}
