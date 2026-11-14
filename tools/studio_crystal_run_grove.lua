-- Place a few copies of Mining Away's native two-part tree around the route.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
local map=workspace.MiningAway.Map
local run=map.CrystalRun
local original=map.MiningAwayReferenceGround.OriginalGrove
local material=game:GetService('MaterialService')
local bark=material.QuarryFoliage_Bark
local leaves=material.QuarryPalette_LeafClumps
local template
for _,model in ipairs(original:GetChildren()) do
 if model:IsA('Model') and math.abs(model:GetBoundingBox().Position.X+112.51172)<.001 then template=model;break end
end
assert(template and #template:GetChildren()==2 and not run:FindFirstChild('TrailGrove') and not shared.CrystalRunGrove)
local grove=Instance.new('Folder');grove.Name='TrailGrove'
local params=RaycastParams.new();params.RespectCanCollide=true
local function ground(x,z)
 return workspace:Raycast(Vector3.new(x,16,z),Vector3.new(0,-24,0),params)
end
local function extent(part)
 local frame=part.CFrame;local half=part.Size*.5
 return math.abs(frame.RightVector.X)*half.X+math.abs(frame.LookVector.X)*half.Z,
  math.abs(frame.RightVector.Z)*half.X+math.abs(frame.LookVector.Z)*half.Z
end

local sites={
 {name='QuartzEdge',zone='Quartz',x=-28,z=139,scale=.48,yaw=-14,tint=Color3.fromRGB(115,143,76)},
 {name='QuartzSapling',zone='Quartz',x=-41,z=142,scale=.32,yaw=21,tint=Color3.fromRGB(98,128,70)},
 {name='CobaltApproach',zone='Ruby',x=31,z=252,scale=.40,yaw=12,tint=Color3.fromRGB(109,139,78)},
 {name='EmeraldEdge',zone='Emerald',x=-30,z=386,scale=.43,yaw=-9,tint=Color3.fromRGB(110,137,77)},
 {name='EmeraldSapling',zone='Emerald',x=-41,z=389,scale=.30,yaw=28,tint=Color3.fromRGB(98,125,69)},
}
local plots,signs={},{run.TrailSign}
for _,zone in ipairs(run:GetChildren()) do
 if not zone:FindFirstChild('Field') then continue end
 table.insert(signs,zone.ZoneSign)
 for _,part in ipairs(zone:GetChildren()) do
  if part:GetAttribute('CrystalCluster') then table.insert(plots,part) end
 end
end
assert(#plots==15 and #signs==6)

local samples={}
for _,x in ipairs({-8,0,8}) do
 for z=110,446,8 do
  local hit=assert(ground(x,z))
  table.insert(samples,{x=x,z=z,part=hit.Instance,y=hit.Position.Y})
 end
end
for _,site in ipairs(sites) do
 local hit=assert(ground(site.x,site.z))
 assert(hit.Instance==run[site.zone].Field and math.abs(hit.Position.Y-4.04)<.02)
 local tree=template:Clone();tree.Name=site.name;tree:ScaleTo(site.scale)
 local canopy,trunk
 for _,p in ipairs(tree:GetChildren()) do
  assert(p:IsA('Part') and p.Anchored)
  p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
  if p.Size.X>3*site.scale then
   canopy=p;p.Name='Canopy';p.Material=leaves.BaseMaterial;p.MaterialVariant=leaves.Name;p.Color=site.tint
  else
   trunk=p;p.Name='Trunk';p.Material=bark.BaseMaterial;p.MaterialVariant=bark.Name;p.Color=Color3.fromRGB(138,104,73)
  end
 end
 assert(canopy and trunk)
 tree:PivotTo(CFrame.new(site.x,0,site.z)*CFrame.Angles(0,math.rad(site.yaw),0))
 local foot=Vector3.new(trunk.Position.X,trunk.Position.Y-trunk.Size.Y*.5,trunk.Position.Z)
 local offset=hit.Position-foot-Vector3.yAxis*.015
 tree:PivotTo(tree:GetPivot()+offset)
 tree.Parent=grove
end

local function crosses(part,from,to)
 local start=part.CFrame:PointToObjectSpace(from)
 local direction=part.CFrame:VectorToObjectSpace(to-from)
 local half=part.Size*.5
 local first,last=0,1
 for _,axis in ipairs({'X','Y','Z'}) do
  local coordinate,speed,edge=start[axis],direction[axis],half[axis]
  if math.abs(speed)<.00001 then
   if math.abs(coordinate)>edge then return false end
  else
   local a,b=(-edge-coordinate)/speed,(edge-coordinate)/speed
   first,last=math.max(first,math.min(a,b)),math.min(last,math.max(a,b))
   if first>last then return false end
  end
 end
 return true
end
local function verify()
 assert(game.RunService:IsEdit() and #grove:GetChildren()==#sites and #grove:GetDescendants()==3*#sites)
 local clearance,views=0,0
 for _,site in ipairs(sites) do
  local tree=grove[site.name]
  local trunk=tree.Trunk
  local hit=assert(ground(trunk.Position.X,trunk.Position.Z))
  assert(hit.Instance==run[site.zone].Field and math.abs(trunk.Position.Y-trunk.Size.Y*.5-hit.Position.Y)<.02)
  for _,p in ipairs(tree:GetChildren()) do
   assert(p.Anchored and not p.CanQuery and not p.CanTouch and not p.CanCollide)
   local x,z=extent(p)
   assert(math.abs(p.Position.X)-x>19,'The tree crossed into the center lane')
   for _,plot in ipairs(plots) do
    assert(math.abs(p.Position.X-plot.Position.X)>plot.Size.X*.5+x+2
     or math.abs(p.Position.Z-plot.Position.Z)>plot.Size.Z*.5+z+2,'The tree is too close to a crystal plot')
    clearance+=1
   end
   for _,sign in ipairs(signs) do
    for _,direction in ipairs({-1,1}) do
     for _,lane in ipairs({-8,0,8}) do
      local from=Vector3.new(lane,9,sign.Position.Z+direction*20)
      for _,faceX in ipairs({-.4,.4}) do
       local to=sign.Position+sign.CFrame.RightVector*(faceX*sign.Size.X)
       assert(not crosses(p,from,to),'The tree covers a sign from the trail')
       views+=1
      end
     end
    end
   end
  end
 end
 for _,sample in ipairs(samples) do
  local hit=assert(ground(sample.x,sample.z))
  assert(hit.Instance==sample.part and math.abs(hit.Position.Y-sample.y)<.001,'The walking surface changed')
 end
 return {placeId=game.PlaceId,universeId=game.GameId,trees=#sites,parts=2*#sites,floorSamples=#samples,clearance=clearance,signViews=views}
end

local function apply()
 assert(not grove.Parent and not run:FindFirstChild(grove.Name))
 grove.Parent=run
 local ok,proof=pcall(verify)
 if not ok then grove.Parent=nil;error(proof) end
 return proof
end
local proof=verify()
local encoding=game:GetService('EncodingService')
local binary=game:GetService('SerializationService'):SerializeInstancesAsync({grove})
local scenery=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)))
shared.CrystalRunGrove={scenery=scenery,apply=apply,verify=verify}
return proof
