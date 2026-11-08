-- Stage the courtyard and color pass from the shared Edit document.
assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong shared place")
assert(game:GetService("RunService"):IsEdit(), "Edit document required")
local root, lighting, mat = workspace.MiningAway, game.Lighting, game.MaterialService
local map, fields = root.Map, root.Fields
local oldMotifs, ground = map.QuarryMotifScenery, map.QuarryContinuousGround
local authored = map.DronerevolutionTerraces
assert(not map:FindFirstChild("QuarryCourtyard") and not shared.QuarryCourtyard)
local v, rgb = Vector3.new, Color3.fromRGB

local function folder(name, parent)
    local item = Instance.new("Folder")
    item.Name, item.Parent = name, parent
    return item
end
local scenery = folder("QuarryCourtyard")
local variants = {}
local function variant(name, base, colorMap, scale)
    local item = Instance.new("MaterialVariant")
    item.Name = "QuarryCourtyard_" .. name
    assert(not mat:FindFirstChild(item.Name))
    item.BaseMaterial, item.ColorMap, item.StudsPerTile = base, "rbxassetid://"..colorMap, scale
    item.RoughnessMap = "rbxassetid://78519593640803"
    item.MaterialPattern = Enum.MaterialPattern.Regular
    table.insert(variants,item)
    return item
end
local turf = variant("Turf",Enum.Material.Concrete,"134439792116456",11)
local garden = variant("Garden",Enum.Material.LeafyGrass,"134439792116456",11)
local firedBrick = variant("Brick",Enum.Material.Brick,"119317200148174",6.4)
local roseStone = variant("RoseStone",Enum.Material.Slate,"112016713025924",9)
local gravel = mat.QuarryField_Aggregate

local decal = Instance.new("Decal")
decal.Texture = firedBrick.ColorMap
local loaded = false
game:GetService("ContentProvider"):PreloadAsync({decal},function(_,status)
    loaded = status == Enum.AssetFetchStatus.Success
end)
decal:Destroy()
assert(loaded,"New brick image did not load")

local partEdits, partHandles = {}, {}
local function bytes(c)
    return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)}
end
local function finish(part, tint, material)
    assert(not material or material.BaseMaterial == part.Material,part:GetFullName())
    local name = material and material.Name or part.MaterialVariant
    local p = part.Position
    table.insert(partEdits,{path=part:GetFullName(),class=part.ClassName,anchor={p.X,p.Y,p.Z},
        before={color=bytes(part.Color),variant=part.MaterialVariant},after={color=bytes(tint),variant=name}})
    table.insert(partHandles,{part,tint,name})
end

local olive = rgb(155,168,104)
local stone = rgb(200,189,185)
finish(map.SimpleFlatTestMap.HubPad,olive,turf)
for _,p in ipairs(authored.MarketGardens:GetChildren()) do
    if p.Name == "GardenSoil" then finish(p,olive,garden) end
end
for _,p in ipairs(authored.MarketSquare:GetChildren()) do
    if p.Name:find("Walk") or p.Name=="ShopApron" then finish(p,stone,gravel) end
end
finish(authored.LogisticsApron.ServiceDeck,rgb(186,180,174))
local earthTints = {
    Quartz={rgb(157,168,104),rgb(142,135,164),rgb(200,190,188)},
    Impact={rgb(172,177,108),rgb(178,146,115),rgb(209,194,174)},
    Ruby={rgb(181,172,108),rgb(174,114,120),rgb(199,162,169)},
    Cobalt={rgb(135,175,143),rgb(118,152,183),rgb(173,190,215)},
    Violet={rgb(157,171,117),rgb(154,129,192),rgb(184,166,211)},
    Emerald={rgb(146,184,125),rgb(204,216,188),rgb(187,221,186)},
}
for _,region in ipairs(ground.Terraces:GetChildren()) do
    local palette = earthTints[region.Name]
    for _,p in ipairs(region:GetChildren()) do finish(p,palette[p.Name:match("^Turf") and 1 or 2]) end
    finish(fields[region.Name=="Impact" and "ImpactTest" or region.Name].Field,palette[3])
end
local rimTints = {
    WestEscarpment=rgb(141,133,165), NorthCrown=rgb(135,147,175), EastChalkRim=rgb(180,194,191),
    SouthwestGate=rgb(153,144,163), SoutheastGate=rgb(161,146,155),
}
for _,section in ipairs(map.QuarryBlockRim:GetChildren()) do
    for _,p in ipairs(section:GetChildren()) do
        if p.Name=="BasalRock" then finish(p,p.Color:Lerp(rimTints[section.Name],.58)) end
    end
end
for _,p in ipairs(oldMotifs:GetDescendants()) do
    if not p:IsA("BasePart") then continue end
    if p.Name=="BrickLow" then finish(p,rgb(250,234,222),firedBrick)
    elseif p.Name=="RoseCube" then finish(p,rgb(228,135,154),roseStone)
    end
end

local propertyEdits, propertyHandles = {}, {}
local function setting(items, name, value)
    local function encode(x)
        return typeof(x)=="Color3" and {x.R,x.G,x.B} or x
    end
    local first = items[1]
    for _,p in ipairs(items) do
        assert(p:GetFullName()==first:GetFullName() and p[name]==first[name])
        table.insert(propertyHandles,{p,name,value})
    end
    table.insert(propertyEdits,{path=first:GetFullName(),property=name,count=#items,
        before=encode(first[name]),after=encode(value)})
end
setting({lighting},"Brightness",1.78)
setting({lighting},"ExposureCompensation",-.055)
setting({lighting},"Ambient",rgb(142,148,157))
setting({lighting},"OutdoorAmbient",rgb(176,183,190))
setting({lighting},"ColorShift_Top",rgb(25,15,8))
setting({lighting.ColorCorrection},"Contrast",.035)
setting({lighting.ColorCorrection},"Saturation",.19)
setting({lighting.Bloom},"Intensity",.08)
local lamps = {}
for _,p in ipairs(map.QuarryLanterns:GetDescendants()) do
    if p:IsA("PointLight") and p.Name=="LocalGlow" then table.insert(lamps,p) end
end
assert(#lamps==12)
setting(lamps,"Brightness",1.12)

local function block(parent,name,size,center,finish,tint,yaw)
    local p = Instance.new("Part")
    p.Name,p.Size = name,size
    p.CFrame = CFrame.new(center)*CFrame.Angles(0,yaw or 0,0)
    p.Material,p.MaterialVariant,p.Color = finish.BaseMaterial,finish.Name,tint
    p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery = true,false,false,false
    p.CastShadow = size.Y>.4
    p.TopSurface,p.BottomSurface = Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local hub = folder("Hub",scenery)
-- A thin finish joins the existing gravel routes across the spawn area.
block(hub,"GravelCourt",v(39,.12,18.1),v(1,4.042,15.98),gravel,stone)
local layers = folder("GroundLayers",scenery)
local function layer(surface,texture,scaleU,scaleV,tint,opacity,phase)
    local size=surface.Size
    local carrier=block(layers,surface.Name.."Grain",v(size.X,.025,size.Z),
        (surface.CFrame*v(0,size.Y/2+.017,0)),gravel,Color3.new(1,1,1))
    carrier.CFrame=surface.CFrame*CFrame.new(0,size.Y/2+.017,0)
    carrier.Transparency=1
    local grain=Instance.new("Texture")
    grain.Name="SecondaryGrain"
    grain.Texture="rbxassetid://"..texture
    grain.Face=Enum.NormalId.Top
    grain.StudsPerTileU,grain.StudsPerTileV=scaleU,scaleV
    grain.OffsetStudsU=(surface.Position.X-size.X/2+phase)%scaleU
    grain.OffsetStudsV=(surface.Position.Z-size.Z/2+phase*.67)%scaleV
    grain.Color3,grain.Transparency=tint,1-opacity
    grain.Parent=carrier
end
for _,region in ipairs(ground.Terraces:GetChildren()) do
    for _,p in ipairs(region:GetChildren()) do
        if p.Name:match("^Turf") then layer(p,"118972165990804",37,31,earthTints[region.Name][1],.28,9) end
    end
end
for _,field in ipairs(fields:GetChildren()) do
    layer(field.Field,"83637161982243",29,37,rgb(171,163,161),.23,field.Field.Position.X*.19)
end
layer(map.SimpleFlatTestMap.HubPad,"118972165990804",37,31,olive,.28,9)
-- The main gravel layer continues onto the authored walks beyond the court.
layer(hub.GravelCourt,"83637161982243",29,37,rgb(180,169,164),.25,6)
for _,p in ipairs(authored.MarketSquare:GetChildren()) do
    if p.Name:find("Walk") or p.Name=="ShopApron" then
        layer(p,"83637161982243",29,37,rgb(180,169,164),.25,6)
    end
end

local protected, occupied = {{0,12,5.3,15}}, {}
local function reserve(list,p,margin)
    local f,h=p.CFrame,p.Size/2
    table.insert(list,{f.X,f.Z,
        math.abs(f.RightVector.X)*h.X+math.abs(f.LookVector.X)*h.Z+margin,
        math.abs(f.RightVector.Z)*h.X+math.abs(f.LookVector.Z)*h.Z+margin})
end
for _,f in ipairs(fields:GetChildren()) do reserve(protected,f.Field,.7) end
for _,p in ipairs(authored.WalkableRoutes:GetChildren()) do reserve(protected,p,.8) end
for _,p in ipairs(map.EmeraldChalkLagoon:GetChildren()) do
    if p.Name=="LagoonCauseway" then reserve(protected,p,.7) end
end
for _,p in ipairs(map.SimpleFlatTestMap:GetDescendants()) do
    if p:IsA("BasePart") and p.Name:match("Pad$") and p.Name~="HubPad" then reserve(protected,p,2) end
end
for _,group in ipairs({oldMotifs,ground.PatternedAccents,map.QuarryArrivalAccents}) do
    for _,p in ipairs(group:GetDescendants()) do
        if p:IsA("BasePart") then reserve(occupied,p,1) end
    end
end
for _,p in ipairs(map.QuarryLanterns:GetChildren()) do
    if p.Name=="LampPost" then reserve(occupied,p,1.4) end
end
for _,p in ipairs(ground.OriginalDetails:GetDescendants()) do
    if p:IsA("Model") then
        local b,s=p:GetBoundingBox()
        table.insert(occupied,{b.X,b.Z,math.min(s.X/2,4),math.min(s.Z/2,4)})
    end
end
local ray = RaycastParams.new()
ray.RespectCanCollide=true
local function anchor(x,z,y,r)
    for _,list in ipairs({protected,occupied}) do
        for _,rect in ipairs(list) do
            if math.abs(x-rect[1])<r+rect[3] and math.abs(z-rect[2])<r+rect[4] then return end
        end
    end
    local top
    for _,d in ipairs({v(0,0,0),v(r,0,r),v(-r,0,r),v(r,0,-r),v(-r,0,-r)}) do
        local hit=workspace:Raycast(v(x,y+1,z)+d,v(0,-1.4,0),ray)
        if not hit or hit.Normal.Y<.98 or math.abs(y-hit.Position.Y)>.14
            or (top and math.abs(top-hit.Position.Y)>.10) then return end
        top=top or hit.Position.Y
    end
    table.insert(occupied,{x,z,r+.6,r+.6})
    if x>-18.5 and x<20.5 and z>6.93 and z<25.03 then top=math.max(top,4.102) end
    return v(x,top,z)
end
local function spot(choices,y,r)
    for _,p in ipairs(choices) do
        local at=anchor(p[1],p[2],y,r)
        if at then return at end
    end
    error(("No clear placement near %.1f, %.1f"):format(choices[1][1],choices[1][2]))
end
local function cube(parent,name,choices,y,width,height,finish,tint,yaw)
    local r=width*(math.cos(yaw)+math.abs(math.sin(yaw)))/2
    local at=spot(choices,y,r)
    block(parent,name,v(width,height,width),at+v(0,height/2,0),finish,tint,yaw)
end
cube(hub,"RoseQuartzSample",{{-11.5,21},{-11,23},{12,2}},4,7,7,roseStone,rgb(231,141,153),-.12)
cube(hub,"FiredBrickSample",{{38,8},{36,3},{-40,17}},4,5,4.5,firedBrick,rgb(255,248,238),.17)
cube(hub,"TimberSample",{{-32,20},{-32,22},{-37,16}},4,4.2,3.6,mat.QuarryAccent_Timber,rgb(241,203,151),-.12)
cube(hub,"TallCheckerSample",{{11,-13},{12,-19},{-11,-18}},4,6.1,8.1,mat.QuarryAccent_Checker,rgb(226,211,184),.09)

local function tree(parent, choices,y,scale)
    local at=spot(choices,y,3.15*scale)
    local group=folder("SteppedTree",parent)
    block(group,"Trunk",v(1.55,2.25,1.55)*scale,at+v(0,1.125*scale,0),mat.QuarryFoliage_Bark,rgb(138,104,73))
    for i,entry in ipairs({{6.3,2.25,rgb(136,169,80)},{4.75,4.1,rgb(155,186,86)},{3.05,5.85,rgb(175,197,100)}}) do
        block(group,"Canopy"..i,v(entry[1],1.85,entry[1])*scale,at+v(0,entry[2]*scale,0),
            mat.QuarryPalette_LeafClumps,entry[3])
    end
end
local function flowers(parent,choices,y)
    local at=spot(choices,y,1.95)
    local group=folder("CrossFlowers",parent)
    local colors={rgb(242,191,75),rgb(245,135,161),rgb(114,191,221),rgb(232,115,104)}
    local offsets={v(-1.12,.27,-.95),v(.86,.25,-1.12),v(-.78,.21,.86),v(1.23,.22,.57)}
    local base=mat.QuarryDrone_Painted
    for i,d in ipairs(offsets) do
        local yaw=i*.29
        block(group,"Petals",v(.87,.22,.3),at+d,base,colors[i],yaw)
        block(group,"Petals",v(.30,.22,.87),at+d,base,colors[i],yaw)
    end
end
tree(hub,{{-33,11},{-35,8},{-40,10}},4,1)
tree(hub,{{35,-13},{38,-11},{36,-19},{44,-17},{41,-8}},4,.77)
flowers(hub,{{-30,15},{-31,17},{-39,12}},4)
flowers(hub,{{30,17},{30,21},{33,19}},4)
flowers(hub,{{9,16},{9,19},{11,16}},4)
flowers(hub,{{-12,-16},{-9,-18},{-12,-21}},4)

local function planting(name,y,trees,blooms)
    local group=folder(name,scenery)
    if trees then tree(group,trees,y,.82) end
    for _,choices in ipairs(blooms) do flowers(group,choices,y) end
end
planting("Quartz",4,{{-104,78},{-115,74},{-117,67}},{
    {{-111,73},{-107,78},{-116,80}},{{-96,138},{-99,140},{-101,135}},
})
planting("Impact",4,{{103,70},{115,67},{119,66}},{
    {{97,59},{102,57},{115,58}},{{101,129},{106,131},{113,132}},
})
planting("Ruby",20,{{-148,37},{-153,37},{-175,34}},{
    {{-100,44},{-109,44},{-119,43},{-136,44},{-124,43},{-159,42},{-186,38}},{{-161,-15},{-168,-17},{-177,-17}},
})
planting("Cobalt",20,nil,{
    {{91,44},{99,44},{101,44},{111,36},{124,36},{136,44},{141,35},{188,38},{182,44}},{{154,30},{157,35},{165,24}},
})
planting("Violet",38,{{-104,-130},{-109,-132},{-123,-126}},{
    {{-105,-119},{-111,-117},{-121,-120}},{{-59,-146},{-57,-147},{-62,-154}},
})
planting("Emerald",42,{{111,-100},{115,-113},{111,-110},{117,-134},{114,-154},{118,-169},{138,-157}},{
    {{106,-82},{111,-83},{117,-86}},{{51,-146},{49,-145},{46,-153}},
})

local serializer, encoding = game:GetService("SerializationService"), game:GetService("EncodingService")
local function encode(bytes)
    return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(bytes,Enum.CompressionAlgorithm.Zstd)))
end
local function json(x) return encode(buffer.fromstring(game.HttpService:JSONEncode(x))) end
local snapshot={
    scenery=encode(serializer:SerializeInstancesAsync({scenery})),
    variants=encode(serializer:SerializeInstancesAsync(variants)),
    edits=json({parts=partEdits,properties=propertyEdits}),
}
local function apply()
    assert(game:GetService("RunService"):IsEdit() and not scenery.Parent)
    for _,item in ipairs(variants) do item.Parent=mat end
    for _,e in ipairs(partHandles) do e[1].Color,e[1].MaterialVariant=e[2],e[3] end
    for _,e in ipairs(propertyHandles) do e[1][e[2]]=e[3] end
    scenery.Parent=map
    return {surfaceEdits=#partEdits,lightEdits=#propertyHandles,addedInstances=#scenery:GetDescendants()}
end
shared.QuarryCourtyard={snapshot=snapshot,apply=apply}
return {parts=#partEdits,settings=#propertyEdits,addedInstances=#scenery:GetDescendants()}
