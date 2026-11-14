-- Shared per-mineral shells and opaque, fixed interior grains.
local Gem={}
local templates,meshes,attempted={},{},false
local Geometry=require('./GemGeometry')
Gem.geometry=Geometry
Gem.key=Geometry.key
function Gem.tint(value) local key=Geometry.key(value);local spec=Geometry.definitions[key];return spec.colors[key=='Emerald' and 3 or 2] end
local function build(key)
 local data=Geometry.describe(key)
 local assets=game:GetService('AssetService')
 local mesh=assert(assets:CreateEditableMesh());meshes[#meshes+1]=mesh
 for _,f in ipairs(data.faces) do
  local ids={}
  for i=1,3 do ids[i]=mesh:AddVertex(f[i]) end
  local face=mesh:AddTriangle(ids[1],ids[2],ids[3])
  local n=mesh:AddNormal((f[2]-f[1]):Cross(f[3]-f[1]).Unit)
  mesh:SetFaceNormals(face,{n,n,n})
  mesh:SetFaceColors(face,{mesh:AddColor(f[4],data.vertexAlpha),mesh:AddColor(f[5],data.vertexAlpha),mesh:AddColor(f[6],data.vertexAlpha)})
 end
 local function part(m,name)
  -- Release the large dynamic allocation before building the next mineral.
  local fixed=assert(assets:CreateEditableMeshAsync(Content.fromObject(m),{FixedSize=true}))
  for i,item in ipairs(meshes) do if item==m then meshes[i]=fixed;break end end
  m:Destroy()
  local p=assets:CreateMeshPartAsync(Content.fromObject(fixed),{CollisionFidelity=Enum.CollisionFidelity.Box})
  p.Name=name;p.Anchored=true;p.Color=Color3.new(1,1,1);p.Material=Enum.Material.Neon
  p.Reflectance=0;p.DoubleSided=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  return p
 end
 local shell=part(mesh,'Faceted'..key)
 if #data.grains>0 then
  local core=assert(assets:CreateEditableMesh());meshes[#meshes+1]=core
 local coreMin,coreMax=Vector3.one*math.huge,-Vector3.one*math.huge

 for _,grain in ipairs(data.grains) do
  local center,s=grain[1],grain[2]
  local white=core:AddColor(grain[3] or Color3.new(1,1,1),1)
  local v,p={},{}
  for _,d in ipairs({Vector3.xAxis,-Vector3.xAxis,Vector3.yAxis,-Vector3.yAxis,Vector3.zAxis,-Vector3.zAxis}) do
   p[#p+1]=center+d*s;v[#v+1]=core:AddVertex(p[#p])
   coreMin=coreMin:Min(p[#p]);coreMax=coreMax:Max(p[#p])
  end
  for _,face in ipairs({{1,3,5},{5,3,2},{2,3,6},{6,3,1},{1,5,4},{5,2,4},{2,6,4},{6,1,4}}) do
   local x,y,z=table.unpack(face)
   if (p[y]-p[x]):Cross(p[z]-p[x]):Dot((p[x]+p[y]+p[z])/3-center)<0 then y,z=z,y end
   local f=core:AddTriangle(v[x],v[y],v[z]);core:SetFaceColors(f,{white,white,white})
  end
 end
  local grains=part(core,'FixedInclusions')
  grains:SetAttribute('SizeRatio',(coreMax-coreMin)/data.extents)
  grains:SetAttribute('CenterRatio',((coreMin+coreMax)*.5-data.center)/data.extents)
  grains.Parent=shell
 end
 if #data.clouds>0 then
  local cloud=assert(assets:CreateEditableMesh());meshes[#meshes+1]=cloud
  local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
  for _,f in ipairs(data.clouds) do
   local ids={}
   for i=1,3 do ids[i]=cloud:AddVertex(f[i]);lo=lo:Min(f[i]);hi=hi:Max(f[i]) end
   local face=cloud:AddTriangle(ids[1],ids[2],ids[3])
   cloud:SetFaceColors(face,{cloud:AddColor(f[4],.62),cloud:AddColor(f[5],.62),cloud:AddColor(f[6],.62)})
  end
  local inside=part(cloud,'MineralClouds');inside.Material=Enum.Material.SmoothPlastic
  inside:SetAttribute('SizeRatio',(hi-lo)/data.extents)
  inside:SetAttribute('CenterRatio',((hi+lo)*.5-data.center)/data.extents)
  inside.Parent=shell
 end
 shell.Material=Enum.Material[data.material]
 shell.Reflectance=key=='Cobalt' and .18 or key=='Diamond' and .12 or key=='Quartz' and .04 or 0
 shell:SetAttribute('GemKind',key)
 shell:SetAttribute('GemAspect',data.aspect)
 shell:SetAttribute('GemOpacity',data.opacity)
 shell.Transparency=1-shell:GetAttribute('GemOpacity')
 return shell
end
function Gem.prepare()
 if attempted then return end;attempted=true
 for _,key in ipairs({'Amber','Ruby','Quartz','Violet','Diamond','Cobalt','Emerald'}) do
  local first=#meshes
  local ok,result=pcall(build,key)
  if ok then templates[key]=result
  else
   for i=#meshes,first+1,-1 do meshes[i]:Destroy();meshes[i]=nil end
   if warn then warn('GemAppearance '..key..': '..tostring(result)) end
  end
 end
end
function Gem.clone(source)
 local template=templates[Gem.key(source:GetAttribute('Mineral'))]
 if not template or source.Name=='PressedCargo' then return source:Clone(),false end
 local p=template:Clone();p.Size=source.Size*template:GetAttribute('GemAspect');p.CFrame=source.CFrame
 for k,v in pairs(source:GetAttributes()) do p:SetAttribute(k,v) end
 Gem.update(p,1)
 return p,true
end
function Gem.update(part,opacity)
 for _,name in ipairs({'FixedInclusions','MineralClouds'}) do
 local core=part:FindFirstChild(name)
 if core then
  core.Size=part.Size*core:GetAttribute('SizeRatio')
  core.CFrame=part.CFrame*CFrame.new(part.Size*core:GetAttribute('CenterRatio'))
  core.Transparency=1-opacity
 end
 end
end
return Gem
