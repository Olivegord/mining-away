-- One-time native terrain planting. Roblox renders grass and wind internally.
local N={}
function N.build(plan,root)
 local terrain=workspace:FindFirstChildOfClass('Terrain')
 if not terrain then return end
 workspace.GlobalWind=Vector3.new(3.5,0,1.2)
 terrain:SetMaterialColor(Enum.Material.Grass,Color3.fromRGB(102,153,76))
 terrain:SetMaterialColor(Enum.Material.Ground,Color3.fromRGB(174,173,86))
 -- A one-voxel soil collar supports the smooth surface at meadow edges.
 -- Without it, empty neighbor columns pull grass roots two studs below slopes.
 local columns={};local occupied={}
 for _,cell in ipairs(plan.grass) do
  table.insert(columns,cell);occupied[cell.x..':'..cell.z]=true
 end
 for _,cell in ipairs(plan.grass) do for dx=-4,4,4 do for dz=-4,4,4 do
  local x,z=cell.x+dx,cell.z+dz;local key=x..':'..z
  if not occupied[key] then
   occupied[key]=true
   table.insert(columns,{x=x,z=z,y=plan:surface(x,z),dry=true,support=true})
  end
 end end end
 local groups={};local keys={}
 for _,cell in ipairs(columns) do
  local gx,gz=math.floor((cell.x-2)/32),math.floor((cell.z-2)/32)
  local key=gx..':'..gz;local group=groups[key]
  if not group then group={x=gx*32,z=gz*32,low=math.huge,high=-math.huge,cells={}};groups[key]=group;table.insert(keys,key) end
  table.insert(group.cells,cell)
  group.low=math.min(group.low,math.floor((cell.y-8)/4)*4)
  group.high=math.max(group.high,math.ceil((cell.y+4)/4)*4)
 end
 table.sort(keys)
 local dry=0
 for _,key in ipairs(keys) do
  local group=groups[key]
  local region=Region3.new(Vector3.new(group.x,group.low,group.z),Vector3.new(group.x+32,group.high,group.z+32))
  -- Read first: unplanted columns and unrelated authored terrain remain intact.
  local materials,occupancies=terrain:ReadVoxels(region,4)
  for _,cell in ipairs(group.cells) do
   local ix,iz=math.floor((cell.x-group.x)/4)+1,math.floor((cell.z-group.z)/4)+1
   -- Smooth terrain reconstructs the iso-surface half a voxel above
   -- this occupancy height. Compensate so the floor stays at plan + .25.
   local top=cell.y-1.75
   if cell.dry and not cell.support then dry+=1 end
   for iy=1,#materials[ix] do
    local bottom=group.low+(iy-1)*4
    if bottom>=cell.y-8 and bottom<top then
     materials[ix][iy][iz]=cell.dry and Enum.Material.Ground or Enum.Material.Grass
     occupancies[ix][iy][iz]=math.clamp((top-bottom)/4,0,1)
    end
   end
  end
  terrain:WriteVoxels(region,4,materials,occupancies)
  task.wait()
 end
 root:SetAttribute('GrassRenderer','Native terrain decoration')
 root:SetAttribute('NativeGrassCells',#plan.grass-dry)
 root:SetAttribute('DryMeadowCells',dry)
 root:SetAttribute('SkinnedGrassPatches',0)
end
return N

