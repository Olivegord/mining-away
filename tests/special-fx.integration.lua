-- Production DroneFX with Roblox API doubles. These validate timelines and
-- ownership/cleanup; they are not engine-rendering or visual-quality evidence.
CF.Rotation=CFrame.new()
local world=Instance.new('Folder');world.Parent=workspace
local visibleRoot=Instance.new('Folder');visibleRoot.Parent=workspace
local views={};local ctrl=DroneFX.new(world,{resolve=function(source) return views[source] end})
local durations={Bubbler=2.8,Halver=3.6,Gridcutter=2.5,Singularity=2,Starforge=3,Frostbite=2.4,Resonator=2.6}
local checks=0
local function resource(kind,start,noView)
 local p=Instance.new('Part');p.Name='Crystal';p.Size=Vector3.new(4,5,3);p.Position=Vector3.new(0,4,0);p.Material=Enum.Material.Slate;p.LocalTransparencyModifier=1;p.Parent=world
 p:SetAttribute('ResourceId','test');p:SetAttribute('FullSize',p.Size);p:SetAttribute('EffectType',kind);p:SetAttribute('EffectStartedAt',start);p:SetAttribute('EffectDuration',durations[kind]);p:SetAttribute('EffectImpact',.68);p:SetAttribute('EffectSerial',1);p:SetAttribute('EffectDepleted',false)
 if not noView then local view=p:Clone();view.Position=Vector3.new(10,4,0);view.LocalTransparencyModifier=.2;view.Parent=visibleRoot;views[p]=view end
 return p
end
local function dispose(p) local view=views[p];p:Destroy();if view then view:Destroy() end;views[p]=nil end
local function finite(e,kind)
 assert(#e.parts<=48,kind..' per-effect geometry budget')
 for _,part in ipairs(e.parts) do
  assert(part.Size.X>0 and part.Size.Y>0 and part.Size.Z>0 and part.Position.Magnitude==part.Position.Magnitude,kind..' positive finite geometry')
 end
end
local now=20
for kind,duration in pairs(durations) do
 local p=resource(kind,now);local view=views[p]
 for j=0,68 do
  ctrl:step(now+duration*j/100,1/60)
  local e=assert(ctrl.active[p]);finite(e,kind)
  assert((e.rock.Position-view.Position).Magnitude<.0001,kind..' leaves the remaining crystal grounded')
  assert((e.rock.Size-view.Size).Magnitude<.0001 and e.rock.Transparency==0,kind..' does not pretend to swallow the whole crystal')
  assert(view.LocalTransparencyModifier==1 and p.LocalTransparencyModifier==1,kind..' proxy only hides local view')
 end
 local contact=now+duration*.68
 p:SetAttribute('EffectDoneAt',contact);view.Size=view.Size*.75
 ctrl:step(contact+.04,1/60)
 assert(ctrl.count>0 and view.LocalTransparencyModifier==.2,kind..' nonlethal immediately hands off to current fracture pose')
 assert(ctrl.active[p].rock.Transparency==1,kind..' removes old proxy after chunk')
 local endOfTail=ctrl.active[p].tail*.99
 ctrl:step(contact+endOfTail,1/144)
 for _,part in ipairs(ctrl.active[p].parts) do assert(part.Transparency>.96,kind..' completes its tail before next cycle replaces geometry') end
 ctrl:step(contact+1.2,1/60)
 assert(not ctrl:isActive(p) and ctrl.count==0 and view.LocalTransparencyModifier==.2,kind..' nonlethal tail releases all geometry')
 -- More attributes from the same completed cycle must never replay it.
 p:SetAttribute('EffectPausedAt',0);p:SetAttribute('EffectDuration',duration+.01);ctrl:step(contact+1.3,1/60)
 assert(ctrl.count==0,kind..' same serial completion cannot replay')
 local restart=contact+1.4
 p:SetAttribute('EffectStartedAt',restart);p:SetAttribute('EffectDuration',duration);p:SetAttribute('EffectDoneAt',0);p:SetAttribute('EffectSerial',2)
 ctrl:step(restart,1/60);assert(ctrl.count>0 and ctrl.active[p].serial==2,kind..' repeats a new cycle on the same reservation')
 local finalAt=restart+duration*.68
 p:SetAttribute('EffectDepleted',true);p:SetAttribute('EffectDoneAt',finalAt)
 ctrl:step(finalAt+.1,1/60);assert(view.LocalTransparencyModifier==1,kind..' final contact conceals retired rock')
 ctrl:step(finalAt+1.2,1/60);assert(ctrl.count==0 and ctrl:isActive(p) and view.LocalTransparencyModifier==1,kind..' final retired hold prevents fracture-queue flash')
 dispose(p);assert(ctrl.count==0,kind..' retirement cleanup');checks+=1
 now+=20
 local cancelled=resource(kind,now);ctrl:step(now+.1,1/60)
 cancelled:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+.2,1/60)
 assert(ctrl.count==0 and views[cancelled].LocalTransparencyModifier==.2 and cancelled.LocalTransparencyModifier==1,kind..' cancellation restores only local view')
 dispose(cancelled);checks+=1
end

-- Every visible action advances at render frequency and agrees at equal absolute
-- times after 30/60/144 FPS histories; no 30 Hz cosmetic update throttle remains.
for kind,duration in pairs(durations) do
 local baseline
 for _,fps in ipairs({30,60,144}) do
  local p=resource(kind,now);local start=now;local dt=1/fps
  local function advance(seconds)
   local cursor=start
   while cursor+dt<start+seconds do cursor+=dt;ctrl:step(cursor,dt) end
   ctrl:step(start+seconds,dt)
  end
  advance(duration*.41)
  local e=assert(ctrl.active[p]);local before=ctrl.poseUpdates
  ctrl:step(start+duration*.41+dt,dt)
  assert(ctrl.poseUpdates>before,kind..' advances every '..fps..' FPS render frame')
  advance(duration*.59)
  local signature={}
  for i,part in ipairs(e.parts) do signature[i]={part.Position,part.Size,part.Transparency} end
  if baseline then
   for i,entry in ipairs(signature) do
    assert((entry[1]-baseline[i][1]).Magnitude<.00001 and (entry[2]-baseline[i][2]).Magnitude<.00001 and math.abs(entry[3]-baseline[i][3])<.00001,kind..' equal pre-contact observer pose at '..fps..' FPS')
   end
  else baseline=signature end
  p:SetAttribute('EffectDoneAt',start+duration*.68)
  advance(duration*.68+.2);finite(e,kind)
  local chip=e.fragments[1].Position
  -- Repeated evaluations do not accumulate displacement or replay impulses.
  ctrl:step(start+duration*.68+.2,dt)
  assert((e.fragments[1].Position-chip).Magnitude<.000001,kind..' timestamp evaluation is idempotent')
  p:SetAttribute('EffectCancelledSerial',1);ctrl:step(start+duration+1,dt);dispose(p)
 end
 checks+=1
end

local waiting=resource('Bubbler',now,true);ctrl:step(now+.1,1/60);assert(ctrl.count==0,'waits for local streamed resource view')
local waitedView=waiting:Clone();waitedView.LocalTransparencyModifier=.3;waitedView.Parent=visibleRoot;views[waiting]=waitedView
ctrl:step(now+.3,1/60);assert(ctrl.count>0 and waitedView.LocalTransparencyModifier==1,'view arrival retries without a new source packet')
waiting:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+.4,1/60);assert(waitedView.LocalTransparencyModifier==.3,'streamed view transparency restored');dispose(waiting);checks+=1

local paused=resource('Halver',now);ctrl:step(now+1,1/60);paused:SetAttribute('EffectPausedAt',now+1)
local held=ctrl.active[paused];local before=held.jaws[1].Position
ctrl:step(now+100,1/60);assert(ctrl.active[paused]==held and (held.jaws[1].Position-before).Magnitude<.000001,'pause does not expire or advance work')
paused:SetAttribute('EffectStartedAt',now+99);paused:SetAttribute('EffectPausedAt',0);ctrl:step(now+100,1/60)
assert(ctrl.active[paused]==held and (held.jaws[1].Position-before).Magnitude<.000001,'resume shifts timeline without rebuilding geometry')
local hitAt=now+99+durations.Halver*.68;paused:SetAttribute('EffectDoneAt',hitAt)
ctrl:step(hitAt+.12,1/60);paused:SetAttribute('EffectPausedAt',hitAt+.12);local chip=held.fragments[1].Position
ctrl:step(hitAt+50,1/60);assert((held.fragments[1].Position-chip).Magnitude<.000001,'post-impact recovery freezes during save')
paused:SetAttribute('EffectStartedAt',now+99+49.88);paused:SetAttribute('EffectDoneAt',hitAt+49.88);paused:SetAttribute('EffectPausedAt',0)
ctrl:step(hitAt+50,1/60);assert((held.fragments[1].Position-chip).Magnitude<.000001,'post-impact save resume preserves chip trajectories')
paused:SetAttribute('EffectCancelledSerial',1);ctrl:step(hitAt+51,1/60);dispose(paused);checks+=1

local cancelledFinal=resource('Gridcutter',now);ctrl:step(now+.1,1/60)
local oldView=views[cancelledFinal];oldView.Transparency=0 -- ordinary fracture queue still shows its old stage
cancelledFinal:SetAttribute('EffectDepleted',true);cancelledFinal:SetAttribute('EffectDoneAt',now+durations.Gridcutter*.68)
cancelledFinal:SetAttribute('EffectCancelledSerial',1);cancelledFinal:SetAttribute('EffectType',nil)
ctrl:step(now+durations.Gridcutter*.68+.01,1/60)
assert(ctrl.count==0 and ctrl:isActive(cancelledFinal) and oldView.LocalTransparencyModifier==1,'recall/death after final hit frees effects without flashing old fracture stage')
ctrl:step(now+100,1/60);assert(oldView.LocalTransparencyModifier==1,'depleted tombstone survives paused source cleanup')
dispose(cancelledFinal);assert(oldView.LocalTransparencyModifier==.2,'source removal restores original local transparency');checks+=1

local old=resource('Bubbler',0);old:SetAttribute('EffectDoneAt',2.8*.68);ctrl:step(now,1/60);assert(ctrl.count==0,'late join skips expired contact');dispose(old);checks+=1
local invisible=resource('Bubbler',now);views[invisible].Transparency=1;ctrl:step(now+.1,1/60);assert(ctrl.count==0,'locked progression rock stays hidden');dispose(invisible);checks+=1
local crowded={};for i=1,20 do crowded[i]=resource('Resonator',now) end
ctrl:step(now+.1,1/60);assert(ctrl.count<=360,'global geometry budget')
for _,p in ipairs(crowded) do p:SetAttribute('EffectCancelledSerial',1) end
ctrl:step(now+.2,1/60);assert(ctrl.count==0,'crowded cancellation frees all geometry')
for _,p in ipairs(crowded) do dispose(p) end;checks+=1
local streamed=resource('Gridcutter',now);ctrl:step(now+.1,1/60);dispose(streamed);assert(ctrl.count==0,'stream out cleanup');checks+=1
local final=resource('Frostbite',now);ctrl:step(now+.1,1/60);ctrl:destroy();assert(ctrl.destroyed and views[final].LocalTransparencyModifier==.2 and final.LocalTransparencyModifier==1,'destroy restores visible view only');checks+=1
print(checks..' specialist chunk FX lifecycle and 30/60/144 FPS timeline checks passed (API doubles; rendering NOT VERIFIED)')
