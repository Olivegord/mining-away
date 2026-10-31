-- A continuous low-poly hillside made entirely from anchored WedgeParts.
-- Each triangle splits across its longest edge into two exact right triangles.
local F={}
function F.triangle(parent: any,a: any,b: any,c: any,color: any)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
 elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local cross=ac:Cross(ab)
 if cross.Magnitude<.001 then return end
 local right=cross.Unit;local back=bc.Unit;local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 local function wedge(position,normal,axis,length)
  if length<.01 or height<.01 then return end
  local part=Instance.new('WedgePart');part.Name='GroundFacet';part.Anchored=true
  part.CanCollide=true;part.CanQuery=true;part.CanTouch=false
  part.Size=Vector3.new(.18,height+.04,length+.04);part.CFrame=CFrame.fromMatrix(position,normal,up,axis)
  part.Color=color;part.Material=Enum.Material.SmoothPlastic;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  part:SetAttribute('LandscapeSurface',true);part.Parent=parent
 end
 wedge((a+b)/2,right,back,math.abs(ab:Dot(back)))
 wedge((a+c)/2,-right,-back,math.abs(ac:Dot(back)))
end
return F

