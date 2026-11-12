-- A few solid cuts, built once per Crystal Run server from convex planes.
-- They share the original footprint and grounding contract, not its mesh.
local C={}
local function plane(list,x,y,z,nx,ny,nz)
 list[#list+1]={Vector3.new(x,y,z),Vector3.new(nx,ny,nz).Unit}
end
local function bevel(list,x,y,z,ny)
 for _,sx in ipairs({-1,1}) do
  for _,sz in ipairs({-1,1}) do plane(list,sx*x,y,sz*z,sx,ny,sz) end
 end
end
function C.planes(name)
 local p={}
 if name=='Needle' then
  bevel(p,.77,0,.77,.16)
  plane(p,.26,1.55,0,1,.43,0);plane(p,.26,1.55,0,-1,.85,0)
  plane(p,0,1.48,-.13,0,.44,1);plane(p,0,1.48,-.13,0,.62,-1)
  plane(p,.03,-1.62,0,-1,-.37,.12)
 elseif name=='Crown' then
  bevel(p,.71,0,.71,-.08)
  plane(p,0,1.04,0,-.46,1,-.17);plane(p,0,1.33,0,.48,1,.36)
  plane(p,.79,.44,.19,1,.85,.24);plane(p,-.38,.38,-.61,-.65,.66,-1)
  plane(p,.61,-1.68,0,1,-.68,0);plane(p,0,-1.57,.65,0,-.61,1)
 else -- Cut ore: octagonal girdle, smaller table, and a tapered pavilion.
  bevel(p,.73,0,.73,0)
  for _,side in ipairs({-1,1}) do
   plane(p,side*.93,0,0,side,0,0);plane(p,0,0,side*.93,0,0,side)
   plane(p,side*.45,.80,0,side,.69,0);plane(p,0,.80,side*.45,0,.69,side)
   plane(p,side*.33,-.87,0,side,-.65,0);plane(p,0,-.87,side*.33,0,-.65,side)
  end
  bevel(p,.39,.80,.39,.85);bevel(p,.30,-.87,.30,-.81)
  plane(p,0,.80,0,0,1,0);plane(p,0,-.87,0,0,-1,0)
 end
 return p
end
function C.build(name)
 local function box(size,frame)
  local p=Instance.new('Part');p.Anchored=true;p.Size=size;p.CFrame=frame
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  return p
 end
 local size=Vector3.new(2,4,2)
 local base=box(size,CFrame.new());local tools={}
 for _,cut in ipairs(C.planes(name)) do
  local point,normal=cut[1],cut[2]
  local center=point+normal*7
  tools[#tools+1]=box(Vector3.one*14,CFrame.lookAt(center,center-normal))
 end
 local ok,result=pcall(function()
  return game:GetService('GeometryService'):SubtractAsync(base,tools,{
   CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=false,
  })
 end)
 base:Destroy();for _,p in ipairs(tools) do p:Destroy() end
 if not ok then return nil,tostring(result) end
 if #result~=1 or not result[1]:IsA('PartOperation') or result[1].Size.Magnitude<2 then
  for _,p in ipairs(result) do p:Destroy() end
  return nil,'Expected one solid cut'
 end
 local part=result[1];part.Name=name;part.PivotOffset=CFrame.new();part.UsePartColor=true
 part.Material=Enum.Material.SmoothPlastic
 return part
end
return C
