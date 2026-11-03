-- Count writes in the actual production FX module, never a copied implementation.
local writes=0;local originalWrite=IT.__newindex;local effectRoot
IT.__newindex=function(object,key,value)
 if effectRoot and object:IsDescendantOf(effectRoot) and (key=='CFrame' or key=='Position' or key=='Size' or key=='Transparency' or key=='Color') then writes+=1 end
 return originalWrite(object,key,value)
end
local world=Instance.new('Folder');world.Parent=workspace
local visible=Instance.new('Folder');visible.Parent=workspace
local views={}
local ctrl=DroneFX.new(world,{resolve=function(v)return views[v] end})
effectRoot=ctrl.folder
workspace.CurrentCamera={CFrame=CFrame.new(0,8,12)}
for index,kind in ipairs({'Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'}) do
 local r=Instance.new('Part');r.Name='Crystal';r.Position=Vector3.new(index,4,0);r.Size=Vector3.new(4,4,4)
 for key,value in pairs({ResourceId=kind,EffectSerial=1,EffectType=kind,EffectStartedAt=20,EffectDuration=5})do r:SetAttribute(key,value)end
 local v=r:Clone();v.LocalTransparencyModifier=.2;v.Parent=visible;views[r]=v;r.Parent=world
end
for _=1,1000 do local scenery=Instance.new('Part');scenery.Name='Scenery';scenery.Parent=world;scenery:SetAttribute('Position',Vector3.zero)end
ctrl:step(20,0);writes=0
for frame=1,144 do ctrl:step(20+frame/144,1/144)end
print('METRIC','fx144',writes)
if ctrl.retry then
 local tracked=0;for _ in pairs(ctrl.tracked)do tracked+=1 end
 assert(tracked==7,'unrelated scenery was subscribed by mining FX')
 assert(ctrl.poseUpdates<=7*32,'multi-part effects exceeded 30 updates per second')
 local previous=ctrl.poseUpdates
 for r in pairs(views)do r:SetAttribute('HP',50);assert(not ctrl.dirty[r],'ordinary HP snapshots dirtied effect construction')end
 workspace.CurrentCamera.CFrame=CFrame.new(10000,8,12);ctrl:step(21.1,.1)
 assert(ctrl.count==0,'distant jobs retained geometry')
 for _,v in pairs(views)do assert(v.LocalTransparencyModifier==.2,'distance culling failed to restore rock')end
 workspace.CurrentCamera.CFrame=CFrame.new(0,8,12);ctrl:step(21.4,.1);assert(ctrl.count>0,'visible ongoing jobs did not return')
 assert(ctrl.poseUpdates>previous)
end
ctrl:destroy();assert(ctrl.count==0)
print(ctrl.retry and 'PASS production FX bounded cadence, scenery filtering, distance return and cleanup; API doubles only' or 'Recorded original FX write load for comparison')
