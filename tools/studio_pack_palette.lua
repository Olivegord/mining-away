assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game:GetService('RunService'):IsEdit())
local pack=workspace['Stud pack V1'];local mat=game.MaterialService
for _,p in ipairs(pack:GetDescendants()) do assert(not p:IsA('LuaSourceContainer'),'Pack contains code; review before export') end
local leaf=mat.Studs:Clone();leaf.Name='QuarryPack_Leaf';leaf.BaseMaterial=Enum.Material.LeafyGrass;leaf.StudsPerTile=2
local wood=mat.Universal:Clone();wood.Name='QuarryPack_Trunk';wood.BaseMaterial=Enum.Material.Wood;wood.StudsPerTile=2
local edits={parts={},properties={}};local handles={}
local function bytes(c)return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)}end
for _,root in ipairs({workspace.MiningAway.Map.QuarryContinuousGround.OriginalDetails,workspace.MiningAway.Map.QuarryCourtyard}) do
 for _,p in ipairs(root:GetDescendants()) do
  if p.ClassName=='Part' and (p.Material==Enum.Material.LeafyGrass or p.Material==Enum.Material.Wood) then
   local foliage=p.Material==Enum.Material.LeafyGrass
   local m=foliage and leaf or wood
   local c=foliage and Color3.fromRGB(97,149,0) or Color3.fromRGB(177,95,51)
   table.insert(edits.parts,{path=p:GetFullName(),class=p.ClassName,anchor={p.Position.X,p.Position.Y,p.Position.Z},before={variant=p.MaterialVariant,color=bytes(p.Color)},after={variant=m.Name,color=bytes(c)}})
   table.insert(handles,{p,m,c})
  end
 end
end
local se,en=game:GetService('SerializationService'),game:GetService('EncodingService')
local function export(items)return buffer.tostring(en:Base64Encode(en:CompressBuffer(se:SerializeInstancesAsync(items),Enum.CompressionAlgorithm.Zstd)))end
shared.PackPalette={apply=function()
 leaf.Parent=mat;wood.Parent=mat
 for _,h in ipairs(handles) do h[1].MaterialVariant=h[2].Name;h[1].Color=h[3] end
 return #handles
end}
return game.HttpService:JSONEncode({edits=edits,variants=export({leaf,wood}),pack=export({pack})})
