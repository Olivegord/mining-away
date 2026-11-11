--!strict
-- Drone Blower revolution • Olivegord/mining-away • generated from editable source.
local Workshop = (function()
-- One shared upgrade pool. Repeated picks merge into the same stack.
-- These local tuning values travel with the saved offer, so reconnects never reroll.
local W={PACK_BASE=20,PACK_GROWTH=1.35,LEVEL_COST=20,LEVEL_GROWTH=1.7,PRESTIGE_BASE=360}
-- Distinct cargo IDs preserve the older mineral shops and the value of saved ore.
W.CRYSTAL_TIERS={
 {material='Quartz',name='Quartz',hardness=1,value=1,cracks=3},
 {material='RunRuby',name='Ruby',hardness=3,value=4,cracks=3},
 {material='RunCobalt',name='Cobalt',hardness=9,value=16,cracks=3},
 {material='RunViolet',name='Violet',hardness=27,value=64,cracks=5},
 {material='RunEmerald',name='Emerald',hardness=81,value=256,cracks=7},
}
W.CRYSTAL_BY_MATERIAL={}
for _,tier in ipairs(W.CRYSTAL_TIERS) do
 W.CRYSTAL_BY_MATERIAL[tier.material]=tier
end
W.EMPTIERS=2
W.STARTER_SPECIALISTS={'Needler','Ballcaster','Vacuum','Compactor'}
W.EMPTIER_BATCH=4
W.EMPTIER_WAIT=6
W.COMPACTOR_BATCH=3
W.COMPACTOR_WAIT=5
W.COMPACTOR_PARTIAL_WAIT=1.5
W.COMPACTOR_REACH=12
function W.emptierId(runId,slot) return runId..':emptier:'..slot end
-- New physical cargo occupies one slot per object. Keep legacy mineral keys
-- unchanged so existing bags and in-flight Emptier manifests retain value.
function W.cargoKey(material,quartz,pressed)
 assert(W.CRYSTAL_BY_MATERIAL[material] and quartz>=1 and quartz<=1000000 and quartz%1==0,'Invalid crystal cargo')
 return (pressed and 'Block:' or 'Rock:')..material..':'..quartz
end
function W.crystalCargo(key)
 if type(key)~='string' then return nil end
 local form,material,digits=key:match('^(%a+):(%a+):(%d+)$')
 if (form~='Rock' and form~='Block') or not W.CRYSTAL_BY_MATERIAL[material] then return nil end
 local value=tonumber(digits)
 if not value or value<1 or value>1000000 or tostring(value)~=digits then return nil end
 return material,value,form=='Block'
end
W.TIERS={'Common','Rare','Epic','Legendary'}
W.CATALOG={
 {id='Q_POWER',title='Power Cell',scope='Fleet',category='mining',tier=1,max=6,step={mining=.5},color={246,113,93},icon='mining'},
 {id='Q_IGNITION',title='Quick Ignition',scope='Fleet',category='startup',tier=1,max=6,step={startup=1},color={69,190,244},icon='startup'},
 {id='Q_CARGO',title='Deep Pockets',scope='Player',category='cargo',tier=1,max=4,step={capacity=.5},color={255,190,65},icon='cargo'},
 {id='Q_BATTERY',title='Battery Cell',scope='Fleet',category='flight',tier=1,max=4,step={battery=100},color={118,215,112},icon='startup'},
 {id='Q_YIELD',title='Quartz Polisher',scope='Fleet',category='cargo',tier=2,max=4,step={yield=.25},color={188,119,245},icon='crystal'},
 {id='Q_SCANNER',title='Route Runner',scope='Fleet',category='flight',tier=2,max=5,step={speed=.4},once={plotAuto=1},color={78,211,145},icon='flight',sideFields=true},
 {id='Q_SPLIT',title='Prism Relay',scope='Fleet',category='mining',tier=2,max=4,step={fork=.1},once={forkRange=6},color={57,210,222},icon='relay'},
 {id='Q_THRUST',title='Thrusters',scope='Fleet',category='flight',tier=1,max=5,step={speed=.4},color={83,168,239},icon='flight'},
 {id='Q_HOT_START',title='Hot Start',scope='Fleet',category='startup',tier=3,max=3,step={startup=2,mining=.25},color={248,144,75},icon='startup'},
 {id='Q_CARGO_LOOP',title='Cargo Loop',scope='Fleet',category='cargo',tier=3,max=3,step={capacity=.5,yield=.125},color={236,173,63},icon='cargo'},
 {id='Q_PRISM_DRIVE',title='Prism Drive',scope='Fleet',category='mining',tier=3,max=3,step={fork=.1,speed=.3},once={forkRange=6},color={75,179,230},icon='relay'},
 {id='Q_OVERDRIVE',title='Overdrive Core',scope='Fleet',category='mining',tier=4,max=3,step={mining=1,startup=2},color={250,109,81},icon='mining'},
 {id='Q_PRISM_CORE',title='Prismatic Core',scope='Fleet',category='mining',tier=4,max=2,step={fork=.2,yield=.25},once={forkRange=6},color={115,132,248},icon='relay'},
 {id='Q_AUTONOMOUS',title='Autonomous Fleet',scope='Fleet',category='flight',tier=4,max=2,step={speed=.75,capacity=.5},once={plotAuto=1},color={81,204,157},icon='fleet',sideFields=true},
 {id='Q_TWIN_BEAM',title='Twin Beam',scope='Fleet',category='mining',tier=2,max=2,step={fork=.2},once={forkRange=6},color={57,210,222},icon='relay',crystalRun=true},
 {id='Q_DEEP_DRILL',title='Deep Drill',scope='Fleet',category='mining',tier=2,max=3,step={deepCut=.6},color={246,113,93},icon='mining',crystalRun=true},
 {id='Q_ORE_MAGNET',title='Ore Magnet',scope='Player',category='cargo',tier=2,max=3,step={magnetRange=12},color={255,190,65},icon='cargo',crystalRun=true},
 {id='Q_AFTERSHOCK',title='Aftershock',scope='Fleet',category='mining',tier=2,max=3,step={aftershock=.12},color={110,195,255},icon='relay',crystalRun=true},
 {id='Q_RECLAIM',title='Reclaim',scope='Fleet',category='flight',tier=1,max=3,step={reclaim=6},color={134,221,129},icon='startup',crystalRun=true},
 {id='Q_EARLY_DROP',title='Loose Seams',scope='Fleet',category='cargo',tier=1,max=2,step={earlyDrop=.25},color={255,190,65},icon='crystal',crystalRun=true},
 {id='Q_FIELD_CHARGE',title='Field Charger',scope='Player',category='flight',tier=3,max=2,step={fieldCharge=28},color={112,214,175},icon='startup',crystalRun=true},
 {id='Q_DOUBLE_BEAM',title='Double Beam',scope='Individual',category='mining',tier=2,max=1,step={doubleBeam=1},color={91,208,255},icon='relay',crystalRun=true,hardware=true},
 {id='Q_TURBO_ROTOR',title='Twin Thrusters',scope='Individual',category='flight',tier=2,max=1,step={twinThrusters=1},color={255,137,66},icon='flight',crystalRun=true,hardware=true},
 {id='Q_ORE_DUPLICATOR',title='Ore Duplicator',scope='Individual',category='cargo',tier=2,max=1,step={oreDuplicator=1},color={255,216,93},icon='crystal',crystalRun=true,hardware=true},
 {id='Q_COMPACTOR',title='Compactor Drone',scope='Player',category='cargo',tier=2,max=1,step={compactor=1},color={255,184,83},icon='cargo',crystalRun=true},
 {id='Q_BATCH_PRESS',title='Batch Press',scope='Player',category='cargo',tier=3,max=1,step={batchPress=1},color={255,216,93},icon='cargo',crystalRun=true},
 {id='Q_DENSER_PACK',title='Denser Packing',scope='Player',category='cargo',tier=3,max=1,step={denserPacking=2},color={255,216,93},icon='cargo',crystalRun=true},
 {id='Q_CARGO_RACK',title='Cargo Rack',scope='Player',category='cargo',tier=2,max=2,step={cargoRack=1},color={255,190,65},icon='cargo',crystalRun=true},
 {id='Q_LIVE_WIRE',title='Live Wire',scope='Fleet',category='mining',tier=3,max=2,step={liveWire=.5},color={134,221,129},icon='mining',crystalRun=true},
 {id='Q_SHIFT_RELAY',title='Shift Relay',scope='Player',category='mining',tier=3,max=3,step={shiftRelay=12},color={255,200,110},icon='relay',crystalRun=true},
}
W.BY_ID={};for _,entry in ipairs(W.CATALOG) do W.BY_ID[entry.id]=entry end
W.FIRST_PACK={'Q_DOUBLE_BEAM','Q_EARLY_DROP','Q_AFTERSHOCK'}
W.LOOSE_SEAMS_TEXT='Ore drops mid-cut.\nLonger pickup reach.'
function W.shiftDescription(seconds)
 return 'Emptier sale primes your next cut.\n+50% damage for '..seconds..'s.'
end
function W.reclaimDescription(battery)
 return '+'..battery..' battery on breaks\nand new Violet or Emerald cracks.'
end
W.CRYSTAL_DRAFT={Q_POWER=true,Q_CARGO=true,Q_BATTERY=true,Q_DOUBLE_BEAM=true,Q_TURBO_ROTOR=true,Q_ORE_DUPLICATOR=true,
 Q_FIELD_CHARGE=true,Q_DEEP_DRILL=true,Q_ORE_MAGNET=true,Q_PRISM_DRIVE=true,Q_OVERDRIVE=true,Q_PRISM_CORE=true,
 Q_AFTERSHOCK=true,Q_EARLY_DROP=true,Q_RECLAIM=true,Q_DENSER_PACK=true,Q_CARGO_RACK=true,Q_LIVE_WIRE=true,Q_SHIFT_RELAY=true}
W.TRIGGER_CARDS={Q_DOUBLE_BEAM=true,Q_ORE_DUPLICATOR=true,Q_FIELD_CHARGE=true,Q_PRISM_DRIVE=true,Q_PRISM_CORE=true,
 Q_AFTERSHOCK=true,Q_EARLY_DROP=true,Q_RECLAIM=true,Q_COMPACTOR=true,Q_BATCH_PRESS=true,Q_DENSER_PACK=true,Q_CARGO_RACK=true,Q_LIVE_WIRE=true,Q_SHIFT_RELAY=true}
W.DEEP_CUT_HARDNESS=1.75
W.PAIRED_CUT_HARDNESS=27
function W.effect(p,key,extra)
 local total=extra and (extra.effects[key] or 0) or 0
 for _,card in ipairs(p.run.cards) do total+=card.effects[key] or 0 end
 return total
end
function W.hasCompactor(p,extra)
 for _,d in ipairs(p.fleet) do if d.role=='Compactor' then return true end end
 return W.effect(p,'compactor',extra)>0
end
function W.compactorBatch(p,extra) return W.COMPACTOR_BATCH-W.effect(p,'batchPress',extra)+W.effect(p,'denserPacking',extra) end
function W.emptierBatch(p,extra) return W.EMPTIER_BATCH+W.effect(p,'cargoRack',extra) end
function W.emptierReady(units,capacity,waitingSince,now)
 return units>=capacity or units>0 and waitingSince~=nil and now-waitingSince>=W.EMPTIER_WAIT
end
W.STAR_CATALOG={
 {id='vacuum',title='Vacuum Drone',description='Gathers loose ore and sends it to your bag.',cost=2,max=1,role='Vacuum',legacy=true},
 {id='cultivator',title='Crystal Planter',description='Replants empty spots under your pin.',cost=3,max=1,role='Dart',legacy=true},
 {id='autosell',title='Auto Sell',description='Sell a full backpack from the field',cost=6,max=1},
 {id='selector',title='Wider Selector',description='+4 studs to the square width',cost=2,max=3},
 {id='walk',title='Walking Speed',description='+2 studs per second on foot',cost=2,max=3},
 {id='charge',title='Quick Charge',description='+30% charge & depot flight',cost=3,max=3},
 {id='backpack',title='Backpack Lining',description='+2 cargo slots',cost=3,max=3},
}
W.STAR_BY_ID={};for _,entry in ipairs(W.STAR_CATALOG) do W.STAR_BY_ID[entry.id]=entry end
W.BATTERY=100
function W.starLevel(p,id) return (p.run.starUpgrades or {})[id] or 0 end
function W.chargeSpeed(p) return 1+.3*W.starLevel(p,'charge') end
function W.starPrice(entry,level) return entry.cost+level end
-- A fresh selector is as wide as one authored Crystal Run plot.
function W.selectorWidth(p) return 30+4*W.starLevel(p,'selector') end
function W.owned(p)
 local result={}
 for _,c in ipairs(p.run.cards) do if c.workshop then table.insert(result,c) end end
 return result
end
function W.find(p,id,targetId)
 for _,c in ipairs(p.run.cards) do if c.workshop and c.cardId==id and c.targetDroneId==targetId then return c end end
 return nil
end
function W.isHardware(c)
 local entry=c.workshop and W.BY_ID[c.cardId]
 return type(entry)=='table' and entry.hardware==true
end
-- These physical parts fit the basic laser chassis only. Preview actors and
-- permanent specialists cannot take a paid part that their rig cannot use.
function W.fits(d)
 local role=d.role or d.type
 return role=='Striker' or role=='Blue'
end
function W.targets(p,c)
 local result={}
 if W.isHardware(c) then
  for _,d in ipairs(p.fleet) do
   if W.fits(d) and not W.find(p,c.cardId,d.id) then table.insert(result,d) end
  end
 end
 return result
end
function W.price(p) return math.min(1e12,math.floor(W.PACK_BASE*W.PACK_GROWTH^math.min(p.run.packIndex,84)+.5)) end
function W.levelCost(c) return math.floor(c.levelCost*c.levelGrowth^(c.level-1)+.5) end
function W.effects(c,level)
 local effects={}
 for k,v in pairs(c.step) do effects[k]=v*level end
 for k,v in pairs(c.once or {}) do effects[k]=v end
 return effects
end
function W.card(entry,tier,ownedCount)
 local before=ownedCount or 0
 local c={cardId=entry.id,title=entry.title,scope=entry.scope,category=entry.category,workshop=true,
  level=1,stackVersion=2,upgradeTier=entry.tier,maxLevel=entry.max,step=table.clone(entry.step),once=table.clone(entry.once or {}),
  levelCost=W.LEVEL_COST,levelGrowth=W.LEVEL_GROWTH,rarity=W.TIERS[entry.tier],packTier=tier,expires='This run'}
 if ownedCount~=nil then c.stackBefore=before end
 c.effects=W.effects(c,c.level)
 c.description='Adds '..c.level..' stack'..(c.level==1 and '' or 's')..'. Duplicates combine.'
 c.headline=before>0 and (before..'× → '..(before+c.level)..'×') or ((before+c.level)..'× NEW UPGRADE')
 c.purpose='Collect upgrades and stack their effects';c.tradeoff='No equipment slots'
 c.stackText=(before+c.level)..'× · This run'
 return c
end
function W.validate(c)
 if not c.workshop then return true end
 local entry=W.BY_ID[c.cardId]
 if not entry or c.workshop~=true or c.scope~=entry.scope or type(c.level)~='number' or c.level%1~=0
  or c.level<1 or c.level>entry.max or c.maxLevel~=entry.max or c.levelCost~=W.LEVEL_COST or c.levelGrowth~=W.LEVEL_GROWTH
  or type(c.step)~='table' or type(c.once)~='table' or type(c.effects)~='table'
  or type(c.packTier)~='number' or c.packTier%1~=0 or c.packTier<1 or c.packTier>4 then return false end
 if c.stackVersion==2 then
  if c.upgradeTier~=entry.tier or c.rarity~=W.TIERS[entry.tier] then return false end
 elseif c.stackVersion~=nil or c.rarity~=W.TIERS[c.packTier] then return false end
 if c.stackBefore~=nil and (type(c.stackBefore)~='number' or c.stackBefore%1~=0 or c.stackBefore<0
  or c.stackBefore>=entry.max or c.level~=(c.stackVersion==2 and 1 or math.min(c.packTier,entry.max-c.stackBefore))) then return false end
 local function same(a,b)
  for k,v in pairs(a) do if b[k]~=v then return false end end
  for k,v in pairs(b) do if a[k]~=v then return false end end
  return true
 end
 return same(c.step,entry.step) and same(c.once,entry.once or {}) and same(c.effects,W.effects(c,c.level))
end
return W

end)()
local Shops = (function()
-- Pure mineral economy. Catalog prices are provisional playtest tuning;
-- ownership, quoted levels, spending and receipts are server transactions.
local S={ORDER={'Quartz','Ruby','Cobalt','Violet','Emerald'},PACK_CURRENCY='Quartz',PACKS_FREE=false}
function S.packPromptText(price)
 return 'Open Quartz Workshop'
end
S.COLORS={Quartz={180,225,213},Ruby={226,75,112},Cobalt={89,150,234},Violet={166,115,217},Emerald={70,184,139}}
local function item(id,shop,title,description,info,cost,max,effects,unlock,role)
 return {id=id,shop=shop,title=title,description=description,info=info,cost=cost,max=max or 1,effects=effects or {},unlock=unlock,role=role}
end
S.CATALOG={
 item('quartz_power','Quartz','Mining power','+50% base mining power per level','Adds 50% of base mining power to every mining drone per level. Four levels; stacks with cards up to the 4× run cap. Permanent prestige power applies on top. Resets on prestige.',20,4,{mining=.5}),
 item('quartz_scanner','Quartz','Auto target','Miners choose the next rock nearby','Earn automatic target selection. Click a rock once. Assigned workers keep choosing ready rocks until you recall or leave. Does not empty your backpack.',40,1,{plotAuto=1}),
 item('quartz_backpack','Quartz','Bigger backpack','+20 ore capacity per level','Adds 50% of the starting 40-unit backpack per level. Shared with capacity cards; total capacity is capped at 120. Whole final crystal drops are preserved.',30,3,{capacity=.5}),
 item('quartz_ruby','Quartz','Unlock Ruby','Opens the Ruby field and shop','Spend Quartz once to open Ruby for this run. Ruby purchases then spend Ruby. Guard clearances remain permanent.',80,1,nil,'Ruby'),
 item('ruby_cobalt','Ruby','Unlock Cobalt','Opens the Cobalt field and shop','Opens Cobalt this run. Its pyramid guard must still be defeated before mining; buying access never bypasses combat.',144,1,nil,'Cobalt'),
 item('ruby_pack_speed','Ruby','Fast pack reveal','2× faster card reveal','Halves the reveal and stagger of your three saved cards. Does not change prices, odds, saved choices or network/save time. You still choose one.',48,1,{packSpeed=1}),
 item('ruby_rotors','Ruby','Faster drones','+25% flight speed per level','Faster travel and courier trips, with the original eased arrival. Adds to speed cards up to the existing 3× flight cap.',36,2,{speed=.25}),
 item('cobalt_violet','Cobalt','Unlock Violet','Opens the Violet field and shop','Opens Violet this run. Its stronger guards remain a separate fleet challenge.',180,1,nil,'Violet'),
 item('cobalt_orbital','Cobalt','Orbital laser','Strike the biggest ready rock','Unlocks a mining ability. Charge above a cleared field, then automatically melt its biggest ready rock over four seconds. Server cooldown and field limits apply.',60,1,{orbitalLaser=1}),
 item('cobalt_pack_discount','Cobalt','Rich extraction','+25% ore yield per level','Every mining drone recovers 25% more ore per level. Stacks with cards up to double yield. Existing levels of the old pack discount carry over.',45,2,{yield=.25,packDiscount=.15}),
 item('cobalt_relay','Cobalt','Split beam','Deal 15% damage to a nearby rock','Splits 15% of a mining tick into one eligible nearby crystal. Stacks with fork cards up to the existing 20% fork cap; no recursive hits.',75,1,{fork=.15}),
 item('violet_emerald','Violet','Unlock Emerald','Opens the Emerald field and shop','Opens the deepest field this run. Its guards and harder crystals require a developed fleet.',240,1,nil,'Emerald'),
 item('violet_scrap','Violet','Scrap-bot swarm','Deploy mining bots for 10s','Unlocks a short-lived mining ability. A miniature swarm works on ready rocks in your cleared field for ten seconds, then disappears. No permanent drones are consumed.',80,1,{scrapSwarm=1}),
 item('violet_courier','Violet','Faster couriers','Couriers fly delivery trips 2× faster','Adds 100% courier travel speed, capped with courier cards. Requires a permanent Courier. Couriers collect small real parcels, fly to storage and return.',48,1,{fullAuto=1}),
 item('emerald_orbital_cycle','Emerald','Rapid orbital laser','Orbital strike every 30s','A complete orbital ability, usable without another upgrade. Charge and automatically strike the biggest ready rock. Cleared-field gates still apply.',80,1,{orbitalLaser=1,orbitalCycle=1}),
 item('emerald_relay','Emerald','Wide split beam','Deal 20% damage within 12 studs','A complete mining behavior: split 20% damage into one eligible nearby crystal within 12 studs. Works without Beam relay. Does not increase command radius or recurse.',60,1,{fork=.20,forkRange=6}),
 item('quartz_miner_focus','Quartz','Faster miner laser','Half the laser warmup for Miners','Striker/Miner hardware only: adds 100% of base startup rate, halving laser warmup on its own. Stacks with startup cards; does not accelerate travel, breaker windup or healing.',35,1,{startup=1},nil,'Striker'),
 item('ruby_courier_hold','Ruby','Bigger courier loads','Couriers carry 32 ore per trip','Courier hardware carries up to 32 real ore instead of 8 per trip. It collects from your backpack, flies to orbital storage, then returns. Requires a Courier; resets on prestige.',55,1,{courierCapacity=3},nil,'Courier'),
 item('ruby_breaker_head','Ruby','Stronger breaker','+80% geode damage for Breakers','Charger/Breaker hardware only: +80% damage against geode shells and cores. Its windup, physical dive and recovery still happen.',65,1,{geode=.8},nil,'Charger'),
 item('cobalt_scout_memory','Cobalt','Faster planting','Cultivators plant every 2.5s','Cultivator hardware only: halves planting cooldown from 5 to 2.5 seconds. Requires an empty rock slot, a depleted-rock replacement and a cleared field. Preserves rock health, yield and two-second growth.',50,1,{scanDuration=1},nil,'Dart'),
 item('violet_repair_kit','Violet','Stronger repairs','Healers repair 20 hull per pulse','Medic/Healer hardware only: restores 20 instead of 10 hull every two seconds. Keeps the existing healer flight and attached repair beam.',65,1,{healPower=1},nil,'Medic'),
 item('emerald_swarm_bay','Emerald','Bigger swarms','Fabricators deploy 2 extra bots','Scrapper hardware only: six bots per ten-second deployment instead of four. Same shared saved cooldown; no permanent drone is consumed.',85,1,{scrapBots=2},nil,'Scrapper'),
 item('emerald_pack_speed','Emerald','Rapid pack reveal','4× faster card reveal','Four times the original reveal speed on its own. Does not require the Ruby upgrade. Every offer still has three saved choices and explicit selection; reveal speed caps at 4×.',100,1,{packSpeed=2}),
}
S.BY_ID={};for _,entry in ipairs(S.CATALOG) do S.BY_ID[entry.id]=entry end
local function integer(n) return type(n)=='number' and n==n and n>=0 and n<1e14 and n%1==0 end
function S.fresh(run)
 run.wallet={};for _,key in ipairs(S.ORDER) do run.wallet[key]=0 end
 run.shops={Quartz=true};run.shopLevels={}
end
function S.validate(run)
 if type(run.wallet)~='table' or type(run.shops)~='table' or type(run.shopLevels)~='table' then return false,'Missing mineral shop state' end
 for _,key in ipairs(S.ORDER) do if not integer(run.wallet[key]) then return false,'Invalid '..key..' balance' end end
 for key in pairs(run.wallet) do if not S.COLORS[key] then return false,'Unknown currency' end end
 if run.shops.Quartz~=true then return false,'Quartz shop missing' end
 for key,value in pairs(run.shops) do if not S.COLORS[key] or value~=true then return false,'Invalid shop unlock' end end
 local locked=false
 for _,key in ipairs(S.ORDER) do if not run.shops[key] then locked=true elseif locked then return false,'Disconnected shop progression' end end
 for id,n in pairs(run.shopLevels) do
  local entry=S.BY_ID[id]
  if not entry or not integer(n) or n>entry.max or not run.shops[entry.shop] then return false,'Invalid shop level' end
  if n>0 and entry.unlock and not run.shops[entry.unlock] then return false,'Missing purchased shop' end
 end
 return true
end
function S.effects(p,role)
 local effects={}
 for id,n in pairs(p.run.shopLevels or {}) do
  local entry=S.BY_ID[id]
  if entry and (not entry.role or entry.role==role) then for key,value in pairs(entry.effects) do effects[key]=(effects[key] or 0)+n*value end end
 end
 return effects
end
function S.abilityUnlocked(p,kind,extra)
 local key=kind=='Orbital' and 'orbitalLaser' or 'scrapSwarm'
 if (S.effects(p)[key] or 0)>0 or (extra and (extra.effects[key] or 0)>0) then return true end
 for _,c in ipairs(p.run.cards) do if (c.effects[key] or 0)>0 then return true end end
 for _,d in ipairs(p.activeFleet or p.fleet) do if d.role==(kind=='Orbital' and 'Orbiter' or 'Scrapper') then return true end end
 return false
end
function S.packSpeed(p) return 2^math.min(2,S.effects(p).packSpeed or 0) end
function S.cost(entry,level) return math.floor(entry.cost*2^(level or 0)) end
function S.balance(p,key) return (p.run.wallet or {})[key] or 0 end
function S.unlocked(p,key) return p.run.shops and p.run.shops[key]==true end
local capped={
 quartz_power={'mining',3},ruby_rotors={'speed',2},cobalt_pack_discount={'yield',1},
 cobalt_relay={'fork',.2,miner=true},emerald_relay={'forkRange',6,miner=true},violet_courier={'fullAuto',2,role='Courier'},
 ruby_breaker_head={'geode',.8,role='Charger'},
}
local function roleOf(d)
 local role=d.role or d.type
 return ({Blue='Striker',Red='Charger',Green='Medic'})[role] or role
end
local function hasRoom(p,fleet,key,limit,role)
 for _,d in ipairs(fleet) do
  local actual=roleOf(d)
  local support=actual=='Dart' or actual=='Courier' or actual=='Medic' or actual=='Orbiter' or actual=='Scrapper'
  if (not role or actual==role) and not (support and (key=='mining' or key=='yield')) then
   local effects=S.effects(p,actual);local amount=effects[key] or 0
   for _,c in ipairs(p.run.cards) do
    if c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Individual' and c.targetDroneId==d.id)
     or (c.scope=='Color' and c.type==d.type) or (c.scope=='Player' and key=='fullAuto' and actual=='Courier') then
     amount+=c.effects[key] or 0
    end
   end
   if amount<limit-1e-8 then return true end
  end
 end
 return false
end
function S.reason(p,entry,context)
 if not S.unlocked(p,entry.shop) then return 'Unlock '..entry.shop..' first' end
 local fleet=(context and context.fleet) or p.activeFleet or p.fleet
 if entry.id=='cobalt_orbital' and S.abilityUnlocked(p,'Orbital') then return 'Orbital laser already installed' end
 if entry.id=='violet_scrap' and S.abilityUnlocked(p,'Scrap') then return 'Scrap swarm already installed' end
 if entry.id=='ruby_pack_speed' and S.packSpeed(p)>=2 then return 'Pack reveal already accelerated' end
 if entry.id=='emerald_pack_speed' and S.packSpeed(p)>=4 then return 'Pack reveal already at full speed' end
 if entry.id=='quartz_scanner' then for _,c in ipairs(p.run.cards) do if (c.effects.plotAuto or 0)>0 then return 'Automatic targeting already installed' end end end
 if entry.id=='quartz_backpack' then
  local capacity=S.effects(p).capacity or 0
  for _,c in ipairs(p.run.cards) do capacity=capacity+(c.effects.capacity or 0) end
  if capacity>=2 then return 'Backpack already at 120 ore' end
 end
 if entry.role then
  local found=false
  for _,d in ipairs(fleet) do if roleOf(d)==entry.role then found=true;break end end
  local names={Striker='Miner',Charger='Breaker',Dart='Grower',Medic='Healer',Scrapper='Swarm Fabricator'}
  if not found then return 'Requires a '..(names[entry.role] or entry.role) end
 end
 if entry.id=='violet_courier' then
  local found=false;for _,d in ipairs(fleet) do if roleOf(d)=='Courier' then found=true;break end end
  if not found then return 'Requires a Courier drone' end
 end
 local cap=capped[entry.id]
 if cap then
  if cap.miner then
   local found=false;for _,d in ipairs(fleet) do if roleOf(d)=='Striker' then found=true;break end end
   if not found then return 'Requires a Miner' end
  end
  if not hasRoom(p,fleet,cap[1],cap[2],cap.miner and 'Striker' or cap.role)
   and not (entry.id=='emerald_relay' and hasRoom(p,fleet,'fork',.20,'Striker')) then return 'Already at the upgrade cap' end
 end
 return nil
end
function S.oreValue(prices,material)
 local _,cargoValue=Workshop.crystalCargo(material)
 if cargoValue then return cargoValue end
 local tier=Workshop.CRYSTAL_BY_MATERIAL[material]
 return tier and material~='Quartz' and tier.value or (prices and prices[material])
end
function S.quartzValue(material)
 local _,value=Workshop.crystalCargo(material)
 local tier=Workshop.CRYSTAL_BY_MATERIAL[material]
 return value or (tier and tier.value)
end
-- Validate the complete mixed bag before touching any balance.
function S.deposit(run,bag)
 local deposit={}
 for key,n in pairs(bag) do
  local quartz=S.quartzValue(key)
  if (not quartz and not S.COLORS[key]) or not integer(n) then return false,'Invalid mineral deposit' end
  local currency=quartz and 'Quartz' or key
  deposit[currency]=(deposit[currency] or 0)+n*(quartz or 1)
 end
 for key,n in pairs(deposit) do
  if not integer(run.wallet[key]+n) then return false,'Invalid mineral deposit' end
 end
 for key,n in pairs(deposit) do run.wallet[key]+=n end
 return true,deposit.Quartz or 0
end
function S.buy(p,id,level,tx,expectedRun,context)
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid transaction ID' end
 if expectedRun~=p.run.id then return false,'Stale run' end
 for i=#p.receipts,1,-1 do local receipt=p.receipts[i]
  if receipt.operation=='Shop' and receipt.id==tx then
   if receipt.result.id~=id or receipt.result.runId~=expectedRun then return false,'Transaction ID already used' end
   return true,receipt.result
  end
 end
 local entry=type(id)=='string' and S.BY_ID[id]
 if not entry then return false,'Unknown upgrade' end
 if not context or context.shop~=entry.shop or context.atShop~=true or context.activeEncounter then return false,'Visit this shop outside combat' end
 local why=S.reason(p,entry,context);if why then return false,why end
 local owned=p.run.shopLevels[id] or 0
 if not integer(level) or level~=owned then return false,'Price changed; refresh the shop' end
 if owned>=entry.max or (entry.unlock and S.unlocked(p,entry.unlock)) then return false,'Already complete' end
 local cost=S.cost(entry,owned)
 if S.balance(p,entry.shop)<cost then return false,'Need '..cost..' '..entry.shop end
 p.run.wallet[entry.shop]=p.run.wallet[entry.shop]-cost;p.run.shopLevels[id]=owned+1
 if entry.unlock then p.run.shops[entry.unlock]=true end
 local result={id=id,level=owned+1,currency=entry.shop,cost=cost,runId=p.run.id}
 table.insert(p.receipts,{operation='Shop',id=tx,runId=p.run.id,result=result})
 while #p.receipts>64 do table.remove(p.receipts,1) end
 return true,result
end
return S

end)()
local ShopStands = (function()
-- Grounded, named counters at the depot. Reuse the captured PackStation shell;
-- never move the original machine or replace field/world assets.
local Stands={}
function Stands.position(home,index,groundY)
 local offset=({-16,-20,12,24,36})[index]
 return Vector3.new(home.X+offset,groundY+1.5,home.Z+(index==1 and 32 or 18))
end
local function addSign(station,text,height)
  local existing=station:FindFirstChild('TestLabel')
  if existing then for _,node in ipairs(existing:GetDescendants()) do if node:IsA('TextLabel') then node.Text=text end end;return end
  local sign=station:FindFirstChild('ShopSign')
  if not sign then sign=Instance.new('Part');sign.Name='ShopSign';sign.Parent=station end
  sign.Anchored=true;sign.CanCollide=false;sign.CanTouch=false;sign.CanQuery=false
  sign.Size=Vector3.new(7.5,2,.25);sign.CFrame=CFrame.new(station.Position+Vector3.new(0,station.Size.Y/2+height,0));sign.Material=Enum.Material.Metal;sign.Color=Color3.fromRGB(30,30,60)
  for _,side in ipairs({'Front','Back'}) do
   local face=sign:FindFirstChild(side) or Instance.new('SurfaceGui');face.Name=side;face.Face=Enum.NormalId[side]
   face.CanvasSize=Vector2.new(600,160);face.LightInfluence=0;face.Parent=sign
   local title=face:FindFirstChild('ShopName') or Instance.new('TextLabel');title.Name='ShopName'
   title.Size=UDim2.fromScale(1,1);title.BackgroundTransparency=1;title.TextColor3=station.Color
   title.Font=Enum.Font.SourceSansBold;title.TextSize=54;title.Text=text;title.Parent=face
  end
end
local function quartzWorkshop(stations)
 for key,station in pairs(stations) do
  local stars=key=='Ruby'
  local title=stars and 'Star Shop' or key=='Quartz' and 'Quartz Workshop' or 'Future field'
  if stars then station:SetAttribute('Interaction','Stars') end
  local prompt=station:FindFirstChildOfClass('ProximityPrompt')
  if prompt then prompt.Enabled=key=='Quartz' or stars;prompt.ActionText='Open';prompt.ObjectText=title end
  local sign=station:FindFirstChild('ShopSign')
  if sign then for _,node in ipairs(sign:GetDescendants()) do if node:IsA('TextLabel') then node.Text=title=='Future field' and key:upper()..' · LATER' or title:upper() end end end
 end
end
function Stands.mount(map,home,template)
 local stations={}
 local prestige=map:FindFirstChild('PrestigeStation',true)
 if prestige then
  prestige:SetAttribute('Interaction','Prestige')
  local prompt=prestige:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
  prompt.ActionText='Review prestige';prompt.ObjectText='PRESTIGE'
  prompt.Enabled=true;prompt.HoldDuration=0;prompt.MaxActivationDistance=12
  prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.RequiresLineOfSight=false;prompt.Parent=prestige
  addSign(prestige,'PRESTIGE',3)
 end
 local printer=map:FindFirstChild('Printer',true)
 if printer then
  printer:SetAttribute('Interaction','Printer')
  local prompt=printer:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
  prompt.ActionText='Manage permanent fleet';prompt.ObjectText='DRONE YARD'
  prompt.Enabled=true;prompt.HoldDuration=0;prompt.MaxActivationDistance=12
  prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.RequiresLineOfSight=false;prompt.Parent=printer
  addSign(printer,'DRONE YARD',3)
 end
 addSign(template,'PACK COUNTER',3)
 local packPrompt=template:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
 packPrompt.ActionText='Buy pack';packPrompt.ObjectText='Upgrade packs'
 packPrompt.KeyboardKeyCode=Enum.KeyCode.E;packPrompt.GamepadKeyCode=Enum.KeyCode.ButtonX;packPrompt.HoldDuration=0;packPrompt.Enabled=true
 packPrompt.MaxActivationDistance=12;packPrompt.RequiresLineOfSight=false
 packPrompt.Parent=template
 template:SetAttribute('Interaction','Pack')
 local packBillboard=template:FindFirstChildOfClass('BillboardGui')
 if packBillboard then packBillboard:Destroy() end
 if map.Parent and map.Parent:GetAttribute('DronerevolutionMapVersion') then
  for _,key in ipairs(Shops.ORDER) do
   local station=assert(map:FindFirstChild(key..'Shop'),'Authored map is missing shop '..key)
   station:SetAttribute('Interaction','Shop');station:SetAttribute('ShopKey',key)
   local prompt=station:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
   prompt.ActionText='View upgrades';prompt.ObjectText=key..' shop'
   prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.HoldDuration=0;prompt.Enabled=true;prompt.Parent=station
   stations[key]=station
  end
  quartzWorkshop(stations)
  return stations
 end
 local pad=map:FindFirstChild('HubPad',true)
 local groundY=pad and pad.Position.Y+pad.Size.Y/2 or template.Position.Y-template.Size.Y/2
 for index,key in ipairs(Shops.ORDER) do
  local name=key..'Shop';local station=map:FindFirstChild(name)
  if not station then
   station=template:Clone();station.Name=name
   for _,child in ipairs(station:GetChildren()) do child:Destroy() end
  end
  station.Size=Vector3.new(6,3,4);station.Anchored=true;station.Material=Enum.Material.Metal;station.Reflectance=0
  station.Transparency=0;station.Color=Color3.fromRGB(unpack(Shops.COLORS[key]))
  station:SetAttribute('Interaction','Shop');station:SetAttribute('ShopKey',key);station:SetAttribute('ShopStandVersion',2)
  local position=Stands.position(home,index,groundY)
  station.CFrame=CFrame.new(position);station.Parent=map
  addSign(station,key:upper()..' SHOP',1)
  -- Remove the obsolete face painted onto the low, far-field cube.
  for _,child in ipairs(station:GetChildren()) do if child:IsA('SurfaceGui') then child:Destroy() end end
  local prompt=station:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
  prompt.ActionText='View upgrades';prompt.ObjectText=key..' shop';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.HoldDuration=0;prompt.Enabled=true;prompt.Parent=station
  stations[key]=station
 end
 quartzWorkshop(stations)
 return stations
end
return Stands

end)()
local DroneAbilities = (function()
-- Authoritative, bounded mining gadgets. No rewards, ownership, input timestamps
-- or client-selected targets are trusted here. Context owns the normal hit path.
local A={}
A.KINDS={Orbital={cooldown=45,burnSeconds=4,chargeSeconds=2.4},Scrap={cooldown=35}}
A.CHARGE_SECONDS=1.4
A.ORBITAL_ORIGIN_HEIGHT=34
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function point(p)
 return {x=p.x or p.X or 0,y=p.y or p.Y or 0,z=p.z or p.Z or 0}
end
local function distance(a,b)
 local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z;return math.sqrt(x*x+y*y+z*z)
end
local function usable(r)
 return type(r)=='table' and type(r.id)=='string' and finite(r.hp) and r.hp>0 and finite(r.maxHP) and r.maxHP>0
  and finite(r.x) and finite(r.y) and finite(r.z)
end
local function targets(ctx,fieldId,kind)
 local list={}
 for _,r in ipairs(ctx.targets(fieldId,kind) or {}) do if usable(r) then table.insert(list,r) end end
 table.sort(list,function(a,b) if a.maxHP==b.maxHP then return a.id<b.id end;return a.maxHP>b.maxHP end)
 return list
end
local function event(ctx,kind,record)
 record=record or {};record.kind=kind;ctx.emit(record)
end
function A.new(savedCooldowns,runId)
 local cooldowns={}
 for kind in pairs(A.KINDS) do
  local saved=type(savedCooldowns)=='table' and savedCooldowns[kind]
  if finite(saved) and saved>=0 and saved<1e14 then cooldowns[kind]=saved end
 end
 return {sequence=0,cooldowns=cooldowns,runId=runId,charge=nil,swarm=nil,burn=nil}
end
function A.cancel(state,ctx)
 state.charge=nil;state.swarm=nil;state.burn=nil
 if ctx then event(ctx,'clear') end
end
function A.pause(state,dt)
 if not finite(dt) or dt<=0 then return end
 local charge=state.charge
 if charge then
  for _,key in ipairs({'started','readyAt','expires'}) do charge[key]+=dt end
 end
 if state.burn then state.burn.started+=dt;state.burn.nextPose=0 end
 if state.swarm then state.swarm.started+=dt;state.swarm.expires+=dt;state.swarm.nextPose=0 end
end
function A.begin(state,kind,now,ctx)
 if not finite(now) or not A.KINDS[kind] then return false,'Unknown mining gadget' end
 if state.runId~=ctx.runId then A.cancel(state,ctx);state.runId=ctx.runId;state.cooldowns={} end
 if not ctx.unlocked(kind) then return false,'Buy this gadget in its mineral shop first' end
 if state.charge then return false,'Finish the current gadget charge first' end
 if kind=='Orbital' and state.burn then return false,'Orbital laser is still melting its target' end
 if kind=='Scrap' and state.swarm then return false,'Scrap bots are already working' end
 if now<(state.cooldowns[kind] or 0) then return false,'Gadget cooling down' end
 if not ctx.valid(ctx.fieldId) then return false,'Use this beside an unlocked, unguarded plot' end
 local list=targets(ctx,ctx.fieldId,kind)
 if #list==0 then return false,'No grown crystals are ready' end
 local chosen=list[1]
 if kind=='Orbital' and ctx.selectedId then
  chosen=nil;for _,r in ipairs(list) do if r.id==ctx.selectedId then chosen=r;break end end
  if not chosen then return false,'That rock is out of reach' end
 elseif kind=='Orbital' and ctx.placement then
  local nearest=math.huge
  for _,r in ipairs(list) do
   local dx,dz=r.x-ctx.placement.x,r.z-ctx.placement.z;local squared=dx*dx+dz*dz
   if squared<nearest then nearest=squared;chosen=r end
  end
 end
 state.sequence+=1
 local duration=A.KINDS[kind].chargeSeconds or A.CHARGE_SECONDS
 local expires=now+duration+1.1
 state.charge={kind=kind,fieldId=ctx.fieldId,targetId=chosen.id,target=point(chosen),
  token=ctx.runId..':gadget:'..state.sequence,started=now,readyAt=now+duration,expires=expires}
 event(ctx,'charge',{ability=kind,target=chosen,expires=expires,duration=duration})
 return true,'Gadget charging'
end
function A.confirm(state,token,now,ctx)
 local charge=state.charge
 if state.runId~=ctx.runId or not charge or token~=charge.token or not finite(now) then return false,'Charge changed; try again' end
 if now>charge.expires then state.charge=nil;event(ctx,'clearCharge');return false,'Charge expired; no cooldown spent' end
 if now<charge.readyAt then return false,'Gadget charging' end
 if not ctx.unlocked(charge.kind) or not ctx.valid(charge.fieldId) then
  state.charge=nil;event(ctx,'clearCharge');return false,'Gadget canceled; return to the plot'
 end
 local list=targets(ctx,charge.fieldId,charge.kind);local target
 for _,r in ipairs(list) do if r.id==charge.targetId then target=r;break end end
 if not target then state.charge=nil;event(ctx,'clearCharge');return false,'That crystal was mined; no cooldown spent' end
 -- Effects follow equipment perks; player reaction timing never changes mining.
 local precise=charge.kind=='Orbital' and (ctx.perks or {}).orbitalRelay==true
 state.charge=nil
 local perks=ctx.perks or {}
 local cooldown=A.KINDS[charge.kind].cooldown
 if charge.kind=='Orbital' and perks.orbitalCycle then cooldown=30 end
 state.cooldowns[charge.kind]=now+cooldown
 if charge.kind=='Orbital' then
  local duration=A.KINDS.Orbital.burnSeconds
  state.burn={fieldId=charge.fieldId,targetId=target.id,actorId=charge.actorId,started=now,
   remaining=duration,dps=target.hp/duration,precise=precise,nextPose=0,accepted=false}
  event(ctx,'clearCharge')

 else
  local origin=point(ctx.origin);local bots={}
  for i=1,math.min(6,4+math.clamp(perks.scrapBots or 0,0,2)) do
   local angle=i*2.399963
   table.insert(bots,{id=i,x=origin.x+math.cos(angle)*1.1,y=origin.y+.5,z=origin.z+math.sin(angle)*1.1,
    targetId=nil,charge=0,pulse=0,active=false})
  end
  state.swarm={fieldId=charge.fieldId,actorId=charge.actorId,started=now,expires=now+10,bots=bots,nextPose=0}
  event(ctx,'scrapStart',{expires=now+10,count=#bots,precise=precise})
 end
 return true,'Gadget deployed'
end
function A.step(state,now,dt,ctx,swarmContext)
 if not finite(now) or not finite(dt) or dt<=0 then return end
 if state.runId~=ctx.runId then A.cancel(state,ctx);state.runId=ctx.runId;state.cooldowns={};return end
 local charge=state.charge
 if charge then
  if not ctx.valid(charge.fieldId) or not ctx.unlocked(charge.kind) then state.charge=nil;event(ctx,'clearCharge')
  elseif now>=charge.readyAt then A.confirm(state,charge.token,now,ctx) end
 end
 local burn=state.burn
 if burn then
  local target
  if ctx.valid(burn.fieldId) and ctx.unlocked('Orbital') then
   if ctx.target then
    target=ctx.target(burn.targetId,burn.fieldId)
    if not usable(target) or target.id~=burn.targetId then target=nil end
   else for _,r in ipairs(targets(ctx,burn.fieldId,'Orbital')) do if r.id==burn.targetId then target=r;break end end end
  end
  if not target or burn.remaining<=1e-7 then
   if not burn.accepted then state.cooldowns.Orbital=now end
   state.burn=nil;event(ctx,'orbitalEnd')
  else
   local slice=math.min(dt,.1,burn.remaining)
   local damage=burn.dps*slice
   -- A complete four-second burn must not strand a microscopic floating-point
   -- remainder. Never increase a real remaining hit budget or skip resistance.
   if target.hp>damage and target.hp-damage<=math.max(1,target.maxHP)*1e-10 then damage=target.hp end
   local accepted,broken=ctx.hit(target.id,damage,'Orbital',{x=target.x,y=target.y+A.ORBITAL_ORIGIN_HEIGHT,z=target.z})
   if not accepted then
    if not burn.accepted then state.cooldowns.Orbital=now end
    state.burn=nil;event(ctx,'orbitalEnd')
   else
    burn.accepted=true;burn.remaining-=slice
    if now>=burn.nextPose then
     burn.nextPose=now+.1
     event(ctx,'orbital',{target=target,remaining=burn.remaining,precise=burn.precise})
    end
    if broken or burn.remaining<=1e-7 then
     if burn.precise then
      for _,r in ipairs(targets(ctx,burn.fieldId,'OrbitalRelay')) do
       if r.id~=target.id and distance(target,r)<=14 then
        if ctx.hit(r.id,math.max(1,r.maxHP*.26),'OrbitalRelay',{x=r.x,y=r.y+9,z=r.z}) then event(ctx,'relay',{from=target,target=r});break end
       end
      end
     end
     state.burn=nil;event(ctx,'orbitalEnd')
    end
   end
  end
 end
 ctx=swarmContext or ctx
 local swarm=state.swarm
 if not swarm then return end
 if now>=swarm.expires or not ctx.valid(swarm.fieldId) or not ctx.unlocked('Scrap') then
  state.swarm=nil;event(ctx,'clearScrap');return
 end
 -- No catch-up burst after a stall. At most six normal hit callbacks per step.
 dt=math.min(dt,.1)
 local list=targets(ctx,swarm.fieldId,'Scrap');local byId={};for _,r in ipairs(list) do byId[r.id]=r end
 local taken={}
 for _,bot in ipairs(swarm.bots) do
  local target=byId[bot.targetId]
  if not target then
   local best=math.huge
   for _,r in ipairs(list) do if (taken[r.id] or 0)<2 then
    -- Small leftovers are useful prey; the orbital tool handles big rocks.
    local score=r.hp*.12+distance(bot,r)
    if score<best then best=score;target=r end
   end end
   if not target then target=list[#list] end
   bot.targetId=target and target.id or nil;bot.charge=0
  end
  bot.active=false;bot.target=nil
  if target then
   local slot=(taken[target.id] or 0)+1;taken[target.id]=slot
   local radius=finite(target.radius) and math.max(.1,target.radius) or .6
   local offset=math.min(.3,radius*.35)*(slot%2==0 and 1 or -1)
   local goal={x=target.x+offset,y=target.y+1.2+math.floor((slot-1)/2)*.45,z=target.z};local d=distance(bot,goal)
   local vx,vy,vz=bot.vx or 0,bot.vy or 0,bot.vz or 0
   local speed=math.min(12,d*5.5,math.sqrt(40*d));local scale=d>.001 and speed/d or 0
   local dx,dy,dz=(goal.x-bot.x)*scale-vx,(goal.y-bot.y)*scale-vy,(goal.z-bot.z)*scale-vz
   local change=math.sqrt(dx*dx+dy*dy+dz*dz);local thrust=change>.001 and math.min(1,20*dt/change) or 0
   local nx,ny,nz=vx+dx*thrust,vy+dy*thrust,vz+dz*thrust
   bot.x+=(vx+nx)*dt*.5;bot.y+=(vy+ny)*dt*.5;bot.z+=(vz+nz)*dt*.5
   bot.vx,bot.vy,bot.vz=nx,ny,nz
   if distance(bot,goal)<=math.min(.15,radius*.25) then
    bot.active=true;bot.target={x=goal.x,y=target.y,z=goal.z};bot.charge+=dt
    if bot.charge>=.25 then
     bot.charge-=.25
     -- A bounded chip of authored crystal work keeps tiny tools consequential
     -- in later fields. Paired bots cooperate rather than polishing many rocks
     -- for ten seconds without finishing one. Hardness still matters at the cap.
     local chip=math.max(2,math.min(8,target.maxHP/48))
     local accepted=ctx.hit(target.id,chip,'Scrap',point(bot))
     if accepted then
      bot.pulse+=1

     end
    end
   else bot.charge=0 end
  else bot.charge=0 end
 end
 if now>=swarm.nextPose then
  swarm.nextPose=now+.1;event(ctx,'scrapPose',{bots=swarm.bots,expires=swarm.expires})
 end
end
function A.view(state,_now)
 local view={runId=state.runId,cooldowns={Orbital=state.cooldowns.Orbital or 0,Scrap=state.cooldowns.Scrap or 0},swarmUntil=state.swarm and state.swarm.expires or 0,burnUntil=state.burn and (_now+state.burn.remaining) or 0}
 if state.charge then
  local c=state.charge;view.charge={kind=c.kind,started=c.started,readyAt=c.readyAt}
 end
 return view
end
return A

end)()
local DroneCatalog = (function()
-- Permanent miner identities. The server owns every chunk and repeat cycle.
-- Power is a finite base-work budget; Chunk is a final cap after all modifiers.
local Catalog = {
 Order = {'Laser','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'},
 Types = {
  Laser = {Name='Miner',Price=60,Duration=0,Color={90,230,255},Description='One more permanent mining drone. Works a second rock and stays after prestige. Each additional Miner costs more.'},
  Bubbler = {Name='Bubbler',Price=1800,Duration=2.8,Impact=.68,Power=1.1,Chunk=.25,Yield=1.25,Color={120,225,255},Description='Captures and pops a mineral chunk per bubble cycle. Up to 25% rock health per hit; 1.25× ore on completion.'},
  Halver = {Name='Halver',Price=900,Duration=3.6,Impact=.68,Power=1.25,Chunk=.25,Yield=1.5,Color={190,140,255},Description='Clamps, splits and grinds a chunk each cycle. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Gridcutter = {Name='Gridcutter',Price=1400,Duration=2.5,Impact=.68,Power=1.2,Chunk=.25,Yield=1.2,Color={255,100,130},Description='Cross-scans and shears a small cube lattice. Up to 25% rock health per hit; 1.2× ore on completion.'},
  Singularity = {Name='Singularity',Price=6500,Duration=2,Impact=.68,Power=1.5,Chunk=.25,Yield=1.5,Color={155,100,255},Description='Tears a chunk into a contained gravity well. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Starforge = {Name='Starforge',Price=2600,Duration=3,Impact=.68,Power=1.2,Chunk=.25,Yield=1.6,Color={255,170,60},Description='Heats and pours a molten mineral chunk. Up to 25% rock health per hit; 1.6× ore on completion.'},
  Frostbite = {Name='Frostbite',Price=650,Duration=2.4,Impact=.68,Power=1.05,Chunk=.25,Yield=1.1,Color={150,255,245},Description='Freezes and snaps a mineral chunk loose. Up to 25% rock health per hit; 1.1× ore on completion.'},
  Resonator = {Name='Resonator',Price=2100,Duration=2.6,Impact=.68,Power=1.15,Chunk=.25,Yield=1.3,Color={125,255,160},Description='Builds resonance, then releases one fracture pulse. Up to 25% rock health per hit; 1.3× ore on completion.'},
  Needler = {Name='Needler',Duration=.82,Impact=.36,Power=1.05,Chunk=.40,Projectile='Dart',Color={255,195,94},Description='Fires quick darts. Favors small and chipped crystals in deep fields.'},
  Ballcaster = {Name='Ballcaster',Duration=1.62,Impact=.35,Power=1.2,Chunk=.55,Projectile='Ball',ShellPower=1.5,Color={150,124,255},Description='Favors large deep crystals. Deals 50% more damage through their first two layers.'},
 },
}
Catalog.PrestigeRewards={
 {kind='Blue',name='Laser Miner',tier=1,weight=45,job='Steady crystal cutting'},
 {kind='Red',name='Breaker',tier=1,weight=25,job='Heavy hits on hard outer layers'},
 {kind='Bubbler',name='Bubbler',tier=2,weight=15,job='Bubble cuts with 25% more ore'},
 {kind='Gridcutter',name='Gridcutter',tier=2,weight=9,job='Quick passes with 20% more ore'},
 {kind='Halver',name='Halver',tier=3,weight=5,job='Heavy cuts with 50% more ore'},
 {kind='Singularity',name='Singularity',tier=4,weight=1,job='Fast gravity pulses with 50% more ore'},
}
function Catalog.prestigeReward(seed,index)
 local prime=2147483647
 local state=(seed*48271+index%prime*69621)%prime
 local ticket=(state*48271)%prime%100+1
 for _,reward in ipairs(Catalog.PrestigeRewards) do
  ticket-=reward.weight
  if ticket<=0 then return reward end
 end
 error('Prestige reward weights must total 100')
end
-- Three distinct weighted choices, stable for a run across reconnects.
function Catalog.prestigeChoices(seed,index)
 local prime=2147483647
 local state=(seed%prime*48271+index%prime*69621)%prime
 local pool=table.clone(Catalog.PrestigeRewards)
 local choices={}
 for _=1,3 do
  local total=0
  for _,entry in ipairs(pool) do total+=entry.weight end
  state=(math.max(1,state)*48271)%prime
  local ticket=state%total+1
  for i,entry in ipairs(pool) do
   ticket-=entry.weight
   if ticket<=0 then
    choices[#choices+1]={kind=entry.kind,name=entry.name,tier=entry.tier,job=entry.job}
    table.remove(pool,i);break
   end
  end
 end
 return choices
end
function Catalog.price(kind,fleet)
 local definition=Catalog.Types[kind];if not definition then return nil end
 if kind~='Laser' then return definition.Price end
 local miners=0
 for _,d in ipairs(fleet or {}) do if (d.role or d.type)=='Striker' or (not d.role and d.type=='Blue') then miners+=1 end end
 return math.floor(definition.Price*1.8^math.min(38,math.max(0,miners-1)))
end
local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end
function Catalog.cycle(kind,baseDPS,effectiveDPS)
 local definition=Catalog.Types[kind]
 if not definition or definition.Duration<=0 or not finite(baseDPS) or baseDPS<=0 or not finite(effectiveDPS) or effectiveDPS<=0 then return nil end
 -- Mining cards improve cycle rate once, rather than multiplying both damage
 -- and rate. A hard field still requires its full finite amount of work.
 local duration=definition.Duration/math.clamp(effectiveDPS/baseDPS,.25,4)
 return {duration=duration,impact=definition.Impact,damage=baseDPS*definition.Duration*definition.Power}
end
function Catalog.capDamage(kind,maxHP,damage)
 local definition=Catalog.Types[kind]
 if not definition or not definition.Chunk or not finite(maxHP) or not finite(damage) then return 0 end
 -- Ten HP is the original visual cutoff, not mineable work.
 return math.max(0,math.min(damage,math.max(0,maxHP-10)*definition.Chunk))
end
function Catalog.chunkTargetScore(kind,cycle,warmup,speed,node,distance)
 local damage=Catalog.capDamage(kind,node.maxHP,cycle.damage)
 if damage<=0 then return math.huge end
 local hits=math.max(1,math.ceil(node.hp/damage-1e-10))
 local travel=distance/math.max(1,speed*60)+math.log(1+distance)*.35
 return (travel+warmup+(hits-1+cycle.impact)*cycle.duration)/math.max(1,node.ore)
end
local SHELL_LAYERS=2
function Catalog.projectileTargetScore(kind,stats,node,distance)
 local travel=distance/math.max(1,stats.maxStep60*60)
 local rate=math.max(1,stats.miningDPS)
 local shellPower=Catalog.Types[kind].ShellPower
 if shellPower then
  -- Compare the time the heavier shot saves on the remaining shell with
  -- the time it takes to reach the deposit.
  local shellEnd=math.max(0,node.maxHP*(1-SHELL_LAYERS/(node.stageCount+1))-10)
  local shellWork=math.max(0,node.hp-shellEnd)
  return travel-shellWork/rate*(1-1/shellPower)
 end
 return travel+node.hp/rate
end
function Catalog.projectileShellPower(kind,stage)
 return stage<SHELL_LAYERS and Catalog.Types[kind].ShellPower or 1
end
return Catalog

end)()
local DroneRoles = (function()
-- Pure capabilities and work phases. Color/ownership never grants an implicit
-- mining beam: a drone must have the actual mechanical job that performs it.
local R={}
R.BREAKER={windup=.8,impactHold=1,recovery=.65,diveLimit=1.25,diveDuration=.28}
R.GROWER={plantSeconds=1.1,cooldown=5}
local legacy={Blue='Striker',Red='Charger',Green='Medic'}
local definitions={
 Striker={job='Miner',worker=true,miner=true,combat=true},
 Charger={job='Breaker',worker=true,combat=true},
 Dart={job='Rock grower',grower=true},
 Courier={job='Backpack emptier',courier=true},
 Medic={job='Healer',healer=true},
 Orbiter={job='Orbital controller',ability='Orbital'},
 Scrapper={job='Swarm fabricator',ability='Scrap'},
 Bubbler={job='Bubble extractor',worker=true,combat=true,special='Bubbler'},
 Halver={job='Ring grinder',worker=true,combat=true,special='Halver'},
 Gridcutter={job='Grid cutter',worker=true,combat=true,special='Gridcutter'},
 Singularity={job='Gravity extractor',worker=true,combat=true,special='Singularity'},
 Starforge={job='Solar refiner',worker=true,combat=true,special='Starforge'},
 Frostbite={job='Cryogenic shatterer',worker=true,combat=true,special='Frostbite'},
 Resonator={job='Resonance extractor',worker=true,combat=true,special='Resonator'},
 Needler={job='Dart thrower',worker=true,special='Needler'},
 Ballcaster={job='Energy ball thrower',worker=true,special='Ballcaster'},
 Vacuum={job='Collects loose ore'},
 Compactor={job='Compresses loose ore into equal-value blocks'},
}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function R.canonical(role) return legacy[role] or role end
local function capability(role,key)
 local definition=definitions[R.canonical(role)]
 return definition and definition[key]==true or false
end
function R.isWorker(role) return capability(role,'worker') end
function R.special(role)
 local definition=definitions[R.canonical(role)];return definition and definition.special or nil
end
function R.isSpecial(role) return R.special(role)~=nil end
function R.isMiner(role) return capability(role,'miner') end
function R.combat(role) return capability(role,'combat') end
function R.isGrower(role) return capability(role,'grower') end
function R.isCourier(role) return capability(role,'courier') end
function R.isHealer(role) return capability(role,'healer') end
function R.ability(role)
 local definition=definitions[R.canonical(role)];return definition and definition.ability or nil
end
function R.job(role)
 local definition=definitions[R.canonical(role)];return definition and definition.job or 'Unknown'
end
local function xyz(value)
 if type(value)~='table' then return nil end
 local p=value.position or value
 local x,y,z=p.x or p.X,p.y or p.Y,p.z or p.Z
 if finite(x) and finite(y) and finite(z) then return x,y,z end
 return nil
end
function R.chooseTarget(role,nodes,origin,now)
 role=R.canonical(role)
 if role~='Charger' then return nil end
 local x,y,z=xyz(origin);if not x or not finite(now) then return nil end
 local chosen,best=nil,-math.huge
 for _,node in ipairs(nodes or {}) do
  local nx,ny,nz=xyz(node)
  local ready=node.readyAt==nil or (finite(node.readyAt) and node.readyAt<=now)
  if nx and type(node.id)=='string' and finite(node.hp) and node.hp>0 and finite(node.maxHP) and node.maxHP>0
   and ready and node.paid~=true and node.eligible~=false then
   local distance=math.sqrt((nx-x)^2+(ny-y)^2+(nz-z)^2)
   local score
   do
    -- The impact specialist takes shells first, then substantial remaining work.
    local shell=node.kind=='Geode' and 120 or (node.kind=='Core' and 80 or 0)
    score=shell+math.min(node.hp,1000)*.08-distance*.7
   end
   if score and (score>best or (score==best and (not chosen or node.id<chosen.id))) then chosen=node;best=score end
  end
 end
 return chosen
end
local function breakerWindup(state)
 return finite(state.windup) and state.windup>0 and math.clamp(state.windup,.08,10) or R.BREAKER.windup
end
function R.newBreaker(targetId,now,windup)
 assert(type(targetId)=='string' and finite(now),'A breaker requires a server target and clock')
 return {targetId=targetId,phase='Approach',phaseAt=now,impactSerial=0,windup=windup}
end
function R.stepBreaker(state,now,context)
 if not finite(now) or now<state.phaseAt then return state.phase,nil end
 context=context or {}
 if state.phase=='Complete' or state.phase=='Canceled' then return state.phase,nil end
 if context.valid~=true or (context.targetId and context.targetId~=state.targetId) then
  state.phase='Canceled';state.phaseAt=now;return state.phase,'canceled'
 end
 local phase,event=state.phase,nil
 if phase=='Approach' and context.arrived==true then phase,event='Windup','windup'
 elseif phase=='Windup' and now-state.phaseAt>=breakerWindup(state) then phase,event='Dive','dive'
 elseif phase=='Dive' then
  if context.impactReached==true then
   phase,event='Impact','contact'
  elseif now-state.phaseAt>=R.BREAKER.diveLimit then phase,event='Recover','missed' end
 elseif phase=='Impact' and now-state.phaseAt>=R.BREAKER.impactHold then
  phase,event='Recover','impact';state.impactSerial+=1
 elseif phase=='Recover' and context.recovered~=false and now-state.phaseAt>=R.BREAKER.recovery then phase,event='Complete','complete' end
 if phase~=state.phase then state.phase=phase;state.phaseAt=now end
 return phase,event
end
function R.breakerPose(state,now)
 local t=finite(now) and math.max(0,now-state.phaseAt) or 0
 if state.phase=='Windup' then
  local p=math.clamp(t/breakerWindup(state),0,1);return {lift=(1-(1-p)^2)*1.2,dive=0,progress=p}
 elseif state.phase=='Dive' then
  local p=math.clamp(t/R.BREAKER.diveDuration,0,1);return {lift=1.2*(1-p),dive=p,progress=p}
 elseif state.phase=='Impact' then return {lift=0,dive=1,progress=1}
 elseif state.phase=='Recover' then
  local p=math.clamp(t/R.BREAKER.recovery,0,1);return {lift=0,dive=1-(1-(1-p)^2),progress=p}
 end
 return {lift=0,dive=0,progress=0}
end
return R

end)()
local Consumables = (function()
-- Earned field tools live in their own backpack pockets, never in ore cargo.
-- Pure rules shared by profile validation, server drops and the placement UI.
local C={STACK=3,MAX_DRY=8,ORDER={'Orbital','Scrap'}}
C.ITEMS={
 Orbital={name='Orbital Beacon',short='Orbital',radius=12,color={246,108,83},description='Place beside a tough rock. Melts the nearest ready rock in 4 seconds.'},
 Scrap={name='Scrap Capsule',short='Scrap bots',radius=16,color={161,131,244},description='Place among leftovers. Six tiny miners work this area for 10 seconds.'},
}
local function integer(n,max)
 return type(n)=='number' and n==n and n>=0 and n%1==0 and n<=(max or 1e12)
end
function C.fresh()
 return {counts={Orbital=0,Scrap=0},collected=0,misses=0,rocks=0,version=0}
end
function C.validate(s)
 if type(s)~='table' or type(s.counts)~='table' then return false,'Missing consumable backpack' end
 for _,kind in ipairs(C.ORDER) do if not integer(s.counts[kind],C.STACK) then return false,'Invalid consumable count' end end
 for kind in pairs(s.counts) do if not C.ITEMS[kind] then return false,'Unknown consumable' end end
 for _,key in ipairs({'collected','rocks','version'}) do if not integer(s[key]) then return false,'Invalid consumable progress' end end
 if not integer(s.misses,C.MAX_DRY) then return false,'Invalid discovery streak' end
 local pending=s.pending
 if pending~=nil then
  if type(pending)~='table' or not C.ITEMS[pending.kind] or s.counts[pending.kind]>=C.STACK
   or type(pending.txId)~='string' or #pending.txId<1 or #pending.txId>100
   or type(pending.runId)~='string' or #pending.runId<1 or #pending.runId>100 then return false,'Invalid reserved consumable' end
 end
 return true
end
function C.room(s,kind)
 return C.ITEMS[kind]~=nil and s.counts[kind]+(s.pending and s.pending.kind==kind and 1 or 0)<C.STACK
end
function C.onRock(s,tier,roll,choice)
 local available={}
 for _,kind in ipairs(C.ORDER) do if C.room(s,kind) then table.insert(available,kind) end end
 if #available==0 then return nil end
 s.rocks+=1;s.misses=math.min(C.MAX_DRY,s.misses+1)
 -- Teach both actions early. Afterwards randomness varies the opportunity,
 -- while the eighth eligible break guarantees useful equipment.
 if s.collected==0 then return s.misses>=3 and (C.room(s,'Orbital') and 'Orbital' or available[1]) or nil end
 if s.collected==1 then return s.misses>=5 and (C.room(s,'Scrap') and 'Scrap' or available[1]) or nil end
 local chance=.18+.03*math.clamp((tier or 1)-1,0,4)
 if s.misses<C.MAX_DRY and roll>=chance then return nil end
 return available[math.min(#available,1+math.floor(math.clamp(choice,0,.999999)*#available))]
end
function C.collect(s,kind)
 if not C.room(s,kind) then return false end
 s.counts[kind]+=1;s.collected+=1;s.misses=0;s.version+=1
 return true
end
function C.reserve(s,kind,version,txId,runId)
 if not C.ITEMS[kind] or s.counts[kind]<1 then return false,'That backpack pocket is empty' end
 if s.pending then return false,'A tool is already deploying' end
 if version~=s.version then return false,'Backpack changed; try again' end
 if type(txId)~='string' or #txId<1 or #txId>100 or type(runId)~='string' or #runId<1 or #runId>100 then return false,'Invalid deployment' end
 s.counts[kind]-=1;s.version+=1;s.pending={kind=kind,txId=txId,runId=runId}
 return true
end
function C.accept(s)
 if not s.pending then return false end
 s.pending=nil;s.version+=1;return true
end
function C.refund(s)
 local pending=s.pending;if not pending then return false end
 s.counts[pending.kind]+=1;s.pending=nil;s.version+=1;return true
end
return C

end)()
local ConsumableService = (function()
-- Bridges saved equipment transactions to the existing authoritative gadgets.
-- One deployment per owner, independent of permanent specialist cooldowns.
local S={};S.__index=S
function S.new(ctx) return setmetatable({ctx=ctx},S) end
function S:clear(p)
 local ctx=self.ctx;local active=p.supply
 if active then
  active.canceled=true
  if active.finishTemporary then active.finishTemporary(false);active.finishTemporary=nil end
  ctx.effects.ClearAbility(tostring(p.player.UserId)..':tool')
  if active.beacon then active.beacon:Destroy();active.beacon=nil end
 end
 if p.busy then return end
 if ctx.saveHealthy(p) and Consumables.refund(ctx.data(p).consumables) then p.dirty=true;p.publishDirty=true end
 p.supply=nil;p.player:SetAttribute('MA_ConsumableActive',nil)
end
function S:command(p,payload,verifiedPosition,verifiedTarget)
 local ctx=self.ctx;local profile=ctx.data(p)
 if type(payload)~='table' or payload.runId~=profile.run.id or not Consumables.ITEMS[payload.kind]
  or type(payload.txId)~='string' or #payload.txId<1 or #payload.txId>100 then return end
 if p.supply or profile.consumables.pending then ctx.notice(p,'Your deployed tool is still working');return end
 if payload.version~=profile.consumables.version or profile.consumables.counts[payload.kind]<1 then ctx.notice(p,'Backpack changed; select an available tool');return end
 local position,reason=verifiedPosition,nil
 if not position then position,reason=ctx.placement(p,payload) end
 if not position then ctx.notice(p,reason);return end
 local record={kind=payload.kind,fieldId=payload.fieldId,position=position,runId=profile.run.id,txId=payload.txId,targetId=verifiedTarget}
 record.state=ctx.abilities.new({},record.runId)
 -- Dry preflight has no effects, damage, inventory writes or cooldown cost.
 local context=ctx.context(p,record);context.emit=function() end
 local ok,message=ctx.abilities.begin(record.state,record.kind,ctx.now(),context)
 if not ok then ctx.notice(p,message);return end
 local started=ctx.transact(p,'tool:'..tostring(payload.version)..':'..payload.txId,function(copy)
  if copy.run.id~=record.runId then return nil,'Run changed' end
  local reserved,why=Consumables.reserve(copy.consumables,record.kind,payload.version,payload.txId,record.runId)
  if not reserved then return nil,why end
  return {kind=record.kind,txId=record.txId}
 end,function()
  -- Transactions still hold the simulation lock in this callback. Start next
  -- tick, after the acknowledged saved inventory becomes the live profile.
  record.state=ctx.abilities.new({},record.runId);p.supply=record
  p.player:SetAttribute('MA_ConsumableActive',record.kind)
 end)
 if not started then ctx.notice(p,'Wait for the current save to finish') end
 return started
end
function S:drop(p,kind,target,point,finish)
 local ctx=self.ctx
 if p.supply or ctx.data(p).consumables.pending then ctx.notice(p,'Your deployed tool is still working');return false end
 local record={kind=kind,fieldId=target.field.id,position=point,targetId=target.id,runId=ctx.data(p).run.id,temporary=true,finishTemporary=finish}
 record.state=ctx.abilities.new({},record.runId)
 local context=ctx.context(p,record);context.emit=function() end
 local ok,why=ctx.abilities.begin(record.state,kind,ctx.now(),context)
 if not ok then ctx.notice(p,why);return false end
 record.state=ctx.abilities.new({},record.runId);p.supply=record
 p.player:SetAttribute('MA_ConsumableActive',kind)
 return true
end
local function beacon(parent,record)
 local item=Consumables.ITEMS[record.kind]
 local part=Instance.new('Part');part.Name=item.name;part.Size=Vector3.new(1.3,.45,1.3)
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
 part.Material=Enum.Material.Metal;part.Color=Color3.fromRGB(table.unpack(item.color))
 part.Position=record.position+Vector3.new(0,.24,0)
 part:SetAttribute('ConsumableKind',record.kind);part:SetAttribute('RunId',record.runId)
 local mast=Instance.new('Part');mast.Name='Signal';mast.Size=Vector3.new(.18,1.3,.18);mast.Material=Enum.Material.Neon;mast.Color=part.Color
 mast.Anchored=true;mast.CanCollide=false;mast.CanQuery=false;mast.CanTouch=false;mast.CastShadow=false
 mast.Position=part.Position+Vector3.new(0,.7,0);mast.Parent=part
 part.Parent=parent;return part
end
function S:step(p,dt)
 local record=p.supply;if not record then return end
 local ctx=self.ctx
 if p.busy or not ctx.healthy(p) then ctx.abilities.pause(record.state,dt);return end
 if record.canceled or ctx.data(p).run.id~=record.runId then self:clear(p);return end
 local context=ctx.context(p,record)
 if not record.started then
  local ok,reason=ctx.abilities.begin(record.state,record.kind,ctx.now(),context)
  if not ok then self:clear(p);ctx.notice(p,record.temporary and reason or (reason..' — tool returned'));return end
  record.started=true;record.beacon=beacon(ctx.root,record)
  ctx.notice(p,Consumables.ITEMS[record.kind].name..' placed')
 end
 ctx.abilities.step(record.state,ctx.now(),dt,context)
 if not record.state.charge and not record.state.burn and not record.state.swarm then
  local unused=ctx.data(p).consumables.pending~=nil
  self:clear(p)
  if unused then ctx.notice(p,'No mining contact — tool returned to backpack') end
 end
end
return S

end)()
local ToolRules = (function()
-- Shared throw equations and temporary durability. Clients only preview them.
local T={SLOTS=8,WORLD_LIFETIME=75,MAX_DROPS=36,MAX_OWNER_DROPS=6,MAX_DRY=6}
T.ORDER={'BowlingBall','Crowbar','JellyGrenade','Greatsword','Scrap','Orbital','Sledgehammer','MoltenTongs'}
T.SAVED={[5]='Scrap',[6]='Orbital'}
T.ITEMS={
 BowlingBall={name='Bowling ball',short='Bowling',uses=4,gravity=420,speed=58,range=42,radius=1.05,color={95,109,222},cooldown=.82,windup=.44},
 Crowbar={name='Crowbar',short='Crowbar',uses=12,range=8,color={239,136,82},cooldown=.56,windup=.29,melee=true},
 JellyGrenade={name='Jelly grenade',short='Jelly',uses=1,gravity=280,speed=52,range=38,radius=.5,color={144,225,99},cooldown=.62,windup=.16,fuse=.42},
 Greatsword={name='Giant sword',short='Sword',uses=3,range=13,radius=.65,color={137,205,255},cooldown=.95,windup=.56,melee=true},
 Sledgehammer={name='Sledgehammer',short='Hammer',uses=3,range=10,radius=.65,color={255,192,84},cooldown=.9,windup=.50,melee=true},
 MoltenTongs={name='Molten steel tongs',short='Molten',uses=1,range=9,radius=.62,color={255,105,42},cooldown=.8,windup=.48,gravity=370,speed=50,molten=true},
 Scrap={name='Scrap capsule',short='Scrap',uses=1,range=45,radius=.6,color={190,149,255},cooldown=.58,windup=.26,gadget=true},
 Orbital={name='Orbital laser',short='Orbital',uses=1,range=45,radius=.6,color={255,125,81},cooldown=.58,windup=.26,gadget=true},
}
function T.finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function T.vector(v) return typeof(v)=='Vector3' and math.abs(v.X)<=100000 and math.abs(v.Y)<=100000 and math.abs(v.Z)<=100000 end
function T.origin(position,look) return position+Vector3.new(0,1.3,0)+look*1.6 end
function T.launch(kind,from,aim)
 local item=T.ITEMS[kind]
 if not item or not item.gravity or not T.vector(from) or not T.vector(aim) then return nil end
 local delta=aim-from;local flat=Vector3.new(delta.X,0,delta.Z)
 if flat.Magnitude>item.range then flat=flat.Unit*item.range end
 delta=flat+Vector3.new(0,math.clamp(delta.Y,-16,10),0)
 local duration=math.clamp(flat.Magnitude/item.speed,.22,.78)
 return delta/duration+Vector3.new(0,item.gravity*duration*.5,0),duration
end
function T.position(from,velocity,gravity,t) return from+velocity*t-Vector3.new(0,gravity*t*t*.5,0) end
function T.segmentDistance(point,from,to)
 local delta=to-from;local length=delta:Dot(delta)
 local q=length>1e-8 and math.clamp((point-from):Dot(delta)/length,0,1) or 0
 return (point-(from+delta*q)).Magnitude
end
-- Work in box-local units so a click at a corner or the visible edge
-- produces a real surface contact at any stage of a rock's life.
function T.surface(part,point,from)
 local half=part.Size*.5
 local v=part.CFrame:PointToObjectSpace(point)
 local q=Vector3.new(math.clamp(v.X,-half.X,half.X),math.clamp(v.Y,-half.Y,half.Y),math.clamp(v.Z,-half.Z,half.Z))
 if (q-v).Magnitude<1e-5 then
  local relative=q/half
  local direction=relative.Magnitude>.01 and relative or part.CFrame:PointToObjectSpace(from)/half
  local axis='X'
  if math.abs(direction.Y)>math.abs(direction[axis]) then axis='Y' end
  if math.abs(direction.Z)>math.abs(direction[axis]) then axis='Z' end
  local edge=half[axis]*(direction[axis]<0 and -1 or 1)
  q=Vector3.new(axis=='X' and edge or q.X,axis=='Y' and edge or q.Y,axis=='Z' and edge or q.Z)
 end
 return part.CFrame:PointToWorldSpace(q),q/part.Size
end
-- Keep old impacts for the life of the rock. Closely spaced hits on
-- the same face deepen the same mark, keeping CSG work bounded.
function T.addScar(history,point,width,depth,heat)
 local axis='Y'
 if not heat then
  if math.abs(point.X)>math.abs(point[axis]) then axis='X' end
  if math.abs(point.Z)>math.abs(point[axis]) then axis='Z' end
 end
 local face=(heat or point[axis]>=0) and .5 or -.5
 local x=axis=='X' and face or math.clamp(point.X,-.49,.49)
 local y=axis=='Y' and face or math.clamp(point.Y,-.49,.49)
 local z=axis=='Z' and face or math.clamp(point.Z,-.49,.49)
 local center=Vector3.new(x,y,z)
 local faceIndex=axis=='X' and 1 or axis=='Y' and 2 or 3
 for _,mark in ipairs(history) do
  if mark[6]==axis and mark[7]==heat and mark[faceIndex]==face
   and (Vector3.new(mark[1],mark[2],mark[3])-center).Magnitude<=.16 then
   local growth=heat and 0 or .025
   local wider=math.min(.96,math.max(width,mark[4]+growth))
   local deeper=math.min(.75,math.max(depth,mark[5]+growth))
   if wider==mark[4] and deeper==mark[5] then return false end
   mark[4],mark[5]=wider,deeper
   return true
  end
 end
 if #history>=8 then return false end
 table.insert(history,{x,y,z,width,depth,axis,heat})
 return true
end
function T.drop(progress,roll,choice)
 progress.breaks=(progress.breaks or 0)+1;progress.dry=math.min(T.MAX_DRY,(progress.dry or 0)+1)
 if (progress.found or 0)==0 then return progress.dry>=2 and 'BowlingBall' or nil end
 if progress.dry<T.MAX_DRY and roll>=.24 then return nil end
 -- Introduce each tool, then vary the tool rather than handing out multipliers.
 if progress.found<#T.ORDER then return T.ORDER[progress.found+1] end
 return T.ORDER[1+math.floor(math.clamp(choice,0,.99999)*#T.ORDER)]
end
return T

end)()
ToolRules.Hazards = (function()
-- Every hit is server-owned. Safe home, spawn shields and cover are respected.
local H={};H.__index=H
function H.new(ctx) return setmetatable({ctx=ctx},H) end
function H:hit(p,amount,from,key,interval,impulse)
 local ctx=self.ctx;local hr=ctx.root(p);if not hr then return end
 local humanoid=p.player.Character:FindFirstChildOfClass('Humanoid')
 if not humanoid or humanoid.Health<=0 or (hr.Position-ctx.home).Magnitude<23
  or p.player.Character:FindFirstChildOfClass('ForceField') then return end
 p.hazardAt=p.hazardAt or {};local now=ctx.now()
 if now<(p.hazardAt[key] or 0) then return end
 if not ctx.clear(from,hr.Position,p.player.Character) then return end
 p.hazardAt[key]=now+(interval or .25)
 -- Bounded categories keep a long server from accumulating per-projectile keys.
 humanoid:TakeDamage(math.clamp(amount,0,65))
 p.player:SetAttribute('MA_HurtAt',now)
 if impulse then
  local away=hr.Position-from;away=Vector3.new(away.X,0,away.Z)
  if away.Magnitude>.01 then away=away.Unit else away=Vector3.new(1,0,0) end
  hr:ApplyImpulse((away*impulse+Vector3.new(0,impulse*.45,0))*hr.AssemblyMass)
 end
end
function H:beam(from,to,amount,key)
 for _,p in pairs(self.ctx.players) do
  local hr=self.ctx.root(p)
  if hr and ToolRules.segmentDistance(hr.Position,from,to)<1.8 then self:hit(p,amount,from,key or 'laser',.24) end
 end
end
function H:blast(position,radius,amount,key)
 for _,p in pairs(self.ctx.players) do
  local hr=self.ctx.root(p);local distance=hr and (hr.Position-position).Magnitude or math.huge
  if distance<radius then self:hit(p,amount*(1-.65*distance/radius),position,key or 'explosion',.35,18*(1-distance/radius)) end
 end
end
return H

end)()
ToolRules.Service = (function()
-- Temporary equipment is runtime-only, separate from saved permanent drones.
-- Server inventories, swept projectiles, contact pickups and finite debris.
local S={};S.__index=S
function S.new(ctx)
 local root=Instance.new('Folder');root.Name='FieldTools';root.Parent=ctx.world
 local effects=Instance.new('Folder');effects.Name='ToolImpacts';effects.Parent=ctx.world
 return setmetatable({ctx=ctx,folder=root,effects=effects,items={},serial=0},S)
end
function S:state(p)
 local run=self.ctx.run(p)
 if not p.fieldTools or p.fieldTools.runId~=run then
  self:clear(p);p.fieldTools={runId=run,slots={},selected=0,version=0,found=0,dry=0}
 end
 return p.fieldTools
end
function S:slot(p,s,i)
 if s.slots[i] then return s.slots[i] end
 local kind=ToolRules.SAVED[i];local count=kind and self.ctx.stock(p,kind) or 0
 if count>0 then return {kind=kind,id='saved:'..kind,hp=count,state='Held',saved=true} end
end
function S:refreshStock(p)
 local stamp=self.ctx.stock(p,'Scrap')..':'..self.ctx.stock(p,'Orbital')
 if stamp==p.toolStock then return end
 if stamp=='0:0' and not p.fieldTools then p.toolStock=stamp;return end
 local s=self:state(p);p.toolStock=stamp
 if s.selected>0 and not self:slot(p,s,s.selected) then s.selected=0 end
 s.version+=1;self:publish(p)
end
function S:publish(p)
 local s=p.fieldTools;if not s then return end
 local view={slots={},selected=s.selected,version=s.version,runId=s.runId}
 for i=1,ToolRules.SLOTS do
  local item=self:slot(p,s,i)
  view.slots[i]=item and {id=item.id,kind=item.kind,hp=item.hp,maxHP=item.saved and 3 or ToolRules.ITEMS[item.kind].uses,state=s.attack and i==s.selected and 'Windup' or item.state} or false
 end
 p.player:SetAttribute('MA_FieldTools',self.ctx.encode(view))
 local selected=self:slot(p,s,s.selected)
 p.player:SetAttribute('HeldFieldTool',selected and selected.state=='Held' and selected.kind or nil)
 p.player:SetAttribute('HeldFieldToolHP',selected and math.min(ToolRules.ITEMS[selected.kind].uses,selected.hp) or 0)
end
function S:clear(p)
 for id,item in pairs(self.items) do
  if item.owner==p.player.UserId then if item.part then item.part:Destroy() end;self.items[id]=nil end
 end
 p.fieldTools=nil;p.toolStock=nil;p.player:SetAttribute('ToolActionAt',nil);p.player:SetAttribute('ToolActionKind',nil);p.player:SetAttribute('ToolAim',nil);p.player:SetAttribute('HeldFieldTool',nil);p.player:SetAttribute('HeldFieldToolHP',0);p.player:SetAttribute('MA_FieldTools',nil)
end
function S:previewLoadout(p)
 local s=self:state(p)
 for i,kind in ipairs(ToolRules.ORDER) do
  self.serial+=1
  local item={id=tostring(p.player.UserId)..':'..self.serial,owner=p.player.UserId,runId=s.runId,kind=kind,hp=ToolRules.ITEMS[kind].uses,state='Held'}
  s.slots[i]=item;self.items[item.id]=item
 end
 s.version+=1;self:publish(p)
end
function S:remove(item)
 if item.part then item.part:Destroy();item.part=nil end
 self.items[item.id]=nil
 local p=self.ctx.players[item.owner];local s=p and p.fieldTools
 if s then
  for i=1,ToolRules.SLOTS do if s.slots[i]==item then s.slots[i]=nil;if s.selected==i then s.selected=0 end end end
  s.version+=1;self:publish(p)
 end
end
function S:marker(position,kind,color,normal,slab,rock)
 local m=Instance.new('Part');m.Name=kind;m.Size=Vector3.one*.1;m.Transparency=1;m.Anchored=true
 m.CanCollide=false;m.CanQuery=false;m.CanTouch=false;m.Position=position
 m:SetAttribute('Kind',kind);m:SetAttribute('Color',color);m:SetAttribute('Normal',normal or Vector3.new(0,1,0))
 m:SetAttribute('Slab',slab)
 if rock then
  m:SetAttribute('RockFrame',rock.frame);m:SetAttribute('RockSize',rock.size)
  m:SetAttribute('RockMaterial',rock.material.Name);m:SetAttribute('RockVariant',rock.variant)
 end
 m:SetAttribute('StartedAt',self.ctx.now());m.Parent=self.effects;self.ctx.debris:AddItem(m,2.2)
end
function S:finishGadget(p,item,used)
 if self.items[item.id]~=item or item.state~='Deployed' then return end
 if used then self:remove(item);return end
 local s=p.fieldTools
 if s and s.runId==item.runId then
  item.state='Held';s.version+=1;self:publish(p)
  self.ctx.notice(p,'No mining contact · tool returned')
 end
end
function S:worldPart(item,position)
 local def=ToolRules.ITEMS[item.kind];local p=Instance.new('Part');p.Name=item.kind
 p.Shape=item.kind=='Crowbar' and Enum.PartType.Block or Enum.PartType.Ball
 p.Size=item.kind=='Crowbar' and Vector3.new(.25,2.4,.3) or Vector3.one*(def.radius*2)
 p.Material=item.kind=='JellyGrenade' and Enum.Material.SmoothPlastic or Enum.Material.Metal
 p.Color=Color3.fromRGB(table.unpack(def.color));p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=true
 p.Position=position;p:SetAttribute('Kind',item.kind);p:SetAttribute('Owner',item.owner);p:SetAttribute('ToolId',item.id)
 p:SetAttribute('HP',item.hp);p:SetAttribute('MaxHP',def.uses);p:SetAttribute('State',item.state)
 p:SetAttribute('ExpiresAt',item.expires)
 if item.state=='Flying' then p:SetAttribute('Origin',item.from);p:SetAttribute('Velocity',item.velocity);p:SetAttribute('StartedAt',item.started) end
 p.Parent=self.folder;item.part=p
 return p
end
function S:onRock(p,r)
 if not self.ctx.healthy(p) or not self.ctx.root(p) then return end
 local s=self:state(p);local total,owned=0,0
 for _,v in pairs(self.items) do if v.state~='Held' then total+=1;if v.owner==p.player.UserId then owned+=1 end end end
 if total>=ToolRules.MAX_DROPS or owned>=ToolRules.MAX_OWNER_DROPS then return end
 local kind=ToolRules.drop(s,self.ctx.random(),self.ctx.random());if not kind then return end
 self.serial+=1
 local ground=r.part:GetAttribute('GroundY') or r.position.Y
 local item={id=tostring(p.player.UserId)..':'..self.serial,owner=p.player.UserId,runId=s.runId,kind=kind,hp=ToolRules.ITEMS[kind].uses,
  state='Drop',expires=self.ctx.now()+ToolRules.WORLD_LIFETIME,collectAt=self.ctx.now()+.5}
 self.items[item.id]=item;s.found+=1;s.dry=0
 local radius=ToolRules.ITEMS[kind].radius or .65
 item.pos=Vector3.new(r.position.X,ground+r.part.Size.Y+.85,r.position.Z)
 item.settleVelocity=Vector3.new(math.cos(self.serial)*6,12,math.sin(self.serial)*6)
 item.settleUntil=self.ctx.now()+1.25;item.floor=ground+(kind=='Crowbar' and 1.35 or radius)
 self:worldPart(item,item.pos)
 self:marker(item.part.Position,'Drop',item.part.Color)
 self.ctx.notice(p,ToolRules.ITEMS[kind].name..' dropped — touch to collect')
end
function S:collect(p,item)
 local s=self:state(p);local hr=self.ctx.root(p)
 if not hr or not self.ctx.healthy(p) or item.owner~=p.player.UserId or item.runId~=s.runId
  or (item.state~='Drop' and item.state~='Recover') or self.ctx.now()<item.collectAt or not item.part
  or (hr.Position-item.part.Position).Magnitude>3.8 or not self.ctx.clear(hr.Position,item.part.Position,p.player.Character) then return false end
 local slot
 for i=1,ToolRules.SLOTS do if s.slots[i]==item then slot=i;break end end
 if not slot then for i=1,ToolRules.SLOTS do if not self:slot(p,s,i) then slot=i;break end end end
 if not slot then return false end
 item.state='Held';item.part:Destroy();item.part=nil;item.expires=nil;s.slots[slot]=item;s.version+=1
 self:publish(p);self.ctx.notice(p,ToolRules.ITEMS[item.kind].name..' · slot '..slot)
 return true
end
function S:target(p,hr,def,id,point)
 local ctx=self.ctx
 local origin=hr.Position+Vector3.yAxis*1.3
 local direct=type(id)=='string' and #id<=160 and ctx.resources[id]
 local function contact(r,hint)
  if r.paid or not r.part.Parent or not ctx.eligible(p,r,hr.Position) then return end
  local surface,offset=ToolRules.surface(r.part,hint,origin)
  if (surface-origin).Magnitude>def.range+.65 or not ctx.clear(origin,surface,p.player.Character,r.part) then return end
  return surface,offset
 end
 if direct then
  local surface,offset=contact(direct,point)
  if surface and (surface-point).Magnitude<=1.2 then return direct,offset end
 end
 local delta=point-origin
 if delta.Magnitude<.15 then return end
 local direction=delta.Unit
 local reach=math.min(def.range,delta.Magnitude)
 local best,bestOffset,bestScore
 for _,r in pairs(ctx.resources) do
  if r==direct or r.paid or not r.part.Parent then continue end
  local part=r.part
  local depth=(part.Position-origin):Dot(direction)
  if depth<=0 or depth>reach+part.Size.Magnitude*.5+2 then continue end
  local sample=origin+direction*math.min(depth,reach)
  local surface,offset=ToolRules.surface(part,sample,origin)
  local gap=(surface-sample).Magnitude
  -- Favor the rock along the click line. A wider cone for throws still
  -- tops out at a few studs and cannot reach behind the player or through cover.
  local allowance=math.clamp(depth*.13,1.8,4.2)
  if gap>allowance and (surface-point).Magnitude>allowance then continue end
  local score=math.min(gap,(surface-point).Magnitude)+depth*.025
  if not bestScore or score<bestScore or (score==bestScore and r.id<best.id) then
   if contact(r,sample) then best,bestOffset,bestScore=r,offset,score end
  end
 end
 return best,bestOffset
end
function S:freeAim(p,hr,def,point)
 local origin=hr.Position+Vector3.yAxis*1.3
 local delta=point-origin
 local aim=origin+(delta.Magnitude>def.range and delta.Unit*def.range or delta)
 local hit=self.ctx.cast(origin,aim,0,p.player.Character)
 return hit and hit.Position or aim,hit and hit.Normal
end
function S:command(p,action,payload)
 local s=self:state(p)
 if type(payload)~='table' or payload.runId~=s.runId or s.attack then return end
 if action=='EquipFieldTool' then
  if payload.version~=s.version then return end
  local slot=payload.slot
  if not ToolRules.finite(slot) or slot%1~=0 or slot<0 or slot>ToolRules.SLOTS then return end
  local item=self:slot(p,s,slot)
  if slot>0 and (not item or item.state~='Held') then return end
  s.selected=slot;s.version+=1;self:publish(p);return
 end
 local item=self:slot(p,s,s.selected);local hr=self.ctx.root(p);local now=self.ctx.now()
 -- The selected item ID and run identify the use even if another slot's
 -- inventory update is still in flight. Cooldown and windup serialize uses.
 if not item or item.state~='Held' or item.id~=payload.id or not hr or now<(s.nextUse or 0)
  or not ToolRules.vector(payload.point) then return end
 local def=ToolRules.ITEMS[item.kind]
 local target,offset=self:target(p,hr,def,payload.resourceId,payload.point)
 s.attack={item=item,target=target,offset=offset,point=payload.point,at=now+def.windup,run=s.runId}
 s.nextUse=now+def.cooldown;s.version+=1
 p.player:SetAttribute('ToolActionKind',item.kind)
 p.player:SetAttribute('ToolAim',target and target.part.CFrame:PointToWorldSpace(offset*target.part.Size) or payload.point)
 p.player:SetAttribute('ToolActionAt',s.attack.at)
 self:marker(hr.Position,item.kind..'Windup',Color3.fromRGB(table.unpack(def.color)))
 self:publish(p)
end
function S:release(p,s,attack)
 local ctx=self.ctx;local item=attack.item;local def=ToolRules.ITEMS[item.kind];local hr=ctx.root(p)
 s.attack=nil
 if not hr or not ctx.healthy(p) or s.runId~=attack.run then self:publish(p);return end
 local target,offset=attack.target,attack.offset
 local origin=hr.Position+Vector3.yAxis*1.3
 local aim=target and target.part.CFrame:PointToWorldSpace(offset*target.part.Size)
 if not aim or target.paid or not target.part.Parent or not ctx.eligible(p,target,hr.Position)
  or (aim-origin).Magnitude>def.range+.65 or not ctx.clear(origin,aim,p.player.Character,target.part) then
  target,offset=self:target(p,hr,def,nil,attack.point)
  aim=target and target.part.CFrame:PointToWorldSpace(offset*target.part.Size)
 end
 local normal
 if not aim then aim,normal=self:freeAim(p,hr,def,attack.point) end
 local color=Color3.fromRGB(table.unpack(def.color))
 if def.gadget then
  if target and ctx.gadget(p,item,target,aim) then
   if not item.saved then item.state='Deployed' end
  else self:marker(aim,item.kind..'Probe',color,normal) end
  s.version+=1;self:publish(p);return
 end
 if def.melee and not target then
  self:marker(origin,item.kind..'Whiff',color,aim-origin)
  self:publish(p);return
 end
 if def.melee then
  local part=target.part;local center=part.Position;local originalHeight=part.Size.Y
  local rock={frame=part.CFrame,size=part.Size,material=part.Material,variant=part.MaterialVariant}
  local cut=math.clamp(.5+offset.Y,.35,.65);local slab=item.kind=='Greatsword' and not target.slice and part.Size*Vector3.new(1,1-cut,1) or nil
  local fraction=item.kind=='Greatsword' and .5 or item.kind=='Sledgehammer' and .32 or .16
  local cap=item.kind=='Greatsword' and 720 or item.kind=='Sledgehammer' and 320 or 70
  if not ctx.hit(p,target,math.min((target.maxHP-10)*fraction,cap),origin,item.kind,aim) then
   self:marker(origin,item.kind..'Whiff',color,aim-origin);self:publish(p);return
  end
  item.hp-=1
  if item.kind=='Greatsword' and target.paid then slab=rock.size end
  self:marker(slab and (rock.frame:PointToWorldSpace(Vector3.new(0,(originalHeight-slab.Y)*.5,0))) or aim,
   item.kind,part.Color,nil,slab,rock)
  if item.kind=='Sledgehammer' then
   ctx.hazards:blast(center+Vector3.new(0,1,0),7,12,'heavy')
   local n=0
   for _,r in ipairs(target.field.resources) do
    if r~=target and not r.paid and (r.part.Position-center).Magnitude<8 and ctx.hit(p,r,math.min(55,(r.maxHP-10)*.12),hr.Position,'Crowbar') then n+=1;if n>=3 then break end end
   end
  end
  if item.hp<=0 then self:marker(hr.Position,'Shatter',Color3.fromRGB(table.unpack(def.color)));self:remove(item);return end
 else
  local delta=aim-hr.Position
  local flat=Vector3.new(delta.X,0,delta.Z);local look=flat.Magnitude>.05 and flat.Unit or hr.CFrame.LookVector
  local from=ToolRules.origin(hr.Position,look)
  if not ctx.clear(hr.Position,from,p.player.Character) then from=hr.Position+Vector3.new(0,1.3,0) end
  local velocity
  if def.molten then
   -- Drop vertically when there's headroom, otherwise lob from the hand.
   if target then aim=Vector3.new(aim.X,target.part.Position.Y+target.part.Size.Y*.5,aim.Z):Lerp(target.part.Position,.04) end
   local above=aim+Vector3.yAxis*4.6
   if ctx.clear(origin,above,p.player.Character) and ctx.clear(above,aim,p.player.Character,target and target.part) then
    from=above;velocity=Vector3.new(0,-3,0)
   else velocity=ToolRules.launch(item.kind,from,aim) end
  else
   if target then aim=aim:Lerp(target.part.Position,.035) end
   velocity=ToolRules.launch(item.kind,from,aim)
  end
  if not velocity then self:publish(p);return end
  item.hp-=1;item.state='Flying';item.from=from;item.pos=from;item.velocity=velocity;item.started=ctx.now();item.expires=item.started+8;item.sampleAge=0
  self:worldPart(item,from);self:marker(from,item.kind..'Release',Color3.fromRGB(table.unpack(def.color)))
 end
 s.version+=1;self:publish(p)
end
function S:impact(p,item,point,normal,resource)
 local def=ToolRules.ITEMS[item.kind];item.pos=point+normal*(def.radius or .1)
 item.part.Position=item.pos;item.part:SetAttribute('State','Impact')
 if item.kind=='MoltenTongs' then
  item.state='Molten';item.stuck=resource;item.fuseAt=self.ctx.now()+(resource and 1.75 or .65);item.nextMelt=self.ctx.now()
  item.part:SetAttribute('State','Molten');item.part:SetAttribute('FuseAt',item.fuseAt)
  self:marker(point,'MoltenTongs',item.part.Color,normal,nil,resource and {frame=resource.part.CFrame,size=resource.part.Size,material=resource.part.Material,variant=resource.part.MaterialVariant})
 elseif item.kind=='JellyGrenade' then
  self:marker(point,'JellyStick',item.part.Color,normal)
  item.state='Stuck';item.fuseAt=self.ctx.now()+def.fuse
  if resource then item.stuck=resource;item.offset=resource.part.CFrame:PointToObjectSpace(item.pos);item.baseSize=resource.part.Size end
  item.part:SetAttribute('State','Stuck');item.part:SetAttribute('FuseAt',item.fuseAt)
 else
  local rock=resource and {frame=resource.part.CFrame,size=resource.part.Size,material=resource.part.Material,variant=resource.part.MaterialVariant}
  if resource then self.ctx.hit(p,resource,math.min((resource.maxHP-10)*.42,210),item.pos,'BowlingBall',point) end
  self:marker(point,'BowlingBall',resource and resource.part.Color or item.part.Color,normal,nil,rock)
  self.ctx.hazards:blast(item.pos,5,18,'heavy')
  if item.hp<=0 then self:marker(item.pos,'Shatter',item.part.Color);self:remove(item);return end
  item.state='Recover';item.collectAt=self.ctx.now()+.65;item.expires=self.ctx.now()+ToolRules.WORLD_LIFETIME
  -- Settle beside the impact, then become a touch pickup. No remote recovery.
  local flat=Vector3.new(normal.X,0,normal.Z)
  if flat.Magnitude<.1 then flat=Vector3.new(1,0,0) else flat=flat.Unit end
  item.settleVelocity=flat*12+Vector3.new(0,13,0);item.settleUntil=self.ctx.now()+1.4
  item.part:SetAttribute('State','Recover');item.part:SetAttribute('ExpiresAt',item.expires)
 end
 local s=p.fieldTools;if s then s.version+=1;self:publish(p) end
end
function S:step(dt)
 local now=self.ctx.now()
 for _,p in pairs(self.ctx.players) do
  local s=p.fieldTools
  if s and (s.runId~=self.ctx.run(p) or not self.ctx.root(p)) then self:clear(p)
  elseif s and s.attack and now>=s.attack.at then self:release(p,s,s.attack) end
 end
 for _,item in pairs(self.items) do
  local p=self.ctx.players[item.owner]
  if not p or item.runId~=self.ctx.run(p) or (item.expires and now>=item.expires) then self:remove(item)
  elseif item.state=='Flying' then
   local def=ToolRules.ITEMS[item.kind];local age=now-item.started
   -- Substeps bound curved sweep error even after a slow server frame.
   local from=item.pos;local oldAge=item.sampleAge or 0;local steps=math.clamp(math.ceil((age-oldAge)*60),1,12)
   for i=1,steps do
    local at=oldAge+(age-oldAge)*i/steps;local to=ToolRules.position(item.from,item.velocity,def.gravity,at)
    local hit=self.ctx.cast(from,to,def.radius,p.player.Character)
    if hit then self:impact(p,item,hit.Position,hit.Normal,self.ctx.resources[hit.Instance:GetAttribute('ResourceId')]);break end
    from=to;item.pos=to;item.part.Position=to
   end
   item.sampleAge=age
  elseif item.state=='Molten' then
   local r=item.stuck
   if now>=item.fuseAt or (r and (r.paid or not r.part.Parent)) then self:remove(item)
   elseif r and now>=item.nextMelt then
    item.nextMelt=now+.22
    local top=r.part.Position.Y+r.part.Size.Y*.5
    item.pos=Vector3.new(item.pos.X,top+.4,item.pos.Z);item.part.Position=item.pos
    self.ctx.hit(p,r,math.min(38,(r.maxHP-10)*.115),item.pos+Vector3.new(0,.35,0),'Melt',item.pos)
   end
  elseif item.state=='Stuck' then
   local r=item.stuck
   if r and not r.paid and r.part.Parent then
    item.pos=r.part.CFrame:PointToWorldSpace(item.offset*(r.part.Size/item.baseSize));item.part.Position=item.pos
   end
   if now>=item.fuseAt then
    local origin=item.pos
    self:marker(origin,'JellyGrenade',item.part.Color,nil,nil,r and r.part.Parent and {frame=r.part.CFrame,size=r.part.Size,material=r.part.Material,variant=r.part.MaterialVariant})
    self.ctx.hazards:blast(origin,12,34,'explosion')
    for _,r2 in pairs(self.ctx.resources) do
     if not r2.paid and (r2.part.Position-origin).Magnitude<=12 then
      self.ctx.hit(p,r2,math.min((r2.maxHP-10)*.72,330),origin,'JellyGrenade')
     end
    end
    self:remove(item)
   end
  elseif item.state=='Drop' or item.state=='Recover' then
   if item.settleVelocity and now<item.settleUntil then
    local velocity=item.settleVelocity-Vector3.new(0,180*dt,0);local to=item.pos+velocity*dt
    local radius=ToolRules.ITEMS[item.kind].radius or .65
    local hit=self.ctx.cast(item.pos,to,radius,p.player.Character)
    if hit then
     item.pos=hit.Position+hit.Normal*(item.kind=='Crowbar' and 1.35 or radius)
     item.settleVelocity=nil
    elseif item.floor and to.Y<=item.floor then
     item.pos=Vector3.new(to.X,item.floor,to.Z);item.settleVelocity=nil
    else item.pos=to;item.settleVelocity=velocity end
    item.part.Position=item.pos
   end
   self:collect(p,item)
  end
 end
end
return S

end)()
local Config = (function()
-- All numbers are provisional playtest tuning. No permanent fleet ownership cap.
local fields={
 {Name='Landing Quartz',Key='Quartz',Hardness=1,Color={255,0,0},ReferenceCrystals=true,Count=16,Ore=10,Value=1,Respawn=8,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Offset={58.9,0,68.4},Size={30,2,30}},
 {Name='Ruby Grove',Key='Ruby',Hardness=1.8,Color={226,75,112},Count=16,Ore=12,Value=2,Respawn=14,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Original='rubyPatch',Offset={-62.7,11.5,108.3},Size={42,2,42}},
 {Name='Cobalt Ridge',Key='Cobalt',Hardness=3.2,Color={89,150,234},Count=6,Ore=15,Value=4,Respawn=25,Turrets=1,TurretHP=260,Damage=19,ShotCooldown=1.8,RecommendedFleet=1,Original='cobaltPatch',Offset={1.9,18.5,-98.8},Size={42,2,42}},
 {Name='Violet Basin',Key='Violet',Hardness=5.2,Color={166,115,217},Count=9,Ore=16,Value=7,Respawn=35,Turrets=2,TurretHP=390,Damage=24,ShotCooldown=1.8,RecommendedFleet=3,Offset={106.4,28.5,-77.9},Size={47.6,2,44.8}},
 {Name='Deep Emerald',Key='Emerald',Hardness=8,Color={70,184,139},Count=12,Ore=20,Value=10,Respawn=45,Turrets=2,TurretHP=650,Damage=34,ShotCooldown=1.7,RecommendedFleet=5,Offset={172.9,38.5,30.4},Size={47.6,2,47.6}},
 {Name='Impact Test · 10x HP',Key='ImpactTest',Material='Quartz',AlwaysUnlocked=true,TestField=true,Hardness=1,HealthMultiplier=10,Color={180,225,213},Count=10,Ore=10,Value=1,Respawn=8,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Offset={132,0,76},Size={56,1,64}},
}
return {
 Tick=1/60, Snapshot=.1, MaxCatchup=6, Fleet=1, Capacity=120,
 MiningDPS=30, DroneDPS=12, Hull=80, Warmup=.8, Range=18,
 Reprint=10, Assembly=2, Grow=2, BreakCutoff=10,
 CommandRadius=95, CommandGrace=3, TurretRange=42, Telegraph=.8,
 Fields=fields,Tiers=fields,
 -- Preview is permitted only in Studio; the production adapter never falls back after failure.
 DataStoreName='MiningAwayProfilesV2',ContentVersion=1,
}

end)()
local Feel = (function()
-- Original 2023 motion and crystal timing, with explicit elapsed-time correction.
-- Scalar helpers stay engine-independent so the original equations are testable.
local F = {FollowHeight=3.2,ReferenceFollowHeight=7,ReferenceCrystalPivot=3,WorkHeight=10,WorkClearance=5,SwarmSpacing=3.5,SwarmRadius=6,SwarmMaxOffset=2.2}
function F.alpha(a, dt)
 if type(dt)~='number' or dt~=dt or dt<=0 then return 0 end
 return 1-(1-a)^(60*dt)
end
function F.turnAlpha(dt) return F.alpha(.1,dt) end
function F.approachScalar(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position
 local distance=math.abs(delta)
 if distance<1e-5 then return goal end
 local step=math.min(distance*F.alpha(.03,dt),math.max(0,maxStep60)*60*dt,distance)
 return position+(delta<0 and -step or step)
end
function F.approach(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position;local distance=delta.Magnitude
 if distance<1e-5 then return goal end
 local step=math.min(distance*F.alpha(.03,dt),math.max(0,maxStep60)*60*dt,distance)
 return position+delta/distance*step
end
-- Shared by the server and every observer. No extra thrust or braking layer.
function F.referenceFlight(position,goal,maxStep60,dt,correction)
 if dt<=0 then return position,Vector3.zero end
 local nextPosition=F.approach(position,goal,maxStep60,dt)
 if correction then
  local step=nextPosition-position+correction*dt
  local cap=maxStep60*60*dt
  nextPosition=position+(step.Magnitude>cap and step.Unit*cap or step)
 end
 return nextPosition,(nextPosition-position)/dt
end
function F.approachWork(position,goal,maxStep60,dt)
 if dt<=0 then return position end
 local delta=goal-position;local distance=delta.Magnitude
 if distance>16 then return F.approach(position,goal,maxStep60,dt) end
 if distance<1e-5 then return goal end
 -- A short hop between nearby jobs should settle promptly. The server and
 -- every observer use this same bounded ease, never a cosmetic teleport.
 local step=math.min(distance*F.alpha(.065,dt),math.max(0,maxStep60)*1.45*60*dt,distance)
 return position+delta/distance*step
end
-- Original crystals snap to a new facing on each crack. Seed + stage give
-- the same pose to the server collider, current observers and late joiners.
function F.rockYaw(seed,stage,turn,reference)
 local yaw=reference and 0 or (seed*.01)%(2*math.pi)
 if turn then
  for i=1,stage do
   local roll=(seed*131+i*271)%83
   yaw+=math.rad(55+roll)*((seed+i)%2==0 and 1 or -1)
  end
 end
 return yaw
end
function F.groundedRockFrame(position,size,ground,stage,seed,turn,reference)
 local center=Vector3.new(position.X,ground+size.Y*.5-.06,position.Z)
 return CFrame.new(center)*CFrame.Angles(0,F.rockYaw(seed,stage,turn,reference),0),ground+size.Y-.06
end
function F.inertialApproach(position,goal,velocity,maxStep60,dt,work,correction,response)
 -- Retain the original capped, distance-eased destination rule, but approach
 -- its requested velocity with thrust. New jobs, reversals and speed upgrades
 -- cannot replace momentum in a single frame. Substeps keep braking consistent
 -- across server ticks and 30/60/144 Hz observers.
 velocity=velocity or Vector3.zero
 if type(dt)~='number' or dt~=dt or dt<=0 then return position,velocity end
 local elapsed=math.min(dt,.1);local steps=math.max(1,math.ceil(elapsed*120));local h=elapsed/steps
 local cruise=math.max(0,maxStep60 or 0)*60
 response=math.clamp(response or 1,1,8)
 local acceleration=math.max(10,cruise*1.6)*math.sqrt(response)
 for _=1,steps do
  local delta=goal-position;local distance=delta.Magnitude
  -- Blend the near-work response continuously. The old distance<=16 switch
  -- changed both speed and easing abruptly at an invisible boundary.
  local proximity=work and math.clamp((16-distance)/12,0,1) or 0
  local cap=cruise
  local ease=-60*math.log(1-.03)
  -- A damped arrival controller brakes lateral momentum as well as forward
  -- speed. Pure pursuit with a fixed acceleration repeatedly crossed the
  -- station and reversed direction during warmup.
  local omega=ease*(1+proximity*.35)*response
  local requestedAcceleration=delta*(omega*omega)-velocity*(2*omega)
  local requestedVelocity=velocity+requestedAcceleration*h
  local speed=math.min(cap,math.sqrt(2*acceleration*distance))
  local requested=requestedVelocity
  if requested.Magnitude>speed then requested=requested.Unit*speed end
  if correction then
   requested+=correction
   if requested.Magnitude>cap then requested=requested.Unit*cap end
  end
  local change=requested-velocity;local limit=acceleration*h
  local nextVelocity=change.Magnitude>limit and velocity+change.Unit*limit or requested
  position+=(velocity+nextVelocity)*(.5*h);velocity=nextVelocity
 end
 return position,velocity
end
local hexDirections={{0,-1},{-1,0},{-1,1},{0,1},{1,0},{1,-1}}
local function hexRing(slot)
 return math.ceil((math.sqrt(12*(slot-1)+9)-3)/6)
end
local function hexPoint(slot)
 if slot<=1 then return 0,0 end
 local ring=hexRing(slot);local index=slot-2-3*ring*(ring-1)
 local q,r=ring,0
 for side,direction in ipairs(hexDirections) do
  local steps=math.min(ring,math.max(0,index-(side-1)*ring))
  q+=direction[1]*steps;r+=direction[2]*steps
 end
 return q,r
end
function F.formationXZ(slot,count)
 count=math.max(1,math.floor(count or 1));slot=math.clamp(math.floor(slot or 1),1,count)
 -- Hexagonal cells keep uniform spacing as a permanent fleet grows. Full
 -- inner rings sum to zero; sum only the partial outer ring to center the crew.
 -- Both lookups cost at most six sides, regardless of the fleet population.
 local cq,cr=0,0
 if count>1 then
  local ring=hexRing(count);local remaining=count-1-3*ring*(ring-1)
  local q,r=ring,0
  for _,direction in ipairs(hexDirections) do
   local n=math.min(ring,remaining)
   cq+=n*q+direction[1]*n*(n-1)/2;cr+=n*r+direction[2]*n*(n-1)/2
   q+=direction[1]*ring;r+=direction[2]*ring;remaining-=n
  end
 end
 local q,r=hexPoint(slot);q-=cq/count;r-=cr/count
 return (q+r*.5)*F.SwarmSpacing,r*(math.sqrt(3)/2)*F.SwarmSpacing
end
function F.formation(slot,count)
 local x,z=F.formationXZ(slot,count)
 return Vector3.new(x,0,z)
end
function F.hover(time,maxStep60) return math.sin(time+maxStep60*200)/3 end
function F.followOffset(slot,count,time,maxStep60)
 local angle=2*math.pi*slot/math.max(1,count)
 return math.cos(angle)*10,F.ReferenceFollowHeight+F.hover(time,maxStep60),math.sin(angle)*10
end
function F.followGoal(ownerPosition,slot,count,time,maxStep60)
 local x,y,z=F.followOffset(slot,count,time,maxStep60)
 return ownerPosition+Vector3.new(x,y,z)
end
local function swarmHash(id)
 local value=0
 for i=1,#id do value=(value*131+string.byte(id,i))%2147483647 end
 return value
end
local function swarmCell(x,y,z) return x..':'..y..':'..z end
local function intentVelocity(record)
 if record.velocity then return record.velocity end
 local goal=record.goal
 if not goal then return Vector3.zero end
 local delta=goal-record.pos;local distance=delta.Magnitude
 if distance<.001 then return Vector3.zero end
 local step=record.maxStep60 or (record.stats and record.stats.maxStep60) or .35
 return delta/distance*math.min(distance*1.8,math.max(0,step)*60)
end
function F.swarmGrid(records)
 -- Snapshot once before moving any worker, so update order cannot make the
 -- first drone push the last one differently. Buckets hold immutable poses.
 local grid={buckets={},velocities={}};local cell=F.SwarmRadius
 for _,record in pairs(records) do
  if record.id and record.pos and (record.hp==nil or record.hp>0) then
   local pos=record.pos;local key=swarmCell(math.floor(pos.X/cell),math.floor(pos.Y/cell),math.floor(pos.Z/cell))
   local bucket=grid.buckets[key]
   if not bucket then bucket={};grid.buckets[key]=bucket end
   local id=tostring(record.id);local velocity=intentVelocity(record)
   table.insert(bucket,{id=id,pos=pos,velocity=velocity});grid.velocities[id]=velocity
  end
 end
 -- Stable sampling in crowded cells must not depend on table iteration order.
 for _,bucket in pairs(grid.buckets) do table.sort(bucket,function(a,b) return a.id<b.id end) end
 return grid
end
function F.swarmOffset(position,id,grid,weight)
 weight=math.clamp(weight or 1,0,1)
 if weight==0 or not grid then return Vector3.zero end
 id=tostring(id)
 local cell=F.SwarmRadius;local x,y,z=math.floor(position.X/cell),math.floor(position.Y/cell),math.floor(position.Z/cell)
 local neighbors={}
 local velocity=(grid.velocities and grid.velocities[id]) or Vector3.zero
 -- Read only 27 local bins, at most 12 samples per bin and 12 final contacts.
 -- Even a crowd stacked at exactly one pose cannot cause a fleet-wide scan for
 -- each worker. Samples spread through the stable bucket using the caller ID.
 for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
  local key=swarmCell(x+dx,y+dy,z+dz);local bucket=grid.buckets[key]
  if bucket then
   local n=#bucket;local samples=math.min(12,n);local start=swarmHash(id..key)%n
   for i=0,samples-1 do
    local other=bucket[(start+math.floor(i*n/samples))%n+1]
    if other.id~=id then
     local delta=position-other.pos;local square=delta:Dot(delta)
     if square<cell*cell then
      local relative=velocity-(other.velocity or Vector3.zero);local motion=relative:Dot(relative)
      local closest=motion>.001 and math.clamp(-delta:Dot(relative)/motion,0,.45) or 0
      local future=delta+relative*closest
      local candidate={id=other.id,delta=delta,square=square,futureSquare=future:Dot(future),closest=closest}
      if #neighbors<12 then table.insert(neighbors,candidate)
      else
       local worst=1
       for j=2,#neighbors do
        if neighbors[j].square>neighbors[worst].square or (neighbors[j].square==neighbors[worst].square and neighbors[j].id>neighbors[worst].id) then worst=j end
       end
       if square<neighbors[worst].square or (square==neighbors[worst].square and other.id<neighbors[worst].id) then neighbors[worst]=candidate end
      end
     end
    end
   end
  end
 end end end
 table.sort(neighbors,function(a,b) return a.id<b.id end)
 local force=Vector3.zero
 for _,other in ipairs(neighbors) do
  local first=id<other.id;local pair=swarmHash(first and (id..'/'..other.id) or (other.id..'/'..id))
  local side=first and 1 or -1;local delta=other.delta
  local flat=Vector3.new(delta.X,0,delta.Z);local distance=math.sqrt(other.square)
  local normal
  if flat.Magnitude>.001 then normal=flat/flat.Magnitude
  else
   -- Exact overlaps still produce equal and opposite, reproducible escape
   -- directions. No random rerolls or unstable zero-vector normalization.
   local angle=(pair%6283)/1000
   normal=Vector3.new(math.cos(angle)*side,0,math.sin(angle)*side)
  end
  -- Predict a crossing before the models overlap. Pair-stable tangents let
  -- head-on workers pass on opposite sides instead of stopping nose-to-nose.
  local currentPressure=(1-distance/cell)^2
  local futureDistance=math.sqrt(other.futureSquare or other.square)
  local anticipation=(other.closest or 0)>0 and (1-math.min(cell,futureDistance)/cell)^2*.8 or 0
  local pressure=math.max(currentPressure,anticipation)
  local tangent=Vector3.new(-normal.Z,0,normal.X)*(pair%2==0 and 1 or -1)
  local lane=side*((pair%3)-1)*.12
  force+=(normal*1.8+tangent*(anticipation>currentPressure and 1.4 or .48)+Vector3.new(0,lane,0))*pressure
 end
 force=Vector3.new(force.X,math.clamp(force.Y,-.24,.24),force.Z)
 if force.Magnitude>F.SwarmMaxOffset then force=force.Unit*F.SwarmMaxOffset end
 -- Add to the movement GOAL and pass through original capped easing. Settled
 -- mining passes zero weight so its exact overhead station/arrival gate wins.
 return force*weight
end
function F.smoothSwarm(previous,desired,dt)
 -- Smooth steering pressure, not a second smoothing of the drone's position.
 -- Isolated movement therefore retains the original .03 capped equation.
 if dt<=0 then return previous or Vector3.zero end
 return (previous or Vector3.zero):Lerp(desired,1-math.exp(-math.min(dt,.1)*10))
end
function F.stationOffset(slot,geode,height)
 height=height or (geode and 8 or F.WorkHeight)
 if not geode then return 0,height,0 end
 -- Geodes share three small slots over the shell footprint, never behind the rock.
 local angle=2*math.pi*((slot or 1)-1)/3
 return math.cos(angle)*.85,height,math.sin(angle)*.85
end
function F.mineGoal(resourcePosition,slot,geode,fullSize,reference)
 -- Large original geodes can be eight studs tall. Keep the smaller worker
 -- above the original volume, with a visible beam gap throughout mining.
 local height=fullSize and math.max(F.WorkHeight,fullSize.Y*.5+F.WorkClearance) or nil
 -- Mining Away sends Crystal.Primary.Position + 10. The visible Mesh is
 -- welded three studs above that primary, so its center-to-drone gap is seven.
 if reference then height=F.WorkHeight-F.ReferenceCrystalPivot end
 local x,y,z=F.stationOffset(slot,geode,height)
 return resourcePosition+Vector3.new(x,y,z)
end
function F.stage(hp,maxHP,count)
 count=math.clamp(math.floor(count or 3),1,7)
 if maxHP<=0 then return count end
 return math.clamp(math.floor((1-hp/maxHP)*(count+1)+1e-7),0,count)
end
function F.powerDive(start,impact,elapsed,duration)
 local delta=impact-start
 -- A powered weight gains speed all the way down. It has no arrival brake:
 -- contact stops the stroke, then the separate held phase carries its weight.
 -- Repeated/late samples stay exactly at contact with no residual velocity.
 if elapsed<=0 then return start,delta*0 end
 duration=math.max(.01,duration)
 if elapsed>=duration then return impact,delta*0 end
 local p=elapsed/duration
 return start:Lerp(impact,p^2.6),delta*(2.6*p^1.6/duration)
end
function F.stagesCrossed(previous,hp,maxHP)
 local result={}
 for stage=previous+1,F.stage(hp,maxHP) do table.insert(result,stage) end
 return result
end
function F.stageScale(stage,count) count=math.clamp(count or 3,1,7);return 1-math.clamp(stage,0,count)/(count+1) end
function F.crystalStageShape(stage,count)
 local loss=1-F.stageScale(stage,count)
 return Vector3.new(1-loss*.62,1-loss*.81,1-loss*.46)
end
function F.crystalShade(hp,maxHP,stage,count)
 local period=F.stageScale(stage,count)
 return math.clamp(hp/math.max(1,maxHP)/period-(1-period)/4,0,1)
end
function F.junkDarkness(hp,maxHP,stage,count)
 local progress=math.clamp((1-hp/math.max(1,maxHP))*(count+1)-stage,0,1)
 return .0832*progress^.8
end
function F.rockShape(slice,heat) return Vector3.new(1,(slice or 1)*(1-.0625*(heat or 0)),1) end
function F.growthProgress(now,spawnAt) return math.clamp((now-spawnAt)/2,0,1) end
function F.growth(now,spawnAt)
 -- TweenInfo.new(2) originally used Roblox's default Quad.Out easing.
 local t=F.growthProgress(now,spawnAt)
 return 1-(1-t)^2
end
function F.ready(now,spawnAt) return now>=spawnAt+2 end
function F.canMine(distance,ready,allowed,alive)
 return alive==true and ready==true and allowed==true and distance<=1
end
function F.flightYaw(position,goal,velocity,lastYaw)
 -- Use actual travel direction, retaining heading after arrival. A tiny
 -- steering residual must never spin a stationary miner through 180 degrees.
 if velocity and Vector3.new(velocity.X,0,velocity.Z).Magnitude>.35 then
  return F.levelYaw(position,position+velocity,lastYaw)
 end
 if Vector3.new(goal.X-position.X,0,goal.Z-position.Z).Magnitude>1 then return F.levelYaw(position,goal,lastYaw) end
 return lastYaw or 0
end
function F.referenceYaw(position,goal,maxStep60,ownerLook,lastYaw)
 if ownerLook and (goal-position).Magnitude*.03<maxStep60 then
  return F.levelYaw(Vector3.zero,ownerLook,lastYaw)
 end
 return F.levelYaw(position,goal,lastYaw)
end
function F.levelYaw(position,target,lastYaw)
 local dx,dz=target.X-position.X,target.Z-position.Z
 if dx*dx+dz*dz<1e-8 then return lastYaw or 0 end
 return math.atan2(-dx,-dz)
end
function F.approachYaw(yaw,target,dt)
 local delta=(target-yaw+math.pi)%(2*math.pi)-math.pi
 return yaw+delta*F.turnAlpha(dt)
end
-- Cosmetic-only quarter-stage sequencing. Server damage/rewards never wait for it.
function F.newStagePresentation(stage,broken,now,count)
 stage=math.clamp(math.floor(stage or 0),0,count or 3)
 return {stage=stage,knownStage=stage,broken=broken==true,knownBreak=broken==true,queue={},nextAt=now or 0}
end
function F.updateStagePresentation(p,authoritativeStage,broken,now,count)
 count=count or 3
 local target=broken and count or math.clamp(math.floor(authoritativeStage or 0),0,count)
 if p.knownBreak then return nil end
 if broken then
  p.stage=target;p.knownStage=target;p.knownBreak=true;p.broken=true;p.queue={}
  return 'break'
 end
 if target<=p.knownStage then return nil end
 p.stage=target;p.knownStage=target;p.scorched=false;p.queue={};p.nextAt=now
 return 'stage'
end
return F

end)()
local Mining = (function()
-- Pure mining rules shared by the authoritative server, UI and pacing model.
-- Drone types are permanent; these behaviors do not rewrite saved base traits.
local M={PULSE_INTERVAL=.8,RESONANCE_RANGE=10,HEALTH_MULTIPLIER=1,BOULDER_CHANCE=.2,BOULDER_WORK=3,BOULDER_SIZE=2.6,EXTRACTION_SHARE=.5}
M.SELECTOR_RANGE=44
M.SELECTOR_LEASH=100
local SELECTOR_GRID=2
local DEPOT_ROUTE_RADIUS=54 -- Half the authored Crystal Run bed width.
function M.selectorCenter(position,frame,size)
 local point=frame:PointToObjectSpace(Vector3.new(position.X,frame.Position.Y,position.Z))
 local halfX,halfZ=size.X*.5,size.Z*.5
 if math.abs(point.X)>halfX or math.abs(point.Z)>halfZ then return nil end
 local maxX,maxZ=math.floor(halfX/SELECTOR_GRID),math.floor(halfZ/SELECTOR_GRID)
 local x=math.clamp(math.round(point.X/SELECTOR_GRID),-maxX,maxX)*SELECTOR_GRID
 local z=math.clamp(math.round(point.Z/SELECTOR_GRID),-maxZ,maxZ)*SELECTOR_GRID
 return frame:PointToWorldSpace(Vector3.new(x,size.Y*.5,z))
end
function M.selectorInRange(position,point)
 local delta=point-position
 return math.abs(delta.Y)<16 and delta.X*delta.X+delta.Z*delta.Z<=M.SELECTOR_RANGE^2
end
function M.onSelectorDepotRoute(position,center,depot,depotFrame,depotSize)
 if depotFrame and depotSize then
  local point=depotFrame:PointToObjectSpace(position)
  if math.abs(point.X)<=depotSize.X*.5 and math.abs(point.Z)<=depotSize.Z*.5 and math.abs(point.Y)<16 then return true end
  depot=depotFrame.Position
 end
 local route=depot-center
 local lengthSquared=route.X*route.X+route.Z*route.Z
 if lengthSquared==0 then return false end
 local delta=position-center
 local along=math.clamp((delta.X*route.X+delta.Z*route.Z)/lengthSquared,0,1)
 local offset=delta-route*along
 return math.abs(offset.Y)<16 and offset.X*offset.X+offset.Z*offset.Z<=DEPOT_ROUTE_RADIUS^2
end
function M.onDepotApproach(position,center,depot,depotFrame,depotSize)
 local destination=depotFrame and depotSize and depotFrame.Position or depot
 return not M.selectorInRange(position,center)
  and (position-destination).Magnitude<(center-destination).Magnitude
  and M.onSelectorDepotRoute(position,center,depot,depotFrame,depotSize)
end
-- Horizontal separating axes for the square and the crystal's current body.
-- A crystal touching the boundary is eligible even if its center is outside.
function M.selectorTouches(center,half,frame,size)
 local x,z=center.X-frame.Position.X,center.Z-frame.Position.Z
 local right,back=frame.RightVector,-frame.LookVector
 local rx,rz=right.X,right.Z
 local bx,bz=back.X,back.Z
 local sx,sz=size.X*.5,size.Z*.5
 return math.abs(x)<=half+math.abs(rx)*sx+math.abs(bx)*sz
  and math.abs(z)<=half+math.abs(rz)*sx+math.abs(bz)*sz
  and math.abs(x*rx+z*rz)<=sx+half*(math.abs(rx)+math.abs(rz))
  and math.abs(x*bx+z*bz)<=sz+half*(math.abs(bx)+math.abs(bz))
end
local roleKinds={Dart='Blue',Striker='Blue',Medic='Green',Charger='Red',Orbiter='Blue',Scrapper='Blue'}
function M.kind(kind: string): string return roleKinds[kind] or kind end
local styles={Blue='Cutter',Red='Percussion',Green='Resonance'}
local descriptions={
 Blue='Cutter · steady single-crystal mining',
 Red='Percussion · charged hits; +50% shell/core damage',
 Green='Healer · repairs nearby drones for 10 health every 2 seconds',
}
function M.style(kind: string): string return styles[M.kind(kind)] or 'Cutter' end
function M.description(kind: string): string
 local roles={Dart='Cultivator · plants replacement rocks in depleted fields',Striker='Miner · cuts one crystal with a continuous laser',Medic='Healer · follows allies; 10 health every 2 seconds',Courier='Backpack emptier · carries 8 ore to storage, then returns',Charger='Breaker · winds up, dives, hits, then recovers',Orbiter='Orbital · charges, then melts the biggest rock over time',Scrapper='Swarm · launches tiny miners for 10 seconds'}
 return roles[kind] or descriptions[M.kind(kind)] or descriptions.Blue
end
function M.workRole(kind: string): string
 return ({Dart='Rock grower',Striker='Miner',Medic='Healer',Courier='Backpack emptier',Charger='Breaker',Orbiter='Orbital controller',Scrapper='Swarm fabricator',Blue='Miner',Red='Breaker',Green='Healer'})[kind] or 'Cutter'
end
function M.resource(roll: number,kind: string,hardness: number?)
 -- The original random size remains 2–4 studs. Hardness increases work, never
 -- the footprint, height or station of an otherwise identical mineral.
 local mass=roll*(kind=='Geode' and 3 or 1)
 local work=(mass-10)*(hardness or 1)*M.HEALTH_MULTIPLIER
 local size=mass/(kind=='Geode' and 37.5 or 25)*(kind=='Shard' and .8 or 1)
 return {maxHP=work+10,work=work,size=size,mass=mass}
end
function M.deepCrystal(roll: number,hardness: number,baseOre: number)
 -- Size shows the work up front. Small cuts pay sooner; big cuts return
 -- more Quartz in the same cargo slot.
 local sizeRoll=(roll-50)/50
 return {
  size=2.15+1.7*sizeRoll,
  work=65*hardness*(.5+sizeRoll)*M.HEALTH_MULTIPLIER,
  ore=math.max(1,math.floor(baseOre*(.65+.9*sizeRoll)+.5)),
 }
end
-- Cumulative base ore released by real layer fractures. The rest belongs to
-- the final collapse; crossing several layers at once never duplicates ore.
function M.extractedOre(ore: number,stage: number,count: number,bonus: number?): number
 return math.floor(ore*math.min(1,M.EXTRACTION_SHARE+(bonus or 0))*math.clamp(stage/math.max(1,count),0,1))
end
function M.looseSeamsReady(hp: number,maxHP: number,bonus: number?): boolean
 local work=math.max(1,maxHP-10)
 return bonus~=nil and bonus>0 and hp<=work*(bonus+1e-10)
end
function M.efficiency(kind: string,nodeKind: string): number
 return M.kind(kind)=='Red' and (nodeKind=='Geode' or nodeKind=='Core') and 1.5 or 1
end
-- Outer hard layers reward a physical breaker; exposed inner layers reward
-- steady cutters. This changes the best fleet/target pairing, without a timer
-- gate or invalidating the existing continuous hit and fracture rules.
function M.contactMultiplier(role,_nodeKind,hardness,stage,count)
 local progress=math.clamp((stage or 0)/math.max(1,count or 3),0,1)
 if role=='Charger' then
  local resistance=math.clamp(((hardness or 1)-1)/7,0,1)
  return 1+resistance*(1-progress)*1.5
 end
 if (role=='Striker' or role=='Blue') and (hardness or 1)>1 then return 1+progress*.35 end
 return 1
end
function M.step(kind: string,charge: number?,dt: number,dps: number): (number,number,number)
 if dt<=0 then return 0,charge or 0,0 end
 if M.kind(kind)~='Red' then return dps*dt,0,0 end
 local elapsed=(charge or 0)+dt
 local count=math.floor((elapsed+1e-9)/M.PULSE_INTERVAL)
 return count*M.PULSE_INTERVAL*dps,math.max(0,elapsed-count*M.PULSE_INTERVAL),count
end
function M.duration(kind: string,nodeKind: string,work: number,dps: number,geodeMultiplier: number?): number
 if work<=0 then return 0 end
 local rate=dps*M.efficiency(kind,nodeKind)
 if nodeKind=='Geode' or nodeKind=='Core' then rate=rate*(geodeMultiplier or 1) end
 local seconds=work/math.max(.001,rate)
 if M.kind(kind)=='Red' then seconds=math.ceil(seconds/M.PULSE_INTERVAL-1e-9)*M.PULSE_INTERVAL end
 return seconds
end
function M.resonanceDamage(maxHP: number,dps: number,crossed: number): number
 -- At most three quarters on one primary hit, one destination, no recursive
 -- echoes. Hard minerals cannot turn a fracture into unbounded burst damage.
 return math.min(maxHP*.25*.35,dps*.8)*math.clamp(crossed,0,3)
end
function M.targetScore(kind: string,stats: any,node: any,distance: number,neighbors: number?): number
 local role=kind
 kind=M.kind(kind)
 -- An estimate for autonomous selection, not an authority/reach test. Actual
 -- movement remains the original eased/capped flight and exact arrival gate.
 local travel=distance/math.max(1,stats.maxStep60*60)+math.log(1+distance)*.35
 local seconds=travel+stats.warmup+M.duration(kind,node.kind,node.hp,stats.miningDPS,stats.geodeMultiplier)
 local yield=math.max(1,node.ore)
 if node.kind=='Geode' then
  -- A shell itself pays nothing: include the growing core, a fresh warmup and
  -- its work before valuing the first 4× payout. No speculative shard windfall.
  seconds=seconds+2+stats.warmup+M.duration(kind,'Core',65*(node.hardness or 1),stats.miningDPS,stats.geodeMultiplier)
  yield=yield*4
  if kind=='Blue' then seconds=seconds*1.25 end
 elseif kind=='Green' then
  seconds=seconds/(1+math.min(neighbors or 0,3)*.10+math.min(node.stage or 0,3)*.08)
 end
 if role=='Dart' then seconds=seconds*(node.kind=='Shard' and .75 or 1)+distance*.035 end
 if role=='Medic' and node.kind=='Shard' then seconds=seconds*.7 end
 return seconds/yield
end
return M

end)()
local ResourcePlacement = (function()
-- Pure bounded random placement. A full-size bounding sphere reserves every
-- yaw/tilt of the authored mesh, including its later fracture/settling poses.
-- All coordinates supplied here are in the field's horizontal local space.
local P={MAX_ATTEMPTS=18,RETRY_SECONDS=2,EDGE_MARGIN=.75,GAP=.65}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function P.radius(x,y,z,kind,upright)
 if not finite(x) or not finite(y) or not finite(z) or x<=0 or y<=0 or z<=0 then return nil end
 -- The starter crystals stay upright as they turn and shrink, so their
 -- horizontal diagonal is sufficient. Other rocks keep the full reservation.
 local radius=math.sqrt(x*x+z*z+(upright and 0 or y*y))*.5
 -- A shell reveals four shard centers four studs away. Reserve those actual
 -- future footprints too, so a small shell cannot grow shards into neighbors.
 if kind=='Geode' then radius=math.max(radius,4+math.sqrt(3)*(70/25*.8)*.5) end
 return radius
end
function P.fits(x,z,width,depth,radius,occupied)
 if not finite(x) or not finite(z) or not finite(width) or not finite(depth) or not finite(radius) or radius<=0 then return false end
 local margin=radius+P.EDGE_MARGIN
 if math.abs(x)+margin>width*.5 or math.abs(z)+margin>depth*.5 then return false end
 for _,other in ipairs(occupied or {}) do
  if finite(other.x) and finite(other.z) and finite(other.radius) and other.radius>0 then
   local dx,dz=x-other.x,z-other.z;local gap=radius+other.radius+P.GAP
   if dx*dx+dz*dz<gap*gap then return false end
  end
 end
 return true
end
local function fitsReference(x,z,halfX,halfZ,radius,occupied,gap)
 if not finite(x) or not finite(z) or x%1~=0 or z%1~=0 or math.abs(x)>halfX or math.abs(z)>halfZ then return false end
 for _,other in ipairs(occupied or {}) do
  local dx,dz=x-other.x,z-other.z
  -- The starter patch keeps Mining Away's spacing. Larger deposits reserve
  -- room for both meshes to turn when they fracture.
  local separation=other.radius and radius+other.radius or gap
  if dx*dx+dz*dz<separation*separation then return false end
 end
 return true
end
function P.sample(width: number,depth: number,radius: number,occupied,random,clear,preferred,reference,referenceGap,
 bounds: {minX: number,maxX: number,minZ: number,maxZ: number}?)
 if not finite(width) or not finite(depth) or not finite(radius) or radius<=0 then return nil,0 end
 local halfX,halfZ=width*.5-radius-P.EDGE_MARGIN,depth*.5-radius-P.EDGE_MARGIN
 if reference then halfX,halfZ=math.floor(width*.5),math.floor(depth*.5) end
 if halfX<0 or halfZ<0 then return nil,0 end
 local minX,maxX,minZ,maxZ=-halfX,halfX,-halfZ,halfZ
 if bounds and not preferred then
  local lowX,highX=math.max(minX,bounds.minX),math.min(maxX,bounds.maxX)
  local lowZ,highZ=math.max(minZ,bounds.minZ),math.min(maxZ,bounds.maxZ)
  minX=if reference then math.ceil(lowX) else lowX
  maxX=if reference then math.floor(highX) else highX
  minZ=if reference then math.ceil(lowZ) else lowZ
  maxZ=if reference then math.floor(highZ) else highZ
  if minX>maxX or minZ>maxZ then return nil,0 end
 end
 local attempts=preferred and 1 or P.MAX_ATTEMPTS
 for attempt=1,attempts do
  -- A grower's committed plan is rechecked exactly where it planted.
  local x,z
  if preferred then x,z=preferred.x,preferred.z else x,z=random(minX,maxX),random(minZ,maxZ) end
  local fits
  if reference then fits=fitsReference(x,z,halfX,halfZ,radius,occupied,referenceGap or 2)
  else fits=P.fits(x,z,width,depth,radius,occupied) end
  if fits and (not clear or clear(x,z,radius)) then
   return {x=x,z=z,radius=radius},attempt
  end
 end
 return nil,attempts
end
return P

end)()
local JunkField = (function()
-- Shared timings and finishes for the themed junk clearings.
local J={BatchSize=4,Cap=10,LowWork=2,CrewCap=2,DropHeight=53,FallTime=.82,SettleTime=.32}
J.Props={
 {name='Pip Block',template='PipsCube',size=5.8,work=54,ore=10,color={232,220,194}},
 {name='Plaid Cube',template='BlueGinghamPaver',size=6.3,work=65,ore=12,color={184,209,235}},
 {name='Battered Crate',template='TimberCube',size=6.8,work=82,ore=15,color={164,103,76}},
 {name='Knit Block',template='KnitCube',size=5.5,work=59,ore=11,color={211,153,155}},
 {name='Daisy Cube',template='DaisiesCube',size=5.3,work=50,ore=9,color={224,196,154}},
 {name='Fired Brick',template='BrickLow',size=6.1,work=75,ore=14,color={179,95,77}},
}
J.TemplateProps={
 {name='Suggestion Box',template='SuggestionBox',work=67,ore=12},
 {name='Alphabet Block',template='AlphabetBlock',work=52,ore=10},
 {name='Moving Box',template='MovingBox',work=62,ore=11},
}
J.TechProps={
 {name='Glass Fuses',template='CartridgeFuses',work=61,ore=12},
 {name='Motherboard',template='Motherboard',work=75,ore=15},
 {name='Ribbon Cable',template='RibbonCable',work=57,ore=11},
 {name='Circuit Traces',template='CircuitTraces',work=66,ore=13},
 {name='Fuse Box',template='FuseBox',work=73,ore=14},
 {name='Heat Sink',template='HeatSink',work=81,ore=16},
}
function J.withTemplates(props,specs,folder)
 local result=table.clone(props)
 if folder then
  for _,spec in ipairs(specs) do
   local template=folder:FindFirstChild(spec.template)
   if template and template:IsA('Part') then
    local prop=table.clone(spec);prop.size=template.Size.X;table.insert(result,prop)
   end
  end
 end
 return result
end
function J.fallPose(age,grounded)
 if age<0 then return grounded+Vector3.yAxis*J.DropHeight end
 if age<J.FallTime then
  local t=age/J.FallTime
  return (grounded+Vector3.yAxis*(J.DropHeight*(1-t*t)))*CFrame.Angles(.62*(1-t),.95*(1-t),-.28*(1-t))
 end
 local t=math.clamp((age-J.FallTime)/J.SettleTime,0,1)
 return (grounded+Vector3.yAxis*(6.4*t*(1-t)))*CFrame.Angles(.13*math.sin(t*math.pi),0,0)
end
-- Give crews without a job the next object, then rotate within each job
-- count by least recent award. Failed/blocked requests cannot lose a turn.
function J.dispatch(crews,claim)
 while #crews>0 do
  table.sort(crews,function(a,b)
   if a.active~=b.active then return a.active<b.active end
   if a.turn~=b.turn then return a.turn<b.turn end
   return a.id<b.id
  end)
  local crew=crews[1]
  if crew.active>=J.CrewCap or not claim(crew) then table.remove(crews,1)
  else crew.active+=1 end
 end
end
return J

end)()
local OreDrops = (function()
-- Pure authoritative pickup trajectory. Uncollected world ore is owner/run bound;
-- only a server-confirmed arrival may put its conserved units in the backpack.
local O={MAGNET_RANGE=30,PICKUP_DISTANCE=2.2,SCATTER_TIME=.72,MAX_NODES=16,LIFETIME=90,FADE_SECONDS=5,CARGO_MAX_AGE=180,GRAVITY=70,
 AIR_DRAG=.9,GROUND_DRAG=18,RESTITUTION=.22}
function O.partition(units,limit)
 local out={};local count=math.min(4,units,limit or 4)
 if count<1 then return out end
 for i=1,count do out[i]=math.floor(units/count)+(i<=units%count and 1 or 0) end
 return out
end
function O.scatter(index,serial)
 local angle=index*2.399963+serial*.73
 local speed=7.5+(serial%5)*.5
 return math.cos(angle)*speed,15+index*.8,math.sin(angle)*speed
end
function O.launch(index,serial,sx,sy,sz)
 local vx,vy,vz=O.scatter(index,serial)
 local speed=math.sqrt(vx*vx+vz*vz)
 -- Outside the whole rotated footprint, above the top. The initial outward
 -- arc clears even a large carved boulder before homing is allowed to begin.
 local radius=math.sqrt(sx*sx+sz*sz)*.5+.4
 return vx/speed*radius,sy*.5+.35,vz/speed*radius,vx,vy,vz
end
-- A clear rise, apex and fall before the item can be collected.
function O.cargoLaunch(serial,block)
 local angle=block and .20 or serial*2.399963
 local speed=block and 5.3 or 6.0+(serial%3)*.35
 return math.cos(angle)*speed,block and 16 or 20+(serial%4)*.65,math.sin(angle)*speed
end
function O.deadline(spawnAt,returnUntil) return math.max(spawnAt+O.LIFETIME,returnUntil or 0) end
function O.expired(spawnAt,now,returnUntil) return now>=O.deadline(spawnAt,returnUntil) end
function O.fade(spawnAt,now,returnUntil)
 return math.clamp((now-O.deadline(spawnAt,returnUntil)+O.FADE_SECONDS)/O.FADE_SECONDS,0,1)
end
function O.sellTripDeadline(spawnAt,now,walkingDistance,returnUntil)
 -- Default walking is 16 studs/s. Leave time for turns, unloading and the counter.
 local trip=math.min(O.LIFETIME,walkingDistance/14+20)
 if now+trip<=O.deadline(spawnAt,returnUntil) then return nil end
 local extended=math.min(spawnAt+O.CARGO_MAX_AGE,now+trip+10)
 if extended>O.deadline(spawnAt,returnUntil) then return extended end
 return nil
end
local function horizontal(s,dt,drag)
 local decay=math.exp(-drag*dt);local travel=(1-decay)/drag
 s.x+=s.vx*travel;s.z+=s.vz*travel;s.vx*=decay;s.vz*=decay
 -- Ground friction leaves less than .003 studs of travel at this speed.
 if drag==O.GROUND_DRAG and s.vx*s.vx+s.vz*s.vz<.05^2 then s.vx=0;s.vz=0 end
end
local function fall(s,dt)
 -- Integrate the flight up to its actual contact time, then consume the rest
 -- of the step after restitution. Landing height/energy no longer depends on
 -- which server tick happened to cross the floor.
 local impact=0
 for _=1,3 do
  if dt<=1e-6 then break end
  local height=math.max(0,s.y-s.floor)
  if height<1e-5 and s.vy<=.8 then
   s.landed=true;s.firstLandedAge=s.firstLandedAge or s.age;s.y=s.floor;s.vy=0
   if s.vx~=0 or s.vz~=0 then horizontal(s,dt,O.GROUND_DRAG) end
   break
  end
  local contact=(s.vy+math.sqrt(s.vy*s.vy+2*O.GRAVITY*height))/O.GRAVITY
  local span=math.min(dt,contact)
  horizontal(s,span,O.AIR_DRAG)
  s.y+=s.vy*span-.5*O.GRAVITY*span*span;s.vy-=O.GRAVITY*span;dt-=span
  if contact>span then break end
  local speed=math.max(0,-s.vy)
  if speed>2 then impact=math.max(impact,speed) end
  s.landed=true;s.firstLandedAge=s.firstLandedAge or s.age;s.y=s.floor;s.vy=speed>2 and speed*(s.raw and .10 or O.RESTITUTION) or 0
  s.vx*=.62;s.vz*=.62
 end
 return impact
end
function O.step(s,target,dt,attract,magnetRange)
 if dt<=0 then return false end
 dt=math.min(dt,.05);s.age+=dt
 local dx,dy,dz=target.x-s.x,target.y-s.y,target.z-s.z
 local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
 local collectAt=s.raw and math.max(.40,(s.firstLandedAge or 0)+.075) or O.SCATTER_TIME
 local pulling=attract and s.landed==true and s.age>=collectAt and distance<=(magnetRange or O.MAGNET_RANGE)
 local oldX,oldY,oldZ=s.x,s.y,s.z
 local impactSpeed=0
 if pulling then
  -- Accelerate into a critically damped homing path, fast enough to catch a
  -- walking player. No orbiting an indefinitely moving pickup target.
  local speed=math.min(42,18+distance*1.6,math.sqrt(200*distance))
  local k=1-math.exp(-dt*12);local scale=speed/math.max(.001,distance)
  s.vx+=(dx*scale-s.vx)*k;s.vy+=(dy*scale-s.vy)*k;s.vz+=(dz*scale-s.vz)*k
  s.x+=s.vx*dt;s.y+=s.vy*dt;s.z+=s.vz*dt
  if s.y<s.floor then s.y=s.floor;s.vy=math.max(0,s.vy) end
 else
  impactSpeed=fall(s,dt)
 end
 s.homing=pulling
 -- Test the full segment as well as its end, so low-FPS homing cannot skip
 -- through the owner and enter a repeated overshoot loop.
 local ex,ey,ez=s.x-oldX,s.y-oldY,s.z-oldZ;local length=ex*ex+ey*ey+ez*ez
 local t=length>0 and math.clamp((dx*ex+dy*ey+dz*ez)/length,0,1) or 0
 local near=math.sqrt((dx-ex*t)^2+(dy-ey*t)^2+(dz-ez*t)^2)
 return pulling and near<=O.PICKUP_DISTANCE,impactSpeed
end
return O

end)()
local Rules = (function()
-- Server-owned guard participation and atomic resource damage.
-- Plot clears are permanent profile unlocks; no timed expeditions or closed rosters.
local R = {}

function R.finite(x)
 return type(x)=='number' and x==x and x>-math.huge and x<math.huge
end

function R.allowed(owner,caller,state)
 return owner==caller and state~='Destroyed' and state~='Reprinting'
end

function R.damage(resource,amount)
 if resource.paid or resource.hp<=0 or not R.finite(amount) or amount<=0 then return false end
 resource.hp=math.max(0,resource.hp-amount)
 if resource.hp==0 then resource.paid=true;return true end
 return false
end

local function clone(value)
 if type(value)~='table' then return value end
 local copy={}
 for k,v in pairs(value) do copy[k]=clone(v) end
 return copy
end

function R.newEncounter(settings)
 settings=settings or {}
 return {phase='Guarded',id=(settings.EncounterPrefix or 'plot')..':guards',roster={},users={}}
end
function R.begin(e)
 if e.phase=='Guarded' then e.phase='Active';return true end
 return false
end
function R.enroll(e,user,runId,drones)
 if e.phase~='Active' or type(runId)~='string' or type(drones)~='table' then return false end
 local selected={}
 for _,d in ipairs(drones) do
  if type(d.id)=='string' and d.owner==user and R.finite(d.hp) and d.hp>0
   and R.finite(d.life) and d.life>=1 and d.life%1==0
   and d.state~='Destroyed' and d.state~='Reprinting' then
   selected[d.id]={user=user,runId=runId,life=d.life,stats=clone(d.stats or {})}
  end
 end
 if next(selected)==nil then return false end
 e.users[user]={runId=runId,contributed=false}
 for id,record in pairs(selected) do e.roster[id]=record end
 return true
end
function R.participates(e,d,runId)
 if not d then return false end
 local r=e.roster[d.id];local u=r and e.users[r.user]
 return e.phase=='Active' and r~=nil and u~=nil and r.runId==runId and u.runId==runId
  and d.owner==r.user and r.life==d.life and R.finite(d.hp) and d.hp>0
  and d.state~='Destroyed' and d.state~='Reprinting'
end
function R.markContribution(e,user,runId)
 local u=e.users[user]
 if e.phase~='Active' or not u or u.runId~=runId then return false end
 u.contributed=true;return true
end
function R.spend(e,id)
 local present=e.roster[id]~=nil;e.roster[id]=nil;return present
end
function R.removeUser(e,user,runId)
 local u=e.users[user]
 if not u or u.runId~=runId then return false end
 e.users[user]=nil
 for id,r in pairs(e.roster) do if r.user==user then e.roster[id]=nil end end
 return true
end

function R.reprint(d,now,delay)
 d.hp=0;d.state='Destroyed';d.readyAt=now+delay;d.target=nil
end

function R.finishReprint(d,now,hull)
 if d.hp>0 or now<d.readyAt or not R.finite(hull) or hull<=0 then return false end
 d.life=d.life+1;d.hp=hull;d.state='Follow';d.target=nil
 return true
end

return R

end)()
local Profile = (function()
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

end)()
local Packs = (function()
-- Delivery and hold timing shared by authority and presentation.
local Packs = {
 Range = 8,
 DeliveryTime = 1.08,
 DropTime = .73,
 DepartTime = 1.65,
 Tiers = {'Common', 'Rare', 'Epic', 'Legendary'},
 Palette = {{195,213,225},{89,208,255},{201,134,255},{255,205,78}},
}
local ends = {.42, 1.32, 2.65, 4.8}
local work = {.60, .22, .12, .06}

function Packs.roll(ticket)
 if ticket <= 66 then return 1 end
 if ticket <= 90 then return 2 end
 if ticket <= 98 then return 3 end
 return 4
end

function Packs.duration(tier)
 return ends[tier]
end

function Packs.stageDuration(stage)
 return ends[stage]-(ends[stage-1] or 0)
end

function Packs.sample(tier, elapsed)
 local start, filled, total = 0, 0, 0
 for i = 1, tier do total += work[i] end
 for i = 1, tier do
  local finish = ends[i]
  if elapsed < finish or i == tier then
   local fraction = math.clamp((elapsed-start)/(finish-start), 0, 1)
   return (filled+work[i]*fraction)/total, i
  end
  start, filled = finish, filled+work[i]
 end
 return 1, tier
end

return Packs

end)()
local Cards = (function()
-- Data-driven run modifiers. Complete resolved choices are saved before disclosure.
local C={CONTENT_VERSION=18,BASE_CAPACITY=10,LASER_CHARGE_SCALE=4}
-- Relative priority weights for the seeded candidate ordering; these are not final probabilities.
C.RARITY_WEIGHTS={Common=6,Uncommon=3,Rare=1}
local rare={G01=true,G02=true,F09=true,F10=true,F11=true,D13=true,D14=true,D15=true,D16=true,D17=true,D18=true,D19=true,D20=true,A02=true}
local uncommon={C01=true,C02=true,C03=true,C04=true,C05=true,C06=true,D09=true,D10=true,D11=true,D12=true,T01=true,T02=true,T03=true,T04=true}
local function clone(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=clone(x) end;return o end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function finite(x) return type(x)=='number' and x==x and x>-math.huge and x<math.huge end
local function card(id,title,scope,effects,description,kind)
 local rarity=rare[id] and 'Rare' or (uncommon[id] and 'Uncommon' or 'Common')
 return {cardId=id,title=title,scope=scope,effects=effects,description=description,type=kind,rarity=rarity,expires='This run'}
end
C.CATALOG={
 card('A01','Rock Scanner','Fleet',{plotAuto=1},'Pick the first rock. Drones choose the next one nearby.'),
 card('G01','Orbital Laser','Player',{orbitalLaser=1},'Unlock timed orbital burns that melt the biggest ready rock over four seconds'),
 card('G02','Scrap-bot Swarm','Player',{scrapSwarm=1},'Unlock a ten-second swarm of tiny mining bots'),
 card('A02','Fast Couriers','Player',{fullAuto=1},'+100% courier delivery speed; couriers carry small batches from your backpack'),
 card('F01','Sharper Beams','Fleet',{mining=.25},'+25% mining output across your fleet'),
 card('F02','Fast Rotors','Fleet',{speed=.30},'+30% flight speed across your fleet'),
 card('F03','Combat Calibration','Fleet',{combat=.30},'+30% combat shot damage across your fleet'),
 card('F04','Reinforced Frames','Fleet',{health=.35},'+35% maximum hull; restore only the added hull'),
 card('F05','Ceramic Plating','Fleet',{reduction=.15},'Block 15 percentage points of incoming turret damage'),
 card('F06','Bigger Backpack','Player',{capacity=.35},'+35% player backpack space'),
 card('F07','Warm Emitters','Fleet',{startup=.50},'+50% startup rate: one-third less laser warmup alone'),
 card('F08','Clean Extraction','Fleet',{yield=.20},'+20% ore from every broken crystal; fills your backpack faster'),
 card('C01','Blue Afterburners','Color',{speed=1},'+100% Blue flight speed: 2× alone','Blue'),
 card('C02','Blue Lenses','Color',{mining=.50},'+50% mining output for every Blue drone','Blue'),
 card('C03','Red Targeting','Color',{combat=.65},'+65% combat shot damage for every Red drone','Red'),
 card('C04','Red Bulkheads','Color',{health=.60},'+60% Red maximum hull; restore only the added hull','Red'),
 card('C05','Green Recovery','Color',{yield=.40},'+40% ore units awarded by Green drones','Green'),
 card('C06','Green Ignition','Color',{startup=1},'Double Green startup rate: half laser warmup alone','Green'),
 card('D01','Diamond Tip','Individual',{mining=.90},'+90% mining output for this named drone'),
 card('D02','Battle Emitter','Individual',{combat=1},'Double this named drone’s combat shot damage alone'),
 card('D03','Titanium Hull','Individual',{health=1},'Double maximum hull alone; restore only the added hull'),
 card('D04','Racing Rotors','Individual',{speed=1},'Double this named drone’s flight speed alone'),
 card('D05','Instant Ignition','Individual',{startup=1},'+100% startup rate: half warmup alone; damage unchanged'),
 card('D06','Long Lens','Individual',{range=.40},'+40% combat working range; command radius unchanged'),
 card('D07','Turret Insulation','Individual',{reduction=.25},'25 percentage points less turret damage'),
 card('D08','Critical Optics','Individual',{crit=.15},'15% server-rolled chance of a double combat hit'),
 card('D09','Burst Splash','Individual',{combat=.20,splash=.15,chain=16},'+20% shot damage; arc 15% hit damage to one other sentry within 22 studs'),
 card('D10','Fracture Fork','Individual',{fork=.20},'Mining tick forks 20% to one eligible nearby crystal'),
 card('D11','Entry Shield','Individual',{shield=.20},'Absorb 20% built-in hull once per life on each guarded plot'),
 card('D12','Rapid Cycling','Individual',{rate=.35},'+35% combat firing rate; final DPS remains capped'),
 card('D13','Execution Lens','Individual',{finisher=.75},'+75% shot damage against sentries below 35% hull'),
 card('D14','Core Drill','Individual',{geode=.80,speed=-.15},'+80% mining damage to geode shells and cores; −15% flight speed'),
 card('D15','Salvage Reactor','Individual',{salvage=.30},'Destroy a sentry to repair 30% built-in hull on this drone'),
 card('D16','Arc Relay','Individual',{splash=.25,chain=16},'Arc 25% shot damage to one other sentry within 22 studs'),
 card('F09','Prism Splitter','Fleet',{fork=.20,forkRange=6},'Split 20% mining damage into one other crystal within 12 studs'),
 card('F10','Bulwark Network','Fleet',{health=.25,reduction=.10},'+25% hull and block 10 percentage points of turret damage'),
 card('F11','Courier Network','Fleet',{yield=.15,speed=.20,capacity=.20},'+15% ore, +20% drone speed and +20% player backpack space'),
 card('D17','Siege Focus','Individual',{combat=.45,finisher=.50,speed=-.15},'+45% shot damage; +50% finishing damage below 35% sentry hull; −15% flight speed'),
 card('D18','Pulse Cannon','Individual',{rate=.50,combat=.15,mining=-.20},'+50% fire rate and +15% shot damage; −20% mining output'),
 card('D19','Prospector Rig','Individual',{geode=.60,yield=.20,speed=-.15},'+60% geode damage and +20% ore; −15% flight speed'),
 card('D20','Shard Harvester','Individual',{fork=.20,forkRange=6,mining=.25,health=-.15},'Split 20% mining damage within 12 studs; +25% mining output; −15% hull'),
 card('T01','Glass Cutter','Tradeoff',{mining=.60,health=-.20},'+60% fleet mining output; −20% maximum hull'),
 card('T02','Battle Formation','Tradeoff',{combat=.60,mining=-.20},'+60% fleet combat shot damage; −20% mining output'),
 card('T03','Heavy Cargo','Tradeoff',{capacity=.60,speed=-.15},'+60% player backpack space; −15% drone speed'),
 card('T04','Hot Emitters','Tradeoff',{startup=1,health=-.20},'Double fleet startup rate alone; −20% maximum hull'),
}
C.FALLBACK={
 card('R01','Mining Reserve','Fleet',{mining=.10},'+10% mining output; repeatable until cap'),
 card('R02','Combat Reserve','Fleet',{combat=.10},'+10% combat shot damage; repeatable until cap'),
 card('R03','Cargo Reserve','Player',{capacity=.10},'+10% player backpack space; repeatable until cap'),
}
local function affects(c,d)
 return c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Color' and c.type==d.type) or (c.scope=='Individual' and c.targetDroneId==d.id)
end
local function support(d)
 return not DroneRoles.isWorker(d.role or d.type)
end
local function courier(d) return (d.role or d.type)=='Courier' end
local workEffects={mining=true,startup=true,yield=true,fork=true,geode=true,forkRange=true,plotAuto=true,aftershock=true,reclaim=true,earlyDrop=true,liveWire=true}
local combatOnly={combat=true,rate=true,crit=true,splash=true,chain=true,range=true,finisher=true,salvage=true}
local function sums(p,d,extra)
 local s={}
 local function add(c)
  local applies=affects(c,d)
  if not applies and c==extra and c.targetDroneId==nil and Workshop.isHardware(c) and Workshop.fits(d) then
   -- Score the option against each chassis it could improve. Installed
   -- effects still apply to only the one saved permanent ID.
   applies=Workshop.find(p,c.cardId,d.id)==nil
  end
  if applies then
   for k,n in pairs(c.effects) do
    if not (support(d) and (workEffects[k] or combatOnly[k])) then s[k]=(s[k] or 0)+n end
   end
  end
  -- Transport upgrades are the one Player modifier that changes a drone.
  if c.scope=='Player' and courier(d) then s.fullAuto=(s.fullAuto or 0)+(c.effects.fullAuto or 0) end
 end
 add({scope='Fleet',effects=Shops.effects(p,DroneRoles.canonical(d.role or d.type))})
 for _,c in ipairs(p.run.cards) do add(c) end
 if extra then add(extra) end
 return s
end
function C.capacity(p,extra)
 local n=Shops.effects(p).capacity or 0
 for _,c in ipairs(p.run.cards) do n=n+(c.effects.capacity or 0) end
 if extra then n=n+(extra.effects.capacity or 0) end
 return math.floor(C.BASE_CAPACITY*clamp(1+n,.25,3)+.000001)+2*Workshop.starLevel(p,'backpack')
end
function C.droneCapacity(p,_owned,extra) return C.capacity(p,extra) end
function C.magnetBonus(p,extra)
 local bonus=extra and (extra.effects.magnetRange or 0) or 0
 for _,card in ipairs(p.run.cards) do bonus+=card.effects.magnetRange or 0 end
 return bonus
end
function C.stats(p,d,extra)
 local b=d.base;local s=sums(p,d,extra)
 local forkCap=extra and extra.workshop and (extra.effects.fork or 0)>0 and .4 or .2
 for _,c in ipairs(p.run.cards) do if c.workshop and (c.effects.fork or 0)>0 then forkCap=.4;break end end
 local cutter=DroneRoles.isMiner(d.role or d.type)
 local doubleBeam=cutter and (s.doubleBeam or 0)>0 and 1 or 0
 local twinThrusters=cutter and (s.twinThrusters or 0)>0 and 1 or 0
 local oreDuplicator=cutter and (s.oreDuplicator or 0)>0 and 1 or 0
 local speed=clamp(1+(s.speed or 0),.1,3)*(1+twinThrusters)
 local interval=math.max(.15,b.shotInterval/math.max(.1,1+(s.rate or 0)))
 local damage=b.combatDPS*b.shotInterval*clamp(1+(s.combat or 0),.1,4)
 -- Cap the combined damage/rate product, rather than independently allowing 16×.
 local dps=math.min(b.combatDPS*4,damage/interval);damage=dps*interval
 return {miningDPS=not support(d) and b.miningDPS*clamp(1+(s.mining or 0),.1,4)*(1+(p.prestiges or 0)*.25)*(1+doubleBeam) or 0,combatDPS=not support(d) and dps or 0,shotDamage=not support(d) and damage or 0,shotInterval=interval,
  doubleBeam=doubleBeam,twinThrusters=twinThrusters,oreDuplicator=oreDuplicator,
  maxHealth=b.maxHealth*clamp(1+(s.health or 0),.1,4),maxStep60=b.maxStep60*speed,speedMultiplier=speed,
  warmup=math.max(cutter and .05 or .08,b.warmup*(cutter and .5 or C.LASER_CHARGE_SCALE)/math.max(.1,1+(s.startup or 0))),range=b.range*clamp(1+(s.range or 0),.1,1.6),
  yieldMultiplier=clamp(1+(s.yield or 0),.1,2)*(1+oreDuplicator),damageReduction=clamp(s.reduction or 0,0,.5),critChance=clamp(s.crit or 0,0,.3),
  splashFraction=clamp(s.splash or 0,0,.25),splashRange=6+clamp(s.chain or 0,0,16),forkFraction=DroneRoles.isMiner(d.role or d.type) and clamp(s.fork or 0,0,forkCap) or 0,forkRange=DroneRoles.isMiner(d.role or d.type) and (6+clamp(s.forkRange or 0,0,6)) or 0,
  geodeMultiplier=1+clamp(s.geode or 0,0,.8),finisherMultiplier=1+clamp(s.finisher or 0,0,.75),salvageFraction=clamp(s.salvage or 0,0,.3),
  aftershock=cutter and (s.aftershock or 0) or 0,reclaim=s.reclaim or 0,earlyDrop=s.earlyDrop or 0,liveWire=cutter and (s.liveWire or 0) or 0,
  deepCutMultiplier=1+(cutter and (s.deepCut or 0) or 0),
  entryShield=b.maxHealth*clamp(s.shield or 0,0,.2),capacity=C.droneCapacity(p,d,extra),
  batteryCapacity=DroneRoles.isWorker(d.role or d.type) and (Workshop.BATTERY+(s.battery or 0)) or 0,
  courierCapacity=courier(d) and math.floor(8*clamp(1+(s.courierCapacity or 0),1,4)) or 0,
  growCooldown=5/clamp(1+(s.scanDuration or 0),1,2),healAmount=10*clamp(1+(s.healPower or 0),1,2),
  plotAuto=(s.plotAuto or 0)>0 and 1 or 0,fullAuto=courier(d) and clamp(s.fullAuto or 0,0,2) or 0}
end
function C.abilityPerks(p)
 return {orbitalCycle=(Shops.effects(p).orbitalCycle or 0)>0,scrapBots=Shops.effects(p,'Scrapper').scrapBots or 0}
end
function C.price(p) return Workshop.price(p) or 0 end
local function hash(s)
 local h=104729
 for i=1,#s do h=(h*131+string.byte(s,i))%2147483647 end
 return math.max(1,h)
end
C.hash=hash
local function rng(seed)
 local state=seed%2147483647;if state<=0 then state=1 end
 return function(n) state=(state*16807)%2147483647;return math.floor(state/2147483647*n)+1 end
end
-- Weighted draw without replacement determines candidate order. The exhaustive
-- compatible-triple score still wins before this order breaks exact ties.
-- Priority protection and eligibility change marginal odds; no fixed percentages.
function C.weightedOrder(items,random)
 local remaining=table.clone(items);local ordered={}
 while #remaining>0 do
  local total=0
  for _,item in ipairs(remaining) do total=total+(C.RARITY_WEIGHTS[item.rarity] or C.RARITY_WEIGHTS.Common) end
  local ticket=random(total);local index=1
  for i,item in ipairs(remaining) do
   ticket=ticket-(C.RARITY_WEIGHTS[item.rarity] or C.RARITY_WEIGHTS.Common)
   if ticket<=0 then index=i;break end
  end
  table.insert(ordered,table.remove(remaining,index))
 end
 return ordered
end
local statLabels={doubleBeam='Laser count bonus',twinThrusters='Thruster kit',oreDuplicator='Duplicator kit',aftershock='Crack echo damage',reclaim='Battery per break',earlyDrop='Extra early ore',batteryCapacity='Battery capacity',miningDPS='Mining / sec',combatDPS='Combat / sec',maxHealth='Hull',maxStep60='Flight speed',warmup='Laser warmup',range='Combat reach',yieldMultiplier='Ore yield',damageReduction='Damage blocked',critChance='Critical chance',splashFraction='Arc damage',splashRange='Arc reach',forkFraction='Split damage',forkRange='Split reach',geodeMultiplier='Geode damage',deepCutMultiplier='Deep crystal damage',finisherMultiplier='Finishing damage',salvageFraction='Repair on kill',entryShield='Entry shield',shotInterval='Shot interval',plotAuto='Automatic targeting',fullAuto='Courier speed bonus'}
statLabels.liveWire='High-battery damage bonus'
local function vector(p,c)
 local out={fieldCharge=Workshop.effect(p,'fieldCharge',c),capacity=C.capacity(p,c),magnetBonus=C.magnetBonus(p,c),orbitalLaser=Shops.abilityUnlocked(p,'Orbital',c) and 1 or 0,scrapSwarm=Shops.abilityUnlocked(p,'Scrap',c) and 1 or 0}
 local compactor=Workshop.hasCompactor(p,c)
 out.compactor=compactor and 1 or 0
 out.batchPress=compactor and Workshop.effect(p,'batchPress',c) or 0
 out.denserPacking=compactor and Workshop.effect(p,'denserPacking',c) or 0
 out.cargoRack=Workshop.effect(p,'cargoRack',c)
 out.shiftRelay=Workshop.effect(p,'shiftRelay',c)
 for _,d in ipairs(p.fleet) do
  local st=C.stats(p,d,c)
  for k in pairs(statLabels) do if k~='shotInterval' then
   -- Extra reach has no gameplay value until its secondary beam exists.
   -- Do not sell a capped split/arc as useful solely for its dormant range.
   local value=st[k]
   if k=='splashRange' and st.splashFraction==0 or k=='forkRange' and st.forkFraction==0 then value=0 end
   out[d.id..':'..k]=k=='warmup' and -value or value
  end end
 end
 return out
end
local function countOwned(p,c)
 local n=0
 for _,owned in ipairs(p.run.cards) do if owned.cardId==c.cardId and (c.scope~='Individual' or owned.targetDroneId==c.targetDroneId) then n=n+1 end end
 return n
end
local function stackLimit(c)
 if c.cardId=='G01' or c.cardId=='G02' or c.cardId=='F09' or c.cardId=='A01' or c.cardId=='A02' then return 1 end
 if string.sub(c.cardId,1,1)=='R' then return 500 end
 if c.scope=='Fleet' or c.scope=='Player' then return 2 end
 return 1
end
local function beneficial(p,c)
 if countOwned(p,c)>=stackLimit(c) then return false end
 local baseline=vector(p,nil);local after=vector(p,c)
 for key,n in pairs(after) do if n>(baseline[key] or 0)+1e-8 then return true end end
 return false
end
local function preview(p,c)
 local lines={}
 if c.effects.compactor then table.insert(lines,{label='Compactor drones',before=0,after=1,unit=''}) end
 if c.effects.shiftRelay then table.insert(lines,{label='Mining boost after delivery',before=Workshop.effect(p,'shiftRelay'),after=Workshop.effect(p,'shiftRelay',c),unit='s'}) end
 if c.effects.batchPress or c.effects.denserPacking then table.insert(lines,{label='Rocks per full press',before=Workshop.compactorBatch(p),after=Workshop.compactorBatch(p,c),unit='rocks'}) end
 if c.effects.cargoRack then table.insert(lines,{label='Cargo mounts per Emptier',before=Workshop.emptierBatch(p),after=Workshop.emptierBatch(p,c),unit='slots'}) end
 if c.effects.fieldCharge then table.insert(lines,{label='Field recharge',before=Workshop.effect(p,'fieldCharge'),after=Workshop.effect(p,'fieldCharge',c),unit='battery/s'}) end
 if c.effects.capacity then table.insert(lines,{label='Backpack space',before=C.capacity(p),after=C.capacity(p,c),unit='ore'}) end
 if c.effects.magnetRange then table.insert(lines,{label='Extra pickup reach',before=C.magnetBonus(p),after=C.magnetBonus(p,c),unit='studs'}) end
 local target
 -- A fleet card can benefit Red while an already capped first Blue gains
 -- nothing. Show a drone that actually changes, rather than an empty example.
 for _,d in ipairs(p.fleet) do if affects(c,d) or (Workshop.isHardware(c) and c.targetDroneId==nil and Workshop.fits(d)) or (c.scope=='Player' and c.effects.fullAuto and courier(d)) then
  local before,after=C.stats(p,d),C.stats(p,d,c)
  for k in pairs(statLabels) do if math.abs(before[k]-after[k])>1e-8 then target=d;break end end
  if target then break end
 end end
 if target then
  local before,after=C.stats(p,target),C.stats(p,target,c)
  for _,k in ipairs({'aftershock','reclaim','earlyDrop','liveWire','batteryCapacity','miningDPS','combatDPS','maxHealth','maxStep60','warmup','range','yieldMultiplier','damageReduction','critChance','splashFraction','splashRange','forkFraction','forkRange','geodeMultiplier','deepCutMultiplier','finisherMultiplier','salvageFraction','entryShield','shotInterval','plotAuto','fullAuto'}) do
   if math.abs(before[k]-after[k])>1e-8 then
    local scale=k=='maxStep60' and 60 or 1
    local unit=(k=='warmup' or k=='shotInterval') and 's' or (k=='maxStep60' and 'studs/s' or ((k=='range' or k=='splashRange' or k=='forkRange') and 'studs' or ''))
    if k=='aftershock' or k=='earlyDrop' or k=='liveWire' or k=='damageReduction' or k=='critChance' or k=='splashFraction' or k=='forkFraction' or k=='salvageFraction' then scale=100;unit='%' end
    if k=='geodeMultiplier' or k=='deepCutMultiplier' or k=='finisherMultiplier' or k=='yieldMultiplier' then unit='×' end
    table.insert(lines,{label=statLabels[k],before=before[k]*scale,after=after[k]*scale,unit=unit})
   end
  end
 end
 return lines,target and target.name
end
local function receipt(p,operation,tx)
 for i=#p.receipts,1,-1 do local r=p.receipts[i];if r.operation==operation and r.id==tx then return clone(r.result) end end
 return nil
end
local function record(p,operation,tx,result)
 table.insert(p.receipts,{operation=operation,id=tx,runId=p.run.id,result=clone(result)})
 while #p.receipts>64 do table.remove(p.receipts,1) end
end
local function validID(tx) return type(tx)=='string' and #tx>0 and #tx<=128 end
-- Expose only choices with a real benefit for the permanent fleet, including legacy caps.
function C.workshopOffer(p,tier,seed,crystalRun)
 local pool={}
 for _,entry in ipairs(Workshop.CATALOG) do
  local owned=Workshop.find(p,entry.id);local count=owned and owned.level or 0
  if count<entry.max and entry.tier<=tier and (if crystalRun then Workshop.CRYSTAL_DRAFT[entry.id] else not entry.crystalRun) then
   local c=Workshop.card(entry,tier,count)
   if beneficial(p,c) then
    c.preview,c.previewTargetName=preview(p,c)
    table.insert(pool,c)
   end
  end
 end
 if #pool<3 then return nil end
 -- Do not put a strictly weaker version of another offered effect beside it.
 local vectors,compatible={},{}
 for i,c in ipairs(pool) do vectors[i]=vector(p,c);compatible[i]={} end
 for i=1,#pool do for j=i+1,#pool do
  local iBetter,jBetter=false,false
  for key,value in pairs(vectors[i]) do
   if value>vectors[j][key]+1e-8 then iBetter=true elseif value<vectors[j][key]-1e-8 then jBetter=true end
  end
  compatible[i][j]=iBetter and jBetter
 end end
 local triples,total={},0
 local triggerTriples,triggerTotal={},0
 local variedTriples,variedTotal={},0
 local secondCrystalPack=crystalRun and p.run.packIndex==1
 for i=1,#pool-2 do
  for j=i+1,#pool-1 do
   if compatible[i][j] then
    for k=j+1,#pool do
     local guaranteed=pool[i].upgradeTier==tier or pool[j].upgradeTier==tier or pool[k].upgradeTier==tier
     if compatible[i][k] and compatible[j][k] and guaranteed then
      local weight=pool[i].upgradeTier+pool[j].upgradeTier+pool[k].upgradeTier
      local triple={i,j,k,weight}
      total+=weight;table.insert(triples,triple)
      if crystalRun and (Workshop.TRIGGER_CARDS[pool[i].cardId] or Workshop.TRIGGER_CARDS[pool[j].cardId] or Workshop.TRIGGER_CARDS[pool[k].cardId]) then
       triggerTotal+=weight;table.insert(triggerTriples,triple)
       -- The next purchase should let a new build improve a different part
       -- of the loop even when the rolled rarity is Common.
       if secondCrystalPack then
        local a,b,c=pool[i].category,pool[j].category,pool[k].category
        if a~=b and b~=c and a~=c then variedTotal+=weight;table.insert(variedTriples,triple) end
       end
      end
     end
    end
   end
  end
 end
 if variedTotal>0 then triples,total=variedTriples,variedTotal
 elseif triggerTotal>0 then triples,total=triggerTriples,triggerTotal end
 if total==0 then return nil end
 local random=rng(seed);local ticket=random(total);local selected=triples[1]
 for _,triple in ipairs(triples) do ticket-=triple[4];if ticket<=0 then selected=triple;break end end
 local chosen={pool[selected[1]],pool[selected[2]],pool[selected[3]]}
 for i=#chosen,2,-1 do local j=random(i);chosen[i],chosen[j]=chosen[j],chosen[i] end
 return chosen
end
local function firstCrystalPack(p)
 local choices={}
 for _,id in ipairs(Workshop.FIRST_PACK) do
  local entry=Workshop.BY_ID[id]
  local owned=Workshop.find(p,id)
  local level=owned and owned.level or 0
  if level>=entry.max then return nil end
  local c=Workshop.card(entry,2,level)
  if not beneficial(p,c) then return nil end
  c.preview,c.previewTargetName=preview(p,c)
  table.insert(choices,c)
 end
 return choices
end
function C.buy(p,tx,expectedRun,context)
 if not validID(tx) then return false,'Invalid transaction ID' end
 if expectedRun~=p.run.id then return false,'Stale run' end
 local replay=receipt(p,'Buy',tx)
 if replay then return replay.runId==expectedRun,replay end
 if p.run.pendingOffer then return true,clone(p.run.pendingOffer) end
 context=context or {}
 if context.expectedPackIndex~=p.run.packIndex then return false,'Stale pack index' end
 if context.atDepot~=true or context.activeEncounter then return false,'Visit the Quartz Workshop outside combat' end
 local price=Workshop.price(p)
 if Shops.balance(p,'Quartz')<price then return false,'Need '..price..' Quartz' end
 local seed=hash(table.concat({p.seed,p.userId,p.run.index,p.run.packIndex+1,C.CONTENT_VERSION},':'))
 local tier=2
 local choices=context.crystalRun and p.run.packIndex==0 and firstCrystalPack(p) or nil
 if not choices then
  local candidates,weights,total={},{66,24,8,2},0
  for packTier=1,4 do
   candidates[packTier]=C.workshopOffer(p,packTier,hash(tostring(seed)..':'..packTier),context.crystalRun)
   if candidates[packTier] then total+=weights[packTier] end
  end
  if total==0 then return false,'No three useful choices remain. Stack owned upgrades or prestige.' end
  -- Exhausted tiers leave the roll so a Legendary pack includes a Legendary choice.
  local ticket=rng(hash(tostring(seed)..':delivery'))(total)
  for i=1,4 do if candidates[i] then ticket-=weights[i];if ticket<=0 then tier=i;break end end end
  choices=candidates[tier]
 end
 local offer={id=p.run.id..':pack:'..(p.run.packIndex+1),runId=p.run.id,contentVersion=C.CONTENT_VERSION,seed=seed,
  packIndex=p.run.packIndex+1,price=price,currency='Quartz',choices=choices,expires='This run',packTier=tier,opened=false}
 p.run.wallet.Quartz-=price;p.run.credits=p.run.wallet.Quartz
 p.run.packIndex+=1;p.run.pendingOffer=clone(offer)
 record(p,'Buy',tx,offer);return true,clone(offer)
end
function C.workshopUpgrade(p,c)
 if Workshop.isHardware(c) then return nil,'Find another in a pack' end
 if c.level>=c.maxLevel then return nil,'Fully stacked' end
 local nextCard=clone(c);nextCard.level+=1;nextCard.effects=Workshop.effects(nextCard,nextCard.level)
 local delta=clone(c);delta.effects={}
 for k,v in pairs(nextCard.effects) do delta.effects[k]=v-(c.effects[k] or 0) end
 -- Check the actual clamped stats, not just the nominal modifier.
 local before,after=vector(p,nil),vector(p,delta);local useful=false
 for key,n in pairs(after) do if n>(before[key] or 0)+1e-8 then useful=true;break end end
 if not useful then return nil,'Already at the effective cap' end
 nextCard.preview,nextCard.previewTargetName=preview(p,delta)
 nextCard.stackText=nextCard.level..'× · This run'
 return nextCard
end
function C.workshopRows(p)
 local rows={}
 for _,c in ipairs(Workshop.owned(p)) do
  local nextCard,reason=C.workshopUpgrade(p,c)
  table.insert(rows,{card=clone(c),cost=Workshop.levelCost(c),next=nextCard,reason=reason})
 end
 return rows
end
function C.upgrade(p,id,level,tx,expectedRun,context)
 if not validID(tx) then return false,'Invalid transaction ID' end
 if expectedRun~=p.run.id then return false,'Stale run' end
 local replay=receipt(p,'Workshop',tx)
 if replay then return replay.cardId==id and replay.runId==expectedRun and replay.previousLevel==level,replay end
 if not context or context.atDepot~=true or context.activeEncounter then return false,'Visit the Quartz Workshop outside combat' end
 if p.run.pendingOffer then return false,'Choose your delivered upgrade first' end
 local c=Workshop.find(p,id)
 if not c then return false,'Find this upgrade in a pack first' end
 if c.level~=level then return false,'Stack changed. Refresh the workshop.' end
 local nextCard,reason=C.workshopUpgrade(p,c);if not nextCard then return false,reason end
 local cost=Workshop.levelCost(c)
 if Shops.balance(p,'Quartz')<cost then return false,'Need '..cost..' Quartz' end
 p.run.wallet.Quartz-=cost;p.run.credits=p.run.wallet.Quartz
 for i,owned in ipairs(p.run.cards) do if owned==c then p.run.cards[i]=nextCard;break end end
 local result={cardId=id,title=c.title,level=nextCard.level,previousLevel=level,cost=cost,runId=p.run.id}
 record(p,'Workshop',tx,result);return true,clone(result)
end
function C.open(p,offerId)
 local offer=p.run.pendingOffer
 if not offer or offer.id~=offerId then return false,'Pack is no longer pending' end
 offer.opened=true
 return true,{offerId=offerId}
end
function C.select(p,offerId,index,tx,expectedRun,context)
 if not validID(tx) then return false,'Invalid transaction ID' end
 if expectedRun~=p.run.id then return false,'Stale run' end
 context=context or {}
 local replay=receipt(p,'Select',tx);if replay then return replay.offerId==offerId and replay.index==index and replay.runId==expectedRun and replay.selectedDroneId==context.targetDroneId,replay end
 if context.atDepot~=true or context.activeEncounter then return false,'Choose your card at the depot outside combat' end
 local offer=p.run.pendingOffer
 if not offer or offer.id~=offerId or offer.runId~=p.run.id then return false,'Offer is no longer pending' end
 if offer.opened==false then return false,'Open your delivered pack first' end
 if not finite(index) or index%1~=0 or index<1 or index>3 then return false,'Invalid card choice' end
 local c=clone(offer.choices[index])
 if Workshop.isHardware(c) then
  local target
  for _,d in ipairs(Workshop.targets(p,c)) do if d.id==context.targetDroneId then target=d;break end end
  if not target then return false,'Choose a miner without this part' end
  c.targetDroneId=target.id;c.targetName=target.name;c.preview,c.previewTargetName=preview(p,c)
 elseif c.scope=='Individual' then
  local exists=false;for _,d in ipairs(p.fleet) do if d.id==c.targetDroneId then exists=true end end
  if not exists then return false,'Saved target missing; refund offer through migration' end
 end
 if c.workshop then
  local owned=Workshop.find(p,c.cardId,c.targetDroneId);local before=owned and owned.level or 0
  if c.stackBefore~=nil and c.stackBefore~=before then return false,'Upgrade stack changed' end
  if before+c.level>c.maxLevel then return false,'Upgrade stack reached its maximum' end
  if owned then
   c.level+=before;c.effects=Workshop.effects(c,c.level)
   c.packTier=math.max(c.packTier,owned.packTier)
   if c.stackVersion~=2 then c.rarity=Workshop.TIERS[c.packTier] end
   for i,entry in ipairs(p.run.cards) do if entry==owned then table.remove(p.run.cards,i);break end end
  end
  c.stackBefore=nil;c.stackText=c.level..'× · This run'
 end
 -- No mutable catalog lookup: the complete paid choice is the contract.
 table.insert(p.run.cards,c);p.run.pendingOffer=nil
 local stars=offer.packTier or 1
 p.run.stars=(p.run.stars or 0)+stars
 local result={stars=stars,offerId=offer.id,runId=p.run.id,card=clone(c),index=index,selectedDroneId=Workshop.isHardware(c) and c.targetDroneId or nil}
 record(p,'Select',tx,result);return true,result
end
function C.refundInvalidOffer(p)
 local o=p.run.pendingOffer;if not o then return false end
 local valid=o.runId==p.run.id and type(o.choices)=='table' and #o.choices==3
 if valid then
  for _,c in ipairs(o.choices) do
   if type(c.effects)~='table' then valid=false;break end
   if Workshop.isHardware(c) then
    if #Workshop.targets(p,c)==0 then valid=false;break end
   elseif c.scope=='Individual' then local found=false;for _,d in ipairs(p.fleet) do if d.id==c.targetDroneId then found=true end end;if not found then valid=false;break end end
  end
 end
 if valid then return false end
 if not finite(o.price) or o.price<0 then return false,'Corrupt paid offer; require recovery' end
 local balance=Shops.balance(p,Shops.PACK_CURRENCY)
 if balance+math.floor(o.price)>=1e14 then return false,'Refund exceeds wallet limit' end
 p.run.wallet[Shops.PACK_CURRENCY]=balance+math.floor(o.price);p.run.credits=p.run.wallet.Quartz;p.run.pendingOffer=nil
 return true,'Full saved pack price refunded; no reroll'
end
return C

end)()
local Persistence = (function()
-- Durable session ownership and ordered, revision-fenced profile transactions.
-- No Roblox service is accessed at module load: the adapters below are explicit.
local Persistence = {}
local Manager = {}
Manager.__index = Manager
local nextManager = 0
local previewNamespaces = {}

local function finite(n)
 return type(n)=='number' and n==n and n>-math.huge and n<math.huge
end
local function copy(value, stack, depth)
 local kind=type(value)
 if kind=='nil' or kind=='boolean' or kind=='string' then return value end
 if kind=='number' then assert(finite(value),'non-finite saved number');return value end
 assert(kind=='table','non-serializable saved value')
 depth=(depth or 0)+1;assert(depth<=64,'saved value nesting exceeds 64')
 stack=stack or {};assert(not stack[value],'cyclic saved value');stack[value]=true
 local result={}
 for k,v in pairs(value) do
  assert(type(k)=='string' or (finite(k) and k>=1 and k%1==0),'invalid saved key')
  result[k]=copy(v,stack,depth)
 end
 stack[value]=nil;return result
end
Persistence.clone=copy

local function validEnvelope(value)
 return type(value)=='table' and value.storageVersion==1 and finite(value.revision)
  and value.revision>=0 and value.revision<9007199254740991 and value.revision%1==0 and type(value.data)=='table'
  and type(value.receipts)=='table'
end
local function findReceipt(envelope,id)
 for i=#envelope.receipts,1,-1 do
  local r=envelope.receipts[i]
  if type(r)=='table' and r.id==id then return r end
 end
 return nil
end
local function holds(envelope,session)
 local lock=envelope.lock
 return type(lock)=='table' and lock.owner==session.owner and lock.token==session.token
end
local function validLock(lock)
 return lock==nil or (type(lock)=='table' and type(lock.owner)=='string' and type(lock.token)=='string' and finite(lock.expiresAt))
end
local function appendReceipt(envelope,receipt,limit)
 table.insert(envelope.receipts,receipt)
 while #envelope.receipts>limit do table.remove(envelope.receipts,1) end
end

function Persistence.new(adapter,options)
 assert(type(adapter)=='table' and type(adapter.update)=='function','persistence adapter required')
 options=options or {}
 assert(type(options.owner)=='string' and #options.owner>0,'unique server owner required')
 assert(type(options.newProfile)=='function','newProfile factory required')
 assert(type(options.migrate)=='function' and type(options.validate)=='function','profile migration and validation required')
 nextManager=nextManager+1
 return setmetatable({adapter=adapter,options=options,owner=options.owner,now=options.now or os.time,
  wait=options.wait or function() end,leaseSeconds=options.leaseSeconds or 180,
  attempts=options.maxAttempts or 3,receiptLimit=options.receiptLimit or 48,
  counter=0,managerId=nextManager,sessions={},mode=adapter.mode or 'Durable'},Manager)
end
function Manager:_id(prefix,userId)
 self.counter=self.counter+1
 return table.concat({prefix,self.owner,tostring(self.managerId),tostring(userId),tostring(self.counter)},':')
end
function Manager:_validate(data,userId)
 local ok,a,b=pcall(self.options.validate,data,userId)
 if not ok then return false,'profile-validation-error' end
 if a~=true then return false,b or 'invalid-profile' end
 local serializable=pcall(copy,data)
 if not serializable then return false,'non-serializable-profile' end
 return true
end
function Manager:_migrate(raw,userId)
 local ok,value,err
 if raw==nil then ok,value=pcall(self.options.newProfile,userId)
 else ok,value,err=pcall(self.options.migrate,copy(raw),userId) end
 if not ok or type(value)~='table' then return nil,err or 'profile-migration-failed' end
 local valid,why=self:_validate(value,userId)
 if not valid then return nil,why end
 return value
end
-- Calls are retried in order with the SAME transform and transaction identity.
-- UpdateAsync is allowed to invoke its transform repeatedly; mutations are prepared outside it.
function Manager:_update(key,transform)
 local lastError='save-unavailable'
 for attempt=1,self.attempts do
  local ok,result=pcall(function() return self.adapter:update(key,transform) end)
  if ok then return true,result end
  lastError=tostring(result)
  if attempt<self.attempts then self.wait(math.min(1,.1*(3^(attempt-1)))) end
 end
 return false,nil,lastError
end
function Manager:load(userId)
 local preview=string.sub(self.mode,1,7)=='Preview'
 if not finite(userId) or userId%1~=0 or math.abs(userId)>=1e14 or (not preview and userId<1) then return nil,'invalid-user' end
 if self.sessions[userId] and not self.sessions[userId].closed then return nil,'already-loaded' end
 local token=self:_id('lease',userId)
 local key='player:'..tostring(userId)
 local rejection
 local ok,envelope=self:_update(key,function(old)
  rejection=nil
  local current
  if old==nil then
   local data,err=self:_migrate(nil,userId)
   if not data then rejection=err;return nil end
   current={storageVersion=1,revision=0,data=data,receipts={}}
  elseif validEnvelope(old) then
   if not validLock(old.lock) then rejection='corrupt-lock';return nil end
   current=copy(old)
   local data,err=self:_migrate(current.data,userId)
   if not data then rejection=err;return nil end
   current.data=data
  elseif type(old)=='table' and old.storageVersion==nil then
   -- Explicit legacy raw-profile migration; malformed/newer envelopes fail closed.
   local data,err=self:_migrate(old,userId)
   if not data then rejection=err;return nil end
   current={storageVersion=1,revision=0,data=data,receipts={}}
  else rejection='unsupported-storage-envelope';return nil end
  local lock=current.lock
  if lock and lock.expiresAt>self.now() and (lock.owner~=self.owner or lock.token~=token) then
   rejection='session-locked';return nil
  end
  current.lock={owner=self.owner,token=token,expiresAt=self.now()+self.leaseSeconds}
  current.data.revision=current.revision
  local valid,err=self:_validate(current.data,userId)
  if not valid then rejection=err;return nil end
  return current
 end)
 if not ok then return nil,'load-unavailable' end
 if not validEnvelope(envelope) then return nil,rejection or 'load-rejected' end
 if not envelope.lock or envelope.lock.token~=token then return nil,'session-locked' end
 local s={userId=userId,key=key,owner=self.owner,token=token,data=copy(envelope.data),revision=envelope.revision,
  leaseUntil=envelope.lock.expiresAt,busy=false,readOnly=false,lost=false,closed=false,pending=nil,mode=self.mode,receipts=copy(envelope.receipts)}
 self.sessions[userId]=s
 return s
end
function Manager:healthy(session)
 return self.sessions[session.userId]==session and not session.closed and not session.lost
  and not session.readOnly and self.now()<session.leaseUntil
end
function Manager:_write(session,id,mutate,releasing)
 if type(id)~='string' or #id<1 or #id>240 then return false,'invalid-transaction-id' end
 if self.sessions[session.userId]~=session or session.closed or session.lost then return false,'session-lost' end
 if session.readOnly then return false,'reconciliation-required' end
 if session.busy then return false,'profile-busy' end
 for _,receipt in ipairs(session.receipts or {}) do
  if receipt.id==id then return true,copy(receipt.result) end
 end
 session.busy=true
 local baseRevision=session.revision
 local cloneOk,prepared=pcall(copy,session.data)
 if not cloneOk then session.busy=false;return false,'non-serializable-profile' end
 local called,result,err=pcall(mutate,prepared)
 if not called then session.busy=false;return false,'mutation-error' end
 if result==nil or result==false then session.busy=false;return false,err or 'mutation-rejected' end
 local valid,why=self:_validate(prepared,session.userId)
 if not valid then session.busy=false;return false,why end
 local resultOk,preparedResult=pcall(copy,result)
 if not resultOk then session.busy=false;return false,'non-serializable-result' end
 session.pending={id=id,baseRevision=baseRevision,releasing=releasing==true}
 local rejection
 local ok,envelope=self:_update(session.key,function(old)
  rejection=nil
  if not validEnvelope(old) then rejection='corrupt-storage';return nil end
  local receipt=findReceipt(old,id)
  if receipt then
   -- Release can be reconciled after its lease was removed, without writing stale data.
   if releasing or holds(old,session) then return old end
   rejection='session-lost';return nil
  end
  if not validLock(old.lock) or not holds(old,session) then rejection='session-lost';return nil end
  if old.revision~=baseRevision then rejection='revision-conflict';return nil end
  local next=copy(old)
  next.revision=baseRevision+1;next.data=copy(prepared);next.data.revision=next.revision
  if releasing then next.lock=nil else next.lock={owner=session.owner,token=session.token,expiresAt=self.now()+self.leaseSeconds} end
  appendReceipt(next,{id=id,result=preparedResult,revision=next.revision,released=releasing==true},self.receiptLimit)
  return next
 end)
 session.busy=false
 if not ok then
  -- The remote service may have committed before its response failed. Never replay a
  -- freshly generated offer/prestige or grant local success; reconcile this exact ID.
  session.readOnly=true;session.uncertain=true
  return false,'save-unavailable'
 end
 if not validEnvelope(envelope) then
  session.pending=nil
  if rejection=='session-lost' or rejection=='revision-conflict' then session.lost=true;session.readOnly=true end
  return false,rejection or 'save-rejected'
 end
 local receipt=findReceipt(envelope,id)
 if not receipt then session.readOnly=true;return false,'missing-commit-receipt' end
 session.data=copy(envelope.data);session.revision=envelope.revision;session.receipts=copy(envelope.receipts)
 session.leaseUntil=envelope.lock and envelope.lock.expiresAt or 0
 session.pending=nil;session.uncertain=false
 if releasing then session.closed=true;self.sessions[session.userId]=nil end
 return true,copy(receipt.result)
end
function Manager:transaction(session,id,mutate)
 if type(mutate)~='function' then return false,'invalid-mutation' end
 return self:_write(session,id,mutate,false)
end
function Manager:save(session)
 return self:_write(session,self:_id('save',session.userId),function() return {saved=true} end,false)
end
function Manager:release(session)
 if session.closed then return true,{released=true} end
 return self:_write(session,self:_id('release',session.userId),function() return {released=true} end,true)
end
function Manager:reconcile(session)
 if self.sessions[session.userId]~=session or session.closed or session.lost then return false,'session-lost' end
 if session.busy then return false,'profile-busy' end
 local pending=session.pending
 if not pending then return not session.readOnly,session.readOnly and 'no-pending-transaction' or 'ready' end
 session.busy=true
 local rejection
 local ok,envelope=self:_update(session.key,function(old)
  if not validEnvelope(old) then rejection='corrupt-storage';return nil end
  local receipt=findReceipt(old,pending.id)
  if receipt and pending.releasing then return old end
  if not holds(old,session) then rejection='session-lost';return nil end
  if old.revision~=pending.baseRevision and not receipt then rejection='revision-conflict';return nil end
  local next=copy(old);next.lock.expiresAt=self.now()+self.leaseSeconds;return next
 end)
 session.busy=false
 if not ok then return false,'reconciliation-unavailable' end
 if not validEnvelope(envelope) then
  if rejection=='session-lost' or rejection=='revision-conflict' then session.lost=true end
  return false,rejection or 'reconciliation-rejected'
 end
 local receipt=findReceipt(envelope,pending.id)
 if receipt then
  session.data=copy(envelope.data);session.revision=envelope.revision;session.receipts=copy(envelope.receipts)
  if pending.releasing then session.closed=true;self.sessions[session.userId]=nil end
 else
  -- Confirmed not committed, and the fenced revision is unchanged. Keep pre-transaction
  -- session data (including dirty earned cargo), never the rejected staged mutation.
  session.data.revision=envelope.revision
 end
 session.leaseUntil=envelope.lock and envelope.lock.expiresAt or 0
 session.pending=nil;session.readOnly=false;session.uncertain=false
 return true,receipt and copy(receipt.result) or {committed=false}
end

function Persistence.dataStore(store)
 assert(store and type(store.UpdateAsync)=='function','DataStore object required')
 return {mode='Durable',update=function(_,key,transform) return store:UpdateAsync(key,transform) end}
end
function Persistence.previewAdapter(namespace)
 assert(type(namespace)=='string' and #namespace>0,'explicit preview namespace required')
 previewNamespaces[namespace]=previewNamespaces[namespace] or {}
 local values=previewNamespaces[namespace]
 return {mode='Preview — not saved across server restarts',update=function(_,key,transform)
  local next=transform(copy(values[key]))
  if next~=nil then values[key]=copy(next) end
  return copy(next)
 end}
end
return Persistence

end)()
local DroneConfig = (function()

export type AttackStyle = "Bolt" | "Charge" | "Heal" | "Carry" | "Grow" | "Orbital" | "Swarm" | "Special"

export type DroneDefinition = {
	DisplayName: string,
	Description: string,
	Color: Color3,
	Accent: Color3,
	Scale: number,
	MaxHealth: number,
	Speed: number,
	FlightHeight: number,
	AttackStyle: AttackStyle,
	AttackRange: number,
	AttackCooldown: number,
	Damage: number,
	HealAmount: number?,
	ChargeWindup: number?,
	ChargeSpeed: number?,
	Weight: number,
	MiningDuration: number?,
}

local DroneConfig = {}

-- Both the authoritative model and its client view clone use this same ratio.
-- The original mesh, emitter and identity remain intact at worker scale.
DroneConfig.Swarm = {ModelScale=.58,FleetViewScale=.94,MinerViewScale=1.22,FieldViewScale=1.16}

DroneConfig.Settings = {
	TestSquadMin = 2,
	TestSquadMax = 5,
	FormationSpacing = 5.5,
	MaxCommandDistance = 240,
	CommandCooldown = 0.08,
	RandomizeCooldown = 1.25,
	SimulationStep = 1 / 30,
	TargetRespawnTime = 3,
}

DroneConfig.Order = {
	Follow = "Follow",
	Move = "Move",
	Attack = "Attack",
	Hold = "Hold",
}

DroneConfig.Types = {
	Dart = {
		DisplayName = "Cultivator",
		Description = "Rock grower. Plants replacement crystals in depleted plots. Flies to an empty spot, seeds it, then the rock grows. Does not mine.",
		Color = Color3.fromRGB(131, 220, 151),
		Accent = Color3.fromRGB(224, 253, 255),
		Scale = 0.72,
		MaxHealth = 48,
		Speed = 35,
		FlightHeight = 3.2,
		AttackStyle = "Grow",
		AttackRange = 26,
		AttackCooldown = 0.38,
		Damage = 5,
		Weight = 4,
	},
	Striker = {
		DisplayName = "Striker",
		Description = "Miner. The crew's ordinary continuous mining laser; works above one crystal at a time.",
		Color = Color3.fromRGB(75, 122, 255),
		Accent = Color3.fromRGB(190, 206, 255),
		Scale = 0.9,
		MaxHealth = 78,
		Speed = 24,
		FlightHeight = 3.4,
		AttackStyle = "Bolt",
		AttackRange = 38,
		AttackCooldown = 0.9,
		Damage = 14,
		Weight = 5,
	},
	Medic = {
		DisplayName = "Medic",
		Description = "Tiny support disc. Repairs nearby drones for 10 health every 2 seconds.",
		Color = Color3.fromRGB(76, 255, 149),
		Accent = Color3.fromRGB(225, 255, 235),
		Scale = 0.48,
		MaxHealth = 64,
		Speed = 14.4,
		FlightHeight = 3.8,
		AttackStyle = "Heal",
		AttackRange = 12,
		AttackCooldown = 2,
		Damage = 0,
		HealAmount = 10,
		ChargeWindup = 0.4,
		Weight = 2,
	},
	Courier = {
		DisplayName = "Courier",
		Description = "Backpack emptier. Reserves up to 8 ore, takes its own parcel to orbital storage, then returns for another.",
		Color = Color3.fromRGB(218, 172, 81),
		Accent = Color3.fromRGB(243, 219, 162),
		Scale = 0.75,
		MaxHealth = 58,
		Speed = 24,
		FlightHeight = 3.2,
		AttackStyle = "Carry",
		AttackRange = 0,
		AttackCooldown = 2,
		Damage = 0,
		Weight = 3,
	},
	Charger = {
		DisplayName = "Charger",
		Description = "Breaker. Winds up, dives into a tough rock, impacts once, then recovers. No continuous mining beam.",
		Color = Color3.fromRGB(255, 113, 65),
		Accent = Color3.fromRGB(255, 226, 133),
		Scale = 1.12,
		MaxHealth = 132,
		Speed = 18,
		FlightHeight = 2.8,
		AttackStyle = "Charge",
		AttackRange = 11,
		AttackCooldown = 2.6,
		Damage = 38,
		ChargeWindup = 0.85,
		ChargeSpeed = 72,
		Weight = 2,
	},
	Orbiter = {
		DisplayName = "Orbiter",
		Description = "Orbital controller. Charges and calls a real strike on the biggest rock, then cools down. Does not mine normally.",
		Color = Color3.fromRGB(221, 165, 78),
		Accent = Color3.fromRGB(245, 223, 162),
		Scale = 0.84,
		MaxHealth = 80,
		Speed = 22,
		FlightHeight = 3.6,
		AttackStyle = "Orbital",
		AttackRange = 24,
		AttackCooldown = 0.8,
		Damage = 10,
		Weight = 2,
	},
	Scrapper = {
		DisplayName = "Scrapper",
		Description = "Swarm fabricator. Launches disposable mini miners for ten seconds, then waits to rebuild them. No normal mining beam.",
		Color = Color3.fromRGB(155, 181, 110),
		Accent = Color3.fromRGB(219, 230, 181),
		Scale = 0.82,
		MaxHealth = 84,
		Speed = 21,
		FlightHeight = 3.2,
		AttackStyle = "Swarm",
		AttackRange = 20,
		AttackCooldown = 0.9,
		Damage = 11,
		Weight = 2,
	},
} :: { [string]: DroneDefinition }

DroneConfig.TypeOrder = { "Dart", "Striker", "Medic", "Charger", "Courier", "Orbiter", "Scrapper" }
-- Permanent specialist hardware extends the existing seven jobs. The server
-- removes a bounded chunk through each role's distinct timed work cycle.
local specialDefinitions: {[string]: {description: string, color: {number}, duration: number, health: number}} = {
 Bubbler={description='Pressure vessels pull loose chips into a buoyant bubble, then pop it. Repeats until the rock breaks.',color={120,225,255},duration=2.8,health=80},
 Halver={description='Wide articulated jaws shear off a seam and ring-grind its chips. Hard rocks need repeated cuts.',color={190,140,255},duration=3.6,health=110},
 Gridcutter={description='A rectangular scanning gantry scores and ejects one layer of mineral cubes per pass.',color={255,100,130},duration=2.5,health=80},
 Singularity={description='A tilted containment ring feeds a small gravity well that strips a bounded chunk per pulse.',color={155,100,255},duration=2,health=100},
 Starforge={description='A tall furnace focuses solar heat into a seam, releasing a short stream of molten chips.',color={255,170,60},duration=3,health=80},
 Frostbite={description='Long cryogenic tanks freeze a surface layer, then a sharp pressure pulse cracks it away.',color={150,255,245},duration=2.4,health=80},
 Resonator={description='Three tuning forks build a coherent vibration, then snap off one resonant mineral chunk.',color={125,255,160},duration=2.6,health=80},
}
local specialOrder = {'Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'}
for _,name in ipairs(specialOrder) do
 local definition=specialDefinitions[name]
 local color=Color3.fromRGB(table.unpack(definition.color))
 DroneConfig.Types[name]={DisplayName=name,Description=definition.description,Color=color,Accent=color:Lerp(Color3.new(1,1,1),.55),Scale=.9,MaxHealth=definition.health,Speed=24,FlightHeight=3.4,AttackStyle='Special',AttackRange=24,AttackCooldown=.9,Damage=name=='Singularity' and 18 or 12,Weight=1,MiningDuration=definition.duration}
 table.insert(DroneConfig.TypeOrder,name)
end
local fieldTestRoles={
 Needler={label='Needler',color=Color3.fromRGB(255,195,94),detail='Throws quick darts. Favors small and chipped crystals in deep fields.'},
 Ballcaster={label='Ballcaster',color=Color3.fromRGB(150,124,255),detail='Deals 50% more damage through the first two layers of deep crystals.'},
 Vacuum={label='Vacuum',color=Color3.fromRGB(95,226,184),detail='Flies to loose ore, pulls it in and sends it to your backpack.'},
 Compactor={label='Compactor',color=Color3.fromRGB(255,184,83),detail='Presses loose rocks into one block worth the sum of its inputs.'},
}
for name,role in pairs(fieldTestRoles) do
 DroneConfig.Types[name]={DisplayName=role.label,Description=role.detail,Color=role.color,Accent=role.color:Lerp(Color3.new(1,1,1),.5),Scale=.9,MaxHealth=80,Speed=26,FlightHeight=3.2,AttackStyle='Special',AttackRange=20,AttackCooldown=1,Damage=12,Weight=1}
end

-- The active place retains its original elapsed-time motion and mining equations.
-- These runtime traits preserve the prior Studio role tuning and never enter saved fleets.
DroneConfig.StudioRoles = {
 Dart = {height=3.2,base={miningDPS=30,combatDPS=9,maxHealth=50,maxStep60=.48,warmup=.8,range=20,shotInterval=.42}},
 Striker = {height=3.4,base={miningDPS=30,combatDPS=18,maxHealth=85,maxStep60=.35,warmup=.8,range=24,shotInterval=.8}},
 Medic = {height=3.8,base={miningDPS=30,combatDPS=6,maxHealth=72,maxStep60=.24,warmup=.8,range=12,shotInterval=2}},
 Courier = {height=3.2,base={miningDPS=30,combatDPS=6,maxHealth=58,maxStep60=.40,warmup=.8,range=12,shotInterval=2}},
 Charger = {height=2.8,base={miningDPS=30,combatDPS=14,maxHealth=135,maxStep60=.29,warmup=.8,range=16,shotInterval=2.4}},
 Orbiter = {height=3.6,base={miningDPS=30,combatDPS=12,maxHealth=80,maxStep60=.36,warmup=.8,range=24,shotInterval=.8}},
 Scrapper = {height=3.2,base={miningDPS=30,combatDPS=12,maxHealth=84,maxStep60=.35,warmup=.8,range=20,shotInterval=.9}},
}
for _,name in ipairs(specialOrder) do
 local definition=specialDefinitions[name]
 DroneConfig.StudioRoles[name]={height=3.4,base={miningDPS=30,combatDPS=name=='Singularity' and 20 or 12,maxHealth=definition.health,maxStep60=.38,warmup=.8,range=24,shotInterval=.8}}
end
for name in pairs(fieldTestRoles) do
 DroneConfig.StudioRoles[name]={height=3.2,base={miningDPS=30,combatDPS=12,maxHealth=80,maxStep60=.43,warmup=.065,range=20,shotInterval=1}}
end

DroneConfig.Courier = {BatchUnits=8,PickupDistance=4,PickupCooldown=2,PickupHold=.55,LaunchHold=.25,UnloadHold=.65}
DroneConfig.PressSockets = {Vector3.new(0,-1.05,.96),Vector3.new(-1.02,-1.05,.27),Vector3.new(1.02,-1.05,.27),Vector3.new(-.58,-1.05,-.86),Vector3.new(.58,-1.05,-.86)}

-- Quarry machines share painted stone-gray panels and worn metal at working
-- surfaces. The old Mesh, weld and emitter stay in every clone as the rig.
-- This only builds the visible hull; flight, reach and articulation are unchanged.
function DroneConfig.decorate(model: Model, role: string, finishColor: Color3?, readable: boolean?): (Model, BasePart?, BasePart?)
 local body=model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart',true)
 local emitter: any=model:FindFirstChild('Emmiter',true)
 if model:GetAttribute('RoleGeometry')==role then return model,body,emitter and emitter:IsA('BasePart') and emitter or nil end
 local def=DroneConfig.Types[role]
 if not body or not def then return model,body,emitter and emitter:IsA('BasePart') and emitter or nil end

 local pose,scale=model:GetPivot(),model:GetScale()
 local color=finishColor or def.Color
 local dark=readable and Color3.fromRGB(37,47,63) or Color3.fromRGB(67,76,84)
 local pale=readable and Color3.fromRGB(240,239,225) or Color3.fromRGB(211,219,219)
 local painted=readable and color:Lerp(pale,.23) or Color3.fromRGB(199,203,205):Lerp(color,.55)
 local metal=Enum.Material.Metal
 local slate=Enum.Material.Slate
 local smooth=Enum.Material.SmoothPlastic
 local cylinder=Enum.PartType.Cylinder
 local vertical=CFrame.Angles(0,0,math.pi/2)
 local foreAft=CFrame.Angles(0,math.pi/2,0)
 body.Transparency=1;body.CastShadow=false
 if emitter and emitter:IsA('BasePart') then emitter.Transparency=1;emitter.CastShadow=false end

 local function hardware(name: string,size: Vector3,offset: CFrame,tint: Color3,material: Enum.Material,kind: Enum.PartType?,motion: string?,side: number?,wedge: boolean?): BasePart
  local part: BasePart=if wedge then Instance.new('WedgePart') else Instance.new('Part')
  part.Name=name;part.Anchored=true
  part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  part.Material=material;part.Color=tint;part.Reflectance=0
  if readable and (material==metal or material==slate) then
   part.Material=smooth
  elseif material==metal then
   part.Material=Enum.Material.CorrodedMetal;part.MaterialVariant='QuarryDrone_Ribbed'
  elseif material==slate then
   part.MaterialVariant='QuarryDrone_Painted'
  end
  part.Size=size*scale;part.CFrame=pose*CFrame.new(offset.Position*scale)*offset.Rotation
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  if kind and part:IsA('Part') then part.Shape=kind end
  if motion then part:SetAttribute('SpecialMotion',motion);part:SetAttribute('MotionSide',side or 1) end
  part.Parent=model;return part
 end
 local function pod(name: string,diameter: number,height: number,y: number,tint: Color3,material: Enum.Material)
  return hardware(name,Vector3.new(height,diameter,diameter),CFrame.new(0,y,0)*vertical,tint,material,cylinder)
 end
 local function lens(name: string,point: Vector3,tint: Color3,radius: number)
  return hardware(name,Vector3.new(.12,radius,radius),CFrame.new(point)*vertical,tint,Enum.Material.Neon,cylinder)
 end
 local function shotMuzzle(part: BasePart,position: Vector3)
  if not readable then return end
  local mount=Instance.new('Attachment');mount.Name='ShotMuzzle';mount.Position=position;mount.Parent=part
 end

 if specialDefinitions[role] then
  -- Working assemblies retain their original joints and travel. Each now gets
  -- a small chassis suited to its tool instead of the common square behind it.
  if role=='Bubbler' then
   pod('PressureManifold',1.48,.50,-.06,painted,slate)
   pod('ManifoldSeal',1.30,.14,-.33,dark,metal)
  elseif role=='Halver' then
   hardware('ShearCounterweight',Vector3.new(.68,.62,1.95),CFrame.new(0,.16,.46),painted,slate,cylinder)
   hardware('JawPump',Vector3.new(.56,.42,1.02),CFrame.new(0,.33,.58),dark,metal)
  elseif role=='Gridcutter' then
   hardware('RaisedBridge',Vector3.new(2.28,.33,.62),CFrame.new(0,.34,.43),painted,slate)
   hardware('RelayCap',Vector3.new(.44,.78,.78),CFrame.new(0,.39,.39)*vertical,dark,metal,cylinder)
  elseif role=='Singularity' then
   pod('FieldSpindle',1.52,.36,-.14,painted,slate)
   pod('SpindleClamp',1.12,.15,-.35,dark,metal)
  elseif role=='Starforge' then
   pod('ForgeBelly',1.65,.44,-.15,painted,slate)
   pod('InsulatedGasket',1.41,.16,-.42,dark,metal)
  elseif role=='Frostbite' then
   hardware('CryoKeel',Vector3.new(.85,.46,2.10),CFrame.new(0,.03,.02),painted,slate,nil,nil,nil,true)
   hardware('ColdPlate',Vector3.new(.62,.15,1.58),CFrame.new(0,-.20,.11),pale,metal)
  else
   hardware('ResonatorKeel',Vector3.new(2.45,.35,.75),CFrame.new(0,-.04,0),painted,slate,cylinder)
   hardware('DampingPlate',Vector3.new(1.92,.16,.57),CFrame.new(0,-.24,0),dark,metal)
  end
  if role=='Bubbler' then
   -- Two large pressure bulbs and their open roll cage read as rounded tanks,
   -- rather than another recolored copy of the small authored chassis.
   for _,side in ipairs({-1,1}) do
    local glass=hardware('PressureBulb',Vector3.one*1.2,CFrame.new(side*1.2,.38,0),color,Enum.Material.Glass,Enum.PartType.Ball,'Bulb',side)
    glass.Transparency=.28;glass.Reflectance=.12
    hardware('BulbFoot',Vector3.new(.18,1.05,1.05),CFrame.new(side*1.2,-.15,0)*CFrame.Angles(0,0,math.pi/2),dark,metal,Enum.PartType.Cylinder,'Bulb',side)
    hardware('PressureNeck',Vector3.new(.18,.38,.18),CFrame.new(side*1.2,1.07,0),pale,metal,nil,'Valve',side)
    hardware('ValveHandle',Vector3.new(.48,.10,.13),CFrame.new(side*1.2,1.28,0),dark,metal,nil,'Valve',side)
   end
   hardware('PressureBridge',Vector3.new(2.4,.15,.22),CFrame.new(0,.9,.55),dark,metal)
   hardware('BubbleNozzle',Vector3.new(.55,.44,.44),CFrame.new(0,-.65,-.45)*CFrame.Angles(0,0,math.pi/2),pale,metal,Enum.PartType.Cylinder,'Nozzle')
  elseif role=='Halver' then
   -- Wide cantilevered jaws have a heavy, open tool silhouette even at rest.
   for _,side in ipairs({-1,1}) do
    hardware('JawHinge',Vector3.new(.3,.55,.55),CFrame.new(side*.95,.12,.45)*CFrame.Angles(0,0,math.pi/2),pale,metal,Enum.PartType.Cylinder,'Jaw',side)
    hardware('Cantilever',Vector3.new(.38,.28,1.9),CFrame.new(side*1.4,-.08,-.25)*CFrame.Angles(0,side*.18,0),dark,metal,nil,'Jaw',side)
    hardware('ShearBlade',Vector3.new(.16,.8,1.15),CFrame.new(side*1.7,-.45,-.75)*CFrame.Angles(0,0,-side*.14),color,metal,nil,'Jaw',side)
    hardware('BladeEdge',Vector3.new(.08,.7,.95),CFrame.new(side*1.6,-.5,-.83),pale,metal,nil,'Jaw',side)
   end
   hardware('JawCrossbrace',Vector3.new(2.6,.22,.3),CFrame.new(0,.12,.65),dark,metal)
  elseif role=='Gridcutter' then
   -- The square perimeter remains readable without any active laser effect.
   for _,side in ipairs({-1,1}) do
    hardware('GantryRail',Vector3.new(.18,.28,2.5),CFrame.new(side*1.25,-.32,0),dark,metal)
    hardware('GantryEnd',Vector3.new(2.65,.24,.18),CFrame.new(0,-.32,side*1.25),pale,metal)
    hardware('RailMount',Vector3.new(.18,.5,.22),CFrame.new(side*1.25,-.02,0),dark,metal)
   end
   hardware('ScanCarriage',Vector3.new(2.35,.2,.28),CFrame.new(0,-.55,0),color,metal,nil,'Scanner')
   for i=-2,2 do hardware('GridLens',Vector3.new(.12,.12,.13),CFrame.new(i*.43,-.72,0),color,Enum.Material.Neon,nil,'Scanner') end
  elseif role=='Singularity' then
   local ring=CFrame.new(0,.85,0)*CFrame.Angles(.75,0,.25)
   for i=1,12 do
    local angle=(i-.5)*math.pi/6
    hardware('ContainmentSegment',Vector3.new(.18,.18,.69),ring*CFrame.new(math.cos(angle)*1.3,0,math.sin(angle)*1.3)*CFrame.Angles(0,-angle,0),i%3==0 and color or dark,metal,nil,'Containment')
   end
   hardware('GravityCore',Vector3.one*.68,CFrame.new(0,.85,0),Color3.fromRGB(10,7,20),Enum.Material.Glass,Enum.PartType.Ball,'GravityCore')
   for _,side in ipairs({-1,1}) do hardware('RingYoke',Vector3.new(.18,.8,.25),CFrame.new(side*.8,.28,.6),pale,metal) end
  elseif role=='Starforge' then
   -- A vertical furnace, chimney and radial cooling plates contrast the wide tools.
   hardware('Furnace',Vector3.new(1.45,.82,.82),CFrame.new(0,.95,0)*CFrame.Angles(0,0,math.pi/2),dark,metal,Enum.PartType.Cylinder)
   hardware('SolarCore',Vector3.one*.64,CFrame.new(0,1.72,0),color,Enum.Material.Neon,Enum.PartType.Ball,'FurnaceCore')
   hardware('ChimneyCap',Vector3.new(.16,1.05,1.05),CFrame.new(0,2.06,0)*CFrame.Angles(0,0,math.pi/2),pale,metal,Enum.PartType.Cylinder,'FurnaceCap')
   for i=1,4 do
    local angle=i*math.pi/2
    hardware('RadiatorFin',Vector3.new(.15,1.15,.78),CFrame.new(math.cos(angle)*.66,.87,math.sin(angle)*.66)*CFrame.Angles(0,-angle,0),color,metal,nil,'HeatFin',i)
   end
   hardware('SlagNozzle',Vector3.new(.4,.55,.4),CFrame.new(0,-.65,0),pale,metal,nil,'Nozzle')
  elseif role=='Frostbite' then
   -- Long cold tanks, rear caps and forward needle nozzles read as a low sled.
   for _,side in ipairs({-1,1}) do
    local tank=hardware('CryoTank',Vector3.new(2.65,.58,.58),CFrame.new(side*1.12,.05,0)*CFrame.Angles(0,math.pi/2,0),color,Enum.Material.Glass,Enum.PartType.Cylinder,'CryoTank',side)
    tank.Transparency=.18
    for _,endSide in ipairs({-1,1}) do hardware('TankCap',Vector3.new(.14,.66,.66),CFrame.new(side*1.12,.05,endSide*1.31)*CFrame.Angles(0,math.pi/2,0),pale,metal,Enum.PartType.Cylinder,'CryoTank',side) end
    hardware('CryoNeedle',Vector3.new(.18,.18,.75),CFrame.new(side*1.12,-.1,-1.7),dark,metal,nil,'CryoNozzle',side)
    for z=-1,1 do hardware('CoolingFin',Vector3.new(.75,.12,.14),CFrame.new(side*1.12,.46,z*.73),dark,metal) end
   end
  else
   -- Three actual U-shaped tuning forks: a tall, thin comb in silhouette.
   for i=-1,1 do
    local height=i==0 and 1.9 or 1.35
    hardware('ForkStem',Vector3.new(.14,.55,.18),CFrame.new(i*.94,.54,0),dark,metal,nil,'Fork',i)
    hardware('ForkHeel',Vector3.new(.58,.15,.2),CFrame.new(i*.94,.87,0),pale,metal,nil,'Fork',i)
    for _,side in ipairs({-1,1}) do hardware('TuningProng',Vector3.new(.12,height,.2),CFrame.new(i*.94+side*.23,.87+height*.5,0),color,metal,nil,'Prong',i*3+side) end
   end
  end
  model:SetAttribute('RoleGeometry',role);return model,body,emitter and emitter:IsA('BasePart') and emitter or nil
 end
 if role=='Needler' then
  local hull=hardware('DartHull',Vector3.new(1.5,.48,1.75),CFrame.new(),painted,slate)
  shotMuzzle(hull,Vector3.new(0,.08,-1.73)*scale)
  for _,side in ipairs({-1,1}) do
   hardware('DartRail',Vector3.new(.26,.29,1.5),CFrame.new(side*.52,.07,-.79),dark,metal,nil,'DartSlide')
   hardware('DartTip',Vector3.new(.21,.20,.34),CFrame.new(side*.52,.07,-1.55),pale,smooth,nil,'DartSlide')
  end
  hardware('RailCover',Vector3.new(1.24,.10,.38),CFrame.new(0,.28,.27),pale,smooth)
 elseif role=='Ballcaster' then
  pod('CoilHull',1.88,.58,0,painted,slate)
  local ring=hardware('LaunchRing',Vector3.new(.24,1.28,1.28),CFrame.new(0,.14,-.96)*foreAft,dark,metal,cylinder,'BallSlide')
  shotMuzzle(ring,Vector3.new(.16,0,0)*scale)
  hardware('CoilFace',Vector3.new(.10,.94,.94),CFrame.new(0,.14,-1.10)*foreAft,pale,smooth,cylinder,'BallSlide')
  hardware('LoadedOrb',Vector3.one*.62,CFrame.new(0,.14,-1.24),color,Enum.Material.Neon,Enum.PartType.Ball,'BallReload')
 elseif role=='Vacuum' then
  pod('VacuumHousing',1.82,.57,.03,painted,slate)
  hardware('WideIntake',Vector3.new(.30,1.46,1.46),CFrame.new(0,-.46,0)*vertical,dark,metal,cylinder,'Intake')
  hardware('IntakeGlow',Vector3.new(.12,.80,.80),CFrame.new(0,-.62,0)*vertical,color,Enum.Material.Neon,cylinder,'Intake')
  for _,side in ipairs({-1,1}) do
   hardware('SuctionCanister',Vector3.new(1.34,.52,.52),CFrame.new(side*.94,.22,0)*foreAft,pale,smooth,cylinder,'Canister',side)
  end
 elseif role=='Compactor' then
  hardware('PressHull',Vector3.new(1.9,.56,1.62),CFrame.new(),painted,slate)
  hardware('PressCap',Vector3.new(1.43,.20,1.23),CFrame.new(0,.32,0),pale,smooth)
  hardware('PressIntake',Vector3.new(.19,.95,.95),CFrame.new(0,-.45,0)*vertical,dark,metal,cylinder)
  hardware('PressIndicator',Vector3.new(.09,.57,.57),CFrame.new(0,-.56,0)*vertical,color,Enum.Material.Neon,cylinder)
  for i,position in ipairs(DroneConfig.PressSockets) do
   hardware('PressSocket'..i,Vector3.new(.13,.63,.63),CFrame.new(position-Vector3.yAxis*.28)*vertical,dark,metal)
  end
  for _,side in ipairs({-1,1}) do
   hardware('PressRail',Vector3.new(.27,.91,1.52),CFrame.new(side*.93,-.21,0),dark,metal)
   hardware('PressJaw',Vector3.new(.27,.25,1.31),CFrame.new(side*.76,-.73,0),pale,metal,nil,'PressJaw',side)
   hardware('PressFoot',Vector3.new(.39,.33,1.22),CFrame.new(side*.97,-.49,0),pale,metal,nil,'PressFoot',side)
  end
 elseif role=='Striker' then
  pod('RoundMinerHull',2.12,.48,.05,painted,slate)
  pod('ShoulderRing',1.99,.16,-.26,dark,metal)
  pod('CeramicNoseCap',1.47,.20,.38,pale,smooth)
  local underside=Vector3.new(0,-body.Size.Y/(2*scale),0)
  pod('OpticCollar',.82,.20,math.min(-.37,underside.Y+.12),dark,metal)
  lens('MiningOptic',Vector3.new(underside.X,math.min(-.49,underside.Y),underside.Z),color,.32)
  for _,side in ipairs({-1,1}) do
   hardware('SideVent',Vector3.new(.32,.23,.66),CFrame.new(side*.91,.07,.15),dark,metal)
  end
 elseif role=='Dart' then
  hardware('SeedDartHull',Vector3.new(1.02,.54,2.4),CFrame.new(0,.14,-.09)*CFrame.Angles(0,math.pi,0),painted,slate,nil,nil,nil,true)
  hardware('SeederKeel',Vector3.new(.76,.22,1.91),CFrame.new(0,-.22,.03),dark,metal)
  for _,side in ipairs({-1,1}) do
   hardware('MineralSeeder',Vector3.new(1.34,.40,.40),CFrame.new(side*.58,-.08,.14)*foreAft,pale,metal,cylinder,'Seeder',side)
  end
  lens('SeedOutlet',Vector3.new(0,-.40,-.31),color,.23)
 elseif role=='Charger' then
  hardware('RamCylinder',Vector3.new(2.15,1.27,1.27),CFrame.new(0,.01,0)*foreAft,painted,slate,cylinder)
  hardware('ForgedRamFace',Vector3.new(.30,1.32,1.32),CFrame.new(0,.01,-1.09)*foreAft,dark,metal,cylinder)
  hardware('RamCap',Vector3.new(.12,.93,.93),CFrame.new(0,.01,-1.29)*foreAft,color,smooth,cylinder)
  for _,side in ipairs({-1,1}) do
   hardware('ImpactDrum',Vector3.new(.72,.74,.74),CFrame.new(side*.79,-.08,.32),dark,metal,cylinder)
  end
 elseif role=='Orbiter' then
  pod('RelayUndercarriage',1.31,.52,-.10,dark,metal)
  hardware('FocusingMast',Vector3.new(.20,.76,.20),CFrame.new(0,.34,0),dark,metal)
  local dish=CFrame.new(0,.81,0)*CFrame.Angles(.26,0,-.17)*vertical
  hardware('ReceiverDish',Vector3.new(.22,2.39,2.39),dish,painted,slate,cylinder)
  hardware('DishInlay',Vector3.new(.12,1.99,1.99),dish*CFrame.new(.15,0,0),pale,smooth,cylinder)
  hardware('OrbitalLens',Vector3.new(.23,.66,.66),dish*CFrame.new(.28,0,0),color,smooth,cylinder)
  for _,side in ipairs({-1,1}) do
   hardware('RelayWing',Vector3.new(.88,.11,.55),CFrame.new(side*.89,-.12,.29)*CFrame.Angles(0,0,side*.13),dark,metal)
  end
 elseif role=='Scrapper' then
  hardware('FabricatorYoke',Vector3.new(2.06,.24,.56),CFrame.new(0,.13,.37),painted,slate)
  for _,side in ipairs({-1,1}) do
   hardware('MiniDroneBay',Vector3.new(1.47,.66,.66),CFrame.new(side*.62,.03,-.07)*foreAft,dark,metal,cylinder)
   hardware('BayLatch',Vector3.new(.13,.69,.69),CFrame.new(side*.62,.03,-.79)*foreAft,painted,slate,cylinder)
   hardware('BayMouth',Vector3.new(.09,.41,.41),CFrame.new(side*.62,.03,-.87)*foreAft,Color3.fromRGB(41,46,39),smooth,cylinder)
  end
  lens('FabricatorIndicator',Vector3.new(0,.33,.35),color,.26)
 elseif role=='Medic' then
  pod('RepairDisc',1.51,.24,.01,dark,metal)
  pod('CeramicCover',1.32,.20,.20,pale,smooth)
  hardware('RepairCrossA',Vector3.new(.76,.06,.21),CFrame.new(0,.33,0),color,smooth)
  hardware('RepairCrossB',Vector3.new(.21,.06,.76),CFrame.new(0,.33,0),color,smooth)
  lens('RepairOutlet',Vector3.new(0,-.29,0),color,.28)
 elseif role=='Courier' then
  hardware('ParcelSling',Vector3.new(1.05,.20,1.36),CFrame.new(0,-.38,0),painted,slate)
  hardware('FrontKeel',Vector3.new(.91,.38,1.04),CFrame.new(0,-.07,-.27),painted,slate,nil,nil,nil,true)
  for _,side in ipairs({-1,1}) do
   hardware('LiftDrum',Vector3.new(.75,.48,.48),CFrame.new(side*.81,.09,0)*vertical,dark,metal,cylinder)
   hardware('LiftDrumCap',Vector3.new(.13,.52,.52),CFrame.new(side*.81,.52,0)*vertical,pale,smooth,cylinder)
   hardware('ParcelRail',Vector3.new(.13,.16,1.31),CFrame.new(side*.52,-.22,.05),dark,metal)
  end
  lens('ParcelIndicator',Vector3.new(0,-.49,.35),color,.22)
 end
 if (role=='Medic' or role=='Courier') and emitter and emitter:IsA('BasePart') then
  emitter.Size=Vector3.one*.18*scale;emitter.CFrame=pose*CFrame.new(0,(role=='Medic' and -.20 or -.5)*scale,0)
 end
 model:SetAttribute('RoleGeometry',role)
 return model,body,emitter and emitter:IsA('BasePart') and emitter or nil
end

-- Equipment drops are rolled by the saved consumable rules, not timed buffs.
DroneConfig.Discoveries = {
 PickupLifetime = 30,
 CollectDistance = 7,
}

-- Active mining plots: preserve crystal geometry while scaling durability by tier.
DroneConfig.Mining = {
 BackpackRange = 70,
 -- Health/work is authored in Config.Fields.Hardness and Mining.resource.
 -- This table owns only the live crew-responsive respawn tuning.
 RespawnRateBase = 1.10,
 RespawnRatePerDrone = .025,
 RespawnRateMaximum = 1.50,
}

return table.freeze(DroneConfig)


end)()
local DroneRoleEffects = (function()
-- Server-owned effect receipts only. No cosmetic Parts, tweens or animation.
-- Persistent active records let every observer (including late joiners) render
-- the same effect from server time, without trusting clients with gameplay.
local Debris=game:GetService('Debris')
local Effects={}
local live=0
local MAX_LIVE=256
local markers,burns,swarms={},{},{}
local function folder()
 local root=workspace:FindFirstChild('DroneRoleState')
 if not root then root=Instance.new('Folder');root.Name='DroneRoleState';root.Parent=workspace end
 return root
end
local function record(kind,attributes,lifetime)
 if live>=MAX_LIVE then return nil end
 local node=Instance.new('Folder');node.Name=kind
 node:SetAttribute('Kind',kind);node:SetAttribute('StartedAt',workspace:GetServerTimeNow())
 for key,value in pairs(attributes) do node:SetAttribute(key,value) end
 if lifetime then node:SetAttribute('ExpiresAt',workspace:GetServerTimeNow()+lifetime);Debris:AddItem(node,lifetime) end
 live+=1;node.Destroying:Connect(function() live-=1 end)
 node.Parent=folder();return node
end
local function clear(map,owner)
 local old=map[owner];map[owner]=nil;if old then old:Destroy() end
end
local function point(p) return Vector3.new(p.x,p.y,p.z) end
function Effects.Beam(from,to,color,width,lifetime)
 record('Beam',{From=from,Position=to,Color=color,Width=width or .18,Duration=lifetime or .16},(lifetime or .16)+.85)
end
function Effects.Pulse(position,color,first,last,lifetime)
 record('Pulse',{Position=position,Color=color,First=first or .8,Last=last or 5,Duration=lifetime or .3},(lifetime or .3)+.2)
end
function Effects.Projectile(shape,from,to,color,startedAt,flight,actor,target,anchor)
 return record('MiningShot',{Shape=shape,From=from,Position=to,Color=color,StartedAt=startedAt,Duration=flight,Actor=actor,TargetId=target,TargetAnchor=anchor},4)
end
function Effects.Heal(from,to)
 record('Heal',{From=from,Position=to},.4)
end
function Effects.Charge(position,target,impact)
 record('Charge',{From=position,Position=target,Impact=impact==true},1)
end
function Effects.Grow(from,target,planted)
 record('Grow',{From=from,Position=target,Planted=planted},1.8)
end
function Effects.BreakerPhase(position,target,phase,diameter)
 record('Breaker',{From=position,Position=target,Phase=phase,Diameter=diameter},1.8)
end
local function endBurn(owner)
 local old=burns[owner];burns[owner]=nil
 if old and old.Parent then old:SetAttribute('EndedAt',workspace:GetServerTimeNow());Debris:AddItem(old,4.4) end
end
local function watchBurn(owner,node)
 task.delay(8,function()
  if not node.Parent or node:GetAttribute('EndedAt') then return end
  if workspace:GetServerTimeNow()-(node:GetAttribute('ContactAt') or 0)<8 then watchBurn(owner,node)
  elseif burns[owner]==node then endBurn(owner) end
 end)
end
function Effects.ClearAbility(owner)
 clear(swarms,owner);clear(markers,owner);endBurn(owner)
end
function Effects.Ability(owner,event,template)
 local kind=event.kind;local now=workspace:GetServerTimeNow()
 if kind=='clear' then Effects.ClearAbility(owner)
 elseif kind=='clearCharge' then clear(markers,owner)
 elseif kind=='clearScrap' then clear(swarms,owner)
 elseif kind=='orbitalEnd' then endBurn(owner)
 elseif kind=='charge' then
  clear(markers,owner)
  local duration=event.duration or 1.4
  markers[owner]=record('AbilityCharge',{Owner=owner,Ability=event.ability,Duration=duration,Position=point(event.target),Ground=event.target.ground,Radius=event.target.radius},duration+1.15)
 elseif kind=='orbital' then
  clear(markers,owner)
  local node=burns[owner]
  if not node or not node.Parent then
   node=record('Orbital',{Owner=owner,Position=point(event.target),Ground=event.target.ground,Radius=event.target.radius,ContactAt=now})
   burns[owner]=node;if not node then return end;watchBurn(owner,node)
  end
  -- ContactAt commits the complete sample. No replicated geometry moves.
  node:SetAttribute('Position',point(event.target));node:SetAttribute('ContactAt',now)
 elseif kind=='relay' or kind=='recycle' then
  record('AbilityPulse',{Owner=owner,Ability=kind,Position=point(event.target)},.6)
 elseif kind=='scrapStart' then clear(markers,owner)
 elseif kind=='scrapPose' then
  local group=swarms[owner]
  if not group or not group.Parent then
   if not template then return end
   group=record('ScrapSwarm',{Owner=owner,ScrapSwarm=true},13);if not group then return end
   local ref=Instance.new('ObjectValue');ref.Name='Template';ref.Value=template;ref.Parent=group
   swarms[owner]=group
  end
  group:SetAttribute('Expires',event.expires)
  for index,bot in ipairs(event.bots) do
   if index>6 then break end
   local name='ScrapBot_'..bot.id;local node=group:FindFirstChild(name)
   if not node then node=Instance.new('Folder');node.Name=name;node:SetAttribute('ScrapBot',true);node.Parent=group end
   node:SetAttribute('Position',point(bot));node:SetAttribute('Active',bot.active)
   node:SetAttribute('TargetPosition',bot.target and point(bot.target) or point(bot))
   node:SetAttribute('Pulse',bot.pulse);node:SetAttribute('PoseAt',now)
  end
 end
end
return Effects

end)()
local MiningDiscoveries = (function()
-- Server-owned equipment drops from the rock that actually broke. Collection
-- stores a tool; it never starts a boost or competes for ore backpack capacity.
local Players=game:GetService('Players')
local D={};D.__index=D
function D.new(parent,config,context)
 local container=Instance.new('Folder');container.Name='MiningDiscoveries';container.Parent=parent
 local self=setmetatable({container=container,config=config,context=context,states={},random=Random.new(),nextStep=0},D)
 self.connection=Players.PlayerRemoving:Connect(function(player) self:Clear(player) end)
 return self
end
function D:Clear(player)
 local state=self.states[player];if state then state.part:Destroy();self.states[player]=nil end
end
-- Compatibility for preserved controller callers. Discoveries no longer alter
-- damage or currency, including while a stored item is selected.
function D:Multiplier(_player,_kind) return 1 end
function D:TrySpawn(player,field,position,tier)
 local ctx=self.context(player)
 if not ctx or self.states[player] or not ctx.roll then return end
 local kind,definition=ctx.roll(tier,self.random:NextNumber(),self.random:NextNumber())
 if not kind then return end
 local now=workspace:GetServerTimeNow()
 local ground=position or field.Position+Vector3.new(0,field.Size.Y*.5,0)
 local color=Color3.fromRGB(table.unpack(definition.color))
 local part=Instance.new('Part');part.Name=kind..'Capsule';part.Size=Vector3.new(1.25,1.05,.85)
 part.Material=Enum.Material.Metal;part.Color=color;part.Anchored=true
 part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Position=ground+Vector3.new(0,.65,0)
 part:SetAttribute('OwnerUserId',player.UserId);part:SetAttribute('ConsumableKind',kind)
 part:SetAttribute('ExpiresAt',now+self.config.PickupLifetime)
 local label=Instance.new('BillboardGui');label.Name='ToolName';label.Size=UDim2.fromOffset(150,26)
 label.StudsOffsetWorldSpace=Vector3.new(0,1.5,0);label.MaxDistance=36;label.AlwaysOnTop=false;label.Parent=part
 local text=Instance.new('TextLabel');text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=.22
 text.BackgroundColor3=Color3.fromRGB(27,32,43);text.TextColor3=color;text.Font=Enum.Font.SourceSansBold;text.TextSize=16
 text.Text=definition.name;text.Parent=label
 local edge=Instance.new('UICorner');edge.CornerRadius=UDim.new(0,5);edge.Parent=text
 -- One small physical case per owner; the bright inset distinguishes equipment
 -- from the existing mineral fragments without adding an effect cloud.
 local lens=Instance.new('Part');lens.Name='Lens';lens.Size=Vector3.new(.7,.12,.48);lens.Material=Enum.Material.Neon
 lens.Color=color;lens.Anchored=true;lens.CanCollide=false;lens.CanTouch=false;lens.CanQuery=false;lens.CastShadow=false
 lens.Position=part.Position+Vector3.new(0,.58,0);lens.Parent=part
 self.states[player]={part=part,lens=lens,origin=ground,kind=kind,name=definition.name,runId=ctx.runId,started=now,expires=now+self.config.PickupLifetime}
 part.Parent=self.container
 player:SetAttribute('MA_Notice',definition.name..' dropped! Walk over to store it in your tools pocket.')
end
function D:Step()
 local now=workspace:GetServerTimeNow();if now<self.nextStep then return end;self.nextStep=now+.1
 for player,state in pairs(self.states) do
  local ctx=self.context(player)
  if not player.Parent or now>=state.expires or (ctx and ctx.runId~=state.runId) then self:Clear(player)
  else
   local age=now-state.started
   local lift=age<.6 and (math.sin(age/.6*math.pi)*1.8) or math.sin(age*2)*.12
   state.part.Position=state.origin+Vector3.new(0,.65+lift,0);state.lens.Position=state.part.Position+Vector3.new(0,.58,0)
   local fade=math.clamp((now-state.expires+5)/5,0,1);state.part.Transparency=fade;state.lens.Transparency=fade
   if ctx and age>=.6 and (ctx.root.Position-state.part.Position).Magnitude<=self.config.CollectDistance
    and (not ctx.clearPath or ctx.clearPath(state.part.Position,state.part)) and ctx.collect and ctx.collect(state.kind) then
    self:Clear(player)
    player:SetAttribute('MA_Notice',state.name..' stored. Select its tools pocket, then place it in a field.')
   end
  end
 end
end
function D:Destroy()
 self.connection:Disconnect()
 for player in pairs(self.states) do self:Clear(player) end
 self.container:Destroy()
end
return D

end)()
local MapLayout = (function()
-- Pure, deterministic terrain and route plan. No Roblox instances or gameplay state.
-- Coordinates use the original spawn (-56,.5,-11); the complete plan follows it.
local L={Scale=1.9,FieldScale=1.4,Cell=8,Origin={-128,-104},Columns=26,Rows=26}
L.Routes={
 {name='Quartz approach',width=12,points={{-44,.34,-2},{-37,1.64,6},{-37,1.64,12}}},
 {name='Converter lane',width=10,points={{-66,.34,-24},{-78,.34,-29},{-85,.34,-29}}},
 {name='Ruby switchback',width=11,points={{-69,.34,1},{-85,5,10},{-107,9,18},{-107,13.14,26},{-107,13.14,34},{-99,13.14,34}}},
 {name='Grove loop',width=10,points={{-37,1.64,37},{-43,5.5,43},{-49,5.5,49},{-55,5.5,55},{-65,13.14,55},{-70,13.14,51},{-78,13.14,51}}},
 {name='Cobalt ascent',width=12,points={{-43,.34,-23},{-26,6,-32},{-24,12,-57},{-30,20.14,-74},{-43,20.14,-74}}},
 {name='High pass',width=11,points={{-55,20.14,-76},{-55,20.14,-85},{-31,24,-89},{-11,28,-86},{-10,30.14,-74},{-10,30.14,-65}}},
 {name='Emerald traverse',width=11,points={{13,30.14,-47},{28,33,-40},{42,36,-32},{44,40.14,-19},{44,40.14,-8}}},
 {name='Fern stair',width=11,points={{25,40.14,18},{25,40.14,29},{8,33,41},{-1,24,56},{-20,14,62},{-34,8,60},{-43,5.5,53},{-49,5.5,49}}},
 {name='Ruby overlook',width=9,points={{-101,13.14,56},{-112,20,67},{-100,27,78},{-79,34,77},{-66,34,77}}},
}
-- Forests are authored clusters, not a uniform scatter. The tall Ruby trees
-- surround the whole clearing and continue up the cliff's stepped shoulders.
L.Trees={
 {-116,32,27,2},{-117,47,30,2},{-112,57,24,2},{-106,69,28,2},{-98,71,30,2},
 {-82,68,25,2},{-72,68,29,2},{-65,45,28,2},{-67,32,24,2},{-82,21,23,2},
 {-96,22,28,2},{-115,16,24,2},{-122,65,29,2},{-114,80,27,2},{-96,89,25,2},{-75,89,29,2},
 {-49,26,15,1},{-53,38,19,1},{-45,6,17,1},{-21,0,17,1},{-5,14,20,1},{-1,31,16,1},
 {-12,47,18,1},{-34,65,20,1},{-49,66,16,1},{-67,14,15,1},{-78,-4,20,1},{-97,-8,21,1},
 {-105,-27,24,1},{-110,-44,19,1},{-95,-49,22,3},{-82,-67,23,3},{-80,-84,26,3},
 {-66,-88,22,3},{-48,-89,25,3},{-30,-91,20,3},{-22,-59,18,3},{-31,-21,18,3},
 {-16,-89,24,4},{2,-83,23,4},{20,-77,28,4},{25,-58,22,4},{-22,-35,20,4},{-7,-29,18,4},
 {34,-62,27,4},{48,-49,22,4},{58,-28,27,5},{66,-9,28,5},{62,13,24,5},
 {52,32,28,5},{34,32,25,5},{20,38,26,5},{13,54,24,5},{-2,67,20,5},
 {-109,-65,24,3},{-96,-88,23,3},{40,-87,24,4},{60,-67,26,4},{68,47,26,5},
 {-118,-1,22,1},{-111,0,18,1},{-11,77,21,1},{-46,82,19,2},{-61,86,26,2},
}
local function distance(x,z,a,b)
 local dx,dz=b[1]-a[1],b[3]-a[3]
 local t=math.clamp(((x-a[1])*dx+(z-a[3])*dz)/(dx*dx+dz*dz),0,1)
 local px,pz=a[1]+dx*t,a[3]+dz*t
 return math.sqrt((x-px)^2+(z-pz)^2),a[2]+(b[2]-a[2])*t
end
L.distance=distance
-- Round the horizontal AND vertical bend together. Straight overlapping slabs
-- and large flat joint discs create a raised lip; these short smooth chords do not.
function L.rounded(route)
 local result={route.points[1]}
 local function mix(a,b,t) return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t} end
 for i=2,#route.points-1 do
  local a,b,c=route.points[i-1],route.points[i],route.points[i+1]
  local la=math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2)
  local lc=math.sqrt((c[1]-b[1])^2+(c[3]-b[3])^2)
  local trim=math.min(route.width*.75,la*.28,lc*.28)
  local entry,exit=mix(b,a,trim/la),mix(b,c,trim/lc)
  table.insert(result,entry)
  for n=1,6 do local t=n/6;table.insert(result,mix(mix(entry,b,t),mix(b,exit,t),t)) end
 end
 table.insert(result,route.points[#route.points])
 return result
end
function L.plan(config: any,home: any): any
 home=home or {-56,.5,-11}
 local dx,dy,dz=home[1]+56,home[2]-.5,home[3]+11
 local p={fields={},routes={},terrain={},cells={},trees={},dx=dx,dy=dy,dz=dz}
 function p:point(x: number,z: number) return -56+(x+56)*L.Scale+dx,-11+(z+11)*L.Scale+dz end
 function p:biomePoint(id: number,x: number,z: number)
  local f=self.fields[id];local base=config[id].Offset
  local ox,oz=-56+base[1]/L.Scale,-11+base[3]/L.Scale
  return f.x+(x-ox)*L.FieldScale,f.z+(z-oz)*L.FieldScale
 end
 function p:hubClear(x,z,radius)
  local rx,rz=50+(radius or 0),46+(radius or 0)
  return ((x-home[1])/rx)^2+((z-home[3])/rz)^2>=1
 end
 for _,f in ipairs(config) do
  table.insert(p.fields,{x=home[1]+f.Offset[1],y=home[2]+f.Offset[2],z=home[3]+f.Offset[3],w=f.Size[1],d=f.Size[3],top=home[2]+f.Offset[2]+f.Size[2]/2})
 end
 for _,r in ipairs(L.Routes) do
  local route={name=r.name,width=r.width*1.2,points={}}
  for _,v in ipairs(r.points) do
   local x,z=p:point(v[1],v[3])
   -- Preserve a full-height connection into resized fields at route endpoints.
   for id,f in ipairs(config) do
    local fx,fz=-56+f.Offset[1]/L.Scale,-11+f.Offset[3]/L.Scale
    if math.abs(v[1]-fx)<f.Size[1]/L.FieldScale/2 and math.abs(v[3]-fz)<f.Size[3]/L.FieldScale/2 then x,z=p:biomePoint(id,v[1],v[3]);break end
   end
   table.insert(route.points,{x,v[2]+dy,z})
  end
  route.samples=L.rounded(route)
  table.insert(p.routes,route)
 end
 function p:routeClear(x,z,radius)
  for _,r in ipairs(self.routes) do for i=1,#r.samples-1 do
   if distance(x,z,r.samples[i],r.samples[i+1])<r.width/2+radius then return false end
  end end
  return true
 end
 function p:fieldClear(x,z,radius)
  for _,f in ipairs(self.fields) do if math.abs(x-f.x)<f.w/2+radius and math.abs(z-f.z)<f.d/2+radius then return false end end
  return true
 end
 local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
 local function mound(x,z,cx,cz,rx,rz,h)
  local d=math.sqrt(((x-cx)/rx)^2+((z-cz)/rz)^2)
  return h*(1-smooth((d-.15)/.85))
 end
 local function height(x,z)
  local h=math.max(
   mound(x,z,-99,78,37,31,51),mound(x,z,-117,47,21,39,30),mound(x,z,-73,86,22,23,40),
   mound(x,z,-64,-79,47,38,36),mound(x,z,-92,-86,24,25,47),
   mound(x,z,14,-86,47,35,58),mound(x,z,-3,-55,37,38,35),
   mound(x,z,57,-18,35,53,49),mound(x,z,35,12,39,37,43),mound(x,z,10,38,32,37,28))
  -- Small broad undulations break up regular silhouettes without noisy spikes.
  h=math.max(0,h+(math.sin(x*.089+z*.047)*2.8+math.cos(z*.13-x*.04)*1.8)*math.min(1,h/12))
  local edge=math.min(x-L.Origin[1],L.Origin[1]+L.Columns*L.Cell-x,z-L.Origin[2],L.Origin[2]+L.Rows*L.Cell-z)
  return h*smooth(edge/14)
 end
 local step=L.Cell*L.Scale
 local radius=step*math.sqrt(2)
 local vertices={}
 local function vertex(ix,iz) return vertices[iz*(L.Columns+1)+ix+1] end
 for iz=0,L.Rows do for ix=0,L.Columns do
  local rawX,rawZ=L.Origin[1]+ix*L.Cell,L.Origin[2]+iz*L.Cell
  local x,z=p:point(rawX,rawZ);local h=height(rawX,rawZ)+dy
  -- Broad level field shoulders give way to forested slopes, then outer cliffs.
  local nearest,biome=math.huge,1
  for id,f in ipairs(p.fields) do
   local fieldDistance=math.max(math.abs(x-f.x)-f.w/2,math.abs(z-f.z)-f.d/2,0)
   if fieldDistance<nearest then nearest=fieldDistance;biome=id end
   if fieldDistance<28 then
    local mix=smooth(fieldDistance/28)
    h=h*mix+math.max(0,f.top-2.1)*(1-mix)
   end
   -- Entire triangles that touch a clearing stay below its ore surface.
   if math.abs(x-f.x)<f.w/2+step+2 and math.abs(z-f.z)<f.d/2+step+2 then h=math.min(h,f.top-2.1) end
  end
  -- Conservative vertex clearance also clears triangle interiors between vertices.
  for _,r in ipairs(p.routes) do for i=1,#r.samples-1 do
   local d,y=distance(x,z,r.samples[i],r.samples[i+1])
   if d<r.width/2+radius+2 then
    local a,b=r.samples[i],r.samples[i+1]
    local gradient=math.abs(b[2]-a[2])/math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2)
    h=math.min(h,y-radius*gradient-.55)
   end
  end end
  if not p:hubClear(x,z,radius) then h=0 end
  if math.abs(x-(-86+dx))<12+radius and math.abs(z-(-37.5+dz))<12+radius then h=0 end
  local mx,mz=p:biomePoint(2,-88,66)
  if math.abs(x-mx)<12+step and math.abs(z-mz)<9+step then h=math.min(h,12.5+dy) end
  vertices[iz*(L.Columns+1)+ix+1]={x,math.max(0,h),z,biome}
 end end
 p.vertices=vertices
 for iz=0,L.Rows-1 do for ix=0,L.Columns-1 do
  local a,b,c,d=vertex(ix,iz),vertex(ix+1,iz),vertex(ix+1,iz+1),vertex(ix,iz+1)
  local cell={a=a,b=b,c=c,d=d,alternate=(ix+iz)%2==1,h=math.max(a[2],b[2],c[2],d[2]),biome=a[4]}
  p.cells[iz*L.Columns+ix+1]=cell
  if cell.h>.05 then
   cell.faces=cell.alternate and {{a,b,c},{a,c,d}} or {{a,b,d},{b,c,d}}
   table.insert(p.terrain,cell)
  end
 end end
 function p:surface(x: number,z: number)
  local ox,oz=self:point(L.Origin[1],L.Origin[2])
  local ix,iz=math.floor((x-ox)/step),math.floor((z-oz)/step)
  if ix<0 or ix>=L.Columns or iz<0 or iz>=L.Rows then return 0 end
  local c=self.cells[iz*L.Columns+ix+1]
  local u,v=(x-ox)/step-ix,(z-oz)/step-iz
  local a,b,d,e=c.a[2],c.b[2],c.c[2],c.d[2]
  if c.alternate then
   if v<=u then return a+(b-a)*(u-v)+(d-a)*v end
   return a+(d-a)*u+(e-a)*(v-u)
  end
  if u+v<=1 then return a+(b-a)*u+(e-a)*v end
  return d+(e-d)*(1-u)+(b-d)*(1-v)
 end
 -- Rock faces are short irregular clusters, never global horizontal bands.
 p.rocks={}
 for i,r in ipairs({{-119,72,16,11,12,17},{-99,91,22,14,15,-11},{-69,88,15,18,14,24},
  {-94,-86,21,14,17,-13},{-64,-99,24,12,15,19},{8,-95,23,18,17,-16},
  {39,-81,18,12,16,26},{60,-63,16,17,13,-19},{70,-16,15,18,17,12},{58,40,20,13,14,-23}}) do
  local x,z=p:point(r[1],r[2]);local clearance=math.sqrt(r[3]^2+r[5]^2)/2+2
  if p:hubClear(x,z,clearance) and p:routeClear(x,z,clearance) and p:fieldClear(x,z,clearance) then
   table.insert(p.rocks,{x=x,z=z,y=p:surface(x,z),w=r[3],h=r[4],d=r[5],yaw=r[6],biome=i<=3 and 2 or 3})
  end
 end
 -- One continuous native meadow. A 4-stud terrain raster follows the same
 -- open-land mask as the dense mesh version, with no isolated lawn squares.
 p.grass={}
 local function grassHeight(x,z)
  if math.abs(x-home[1])<24 and math.abs(z-home[3])<21 then return nil end
  if not p:fieldClear(x,z,4) or not p:routeClear(x,z,3) then return nil end
  local near=(x-home[1])^2+(z-home[3])^2<90^2
  for _,f in ipairs(p.fields) do
   if math.abs(x-f.x)<f.w/2+38 and math.abs(z-f.z)<f.d/2+38 then near=true;break end
  end
  if not near then return nil end
  local h=p:surface(x,z)
  local slope=math.max(math.abs(p:surface(x+.75,z)-h),math.abs(p:surface(x-.75,z)-h),math.abs(p:surface(x,z+.75)-h),math.abs(p:surface(x,z-.75)-h))
  if slope>.55 then return nil end
  return h
 end
 local ox,oz=p:point(L.Origin[1],L.Origin[2]);local edge=L.Columns*L.Cell*L.Scale
 for x=math.floor(ox/4)*4,ox+edge-4,4 do for z=math.floor(oz/4)*4,oz+edge-4,4 do
  local bx,bz=x+2,z+2;local h=grassHeight(bx,bz)
  if h then
   local tone=math.clamp(.45+.32*(math.sin(bx*.019+math.cos(bz*.011)*1.8)+math.cos(bz*.024-bx*.007)),0,1)
   local scatter=(math.sin(bx*17.13+bz*7.91)*43758.5453)%1
   -- Dry soil blends into grass, with grass blades retained across each band.
   local dry=scatter<math.max(0,tone-.55)*1.2
   table.insert(p.grass,{x=bx,z=bz,y=h,w=4,d=4,tone=tone,dry=dry})
  end
 end end
 for i,t in ipairs(L.Trees) do
  local x,z=p:biomePoint(t[4],t[1],t[2])
  if p:hubClear(x,z,t[3]*.3) and p:routeClear(x,z,3) and p:fieldClear(x,z,t[3]*.27) then
   table.insert(p.trees,{x=x,z=z,h=t[3],biome=t[4],ground=p:surface(x,z),yaw=i*.73})
  end
 end
 return p
end
return L


end)()
local HarborLighting = (function()
-- Exact Lighting settings captured read-only from Alabaster Harbor, place 11490608035.
local H={}
H.SourcePlaceId=11490608035
H.settings={
 ["Ambient"]=Color3.new(1,0.9294118285179138,0.7529412508010864),
 ["Brightness"]=2,
 ["ClockTime"]=7,
 ["ColorShift_Bottom"]=Color3.new(0,0,0),
 ["ColorShift_Top"]=Color3.new(0.4274509847164154,0.32156863808631897,0),
 ["EnvironmentDiffuseScale"]=0.699999988079071,
 ["EnvironmentSpecularScale"]=0.6290000081062317,
 ["ExposureCompensation"]=0.30000001192092896,
 ["FogColor"]=Color3.new(0.7960785031318665,0.7725490927696228,0.7176470756530762),
 ["FogEnd"]=1000000,
 ["FogStart"]=0,
 ["GeographicLatitude"]=360,
 ["GlobalShadows"]=true,
 ["LightingStyle"]=Enum.LightingStyle.Realistic,
 ["OutdoorAmbient"]=Color3.new(0.5764706134796143,0.4274509847164154,0),
 ["Outlines"]=false,
 ["PrioritizeLightingQuality"]=true,
 ["ShadowColor"]=Color3.new(0.699999988079071,0.699999988079071,0.7200000286102295),
 ["ShadowSoftness"]=0.6000000238418579,
 ["TimeOfDay"]="07:00:00",
}
function H.apply()
 local lighting=game:GetService('Lighting')
 local template=game:GetService('ServerStorage'):FindFirstChild('AlabasterHarborLighting')
 assert(template,'Missing native Alabaster Harbor Lighting export in build')
 -- The template includes every original child, including the inactive lowPolyUI.
 -- Cloning preserves the authored sky/effects and all nested property values.
 for _,child in ipairs(lighting:GetChildren()) do child:Destroy() end
 for _,child in ipairs(template:GetChildren()) do child:Clone().Parent=lighting end
 for property,value in pairs(H.settings) do
  -- LightingStyle/PrioritizeLightingQuality are persisted by the builder too;
  -- some engine versions restrict writing these rendering options at runtime.
  pcall(function() lighting[property]=value end)
 end
 lighting:SetAttribute('CopiedFromPlaceId',H.SourcePlaceId)
end
return H


end)()
local Daylight = (function()
-- Daylight fallback for the reference layout. The authored quarry stores its
-- lighting in the native place so Edit and Play use the same sky and grade.
local Daylight = {}
function Daylight.apply()
 local authored = workspace:FindFirstChild('MiningAway')
 if authored and authored:GetAttribute('DronerevolutionMapVersion') then return end
 local lighting = game:GetService('Lighting')
 local storage=game:GetService('ServerStorage')
 local archive=storage:FindFirstChild('OriginalQuarrySky')
 if not archive then archive=Instance.new('Folder');archive.Name='OriginalQuarrySky';archive.Parent=storage end
 for _,child in ipairs(lighting:GetChildren()) do
  if child:IsA('Sky') and child.Name~='QuarryDaySky' then child.Parent=archive end
 end
 if not lighting:FindFirstChild('QuarryDaySky') then
  -- Engine-bundled blue/cloud sky: no external permission or texture download.
  local sky=Instance.new('Sky');sky.Name='QuarryDaySky';sky.StarCount=0
  sky.SunAngularSize=11;sky.MoonAngularSize=0;sky.Parent=lighting
 end
 if not lighting:FindFirstChildOfClass('Atmosphere') then
  local atmosphere=Instance.new('Atmosphere');atmosphere.Name='QuarryAir';atmosphere.Parent=lighting
 end
 lighting.ClockTime = 14
 lighting.GeographicLatitude = 35
 lighting.Brightness = 2
 lighting.ExposureCompensation = 0
 lighting.Ambient = Color3.fromRGB(112,122,132)
 lighting.OutdoorAmbient = Color3.fromRGB(153,163,167)
 lighting.ColorShift_Top = Color3.fromRGB(0,0,0)
 lighting.ColorShift_Bottom = Color3.fromRGB(0,0,0)
 lighting.EnvironmentDiffuseScale = .65
 lighting.EnvironmentSpecularScale = .12
 lighting.GlobalShadows = true
 lighting.ShadowSoftness = .35
 lighting.FogColor = Color3.fromRGB(185,217,234)
 lighting.FogStart = 600
 lighting.FogEnd = 2400
 -- Some Studio versions restrict render-path writes; the remaining settings
 -- still apply independently.
 pcall(function() lighting.LightingStyle = Enum.LightingStyle.Soft end)
 for _,effect in ipairs(lighting:GetChildren()) do
  if effect:IsA('BloomEffect') or effect:IsA('DepthOfFieldEffect')
   or effect:IsA('SunRaysEffect') or effect:IsA('BlurEffect') then
   effect.Enabled = false
  elseif effect:IsA('ColorCorrectionEffect') then
   effect.Enabled = true
   effect.Brightness = 0; effect.Contrast = .03; effect.Saturation = .02
   effect.TintColor = Color3.new(1,1,1)
  elseif effect:IsA('Atmosphere') then
   effect.Density = .19; effect.Offset = .18
   effect.Color = Color3.fromRGB(202,225,238)
   effect.Decay = Color3.fromRGB(129,171,187)
   effect.Glare = 0; effect.Haze = .6
  end
 end
end
return Daylight

end)()
local Facets = (function()
-- A continuous low-poly hillside made entirely from anchored WedgeParts.
-- Each triangle splits across its longest edge into two exact right triangles.
local F={}
function F.triangle(parent: any,a: any,b: any,c: any,color: any,finish: ((WedgePart) -> ())?)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
 elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local cross=ac:Cross(ab)
 if cross.Magnitude<.001 then return end
 local right=cross.Unit;local back=bc.Unit;local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 local function wedge(position,normal,axis,length)
  if length<.01 or height<.01 then return end
  local part=Instance.new('WedgePart');part.Name='GroundFacet';part.Anchored=true
  part.CanCollide=true;part.CanQuery=true;part.CanTouch=false
  part.Size=Vector3.new(.18,height+.04,length+.04);part.CFrame=CFrame.fromMatrix(position,normal,up,axis)
  part.Color=color;part.Material=Enum.Material.SmoothPlastic;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  if finish then finish(part) else part:SetAttribute('LandscapeSurface',true) end
  part.Parent=parent
 end
 wedge((a+b)/2,right,back,math.abs(ab:Dot(back)))
 wedge((a+c)/2,-right,-back,math.abs(ac:Dot(back)))
end
return F


end)()
local NativeMeadow = (function()
-- One-time native terrain planting. Roblox renders grass and wind internally.
local N={}
function N.build(plan,root)
 local terrain=workspace:FindFirstChildOfClass('Terrain')
 if not terrain then return end
 workspace.GlobalWind=Vector3.new(3.5,0,1.2)
 terrain:SetMaterialColor(Enum.Material.Grass,Color3.fromRGB(102,153,76))
 terrain:SetMaterialColor(Enum.Material.Ground,Color3.fromRGB(174,173,86))
 -- A one-voxel soil collar supports the smooth surface at meadow edges.
 -- Without it, empty neighbor columns pull grass roots two studs below slopes.
 local columns={};local occupied={}
 for _,cell in ipairs(plan.grass) do
  table.insert(columns,cell);occupied[cell.x..':'..cell.z]=true
 end
 for _,cell in ipairs(plan.grass) do for dx=-4,4,4 do for dz=-4,4,4 do
  local x,z=cell.x+dx,cell.z+dz;local key=x..':'..z
  if not occupied[key] then
   occupied[key]=true
   table.insert(columns,{x=x,z=z,y=plan:surface(x,z),dry=true,support=true})
  end
 end end end
 local groups={};local keys={}
 for _,cell in ipairs(columns) do
  local gx,gz=math.floor((cell.x-2)/32),math.floor((cell.z-2)/32)
  local key=gx..':'..gz;local group=groups[key]
  if not group then group={x=gx*32,z=gz*32,low=math.huge,high=-math.huge,cells={}};groups[key]=group;table.insert(keys,key) end
  table.insert(group.cells,cell)
  group.low=math.min(group.low,math.floor((cell.y-8)/4)*4)
  group.high=math.max(group.high,math.ceil((cell.y+4)/4)*4)
 end
 table.sort(keys)
 local dry=0
 for _,key in ipairs(keys) do
  local group=groups[key]
  local region=Region3.new(Vector3.new(group.x,group.low,group.z),Vector3.new(group.x+32,group.high,group.z+32))
  -- Read first: unplanted columns and unrelated authored terrain remain intact.
  local materials,occupancies=terrain:ReadVoxels(region,4)
  for _,cell in ipairs(group.cells) do
   local ix,iz=math.floor((cell.x-group.x)/4)+1,math.floor((cell.z-group.z)/4)+1
   -- Smooth terrain reconstructs the iso-surface half a voxel above
   -- this occupancy height. Compensate so the floor stays at plan + .25.
   local top=cell.y-1.75
   if cell.dry and not cell.support then dry+=1 end
   for iy=1,#materials[ix] do
    local bottom=group.low+(iy-1)*4
    if bottom>=cell.y-8 and bottom<top then
     materials[ix][iy][iz]=cell.dry and Enum.Material.Ground or Enum.Material.Grass
     occupancies[ix][iy][iz]=math.clamp((top-bottom)/4,0,1)
    end
   end
  end
  terrain:WriteVoxels(region,4,materials,occupancies)
  task.wait()
 end
 root:SetAttribute('GrassRenderer','Native terrain decoration')
 root:SetAttribute('NativeGrassCells',#plan.grass-dry)
 root:SetAttribute('DryMeadowCells',dry)
 root:SetAttribute('SkinnedGrassPatches',0)
end
return N


end)()
local World: any = (function()
-- Runtime map assembly around the original spawn, fields and Converter.
-- The source binary remains untouched. Authored assets are cloned, never rebuilt as boxes.
local W={}
function W.part(parent,name,pos,size,color,material)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.Size=size;p.Position=pos;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Parent=parent
 return p
end
function W.label(part,text,offset)
 -- Reserved for short contextual readouts; field identity uses grounded signs instead.
 local b=Instance.new('BillboardGui');b.Name='Readout';b.Size=UDim2.fromOffset(170,38);b.StudsOffset=offset or Vector3.new(0,4,0);b.AlwaysOnTop=false;b.MaxDistance=65;b.Parent=part
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=.15;t.BackgroundColor3=Color3.fromRGB(20,31,37);t.TextColor3=Color3.fromRGB(229,241,229);t.TextSize=13;t.Font=Enum.Font.GothamMedium;t.TextWrapped=true;t.Text=text;t.Parent=b
 return t
end
local function sanitize(model,query)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=query==true
  elseif v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Trail') then v.Enabled=false end
 end
end
W.sanitize=sanitize
function W.drone(parent,template,pos,color,referenceMiner)
 local model=template and template:Clone() or Instance.new('Model');model.Name='Drone';sanitize(model,false)
 local part=model.PrimaryPart or model:FindFirstChild('Mesh') or model:FindFirstChildWhichIsA('BasePart',true)
 if not part or not part:IsA('BasePart') then part=W.part(model,'Hull',pos,Vector3.new(2,2,2),Color3.fromRGB(229,235,230)) end
 part.Color=Color3.fromRGB(111,120,123):Lerp(color,.18)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('BasePart') then v.Material=Enum.Material.SmoothPlastic;v.Reflectance=0 end
 end
 model.PrimaryPart=part;model.Parent=parent;model:PivotTo(CFrame.new(pos))
 local emitter=model:FindFirstChild('Emmiter',true)
 if not emitter or not emitter:IsA('BasePart') then emitter=W.part(model,'Emmiter',pos,Vector3.new(.24,.24,.24),color,Enum.Material.Neon) end
 emitter.Color=color;emitter.CanQuery=false;emitter.Material=Enum.Material.SmoothPlastic
 local scale=referenceMiner and 1 or .58
 model:ScaleTo(model:GetScale()*scale);model:SetAttribute('ModelScale',scale)
 model:SetAttribute('OriginalDrone',template~=nil)
 return model,part,emitter
end
local function finishConstruct(model)
 local shell={bottemseg=true,lowerseg=true,upperseg=true,topseg=true}
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('BasePart') then
   v.Reflectance=0;v.MaterialVariant=''
   if shell[v.Name] then v.Material=Enum.Material.SmoothPlastic;v.Color=Color3.fromRGB(218,232,219)
   elseif v.Name=='eyecase' then v.Material=Enum.Material.Metal;v.Color=Color3.fromRGB(47,91,91)
   elseif v.Name=='basepart' then v.Material=Enum.Material.Slate;v.Color=Color3.fromRGB(35,66,70);v.Transparency=0
   elseif v.Name=='eye' or v.Name=='spawnEye' then v.Material=Enum.Material.Neon;v.Color=Color3.fromRGB(102,224,206) end
  end
 end
end
function W.turret(parent,template,pos,color)
 assert(template and template:IsA('Model'),'Original Workspace.construct template is required; refusing a replacement box turret')
 local model=template:Clone();model.Name='PyramidTurret'
 -- AnimSaves is editor keyframe history (3,428 descendants), not the live rig.
 -- Preserve the complete original and ServerStorage template; omit only this redundant
 -- cloned editor copy. Clone the model first so Motor6D references remain correctly remapped.
 local editorHistory=model:FindFirstChild('AnimSaves')
 if editorHistory then editorHistory:Destroy() end
 sanitize(model,false)
 local base=model:FindFirstChild('basepart',true)
 assert(base and base:IsA('BasePart'),'Original construct basepart is missing')
 for _,name in ipairs({'bottemseg','lowerseg','upperseg','topseg','eye','eyecase','spawnEye'}) do
  assert(model:FindFirstChild(name,true),'Original construct missing '..name)
 end
 model.PrimaryPart=base;model.Parent=parent;model:PivotTo(CFrame.new(pos))
 -- Retain every authored mesh/pivot, but give the construct one coherent ceramic shell.
 finishConstruct(model)
 local eye=model:FindFirstChild('eye',true)
 -- One invisible query body admits range/LOS checks without changing the authored silhouette.
 local hit=W.part(model,'DefenseHitbox',base.Position+Vector3.new(0,4.5,0),Vector3.new(8,10,8),color)
 hit.Transparency=1;hit.CanQuery=true
 hit:SetAttribute('TurretHitbox',true);model:SetAttribute('OriginalConstruct',true)
 return model,hit,eye
end
function W.beam(parent,color)
 local rs=game:GetService('ReplicatedStorage')
 local fx=rs:FindFirstChild('MiningFX');local template=fx and fx:FindFirstChild('Beam')
 local a=Instance.new('Attachment');a.Name='RenderedEmitter';a.Position=Vector3.zero;a.Parent=parent
 local endpoint=W.part(parent,'Endpoint',parent.Position,Vector3.new(.05,.05,.05),color);endpoint.Transparency=1
 local b=Instance.new('Attachment');b.Parent=endpoint
 local beams={}
 for i,name in ipairs({'InnerBeam','OuterBeam'}) do
  local original=template and template:FindFirstChild(name,true)
  local beam=original and original:Clone() or Instance.new('Beam')
  beam.Name=name;beam.Attachment0=a;beam.Attachment1=b;beam.FaceCamera=true;beam.LightEmission=1
  beam.Color=ColorSequence.new(i==1 and Color3.new(1,1,1) or color)
  beam.Width0=0;beam.Width1=0;beam.Enabled=false;beam.Parent=parent
  table.insert(beams,beam)
 end
 return {beams=beams,endpoint=endpoint,attachment=a,targetAttachment=b}
end
function W.setBeam(b,on,pos)
 if pos then b.endpoint.Position=pos end
 for i,v in ipairs(b.beams) do v.Enabled=on;v.Width0=on and (i==1 and .3 or .65) or 0;v.Width1=v.Width0 end
end
local P={
 ground=Color3.fromRGB(84,154,115),dust=Color3.fromRGB(210,216,183),stone=Color3.fromRGB(65,103,106),
 ledge=Color3.fromRGB(186,207,191),metal=Color3.fromRGB(30,65,73),edge=Color3.fromRGB(117,171,162),
 ivory=Color3.fromRGB(245,237,207),ink=Color3.fromRGB(22,49,60),mint=Color3.fromRGB(100,229,201),
 amber=Color3.fromRGB(245,182,96),blue=Color3.fromRGB(118,201,228),coral=Color3.fromRGB(226,129,145),
}
local function solid(p) p.CanCollide=true;p.CanQuery=true;return p end
local function block(parent,name,at,size,color,material,rotation)
 local p=W.part(parent,name,at,size,color,material)
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.CastShadow=true
 if rotation then p.CFrame=CFrame.new(at)*CFrame.Angles(rotation[1] or 0,rotation[2] or 0,rotation[3] or 0) end
 return p
end
local function textFace(part,title,subtitle,color,face)
 local g=Instance.new('SurfaceGui');g.Name='SignFace';g.Face=face or Enum.NormalId.Front;g.CanvasSize=Vector2.new(600,180);g.LightInfluence=0;g.Parent=part
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(.92,.48);t.Position=UDim2.fromScale(.04,.09);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextSize=44;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextColor3=color;t.Text=title;t.Parent=g
 local s=Instance.new('TextLabel');s.Size=UDim2.fromScale(.92,.28);s.Position=UDim2.fromScale(.04,.65);s.BackgroundTransparency=1;s.Font=Enum.Font.GothamMedium;s.TextSize=24;s.TextXAlignment=Enum.TextXAlignment.Left;s.TextColor3=P.ivory;s.Text=subtitle;s.Parent=g
 -- Machines and field approaches can be visited from either direction.
 if not face then local back=g:Clone();back.Name='SignReverse';back.Face=Enum.NormalId.Back;back.Parent=part end
 return g
end
local function sign(parent,at,title,subtitle,color,facing)
 local model=Instance.new('Model');model.Name='Wayfinding';model.Parent=parent
 local board=block(model,'FieldSign',at+Vector3.new(0,3.4,0),Vector3.new(9,2.8,.45),P.ink,Enum.Material.Metal)
 if facing then board.CFrame=CFrame.lookAt(board.Position,Vector3.new(facing.X,board.Position.Y,facing.Z)) end
 for _,dx in ipairs({-3.5,3.5}) do
  local p=block(model,'SignFoot',board.CFrame:PointToWorldSpace(Vector3.new(dx,-2,0)),Vector3.new(.3,3,.3),P.edge,Enum.Material.Metal);p.CFrame=CFrame.new(p.Position)*board.CFrame.Rotation
 end
 local stripe=block(model,'FieldCode',board.CFrame:PointToWorldSpace(Vector3.new(-4.3,0,-.25)),Vector3.new(.18,2.2,.08),color,Enum.Material.SmoothPlastic);stripe.CFrame=CFrame.new(stripe.Position)*board.CFrame.Rotation
 textFace(board,title,subtitle,color)
 return board
end
local function light(parent,color,range,brightness)
 local l=Instance.new('PointLight');l.Name='WorkLight';l.Color=color;l.Range=range;l.Brightness=brightness;l.Shadows=false;l.Parent=parent
end
local function path(parent,a,b,width)
 local middle=(a+b)/2
 local p=solid(block(parent,'Trail',middle,Vector3.new(width or 11,.28,(b-a).Magnitude),P.dust,Enum.Material.SmoothPlastic))
 p.CFrame=CFrame.lookAt(middle,b);p:SetAttribute('WalkRoute',true)
 -- Inlaid shoulder and short waymarkers give the trail a direction without neon rails.
 local flat=Vector3.new(b.X-a.X,0,b.Z-a.Z);local side=Vector3.new(-flat.Z,0,flat.X).Unit
 for _,sgn in ipairs({-1,1}) do
  local shoulder=block(parent,'TrailShoulder',middle+side*((width or 11)/2+.5)*sgn-Vector3.new(0,.1,0),Vector3.new(.8,.25,(b-a).Magnitude),P.ground,Enum.Material.Slate)
  shoulder.CFrame=CFrame.lookAt(shoulder.Position,b+side*((width or 11)/2+.5)*sgn)
 end
 return p
end
local function station(parent,name,at,color,title,interaction)
 local model=Instance.new('Model');model.Name=name..'Assembly';model.Parent=parent
 local base=solid(block(model,name,at+Vector3.new(0,1,0),Vector3.new(6,2,5),P.metal,Enum.Material.Metal))
 base:SetAttribute('Interaction',interaction)
 local prompt=Instance.new('ProximityPrompt');prompt.ActionText=title;prompt.ObjectText=name=='PackStation' and 'RUN CARDS' or name=='Printer' and 'DRONE PRINTER' or 'PERMANENT FLEET';prompt.MaxActivationDistance=10;prompt.HoldDuration=0;prompt.RequiresLineOfSight=false;prompt.Enabled=true;prompt.Parent=base
 block(model,'MachineFoot',at+Vector3.new(0,.18,0),Vector3.new(7,.36,6),P.ledge,Enum.Material.Concrete)
 for _,x in ipairs({-2.7,2.7}) do block(model,'ChassisEdge',at+Vector3.new(x,1.2,0),Vector3.new(.22,1.7,4.7),P.edge,Enum.Material.Metal) end
 if name=='Printer' then
  -- Free reprints appear inside this open bay, directly above the existing server station.
  for _,x in ipairs({-3.25,3.25}) do
   block(model,'PrintGantry',at+Vector3.new(x,3.7,0),Vector3.new(.55,7.4,4.7),P.metal,Enum.Material.Metal)
   block(model,'PrintRail',at+Vector3.new(x*.93,4.2,-1.8),Vector3.new(.14,4.5,.16),color,Enum.Material.Neon)
  end
  block(model,'PrintHead',at+Vector3.new(0,7.1,0),Vector3.new(7.2,.65,4.7),P.edge,Enum.Material.Metal)
  block(model,'PrintEmitter',at+Vector3.new(0,6.68,0),Vector3.new(3.3,.1,2.8),color,Enum.Material.Neon)
  block(model,'PrintBed',at+Vector3.new(0,2.08,0),Vector3.new(4.7,.16,3.7),P.ink,Enum.Material.Metal)
  local fascia=block(model,'PrinterName',at+Vector3.new(0,6.98,-2.4),Vector3.new(4.7,.8,.12),P.ink)
  textFace(fascia,'PRINT BAY','FREE REPAIRS',color)
 elseif name=='PackStation' then
  local screen=block(model,'CardConsole',at+Vector3.new(0,2.8,.7),Vector3.new(4.9,2,.45),P.ink,Enum.Material.Metal,{math.rad(-16),0,0})
  for i=-1,1 do
   local card=block(model,'CardSlot',screen.CFrame:PointToWorldSpace(Vector3.new(i*1.45,.1,-.28)),Vector3.new(1.05,1.32,.12),i==0 and color or P.edge,Enum.Material.SmoothPlastic)
   card.CFrame=CFrame.new(card.Position)*screen.CFrame.Rotation
   local notch=block(model,'CardNotch',card.CFrame:PointToWorldSpace(Vector3.new(0,-.35,-.08)),Vector3.new(.6,.08,.04),P.ink);notch.CFrame=CFrame.new(notch.Position)*screen.CFrame.Rotation
  end
  local fascia=block(model,'CardName',at+Vector3.new(0,1.1,-2.56),Vector3.new(4.5,1.3,.12),P.ink)
  textFace(fascia,'PACK SHOP','',color)
 else
  -- Stepped hardware echoes the original segmented construct without replacing it.
  for i=1,3 do
   block(model,'FleetStack',at+Vector3.new(0,1.7+i*.8,.2),Vector3.new(4.8-i*.8,.48,3.8-i*.55),i==3 and color or P.edge,Enum.Material.Metal)
  end
  for _,x in ipairs({-2.4,2.4}) do block(model,'FleetSocket',at+Vector3.new(x,2.6,.5),Vector3.new(.32,2.1,.32),P.metal,Enum.Material.Metal) end
  local fascia=block(model,'FleetName',at+Vector3.new(0,1.1,-2.56),Vector3.new(4.5,1.3,.12),P.ink)
  textFace(fascia,'FLEET UPLINK','EARN A NEW DRONE',color)
 end
 return base
end
local function tree(parent,x,z,h,color,ground,yaw)
 local m=Instance.new('Model');m.Name='QuarryTree';m.Parent=parent
 ground=ground or 0;yaw=yaw or x*.1
 local trunkColor=Color3.fromRGB(85,70,66)
 local function localPart(name,p,size,tint,turn)
  local cf=CFrame.new(x,ground,z)*CFrame.Angles(0,yaw,0)*CFrame.new(p)
  local v=block(m,name,cf.Position,size,tint,Enum.Material.SmoothPlastic);v.CFrame=cf*CFrame.Angles(0,0,turn or 0);return v
 end
 -- Forked trunks and chunky, tiered crowns keep the original parts-built language.
 localPart('Trunk',Vector3.new(0,h*.39,0),Vector3.new(1.35,h*.78,1.5),trunkColor,math.rad(-4))
 localPart('Root',Vector3.new(-.8,.65,0),Vector3.new(3.8,1.3,2.7),trunkColor,math.rad(8))
 localPart('Fork',Vector3.new(2,h*.68,0),Vector3.new(.85,h*.44,.9),trunkColor,math.rad(-29))
 localPart('Fork',Vector3.new(-2.2,h*.65,.3),Vector3.new(.8,h*.34,.85),trunkColor,math.rad(32))
 localPart('Canopy',Vector3.new(-2.5,h*.84,.3),Vector3.new(h*.52,3.4,h*.46),color,math.rad(-9))
 localPart('Canopy',Vector3.new(3.5,h*.88,-.3),Vector3.new(h*.43,3.1,h*.39),color:Lerp(P.amber,.12),math.rad(8))
 localPart('Canopy',Vector3.new(0,h,0),Vector3.new(h*.48,3.5,h*.42),color:Lerp(P.ivory,.14),math.rad(-3))
 localPart('Crown',Vector3.new(-1,h+2.1,.3),Vector3.new(h*.29,1.5,h*.3),color:Lerp(P.ivory,.27),math.rad(-5))
 return m
end
local function stone(parent,at,size,tilt,color,name)
 return solid(block(parent,name or 'WeatheredStone',at,size,color or P.stone,Enum.Material.SmoothPlastic,{math.rad(tilt[1] or 0),math.rad(tilt[2] or 0),math.rad(tilt[3] or 0)}))
end
local function surveyGate(parent,at,color)
 local m=Instance.new('Model');m.Name='PlotEntrance';m.Parent=parent
 for _,s in ipairs({-1,1}) do
  stone(m,at+Vector3.new(s*8,3.5,0),Vector3.new(2,7,3),{0,0,s*-5},P.ledge,'ChalkPylon')
  block(m,'GateMarker',at+Vector3.new(s*7.9,5.6,-1.53),Vector3.new(.3,2,.12),color,Enum.Material.Neon)
 end
 block(m,'GateLintel',at+Vector3.new(0,7.5,0),Vector3.new(18,1.15,3),P.ivory,Enum.Material.SmoothPlastic)
end
local function cleanSurface(part,archive)
 part.MaterialVariant='';part.Reflectance=0;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 for _,v in ipairs(part:GetChildren()) do if v:IsA('Texture') or v:IsA('Decal') then v.Parent=archive end end
end
local function nativeFinish(part,material,studs)
 part.Material=material;part.MaterialVariant='';part.Reflectance=0
 part.TopSurface=studs and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
 part.BottomSurface=Enum.SurfaceType.Smooth
end

-- The authored terraces use the stud pack for nearly every surface, including
-- earth, plants and wood. Map those finishes to actual surface materials at
-- server startup so the original parts, placement and archives stay intact.
local QuarryBiomes=(function()
-- Biome dressing grows out from the existing mining patches and routes.
local Biomes={}
local rgb=Color3.fromRGB
local ivory=rgb(249,239,207)
local cool={rgb(65,108,183),rgb(105,158,226),rgb(166,222,252)}
local coral={rgb(154,61,77),rgb(221,102,117),rgb(251,172,142)}

local function glow(part,color,range,brightness)
 local lamp=Instance.new('PointLight');lamp.Name='LocalGlow';lamp.Color=color
 lamp.Range=range;lamp.Brightness=brightness;lamp.Shadows=false;lamp.Parent=part
end

local function block(parent,name,frame,size,color,variant)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true
 p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.CFrame=frame;p.Size=size;p.Color=color;p.Material=Enum.Material.Slate
 p.MaterialVariant=variant or 'QuarryBiome_Chalk'
 local definition=game:GetService('MaterialService'):FindFirstChild(p.MaterialVariant)
 if definition and definition:IsA('MaterialVariant') then p.Material=definition.BaseMaterial end
 p.Parent=parent
 return p
end

local function cosmetic(part)
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
 part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
end

local function cylinder(parent,name,frame,size,color,material,variant)
 local part=Instance.new('Part');part.Name=name;part.Shape=Enum.PartType.Cylinder
 cosmetic(part)
 part.Size=size;part.CFrame=frame;part.Color=color;part.Material=material
 if variant then part.MaterialVariant=variant end
 part.Parent=parent
 return part
end

local function segment(parent,name,a,b,width,color,material,variant)
 local center=(a+b)*.5
 local frame=CFrame.lookAt(center,b)*CFrame.Angles(0,math.pi*.5,0)
 return cylinder(parent,name,frame,Vector3.new((b-a).Magnitude+.06,width,width),color,material,variant)
end

local function capFacet(part)
 cosmetic(part);part.Name='CapMembrane';part.Material=Enum.Material.Slate
 part.MaterialVariant='QuarryBiome_Chalk'
end

local function mushroom(parent,ground,height,radius,lean,palette,index)
 local tree=Instance.new('Model');tree.Name=palette==cool and 'Blue Trumpet' or 'Coral Fan';tree.Parent=parent
 tree:SetAttribute('BiomeLandmark',true)
 local function stalk(t)
  return ground+Vector3.yAxis*(height*.77*t)+lean*(t*t)
 end
 local stemRings={};local segments=height>25 and 7 or 5
 for k=0,segments do
  local t=k/segments;local ring={}
  local width=radius*(.085+.09*(1-t)^3+.055*t^5)
  for j=1,8 do
   local a=(j-1)*math.pi*.25
   ring[j]=stalk(t)+Vector3.new(math.cos(a),0,math.sin(a))*width*(1+.065*math.sin(j*2.1+index))
  end
  stemRings[k+1]=ring
 end
 local function stemFinish(part)
  cosmetic(part);part.Name='CurvedFibrousStem';part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk'
 end
 for k=1,segments do
  local t=k/segments
  for j=1,8 do
   local next=j%8+1
   local tint=ivory:Lerp(palette[2],t*t*.65):Lerp(palette[1],(j%3)*.026)
   Facets.triangle(tree,stemRings[k][j],stemRings[k+1][j],stemRings[k+1][next],tint,stemFinish)
   Facets.triangle(tree,stemRings[k][j],stemRings[k+1][next],stemRings[k][next],tint,stemFinish)
  end
 end
 -- Buttresses give the trunk weight where it meets the ground.
 for i=1,index>50 and 0 or 5 do
  local a=i*math.pi*.4+index
  segment(tree,'StemButtress',ground+Vector3.new(math.cos(a),0,math.sin(a))*radius*.24,
   stalk(.22),radius*.09,ivory,Enum.Material.Slate,'QuarryBiome_Chalk')
 end
 local n=height>34 and 16 or 12
 local neck=stalk(1);local rings={{},{},{}};local tops={{},{},{}}
 for i=1,n do
  local a=(i-1)*2*math.pi/n
  local wave=math.sin(3*a+index*.61)*.7+math.sin(5*a+index)*.3
  local fan=palette==coral and (.87+.18*math.cos(a-index)) or 1
  local radial=Vector3.new(math.cos(a),0,math.sin(a))
  local reach=radius*(fan+wave*.075)
  rings[1][i]=neck+radial*radius*.14
  rings[2][i]=neck+radial*reach*.48+Vector3.yAxis*height*.135+lean*.09
  rings[3][i]=neck+radial*reach+Vector3.yAxis*height*(.19+.025*wave)+lean*.17
  for k=1,3 do tops[k][i]=rings[k][i]+Vector3.yAxis*(k==3 and .7 or 1.1) end
 end
 for i=1,n do
  local j=i%n+1
  local shade=palette[1]:Lerp(palette[2],.34+.15*math.sin(i*1.3+index))
  for k=1,2 do
   Facets.triangle(tree,rings[k][i],rings[k+1][i],rings[k+1][j],shade,capFacet)
   Facets.triangle(tree,rings[k][i],rings[k+1][j],rings[k][j],shade,capFacet)
   local upper=palette[2]:Lerp(palette[3],.10+.06*(i%3))
   Facets.triangle(tree,tops[k][i],tops[k+1][j],tops[k+1][i],upper,capFacet)
   Facets.triangle(tree,tops[k][i],tops[k][j],tops[k+1][j],upper,capFacet)
  end
  Facets.triangle(tree,rings[3][i],tops[3][i],tops[3][j],ivory,capFacet)
  Facets.triangle(tree,rings[3][i],tops[3][j],rings[3][j],ivory,capFacet)
  -- Continuous ribbed undersides replace the disconnected white dashes.
  for k=1,2 do
   local rib=segment(tree,'RadialGill',rings[k][i]-Vector3.yAxis*.24,rings[k+1][i]-Vector3.yAxis*.24,
    radius*.018,palette[1]:Lerp(ivory,.21),Enum.Material.Slate,'QuarryBiome_Chalk')
   if i%5==1 then
    local a=rings[k][i]:Lerp(rings[k+1][i],.18)-Vector3.yAxis*.36
    local b=rings[k][i]:Lerp(rings[k+1][i],.91)-Vector3.yAxis*.36
    local glowRib=segment(tree,'BioluminescentGill',a,b,radius*.009,palette[3],Enum.Material.Neon)
    glowRib.CastShadow=false
    if k==1 and i==1 then glow(glowRib,palette[3],math.min(36,height*.65),1.5) end
   end
  end
 end
 -- Coral shelves branch from the same curved stalk, as in the canyon reference.
 if palette==coral and height>25 and index<50 then
  mushroom(tree,stalk(.35),height*.51,radius*.46,Vector3.new(8,0,4),palette,index+60)
  mushroom(tree,stalk(.65),height*.31,radius*.34,Vector3.new(-6,0,-3),palette,index+80)
 end
end

local function turfSampler(terraces,center)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={terraces};params.RespectCanCollide=true
 return function(x,z)
  local point=center+Vector3.new(x,110,z)
  local hit=workspace:Raycast(point,Vector3.new(0,-155,0),params)
  if hit and hit.Instance.Name=='Turf' then return hit.Position end
 end
end

local function patchEdge(part,bed)
 local p=part.Position-bed.Position
 return math.max(0,math.abs(p.X)-bed.Size.X*.5,math.abs(p.Z)-bed.Size.Z*.5),p.Y
end

local function cobalt(biome,bed,terraces,ground)
 -- A dominant crown and two supporting silhouettes frame the open mining floor.
 for i,spec in ipairs({
  {39,10,58,25,Vector3.new(-10,0,-5),cool},
  {18,-41,44,21,Vector3.new(5,0,5),cool},
  {-20,38,35,17,Vector3.new(-8,0,-5),coral},
  {34,39,18,9,Vector3.new(-4,0,2),coral},
  {-39,25,12,6,Vector3.new(2,0,1),cool},
 }) do
  local pos=ground(spec[1],spec[2]);if pos then mushroom(biome,pos,spec[3],spec[4],spec[5],spec[6],i) end
 end
 for _,part in ipairs(terraces:GetDescendants()) do
  if part:IsA('BasePart') then
   local edge,y=patchEdge(part,bed)
   if edge<26 and y>-25 and y<7 then
    if part.MaterialVariant=='QuarryPhoto_Grass' and edge<15 then
     part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk'
     part.Color=rgb(201,222,194):Lerp(rgb(139,183,166),math.clamp(edge/26,0,1))
    elseif part.MaterialVariant=='QuarryPhoto_Rock' or part.MaterialVariant=='QuarryPhoto_Sandstone' then
     part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Shale';part.Color=rgb(167,185,213)
    end
   end
  end
 end
 bed.Material=Enum.Material.Slate;bed.MaterialVariant='QuarryBiome_Shale';bed.Color=rgb(141,164,196)
end

local function spire(parent,base,width,height,lean,tint,variant)
 -- Offset vertical stone plates make broken cliffs with readable ledges and fissures.
 local group=Instance.new('Model');group.Name='FracturedCliff';group.Parent=parent
 for i=1,5 do
  local offset=(i-3)*width*.38
  local h=height*({.59,.84,1,.76,.46})[i]
  local at=base+Vector3.new(offset,h*.5,-math.abs(i-3)*width*.20)+lean*(h/height)*.4
  local p=block(group,'SplitRockFace',CFrame.new(at)*CFrame.Angles(.025*(i-3),.13*(i-2),-.035*(i-3)),
   Vector3.new(width*(.38+.05*(i%2)),h,width*(.74+.11*(i%3))),tint:Lerp(rgb(105,132,158),.06*(i%3)),variant)
  local crown=Instance.new('WedgePart');crown.Name='JaggedCrown';cosmetic(crown)
  crown.Size=Vector3.new(p.Size.Z*.99,height*(.12+.025*(i%3)),p.Size.X*1.02)
  crown.CFrame=p.CFrame*CFrame.new(0,h*.5+crown.Size.Y*.5-.15,0)*CFrame.Angles(0,i%2==0 and math.pi*.5 or -math.pi*.5,0)
  crown.Color=tint;crown.Material=Enum.Material.Slate;crown.MaterialVariant=variant;crown.Parent=group
 end
 return base+Vector3.yAxis*height+lean*.4
end

local function ruby(biome,bed,terraces,ground)
 for _,part in ipairs(terraces:GetDescendants()) do
  if not part:IsA('BasePart') then continue end
  local edge,y=patchEdge(part,bed)
  if edge>27 or y>5 or y< -25 then continue end
  local noise=math.noise(part.Position.X*.058,part.Position.Z*.058)
  if part.MaterialVariant=='QuarryPhoto_Grass' and (edge<9 or noise>edge/55-.28) then
   part.MaterialVariant='QuarryBiome_Crimson';part.Color=rgb(248,237,221):Lerp(rgb(221,215,204),math.clamp(.5+noise,0,1))
  elseif (part.MaterialVariant=='QuarryPhoto_Sandstone' or part.MaterialVariant=='QuarryPhoto_Rock' or (part.Name=='RubyEdgeWeathering' and part.MaterialVariant=='QuarryPhoto_Pebble')) and edge<18 then
   part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Shale'
   part.Color=rgb(174,195,223):Lerp(rgb(116,132,156),math.clamp(.45+noise,0,1))
  end
 end
 bed.Material=Enum.Material.Slate;bed.MaterialVariant='QuarryBiome_Shale';bed.Color=rgb(149,163,185)
 for _,spec in ipairs({{-39,10,13,43,-4},{-38,-16,11,57,-3},{-34,-34,8,32,-2},{-17,38,6,18,2},{17,39,4,11,1}}) do
  local p=ground(spec[1],spec[2])
  if p then
   spire(biome,p,spec[3],spec[4],Vector3.new(spec[5],0,-1),rgb(208,220,240),'QuarryBiome_Shale')
   local seam=p+Vector3.new(spec[3]*.64,1.3,0)
   local vein=segment(biome,'RubyVein',seam,seam+Vector3.new(-.45,spec[4]*.21,-.4),.34,rgb(255,117,134),Enum.Material.Neon)
   vein.CastShadow=false;glow(vein,rgb(255,103,122),16,1.7)
  end
 end
end

-- Build a real water body and its shore in the open space alongside a patch.
-- Keep the voxel edit bounded and retain any pre-existing occupied cells.
local function basin(terrain,center,rx,rz,depth,minCorner,maxCorner)
 local region=Region3.new(minCorner,maxCorner):ExpandToGrid(4)
 local channels=terrain:ReadVoxelChannels(region,4,{'SolidMaterial','SolidOccupancy','LiquidOccupancy'})
 local materials,solid,water=channels.SolidMaterial,channels.SolidOccupancy,channels.LiquidOccupancy
 local origin=region.CFrame.Position-region.Size*.5
 local salt,sand,grass=Enum.Material.Salt,Enum.Material.Sand,Enum.Material.Ground
 local function profile(x,z)
  local dx,dz=x-center.X,z-center.Z
  local angle=math.atan2(dz/rz,dx/rx)
  local r=math.sqrt((dx/rx)^2+(dz/rz)^2)+.067*math.cos(angle*3+.65)+.044*math.sin(angle*5)
  local t=math.clamp((r-.39)/.46,0,1)
  t=t*t*(3-2*t)
  local top=center.Y-depth+(depth+4.6)*t+1.45*math.noise(x*.07,z*.07)
  local bottom=center.Y-8-13*math.sqrt(math.max(0,1-r))
  return r,top,bottom
 end
 for ix,column in ipairs(solid) do
  local x=origin.X+(ix-.5)*4
  for iz=1,#column[1] do
   local z=origin.Z+(iz-.5)*4
   local r,top,bottom=profile(x,z)
   if r>=1 then continue end
   local lip=math.clamp((1-r)*13,0,1)
   for iy,row in ipairs(column) do
    local y=origin.Y+(iy-.5)*4
    if row[iz]>0 or water[ix][iy][iz]>0 or y<bottom-2 then continue end
    local density=math.clamp((top-y)/4+.5,0,lip)
    if density>0 then
     row[iz]=density
     local green=top>center.Y+1.5 and math.noise(x*.071,z*.077)+.17*math.sin(z*.083)>-.15
     if green and y>top-3.2 then materials[ix][iy][iz]=grass
     elseif y<top-8 then materials[ix][iy][iz]=Enum.Material.Sandstone
     else materials[ix][iy][iz]=y>top-3 and top<center.Y+1 and sand or salt end
    end
    if r<.83 then
     local level=math.clamp((center.Y-y)/4+.5,0,1)
     water[ix][iy][iz]=math.max(0,math.min(1-density,level))
    end
   end
  end
 end
 terrain:WriteVoxelChannels(region,4,{SolidMaterial=materials,SolidOccupancy=solid,LiquidOccupancy=water})
 return profile
end

local function rockMass(parent,base,width,depth,height,turn,seed)
 local group=Instance.new('Model');group.Name='WeatheredWhiteCliff';group.Parent=parent
 local basis=CFrame.new(base)*CFrame.Angles(0,turn,0)
 -- Broad planar faces and stepped fractures, with no rounded cone silhouette.
 for i=1,4 do
  local h=height*({.72,1,.89,.56})[i]
  local x=(i-2.5)*width*.49
  local tint=rgb(246,247,229):Lerp(rgb(157,190,203),.035+((i+seed)%3)*.055)
  local slab=block(group,'ChalkSlab',basis*CFrame.new(x,h*.5,(i%2)*depth*.14)*CFrame.Angles(.018*(i-2),.035*(i-2),.045*(i-2)),
   Vector3.new(width*.57,h,depth*(.9+.11*(i%2))),tint,'QuarryBiome_Chalk')
  if h>12 then
   block(group,'ChalkLedge',slab.CFrame*CFrame.new(0,h*.15,-depth*.10)*CFrame.Angles(0,.06,-.06),
    Vector3.new(width*.63,height*.09,depth*1.05),tint:Lerp(ivory,.2),'QuarryBiome_Chalk')
   block(group,'BrokenSummit',slab.CFrame*CFrame.new(0,h*.48,0)*CFrame.Angles(.12,0,-.10),
    Vector3.new(width*.59,height*.075,depth*.89),tint,'QuarryBiome_Chalk')
  end
 end
 return basis:PointToWorldSpace(Vector3.new(-width*.25,height+.1,0))
end

local function foliage(parent,base,scale,seed)
 -- Layered leaf planes keep a leafy silhouette instead of spherical clusters.
 for i=1,7 do
  local angle=(i-1)*2.4+seed
  local reach=(i%3)*1.05*scale
  local size=Vector3.new(3.4+(i%2)*.7,.75+(i%3)*.16,2.8)*scale
  local at=base+Vector3.new(math.cos(angle)*reach,(i%3)*.36,math.sin(angle)*reach)
  block(parent,'LeafyShelf',CFrame.new(at)*CFrame.Angles(.07*math.sin(i),angle,.14*math.cos(i)),size,
   rgb(213,244,171):Lerp(rgb(124,203,142),.14*(i%4)),'QuarryFoliage_Canopy')
 end
end

local function causeway(parent,origin)
 -- A complete narrow crossing, leading through the water to the far overlook.
 for i=0,30 do
  local t=i/30
  local bend=math.sin(t*math.pi)*4.2
  local at=origin+Vector3.new(i*3.18,.45+math.sin(t*math.pi)*1.3-.9*t^5,bend)
  local p=block(parent,'LagoonCauseway',CFrame.new(at)*CFrame.Angles(0,.045*math.cos(t*math.pi),0),
   Vector3.new(3.27,.95,7.8),ivory:Lerp(rgb(171,205,198),.06*(i%3)),'QuarryBiome_Chalk')
  p.CanCollide=true;p.CanQuery=true;p:SetAttribute('WalkRoute',true)
  if i%4==0 then
   block(parent,'BridgePier',CFrame.new(at+Vector3.new(0,-6.5,0)),Vector3.new(2.5,12,5.5),rgb(204,222,218),'QuarryBiome_Chalk')
  end
  if i>2 and i<29 and i%3~=0 then
   block(parent,'LowParapet',CFrame.new(at+Vector3.new(0,.9,3.65)),Vector3.new(3.24,1.5,.65),ivory,'QuarryBiome_Chalk')
  end
 end
end

local function shoreTree(parent,base,h,lean,index)
 local top=base+lean+Vector3.yAxis*h
 local fork=base+lean*.55+Vector3.yAxis*(h*.64)
 local bark=rgb(220,212,176)
 segment(parent,'WindBentTrunk',base-Vector3.yAxis*.18,fork,h*.11,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
 segment(parent,'WindBentTrunk',fork,top,h*.073,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
 foliage(parent,top,h*.15,index)
 for i=1,3 do
  local theta=i*2.4+index
  local endPoint=fork+Vector3.new(math.cos(theta)*h*.30,h*(.16+i*.04),math.sin(theta)*h*.26)
  segment(parent,'WindBentBranch',fork,endPoint,h*.045,bark,Enum.Material.Wood,'QuarryFoliage_Bark')
  foliage(parent,endPoint,h*.10,i+index)
 end
end

local function lagoon(parent,bed)
 local terrain=workspace.Terrain
 local center=bed.Position+Vector3.new(95,-5,0)
 local profile=basin(terrain,center,49,39,7,bed.Position+Vector3.new(48,-34,-44),center+Vector3.new(54,13,44))
 causeway(parent,bed.Position+Vector3.new(40,.55,0))
 -- One large broken cliff dominates the far bank. Lower shelves overlap it,
 -- and open water is held between the foreground crossing and the stone wall.
 for i,s in ipairs({{29,-23,12,9,60},{39,-14,9,8,44},{15,-28,8,7,30},
  {35,20,8,7,34},{42,7,5,6,21},{10,31,7,5,8},{-9,29,5,4,5},
  {-28,18,5,5,4},{11,-17,4,3,5}}) do
  local x,z=center.X+s[1],center.Z+s[2];local _,y=profile(x,z)
  local base=Vector3.new(x,y-1.1,z)
  local peak=rockMass(parent,base,s[3],s[4],s[5],-.12+i*.16,i)
  foliage(parent,peak, i<=4 and 2.15 or 1.4,i)
  if i<=4 then
   foliage(parent,base+Vector3.new(-s[3]*.5,s[5]*.64,-s[4]*.45),1.65,i+7)
   foliage(parent,base+Vector3.new(s[3]*.45,s[5]*.31,s[4]*.45),1.3,i+12)
  end
 end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={terrain};params.IgnoreWater=true
 for i,s in ipairs({{-34,19,10},{-31,-22,12},{-20,-29,10},{-7,-32,0},{7,32,0},{24,27,12},{30,-25,0}}) do
  local x,z=center.X+s[1],center.Z+s[2];local r,expected=profile(x,z)
  local hit=workspace:Raycast(Vector3.new(x,center.Y+24,z),Vector3.new(0,-36,0),params)
  local ground=hit and hit.Position or (r<.94 and Vector3.new(x,expected,z))
  if ground and ground.Y>center.Y+.15 then
   foliage(parent,ground+Vector3.yAxis*.25,1.5+.22*(i%3),i)
   if s[3]>0 then shoreTree(parent,ground,s[3],Vector3.new(2+i*.12,0,1.4),i) end
  end
 end
 -- Pale reeds and warm seed heads draw attention at the landing.
 for i=1,9 do
  local angle=i*2.4;local base=bed.Position+Vector3.new(46+math.cos(angle)*4,1.6,math.sin(angle)*6)
  local tip=base+Vector3.new(.3,2.2+(i%3)*.65,.15)
  segment(parent,'WaterReed',base,tip,.14,rgb(146,189,151),Enum.Material.Slate,'QuarryBiome_Chalk')
  local bulb=cylinder(parent,'ReedLight',CFrame.new(tip)*CFrame.Angles(0,0,math.pi*.5),Vector3.new(.8,.35,.35),rgb(255,222,131),Enum.Material.Neon)
  if i==1 then glow(bulb,rgb(255,221,148),18,1.5) end
 end
end

local function emerald(biome,bed,terraces)
 bed.Material=Enum.Material.Slate;bed.MaterialVariant='QuarryBiome_Chalk';bed.Color=rgb(197,235,217)
 local routes=terraces:FindFirstChild('WalkableRoutes')
 if routes then
  for _,part in ipairs(routes:GetChildren()) do
   if part:IsA('BasePart') and part.Name:match('^Emerald') then
    part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk';part.Color=ivory
   end
  end
 end
 lagoon(biome,bed)
 for _,part in ipairs(terraces:GetDescendants()) do
  if not part:IsA('BasePart') then continue end
  local p=part.Position-bed.Position
  if p.Y<0 and p.Y> -28 and p.X>12 and p.X<54 and math.abs(p.Z)<39 and
   (part.MaterialVariant=='QuarryPhoto_Sandstone' or part.MaterialVariant=='QuarryPhoto_Rock') then
   part.Material=Enum.Material.Slate;part.MaterialVariant='QuarryBiome_Chalk'
   part.Color=rgb(219,237,228):Lerp(rgb(148,180,195),math.clamp(.33+math.noise(p.X*.08,p.Z*.08),0,1))
  end
 end

end

local function lantern(parent,base,yaw,height)
 local warm=rgb(255,212,125)
 local basis=CFrame.new(base)*CFrame.Angles(0,yaw,0)
 local function piece(name,offset,size,tint,variant)
  return block(parent,name,basis*CFrame.new(offset),size,tint,variant)
 end
 local dark=rgb(66,82,83)
 piece('LampFoot',Vector3.new(0,.3,0),Vector3.new(1.5,.6,1.5),rgb(185,204,193))
 piece('LampPost',Vector3.new(0,height*.5,0),Vector3.new(.38,height,.38),dark,'QuarryPhoto_CorrodedMetal')
 piece('LampArm',Vector3.new(.8,height-.3,0),Vector3.new(2,.32,.4),dark,'QuarryPhoto_CorrodedMetal')
 piece('LampHood',Vector3.new(1.6,height-.65,0),Vector3.new(1.65,.34,1.55),dark,'QuarryPhoto_CorrodedMetal')
 local glass=piece('WarmLamp',Vector3.new(1.6,height-1.3,0),Vector3.new(.96,1.1,.96),warm)
 glass.Material=Enum.Material.Neon;glass.MaterialVariant='';glass.CastShadow=false
 piece('LampLowerRim',Vector3.new(1.6,height-1.88,0),Vector3.new(1.23,.18,1.23),dark,'QuarryPhoto_CorrodedMetal')
 glow(glass,warm,24,2.7)
end

local function lighting(scene,terraces)
 local lamps=Instance.new('Folder');lamps.Name='QuarryLanterns';lamps.Parent=scene.map
 for _,s in ipairs({{-17,4,17,0},{17,4,17,math.pi},{-42,4,-26,0},{42,4,-26,math.pi}}) do
  lantern(lamps,Vector3.new(s[1],s[2],s[3]),s[4],8.6)
 end
 local routes=terraces:FindFirstChild('WalkableRoutes')
 if routes then
  for _,route in ipairs(routes:GetChildren()) do
   if route:IsA('BasePart') and not route.Name:match('Curb$') then
    local at=route.CFrame:PointToWorldSpace(Vector3.new(route.Size.X*.5+.7,route.Size.Y*.5,-route.Size.Z*.28))
    local _,yaw=route.CFrame:ToOrientation()
    lantern(lamps,at,yaw+math.pi,7.4)
   end
  end
 end
end

local function patternedSurfaces(scene,terraces)
 -- Architectural patterns have limited, readable jobs. Mining beds keep their
 -- quieter geological surfaces, and the large hub pad remains plain.
 local materials=game:GetService('MaterialService')
 local herringbone=materials:FindFirstChild('QuarryPattern_Herringbone')
 local checker=materials:FindFirstChild('QuarryPattern_Checker')
 local square=terraces:FindFirstChild('MarketSquare')
 if square and herringbone then
  for _,name in ipairs({'NorthSouthWalk','EastWestWalk','UtilityWalk','ShopApron'}) do
   local part=square:FindFirstChild(name)
   if part and part:IsA('BasePart') then
    if not part.CustomPhysicalProperties then part.CustomPhysicalProperties=part.CurrentPhysicalProperties end
    part.Material=herringbone.BaseMaterial;part.MaterialVariant=herringbone.Name
    part.Color=rgb(190,205,240);part.Reflectance=0
   end
  end
 end
 local depot=scene.map:FindFirstChild('SimpleFlatTestMap')
 if depot and checker then
  for _,name in ipairs({'Printer','PackStation','PrestigeStation'}) do
   local assembly=depot:FindFirstChild(name..'Assembly')
   local pad=assembly and assembly:FindFirstChild(name..'Pad')
   if pad and pad:IsA('BasePart') then
    if not pad.CustomPhysicalProperties then pad.CustomPhysicalProperties=pad.CurrentPhysicalProperties end
    pad.Material=checker.BaseMaterial;pad.MaterialVariant=checker.Name
    pad.Color=rgb(233,234,216);pad.Reflectance=0
   end
  end
 end
end

function Biomes.build(scene,terraces)
 local fields=scene.root:FindFirstChild('Fields')
 if not fields then return end
 local terrain=workspace.Terrain
 terrain.WaterColor=rgb(35,139,154);terrain.WaterReflectance=.34
 terrain.WaterTransparency=.38;terrain.WaterWaveSize=.13;terrain.WaterWaveSpeed=5
 terrain:SetMaterialColor(Enum.Material.Salt,rgb(206,221,218))
 terrain:SetMaterialColor(Enum.Material.Sand,rgb(209,222,185))
 terrain:SetMaterialColor(Enum.Material.Ground,rgb(107,151,104))
 for _,spec in ipairs({{'Ruby','RubyCrimsonBluffs',ruby},{'Cobalt','CobaltMushroomGrove',cobalt},{'Emerald','EmeraldChalkLagoon',emerald}}) do
  local field=fields:FindFirstChild(spec[1])
  local bed=field and field:FindFirstChild('Field')
  if bed and bed:IsA('BasePart') then
   local biome=Instance.new('Folder');biome.Name=spec[2];biome.Parent=scene.map
   spec[3](biome,bed,terraces,turfSampler(terraces,bed.Position))
   task.wait()
  end
 end
 lighting(scene,terraces)
 patternedSurfaces(scene,terraces)
end
return Biomes

end)()
local quarryVariants={}
local polishedOre=false
local veinedOre=false
function W.applyQuarryVariant(part)
 part.MaterialVariant=quarryVariants[part.Material] or ''
end
function W.applyOreFinish(part,strongVeins)
 W.applyQuarryVariant(part)
 if polishedOre then
  part.MaterialVariant=strongVeins and veinedOre and 'QuarryOre_Veined' or 'QuarryOre_Polished'
  part.Reflectance=.11
 end
end
function W.applyQuarryTextures(scene)
 if not scene.root:GetAttribute('DronerevolutionMapVersion') then return false end
 local terraces=scene.map:FindFirstChild('DronerevolutionTerraces')
 if not terraces then return false end
 local material=Enum.Material
 local rgb=Color3.fromRGB
 -- Roblox restricts material definitions to Studio. The native document
 -- carries the 64 px photo tiles; gameplay only selects the named variants.
 for _,variant in ipairs(game:GetService('MaterialService'):GetChildren()) do
  local base=variant:IsA('MaterialVariant') and variant.Name:match('^QuarryPhoto_(%w+)$')
  if base then quarryVariants[material[base]]=variant.Name end
  if variant:IsA('MaterialVariant') and variant.Name=='QuarryOre_Polished' then polishedOre=true end
  if variant:IsA('MaterialVariant') and variant.Name=='QuarryOre_Veined' then veinedOre=true end
 end
 -- The shared Edit map and canonical file already carry the authored scenery.
 -- Still register materials for runtime ore and debris on every server.
 if scene.root:GetAttribute('QuarrySceneryAuthored') then return true end
 local oldFinish={
  DR_MeadowFine={material.Grass,rgb(103,112,77)},
  DR_MeadowMoss={material.LeafyGrass,rgb(87,101,70)},
  DR_MineralDust={material.Pebble,rgb(132,122,109)},
  DR_MineralSeams={material.Rock,rgb(113,105,98)},
  DR_CliffStrata={material.Sandstone,rgb(126,104,82)},
  DR_ExposedRock={material.Slate,rgb(109,98,86)},
  DR_WornPath={material.Pavement,rgb(143,134,116)},
 }
 -- Keep the photo palette legible after multiplication by the part color.
 -- Walkable stone and earth should read as different surfaces at a glance.
 local photoTint={
  [material.Grass]=rgb(221,224,201),
  [material.LeafyGrass]=rgb(201,216,198),
  [material.Sandstone]=rgb(255,237,219),
  [material.Pebble]=rgb(248,230,205),
  [material.Pavement]=rgb(229,239,255),
  [material.Concrete]=rgb(248,232,207),
 }
 local function finish(part,base,tint,foliageVariant)
  if part.Transparency>=1 or part.Material==material.Neon then return end
  if part.Material~=base or part.MaterialVariant~='' then
   -- Material changes can otherwise change friction and elasticity on paths.
   if not part.CustomPhysicalProperties then part.CustomPhysicalProperties=part.CurrentPhysicalProperties end
   part.Material=base;part.MaterialVariant=''
  end
  W.applyQuarryVariant(part)
  if foliageVariant then
   part.MaterialVariant=foliageVariant;part.Color=tint
  elseif photoTint[base] and quarryVariants[base] then
   part.Color=photoTint[base]:Lerp(tint,.14)
  else
   part.Color=quarryVariants[base] and rgb(252,249,239):Lerp(tint,.18) or tint
  end
  part.Reflectance=0
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  part.FrontSurface=Enum.SurfaceType.Smooth;part.BackSurface=Enum.SurfaceType.Smooth
  part.LeftSurface=Enum.SurfaceType.Smooth;part.RightSurface=Enum.SurfaceType.Smooth
 end
 for _,group in ipairs(terraces:GetChildren()) do
  for _,part in ipairs(group:GetDescendants()) do
   if not part:IsA('BasePart') then continue end
   local variant=part.MaterialVariant
   local color=part.Color
   local authored=oldFinish[variant]
   if authored then
    finish(part,authored[1],authored[2]:Lerp(color,.17))
   elseif group.Name=='WalkableRoutes' then
    local curb=part.Name:match('Curb$')
    finish(part,curb and material.Concrete or material.Pavement,curb and rgb(105,99,90) or rgb(151,139,114))
   elseif group.Name=='StudPackCliffs' then
    if variant=='Studs' then finish(part,material.Grass,rgb(100,109,72):Lerp(color,.17))
    elseif variant=='Universal' then finish(part,material.Sandstone,rgb(148,110,87):Lerp(color,.22)) end
   elseif group.Name=='WoodenMarketStalls' then
    if color.R>color.G*1.25 and color.G>color.B*1.2 then
     finish(part,material.WoodPlanks,rgb(123,98,74):Lerp(color,.22))
    else
     finish(part,material.CorrodedMetal,rgb(123,126,124):Lerp(color,.28))
    end
   elseif group.Name=='AssetScenery' or group.Name=='MarketGardens' then
    local prop=part.Parent.Name:lower()
    if prop:find('rock',1,true) then
     finish(part,material.Rock,rgb(109,110,107):Lerp(color,.16))
    elseif prop=='model' and variant=='' then
     finish(part,material.SmoothPlastic,color:Lerp(rgb(227,203,156),.16))
    elseif color.G>color.R and color.G>color.B then
     local tall=prop:find('tree2',1,true)
     local leaves=tall and 'QuarryFoliage_Evergreen' or 'QuarryFoliage_Canopy'
     finish(part,material.LeafyGrass,rgb(194,232,202):Lerp(color,.14),leaves)
    elseif prop:find('tree',1,true) then
     finish(part,material.Wood,rgb(233,225,215):Lerp(color,.13),'QuarryFoliage_Bark')
    end
   elseif part.Name=='ServiceDeck' or part.Parent.Name=='WornRouteSurfaces' then
    finish(part,material.Concrete,rgb(130,123,108))
   end
  end
 end
 for _,item in ipairs(terraces:GetDescendants()) do
  if item:IsA('Texture') and item.Name=='Checker Texture' and item.Texture=='rbxassetid://1372654506' then item:Destroy() end
 end
 for _,field in ipairs(scene.fields) do
  finish(field.part,material.Pebble,rgb(130,121,107):Lerp(field.part.Color,.24))
  local border=field.model:FindFirstChild('Border')
  if border and border:IsA('BasePart') then finish(border,material.Concrete,rgb(111,105,96):Lerp(border.Color,.25)) end
 end
 local depot=scene.map:FindFirstChild('SimpleFlatTestMap')
 if depot then
  for _,part in ipairs(depot:GetDescendants()) do
   if not part:IsA('BasePart') then continue end
   if part.Name:match('Pad$') then
    finish(part,material.Concrete,rgb(131,128,118):Lerp(part.Color,.21))
   elseif part.Name=='Printer' or part.Name=='PackStation' or part.Name=='PrestigeStation' then
    finish(part,material.CorrodedMetal,rgb(109,111,106):Lerp(part.Color,.28))
   end
  end
 end
 for _,part in ipairs(scene.map:GetChildren()) do
  if part:IsA('BasePart') and part.Name:match('Shop$') then
   finish(part,material.CorrodedMetal,rgb(112,115,111):Lerp(part.Color,.3))
  end
 end
 if scene.converter and scene.converter:IsA('BasePart') then
  finish(scene.converter,material.DiamondPlate,rgb(96,101,100))
 end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 if spawn then finish(spawn,material.Concrete,rgb(138,133,118)) end
 local fixtures=Instance.new('Folder');fixtures.Name='QuarryLights';fixtures.Parent=scene.map
 local routes=terraces:FindFirstChild('WalkableRoutes')
 local function fixture(name,frame,size,tint,range,strength)
  local lamp=block(fixtures,name,frame.Position,size,tint,material.Neon)
  lamp.CFrame=frame;lamp.CastShadow=false
  light(lamp,tint,range,strength)
 end
 for _,field in ipairs(scene.fields) do
  local key=field.cfg.Key
  local shop=scene.map:FindFirstChild(key..'Shop')
  local board=shop and shop:FindFirstChild('ShopSign')
  local tint=rgb(unpack(field.cfg.Color)):Lerp(rgb(247,245,233),.43)
  if board and board:IsA('BasePart') then
   local face=board:FindFirstChildWhichIsA('SurfaceGui')
   local front=face and face.Face==Enum.NormalId.Back and 1 or -1
   local frame=board.CFrame*CFrame.new(0,-board.Size.Y*.5-.08,front*(board.Size.Z*.5+.04))
   fixture(key..'ShopGlow',frame,Vector3.new(board.Size.X*.67,.16,.22),tint,17,1.3)
  end
  local ramp=routes and routes:FindFirstChild(key..'Ramp')
  if ramp and ramp:IsA('BasePart') then
   local frame=ramp.CFrame*CFrame.new(ramp.Size.X*.5+.17,ramp.Size.Y*.5+.16,0)
   fixture(key..'RampGlow',frame,Vector3.new(.24,.18,3.6),tint,13,1.25)
  end
 end
 for _,name in ipairs({'Printer','PackStation','PrestigeStation'}) do
  local station=scene.map:FindFirstChild(name,true)
  if station and station:IsA('BasePart') then
   local frame=station.CFrame*CFrame.new(0,station.Size.Y*.5+.07,-station.Size.Z*.32)
   fixture(station.Name..'Glow',frame,Vector3.new(station.Size.X*.62,.14,.24),rgb(164,232,248),15,1.2)
  end
 end
 QuarryBiomes.build(scene,terraces)
 return true
end
function W.ensureImpactField(root,fields)
 if root:GetAttribute('DronerevolutionMapVersion') and fields:FindFirstChild('ImpactTest') then return end
 local quartz=fields:FindFirstChild('Quartz');local source=quartz and quartz:FindFirstChild('Field')
 if not source then return end
 local cfg=Config.Fields[6]
 local model=fields:FindFirstChild(cfg.Key)
 if not model then
  model=Instance.new('Model');model.Name=cfg.Key;model.Parent=fields
  local bed=W.part(model,'Field',source.Position,Vector3.new(56,source.Size.Y,64),source.Color,Enum.Material.Slate)
  bed.Anchored=true;bed.CanCollide=true;bed.CanQuery=true
 end
 local bed=model:FindFirstChild('Field')
 local destination=source.Position+Vector3.new(source.Size.X/2+8+bed.Size.X/2,0,0)
 model:PivotTo(CFrame.new(destination-bed.Position)*model:GetPivot())
 model:SetAttribute('AlwaysUnlocked',true);model:SetAttribute('Mineral','Quartz');model:SetAttribute('DisplayName',cfg.Name)
 bed:SetAttribute('Mineral','Quartz')
 if not model:FindFirstChild('ImpactTestSign') then
  for _,side in ipairs({-1,1}) do
   local foot=W.part(model,'TestSignFoot',bed.Position+Vector3.new(side*5,1.5,-bed.Size.Z/2+1),Vector3.new(.3,3,.3),Color3.fromRGB(67,73,72),Enum.Material.Metal)
   foot.CanCollide=false
  end
  local board=W.part(model,'ImpactTestSign',bed.Position+Vector3.new(0,3,-bed.Size.Z/2+1),Vector3.new(13,3,.3),Color3.fromRGB(43,48,49),Enum.Material.Metal)
  textFace(board,'IMPACT TEST','10x ROCK HEALTH  /  ALWAYS OPEN',Color3.fromRGB(225,202,143))
 end
end
function W.layoutFields(root,fields,home)
 W.ensureImpactField(root,fields)
 -- Preserve the captured parts, machines and field identities. The former
 -- straight-line order placed Cobalt in front of spawn and Quartz at the end.
 -- Reuse the existing plot footprints, ordered by distance, then stagger the
 -- two right-hand plots so every later tier is farther from both depot and sell.
 if root:GetAttribute('PlotOrderVersion')~=1 and not root:GetAttribute('DronerevolutionMapVersion') then
  local slots={};local plots={}
  for id,cfg in ipairs(Config.Fields) do
   if cfg.TestField then continue end
   local model=fields:FindFirstChild(cfg.Key);local part=model and model:FindFirstChild('Field')
   assert(model and part and part:IsA('BasePart'),'Editable map is missing field '..cfg.Key)
   plots[id]={model=model,part=part};table.insert(slots,part.CFrame)
  end
  table.sort(slots,function(a,b)
   local ad=(a.Position-home).Magnitude;local bd=(b.Position-home).Magnitude
   if math.abs(ad-bd)<.01 then return a.Position.X<b.Position.X end
   return ad<bd
  end)
  for id,plot in ipairs(plots) do
   local target=slots[id]+Vector3.new(0,0,id==3 and 20 or id==5 and 40 or 0)
   local transform=target*plot.part.CFrame:Inverse()
   plot.model:PivotTo(transform*plot.model:GetPivot())
   plot.model:SetAttribute('Tier',id)
  end
  root:SetAttribute('PlotOrderVersion',1)
 end
 for id,cfg in ipairs(Config.Fields) do
  local model=fields:FindFirstChild(cfg.Key);local part=model:FindFirstChild('Field')
  model:SetAttribute('Tier',id);model:SetAttribute('FieldId',id);part:SetAttribute('FieldId',id)
  model:SetAttribute('AlwaysUnlocked',cfg.AlwaysUnlocked==true);model:SetAttribute('Mineral',cfg.Material or cfg.Key);part:SetAttribute('Mineral',cfg.Material or cfg.Key)
 end
end
local function finishEditableMap(root,map,fields,home)
 W.layoutFields(root,fields,home)
 if root:GetAttribute('DronerevolutionMapVersion') then return end
 -- Native Roblox surfaces provide readable material changes without global
 -- gloss: studded plastic trim, rough ore beds, paved lanes and metal machines.
 for _,part in ipairs(map:GetDescendants()) do if part:IsA('BasePart') then
  if part.Name=='HubPad' then nativeFinish(part,Enum.Material.Concrete);part.Color=Color3.fromRGB(179,175,139)
  elseif part.Name=='MainTestLane' or part.Name=='FieldTestLane' then nativeFinish(part,Enum.Material.Sandstone);part.Color=Color3.fromRGB(210,185,128)
  elseif part.Name:match('Pad$') then nativeFinish(part,Enum.Material.DiamondPlate)
  elseif part.Name=='Printer' or part.Name=='PackStation' or part.Name=='PrestigeStation' then nativeFinish(part,Enum.Material.Metal)
  else part.Reflectance=0 end
 end end
 local baseplate=workspace:FindFirstChild('Baseplate')
 if baseplate and baseplate:IsA('BasePart') then nativeFinish(baseplate,Enum.Material.Grass);baseplate.Color=Color3.fromRGB(86,142,74) end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 if spawn then nativeFinish(spawn,Enum.Material.Plastic,true) end
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then
  nativeFinish(converter,Enum.Material.DiamondPlate)
  for _,prompt in ipairs(converter:GetDescendants()) do if prompt:IsA('ProximityPrompt') then prompt.ActionText='Sell ore' end end
 end
 local converterName=map:FindFirstChild('ConverterName',true)
 if converterName then for _,text in ipairs(converterName:GetDescendants()) do if text:IsA('TextLabel') and (text.Text=='SELL YOUR CARGO' or text.Text=='DEPOSIT FOR LAUNCH') then text.Text='SELL ORE' end end end
 local lane=map:FindFirstChild('FieldTestLane',true)
 local finishes={Enum.Material.Sandstone,Enum.Material.Ground,Enum.Material.Slate,Enum.Material.Rock,Enum.Material.Grass}
 local beds={Color3.fromRGB(192,170,113),Color3.fromRGB(173,111,86),Color3.fromRGB(100,143,165),Color3.fromRGB(146,117,167),Color3.fromRGB(104,154,101)}
 for id,cfg in ipairs(Config.Fields) do
  local model=fields:FindFirstChild(cfg.Key);local part=model:FindFirstChild('Field')
  nativeFinish(part,finishes[id] or Enum.Material.Slate);part.Color=beds[id] or beds[1]
  local border=model:FindFirstChild('Border')
  if border and border:IsA('BasePart') then nativeFinish(border,Enum.Material.Plastic,true);border.Color=(beds[id] or beds[1]):Lerp(Color3.fromRGB(50,70,53),.5) end
  if lane and lane:IsA('BasePart') and not model:FindFirstChild('DepotApproach') then
   local nearEdge=part.Position.Z-part.Size.Z/2
   local laneEdge=lane.Position.Z+lane.Size.Z/2
   if nearEdge>laneEdge then
    local length=nearEdge-laneEdge+1
    local link=W.part(model,'DepotApproach',Vector3.new(part.Position.X,lane.Position.Y,laneEdge+length/2),Vector3.new(12,lane.Size.Y,length),lane.Color,Enum.Material.Pavement)
    link:SetAttribute('GeneratedDepotApproach',true);nativeFinish(link,Enum.Material.Pavement);solid(link)
   end
  end
 end
end
-- Dress the actual editable map, after the starter plot has reached its final
-- position. The old landscape planner belongs to the historical capture and
-- must not be used to cover this native map with a second world.
function W.landscapeEditable(scene)
 if scene.root:GetAttribute('DronerevolutionMapVersion') then return end
 if not scene.root:GetAttribute('EditableMap') then return end
 local previous=scene.map:FindFirstChild('QuarryLandscape')
 if previous and previous:GetAttribute('LandscapeVersion')==1 then return end
 if previous then previous:Destroy() end
 local landscape=Instance.new('Folder');landscape.Name='QuarryLandscape';landscape:SetAttribute('LandscapeVersion',1)
 local base=workspace:FindFirstChild('Baseplate')
 local floor=base and base.Position.Y+base.Size.Y/2 or 0
 local grass=Color3.fromRGB(102,155,77)
 local earth=Color3.fromRGB(120,99,70)
 local chalk=Color3.fromRGB(184,170,131)
 local foliage={Color3.fromRGB(84,143,67),Color3.fromRGB(159,124,63),Color3.fromRGB(71,133,126),Color3.fromRGB(113,115,160),Color3.fromRGB(62,133,89)}
 local keepClear={}
 for _,field in ipairs(scene.fields) do table.insert(keepClear,{part=field.part,padding=5}) end
 -- Treat every existing floor, building and lane as occupied. Decorations
 -- never cover a shop, mining footprint, display station or authored route.
 for _,part in ipairs(scene.map:GetDescendants()) do
  if part:IsA('BasePart') and part.Transparency<1 then table.insert(keepClear,{part=part,padding=3}) end
 end
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then table.insert(keepClear,{part=converter,padding=6}) end
 local function clear(x,z,w,d)
  -- The home effects previews are client-only and appear after this server
  -- pass. Reserve their two-column apron before any trees are planted.
  if math.abs(x-(scene.home.X+61))<w/2+25 and math.abs(z-(scene.home.Z-2))<d/2+35 then return false end
  if base and (math.abs(x-base.Position.X)+w/2>base.Size.X/2-5 or math.abs(z-base.Position.Z)+d/2>base.Size.Z/2-5) then return false end
  for _,entry in ipairs(keepClear) do
   local part=entry.part;local localPoint=part.CFrame:PointToObjectSpace(Vector3.new(x,part.Position.Y,z))
   -- Project the candidate's two diagonal corners into the original part's
   -- frame. This also conservatively clears any rotated authored footprint.
   local a=part.CFrame:PointToObjectSpace(Vector3.new(x+w/2,part.Position.Y,z+d/2))-localPoint
   local b=part.CFrame:PointToObjectSpace(Vector3.new(x-w/2,part.Position.Y,z+d/2))-localPoint
   local ex,ez=math.max(math.abs(a.X),math.abs(b.X)),math.max(math.abs(a.Z),math.abs(b.Z))
   if math.abs(localPoint.X)<part.Size.X/2+ex+entry.padding and math.abs(localPoint.Z)<part.Size.Z/2+ez+entry.padding then return false end
  end
  return true
 end
 local function piece(parent,name,x,z,w,h,d,tint,material,top,collide)
  local p=W.part(parent,name,Vector3.new(x,top-h/2,z),Vector3.new(w,h,d),tint,material)
  p.CanCollide=collide==true;p.CanQuery=collide==true;p.CastShadow=h>.4
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  return p
 end
 local function terrace(parent,x,z,w,d,h,tint)
  if not clear(x,z,w,d) then return false end
  piece(parent,'EarthBank',x,z,w,h,d,earth,Enum.Material.Ground,floor+h,true)
  piece(parent,'GrassShelf',x,z,w+.08,.22,d+.08,tint,Enum.Material.Grass,floor+h+.12,true)
  piece(parent,'ExposedStratum',x,z-d/2-.06,w-.8,.65,.16,chalk,Enum.Material.Sandstone,floor+h*.56,false)
  return true
 end
 for index,field in ipairs(scene.fields) do
  if field.cfg.TestField then continue end
  local p=field.part;local biome=Instance.new('Folder');biome.Name=field.cfg.Key..'Landscape'
  local x,z=p.Position.X,p.Position.Z;local halfX,halfZ=p.Size.X/2,p.Size.Z/2
  local tint=foliage[index] or grass
  -- Stacked rectangular cuts show local geology instead of an empty grey
  -- plane. Their fronts remain outside the rock and player travel footprint.
  local ridgeX,ridgeZ=x,z+halfZ+29
  local width,depth=p.Size.X+7,22
  if index==1 then ridgeX=x-halfX-27;ridgeZ=z;width=20;depth=p.Size.Z-16 end
  if terrace(biome,ridgeX,ridgeZ,width,depth,3.4,tint:Lerp(grass,.55)) then
   local upperX=ridgeX+(index==1 and -3 or 3);local upperZ=ridgeZ+3
   terrace(biome,upperX,upperZ,width-7,depth-7,7+index*.65,tint:Lerp(grass,.4))
   tree(biome,upperX-width*.2,upperZ,14+index,tint,floor+7+index*.65,.3*index)
   tree(biome,upperX+width*.23,upperZ+2,11+index,tint:Lerp(grass,.25),floor+7+index*.65,1.2+index)
  end
  -- A low grassy shoulder and two hand-placed trees form a compact grove.
  -- A failed clearance candidate is simply omitted, never pushed into a lane.
  for side=-1,1,2 do
   local tx,tz=x+side*(halfX+19),z+halfZ-8
   if clear(tx,tz,15,15) then
    piece(biome,'GroveSoil',tx,tz,15,.3,15,grass:Lerp(tint,.18),Enum.Material.Grass,floor+.24,false)
    tree(biome,tx,tz,12+index*.7,tint,floor,.5+index*side)
    for bush=1,3 do
     piece(biome,'LowBrush',tx+side*(3+bush),tz-5+bush*.7,3.2,1.2+bush*.25,2.7,tint:Lerp(grass,.25),Enum.Material.SmoothPlastic,floor+1.2+bush*.25,false)
    end
   end
  end
  -- Cobalt gets a shallow settling pond on its far outside shoulder; it is
  -- cosmetic, with a grounded stone lip and no deep-water movement trap.
  if field.cfg.Key=='Cobalt' then
   local px,pz=x+halfX+23,z+halfZ+9
   if clear(px,pz,20,16) then
    piece(biome,'SettlingPondBank',px,pz,20,.6,16,chalk,Enum.Material.Slate,floor+.55,true)
    piece(biome,'SettlingPondWater',px,pz,17,.12,13,Color3.fromRGB(59,157,176),Enum.Material.SmoothPlastic,floor+.62,false)
    for n=1,3 do piece(biome,'PondReed',px+6+n*.5,pz-4, .3,1+n*.4,.3,foliage[5],Enum.Material.SmoothPlastic,floor+1+n*.4,false) end
   end
  end
  biome.Parent=landscape
 end
 -- Backdrop behind the depot, leaving its machines and forward sightline open.
 for _,side in ipairs({-1,1}) do
  local x,z=scene.home.X+side*70,scene.home.Z-25
  if terrace(landscape,x,z,24,28,2.2,grass) then
   tree(landscape,x-side*4,z,17,foliage[1],floor+2.2,side*.6)
   tree(landscape,x+side*6,z+5,12,foliage[1]:Lerp(chalk,.12),floor+2.2,side*1.1)
  end
 end
 landscape.Parent=scene.map
 scene.root:SetAttribute('LandscapeDirection','Sunlit parts-built mineral quarry')
 scene.root:SetAttribute('LandscapePartCount',#landscape:GetDescendants())
end
local function restoreMiningFX()
 local rs=game:GetService('ReplicatedStorage')
 if rs:FindFirstChild('MiningFX') then return end
 -- The flat-map capture archived the original particles and contact glows.
 -- Replicate a disposable visual template; leave every preserved backup intact.
 for _,archive in ipairs(game:GetService('ServerStorage'):GetChildren()) do
  local original=archive:FindFirstChild('MiningFX')
  if original then
   local copy=original:Clone()
   for _,object in ipairs(copy:GetDescendants()) do
    if object:IsA('LuaSourceContainer') then object:Destroy()
    elseif object:IsA('ParticleEmitter') or object:IsA('Beam') then object.Enabled=false
    elseif object:IsA('BasePart') then object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false end
   end
   copy.Parent=rs;return
  end
 end
end
-- Keep the first field on the depot's center approach and respawn beside it.
-- Run before resources/turrets spawn; move the original model as one assembly.
function W.placeStart(scene)
 if scene.root:GetAttribute('DronerevolutionMapVersion') then
  local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
  scene.spawnPosition=spawn and spawn.Position or scene.home
  scene.root:SetAttribute('StarterField','Quartz')
  scene.root:SetAttribute('StarterSpawn',scene.spawnPosition)
  return
 end
 local home=scene.home;local pad=scene.map:FindFirstChild('HubPad',true)
 scene.root:SetAttribute('DepotHome',home)
 local quartz
 for _,field in ipairs(scene.fields) do if field.cfg.Key=='Quartz' then quartz=field;break end end
 if not quartz then return end
 local half=pad and pad.Size.Z/2 or 32
 local center=Vector3.new(home.X,quartz.part.Position.Y,home.Z+half+6+quartz.part.Size.Z/2)
 local target=CFrame.new(center)*quartz.part.CFrame.Rotation
 quartz.model:PivotTo(target*quartz.part.CFrame:Inverse()*quartz.model:GetPivot());quartz.center=quartz.part.Position
 local approach=quartz.model:FindFirstChild('DepotApproach')
 if approach and approach:GetAttribute('GeneratedDepotApproach') then approach:Destroy() end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local surface=pad and pad.Position.Y+pad.Size.Y/2 or home.Y
 local nearEdge=quartz.center.Z-quartz.part.Size.Z/2
 if pad then
  local edge=pad.Position.Z+pad.Size.Z/2
  if nearEdge>edge then
   local bridge=scene.map:FindFirstChild('QuartzApproach') or W.part(scene.map,'QuartzApproach',Vector3.zero,Vector3.one,pad.Color,Enum.Material.Pavement)
   bridge.Size=Vector3.new(12,pad.Size.Y,nearEdge-edge+1);bridge.CFrame=CFrame.new(home.X,pad.Position.Y,(nearEdge+edge)/2)
   bridge.CanCollide=true;bridge.CanQuery=true
  end
 end
 scene.spawnPosition=Vector3.new(home.X,surface+(spawn and spawn.Size.Y/2 or .5),nearEdge-10)
 if spawn then spawn.CFrame=CFrame.lookAt(scene.spawnPosition,Vector3.new(quartz.center.X,scene.spawnPosition.Y,quartz.center.Z)) end
 W.ensureImpactField(scene.root,scene.root:FindFirstChild('Fields'))
 for _,field in ipairs(scene.fields) do if field.cfg.TestField then field.center=field.part.Position end end
 scene.root:SetAttribute('StarterField','Quartz');scene.root:SetAttribute('StarterSpawn',scene.spawnPosition)
 W.landscapeEditable(scene)
end
function W.initialize(): any
 restoreMiningFX()
 Daylight.apply()
 -- The reference layout can clone its old dawn setter during startup.
 -- Reapply its fallback after those scripts run; the authored quarry is native.
 task.defer(Daylight.apply)
 local existing=workspace:FindFirstChild('MiningAway')
 if existing and existing:GetAttribute('EditableMap') then
  local map=existing:FindFirstChild('Map')
  local fields=existing:FindFirstChild('Fields')
  local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
  local hub=map and map:FindFirstChild('HubPad',true)
  local home=existing:GetAttribute('DepotHome') or (hub and hub.Position) or (spawn and spawn.Position) or Vector3.new(-56,.5,-11)
  assert(map and fields,'Editable map is missing required folders')
  finishEditableMap(existing,map,fields,home)
  local fieldMetadata={}
  for id,cfg in ipairs(Config.Fields) do
   local model=fields:FindFirstChild(cfg.Key)
   local part=model and model:FindFirstChild('Field')
   assert(model and part and part:IsA('BasePart'),'Editable map is missing field '..cfg.Key)
   table.insert(fieldMetadata,{id=id,cfg=cfg,center=part.Position,part=part,model=model})
  end
  local run=map:FindFirstChild('CrystalRun')
  local runStart,chargingStation
  if run then
   for i,tier in ipairs(Workshop.CRYSTAL_TIERS) do
    local original=Config.Fields[i]
    local model=run:FindFirstChild(original.Key)
    local part=model and model:FindFirstChild('Field')
    assert(part and part:IsA('BasePart') and part:GetAttribute('CrystalZone')==i,'Missing Crystal Run zone '..original.Key)
    local clusters={}
    for _,child in ipairs(model:GetChildren()) do
     if child:IsA('BasePart') and child:GetAttribute('CrystalCluster') then table.insert(clusters,child) end
    end
    table.sort(clusters,function(a,b) return a.Name<b.Name end)
    assert(#clusters==3,'Missing Mining Away patches in '..original.Key)
    local cfg={Name=original.Key,Key=original.Key,Material=tier.material,AlwaysUnlocked=true,SelectionOnly=true,
     Hardness=tier.hardness,Cracks=tier.cracks,Color=original.Color,ReferenceCrystals=true,Count=16*#clusters,Ore=10,Value=tier.value,Respawn=8+i-1,Turrets=0}
    local id=#fieldMetadata+1
    part:SetAttribute('FieldId',id);model:SetAttribute('FieldId',id)
    fieldMetadata[id]={id=id,cfg=cfg,center=part.Position,part=part,model=model,clusters=clusters}
    runStart=runStart or part.Position
   end
   chargingStation=run:FindFirstChild('ChargingStation')
   assert(chargingStation and chargingStation:IsA('BasePart'),'Missing Crystal Run charging station')
  end
  return {
   root=existing,map=map,home=home,
   printer=map:FindFirstChild('Printer',true),
   packStation=map:FindFirstChild('PackStation',true),
   prestigeStation=map:FindFirstChild('PrestigeStation',true),
   converter=workspace:FindFirstChild('Converter'),
   fields=fieldMetadata,runStart=runStart,chargingStation=chargingStation,
   turretTemplate=game:GetService('ServerStorage'):FindFirstChild('OriginalConstructTemplate'),
   droneTemplate=workspace:FindFirstChild('Drone'),
   crystalTemplate=workspace:FindFirstChild('Crystal')
  }
 end
 local cfg=Config
 local rs=game:GetService('ReplicatedStorage');local storage=game:GetService('ServerStorage')
 local root=Instance.new('Folder');root.Name='MiningAway';root.Parent=workspace
 local map=Instance.new('Folder');map.Name='Map';map.Parent=root
 for _,name in ipairs({'Fields','Drones','Resources','Turrets'}) do local f=Instance.new('Folder');f.Name=name;f.Parent=root end
 local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local home=spawn and spawn.Position or Vector3.new(-56,.5,-11)
 local plan=MapLayout.plan(cfg.Fields,{home.X,home.Y,home.Z})
 local archive=Instance.new('Folder');archive.Name='MiningAwayOriginalReference';archive.Parent=storage
 for _,name in ipairs({'FaceTest','Test','sphere','Mesh','Crystals','MiningEffect','Beam','Cat','potato'}) do
  local original=workspace:FindFirstChild(name);if original then original.Parent=archive end
 end
 -- These unlabelled top-level blocks are the old off-route construction experiment.
 -- Preserve their exact objects beside other reference props rather than leaving
 -- grey stairs and a giant beige slab in the composed landscape.
 for _,v in ipairs(workspace:GetChildren()) do
  if v:IsA('BasePart') and v.Name=='Part' then v.Parent=archive end
 end
 local construct=workspace:FindFirstChild('construct')
 assert(construct and construct:IsA('Model'),'The supplied source must retain Workspace.construct')
 local turretTemplate=construct:Clone();turretTemplate.Name='OriginalConstructTemplate';turretTemplate.Parent=storage
 finishConstruct(construct);construct:SetAttribute('DormantLandmark',true)
 local constructX,constructZ=plan:point(62,9)
 construct.PrimaryPart=construct:FindFirstChild('basepart');construct:PivotTo(CFrame.new(constructX,plan:surface(constructX,constructZ)+.5,constructZ))
 local baseplate=workspace:FindFirstChild('Baseplate')
 if baseplate and baseplate:IsA('BasePart') then cleanSurface(baseplate,archive);baseplate.Color=P.ground;baseplate.Material=Enum.Material.SmoothPlastic end
 if spawn then cleanSurface(spawn,archive);spawn.Color=P.ledge;spawn.Material=Enum.Material.Metal end
 -- Retain the author's simple parts-built trees, now under the same restrained palette.
 for _,model in ipairs(workspace:GetChildren()) do
  if model:IsA('Model') and model.Name=='Model' then
   -- Original trees were perched on the old abandoned test stairs. Keep the
   -- same two-part geometry, scale and ground it as a distant southern grove.
   local parts={};local low,high=math.huge,-math.huge;local anchor=nil
   for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then
    table.insert(parts,v);anchor=anchor or v.Position
    low=math.min(low,v.Position.Y-v.Size.Y/2);high=math.max(high,v.Position.Y+v.Size.Y/2)
   end end
   local scale=math.min(1,18/math.max(1,high-low))
   if anchor then for _,v in ipairs(parts) do
    local p=v.Position;v.Size=v.Size*scale
    v.CFrame=CFrame.new(anchor.X+(p.X-anchor.X)*scale,(p.Y-low)*scale,anchor.Z+(p.Z-anchor.Z)*scale)*v.CFrame.Rotation
   end end
   for _,v in ipairs(model:GetDescendants()) do
    if v:IsA('BasePart') then cleanSurface(v,archive);v.Material=Enum.Material.SmoothPlastic;v.Color=v.Size.Y>v.Size.X*1.7 and Color3.fromRGB(50,88,91) or Color3.fromRGB(107,182,159) end
   end
  end
 end
 HarborLighting.apply()
 Daylight.apply()
 local depot=solid(block(map,'DepotApron',Vector3.new(home.X,.1,home.Z),Vector3.new(40,.2,34),P.ivory:Lerp(P.ledge,.2),Enum.Material.SmoothPlastic));depot:SetAttribute('SafeDepot',true)
 -- Flush panel joints and painted corner brackets make one deliberate working yard.
 for _,x in ipairs({-10,0,10}) do block(map,'ApronJoint',Vector3.new(home.X+x,.215,home.Z),Vector3.new(.1,.02,32),P.stone) end
 for _,z in ipairs({-8,0,8}) do block(map,'ApronJoint',Vector3.new(home.X,.216,home.Z+z),Vector3.new(38,.02,.1),P.stone) end
 for _,dx in ipairs({-19,19}) do
  for _,dz in ipairs({-16,16}) do
   block(map,'YardPaint',Vector3.new(home.X+dx,.235,home.Z+dz*.86),Vector3.new(.18,.025,4),P.ivory)
   block(map,'YardPaint',Vector3.new(home.X+dx*.9,.235,home.Z+dz),Vector3.new(4,.025,.18),P.ivory)
  end
 end
 -- Rear service frame leaves the original follow ring and the route ahead open.
 for _,dx in ipairs({-17,17}) do
  block(map,'DepotPillar',Vector3.new(home.X+dx,5.8,home.Z-13),Vector3.new(.8,11.6,.8),P.metal,Enum.Material.Metal)
  local lamp=block(map,'DepotLamp',Vector3.new(home.X+dx,10.8,home.Z-12.5),Vector3.new(1.4,.4,.4),P.ivory,Enum.Material.Neon);light(lamp,P.ivory,22,.7)
 end
 block(map,'DepotLintel',Vector3.new(home.X,11.3,home.Z-13),Vector3.new(35,.8,1.2),P.edge,Enum.Material.Metal)
 block(map,'DepotCanopy',Vector3.new(home.X,12,home.Z-8),Vector3.new(38,.65,13),P.ivory,Enum.Material.SmoothPlastic)
 block(map,'CanopyInset',Vector3.new(home.X,11.64,home.Z-8),Vector3.new(34,.1,10),P.metal,Enum.Material.Metal)
 block(map,'DepotSunstripe',Vector3.new(home.X,12.36,home.Z-4),Vector3.new(31,.06,1.6),P.amber,Enum.Material.SmoothPlastic)
 local header=block(map,'DepotHeader',Vector3.new(home.X,10.7,home.Z-13.65),Vector3.new(12,1.9,.18),P.ink)
 textFace(header,'MINING AWAY','EXTRACTION DEPOT  /  01',P.ivory)
 local printer=station(map,'Printer',home+Vector3.new(12,-.5,-2),P.mint,'Free reprint','Printer')
 local packs=station(map,'PackStation',home+Vector3.new(-12,-.5,-2),P.blue,'Open pack','Pack')
 local prestige=station(map,'PrestigeStation',home+Vector3.new(0,-.5,-12),P.amber,'Review prestige','Prestige')
 local converter=workspace:FindFirstChild('Converter')
 if converter and converter:IsA('BasePart') then
  cleanSurface(converter,archive);converter.Color=P.metal;converter.Material=Enum.Material.Metal;converter:SetAttribute('Interaction','Sell')
  for _,v in ipairs(converter:GetChildren()) do if v:IsA('ProximityPrompt') then v:Destroy() end end
  local prompt=Instance.new('ProximityPrompt');prompt.ActionText='Sell ore';prompt.ObjectText='CONVERTER';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=converter
  local p=converter.Position;local half=converter.Size/2
  block(map,'ConverterCollar',Vector3.new(p.X,p.Y+half.Y-.3,p.Z),Vector3.new(converter.Size.X+1,.6,converter.Size.Z+1),P.edge,Enum.Material.Metal)
  for _,dx in ipairs({-.34,.34}) do
   block(map,'ConverterRib',Vector3.new(p.X+converter.Size.X*dx,p.Y,p.Z-half.Z-.15),Vector3.new(.45,converter.Size.Y*.85,.35),P.edge,Enum.Material.Metal)
  end
  block(map,'ConverterIntake',Vector3.new(p.X,p.Y,p.Z-half.Z-.3),Vector3.new(converter.Size.X*.5,converter.Size.Y*.42,.28),P.ink)
  block(map,'ConverterLight',Vector3.new(p.X,p.Y+half.Y*.42,p.Z-half.Z-.48),Vector3.new(converter.Size.X*.4,.18,.08),P.mint,Enum.Material.Neon)
  local name=block(map,'ConverterName',Vector3.new(p.X,p.Y+half.Y+1,p.Z-half.Z-.2),Vector3.new(7,1.6,.22),P.ink);textFace(name,'CONVERTER','SELL ORE',P.mint)
  block(map,'OreChute',Vector3.new(p.X,p.Y-half.Y+.6,p.Z-half.Z-2),Vector3.new(converter.Size.X*.7,1.2,3.5),P.ledge,Enum.Material.Metal)
 end
 local fields={};local originals=workspace:FindFirstChild('Patches')
 for id,field in ipairs(cfg.Fields) do
  local model=Instance.new('Model');model.Name=field.Key;model:SetAttribute('AlwaysUnlocked',field.AlwaysUnlocked==true);model:SetAttribute('Mineral',field.Material or field.Key);model:SetAttribute('FieldId',id);model:SetAttribute('Tier',id);model:SetAttribute('DisplayName',field.Name);model.Parent=root.Fields
  local part=originals and field.Original and originals:FindFirstChild(field.Original)
  if part and part:IsA('BasePart') then part.Parent=model
  else local o=field.Offset;part=block(model,'Field',home+Vector3.new(o[1],o[2],o[3]),Vector3.new(unpack(field.Size)),P.ground,Enum.Material.Ground) end
  -- Reposition the original patch objects with the rest of the compact valley.
  part.CFrame=CFrame.new(home+Vector3.new(unpack(field.Offset)));part.Size=Vector3.new(unpack(field.Size))
  cleanSurface(part,archive)
  local accent=Color3.fromRGB(unpack(field.Color))
  local beds={Color3.fromRGB(130,190,139),Color3.fromRGB(159,102,91),Color3.fromRGB(88,146,179),Color3.fromRGB(142,117,178),Color3.fromRGB(63,156,114)}
  part.Name='Field';part.Anchored=true;part.CanCollide=true;part.CanQuery=true;part.Color=beds[id] or beds[1];part.Material=Enum.Material.SmoothPlastic;part:SetAttribute('FieldId',id);part:SetAttribute('Patch',id)
  local top=part.Position.Y+part.Size.Y/2;local bottom=part.Position.Y-part.Size.Y/2
  -- The original raised Ruby patch is now visibly supported by a low layered mesa.
  if bottom>.4 then
   solid(block(model,'FieldBedrock',Vector3.new(part.Position.X,bottom/2,part.Position.Z),Vector3.new(part.Size.X+4,bottom,part.Size.Z+4),P.stone,Enum.Material.SmoothPlastic))
   solid(block(model,'FieldSkirt',Vector3.new(part.Position.X,bottom*.23,part.Position.Z),Vector3.new(part.Size.X+10,math.max(.4,bottom*.46),part.Size.Z+8),P.ledge,Enum.Material.SmoothPlastic))
   block(model,'ChalkCrown',Vector3.new(part.Position.X,bottom-.45,part.Position.Z),Vector3.new(part.Size.X+5,.65,part.Size.Z+5),P.ivory,Enum.Material.SmoothPlastic)
  end
  -- Signs stand on each actual field top, beside its incoming route.
  local shoulders={{-20,-11},{-20,-8},{-20,10},{-21,-8},{21,-8}}
  local shoulder=shoulders[id] or {0,-20};local edge=Vector3.new(part.Position.X+shoulder[1]*MapLayout.FieldScale,top,part.Position.Z+shoulder[2]*MapLayout.FieldScale)
  local subtitle=id==1 and 'SAFE  /  START HERE' or field.Turrets>0 and (id==3 and 'GUARDED  /  COMBAT CARDS' or 'GUARDED  /  '..field.RecommendedFleet..'+ DRONES') or 'SAFE  /  RICHER ORE'
  local facing=id>3 and fields[id-1].center or home
  solid(block(model,'SignTerrace',edge-Vector3.new(0,top/2,0),Vector3.new(9,math.max(.2,top),5),P.stone))
  sign(model,edge,string.format('%02d  %s',id,field.Name:upper()),subtitle,accent,facing)
  -- Short corner caps read as a footprint and leave every field side walkable.
  for _,x in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local corner=part.Position+Vector3.new(x*(part.Size.X/2+.3),top-part.Position.Y+.15,z*(part.Size.Z/2+.3))
   block(model,'FieldCorner',corner-Vector3.new(x*2.2,0,0),Vector3.new(4.4,.25,.42),P.ivory,Enum.Material.SmoothPlastic)
   block(model,'FieldCorner',corner-Vector3.new(0,0,z*2.2),Vector3.new(.42,.25,4.4),P.ivory,Enum.Material.SmoothPlastic)
   local beacon=block(model,'SurveyPin',corner+Vector3.new(0,.75,0),Vector3.new(.3,1.5,.3),P.metal,Enum.Material.Metal)
   block(model,'PinLight',beacon.Position+Vector3.new(0,.76,0),Vector3.new(.32,.16,.32),accent,Enum.Material.Neon)
  end end
  table.insert(fields,{id=id,cfg=field,center=part.Position,part=part,model=model})
 end
 -- The valley is one continuous stepped landform. Route and field cuts are
 -- calculated in the pure plan before geometry is emitted, leaving real corridors.
 local foliage={Color3.fromRGB(81,174,104),Color3.fromRGB(173,57,49),Color3.fromRGB(64,150,185),Color3.fromRGB(157,103,192),Color3.fromRGB(36,157,110)}
 local soils={Color3.fromRGB(112,171,112),Color3.fromRGB(158,104,83),Color3.fromRGB(103,165,174),Color3.fromRGB(148,129,173),Color3.fromRGB(64,147,107)}
 local terrain=Instance.new('Model');terrain.Name='ConnectedCliffs';terrain.Parent=map
 local batch=Instance.new('Model');batch.Name='SlopePatch';local facetCells=0
 for _,cell in ipairs(plan.terrain) do
  for _,face in ipairs(cell.faces) do
   local a,b,c=Vector3.new(face[1][1],face[1][2],face[1][3]),Vector3.new(face[2][1],face[2][2],face[2][3]),Vector3.new(face[3][1],face[3][2],face[3][3])
   local normal=(b-a):Cross(c-a).Unit
   local steep=math.abs(normal.Y)<.72
   local color=steep and (cell.biome==2 and Color3.fromRGB(111,76,70) or P.stone) or (soils[cell.biome] or soils[1])
   Facets.triangle(batch,a,b,c,color)
  end
  facetCells+=1
  if facetCells%40==0 then batch.Parent=terrain;task.wait();batch=Instance.new('Model');batch.Name='SlopePatch' end
 end
 batch.Parent=terrain
 for _,r in ipairs(plan.rocks) do
  local m=Instance.new('Model');m.Name='FracturedCliff';m.Parent=terrain
  local tint=r.biome==2 and Color3.fromRGB(112,76,70) or P.stone
  stone(m,Vector3.new(r.x,r.y+r.h*.32,r.z),Vector3.new(r.w,r.h*.8,r.d),{-5,r.yaw,4},tint,'CliffButtress')
  stone(m,Vector3.new(r.x-2,r.y+r.h*.75,r.z+1),Vector3.new(r.w*.72,r.h*.35,r.d*.8),{4,r.yaw+17,-8},tint:Lerp(P.ledge,.18),'BrokenCrown')
 end
 -- Built-in terrain decoration owns grass rendering and wind. No per-blade
 -- replication, client cloning, octrees or per-frame foliage work remains.
 NativeMeadow.build(plan,root)
 root:SetAttribute('TerrainStyle','Irregular slopes and fractured cliffs')
 local function v(a) return Vector3.new(unpack(a)) end
 local routes=Instance.new('Model');routes.Name='WindingRoutes';routes.Parent=map
 for _,r in ipairs(plan.routes) do
  local lane=Instance.new('Model');lane.Name=r.name;lane.Parent=routes
  for i=1,#r.samples-1 do
   local a,b=v(r.samples[i]),v(r.samples[i+1]);local trail=path(lane,a,b,r.width)
   trail:SetAttribute('RouteSegment',i);trail:SetAttribute('RouteName',r.name);trail:SetAttribute('RouteStart',a);trail:SetAttribute('RouteEnd',b);trail:SetAttribute('RouteWidth',r.width)
   -- Close the underside with contiguous earth supports, never a floating ramp.
   local flat=Vector3.new(b.X-a.X,0,b.Z-a.Z);local count=math.ceil(flat.Magnitude/3)
   for n=1,count do
    local t=(n-.5)/count;local at=a:Lerp(b,t)
    local top=at.Y-math.abs(b.Y-a.Y)/(count*2)-.18
    if top>.3 then
     local fill=solid(block(lane,'TrailEarth',Vector3.new(at.X,top/2,at.Z),Vector3.new(r.width-.3,top,flat.Magnitude/count+.08),P.stone))
     fill.CFrame=CFrame.lookAt(fill.Position,fill.Position+flat)
    end
   end
  end

 end
 local forest=Instance.new('Model');forest.Name='BiomeGroves';forest.Parent=map
 for _,t in ipairs(plan.trees) do
  local m=tree(forest,t.x,t.z,t.h,foliage[t.biome],t.ground,t.yaw)
  m.Name=t.biome==2 and 'AuburnTree' or 'MineralTree';m:SetAttribute('Biome',t.biome)
 end
 -- Small parts-built landmarks and dense undergrowth reward the bends. All
 -- dressing is outside the resource clearings; it never substitutes for an ore node.
 local props=Instance.new('Model');props.Name='ValleyDetails';props.Parent=map
 local siteX,siteZ,targetX,targetZ
 local function site(x,z,biome)
  siteX,siteZ=x,z
  if biome then targetX,targetZ=plan:biomePoint(biome,x,z) else targetX,targetZ=plan:point(x,z) end
 end
 local function at(x,y,z) return Vector3.new(targetX+x-siteX,y+plan.dy,targetZ+z-siteZ) end
 local function groundAt(x,z) local p=at(x,0,z);return plan:surface(p.X,p.Z) end
 local function prop(name,x,y,z,sx,sy,sz,color,turn,collide)
  local p=block(props,name,at(x,y,z),Vector3.new(sx,sy,sz),color,Enum.Material.SmoothPlastic,turn and {0,math.rad(turn),0})
  if collide then solid(p) end
  return p
 end
 -- Ruby mine: actual walk-in recess at the foot of a rising cliff. The
 -- playable crystal field remains in front, with no roof over its drone stations.
 site(-88,66,2)
 for _,x in ipairs({-99,-77}) do
  prop('RubyPortalRock',x,22,66,7,18,9,Color3.fromRGB(112,70,66),x==-99 and -8 or 8,true)
  prop('MineTimber',x==-99 and -95 or -81,19,62.5,1.1,12,1.3,Color3.fromRGB(92,65,52),0,true)
 end
 prop('RubyLintel',-88,30,67,27,6,11,Color3.fromRGB(158,98,85),0,true)
 prop('MineCrossbeam',-88,25,62.5,15,1.4,1.5,Color3.fromRGB(111,75,51),0,true)
 prop('MineShadow',-88,20.5,70.8,14,14.5,.2,Color3.fromRGB(34,35,43))
 prop('MineFloor',-88,12.7,66,15,.6,11,P.stone,0,true)
 for _,x in ipairs({-92.5,-83.5}) do
  local lamp=prop('AmberMineLamp',x,22.5,61.6,.8,1,.7,P.amber);light(lamp,P.amber,13,.6)
 end
 for i=1,6 do prop('MineSleeper',-88,13.08,62+i*1.15,8,.18,.5,Color3.fromRGB(98,70,51)) end
 for _,x in ipairs({-90.8,-85.2}) do prop('OreRail',x,13.22,66.2,.16,.16,9,P.metal) end
 -- A little ore trolley and abandoned hand tools, built from the same simple parts.
 site(-63,35,2)
 local cartX,cartZ=-63,35;local cartGround=groundAt(cartX,cartZ)
 prop('OreCart',cartX,cartGround+2,cartZ,4,2.5,3,P.metal,14)
 prop('CartOre',cartX,cartGround+3.3,cartZ,3.5,.5,2.5,P.coral,14)
 for _,x in ipairs({cartX-1.6,cartX+1.6}) do for _,z in ipairs({cartZ-1,cartZ+1}) do
  local wheel=prop('CartWheel',x,cartGround+.6,z,.5,1.2,1.2,P.ink);wheel.Shape=Enum.PartType.Cylinder
 end end
 -- Walkable overlook sits above the grove; one short sign replaces floating text.
 site(-65,77)
 prop('OverlookDeck',-65,33.8,77,13,.6,12,P.ledge,0,true)
 for _,z in ipairs({72,82}) do
  prop('LookoutRail',-65,36,z,13,.35,.35,P.metal)
  for _,x in ipairs({-71,-65,-59}) do prop('LookoutPost',x,35,z,.35,2.5,.35,P.metal) end
 end
 sign(props,at(-65,34,81),'RUBY LOOKOUT','GROVE BELOW',P.coral,at(-87,13,46))
 -- A narrow aqueduct/waterfall gives the upper pass an unmistakable silhouette.
 site(-12,-101)
 local aqueductY=math.max(groundAt(-20,-101),groundAt(-4,-101))+12
 for _,x in ipairs({-20,-4}) do prop('AqueductPier',x,aqueductY-6,-101,3.5,12,5,P.ledge,0,true) end
 prop('AqueductLintel',-12,aqueductY,-101,21,2.5,6,P.ivory,0,true)
 prop('WaterChannel',-12,aqueductY+1.3,-101,19,.2,2.5,Color3.fromRGB(82,193,216))
 prop('WaterSpout',-21,aqueductY+.8,-97.5,2,1,10,P.ledge)
 prop('SpoutWater',-21,aqueductY+1.35,-97.5,1.2,.15,10,Color3.fromRGB(82,193,216))
 local poolGround=groundAt(-21,-94)
 local fallTop=aqueductY+1.3;local fallHeight=fallTop-poolGround
 local fall=prop('MineralWaterfall',-21,poolGround+fallHeight/2,-94,1.1,fallHeight,3.2,Color3.fromRGB(81,190,208));fall.Transparency=.25
 prop('PoolBank',-21,poolGround+.11,-94,11,.2,12,P.ledge)
 prop('PoolWater',-21,poolGround+.24,-94,9,.12,10,Color3.fromRGB(54,154,181))
 -- Emerald's preserved segmented construct crowns the ridge as a dormant landmark.
 site(62,9)
 local constructGround=groundAt(62,9)
 prop('ConstructPlinth',62,constructGround-.5,9,13,1,13,P.ledge,0,true)
 prop('ConstructBedrock',62,constructGround/2,9,13,constructGround,13,P.stone,0,true)
 -- Leaf/flower clusters, fungi, fallen trunks and survey equipment occupy the
 -- negative space around trees. Deterministic placement keeps repeat builds equal.
 for i,t in ipairs(plan.trees) do
  for n=1,4 do
   local angle=i*2.1+n*1.7;local x=t.x+math.cos(angle)*(3+n);local z=t.z+math.sin(angle)*(3+n)
   if plan:routeClear(x,z,1.8) and plan:fieldClear(x,z,2) then
    local ground=plan:surface(x,z);local color=foliage[t.biome]
    block(props,'Undergrowth',Vector3.new(x,ground+.65,z),Vector3.new(2.2,1.3,1.8),color:Lerp(P.ground,.4),Enum.Material.SmoothPlastic,{0,angle,.15})
    local stem=block(props,'FlowerStem',Vector3.new(x+.8,ground+1.3,z+.3),Vector3.new(.18,1.5,.18),P.metal)
    local blossom=block(props,n%2==0 and 'MineralBloom' or 'ShelfFungus',stem.Position+Vector3.new(0,.8,0),Vector3.new(n%2==0 and .8 or 1.8,.3,n%2==0 and .8 or 1.8),n%2==0 and P.ivory or color:Lerp(P.amber,.35))
    if n%2==1 then blossom.CFrame=blossom.CFrame*CFrame.Angles(0,angle,0) end
   end
  end
 end
 -- Deliberate little discoveries along the lower loop, never new interaction UI.
 site(-102,-9)
 for i=1,4 do
  local x,z=-108+i*3,-12+i*1.5;local y=groundAt(x,z)
  prop('SurveyCrate',x,y+1.2,z,2.4,2.4,2.4,i%2==0 and P.amber or P.edge,i*13)
  prop('CrateBand',x,y+1.2,z,2.45,.32,2.45,P.ivory,i*13)
 end
 -- Giant flat-capped alien fungi mark the first route, without copying the reference's assets.
 for _,m in ipairs({{-8,3,6},{-3,43,8},{-50,54,5}}) do
  local x,z,h=m[1],m[2],m[3];site(x,z);local y=groundAt(x,z)
  prop('FungusStalk',x,y+h/2,z,1,h,1,P.ledge)
  prop('FungusCap',x,y+h,z,h*.9,1.3,h*.75,P.amber,-8)
  prop('FungusCrown',x-.5,y+h+.9,z,h*.55,.6,h*.5,P.ivory,4)
 end
 site(-24,-50)
 surveyGate(map,at(-24,10,-50),P.blue)
 root:SetAttribute('TreeCount',#plan.trees);root:SetAttribute('RouteCount',#plan.routes);root:SetAttribute('MapScale',MapLayout.Scale);root:SetAttribute('OpenHubRadius',46)
 root:SetAttribute('SourceSceneIntegrated',true);root:SetAttribute('FieldCount',#fields);root:SetAttribute('ArtDirection','Alabaster Valley / Open Meadows / Outer Groves')
 return {root=root,map=map,home=home,printer=printer,packStation=packs,prestigeStation=prestige,converter=converter,fields=fields,turretTemplate=turretTemplate,droneTemplate=rs:FindFirstChild('Drone'),crystalTemplate=rs:FindFirstChild('Crystal')}
end
return W


end)()
local Logistics = (function()
-- Typed mineral storage and permanent transport ownership for the existing game.
-- Currency changes use working-copy transactions; ordinary mining deposits are
-- non-yielding and become part of the next fenced profile save.
local L: any={CAPACITY=120,LAUNCH_SECONDS=6,CARRIER_PRICE=1500,BACKPACK_PRICE=750}
local materials={'Quartz','Ruby','Cobalt','Violet','Emerald'}
local mineral={Quartz=true,Ruby=true,Cobalt=true,Violet=true,Emerald=true}
for _,tier in ipairs(Workshop.CRYSTAL_TIERS) do
 if not mineral[tier.material] then
  table.insert(materials,tier.material);mineral[tier.material]=true
 end
end
local miningRoles={Striker=true,Charger=true,Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local function integer(n: any): any return type(n)=='number' and n==n and n>=0 and n<1e14 and n%1==0 end
local function clone(t: any): any local out={};for k,v in pairs(t or {}) do out[k]=type(v)=='table' and clone(v) or v end;return out end
function L.bagUnits(bag: any): any local n=0;for _,v in pairs(bag or {}) do n+=v end;return n end
local function validBag(bag: any): any
 if type(bag)~='table' then return false end
 local total=0
 for k,v in pairs(bag) do if not mineral[k] or not integer(v) then return false end;total+=v;if not integer(total) then return false end end
 return true
end
local function take(bag: any, maximum: any): (any, any)
 local out,remaining={},maximum
 for _,key in ipairs(materials) do
  local n=math.min(remaining,bag[key] or 0)
  if n>0 then out[key]=n;bag[key]-=n;remaining-=n;if bag[key]==0 then bag[key]=nil end end
 end
 return out,maximum-remaining
end
local function add(bag: any, other: any): () for k,n in pairs(other) do bag[k]=(bag[k] or 0)+n end end
local function runState(p: any): any return p.run and p.run.logistics end
local function ownedState(p: any): any return p.logistics end
local function findCarrier(p: any, id: any): any
 for _,c in ipairs(p.logistics.carriers) do if c.id==id then return c end end
 return nil
end
local function permanent(p: any, id: any): any
 for _,d in ipairs(p.fleet or {}) do if d.id==id then return d end end
 return nil
end

function L.depositInto(p: any, bag: any, capacity: any): (any, any)
 local state=runState(p);capacity=capacity or L.CAPACITY
 if not state or not validBag(bag) or not integer(capacity) then return {},0 end
 local copy=clone(bag);local accepted,units=take(copy,math.max(0,capacity-L.bagUnits(state.storage)))
 add(state.storage,accepted);return accepted,units
end
function L.depositMineral(p: any, key: any, amount: any, capacity: any): any
 if not mineral[key] or not integer(amount) then return 0 end
 local _,accepted=L.depositInto(p,{[key]=amount},capacity);return accepted
end
function L.beginLaunch(p: any, capacity: any): (any, any)
 local state=runState(p);capacity=capacity or L.CAPACITY
 if not state or not integer(capacity) or capacity<1 then return false,'Storage unavailable' end
 if L.bagUnits(state.launchCargo)>0 then return false,'A cargo capsule is already in flight' end
 if L.bagUnits(state.storage)<capacity then return false,'Fill storage before launching' end
 state.launchCargo=take(state.storage,capacity);state.launchRemaining=L.LAUNCH_SECONDS
 return true,{units=capacity,runId=p.run.id,launch=p.logistics.launches+1}
end
function L.finishLaunch(p: any, values: any): (any, any)
 local state=runState(p)
 if not state or L.bagUnits(state.launchCargo)==0 then return false,'No launch is pending' end
 if state.launchRemaining>0 then return false,'Cargo capsule is still in flight' end
 local units,earnings=L.bagUnits(state.launchCargo),0
 for key,n in pairs(state.launchCargo) do
  local value=Shops.oreValue(values,key) or 1
  if not mineral[key] or not integer(n) or type(value)~='number' or value<0 or value~=value then return false,'Invalid launch manifest' end
  earnings+=n*value
 end
 earnings=math.floor(earnings)
 if not integer(earnings) or not integer(p.run.saleEarnings+earnings) then return false,'Launch earnings limit reached' end
 local manifest=clone(state.launchCargo)
 local deposited,quartz=Shops.deposit(p.run,manifest);if not deposited then return false,quartz end
 p.run.credits=p.run.wallet.Quartz;p.run.saleEarnings+=earnings;p.run.quartzEarnings+=quartz
 state.launchCargo={};state.launchRemaining=0;p.logistics.launches+=1
 return true,{units=units,earnings=earnings,cargo=manifest,runId=p.run.id,launch=p.logistics.launches}
end
function L.pickupBackpack(p: any, capacity: any): (any, any)
 local state=runState(p)
 if not state or not p.logistics.backpack or not integer(capacity) or capacity<1 then return false,'Flying backpack unavailable' end
 if L.bagUnits(state.backpackCargo)>0 then return false,'Flying backpack is still carrying cargo' end
 if L.bagUnits(p.run.cargo)<capacity then return false,'Backpack is not full yet' end
 state.backpackCargo=take(p.run.cargo,capacity)
 return true,{units=L.bagUnits(state.backpackCargo),runId=p.run.id}
end
function L.deliverBackpack(p: any, capacity: any): any
 local state=runState(p);if not state then return 0 end
 local accepted,units=L.depositInto(p,state.backpackCargo,capacity)
 for key,n in pairs(accepted) do state.backpackCargo[key]-=n;if state.backpackCargo[key]==0 then state.backpackCargo[key]=nil end end
 return units
end
function L.buy(p: any, kind: any): (any, any)
 if not ownedState(p) then return false,'Transport ownership unavailable' end
 local price=kind=='Carrier' and L.CARRIER_PRICE or (kind=='Backpack' and L.BACKPACK_PRICE or nil)
 if not price then return false,'Unknown transport' end
 if kind=='Carrier' and #p.logistics.carriers>=3 then return false,'Carrier limit reached: three carriers' end
 if kind=='Backpack' and p.logistics.backpack then return false,'You already own a flying backpack' end
 if p.run.wallet.Quartz<price then return false,'Need '..price..' Quartz' end
 p.run.wallet.Quartz-=price;p.run.credits=p.run.wallet.Quartz
 if kind=='Backpack' then p.logistics.backpack=true;return true,{kind=kind,price=price} end
 local id=tostring(p.userId)..':carrier:'..p.logistics.nextCarrier;p.logistics.nextCarrier+=1
 table.insert(p.logistics.carriers,{id=id,droneIds={}})
 return true,{kind=kind,id=id,price=price}
end
function L.loadCarrier(p: any, id: any, ids: any): (any, any)
 if type(id)~='string' or type(ids)~='table' then return false,'Invalid loadout' end
 local c=findCarrier(p,id);if not c then return false,'Unknown carrier' end
 local count=0;for k in pairs(ids) do if type(k)~='number' or k%1~=0 or k<1 or k>4 then return false,'A carrier holds at most four miners' end;count+=1 end
 local selected={}
 for i=1,count do
  local key=ids[i];local d=type(key)=='string' and permanent(p,key)
  if not d or selected[key] then return false,'Select distinct owned permanent miners' end
  if not miningRoles[d.role] then return false,'Carriers deploy mining drones' end
  for _,other in ipairs(p.logistics.carriers) do if other.id~=id and table.find(other.droneIds,key) then return false,'Unload that miner from its other carrier first' end end
  selected[key]=true
 end
 c.droneIds=clone(ids);return true,{id=id,count=count}
end

function L.new(ctx: any): any
 local system: any={};local runtime: any,slots: any={},{}
 local C,W=ctx.C,ctx.W
 local capacity=C.StorageCapacity or L.CAPACITY
 local function profile(p: any): any return ctx.data(p) end
 local function canDeploy(p: any, field: any): any
  if not field then return false end
  if ctx.canDeploy then return ctx.canDeploy(p,field) end
  if ctx.canMine then return ctx.canMine(p,field) end
  local saved=profile(p)
  local unlocked=field.cfg.AlwaysUnlocked or not ctx.Shops or ctx.Shops.unlocked(saved,field.cfg.Key)
  return unlocked and (field.cfg.Turrets==0 or field.e.phase=='Cleared' or saved.clearedFields[field.cfg.Key]==true)
 end
 local function healthy(p: any): any
  if ctx.healthy then return ctx.healthy(p) end
  return not p.busy and not p.leaving
 end
 local function hr(p: any): any return ctx.characterRoot and ctx.characterRoot(p) or nil end
 local function announce(p: any, text: any): () if ctx.notice then ctx.notice(p,text) else p.player:SetAttribute('MA_Notice',text) end end
 local function dirty(p: any): () p.dirty=true;p.publishDirty=true end
 local function model(name: any, owner: any, class: any): any
  local m=Instance.new('Model');m.Name=name;m:SetAttribute('Owner',owner);m:SetAttribute('Class',class);m.Parent=ctx.root;return m
 end
 local function v(x: any, y: any, z: any): any return Vector3.new(x,y,z) end
 local ink=Color3.fromRGB(31,43,52);local gold=Color3.fromRGB(255,195,75);local cyan=Color3.fromRGB(95,226,222);local pale=Color3.fromRGB(218,233,221)
 local function part(m: any, name: any, pos: any, size: any, color: any, mat: any): any return W.part(m,name,pos,size,color,mat or Enum.Material.SmoothPlastic) end
 local function move(m: any, pos: any, force: any?): ()
  local now=ctx.getClock()
  if not force and now-(m:GetAttribute('PoseAt') or -math.huge)<.1 then return end
  local cf=CFrame.new(pos)
  local moving=m:GetAttribute('Pose')~=cf
  if not force and not moving and m:GetAttribute('PoseMoving')~=true then return end
  -- One final stationary sample cancels prediction after arrival.
  if moving then m:PivotTo(cf);m:SetAttribute('Pose',cf) end
  m:SetAttribute('PoseMoving',moving);m:SetAttribute('PoseAt',now)
 end
 local function approach(pos: any, goal: any, dt: any, speed: any): (any, any)
  local delta=goal-pos;local n=delta.Magnitude;if n<.001 then return goal,true end
  local step=math.min(n,dt*speed);return pos+delta/n*step,n<=step+.15
 end
 local function carrierAttrs(c: any): ()
  for _,target in ipairs({c.model,c.metadata}) do
   target:SetAttribute('State',c.state);target:SetAttribute('Patch',c.field or 0);target:SetAttribute('FieldId',c.field or 0)
   target:SetAttribute('LoadedIds',table.concat(c.ids,','));target:SetAttribute('LoadedCount',#c.ids)
  end
 end
 local function makeCarrier(p: any, rt: any, saved: any): any
  local at=rt.base+v(-8,6,-7);local m=model('Carrier_'..saved.id,p.player.UserId,'Carrier')
  local body=part(m,'Frame',at,v(8.5,.75,7),ink,Enum.Material.Metal);m.PrimaryPart=body
  part(m,'Spine',at+v(0,.5,0),v(.8,1.2,7.8),gold,Enum.Material.Metal)
  for i=1,4 do
   local x=i%2==1 and -2.6 or 2.6;local z=i<=2 and -2 or 2
   part(m,'Bay'..i,at+v(x,.6,z),v(2.4,.2,2.4),cyan,Enum.Material.Neon)
   part(m,'Engine'..i,at+v(x*1.45,-.25,z),v(1.1,1.2,1.2),gold,Enum.Material.Metal)
   part(m,'Jet'..i,at+v(x*1.45,-1,z),v(.7,.5,.8),cyan,Enum.Material.Neon)
  end
  m:SetAttribute('CarrierId',saved.id);m:SetAttribute('Capacity',4)
  local meta=Instance.new('Folder');meta.Name=saved.id;meta:SetAttribute('CarrierId',saved.id);meta:SetAttribute('Owner',p.player.UserId);meta:SetAttribute('Class','Carrier');meta.Parent=rt.metadata
  local c={id=saved.id,model=m,metadata=meta,pos=at,state='Home',ids=clone(saved.droneIds),field=nil,lives={},dead={}}
  rt.carriers[c.id]=c;carrierAttrs(c);move(m,at);return c
 end
 local function makeBackpack(p: any, rt: any): ()
  local at=rt.base+v(6,5,0);local m=model('FlyingBackpack_'..p.player.UserId,p.player.UserId,'Backpack')
  local body=part(m,'Pack',at,v(2.1,2.6,1.25),gold,Enum.Material.Metal);m.PrimaryPart=body
  part(m,'Pocket',at+v(0,-.35,-.8),v(1.7,1.1,.45),ink)
  for _,s in ipairs({-1,1}) do
   part(m,'Strap',at+v(s*.65,0,.75),v(.2,2.1,.2),pale)
   part(m,'Thruster',at+v(s*1.2,-.65,0),v(.5,.7,.65),ink,Enum.Material.Metal)
   part(m,'Jet',at+v(s*1.2,-1.15,0),v(.32,.45,.4),cyan,Enum.Material.Neon)
  end
  rt.backpack={model=m,pos=at,state='Follow'};move(m,at)
 end
 local function request(p: any, label: any, mutate: any, after: any?, fixedId: any?): any
  if not healthy(p) or not ctx.transact then return false end
  local runId=profile(p).run.id
  local id=fixedId or ('logistics:'..label..':'..ctx.guid())
  return ctx.transact(p,id,function(copy: any): (any, any)
   if copy.run.id~=runId then return nil,'Run changed' end
   local ok,result=mutate(copy)
   if not ok then return nil,result end
   return result or {runId=runId},nil
  end,function(result: any)
   system:refresh(p);if after then after(result) end;p.publishDirty=true
  end)
 end
 local function returnCarrier(p: any, c: any): ()
  for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==p.player.UserId then ctx.recall(d);d.deployedCarrier=false end end
  c.field=nil;c.state='Return';c.lives={};carrierAttrs(c)
 end
 function system:create(p: any): ()
  if runtime[p.player.UserId] then self:refresh(p);return end
  local slot=1;while slots[slot] do slot+=1 end;slots[slot]=p.player.UserId
  -- A compact pad joins the depot's existing ground; existing map geometry stays intact.
  local base=ctx.origin+v(((slot-1)%3-1)*21,0,-26-math.floor((slot-1)/3)*21)
  if ctx.root:GetAttribute('DronerevolutionMapVersion') then
   local surface=ctx.root:GetAttribute('LogisticsSurfaceHeight') or 4
   if slot<=9 then
    base=v(((slot-1)%3-1)*21,surface+.5,66+math.floor((slot-1)/3)*21)
   else
    local index=slot-10
    local row=math.floor(index/12)
    local rowZ=152+row*21
    base=v(-115.5+(index%12)*21,surface+.5,rowZ)
    local map=ctx.root:FindFirstChild('Map')
    local terraces=map and map:FindFirstChild('DronerevolutionTerraces')
    assert(terraces,'Authored map is missing DronerevolutionTerraces')
    local overflow=terraces:FindFirstChild('LogisticsOverflow')
    if not overflow then
     overflow=Instance.new('Folder');overflow.Name='LogisticsOverflow';overflow.Parent=terraces
    end
    local function floorPart(parent: any,name: string,position: Vector3,size: Vector3,color: Color3,material: Enum.Material): ()
     local floor=Instance.new('Part');floor.Name=name;floor.Size=size;floor.Position=position
     floor.Anchored=true;floor.CanCollide=true;floor.CanQuery=true;floor.CanTouch=false
     floor.Material=material;floor.Color=color
     W.applyQuarryVariant(floor)
     floor.TopSurface=Enum.SurfaceType.Smooth;floor.BottomSurface=Enum.SurfaceType.Smooth
     floor:SetAttribute('AuthoredMapSurface',true);floor:SetAttribute('GeneratedLogisticsFloor',true)
     floor.Parent=parent
    end
    local function floorAssembly(name: string,x: number,z: number,width: number,depth: number): ()
     if overflow:FindFirstChild(name) then return end
     local assembly=Instance.new('Model');assembly.Name=name
     floorPart(assembly,'ApronSurface',v(x,surface-.5,z),v(width,1,depth),Color3.fromRGB(230,226,215),Enum.Material.Concrete)
     floorPart(assembly,'EarthSupport',v(x,surface-2.75,z),v(width,3.5,depth),Color3.fromRGB(229,223,211),Enum.Material.Sandstone)
     assembly.Parent=overflow
    end
    -- Shared rows persist for this server, including when their first owner leaves.
    -- The static apron ends at Z=126; this flush bridge meets row one's Z=141.5 edge.
    floorAssembly('EntryWalk',0,133.75,14,15.5)
    for connectedRow=0,row do
     floorAssembly('Row_'..tostring(connectedRow+1),0,152+connectedRow*21,260,21)
    end
   end
  end
  local function groundAt(x: any, z: any): any
   return ctx.groundHeight and ctx.groundHeight(x,z) or ctx.origin.Y-.5
  end
  -- Later player pads extend onto the existing hills. Level the entire pad
  -- above its highest footprint sample without cutting into authored terrain.
  local baseY=ctx.origin.Y
  for _,x in ipairs({-9,0,9}) do
   for _,z in ipairs({-9,0,9}) do baseY=math.max(baseY,groundAt(base.X+x,base.Z+z)+.5) end
  end
  base=v(base.X,baseY,base.Z)
  local rt={base=base,slot=slot,carriers={},runId=profile(p).run.id,nextPublish=0}
  runtime[p.player.UserId]=rt
  local metadata=Instance.new('Folder');metadata.Name='MA_Logistics';metadata.Parent=p.player;rt.metadata=metadata
  local building=model('OrbitalStorage_'..p.player.UserId,p.player.UserId,'Storage');rt.building=building
  local pad=part(building,'LaunchPad',base,v(18,1,18),ink,Enum.Material.Metal);pad.CanCollide=true;pad.CanQuery=true;building.PrimaryPart=pad
  for _,x in ipairs({-7.5,7.5}) do
   for _,z in ipairs({-7.5,7.5}) do
    local ground=groundAt(base.X+x,base.Z+z);local height=base.Y-.5-ground
    if height>.2 then
     local support=part(building,'FoundationSupport',v(base.X+x,ground+height/2,base.Z+z),v(1.2,height,1.2),ink,Enum.Material.Metal)
     support.CanCollide=true;support.CanQuery=true
    end
   end
  end
  for _,s in ipairs({-1,1}) do
   part(building,'Gantry',base+v(s*5.5,4.5,-6),v(.5,8,.5),gold,Enum.Material.Metal)
   part(building,'Signal',base+v(s*5.5,8.8,-6),v(.7,.7,.7),cyan,Enum.Material.Neon)
  end
  part(building,'Crossbar',base+v(0,8.4,-6),v(11,.5,.5),ink,Enum.Material.Metal)
  rt.label=W.label(pad,'ORBITAL STORAGE',v(0,10,0));rt.label.Parent.MaxDistance=42
  local cm=model('LaunchCapsule_'..p.player.UserId,p.player.UserId,'Capsule');rt.capsule=cm;rt.capsuleBase=base+v(0,3.7,0)
  local body=part(cm,'CargoPod',rt.capsuleBase,v(4.4,5,4.4),pale,Enum.Material.Metal);cm.PrimaryPart=body
  local nose=part(cm,'Nose',rt.capsuleBase+v(0,2.6,0),v(4.4,4.4,4.4),gold,Enum.Material.Metal);nose.Shape=Enum.PartType.Ball
  rt.jet=part(cm,'Exhaust',rt.capsuleBase+v(0,-3.7,0),v(2,3,2),cyan,Enum.Material.Neon);rt.jet.Transparency=1
  move(cm,rt.capsuleBase)
  for _,entry in ipairs({{'Deposit','Deposit cargo',Enum.KeyCode.E},{'LaunchStorage','Launch full storage',Enum.KeyCode.F}}) do
   local prompt=Instance.new('ProximityPrompt');prompt.Name=entry[1];prompt.ActionText=entry[2];prompt.ObjectText='Orbital storage';prompt.KeyboardKeyCode=entry[3];prompt.MaxActivationDistance=14;prompt.RequiresLineOfSight=false;prompt.Parent=pad
   if prompt.Triggered then prompt.Triggered:Connect(function(who: any) if who==p.player then self:command(p,entry[1]) end end) end
  end
  self:refresh(p)
 end
 function system:refresh(p: any): ()
  local rt=runtime[p.player.UserId];if not rt then return end
  local saved=profile(p);local current={}
  if rt.runId~=saved.run.id then
   rt.runId=saved.run.id
   for _,c in pairs(rt.carriers) do returnCarrier(p,c);c.state='Home';c.pos=rt.base+v(-8,6,-7);c.dead={} end
  end
  for _,record in ipairs(saved.logistics.carriers) do
   local c=rt.carriers[record.id] or makeCarrier(p,rt,record)
   local same=#c.ids==#record.droneIds
   if same then for i,id in ipairs(c.ids) do if record.droneIds[i]~=id then same=false;break end end end
   if not same then
    for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==p.player.UserId then d.carrierId=nil;d.deployedCarrier=false end end
    c.ids=clone(record.droneIds);c.dead={}
   end
   current[c.id]=true
   for _,id in ipairs(c.ids) do
    local d=ctx.drones[id]
    if d and d.owner==p.player.UserId then d.carrierId=c.id;if c.state~='Working' or c.dead[id] then d.deployedCarrier=false end end
   end
   carrierAttrs(c)
  end
  for id,c in pairs(rt.carriers) do if not current[id] then c.model:Destroy();c.metadata:Destroy();rt.carriers[id]=nil end end
  if saved.logistics.backpack and not rt.backpack then makeBackpack(p,rt) end
  if not saved.logistics.backpack and rt.backpack then rt.backpack.model:Destroy();rt.backpack=nil end
  p.publishDirty=true
 end
 function system:capacity(p: any): any return math.max(0,capacity-L.bagUnits(profile(p).run.logistics.storage)) end
 function system:storagePosition(p: any): any local rt=runtime[p.player.UserId];return rt and rt.base+v(6,4,0) or ctx.origin end
 function system:deposit(p: any, key: any, amount: any): (any, any)
  if not healthy(p) then return 0,nil end
  if type(key)=='table' then local bag,n=L.depositInto(profile(p),key,capacity);if n>0 then dirty(p) end;return bag,n end
  local n=L.depositMineral(profile(p),key,amount,capacity);if n>0 then dirty(p) end;return n,nil
 end
 function system:station(d: any): any
  if not d.carrierId then return nil end
  local rt=runtime[d.owner];local c=rt and rt.carriers[d.carrierId]
  if not c then d.carrierId=nil;d.deployedCarrier=false;return nil end
  if c.dead[d.id] then d.deployedCarrier=false;return ctx.origin+v(0,7,0) end
  if d.deployedCarrier and c.state=='Working' and d.field==c.field and c.lives[d.id]==d.life then return nil end
  d.deployedCarrier=false
  for i,id in ipairs(c.ids) do if id==d.id then return c.pos+v(i%2==1 and -2.6 or 2.6,2,i<=2 and -2 or 2) end end
  d.carrierId=nil;return nil
 end
 function system:atHome(d: any): any
  local rt=runtime[d.owner];local c=rt and d.carrierId and rt.carriers[d.carrierId]
  return c~=nil and (c.state=='Home' or c.dead[d.id]==true)
 end
 function system:view(p: any): any
  local rt=runtime[p.player.UserId];local out={}
  for id,c in pairs(rt and rt.carriers or {}) do out[id]={state=c.state,field=c.field or 0,droneIds=clone(c.ids)} end
  return out
 end
 function system:decorate(p: any): any
  local saved=profile(p);local s=saved.run.logistics
  return {Storage=L.bagUnits(s.storage),StorageCapacity=capacity,LaunchCargo=L.bagUnits(s.launchCargo),LaunchRemaining=s.launchRemaining,BackpackCargo=L.bagUnits(s.backpackCargo),HasBackpack=saved.logistics.backpack,Carriers=#saved.logistics.carriers,CarrierCount=#saved.logistics.carriers,AutoLaunch=saved.logistics.autoLaunch,Launches=saved.logistics.launches}
 end
 function system:save(p: any): any return clone(profile(p).run.logistics) end
 function system:remove(p: any): ()
  local rt=runtime[p.player.UserId];if not rt then return end
  for _,c in pairs(rt.carriers) do
   for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==p.player.UserId then d.carrierId=nil;d.deployedCarrier=false end end
   c.model:Destroy()
  end
  if rt.backpack then rt.backpack.model:Destroy() end
  rt.building:Destroy();rt.capsule:Destroy();rt.metadata:Destroy();slots[rt.slot]=nil;runtime[p.player.UserId]=nil
 end
 function system:command(p: any, action: any, value: any): any
  local rt=runtime[p.player.UserId]
  if not rt or not healthy(p) or not hr(p) then return false end
  local saved=profile(p);local state=saved.run.logistics
  local function reject(text: any): any announce(p,text);return true end
  local function nearStorage(): any
   return ctx.inHome(p) or (ctx.atDepotStation and ctx.atDepotStation(p)) or (hr(p).Position-rt.base).Magnitude<22
  end
  if action=='BuyCarrier' or action=='BuyBackpack' then
   if value~=nil then return true end
   if not ctx.inHome(p) then return reject('Return to the depot to buy transport.') end
   local kind=action=='BuyCarrier' and 'Carrier' or 'Backpack'
   request(p,'buy'..kind,function(copy: any) return L.buy(copy,kind) end,function() announce(p,kind=='Carrier' and 'Carrier ready. Load up to four permanent miners at the depot.' or 'Flying backpack ready. It collects your full bag and returns it to storage.') end)
  elseif action=='Deposit' or action=='Sell' then
   if value~=nil then return true end
   if not nearStorage() then return reject('Return to your storage or the depot to deposit cargo.') end
   if L.bagUnits(saved.run.cargo)==0 then return reject('Your backpack is empty.') end
   if self:capacity(p)==0 then return reject('Storage is full. Launch its cargo before depositing more.') end
   request(p,'deposit',function(copy: any)
    local accepted,n=L.depositInto(copy,copy.run.cargo,capacity)
    for k,units in pairs(accepted) do copy.run.cargo[k]-=units;if copy.run.cargo[k]==0 then copy.run.cargo[k]=nil end end
    return n>0,{units=n}
   end,function(result: any) announce(p,'Deposited '..result.units..' ore. Full storage can launch into space.') end)
  elseif action=='LaunchStorage' then
   if value~=nil then return true end
   if not nearStorage() then return reject('Return to your storage or the depot to launch cargo.') end
   if L.bagUnits(state.launchCargo)>0 then return reject('A cargo capsule is already in flight.') end
   if L.bagUnits(state.storage)<capacity then return reject('Fill storage before launching: '..L.bagUnits(state.storage)..' / '..capacity..'.') end
   request(p,'launch',function(copy: any) return L.beginLaunch(copy,capacity) end,function() rt.capsule:SetAttribute('LaunchedAt',ctx.getClock());announce(p,'Cargo launched. Its minerals enter their matching shop balances in space.') end)
  elseif action=='AutoLaunch' then
   if type(value)~='boolean' then return true end
   if not ctx.inHome(p) then return reject('Return to the depot to change automatic launching.') end
   request(p,'auto',function(copy: any) copy.logistics.autoLaunch=value;return true,{enabled=value} end,function() announce(p,value and 'Automatic storage launching enabled.' or 'Automatic storage launching disabled.') end)
  elseif action=='LoadCarrier' then
   if type(value)~='table' or type(value.carrierId)~='string' or type(value.droneIds)~='table' then return true end
   local c=rt.carriers[value.carrierId];if not c then return true end
   local check=clone(saved);local ok,reason=L.loadCarrier(check,value.carrierId,value.droneIds)
   if not ok then return reject(reason) end
   if not ctx.inHome(p) then return reject('Return to the depot to change a carrier loadout.') end
   if c.state~='Home' then return reject('Recall this carrier and wait for it to reach the depot first.') end
   for _,id in ipairs(value.droneIds) do local d=ctx.drones[id];if not d or d.hp<=0 or d.field then return reject('Recall the selected miners and wait for any reprints before loading.') end end
   local ids=clone(value.droneIds);local id=value.carrierId
   request(p,'load',function(copy: any) return L.loadCarrier(copy,id,ids) end,function() c.dead={};announce(p,'Carrier loadout saved: '..#ids..' / 4 miners.') end)
  elseif action=='CarrierPatch' then
   if type(value)~='table' or type(value.carrierId)~='string' or type(value.patch)~='number' or value.patch%1~=0 then return true end
   local c=rt.carriers[value.carrierId];local field=ctx.patches[value.patch];if not c or not field then return true end
   if c.state=='Working' and c.field==field.id then return reject('This carrier is already working that field.') end
   if #c.ids==0 then return reject('Load up to four permanent miners into this carrier at the depot.') end
   if (hr(p).Position-field.center).Magnitude>(C.CommandRadius or 95) then return reject('Walk closer to the field before dispatching the carrier.') end
   if c.state~='Home' and c.state~='Working' then return reject('The carrier is still travelling. Wait until it arrives or returns home.') end
   if not canDeploy(p,field) then return reject('Unlock this field and clear its guards before sending a carrier.') end
   returnCarrier(p,c);c.field=field.id;c.state='Travel';c.dead={};carrierAttrs(c);announce(p,'Carrier dispatched. Its miners deploy on arrival and keep working when you leave.')
  elseif action=='RecallCarrier' then
   if type(value)~='string' then return true end
   local c=rt.carriers[value];if c then returnCarrier(p,c);announce(p,'Carrier returning to the depot.') end
  else return false end
  return true
 end
 function system:tick(dt: any): ()
  for owner,rt in pairs(runtime) do
   local p=ctx.profiles[owner]
   if p and healthy(p) then
    local saved=profile(p);if rt.runId~=saved.run.id then self:refresh(p);saved=profile(p) end
    local state=saved.run.logistics;local now=ctx.getClock()
    if self:capacity(p)>0 and L.bagUnits(state.pendingCargo)>0 then
     local accepted,n=L.depositInto(saved,state.pendingCargo,capacity)
     for k,units in pairs(accepted) do state.pendingCargo[k]-=units;if state.pendingCargo[k]==0 then state.pendingCargo[k]=nil end end
     if n>0 then dirty(p) end
    end
    if L.bagUnits(state.launchCargo)>0 then
     state.launchRemaining=math.max(0,state.launchRemaining-dt);p.dirty=true
     local t=1-state.launchRemaining/L.LAUNCH_SECONDS
     move(rt.capsule,rt.capsuleBase+v(0,t*t*240,0));rt.jet.Transparency=.15
     rt.capsule:SetAttribute('Manifest',L.bagUnits(state.launchCargo))
     if state.launchRemaining==0 then
      if request(p,'launchFinish',function(copy: any) return L.finishLaunch(copy,ctx.prices) end,function() rt.jet.Transparency=1;rt.capsule:SetAttribute('Manifest',0);move(rt.capsule,rt.capsuleBase,true);announce(p,'Cargo reached space. Matching mineral balances credited.') end,'logisticsPay:'..saved.run.id..':'..(saved.logistics.launches+1)) then continue end
     end
    else rt.jet.Transparency=1;rt.capsule:SetAttribute('Manifest',0);move(rt.capsule,rt.capsuleBase) end
    if healthy(p) and saved.logistics.autoLaunch and L.bagUnits(state.launchCargo)==0 and L.bagUnits(state.storage)>=capacity then
     if request(p,'autoLaunch',function(copy: any) return L.beginLaunch(copy,capacity) end,function() rt.capsule:SetAttribute('LaunchedAt',ctx.getClock()) end) then continue end
    end
    local bp=rt.backpack
    if healthy(p) and bp then
     local playerRoot=hr(p);local cargo=L.bagUnits(state.backpackCargo);local full=L.bagUnits(saved.run.cargo)>=(ctx.capacityOf and ctx.capacityOf(saved) or C.Capacity)
     local goal
     if cargo>0 then goal=self:storagePosition(p);bp.state=self:capacity(p)>0 and 'Deliver' or 'StorageFull'
     else goal=(playerRoot and playerRoot.Position or ctx.origin)+v(3,5,3);bp.state=full and 'Collect' or 'Follow' end
     local arrived;bp.pos,arrived=approach(bp.pos,goal,dt,30);move(bp.model,bp.pos);bp.model:SetAttribute('State',bp.state);bp.model:SetAttribute('Cargo',cargo)
     if arrived and cargo>0 and self:capacity(p)>0 then
      if request(p,'backpackDeliver',function(copy: any) local n=L.deliverBackpack(copy,capacity);return n>0,{units=n} end) then continue end
     elseif arrived and cargo==0 and full and playerRoot then
      if request(p,'backpackCollect',function(copy: any) return L.pickupBackpack(copy,ctx.capacityOf and ctx.capacityOf(copy) or C.Capacity) end) then continue end
     end
    end
    for _,c in pairs(rt.carriers) do
     for _,id in ipairs(c.ids) do
      local d=ctx.drones[id]
      if d and (d.hp<=0 or (c.lives[id] and c.lives[id]~=d.life)) then c.dead[id]=true;d.deployedCarrier=false end
     end
     if c.state=='Travel' then
      local field=c.field and ctx.patches[c.field]
      if not field then returnCarrier(p,c)
      else
       local arrived;c.pos,arrived=approach(c.pos,field.center+v(0,15,12),dt,25)
       if arrived then
        local fleet={}
        for _,id in ipairs(c.ids) do local d=ctx.drones[id];if d and d.owner==owner and d.hp>0 and not c.dead[id] then table.insert(fleet,d) end end
        if #fleet>0 and ctx.assignFleet(p,field,fleet) then
         c.state='Working';for _,d in ipairs(fleet) do d.deployedCarrier=true;c.lives[d.id]=d.life end
        else returnCarrier(p,c);announce(p,'Carrier returned: unlock the field and clear its guards before deployment.') end
       end
      end
     elseif c.state=='Return' then
      local arrived;c.pos,arrived=approach(c.pos,rt.base+v(-8,6,-7),dt,25)
      if arrived then c.state='Home';c.dead={} end
     elseif c.state=='Working' and not canDeploy(p,ctx.patches[c.field]) then returnCarrier(p,c) end
     carrierAttrs(c);move(c.model,c.pos)
    end
    if now>=rt.nextPublish then
     rt.nextPublish=now+.25
     if state.launchRemaining>0 then p.publishDirty=true end
     rt.label.Text=string.format('ORBITAL STORAGE\n%d / %d%s',L.bagUnits(state.storage),capacity,L.bagUnits(state.launchCargo)>0 and ' · IN FLIGHT' or '')
     for _,piece in ipairs(rt.building:GetChildren()) do if piece.Name=='Signal' then piece.Color=L.bagUnits(state.storage)>=capacity and gold or cyan end end
     for key,value in pairs(self:decorate(p)) do p.player:SetAttribute('MA_'..key,value) end
    end
   end
  end
 end
 return system
end
return L

end)()
local PackDelivery = (function()
-- One replicated delivery per paid, sealed offer. Only the owner can open it.
local Delivery = {}
Delivery.__index = Delivery
local lanes={0,1,-1,2,-2,3,-3}

local function flat(vector)
 return Vector3.new(vector.X, 0, vector.Z)
end

local function supportsCrate(position, forward, sideways, ground, ray)
 for _,x in ipairs({-.96,.96}) do
  for _,z in ipairs({-.82,.82}) do
   local corner=position+forward*x+sideways*z
   local hit=workspace:Raycast(corner+Vector3.yAxis*4,-Vector3.yAxis*16,ray)
   if not hit or math.abs(hit.Position.Y-ground)>.18 then return false end
  end
 end
 return true
end

function Delivery.new(options)
 local folder = Instance.new('Folder')
 folder.Name = 'PackDeliveries'
 folder.Parent = options.root
 return setmetatable({options=options, folder=folder}, Delivery)
end

function Delivery:landing(buyerPosition)
 local o=self.options
 local counter=o.station
 local station=counter.Position
 local direction=flat(buyerPosition-station)
 if direction.Magnitude<.1 then direction=flat(o.home-station) end
 if direction.Magnitude<.1 then direction=Vector3.new(0,0,1) end
 local forward=direction.Unit
 local sideways=Vector3.new(-forward.Z,0,forward.X)
 local localDirection=counter.CFrame:PointToObjectSpace(station+forward)
 local edge=math.min(counter.Size.X*.5/math.max(.001,math.abs(localDirection.X)),counter.Size.Z*.5/math.max(.001,math.abs(localDirection.Z)))
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Exclude
 local ignored={self.folder}
 for _,player in ipairs(o.players:GetPlayers()) do if player.Character then table.insert(ignored,player.Character) end end
 ray.FilterDescendantsInstances=ignored
 ray.RespectCanCollide=true
 local floorY=station.Y-counter.Size.Y*.5
 local position,score=nil,math.huge
 local occupiedCrates=self.folder:GetChildren()
 for _,setback in ipairs({1.6,4.4}) do
  local center=station+forward*(edge+setback)
  for _,lane in ipairs(lanes) do
   local candidate=center+sideways*lane*2.8
   if flat(buyerPosition-candidate).Magnitude<2.4 then continue end
   local occupied=false
   for _,other in ipairs(occupiedCrates) do
    if flat(other.Position-candidate).Magnitude<2.6 then occupied=true;break end
   end
   if occupied then continue end
   local hit=workspace:Raycast(candidate+Vector3.yAxis*4,-Vector3.yAxis*16,ray)
   if not hit and o.requireGround then continue end
   local ground=hit and hit.Position.Y or o.groundHeight(candidate.X,candidate.Z)
   if hit and (hit.Normal.Y<.88 or math.abs(ground-floorY)>1.4) then continue end
   local landing=Vector3.new(candidate.X,ground+.56,candidate.Z)
   local distance=(buyerPosition-landing).Magnitude
   if distance>=score then continue end
   local blocked=workspace:Raycast(buyerPosition,landing-buyerPosition,ray)~=nil
   local cost=distance+(blocked and Packs.Range*2 or 0)
   if cost>=score then continue end
   if o.requireGround and not supportsCrate(candidate,forward,sideways,ground,ray) then continue end
   position,score=landing,cost
  end
  if score<=Packs.Range-2 then break end
 end
 return position,sideways
end

function Delivery:spawn(p, offer, buyerPosition, now)
 if not offer or offer.opened~=false or p.leaving or p.packDelivery then return end
 local o=self.options
 local position,sideways=self:landing(buyerPosition)
 if not position then return end
 local part=World.part(nil,'CompanyPack',position,Vector3.new(1.9,1.4,1.6),Color3.new())
 part.Transparency=1
 part:SetAttribute('OfferId',offer.id)
 part:SetAttribute('Owner',p.player.UserId)
 part:SetAttribute('Approach',sideways)
 part:SetAttribute('DeliveryAt',now)
 local prompt=Instance.new('ProximityPrompt')
 prompt.Name='OpenPack';prompt.ActionText='Open pack';prompt.ObjectText='Company delivery'
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
 prompt.MaxActivationDistance=Packs.Range;prompt.RequiresLineOfSight=false
 prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
 prompt.HoldDuration=0;prompt.Enabled=false;prompt.Parent=part
 local delivery={part=part,prompt=prompt,id=offer.id,tier=offer.packTier,readyAt=now+Packs.DeliveryTime}
 p.packDelivery=delivery
 prompt.Triggered:Connect(function(player)
  if player~=p.player or delivery.opening or not self:canOpen(p,delivery,o.getClock()) then return end
  delivery.opening=true;prompt.Enabled=false
  o.open(p,delivery.id,function(status)
   if p.packDelivery~=delivery then return end
   if status=='rejected' then delivery.opening=false
   elseif status=='accepted' then self:reveal(delivery,o.getClock()) end
  end)
 end)
 part.Parent=self.folder
end

function Delivery:clear(p)
 local delivery=p.packDelivery
 if delivery then delivery.part:Destroy();p.packDelivery=nil end
end

function Delivery:canOpen(p, delivery, now)
 local o=self.options
 local offer=o.offer(p)
 if not offer or offer.id~=delivery.id or offer.opened~=false or now<delivery.readyAt or not o.healthy(p) or o.inAssault(p) then return false end
 local hr=o.characterRoot(p)
 return hr and (hr.Position-delivery.part.Position).Magnitude<=Packs.Range
end

function Delivery:reveal(delivery,now)
 delivery.openedAt=now
 delivery.part:SetAttribute('Tier',delivery.tier)
 delivery.part:SetAttribute('OpenedAt',now)
end

function Delivery:step(p, now)
 if p.leaving then return end
 local o=self.options
 local offer=o.offer(p)
 local delivery=p.packDelivery
 if not delivery then
  if offer and offer.opened==false and o.healthy(p) then
   local hr=o.characterRoot(p)
   local near=hr and (hr.Position-o.station.Position).Magnitude<20
   if near and now>=(p.nextPackDelivery or 0) then
    p.nextPackDelivery=now+1
    self:spawn(p,offer,hr.Position,now)
   end
  end
  return
 end
 if not offer or offer.id~=delivery.id then self:clear(p);return end
 if offer.opened~=false then
  if not delivery.openedAt then
   self:reveal(delivery,now)
  elseif now-delivery.openedAt>1.15 then self:clear(p) end
  return
 end
 if now>=delivery.readyAt and not delivery.ready then delivery.ready=true;delivery.part:SetAttribute('Ready',true) end
 delivery.prompt.Enabled=delivery.ready==true and not delivery.opening
end

return Delivery

end)()
-- Server simulation, validated intent, and durable profile boundaries.
-- The builder lexically provides Config/Feel/Mining/Rules/Profile/Cards/Persistence/World.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Debris=game:GetService('Debris')
local RoleConfig: any,RoleEffects: any,DiscoveryService: any=DroneConfig,DroneRoleEffects,MiningDiscoveries
local C: any,R: any=Config,Rules
local Pro: any,Ca: any=Profile,Cards
local scene: any=World.initialize()
World.placeStart(scene)
World.applyQuarryTextures(scene)
local root,home=scene.root,scene.home
root:SetAttribute('FieldToolsEnabled',scene.runStart==nil)
if scene.runStart then
 root:SetAttribute('PackCounterPosition',scene.packStation.Position)
 local depot=scene.map:FindFirstChild('SimpleFlatTestMap')
 local floor=depot and depot:FindFirstChild('HubPad')
 if floor and floor:IsA('BasePart') then
  scene.depotFloor=floor
  root:SetAttribute('DepotFloorFrame',floor.CFrame);root:SetAttribute('DepotFloorSize',floor.Size)
 end
end
local function folder(parent,name)
 local f=Instance.new('Folder');f.Name=name;f.Parent=parent;return f
end
local droneFolder=root:FindFirstChild('Drones') or folder(root,'Drones')
local net=folder(RS,'MiningAway')
local command=Instance.new('RemoteEvent');command.Name='Command';command.Parent=net
-- Runtime entity graphs are mutually recursive. Keep their dynamic Roblox
-- boundaries explicit rather than expanding an unbounded inferred table type.
local profiles: {[number]: any}={}
local drones: {[string]: any}={}
local swarmGrid: any=nil
local patches: {any}={}
local resources: {[string]: any}={}
local logistics: any=nil
local consumableService: any=nil
scene.loading={}
-- At most one replacement Player may wait per user. A reconnect cannot acquire
-- another lease until the retiring local session is saved and released.
scene.pendingJoins={}
local now=workspace:GetServerTimeNow()
local elapsed,snapshotElapsed,autosaveElapsed=0,0,0
local seed=Random.new()
local instanceId=(game.JobId~='' and game.JobId or Http:GenerateGUID(false))
local inStudio=RunService:IsStudio()
local preview=inStudio or game.GameId==0
-- Runtime-only test perks: never add cards, upgrades or fleet ownership to a save.
local testPerks={scope='Fleet',effects={plotAuto=1,capacity=C.Capacity/Ca.BASE_CAPACITY-1}}
local function previewPerks(p) return p and p.testFleet and testPerks or nil end
local adapter
if preview then adapter=Persistence.previewAdapter('MiningAwayPreview:'..instanceId)
else adapter=Persistence.dataStore(game:GetService('DataStoreService'):GetDataStore('MiningAwayProfiles_v2')) end
local store=Persistence.new(adapter,{
 owner=instanceId,now=os.time,wait=task.wait,leaseSeconds=180,maxAttempts=3,
 newProfile=function(uid)
  local profile=Pro.new(uid,seed:NextInteger(1,2147483000),scene.runStart and RoleConfig or nil)
  -- Studio starts with the real earned Quartz economy; no free workshop money.
  return profile
 end,
 migrate=function(data,uid) return Pro.migrate(data,uid) end,validate=Pro.validate,
})
root:SetAttribute('PersistenceMode',preview and 'PREVIEW • isolated temporary profiles' or 'DataStore • session-locked')
root:SetAttribute('Build','restore-feel-prestige')
local function data(p: any): any return p.session.data end
local function healthy(p: any) return p and not p.leaving and not p.busy and store:healthy(p.session) end
local function notice(p,message)
 if p.player.Parent then p.player:SetAttribute('MA_Notice',message) end
end
local function publish(p)
 if not p.player.Parent then return end
 local copy={}
 for key,value in pairs(data(p)) do if key~='seed' and key~='receipts' then copy[key]=Pro.clone(value) end end
 copy.capacity=Ca.capacity(copy,previewPerks(p));copy.cargoUnits=Pro.cargoUnits(copy);copy.nextPackPrice=Ca.price(copy);copy.packSpeed=Shops.packSpeed(copy);copy.packCurrency=Shops.PACK_CURRENCY;copy.prestigePreview=Pro.prestigePreview(data(p))
 copy.workshop=Ca.workshopRows(copy)
 p.magnetRange=OreDrops.MAGNET_RANGE+Ca.magnetBonus(copy);p.cargoReach=13+Ca.magnetBonus(copy)
 p.fieldCharge=Workshop.effect(copy,'fieldCharge')
 p.compactorBatch=Workshop.compactorBatch(copy)
 p.shiftSeconds=Workshop.effect(copy,'shiftRelay')
 p.vacuumReach=Workshop.starLevel(copy,'vacuum')>0 and 76 or 64
 copy.storageCapacity=Logistics.CAPACITY
 if logistics and logistics.view then copy.logisticsStates=logistics:view(p) end
 copy.deliveryUnits=0;copy.deliveryQuartz=scene.runStart and Pro.deliveryQuartz(copy) or 0
 for _,manifest in pairs(copy.run.deliveries) do
  for _,units in pairs(manifest.cargo) do copy.deliveryUnits+=units end
 end
 -- The active preview crew is presentation data, never permanent ownership.
 if scene.runStart or p.testFleet or Workshop.starLevel(copy,'vacuum')>0 or Workshop.starLevel(copy,'cultivator')>0 then
  copy.activeFleet=Pro.clone(scene.runtimeFleet(p))
 end
 copy.testCrewActive=p.testFleet~=nil
 copy.droneStats={};copy.droneRoles={};for _,d in ipairs(p.drones) do copy.droneStats[d.id]=d.stats;copy.droneRoles[d.id]=d.role end
 local autoMine,autoHaul=scene.runStart~=nil,Workshop.starLevel(copy,'autosell')>0
 for _,d in ipairs(p.drones) do
  autoMine=autoMine or (DroneRoles.isWorker(d.role) and (d.stats.plotAuto or 0)>0);autoHaul=autoHaul or d.role=='Courier'
 end
 p.player:SetAttribute('BackpackUnits',copy.cargoUnits);p.player:SetAttribute('BackpackCapacity',copy.capacity)
 p.player:SetAttribute('StorageUnits',Logistics.bagUnits(copy.run.logistics.storage))
 p.player:SetAttribute('StorageCapacity',Logistics.CAPACITY)
 p.player:SetAttribute('LaunchCargoUnits',Logistics.bagUnits(copy.run.logistics.launchCargo))
 p.player:SetAttribute('AutomationMineEnabled',autoMine);p.player:SetAttribute('AutomationHaulEnabled',autoHaul)
 p.player:SetAttribute('QueuedOreCount',#(p.oreQueue or {}))
 p.player:SetAttribute('QueuedOreIds',Http:JSONEncode(p.oreQueue or {}))
 copy.seed=nil;copy.receipts=nil
 if scene.runStart then copy.consumables=nil end
 if copy.run.pendingOffer then
  copy.run.pendingOffer.seed=nil
  if copy.run.pendingOffer.opened==false then copy.run.pendingOffer.choices=nil end
 end
 copy.saveMode=preview and 'Preview — temporary profiles' or 'Saved profile';copy.pendingTransaction=p.busy or p.session.readOnly or false
 p.player:SetAttribute('MA_Profile',Http:JSONEncode(copy))
 if scene.fieldTools then scene.fieldTools:refreshStock(p) end
 p.player:SetAttribute('MA_SaveStatus',p.session.lost and 'Session lost — progress paused' or (p.session.readOnly and 'Save uncertain — reconciling' or (preview and 'PREVIEW • not saved across restarts' or 'Saved • autosave active')))
end
function scene.applyWalkSpeed(p)
 local humanoid=p.player.Character and p.player.Character:FindFirstChildOfClass('Humanoid')
 if humanoid then humanoid.WalkSpeed=16+2*Workshop.starLevel(data(p),'walk') end
end
local function characterRoot(p: any): any
 local ch=p.player.Character;local h=ch and ch:FindFirstChildOfClass('Humanoid');local hr=ch and ch:FindFirstChild('HumanoidRootPart')
 return h and h.Health>0 and hr or nil
end
local function atStation(p,station,radius)
 local hr=characterRoot(p);return hr and station and (hr.Position-station.Position).Magnitude<(radius or 18)
end
local function atHome(p)
 local hr=characterRoot(p);return hr and ((hr.Position-home).Magnitude<30 or (scene.printer and (hr.Position-scene.printer.Position).Magnitude<16))
end
-- Orders belong to a field footprint with a forgiving walking margin.
local function nearMiningField(position,field)
 local localPoint=field.part.CFrame:PointToObjectSpace(position)
 return math.abs(localPoint.X)<=field.part.Size.X*.5+18 and math.abs(localPoint.Z)<=field.part.Size.Z*.5+18 and math.abs(localPoint.Y)<=45
end
local function updateSlots(r)
 local count=0;for _ in pairs(r.slots) do count=count+1 end
 if r.part and r.part.Parent then r.part:SetAttribute('SlotsUsed',count) end
end
local function sameRockType(d,r,allowCrewAssist: boolean?)
 -- A rock hosts one drone type at a time, even when a boulder has spare
 -- slots. An Aftershock assist never takes a worker slot.
 local role=DroneRoles.canonical(d.role)
 for id in pairs(r.slots) do
  local worker=drones[id]
  if not worker or worker.owner~=d.owner or (not allowCrewAssist and DroneRoles.canonical(worker.role)~=role) then return false end
 end
 -- Autonomous orbital/scrap drones also occupy their real current job.
 -- Player-placed consumables have no actor reservation and remain tools.
 for _,p in pairs(profiles) do
  local ability=p.ability
  if ability and ability.runId==data(p).run.id then
   local function conflicts(id,target)
    local worker=id and drones[id]
    return target==r.id and worker and worker.hp>0 and (worker.owner~=d.owner or (not allowCrewAssist and DroneRoles.canonical(worker.role)~=role))
   end
   if ability.charge and now<=ability.charge.expires and conflicts(ability.charge.actorId,ability.charge.targetId) then return false end
   if ability.burn and ability.burn.remaining>0 and conflicts(ability.burn.actorId,ability.burn.targetId) then return false end
   if ability.swarm and now<ability.swarm.expires then
    for _,bot in ipairs(ability.swarm.bots) do if conflicts(ability.swarm.actorId,bot.targetId) then return false end end
   end
  end
 end
 return true
end
local function release(d: any,keepCombatEffects: boolean?,keepBreakContact: boolean?): ()
 if d.specialJob and d.specialJob.projectile and not d.specialJob.impacted then d.specialJob.projectile:Destroy() end
 if d.specialJob and d.target and not d.target.paid then
  d.target.part:SetAttribute('EffectCancelledSerial',d.specialJob.serial);d.target.part:SetAttribute('EffectType',nil)
 end
 if d.specialRecovery and d.specialRecovery.part.Parent then
  local part=d.specialRecovery.part
  part:SetAttribute('EffectPausedAt',0);part:SetAttribute('EffectCancelledSerial',d.specialRecovery.serial)
 end
 d.specialJob=nil;d.specialRecovery=nil;d.specialPausedAt=nil;d.obstructedAt=nil;d.manualTarget=nil
 d.specialClear=nil;d.specialQueryAt=nil
 d.resumeResourceId=nil;d.resumePin=nil;d.chargedPin=nil
 d.chargeSite=nil
 if d.target then local r=d.target;r.slots[d.id]=nil;updateSlots(r) end
 d.target=nil;d.squareJob=nil;d.mining=false;d.beamSince=0;d.warmAt=nil;d.mineCharge=0;d.forkUntil=0;d.forkTargetId=nil;d.combatTarget=nil;d.targetPosition=nil
 d.breaker=nil;d.growPlan=nil;d.growAt=nil;d.workStation=nil;d.workTargetId=nil
 d.lingerUntil=nil;d.lingerGoal=nil
 if not keepBreakContact then d.mineBreakContact=nil end
 if not keepCombatEffects then d.chainUntil=0;d.chainTargetId=nil end
 if not keepCombatEffects then d.chargeAt=nil;d.chargeTarget=nil end
end
local function retireTarget(d,keepBreakContact)
 local finished=d.target and d.target.paid and DroneRoles.isWorker(d.role)
 local station=finished and ((d.breaker and d.breaker.station) or d.goal or d.pos)
 local impact=d.breaker
 if impact and impact.phase=='Impact' then
  -- A teammate retired the stone during its weight hold. Lift safely without
  -- applying the delayed hit to a replacement target.
  impact.phase='Recover';impact.phaseAt=now
 elseif impact and impact.phase~='Recover' then impact=nil end
 release(d,false,keepBreakContact);d.breaker=impact
 if finished then
  local p=profiles[d.owner];local hasNext=d.autoField~=nil or (p and (p.miningSquare~=nil or #(p.oreQueue or {})>0))
  d.lingerUntil=now+(hasNext and .2 or 1);d.lingerGoal=station
 end
end
local function spend(d)
 for _,p in ipairs(patches) do R.spend(p.e,d.id) end
end
local function dropFieldIfEmpty(p: any,fieldId: any)
 if not fieldId then return end
 for _,d in ipairs(p.drones) do if d.hp>0 and d.field==fieldId then return end end
 local field=patches[fieldId]
 if field then
  R.removeUser(field.e,p.player.UserId,data(p).run.id)
 end
end
local function leaveDroneField(p: any,d: any)
 local old=d.field
 release(d);spend(d);d.field=nil;d.autoField=nil;d.commandOutAt=nil
 if d.hp>0 then d.state='Return' end
 dropFieldIfEmpty(p,old)
end
local function leaveField(p: any,keepField: number?,keepBreakContact: boolean?,keepCarriers: boolean?): ()
 p.oreQueue={};p.workField=nil
 scene.clearSquare(p)
 if consumableService then consumableService:clear(p) end
 if p.ability then DroneAbilities.cancel(p.ability);RoleEffects.ClearAbility(p.player.UserId) end
 local runId=data(p).run.id
 for _,field in ipairs(patches) do
  if field.id~=keepField then
   R.removeUser(field.e,p.player.UserId,runId)
  end
 end
 for _,d in ipairs(p.drones) do if not keepCarriers or not d.carrierId then release(d,false,keepBreakContact);spend(d);d.field=nil;d.autoField=nil;d.state=d.hp>0 and 'Return' or d.state end end
end
local function recallFromField(p)
 if not healthy(p) then return end
 local hr=characterRoot(p);if not hr then return end
 local square=p.miningSquare
 if square then
  local delta=hr.Position-square.center
  if delta.X*delta.X+delta.Z*delta.Z<=Mining.SELECTOR_LEASH^2 and math.abs(delta.Y)<=32 then return end
  -- Depot visits leave the crew working, including the shops beyond the Pack Counter.
  local floor=scene.depotFloor
  if scene.runStart and square.field.clusters and scene.packStation
   and Mining.onSelectorDepotRoute(hr.Position,square.center,scene.packStation.Position,floor and floor.CFrame,floor and floor.Size) then return end
 end
 local hasOrders=p.workField~=nil or #(p.oreQueue or {})>0
 local field=p.workField and patches[p.workField]
 if not field then
  for _,d in ipairs(p.drones) do if not d.carrierId and d.field and patches[d.field] then field=patches[d.field];hasOrders=true;break end end
 end
 if not square and (not hasOrders or not field or nearMiningField(hr.Position,field)) then return end
 leaveField(p,nil,nil,true)
 if square then notice(p,'Too far from the pin. Crew following you.') end
 p.recallSerial=(p.recallSerial or 0)+1
 p.player:SetAttribute('MA_RecallSerial',p.recallSerial);p.player:SetAttribute('MA_RecallAt',now)
 for _,d in ipairs(p.drones) do if d.hp>0 and not d.carrierId then
  d.state='Follow';d.recallSerial=(d.recallSerial or 0)+1;d.recallAt=now
  d.model:SetAttribute('RecallSerial',d.recallSerial);d.model:SetAttribute('RecallAt',now)
 end end
 p.publishDirty=true
end
local colors={Blue=Color3.fromRGB(86,190,255),Red=Color3.fromRGB(255,110,118),Green=Color3.fromRGB(116,230,157)}
local TEST_ROLES={}
for _,name in ipairs(RoleConfig.TypeOrder) do
 local role=RoleConfig.StudioRoles[name];colors[name]=RoleConfig.Types[name].Color
 table.insert(TEST_ROLES,{type=name,name=name,height=role.height,base=role.base})
end
function scene.runtimeFleet(p: any)
 local profile=data(p)
 local base=p.testFleet or profile.fleet
 local fleet=table.clone(base)
 if scene.runStart then
  local role=RoleConfig.StudioRoles.Courier
  for slot=1,Workshop.EMPTIERS do
   table.insert(fleet,{id=Workshop.emptierId(profile.run.id,slot),type='Courier',role='Courier',name='Emptier '..slot,flightHeight=role.height,base=role.base})
  end
  local hasPress=false
  for _,owned in ipairs(base) do if owned.role=='Compactor' then hasPress=true;break end end
  if not hasPress and Workshop.effect(profile,'compactor')>0 then
   role=RoleConfig.StudioRoles.Compactor
   table.insert(fleet,{id=profile.run.id..':compactor',type='Compactor',role='Compactor',name='Compactor',flightHeight=role.height,base=role.base})
  end
 end
 for _,entry in ipairs(Workshop.STAR_CATALOG) do
  if not entry.role or Workshop.starLevel(profile,entry.id)==0 then continue end
  local present=false
  for _,owned in ipairs(base) do if owned.role==entry.role then present=true;break end end
  if not present then
   local role=RoleConfig.StudioRoles[entry.role]
   table.insert(fleet,{id=profile.run.id..':'..entry.id,type=entry.role,role=entry.role,name=RoleConfig.Types[entry.role].DisplayName,
    flightHeight=role.height,base=role.base})
  end
 end
 return fleet
end
local function includePurchasedSpecials(p: any,fleet: any)
 local present={};for _,owned in ipairs(fleet) do present[owned.id]=true end
 for _,owned in ipairs(data(p).fleet) do
  if DroneCatalog.Types[owned.role] and not present[owned.id] then table.insert(fleet,Pro.clone(owned));present[owned.id]=true end
 end
 return fleet
end
local function roleTestFleet(p: any,starterOnly: boolean?)
 p.testRoll=(p.testRoll or 0)+1
 local fleet,counts={},{}
 local names={Striker='Miner',Courier='Emptier',Medic='Healer',Dart='Grower',Charger='Breaker',Orbiter='Orbital',Scrapper='Swarm'}
 local order={'Striker','Courier','Courier','Medic','Dart','Charger','Orbiter','Scrapper'}
 local optional={Starforge=true,Frostbite=true,Resonator=true}
 for _,name in ipairs(DroneCatalog.Order) do if name~='Laser' and (not starterOnly or not optional[name]) then table.insert(order,name) end end
 if scene.runStart and not starterOnly then table.insert(order,'Needler');table.insert(order,'Ballcaster') end
 for i,name in ipairs(order) do
  counts[name]=(counts[name] or 0)+1
  local role=RoleConfig.StudioRoles[name]
  local owned
  if DroneCatalog.Types[name] then for _,candidate in ipairs(data(p).fleet) do if candidate.role==name then owned=Pro.clone(candidate);break end end end
  table.insert(fleet,owned or {id=string.format('test:%d:%d:%d',p.player.UserId,p.testRoll,i),type=name,role=name,name=(names[name] or RoleConfig.Types[name].DisplayName)..(name=='Courier' and ' '..counts[name] or ''),flightHeight=role.height,base=Pro.clone(role.base)})
 end
 -- Keep the real first miner's identity so named cards also work in this test.
 local miner=Pro.clone(data(p).fleet[1]);miner.role='Striker';miner.name='Miner';fleet[1]=miner
 p.player:SetAttribute('MA_TestLoadoutLabel',(starterOnly and 'Core crew' or 'All drone types')..' · Rock Scanner · max backpack')
 return includePurchasedSpecials(p,fleet)
end
local function randomTestFleet(p: any)
 p.testRoll=(p.testRoll or 0)+1
 local picks={TEST_ROLES[2]} -- Every preview loadout can mine; support is random.
 for _=2,seed:NextInteger(RoleConfig.Settings.TestSquadMin,RoleConfig.Settings.TestSquadMax) do
  local weight=0;for _,role in ipairs(TEST_ROLES) do weight+=RoleConfig.Types[role.type].Weight end
  local pick=seed:NextNumber(0,weight)
  for _,role in ipairs(TEST_ROLES) do pick-=RoleConfig.Types[role.type].Weight;if pick<=0 then table.insert(picks,role);break end end
 end
 for i=#picks,2,-1 do local j=seed:NextInteger(1,i);picks[i],picks[j]=picks[j],picks[i] end
 local fleet,counts={},{};for _,role in ipairs(TEST_ROLES) do counts[role.type]=0 end
 for i,role in ipairs(picks) do
  counts[role.type]+=1
  table.insert(fleet,{id=string.format('test:%d:%d:%d',p.player.UserId,p.testRoll,i),type=role.type,role=role.type,name=role.name..' '..counts[role.type],flightHeight=role.height,base=Pro.clone(role.base)})
 end
 local labels={};for _,role in ipairs(TEST_ROLES) do if counts[role.type]>0 then table.insert(labels,role.name..' '..counts[role.type]) end end
 p.player:SetAttribute('MA_TestLoadoutLabel',table.concat(labels,' · '))
 return includePurchasedSpecials(p,fleet)
end
local function spawnDrone(p,owned,slot,origin)
 local stats=Ca.stats(data(p),owned,previewPerks(p))
 local roleName=owned.role or owned.type
 local role=RoleConfig.StudioRoles[roleName]
 local flightHeight=owned.flightHeight or (role and role.height) or Feel.FollowHeight
 -- Runtime presentation lift; never rewrite a permanent drone's base traits.
 if roleName=='Striker' then flightHeight=Feel.ReferenceFollowHeight
 elseif roleName~='Courier' and roleName~='Charger' then flightHeight+=1.8 end
 local hr=characterRoot(p)
 origin=origin or (hr and hr.Position) or (scene.spawnPosition or home)+Vector3.new(0,4,0)
 local pos=Feel.followGoal(origin,slot,#scene.runtimeFleet(p),now,owned.base.maxStep60)
 local model,body,emitter=World.drone(droneFolder,RS:FindFirstChild('Drone'),pos,colors[owned.type] or RoleConfig.Types[roleName] and RoleConfig.Types[roleName].Color or colors.Blue,roleName=='Striker')
 if roleName~='Striker' then model,body,emitter=RoleConfig.decorate(model,roleName) end
 model.Name='Drone_'..owned.id
 local d={id=owned.id,owner=p.player.UserId,owned=owned,name=owned.name,role=owned.role or owned.type,flightHeight=flightHeight,model=model,body=body,emitter=emitter,slot=slot,
  pos=pos,goal=pos,velocity=Vector3.zero,yaw=0,life=1,state='Follow',hp=stats.maxHealth,stats=stats,field=nil,target=nil,mining=false,battery=stats.batteryCapacity,
  beamSince=0,readyAt=0,shotAt=0,shield=0,evade=0,commandOutAt=nil,shotSerial=0,lastShotAt=0,lastCritAt=0,forkUntil=0,chainUntil=0,
  mineCharge=0,minePulseSerial=0,minePulseAt=0,minePulseTargetId='',mineBreakSerial=0,healAt=0,chargeAt=nil}
 if roleName=='Vacuum' and not p.vacuum then p.vacuum=d end
 if roleName=='Compactor' and not p.compactor then p.compactor=d end
 drones[d.id]=d;table.insert(p.drones,d);return d
end
local function rebuildFleet(p,origin)
 for _,d in ipairs(p.drones) do release(d);spend(d);drones[d.id]=nil;d.model:Destroy() end
 p.drones={};p.vacuum=nil;p.vacuumTarget=nil;p.compactor=nil;p.compactorTarget=nil
 p.emptierPickups=nil;p.nextEmptierPlan=nil
 local fleet=scene.runtimeFleet(p)
 local ids={};for _,owned in ipairs(fleet) do if owned.role=='Courier' then table.insert(ids,owned.id) end end
 if Pro.reconcileCargo(data(p),ids) then p.dirty=true end
 for i,owned in ipairs(fleet) do spawnDrone(p,owned,i,origin) end
end
local function refreshStats(p)
 for _,d in ipairs(p.drones) do
  local old=d.stats.maxHealth;local stats=Ca.stats(data(p),d.owned,previewPerks(p))
  if d.hp>0 then d.hp=math.min(stats.maxHealth,math.max(1,d.hp+math.max(0,stats.maxHealth-old))) end
  d.battery=math.min(stats.batteryCapacity,(d.battery or 0)+math.max(0,stats.batteryCapacity-d.stats.batteryCapacity))
  d.stats=stats
 end
end
local function kill(d)
 if d.hp<=0 then return end
 release(d);spend(d);d.field=nil;d.autoField=nil;d.recharging=nil;d.battery=d.stats.batteryCapacity;R.reprint(d,now,C.Reprint+C.Assembly)
 d.pickupAt=nil;d.launchAt=nil;d.unloadAt=nil;d.deliveryArrived=false;d.deliveryRequested=false
 d.repairChargeAt=nil;d.repairTarget=nil;d.healTargetId=nil;d.healUntil=0
 d.model:SetAttribute('DeathSerial',(d.model:GetAttribute('DeathSerial') or 0)+1)
end
local function playerCanMine(p,field)
 if not field.cfg.AlwaysUnlocked and not Shops.unlocked(data(p),field.cfg.Key) then return false end
 return field.cfg.Turrets==0 or field.e.phase=='Cleared' or data(p).clearedFields[field.cfg.Key]==true
end
function scene.unlockedMiners(field)
 for _,d in pairs(drones) do
  local p=profiles[d.owner]
  if d.field==field.id and d.hp>0 and healthy(p) and data(p).clearedFields[field.cfg.Key] then return true end
 end
 return false
end
local function los(a,b,target,ignore)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=ignore or {droneFolder}
 if target and target:GetAttribute('ReferenceCrystal')==true then params.RespectCanCollide=true end
 local hit=workspace:Raycast(a,b-a,params)
 return hit==nil or hit.Instance==target or (target and hit.Instance:IsDescendantOf(target))
end
local function abilityLineOfSight(p,from,r)
 return los(from,r.part.Position,r.part,{droneFolder,p.player.Character})
end
scene.hazards=ToolRules.Hazards.new({players=profiles,root=characterRoot,home=home,now=function() return now end,
 clear=function(from,to,character) return los(from,to,character,{droneFolder}) end})
scene.classicCrystal=game:GetService('ServerStorage'):FindFirstChild('MiningAwayCrystal')
if scene.runStart and scene.classicCrystal then
 -- Courier loads use the same original mesh as field ore, even while the
 -- source map model is outside a streaming client's view.
 local cargoShape=scene.classicCrystal:Clone()
 for _,child in ipairs(cargoShape:GetChildren()) do child:Destroy() end
 cargoShape.Name='CargoCrystal';cargoShape.Parent=net
end
scene.chargeIndicator=scene.chargingStation and scene.chargingStation.Parent:FindFirstChild('ChargeIndicator')
local resourceSerial=0
local function nodeUsage(field)
 local count=0;for _,r in ipairs(field.resources) do if not r.paid then count=count+(r.kind=='Geode' and 5 or 1) end end;return count
end
local function respawnRate(field: any)
 local count=0
 for _,d in pairs(drones) do
  local p=profiles[d.owner]
  if d.field==field.id and d.hp>0 and healthy(p) and characterRoot(p) then count+=1 end
 end
 if field.cfg.ReferenceCrystals then return 1,count end
 local tuning=RoleConfig.Mining
 return math.min(tuning.RespawnRateMaximum,tuning.RespawnRateBase+math.max(0,count-1)*tuning.RespawnRatePerDrone),count
end
local function makeResource(field,position,kind,maxHealth,ore,visualSize,stageCount,junk)
 maxHealth=(maxHealth-10)*(field.cfg.HealthMultiplier or 1)+10
 resourceSerial=resourceSerial+1
 local template=junk and ((field.junkTemplates and field.junkTemplates:FindFirstChild(junk.template)) or field.junk:FindFirstChild(junk.template,true))
 local original=not junk and kind=='Crystal' and ((stageCount or 3)==3 or field.cfg.SelectionOnly) and scene.classicCrystal
 local part=(template or original) and (template or original):Clone() or Instance.new('Part')
 if part:IsA('Part') then
  part.Shape=Enum.PartType.Block
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 end
 part:SetAttribute('CubicRock',not original)
 local reference=field.cfg.ReferenceCrystals==true and kind=='Crystal'
 local shell=kind=='Geode';local size=visualSize or (reference and 3 or (maxHealth/(shell and 37.5 or 25))*(kind=='Shard' and .8 or 1))
 local fullSize=original and original.Size*(size/3) or Vector3.one*size
 local ground=field.part.Position.Y+field.part.Size.Y*.5
 -- Anchor every size to the bottom of the reference mesh at its original scale.
 if reference then ground=position.Y+Feel.ReferenceCrystalPivot-fullSize.Y*1.5/size+.06 end
 local start=Vector3.new(position.X,ground,position.Z)
 local finish=Vector3.new(position.X,ground+fullSize.Y*.5-.06,position.Z)
 part.Name=junk and junk.name or kind;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=not junk;part.Size=fullSize;part.Position=finish
 if junk then
  part.Transparency=0;part.CastShadow=true
  if not template then part.Color=Color3.fromRGB(unpack(junk.color));part.Material=Enum.Material.SmoothPlastic end
  part.Reflectance=0;part:SetAttribute('JunkName',junk.name)
 elseif reference then
  -- The reference clones its opaque red union with the authored finish.
  part.Color=field.color
  if not original then part.Material=Enum.Material.SmoothPlastic end
 elseif original then
  part.Color=field.cfg.Key=='Ruby' and original.Color or field.color
  part.Material=original.Material;part.MaterialVariant='';part.Reflectance=0
 else
  part.Color=shell and Color3.fromRGB(186,193,224):Lerp(field.color,.48) or Color3.fromRGB(228,239,248):Lerp(field.color,.66)
  part.Material=Enum.Material.Slate;part.Reflectance=0
  if scene.classicCrystal then part.Material=Enum.Material.SmoothPlastic
  else World.applyOreFinish(part,field.cfg.Key=='Quartz' or field.cfg.Key=='Cobalt' or field.cfg.Key=='ImpactTest') end
 end
 if part:IsA('PartOperation') then part.UsePartColor=true end
 part.Parent=field.model
 local r={id=instanceId..':r'..resourceSerial,field=field,part=part,referenceCrystal=reference,hp=maxHealth-10,maxHP=maxHealth,fullSize=fullSize,position=finish,start=start,
  slots={},limit=(shell or (not field.cfg.SelectionOnly and (stageCount or 3)>3)) and 3 or 1,kind=kind,paid=false,ore=ore,hardness=field.cfg.Hardness or 1,spawnAt=now,readyAt=now+2,stage=0,stageCount=stageCount or 3,stageSeed=seed:NextInteger(1,1000000),removeAt=nil}
 if junk then
  r.spawnAt=now+.18*(junk.order-1)
  r.readyAt=r.spawnAt+JunkField.FallTime+JunkField.SettleTime
 end
 part.CFrame=Feel.groundedRockFrame(finish,fullSize,ground,0,r.stageSeed,original~=nil and original~=false,reference)
 if field.cfg.SelectionOnly then
  part:SetAttribute('ZoneName',field.cfg.Name or field.cfg.Key)
  part:SetAttribute('BaseOre',1)
  part:SetAttribute('OreValue',ore*(field.cfg.Value or 1))
 end
 resources[r.id]=r;table.insert(field.resources,r)
 for k,v in pairs({ResourceId=r.id,FieldId=field.id,Kind=kind,Hardness=r.hardness,HP=maxHealth,MaxHP=maxHealth,Stage=0,StageCount=r.stageCount,Mineral=field.cfg.Material or field.cfg.Key,StageSeed=r.stageSeed,SpawnAt=r.spawnAt,ReadyAt=r.readyAt,FullSize=fullSize,FullPosition=finish,StartPosition=start,ReferenceCrystal=reference,GroundY=ground,BreakSerial=0,SlotCapacity=r.limit,SlotsUsed=0}) do part:SetAttribute(k,v) end
 return r
end
function scene.junkLandingOccupied(position,radius)
 for _,pl in ipairs(Players:GetPlayers()) do
  local hr=pl.Character and pl.Character:FindFirstChild('HumanoidRootPart')
  if hr and math.abs(hr.Position.Y-position.Y)<10 then
   local dx,dz=hr.Position.X-position.X,hr.Position.Z-position.Z
   if dx*dx+dz*dz<(radius+2)^2 then return true end
  end
 end
 return false
end
function scene.replenishJunk(field)
 if now<(field.nextJunkDrop or 0) then return end
 local occupied,available={},0
 for _,r in ipairs(field.resources) do
  if not r.paid and r.part.Parent then
   local p=field.part.CFrame:PointToObjectSpace(r.position)
   table.insert(occupied,{x=p.X,z=p.Z,radius=r.fullSize.Magnitude*.5})
   if not next(r.slots) then available+=1 end -- Includes incoming work.
  end
 end
 if available>JunkField.LowWork or #occupied>=JunkField.Cap then return end
 field.nextJunkDrop=now+2.4
 local clearance=RaycastParams.new();clearance.FilterType=Enum.RaycastFilterType.Exclude
 local excluded={droneFolder}
 for _,pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(excluded,pl.Character) end end
 clearance.FilterDescendantsInstances=excluded
 local top=field.part.Position.Y+field.part.Size.Y*.5
 local props=field.junkProps or JunkField.Props
 for order=1,math.min(JunkField.BatchSize,JunkField.Cap-#occupied) do
  local index=(field.junkSerial or 0)%#props+1
  local spec=table.clone(props[index]);spec.order=order
  local radius=Vector3.one.Magnitude*spec.size*.5
  local spot=ResourcePlacement.sample(field.part.Size.X,field.part.Size.Z,radius,occupied,
   function(a,b) return seed:NextNumber(a,b) end,function(x,z)
    local center=field.part.CFrame:PointToWorldSpace(Vector3.new(x,0,z))
    if scene.junkLandingOccupied(center,radius) then return false end
    -- Test support and the whole approach envelope against the authored map.
    for sx=-1,1 do for sz=-1,1 do
     local origin=Vector3.new(center.X+sx*radius,top+JunkField.DropHeight+radius,center.Z+sz*radius)
     local hit=workspace:Raycast(origin,Vector3.new(0,top-.25-origin.Y,0),clearance)
     if not hit or hit.Instance~=field.part then return false end
    end end
    return true
   end)
  if spot then
   local position=field.part.CFrame:PointToWorldSpace(Vector3.new(spot.x,0,spot.z))
   makeResource(field,position,'Junk',spec.work+10,spec.ore,spec.size,3,spec)
   table.insert(occupied,spot);field.junkSerial=(field.junkSerial or 0)+1
  end
 end
end
local function spawnResource(field,forceKind,prepareOnly,plan,nearPin,onlyCluster)
 local usage=nodeUsage(field);if usage>=field.cfg.Count then return false end
 local kind=forceKind or ((not field.cfg.SelectionOnly and field.id>1 and field.cfg.Count-usage>=5 and seed:NextNumber()<.12) and 'Geode' or 'Crystal')
 if kind=='Geode' and field.cfg.Count-usage<5 then kind='Crystal' end
 local reference=field.cfg.ReferenceCrystals==true and kind=='Crystal'
 local boulder=not field.cfg.ReferenceCrystals and not prepareOnly and not plan and kind=='Crystal' and (usage==0 or seed:NextNumber()<Mining.BOULDER_CHANCE)
 local clearance=RaycastParams.new();clearance.FilterType=Enum.RaycastFilterType.Exclude
 local excluded={field.model,droneFolder}
 for _,player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excluded,player.Character) end end
 clearance.FilterDescendantsInstances=excluded
 local fieldTop=field.part.Position.Y+field.part.Size.Y/2
 local deep=reference and field.cfg.SelectionOnly and (field.cfg.Hardness or 1)>1
 local mineral=plan and plan.mineral
 if not mineral then
  local roll=seed:NextInteger(50,100)
  mineral=deep and Mining.deepCrystal(roll,field.cfg.Hardness,field.cfg.Ore) or Mining.resource(roll,kind,field.cfg.Hardness)
 end
 local visualSize=reference and not deep and 3 or mineral.size*(boulder and Mining.BOULDER_SIZE or 1)
 local original=kind=='Crystal' and not boulder and scene.classicCrystal
 local dimensions=original and original.Size*(visualSize/3) or Vector3.one*visualSize
 local radius=ResourcePlacement.radius(dimensions.X,dimensions.Y,dimensions.Z,kind,field.cfg.ReferenceCrystals and kind=='Crystal')
 local function sample(patch,neighbors,inset)
  local preferred,bounds
  if plan then local p=patch.CFrame:PointToObjectSpace(plan.spot);preferred={x=p.X,z=p.Z} end
  if nearPin and not preferred then
   local frame=patch.CFrame
   local center=frame:PointToObjectSpace(nearPin.center)
   local right,look=frame.RightVector,frame.LookVector
   local padding=onlyCluster and 0 or radius
   local x=nearPin.half*(math.abs(right.X)+math.abs(right.Z))+padding
   local z=nearPin.half*(math.abs(look.X)+math.abs(look.Z))+padding
   bounds={minX=center.X-x,maxX=center.X+x,minZ=center.Z-z,maxZ=center.Z+z}
  end
  local selected=ResourcePlacement.sample(patch.Size.X-inset,patch.Size.Z-inset,radius,neighbors,
   function(a,b)
    if reference then return seed:NextInteger(a,b) end
    return seed:NextNumber(a,b)
   end,function(x,z)
   local candidate=patch.CFrame:PointToWorldSpace(Vector3.new(x,0,z))
   if nearPin then
    if onlyCluster then
     local delta=candidate-nearPin.center
     if math.abs(delta.X)>nearPin.half or math.abs(delta.Z)>nearPin.half then return false end
    elseif not Mining.selectorTouches(nearPin.center,nearPin.half,CFrame.new(candidate),dimensions) then return false end
   end
    -- Check the footprint and flight space against authored trees/fixtures.
    for _,offset in ipairs({Vector3.zero,Vector3.new(-.45,0,-.45),Vector3.new(.45,0,-.45),Vector3.new(-.45,0,.45),Vector3.new(.45,0,.45)}) do
     local origin=Vector3.new(candidate.X,field.center.Y+(field.cfg.SelectionOnly and 20 or 64),candidate.Z)+offset*visualSize
     if workspace:Raycast(origin,Vector3.new(0,fieldTop+.05-origin.Y,0),clearance) then return false end
     if field.cfg.SelectionOnly then
      local low=Vector3.new(origin.X,fieldTop-.05,origin.Z)
      if workspace:Raycast(low,Vector3.new(0,19,0),clearance) then return false end
     end
    end
    return true
   end,preferred,reference,field.clusters and 1 or nil,bounds)
  return selected and patch.CFrame:PointToWorldSpace(Vector3.new(selected.x,0,selected.z))
 end
 local spot,cluster
 if field.clusters then
  local choices={}
  for _,patch in ipairs(field.clusters) do
   if onlyCluster and patch~=onlyCluster then continue end
   local neighbors={}
   for _,r in ipairs(field.resources) do if not r.paid and r.cluster==patch then
    local p=patch.CFrame:PointToObjectSpace(r.position)
    local reserved=deep and ResourcePlacement.radius(r.fullSize.X,r.fullSize.Y,r.fullSize.Z,r.kind,true) or nil
    table.insert(neighbors,{x=p.X,z=p.Z,radius=reserved})
   end end
   if #neighbors<16 and (not plan or plan.cluster==patch) and (not nearPin or Mining.selectorTouches(nearPin.center,nearPin.half,patch.CFrame,patch.Size)) then
    table.insert(choices,{patch=patch,neighbors=neighbors})
   end
  end
  table.sort(choices,function(a,b)
   if nearPin then
    local distanceA=(a.patch.Position-nearPin.center).Magnitude
    local distanceB=(b.patch.Position-nearPin.center).Magnitude
    if distanceA~=distanceB then return distanceA<distanceB end
   end
   return #a.neighbors<#b.neighbors or #a.neighbors==#b.neighbors and a.patch.Name<b.patch.Name
  end)
  for _,choice in ipairs(choices) do
   cluster=choice.patch;spot=sample(cluster,choice.neighbors,0)
   if spot then break end
  end
 else
  local occupied={}
  for _,r in ipairs(field.resources) do if not r.paid then
   local p=field.part.CFrame:PointToObjectSpace(r.position)
   local reserved=(not reference or deep) and ResourcePlacement.radius(r.fullSize.X,r.fullSize.Y,r.fullSize.Z,r.kind,reference and r.kind=='Crystal') or nil
   occupied[#occupied+1]={x=p.X,z=p.Z,radius=reserved}
  end end
  for _,t in ipairs(field.turrets) do
   local p=field.part.CFrame:PointToObjectSpace(t.body.Position)
   occupied[#occupied+1]={x=p.X,z=p.Z,radius=math.max(4,ResourcePlacement.radius(t.body.Size.X,t.body.Size.Y,t.body.Size.Z))}
  end
  spot=sample(field.part,occupied,field.cfg.SelectionOnly and 8 or 0)
 end
 if not spot then return false end
 if prepareOnly then return true,1,{spot=spot,field=field.id,mineral=mineral,cluster=cluster} end
 local work=mineral.work*(boulder and Mining.BOULDER_WORK or 1)
 local ore=(mineral.ore or field.cfg.Ore)*(boulder and Mining.BOULDER_WORK or 1)
 local resource=makeResource(field,spot,kind,work+10,ore,visualSize,boulder and 7 or field.cfg.Cracks or 3)
 resource.cluster=cluster
 return true,kind=='Geode' and 5 or 1,resource
end
function scene.respawnEarlier(a,b) return a.at<b.at end
function scene.replacementSquare(field,vacancy)
 local owner=vacancy.owner and profiles[vacancy.owner]
 local square=owner and not owner.leaving and owner.miningSquare
 if square and square.field==field
  and Mining.selectorTouches(square.center,square.half,vacancy.frame,vacancy.size)
  and Mining.selectorTouches(square.center,square.half,vacancy.cluster.CFrame,vacancy.cluster.Size) then return square end
 return nil
end
function scene.spawnReplacement(field,kind,vacancy)
 local square=scene.replacementSquare(field,vacancy)
 if square then
  -- Give a cleared pin two cuts to return to. Once it has mature work,
  -- replenish the rest of the field through ordinary placement.
  local growing=0
  for _,r in ipairs(field.resources) do
   if not r.paid and r.part.Parent and Mining.selectorTouches(square.center,square.half,r.part.CFrame,r.part.Size) then
    growing+=1
    if now>=r.readyAt or growing>=2 then return spawnResource(field,kind) end
   end
  end
  local spawned,cost=spawnResource(field,kind,false,nil,square,vacancy.cluster)
  if spawned then return true,cost end
 end
 return spawnResource(field,kind)
end
local function seedField(field)
 for _,r in ipairs(field.resources) do
  for id in pairs(r.slots) do if drones[id] then release(drones[id]) end end
  resources[r.id]=nil;r.part:Destroy()
 end
 field.resources={};field.respawnQueue={};field.respawnClock=now
 for _=1,field.cfg.Count do if not spawnResource(field) then break end end
 -- A blocked initial sampling pass must not permanently strand a safe field.
 -- Reserve one retry token for each missing unit of the population budget;
 -- geodes already count as five units through nodeUsage.
 for _=1,math.max(0,field.cfg.Count-nodeUsage(field)) do
  table.insert(field.respawnQueue,{at=now+2})
 end
end
local function restoreTurrets(field)
 for _,t in ipairs(field.turrets) do
  t.hp=field.cfg.TurretHP;t.nextShot=now+1;t.fireAt=nil;t.lock=nil;t.aim=nil;t.shotSerial=0
  t.awake=false;t.deathAt=nil;t.watcher=nil
  t.model:SetAttribute('Awake',false);t.model:SetAttribute('WakeAt',0);t.model:SetAttribute('ActivateAt',0);t.model:SetAttribute('DeathAt',0)
  t.model:SetAttribute('WakeAim',nil);t.model:SetAttribute('WatchPosition',nil);t.model:SetAttribute('Aim',nil)
  for part,transparency in pairs(t.originalTransparency) do if part.Parent then part.Transparency=transparency end end
  t.model:SetAttribute('HP',t.hp);t.model:SetAttribute('Telegraph',false);t.model:SetAttribute('Dead',false);t.model:SetAttribute('ShotSerial',0)
 end
end
local function wakeTurrets(field: any,pl: any)
 local hr=pl and pl.Character and pl.Character:FindFirstChild('HumanoidRootPart')
 for _,t in ipairs(field.turrets) do
  if not t.awake and t.hp>0 then
   t.awake=true;t.watcher=pl and pl.UserId
   t.model:SetAttribute('WakeAt',now);t.model:SetAttribute('ActivateAt',now+2.15)
   t.model:SetAttribute('WakeAim',hr and hr.Position or field.center)
   t.model:SetAttribute('WatchPosition',hr and hr.Position or field.center)
   t.model:SetAttribute('Awake',true)
  end
 end
end
local function publishTurretHealth(t: any)
 if t.hp<=0 and not t.deathAt then
  t.deathAt=now;t.model:SetAttribute('DeathAt',now)
  t.fireAt=nil;t.lock=nil;t.aim=nil;t.model:SetAttribute('Telegraph',false)
  for _,d in pairs(drones) do
   if d.combatTarget==t or d.chargeTarget==t then release(d);if d.hp>0 then d.state='Travel' end end
  end
 end
 t.model:SetAttribute('HP',t.hp);t.model:SetAttribute('Dead',t.hp<=0)
end
for _,f in ipairs(scene.fields) do
 local settings=table.clone(C);settings.EncounterPrefix=instanceId..':field:'..f.id
 local field={id=f.id,cfg=f.cfg,center=f.center,part=f.part,model=f.model,clusters=f.clusters,color=Color3.fromRGB(unpack(f.cfg.Color)),resources={},turrets={},respawnQueue={},e=R.newEncounter(settings)}
 field.model:SetAttribute('Hardness',f.cfg.Hardness or 1);field.model:SetAttribute('OreValue',f.cfg.Value)
 for n=1,f.cfg.Turrets do
  local pos=f.center+Vector3.new((n-(f.cfg.Turrets+1)/2)*17,f.part.Size.Y/2+.5,-f.part.Size.Z*.32)
  local model,body,emitter=World.turret(f.model,scene.turretTemplate,pos,Color3.fromRGB(210,100,145))
  model.Name='Pyramid_'..n;model:SetAttribute('TurretId',instanceId..':field:'..f.id..':turret:'..n);model:SetAttribute('FieldId',f.id);model:SetAttribute('Turret',true);model:SetAttribute('MaxHP',f.cfg.TurretHP)
  local t={model=model,body=body,emitter=emitter,hp=f.cfg.TurretHP,nextShot=0,fireAt=nil,lock=nil,shotSerial=0}
  -- An invisible queryable proxy binds damage/raycasting to the actual authored pyramid.
  t.hitbox=body;t.originalTransparency={}
  for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then t.originalTransparency[v]=v.Transparency end end
  table.insert(field.turrets,t)
 end
 if f.cfg.Turrets==0 then field.e.phase='Safe' end
 -- All playable fields use mineral rocks, including Studio preview. Photo and
 -- pattern templates remain available in the authored waterfront display.
 field.model:SetAttribute('JunkClearing',field.junk~=nil)
 field.model:SetAttribute('JunkTheme',field.junkTheme)
 table.insert(patches,field);restoreTurrets(field)
 if field.junk then
  field.nextJunkDrop=now+2.4
 else seedField(field) end
 field.model:SetAttribute('AlwaysUnlocked',field.cfg.AlwaysUnlocked==true)
end
-- Visible depot counters, shared with edit-time and in-session repair tooling.
local shopStations=ShopStands.mount(scene.map,home,scene.packStation)
local prices={};for _,field in ipairs(patches) do prices[field.cfg.Material or field.cfg.Key or field.cfg.Name]=field.cfg.Value end
local discoveries=DiscoveryService.new(root,RoleConfig.Discoveries,function(player)
 if scene.runStart then return nil end
 local p=profiles[player.UserId];if not healthy(p) then return nil end
 local hr=characterRoot(p);if not hr then return nil end
 return {root=hr,runId=data(p).run.id,
  roll=function(tier,roll,choice)
   local kind=Consumables.onRock(data(p).consumables,tier,roll,choice)
   p.dirty=true;p.publishDirty=true
   return kind,kind and Consumables.ITEMS[kind]
  end,
  collect=function(kind)
   if not healthy(p) or not Consumables.collect(data(p).consumables,kind) then return false end
   p.dirty=true;p.publishDirty=true;return true
  end,
  clearPath=function(position,part) return los(position,hr.Position,hr.Parent,{part,droneFolder}) end}
end)
local pickupFolder=folder(root,'OrePickups')
local pickups={}
local pickupSerial=0
function scene.spawnOrePickup(template,drop,position,velocity,color)
 pickupSerial+=1
 local chip=template:Clone();for _,child in ipairs(chip:GetChildren()) do child:Destroy() end
 for key in pairs(chip:GetAttributes()) do chip:SetAttribute(key,nil) end
 chip.Name=drop.raw and (drop.compacted and 'PressedCargo' or 'RawCrystalCargo') or 'OreFragment'
 chip.Size=drop.raw and (drop.compacted and Vector3.new(1.45,.90,1.22) or Vector3.new(1.48,1.70,1.42)) or Vector3.new(.64,.74,.56)
 chip.Position=position;chip.Color=color
 if drop.raw then
  chip.Material=drop.compacted and Enum.Material.Metal or Enum.Material.Glass
  chip.MaterialVariant='';chip.Reflectance=0;chip:SetAttribute('PhysicalCargo',true)
  chip:SetAttribute('CargoValue',drop.value)
 end
 chip.Anchored=true;chip.CanCollide=false;chip.CanTouch=false;chip.CanQuery=false;chip.Transparency=0
 chip:SetAttribute('Owner',drop.owner);chip:SetAttribute('RunId',drop.runId);chip:SetAttribute('Units',drop.units);chip:SetAttribute('Mineral',drop.material)
 chip:SetAttribute('SpawnAt',now);chip:SetAttribute('FadeAt',now+OreDrops.LIFETIME-OreDrops.FADE_SECONDS);chip:SetAttribute('ExpiresAt',now+OreDrops.LIFETIME);chip:SetAttribute('FloorY',drop.floor);chip:SetAttribute('Homing',false)
 chip:SetAttribute('PickupId',pickupSerial);chip:SetAttribute('Position',position);chip:SetAttribute('Velocity',velocity);chip:SetAttribute('SnapshotAt',now)
 chip.Parent=pickupFolder
 drop.part=chip;drop.x=position.X;drop.y=position.Y;drop.z=position.Z
 drop.vx=velocity.X;drop.vy=velocity.Y;drop.vz=velocity.Z;drop.age=0;drop.spawnAt=now
 drop.publishedPosition=position;drop.publishedVelocity=velocity
 drop.publishedHoming=false;drop.publishedFloor=drop.floor;drop.publishedFade=0
 pickups[pickupSerial]=drop
end
function scene.snapshotOrePickup(drop)
 drop.snapshotAt=now+C.Snapshot
 local part=drop.part
 local position=drop.publishedPosition
 local velocity=drop.publishedVelocity
 local moved=not position or position.X~=drop.x or position.Y~=drop.y or position.Z~=drop.z
 local accelerated=not velocity or velocity.X~=drop.vx or velocity.Y~=drop.vy or velocity.Z~=drop.vz
 local homing=drop.homing==true
 local fade=OreDrops.fade(drop.refreshedAt or drop.spawnAt,now,drop.returnUntil)
 if fade~=drop.publishedFade then part.Transparency=fade;drop.publishedFade=fade end
 if not moved and not accelerated and homing==drop.publishedHoming
  and drop.pressSocket==drop.publishedSocket and drop.floor==drop.publishedFloor then return end
 if moved then
  position=Vector3.new(drop.x,drop.y,drop.z)
  part.Position=position;part:SetAttribute('Position',position)
 end
 if accelerated then
  velocity=Vector3.new(drop.vx,drop.vy,drop.vz)
  part:SetAttribute('Velocity',velocity)
 end
 if homing~=drop.publishedHoming then part:SetAttribute('Homing',homing) end
 drop.publishedPosition=position;drop.publishedVelocity=velocity
 drop.publishedHoming=homing;drop.publishedSocket=drop.pressSocket;drop.publishedFloor=drop.floor
 part:SetAttribute('SnapshotAt',now)
end
local function pendingOre(p)
 local units,nodes=0,{}
 for _,drop in pairs(pickups) do
  if drop.owner==p.player.UserId and drop.runId==data(p).run.id then units+=drop.units;nodes[drop.nodeId]=true end
 end
 local count=0;for _ in pairs(nodes) do count+=1 end
 return units,count
end
local function award(d: any,r: any,specialistCut: boolean?,extraction: boolean?)
 local p=profiles[d.owner];if not healthy(p) or not playerCanMine(p,r.field) or r.kind=='Geode' then return end
 local profile=data(p);local material=r.field.cfg.Material or r.field.cfg.Key or r.field.cfg.Name
 if r.field.cfg.SelectionOnly and Workshop.CRYSTAL_BY_MATERIAL[material] then
  if r.cargoProduced then return end
  local early=d.stats.earlyDrop or 0
  if extraction and (not DroneRoles.isWorker(d.role) or not Mining.looseSeamsReady(r.hp,r.maxHP,early)) then return end
  local tier=Workshop.CRYSTAL_BY_MATERIAL[material]
  local specialist=specialistCut and DroneCatalog.Types[d.role]
  local amount=r.ore*(specialist and specialist.Yield or 1)*d.stats.yieldMultiplier*tier.value+(profile.run.yieldRemainders[material] or 0)
  local value=math.max(1,math.floor(amount))
  profile.run.yieldRemainders[material]=math.max(0,amount-value)
  r.cargoProduced=true;r.extractedOre=r.ore;r.part:SetAttribute('ExtractedOre',r.ore)
  local fieldTop=r.field.part.Position.Y+r.field.part.Size.Y*.5
  local vx,vy,vz=OreDrops.cargoLaunch(pickupSerial+1,false)
  local out=Vector3.new(vx,0,vz).Unit
  local position=r.part.Position+out*(Vector3.new(r.part.Size.X,0,r.part.Size.Z).Magnitude*.5+.42)
   +Vector3.yAxis*(r.part.Size.Y*.28+.18)
  scene.spawnOrePickup(r.part,{owner=d.owner,runId=profile.run.id,nodeId=r.id,material=Workshop.cargoKey(material,value),tierMaterial=material,value=value,
   units=1,raw=true,floor=fieldTop+.22,fieldPart=r.field.part,reachBonus=early*14},position,Vector3.new(vx,vy,vz),r.field.color)
  p.dirty=true;p.publishDirty=true;return
 end
 local target=extraction and Mining.extractedOre(r.ore,r.stage,r.stageCount,d.stats.earlyDrop) or r.ore
 local reachBonus=extraction and (d.stats.earlyDrop or 0)*56 or 0
 local base=math.max(0,target-(r.extractedOre or 0));if base==0 then return end
 local special=not extraction and specialistCut and d.specialJob and d.specialJob.targetId==r.id and DroneCatalog.Types[d.role]
 -- Keep the existing whole-rock specialist bonus on the final collapse.
 -- Partial extraction advances one shared ledger, independent of worker.
 local bonus=special and r.ore*((special.Yield or 1)-1) or 0
 local amount=(base+bonus)*d.stats.yieldMultiplier*discoveries:Multiplier(p.player,'Yield')+(profile.run.yieldRemainders[material] or 0)
 local units=math.floor(amount);profile.run.yieldRemainders[material]=amount-units
 r.extractedOre=target;r.part:SetAttribute('ExtractedOre',target)
 if d.deployedCarrier and logistics then
  local accepted=logistics:deposit(p,material,units)
  local pending=profile.run.logistics.pendingCargo
  if accepted<units then pending[material]=(pending[material] or 0)+units-accepted end
  p.dirty=true;p.publishDirty=true;return
 end
 if units<=0 then p.dirty=true;return end
 local fieldTop=r.field.part.Position.Y+r.field.part.Size.Y*.5
 local ground=r.referenceCrystal and fieldTop or (r.part:GetAttribute('GroundY') or fieldTop)
 local _,nodes=pendingOre(p)
 local nodeDrops=0
 for _,drop in pairs(pickups) do
  if drop.owner==d.owner and drop.runId==profile.run.id and drop.nodeId==r.id and not drop.compacted
   and not OreDrops.expired(drop.refreshedAt or drop.spawnAt,now) then nodeDrops+=1 end
 end
 if nodes>=OreDrops.MAX_NODES or nodeDrops>=4 then
  -- Consolidate overflow at a nearby pile of the same ore. Renew the pile's
  -- lifetime without restarting the existing fragment's motion or spin.
  local nearest,nearestId,distance=nil,nil,math.huge
  for id,drop in pairs(pickups) do
   if drop.owner==d.owner and drop.runId==profile.run.id and drop.material==material and not drop.compacted
    and (nodeDrops<4 or drop.nodeId==r.id) and not OreDrops.expired(drop.refreshedAt or drop.spawnAt,now) then
    local delta=Vector3.new(drop.x,drop.y,drop.z)-r.position
    local dist=delta:Dot(delta)
    if not nearest or dist<distance or dist==distance and id<nearestId then
     nearest,nearestId,distance=drop,id,dist
    end
   end
  end
  if nearest then
   nearest.units+=units;nearest.refreshedAt=now
   nearest.reachBonus=math.max(nearest.reachBonus or 0,reachBonus)
   nearest.part:SetAttribute('Units',nearest.units)
   nearest.part:SetAttribute('FadeAt',now+OreDrops.LIFETIME-OreDrops.FADE_SECONDS)
   nearest.part:SetAttribute('ExpiresAt',now+OreDrops.LIFETIME)
   p.dirty=true;p.publishDirty=true;return
  end
 end
 local limit=4-nodeDrops
 if r.field.cfg.SelectionOnly then limit=math.min(limit,math.max(1,math.floor(units/Workshop.COMPACTOR_BATCH))) end
 for index,n in ipairs(OreDrops.partition(units,limit)) do
  local ox,oy,oz,vx,vy,vz=OreDrops.launch(index,pickupSerial+1,r.part.Size.X,r.part.Size.Y,r.part.Size.Z)
  local position=r.part.Position+Vector3.new(ox,oy,oz)
  scene.spawnOrePickup(r.part,{owner=d.owner,runId=profile.run.id,nodeId=r.id,material=material,units=n,quiet=r.referenceCrystal,
   floor=ground+.22,fieldPart=r.field.part,reachBonus=reachBonus},position,Vector3.new(vx,vy,vz),r.field.color)
 end
 p.dirty=true;p.publishDirty=true
end
function scene.pressSocket(press,slot)
 local pose=CFrame.new(press.pos)*CFrame.Angles(0,press.yaw or 0,0)
 return pose:PointToWorldSpace(RoleConfig.PressSockets[slot]*press.model:GetScale())
end
function scene.resetPress(press)
 for _,id in ipairs(press.pressInputs or {}) do
  local drop=pickups[id]
  if drop then
   drop.pressSocket=nil;drop.pressCarrier=nil;drop.pressBlockedUntil=now+8
   drop.part:SetAttribute('PressSocket',nil)
  end
 end
 press.pressInputs=nil;press.pressInputValue=nil;press.pressDeadline=nil;press.pressPartialAt=nil
 press.pressMaterial=nil;press.pressDock=nil;press.pressSquare=nil;press.pressNextInputAt=nil
 press.pressSearchAt=nil
end
function scene.finishPress(press)
 local inputs=press.pressInputs
 local first=pickups[inputs[1]]
 local intake=press.pos-Vector3.yAxis*.85
 local outlet=CFrame.Angles(0,press.yaw or 0,0)
 local tier=Workshop.CRYSTAL_BY_MATERIAL[first.tierMaterial]
 local value=press.pressInputValue
 local output={owner=first.owner,runId=first.runId,nodeId=first.nodeId,tierMaterial=tier.material,
  material=Workshop.cargoKey(tier.material,value,true),value=value,units=1,raw=true,compacted=true,
  floor=first.floor,fieldPart=first.fieldPart}
 local tint=Color3.fromRGB(table.unpack(Shops.COLORS[tier.name]))
 table.insert(scene.pressOutputs,{at=now+.52,template=Instance.new('Part'),drop=output,
  position=intake+outlet.RightVector*2.25,outlet=outlet,color=tint})
 press.pressUntil=now+1.1
 press.model:SetAttribute('PressAt',now)
 for _,id in ipairs(inputs) do
  local drop=pickups[id]
  drop.part:SetAttribute('ProcessedPosition',intake);drop.part:SetAttribute('ProcessedAt',now)
  drop.part.Transparency=1;Debris:AddItem(drop.part,.24);pickups[id]=nil
 end
 scene.resetPress(press)
end
function scene.orePullClear(drop,from,target,targetModel)
 if drop.pullTarget~=targetModel or now>=(drop.queryAt or 0) then
  drop.clearPath=los(from,target,targetModel,{pickupFolder,droneFolder})
  drop.queryAt=now+.15;drop.pullTarget=targetModel
 end
 return drop.clearPath==true
end
function scene.vacuumApproach(drop,from,hr)
 if drop.vacuumRouteRoot~=hr or now>=(drop.vacuumRouteAt or 0) then
  drop.vacuumRouteAt=now+.2;drop.vacuumRouteRoot=hr;drop.vacuumGoal=nil
  local ignore={pickupFolder,droneFolder}
  -- The raised intake can clear a bank while staying inside the pull radius.
  for _,height in ipairs({3.2,8}) do
   local goal=Vector3.new(from.X,drop.floor+height,from.Z)
   local intake=goal-Vector3.yAxis*.7
   if (intake-from).Magnitude<=13 and los(intake,hr.Position,hr.Parent,ignore) and los(from,intake,nil,ignore) then
    drop.vacuumGoal=goal;break
   end
  end
 end
 return drop.vacuumGoal
end
function scene.pressPair(candidates,previous)
 local best
 for _,candidate in ipairs(candidates) do
  if best and (candidate.distance>best.distance or candidate.distance==best.distance and candidate.id>best.id)
   and candidate.id~=previous then continue end
  for _,other in ipairs(candidates) do
   -- Leave clearance for the press to stop just short of its approach goal.
   if candidate~=other and candidate.value+other.value<=1000000
    and (candidate.position-other.position).Magnitude<=Workshop.COMPACTOR_REACH-1.1 then
    if candidate.id==previous then return candidate end
    best=candidate;break
   end
  end
 end
 return best
end
function scene.cargoInSquare(square,position)
 local reach=square.half+8
 return math.abs(position.X-square.center.X)<=reach and math.abs(position.Z-square.center.Z)<=reach
end
local function pickupStep(dt)
 scene.pressOutputs=scene.pressOutputs or {}
 for i=#scene.pressOutputs,1,-1 do
  local item=scene.pressOutputs[i]
  if now>=item.at then
   local p=profiles[item.drop.owner]
   if p and not p.leaving and item.drop.runId==data(p).run.id then
    local vx,vy,vz=OreDrops.cargoLaunch(pickupSerial+1,true)
    scene.spawnOrePickup(item.template,item.drop,item.position,item.outlet:PointToWorldSpace(Vector3.new(vx,vy,vz)),item.color)
   end
   item.template:Destroy();table.remove(scene.pressOutputs,i)
  end
 end
 local activePresses={}
 for _,p in pairs(profiles) do
  p.pinOreOutOfReach=nil
  if p.vacuum then
   p.previousVacuumTargetId=p.vacuumTarget and p.vacuumTarget.id
   p.vacuumTarget=nil;p.vacuumScore=math.huge
  end
  local press=p.compactor
  if not press then continue end
  local previous=p.compactorTarget
  p.compactorTarget=nil;p.compactorDistance=math.huge
  local hr=characterRoot(p)
  if press.pressSquare and (p.miningSquare~=press.pressSquare or press.hp<=0 or not hr) then
   scene.resetPress(press)
  end
  if not p.miningSquare or press.hp<=0 or now<(press.pressUntil or 0) or not healthy(p) or not hr then continue end
  local inputs=press.pressInputs
  if inputs then
   for _,id in ipairs(inputs) do
    if not pickups[id] then scene.resetPress(press);inputs=nil;break end
   end
  end
  if inputs and (#inputs>=p.compactorBatch or now>=press.pressDeadline or now>=(press.pressPartialAt or math.huge)) then
   if #inputs>=2 then scene.finishPress(press) else scene.resetPress(press) end
   continue
  end
  if now>=(press.pressNextInputAt or 0) then
   local search=not inputs and now>=(press.pressSearchAt or 0)
   if search then press.pressSearchAt=now+.15 end
   if not inputs and not search and not previous then continue end
   local hasRoom=Pro.cargoUnits(data(p))<Ca.capacity(data(p),previewPerks(p))
   activePresses[press.owner]={profile=p,playerRoot=hasRoom and not inputs and hr or nil,
    groups=search and {},previous=previous and previous.id}
  end
 end
 if next(activePresses) then
  for id,drop in pairs(pickups) do
   local active=activePresses[drop.owner]
   local p=active and active.profile
   if not p or not drop.raw or drop.compacted or drop.pressSocket or not drop.landed or drop.age<.40
    or now<(drop.pressBlockedUntil or 0) or OreDrops.expired(drop.spawnAt,now+Workshop.COMPACTOR_WAIT+1,drop.returnUntil)
    or now<(drop.relayUntil or 0)
    or drop.runId~=data(p).run.id or drop.fieldPart~=p.miningSquare.field.part then continue end
   local press=p.compactor
   if drop.homing and drop.pullTarget~=press.model then continue end
   if not active.groups and not press.pressDock and id~=active.previous then continue end
   if press.pressMaterial and (press.pressMaterial~=drop.tierMaterial or press.pressInputValue+drop.value>1000000) then continue end
   local square=p.miningSquare
   -- Let the player's backpack take nearby ore before starting another
   -- batch. A press already loaded can finish with the next matching rock.
   local hr=active.playerRoot
   if hr and not drop.homing then
    local from=Vector3.new(drop.x,drop.y,drop.z)
    local reach=p.cargoReach+(drop.reachBonus or 0)
    if (hr.Position-from).Magnitude<=reach and scene.orePullClear(drop,from,hr.Position,hr.Parent) then continue end
   end
   local position=Vector3.new(drop.x,drop.floor+3.2,drop.z)
   if not scene.cargoInSquare(square,position) then continue end
   local distance=((press.pressDock or press.pos)-position).Magnitude
   if active.groups then
    local group=active.groups[drop.tierMaterial]
    if not group then group={};active.groups[drop.tierMaterial]=group end
    table.insert(group,{id=id,position=position,distance=distance,value=drop.value})
   elseif (not press.pressDock or distance<=Workshop.COMPACTOR_REACH)
    and (distance<p.compactorDistance or distance==p.compactorDistance and id<p.compactorTarget.id) then
    p.compactorDistance=distance;p.compactorTarget={id=id,position=press.pressDock or position}
   end
  end
  for _,active in pairs(activePresses) do
   if not active.groups then continue end
   local p=active.profile
   for _,group in pairs(active.groups) do
    local candidate=scene.pressPair(group,active.previous)
    if not candidate then continue end
    if candidate.id==active.previous then p.compactorTarget=candidate;break end
    if candidate.distance<p.compactorDistance or candidate.distance==p.compactorDistance and candidate.id<p.compactorTarget.id then
     p.compactorDistance=candidate.distance;p.compactorTarget=candidate
    end
   end
  end
 end
 for id,drop in pairs(pickups) do
  local p=profiles[drop.owner]
  if p and drop.pressCarrier and drop.pressCarrier~=p.compactor then scene.resetPress(drop.pressCarrier) end
  if not p or p.leaving or data(p).run.id~=drop.runId or OreDrops.expired(drop.refreshedAt or drop.spawnAt,now,drop.returnUntil) then
   drop.part:Destroy();pickups[id]=nil;if p then p.publishDirty=true end
  elseif healthy(p) and not drop.pressSocket then
   -- A chip can roll off a raised ore bed. Sample the real map floor only
   -- outside its original footprint, at bounded intervals while moving.
   if drop.fieldPart and now>=(drop.floorQueryAt or 0) then
    local localPoint=drop.fieldPart.CFrame:PointToObjectSpace(Vector3.new(drop.x,drop.y,drop.z))
    local outside=math.abs(localPoint.X)>drop.fieldPart.Size.X*.5 or math.abs(localPoint.Z)>drop.fieldPart.Size.Z*.5
    drop.floorQueryAt=now+.25
    if outside and (not drop.floorQueryX or (drop.x-drop.floorQueryX)^2+(drop.z-drop.floorQueryZ)^2>.25) then
     local include={scene.map};local base=workspace:FindFirstChild('Baseplate');if base then table.insert(include,base) end
     for _,field in ipairs(scene.fields) do table.insert(include,field.part) end
     local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances=include;query.RespectCanCollide=true
     local hit=workspace:Raycast(Vector3.new(drop.x,drop.y+2,drop.z),Vector3.new(0,-66,0),query)
     if hit then drop.floor=hit.Position.Y+.22;drop.part:SetAttribute('FloorY',drop.floor) end
     drop.floorQueryX=drop.x;drop.floorQueryZ=drop.z
    end
   end
   local from=Vector3.new(drop.x,drop.y,drop.z)
   local hr=characterRoot(p);local target=hr and hr.Position or from
   local naturalReach=(drop.raw and (p.cargoReach or 13) or p.magnetRange)+(drop.reachBonus or 0)
   local hasSpace=hr~=nil and Pro.cargoUnits(data(p))<Ca.capacity(data(p),previewPerks(p))
   if drop.raw and drop.landed and hr and not hasSpace and now>=(drop.returnCheckAt or 0) then
    drop.returnCheckAt=now+1
    local counter=scene.packStation.Position
    local walkingDistance=(target-counter).Magnitude+(from-counter).Magnitude
    local deadline=OreDrops.sellTripDeadline(drop.spawnAt,now,walkingDistance,drop.returnUntil)
    if deadline then
     drop.returnUntil=deadline
     drop.part:SetAttribute('FadeAt',deadline-OreDrops.FADE_SECONDS)
     drop.part:SetAttribute('ExpiresAt',deadline)
    end
   end
   local vacuum=p.vacuum
   local press=p.compactor
   local assignedToPress=p.compactorTarget and p.compactorTarget.id==id
   local pressing=assignedToPress
    and (press.pressDock or (press.pos-p.compactorTarget.position).Magnitude<1.1)
   local socket=pressing and #(press.pressInputs or {})+1
   local relay=now<(drop.relayUntil or 0)
   local vacuuming=false
   local vacuumApproaching=false
   local relayReach=p.vacuumReach+12
   local reach=relay and math.max(relayReach,naturalReach) or naturalReach
   if pressing then
    target=scene.pressSocket(press,socket);reach=13
   elseif hasSpace and vacuum and vacuum.hp>0 and not vacuum.carrierId and not relay and not assignedToPress and drop.landed and drop.age>=OreDrops.SCATTER_TIME then
    local distance=(target-from).Magnitude
    local committed=id==p.previousVacuumTargetId
    local searchReach=committed and relayReach or p.vacuumReach
    local goal=distance<=searchReach and (distance>naturalReach or not scene.orePullClear(drop,from,target,hr.Parent)) and scene.vacuumApproach(drop,from,hr)
    if goal then
     local intake=vacuum.pos-Vector3.new(0,.7,0)
     local gap=(intake-from).Magnitude
     local score=committed and -1 or gap
     if score<p.vacuumScore or (score==p.vacuumScore and id<p.vacuumTarget.id) then
      p.vacuumScore=score;p.vacuumTarget={position=goal,id=id}
     end
     if gap<=13 then target=intake;reach=13;vacuuming=true
     else vacuumApproaching=true end
    end
   end
   local canCollect=(pressing or hasSpace) and (target-from).Magnitude<=reach
   local targetModel=pressing and press.model or vacuuming and vacuum.model or hr and hr.Parent
   if canCollect then
    canCollect=scene.orePullClear(drop,from,target,targetModel)
    if pressing and not canCollect then drop.pressBlockedUntil=now+2 end
   end
   local square=p.miningSquare
   if not p.pinOreOutOfReach and square and drop.raw and drop.fieldPart==square.field.part
    and drop.landed and drop.age>=OreDrops.SCATTER_TIME and hasSpace and not canCollect and not assignedToPress and not vacuumApproaching
    and scene.cargoInSquare(square,from) then
    p.pinOreOutOfReach=square
   end
   local reached,groundSpeed=OreDrops.step(drop,{x=target.X,y=target.Y,z=target.Z},dt,canCollect,reach)
   if groundSpeed and groundSpeed>1 then
    drop.groundSerial=(drop.groundSerial or 0)+1
    drop.part:SetAttribute('GroundImpactAt',now)
    drop.part:SetAttribute('GroundImpactSpeed',groundSpeed)
    drop.part:SetAttribute('GroundImpactPosition',Vector3.new(drop.x,drop.floor,drop.z))
    drop.part:SetAttribute('GroundImpactSerial',drop.groundSerial)
   end
   if reached and los(Vector3.new(drop.x,drop.y,drop.z),target,targetModel,{pickupFolder,droneFolder}) then
    if pressing then
     if not press.pressInputs then
      press.pressInputs={};press.pressInputValue=0;press.pressDeadline=now+Workshop.COMPACTOR_WAIT
      press.pressMaterial=drop.tierMaterial;press.pressSquare=p.miningSquare;press.pressDock=press.pos
     end
     table.insert(press.pressInputs,id);press.pressInputValue+=drop.value
     press.pressNextInputAt=now+.22
     if #press.pressInputs>=2 then press.pressPartialAt=now+Workshop.COMPACTOR_PARTIAL_WAIT end
     drop.x=target.X;drop.y=target.Y;drop.z=target.Z
     drop.vx=0;drop.vy=0;drop.vz=0;drop.homing=false;drop.snapshotAt=0
     drop.pressSocket=socket;drop.pressCarrier=press;drop.part:SetAttribute('PressSocket',socket)
    elseif vacuuming then
     local lifted=Vector3.new(drop.x,drop.y,drop.z)
     if los(lifted,hr.Position,hr.Parent,{pickupFolder,droneFolder}) then
      drop.relayUntil=now+3;drop.queryAt=0
     end
    else
    local accepted=Pro.addCargo(data(p),drop.material,drop.units,Ca.capacity(data(p),previewPerks(p)))
    if accepted>0 then
     drop.units-=accepted;p.dirty=true;p.publishDirty=true
     p.collectSerial=(p.collectSerial or 0)+1
     p.collectTotal=(p.collectTotal or 0)+accepted
     p.player:SetAttribute('CollectedOreTotal',p.collectTotal)
     local color=drop.part.Color
     p.player:SetAttribute('MA_Collect',Http:JSONEncode({serial=p.collectSerial,total=p.collectTotal,at=now,units=accepted,pickupId=id,exhausted=drop.units==0,quiet=drop.quiet,physical=drop.raw==true,x=drop.x,y=drop.y,z=drop.z,
      r=math.floor(color.R*255),g=math.floor(color.G*255),b=math.floor(color.B*255)}))
     if drop.units==0 then
      drop.part:SetAttribute('Units',0);drop.part:SetAttribute('CollectedPosition',target);drop.part:SetAttribute('CollectedAt',now)
      drop.part.Transparency=1;Debris:AddItem(drop.part,.35);pickups[id]=nil
     else drop.part:SetAttribute('Units',drop.units);drop.clearPath=false;drop.queryAt=0 end
    end
    end
   end
   if pickups[id] and now>=(drop.snapshotAt or 0) then scene.snapshotOrePickup(drop) end
  end
 end
end
local hitResource: any
local function secondaryMining(d: any,primary: any,amount: number,radius: number,contactKind: string?)
 if primary.field.junk then return false end -- One claimed target per salvage job.
 local assist=contactKind=='Aftershock'
 local candidates={}
 for _,other in ipairs(primary.field.resources) do
  if other~=primary and not other.paid and now>=other.readyAt and other.part.Parent then
   local distance=(other.position-primary.position).Magnitude
   if distance<=radius then table.insert(candidates,{resource=other,distance=distance}) end
  end
 end
 table.sort(candidates,function(a,b) return a.distance==b.distance and a.resource.id<b.resource.id or a.distance<b.distance end)
 for _,candidate in ipairs(candidates) do
  local other=candidate.resource
  if d.squareJob and not Mining.selectorTouches(d.squareJob.center,d.squareJob.half,other.part.CFrame,other.part.Size) then continue end
  if sameRockType(d,other,assist) and not other.slots[d.id] then
   if not assist then other.slots[d.id]=1 end
   local accepted=hitResource(d,other,amount,true,radius,nil,contactKind)
   if not assist then other.slots[d.id]=nil;updateSlots(other) end
   -- An obstructed first candidate must not starve a reachable second one.
   if accepted then return other.id end
  end
 end
 return false
end
function scene.recordToolScar(r,point,width,depth,heat)
 r.toolScars=r.toolScars or {}
 if ToolRules.addScar(r.toolScars,point,width,depth,heat) then
  r.part:SetAttribute('ToolScars',Http:JSONEncode(r.toolScars))
 end
end
function scene.shiftReady(p)
 return (p.shiftSeconds or 0)>0 and p.shiftReadyRun==data(p).run.id
end
function scene.reclaimBattery(d,r,broken,abilityOrigin,contactKind)
 -- Violet and Emerald have extra fracture layers. Regrowth does not restore their charge.
 local deepCrystal=r.kind=='Crystal' and r.field.cfg.SelectionOnly and r.stageCount>3
 local freshCrack=deepCrystal and not broken and r.stage>(r.deepestFracture or 0)
 if freshCrack then r.deepestFracture=r.stage end
 if not (broken or freshCrack) or (abilityOrigin and not (deepCrystal and contactKind=='Breaker'))
  or d.recharging or (d.stats.reclaim or 0)<=0 then return end
 local before=d.battery
 d.battery=math.min(d.stats.batteryCapacity,before+d.stats.reclaim)
 if d.battery-before>=1 then RoleEffects.Pulse(d.pos,Color3.fromRGB(134,221,129),.4,2.4,.20) end
end
hitResource=function(d: any,r: any,amount: number,secondary: boolean?,secondaryRange: number?,abilityOrigin: any,contactKind: string?,fractureContext: any)
 local p=profiles[d.owner]
 local assist=secondary and not abilityOrigin and contactKind=='Aftershock' and r.field.cfg.SelectionOnly==true
 if not healthy(p) or d.hp<=0 or r.paid or r.hp<=0 or not r.part.Parent or not R.finite(amount) or amount<=0 or (not abilityOrigin and not assist and not r.slots[d.id]) or not playerCanMine(p,r.field) or now<r.readyAt then return false end
 if contactKind~='Consumable' and contactKind~='FieldTool' and not sameRockType(d,r,assist) then return false end
 local recipient=d
 local job=d.specialJob
 local special=contactKind=='Special' and DroneCatalog.Types[d.role] and r.kind~='Geode' and job and not job.impacted and job.targetId==r.id and now>=job.startedAt+job.duration*job.impact
 local shell=contactKind=='SpecialShell' and DroneCatalog.Types[d.role] and r.kind=='Geode'
 if secondary then
  for id in pairs(r.slots) do
   local worker=drones[id]
   if worker and worker~=d and worker.target==r then
    if worker.owner~=d.owner then return false end
    if recipient==d or worker.id<recipient.id then recipient=worker end
   end
  end
 end
 if not DroneRoles.isWorker(d.role) and not (abilityOrigin and DroneRoles.ability(d.role)) then return false end
 if not abilityOrigin and not DroneRoles.isMiner(d.role) and not special and not shell then return false end
 if abilityOrigin then
  local hr=characterRoot(p)
  local carrierImpact=d.deployedCarrier and contactKind=='Breaker'
  if (not carrierImpact and (not hr or not nearMiningField(hr.Position,r.field))) or not abilityLineOfSight(p,abilityOrigin,r) then return false end
  for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=d.owner then return false end end
 elseif secondary then
  local primary=d.target
  -- The synchronous primary resolver alone can retain its contact through a
  -- final hit. No saved state/remote can authorize an echo from a retired node.
  if not primary or primary.field~=r.field or not primary.slots[d.id] or (primary.paid and primary.processingPrimary~=d.id) or (r.position-primary.position).Magnitude>(secondaryRange or d.stats.forkRange or 6) or (d.pos-r.position).Magnitude>d.stats.range or (d.pos-(d.workStation or Feel.mineGoal(primary.position,d.targetSlot,primary.limit>1,primary.fullSize,primary.referenceCrystal))).Magnitude>1 or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
  if assist and primary.processingPrimary~=d.id then return false end
 elseif d.target~=r or (d.pos-(d.workStation or Feel.mineGoal(r.position,d.targetSlot,r.limit>1,r.fullSize,r.referenceCrystal))).Magnitude>1 or not los(d.pos,r.position,r.part,{droneFolder}) then return false end
 -- A specialist's committed job, never its caller, supplies the finite hit budget.
 if special then amount=job.damage end
 if contactKind=='Consumable' or contactKind=='FieldTool' then r.consumableWorked=true end
 local baseAmount=amount
 local discoverySpeed=discoveries:Multiplier(p.player,'Speed')
 amount=amount*discoverySpeed
 if not abilityOrigin or contactKind=='Breaker' then amount*=Mining.contactMultiplier(d.role,r.kind,r.hardness,r.stage,r.stageCount) end
 if not abilityOrigin and r.field.cfg.SelectionOnly then
  if r.hardness>=Workshop.DEEP_CUT_HARDNESS then
   amount*=d.stats.deepCutMultiplier or 1
   if special and job.projectile then amount*=DroneCatalog.projectileShellPower(d.role,r.stage) end
  end
  if d.battery>d.stats.batteryCapacity*.5 then amount*=1+(d.stats.liveWire or 0) end
 end
 local pinnedWork=(not abilityOrigin or contactKind=='Breaker') and d.squareJob and d.squareJob==p.miningSquare
 local startShift=pinnedWork and not secondary and scene.shiftReady(p)
 if pinnedWork and (startShift or (d.squareJob==p.shiftSquare and now<(p.shiftUntil or 0))) then amount*=1.5 end
 amount=amount*(abilityOrigin and contactKind~='Breaker' and 1 or Mining.efficiency(d.role=='Charger' and 'Red' or 'Blue',r.kind))
 if (r.kind=='Geode' or r.kind=='Core') then amount=amount*(d.stats.geodeMultiplier or 1) end
 if special then
  amount=DroneCatalog.capDamage(d.role,r.maxHP,amount)
  -- Quarter-work subtraction can leave a floating-point residue on minerals
  -- such as Ruby. Resolve only arithmetic dust, never another real chunk.
  if r.hp>amount and r.hp-amount<=math.max(1,r.maxHP)*1e-10 then amount=r.hp end
 end
 if secondary then d.forkTarget=r.position;d.forkTargetId=r.id;d.forkUntil=now+.18 end
 if secondary and not r.field.cfg.SelectionOnly then scene.hazards:beam(d.pos,r.part.Position,5,'laser') end
 if not secondary and not abilityOrigin then r.processingPrimary=d.id end
 local previous=r.stage
 local isShot=special==true or contactKind=='Breaker'
 local cutStart=not secondary and not abilityOrigin and not special and d.mining and d.beamSince and d.lastCutFX~=d.beamSince
 local shapeChanged=false
 local revealed=nil
 local before=r.hp
 local broken=R.damage(r,amount)
 if startShift and r.hp<before then
  p.shiftReadyRun=nil;p.shiftSquare=d.squareJob;p.shiftUntil=now+p.shiftSeconds
 end
 local finalSurface
 if broken and r.field.cfg.SelectionOnly then
  local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={r.part}
  finalSurface=workspace:Raycast(d.pos,r.part.Position-d.pos,query)
 end
 r.lastHitAt=now
 if r.field.cfg.SelectionOnly and r.hardness>1 and d.squareJob then
  r.lastPin=d.squareJob;r.lastPinOwner=d.owner
 end
 local tool=fractureContext and fractureContext.toolKind
 if tool=='Greatsword' and not r.slice then
  r.slice=math.clamp(.5+r.part.CFrame:PointToObjectSpace(fractureContext.point).Y/r.part.Size.Y,.35,.65);r.part:SetAttribute('SliceScale',r.slice);shapeChanged=true
 end
 if tool=='Melt' or tool=='JellyGrenade' or (special and d.role=='Starforge') or (not r.referenceCrystal and not abilityOrigin and d.mining and d.role=='Striker') then
  local rate=tool=='Melt' and 5 or tool=='JellyGrenade' and 1.6 or special and 2 or .9
  r.heat=math.min(1,(r.heat or 0)+amount/math.max(1,r.maxHP-10)*rate)
  local heat=math.floor(r.heat*4+1e-6)
  local changed=heat~=(r.heatBand or 0)
  if not broken and (changed or tool=='Melt' or tool=='JellyGrenade') then
   local contact=fractureContext and fractureContext.point or abilityOrigin
   local point=contact and r.part.CFrame:PointToObjectSpace(contact)/r.part.Size or Vector3.zero
   local band=math.max(1,heat)
   scene.recordToolScar(r,point,.48+.12*band,.35+.1*band,true)
  end
  if changed then
   r.heatBand=heat;r.part:SetAttribute('MeltBand',heat);shapeChanged=true
   if not broken then RoleEffects.Pulse(r.part.Position+Vector3.new(0,r.part.Size.Y*.5,0),Color3.fromRGB(255,125,56),.35,math.min(13,r.part.Size.X*1.35),.32) end
  end
 end
 if not broken and contactKind=='FieldTool' and (tool=='BowlingBall' or tool=='Crowbar' or tool=='Sledgehammer') then
  local point=r.part.CFrame:PointToObjectSpace(fractureContext.point or abilityOrigin)/r.part.Size
  if tool=='Sledgehammer' and not fractureContext.point then point=Vector3.new(0,.5,0) end
  local width=tool=='Crowbar' and .475 or tool=='Sledgehammer' and .885 or .755
  scene.recordToolScar(r,point,width,width*.78,false)
 end
 if not r.field.cfg.SelectionOnly then
  if contactKind=='Breaker' then scene.hazards:blast(r.part.Position+Vector3.new(0,r.part.Size.Y*.5+.3,0),6,20,'heavy')
  elseif special then scene.hazards:blast(r.part.Position+Vector3.new(0,r.part.Size.Y*.5+.3,0),5,14,'special') end
 end
 -- Persistent cosmetic history is emitted only by accepted authoritative hits.
 -- Observers/late joiners reconstruct the same cavities without authorizing
 -- damage from local CSG geometry, bubbles or collision debris.
 if special and d.role=='Bubbler' then
  r.bubbleBites=math.min(6,(r.bubbleBites or 0)+1);r.part:SetAttribute('BubbleBites',r.bubbleBites)
 elseif contactKind=='Breaker' and d.role=='Charger' then
  r.smashDents=math.min(6,(r.smashDents or 0)+1);r.part:SetAttribute('SmashDents',r.smashDents)
 end
 if (special and d.role=='Bubbler') or (contactKind=='Breaker' and d.role=='Charger') then
  local depth=math.clamp(1-r.hp/math.max(1,r.maxHP-10),0,1)
  r.smashPressure=(r.smashDents or 0)>=6 and math.floor(depth*6+1e-7)/6 or 0
  r.part:SetAttribute('DamageDepth',depth)
  r.part:SetAttribute('DamageAt',now)
 end
 if special then
  job.impacted=true
  r.part:SetAttribute('EffectDepleted',broken);r.part:SetAttribute('EffectDoneAt',now)
 end
 local actual=r.paid and 0 or r.hp+10
 r.stage=Feel.stage(actual,r.maxHP,r.stageCount)
 if r.stage~=previous or shapeChanged then
  r.part:SetAttribute('Stage',r.stage)
  local scale=r.field.cfg.SelectionOnly and Feel.crystalStageShape(r.stage,r.stageCount) or Feel.stageScale(r.stage,r.stageCount)
  r.part.Size=r.fullSize*scale*Feel.rockShape(r.slice,r.heatBand)
  r.part.CFrame=Feel.groundedRockFrame(r.position,r.part.Size,r.part:GetAttribute('GroundY'),r.stage,r.stageSeed,r.part:GetAttribute('CubicRock')==false,r.referenceCrystal)
 end
 r.part:SetAttribute('HP',actual)
 if r.field.cfg.SelectionOnly and (isShot or cutStart or broken) then
  if cutStart then d.lastCutFX=d.beamSince end
  local hitFrom=d.pos
  local delta=r.part.Position-hitFrom
  local direction=delta.Magnitude>.01 and delta.Unit or -Vector3.yAxis
  local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={r.part}
  local hit=finalSurface or workspace:Raycast(hitFrom,delta,query)
  local point=hit and hit.Position or (job and job.contact) or r.part.Position-direction*r.part.Size.Y*.32
  r.part:SetAttribute('CutContactPoint',point);r.part:SetAttribute('CutContactNormal',hit and hit.Normal or -direction)
  r.part:SetAttribute('CutIsShot',isShot==true);r.part:SetAttribute('CutContactAt',now)
  if special and job.projectile then
   job.projectile:SetAttribute('ContactPoint',point);job.projectile:SetAttribute('ContactAt',now)
  end
  if broken then r.part:SetAttribute('CrystalBreakAt',now) end
 end
 -- An allied specialist keeps its cargo value if a laser's Aftershock finishes a layer for it.
 local specialistCut=special==true or (assist and recipient~=d)
 if not broken and r.kind~='Geode' and (r.stage>previous or (r.field.cfg.SelectionOnly and not r.cargoProduced
  and Mining.looseSeamsReady(r.hp,r.maxHP,recipient.stats.earlyDrop))) then
  award(recipient,r,specialistCut,true)
 end
 if not secondary and not abilityOrigin and Mining.kind(d.owned.type)=='Red' then
  d.minePulseSerial=d.minePulseSerial+1;d.minePulseAt=now;d.minePulseTargetId=r.id
 end
 scene.reclaimBattery(assist and recipient or d,r,broken,abilityOrigin,contactKind)
 if broken then
  r.part:SetAttribute('BreakSerial',1);r.part.CanQuery=false;r.part.CanCollide=false;r.part.CanTouch=false;r.removeAt=now+2
  if r.kind=='Geode' then
   local core=Mining.resource(seed:NextInteger(50,100),'Core',r.hardness)
   revealed={makeResource(r.field,r.position,'Core',core.maxHP,r.ore*4,core.size)}
   for n=1,4 do
    local a=n*math.pi/2;local shard=Mining.resource(seed:NextInteger(50,70),'Shard',r.hardness)
    table.insert(revealed,makeResource(r.field,r.position+Vector3.new(math.cos(a)*4,0,math.sin(a)*4),'Shard',shard.maxHP,r.ore,shard.size))
   end
   for _,child in ipairs(revealed) do child.consumableWorked=r.consumableWorked end
  else
   award(recipient,r,specialistCut)
   if (recipient.stats.oreDuplicator or 0)>0 and not abilityOrigin then
    RoleEffects.Pulse(r.part.Position,Color3.fromRGB(255,211,93),.45,3.5,.20)
   end
   -- Tools never manufacture more tools, including rocks later finished by a
   -- normal drone. The rock's ordinary ore payout remains unchanged.
   if not r.consumableWorked then
    if scene.fieldTools then scene.fieldTools:onRock(p,r) end
   end
   if not r.field.junk then
    local respawnClock=r.field.cfg.ReferenceCrystals and now or r.field.respawnClock
    local vacancy={at=respawnClock+r.field.cfg.Respawn}
    if r.cluster and d.squareJob and d.squareJob==p.miningSquare then
     vacancy.owner=d.owner;vacancy.cluster=r.cluster;vacancy.frame=CFrame.new(r.position);vacancy.size=r.fullSize
    end
    table.insert(r.field.respawnQueue,vacancy)
   end
  end
 end
 if not secondary and not abilityOrigin then
  local secondaryId
  if (d.stats.forkFraction or 0)>0 then secondaryId=secondaryMining(d,r,baseAmount*d.stats.forkFraction,d.stats.forkRange or 6) end
  if (d.stats.aftershock or 0)>0 and (broken or r.stage>previous) then
   local echoed=secondaryMining(d,r,(r.maxHP-10)*d.stats.aftershock/discoverySpeed,9,r.field.cfg.SelectionOnly and 'Aftershock' or nil)
   if echoed then
    secondaryId=echoed
    RoleEffects.Pulse(r.part.Position,Color3.fromRGB(125,208,255),1,8,.23)
   end
  end
  if Mining.kind(d.owned.type)=='Green' and r.stage>previous then
   -- Convert the capped effective echo back to base units: hitResource applies
   -- the current discovery multiplier once to every accepted contact.
   local echo=Mining.resonanceDamage(r.maxHP,d.stats.miningDPS*discoverySpeed,r.stage-previous)/discoverySpeed
   local echoed=secondaryMining(d,r,echo,Mining.RESONANCE_RANGE)
   if echoed then
    secondaryId=echoed
    d.minePulseSerial=d.minePulseSerial+1;d.minePulseAt=now;d.minePulseTargetId=r.id
   end
  end
  if broken and (secondaryId or d.stats.doubleBeam==1 or Mining.kind(d.owned.type)=='Red') then
   -- This short record is presentation only: scalar IDs/timestamps, no target,
   -- reservation, damage permission or resource reference survives retirement.
   d.mineBreakSerial=d.mineBreakSerial+1
   d.mineBreakContact={at=now,untilTime=now+.3,primaryId=r.id,secondaryId=secondaryId or '',beamSince=d.beamSince}
  end
  r.processingPrimary=nil
 end
 if broken then
  local workers={};for id in pairs(r.slots) do table.insert(workers,id) end;table.sort(workers)
  for _,id in ipairs(workers) do
   local worker=drones[id]
   if worker and worker.target==r then
    local manual=worker.manualTarget~=nil
    if worker.specialJob and not special then
     r.part:SetAttribute('EffectCancelledSerial',worker.specialJob.serial);r.part:SetAttribute('EffectType',nil)
    end
    retireTarget(worker,not secondary and worker==d and d.mineBreakContact~=nil)
    -- Breaking a shell commits its existing crew to the actual revealed work.
    -- This is continuation of that ordered geode, not free field automation.
    -- New stones still have their normal growth/arrival/warmup gates.
    if revealed then
     for _,nextRock in ipairs(revealed) do
      if not next(nextRock.slots) then
       worker.target=nextRock;worker.targetSlot=1;nextRock.slots[id]=1
       worker.manualTarget=manual and nextRock.id or nil
       worker.lingerUntil=nil;worker.lingerGoal=nil;worker.state='Travel'
       updateSlots(nextRock);break
      end
     end
    end
   else r.slots[id]=nil end
  end
  updateSlots(r)
  if special then
   d.lingerUntil=math.max(d.lingerUntil or now,job.startedAt+job.duration)
   -- A dead rock owns no work reservation. Retain only its cosmetic timeline
   -- so a yielding save can freeze the last recovery just like earlier hits.
   d.specialRecovery={part=r.part,serial=job.serial,startedAt=job.startedAt,duration=job.duration,impacted=true}
  end
 end
 return true
end
local function chooseResource(d: any,field: any,square: any?)
 local best,score,bestPriority=nil,math.huge,-math.huge
 local definition=DroneCatalog.Types[d.role]
 local chunkCycle=square and field.cfg.SelectionOnly and definition and not definition.Projectile
  and DroneCatalog.cycle(d.role,d.owned.base.miningDPS,d.stats.miningDPS)
 for _,r in ipairs(field.resources) do
  if not r.paid and r.hp>0 and r.part.Parent and now>=r.readyAt and (not r.blockedUntil or not r.blockedUntil[d.id] or now>=r.blockedUntil[d.id])
   and (not square or Mining.selectorTouches(square.center,square.half,r.part.CFrame,r.part.Size)) then
   local used=0;local foreign=false
   for id in pairs(r.slots) do used+=1;if not drones[id] or drones[id].owner~=d.owner then foreign=true end end
   local paired=square and square.pairId==r.id and not r.cargoProduced
   local capacity=paired and (DroneRoles.isMiner(d.role) and 2 or 0) or r.limit
   if used<capacity and not foreign and sameRockType(d,r) then
    local neighbors=0
    if Mining.kind(d.owned.type)=='Green' then
     for _,other in ipairs(field.resources) do
      if other~=r and not other.paid and now>=other.readyAt and (other.position-r.position).Magnitude<=Mining.RESONANCE_RANGE then neighbors=neighbors+1;if neighbors==3 then break end end
     end
    end
    local distance=(r.position-d.pos).Magnitude
    local value=if chunkCycle and r.kind=='Crystal' then
     DroneCatalog.chunkTargetScore(d.role,chunkCycle,scene.miningWarmup(d,r),d.stats.maxStep60,r,distance)
     elseif square and field.cfg.SelectionOnly and r.hardness>=Workshop.DEEP_CUT_HARDNESS and definition and definition.Projectile then
     DroneCatalog.projectileTargetScore(d.role,d.stats,r,distance)
     elseif square and d.role=='Charger' then
     distance*.7-math.min(r.hp,1000)*.08
     elseif d.role=='Striker' and not field.junk then
     distance+(used>0 and 10000 or 0)
     else Mining.targetScore(d.owned.type,d.stats,r,distance,neighbors)
    -- A paired cut takes two lasers. An ordinary lead gets one assignment.
    -- Resume ore-bearing work before dispatching an idle drone to clear an empty shell.
    local priority=0
    if square and r.cargoProduced then priority=-1
    elseif paired or square and square.leadId==r.id then priority=3
    elseif square and r.lastPin==square and r.lastPinOwner==d.owner and r.hp<r.maxHP-10 then
     priority=(d.resumePin==square and d.resumeResourceId==r.id) and 2 or 1
    end
    if priority>bestPriority or (priority==bestPriority and value<score) then
     best=r;score=value;bestPriority=priority
    end
   end
  end
 end
 if best then
  local occupied={};for _,slot in pairs(best.slots) do occupied[slot]=true end
  local slot=1;while occupied[slot] do slot=slot+1 end
  best.slots[d.id]=slot;updateSlots(best);d.target=best;d.targetSlot=slot;d.warmAt=nil;d.mineCharge=0;d.mining=false
  if square and square.leadId==best.id then square.leadId=nil end
 end
 return best
end
function scene.clearSquare(p)
 if not p.miningSquare then return end
 p.miningSquare=nil
 p.shiftSquare=nil;p.shiftUntil=nil
 p.player:SetAttribute('MA_Selector',nil)
 p.player:SetAttribute('MA_SelectorWidth',nil)
 p.player:SetAttribute('MA_SelectorWorking',nil)
 p.player:SetAttribute('MA_SelectorStatus',nil)
 p.player:SetAttribute('MA_SelectorFocus',nil)
end
function scene.squareInRange(position,square)
 return Mining.selectorInRange(position,square.center)
end
function scene.committedWork(d)
 return d.target~=nil and (d.warmAt~=nil or d.mining or d.specialJob~=nil
  or (d.breaker~=nil and d.breaker.phase~='Approach'))
end
function scene.finishingDiscreteCut(d)
 local field=d.field and patches[d.field]
 if not field or not field.cfg.SelectionOnly then return false end
 if d.specialJob then return true end
 local recovery=d.specialRecovery
 if recovery and now<recovery.startedAt+recovery.duration then return true end
 local phase=d.breaker and d.breaker.phase
 return phase=='Dive' or phase=='Impact' or phase=='Recover'
end
function scene.publishSquareFocus(p,square)
 local focus=resources[square.focusId]
 local receipt
 if focus and not focus.paid and focus.hp>0 and focus.part.Parent then
  local phase,foreign='Queued',false
  for id in pairs(focus.slots) do
   local worker=drones[id]
   if worker and worker.owner==p.player.UserId and worker.target==focus then
    if worker.mining or worker.specialJob or (worker.breaker and worker.breaker.phase~='Approach') then phase='Cutting';break end
    if worker.warmAt then phase='Starting' elseif phase=='Queued' then phase='Travel' end
   else foreign=true end
  end
  if not healthy(p) then phase='Paused'
  elseif foreign and phase=='Queued' then phase='Claimed' end
  receipt=phase..':'..focus.id
 elseif square.focusId then square.focusId=nil end
 if p.player:GetAttribute('MA_SelectorFocus')~=receipt then p.player:SetAttribute('MA_SelectorFocus',receipt) end
end
function scene.idleSquareStatus(p,square)
 local growing,claimed=false,false
 for _,r in ipairs(square.field.resources) do
  if r.paid or r.hp<=0 or not r.part.Parent or not Mining.selectorTouches(square.center,square.half,r.part.CFrame,r.part.Size) then continue end
  if now<r.readyAt then
   growing=true
  else
   local foreign=false
   for id in pairs(r.slots) do
    local worker=drones[id]
    if worker and worker.owner~=p.player.UserId then foreign=true;break end
   end
   if not foreign then return 'Waiting' end
   claimed=true
  end
 end
 if growing then return 'Growing' end
 if claimed then return 'Claimed' end
 for _,vacancy in ipairs(square.field.respawnQueue) do
  if vacancy.owner==p.player.UserId and scene.replacementSquare(square.field,vacancy) then return 'Refilling' end
 end
 return 'NoCrystals'
end
-- Project the current jobs onto one player-facing status. This never grants
-- work or takes a reservation, and bag capacity is only a pickup concern.
function scene.publishSquareStatus(p)
 local square=p.miningSquare
 if not square then return end
 scene.publishSquareFocus(p,square)
 local working,finishing,moving=false,false,false
 local available,recharging=0,0
 local pair=resources[square.pairId]
 local cuttingPair=0
 if pair and not pair.paid then
  for id in pairs(pair.slots) do
   local worker=drones[id]
   if worker and worker.owner==p.player.UserId and worker.mining then cuttingPair+=1 end
  end
 end
 for _,d in ipairs(p.drones) do
  if d.hp<=0 or d.carrierId or not DroneRoles.isWorker(d.role) then continue end
  available+=1
  if d.recharging then recharging+=1 end
  if scene.committedWork(d) then
   if d.squareJob==square then working=true;break end
   finishing=true
  elseif d.squareJob==square and d.target then moving=true end
 end
 local status=if not healthy(p) or not characterRoot(p) then 'Paused'
  elseif Pro.cargoUnits(data(p))>=Ca.capacity(data(p),previewPerks(p)) and Workshop.starLevel(data(p),'autosell')==0 then 'BagFull'
  elseif working and p.shiftSquare==square and now<(p.shiftUntil or 0) then 'Surge'
  elseif scene.shiftReady(p) then 'SurgeReady'
  elseif p.compactor and now<(p.compactor.pressUntil or 0) then 'Pressing'
  elseif p.pinOreOutOfReach==square then 'LooseOre'
  elseif cuttingPair>=2 then 'PairCut'
  elseif working then 'Working'
  elseif finishing then 'FinishingCut'
  elseif moving then 'Moving'
  elseif available==0 then 'NoMiners'
  elseif recharging==available then 'Recharging'
  elseif next(data(p).run.deliveries) then 'Hauling'
  elseif p.vacuumTarget then 'Gathering'
  else scene.idleSquareStatus(p,square)
 if p.player:GetAttribute('MA_SelectorStatus')~=status then p.player:SetAttribute('MA_SelectorStatus',status) end
 if p.player:GetAttribute('MA_SelectorWorking')~=working then p.player:SetAttribute('MA_SelectorWorking',working) end
end
function scene.squareStep(p,d)
 if not DroneRoles.isWorker(d.role) or d.carrierId then return end
 local square=p.miningSquare
 if d.resumePin~=square then d.resumePin=nil;d.resumeResourceId=nil end
 if d.squareJob and d.squareJob~=square and not scene.committedWork(d) then release(d);d.field=nil end
 if not square or d.target or d.breaker or d.specialRecovery then return end
 d.field=nil;d.autoField=nil
 if now<(d.squareSearchAt or 0) and d.squareSearched==square then return end
 d.squareSearchAt=now+.22;d.squareSearched=square
 if chooseResource(d,square.field,square) then
  d.field=square.field.id;d.squareJob=square;d.state='Travel'
  d.resumePin=nil;d.resumeResourceId=nil
 end
end
function scene.regrow(r,dt)
 if not r.field.cfg.SelectionOnly or r.paid or not r.lastHitAt or now-r.lastHitAt<.8 or next(r.slots) then return end
 local owner=r.lastPinOwner and profiles[r.lastPinOwner]
 if owner and not owner.leaving and owner.miningSquare==r.lastPin then return end
 local maxWork=r.maxHP-10
 if r.hp>=maxWork or now<(r.nextRegenAt or 0) then return end
 r.nextRegenAt=now+.2
 r.hp=math.min(maxWork,r.hp+maxWork*.42*math.max(.2,dt))
 local previous=r.stage
 r.stage=Feel.stage(r.hp+10,r.maxHP,r.stageCount)
 if r.stage~=previous then
  r.part:SetAttribute('Stage',r.stage)
  r.part.Size=r.fullSize*(r.field.cfg.SelectionOnly and Feel.crystalStageShape(r.stage,r.stageCount) or Feel.stageScale(r.stage,r.stageCount))*Feel.rockShape(r.slice,r.heatBand)
 r.part.CFrame=Feel.groundedRockFrame(r.position,r.part.Size,r.part:GetAttribute('GroundY'),r.stage,r.stageSeed,r.part:GetAttribute('CubicRock')==false,r.referenceCrystal)
 end
 r.part:SetAttribute('HP',r.hp+10)
 if now>=(r.nextHealCue or 0) then r.nextHealCue=now+.48;r.part:SetAttribute('RegrowAt',now) end
end
local function eligible(d,field)
 local p=profiles[d.owner];return p and store:healthy(p.session) and characterRoot(p) and d.hp>0 and d.field==field.id and (d.pos-field.center).Magnitude<75
end
local function activeAssault(p)
 for _,field in ipairs(patches) do
  if field.e.phase=='Active' then
   for _,d in ipairs(p.drones) do if d.field==field.id and R.participates(field.e,d,data(p).run.id) then return true end end
  end
 end
 return false
end
local function grantClear(p,field)
 local key=field.cfg.Key
 if data(p).clearedFields[key] then return end
 if p.busy or not store:healthy(p.session) then p.pendingClears=p.pendingClears or {};p.pendingClears[key]=field;return end
 data(p).clearedFields[key]=true
 data(p).run.wins[key]=math.max(1,data(p).run.wins[key] or 0)
 p.dirty=true;p.publishDirty=true
 notice(p,field.cfg.Name..' unlocked permanently. Crystals keep replenishing.')
end
local function settleRuntime(p)
 if p.busy or not store:healthy(p.session) then return end
 local pending=p.pendingClears;p.pendingClears={}
 for _,field in pairs(pending or {}) do grantClear(p,field) end
end
local function encounterStep(field)
 if field.cfg.Turrets==0 or field.e.phase=='Cleared' then return end
 local defeated=true
 for _,t in ipairs(field.turrets) do if t.hp>0 then defeated=false;break end end
 if defeated then
  field.e.phase='Cleared'
  for uid in pairs(field.e.users) do local p=profiles[uid];if p then grantClear(p,field) end end
  for _,d in pairs(drones) do
   if d.field==field.id then
    release(d);d.chargeAt=nil;d.chargeTarget=nil;d.chainUntil=0
    if d.hp>0 then d.state='Travel' end
   end
  end
  field.e.roster={};field.e.users={}
  return
 end
 local active=false
 for id,record in pairs(field.e.roster) do
  local d=drones[id];local p=d and profiles[d.owner]
  if not p or d.field~=field.id or not R.participates(field.e,d,data(p).run.id) then field.e.roster[id]=nil
  else active=true end
 end
 if not active and field.e.phase=='Active' then
  field.e.phase='Guarded'
  for _,t in ipairs(field.turrets) do
   t.awake=false;t.fireAt=nil;t.lock=nil;t.model:SetAttribute('Awake',false);t.model:SetAttribute('Telegraph',false)
  end
 end
end
local function hurtDrone(d,damage)
 local absorbed=math.min(d.shield or 0,damage);d.shield=(d.shield or 0)-absorbed;damage=damage-absorbed
 if damage<=0 then return end
 if damage>=d.hp then kill(d) else d.hp=d.hp-damage end
end
local function turretStep(field: any)
 if field.e.phase~='Active' then
  for _,t in ipairs(field.turrets) do t.fireAt=nil;t.lock=nil;t.model:SetAttribute('Telegraph',false) end;return
 end
 for _,t in ipairs(field.turrets) do
  if t.hp>0 then
   if t.fireAt then
    local d=t.lock;local p=d and profiles[d.owner]
    if p and p.busy then t.fireAt=now+.2;t.model:SetAttribute('FireAt',t.fireAt)
    elseif not d or not p or not R.participates(field.e,d,data(p).run.id) then t.fireAt=nil;t.lock=nil;t.nextShot=now+1
    elseif now>=t.fireAt then
     t.shotSerial=t.shotSerial+1;t.model:SetAttribute('ShotSerial',t.shotSerial)
     scene.hazards:beam(t.emitter.Position,t.aim,field.cfg.Damage,'turret')
     if (d.pos-t.aim).Magnitude<=3.5 and (d.pos-t.emitter.Position).Magnitude<55 and los(t.emitter.Position,t.aim,d.model,{t.model,droneFolder}) then
      local stats=field.e.roster[d.id].stats;hurtDrone(d,field.cfg.Damage*(1-(stats.damageReduction or 0)))
     end
     t.fireAt=nil;t.lock=nil;t.nextShot=now+(field.cfg.ShotCooldown or 1.6)
    end
   elseif now>=t.nextShot then
    local best,dist=nil,55
    for _,d in pairs(drones) do
     local p=profiles[d.owner];local n=(d.pos-t.emitter.Position).Magnitude
     if p and R.participates(field.e,d,data(p).run.id) and eligible(d,field) and n<dist and los(t.emitter.Position,d.pos,d.model,{t.model,droneFolder}) then best=d;dist=n end
    end
    if best then t.lock=best;t.aim=best.pos;t.fireAt=now+.8;t.model:SetAttribute('Aim',t.aim);t.model:SetAttribute('FireAt',t.fireAt) end
   end
  end
  t.model:SetAttribute('Telegraph',t.fireAt~=nil);publishTurretHealth(t)
 end
end
local function combatHit(d,field,target,stats)
 local p=profiles[d.owner]
 if not healthy(p) or not R.participates(field.e,d,data(p).run.id) or target.hp<=0 then return end
 local damage=stats.shotDamage
 if target.hp<=field.cfg.TurretHP*.35 then damage=damage*(stats.finisherMultiplier or 1) end
 if (stats.critChance or 0)>0 and seed:NextNumber()<stats.critChance then damage=damage*2;d.lastCritAt=now end
 d.shotSerial=(d.shotSerial or 0)+1;d.lastShotAt=now
 local dealt=math.min(target.hp,damage);target.hp=math.max(0,target.hp-damage)
 scene.hazards:beam(d.pos,target.emitter.Position,12,'combat')
 local kills=target.hp<=0 and 1 or 0
 if dealt>0 then R.markContribution(field.e,d.owner,data(p).run.id) end
 if (stats.splashFraction or 0)>0 then
  for _,other in ipairs(field.turrets) do
   if other~=target and other.hp>0 and (other.emitter.Position-target.emitter.Position).Magnitude<=(stats.splashRange or 6) and (other.emitter.Position-d.pos).Magnitude<=stats.range and los(d.pos,other.emitter.Position,other.model,{droneFolder}) then
    other.hp=math.max(0,other.hp-damage*stats.splashFraction);if other.hp<=0 then kills=kills+1 end
    publishTurretHealth(other)
    d.chainTarget=other.emitter.Position;d.chainTargetId=other.model:GetAttribute('TurretId');d.chainUntil=now+.2;break
   end
  end
 end
 if kills>0 and (stats.salvageFraction or 0)>0 then
  d.hp=math.min(d.stats.maxHealth,d.hp+d.owned.base.maxHealth*stats.salvageFraction*kills)
  d.model:SetAttribute('RepairSerial',(d.model:GetAttribute('RepairSerial') or 0)+1)
 end
 publishTurretHealth(target)
end
local function travelSpeed(d)
 local returning=d.state=='Travel' and d.chargedPin and d.chargedPin==d.squareJob
 if d.state=='ToCharge' or returning then
  local p=profiles[d.owner]
  local fieldCharge=p and p.miningSquare and (p.fieldCharge or 0)>0
  local boost=p and (returning or not fieldCharge) and Workshop.chargeSpeed(data(p)) or 1
  return d.stats.maxStep60*1.5*boost
 end
 return d.stats.maxStep60*(d.role=='Medic' and .68 or (d.role=='Courier' and (1+(d.stats.fullAuto or 0)) or (d.state=='BreakerDive' and 2.5 or 1)))
end
local function move(d,goal,dt)
 d.intentGoal=goal
 local settling=d.target~=nil or d.state=='ToCharge' or d.state=='BreakerRecover' or d.state=='GrowRecover' or d.state=='Deliver' or d.state=='Collect' or d.state=='Pickup' or d.state=='GrowApproach' or d.state=='Plant' or d.state=='Intake'
 local weight=(d.state=='Recover' or d.state=='Follow') and 0 or (settling and math.clamp(((goal-d.pos).Magnitude-1)/5,0,1) or 1)
 local desired=Feel.swarmOffset(d.pos,d.id,swarmGrid,weight)
 d.swarmOffset=weight==0 and Vector3.zero or Feel.smoothSwarm(d.swarmOffset,desired,dt)
 goal=goal+d.swarmOffset
 d.goal=goal
 local work=d.target~=nil or d.state=='ToCharge' or d.state=='Deliver' or d.state=='BreakerDive' or d.state=='BreakerRecover' or d.state=='Recover' or d.state=='Plant' or d.state=='GrowApproach'
 local speed=travelSpeed(d)
 local yaw
 if d.role=='Striker' then
  local p=profiles[d.owner];local hr=p and characterRoot(p)
  yaw=Feel.referenceYaw(d.pos,goal,speed,hr and hr.CFrame.LookVector,d.yaw)
  if scene.runStart or d.squareJob then
   d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,speed,dt,work,nil,1.35)
  else d.pos,d.velocity=Feel.referenceFlight(d.pos,goal,speed,dt) end
 else
  d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,speed,dt,work)
  yaw=Feel.flightYaw(d.pos,goal,d.velocity,d.yaw)
 end
 d.yaw=Feel.approachYaw(d.yaw,yaw,dt)
 -- Fixed-rate logical motion; snapshotDrone publishes its physical proxy.
end
function scene.holdSquare(d,p,dt)
 local square=p.miningSquare
 if not square or d.carrierId then return false end
 local offset=Feel.formation(d.slot,#p.drones)
 local limit=math.max(0,square.half-2)
 if offset.Magnitude>limit then offset=offset.Unit*limit end
 local height=(d.flightHeight or Feel.FollowHeight)+Feel.hover(now,d.owned.base.maxStep60)
 if d.role=='Striker' and square.field.clusters then
  -- Park at the same low working altitude instead of rising after each cut.
  height=square.field.clusters[1].Position.Y+Feel.WorkHeight-square.center.Y
 end
 d.mining=false;d.state='HoldSelector'
 move(d,square.center+offset+Vector3.new(0,height,0),dt)
 return true
end
local function supportDrone(d: any,p: any,hr: any,dt: number)
 if d.target or d.combatTarget then release(d) end
 local best,score=nil,math.huge
 for _,ally in ipairs(p.drones) do
  if ally~=d and ally.hp>0 and ally.role~='Courier' and (not p.miningSquare or not ally.recharging and scene.squareInRange(ally.pos,p.miningSquare)) then
   local distance=(ally.pos-d.pos).Magnitude
   local injured=ally.hp<ally.stats.maxHealth
   local rank=(injured and -1000 or 0)+(ally.target and -100 or 0)+distance
   if rank<score then best,score=ally,rank end
  end
 end
 if d.repairTarget then
  if d.repairTarget.hp>0 and d.repairTarget.hp<d.repairTarget.stats.maxHealth then best=d.repairTarget
  else d.repairTarget=nil;d.repairChargeAt=nil;d.healTargetId=nil end
 end
 if (not best or (best.hp>=best.stats.maxHealth and not best.target)) and now>=(d.healUntil or 0) then
  d.state='Follow';d.mining=false;d.healTargetId=nil
  if scene.holdSquare(d,p,dt) then return end
  move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60),dt);return
 end
 local goal=best and best.pos+Vector3.new(2,1,2) or hr.Position+Vector3.new(3,d.flightHeight,3)
 d.state='Support';d.mining=false;move(d,goal,dt)
 local inRange=best and best.hp>0 and best.hp<best.stats.maxHealth and (best.pos-d.pos).Magnitude<=RoleConfig.Types.Medic.AttackRange and los(d.pos,best.pos,best.model,{droneFolder,p.player.Character})
 if inRange and now>=(d.healAt or 0) then
  if not d.repairChargeAt then d.repairChargeAt=now;d.repairTarget=best;d.healTargetId=best.id end
  if now-d.repairChargeAt>=RoleConfig.Types.Medic.ChargeWindup then
   best.hp=math.min(best.stats.maxHealth,best.hp+(d.stats.healAmount or RoleConfig.Types.Medic.HealAmount))
   d.healAt=d.repairChargeAt+RoleConfig.Types.Medic.AttackCooldown;d.healTargetId=best.id;d.healUntil=now+.45
   d.repairChargeAt=nil;d.repairTarget=nil
   best.model:SetAttribute('RepairSerial',(best.model:GetAttribute('RepairSerial') or 0)+1)
  end
 else d.repairChargeAt=nil;d.repairTarget=nil end
 if d.repairChargeAt then d.state='RepairCharge'
 elseif now<(d.healUntil or 0) then d.state='Heal'
 else d.healTargetId=nil end
end
local function attackDrone(d: any,field: any,dt: number)
   release(d,true);local target,dist=nil,math.huge
   for _,t in ipairs(field.turrets) do local n=(t.emitter.Position-d.pos).Magnitude;if t.hp>0 and n<dist then target=t;dist=n end end
   if target then
    local stats=field.e.roster[d.id].stats
    local side=d.evade%2==0 and 1 or -1
    local goal=target.emitter.Position+Vector3.new(side*(8+(d.slot%3)*3),5+((d.flightHeight or Feel.FollowHeight)-Feel.FollowHeight),9)
    d.state='Attack';move(d,goal,dt)
    if (d.pos-target.emitter.Position).Magnitude<=stats.range and los(d.pos,target.emitter.Position,target.model,{droneFolder}) then
     d.combatTarget=target;d.mining=true;d.targetPosition=target.emitter.Position
     if d.role=='Charger' then
      if d.chargeTarget and d.chargeTarget~=target then d.chargeAt=nil;d.chargeTarget=nil end
      if not d.chargeAt and now>=d.shotAt then
       d.chargeAt=now+(RoleConfig.Types.Charger.ChargeWindup or .85);d.chargeTarget=target;RoleEffects.Charge(d.emitter.Position,target.emitter.Position,false)
      elseif d.chargeAt and now>=d.chargeAt then
       local charged=Pro.clone(stats);charged.shotDamage=stats.shotDamage*1.75
       RoleEffects.Charge(d.emitter.Position,target.emitter.Position,true);combatHit(d,field,target,charged)
       d.shotAt=now+stats.shotInterval;d.chargeAt=nil;d.chargeTarget=nil
      end
     elseif now>=d.shotAt then combatHit(d,field,target,stats);d.shotAt=now+stats.shotInterval end
    else d.chargeAt=nil;d.chargeTarget=nil end
   else d.chargeAt=nil;d.chargeTarget=nil end
end
local function committedStation(d,r)
 if d.workTargetId~=r.id then
  d.workTargetId=r.id
  d.workStation=Feel.mineGoal(r.position,d.targetSlot,r.limit>1,r.fullSize,r.referenceCrystal)
  local definition=DroneCatalog.Types[d.role]
  if r.field.cfg.SelectionOnly and d.targetSlot==2 then
   local base=d.workStation
   for turn=0,3 do
    local angle=d.slot*2.4+turn*math.pi/2
    local side=base+Vector3.new(math.cos(angle)*3.2,0,math.sin(angle)*3.2)
    if turn==0 then d.workStation=side end
    if los(side,r.position,r.part,{droneFolder}) then d.workStation=side;break end
   end
  elseif definition and definition.Projectile then
   local direction=d.slot*2.4
   local approach=d.pos-r.position
   if r.field.cfg.SelectionOnly and approach.X^2+approach.Z^2>1 then
    direction=math.atan2(approach.Z,approach.X)
   end
   for turn=0,3 do
    local angle=direction+turn*math.pi/2
    local station=r.position+Vector3.new(math.cos(angle)*9,2.8,math.sin(angle)*9)
    if turn==0 then d.workStation=station end
    if los(station,r.position,r.part,{droneFolder}) then d.workStation=station;break end
   end
  end
 end
 return d.workStation
end
function scene.miningWarmup(d,r)
 -- The reference starts cutting on arrival. Keep a short settling beat
 -- for the replicated cut, and keep ignition upgrades proportional.
 if r and r.cluster and d.role=='Striker' then return math.min(.16,d.stats.warmup*.3) end
 local definition=DroneCatalog.Types[d.role]
 if r and r.field.cfg.SelectionOnly and r.kind=='Crystal' and definition and not definition.Projectile then
  return math.max(.08,d.stats.warmup/Ca.LASER_CHARGE_SCALE)
 end
 return r and math.max(.08,d.stats.warmup) or d.stats.warmup
end
local function mineDrone(d: any,p: any,field: any,dt: number)
 if d.combatTarget or d.state=='Attack' then release(d);d.chargeAt=nil;d.chargeTarget=nil end
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 -- A field order keeps the fleet moving; individual orders remain precise.
 if not field.junk and not d.target and d.autoField==field.id then chooseResource(d,field) end
 local r=d.target
 if r then
  local goal=committedStation(d,r);d.state='Travel';move(d,goal,dt)
  if Feel.canMine((d.pos-goal).Magnitude,now>=r.readyAt,true,d.hp>0) and los(d.pos,r.position,r.part,{droneFolder}) then
   d.obstructedAt=nil
   d.warmAt=d.warmAt or now;d.state='Warmup'
   if now-d.warmAt>=scene.miningWarmup(d,r) then
    if not d.mining then d.beamSince=now end
    d.state='Mine';d.mining=true
    local damage,charge=Mining.step('Blue',d.mineCharge,dt,d.stats.miningDPS);d.mineCharge=charge
    if damage>0 then hitResource(d,r,damage,false,nil,nil,DroneCatalog.Types[d.role] and r.kind=='Geode' and 'SpecialShell' or nil) end
   end
  else
   d.warmAt=nil;d.mineCharge=0;d.mining=false
   if (d.pos-goal).Magnitude<=1 and now>=r.readyAt then
    d.obstructedAt=d.obstructedAt or now
    if now-d.obstructedAt>=2 then
     r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+6;release(d)
    end
   end
  end
 else
  -- Workers without a current stone regroup with the player. Plot orders may
  -- find another stone later; manual clicks are dispatched next simulation step.
  d.state='Follow';d.mining=false
  if d.autoField==field.id then d.state='Waiting';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt);return end
  if not d.autoField then local old=d.field;d.field=nil;dropFieldIfEmpty(p,old) end
  local hr=characterRoot(p)
  move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60),dt)
 end
end
local function specialDrone(d: any,p: any,field: any,dt: number)
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 if not field.junk and not d.target and d.autoField==field.id then chooseResource(d,field) end
 local r=d.target
 if not r or r.kind=='Geode' then mineDrone(d,p,field,dt);return end
 local definition=DroneCatalog.Types[d.role]
 local projectile=definition.Projectile
 local goal=committedStation(d,r);local yaw=d.yaw;d.state='Travel';d.mining=false;move(d,goal,dt)
 local arrived=Feel.canMine((d.pos-goal).Magnitude,now>=r.readyAt,true,d.hp>0)
 if projectile and arrived then
  d.yaw=Feel.approachYaw(yaw,Feel.levelYaw(d.pos,r.position,yaw),dt)
 end
 local job=d.specialJob
 local warmup=scene.miningWarmup(d,r)+(projectile and not d.workShotStarted and ((d.slot*7)%11)*.012 or 0)
 local starting=not job and d.warmAt and now-d.warmAt>=warmup
 local contacting=job and not job.impacted and now>=job.startedAt+job.duration*job.impact
 if arrived and (d.specialClear==nil or now>=(d.specialQueryAt or 0) or starting or contacting) then
  -- Monitor obstruction at snapshot cadence, with fresh checks at startup
  -- and the actual contact. Cosmetic recovery never adds damage.
  d.specialClear=los(d.pos,r.position,r.part,{droneFolder});d.specialQueryAt=now+C.Snapshot
 end
 if not arrived or not d.specialClear then
  if (d.pos-goal).Magnitude<=1 and now>=r.readyAt then
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+3;release(d)
  elseif d.specialJob then release(d) else d.warmAt=nil end;return
 end
 d.warmAt=d.warmAt or now;d.state='Warmup'
 if now-d.warmAt<warmup then return end
 if not d.specialJob then
  d.workShotStarted=true
  local cycle=DroneCatalog.cycle(d.role,d.owned.base.miningDPS,d.stats.miningDPS)
  if not cycle then return end
  r.specialSerial=(r.specialSerial or 0)+1
  d.specialJob={targetId=r.id,serial=r.specialSerial,startedAt=now,duration=cycle.duration,impact=cycle.impact,damage=cycle.damage,impacted=false}
  if projectile then
   local vector=r.part.Position-d.pos
   local from=d.pos+vector.Unit*.9
   local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={r.part}
   local contact=workspace:Raycast(from,r.part.Position-from,query)
   local aim=contact and contact.Position or r.part.Position
   local flight=projectile=='Dart' and .25 or .48
   d.specialJob.duration=math.max(cycle.duration,flight+.10);d.specialJob.impact=flight/d.specialJob.duration
   d.specialJob.contact=aim
   d.specialJob.projectile=RoleEffects.Projectile(projectile,from,aim,RoleConfig.Types[d.role].Color,now,flight,d.id,r.id,r.part.CFrame:PointToObjectSpace(aim)/r.part.Size)
  else
   for key,value in pairs({EffectType=d.role,EffectStartedAt=now,EffectDuration=cycle.duration,EffectImpact=cycle.impact,EffectDoneAt=0,EffectDepleted=false,EffectOwner=d.owner,EffectDrone=d.id,EffectPausedAt=0}) do r.part:SetAttribute(key,value) end
   r.part:SetAttribute('EffectSerial',r.specialSerial)
  end
 end
 d.state='SpecialMine'
 job=d.specialJob
 if not job.impacted and now>=job.startedAt+job.duration*job.impact then
  if not hitResource(d,r,job.damage,false,nil,nil,'Special') then
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+3;release(d);return
  end
  if projectile and not r.field.cfg.SelectionOnly then
   RoleEffects.Pulse(job.contact,RoleConfig.Types[d.role].Color,.35,projectile=='Dart' and 1.9 or 4.2,.18)
  end
 end
 -- Keep the same reservation during recovery. A new serial can begin only
 -- after the current complete gesture; no extra warmup or overlapping hits.
 if d.specialJob==job and job.impacted and now>=job.startedAt+job.duration then d.specialJob=nil end
end
local roleAbilityStep
local function followRole(d,p,hr,dt,state)
 if scene.holdSquare(d,p,dt) then return end
 d.mining=false;d.state=state or 'Follow'
 move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60),dt)
end
local function roleNodes(p,field,worker)
 local list={}
 for _,r in ipairs(field.resources) do
  local eligible=not worker or ((not r.blockedUntil or now>=(r.blockedUntil[worker.id] or 0)) and sameRockType(worker,r));local count=0
  for id in pairs(r.slots) do count+=1;local worker=drones[id];if not worker or worker.owner~=p.player.UserId then eligible=false end end
  if r.part.Parent then table.insert(list,{id=r.id,hp=r.hp,maxHP=r.maxHP,kind=r.kind,x=r.position.X,y=r.position.Y,z=r.position.Z,readyAt=r.readyAt,paid=r.paid,eligible=eligible and count<r.limit}) end
 end
 return list
end
local function workingField(p,hr)
 local field=p.workField and patches[p.workField]
 if field and not activeAssault(p) and playerCanMine(p,field) and nearMiningField(hr.Position,field) then return field end
 return nil
end
local function growerDrone(d,p,hr,dt)
 d.mining=false
 local square=p.miningSquare
 local field=square and square.field or workingField(p,hr)
 if d.growSquare~=square then d.growSquare=square;d.growPlan=nil;d.growAt=nil end
 if not field or #field.respawnQueue==0 or nodeUsage(field)>=field.cfg.Count then
  d.growPlan=nil;d.growAt=nil;d.field=nil;followRole(d,p,hr,dt);return
 end
 d.field=field.id
 if now<(d.nextGrow or 0) then
  if square then followRole(d,p,hr,dt);return end
  d.state='GrowRecover';move(d,d.growRecoveryGoal or d.pos,dt);return
 end
 if not d.growPlan or d.growPlan.field~=field.id then
  d.growAt=nil
  local ok,_,plan=spawnResource(field,'Crystal',true,nil,square)
  if not ok then d.nextGrow=now+1;followRole(d,p,hr,dt);return end
  d.growPlan=plan
 end
 local spot=d.growPlan.spot
 local ground=Vector3.new(spot.X,field.part.Position.Y+field.part.Size.Y*.5,spot.Z)
 local goal=ground+Vector3.new(0,3.2,0)
 d.state='GrowApproach';move(d,goal,dt)
 if (d.pos-goal).Magnitude>.8 then d.growAt=nil;return end
 if not los(d.pos,ground,field.part,{droneFolder}) then d.growPlan=nil;d.growAt=nil;d.nextGrow=now+1;return end
 d.state='Plant'
 if not d.growAt then d.growAt=now;RoleEffects.Grow(d.pos,ground,false) end
 if now-d.growAt<DroneRoles.GROWER.plantSeconds then return end
 -- Commit one real replacement token, rechecking population and placement.
 -- Multiple growers cannot grow on top of each other or inflate field rewards.
 local ok,_,resource=spawnResource(field,'Crystal',false,d.growPlan,square)
 if ok then
  table.sort(field.respawnQueue,scene.respawnEarlier);table.remove(field.respawnQueue,1)
  resource.part:SetAttribute('GrownBy',d.id)
  RoleEffects.Grow(d.pos,ground,true)
 end
 local cooldown=d.stats.growCooldown or DroneRoles.GROWER.cooldown
 if Workshop.starLevel(data(p),'cultivator')>0 then cooldown=math.min(cooldown,3) end
 d.growRecoveryGoal=goal;d.growPlan=nil;d.growAt=nil;d.nextGrow=now+(ok and cooldown or 1)
end
local function publishBreakerPhase(d,job)
 -- Publish the full transition before its world contact effects. In particular,
 -- observers must receive the powered stroke instead of holding an old windup
 -- until the next 10 Hz snapshot. SnapshotAt is the final coherence marker.
 local model=d.model
 model:PivotTo(CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0));d.publishedAttributes=nil;d.publishedPose=nil
 model:SetAttribute('Position',d.pos);model:SetAttribute('Goal',d.goal);model:SetAttribute('Velocity',d.velocity or Vector3.zero)
 model:SetAttribute('BreakerDiveStart',job.diveStart or d.pos);model:SetAttribute('BreakerImpact',job.impact)
 model:SetAttribute('BreakerPhaseAt',job.phaseAt);model:SetAttribute('BreakerDiveDuration',DroneRoles.BREAKER.diveDuration)
 model:SetAttribute('BreakerContactSerial',d.contactSerial or 0);model:SetAttribute('BreakerContactAt',d.contactAt or 0)
 model:SetAttribute('ImpactSerial',d.impactSerial or 0);model:SetAttribute('ImpactAt',d.impactAt or 0)
 model:SetAttribute('State',d.state);model:SetAttribute('SnapshotAt',now)
end
local function breakerSurface(r)
 local ground=r.part:GetAttribute('GroundY') or r.position.Y-r.fullSize.Y*.5
 local _,top=Feel.groundedRockFrame(r.position,r.part.Size,ground,r.stage,r.stageSeed,r.part:GetAttribute('CubicRock')==false)
 local contact=Vector3.new(r.position.X,top,r.position.Z)
 local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={r.part}
 local origin=contact+Vector3.new(0,2,0)
 local hit=workspace:Raycast(origin,Vector3.new(0,-r.part.Size.Magnitude-3,0),query)
 if hit then contact=hit.Position end
 if (r.smashDents or 0)>0 then
  -- The center of the same nested ellipsoid rendered by RockDamage. The
  -- authority keeps its original query collider; contact intent follows the
  -- earned bowl floor so later strokes do not hover above an existing dent.
  local dent=r.part.CFrame:PointToWorldSpace(Vector3.new(.025,.31-.05*math.min(6,r.smashDents)-.09*(r.smashPressure or 0),.015)*r.part.Size)
  contact=Vector3.new(contact.X,math.max(ground+.08,math.min(contact.Y,dent.Y)),contact.Z)
 end
 return contact
end
local function breakerDrone(d,p,hr,field,dt)
 d.mining=false
 local job=d.breaker
 -- Recovery survives destruction of this stone, but never a recall/death.
 if job and job.phase=='Recover' then
  local phase,event=DroneRoles.stepBreaker(job,now,{valid=true,recovered=(d.pos-job.station).Magnitude<=.7 and (d.velocity or Vector3.zero).Magnitude<=1})
  d.state='BreakerRecover';move(d,job.station,dt)
  if event=='recover' then RoleEffects.BreakerPhase(d.pos,job.contact,'Recover') end
  if phase=='Complete' then d.breaker=nil end
  return
 end
 if d.target and (d.target.paid or not d.target.part.Parent or d.target.field~=field) then release(d) end
 -- Owning a breaker earns autonomous heavy-rock work after the owner chooses
 -- a rock. The ordinary miner still needs the earned Rock Scanner.
 if not field.junk and not d.target and (p.workField==field.id or d.deployedCarrier) then
  local node=DroneRoles.chooseTarget('Charger',roleNodes(p,field,d),{x=d.pos.X,y=d.pos.Y,z=d.pos.Z},now)
  local r=node and resources[node.id]
  if r then
   local occupied={};for _,slot in pairs(r.slots) do occupied[slot]=true end
   local slot=1;while occupied[slot] do slot+=1 end
   r.slots[d.id]=slot;d.target=r;d.targetSlot=slot;updateSlots(r)
  end
 end
 local r=d.target
 if not r then
  if d.autoField==field.id then d.state='Waiting';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt)
  else followRole(d,p,hr,dt) end
  return
 end
 job=d.breaker
 if not job then
  local station=committedStation(d,r)+Vector3.new(0,2,0)
  if not abilityLineOfSight(p,station,r) then
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+6;release(d);return
  end
  job=DroneRoles.newBreaker(r.id,now);d.breaker=job
  job.windup=math.max(.08,d.stats.warmup)
  job.station=station
  job.contact=breakerSurface(r);job.contactStage=r.stage;job.contactDents=r.smashDents;job.contactPressure=r.smashPressure
  local lowest=0;local pivot=d.model:GetPivot()
  for _,part in ipairs(d.model:GetDescendants()) do if part:IsA('BasePart') and part.Transparency<1 then
   local cf=part.CFrame;local half=part.Size*.5
   for _,x in ipairs({-half.X,half.X}) do for _,y in ipairs({-half.Y,half.Y}) do for _,z in ipairs({-half.Z,half.Z}) do
    lowest=math.min(lowest,pivot:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(x,y,z))).Y)
   end end end
  end end
  job.impactClearance=math.max(.45,-lowest+.12)
  job.impact=job.contact+Vector3.new(0,job.impactClearance,0)
 end
 -- A teammate may chip the shared crystal while this weight descends or
 -- rests on it. Follow the real current surface instead of hovering over its
 -- previous size or letting the body penetrate a newly rotated fragment.
 if job.contactStage~=r.stage or job.contactDents~=r.smashDents or job.contactPressure~=r.smashPressure then
  job.contact=breakerSurface(r);job.contactStage=r.stage;job.contactDents=r.smashDents;job.contactPressure=r.smashPressure
 end
 job.impact=job.contact+Vector3.new(0,job.impactClearance,0)
 local phase=job.phase;local pose=DroneRoles.breakerPose(job,now)
 local goal=job.station+Vector3.new(0,pose.lift,0)
 if phase=='Dive' then goal=job.impact elseif phase=='Impact' then goal=job.impact end
 d.state=phase=='Approach' and 'Travel' or 'Breaker'..phase
 if phase=='Dive' and job.diveStart then
  d.goal=job.impact;d.intentGoal=job.impact;d.pos,d.velocity=Feel.powerDive(job.diveStart,job.impact,now-job.phaseAt,DroneRoles.BREAKER.diveDuration)
 elseif phase=='Impact' then
  d.pos=job.impact;d.goal=job.impact;d.intentGoal=job.impact;d.velocity=Vector3.zero
 else move(d,goal,dt) end
 local event
 phase,event=DroneRoles.stepBreaker(job,now,{valid=not r.paid and now>=r.readyAt and r.slots[d.id]~=nil,targetId=r.id,arrived=(d.pos-job.station).Magnitude<=.7,impactReached=now-job.phaseAt>=DroneRoles.BREAKER.diveDuration and (d.pos-job.impact).Magnitude<=.15})
 if phase~='Approach' then d.state='Breaker'..phase end
 if event=='windup' then publishBreakerPhase(d,job);RoleEffects.BreakerPhase(d.pos,job.contact,'Windup',r.part.Size.X)
 elseif event=='dive' then job.diveStart=d.pos;publishBreakerPhase(d,job);RoleEffects.BreakerPhase(d.pos,job.contact,'Dive',r.part.Size.X)
 elseif event=='contact' then
  d.velocity=Vector3.zero;d.pos=job.impact;d.goal=job.impact;d.intentGoal=job.impact
  d.contactSerial=(d.contactSerial or 0)+1;d.contactAt=now;publishBreakerPhase(d,job)
  RoleEffects.BreakerPhase(d.pos,job.contact,'Hold',r.part.Size.X)
 elseif event=='impact' then
  d.velocity=Vector3.zero
  -- Hold the physical weight on the surface before this single delayed fracture.
  -- The longer weight hold earns a larger hit, retaining its pre-hold work
  -- rate while the shell/perk multipliers continue to define the specialist.
  local diameter=r.part.Size.X
  if hitResource(d,r,d.stats.miningDPS*3.2,false,nil,d.pos,'Breaker') then
   d.impactSerial=(d.impactSerial or 0)+1;d.impactAt=now
   d.goal=job.station;d.intentGoal=job.station;publishBreakerPhase(d,job)
   RoleEffects.BreakerPhase(d.pos,job.contact,'Impact',diameter)
  else
   r.blockedUntil=r.blockedUntil or {};r.blockedUntil[d.id]=now+6
   release(d)
  end
  d.breaker=job
 elseif event=='missed' or event=='canceled' then release(d) end
end
function scene.autoSellReady(p,profile,units)
 return Workshop.starLevel(profile,'autosell')>0 and units>=Ca.capacity(profile,previewPerks(p)) and not activeAssault(p)
end
function scene.emptierReady(p,profile)
 local units=Pro.cargoUnits(profile)
 if scene.autoSellReady(p,profile,units) then return false end
 if not scene.runStart then return units>0 end
 if profile.run.id~=p.emptierBagRun or units==0 then
  p.emptierBagRun=profile.run.id;p.emptierBagSince=nil
 end
 if units>0 then p.emptierBagSince=p.emptierBagSince or now end
 local batch=Workshop.emptierBatch(profile)
 return Workshop.emptierReady(units,batch,p.emptierBagSince,now) or (units>0 and Pro.deliveryFundsMilestone(profile,batch))
end
function scene.emptierOffset(rank)
 return Vector3.new(rank%2==0 and 2.2 or -2.2,2.4,1)
end
function scene.emptierApproachTime(d,position,offset)
 local from=d.pos-position
 local reach=RoleConfig.Courier.PickupDistance
 if from.Magnitude<=reach then return 0 end
 -- The worker can start loading at the reach boundary. An approach that
 -- enters it late can be slower even when its final dock is closer.
 local path=from-offset
 local lengthSquared=path:Dot(path)
 local projection=offset:Dot(path)
 local margin=reach*reach-offset:Dot(offset)
 local remainingFraction=(math.sqrt(projection*projection+lengthSquared*margin)-projection)/lengthSquared
 return path.Magnitude*(1-remainingFraction)/(travelSpeed(d)*60)-math.log(remainingFraction)*.55
end
function scene.assignEmptierPickups(p)
 if not healthy(p) or now<(p.nextEmptierPlan or 0) then return end
 p.nextEmptierPlan=now+C.Snapshot
 local hr=characterRoot(p)
 local profile=data(p)
 if not hr or not scene.emptierReady(p,profile) then p.emptierPickups=nil;return end
 local batch=Workshop.emptierBatch(profile)
 local loads=math.max(1,math.floor(Pro.cargoUnits(profile)/batch))
 local previous=p.emptierPickups
 local candidates,rank={},0
 for _,d in ipairs(p.drones) do
  if d.role~='Courier' then continue end
  rank+=1
  if d.hp<=0 or d.carrierId or profile.run.deliveries[d.id]
   or now<math.max(d.collectAfter or 0,d.pickupRetryAt or 0) then continue end
  local assigned=previous and previous[d.id]
  local offset=assigned or scene.emptierOffset(rank)
  table.insert(candidates,{id=d.id,offset=offset,slot=d.slot,holding=d.pickupAt or math.huge,
   assigned=assigned~=nil,time=scene.emptierApproachTime(d,hr.Position,offset)})
 end
 table.sort(candidates,function(a,b)
  if a.holding~=b.holding then return a.holding<b.holding end
  if a.assigned~=b.assigned then return a.assigned end
  if a.time~=b.time then return a.time<b.time end
  return a.slot<b.slot
 end)
 local pickups={}
 for i=1,math.min(loads,#candidates,2) do
  local c=candidates[i]
  local offset=c.offset
  if i==2 and offset.X==candidates[1].offset.X then offset=Vector3.new(-offset.X,offset.Y,offset.Z) end
  pickups[c.id]=offset
 end
 p.emptierPickups=pickups
end
local function droneStep(d: any,dt: number)
 local p=profiles[d.owner];if not p then return end
 if d.specialRecovery and not d.specialPausedAt and (not d.specialRecovery.part.Parent or now>=d.specialRecovery.startedAt+d.specialRecovery.duration+1.15) then d.specialRecovery=nil end
 if d.hp<=0 then
  d.velocity=Vector3.zero
  d.state=now>=d.readyAt-C.Assembly and 'Reprinting' or 'Destroyed';d.pos=scene.printer.Position+Vector3.new((d.slot-1)%4*2,3,math.floor((d.slot-1)/4)*2);d.goal=d.pos
  if R.finishReprint(d,now,d.stats.maxHealth) then d.field=nil;d.commandOutAt=nil end
  return
 end
 -- Freeze the job during a yielding save; no damage or profile mutation occurs.
 -- Shift the warmup clock so storage latency cannot skip weapon startup.
 if p.busy then
  if d.warmAt then d.warmAt=d.warmAt+dt end
  if d.chargeAt then d.chargeAt=d.chargeAt+dt end
  if d.pickupAt then d.pickupAt=d.pickupAt+dt end
  if d.launchAt then d.launchAt=d.launchAt+dt end
  if d.unloadAt then d.unloadAt=d.unloadAt+dt end
  if d.repairChargeAt then d.repairChargeAt=d.repairChargeAt+dt end
  if d.breaker and d.breaker.phase~='Dive' then d.breaker.phaseAt+=dt end
  if d.growAt then d.growAt+=dt end
  if d.lingerUntil then d.lingerUntil+=dt end
  -- Storage freezes work, not safe flight. No profile, damage, reservation or
  -- job transition is mutated here; travel retains its committed destination.
  if store:healthy(p.session) and d.goal then
   if d.breaker and d.breaker.phase=='Dive' and d.breaker.diveStart then
    local job=d.breaker;d.goal=job.impact;d.intentGoal=job.impact
    d.pos,d.velocity=Feel.powerDive(job.diveStart,job.impact,now-job.phaseAt,DroneRoles.BREAKER.diveDuration)
    if now-job.phaseAt>=DroneRoles.BREAKER.diveDuration then d.velocity=Vector3.zero end
   else move(d,d.intentGoal or (d.goal-(d.swarmOffset or Vector3.zero)),dt) end
  end
  return
 end
 if not store:healthy(p.session) then release(d);return end
 if logistics then
  local station=logistics:station(d)
  if station then
   release(d);d.pos=station;d.goal=station;d.velocity=Vector3.zero;d.state='Docked'
   if logistics:atHome(d) then d.hp=math.min(d.stats.maxHealth,d.hp+8*dt) end
   return
  end
 end
 local hr=characterRoot(p)
 if not hr and d.deployedCarrier and d.field and patches[d.field] then hr={Position=patches[d.field].center} end
 if not hr then
  if d.field then leaveField(p,nil,nil,true) end
  if d.state=='Follow' then
   local spawnAt=(scene.spawnPosition or home)+Vector3.new(0,4,0)
   move(d,Feel.followGoal(spawnAt,d.slot,#p.drones,now,d.owned.base.maxStep60),dt)
  else
   move(d,home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,d.flightHeight or Feel.FollowHeight,0),dt)
  end
  return
 end
 if scene.chargingStation and not d.carrierId and d.stats.batteryCapacity>0 then
  local committed=scene.committedWork(d)
  if d.chargedPin and (d.chargedPin~=p.miningSquare or committed) then d.chargedPin=nil end
  if committed and not d.recharging then
   d.battery=math.max(0,d.battery-2*dt)
  end
  -- Power can run out during a shot or dive that the player already saw start.
  -- Resolve that single gesture before charging. Warmup alone still needs power.
  if d.battery<=0 and not d.recharging and not scene.finishingDiscreteCut(d) then
   local pin,target=d.squareJob,d.target
   release(d);d.recharging=true
   if pin and pin==p.miningSquare and target and target.hardness>=Workshop.DEEP_CUT_HARDNESS then
    d.resumePin=pin;d.resumeResourceId=target.id
   end
  end
  if d.recharging then
   local localCharge=p.miningSquare and (p.fieldCharge or 0)>0
   local pad=localCharge and p.miningSquare.center or scene.chargingStation.Position
   local limit=localCharge and 7 or 3
   local offset=Feel.formation(d.slot,#p.drones);if offset.Magnitude>limit then offset=offset.Unit*limit end
   local goal=pad+offset+Vector3.new(0,2.6,0)
   d.state='ToCharge';d.chargeSite=nil;move(d,goal,dt)
   if (d.pos-goal).Magnitude<1.4 then
    local rate=localCharge and p.fieldCharge or 35
    d.state='Charging';d.chargeSite=localCharge and 'Field' or 'Depot'
    d.battery=math.min(d.stats.batteryCapacity,d.battery+rate*Workshop.chargeSpeed(data(p))*dt)
    if d.battery>=d.stats.batteryCapacity then
     d.recharging=nil
     if not localCharge then d.chargedPin=p.miningSquare end
    end
   end
   return
  end
 end
 if d.lingerUntil and not d.breaker then
  if now<d.lingerUntil then
   d.state='Recover';d.mining=false;move(d,d.lingerGoal or d.pos,dt);return
  end
  d.lingerUntil=nil;d.lingerGoal=nil
 end
 local manifest=data(p).run.deliveries and data(p).run.deliveries[d.id]
 if manifest then
  if d.target or d.combatTarget then release(d) end
  if d.launchAt and now<d.launchAt+RoleConfig.Courier.LaunchHold then
   d.state='Launch';d.goal=d.pos;return
  end
  d.state='Deliver';d.deliveryId=manifest.id
  local depot=scene.converter or scene.packStation
  local depotPosition=scene.runStart and scene.packStation.Position or (logistics and logistics:storagePosition(p) or depot.Position)
  local offset=Feel.formation(d.slot,#p.drones);if offset.Magnitude>6 then offset=offset.Unit*6 end
  local goal=depotPosition+offset+Vector3.new(0,d.flightHeight,0)
  move(d,goal,dt)
  if (d.pos-goal).Magnitude<1 then
   d.unloadAt=d.unloadAt or now;d.state='Unload'
   d.deliveryArrived=now-d.unloadAt>=RoleConfig.Courier.UnloadHold
  else d.unloadAt=nil;d.deliveryArrived=false end
  return
 end
 if d.role=='Courier' then
  d.mining=false;d.field=nil
  if not scene.runStart and logistics:capacity(p)<=0 then
   d.deliveryRequested=false;d.pickupAt=nil;d.state='StorageFull'
   if scene.holdSquare(d,p,dt) then return end
   move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60),dt);return
  end
  local offset=scene.runStart and p.emptierPickups and p.emptierPickups[d.id]
  if not scene.runStart and scene.emptierReady(p,data(p)) and now>=(d.collectAfter or 0) then
   local rank=0;for _,other in ipairs(p.drones) do if other.role=='Courier' then rank+=1;if other==d then break end end end
   offset=scene.emptierOffset(rank)
  end
  if offset and now>=(d.pickupRetryAt or 0) then
   d.state='Collect';move(d,hr.Position+offset,dt)
   local inReach=(d.pos-hr.Position).Magnitude<=RoleConfig.Courier.PickupDistance
   if inReach and los(d.pos,hr.Position,hr.Parent,{droneFolder}) then
    d.pickupBlockedAt=nil
    d.pickupAt=d.pickupAt or now;d.state='Pickup'
    d.deliveryRequested=now-d.pickupAt>=RoleConfig.Courier.PickupHold
   else
    d.pickupAt=nil;d.deliveryRequested=false
    if scene.runStart and inReach then
     d.pickupBlockedAt=d.pickupBlockedAt or now
     if now-d.pickupBlockedAt>=.35 then d.pickupRetryAt=now+1.25;p.nextEmptierPlan=nil end
    else d.pickupBlockedAt=nil end
   end
  else
   d.pickupAt=nil;d.deliveryRequested=false;d.pickupBlockedAt=nil
   d.state='Follow'
   if not scene.runStart and scene.holdSquare(d,p,dt) then return end
   move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60),dt)
  end
  return
 elseif d.role=='Vacuum' then
  if p.vacuum==d and p.vacuumTarget then
   d.state='Vacuum';move(d,p.vacuumTarget.position,dt)
  else followRole(d,p,hr,dt) end
  return
 elseif d.role=='Compactor' then
  if now<(d.pressUntil or 0) then d.state='Press';d.goal=d.pos;d.velocity=Vector3.zero
  elseif d.pressDock then
   d.state='Intake';d.goal=d.pressDock;d.velocity=Vector3.zero
  elseif p.compactor==d and p.compactorTarget then
   d.state='Intake';move(d,p.compactorTarget.position,dt)
  elseif not scene.holdSquare(d,p,dt) then followRole(d,p,hr,dt) end
  return
 elseif d.role=='Medic' then supportDrone(d,p,hr,dt);return
 elseif d.role=='Dart' then growerDrone(d,p,hr,dt);return
 elseif DroneRoles.ability(d.role) then roleAbilityStep(d,p,hr,dt);return end
 scene.squareStep(p,d)
 if not d.target and not d.breaker and scene.holdSquare(d,p,dt) then return end
 if d.role=='Charger' and not d.field then
  local selected=workingField(p,hr)
  if selected then d.field=selected.id end
 end
 local field=d.field and patches[d.field]
 -- Cleared/safe mining orders are independent jobs. Combat still has the
 -- owner leash and server-owned guard participation.
 local idleManual=field and not d.autoField and not d.target
 if field and not d.deployedCarrier and (not playerCanMine(p,field) or idleManual) and (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then
  d.commandOutAt=d.commandOutAt or now
  if now-d.commandOutAt>3 then leaveDroneField(p,d);field=nil end
 else d.commandOutAt=nil end
 if field then
  if field.e.phase=='Active' and R.participates(field.e,d,data(p).run.id) then
   attackDrone(d,field,dt)
  elseif playerCanMine(p,field) then
   if d.deployedCarrier and logistics:capacity(p)<=0 then
    release(d);d.state='StorageFull';move(d,field.center+Feel.formation(d.slot,#p.drones)+Vector3.new(0,10,0),dt)
   elseif not d.deployedCarrier and not d.squareJob and not nearMiningField(hr.Position,field) then
    -- Ore goes into a backpack carried by the owner. Leaving the plot brings
    -- the swarm along. The profile-level leash clears the order before work resumes.
    if field.junk then leaveDroneField(p,d) end
    d.mining=false;d.warmAt=nil;d.mineCharge=0;d.state='Follow'
    move(d,Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60),dt)
   elseif DroneCatalog.Types[d.role] then specialDrone(d,p,field,dt)
   elseif d.role=='Charger' then breakerDrone(d,p,hr,field,dt)
   else mineDrone(d,p,field,dt) end
  else leaveDroneField(p,d) end
 else
  d.mining=false;d.combatTarget=nil
  d.chargeAt=nil;d.chargeTarget=nil
  local height=d.flightHeight or Feel.FollowHeight
  if d.state~='Return' then d.state='Follow' end
  local goal=d.state=='Return' and home+Feel.formation(d.slot,#p.drones)+Vector3.new(0,height,0) or Feel.followGoal(hr.Position,d.slot,#p.drones,now,d.owned.base.maxStep60)
  move(d,goal,dt)
  if d.state=='Return' and (d.pos-goal).Magnitude<1 then d.state='Follow' end
  if (d.pos-home).Magnitude<22 then d.hp=math.min(d.stats.maxHealth,d.hp+8*dt) end
 end
end
function scene.publishCharger()
 local indicator=scene.chargeIndicator
 if not indicator then return end
 local focus=scene.chargerFocus
 if focus and (drones[focus.id]~=focus or focus.state~='Charging' or focus.chargeSite~='Depot' or focus.hp<=0) then
  if drones[focus.id]==focus and focus.hp>0 and focus.battery>=focus.stats.batteryCapacity then
   scene.chargerFullUntil=now+.28
  end
  focus=nil
 end
 local full=now<(scene.chargerFullUntil or 0)
 if not focus and not full then
  for id,d in pairs(drones) do
   if d.state=='Charging' and d.chargeSite=='Depot' and d.hp>0 and (not focus or id<focus.id) then focus=d end
  end
 end
 scene.chargerFocus=focus
 local progress=if full then 1 elseif focus then math.clamp(focus.battery/focus.stats.batteryCapacity,0,1) else nil
 if indicator:GetAttribute('ChargeProgress')~=progress then indicator:SetAttribute('ChargeProgress',progress) end
end
local function snapshotDrone(d)
 local pose=CFrame.new(d.pos)*CFrame.Angles(0,d.yaw,0)
 if d.publishedPose~=pose then d.model:PivotTo(pose);d.publishedPose=pose end
 local profile=data(profiles[d.owner])
 local delivery=profile.run.deliveries[d.id]
 local slots=scene.runStart and d.role=='Courier' and Workshop.emptierBatch(profile) or 0
 local counter=scene.runStart and scene.packStation or scene.converter or scene.packStation
 local salePosition=counter.Position
 if slots>0 then
  -- Alternate the two Emptiers across the field-facing side of the nameplate.
  local lane=(d.slot%2==0 and -1 or 1)*counter.Size.X*.22
  salePosition=counter.CFrame:PointToWorldSpace(Vector3.new(lane,counter.Size.Y*.5,counter.Size.Z*.22))
 end
 local deliveryId=delivery and delivery.id or ''
 if slots>0 and d.displayedDelivery~=deliveryId then
  d.displayedDelivery=deliveryId
  local materials,load={},{}
  if delivery then
   for material in pairs(delivery.cargo) do table.insert(materials,material) end
   table.sort(materials)
   for _,material in ipairs(materials) do
    for _=1,math.min(delivery.cargo[material],6-#load) do table.insert(load,material) end
   end
  end
  d.deliveryMaterials=table.concat(load,';')
 end
 local target=d.target
 if target and (target.paid or target.hp<=0 or not target.part.Parent) then retireTarget(d);target=nil end
 local breakContact=d.mineBreakContact
 if breakContact and (now>=breakContact.untilTime or not healthy(profiles[d.owner]) or d.hp<=0) then d.mineBreakContact=nil;breakContact=nil end
 if (d.forkUntil or 0)<=now then d.forkTargetId=nil end
 if (d.chainUntil or 0)<=now then d.chainTargetId=nil end
 local combatTarget=d.state=='Attack' and d.mining and d.combatTarget
 local combatId=combatTarget and combatTarget.hp>0 and combatTarget.model.Parent and combatTarget.model:GetAttribute('TurretId') or ''
 local mining=not profiles[d.owner].busy and d.state=='Mine' and d.mining and target~=nil
 local values={Owner=d.owner,DroneId=d.id,DroneName=d.name,Name=d.name,Type=d.owned.type,Role=d.role,FlightHeight=d.flightHeight or Feel.FollowHeight,Life=d.life,State=d.state,HP=d.hp,MaxHP=d.stats.maxHealth,ChargeAt=d.chargeAt or 0,Firing=combatId~='',
  Battery=scene.chargingStation and math.ceil(d.battery or 0) or nil,MaxBattery=scene.chargingStation and d.stats.batteryCapacity or nil,
  Position=d.pos,Goal=d.goal,Velocity=d.velocity or Vector3.zero,SwarmOffset=d.swarmOffset or Vector3.zero,Yaw=d.yaw,WorkPaused=profiles[d.owner].busy,MotionPaused=not store:healthy(profiles[d.owner].session) and d.hp>0,MaxStep60=travelSpeed(d),PhaseSeed=d.owned.base.maxStep60*200,FormationSlot=d.slot,FleetCount=#profiles[d.owner].drones,
  TargetId=target and target.id or '',CombatTargetId=combatId,TargetPosition=target and target.position or (combatId~='' and combatTarget.emitter.Position) or d.pos,Mining=mining,BeamSince=d.beamSince,WarmupStart=d.warmAt or 0,WarmupDuration=scene.miningWarmup(d,target),
  DoubleBeam=d.stats.doubleBeam==1,TwinThrusters=d.stats.twinThrusters==1,OreDuplicator=d.stats.oreDuplicator==1,
  MiningStyle=DroneRoles.isMiner(d.role) and 'Cutter' or 'None',MinePulseSerial=d.minePulseSerial,MinePulseAt=d.minePulseAt,MinePulseTargetId=d.minePulseTargetId,
  RecallSerial=d.recallSerial or 0,RecallAt=d.recallAt or 0,
  BreakerDiveStart=d.breaker and d.breaker.diveStart or d.pos,BreakerImpact=d.breaker and d.breaker.impact or d.pos,BreakerPhaseAt=d.breaker and d.breaker.phaseAt or 0,BreakerDiveDuration=DroneRoles.BREAKER.diveDuration,
  BreakerContactSerial=d.contactSerial or 0,BreakerContactAt=d.contactAt or 0,ImpactAt=d.impactAt or 0,
  DeliveryUnits=Pro.deliveryUnits(profile,d.id),DeliveryId=deliveryId,DeliverySlots=slots,DeliveryMaterials=d.deliveryMaterials or '',AutoFieldId=d.autoField or 0,
  CourierPickupAt=d.pickupAt or 0,CourierPickupHold=RoleConfig.Courier.PickupHold,CourierLaunchAt=d.launchAt or 0,CourierLaunchHold=RoleConfig.Courier.LaunchHold,
  CourierUnloadAt=d.unloadAt or 0,CourierUnloadHold=RoleConfig.Courier.UnloadHold,CourierSaleSerial=d.saleSerial or 0,CourierSaleAt=d.saleAt or 0,SellPosition=salePosition,
  Healing=d.hp>0 and d.healTargetId~=nil and now<(d.healUntil or 0),HealTargetId=d.healTargetId or '',
  RepairChargeAt=d.repairChargeAt or 0,RepairChargeDuration=RoleConfig.Types.Medic.ChargeWindup,
  CanMine=DroneRoles.isWorker(d.role),AutomationMineEnabled=DroneRoles.isWorker(d.role) and (d.stats.plotAuto or 0)>0,AutomationHaulEnabled=d.role=='Courier',WorkRole=DroneRoles.job(d.role),ImpactSerial=d.impactSerial or 0,
  MineBreakSerial=d.mineBreakSerial,MineBreakAt=breakContact and breakContact.at or 0,MineBreakUntil=breakContact and breakContact.untilTime or 0,
  MineBreakPrimaryId=breakContact and breakContact.primaryId or '',MineBreakSecondaryId=breakContact and breakContact.secondaryId or '',MineBreakBeamSince=breakContact and breakContact.beamSince or 0,
  ReprintAt=d.hp<=0 and d.readyAt or 0,SnapshotAt=now,ShotSerial=d.shotSerial,ShotAt=d.lastShotAt,LastCritAt=d.lastCritAt,Shield=d.shield,
  ForkTargetPosition=d.forkTarget or d.pos,ForkTargetId=(d.forkUntil or 0)>now and (d.forkTargetId or '') or '',ForkUntil=d.forkUntil or 0,
  ChainTargetPosition=d.chainTarget or d.pos,ChainTargetId=(d.chainUntil or 0)>now and (d.chainTargetId or '') or '',ChainUntil=d.chainUntil or 0,
  GeodeMultiplier=d.stats.geodeMultiplier,FinisherMultiplier=d.stats.finisherMultiplier,SalvageFraction=d.stats.salvageFraction,ChainRange=d.stats.splashRange}
 local published=d.publishedAttributes or {};d.publishedAttributes=published
 for k,v in pairs(values) do if published[k]~=v then d.model:SetAttribute(k,v);published[k]=v end end
 if published.CarrierId~=d.carrierId then d.model:SetAttribute('CarrierId',d.carrierId);published.CarrierId=d.carrierId end
 local deployed=d.deployedCarrier==true
 if published.DeployedCarrier~=deployed then d.model:SetAttribute('DeployedCarrier',deployed);published.DeployedCarrier=deployed end
end
-- Publish pause transitions immediately, not only on the periodic snapshot.
-- Resume position and goal are sent before the pause flag is cleared.
local function setMotionPaused(p: any,paused: boolean)
 for _,d in ipairs(p.drones) do
  if d.model and d.model.Parent and d.hp>0 then
   d.publishedAttributes=nil -- Immediate pause writes invalidate snapshot deltas.
   local effectJob=d.specialJob or d.specialRecovery
   local effectPart=d.specialJob and d.target and d.target.part or d.specialRecovery and d.specialRecovery.part
   if effectPart and not effectPart.Parent then effectJob=nil;effectPart=nil end
   if paused then
    if effectJob and effectPart and not d.specialPausedAt then
     d.specialPausedAt=now;effectPart:SetAttribute('EffectPausedAt',now)
     if effectJob.projectile and effectJob.projectile.Parent then effectJob.projectile:SetAttribute('PausedAt',now) end
    end
    d.model:SetAttribute('Mining',false);d.model:SetAttribute('Firing',false)
    d.mineBreakContact=nil;d.model:SetAttribute('MineBreakUntil',0);d.model:SetAttribute('MineBreakPrimaryId','');d.model:SetAttribute('MineBreakSecondaryId','')
   elseif d.specialPausedAt then
    if effectJob and effectPart then
     local pausedFor=math.max(0,now-d.specialPausedAt)
     effectJob.startedAt+=pausedFor
     if effectJob.projectile and effectJob.projectile.Parent then
      effectJob.projectile:SetAttribute('StartedAt',effectJob.startedAt);effectJob.projectile:SetAttribute('PausedAt',0)
     end
     if effectJob.impacted then effectPart:SetAttribute('EffectDoneAt',(effectPart:GetAttribute('EffectDoneAt') or now)+pausedFor) end
     effectPart:SetAttribute('EffectStartedAt',effectJob.startedAt);effectPart:SetAttribute('EffectPausedAt',0)
     if d.specialRecovery then
      local retired=resources[effectPart:GetAttribute('ResourceId')]
      if retired and retired.removeAt then retired.removeAt+=pausedFor end
     end
    end
    d.specialPausedAt=nil
   end
   d.model:SetAttribute('Position',d.pos);d.model:SetAttribute('Goal',d.goal);d.model:SetAttribute('Yaw',d.yaw)
   d.model:SetAttribute('WorkPaused',paused)
   d.model:SetAttribute('MotionPaused',not store:healthy(p.session))
  end
 end
end
local function resolveAfter(p,result)
 local after=p.pendingAfter;p.pendingAfter=nil
 local outcome=p.pendingOutcome;p.pendingOutcome=nil
 local committed=result and result.committed~=false
 if committed and after and not p.leaving then after(result) end
 if outcome and not p.leaving then outcome(committed and 'accepted' or 'rejected',committed and 'Card installed' or 'Save confirmed no change; try again') end
end
local function transact(p: any,id: any,mutate: any,after: any,outcome: any)
 if p.leaving or p.busy or not store:healthy(p.session) then return false end
 p.busy=true;setMotionPaused(p,true);p.pendingAfter=after;p.pendingOutcome=outcome;publish(p)
 task.spawn(function()
  local ok,result=store:transaction(p.session,id,mutate)
  if ok then p.dirty=false;resolveAfter(p,result)
  else
   notice(p,tostring(result))
   if p.session.readOnly then
    if p.pendingOutcome then p.pendingOutcome('uncertain','Saving outcome is being checked') end
    local recovered,reconciled=store:reconcile(p.session)
    if recovered then resolveAfter(p,reconciled) end
   else
    p.pendingAfter=nil;local report=p.pendingOutcome;p.pendingOutcome=nil
    if report then report('rejected',tostring(result)) end
   end
  end
  p.busy=false;setMotionPaused(p,not store:healthy(p.session));settleRuntime(p);if not p.leaving then publish(p) end
 end)
 return true
end
local logisticsTerrain=MapLayout.plan(C.Fields,{home.X,home.Y,home.Z})
logistics=Logistics.new({C=C,R=R,W=World,root=root,origin=home,profiles=profiles,drones=drones,patches=patches,
 data=data,Pro=Pro,Profile=Pro,Shops=Shops,capacityOf=function(profile) return Ca.capacity(profile,previewPerks(profiles[profile.userId])) end,healthy=healthy,characterRoot=characterRoot,inHome=atHome,
 notice=notice,updateProfile=publish,getClock=function() return now end,transact=transact,
 atDepotStation=function(p) return atStation(p,scene.converter or scene.packStation,18) end,
 groundHeight=function(x,z)
  if root:GetAttribute('DronerevolutionMapVersion') then return root:GetAttribute('LogisticsSurfaceHeight') or 4 end
  return logisticsTerrain:surface(x,z)
 end,
 guid=function() return Http:GenerateGUID(false) end,prices=prices,release=release,
 recall=function(d) local p=profiles[d.owner];if p then leaveDroneField(p,d) end end,
 assignFleet=function(p,field,fleet)
  if not healthy(p) or not playerCanMine(p,field) or activeAssault(p) or #fleet==0 then return false end
  for _,d in ipairs(fleet) do if d.owner~=p.player.UserId or d.hp<=0 or not DroneRoles.isWorker(d.role) then return false end end
  for _,d in ipairs(fleet) do
   if d.field~=field.id then release(d);spend(d) end
   d.field=field.id;d.autoField=field.id;d.state='Travel';d.commandOutAt=nil
  end
  return true
 end,
 canMine=playerCanMine,canDeploy=playerCanMine,isWorker=function(d) return DroneRoles.isWorker(d.role) end})
local function assignOre(p: any,d: any,r: any): boolean
 if d.carrierId or not DroneRoles.isWorker(d.role) or d.target==r or not sameRockType(d,r) then return false end
 local occupied={};for id,slot in pairs(r.slots) do
  if not drones[id] or drones[id].owner~=p.player.UserId then return false end
  occupied[slot]=true
 end
 local slot=1;while slot<=r.limit and occupied[slot] do slot+=1 end
 if slot>r.limit then return false end
 local old=d.field;local resume=d.autoField~=nil or (d.stats.plotAuto or 0)>0;release(d);spend(d)
 d.autoField=resume and r.field.id or nil;d.manualTarget=r.id
 d.field=r.field.id;d.target=r;d.targetSlot=slot;d.state='Travel';d.commandOutAt=nil;p.workField=r.field.id
 r.slots[d.id]=slot;updateSlots(r)
 if old~=d.field then dropFieldIfEmpty(p,old) end
 return true
end
local function dispatchOreQueue(p: any)
 if not healthy(p) or not characterRoot(p) or activeAssault(p) then return {} end
 local assigned={};local queue=p.oreQueue or {};local index=1
 while index<=#queue do
  local r=resources[queue[index]]
  if not r or r.paid or r.hp<=0 or not r.part.Parent or not playerCanMine(p,r.field) then table.remove(queue,index);p.publishDirty=true
  elseif now<r.readyAt or not nearMiningField(characterRoot(p).Position,r.field) then index+=1
  else
   local best,distance=nil,math.huge
   for _,d in ipairs(p.drones) do
    -- An explicit order may redirect automatic cutting/travel. Never cancel
    -- another manual order, a committed slam, or a specialist's physical job.
    local available=not d.target or (d.autoField and not d.manualTarget)
    if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) and available and d.target~=r and sameRockType(d,r) and not d.breaker and not d.specialJob and not d.specialRecovery
     and (not r.blockedUntil or now>=(r.blockedUntil[d.id] or 0)) then
     local n=(d.pos-r.position).Magnitude+(d.target and 10000 or 0)
     if n<distance then best,distance=d,n end
    end
   end
   if not best then index+=1
   elseif assignOre(p,best,r) then assigned[r.id]=best;table.remove(queue,index);p.publishDirty=true else index+=1 end
  end
 end
 p.oreQueue=queue
 return assigned
end
function scene.dispatchJunk(field)
 local crews={}
 for uid,p in pairs(profiles) do
  local hr=healthy(p) and characterRoot(p)
  if not hr then continue end
  local active,workers=0,{}
  for _,d in ipairs(p.drones) do
   if d.hp>0 and d.field==field.id and d.autoField==field.id and (d.deployedCarrier or (not d.carrierId and nearMiningField(hr.Position,field))) then
    local room=not d.deployedCarrier or logistics:capacity(p)>0
    if d.target and (not room or d.target.paid or not d.target.part.Parent) then release(d) end
    if d.target then active+=1
    elseif room and DroneRoles.isWorker(d.role) and not d.breaker and not d.lingerUntil and not d.specialRecovery then
     table.insert(workers,d)
    end
   end
  end
  if #workers>0 and active<JunkField.CrewCap then table.insert(crews,{id=uid,p=p,active=active,workers=workers,turn=p.junkTurn or 0}) end
 end
 JunkField.dispatch(crews,function(crew)
  for i,d in ipairs(crew.workers) do
   if chooseResource(d,field) then
    table.remove(crew.workers,i)
    scene.junkTurn=(scene.junkTurn or 0)+1;crew.p.junkTurn=scene.junkTurn;crew.turn=scene.junkTurn
    d.state='Travel'
    return true
   end
  end
  return false
 end)
end
function scene.saleMilestoneNotice(p,saleQuartz)
 if not scene.runStart or saleQuartz<=0 then return nil end
 local profile=data(p)
 local run=profile.run
 if run.pendingOffer then return nil end
 local balance=run.wallet.Quartz
 local price=Workshop.price(profile)
 local fundsPack=balance>=price and balance-saleQuartz<price
 local goal=Pro.milestone(profile).earnings
 local earnsPrestige=run.quartzEarnings>=goal and run.quartzEarnings-saleQuartz<goal
 if earnsPrestige and (run.packIndex>0 or not fundsPack) then
  return '+'..saleQuartz..' Quartz · Prestige ready'
 elseif fundsPack then
  return '+'..saleQuartz..' Quartz · Pack Counter ready'
 end
end
local function serviceDeliveries(p: any)
 if not healthy(p) or not characterRoot(p) or now<(p.nextDeliveryAction or 0) then return end
 local run=data(p).run
 for _,d in ipairs(p.drones) do
  local manifest=run.deliveries[d.id]
  local destination=scene.runStart and scene.packStation.Position or logistics:storagePosition(p) or (scene.converter or scene.packStation).Position
  if d.hp>0 and manifest and d.deliveryArrived and d.deliveryId==manifest.id and (d.pos-destination).Magnitude<=12 then
   local tx,runId,id=manifest.id,run.id,d.id
   p.nextDeliveryAction=now+.4
   transact(p,'deliveryFinish:'..tx,function(copy)
    if scene.runStart then
     local ok,result=Pro.finishDelivery(copy,id,prices,tx,runId)
     if ok then return result end;return nil,result
    end
    local parcel=copy.run.deliveries[id]
    if copy.run.id~=runId or not parcel or parcel.id~=tx or parcel.runId~=runId then return nil,'Delivery changed' end
    local accepted=Logistics.depositInto(copy,parcel.cargo)
    for mineral,units in pairs(parcel.cargo) do
     local remainder=units-(accepted[mineral] or 0)
     if remainder>0 then copy.run.logistics.pendingCargo[mineral]=(copy.run.logistics.pendingCargo[mineral] or 0)+remainder end
    end
    copy.run.deliveries[id]=nil
    return {droneId=id,id=tx,runId=runId,stored=true}
   end,function(result)
    local worker=drones[id]
    if worker and worker.owner==p.player.UserId then
     worker.deliveryArrived=false;worker.deliveryId=nil;worker.deliveryRequested=false
     worker.pickupAt=nil;worker.launchAt=nil;worker.unloadAt=nil
     worker.saleSerial=(worker.saleSerial or 0)+1;worker.saleAt=now
     worker.field=nil;worker.autoField=nil;worker.state='Collect';worker.collectAfter=now+RoleConfig.Courier.PickupCooldown
    end
    if scene.runStart then
     local proceeds=result.quartz>0 and (' · +'..result.quartz..' Quartz') or ''
     if (p.shiftSeconds or 0)>0 then
      p.shiftReadyRun=result.runId
      proceeds..=' · Surge ready'
     end
     notice(p,scene.saleMilestoneNotice(p,result.quartz) or 'Emptier sold '..result.units..' cargo'..proceeds)
    end
    p.publishDirty=true
   end)
   return
  elseif d.role=='Courier' and d.hp>0 and d.deliveryRequested and not manifest and now>=(d.collectAfter or 0) then
   local hr=characterRoot(p)
   if not scene.emptierReady(p,data(p)) or (d.pos-hr.Position).Magnitude>RoleConfig.Courier.PickupDistance or not d.pickupAt or now-d.pickupAt<RoleConfig.Courier.PickupHold or not los(d.pos,hr.Position,hr.Parent,{droneFolder}) then d.deliveryRequested=false;d.pickupAt=nil
   else
    local tx,runId,id=Http:GenerateGUID(false),run.id,d.id
    p.nextDeliveryAction=now+1
    transact(p,'deliveryBegin:'..tx,function(copy)
     if not scene.emptierReady(p,copy) then return nil,'Courier is waiting for cargo' end
     local batch=scene.runStart and Workshop.emptierBatch(copy) or d.stats.courierCapacity or RoleConfig.Courier.BatchUnits
     local ok,result=Pro.beginDelivery(copy,id,tx,runId,batch,scene.runStart~=nil);if ok then return result end;return nil,result
    end,function(result)
    p.nextEmptierPlan=nil
     if Pro.cargoUnits(data(p))==0 then p.emptierBagSince=nil end
     local worker=drones[id]
     if worker and worker.owner==p.player.UserId then
      release(worker);worker.deliveryId=result.id;worker.deliveryArrived=false;worker.state='Launch';worker.launchAt=now;worker.unloadAt=nil;worker.deliveryRequested=false
     end
     p.publishDirty=true
    end)
    return
   end
  end
 end
end
local function sellBackpack(p: any,automatic: boolean?)
 if activeAssault(p) then
  if not automatic then notice(p,'Recall your fighting drones before selling.') end
  return
 end
 if not automatic and not (atStation(p,scene.converter or scene.packStation,18) or atStation(p,scene.packStation,20) or atStation(p,shopStations.Quartz,20)) then
  notice(p,'Sell your backpack at the Workshop or SELL ORE.')
  return
 end
 if Pro.cargoUnits(data(p))==0 then notice(p,'Your backpack is empty.');return end
 local tx,runId=Http:GenerateGUID(false),data(p).run.id
 transact(p,'sell:'..tx,function(copy)
  local ok,result=Pro.sell(copy,prices,tx,runId)
  if ok then return result end;return nil,result
 end,function(result)
  p.emptierBagSince=nil;p.nextEmptierPlan=nil
  local amounts={}
  for _,key in ipairs(Shops.ORDER) do
   local n=key=='Quartz' and result.quartz or result.cargo[key]
   if n and n>0 then table.insert(amounts,tostring(n)..' '..key) end
  end
  local sale=automatic and 'Auto Sell' or 'Sold '..result.units..' ore'
  notice(p,scene.saleMilestoneNotice(p,result.quartz) or sale..' · +'..table.concat(amounts,', '))
  p.publishDirty=true
 end)
end
local function validPayload(payload)
 return type(payload)=='table' and type(payload.txId)=='string' and #payload.txId>=1 and #payload.txId<=100 and type(payload.runId)=='string' and #payload.runId<=100
end
local offerReceiptSerial=0
local function offerReply(pl: any,payload: any,status: string,reason: string)
 if not validPayload(payload) or type(payload.offerId)~='string' or #payload.offerId>160 then return end
 local gui=pl:FindFirstChildOfClass('PlayerGui');if not gui then return end
 offerReceiptSerial=offerReceiptSerial%1000000000+1
 gui:SetAttribute('MA_OfferReceipt',Http:JSONEncode({txId=payload.txId,runId=payload.runId,offerId=payload.offerId,status=status,reason=reason,serial=offerReceiptSerial}))
end
local function committedOffer(p: any,payload: any): (boolean,boolean)
 if not p or not validPayload(payload) then return false,false end
 for _,receipt in ipairs(p.session.receipts or {}) do
  local result=receipt.result
  if receipt.id=='choose:'..payload.txId and type(result)=='table' then
   local same=result.offerId==payload.offerId and result.runId==payload.runId and result.index==payload.index and result.selectedDroneId==payload.targetDroneId
   return same,not same
  end
 end
 return false,false
end
local function offerUnavailable(p: any,pl: any,payload: any,reason: string)
 if committedOffer(p,payload) then offerReply(pl,payload,'accepted','Card installed')
 elseif validPayload(payload) and p and p.pendingOfferTx==payload.txId then
  offerReply(pl,payload,'uncertain','Saving outcome is being checked')
 else offerReply(pl,payload,'rejected',reason) end
end
local function validCommandId(v)
 return type(v)=='string' and #v>0 and #v<=80 and v:match('^[%w_.:-]+$')~=nil
end
local function validDroneIntent(payload: any): boolean
 if type(payload)~='table' or not validCommandId(payload.requestId) then return false end
 if type(payload.runId)~='string' or #payload.runId>100 then return false end
 if type(payload.droneId)~='string' or #payload.droneId>160 then return false end
 return R.finite(payload.life) and payload.life%1==0
end
local function commandReply(pl: any,payload: any,status: any,reason: any,field: any,drone: any,resource: any,slot: any)
 if type(payload)~='table' or not validCommandId(payload.requestId) then return end
 local gui=pl:FindFirstChildOfClass('PlayerGui');if not gui then return end
 local count,available=0,0
 local p=profiles[pl.UserId]
 if field and p then
  for _,d in ipairs(p.drones) do if d.hp>0 and d.field==field.id then count=count+1 end end
  if playerCanMine(p,field) then for _,r in ipairs(field.resources) do
   if not r.paid and r.hp>0 and now>=r.readyAt then local used=0;for _ in pairs(r.slots) do used=used+1 end;available=available+math.max(0,r.limit-used) end
  end end
 end
 local state={requestId=payload.requestId,status=status,reason=reason,fieldId=field and field.id or nil,assignedCount=count,availableSlots=available,phase=field and field.e.phase or nil,droneId=drone and drone.id or nil,life=drone and drone.life or nil,resourceId=resource and resource.id or nil,slot=slot}
 gui:SetAttribute('MA_CommandState',Http:JSONEncode(state))
end
function scene.syncRuntimeFleet(p)
 for slot,owned in ipairs(scene.runtimeFleet(p)) do
  if not drones[owned.id] then snapshotDrone(spawnDrone(p,owned,slot)) end
 end
end
local function chooseCard(p: any,pl: any,payload: any)
   if type(payload.offerId)~='string' or #payload.offerId>160 or not R.finite(payload.index) or payload.index%1~=0 or payload.index<1 or payload.index>3 or (payload.targetDroneId~=nil and (type(payload.targetDroneId)~='string' or #payload.targetDroneId>100)) then offerReply(pl,payload,'rejected','Invalid choice');return end
   p.pendingOfferTx=payload.txId
   local started=transact(p,'choose:'..payload.txId,function(copy: any)
    local ok: boolean,r: any=Ca.select(copy,payload.offerId,payload.index,payload.txId,payload.runId,{atDepot=true,activeEncounter=false,targetDroneId=payload.targetDroneId});if ok then return r end;return nil,r
   end,function(result)
    scene.syncRuntimeFleet(p)
    refreshStats(p)
    local stars=result.stars or 0
    notice(p,stars>0 and ((result.selectedDroneId and (result.card.title..' fitted to '..result.card.targetName) or 'Upgrade installed')..' · +'..stars..' '..(stars==1 and 'Star' or 'Stars')) or 'Upgrade installed')
   end,function(status,reason) if status~='uncertain' then p.pendingOfferTx=nil end;offerReply(pl,payload,status,reason) end)
   if not started then p.pendingOfferTx=nil;offerReply(pl,payload,'rejected','Profile busy; try again') end
end
local function executePrestige(p: any,pl: any,payload: any)
 if payload.confirm~=true or type(payload.droneType)~='string' or #payload.droneType>24 or not atStation(p,scene.prestigeStation,15) then return end
 local function applyPrestige(copy: any): (any, any)
  local context: any={atDepot=true,activeEncounter=activeAssault(p),confirmed=true,droneType=payload.droneType}
  local ok: boolean,result: any=Pro.prestige(copy,payload.txId,payload.runId,context)
  if ok then return result end
  return nil,result
 end
 transact(p,'prestige:'..payload.txId,applyPrestige,function(result)
  for _,field in ipairs(patches) do local u=field.e.users[pl.UserId];if u then R.removeUser(field.e,pl.UserId,u.runId) end end
  p.oreQueue={};p.workField=nil;p.shiftReadyRun=nil;scene.clearSquare(p)
  p.testFleet=nil
  RoleEffects.ClearAbility(pl.UserId);rebuildFleet(p);logistics:refresh(p);scene.applyWalkSpeed(p)
  p.player:SetAttribute('MA_DroneReward',Http:JSONEncode(result))
 end)
end
local packDelivery=PackDelivery.new({
 root=root, players=Players, getClock=function() return now end, home=home, station=scene.packStation, healthy=healthy,
 inAssault=activeAssault, characterRoot=characterRoot,
 requireGround=scene.runStart~=nil and root:GetAttribute('EditableMap')==true,
 groundHeight=function(x,z) return logisticsTerrain:surface(x,z) end,
 offer=function(p) return data(p).run.pendingOffer end,
 open=function(p,id,outcome)
  if not transact(p,'open:'..id,function(copy)
   local ok,result=Ca.open(copy,id)
   if ok then return result end
   return nil,result
  end,nil,outcome) then outcome('rejected') end
 end,
})
local packPrompt=scene.packStation:FindFirstChildWhichIsA('ProximityPrompt')
local function economyAction(p: any,pl: any,action: string,payload: any): boolean
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then
  if action=='ChooseCard' then offerReply(pl,payload,'rejected','Run changed or assault active') end
  return false
 end
 if action=='ChooseCard' and not atStation(p,scene.packStation,24) then
  notice(p,'Return to the Pack Counter to choose your upgrade.')
  if action=='ChooseCard' then offerReply(pl,payload,'rejected','Return to the depot') end
  return false
 end
 if action=='BuyPack' then
  if not R.finite(payload.packIndex) or payload.packIndex%1~=0 then return false end
  if not atStation(p,scene.packStation,12) then return false end
  local function buyCard(copy: any): (any, any)
   local options: any={expectedPackIndex=payload.packIndex,atDepot=true,activeEncounter=false,crystalRun=scene.runStart~=nil}
   local ok: boolean,result: any=Ca.buy(copy,payload.txId,payload.runId,options)
   if ok then return result end
   return nil,result
  end
  local origin=characterRoot(p).Position
  transact(p,'buy:'..payload.txId,buyCard,function()
   local buyer=characterRoot(p)
   local position=buyer and (buyer.Position-scene.packStation.Position).Magnitude<12 and buyer.Position or origin
   packDelivery:spawn(p,data(p).run.pendingOffer,position,now)
  end)
 elseif action=='ChooseCard' then
  chooseCard(p,pl,payload)
 else
  executePrestige(p,pl,payload)
 end
 return true
end
if packPrompt then packPrompt.Triggered:Connect(function(pl)
 local p=profiles[pl.UserId]
 if not healthy(p) or p.player~=pl or not atStation(p,scene.packStation,12) or activeAssault(p) or now<(p.nextPackPress or 0) then return end
 p.nextPackPress=now+.45
 local run=data(p).run
 local offer=run.pendingOffer
 if offer then
  if offer.opened~=false then pl:SetAttribute('MA_ShowOffer',Http:GenerateGUID(false))
  else packDelivery:spawn(p,offer,characterRoot(p).Position,now);notice(p,'Open your delivered pack beside the counter.') end
  return
 end
 economyAction(p,pl,'BuyPack',{txId=Http:GenerateGUID(false),runId=run.id,packIndex=run.packIndex})
end) end
local function abilityContext(p,fieldId,operator,deployment)
 local function valid(id)
  local field=patches[id];local hr=characterRoot(p)
  return healthy(p) and hr~=nil and field~=nil and not activeAssault(p) and playerCanMine(p,field) and nearMiningField(hr.Position,field)
 end
 local state=deployment and deployment.state or p.ability
 local active=state and (state.burn or state.charge or state.swarm)
 local actor=operator or (active and active.actorId and drones[active.actorId])
 if not actor and not (active and active.actorId) then
  for _,d in ipairs(p.drones) do if d.hp>0 and (DroneRoles.isWorker(d.role) or DroneRoles.ability(d.role)) then actor=d;break end end
 end
 local hr=characterRoot(p);local origin=actor and actor.pos or (hr and hr.Position or home)
 if deployment then
  origin=deployment.position+Vector3.new(0,1,0)
  if deployment.temporary then actor={id=tostring(p.player.UserId)..':drop-gadget',owner=p.player.UserId,hp=1,life=1,role='Striker',pos=origin,
   owned={type='Blue'},stats={yieldMultiplier=1,geodeMultiplier=1,miningDPS=0}} end
 end
 local function unlocked(kind)
  if deployment then return kind==deployment.kind end
  if Shops.abilityUnlocked(data(p),kind) then return true end
  for _,d in ipairs(p.drones) do if d.hp>0 and DroneRoles.ability(d.role)==kind then return true end end
  return false
 end
 local function targetRecord(r)
  if not r or r.paid or r.hp<=0 or now<r.readyAt or not r.part.Parent then return nil end
  if not deployment and actor and not sameRockType(actor,r) then return nil end
  if deployment then
   local offset=r.position-deployment.position;local radius=Consumables.ITEMS[deployment.kind].radius
   if offset.X*offset.X+offset.Z*offset.Z>radius*radius then return nil end
  end
  for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=p.player.UserId then return nil end end
  -- Gadgets survey the current health-scaled body and actual cut height.
  local top=select(2,Feel.groundedRockFrame(r.position,r.part.Size,r.part:GetAttribute('GroundY'),r.stage,r.stageSeed,r.part:GetAttribute('CubicRock')==false))
  local click=deployment and deployment.kind=='Orbital' and deployment.targetId==r.id and deployment.position or r.position
  return {id=r.id,hp=r.hp,maxHP=r.maxHP,ground=r.part:GetAttribute('GroundY'),radius=math.max(.1,r.part.Size.X*.5),x=click.X,y=top,z=click.Z}
 end
 return {runId=data(p).run.id,fieldId=fieldId,origin={x=origin.X,y=origin.Y,z=origin.Z},
  placement=deployment and {x=origin.X,y=origin.Y,z=origin.Z},selectedId=deployment and deployment.targetId,perks=deployment and {scrapBots=2} or Ca.abilityPerks(data(p)),unlocked=unlocked,
  valid=function(id) return actor~=nil and actor.hp>0 and actor.owner==p.player.UserId and valid(id) end,
  full=function() return false end,
  -- During a burn inspect only its fixed target. The normal ctx.hit path still
  -- performs a fresh authoritative obstruction query before every damage tick.
  target=function(id,field)
   local r=resources[id]
   if valid(field) and r and r.field.id==field then return targetRecord(r) end
   return nil
  end,
  targets=function(id,kind)
   local list={};if not valid(id) then return list end
   for _,r in ipairs(patches[id].resources) do
    if r.field.cfg.SelectionOnly and not deployment then
     local square=p.miningSquare
     if not square or square.field~=r.field or not Mining.selectorTouches(square.center,square.half,r.part.CFrame,r.part.Size) then continue end
    end
    local target=targetRecord(r)
    if target then
     -- Survey the same vertical path that the authoritative orbital hit uses.
     -- A taller blocked crystal must not starve reachable work forever. Tiny
     -- scrap miners keep their normal nearby target list and contact checks.
     if kind~='Orbital' or abilityLineOfSight(p,Vector3.new(target.x,target.y+DroneAbilities.ORBITAL_ORIGIN_HEIGHT,target.z),r) then
      table.insert(list,target)
     end
    end
   end
   return list
  end,
  hit=function(id,damage,_kind,from)
   local resource=resources[id]
   if not resource or not actor or actor.hp<=0 or not valid(resource.field.id) or type(from)~='table' or not targetRecord(resource) then return false end
   if not R.finite(from.x) or not R.finite(from.y) or not R.finite(from.z) then return false end
   local accepted=hitResource(actor,resource,math.min(damage,resource.maxHP+10),false,nil,Vector3.new(from.x,from.y,from.z),deployment and 'Consumable' or nil,_kind=='Orbital' and {toolKind='Melt',point=Vector3.new(from.x,resource.part.Position.Y,from.z)} or nil)
   if accepted then scene.hazards:beam(Vector3.new(from.x,from.y,from.z),resource.part.Position,7,'laser') end
   if accepted and deployment and deployment.finishTemporary then
    deployment.finishTemporary(true);deployment.finishTemporary=nil
   end
   if accepted and deployment and not deployment.temporary and Consumables.accept(data(p).consumables) then p.dirty=true;p.publishDirty=true end
   return accepted,resource.paid==true
  end,
  emit=function(event) RoleEffects.Ability(deployment and (tostring(p.player.UserId)..':tool') or p.player.UserId,event,scene.droneTemplate) end}
end
-- The Crystal Run game uses the drone workflow. Legacy fixtures still load
-- the equipment services, and stored inventory stays valid for old saves.
if not scene.runStart then
 consumableService=ConsumableService.new({data=data,healthy=healthy,saveHealthy=function(p) return store:healthy(p.session) end,
  notice=notice,transact=transact,abilities=DroneAbilities,effects=RoleEffects,root=root,now=function() return now end,
  context=function(p,record) return abilityContext(p,record.fieldId,nil,record) end,
  placement=function(p,payload)
   if not R.finite(payload.fieldId) or payload.fieldId%1~=0 or not R.finite(payload.x) or not R.finite(payload.z)
    or math.abs(payload.x)>100000 or math.abs(payload.z)>100000 then return nil,'Choose a position inside a mining field' end
   local field=patches[payload.fieldId];local hr=characterRoot(p)
   if not field or not hr or activeAssault(p) or not playerCanMine(p,field) or not nearMiningField(hr.Position,field) then return nil,'Use tools beside an unlocked, unguarded field' end
   local localPoint=field.part.CFrame:PointToObjectSpace(Vector3.new(payload.x,field.center.Y,payload.z))
   if math.abs(localPoint.X)>field.part.Size.X*.5 or math.abs(localPoint.Z)>field.part.Size.Z*.5 then return nil,'Place the tool inside the field' end
   local ground=field.part.CFrame:PointToWorldSpace(Vector3.new(localPoint.X,field.part.Size.Y*.5,localPoint.Z))
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
   params.FilterDescendantsInstances={field.part,workspace.Terrain}
   local surface=workspace:Raycast(ground+Vector3.new(0,40,0),Vector3.new(0,-80,0),params)
   if surface then ground=surface.Position end
   if (hr.Position-ground).Magnitude>60 or not los(hr.Position,ground+Vector3.new(0,1.5,0),field.part,{droneFolder,p.player.Character}) then return nil,'Move closer to a clear placement spot' end
   return ground
  end})
 scene.toolRandom=Random.new()
 scene.fieldTools=ToolRules.Service.new({world=root,players=profiles,resources=resources,debris=Debris,healthy=healthy,
  root=characterRoot,run=function(p) return data(p).run.id end,encode=function(v) return Http:JSONEncode(v) end,
  now=function() return now end,random=function() return scene.toolRandom:NextNumber() end,notice=notice,hazards=scene.hazards,
  stock=function(p,kind) return data(p).consumables.counts[kind] or 0 end,
  eligible=function(p,r,position)
   if now<r.readyAt or not playerCanMine(p,r.field) or not nearMiningField(position,r.field) or activeAssault(p) then return false end
   for id in pairs(r.slots) do local worker=drones[id];if not worker or worker.owner~=p.player.UserId then return false end end
   return true
  end,
  gadget=function(p,item,target,point)
   if not item.saved then
    return consumableService:drop(p,item.kind,target,point,function(used) scene.fieldTools:finishGadget(p,item,used) end)
   end
   local profile=data(p)
   return consumableService:command(p,{kind=item.kind,runId=profile.run.id,version=profile.consumables.version,txId=Http:GenerateGUID(false),fieldId=target.field.id},point,target.id)
  end,
  clear=function(from,to,character,target) return los(from,to,target,{droneFolder,character}) end,
  cast=function(from,to,radius,character)
   if (to-from).Magnitude<1e-6 then return nil end
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
   params.FilterDescendantsInstances={droneFolder,character,root.FieldTools,root.ToolImpacts}
   if radius==0 then return workspace:Raycast(from,to-from,params) end
   return workspace:Spherecast(from,radius,to-from,params)
  end,
  hit=function(p,r,amount,origin,kind,point)
   -- Equipment works without borrowing a live drone or changing its orders.
   local actor={id=tostring(p.player.UserId)..':field-tool',owner=p.player.UserId,hp=1,life=1,role='Striker',pos=origin,
    owned={type='Blue'},stats={yieldMultiplier=1,geodeMultiplier=1,miningDPS=0}}
   return hitResource(actor,r,amount,false,nil,origin,'FieldTool',{consumable=true,toolKind=kind,point=point})
  end})
end
do
 local function finishAbility(p,token,context)
  local charge=p.ability.charge
  local ok,reason=DroneAbilities.confirm(p.ability,token,now,context)
  if ok then
   if p.ability.swarm and charge then p.ability.swarm.actorId=charge.actorId end
   data(p).run.abilityCooldowns=Pro.clone(p.ability.cooldowns);p.dirty=true
  end
  p.publishDirty=true;return ok,reason
 end
 roleAbilityStep=function(d,p,hr,dt)
  d.mining=false
  local kind=DroneRoles.ability(d.role);local field=workingField(p,hr)
  if not field or field.junk then followRole(d,p,hr,dt);return end
  p.ability=p.ability or DroneAbilities.new(data(p).run.abilityCooldowns,data(p).run.id)
  local ability=p.ability;local charge=ability.charge
  if now<(ability.cooldowns[kind] or 0) and not (charge and charge.actorId==d.id)
   and not (kind=='Orbital' and ability.burn and ability.burn.actorId==d.id)
   and not (kind=='Scrap' and ability.swarm and ability.swarm.actorId==d.id) then
   followRole(d,p,hr,dt,kind=='Orbital' and 'OrbitalCool' or 'SwarmCool');return
  end
  local context=abilityContext(p,field.id,d)
  if charge and charge.actorId==d.id then
   d.state=kind=='Orbital' and 'OrbitalCharge' or 'SwarmDeploy'
   if now>=charge.started+1.4 then finishAbility(p,charge.token,context) end
  elseif kind=='Orbital' and ability.burn and ability.burn.actorId==d.id then d.state='OrbitalBurn'
  elseif kind=='Scrap' and ability.swarm and ability.swarm.actorId==d.id then d.state='SwarmActive'
  elseif now<(ability.cooldowns[kind] or 0) then d.state=kind=='Orbital' and 'OrbitalCool' or 'SwarmCool'
  else d.state=kind=='Orbital' and 'OrbitalSurvey' or 'SwarmReady' end
  local goal
  if kind=='Orbital' then
   local target=ability.burn and ability.burn.actorId==d.id and resources[ability.burn.targetId] or (charge and charge.actorId==d.id and resources[charge.targetId]) or nil
   if not target and (d.surveyField~=field.id or now>=(d.nextSurveyAt or 0)) then
    d.surveyField=field.id;d.nextSurveyAt=now+C.Snapshot;d.surveyTargetId=nil
    local largest=-1
    for _,node in ipairs(context.targets(field.id,'Orbital')) do if node.maxHP>largest then target=resources[node.id];largest=node.maxHP end end
    d.surveyTargetId=target and target.id or nil
   end
   if not target then target=d.surveyTargetId and resources[d.surveyTargetId] end
   if target and (target.paid or target.hp<=0 or not target.part.Parent) then target=nil end
   goal=target and target.position+Vector3.new(0,math.max(12,target.fullSize.Y*.5+7),0) or hr.Position+Vector3.new(4,10,0)
  else goal=hr.Position+Vector3.new(4,4,-3) end
  move(d,goal,dt)
  -- Hardware performs the normal server gadget, sharing its saved cooldown and
  -- completing its charge automatically without a timing minigame.
  if not ability.charge and not (kind=='Orbital' and ability.burn) and not (kind=='Scrap' and ability.swarm) and now>=(ability.cooldowns[kind] or 0) and (d.pos-goal).Magnitude<1 then
   local ok=DroneAbilities.begin(ability,kind,now,context)
   if ok then ability.charge.actorId=d.id;ability.charge.automatic=true;p.publishDirty=true end
  end
 end
end
local function miningAbility(p,payload)
 if type(payload)~='table' or payload.runId~=data(p).run.id or (payload.kind~='Orbital' and payload.kind~='Scrap') or not R.finite(payload.fieldId) or payload.fieldId%1~=0 or not patches[payload.fieldId] then return end
 if payload.op~='begin' then return end
 p.ability=p.ability or DroneAbilities.new(data(p).run.abilityCooldowns,data(p).run.id)
 local context=abilityContext(p,payload.fieldId)
 local ok,reason=DroneAbilities.begin(p.ability,payload.kind,now,context)
 if ok then data(p).run.abilityCooldowns=Pro.clone(p.ability.cooldowns);p.dirty=true end
 notice(p,reason);p.publishDirty=true
end
local function buyShopUpgrade(p,pl,payload)
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then return end
 if not atStation(p,shopStations.Quartz,15) then notice(p,'Visit the Quartz Workshop.');return end
 transact(p,'shop:'..payload.txId,function(copy)
  local ok,result=Ca.upgrade(copy,payload.upgradeId,payload.level,payload.txId,payload.runId,{atDepot=true,activeEncounter=false})
  if ok then return result end;return nil,result
 end,function(result) refreshStats(p);notice(p,result.title..' · '..result.level..'×');p.publishDirty=true end)
end
function scene.buyStarUpgrade(p,payload)
 if not validPayload(payload) or payload.runId~=data(p).run.id or activeAssault(p) then return end
 if not atStation(p,shopStations.Ruby,12) then notice(p,'Visit the Star Shop.');return end
 transact(p,'stars:'..payload.txId,function(copy)
  local ok,result=Pro.buyStarUpgrade(copy,payload.upgradeId,payload.level,payload.txId,payload.runId)
  if ok then return result end;return nil,result
 end,function(result)
  scene.syncRuntimeFleet(p)
  if result.id=='selector' and p.miningSquare then
   local width=Workshop.selectorWidth(data(p))
   -- Keep the pin object so active cuts, deliveries and press jobs stay attached.
   p.miningSquare.half=width*.5
   p.player:SetAttribute('MA_SelectorWidth',width)
  end
  scene.applyWalkSpeed(p);notice(p,result.title..' · '..result.level..'×');p.publishDirty=true
 end)
end
function scene.canPairCut(p,r)
 if r.hardness<Workshop.PAIRED_CUT_HARDNESS then return false end
 for id in pairs(r.slots) do
  local worker=drones[id]
  if not worker or worker.owner~=p.player.UserId or not DroneRoles.isMiner(worker.role) then return false end
 end
 local miners=0
 for _,d in ipairs(p.drones) do
  if d.hp>0 and not d.carrierId and DroneRoles.isMiner(d.role) then
   miners+=1
   if miners==2 then return true end
  end
 end
 return false
end
function scene.prioritizeSquareApproach(p,square)
 local focus=resources[square.pairId or square.leadId]
 if not focus then return end
 local needed=square.pairId and 2 or 1
 for _ in pairs(focus.slots) do needed-=1 end
 if needed<=0 then return end
 local approaches={}
 for _,d in ipairs(p.drones) do
  if d.hp<=0 or d.carrierId or d.recharging or (d.stats.batteryCapacity>0 and d.battery<=0)
   or not DroneRoles.isWorker(d.role) or (square.pairId and not DroneRoles.isMiner(d.role))
   or (focus.blockedUntil and now<(focus.blockedUntil[d.id] or 0)) or not sameRockType(d,focus) then continue end
  if not d.target and not d.breaker and not d.specialRecovery then
   needed-=1
   d.squareSearchAt=nil
  elseif d.target~=focus and d.squareJob and not scene.committedWork(d) then
   if d.squareJob==square then
    table.insert(approaches,{drone=d,time=(d.pos-focus.position).Magnitude/travelSpeed(d)})
   else
    -- An obsolete approach will release itself on the next worker tick.
    needed-=1
    d.squareSearchAt=nil
   end
  end
 end
 if needed<=0 then return end
 table.sort(approaches,function(a,b) return a.time==b.time and a.drone.slot<b.drone.slot or a.time<b.time end)
 for i=1,math.min(needed,#approaches) do
  local d=approaches[i].drone
  local chargedPin=d.chargedPin
  release(d);d.chargedPin=chargedPin;d.squareSearchAt=nil
 end
end
function scene.moveSquareWork(p,current,square)
 if not current or current.field~=square.field then return end
 local press=p.compactor
 if press and press.pressSquare==current and press.pressDock and scene.cargoInSquare(square,press.pressDock) then press.pressSquare=square end
 local function staysInSquare(r)
  return r and not r.paid and r.part.Parent
   and Mining.selectorTouches(square.center,square.half,r.part.CFrame,r.part.Size)
 end
 for _,r in ipairs(square.field.resources) do
  if r.lastPin==current and r.lastPinOwner==p.player.UserId and staysInSquare(r) then r.lastPin=square end
 end
 for _,d in ipairs(p.drones) do
  local target=d.target
  if d.squareJob==current and staysInSquare(target) then
   local changingPair=current.pairId==target.id and square.pairId~=target.id
   if scene.committedWork(d) or not changingPair then
    d.squareJob=square
    if d.chargedPin==current then d.chargedPin=square end
   end
  end
  if d.resumePin==current and staysInSquare(resources[d.resumeResourceId]) then d.resumePin=square end
 end
end
function scene.placeSquare(p,payload)
 if type(payload)~='table' or payload.runId~=data(p).run.id or not R.finite(payload.fieldId) or typeof(payload.position)~='Vector3' then return end
 local field=patches[payload.fieldId]
 if not field or not field.cfg.SelectionOnly or activeAssault(p) then return end
 local position=payload.position
 if not R.finite(position.X) or not R.finite(position.Z) then return end
 local part=field.part
 local center=Mining.selectorCenter(position,part.CFrame,part.Size)
 if not center then return end
 local hr=characterRoot(p)
 local square={field=field,center=center,half=Workshop.selectorWidth(data(p))*.5}
 if not hr or not scene.squareInRange(hr.Position,square) then return end
 local leadId=payload.leadId
 local lead=type(leadId)=='string' and #leadId<=128 and resources[leadId]
 if lead and lead.field==field and not lead.paid and not lead.cargoProduced and lead.hp>0 and lead.part.Parent and now>=lead.readyAt
  and Mining.selectorTouches(center,square.half,lead.part.CFrame,lead.part.Size) then
  if scene.canPairCut(p,lead) then square.pairId=leadId;square.focusId=leadId
  elseif not next(lead.slots) then square.leadId=leadId;square.focusId=leadId
  else
   for id in pairs(lead.slots) do
    local worker=drones[id]
    if worker and worker.owner==p.player.UserId and worker.target==lead then square.focusId=leadId;break end
   end
  end
 end
 local current=p.miningSquare
 local samePin=current and current.field==field and current.half==square.half and (current.center-center).Magnitude==0
 if samePin and leadId~=nil and not square.focusId then return end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={part.Parent.Parent};params.RespectCanCollide=true
 local from=hr.Position+Vector3.new(0,1,0)
 if workspace:Raycast(from,center+Vector3.new(0,2,0)-from,params) then return end
 if samePin then
  current.leadId=square.leadId;current.pairId=square.pairId;current.focusId=square.focusId
  scene.prioritizeSquareApproach(p,current)
  scene.publishSquareFocus(p,current)
  return
 end
 scene.moveSquareWork(p,current,square)
 p.oreQueue={};p.workField=field.id;p.miningSquare=square
 scene.prioritizeSquareApproach(p,square)
 scene.publishSquareStatus(p)
 p.player:SetAttribute('MA_SelectorWidth',square.half*2)
 p.player:SetAttribute('MA_Selector',center)
end
local function commandPlayer(pl: any,action: any,payload: any)
 local p=profiles[pl.UserId];if not p or p.player~=pl then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerReply(pl,payload,'rejected','Fleet unavailable') end;return end
 if action=='ChooseCard' then
  local committed,conflict=committedOffer(p,payload)
  if committed then offerReply(pl,payload,'accepted','Card installed');return end
  if conflict then offerReply(pl,payload,'rejected','This install was already used');return end
 end
 local duration=math.max(0,now-p.bucketAt);p.tokens=math.min(7,p.tokens+duration*3);p.bucketAt=now
 if p.tokens<1 then if now>=(p.nextCommandRejection or 0) then p.nextCommandRejection=now+.35;commandReply(pl,payload,'rejected','Too many commands');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Too many commands') end end;return end;p.tokens=p.tokens-1
 if type(action)~='string' or #action>24 or not healthy(p) or not characterRoot(p) then commandReply(pl,payload,'rejected','Fleet unavailable');if action=='ChooseCard' then offerUnavailable(p,pl,payload,'Fleet unavailable') end;return end
 if p.miningSquare and (action=='MineOre' or action=='Patch' or action=='AssignSlot' or action=='CancelDrone') then
  local reason='Recall your fleet before giving it a different kind of order.'
  notice(p,reason);commandReply(pl,payload,'rejected',reason);return
 end
 if action=='BuyDrone' then
  local kind=type(payload)=='table' and payload.droneType or payload
  if type(kind)~='string' or not DroneCatalog.Types[kind] then return end
  if not atHome(p) or activeAssault(p) then notice(p,'Visit the depot to buy a permanent miner.');return end
  if type(payload)=='table' and (not validPayload(payload) or payload.runId~=data(p).run.id) then return end
  local txId=type(payload)=='table' and payload.txId or Http:GenerateGUID(false)
  local runId=data(p).run.id
  transact(p,'drone:'..txId,function(copy)
   local ok,result=Pro.buyDrone(copy,kind,txId,runId,{atDepot=true,activeEncounter=false})
   if ok then return result end;return nil,result
  end,function(result)
   local owned
   for _,entry in ipairs(data(p).fleet) do if entry.id==result.droneId then owned=entry;break end end
   if owned and not drones[owned.id] then
    if p.testFleet then table.insert(p.testFleet,Pro.clone(owned)) end
    spawnDrone(p,owned,#p.drones+1)
   end
   logistics:refresh(p);notice(p,DroneCatalog.Types[kind].Name..' added to your permanent fleet.');p.publishDirty=true
  end)
 elseif action=='BuyCarrier' or action=='BuyBackpack' or action=='LoadCarrier' or action=='CarrierPatch' or action=='RecallCarrier' or action=='Deposit' or action=='LaunchStorage' or action=='AutoLaunch' then
  logistics:command(p,action,payload)
 elseif action=='MiningAbility' then
  miningAbility(p,payload)
 elseif action=='PlaceConsumable' then
  if consumableService then consumableService:command(p,payload) end
 elseif action=='EquipFieldTool' or action=='UseFieldTool' then
  if scene.fieldTools then scene.fieldTools:command(p,action,payload) end
 elseif action=='BuyUpgrade' then
  buyShopUpgrade(p,pl,payload)
 elseif action=='BuyStarUpgrade' then
  scene.buyStarUpgrade(p,payload)
 elseif action=='PlaceSelector' then
  scene.placeSquare(p,payload)
 elseif action=='DevFillBag' then
  if not RunService:IsStudio() then return end
  local field=p.workField and patches[p.workField] or patches[1]
  local material=field.cfg.Material or field.cfg.Key or 'Quartz'
  local added=Pro.addCargo(data(p),material,math.max(0,Ca.capacity(data(p),previewPerks(p))-Pro.cargoUnits(data(p))),Ca.capacity(data(p),previewPerks(p)))
  if added>0 then p.dirty=true;p.publishDirty=true end
 elseif action=='DevAddDrone' then
  if not RunService:IsStudio() or type(payload)~='table' or type(payload.role)~='string' then return end
  local role=RoleConfig.StudioRoles[payload.role]
  if not role or #p.drones>=24 then return end
  p.testFleet=p.testFleet or Pro.clone(data(p).fleet)
  p.testRoll=(p.testRoll or 0)+1
  local owned={id=string.format('test:%d:add:%d',pl.UserId,p.testRoll),type=payload.role,role=payload.role,name=RoleConfig.Types[payload.role].DisplayName,flightHeight=role.height,base=Pro.clone(role.base)}
  table.insert(p.testFleet,owned)
  local d=spawnDrone(p,owned,#p.drones+1);snapshotDrone(d)
  pl:SetAttribute('MA_TestLoadoutLabel',tostring(#p.testFleet)..' preview drones')
  refreshStats(p);p.publishDirty=true
 elseif action=='NormalLoadout' then
  if not preview then return end
  leaveField(p);RoleEffects.ClearAbility(pl.UserId);p.ability=nil;p.testFleet=nil;rebuildFleet(p);logistics:refresh(p)
  notice(p,'Using your usual crew.');p.publishDirty=true
 elseif action=='TestLoadout' or action=='RoleLoadout' then
  if not preview or now<(p.nextTestLoadout or 0) then return end
  p.nextTestLoadout=now+RoleConfig.Settings.RandomizeCooldown;pl:SetAttribute('MA_TestReadyAt',p.nextTestLoadout)
  leaveField(p)
  for _,carrier in ipairs(data(p).logistics.carriers) do logistics:command(p,'RecallCarrier',carrier.id) end
  RoleEffects.ClearAbility(pl.UserId);p.ability=nil;p.testFleet=action=='RoleLoadout' and roleTestFleet(p) or randomTestFleet(p);rebuildFleet(p);logistics:refresh(p)
  notice(p,action=='RoleLoadout' and 'All drone types ready. Click a rock to start mining.' or 'Random test loadout ready — no saved fleet changed.')
 elseif action=='Recall' then
  leaveField(p)
  for _,carrier in ipairs(data(p).logistics.carriers) do logistics:command(p,'RecallCarrier',carrier.id) end
  for _,d in ipairs(p.drones) do if d.hp>0 then d.state='Follow' end end
  notice(p,'Orders cleared. Your backpack stays with you.');commandReply(pl,payload,'recalled','Orders cleared')
 elseif action=='Evade' then
  if now<(p.nextEvade or 0) then return end;p.nextEvade=now+2
  for _,d in ipairs(p.drones) do if d.field and R.participates(patches[d.field].e,d,data(p).run.id) then d.evade=d.evade+1 end end
 elseif action=='CancelDrone' or action=='AssignSlot' then
  local function reject(why,field,d,r) commandReply(pl,payload,'rejected',why,field,d,r) end
  if not validDroneIntent(payload) then reject('Invalid request');return end
  if payload.runId~=data(p).run.id then reject('Run changed');return end
  local d=drones[payload.droneId]
  if not d or d.owner~=pl.UserId then reject('Drone unavailable');return end
  if d.carrierId then reject('Select its carrier to give orders',nil,d);return end
  if d.life~=payload.life or d.hp<=0 or not R.allowed(d.owner,pl.UserId,d.state) then reject('Drone reprinted or unavailable',nil,d);return end
  if action=='CancelDrone' then
   local old=d.field;release(d);spend(d);d.field=nil;d.autoField=nil;d.state='Return';dropFieldIfEmpty(p,old)
   commandReply(pl,payload,'accepted','Drone recalled',patches[old],d);return
  end
  if not R.finite(payload.fieldId) or payload.fieldId%1~=0 or type(payload.resourceId)~='string' or #payload.resourceId>160 then reject('Invalid request',nil,d);return end
  local field=patches[payload.fieldId];local r=resources[payload.resourceId]
  if field and field.cfg.SelectionOnly then reject('Place the mining square to select crystals',field,d);return end
  if not field or (characterRoot(p).Position-field.center).Magnitude>(C.CommandRadius or 90) then reject('Too far from field',field,d);return end
  if not playerCanMine(p,field) or activeAssault(p) then reject('Clear guards first',field,d);return end
  if not nearMiningField(characterRoot(p).Position,field) then reject('Move closer to the mining area',field,d);return end
  if field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if not DroneRoles.isWorker(d.role) then reject('Choose the miner or breaker',field,d);return end
  if not r or r.field~=field or not r.part.Parent or r.paid or r.hp<=0 then reject('Rock unavailable',field,d);return end
  if now<r.readyAt then reject('Rock is still settling',field,d,r);return end
  if not sameRockType(d,r) then reject('This rock is already assigned to another drone type or crew',field,d,r);return end
  if d.target==r and d.field==field.id and r.slots[d.id] then commandReply(pl,payload,'accepted','Already assigned',field,d,r,r.slots[d.id]);return end
  local occupied={};for _,v in pairs(r.slots) do occupied[v]=true end
  local slot=1;while slot<=r.limit and occupied[slot] do slot=slot+1 end
  if slot>r.limit then reject('Resource is busy',field,d,r);return end
  local old=d.field;release(d);spend(d);d.autoField=nil;d.field=field.id;d.target=r;d.targetSlot=slot;r.slots[d.id]=slot;updateSlots(r);d.state='Travel';d.shotAt=now;p.workField=field.id
  if old~=field.id then dropFieldIfEmpty(p,old) end
  commandReply(pl,payload,'accepted','Drone assigned',field,d,r,slot)
 elseif action=='MineOre' then
  local id=type(payload)=='table' and payload.resourceId or payload
  if type(payload)=='table' and not validCommandId(payload.requestId) then return end
  local function reply(status,reason,r,d)
   commandReply(pl,payload,status,reason,r and r.field,d,r)
   if status=='rejected' then notice(p,reason) end
  end
  if type(payload)=='table' and payload.runId~=data(p).run.id then reply('rejected','Run changed');return end
  if type(id)~='string' or #id>160 then reply('rejected','Invalid rock');return end
  local r=resources[id];local hr=characterRoot(p)
  if not r or r.paid or r.hp<=0 or not r.part.Parent then reply('rejected','That rock has already broken');return end
  if r.field.cfg.SelectionOnly then reply('rejected','Place the mining square to select crystals',r);return end
  p.oreQueue=p.oreQueue or {}
  for index,queued in ipairs(p.oreQueue) do if queued==id then
   if type(payload)=='table' and payload.toggle==true then
    table.remove(p.oreQueue,index);p.publishDirty=true;reply('canceled','Queued order canceled',r)
   else reply('queued','Already queued',r) end
   return
  end end
  if not nearMiningField(hr.Position,r.field) then reply('rejected','Move closer to that rock',r);return end
  if activeAssault(p) or not playerCanMine(p,r.field) then reply('rejected','Clear the guards before mining',r);return end
  if now<r.readyAt then reply('rejected','Rock is still growing',r);return end
  local hasWorker=false;for _,d in ipairs(p.drones) do if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) then hasWorker=true;break end end
  if not hasWorker then reply('rejected','A miner or breaker is needed',r);return end
  local used=0;local mine
  for workerId in pairs(r.slots) do
   used+=1;local worker=drones[workerId]
   if not worker or worker.owner~=pl.UserId then reply('rejected','Another crew is working this rock',r);return end
   mine=worker
  end
  if used>=r.limit then reply('accepted','Crew already working this rock',r,mine);return end
  if #p.oreQueue>=16 then reply('rejected','16 orders queued. Click a queued rock to cancel it',r);return end
  if r.field.cfg.Turrets>0 and r.field.e.phase=='Cleared' then grantClear(p,r.field) end
  p.workField=r.field.id;table.insert(p.oreQueue,r.id);p.publishDirty=true
  local sent=dispatchOreQueue(p)
  if sent[r.id] then reply('accepted',used>0 and 'Helper sent' or 'Miner sent',r,sent[r.id]);return end
  reply('queued','Queued · next available worker',r)
 elseif action=='ReturnCargo' then
  if payload~=nil and (type(payload)~='string' or #payload>160) then return end
  sellBackpack(p)
 elseif action=='Patch' then
  local fieldId=type(payload)=='table' and payload.fieldId or payload
  if type(payload)=='table' and not validCommandId(payload.requestId) then return end
  if not R.finite(fieldId) or fieldId%1~=0 then commandReply(pl,payload,'rejected','Invalid field');return end
  local field=patches[fieldId];local hr=characterRoot(p)
  if field and field.cfg.SelectionOnly then return end
  if not field or (hr.Position-field.center).Magnitude>(C.CommandRadius or 90) then commandReply(pl,payload,'rejected','Too far from field',field);return end
  if not field.cfg.AlwaysUnlocked and not Shops.unlocked(data(p),field.cfg.Key) then commandReply(pl,payload,'rejected','Buy access in the previous mineral shop first',field);return end
  local can=playerCanMine(p,field)
  if can and field.cfg.Turrets>0 and field.e.phase=='Cleared' then grantClear(p,field) end
  if can then
   if not nearMiningField(hr.Position,field) then commandReply(pl,payload,'rejected','Move closer to the mining area',field);return end
   if activeAssault(p) then commandReply(pl,payload,'rejected','Recall fighting drones first',field);return end
   local assigned=0
   for _,d in ipairs(p.drones) do
    if not d.carrierId and d.hp>0 and DroneRoles.isWorker(d.role) then
     local old=d.field
     if old~=field.id then release(d);spend(d);d.field=field.id;d.state='Travel';d.shotAt=now end
     d.autoField=field.id;d.commandOutAt=nil;assigned+=1
     if old~=field.id then dropFieldIfEmpty(p,old) end
    end
   end
   if assigned==0 then
    local reason='An available mining drone is needed'
    commandReply(pl,payload,'rejected',reason,field);notice(p,reason);return
   end
   if p.workField~=field.id then p.oreQueue={} end
   p.workField=field.id
   if field.junk then notice(p,'Crew assigned to '..(field.junkTheme or 'salvage')..'. Press Recall to stop.') end
   commandReply(pl,payload,'accepted',field.junk and 'Clearing order accepted' or 'Mining area assigned',field)
  else
   local fleet={}
   for _,d in ipairs(p.drones) do
    if not d.carrierId and d.hp>0 and (DroneRoles.combat(d.role) or d.role=='Medic') and R.allowed(d.owner,pl.UserId,d.state) then table.insert(fleet,d) end
   end
   local fighters=0;for _,d in ipairs(fleet) do if d.role~='Medic' then fighters+=1 end end
   if fighters==0 then commandReply(pl,payload,'rejected','Reprint a fighting drone first',field);return end
   p.oreQueue={};p.workField=nil
   -- Living replacements may join at any time. Repeating a guard order does
   -- not restart an existing attack or refresh its once-per-life entry shield.
   for _,d in ipairs(fleet) do
    local old=d.field
    if old~=field.id then release(d);spend(d);d.field=field.id;d.state='Travel';d.shotAt=now end
    d.autoField=field.id
    if old~=field.id then dropFieldIfEmpty(p,old) end
   end
   R.begin(field.e);wakeTurrets(field,pl)
   if R.enroll(field.e,pl.UserId,data(p).run.id,fleet) then
    for _,d in ipairs(fleet) do
     d.guardShieldLives=d.guardShieldLives or {}
     if d.guardShieldLives[field.id]~=d.life then
      d.shield=field.e.roster[d.id].stats.entryShield or 0;d.guardShieldLives[field.id]=d.life
     end
    end
   end
   commandReply(pl,payload,'accepted','Fighting guards',field)
  end
 elseif action=='Sell' then
  sellBackpack(p)
 elseif action=='BuyPack' or action=='ChooseCard' or action=='Prestige' then
  if not economyAction(p,pl,action,payload) then return end
 end
 p.publishDirty=true
end
command.OnServerEvent:Connect(commandPlayer)
local addPlayer
local function failPendingJoin(uid,why)
 local waiting=scene.pendingJoins[uid];scene.pendingJoins[uid]=nil
 if waiting and waiting.Parent then
  waiting:SetAttribute('MA_SaveStatus','Previous profile session unavailable — no defaults written')
  waiting:SetAttribute('MA_Notice',why)
 end
end
local function drainPendingJoin(uid,previous)
 if profiles[uid] or scene.loading[uid] then return end
 local waiting=scene.pendingJoins[uid];scene.pendingJoins[uid]=nil
 if waiting and waiting~=previous and waiting.Parent then task.spawn(addPlayer,waiting) end
end
addPlayer=function(pl)
 local current=profiles[pl.UserId]
 if current then
  -- PlayerAdded can race ahead of PlayerRemoving. A distinct same-ID Player
  -- must wait for the prior session even before its leave handler starts.
  if current.player~=pl and pl.Parent then scene.pendingJoins[pl.UserId]=pl end
  return
 end
 if scene.loading[pl.UserId] then
  if scene.loading[pl.UserId]~=pl then scene.pendingJoins[pl.UserId]=pl end
  return
 end
 scene.loading[pl.UserId]=pl
 pl:SetAttribute('MA_SaveStatus','Loading profile...')
 -- A prior bounded final-release attempt may have failed after its Player
 -- left. Recover that exact session before loading again; the manager's local
 -- lease guard would otherwise block every later reconnect in this server.
 local orphan=store.sessions[pl.UserId]
 if orphan and not orphan.closed then
  local resolved=true
  if orphan.readOnly then resolved=store:reconcile(orphan) end
  if resolved and not orphan.closed then resolved=store:release(orphan) end
  if not resolved then
   scene.loading[pl.UserId]=nil
   if pl.Parent then pl:SetAttribute('MA_SaveStatus','Previous profile session unavailable — no defaults written');pl:SetAttribute('MA_Notice','Previous session still needs safe reconciliation; try again later.') end
   drainPendingJoin(pl.UserId,pl);return
  end
 end
 local session,err=store:load(pl.UserId)
 scene.loading[pl.UserId]=nil
 if not session then
  if pl.Parent then pl:SetAttribute('MA_SaveStatus','Profile unavailable — no defaults written');pl:SetAttribute('MA_Notice',tostring(err)) end
  drainPendingJoin(pl.UserId,pl);return
 end
 if not pl.Parent then
  -- The first Player left while loading. Finish releasing its acquired lease
  -- before starting one queued replacement; uncertain storage never falls back
  -- to a new profile or bypasses that lease.
  local released=false
  for attempt=1,3 do
   if session.readOnly then store:reconcile(session) end
   if session.closed or store:release(session) then released=true;break end
   task.wait(.2*attempt)
  end
  if released then drainPendingJoin(pl.UserId,pl)
  else failPendingJoin(pl.UserId,'Previous session could not be safely released; try again later.') end
  return
 end
 -- Clear obsolete transient tokens; permanent plot unlocks are retained.
 session.data.run.entitlements={}
 local p={player=pl,session=session,drones={},tokens=7,bucketAt=now,busy=false,dirty=false,leaving=false,publishDirty=true}
 profiles[pl.UserId]=p
 pl:SetAttribute('MA_TestingEnabled',preview);pl:SetAttribute('MA_DevToolsEnabled',RunService:IsStudio());pl:SetAttribute('MA_NoRestock',false)
 pl:SetAttribute('MA_TestLoadoutLabel','Use RANDOM LOADOUT for 2–5 random drones')
 local spawnAt=(scene.spawnPosition or home)+Vector3.new(0,4,0)
 local function character(ch)
  local hr=ch:WaitForChild('HumanoidRootPart',10)
  if not hr or not pl.Parent then return end
  local firstField=scene.runStart or scene.fields[1].center
  if scene.fieldTools then scene.fieldTools:clear(p) end
  p.hazardAt={}
  if p.characterReady then leaveField(p,nil,nil,true) end
  p.characterReady=true
  scene.applyWalkSpeed(p)
  ch:PivotTo(CFrame.lookAt(spawnAt,Vector3.new(firstField.X,spawnAt.Y,firstField.Z)))
  if inStudio and scene.fieldTools and not p.previewToolsGranted then
   p.previewToolsGranted=true;scene.fieldTools:previewLoadout(p)
  end
 end
 p.connection=pl.CharacterAdded:Connect(character)
 rebuildFleet(p,spawnAt);logistics:create(p);publish(p)
 if pl.Character then task.spawn(character,pl.Character) end
end
Players.PlayerAdded:Connect(function(pl) task.spawn(addPlayer,pl) end)
local function removePlayer(pl)
 local p=profiles[pl.UserId];if not p or p.leaving then return end
 p.leaving=true;RoleEffects.ClearAbility(pl.UserId);leaveField(p);if p.connection then p.connection:Disconnect() end
 if scene.fieldTools then scene.fieldTools:clear(p) end
 logistics:remove(p);packDelivery:clear(p)
 for _,d in ipairs(p.drones) do release(d);spend(d);d.model:Destroy();drones[d.id]=nil end
 -- Wait for the one ordered economy operation, then final save/unlock. No default fallback.
 local deadline=os.clock()+12
 while p.busy and os.clock()<deadline do task.wait(.1) end
 local released=false
 if not p.busy then
  if consumableService then consumableService:clear(p) end
  p.session.data.run.entitlements={}
  for attempt=1,3 do
   if p.session.readOnly then local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end end
   if p.session.closed then released=true;break end
   local saved=store:release(p.session);if saved then released=true;break end
   if os.clock()>=deadline then break end;task.wait(.2*attempt)
  end
 end
 profiles[pl.UserId]=nil
 if released then drainPendingJoin(pl.UserId,pl)
 else failPendingJoin(pl.UserId,'Previous session could not be safely released; try again later.') end
end
Players.PlayerRemoving:Connect(removePlayer)
for _,pl in ipairs(Players:GetPlayers()) do task.spawn(addPlayer,pl) end
RunService.Heartbeat:Connect(function(dt: number)
 now=workspace:GetServerTimeNow()
 discoveries:Step()
 elapsed=math.min(elapsed+math.max(0,dt),C.Tick*(C.MaxCatchup or 6))
 local steps=0
 while elapsed>=C.Tick and steps<(C.MaxCatchup or 6) do
  elapsed=elapsed-C.Tick;steps=steps+1
  for _,field in ipairs(patches) do encounterStep(field) end
  logistics:tick(C.Tick)
  for _,p in pairs(profiles) do
   packDelivery:step(p,now)
   recallFromField(p)
   dispatchOreQueue(p)
   if consumableService then consumableService:step(p,C.Tick) end
   if p.ability and p.busy then DroneAbilities.pause(p.ability,C.Tick)
   elseif p.ability and healthy(p) and (p.ability.charge or p.ability.burn or p.ability.swarm) then
    local work=p.ability.burn or p.ability.swarm or p.ability.charge
    local swarm=p.ability.swarm;local burn=p.ability.burn;local charge=p.ability.charge
    DroneAbilities.step(p.ability,now,C.Tick,abilityContext(p,work and work.fieldId or 1,work and work.actorId and drones[work.actorId]),
     swarm and abilityContext(p,swarm.fieldId,swarm.actorId and drones[swarm.actorId]))
    if (burn and not p.ability.burn) or (charge and not p.ability.charge) then
     data(p).run.abilityCooldowns=Pro.clone(p.ability.cooldowns);p.dirty=true;p.publishDirty=true
    end
   end
  end
  pickupStep(C.Tick)
  if scene.runStart then for _,p in pairs(profiles) do scene.assignEmptierPickups(p) end end
  for _,field in ipairs(patches) do if field.junk then scene.dispatchJunk(field) end end
  swarmGrid=Feel.swarmGrid(drones)
  for _,d in pairs(drones) do droneStep(d,C.Tick) end
  if scene.fieldTools then scene.fieldTools:step(C.Tick) end
  for _,d in pairs(drones) do
   if d.hp>0 and d.mining and d.target and not d.target.paid and not d.target.field.cfg.SelectionOnly then scene.hazards:beam(d.pos,d.target.part.Position,4,'laser') end
  end
  for _,field in ipairs(patches) do turretStep(field);encounterStep(field) end
 end
 snapshotElapsed=snapshotElapsed+dt;autosaveElapsed=autosaveElapsed+dt
 if snapshotElapsed>=C.Snapshot then
  local snapshotDt=snapshotElapsed;snapshotElapsed=0
  for _,d in pairs(drones) do snapshotDrone(d) end
  scene.publishCharger()
  for _,field in ipairs(patches) do
   for _,r in ipairs(field.resources) do
    scene.regrow(r,snapshotDt)
    local solid=not r.referenceCrystal and not r.paid and now>=r.readyAt
    if field.junk then
     if r.part.CanQuery~=solid then r.part.CanQuery=solid end
     if solid and not r.part.CanCollide then solid=not scene.junkLandingOccupied(r.position,r.fullSize.Magnitude*.5) end
    end
    if r.part.CanCollide~=solid then r.part.CanCollide=solid;r.part.CanTouch=solid end
   end
   field.model:SetAttribute('Phase',field.e.phase);field.model:SetAttribute('EncounterId',nil);field.model:SetAttribute('PhaseEndsAt',nil)
   for _,t in ipairs(field.turrets) do
    local watcher: any=t.watcher and profiles[t.watcher];local hr: any=watcher and characterRoot(watcher)
    if t.awake and not hr then
     for uid in pairs(field.e.users) do
      local p=profiles[uid];local candidate=p and characterRoot(p)
      if candidate then t.watcher=uid;hr=candidate;break end
     end
    end
    if t.awake and t.hp>0 and hr then t.model:SetAttribute('WatchPosition',hr.Position) end
   end
   for i=#field.resources,1,-1 do local r=field.resources[i];if r.paid and r.removeAt and now>=r.removeAt and (r.part:GetAttribute('EffectPausedAt') or 0)<=0 then resources[r.id]=nil;r.part:Destroy();table.remove(field.resources,i) end end
   if field.junk then scene.replenishJunk(field);continue end
   local rate,count=respawnRate(field)
   field.model:SetAttribute('MiningDroneCount',count);field.model:SetAttribute('RespawnRate',rate)
   local replenishing=field.e.phase=='Safe' or field.e.phase=='Cleared' or scene.unlockedMiners(field)
   if replenishing then
    if field.cfg.ReferenceCrystals then field.respawnClock=now
    else field.respawnClock+=snapshotDt*rate end
   end
   table.sort(field.respawnQueue,scene.respawnEarlier)
   local replenished=0
   while replenishing and #field.respawnQueue>0 and field.respawnClock>=field.respawnQueue[1].at and replenished<field.cfg.Count do
    local due=0;for _,vacancy in ipairs(field.respawnQueue) do if vacancy.at<=field.respawnClock then due+=1 else break end end
    -- A geode reserves five future nodes. Consume five due replenishment tokens,
    -- rather than leaving four immortal retries behind after every shell cycle.
    local spawned,cost=scene.spawnReplacement(field,due<5 and 'Crystal' or nil,field.respawnQueue[1])
    if not spawned then
     -- One failed sample set establishes a field-level backoff for every token
     -- already due, rather than re-running 18 raycasts per snapshot for each
     -- blocked missing slot in turn. Future tokens keep their own due times.
     for _,vacancy in ipairs(field.respawnQueue) do
      if vacancy.at<=field.respawnClock then vacancy.at=field.respawnClock+2 end
     end
     table.sort(field.respawnQueue,scene.respawnEarlier);break
    end
    for _=1,cost do table.remove(field.respawnQueue,1) end
    replenished=replenished+cost
   end
  end
  for _,p in pairs(profiles) do
   if p.ability then
    local encoded=Http:JSONEncode(DroneAbilities.view(p.ability,now))
    if encoded~=p.lastAbilityJSON then p.lastAbilityJSON=encoded;p.player:SetAttribute('MA_Ability',encoded) end
   end
   serviceDeliveries(p);p.player:SetAttribute('MA_InAssault',activeAssault(p))
   scene.publishSquareStatus(p)
   if not p.busy then settleRuntime(p) end
   local profile=data(p)
   if healthy(p) and characterRoot(p) and scene.autoSellReady(p,profile,Pro.cargoUnits(profile)) then sellBackpack(p,true) end
   if p.publishDirty then p.publishDirty=false;publish(p) end
  end
 end
 if autosaveElapsed>=30 then
  autosaveElapsed=0
  for _,p in pairs(profiles) do
   if not p.busy and not p.leaving then
    p.busy=true;setMotionPaused(p,true)
    task.spawn(function()
     if p.session.readOnly then
      local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end
     end
     local ok,err=store:save(p.session)
     if not ok then
      notice(p,'Save delayed: '..tostring(err))
      if p.session.readOnly then local recovered,result=store:reconcile(p.session);if recovered then resolveAfter(p,result) end end
     else p.dirty=false end
     p.busy=false;setMotionPaused(p,not store:healthy(p.session));settleRuntime(p);publish(p)
    end)
   end
  end
 end
end)
game:BindToClose(function()
 local pending=0
 for _,p in pairs(profiles) do pending=pending+1;task.spawn(function() removePlayer(p.player);pending=pending-1 end) end
 local deadline=os.clock()+25;while pending>0 and os.clock()<deadline do task.wait(.1) end
end)
