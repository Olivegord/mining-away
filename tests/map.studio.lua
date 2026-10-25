-- Execute on a real Studio SERVER after Play. Tests the actual assembled solids,
-- not the Lua API double. Keep the return value as evidence; no place is saved.
local root=assert(workspace:FindFirstChild('MiningAway'),'Start Mining Away first')
local parts={}
for _,p in ipairs(root:GetDescendants()) do
 if p:IsA('BasePart') and p.CanCollide then table.insert(parts,p) end
end
local base=workspace:FindFirstChild('Baseplate');if base then table.insert(parts,base) end
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=parts
local issues={};local samples=0;local routeCount=0
for _,route in ipairs(root.Map.WindingRoutes:GetChildren()) do
 routeCount+=1
 for _,trail in ipairs(route:GetChildren()) do
  local a,b=trail:GetAttribute('RouteStart'),trail:GetAttribute('RouteEnd')
  if a and b then
   local side=Vector3.new(-(b-a).Z,0,(b-a).X).Unit
   local steps=math.ceil((b-a).Magnitude/1.5)
   for n=0,steps do for _,offset in ipairs({-.25,0,.25}) do
    samples+=1;local p=a:Lerp(b,n/steps)+side*trail:GetAttribute('RouteWidth')*offset
    local hit=workspace:Raycast(p+Vector3.new(0,6,0),Vector3.new(0,-7,0),params)
    if not hit or math.abs(hit.Position.Y-p.Y)>.8 then
     table.insert(issues,{route=route.Name,position=tostring(p),offset=offset,floor=hit and hit.Position.Y or 'none',part=hit and hit.Instance:GetFullName() or 'none'})
    end
   end end
  end
 end
end
return game:GetService('HttpService'):JSONEncode({kind='real Studio collision ray probes, not humanoid or multiplayer playtest',samples=samples,routes=routeCount,issues=issues})
