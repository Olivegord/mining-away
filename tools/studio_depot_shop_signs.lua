-- Mount the two active shop boards using the existing depot post.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local root=workspace.MiningAway
local map=root.Map
local template=map.CrystalRun.DepotWayfinder.WestPost
local apron=map.DronerevolutionTerraces.MarketSquare.ShopApron
assert(not map:FindFirstChild('ShopSignPosts') and not shared.DepotShopSigns)
local folder=Instance.new('Folder');folder.Name='ShopSignPosts'
local ray=RaycastParams.new();ray.RespectCanCollide=true
local font=game:GetService('TextService')
local active={Quartz=-36,Ruby=-18}
local inactive={Cobalt=0,Violet=18,Emerald=36}
local edits={}
local function stage(instance,property,before,after)
 local current=instance[property]
 assert(current==before or (typeof(current)=='Vector3' and (current-before).Magnitude<.001),instance:GetFullName()..'.'..property)
 table.insert(edits,{instance=instance,property=property,before=current,after=after})
end
local function floor(x,z)
 return assert(workspace:Raycast(Vector3.new(x,32,z),Vector3.new(0,-80,0),ray))
end
local samples={}
for _,x in ipairs({-42,-36,-30,-24,-18,-12}) do
 for _,z in ipairs({-42,-36,-32,-26,-18,0,12}) do
  local hit=floor(x,z)
  table.insert(samples,{x=x,z=z,instance=hit.Instance,y=hit.Position.Y})
 end
end
for key,x in pairs(active) do
 local station=map[key..'Shop']
 local board=station.ShopSign
 assert(station:FindFirstChildOfClass('ProximityPrompt').Enabled and board.Anchored and not board.CanQuery)
 stage(board,'Position',Vector3.new(x,16.7,-31.7),Vector3.new(x,7.2,-31.7))
 for _,side in ipairs({'Front','Back'}) do
  local face=board[side]
  assert(face.Enabled and face.ShopName.Text==(key=='Quartz' and 'QUARTZ WORKSHOP' or 'STAR SHOP'))
  local size=font:GetTextSize(face.ShopName.Text,64,face.ShopName.Font,Vector2.new(10000,1000))
  assert(size.X<face.CanvasSize.X*.9 and size.Y<face.CanvasSize.Y)
  stage(face.ShopName,'TextSize',54,64)
 end
 for _,offset in ipairs({-5.3,5.3}) do
  local post=template:Clone();post.Name=key..(offset<0 and 'WestPost' or 'EastPost')
  local hit=floor(x+offset,-31.7)
  assert(hit.Instance==apron and math.abs(hit.Position.Y-4.07)<.01)
  local bottom=hit.Position.Y-.02
  local top=7.2-board.Size.Y*.5+.07
  post.Size=Vector3.new(template.Size.X,top-bottom,template.Size.Z)
  post.Position=Vector3.new(x+offset,(top+bottom)*.5,-31.7)
  post.Parent=folder
 end
end
for key,x in pairs(inactive) do
 local station=map[key..'Shop'];local board=station.ShopSign
 assert(math.abs(board.Position.X-x)<.001 and not station:FindFirstChildOfClass('ProximityPrompt').Enabled)
 stage(board,'Transparency',0,1)
 for _,side in ipairs({'Front','Back'}) do stage(board[side],'Enabled',true,false) end
end
for _,key in ipairs({'Ruby','Cobalt','Violet','Emerald'}) do
 local label=root.Fields[key].Field.TestLabel
 assert(label.Enabled and label:IsA('BillboardGui'))
 stage(label,'MaxDistance',230,72)
end

local function verify()
 assert(game.RunService:IsEdit() and folder.Parent==map)
 for _,edit in ipairs(edits) do assert(edit.instance[edit.property]==edit.after) end
 local views=0
 for key,x in pairs(active) do
  local board=map[key..'Shop'].ShopSign
  for _,from in ipairs({Vector3.new(0,8.5,12),Vector3.new(x,8.5,0),Vector3.new(x,8.5,-16),Vector3.new(x,8.5,-26),Vector3.new(x,8.5,-41)}) do
   for _,offset in ipairs({-4.5,0,4.5}) do
    assert(not workspace:Raycast(from,board.Position+Vector3.xAxis*offset-from,ray),'Shop board obscured from the depot')
    views+=1
   end
  end
  for _,suffix in ipairs({'WestPost','EastPost'}) do
   local post=folder[key..suffix]
   assert(post.Anchored and not post.CanCollide and not post.CanTouch and not post.CanQuery)
   local hit=floor(post.Position.X,post.Position.Z)
   assert(hit.Instance==apron and math.abs(post.Position.Y-post.Size.Y*.5-hit.Position.Y+.02)<.001)
   assert(math.abs(post.Position.Y+post.Size.Y*.5-(board.Position.Y-board.Size.Y*.5)-.07)<.001)
  end
 end
 for _,sample in ipairs(samples) do
  local hit=floor(sample.x,sample.z)
  assert(hit.Instance==sample.instance and math.abs(hit.Position.Y-sample.y)<.001)
 end
 return {placeId=game.PlaceId,universeId=game.GameId,edits=#edits,posts=#folder:GetChildren(),sightlines=views,floorSamples=#samples}
end
local function apply()
 assert(game.RunService:IsEdit() and not folder.Parent and not map:FindFirstChild(folder.Name))
 for _,edit in ipairs(edits) do assert(edit.instance[edit.property]==edit.before,'Edit changed since staging') end
 for _,edit in ipairs(edits) do edit.instance[edit.property]=edit.after end
 folder.Parent=map
 local ok,proof=pcall(verify)
 if not ok then
  folder.Parent=nil
  for _,edit in ipairs(edits) do edit.instance[edit.property]=edit.before end
  error(proof)
 end
 return proof
end
local encoding=game:GetService('EncodingService')
local binary=game:GetService('SerializationService'):SerializeInstancesAsync({folder})
local scenery=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)))
shared.DepotShopSigns={scenery=scenery,apply=apply,verify=verify}
return {staged=#edits,posts=#folder:GetChildren(),exportBytes=#scenery}
