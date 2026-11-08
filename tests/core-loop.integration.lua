-- Executes the real mining, pickups, commands and persistence transaction code.
-- Movement is supplied by an API double; this is not a native playtest or fun proof.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS core loop '..name) end
RoleEffects.BreakerPhase=function() end;discoveries.TrySpawn=function() end
local pl=player(310001);players.PlayerAdded:Fire(pl);local p=assert(profiles[pl.UserId]);local field=patches[1]
local function input(action,payload) p.tokens=7;p.bucketAt=now;command.OnServerEvent:Fire(pl,action,payload) end
local function move(position) pl.Character:PivotTo(CFrame.new(position+Vector3.new(0,3,0))) end
local serial=0
local function quote(extra)
 serial+=1;local q={txId='loop:'..serial,runId=data(p).run.id};for k,v in pairs(extra or {}) do q[k]=v end;return q
end
local function tick()
 realTime+=C.Tick;now=realTime
 for _,d in ipairs(p.drones) do droneStep(d,C.Tick) end
 pickupStep(C.Tick)
end
for _,r in ipairs(field.resources) do r.paid=true;r.hp=0 end
local function mine()
 move(field.center)
 local resource=Mining.resource(75,'Crystal',field.cfg.Hardness)
 local r=makeResource(field,field.center,'Crystal',resource.work,10,3);r.readyAt=now
 local before=Pro.cargoUnits(data(p));input('MineOre',r.id)
 local started=now
 for _=1,1500 do
  tick()
  if r.paid and pendingOre(p)==0 then break end
 end
 assert(r.paid and Pro.cargoUnits(data(p))==before+10,'mining/collection did not produce the rock payout: '..Pro.cargoUnits(data(p)))
 return now-started
end
local function sell() move(scene.converter.Position);input('Sell') end
local firstId,firstBase,baseTime,improvedTime
check('one miner with the correct starter wallet, normal bag and no free automation or transport',function()
 assert(#p.drones==1 and #data(p).fleet==1 and not p.testFleet)
 assert(Ca.capacity(data(p))==40 and p.drones[1].stats.plotAuto==0)
 assert(data(p).run.wallet.Quartz==(preview and 100 or 0))
 local hotbar=pl:GetAttribute('MA_FieldTools')
 if preview then
  local slots=Http:JSONDecode(hotbar).slots
  for i,kind in ipairs(ToolRules.ORDER) do assert(slots[i].kind==kind) end
 else assert(not hotbar,'production player received preview tools') end
 assert(data(p).run.saleEarnings==0 and not data(p).logistics.backpack and #data(p).logistics.carriers==0)
 -- Continue the earned-economy scenarios from the live starting balance.
 data(p).run.wallet.Quartz=0;data(p).run.credits=0
 firstId=p.drones[1].id;firstBase=Pro.clone(data(p).fleet[1].base)
 baseTime=mine();mine();mine();mine()
 assert(Pro.cargoUnits(data(p))==40 and data(p).run.wallet.Quartz==0)
end)
check('sell pays immediately once at the converter without filling storage',function()
 input('Sell');assert(data(p).run.wallet.Quartz==0 and Pro.cargoUnits(data(p))==40,'remote sale accepted')
 if not preview then runtimeStore.failAfter=1 end
 sell();assert(data(p).run.wallet.Quartz==40 and Pro.cargoUnits(data(p))==0 and data(p).run.saleEarnings==40)
 assert(Logistics.bagUnits(data(p).run.logistics.storage)==0 and data(p).logistics.launches==0)
 local receipts=#data(p).receipts;input('Sell');assert(data(p).run.wallet.Quartz==40 and #data(p).receipts==receipts)
end)
check('first affordable power purchase increases real mining throughput',function()
 local payload=quote({upgradeId='quartz_power',level=0})
 move(field.center);input('BuyUpgrade',payload);assert(not data(p).run.shopLevels.quartz_power)
 move(shopStations.Quartz.Position);input('BuyUpgrade',payload)
 assert(data(p).run.wallet.Quartz==20 and data(p).run.shopLevels.quartz_power==1)
 assert(p.drones[1].stats.miningDPS==firstBase.miningDPS*1.5)
 input('BuyUpgrade',payload);assert(data(p).run.wallet.Quartz==20 and data(p).run.shopLevels.quartz_power==1)
 improvedTime=mine();mine();mine();mine();sell()
 assert(data(p).run.wallet.Quartz==60 and data(p).run.saleEarnings==80)
 -- Compare the same production job from a stationary work position separately
 -- below; these trip totals also include approach, warmup and collection.
 print(string.format('PACING one rock including travel/charge/collection: first %.2fs, first upgraded %.2fs',baseTime,improvedTime))
end)
local boughtId
check('sale earnings buy a permanent second miner and prices increase without rerolling traits',function()
 local printerBefore=scene.printer.Position
 scene.printer.Position=home+Vector3.new(0,0,40);move(scene.printer.Position)
 assert((characterRoot(p).Position-home).Magnitude>30,'printer probe must be outside the old home radius')
 local payload=quote({droneType='Laser'});input('BuyDrone',payload)
 scene.printer.Position=printerBefore
 assert(data(p).run.wallet.Quartz==0 and #data(p).fleet==2 and #p.drones==2)
 local owned=data(p).fleet[2];boughtId=owned.id
 assert(owned.type=='Blue' and owned.role=='Striker' and owned.base.miningDPS==30 and data(p).purchasedDrones==1)
 assert(DroneCatalog.price('Laser',data(p).fleet)==108)
 input('BuyDrone',payload);assert(#data(p).fleet==2 and data(p).run.wallet.Quartz==0)
 input('BuyDrone',quote({droneType='Laser'}));assert(#data(p).fleet==2,'unfunded purchase accepted')
 assert(Pro.validate(data(p),pl.UserId))
end)
check('earned sales unlock prestige even after money was spent on upgrades and drones',function()
 for _=1,2 do for _=1,4 do mine() end;sell() end
 assert(data(p).run.saleEarnings==160 and data(p).run.wallet.Quartz==80)
 local pre=Pro.prestigePreview(data(p));assert(pre.eligible and pre.miningBonusBefore==0 and pre.miningBonusAfter==.25)
 local oldRun=data(p).run.id;local payload=quote({confirm=true})
 move(field.center);input('Prestige',payload);assert(data(p).prestiges==0)
 local prestigeBefore=scene.prestigeStation.Position
 scene.prestigeStation.Position=home+Vector3.new(40,0,20);move(scene.prestigeStation.Position)
 assert((characterRoot(p).Position-home).Magnitude>30,'prestige probe must be outside the old home radius')
 input('Prestige',payload);scene.prestigeStation.Position=prestigeBefore
 assert(data(p).prestiges==1 and data(p).run.id~=oldRun and #data(p).fleet==3 and #p.drones==3)
 assert(data(p).fleet[1].id==firstId and data(p).fleet[2].id==boughtId)
 assert(not next(data(p).run.shopLevels) and data(p).run.wallet.Quartz==0 and data(p).run.saleEarnings==0 and Pro.cargoUnits(data(p))==0)
 for key,value in pairs(firstBase) do assert(data(p).fleet[1].base[key]==value,'permanent traits rewritten') end
 assert(p.drones[1].stats.miningDPS==37.5 and Ca.capacity(data(p))==40)
 input('Prestige',payload);assert(data(p).prestiges==1 and #data(p).fleet==3)
 input('BuyUpgrade',{txId='stale',runId=oldRun,upgradeId='quartz_power',level=0});assert(not next(data(p).run.shopLevels))
 assert(Pro.validate(data(p),pl.UserId))
end)
check('permanent purchases and prestige strength survive reconnect and can begin the next loop',function()
 players.PlayerRemoving:Fire(pl);assert(not profiles[pl.UserId])
 pl=player(310001);players.PlayerAdded:Fire(pl);p=assert(profiles[pl.UserId])
 assert(#p.drones==3 and not p.testFleet and data(p).fleet[2].id==boughtId and p.drones[1].stats.miningDPS==37.5)
 mine();mine();sell();move(shopStations.Quartz.Position);input('BuyUpgrade',quote({upgradeId='quartz_power',level=0}))
 assert(p.drones[1].stats.miningDPS==56.25 and data(p).run.wallet.Quartz==0)
end)
check('mixed sales preserve typed balances and optional logistics cargo',function()
 local q=Pro.new(310002,8);q.run.cargo={Quartz=2,Ruby=3};q.run.logistics.storage={Cobalt=7}
 local run=q.run.id;local ok,result=Pro.sell(q,prices,'mixed',run);assert(ok and result.units==5 and result.earnings==8)
 assert(q.run.wallet.Quartz==2 and q.run.wallet.Ruby==3 and q.run.credits==2 and q.run.saleEarnings==8)
 assert(q.run.logistics.storage.Cobalt==7 and not next(q.run.cargo))
 assert(Pro.sell(q,prices,'mixed',run));assert(q.run.saleEarnings==8)
 assert(not Pro.sell(q,prices,'mixed','other-run'))
 q.run.cargo={Quartz=1};q.run.wallet.Quartz=1e14-1
 assert(not Pro.sell(q,prices,'overflow',run));assert(q.run.cargo.Quartz==1)
end)
check('rarity adds slower hold segments and never advances past its own color',function()
 local previousDuration=0
 for tier=1,#Packs.Tiers do
  local duration=Packs.duration(tier)
  assert(duration>previousDuration)
  local progress,stage=Packs.sample(tier,duration)
  assert(progress==1 and stage==tier)
  local last=0
  for step=0,40 do
   local q=Packs.sample(tier,duration*step/40)
   assert(q>=last and q<=1);last=q
  end
  previousDuration=duration
 end
 local starts={0,.42,1.32,2.65}
 local lastSpeed=math.huge
 for stage,at in ipairs(starts) do
  local before,color=Packs.sample(4,at)
  local after=Packs.sample(4,at+.1)
  assert(color==stage and after-before<lastSpeed)
  lastSpeed=after-before
 end
end)
check('free delivery stays sealed until the owner finishes a nearby uninterrupted hold',function()
 local function advance(seconds)
  realTime+=seconds;now=realTime;packDelivery:step(p,now)
 end
 local function visibleOffer()
  return Http:JSONDecode(pl:GetAttribute('MA_Profile')).run.pendingOffer
 end
 data(p).run.wallet.Quartz=0
 move(scene.packStation.Position+Vector3.new(12,0,0))
 local request=quote({packIndex=0});input('BuyPack',request)
 local offer=Pro.clone(data(p).run.pendingOffer)
 assert(offer.opened==false and #offer.choices==3 and not visibleOffer().choices)
 for _,choice in ipairs(offer.choices) do
  assert(choice.category~='combat' and choice.category~='survival','starter offer contains a guard-only card')
 end
 local wallet=data(p).run.wallet.Quartz
 assert(offer.price==0 and wallet==0,'free pack charged money or required a balance')
 local part=assert(p.packDelivery).part
 assert((part.Position-scene.packStation.Position).Magnitude>=7)
 input('BuyPack',request)
 assert(p.packDelivery.part==part and data(p).run.wallet.Quartz==wallet)
 local function hold(phase)
  local current=p.packDelivery.prompt
  if phase=='Begin' then current.PromptButtonHoldBegan:Fire(pl)
  elseif phase=='End' then current.PromptButtonHoldEnded:Fire(pl)
  elseif phase=='Complete' then current.Triggered:Fire(pl) end
 end
 local choice=quote({offerId=offer.id,index=2})
 input('ChooseCard',choice);assert(#data(p).run.cards==0)
 hold('Begin');assert(not part:GetAttribute('HoldAt'))
 advance(Packs.DeliveryTime+.1);move(part.Position)
 local intruder=player(310003);players.PlayerAdded:Fire(intruder)
 intruder.Character:PivotTo(CFrame.new(part.Position))
 p.packDelivery.prompt.PromptButtonHoldBegan:Fire(intruder)
 assert(not part:GetAttribute('HoldAt'))
 players.PlayerRemoving:Fire(intruder)
 hold('Begin');assert(part:GetAttribute('HoldAt'))
 advance(.18);hold('End');advance(.1);assert(not part:GetAttribute('HoldAt') and not data(p).run.pendingOffer.opened)
 advance(.2);hold('Begin');hold('Complete')
 assert(not data(p).run.pendingOffer.opened,'early native completion accepted')
 hold('End')
 hold('Begin');move(field.center);advance(.15)
 assert(not part:GetAttribute('HoldAt') and not data(p).run.pendingOffer.opened)
 players.PlayerRemoving:Fire(pl);assert(not part.Parent)
 pl=player(310001);players.PlayerAdded:Fire(pl);p=assert(profiles[pl.UserId])
 local restored=data(p).run.pendingOffer
 assert(restored.id==offer.id and restored.packTier==offer.packTier and not visibleOffer().choices)
 for i,card in ipairs(restored.choices) do assert(card.cardId==offer.choices[i].cardId and card.targetDroneId==offer.choices[i].targetDroneId) end
 move(scene.packStation.Position+Vector3.new(12,0,0));advance(.1)
 local delivered=assert(p.packDelivery)
 advance(Packs.DeliveryTime+.1);move(delivered.part.Position);hold('Begin')
 local duration=Packs.duration(offer.packTier)
 assert(delivered.prompt.HoldDuration==duration)
 local started=delivered.part:GetAttribute('HoldAt')
 for step=1,20 do
  advance(duration/20)
  assert(delivered.prompt.HoldDuration==duration,'native hold restarted or changed duration')
  assert(delivered.part:GetAttribute('HoldAt')==started,'continuous hold timestamp reset')
  assert(not data(p).run.pendingOffer.opened)
 end
 -- Native HoldEnded can precede Triggered in the same completion frame.
 hold('End');hold('Complete')
 assert(data(p).run.pendingOffer.opened and #visibleOffer().choices==3)
 input('ChooseCard',quote({offerId=offer.id,index=2}))
 assert(data(p).run.pendingOffer==nil and #data(p).run.cards==1 and data(p).run.cards[1].cardId==offer.choices[2].cardId)
 advance(.1);assert(not delivered.part.Parent)
end)
print(checks..' full-loop production-logic checks passed ('..(preview and 'Studio configuration' or 'production configuration')..'); API doubles, not a native playtest')
