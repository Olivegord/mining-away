-- Bundle RockFinish and studio_bake_gem.lua before this checked Edit stage.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning() and not shared.GemFinishMatchStage)
local map=workspace.MiningAway.Map
local previous=map.MineralLineup
local archive=Instance.new('Folder');archive.Name='GemFinishMatchArchive'
assert(not game.ServerStorage:FindFirstChild(archive.Name))
local root=previous:Clone()
for row=1,2 do
 for _,key in ipairs(RockFinish.Gems.geometry.order) do
  local compact=row==2
  local model=root[key..(compact and 'Compact' or '')]
  model.Name=key..(compact and 'Compact' or '')
  model:SetAttribute('MineralSample',key)
  local anchor=model.SpecimenAnchor;anchor:SetAttribute('Mineral',key)
  anchor:SetAttribute('GemCut',compact and 'Compact' or nil)
  local data=RockFinish.Gems.geometry.describe(key,compact)
  local size=anchor.Size*data.aspect
  local pad=model.DisplayPad
  anchor.CFrame=CFrame.new(pad.Position.X,pad.Position.Y+pad.Size.Y*.5+.48+size.Y*.5,pad.Position.Z)*anchor.CFrame.Rotation
  model.PreviewGeometry:Destroy()
  bakeGemPreview(key,data,anchor.CFrame,size).Parent=model
  for _,p in ipairs(model:GetDescendants()) do
   if p:IsA('TextLabel') then p.Text=key:upper()..(compact and ' / COMPACT' or '') end
   if p:IsA('BasePart') then p.LocalTransparencyModifier=0 end
  end
  task.wait()
 end
end
local serializer,encoding=game:GetService('SerializationService'),game:GetService('EncodingService')
local function encode(instance)
 return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(serializer:SerializeInstancesAsync({instance}),Enum.CompressionAlgorithm.Zstd)))
end
shared.GemFinishMatchStage={root=root,snapshot={scenery=encode(root),archive=encode(archive)},apply=function()
 assert(not game:GetService('RunService'):IsRunning() and map.MineralLineup==previous)
 archive.Parent=game.ServerStorage;previous.Parent=archive;root.Parent=map
 return {placeId=game.PlaceId,universeId=game.GameId,order=RockFinish.Gems.geometry.order,parts=#root:GetDescendants()}
end}
return {bytes=#shared.GemFinishMatchStage.snapshot.scenery,descendants=#root:GetDescendants()}
