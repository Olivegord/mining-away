-- Bundle RockFinish and studio_bake_gem.lua before this Diamond-only stage.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning() and not shared.DiamondSpectrumStage)
local diamond=workspace.MiningAway.Map.MineralLineup.Diamond
local previous=diamond.PreviewGeometry
local archive=Instance.new('Folder');archive.Name='DiamondSpectrumArchive'
assert(not game.ServerStorage:FindFirstChild(archive.Name))
local anchor=diamond.SpecimenAnchor
local data=RockFinish.Gems.geometry.describe('Diamond')
local preview=bakeGemPreview('Diamond',data,anchor.CFrame,anchor.Size*data.aspect)
assert(preview:FindFirstChild('PrismaticEdges'))
local serializer,encoding=game:GetService('SerializationService'),game:GetService('EncodingService')
local function encode(instance)
 return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(serializer:SerializeInstancesAsync({instance}),Enum.CompressionAlgorithm.Zstd)))
end
shared.DiamondSpectrumStage={snapshot={scenery=encode(preview),archive=encode(archive)},apply=function()
 assert(not game:GetService('RunService'):IsRunning() and diamond.PreviewGeometry==previous)
 archive.Parent=game.ServerStorage;previous.Parent=archive;preview.Parent=diamond
 return {path=preview:GetFullName(),descendants=#preview:GetDescendants()}
end}
return {bytes=#shared.DiamondSpectrumStage.snapshot.scenery,descendants=#preview:GetDescendants()}
