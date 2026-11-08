-- Stage two themed displays, the unassigned samples, and the native Tech library.
local function checkEdit()
    assert(not game:GetService("RunService"):IsRunning(), "Expected Studio Edit")
    assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong experience")
end
checkEdit()
local map = workspace.MiningAway.Map
local deck = map.DronerevolutionTerraces.LogisticsApron.ServiceDeck
local old = map.JunkCubeLineup
local library = game.ServerStorage.JunkCubeTemplates
local candy = library.GumballDispenser
local oldCandy, newCandy = "rbxassetid://101810481156570", "rbxassetid://71489321433210"
local function checkBaseline()
    assert(map:FindFirstChild(old.Name) == old and #old:GetChildren() == 23, "Expected the 23-cube display")
    assert(not map:FindFirstChild("JunkCubeAreas") and not library:FindFirstChild("Tech"))
    for _, decal in ipairs(candy:GetChildren()) do assert(decal.Texture == oldCandy, decal.Name) end
end
checkBaseline()

local tech = Instance.new("Folder")
tech.Name = "Tech"
local specs = {
    Motherboard = {139223200425797, 6.4},
    CartridgeFuses = {83167278370582, 5.2},
    CircuitTraces = {98043205815744, 5.8},
    RibbonCable = {104263900865294, 5.4},
    FuseBox = {102847719502485, 6.1},
    HeatSink = {70475352234682, 6.3},
}
for name, spec in pairs(specs) do
    local p = Instance.new("Part")
    p.Name = name
    p.Material = Enum.Material.SmoothPlastic
    p.Size = Vector3.one * spec[2]
    p.Anchored = true
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
        local decal = Instance.new("Decal")
        decal.Name = face.Name
        decal.Face = face
        decal.Texture = "rbxassetid://" .. spec[1]
        decal.Parent = p
    end
    p.Parent = tech
end

local areas = Instance.new("Folder")
areas.Name = "JunkCubeAreas"
local decals, occupied, used = {}, {}, {}
local supportSamples = 0
local function support(localPoint)
    assert(math.abs(localPoint.X) < deck.Size.X/2 and math.abs(localPoint.Z) < deck.Size.Z/2)
    local ground = deck.CFrame:PointToWorldSpace(localPoint)
    local hit = workspace:Raycast(ground + Vector3.yAxis*10, -Vector3.yAxis*10.5)
    assert(hit and hit.Instance == deck and (hit.Position-ground).Magnitude < .01,
        "Unexpected ServiceDeck obstruction at " .. tostring(localPoint))
    supportSamples += 1
end
local function area(name, title, x, z, color)
    local group = Instance.new("Folder")
    group.Name = name
    group.Parent = areas
    local sign = Instance.new("Part")
    sign.Name = "Label"
    sign.Size = Vector3.new(20, 1.7, .15)
    sign.CFrame = deck.CFrame * CFrame.new(x, deck.Size.Y/2+sign.Size.Y/2, z) * CFrame.Angles(0, math.pi, 0)
    sign.Anchored = true
    sign.CanCollide, sign.CanTouch, sign.CanQuery = false, false, false
    sign.CastShadow = false
    sign.Material = Enum.Material.SmoothPlastic
    sign.Color = color
    sign.Parent = group
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(640, 54)
    gui.Parent = sign
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(252, 244, 224)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 44
    label.Text = title
    label.Parent = gui
    support(Vector3.new(x, deck.Size.Y/2, z))
    return group
end
local function add(group, source, name, x, z, yaw)
    assert(source and not used[source], name)
    used[source] = true
    local p = source:Clone()
    p.Name = name
    local half = p.Size.X/2
    local angle = math.rad(group.Name == "Tech" and 0 or yaw)
    local radius = half*(math.abs(math.cos(angle))+math.abs(math.sin(angle)))
    for _, other in ipairs(occupied) do
        assert(math.abs(other.x-x) > other.radius+radius+.3 or math.abs(other.z-z) > other.radius+radius+.3,
            "Display cubes overlap: " .. name)
    end
    table.insert(occupied, {x=x,z=z,radius=radius})
    for _, offset in ipairs({{0,0},{-radius,-radius},{radius,-radius},{-radius,radius},{radius,radius}}) do
        support(Vector3.new(x+offset[1], deck.Size.Y/2, z+offset[2]))
    end
    p.CFrame = deck.CFrame * CFrame.new(x, deck.Size.Y/2+half, z) * CFrame.Angles(0, math.pi+angle, 0)
    for _, d in ipairs(p:GetChildren()) do
        if d:IsA("Decal") then
            if name == "Gumballs" then d.Texture = newCandy end
            table.insert(decals, d)
        end
    end
    p.Parent = group
end
local craft = area("ArtsAndCrafts", "01  ARTS & CRAFTS", -18, 34, Color3.fromRGB(105, 65, 55))
local science = area("Tech", "02  TECH", 18, 34, Color3.fromRGB(42, 72, 72))
local samples = area("Unassigned", "UNASSIGNED", 0, -17, Color3.fromRGB(81, 72, 63))
local function arrange(group, rows)
    for _, row in ipairs(rows) do
        local name, x, z, yaw, key = table.unpack(row)
        add(group, key and tech[key] or old[name], name, x, z, yaw)
    end
end
arrange(craft, {
    {"Blue Gingham",-27,25,-6}, {"Daisy Cube",-17,24,7}, {"Fired Brick",-7,26,-4},
    {"Stars",-29,14,6}, {"Red Gingham",-19,12,-7}, {"Knit Block",-9,14,4},
    {"Alphabet Block",-26,3,-5}, {"Pip Block",-15,2,5}, {"Brick",-5,3,-3},
    {"Battered Crate",-28,-8,4}, {"Suggestion Box",-18,-9,-6}, {"Moving Box",-7,-9,6},
})
arrange(science, {
    {"Glass Fuses",8,23,5,"CartridgeFuses"}, {"Motherboard",19,24,-4,"Motherboard"},
    {"Circuit Traces",29,23,6,"CircuitTraces"}, {"Box Fan",9,12,-6},
    {"Ribbon Cable",19,12,5,"RibbonCable"}, {"Fuse Box",28,11,-6,"FuseBox"},
    {"Heat Sink",14,1,-4,"HeatSink"}, {"Blue Ribs",26,0,6},
})
arrange(samples, {
    {"Gumballs",-29,-24,-5}, {"Waves",-18,-24,6}, {"Ticket Box",-7,-25,-6},
    {"Checker",6,-24,5}, {"Ice Cube",17,-24,-4}, {"Cube Aquarium",28,-24,5},
    {"Pebbles",-21,-34,6}, {"Rose Stone",-8,-34,-5}, {"Gold Studs",8,-34,6},
})
for _, p in ipairs(old:GetChildren()) do assert(used[p], p.Name) end
for _, p in ipairs(tech:GetChildren()) do assert(used[p], p.Name) end
local content = game:GetService("ContentProvider")
content:PreloadAsync(decals)
for _, d in ipairs(decals) do
    assert(content:GetAssetFetchStatus(d.Texture) == Enum.AssetFetchStatus.Success, d.Texture)
end
local serialize, encode = game:GetService("SerializationService"), game:GetService("EncodingService")
local function export(root)
    local data = serialize:SerializeInstancesAsync({root})
    return buffer.tostring(encode:Base64Encode(encode:CompressBuffer(data, Enum.CompressionAlgorithm.Zstd)))
end
local exports = {display=export(areas), tech=export(tech)}
local function apply()
    checkEdit()
    checkBaseline()
    for _, decal in ipairs(candy:GetChildren()) do decal.Texture = newCandy end
    tech.Parent = library
    areas.Parent = map
    old:Destroy()
    return {cubes=#occupied, supportSamples=supportSamples}
end
shared.JunkAreasStage = {apply=apply}
return {exports=exports, cubes=#occupied, supportSamples=supportSamples}
