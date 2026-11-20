-- Quarry World restyle (owner, Nov 18): the Toy World read as tiny candyland.
-- Keep it simple and abstract but with few colors: sand, stone, slate and a
-- muted green, with the five field colors as the only strong accents. Make the
-- world feel big with stepped terraces, tall monoliths and distant mesas in
-- haze. Restore the glowing mineral display stands. Stage first (nothing
-- changes), then shared.QuarryWorld.apply() in Edit; undo() reverts it.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing the map")
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong experience: expected DRONEREVOLUTION")

local storage = game:GetService("ServerStorage")
local lighting = game:GetService("Lighting")
local root = assert(workspace:FindFirstChild("MiningAway"))
local map = assert(root:FindFirstChild("Map"))
local fieldsFolder = assert(root:FindFirstChild("Fields"))
local toy = assert(map:FindFirstChild("ToyWorld"), "Expected the Toy World pass")
local archive = assert(storage:FindFirstChild("ToyWorldArchive"))
local lineup = assert(archive:FindFirstChild("MineralLineup"), "Expected the archived mineral stands")
local toyAir = assert(lighting:FindFirstChild("ToyWorldAir"))
assert(not map:FindFirstChild("QuarryWorld") and not map:FindFirstChild("MineralLineup"), "Quarry World already installed")
local run = assert(map:FindFirstChild("CrystalRun"))
local depot = assert(map:FindFirstChild("SimpleFlatTestMap"))

local v, rgb = Vector3.new, Color3.fromRGB
local ZONES = {rgb(255, 170, 40), rgb(255, 72, 96), rgb(80, 190, 255), rgb(176, 102, 255), rgb(255, 150, 232)}
local SAND, STONE, SLATE, CHARCOAL = rgb(196, 176, 146), rgb(150, 132, 112), rgb(96, 86, 80), rgb(62, 56, 54)
local GRASS, LOWLAND = rgb(112, 138, 92), rgb(118, 104, 90)
local GOLD = rgb(240, 186, 70)
local GROUND_TOP = 4.0

local scenery = Instance.new("Folder")
scenery.Name = "QuarryWorld"

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
local function disc(parent, name, center, diameter, thickness, color, collide)
    return part(parent, name, Enum.PartType.Cylinder, v(thickness, diameter, diameter),
        CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, {collide = collide})
end
local function sparkles(host, name, color, opts)
    local a = Instance.new("Attachment")
    a.Name = name .. "Point"
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
    e.Parent = a
    return e
end

local beds = {}
for tier, name in ipairs({"Quartz", "Ruby", "Cobalt", "Violet", "Emerald"}) do
    local bed = assert(run:FindFirstChild(name) and run[name]:FindFirstChild("Field"), "Missing field " .. name)
    assert(bed:GetAttribute("CrystalZone") == tier and bed:GetAttribute("WholeField"), "Unexpected field " .. name)
    beds[tier] = bed
end
local hub = assert(depot:FindFirstChild("HubPad"))
local island = assert(run:FindFirstChild("FlatGround"))
local iMin = island.Position - island.Size / 2
local iMax = island.Position + island.Size / 2
local keepOut = {}
for _, bed in ipairs(beds) do table.insert(keepOut, {bed.Position, bed.Size / 2 + v(3, 0, 3)}) end
-- The restored mineral stands sit on the hub; keep their area clear too.
local lMin, lMax = Vector3.one * 1e9, -Vector3.one * 1e9
for _, model in ipairs(lineup:GetChildren()) do
    -- CoreSpecimen's bounding box spans the hub; the stands are the pad rows.
    if model:IsA("Model") and model.Name ~= "CoreSpecimen" then
        local cf, size = model:GetBoundingBox()
        lMin, lMax = lMin:Min(cf.Position - size / 2), lMax:Max(cf.Position + size / 2)
    end
end
table.insert(keepOut, {(lMin + lMax) / 2, (lMax - lMin) / 2 + v(4, 0, 4)})
local function blocked(x, z, radius)
    for _, area in ipairs(keepOut) do
        if math.abs(x - area[1].X) < area[2].X + radius and math.abs(z - area[1].Z) < area[2].Z + radius then return true end
    end
    return false
end

-- 1. Field beacons: a slate post with stacked pips (1 = easy, 5 = hardest)
-- and a glowing cap in the field color.
local fieldArt = folder(scenery, "Fields")
for tier, bed in ipairs(beds) do
    local zone = ZONES[tier]
    local f = folder(fieldArt, bed.Parent.Name)
    local cx = bed.Position.X + (bed.Position.X >= 0 and -1 or 1) * (bed.Size.X / 2 + 3.5)
    local cz = bed.Position.Z + bed.Size.Z / 2 + 3.5
    local height = 8 + tier * 2
    part(f, "Beacon", nil, v(1.8, height, 1.8), CFrame.new(cx, GROUND_TOP + height / 2, cz), SLATE, {collide = true})
    local cap = part(f, "BeaconCap", Enum.PartType.Ball, v(3, 3, 3), CFrame.new(cx, GROUND_TOP + height + 1.3, cz), zone,
        {material = Enum.Material.Neon})
    for pip = 1, tier do
        part(f, "Pip" .. pip, nil, v(1.2, .7, .3), CFrame.new(cx, GROUND_TOP + 2 + (pip - 1) * 1.3, cz + 1.02), zone,
            {material = Enum.Material.Neon})
    end
    sparkles(cap, "FieldBeacon", zone, {rate = 3 + tier, life = 2.2, speed = 1.6, size = .5, spread = Vector2.new(35, 35), accel = v(0, 1.2, 0)})
    local glow = Instance.new("PointLight")
    glow.Color = zone
    glow.Range = 12
    glow.Brightness = 1.2
    glow.Parent = cap
end

-- 2. Paving-slab paths: hub -> field 1 -> fields 2 and 3 -> fields 4 and 5.
local paths = folder(scenery, "Paths")
local function edgePoint(bed, toward)
    local c = bed.Position
    local d = (toward - c) * v(1, 0, 1)
    local s = math.min(math.abs((bed.Size.X / 2 + 3) / (d.X ~= 0 and d.X or 1e-6)), math.abs((bed.Size.Z / 2 + 3) / (d.Z ~= 0 and d.Z or 1e-6)))
    return c + d * s
end
local routes = {
    {v(0, 0, hub.Position.Z - hub.Size.Z / 2 + 2), edgePoint(beds[1], v(0, 0, 0))},
    {edgePoint(beds[1], beds[2].Position), edgePoint(beds[2], beds[1].Position)},
    {edgePoint(beds[1], beds[3].Position), edgePoint(beds[3], beds[1].Position)},
    {edgePoint(beds[2], beds[4].Position), edgePoint(beds[4], beds[2].Position)},
    {edgePoint(beds[3], beds[5].Position), edgePoint(beds[5], beds[3].Position)},
}
local slabs = 0
for _, route in ipairs(routes) do
    local a, b = route[1] * v(1, 0, 1), route[2] * v(1, 0, 1)
    local length = (b - a).Magnitude
    local count = math.max(2, math.floor(length / 4))
    local yaw = math.atan2((b - a).X, (b - a).Z)
    for i = 0, count do
        local p = a:Lerp(b, i / count)
        if not blocked(p.X, p.Z, -2.5) then
            part(paths, "Slab", nil, v(3.4, .3, 2.4), CFrame.new(p.X, GROUND_TOP + .12, p.Z) * CFrame.Angles(0, yaw, 0), SAND, {collide = true})
            slabs += 1
        end
    end
end

-- 3. Hub: one stone ring around spawn with a thin gold inlay.
local hubArt = folder(scenery, "Hub")
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local center = spawn and spawn.Position * v(1, 0, 1) or v(0, 0, 12)
disc(hubArt, "Ring", v(center.X, GROUND_TOP + .05, center.Z), 18, .1, STONE, true)
disc(hubArt, "Inlay", v(center.X, GROUND_TOP + .08, center.Z), 13, .1, GOLD, true)
disc(hubArt, "Center", v(center.X, GROUND_TOP + .11, center.Z), 12, .1, SAND, true)

-- 4. A stepped basin rim around the island: long terraces that climb away
-- from the fields, so the quarry reads big.
local rim = folder(scenery, "Terraces")
local rng = Random.new(2611)
local terraces = 0
local function terraceRun(axis, side)
    -- axis "x": west/east edges run along Z; axis "z": the north edge runs along X.
    local tiers = {{offset = 7, height = 3, depth = 10}, {offset = 18, height = 9, depth = 12}, {offset = 31, height = 18, depth = 14}}
    for t, tier in ipairs(tiers) do
        local span = axis == "x" and island.Size.Z or island.Size.X + 2 * (tiers[3].offset + 7)
        local pieces = math.floor(span / 26)
        for i = 0, pieces - 1 do
            local along = (axis == "x" and iMin.Z or iMin.X - tiers[3].offset - 7) + (i + .5) * span / pieces
            local len = span / pieces - (rng:NextNumber() < .25 and 6 or 1)
            local h = tier.height + rng:NextNumber() * 3
            local color = (t + i) % 2 == 0 and STONE or SAND
            local cf, size
            if axis == "x" then
                local x = side > 0 and iMax.X + tier.offset or iMin.X - tier.offset
                cf, size = CFrame.new(x, GROUND_TOP + h / 2 - 1, along), v(tier.depth, h, len)
            else
                local z = iMin.Z - tier.offset
                cf, size = CFrame.new(along, GROUND_TOP + h / 2 - 1, z), v(len, h, tier.depth)
            end
            part(rim, "Terrace", nil, size, cf, color, {collide = true})
            terraces += 1
        end
    end
end
terraceRun("x", -1)
terraceRun("x", 1)
terraceRun("z", -1)

-- 5. Monoliths: tall slate slabs on the terraces and a few on the island.
local monoliths = 0
local function monolith(x, z, h, w, base)
    local yaw, lean = rng:NextNumber() * math.pi, (rng:NextNumber() - .5) * .12
    part(rim, "Monolith", nil, v(w, h, w * .38), CFrame.new(x, base + h / 2 - 1, z) * CFrame.Angles(lean, yaw, lean * .5),
        (monoliths % 3 == 0) and CHARCOAL or SLATE, {collide = true})
    monoliths += 1
end
for i = 1, 4 do
    local z = iMin.Z + 30 + (i - 1) * (island.Size.Z - 60) / 3
    monolith(iMin.X - 31 + rng:NextNumber() * 6, z, 16 + rng:NextNumber() * 10, 6 + rng:NextNumber() * 3, GROUND_TOP + 18)
    monolith(iMax.X + 31 - rng:NextNumber() * 6, z + 14, 16 + rng:NextNumber() * 10, 6 + rng:NextNumber() * 3, GROUND_TOP + 18)
end
for i = 1, 3 do
    monolith(iMin.X + (i - .5) * island.Size.X / 3, iMin.Z - 31 + rng:NextNumber() * 6, 18 + rng:NextNumber() * 10, 7 + rng:NextNumber() * 3, GROUND_TOP + 18)
end
for _ = 1, 30 do -- a few small standing stones between fields
    local x = iMin.X + 12 + rng:NextNumber() * (island.Size.X - 24)
    local z = iMin.Z + 12 + rng:NextNumber() * (island.Size.Z - 24)
    local nearPath = false
    for _, route in ipairs(routes) do
        local a, b = route[1] * v(1, 0, 1), route[2] * v(1, 0, 1)
        local ab = b - a
        local t = math.clamp((v(x, 0, z) - a):Dot(ab) / ab:Dot(ab), 0, 1)
        if ((a + ab * t) - v(x, 0, z)).Magnitude < 8 then nearPath = true end
    end
    if not nearPath and not blocked(x, z, 8) and monoliths < 20 then monolith(x, z, 5 + rng:NextNumber() * 5, 2.6 + rng:NextNumber() * 1.6, GROUND_TOP) end
end

-- 6. Distant mesas in the haze give the world its scale.
local far = folder(scenery, "Mesas")
local mesas = 0
for i = 1, 16 do
    local a = i / 16 * math.pi * 2 + rng:NextNumber() * .2
    local r = 520 + rng:NextNumber() * 200
    local x, z = math.cos(a) * r, -110 + math.sin(a) * r
    local w, h = 180 + rng:NextNumber() * 160, 40 + rng:NextNumber() * 55
    local tone = (i % 2 == 0) and STONE or SLATE
    part(far, "Mesa", nil, v(w, h, w * (.5 + rng:NextNumber() * .5)), CFrame.new(x, h / 2 - 2, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0), tone)
    part(far, "MesaCap", nil, v(w * .6, h * .3, w * .35), CFrame.new(x, h + h * .15 - 2, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0), SAND)
    mesas += 1
end

-- 7. Station markers: one accent color each; shapes and particles say what
-- each place does.
local stations = folder(scenery, "Stations")
local function above(p, dy) return p.Position + v(0, p.Size.Y / 2 + dy, 0) end
local pack = depot.PackStationAssembly.PackStation
for i = -1, 1 do -- fanned cards: packs give you a card to pick
    local cf = CFrame.new(above(pack, 3.4)) * CFrame.Angles(0, 0, math.rad(-i * 18)) * CFrame.new(i * 1.8, 0, 0)
    part(stations, "PackCard", nil, v(2.6, 3.6, .18), cf, GOLD)
    part(stations, "PackCardFace", nil, v(2, 3, .2), cf * CFrame.new(0, 0, -.02), SAND)
end
local packSpark = part(stations, "PackSpark", Enum.PartType.Ball, v(.6, .6, .6), CFrame.new(above(pack, 1.2)), GOLD, {shadow = false})
packSpark.Transparency = 1
sparkles(packSpark, "PackSparkles", GOLD, {rate = 10, life = 1.4, speed = 3, size = .45, spread = Vector2.new(40, 40), accel = v(0, 2, 0)})
local printer = depot.PrinterAssembly.Printer
for i = 1, 3 do -- little cubes: this is where drones come from
    local cf = CFrame.new(above(printer, 2.4 + i * .7)) * CFrame.new((i - 2) * 2.4, 0, 0) * CFrame.Angles(math.rad(20 * i), math.rad(35 * i), 0)
    part(stations, "PrinterCube", nil, v(1.5, 1.5, 1.5), cf, ZONES[3])
end
local printerSpark = part(stations, "PrinterSpark", Enum.PartType.Ball, v(.6, .6, .6), CFrame.new(above(printer, .8)), ZONES[3], {shadow = false})
printerSpark.Transparency = 1
sparkles(printerSpark, "PrinterSparkles", ZONES[3], {rate = 8, life = 1.2, speed = 2.5, size = .4, spread = Vector2.new(50, 50), accel = v(0, 2.5, 0)})
local prestige = depot.PrestigeStationAssembly.PrestigeStation
local spire = part(stations, "PrestigeSpire", nil, v(2, 15, 2),
    CFrame.new(prestige.Position.X, GROUND_TOP + 7.5, prestige.Position.Z + prestige.Size.Z / 2 + 2.4) * CFrame.Angles(0, math.rad(45), 0),
    SLATE, {collide = true})
local star = part(stations, "PrestigeStar", Enum.PartType.Ball, v(2.6, 2.6, 2.6), CFrame.new(spire.Position + v(0, 9, 0)), ZONES[4],
    {material = Enum.Material.Neon})
sparkles(star, "PrestigeSparkles", ZONES[4], {rate = 9, life = 2, speed = 2.2, size = .5, spread = Vector2.new(180, 180), drag = 1.5})
local converter = workspace:FindFirstChild("Converter")
if converter then
    local coin = part(stations, "SellCoinSpout", Enum.PartType.Ball, v(.6, .6, .6), CFrame.new(above(converter, .6)), GOLD, {shadow = false})
    coin.Transparency = 1
    sparkles(coin, "SellCoins", GOLD, {rate = 6, life = 1.3, speed = 4, size = .6, spread = Vector2.new(30, 30), accel = v(0, -6, 0)})
end
local charger = run:FindFirstChild("ChargingStation")
if charger then
    for _, side in ipairs({-1, 1}) do
        local pylon = part(stations, "ChargePylon", nil, v(1, 5, 1), CFrame.new(charger.Position + v(side * 5.6, 2.9, 0)), SLATE, {collide = true})
        local tip = part(stations, "ChargeTip", Enum.PartType.Ball, v(1.3, 1.3, 1.3), CFrame.new(pylon.Position + v(0, 3, 0)), rgb(140, 255, 160),
            {material = Enum.Material.Neon})
        sparkles(tip, "ChargeSparks", rgb(150, 255, 170), {rate = 7, life = .5, speed = 6, size = .3, spread = Vector2.new(180, 180), drag = 6})
    end
end
for _, info in ipairs({{"QuartzShop", ZONES[3]}, {"RubyShop", GOLD}}) do
    local shop = map:FindFirstChild(info[1])
    if shop then
        local obelisk = part(stations, "ShopObelisk", nil, v(2, 10, 2),
            CFrame.new(shop.Position.X + 6.2, GROUND_TOP + 5, shop.Position.Z - 1) * CFrame.Angles(0, math.rad(45), 0), SLATE, {collide = true})
        local top = part(stations, "ShopObeliskTop", Enum.PartType.Ball, v(2.2, 2.2, 2.2), CFrame.new(obelisk.Position + v(0, 6, 0)), info[2],
            {material = Enum.Material.Neon})
        sparkles(top, "ShopSparkles", info[2], {rate = 5, life = 1.6, speed = 1.8, size = .45, spread = Vector2.new(60, 60), accel = v(0, 1.5, 0)})
    end
end

-- 8. Recolor the gameplay parts in the restrained palette.
local edits, editHandles = {}, {}
local function bytes(c) return {math.floor(c.R * 255 + .5), math.floor(c.G * 255 + .5), math.floor(c.B * 255 + .5)} end
local function recolor(p, color)
    assert(p and p.ClassName == "Part", "Expected a Part")
    local pos = p.Position
    table.insert(edits, {path = p:GetFullName(), class = "Part", anchor = {pos.X, pos.Y, pos.Z},
        before = {color = bytes(p.Color)}, after = {color = bytes(color)}})
    table.insert(editHandles, {p, p.Color, color})
end
recolor(fieldsFolder.Baseplate, LOWLAND)
recolor(island, GRASS)
recolor(hub, SAND)
for tier, bed in ipairs(beds) do recolor(bed, ZONES[tier]:Lerp(CHARCOAL, .5)) end
recolor(depot.PackStationAssembly.PackStationPad, STONE)
recolor(depot.PackStationAssembly.PackStation, GOLD)
recolor(depot.PrinterAssembly.PrinterPad, STONE)
recolor(depot.PrinterAssembly.Printer, rgb(70, 160, 215))
recolor(depot.PrestigeStationAssembly.PrestigeStationPad, STONE)
recolor(depot.PrestigeStationAssembly.PrestigeStation, rgb(140, 100, 210))
if converter then recolor(converter, rgb(96, 186, 132)) end
if charger then recolor(charger, SLATE) end
for _, info in ipairs({{"QuartzShop", "QuartzCounter"}, {"RubyShop", "StarCounter"}}) do
    local shop = map:FindFirstChild(info[1])
    local counter = shop and shop:FindFirstChild(info[2])
    if counter then
        recolor(counter.Base, SLATE)
        recolor(counter.Top, SAND)
    end
    if shop and shop:FindFirstChild("ShopSign") then recolor(shop.ShopSign, CHARCOAL) end
end

-- 9. Warm afternoon light with depth haze so distance reads as distance.
local air = Instance.new("Atmosphere")
air.Name = "QuarryAir"
air.Density = .3
air.Offset = .2
air.Color = rgb(222, 208, 186)
air.Decay = rgb(168, 146, 124)
air.Glare = .1
air.Haze = .9
local function floats(c) return {c.R, c.G, c.B} end
local light = {before = {ClockTime = lighting.ClockTime, Brightness = lighting.Brightness, Ambient = lighting.Ambient,
    OutdoorAmbient = lighting.OutdoorAmbient, ExposureCompensation = lighting.ExposureCompensation,
    EnvironmentDiffuseScale = lighting.EnvironmentDiffuseScale, EnvironmentSpecularScale = lighting.EnvironmentSpecularScale},
    after = {ClockTime = 15, Brightness = 2.4, Ambient = rgb(104, 100, 98), OutdoorAmbient = rgb(122, 118, 112), ExposureCompensation = -.2,
        -- Less blue sky light in the shade keeps the stone warm.
        EnvironmentDiffuseScale = .35, EnvironmentSpecularScale = .3}}
local lightPlan = {before = {TimeOfDay = lighting.TimeOfDay, Brightness = lighting.Brightness, Ambient = floats(lighting.Ambient),
    OutdoorAmbient = floats(lighting.OutdoorAmbient), ExposureCompensation = lighting.ExposureCompensation,
    EnvironmentDiffuseScale = lighting.EnvironmentDiffuseScale, EnvironmentSpecularScale = lighting.EnvironmentSpecularScale},
    after = {TimeOfDay = "15:00:00", Brightness = 2.4, Ambient = floats(light.after.Ambient), OutdoorAmbient = floats(light.after.OutdoorAmbient),
        ExposureCompensation = -.2, EnvironmentDiffuseScale = .35, EnvironmentSpecularScale = .3}}

-- 10. Moves: archive the Toy World decorations and haze, restore the stands.
local moves, moveHandles = {}, {}
local function move(inst, to)
    table.insert(moves, {path = inst:GetFullName(), class = inst.ClassName, descendants = #inst:GetDescendants(), to = to:GetFullName()})
    table.insert(moveHandles, {inst, inst.Parent, to})
end
move(toy, archive)
move(toyAir, archive)
move(lineup, map)

local newParts = 0
for _, p in ipairs(scenery:GetDescendants()) do
    if p:IsA("BasePart") then
        newParts += 1
        if p.Name ~= "Slab" and p.Name ~= "Mesa" and p.Name ~= "MesaCap" and p.Name ~= "Terrace" then
            assert(not blocked(p.Position.X, p.Position.Z, -1), "Decoration inside a protected area: " .. p:GetFullName() .. " " .. tostring(p.Position))
        end
    end
end

local serialize = game:GetService("SerializationService")
local enc = game:GetService("EncodingService")
local http = game:GetService("HttpService")
local function encode(b) return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(b, Enum.CompressionAlgorithm.Zstd))) end
local snapshot = {
    scenery = encode(serialize:SerializeInstancesAsync({scenery})),
    air = encode(serialize:SerializeInstancesAsync({air})),
    moves = encode(buffer.fromstring(http:JSONEncode(moves))),
    edits = encode(buffer.fromstring(http:JSONEncode(edits))),
    lighting = encode(buffer.fromstring(http:JSONEncode(lightPlan))),
}

local function undo()
    for _, e in ipairs(editHandles) do e[1].Color = e[2] end
    for _, h in ipairs(moveHandles) do h[1].Parent = h[2] end
    scenery.Parent, air.Parent = nil, nil
    for k, value in pairs(light.before) do lighting[k] = value end
end
local function apply()
    assert(not scenery.Parent, "Already installed")
    for _, h in ipairs(moveHandles) do assert(h[1].Parent == h[2], "Concurrent map change: " .. h[1]:GetFullName()) end
    for _, e in ipairs(editHandles) do assert(e[1].Color == e[2], "Concurrent color change: " .. e[1]:GetFullName()) end
    local history = game:GetService("ChangeHistoryService")
    local recording = history:TryBeginRecording("Quarry World")
    for _, h in ipairs(moveHandles) do h[1].Parent = h[3] end
    scenery.Parent = map
    air.Parent = lighting
    for _, e in ipairs(editHandles) do e[1].Color = e[3] end
    for k, value in pairs(light.after) do lighting[k] = value end
    if recording then history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
    return {newParts = newParts, slabs = slabs, terraces = terraces, monoliths = monoliths, mesas = mesas, edits = #edits, moves = #moves}
end
shared.QuarryWorld = {snapshot = snapshot, apply = apply, undo = undo}
return {newParts = newParts, slabs = slabs, terraces = terraces, monoliths = monoliths, mesas = mesas, edits = #edits, moves = #moves,
    sceneryBytes = #snapshot.scenery}
