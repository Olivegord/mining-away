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
check('one miner zero money normal bag and no free automation or transport',function()
 assert(#p.drones==1 and #data(p).fleet==1 and not p.testFleet)
 assert(Ca.capacity(data(p))==40 and p.drones[1].stats.plotAuto==0)
 assert(data(p).run.wallet.Quartz==0 and not data(p).logistics.backpack and #data(p).logistics.carriers==0)
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
 move(home);local payload=quote({droneType='Laser'});input('BuyDrone',payload)
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
 move(scene.prestigeStation.Position);input('Prestige',payload)
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
print(checks..' full-loop production-logic checks passed ('..(preview and 'Studio configuration' or 'production configuration')..'); API doubles, not a native playtest')
