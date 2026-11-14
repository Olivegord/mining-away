-- Stage the replacement ground and selected original details in the shared Edit place.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing")
local root, storage = workspace.MiningAway, game:GetService("ServerStorage")
local map, old = root.Map, storage.QuarryBlockscapeArchive
local authored = map.DronerevolutionTerraces
local mat = game:GetService("MaterialService")
local v, rgb = Vector3.new, Color3.fromRGB

local function folder(name, parent)
    local instance = Instance.new("Folder")
    instance.Name, instance.Parent = name, parent
    return instance
end

local scene = folder("QuarryContinuousGround")
local floor = folder("Terraces", scene)
local details = folder("OriginalDetails", scene)
local retired = folder("QuarryGroundArchive")
assert(not map:FindFirstChild(scene.Name) and not storage:FindFirstChild(retired.Name))
assert(not shared.QuarryContinuousGround, "Clear the previous stage first")

local moves = {
    map.QuarryBlockscape,
    map.QuarryBiomeReaches,
    map.QuarryWoodlands,
    map.QuarryDepthPass.CobaltForestExtension,
    authored.GrassyRims,
    authored.GroundArt.ExposedStrata,
    authored.AssetScenery.EmeraldScenery["09_Rock"],
}
local plan, parents = {}, {}
for i, item in ipairs(moves) do
    parents[i] = item.Parent
    local descendants = item:GetDescendants()
    for _, child in ipairs(descendants) do
        assert(child:IsA("Folder") or child:IsA("Model") or child:IsA("BasePart")
            or child:IsA("PointLight"), "Unexpected archived instance " .. child:GetFullName())
    end
    plan[i] = {path = item:GetFullName(), descendants = #descendants}
end

local function block(parent, name, center, size, finish, tint)
    local part = Instance.new("Part")
    part.Name, part.Size, part.Position = name, size, center
    part.Anchored, part.CanTouch = true, false
    part.Material, part.MaterialVariant, part.Color = finish.BaseMaterial, finish.Name, tint
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

-- Each footprint uses continuous horizontal slabs. Adjacent slabs meet edge to
-- edge at the same height. The beds sit .025 stud above the turf.
local platforms, surfaces = {}, {}
local function terrace(name, bed, turf, rock, rockTint, rectangles)
    local group = folder(name, floor)
    local top = bed.Position.Y + bed.Size.Y/2 - .025
    platforms[name] = {top = top, rectangles = rectangles}
    for i, rectangle in ipairs(rectangles) do
        local x0, x1, z0, z1 = table.unpack(rectangle)
        local x, z = (x0+x1)/2, (z0+z1)/2
        local bottom = -8
        block(group, "Earth" .. i, v(x,(bottom+top-1.3)/2,z),
            v(x1-x0,top-1.3-bottom,z1-z0), rock, rockTint)
        local surface = block(group, "Turf" .. i, v(x,top-.65,z),
            v(x1-x0,1.3,z1-z0), mat.QuarryPhoto_Grass, turf)
        table.insert(surfaces, {surface, rectangle, top})
    end
end

local fields = root.Fields
local stone, shale, chalk = mat.QuarryPhoto_Slate, mat.QuarryBiome_Shale, mat.QuarryBiome_Chalk
terrace("Quartz", fields.Quartz.Field, rgb(153,173,112), stone, rgb(128,133,139), {
    {-175,-35,52,184}, {-132,-40,184,211},
})
terrace("Impact", fields.ImpactTest.Field, rgb(159,175,110), stone, rgb(151,134,113), {
    {35,169,53,184}, {64,152,184,211}, {169,198,76,131},
})
terrace("Ruby", fields.Ruby.Field, rgb(170,167,111), shale, rgb(144,116,114), {
    {-198,-86,-32,47}, {-198,-132,-123,-32},
})
terrace("Cobalt", fields.Cobalt.Field, rgb(124,164,138), shale, rgb(113,137,156), {
    {86,198,-32,47}, {133,257,-102,-32}, {170,198,47,76},
})
terrace("Violet", fields.Violet.Field, rgb(136,156,119), shale, rgb(132,126,154), {
    {-130,-36,-162,-76}, {-184,-130,-159,-104},
})
terrace("Emerald", fields.Emerald.Field, rgb(135,175,125), chalk, rgb(188,186,172), {
    {36,122,-163,-76}, {122,204,-183,-145}, {80,122,-183,-163},
})

local function footprint(frame, size)
    local h, r, u, f = size/2, frame.RightVector, frame.UpVector, frame.LookVector
    return math.abs(r.X)*h.X+math.abs(u.X)*h.Y+math.abs(f.X)*h.Z,
        math.abs(r.Z)*h.X+math.abs(u.Z)*h.Y+math.abs(f.Z)*h.Z
end

local probes, protected = {}, {}
local function protect(part, samples, margin)
    local hx, hz = footprint(part.CFrame, part.Size)
    table.insert(protected, {part.Position, hx+margin, hz+margin})
    if not samples then return end
    for _, x in ipairs(samples) do
        for _, z in ipairs(samples) do
            local top = part.CFrame:PointToWorldSpace(v(x*part.Size.X, part.Size.Y/2, z*part.Size.Z))
            table.insert(probes, {top, part})
        end
    end
end
local grid = {-.44, -.22, 0, .22, .44}
for _, field in ipairs(fields:GetChildren()) do protect(field.Field, grid, 1) end
for _, route in ipairs(authored.WalkableRoutes:GetChildren()) do
    if not route.Name:find("Curb") then protect(route, grid, 1) end
end
for _, item in ipairs(map.EmeraldChalkLagoon:GetChildren()) do
    if item.Name == "LagoonCauseway" then protect(item, {-.4,0,.4}, .4) end
end
for _, item in ipairs(map:GetDescendants()) do
    if item:IsA("ProximityPrompt") and item.Parent:IsA("BasePart") then protect(item.Parent, nil, 2) end
end

local function fits(name, x, z, hx, hz)
    for _, item in ipairs(protected) do
        if math.abs(x-item[1].X) < hx+item[2] and math.abs(z-item[1].Z) < hz+item[3] then
            return false
        end
    end
    for _, area in ipairs(platforms[name].rectangles) do
        if x-hx >= area[1] and x+hx <= area[2] and z-hz >= area[3] and z+hz <= area[4] then
            return true
        end
    end
    return false
end

local function original(name, near)
    local found, best = nil, math.huge
    for _, container in ipairs({old, authored.AssetScenery}) do
        for _, model in ipairs(container == old and container:GetChildren() or container:GetDescendants()) do
            if model:IsA("Model") and model.Name == name then
                local point = model:GetBoundingBox().Position
                local distance = (v(point.X,0,point.Z)-v(near.X,0,near.Z)).Magnitude
                if distance < best then found, best = model, distance end
            end
        end
    end
    return assert(found, "Missing original " .. name)
end

local groups, count = {}, 0
local function place(name, template, x, z, scale, label)
    local copy
    if template:IsA("Folder") then
        copy = Instance.new("Model")
        for _, item in ipairs(template:GetChildren()) do item:Clone().Parent = copy end
    else
        copy = template:Clone()
    end
    copy.Name = label or template.Name
    copy:ScaleTo(copy:GetScale()*scale)
    local frame, size = copy:GetBoundingBox()
    local hx, hz = footprint(frame, size)
    assert(fits(name, x, z, hx, hz), ("Detail %s lies outside clear %s turf at %s, %s"):format(copy.Name,name,x,z))
    local top = platforms[name].top
    copy:PivotTo(copy:GetPivot() + v(x-frame.X,top-(frame.Y-size.Y/2)-.035,z-frame.Z))
    for _, item in ipairs(copy:GetDescendants()) do
        if item:IsA("BasePart") then
            item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
        end
    end
    if not groups[name] then groups[name] = folder(name, details) end
    copy.Parent = groups[name]
    count += 1
end

-- Leave the approaches open. Trees and rocks anchor spaced groups of smaller
-- native flowers, brush, and grass instead of lining every edge.
local accents = {
    Quartz = {
        {"03_Tree2",-126,139,.78}, {"01_Tree1",-156,165,.62},
        {"09_Rock",-116,133,1.25}, {"08_Bush",-123,146,.9},
        {"21_Flowers",-105,141,.9}, {"17_Grass2",-118,135,1},
        {"24_Flowers",-92,157,1.12}, {"08_Bush",-63,163,.8}, {"09_Rock",-56,168,1.05},
    },
    Impact = {
        {"04_Tree1",124,149,.74}, {"03_Tree2",149,171,.62},
        {"09_Rock",111,138,1.27}, {"08_Bush",119,146,.9},
        {"24_Flowers",100,146,1.04}, {"16_Grass1",111,143,1.05},
        {"23_Flowers",50,154,.9}, {"09_Rock",81,161,.95},
    },
    Ruby = {
        {"03_Tree2",-171,-49,.65}, {"01_Tree1",-182,33,.6},
        {"10_Rock",-161,22,1.3}, {"05_Bush",-156,25,.85},
        {"21_Flowers",-157,32,.82}, {"15_Grass2",-161,27,.83},
        {"24_Flowers",-118,39,1}, {"08_Bush",-125,39,.8},
    },
    Violet = {
        {"04_Tree1",-146,-137,.72}, {"03_Tree2",-113,-150,.73},
        {"10_Rock",-139,-126,1.4}, {"13_Grass1",-134,-132,.9},
        {"07_Bush",-113,-141,.8}, {"21_Flowers",-108,-144,.85},
        {"09_Rock",-49,-151,.95},
    },
    Emerald = {
        {"02_Tree2",111,-137,.81}, {"01_Tree1",101,-173,.59},
        {"09_Rock",116,-143,1.17}, {"06_Bush",110,-148,.92},
        {"23_Flowers",109,-151,.83}, {"16_Grass1",115,-149,.9},
        {"24_Flowers",52,-153,.83}, {"07_Bush",57,-154,.82},
    },
    Cobalt = {
        {"09_Rock",161,32,1.5}, {"15_Grass2",164,29,.9},
        {"09_Rock",172,-44,1.14}, {"22_Flowers",159,-47,.83},
    },
}
for _, name in ipairs({"Quartz","Impact","Ruby","Violet","Emerald","Cobalt"}) do
    local bed = fields[name == "Impact" and "ImpactTest" or name].Field
    for _, entry in ipairs(accents[name]) do
        local template, x, z, scale = table.unpack(entry)
        place(name, original(template, bed.Position), x, z, scale)
    end
end
local grove = old.CobaltMushroomGrove
local trumpet, fan
for _, model in ipairs(grove:GetChildren()) do
    if model:IsA("Model") then
        if model.Name == "Blue Trumpet" and model:GetExtentsSize().Y > 40 then trumpet = model end
        if model.Name == "Coral Fan" and model:GetExtentsSize().Y < 25 then fan = model end
    end
end
place("Cobalt", assert(trumpet), 176,-17,.44,"Blue Trumpet")
place("Cobalt", assert(fan), 165,36,.72,"Coral Fan")
place("Cobalt", fan, 200,-66,.85,"Coral Fan")
for _, item in ipairs({
    {"Shelf01_1",160,41,.85}, {"Shelf01_2",166,42,.72}, {"Shelf02_1",170,-38,.9},
    {"Shelf03_1",184,-35,.78}, {"Shelf02_2",209,-70,.7},
}) do
    place("Cobalt", old.Understory[item[1]], item[2],item[3],item[4],"Small Mushroom")
end

-- Restore one of the original broken Ruby outcrops on its outer terrace.
local rubyCliff = old.RubyCrimsonBluffs:FindFirstChild("FracturedCliff")
place("Ruby", rubyCliff, -181,-84,.57,"Fractured Cliff")

-- Pattern belongs on the small objects. Keep the large turf surfaces quiet.
local accentsFolder = folder("PatternedAccents", scene)
local checker, ribbed = mat.QuarryAccent_Checker, mat.QuarryAccent_Ribbed
local brick, timber, pebbles = mat.QuarryAccent_Brick, mat.QuarryAccent_Timber, mat.QuarryPalette_Pebbles
for _, accent in ipairs({
    {"Quartz",-112,106,6.3,false,pebbles,rgb(226,122,151)},
    {"Quartz",-89,139,5.3,true,checker,rgb(111,149,213)},
    {"Quartz",-137,149,3.2,false,timber,rgb(222,165,90)},
    {"Quartz",-57,137,4.3,false,checker,rgb(235,217,177)},
    {"Impact",110,117,5.1,false,brick,rgb(222,128,94)},
    {"Impact",70,140,5.2,true,checker,rgb(210,180,114)},
    {"Ruby",-145,38,4.7,false,brick,rgb(228,123,102)},
    {"Ruby",-165,-26,5.8,true,checker,rgb(186,127,146)},
    {"Cobalt",131,40,4.3,false,ribbed,rgb(107,153,225)},
    {"Cobalt",150,-45,5.6,true,checker,rgb(147,179,232)},
    {"Violet",-118,-123,4.6,false,pebbles,rgb(177,132,209)},
    {"Violet",-47,-157,5.8,true,checker,rgb(176,153,224)},
    {"Emerald",71,-153,5.2,true,checker,rgb(146,198,163)},
    {"Emerald",99,-151,3.7,false,timber,rgb(217,170,106)},
}) do
    local region, x, z, size, paver, finish, tint = table.unpack(accent)
    local h = paver and .044 or size
    local radius = size * (paver and .5 or .6)
    assert(fits(region,x,z,radius,radius), "Patterned accent overlaps a route or terrace edge")
    local part = block(accentsFolder, paver and "InsetPaver" or "SampleBlock",
        v(x,platforms[region].top+h/2,z), v(size,h,size), finish, tint)
    if not paver then part.Orientation = v(0,12,0) end
    part.CanCollide, part.CanQuery = false, false
    part.CastShadow = not paver
end

local serialize, enc = game:GetService("SerializationService"), game:GetService("EncodingService")
local http = game:GetService("HttpService")
local function encode(bytes)
    return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(bytes, Enum.CompressionAlgorithm.Zstd)))
end
local snapshot = {
    scenery = encode(serialize:SerializeInstancesAsync({scene})),
    archive = encode(serialize:SerializeInstancesAsync({retired})),
    moves = encode(buffer.fromstring(http:JSONEncode(plan))),
}

local function undo()
    scene.Parent = nil
    for i, item in ipairs(moves) do item.Parent = parents[i] end
    retired.Parent = nil
end
local function apply()
    assert(not scene.Parent and not retired.Parent, "Already installed")
    for i, item in ipairs(moves) do assert(item.Parent == parents[i], "Concurrent map edit") end
    local ray = RaycastParams.new()
    ray.RespectCanCollide = true
    local function ground(at)
        return workspace:Raycast(at + v(0,5,0),v(0,-5.5,0),ray)
    end
    local before = {}
    for i, probe in ipairs(probes) do before[i] = ground(probe[1]) or false end

    retired.Parent = storage
    for _, item in ipairs(moves) do item.Parent = retired end
    scene.Parent = map
    local flat = 0
    local ok, issue = pcall(function()
        for i, probe in ipairs(probes) do
            local hit, prior = ground(probe[1]), before[i]
            assert((not hit and not prior) or (hit and prior and hit.Instance == prior.Instance
                and (hit.Position-prior.Position).Magnitude < .025),
                ("%s clearance changed at %s (was %s, now %s)"):format(probe[2].Name, tostring(probe[1]),
                    prior and prior.Instance.Name or "none", hit and hit.Instance.Name or "none"))
        end
        for _, entry in ipairs(surfaces) do
            local part, area, top = table.unpack(entry)
            local x0,x1,z0,z1 = table.unpack(area)
            for _, a in ipairs({.015,.15,.32,.5,.68,.85,.985}) do
                for _, b in ipairs({.015,.15,.32,.5,.68,.85,.985}) do
                    local at = v(x0+(x1-x0)*a,top,z0+(z1-z0)*b)
                    local hit = workspace:Raycast(at + v(0,.45,0),v(0,-.58,0),ray)
                    assert(hit and (hit.Instance == part or hit.Instance.Name == "Field"
                        or hit.Instance:IsDescendantOf(authored.WalkableRoutes))
                        and math.abs(hit.Position.Y-top) < (hit.Instance:IsDescendantOf(authored.WalkableRoutes) and .34 or .11),
                        ("Unexpected ground over %s at %s (%s)"):format(part:GetFullName(),tostring(at),
                            hit and (hit.Instance:GetFullName() .. " at " .. tostring(hit.Position.Y)) or "none"))
                    flat += 1
                end
            end
        end
    end)
    if not ok then undo(); error(issue) end
    return {details=count, floors=#surfaces, flatProbes=flat, routeAndFieldProbes=#probes}
end
shared.QuarryContinuousGround = {snapshot=snapshot, apply=apply, undo=undo}
return {details=count, floors=#surfaces, sceneryBytes=#snapshot.scenery}
