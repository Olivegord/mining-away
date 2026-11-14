-- One shared upgrade pool. Repeated picks merge into the same stack.
-- These local tuning values travel with the saved offer, so reconnects never reroll.
local W={PACK_BASE=20,PACK_GROWTH=1.35,LEVEL_COST=20,LEVEL_GROWTH=1.7,PRESTIGE_BASE=160}
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
-- Reach the first permanent gain while the first few cards still feel new.
-- Later goals ask the player to exploit the increasingly valuable deep route.
W.PRESTIGE_GOALS={160,400,1000}
function W.prestigeGoal(completed)
 -- Existing deeper runs never lose earned eligibility during this tuning pass.
 return W.PRESTIGE_GOALS[completed+1] or math.min(1e12,math.floor(360*(1+completed)^1.35))
end
function W.permanentMiningBonus(completed)
 return .5*math.min(completed,3)+.25*math.max(0,completed-3)
end
W.EMPTIERS=2
W.VACUUM_ENABLED=false
W.ORE_REACH_SCALE=.28
W.STARTER_SPECIALISTS={'Needler','Ballcaster','Vacuum','Compactor'}
W.EMPTIER_BATCH=4
W.COURIER_LOWER=.38
W.COURIER_CLOSE=.18
W.COURIER_CONTACT=W.COURIER_LOWER+W.COURIER_CLOSE
W.COURIER_LIFT=.38
W.COURIER_CLEARANCE=1.45
W.COURIER_APPROACH_RESPONSE=1.85
W.COURIER_RENDER_DELAY=.10
function W.courierClawOffset(slot)
 local side=slot%2==1 and -1 or 1
 return side*.98,-1.14,.86-math.floor((slot-1)/2)*1.72,side*.06
end
local function easeClaw(t)
 t=math.clamp(t,0,1)
 return t*t*t*(10+t*(-15+6*t))
end
function W.courierStroke(age)
 local lower=easeClaw(age/W.COURIER_LOWER)
 local close=easeClaw((age-W.COURIER_LOWER)/W.COURIER_CLOSE)
 local lift=easeClaw((age-W.COURIER_CONTACT)/W.COURIER_LIFT)
 return W.COURIER_CLEARANCE*(1-lower+lift),close,1-lower
end
W.ROCK_SIZE={2.16,1.28,1.94}
W.RAW_CRYSTAL_COLOR={204,32,47}
W.RAW_CRYSTAL_REFLECTANCE=.30
W.BLOCK_SIZE={1.45,.90,1.22}
W.EMPTIER_WAIT=6
W.COMPACTOR_BATCH=3
W.COMPACTOR_WAIT=5
W.COMPACTOR_PARTIAL_WAIT=1.5
W.COMPACTOR_REACH=12
W.PRESS_CONTACT=.43
W.PRESS_EJECT=.82
W.PRESS_RESET=1.20
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
