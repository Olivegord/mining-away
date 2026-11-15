-- Shared native Edit approximation for the runtime gem data.
local function bakeGemPreview(key,data,frame,size)
 local function part(class,name,size,frame,color,parent)
  local p=Instance.new(class);p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Material=Enum.Material[data.material];p.Parent=parent
  return p
 end
 local function triangle(a,b,c,color,parent,alpha)
  -- Split a triangle along the altitude to its longest edge into two wedges.
  if (b-a).Magnitude>(c-b).Magnitude and (b-a).Magnitude>(c-a).Magnitude then a,c=c,a
  elseif (c-a).Magnitude>(c-b).Magnitude then a,b=b,a end
  local edge=c-b
  if edge.Magnitude<.0001 then return end
  local foot=b+edge*((a-b):Dot(edge)/edge:Dot(edge))
  local height=(a-foot).Magnitude
  if height<.0001 then return end
  local up=(a-foot).Unit
  for _,endPoint in ipairs({b,c}) do
   local offset=foot-endPoint
   if offset.Magnitude>.0001 then
    local back=offset.Unit
    local wedge=part('WedgePart','Facet',Vector3.new(.002,height,offset.Magnitude),
     CFrame.fromMatrix((a+endPoint)*.5,up:Cross(back),up,back),color,parent)
    wedge.Transparency=alpha
   end
  end
 end
 local preview=Instance.new('Folder');preview.Name='PreviewGeometry'
 local function point(p) return frame:PointToWorldSpace((p-data.center)/data.extents*size) end
 -- Bake the same transformed triangles and interpolated facet colors used
 -- by GemAppearance. Box scaling before rotation distorted the old bismuth.
 local alpha=1-data.opacity*data.vertexAlpha
 local function texturedTriangle(vertices,colors,uvs,depth,parent,transparency)
  if depth>0 then
   local ab,bc,ca=(vertices[1]+vertices[2])*.5,(vertices[2]+vertices[3])*.5,(vertices[3]+vertices[1])*.5
   local cab,cbc,cca=colors[1]:Lerp(colors[2],.5),colors[2]:Lerp(colors[3],.5),colors[3]:Lerp(colors[1],.5)
   local uab,ubc,uca=(uvs[1]+uvs[2])*.5,(uvs[2]+uvs[3])*.5,(uvs[3]+uvs[1])*.5
   texturedTriangle({vertices[1],ab,ca},{colors[1],cab,cca},{uvs[1],uab,uca},depth-1,parent,transparency)
   texturedTriangle({ab,vertices[2],bc},{cab,colors[2],cbc},{uab,uvs[2],ubc},depth-1,parent,transparency)
   texturedTriangle({ca,bc,vertices[3]},{cca,cbc,colors[3]},{uca,ubc,uvs[3]},depth-1,parent,transparency)
   texturedTriangle({ab,bc,ca},{cab,cbc,cca},{uab,ubc,uca},depth-1,parent,transparency)
   return
  end
  local c=colors[1]:Lerp(colors[2],.5):Lerp(colors[3],1/3)
  if data.texture or key=='Diamond' then
   local uv=(uvs[1]+uvs[2]+uvs[3])/3
   local shade=RockFinish.Gems.geometry.texture(uv.X%1,uv.Y%1,key)
   if key=='Diamond' then
    local spectral=RockFinish.Gems.geometry.spectrum(uv.X%1,uv.Y%1)
    c=Color3.new(c.R*spectral.R,c.G*spectral.G,c.B*spectral.B)
   else c=Color3.new(c.R*shade,c.G*shade,c.B*shade) end
  end
  triangle(vertices[1],vertices[2],vertices[3],c,parent,transparency)
 end
 for index,f in ipairs(data.faces) do
  local a,b,c=point(f[1]),point(f[2]),point(f[3])
  if key=='Cobalt' then triangle(a,b,c,f[4],preview,alpha)
  else
   local uvs={f[7] or Vector2.zero,f[8] or Vector2.zero,f[9] or Vector2.zero}
   texturedTriangle({a,b,c},{f[4],f[5],f[6]},uvs,key=='Diamond' and 2 or 1,preview,alpha)
  end
  if index%70==0 then task.wait() end
 end
 if key=='Cobalt' then
  for _,facet in ipairs(preview:GetChildren()) do facet.Material=Enum.Material.Metal;facet.Reflectance=.18 end
 end
 for _,grain in ipairs(data.grains) do
  local radius=grain[2]
  local v={}
  for _,d in ipairs({Vector3.xAxis,-Vector3.xAxis,Vector3.yAxis,-Vector3.yAxis,Vector3.zAxis,-Vector3.zAxis}) do v[#v+1]=point(grain[1]+d*radius) end
  for _,f in ipairs({{1,3,5},{5,3,2},{2,3,6},{6,3,1},{1,5,4},{5,2,4},{2,6,4},{6,1,4}}) do
   triangle(v[f[1]],v[f[2]],v[f[3]],grain[3] or Color3.new(1,1,1),preview,0)
  end
 end
 local clouds=Instance.new('Folder');clouds.Name='MineralClouds'
 for _,f in ipairs(data.clouds or {}) do
  texturedTriangle({point(f[1]),point(f[2]),point(f[3])},{f[4],f[5],f[6]},{f[7] or Vector2.zero,f[8] or Vector2.zero,f[9] or Vector2.zero},1,clouds,key=='Diamond' and .44 or .78)
 end
 -- Consolidate the durable Edit approximation into one shell and one grain
 -- object. Thousands of temporary wedges must not remain in the live map.
 local rims=Instance.new('Folder')
 for _,f in ipairs(key=='Diamond' and {} or data.rims or {}) do triangle(point(f[1]),point(f[2]),point(f[3]),f[4],rims,key=='Diamond' and 0 or .32) end
 local groups={{},{},clouds:GetChildren(),rims:GetChildren()}
 for _,p in ipairs(preview:GetChildren()) do local group=p.Transparency==0 and groups[2] or groups[1];group[#group+1]=p end
 for index,pieces in ipairs(groups) do
  if #pieces>0 then
   local first=table.remove(pieces,1)
   local result=game:GetService('GeometryService'):UnionAsync(first,pieces,{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=false})
   assert(#result==1,'specimen consolidation failed')
   local combined=result[1];combined.Name=index==1 and 'FacetShell' or index==2 and 'FixedInclusions' or index==3 and 'MineralClouds' or 'PrismaticEdges'
   combined.UsePartColor=false;combined.Anchored=true;combined.CanCollide=false;combined.CanTouch=false;combined.CanQuery=false;combined.CastShadow=false
   combined.Material=key=='Diamond' and Enum.Material.SmoothPlastic or first.Material;combined.Reflectance=first.Reflectance;combined.Transparency=first.Transparency
   combined.Parent=preview;first:Destroy();for _,p in ipairs(pieces) do p:Destroy() end
   task.wait()
  end
 end
 clouds:Destroy();rims:Destroy()
 return preview
end
