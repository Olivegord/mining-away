-- Rectangular turf color layers and a clear daylight palette, authored in Edit.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(game:GetService('RunService'):IsEdit())
local map=workspace.MiningAway.Map
assert(not map:FindFirstChild('QuarryMeadowLayers'))
local root=Instance.new('Folder');root.Name='QuarryMeadowLayers'
local props,parts,handles={},{},{}
local function bytes(c) return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)} end
local function set(p,k,x)
 local a=p:IsA('Texture') and p.Parent.Position
 table.insert(props,{path=p:GetFullName(),property=k,anchor=a and {a.X,a.Y,a.Z},before=typeof(p[k])=='Color3' and {p[k].R,p[k].G,p[k].B} or p[k],after=typeof(x)=='Color3' and {x.R,x.G,x.B} or x})
 table.insert(handles,{p,k,x})
end
local function tint(p,c)
 table.insert(parts,{path=p:GetFullName(),class=p.ClassName,anchor={p.Position.X,p.Position.Y,p.Position.Z},before={color=bytes(p.Color)},after={color=bytes(c)}})
 table.insert(handles,{p,'Color',c})
end
local rgb=Color3.fromRGB
local l=game.Lighting
set(l,'Brightness',2.6);set(l,'ExposureCompensation',.04)
set(l,'Ambient',rgb(151,177,205));set(l,'OutdoorAmbient',rgb(182,207,228))
set(l,'ColorShift_Top',rgb(0,0,0));set(l,'EnvironmentDiffuseScale',.08)
set(l,'EnvironmentSpecularScale',.12)
set(l.ColorCorrection,'Brightness',.012);set(l.ColorCorrection,'Contrast',.04);set(l.ColorCorrection,'Saturation',.18)
local greens={Quartz=rgb(133,198,124),Impact=rgb(163,204,105),Ruby=rgb(167,201,116),Cobalt=rgb(113,190,162),Violet=rgb(144,194,139),Emerald=rgb(112,206,151)}
local surfaces={}
for _,region in ipairs(map.QuarryContinuousGround.Terraces:GetChildren()) do
 for _,p in ipairs(region:GetChildren()) do if p.Name:match('^Turf') then
  tint(p,greens[region.Name]);table.insert(surfaces,{p,greens[region.Name]})
 end end
end
local hub=map.SimpleFlatTestMap.HubPad
tint(hub,rgb(139,204,119));table.insert(surfaces,{hub,rgb(139,204,119)})
for _,p in ipairs(map.DronerevolutionTerraces.MarketGardens:GetChildren()) do if p.Name=='GardenSoil' then tint(p,rgb(139,204,119)) end end
for _,p in ipairs(map.QuarryCourtyard.GroundLayers:GetChildren()) do
 local t=p.SecondaryGrain
 if t.Texture:find('118972165990804') then set(t,'Transparency',.73);set(t,'Color3',rgb(167,220,190)) end
end
-- Keep floral details saturated rather than relying on a global saturation filter.
local colors={rgb(255,213,44),rgb(255,109,173),rgb(75,220,246),rgb(255,113,96)}
for _,group in ipairs(map.QuarryCourtyard:GetChildren()) do
 for _,flower in ipairs(group:GetChildren()) do
  if flower.Name=='CrossFlowers' then for i,p in ipairs(flower:GetChildren()) do tint(p,colors[math.ceil(i/2)]) end end
 end
end
-- Sparse, broad rectangles share the existing turf grain but differ in hue and phase.
-- A 0.055-stud finish creates no terrain steps and does not participate in physics.
local ray=RaycastParams.new();ray.RespectCanCollide=true
local rand=Random.new(41682)
local count=0
for n,entry in ipairs(surfaces) do
 local surface,base=entry[1],entry[2]
 local sx,sz=surface.Size.X,surface.Size.Z
 local folder=Instance.new('Folder');folder.Name=surface.Parent.Name..'_'..surface.Name..'_'..n
 local nx,nz=math.max(1,math.floor(sx/22)),math.max(1,math.floor(sz/22))
 for ix=1,nx do for iz=1,nz do
  if (ix+iz*2+n)%3==0 then
   local w=math.min(sx/nx*.92,rand:NextNumber(15,25));local d=math.min(sz/nz*.92,rand:NextNumber(13,24))
   local x=-sx/2+(ix-.5)*sx/nx;local z=-sz/2+(iz-.5)*sz/nz
   local cf=surface.CFrame*CFrame.new(x,surface.Size.Y/2+.055,z)
   local clear=true
   for _,o in ipairs({Vector3.zero,Vector3.new(w/2,0,d/2),Vector3.new(-w/2,0,d/2),Vector3.new(w/2,0,-d/2),Vector3.new(-w/2,0,-d/2)}) do
    local hit=workspace:Raycast(cf.Position+o+Vector3.new(0,1,0),Vector3.new(0,-2,0),ray)
    if not hit or hit.Instance~=surface then clear=false;break end
   end
   if clear then
    count+=1
    local p=Instance.new('Part');p.Name='TurfPatch'..count;p.Size=Vector3.new(w,.02,d);p.CFrame=cf
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Material=surface.Material;p.MaterialVariant=surface.MaterialVariant
    local target=({rgb(96,181,140),rgb(166,214,117),rgb(116,183,104),rgb(134,211,168)})[(ix+iz+n)%4+1]
    p.Color=base:Lerp(target,.70);p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=folder
    local t=Instance.new('Texture');t.Name='OffsetFineGrain';t.Texture='rbxassetid://118972165990804';t.Face=Enum.NormalId.Top
    t.StudsPerTileU=13+(ix%3)*3;t.StudsPerTileV=17+(iz%3)*2;t.OffsetStudsU=ix*3.7;t.OffsetStudsV=iz*5.1
    t.Color3=p.Color;t.Transparency=.78;t.Parent=p
   end
  end
 end end
 folder.Parent=root
 task.wait()
end
local serializer,encoding=game:GetService('SerializationService'),game:GetService('EncodingService')
local model=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(serializer:SerializeInstancesAsync({root}),Enum.CompressionAlgorithm.Zstd)))
shared.QuarryMeadow={scenery=model,edits={parts=parts,properties=props},apply=function()
 assert(game:GetService('RunService'):IsEdit() and not root.Parent)
 for _,e in ipairs(handles) do e[1][e[2]]=e[3] end
 root.Parent=map
 return count
end}
return game.HttpService:JSONEncode({edits=shared.QuarryMeadow.edits,scenery=model,patches=count})
