-- Stage the photographed faces and the authored prop grid on the tan ServiceDeck.
local function checkEdit()
    assert(not game:GetService("RunService"):IsRunning(), "Expected Studio Edit")
    assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong Roblox experience")
end
checkEdit()

local map = workspace.MiningAway.Map
local deck = map.DronerevolutionTerraces.LogisticsApron.ServiceDeck
local templates = game.ServerStorage.JunkCubeTemplates
local motifs = map.QuarryMotifScenery
local accents = map.QuarryContinuousGround.PatternedAccents

-- Face order is front, side, top, back. Side fills unspecified faces.
local before = {
    GumballDispenser = {"106388902076745", "129022618967631", "113561068034390", "91784662841732"},
    AlphabetBlock = {"76119583477215", "128489014480578", "97290003219397"},
    BoxFan = {"93961949413835", "109061592871593", "118026330567753"},
    CubeAquarium = {"122623759199725", "139358738414450", "82474460314139"},
    IceCube = {"100819564990345", "94672407242314"},
    TicketBox = {"76628551710533", "135381551727565"},
}
local photographs = {
    GumballDispenser = {"101810481156570", "101810481156570"},
    AlphabetBlock = {"84999384725093", "125212600236177", "116071959828195"},
    BoxFan = {"101403951748700", "113546682006582", "123619630591778"},
    CubeAquarium = {"96542276756320", "85151127865076", "133217461882504"},
    IceCube = {"88834508418674", "97206479305223"},
    TicketBox = {"99341485540982", "84353698289172"},
}
local function faces(ids)
    return {Front=ids[1], Left=ids[2], Right=ids[2], Top=ids[3] or ids[2],
            Back=ids[4] or ids[2], Bottom=ids[4] or ids[2]}
end
local edits = {}
for name, ids in pairs(photographs) do
    local old = faces(before[name])
    for face, asset in pairs(faces(ids)) do
        table.insert(edits, {template=name, face=face, before="rbxassetid://" .. old[face],
                            after="rbxassetid://" .. asset})
    end
end
local draft = map:FindFirstChild("JunkCubeLineup")
local function checkBaseline()
    assert(map:FindFirstChild("JunkCubeLineup") == draft, "Display changed while staging")
    assert(not draft or #draft:GetChildren() == 8, "Unexpected existing display")
    for _, edit in ipairs(edits) do
        local texture = templates[edit.template][edit.face].Texture
        assert(texture == edit.before or (draft and edit.template == "GumballDispenser"
            and texture == "rbxassetid://117133783246488"), "Template face changed: " .. edit.template .. "." .. edit.face)
    end
end
checkBaseline()
assert(deck.CFrame.UpVector:Dot(Vector3.yAxis) > .999 and deck.Size.X >= 70 and deck.Size.Z >= 72,
    "The photographed deck has moved or been resized")

local function sample(variant)
    for _, part in ipairs(accents:GetChildren()) do
        if part:IsA("Part") and part.Name == "SampleBlock" and part.MaterialVariant == variant then
            return part
        end
    end
    error("Missing patterned prop " .. variant)
end
local props = {
    {templates.SuggestionBox, "Suggestion Box"},
    {templates.GumballDispenser, "Gumballs"},
    {templates.AlphabetBlock, "Alphabet Block"},
    {templates.BoxFan, "Box Fan"},
    {templates.CubeAquarium, "Cube Aquarium"},
    {templates.IceCube, "Ice Cube"},
    {templates.TicketBox, "Ticket Box"},
    {templates.MovingBox, "Moving Box"},
    {motifs:FindFirstChild("PipsCube", true), "Pip Block"},
    {motifs:FindFirstChild("BlueGinghamPaver", true), "Blue Gingham"},
    {motifs:FindFirstChild("TimberCube", true), "Battered Crate"},
    {motifs:FindFirstChild("KnitCube", true), "Knit Block"},
    {motifs:FindFirstChild("DaisiesCube", true), "Daisy Cube"},
    {motifs:FindFirstChild("RedGinghamPaver", true), "Red Gingham"},
    {motifs:FindFirstChild("StarsCube", true), "Stars"},
    {motifs:FindFirstChild("WavesCube", true), "Waves"},
    {motifs:FindFirstChild("StudsCube", true), "Gold Studs"},
    {motifs:FindFirstChild("RoseCube", true), "Rose Stone"},
    {motifs:FindFirstChild("BrickLow", true), "Fired Brick"},
    {sample("QuarryAccent_Brick"), "Brick"},
    {sample("QuarryAccent_Checker"), "Checker"},
    {sample("QuarryPalette_Pebbles"), "Pebbles"},
    {sample("QuarryAccent_Ribbed"), "Blue Ribs"},
}
local lineup = Instance.new("Folder")
lineup.Name = "JunkCubeLineup"
local decals = {}
local samples = 0
for index, entry in ipairs(props) do
    local source = assert(entry[1], entry[2])
    local part = source:Clone()
    assert(part:IsA("Part") and part.Shape == Enum.PartType.Block, entry[2])
    part.Name = entry[2]
    part.Size = Vector3.one * 6
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    local half = part.Size.X / 2
    local column, row = (index - 1) % 6, math.floor((index - 1) / 6)
    local x, y, z = (column - 2.5) * 10.5, deck.Size.Y / 2, deck.Size.Z / 2 - 11 - row * 11.5
    for _, offset in ipairs({{0, 0}, {-half, -half}, {half, -half}, {-half, half}, {half, half}}) do
        local ground = deck.CFrame:PointToWorldSpace(Vector3.new(x + offset[1], y, z + offset[2]))
        local hit = workspace:Raycast(ground + Vector3.yAxis * 10, -Vector3.yAxis * 10.5)
        assert(hit and hit.Instance == deck and (hit.Position - ground).Magnitude < .01,
            "Lineup needs unobstructed deck support: " .. part.Name)
        samples += 1
    end
    part.CFrame = deck.CFrame * CFrame.new(x, y + half, z) * CFrame.Angles(0, math.pi, 0)
    if source.Parent == templates then
        local images = photographs[source.Name] and faces(photographs[source.Name])
        assert(#part:GetChildren() == 6, part.Name)
        for _, decal in ipairs(part:GetChildren()) do
            assert(decal:IsA("Decal"), part.Name)
            if images then decal.Texture = "rbxassetid://" .. images[decal.Name] end
            table.insert(decals, decal)
        end
    else
        part:ClearAllChildren()
    end
    part.Parent = lineup
end

local content = game:GetService("ContentProvider")
content:PreloadAsync(decals)
for _, decal in ipairs(decals) do
    assert(content:GetAssetFetchStatus(decal.Texture) == Enum.AssetFetchStatus.Success, decal.Texture)
end
local serialize, encode = game:GetService("SerializationService"), game:GetService("EncodingService")
local bytes = serialize:SerializeInstancesAsync({lineup})
local export = buffer.tostring(encode:Base64Encode(encode:CompressBuffer(bytes, Enum.CompressionAlgorithm.Zstd)))
local function apply()
    checkEdit()
    checkBaseline()
    for _, edit in ipairs(edits) do templates[edit.template][edit.face].Texture = edit.after end
    if draft then draft:Destroy() end
    lineup.Parent = map
    return {parts=#lineup:GetChildren(), supportSamples=samples}
end
shared.JunkCubeLineupStage = {apply=apply}
return {parts=#props, supportSamples=samples, edits=edits, export=export}
