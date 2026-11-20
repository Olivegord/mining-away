-- Prepend the ResourcePlacement and CrystalCuts bundles before staging in Edit.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning())
local run=workspace.MiningAway.Map.CrystalRun
assert(not run:FindFirstChild('SeamOutcrops') and not shared.CrystalOutcrops)
local root=Instance.new('Folder');root.Name='SeamOutcrops'
local profiles={
 {name='Amber Fault',color={104,91,81},pieces={
  {'Oblique',-5,-.5,16,39,10,-13,-9,0}, {'Spear',8,.5,12,27,12,15,11,-7},
  {'Crown',-14,1,10,15,9,8,7,-9}, {'Spear',13,-3,11,15,8,-9,16,4},
  {'Oblique',1,2.7,14,12,8,17,-5,8},
 }},
 {name='Quartz Shoulder',color={95,106,113},pieces={
  {'Spear',1,-1,14,45,10,-13,-11,0}, {'Oblique',-10,-1,13,34,11,13,-12,-7},
  {'Crown',10,1,14,23,13,7,7,4}, {'Spear',15,-3,8,15,7,18,9,-8},
  {'Oblique',-14,4,11,13,8,-15,-11,5},
 }},
 {name='Violet Split',color={100,91,112},pieces={
  {'Oblique',-8,-1,14,35,10,14,-11,1}, {'Spear',5,0,16,41,11,-8,8,-7},
  {'Crown',14,-1,11,22,12,7,9,3}, {'Spear',-13,-3,11,16,8,-7,-9,-5},
  {'Oblique',0,4,14,12,8,10,8,8},
 }},
 {name='Diamond Teeth',color={107,105,115},pieces={
  {'Oblique',2,-1,15,47,10,10,8,-4}, {'Spear',-9,0,12,33,13,-12,-11,5},
  {'Spear',12,1,10,28,11,12,12,-8}, {'Crown',-15.5,-1,9,14,12,13,-15,2},
  {'Oblique',9,4,13,15,8,-10,9,7},
 }},
}
local beds={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local templates={}
for _,name in ipairs({'Oblique','Spear','Crown'}) do
 templates[name]=assert(CrystalCuts.build(name))
 task.wait()
end
local function extent(frame,size,axis)
 return (math.abs(frame.RightVector[axis])*size.X+math.abs(frame.UpVector[axis])*size.Y+math.abs(frame.LookVector[axis])*size.Z)*.5
end
local function verify()
 local pieces,tallest=0,0
 for i,profile in ipairs(profiles) do
  local before,after=run[beds[i]].Field,run[beds[i+1]].Field
  assert(before.Size.X==216 and before.Size.Z==64 and after.Position.X==before.Position.X)
  local seam=(before.Position+after.Position)*.5
  assert(math.abs(seam.Z-before.Position.Z-before.Size.Z*.5)<.01)
  local ridge=ResourcePlacement.seamOutcrops[i]
  local floor=before.Position.Y+before.Size.Y*.5
  local center=Vector3.new(seam.X+ridge.x,floor,seam.Z)
  local model=assert(root:FindFirstChild(profile.name))
  assert(#model:GetChildren()==#profile.pieces)
  for _,part in ipairs(model:GetChildren()) do
   local position,size,frame=part.Position,part.Size,part.CFrame
   assert(part.Anchored and part.CanCollide and part.CanQuery and not part:GetAttribute('ResourceId'))
   assert(math.abs(position.X-center.X)+extent(frame,size,'X')<=ridge.halfX,part.Name..' exceeds its seam width')
   assert(math.abs(position.Z-center.Z)+extent(frame,size,'Z')<=ridge.halfZ,part.Name..' exceeds its seam depth')
   assert(position.Y-extent(frame,size,'Y')<floor and position.Y>floor)
   tallest=math.max(tallest,position.Y+extent(frame,size,'Y')-floor)
   pieces+=1
  end
 end
 return {groups=#profiles,parts=pieces,maxHeight=math.round(tallest*10)/10}
end
local function verifyCrossings()
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={root}
 local checked=0
 for zone,name in ipairs(beds) do
  local field=run[name].Field
  local layout=ResourcePlacement.crystalLayout(field.Size.X,field.Size.Z,zone)
  for _,segment in ipairs(layout.paths) do
   local length=math.sqrt(segment.lengthSquared)
   local divisions=math.ceil(length/3)
   for step=0,divisions do
    local t=step/divisions
    for _,offset in ipairs({-2,0,2}) do
     local x=segment.x+t*segment.dx-offset*segment.dz/length
     local z=segment.z+t*segment.dz+offset*segment.dx/length
     local at=field.CFrame:PointToWorldSpace(Vector3.new(x,0,z))
     assert(not workspace:Raycast(at+Vector3.yAxis*52,Vector3.new(0,-51.6,0),ray),name..' crossing is obstructed')
     checked+=1
    end
   end
  end
 end
 return checked
end
for i,profile in ipairs(profiles) do
 local before,after=run[beds[i]].Field,run[beds[i+1]].Field
 local ridge=ResourcePlacement.seamOutcrops[i]
 local center=Vector3.new(before.Position.X+ridge.x,before.Position.Y+before.Size.Y*.5,(before.Position.Z+after.Position.Z)*.5)
 local model=Instance.new('Model');model.Name=profile.name;model.Parent=root
 for index,spec in ipairs(profile.pieces) do
  local cut,x,z,width,height,depth,yaw,lean,bias=table.unpack(spec)
  local part=templates[cut]:Clone()
  part.Name=cut..' '..index
  part.Size=Vector3.new(width,height,depth)
  local rotation=CFrame.Angles(0,math.rad(yaw),0)*CFrame.Angles(0,0,math.rad(lean))
  local support=extent(rotation,part.Size,'Y')
  part.CFrame=CFrame.new(center+Vector3.new(x,support-math.min(3.2,height*.18),z))*rotation
  local r,g,b=table.unpack(profile.color)
  part.Color=Color3.fromRGB(r+bias,g+bias,b+bias)
  part.Material=Enum.Material.Slate
  part.CanCollide=true;part.CanQuery=true;part.CanTouch=false
  part.Parent=model
 end
end
for _,template in pairs(templates) do template:Destroy() end
local report=verify()
local serializer,encoding=game:GetService('SerializationService'),game:GetService('EncodingService')
local binary=serializer:SerializeInstancesAsync({root})
local compressed=encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)
local export=buffer.tostring(encoding:Base64Encode(compressed))
shared.CrystalOutcrops={scenery=export,apply=function()
 assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and not game:GetService('RunService'):IsRunning())
 assert(not run:FindFirstChild(root.Name))
 local receipt=verify()
 root.Parent=run
 local ok,result=pcall(verifyCrossings)
 if not ok then root.Parent=nil;error(result) end
 receipt.crossingSamples=result
 return receipt
end}
return {report=report,bytes=#export}
