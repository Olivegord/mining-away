-- Biome dressing grows out from the existing mining patches and routes.
local Biomes={}
local rgb=Color3.fromRGB
local ivory=rgb(249,239,207)
local cool={rgb(65,108,183),rgb(105,158,226),rgb(166,222,252)}
local coral={rgb(154,61,77),rgb(221,102,117),rgb(251,172,142)}

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
 local neck=ground+Vector3.yAxis*(height*.63)+lean*.46
 local previous=ground-Vector3.yAxis*.22
 for step=1,5 do
  local t=step/5
  local next=ground+Vector3.yAxis*(height*.63*t)+lean*(.46*t*t)
  local stem=segment(tree,'FibrousStem',previous,next,radius*(.18-.07*t),ivory:Lerp(palette[2],t*.48),Enum.Material.Concrete,'QuarryPhoto_Concrete')
  stem.CastShadow=true
  previous=next
 end
 local brim,shoulder,upper={},{},{}
 local n=height>20 and 14 or 10
 for i=1,n do
  local angle=(i-1)*2*math.pi/n
  local wave=math.sin(3*angle+index*.61)*.74+math.sin(5*angle+index)*.26
  local fan=palette==coral and (.88+.18*math.cos(angle-index)) or 1
  local reach=radius*(fan+wave*.10+math.cos(angle+index)*.06)
  local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
  shoulder[i]=neck+radial*(reach*.54)+Vector3.yAxis*(height*.225)+lean*.31
  brim[i]=neck+radial*(reach*.96)+Vector3.yAxis*(height*(.33+.043*wave))+lean*.54
  upper[i]=brim[i]+radial*(reach*.04)+Vector3.yAxis*(height*(.024+.009*wave))
 end
 for i=1,n do
  local j=i%n+1
  local shade=palette[1]:Lerp(palette[2],.47+.19*math.cos(i*1.9+index))
  Facets.triangle(tree,neck,shoulder[i],shoulder[j],shade,capFacet)
  Facets.triangle(tree,shoulder[i],brim[i],brim[j],shade:Lerp(palette[2],.32),capFacet)
  Facets.triangle(tree,shoulder[i],brim[j],shoulder[j],shade:Lerp(palette[2],.20),capFacet)
  Facets.triangle(tree,brim[i],upper[i],upper[j],ivory,capFacet)
  Facets.triangle(tree,brim[i],upper[j],brim[j],ivory,capFacet)
  Facets.triangle(tree,neck+Vector3.yAxis*(height*.09),upper[i],upper[j],shade:Lerp(palette[2],.38),capFacet)
  if i%5==1 then
   local a=shoulder[i]:Lerp(brim[i],.26)-Vector3.yAxis*.18
   local rib=segment(tree,'LuminousGill',a,shoulder[i]:Lerp(brim[i],.55)-Vector3.yAxis*.18,radius*.012,palette[3],Enum.Material.Neon)
   rib.CastShadow=false
   if height>24 and i==1 then
    local l=Instance.new('PointLight');l.Name='GillGlow';l.Color=palette[2];l.Brightness=.8;l.Range=15;l.Shadows=false;l.Parent=rib
   end
  end
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
 for i,spec in ipairs({
  {37,6,32,14,Vector3.new(8,0,-3),cool},
  {20,41,27,12,Vector3.new(4,0,7),cool},
  {-20,36,19,9,Vector3.new(-7,0,4),coral},
  {18,-42,24,10,Vector3.new(5,0,-5),cool},
  {-35,27,12,5.5,Vector3.new(-2,0,3),cool},
  {-45,22,8,3.7,Vector3.new(-1,0,1.8),coral},
 }) do
  local pos=ground(spec[1],spec[2]);if pos then mushroom(biome,pos,spec[3],spec[4],spec[5],spec[6],i) end
 end
 -- Carry the cooler ground into the approach, fading back into the original
 -- grass on the next ledges. Field ownership and rock placement stay on bed.
 for _,part in ipairs(terraces:GetDescendants()) do
  if part:IsA('BasePart') and part.MaterialVariant=='QuarryPhoto_Grass' then
   local edge,y=patchEdge(part,bed)
   if math.abs(y)<7 then
    local weight=.65*(1-math.clamp(edge/27,0,1))
    part.Color=part.Color:Lerp(rgb(122,225,249),weight)
   end
  end
 end
 bed.Color=rgb(177,211,247)
end

local function spire(parent,base,width,height,lean,tint,variant,column)
 local foot,crest={},{}
 local peak=base+Vector3.yAxis*height+lean
 for i=1,5 do
  local angle=(i-1)*2*math.pi/5
  local spoke=Vector3.new(math.cos(angle),0,math.sin(angle))
  foot[i]=base+spoke*(width*(.76+i*.055))
  local elevation=column and (.73+i*.032) or (.48+i*.054)
  local shoulder=column and (.59+i*.031) or (.42+i*.026)
  crest[i]=base+Vector3.yAxis*(height*elevation)+lean*.67+spoke*(width*shoulder)
 end
 local function finish(part)
  cosmetic(part);part.Name='CliffSpire';part.Material=Enum.Material.Slate;part.MaterialVariant=variant
 end
 for i=1,5 do
  local j=i%5+1
  local shade=tint:Lerp(rgb(122,152,169),i*.052)
  Facets.triangle(parent,foot[i],crest[i],foot[j],shade,finish)
  Facets.triangle(parent,foot[j],crest[i],crest[j],shade,finish)
  Facets.triangle(parent,crest[i],peak,crest[j],shade,finish)
 end
 return peak
end

local function ruby(biome,bed,terraces,ground)
 for _,part in ipairs(terraces:GetDescendants()) do
  if not part:IsA('BasePart') then continue end
  local edge,y=patchEdge(part,bed)
  if edge>27 or y>5 or y< -25 then continue end
  local noise=math.noise(part.Position.X*.058,part.Position.Z*.058)
  if part.MaterialVariant=='QuarryPhoto_Grass' and (edge<9 or noise>edge/55-.28) then
   part.MaterialVariant='QuarryBiome_Crimson';part.Color=rgb(189,103,108):Lerp(rgb(155,71,76),math.clamp(.5+noise,0,1))
  elseif (part.MaterialVariant=='QuarryPhoto_Sandstone' or part.MaterialVariant=='QuarryPhoto_Rock') and edge<18 then
   part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Shale'
   part.Color=rgb(174,195,223):Lerp(rgb(116,132,156),math.clamp(.45+noise,0,1))
  end
 end
 bed.Material=Enum.Material.Slate;bed.MaterialVariant='QuarryBiome_Shale';bed.Color=rgb(149,163,185)
 for _,spec in ipairs({{-37,9,5.8,20,-4},{-37,-13,4.8,26,-3},{-34,-27,3.9,15,-2},{-19,37,4.3,14,2},{16,38,3.1,9,1}}) do
  local p=ground(spec[1],spec[2])
  if p then
   spire(biome,p,spec[3],spec[4],Vector3.new(spec[5],0,-1),rgb(208,220,240),'QuarryBiome_Shale')
   local seam=p+Vector3.new(spec[3]*.64,1.3,0)
   local vein=segment(biome,'RubyVein',seam,seam+Vector3.new(-.45,spec[4]*.21,-.4),.15,rgb(250,87,104),Enum.Material.Neon)
   vein.CastShadow=false
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
 local salt,sand,grass=Enum.Material.Salt,Enum.Material.Sand,Enum.Material.Grass
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
 local color=rgb(240,249,255)
 local rings={}
 local sides=height>12 and 7 or 5
 local bands=height>12 and {{0,1},{.19,1.12},{.63,.79},{.86,.70},{1,.45}} or {{0,1},{.38,.97},{.90,.55}}
 for j,spec in ipairs(bands) do
  local points={}
  for i=1,sides do
   local a=(i-1)*math.pi*2/sides+turn
   local rough=1+.17*math.sin(i*3.1+seed)+.08*math.cos(i*2.4+j)
   points[i]=base+Vector3.new(math.cos(a)*width*spec[2]*rough+height*.10*spec[1],
    height*(spec[1]+(j==1 and 0 or .045*math.cos(i*1.7+j*.37+seed))),
    math.sin(a)*depth*spec[2]*rough-height*.045*spec[1])
  end
  rings[j]=points
 end
 local function finish(part)
  cosmetic(part);part.Name='StratifiedChalk';part.Material=Enum.Material.Slate
  part.MaterialVariant='QuarryBiome_Chalk'
 end
 for j=1,#rings-1 do
  for i=1,sides do
   local k=i%sides+1
   local shade=color:Lerp(rgb(150,183,199),.15+.18*(.5+.5*math.cos(i*1.7+seed))+(j==1 and .10 or 0))
   local a,b,c,d=rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i]
   Facets.triangle(parent,a,b,c,shade,finish);Facets.triangle(parent,a,c,d,shade,finish)
  end
 end
 local top=base+Vector3.new(height*.10,height*.99,-height*.045)
 local last=rings[#rings]
 for i=1,sides do Facets.triangle(parent,last[i],last[i%sides+1],top,color,finish) end
 return top
end

local function foliage(parent,base,scale,seed)
 for i=1,5 do
  local angle=(i-1)*2.4+seed
  local leaf=Instance.new('Part');leaf.Name='ShoreFoliage';leaf.Shape=Enum.PartType.Ball
  cosmetic(leaf)
  leaf.Size=Vector3.new(2.5+((i*7)%3)*.42,1.1+i%2*.48,2.4)*scale
  leaf.CFrame=CFrame.new(base+Vector3.new(math.cos(angle)*1.1,i%2*.5,math.sin(angle)*1.1)*scale)*CFrame.Angles(.14,angle,.22)
  leaf.Color=rgb(139,200,136):Lerp(rgb(209,232,158),i*.11)
  leaf.Material=Enum.Material.LeafyGrass;leaf.MaterialVariant='QuarryFoliage_Canopy'
  leaf.Parent=parent
 end
end

local function causeway(parent,origin)
 -- Flagstone crossing from the quarry to the overlook, with one low parapet.
 for i=1,7 do
  local p=Instance.new('Part');p.Name='LagoonCauseway';cosmetic(p)
  p.CanCollide=true;p.CanQuery=true;p:SetAttribute('WalkRoute',true)
  p.Size=Vector3.new(2.9,.9,7.8-.17*(i%2));p.Position=origin+Vector3.new(i*2.79,-.45+math.min(i-1,3)*.34,.11*math.sin(i))
  p.Color=ivory:Lerp(rgb(155,194,190),.13+.15*(i%3))
  p.Material=Enum.Material.Slate;p.MaterialVariant='QuarryBiome_Chalk';p.Parent=parent
  if i==2 or i==5 or i==7 then
   local foot=p.Position+Vector3.new(0,-3.5,2.4)
   rockMass(parent,foot,1.25,1.32,5.1,.4,i)
  end
 end
end

local function shoreTree(parent,base,h,lean,index)
 local top=base+lean+Vector3.yAxis*h
 local fork=base+lean*.55+Vector3.yAxis*(h*.64)
 local bark=rgb(220,212,176)
 segment(parent,'WindBentTrunk',base-Vector3.yAxis*.18,fork,h*.11,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
 segment(parent,'WindBentTrunk',fork,top,h*.073,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
 foliage(parent,top,h*.20,index)
 for i=1,3 do
  local theta=i*2.4+index
  local endPoint=fork+Vector3.new(math.cos(theta)*h*.30,h*(.16+i*.04),math.sin(theta)*h*.26)
  segment(parent,'WindBentBranch',fork,endPoint,h*.045,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
  foliage(parent,endPoint,h*.13,i+index)
 end
end

local function lagoon(parent,bed)
 local terrain=workspace.Terrain
 local center=bed.Position+Vector3.new(95,-5,0)
 local profile=basin(terrain,center,49,39,7,bed.Position+Vector3.new(48,-34,-44),center+Vector3.new(54,13,44))
 causeway(parent,bed.Position+Vector3.new(43,.55,0))
 -- Give the view from the causeway a clear foreground, open water in the
 -- middle, and two offset cliff groups beyond it. Leave the waterline legible.
 for i,s in ipairs({{26,-22,8.4,7.2,29},{34,-17,6.0,6.2,20},{19,-27,5.1,5.2,15},
  {35,15,6.4,6.0,16},{39,7,4.1,4.9,11},{10,30,4.6,4.2,6},{-9,29,3.6,4.2,5},
  {-27,16,4.2,4.7,3.8},{13,-17,3.7,3.3,4.5}}) do
  local x,z=center.X+s[1],center.Z+s[2]
  local _,y=profile(x,z)
  local base=Vector3.new(x,y-1.5,z)
  local peak=rockMass(parent,base,s[3],s[4],s[5],i*.51,i)
  if i<=7 then
   foliage(parent,peak-Vector3.yAxis*.22,i<=3 and 1.8 or 1.15,i)
   if i<=3 then foliage(parent,base+Vector3.new(-s[3]*.61,s[5]*.59,s[4]*.25),1.08,i+7) end
  end
 end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={terrain};params.IgnoreWater=true
 for i,s in ipairs({{-34,14,7.2},{-31,-17,8.6},{-20,-29,5.5},{-7,-32,0},{7,32,0},{24,27,5.8},{30,-25,0}}) do
  local x,z=center.X+s[1],center.Z+s[2]
  local r,expected=profile(x,z)
  local hit=workspace:Raycast(Vector3.new(x,center.Y+24,z),Vector3.new(0,-36,0),params)
  local ground=hit and hit.Position or (r<.94 and Vector3.new(x,expected,z))
  if ground and ground.Y>center.Y+.15 then
   foliage(parent,ground+Vector3.yAxis*.25,1.15+.22*(i%3),i)
   if s[3]>0 then shoreTree(parent,ground,s[3],Vector3.new(.8+i*.08,0,.55),i) end
  end
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

function Biomes.build(scene,terraces)
 local fields=scene.root:FindFirstChild('Fields')
 if not fields then return end
 local terrain=workspace.Terrain
 terrain.WaterColor=rgb(83,179,184);terrain.WaterReflectance=.27
 terrain.WaterTransparency=.26;terrain.WaterWaveSize=.16;terrain.WaterWaveSpeed=7
 terrain:SetMaterialColor(Enum.Material.Salt,rgb(206,221,218))
 terrain:SetMaterialColor(Enum.Material.Sand,rgb(209,222,185))
 for _,spec in ipairs({{'Ruby','RubyCrimsonBluffs',ruby},{'Cobalt','CobaltMushroomGrove',cobalt},{'Emerald','EmeraldChalkLagoon',emerald}}) do
  local field=fields:FindFirstChild(spec[1])
  local bed=field and field:FindFirstChild('Field')
  if bed and bed:IsA('BasePart') then
   local biome=Instance.new('Folder');biome.Name=spec[2];biome.Parent=scene.map
   spec[3](biome,bed,terraces,turfSampler(terraces,bed.Position))
  end
 end
end
return Biomes
