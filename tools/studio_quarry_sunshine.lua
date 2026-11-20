-- Bright reference follow-up. Stage exact before/after edits for the scoped saver.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(game:GetService('RunService'):IsEdit())
local l=game.Lighting
local map=workspace.MiningAway.Map
local props,parts,handles={},{},{}
local function enc(x) if typeof(x)=='Color3' then return {x.R,x.G,x.B} end return x end
local function set(p,k,x)
 local a=p:IsA('Texture') and p.Parent.Position
 table.insert(props,{path=p:GetFullName(),property=k,anchor=a and {a.X,a.Y,a.Z} or nil,before=enc(p[k]),after=enc(x)})
 table.insert(handles,{p,k,x})
end
set(l,'Brightness',2.3)
set(l,'ExposureCompensation',.10)
set(l,'Ambient',Color3.fromRGB(160,169,184))
set(l,'OutdoorAmbient',Color3.fromRGB(190,199,209))
set(l,'ColorShift_Top',Color3.fromRGB(16,10,0))
set(l,'FogStart',260)
set(l,'FogEnd',1100)
set(l.ColorCorrection,'Contrast',.015)
set(l.ColorCorrection,'Saturation',.23)
set(l.ColorCorrection,'Brightness',.025)
-- Broad independent grain must remain readable, not disappear into the base tile.
for _,carrier in ipairs(map.QuarryCourtyard.GroundLayers:GetChildren()) do
 local t=carrier.SecondaryGrain
 local grass=t.Texture:find('118972165990804')~=nil
 set(t,'Transparency',grass and .54 or .72)
 set(t,'StudsPerTileU',t.StudsPerTileU*1.31)
 set(t,'StudsPerTileV',t.StudsPerTileV*1.17)
 set(t,'Color3',grass and Color3.fromRGB(180,215,180) or Color3.fromRGB(180,190,210))
end
local tree=map.QuarryCourtyard.Quartz.SteppedTree
local anchor=Vector3.new(-104,3.975,78)
local target=Vector3.new(-126,3.975,78)
for _,p in ipairs(tree:GetChildren()) do
 local pos=target+(p.Position-anchor)*1.85
 local size=p.Size*1.85
 table.insert(parts,{path=p:GetFullName(),class=p.ClassName,anchor={p.Position.X,p.Position.Y,p.Position.Z},before={position={p.Position.X,p.Position.Y,p.Position.Z},size={p.Size.X,p.Size.Y,p.Size.Z}},after={position={pos.X,pos.Y,pos.Z},size={size.X,size.Y,size.Z}}})
 table.insert(handles,{p,'Position',pos});table.insert(handles,{p,'Size',size})
end
shared.QuarrySunshine={edits={properties=props,parts=parts},apply=function()
 for _,e in ipairs(handles) do e[1][e[2]]=e[3] end
 return #handles
end}
return game.HttpService:JSONEncode(shared.QuarrySunshine.edits)
