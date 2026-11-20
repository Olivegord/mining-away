-- Real recovered geometry data; this does not simulate rendering or CSG.
local G=require('../src/CrystalGeometry')
assert(G.sourceHullCount==36 and G.sourceVertexCount==471 and G.sourceTriangleCount==798)
assert(G.sourceSha256=='7a126b8c311857fcfae37fbe19508840409de4460c8454b2edcda33e6efb4be9')
assert(#G.vertices>100 and #G.vertices<1000 and #G.triangles<2000)
assert(G.hullDilation==.001 and G.weldDistance==.003 and G.simplifyTolerance==.001 and G.pointContactInset==.001)
local expected={3.1349997520446777,6.566901445388794,4.4872307777404785}
local low,high={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
for _,v in ipairs(G.vertices) do
 for k=1,3 do
  assert(v[k]==v[k] and math.abs(v[k])<=.5000001)
  low[k]=math.min(low[k],v[k]);high[k]=math.max(high[k],v[k])
 end
end
-- Roblox CSG welds close points. Pure index-manifold checks alone missed the
-- rejected first candidate, so enforce separation at canonical Size 4 too.
for i,a in ipairs(G.vertices) do for j=i+1,#G.vertices do
 local b=G.vertices[j];local dx,dy,dz=(a[1]-b[1])*4,(a[2]-b[2])*4,(a[3]-b[3])*4
 assert(dx*dx+dy*dy+dz*dz>.002^2,'Points are too close for native CSG welding')
end end
for k=1,3 do
 assert(math.abs(low[k]+.5)<1e-10 and math.abs(high[k]-.5)<1e-10)
 assert(math.abs(G.originalSize[k]-expected[k])<1e-10)
end
local edges={};local links={};local signedVolume=0
for index,t in ipairs(G.triangles) do
 local a,b,c=G.vertices[t[1]],G.vertices[t[2]],G.vertices[t[3]]
 assert(a and b and c and t[1]~=t[2] and t[2]~=t[3] and t[1]~=t[3])
 local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
 local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
 assert(nx*nx+ny*ny+nz*nz>(.00003/16)^2,'Triangle is too thin for native CSG')
 signedVolume+=(a[1]*nx+a[2]*ny+a[3]*nz)/6
 links[index]={}
 for i=1,3 do
  local u,v=t[i],t[i%3+1];local key=math.min(u,v)..':'..math.max(u,v)
  local edge=edges[key]
  if not edge then edges[key]={a=u,b=v,face=index,count=1}
  else
   assert(edge.a==v and edge.b==u,'Inconsistent face winding')
   edge.count+=1;table.insert(links[index],edge.face);table.insert(links[edge.face],index)
  end
 end
end
for _,edge in pairs(edges) do assert(edge.count==2,'Open or nonmanifold crystal edge') end
assert(signedVolume>.18 and signedVolume<.20,'Lost authored crystal silhouette/volume')
local seen={};local components=0
for index in ipairs(G.triangles) do if not seen[index] then
 components+=1;local queue={index};seen[index]=true
 while #queue>0 do
  for _,other in ipairs(links[table.remove(queue)]) do
   if not seen[other] then seen[other]=true;table.insert(queue,other) end
  end
 end
end end
assert(components==1 and components==G.closedComponents)
for vertex in ipairs(G.vertices) do
 local ring={}
 for _,face in ipairs(G.triangles) do
  local slot=table.find(face,vertex)
  if slot then
   local a,b=face[slot%3+1],face[(slot+1)%3+1]
   ring[a]=ring[a] or {};ring[b]=ring[b] or {}
   ring[a][b]=true;ring[b][a]=true
  end
 end
 local count=0;local start
 for v,neighbors in pairs(ring) do
  count+=1;start=v;local degree=0;for _ in pairs(neighbors) do degree+=1 end
  assert(degree==2,'Nonmanifold vertex link')
 end
 local visited={};local queue={start};local reached=0
 while #queue>0 do
  local v=table.remove(queue)
  if not visited[v] then
   visited[v]=true;reached+=1
   for other in pairs(ring[v]) do table.insert(queue,other) end
  end
 end
 assert(reached==count,'Two shells pinch together at a vertex')
end
print('PASS real original crystal data: exact bounds, '..#G.vertices..' vertices / '..#G.triangles..' valid triangles, closed wound surface, safe point separation and manifold vertex fans; not Studio visual proof')
