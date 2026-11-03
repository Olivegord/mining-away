-- Exercise the production DroneFX module supplied by the runner.
CF.Rotation=CFrame.new()
local world=Instance.new('Folder');world.Parent=workspace
local visibleRoot=Instance.new('Folder');visibleRoot.Parent=workspace
local views={};local ctrl=DroneFX.new(world,{resolve=function(source) return views[source] end})
local durations={Bubbler=4.2,Halver=8,Gridcutter=5,Singularity=2.4,Starforge=5,Frostbite=5.5,Resonator=4.8}
local checks=0
local function resource(kind,start,noView)
 local p=Instance.new('Part');p.Name='Crystal';p.Size=Vector3.new(4,5,3);p.Position=Vector3.new(0,4,0);p.Material=Enum.Material.Slate;p.LocalTransparencyModifier=1;p.Parent=world
 p:SetAttribute('ResourceId','test');p:SetAttribute('FullSize',p.Size);p:SetAttribute('EffectType',kind);p:SetAttribute('EffectStartedAt',start);p:SetAttribute('EffectDuration',durations[kind]);p:SetAttribute('EffectSerial',1)
 if not noView then local view=p:Clone();view.Position=Vector3.new(10,4,0);view.LocalTransparencyModifier=.2;view.Parent=visibleRoot;views[p]=view end
 return p
end
local now=20
for kind,duration in pairs(durations) do
 local p=resource(kind,now);local view=views[p]
 for j=0,100 do
  ctrl:step(now+duration*j/100,.02)
  assert(ctrl.count>0 and ctrl.count<=48,kind..' bounded geometry')
  assert(view.LocalTransparencyModifier==1 and p.LocalTransparencyModifier==1,kind..' hides view, preserves source')
  for _,fx in ipairs(ctrl.folder:GetDescendants()) do
   if fx:IsA('BasePart') then assert(fx.Size.X>0 and fx.Size.Y>0 and fx.Size.Z>0 and fx.Position.Magnitude==fx.Position.Magnitude,kind..' finite geometry') end
  end
 end
 p:SetAttribute('EffectDoneAt',now+duration)
 ctrl:step(now+duration+.1,.1);assert(ctrl.count>0,kind..' completion tail')
 ctrl:step(now+duration+1.2,.1);assert(ctrl.count==0 and view.LocalTransparencyModifier==1 and ctrl:isActive(p),kind..' retirement hold prevents fracture flash')
 p:Destroy();assert(view.LocalTransparencyModifier==.2 and not ctrl:isActive(p),kind..' source retirement cleanup');view:Destroy();checks=checks+1
 now=now+20
 local cancelled=resource(kind,now);local cancelledView=views[cancelled]
 ctrl:step(now+.1,.1);cancelled:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+.2,.1)
 assert(ctrl.count==0 and cancelledView.LocalTransparencyModifier==.2,kind..' cancellation restore');assert(cancelled.LocalTransparencyModifier==1,'must preserve authoritative collider')
 cancelled:Destroy();cancelledView:Destroy();checks=checks+1
end
local waiting=resource('Bubbler',now,true);ctrl:step(now+.1,.1);assert(ctrl.count==0,'awaits local resource view');checks=checks+1
local waitedView=waiting:Clone();waitedView.LocalTransparencyModifier=.3;waitedView.Parent=visibleRoot;views[waiting]=waitedView
ctrl:step(now+.2,.1);assert(ctrl.count>0 and waitedView.LocalTransparencyModifier==1,'view arrival without source attr update');checks=checks+1
waiting:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+.3,.1);assert(waitedView.LocalTransparencyModifier==.3,'view wait original transparency retained');waiting:Destroy();waitedView:Destroy();checks=checks+1
local paused=resource('Halver',now);ctrl:step(now+2.4,.1);paused:SetAttribute('EffectPausedAt',now+2.4)
local before=ctrl.active[paused].fragments[1].Position
ctrl:step(now+100,.1);assert(ctrl.count>0,'pause does not expire');assert((ctrl.active[paused].fragments[1].Position-before).Magnitude<.0001,'pause pose frozen');checks=checks+1
paused:SetAttribute('EffectStartedAt',now+97.6);paused:SetAttribute('EffectPausedAt',0);ctrl:step(now+100,.1)
assert((ctrl.active[paused].fragments[1].Position-before).Magnitude<.0001,'resume start shift preserves pose');checks=checks+1
paused:SetAttribute('EffectCancelledSerial',1);ctrl:step(now+100.1,.1);paused:Destroy();views[paused]:Destroy()
local old=resource('Bubbler',0);old:SetAttribute('EffectDoneAt',4.2);ctrl:step(now,.1);assert(ctrl.count==0,'late join skips old payout');old:Destroy();views[old]:Destroy();checks=checks+1
local invisible=resource('Bubbler',now);views[invisible].Transparency=1;ctrl:step(now+.1,.1);assert(ctrl.count==0,'hidden progression rock stays hidden');invisible:Destroy();views[invisible]:Destroy();checks=checks+1
local crowded={}
for i=1,20 do crowded[i]=resource('Resonator',now) end
ctrl:step(now+.1,.1);assert(ctrl.count<=360,'shared budget');checks=checks+1
for _,p in ipairs(crowded) do p:SetAttribute('EffectCancelledSerial',1) end
ctrl:step(now+.2,.1);assert(ctrl.count==0,'all crowded effects cancel');checks=checks+1
for _,p in ipairs(crowded) do p:Destroy();views[p]:Destroy() end
local streamed=resource('Gridcutter',now);ctrl:step(now+.1,.1);streamed:Destroy();assert(ctrl.count==0,'stream out cleanup');views[streamed]:Destroy();checks=checks+1
local final=resource('Frostbite',now);ctrl:step(now+.1,.1);ctrl:destroy();assert(ctrl.destroyed and views[final].LocalTransparencyModifier==.2 and final.LocalTransparencyModifier==1,'destroy restores visible view only');checks=checks+1
print(checks..' latest-client FX lifecycle API-double checks passed (not Roblox rendering validation)')
