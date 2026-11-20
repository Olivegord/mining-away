-- Stage only the five active mining beds for a checked native mirror.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
assert(not shared.WideCrystalRun)
local run=workspace.MiningAway.Map.CrystalRun
local zones={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local beds,edits={},{}
local shift=Vector3.new(30,0,0)
local function xyz(v) return {v.X,v.Y,v.Z} end
for i,zone in ipairs(zones) do
 local bed=run[zone].Field
 local size,frame=bed.Size,bed.CFrame
 assert(bed:IsA('Part') and bed:GetAttribute('CrystalZone')==i and bed.CanCollide and bed.CanQuery)
 assert(size==Vector3.new(108,.6,64) and frame==CFrame.new(0,3.74,158+(i-1)*64))
 local texture=bed:FindFirstChildOfClass('Texture')
 assert(texture and texture.Face==Enum.NormalId.Top and texture.StudsPerTileU==8 and texture.StudsPerTileV==8)
 -- The left edge changes by -24 studs, a whole number of checker tiles.
 local newSize=Vector3.new(size.X*2,size.Y,size.Z)
 local newFrame=frame+shift
 beds[i]={bed=bed,size=size,frame=frame,newSize=newSize,newFrame=newFrame}
 edits[i]={path=bed:GetFullName(),class='Part',anchor=xyz(frame.Position),anchorSize=xyz(size),
  before={position=xyz(frame.Position),size=xyz(size)},after={position=xyz(newFrame.Position),size=xyz(newSize)}}
end
local function verify()
 assert(game.RunService:IsEdit())
 local params=RaycastParams.new();params.RespectCanCollide=true
 local checked=0
 for _,entry in ipairs(beds) do
  local bed=entry.bed
  assert(bed.Size==entry.newSize and bed.CFrame==entry.newFrame and bed.CanCollide and bed.CanQuery)
  for x=-104,104,8 do for z=-30,30,6 do
   local from=bed.CFrame:PointToWorldSpace(Vector3.new(x,16,z))
   local hit=workspace:Raycast(from,Vector3.new(0,-17,0),params)
   assert(hit and hit.Instance==bed and math.abs(hit.Position.Y-(bed.Position.Y+bed.Size.Y/2))<.005,
    'Blocked bed at '..bed:GetFullName()..' ('..x..', '..z..')')
   checked+=1
  end end
 end
 return {place=game.PlaceId,universe=game.GameId,beds=#beds,width=216,surfaceChecks=checked}
end
local function apply()
 assert(game.RunService:IsEdit())
 for _,entry in ipairs(beds) do
  assert(entry.bed.Size==entry.size and entry.bed.CFrame==entry.frame,'Mining bed changed after staging')
 end
 local ok,result=pcall(function()
  for _,entry in ipairs(beds) do
   entry.bed.Size=entry.newSize;entry.bed.CFrame=entry.newFrame
  end
  return verify()
 end)
 if not ok then
  for _,entry in ipairs(beds) do entry.bed.Size=entry.size;entry.bed.CFrame=entry.frame end
  error(result)
 end
 return result
end
shared.WideCrystalRun={apply=apply,verify=verify,edits=edits}
return game.HttpService:JSONEncode(edits)
