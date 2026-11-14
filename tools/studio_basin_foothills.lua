assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game:GetService('RunService'):IsEdit())
local map=workspace.MiningAway.Map;local mat=game.MaterialService;local v=Vector3.new;local rgb=Color3.fromRGB
assert(not map:FindFirstChild('QuarryBasinFoothills'))
local root=Instance.new('Folder');root.Name='QuarryBasinFoothills'
local grass=mat.QuarryRestoredTurf_Grass;local stone=mat.QuarryColorStone_Slate
local edits={parts={},properties={}};local handles={};local protected={}
local ray=RaycastParams.new();ray.RespectCanCollide=true
-- Record protected surfaces in the actual Edit map before any geometry changes.
for _,field in ipairs(workspace.MiningAway.Fields:GetChildren()) do
 local p=field.Field
 for ix=-2,2 do for iz=-2,2 do local point=p.CFrame*v(p.Size.X*.21*ix,p.Size.Y/2+2,p.Size.Z*.21*iz);local h=workspace:Raycast(point,v(0,-6,0),ray);assert(h);table.insert(protected,{point=point,y=h.Position.Y}) end end
end
for _,p in ipairs(map.DronerevolutionTerraces.WalkableRoutes:GetChildren()) do if p:IsA('BasePart') then
 for i=0,10 do local pt=p.CFrame*v(0,p.Size.Y/2+2,p.Size.Z*(i/10-.5));local h=workspace:Raycast(pt,v(0,-7,0),ray);if h then table.insert(protected,{point=pt,y=h.Position.Y}) end end
end end
local function block(parent,name,size,cf,finish,tint,cls)
 local p=Instance.new(cls or 'Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.Material=finish.BaseMaterial;p.MaterialVariant=finish.Name;p.Color=tint;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local plateauTops={}
-- Frame local +Z runs uphill toward the rim; native wedges are solid below the incline.
local function foothill(name,front,y,width,ramp,depth,rise,yaw,tint)
 local group=Instance.new('Folder');group.Name=name
 local f=CFrame.new(front.X,y,front.Z)*CFrame.Angles(0,math.rad(yaw),0)
 local total=ramp+depth
 block(group,'GroundConnection',v(width,y+10,total),f*CFrame.new(0,-(y+10)/2,total/2),stone,rgb(170,155,129))
 block(group,'GrassySlope',v(width,rise,ramp),f*CFrame.new(0,rise/2,ramp/2),grass,tint,'WedgePart')
 block(group,'RaisedPlateau',v(width,rise,depth),f*CFrame.new(0,rise/2,ramp+depth/2),grass,tint)
 table.insert(plateauTops,{group=group,cf=f*CFrame.new(0,rise,ramp+depth/2),width=width,depth=depth})
 group.Parent=root
end
-- Outer grass reaches the wall feet without crossing existing field approaches.
foothill('QuartzWestLower',v(-175,0,112),3.975,68,32,22,14,-90,rgb(157,190,118))
foothill('QuartzWestUpper',v(-175,0,171),3.975,50,24,30,14,-90,rgb(171,198,115))
foothill('RubyWestShoulder',v(-198,0,-47),19.975,96,25,18,19,-90,rgb(157,191,119))
foothill('VioletNorthShelf',v(-101,0,-162),37.975,70,32,28,15,180,rgb(164,190,128))
foothill('VioletWestRise',v(-184,0,-134),37.975,38,25,16,12,-90,rgb(153,189,117))
foothill('EmeraldNorthShelf',v(106,0,-183),41.975,80,25,22,13,180,rgb(152,194,127))
foothill('EmeraldEastRise',v(204,0,-165),41.975,36,24,16,12,90,rgb(150,196,132))
foothill('ImpactEastLower',v(198,0,104),3.975,48,18,32,10,90,rgb(169,193,113))
foothill('ImpactEastUpper',v(169,0,159),3.975,56,35,24,25,90,rgb(161,188,110))
-- Shallow rear mounds reach up from the existing south shelves into the basin rim.
foothill('QuartzSouthMound',v(-100,0,211),3.975,52,12,27,5,0,rgb(177,197,116))
foothill('ImpactSouthMound',v(117,0,211),3.975,52,14,26,6,0,rgb(173,195,117))
local function vec(a)return {a.X,a.Y,a.Z}end
local caps=Instance.new('Folder');caps.Name='GrassRim';caps.Parent=root
local index=0
for _,section in ipairs(map.QuarryBlockRim:GetChildren()) do
 for _,p in ipairs(section:GetChildren()) do if p.Name=='BasalRock' then
  index+=1
  local oldTop=p.Position.Y+p.Size.Y/2;local bottom=p.Position.Y-p.Size.Y/2
  local minTop=section.Name=='NorthCrown' and 59 or (p.Position.Z<0 and 52 or 37)
  local cut=({4,12,7,17,5})[index%5+1]
  local top=math.min(oldTop,math.max(minTop,oldTop-cut))
  if top<oldTop-.01 then
   local newSize=v(p.Size.X,top-bottom,p.Size.Z);local pos=v(p.Position.X,(top+bottom)/2,p.Position.Z)
   table.insert(edits.parts,{path=p:GetFullName(),class='Part',anchor=vec(p.Position),before={position=vec(p.Position),size=vec(p.Size)},after={position=vec(pos),size=vec(newSize)}})
   table.insert(handles,{p,p.CFrame,p.Size,pos,newSize})
  end
  local cf=CFrame.new(p.Position.X,top+.2,p.Position.Z)*p.CFrame.Rotation
  block(caps,'GrassCrown',v(p.Size.X,.4,p.Size.Z),cf,grass,rgb(156+(index%3)*8,188+(index%4)*5,109+(index%3)*5))
 end end
end
-- Use existing foliage on the new upper shelves, anchored to their actual top.
local template=map.QuarryContinuousGround.OriginalDetails.Quartz:FindFirstChild('01_Tree1')
for i,s in ipairs(plateauTops) do
 for j=1,2 do
  local tree=template:Clone();tree.Name='ShelfTree';tree:ScaleTo(tree:GetScale()*(j==1 and .64 or .45))
  local b,sz=tree:GetBoundingBox();local target=(s.cf*v((j==1 and -.24 or .25)*s.width,0,(j==1 and -.12 or .14)*s.depth))
  tree:PivotTo(tree:GetPivot()+v(target.X-b.X,target.Y-(b.Y-sz.Y/2),target.Z-b.Z))
  for _,p in ipairs(tree:GetDescendants()) do if p:IsA('BasePart') then p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false end end
  tree.Parent=s.group
 end
 task.wait()
end
local function verify()
 for _,sample in ipairs(protected) do local h=workspace:Raycast(sample.point,v(0,-7,0),ray);assert(h and math.abs(h.Position.Y-sample.y)<.05,'Protected ground changed') end
 local slopes=0
 for _,p in ipairs(root:GetDescendants()) do if p:IsA('WedgePart') and p.Name=='GrassySlope' then
  for _,z in ipairs({-.35,0,.35}) do local q=p.CFrame*v(0,p.Size.Y+2,p.Size.Z*z);local hit=workspace:Raycast(q,v(0,-p.Size.Y*3-5,0),ray);assert(hit and hit.Instance==p and hit.Normal.Y>.70,'Unwalkable slope '..p.Parent.Name..' '..tostring(z)..' '..(hit and hit.Instance:GetFullName() or 'no hit')) end;slopes+=1
 end end
 return {protectedSamples=#protected,slopes=slopes,wallSectionsLowered=#edits.parts,grassCaps=index}
end
shared.BasinFoothills={apply=function()
 for _,h in ipairs(handles) do h[1].Position=h[4];h[1].Size=h[5] end
 root.Parent=map
 local ok,result=pcall(verify)
 if not ok then root.Parent=nil;for _,h in ipairs(handles) do h[1].CFrame=h[2];h[1].Size=h[3] end;error(result) end
 return result
end}
local se,en=game:GetService('SerializationService'),game:GetService('EncodingService')
shared.BasinFoothillsSnapshot={scenery=buffer.tostring(en:Base64Encode(en:CompressBuffer(se:SerializeInstancesAsync({root}),Enum.CompressionAlgorithm.Zstd))),edits=game.HttpService:JSONEncode(edits)}
return {sceneryBytes=#shared.BasinFoothillsSnapshot.scenery,editsBytes=#shared.BasinFoothillsSnapshot.edits}
