-- Stage only authored geometry in the selected shared Edit document.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and not game:GetService('RunService'):IsRunning())
local root=workspace.MiningAway
local map=root.Map
local oldRun=map.CrystalRun
local terrain=workspace.Terrain
local storage=game:GetService('ServerStorage')
local serializer=game:GetService('SerializationService')
local encoding=game:GetService('EncodingService')
local http=game:GetService('HttpService')
assert(not storage:FindFirstChild('FlatFieldsArchive') and not oldRun:GetAttribute('WholeFields'))
local stage={snapshot={}}
shared.FlatFieldsStage=stage
local function export(value)
 return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(value,Enum.CompressionAlgorithm.Zstd)))
end
local function model(instance)
 return export(serializer:SerializeInstancesAsync({instance}))
end
local archive=Instance.new('Folder');archive.Name='FlatFieldsArchive'
local min=Vector3int16.new(-256,-32,-256)
local max=Vector3int16.new(255,31,255)
local terrainCopy=terrain:CopyRegion(Region3int16.new(min,max))
terrainCopy.Name='OriginalVoxels'
terrainCopy:SetAttribute('PasteCorner',Vector3.new(min.X,min.Y,min.Z))
terrainCopy.Parent=archive
local oldCellCount=terrain:CountCells()
local moves={}
local function retire(instance)
 table.insert(moves,{instance=instance,parent=instance.Parent})
end
for _,name in ipairs({'PlatformSurfaceFill','QuarryContinuousGround','MiningAwayReferenceGround',
 'CrystalRun','DronerevolutionTerraces'}) do retire(assert(map:FindFirstChild(name),name)) end
retire(root.Fields)
retire(workspace.Part)
for _,name in ipairs({'MideDibber_Hats','OliveGord_Hats'}) do retire(assert(terrain:FindFirstChild(name),name)) end
local run=Instance.new('Folder');run.Name='CrystalRun';run:SetAttribute('WholeFields',true)
local function slab(parent,name,x,y,z,w,h,d,color)
 local part=Instance.new('Part');part.Name=name;part.Anchored=true
 part.Size=Vector3.new(w,h,d);part.Position=Vector3.new(x,y,z);part.Color=Color3.fromRGB(table.unpack(color))
 part.Material=Enum.Material.SmoothPlastic;part.TopSurface=Enum.SurfaceType.Smooth
 part.BottomSurface=Enum.SurfaceType.Smooth;part.CanTouch=false;part.CastShadow=false;part.Parent=parent
 return part
end
slab(run,'FlatGround',0,3,-166,204,2,236,{112,145,114})
local plots={
 {'Quartz',0,-82,{194,164,104}},
 {'Ruby',-68,-131,{181,115,111}},
 {'Cobalt',63,-148,{166,169,179}},
 {'Violet',-41,-212,{152,124,170}},
 {'Emerald',48,-231,{128,170,178}},
}
for tier,plot in ipairs(plots) do
 local field=Instance.new('Folder');field.Name=plot[1];field.Parent=run
 local bed=slab(field,'Field',plot[2],3.80,plot[3],46,.8,46,plot[4])
 bed:SetAttribute('CrystalZone',tier);bed:SetAttribute('WholeField',true)
end
for _,name in ipairs({'ChargingStation','ChargeIndicator'}) do
 local charger=assert(oldRun:FindFirstChild(name)):Clone()
 charger.Parent=run
end
local fields=Instance.new('Folder');fields.Name='Fields'
stage.snapshot.archive=model(archive)
stage.snapshot.run=model(run)
stage.snapshot.fields=model(fields)
stage.snapshot.terrainBefore=model(terrain)
function stage.apply()
 assert(workspace.MiningAway.Map==map and map.CrystalRun==oldRun and not game:GetService('RunService'):IsRunning())
 assert(terrain:CountCells()==oldCellCount and model(terrain)==stage.snapshot.terrainBefore,'Terrain changed during staging')
 for _,move in ipairs(moves) do assert(move.instance.Parent==move.parent,move.instance.Name) end
 local ok,result=pcall(function()
  archive.Parent=storage
  for _,move in ipairs(moves) do move.instance.Parent=archive end
  run.Parent=map;fields.Parent=root
  terrain:Clear()
  assert(terrain:CountCells()==0,'Terrain still occupied')
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Include
  params.FilterDescendantsInstances={run,map.SimpleFlatTestMap,terrain}
  local minimum=math.huge
  for i,plot in ipairs(plots) do
   local bed=run[plot[1]].Field
   local hit=workspace:Raycast(bed.Position+Vector3.yAxis*20,-Vector3.yAxis*40,params)
   assert(hit and hit.Instance==bed and bed.Size.X==bed.Size.Z and bed.Position.Z<workspace.SpawnLocation.Position.Z)
   for j=1,i-1 do
    local other=plots[j]
    local dx=math.max(0,math.abs(plot[2]-other[2])-46)
    local dz=math.max(0,math.abs(plot[3]-other[3])-46)
    minimum=math.min(minimum,math.sqrt(dx*dx+dz*dz))
   end
  end
  for z=-289,40,2 do
   local hit=workspace:Raycast(Vector3.new(0,20,z),Vector3.new(0,-24,0),params)
   if z>=-284 then assert(hit and hit.Position.Y>=3.99,'Gap on starter route at '..z) end
  end
  stage.snapshot.terrainAfter=model(terrain)
  return {plots=#plots,fieldWidth=46,minGap=minimum,archivedRoots=#moves,terrainCellsBefore=oldCellCount,terrainCellsAfter=terrain:CountCells()}
 end)
 if not ok then
  run.Parent=nil;fields.Parent=nil
  for _,move in ipairs(moves) do move.instance.Parent=move.parent end
  archive.Parent=nil
  if terrain:CountCells()~=oldCellCount then
   terrain:Clear();terrain:PasteRegion(terrainCopy,min,true)
  end
  error(result)
 end
 return result
end
return {staged=true,terrainCells=oldCellCount,plots=#plots}
