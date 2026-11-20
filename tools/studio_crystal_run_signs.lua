-- Mount the existing field signs where they can be read from the center route.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local run=workspace.MiningAway.Map.CrystalRun
assert(not run:FindFirstChild('ZoneSignPosts') and not shared.CrystalRunSigns)
local mount=Instance.new('Folder');mount.Name='ZoneSignPosts'
local template=run.DepotWayfinder.WestPost
local zones={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local ray=RaycastParams.new();ray.RespectCanCollide=true
local signs={}
local floorY=4.04
local function floorAt(field,x,z)
 local hit=workspace:Raycast(Vector3.new(x,12,z),Vector3.new(0,-10,0),ray)
 assert(hit and hit.Instance==field and math.abs(hit.Position.Y-floorY)<.01,'Sign needs the existing field floor')
end
local function fitsBetweenPlots(zone,position)
 for _,plot in ipairs(zone:GetChildren()) do
  if plot:GetAttribute('CrystalCluster') then
   local gap=math.max(math.abs(plot.Position.X-position.X)-plot.Size.X*.5-8,math.abs(plot.Position.Z-position.Z)-plot.Size.Z*.5-.11)
   assert(gap>=3.5,'Sign crowds a mining plot')
  end
 end
end
for i,name in ipairs(zones) do
 local zone=run[name]
 local board=zone.ZoneSign
 local start=126+(i-1)*64
 local z=start+(i==1 and 2 or 4)
 local position=Vector3.new(-16,6.59,z)
 assert((board.Position-Vector3.new(-58,5.1,start+5)).Magnitude<.002 and board.Size==Vector3.new(16,2.6,.22))
 assert(board.Anchored and not board.CanCollide and not board.CanQuery and not board.CanTouch)
 assert(board.CFrame.LookVector==Vector3.new(0,0,-1) and #board:GetChildren()==2)
 fitsBetweenPlots(zone,position)
 local posts={}
 for _,side in ipairs({-1,1}) do
  local post=template:Clone()
  post.Name=name..(side<0 and 'WestPost' or 'EastPost')
  post.Position=Vector3.new(position.X+side*6.1,floorY+.86,z+.18)
  floorAt(zone.Field,post.Position.X,post.Position.Z)
  post.Parent=mount;table.insert(posts,post)
 end
 table.insert(signs,{board=board,zone=zone,old=board.CFrame,new=CFrame.new(position)*board.CFrame.Rotation,posts=posts})
end

local function verify()
 assert(game.RunService:IsEdit() and mount.Parent==run)
 local checked,clear,maxAngle=0,0,0
 for _,entry in ipairs(signs) do
  local board,zone=entry.board,entry.zone
  assert(board.CFrame==entry.new)
  assert(board.Position.X+board.Size.X*.5<=-7)
  fitsBetweenPlots(zone,board.Position)
  for _,post in ipairs(entry.posts) do
   assert(post.Parent==mount and post.Anchored and not post.CanCollide and not post.CanQuery and not post.CanTouch)
   floorAt(zone.Field,post.Position.X,post.Position.Z)
   local base=post.Position.Y-post.Size.Y*.5
   local boardBottom=board.Position.Y-board.Size.Y*.5
   assert(math.abs(base-floorY)<.02 and post.Position.Y+post.Size.Y*.5-boardBottom>.4)
   checked+=1
  end
  for _,x in ipairs({-4,0,4}) do
   for _,distance in ipairs({28,36,44}) do
    local eye=Vector3.new(x,8.5,board.Position.Z-distance)
    local delta=board.Position-eye
    local angle=math.deg(math.atan2(math.abs(delta.X),delta.Z))
    assert(angle<36 and not workspace:Raycast(eye,delta,ray),'Sign hidden from the approach')
    maxAngle=math.max(maxAngle,angle);clear+=1
   end
  end
 end
 for _,x in ipairs({-6,0,6}) do
  assert(not workspace:Raycast(Vector3.new(x,4.35,127),Vector3.new(0,0,318),ray),'Center walking lane is obstructed')
 end
 return {placeId=game.PlaceId,universeId=game.GameId,signs=#signs,posts=checked,sightlines=clear,maxAngle=maxAngle}
end

local function apply()
 assert(game.RunService:IsEdit() and not mount.Parent and not run:FindFirstChild(mount.Name))
 for _,entry in ipairs(signs) do assert(entry.board.CFrame==entry.old) end
 mount.Parent=run
 for _,entry in ipairs(signs) do entry.board.CFrame=entry.new end
 local ok,result=pcall(verify)
 if not ok then
  for _,entry in ipairs(signs) do entry.board.CFrame=entry.old end
  mount.Parent=nil
  error(result)
 end
 return result
end
local binary=game:GetService('SerializationService'):SerializeInstancesAsync({mount})
local encoding=game:GetService('EncodingService')
local compressed=encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)
local scenery=buffer.tostring(encoding:Base64Encode(compressed))
shared.CrystalRunSigns={scenery=scenery,apply=apply,verify=verify}
return scenery
