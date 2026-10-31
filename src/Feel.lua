-- Original 2023 motion and crystal timing, with explicit elapsed-time correction.
-- Scalar helpers stay engine-independent so the original equations are testable.
local F = {FollowHeight=3.2,WorkHeight=3,WorkClearance=.9}
function F.alpha(a, dt)
 if type(dt)~='number' or dt~=dt or dt<=0 then return 0 end
 return 1-(1-a)^(60*dt)
end
function F.turnAlpha(dt) return F.alpha(.1,dt) end
function F.approachScalar(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position
 local distance=math.abs(delta)
 if distance<1e-5 then return goal end
 local step=math.min(distance*F.alpha(.03,dt),math.max(0,maxStep60)*60*dt,distance)
 return position+(delta<0 and -step or step)
end
function F.approach(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position;local distance=delta.Magnitude
 if distance<1e-5 then return goal end
 local step=math.min(distance*F.alpha(.03,dt),math.max(0,maxStep60)*60*dt,distance)
 return position+delta/distance*step
end
function F.approachWork(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position;local distance=delta.Magnitude
 if distance>16 then return F.approach(position,goal,maxStep60,dt) end
 if distance<1e-5 then return goal end
 -- A short hop between nearby jobs should settle promptly. The server and
 -- every observer use this same bounded ease, never a cosmetic teleport.
 local step=math.min(distance*F.alpha(.065,dt),math.max(0,maxStep60)*1.45*60*dt,distance)
 return position+delta/distance*step
end
function F.formationXZ(slot,count)
 local angle=2*math.pi*slot/math.max(1,count)
 local radius=4.2+math.min(1.8,math.max(0,count-6)*.18)
 return math.cos(angle)*radius,math.sin(angle)*radius
end
function F.formation(slot,count)
 local x,z=F.formationXZ(slot,count)
 return Vector3.new(x,0,z)
end
function F.hover(time,maxStep60) return math.sin(time+maxStep60*200)*.14 end
function F.followOffset(slot,count,time,maxStep60)
 local x,z=F.formationXZ(slot,count)
 return x,F.FollowHeight+F.hover(time,maxStep60),z
end
function F.followGoal(ownerPosition,slot,count,time,maxStep60)
 local x,y,z=F.followOffset(slot,count,time,maxStep60)
 return ownerPosition+Vector3.new(x,y,z)
end
function F.stationOffset(slot,geode,height)
 height=height or (geode and 5 or F.WorkHeight)
 if not geode then return 0,height,0 end
 -- Geodes share three small slots over the shell footprint, never behind the rock.
 local angle=2*math.pi*((slot or 1)-1)/3
 return math.cos(angle)*.85,height,math.sin(angle)*.85
end
function F.mineGoal(resourcePosition,slot,geode,fullSize)
 -- Large original geodes can be eight studs tall. Keep the smaller worker
 -- just above that real volume instead of embedding it in the shell.
 local height=fullSize and math.max(F.WorkHeight,fullSize.Y*.5+F.WorkClearance) or nil
 local x,y,z=F.stationOffset(slot,geode,height)
 return resourcePosition+Vector3.new(x,y,z)
end
function F.stage(hp,maxHP)
 if maxHP<=0 then return 3 end
 local fraction=hp/maxHP
 if fraction<=.25 then return 3 elseif fraction<=.5 then return 2 elseif fraction<=.75 then return 1 end
 return 0
end
function F.stagesCrossed(previous,hp,maxHP)
 local result={}
 for stage=previous+1,F.stage(hp,maxHP) do table.insert(result,stage) end
 return result
end
function F.stageScale(stage) return 1-math.clamp(stage,0,3)*.25 end
function F.growthProgress(now,spawnAt) return math.clamp((now-spawnAt)/2,0,1) end
function F.growth(now,spawnAt)
 -- TweenInfo.new(2) originally used Roblox's default Quad.Out easing.
 local t=F.growthProgress(now,spawnAt)
 return 1-(1-t)^2
end
function F.ready(now,spawnAt) return now>=spawnAt+2 end
function F.canMine(distance,ready,allowed,alive)
 return alive==true and ready==true and allowed==true and distance<=1
end
function F.levelYaw(position,target,lastYaw)
 local dx,dz=target.X-position.X,target.Z-position.Z
 if dx*dx+dz*dz<1e-8 then return lastYaw or 0 end
 return math.atan2(-dx,-dz)
end
function F.approachYaw(yaw,target,dt)
 local delta=(target-yaw+math.pi)%(2*math.pi)-math.pi
 return yaw+delta*F.turnAlpha(dt)
end
-- Cosmetic-only quarter-stage sequencing. Server damage/rewards never wait for it.
function F.newStagePresentation(stage,broken,now)
 stage=math.clamp(math.floor(stage or 0),0,3)
 return {stage=stage,knownStage=stage,broken=broken==true,knownBreak=broken==true,queue={},nextAt=now or 0}
end
function F.updateStagePresentation(p,authoritativeStage,broken,now)
 -- A break implies all three quarters crossed, even if attributes arrive out of order.
 local target=broken and 3 or math.clamp(math.floor(authoritativeStage or 0),0,3)
 if target>p.knownStage and not p.knownBreak then
  for stage=p.knownStage+1,target do table.insert(p.queue,{stage=stage}) end
  p.knownStage=target
 end
 -- Keep an already-fractured source visible briefly so its final authoritative
 -- hit can resolve into the neighboring crystal before the source disappears.
 -- This is a cosmetic hold only; server rewards/slots retire immediately.
 if broken and not p.knownBreak then table.insert(p.queue,{broken=true,notBefore=now+.12});p.knownBreak=true end
 if #p.queue==0 or now<p.nextAt then return nil end
 if p.queue[1].broken and now<p.queue[1].notBefore then return nil end
 local event=table.remove(p.queue,1)
 if event.broken then p.broken=true;return 'break' end
 p.stage=event.stage;p.nextAt=now+.09
 return 'stage'
end
return F
