assert(game.PlaceId==124078027733625 and game.GameId==10774898335 and game:GetService('RunService'):IsEdit())
local map=workspace.MiningAway.Map
local edits={parts={},properties={}};local handles={};local grass,dirt=0,0
local function bytes(c)return {math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)} end
for _,p in ipairs(map:GetDescendants()) do
 if p.ClassName=='Part' then
  local c
  if p.MaterialVariant:match('^QuarryRestoredTurf_') then
   local patch=p:IsDescendantOf(map.QuarryMeadowLayers)
   local i=tonumber(p.Name:match('%d+')) or math.floor(math.abs(p.Position.X+p.Position.Z))
   local greens={Color3.fromRGB(118,255,74),Color3.fromRGB(96,235,90),Color3.fromRGB(145,255,65),Color3.fromRGB(99,246,112)}
   c=patch and greens[i%4+1] or Color3.fromRGB(126,250,78);grass+=1
  elseif p.Name:match('^Earth%d*$') or p.Name=='EarthMass' or p.Name=='Foundation' or p.Name=='BasalRock' then
   local colors={Color3.fromRGB(198,120,59),Color3.fromRGB(213,135,70),Color3.fromRGB(187,106,52),Color3.fromRGB(221,146,78)}
   local i=math.floor(math.abs(p.Position.X*.17+p.Position.Z*.11))
   c=colors[i%4+1];dirt+=1
  end
  if c then
   table.insert(edits.parts,{path=p:GetFullName(),class=p.ClassName,anchor={p.Position.X,p.Position.Y,p.Position.Z},before={color=bytes(p.Color)},after={color=bytes(c)}})
   table.insert(handles,{p,c})
  end
 end
end
shared.GreenWarm={apply=function() for _,h in ipairs(handles) do h[1].Color=h[2] end return {grass=grass,dirt=dirt} end}
return game.HttpService:JSONEncode(edits)
