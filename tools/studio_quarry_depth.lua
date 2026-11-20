-- Author the depth pass once in the existing shared Edit document. The export
-- bridge keeps the native snapshot in sync without opening a Studio save panel.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335,'Wrong shared place')
assert(not game:GetService('RunService'):IsRunning(),'Stop Play before editing')
local root=workspace.MiningAway
assert(root:GetAttribute('QuarrySceneryAuthored'),'Missing authored quarry')
local map,fields=root.Map,root.Fields
local terraces=map.DronerevolutionTerraces
local materials=game:GetService('MaterialService')
local storage=game:GetService('ServerStorage')
assert(not map:FindFirstChild('QuarryDepthPass') and not storage:FindFirstChild('QuarryDormantVegetation'),'Reconcile existing depth pass first')
assert(materials.QuarryPhoto_Grass.ColorMap=='rbxassetid://134439792116456','Expected v43 material baseline')

local rgb=Color3.fromRGB
local v=Vector3.new
local cf=CFrame.new
local yaw=function(a) return CFrame.Angles(0,math.rad(a),0) end
local dry='rbxassetid://78519593640803'
local newMaps={'rbxassetid://140062751462844','rbxassetid://104200953297371'}
local decals={}
local loaded={}
for _,id in ipairs(newMaps) do
 local d=Instance.new('Decal');d.Texture=id;table.insert(decals,d)
end
game:GetService('ContentProvider'):PreloadAsync(decals,function(id,status) loaded[id]=status.Name end)
for _,d in ipairs(decals) do d:Destroy() end
for _,id in ipairs(newMaps) do assert(loaded[id]=='Success','Missing image: '..id) end

local variants={}
local function variant(name,base,mapId,tile,pattern)
 assert(not materials:FindFirstChild(name),name)
 local m=Instance.new('MaterialVariant');m.Name=name;m.BaseMaterial=base
 m.ColorMap=mapId;m.StudsPerTile=tile;m.MaterialPattern=pattern or Enum.MaterialPattern.Regular
 m.RoughnessMap=dry
 variants[name]=m;return name
end
local brick=variant('QuarryAccent_Brick',Enum.Material.Brick,newMaps[1],5.6)
local check=variant('QuarryAccent_Checker',Enum.Material.Slate,materials.QuarryPattern_Checker.ColorMap,6.4)
local timber=variant('QuarryAccent_Timber',Enum.Material.WoodPlanks,materials.QuarryPhoto_WoodPlanks.ColorMap,6)
local steel=variant('QuarryAccent_Ribbed',Enum.Material.CorrodedMetal,materials.QuarryPhoto_CorrodedMetal.ColorMap,4.8)
local loam=variant('QuarryBlend_RubyLoam',Enum.Material.Grass,newMaps[2],12,Enum.MaterialPattern.Organic)
local stone='QuarryPhoto_Slate'
local shale='QuarryBiome_Shale'
local chalk='QuarryBiome_Chalk'
local grass='QuarryPhoto_Grass'
local paving='QuarryPhoto_Pavement'

local function folder(parent,name)
 local f=Instance.new('Folder');f.Name=name;f.Parent=parent;return f
end
local pass=folder(nil,'QuarryDepthPass')
local archive=folder(nil,'QuarryDormantVegetation')
local accents=folder(pass,'MaterialSamples')
local ruby=folder(pass,'RubyEscarpment')
local cobalt=folder(pass,'CobaltForestExtension')
local emerald=folder(pass,'EmeraldShoreTerraces')
local violet=folder(pass,'VioletRidge')
local seam=folder(pass,'BiomeApproaches')

local function piece(parent,name,frame,size,tint,finish,opts)
 opts=opts or {}
 local p=Instance.new(opts.wedge and 'WedgePart' or 'Part');p.Name=name
 p.Anchored=true;p.CanCollide=opts.walk==true;p.CanQuery=p.CanCollide;p.CanTouch=false
 p.CastShadow=opts.shadow~=false
 p.CFrame=frame;p.Size=size;p.Color=tint
 local m=finish and (variants[finish] or materials:FindFirstChild(finish))
 p.Material=m and m.BaseMaterial or (opts.base or Enum.Material.SmoothPlastic)
 if m then p.MaterialVariant=finish end
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Parent=parent;return p
end
local function slab(parent,name,x,top,z,w,h,d,tint,finish,angle,walk)
 return piece(parent,name,cf(x,top-h/2,z)*yaw(angle or 0),v(w,h,d),tint,finish,{walk=walk})
end
local function rod(parent,name,a,b,width,tint,finish)
 local p=piece(parent,name,CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0),
  v((b-a).Magnitude+.05,width,width),tint,finish)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function disc(parent,name,frame,r,height,tint,finish)
 local p=piece(parent,name,frame*CFrame.Angles(0,0,math.pi/2),v(height,r*2,r*2),tint,finish)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function ground(x,z)
 local hit=workspace:Raycast(v(x,140,z),v(0,-180,0))
 if hit and hit.Instance.Name=='Turf' and hit.Normal.Y>.95 then return hit.Position.Y end
 return nil
end

-- A continuous wall set well behind the original narrow Ruby outcrops.
-- Large staggered planes carry the silhouette; lower talus benches bridge the gap.
for i=1,12 do
 local z=-96+(i-1)*17
 local height=({64,83,101,114,128,137,120,126,109,94,77,61})[i]
 local x=-223-7*math.sin(i*.64)-(i%3)*3.1
 local tint=rgb(140,156,180):Lerp(rgb(191,198,214),.13*(i%4))
 local base=-18
 slab(ruby,'EscarpmentMass',x,base+height,z,38,height,23,tint,shale,(i%4-1.5)*4)
 slab(ruby,'LowerStoneButtress',x+18,base+height*.64,z+2,26,height*.72,18,tint:Lerp(rgb(103,124,155),.21),stone,(i%3-1)*7)
 if i>1 and i<12 then
  slab(ruby,'WeatheredRockBand',x+11,base+height*.74,z-1,33,4+(i%3),22,tint:Lerp(rgb(217,200,185),.24),stone,-5)
  piece(ruby,'BrokenUpperEdge',cf(x,base+height+2,z)*yaw(92+(i%3)*6),v(22,8+(i%4)*2,34),
   tint:Lerp(rgb(210,214,222),.16),shale,{wedge=true})
 end
end
for i,s in ipairs({{-185,-45,21,42,47},{-194,-7,26,54,51},{-188,37,22,49,50},{-182,69,11,37,43}}) do
 slab(ruby,'TalusBench',s[1],s[3],s[2],s[4],27,s[5],rgb(146,151,169),stone,i%2==0 and 8 or -7)
 slab(ruby,'LoamShelf',s[1]+2,s[3]+.18,s[2]+2,s[4]*.86,.7,s[5]*.77,rgb(209,202,186),loam,i%2==0 and 8 or -7)
end

-- Open ground inside the existing forest becomes a broad, walkable outer shelf.
-- Keep the original mining bed and ramps untouched.
for _,s in ipairs({
 {175,19.91,0,51,51,58,0},{206,20.55,-16,67,49,59,6},
 {198,20.13,33,59,47,51,-8},{196,20.74,-51,55,42,38,14},
 {231,21.18,14,39,38,47,-13},{216,20.9,50,43,40,28,-12}
}) do
 local x,top,z,w,h,d,a=table.unpack(s)
 slab(cobalt,'ForestRockShelf',x,top-.28,z,w,h,d,rgb(130,154,173),shale,a,true)
 slab(cobalt,'MossFloor',x,top,z,w-.2,.75,d-.2,rgb(177,198,168),chalk,a,true)
end
for i=1,8 do
 local x=167+i*8.8;local z=(i%2==0 and -1 or 1)*(45+math.sin(i)*7)
 slab(cobalt,'FracturedForestEdge',x,18+(i%3)*2,z,21,35+(i%3)*8,16,rgb(141,164,175),stone,(i-4)*8)
end

local capPalettes={
 {rgb(70,124,178),rgb(91,155,206),rgb(156,212,223)},
 {rgb(153,72,99),rgb(199,111,124),rgb(239,166,152)},
 {rgb(75,113,156),rgb(115,146,184),rgb(161,190,211)},
}
local cream=rgb(237,222,184)
local function mushroom(parent,name,base,height,r,dx,dz,palette,index)
 local group=folder(parent,name)
 local p=capPalettes[palette]
 local fork=base+v(dx*.3,height*.49,dz*.25)
 local crown=base+v(dx,height,dz)
 local thick=math.max(.24,r*.20)
 rod(group,'RootedStalk',base-v(0,.35,0),fork,thick*1.30,cream:Lerp(p[1],.18),chalk)
 rod(group,'CurvedStalk',fork,crown,thick*.86,cream:Lerp(p[2],.38),chalk)
 local frame=cf(crown)*CFrame.Angles(math.rad(5*math.sin(index)),0,math.rad(9*math.cos(index)))
 disc(group,'CapUnderside',frame*cf(0,-r*.08,0),r*.72,math.max(.17,r*.20),p[1],chalk)
 disc(group,'CreamCapRim',frame,r,math.max(.17,r*.095),cream,chalk)
 disc(group,'CapSkirt',frame*cf(0,r*.12,0),r*.96,math.max(.21,r*.18),p[1],chalk)
 disc(group,'CapCrown',frame*cf(0,r*.25,0),r*.80,math.max(.22,r*.20),p[2],chalk)
 disc(group,'RaisedCapCenter',frame*cf(0,r*.36,0),r*.52,math.max(.2,r*.13),p[3],chalk)
 if r>=8 then
  for i=1,7 do
   local a=i*math.pi*2/7
   local radial=v(math.cos(a),0,math.sin(a))
   local inner=frame:PointToWorldSpace(radial*r*.22-v(0,r*.19,0))
   local outer=frame:PointToWorldSpace(radial*r*.87-v(0,r*.095,0))
   rod(group,'RadialGill',inner,outer,r*.035,cream:Lerp(p[3],.40),chalk)
  end
 end
end
local canopy=folder(cobalt,'Canopy')
for i,s in ipairs({
 {78,-21,20,19,9,4,2,3},{97,39,20,23,12,-4,2,2},{158,21,20,23,12,4,-3,3},{139,-40,20,25,12,4,-2,2},
 {173,-26,19.9,36,15,-6,3,1},{184,22,20,48,19,-7,1,1},{195,-47,20.65,35,16,5,4,3},
 {207,-12,20.5,52,22,6,1,1},{222,29,20.65,42,18,-4,5,3},{221,-41,20.5,31,14,5,0,2},
 {236,4,21.10,37,14,2,-2,1},{200,53,20.55,25,11,5,-4,2},{169,38,19.85,24,10,4,3,3},
 {229,47,20.85,25,10,3,3,2},{203,16,20.2,24,11,-5,-2,2},{160,-8,19.92,18,8,5,4,2},
}) do
 local x,z,y,h,r,dx,dz,p=table.unpack(s)
 mushroom(canopy,('Canopy%02d'):format(i),v(x,y,z),h,r,dx,dz,p,i)
end
local understory=folder(cobalt,'Understory')
for i,s in ipairs({{80,-29},{81,23},{119,39},{150,39},{154,-28},{173,-18},{173,16},{186,-32},
 {188,4},{197,40},{209,-27},{212,24},{227,-5},{232,31},{224,52},{192,-51}}) do
 local x,z=table.unpack(s)
 local y=ground(x,z) or 20.17
 for j=1,3 do
  local a=j*2.4+i;local r=1.2+(i+j)%4*.33
  mushroom(understory,('Shelf%02d_%d'):format(i,j),v(x+math.cos(a)*2.1,y,z+math.sin(a)*2.1),
   2.1+((i+j)%5)*.73,r,math.cos(a)*.6,math.sin(a)*.6,1+(i%3),i+j)
 end
end

-- Chalk ridges behind Emerald's existing shore; foreground water and crossing
-- remain open. Broad green shoulders tie the chalk and neighboring turf together.
for i=1,8 do
 local z=-169+(i-1)*15
 local x=237+(math.sin(i*.56)+1)*9
 local h=({44,63,88,105,99,76,63,40})[i]
 local tint=rgb(211,226,222):Lerp(rgb(160,185,204),.12*(i%3))
 slab(emerald,'DistantChalkFace',x,28+h,z,36,h,25,tint,chalk,(i%3-1)*8)
 slab(emerald,'LowerLimestoneShoulder',x-19,26+h*.60,z-2,32,h*.72,24,tint:Lerp(rgb(152,181,185),.18),chalk,(i%2)*7)
 if i%2==1 then slab(emerald,'MossCrown',x-2,28+h+.65,z+1,35,1.8,22,rgb(203,220,181),grass,3) end
end
for _,s in ipairs({{212,45,-143,34,21},{217,44,-80,35,23},{231,55,-133,40,19},{227,54,-91,38,20}}) do
 slab(emerald,'WeatheredBankShelf',s[1],s[2],s[3],s[4],18,s[5],rgb(199,220,213),chalk,9)
 slab(emerald,'BankMoss',s[1]+1,s[2]+.22,s[3]+1,s[4]*.76,1.1,s[5]*.77,rgb(185,206,168),grass,9)
end
local function shoreTree(parent,x,y,z,h,i)
 local base=v(x,y,z);local fork=base+v(2,h*.63,-1);local crown=base+v(4,h,-2)
 rod(parent,'ShoreTrunk',base,fork,h*.14,rgb(194,181,151),'QuarryFoliage_Bark')
 rod(parent,'ShoreLeader',fork,crown,h*.09,rgb(199,190,154),'QuarryFoliage_Bark')
 for j=1,5 do
  local a=j*2.399+i
  local top=crown+v(math.cos(a)*h*.26,(j%3)*1.55-h*.15,math.sin(a)*h*.23)
  if j<=3 then rod(parent,'ShoreBranch',fork,top,h*.058,rgb(198,190,155),'QuarryFoliage_Bark') end
  slab(parent,'WindShapedCanopy',top.X,top.Y,top.Z,h*.56,h*.16,h*.44,
   rgb(170,218,165):Lerp(rgb(131,185,166),.13*(j%3)),'QuarryFoliage_Canopy',j*41)
 end
end
shoreTree(emerald,207,44.2,-141,26,1)
shoreTree(emerald,215,43.1,-79,32,2)
shoreTree(emerald,232,54.2,-134,24,3)

-- Cooler stratified benches and a broken ridge give Violet a distinct skyline.
for i=1,8 do
 local x=-132+i*15.5
 local z=-176-10*math.sin(i*.58)
 local h=({22,35,57,66,53,40,29,20})[i]
 slab(violet,'VioletRidgeMass',x,31+h,z,23,h+12,25,
  rgb(147,142,171):Lerp(rgb(170,164,191),.17*(i%4)),stone,(i-4)*3)
 slab(violet,'SplitVioletBench',x,37+h*.48,z+11,25,h*.66,22,rgb(171,162,193),shale,i%3*7)
 if i%2==0 then
  slab(violet,'RidgeGrassLip',x,37.5+h*.48,z+12,20,1.1,15,rgb(176,193,159),grass,i%3*7)
 end
end

-- Repeat a common quarry vocabulary across biomes; these are small
-- noninteractive markers outside the mining floors and walking routes.
local function sample(name,x,z,w,h,d,tint,finish,angle)
 local y=ground(x,z)
 if not y then return false end
 piece(accents,name,cf(x,y+h*.5-.04,z)*yaw(angle),v(w,h,d),tint,finish)
 return y
end
local function studded(x,z,s)
 local yellow=rgb(226,177,60)
 local y=sample('OchreStudBlock',x,z,s,s*.72,s,yellow,nil,9)
 if not y then return end
 local frame=cf(x,y+s*.72-.035,z)*yaw(9)
 for i=-1,1 do for j=-1,1 do
  disc(accents,'RaisedCeramicStud',frame*cf(i*s*.27,s*.031,j*s*.27),s*.087,s*.085,rgb(235,189,70),nil)
 end end
end
sample('QuartzCheckerBlock',-89,58,5.5,5.6,5.5,rgb(242,231,207),check,-10)
sample('QuartzBrickBlock',-107,92,5.2,5.0,4.9,rgb(247,217,196),brick,8)
studded(-109,106,3.5)
sample('QuartzRibbedBlueBlock',-91,130,4.6,4.9,4.5,rgb(102,156,232),steel,-12)
sample('QuartzTimberBlock',-70,134,5.7,4.2,4.8,rgb(255,214,153),timber,14)
sample('QuartzBlueCheckPaver',-54,132,6.8,.28,6.8,rgb(134,183,239),check,11)
sample('RubyTerracottaBlock',-85,-30,4.7,4.0,4.4,rgb(239,202,175),brick,-9)
sample('RubyOchreCheckPaver',-89,36,5.8,.24,5.4,rgb(218,178,141),check,12)
sample('CobaltRibbedBlock',85,-23,4.4,3.9,4.4,rgb(116,170,222),steel,14)
sample('CobaltBlueCheckPaver',84,31,5.0,.25,4.7,rgb(140,185,235),check,3)
sample('VioletTimberBlock',-37,-74,4.4,3.7,4.1,rgb(219,187,166),timber,-12)
sample('VioletCheckPaver',-31,-84,5.0,.26,5.0,rgb(179,171,216),check,12)
sample('EmeraldTimberBlock',35,-80,4.5,3.8,4.5,rgb(246,217,160),timber,-11)
sample('EmeraldGreenCheckPaver',105,-137,5.5,.25,5.5,rgb(163,209,187),check,8)
sample('ImpactBrickBlock',106,95,4.8,4.2,4.8,rgb(232,210,190),brick,-6)
sample('ImpactOchreCheckPaver',95,132,5.4,.25,5.3,rgb(233,203,131),check,-7)

-- A chain of low shared materials at transitions helps the zones read as one place.
for i,s in ipairs({{-80,-22},{-87,-46},{-76,-63},{81,18},{86,46},{71,56},{85,-50},{79,-65},
 {-31,-100},{-15,-99},{10,-101},{23,-99},{-93,54},{-99,62},{104,50},{112,63}}) do
 local y=ground(s[1],s[2])
 if y then
  local color=rgb(159,177,164):Lerp(rgb(190,189,175),.15*(i%4))
  slab(seam,'WeatheredTransitionStone',s[1],y+.24,s[2],4+(i%3)*.8,.45,3.2,color,paving,i*13)
 end
end

-- Prepare in-place edits with old and new values for a guarded native merge.
local function xyz(p) return {p.X,p.Y,p.Z} end
local function colorBytes(c) return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)} end
local edits,handles={},{}
local function stage(p,after)
 assert(p.ClassName=='Part' or p.ClassName=='WedgePart',p:GetFullName())
 local before={}
 if after.position then before.position=xyz(p.Position) end
 if after.size then before.size=xyz(p.Size) end
 if after.color then before.color=colorBytes(p.Color) end
 if after.variant then before.variant=p.MaterialVariant end
 table.insert(edits,{path=p:GetFullName(),class=p.ClassName,anchor=xyz(p.Position),before=before,after=after})
 table.insert(handles,p)
end
local archived,trees={},0
local treeGroups={terraces.AssetScenery,terraces.MarketGardens}
for _,group in ipairs(treeGroups) do
 for _,tree in ipairs(group:GetDescendants()) do
  if not tree:IsA('Model') then continue end
  local leaf=tree.Name:lower()
  local isTree=leaf:find('tree',1,true)~=nil
  if tree.Parent.Name=='CobaltScenery' and (isTree or leaf:find('bush',1,true)) then
   table.insert(archived,tree)
  elseif isTree then
   local frame,size=tree:GetBoundingBox()
   local base=frame.Position-v(0,size.Y*.5,0)
   local height=tree.Name=='LookoutTree' and 1.94 or 1.66+(math.abs(math.floor(base.Z))%4)*.11
   local width=tree.Parent==terraces.MarketGardens and 1.20 or 1.36+(math.abs(math.floor(base.X))%4)*.06
   local scale=v(width,height,width)
   for _,p in ipairs(tree:GetDescendants()) do
    assert(p.ClassName=='Part','Unexpected tree content: '..p:GetFullName())
    stage(p,{position=xyz(base+(p.Position-base)*scale),size=xyz(p.Size*scale)})
   end
   trees+=1
  end
 end
end

local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
for _,p in ipairs(terraces:GetDescendants()) do
 if not p:IsA('BasePart') then continue end
 local x,y,z=p.Position.X,p.Position.Y,p.Position.Z
 local base=p.MaterialVariant
 local after
 if base=='QuarryBiome_Crimson' and p.Name~='Turf' then
  local tint=p.Name=='RubyEdgeWeathering' and rgb(213,204,188) or rgb(168,171,160)
  after={variant=loam,color=colorBytes(tint)}
 elseif p.ClassName~='Part' or p.Name~='Turf' then
  continue
 elseif base=='QuarryBiome_Crimson' then
  local intoCliff=smooth((-x-74)/77)
  local shoulder=smooth((math.abs(z)-22)/48)
  if intoCliff<.48 and shoulder>.42 then
   after={variant=grass,color=colorBytes(rgb(191,182,149):Lerp(rgb(221,218,180),shoulder))}
  else
   after={variant=loam,color=colorBytes(rgb(183,184,175):Lerp(rgb(227,214,196),intoCliff))}
  end
 elseif base==chalk and x>67 and y<23 and math.abs(z)<67 then
  local intoForest=smooth((x-76)/76)
  after={color=colorBytes(rgb(138,163,127):Lerp(rgb(176,200,173),intoForest))}
 elseif base==grass and x>47 and z<-62 and y>30 then
  local lagoonWeight=smooth((x-55)/62)
  after={color=colorBytes(p.Color:Lerp(rgb(176,211,187),lagoonWeight*.74))}
 elseif base==grass and x<-28 and z<-47 and y>26 then
  local violetWeight=smooth((-z-47)/74)
  after={color=colorBytes(p.Color:Lerp(rgb(187,190,175),violetWeight*.72))}
 elseif base==grass and math.abs(z)<66 and math.abs(x)>53 then
  local edge=smooth((math.abs(x)-53)/45)
  local tint=x<0 and rgb(211,188,148) or rgb(169,192,161)
  after={color=colorBytes(p.Color:Lerp(tint,edge*.69))}
 end
 if after then stage(p,after) end
end
assert(trees==18 and #archived==7 and #edits>285,
 ('Unexpected vegetation baseline: %d trees, %d archived, %d edits'):format(trees,#archived,#edits))
assert(#accents:GetChildren()>=22,('Only %d accent pieces found safe placements'):format(#accents:GetChildren()))
local moves={}
for _,tree in ipairs(archived) do table.insert(moves,{path=tree:GetFullName(),parent='ServerStorage.'..archive.Name}) end

local function set(p,after)
 if after.position then p.CFrame=CFrame.new(Vector3.new(table.unpack(after.position)))*p.CFrame.Rotation end
 if after.size then p.Size=Vector3.new(table.unpack(after.size)) end
 if after.variant then p.MaterialVariant=after.variant end
 if after.color then p.Color=rgb(table.unpack(after.color)) end
end
-- Keep transient payloads in the local Studio tool context, outside the game.
-- Serialize the new archive before moving any old model into it.
local serialization=game:GetService('SerializationService')
local enc=game:GetService('EncodingService')
local http=game:GetService('HttpService')
local function encode(bytes)
 return buffer.tostring(enc:Base64Encode(enc:CompressBuffer(bytes,Enum.CompressionAlgorithm.Zstd)))
end
local newVariants={}
for _,m in pairs(variants) do table.insert(newVariants,m) end
table.sort(newVariants,function(a,b) return a.Name<b.Name end)
local snapshot={
 scenery=encode(serialization:SerializeInstancesAsync({pass})),
 variants=encode(serialization:SerializeInstancesAsync(newVariants)),
 archive=encode(serialization:SerializeInstancesAsync({archive})),
 edits=encode(buffer.fromstring(http:JSONEncode({edits=edits,moves=moves}))),
}
for _,m in ipairs(newVariants) do m.Parent=materials end
archive.Parent=storage
for _,tree in ipairs(archived) do tree.Parent=archive end
for i,p in ipairs(handles) do set(p,edits[i].after) end
pass.Parent=map
shared.QuarryDepthSnapshot=snapshot
local counts={}
for name,data in pairs(snapshot) do counts[name]=#data end
return {trees=trees,archived=#archived,edits=#edits,newScenery=#pass:GetDescendants(),canopy=#canopy:GetChildren(),
 understory=#understory:GetChildren(),assetStatus=loaded,exportBytes=counts}
