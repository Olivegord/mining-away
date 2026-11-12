-- The production resolver owns impact timing, rock eligibility and rewards.
local function checkNomad()
 local owner=player(195030);players.PlayerAdded:Fire(owner)
 local p=assert(profiles[owner.UserId])
 local field=patches[1];field.resources={}
 owner.Character:PivotTo(CFrame.new(field.center+Vector3.new(0,3,0)))
 local d=p.drones[1];d.role='Nomad'
 local function rock(x,z,kind)
  local r=makeResource(field,field.center+Vector3.new(x,0,z),kind or 'Crystal',810,10,3)
  r.readyAt=now;return r
 end
 local primary=rock(0,0)
 local nearest={rock(2,0),rock(4,0),rock(5,0),rock(7,0)}
 local extra=rock(11,0)
 local distant=rock(16,0)
 local reserved=rock(0,3)
 local behindWall=rock(0,4)
 local geode=rock(0,5,'Geode')
 local growing=rock(0,6);growing.readyAt=now+100
 local foreign=player(195031);players.PlayerAdded:Fire(foreign)
 local other=profiles[foreign.UserId].drones[1]
 reserved.slots[other.id]=1
 release(d);d.target=primary;d.targetSlot=1;d.field=field.id;primary.slots[d.id]=1
 local spec=DroneCatalog.Types.Nomad
 d.pos=primary.position+Vector3.new(4,spec.StationHeight,0)
 local receipt=RoleEffects.Projectile('Nomad',d.pos,primary.position,Color3.new(1,1,1),now,spec.Windup,spec.Flight,d.id,primary.id)
 local job={startedAt=now,duration=spec.CycleDuration,impact=spec.Impact,projectile=receipt,serial=1,
  from=d.pos,contact=primary.position,targetId=primary.id}
 d.specialJob=job
 local barrier=Instance.new('Part');barrier.Parent=workspace
 local pathBlocked=true
 function workspace:Raycast(from,delta)
  if (pathBlocked and delta.Y<-10) or (from+delta-behindWall.part.Position).Magnitude<.01 then
   return {Instance=barrier,Position=from+delta*.5,Normal=Vector3.yAxis}
  end
  return nil
 end
 assert(not scene.fireNomad(d,primary,job) and not receipt:GetAttribute('ContactAt'))
 assert(not hitResource(d,nearest[1],810,false,nil,nil,'NomadFinish'))
 now=now+5.01
 assert(not scene.fireNomad(d,primary,job) and not primary.paid,'obstruction did not stop the rocket')
 pathBlocked=false
 p.busy=true
 assert(not scene.fireNomad(d,primary,job),'a paused job awarded ore')
 p.busy=false
 local before=pickupSerial
 assert(scene.fireNomad(d,primary,job))
 assert(receipt:GetAttribute('ContactAt')==now and receipt:GetAttribute('BlastRadius')==13)
 assert(primary.paid and primary.part:GetAttribute('CrystalSplitAt')==now)
 for _,r in ipairs(nearest) do
  assert(r.paid and r.part:GetAttribute('CutProjectile')=='Nomad' and r.part:GetAttribute('CrystalSplitAt')==now)
  assert(not r.prismShot,'the finished rock kept its blast reservation')
 end
 for _,r in ipairs({extra,distant,reserved,behindWall,geode,growing}) do assert(not r.paid and r.hp==800) end
 assert(pickupSerial>before and d.nomadReadyAt>now)
 local after=pickupSerial
 assert(not scene.fireNomad(d,primary,job) and pickupSerial==after)
 local profile=Pro.new(195032,123)
 profile.run.quartzEarnings=Pro.milestone(profile).earnings
 local first=Pro.prestigePreview(profile)
 for _,choice in ipairs(first.droneChoices) do assert(choice.kind~='Nomad') end
 assert(Pro.prestige(profile,'initial',profile.run.id,{atDepot=true,confirmed=true,droneType=first.droneChoices[1].kind}))
 profile.run.quartzEarnings=Pro.milestone(profile).earnings
 local offer=Pro.prestigePreview(profile).droneChoices
 assert(#offer==3 and offer[2].kind=='Nomad' and offer[3].kind=='Ramiel')
 assert(Pro.prestige(profile,'nomad',profile.run.id,{atDepot=true,confirmed=true,droneType='Nomad'}))
 local owned=profile.fleet[#profile.fleet]
 local migrated=assert(Pro.migrate(profile,profile.userId))
 assert(migrated.fleet[#migrated.fleet].id==owned.id and owned.role=='Nomad')
 profile.run.quartzEarnings=Pro.milestone(profile).earnings
 for _,choice in ipairs(Pro.prestigePreview(profile).droneChoices) do assert(choice.kind~='Nomad') end
 print('PASS Nomad strike timing, blocked paths, five-rock limit, crew reservations, ore, and permanent prestige ownership')
end
checkNomad()
