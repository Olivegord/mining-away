-- Replace the perimeter with an authored island while retaining the playable terraces.
local function checkEdit()
    assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong experience")
    assert(game:GetService("RunService"):IsEdit(), "Expected Studio Edit")
end
checkEdit()
local world = workspace.MiningAway
local map, storage = world.Map, game:GetService("ServerStorage")
assert(not map:FindFirstChild("ReserveIsland") and not storage:FindFirstChild("IslandShoreArchive"))
local moves = {
    {map.LiminalReserve.Enclosure, map.LiminalReserve, 136},
    {map.QuarryBlockRim, map, 87},
    {map.QuarryBasinFoothills.GrassRim, map.QuarryBasinFoothills, 41},
}
for _,entry in ipairs(moves) do
    assert(entry[1].Parent == entry[2] and #entry[1]:GetDescendants() == entry[3], "Reconcile changed rim")
end

local v, rgb = Vector3.new, Color3.fromRGB
local materials = game:GetService("MaterialService")
local grass, gravel, slate = materials.QuarryPhoto_Grass, materials.QuarryPhoto_Pebble, materials.QuarryPhoto_Slate
local function folder(name,parent)
    local object = Instance.new("Folder")
    object.Name, object.Parent = name, parent
    return object
end
local island = folder("ReserveIsland")
local archive = folder("IslandShoreArchive")
local land = folder("Coastline",island)
local sea = folder("OpenWater",island)
local shallows = folder("Shallows",island)

local function piece(parent, name, class, frame, size, finish, color, solid)
    local p = Instance.new(class)
    p.Name, p.CFrame, p.Size = name, frame, size
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, solid, solid, false
    p.CastShadow = parent == land
    p.Material = finish and finish.BaseMaterial or Enum.Material.SmoothPlastic
    p.MaterialVariant = finish and finish.Name or ""
    p.Color = color
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

-- Native wedges make each triangle editable without a generated mesh asset.
local function triangle(parent,name,a,b,c,finish,color,solid,thickness)
    local ab,ac,bc = b-a,c-a,c-b
    if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then
        a,c = c,a
    elseif ac:Dot(ac)>bc:Dot(bc) then
        a,b = b,a
    end
    ab,ac,bc = b-a,c-a,c-b
    local right,back = ac:Cross(ab).Unit,bc.Unit
    local up = back:Cross(right).Unit
    local height = math.abs(ab:Dot(up))
    local function half(center,x,z,length)
        if length>.03 and height>.03 then
            piece(parent,name,"WedgePart",CFrame.fromMatrix(center,x,up,z),
                v(thickness,height+.035,length+.035),finish,color,solid)
        end
    end
    half((a+b)*.5,right,back,math.abs(ab:Dot(back)))
    half((a+c)*.5,-right,-back,math.abs(ac:Dot(back)))
end
local function quad(parent,name,a,b,c,d,finish,color,solid,thickness)
    triangle(parent,name,a,b,c,finish,color,solid,thickness)
    triangle(parent,name,a,c,d,finish,color,solid,thickness)
end

local shore = {
    {-269,-54},{-254,-120},{-221,-194},{-154,-249},{-77,-252},
    {-40,-214},{17,-207},{55,-233},{100,-260},{169,-251},
    {229,-208},{276,-156},{289,-85},{269,-22},{265,39},
    {286,89},{262,148},{222,203},{170,238},{128,272},
    {78,266},{34,226},{-26,225},{-74,274},{-131,272},
    {-179,241},{-224,210},{-255,151},{-266,85},{-251,15},
}
local shelf, shingle, foot, nearWater, outerWater = {},{},{},{},{}
local waterHeight = -4.65
for i,point in ipairs(shore) do
    local x,z = table.unpack(point)
    local headland = (.5+.5*math.sin(i*1.68))
    shelf[i] = v(x*.851,2.63,z*.851)
    shingle[i] = v(x*.927,.4+headland*.8,z*.927)
    foot[i] = v(x,-7.4,z)
    nearWater[i] = v(x*.965,waterHeight+.035,z*.965)
    outerWater[i] = v(x*(1.065+headland*.022),waterHeight+.035,z*(1.065+headland*.022))
end

-- A level ocean extends far enough to give the low fields an open horizon.
for x=-1,1 do for z=-1,1 do
    piece(sea,"Ocean","Part",CFrame.new(x*2048,waterHeight-.16,z*2048),
        v(2048,.32,2048),nil,rgb(80,158,191),false)
end end
local center = v(0,2.63,0)
for i=1,#shore do
    local j = i%#shore+1
    local tone = .5+.5*math.sin(i*1.31)
    local grassTint = rgb(149,178,117):Lerp(rgb(175,190,125),tone*.55)
    local sandTint = rgb(207,197,156):Lerp(rgb(226,211,170),tone*.65)
    local stoneTint = rgb(144,152,137):Lerp(rgb(174,173,152),tone*.66)
    local beach = shore[i][2]>160 or i%7==0
    triangle(land,"IslandFoot",center,shelf[i],shelf[j],grass,rgb(160,184,124),true,.28)
    quad(land,"CoastalGrass",shelf[i],shelf[j],shingle[j],shingle[i],grass,grassTint,true,.27)
    quad(land,"Beach",shingle[i],shingle[j],foot[j],foot[i],beach and gravel or slate,
        beach and sandTint or stoneTint,true,.33)
    local outer = rgb(112,179,190):Lerp(rgb(132,193,192),tone*.37)
    quad(shallows,"ShelfWater",nearWater[i],nearWater[j],outerWater[j],outerWater[i],
        nil,outer,false,.045)
    if i%2~=0 or beach then
        local along = (foot[j]-foot[i]).Unit
        for stripe=1,2 do
            local a = nearWater[i]:Lerp(outerWater[i],.35+stripe*.22)
            local b = nearWater[j]:Lerp(outerWater[j],.35+stripe*.22)
            local at = a:Lerp(b,.21+tone*.49+(stripe-1)*.075)+v(0,.06+stripe*.025,0)
            local w = 7+tone*13+stripe*2
            local foam = piece(shallows,"BrokenFoam","Part",CFrame.lookAt(at,at+along)*CFrame.Angles(0,math.pi/2,0),
                v(w,.035,.29+tone*.17),nil,rgb(189,222,219),false)
            foam.Transparency = .35+stripe*.12
        end
    end
    if i%3==1 then
        local p = shelf[i]:Lerp(shingle[i],.64)
        for stack=1,3 do
            local at = p+shelf[i]:Lerp(shelf[j],stack*.045)-shelf[i]
            local h = 1+stack*.55
            piece(land,"ShoreStone","WedgePart",CFrame.new(at+v(0,h*.34,0))*CFrame.Angles(0,i*.87+stack*.76,0),
                v(3.7+stack*1.12,h,3.1+tone*2.9),slate,stoneTint,false)
        end
    end
end

local samples = {}
local function sample(at) table.insert(samples,at) end
for _,field in ipairs(world.Fields:GetChildren()) do
    local bed = field:FindFirstChild("Field")
    if bed then
        for x=-2,2 do for z=-2,2 do
            sample(bed.CFrame:PointToWorldSpace(v(bed.Size.X*x/5,bed.Size.Y/2,bed.Size.Z*z/5)))
        end end
    end
end
local terraces = map.DronerevolutionTerraces
for _,route in ipairs(terraces.WalkableRoutes:GetDescendants()) do
    if route:IsA("BasePart") then
        for _,z in ipairs({-.4,0,.4}) do
            sample(route.CFrame:PointToWorldSpace(v(0,route.Size.Y/2,route.Size.Z*z)))
        end
    end
end
for _,item in ipairs(map.EmeraldChalkLagoon:GetChildren()) do
    if item.Name=="LagoonCauseway" and item:IsA("BasePart") then sample(item.Position) end
end
local hub,deck = map.SimpleFlatTestMap.HubPad,terraces.LogisticsApron.ServiceDeck
for _,p in ipairs({hub,deck}) do
    for x=-2,2 do for z=-2,2 do
        sample(p.CFrame:PointToWorldSpace(v(p.Size.X*x/5,p.Size.Y/2,p.Size.Z*z/5)))
    end end
end
local ray = RaycastParams.new()
ray.RespectCanCollide = true
local function supports()
    local out = {}
    for index,at in ipairs(samples) do
        local hit = workspace:Raycast(at+v(0,8,0),v(0,-20,0),ray)
        out[index] = hit and {hit.Instance,hit.Position.Y} or false
    end
    return out
end
local before = supports()
local treeEdits, treeParts, trees = {}, {}, {}
local function coordinates(point) return {point.X,point.Y,point.Z} end
for _,group in ipairs(map.QuarryBasinFoothills:GetChildren()) do
    local plateau = group:FindFirstChild("RaisedPlateau")
    if not plateau then continue end
    local plateauRay = RaycastParams.new()
    plateauRay.FilterType,plateauRay.FilterDescendantsInstances = Enum.RaycastFilterType.Include,{plateau}
    for _,tree in ipairs(group:GetChildren()) do
        if tree.Name~="ShelfTree" or not tree:IsA("Model") then continue end
        local box,size = tree:GetBoundingBox()
        local foot = box.Position-v(0,size.Y/2,0)
        local hit = assert(workspace:Raycast(foot+v(0,2,0),v(0,-40,0),plateauRay),tree:GetFullName())
        local drop = foot.Y-hit.Position.Y
        if drop<.85 then continue end
        table.insert(trees,{tree,hit.Position.Y})
        for _,p in ipairs(tree:GetDescendants()) do
            if not p:IsA("BasePart") then continue end
            assert(p.ClassName=="Part" and p.Anchored and not p.CanQuery)
            local old,new = p.Position,p.Position-v(0,drop,0)
            table.insert(treeParts,{p,old,new})
            table.insert(treeEdits,{path=p:GetFullName(),class=p.ClassName,anchor=coordinates(old),
                anchorSize=coordinates(p.Size),before={position=coordinates(old)},after={position=coordinates(new)}})
        end
    end
end
local serial, encoding = game:GetService("SerializationService"),game:GetService("EncodingService")
local function compress(bytes)
    return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(bytes,Enum.CompressionAlgorithm.Zstd)))
end
shared.ReserveIsland = {
    scenery=compress(serial:SerializeInstancesAsync({island})),
    archive=compress(serial:SerializeInstancesAsync({archive})),
    trees=compress(buffer.fromstring(game:GetService("HttpService"):JSONEncode(treeEdits))),
    rollback=function()
        island.Parent = nil
        for _,entry in ipairs(moves) do entry[1].Parent = entry[2] end
        for _,entry in ipairs(treeParts) do entry[1].Position = entry[2] end
        archive.Parent = nil
    end,
    apply=function()
        checkEdit()
        assert(not island.Parent and not archive.Parent)
        for _,entry in ipairs(moves) do
            assert(entry[1].Parent==entry[2] and #entry[1]:GetDescendants()==entry[3],"Rim changed while staged")
        end
        for _,entry in ipairs(treeParts) do assert(entry[1].Position==entry[2],"Tree moved while staged") end
        archive.Parent = storage
        for _,entry in ipairs(moves) do entry[1].Parent = archive end
        island.Parent = map
        for _,entry in ipairs(treeParts) do entry[1].Position = entry[3] end
        local ok,report = pcall(function()
            local after = supports()
            for i,old in ipairs(before) do
                local new = after[i]
                assert((not old and not new) or (old and new and old[1]==new[1] and math.abs(old[2]-new[2])<.01),
                    "Protected ground changed at "..i)
            end
            local coast = RaycastParams.new()
            coast.FilterType,coast.FilterDescendantsInstances = Enum.RaycastFilterType.Include,{land}
            for i=1,#shore do
                local j = i%#shore+1
                for _,t in ipairs({.15,.5,.85}) do
                    local wet = foot[i]:Lerp(foot[j],t)
                    local dry = shelf[i]:Lerp(shelf[j],t)*.96
                    local inner = workspace:Raycast(v(dry.X,20,dry.Z),v(0,-35,0),coast)
                    local outer = workspace:Raycast(v(wet.X*1.03,20,wet.Z*1.03),v(0,-35,0),coast)
                    assert(inner and inner.Position.Y>waterHeight and not outer,"Broken shoreline "..i)
                end
            end
            for _,entry in ipairs(trees) do
                local box,size = entry[1]:GetBoundingBox()
                assert(math.abs(box.Position.Y-size.Y/2-entry[2])<.025,"Shelf tree is off the ground")
            end
            return {groundSamples=#samples,shoreProbes=#shore*6,archived=#moves,seaTiles=#sea:GetChildren(),trees=#trees}
        end)
        if not ok then shared.ReserveIsland.rollback();error(report) end
        return report
    end,
}
return {scenery=#shared.ReserveIsland.scenery,archive=#shared.ReserveIsland.archive,trees=#shared.ReserveIsland.trees}
