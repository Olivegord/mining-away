-- Run the production resolver with a deterministic raycast double. Roblox
-- supplies mesh intersections in-game; this fixture verifies their handling.
local function checkPrism()
 local owner=player(195020);players.PlayerAdded:Fire(owner)
 local p=assert(profiles[owner.UserId])
 local field=patches[1]
 owner.Character:PivotTo(CFrame.new(field.center+Vector3.new(0,3,0)))
 local drone=p.drones[1];drone.role='Ramiel'
 local function make(offset)
  local rock=makeResource(field,field.center+Vector3.new(offset,0,0),'Crystal',810,10,3)
  rock.readyAt=now;return rock
 end
 local target,second,third,guarded,behind,offRay=make(0),make(5),make(10),make(15),make(20),make(23)
 local foreign=player(195021);players.PlayerAdded:Fire(foreign)
 local worker=profiles[foreign.UserId].drones[1]
 guarded.slots[worker.id]=1
 release(drone);drone.target=target;drone.targetSlot=1;drone.field=field.id
 target.slots[drone.id]=1
 drone.pos=target.position+Vector3.new(-32,2.8,0);drone.workStation=drone.pos
 local receipt=RoleEffects.Projectile('Prism',drone.pos,target.position,Color3.new(1,0,0),now-5,4.94,.06,drone.id,target.id)
 drone.specialJob={targetId=target.id,startedAt=now-6,duration=7.75,impact=.645,damage=300,serial=1,projectile=receipt}
 local entries={target,second,third,guarded,behind}
 local wall,wallNormal
 local function distance(i) return 35+(i-1)*4 end
 function workspace:Raycast(from,delta,params)
  assert(delta.Magnitude<=64+.001,'Prism cast beyond its range')
  for i,rock in ipairs(entries) do
   if not table.find(params.FilterDescendantsInstances,rock.part) and distance(i)<=delta.Magnitude then
    return {Instance=rock.part,Position=from+delta.Unit*distance(i),Normal=rock.part==wall and wallNormal or -delta.Unit}
   end
  end
 end
 assert(not hitResource(drone,second,300,false,nil,nil,'PrismPass'),'pass without a ray contact was accepted')
 assert(scene.firePrism(drone,target,drone.specialJob),'valid path did not fire')
 local damage={800-target.hp,800-second.hp,800-third.hp}
 assert(damage[1]>damage[2] and damage[2]>damage[3] and damage[3]>0,'piercing falloff was lost')
 assert(guarded.hp==800 and behind.hp==800 and offRay.hp==800,'shot damaged reserved or off-axis rock')
 assert(receipt:GetAttribute('ContactAt')==now and receipt:GetAttribute('PrismHits')==2)
 local origin,endpoint=receipt:GetAttribute('PrismFrom'),receipt:GetAttribute('PrismEnd')
 assert(math.abs((endpoint-origin).Magnitude-distance(4))<.001,'path did not stop at the reserved rock')
 assert(receipt:GetAttribute('PrismHit1') and receipt:GetAttribute('PrismHit2') and not receipt:GetAttribute('PrismHit3'))
 assert(not scene.firePrism(drone,target,drone.specialJob),'a confirmed job fired a second time')
 guarded.slots[worker.id]=nil
 local clear=assert(scene.prismTrace(drone,target,drone.pos,false))
 assert(#clear.hits==4 and math.abs((clear.endpoint-clear.origin).Magnitude-distance(5))<.001,'target limit failed to stop the path')
 wall=Instance.new('Part');wall.CanCollide=true;wall.Parent=workspace
 entries={target,{part=wall},third}
 local blocked=assert(scene.prismTrace(drone,target,drone.pos,false))
 assert(#blocked.hits==1 and math.abs((blocked.endpoint-blocked.origin).Magnitude-distance(2))<.001,'solid scenery did not stop the path')
 assert(not blocked.groundNormal,'a side wall was treated as ground')
 wallNormal=Vector3.yAxis
 local ground=assert(scene.prismTrace(drone,target,drone.pos,false))
 assert(ground.groundNormal==wallNormal,'the renderer cannot identify the real ground contact')
 print('PASS Ramiel server ray applies ordered falloff, respects occupancy and scenery, and publishes one full shot')
end
checkPrism()
