-- The production resolver owns impact timing, rock eligibility and rewards.
local function checkNomad()
 local owner=player(195030);players.PlayerAdded:Fire(owner)
 local p=assert(profiles[owner.UserId])
 local bed=World.part(scene.map,'NomadTestField',Vector3.new(0,5,222),Vector3.new(108,1,64),Color3.new(1,0,0))
 local field={id=#patches+1,cfg={Key='Quartz',Value=1,SelectionOnly=true,AlwaysUnlocked=true,ReferenceCrystals=true,
  Hardness=1,Count=48,Ore=10,Turrets=0,Respawn=8},part=bed,model=scene.map,center=bed.Position,color=bed.Color,
  resources={},turrets={},respawnQueue={},e=R.newEncounter(C)}
 patches[field.id]=field
 owner.Character:PivotTo(CFrame.new(field.center+Vector3.new(0,3,0)))
 local ownedNomad=Pro.clone(p.drones[1].owned)
 ownedNomad.id='nomad:test';ownedNomad.type='Nomad';ownedNomad.role='Nomad'
 local d=spawnDrone(p,ownedNomad,#p.drones+1)
 for _,part in ipairs(d.model:GetDescendants()) do
  if part:IsA('BasePart') then assert(part.Transparency==1 and not part.CanQuery) end
 end
 local function rock(x,z,kind)
  local r=makeResource(field,field.center+Vector3.new(x,0,z),kind or 'Crystal',810,10,3)
  r.readyAt=now;return r
 end
 local exposed={}
 for x=-50,50,10 do
  for z=-27,27,18 do exposed[#exposed+1]=rock(x,z) end
 end
 local reserved=rock(0,3)
 local behindCover=rock(0,4)
 local geode=rock(0,5,'Geode')
 local growing=rock(0,6);growing.readyAt=now+100
 local otherField=patches[1]
 local outside=makeResource(otherField,otherField.center,'Crystal',810,10,3)
 outside.readyAt=now
 local foreign=player(195031);players.PlayerAdded:Fire(foreign)
 local other=profiles[foreign.UserId].drones[1]
 reserved.slots[other.id]=1
 local allied=p.drones[1]
 allied.target=exposed[2];exposed[2].slots[allied.id]=1
 local spec=DroneCatalog.Types.Nomad
 local start=d.pos
 droneStep(d,1/60)
 assert(d.state=='Patrol' and not d.target and not d.nomadJob)
 assert((start-home).Magnitude>570 and start.Y==home.Y+spec.StationHeight and spec.StationHeight>=400)
 assert((Feel.nomadPatrol(home,spec.StationHeight,d.slot,d.owner,now+56)-start).Magnitude>1100)
 p.miningSquare={field=field,center=field.center,half=5}
 local peak=0
 for _=1,60*35 do
  now+=1/60
  droneStep(d,1/60)
  peak=math.max(peak,d.velocity.Magnitude)
  if d.nomadJob and d.nomadJob.projectile then break end
 end
 local job=assert(d.nomadJob)
 local receipt=assert(job.projectile)
 assert(peak<=75.001 and not d.target and d.state=='SpecialMine')
 assert(job.from.Y-job.contact.Y==spec.StationHeight)
 assert((job.scanFrom-job.from).Magnitude>job.radius and receipt:GetAttribute('ScanFrom')==job.scanFrom)
 assert((Feel.nomadPass(job.scanFrom,job.from,.36)-job.from).Magnitude>10)
 assert(Feel.nomadPass(job.scanFrom,job.from,.72)==job.from)
 assert(job.windup>17 and receipt:GetAttribute('Windup')==job.windup)
 local step=1/60
 local previous=job.scanFrom
 for i=1,math.ceil(job.windup/step) do
  local point=Feel.nomadPass(job.scanFrom,job.from,i*step/job.windup)
  assert((point-previous).Magnitude/step<=spec.ScanSpeed+.01,'Nomad passed the field too fast')
  previous=point
 end
 local barrier=Instance.new('Part');barrier.Parent=workspace
 local pathBlocked=true
 function workspace:Raycast(from,delta)
  local finish=from+delta
  if delta.Y< -10 and ((pathBlocked and (finish-job.contact).Magnitude<.01)
   or math.abs(finish.X-behindCover.part.Position.X)+math.abs(finish.Z-behindCover.part.Position.Z)<.01) then
   return {Instance=barrier,Position=from+delta*.5,Normal=Vector3.yAxis}
  end
  return nil
 end
 assert(not scene.fireNomad(d,field,job) and not receipt:GetAttribute('ContactAt'))
 assert(not hitResource(d,exposed[1],810,false,nil,nil,'NomadFinish'))
 now=job.startedAt+1
 setMotionPaused(p,true)
 assert(receipt:GetAttribute('PausedAt')==now)
 now+=2
 setMotionPaused(p,false)
 assert(receipt:GetAttribute('PausedAt')==0 and receipt:GetAttribute('StartedAt')==job.startedAt)
 now=job.startedAt+spec.Windup+spec.Flight+.01
 assert(not scene.fireNomad(d,field,job),'Nomad struck before the slower approach finished')
 now=job.startedAt+job.windup+spec.Flight+.01
 assert(not scene.fireNomad(d,field,job) and not exposed[1].paid,'obstruction did not stop the strike')
 pathBlocked=false
 p.busy=true
 assert(not scene.fireNomad(d,field,job),'a paused job awarded ore')
 p.busy=false
 local before=pickupSerial
 droneStep(d,1/60)
 local contactAt=now
 assert(receipt:GetAttribute('ContactAt')==contactAt and receipt:GetAttribute('BlastRadius')==job.radius and job.impacted)
 now=contactAt+spec.BlastPause-.001
 scene.stepClusterShots()
 assert(pickupSerial==before and not receipt:GetAttribute('ShatterAt'))
 for _,r in ipairs(exposed) do
  assert(r.hp==800 and r.clusterShot and r.part:GetAttribute('ClusterBlackAt')==contactAt)
  assert(not sameRockType(other,r))
 end
 now=contactAt+spec.BlastPause+.001
 p.busy=true;scene.stepClusterShots()
 assert(not exposed[1].paid and exposed[1].clusterShot and pickupSerial==before)
 p.busy=false;scene.stepClusterShots()
 assert(receipt:GetAttribute('ShatterAt')==now)
 for _,r in ipairs(exposed) do
  assert(r.paid and r.part:GetAttribute('CutProjectile')=='Nomad' and r.part:GetAttribute('CrystalSplitAt')==now)
  assert(not r.clusterShot,'the finished rock kept its blast reservation')
 end
 for _,r in ipairs({reserved,behindCover,geode,growing,outside}) do assert(not r.paid and r.hp==800) end
 assert(pickupSerial>before and d.nomadReadyAt==contactAt+spec.Cooldown and not allied.target)
 local after=pickupSerial
 scene.stepClusterShots()
 assert(not scene.fireNomad(d,field,job) and pickupSerial==after)
 droneStep(d,1/60)
 assert(not d.nomadJob and d.state=='Patrol','a finished pass must go back to patrol')
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
 print('PASS Nomad invisible patrol, side entry, delayed field shatter, claims, cover, ore and prestige ownership')
end
checkNomad()
