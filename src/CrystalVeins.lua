-- Hollow the original rock, then cut a hairline opening through its shell.
-- The glowing geometry is a single inner mineral, never strips on the surface.
local V={}
function V.carve(source)
 local world=Instance.new('WorldModel');world.Name='CrystalCoreQuery'
 local probe=source:Clone();probe.CanQuery=true;probe.CanCollide=false;probe.CanTouch=false;probe.Transparency=1;probe.Parent=world
 world.Parent=workspace;task.wait()
 local size,frame=probe.Size,probe.CFrame
 local cutters,paths={},{}
 local seed=29
 for i=1,#source.Name do seed=(seed*7+source.Name:byte(i))%1000000 end
 local random=Random.new(seed)
 local cavity=source:Clone()
 cavity.Size=source.Size*Vector3.new(.76,.85,.76)
 cavity.CFrame+=source.ExtentsCFrame.Position-cavity.ExtentsCFrame.Position
 cutters[#cutters+1]=cavity
 for side=1,2 do
  local normal=Vector3.new(0,0,side==1 and 1 or -1)
  local path={}
  local drift=random:NextNumber(-.09,.03)
  for i=1,6 do
   local y=(-.24+(i-1)*.095)*size.Y
   drift=math.clamp(drift+random:NextNumber(-.10,.11),-.16,.16)
   local point=Vector3.new(drift*size.X,y,normal.Z*size.Z*1.4)
   local hit=world:Raycast(frame:PointToWorldSpace(point),frame:VectorToWorldSpace(-normal*size.Magnitude*2))
   if hit then path[#path+1]={point=hit.Position,normal=frame:VectorToWorldSpace(normal)} end
  end
  if #path>=4 then
   local width=math.min(size.X,size.Z)*.017
   for i=1,#path-1 do
    local a,b=path[i],path[i+1]
    local tangent=(b.point-a.point).Unit
    local across=tangent:Cross(a.normal).Unit
    local n=across:Cross(tangent).Unit
    local cutter=Instance.new('Part');cutter.Anchored=true
    cutter.Size=Vector3.new(width*((i==1 or i==#path-1) and .42 or i%2==0 and .7 or 1),(b.point-a.point).Magnitude+width,size.Z*.8)
    cutter.CFrame=CFrame.fromMatrix((a.point+b.point)*.5-a.normal*size.Z*.32,across,tangent,n)
    cutters[#cutters+1]=cutter
   end
   paths[#paths+1]={points=path,width=width}
  end
 end
 probe.Parent=nil;world:Destroy()
 if #paths==0 then probe:Destroy();cavity:Destroy();return source end
 local ok,parts=pcall(function()
  return game:GetService('GeometryService'):SubtractAsync(probe,cutters,{
   CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition,
   RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=false,
  })
 end)
 probe:Destroy();for _,p in ipairs(cutters) do p:Destroy() end
 if not ok or #parts~=1 then
  if ok then for _,p in ipairs(parts) do p:Destroy() end end
  return source
 end
 local result=parts[1]
 result.Name=source.Name;result.Anchored=true;result.CanCollide=false;result.CanTouch=false;result.CanQuery=false
 result.Material=source.Material;result.Color=source.Color;result.Reflectance=0;result.Transparency=source.Transparency
 if result:IsA('PartOperation') then result.UsePartColor=true end
 for k,v in pairs(source:GetAttributes()) do result:SetAttribute(k,v) end
 local encoded={}
 for _,path in ipairs(paths) do
  local points={}
  for _,p in ipairs(path.points) do
   local position=result.CFrame:PointToObjectSpace(p.point)/result.Size
   local n=result.CFrame:VectorToObjectSpace(p.normal)
   points[#points+1]={position.X,position.Y,position.Z,n.X,n.Y,n.Z}
  end
  encoded[#encoded+1]={points=points,width=path.width/math.min(result.Size.X,result.Size.Z)}
 end
 result:SetAttribute('CoreFissures',game:GetService('HttpService'):JSONEncode(encoded))
 result:SetAttribute('InsetVeins',nil)
 local center=source.ExtentsCFrame.Position
 source.Size*=Vector3.new(.65,.73,.65)
 source.CFrame+=center-source.ExtentsCFrame.Position
 source.Name='CoreGeometry';source.Material=Enum.Material.Neon;source.Transparency=1
 source.CanCollide=false;source.CanTouch=false;source.CanQuery=false;source.CastShadow=false
 source:SetAttribute('SizeRatio',source.Size/result.Size)
 source:SetAttribute('CenterRatio',result.CFrame:PointToObjectSpace(source.Position)/result.Size)
 source:SetAttribute('RelativeRotation',result.CFrame:ToObjectSpace(source.CFrame).Rotation)
 source.Parent=result
 return result
end
return V
