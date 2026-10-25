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
params.FilterDescendantsInstances={workspace.Terrain}
local nativeHits=0;local floorErrors={};local worstMeadow=0
for i,cell in ipairs(plan.grass) do if i%7==0 then
 local hit=workspace:Raycast(Vector3.new(cell.x,cell.y+12,cell.z),Vector3.new(0,-28,0),params)
 if hit then
  nativeHits+=1;local delta=math.abs(hit.Position.Y-cell.y-.25);worstMeadow=math.max(worstMeadow,delta)
  if delta>1.25 then table.insert(floorErrors,{x=cell.x,z=cell.z,expected=cell.y+.25,actual=hit.Position.Y}) end
 else table.insert(floorErrors,{x=cell.x,z=cell.z,missing=true}) end
end end
return game:GetService('HttpService'):JSONEncode({kind='real engine facet and native-meadow inspection',facetSamples=samples,worstFacetHeightError=worst,facetIssues=issues,nativeSamples=nativeHits,worstMeadowHeightError=worstMeadow,meadowIssues=floorErrors,grassCells=workspace.MiningAway:GetAttribute('NativeGrassCells'),dryCells=workspace.MiningAway:GetAttribute('DryMeadowCells'),plannedCells=#plan.grass})
