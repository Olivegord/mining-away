-- Run after the RockFinish bundle and tools/studio_bake_gem.lua.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning() and not shared.RubyRestore)
local ruby=workspace.MiningAway.Map.MineralLineup.Ruby
local archive=game.ServerStorage.MineralLineupArchive
local old=ruby.PreviewGeometry
assert(not archive:FindFirstChild(old.Name))
local anchor=ruby.SpecimenAnchor
local data=RockFinish.Gems.geometry.describe('Ruby')
assert(data.aspect==Vector3.new(.94,1.10,.84) and #data.faces==56 and #data.grains==30)
local preview=bakeGemPreview('Ruby',data,anchor.CFrame,anchor.Size*data.aspect)
assert(#preview:GetChildren()==2 and preview:FindFirstChild('FacetShell') and preview:FindFirstChild('FixedInclusions'))
local e=game:GetService('EncodingService')
local model=game:GetService('SerializationService'):SerializeInstancesAsync({preview})
local encoded=buffer.tostring(e:Base64Encode(e:CompressBuffer(model,Enum.CompressionAlgorithm.Zstd)))
shared.RubyRestore={data=encoded,apply=function()
 assert(not game:GetService('RunService'):IsRunning() and old.Parent==ruby and not archive:FindFirstChild(old.Name))
 old.Parent=archive
 preview.Parent=ruby
 return {path=preview:GetFullName(),partCount=#preview:GetChildren()}
end}
return {bytes=#encoded,partCount=#preview:GetChildren(),pad=tostring(ruby.DisplayPad.Position)}
