-- Stage the southbound Crystal Run in shared Edit. Export only the new
-- fixtures; the checked saver mirrors the existing reparent/translation.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game.RunService:IsEdit())
assert(not shared.OutwardCrystalRun)
local map=workspace.MiningAway.Map
local old=map.CrystalRun
assert(old.Quartz.Field.Position==Vector3.new(0,3.74,-72) and #old:GetDescendants()==56)
local reference=map.MiningAwayReferenceGround
local grove=reference.OriginalGrove
local checker=reference.Baseplate.Texture
assert(checker.Texture=='rbxassetid://6372755229' and checker.StudsPerTileU==8 and checker.StudsPerTileV==8)
local route=Instance.new('Folder');route.Name='CrystalRun'
local archive=Instance.new('Folder');archive.Name='PreOutwardCrystalRun'
local terrain,mapFloor=map.DronerevolutionTerraces,reference.Baseplate
local anchor,depth,width,top=126,64,108,4.04
local swatches={
 {'Quartz',{180,136,127},{255,200,158},.8},
 {'Ruby',{180,136,127},{255,163,157},.65},
 {'Cobalt',{123,133,180},{172,194,245},0},
 {'Violet',{148,129,166},{217,191,243},.55},
 {'Emerald',{118,153,135},{177,224,183},.55},
}
local function part(parent,name,position,size,color,solid)
 local p=Instance.new('Part')
 p.Name=name;p.Size=size;p.Position=position;p.Color=color;p.Material=Enum.Material.Plastic
 p.Anchored=true;p.CanTouch=false;p.CanCollide=solid;p.CanQuery=solid
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end
local function sign(parent,name,at,label,color)
 local p=part(parent,name,at,Vector3.new(16,2.6,.22),Color3.fromRGB(64,61,60),false)
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
  local gui=Instance.new('SurfaceGui');gui.Name='Sign';gui.Face=face
  gui.CanvasSize=Vector2.new(560,112);gui.LightInfluence=.35;gui.Parent=p
  local t=Instance.new('TextLabel');t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1)
  t.Font=Enum.Font.GothamBold;t.Text=label;t.TextColor3=color;t.TextSize=37;t.Parent=gui
 end
 return p
end
local function finish(floor)
 local t=checker:Clone()
 -- Keep an unbroken 8-stud grid across the larger beds and the original baseplate.
 t.OffsetStudsU=(floor.Position.X-floor.Size.X/2-mapFloor.Position.X+mapFloor.Size.X/2)%t.StudsPerTileU
 t.OffsetStudsV=(floor.Position.Z-floor.Size.Z/2-mapFloor.Position.Z+mapFloor.Size.Z/2)%t.StudsPerTileV
 t.Parent=floor
end
for i,data in ipairs(swatches) do
 local zone=Instance.new('Folder');zone.Name=data[1];zone.Parent=route
 local near=anchor+(i-1)*depth
 local patchColor,capColor=Color3.fromRGB(table.unpack(data[2])),Color3.fromRGB(table.unpack(data[3]))
 local floor=part(zone,'Field',Vector3.new(0,top-.3,near+depth/2),
  Vector3.new(width,.6,depth),mapFloor.Color:Lerp(patchColor,.14),true)
 floor:SetAttribute('CrystalZone',i);finish(floor)
 for j,p in ipairs({{0,i==1 and 21 or 38},{-34,i%2==1 and 37 or 26},{34,i%2==1 and 26 or 37}}) do
  local patch=part(zone,'Patch'..j,Vector3.new(p[1],top-1+.012,near+p[2]),Vector3.new(30,2,30),patchColor,false)
  patch.Transparency=data[4];patch.CastShadow=false;patch:SetAttribute('CrystalCluster',true)
 end
 if i>1 then
  for _,side in ipairs({-1,1}) do
   part(zone,side<0 and 'WestWall' or 'EastWall',Vector3.new(side*32.5,top+3.4,near),Vector3.new(43,6.8,2.25),
    Color3.fromRGB(103,99,97),true)
   part(zone,'WallCap',Vector3.new(side*32.5,top+6.95,near),Vector3.new(43,.3,2.25),capColor,true)
  end
 end
 sign(zone,'ZoneSign',Vector3.new(-25,top+(i==1 and 1.8 or 4.5),near-1.3),
  string.format('%02d   %s',i,string.upper(data[1])),capColor)
end
sign(route,'TrailSign',Vector3.new(25,top+1.7,120),'CRYSTAL RUN  ↑',Color3.fromRGB(255,216,177))
part(route,'EndWall',Vector3.new(0,top+1.8,anchor+#swatches*depth),Vector3.new(width,3.6,2),
 Color3.fromRGB(103,99,97),true)

local translations,frames,feet={},{},{}
local delta=Vector3.new(-124,0,0)
local function xyz(v) return {v.X,v.Y,v.Z} end
for _,p in ipairs(grove:GetDescendants()) do if p:IsA('BasePart') then
 assert(p:IsA('Part') and p.Anchored)
 frames[p]=p.CFrame
 table.insert(translations,{path=p:GetFullName(),class='Part',anchor=xyz(p.Position),anchorSize=xyz(p.Size),
  before={position=xyz(p.Position)},after={position=xyz(p.Position+delta)}})
end end
assert(#translations==19,'Unexpected reference grove inventory')
-- The old floor supported these piers 0.24 studs above the checker base.
-- Extend only their feet; the underside of the overlook stays at Y=25.
for _,p in ipairs(old.OverlookPiers:GetChildren()) do
 assert(p:IsA('Part') and math.abs(p.Position.Y-p.Size.Y/2-4.04)<.002)
 local y=4.04-(mapFloor.Position.Y+mapFloor.Size.Y/2)
 feet[p]={p.CFrame,p.Size,y}
 table.insert(translations,{path=p:GetFullName(),class='Part',anchor=xyz(p.Position),anchorSize=xyz(p.Size),
  before={position=xyz(p.Position),size=xyz(p.Size)},
  after={position=xyz(p.Position-Vector3.yAxis*y/2),size=xyz(p.Size+Vector3.yAxis*y)}})
end
assert(#translations==23,'Unexpected pier inventory')
local reparent={
 {object=old.OverlookPiers,to=terrain.NorthOverlook},
 {object=old.ChargingStation,to=route},
 {object=old.ChargeIndicator,to=route},
 {object=old.ChargingSign,to=route},
}
local function verify()
 assert(game.RunService:IsEdit() and route.Parent==map and old.Parent==archive)
 local p=RaycastParams.new();p.RespectCanCollide=true
 local bedChecks,patchChecks,aisleChecks=0,0,0
 for i,data in ipairs(swatches) do
  local zone=route[data[1]]
  local bed=zone.Field
  for x=-49,49,7 do for z=-28,28,7 do
   local hit=workspace:Raycast(Vector3.new(x,top+16,bed.Position.Z+z),Vector3.new(0,-18,0),p)
   assert(hit and hit.Instance==bed and math.abs(hit.Position.Y-top)<.005,'Unclear bed at '..data[1]..': '..x..', '..z)
   bedChecks+=1
  end end
  for j=1,3 do
   local patch=zone['Patch'..j]
   assert(patch.Size==Vector3.new(30,2,30) and not patch.CanQuery and not patch.CanCollide)
   for x=-16,16,8 do for z=-16,16,8 do
    local hit=workspace:Raycast(Vector3.new(patch.Position.X+x,top+17,patch.Position.Z+z),Vector3.new(0,-18,0),p)
    assert(hit and hit.Instance==bed,'Obstructed reference patch: '..patch:GetFullName())
    patchChecks+=1
   end end
  end
 end
 for _,x in ipairs({-16,16}) do
  for z=30,126,2 do
   local hit=workspace:Raycast(Vector3.new(x,top+3,z),Vector3.new(0,-4,0),p)
   assert(hit and math.abs(hit.Position.Y-top)<.25,'Blocked approach '..x..', '..z)
   aisleChecks+=1
  end
 end
 for _,x in ipairs({-7,0,7}) do
  for _,y in ipairs({4.3,6,8,11,14}) do
   assert(not workspace:Raycast(Vector3.new(x,y,127),Vector3.new(0,0,316),p),'Blocked center aisle')
   aisleChecks+=1
  end
 end
 for i=2,#swatches do
  local wallZ=anchor+(i-1)*depth
  for _,x in ipairs({-42,42}) do
   local hit=workspace:Raycast(Vector3.new(x,top+3,wallZ-3),Vector3.new(0,0,6),p)
   assert(hit and hit.Instance:IsDescendantOf(route[swatches[i][1]]),'Missing divider')
  end
 end
 assert(terrain.NorthOverlook.OverlookPiers and route.ChargingStation and route.ChargingSign)
 for p in pairs(feet) do
  assert(math.abs(p.Position.Y+p.Size.Y/2-25)<.005)
  assert(math.abs(p.Position.Y-p.Size.Y/2-(mapFloor.Position.Y+mapFloor.Size.Y/2))<.005)
 end
 return {id=game.PlaceId,universe=game.GameId,version=game.PlaceVersion,bedChecks=bedChecks,
  patchChecks=patchChecks,aisleChecks=aisleChecks,fields=#swatches,patches=3*#swatches,grove=19,
  firstZ=anchor,lastZ=anchor+#swatches*depth,width=width}
end
local function rollback()
 route.Parent=nil;old.Parent=map
 for _,entry in ipairs(reparent) do entry.object.Parent=old end
 for p,frame in pairs(frames) do p.CFrame=frame end
 for p,foot in pairs(feet) do p.Size=foot[2];p.CFrame=foot[1] end
 archive.Parent=nil
end
local function apply()
 assert(game.RunService:IsEdit() and old.Parent==map and not archive.Parent and not route.Parent)
 for p,frame in pairs(frames) do assert(p:IsDescendantOf(grove) and p.CFrame==frame,'Grove changed after staging') end
 for p,foot in pairs(feet) do assert(p.CFrame==foot[1] and p.Size==foot[2],'Pier changed after staging') end
 for _,entry in ipairs(reparent) do assert(entry.object.Parent==old,'Old route changed after staging') end
 local ok,answer=pcall(function()
  archive.Parent=game.ServerStorage;old.Parent=archive;route.Parent=map
  for _,entry in ipairs(reparent) do entry.object.Parent=entry.to end
  for p,frame in pairs(frames) do p.CFrame=frame+delta end
  for p,foot in pairs(feet) do p.Size=foot[2]+Vector3.yAxis*foot[3];p.CFrame=foot[1]-Vector3.yAxis*foot[3]/2 end
  return verify()
 end)
 if not ok then rollback();error(answer) end
 return answer
end
local ser,enc=game:GetService('SerializationService'),game:GetService('EncodingService')
local function export(objects)
 local raw=ser:SerializeInstancesAsync(objects)
 return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(raw,Enum.CompressionAlgorithm.Zstd)))
end
shared.OutwardCrystalRun={route=export({route}),archive=export({archive}),translations=game.HttpService:JSONEncode(translations),
 apply=apply,verify=verify,rollback=rollback}
return {routeBytes=#shared.OutwardCrystalRun.route,archiveBytes=#shared.OutwardCrystalRun.archive}
