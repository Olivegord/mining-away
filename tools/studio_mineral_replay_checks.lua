-- Bundle Workshop, EnergyDisc, RockFinish, AudioFeedback, OreDrops,
-- PickupMotion, PickupDisplay and PickupView before this Edit check.
assert(not game:GetService('RunService'):IsRunning())
local fx=Instance.new('Folder');fx.Name='TemporaryMineralReplay';fx.Parent=workspace
local sources=Instance.new('Folder');sources.Parent=fx
local camera=workspace.CurrentCamera;local before=camera.CFrame
local view
local report={}
local ok,err=xpcall(function()
 local reduced=false
 view=PickupView.new(sources,fx,nil,function() return reduced end)
 local position=Vector3.new(55,6,-5)
 view.player={Character={FindFirstChild=function() return {Position=position} end},GetAttribute=function() return nil end}
 camera.CFrame=CFrame.lookAt(Vector3.new(11,20,-5),Vector3.new(32,8,-5))
 local now=workspace:GetServerTimeNow()
 position=Vector3.new(0,6,12)
 view:update(1/60,now)
 assert(not view.lineup.nextReplay,'replayed at spawn')
 position=Vector3.new(22,6,-5)
 view:update(1/60,now+.25)
 for pass=1,2 do
  local time=pass==1 and now+.25 or now+12.5
  view:update(1/60,time)
  local cueAt={}
  local seen={}
  for i=1,5 do
   local r=assert(view.byId[-i]);cueAt[i]=assert(r.previewReplayAt)
   if i>1 then assert(math.abs(cueAt[i]-cueAt[i-1]-.22)<.001) end
   assert(r.arc.x>r.arc.landX+3 and math.abs(r.arc.landX-32)<.01,'arc fails to land on its pad')
   seen[i]={}
  end
  for tick=1,220 do
   local t=time+tick/60
   view:update(1/60,t)
   for i=1,5 do
    local r=view.byId[-i];local age=t-PickupMotion.DELAY-cueAt[i]
    if age>=.22 and age<.4 then
     assert(r.ribbon and r.ribbon.trail.Enabled and not r.displayRig,'airborne effects are wrong')
     assert(r.drawPosition.Y>r.arc.floor+6,'no visible launch')
     seen[i].air=true
    elseif age>=r.landAge+.03 and age<r.landAge+.16 then
     assert(r.displayRig and r.displayRig.surface.Enabled and (not r.ribbon or not r.ribbon.trail.Enabled),'contact did not switch effects')
     assert(not r.hoverAlpha,'hover began before contact hold finished')
     seen[i].land=true
    elseif age>=r.landAge+1.1 then
     assert(r.hoverAlpha==1 and not r.ribbon and r.displayRig,'missing settled hover or lingering trail')
     seen[i].hover=true
    end
   end
  end
  for _,sample in ipairs(seen) do assert(sample.air and sample.land and sample.hover) end
  report[pass]={gems=5,launch=true,touchdown=true,hover=true}
 end
 reduced=true;view:update(1/60,now+26)
 assert(not view.lineup.nextReplay and not view.byId[-1].previewReplayAt,'reduced motion queued a replay')
end,debug.traceback)
camera.CFrame=before
if view then view:destroy() end
fx:Destroy()
assert(ok,err)
return report
