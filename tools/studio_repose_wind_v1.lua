-- Stage the revised hero pose on a detached clone and retain the exact before export.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local root=assert(workspace:FindFirstChild("VERSION 1"))
assert(root:GetAttribute("WindVortexVersion")==1 and root:GetAttribute("CastAt")==nil)
local function export(model)
 local bytes=game:GetService("SerializationService"):SerializeInstancesAsync({model})
 local enc=game:GetService("EncodingService")
 return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(bytes,Enum.CompressionAlgorithm.Zstd)))
end
local pose=WindVortexV1.editPose
local sample=root:Clone()
local before=export(root)
WindVortexV1.pose(WindVortexV1.bind(sample),pose)
local after=export(sample)
sample:Destroy()
local stage={before=before,after=after}
stage.apply=function()
 assert(game.RunService:IsEdit() and root==workspace["VERSION 1"] and root:GetAttribute("CastAt")==nil)
 -- The scoped saver compares the live before pose to the canonical baseline.
 -- Refuse an intervening change in shared Edit as well.
 assert(export(root)==before,"Version 1 changed since staging")
 WindVortexV1.pose(WindVortexV1.bind(root),pose)
 stage.verified=export(root)
 return #stage.verified
end
shared.WindV1Repose=stage
return {before=#before,after=#after}
