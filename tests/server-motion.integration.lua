-- Actual server plus actual client renderDrone, synthetic Roblox API/data-store double.
local pl=player(99881);players.PlayerAdded:Fire(pl);local p=assert(profiles[pl.UserId]);local d=p.drones[1]
d.field=1;d.state='Travel';d.goal=patches[1].center+Vector3.new(0,10,0);d.pos=d.goal-Vector3.new(80,0,0)
snapshotDrone(d);p.dirty=true
local function viewer(life)
 local v=Instance.new('Model');v.Parent=workspace
 return {source=d.model,view=v,pos=d.pos,yaw=0,life=life,parts={},beam={}}
end
local first,second=viewer(d.life),viewer(d.life)
renderDrone(first,1/60,now);renderDrone(second,1/60,now)
local called=false
runtimeStore.hook=function()
 called=true;assert(p.busy and d.model:GetAttribute('MotionPaused')==true)
 local serverPosition=d.pos;local a,b=first.pos,second.pos
 local late=viewer(nil);renderDrone(late,1/60,now);local c=late.pos
 for _=1,240 do
  realTime=realTime+1/60;heartbeat:Fire(1/60)
  renderDrone(first,1/60,now);renderDrone(second,1/60,now);renderDrone(late,1/60,now)
  assert((first.pos-a).Magnitude<1e-7 and (second.pos-b).Magnitude<1e-7 and (late.pos-c).Magnitude<1e-7,'viewer moved while simulation was paused')
  assert((d.pos-serverPosition).Magnitude<1e-7,'server moved while save was pending')
 end
end
autosaveElapsed=30;realTime=realTime+1/60;heartbeat:Fire(1/60)
assert(called and not p.busy and d.model:GetAttribute('MotionPaused')==false)
local before=first.pos;renderDrone(first,1/60,now);assert((first.pos-before).Magnitude<=d.stats.maxStep60*1.25+1e-6,'resume teleported')
print('PASS actual server and client renderDrone four-second yielding save with two viewers and late join (API doubles; not Studio/network)')
runtimeStore.hook=function() runtimeStore.failAfter=3;runtimeStore.failBefore=100 end
p.dirty=true;autosaveElapsed=30;realTime+=1/60;heartbeat:Fire(1/60)
assert(not p.busy and not store:healthy(p.session),'failed response must leave session unhealthy')
assert(d.model:GetAttribute('MotionPaused')==true,'unresolved failure must remain visibly paused')
local held=first.pos
for _=1,60 do realTime+=1/60;heartbeat:Fire(1/60);renderDrone(first,1/60,now);assert((first.pos-held).Magnitude<1e-7) end
runtimeStore.failBefore=0;runtimeStore.failAfter=0;autosaveElapsed=30;realTime+=1/60;heartbeat:Fire(1/60)
assert(store:healthy(p.session) and d.model:GetAttribute('MotionPaused')==false,'successful reconciliation must resume')
print('PASS unresolved save failure stays visibly paused until reconciliation (API doubles; not Studio/network)')
