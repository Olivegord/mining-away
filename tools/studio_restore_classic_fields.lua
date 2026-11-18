-- Restore the original Crystal Run and its floor alongside the smaller squares.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and not game:GetService('RunService'):IsRunning())
local root=workspace.MiningAway
local run=root.Map.CrystalRun
local fields=root.Fields
local archive=game.ServerStorage.FlatFieldsArchive
local oldRun=archive.CrystalRun
local floor=archive.MiningAwayReferenceGround.Baseplate
assert(run:GetAttribute('WholeFields') and not fields:FindFirstChild('CrystalRun'))
assert(floor:IsA('BasePart') and floor.CanCollide)
local moves={
 {oldRun,archive,fields},
 {floor,floor.Parent,fields},
 {oldRun.ChargingStation,oldRun,archive},
 {oldRun.ChargeIndicator,oldRun,archive},
}
local names={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local function list(v) return {v.X,v.Y,v.Z} end
local edits={}
local squareBeds={}
for _,name in ipairs(names) do
 local bed=run[name].Field
 assert(bed.Size.X==46 and bed.Size.Z==46 and oldRun[name].Field.Size.X==216)
 table.insert(squareBeds,bed)
 table.insert(edits,{path=bed:GetFullName(),anchor=list(bed.Position),before={size=list(bed.Size)},
  after={size={32,bed.Size.Y,32}}})
end
local stage={edits=game:GetService('HttpService'):JSONEncode(edits)}
function stage.apply()
 assert(not game:GetService('RunService'):IsRunning() and not fields:FindFirstChild('CrystalRun'))
 for _,move in ipairs(moves) do assert(move[1].Parent==move[2],move[1].Name) end
 for i,bed in ipairs(squareBeds) do assert((bed.Size-Vector3.new(table.unpack(edits[i].before.size))).Magnitude<.001) end
 local ok,result=pcall(function()
  for _,move in ipairs(moves) do move[1].Parent=move[3] end
  for i,bed in ipairs(squareBeds) do bed.Size=Vector3.new(table.unpack(edits[i].after.size)) end
  local filter=RaycastParams.new()
  filter.FilterType=Enum.RaycastFilterType.Include
  filter.FilterDescendantsInstances={run,fields,root.Map.SimpleFlatTestMap}
  local function ground(p) return workspace:Raycast(p+Vector3.yAxis*25,-Vector3.yAxis*60,filter) end
  local gap=math.huge
  for i,name in ipairs(names) do
   local square,classic=squareBeds[i],oldRun[name].Field
   local spawnZ=workspace.SpawnLocation.Position.Z
   assert(square.Position.Z<spawnZ and classic.Position.Z>spawnZ)
   assert(ground(classic.Position).Instance==classic and ground(square.Position).Instance==square)
   for j=1,i-1 do
    local delta=square.Position-squareBeds[j].Position
    gap=math.min(gap,Vector2.new(math.max(0,math.abs(delta.X)-32),math.max(0,math.abs(delta.Z)-32)).Magnitude)
   end
  end
  for z=-280,445,3 do
   local hit=ground(Vector3.new(30,4,z))
   assert(hit and hit.Position.Y>=3.79,'Missing approach floor at '..z)
  end
  return {oldFields=#names,newFields=#squareBeds,width=32,minimumGap=gap,terrainCells=workspace.Terrain:CountCells()}
 end)
 if not ok then
  for i=#moves,1,-1 do local m=moves[i];m[1].Parent=m[2] end
  for i,bed in ipairs(squareBeds) do bed.Size=Vector3.new(table.unpack(edits[i].before.size)) end
  error(result)
 end
 return result
end
shared.RestoreClassicFields=stage
return {staged=true,oldBeds=#names,newBeds=#squareBeds}
