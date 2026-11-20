-- Extend the original Mining Away checker across the depot's existing walks.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local map=workspace.MiningAway.Map
assert(not shared.DepotChecker)
local terraces=map.DronerevolutionTerraces
local market,fill=terraces.MarketSquare,map.PlatformSurfaceFill
local base=map.MiningAwayReferenceGround.Baseplate
local original=base.Texture
local hub=map.SimpleFlatTestMap.HubPad
local deck=terraces.LogisticsApron.ServiceDeck
local quartz=map.CrystalRun.Quartz.Field
local before=Color3.fromRGB(163,162,165)
local after=deck.Color
local parts={market.ShopApron,market.NorthSouthWalk,market.EastWestWalk,market.UtilityWalk,
 fill.DronerevolutionTerraces_MarketSquare_EastWestWalk_2,fill.DronerevolutionTerraces_MarketSquare_EastWestWalk_3,
 fill.DronerevolutionTerraces_MarketSquare_UtilityWalk_2,fill.DronerevolutionTerraces_MarketSquare_UtilityWalk_3}
assert(original.Texture=='rbxassetid://6372755229' and original.StudsPerTileU==8 and original.StudsPerTileV==8)
assert(after==Color3.fromRGB(109,106,105))
local function offsets(part)
 -- Same phase as the authored Crystal Run fields, measured from the baseplate.
 local corner=(part.Position-part.Size*.5)-(base.Position-base.Size*.5)
 return corner.X%8,corner.Z%8
end
local function sameFinish(texture)
 return texture.Texture==original.Texture and texture.Face==Enum.NormalId.Top
  and texture.StudsPerTileU==8 and texture.StudsPerTileV==8
  and texture.Transparency==original.Transparency and texture.Color3==original.Color3
end
local function aligned(part,texture)
 local u,v=offsets(part)
 return math.abs(texture.OffsetStudsU-u)<.001 and math.abs(texture.OffsetStudsV-v)<.001
end
assert(aligned(quartz,quartz.Texture))
local existing={hub.MiningAwayChecker,deck.MiningAwayChecker}
for _,texture in ipairs(existing) do
 assert(sameFinish(texture) and texture.OffsetStudsU==0 and texture.OffsetStudsV==0)
end
local textures,colors={},{}
for i,part in ipairs(parts) do
 assert(part:IsA('Part') and part.Material==Enum.Material.Plastic and part.MaterialVariant=='' and part.Reflectance==0)
 local alreadyTinted=part.Name:find('UtilityWalk',1,true)~=nil
 assert(part.Color==(alreadyTinted and after or before))
 assert(not part:FindFirstChildOfClass('Texture') and part.CFrame.RightVector==Vector3.xAxis and part.CFrame.UpVector==Vector3.yAxis)
 colors[i]=part.Color
 local texture=original:Clone();texture.Name='Checker'..part.Name
 texture.OffsetStudsU,texture.OffsetStudsV=offsets(part)
 textures[i]=texture
end
local params=RaycastParams.new();params.RespectCanCollide=true
local function floor(x,z)
 return assert(workspace:Raycast(Vector3.new(x,12,z),Vector3.new(0,-16,0),params))
end
local samples={}
for _,x in ipairs({-46,-35,-22,-18.6,-18.4,-8,0,8,20.4,20.6,22,35,46}) do
 for _,z in ipairs({-44,-35,-31.7,-24.1,-23.9,-16,-7.1,-6.9,0,6.8,12,25.1,35,44.9,48.1,58,126.1}) do
  local hit=floor(x,z)
  table.insert(samples,{x=x,z=z,part=hit.Instance,y=hit.Position.Y})
 end
end
local function verify()
 assert(game.RunService:IsEdit())
 for i,part in ipairs(parts) do
  local texture=textures[i]
  assert(part.Color==after and texture.Parent==part and sameFinish(texture) and aligned(part,texture))
 end
 for _,texture in ipairs(existing) do assert(sameFinish(texture) and aligned(texture.Parent,texture)) end
 for _,sample in ipairs(samples) do
  local hit=floor(sample.x,sample.z)
  assert(hit.Instance==sample.part and math.abs(hit.Position.Y-sample.y)<.001,'Walking surface changed')
 end
 return {placeId=game.PlaceId,universeId=game.GameId,textures=#textures,phaseAdjustments=#existing,floorSamples=#samples,tile=8}
end
local function apply()
 assert(game.RunService:IsEdit())
 for i,part in ipairs(parts) do assert(part.Color==colors[i] and not part:FindFirstChildOfClass('Texture')) end
 for _,texture in ipairs(existing) do assert(texture.OffsetStudsU==0 and texture.OffsetStudsV==0) end
 for i,part in ipairs(parts) do part.Color=after;textures[i].Parent=part end
 for _,texture in ipairs(existing) do texture.OffsetStudsU,texture.OffsetStudsV=offsets(texture.Parent) end
 local ok,proof=pcall(verify)
 if not ok then
  for i,part in ipairs(parts) do part.Color=colors[i];textures[i].Parent=nil end
  for _,texture in ipairs(existing) do texture.OffsetStudsU=0;texture.OffsetStudsV=0 end
  error(proof)
 end
 return proof
end
local encoding=game:GetService('EncodingService')
local binary=game:GetService('SerializationService'):SerializeInstancesAsync(textures)
local scenery=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)))
shared.DepotChecker={scenery=scenery,apply=apply,verify=verify}
return {staged=#textures,exportBytes=#scenery}
