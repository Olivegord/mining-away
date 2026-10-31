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

-- The final-hit path must survive production damage -> retirement -> snapshot
-- -> actual client dispatch. A directly fabricated renderer sample misses this.
local finalResources={}
resolveRenderedTarget=function(kind,id,allowBreaking)
 if kind~='resource' then return nil end
 local r=finalResources[id]
 if not r or not r.source.Parent or r.visual.broken or (not allowBreaking and (r.source:GetAttribute('HP') or 0)<=0) then return nil end
 return r.view,r.source,r
end
local function finishingContact(kind)
 release(d);data(p).run.cargo={};d.owned.type=kind;d.stats.forkFraction=kind=='Blue' and .2 or 0
 local f=patches[1]
 for _,r in ipairs(f.resources) do r.paid=true end
 local primary=makeResource(f,f.center,'Crystal',100,10)
 local secondary=makeResource(f,f.center+Vector3.new(5,0,0),'Crystal',100,10)
 primary.readyAt=now;secondary.readyAt=now
 finalResources={}
 for _,r in ipairs({primary,secondary}) do
  local view=r.part:Clone();view.Parent=workspace
  finalResources[r.id]={source=r.part,view=view,visual={broken=false}}
 end
 d.field=f.id;d.target=primary;d.targetSlot=1;primary.slots[d.id]=1;d.pos=Feel.mineGoal(primary.position,1,false);d.goal=d.pos;d.state='Mine';d.mining=true;d.beamSince=now-1
 pl.Character:PivotTo(CFrame.new(f.center))
 local since=d.beamSince
 assert(hitResource(d,primary,100))
 assert(primary.paid and d.target==nil and not d.mining and next(primary.slots)==nil)
 now+=1/60;realTime=now;droneStep(d,1/60);snapshotDrone(d)
 assert(d.target==secondary and d.state=='Travel','automatic acquisition should retain the brief old contact')
 local observer=viewer(nil);renderDrone(observer,1/60,now)
 local sample=presentation.lastBeam
 assert(sample.active and sample.key==primary.id and sample.secondaryKey==secondary.id,'production final-hit snapshot lost its primary/secondary visual IDs')
 assert(sample.part==finalResources[primary.id].view and sample.secondaryPart==finalResources[secondary.id].view)
 assert(sample.since==since and sample.breakContactUntil==d.mineBreakContact.untilTime,'final event changed original beam age or lifetime')
 assert(sample.style==Mining.style(kind))
 return observer,primary,secondary
end
for _,kind in ipairs({'Blue','Green'}) do
 local observer,primary=finishingContact(kind)
 now+=.31;realTime=now;renderDrone(observer,1/60,now)
 assert(not presentation.lastBeam.active and presentation.lastBeam.secondaryPart==nil,'client retained an expired final-hit branch')
 snapshotDrone(d);assert(d.model:GetAttribute('MineBreakUntil')==0)
 assert(primary.paid and next(primary.slots)==nil,'cosmetic contact restored a gameplay reservation')
end
local fullObserver,fullPrimary=finishingContact('Blue')
data(p).run.cargo={Quartz=119}
local finalDrop=makeResource(patches[1],patches[1].center,'Core',80,80)
finalDrop.readyAt=now;award(d,finalDrop)
assert(Profile.cargoUnits(data(p))==199)
droneStep(d,1/60);snapshotDrone(d);renderDrone(fullObserver,1/60,now)
assert(d.field==nil and d.target==nil and d.state=='Return','full hold must recall without retaining a job')
assert(presentation.lastBeam.active and presentation.lastBeam.key==fullPrimary.id,'automatic full-hold return erased the final causal cue')
leaveField(p);snapshotDrone(d);renderDrone(fullObserver,1/60,now)
assert(not presentation.lastBeam.active and d.mineBreakContact==nil,'explicit recall must erase the final cue')
local observer=finishingContact('Green')
p.busy=true;setMotionPaused(p,true);renderDrone(observer,1/60,now)
assert(not presentation.lastBeam.active and presentation.lastBeam.secondaryPart==nil,'owner pause replayed a final mining event')
p.busy=false;setMotionPaused(p,false);snapshotDrone(d)
assert(d.mineBreakContact==nil and d.model:GetAttribute('MineBreakUntil')==0)
print('PASS actual final-hit damage -> retired reservation -> snapshot -> client beam dispatch for fork and resonance, including automatic reacquisition, expiry and save pause (API doubles; not Studio/network)')
