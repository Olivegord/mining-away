-- Execute on the real Studio CLIENT after Play, with exclusive Studio control.
-- Stages the avatar once at each route start, then walks all chords without jumps
-- or further teleports. Poll workspace.MapWalkReview.Report.Value for results.
local onlyRoute=nil -- Set to a route name to rerun an isolated repaired route.
local routes=workspace.MiningAway.Map.WindingRoutes
local player=game.Players.LocalPlayer
local character=assert(player.Character)
local hum=assert(character:FindFirstChildOfClass('Humanoid'))
local root=assert(character:FindFirstChild('HumanoidRootPart'))
assert(hum.Health>0,'Avatar must be alive')
local old=workspace:FindFirstChild('MapWalkReview');if old then old:Destroy() end
local status=Instance.new('Folder');status.Name='MapWalkReview';status.Parent=workspace
local report=Instance.new('StringValue');report.Name='Report';report.Parent=status
status:SetAttribute('State','Walking')
task.spawn(function()
 local results={};local total=0
 for _,route in ipairs(routes:GetChildren()) do
  status:SetAttribute('Route',route.Name)
  local trails={}
  for _,trail in ipairs(route:GetChildren()) do if trail:GetAttribute('RouteStart') then table.insert(trails,trail) end end
  table.sort(trails,function(a,b) return a:GetAttribute('RouteSegment')<b:GetAttribute('RouteSegment') end)
  if #trails>0 and (onlyRoute==nil or route.Name==onlyRoute) then
   character:PivotTo(CFrame.new(trails[1]:GetAttribute('RouteStart')+Vector3.new(0,4,0)))
   task.wait(.4)
   local failed=nil
   for n,trail in ipairs(trails) do
    local goal=trail:GetAttribute('RouteEnd');status:SetAttribute('Segment',n)
    hum:MoveTo(goal+Vector3.new(0,3,0))
    local started=os.clock();local arrived=false
    repeat
     task.wait(.05)
     local p=root.Position
     if Vector3.new(p.X-goal.X,0,p.Z-goal.Z).Magnitude<1.5 and math.abs(p.Y-goal.Y-3)<3 then arrived=true;break end
    until os.clock()-started>5 or hum.Health<=0
    if not arrived then failed={segment=n,goal=tostring(goal),actual=tostring(root.Position)};break end
    total+=1
   end
   table.insert(results,{route=route.Name,segments=#trails,passed=failed==nil,failure=failed})
  end
 end
 hum:MoveTo(root.Position)
 status:SetAttribute('State','Complete')
 report.Value=game:GetService('HttpService'):JSONEncode({kind='single actual Studio avatar; staged route starts, no jumping; not multiplayer',walkedSegments=total,routes=results})
end)
return 'Walking nine routes asynchronously; poll workspace.MapWalkReview.Report.Value'
