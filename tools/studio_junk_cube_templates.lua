-- Run in DRONEREVOLUTION Edit. Stage one native template folder for a scoped save.
local function checkEdit()
    assert(not game:GetService("RunService"):IsRunning(), "Expected Studio Edit")
    assert(game.PlaceId == 124078027733625 and game.GameId == 10774898335, "Wrong Roblox experience")
end
checkEdit()
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("JunkCubeTemplates"), "Template library already exists")

local specs = {
    SuggestionBox = {size=6.2, front="rbxassetid://72213799953835", side="rbxassetid://112004981306630", top="rbxassetid://110524207879393"},
    GumballDispenser = {size=6, front="rbxassetid://106388902076745", side="rbxassetid://129022618967631", top="rbxassetid://113561068034390", back="rbxassetid://91784662841732"},
    AlphabetBlock = {size=5.4, front="rbxassetid://76119583477215", side="rbxassetid://128489014480578", top="rbxassetid://97290003219397"},
    BoxFan = {size=6.4, front="rbxassetid://93961949413835", side="rbxassetid://109061592871593", top="rbxassetid://118026330567753"},
    CubeAquarium = {size=6.1, front="rbxassetid://122623759199725", side="rbxassetid://139358738414450", top="rbxassetid://82474460314139"},
    IceCube = {size=5.6, front="rbxassetid://100819564990345", side="rbxassetid://94672407242314"},
    TicketBox = {size=5.5, front="rbxassetid://76628551710533", side="rbxassetid://135381551727565"},
    MovingBox = {size=6.6, front="rbxassetid://83882738096195", side="rbxassetid://133564101968592", top="rbxassetid://124988789231346"},
}
local folder = Instance.new("Folder")
folder.Name = "JunkCubeTemplates"
local images, decals = {}, {}
for name, spec in pairs(specs) do
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = Enum.PartType.Block
    part.Size = Vector3.one * spec.size
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    local faces = {
        Front = spec.front, Back = spec.back or spec.side, Left = spec.side, Right = spec.side,
        Top = spec.top or spec.side, Bottom = spec.back or spec.side,
    }
    for face, image in pairs(faces) do
        local decal = Instance.new("Decal")
        decal.Name = face
        decal.Face = Enum.NormalId[face]
        decal.Texture = image
        decal.Parent = part
        table.insert(decals, decal)
        images[image] = true
    end
    part.Parent = folder
end

local provider = game:GetService("ContentProvider")
provider:PreloadAsync(decals)
local failed = {}
local imageCount = 0
for image in pairs(images) do
    imageCount += 1
    if provider:GetAssetFetchStatus(image) ~= Enum.AssetFetchStatus.Success then
        table.insert(failed, image)
    end
end
assert(#failed == 0, "Images unavailable in Studio: " .. table.concat(failed, ", "))

local serialization, encoding = game:GetService("SerializationService"), game:GetService("EncodingService")
local serialized = serialization:SerializeInstancesAsync({folder})
local packed = encoding:CompressBuffer(serialized, Enum.CompressionAlgorithm.Zstd)
local export = buffer.tostring(encoding:Base64Encode(packed))
local function apply()
    checkEdit()
    assert(not folder.Parent and not storage:FindFirstChild(folder.Name), "Library already installed")
    folder.Parent = storage
    return #folder:GetChildren()
end
shared.JunkCubeTemplateStage = {export=export, apply=apply}
return {templates=#folder:GetChildren(), images=imageCount, export=export}
