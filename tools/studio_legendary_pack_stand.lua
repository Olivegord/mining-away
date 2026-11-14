-- Stage the Studio-only pack preview counter in the existing authored depot.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local map=workspace.MiningAway.Map
local source=map.SimpleFlatTestMap.PackStationAssembly
assert(not map:FindFirstChild('LegendaryPreviewStand'))
local ray=RaycastParams.new();ray.RespectCanCollide=true
local function ground(x,z)
 return assert(workspace:Raycast(Vector3.new(x,12,z),Vector3.new(0,-16,0),ray))
end
local x,z=-38,19.5
local floor=ground(x,z)
assert(math.abs(floor.Position.Y-4)<.01)
local model=Instance.new('Model');model.Name='LegendaryPreviewStand'
local function part(template,name,y,size,color)
 local value=template:Clone()
 value:ClearAllChildren()
 for key in pairs(value:GetAttributes()) do value:SetAttribute(key,nil) end
 local tags=game:GetService('CollectionService')
 for _,tag in ipairs(tags:GetTags(value)) do tags:RemoveTag(value,tag) end
 value.Name=name;value.Size=size;value.Position=Vector3.new(x,y,z)
 value.Orientation=Vector3.zero;value.Color=color;value.Transparency=0
 value.Anchored=true;value.CanCollide=name~='Sign';value.CanTouch=false;value.CanQuery=name~='Sign';value.Parent=model
 return value
end
local base=part(source.PackStation,'Counter',4.7,Vector3.new(6.2,1.4,3.5),Color3.fromRGB(45,43,72))
part(source.PackStationPad,'GoldTop',5.56,Vector3.new(6.65,.32,3.95),Color3.fromRGB(242,179,66))
local sign=part(source.PackStation,'Sign',7.35,Vector3.new(6,1.45,.16),Color3.fromRGB(35,29,51))
sign.Material=Enum.Material.SmoothPlastic;sign.MaterialVariant=''
for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
 local surface=Instance.new('SurfaceGui');surface.Name=tostring(face.Name);surface.Face=face
 surface.CanvasSize=Vector2.new(600,144);surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;surface.LightInfluence=0;surface.Parent=sign
 local text=Instance.new('TextLabel');text.Name='LegendaryPack';text.Text='LEGENDARY PACK'
 text.Font=Enum.Font.GothamBlack;text.TextSize=51;text.BackgroundTransparency=1
 text.Position=UDim2.fromOffset(5,10);text.Size=UDim2.new(1,-10,0,76)
 text.TextColor3=Color3.fromRGB(255,211,99);text.Parent=surface
 local caption=text:Clone();caption.Name='StudioPreview';caption.Text='FREE STUDIO PREVIEW';caption.TextSize=27
 caption.TextColor3=Color3.fromRGB(242,239,250);caption.Position=UDim2.fromOffset(5,87);caption.Size=UDim2.new(1,-10,0,39);caption.Parent=surface
end
local spots={}
for _,off in ipairs({Vector3.new(0,0,3.4),Vector3.new(0,0,-5),Vector3.new(-5,0,0),Vector3.new(5,0,0)}) do
 local h=ground(x+off.X,z+off.Z)
 assert(math.abs(h.Position.Y-floor.Position.Y)<.18)
 table.insert(spots,{p=h.Position,source=h.Instance})
end
local function apply()
 assert(game.RunService:IsEdit() and not map:FindFirstChild(model.Name))
 model.Parent=map
 local ok,proof=pcall(function()
  assert(model.Counter==base and #model:GetDescendants()==9)
  for _,spot in ipairs(spots) do assert(ground(spot.p.X,spot.p.Z).Instance==spot.source) end
  assert(ground(x,z).Instance==model.GoldTop)
  return {placeId=game.PlaceId,universeId=game.GameId,parts=3,approaches=#spots}
 end)
 if not ok then model.Parent=nil;error(proof) end
 return proof
end
local encoding=game:GetService('EncodingService')
local blob=game:GetService('SerializationService'):SerializeInstancesAsync({model})
local scenery=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(blob,Enum.CompressionAlgorithm.Zstd)))
shared.LegendaryPreviewStand={scenery=scenery,apply=apply}
return {bytes=#scenery,position=tostring(base.Position)}
