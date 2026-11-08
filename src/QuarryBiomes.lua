-- Biome dressing grows out from the existing mining patches and routes.
local Biomes={}
local rgb=Color3.fromRGB
local ivory=rgb(249,239,207)
local cool={rgb(65,108,183),rgb(105,158,226),rgb(166,222,252)}
local coral={rgb(154,61,77),rgb(221,102,117),rgb(251,172,142)}

local function glow(part,color,range,brightness)
 local lamp=Instance.new('PointLight');lamp.Name='LocalGlow';lamp.Color=color
 lamp.Range=range;lamp.Brightness=brightness;lamp.Shadows=false;lamp.Parent=part
end

local function block(parent,name,frame,size,color,variant)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true
 p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.CFrame=frame;p.Size=size;p.Color=color;p.Material=Enum.Material.Slate
 p.MaterialVariant=variant or 'QuarryBiome_Chalk'
 local definition=game:GetService('MaterialService'):FindFirstChild(p.MaterialVariant)
 if definition and definition:IsA('MaterialVariant') then p.Material=definition.BaseMaterial end
 p.Parent=parent
 return p
end

local function cosmetic(part)
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
 part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
end

local function cylinder(parent,name,frame,size,color,material,variant)
 local part=Instance.new('Part');part.Name=name;part.Shape=Enum.PartType.Cylinder
 cosmetic(part)
 part.Size=size;part.CFrame=frame;part.Color=color;part.Material=material
 if variant then part.MaterialVariant=variant end
 part.Parent=parent
 return part
end

local function segment(parent,name,a,b,width,color,material,variant)
 local center=(a+b)*.5
 local frame=CFrame.lookAt(center,b)*CFrame.Angles(0,math.pi*.5,0)
 return cylinder(parent,name,frame,Vector3.new((b-a).Magnitude+.06,width,width),color,material,variant)
end

local function capFacet(part)
 cosmetic(part);part.Name='CapMembrane';part.Material=Enum.Material.Slate
 part.MaterialVariant='QuarryBiome_Chalk'
end

local function mushroom(parent,ground,height,radius,lean,palette,index)
 local tree=Instance.new('Model');tree.Name=palette==cool and 'Blue Trumpet' or 'Coral Fan';tree.Parent=parent
 tree:SetAttribute('BiomeLandmark',true)
 local function stalk(t)
  return ground+Vector3.yAxis*(height*.77*t)+lean*(t*t)
 end
 local stemRings={};local segments=height>25 and 7 or 5
 for k=0,segments do
  local t=k/segments;local ring={}
  local width=radius*(.085+.09*(1-t)^3+.055*t^5)
  for j=1,8 do
   local a=(j-1)*math.pi*.25
   ring[j]=stalk(t)+Vector3.new(math.cos(a),0,math.sin(a))*width*(1+.065*math.sin(j*2.1+index))
  end
  stemRings[k+1]=ring
 end
 local function stemFinish(part)
  cosmetic(part);part.Name='CurvedFibrousStem';part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk'
 end
 for k=1,segments do
  local t=k/segments
  for j=1,8 do
   local next=j%8+1
   local tint=ivory:Lerp(palette[2],t*t*.65):Lerp(palette[1],(j%3)*.026)
   Facets.triangle(tree,stemRings[k][j],stemRings[k+1][j],stemRings[k+1][next],tint,stemFinish)
   Facets.triangle(tree,stemRings[k][j],stemRings[k+1][next],stemRings[k][next],tint,stemFinish)
  end
 end
 -- Buttresses give the trunk weight where it meets the ground.
 for i=1,index>50 and 0 or 5 do
  local a=i*math.pi*.4+index
  segment(tree,'StemButtress',ground+Vector3.new(math.cos(a),0,math.sin(a))*radius*.24,
   stalk(.22),radius*.09,ivory,Enum.Material.Slate,'QuarryBiome_Chalk')
 end
 local n=height>34 and 16 or 12
 local neck=stalk(1);local rings={{},{},{}};local tops={{},{},{}}
 for i=1,n do
  local a=(i-1)*2*math.pi/n
  local wave=math.sin(3*a+index*.61)*.7+math.sin(5*a+index)*.3
  local fan=palette==coral and (.87+.18*math.cos(a-index)) or 1
  local radial=Vector3.new(math.cos(a),0,math.sin(a))
  local reach=radius*(fan+wave*.075)
  rings[1][i]=neck+radial*radius*.14
  rings[2][i]=neck+radial*reach*.48+Vector3.yAxis*height*.135+lean*.09
  rings[3][i]=neck+radial*reach+Vector3.yAxis*height*(.19+.025*wave)+lean*.17
  for k=1,3 do tops[k][i]=rings[k][i]+Vector3.yAxis*(k==3 and .7 or 1.1) end
 end
 for i=1,n do
  local j=i%n+1
  local shade=palette[1]:Lerp(palette[2],.34+.15*math.sin(i*1.3+index))
  for k=1,2 do
   Facets.triangle(tree,rings[k][i],rings[k+1][i],rings[k+1][j],shade,capFacet)
   Facets.triangle(tree,rings[k][i],rings[k+1][j],rings[k][j],shade,capFacet)
   local upper=palette[2]:Lerp(palette[3],.10+.06*(i%3))
   Facets.triangle(tree,tops[k][i],tops[k+1][j],tops[k+1][i],upper,capFacet)
   Facets.triangle(tree,tops[k][i],tops[k][j],tops[k+1][j],upper,capFacet)
  end
  Facets.triangle(tree,rings[3][i],tops[3][i],tops[3][j],ivory,capFacet)
  Facets.triangle(tree,rings[3][i],tops[3][j],rings[3][j],ivory,capFacet)
  -- Continuous ribbed undersides replace the disconnected white dashes.
  for k=1,2 do
   local rib=segment(tree,'RadialGill',rings[k][i]-Vector3.yAxis*.24,rings[k+1][i]-Vector3.yAxis*.24,
    radius*.018,palette[1]:Lerp(ivory,.21),Enum.Material.Slate,'QuarryBiome_Chalk')
   if i%5==1 then
    local a=rings[k][i]:Lerp(rings[k+1][i],.18)-Vector3.yAxis*.36
    local b=rings[k][i]:Lerp(rings[k+1][i],.91)-Vector3.yAxis*.36
    local glowRib=segment(tree,'BioluminescentGill',a,b,radius*.009,palette[3],Enum.Material.Neon)
    glowRib.CastShadow=false
    if k==1 and i==1 then glow(glowRib,palette[3],math.min(36,height*.65),1.5) end
   end
  end
 end
 -- Coral shelves branch from the same curved stalk, as in the canyon reference.
 if palette==coral and height>25 and index<50 then
  mushroom(tree,stalk(.35),height*.51,radius*.46,Vector3.new(8,0,4),palette,index+60)
  mushroom(tree,stalk(.65),height*.31,radius*.34,Vector3.new(-6,0,-3),palette,index+80)
 end
end

local function turfSampler(terraces,center)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={terraces};params.RespectCanCollide=true
 return function(x,z)
  local point=center+Vector3.new(x,110,z)
  local hit=workspace:Raycast(point,Vector3.new(0,-155,0),params)
  if hit and hit.Instance.Name=='Turf' then return hit.Position end
 end
end

local function patchEdge(part,bed)
 local p=part.Position-bed.Position
 return math.max(0,math.abs(p.X)-bed.Size.X*.5,math.abs(p.Z)-bed.Size.Z*.5),p.Y
end

local function cobalt(biome,bed,terraces,ground)
 -- A dominant crown and two supporting silhouettes frame the open mining floor.
 for i,spec in ipairs({
  {39,10,58,25,Vector3.new(-10,0,-5),cool},
  {18,-41,44,21,Vector3.new(5,0,5),cool},
  {-20,38,35,17,Vector3.new(-8,0,-5),coral},
  {34,39,18,9,Vector3.new(-4,0,2),coral},
  {-39,25,12,6,Vector3.new(2,0,1),cool},
 }) do
  local pos=ground(spec[1],spec[2]);if pos then mushroom(biome,pos,spec[3],spec[4],spec[5],spec[6],i) end
 end
 for _,part in ipairs(terraces:GetDescendants()) do
  if part:IsA('BasePart') then
   local edge,y=patchEdge(part,bed)
   if edge<26 and y>-25 and y<7 then
    if part.MaterialVariant=='QuarryPhoto_Grass' and edge<15 then
     part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk'
     part.Color=rgb(201,222,194):Lerp(rgb(139,183,166),math.clamp(edge/26,0,1))
    elseif part.MaterialVariant=='QuarryPhoto_Rock' or part.MaterialVariant=='QuarryPhoto_Sandstone' then
     part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Shale';part.Color=rgb(167,185,213)
    end
   end
  end
 end
 bed.Material=Enum.Material.Slate;bed.MaterialVariant='QuarryBiome_Shale';bed.Color=rgb(141,164,196)
end

local function spire(parent,base,width,height,lean,tint,variant)
 -- Offset vertical stone plates make broken cliffs with readable ledges and fissures.
 local group=Instance.new('Model');group.Name='FracturedCliff';group.Parent=parent
 for i=1,5 do
  local offset=(i-3)*width*.38
  local h=height*({.59,.84,1,.76,.46})[i]
  local at=base+Vector3.new(offset,h*.5,-math.abs(i-3)*width*.20)+lean*(h/height)*.4
  local p=block(group,'SplitRockFace',CFrame.new(at)*CFrame.Angles(.025*(i-3),.13*(i-2),-.035*(i-3)),
   Vector3.new(width*(.38+.05*(i%2)),h,width*(.74+.11*(i%3))),tint:Lerp(rgb(105,132,158),.06*(i%3)),variant)
  local crown=Instance.new('WedgePart');crown.Name='JaggedCrown';cosmetic(crown)
  crown.Size=Vector3.new(p.Size.Z*.99,height*(.12+.025*(i%3)),p.Size.X*1.02)
  crown.CFrame=p.CFrame*CFrame.new(0,h*.5+crown.Size.Y*.5-.15,0)*CFrame.Angles(0,i%2==0 and math.pi*.5 or -math.pi*.5,0)
  crown.Color=tint;crown.Material=Enum.Material.Slate;crown.MaterialVariant=variant;crown.Parent=group
 end
 return base+Vector3.yAxis*height+lean*.4
end

local function ruby(biome,bed,terraces,ground)
 for _,part in ipairs(terraces:GetDescendants()) do
  if not part:IsA('BasePart') then continue end
  local edge,y=patchEdge(part,bed)
  if edge>27 or y>5 or y< -25 then continue end
  local noise=math.noise(part.Position.X*.058,part.Position.Z*.058)
  if part.MaterialVariant=='QuarryPhoto_Grass' and (edge<9 or noise>edge/55-.28) then
   part.MaterialVariant='QuarryBiome_Crimson';part.Color=rgb(248,237,221):Lerp(rgb(221,215,204),math.clamp(.5+noise,0,1))
  elseif (part.MaterialVariant=='QuarryPhoto_Sandstone' or part.MaterialVariant=='QuarryPhoto_Rock' or (part.Name=='RubyEdgeWeathering' and part.MaterialVariant=='QuarryPhoto_Pebble')) and edge<18 then
   part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Shale'
   part.Color=rgb(174,195,223):Lerp(rgb(116,132,156),math.clamp(.45+noise,0,1))
  end
 end
 bed.Material=Enum.Material.Slate;bed.MaterialVariant='QuarryBiome_Shale';bed.Color=rgb(149,163,185)
 for _,spec in ipairs({{-39,10,13,43,-4},{-38,-16,11,57,-3},{-34,-34,8,32,-2},{-17,38,6,18,2},{17,39,4,11,1}}) do
  local p=ground(spec[1],spec[2])
  if p then
   spire(biome,p,spec[3],spec[4],Vector3.new(spec[5],0,-1),rgb(208,220,240),'QuarryBiome_Shale')
   local seam=p+Vector3.new(spec[3]*.64,1.3,0)
   local vein=segment(biome,'RubyVein',seam,seam+Vector3.new(-.45,spec[4]*.21,-.4),.34,rgb(255,117,134),Enum.Material.Neon)
   vein.CastShadow=false;glow(vein,rgb(255,103,122),16,1.7)
  end
 end
end

-- Build a real water body and its shore in the open space alongside a patch.
-- Keep the voxel edit bounded and retain any pre-existing occupied cells.
local function basin(terrain,center,rx,rz,depth,minCorner,maxCorner)
 local region=Region3.new(minCorner,maxCorner):ExpandToGrid(4)
 local channels=terrain:ReadVoxelChannels(region,4,{'SolidMaterial','SolidOccupancy','LiquidOccupancy'})
 local materials,solid,water=channels.SolidMaterial,channels.SolidOccupancy,channels.LiquidOccupancy
 local origin=region.CFrame.Position-region.Size*.5
 local salt,sand,grass=Enum.Material.Salt,Enum.Material.Sand,Enum.Material.Ground
 local function profile(x,z)
  local dx,dz=x-center.X,z-center.Z
  local angle=math.atan2(dz/rz,dx/rx)
  local r=math.sqrt((dx/rx)^2+(dz/rz)^2)+.067*math.cos(angle*3+.65)+.044*math.sin(angle*5)
  local t=math.clamp((r-.39)/.46,0,1)
  t=t*t*(3-2*t)
  local top=center.Y-depth+(depth+4.6)*t+1.45*math.noise(x*.07,z*.07)
  local bottom=center.Y-8-13*math.sqrt(math.max(0,1-r))
  return r,top,bottom
 end
 for ix,column in ipairs(solid) do
  local x=origin.X+(ix-.5)*4
  for iz=1,#column[1] do
   local z=origin.Z+(iz-.5)*4
   local r,top,bottom=profile(x,z)
   if r>=1 then continue end
   local lip=math.clamp((1-r)*13,0,1)
   for iy,row in ipairs(column) do
    local y=origin.Y+(iy-.5)*4
    if row[iz]>0 or water[ix][iy][iz]>0 or y<bottom-2 then continue end
    local density=math.clamp((top-y)/4+.5,0,lip)
    if density>0 then
     row[iz]=density
     local green=top>center.Y+1.5 and math.noise(x*.071,z*.077)+.17*math.sin(z*.083)>-.15
     if green and y>top-3.2 then materials[ix][iy][iz]=grass
     elseif y<top-8 then materials[ix][iy][iz]=Enum.Material.Sandstone
     else materials[ix][iy][iz]=y>top-3 and top<center.Y+1 and sand or salt end
    end
    if r<.83 then
     local level=math.clamp((center.Y-y)/4+.5,0,1)
     water[ix][iy][iz]=math.max(0,math.min(1-density,level))
    end
   end
  end
 end
 terrain:WriteVoxelChannels(region,4,{SolidMaterial=materials,SolidOccupancy=solid,LiquidOccupancy=water})
 return profile
end

local function rockMass(parent,base,width,depth,height,turn,seed)
 local group=Instance.new('Model');group.Name='WeatheredWhiteCliff';group.Parent=parent
 local basis=CFrame.new(base)*CFrame.Angles(0,turn,0)
 -- Broad planar faces and stepped fractures, with no rounded cone silhouette.
 for i=1,4 do
  local h=height*({.72,1,.89,.56})[i]
  local x=(i-2.5)*width*.49
  local tint=rgb(246,247,229):Lerp(rgb(157,190,203),.035+((i+seed)%3)*.055)
  local slab=block(group,'ChalkSlab',basis*CFrame.new(x,h*.5,(i%2)*depth*.14)*CFrame.Angles(.018*(i-2),.035*(i-2),.045*(i-2)),
   Vector3.new(width*.57,h,depth*(.9+.11*(i%2))),tint,'QuarryBiome_Chalk')
  if h>12 then
   block(group,'ChalkLedge',slab.CFrame*CFrame.new(0,h*.15,-depth*.10)*CFrame.Angles(0,.06,-.06),
    Vector3.new(width*.63,height*.09,depth*1.05),tint:Lerp(ivory,.2),'QuarryBiome_Chalk')
   block(group,'BrokenSummit',slab.CFrame*CFrame.new(0,h*.48,0)*CFrame.Angles(.12,0,-.10),
    Vector3.new(width*.59,height*.075,depth*.89),tint,'QuarryBiome_Chalk')
  end
 end
 return basis:PointToWorldSpace(Vector3.new(-width*.25,height+.1,0))
end

local function foliage(parent,base,scale,seed)
 -- Layered leaf planes keep a leafy silhouette instead of spherical clusters.
 for i=1,7 do
  local angle=(i-1)*2.4+seed
  local reach=(i%3)*1.05*scale
  local size=Vector3.new(3.4+(i%2)*.7,.75+(i%3)*.16,2.8)*scale
  local at=base+Vector3.new(math.cos(angle)*reach,(i%3)*.36,math.sin(angle)*reach)
  block(parent,'LeafyShelf',CFrame.new(at)*CFrame.Angles(.07*math.sin(i),angle,.14*math.cos(i)),size,
   rgb(213,244,171):Lerp(rgb(124,203,142),.14*(i%4)),'QuarryFoliage_Canopy')
 end
end

local function causeway(parent,origin)
 -- A complete narrow crossing, leading through the water to the far overlook.
 for i=0,30 do
  local t=i/30
  local bend=math.sin(t*math.pi)*4.2
  local at=origin+Vector3.new(i*3.18,.45+math.sin(t*math.pi)*1.3-.9*t^5,bend)
  local p=block(parent,'LagoonCauseway',CFrame.new(at)*CFrame.Angles(0,.045*math.cos(t*math.pi),0),
   Vector3.new(3.27,.95,7.8),ivory:Lerp(rgb(171,205,198),.06*(i%3)),'QuarryBiome_Chalk')
  p.CanCollide=true;p.CanQuery=true;p:SetAttribute('WalkRoute',true)
  if i%4==0 then
   block(parent,'BridgePier',CFrame.new(at+Vector3.new(0,-6.5,0)),Vector3.new(2.5,12,5.5),rgb(204,222,218),'QuarryBiome_Chalk')
  end
  if i>2 and i<29 and i%3~=0 then
   block(parent,'LowParapet',CFrame.new(at+Vector3.new(0,.9,3.65)),Vector3.new(3.24,1.5,.65),ivory,'QuarryBiome_Chalk')
  end
 end
end

local function shoreTree(parent,base,h,lean,index)
 local top=base+lean+Vector3.yAxis*h
 local fork=base+lean*.55+Vector3.yAxis*(h*.64)
 local bark=rgb(220,212,176)
 segment(parent,'WindBentTrunk',base-Vector3.yAxis*.18,fork,h*.11,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
 segment(parent,'WindBentTrunk',fork,top,h*.073,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
 foliage(parent,top,h*.15,index)
 for i=1,3 do
  local theta=i*2.4+index
  local endPoint=fork+Vector3.new(math.cos(theta)*h*.30,h*(.16+i*.04),math.sin(theta)*h*.26)
  segment(parent,'WindBentBranch',fork,endPoint,h*.045,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
  foliage(parent,endPoint,h*.10,i+index)
 end
end

local function lagoon(parent,bed)
 local terrain=workspace.Terrain
 local center=bed.Position+Vector3.new(95,-5,0)
 local profile=basin(terrain,center,49,39,7,bed.Position+Vector3.new(48,-34,-44),center+Vector3.new(54,13,44))
 causeway(parent,bed.Position+Vector3.new(40,.55,0))
 -- One large broken cliff dominates the far bank. Lower shelves overlap it,
 -- and open water is held between the foreground crossing and the stone wall.
 for i,s in ipairs({{29,-23,12,9,60},{39,-14,9,8,44},{15,-28,8,7,30},
  {35,20,8,7,34},{42,7,5,6,21},{10,31,7,5,8},{-9,29,5,4,5},
  {-28,18,5,5,4},{11,-17,4,3,5}}) do
  local x,z=center.X+s[1],center.Z+s[2];local _,y=profile(x,z)
  local base=Vector3.new(x,y-1.1,z)
  local peak=rockMass(parent,base,s[3],s[4],s[5],-.12+i*.16,i)
  foliage(parent,peak, i<=4 and 2.15 or 1.4,i)
  if i<=4 then
   foliage(parent,base+Vector3.new(-s[3]*.5,s[5]*.64,-s[4]*.45),1.65,i+7)
   foliage(parent,base+Vector3.new(s[3]*.45,s[5]*.31,s[4]*.45),1.3,i+12)
  end
 end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={terrain};params.IgnoreWater=true
 for i,s in ipairs({{-34,19,10},{-31,-22,12},{-20,-29,10},{-7,-32,0},{7,32,0},{24,27,12},{30,-25,0}}) do
  local x,z=center.X+s[1],center.Z+s[2];local r,expected=profile(x,z)
  local hit=workspace:Raycast(Vector3.new(x,center.Y+24,z),Vector3.new(0,-36,0),params)
  local ground=hit and hit.Position or (r<.94 and Vector3.new(x,expected,z))
  if ground and ground.Y>center.Y+.15 then
   foliage(parent,ground+Vector3.yAxis*.25,1.5+.22*(i%3),i)
   if s[3]>0 then shoreTree(parent,ground,s[3],Vector3.new(2+i*.12,0,1.4),i) end
  end
 end
 -- Pale reeds and warm seed heads draw attention at the landing.
 for i=1,9 do
  local angle=i*2.4;local base=bed.Position+Vector3.new(46+math.cos(angle)*4,1.6,math.sin(angle)*6)
  local tip=base+Vector3.new(.3,2.2+(i%3)*.65,.15)
  segment(parent,'WaterReed',base,tip,.14,rgb(146,189,151),Enum.Material.Slate,'QuarryBiome_Chalk')
  local bulb=cylinder(parent,'ReedLight',CFrame.new(tip)*CFrame.Angles(0,0,math.pi*.5),Vector3.new(.8,.35,.35),rgb(255,222,131),Enum.Material.Neon)
  if i==1 then glow(bulb,rgb(255,221,148),18,1.5) end
 end
end

local function emerald(biome,bed,terraces)
 bed.Material=Enum.Material.Slate;bed.MaterialVariant='QuarryBiome_Chalk';bed.Color=rgb(197,235,217)
 local routes=terraces:FindFirstChild('WalkableRoutes')
 if routes then
  for _,part in ipairs(routes:GetChildren()) do
   if part:IsA('BasePart') and part.Name:match('^Emerald') then
    part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk';part.Color=ivory
   end
  end
 end
 lagoon(biome,bed)
 for _,part in ipairs(terraces:GetDescendants()) do
  if not part:IsA('BasePart') then continue end
  local p=part.Position-bed.Position
  if p.Y<0 and p.Y> -28 and p.X>12 and p.X<54 and math.abs(p.Z)<39 and
   (part.MaterialVariant=='QuarryPhoto_Sandstone' or part.MaterialVariant=='QuarryPhoto_Rock') then
   part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk'
   part.Color=rgb(219,237,228):Lerp(rgb(148,180,195),math.clamp(.33+math.noise(p.X*.08,p.Z*.08),0,1))
  end
 end

end

local function lantern(parent,base,yaw,height)
 local warm=rgb(255,212,125)
 local basis=CFrame.new(base)*CFrame.Angles(0,yaw,0)
 local function piece(name,offset,size,tint,variant)
  return block(parent,name,basis*CFrame.new(offset),size,tint,variant)
 end
 local dark=rgb(66,82,83)
 piece('LampFoot',Vector3.new(0,.3,0),Vector3.new(1.5,.6,1.5),rgb(185,204,193))
 piece('LampPost',Vector3.new(0,height*.5,0),Vector3.new(.38,height,.38),dark,'QuarryPhoto_CorrodedMetal')
 piece('LampArm',Vector3.new(.8,height-.3,0),Vector3.new(2,.32,.4),dark,'QuarryPhoto_CorrodedMetal')
 piece('LampHood',Vector3.new(1.6,height-.65,0),Vector3.new(1.65,.34,1.55),dark,'QuarryPhoto_CorrodedMetal')
 local glass=piece('WarmLamp',Vector3.new(1.6,height-1.3,0),Vector3.new(.96,1.1,.96),warm)
 glass.Material=Enum.Material.Neon;glass.MaterialVariant='';glass.CastShadow=false
 piece('LampLowerRim',Vector3.new(1.6,height-1.88,0),Vector3.new(1.23,.18,1.23),dark,'QuarryPhoto_CorrodedMetal')
 glow(glass,warm,24,2.7)
end

local function lighting(scene,terraces)
 local lamps=Instance.new('Folder');lamps.Name='QuarryLanterns';lamps.Parent=scene.map
 for _,s in ipairs({{-17,4,17,0},{17,4,17,math.pi},{-42,4,-26,0},{42,4,-26,math.pi}}) do
  lantern(lamps,Vector3.new(s[1],s[2],s[3]),s[4],8.6)
 end
 local routes=terraces:FindFirstChild('WalkableRoutes')
 if routes then
  for _,route in ipairs(routes:GetChildren()) do
   if route:IsA('BasePart') and not route.Name:match('Curb$') then
    local at=route.CFrame:PointToWorldSpace(Vector3.new(route.Size.X*.5+.7,route.Size.Y*.5,-route.Size.Z*.28))
    local _,yaw=route.CFrame:ToOrientation()
    lantern(lamps,at,yaw+math.pi,7.4)
   end
  end
 end
end

local function patternedSurfaces(scene,terraces)
 -- Architectural patterns have limited, readable jobs. Mining beds keep their
 -- quieter geological surfaces, and the large hub pad remains plain.
 local materials=game:GetService('MaterialService')
 local herringbone=materials:FindFirstChild('QuarryPattern_Herringbone')
 local checker=materials:FindFirstChild('QuarryPattern_Checker')
 local square=terraces:FindFirstChild('MarketSquare')
 if square and herringbone then
  for _,name in ipairs({'NorthSouthWalk','EastWestWalk','UtilityWalk','ShopApron'}) do
   local part=square:FindFirstChild(name)
   if part and part:IsA('BasePart') then
    if not part.CustomPhysicalProperties then part.CustomPhysicalProperties=part.CurrentPhysicalProperties end
    part.Material=herringbone.BaseMaterial;part.MaterialVariant=herringbone.Name
    part.Color=rgb(190,205,240);part.Reflectance=0
   end
  end
 end
 local depot=scene.map:FindFirstChild('SimpleFlatTestMap')
 if depot and checker then
  for _,name in ipairs({'Printer','PackStation','PrestigeStation'}) do
   local assembly=depot:FindFirstChild(name..'Assembly')
   local pad=assembly and assembly:FindFirstChild(name..'Pad')
   if pad and pad:IsA('BasePart') then
    if not pad.CustomPhysicalProperties then pad.CustomPhysicalProperties=pad.CurrentPhysicalProperties end
    pad.Material=checker.BaseMaterial;pad.MaterialVariant=checker.Name
    pad.Color=rgb(233,234,216);pad.Reflectance=0
   end
  end
 end
end

function Biomes.build(scene,terraces)
 local fields=scene.root:FindFirstChild('Fields')
 if not fields then return end
 local terrain=workspace.Terrain
 terrain.WaterColor=rgb(35,139,154);terrain.WaterReflectance=.34
 terrain.WaterTransparency=.38;terrain.WaterWaveSize=.13;terrain.WaterWaveSpeed=5
 terrain:SetMaterialColor(Enum.Material.Salt,rgb(206,221,218))
 terrain:SetMaterialColor(Enum.Material.Sand,rgb(209,222,185))
 terrain:SetMaterialColor(Enum.Material.Ground,rgb(107,151,104))
 for _,spec in ipairs({{'Ruby','RubyCrimsonBluffs',ruby},{'Cobalt','CobaltMushroomGrove',cobalt},{'Emerald','EmeraldChalkLagoon',emerald}}) do
  local field=fields:FindFirstChild(spec[1])
  local bed=field and field:FindFirstChild('Field')
  if bed and bed:IsA('BasePart') then
   local biome=Instance.new('Folder');biome.Name=spec[2];biome.Parent=scene.map
   spec[3](biome,bed,terraces,turfSampler(terraces,bed.Position))
   task.wait()
  end
 end
 lighting(scene,terraces)
 patternedSurfaces(scene,terraces)
end
return Biomes
