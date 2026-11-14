-- Crystal Run templates and their fracture halves are built once per server.
local CrystalGeometry=require('./CrystalGeometry')
local C={variants={'Needle','Crown','Spear','Oblique','Triad','Fan','Terrace','Outcrop'}}
local clusters={
 Triad={core='Spear',width=.92,height=1, feet={{-.45,.14,.56,-.28},{.49,-.15,.44,.33},{.04,.52,.25,-.21}}},
 Fan={core='Oblique',width=.72,height=.92, feet={{-.54,.05,.79,-.53},{.56,.13,.63,.43},{.17,-.56,.29,.28}}},
 Terrace={core='Crown',width=1.12,height=.67, feet={{.57,.29,.45,.31},{-.52,.23,.35,-.44},{.12,-.59,.24,.14}}},
 Outcrop={core='Needle',width=.89,height=.83, feet={{-.55,-.03,.64,-.43},{.42,-.40,.49,.33},{.43,.37,.32,.21},{-.16,.59,.22,-.26}}},
}
local function box(size,frame)
 local p=Instance.new('Part');p.Anchored=true;p.Size=size;p.CFrame=frame
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 return p
end
local function clean(part,name)
 part.Name=name;part.PivotOffset=CFrame.new();part.Anchored=true
 part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Material=Enum.Material.SmoothPlastic;part.MaterialVariant='';part.Reflectance=0
 if part:IsA('PartOperation') then part.UsePartColor=true end
 return part
end
local function solid(results)
 if type(results)~='table' then return nil end
 if #results==1 and results[1]:IsA('BasePart') then return results[1] end
 for _,part in ipairs(results) do part:Destroy() end
 return nil
end
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
 elseif name=='Spear' or name=='Oblique' then
  -- Four steep facets meet at a single tip. Shift the apex for a second
  -- silhouette without widening the footprint or using a tilted collision box.
  local lean=name=='Oblique'
  local x,z=lean and .68 or -.17,lean and -.58 or .16
  bevel(p,.69,-.28,.69,.08)
  plane(p,x,1.91,z,1,lean and .27 or .50,0)
  plane(p,x,1.91,z,-1,lean and .79 or .41,0)
  plane(p,x,1.91,z,0,lean and .79 or .47,1)
  plane(p,x,1.91,z,0,lean and .20 or .43,-1)
  plane(p,.46,-1.73,-.11,1,-.70,0)
  plane(p,-.61,-1.70,.08,-1,-.72,.13)
  plane(p,.16,-1.79,.49,0,-.63,1)
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
function C.build(name,cuts)
 local cluster=clusters[name]
 if cluster then
  if not cuts[cluster.core] or not cuts.Oblique or not cuts.Crown then return nil end
  local core=cuts[cluster.core]:Clone();core.CFrame=CFrame.new()
  core.Size*=Vector3.new(cluster.width,cluster.height,cluster.width)
  local feet={}
  for i,spec in ipairs(cluster.feet) do
   local x,z,height,lean=table.unpack(spec)
   local foot=(i%2==0 and cuts.Crown or cuts.Oblique):Clone()
   foot.Size=Vector3.new(.82+.20*height,core.Size.Y*height,.88+.28*height)
   local turn=CFrame.Angles(0,i*1.63,0)*CFrame.Angles(0,0,lean)
   local support=math.abs(turn.RightVector.Y)*foot.Size.X+math.abs(turn.UpVector.Y)*foot.Size.Y+math.abs(turn.LookVector.Y)*foot.Size.Z
   foot.CFrame=CFrame.new(x,-core.Size.Y*.5+support*.5,z)*turn
   feet[#feet+1]=foot
  end
  local ok,parts=pcall(function()
   return game:GetService('GeometryService'):UnionAsync(core,feet,{
    CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=false,
   })
  end)
  core:Destroy();for _,foot in ipairs(feet) do foot:Destroy() end
  local merged=ok and solid(parts)
  return merged and clean(merged,name) or nil
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
 return clean(result[1],name)
end
function C.split(template,name)
 local base=template:Clone();base.CFrame=CFrame.new()
 local size=base.Size
 local container=Instance.new('Folder');container.Name=name
 container:SetAttribute('HingeY',base.ExtentsCFrame.Position.Y/size.Y-.5)
 local halfSpan=size.Magnitude*1.1
 for index,side in ipairs({-1,1}) do
  local clip=box(Vector3.one*(2*halfSpan),CFrame.new(side*halfSpan,0,0))
  local ok,result=pcall(function()
   return game:GetService('GeometryService'):IntersectAsync(base,{clip},{
    CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=false,
   })
  end)
  clip:Destroy()
  local half=ok and solid(result)
  if not half or math.abs(half.Size.Y-size.Y)>size.Y*.46 or half.Size.X>size.X*.68 then
   if half then half:Destroy() end
   base:Destroy();container:Destroy();return nil
  end
  clean(half,index==1 and 'Left' or 'Right')
  half.CastShadow=false
  half:SetAttribute('SizeRatio',half.Size/size)
  -- CSG extents may sit off-center from the returned part's CFrame. Account
  -- for the mesh-local offset when applying non-uniform stage dimensions.
  half:SetAttribute('CenterRatio',half.ExtentsCFrame.Position/size-(half.ExtentsCFrame.Position-half.Position)/half.Size)
  half.Parent=container
 end
 base:Destroy()
 return container
end
function C.proportions(cut,original)
 local native,custom=original.Size,cut.Size
 local aspect=(custom/custom.Y)/(native/native.Y)
 return Vector3.new(math.clamp(aspect.X,.67,1),1,math.clamp(aspect.Z,.62,1))
end
function C.splitOriginal(original)
 local halves=C.split(original,'Original')
 if halves or not CrystalGeometry then return halves end
 -- The old URL-backed union can lose its geometry in a boolean operation.
 -- Its recovered collision surface follows the original silhouette.
 local assets=game:GetService('AssetService')
 local mesh
 local ok,part=pcall(function()
  mesh=assert(assets:CreateEditableMesh())
  local ids={}
  for i,v in ipairs(CrystalGeometry.vertices) do
   ids[i]=mesh:AddVertex(Vector3.new(v[1],v[2],v[3])*original.Size)
  end
  for _,tri in ipairs(CrystalGeometry.triangles) do mesh:AddTriangle(ids[tri[1]],ids[tri[2]],ids[tri[3]]) end
  return assets:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
 end)
 if ok then halves=C.split(part,'Original');part:Destroy() end
 if mesh then mesh:Destroy() end
 return halves
end
return C
