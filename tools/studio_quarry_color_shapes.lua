-- Add abstract accents and vary the authored quarry's surfaces and crowns.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local root = workspace.MiningAway
local map = root.Map
local terraces = map.DronerevolutionTerraces
local reaches = map.QuarryBiomeReaches
local materials = game:GetService("MaterialService")
local v, rgb = Vector3.new, Color3.fromRGB
assert(not map:FindFirstChild("QuarryColorShapes"), "Reconcile the existing color pass")

local function folder(name, parent)
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end
local pass = folder("QuarryColorShapes")
local variants = {}
local function finish(name, source, base, scale, pattern, mapId)
    assert(not materials:FindFirstChild(name), "Material already exists: " .. name)
    local variant = materials[source]:Clone()
    variant.Name = name
    variant.BaseMaterial = base
    variant.StudsPerTile = scale
    variant.MaterialPattern = pattern
    if mapId then variant.ColorMap = "rbxassetid://" .. mapId end
    table.insert(variants, variant)
    return variant
end
local organic, regular = Enum.MaterialPattern.Organic, Enum.MaterialPattern.Regular
local leaf, grass, slate = Enum.Material.LeafyGrass, Enum.Material.Grass, Enum.Material.Slate
local clump = finish("QuarryPalette_LeafClumps", "QuarryFoliage_Canopy", leaf, 4.6, organic)
local stipple = finish("QuarryPalette_LeafStipple", "QuarryField_Aggregate", leaf, 4.2, regular)
local ribs = finish("QuarryPalette_LeafRibs", "QuarryAccent_Ribbed", leaf, 3.8, regular)
local rough = finish("QuarryPalette_Tufts", "QuarryPhoto_Grass", grass, 9.2, organic, "118972165990804")
local stratum = finish("QuarryPalette_Strata", "QuarryPhoto_Sandstone", slate, 11, regular)
local pebble = finish("QuarryPalette_Pebbles", "QuarryField_Aggregate", slate, 6.2, regular)

local checker, ribbed = materials.QuarryAccent_Checker, materials.QuarryAccent_Ribbed
local brick, wood = materials.QuarryAccent_Brick, materials.QuarryAccent_Timber
local matte, pale = materials.QuarryPhoto_Slate, materials.QuarryBiome_Chalk
local weave, turf = materials.QuarryPattern_Herringbone, materials.QuarryPhoto_Grass
local bark = materials.QuarryFoliage_Bark
local cream, ink = rgb(243, 226, 181), rgb(47, 57, 74)

-- Five deliberate accents around each bed plus a small set at the hub.
-- Coordinates list x, z and shape. Color and finish are local to the biome.
local zones = {
    {name="Quartz", y=4, a=rgb(64, 151, 228), b=rgb(250, 205, 93), soil=rgb(164, 193, 99),
        leaf=rgb(137, 183, 81), tile=checker, block=pebble,
        sites={{-68,139,"stripes"},{-47,139,"dots"},{-111,115,"steps"},{-106,67,"discs"},{-69,54,"tile"}},
        trees={{-120,84,"fans"},{-58,158,"needles"},{-38,181,"discs"}}},
    {name="Impact", y=4, a=rgb(243, 163, 80), b=rgb(78, 175, 163), soil=rgb(198, 172, 106),
        leaf=rgb(160, 183, 93), tile=weave, block=ribbed,
        sites={{110,114,"dots"},{110,81,"steps"},{78,138,"discs"},{56,136,"stripes"},{83,56,"tile"}},
        trees={{120,131,"needles"},{147,118,"fans"}}},
    {name="Ruby", y=20, a=rgb(222, 91, 77), b=rgb(231, 177, 98), soil=rgb(216, 132, 91),
        leaf=rgb(163, 164, 90), tile=brick, block=stratum,
        sites={{-153,36,"steps"},{-143,42,"tile"},{-117,39,"stripes"},{-96,41,"dots"},{-151,-33,"discs"}},
        trees={{-180,-48,"fans"},{-159,-97,"needles"}}},
    {name="Cobalt", y=20, a=rgb(76, 171, 224), b=rgb(225, 128, 169), soil=rgb(128, 176, 163),
        leaf=rgb(119, 192, 162), tile=ribbed, block=pale,
        sites={{93,38,"stripes"},{112,39,"dots"},{136,39,"discs"},{156,43,"steps"},{153,-41,"tile"}}},
    {name="Violet", y=38, a=rgb(162, 124, 219), b=rgb(220, 175, 214), soil=rgb(160, 164, 144),
        leaf=rgb(115, 162, 123), tile=checker, block=weave,
        sites={{-53,-72,"stripes"},{-56,-145,"dots"},{-89,-146,"steps"},{-102,-140,"tile"},{-113,-122,"discs"}},
        trees={{-126,-155,"needles"},{-150,-147,"fans"}}},
    {name="Emerald", y=42, a=rgb(113, 207, 168), b=rgb(227, 165, 103), soil=rgb(165, 203, 150),
        leaf=rgb(114, 182, 133), tile=wood, block=pale,
        sites={{44,-73,"discs"},{62,-71,"dots"},{80,-146,"steps"},{61,-150,"stripes"},{43,-146,"tile"}},
        trees={{117,-161,"discs"},{143,-175,"fans"}}},
    {name="Hub", y=4, a=rgb(99, 165, 215), b=rgb(232, 172, 99), soil=rgb(182, 192, 135),
        leaf=rgb(128, 178, 94), tile=checker, block=ribbed,
        sites={{-25,20,"tile"},{18,17,"tile"},{-30,48,"discs"},{28,48,"steps"},{-16,45,"stripes"}}},
}
local byName = {}
for _, zone in ipairs(zones) do byName[zone.name] = zone end

local function place(parent, name, frame, size, material, color, shape)
    local p = Instance.new(shape == "WedgePart" and "WedgePart" or "Part")
    p.Name, p.CFrame, p.Size = name, frame, size
    if shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
    p.Material, p.MaterialVariant, p.Color = material.BaseMaterial, material.Name, color
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
    p.CastShadow = size.Y > 2 and size.X > 1
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
end

local function disc(parent, name, frame, diameter, thickness, material, color)
    place(parent, name, frame * CFrame.Angles(0, 0, math.pi / 2),
        v(thickness, diameter, diameter), material, color, "Cylinder")
end

local function motif(parent, shape, frame, zone, scale)
    local function block(name, at, size, material, color, class, rotation)
        place(parent, name, frame * CFrame.new(at * scale) * (rotation or CFrame.identity),
            size * scale, material, color, class)
    end
    if shape == "stripes" then
        block("StripeSlab", v(0,.12,0), v(7,.24,5.8), matte, zone.a)
        for i = -1, 1 do
            block("ColorInlay", v(i*2.13,.253,0), v(1.04,.024,5.4), stratum, i == 0 and cream or zone.b)
        end
    elseif shape == "tile" then
        block("PatternSquare", v(0,.11,0), v(7.4,.22,6.9), zone.tile, zone.a:Lerp(cream,.28))
    elseif shape == "dots" then
        block("DotCube", v(0,2.26,0), v(4.6,4.52,4.6), zone.block, zone.b)
        for i = -1, 1 do
            for j = -1, 1 do
                disc(parent, "RoundInset", frame * CFrame.new(v(i*1.28,4.55,j*1.28)*scale),
                    .72*scale,.08*scale, matte, (i+j)%2 == 0 and ink or cream)
            end
        end
        block("OffsetFoot", v(2.53,.62,.92), v(2,1.24,2.2), checker, zone.a)
    elseif shape == "steps" then
        block("StepBase", v(0,.59,0), v(6.3,1.18,4.7), pebble, zone.b)
        block("LeaningWedge", v(-.46,2.45,.15), v(4.1,2.54,4.2), zone.block, zone.a,
            "WedgePart", CFrame.Angles(0,math.rad(14),math.rad(-7)))
        block("SmallStep", v(2.15,1.47,-.62), v(2,1.55,2.9), stratum, cream)
    else
        disc(parent, "WideDisc", frame * CFrame.new(0,.48*scale,0), 5.7*scale,.96*scale, zone.block, zone.a)
        disc(parent, "OffsetDisc", frame * CFrame.new(.42*scale,1.23*scale,-.25*scale),
            4.4*scale,.56*scale, stratum, zone.b)
        disc(parent, "SmallDisc", frame * CFrame.new(.9*scale,1.8*scale,-.37*scale),
            2.3*scale,.58*scale, pebble, cream)
    end
end

local function tree(parent, shape, frame, zone, height)
    local function block(name, at, size, finish, color, class, rotation)
        place(parent, name, frame * CFrame.new(at*height) * (rotation or CFrame.identity),
            size*height, finish, color, class)
    end
    local green = zone.leaf
    local light = green:Lerp(rgb(201,223,114),.36)
    local dark = green:Lerp(rgb(60,124,91),.37)
    block("Trunk", v(0,.30,0), v(.074,.62,.077), bark, rgb(148,107,69))
    if shape == "discs" then
        for i, w in ipairs({.65,.53,.39,.24}) do
            local frameAt = frame * CFrame.new(v((i%2-.5)*.10,.42+i*.13,(i%2)*.05)*height)
            disc(parent,"RoundedLeaf",frameAt,w*height,.115*height,
                i%2 == 0 and clump or stipple,i%2 == 0 and light or dark)
        end
    elseif shape == "fans" then
        for i, width in ipairs({.40,.35,.30,.22,.14}) do
            local angle = i*2.4
            block("FanLeaf", v(math.cos(angle)*.13,.49+i*.09,math.sin(angle)*.13), v(width,.23,.21),
                i%2 == 0 and ribs or clump,i%2 == 0 and light or green,
                "WedgePart",CFrame.Angles(0,angle,-.17))
        end
    else
        for i, width in ipairs({.51,.44,.35,.27,.18}) do
            local angle = i*math.pi/2
            block("NeedleTier",v(0,.36+i*.115,0),v(width,.165,width*.84),
                i%3 == 1 and stipple or ribs,i%2 == 0 and green or dark,
                "WedgePart",CFrame.Angles(0,angle,0))
        end
    end
end

local forbidden = {}
local function keepClear(p, margin)
    local f, s = p.CFrame, p.Size/2
    table.insert(forbidden,{x=f.X,z=f.Z,
        hx=math.abs(f.RightVector.X)*s.X+math.abs(f.UpVector.X)*s.Y+math.abs(f.LookVector.X)*s.Z+margin,
        hz=math.abs(f.RightVector.Z)*s.X+math.abs(f.UpVector.Z)*s.Y+math.abs(f.LookVector.Z)*s.Z+margin})
end
for _, field in ipairs(root.Fields:GetChildren()) do
    local bed = field:FindFirstChild("Field")
    if bed then keepClear(bed, 1) end
end
for _, route in ipairs(terraces.WalkableRoutes:GetChildren()) do
    if route:IsA("BasePart") then keepClear(route, .25) end
end
for _, p in ipairs(map.EmeraldChalkLagoon:GetDescendants()) do
    if p.Name == "LagoonCauseway" then keepClear(p, 1) end
end
local function open(x,z,r)
    for _, area in ipairs(forbidden) do
        if math.abs(x-area.x)<r+area.hx and math.abs(z-area.z)<r+area.hz then return false end
    end
    return true
end
local groundParams = RaycastParams.new()
groundParams.RespectCanCollide = true
local function grounded(x,z,y,r)
    if not open(x,z,r) then return nil end
    local center
    for _, offset in ipairs({v(0,0,0),v(r*.64,0,0),v(-r*.64,0,0),v(0,0,r*.64),v(0,0,-r*.64)}) do
        local hit = workspace:Raycast(v(x,y+2,z)+offset,v(0,-5,0),groundParams)
        if not hit or hit.Normal.Y<.82 then return nil end
        center = center or hit.Position.Y
        if math.abs(hit.Position.Y-center)>.43 then return nil end
    end
    return center
end
local placed, treeCount, remote = {}, 0, 0
for _, zone in ipairs(zones) do
    local group = folder(zone.name, pass)
    placed[zone.name] = 0
    for i, site in ipairs(zone.sites) do
        local x,z,shape = table.unpack(site)
        local size = .89 + (i%3)*.10
        local y = grounded(x,z,zone.y,4.4*size)
        if y then
            motif(group,shape,CFrame.new(x,y+.016,z)*CFrame.Angles(0,(i%3-1)*.13,0),zone,size)
            placed[zone.name] += 1
        end
    end
    if zone.name ~= "Hub" then
        local shelf = reaches[zone.name].Shelf1_3.TerraceSurface
        local top = shelf.Position.Y + shelf.Size.Y/2
        local x,z = shelf.Position.X-shelf.Size.X*.30,shelf.Position.Z+shelf.Size.Z*.26
        local y = grounded(x,z,top,2.5)
        if y then
            motif(group,"discs",CFrame.new(x,y+.016,z),zone,.59)
            remote += 1
        end
    end
    for i, site in ipairs(zone.trees or {}) do
        local x,z,shape = table.unpack(site)
        local height = 14 + (i%2)*5
        local top = grounded(x,z,zone.y,height*.41)
        if top then
            tree(group,shape,CFrame.new(x,top-.10,z)*CFrame.Angles(0,i*.43,0),zone,height)
            treeCount += 1
        end
    end
end
assert(treeCount>=5, "Too few new silhouettes fit the terrain")

local edits, handles = {}, {}
local function bytes(c)
    return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)}
end
local function record(p, material, color)
    assert(p.Material == material.BaseMaterial, "Material mismatch at " .. p:GetFullName())
    local pos, size = p.Position, p.Size
    local old,new = bytes(p.Color),bytes(color)
    if p.MaterialVariant == material.Name and old[1]==new[1] and old[2]==new[2] and old[3]==new[3] then return end
    table.insert(edits,{path=p:GetFullName(),class=p.ClassName,anchor={pos.X,pos.Y,pos.Z},anchorSize={size.X,size.Y,size.Z},
        before={color=old,variant=p.MaterialVariant},after={color=new,variant=material.Name}})
    table.insert(handles,{p,material,color})
end

local function leaves(region, zone)
    for _, p in ipairs(region:GetDescendants()) do
        if p:IsA("Part") and p.Material==leaf and
            (p.MaterialVariant=="QuarryFoliage_Canopy" or p.MaterialVariant=="QuarryFoliage_Evergreen") then
            local tiered = p.MaterialVariant=="QuarryFoliage_Evergreen"
            local thin = p.Size.Y < math.min(p.Size.X,p.Size.Z)*.56
            local shapeFinish = tiered and (thin and ribs or materials.QuarryFoliage_Evergreen)
                or (thin and stipple or clump)
            local green = zone.leaf:Lerp(rgb(196,216,112),thin and .31 or .06)
            record(p,shapeFinish,p.Color:Lerp(green,tiered and .52 or .65))
        end
    end
end

for _, region in ipairs(map.QuarryWoodlands:GetChildren()) do
    leaves(region,byName[region.Name:gsub("Woodland$","")])
end
leaves(reaches.Quartz,byName.Quartz)
leaves(map.QuarryDepthPass.EmeraldShoreTerraces,byName.Emerald)
leaves(map.EmeraldChalkLagoon,byName.Emerald)
for _, region in ipairs(terraces.AssetScenery:GetChildren()) do
    local key = region.Name:gsub("Scenery$",""):gsub("ImpactTest","Impact")
    local zone = byName[key]
    if zone and key~="Cobalt" then
        for _, model in ipairs(region:GetChildren()) do
            if model:IsA("Model") and model.Name:lower():find("tree") then leaves(model,zone) end
        end
    end
end

local leafEdits = #edits
for _, region in ipairs(reaches:GetChildren()) do
    local zone = byName[region.Name]
    for _, shelf in ipairs(region:GetChildren()) do
        local step = tonumber(shelf.Name:match("_(%d+)$"))
        for _, p in ipairs(shelf:GetChildren()) do
            if p:IsA("Part") and p.Material==grass then
                local accent = step%2 == 0 and p.Name=="LowerGrassBench"
                record(p,accent and rough or materials[p.MaterialVariant],p.Color:Lerp(zone.soil,accent and .65 or .31))
            end
        end
    end
end
for _, p in ipairs(map.QuarryBlockRim:GetDescendants()) do
    if p:IsA("Part") and p.Name=="RockStratum" and p.Material==slate then
        record(p,stratum,p.Color:Lerp(rgb(155,164,157),.27))
    end
end

local serialization = game:GetService("SerializationService")
local encoding = game:GetService("EncodingService")
local function encode(data)
    return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(data,Enum.CompressionAlgorithm.Zstd)))
end
local snapshot = {
    scenery=encode(serialization:SerializeInstancesAsync({pass})),
    variants=encode(serialization:SerializeInstancesAsync(variants)),
    edits=encode(buffer.fromstring(game:GetService("HttpService"):JSONEncode({edits=edits,moves={}}))),
}
for _, variant in ipairs(variants) do variant.Parent = materials end
for _, entry in ipairs(handles) do entry[1].MaterialVariant,entry[1].Color = entry[2].Name,entry[3] end
pass.Parent = map
shared.QuarryColorShapesSnapshot = snapshot
return {abstract=placed, trees=treeCount, outerAccents=remote, foliageEdits=leafEdits,
    surfaceEdits=#edits-leafEdits, instances=#pass:GetDescendants()+1, variants=#variants,
    exportBytes={scenery=#snapshot.scenery,variants=#snapshot.variants,edits=#snapshot.edits}}
