-- Bring the original checker to the authored route between the depot and Quartz.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local root=workspace.MiningAway
assert(root:GetAttribute('DronerevolutionMapVersion') and root:GetAttribute('QuarrySceneryAuthored'))
local map=root.Map
local apron=map.DronerevolutionTerraces.LogisticsApron
local deck=apron.ServiceDeck
local market=map.DronerevolutionTerraces.MarketSquare
local fill=map.PlatformSurfaceFill
local reference=map.MiningAwayReferenceGround.Baseplate.Texture
local before=Color3.fromRGB(163,162,165)
local after=Color3.fromRGB(109,106,105)
local parts={deck,market.UtilityWalk,fill.DronerevolutionTerraces_MarketSquare_UtilityWalk_2,fill.DronerevolutionTerraces_MarketSquare_UtilityWalk_3}
assert(apron.Earth.Color==after and not shared.ServiceDeckFinish and not deck:FindFirstChild('MiningAwayChecker'))
assert(reference:IsA('Texture') and reference.Face==Enum.NormalId.Top and reference.StudsPerTileU==8 and reference.StudsPerTileV==8)
for _,part in ipairs(parts) do
 assert(part:IsA('Part') and part.Color==before and part.Material==Enum.Material.Plastic and part.MaterialVariant=='' and part.Reflectance==0)
end
local checker=reference:Clone();checker.Name='MiningAwayChecker'
local params=RaycastParams.new();params.RespectCanCollide=true
local samples={}
for _,x in ipairs({-31,-25,-14,-6,0,6,14,25,31}) do
 for _,z in ipairs({30,42,48.2,51,67,86,105,119,125.8,126.2,129}) do
  local point=Vector3.new(x,11,z)
  local hit=workspace:Raycast(point,Vector3.new(0,-10,0),params)
  assert(hit and hit.Position.Y>=3.8 and hit.Position.Y<8)
  table.insert(samples,{point=point,part=hit.Instance,y=hit.Position.Y})
 end
end

local function verify()
 assert(game.RunService:IsEdit() and checker.Parent==deck)
 assert(checker.Texture==reference.Texture and checker.Face==reference.Face and checker.Transparency==reference.Transparency)
 assert(checker.StudsPerTileU==reference.StudsPerTileU and checker.StudsPerTileV==reference.StudsPerTileV and checker.Color3==reference.Color3)
 for _,part in ipairs(parts) do
  assert(part.Color==after and part.Material==Enum.Material.Plastic and part.Reflectance==0)
 end
 for _,sample in ipairs(samples) do
  local hit=workspace:Raycast(sample.point,Vector3.new(0,-10,0),params)
  assert(hit and hit.Instance==sample.part and math.abs(hit.Position.Y-sample.y)<.001,'Route geometry changed')
 end
 return {placeId=game.PlaceId,universeId=game.GameId,tinted=#parts,floorSamples=#samples,tile=8}
end

local function apply()
 assert(game.RunService:IsEdit() and not checker.Parent and not deck:FindFirstChild(checker.Name))
 for _,part in ipairs(parts) do assert(part.Color==before) end
 checker.Parent=deck
 for _,part in ipairs(parts) do part.Color=after end
 local ok,result=pcall(verify)
 if not ok then
  for _,part in ipairs(parts) do part.Color=before end
  checker.Parent=nil
  error(result)
 end
 return result
end
local binary=game:GetService('SerializationService'):SerializeInstancesAsync({checker})
local encoding=game:GetService('EncodingService')
local scenery=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)))
shared.ServiceDeckFinish={scenery=scenery,apply=apply,verify=verify}
return scenery
