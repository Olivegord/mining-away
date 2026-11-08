-- Production server mechanics under API doubles; real damage/rewards/transactions.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS Quartz server '..name) end
RoleEffects.BreakerPhase=function() end;discoveries.TrySpawn=function() end
local pl=player(310001);players.PlayerAdded:Fire(pl);local p=assert(profiles[pl.UserId]);local field=patches[1]
check('new miners spawn in the four-slot reference formation',function()
 local origin=characterRoot(p).Position
 local offsets={Vector3.new(0,0,10),Vector3.new(-10,0,0),Vector3.new(0,0,-10),Vector3.new(10,0,0)}
 for slot,d in ipairs(p.drones) do
  local offset=d.pos-origin
  assert((Vector3.new(offset.X,0,offset.Z)-offsets[slot]).Magnitude<1e-6,'starter fleet did not spawn in the reference ring')
  assert(math.abs(offset.Y-7)<=1/3 and d.state=='Follow')
 end
end)
local function input(action,payload) p.tokens=7;p.bucketAt=now;command.OnServerEvent:Fire(pl,action,payload) end
local function move(position) pl.Character:PivotTo(CFrame.new(position+Vector3.new(0,3,0))) end
local serial=0
local function quote(extra)
 serial+=1;local q={txId='quartz:'..serial,runId=data(p).run.id};for k,v in pairs(extra or {}) do q[k]=v end;return q
end
local function tick()
 realTime+=C.Tick;now=realTime
 for _,d in ipairs(p.drones) do droneStep(d,C.Tick) end
 pickupStep(C.Tick)
end
local function sell() move(scene.converter.Position);input('Sell') end
check('the starter field starts with sixteen scattered full-size crystals',function()
 local originalRng=seed
 local crystal=Instance.new('UnionOperation')
 crystal.Size=Vector3.new(3.135,6.566902,4.487231)
 scene.classicCrystal=crystal
 field.part.Size=Vector3.new(unpack(field.cfg.Size))
 for roll=1,24 do
  seed=Random.new(roll)
  seedField(field)
  assert(nodeUsage(field)==16,'starter field did not fill at seed '..roll)
  local occupied={}
  for _,r in ipairs(field.resources) do
   local site=field.part.CFrame:PointToObjectSpace(r.position)
   assert(site.X%1==0 and site.Z%1==0 and math.abs(site.X)<=15 and math.abs(site.Z)<=15 and math.abs(site.Y-3)<1e-5)
   for _,other in ipairs(occupied) do assert((Vector3.new(site.X,0,site.Z)-other).Magnitude>=2) end
   table.insert(occupied,Vector3.new(site.X,0,site.Z))
   assert(r.maxHP>=50 and r.maxHP<=100 and r.hp==r.maxHP-10 and r.readyAt==r.spawnAt+2)
   assert(r.part.ClassName=='UnionOperation' and r.limit==1 and r.stageCount==3)
   assert((r.fullSize-crystal.Size).Magnitude<.0001)
   assert(r.part.Color.R==1 and r.part.Color.G==0 and r.part.Color.B==0 and r.part.Material==Enum.Material.Ice and r.part.Transparency==.2)
   assert(r.part:GetAttribute('Mineral')=='Quartz' and r.ore==10)
  end
 end
 seed=originalRng
end)
check('the reference crystal stays full size and respawns after eight seconds with four workers',function()
 move(field.center)
 local r=field.resources[1]
 r.readyAt=now
 local miner=p.drones[1]
 assert(assignOre(p,miner,r));miner.pos=committedStation(miner,r);miner.mining=true
 assert(hitResource(miner,r,r.maxHP*.26) and r.stage==1 and (r.part.Size-r.fullSize).Magnitude==0)
 local brokenAt=now
 local before={};for _,rock in ipairs(field.resources) do before[rock.id]=true end
 assert(hitResource(miner,r,1000) and r.paid and r.removeAt==brokenAt+2)
 for _,drone in ipairs(p.drones) do drone.field=field.id end
 local rate,count=respawnRate(field);assert(rate==1 and count==4)
 assert(field.respawnQueue[1]==brokenAt+8)
 local function advance(seconds)
  for _=1,math.floor(seconds/C.Tick+.5) do realTime+=C.Tick;heartbeat:Fire(C.Tick) end
 end
 advance(7.8)
 assert(nodeUsage(field)==15 and not r.part.Parent,'replacement spawned early or broken crystal lingered')
 advance(.4)
 assert(nodeUsage(field)==16,'replacement was late')
 local replacement
 for _,rock in ipairs(field.resources) do if not before[rock.id] then replacement=rock;break end end
 assert(replacement and replacement.spawnAt>=brokenAt+8 and replacement.readyAt==replacement.spawnAt+2)
 for _,drone in ipairs(p.drones) do leaveDroneField(p,drone) end
 -- Isolate the paid-packs fixture from the ore earned in this timing case.
 data(p).run.cargo={}
 for id,drop in pairs(pickups) do if drop.owner==pl.UserId then drop.part:Destroy();pickups[id]=nil end end
end)
for _,r in ipairs(field.resources) do r.paid=true;r.hp=0 end
local function mine()
 if Ca.capacity(data(p))-Pro.cargoUnits(data(p))<25 then sell() end
 move(field.center)
 local resource=Mining.resource(75,'Crystal',field.cfg.Hardness)
 local r=makeResource(field,field.center,'Crystal',resource.work,10,3);r.readyAt=now
 local before=Pro.cargoUnits(data(p));input('MineOre',r.id);local started=now
 for _=1,2400 do tick();if r.paid and pendingOre(p)==0 then break end end
 assert(r.paid and Pro.cargoUnits(data(p))>before,'real mining/collection produced no reward')
 return now-started
end
check('a single field order sends four workers to different rocks and retargets without a card',function()
 local main,mainProfile=pl,p
 pl=player(310009);players.PlayerAdded:Fire(pl);p=assert(profiles[pl.UserId]);move(field.center)
 local seeds={}
 for i,x in ipairs({-11,-4,4,11,-10,0,10}) do
  local r=makeResource(field,field.center+Vector3.new(x,0,i<=4 and -5 or 7),'Crystal',55,10,3)
  r.readyAt=now;seeds[i]=r
 end
 input('Patch',field.id);tick()
 local claimed={}
 for _,d in ipairs(p.drones) do
  assert(d.autoField==field.id and d.target and not claimed[d.target.id])
  claimed[d.target.id]=true
 end
 for _=1,1500 do
  tick()
  for _,r in ipairs(seeds) do
   if r.paid and not claimed[r.id] then
    input('Recall')
    for _,node in ipairs(seeds) do node.paid=true;node.hp=0 end
    players.PlayerRemoving:Fire(pl);pl,p=main,mainProfile
    return
   end
  end
 end
 error('No second wave of mining')
end)
local firstId,firstBase,offer,selected,baseTime
local beganAt=now
check('Studio and production both start with four permanent miners, zero Quartz, actual rocks',function()
 assert(#p.drones==4 and #data(p).fleet==4 and not p.testFleet)
 assert(data(p).run.wallet.Quartz==0 and Ca.capacity(data(p))==100)
 assert(data(p).run.quartzEarnings==0 and p.drones[1].stats.plotAuto==0)
 firstId=p.drones[1].id;firstBase=Pro.clone(data(p).fleet[1].base)
 baseTime=mine();mine();sell()
 assert(data(p).run.wallet.Quartz==20 and data(p).run.quartzEarnings==20)
end)
check('one paid pack from the combined Quartz counter, hidden saved choices and owned timed opening',function()
 local request=quote({packIndex=0});move(field.center);input('BuyPack',request);assert(not data(p).run.pendingOffer)
 move(shopStations.Quartz.Position);input('BuyPack',request);offer=Pro.clone(assert(data(p).run.pendingOffer))
 assert(offer.price==20 and data(p).run.wallet.Quartz==0 and #offer.choices==3)
 local published=Http:JSONDecode(pl:GetAttribute('MA_Profile'));assert(not published.run.pendingOffer.choices,'sealed options leaked')
 input('BuyPack',request);assert(data(p).run.wallet.Quartz==0 and data(p).run.packIndex==1)
 local delivery=assert(p.packDelivery);assert((delivery.part.Position-shopStations.Quartz.Position).Magnitude<16,'delivery did not use closest workshop counter')
 input('ChooseCard',quote({offerId=offer.id,index=1}));assert(#data(p).run.cards==0)
 realTime+=Packs.DeliveryTime+.1;now=realTime;packDelivery:step(p,now);move(delivery.part.Position)
 local intruder=player(310002);delivery.prompt.PromptButtonHoldBegan:Fire(intruder);assert(not delivery.start)
 delivery.prompt.PromptButtonHoldBegan:Fire(pl);delivery.prompt.Triggered:Fire(pl);assert(not data(p).run.pendingOffer.opened)
 delivery.prompt.PromptButtonHoldBegan:Fire(pl);realTime+=Packs.duration(offer.packTier)+.1;now=realTime;delivery.prompt.Triggered:Fire(pl)
 assert(data(p).run.pendingOffer.opened)
 local index=1
 for i,c in ipairs(offer.choices) do if c.cardId=='Q_POWER' or c.cardId=='Q_IGNITION' then index=i;break end end
 move(shopStations.Quartz.Position);input('ChooseCard',quote({offerId=offer.id,index=index}))
 selected=assert(data(p).run.cards[1]);assert(selected.level==1 and not data(p).run.pendingOffer)
 assert(p.drones[1].stats.miningDPS==Ca.stats(data(p),data(p).fleet[1]).miningDPS)
 print('DRAFT '..selected.cardId..' '..selected.rarity..' level '..selected.level)
end)
check('earned repeat purchase applies exactly once at either counter and refuses remote/legacy purchases',function()
 local cost=Workshop.levelCost(selected)
 while data(p).run.wallet.Quartz<cost do mine();sell() end
 local previous=data(p).run.wallet.Quartz;local earned=data(p).run.quartzEarnings
 local request=quote({upgradeId=selected.cardId,level=selected.level})
 move(field.center);input('BuyUpgrade',request);assert(data(p).run.wallet.Quartz==previous)
 move(scene.packStation.Position);input('BuyUpgrade',request)
 local upgraded=assert(Workshop.find(data(p),selected.cardId));assert(upgraded.level==selected.level+1 and data(p).run.wallet.Quartz==previous-cost)
 assert(data(p).run.quartzEarnings==earned)
 input('BuyUpgrade',request);assert(data(p).run.wallet.Quartz==previous-cost and Workshop.find(data(p),selected.cardId).level==selected.level+1)
 input('BuyUpgrade',quote({upgradeId='quartz_power',level=0}));assert(not data(p).run.shopLevels.quartz_power)
 assert(Pro.validate(data(p),pl.UserId))
end)
check('actual worker ticks pay all Quartz required for prestige after spending on the run',function()
 while data(p).run.quartzEarnings<Pro.milestone(data(p)).earnings do mine();sell() end
 local pre=Pro.prestigePreview(data(p));assert(pre.eligible and pre.winsRequired==0 and pre.field=='Quartz')
 local request=quote({confirm=true});move(shopStations.Quartz.Position);input('Prestige',request)
 assert(#p.drones==5 and #data(p).fleet==5 and data(p).prestiges==1)
 assert(data(p).fleet[1].id==firstId and data(p).fleet[1].base.miningDPS==firstBase.miningDPS)
 assert(DroneRoles.isWorker(data(p).fleet[5].role))
 assert(#data(p).run.cards==0 and data(p).run.wallet.Quartz==0 and data(p).run.quartzEarnings==0)
 assert(p.drones[1].stats.miningDPS==firstBase.miningDPS*1.25)
 input('Prestige',request);assert(#data(p).fleet==5)
 print(string.format('MODEL run1 %.2fs worker ticks (travel to stations supplied by double); starter rock %.2fs',now-beganAt,baseTime))
end)
check('reconnect preserves reward and the second earned run can buy another upgrade',function()
 local prestigeId=data(p).fleet[5].id;players.PlayerRemoving:Fire(pl)
 pl=player(310001);players.PlayerAdded:Fire(pl);p=assert(profiles[pl.UserId])
 assert(#data(p).fleet==5 and data(p).fleet[1].id==firstId and data(p).fleet[5].id==prestigeId)
 assert(data(p).prestiges==1 and p.drones[1].stats.miningDPS==37.5)
 mine();mine();sell();assert(data(p).run.wallet.Quartz>=20)
 move(scene.packStation.Position);input('BuyPack',quote({packIndex=0}));assert(data(p).run.pendingOffer.price==20)
 assert(Pro.validate(data(p),pl.UserId))
end)
print(checks..' Quartz production-server checks passed ('..(preview and 'Studio' or 'production')..' configuration; API doubles)')
