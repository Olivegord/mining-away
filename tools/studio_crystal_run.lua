-- Author the Crystal Run in the existing shared Edit map. Runtime creates the
-- crystals and work effects only. The export contains these new fixtures.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(not game:GetService('RunService'):IsRunning())
local map=workspace.MiningAway.Map
assert(not map:FindFirstChild('CrystalRun'))
local foundation=map.DronerevolutionTerraces.NorthOverlook.Earth
local oldFrame,oldSize=foundation.CFrame,foundation.Size
assert(foundation.Position==Vector3.new(0,12.5,-108) and oldSize==Vector3.new(30,51,30))
local route=Instance.new('Folder')
route.Name='CrystalRun'
local surface=4.04
local function part(parent,name,x,y,z,sx,sy,sz,color,material)
 local object=Instance.new('Part')
 object.Name=name;object.Size=Vector3.new(sx,sy,sz);object.Position=Vector3.new(x,y,z)
 object.Color=Color3.fromRGB(table.unpack(color));object.Material=material or Enum.Material.SmoothPlastic
 object.Anchored=true;object.CanTouch=false
 object.TopSurface=Enum.SurfaceType.Smooth;object.BottomSurface=Enum.SurfaceType.Smooth
 object.Parent=parent
 return object
end
local function sign(anchor,face,title,color)
 local gui=Instance.new('SurfaceGui')
 gui.Name='Sign';gui.Face=face;gui.CanvasSize=Vector2.new(560,126);gui.LightInfluence=.25;gui.Parent=anchor
 local label=Instance.new('TextLabel')
 label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1);label.Font=Enum.Font.GothamBold
 label.Text=title;label.TextColor3=Color3.fromRGB(table.unpack(color));label.TextSize=40;label.Parent=gui
end
local zones={
 {'Quartz',{191,195,193},{249,142,117}},
 {'Ruby',{189,163,165},{255,145,164}},
 {'Cobalt',{151,175,191},{144,212,255}},
 {'Violet',{173,160,189},{214,179,255}},
 {'Emerald',{150,183,170},{152,249,190}},
}
for i,zone in ipairs(zones) do
 local model=Instance.new('Folder')
 model.Name=zone[1];model.Parent=route
 local z=-48-48*(i-1)
 local floor=part(model,'Field',0,surface-.3,z-24,68,.6,48,zone[2],Enum.Material.Concrete)
 floor:SetAttribute('CrystalZone',i)
 if i>1 then
  for _,side in ipairs({-1,1}) do
   part(model,side<0 and 'WestWall' or 'EastWall',side*21,surface+3.6,z,26,7.2,2.4,{49,53,65},Enum.Material.Concrete)
   part(model,'WallCap',side*21,surface+7.3,z,26,.4,2.5,zone[3])
  end
 end
 local board=part(model,'ZoneSign',-21,surface+(i==1 and 2 or 4.4),z+1.3,14,2.6,.25,{34,41,56})
 board.CanCollide=false
 sign(board,Enum.NormalId.Back,string.format('%02d   %s',i,string.upper(zone[1])),zone[3])
end
local endWall=part(route,'EndWall',0,surface+2.5,-288,68,5,2,{49,53,65},Enum.Material.Concrete)
sign(endWall,Enum.NormalId.Back,'CRYSTAL RUN',{152,249,190})
local piers=Instance.new('Folder');piers.Name='OverlookPiers';piers.Parent=route
for _,x in ipairs({-12.5,12.5}) do for _,z in ipairs({-99,-119}) do
 local pier=part(piers,'Pier',x,(surface+25)*.5,z,4,25-surface,5,{109,106,105},foundation.Material)
 pier.Color=foundation.Color
end end
local charger=part(route,'ChargingStation',0,4.4,25,9,.8,6,{44,53,67},Enum.Material.Metal)
local indicator=part(route,'ChargeIndicator',0,4.85,25,7,.12,4,{139,247,148},Enum.Material.Neon)
indicator.CanCollide=false;indicator.CanQuery=false
local board=part(route,'ChargingSign',0,6.8,27.9,9,2,.5,{37,49,63})
board.CanCollide=false
sign(board,Enum.NormalId.Front,'DRONE CHARGE',{159,255,178})
sign(board,Enum.NormalId.Back,'DRONE CHARGE',{159,255,178})
local serialize,encoding=game:GetService('SerializationService'),game:GetService('EncodingService')
local raw=serialize:SerializeInstancesAsync({route})
local export=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(raw,Enum.CompressionAlgorithm.Zstd)))
local function verify()
 assert(route.Parent==map)
 local floorSamples=0
 local params=RaycastParams.new();params.RespectCanCollide=true
 local throughSamples=0
 for _,x in ipairs({-6,-3,0,3,6}) do for _,y in ipairs({4.3,6,8,12,17}) do
  local hit=workspace:Raycast(Vector3.new(x,y,-49),Vector3.new(0,0,-237),params)
  assert(not hit,'Blocked passage at '..x..', '..y..': '..(hit and hit.Instance:GetFullName() or ''))
  throughSamples+=1
 end end
 for z=-50,-286,-2 do
  for x=-5,5,5 do
   local hit=workspace:Raycast(Vector3.new(x,23,z),Vector3.new(0,-22,0))
   assert(hit and hit.Instance:IsDescendantOf(route) and hit.Instance.Name=='Field' and math.abs(hit.Position.Y-surface)<.02,'Blocked walking route at '..x..', '..z)
   floorSamples+=1
  end
 end
 for _,zone in ipairs(zones) do
  local floor=route[zone[1]].Field
  for x=-30,30,10 do for z=-18,18,6 do
   local hit=workspace:Raycast(floor.Position+Vector3.new(x,23,z),Vector3.new(0,-23,0))
   assert(hit and (hit.Instance==floor or hit.Instance:IsDescendantOf(piers)),'Blocked crystal footprint '..zone[1]..' at '..x..', '..z)
  end end
 end
 for z=-96,-240,-48 do
  for _,x in ipairs({-22,22}) do
   local hit=workspace:Raycast(Vector3.new(x,7,z+4),Vector3.new(0,0,-8))
   assert(hit and hit.Instance.CanCollide and hit.Instance:IsDescendantOf(route),'Missing zone wall')
  end
 end
 return {zones=#zones,walls=8,walkSamples=floorSamples,throughSamples=throughSamples,crystalSamples=#zones*49,parts=#route:GetDescendants()}
end
shared.CrystalRun={export=export,apply=function()
 assert(not game:GetService('RunService'):IsRunning() and not map:FindFirstChild(route.Name))
 assert(foundation.CFrame==oldFrame and foundation.Size==oldSize)
 foundation.Size=Vector3.new(30,13,30);foundation.CFrame=CFrame.new(0,31.5,-108)
 route.Parent=map
 local ok,result=pcall(verify)
 if not ok then route.Parent=nil;foundation.Size=oldSize;foundation.CFrame=oldFrame;error(result) end
 return result
end,verify=verify}
return {exportLength=#export}
