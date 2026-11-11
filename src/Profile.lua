local Workshop=require('./Workshop')
local Shops=require('./Shops')
local DroneCatalog=require('./DroneCatalog')
local Consumables=require('./Consumables')
-- Pure permanent ownership and run transactions. Durable storage commits working copies.
local P={SCHEMA=12,CONTENT=1}
local STARTER_COUNT=3
local crystalStarterCount=STARTER_COUNT+#Workshop.STARTER_SPECIALISTS
local excessStarters={'Charger','Medic','Dart','Orbiter','Scrapper','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'}
local oversizedStarterCount=1+#excessStarters+#Workshop.STARTER_SPECIALISTS
local supportedStarterCounts={[1]=true,[STARTER_COUNT]=true,[4]=true,[crystalStarterCount]=true,[oversizedStarterCount]=true}
local types={'Blue','Red','Green'}
local specialTypes={Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local roles={Striker=true,Charger=true,Medic=true,Courier=true,Orbiter=true,Scrapper=true,Dart=true}
for role in pairs(specialTypes) do roles[role]=true end
local starterTypes={Dart=true,Orbiter=true,Scrapper=true,Needler=true,Ballcaster=true,Vacuum=true,Compactor=true}
for role in pairs(starterTypes) do roles[role]=true end
local guardedFields={Cobalt=1,Violet=3,Emerald=5}
local effectKeys={orbitalLaser=true,scrapSwarm=true,orbitalRelay=true,scrapRecycle=true,mining=true,speed=true,combat=true,health=true,reduction=true,capacity=true,startup=true,yield=true,range=true,crit=true,splash=true,fork=true,shield=true,rate=true,finisher=true,geode=true,salvage=true,chain=true,forkRange=true,plotAuto=true,fullAuto=true,battery=true,deepCut=true,magnetRange=true,aftershock=true,reclaim=true,earlyDrop=true,fieldCharge=true,doubleBeam=true,twinThrusters=true,oreDuplicator=true}
effectKeys.compactor=true;effectKeys.batchPress=true;effectKeys.liveWire=true;effectKeys.shiftRelay=true
effectKeys.denserPacking=true;effectKeys.cargoRack=true
local scopes={Fleet=true,Player=true,Color=true,Individual=true,Tradeoff=true}
local function validRarity(v) return v==nil or v=='Common' or v=='Uncommon' or v=='Rare' or v=='Epic' or v=='Legendary' end
P.BASE={miningDPS=30,combatDPS=12,maxHealth=80,warmup=.8,range=18,shotInterval=.8}
P.TYPE_SCALES={Blue={speed=1.15,mining=1,combat=1},Red={speed=1,mining=.95,combat=1.15},Green={speed=1,mining=1.10,combat=.95}}
local function integer(n) return type(n)=='number' and n==n and n>=0 and n<1e14 and n%1==0 end
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function clone(v)
 if type(v)~='table' then return v end
 local out={};for k,x in pairs(v) do out[k]=clone(x) end;return out
end
P.clone=clone
local function run(uid,index)
 local state={id=tostring(uid)..':run:'..index,index=index,credits=0,cargo={},droneCargo={},deliveries={},saleEarnings=0,quartzEarnings=0,packIndex=0,cards={},pendingOffer=nil,offersWithoutCombat=0,wins={},entitlements={},yieldRemainders={},abilityCooldowns={},logistics={storage={},launchCargo={},launchRemaining=0,backpackCargo={},pendingCargo={}}}
 state.stars=0;state.starUpgrades={}
 Shops.fresh(state);return state
end
local function logisticsOwnership()
 return {carriers={},nextCarrier=1,backpack=false,autoLaunch=true,launches=0}
end
local function cargoId(p,id)
 if type(id)~='string' or #id>160 then return false end
 if type(p.fleet)~='table' then return false end
 for _,d in ipairs(p.fleet) do if type(d)=='table' and d.id==id then return true end end
 if p.run and type(p.run.id)=='string' then
  for slot=1,Workshop.EMPTIERS do if id==Workshop.emptierId(p.run.id,slot) then return true end end
 end
 -- Studio roles have separate own-player bags; they never become permanent units.
 local prefix='test:'..tostring(p.userId)..':'
 return string.sub(id,1,#prefix)==prefix and string.match(string.sub(id,#prefix+1),'^%d+:%d+$')~=nil
end
local function bagUnits(bag)
 local total=0;for _,units in pairs(bag or {}) do total=total+units end;return total
end
local function validBag(bag)
 if type(bag)~='table' then return false end
 local total=0
 for material,units in pairs(bag) do
  if type(material)~='string' or #material>40 or not integer(units) then return false end
  total=total+units;if not integer(total) then return false end
 end
 return true
end
local function denseArray(value,limit)
 if type(value)~='table' or (limit and #value>limit) then return false end
 local count=0
 for key in pairs(value) do
  if not integer(key) or key<1 or key>#value then return false end
  count=count+1
 end
 return count==#value
end
local function mineralBag(bag)
 if not validBag(bag) then return false end
 for material in pairs(bag) do if not Shops.COLORS[material] and not Workshop.CRYSTAL_BY_MATERIAL[material] and not Workshop.crystalCargo(material) then return false end end
 return true
end
local function validateLogistics(p,ids)
 local ownership=p.logistics
 if type(ownership)~='table' or not denseArray(ownership.carriers,3) or not integer(ownership.nextCarrier) or ownership.nextCarrier<1 or not integer(ownership.launches)
  or type(ownership.backpack)~='boolean' or type(ownership.autoLaunch)~='boolean' then return false,'Invalid permanent logistics' end
 local carrierIds,loaded={},{}
 local prefix=tostring(p.userId)..':carrier:'
 for _,carrier in ipairs(ownership.carriers) do
  if type(carrier)~='table' or type(carrier.id)~='string' or #carrier.id>128 or carrierIds[carrier.id] or not denseArray(carrier.droneIds,4) then return false,'Invalid carrier ownership' end
  if string.sub(carrier.id,1,#prefix)~=prefix then return false,'Foreign carrier identity' end
  local suffix=string.sub(carrier.id,#prefix+1)
  local serial=tonumber(suffix)
  if not string.match(suffix,'^%d+$') or not integer(serial) or serial<1 or tostring(serial)~=suffix or serial>=ownership.nextCarrier then return false,'Invalid carrier serial' end
  carrierIds[carrier.id]=true
  for _,id in ipairs(carrier.droneIds) do
   if type(id)~='string' or not ids[id] or loaded[id] then return false,'Invalid carrier loadout' end
   loaded[id]=true
  end
 end
 local state=p.run.logistics
 if type(state)~='table' or not finite(state.launchRemaining) or state.launchRemaining<0 or state.launchRemaining>6 then return false,'Invalid storage launch' end
 for _,key in ipairs({'storage','launchCargo','backpackCargo','pendingCargo'}) do if not mineralBag(state[key]) then return false,'Invalid logistics cargo '..key end end
 if bagUnits(state.launchCargo)==0 and state.launchRemaining~=0 then return false,'Empty capsule has a launch timer' end
 return true
end
local function drone(uid,serial,kind,seed,earnedSerial)
 local progression=earnedSerial or serial
 local step=(20+((seed+serial*17)%31))/100
 local base=clone(P.BASE);local scale=P.TYPE_SCALES[kind]
 base.maxStep60=step*scale.speed;base.miningDPS=base.miningDPS*scale.mining;base.combatDPS=base.combatDPS*scale.combat
 local role=kind=='Green' and 'Medic' or (kind=='Red' and 'Charger' or (math.floor((progression-1)/3)%2==1 and 'Courier' or 'Striker'))
 if progression>=4 then role=({'Orbiter','Scrapper','Courier','Striker','Charger','Medic','Dart'})[(progression-4)%7+1] end
 return {id=tostring(uid)..':drone:'..serial,name=(progression>=4 and role or kind)..' '..serial,type=kind,role=role,base=base}
end
local function specialDrone(uid,serial,kind,seed)
 local base=clone(P.BASE)
 base.maxStep60=(30+((seed+serial*17)%16))/100
 base.combatDPS=kind=='Singularity' and 20 or 12
 base.maxHealth=kind=='Halver' and 110 or (kind=='Singularity' and 100 or 80)
 return {id=tostring(uid)..':drone:'..serial,name=DroneCatalog.Types[kind].Name..' '..serial,type=kind,role=kind,base=base,flightHeight=3.4}
end
local function starterMiner(uid,serial,seed)
 local miner=drone(uid,serial,'Blue',seed,1)
 -- The reference's 12–30 studs/second flight roll for each starter miner.
 miner.base.maxStep60=(20+((seed+serial*17)%31))/100
 return miner
end
function P.new(uid,seed,roleConfig)
 assert(finite(uid) and uid%1==0 and math.abs(uid)<1e14,'Invalid user ID')
 seed=integer(seed) and seed%2147483646 or (uid*7919+104729)%2147483646
 local fleet={}
 for serial=1,STARTER_COUNT do fleet[serial]=starterMiner(uid,serial,seed) end
 if roleConfig then
  for _,role in ipairs(Workshop.STARTER_SPECIALISTS) do
   local serial=#fleet+1
   local stats=roleConfig.StudioRoles[role]
   fleet[serial]={id=tostring(uid)..':drone:'..serial,name=roleConfig.Types[role].DisplayName,role=role,type=role,
    base=clone(stats.base),flightHeight=stats.height}
  end
 end
 return {schemaVersion=P.SCHEMA,contentVersion=P.CONTENT,userId=uid,revision=0,prestiges=0,purchasedDrones=0,starterDrones=#fleet,nextDroneSerial=#fleet+1,seed=seed,fleet=fleet,run=run(uid,1),receipts={},settings={},clearedFields={},logistics=logisticsOwnership(),consumables=Consumables.fresh()}
end
function P.validate(p,uid)
 if type(p)~='table' or p.schemaVersion~=P.SCHEMA or p.userId~=uid then return false,'Unsupported profile schema or owner' end
 local toolsOK,toolsError=Consumables.validate(p.consumables);if not toolsOK then return false,toolsError end
 if not integer(p.prestiges) or not integer(p.purchasedDrones) or not integer(p.revision) or not integer(p.seed) or not integer(p.nextDroneSerial) then return false,'Invalid permanent counters' end
 if not denseArray(p.fleet) or not supportedStarterCounts[p.starterDrones] or #p.fleet~=p.prestiges+p.starterDrones+p.purchasedDrones or #p.fleet<1 then return false,'Permanent fleet invariant violated' end
 local ids={}
 local prefix=tostring(uid)..':drone:'
 local lastSerial=0
 for serial,d in ipairs(p.fleet) do
  if type(d)~='table' or type(d.id)~='string' or #d.id>100 or ids[d.id] or type(d.name)~='string' or #d.name>80 or (not table.find(types,d.type) and not specialTypes[d.type] and not starterTypes[d.type]) or type(d.base)~='table' then return false,'Invalid permanent drone' end
  local idSerial=tonumber(string.sub(d.id,#prefix+1))
  if not integer(idSerial) or idSerial<=lastSerial or d.id~=prefix..idSerial
   or (p.starterDrones~=crystalStarterCount and idSerial~=serial) then return false,'Permanent drone ID does not match owner/serial' end
  lastSerial=idSerial
  ids[d.id]=d
  if not roles[d.role] or ((specialTypes[d.type] or starterTypes[d.type]) and d.role~=d.type) then return false,'Invalid permanent role' end
  for _,k in ipairs({'miningDPS','combatDPS','maxHealth','maxStep60','warmup','range','shotInterval'}) do if not finite(d.base[k]) or d.base[k]<=0 or d.base[k]>1e6 then return false,'Invalid permanent base trait' end end
 end
 if type(p.clearedFields)~='table' then return false,'Missing permanent plot unlocks' end
 for key,value in pairs(p.clearedFields) do if not guardedFields[key] or value~=true then return false,'Invalid permanent plot unlock' end end
 local r=p.run
 if type(r)~='table' or not integer(r.index) or r.index~=p.prestiges+1 or r.id~=tostring(uid)..':run:'..r.index then return false,'Invalid current run' end
 if p.consumables.pending and p.consumables.pending.runId~=r.id then return false,'Stale consumable reservation' end
 local logisticsOK,logisticsError=validateLogistics(p,ids);if not logisticsOK then return false,logisticsError end
 if type(r.abilityCooldowns)~='table' then return false,'Missing gadget cooldowns' end
 for key,value in pairs(r.abilityCooldowns) do if (key~='Orbital' and key~='Scrap') or not finite(value) or value<0 or value>=1e14 then return false,'Invalid gadget cooldown' end end
 local shopOK,shopError=Shops.validate(r);if not shopOK then return false,shopError end
 for _,k in ipairs({'credits','saleEarnings','quartzEarnings','packIndex','offersWithoutCombat'}) do if not integer(r[k]) then return false,'Invalid run counter '..k end end
 for _,k in ipairs({'cargo','droneCargo','deliveries','cards','wins','entitlements','yieldRemainders'}) do if type(r[k])~='table' then return false,'Missing run state '..k end end
 if not validBag(r.cargo) then return false,'Invalid legacy cargo' end
 local cargoTotal=bagUnits(r.cargo)
 for id,bag in pairs(r.droneCargo) do
  if not cargoId(p,id) or not validBag(bag) then return false,'Invalid drone cargo' end
  cargoTotal=cargoTotal+bagUnits(bag)
 end
 local manifests={}
 for id,manifest in pairs(r.deliveries) do
  if not cargoId(p,id) or type(manifest)~='table' or manifest.droneId~=id or manifest.runId~=r.id or type(manifest.id)~='string' or #manifest.id<1 or #manifest.id>128 or manifests[manifest.id] or not validBag(manifest.cargo) or bagUnits(manifest.cargo)<=0 or bagUnits(manifest.cargo)>32 then return false,'Invalid delivery manifest' end
  manifests[manifest.id]=true;cargoTotal=cargoTotal+bagUnits(manifest.cargo)
 end
 for _,key in ipairs({'storage','launchCargo','backpackCargo','pendingCargo'}) do cargoTotal=cargoTotal+bagUnits(r.logistics[key]) end
 if not integer(cargoTotal) then return false,'Cargo total limit exceeded' end
 for field,n in pairs(r.wins) do if type(field)~='string' or not integer(n) then return false,'Invalid run wins' end end
 for material,n in pairs(r.yieldRemainders) do if type(material)~='string' or not finite(n) or n<0 or n>=1 then return false,'Invalid yield remainder' end end
 local blueprints={}
 if #r.cards>500 then return false,'Invalid card count' end
 for _,c in ipairs(r.cards) do
  if type(c)~='table' or type(c.cardId)~='string' or type(c.effects)~='table' or not scopes[c.scope] then return false,'Invalid run card' end
  if not validRarity(c.rarity) or not Workshop.validate(c) then return false,'Invalid run card rarity or blueprint' end
  if c.workshop then
   local key=c.cardId
   if Workshop.isHardware(c) then
    local target=ids[c.targetDroneId]
    if not target or not Workshop.fits(target) then return false,'Invalid hardware target' end
    key=key..':'..target.id
   end
   if blueprints[key] then return false,'Duplicate blueprint' end;blueprints[key]=true
  end
  if c.scope=='Individual' and not ids[c.targetDroneId] then return false,'Missing permanent card target' end
  if c.scope=='Color' and not table.find(types,c.type) then return false,'Invalid card color' end
  for k,v in pairs(c.effects) do if not effectKeys[k] or not finite(v) or math.abs(v)>(k=='battery' and c.cardId=='Q_BATTERY' and 400 or 100) then return false,'Invalid modifier' end end
 end
 local offer=r.pendingOffer
 if not integer(r.stars) or type(r.starUpgrades)~='table' then return false,'Invalid Star Shop state' end
 for id,level in pairs(r.starUpgrades) do
  local entry=Workshop.STAR_BY_ID[id]
  if not entry or not integer(level) or level<1 or level>entry.max then return false,'Invalid Star Shop level' end
 end
 if offer~=nil then
  if type(offer)~='table' or type(offer.id)~='string' or offer.runId~=r.id or not integer(offer.price) or type(offer.choices)~='table' or #offer.choices~=3 then return false,'Invalid paid offer' end
  if offer.currency~=nil and offer.currency~='Quartz' then return false,'Invalid paid offer currency' end
  if offer.opened~=nil and type(offer.opened)~='boolean' then return false,'Invalid pack state' end
  if (offer.packTier~=nil or offer.opened==false) and (not integer(offer.packTier) or offer.packTier<1 or offer.packTier>4) then return false,'Invalid pack tier' end
  local seen={};local guaranteed=false
  for _,c in ipairs(offer.choices) do
   if type(c)~='table' or type(c.cardId)~='string' or seen[c.cardId] or type(c.effects)~='table' or not scopes[c.scope] then return false,'Invalid offer choice' end
   if (offer.contentVersion or 0)>=13 and not c.workshop then return false,'Invalid guaranteed upgrade kind' end
   if not validRarity(c.rarity) or not Workshop.validate(c) then return false,'Invalid offer choice rarity or blueprint' end
   if c.workshop then
    local owned=Workshop.find(p,c.cardId);local before=owned and owned.level or 0
    if c.packTier~=offer.packTier or before+c.level>c.maxLevel then return false,'Invalid upgrade stack' end
    if (offer.contentVersion or 0)>=13 then
     if c.stackVersion~=2 or c.stackBefore~=before or c.level~=1 or c.upgradeTier>offer.packTier then return false,'Invalid guaranteed upgrade' end
     guaranteed=guaranteed or c.upgradeTier==offer.packTier
    elseif (offer.contentVersion or 0)>=12 then
     if c.stackBefore~=before then return false,'Invalid saved stack count' end
    elseif owned then return false,'Invalid legacy blueprint offer' end
   end
  for effect,value in pairs(c.effects) do if not effectKeys[effect] or not finite(value) or math.abs(value)>(effect=='battery' and c.cardId=='Q_BATTERY' and 400 or 100) then return false,'Invalid saved offer modifier' end end
   if c.scope=='Color' and not table.find(types,c.type) then return false,'Invalid saved offer color' end
   seen[c.cardId]=true
   if Workshop.isHardware(c) then
    if c.targetDroneId~=nil or #Workshop.targets(p,c)==0 then return false,'Invalid unassigned hardware offer' end
   elseif c.scope=='Individual' and not ids[c.targetDroneId] then return false,'Paid offer target missing' end
  end
  if (offer.contentVersion or 0)>=13 and not guaranteed then return false,'Pack rarity reward missing' end
 end
 if p.nextDroneSerial~=lastSerial+1 then return false,'Invalid permanent serial' end
 if type(p.receipts)~='table' or #p.receipts>64 then return false,'Invalid receipt ledger' end
 for _,savedReceipt in ipairs(p.receipts) do if type(savedReceipt)~='table' or type(savedReceipt.operation)~='string' or type(savedReceipt.id)~='string' or #savedReceipt.id>128 or type(savedReceipt.result)~='table' then return false,'Invalid saved receipt' end end
 return true
end
-- Repair only the short-lived 17-starter grant. Keep original IDs for the
-- intended drones and any drones earned since, and never recycle retired IDs.
local function correctStarterGrant(p)
 if p.fleet[1].role~='Striker' then return false end
 for i,role in ipairs(excessStarters) do if p.fleet[i+1].role~=role then return false end end
 for i,role in ipairs(Workshop.STARTER_SPECIALISTS) do if p.fleet[1+#excessStarters+i].role~=role then return false end end
 local fleet,removed={p.fleet[1]},{}
 for i=2,#p.fleet do
  local d=p.fleet[i]
  if i<=1+#excessStarters then removed[d.id]=true else table.insert(fleet,d) end
 end
 for _=2,STARTER_COUNT do
  table.insert(fleet,starterMiner(p.userId,p.nextDroneSerial,p.seed))
  p.nextDroneSerial+=1
 end
 p.fleet=fleet;p.starterDrones=crystalStarterCount
 for _,carrier in ipairs(p.logistics.carriers) do
  for i=#carrier.droneIds,1,-1 do if removed[carrier.droneIds[i]] then table.remove(carrier.droneIds,i) end end
 end
 local run=p.run
 for id in pairs(removed) do
  local manifest=run.deliveries[id]
  for _,cargo in ipairs({run.droneCargo[id] or {},manifest and manifest.cargo or {}}) do
   for material,units in pairs(cargo) do run.cargo[material]=(run.cargo[material] or 0)+units end
  end
  run.droneCargo[id]=nil;run.deliveries[id]=nil
 end
 for _,cards in ipairs({run.cards,run.pendingOffer and run.pendingOffer.choices or {}}) do
  for _,card in ipairs(cards) do
   if removed[card.targetDroneId] then
    card.targetDroneId=fleet[1].id;card.targetName=fleet[1].name;card.preview=nil;card.previewTargetName=nil
   end
  end
 end
 return true
end
function P.migrate(raw,uid,seed)
 if raw==nil then return nil,'No profile; explicit new-profile factory required' end
 if type(raw)~='table' then return nil,'Stored profile is not an object' end
 local p=clone(raw)
 local legacyPlotProgress=p.schemaVersion==1 or p.schemaVersion==2
 if p.schemaVersion==1 then
  -- Supported v1 used the same permanent identities; do not reroll or multiply bases.
  if type(p.fleet)~='table' or not integer(p.prestiges) or type(p.run)~='table' then return nil,'Unsupported v1 ownership data' end
  p.schemaVersion=2;p.contentVersion=p.contentVersion or 1;p.revision=p.revision or 0;p.seed=p.seed or seed
  p.receipts=p.receipts or {};p.settings=p.settings or {};p.nextDroneSerial=p.nextDroneSerial or #p.fleet+1
  p.run.entitlements=p.run.entitlements or {};p.run.yieldRemainders=p.run.yieldRemainders or {};p.run.offersWithoutCombat=p.run.offersWithoutCombat or 0
 end
 if p.schemaVersion==2 then
  if type(p.run)~='table' or type(p.run.cargo)~='table' then return nil,'Unsupported v2 cargo' end
  -- Existing cargo remains an unassigned legacy bag until the actual runtime
  -- fleet is known. Never reroll identities or erase cargo during migration.
  p.run.droneCargo=p.run.droneCargo or {};p.run.deliveries=p.run.deliveries or {}
  p.schemaVersion=3
 end
 if p.schemaVersion==3 then
  -- Old worker holds move into the player's backpack without dropping ore.
  -- Legacy manifests were entire worker holds, not eight-unit courier parcels.
  -- Recover their unsold ore too, including IDs now assigned a courier role.
  if type(p.run)~='table' or not validBag(p.run.cargo) or type(p.run.droneCargo)~='table' or type(p.run.deliveries)~='table' or type(p.fleet)~='table' then return nil,'Unsupported v3 cargo' end
  for id,bag in pairs(p.run.droneCargo) do
   if not cargoId(p,id) or not validBag(bag) then return nil,'Invalid v3 worker hold' end
   for material,units in pairs(bag) do p.run.cargo[material]=(p.run.cargo[material] or 0)+units end
  end
  p.run.droneCargo={}
  local manifests={}
  for id,manifest in pairs(p.run.deliveries) do
   if not cargoId(p,id) or type(manifest)~='table' or manifest.droneId~=id or manifest.runId~=p.run.id or type(manifest.id)~='string' or #manifest.id<1 or #manifest.id>128 or manifests[manifest.id] or not validBag(manifest.cargo) or bagUnits(manifest.cargo)<=0 then return nil,'Invalid v3 delivery manifest' end
   manifests[manifest.id]=true
   for material,units in pairs(manifest.cargo) do p.run.cargo[material]=(p.run.cargo[material] or 0)+units end
  end
  p.run.deliveries={}
  for serial,d in ipairs(p.fleet) do
   if type(d)~='table' then return nil,'Invalid v3 permanent drone' end
   d.role=d.role or (d.type=='Green' and 'Medic' or (d.type=='Red' and 'Charger' or (math.floor((serial-1)/3)%2==1 and 'Courier' or 'Striker')))
  end
  -- The old named-worker Auto Hauler cannot operate after worker holds are
  -- removed. Preserve selected purchases as a useful backpack/travel retrofit;
  -- refund an unchosen affected pack at its exact paid price, without a reroll.
  if type(p.run.cards)~='table' then return nil,'Invalid v3 cards' end
  for _,card in ipairs(p.run.cards) do
   if type(card)=='table' and card.cardId=='A02' and type(card.effects)=='table' and finite(card.effects.fullAuto) and card.effects.fullAuto>0 then
    card.legacyCard=clone(card);card.title='Backpack Retrofit';card.scope='Fleet';card.targetDroneId=nil;card.targetName=nil
    card.effects={capacity=.35,speed=.30};card.description='+35% backpack space and +30% drone speed';card.preview=nil
    p.lastMigration='Converted selected Auto Hauler to Backpack Retrofit'
   end
  end
  local offer=p.run.pendingOffer
  if type(offer)=='table' and type(offer.choices)=='table' then
   for _,choice in ipairs(offer.choices) do
    if type(choice)=='table' and choice.cardId=='A02' and type(choice.effects)=='table' and finite(choice.effects.fullAuto) and choice.effects.fullAuto>0 then
     if not integer(offer.price) or not integer(p.run.credits) or p.run.credits+offer.price>=1e14 then return nil,'Cannot refund obsolete Auto Hauler offer' end
     p.run.credits=p.run.credits+offer.price;p.run.pendingOffer=nil;p.lastMigration='Refunded obsolete Auto Hauler pack at full saved price';break
    end
   end
  end
  p.schemaVersion=4
 end
 if p.schemaVersion==4 then
  if type(p.run)~='table' or not integer(p.run.credits) or not validBag(p.run.cargo) or type(p.clearedFields or {})~='table' then return nil,'Invalid legacy shop migration' end
  Shops.fresh(p.run);p.run.wallet.Quartz=p.run.credits;p.run.abilityCooldowns={}
  -- Preserve reached fields without inventing mineral exchange rates. Only
  -- old unspent universal credits become Quartz; unsold ore keeps its type.
  local highest=2
  for i,key in ipairs(Shops.ORDER) do
   if (p.clearedFields or {})[key] or (p.run.cargo[key] or 0)>0 then highest=math.max(highest,i) end
  end
  for i=1,highest do p.run.shops[Shops.ORDER[i]]=true end
  p.schemaVersion=5
 end
 -- Preserve live permanent plot clearances. Only the old progression required
 -- guarded plots before its first prestige; the new first two prestiges do not.
 if p.clearedFields==nil then p.clearedFields={} end
 if legacyPlotProgress and type(p.clearedFields)=='table' then
  for key,firstPrestige in pairs(guardedFields) do
   local wins=type(p.run)=='table' and type(p.run.wins)=='table' and p.run.wins[key]
   if p.clearedFields[key]==nil and ((type(wins)=='number' and wins>0) or (integer(p.prestiges) and p.prestiges>=firstPrestige)) then p.clearedFields[key]=true end
  end
 end
 -- A paid offer retains its full effect payload across catalog revisions. If its
 -- permanent target truly disappeared during a supported migration, refund the
 -- exact charged price atomically in this migrated working copy, never reroll.
 local pending=type(p.run)=='table' and p.run.pendingOffer
 if type(pending)=='table' and type(pending.choices)=='table' and type(p.fleet)=='table' then
  local ids={};for _,d in ipairs(p.fleet) do if type(d)=='table' then ids[d.id]=true end end
  local missing=false
  for _,choice in ipairs(pending.choices) do if type(choice)=='table' and choice.scope=='Individual' and not Workshop.isHardware(choice) and not ids[choice.targetDroneId] then missing=true end end
  if missing then
   if not integer(pending.price) or not integer(p.run.credits) or p.run.credits+pending.price>=1e14 then return nil,'Cannot safely refund invalid saved offer' end
   if p.run.wallet and not integer(p.run.wallet.Quartz+pending.price) then return nil,'Refund exceeds wallet limit' end
   p.run.credits=p.run.credits+pending.price;if p.run.wallet then p.run.wallet.Quartz=p.run.wallet.Quartz+pending.price end;p.run.pendingOffer=nil;p.lastMigration='Refunded missing-target paid offer at full saved price'
  end
 end
 if p.schemaVersion==5 then
  if type(p.run)~='table' or type(p.run.cards)~='table' or type(p.run.wallet)~='table' then return nil,'Invalid standalone upgrade migration' end
  local offer=p.run.pendingOffer
  if offer and type(offer.choices)=='table' then
   local retired=false
   for _,c in ipairs(offer.choices) do if type(c)=='table' and (c.cardId=='A03' or c.cardId=='A04') then retired=true end end
   if retired then
    if not integer(offer.price) or not integer(p.run.wallet.Quartz) or not integer(p.run.wallet.Quartz+offer.price) then return nil,'Cannot refund retired combo offer' end
    p.run.wallet.Quartz=p.run.wallet.Quartz+offer.price;p.run.pendingOffer=nil;p.lastMigration='Refunded retired combo pack at its full saved price'
   end
  end
  for _,c in ipairs(p.run.cards) do
   if type(c)=='table' and (c.cardId=='A03' or c.cardId=='A04') then
    local orbital=c.cardId=='A03';c.legacyCard=clone(c);c.cardId=orbital and 'G01' or 'G02';c.title=orbital and 'Orbital Laser' or 'Scrap-bot Swarm'
    c.scope='Player';c.effects=orbital and {orbitalLaser=1} or {scrapSwarm=1};c.preview=nil;c.targetDroneId=nil;c.targetName=nil
    c.description=orbital and 'Unlock timed orbital strikes on the biggest ready rock' or 'Unlock a ten-second swarm of tiny mining bots'
   end
  end
  p.schemaVersion=6
 end
 if p.schemaVersion==6 then
  if type(p.run)~='table' then return nil,'Invalid logistics migration' end
  if p.purchasedDrones==nil then p.purchasedDrones=0 end
  if p.logistics==nil then p.logistics=logisticsOwnership() end
  if p.run.logistics==nil then p.run.logistics={storage={},launchCargo={},launchRemaining=0,backpackCargo={},pendingCargo={}} end
  p.schemaVersion=7
 end
 if p.schemaVersion==7 then
  if p.consumables==nil then p.consumables=Consumables.fresh() end
  p.schemaVersion=8
 end
 if p.schemaVersion==8 then
  if type(p.run)~='table' or not integer(p.run.saleEarnings) then return nil,'Invalid Quartz migration' end
  -- Honor already-earned run progress once; every new sale counts only Quartz.
  p.run.quartzEarnings=p.run.saleEarnings;p.schemaVersion=9
 end
 if p.schemaVersion==9 then p.schemaVersion=10 end
 if p.schemaVersion==10 then p.starterDrones=1;p.schemaVersion=11 end
 if p.schemaVersion==11 and type(p.run)=='table' then
  p.run.stars=0;p.run.starUpgrades={};p.schemaVersion=12
 end
 local ok,err=P.validate(p,uid);if not ok then return nil,err end
 if p.starterDrones==oversizedStarterCount then
  if not correctStarterGrant(p) then return nil,'Unexpected oversized starter fleet' end
  ok,err=P.validate(p,uid);if not ok then return nil,err end
 end
 -- An acknowledged save reserves the charge before any world damage. If the
 -- server went away before its first accepted contact, return the unused tool.
 Consumables.refund(p.consumables)
 return p
end
function P.receipt(p,operation,tx)
 if type(tx)~='string' or #tx<1 or #tx>128 then return nil end
 for i=#p.receipts,1,-1 do local r=p.receipts[i];if r.operation==operation and r.id==tx then return clone(r.result) end end
 return nil
end
function P.record(p,operation,tx,result)
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid transaction ID' end
 table.insert(p.receipts,{operation=operation,id=tx,runId=p.run.id,result=clone(result)})
 while #p.receipts>64 do table.remove(p.receipts,1) end
 return true
end
function P.buyStarUpgrade(p,id,level,tx,expectedRun)
 if expectedRun~=p.run.id or type(tx)~='string' or #tx<1 or #tx>128 or not integer(level) then return false,'Invalid Star Shop order' end
 local replay=P.receipt(p,'StarUpgrade',tx)
 if replay then return replay.id==id and replay.level==level+1,replay end
 local entry=type(id)=='string' and Workshop.STAR_BY_ID[id]
 if not entry or entry.legacy then return false,'Invalid Star Shop upgrade' end
 local owned=Workshop.starLevel(p,id)
 if level~=owned or owned>=entry.max then return false,'Upgrade level changed' end
 local price=Workshop.starPrice(entry,owned)
 if p.run.stars<price then return false,'Need '..price..' Stars' end
 p.run.stars-=price;p.run.starUpgrades[id]=owned+1
 local result={id=id,level=owned+1,title=entry.title}
 P.record(p,'StarUpgrade',tx,result);return true,result
end
function P.buyDrone(p,kind,tx,expectedRun,context)
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid transaction ID' end
 local replay=P.receipt(p,'BuyDrone',tx)
 if replay then
  if replay.droneType~=kind or replay.runId~=expectedRun then return false,'Transaction ID already used' end
  return true,replay
 end
 if expectedRun~=p.run.id then return false,'Stale run' end
 return false,'Earn a permanent mining drone through Quartz prestige'
end
function P.cargoUnits(p)
 return bagUnits(p.run.cargo)
end
function P.deliveryUnits(p,id)
 local manifest=p.run.deliveries[id];return manifest and bagUnits(manifest.cargo) or 0
end
function P.droneCargoUnits(p,id)
 return bagUnits(p.run.droneCargo[id])+P.deliveryUnits(p,id)
end
function P.reconcileCargo(p,eligibleDroneIds)
 local eligible={};local changed=false
 for key,value in pairs(eligibleDroneIds or {}) do
  local id=type(key)=='string' and value==true and key or value
  if cargoId(p,id) then eligible[id]=true end
 end
 local function retain(bag)
  for material,units in pairs(bag) do p.run.cargo[material]=(p.run.cargo[material] or 0)+units end
 end
 local retired={}
 for id in pairs(p.run.droneCargo) do table.insert(retired,id) end
 for _,id in ipairs(retired) do
  local bag=p.run.droneCargo[id];p.run.droneCargo[id]=nil;retain(bag);changed=true
 end
 for id,manifest in pairs(p.run.deliveries) do if not eligible[id] then
  p.run.deliveries[id]=nil;retain(manifest.cargo);changed=true
 end end
 return changed
end
function P.addCargo(p,material,units,capacity)
 if type(material)~='string' or #material>40 or not integer(units) or not finite(capacity) or capacity<0 then return 0 end
 local accepted=math.min(units,math.max(0,math.floor(capacity)-P.cargoUnits(p)))
 p.run.cargo[material]=(p.run.cargo[material] or 0)+accepted;return accepted
end
-- Mining completes indivisible nodes. Keep the whole final drop, then require
-- a sale before any further mining; never erase a hard-earned core at the cap.
-- The caller supplies a bounded server-authored node yield, not client input.
function P.addMiningCargo(p,material,units,capacity,droneId)
 if type(material)~='string' or #material>40 or not integer(units) or not finite(capacity) or capacity<1 then return 0 end
 if droneId~=nil and not cargoId(p,droneId) then return 0 end
 local held=bagUnits(p.run.cargo)
 if held>=math.floor(capacity) or P.cargoUnits(p)+units>=1e14 then return 0 end
 local bag=p.run.cargo
 bag[material]=(bag[material] or 0)+units
 return units
end
local function deliveryCargo(cargo,batchSize,quartzFirst)
 local manifest,remaining={},batchSize
 local materials,values={},{}
 for material in pairs(cargo) do
  table.insert(materials,material)
  if quartzFirst then values[material]=Shops.quartzValue(material) or 0 end
 end
 table.sort(materials,function(a,b)
  if quartzFirst and values[a]~=values[b] then return values[a]>values[b] end
  return a<b
 end)
 for _,material in ipairs(materials) do
  local units=math.min(remaining,cargo[material])
  if units>0 then manifest[material]=units;remaining-=units end
  if remaining==0 then break end
 end
 return manifest
end
local function cargoQuartz(cargo)
 local value=0
 for material,units in pairs(cargo) do value+=units*(Shops.quartzValue(material) or 0) end
 return value
end
function P.deliveryQuartz(p)
 local value=0
 for _,manifest in pairs(p.run.deliveries) do value+=cargoQuartz(manifest.cargo) end
 return value
end
function P.deliveryFundsMilestone(p,batchSize)
 local run=p.run
 if run.pendingOffer then return false end
 local incoming=P.deliveryQuartz(p)
 local packGap=Workshop.price(p)-run.wallet.Quartz-incoming
 local prestigeGap=P.milestone(p).earnings-run.quartzEarnings-incoming
 local shortfall=math.min(packGap>0 and packGap or math.huge,prestigeGap>0 and prestigeGap or math.huge)
 if shortfall==math.huge then return false end
 local parcel=P.cargoUnits(p)<=batchSize and run.cargo or deliveryCargo(run.cargo,batchSize,true)
 return cargoQuartz(parcel)>=shortfall
end
function P.beginDelivery(p,droneId,tx,expectedRun,batchSize,quartzFirst)
 if expectedRun~=p.run.id or not cargoId(p,droneId) then return false,'Stale run or unknown carrier' end
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid delivery ID' end
 local replay=P.receipt(p,'BeginDelivery',tx)
 if replay then return replay.droneId==droneId and replay.runId==expectedRun,replay end
 local existing=p.run.deliveries[droneId]
 if existing then return true,{id=existing.id,droneId=droneId,runId=p.run.id,units=bagUnits(existing.cargo)} end
 for _,manifest in pairs(p.run.deliveries) do if manifest.id==tx then return false,'Delivery ID already assigned' end end
 if not integer(batchSize) or batchSize<1 or batchSize>32 then return false,'Invalid courier batch' end
 if bagUnits(p.run.cargo)<=0 then return false,'Backpack is empty' end
 local bag=deliveryCargo(p.run.cargo,batchSize,quartzFirst)
 for material,units in pairs(p.run.cargo) do
  local left=units-(bag[material] or 0)
  p.run.cargo[material]=left>0 and left or nil
 end
 p.run.deliveries[droneId]={id=tx,droneId=droneId,runId=p.run.id,cargo=bag}
 local result={id=tx,droneId=droneId,runId=p.run.id,units=bagUnits(bag)}
 P.record(p,'BeginDelivery',tx,result);return true,result
end
function P.finishDelivery(p,droneId,prices,tx,expectedRun)
 if expectedRun~=p.run.id or not cargoId(p,droneId) then return false,'Stale run or unknown carrier' end
 local replay=P.receipt(p,'FinishDelivery',tx)
 if replay then return replay.droneId==droneId and replay.runId==expectedRun,replay end
 local manifest=p.run.deliveries[droneId]
 if not manifest or manifest.id~=tx or manifest.runId~=expectedRun then return false,'Delivery no longer pending' end
 local amount=0
 for material,units in pairs(manifest.cargo) do
  local price=Shops.oreValue(prices,material);if not finite(price) or price<0 then return false,'Unknown material value' end
  amount=amount+units*price
 end
 amount=math.floor(amount)
 if not integer(amount) or p.run.credits+amount>=1e14 or p.run.saleEarnings+amount>=1e14 then return false,'Sale limit exceeded' end
 local deposited,quartz=Shops.deposit(p.run,manifest.cargo);if not deposited then return false,quartz end
 p.run.deliveries[droneId]=nil;p.run.credits=p.run.wallet.Quartz;p.run.saleEarnings=p.run.saleEarnings+amount;p.run.quartzEarnings+=quartz
 local result={id=tx,droneId=droneId,runId=p.run.id,units=bagUnits(manifest.cargo),credits=amount,quartz=quartz}
 P.record(p,'FinishDelivery',tx,result);return true,result
end
function P.sell(p,prices,tx,expectedRun)
 local replay=P.receipt(p,'Sell',tx);if replay then
  if replay.runId~=expectedRun then return false,'Transaction ID already used' end
  return true,replay
 end
 if expectedRun~=p.run.id then return false,'Stale run' end
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid transaction ID' end
 local units=P.cargoUnits(p);if units==0 then return false,'Backpack is empty' end
 local manifest=clone(p.run.cargo)
 local amount=0
 for material,n in pairs(p.run.cargo) do
  local value=Shops.oreValue(prices,material);if not finite(value) or value<0 then return false,'Unknown material value' end
  amount+=n*value
 end
 amount=math.floor(amount)
 if not integer(amount) or p.run.credits+amount>=1e14 or p.run.saleEarnings+amount>=1e14 then return false,'Sale limit exceeded' end
 local deposited,quartz=Shops.deposit(p.run,p.run.cargo);if not deposited then return false,quartz end
 p.run.cargo={};p.run.credits=p.run.wallet.Quartz;p.run.saleEarnings=p.run.saleEarnings+amount;p.run.quartzEarnings+=quartz
 local result={credits=amount,earnings=amount,units=units,cargo=manifest,quartz=quartz,runId=p.run.id};P.record(p,'Sell',tx,result);return true,result
end
function P.milestone(p)
 return {earnings=math.min(1000000000000,math.floor(Workshop.PRESTIGE_BASE*(1+p.prestiges)^1.35)),field='Quartz',wins=0}
end
local function prestigeDrone(p,kind)
 return specialTypes[kind] and specialDrone(p.userId,p.nextDroneSerial,kind,p.seed)
  or drone(p.userId,p.nextDroneSerial,kind,p.seed,kind=='Red' and 2 or 1)
end
function P.prestigePreview(p)
 local m=P.milestone(p);local earned=p.run.quartzEarnings
 local eligible=earned>=m.earnings and p.run.pendingOffer==nil
 local reason=p.run.pendingOffer and 'Choose your purchased card before prestige' or (earned<m.earnings and 'Sell more Quartz this run' or 'Ready at the Prestige beacon')
 return {eligible=eligible,reason=reason,miningBonusBefore=p.prestiges*.25,miningBonusAfter=(p.prestiges+1)*.25,
  saleRequired=m.earnings,field='Quartz',winsRequired=0,wins=0,earnings=earned,fleetBefore=#p.fleet,fleetAfter=#p.fleet+1,
  cards=#p.run.cards,runId=p.run.id,droneChoices=eligible and DroneCatalog.prestigeChoices(p.seed,p.run.index) or nil}
end
P.prestigeEligibility=P.prestigePreview
function P.prestige(p,tx,expectedRun,context)
 context=context or {}
 local replay=P.receipt(p,'Prestige',tx)
 if replay then
  if replay.oldRunId~=expectedRun or replay.droneType~=context.droneType then return false,'Prestige choice already committed' end
  return true,replay
 end
 if expectedRun~=p.run.id then return false,'Stale run' end
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid transaction ID' end
 if not context.atDepot or context.activeEncounter then return false,'Recall your fighting drones and return to the depot' end
 if context.confirmed~=true then return false,'Explicit prestige confirmation required' end
 local preview=P.prestigePreview(p);if not preview.eligible then return false,preview.reason end
 local reward
 for _,choice in ipairs(preview.droneChoices) do
  if choice.kind==context.droneType then reward=choice;break end
 end
 if not reward then return false,'Choose one of the three offered drones' end
 local oldRun=p.run.id;local serial=p.nextDroneSerial;local awarded=prestigeDrone(p,reward.kind)
 Consumables.refund(p.consumables)
 table.insert(p.fleet,awarded);p.nextDroneSerial=serial+1;p.prestiges=p.prestiges+1;p.run=run(p.userId,p.prestiges+1)
 local result={oldRunId=oldRun,runId=p.run.id,droneId=awarded.id,droneType=awarded.type,rewardName=reward.name,rewardTier=reward.tier,rewardJob=reward.job,fleetCount=#p.fleet,prestiges=p.prestiges}
 P.record(p,'Prestige',tx,result);return true,result
end
return P
