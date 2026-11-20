-- Append after mock-roblox.lua and the actual Mining/WorkEffects modules.
-- Covers dispatch/lifecycle, not engine rendering or visual acceptance.
local parent=Instance.new('Folder');parent.Parent=workspace
local work=WorkEffects.new(parent)
for name,method in pairs(WorkEffects) do
 if type(method)=='function' then assert(type(work[name])=='function','Constructor shadows '..name) end
end
-- An idle render still dispatches mining(), even when no effect is visible.
local beam={origin={WorldPosition=Vector3.zero}}
work:mining(beam,{alive=true,isMining=true,active=false,paused=false,charging=false,warmupStart=0},nil,nil,0,0,0)
assert(beam.work==nil and work.miningCount==0)
work:update(1);work:destroy();work:destroy()
assert(work.miningCount==0 and next(work.miningBeams)==nil)
parent:Destroy()
print('PASS work effects constructor dispatch and idle/cleanup lifecycle (API doubles)')
