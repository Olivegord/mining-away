assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit(),
 'Use shared DRONEREVOLUTION in Edit')
assert(not shared.StarterPatch,'A starter patch edit is already staged')
local plan=game.HttpService:JSONDecode([==[PLAN_JSON]==])
local function lookup(path)
 local objects={game}
 for name in string.gmatch(path,'[^.]+') do
  local nextObjects={}
  for _,object in objects do
   for _,child in object:GetChildren() do
    if child.Name==name then table.insert(nextObjects,child) end
   end
  end
  objects=nextObjects
 end
 return objects
end
local function resolve(path,position,size)
 local matches={}
 for _,o in lookup(path) do
  if not position or ((o.Position-Vector3.new(unpack(position))).Magnitude<.003
   and (o.Size-Vector3.new(unpack(size))).Magnitude<.003) then table.insert(matches,o) end
 end
 assert(#matches==1,'Missing or ambiguous object: '..path)
 return matches[1]
end
local function rgb(a) return Color3.fromRGB(unpack(a)) end
local field=resolve(plan.field.path,plan.field.before.position,plan.field.before.size)
local archive=resolve(plan.archive)
local plate=resolve(plan.plate)
local old=plan.field.before
local original={frame=field.CFrame,size=field.Size,color=field.Color,transparency=field.Transparency}
assert(math.abs(field.Color.R-rgb(old.color).R)<.004 and math.abs(field.Color.G-rgb(old.color).G)<.004
 and math.abs(field.Color.B-rgb(old.color).B)<.004 and math.abs(field.Transparency-plan.transparency.before)<.001)
assert(math.abs(plate.Position.Y+plate.Size.Y*.5-plan.floor)<.002)
assert(field.CanCollide and field.CanQuery and field.Material==Enum.Material.Plastic)
assert(field.CFrame.Rotation==CFrame.identity)
local moves={}
for _,row in plan.moves do
 local o=resolve(row.path,row.position,row.size)
 assert(o.ClassName==row.cls)
 for _,v in {o,table.unpack(o:GetDescendants())} do
  assert(not v:IsA('LuaSourceContainer') and not v:IsA('ProximityPrompt') and not v:GetAttribute('Interaction'),
   'Cannot hide a functional object: '..v:GetFullName())
 end
 table.insert(moves,{node=o,original=o.Parent,count=#o:GetDescendants()})
end
local function verify()
 assert(game.RunService:IsEdit())
 assert(field.Size==Vector3.new(30,2,30) and field.CanQuery and field.CanCollide)
 assert((field.Position-Vector3.new(unpack(plan.field.after.position))).Magnitude<.002)
 assert(math.abs(field.Transparency-.8)<.002 and field.Color==rgb(plan.field.after.color))
 for _,row in moves do assert(row.node.Parent==archive and #row.node:GetDescendants()==row.count) end
 local baseHits,fieldHits=0,0
 for x=-32,32,2 do
  for z=-32,32,2 do
   local start=Vector3.new(field.Position.X+x,plan.floor+18,field.Position.Z+z)
   local hit=workspace:Raycast(start,Vector3.yAxis*-25)
   local expected=(math.abs(x)<15 and math.abs(z)<15) and field or plate
   assert(hit and hit.Instance==expected,('Unexpected ground at %d,%d: %s'):format(x,z,hit and hit.Instance:GetFullName() or 'no ground'))
   if expected==field then fieldHits+=1 else baseHits+=1 end
  end
 end
 return {place=game.PlaceId,universe=game.GameId,version=game.PlaceVersion,size={field.Size.X,field.Size.Y,field.Size.Z},
  transparency=field.Transparency,fieldHits=fieldHits,baseplateHits=baseHits,probes=fieldHits+baseHits,archived=#moves}
end
local function rollback()
 field.CFrame=original.frame;field.Size=original.size;field.Color=original.color;field.Transparency=original.transparency
 for _,row in moves do row.node.Parent=row.original end
end
local function apply()
 assert(game.RunService:IsEdit() and field.CFrame==original.frame and field.Size==original.size
  and field.Color==original.color and field.Transparency==original.transparency)
 for _,row in moves do
  assert(row.node.Parent==row.original and #row.node:GetDescendants()==row.count,'New map edits detected')
 end
 local ok,value=pcall(function()
  for _,row in moves do row.node.Parent=archive end
  field.Size=Vector3.new(unpack(plan.field.after.size));field.CFrame=CFrame.new(unpack(plan.field.after.position))
  field.Color=rgb(plan.field.after.color);field.Transparency=plan.transparency.after
  return verify()
 end)
 if not ok then rollback();error(value) end
 return value
end
shared.StarterPatch={apply=apply,verify=verify,rollback=rollback}
return #moves
