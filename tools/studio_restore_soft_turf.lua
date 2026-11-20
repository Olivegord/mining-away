assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game:GetService('RunService'):IsEdit())
local mat=game.MaterialService
local variants={};local replacements={}
for _,name in ipairs({'QuarryPhoto_Grass','QuarryCourtyard_Turf','QuarryCourtyard_Garden','QuarryAccent_LushGrass'}) do
 local old=mat[name];local key=old.BaseMaterial.Name
 if not replacements[key] then
  local m=old:Clone();m.Name='QuarryRestoredTurf_'..key;m.ColorMap='rbxassetid://118972165990804';m.StudsPerTile=17
  m.MaterialPattern=Enum.MaterialPattern.Organic
  replacements[key]=m;table.insert(variants,m)
 end
end
local probe=Instance.new('Decal');probe.Texture='rbxassetid://118972165990804'
local loaded=false;game.ContentProvider:PreloadAsync({probe},function(_,s) loaded=s==Enum.AssetFetchStatus.Success end);probe:Destroy();assert(loaded)
local allowed={QuarryPhoto_Grass=true,QuarryCourtyard_Turf=true,QuarryCourtyard_Garden=true,QuarryAccent_LushGrass=true}
local edits={};local handles={};local flags={}
local function vec(v)return {v.X,v.Y,v.Z}end
for _,p in ipairs(workspace.MiningAway.Map:GetDescendants()) do
 if p:IsA('Part') and allowed[p.MaterialVariant] then
  local e={path=p:GetFullName(),class=p.ClassName,anchor=vec(p.Position),before={variant=p.MaterialVariant},after={variant=replacements[p.Material.Name].Name}}
  if p:IsDescendantOf(workspace.MiningAway.Map.QuarryMeadowLayers) then
   local i=tonumber(p.Name:match('%d+'))
   local rise=({.22,.32,.42})[i%3+1]
   local bottom=p.Position.Y-p.Size.Y/2-.045
   e.before.position=vec(p.Position);e.before.size=vec(p.Size)
   e.after.position={p.Position.X,bottom+rise/2,p.Position.Z};e.after.size={p.Size.X,rise,p.Size.Z}
   for _,key in ipairs({'CanCollide','CanQuery','CastShadow'}) do table.insert(flags,{path=p:GetFullName(),property=key,before=p[key],after=true}) end
  end
  table.insert(edits,e);table.insert(handles,{p,e})
 end
end
local se,en=game:GetService('SerializationService'),game:GetService('EncodingService')
local exported=buffer.tostring(en:Base64Encode(en:CompressBuffer(se:SerializeInstancesAsync(variants),Enum.CompressionAlgorithm.Zstd)))
shared.SoftTurf={apply=function()
 for _,m in ipairs(variants) do m.Parent=mat end
 for _,h in ipairs(handles) do local p,e=h[1],h[2];p.MaterialVariant=e.after.variant
  if e.after.size then p.Size=Vector3.new(unpack(e.after.size));p.Position=Vector3.new(unpack(e.after.position));p.CanCollide=true;p.CanQuery=true;p.CastShadow=true end
 end
 return #edits
end}
return game.HttpService:JSONEncode({parts=edits,flags=flags,variants=exported})
