-- Give the quarry's abstract shapes a clear sightline from spawn and the paths.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local root = workspace.MiningAway
local map = root.Map
assert(map:FindFirstChild("QuarryColorShapes") and not map:FindFirstChild("QuarryArrivalAccents"))
local materials = game:GetService("MaterialService")
local v, rgb = Vector3.new, Color3.fromRGB
local paper, ink = rgb(246,234,191), rgb(48,62,81)
local palette = Instance.new("Folder")
palette.Name = "QuarryArrivalAccents"

local function piece(group, name, frame, size, finish, color, shape)
    local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
    part.Name, part.CFrame, part.Size = name, frame, size
    if shape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
    part.Material, part.MaterialVariant, part.Color = finish.BaseMaterial, finish.Name, color
    part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
    part.CastShadow = size.Magnitude > 4
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = group
end

local function disc(group, name, frame, width, height, finish, color)
    piece(group, name, frame * CFrame.Angles(0, 0, math.pi/2), v(height,width,width), finish, color, "Cylinder")
end

local function sculpture(name, frame, shape, scale, primary, secondary, finish)
    local group = Instance.new("Folder")
    group.Name, group.Parent = name, palette
    local function box(label, offset, size, material, color, form)
        piece(group,label,frame*CFrame.new(offset*scale),size*scale,material,color,form)
    end
    if shape == "dots" then
        box("DottedBlock",v(0,2.7,0),v(5.4,5.4,5.4),finish,primary)
        for row = -1, 1 do
            for column = -1, 1 do
                local color = (row + column) % 2 == 0 and paper or ink
                local top = frame*CFrame.new(v(column*1.46,5.42,row*1.46)*scale)
                disc(group,"TopDot",top,.82*scale,.10*scale,materials.QuarryPhoto_Slate,color)
                local side = frame*CFrame.new(v(2.72,2.7+row*1.46,column*1.46)*scale)
                piece(group,"SideDot",side,v(.10,.82,.82)*scale,materials.QuarryPhoto_Slate,color,"Cylinder")
            end
        end
        box("CheckerStep",v(0,.42,-3.12),v(5.4,.84,1.25),materials.QuarryAccent_Checker,secondary)
    elseif shape == "wedge" then
        box("WideFoot",v(0,.72,0),v(6.8,1.44,5.7),materials.QuarryPalette_Pebbles,secondary)
        box("RisingWedge",v(-.25,3.30,0),v(5.9,3.78,5.18),finish,primary,"Wedge")
        box("Stripe",v(.17,1.28,-2.70),v(5.2,.42,.36),materials.QuarryPalette_Strata,paper)
    else
        for i, width in ipairs({6.8,5.5,4.2,2.8}) do
            disc(group,"OffsetDisc",frame*CFrame.new(v(i*.30-.75,(i-.5)*1.34,0)*scale),
                width*scale,1.34*scale,i%2==1 and finish or materials.QuarryPalette_Strata,
                i%2==1 and primary or secondary)
        end
    end
end

local ground = RaycastParams.new()
ground.RespectCanCollide = true
local function base(x, z, y, radius, yaw)
    local height
    for _, offset in ipairs({v(0,0,0),v(radius,0,0),v(-radius,0,0),v(0,0,radius),v(0,0,-radius)}) do
        local hit = workspace:Raycast(v(x,y+2,z)+offset,v(0,-4,0),ground)
        assert(hit and hit.Normal.Y > .88, ("No ground at %s, %s"):format(x,z))
        height = height or hit.Position.Y
        assert(math.abs(height-hit.Position.Y) <= .28, "Sculpture base would hang off the shelf")
    end
    return CFrame.new(x,height+.025,z)*CFrame.Angles(0,yaw or 0,0)
end

sculpture("SpawnCyanWedge",base(-17,-9,4,4,-.20),"wedge",1.19,
    rgb(58,177,228),rgb(222,152,82),materials.QuarryAccent_Ribbed)
sculpture("SpawnAmberDiscs",base(17,-9,4,4,.25),"discs",1.19,
    rgb(242,177,66),rgb(219,119,90),materials.QuarryPalette_Pebbles)
sculpture("QuartzCoralDots",base(-59,54,4,4,.12),"dots",1.13,
    rgb(230,106,133),rgb(111,176,231),materials.QuarryPalette_Strata)
sculpture("ImpactAmberWedge",base(77,54,4,3,.50),"wedge",.93,
    rgb(241,164,84),rgb(80,189,167),materials.QuarryAccent_Ribbed)
sculpture("RubyRustDiscs",base(-102,42,20,3,-.14),"discs",.94,
    rgb(208,89,69),rgb(232,180,101),materials.QuarryAccent_Brick)
sculpture("CobaltBlueDiscs",base(98,40,20,3.3,.12),"discs",1.03,
    rgb(77,169,230),rgb(217,129,174),materials.QuarryAccent_Ribbed)
sculpture("VioletRibbedWedge",base(-48,-69,38,3,.16),"wedge",.95,
    rgb(180,131,235),rgb(124,162,218),materials.QuarryAccent_Ribbed)
sculpture("EmeraldMintDots",base(58,-70,42,3,.27),"dots",.94,
    rgb(113,206,162),rgb(231,160,94),materials.QuarryBiome_Chalk)

local function tree(name, frame, fan)
    local group = Instance.new("Folder")
    group.Name, group.Parent = name, palette
    piece(group,"Trunk",frame*CFrame.new(0,4.8,0),v(1.8,9.8,1.9),materials.QuarryFoliage_Bark,rgb(159,124,77))
    if fan then
        for i, width in ipairs({10,8.1,6.0,4.0}) do
            local at = frame*CFrame.new((i%2-.5)*2.3,6.9+i*2.6,0)*CFrame.Angles(0,i*1.45,-.10)
            piece(group,"NeedleFan",at,v(width,3.8,width*.72),
                i%2==1 and materials.QuarryPalette_LeafRibs or materials.QuarryFoliage_Evergreen,
                i%2==1 and rgb(189,219,88) or rgb(108,171,80),"Wedge")
        end
    else
        for i, width in ipairs({12.0,10.8,8.8,6.3}) do
            disc(group,"RoundLeaf",frame*CFrame.new((i%2-.5)*2.5,7.9+i*2.35,(i%2)*.86),
                width,1.8,i%2==1 and materials.QuarryPalette_LeafStipple or materials.QuarryPalette_LeafClumps,
                i%2==1 and rgb(93,194,159) or rgb(132,210,122))
        end
    end
end
tree("QuartzRoundLeafTree",base(-72,53,4,2.4,-.33),false)
tree("QuartzLimeFanTree",base(-109,58,4,2.4,.52),true)

local protected = {}
for _, field in ipairs(root.Fields:GetChildren()) do
    local bed = field:FindFirstChild("Field")
    if bed then table.insert(protected,bed) end
end
for _, route in ipairs(map.DronerevolutionTerraces.WalkableRoutes:GetChildren()) do
    if route:IsA("BasePart") then table.insert(protected,route) end
end
local function extent(part)
    local f, s = part.CFrame, part.Size/2
    return v(math.abs(f.RightVector.X)*s.X+math.abs(f.UpVector.X)*s.Y+math.abs(f.LookVector.X)*s.Z,
        0, math.abs(f.RightVector.Z)*s.X+math.abs(f.UpVector.Z)*s.Y+math.abs(f.LookVector.Z)*s.Z)
end
for _, part in ipairs(palette:GetDescendants()) do
    if part:IsA("BasePart") then
        local a = extent(part)
        for _, surface in ipairs(protected) do
            local b = extent(surface)
            local d = part.Position-surface.Position
            assert(math.abs(d.X) >= a.X+b.X+.30 or math.abs(d.Z) >= a.Z+b.Z+.30,
                ("%s overlaps %s"):format(part.Parent.Name,surface.Name))
        end
    end
end

local serialize, enc = game:GetService("SerializationService"), game:GetService("EncodingService")
local bytes = serialize:SerializeInstancesAsync({palette})
local data = buffer.tostring(enc:Base64Encode(enc:CompressBuffer(bytes,Enum.CompressionAlgorithm.Zstd)))
palette.Parent = map
shared.QuarryArrivalSnapshot = data
return {groups=#palette:GetChildren(),parts=#palette:GetDescendants()-#palette:GetChildren(),exportBytes=#data}
