-- Give the Workshop and Star Shop physical counters from the native Pack Counter.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local map=workspace.MiningAway.Map
local source=map.SimpleFlatTestMap.PackStationAssembly
local apron=map.DronerevolutionTerraces.MarketSquare.ShopApron
local tags=game:GetService('CollectionService')
assert(not shared.DepotCounters)
local ray=RaycastParams.new();ray.RespectCanCollide=true
local function ground(x,z)
 return assert(workspace:Raycast(Vector3.new(x,12,z),Vector3.new(0,-16,0),ray))
end
local function copyPart(template,name,position,size,color,parent)
 local part=template:Clone()
 part:ClearAllChildren()
 for key in pairs(part:GetAttributes()) do part:SetAttribute(key,nil) end
 for _,tag in ipairs(tags:GetTags(part)) do tags:RemoveTag(part,tag) end
 part.Name=name;part.Size=size;part.CFrame=CFrame.new(position);part.Color=color
 part.Anchored=true;part.CanCollide=true;part.CanTouch=false;part.CanQuery=true
 part.Parent=parent
 return part
end
local counters={}
local stations={{name='QuartzCounter',station=map.QuartzShop,x=-36},{name='StarCounter',station=map.RubyShop,x=-18}}
for i,site in ipairs(stations) do
 local station=site.station
 local sign=station.ShopSign
 local prompt=assert(station:FindFirstChildOfClass('ProximityPrompt'))
 assert(station.Position==Vector3.new(site.x,5.5,-30) and station.Transparency==1 and not station.CanCollide)
 assert(prompt.Enabled and not prompt.RequiresLineOfSight and prompt.MaxActivationDistance==12 and not station:FindFirstChild(site.name))
 local floor=ground(site.x,-30)
 assert(floor.Instance==apron and math.abs(floor.Position.Y-4.07)<.001)
 local counter=Instance.new('Model');counter.Name=site.name
 local tint=sign.Front.ShopName.TextColor3
 local baseColor=apron.Color:Lerp(sign.Color,.25)
 local topColor=source.PackStationPad.Color:Lerp(tint,.20)
 copyPart(source.PackStation,'Base',Vector3.new(site.x,4.795,-30),Vector3.new(8.4,1.49,4.2),baseColor,counter)
 copyPart(source.PackStationPad,'Top',Vector3.new(site.x,5.655,-30),Vector3.new(9,.25,4.8),topColor,counter)
 counters[i]=counter
end

local samples={}
for _,x in ipairs({-47,-42,-30.5,-27,-23.5,-12,-7,0}) do
 for _,z in ipairs({-41,-34,-32,-30,-27,-24.5,-22,-18,0}) do
  local hit=ground(x,z)
  table.insert(samples,{x=x,z=z,part=hit.Instance,y=hit.Position.Y})
 end
end
local function verify()
 assert(game.RunService:IsEdit())
 local sightlines,promptSpots,topSamples=0,0,0
 for i,site in ipairs(stations) do
  local station,counter=site.station,counters[i]
  local sign,prompt=station.ShopSign,station:FindFirstChildOfClass('ProximityPrompt')
  assert(counter.Parent==station and #counter:GetDescendants()==2)
  local top=counter.Top
  assert(top.Position.Y+top.Size.Y*.5<sign.Position.Y-sign.Size.Y*.5)
  assert(prompt.Enabled and prompt.MaxActivationDistance==12 and not prompt.RequiresLineOfSight)
  for _,spot in ipairs({Vector3.new(site.x,7.07,-25),Vector3.new(site.x,7.07,-35),
   Vector3.new(site.x-6,7.07,-30),Vector3.new(site.x+6,7.07,-30)}) do
   assert((spot-station.Position).Magnitude<prompt.MaxActivationDistance)
   assert(ground(spot.X,spot.Z).Instance==apron)
   promptSpots+=1
  end
  for _,from in ipairs({Vector3.new(0,8.5,12),Vector3.new(site.x,8.5,-16),Vector3.new(site.x,8.5,-41)}) do
   for _,offset in ipairs({-4.5,0,4.5}) do
    assert(not workspace:Raycast(from,sign.Position+Vector3.xAxis*offset-from,ray),'Counter obscured its sign')
    sightlines+=1
   end
  end
  for _,dx in ipairs({-4,0,4}) do
   for _,dz in ipairs({-2,0,2}) do
    local hit=ground(site.x+dx,-30+dz)
    assert(hit.Instance==top and math.abs(hit.Position.Y-5.78)<.001)
    topSamples+=1
   end
  end
 end
 for _,sample in ipairs(samples) do
  local hit=ground(sample.x,sample.z)
  assert(hit.Instance==sample.part and math.abs(hit.Position.Y-sample.y)<.001,'Aisle height changed')
 end
 return {placeId=game.PlaceId,universeId=game.GameId,counters=#counters,aisleSamples=#samples,
  sightlines=sightlines,promptSpots=promptSpots,topSamples=topSamples}
end
local function apply()
 assert(game.RunService:IsEdit())
 for i,site in ipairs(stations) do assert(not counters[i].Parent and not site.station:FindFirstChild(site.name)) end
 for i,site in ipairs(stations) do counters[i].Parent=site.station end
 local ok,proof=pcall(verify)
 if not ok then
  for _,counter in ipairs(counters) do counter.Parent=nil end
  error(proof)
 end
 return proof
end
local encoding=game:GetService('EncodingService')
local binary=game:GetService('SerializationService'):SerializeInstancesAsync(counters)
local scenery=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)))
shared.DepotCounters={scenery=scenery,apply=apply,verify=verify}
return {counters=#counters,exportBytes=#scenery}
