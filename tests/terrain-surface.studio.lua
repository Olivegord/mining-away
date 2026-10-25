-- Execute on the real Studio server after prepending bundled Config/MapLayout.
local plan=MapLayout.plan(Config.Fields)
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
local ground={}
for _,v in ipairs(workspace.MiningAway.Map.ConnectedCliffs:GetDescendants()) do if v.Name=='GroundFacet' then table.insert(ground,v) end end
params.FilterDescendantsInstances=ground
local issues={};local samples=0;local worst=0
for i,cell in ipairs(plan.terrain) do if i%3==0 then for _,face in ipairs(cell.faces) do
 local x=(face[1][1]+face[2][1]+face[3][1])/3
 local y=(face[1][2]+face[2][2]+face[3][2])/3
 local z=(face[1][3]+face[2][3]+face[3][3])/3
 if y>.1 then
  samples+=1;local hit=workspace:Raycast(Vector3.new(x,y+80,z),Vector3.new(0,-100,0),params)
  local gap=hit and math.abs(hit.Position.Y-y) or 999;worst=math.max(worst,gap)
  if gap>.4 then table.insert(issues,{x=x,z=z,y=y,gap=gap}) end
 end
end end end
local markers=workspace.MiningAway:FindFirstChild('FoliagePatches')
local count=markers and #markers:GetChildren() or 0
return game:GetService('HttpService'):JSONEncode({kind='real engine facet and planting-marker inspection',facetSamples=samples,worstHeightError=worst,issues=issues,nativeGrass=workspace.MiningAway:GetAttribute('NativeGrassPatches'),skinnedGrass=count,plannedGrass=#plan.grass})
