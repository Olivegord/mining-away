-- Toy World pass (owner, Nov 18): one colorful, simple, abstract map.
-- Keeps every gameplay part where it is; recolors them, archives the classic
-- Crystal Run strips and extra props, and adds abstract shapes plus particles
-- that explain what each place does. Stage first (nothing changes), then
-- shared.ToyWorld.apply() in Edit. shared.ToyWorld.undo() reverts it.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing the map")
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong experience: expected DRONEREVOLUTION")

local storage = game:GetService("ServerStorage")
local root = assert(workspace:FindFirstChild("MiningAway"))
local map = assert(root:FindFirstChild("Map"))
local fieldsFolder = assert(root:FindFirstChild("Fields"))
assert(not map:FindFirstChild("ToyWorld") and not storage:FindFirstChild("ToyWorldArchive"), "Toy World already installed")
local run = assert(map:FindFirstChild("CrystalRun"))
local depot = assert(map:FindFirstChild("SimpleFlatTestMap"))

local v, rgb = Vector3.new, Color3.fromRGB
local ZONES = {rgb(255, 170, 40), rgb(255, 72, 96), rgb(80, 190, 255), rgb(176, 102, 255), rgb(255, 150, 232)}
local CREAM, INK = rgb(255, 243, 222), rgb(44, 38, 74)
local PASTELS = {rgb(255, 196, 120), rgb(255, 150, 170), rgb(150, 210, 255), rgb(200, 160, 255), rgb(255, 180, 230),
    rgb(140, 230, 190), rgb(255, 226, 120)}
local GROUND_TOP = 4.0

local scenery = Instance.new("Folder")
scenery.Name = "ToyWorld"
local archive = Instance.new("Folder")
archive.Name = "ToyWorldArchive"

local function folder(parent, name)
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end
local function part(parent, name, shape, size, cframe, color, opts)
    opts = opts or {}
    local p = Instance.new("Part")
    p.Name = name
    p.Shape = shape or Enum.PartType.Block
    p.Size = size
    p.CFrame = cframe
    p.Color = color
    p.Material = opts.material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = opts.collide == true
    p.CanTouch = false
    p.CanQuery = opts.collide == true
    p.CastShadow = opts.shadow ~= false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end
-- A flat disc lying on the ground (cylinders run along X).
local function disc(parent, name, center, diameter, thickness, color, collide)
    return part(parent, name, Enum.PartType.Cylinder, v(thickness, diameter, diameter),
        CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, {collide = collide})
end
local function sparkles(host, name, color, opts)
    local a = Instance.new("Attachment")
    a.Name = name .. "Point"
    a.Position = opts.offset or v(0, 0, 0)
    a.Parent = host
    local e = Instance.new("ParticleEmitter")
    e.Name = name
    e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
    e.LightEmission = opts.light or .6
    e.LightInfluence = 0
    e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, opts.size or .5), NumberSequenceKeypoint.new(.7, (opts.size or .5) * .7),
        NumberSequenceKeypoint.new(1, 0)})
    e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .15), NumberSequenceKeypoint.new(.8, .35), NumberSequenceKeypoint.new(1, 1)})
    e.Lifetime = NumberRange.new(opts.life or 1.6, (opts.life or 1.6) * 1.4)
    e.Rate = opts.rate or 6
    e.Speed = NumberRange.new(opts.speed or 2, (opts.speed or 2) * 1.6)
    e.SpreadAngle = opts.spread or Vector2.new(25, 25)
    e.Acceleration = opts.accel or v(0, 0, 0)
    e.Drag = opts.drag or 0
    e.RotSpeed = NumberRange.new(-60, 60)
    e.Rotation = NumberRange.new(0, 360)
    e.EmissionDirection = opts.direction or Enum.NormalId.Top
    if opts.shapeSize then
        e.Shape = Enum.ParticleEmitterShape.Box
        e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        a.Parent = host
    end
    e.Parent = a
    return e
end

-- Every rectangle where play happens; decorations stay out of them.
local beds = {}
for tier, name in ipairs({"Quartz", "Ruby", "Cobalt", "Violet", "Emerald"}) do
    local bed = assert(run:FindFirstChild(name) and run[name]:FindFirstChild("Field"), "Missing field " .. name)
    assert(bed:GetAttribute("CrystalZone") == tier and bed:GetAttribute("WholeField"), "Unexpected field " .. name)
    beds[tier] = bed
end
local hub = assert(depot:FindFirstChild("HubPad"))
local keepOut = {}
for _, bed in ipairs(beds) do table.insert(keepOut, {bed.Position, bed.Size / 2 + v(3, 0, 3), "field"}) end
local function blocked(x, z, radius)
    for _, area in ipairs(keepOut) do
        if math.abs(x - area[1].X) < area[2].X + radius and math.abs(z - area[1].Z) < area[2].Z + radius then return true end
    end
    return false
end

-- 1. Fields: a colored tile under each bed and a beacon whose stacked pips
-- show how hard the field is (1 = easy, 5 = hardest).
local fieldArt = folder(scenery, "Fields")
for tier, bed in ipairs(beds) do
    local zone = ZONES[tier]
    local f = folder(fieldArt, bed.Parent.Name)
    -- Beacon on the corner that faces the hub.
    local cx = bed.Position.X + (bed.Position.X >= 0 and -1 or 1) * (bed.Size.X / 2 + 3.5)
    local cz = bed.Position.Z + bed.Size.Z / 2 + 3.5
    local height = 7 + tier * 1.6
    local post = part(f, "Beacon", nil, v(1.6, height, 1.6), CFrame.new(cx, GROUND_TOP + height / 2, cz), CREAM, {collide = true})
    local cap = part(f, "BeaconCap", Enum.PartType.Ball, v(3.2, 3.2, 3.2), CFrame.new(cx, GROUND_TOP + height + 1.4, cz), zone,
        {material = Enum.Material.Neon})
    for pip = 1, tier do
        part(f, "Pip" .. pip, Enum.PartType.Ball, v(1.1, 1.1, 1.1),
            CFrame.new(cx, GROUND_TOP + 1.6 + (pip - 1) * 1.45, cz) * CFrame.new(0, 0, .95), zone)
    end
    sparkles(cap, "FieldBeacon", zone, {rate = 3 + tier, life = 2.2, speed = 1.6, size = .55, spread = Vector2.new(35, 35),
        accel = v(0, 1.2, 0)})
    local glow = Instance.new("PointLight")
    glow.Color = zone
    glow.Range = 12
    glow.Brightness = 1.2
    glow.Parent = cap
    post:SetAttribute("Tier", tier)
end

-- 2. Stepping-stone paths: hub -> field 1 -> fields 2 and 3 -> fields 4 and 5.
local paths = folder(scenery, "Paths")
local function edgePoint(bed, toward)
    local c = bed.Position
    local d = (toward - c) * v(1, 0, 1)
    local s = math.min(math.abs((bed.Size.X / 2 + 3) / (d.X ~= 0 and d.X or 1e-6)), math.abs((bed.Size.Z / 2 + 3) / (d.Z ~= 0 and d.Z or 1e-6)))
    return c + d * s
end
local routes = {
    {v(0, 0, hub.Position.Z - hub.Size.Z / 2 + 2), edgePoint(beds[1], v(0, 0, 0)), 1},
    {edgePoint(beds[1], beds[2].Position), edgePoint(beds[2], beds[1].Position), 2},
    {edgePoint(beds[1], beds[3].Position), edgePoint(beds[3], beds[1].Position), 3},
    {edgePoint(beds[2], beds[4].Position), edgePoint(beds[4], beds[2].Position), 4},
    {edgePoint(beds[3], beds[5].Position), edgePoint(beds[5], beds[3].Position), 5},
}
local stones = 0
for _, route in ipairs(routes) do
    local a, b, tier = route[1] * v(1, 0, 1), route[2] * v(1, 0, 1), route[3]
    local length = (b - a).Magnitude
    local count = math.max(2, math.floor(length / 4.2))
    for i = 0, count do
        local p = a:Lerp(b, i / count)
        if not blocked(p.X, p.Z, -2.5) then
            local color = (i % 2 == 0) and CREAM or ZONES[tier]:Lerp(CREAM, .55)
            disc(paths, "Stone", v(p.X, GROUND_TOP + .12, p.Z), i % 2 == 0 and 3.2 or 2.4, .25, color, true)
            stones += 1
        end
    end
end

-- 3. Hub: a flower plaza around spawn.
local hubArt = folder(scenery, "Hub")
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local center = spawn and spawn.Position * v(1, 0, 1) or v(0, 0, 12)
disc(hubArt, "Plaza", v(center.X, GROUND_TOP + .06, center.Z), 17, .14, rgb(255, 214, 102), true)
disc(hubArt, "PlazaCore", v(center.X, GROUND_TOP + .1, center.Z), 8, .14, rgb(255, 250, 236), true)
for i = 1, 8 do
    local a = i / 8 * math.pi * 2
    disc(hubArt, "Petal", v(center.X + math.cos(a) * 10.5, GROUND_TOP + .06, center.Z + math.sin(a) * 10.5), 5.4, .14,
        ZONES[(i - 1) % 5 + 1]:Lerp(CREAM, .35), true)
end

-- 4. Station markers: shapes and particles say what each place does.
local stations = folder(scenery, "Stations")
local function above(p, dy) return p.Position + v(0, p.Size.Y / 2 + dy, 0) end
local pack = depot.PackStationAssembly.PackStation
for i = -1, 1 do -- three fanned cards: packs give you a card to pick
    local cf = CFrame.new(above(pack, 3.4)) * CFrame.Angles(0, 0, math.rad(-i * 18)) * CFrame.new(i * 1.8, 0, 0)
    part(stations, "PackCard", nil, v(2.6, 3.6, .18), cf, ZONES[i + 2])
    part(stations, "PackCardFace", nil, v(2, 3, .2), cf * CFrame.new(0, 0, -.02), rgb(255, 252, 240))
end
local packGlow = part(stations, "PackSpark", Enum.PartType.Ball, v(.6, .6, .6), CFrame.new(above(pack, 1.2)), rgb(255, 214, 90),
    {material = Enum.Material.Neon, shadow = false})
packGlow.Transparency = 1
sparkles(packGlow, "PackSparkles", rgb(255, 210, 80), {rate = 10, life = 1.4, speed = 3, size = .45, spread = Vector2.new(40, 40), accel = v(0, 2, 0)})
local printer = depot.PrinterAssembly.Printer
for i = 1, 3 do -- little cubes: this is where drones come from
    local cf = CFrame.new(above(printer, 2.4 + i * .7)) * CFrame.new((i - 2) * 2.4, 0, 0) * CFrame.Angles(math.rad(20 * i), math.rad(35 * i), 0)
    part(stations, "PrinterCube", nil, v(1.5, 1.5, 1.5), cf, ZONES[i + 1])
end
local printerGlow = part(stations, "PrinterSpark", Enum.PartType.Ball, v(.6, .6, .6), CFrame.new(above(printer, .8)), rgb(120, 220, 255),
    {material = Enum.Material.Neon, shadow = false})
printerGlow.Transparency = 1
sparkles(printerGlow, "PrinterSparkles", rgb(120, 220, 255), {rate = 8, life = 1.2, speed = 2.5, size = .4, spread = Vector2.new(50, 50), accel = v(0, 2.5, 0)})
local prestige = depot.PrestigeStationAssembly.PrestigeStation
local spire = part(stations, "PrestigeSpire", nil, v(1.8, 13, 1.8),
    CFrame.new(prestige.Position.X, GROUND_TOP + 6.5, prestige.Position.Z + prestige.Size.Z / 2 + 2.2) * CFrame.Angles(0, math.rad(45), 0),
    rgb(176, 102, 255), {collide = true})
local star = part(stations, "PrestigeStar", Enum.PartType.Ball, v(2.6, 2.6, 2.6), CFrame.new(spire.Position + v(0, 8.2, 0)),
    rgb(255, 236, 140), {material = Enum.Material.Neon})
sparkles(star, "PrestigeSparkles", rgb(220, 170, 255), {rate = 9, life = 2, speed = 2.2, size = .5, spread = Vector2.new(180, 180), drag = 1.5})
local converter = workspace:FindFirstChild("Converter")
if converter then -- coins rise from the sell counter
    local coin = part(stations, "SellCoinSpout", Enum.PartType.Ball, v(.6, .6, .6), CFrame.new(above(converter, .6)), rgb(255, 214, 74),
        {material = Enum.Material.Neon, shadow = false})
    coin.Transparency = 1
    sparkles(coin, "SellCoins", rgb(255, 214, 74), {rate = 6, life = 1.3, speed = 4, size = .6, spread = Vector2.new(30, 30), accel = v(0, -6, 0)})
end
local charger = run:FindFirstChild("ChargingStation")
if charger then -- zappy sparks: drones recharge here
    for _, side in ipairs({-1, 1}) do
        local pylon = part(stations, "ChargePylon", nil, v(1, 5, 1), CFrame.new(charger.Position + v(side * 5.6, .4 + 2.5, 0)), rgb(255, 226, 90), {collide = true})
        local tip = part(stations, "ChargeTip", Enum.PartType.Ball, v(1.4, 1.4, 1.4), CFrame.new(pylon.Position + v(0, 3, 0)), rgb(140, 255, 160),
            {material = Enum.Material.Neon})
        sparkles(tip, "ChargeSparks", rgb(150, 255, 170), {rate = 7, life = .5, speed = 6, size = .3, spread = Vector2.new(180, 180), drag = 6})
    end
end
for _, info in ipairs({{"QuartzShop", rgb(80, 190, 255)}, {"RubyShop", rgb(255, 196, 64)}}) do
    local shop = map:FindFirstChild(info[1])
    if shop then
        local obelisk = part(stations, "ShopObelisk", nil, v(2, 9, 2),
            CFrame.new(shop.Position.X + 6.2, GROUND_TOP + 4.5, shop.Position.Z - 1) * CFrame.Angles(0, math.rad(45), 0), info[2], {collide = true})
        local top = part(stations, "ShopObeliskTop", Enum.PartType.Ball, v(2.4, 2.4, 2.4), CFrame.new(obelisk.Position + v(0, 5.6, 0)), CREAM,
            {material = Enum.Material.Neon})
        sparkles(top, "ShopSparkles", info[2], {rate = 5, life = 1.6, speed = 1.8, size = .45, spread = Vector2.new(60, 60), accel = v(0, 1.5, 0)})
    end
end

-- 5. Abstract scenery around the island: lollipop trees, bubble hills in the
-- sea and slow floating shapes in the sky. None of it looks like a rock.
local nature = folder(scenery, "Shapes")
local rng = Random.new(1118)
local island = assert(run:FindFirstChild("FlatGround"))
local iMin = island.Position - island.Size / 2
local iMax = island.Position + island.Size / 2
local trees = 0
local function tree(x, z, scale)
    local h = (5 + rng:NextNumber() * 4) * scale
    local top = PASTELS[rng:NextInteger(1, #PASTELS)]
    part(nature, "TreeStem", Enum.PartType.Cylinder, v(h, .8 * scale, .8 * scale),
        CFrame.new(x, GROUND_TOP + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), CREAM, {collide = true})
    local d = (4.5 + rng:NextNumber() * 3) * scale
    part(nature, "TreeTop", Enum.PartType.Ball, v(d, d, d), CFrame.new(x, GROUND_TOP + h + d * .35, z), top, {collide = true})
    trees += 1
end
-- Along the island's long edges and around the hub corners.
for i = 0, 13 do
    local z = iMin.Z + 12 + i * (island.Size.Z - 24) / 13
    for _, x in ipairs({iMin.X + 5 + rng:NextNumber() * 4, iMax.X - 5 - rng:NextNumber() * 4}) do
        if not blocked(x, z, 3) then tree(x, z, .9 + rng:NextNumber() * .5) end
    end
end
for _, corner in ipairs({v(-44, 0, -40), v(44, 0, -40), v(-46, 0, 44), v(46, 0, 44), v(-46, 0, 2), v(46, 0, 2)}) do
    tree(corner.X, corner.Z, 1.15)
end
-- Interior clusters between fields.
for _ = 1, 40 do
    local x = iMin.X + 10 + rng:NextNumber() * (island.Size.X - 20)
    local z = iMin.Z + 10 + rng:NextNumber() * (island.Size.Z - 20)
    local nearPath = false
    for _, route in ipairs(routes) do
        local a, b = route[1] * v(1, 0, 1), route[2] * v(1, 0, 1)
        local ab = b - a
        local t = math.clamp((v(x, 0, z) - a):Dot(ab) / ab:Dot(ab), 0, 1)
        if ((a + ab * t) - v(x, 0, z)).Magnitude < 7 then nearPath = true end
    end
    if not nearPath and not blocked(x, z, 6) and trees < 52 then tree(x, z, .8 + rng:NextNumber() * .4) end
end
local hills = 0
for i = 1, 14 do
    local a = i / 14 * math.pi * 2 + rng:NextNumber() * .3
    local rx, rz = 150 + rng:NextNumber() * 60, 190 + rng:NextNumber() * 60
    local x, z = math.cos(a) * rx, -110 + math.sin(a) * rz
    local d = 18 + rng:NextNumber() * 26
    part(nature, "BubbleHill", Enum.PartType.Ball, v(d, d, d), CFrame.new(x, 3.8 - d * .18, z), PASTELS[(i - 1) % #PASTELS + 1], {collide = true})
    hills += 1
end
local kinds = {Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder}
for i = 1, 12 do
    local a = i / 12 * math.pi * 2
    local x, z = math.cos(a) * (120 + rng:NextNumber() * 40), -110 + math.sin(a) * (150 + rng:NextNumber() * 40)
    -- Keep the sky over the hub clear so the view from spawn stays open.
    if math.abs(x) < 80 and z > -70 then continue end
    local s = 5 + rng:NextNumber() * 7
    local shape = kinds[(i - 1) % 3 + 1]
    local size = shape == Enum.PartType.Cylinder and v(s * .45, s, s) or v(s, s, s)
    part(nature, "SkyShape", shape, size, CFrame.new(x, 30 + rng:NextNumber() * 18, z)
        * CFrame.Angles(rng:NextNumber() * 3, rng:NextNumber() * 3, rng:NextNumber() * 3), ZONES[(i - 1) % 5 + 1]:Lerp(CREAM, .25), {shadow = false})
end

-- 6. Recolor the gameplay parts; geometry and names are unchanged.
local edits, editHandles = {}, {}
local function bytes(c) return {math.floor(c.R * 255 + .5), math.floor(c.G * 255 + .5), math.floor(c.B * 255 + .5)} end
local function recolor(p, color)
    assert(p and p.ClassName == "Part", "Expected a Part")
    local pos = p.Position
    table.insert(edits, {path = p:GetFullName(), class = "Part", anchor = {pos.X, pos.Y, pos.Z},
        before = {color = bytes(p.Color)}, after = {color = bytes(color)}})
    table.insert(editHandles, {p, p.Color, color})
end
recolor(fieldsFolder.Baseplate, rgb(132, 206, 255)) -- pastel sea
recolor(island, rgb(156, 222, 118)) -- bright grass island
recolor(hub, rgb(255, 214, 190))
for tier, bed in ipairs(beds) do recolor(bed, ZONES[tier]:Lerp(rgb(255, 255, 255), .3)) end
recolor(depot.PackStationAssembly.PackStationPad, rgb(255, 226, 140))
recolor(depot.PackStationAssembly.PackStation, rgb(255, 186, 52))
recolor(depot.PrinterAssembly.PrinterPad, rgb(170, 230, 255))
recolor(depot.PrinterAssembly.Printer, rgb(70, 186, 255))
recolor(depot.PrestigeStationAssembly.PrestigeStationPad, rgb(222, 196, 255))
recolor(depot.PrestigeStationAssembly.PrestigeStation, rgb(160, 104, 255))
if converter then recolor(converter, rgb(96, 222, 150)) end
if charger then recolor(charger, rgb(78, 70, 128)) end
for _, info in ipairs({{"QuartzShop", "QuartzCounter", rgb(70, 170, 255), rgb(236, 248, 255)}, {"RubyShop", "StarCounter", rgb(255, 176, 40), rgb(255, 244, 210)}}) do
    local shop = map:FindFirstChild(info[1])
    local counter = shop and shop:FindFirstChild(info[2])
    if counter then
        recolor(counter.Base, info[3])
        recolor(counter.Top, info[4])
    end
    if shop and shop:FindFirstChild("ShopSign") then recolor(shop.ShopSign, INK) end
end

-- 7. Bright midday light: a plain blue sky and a soft blue haze replace
-- the grey sunset skybox and brown haze (both archived).
local lighting = game:GetService("Lighting")
local oldSky = assert(lighting:FindFirstChildOfClass("Sky"))
local oldAir = assert(lighting:FindFirstChildOfClass("Atmosphere"))
local sky = Instance.new("Sky")
sky.Name = "ToyWorldSky"
sky.StarCount = 0
sky.SunAngularSize = 14
sky.MoonAngularSize = 0
local air = Instance.new("Atmosphere")
air.Name = "ToyWorldAir"
air.Density = .2
air.Offset = .12
air.Color = rgb(206, 232, 255)
air.Decay = rgb(120, 170, 230)
air.Glare = 0
air.Haze = .3
local light = {before = {ClockTime = lighting.ClockTime, Brightness = lighting.Brightness, Ambient = lighting.Ambient,
    OutdoorAmbient = lighting.OutdoorAmbient, ExposureCompensation = lighting.ExposureCompensation},
    after = {ClockTime = 13, Brightness = 2.2, Ambient = rgb(120, 124, 140), OutdoorAmbient = rgb(128, 136, 156), ExposureCompensation = -.25}}
local function floats(c) return {c.R, c.G, c.B} end
local lightPlan = {before = {TimeOfDay = lighting.TimeOfDay, Brightness = lighting.Brightness, Ambient = floats(lighting.Ambient),
    OutdoorAmbient = floats(lighting.OutdoorAmbient), ExposureCompensation = lighting.ExposureCompensation}, after = {}}
for k, value in pairs(light.after) do
    lightPlan.after[k == "ClockTime" and "TimeOfDay" or k] = typeof(value) == "Color3" and floats(value) or value
end
lightPlan.after.TimeOfDay = "13:00:00"

-- 8. Archive (never delete): the classic strips, the specimen row, duplicate
-- plates, sign posts and the grey checker textures.
local moves, moveHandles = {}, {}
local function move(inst)
    assert(inst, "Missing archive item")
    local parts = 0
    for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
    if inst:IsA("BasePart") then parts += 1 end
    table.insert(moves, {path = inst:GetFullName(), class = inst.ClassName, descendants = #inst:GetDescendants(), parts = parts})
    table.insert(moveHandles, {inst, inst.Parent})
end
move(fieldsFolder:FindFirstChild("CrystalRun"))
move(map:FindFirstChild("MineralLineup"))
move(map:FindFirstChild("DepotStationPlates"))
move(map:FindFirstChild("ShopSignPosts"))
move(fieldsFolder.Baseplate:FindFirstChild("Texture"))
move(hub:FindFirstChild("MiningAwayChecker"))
move(oldSky)
move(oldAir)

-- Decorations must not intrude on any bed, the hub's open middle or paths.
local newParts = 0
for _, p in ipairs(scenery:GetDescendants()) do
    if p:IsA("BasePart") then
        newParts += 1
        if p.Name ~= "Stone" and p.Name ~= "SkyShape" then
            assert(not blocked(p.Position.X, p.Position.Z, -1), "Decoration inside a field: " .. p:GetFullName())
        end
    end
end

local serialize = game:GetService("SerializationService")
local enc = game:GetService("EncodingService")
local http = game:GetService("HttpService")
local function encode(b) return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(b, Enum.CompressionAlgorithm.Zstd))) end
local snapshot = {
    scenery = encode(serialize:SerializeInstancesAsync({scenery})),
    archive = encode(serialize:SerializeInstancesAsync({archive})),
    moves = encode(buffer.fromstring(http:JSONEncode(moves))),
    edits = encode(buffer.fromstring(http:JSONEncode(edits))),
    sky = encode(serialize:SerializeInstancesAsync({sky})),
    air = encode(serialize:SerializeInstancesAsync({air})),
    lighting = encode(buffer.fromstring(http:JSONEncode(lightPlan))),
}

local function undo()
    for _, e in ipairs(editHandles) do e[1].Color = e[2] end
    for _, h in ipairs(moveHandles) do h[1].Parent = h[2] end
    scenery.Parent, archive.Parent, sky.Parent, air.Parent = nil, nil, nil, nil
    for k, value in pairs(light.before) do lighting[k] = value end
end
local function apply()
    assert(not scenery.Parent and not archive.Parent, "Already installed")
    for _, h in ipairs(moveHandles) do assert(h[1].Parent == h[2], "Concurrent map change: " .. h[1]:GetFullName()) end
    for _, e in ipairs(editHandles) do assert(e[1].Color == e[2], "Concurrent color change: " .. e[1]:GetFullName()) end
    local history = game:GetService("ChangeHistoryService")
    local recording = history:TryBeginRecording("Toy World")
    archive.Parent = storage
    for _, h in ipairs(moveHandles) do h[1].Parent = archive end
    scenery.Parent = map
    for _, e in ipairs(editHandles) do e[1].Color = e[3] end
    sky.Parent, air.Parent = lighting, lighting
    for k, value in pairs(light.after) do lighting[k] = value end
    if recording then history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
    return {newParts = newParts, stones = stones, trees = trees, hills = hills, edits = #edits, archived = #moves}
end
shared.ToyWorld = {snapshot = snapshot, apply = apply, undo = undo, scenery = scenery}
return {newParts = newParts, stones = stones, trees = trees, hills = hills, edits = #edits, moves = #moves,
    sceneryBytes = #snapshot.scenery}
