assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit(),
 'Use shared DRONEREVOLUTION in Edit')
assert(not shared.MiningAwayLook,'A transfer is already staged')
local plan=game.HttpService:JSONDecode([==[PLAN_JSON]==])
local lighting,storage=game.Lighting,game.ServerStorage
local root=workspace.MiningAway
local map=root.Map
local archive=Instance.new('Folder');archive.Name='PreMiningAwayLook'
local ser,enc=game:GetService('SerializationService'),game:GetService('EncodingService')
local function import(data)
 return ser:DeserializeInstancesAsync(enc:DecompressBuffer(enc:Base64Decode(buffer.fromstring(data)),Enum.CompressionAlgorithm.Zstd))
end
local function export(list)
 return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(ser:SerializeInstancesAsync(list),Enum.CompressionAlgorithm.Zstd,3)))
end
local function lookup(path)
 local items={game}
 for name in string.gmatch(path,'[^.]+') do
  local nextItems={}
  for _,p in items do
   for _,c in p:GetChildren() do if c.Name==name then table.insert(nextItems,c) end end
  end
  items=nextItems
 end
 return items
end
local function find(path)
 local list=lookup(path);assert(#list==1,path..' is missing or ambiguous');return list[1]
end
local function rgb(a)
 return Color3.fromRGB(a[1],a[2],a[3])
end
local function material(n)
 for _,e in Enum.Material:GetEnumItems() do if e.Value==n then return e end end
 error('Unknown material '..tostring(n))
end
local function close(a,b)
 if typeof(a)=='Color3' then return math.abs(a.R-b.R)<.004 and math.abs(a.G-b.G)<.004 and math.abs(a.B-b.B)<.004 end
 if typeof(a)=='number' then return math.abs(a-b)<.002 end
 return a==b
end
local edits,moves,lights={}, {}, {}
for _,e in plan.finish do
 local candidates={}
 for _,p in lookup(e.path) do
  if p.ClassName==e.cls and (p.Position-Vector3.new(unpack(e.pos))).Magnitude<.003
   and (p.Size-Vector3.new(unpack(e.size))).Magnitude<.003
   and close(p.Color,rgb(e.before[1])) and p.MaterialVariant==e.before[2]
   and p.Material.Value==e.before[3] and close(p.Reflectance,e.before[4]) then
   table.insert(candidates,p)
  end
 end
 assert(#candidates==1,'Canonical finish mismatch: '..e.path..' '..tostring(#candidates))
 local p=candidates[1]
 table.insert(edits,{part=p,before={p.Color,p.MaterialVariant,p.Material,p.Reflectance},
  after={rgb(e.after[1]),e.after[2],material(e.after[3]),e.after[4]}})
end
for _,path in plan.moves do
 local node=find(path)
 for _,o in node:GetDescendants() do
  assert(not o:IsA('ProximityPrompt') and not o:IsA('LuaSourceContainer') and not o:GetAttribute('Interaction'),
   'Keep the active object: '..o:GetFullName())
 end
 table.insert(moves,{object=node,parent=node.Parent,count=#node:GetDescendants()})
end
for _,e in plan.lighting do
 local before=lighting[e.prop]
 local check=type(e.before)=='table' and Color3.new(unpack(e.before)) or e.before
 local after=type(e.after)=='table' and Color3.new(unpack(e.after)) or e.after
 assert(close(before,check),'Canonical lighting mismatch: '..e.prop)
 table.insert(lights,{key=e.prop,before=before,after=after})
end
assert(lighting.LightingStyle==Enum.LightingStyle.Realistic)
local ground=import(plan.reference.ground)[1]
local plate=ground.Baseplate
plate.CFrame+=Vector3.new(0,3.8,0)
-- Keep the exact grove and its bare slabs together. Shift them past the
-- service deck, between the two low fields and clear of mining and paths.
for _,o in ground.OriginalGrove:GetChildren() do
 o:PivotTo(o:GetPivot()+Vector3.new(-40,3.8,94))
end
local hub=find('Workspace.MiningAway.Map.SimpleFlatTestMap.HubPad')
local checker=plate.Texture:Clone();checker.Name='MiningAwayChecker'
local fx=import(plan.reference.fx)
local crystal=import(plan.reference.crystal.data)[1]
assert(crystal:IsA('UnionOperation') and #crystal:GetDescendants()==0)
assert(#ground.OriginalGrove:GetChildren()==12,'Unexpected original grove inventory')
local fields={}
for _,m in root.Fields:GetChildren() do
 local p=m.Field;fields[p]={p.CFrame,p.Size}
end
local samples={}
local function checkSurface(part,grid)
 for x=0,grid do for z=0,grid do
  local point=part.CFrame:PointToWorldSpace(Vector3.new((x/grid-.5)*part.Size.X*.92,part.Size.Y*.5,(z/grid-.5)*part.Size.Z*.92))
  table.insert(samples,{point=point,part=part})
 end end
end
for part in fields do checkSurface(part,6) end
for _,part in map.DronerevolutionTerraces.WalkableRoutes:GetChildren() do
 if part:IsA('BasePart') and not part.Name:find('Curb') then checkSurface(part,8) end
end
checkSurface(hub,6)
checkSurface(map.DronerevolutionTerraces.LogisticsApron.ServiceDeck,6)
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances={root}
for _,row in samples do
 local hit=workspace:Raycast(row.point+Vector3.yAxis*3,Vector3.yAxis*-7,ray)
 row.height=hit and hit.Position.Y
end
local function put(part,a)
 part.Material=a[3];part.MaterialVariant=a[2];part.Color=a[1];part.Reflectance=a[4]
end
local function verify()
 local lowered,obstructed=0,0
 for _,row in samples do
  local hit=workspace:Raycast(row.point+Vector3.yAxis*3,Vector3.yAxis*-7,ray)
  assert(hit and hit.Position.Y>=row.point.Y-.075,'Lost support on '..row.part:GetFullName())
  if row.height and hit.Position.Y<row.height-.15 then lowered+=1 end
  if hit.Position.Y>row.point.Y+.25 then obstructed+=1 end
 end
 for p,b in fields do assert(p.CFrame==b[1] and p.Size==b[2]) end
 for _,e in edits do local a=e.after
  assert(close(e.part.Color,a[1]) and e.part.MaterialVariant==a[2] and e.part.Material==a[3] and close(e.part.Reflectance,a[4]))
 end
 for _,e in lights do assert(close(lighting[e.key],e.after),e.key) end
 assert(#archive.JunkCubeAreas:GetDescendants()==125)
 assert(not map:FindFirstChild('ReserveIsland') and map.MiningAwayReferenceGround==ground)
 for _,m in moves do assert(m.object.Parent==archive and #m.object:GetDescendants()==m.count) end
 assert(checker.Parent==hub and crystal.Parent==storage and ground.Baseplate.Texture.Texture=='rbxassetid://6372755229')
 return {place=game.PlaceId,universe=game.GameId,version=game.PlaceVersion,fields=6,finish=#edits,
  supportSamples=#samples,loweredDecorations=lowered,pointsWithOverlays=obstructed,groveChildren=#ground.OriginalGrove:GetChildren(),
  archiveBranches=#moves,displayParts=#archive.JunkCubeAreas:GetDescendants()}
end
local function rollback()
 for _,o in fx do o.Parent=nil end
 ground.Parent=nil;checker.Parent=nil;crystal.Parent=nil
 for _,e in edits do put(e.part,e.before) end
 for _,e in lights do lighting[e.key]=e.before end
 for _,e in moves do e.object.Parent=e.parent end
 archive.Parent=nil
end
local function apply()
 assert(game.RunService:IsEdit() and not archive.Parent)
 for _,m in moves do assert(m.object.Parent==m.parent and #m.object:GetDescendants()==m.count,'New scenery edits detected') end
 for _,e in edits do local p,a=e.part,e.before
  assert(p.Parent and close(p.Color,a[1]) and p.MaterialVariant==a[2] and p.Material==a[3] and close(p.Reflectance,a[4]),
   'New surface edits detected')
 end
 local ok,answer=pcall(function()
  archive.Parent=storage
  for i,e in moves do e.object.Parent=archive;if i%4==0 then task.wait() end end
  for _,e in edits do put(e.part,e.after) end
  for _,e in lights do lighting[e.key]=e.after end
  for _,o in fx do o.Parent=lighting end
  ground.Parent=map;checker.Parent=hub;crystal.Parent=storage
  return verify()
 end)
 if not ok then rollback();error(answer) end
 return answer
end
shared.MiningAwayLook={apply=apply,verify=verify,rollback=rollback,exports={
 archive=export({archive}),ground=export({ground}),hub=export({checker}),fx=plan.reference.fx,crystal=plan.reference.crystal.data}}
return {finishedParts=#edits,moves=#moves,probes=#samples,groundChildren=#ground.OriginalGrove:GetChildren()}
