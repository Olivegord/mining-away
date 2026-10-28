-- Shared host stubs for the actual client renderDrone function extracted by tools/test.py.
-- The mock verifies client logic, not actual Roblox rendering or network timing.
local function typeof(v) if getmetatable(v)==VM then return 'Vector3' end return type(v) end
local Players={}
local ownerRoot=Instance.new('Part');ownerRoot.Position=Vector3.new(80,0,0)
function Players:GetPlayerByUserId(_) return {Character={FindFirstChild=function(_,name) if name=='HumanoidRootPart' then return ownerRoot end end}} end
local presentation={}
function presentation:renderDrone(_,_,_) end
function presentation:renderMiningBeam(_,sample,_) self.lastBeam=sample end
function presentation:queueMiningBeam(_,sample,_) self.lastBeam=sample end
local function resolveRenderedTarget() return nil end
