-- Paste into the Studio command bar in shared DRONEREVOLUTION Edit, then Save to Roblox.
-- Calms the view: darker, greyer seam outcrops and larger, fainter floor tiles.
-- tools/refresh_calm_scenery.py applies the identical values to build/DRONE_GAME.rbxl.
local TARGET,MIX=Color3.fromRGB(52,50,54),.5
local function byte(x) return math.floor(x*255+.5) end
local function mix(c)
 local function ch(a,b) return math.floor(a+(b-a)*MIX+.5) end
 return Color3.fromRGB(ch(byte(c.R),52),ch(byte(c.G),50),ch(byte(c.B),54))
end
local root=workspace:FindFirstChild('MiningAway');assert(root,'MiningAway missing')
local outcrops=root.Fields.CrystalRun:FindFirstChild('SeamOutcrops');assert(outcrops,'SeamOutcrops missing')
local textures={root.Fields.Baseplate.Texture,root.Map.SimpleFlatTestMap.HubPad.MiningAwayChecker}
for _,k in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do table.insert(textures,root.Fields.CrystalRun[k].Field.Texture) end
-- Check everything before changing anything, so a second paste is refused cleanly.
for _,t in ipairs(textures) do assert(t.StudsPerTileU==8 and t.StudsPerTileV==8,'already applied or unexpected tile size: '..t:GetFullName()) end
local list={}
for _,d in ipairs(outcrops:GetDescendants()) do if d:IsA('UnionOperation') then table.insert(list,d) end end
assert(#list==20 and #textures==7,('expected 20 outcrops and 7 textures, got %d and %d'):format(#list,#textures))
for _,d in ipairs(list) do d.Color=mix(d.Color) end
for _,t in ipairs(textures) do t.StudsPerTileU=16;t.StudsPerTileV=16;t.Transparency=.9 end
print('CalmScenery applied: 20 outcrops darkened, 7 floor textures calmed. Now File > Save to Roblox.')
