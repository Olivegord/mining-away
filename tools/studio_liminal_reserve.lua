-- Stage the reserve scenery outside the DataModel. Apply after the native dry run.
local function checkEdit()
    assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong experience")
    assert(game:GetService("RunService"):IsEdit(), "Expected Studio Edit")
end
checkEdit()
local world = workspace.MiningAway
local map = world.Map
assert(not map:FindFirstChild("LiminalReserve"))
local materials = game:GetService("MaterialService")
local v, rgb = Vector3.new, Color3.fromRGB
local function folder(name, parent)
    local object = Instance.new("Folder")
    object.Name, object.Parent = name, parent
    return object
end
local reserve = folder("LiminalReserve")
local enclosure = folder("Enclosure", reserve)
local landscapes = folder("Landscapes", reserve)
local oddities = folder("Oddities", reserve)
local clouds = folder("CloudBlocks", reserve)

local function part(parent, name, frame, size, finish, color, form, solid)
    local object = Instance.new(form == "Wedge" and "WedgePart" or "Part")
    object.Name, object.CFrame, object.Size = name, frame, size
    if form == "Cylinder" then object.Shape = Enum.PartType.Cylinder end
    local variant = finish and materials:FindFirstChild(finish)
    object.Material = variant and variant.BaseMaterial or Enum.Material.SmoothPlastic
    object.MaterialVariant = variant and variant.Name or ""
    object.Color = color
    object.Anchored, object.CanCollide = true, solid == true
    object.CanQuery, object.CanTouch = solid == true, false
    object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    object.Parent = parent
    return object
end

local slate = "QuarryPhoto_Slate"
local chalk = "QuarryBiome_Chalk"
local turf = "QuarryPhoto_Grass"
local bark = "QuarryFoliage_Bark"
local gravel = "QuarryPhoto_Pebble"
local timber = "QuarryAccent_Timber"
local ivory, paint, ink = rgb(224,220,185), rgb(218,178,83), rgb(52,68,72)
local xmin, xmax, zmin, zmax = -216, 271, -197, 223

local function boundary(name, origin, length, yaw, stone)
    local group = folder(name, enclosure)
    local frame = CFrame.new(origin) * CFrame.Angles(0,yaw,0)
    local function box(label,x,y,z,w,h,d,finish,color,solid)
        return part(group,label,frame*CFrame.new(x,y,z),v(w,h,d),finish,color,nil,solid)
    end
    -- The continuous backing overlaps at the corners. Relief faces sit in
    -- front of it with deliberately repetitive seams and a stepped skyline.
    box("ContinuousBoundary",0,62,0,length+24,172,19,slate,stone,true)
    local count = math.ceil(length/52)
    local width = length/count
    for index = 1,count do
        local x = -length/2+(index-.5)*width
        local shade = stone:Lerp(rgb(154,170,159), .11+(index%4)*.068)
        local shoulder = 48+(index*17)%31
        local crest = 151+(index*19)%31
        box("LowerStone",x,shoulder/2-6,-13,width+.5,shoulder+12,15,slate,shade)
        box("UpperStone",x,(shoulder+crest)/2,-8,width+.32,crest-shoulder,13,slate,shade:Lerp(stone,.26))
        if index%3 ~= 0 then
            box("GrassyLedge",x,shoulder-1,-19,width*.64,2.5,11,turf,rgb(130,155,108))
            box("UpperCourse",x+(index%2-.5)*width*.22,crest-9,-16,width*.33,18,10,
                chalk,shade:Lerp(rgb(169,175,153),.36))
        end
    end
end

boundary("North",v((xmin+xmax)/2,0,zmin),xmax-xmin,math.pi,rgb(112,132,123))
boundary("East",v(xmax,0,(zmin+zmax)/2),zmax-zmin,math.pi/2,rgb(130,142,127))
boundary("South",v((xmin+xmax)/2,0,zmax),xmax-xmin,0,rgb(114,130,116))
boundary("West",v(xmin,0,(zmin+zmax)/2),zmax-zmin,-math.pi/2,rgb(114,130,128))

local sky = assert(game.Lighting:FindFirstChildOfClass("Sky"))
local cloudTexture = sky.SkyboxBk
for index,spec in ipairs({
    {-105,49,107,43,4,18,15,0,8,62}, {79,57,58,37,4.5,20,19,0,-5,69},
    {-120,69,6,44,4,19,12,0,10,76}, {106,72,2,39,5,18,-9,0,15,64},
    {-67,90,-102,44,4,21,14,0,5,83}, {70,93,-105,36,4,19,9,0,-11,74},
}) do
    local x,y,z,w,h,d,dx,dy,dz,period = table.unpack(spec)
    local center = v(x,y,z)
    local p = part(clouds,"CloudBlock"..index,CFrame.new(center),v(w,h,d),nil,rgb(218,232,247))
    p.CastShadow = false
    p:SetAttribute("DriftCenter",center)
    p:SetAttribute("DriftVector",v(dx,dy,dz))
    p:SetAttribute("DriftPeriod",period)
    p:SetAttribute("DriftPhase",index*.91)
    for _,face in ipairs(Enum.NormalId:GetEnumItems()) do
        local decal = Instance.new("Decal")
        decal.Name, decal.Face, decal.Texture = "PrintedCloud", face, cloudTexture
        decal.Transparency = .08
        decal.Parent = p
    end
end

local ray = RaycastParams.new()
ray.RespectCanCollide = true
local protected = {}
local function mark(p)
    if p:IsA("BasePart") then
        local f,s = p.CFrame,p.Size/2
        table.insert(protected,{
            p.Position.X,p.Position.Z,
            math.abs(f.RightVector.X)*s.X+math.abs(f.UpVector.X)*s.Y+math.abs(f.LookVector.X)*s.Z,
            math.abs(f.RightVector.Z)*s.X+math.abs(f.UpVector.Z)*s.Y+math.abs(f.LookVector.Z)*s.Z,
        })
    end
end
for _,field in ipairs(world.Fields:GetChildren()) do
    local bed = field:FindFirstChild("Field")
    if bed then mark(bed) end
end
for _,p in ipairs(map.DronerevolutionTerraces.WalkableRoutes:GetDescendants()) do mark(p) end
mark(map.SimpleFlatTestMap.HubPad)
mark(map.DronerevolutionTerraces.LogisticsApron.ServiceDeck)
local claimed = {}
local function anchor(name,x,y,z,radius)
    for _,offset in ipairs({{0,0},{-7,0},{7,0},{0,-7},{0,7},{-8,-8},{8,-8},{-8,8},{8,8},
            {-14,0},{14,0},{0,-14},{0,14}}) do
        local a,b = x+offset[1],z+offset[2]
        local clear = true
        for _,area in ipairs(protected) do
            if math.abs(a-area[1]) < area[3]+radius+.6 and math.abs(b-area[2]) < area[4]+radius+.6 then
                clear = false
                break
            end
        end
        for _,area in ipairs(claimed) do
            if (Vector2.new(a,b)-area[1]).Magnitude < radius+area[2]+1 then clear = false; break end
        end
        if clear then
            local height
            for _,delta in ipairs({v(0,0,0),v(radius,0,0),v(-radius,0,0),v(0,0,radius),v(0,0,-radius)}) do
                local hit = workspace:Raycast(v(a,y+1.5,b)+delta,v(0,-3.5,0),ray)
                if not hit or hit.Normal.Y < .88 or height and math.abs(height-hit.Position.Y) > .45 then
                    clear = false
                    break
                end
                height = height or hit.Position.Y
            end
            if clear then
                table.insert(claimed,{Vector2.new(a,b),radius})
                return CFrame.new(a,height+.02,b)
            end
        end
    end
    error("No safe position for "..name)
end

local function pieces(parent,name,x,y,z,radius,yaw)
    local group = folder(name,parent)
    local frame = anchor(name,x,y,z,radius)*CFrame.Angles(0,yaw or 0,0)
    return function(label,position,size,finish,color,form,rotation)
        return part(group,label,frame*CFrame.new(position)*(rotation or CFrame.identity),size,finish,color,form)
    end
end
local function disc(box,name,x,y,z,w,h,finish,color)
    box(name,v(x,y,z),v(h,w,w),finish,color,"Cylinder",CFrame.Angles(0,0,math.pi/2))
end
local function rock(box,name,x,z,w,h,finish,color,yaw)
    box(name,v(x,h/2-.12,z),v(w,h,w*.78),finish,color,"Wedge",CFrame.Angles(0,yaw or 0,0))
end
local function needles(box,x,z,scale)
    box("Trunk",v(x,3.5*scale,z),v(.85,7,.85)*scale,bark,rgb(139,109,81))
    for tier = 1,3 do
        local width = (5.3-tier*.86)*scale
        box("Needles",v(x,(4.4+tier*1.44)*scale,z),v(width,1.7*scale,width),
            "QuarryFoliage_Evergreen",rgb(110+tier*8,155+tier*7,112+tier*3))
    end
end
local function reeds(box,x,z,tint)
    for index = -1,1 do
        box("Blade",v(x+index*.47,.8+math.abs(index)*.19,z),v(.22,1.8,.22),
            turf,tint,nil,CFrame.Angles(0,index*.3,index*.16))
    end
end

-- Six familiar landscape silhouettes. A few repeated shapes make the reserve
-- look staged and leave the current field floors, ore sight lines and routes open.
local quartz = pieces(landscapes,"QuartzSparseMeadow",-107,4,108,4,.15)
for _,x in ipairs({-2,2}) do reeds(quartz,x,0,rgb(156,179,105)) end
rock(quartz,"FieldStone",0,1,2.5,1.15,slate,rgb(155,163,145),.25)

local impact = pieces(landscapes,"ImpactDryGrassland",112,4,114,7,.12)
for index = 1,4 do
    rock(impact,"RoundedWashStone",index*2.6-6.5,index%2*2-1,2.5+(index%3)*.65,1.1+index*.17,
        gravel,rgb(173+index*6,156+index*5,128+index*3),index*.79)
end
reeds(impact,2,-3,rgb(192,174,105))

local ruby = pieces(landscapes,"RubyPinePlantation",-159,20,21,8,.1)
for _,x in ipairs({-5,0,5}) do
    needles(ruby,x,-2,1.1)
    needles(ruby,x,3,1.1)
end

local cobalt = pieces(landscapes,"CobaltMushroomFloor",160,20,14,7,-.35)
for index = 1,5 do
    local x,z = (index-3)*2.25,(index%2-.5)*3.2
    local height = 1.6+index*.29
    disc(cobalt,"MushroomStem",x,height/2,z,.68,height,nil,rgb(205,193,163))
    disc(cobalt,"MushroomCap",x,height,z,2.35,.48,nil,index%2==0 and rgb(99,146,169) or rgb(174,109,97))
    reeds(cobalt,x,z+1.4,rgb(110,149,101))
end

local violet = pieces(landscapes,"VioletStoneMoor",-107,38,-148,7,-.45)
for index = -2,2 do
    rock(violet,"HeatherStone",index*2.3,math.abs(index)*.8,2.7,2.8-math.abs(index)*.53,
        slate,rgb(137,141,148),index*.6)
    reeds(violet,index*2,-2,rgb(147,126,133))
end

local emerald = pieces(landscapes,"EmeraldChalkMeadow",112,42,-144,7,.27)
for index = -2,2 do
    rock(emerald,"ChalkOutcrop",index*2.2,index%2*2,2.9,2.1+math.abs(index)*.53,
        chalk,rgb(219,217,187),index*.43)
    reeds(emerald,index*1.8,2.8,rgb(145,170,105))
end

local dryShelf = pieces(landscapes,"ImpactDryShelf",132,4,143,11,.32)
for index = -2,2 do
    rock(dryShelf,"Sandstone",index*3.35,math.abs(index)*1.4,3.8,2.2-index*.3,
        gravel,rgb(193,170,133),index*.62)
    reeds(dryShelf,index*3.45,-2,rgb(184,161,94))
end

local pineEdge = pieces(landscapes,"RubyRepeatedTreeline",-158,20,-58,10,.22)
for _,x in ipairs({-7,-2,3,8}) do needles(pineEdge,x,0,1.35) end

local moor = pieces(landscapes,"VioletRockShelf",-148,38,-117,9,-.24)
for index = -2,2 do
    rock(moor,"SlantedSlate",index*3,math.abs(index)*1.6,4.8,3.7-math.abs(index)*.54,
        slate,rgb(142,145,151),index*.34)
end

local die = pieces(oddities,"QuartzDiscardedDomino",-119,4,78,5,.39)
die("Domino",v(0,3,0),v(3.6,6,1.05),nil,ivory)
for _,p in ipairs({{-1.04,1.28},{0,1.94},{1.04,2.58},{-1.04,3.64},{1.04,4.64},{0,5.19}}) do
    die("Pip",v(p[1],p[2],-.545),v(.17,.49,.49),nil,ink,"Cylinder",CFrame.Angles(0,math.pi/2,0))
end
die("Divider",v(0,3.16,-.56),v(3,.11,.09),nil,ink)

local chair = pieces(oddities,"ImpactOverlookChair",119,4,77,5,-.32)
for _,x in ipairs({-2.4,2.4}) do
    for _,z in ipairs({-1.65,1.65}) do chair("Leg",v(x,1.45,z),v(.48,2.9,.48),timber,paint) end
    chair("BackPost",v(x,4.3,1.7),v(.49,3.3,.52),timber,paint)
end
chair("Seat",v(0,3.05,0),v(5.4,.48,4.4),"QuarryMotif_BlueGingham",ivory)
chair("Back",v(0,5.36,1.7),v(5.4,1.42,.52),timber,paint)

local door = pieces(oddities,"RubyFreestandingDoor",-167,20,-14,5,-.23)
for _,x in ipairs({-2.15,2.15}) do door("Frame",v(x,3.56,0),v(.44,7.12,.54),timber,ivory) end
door("Lintel",v(0,7.08,0),v(4.7,.47,.54),timber,ivory)
door("HalfOpenDoor",v(-.72,3.42,-1.33),v(3.74,6.71,.36),timber,paint,nil,CFrame.Angles(0,.81,0))
door("Doorknob",v(.47,3.35,-2.52),v(.24,.27,.24),nil,ink)

local cabinet = pieces(oddities,"CobaltParkMonitor",157,20,-12,5,.24)
cabinet("Plinth",v(0,.48,0),v(4.4,.96,3.6),nil,ink)
cabinet("Case",v(0,2.72,.3),v(3.84,4.45,2.9),nil,rgb(152,166,143))
cabinet("Screen",v(0,3.12,-1.19),v(3.03,2.4,.16),"QuarryMotif_Waves",rgb(155,200,193))
cabinet("Button",v(1.16,1.47,-1.22),v(.24,.24,.16),nil,rgb(200,94,85))

local stair = pieces(oddities,"VioletStairToNowhere",-60,38,-150,7,.25)
for index = 1,6 do
    stair("TiledStep",v(0,index*.46,(index-3.5)*1.55),v(5,index*.92,1.58),
        "QuarryAccent_Checker",rgb(188,181,175))
end

local frame = pieces(oddities,"EmeraldViewfinder",113,42,-102,6,-.36)
for _,x in ipairs({-3.4,3.4}) do frame("Post",v(x,3.5,0),v(.52,7,.54),timber,paint) end
for _,y in ipairs({2,6.75}) do frame("Crosspiece",v(0,y,0),v(7.22,.52,.54),timber,paint) end
frame("HalfBench",v(-1.87,.88,.96),v(2.4,.42,1.25),"QuarryMotif_RedGingham",ivory)

local dock = pieces(oddities,"ReserveMaintenanceDock",-77,4,146,5,.19)
dock("Pad",v(0,.18,0),v(5.4,.36,4.65),"QuarryAccent_Checker",rgb(152,162,149))
dock("ServiceColumn",v(0,1.74,1.58),v(.88,3.48,.82),nil,ink)
dock("ServiceHead",v(0,3.36,.98),v(3.45,.42,1.75),nil,ivory)
for _,x in ipairs({-1.38,1.38}) do
    dock("GuideRail",v(x,.56,-.15),v(.22,.4,2.64),nil,paint)
end
dock("StatusWindow",v(0,3.36,.05),v(.93,.19,.14),nil,rgb(116,196,165))

local protectedSamples = {}
for _,field in ipairs(world.Fields:GetChildren()) do
    local bed = field:FindFirstChild("Field")
    if bed and bed:IsA("BasePart") then
        for ix = -2,2 do for iz = -2,2 do
            local at = bed.CFrame:PointToWorldSpace(v(bed.Size.X*ix/5,bed.Size.Y/2,bed.Size.Z*iz/5))
            table.insert(protectedSamples,at)
        end end
    end
end
for _,p in ipairs(map.DronerevolutionTerraces.WalkableRoutes:GetDescendants()) do
    if p:IsA("BasePart") then
        table.insert(protectedSamples,p.CFrame:PointToWorldSpace(v(0,p.Size.Y/2,0)))
    end
end
local function groundHits()
    local hits = {}
    for i,at in ipairs(protectedSamples) do
        local hit = workspace:Raycast(at+v(0,5,0),v(0,-13,0),ray)
        hits[i] = hit and hit.Instance or false
    end
    return hits
end
local baseline = groundHits()
local tints, recolors = {}, {}
local palette = {
    Quartz = {rgb(168,196,135),rgb(161,146,117),rgb(194,191,173)},
    Impact = {rgb(186,183,120),rgb(182,151,115),rgb(204,183,149)},
    Ruby = {rgb(137,168,120),rgb(149,117,95),rgb(182,158,135)},
    Cobalt = {rgb(116,164,129),rgb(127,132,112),rgb(148,162,144)},
    Violet = {rgb(155,166,137),rgb(145,147,146),rgb(177,174,166)},
    Emerald = {rgb(160,189,137),rgb(181,178,151),rgb(207,204,177)},
}
local function bytesColor(color)
    return {math.round(color.R*255),math.round(color.G*255),math.round(color.B*255)}
end
local function tint(p,color)
    local before, at = p.Color, p.Position
    table.insert(recolors,{p,before,color})
    table.insert(tints,{path=p:GetFullName(),class=p.ClassName,anchor={at.X,at.Y,at.Z},
        before={color=bytesColor(before)},after={color=bytesColor(color)}})
end
local terraces = map.DronerevolutionTerraces
for region,colors in pairs(palette) do
    local field = region == "Impact" and "ImpactTest" or region
    tint(world.Fields[field].Field,colors[3])
    local foundation = terraces[field.."Terrace"]
    tint(foundation.EarthMass,colors[2])
    tint(foundation.EarthBand,colors[2]:Lerp(colors[3],.47))
    for _,p in ipairs(map.QuarryContinuousGround.Terraces[region]:GetChildren()) do
        if p.Name:match("^Earth%d+$") then tint(p,colors[2]) end
        if p.Name:match("^Turf%d+$") then tint(p,colors[1]) end
    end
end
for _,p in ipairs(terraces.IslandGround:GetChildren()) do
    if p.Name == "Earth" then tint(p,rgb(145,138,118):Lerp(p.Color,.18)) end
end
local serial, encoding = game:GetService("SerializationService"),game:GetService("EncodingService")
local bytes = serial:SerializeInstancesAsync({reserve})
local snapshot = buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(bytes,Enum.CompressionAlgorithm.Zstd)))
local tintData = game:GetService("HttpService"):JSONEncode(tints)
local tintSnapshot = buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(buffer.fromstring(tintData),Enum.CompressionAlgorithm.Zstd)))
shared.LiminalReserve = {
    snapshot = snapshot,
    tints = tintSnapshot,
    apply = function()
        checkEdit()
        assert(not reserve.Parent and not map:FindFirstChild(reserve.Name))
        for _,entry in ipairs(recolors) do assert(entry[1].Color == entry[2],"Terrain palette changed while staged") end
        reserve.Parent = map
        local ok, report = pcall(function()
            local actual = groundHits()
            for i,before in ipairs(baseline) do assert(actual[i] == before,"Ground obstruction at sample "..i) end
            local params = RaycastParams.new()
            params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include,{enclosure}
            for _,y in ipairs({1,45,100,145}) do
                for i=1,64 do
                    local angle = i*math.pi/32
                    local hit = workspace:Raycast(v(0,y,0),v(math.cos(angle)*450,0,math.sin(angle)*450),params)
                    assert(hit and hit.Instance.Name == "ContinuousBoundary","Open rim at "..i..", "..y)
                end
            end
            return {protectedSamples=#baseline,boundaryRays=256,clouds=#clouds:GetChildren(),zones=#landscapes:GetChildren()}
        end)
        if not ok then reserve.Parent = nil; error(report) end
        for _,entry in ipairs(recolors) do entry[1].Color = entry[3] end
        return report
    end,
    rollback = function()
        checkEdit()
        if reserve.Parent == map then
            reserve.Parent = nil
            for _,entry in ipairs(recolors) do entry[1].Color = entry[2] end
        end
    end,
}
return {
    bytes=#snapshot, tintBytes=#tintSnapshot, tintCount=#tints,
    descendants=#reserve:GetDescendants(), cloudTexture=cloudTexture,
    sites=#claimed, protectedSamples=#baseline,
}
