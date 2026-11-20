-- Calmer world light (November 19): the owner found the game too bright and
-- the effects shrouded. Less haze and glare, less added saturation, a weaker
-- bloom and a slightly lower sun. Stages exact before/after edits for
-- tools/refresh_calm_light.py; run in shared Edit, then call
-- shared.CalmLight.apply() and save.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(game:GetService('RunService'):IsEdit())
local l=game.Lighting
local props,handles={},{}
local function set(p,k,x)
 table.insert(props,{path=p:GetFullName(),property=k,before=p[k],after=x})
 table.insert(handles,{p,k,x})
end
set(l,'Brightness',2.1)
set(l.QuarryAir,'Haze',.35)
set(l.QuarryAir,'Density',.24)
set(l.QuarryAir,'Glare',0)
set(l.ColorCorrection,'Saturation',.08)
set(l.ColorCorrection,'Contrast',.08)
set(l.Bloom,'Intensity',.45)
shared.CalmLight={edits={properties=props,parts={}},apply=function()
 for _,e in ipairs(handles) do e[1][e[2]]=e[3] end
 return #handles
end}
return game.HttpService:JSONEncode(shared.CalmLight.edits)
