-- Stage a rigid move of each specimen and check the whole display/flight strip.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning() and not shared.MineralMove)
local row=workspace.MiningAway.Map.MineralLineup
local from=CFrame.new(0,0,-12)
local to=CFrame.new(32,0,-5)*CFrame.Angles(0,math.pi/2,0)
local transform=to*from:Inverse()
local cast=RaycastParams.new();cast.FilterDescendantsInstances={row};cast.RespectCanCollide=true
local bounds=OverlapParams.new();bounds.FilterDescendantsInstances={row}
for _,hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(34,12.15,-5),Vector3.new(13,15.8,45),bounds)) do
 error('Display clearance intersects '..hit:GetFullName())
end
local plan={};local edits={};local floorHeights={}
for _,model in ipairs(row:GetChildren()) do
 local pad=model.DisplayPad
 local position=transform:PointToWorldSpace(pad.Position)
 local floor=-math.huge
 for _,x in ipairs({-2.4,0,2.4}) do
  for _,z in ipairs({-2.4,0,2.4}) do
   local hit=workspace:Raycast(Vector3.new(position.X+x,19,position.Z+z),Vector3.new(0,-30,0),cast)
   assert(hit and hit.Position.Y>=3.99 and hit.Position.Y<=4.1,'unexpected floor elevation')
   floor=math.max(floor,hit.Position.Y)
  end
 end
 floorHeights[model.Name]=floor
 local lift=floor+pad.Size.Y*.5-pad.Position.Y
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA('BasePart') and p.Name~='CoreGeometry' then
   local before=p.CFrame
   local after=transform*before+Vector3.yAxis*lift
   plan[#plan+1]={part=p,before=before,after=after}
   edits[#edits+1]={path=p:GetFullName(),class=p.ClassName,before={before:GetComponents()},after={after:GetComponents()}}
  end
 end
end
assert(#edits==22)
shared.MineralMove={edits=edits,apply=function()
 assert(not game:GetService('RunService'):IsRunning())
 for _,item in ipairs(plan) do assert(item.part:IsDescendantOf(row) and item.part.CFrame==item.before) end
 for _,item in ipairs(plan) do item.part.CFrame=item.after end
 for _,item in ipairs(plan) do assert(item.part.CFrame==item.after) end
 return {moved=#plan,clearance=true,height=floorHeights}
end}
return {moved=#plan,clearance=true,height=floorHeights}
