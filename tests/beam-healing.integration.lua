-- Exercises the actual Client.renderHealing function, including its ray cap.
local camera=Instance.new('Camera');camera.CFrame=CFrame.new(0,4,10);workspace.CurrentCamera=camera
local function drone(id,position)
 local source=Instance.new('Folder');source.Parent=world
 source:SetAttribute('DroneId',id);source:SetAttribute('HP',100);source:SetAttribute('Life',1)
 local view=Instance.new('Model');view.Parent=localFX
 local emitter=Instance.new('Part');emitter.Position=position;emitter.Parent=view
 local d={source=source,view=view,emitter=emitter};drones[id]=d;droneIndex[id]=d
 return d
end
local medic=drone('medic',Vector3.new(0,7,0));local target=drone('target',Vector3.new(3,7,0))
medic.source:SetAttribute('HealTargetId','target');medic.source:SetAttribute('State','RepairCharge')
medic.source:SetAttribute('RepairChargeAt',10);medic.source:SetAttribute('RepairChargeDuration',.4)
local blocked=false;local rays=0
workspace.Raycast=function() rays+=1;return blocked and {Instance=world} or nil end
renderHealing(10.2)
local rig=assert(medic.healVFX);assert(rig.body.Enabled and medic.healBeam.Transparency==1)
local chargingWidth=rig.body.Width0;assert(chargingWidth<.13 and rays<=4)
medic.source:SetAttribute('State','Repair');medic.source:SetAttribute('Healing',true)
target.emitter.Position=Vector3.new(6,8,0);renderHealing(10.3)
assert(medic.healVFX==rig and rig.body.Width0>chargingWidth)
assert((rig.root.Position+rig.b.Position-target.emitter.Position).Magnitude<1e-6,'healing endpoint detached')
blocked=true;renderHealing(10.4);assert(not rig.body.Enabled,'blocked healer kept showing a tether')
blocked=false;renderHealing(10.5);assert(rig.body.Enabled)
medic.source:SetAttribute('WorkPaused',true);renderHealing(10.6);assert(medic.healVFX==nil and rig.root.Parent==nil)
medic.source:SetAttribute('WorkPaused',false);renderHealing(10.7);assert(medic.healVFX)
target.source:SetAttribute('HP',0);renderHealing(10.8);assert(medic.healVFX==nil)
-- Crowded observers share four checks; stale secondary visuals expire.
target.source:SetAttribute('HP',100)
for i=1,12 do
 local d=drone('other'..i,Vector3.new(i*.2,7,0));d.source:SetAttribute('HealTargetId','target');d.source:SetAttribute('Healing',true)
end
for frame=1,30 do
 rays=0;renderHealing(11+frame/60);assert(rays<=4)
end
localFX:Destroy();world:Destroy();local live,detail=BeamVFX.counts();assert(live==0 and detail==0)
print('PASS actual client repair charge, moving endpoints, obstruction, pause, target death, repeated activation and four-ray crowd limit')
