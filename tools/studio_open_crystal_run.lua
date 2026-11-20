-- Archive the divider pieces and ground the existing signs outside the beds.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
assert(not shared.OpenCrystalRun and not game.ServerStorage:FindFirstChild('CrystalRunDividers'))
local run=workspace.MiningAway.Map.CrystalRun
local archive=Instance.new('Folder');archive.Name='CrystalRunDividers'
local zones={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local removed,signs={},{}
for i,name in ipairs(zones) do
 local zone=run[name]
 local near=126+(i-1)*64
 local sign=zone.ZoneSign
 assert((sign.Position-Vector3.new(-25,i==1 and 5.84 or 8.54,near-1.3)).Magnitude<.002)
 assert(not sign.CanCollide)
 table.insert(signs,{object=sign,before=sign.CFrame,after=CFrame.new(-58,5.1,near+5)*sign.CFrame.Rotation})
 if i>1 then
  local bin=Instance.new('Folder');bin.Name=name;bin.Parent=archive
  local walls,caps=0,0
  for _,part in ipairs(zone:GetChildren()) do
   if part.Name=='WestWall' or part.Name=='EastWall' or part.Name=='WallCap' then
    assert(part:IsA('Part') and part.Anchored and math.abs(part.Position.Z-near)<.002)
    table.insert(removed,{object=part,parent=zone,dest=bin})
    if part.Name=='WallCap' then caps+=1 else walls+=1 end
   end
  end
  assert(walls==2 and caps==2)
 end
end
assert(run.EndWall.Position.Z==446)
table.insert(removed,{object=run.EndWall,parent=run,dest=archive})

local function verify()
 assert(game.RunService:IsEdit() and archive.Parent==game.ServerStorage)
 for _,entry in ipairs(removed) do assert(entry.object.Parent==entry.dest) end
 for _,entry in ipairs(signs) do assert(entry.object.CFrame==entry.after) end
 local params=RaycastParams.new();params.RespectCanCollide=true
 local through,floor=0,0
 for _,x in ipairs({-49,-36,-18,0,18,36,49}) do
  for _,y in ipairs({4.3,6,10,14}) do
   assert(not workspace:Raycast(Vector3.new(x,y,127),Vector3.new(0,0,321),params),'Crystal Run still blocked')
   through+=1
  end
  for z=127,445,2 do
   local hit=workspace:Raycast(Vector3.new(x,19,z),Vector3.new(0,-16,0),params)
   assert(hit and hit.Instance:IsDescendantOf(run) and hit.Instance.Name=='Field','Crystal Run floor is blocked or missing')
   floor+=1
  end
 end
 return {placeId=game.PlaceId,universeId=game.GameId,wallsRemoved=#removed,signsMoved=#signs,through=through,floor=floor}
end
local function apply()
 assert(game.RunService:IsEdit() and not archive.Parent)
 for _,entry in ipairs(removed) do assert(entry.object.Parent==entry.parent) end
 for _,entry in ipairs(signs) do assert(entry.object.CFrame==entry.before) end
 archive.Parent=game.ServerStorage
 local ok,result=pcall(function()
  for _,entry in ipairs(removed) do entry.object.Parent=entry.dest end
  for _,entry in ipairs(signs) do entry.object.CFrame=entry.after end
  return verify()
 end)
 if not ok then
  for _,entry in ipairs(removed) do entry.object.Parent=entry.parent end
  for _,entry in ipairs(signs) do entry.object.CFrame=entry.before end
  archive.Parent=nil
  error(result)
 end
 return result
end
local raw=game:GetService('SerializationService'):SerializeInstancesAsync({archive})
local enc=game:GetService('EncodingService')
local export=buffer.tostring(enc:Base64Encode(enc:CompressBuffer(raw,Enum.CompressionAlgorithm.Zstd)))
shared.OpenCrystalRun={export=export,apply=apply,verify=verify}
return export
