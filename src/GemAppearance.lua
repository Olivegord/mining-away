-- Shared per-mineral shells and opaque, fixed interior grains.
local Gem={}
local templates,meshes,textures,attempted={},{},{},false
local Geometry=require('./GemGeometry')
Gem.geometry=Geometry
Gem.key=Geometry.key
function Gem.tint(value) local key=Geometry.key(value);local spec=Geometry.definitions[key];return spec.colors[key=='Emerald' and 3 or 2] end
local function build(key,compact)
 local data=Geometry.describe(key,compact)
 local assets=game:GetService('AssetService')
 local texture
 if (data.texture and key~='Amber') or key=='Diamond' then
  local ok,result=pcall(function()
   local width=key=='Diamond' and 256 or 128
   local bitmap=assert(assets:CreateEditableImage({Size=Vector2.new(width,width)}))
   local pixels=buffer.create(width*width*4)
   for y=0,width-1 do
    for x=0,width-1 do
     local value,alpha=Geometry.texture(x/width,y/width,key)
     local color=Color3.new(value,value,value)
     if key=='Diamond' then color,alpha=Geometry.spectrum(x/width,y/width) end
     local offset=(y*width+x)*4
     buffer.writeu8(pixels,offset,math.floor(color.R*255+.5));buffer.writeu8(pixels,offset+1,math.floor(color.G*255+.5));buffer.writeu8(pixels,offset+2,math.floor(color.B*255+.5))
     buffer.writeu8(pixels,offset+3,math.floor(alpha*255+.5))
    end
    if y%32==0 then task.wait() end
   end
   bitmap:WritePixelsBuffer(Vector2.zero,Vector2.new(width,width),pixels)
   return bitmap
  end)
  if ok then
   textures[#textures+1]=result;texture=texture or result
  else warn('Gem texture fallback '..key..': '..tostring(result)) end
 end
 if key=='Diamond' and not texture then
  for _,f in ipairs(data.clouds) do for i=1,3 do
   local uv=f[6+i];f[3+i]=Geometry.spectrum(uv.X%1,uv.Y%1)
  end end
 end
 local mesh=assert(assets:CreateEditableMesh());meshes[#meshes+1]=mesh
 -- Convex shell uses outward normals and back-face culling. The inset
 -- reflective cut is separated from the shell, with no coplanar layers.
 local layers={data.faces}
 for layer,faces in ipairs(layers) do
 for _,f in ipairs(faces) do
  local ids={}
  for i=1,3 do ids[i]=mesh:AddVertex(f[i]) end
  local face=mesh:AddTriangle(ids[1],ids[2],ids[3])
  local n=mesh:AddNormal((f[2]-f[1]):Cross(f[3]-f[1]).Unit)
  mesh:SetFaceNormals(face,{n,n,n})
  if f[7] then mesh:SetFaceUVs(face,{mesh:AddUV(f[7]),mesh:AddUV(f[8]),mesh:AddUV(f[9])}) end
  local alpha=data.vertexAlpha
  mesh:SetFaceColors(face,{mesh:AddColor(f[4],alpha),mesh:AddColor(f[5],alpha),mesh:AddColor(f[6],alpha)})
 end
 end
 local function part(m,name)
  -- Release the large dynamic allocation before building the next mineral.
  local fixed=assert(assets:CreateEditableMeshAsync(Content.fromObject(m),{FixedSize=true}))
  for i,item in ipairs(meshes) do if item==m then meshes[i]=fixed;break end end
  m:Destroy()
  local p=assets:CreateMeshPartAsync(Content.fromObject(fixed),{CollisionFidelity=Enum.CollisionFidelity.Box})
  p.Name=name;p.Anchored=true;p.Color=Color3.new(1,1,1);p.Material=Enum.Material.Neon
  p.Reflectance=0;p.DoubleSided=key~='Diamond';p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  return p
 end
 local shell=part(mesh,'Faceted'..key)
 if key=='Diamond' then shell:SetAttribute('RefractionLayers',2);shell:SetAttribute('RefractionPatterns',0) end
 if compact then shell:SetAttribute('GemCut','Compact') end
 if texture and key~='Diamond' then shell.TextureContent=Content.fromObject(texture);shell:SetAttribute('OpticalTexture',true) end
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
   local normal=cloud:AddNormal((f[2]-f[1]):Cross(f[3]-f[1]).Unit)
   cloud:SetFaceNormals(face,{normal,normal,normal})
   if f[7] then cloud:SetFaceUVs(face,{cloud:AddUV(f[7]),cloud:AddUV(f[8]),cloud:AddUV(f[9])}) end
   cloud:SetFaceColors(face,{cloud:AddColor(f[4],1),cloud:AddColor(f[5],1),cloud:AddColor(f[6],1)})
  end
  local inside=part(cloud,'MineralClouds');inside.Material=key=='Diamond' and Enum.Material.Glass or Enum.Material.Neon
  inside.Reflectance=key=='Diamond' and .45 or 0
  -- Shifted spectrum on the inset cut supplies refracted depth.
  if texture then inside.TextureContent=Content.fromObject(texture) end
  inside:SetAttribute('SizeRatio',(hi-lo)/data.extents)
  inside:SetAttribute('CenterRatio',((hi+lo)*.5-data.center)/data.extents)
  inside.Parent=shell
 end
 if data.rims and #data.rims>0 then
  local rim=assert(assets:CreateEditableMesh());meshes[#meshes+1]=rim
  local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
  for _,f in ipairs(data.rims) do
   local ids={}
   for i=1,3 do ids[i]=rim:AddVertex(f[i]);lo=lo:Min(f[i]);hi=hi:Max(f[i]) end
   local triangle=rim:AddTriangle(ids[1],ids[2],ids[3])
   rim:SetFaceColors(triangle,{rim:AddColor(f[4],f[7]),rim:AddColor(f[5],f[8]),rim:AddColor(f[6],f[9])})
  end
  local edges=part(rim,'PrismaticEdges')
  edges:SetAttribute('SizeRatio',(hi-lo)/data.extents)
  edges:SetAttribute('CenterRatio',((hi+lo)*.5-data.center)/data.extents)
  edges.Parent=shell
  for i,position in ipairs(data.flares) do shell:SetAttribute('GemFlare'..i,position) end
 end
 shell.Material=Enum.Material[data.material]
 shell.Reflectance=key=='Cobalt' and .18 or key=='Diamond' and .30 or key=='Quartz' and .04 or 0
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
 for _,key in ipairs(Geometry.order) do
  local first=#meshes
  local ok,result=pcall(build,key,true)
  if ok then templates[key..'Compact']=result else
   for i=#meshes,first+1,-1 do meshes[i]:Destroy();meshes[i]=nil end
   if warn then warn('Compact gem '..key..': '..tostring(result)) end
  end
 end
end
function Gem.clone(source)
 local template=templates[Gem.key(source:GetAttribute('Mineral'))..(source:GetAttribute('GemCut')=='Compact' and 'Compact' or '')]
 if not template or source.Name=='PressedCargo' then return source:Clone(),false end
 local p=template:Clone();p.Size=source.Size*template:GetAttribute('GemAspect');p.CFrame=source.CFrame
 for k,v in pairs(source:GetAttributes()) do p:SetAttribute(k,v) end
 Gem.update(p,1)
 return p,true
end
function Gem.update(part,opacity,cameraPosition)
 for _,name in ipairs({'FixedInclusions','MineralClouds','PrismaticEdges'}) do
 local core=part:FindFirstChild(name)
 if core then
  core.Size=part.Size*core:GetAttribute('SizeRatio')
  core.CFrame=part.CFrame*CFrame.new(part.Size*core:GetAttribute('CenterRatio'))
  -- The clear inset fades with the pickup; edge ribbons remain opaque at rest.
  core.Transparency=1-opacity*(name=='MineralClouds' and part:GetAttribute('GemKind')=='Diamond' and .88 or 1)
 end
 end
end
return Gem
