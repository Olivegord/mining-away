-- Washed, bright daylight (November 22): the owner asked for the lighting of a
-- reference Roblox clip (bright pastel, faint bluish shadows, pale blue haze,
-- vivid sky fading to near white at the horizon). Neutral white sun instead of
-- the warm sunset cast, a bright cool fill so shadows stay light and soft, more
-- haze toward the horizon, lower contrast and a little more saturation so the
-- colors stay pastel instead of grey. Stages exact before/after edits for
-- tools/refresh_washed_light.py; run in shared Edit, then call
-- shared.WashedLight.apply() and save.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(game:GetService('RunService'):IsEdit())
local l=game.Lighting
local rgb=Color3.fromRGB
local props,handles={},{}
local function enc(x) if typeof(x)=='Color3' then return {x.R,x.G,x.B} end return x end
local function set(p,k,x)
 table.insert(props,{path=p:GetFullName(),property=k,before=enc(p[k]),after=enc(x)})
 table.insert(handles,{p,k,x})
end
set(l,'TimeOfDay','13:30:00')
set(l,'Brightness',2.6)
set(l,'ExposureCompensation',.15)
set(l,'Ambient',rgb(158,164,176))
set(l,'OutdoorAmbient',rgb(186,194,208))
set(l,'ColorShift_Top',rgb(255,238,212))
set(l,'ColorShift_Bottom',rgb(0,0,0))
set(l,'EnvironmentDiffuseScale',.8)
set(l,'EnvironmentSpecularScale',.2)
set(l,'ShadowSoftness',.5)
set(l.QuarryAir,'Density',.28)
set(l.QuarryAir,'Offset',.25)
set(l.QuarryAir,'Haze',1.1)
set(l.QuarryAir,'Glare',.2)
set(l.QuarryAir,'Color',rgb(200,224,248))
set(l.QuarryAir,'Decay',rgb(120,170,230))
set(l.ColorCorrection,'Brightness',.02)
set(l.ColorCorrection,'Contrast',-.06)
set(l.ColorCorrection,'Saturation',.18)
set(l.ColorCorrection,'TintColor',rgb(250,252,255))
set(l.Bloom,'Intensity',.4)
set(l.Bloom,'Size',28)
set(l.Bloom,'Threshold',1.5)
set(l.SunRays,'Intensity',.04)
shared.WashedLight={edits={properties=props,parts={}},apply=function()
 for _,e in ipairs(handles) do e[1][e[2]]=e[3] end
 return #handles
end}
return game.HttpService:JSONEncode(shared.WashedLight.edits)
