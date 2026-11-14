-- Carve a narrow, jagged channel once per native crystal template. The shell
-- itself supplies the recessed walls; normalized anchors survive stage scaling.
local V={}
function V.carve(source)
 local world=Instance.new('WorldModel')
 local probe=source:Clone();probe.CanQuery=true;probe.CanCollide=false;probe.CanTouch=false;probe.Transparency=1;probe.Parent=world
 world.Name='CrystalVeinQuery';world.Parent=workspace
 task.wait() -- WorldModel spatial queries require an active world root.
 local size=probe.Size
 local frame=probe.CFrame
 local cutters,paths={},{}
 local seed=29
 for i=1,#source.Name do seed=seed*7+source.Name:byte(i);seed=seed%1000000 end
 local random=Random.new(seed)
 for side=1,2 do
  local normal=side==1 and Vector3.new(0,0,1) or Vector3.new(0,0,-1)
  local path={}
  local drift=random:NextNumber(-.16,.02)
  for i=1,9 do
   local y=(-.30+(i-1)*.063+random:NextNumber(-.012,.012))*size.Y
   drift=math.clamp(drift+random:NextNumber(-.08,.10),-.24,.24)
   local x=drift*size.X
   local point=Vector3.new(x,y,normal.Z*size.Z*1.4)
   local hit=world:Raycast(frame:PointToWorldSpace(point),frame:VectorToWorldSpace(-normal*size.Magnitude*2))
   if hit then path[#path+1]={point=hit.Position,normal=frame:VectorToWorldSpace(normal)} end
  end
  if #path>=4 then
   local width=math.min(size.X,size.Z)*.090
   local depth=math.min(size.X,size.Z)*.12
   for i=1,#path-1 do
    local a,b=path[i],path[i+1]
    local mid=(a.point+b.point)*.5
    local tangent=(b.point-a.point).Unit
    local across=tangent:Cross(a.normal).Unit
    local n=across:Cross(tangent).Unit
    local cutter=Instance.new('Part');cutter.Anchored=true
    cutter.Size=Vector3.new(width*(.72+.28*math.sin(i*1.7)^2),(b.point-a.point).Magnitude+width,depth*2)
    cutter.CFrame=CFrame.fromMatrix(mid,across,tangent,n)
    cutters[#cutters+1]=cutter
   end
   paths[#paths+1]={points=path,width=width,depth=depth}
  end
 end
 probe.Parent=nil;world:Destroy()
 if #cutters==0 then probe:Destroy();return source end
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
   local inset=p.point-p.normal*path.depth*.63
   local localPoint=result.CFrame:PointToObjectSpace(inset)/result.Size
   local n=result.CFrame:VectorToObjectSpace(p.normal)
   points[#points+1]={localPoint.X,localPoint.Y,localPoint.Z,n.X,n.Y,n.Z}
  end
  encoded[#encoded+1]={points=points,width=path.width/math.min(result.Size.X,result.Size.Z)}
 end
 result:SetAttribute('InsetVeins',game:GetService('HttpService'):JSONEncode(encoded))
 source:Destroy()
 return result
end
return V
