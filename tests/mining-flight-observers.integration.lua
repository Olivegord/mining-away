-- Real yielding persistence adapter + server Heartbeat + two production renderers.
local pl=player(99119);players.PlayerAdded:Fire(pl);local p=assert(profiles[pl.UserId]);local d=p.drones[1]
pl.Character:PivotTo(CFrame.new(patches[1].center))
local r=makeResource(patches[1],patches[1].center,'Crystal',5000,10,3);r.readyAt=now
assert(assignOre(p,d,r));local station=committedStation(d,r)
d.pos=station-Vector3.new(60,0,0);d.velocity=Vector3.new(6,0,0);d.goal=station;d.intentGoal=station;snapshotDrone(d)
local function observer()
 local view=Instance.new('Model');view.Parent=workspace
 return {source=d.model,view=view,pos=d.pos,velocity=d.velocity,yaw=0,life=d.life,parts={},beam={}}
end
local a,b=observer(),observer();local late;local called=false
runtimeStore.hook=function()
 called=true;assert(p.busy and d.model:GetAttribute('WorkPaused') and not d.model:GetAttribute('MotionPaused'))
 local start=d.pos;local hp=r.hp
 for n=1,240 do
  realTime+=1/60;heartbeat:Fire(1/60);renderDrone(a,1/60,now);renderDrone(b,1/60,now)
  if n==120 then late=observer() end
  if late then renderDrone(late,1/60,now) end
  assert((a.pos-b.pos).Magnitude<1e-7,'observers chose different movement')
  assert(r.hp==hp and d.target==r,'save produced work or discarded job')
 end
 assert((d.pos-start).Magnitude>10 and (a.pos-start).Magnitude>10,'save froze flight')
 assert(late and (late.pos-d.pos).Magnitude<2,'late join failed bounded reconciliation')
end
autosaveElapsed=30;realTime+=1/60;heartbeat:Fire(1/60)
assert(called and not p.busy and not d.model:GetAttribute('WorkPaused'))
print('PASS four-second yielding production save: two matching observers, late join, continuous travel and zero work while busy (API doubles; not network/engine evidence)')
