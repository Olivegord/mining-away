assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game:GetService('RunService'):IsEdit())
local map=workspace.MiningAway.Map;local mat=game.MaterialService;local rgb=Color3.fromRGB
local variants={};local byBase={}
for _,base in ipairs({Enum.Material.Slate,Enum.Material.Sandstone}) do
 local m=Instance.new('MaterialVariant');m.Name='QuarryColorStone_'..base.Name;m.BaseMaterial=base
 m.ColorMap='rbxassetid://112016713025924';m.RoughnessMap='rbxassetid://78519593640803';m.StudsPerTile=22;m.MaterialPattern=Enum.MaterialPattern.Organic
 table.insert(variants,m);byBase[base]=m
end
local edits={parts={},properties={}};local handles={};local seen={}
local function bytes(c)return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)} end
local function finish(p,c,m)
 if seen[p] then return end;seen[p]=true
 local b,a={color=bytes(p.Color)},{color=bytes(c)}
 if m then assert(m.BaseMaterial==p.Material);b.variant=p.MaterialVariant;a.variant=m.Name end
 table.insert(edits.parts,{path=p:GetFullName(),class=p.ClassName,anchor={p.Position.X,p.Position.Y,p.Position.Z},before=b,after=a})
 table.insert(handles,{p,c,m})
end
local palette={Quartz={rgb(154,207,235),rgb(199,228,239)},Impact={rgb(242,182,106),rgb(244,211,143)},Ruby={rgb(229,125,148),rgb(245,176,190)},Cobalt={rgb(107,173,233),rgb(166,206,245)},Violet={rgb(183,143,224),rgb(217,188,243)},Emerald={rgb(112,206,177),rgb(170,237,204)}}
for _,region in ipairs(map.QuarryContinuousGround.Terraces:GetChildren()) do
 for _,p in ipairs(region:GetChildren()) do
  if p.Name:match('^Earth') then finish(p,palette[region.Name][1],byBase[p.Material])
  elseif p.Name:match('^Turf') then finish(p,p.Color:Lerp(rgb(203,244,157),.25)) end
 end
 local field=workspace.MiningAway.Fields[region.Name=='Impact' and 'ImpactTest' or region.Name].Field
 finish(field,palette[region.Name][2])
end
local rim={WestEscarpment=rgb(165,173,225),NorthCrown=rgb(143,195,230),EastChalkRim=rgb(141,221,205),SouthwestGate=rgb(185,165,224),SoutheastGate=rgb(136,202,218)}
for _,region in ipairs(map.QuarryBlockRim:GetChildren()) do
 for _,p in ipairs(region:GetChildren()) do if p.Name=='BasalRock' then finish(p,rim[region.Name],byBase[p.Material]) end end
end
for _,p in ipairs(map.DronerevolutionTerraces:GetDescendants()) do
 if p.ClassName=='Part' and p.Material==Enum.Material.Sandstone and (p.Name=='Earth' or p.Name=='EarthMass' or p.Name=='Foundation') then
  local c=rgb(239,198,145)
  if p.Position.Z < -65 then c=p.Position.X<0 and palette.Violet[1] or palette.Emerald[1] end
  finish(p,c,byBase[p.Material])
 end
end
for _,p in ipairs(map.DronerevolutionTerraces.MarketSquare:GetChildren()) do
 if p:IsA('Part') and (p.Name:find('Walk') or p.Name=='ShopApron') then finish(p,rgb(244,225,187)) end
end
finish(map.QuarryCourtyard.Hub.GravelCourt,rgb(244,225,187))
-- Retain the smoother grass image; lift its tint instead of adding grain.
for _,p in ipairs(map.QuarryMeadowLayers:GetDescendants()) do
 if p:IsA('Part') then finish(p,p.Color:Lerp(rgb(203,244,157),.25)) end
end
finish(map.SimpleFlatTestMap.HubPad,rgb(177,232,136))
local se,en=game:GetService('SerializationService'),game:GetService('EncodingService')
local model=buffer.tostring(en:Base64Encode(en:CompressBuffer(se:SerializeInstancesAsync(variants),Enum.CompressionAlgorithm.Zstd)))
shared.ColorWorld={apply=function()
 for _,m in ipairs(variants) do m.Parent=mat end
 for _,h in ipairs(handles) do h[1].Color=h[2];if h[3] then h[1].MaterialVariant=h[3].Name end end
 return #handles
end}
return game.HttpService:JSONEncode({edits=edits,variants=model})
