-- Production server mechanics under API doubles; real damage/rewards/transactions.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS Quartz server '..name) end
RoleEffects.BreakerPhase=function() end;discoveries.TrySpawn=function() end
local pl=player(310001);players.PlayerAdded:Fire(pl);local p=assert(profiles[pl.UserId]);local field=patches[1]
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
local firstId,firstBase,offer,selected,baseTime
local beganAt=now
check('Studio and production both start with one drone, zero Quartz, actual rocks',function()
 assert(#p.drones==1 and #data(p).fleet==1 and not p.testFleet)
 assert(data(p).run.wallet.Quartz==0 and Ca.capacity(data(p))==40)
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
 selected=assert(data(p).run.cards[1]);assert(selected.level==offer.packTier and not data(p).run.pendingOffer)
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
 assert(#p.drones==2 and #data(p).fleet==2 and data(p).prestiges==1)
 assert(data(p).fleet[1].id==firstId and data(p).fleet[1].base.miningDPS==firstBase.miningDPS)
 assert(DroneRoles.isWorker(data(p).fleet[2].role))
 assert(#data(p).run.cards==0 and data(p).run.wallet.Quartz==0 and data(p).run.quartzEarnings==0)
 assert(p.drones[1].stats.miningDPS==firstBase.miningDPS*1.25)
 input('Prestige',request);assert(#data(p).fleet==2)
 print(string.format('MODEL run1 %.2fs worker ticks (travel to stations supplied by double); starter rock %.2fs',now-beganAt,baseTime))
end)
check('reconnect preserves reward and the second earned run can buy another blueprint',function()
 local secondId=data(p).fleet[2].id;players.PlayerRemoving:Fire(pl)
 pl=player(310001);players.PlayerAdded:Fire(pl);p=assert(profiles[pl.UserId])
 assert(#data(p).fleet==2 and data(p).fleet[1].id==firstId and data(p).fleet[2].id==secondId)
 assert(data(p).prestiges==1 and p.drones[1].stats.miningDPS==37.5)
 mine();mine();sell();assert(data(p).run.wallet.Quartz>=20)
 move(scene.packStation.Position);input('BuyPack',quote({packIndex=0}));assert(data(p).run.pendingOffer.price==20)
 assert(Pro.validate(data(p),pl.UserId))
end)
print(checks..' Quartz production-server checks passed ('..(preview and 'Studio' or 'production')..' configuration; API doubles)')
