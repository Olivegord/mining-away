--!strict
-- Drone Blower revolution • Olivegord/mining-away • generated from editable source.
local Workshop = (function()
-- One shared upgrade pool. Repeated picks merge into the same stack.
-- These local tuning values travel with the saved offer, so reconnects never reroll.
local W={PACK_BASE=20,PACK_GROWTH=1.35,LEVEL_COST=20,LEVEL_GROWTH=1.7,PRESTIGE_BASE=360}
W.TIERS={'Common','Rare','Epic','Legendary'}
W.CATALOG={
 {id='Q_POWER',title='Power Cell',scope='Fleet',category='mining',tier=1,max=6,step={mining=.5},color={246,113,93},icon='mining'},
 {id='Q_IGNITION',title='Quick Ignition',scope='Fleet',category='startup',tier=1,max=6,step={startup=1},color={69,190,244},icon='startup'},
 {id='Q_CARGO',title='Deep Pockets',scope='Player',category='cargo',tier=1,max=4,step={capacity=.5},color={255,190,65},icon='cargo'},
 {id='Q_BATTERY',title='Battery Cell',scope='Fleet',category='flight',tier=1,max=4,step={battery=100},color={118,215,112},icon='startup'},
 {id='Q_YIELD',title='Quartz Polisher',scope='Fleet',category='cargo',tier=2,max=4,step={yield=.25},color={188,119,245},icon='crystal'},
 {id='Q_SCANNER',title='Route Runner',scope='Fleet',category='flight',tier=2,max=5,step={speed=.4},once={plotAuto=1},color={78,211,145},icon='flight'},
 {id='Q_SPLIT',title='Prism Relay',scope='Fleet',category='mining',tier=2,max=4,step={fork=.1},once={forkRange=6},color={57,210,222},icon='relay'},
 {id='Q_THRUST',title='Thrusters',scope='Fleet',category='flight',tier=1,max=5,step={speed=.4},color={83,168,239},icon='flight'},
 {id='Q_HOT_START',title='Hot Start',scope='Fleet',category='startup',tier=3,max=3,step={startup=2,mining=.25},color={248,144,75},icon='startup'},
 {id='Q_CARGO_LOOP',title='Cargo Loop',scope='Fleet',category='cargo',tier=3,max=3,step={capacity=.5,yield=.125},color={236,173,63},icon='cargo'},
 {id='Q_PRISM_DRIVE',title='Prism Drive',scope='Fleet',category='mining',tier=3,max=3,step={fork=.1,speed=.3},once={forkRange=6},color={75,179,230},icon='relay'},
 {id='Q_OVERDRIVE',title='Overdrive Core',scope='Fleet',category='mining',tier=4,max=3,step={mining=1,startup=2},color={250,109,81},icon='mining'},
 {id='Q_PRISM_CORE',title='Prismatic Core',scope='Fleet',category='mining',tier=4,max=2,step={fork=.2,yield=.25},once={forkRange=6},color={115,132,248},icon='relay'},
 {id='Q_AUTONOMOUS',title='Autonomous Fleet',scope='Fleet',category='flight',tier=4,max=2,step={speed=.75,capacity=.5},once={plotAuto=1},color={81,204,157},icon='fleet'},
}
W.BY_ID={};for _,entry in ipairs(W.CATALOG) do W.BY_ID[entry.id]=entry end
W.STAR_CATALOG={
 {id='selector',title='Wider Selector',description='+4 studs to the square width',cost=2,max=3},
 {id='walk',title='Walking Speed',description='+2 studs per second on foot',cost=2,max=3},
 {id='charge',title='Quick Charge',description='+30% battery recharge speed',cost=3,max=3},
 {id='backpack',title='Backpack Lining',description='+10 ore capacity',cost=3,max=3},
 {id='autosell',title='Auto Sell',description='Sell a full backpack from the field',cost=6,max=1},
}
W.STAR_BY_ID={};for _,entry in ipairs(W.STAR_CATALOG) do W.STAR_BY_ID[entry.id]=entry end
W.BATTERY=100
function W.starLevel(p,id) return (p.run.starUpgrades or {})[id] or 0 end
function W.starPrice(entry,level) return entry.cost+level end
function W.selectorWidth(p) return 14+4*W.starLevel(p,'selector') end
function W.owned(p)
 local result={}
 for _,c in ipairs(p.run.cards) do if c.workshop then table.insert(result,c) end end
 return result
end
function W.find(p,id)
 for _,c in ipairs(p.run.cards) do if c.workshop and c.cardId==id then return c end end
 return nil
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
-- Validate the complete mixed bag before touching any balance.
function S.deposit(run,bag)
 for key,n in pairs(bag) do
  if not S.COLORS[key] or not integer(n) or not integer(run.wallet[key]+n) then return false,'Invalid mineral deposit' end
 end
 for key,n in pairs(bag) do run.wallet[key]=run.wallet[key]+n end
 return true
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
local Feel = (function()
-- Original 2023 motion and crystal timing, with explicit elapsed-time correction.
-- Scalar helpers stay engine-independent so the original equations are testable.
local F = {FollowHeight=3.2,ReferenceFollowHeight=7,WorkHeight=10,WorkClearance=5,SwarmSpacing=3.5,SwarmRadius=6,SwarmMaxOffset=2.2}
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
function F.rockYaw(seed,stage,turn)
 local yaw=(seed*.01)%(2*math.pi)
 if turn then
  for i=1,stage do
   local roll=(seed*131+i*271)%83
   yaw+=math.rad(55+roll)*((seed+i)%2==0 and 1 or -1)
  end
 end
 return yaw
end
function F.groundedRockFrame(position,size,ground,stage,seed,turn)
 local center=Vector3.new(position.X,ground+size.Y*.5-.06,position.Z)
 return CFrame.new(center)*CFrame.Angles(0,F.rockYaw(seed,stage,turn),0),ground+size.Y-.06
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
function F.mineGoal(resourcePosition,slot,geode,fullSize)
 -- Large original geodes can be eight studs tall. Keep the smaller worker
 -- above the original volume, with a visible beam gap throughout mining.
 local height=fullSize and math.max(F.WorkHeight,fullSize.Y*.5+F.WorkClearance) or nil
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
local Mining = (function()
-- Pure mining rules shared by the authoritative server, UI and pacing model.
-- Drone types are permanent; these behaviors do not rewrite saved base traits.
local M={PULSE_INTERVAL=.8,RESONANCE_RANGE=10,HEALTH_MULTIPLIER=1,BOULDER_CHANCE=.2,BOULDER_WORK=3,BOULDER_SIZE=2.6,EXTRACTION_SHARE=.5}
M.SELECTOR_RANGE=44
local SELECTOR_GRID=2
function M.selectorCenter(position,frame,size)
 local point=frame:PointToObjectSpace(Vector3.new(position.X,frame.Position.Y,position.Z))
 local halfX,halfZ=size.X*.5,size.Z*.5
 if math.abs(point.X)>halfX or math.abs(point.Z)>halfZ then return nil end
 local maxX,maxZ=math.floor(halfX/SELECTOR_GRID),math.floor(halfZ/SELECTOR_GRID)
 local x=math.clamp(math.round(point.X/SELECTOR_GRID),-maxX,maxX)*SELECTOR_GRID
 local z=math.clamp(math.round(point.Z/SELECTOR_GRID),-maxZ,maxZ)*SELECTOR_GRID
 return frame:PointToWorldSpace(Vector3.new(x,size.Y*.5,z))
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
-- Cumulative base ore released by real layer fractures. The rest belongs to
-- the final collapse; crossing several layers at once never duplicates ore.
function M.extractedOre(ore: number,stage: number,count: number): number
 return math.floor(ore*M.EXTRACTION_SHARE*math.clamp(stage/math.max(1,count),0,1))
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
local Feedback = (function()
-- Pure cosmetic event detection and time envelopes. These never advance gameplay.
local F={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function dead(s)
 return s.dead==true or s.state=='Destroyed' or s.state=='Reprinting' or (finite(s.hp) and s.hp<=0)
end
function F.new(snapshot)
 return {dead=dead(snapshot),state=snapshot.state,life=snapshot.life,hp=snapshot.hp,serial=snapshot.serial or 0}
end
function F.observe(previous,snapshot)
 local isDead=dead(snapshot)
 local changedLife=snapshot.life~=nil and previous.life~=nil and snapshot.life~=previous.life
 local serial=finite(snapshot.serial) and snapshot.serial or 0
 local event={
  died=isDead and not previous.dead,
  revived=not isDead and previous.dead,
  assembly=snapshot.state=='Reprinting' and previous.state~='Reprinting',
  hit=not changedLife and not previous.dead and not isDead and finite(snapshot.hp) and finite(previous.hp) and snapshot.hp<previous.hp-.001,
  shot=not isDead and not changedLife and serial>previous.serial,
 }
 previous.dead=isDead;previous.state=snapshot.state;previous.life=snapshot.life
 previous.hp=snapshot.hp;previous.serial=serial
 return event
end
function F.progress(now,start,duration)
 if not finite(now) or not finite(start) or not finite(duration) or duration<=0 then return 1 end
 return math.clamp((now-start)/duration,0,1)
end
function F.smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function F.flash(age,duration)
 if not finite(age) or age<0 then return 0 end
 local t=math.clamp(age/(duration or .16),0,1)
 return (1-t)^2
end
function F.recoil(age)
 if not finite(age) or age<0 or age>=.28 then return 0 end
 -- A fast compression followed by a slower return, sampled from elapsed time.
 local t=age/.28
 return math.sin(math.pi*t)^2*(1-t)*1.8
end
function F.assembly(now,readyAt,duration)
 local p=math.clamp(1-(readyAt-now)/(duration or 2),0,1)
 return p,1-(1-p)^2
end
function F.fragment(age,groundDrop,vy,gravity)
 -- Deterministic ballistic fall, one floor sample at spawn; no per-frame raycasts.
 local floor=math.min(0,groundDrop)
 local impact=(vy+math.sqrt(vy*vy-2*gravity*floor))/gravity
 if age<impact then return vy*age-.5*gravity*age*age,false,age end
 return floor,true,impact
end
function F.rubble(age,groundDrop,vy,gravity)
 -- Piecewise ballistic arcs conserve downward speed at impact, then lose
 -- energy to restitution/friction. Sampling time directly is frame-rate safe.
 local floor=math.min(0,groundDrop);local y=0;local elapsed=0
 local travel=0;local horizontal=1;local lastImpact=0;local strength=0
 local function drift(t) return (1-math.exp(-.7*t))/.7 end
 for bounce=0,4 do
  local impact=(vy+math.sqrt(vy*vy+2*gravity*math.max(0,y-floor)))/gravity
  local t=math.max(0,age-elapsed)
  if t<impact then
   return y+vy*t-.5*gravity*t*t,travel+horizontal*drift(t),bounce,lastImpact,strength,false,0
  end
  travel+=horizontal*drift(impact);horizontal*=math.exp(-.7*impact)*.57
  elapsed+=impact;strength=math.max(0,gravity*impact-vy);lastImpact=elapsed
  y=floor;vy=strength*.32
  if vy<1.4 or bounce==4 then
   local rest=math.max(0,age-elapsed)
   return floor,travel+horizontal*(1-math.exp(-9*rest))/9,bounce+1,lastImpact,strength,true,rest
  end
 end
 return floor,travel,5,lastImpact,strength,true,0
end
-- Stable, size-normalised anchor on the *queried rendered part* surface.
-- A cached anchor transforms with crystal shrink and tilt between bounded raycasts.
function F.surfaceAnchor(point,size)
 if not point or not size then return nil end
 local function ratio(v,n)
  if not finite(v) or not finite(n) or n<=0 then return nil end
  return math.clamp(v/n,-.5,.5)
 end
 local x,y,z=ratio(point.X,size.X),ratio(point.Y,size.Y),ratio(point.Z,size.Z)
 if x==nil or y==nil or z==nil then return nil end
 return {x=x,y=y,z=z}
end
function F.surfaceComponents(anchor,size)
 if not anchor or not size or not finite(size.X) or not finite(size.Y) or not finite(size.Z)
  or size.X<=0 or size.Y<=0 or size.Z<=0 then return nil end
 return anchor.x*size.X,anchor.y*size.Y,anchor.z*size.Z
end
-- A percussion hit/resonance discharge must correspond to this life and target.
-- Late discovery reconstructs the short visual envelope but never replays audio.
function F.miningCue(previous,sample,now)
 local serial=finite(sample.pulseSerial) and sample.pulseSerial or 0
 local changed=previous.life~=sample.life or previous.key~=sample.key
 local fresh=previous.serial~=nil and not changed and serial>previous.serial
 previous.serial=serial;previous.life=sample.life;previous.key=sample.key
 local valid=sample.alive and sample.active and not sample.paused and serial>0
  and sample.pulseKey==sample.key and sample.key~=nil
  and finite(sample.pulseAt) and sample.pulseAt>0
 if not valid then return 0,false end
 local strength=F.flash(now-sample.pulseAt,.22)
 return strength,fresh and strength>0
end
-- One coherent envelope; never replay a stale contact across death/life/target changes.
function F.newBeam()
 return {key=nil,ever=false,active=false,width=0,life=nil,startAt=0,startWidth=0,hideAt=nil,hideWidth=0}
end
function F.beamStep(record: any,sample: any)
 local now: any=sample.now
 if type(now)~='number' or not finite(now) then return 0 end
 if not sample.alive or not sample.valid or not sample.key then
  record.key=nil;record.width=0;record.active=false;record.hideAt=nil;record.life=sample.life
  return 0
 end
 local changed=record.key~=sample.key or (record.life~=nil and sample.life~=record.life)
 if changed then
  record.key=sample.key;record.width=0;record.active=false;record.hideAt=nil
 end
 record.life=sample.life
 if sample.active then
  if not record.active then
   -- Charging already finished on the server. Release immediately, including
   -- late joins and new targets; do not append a second cosmetic warmup.
   local since=now
   if type(sample.since)=='number' and finite(sample.since) then since=math.min(sample.since,now) end
   record.startAt=record.ever and now or since
   record.startWidth=record.width;record.active=true;record.hideAt=nil;record.ever=true
  end
  record.width=1
 else
  if record.active or record.hideAt==nil then record.hideAt=now;record.hideWidth=record.width end
  record.active=false
  local t=math.clamp((now-record.hideAt)/.2,0,1)
  record.width=record.hideWidth*(1-t)^2
 end
 return record.width
end
return F

end)()
local AudioFeedback = (function()
-- Pure audio event gating. Replicated state authorizes cues, never the reverse.
local A={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function A.fresh(at,now,age)
 return finite(at) and at>0 and finite(now) and now-at>=-.1 and now-at<=(age or .6)
end
function A.serial(record,key,serial,at,now)
 local before=record[key];record[key]=serial
 return finite(before) and finite(serial) and serial>before and A.fresh(at,now,.35)
end
local work={
 Warmup='charge',BreakerWindup='breaker_charge',RepairCharge='repair_charge',
 Plant='grow_charge',
 Heal='healing',Pickup='transfer',Unload='transfer',
}
local transition={Mine='laser_start',BreakerDive='dive',Heal='heal',Launch='parcel_latch',
 Unload='unload',SwarmActive='swarm_launch'}
function A.drone(record,s,now)
 local previous=record.sample;record.sample=table.clone(s)
 local audible=not s.dead and not s.paused and A.fresh(s.at,now)
 local mode=audible and work[s.state] or nil
 if audible and s.state=='Attack' and finite(s.chargeAt) and s.chargeAt>now then mode='combat_charge' end
 local cues={}
 if audible and previous and previous.life==s.life and not previous.dead and not previous.paused
  and A.fresh(previous.at,now,.7) then
  if previous.state~=s.state and transition[s.state] then table.insert(cues,transition[s.state]) end
  if A.serial(record,'sale',s.sale,s.saleAt,now) then table.insert(cues,'courier_sale') end
 else record.sale=s.sale end
 return cues,mode
end
return A

end)()
local SentryMotion = (function()
-- Cosmetic mechanics in seconds/radians/studs. No gameplay decisions.
local M={WAKE_DURATION=2.8,IGNITE=2.15}
local pi=math.pi
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function wrap(a) return math.atan2(math.sin(a),math.cos(a)) end
-- Exact underdamped spring for a fixed target over dt; separate velocities retain inertia.
function M.spring(value,velocity,target,frequency,damping,dt)
 if dt<=0 then return value,velocity end
 local w=frequency;local d=damping*w;local wd=w*math.sqrt(1-damping*damping)
 local offset=value-target;local b=(velocity+d*offset)/wd
 local c,s=math.cos(wd*dt),math.sin(wd*dt);local decay=math.exp(-d*dt)
 local y=offset*c+b*s
 return target+decay*y,decay*((-offset*wd*s+b*wd*c)-d*y)
end
function M.new(_now,_phase)
 return {yaw=0,pitch=0,yawV=0,pitchV=0,charge=0,initialized=false}
end
function M.wake(age,rank)
 local t=age-rank*.045
 local opening=smooth((t-.12)/.8)
 local burst
 if t<.92 then burst=smooth((t-.12)/.8)
 else
  local settle=t-.92
  -- Start the return at zero velocity; the slab accelerates into its settle.
  burst=math.exp(-settle*3.8)*(math.cos(settle*5.2)+(3.8/5.2)*math.sin(settle*5.2))
 end
 local spin=2*pi*smooth(t/1.7)
 if t>1.7 then spin+=math.sin((t-1.7)*9)*math.exp(-(t-1.7)*7)*.16 end
 return opening,burst,spin
end
function M.impulse(age,delay,frequency,decay)
 local t=age-(delay or 0)
 if t<0 or t>1.6 then return 0 end
 return math.sin(t*frequency)*math.exp(-t*decay)
end
function M.step(state,dt,now,phase,input)
 dt=math.clamp(dt,0,.1)
 local awake=input.awake==true and not input.dead
 local targetYaw=awake and (input.aimYaw or state.yaw) or 0
 local targetPitch=awake and math.clamp(input.aimPitch or 0,-.35,.35) or 0
 if not state.initialized then state.yaw=targetYaw;state.pitch=targetPitch;state.initialized=true end
 targetYaw=state.yaw+wrap(targetYaw-state.yaw)
 state.yaw,state.yawV=M.spring(state.yaw,state.yawV,targetYaw,11,.68,dt)
 state.pitch,state.pitchV=M.spring(state.pitch,state.pitchV,targetPitch,9,.7,dt)
 local charge=awake and input.charging and smooth(input.charge or 0) or 0
 state.charge=charge>state.charge and charge or charge+(state.charge-charge)*math.exp(-dt*10)
 local age=awake and math.max(0,now-(input.wakeAt or now-M.WAKE_DURATION)) or -10
 return {awake=awake,wakeAge=age,yaw=state.yaw,pitch=state.pitch,charge=state.charge,
  shotAge=input.shotAge,hitAge=input.hitAge,phase=phase,now=now,
  ignition=awake and M.impulse(age-M.IGNITE,0,22,6) or 0}
end
function M.segment(rank,now,phase,pose,eye,compact)
 if not pose.awake then return {yaw=0,pitch=0,roll=0,lift=compact or 0,back=0,side=0,reveal=0} end
 local opening,burst,spin=M.wake(pose.wakeAge,eye and .5 or rank)
 local delayed=now-rank*.16
 local shot=M.impulse(pose.shotAge,rank*.035,17-rank,5-rank*.35)
 local hit=M.impulse(pose.hitAge,rank*.045,19-rank*1.5,5)
 local settled=smooth((pose.wakeAge-1.1)/1.1)
 local breathe=math.sin(delayed*1.5+phase)
 if eye then
  return {yaw=pose.yaw+spin,pitch=pose.pitch*settled+hit*.25,
   roll=hit*.22,lift=(compact or 0)*(1-opening)+opening*1.25+burst*6.5
    +breathe*.3*settled-shot*.9,back=pose.charge*.65+shot*2.25,side=hit*.65,
   reveal=smooth((pose.wakeAge-1.6)/.4)}
 end
 local weight=(rank+1)/4
 return {yaw=spin+pose.yaw*opening+math.sin(delayed*.9+phase)*.17*settled
   +burst*(rank%2==0 and 1 or -1)*.55+hit*.3,
  pitch=hit*.22*weight,roll=math.sin(delayed*1.2+phase)*.055*settled+hit*.28*weight,
  lift=(compact or 0)*(1-opening)+opening*(.55+rank*1.25)+burst*(rank+1)*4.4
   +breathe*(.24+rank*.09)*settled+pose.charge*(rank+1)*.3-shot*(.9+rank*.5)+hit*.65*weight,
  back=shot*.4*weight,side=math.sin(delayed*.7+phase)*.16*settled+hit*.75*weight,reveal=1}
end
-- Dropped slabs accelerate, strike once and stay embedded. No bounce or wobble.
function M.fall(age,drop,rank)
 local delay=rank*.065;local t=math.max(0,age-delay);local height=math.max(0,drop)
 local duration=math.sqrt(2*height/68)
 local landed=age>=delay+duration
 local fraction=height>.0001 and math.clamp(34*t*t/height,0,1) or 1
 return fraction,landed,t-duration
end
return M

end)()
local Soundscape = (function()
-- Client-only Toolbox audio. Gameplay and reward confirmation stay on the server.
-- Asset names, creators and Creator Store links: docs/review/AUDIO_LIGHTING.md.
local SoundService = game:GetService('SoundService')
local ContentProvider = game:GetService('ContentProvider')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local Players = game:GetService('Players')
local Http = game:GetService('HttpService')
local Soundscape = {}; Soundscape.__index = Soundscape

local TRACKS = {
 {name='Bossa Me (a)',id='1837768517'},
 {name='Heavenly Fields',id='1835928951'},
 {name='The City',id='1835929012'},
}
local CUES = {
 click={id='9126066421',volume=.16,duration=1,cooldown=.075,fallback='volume_slider.ogg'},
 sale={id='soft-sale',localSound='rbxasset://sounds/action_jump_land.mp3',volume=.075,duration=.65,pitch=1.05,cooldown=.8,fallback='action_jump_land.mp3'},
 pickup={id='soft-pickup',localSound='rbxasset://sounds/volume_slider.ogg',volume=.11,duration=.3,pitch=1.2,cooldown=.09,fallback='volume_slider.ogg'},
 rock_clack={ids={'9125869504','9125869495','9125869138'},volume=.23,duration=.48,pitch=1.05,cooldown=.065,range=65,maxVoices=4,fallback='action_jump_land.mp3'},
 pack_land={id='9125869495',volume=.21,duration=.55,pitch=.8,cooldown=.14,range=34,fallback='action_jump_land.mp3'},
 pack_step={id='9126066421',volume=.16,duration=.38,pitch=1.1,cooldown=.09,range=30,fallback='volume_slider.ogg'},
 pack_open={id='91735091370012',volume=.22,duration=1.65,pitch=1.08,cooldown=.18,range=42,fallback='volume_slider.ogg'},
 upgrade={id='91735091370012',pitch=.8,volume=.12,duration=4,cooldown=.45,fallback='volume_slider.ogg'},
 prestige={id='91735091370012',volume=.16,duration=4,pitch=.85,cooldown=2,fallback='volume_slider.ogg'},
 cutting={id='9118614717',volume=.045,duration=.6,pitch=.72,cooldown=.22,fallback='action_jump_land.mp3'},
 orbital={id='9118612324',volume=.16,duration=1.1,pitch=.65,cooldown=.25,fallback='action_jump_land.mp3'},
 mining={id='9125871199',volume=.22,duration=2,cooldown=.16,fallback='action_jump_land.mp3'},
 hit={id='9125871199',volume=.15,duration=2,cooldown=.12,fallback='action_jump_land.mp3'},
 death={id='9125871199',volume=.32,duration=2,pitch=.75,cooldown=.2,fallback='impact_explosion_03.mp3'},
 wake={id='9126066421',volume=.3,duration=1,pitch=.65,cooldown=.5,fallback='action_get_up.mp3'},
 ignite={id='9126066421',volume=.27,duration=1,pitch=1.2,cooldown=.25,fallback='action_get_up.mp3'},
 impact={id='9125871199',volume=.45,duration=2,pitch=.7,cooldown=.15,fallback='impact_explosion_03.mp3'},
 breaker_contact={id='9125869495',volume=.46,duration=.7,pitch=.68,cooldown=.12,range=85,maxVoices=4,fallback='action_jump_land.mp3'},
 breaker_fracture={id='9125869138',volume=.35,duration=1.1,pitch=1.05,cooldown=.12,range=85,maxVoices=4,fallback='action_jump_land.mp3'},
 rubble={ids={'9125869504','9125869495','9125869138'},volume=.32,duration=1.2,pitch=1.12,cooldown=.055,range=75,maxVoices=4,fallback='action_jump_land.mp3'},
 tool_pipe={ids={'9113500863','9113500510','9113500760'},volume=.42,duration=1.2,pitch=.94,cooldown=.1,range=68,fallback='action_jump_land.mp3'},
 tool_slice={id='9125869138',volume=.36,duration=.72,pitch=1.4,cooldown=.1,range=68,fallback='action_jump_land.mp3'},
 tool_sizzle={id='9118614717',volume=.24,duration=1.45,pitch=.94,cooldown=.1,range=58,fallback='action_jump_land.mp3'},
 tool_stick={id='9126066421',volume=.19,duration=.4,pitch=1.36,cooldown=.1,range=50,fallback='volume_slider.ogg'},
 tool_throw={id='9118941667',volume=.2,duration=.5,pitch=.85,cooldown=.1,range=64,fallback='action_jump_land.mp3'},
 tool_windup={id='9114583503',volume=.15,duration=.52,pitch=1.3,cooldown=.12,range=54,fallback='action_jump_land.mp3'},
 metal_land={id='9125871199',volume=.22,duration=1,pitch=.78,cooldown=.08,fallback='action_jump_land.mp3'},
 charge={id='139131445232833',volume=.12,duration=3.05,pitch=.74,cooldown=.1,range=65,priority=3,softLaser=true},
 breaker_charge={id='9114583503',volume=.28,duration=5,pitch=.7,cooldown=.1,range=80,priority=4},
 repair_charge={id='9119816710',volume=.2,duration=3,pitch=1.4,cooldown=.1,range=65,priority=3},
 grow_charge={id='9118941971',volume=.22,duration=1,pitch=.8,cooldown=.1,range=65,priority=2},
 orbital_charge={id='9119816710',volume=.3,duration=3,pitch=.65,cooldown=.1,range=95,priority=4},
 swarm_charge={id='9114583503',volume=.24,duration=5,pitch=1.3,cooldown=.1,range=75,priority=3},
 combat_charge={id='9119816710',volume=.25,duration=3,pitch=.9,cooldown=.1,range=80,priority=4},
 flight={id='9118941667',volume=.18,duration=1,pitch=.85,cooldown=.1,range=60,priority=1},
 cutting_hum={id='9118614717',volume=.13,duration=3,pitch=.70,cooldown=.1,range=80,priority=2,softLaser=true},
 orbital_hum={id='9118612324',volume=.27,duration=3,pitch=.6,cooldown=.1,range=95,priority=4},
 healing={id='9118941971',volume=.14,duration=1,pitch=1.45,cooldown=.1,range=65,priority=2},
 transfer={id='9118941667',volume=.17,duration=1,pitch=1.25,cooldown=.1,range=60,priority=2},
 laser_start={id='139620337204036',volume=.115,duration=.85,pitch=.76,cooldown=.25,range=65,maxVoices=2,softLaser=true,attack=.07},
 laser_stop={id='9118941971',volume=.06,duration=.45,pitch=.65,cooldown=.12,fallback='volume_slider.ogg',softLaser=true,attack=.06},
 dive={id='9118941667',volume=.21,duration=.55,pitch=.65,cooldown=.1,fallback='action_get_up.mp3'},
 heal={id='91735091370012',volume=.12,duration=.8,pitch=1.4,cooldown=.15,fallback='volume_slider.ogg'},
 plant={id='91735091370012',volume=.15,duration=.9,pitch=.85,cooldown=.18,fallback='volume_slider.ogg'},
 parcel_latch={id='9126066421',volume=.18,duration=.5,pitch=.8,cooldown=.1,fallback='action_get_up.mp3'},
 unload={id='9118941971',volume=.15,duration=.55,pitch=.9,cooldown=.15,fallback='action_jump_land.mp3'},
 courier_sale={id='91735091370012',volume=.1,duration=.8,pitch=1.15,cooldown=.2,fallback='volume_slider.ogg'},
 swarm_launch={id='9118941667',volume=.16,duration=.65,pitch=1.3,cooldown=.2,fallback='action_get_up.mp3'},
 shot={id='9126066421',volume=.19,duration=.45,pitch=1.5,cooldown=.065,fallback='action_get_up.mp3'},
 shield={id='9126066421',volume=.13,duration=.55,pitch=.6,cooldown=.12,fallback='action_jump_land.mp3'},
 reprint={id='91735091370012',volume=.15,duration=.9,pitch=.95,cooldown=.2,fallback='volume_slider.ogg'},
 resonance={id='91735091370012',volume=.12,duration=.8,pitch=.65,cooldown=.14,fallback='volume_slider.ogg'},
 command={id='9126066421',volume=.12,duration=.5,pitch=1.12,cooldown=.12,fallback='volume_slider.ogg'},
 denied={id='9118941971',volume=.1,duration=.4,pitch=.65,cooldown=.25,fallback='volume_slider.ogg'},
 full={id='9126066421',volume=.12,duration=.6,pitch=.7,cooldown=2,fallback='volume_slider.ogg'},
}
local function fade(object,duration,volume)
 local tween=TweenService:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Sine),{Volume=volume})
 tween:Play();return tween
end
local function group(parent,name,volume)
 local value=Instance.new('SoundGroup');value.Name=name;value.Volume=volume;value.Parent=parent;return value
end
function Soundscape.new(effectParent)
 local folder=Instance.new('SoundGroup');folder.Name='DroneBlowerSoundscape';folder.Volume=1;folder.Parent=SoundService
 local self=setmetatable({folder=folder,effectParent=effectParent,tracks={},bank={},cooldowns={},
  voices=0,closed=false,musicMuted=true,effectsMuted=false,combat=false,menu=false,
  loops={},loopCount=0,active={},cueVoices={},droneStates={},
  nextIndex=1,current=nil,lastMusicVolume=-1,random=Random.new()},Soundscape)
 self.musicGroup=group(folder,'Music',0)
 self.effectsGroup=group(folder,'Actions',1)
 local eq=Instance.new('EqualizerSoundEffect');eq.Name='GentleActionMix';eq.LowGain=0;eq.MidGain=0;eq.HighGain=-3;eq.Parent=self.effectsGroup
 local compressor=Instance.new('CompressorSoundEffect');compressor.Name='ActionPeakControl'
 compressor.Threshold=-8;compressor.Ratio=3;compressor.Attack=.1;compressor.Release=.18;compressor.GainMakeup=0;compressor.Parent=self.effectsGroup
 self.listenerType,self.listenerObject=SoundService:GetListener()
 -- A replacement controller inherits the baseline camera listener rather than
 -- restoring a previous controller's ownership after that controller closes.
 if SoundService:GetAttribute('DroneBlowerListenerOwner') then self.listenerType=Enum.ListenerType.Camera;self.listenerObject=nil end
 self.listenerToken=Http:GenerateGUID(false)
 self:_listenerStep()
 local preload={}
 for _,track in ipairs(TRACKS) do
  local sound=Instance.new('Sound');sound.Name=track.name;sound.SoundId='rbxassetid://'..track.id
  sound.Volume=0;sound.Looped=false;sound.PlayOnRemove=false;sound.SoundGroup=self.musicGroup;sound.Parent=folder
  table.insert(self.tracks,sound);table.insert(preload,sound)
 end
 -- Reuse one loaded template per asset, even when several cues share a clip.
 for _,cue in pairs(CUES) do for _,id in ipairs(cue.ids or {cue.id}) do if not self.bank[id] then
  local sound=Instance.new('Sound');sound.Name='Toolbox_'..id;sound.SoundId=cue.localSound or 'rbxassetid://'..id
  sound.Volume=0;sound.SoundGroup=self.effectsGroup;sound.Parent=folder
  self.bank[id]=sound;table.insert(preload,sound)
 end end end
 for _,sound in ipairs(preload) do task.spawn(function()
  local ok,err=pcall(function()
   ContentProvider:PreloadAsync({sound},function(_,status)
    if not self.closed and status==Enum.AssetFetchStatus.Failure then
     warn('[Drone Blower audio] Could not load '..sound.Name..' ('..sound.SoundId..'); skipping or using a local fallback.')
    end
   end)
  end)
  if not ok and not self.closed then warn('[Drone Blower audio] '..tostring(err)) end
 end) end
 -- No audio download blocks the HUD, player input or drone rendering.
 task.spawn(function()
  while not self.closed do self:_musicStep();self:update();task.wait(.1) end
 end)
 return self
end
function Soundscape:_musicStep()
 if self.closed or self.musicMuted then return end
 local current=self.current
 local playing=current and current.IsPlaying
 local remaining=playing and current.TimeLength>0 and (current.TimeLength-current.TimePosition) or math.huge
 if playing and remaining>2 then return end
 local nextSound,index
 for offset=0,#self.tracks-1 do
  local i=(self.nextIndex+offset-1)%#self.tracks+1;local candidate=self.tracks[i]
  if candidate.IsLoaded and (candidate~=current or not playing) then nextSound=candidate;index=i;break end
 end
 if not nextSound then return end -- All unavailable: stay quiet and allow later loads to recover.
 self.nextIndex=index%#self.tracks+1;self.current=nextSound
 if current and current~=nextSound then
  fade(current,math.min(2,remaining),0)
  task.delay(2,function() if not self.closed and current~=self.current then current:Stop() end end)
 end
 nextSound.Volume=0;nextSound.TimePosition=0;nextSound:Play();fade(nextSound,2,1)
end
function Soundscape:setContext(combat,menu)
 self.combat=combat==true;self.menu=menu==true
 local volume=self.musicMuted and 0 or (self.combat and .055 or (self.menu and .085 or .14))
 if volume~=self.lastMusicVolume then
  self.lastMusicVolume=volume
  if self.musicTween then self.musicTween:Cancel() end
  self.musicTween=fade(self.musicGroup,.45,volume)
 end
end
function Soundscape:toggleMusic()
 self.musicMuted=not self.musicMuted;self:setContext(self.combat,self.menu)
 if self.musicMuted then for _,track in ipairs(self.tracks) do track:Stop() end end
 return not self.musicMuted
end
function Soundscape:toggleEffects()
 self.effectsMuted=not self.effectsMuted;self.effectsGroup.Volume=self.effectsMuted and 0 or 1
 if self.effectsMuted then
  for key in pairs(self.loops) do self:stopLoop(key,true) end
  local active=table.clone(self.active);for sound,anchor in pairs(active) do (anchor or sound):Destroy() end
 end
 return not self.effectsMuted
end
function Soundscape:_distance(position)
 local player=Players.LocalPlayer
 local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local origin=root and root.Position or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
 return position and origin and (position-origin).Magnitude or 0
end
function Soundscape:_listenerStep()
 local player=Players.LocalPlayer
 local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local kind,object=SoundService:GetListener()
 if root==self.listenerRoot and (not root or (kind==Enum.ListenerType.ObjectPosition and object==root)) then return end
 if root then
  -- Position follows the character; stereo orientation still follows the camera.
  SoundService:SetListener(Enum.ListenerType.ObjectPosition,root)
  SoundService:SetAttribute('DroneBlowerListenerOwner',self.listenerToken)
 elseif SoundService:GetAttribute('DroneBlowerListenerOwner')==self.listenerToken then
  SoundService:SetListener(Enum.ListenerType.Camera)
 end
 self.listenerRoot=root
end
function Soundscape:_voice(name,position,looped)
 local cue=CUES[name];local id=cue.ids and cue.ids[self.random:NextInteger(1,#cue.ids)] or cue.id
 local template=self.bank[id];local ready=template and template.IsLoaded
 -- A missing sustained clip stays silent; never loop a generic fallback beep.
 if looped and not ready then return nil end
 local sound=ready and template:Clone() or Instance.new('Sound')
 sound.Name=name;sound.SoundGroup=self.effectsGroup
 if cue.softLaser then
  -- Remove the piercing upper bands on laser voices only. Shared templates
  -- stay untouched, so crystal cracks and other jobs retain their character.
  local eq=Instance.new('EqualizerSoundEffect');eq.Name='SoftLaserTone'
  eq.LowGain=0;eq.MidGain=-9;eq.HighGain=-20;eq.Parent=sound
 end
 if not ready then sound.SoundId='rbxasset://sounds/'..(cue.fallback or 'action_get_up.mp3') end
 sound.Volume=0
 sound.PlaybackSpeed=(cue.pitch or 1)*(position and self.random:NextNumber(.96,1.04) or 1)
 sound.Looped=looped;sound.PlayOnRemove=false
 local anchor
 if position then
  anchor=Instance.new('Part');anchor.Name='ActionAudio';anchor.Size=Vector3.one*.05
  anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false
  anchor.Position=position;anchor.Parent=self.effectParent
  sound.RollOffMode=Enum.RollOffMode.Linear;sound.RollOffMinDistance=14;sound.RollOffMaxDistance=cue.range or 80
 end
 sound.Parent=anchor or self.folder;self.voices+=1
 self.cueVoices[name]=(self.cueVoices[name] or 0)+1
 self.active[sound]=anchor or false
 sound.Destroying:Once(function()
  self.active[sound]=nil;self.voices=math.max(0,self.voices-1)
  self.cueVoices[name]=math.max(0,(self.cueVoices[name] or 0)-1)
 end)
 return sound,anchor
end
function Soundscape:play(name,position,options)
 local cue=CUES[name];local now=os.clock()
 if self.closed or self.effectsMuted or not cue or self.voices>=22 or now<(self.cooldowns[name] or 0) then return end
 if (self.cueVoices[name] or 0)>=(cue.maxVoices or 5) then return end
 if position and self:_distance(position)>(cue.range or 80) then return end
 self.cooldowns[name]=now+cue.cooldown
 local sound,anchor=self:_voice(name,position,false);if not sound then return end
 local volume=cue.volume/math.sqrt(1+self.voices*.07)*(options and options.level or 1)
 if options and options.pitch then sound.PlaybackSpeed*=options.pitch end
 sound.Ended:Once(function() if anchor then anchor:Destroy() else sound:Destroy() end end)
 sound:Play();fade(sound,cue.attack or .025,volume)
 task.delay(math.max(.05,cue.duration-.22),function() if sound.Parent then fade(sound,.18,0) end end)
 Debris:AddItem(anchor or sound,cue.duration+.05)
end
function Soundscape:stopLoop(key,immediate)
 local loop=self.loops[key];if not loop then return end
 self.loops[key]=nil;self.loopCount=math.max(0,self.loopCount-1)
 if immediate or not loop.sound.Parent then (loop.anchor or loop.sound):Destroy()
 else fade(loop.sound,.12,0);Debris:AddItem(loop.anchor or loop.sound,.14) end
end
function Soundscape:setLoop(key,name,position,level,pitch)
 local cue=CUES[name];local loop=self.loops[key];local now=os.clock()
 if self.closed or self.effectsMuted or not cue or typeof(position)~='Vector3' or self:_distance(position)>(cue.range or 80) or (level or 1)<=0 then self:stopLoop(key);return end
 if loop and (loop.name~=name or not loop.sound.Parent) then self:stopLoop(key);loop=nil end
 if not loop then
  -- Six spatial beds, with priority and proximity eviction, leave room for
  -- impacts/rewards. A swarm never creates an unbounded choir of motors.
  if self.loopCount>=6 then
   local worstKey,worstScore
   for candidate,item in pairs(self.loops) do
    local score=(CUES[item.name].priority or 1)*100-self:_distance(item.anchor.Position)
    if not worstScore or score<worstScore then worstKey=candidate;worstScore=score end
   end
   local score=(cue.priority or 1)*100-self:_distance(position)
   if not worstScore or score<=worstScore+5 then return end
   self:stopLoop(worstKey)
  end
  if self.voices>=22 then return end
  local sound,anchor=self:_voice(name,position,true);if not sound then return end
  loop={sound=sound,anchor=anchor,name=name,seen=now,step=now};self.loops[key]=loop;self.loopCount+=1
  sound:Play()
 end
 local dt=math.clamp(now-loop.step,1/240,.1);loop.step=now;loop.seen=now
 if loop.anchor then loop.anchor.Position=position end
 local volume=cue.volume*(level or 1)/math.sqrt(1+self.loopCount*.12)
 loop.sound.Volume+=(volume-loop.sound.Volume)*(1-math.exp(-dt*(cue.softLaser and 8 or 14)))
 loop.sound.PlaybackSpeed=(cue.pitch or 1)*(pitch or 1)
end
function Soundscape:update()
 if self.closed then return end
 self:_listenerStep()
 local now=os.clock()
 for key,loop in pairs(self.loops) do
  -- Stop even if an interrupted renderer never gets another cleanup callback.
  if now-loop.seen>.3 or not loop.sound.Parent then self:stopLoop(key) end
 end
end
function Soundscape:updateDrone(source,position,now)
 local record=self.droneStates[source]
 if not record then record={workKey={},flightKey={}};self.droneStates[source]=record end
 local function a(name) return source:GetAttribute(name) end
 local state=a('State');local hp=a('HP') or 0
 local sample={state=state,life=a('Life'),dead=hp<=0 or state=='Destroyed' or state=='Reprinting',
  paused=a('WorkPaused')==true or a('MotionPaused')==true,at=a('SnapshotAt'),chargeAt=a('ChargeAt'),sale=a('CourierSaleSerial') or 0,saleAt=a('CourierSaleAt')}
 local cues,mode=AudioFeedback.drone(record,sample,now)
 -- The production beam renderer owns this rising tone for both real drones
 -- and preview displays. Avoid a second charge loop from the state observer.
 if mode=='charge' and self.chargeFromRenderer then mode=nil end
 for _,name in ipairs(cues) do
  if name~='laser_start' or not self.chargeFromRenderer then self:play(name,position) end
 end
 if mode then
  local start,duration
  if state=='Warmup' then start=a('WarmupStart');duration=a('WarmupDuration')
  elseif state=='RepairCharge' then start=a('RepairChargeAt');duration=a('RepairChargeDuration')
  elseif state=='BreakerWindup' then start=a('BreakerPhaseAt');duration=.8 end
  local q=start and duration and math.clamp((now-start)/math.max(.01,duration),0,1) or .6
  self:setLoop(record.workKey,mode,position,.65+.35*q,.8+.4*q)
 else self:stopLoop(record.workKey) end
 local velocity=a('Velocity');local speed=typeof(velocity)=='Vector3' and velocity.Magnitude or 0
 if not sample.dead and not sample.paused and AudioFeedback.fresh(sample.at,now) and speed>2 then
  self:setLoop(record.flightKey,'flight',position,math.clamp(speed/18,.2,1),.85+math.min(speed,30)/65)
 else self:stopLoop(record.flightKey) end
end
function Soundscape:forgetDrone(source)
 local record=self.droneStates[source];if not record then return end
 self:stopLoop(record.workKey);self:stopLoop(record.flightKey);self.droneStates[source]=nil
end
function Soundscape:bindUI(root)
 if self.uiConnection then self.uiConnection:Disconnect() end
 local function bind(object)
  if not object:IsA('GuiButton') then return end
  -- Instance-owned connections disappear with rebuilt menus. Do not retain
  -- every historical button in the soundscape's lifetime connection list.
  object.Activated:Connect(function()
   if object.Active and object:GetAttribute('Enabled')~=false then self:play('click') end
  end)
 end
 for _,object in ipairs(root:GetDescendants()) do bind(object) end
 self.uiConnection=root.DescendantAdded:Connect(bind)
end
function Soundscape:observeProfile(previous,current)
 -- Joining/reconnecting is silent. Only replicated, confirmed changes make a reward cue.
 if current.pendingTransaction then return end
 previous=self.confirmedProfile or (previous and not previous.pendingTransaction and previous or nil)
 self.confirmedProfile=current
 if not previous then return end
 local before,after=previous.run,current.run
 local shopChanged=false
 for id,level in pairs(after.shopLevels or {}) do if level>((before.shopLevels or {})[id] or 0) then shopChanged=true;break end end
 if before.id~=after.id then
  if #current.fleet>#previous.fleet then self:play('prestige') end
 elseif #after.cards>#before.cards then self:play('upgrade')
 elseif shopChanged then self:play('upgrade')
 elseif (after.saleEarnings or 0)>(before.saleEarnings or 0) then self:play('sale') end
 if before.id==after.id then
  local function cargo(run) local total=0;for _,units in pairs(run.cargo or {}) do total+=units end;return total end
  local capacity=current.capacity or 40
  if cargo(before)<(previous.capacity or 40) and cargo(after)>=capacity then self:play('full') end
 end
end
function Soundscape:destroy()
 self.closed=true
 if self.musicTween then self.musicTween:Cancel() end
 if self.uiConnection then self.uiConnection:Disconnect() end
 for key in pairs(self.loops) do self:stopLoop(key,true) end
 local active=table.clone(self.active);for sound,anchor in pairs(active) do (anchor or sound):Destroy() end
 self.droneStates={}
 if SoundService:GetAttribute('DroneBlowerListenerOwner')==self.listenerToken then
  local kind,object=SoundService:GetListener()
  if (kind==Enum.ListenerType.ObjectPosition and object==self.listenerRoot) or not self.listenerRoot then
   local previous=self.listenerObject
   if typeof(previous)=='Instance' and not previous.Parent then SoundService:SetListener(Enum.ListenerType.Camera)
   else SoundService:SetListener(self.listenerType,previous) end
  end
  SoundService:SetAttribute('DroneBlowerListenerOwner',nil)
 end
 self.folder:Destroy()
end
return Soundscape

end)()
local PullMotion = (function()
-- Cosmetic point masses attracted to an emitter. Cache the force simulation
-- once; sample authoritative charge time without frame-dependent integration.
local Pull={}
local RATE=240
local paths={}
local ZERO=Vector3.zero
local function simulate(index)
 local angle=index*2.399963
 local radius=2.4+(index%3)*.55
 local position=Vector3.new(math.cos(angle)*radius,-.35-(index%4)*.35,math.sin(angle)*radius)
 local velocity=Vector3.new(-math.cos(angle)*.8-math.sin(angle)*5.5,.25,-math.sin(angle)*.8+math.cos(angle)*5.5)
 local mass=.85+(index%3)*.12
 local samples={{position=position,velocity=velocity}}
 local captured
 for step=1,RATE do
  local t=step/RATE
  if not captured then
   -- Softened attraction: increasing field strength bends initial momentum
   -- inward from the first sample. Drag removes angular momentum so
   -- each stream is captured instead of orbiting indefinitely.
   local distance2=position:Dot(position)
   local attraction=(160+620*t*t*t)/(mass*(distance2+.3)^1.5)
   local acceleration=-position*attraction-velocity*3.2
   velocity+=acceleration/RATE
   position+=velocity/RATE
   if position:Dot(position)<.2*.2 then captured=t;position=ZERO;velocity=ZERO end
  end
  samples[#samples+1]={position=position,velocity=velocity}
 end
 return {samples=samples,captured=captured or 1}
end
for i=1,8 do paths[i]=simulate(i) end
function Pull.sample(index,progress)
 local path=paths[(index-1)%#paths+1]
 local frame=math.clamp(progress*.82,0,1)*RATE
 local left=math.min(RATE,math.floor(frame))+1
 local a=path.samples[left]
 local b=path.samples[math.min(left+1,RATE+1)]
 local fraction=frame-math.floor(frame)
 return a.position:Lerp(b.position,fraction),a.velocity:Lerp(b.velocity,fraction),path.captured/.82
end
-- Reuse the same cached point-mass approach for the release. Small lateral
-- velocity kicks make an electrical spray without constraints or per-frame RNG.
local discharge={}
local OUT_RATE=120
for i=1,18 do
 local angle=i*2.399963;local speed=11+(i%5)*1.1
 local p=Vector3.zero
 local radial=24+(i%3)*4
 local v=Vector3.new(math.cos(angle)*radial,-speed,math.sin(angle)*radial)
 local points={p}
 for step=1,180 do
  local t=step/OUT_RATE
  if step%5==0 and t<1.4 then
   local kick=angle+step*1.73
   v+=Vector3.new(math.cos(kick),0,math.sin(kick))*(.45+5.5*math.exp(-t*7))
  end
  -- Strong initial braking hands off to a small persistent outward current.
  -- There is no gravitational acceleration or ballistic fall in the tail.
  local drift=Vector3.new(math.cos(angle)*.55,-.32,math.sin(angle)*.55)
  v+=(drift-v)*(t<.12 and 15 or 6)/OUT_RATE
  p+=v/OUT_RATE;points[#points+1]=p
 end
 discharge[i]=points
end
function Pull.discharge(index,age)
 local frame=math.clamp(age,0,1.5)*OUT_RATE
 local left=math.min(180,math.floor(frame))+1
 local points=discharge[(index-1)%#discharge+1]
 return points[left]:Lerp(points[math.min(left+1,181)],frame-math.floor(frame))
end
return Pull

end)()
local PlaneBurst = (function()
-- Four cubic quadrants make one expanding circular sheet in the shot plane.
-- The circle expands and fades; its attachments never orbit or face the camera.
local Plane={}
local opacity={}
for i=0,32 do
 local a=i/32
 opacity[i]=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,1-a),NumberSequenceKeypoint.new(.6,1-a*.8),NumberSequenceKeypoint.new(1,1)})
end
function Plane.create(parent,color)
 local f={rays={}}
 for i=1,4 do
  local a=Instance.new('Attachment');a.Name='PlanarReleaseFrom';a.Parent=parent
  local b=Instance.new('Attachment');b.Name='PlanarReleaseTo';b.Parent=parent
  local beam=Instance.new('Beam');beam.Name='PlanarRelease';beam.Attachment0=a;beam.Attachment1=b
  beam.FaceCamera=false;beam.Segments=12;beam.LightEmission=1;beam.LightInfluence=0
  beam.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.45));beam.Enabled=false;beam.Parent=parent
  f.rays[i]={a=a,b=b,beam=beam}
 end
 return f
end
function Plane.hide(f) for _,r in ipairs(f.rays) do r.beam.Enabled=false end end
function Plane.destroy(f)
 for _,r in ipairs(f.rays) do r.a:Destroy();r.b:Destroy();r.beam:Destroy() end
end
-- Shared circular geometry for shock fronts, contracting telegraphs and wells.
-- Radius is sampled by the owning timeline; the four tangents never rotate.
function Plane.pose(f,normal,reach,strength,width)
 if strength<=.008 or reach<=.001 then Plane.hide(f);return end
 local ref=math.abs(normal.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local right=normal:Cross(ref).Unit;local up=right:Cross(normal).Unit
 for i,r in ipairs(f.rays) do
  local angle=(i-1)*math.pi/2
  local radial0=right*math.cos(angle)+up*math.sin(angle)
  local radial1=right*math.cos(angle+math.pi/2)+up*math.sin(angle+math.pi/2)
  local tangent0=-right*math.sin(angle)+up*math.cos(angle)
  local tangent1=-right*math.sin(angle+math.pi/2)+up*math.cos(angle+math.pi/2)
  r.a.CFrame=CFrame.fromMatrix(radial0*reach,tangent0,radial0,tangent0:Cross(radial0))
  r.b.CFrame=CFrame.fromMatrix(radial1*reach,tangent1,radial1,tangent1:Cross(radial1))
  r.beam.CurveSize0=reach*.55228475;r.beam.CurveSize1=reach*.55228475
  r.beam.Width0=width;r.beam.Width1=width
  r.beam.Transparency=opacity[math.floor(math.clamp(strength,0,1)*32+.5)]
  r.beam.Enabled=strength>.008
 end
end
function Plane.draw(f,normal,t,scale)
 if not t or t<0 or t>=1 then Plane.hide(f);return end
 local reach=(.12+1.75*(1-math.exp(-t*40))+.65*t)*scale
 Plane.pose(f,normal,reach,(1-t)^.8,(.08+.22*(1-t))*scale)
end
return Plane

end)()
local LaunchAftermath = (function()
-- Four reusable local aftermath rigs. The charge hands off its existing smoke
-- to this independent clock; returning the lens lease cannot erase the launch.
local A={}
local active,pool={},{}
local connection
local BLUE=Color3.fromRGB(114,201,255)
-- Chromatic refraction visibly separates RGB channels; carry those saturated
-- output hues into the dust rather than tinting all fragments beam-blue.
local popColors={Color3.new(0,0,1),Color3.new(0,1,1),Color3.new(1,0,1),
 Color3.new(0,1,0),Color3.new(1,1,0),Color3.new(1,0,0)}
function A.palette(color,index)
 return popColors[(index-1)%#popColors+1]
end
local function part(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Transparency=1;p.Size=Vector3.one*.025;p.Parent=parent;return p
end
local function create()
 local root=part(nil,'LaserLaunchAftermath')
 local f={root=root,smoke={},chips={},plane=PlaneBurst.create(root,BLUE)}
 for i=1,6 do
  local a=Instance.new('Attachment');a.Name='SmokeSector';a.Parent=root
  local e=Instance.new('ParticleEmitter');e.Name='PersistentBeamSmoke';e.Texture='rbxasset://textures/particles/smoke_main.dds'
  e.Enabled=false;e.Rate=0;e.LockedToPart=false;e.VelocityInheritance=0;e.WindAffectsDrag=false
  e.Lifetime=NumberRange.new(1.25,1.8);e.Speed=NumberRange.new(.15,.4);e.Drag=3
  e.SpreadAngle=Vector2.new(40,40);e.Color=ColorSequence.new(BLUE)
  e.LightEmission=.25;e.LightInfluence=0;e.Brightness=1.1
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(.32,1.25),NumberSequenceKeypoint.new(1,2.2)})
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.9),NumberSequenceKeypoint.new(.12,.68),NumberSequenceKeypoint.new(.55,.8),NumberSequenceKeypoint.new(1,1)})
  e.Rotation=NumberRange.new(-180,180);e.RotSpeed=NumberRange.new(-18,18);e.Parent=a
  f.smoke[i]={a=a,e=e}
 end
 for i=1,18 do
  local p=part(root,'ElectricColorFragment');p.Material=Enum.Material.Neon;p.Color=A.palette(BLUE,i)
  p.Size=Vector3.new(.035+(i%3)*.009,.035,.075+(i%4)*.025);f.chips[i]=p
 end
 return f
end
local function retire(f)
 if f.owner then f.owner.aftermath=nil end
 f.owner=nil;f.phase=nil;f.lastEmission=nil;f.emissionSector=0
 for _,s in ipairs(f.smoke) do s.e:Clear();s.e.Acceleration=Vector3.zero end
 for _,p in ipairs(f.chips) do p.Transparency=1 end
 PlaneBurst.hide(f.plane);f.root.Parent=nil
 if #pool<4 then pool[#pool+1]=f else f.root:Destroy() end
end
local function remove(f)
 for i=#active,1,-1 do if active[i]==f then table.remove(active,i);retire(f);return end end
end
function A.cancel(owner)
 if owner.aftermath then remove(owner.aftermath) end
end
function A.clear()
 for i=#active,1,-1 do retire(table.remove(active,i)) end
 for _,f in ipairs(pool) do f.root:Destroy() end
 table.clear(pool)
 if connection then connection:Disconnect();connection=nil end
end
function A.step(now)
 local camera=workspace.CurrentCamera
 local player=game:GetService('Players').LocalPlayer
 local reduced=player and (player:GetAttribute('ReducedEffects') or player:GetAttribute('MA_ReducedEffects') or player:GetAttribute('ReducedMotion') or player:GetAttribute('MA_ReducedMotion'))
 for i=#active,1,-1 do
  local f=active[i];local age=f.firedAt and now-f.firedAt or 0
  local far=camera and (camera.CFrame.Position-f.root.Position).Magnitude>120
  if not f.root.Parent or reduced or far or (f.phase=='release' and age>=1.8) or (f.phase=='charge' and now-f.updatedAt>.25) then
   table.remove(active,i);retire(f)
  elseif f.phase=='release' then
   -- Brief pressure impulse acts on particles already emitted during charge.
   local pressure=180*math.exp(-math.max(0,age)*35)
   for _,s in ipairs(f.smoke) do s.e.Acceleration=s.radial*pressure; s.e.Drag=7 end
   PlaneBurst.draw(f.plane,f.direction,age/1.1,f.scale)
   for n,p in ipairs(f.chips) do
    local t=age-(n%3)*.004
    local life=1.25+(n%4)*.07
    if t>=0 and t<life then
     local offset=PullMotion.discharge(n,t)*f.scale
     local position=f.root.Position+f.right*offset.X+f.direction*(-offset.Y)+f.up*offset.Z
     local nextOffset=PullMotion.discharge(n,math.min(1.5,t+.008))*f.scale
     local velocity=nextOffset-offset
     local direction=f.right*velocity.X-f.direction*velocity.Y+f.up*velocity.Z
     if direction.Magnitude>.0001 then
      p.CFrame=CFrame.lookAt(position,position+direction, f.direction)*CFrame.Angles(0,0,n*2.399963)
     else p.CFrame=CFrame.new(position) end
     p.Transparency=math.clamp((t-.45)/(life-.45),0,1)
    else p.Transparency=1 end
   end
  end
 end
 if #active==0 and connection then connection:Disconnect();connection=nil end
end
function A.charge(owner,origin,direction,now,q,scale)
 local f=owner.aftermath
 if not f then
  if #active>=4 then return end
  f=table.remove(pool) or create();f.owner=owner;owner.aftermath=f
  f.phase='charge';f.firedAt=nil;f.root.Parent=workspace;active[#active+1]=f
  if not connection then
   local run=game:GetService('RunService')
   connection=(run.RenderStepped or run.Heartbeat):Connect(function() A.step(workspace:GetServerTimeNow()) end)
  end
 end
 f.root.CFrame=CFrame.new(origin);f.updatedAt=now;f.scale=math.min(scale or 1,1.5)
 local color=owner.color or BLUE
 if f.color~=color then
  f.color=color
  for _,s in ipairs(f.smoke) do s.e.Color=ColorSequence.new(color) end
  for i,p in ipairs(f.chips) do p.Color=A.palette(color,i) end
  for _,r in ipairs(f.plane.rays) do r.beam.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.2)) end
 end
 f.direction=direction
 local ref=math.abs(direction.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 f.right=direction:Cross(ref).Unit;f.up=f.right:Cross(direction).Unit
 for i,s in ipairs(f.smoke) do
  local angle=i*math.pi/3
  s.radial=f.right*math.cos(angle)+f.up*math.sin(angle)
  s.a.Position=s.radial*(.12+.45*q)*f.scale
  s.e.Acceleration=s.radial*.15
 end
 if q>.32 and q<.99 and (not f.lastEmission or now-f.lastEmission>=.24) then
  for i=1,3 do f.smoke[((f.emissionSector or 0)+i-1)%6+1].e:Emit(1) end
  f.emissionSector=((f.emissionSector or 0)+3)%6
  f.lastEmission=now
 end
end
function A.fire(owner,origin,direction,now,age)
 local f=owner.aftermath
 if not f then return end
 if not age or age<0 or age>.16 then A.cancel(owner);return end
 f.root.CFrame=CFrame.new(origin);f.direction=direction;f.phase='release';f.firedAt=now-age
 -- The launched tail no longer belongs to a charge lease or moving drone.
 f.owner=nil;owner.aftermath=nil
 for _,s in ipairs(f.smoke) do s.e:Emit(2) end
 A.step(now)
end
function A.counts() return #active,#pool end
return A

end)()
local StartupFX = (function()
-- The supplied clip's inward streams, compact charge glint and flat release.
-- This shares the same force-sampled paths as the regular laser's charge.
local FX={MaxActive=4,MaxDistance=110}
local palettes={Stars=Color3.fromRGB(105,224,255),Ignition=Color3.fromRGB(255,179,77),Coil=Color3.fromRGB(182,137,255)}
local fades={}
for i=0,32 do fades[i]=NumberSequence.new(1-i/32) end
local function line(root,color)
 local a=Instance.new('Attachment');a.Parent=root
 local b=Instance.new('Attachment');b.Parent=root
 local beam=Instance.new('Beam');beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.Segments=8;beam.LightEmission=1;beam.LightInfluence=0
 beam.Color=ColorSequence.new(color);beam.Enabled=false;beam.Parent=root
 return {a=a,b=b,beam=beam}
end
local function pose(a,p,tangent)
 local ref=math.abs(tangent.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=tangent:Cross(ref).Unit
 a.CFrame=CFrame.fromMatrix(p,tangent,back:Cross(tangent).Unit,back)
end
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function FX.create(parent,style,seed)
 local color=palettes[style] or palettes.Coil
 local root=Instance.new('Part');root.Name='LaserStartup_'..style
 root.Anchored=true;root.Transparency=1;root.Size=Vector3.one*.025
 root.CanCollide=false;root.CanTouch=false;root.CanQuery=false;root.CastShadow=false;root.Parent=parent
 local f={root=root,style=style,seed=seed or 1,arcs={},rays={},glints={{rays={}}},plane=PlaneBurst.create(root,color)}
 for i=1,8 do f.arcs[i]=line(root,color);f.rays[i]=line(root,Color3.new(1,1,1));f.rays[i].beam.Segments=1 end
 for i=1,4 do f.glints[1].rays[i]=line(root,Color3.new(1,1,1));f.glints[1].rays[i].beam.Segments=1 end
 return f
end
function FX.hide(f)
 f.root.Transparency=1;PlaneBurst.hide(f.plane)
 for _,l in ipairs(f.arcs) do l.beam.Enabled=false end
 for _,l in ipairs(f.rays) do l.beam.Enabled=false end
 for _,g in ipairs(f.glints) do for _,l in ipairs(g.rays) do l.beam.Enabled=false end end
end
function FX.destroy(f) f.root:Destroy() end
function FX.update(f,origin,q)
 f.root.CFrame=CFrame.new(origin.Position)
 for i,l in ipairs(f.arcs) do
  local timing=f.style=='Ignition' and q^.82 or f.style=='Coil' and q^1.12 or q
  local a,va,captured=PullMotion.sample(i,timing)
  local b,vb=PullMotion.sample(i,math.max(0,timing-.13))
  local alpha=smooth(q/.035)*(1-smooth((timing-captured+.035)/.035))
  local span=(b-a).Magnitude
  local breadth=f.style=='Coil' and .075 or f.style=='Ignition' and .045 or .035
  l.beam.Enabled=alpha>.01 and span>.002 and va.Magnitude>.01 and vb.Magnitude>.01
  local head=f.rays[i];head.beam.Enabled=l.beam.Enabled
  if l.beam.Enabled then
   pose(l.a,a*.62,-va.Unit);pose(l.b,b*.62,-vb.Unit)
   l.beam.CurveSize0=span*.62/3;l.beam.CurveSize1=span*.62/3
   l.beam.Width0=breadth*alpha;l.beam.Width1=0;l.beam.Transparency=fades[math.floor(alpha*32+.5)]
   head.a.Position=a*.62;head.b.Position=(a-va.Unit*.075)*.62
   head.beam.Width0=.09*alpha;head.beam.Width1=0;head.beam.Transparency=fades[math.floor(alpha*32+.5)]
  end
 end
 -- Stars have distinct short flashes with quiet gaps. Ignition forms one
 -- compressed hot slit; Coil stays dark between its inward strands. These
 -- silhouettes belong to specialists and never replace the regular color pop.
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 local light=smooth((q-.38)/.48)*(1-smooth((q-.9)/.1))
 if f.style=='Stars' then
  light=0
  for _,at in ipairs({.28,.53,.73,.91}) do
   local u=(q-at)/.065
   if u>=0 and u<1 then light=math.max(light,math.sin(u*math.pi)*(at==.91 and 1.5 or .7+at*.3)) end
  end
 elseif f.style=='Ignition' then light=smooth((q-.64)/.2)*(1-smooth((q-.94)/.06))
 else light=light*.28 end
 for i,l in ipairs(f.glints[1].rays) do
  local axis=i==1 and right or i==2 and up or i==3 and -right or -up
  local aspect=f.style=='Ignition' and (i%2==1 and 1.65 or .35) or 1
  l.a.Position=Vector3.zero;l.b.Position=axis*(.10+.42*light)*aspect
  l.beam.Width0=.055*light;l.beam.Width1=0;l.beam.Enabled=light>.01
  l.beam.Transparency=fades[math.floor(math.clamp(light,0,1)*32+.5)]
 end
 PlaneBurst.draw(f.plane,-Vector3.yAxis,(q-.86)/.14,.8)
end
return FX

end)()
local BeamVFX = (function()
-- Client-only beam vocabulary. No gameplay clocks, queries, remotes or assets.
-- Native tapered ribbons form the four-point glint; curved ribbons follow
-- explicit world-space paths. Neither depends on bloom or uploaded textures.
local B={}
B.MiningScale=1 -- Restore the first installed beam proportions.
B.WidthScale=.4
B.startupStyles={Bubbler='Stars',Starforge='Stars',Halver='Ignition',Singularity='Coil',Resonator='Coil'}
local WHITE=Color3.fromRGB(247,250,255)
local DARK=Color3.fromRGB(19,9,32)
local DARK_GLOW=Color3.fromRGB(48,20,68)
local Players=game:GetService('Players')
local TAU=math.pi*2
local live,details=0,0
B.limits={rigs=64,details=12,reservedRigs=4,reservedDetails=2}
B.styles={
 Cutter={body=.30,core=.055,taper=.48,orbit=.32,spin=2.5,star=.24,tail=.65},
 Percussion={body=.36,core=.075,taper=.22,orbit=.37,spin=1.7,star=.36,tail=.55},
 Resonance={body=.25,core=.04,taper=.7,orbit=.4,spin=2,star=.24,tail=.8},
 Combat={body=.22,core=.07,taper=.12,orbit=.2,spin=4,star=.45,tail=.45},
 Branch={body=.10,core=.025,taper=.35,orbit=0,spin=0,star=0,tail=.25},
 Repair={body=.13,core=.025,taper=.82,orbit=.18,spin=1,star=.12,tail=.7},
 Courier={body=.10,core=.02,taper=.35,orbit=.20,spin=-1.8,star=.12,tail=.6},
 Sentry={body=.32,core=.065,taper=.18,orbit=.26,spin=-2,star=.38,tail=.45},
 Lance={body=.24,core=.055,taper=.08,orbit=.24,spin=3,star=.38,tail=.8},
 Orbital={body=1.8,core=.2,taper=.6,orbit=2.1,spin=3.1,star=1.65,tail=1.1},
 Gridcutter={body=.065,core=.018,taper=.15,orbit=.15,spin=0,star=.17,tail=.55},
 Starforge={body=.12,core=.035,taper=.28,orbit=.3,spin=2.7,star=.32,tail=.8},
 Singularity={body=.09,core=.02,taper=.4,orbit=.55,spin=-3,star=.32,tail=.9},
}
local function sequence(a,b,c,d)
 return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.12,b),
  NumberSequenceKeypoint.new(.86,c),NumberSequenceKeypoint.new(1,d)})
end
-- A stable soft body: moving hard transparency cuts read as dropped frames.
local BODY=sequence(.45,.2,.3,.8)
local CORE=sequence(.18,.04,.12,.32)
local EDGE=sequence(.85,.4,.72,1)
local INK=sequence(1,.42,.65,1)
local ARC=sequence(1,.3,.45,1)
local STAR=NumberSequence.new(.18)
local function clamp(v) return math.clamp(v,0,1) end
local function smooth(v) v=clamp(v);return v*v*(3-2*v) end
function B.charge(q)
 q=clamp(q)
 if q<.76 then return smooth(q/.76),0 end
 if q<.9 then return 1-.62*smooth((q-.76)/.14),0 end
 return .38+.32*smooth((q-.9)/.1),smooth((q-.9)/.1)
end
function B.reduced()
 local p=Players.LocalPlayer
 return p and (p:GetAttribute('ReducedMotion')==true or p:GetAttribute('MA_ReducedMotion')==true
  or p:GetAttribute('ReducedEffects')==true or p:GetAttribute('MA_ReducedEffects')==true) or false
end
function B.near(position,distance)
 local camera=workspace.CurrentCamera
 if not camera then return false end
 local delta=camera.CFrame.Position-position
 return delta:Dot(delta)<distance*distance
end
local function attachment(root,name)
 local a=Instance.new('Attachment');a.Name=name;a.Parent=root;return a
end
local function ribbon(root,name,a,b,color,opacity)
 local v=Instance.new('Beam');v.Name=name;v.Attachment0=a;v.Attachment1=b
 v.FaceCamera=true;v.Segments=12;v.LightEmission=.65;v.LightInfluence=0;v.Brightness=1
 v.Color=ColorSequence.new(color);v.Transparency=opacity;v.Enabled=false;v.Parent=root
 return v
end
local function pair(root,name,color,opacity)
 local a,b=attachment(root,name..'From'),attachment(root,name..'To')
 return {a=a,b=b,beam=ribbon(root,name,a,b,color,opacity)}
end
function B.new(parent,style,color,detail,chargeLens)
 local priority=style=='Orbital' or style=='Singularity'
 local limit=B.limits.rigs-(priority and 0 or B.limits.reservedRigs)
 if live>=limit or not parent then return nil end
 local root=Instance.new('Part');root.Name='BeamVFX';root.Transparency=1;root.Size=Vector3.one*.025
 root.Anchored=true;root.CanQuery=false;root.CanTouch=false;root.CanCollide=false;root.CastShadow=false
 root.Parent=parent
 local r={root=root,all={},style=style,color=color,profile=B.styles[style] or B.styles.Cutter}
 r.a=attachment(root,'Source');r.b=attachment(root,'Contact')
 r.body=ribbon(root,'TaperedBody',r.a,r.b,color,BODY);r.all[#r.all+1]=r.body
 r.core=ribbon(root,'NeedleCore',r.a,r.b,color:Lerp(WHITE,.65),CORE);r.all[#r.all+1]=r.core
 r.body.Segments=1;r.core.Segments=1
 live+=1
 local counted=true
 root.Destroying:Connect(function()
  if counted then
   if B.onChargeEnd then B.onChargeEnd(r) end
   LaunchAftermath.cancel(r)
   counted=false;r.destroyed=true;live-=1
   if live==0 and B.clearChargeCache then B.clearChargeCache() end
   if r.detail then details-=1;r.detail=false end
  end
 end)
 -- Detail leases are acquired only near the viewer, and returned on culling.
 r.wantDetail=detail~=false;r.wantChargeLens=chargeLens~=false
 return r
end
local releaseRich,acquireRich,hideRich,drawRich
local function freeDetail(r)
 LaunchAftermath.cancel(r)
 if releaseRich then releaseRich(r) end
 if not r.detail then return end
 for _,p in ipairs(r.paths) do p.beam:Destroy();p.a:Destroy();p.b:Destroy() end
 for _,p in ipairs(r.stars) do p.beam:Destroy();p.b:Destroy() end
 r.starSource:Destroy();r.starSource=nil
 PlaneBurst.destroy(r.plane);r.plane=nil
 for i=#r.all,3,-1 do r.all[i]=nil end
 r.paths=nil;r.stars=nil;r.detail=false;details-=1
 if r.orb then r.orb:Destroy();r.orb=nil end
end
local function addDetail(r)
 local priority=r.style=='Orbital' or r.style=='Singularity'
 local limit=B.limits.details-(priority and 0 or B.limits.reservedDetails)
 if r.detail or not r.wantDetail or details>=limit then return end
 r.detail=true;details+=1;r.paths={};r.stars={}
 if r.style=='Orbital' or r.style=='Singularity' or r.style=='Cutter' then
  local orb=Instance.new('Part');orb.Name='ChargedDarkCore';orb.Shape=Enum.PartType.Ball
  orb.Material=Enum.Material.SmoothPlastic;orb.Color=DARK
  orb.Anchored=true;orb.CanCollide=false;orb.CanTouch=false;orb.CanQuery=false;orb.CastShadow=false
  orb.Transparency=1;orb.Parent=r.root;r.orb=orb
 end
 for i=1,4 do
  local p=pair(r.root,i<=2 and 'OrbitRibbon' or i==3 and 'EdgeFilament' or 'DarkCut',r.color,i<=2 and ARC or i==3 and EDGE or INK)
  if i>=3 then p.beam.Segments=1 end
  if i==4 then p.beam.Color=ColorSequence.new(Color3.fromRGB(22,15,37));p.beam.LightEmission=0;p.beam.Brightness=1 end
  r.paths[i]=p;r.all[#r.all+1]=p.beam
 end
 r.plane=PlaneBurst.create(r.root,r.color)
 r.starSource=attachment(r.root,'StarCenter')
 for i=1,4 do
  local a=attachment(r.root,'StarPoint'..i)
  local v=ribbon(r.root,'FourPointStar',r.starSource,a,WHITE,STAR);v.Segments=1
  r.stars[i]={b=a,beam=v};r.all[#r.all+1]=v
 end
end
function B.hide(r,releaseDetail)
 if not r or r.destroyed then return end
 LaunchAftermath.cancel(r)
 -- A hidden charge must return its lease even when base detail is retained.
 if releaseRich then releaseRich(r) end
 for _,v in ipairs(r.all) do v.Enabled=false end
 if r.plane then PlaneBurst.hide(r.plane) end
 if r.orb then r.orb.Transparency=1 end
 if releaseDetail then freeDetail(r) end
end
function B.destroy(r)
 if r then r.root:Destroy() end
end
function B.style(r,style,color)
 if not r or r.destroyed or (r.style==style and r.color==color) then return end
 if releaseRich then releaseRich(r) end
 r.style=style;r.profile=B.styles[style] or B.styles.Cutter;r.color=color
 r.body.Color=ColorSequence.new(color);r.core.Color=ColorSequence.new(color:Lerp(WHITE,.65))
 if r.paths then for i=1,3 do r.paths[i].beam.Color=ColorSequence.new(color) end end
 if r.plane then for _,ray in ipairs(r.plane.rays) do ray.beam.Color=ColorSequence.new(color:Lerp(WHITE,.2)) end end
end
function B.startup(r,style)
 if not r or r.destroyed or r.startupStyle==style then return end
 releaseRich(r);r.startupStyle=style
end
local function pose(a,position,tangent)
 local reference=math.abs(tangent.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=tangent:Cross(reference).Unit;local up=back:Cross(tangent).Unit
 -- Beam curves use the attachment's X axis, not its LookVector.
 a.CFrame=CFrame.fromMatrix(position,tangent,up,back)
end
-- The supplied motion reference uses a refracting lens as the main silhouette.
-- Only major effects lease this rig; every pose is an absolute timestamp sample.
local richLive=0
local richLimit=4
local richPoolLimit=6 -- Mixed preview styles can need overlapping refraction rigs.
local richPool={} -- Six detached cached rigs maximum; active lease limit stays four.
function B.clearChargeCache()
 for _,h in ipairs(richPool) do h.root:Destroy() end
 table.clear(richPool)
end
local GLASS_COLOR=Color3.fromRGB(245,250,255)
local CYAN=Color3.fromRGB(108,238,255)
local VIOLET=Color3.fromRGB(166,64,255)
local LENS_COLORS={Color3.fromRGB(255,255,0),Color3.fromRGB(0,255,255),Color3.fromRGB(255,0,255),Color3.fromRGB(255,255,0)}
local function visualPart(parent,name,material,color,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
 p.Transparency=1;p.Size=Vector3.one*.02;p.Material=material;p.Color=color
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
local function richPath(r,name,color,opacity)
 local p=pair(r.rich.root,name,color,opacity or ARC)
 p.beam.Width1=0;r.rich.paths[#r.rich.paths+1]=p;return p
end
releaseRich=function(r)
 local h=r.rich;if not h then return end
 if B.onChargeEnd and not h.launched then B.onChargeEnd(r) end
 hideRich(r);r.rich=nil
 if h.leased then h.leased=false;richLive-=1 end
 if h.particleSource then
  h.vapor:Clear();h.sparks:Clear();h.particleSource.Parent=h.root
 end
 h.lastEmission=nil;h.lastPulse=nil;h.launched=nil;h.root.Parent=nil
 if #richPool>=richPoolLimit then table.remove(richPool,1).root:Destroy() end
 richPool[#richPool+1]=h
end
acquireRich=function(r)
 if r.rich or not r.wantChargeLens or richLive>=richLimit or r.style=='Repair' or r.style=='Courier' or r.style=='Branch' then return end
 local key=r.startupStyle or 'Refraction'
 for i=#richPool,1,-1 do
  local h=richPool[i]
  if h.key==key then
   table.remove(richPool,i);r.rich=h;h.leased=true;richLive+=1
   h.root.Parent=r.root
   if h.particleSource then h.particleSource.Parent=r.root end
   return
  end
 end
 local folder=Instance.new('Folder');folder.Name='RefractionChoreography';folder.Parent=r.root
 local h={root=folder,paths={},comets={},sweeps={},bolts={},debris={},lastEmission=nil,key=key,leased=true}
 r.rich=h;richLive+=1
 folder.Destroying:Connect(function() if h.leased then h.leased=false;richLive-=1 end end)
 if r.startupStyle then
  h.startup=StartupFX.create(folder,r.startupStyle,1)
  return
 end
 h.glass=visualPart(folder,'ClearGlassDistortion',Enum.Material.Glass,GLASS_COLOR,Enum.PartType.Ball)
 h.glass.Reflectance=0
 -- Glass + Highlight is a native renderer technique, verified in this Studio.
 -- Keep it local and optional: above-one transparency is engine-dependent.
 h.mask=Instance.new('Highlight');h.mask.Name='ChromaticDistortionMask'
 h.mask.DepthMode=Enum.HighlightDepthMode.Occluded;h.mask.OutlineTransparency=.999
 h.mask.FillTransparency=1;h.mask.FillColor=Color3.fromRGB(255,255,0);h.mask.Enabled=false;h.mask.Parent=h.glass
 h.core=visualPart(folder,'ChargeOriginCore',Enum.Material.SmoothPlastic,DARK,Enum.PartType.Ball)
 for i=1,8 do
  h.comets[i]={path=richPath(r,'InwardStream'..i,i%2==0 and CYAN or VIOLET),
   head=visualPart(folder,'InwardSpark',Enum.Material.Neon,i%2==0 and CYAN or WHITE,Enum.PartType.Ball)}
 end
 for i=1,3 do
  local edge=richPath(r,'InwardTendrilEdge'..i,VIOLET,ARC)
  local ink=richPath(r,'InwardTendrilInk'..i,DARK,ARC)
  ink.beam.LightEmission=0
  h.sweeps[i]={edge=edge,ink=ink}
 end
 h.vapor=Instance.new('ParticleEmitter');h.vapor.Name='VioletDistortionVapor';h.vapor.Texture='rbxasset://textures/particles/smoke_main.dds'
 h.vapor.Enabled=false;h.vapor.Rate=0;h.vapor.Color=ColorSequence.new(VIOLET)
 h.vapor.LightEmission=.35;h.vapor.LightInfluence=0;h.vapor.Brightness=1
 h.vapor.Lifetime=NumberRange.new(.5,1.3);h.vapor.Speed=NumberRange.new(1,3.5);h.vapor.Drag=3
 h.vapor.SpreadAngle=Vector2.new(180,180);h.vapor.Acceleration=Vector3.new(0,.7,0);h.vapor.WindAffectsDrag=false
 h.vapor.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(.35,1.9),NumberSequenceKeypoint.new(1,2.8)})
 h.vapor.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,.62),NumberSequenceKeypoint.new(1,1)})
 h.vapor.Rotation=NumberRange.new(-180,180);h.vapor.RotSpeed=NumberRange.new(-55,55)
 h.particleSource=attachment(r.root,'LensParticleSource');h.vapor.Parent=h.particleSource
 h.sparks=Instance.new('ParticleEmitter');h.sparks.Name='LensDischargeSparks';h.sparks.Texture='rbxasset://textures/particles/sparkles_main.dds'
 h.sparks.Enabled=false;h.sparks.Rate=0;h.sparks.Color=ColorSequence.new(CYAN);h.sparks.LightEmission=.8;h.sparks.LightInfluence=0;h.sparks.Brightness=1.5
 h.sparks.Lifetime=NumberRange.new(.25,.65);h.sparks.Speed=NumberRange.new(4,11);h.sparks.Drag=4;h.sparks.SpreadAngle=Vector2.new(180,180)
 h.sparks.Acceleration=Vector3.new(0,-2,0);h.sparks.WindAffectsDrag=false;h.sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.11),NumberSequenceKeypoint.new(.15,.24),NumberSequenceKeypoint.new(1,0)})
 h.sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,1)});h.sparks.Parent=h.particleSource
 -- Emitters are outside the detail Folder because their parent is an Attachment.
 folder.Destroying:Connect(function() h.particleSource:Destroy() end)
end
hideRich=function(r)
 local h=r.rich;if not h then return end
 if h.startup then StartupFX.hide(h.startup);return end
 h.glass.Transparency=1;h.mask.Enabled=false;h.core.Transparency=1
 for _,p in ipairs(h.paths) do p.beam.Enabled=false end
 for _,p in ipairs(h.debris) do p.Transparency=1 end
 for _,p in ipairs(h.comets) do p.head.Transparency=1 end
 h.vapor.Enabled=false;h.sparks.Enabled=false
end
local function curve(path,a,b,ta,tb,bend,width)
 if width<=.002 then
  if path.beam.Enabled then path.beam.Enabled=false end
  return
 end
 pose(path.a,a,ta);pose(path.b,b,tb)
 path.beam.CurveSize0=bend;path.beam.CurveSize1=bend
 path.beam.Width0=width
 if not path.beam.Enabled then path.beam.Enabled=true end
end
-- Original pre-revision flash, preserved independently of the longer inflow.
function B.lensEnvelope(q)
 if q==nil or q<.64 or q>=1 then return 0 end
 if q<.79 then return smooth((q-.64)/.15) end
 return 1-smooth((q-.79)/.21)
end
function B.flashProgress(q,duration)
 duration=math.max(.01,duration or .8)
 return 1-(1-q)*duration/math.min(.8,duration)-.1
end
local function drawFlash(h,from,flashQ,s)
 local lens=B.lensEnvelope(flashQ)
 local radius=s*(.025+4.475*lens)
 h.glass.CFrame=CFrame.new(from);h.glass.Size=Vector3.one*radius*2
 h.mask.Enabled=lens>.002
 h.glass.Transparency=lens>.002 and (1+2*lens) or 1
 local colorPulse=smooth((flashQ-.70)/.045)*(1-smooth((flashQ-.975)/.025))
 local colorAt=clamp((flashQ-.73)/.24)*3
 local index=math.min(4,math.floor(colorAt)+1)
 h.mask.FillColor=LENS_COLORS[index]
 h.mask.FillTransparency=1+1.2*colorPulse
end
drawRich=function(r,from,to,now,width,charge,releaseAge,scale,afterAge,chargeDuration)
 local h=r.rich;if not h then return end
 if charge==nil or charge<0 or charge>=1 or afterAge then hideRich(r);return end
 if B.onCharge then B.onCharge(r,from,now,charge) end
 if h.startup then StartupFX.update(h.startup,CFrame.new(from),charge);return end
 local q=charge
 local major=r.style=='Orbital' and 1 or r.style=='Singularity' and .34 or .2
 local s=major*(scale or 1)
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local vertical=camera and camera.CFrame.UpVector or Vector3.yAxis
 local eye=camera and camera.CFrame.Position-from or Vector3.zAxis*40
 local toward=eye.Magnitude>.01 and eye.Unit or Vector3.zAxis
 local inflow=smooth(q/.12)*(1-smooth((q-.62)/.26))
 local flashQ=B.flashProgress(q,chargeDuration)
 h.flashDuration=math.min(.8,math.max(.01,chargeDuration or .8))
 if h.tint~=r.color then
  h.tint=r.color;h.glass.Color=GLASS_COLOR
  h.vapor.Color=ColorSequence.new(r.color);h.sparks.Color=ColorSequence.new(r.color)
  for i,item in ipairs(h.comets) do
   local color=r.color:Lerp(WHITE,i%2==0 and .3 or 0)
   item.path.beam.Color=ColorSequence.new(color);item.head.Color=color
  end
 end
 local delta=to-from
 LaunchAftermath.charge(r,from,delta.Unit,now,q,scale)
 local pressure=smooth((q-.36)/.26)*(1-smooth((q-.85)/.13))
 local alive=smooth(q/.1)*(1-smooth((q-.94)/.06))
 -- The single surface goes clear -> chromatic -> clear, so nested Glass
 -- cannot hide the color layer. It stays exactly on the emitting attachment.
 drawFlash(h,from,flashQ,s)
 h.core.CFrame=CFrame.new(from);h.core.Size=Vector3.one*s*(.35+.9*smooth(q/.65))
 h.core.Transparency=alive>.02 and 0 or 1
 h.particleSource.Position=toward*s*.8
 -- The video's streams are moving inward immediately. Their curvature is
 -- generated by attraction acting on momentum, not an orbit angle animation.
 for i,item in ipairs(h.comets) do
  local a,va,captured=PullMotion.sample(i,q)
  local b,vb=PullMotion.sample(i,math.max(0,q-.13))
  local visible=smooth(q/.035)*(1-smooth((q-captured+.035)/.035))
  local head=a*s*2.6;local tail=b*s*2.6
  local span=(tail-head).Magnitude
  if va.Magnitude>.01 and vb.Magnitude>.01 and span>.002 then
   curve(item.path,head,tail,-va.Unit,-vb.Unit,span/3,.22*s*visible)
  else item.path.beam.Enabled=false end
  item.head.CFrame=CFrame.new(from+head)
  item.head.Size=Vector3.one*math.max(.01,.25*s*visible)
  item.head.Transparency=1-visible
 end
 -- Small ink curls have separate arrivals and deform along attracted paths.
 -- No shared orbit angle or reset: each short ribbon is drawn into the mouth.
 for i,item in ipairs(h.sweeps) do
  local start=.035+(i-1)*.12
  local finish=.72+(i-1)*.065
  local t=clamp((q-start)/(finish-start))
  local _,_,captured=PullMotion.sample(i*2,0)
  local progress=t*captured
  local a,va=PullMotion.sample(i*2,progress)
  local b,vb=PullMotion.sample(i*2,math.max(0,progress-.09-.018*i))
  local visible=smooth(t/.12)*(1-smooth((t-.82)/.18))
  local head=a*s*2;local tail=b*s*2
  local span=(tail-head).Magnitude
  if span>.002 and va.Magnitude>.01 and vb.Magnitude>.01 then
   local breadth=s*(.52+.1*math.sin(t*11+i*2.1))*visible
   curve(item.edge,head,tail,-va.Unit,-vb.Unit,span/3,breadth)
   curve(item.ink,head,tail,-va.Unit,-vb.Unit,span/3,breadth*.66)
  else
   item.edge.beam.Enabled=false;item.ink.beam.Enabled=false
  end
 end
 -- Fine charge motes stop at release; the separately owned smoke persists.
 -- Never emit catch-up batches after a late observer or paused render loop.
 if inflow>.05 then
  if h.lastEmission and now>=h.lastEmission+.08 then
   h.sparks:Emit(2);h.lastEmission=now
  elseif not h.lastEmission or now<h.lastEmission then h.lastEmission=now end
 else h.lastEmission=nil end
end

-- width is the caller's authoritative-envelope result. Charge never changes
-- contact timing. releaseAge is from the server start, never local creation.
function B.draw(r,from,to,now,width,charge,releaseAge,scale,chargeDuration)
 if not r or r.destroyed or not r.root.Parent then return end
 width=clamp(width);scale=scale or 1
 if charge and charge>=1 and width==0 then B.hide(r,true);return end
 local near=B.near(from,r.style=='Orbital' and 340 or 110)
 local reduced=B.reduced()
 if not near or reduced then freeDetail(r) else addDetail(r) end
 local delta=to-from;local length=delta.Magnitude
 if length<.015 then B.hide(r);return end
 local direction=delta/length
 local reference=math.abs(direction.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local side=direction:Cross(reference).Unit;local up=side:Cross(direction).Unit
 r.root.CFrame=CFrame.new(from);r.a.Position=Vector3.zero;r.b.Position=delta
 local p=r.profile
 -- Keep body opacity stable; release pressure carries the width motion.
 local launchPressure=releaseAge and releaseAge>=0 and (1-clamp(releaseAge/.14))^2 or 0
 local thickness=p.body*width*scale*B.WidthScale*(1+launchPressure*.35)
 r.body.Width0=thickness;r.body.Width1=thickness*p.taper;r.body.Enabled=width>.002
 r.core.Width0=p.core*width*scale*B.WidthScale;r.core.Width1=p.core*width*scale*.6*B.WidthScale;r.core.Enabled=width>.002
 if not r.detail then return end
 if charge~=nil and charge>=0 and charge<1 then
  acquireRich(r);drawRich(r,from,to,now,width,charge,releaseAge,scale,nil,chargeDuration)
 else
  local h=r.rich
  if h and not h.launched then
   h.launched=true
   if B.onChargeEnd then B.onChargeEnd(r) end
   if releaseAge and releaseAge>=0 and releaseAge<=.16 and B.onCue then B.onCue('launch',from,now,1) end
  end
  LaunchAftermath.fire(r,from,direction,now,releaseAge)
  -- Ignition overlaps the final color cuts by 80 ms at normal charge speed.
  -- Only the lens remains: inflow and charge audio end on authoritative release.
  if h and not h.startup and releaseAge and releaseAge>=0 and releaseAge<h.flashDuration*.1 then
   hideRich(r)
   local major=r.style=='Orbital' and 1 or r.style=='Singularity' and .34 or .2
   drawFlash(h,from,.9+releaseAge/h.flashDuration,major*scale)
  else releaseRich(r) end
 end
 if r.rich and r.rich.startup then
  -- The selected cloud style is the charge silhouette, not another overlay.
  for _,v in ipairs(r.all) do if v.Enabled then v.Enabled=false end end
  if r.orb then r.orb.Transparency=1 end
  return
 end
 local gather,glint=0,0
 if charge~=nil then gather,glint=B.charge(charge) end
 local release=releaseAge and releaseAge>=0 and (1-clamp(releaseAge/.18))^2 or 0
 -- Restore the first version's small emitting glint. Release spreads in
 -- a fixed plane perpendicular to the laser; nothing turns into a bright ball.
 local energy=charge~=nil and gather or width
 local radius=p.orbit*scale
 if r.orb then r.orb.Transparency=1 end
 -- Regular lens charges hand their ring to the independent aftermath clock.
 if r.wantChargeLens and not r.startupStyle and r.style~='Repair' and r.style~='Courier' and r.style~='Branch' then
  PlaneBurst.hide(r.plane)
 else PlaneBurst.draw(r.plane,direction,releaseAge and releaseAge/1.1,scale) end
 for i=1,2 do
  local path=r.paths[i];path.beam.Enabled=false
  if charge==nil and (r.style=='Resonance' or r.style=='Repair') then
   local bend=(i==1 and 1 or -1)*.12*math.sin(now*1.3)
   pose(path.a,Vector3.zero,(direction+side*bend).Unit)
   pose(path.b,delta,(direction-side*bend).Unit)
   path.beam.CurveSize0=length*.33;path.beam.CurveSize1=length*.33
   path.beam.Width0=p.core*width*scale*.65*B.WidthScale;path.beam.Width1=0
   path.beam.Enabled=width>.02
  elseif charge==nil and (r.style=='Cutter' or r.style=='Combat' or r.style=='Lance' or r.style=='Sentry' or r.style=='Starforge') then
   local t=(now*1.7+(i-1)*.5)%1
   local visibility=math.sin(math.pi*t)^2
   path.a.Position=delta*t;path.b.Position=delta*math.min(1,t+.055)
   path.beam.CurveSize0=0;path.beam.CurveSize1=0
   path.beam.Width0=p.core*width*scale*B.WidthScale*visibility;path.beam.Width1=0
   path.beam.Enabled=width>.02 and visibility>.02
  elseif charge==nil and r.style=='Courier' then
   local t=1-((now*.8+(i-1)*.5)%1)
   path.a.Position=delta*t;path.b.Position=delta*math.max(0,t-.12)
   path.beam.CurveSize0=0;path.beam.CurveSize1=0
   path.beam.Width0=.035*energy*scale*B.WidthScale;path.beam.Width1=.012*energy*scale*B.WidthScale
   path.beam.Enabled=width>.02
  end
 end
 -- Parallel rim + normally blended dark seam. Endpoint offsets shrink to
 -- zero at contact, so no filament can protrude beyond the verified surface.
 for i=3,4 do
  local path=r.paths[i];local offset=side*(i==3 and .22 or -.13)*thickness
  path.a.Position=offset;path.b.Position=delta
  path.beam.CurveSize0=0;path.beam.CurveSize1=0
  path.beam.Width0=thickness*(i==3 and .08 or .14);path.beam.Width1=0
  path.beam.Enabled=width>.02

 end
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or side
 local vertical=camera and camera.CFrame.UpVector or up
 local star=p.star*scale*math.max(release,glint*.3)
 local starCenter=r.style=='Orbital' and charge==nil and Vector3.yAxis*2.5 or Vector3.zero
 r.starSource.Position=starCenter
 -- Concave four-cardinal needle silhouette, with quiet gaps between rays.
 for i,path in ipairs(r.stars) do
  local axis=i==1 and right or i==2 and vertical or i==3 and -right or -vertical
  path.b.Position=starCenter+axis*star
  path.beam.Width0=star*.22;path.beam.Width1=0;path.beam.Enabled=star>.008 and not reduced
 end
end
function B.counts() return live,details,richLive,#richPool end
-- Main geometry, fine trace, star and flecks have separate shutdown clocks.
-- Reuse the rig; no emitter/Part allocation occurs when a cast ends.
function B.after(r,from,to,now,age,scale)
 if not r or r.destroyed or age<0 then return end
 if (to-from).Magnitude<.015 then B.hide(r,true);return end
 local lifetime=r.profile.tail;local q=clamp(age/lifetime)
 if q>=1 then B.hide(r,true);return end
 local trace=(1-clamp(age/.14))^2
 B.draw(r,from,to,now,trace*.16,nil,nil,scale)
 r.body.Enabled=false
 if not r.detail or B.reduced() then return end
 local delta=to-from
 local camera=workspace.CurrentCamera
 local right=camera and camera.CFrame.RightVector or Vector3.new(1,0,0)
 local up=camera and camera.CFrame.UpVector or Vector3.yAxis
 local decay=(1-q)^2;local radius=r.profile.star*(scale or 1)*decay*.45
 local drift=Vector3.yAxis*(.08+.15*(1-math.exp(-age*3)))
 r.starSource.Position=delta+drift
 for i,path in ipairs(r.stars) do
  local axis=i==1 and right or i==2 and up or i==3 and -right or -up
  path.b.Position=delta+drift+axis*radius
  path.beam.Width0=radius*.22;path.beam.Width1=0;path.beam.Enabled=radius>.008
 end
 r.core.Enabled=false
 for i,path in ipairs(r.paths) do
  if i<=2 then
   local center=delta*(.32+i*.22)+up*(.1*(1-math.exp(-age*2)))
   path.a.Position=center-right*.035*decay;path.b.Position=center+right*.035*decay
   path.beam.CurveSize0=0;path.beam.CurveSize1=0
   path.beam.Width0=.045*decay;path.beam.Width1=.012*decay;path.beam.Enabled=decay>.04
  elseif i==3 then
   path.a.Position=Vector3.zero;path.b.Position=delta;path.beam.Width0=.025*trace;path.beam.Width1=0;path.beam.Enabled=trace>.02
  else path.beam.Enabled=false end
 end
end
return B

end)()
local WorkEffects = (function()
-- Attached, bounded work choreography. Server timestamps drive every phase;
-- these visuals never remove ore, credit a sale, heal, or advance mining.
local W={};W.__index=W
local Players=game:GetService('Players')
local GOLD=Color3.fromRGB(244,193,89)
local WHITE=Color3.fromRGB(236,249,255)
local ENERGY='rbxasset://textures/ui/VR/circleWhite.png'
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local YELLOW=Color3.fromRGB(255,208,69)
local ENERGY_TAIL=1.8
local function part(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Size=Vector3.one*.05;p.Transparency=1
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent
 return p
end
local function progress(now,at,duration)
 return math.clamp((now-at)/math.max(.01,duration),0,1)
end
local function facing(position,direction)
 local normal=direction.Magnitude>.001 and direction.Unit or Vector3.new(0,-1,0)
 local up=math.abs(normal.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 return CFrame.lookAt(position,position+normal,up)
end
local function cameraNear(position,radius)
 local camera=workspace.CurrentCamera
 if camera and (camera.CFrame.Position-position).Magnitude<radius then return true end
 local character=Players.LocalPlayer and Players.LocalPlayer.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 return root and (root.Position-position).Magnitude<radius or false
end
local function cameraAbove(position,radius)
 local camera=workspace.CurrentCamera
 if not camera then return false end
 local delta=camera.CFrame.Position-position
 return delta.X*delta.X+delta.Z*delta.Z<radius*radius
end
local function particle(parent,name,color)
 -- Energy uses a fresh emitter: the preserved Largeparticles template runs at
 -- TimeScale .2 and must not silently slow newly authored work effects.
 local p=Instance.new('ParticleEmitter')
 p.Name=name;p.Enabled=false;p.Rate=0
 -- Small discs are the neutral energy cue; contacts use fine sparks and
 -- fractures use matte smoke. Keep the original asset templates intact.
 p.Texture=ENERGY;p.Squash=NumberSequence.new(0)
 p.Color=ColorSequence.new(color);p.LightEmission=.8;p.LightInfluence=0;p.Brightness=1.8
 p.TimeScale=1;p.LockedToPart=false;p.VelocityInheritance=0;p.FlipbookLayout=Enum.ParticleFlipbookLayout.None
 p.EmissionDirection=Enum.NormalId.Front;p.Orientation=Enum.ParticleOrientation.FacingCamera
 p.Lifetime=NumberRange.new(.65,1.2);p.Speed=NumberRange.new(.4,1.2);p.Drag=2.4
 p.SpreadAngle=Vector2.new(45,45);p.Acceleration=Vector3.zero;p.WindAffectsDrag=false
 p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16),NumberSequenceKeypoint.new(.2,.26),NumberSequenceKeypoint.new(1,0)})
 p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(.55,.42),NumberSequenceKeypoint.new(1,1)})
 p.Parent=parent;return p
end
-- Three concentric sphere Parts, not orbiting rings. Different phases keep
-- the nested glow breathing without sudden size or transparency changes.
local function spheres(parent,color)
 local out={}
 for index,size in ipairs({.24,.46,.76}) do
  local globe=part(parent,'MiningSphere'..index);globe.Shape=Enum.PartType.Ball
  globe.Material=Enum.Material.Neon;globe.Color=index==1 and color:Lerp(WHITE,.18) or color
  table.insert(out,{part=globe,size=size,index=index})
 end
 return out
end
local function drawSpheres(record,now,strength,charge,pulse,color)
 if BeamVFX.reduced() then strength=0 end
 for _,sphere in ipairs(record.spheres) do
  local breathing=1+.035*math.sin(now*2.4+sphere.index*.85)
  local size=sphere.size*(record.scale or 1)*(.38+.18*charge)*breathing*(1+pulse*.08)
  sphere.part.Size=Vector3.one*math.max(.01,size)
  sphere.part.CFrame=record.anchor.CFrame*CFrame.new(0,0,-.08)
  sphere.part.Color=sphere.index==1 and color:Lerp(WHITE,.18) or color
  local opacity=({.30,.10,.025})[sphere.index]
  sphere.part.Transparency=1-math.clamp(strength,0,1)*opacity
 end
end
-- Roblox cylinders run along local X. One function owns all Part-laser poses.
function W.newCylinder(parent,name,color)
 local cylinder=part(parent,name);cylinder.Shape=Enum.PartType.Cylinder
 cylinder.Material=Enum.Material.Neon;cylinder.Color=color;cylinder.Reflectance=0
 return cylinder
end
function W.drawCylinder(cylinder,origin,target,diameter,transparency)
 local delta=target-origin;local length=delta.Magnitude
 if diameter<.002 or length<.015 then cylinder.Transparency=1;return end
 local axis=delta/length;local reference=math.abs(axis.Y)>.95 and Vector3.zAxis or Vector3.yAxis
 local back=axis:Cross(reference).Unit;local up=back:Cross(axis).Unit
 cylinder.Size=Vector3.new(length,diameter,diameter)
 cylinder.CFrame=CFrame.fromMatrix((origin+target)*.5,axis,up,back)
 cylinder.Transparency=math.clamp(transparency,0,1)
end
function W.new(parent)
 return setmetatable({parent=parent,miningBeams={},miningCount=0,maxMining=16,courierCount=0,maxCouriers=12,repairCount=0,maxRepairs=12,flightCount=0,maxFlightParticles=64,bursts={},maxBursts=14,orbitals={},scanAt=0},W)
end
function W:energyBloom()
 if self.bloom and self.bloom.Parent then return end
 local lighting=game:GetService('Lighting')
 local existing=lighting:FindFirstChild('MiningEnergyBloom')
 local bloom=existing or Instance.new('BloomEffect');bloom.Name='MiningEnergyBloom'
 bloom.Enabled=true;bloom.Intensity=.5;bloom.Size=20;bloom.Threshold=1.25;bloom.Parent=lighting
 self.bloom=bloom;self.ownsBloom=existing==nil
end
function W:burst(position,normal,color,count,now)
 if #self.bursts>=self.maxBursts or BeamVFX.reduced() or not cameraNear(position,140) then return end
 self:energyBloom()
 local anchor=part(self.parent,'WorkBurst');anchor.CFrame=facing(position,normal)
 local sparks=particle(anchor,'WorkSparks',color);sparks.Speed=NumberRange.new(9,14)
 sparks.Lifetime=NumberRange.new(1,1.6);sparks.Drag=11;sparks.Acceleration=Vector3.zero
 sparks.Texture=SPARK;sparks.Rotation=NumberRange.new(-180,180);sparks.RotSpeed=NumberRange.new(-40,40)
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.22,.03),NumberSequenceKeypoint.new(.06,.19,.02),NumberSequenceKeypoint.new(1,0)})
 sparks.SpreadAngle=Vector2.new(65,65)
 sparks:Emit(math.min(42,count));table.insert(self.bursts,{part=anchor,untilAt=now+ENERGY_TAIL})
end
function W:destroyMining(beam)
 local fx=beam.work
 if not fx then return end
 fx.impact:Destroy();if fx.tip then fx.tip:Destroy() end;fx.anchor:Destroy();beam.work=nil;self.miningBeams[beam]=nil;self.miningCount=math.max(0,self.miningCount-1)
end
function W:mining(beam,sample,point,normal,width,pulse,now)
 local charging=sample.charging and not sample.paused and sample.warmupStart>0
 local working=sample.active and sample.isMining and not sample.paused and point~=nil and width>.001
 local visible=not BeamVFX.reduced() and sample.alive and sample.isMining and (charging or working or width>.001) and cameraNear(beam.origin.WorldPosition,95)
 local fx=beam.work
 if not visible then
  if fx then
   fx.sparks.Enabled=false;fx.glow.Enabled=false;fx.impact.Enabled=false
   if fx.contact then fx.contact.Transparency=1 end
   if fx.inner then fx.inner.Transparency=1 end
   for _,sphere in ipairs(fx.spheres) do sphere.part.Transparency=1 end
   if not sample.alive then fx.sparks:Clear();fx.glow:Clear();fx.impact:Clear() end
   if not sample.alive or now-fx.lastAt>ENERGY_TAIL then self:destroyMining(beam) end
  end
  return
 end
 if not fx then
  if self.miningCount>=self.maxMining then return end
  self:energyBloom()
  local anchor=part(beam.holder,'OriginalMiningOrigin')
  fx={anchor=anchor,spheres=spheres(anchor,beam.tint or WHITE),lastAt=now,pulseSerial=sample.pulseSerial or 0}
  fx.sparks=particle(anchor,'OriginParticles',beam.tint or WHITE)
  fx.sparks.Brightness=1;fx.sparks.LightEmission=.55
  fx.glow=particle(anchor,'OriginGlow',beam.tint or WHITE)
  fx.glow.Brightness=.8;fx.glow.LightEmission=.4
  fx.glow.Speed=NumberRange.new(0);fx.glow.Lifetime=NumberRange.new(.5,1);fx.glow.Size=NumberSequence.new(.13)
  fx.tip=Instance.new('Attachment');fx.tip.Name='RockContact';fx.tip.Parent=beam.marker
  fx.impact=particle(fx.tip,'CuttingSparks',YELLOW)
  fx.impact.Texture=SPARK;fx.impact.Squash=NumberSequence.new(.55)
  fx.impact.Rotation=NumberRange.new(-180,180);fx.impact.RotSpeed=NumberRange.new(-30,30)
  fx.impact.Lifetime=NumberRange.new(.85,1.35);fx.impact.Speed=NumberRange.new(7,12)
  fx.impact.Drag=10;fx.impact.Acceleration=Vector3.new(0,-.6,0);fx.impact.SpreadAngle=Vector2.new(80,80)
  fx.impact.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12,.02),NumberSequenceKeypoint.new(.06,.16,.02),NumberSequenceKeypoint.new(1,0)})
  fx.impact.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(.7,.45),NumberSequenceKeypoint.new(1,1)})
  -- Reuse the preserved original two-ball contact glows, at the real contact.
  local templates=game:GetService('ReplicatedStorage'):FindFirstChild('MiningFX')
  local template=templates and templates:FindFirstChild('MiningEffect')
  if template and template:IsA('BasePart') then
   fx.contact=template:Clone()
   for _,child in ipairs(fx.contact:GetChildren()) do child:Destroy() end
   fx.contact.Anchored=true;fx.contact.CanCollide=false;fx.contact.CanTouch=false;fx.contact.CanQuery=false;fx.contact.CastShadow=false
   fx.contact.Transparency=1;fx.contact.Parent=anchor
   local inner=template:FindFirstChild('InnerMiningEffect')
   if inner and inner:IsA('BasePart') then
    fx.inner=inner:Clone();fx.inner.Anchored=true;fx.inner.CanCollide=false;fx.inner.CanTouch=false;fx.inner.CanQuery=false
    fx.inner.CastShadow=false;fx.inner.Transparency=1;fx.inner.Parent=anchor
   end
  end
  beam.work=fx;self.miningBeams[beam]=true;self.miningCount+=1
 end
 if fx.key~=sample.key or fx.life~=sample.life then
  -- Already-emitted world-space light belongs to the previous contact. Let it
  -- finish naturally when changing rocks; only a new life invalidates the tail.
  if fx.life~=sample.life then fx.sparks:Clear();fx.glow:Clear();fx.impact:Clear() end
  fx.key=sample.key;fx.life=sample.life
  fx.pulseSerial=sample.pulseSerial or 0
 end
 if fx.contact then fx.contact.Transparency=1 end
 if fx.inner then fx.inner.Transparency=1 end
 fx.lastAt=now
 local origin=beam.origin.WorldPosition
 local direction=point and point-origin or Vector3.new(0,-1,0)
 if direction.Magnitude<.01 then direction=Vector3.new(0,-1,0) end
 direction=direction.Unit;fx.anchor.CFrame=facing(origin,direction)
 local q=charging and math.clamp(progress(now,sample.warmupStart,sample.warmupDuration)/.78,0,1) or 1
 if working and sample.style=='Percussion' then
  local at=(sample.pulseAt or 0)>0 and sample.pulseAt or sample.since
  q=math.clamp(progress(now,at or now,Mining.PULSE_INTERVAL)/.78,0,1)
 end
 local strength=charging and (.25+.75*q) or width
 drawSpheres(fx,now,strength,q,pulse,beam.tint or WHITE)
 local continuous=sample.style~='Percussion'
 fx.sparks.Rate=2;fx.sparks.Enabled=working
 fx.glow.Rate=charging and 1.5 or .8;fx.glow.Enabled=working
 local resonance=sample.style=='Resonance'
 local impactColor=resonance and (beam.tint or WHITE) or YELLOW
 if fx.impactColor~=impactColor then fx.impactColor=impactColor;fx.impact.Color=ColorSequence.new(impactColor) end
 -- Random emission directions give individual sparks variety without a
 -- shared lateral force pushing the whole cloud like wind.
 fx.impact.Acceleration=resonance and Vector3.zero or Vector3.new(0,-.6,0)
 fx.impact.Drag=resonance and 9 or 10
 fx.impact.Rate=continuous and (resonance and 7 or 9) or 0;fx.impact.Enabled=working and continuous
 if working and fx.releaseAt~=sample.since then
  fx.releaseAt=sample.since
  if sample.since and now>=sample.since and now-sample.since<.15 then
   fx.impact:Emit(12);fx.sparks:Emit(5)
  end
 end
 if point and normal then
  beam.marker.CFrame=facing(point+normal*.2,normal)
  if fx.contact then
   fx.contact.CFrame=CFrame.new(point+normal*.05)
   fx.contact.Size=Vector3.one*(.22+.18*width+.08*pulse)
   fx.contact.Color=beam.tint or WHITE;fx.contact.Transparency=working and (.68-.05*pulse) or 1
   if fx.inner then
    fx.inner.CFrame=CFrame.new(point+normal*.06);fx.inner.Size=Vector3.one*(.09+.05*pulse)
    fx.inner.Color=(beam.tint or WHITE):Lerp(WHITE,.25);fx.inner.Transparency=working and .45 or 1
   end
  end
 end
 if sample.pulseSerial~=fx.pulseSerial then
  if working and sample.pulseAt and now-sample.pulseAt<.25 then fx.impact:Emit(16);fx.sparks:Emit(5) end
  fx.pulseSerial=sample.pulseSerial
 end
end
local function backpackPosition(source)
 local owner=Players:GetPlayerByUserId(source:GetAttribute('Owner') or 0)
 local ch=owner and owner.Character
 local torso=ch and (ch:FindFirstChild('UpperTorso') or ch:FindFirstChild('Torso') or ch:FindFirstChild('HumanoidRootPart'))
 return torso and torso.CFrame:PointToWorldSpace(Vector3.new(0,.15,.9))
end
function W:destroyCourier(record)
 if record.courier then
  if record.courier.detailed then self.courierCount=math.max(0,self.courierCount-1) end
  BeamVFX.destroy(record.courier.tetherVFX)
  record.courier.root:Destroy();record.courier=nil
 end
end
function W:destroyDrone(record)
 for _,rocket in ipairs(record.rockets or {}) do rocket.attachment:Destroy() end;record.rockets=nil
 self:destroyCourier(record)
 if record.repair then record.repair.anchor:Destroy();record.repair=nil;self.repairCount=math.max(0,self.repairCount-1) end
 if record.flight then
  for _,object in ipairs(record.flight.objects) do object:Destroy() end
  if record.flight.wisp then self.flightCount=math.max(0,self.flightCount-1) end
  record.flight=nil
 end
end
function W:flight(drone,record,dt,now)
 local root=drone.view.PrimaryPart or drone.emitter
 if not root or not root.Parent then return end
 local source=drone.source
 local powered=source:GetAttribute('State')=='BreakerDive' and source:GetAttribute('MotionPaused')~=true and source:GetAttribute('WorkPaused')~=true
 if powered and not record.rockets then
  record.rockets={}
  for _,side in ipairs({-1,1}) do
   local nozzle=Instance.new('Attachment');nozzle.Name='BreakerRocket';nozzle.Position=Vector3.new(side*.4,.35,0);nozzle.Parent=root
   local jet=particle(nozzle,'RocketExhaust',Color3.fromRGB(255,178,66))
   jet.EmissionDirection=Enum.NormalId.Top;jet.SpreadAngle=Vector2.new(9,9);jet.Speed=NumberRange.new(4,8);jet.Drag=3.5
   jet.Lifetime=NumberRange.new(.16,.32);jet.Acceleration=Vector3.new(0,1.2,0);jet.Rate=20;jet.LightEmission=.7;jet.Brightness=1.4
   jet.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,0)})
   table.insert(record.rockets,{attachment=nozzle,jet=jet})
  end
 end
 for _,rocket in ipairs(record.rockets or {}) do rocket.jet.Enabled=powered and not BeamVFX.reduced() end
 local fx=record.flight
 if not fx then
  fx={objects={},trails={},position=root.Position,life=source:GetAttribute('Life')};record.flight=fx
  local role=source:GetAttribute('Role')
  local span=role=='Medic' and .25 or role=='Courier' and .48 or math.max(.25,root.Size.X*.34)
  for _,side in ipairs({-1,1}) do
   local a=Instance.new('Attachment');a.Name='FlightTrailTop';a.Position=Vector3.new(side*span,-.03,span*.65);a.Parent=root
   local b=Instance.new('Attachment');b.Name='FlightTrailBottom';b.Position=a.Position-Vector3.new(0,.065,0);b.Parent=root
   local trail=Instance.new('Trail');trail.Name='DroneFlightTrail';trail.Attachment0=a;trail.Attachment1=b
   trail.Lifetime=.28;trail.MinLength=.04;trail.FaceCamera=true;trail.LightEmission=.2
   trail.Color=ColorSequence.new(drone.emitter.Color)
   trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.45,.8),NumberSequenceKeypoint.new(1,1)})
   trail.Enabled=false;trail.Parent=root
   table.insert(fx.objects,a);table.insert(fx.objects,b);table.insert(fx.objects,trail);table.insert(fx.trails,trail)
  end
  if self.flightCount<self.maxFlightParticles then
   local a=Instance.new('Attachment');a.Name='HoverExhaust'
   a.Position=(role~='Medic' and role~='Courier' and drone.beam and drone.beam.origin.Position) or Vector3.zero;a.Parent=drone.emitter
   local wisp=particle(a,'FlightWisp',drone.emitter.Color)
   wisp.EmissionDirection=Enum.NormalId.Bottom
   wisp.Lifetime=NumberRange.new(.6,1.1);wisp.Speed=NumberRange.new(.15,.35);wisp.Acceleration=Vector3.new(0,-.12,0);wisp.Drag=2.2
   wisp.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(.55,.12),NumberSequenceKeypoint.new(1,.16)})
   wisp.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.82),NumberSequenceKeypoint.new(1,1)})
   wisp.LightEmission=.15;wisp.Brightness=.8;wisp.Rate=3;fx.wisp=wisp;self.flightCount+=1;table.insert(fx.objects,a)
  end
 end
 local distance=(root.Position-fx.position).Magnitude
 local speed=dt>0 and distance/math.max(dt,1/240) or 0
 local state=source:GetAttribute('State');local alive=not record.events.dead and state~='Destroyed' and state~='Reprinting'
 -- Flight remains visible during healthy storage; only work effects pause.
 local paused=source:GetAttribute('MotionPaused')==true
 local reset=fx.life~=source:GetAttribute('Life') or distance>8 or not alive
 for _,trail in ipairs(fx.trails) do
  if reset then trail:Clear() end
  trail.Enabled=alive and not paused and not BeamVFX.reduced() and speed>.6 and not reset
 end
 if fx.wisp then
  if reset then fx.wisp:Clear() end
  fx.wisp.Enabled=alive and not paused and not BeamVFX.reduced() and cameraNear(root.Position,100)
  fx.wisp.Rate=1+math.min(3,speed*.25)
 end
 fx.position=root.Position;fx.life=source:GetAttribute('Life')
end
function W:repair(drone,record,now)
 local s=drone.source;local charging=s:GetAttribute('State')=='RepairCharge'
 local healing=s:GetAttribute('Healing')==true
 local active=not BeamVFX.reduced() and s:GetAttribute('Role')=='Medic' and not record.events.dead and s:GetAttribute('MotionPaused')~=true and s:GetAttribute('WorkPaused')~=true and (charging or healing) and cameraNear(drone.pos,90)
 local fx=record.repair
 if not active then
  if fx then
   fx.sparks.Enabled=false
   drawSpheres(fx,now,0,0,0,WHITE)
   if now-fx.lastAt>ENERGY_TAIL then fx.anchor:Destroy();record.repair=nil;self.repairCount=math.max(0,self.repairCount-1) end
  end
  return
 end
 local color=Color3.fromRGB(126,233,160)
 if not fx then
  if self.repairCount>=self.maxRepairs then return end
  local anchor=part(self.parent,'RepairCapacitor');fx={anchor=anchor,spheres=spheres(anchor,color),scale=.42,lastAt=now}
  fx.sparks=particle(anchor,'RepairParticles',color);fx.sparks.Brightness=1.2;fx.sparks.LightEmission=.65
  record.repair=fx;self.repairCount+=1
 end
 fx.lastAt=now;fx.anchor.CFrame=facing(drone.emitter.Position,Vector3.new(0,-1,0))
 local q=charging and progress(now,s:GetAttribute('RepairChargeAt') or now,s:GetAttribute('RepairChargeDuration') or .4) or 1
 drawSpheres(fx,now,charging and .3+.7*q or 1,q,healing and .5 or 0,color)
 fx.sparks.Rate=charging and 3+q*4 or 8;fx.sparks.Enabled=true
end
function W:courier(drone,record,now)
 local source=drone.source;local state=source:GetAttribute('State')
 local enabled=source:GetAttribute('Role')=='Courier' and not record.events.dead and cameraNear(drone.pos,200)
 local fx=record.courier
 if not enabled then self:destroyCourier(record);return end
 local parcelUnits=source:GetAttribute('DeliveryUnits') or 0
 local busy=state=='Pickup' or state=='Unload' or parcelUnits>0
 if not busy and not fx then return end
 if fx and not busy and now-fx.lastAt>ENERGY_TAIL then self:destroyCourier(record);return end
 if not fx then
  local detailed=self.courierCount<self.maxCouriers
  local root=Instance.new('Folder');root.Name='CourierWork';root.Parent=self.parent
  local anchor=part(root,'TransferOrigin');local contact=part(root,'BackpackContact')
  local tether=W.newCylinder(root,'PickupTether',GOLD)
  local parcel=part(root,'CourierParcel');parcel.Size=Vector3.new(.62,.42,.5);parcel.Material=Enum.Material.WoodPlanks;parcel.Color=Color3.fromRGB(171,139,79)
  local band=part(root,'ParcelLatch');band.Size=Vector3.new(.65,.07,.53);band.Material=Enum.Material.Metal;band.Color=GOLD
  local drive=part(root,'CourierWake');local trails={}
  if detailed then for _,side in ipairs({-1,1}) do
   local top=Instance.new('Attachment');top.Position=Vector3.new(side*.38,.025,.25);top.Parent=drive
   local bottom=Instance.new('Attachment');bottom.Position=Vector3.new(side*.38,-.025,.25);bottom.Parent=drive
   local trail=Instance.new('Trail');trail.Name='LoadedFlightTrail';trail.Attachment0=top;trail.Attachment1=bottom
   trail.Lifetime=.32;trail.MinLength=.04;trail.FaceCamera=true;trail.LightEmission=.25
   trail.Color=ColorSequence.new(GOLD);trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,1)})
   trail.Enabled=false;trail.Parent=root;table.insert(trails,trail)
  end end
  fx={root=root,anchor=anchor,contact=contact,tether=tether,parcel=parcel,band=band,drive=drive,trails=trails,spheres=detailed and spheres(anchor,GOLD) or {},detailed=detailed,sale=source:GetAttribute('CourierSaleSerial') or 0,loadId=source:GetAttribute('DeliveryId') or '',lastAt=now}
  if detailed then
   fx.sparks=particle(anchor,'CourierSparks',GOLD);fx.sparks.Brightness=1.2;fx.sparks.LightEmission=.65;self.courierCount+=1
  end
  record.courier=fx
 end
 if busy then fx.lastAt=now end
 local paused=source:GetAttribute('MotionPaused')==true or source:GetAttribute('WorkPaused')==true
 local pivot=drone.view:GetPivot();local mount=pivot:PointToWorldSpace(Vector3.new(0,-.52,0))
 for _,trail in ipairs(fx.trails) do trail.Enabled=not BeamVFX.reduced() and state=='Deliver' and parcelUnits>0 and not paused and now-(source:GetAttribute('SnapshotAt') or 0)<.5 end
 local backpack=backpackPosition(source)
 local sale=source:GetAttribute('CourierSaleSerial') or 0;local sell=source:GetAttribute('SellPosition')
 if sale>fx.sale and typeof(sell)=='Vector3' and now-(source:GetAttribute('CourierSaleAt') or 0)<.7 then self:burst(sell+Vector3.new(0,1,0),Vector3.yAxis,GOLD,18,now) end
 fx.sale=sale
 local pickup=state=='Pickup' and backpack~=nil and (backpack-mount).Magnitude<=6 and not paused and now-(source:GetAttribute('SnapshotAt') or 0)<.5
 local unload=state=='Unload' and typeof(sell)=='Vector3'
 local launch=source:GetAttribute('CourierLaunchAt') or 0
 local pickupAt=source:GetAttribute('CourierPickupAt') or 0
 local q=pickup and progress(now,pickupAt,source:GetAttribute('CourierPickupHold') or .55) or 1
 local loadId=source:GetAttribute('DeliveryId') or ''
 if loadId~='' and loadId~=fx.loadId and launch>0 and now-launch<.5 then self:burst(mount,Vector3.new(0,-1,0),GOLD,8,now) end
 fx.loadId=loadId
 if pickup then drone.view:PivotTo(pivot*CFrame.new(0,-.10*q,0))
 elseif state=='Launch' and launch>0 then
  local t=progress(now,launch,source:GetAttribute('CourierLaunchHold') or .25)
  drone.view:PivotTo(pivot*CFrame.new(0,math.sin(t*math.pi)*.18,0))
 end
 pivot=drone.view:GetPivot();mount=pivot:PointToWorldSpace(Vector3.new(0,-.52,0))
 fx.drive.CFrame=pivot;fx.anchor.CFrame=facing(mount,Vector3.new(0,-1,0))
 drawSpheres(fx,now,pickup and .3+.7*q or unload and .7 or 0,q,0,GOLD)
 if pickup then
  fx.tetherVFX=fx.tetherVFX or BeamVFX.new(fx.root,'Courier',GOLD)
  if fx.tetherVFX then
   fx.tether.Transparency=1;BeamVFX.draw(fx.tetherVFX,mount,backpack,now,.45+.55*q,nil,nil)
  else W.drawCylinder(fx.tether,mount,backpack,.045+.025*q,.5-.2*q) end
 else
  fx.tether.Transparency=1;BeamVFX.destroy(fx.tetherVFX);fx.tetherVFX=nil
 end
 if fx.sparks then
  fx.sparks.Rate=pickup and 4+q*5 or unload and 6 or 0;fx.sparks.Enabled=not paused and not BeamVFX.reduced() and (pickup or unload)
  if paused then fx.sparks:Clear() end
 end
 local parcelScale=math.clamp((math.max(1,parcelUnits)/8)^(1/3),1,1.6)
 fx.parcel.Size=Vector3.new(.62,.42,.5)*parcelScale;fx.band.Size=Vector3.new(.65,.07,.53)*parcelScale
 fx.parcel.Transparency=parcelUnits>0 and 0 or 1
 fx.band.Transparency=fx.parcel.Transparency
 if parcelUnits>0 then
  local position=mount
  local transfer=launch>0 and progress(now,launch,source:GetAttribute('CourierLaunchHold') or .25) or 1
  if transfer<1 and backpack and (backpack-mount).Magnitude<=6 then
   local t=transfer*transfer*(3-2*transfer)
   position=backpack:Lerp(mount,t)+Vector3.new(0,math.sin(t*math.pi)*.35,0)
  elseif unload then
   local t=paused and (fx.unloadProgress or 0) or progress(now,source:GetAttribute('CourierUnloadAt') or now,source:GetAttribute('CourierUnloadHold') or .65)
   fx.unloadProgress=t
   -- Hold the parcel just above the converter until the server confirms sale.
   local finish=sell+Vector3.new(0,1.25,0)
   position=mount:Lerp(finish,t*.9)+Vector3.new(math.sin(t*math.pi)*.18,math.sin(t*math.pi)*.3,0)
  end
  fx.parcel.CFrame=CFrame.new(position)*pivot.Rotation
  fx.band.CFrame=fx.parcel.CFrame
 end
end
-- A monochrome beam with alternating opaque/clear bands. Shift the sequence
-- along its normalized length, so the pulse remains fast at every frame rate.
-- Two broad bands give the ramp more scale without hiding the physical core.
-- Ten or fewer keys stay inside Roblox's twenty-key NumberSequence limit.
function W.orbitalTransparency(now,minimum)
 local phase=(now*7)%1
 local function opacity(t)
  local x=(t*2+phase)%1
  if x<.22 then return .04 elseif x<.32 then return .04+.96*(x-.22)/.1
  elseif x<.88 then return 1 else return 1-.96*(x-.88)/.12 end
 end
 local keys={NumberSequenceKeypoint.new(0,opacity(0))}
 for i=-1,4 do for _,point in ipairs({{0,.04},{.22,.04},{.32,1},{.88,1}}) do
  local t=(i+point[1]-phase)/2
  if t>0 and t<1 then table.insert(keys,NumberSequenceKeypoint.new(t,point[2])) end
 end end
 table.insert(keys,NumberSequenceKeypoint.new(1,opacity(1)))
 if minimum then
  for i,key in ipairs(keys) do keys[i]=NumberSequenceKeypoint.new(key.Time,minimum+(1-minimum)*key.Value) end
 end
 return NumberSequence.new(keys)
end
function W:orbital(now)
 if now>=self.scanAt then
  self.scanAt=now+.2
  local source=workspace:FindFirstChild('DroneRoleClientEffects')
  if source then for _,group in ipairs(source:GetChildren()) do
   local position=group:GetAttribute('Position')
   if group:GetAttribute('OrbitalBurn') and not self.orbitals[group] and not group:GetAttribute('EndedAt')
    and typeof(position)=='Vector3' and cameraAbove(position,180) then
    local holder=part(self.parent,'OrbitalEnergyRamp')
    local bottom=Instance.new('Attachment');bottom.Parent=holder
    local top=Instance.new('Attachment');top.Parent=holder
    local ramp=Instance.new('Beam');ramp.Name='DescendingWhiteClearEnergy'
    ramp.Attachment0=bottom;ramp.Attachment1=top;ramp.FaceCamera=true;ramp.Segments=48
    ramp.Color=ColorSequence.new(Color3.new(1,1,1));ramp.LightEmission=1;ramp.LightInfluence=0;ramp.Brightness=.7
    ramp.Width0=.72;ramp.Width1=.72;ramp.Parent=holder
    -- The local physical cylinder stays visible through the clear ramp bands.
    self.orbitals[group]={holder=holder,bottom=bottom,top=top,ramp=ramp,
     vfx=BeamVFX.new(holder,'Orbital',Color3.fromRGB(171,111,255))}
    self:energyBloom()
   end
  end end
 end
 for group,record in pairs(self.orbitals) do
  local position=group:GetAttribute('Position')
  local ended=group:GetAttribute('EndedAt')
  local strength=ended and (1-progress(now,ended,.48))^2 or 1
  if not group.Parent or typeof(position)~='Vector3' or strength<.002 then
   BeamVFX.destroy(record.vfx);record.holder:Destroy();self.orbitals[group]=nil
  else
   local camera=workspace.CurrentCamera
   local contactAt=group:GetAttribute('ContactAt')
   -- A yielding save or a stalled contact stream must not leave a cosmetic
   -- strike drilling after authoritative work has paused.
   record.ramp.Enabled=ended~=nil or contactAt==nil or now-contactAt<.3
   local height=math.max(260,(camera and camera.CFrame.Position.Y or position.Y)-position.Y+180)
   record.holder.CFrame=CFrame.new(position)
   record.bottom.Position=Vector3.zero;record.top.Position=Vector3.new(0,height,0)
   record.ramp.Width0=.72*strength;record.ramp.Width1=record.ramp.Width0
   record.ramp.Transparency=W.orbitalTransparency(now,.7)
   if ended then
    BeamVFX.after(record.vfx,position+Vector3.yAxis*.12,position+Vector3.yAxis*height,now,now-ended)
   elseif record.ramp.Enabled then
    BeamVFX.draw(record.vfx,position+Vector3.yAxis*.12,position+Vector3.yAxis*height,now,strength,nil,now-(group:GetAttribute('StartedAt') or now))
   else BeamVFX.hide(record.vfx,true) end
  end
 end
end
function W:update(now)
 self:orbital(now)
 for i=#self.bursts,1,-1 do
  local item=self.bursts[i]
  if now>=item.untilAt then item.part:Destroy();table.remove(self.bursts,i) end
 end
end
function W:destroy()
 for beam in pairs(self.miningBeams) do self:destroyMining(beam) end
 for _,item in ipairs(self.bursts) do item.part:Destroy() end;self.bursts={}
 for _,record in pairs(self.orbitals) do
  BeamVFX.destroy(record.vfx);record.holder:Destroy()
 end;self.orbitals={}
 if self.ownsBloom and self.bloom then self.bloom:Destroy() end;self.bloom=nil
end
return W

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
 },
}
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
return Catalog

end)()
local CrystalGeometry = (function()
-- Recovered original crystal collision surface; do not replace with a primitive.
-- Generated by tools/recover_crystal_geometry.py using manifold3d 3.5.4.
-- Source: immutable assets/mining-away-base.rbxl / crystal PhysicalConfigData / SSTR 8.
-- Original rendered mesh is cloud-only; this is its authored convex collision approximation.
-- 36 closed hulls (471 vertices / 798 triangles) were boolean-unioned OFFLINE.
-- Centered coordinates span [-.5,.5] on each axis; triangle indices are one-based.
-- Hull dilation .001 stud; weld .003; simplify .001; point-contact inset .001 normalized.
-- Exact original bounds restored. No coincident points or pinched vertex fans.
local G={
 originalSize={3.1349997520446777,6.5669014453887939,4.4872307777404785},
 sourceSha256="7a126b8c311857fcfae37fbe19508840409de4460c8454b2edcda33e6efb4be9",
 sourceHullCount=36,
 sourceVertexCount=471,
 sourceTriangleCount=798,
 closedComponents=1,
 hullDilation=0.001,
 weldDistance=0.003,
 simplifyTolerance=0.001,
 pointContactInset=0.001,
 vertices={
  {-0.25129108569077285,-0.4346004272870661,-0.25881598887005169},
  {-0.28839656543465486,-0.25088657003062104,-0.45884381267858565},
  {-0.3528337497361777,-0.33895782548245462,-0.28500693444298586},
  {-0.27060836869774429,-0.33895818843292108,-0.3629513588417308},
  {-0.41167731240762417,-0.45897556359765068,-0.00022275532920832582},
  {-0.40875913573754835,-0.45894464021790965,-7.0140770626970537e-05},
  {-0.40194459735644933,-0.47209527928838768,-0.062189883233476011},
  {-0.42455275233628559,-0.35396934788943757,-0.13901927740098119},
  {-0.44990169508245886,-0.31257506496178183,-0.00022275532920832582},
  {-0.34513872701496962,-0.41452139046759234,-0.19555365555134105},
  {-0.34835699798085218,-0.38291842227319578,-0.23252036544519847},
  {-0.29022240190807835,-0.42627093185245674,-0.23257254504413835},
  {-0.32696419259814019,-0.35382071967342876,-0.23252899565876359},
  {-0.31577548629754321,-0.33872397649692476,-0.23257254504413835},
  {-0.45869221208751093,-0.18150074863977961,-0.25011139614124828},
  {-0.45295333144189437,-0.18296481823132132,-0.25004883373152698},
  {-0.46984354435494013,-0.12439676271412761,-0.28703936301482408},
  {-0.46696017664712325,-0.1178335475769445,-0.28849470912143999},
  {-0.4126052220587586,-0.00015225061407475997,-0.31592986594543221},
  {-0.43653604160233406,-0.019533853460709107,-0.25011139614124828},
  {-0.4229308675009012,-0.0001522505963525692,-0.27148530171067298},
  {-0.36343649883857387,-0.23484127395758903,-0.40826271517246776},
  {-0.36330588922800183,-0.23612377757829214,-0.40674446144758797},
  {-0.36301548520007287,-0.23581928028446897,-0.404273963235184},
  {-0.28648361155295776,-0.15093059229269604,-0.5},
  {-0.30421201363690498,-0.23581928028446897,-0.32188378389775285},
  {-0.29865776109514769,-0.23581928028446897,-0.31637005994626005},
  {-0.34298224340113659,-0.00015225061407475997,-0.31591701356584601},
  {-0.35399566985629749,-0.0001522505963525692,-0.25098148099563244},
  {-0.35264712657716712,-0.00015225061407475997,-0.25237471611908269},
  {-0.31622982685733364,-0.00015225061407475997,-0.29059102782816348},
  {-0.31714061703521734,-0.00015225061407475997,-0.28905843467151388},
  {-0.448025317211869,-0.23612377757829214,-0.21478778596942896},
  {-0.46401482922593912,-0.23612377757829214,-0.05767709808989209},
  {-0.48954385895043684,-0.097527285617953471,-0.1616057146990541},
  {-0.33807395171632126,-0.23868680673965625,-0.23257254504413835},
  {-0.33844176388412084,-0.23693557073906404,-0.23254097173974164},
  {-0.33841041301745745,-0.23612377757829214,-0.23256271987792576},
  {-0.3190756685277808,-0.24441790348994658,-0.00022275532920832582},
  {-0.30233669979572914,-0.23581929843199229,-0.00022275532920832582},
  {-0.25295344164494082,-0.23581929843199229,-0.00022275532920832582},
  {-0.25819684559359957,-0.204928674970562,-0.00022275532920832582},
  {-0.2988503124180365,-0.13335909858202874,-0.00022275532920832582},
  {-0.3688479624330735,-0.00015225054318599698,-0.2496658646852617},
  {-0.35750989300348218,-0.00015225056090818772,-0.24970341275289579},
  {-0.35465829417388417,-0.0014358752873977899,-0.24967016651479262},
  {-0.2520521137286319,-0.048573946747689792,-0.24979250311139115},
  {-0.25258747252809055,-0.048031013681817079,-0.249791626812783},
  {-0.29526314625441508,-0.00015224831018996319,-0.0036419953501205947},
  {-0.29159218242052398,-0.00039933030972482498,-0.00083707161517717677},
  {-0.2922474375767487,0.0008475612543737375,-0.00011029790545971532},
  {-0.16627359646730075,-0.47083221166516265,-0.10117225916897789},
  {-0.08621510183027499,-0.42616676506858731,-0.23212701358815177},
  {-0.084576430030831776,-0.43586581779327643,-0.23243215138531126},
  {-0.085864162128897886,-0.4358244414401018,-0.23237054493770792},
  {-0.074858397635544235,-0.44505245704943991,-7.0140770626970537e-05},
  {-0.063557203475332877,-0.39262484289235372,-8.542271222116709e-05},
  {-0.11292122359430504,-0.35393116550036768,-0.23212701358815177},
  {-0.10942128884210875,-0.34053891030437788,-0.23212701358815177},
  {-0.10949380434672736,-0.33873642569792378,-0.23238902687198892},
  {-0.10997787122827224,-0.35380507650832504,-2.6518916288261953e-05},
  {-0.094584804702341194,-0.36647498768599807,-2.6276865767177622e-05},
  {-0.18859085340555154,-0.23612377757829214,-0.43690501316094293},
  {-0.18562323736877381,-0.23872333770410384,-0.43497970545532527},
  {-0.24516645638152021,-0.23243226282666041,-0.25008351391280714},
  {-0.24404557739594154,-0.23581928028446897,-0.24796789008220105},
  {-0.24169677046552274,-0.23581928028446897,-0.24522425224908675},
  {-0.24169677046552274,-0.21716300929345558,-0.2496658646852617},
  {-0.23633216216629094,-0.2497717132303684,-3.1628357907987132e-06},
  {-0.23710778260754239,-0.24886210491888983,-0.00022275532920832582},
  {-0.24167974599489828,-0.23581929843199229,-0.01037048368310748},
  {-0.24167974599489828,-0.066561604000062571,-0.24981552586573258},
  {-0.2402186056031333,-0.066704801569717212,-0.24981685359089645},
  {-0.24167974599489828,-0.055873402369173687,-0.24396724172744905},
  {-0.24175438005808234,-0.00015224983429836721,-0.14299060958411505},
  {-0.24167974599489828,-0.00015224981657617647,-0.14169099236196889},
  {-0.10387789510053216,-0.23572768973426184,-0.2496658646852617},
  {-0.10026523023202454,-0.23581928028446897,-0.24975992073586989},
  {-0.085939774719132334,-0.23581928028446897,-0.24994479318768648},
  {-0.082767466023830769,-0.23646055931610549,-0.2323875132653021},
  {-0.0758540299088028,-0.23581928028446897,-0.24263067391399251},
  {-0.08868097099676224,-0.00015225061407475997,-0.17888361469245795},
  {-0.087353945812478045,-0.00015225061407475997,-0.1791947803618614},
  {-0.086698418191072477,-0.0001522505963525692,-0.17799676066925421},
  {-0.42658561853283872,-0.43887917774588087,0.095142262564767766},
  {-0.43986736569345725,-0.36693147048764463,0.040626936155220207},
  {-0.44419070720791004,-0.30933696608035527,0.00022275532920832582},
  {-0.47310319846481835,-0.25007597460638836,0.17728078487463991},
  {-0.46522679672956879,-0.25007630126180819,0.21342994799884732},
  {-0.32349842079034435,-0.3750380780408108,0.21343010732586698},
  {-0.27255341446658954,-0.48221945589442267,0.20382428131033514},
  {-0.25283005223396393,-0.4837868211887143,0.21343010732586698},
  {-0.37313980107666095,-0.36784694044915628,0.21343010732586698},
  {-0.37405277631494843,-0.36689597393202644,0.21298792173729333},
  {-0.45356864445160722,-0.25007615608162159,0.26628651416804899},
  {-0.26075405028496607,-0.3750380780408108,0.25881561710700585},
  {-0.5,-0.20938879177745881,0.1995697320724972},
  {-0.48885444389224697,-0.14657143923180227,0.2496658646852617},
  {-0.46094677641268716,-0.13057125790174923,0.2496658646852617},
  {-0.32045195257377695,-0.24968097561375741,0.00022275532920832582},
  {-0.32128512560601225,-0.2497970471729262,0.001147810935707405},
  {-0.31966696487357699,-0.24537068475940865,0.00022275532920832582},
  {-0.25928762774718145,-0.20134786011119568,0.00022275532920832582},
  {-0.29585075649831266,-0.12517841283866138,0.00022275532920832582},
  {-0.29729337137795836,-0.12480973682860924,0.00022275532920832582},
  {-0.29307525477234292,-0.00076924218079477363,0.00022275532920832582},
  {-0.29183415946350422,-0.0033291192024243348,0.00022275532920832582},
  {-0.29273788144599472,-0.00015224799119052979,0.028622810302382503},
  {-0.27482595328865272,-0.00015224820385681872,0.01129110839585414},
  {-0.29576175803803922,-0.12480973682860924,0.13828577563420386},
  {-0.47478493495474189,-0.21900955608653597,0.28022946064935955},
  {-0.48497404262243426,-0.12511251010771679,0.26755199557623222},
  {-0.48108512911730933,-0.12511251010771679,0.28024852678271267},
  {-0.48214862651663143,-0.10896057011388188,0.27980620842162263},
  {-0.46659928067051487,-0.12480973682860924,0.25770141670399344},
  {-0.16533044839491542,-0.38574529827614135,0.21321014309796943},
  {-0.15006438137975886,-0.36693147048764463,0.21307204640367583},
  {-0.0039125534242518602,-0.4534917812951953,0.027315988511565921},
  {-0.0039471450680032601,-0.38315136388255955,0.24833882993848172},
  {-0.003767433053169322,-0.36662702763639143,0.079495200751513687},
  {-0.0037674294905708375,-0.36567464561244245,0.080074666483405194},
  {-0.0038970044631663797,-0.36693147048764463,0.08044401970811503},
  {-0.0038559140460128882,-0.36625903215846389,0.080897358188065149},
  {-0.012796275427737924,-0.25007615608162159,0.14455476276790971},
  {-0.003812960686735224,-0.25010727908411917,0.15034930059155999},
  {-0.0029868217083243048,-0.25007615608162159,0.14986384443989595},
  {-0.0038217644613567697,-0.2503805081952582,0.15136110682993509},
  {-0.023781983679156828,-0.25007615608162159,0.17499472096474847},
  {-0.05635741994451695,-0.25039007194004903,0.21307204640367583},
  {-0.023781983679156828,-0.25007615608162159,0.22023424736412034},
  {-0.0039472094916591875,-0.25039869201362702,0.22468673386938731},
  {-0.0039441619855389281,-0.49643451979784092,0.29049891025629448},
  {-0.048804568653495854,-0.5,0.31279624867718742},
  {-0.048804601904415046,-0.3750380780408108,0.3697168620777157},
  {-0.020551317245613938,-0.37503804174576416,0.3552653437496382},
  {-0.04880461615480898,-0.25007615608162159,0.42663750203274725},
  {-0.023782021680207328,-0.25007615608162159,0.41387660271032256},
  {-0.24899033108871263,-0.00015224822157900946,0.028211514239746164},
  {-0.17475708398482967,-0.12480973682860924,0.24967879672835774},
  {-0.16239121914286198,-0.087316046268780284,0.24968001823550848},
  {-0.024056332263249085,-0.24977167693532176,0.15058833095281063},
  {-0.024091628113967582,-0.12490733420903602,0.19770844727428113},
  {-0.02378198130409117,-0.096118221169601351,0.24368844599754064},
  {-0.02378198130409117,-0.096623910980736083,0.24396246191685914},
  {-0.024419536803675399,-0.086943668163970422,0.24985222418926181},
  {-0.024091656614755458,-0.00029406564018505355,0.17550653246091522},
  {-0.02378198130409117,-0.0008144942353076472,0.17696972542324957},
  {-0.15938794862045166,-0.051477899819065566,0.27143062598842499},
  {-0.22770162958384821,-0.074799731191625543,0.41285818440063138},
  {-0.04880461615480898,-0.12511419782738575,0.48355819509678533},
  {-0.048804606654546355,-0.089018093407407656,0.5},
  {-0.023781983679156828,-0.086775567655436897,0.48812190513902931},
  {-0.39040489435289949,0.048341540490264054,-0.32713525557487899},
  {-0.42315647973772585,0.00015221431902811555,-0.27245082344983573},
  {-0.36007253184507032,0.00012146543197715742,-0.32463833563171413},
  {-0.29040988009072521,0.12511416153233912,-0.13995800564633715},
  {-0.28728081659089383,0.21955770202848299,-0.14746055567528685},
  {-0.086631412838776511,0.000142483604617219,-0.17882939039676571},
  {-0.087074638091295398,0.010826431316034073,-0.17833814536338721},
  {-0.08663181184980677,0.12472050545643398,-0.1877289462886311},
  {-0.087074638091295398,0.12489516629464849,-0.18648675317982211},
  {-0.087074638091295398,0.2382597047782683,-0.1800271312670885},
  {-0.086735972729230129,0.2497716406402751,-0.17976834435539951},
  {-0.059548102147735774,0.21925155331003748,-0.20083204021753873},
  {-0.00035126682956086139,0.25007611978657496,-0.20083204021753873},
  {-0.077271374089865341,0.5,-0.069540508310550461},
  {-0.29163237388534369,0.00015221866096484793,0.028211514239746164},
  {-0.29174390696856423,0.00015223246655143776,0.11690945360498095},
  {-0.28740496602288074,0.12454064535278767,0.028211514239746164},
  {-0.28847826769323209,0.125112210673582,0.028652325632775224},
  {-0.26615578561053743,0.24951372803882002,0.028211514239746164},
  {-0.28441188928226729,0.22818848264528752,0.077900987870009125},
  {-0.024419536803675399,0.0001522132556966709,0.1761517006725406},
  {-0.15637678337979974,0.00015221431902811555,0.43562038595589681},
  {-0.12461955248290883,0.00015221431902811555,0.33370693749144281},
  {-0.04880459715428373,0.00015222339278977667,0.48674409818198311},
  {-0.023781983679156828,0.0001520779113259564,0.47515512875269567},
  {-0.048804611404677671,0.11273542736637081,0.46950486154535098},
  {-0.21501938699593412,0.31924591305978894,0.028211514239746164},
  {-0.031431604645278811,0.37819389605149456,0.028656966032222935},
  {0.0052166595218358213,-0.4417705863417602,-0.26189235462923061},
  {0.063181710345200787,-0.4456829020096531,-0.28196046905449718},
  {0.0051238573939137973,-0.33895818843292108,-0.31218642450942413},
  {0.0050714135691567056,-0.33840639483878632,-0.311236091946136},
  {0.0053639349681182591,-0.39870578759724939,-0.17188228091286734},
  {0.074784789600723725,-0.3987195434199276,-0.18820271845885311},
  {0.005363472424081691,-0.40648407015847032,-0.061337782416436427},
  {0.0053517544438998468,-0.35393116550036768,-0.17511754881965763},
  {0.0052869032761541663,-0.35394815158219728,-0.094593128714244759},
  {0.18944306496408786,-0.43129416630804135,-0.19625347293071113},
  {0.21662861748150167,-0.39609229017352626,-0.19634329353804661},
  {0.21858472155604269,-0.42866375539258195,-0.17806744875697839},
  {0.16004347624185722,-0.42290779653534016,-0.00022275532920832582},
  {0.16060917888014095,-0.42234983278327587,-0.00022275532920832582},
  {0.19442141158550186,-0.43274331863541221,-0.058447756245380178},
  {0.24317886843663905,-0.4351545800592328,-0.054119382169118407},
  {0.24317886843663905,-0.39178337853095002,-0.029315955862804142},
  {0.17380318161515257,-0.36612535750167258,-8.2241863930888079e-05},
  {0.24357368035081961,-0.33820285221720453,-0.092236781672804122},
  {0.2433558013277719,-0.33708057307991307,-0.092525210048776368},
  {0.1901747371904349,-0.36567486338272231,-0.00022275532920832582},
  {0.19278634038559361,-0.2999610844509879,-1.6868767656006245e-05},
  {0.24313955634989573,-0.2641452776024828,-0.00022275532920832582},
  {0.0052376996347187023,-0.23612795150865623,-0.36188543452567656},
  {0.0043591916461188651,-0.23581928028446897,-0.35958979771735367},
  {0.005102017477671153,-0.23594560519431479,-0.3606119336575036},
  {0.0055468464932744597,-0.23452525298645624,-0.35980106534542788},
  {0.0055468464932744597,-0.222613109792625,-0.36633676591005099},
  {0.0055468464932744597,-0.222613109792625,-0.36555348772688034},
  {0.0055468464932744597,-0.21051535373025426,-0.33696318345582216},
  {0.0049092945562887137,-0.20956952296222459,-0.33528937345074389},
  {0.0046679715570307227,-0.11786070534559617,-0.41880904858507517},
  {0.0049092945562887137,-0.11735294671680271,-0.41912085156255724},
  {0.0049092945562887137,-0.019508821220726547,-0.41220568714610151},
  {0.023208619079065823,-0.00015225061407475997,-0.41468197424021991},
  {0.02558861774674899,-0.00015225061407475997,-0.38092854512443919},
  {0.074784813351380292,-0.12171716293670336,-0.44251353668913568},
  {0.095435220711241345,-0.00015225061407475997,-0.40711885338929465},
  {0.0032696816370791754,-0.11783395589621926,-0.250058127807674},
  {0.0046083820503634004,-0.11783395589621926,-0.25005921654230839},
  {0.0053208661212730563,-0.090576620857841406,-0.26792808700614862},
  {0.0049587852837853852,-0.02375893261929846,-0.35343300335999439},
  {0.11957284197164346,-0.089276441549422478,-0.2554302897021955},
  {0.077537348192453434,-0.00015225061407475997,-0.37453400829923822},
  {0.2060344566165187,-0.222613109792625,-0.29404226351010809},
  {0.19917120088867737,-0.10810744596874365,-0.35945699864646385},
  {0.059959929032278168,-0.23629940930900437,-0.19594379431349121},
  {0.056270620795041255,-0.22575163321358266,-0.19621206118285017},
  {0.055637893803936314,-0.22291758893892483,-0.1968590749324533},
  {0.055712689371584988,-0.22370448369769871,-0.19622739640849282},
  {0.0055468458995080461,-0.23582267387133021,-0.18359721162845066},
  {0.0052546617598696896,-0.23611693596199967,-0.17207141536245993},
  {0.0055468458995080461,-0.23500173435880389,-0.17260181501092081},
  {0.0055468458995080461,-0.22452161223032735,-0.18440420298304791},
  {0.0055468458995080461,-0.22291758893892483,-0.18452618109385222},
  {0.0055468458995080461,-0.22266005743545952,-0.18073087871294358},
  {0.026539309027658761,-0.22291758893892483,-0.16663455342070332},
  {0.0049092945562887137,-0.16407186724113981,-0.22482019680285906},
  {0.0055468458995080461,-0.16412538428741699,-0.22432742488554214},
  {0.0055468458995080461,-0.16286963011609079,-0.22127845009649375},
  {0.0055468458995080461,-0.16144757204103996,-0.22131739227554992},
  {0.0055468458995080461,-0.15908432896392993,-0.22111771568815625},
  {0.11960016472695371,-0.14165914058628623,-0.22117762264754984},
  {0.0049092945562887137,-0.11984509165207032,-0.24994479318768648},
  {0.0055468458995080461,-0.016839056266722715,-0.19786343263265913},
  {0.0051787130978448769,-0.00015225061407475997,-0.19957491020063628},
  {0.0072814276002845825,-0.00015225061407475997,-0.20087228356725551},
  {0.038468610676273537,-0.00015225061407475997,-0.20818627006843307},
  {0.047091628550979661,-0.00015225061407475997,-0.20090661853999306},
  {0.1560251121582005,-0.22291758893892483,-0.22102136267301453},
  {0.15406219639535715,-0.222613109792625,-0.22127845009649375},
  {0.15555306310887659,-0.22162780816136951,-0.22117762264754984},
  {0.13892435442485371,-0.22291758893892483,-0.1961199436109812},
  {0.2433558013277719,-0.22401593149295429,-0.043961232443357388},
  {0.24327176200458886,-0.22291758893892483,-0.043361362895010185},
  {0.24293611772603843,-0.22291758893892483,-0.023307803656852512},
  {0.24232922194901155,-0.017602853765188251,-0.00022275532920832582},
  {0.23842297996485814,-0.00015225061407475997,-1.6541098959254995e-05},
  {0.27420397109457695,-0.39067710550922874,-0.00022275532920832582},
  {0.36786738332594465,-0.44260798565793974,-0.044926521830616468},
  {0.38201152632663377,-0.43783250119074973,-0.00022275532920832582},
  {0.41870731674506412,-0.36597897957855569,-0.00022275532920832582},
  {0.46536322050086754,-0.26942384771121075,-0.00022275532920832582},
  {0.30209630515025959,-0.22291758893892483,-0.13289675163010128},
  {0.32811600443882671,-0.17190836705717838,-0.1507798287531949},
  {0.25242887514382445,-0.22291758893892483,-0.057319541703263199},
  {0.25810619408762936,-0.23722179347690178,-0.00022275532920832582},
  {0.2514325256007377,-0.22291758893892483,-0.015321696123223092},
  {0.25212062962268528,-0.22266412248068368,-0.014831310791888215},
  {0.26767195152342793,-0.22264994926496906,-0.00022275532920832582},
  {0.25250808833359389,-0.20372072137566646,-0.052802033177408829},
  {0.26230595618585278,-0.16332411669017194,-0.00022275532920832582},
  {0.25443766767488518,-0.076333264965563807,-0.00022275532920832582},
  {0.25213588704446144,-0.050884997547725172,-0.00022275532920832582},
  {0.25250808833359389,-0.01985390545045982,-0.0090083737568110965},
  {0.25263573386222687,-0.018419074921650791,-0.0083936859658069341},
  {0.46745297427002069,-0.17979401036637346,-0.13959754154159937},
  {0.45131309209911796,-0.22291762523397149,-0.1241553145280006},
  {0.48160046136315393,-0.22291762523397149,-0.020932246091947198},
  {0.5,-0.17021859671807849,-0.044904242602366813},
  {0.44179154888557737,-0.051370407501547345,-0.12768011946127497},
  {0.090117980721459059,-0.45344768281352232,0.027045728394804708},
  {0.096604000020976577,-0.25007617422914491,0.20145174266052118},
  {0.10908583456881082,-0.25007615608162159,0.20168649774674419},
  {0.11447809813254478,-0.25007615608162159,0.19858497159571004},
  {0.12205199250528082,-0.25007615608162159,0.23986077367713696},
  {0.17349761516807372,-0.48163590413447405,0.20142820209336584},
  {0.17322839672579909,-0.48095362984765261,0.20140444909018429},
  {0.17558176378227799,-0.4822194921894693,0.20382434769659336},
  {0.15107738488322772,-0.39360125223718129,0.20152305477907237},
  {0.14827629895000818,-0.3832680887525679,0.20151666842103419},
  {0.1937155610729703,-0.29913328517464577,2.015903009467663e-05},
  {0.24293611772603843,-0.26072457834138824,2.0160603850943857e-05},
  {0.24374662313164985,-0.259818254731631,0.00022275532920832582},
  {0.13473623014834621,-0.36528073547121076,0.20145174266052118},
  {0.13517227320232039,-0.36597912475874228,0.20140444909018429},
  {0.14314966272927648,-0.36567464561244245,0.20168651102399582},
  {0.15002586731507606,-0.25007615608162159,0.32292955334581963},
  {0.11626527803734607,-0.24977169508284508,0.24406618380666029},
  {0.074875298602754575,-0.12478296015794733,0.24402048350652003},
  {0.065663815460514585,-0.096951274153945222,0.24402186434069045},
  {0.19620003175367781,-0.00015225052546380624,0.028211514239746164},
  {0.20287850737345783,-0.00015225061407475997,0.023746631760418049},
  {0.23889362297531352,-0.0028479739165828766,4.0375843462720104e-05},
  {0.062416359687847207,-0.051477872597780583,0.27143059943392173},
  {0.13073025440715283,-0.074495274729729846,0.41285818440063138},
  {0.2519582321333691,-0.25007615608162159,0.0026893695565259868},
  {0.40921294428263177,-0.43024730827767699,0.073378835625394129},
  {0.42567769743426787,-0.36597912475874228,0.023428455702149395},
  {0.43165169057933439,-0.36567464561244245,0.044144219525441286},
  {0.45089644858142458,-0.25007615608162159,0.00087833594017785565},
  {0.25656152738686311,-0.24981827977521315,0.00022275532920832582},
  {0.25715103768328573,-0.23939884296472605,0.00022275532920832582},
  {0.2619782541268571,-0.15446079370951674,0.00022275532920832582},
  {0.26364243413144911,-0.12517841283866138,0.00022275532920832582},
  {0.37303545019198509,-0.15183948377700338,0.00022275532920832582},
  {0.26560636642239338,-0.12480973682860924,0.00022275532920832582},
  {0.27079622689089616,-0.12480973682860924,0.0051009296339918457},
  {0.25580298841781185,-0.086187751227507547,0.00022275532920832582},
  {0.26412533248069109,-0.085398460995655151,0.00022275532920832582},
  {0.26351609963905842,-0.081799135662500203,0.00022275532920832582},
  {0.25277343066871738,-0.045340284935715486,0.00022275532920832582},
  {0.38639076738637362,-0.1564784353524788,0.00022272784114829266},
  {0.38237268831059568,-0.15430802785819045,0.00022275532920832582},
  {0.45179855551926879,-0.24977169508284508,0.0002227363728197558},
  {0.023374291783922075,0.00015221431902811555,-0.4169059935532039},
  {0.058910093010611182,0.037989746304520011,-0.4259517850946174},
  {0.062671113980274876,0.00015221431902811555,-0.42987555816238165},
  {0.081202164752642428,0.00015221431902811555,-0.41819771081062507},
  {0.095708571767757947,0.00015221431902811555,-0.40873039308418763},
  {0.0048583366319828545,0.0001406665040947255,-0.20028540249032381},
  {0.038679124620721018,0.22027048230200899,-0.20083204021753873},
  {0.24964474717939103,0.0001518775619595917,-0.009920866152929083},
  {0.21115716922878616,0.22753466367503536,-0.038510940561568265},
  {0.0087583758352915916,0.25007611978657496,-0.20281239540845022},
  {0.010945112441688339,0.25007611978657496,-0.20083204021753873},
  {0.044950288355771306,0.00015221431902811555,0.1915228014491111},
  {0.11785614451525898,0.24923353027872527,0.028211514239746164},
  {0.023876266660515563,0.23292308074243259,0.14523996189322561},
  {0.20917564245145992,0.00015221431902811555,0.028211514239746164},
  {0.23936897811603103,0.00015220712381867335,0.00022277337797227211},
  {0.13987583422756139,0.18917306781232224,0.028211514239746164},
  {0.14298761674967742,0.22949602984817527,0.028657025779855308},
  {0.027647968300435696,0.00015221431902811555,0.33370688438243623},
  {0.059405251448771047,0.0001522093390925164,0.43517485449991017},
 },
 triangles={
  {1,11,3},
  {4,23,2},
  {3,11,13},
  {3,13,14},
  {3,24,23},
  {3,23,4},
  {3,38,24},
  {3,14,36},
  {3,36,37},
  {3,37,38},
  {1,3,4},
  {8,11,7},
  {6,5,7},
  {8,7,5},
  {5,86,8},
  {8,33,13},
  {9,8,86},
  {8,9,33},
  {33,9,34},
  {87,34,9},
  {102,34,87},
  {10,12,7},
  {10,11,12},
  {10,7,11},
  {7,12,55},
  {1,12,11},
  {6,7,56},
  {8,13,11},
  {33,37,13},
  {13,36,14},
  {37,36,13},
  {15,23,24},
  {15,22,23},
  {15,24,26},
  {15,26,16},
  {15,17,22},
  {17,18,25},
  {18,35,19},
  {20,154,19},
  {21,154,20},
  {21,20,44},
  {22,25,2},
  {22,2,23},
  {17,25,22},
  {2,25,63},
  {24,38,26},
  {16,26,27},
  {26,38,27},
  {16,27,65},
  {27,38,66},
  {19,213,18},
  {214,19,155},
  {15,16,33},
  {15,33,34},
  {15,35,17},
  {15,34,35},
  {16,38,33},
  {17,35,18},
  {35,20,19},
  {35,49,20},
  {21,108,154},
  {34,50,35},
  {33,38,37},
  {16,65,38},
  {65,66,38},
  {39,34,102},
  {39,40,34},
  {34,40,43},
  {34,43,105},
  {39,43,40},
  {71,42,41},
  {71,103,42},
  {39,105,43},
  {107,103,71},
  {29,75,45},
  {45,75,46},
  {30,75,29},
  {20,49,44},
  {21,44,108},
  {46,75,48},
  {30,32,82},
  {34,105,50},
  {44,49,108},
  {35,50,49},
  {107,71,76},
  {51,107,76},
  {1,4,181},
  {2,183,4},
  {2,64,183},
  {1,181,54},
  {4,183,181},
  {181,184,60},
  {64,204,183},
  {184,80,60},
  {184,81,80},
  {184,206,81},
  {7,55,54},
  {7,54,52},
  {1,55,12},
  {1,54,55},
  {52,56,7},
  {53,54,59},
  {181,60,54},
  {188,53,58},
  {188,54,53},
  {185,54,188},
  {185,187,54},
  {52,54,56},
  {56,54,187},
  {56,187,57},
  {57,187,189},
  {58,53,59},
  {60,59,54},
  {188,58,59},
  {188,59,60},
  {188,60,80},
  {188,80,231},
  {189,61,62},
  {232,69,61},
  {189,232,61},
  {57,189,62},
  {2,63,64},
  {25,18,212},
  {25,212,63},
  {27,77,65},
  {27,66,78},
  {27,78,77},
  {18,213,212},
  {213,19,214},
  {28,214,155},
  {28,31,214},
  {29,45,222},
  {30,222,32},
  {30,29,222},
  {28,83,31},
  {31,82,32},
  {31,32,222},
  {63,204,64},
  {63,212,204},
  {206,205,81},
  {205,211,79},
  {205,79,81},
  {211,244,79},
  {45,220,221},
  {31,222,214},
  {45,221,222},
  {66,68,67},
  {66,65,68},
  {66,67,78},
  {68,77,67},
  {65,77,68},
  {67,77,78},
  {41,42,70},
  {41,70,232},
  {41,232,71},
  {70,69,232},
  {72,74,73},
  {47,72,73},
  {47,74,72},
  {47,48,74},
  {45,46,220},
  {48,75,74},
  {30,82,75},
  {46,48,220},
  {74,75,82},
  {47,220,48},
  {47,73,219},
  {74,331,73},
  {31,83,82},
  {83,74,82},
  {76,71,84},
  {51,76,84},
  {84,109,51},
  {233,245,71},
  {231,80,81},
  {81,79,244},
  {81,238,239},
  {231,81,239},
  {81,244,238},
  {232,233,71},
  {47,219,220},
  {71,246,84},
  {245,246,71},
  {83,331,74},
  {219,73,331},
  {5,85,86},
  {85,94,86},
  {85,93,94},
  {88,87,9},
  {86,88,9},
  {88,101,87},
  {86,89,88},
  {89,86,94},
  {93,95,94},
  {95,89,94},
  {6,92,5},
  {5,91,85},
  {85,91,93},
  {92,90,93},
  {5,92,91},
  {91,92,93},
  {90,92,96},
  {87,101,100},
  {100,102,87},
  {96,93,90},
  {93,134,95},
  {100,101,97},
  {100,97,102},
  {39,102,97},
  {89,97,88},
  {111,97,89},
  {111,98,97},
  {97,101,88},
  {97,98,105},
  {98,99,105},
  {39,97,105},
  {110,105,99},
  {139,110,99},
  {104,103,107},
  {106,105,110},
  {50,105,106},
  {106,110,50},
  {50,110,108},
  {49,50,108},
  {51,109,107},
  {109,138,107},
  {109,167,138},
  {108,110,168},
  {110,139,168},
  {89,95,111},
  {98,111,112},
  {112,111,113},
  {98,112,115},
  {98,115,99},
  {112,114,115},
  {112,113,114},
  {113,149,114},
  {95,136,111},
  {115,139,99},
  {111,150,113},
  {114,148,115},
  {115,140,139},
  {115,148,140},
  {114,175,148},
  {114,174,175},
  {113,151,149},
  {114,149,174},
  {6,118,92},
  {6,56,118},
  {92,118,116},
  {119,92,116},
  {56,57,118},
  {57,62,120},
  {57,120,118},
  {118,122,117},
  {116,118,117},
  {125,62,61},
  {61,69,124},
  {120,62,121},
  {123,117,122},
  {121,62,125},
  {125,61,124},
  {123,129,117},
  {131,116,117},
  {129,131,117},
  {119,116,131},
  {123,127,129},
  {125,124,126},
  {127,128,129},
  {128,130,129},
  {128,131,130},
  {129,130,131},
  {133,96,92},
  {93,96,134},
  {95,134,136},
  {133,92,132},
  {119,132,92},
  {133,134,96},
  {132,134,133},
  {132,135,134},
  {134,135,137},
  {134,137,136},
  {141,103,104},
  {70,42,141},
  {70,141,69},
  {141,42,103},
  {104,107,146},
  {138,146,107},
  {139,140,168},
  {140,173,168},
  {69,141,124},
  {141,104,142},
  {146,142,104},
  {146,138,302},
  {140,145,173},
  {143,145,144},
  {147,337,173},
  {143,337,147},
  {143,147,145},
  {145,147,173},
  {111,136,150},
  {113,150,151},
  {149,176,174},
  {137,152,136},
  {136,152,150},
  {140,148,145},
  {148,175,344},
  {145,148,305},
  {148,344,305},
  {149,151,176},
  {150,152,151},
  {151,152,176},
  {152,177,176},
  {19,153,155},
  {19,154,153},
  {153,160,155},
  {28,155,160},
  {153,154,170},
  {153,170,156},
  {153,156,160},
  {154,108,170},
  {156,170,157},
  {157,170,172},
  {172,179,157},
  {164,326,215},
  {164,215,247},
  {164,165,327},
  {28,160,83},
  {84,169,109},
  {84,159,169},
  {159,161,169},
  {156,157,164},
  {156,164,160},
  {161,171,169},
  {161,162,171},
  {162,163,171},
  {160,158,83},
  {159,162,161},
  {160,331,158},
  {160,247,331},
  {83,158,331},
  {160,164,247},
  {84,338,159},
  {159,163,162},
  {164,157,165},
  {163,338,171},
  {159,338,163},
  {166,157,179},
  {157,166,165},
  {166,335,165},
  {166,336,335},
  {166,179,180},
  {109,169,167},
  {108,168,170},
  {170,168,172},
  {168,173,172},
  {138,167,342},
  {169,342,167},
  {171,338,169},
  {172,173,337},
  {338,342,169},
  {339,172,337},
  {175,174,178},
  {174,176,178},
  {175,178,344},
  {176,177,178},
  {177,345,178},
  {179,172,180},
  {180,172,339},
  {181,183,182},
  {182,183,204},
  {181,229,184},
  {184,207,206},
  {182,204,217},
  {184,229,207},
  {182,217,225},
  {182,225,191},
  {186,185,188},
  {181,182,190},
  {186,190,185},
  {185,190,187},
  {187,195,193},
  {187,193,198},
  {186,188,231},
  {181,227,228},
  {181,228,230},
  {181,230,229},
  {186,234,228},
  {186,231,234},
  {181,190,227},
  {186,227,190},
  {186,228,227},
  {187,202,189},
  {187,198,202},
  {189,202,232},
  {233,202,236},
  {232,202,233},
  {182,191,190},
  {192,190,191},
  {192,196,190},
  {192,191,199},
  {187,190,195},
  {195,190,196},
  {192,199,196},
  {195,196,193},
  {196,194,193},
  {259,193,194},
  {196,197,194},
  {201,194,197},
  {259,194,201},
  {250,253,191},
  {200,199,191},
  {225,250,191},
  {191,253,255},
  {237,202,292},
  {200,191,254},
  {201,197,203},
  {259,201,203},
  {191,255,254},
  {266,200,254},
  {293,256,292},
  {204,212,217},
  {206,207,205},
  {205,207,210},
  {207,209,210},
  {208,210,209},
  {205,210,211},
  {208,209,251},
  {207,229,209},
  {208,251,210},
  {211,210,251},
  {211,251,239},
  {211,239,238},
  {211,238,244},
  {209,229,251},
  {213,217,212},
  {213,328,217},
  {213,214,328},
  {326,328,214},
  {214,222,326},
  {222,215,326},
  {222,216,215},
  {217,328,226},
  {226,328,329},
  {218,224,226},
  {222,221,216},
  {215,216,247},
  {216,224,248},
  {216,248,247},
  {221,223,216},
  {224,249,248},
  {223,224,216},
  {218,249,224},
  {218,330,249},
  {217,226,225},
  {223,252,225},
  {223,225,226},
  {226,329,330},
  {218,226,330},
  {223,226,224},
  {234,235,229},
  {231,239,234},
  {234,239,235},
  {229,235,240},
  {234,229,230},
  {234,230,228},
  {235,239,240},
  {220,242,241},
  {251,240,239},
  {243,241,242},
  {243,220,241},
  {233,236,245},
  {229,240,251},
  {236,202,237},
  {304,236,237},
  {220,331,242},
  {219,331,220},
  {220,243,221},
  {243,242,248},
  {247,242,331},
  {248,242,247},
  {221,243,223},
  {258,245,236},
  {243,248,249},
  {258,246,245},
  {303,84,246},
  {225,252,250},
  {250,266,253},
  {223,243,252},
  {250,252,333},
  {237,292,256},
  {268,237,256},
  {268,304,237},
  {266,255,253},
  {250,271,266},
  {266,254,255},
  {269,293,294},
  {256,293,268},
  {268,293,269},
  {250,333,271},
  {268,269,304},
  {243,333,252},
  {243,249,333},
  {304,258,236},
  {258,303,246},
  {269,274,257},
  {269,257,304},
  {274,273,257},
  {276,341,322},
  {276,333,341},
  {259,261,193},
  {259,197,196},
  {259,196,261},
  {196,260,261},
  {259,203,197},
  {266,264,200},
  {278,196,199},
  {260,196,278},
  {278,199,200},
  {278,200,264},
  {260,278,261},
  {261,278,262},
  {263,262,279},
  {262,278,279},
  {264,265,278},
  {266,271,264},
  {269,294,313},
  {269,313,267},
  {269,267,270},
  {267,272,270},
  {269,270,272},
  {271,275,264},
  {275,265,264},
  {269,272,314},
  {269,314,319},
  {269,319,273},
  {269,273,274},
  {271,333,275},
  {276,322,323},
  {257,273,319},
  {275,333,276},
  {275,281,265},
  {275,276,281},
  {265,277,278},
  {265,281,277},
  {278,277,280},
  {278,280,279},
  {279,325,263},
  {280,323,325},
  {280,325,279},
  {277,281,280},
  {276,323,280},
  {276,280,281},
  {120,198,118},
  {287,122,118},
  {123,122,287},
  {282,287,118},
  {198,193,118},
  {119,287,132},
  {123,287,288},
  {132,287,289},
  {119,288,287},
  {123,288,296},
  {120,121,198},
  {121,125,202},
  {125,126,202},
  {121,202,198},
  {126,124,307},
  {123,295,127},
  {119,131,288},
  {127,283,128},
  {128,283,131},
  {123,296,295},
  {131,295,296},
  {131,296,288},
  {127,295,283},
  {131,283,295},
  {297,284,286},
  {284,285,286},
  {261,282,118},
  {261,118,193},
  {261,287,282},
  {287,290,289},
  {289,290,298},
  {287,308,290},
  {291,308,297},
  {290,308,291},
  {126,292,202},
  {293,292,126},
  {293,126,294},
  {294,126,307},
  {291,297,298},
  {290,291,298},
  {297,310,284},
  {263,285,284},
  {285,311,286},
  {289,135,132},
  {289,137,135},
  {289,298,137},
  {297,286,298},
  {141,312,124},
  {141,142,315},
  {146,315,142},
  {143,144,301},
  {143,301,337},
  {341,337,301},
  {141,313,312},
  {141,267,313},
  {124,312,307},
  {141,272,267},
  {141,314,272},
  {141,315,314},
  {318,300,324},
  {325,300,299},
  {325,299,286},
  {146,302,315},
  {303,319,315},
  {300,318,321},
  {321,322,300},
  {303,302,340},
  {257,319,303},
  {302,303,315},
  {257,303,304},
  {303,258,304},
  {300,322,341},
  {301,300,341},
  {305,299,300},
  {299,305,306},
  {137,298,152},
  {298,306,152},
  {144,145,305},
  {144,305,301},
  {305,344,345},
  {301,305,300},
  {305,345,306},
  {152,345,177},
  {152,306,345},
  {298,286,299},
  {299,306,298},
  {287,261,308},
  {297,308,310},
  {294,307,312},
  {310,263,284},
  {263,311,285},
  {309,308,261},
  {261,262,309},
  {308,309,310},
  {262,263,309},
  {309,263,310},
  {263,325,311},
  {294,312,313},
  {317,318,316},
  {323,324,300},
  {300,325,323},
  {325,286,311},
  {316,318,324},
  {320,316,324},
  {320,324,323},
  {319,314,315},
  {317,320,318},
  {320,321,318},
  {317,316,320},
  {320,323,321},
  {321,323,322},
  {326,327,328},
  {328,327,329},
  {327,330,329},
  {164,327,326},
  {330,332,249},
  {327,332,330},
  {165,335,327},
  {327,335,336},
  {327,336,332},
  {303,338,84},
  {249,332,334},
  {332,336,334},
  {249,334,333},
  {334,341,333},
  {334,343,341},
  {334,336,166},
  {180,343,166},
  {334,166,343},
  {138,342,302},
  {343,339,337},
  {302,342,340},
  {303,340,342},
  {341,343,337},
  {338,303,342},
  {178,345,344},
  {180,339,343},
 },
}
return G

end)()
local RockDamage = (function()
-- Cosmetic CSG of cubic rocks and retained crystal previews. Server hits provide the
-- persistent counts; this module cannot grant damage, ore or reservations.
local R={MAX_CUTS=6}
local CANONICAL=4
local views=setmetatable({},{__mode='k'})
local function count(value) return math.clamp(math.floor(tonumber(value) or 0),0,R.MAX_CUTS) end
local function divide(a,b) return Vector3.new(a.X/b.X,a.Y/b.Y,a.Z/b.Z) end
function R.bite(index,depthBand)
 local i=math.clamp(math.floor(index or 1),1,R.MAX_CUTS)
 local angle=(i-1)*2.39996323+.35
 local pressure=math.clamp(math.floor(depthBand or 0),0,6)/6
 return Vector3.new(math.cos(angle)*.23,.10+(i%2)*.035,math.sin(angle)*.23),.60+.12*pressure
end
function R.depthBand(bubbles,dents,depth)
 if count(bubbles)<R.MAX_CUTS and count(dents)<R.MAX_CUTS then return 0 end
 return math.clamp(math.floor(math.clamp(tonumber(depth) or 0,0,1)*6+1e-7),0,6)
end
function R.cutSpecs(bubbles,dents,depthBand,scars,shallow)
 local result={}
 for i=1,count(bubbles) do
  local center,diameter=R.bite(i,count(bubbles)>=R.MAX_CUTS and depthBand or 0)
  result[#result+1]={center=center,size=Vector3.one*diameter,kind='Bubbler'}
 end
 local n=count(dents)
 if n>0 then
  local pressure=n>=R.MAX_CUTS and math.clamp(math.floor(depthBand or 0),0,6)/6 or 0
  -- One nested ellipsoid: each accepted hammer strike widens AND deepens
  -- the same cavity. Its lower rim never cuts through the grounded foot.
  result[#result+1]={center=Vector3.new(.025,.49,.015),size=Vector3.new(.60+.10*n+.20*pressure,.36+.10*n+.18*pressure,.60+.10*n+.20*pressure),kind='Smasher'}
 end
 for _,scar in ipairs(scars or {}) do
  local width,depth,axis=scar[4],scar[5],scar[6]
  local size=Vector3.new(axis=='X' and depth or width,axis=='Y' and depth or width,axis=='Z' and depth or width)
  result[#result+1]={center=Vector3.new(scar[1],scar[2],scar[3]),size=size,axis=axis}
 end
 if shallow then
  -- Press into one solid cube. Leave the printed face planar away from
  -- contact, with enough material under each mark to read as a dent.
  for _,spec in ipairs(result) do
   local axis=spec.axis or 'Y'
   local center,size=spec.center,spec.size
   local face=center[axis]<0 and -.5 or .5
   local depth=math.clamp(size[axis]*.39,.13,.29)
   spec.center=Vector3.new(axis=='X' and face or center.X,axis=='Y' and face or center.Y,axis=='Z' and face or center.Z)
   spec.size=Vector3.new(axis=='X' and depth or size.X,axis=='Y' and depth or size.Y,axis=='Z' and depth or size.Z)
  end
 end
 return result
end
function R.basePose(view)
 local record=views[view]
 if not record then return view.CFrame,view.Size end
 local size=divide(view.Size,record.damageScale or Vector3.one)
 return view.CFrame*CFrame.new(-(size*(record.damageOffset or Vector3.zero))),size
end
local function clean(part)
 for _,child in ipairs(part:GetChildren()) do child:Destroy() end
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.PivotOffset=CFrame.new()
 part.LocalTransparencyModifier=0;part.Transparency=0
 if part:IsA('PartOperation') then part.UsePartColor=true end
end
local function discard(parts)
 if type(parts)=='table' then for _,part in ipairs(parts) do part:Destroy() end end
end
function R.new(options)
 options=options or {}
 local self={records={},queued={},working=false,nextAt=0,closed=false,operations=0,failures=0}
 local function failure(record,state,key,message)
  self.failures+=1;self.lastError=tostring(message);state.failed=key
  if record.view.Parent then record.view:SetAttribute('PhysicalDamageError',self.lastError:sub(1,350)) end
 end
 function self:register(record)
  if self.closed or self.records[record] then return end
  self.records[record]={requested='',applied='',generation=0}
  views[record.view]=record
 end
 function self:update(record,now)
  if self.closed then return end
  self:register(record)
  local state=self.records[record];local source=record.source
  if not state or not source.Parent or not record.view.Parent then return end
  if (source:GetAttribute('BreakSerial') or 0)>0 or (source:GetAttribute('HP') or 1)<=0 then self.queued[record]=nil;return end
  local bubbles=count(source:GetAttribute('BubbleBites'));local dents=count(source:GetAttribute('SmashDents'))
  local band=R.depthBand(bubbles,dents,source:GetAttribute('DamageDepth'))
  local scars=source:GetAttribute('ToolScars')
  local key=bubbles..':'..dents..(band>0 and ':'..band or '')..(scars and ':tools:'..scars or '')
  if key==state.requested then return end
  state.requested=key;state.generation+=1
  if bubbles+dents==0 and not scars then return end
  -- Only the local render clone is touched, never the replicated source.
  if not record.view:IsA('PartOperation') and not record.view:IsA('MeshPart') and source:GetAttribute('CubicRock')~=true then return end
  local history=scars and game:GetService('HttpService'):JSONDecode(scars)
  self.queued[record]={bubbles=bubbles,dents=dents,depthBand=band,scars=history,generation=state.generation,key=key,at=now}
 end
 local function execute(record,request,state)
  local geometry=game:GetService('GeometryService')
  local cubic=record.source:GetAttribute('CubicRock')==true
  if not cubic and CrystalGeometry and not self.templateAttempted then
   self.templateAttempted=true
   local editable
   local made,template=pcall(function()
    local assets=game:GetService('AssetService')
    editable=assert(assets:CreateEditableMesh(),'Local crystal mesh budget unavailable')
    local ids={}
    for i,vertex in ipairs(CrystalGeometry.vertices) do
     ids[i]=editable:AddVertex(Vector3.new(vertex[1],vertex[2],vertex[3])*CANONICAL)
    end
    for _,triangle in ipairs(CrystalGeometry.triangles) do
     editable:AddTriangle(ids[triangle[1]],ids[triangle[2]],ids[triangle[3]])
    end
    return assets:CreateMeshPartAsync(Content.fromObject(editable),{
     CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise,
    })
   end)
   if made and template and not self.closed then
    self.template=template;self.editableTemplate=editable
    clean(template);template.CFrame=CFrame.new();template.Size=Vector3.one*CANONICAL
   else
    if made and template then template:Destroy() end
    if editable then editable:Destroy() end
    self.templateError=tostring(template)
    failure(record,state,request.key,'Template: '..self.templateError)
   end
  end
  if self.closed or self.records[record]~=state then return end
  -- Cubic resources use their pristine server Part. For retained crystal
  -- previews, use original geometry; never normalize a legacy union
  -- by re-unioning it: old URL-backed operands can resolve to a plain box.
  -- CrystalGeometry recovers the original asset's collision hull surface;
  -- intact rocks retain their original render, only damaged rocks use it.
  local template=cubic and record.source or (options.template and options.template(record) or self.template or record.source)
  local base=template:Clone();clean(base)
  base.CFrame=CFrame.new();base.Size=Vector3.one*CANONICAL
  local cutters={}
  local shallow=record.source:GetAttribute('Kind')=='Junk'
 for _,spec in ipairs(R.cutSpecs(request.bubbles,request.dents,request.depthBand,request.scars,shallow)) do
   local cutter=Instance.new('Part');cutter.Shape=Enum.PartType.Ball
   cutter.Size=spec.size*CANONICAL;cutter.CFrame=CFrame.new(spec.center*CANONICAL)
   cutter.Anchored=true;cutter.CanCollide=false;cutter.CanTouch=false;cutter.CanQuery=false
   cutters[#cutters+1]=cutter
  end
  self.operations+=1
  local geometryOptions={
   CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition,RenderFidelity=Enum.RenderFidelity.Automatic,SplitApart=false,
  }
  local ok,parts=pcall(function()
   return geometry:SubtractAsync(base,cutters,geometryOptions)
  end)
  base:Destroy();discard(cutters)
  if not ok or type(parts)~='table' or #parts~=1 then
   failure(record,state,request.key,'Subtract: '..(ok and ('expected one result, received '..tostring(type(parts)=='table' and #parts or type(parts))) or tostring(parts)))
   discard(parts);return
  end
  local result=parts[1]
  local ratio=result.Size/CANONICAL
  -- Some legacy unions have invalid CSG operand data. A subtraction cannot
  -- expand its source; refuse a malformed result and retain original art.
  local valid=ratio.X>.24 and ratio.Y>.24 and ratio.Z>.24 and ratio.X<1.03 and ratio.Y<1.03 and ratio.Z<1.03
  if valid and not self.closed and self.records[record]==state and state.generation==request.generation
   and record.source.Parent and record.view.Parent and (record.source:GetAttribute('BreakSerial') or 0)==0 then
   local view=record.view;local frame,size=R.basePose(view)
   local offset=result.CFrame.Position/CANONICAL
   local priorPivot,priorColor=view.PivotOffset,view.Color
   local swapped,swapError=pcall(function()
    if (view:IsA('Part') and cubic) or (view:IsA('PartOperation') and result:IsA('MeshPart')) then
     -- Native verification found SubstituteGeometry(MeshPart) reports success
     -- but keeps the old union render. Convert the local view once, retaining
     -- its logical record and metadata; later cuts use stable ApplyMesh.
     local old=view
     clean(result)
     for _,property in ipairs({'Name','Material','MaterialVariant','Color','Transparency','LocalTransparencyModifier','Reflectance','CastShadow'}) do
      if old[property]~=nil then result[property]=old[property] end
     end
     for name,value in pairs(old:GetAttributes()) do result:SetAttribute(name,value) end
     result.Size=size*ratio;result.CFrame=frame*CFrame.new(size*offset)
     for _,child in ipairs(old:GetChildren()) do child.Parent=result end
     result.Parent=old.Parent
     record.view=result;views[old]=nil;views[result]=record
     view=result;parts={};old:Destroy()
    elseif view:IsA('PartOperation') and result:IsA('PartOperation') then
     view.PivotOffset=CFrame.new();view:SubstituteGeometry(result)
    elseif view:IsA('MeshPart') and result:IsA('MeshPart') then
     view.PivotOffset=CFrame.new();view:ApplyMesh(result)
    else error('Incompatible local crystal geometry') end
   end)
   if swapped then
    record.damageScale=ratio;record.damageOffset=offset
    view.Size=size*ratio;view.CFrame=frame*CFrame.new(size*offset)
    view.Color=priorColor;view:SetAttribute('PhysicalDamageKey',request.key)
    view:SetAttribute('PhysicalDamageError',nil)
    record.dirty=true;state.applied=request.key
   else view.PivotOffset=priorPivot;failure(record,state,request.key,'Substitute: '..tostring(swapError)) end
  elseif not valid then failure(record,state,request.key,string.format('Invalid bounds %.4f, %.4f, %.4f; template=%s',ratio.X,ratio.Y,ratio.Z,self.template and self.template.ClassName or 'original')) end
  discard(parts)
 end
 function self:step(now)
  if self.closed or self.working or now<self.nextAt then return end
  local camera=workspace.CurrentCamera;local selected,request,best=nil,nil,math.huge
  for record,pending in pairs(self.queued) do
   if not record.source.Parent or not record.view.Parent then self.queued[record]=nil
   else
    local distance=camera and (record.view.Position-camera.CFrame.Position).Magnitude or 0
    -- Distant damage remains queued; a returning observer gets the latest
    -- full shape, without replaying intermediate contacts or sound.
    if distance<160 and distance<best then selected=record;request=pending;best=distance end
   end
  end
  if not selected then return end
  self.queued[selected]=nil;self.working=true;self.nextAt=now+.12
  local state=self.records[selected]
  task.spawn(function()
   local ok,err=pcall(execute,selected,request,state)
   if not ok then failure(selected,state,request.key,'Worker: '..tostring(err)) end
   self.working=false
  end)
 end
 function self:remove(record)
  self.queued[record]=nil;self.records[record]=nil;views[record.view]=nil
 end
 function self:destroy()
  self.closed=true
  if self.template then self.template:Destroy();self.template=nil end
  if self.editableTemplate then self.editableTemplate:Destroy();self.editableTemplate=nil end
  for record in pairs(self.records) do views[record.view]=nil end
  table.clear(self.queued);table.clear(self.records)
 end
 return self
end
return R

end)()
local DroneFX = (function()
-- Client-only, server-clocked specialist work. Each cycle removes a chunk;
-- the remaining authored crystal stays grounded and readable throughout.
local FX = {}
local TAU=math.pi*2
local MAX_PARTS,MAX_EFFECT_PARTS=360,48
local TAIL=1.15
local supported={Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local effectAttributes={ResourceId=true,EffectSerial=true,EffectType=true,EffectStartedAt=true,EffectDuration=true,EffectImpact=true,EffectDoneAt=true,EffectDepleted=true,EffectPausedAt=true,EffectCancelledSerial=true}
local resourceNames={Crystal=true,Geode=true,Core=true,Shard=true}
local cyan=Color3.fromRGB(130,239,255)
local gold=Color3.fromRGB(255,211,83)
local purple=Color3.fromRGB(179,105,255)
local ice=Color3.fromRGB(169,229,255)
local hot=Color3.fromRGB(255,140,48)
local function clamp(x) return math.clamp(x,0,1) end
local function smooth(x) x=clamp(x);return x*x*(3-2*x) end
local function safeSize(v) return Vector3.new(math.max(.025,v.X),math.max(.025,v.Y),math.max(.025,v.Z)) end
local function part(e,name,size,color,material,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Size=safeSize(size);p.Color=color;p.Material=material or Enum.Material.Neon;p.CFrame=e.cf;p.Transparency=1
 if shape then p.Shape=shape end
 p.Parent=e.folder;e.parts[#e.parts+1]=p;e.owner.count+=1;return p
end
local function ring(e,n,color,width)
 local root=part(e,'PressurePlane',Vector3.one*.025,color)
 return {root=root,plane=PlaneBurst.create(root,color),width=width or .045}
end
local function line(p,a,b,width,alpha)
 if (b-a).Magnitude<.001 then p.Transparency=1;return end
 p.Size=Vector3.new(width,width,math.max(.025,(b-a).Magnitude));p.CFrame=CFrame.lookAt((a+b)*.5,b);p.Transparency=clamp(alpha)
end
local function energyLine(e,p,a,b,width,alpha,style)
 line(p,a,b,width,alpha)
 e.beams=e.beams or {}
 local r=e.beams[p]
 if alpha>=.98 or (b-a).Magnitude<.015 then BeamVFX.hide(r,not e.owner.reuseGeometry);return end
 if not r then r=BeamVFX.new(e.folder,style,p.Color,p.Name=='ScanHead');e.beams[p]=r end
 if r then
  p.Transparency=1
  BeamVFX.draw(r,a,b,e.visualNow,1-math.clamp(alpha,0,1),nil,e.contactAge,width/r.profile.body)
 end
end
local function showRing(value,cf,radius,alpha)
 value.root.CFrame=cf
 PlaneBurst.pose(value.plane,Vector3.yAxis,radius,1-clamp(alpha),value.width)
end
local function hideParts(values) for _,p in ipairs(values) do p.Transparency=1 end end
local function proxy(e)
 local p=e.view:Clone()
 for _,v in ipairs(p:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Highlight') or v:IsA('Sound') or v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Trail') then v:Destroy() end
 end
 p.Name='GroundedCrystal';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.LocalTransparencyModifier=0;p.Transparency=0;p.Parent=e.folder;e.parts[#e.parts+1]=p;e.owner.count+=1;return p
end
local function build(e)
 e.rock=proxy(e)
 if e.kind=='Bubbler' then
  e.bubbles={};e.glints={}
  for i=1,3 do
   local p=part(e,'PressureBubble',Vector3.one,cyan,Enum.Material.Glass,Enum.PartType.Ball);p.Reflectance=.18;e.bubbles[i]=p
   e.glints[i]=part(e,'GlassGlint',Vector3.one,Color3.new(1,1,1),Enum.Material.Neon,Enum.PartType.Ball)
  end
 elseif e.kind=='Halver' then
  e.jaws={part(e,'CuttingJaw',Vector3.one,purple,Enum.Material.CorrodedMetal),part(e,'CuttingJaw',Vector3.one,purple,Enum.Material.CorrodedMetal)}
  for _,jaw in ipairs(e.jaws) do jaw.MaterialVariant='QuarryDrone_Ribbed' end
  e.cut=part(e,'ShearEdge',Vector3.one,cyan)
 elseif e.kind=='Gridcutter' then
  e.grid={};for i=1,4 do e.grid[i]=part(e,'CutLine',Vector3.one,Color3.fromRGB(255,92,109)) end
  e.scanner=part(e,'ScanHead',Vector3.one,Color3.new(1,1,1))
  e.release=ring(e,12,Color3.fromRGB(255,120,145),.065)
 elseif e.kind=='Singularity' then
  e.hole=part(e,'EventHorizon',Vector3.one,Color3.fromRGB(5,3,12),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
  e.ring=ring(e,12,purple,.07)
 elseif e.kind=='Starforge' then
  e.sun=part(e,'ContainedSun',Vector3.one,gold,Enum.Material.Neon,Enum.PartType.Ball)
  e.corona=part(e,'HeatEnvelope',Vector3.one,hot,Enum.Material.Neon,Enum.PartType.Ball)
  e.rays={};for i=1,3 do e.rays[i]=part(e,'HeatRay',Vector3.one,hot) end
 elseif e.kind=='Frostbite' then
  e.shell=proxy(e);e.shell.Name='GrowingIce';e.shell.Color=ice;e.shell.Material=Enum.Material.Glass;e.shell.Transparency=1;e.shell.Reflectance=.16
  e.ring=ring(e,10,ice,.045)
 elseif e.kind=='Resonator' then
  e.rings={ring(e,10,cyan,.045),ring(e,10,purple,.045),ring(e,10,cyan,.045)}
 end
end
local function facePoint(e,i)
 local a=i*2.399963
 return e.center+Vector3.new(math.cos(a)*e.radius*.38,e.size.Y*.36,math.sin(a)*e.radius*.38)
end
local function fade(e,age) return age and smooth(age/e.tail) or 0 end
local function recovery(age) return age and smooth(age/.65) or 0 end
local function bubblePose(e,t,age)
 local r=e.radius;local fill=smooth(t/(e.impact*.88))
 local cutPoint,cutDiameter
 if RockDamage then cutPoint,cutDiameter=RockDamage.bite(e.biteIndex,e.biteDepthBand)
 else
  local angle=(e.biteIndex-1)*2.39996323+.35
  cutPoint=Vector3.new(math.cos(angle)*.23,.10+(e.biteIndex%2)*.035,math.sin(angle)*.23);cutDiameter=.60
 end
 -- The large bubble is the actual spherical subtraction stencil, in the
 -- crystal's local coordinates. It stops hovering over an unrelated top cap.
 local cap=e.cf:PointToWorldSpace(cutPoint*e.size)
 local lift=age and math.min(age,.48) or 0
 local floating=cap+Vector3.new(lift*.18,r*(1-math.exp(-lift*8))*.65,0)
 local pop=age and smooth((age-.42)/.09) or 0
 for i,p in ipairs(e.bubbles) do
  local side=i-2
  local position=cap+Vector3.new(side*r*.48*(1-fill),r*.5*(1-fill),side*r*.2*(1-fill))
  if age then position=floating+Vector3.new(side*r*.15,math.abs(side)*r*.13,side*r*.08) end
  local diameter=(i==2 and cutDiameter*r*2 or r*.20)*fill*(1+pop*.35)
  local stretch=age and .28*math.exp(-age*8) or .09*math.sin(fill*math.pi)
  p.Position=position;p.Size=safeSize(Vector3.new(diameter*(1-stretch*.4),diameter*(1+stretch),diameter*(1-stretch*.4)));p.Transparency=.64+pop*.36
  local glint=e.glints[i];glint.Position=position+Vector3.new(-diameter*.23,diameter*.27,-diameter*.12)
  glint.Size=Vector3.one*math.max(.025,diameter*.05);glint.Transparency=.18+pop*.82
 end
end
local function halverPose(e,t,age)
 local charge=smooth(t/(e.impact*.7));local cut=clamp((t-e.impact*.8)/(e.impact*.2))^3;local reset=recovery(age)
 local size,frame=e.rockSize,e.rockFrame
 local gap=size.X*(.56+.13*charge-.58*cut+.76*reset)
 local top=frame*CFrame.new(0,size.Y*.43,0)
 for i,p in ipairs(e.jaws) do
  local side=i==1 and -1 or 1
  p.CFrame=top*CFrame.new(side*gap,.15*charge,0)*CFrame.Angles(0,0,side*(.18*charge-.24*cut)*(1-reset))
  p.Size=Vector3.new(.12,size.Y*.21,size.Z*1.05);p.Transparency=.15+reset*.85
 end
 energyLine(e,e.cut,top:PointToWorldSpace(Vector3.new(0,0,-size.Z*.51)),top:PointToWorldSpace(Vector3.new(0,0,size.Z*.51)),.075,.97-cut*.9+reset*.9,'Lance')
end
local function gridPose(e,t,age)
 local frame,size=e.rockFrame,e.rockSize
 local top=frame*CFrame.new(0,size.Y*.5+.035,0)
 local x,z=size.X*.5,size.Z*.5
 local width=math.clamp(e.radius*.023,.035,.12)
 local scan=smooth(t/(e.impact*.83));local out=fade(e,age)
 for i,p in ipairs(e.grid) do
  local axis=i>2;local sign=i%2==1 and -1 or 1
  local a=top:PointToWorldSpace(axis and Vector3.new(-x,0,sign*z/3) or Vector3.new(sign*x/3,0,-z))
  local b=top:PointToWorldSpace(axis and Vector3.new(x,0,sign*z/3) or Vector3.new(sign*x/3,0,z))
  local visible=smooth((scan-(i-1)/5)*5)
  energyLine(e,p,a,a:Lerp(b,visible),width,1-visible*(1-out)*.88,'Gridcutter')
 end
 local scanX=-x+scan*x*2
 energyLine(e,e.scanner,top:PointToWorldSpace(Vector3.new(scanX,.045,-z)),top:PointToWorldSpace(Vector3.new(scanX,.045,z)),width*1.6,.18+out*.82,'Gridcutter')
 showRing(e.release,CFrame.new(top.Position),e.radius*(.35+1.3*(1-math.exp(-(age or 0)*13))),age and smooth(age/.42) or 1)
end
local function singularityPose(e,t,age)
 local r=e.radius;local grow=smooth(t/(e.impact*.75));local close=recovery(age)
 local center=e.center+Vector3.new(0,e.size.Y*.5+r*.55,0)
 local diameter=r*.63*grow*(1-close*.85)
 e.hole.Position=center;e.hole.Size=Vector3.one*math.max(.025,diameter);e.hole.Transparency=math.max(close,fade(e,age))
 showRing(e.ring,CFrame.new(center)*CFrame.Angles(.42,0,.25),math.max(.025,diameter*1.18),.15+math.max(close,fade(e,age))*.85)
 -- Keep the authored gravity well. A pair of tightening hooks and
 -- two sharp cuts give this small well a different vocabulary from heat rays.
 -- This is a resource gravity well, not a laser emitter: no charge lens here.
 e.gravityVFX=e.gravityVFX or BeamVFX.new(e.folder,'Singularity',purple,nil,false)
 if e.gravityVFX then
  BeamVFX.draw(e.gravityVFX,center,center-Vector3.yAxis,e.visualNow,0,math.min(1,t/e.impact),age,math.min(1.4,r*.7))
  local strength=1-fade(e,age)
  for _,v in ipairs(e.gravityVFX.all) do v.Width0*=strength;v.Width1*=strength end
  if e.gravityVFX.orb then e.gravityVFX.orb.Transparency=1 end -- existing EventHorizon owns the dark center
 end
end
local function starforgePose(e,t,age)
 local heat=smooth(t/(e.impact*.9));local cool=recovery(age);local r=e.radius
 local center=e.center+Vector3.new(0,e.size.Y*.5+r*.8,0)
 local diameter=r*(.2+.35*heat)*(1-cool*.8)
 e.sun.Position=center;e.sun.Size=Vector3.one*math.max(.025,diameter);e.sun.Transparency=cool
 e.corona.Position=center;e.corona.Size=e.sun.Size*1.35;e.corona.Transparency=.82+cool*.18
 for i,p in ipairs(e.rays) do energyLine(e,p,center,facePoint(e,i*2),.065,.95-heat*.65+cool*.75,'Starforge') end
 e.rock.Color=e.color:Lerp(hot,heat*.25*(1-cool))
end
local function frostbitePose(e,t,age)
 local freeze=smooth(t/(e.impact*.8));local shatter=age and smooth(age/.16) or 0
 e.shell.CFrame=e.rockFrame;e.shell.Size=safeSize(e.rockSize*(1.006+.022*freeze))
 e.shell.Color=ice;e.shell.Transparency=1-freeze*.45*(1-shatter)
 local wave=age and (1-math.exp(-age*18)) or 0
 showRing(e.ring,CFrame.new(e.center+Vector3.new(0,e.size.Y*.15,0)),e.radius*(.92+wave*1.03),age and clamp(.2+age/.7) or 1)
end
local function resonatorPose(e,t,age)
 for i,value in ipairs(e.rings) do
   local from=e.impact*(.08+(i-1)*.19)
  local phase=clamp((t-from)/(e.impact*.55))
  local strength=math.sin(math.pi*phase)^2
  local center=e.center+Vector3.new(0,(i-2)*e.radius*.12,0)
  local radius=e.radius*(1.45-.7*phase*phase)
  if age then
   local a=math.max(0,age-(i-1)*.045)
   radius=e.radius*(.66+1.24*(1-math.exp(-a*18))+.15*a)
   strength=age<(i-1)*.045 and 0 or (1-clamp(a/.72))^.7
  end
  showRing(value,CFrame.new(center),radius,1-strength*.65)
 end
 -- One low-amplitude recoil at contact replaces whole-rock high-frequency jitter.
 if age then
  local recoil=math.sin(math.pi*clamp(age/.26))*math.exp(-age*8)*.018
  e.rock.CFrame=e.rockFrame*CFrame.Angles(0,recoil,0)
 end
end
local poses={Bubbler=bubblePose,Halver=halverPose,Gridcutter=gridPose,Singularity=singularityPose,Starforge=starforgePose,Frostbite=frostbitePose,Resonator=resonatorPose}

function FX.new(world,options)
 options=options or {}
 local self={world=world,tracked={},dirty={},retry={},active={},cached={},completed={},count=0,effectSlots=0,connections={},destroyed=false,poseUpdates=0,reuseGeometry=options.reuseGeometry==true}
 local maxDistance=options.maxDistance or 160
 local focusPosition
 local function nearby(v)
  if BeamVFX.reduced() then return false end
  if focusPosition then local delta=focusPosition-v.Position;if delta:Dot(delta)<=maxDistance*maxDistance then return true end end
  local camera=workspace.CurrentCamera
  if not camera then return true end
  local offset=camera.CFrame.Position-v.Position
  return offset:Dot(offset)<=maxDistance*maxDistance
 end
 local folder=Instance.new('Folder');folder.Name='MiningAwayDroneFX';folder.Parent=workspace;self.folder=folder
 local function freeGeometry(e)
  self.count=math.max(0,self.count-#e.parts);e.parts={}
  if e.folder then e.folder:Destroy();e.folder=nil;self.effectSlots=math.max(0,self.effectSlots-1) end
 end
 local function remove(v,retain)
  local e=self.active[v]
  if e then
   if e.view.Parent then e.view.LocalTransparencyModifier=e.originalTransparency end
   if retain and options.reuseGeometry and not self.destroyed and v.Parent and not e.retired and nearby(v) then
    -- Only the fixed home displays opt in. Retained geometry counts against
    -- the same budget and is freed when its source streams out or we suspend.
    hideParts(e.parts)
    if e.ring then PlaneBurst.hide(e.ring.plane) end
    if e.release then PlaneBurst.hide(e.release.plane) end
    for _,ring in ipairs(e.rings or {}) do PlaneBurst.hide(ring.plane) end
    BeamVFX.hide(e.gravityVFX,false)
    if e.beams then for _,rig in pairs(e.beams) do BeamVFX.hide(rig,false) end end
    self.cached[v]=e
   else freeGeometry(e) end
   self.active[v]=nil
  end
 end
 -- A final hit is irreversible. Recall/death may cancel its cosmetic tail,
 -- but cannot reveal the old crystal while ordinary fracture stages drain.
 local function concealDepleted(e)
  if not e.retired then freeGeometry(e) end
  e.retired=true;e.tombstone=true;e.view.LocalTransparencyModifier=1
 end
 local function observe(v)
  if not v:IsA('BasePart') or self.tracked[v] then return end
  -- Ignore scenery, drone hardware, currency and their constantly changing
  -- attributes. Name/parent cover resources streamed before their attributes.
  local parent=v.Parent
  if not v:GetAttribute('ResourceId') and not resourceNames[v.Name]
   and not (parent and (parent.Name=='Resources' or parent:GetAttribute('FieldId'))) then return end
  self.tracked[v]=v.AttributeChanged:Connect(function(name)
   if effectAttributes[name] then self.dirty[v]=true;self.retry[v]=nil end
  end)
  self.dirty[v]=true
 end
 self.connections[#self.connections+1]=world.DescendantAdded:Connect(observe)
 self.connections[#self.connections+1]=world.DescendantRemoving:Connect(function(v)
  remove(v)
  if self.cached[v] then freeGeometry(self.cached[v]);self.cached[v]=nil end
  if self.tracked[v] then self.tracked[v]:Disconnect();self.tracked[v]=nil end
  self.dirty[v]=nil;self.retry[v]=nil;self.completed[v]=nil
 end)
 for _,v in ipairs(world:GetDescendants()) do observe(v) end
 function self:isActive(source) return self.active[source]~=nil end
 function self:step(now,_dt)
  if self.destroyed then return end
  focusPosition=options.focus and options.focus() or nil
  for v,at in pairs(self.retry) do if now>=at then self.retry[v]=nil;self.dirty[v]=true end end
  for v in pairs(self.dirty) do
   self.dirty[v]=nil
   if v.Parent and v:GetAttribute('ResourceId') then
    local serial=v:GetAttribute('EffectSerial') or 0
    local kind=v:GetAttribute('EffectType')
    local start=v:GetAttribute('EffectStartedAt')
    local duration=v:GetAttribute('EffectDuration')
    local cancelled=(v:GetAttribute('EffectCancelledSerial') or 0)>=serial
    local e=self.active[v]
    if e and e.serial==serial and cancelled and v:GetAttribute('EffectDepleted')==true then concealDepleted(e)
    elseif e and (e.serial~=serial or e.kind~=kind or cancelled or type(start)~='number' or type(duration)~='number' or duration<=0) then remove(v);e=nil end
    if e and not e.tombstone then e.start=start;e.duration=duration;e.tail=math.min(TAIL,duration*(1-e.impact)*.98) end -- Save-pause clock shifts preserve geometry and phase.
    if not e and self.completed[v]~=serial and serial>0 and not cancelled and supported[kind] and type(start)=='number' and type(duration)=='number' and duration>0 then
     local done=v:GetAttribute('EffectDoneAt') or 0
     if done>0 and done>=start and now-done>TAIL then
      self.completed[v]=serial -- A late joiner never replays an old contact.
     elseif not nearby(v) then self.retry[v]=now+.2
     elseif self.cached[v] or (self.effectSlots<8 and self.count+MAX_EFFECT_PARTS<=MAX_PARTS) then
      local view=options.resolve and options.resolve(v) or (not options.resolve and v or nil)
      if view and view.Parent and view.Transparency<.99 then
       local full=v:GetAttribute('FullSize') or v.Size
       if type(full)=='number' then full=Vector3.one*full end
       local size=view.Size.Magnitude>.05 and view.Size or full
       e=self.cached[v];self.cached[v]=nil
       if e and (e.kind~=kind or e.view~=view) then freeGeometry(e);e=nil end
       if not e then
        local effectFolder=Instance.new('Folder');effectFolder.Name=kind..'_'..serial;effectFolder.Parent=self.folder;self.effectSlots+=1
        e={owner=self,resource=v,view=view,kind=kind,folder=effectFolder,parts={}}
       end
       e.serial=serial;e.start=start;e.duration=duration;e.impact=math.clamp(v:GetAttribute('EffectImpact') or .68,.1,.95)
       e.rockFrame=view.CFrame;e.rockSize=size
       if RockDamage then e.cf,e.size=RockDamage.basePose(view) else e.cf=view.CFrame;e.size=size end
       e.center=e.cf.Position;e.color=view.Color;e.material=view.Material
       e.biteIndex=math.clamp((v:GetAttribute('BubbleBites') or 0)+(done>0 and done>=start and 0 or 1),1,6)
       e.biteDepthBand=RockDamage and RockDamage.depthBand(v:GetAttribute('BubbleBites') or 0,v:GetAttribute('SmashDents') or 0,v:GetAttribute('DamageDepth')) or 0
       e.radius=math.max(e.size.X,e.size.Y,e.size.Z)*.5;e.originalTransparency=view.LocalTransparencyModifier
       e.lastPhase=nil;e.lastAge=nil;e.contactAge=nil
       e.tail=math.min(TAIL,duration*(1-e.impact)*.98)
       if #e.parts==0 then build(e) end
       self.active[v]=e;view.LocalTransparencyModifier=1
      elseif done<=0 then self.retry[v]=now+.1 end
     else self.retry[v]=now+.1 end
    end
   end
  end
  for v,e in pairs(self.active) do
   -- The first physical cut converts the old UnionOperation render into a
   -- MeshPart. Keep the ongoing bubble/tool tail and its original visibility
   -- lease attached to the resource's current local view across that swap.
   local latest=options.resolve and options.resolve(v) or nil
   if latest and latest.Parent and latest~=e.view then e.view=latest end
   if not v.Parent or not e.view.Parent or not v:GetAttribute('ResourceId') then remove(v)
   elseif e.tombstone then e.view.LocalTransparencyModifier=1
   elseif (v:GetAttribute('EffectCancelledSerial') or 0)>=e.serial then
    if v:GetAttribute('EffectDepleted')==true then concealDepleted(e) else remove(v) end
   elseif not nearby(v) then
    if v:GetAttribute('EffectDepleted')==true then concealDepleted(e) else remove(v);self.retry[v]=now+.2 end
   else
    local pausedAt=v:GetAttribute('EffectPausedAt') or 0
    local visualNow=pausedAt>0 and math.min(now,pausedAt) or now
    local done=v:GetAttribute('EffectDoneAt') or 0
    local impacted=done>0 and done>=e.start
    local depleted=impacted and v:GetAttribute('EffectDepleted')==true
    local age=impacted and math.max(0,visualNow-done) or nil
    if e.kind=='Bubbler' and impacted and RockDamage then
     e.biteDepthBand=RockDamage.depthBand(v:GetAttribute('BubbleBites') or 0,v:GetAttribute('SmashDents') or 0,v:GetAttribute('DamageDepth'))
    end
    e.visualNow=visualNow;e.contactAge=age
    -- The ordinary fracture queue owns surviving crystal size/pose immediately
    -- after the accepted hit. Keep only tool recovery over that view.
    e.view.LocalTransparencyModifier=(not impacted or depleted) and 1 or e.originalTransparency
    if age and age>=e.tail then
     if depleted then
      if not e.retired then freeGeometry(e);e.retired=true end
     else self.completed[v]=e.serial;remove(v,true) end
    elseif not e.retired then
     local t=impacted and math.min(1,e.impact+age/e.duration) or math.min(e.impact,clamp((visualNow-e.start)/e.duration))
     if t~=e.lastPhase or age~=e.lastAge then
      e.lastPhase=t;e.lastAge=age;self.poseUpdates+=1
      e.rock.CFrame=e.rockFrame;e.rock.Size=e.rockSize;e.rock.Color=e.color;e.rock.Transparency=impacted and 1 or 0
      poses[e.kind](e,t,age)
     end
     if visualNow-e.start>e.duration+3 then remove(v) end
    end
   end
  end
 end
 function self:destroy()
  if self.destroyed then return end;self.destroyed=true
  for v in pairs(self.active) do remove(v) end
  for v,e in pairs(self.cached) do freeGeometry(e);self.cached[v]=nil end
  for _,connection in pairs(self.tracked) do connection:Disconnect() end
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  table.clear(self.dirty);table.clear(self.retry);table.clear(self.tracked);table.clear(self.completed)
  self.folder:Destroy()
 end
 return self
end
return FX

end)()
local SpecialDroneMotion = (function()
-- Shared-time client tool articulation. No gameplay position, reach or damage.
-- The authored chassis stays in level flight; the working hardware has its own
-- readable preparation, quick contact and longer mechanically damped recovery.
local Motion={}
local roles={Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function stroke(t,loaded,contact)
 if t<=.52 then return loaded*smooth((t-.12)/.4) end
 if t<=.68 then local release=math.clamp((t-.52)/.16,0,1)^3;return loaded+(contact-loaded)*release end
 return contact*(1-smooth((t-.68)/.32))
end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end

function Motion.new(model,role)
 if not roles[role] then return nil end
 local record={model=model,role=role,parts={},scale=model:GetScale()}
 local pivot=model:GetPivot()
 for _,part in ipairs(model:GetDescendants()) do
  local kind=part:GetAttribute('SpecialMotion')
  if part:IsA('BasePart') and kind then
   record.parts[#record.parts+1]={part=part,kind=kind,side=part:GetAttribute('MotionSide') or 1,base=pivot:ToObjectSpace(part.CFrame),size=part.Size}
  end
 end
 return record
end

-- Pure phase evaluation is also used by deterministic frame-rate checks.
function Motion.phase(resource,id,now)
 if not resource or resource:GetAttribute('EffectDrone')~=id then return nil end
 local serial=resource:GetAttribute('EffectSerial') or 0
 local started=resource:GetAttribute('EffectStartedAt')
 local duration=resource:GetAttribute('EffectDuration')
 if serial<=0 or (resource:GetAttribute('EffectCancelledSerial') or 0)>=serial or not finite(started) or not finite(duration) or duration<=0 or not finite(now) then return nil end
 local paused=resource:GetAttribute('EffectPausedAt') or 0
 if paused>0 then now=math.min(now,paused) end
 if now<started or now>started+duration+.15 then return nil end
 return math.clamp((now-started)/duration,0,1)
end

local function offset(record,item,t)
 local k,s=item.kind,item.side
 local scale=record.scale
 if k=='Jaw' then
  -- Rotate the whole rigid jaw around its actual aft hinge, not its center.
  local hinge=Vector3.new(s*.95,.12,.45)*scale
  return CFrame.new(hinge)*CFrame.Angles(0,s*stroke(t,.20,-.065),0)*CFrame.new(-hinge)
 elseif k=='Scanner' then
  local scan=stroke(t,-.78,.88)
  return CFrame.new(0,0,scan*scale)
 elseif k=='Bulb' then
  return CFrame.new(0,stroke(t,.055,-.045)*scale,0)
 elseif k=='Valve' then
  return CFrame.new(0,stroke(t,.10,-.025)*scale,0)
 elseif k=='Nozzle' then
  return CFrame.new(0,stroke(t,.06,-.18)*scale,0)
 elseif k=='Containment' then
  local hinge=Vector3.new(0,.85,0)*scale
  return CFrame.new(hinge)*CFrame.Angles(0,stroke(t,.25,-.08),stroke(t,-.12,.045))*CFrame.new(-hinge)
 elseif k=='GravityCore' then
  return CFrame.new(0,stroke(t,.14,-.055)*scale,0)
 elseif k=='FurnaceCore' then
  return CFrame.new(0,stroke(t,.12,-.04)*scale,0)
 elseif k=='FurnaceCap' then
  return CFrame.new(0,stroke(t,.18,.04)*scale,0)
 elseif k=='HeatFin' then
  local angle=s*math.pi/2;local spread=stroke(t,.12,.025)*scale
  return CFrame.new(math.cos(angle)*spread,0,math.sin(angle)*spread)
 elseif k=='CryoTank' then
  return CFrame.new(s*stroke(t,.08,-.035)*scale,0,0)
 elseif k=='CryoNozzle' then
  return CFrame.new(0,0,stroke(t,.13,-.24)*scale)
 elseif k=='Fork' then
  return CFrame.new(0,stroke(t,.07,-.025)*scale,0)
 elseif k=='Prong' then
  -- One bounded deflection and decaying follow-through, never a noisy shake.
  local decay=t>.68 and math.exp(-(t-.68)*14)*math.sin((t-.68)*23) or 0
  return CFrame.new((s%2==0 and -1 or 1)*(stroke(t,.055,-.018)+decay*.018)*scale,0,0)
 end
 return CFrame.new()
end

function Motion.step(record,source,resource,now)
 if not record or not record.model.Parent then return end
 local state=source:GetAttribute('State')
 local id=source:GetAttribute('DroneId')
 if resource and resource:GetAttribute('EffectDrone')==id then record.resource=resource end
 -- The final contact clears TargetId, but its mechanical recoil still finishes
 -- during the server's bounded Recover hold. An explicit order cancels it.
 local recovering=state=='Recover' and record.resource and record.resource:GetAttribute('EffectDepleted')==true
 local active=state=='SpecialMine' or recovering
 local t=active and Motion.phase(resource or record.resource,id,now) or nil
 if t then
  record.cancelAt=nil
 elseif record.active then
  record.cancelAt=now
  for _,item in ipairs(record.parts) do item.cancel=record.model:GetPivot():ToObjectSpace(item.part.CFrame) end
 end
 local pivot=record.model:GetPivot()
 for _,item in ipairs(record.parts) do
  if item.part.Parent then
   if t then
    item.part.CFrame=pivot*offset(record,item,t)*item.base
   elseif record.cancelAt and now-record.cancelAt<.2 then
    item.part.CFrame=pivot*item.cancel:Lerp(item.base,smooth((now-record.cancelAt)/.2))
   else item.part.CFrame=pivot*item.base end
   -- Scaling pressure/core light subtly is secondary to the assembly's action.
   local swell=t and (item.kind=='Bulb' or item.kind=='GravityCore' or item.kind=='FurnaceCore') and stroke(t,.055,-.025) or 0
   item.part.Size=item.size*(1+swell)
  end
 end
 record.active=t~=nil
end
return Motion

end)()
local MotionBuffer = (function()
-- Render-only timeline. Never feeds a visual position back into gameplay.
local M={DELAY=.12,MAX_PREDICTION=.1}
function M.push(samples,at,pose,reset)
 if type(at)~='number' or not pose then return end
 local last=samples[#samples]
 if reset then table.clear(samples);last=nil end
 if last and at<=last.at then return end
 samples[#samples+1]={at=at,pose=pose}
 if #samples>6 then table.remove(samples,1) end
end
function M.pose(samples,now)
 local first=samples[1];if not first then return nil end
 local at=now-M.DELAY
 if at<=first.at then return first.pose end
 for i=2,#samples do
  local a,b=samples[i-1],samples[i]
  if at<=b.at then return a.pose:Lerp(b.pose,math.clamp((at-a.at)/(b.at-a.at),0,1)) end
 end
 local last=samples[#samples];local before=samples[#samples-1]
 if not before then return last.pose end
 local span=last.at-before.at
 local dt=math.clamp(at-last.at,0,M.MAX_PREDICTION)
 -- Bounded linear continuation bridges one late packet; long outages freeze.
 return last.pose+(last.pose.Position-before.pose.Position)*(dt/span)
end
return M

end)()
local RoleVisuals = (function()
-- Client-only role visuals. The server publishes compact effect descriptions.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}
local animations={}
local beamTimelines={}
local chargeTimelines={}
local pulseTimelines={}
local pulseCount=0
local eventAt=nil
local function clock() return eventAt or workspace:GetServerTimeNow() end
function Effects.setTime(at) eventAt=at end
local function animate(value,duration,style,direction,properties)
 local initial={};for key in pairs(properties) do initial[key]=value[key] end
 animations[value]={at=clock(),duration=duration,style=style,direction=direction,initial=initial,goal=properties}
end
function Effects.step(now)
 for root,t in pairs(pulseTimelines) do
  local q=(now-t.at)/t.duration
  if not root.Parent or q>=1 then root:Destroy();pulseTimelines[root]=nil;pulseCount-=1
  elseif q<0 or BeamVFX.reduced() then PlaneBurst.hide(t.plane)
  else
   -- Attack pressure is immediate and strongly braked. A contracting target
   -- mark instead accelerates into contact; neither is an expanding ball.
   local u=t.last>=t.first and (1-math.exp(-q*14))*.88+.12*q or q*q*q
   local radius=(t.first+(t.last-t.first)*u)*.5
   PlaneBurst.pose(t.plane,Vector3.yAxis,radius,t.sight and (.42+.5*q) or (1-q)^.7*.8,.035+.055*(1-q))
  end
 end
 for rig,t in pairs(beamTimelines) do
  local age=now-t.at
  if not rig.root.Parent or age>t.duration+rig.profile.tail then
   BeamVFX.destroy(rig);beamTimelines[rig]=nil
  elseif age<0 then BeamVFX.hide(rig)
  elseif age<t.duration then
   local expansion=math.min(1,age/.035)
   local collapse=1-math.clamp((age/t.duration-.62)/.38,0,1)
   BeamVFX.draw(rig,t.from,t.to,now,expansion*collapse,nil,age,t.scale)
  else BeamVFX.after(rig,t.from,t.to,now,age-t.duration,t.scale) end
 end
 for group,t in pairs(chargeTimelines) do
  if not group.Parent then BeamVFX.destroy(t.rig);chargeTimelines[group]=nil
  else
   local q=(now-t.at)/t.duration
   if q>=0 and q<1 then BeamVFX.draw(t.rig,t.position,t.position-Vector3.yAxis,now,0,q,nil)
   else BeamVFX.hide(t.rig,true) end
  end
 end
 for value,animation in pairs(animations) do
  if not value.Parent then animations[value]=nil
  else
   local t=math.clamp((now-animation.at)/animation.duration,0,1)
   local alpha=TweenService:GetValue(t,animation.style,animation.direction)
   for key,goal in pairs(animation.goal) do
    local first=animation.initial[key]
    value[key]=type(goal)=='number' and first+(goal-first)*alpha or first:Lerp(goal,alpha)
   end
   if t>=1 then animations[value]=nil end
  end
 end
end
local MAX_LIVE = 256
local live = 0
local ENERGY='rbxasset://textures/ui/VR/circleWhite.png'
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local ORBITAL_HEIGHT=260
local ORBITAL_COLOR=Color3.new(1,1,1)
local ORBITAL_TAIL=4.4

local function folder(): Folder
	local existing = workspace:FindFirstChild("DroneRoleClientEffects")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "DroneRoleClientEffects"
	created.Parent = workspace
	return created
end

local function part(): Part?
	if live >= MAX_LIVE then
		return nil
	end
	local value = Instance.new("Part")
	value.Name = "RoleEffect"
	value.Anchored = true
	value.CanCollide = false
	value.CanQuery = false
	value.CanTouch = false
	value.CastShadow = false
	value.Material = Enum.Material.Neon
	value.Parent = folder()
	live += 1
	local counted = true
	value.Destroying:Connect(function()
		if counted then
			counted = false
			live -= 1
		end
	end)
	return value
end

function Effects.Beam(from: Vector3, to: Vector3, color: Color3, width: number?, lifetime: number?, style: string?)
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return
	end
	local duration = lifetime or 0.16
	local thickness = width or 0.18
	local at=clock();local now=workspace:GetServerTimeNow()
	local profile=BeamVFX.styles[style or 'Lance'] or BeamVFX.styles.Lance
	if now-at>duration+profile.tail then return end
	local rig=BeamVFX.new(folder(),style or 'Lance',color)
	if rig then
	 beamTimelines[rig]={at=at,duration=duration,from=from,to=to,scale=thickness/profile.body}
	elseif now-at<duration then
	 -- Saturated cosmetic budget retains a simple readable shot.
	 local value=part();if not value then return end
	 value.Color=color;value.Size=Vector3.new(thickness*.35,thickness*.35,delta.Magnitude)
	 value.CFrame=CFrame.lookAt(from:Lerp(to,.5),to);value.Transparency=.45
	 animate(value,math.max(.01,duration-(now-at)),Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Transparency=1})
	 Debris:AddItem(value,math.max(.01,duration-(now-at))+.05)
	end
end

function Effects.Pulse(position: Vector3, color: Color3, startSize: number?, endSize: number?, lifetime: number?)
 local duration=math.max(.01,lifetime or .3)
 local at=clock()
 if pulseCount>=24 or workspace:GetServerTimeNow()-at>=duration or not BeamVFX.near(position,140) or BeamVFX.reduced() then return end
 local value=part();if not value then return end
 pulseCount+=1
 value.Name='RolePressureFront';value.Transparency=1;value.Size=Vector3.one*.025;value.Position=position
 pulseTimelines[value]={at=at,duration=duration,first=startSize or .8,last=endSize or 5,plane=PlaneBurst.create(value,color)}
 Debris:AddItem(value,duration+.05)
end

function Effects.Heal(from: Vector3, to: Vector3)
	local color = Color3.fromRGB(99, 255, 164)
	Effects.Beam(from, to, color, 0.14, 0.2,'Repair')
	Effects.Pulse(to, color, 0.5, 2.5, 0.24)
end

function Effects.Charge(position: Vector3, target: Vector3, impact: boolean?)
	local color = Color3.fromRGB(255, 137, 70)
	if impact then
		Effects.Beam(position, target, color, 0.3, 0.2,'Combat')
		Effects.Pulse(target, color, .7, 4.2, 0.28)
	else
		Effects.Pulse(position, Color3.fromRGB(255, 218, 105), 0.5, 3.4, 0.8)
	end
end

-- Seeding dust falls from the actual grower; the bloom confirms a real spawn.
function Effects.Grow(from: Vector3,target: Vector3,planted: boolean)
 if BeamVFX.reduced() then return end
 local green=Color3.fromRGB(152,231,158)
 local value=part();if not value then return end
 value.Name=planted and 'CrystalSeedBloom' or 'CrystalSeedFall';value.Transparency=1
 if planted then value:SetAttribute('AudioCue','plant');value:SetAttribute('AudioAt',clock()) end
 value.Position=planted and target or from
 local tip=Instance.new('Attachment');tip.Parent=value
 local dust=Instance.new('ParticleEmitter');dust.Texture=SPARK
 dust.Rate=0;dust.Color=ColorSequence.new(green);dust.LightEmission=1;dust.Brightness=.95;dust.LightInfluence=0
 dust.Lifetime=NumberRange.new(1,1.6);dust.Speed=NumberRange.new(planted and 3 or 1,planted and 5 or 2)
 dust.EmissionDirection=planted and Enum.NormalId.Top or Enum.NormalId.Bottom;dust.SpreadAngle=Vector2.new(22,22)
 dust.Acceleration=Vector3.new(0,planted and .1 or -.3,0);dust.Drag=planted and 8 or 3;dust.WindAffectsDrag=false
 dust.Rotation=NumberRange.new(-180,180);dust.RotSpeed=NumberRange.new(-65,65)
 dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.14,.02),NumberSequenceKeypoint.new(.2,.24,.03),NumberSequenceKeypoint.new(1,0)})
 dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.45,.55),NumberSequenceKeypoint.new(1,1)})
 dust.Parent=tip;dust:Emit(planted and 14 or 9);Debris:AddItem(value,1.8)
 if planted then Effects.Pulse(target+Vector3.new(0,.25,0),green,.2,1.6,.45) end
end

-- These are one-shot phase cues. The authoritative drone moves through its
-- windup/dive/recovery; none of these effects is a steady mining beam.
function Effects.BreakerPhase(position: Vector3,target: Vector3,phase: string,diameter: number?)
 local amber=Color3.fromRGB(220,164,81)
 local scale=math.clamp((diameter or 3)/3,.65,3)
 if phase=='Windup' then
  Effects.Pulse(target,amber,.2*scale,2.4*scale,.75)
 elseif phase=='Dive' then
  Effects.Pulse(target,Color3.fromRGB(239,211,154),2*scale,.25*scale,.25)
 elseif phase=='Impact' then
  local cue=part();if cue then cue.Name='ConfirmedMiningImpact';cue.Transparency=1;cue.Position=target;cue:SetAttribute('MiningImpact','Breaker');cue:SetAttribute('ImpactAt',clock());Debris:AddItem(cue,1) end
  Effects.Pulse(target,Color3.fromRGB(244,207,142),.35*scale,4.6*scale,.26)
  local shock=not BeamVFX.reduced() and part() or nil
  if shock then
   shock.Name='BreakerPressureWave';shock.Shape=Enum.PartType.Cylinder;shock.Color=Color3.fromRGB(221,196,142)
   shock.Transparency=1;shock.Size=Vector3.new(.055,.6,.6);shock.CFrame=CFrame.new(target)*CFrame.Angles(0,0,math.pi/2)
   local attachment=Instance.new('Attachment');attachment.CFrame=CFrame.Angles(0,0,-math.pi/2);attachment.Parent=shock
   local dust=Instance.new('ParticleEmitter');dust.Name='BreakerDust';dust.Texture=SMOKE
   dust.Color=ColorSequence.new(Color3.fromRGB(118,108,91));dust.LightEmission=0;dust.LightInfluence=.65;dust.Brightness=1
   dust.Rate=0;dust.Lifetime=NumberRange.new(1,1.6)
   dust.Speed=NumberRange.new(4,7);dust.Drag=10;dust.Acceleration=Vector3.new(0,.25,0);dust.WindAffectsDrag=false
   dust.Rotation=NumberRange.new(-180,180);dust.RotSpeed=NumberRange.new(-50,50)
   dust.EmissionDirection=Enum.NormalId.Top;dust.SpreadAngle=Vector2.new(80,80)
   dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.2,.04),NumberSequenceKeypoint.new(.3,.5,.08),NumberSequenceKeypoint.new(1,.75,.1)})
   dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(.3,.45),NumberSequenceKeypoint.new(1,1)});dust.Parent=attachment;dust:Emit(16)
   Effects.Pulse(target,amber,.6*scale,6.4*scale,.65)
   Debris:AddItem(shock,1.8)
  end
  -- The actual fracture creates authored crystal fragments in Presentation.
  -- Avoid a second shower of generic weightless balls on the same event.
 elseif phase=='Hold' then
  -- This is physical touchdown, distinct from the later damaging fracture.
  -- A single server receipt drives both the local thud and camera impulse.
  local cue=part();if cue then cue.Name='ConfirmedBreakerContact';cue.Transparency=1;cue.Position=target;cue:SetAttribute('MiningImpact','BreakerContact');cue:SetAttribute('ImpactAt',clock());Debris:AddItem(cue,1) end
  Effects.Pulse(target,Color3.fromRGB(244,211,155),.3*scale,2.5*scale,.17)
  Effects.Pulse(target,Color3.fromRGB(255,206,107),.2*scale,1.1*scale,.9)
 elseif phase=='Recover' then
  Effects.Pulse(position,Color3.fromRGB(168,155,123),.15,.7,.2)
 end
end

-- Gadget FX are consequences of the authoritative DroneAbilities state machine.
-- RoleEffectView supplies the replicated intent; no local pose feeds damage.
local swarms: {[any]: Folder} = {}
local markers: {[any]: Instance} = {}
local function clearSwarm(owner: any)
 local old=swarms[owner]
 if old then swarms[owner]=nil;old:Destroy() end
end
local function clearMarker(owner: any)
 local old=markers[owner];markers[owner]=nil
 if old then old:Destroy() end
end
local function location(p: any): Vector3 return Vector3.new(p.x,p.y,p.z) end
local function column(position: Vector3,height: number,width: number,color: Color3,duration: number)
 Effects.Beam(position+Vector3.yAxis*height,position,color,width,duration,'Resonance')
end
local burns: {[any]: Folder} = {}
local function clearBurn(owner: any)
 local old=burns[owner];burns[owner]=nil
 if not old or not old.Parent then return end
 -- Stop work immediately, but let the column collapse into suspended embers.
 -- Every observer evaluates the same authoritative end time locally.
 old:SetAttribute('EndedAt',clock())
 for _,effect in ipairs(old:GetDescendants()) do
  if effect:IsA('ParticleEmitter') then effect.Enabled=false end
 end
 local core=old:FindFirstChild('MeltCore')
 if core and core:IsA('BasePart') then
  -- A full volume leaves a continuous vertical trail, rather than twelve
  -- isolated pairs of dots. Its fixed carrier must not shrink with the laser.
  local trail=part()
  if trail then
   trail.Name='OrbitalResidualColumn';trail.Transparency=1;trail.Shape=Enum.PartType.Cylinder
   trail.Size=Vector3.new(ORBITAL_HEIGHT,.68,.68);trail.CFrame=core.CFrame;trail.Parent=old
   local embers=Instance.new('ParticleEmitter');embers.Name='OrbitalAfterglow'
   embers.Texture=ENERGY;embers.Enabled=false;embers.Rate=0;embers.LightEmission=.8;embers.LightInfluence=0;embers.Brightness=1.1
   embers.Color=ColorSequence.new(ORBITAL_COLOR)
   embers.Shape=Enum.ParticleEmitterShape.Cylinder;embers.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
   embers.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward;embers.ShapePartial=1;embers.EmissionDirection=Enum.NormalId.Right
   embers.Lifetime=NumberRange.new(2.5,4);embers.Speed=NumberRange.new(.05,.35);embers.Drag=2.5;embers.WindAffectsDrag=false
   embers.LockedToPart=false;embers.VelocityInheritance=0
   embers.SpreadAngle=Vector2.new(180,180);embers.Rotation=NumberRange.new(-180,180);embers.RotSpeed=NumberRange.new(-45,45)
   embers.Acceleration=Vector3.new(0,.08,0)
   embers.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16,.04),NumberSequenceKeypoint.new(.2,.3,.06),NumberSequenceKeypoint.new(1,0)})
   embers.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(.55,.55),NumberSequenceKeypoint.new(1,1)})
   embers.Parent=trail;embers:Emit(312)
  end
 end
 for _,value in ipairs(old:GetChildren()) do if value:IsA('BasePart') and value.Name~='OrbitalResidualColumn' then
  local size=value.Name=='MeltContact' and Vector3.one*.03 or Vector3.new(value.Size.X,.015,.015)
  animate(value,.48,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{Size=size,Transparency=1})
 end end
 Debris:AddItem(old,ORBITAL_TAIL)
end
-- A fixed timer from the strike's creation could cut off its last motes after
-- a storage pause. One watchdog per live group instead begins cleanup only
-- after contacts stop, then preserves a full final particle lifetime.
local function watchBurn(owner: any,group: Folder)
 task.delay(8,function()
  if not group.Parent or group:GetAttribute('EndedAt') then return end
  local at=group:GetAttribute('ContactAt') or 0
  if clock()-at<8 then watchBurn(owner,group);return end
  if burns[owner]==group then burns[owner]=nil end
  group:SetAttribute('EndedAt',clock())
  for _,object in ipairs(group:GetDescendants()) do
   if object:IsA('ParticleEmitter') then object.Enabled=false
   elseif object:IsA('BasePart') then object.Transparency=1 end
  end
  Debris:AddItem(group,ORBITAL_TAIL)
 end)
end
local function targetSight(owner: any,target: any,duration: number?)
 local group=Instance.new('Folder');group.Name='OrbitalTargetSight';group.Parent=folder();markers[owner]=group
 local value=part();local cue=part()
 if not value or not cue then if value then value:Destroy() end;if cue then cue:Destroy() end;group:Destroy();return end
 local seconds=duration or 2.4
 local radius=math.clamp((target.radius or 1)*1.5,1.65,12)
 local floor=Vector3.new(target.x,(target.ground or target.y)+.065,target.z)
 local red=Color3.fromRGB(255,40,48)
 value.Name='ThinRedSight';value.Shape=Enum.PartType.Cylinder;value.Color=red;value.Transparency=.28
 value.Size=Vector3.new(ORBITAL_HEIGHT,.052,.052)
 value.CFrame=CFrame.new(floor+Vector3.yAxis*(ORBITAL_HEIGHT*.5))*CFrame.Angles(0,0,math.pi/2)
 value.Parent=group
 cue.Name='OrbitalFootprint';cue.Transparency=1;cue.Size=Vector3.one*.025;cue.Position=floor;cue.Parent=group
 cue:SetAttribute('AudioLoop','orbital_charge');cue:SetAttribute('AudioAt',clock());cue:SetAttribute('AudioUntil',clock()+seconds)
 if not BeamVFX.reduced() and pulseCount<24 then
  pulseCount+=1
  pulseTimelines[cue]={at=clock(),duration=seconds,first=radius*2.85,last=radius*2,plane=PlaneBurst.create(cue,red),sight=true}
 end
 local rig=BeamVFX.new(group,'Orbital',Color3.fromRGB(172,113,255))
 if rig then
  local camera=workspace.CurrentCamera
  local height=math.max(260,(camera and camera.CFrame.Position.Y or target.y)-target.y+180)
  chargeTimelines[group]={rig=rig,at=clock(),duration=seconds,position=floor+Vector3.yAxis*height}
 end
 animate(value,seconds,Enum.EasingStyle.Sine,Enum.EasingDirection.In,{Transparency=.06})
 Debris:AddItem(group,seconds+1.15)
end
local function sustainedStrike(owner: any,event: any)
 local group=burns[owner]
 if group and not group.Parent then burns[owner]=nil;group=nil end
 if not group then
  group=Instance.new('Folder');group.Name='OrbitalMelt';burns[owner]=group
  group:SetAttribute('OrbitalBurn',true)
  group:SetAttribute('StartedAt',event.startedAt or clock())
  local radius=math.clamp(event.target.radius or 1,1,8)
  local floor=Vector3.new(event.target.x,(event.target.ground or event.target.y)+.045,event.target.z)
  local age=workspace:GetServerTimeNow()-(event.startedAt or clock())
  if age<.32 then
   Effects.Pulse(floor,Color3.fromRGB(202,168,255),radius*1.25,radius*4.8,.88)
   Effects.Pulse(location(event.target),ORBITAL_COLOR,radius*.45,radius*2.7,.52)
  end
  local scale=math.clamp(.75+radius*.2,1,1.85)
  for index,width in ipairs({.78*scale,.18*scale}) do
   local value=part();if not value then break end
   value.Name=index==1 and 'MeltHalo' or 'MeltCore';value.Shape=Enum.PartType.Cylinder
   value.Color=index==1 and Color3.fromRGB(155,94,245) or ORBITAL_COLOR
   value.Transparency=index==1 and .88 or .17;value.Size=Vector3.new(ORBITAL_HEIGHT,width,width);value.Parent=group
   value:SetAttribute('BurnTransparency',value.Transparency)
   if index==2 then
    local energy=Instance.new('ParticleEmitter');energy.Name='TurbulentColumnEnergy';energy.Texture=ENERGY
    energy.Color=ColorSequence.new(ORBITAL_COLOR);energy.LightEmission=1;energy.LightInfluence=0;energy.Brightness=1.25
    energy.Rate=10;energy.Lifetime=NumberRange.new(2,3.5);energy.Speed=NumberRange.new(.4,1.4);energy.Drag=1.8
    energy.Shape=Enum.ParticleEmitterShape.Cylinder;energy.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume;energy.EmissionDirection=Enum.NormalId.Right
    energy.SpreadAngle=Vector2.new(180,180);energy.Acceleration=Vector3.new(0,-.1,0);energy.WindAffectsDrag=false
    energy.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16,.04),NumberSequenceKeypoint.new(.15,.32,.06),NumberSequenceKeypoint.new(1,0)})
    energy.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.32),NumberSequenceKeypoint.new(.5,.6),NumberSequenceKeypoint.new(1,1)});energy.Parent=value
   end
  end
  local contact=part()
  if contact then
   contact.Name='MeltContact';contact.Shape=Enum.PartType.Ball;contact.Color=ORBITAL_COLOR
   contact.Transparency=.56;contact.Size=Vector3.one*(.55*scale);contact.Parent=group;contact:SetAttribute('BurnTransparency',.56)
   local tip=Instance.new('Attachment');tip.Parent=contact
   local sparks=Instance.new('ParticleEmitter');sparks.Name='MoltenSparks';sparks.Texture=SPARK;sparks.Squash=NumberSequence.new(.65);sparks.Rotation=NumberRange.new(-180,180)
   sparks.Color=ColorSequence.new(ORBITAL_COLOR);sparks.LightEmission=1;sparks.LightInfluence=0;sparks.Brightness=1.15
   sparks.Lifetime=NumberRange.new(2,3.5);sparks.Speed=NumberRange.new(.8,2);sparks.Drag=2.2;sparks.WindAffectsDrag=false
   sparks.Acceleration=Vector3.new(0,-.4,0);sparks.EmissionDirection=Enum.NormalId.Top;sparks.SpreadAngle=Vector2.new(60,60)
   sparks.Rate=8;sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.14,.03),NumberSequenceKeypoint.new(.12,.28,.04),NumberSequenceKeypoint.new(1,0)})
   sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.48),NumberSequenceKeypoint.new(.5,.68),NumberSequenceKeypoint.new(1,1)});sparks.Parent=tip
  end
  group:SetAttribute('Position',location(event.target));group:SetAttribute('ContactAt',clock())
  group.Parent=folder();watchBurn(owner,group)
 end
 local position=location(event.target)
 local ground=Vector3.new(position.X,(event.target.ground or position.Y)+.045,position.Z)
 group:SetAttribute('Position',position);group:SetAttribute('ContactAt',clock())
 local fresh=workspace:GetServerTimeNow()-clock()<=.3
 local suspended=not fresh
 if group:GetAttribute('Suspended')~=suspended then
  group:SetAttribute('Suspended',suspended)
  for _,v in ipairs(group:GetDescendants()) do if v:IsA('ParticleEmitter') then v.Enabled=fresh end end
 end
 for _,value in ipairs(group:GetChildren()) do if value:IsA('BasePart') then
  local pose=value.Name=='MeltContact' and CFrame.new(position) or CFrame.new(ground+Vector3.new(0,ORBITAL_HEIGHT*.5,0))*CFrame.Angles(0,0,math.pi/2)
  value.CFrame=pose
  value.Transparency=not fresh and 1 or (value:GetAttribute('BurnTransparency') or value.Transparency)
 end end
 group:SetAttribute('Placed',true)
end
function Effects.ClearAbility(owner: any)
 clearSwarm(owner);clearMarker(owner);clearBurn(owner)
end
function Effects.Ability(owner: any,event: any,template: Model?)
 local kind=event.kind
 if kind=='clear' then Effects.ClearAbility(owner)
 elseif kind=='clearCharge' then clearMarker(owner)
 elseif kind=='clearScrap' then clearSwarm(owner)
 elseif kind=='orbitalEnd' then clearBurn(owner)
 elseif kind=='charge' then
  clearMarker(owner)
  if event.ability=='Orbital' then targetSight(owner,event.target,event.duration);return end
  local value=part();if not value then return end
  value.Name='GadgetCharge';value.Shape=Enum.PartType.Ball;value.Size=Vector3.one*.45
  value:SetAttribute('AudioLoop','swarm_charge');value:SetAttribute('AudioAt',clock());value:SetAttribute('AudioUntil',clock()+2.6)
  value.Color=event.ability=='Orbital' and Color3.fromRGB(240,173,88) or Color3.fromRGB(178,202,151)
  value.Transparency=.7;value.Position=location(event.target)+Vector3.new(0,5,0)
  markers[owner]=value;Debris:AddItem(value,2.6)
 elseif kind=='orbital' then
  clearMarker(owner)
  sustainedStrike(owner,event)
 elseif kind=='relay' then
  local position=location(event.target)
  column(position,9,.18,Color3.fromRGB(176,218,255),.3)
  Effects.Pulse(position,Color3.fromRGB(176,218,255),.2,1.7,.3)
 elseif kind=='scrapStart' then clearMarker(owner)
 elseif kind=='recycle' then Effects.Pulse(location(event.target),Color3.fromRGB(173,222,146),.4,2.8,.4)

 end
end

function Effects.destroy()
 for rig in pairs(beamTimelines) do BeamVFX.destroy(rig) end
 for _,t in pairs(chargeTimelines) do BeamVFX.destroy(t.rig) end
 table.clear(beamTimelines);table.clear(chargeTimelines)
 table.clear(animations)
 for root in pairs(pulseTimelines) do root:Destroy() end;table.clear(pulseTimelines);pulseCount=0;table.clear(markers);table.clear(burns);table.clear(swarms)
 eventAt=nil
 local root=workspace:FindFirstChild('DroneRoleClientEffects');if root then root:Destroy() end
end
return Effects


end)()
local RoleEffectView = (function()
-- Observe server-authored receipts. Every client renders locally, regardless
-- of ownership. State records also cover late joins and canceled abilities.
local View={}
function View.new()
 local self={records={},connections={},root=nil}
 local function attach(root)
  if self.root==root then return end
  self.root=root
  local function observe(node)
   if node:IsA('Folder') then self.records[node]={samples={}} end
  end
  for _,node in ipairs(root:GetChildren()) do observe(node) end
  self.connections[#self.connections+1]=root.ChildAdded:Connect(observe)
 end
 local root=workspace:FindFirstChild('DroneRoleState');if root then attach(root) end
 self.connections[#self.connections+1]=workspace.ChildAdded:Connect(function(node) if node.Name=='DroneRoleState' then attach(node) end end)
 function self:step(now)
  for node,r in pairs(self.records) do
   local kind=node:GetAttribute('Kind');local owner=node -- isolate overlapping old/new effects for the same player
   if not node.Parent then
    if r.started and kind=='AbilityCharge' then RoleVisuals.Ability(owner,{kind='clearCharge'}) end
    if r.started and kind=='Orbital' and not r.ended then RoleVisuals.Ability(owner,{kind='orbitalEnd'}) end
    self.records[node]=nil
   elseif kind=='Orbital' then
    local at=node:GetAttribute('ContactAt');local position=node:GetAttribute('Position');local ended=node:GetAttribute('EndedAt')
    if typeof(position)=='Vector3' and type(at)=='number' and now>=at then
     MotionBuffer.push(r.samples,at,CFrame.new(position))
     local pose=MotionBuffer.pose(r.samples,now)
     -- Do not replay completed strikes to a late joiner.
     if not ended or r.started then
      if not r.ended then
       RoleVisuals.setTime(at)
       RoleVisuals.Ability(owner,{kind='orbital',startedAt=node:GetAttribute('StartedAt') or at,target={x=pose.Position.X,y=pose.Position.Y,z=pose.Position.Z,
        ground=node:GetAttribute('Ground'),radius=node:GetAttribute('Radius')}})
       r.started=true
       if ended then RoleVisuals.setTime(ended);RoleVisuals.Ability(owner,{kind='orbitalEnd'});r.ended=true end
      end
     end
    end
   elseif not r.started and kind and kind~='ScrapSwarm' then
    local at=node:GetAttribute('StartedAt');local position=node:GetAttribute('Position')
    local from=node:GetAttribute('From')
    local needsFrom=kind=='Beam' or kind=='Heal' or kind=='Charge' or kind=='Grow' or kind=='Breaker'
    local ready=not needsFrom or typeof(from)=='Vector3'
    if kind=='Beam' or kind=='Pulse' then ready=ready and node:GetAttribute('Color')~=nil and type(node:GetAttribute('Duration'))=='number' end
    if kind=='Beam' then ready=ready and type(node:GetAttribute('Width'))=='number' end
    if kind=='Pulse' then ready=ready and type(node:GetAttribute('First'))=='number' and type(node:GetAttribute('Last'))=='number' end
    if kind=='Grow' then ready=ready and type(node:GetAttribute('Planted'))=='boolean' end
    if kind=='Charge' then ready=ready and type(node:GetAttribute('Impact'))=='boolean' end
    if kind=='Breaker' then ready=ready and type(node:GetAttribute('Phase'))=='string' end
    if kind=='AbilityCharge' or kind=='AbilityPulse' then ready=ready and type(node:GetAttribute('Ability'))=='string' end
    if ready and type(at)=='number' and typeof(position)=='Vector3' and now>=at then
     r.started=true
     local age=now-at
     local expires=node:GetAttribute('ExpiresAt') or at+1
     -- Short contact cues are never replayed as fresh hits after a late join.
     if now<expires and (age<=.35 or kind=='AbilityCharge' or kind=='Pulse' or kind=='Beam') then
      RoleVisuals.setTime(at)
      local from=node:GetAttribute('From');local color=node:GetAttribute('Color')
      if kind=='Beam' then RoleVisuals.Beam(from,position,color,node:GetAttribute('Width'),node:GetAttribute('Duration'))
      elseif kind=='Pulse' then RoleVisuals.Pulse(position,color,node:GetAttribute('First'),node:GetAttribute('Last'),node:GetAttribute('Duration'))
      elseif kind=='Heal' then RoleVisuals.Heal(from,position)
      elseif kind=='Charge' then RoleVisuals.Charge(from,position,node:GetAttribute('Impact'))
      elseif kind=='Grow' then RoleVisuals.Grow(from,position,node:GetAttribute('Planted'))
      elseif kind=='Breaker' then RoleVisuals.BreakerPhase(from,position,node:GetAttribute('Phase'),node:GetAttribute('Diameter'))
      elseif kind=='AbilityCharge' or kind=='AbilityPulse' then
       RoleVisuals.Ability(owner,{kind=kind=='AbilityCharge' and 'charge' or node:GetAttribute('Ability'),ability=node:GetAttribute('Ability'),duration=node:GetAttribute('Duration') or 1.4,target={x=position.X,y=position.Y,z=position.Z,ground=node:GetAttribute('Ground'),radius=node:GetAttribute('Radius')}})
      end
     end
    end
   end
  end
  RoleVisuals.setTime(nil);RoleVisuals.step(now)
 end
 function self:destroy()
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  table.clear(self.records);RoleVisuals.destroy()
 end
 return self
end
return View

end)()
local Presentation = (function()
-- Client-only animation and cosmetic debris. No remotes, damage or rewards.
-- Feedback is bundled immediately before this module by tools/build.py.
local P={};P.__index=P
local F=Feedback
local S=SentryMotion
local ICE=Color3.fromRGB(126,241,221)
local HOT=Color3.fromRGB(255,179,102)
local WHITE=Color3.fromRGB(255,249,230)
local RUIN=Color3.fromRGB(34,61,67)
local miningLooks={
 Cutter={color=Color3.fromRGB(255,208,69),core=Color3.fromRGB(255,244,179),width0=1.05,width1=.78},
 Percussion={color=Color3.fromRGB(245,105,85),core=Color3.fromRGB(255,226,202),width0=.85,width1=.72},
 Resonance={color=Color3.fromRGB(104,224,146),core=Color3.fromRGB(221,255,227),width0=.9,width1=.68},
}
local miningTypeColors={Dart=Color3.fromRGB(45,224,255),Striker=Color3.fromRGB(255,210,86),
 Medic=Color3.fromRGB(99,255,164),Charger=Color3.fromRGB(255,112,72)}
local segmentRanks={bottemseg=0,lowerseg=1,upperseg=2,topseg=3,eye=1,eyecase=1,spawnEye=1}
local requiredSegments={'bottemseg','lowerseg','upperseg','topseg','eye','eyecase','spawnEye'}
local function finalContact(sample,now)
 if sample.breakContactAt==nil then return sample,false end
 local at,untilAt=sample.breakContactAt,sample.breakContactUntil
 local valid=type(at)=='number' and type(untilAt)=='number' and at==at and untilAt==untilAt
  and now>=at and now<math.min(untilAt,at+.3) and sample.alive and not sample.paused
  and sample.part and sample.part.Parent and sample.part.Transparency<1
 if valid then return sample,true end
 local expired=table.clone(sample);expired.active=false;expired.key=nil;expired.part=nil
 expired.secondaryPart=nil;expired.secondaryKey=nil
 return expired,false
end
local function snapshot(source)
 return {state=source:GetAttribute('State'),life=source:GetAttribute('Life'),hp=source:GetAttribute('HP'),
  dead=source:GetAttribute('Dead'),serial=source:GetAttribute('ShotSerial') or 0}
end
local function passive(part)
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.LocalTransparencyModifier=0
end
local function clean(model)
 for _,object in ipairs(model:GetDescendants()) do
  if object:IsA('LuaSourceContainer') or object:IsA('BillboardGui') or object:IsA('SurfaceGui')
   or object:IsA('JointInstance') or object:IsA('WeldConstraint') or object:IsA('Constraint')
   or object:IsA('AnimationController') or object.Name=='AnimSaves' then object:Destroy()
  elseif object:IsA('BasePart') then passive(object)
  elseif object:IsA('Beam') or object:IsA('Trail') or object:IsA('ParticleEmitter') then object.Enabled=false end
 end
end
local function partsOf(model)
 local parts={};local pivot=model:GetPivot()
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA('BasePart') then
   table.insert(parts,{part=part,relative=pivot:ToObjectSpace(part.CFrame),frame=part.CFrame,
    color=part.Color,material=part.Material,transparency=part.Transparency,size=part.Size})
  end
 end
 table.sort(parts,function(a,b) return a.part.Name<b.part.Name end)
 return parts
end
local function barePart(parent,name)
 local part=Instance.new('Part');part.Name=name;passive(part);part.Material=Enum.Material.Neon
 part.CastShadow=false
 part.Parent=parent;return part
end
function P.new(options)
 assert(options and options.parent,'Presentation needs a local effect parent')
 return setmetatable({parent=options.parent,audio=options.audio,work=WorkEffects.new(options.parent),drones={},turrets={},fragments={},pulses={},scanCount=0,
  maxFragments=48,maxPulses=8,maxScans=8,beamRays=0,maxBeamRays=12,beamQueue={},beamOrder=0,closed=false},P)
end
-- One budget per render frame; cached anchors remain in the visible part's local
-- coordinates between queries, so a shrinking or tilted crystal carries its impact.
function P:beginFrame()
 self.beamRays=0;self.beamQueue={}
end
local function newLaserLayer(parent,name,color)
 return WorkEffects.newCylinder(parent,name,color)
end
local function branchOrigin(beam,part,point,normal)
 if beam.vertical then
  return Vector3.new(part.Position.X,math.max(beam.origin.WorldPosition.Y,part.Position.Y+part.Size.Magnitude*.5+.3),part.Position.Z)
 end
 return point+normal*.08
end
function P:createMiningBeam(view,emitter)
 local holder=Instance.new('Folder');holder.Name='MiningBeam';holder.Parent=self.parent
 local muzzle=Instance.new('Attachment');muzzle.Name='RenderedMuzzle';muzzle.Parent=emitter
 local body=view.PrimaryPart
 local optic=view:FindFirstChild('MiningOptic')
 if optic and optic:IsA('BasePart') then
  local exit=optic.CFrame:PointToWorldSpace(Vector3.new(-optic.Size.X*.5,0,0))
  muzzle.Position=emitter.CFrame:PointToObjectSpace(exit)
 elseif body then
  -- Keep the captured emission point for rigs with no separate visible optic.
  local bottom=body.CFrame:PointToWorldSpace(Vector3.new(0,-body.Size.Y*.5,0))
  muzzle.Position=emitter.CFrame:PointToObjectSpace(bottom)
 end
 local endpoint=barePart(holder,'MiningEndpoint');endpoint.Size=Vector3.one*.05;endpoint.Transparency=1
 local impact=barePart(holder,'ContactLight');impact.Shape=Enum.PartType.Ball
 impact.Size=Vector3.one*.14;impact.Transparency=1;impact.Color=ICE
 local extra=barePart(holder,'SecondaryEndpoint');extra.Size=Vector3.one*.05;extra.Transparency=1
 local halo=newLaserLayer(holder,'OuterBeam',ICE)
 local core=newLaserLayer(holder,'InnerBeam',WHITE)
 local branch=newLaserLayer(holder,'SecondaryBeam',ICE)
 return {holder=holder,origin=muzzle,endpoint=endpoint,marker=impact,secondaryPoint=extra,
  core=core,halo=halo,secondary=branch,envelope=F.newBeam(),surface={},secondarySurface={},lastKey=nil,lastKind=nil}
end
function P:destroyMiningBeam(beam)
 if not beam then return end
 if self.audio and self.audio.stopLoop then self.audio:stopLoop(beam) end
 self.work:destroyMining(beam)
 BeamVFX.destroy(beam.vfx);BeamVFX.destroy(beam.branchVFX)
 if beam.origin then beam.origin:Destroy() end
 if beam.holder then beam.holder:Destroy() end
end
-- Mining Away attaches its beam to an off-center marker on Crystal.Mesh.
-- Keep its authored X/Z proportions; sample the actual visible surface below
-- that marker so damage geometry cannot leave the tip suspended above it.
local CRYSTAL_AIM_X = -.5675010681152344 / 3.135000228881836
local CRYSTAL_AIM_Z = -.24361419677734375 / 4.4872307777404785
local function followsCrystal(sample)
 return sample.isMining==true and sample.serverSource~=nil and sample.serverSource:GetAttribute('CubicRock')==false
end
function P:_surface(beam,cache,origin,part,serverSource,now,ignoredSource,noQuery,vertical)
 if not part or not part.Parent or part.Transparency>=1 then cache.anchor=nil;return nil end
 if cache.part~=part then cache.part=part;cache.anchor=nil;cache.nextSample=0;cache.dueSince=now;cache.lastSample=nil;cache.verifiedAt=nil;cache.fadeUntil=nil end
 if not noQuery and now>=(cache.nextSample or 0) and self.beamRays+2<=self.maxBeamRays then
  self.beamRays+=2;cache.nextSample=now+.08;cache.dueSince=cache.nextSample;cache.lastSample=now
  local attached=beam.followCrystal and cache==beam.surface
  local rayOrigin=origin
  local direction
  if attached then
   rayOrigin=part.CFrame:PointToWorldSpace(Vector3.new(CRYSTAL_AIM_X*part.Size.X,part.Size.Y*.5+.2,CRYSTAL_AIM_Z*part.Size.Z))
   direction=part.CFrame:VectorToWorldSpace(Vector3.new(0,-part.Size.Y-.4,0))
  else
   direction=vertical and Vector3.new(0,-math.max(.1,origin.Y-part.Position.Y+part.Size.Magnitude),0) or part.Position-origin
  end
  if direction.Magnitude<.01 then cache.anchor=nil;return nil end
  local include=RaycastParams.new();include.FilterType=Enum.RaycastFilterType.Include;include.FilterDescendantsInstances={part}
  -- Query the local rendered union/mesh, not the untouched server collider. The
  -- temporary query flag is reset even if the engine rejects the query.
  local previous=part.CanQuery;part.CanQuery=true
  local ok,hit=pcall(function() return workspace:Raycast(rayOrigin,direction*1.5,include) end)
  part.CanQuery=previous
  if not ok or not hit or hit.Instance~=part then cache.anchor=nil;return nil end
  local exclude=RaycastParams.new();exclude.FilterType=Enum.RaycastFilterType.Exclude
  local ignored={self.parent};if serverSource then table.insert(ignored,serverSource) end
  if ignoredSource and ignoredSource~=serverSource then table.insert(ignored,ignoredSource) end
  exclude.FilterDescendantsInstances=ignored
  -- Closely scattered reference crystals are noncolliding. Resolve the
  -- contact on the assigned crystal while still respecting authored walls.
  if serverSource and serverSource:GetAttribute('ReferenceCrystal')==true then exclude.RespectCanCollide=true end
  local blocked=workspace:Raycast(origin,hit.Position-origin,exclude)
  if blocked and (blocked.Position-hit.Position).Magnitude>.12 then cache.anchor=nil;return nil end
  cache.anchor=F.surfaceAnchor(part.CFrame:PointToObjectSpace(hit.Position),part.Size)
  cache.normal=part.CFrame:VectorToObjectSpace(hit.Normal)
  cache.verifiedAt=now
 end
 -- A verified contact may bridge several frames of bounded contention, but it
 -- cannot remain visible indefinitely after a newly appeared obstruction.
 if cache.verifiedAt and now>math.max(cache.verifiedAt+.75,cache.fadeUntil or 0) then cache.anchor=nil;cache.normal=nil end
 if not cache.anchor or not cache.normal then return nil end
 local x,y,z=F.surfaceComponents(cache.anchor,part.Size)
 if not x then cache.anchor=nil;return nil end
 local point=part.CFrame:PointToWorldSpace(Vector3.new(x,y,z))
 local normal=part.CFrame:VectorToWorldSpace(cache.normal)
 if normal.Magnitude<.001 then return nil end
 normal=normal.Unit
 if vertical then
  -- Reproject the verified surface plane onto the current emitter's vertical
  -- line. Shrink/rotation cannot steer the laser sideways between ray samples.
  if normal.Y<.1 then return nil end
  local y=point.Y+(normal.X*(point.X-origin.X)+normal.Z*(point.Z-origin.Z))/normal.Y
  point=Vector3.new(origin.X,y,origin.Z)
  local localPoint=part.CFrame:PointToObjectSpace(point)
  if y>=origin.Y or math.abs(localPoint.X)>part.Size.X*.5+.02 or math.abs(localPoint.Y)>part.Size.Y*.5+.02 or math.abs(localPoint.Z)>part.Size.Z*.5+.02 then return nil end
 end
 return point,normal
end
-- Mining Away's two flat beam ribbons. Render from the same verified contact
-- as other miners; the original warm palette and width curve are cosmetic.
local function drawReferenceBeam(beam,visible,width,sample,now)
 if visible and not beam.reference then
  local tip=Instance.new('Attachment');tip.Parent=beam.endpoint
  local layers={}
  for i,name in ipairs({'ReferenceInner','ReferenceOuter'}) do
   local b=Instance.new('Beam');b.Name=name;b.Attachment0=beam.origin;b.Attachment1=tip;b.FaceCamera=true
   -- The enabled reference clones MiningFX.Beam, whose inner color differs
   -- from the unused beam embedded in the drone template.
   b.Color=ColorSequence.new(i==1 and Color3.fromRGB(192,134,80) or Color3.new(1,.622278,.0959487))
   b.Transparency=i==1 and NumberSequence.new(0) or NumberSequence.new(.85625,.85)
   b.LightEmission=i==1 and 1 or .1;b.LightInfluence=i==1 and 1 or .6
   b.Parent=beam.holder;layers[i]=b
  end
  beam.reference=layers
 end
 if not beam.reference then return end
 local t=math.clamp((now-(sample.since or now))/2,0,1)
 local inner=.3*(1-(1-t)^2)*width
 for i,b in ipairs(beam.reference) do
  local w=visible and (i==1 and inner or .5*width) or 0
  b.Width0=w;b.Width1=w;b.Enabled=w>.001
 end
end
function P:renderMiningBeam(beam,sample,now,noQuery)
 if self.closed or not beam or not beam.origin.Parent then return end
 local final;sample,final=finalContact(sample,now)
 beam.vertical=sample.isMining==true
 beam.followCrystal=followsCrystal(sample)
 if not sample.alive or beam.cachedLife~=sample.life or beam.cacheKey~=sample.key then
  beam.surface={};beam.secondarySurface={};beam.endY=nil;beam.visibility=0;beam.cachedLife=sample.life;beam.cacheKey=sample.key
 end
 local dt=beam.renderAt and math.clamp(now-beam.renderAt,0,.1) or 1/60;beam.renderAt=now
 local part=sample.part
 local point,normal
 -- A recall starting with a still-valid contact may finish its authored fade,
 -- even when its verification expires during those final 0.2 seconds.
 if sample.active then beam.surface.fadeUntil=nil
 elseif sample.alive and beam.envelope.active and beam.surface.verifiedAt and now-beam.surface.verifiedAt<=.75 then
  beam.surface.fadeUntil=now+.2
 end
 if sample.alive and part then point,normal=self:_surface(beam,beam.surface,beam.origin.WorldPosition,part,sample.serverSource,now,nil,noQuery,beam.vertical and not beam.followCrystal) end
 local valid=point~=nil and normal~=nil
 -- The server already supplied the charge deadline. Bridge only the small
 -- snapshot gap for continuous miners, cosmetically, with a verified contact.
 -- Never feed prediction into damage, work particles, audio or the fade state.
 local deadline=(sample.warmupStart or 0)+(sample.warmupDuration or .8)
 local predicted=sample.droneRole=='Striker' and sample.isMining and sample.alive
  and sample.charging and not sample.active and not sample.paused and valid
  and (sample.warmupStart or 0)>0 and now>=deadline and now<deadline+.15
 -- A break attribute can precede its contact snapshot. A released beam is
 -- already full width; only its existing stop fade needs reconstruction.
 if final and beam.envelope.key~=sample.key then beam.envelope=F.newBeam() end
 local width=F.beamStep(beam.envelope,{now=now,alive=sample.alive,valid=part~=nil and part.Parent~=nil and part.Transparency<1,
  key=sample.key,life=sample.life,active=sample.active,since=sample.since})
 if predicted then width=1 end
 if valid then
  beam.endpoint.Position=point;beam.marker.Position=point+normal*.07
  if sample.resource then sample.resource.lastContact={anchor=beam.surface.anchor,normal=beam.surface.normal} end
 end
 local style=sample.style or 'Cutter';local look=miningLooks[style] or miningLooks.Cutter
 local tint=miningTypeColors[sample.droneType] or look.color
 if beam.look~=look or beam.tint~=tint then
  beam.look=look;beam.tint=tint
  beam.core.Color=miningTypeColors[sample.droneType] and tint:Lerp(WHITE,.4) or look.core
  beam.halo.Color=tint;beam.marker.Color=tint
 end
 beam.miningCue=beam.miningCue or {}
 local pulse,newPulse=F.miningCue(beam.miningCue,sample,now)
 if style=='Cutter' then pulse=0;newPulse=false end
 local visible=valid and width>.001
 beam.visibility=visible and 1 or 0
 beam.core.Transparency=1;beam.halo.Transparency=1
 local reference=sample.droneRole=='Striker' and sample.isMining
 local charging=sample.alive and sample.charging and not sample.paused
 if not reference and (visible or charging) and not beam.vfx then beam.vfx=BeamVFX.new(beam.holder,sample.isMining and style or 'Combat',tint) end
 if beam.vfx then
  BeamVFX.style(beam.vfx,sample.isMining and style or 'Combat',tint)
  BeamVFX.startup(beam.vfx,BeamVFX.startupStyles[sample.droneRole or sample.droneType])
  -- draw writes every phase's visibility; avoid hide/show churn each frame.
 end
 if reference and beam.vfx then BeamVFX.destroy(beam.vfx);beam.vfx=nil end
 if visible then
  local origin=beam.origin.WorldPosition
  local vertical=beam.vertical and not beam.followCrystal
  if vertical then
   -- Only the downward endpoint eases. Both X/Z coordinates are always the
   -- emitter's, and the endpoint can never ease inside the verified surface.
   beam.endY=beam.endY and math.max(point.Y,beam.endY+(point.Y-beam.endY)*(1-math.exp(-dt*20))) or point.Y
  end
  local tip=vertical and Vector3.new(origin.X,beam.endY,origin.Z) or point
  local workerScale=.23;local alpha=beam.visibility
  if reference then beam.endpoint.Position=tip
  else
   WorkEffects.drawCylinder(beam.core,origin,tip,.11*width*workerScale,1-.62*alpha)
   WorkEffects.drawCylinder(beam.halo,origin,tip,(look.width0+(style=='Percussion' and .18 or .06)*pulse)*width*workerScale,1-.22*alpha)
  end
  if beam.vfx then
   beam.halo.Transparency=1
   local releaseAt=predicted and deadline or (style=='Percussion' and (sample.pulseAt or sample.since) or sample.since)
   BeamVFX.draw(beam.vfx,origin,tip,now,width*alpha,nil,now-(releaseAt or now),BeamVFX.MiningScale+pulse*.15)
  end
 elseif charging and beam.vfx then
  local q=math.clamp((now-(sample.warmupStart or now))/math.max(.01,sample.warmupDuration or .8),0,1)
  local origin=beam.origin.WorldPosition
  BeamVFX.draw(beam.vfx,origin,origin-Vector3.yAxis,now,0,q,nil,BeamVFX.MiningScale,sample.warmupDuration)
 elseif beam.vfx and sample.specialReleaseAt and now-sample.specialReleaseAt<.16 then
  local origin=beam.origin.WorldPosition
  BeamVFX.draw(beam.vfx,origin,origin-Vector3.yAxis,now,0,nil,now-sample.specialReleaseAt,BeamVFX.MiningScale)
 elseif beam.vfx then
  BeamVFX.destroy(beam.vfx);beam.vfx=nil
 end
 drawReferenceBeam(beam,reference and visible,width,sample,now)
 beam.marker.Size=Vector3.one*(.09+(style=='Percussion' and .11 or .04)*pulse)
 if valid then beam.marker.Position=point+normal*(beam.marker.Size.X*.5) end
 beam.marker.Transparency=visible and sample.contact and (.6+.4*(1-width)) or 1
 if not reference then self.work:mining(beam,sample,point,normal,width,pulse,now) end
 if self.audio and self.audio.setLoop then
  if visible and sample.active and sample.isMining and not sample.paused and not reference then
   self.audio:setLoop(beam,'cutting_hum',point,.45+.55*width,.9+.1*width)
   beam.wasCutting=true
  else
   self.audio:stopLoop(beam)
   if beam.wasCutting and sample.alive and not sample.paused then self:_sound(beam.origin.WorldPosition,'laser_stop',now) end
   beam.wasCutting=false
  end
 end
 if visible and newPulse and style=='Percussion' and now>=(self.nextMiningSoundAt or 0) then
  self.nextMiningSoundAt=now+.12;self:_sound(point,'mining',now)
 elseif visible and newPulse and style=='Resonance' then self:_sound(point,'resonance',now)
 end
 beam.secondary.Transparency=1
 BeamVFX.hide(beam.branchVFX,true)
 local branchDrawn=false
 if visible and sample.active and sample.secondaryPart and sample.secondaryKey then
  local secondary,secondaryNormal=self:_surface(beam,beam.secondarySurface,branchOrigin(beam,sample.secondaryPart,point,normal),sample.secondaryPart,sample.secondarySource,now,sample.serverSource,noQuery,beam.vertical)
  if secondary and secondaryNormal then
   beam.secondaryPoint.Position=secondary;beam.secondary.Color=sample.secondaryColor or tint
   WorkEffects.drawCylinder(beam.secondary,branchOrigin(beam,sample.secondaryPart,point,normal),secondary,(style=='Resonance' and .11+.04*pulse or .085)*width*.58,.35)
   if not beam.branchVFX then beam.branchVFX=BeamVFX.new(beam.holder,'Branch',sample.secondaryColor or tint,false) end
   if beam.branchVFX then
    beam.secondary.Transparency=1;BeamVFX.style(beam.branchVFX,'Branch',sample.secondaryColor or tint)
    BeamVFX.draw(beam.branchVFX,branchOrigin(beam,sample.secondaryPart,point,normal),secondary,now,width,nil,nil)
    branchDrawn=true
   end
  end
 end
 if not branchDrawn then BeamVFX.destroy(beam.branchVFX);beam.branchVFX=nil end
end
-- Collect a frame before spending any rays. Oldest-due primary contacts are
-- given at least half of six contact slots and scheduled first. Branches receive
-- two slots, escalating to three under heavier load; unused slots return.
-- The .75s verified-cache deadline hides stale anchors during overload.
function P:queueMiningBeam(beam,sample,now)
 if self.closed or not beam or not beam.origin.Parent then return end
 local final;sample,final=finalContact(sample,now)
 beam.vertical=sample.isMining==true
 beam.followCrystal=followsCrystal(sample)
 if not sample.alive or beam.cachedLife~=sample.life or beam.cacheKey~=sample.key then
  beam.surface={};beam.secondarySurface={};beam.branchHold=nil;beam.endY=nil;beam.visibility=0;beam.cachedLife=sample.life;beam.cacheKey=sample.key
 end
 if final then
  -- This saved hit already has a hard .3s lifetime. It may use the still-visible
  -- fracture mesh at HP zero, but must never enter the ordinary 1.2s proc hold.
  beam.branchHold=nil
  table.insert(self.beamQueue,{beam=beam,sample=sample,now=now});return
 end
 -- A short-lived authoritative proc can end before its fair verification turn.
 -- Retain the observed target cosmetically for at most 1.2 s, and only until
 -- 0.12 s after its first successful verification. No gameplay is performed.
 local incoming=sample.alive and sample.active and sample.secondaryPart and sample.secondaryKey
 local incomingSource=sample.secondarySource
 local incomingHP=incomingSource and incomingSource:GetAttribute('HP')
 local incomingDead=incomingSource and incomingSource:GetAttribute('Dead')
 if incoming and (not sample.secondaryPart.Parent or (incomingSource and not incomingSource.Parent)
  or incomingDead==true or (type(incomingHP)=='number' and incomingHP<=0)) then
  sample=table.clone(sample);sample.secondaryPart=nil;sample.secondaryKey=nil;incoming=nil
 end
 local hold=beam.branchHold
 if incoming then
  if not hold or hold.key~=sample.secondaryKey or hold.part~=sample.secondaryPart then
   hold={key=sample.secondaryKey,part=sample.secondaryPart,source=sample.secondarySource,color=sample.secondaryColor}
   beam.branchHold=hold;beam.secondarySurface={}
  end
  hold.deadline=now+1.2
 elseif hold then
  local verified=hold.firstVerifiedAt
  local sourceHP=hold.source and hold.source:GetAttribute('HP')
  local sourceDead=hold.source and hold.source:GetAttribute('Dead')
  if not sample.alive or not sample.active or not hold.part.Parent or (hold.source and not hold.source.Parent)
   or sourceDead==true or (type(sourceHP)=='number' and sourceHP<=0)
   or now>hold.deadline or (verified and now>verified+.12) then
   beam.branchHold=nil;beam.secondarySurface={};hold=nil
  else
   sample=table.clone(sample)
   sample.secondaryPart=hold.part;sample.secondaryKey=hold.key
   sample.secondarySource=hold.source;sample.secondaryColor=hold.color
  end
 end
 table.insert(self.beamQueue,{beam=beam,sample=sample,now=now})
end
function P:flushMiningBeams()
 local primary={};local secondary={}
 local function add(list,entry,cache,part,origin,source,ignored,vertical)
  if not part or not part.Parent or part.Transparency>=1 then cache.anchor=nil;return end
  if cache.part~=part then cache.part=part;cache.anchor=nil;cache.nextSample=0;cache.dueSince=entry.now;cache.lastSample=nil;cache.verifiedAt=nil;cache.fadeUntil=nil end
  if not cache.order then self.beamOrder+=1;cache.order=self.beamOrder end
  if entry.now>=(cache.nextSample or 0) then
   table.insert(list,{entry=entry,cache=cache,part=part,origin=origin,source=source,ignored=ignored,vertical=vertical})
  end
 end
 local function run(list,limit)
  table.sort(list,function(a,b)
   local x,y=a.cache.dueSince or a.entry.now,b.cache.dueSince or b.entry.now
   return x==y and a.cache.order<b.cache.order or x<y
  end)
  local used=0
  for _,v in ipairs(list) do
   if used>=limit or self.beamRays+2>self.maxBeamRays then break end
   if not v.served then
    self:_surface(v.entry.beam,v.cache,v.origin,v.part,v.source,v.entry.now,v.ignored,false,v.vertical)
    v.served=true;used+=1
   end
  end
 end
 local branchCount=0;local primaryCount=0
 for _,e in ipairs(self.beamQueue) do
  local b,s=e.beam,e.sample
  if s.alive and s.active then
   primaryCount+=1
   add(primary,e,b.surface,s.part,b.origin.WorldPosition,s.serverSource,nil,b.vertical and not b.followCrystal)
   if s.secondaryPart and s.secondaryKey then branchCount+=1 end
  end
 end
 local slots=math.floor(self.maxBeamRays/2)
 local frameNow=self.beamQueue[1] and self.beamQueue[1].now
 local dt=frameNow and self.lastBeamFrame and math.clamp(frameNow-self.lastBeamFrame,1/240,1/10) or 1/60
 if frameNow then self.lastBeamFrame=frameNow end
 local reserved=branchCount>0 and math.min(2,math.max(0,slots-1)) or 0
 -- Allocate according to both populations, preserving at least two primary
 -- and two branch slots where the budget permits. A 0.74s planning window
 -- leaves a small margin before the 0.75s verified-contact deadline.
 if reserved>0 then
  local primaryNeed=math.ceil(primaryCount*dt/.74)
  local branchNeed=math.ceil(branchCount*dt/.74)
  local primaryFloor=math.min(slots-2,math.max(2,primaryNeed))
  reserved=math.min(slots-primaryFloor,math.max(reserved,branchNeed))
 end
 run(primary,slots-reserved)
 for _,e in ipairs(self.beamQueue) do
  local b,s=e.beam,e.sample
  if s.alive and s.active and s.secondaryPart and s.secondaryKey then
   local point,normal=self:_surface(b,b.surface,b.origin.WorldPosition,s.part,s.serverSource,e.now,nil,true,b.vertical and not b.followCrystal)
   if point and normal then add(secondary,e,b.secondarySurface,s.secondaryPart,branchOrigin(b,s.secondaryPart,point,normal),s.secondarySource,s.serverSource,b.vertical) end
  end
 end
 run(secondary,reserved)
 -- If no usable branch was due, its reservation must not waste the budget.
 run(primary,slots)
 run(secondary,slots)
 for _,e in ipairs(self.beamQueue) do
  local hold=e.beam.branchHold
  if hold and not hold.firstVerifiedAt and e.beam.secondarySurface.verifiedAt then
   hold.firstVerifiedAt=e.beam.secondarySurface.verifiedAt
  end
 end
 for _,e in ipairs(self.beamQueue) do self:renderMiningBeam(e.beam,e.sample,e.now,true) end
 self.beamQueue={}
end
function P:_pulse(position,color,size,now,duration)
 if self.closed or #self.pulses>=self.maxPulses then return end
 local part=barePart(self.parent,'ImpactPulse');part.Shape=Enum.PartType.Ball
 part.Material=Enum.Material.SmoothPlastic;part.Size=Vector3.one*.1;part.Position=position;part.Color=color;part.Transparency=.82
 table.insert(self.pulses,{part=part,start=now,size=math.min(size,.8),duration=duration or .2})
end
function P:_sound(position,kind,now)
 if self.audio then self.audio:play(kind,position);return end
 -- Roblox Studio's shipped sounds were verified locally; no external asset IDs.
 if #self.pulses>=self.maxPulses then return end
 local anchor=barePart(self.parent,'ImpactAudio');anchor.Size=Vector3.one*.05
 anchor.Position=position;anchor.Transparency=1
 local sound=Instance.new('Sound');sound.Name='CosmeticImpact'
 sound.SoundId=kind=='death' and 'rbxasset://sounds/impact_explosion_03.mp3' or 'rbxasset://sounds/action_jump_land.mp3'
 sound.Volume=kind=='death' and .28 or (kind=='mining' and .065 or .12)
 sound.PlaybackSpeed=kind=='death' and 1.1 or (kind=='mining' and .85 or 1.6)
 sound.RollOffMinDistance=5;sound.RollOffMaxDistance=65;sound.Parent=anchor;sound:Play()
 -- The same bounded, frame-cleaned pool owns both pulse parts and audio anchors.
 table.insert(self.pulses,{part=anchor,start=now,size=0,duration=kind=='death' and 2.5 or 1,audio=true})
end
function P:_floor(position,exclude)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={self.parent,exclude}
 local result=workspace:Raycast(position+Vector3.new(0,1,0),Vector3.new(0,-100,0),params)
 return result and result.Position.Y or position.Y-9
end
function P:_fragment(template,frame,color,transparency,scale,velocity,spin,floor,now,duration,priority,rock)
 if self.closed then return end
 if #self.fragments>=self.maxFragments then
  if not priority then return end
  -- A mineral shower cannot consume the space needed for a visible drone death.
  local replace=1
  for i,item in ipairs(self.fragments) do if not item.priority then replace=i;break end end
  self.fragments[replace].part:Destroy();table.remove(self.fragments,replace)
 end
 local part=rock and Instance.new('Part') or template:Clone();if not part then return end
 if rock then
  part.Size=template.Size;part.Material=template.Material;part.MaterialVariant=template.MaterialVariant
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 end
 -- Clone each real mesh once. Nested emitter parts and joints must not travel twice.
 for _,object in ipairs(part:GetDescendants()) do
  if object:IsA('BasePart') or object:IsA('LuaSourceContainer') or object:IsA('JointInstance')
   or object:IsA('Constraint') or object:IsA('WeldConstraint') or object:IsA('Beam')
   or object:IsA('Trail') or object:IsA('ParticleEmitter') or object:IsA('Sound')
   or object:IsA('BillboardGui') or object:IsA('SurfaceGui') then object:Destroy() end
 end
 passive(part);part.CastShadow=false;part.Name=rock and 'RockDebris' or 'AuthoredDebris';part.Size=part.Size*scale;part.CFrame=frame
 part.Color=color;part.Transparency=transparency;part.Parent=self.parent
 local ground=floor+(rock and part.Size.Magnitude*.5 or part.Size.Y*.3)
 local gravity=rock and 72 or 26
 local landing=(velocity.Y+math.sqrt(velocity.Y^2+2*gravity*math.max(0,frame.Position.Y-ground)))/gravity
 table.insert(self.fragments,{part=part,frame=frame,start=now,velocity=velocity,spin=spin,
  floor=ground,transparency=transparency,duration=math.max(duration or 1.5,landing+(rock and 1.25 or .35)),priority=priority,rock=rock})
end
function P:registerDrone(drone,now)
 if self.closed or self.drones[drone] then return end
 local current=snapshot(drone.source)
 if current.state==nil or current.hp==nil or current.life==nil then return end
 self.drones[drone]={events=F.new(current),parts=partsOf(drone.view),
  pose=drone.view:GetPivot(),hitAt=-100,shotAt=-100,repairSerial=drone.source:GetAttribute('RepairSerial') or 0,shield=drone.source:GetAttribute('Shield') or 0,scan=nil}
 -- Starting in Destroyed/Reprinting reconstructs that state; no previous death replay.
 self:renderDrone(drone,0,now)
end
function P:_droneDeath(drone,record,now)
 local origin=record.pose.Position;local floor=self:_floor(origin,drone.source)
 self:_pulse(origin,ICE,3.1,now,.18)
 self:_sound(origin,'death',now)
 local visible=0
 for _,item in ipairs(record.parts) do
  if item.transparency<.95 and visible<6 then
   visible=visible+1
   local angle=visible*2.4;local frame=record.pose*item.relative
   self:_fragment(item.part,frame,item.color,item.transparency,1,
    Vector3.new(math.cos(angle)*3.4,visible==1 and 1.3 or 3.5,math.sin(angle)*3.4),
    Vector3.new(visible%2==0 and -3.2 or 2.8,visible*.8,2.1),floor,now,1.65,true)
  end
 end
end
function P:_removeScan(record)
 if record.scan then record.scan:Destroy();record.scan=nil;self.scanCount=math.max(0,self.scanCount-1) end
end
function P:renderDrone(drone,_dt,now)
 local record=self.drones[drone]
 if not record then self:registerDrone(drone,now);return end
 if not drone.view.Parent then return end
 local source=drone.source;local state=source:GetAttribute('State') or 'Follow'
 local event=F.observe(record.events,snapshot(source))
 -- record.pose is the last rendered pre-destruction pose, before server reprint teleport.
 if event.died then self:_droneDeath(drone,record,now) end
 if event.hit then
  if now-record.hitAt>.22 then self:_sound(record.pose.Position,'hit',now) end
  record.hitAt=now
 end
 if event.shot then record.shotAt=now end
 local pose=drone.view:GetPivot()
 if self.audio and self.audio.updateDrone then self.audio:updateDrone(source,pose.Position,now) end
 local repairs=source:GetAttribute('RepairSerial') or 0
 if repairs>record.repairSerial and not record.events.dead then self:_pulse(pose.Position,Color3.fromRGB(131,235,168),2.4,now,.3) end
 record.repairSerial=repairs
 local shield=source:GetAttribute('Shield') or 0
 if shield<record.shield-.001 and not record.events.dead then self:_pulse(pose.Position,ICE,2.8,now,.22);self:_sound(pose.Position,'shield',now) end
 record.shield=shield
 local hit=F.flash(now-record.hitAt,.16);local recoil=F.recoil(now-record.shotAt)
 local rebuilding=state=='Reprinting'
 if rebuilding then
  local ready=source:GetAttribute('ReprintAt') or now
  local progress,reveal=F.assembly(now,ready,2)
  if not record.scan and self.scanCount<self.maxScans then
   record.scan=barePart(self.parent,'ReconstructionScan');record.scan.Color=ICE;record.scan.Material=Enum.Material.SmoothPlastic
   record.scan.Size=Vector3.new(1.48,.025,1.48);self.scanCount=self.scanCount+1
  end
  if record.scan then
   record.scan.CFrame=CFrame.new(pose.Position+Vector3.new(0,-.73+progress*1.46,0))*CFrame.Angles(0,progress*math.pi*.5,0)
   record.scan.Transparency=.8+reveal*.15
  end
  for _,item in ipairs(record.parts) do
   if item.part.Parent then
    item.part.Transparency=math.max(item.transparency,.88*(1-reveal))
    item.part.Color=item.color:Lerp(ICE,(1-reveal)*.45)
   end
  end
  drone.view:PivotTo(pose*CFrame.new(0,(1-reveal)*.35,0))
 else
  self:_removeScan(record)
  for _,item in ipairs(record.parts) do
   if item.part.Parent then
    item.part.Color=item.color:Lerp(WHITE,hit*.78)
    -- HP can replicate one frame before State. Never leave a dead body at the printer.
    item.part.Transparency=record.events.dead and 1 or item.transparency
   end
  end
  if not record.events.dead and (hit>0 or recoil>0) then
   drone.view:PivotTo(pose*CFrame.new(0,hit*.045,recoil*.12))
  end
 end
 if event.revived then self:_pulse(pose.Position,ICE,2.35,now,.28);self:_sound(pose.Position,'reprint',now) end
 if event.shot and not record.events.dead then
  local emitter=drone.view:FindFirstChild('Emmiter',true)
  if emitter and emitter:IsA('BasePart') then
   local critical=source:GetAttribute('Critical')==true or now-(source:GetAttribute('LastCritAt') or -100)<.15
   self:_pulse(emitter.Position,critical and HOT or ICE,critical and 1.25 or .65,now,.13)
   if now-(source:GetAttribute('ShotAt') or 0)<.35 then self:_sound(emitter.Position,'shot',now) end
  end
 end
 self.work:courier(drone,record,now)
 self.work:repair(drone,record,now)
 if source:GetAttribute('Role')~='Striker' then self.work:flight(drone,record,_dt,now) end
 if not record.events.dead then record.pose=pose end
end
function P:destroyDrone(drone)
 if self.audio and self.audio.forgetDrone then self.audio:forgetDrone(drone.source) end
 local record=self.drones[drone]
 if record then self:_removeScan(record);self.work:destroyDrone(record);self.drones[drone]=nil end
end
function P:_sentryAudio(position,kind,now)
 if #self.pulses>=self.maxPulses then return end
 local anchor=barePart(self.parent,'SentryAudio');anchor.Transparency=1;anchor.Position=position
 if self.audio then self.audio:play(kind,position)
 else
  local sound=Instance.new('Sound');sound.Name=kind=='impact' and 'StoneSlabThud' or 'SentryIgnition'
  sound.SoundId=kind=='wake' and 'rbxasset://sounds/action_get_up.mp3' or 'rbxasset://sounds/impact_explosion_03.mp3'
  sound.Volume=kind=='impact' and .65 or .5
  sound.PlaybackSpeed=kind=='impact' and .48 or (kind=='wake' and .65 or 1.65)
  sound.RollOffMinDistance=12;sound.RollOffMaxDistance=130;sound.Parent=anchor;sound:Play()
 end
 if kind=='impact' then
  local dust=Instance.new('ParticleEmitter');dust.Name='SlabImpactDust';dust.Rate=0
  dust.Texture='rbxasset://textures/particles/smoke_main.dds';dust.Color=ColorSequence.new(Color3.fromRGB(156,176,156))
  dust.Lifetime=NumberRange.new(.8,1.3);dust.Speed=NumberRange.new(1.5,4);dust.Drag=5
  dust.SpreadAngle=Vector2.new(75,75);dust.Acceleration=Vector3.new(0,-4,0)
  dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(.3,2.5),NumberSequenceKeypoint.new(1,4)})
  dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.4,.6),NumberSequenceKeypoint.new(1,1)})
  dust.Parent=anchor;dust:Emit(12)
 end
 table.insert(self.pulses,{part=anchor,start=now,duration=4,size=0,audio=true})
end
local function sentryFlare(eye)
 local flare=Instance.new('BillboardGui');flare.Name='SentryLensFlare';flare.Adornee=eye
 flare.Size=UDim2.fromScale(28,14);flare.AlwaysOnTop=false;flare.LightInfluence=0;flare.MaxDistance=160;flare.Enabled=false;flare.Parent=eye
 local glow=Instance.new('ImageLabel');glow.Name='Starburst';glow.BackgroundTransparency=1
 glow.Image='rbxasset://textures/sparkle.png';glow.ImageColor3=WHITE
 glow.Size=UDim2.fromScale(.5,1);glow.Position=UDim2.fromScale(.25,0);glow.Parent=flare
 local streak=Instance.new('Frame');streak.Name='AnamorphicStreak';streak.AnchorPoint=Vector2.new(.5,.5)
 streak.Position=UDim2.fromScale(.5,.5);streak.Size=UDim2.fromScale(1,.025);streak.BorderSizePixel=0;streak.BackgroundColor3=ICE;streak.Parent=flare
 local fade=Instance.new('UIGradient');fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.15),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.6,.15),NumberSequenceKeypoint.new(1,1)});fade.Parent=streak
 return flare,glow,streak
end
function P:_prepareSentryFall(record,now,late)
 record.fallGroups={}
 for _,item in ipairs(record.pieces) do
  local rank=segmentRanks[item.part.Name]
  if rank then
   local eyePart=item.part.Name=='eye' or item.part.Name=='eyecase' or item.part.Name=='spawnEye'
   local key=eyePart and 'socket' or item.part.Name
   local group=record.fallGroups[key]
   if not group then
    local start=eyePart and record.eye.CFrame or item.part.CFrame
    local angle=record.phase+rank*2.39996;local radius=eyePart and 3.7 or 4.5+rank*.9
    local rest=eyePart and CFrame.new(record.eyeCenter) or item.frame
    local xz=rest.Position+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
    local field=record.source.Parent and record.source.Parent:FindFirstChild('Field')
    local floor
    if field and field:IsA('BasePart') then
     local point=field.CFrame:PointToObjectSpace(xz)
     if math.abs(point.X)<=field.Size.X*.5 and math.abs(point.Z)<=field.Size.Z*.5 then
      floor=field.CFrame:PointToWorldSpace(Vector3.new(point.X,field.Size.Y*.5,point.Z)).Y
     end
    end
    floor=floor or self:_floor(xz,record.source)
    local rotation=rest.Rotation*CFrame.Angles((rank%2==0 and 1 or -1)*(.28+rank*.12),angle*.13,.2+rank*.1)
    local size=eyePart and record.view:FindFirstChild('eyecase',true).Size or item.size
    local support=(math.abs(rotation.RightVector.Y)*size.X+math.abs(rotation.UpVector.Y)*size.Y+math.abs(rotation.LookVector.Y)*size.Z)*.5
    local finish=CFrame.new(xz.X,floor+support*.65,xz.Z)*rotation
    local drop=math.max(0,start.Position.Y-finish.Position.Y)
    group={start=start,finish=finish,drop=drop,rank=rank,ground=Vector3.new(xz.X,floor,xz.Z),impact=false}
    if late then local _,landed=S.fall(now-record.deathAt,drop,rank);group.impact=landed end
    record.fallGroups[key]=group
   end
   item.fall=group;item.fallRelative=group.start:ToObjectSpace(item.part.CFrame)
  end
 end
end
function P:_sentryFallFrame(item,record,now)
 local group=item.fall
 local fraction,landed,impactAge=S.fall(now-record.deathAt,group.drop,group.rank)
 local frame
 if landed then frame=group.finish
 else
  local travel=math.sqrt(fraction);local p=group.start.Position:Lerp(group.finish.Position,travel)
  local y=group.start.Position.Y-group.drop*fraction
  frame=CFrame.new(p.X,y,p.Z)*group.start.Rotation:Lerp(group.finish.Rotation,F.smooth(travel))
 end
 if landed and not group.impact then
  group.impact=true
  -- A long suspended frame must not replay every historical impact at once.
  if impactAge<.22 then self:_sentryAudio(group.ground,'impact',now) end
 end
 return frame*item.fallRelative
end
function P:registerTurret(source,now)
 if self.closed or self.turrets[source] then return self.turrets[source] end
 if source:GetAttribute('HP')==nil or source:GetAttribute('Dead')==nil then return nil end
 -- Streamed partial models must not become partial turret viewmodels.
 for _,name in ipairs(requiredSegments) do
  local part=source:FindFirstChild(name,true)
  if not part or not part:IsA('BasePart') then return nil end
 end
 local base=source:FindFirstChild('basepart',true)
 if not base or not base:IsA('BasePart') then return nil end
 local view=source:Clone();if not view then return nil end
 clean(view);view.Name='View_'..source.Name;view.Parent=self.parent
 local eye=view:FindFirstChild('eye',true)
 local endpoint=barePart(self.parent,'SentryAim');endpoint.Size=Vector3.one*.05;endpoint.Transparency=1
 local cue=barePart(self.parent,'SentryChargeMark');cue.Shape=Enum.PartType.Cylinder
 cue.Size=Vector3.new(.025,7,7);cue.Color=HOT;cue.Transparency=1
 local a=Instance.new('Attachment');a.Name='ChargeOrigin';a.Parent=eye
 local b=Instance.new('Attachment');b.Parent=endpoint
 local beam=Instance.new('Beam');beam.Name='SentryTelegraph';beam.Attachment0=a;beam.Attachment1=b
 beam.FaceCamera=true;beam.Color=ColorSequence.new(HOT);beam.LightEmission=.65;beam.LightInfluence=0
 beam.Transparency=NumberSequence.new(.7);beam.Segments=1;beam.Enabled=false;beam.Parent=view
 local core=beam:Clone();core.Name='SentryBeamCore';core.Color=ColorSequence.new(WHITE)
 core.Transparency=NumberSequence.new(.4);core.Parent=view
 local light=Instance.new('PointLight');light.Name='SentryCharge';light.Color=ICE;light.Range=7
 light.Shadows=false;light.Brightness=0;light.Parent=eye
 local initial=F.new(snapshot(source))
 local flare,glow,streak=sentryFlare(eye)
 local record={source=source,view=view,eye=eye,endpoint=endpoint,cue=cue,attachment=a,beam=beam,core=core,light=light,
  flare=flare,glow=glow,streak=streak,
  parts={},pieces=partsOf(view),hidden={},accents={},events=initial,yaw=0,hitAt=-100,shotAt=-100,
  deathAt=initial.dead and now-10 or nil,restoreAt=nil,floor=base.Position.Y+base.Size.Y*.5,
  baseCenter=base.Position,eyeCenter=eye.Position,phase=base.Position.X*.17+base.Position.Z*.23}
 record.motion=S.new(now,record.phase)
 local stackCenter=base.Position.Y+base.Size.Y*.5
 local previousHeight=nil
 for _,name in ipairs({'bottemseg','lowerseg','upperseg','topseg'}) do
  for _,item in ipairs(record.pieces) do if item.part.Name==name then
   -- The authored lower shell has a deep eye cutout: touching bounding boxes
   -- still leaves that opening exposed. Telescope the rims into one another.
   stackCenter+=previousHeight and (previousHeight+item.size.Y)*.25 or item.size.Y*.5
   item.compact=stackCenter-item.frame.Position.Y;previousHeight=item.size.Y
  end end
 end
 record.lastAwake=source:GetAttribute('Awake')==true
 record.lastWake=source:GetAttribute('WakeAt') or 0
 local ignition=source:GetAttribute('ActivateAt') or record.lastWake+S.IGNITE
 record.ignited=now>=ignition;record.wakeSound=record.lastAwake
 if initial.dead then
  record.deathAt=source:GetAttribute('DeathAt') or now-10
  if record.deathAt<=0 then record.deathAt=now-10 end
  self:_prepareSentryFall(record,now,true)
 end
 for _,item in ipairs(record.pieces) do
  record.parts[item.part]=true
  if item.part.Name=='eye' or item.part.Name=='eyecase' or item.part.Name=='spawnEye' then
   item.eyeRelative=eye.CFrame:ToObjectSpace(item.frame)
  end
 end
 for _,name in ipairs({'eye','spawnEye'}) do
  local part=view:FindFirstChild(name,true);record.accents[part]=part.Color
 end
 self.turrets[source]=record
 self:_hideTurret(record)
 self:renderTurret(record,0,now)
 return record
end
function P:_hideTurret(record)
 -- Also covers parts arriving after the initial source clone through StreamingEnabled.
 for _,part in ipairs(record.source:GetDescendants()) do
  if part:IsA('BasePart') then
   if record.hidden[part]==nil then record.hidden[part]=part.LocalTransparencyModifier end
   part.LocalTransparencyModifier=1
  end
 end
end
function P:renderTurret(record,dt,now)
 if self.closed or not record.view.Parent then return end
 local source=record.source;local event=F.observe(record.events,snapshot(source))
 local dead=record.events.dead
 if event.died then
  local stamp=source:GetAttribute('DeathAt') or 0
  record.deathAt=stamp>0 and stamp or now;record.restoreAt=nil
  self:_prepareSentryFall(record,now,false)
 elseif event.revived then
  record.restoreAt=now;record.deathAt=nil;record.fallGroups=nil
  for _,item in ipairs(record.pieces) do item.rebuildFrom=item.part.CFrame end
 end
 if event.hit then record.hitAt=now end
 if event.shot then record.shotAt=now;self:_sound(record.eye.Position,'hit',now) end
 local awake=source:GetAttribute('Awake')
 -- Older in-memory preview servers have no new attributes. This fallback only
 -- derives presentation from their authoritative field phase, never local input.
 if awake==nil then
  local phase=source.Parent and source.Parent:GetAttribute('Phase')
  awake=phase=='Gathering' or phase=='Active' or source:GetAttribute('Telegraph')==true
 end
 awake=awake==true and not dead
 local wakeAt=source:GetAttribute('WakeAt')
 if not wakeAt or wakeAt<=0 then
  if awake and not record.lastAwake then record.observedWake=now end
  wakeAt=record.observedWake or now-S.WAKE_DURATION
 end
 local activateAt=source:GetAttribute('ActivateAt')
 if not activateAt or activateAt<=0 then activateAt=wakeAt+S.IGNITE end
 if not awake and record.lastAwake and not dead then
  record.sleepAt=now
  for _,item in ipairs(record.pieces) do item.sleepFrom=item.part.CFrame end
 elseif awake then record.sleepAt=nil end
 if awake and (not record.lastAwake or record.lastWake~=wakeAt) then
  record.ignited=now>activateAt+.8;record.wakeSound=false
 end
 record.lastAwake=awake;record.lastWake=wakeAt
 if awake and not record.wakeSound then
  record.wakeSound=true
  if now-wakeAt<.3 then self:_sentryAudio(record.baseCenter,'wake',now) end
 end
 if awake and not record.ignited and now>=activateAt then
  record.ignited=true
  if now-activateAt<.5 then self:_sentryAudio(record.eye.Position,'ignite',now);self:_pulse(record.eye.Position,WHITE,4.5,now,.3) end
 end
 local charging=source:GetAttribute('Telegraph')==true and awake
 if self.audio and self.audio.setLoop then
  if charging and source:GetAttribute('MotionPaused')~=true and (source:GetAttribute('FireAt') or 0)>now then
   self.audio:setLoop(record,'combat_charge',record.eye.Position,.85,1)
  else self.audio:stopLoop(record) end
 end
 local aim=source:GetAttribute('Aim')
 local followingShot=now-record.shotAt<.35
 local look=(charging or followingShot) and aim or source:GetAttribute('WatchPosition') or source:GetAttribute('WakeAim') or aim
 local fireAt=source:GetAttribute('FireAt') or now
 local charge=charging and math.clamp(1-(fireAt-now)/.8,0,1) or 0
 local aimYaw,aimPitch
 if typeof(look)=='Vector3' then
  local delta=look-(record.eyeCenter+Vector3.new(0,1.25,0))
  local horizontal=math.sqrt(delta.X*delta.X+delta.Z*delta.Z)
  if horizontal>.1 then aimYaw=math.atan2(-delta.X,-delta.Z);aimPitch=math.atan2(delta.Y,horizontal) end
 end
 local pose=S.step(record.motion,dt,now,record.phase,{dead=dead,awake=awake,wakeAt=wakeAt,
  charging=charging,charge=charge,aimYaw=aimYaw,aimPitch=aimPitch,
  shotAge=now-record.shotAt,hitAge=now-record.hitAt})
 local warm=pose.charge;local shotFlash=F.flash(now-record.shotAt,.22)
 local ignite=awake and F.flash(now-activateAt,.8) or 0
 local hit=F.flash(now-record.hitAt,.2)
 local eyeColor=ICE:Lerp(HOT,warm):Lerp(WHITE,math.max(ignite,shotFlash))
 for _,item in ipairs(record.pieces) do
  local part=item.part
  if part.Parent then
   local rank=segmentRanks[part.Name]
   local frame=item.frame;local transparency=item.transparency
   local color=item.color:Lerp(WHITE,hit*.65)
   if rank then
    local eyePart=part.Name=='eye' or part.Name=='eyecase' or part.Name=='spawnEye'
    if dead then
     if not item.fall then self:_prepareSentryFall(record,now,true) end
     frame=self:_sentryFallFrame(item,record,now);color=item.color:Lerp(RUIN,eyePart and .92 or .38)
     part.Size=item.size
     if eyePart then part.Material=Enum.Material.SmoothPlastic end
    else
     local motion=S.segment(rank,now,record.phase,pose,eyePart,item.compact or 0)
     local origin=eyePart and record.eyeCenter or Vector3.new(record.baseCenter.X,item.frame.Position.Y,record.baseCenter.Z)
     local rotation=CFrame.Angles(0,motion.yaw,0)*CFrame.Angles(motion.pitch,0,motion.roll)
     frame=CFrame.new(origin+Vector3.new(motion.side,motion.lift,motion.back))*rotation*CFrame.new(-origin)*item.frame
     if not awake and item.sleepFrom and record.sleepAt then
      local progress=F.smooth(F.progress(now,record.sleepAt+rank*.06,.95))
      frame=item.sleepFrom:Lerp(frame,progress)
      if progress>=1 then item.sleepFrom=nil end
     end
     if item.rebuildFrom and record.restoreAt then
      local progress=F.smooth(F.progress(now,record.restoreAt+rank*.07,1.15))
      frame=item.rebuildFrom:Lerp(frame,progress)
      if progress>=1 then item.rebuildFrom=nil end
     end
     if eyePart then
      part.Material=item.material
      -- Interpolate the socket as one rigid assembly even during closing and
      -- reconstruction. Independent world-space lerps would shrink its orbit.
      -- partsOf sorts eye before eyecase/spawnEye.
      if part==record.eye then record.rigidEyeFrame=frame
      else frame=record.rigidEyeFrame*item.eyeRelative end
      transparency=math.max(transparency,1-motion.reveal)
      if part.Name~='eyecase' then
       color=eyeColor
       part.Size=Vector3.new(item.size.X,item.size.Y*(1-warm*.15),item.size.Z)
      end
     else color=color:Lerp(HOT,warm*.13):Lerp(WHITE,ignite*.3+shotFlash*.2) end
    end
   end
   part.CFrame=frame;part.Color=color;part.Transparency=transparency;item.lastFrame=frame
  end
 end
 record.light.Color=eyeColor;record.light.Range=5+ignite*2
 record.light.Brightness=awake and (.08+warm*.22+ignite*.25+shotFlash*.2) or 0
 record.flare.Enabled=false
 local aiming=typeof(aim)=='Vector3'
 record.beam.Enabled=awake and now>=activateAt and aiming and (charging or shotFlash>.01)
 record.beam.Width0=.014+warm*.028+shotFlash*.128;record.beam.Width1=.014+warm*.028+shotFlash*.088
 record.core.Enabled=record.beam.Enabled;record.core.Width0=.005+warm*.008+shotFlash*.04
 record.core.Width1=.005+warm*.008+shotFlash*.028
 if aiming then record.endpoint.Position=aim end
 if record.beam.Enabled then
  record.vfx=record.vfx or BeamVFX.new(record.view,'Sentry',HOT)
  if record.vfx then
   BeamVFX.draw(record.vfx,record.eye.Position,aim,now,shotFlash,charging and warm or nil,now-record.shotAt)
   record.core.Enabled=false -- retain the thin warning line until the shot
  end
 elseif record.vfx then BeamVFX.destroy(record.vfx);record.vfx=nil end
 if charging and aiming then
  if record.markAim~=aim then
   record.markAim=aim
   local field=source.Parent and source.Parent:FindFirstChild('Field');local ground=nil
   if field and field:IsA('BasePart') then
    local point=field.CFrame:PointToObjectSpace(aim)
    if math.abs(point.X)<=field.Size.X*.5 and math.abs(point.Z)<=field.Size.Z*.5 then
     ground=field.CFrame:PointToWorldSpace(Vector3.new(point.X,field.Size.Y*.5,point.Z)).Y
    end
   end
   record.cue.CFrame=CFrame.new(aim.X,(ground or self:_floor(aim,source))+.035,aim.Z)*CFrame.Angles(0,0,math.pi*.5)
  end
  record.cue.Transparency=.94-warm*.09
 else record.cue.Transparency=1;record.markAim=nil end
end
function P:destroyTurret(record)
 if not record then return end
 if self.audio and self.audio.stopLoop then self.audio:stopLoop(record) end
 for part,original in pairs(record.hidden) do if part.Parent then part.LocalTransparencyModifier=original end end
 record.endpoint:Destroy();record.cue:Destroy();record.view:Destroy();self.turrets[record.source]=nil
end
function P:kick(position,strength,now)
 local camera=workspace.CurrentCamera;if not camera then return end
 local player=game:GetService('Players').LocalPlayer
 if player and (player:GetAttribute('ReducedMotion')==true or player:GetAttribute('MA_ReducedMotion')==true) then return end
 local character=player and player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local distance=((root and root.Position or camera.CFrame.Position)-position).Magnitude
 local amount=strength*math.clamp(1-distance/55,0,1)^2
 if amount<=.001 then return end
 local remaining=math.max(0,(self.shakeStrength or 0)*(1-math.clamp((now-(self.shakeAt or 0))/.4,0,1)))
 self.shakeStrength=math.min(.16,remaining+amount);self.shakeAt=now
end
function P:cameraOffset(now)
 local age=now-(self.shakeAt or -100);local envelope=math.max(0,1-age/.4)^2
 local strength=(self.shakeStrength or 0)*envelope
 return CFrame.new(math.sin(now*67)*strength,math.sin(now*83+.7)*strength*.65,0)
end
function P:update(_dt,now)
 if self.closed then return end
 self.work:update(now)
 for i=#self.fragments,1,-1 do
  local item=self.fragments[i];local age=now-item.start
  if age>=item.duration or not item.part.Parent then
   item.part:Destroy();table.remove(self.fragments,i)
  else
   if item.rock then
    local y,travel,bounces,impactAt,speed,settled,rest=F.rubble(age,item.floor-item.frame.Position.Y,item.velocity.Y,72)
    local rotation=item.spin*travel
    local turn=item.frame.Rotation*CFrame.Angles(rotation.X,rotation.Y,rotation.Z)
    if settled then
     local flatten=math.clamp(rest/.2,0,1);local _,yaw=turn:ToOrientation()
     turn=turn:Lerp(CFrame.Angles(0,yaw,0),flatten)
     y-=(item.part.Size.Magnitude-item.part.Size.Y)*.5*flatten
    end
    item.part.CFrame=CFrame.new(item.frame.Position+Vector3.new(item.velocity.X*travel,y,item.velocity.Z*travel))*turn
    if bounces>(item.bounces or 0) then
     item.bounces=bounces
     if age-impactAt<.12 and self.audio then self.audio:play('rock_clack',item.part.Position,{level=math.clamp(speed/22,.15,.75),pitch=math.clamp(1.2-item.part.Size.X*.2,.75,1.15)}) end
    end
   else
    local y,landed,flight=F.fragment(age,item.floor-item.frame.Position.Y,item.velocity.Y,26)
    local rotation=item.spin*flight
    item.part.CFrame=CFrame.new(item.frame.Position+Vector3.new(item.velocity.X*flight,y,item.velocity.Z*flight))*item.frame.Rotation*CFrame.Angles(rotation.X,rotation.Y,rotation.Z)
    if landed and not item.landed then
     item.landed=true
     if age-flight<.2 then self:_sound(item.part.Position,item.priority and 'metal_land' or 'rubble',now) end
    end
   end
   local fade=math.clamp((age-item.duration*.6)/(item.duration*.4),0,1)
   item.part.Transparency=item.transparency+(1-item.transparency)*fade
  end
 end
 for i=#self.pulses,1,-1 do
  local item=self.pulses[i];local progress=F.progress(now,item.start,item.duration)
  if progress>=1 or not item.part.Parent then item.part:Destroy();table.remove(self.pulses,i)
  elseif not item.audio then
   item.part.Size=Vector3.one*(.1+item.size*(1-(1-progress)^2));item.part.Transparency=.82+.18*progress
  end
 end
end
function P:destroy()
 if self.closed then return end
 self.closed=true
 for drone in pairs(self.drones) do self:destroyDrone(drone) end
 for _,record in pairs(self.turrets) do self:destroyTurret(record) end
 for _,item in ipairs(self.fragments) do item.part:Destroy() end
 for _,item in ipairs(self.pulses) do item.part:Destroy() end
 self.work:destroy()
 self.fragments={};self.pulses={}
end
return P


end)()
local LaserShowcase = (function()
-- Stationary local viewmodels, never fleet members or server reward sources.
-- Reuses the production laser, specialist, particle and hardware renderers.
local Showcase={}
local definitions={
 {name='REGULAR LASER',role='Striker',color=Color3.fromRGB(114,201,255)},
 {name='BUBBLER',role='Bubbler',color=Color3.fromRGB(105,224,255)},
 {name='SPIRAL',role='Singularity',color=Color3.fromRGB(182,137,255)},
 {name='COMBAT LASER',role='Combat',color=Color3.fromRGB(255,116,99)},
 {name='HALVER',role='Halver',color=Color3.fromRGB(255,179,77)},
 {name='GRIDCUTTER',role='Gridcutter',color=Color3.fromRGB(255,92,109)},
}
local period,charge,attack=7.9,3.2,4.5 -- Longer readable charge, still only 0.2 seconds idle.
local function clean(model)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('SurfaceGui') or v:IsA('Sound') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
  elseif v:IsA('Beam') or v:IsA('Trail') or v:IsA('ParticleEmitter') or v:IsA('Light') then v.Enabled=false end
 end
end
local function part(parent,name,position,size,color)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.Size=size;p.Position=position;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Parent=parent;return p
end
local function label(p,text)
 local g=Instance.new('SurfaceGui');g.Face=Enum.NormalId.Top;g.CanvasSize=Vector2.new(640,160);g.Parent=p
 local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1
 t.Text=text;t.TextColor3=Color3.fromRGB(236,243,255);t.TextSize=45;t.Font=Enum.Font.GothamBold;t.Parent=g
end
function Showcase.new(world,parent,config)
 local self={world=world,parent=parent,stations={},nextAttempt=0}
 function self:build()
  local rs=game:GetService('ReplicatedStorage')
  local drone=rs:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
  local rock
  for _,v in ipairs(world:GetDescendants()) do if v:IsA('BasePart') and v:GetAttribute('ResourceId') then rock=v;break end end
  local home=world:GetAttribute('DepotHome')
  if not drone or not rock or typeof(home)~='Vector3' then return false end
  local root=Instance.new('Folder');root.Name='HomeEffectsPreview';root.Parent=parent;self.root=root
  -- The west side of the hub leaves the central walk and ramp approaches clear.
  self.center=home+Vector3.new(-27,0,-31)
  local params=RaycastParams.new()
  params.FilterDescendantsInstances={parent}
  params.RespectCanCollide=true
  local function grounded(pos)
   local hit=workspace:Raycast(pos+Vector3.yAxis*8,-Vector3.yAxis*32,params)
   return Vector3.new(pos.X,hit and hit.Position.Y or home.Y,pos.Z)
  end
  local signPos=grounded(self.center+Vector3.zAxis*18)+Vector3.yAxis*.07
  local sign=part(root,'PreviewTitle',signPos,Vector3.new(24,.12,3),Color3.fromRGB(24,34,49))
  label(sign,'EFFECTS PREVIEW  /  INFINITE ROCKS')
  for i,def in ipairs(definitions) do
   local column=(i-1)%3
   local row=math.floor((i-1)/3)
   local pos=grounded(self.center+Vector3.new((column-1)*13,0,9-row*18))
   local station=Instance.new('Model');station.Name=def.name;station:SetAttribute('EffectsPreview',true);station.Parent=root
   part(station,'DisplayPad',pos+Vector3.yAxis*.06,Vector3.new(9,.12,9),Color3.fromRGB(41,49,58))
   local plaque=part(station,'Nameplate',pos+Vector3.new(0,.15,5.4),Vector3.new(9,.12,1.7),Color3.fromRGB(24,34,49));label(plaque,def.name)
   local target=rock:Clone();target.Name='InfiniteDisplayRock';clean(target)
   for key in pairs(target:GetAttributes()) do target:SetAttribute(key,nil) end
   target.Anchored=true;target.CanCollide=false;target.CanTouch=false;target.CanQuery=false;target.LocalTransparencyModifier=0
   target.Size=Vector3.new(3.4,3.8,3.4);target.CFrame=CFrame.new(pos+Vector3.yAxis*2.02);target.Transparency=0
   target:SetAttribute('ResourceId','preview:'..i);target:SetAttribute('InfiniteHealth',true)
   target:SetAttribute('HP',1e30);target:SetAttribute('MaxHP',1e30);target.Parent=station
   local model=drone:Clone();model.Name='DisplayDrone';clean(model)
   model.PrimaryPart=model.PrimaryPart or model:FindFirstChild('Mesh') or model:FindFirstChildWhichIsA('BasePart',true)
   model:ScaleTo(model:GetScale()*config.Swarm.ModelScale)
   config.decorate(model,def.role=='Combat' and 'Striker' or def.role)
   model.Parent=station;model:PivotTo(CFrame.new(pos+Vector3.yAxis*12))
   local emitter=model:FindFirstChild('Emmiter',true) or model:FindFirstChild('MiningEmitter',true) or model:FindFirstChild('Emitter',true)
   if emitter then emitter.Color=def.color end
   local state=Instance.new('Folder');state.Name='DisplayState';state:SetAttribute('DroneId','preview:'..i);state.Parent=station
   self.stations[#self.stations+1]={model=model,emitter=emitter,source=state,rock=target,def=def,pos=pos,index=i,
    motion=SpecialDroneMotion.new(model,def.role)}
  end
  return true
 end
 function self:suspend()
  if not self.presentation then return end
  for _,s in ipairs(self.stations) do
   if s.beam then self.presentation:destroyMiningBeam(s.beam);s.beam=nil end
   BeamVFX.destroy(s.rig);s.rig=nil;s.cycle=nil
  end
  self.special:destroy();self.special=nil;self.presentation:destroy();self.presentation=nil
  BeamVFX.clearChargeCache()
 end
 function self:step(now,dt)
  if not self.root then
   if now<self.nextAttempt then return end
   self.nextAttempt=now+1;if not self:build() then return end
  end
  if not BeamVFX.near(self.center,85) or BeamVFX.reduced() then self:suspend();return end
  if not self.presentation then
   self.presentation=Presentation.new({parent=self.root})
   self.special=DroneFX.new(self.root,{maxDistance=100,reuseGeometry=true})
   self.special.folder.Name='HomePreviewSpecialEffects'
  end
  for _,s in ipairs(self.stations) do
   if not s.emitter then continue end
   local shifted=now+(s.index-1)*1.15;local cycle=math.floor(shifted/period)
   local t=shifted-cycle*period;local start=now-t
   local active=t>=charge and t<charge+attack
   local special=s.def.role~='Striker' and s.def.role~='Combat'
   if s.cycle~=cycle then
    s.cycle=cycle;s.rock:SetAttribute('EffectCancelledSerial',0);s.rock:SetAttribute('EffectDoneAt',0)
    s.rock:SetAttribute('EffectDepleted',false);s.rock:SetAttribute('EffectType',special and s.def.role or nil)
    s.rock:SetAttribute('EffectDrone','preview:'..s.index);s.rock:SetAttribute('EffectStartedAt',start+charge)
    s.rock:SetAttribute('EffectDuration',attack);s.rock:SetAttribute('EffectSerial',0)
   end
   if special and t>=charge and s.rock:GetAttribute('EffectSerial')==0 then s.rock:SetAttribute('EffectSerial',cycle+1) end
   local state=t<charge and 'Warmup' or active and (special and 'SpecialMine' or 'Mine') or 'Recover'
   if s.state~=state then s.source:SetAttribute('State',state);s.state=state end
   if special and t>=charge+attack*.68 and (s.rock:GetAttribute('EffectDoneAt') or 0)==0 then
    s.rock:SetAttribute('EffectDoneAt',start+charge+attack*.68)
   end
   s.model:PivotTo(CFrame.new(s.pos+Vector3.new(0,12+math.sin(now*1.4+s.index)*.12,0)))
   SpecialDroneMotion.step(s.motion,s.source,s.rock,now)
   if not s.beam then s.beam=self.presentation:createMiningBeam(s.model,s.emitter);s.beam.tint=s.def.color end
   if not s.rig then s.rig=BeamVFX.new(s.beam.holder,s.def.role=='Combat' and 'Combat' or 'Cutter',s.def.color);BeamVFX.startup(s.rig,BeamVFX.startupStyles[s.def.role]) end
   local from=s.beam.origin.WorldPosition;local tip=Vector3.new(from.X,s.rock.Position.Y+s.rock.Size.Y*.5,from.Z)
   s.beam.marker.Position=tip
   if t<charge then BeamVFX.draw(s.rig,from,from-Vector3.yAxis,now,0,t/charge,nil,BeamVFX.MiningScale,charge)
   elseif active and (not special or t-charge<.16) then BeamVFX.draw(s.rig,from,tip,now,special and 0 or 1,nil,t-charge,BeamVFX.MiningScale)
   else BeamVFX.hide(s.rig,false) end
   self.presentation.work:mining(s.beam,{alive=true,isMining=not special,active=active and not special,charging=t<charge,
    paused=false,warmupStart=start,warmupDuration=charge,key=s.index,life=1,style='Cutter',since=start+charge},tip,Vector3.yAxis,active and not special and 1 or 0,0,now)
  end
  self.special:step(now,dt)
  -- These stations only own mining emitters. The main presentation already
  -- updates orbital attacks; running it here duplicates those world effects.
 end
 function self:destroy() self:suspend();if self.root then self.root:Destroy() end end
 return self
end
return Showcase

end)()
local UILayout = (function()
-- Pixel layout inside the ScreenGui's safe content rectangle. This module has
-- no Roblox dependencies, so the same geometry can be exercised outside Studio.
-- Clients should pass their safe root's AbsoluteSize, not Camera.ViewportSize.
local Layout = {}

local function dimension(value, fallback)
 if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return fallback end
 return math.max(1, math.floor(value))
end

function Layout.calculate(viewportWidth, viewportHeight, touch)
 local width = dimension(viewportWidth, 1280)
 local height = dimension(viewportHeight, 720)
 local short = height < 500
 local compact = width < 980 or height < 650
 local mobile = width < 900 or (touch == true and short)
 local margin = width < 900 and 12 or 16
 local availableWidth = math.max(1, width - margin * 2)

 local hudWidth = math.min(300, availableWidth)
 local hudHeight = short and 64 or 68
 local hudX, hudY = margin, 12
 local objectiveHeight = short and 28 or 42
 local objectiveY = hudY + hudHeight + 8

 -- Touch controls occupy the lower corners in both orientations. Keeping the
 -- entire game command group above this strip also avoids jump/joystick hits
 -- when a station prompt becomes visible while the player is moving.
 local bottomReserve = touch == true and 130 or 16
 local contextWidth = math.min(short and 360 or 420, availableWidth)
 local contextHeight = short and 64 or 72
 local contextX = (width - contextWidth) / 2
 local contextY = math.max(margin, height - bottomReserve - contextHeight)

 local actionGap = 8
 local actionWidth = math.min(244, availableWidth)
 local actionHeight = 44
 local actionX = (width - actionWidth) / 2
 local actionY = contextY - actionGap - actionHeight
 local actionAtTop = short and touch == true and width >= 568
 if actionAtTop then
  actionX = width - margin - actionWidth
  actionY = 12
  hudWidth = math.min(hudWidth, availableWidth - actionWidth - 12)
 end
 -- Large keyboard screens have room for a separate bottom-right pair. The
 -- narrower layout keeps the pair centered above the station command dock.
 if width >= 1024 and touch ~= true then
  actionX = width - margin - actionWidth
  actionY = height - 16 - actionHeight
 end
 local actionButtonWidth = (actionWidth - actionGap) / 2

 local panelMargin = 12
 local panelWidth = math.min(1010, math.max(1, width - panelMargin * 2))
 local panelHeight = math.min(664, math.max(1, height - panelMargin * 2))
 local panelPadding = compact and 16 or 24
 local headerHeight = short and 96 or 112
 local bodyWidth = math.max(1, panelWidth - panelPadding * 2)
 local bodyHeight = math.max(1, panelHeight - headerHeight - panelPadding)
 local cardGap = 14
 local cardColumns = width >= 800 and bodyWidth >= 240 * 3 + cardGap * 2 and 3 or 1
 local cardWidth = (bodyWidth - cardGap * (cardColumns - 1)) / cardColumns
 local cardHeight = 320

 return {
  mobile = mobile,
  compact = compact,
  short = short,
  hudWidth = hudWidth,
  hudHeight = hudHeight,
  hudX = hudX,
  hudY = hudY,
  panelWidth = panelWidth,
  panelHeight = panelHeight,
  panelX = (width - panelWidth) / 2,
  panelY = (height - panelHeight) / 2,
  panelPadding = panelPadding,
  headerHeight = headerHeight,
  bodyWidth = bodyWidth,
  bodyHeight = bodyHeight,
  cardWidth = cardWidth,
  cardHeight = cardHeight,
  cardColumns = cardColumns,
  cardGap = cardGap,
  contextWidth = contextWidth,
  contextHeight = contextHeight,
  contextX = contextX,
  contextY = contextY,
  actionWidth = actionWidth,
  actionHeight = actionHeight,
  actionX = actionX,
  actionY = actionY,
  actionAtTop = actionAtTop,
  -- At very short native-safe heights, the station command uses the space
  -- occupied by resources. Show resources again when that command disappears.
  contextReplacesHUD = actionAtTop and height < 300,
  recallWidth = actionButtonWidth,
  recallHeight = actionHeight,
  recallX = actionX,
  recallY = actionY,
  evadeX = actionX + actionButtonWidth + actionGap,
  evadeY = actionY,
  objectiveWidth = math.min(360, availableWidth),
  objectiveHeight = objectiveHeight,
  objectiveY = objectiveY,
  bottomReserve = bottomReserve,
 }
end

return Layout


end)()
local Interface = (function()
-- Shared native skin: dark backing, colorful studded surfaces and purposeful input feedback.
local U={}
local TweenService=game:GetService('TweenService')
local GuiService=game:GetService('GuiService')
U.palette={ink=Color3.fromRGB(9,14,30),panel=Color3.fromRGB(24,29,49),paper=Color3.fromRGB(43,53,80),
 text=Color3.fromRGB(250,252,255),muted=Color3.fromRGB(192,205,230),accent=Color3.fromRGB(28,145,224),
 mineral=Color3.fromRGB(30,159,97),line=Color3.fromRGB(8,12,27),danger=Color3.fromRGB(217,49,76),white=Color3.fromRGB(255,255,255)}
local C=U.palette
local bases=setmetatable({},{__mode='k'});local tweens=setmetatable({},{__mode='k'});local enabledStates=setmetatable({},{__mode='k'})
local function buttonText(color)
 local brightness=color.R*.2126+color.G*.7152+color.B*.0722
 return brightness>.72 and C.ink or C.white
end
local function layer(parent) return parent:IsA('GuiObject') and parent.ZIndex+1 or 2 end
function U.corner(parent,radius)
 local c=parent:FindFirstChildOfClass('UICorner') or Instance.new('UICorner');c.CornerRadius=UDim.new(0,radius or 12);c.Parent=parent;return c
end
function U.stroke(parent,color,width)
 local s=parent:FindFirstChildOfClass('UIStroke') or Instance.new('UIStroke');s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color or C.line;s.Thickness=width or 2;s.Parent=parent;return s
end
function U.frame(parent,pos,size,color)
 local f=Instance.new('Frame');f.Position=pos;f.Size=size;f.BackgroundColor3=color or C.panel;f.BorderSizePixel=0;f.ZIndex=layer(parent);f.Parent=parent;return f
end
function U.gradient(parent,_color)
 local g=parent:FindFirstChildOfClass('UIGradient') or Instance.new('UIGradient');g.Name='SurfaceGradient';g.Rotation=90
 g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.38,Color3.fromRGB(242,242,242)),ColorSequenceKeypoint.new(1,Color3.fromRGB(180,180,180))});g.Enabled=true;g.Parent=parent;return g
end
function U.unskin(root)
 local texture=root:FindFirstChild('StudSurface');if texture then texture:Destroy() end
 local gradient=root:FindFirstChildOfClass('UIGradient');if gradient then gradient:Destroy() end
end
function U.skin(root,color,radius,textureOpacity)
 color=color or C.panel;radius=radius or 12
 root.BackgroundColor3=color;root.BackgroundTransparency=0;U.corner(root,radius)
 local edge=U.stroke(root,color:Lerp(C.ink,.72),2);edge.Transparency=0
 U.gradient(root,color)
 if root:IsA('GuiButton') then root:SetAttribute('EnabledColor',color);bases[root]=color end
 local texture=root:FindFirstChild('StudSurface')
 if not texture then
  texture=Instance.new('CanvasGroup');texture.Name='StudSurface';texture.BackgroundTransparency=1;texture.Position=UDim2.fromOffset(2,2);texture.Size=UDim2.new(1,-4,1,-4);texture.ZIndex=root.ZIndex+1;texture.Active=false;texture.Parent=root
  U.corner(texture,math.max(1,radius-2))
  local function fit()
   if not texture.Parent then return end
   local bands=math.clamp(math.ceil(math.max(root.Size.Y.Offset,root.AbsoluteSize.Y)/80),1,10)
   for i=#texture:GetChildren(),bands do -- UICorner is the first child.
    local tile=Instance.new('ImageLabel');tile.Name='StudBand';tile.BackgroundTransparency=1;tile.Position=UDim2.fromOffset(0,(i-1)*80);tile.Size=UDim2.new(1,0,0,80)
    tile.Image='rbxasset://textures/studs.dds';tile.ScaleType=Enum.ScaleType.Tile;tile.TileSize=UDim2.fromOffset(20,320);tile.ImageTransparency=textureOpacity or .94;tile.ZIndex=texture.ZIndex;tile.Parent=texture
   end
  end
  fit();root:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit)
 end
 return root
end
function U.panel(parent,pos,size,color,radius)
 local tint=color or C.panel
 if tint.R*.2126+tint.G*.7152+tint.B*.0722>.54 then tint=C.panel:Lerp(tint,.44) end
 local f=U.frame(parent,pos,size,tint);U.skin(f,tint,radius or 14);f.Active=true;return f
end
function U.text(parent,pos,size,text,sizePx,color,bold)
 local t=Instance.new('TextLabel');t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.BorderSizePixel=0
 t.Text=text or '';t.TextColor3=color or C.text;t.TextSize=sizePx or 16;t.TextXAlignment=Enum.TextXAlignment.Left
 t.TextYAlignment=Enum.TextYAlignment.Center;t.Font=bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
 t.TextWrapped=true;t.ZIndex=layer(parent)+1;t.Parent=parent;return t
end
function U.badge(parent,pos,size,text,color)
 local b=U.panel(parent,pos,size,(color or C.mineral):Lerp(C.panel,.35),8)
 local t=U.text(b,UDim2.fromOffset(6,2),UDim2.new(1,-12,1,-4),text,12,C.text,true);t.TextXAlignment=Enum.TextXAlignment.Center
 return b
end
local function quiet()
 local reduced=false;pcall(function() reduced=GuiService.ReducedMotionEnabled end)
 local player=game:GetService('Players').LocalPlayer
 return reduced or (player and (player:GetAttribute('ReducedMotion')==true or player:GetAttribute('MA_ReducedMotion')==true))
end
local function paint(button,color,scale)
 if tweens[button] then for _,t in ipairs(tweens[button]) do t:Cancel() end end
 local a=TweenService:Create(button,TweenInfo.new(.13,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=color})
 local uiScale=button:FindFirstChild('ButtonScale');local b=uiScale and TweenService:Create(uiScale,TweenInfo.new(.13),{Scale=quiet() and 1 or scale or 1})
 tweens[button]={a,b};a:Play();if b then b:Play() end
end
function U.button(parent,pos,size,text,callback,color)
 local b=Instance.new('TextButton');b.Position=pos;b.Size=size;b.BackgroundColor3=color or C.mineral;b.BorderSizePixel=0
 b.Text=text;b.TextColor3=buttonText(b.BackgroundColor3);b.TextSize=16;b.Font=Enum.Font.SourceSansBold;b.TextWrapped=true;b.AutoButtonColor=false
 b.TextStrokeColor3=C.ink;b.TextStrokeTransparency=.65;b.ZIndex=layer(parent);b.Parent=parent;U.skin(b,b.BackgroundColor3,11,.92)
 local scale=Instance.new('UIScale');scale.Name='ButtonScale';scale.Parent=b
 local function base() return b:GetAttribute('EnabledColor') or bases[b] or C.mineral end
 local function focus() if b.Active then paint(b,base():Lerp(C.white,.16),1.025) end end
 local function rest() if b.Active then paint(b,base(),1) end end
 b.MouseEnter:Connect(focus);b.MouseLeave:Connect(rest);b.SelectionGained:Connect(focus);b.SelectionLost:Connect(rest)
 b.MouseButton1Down:Connect(function() if b.Active then paint(b,base():Lerp(C.ink,.16),.975) end end)
 b.MouseButton1Up:Connect(focus)
 b.Activated:Connect(function() if b.Active and callback then callback() end end)
 b.Destroying:Connect(function() if tweens[b] then for _,t in ipairs(tweens[b]) do t:Cancel() end end;tweens[b]=nil;bases[b]=nil;enabledStates[b]=nil end)
 return b
end
function U.setEnabled(b,enabled)
 enabled=enabled==true
 local color=b:GetAttribute('EnabledColor') or bases[b] or C.mineral
 local state=enabledStates[b]
 if state and state.enabled==enabled and state.color==color then return end
 enabledStates[b]={enabled=enabled,color=color}
 if tweens[b] then for _,t in ipairs(tweens[b]) do t:Cancel() end end
 b.Active=enabled;b.Selectable=enabled;b.BackgroundColor3=enabled and color or C.paper
 b.TextColor3=enabled and buttonText(color) or C.muted
 local s=b:FindFirstChild('ButtonScale');if s then s.Scale=1 end
end
function U.icon(parent,kind,pos,size,color)
 local root=U.frame(parent,pos,size,C.white);root.BackgroundTransparency=1;root.Name='Icon_'..kind
 local tint=color or C.mineral
 local function shape(x,y,w,h,c,r,turn,outline)
  local p=U.frame(root,UDim2.fromScale(x,y),UDim2.fromScale(w,h),c);if r then local round=Instance.new('UICorner');round.CornerRadius=UDim.new(r,0);round.Parent=p end
  if turn then p.Rotation=turn end;if outline then U.stroke(p,C.ink,1.8) end;return p
 end
 if kind=='coin' then
  shape(.12,.12,.76,.76,tint,1,nil,true);shape(.25,.25,.5,.5,tint:Lerp(C.white,.28),1)
  local t=U.text(root,UDim2.fromScale(.18,.16),UDim2.fromScale(.64,.64),'C',size.X.Offset*.43,C.ink,true);t.TextXAlignment=Enum.TextXAlignment.Center
 elseif kind=='cargo' then
  shape(.30,.10,.4,.22,C.ink,.25);shape(.19,.24,.62,.62,tint,.16,nil,true)
  shape(.29,.55,.42,.20,tint:Lerp(C.ink,.18),.12);shape(.47,.28,.07,.55,C.white,.1)
 elseif kind=='cards' then
  shape(.15,.20,.42,.62,tint:Lerp(C.ink,.22),.1,-14,true);shape(.42,.17,.42,.62,tint,.1,10,true)
  shape(.51,.31,.23,.23,C.white,.12,45)
 elseif kind=='drone' or kind=='fleet' then
  shape(.03,.25,.27,.09,C.ink,.25,-25);shape(.70,.25,.27,.09,C.ink,.25,25)
  shape(.22,.24,.56,.52,tint,.16,nil,true);shape(.30,.46,.40,.10,C.ink,.1)
  shape(.36,.48,.26,.04,C.white,.1);shape(.47,.09,.06,.15,C.ink,.2)
 elseif kind=='combat' then
  shape(.38,.38,.24,.24,tint,.1,45,true)
  for _,v in ipairs({{.44,.08,.12,.22},{.44,.70,.12,.22},{.08,.44,.22,.12},{.70,.44,.22,.12}}) do shape(v[1],v[2],v[3],v[4],C.ink,.2) end
 elseif kind=='survival' then
  shape(.24,.14,.52,.60,tint,.32,nil,true);shape(.32,.50,.36,.36,tint,.1,45)
  shape(.45,.25,.10,.39,C.ink,.1);shape(.33,.39,.34,.10,C.ink,.1)
 elseif kind=='prestige' then
  shape(.24,.24,.52,.52,tint,.08,45,true);shape(.17,.37,.66,.26,tint,.08)
  shape(.45,.27,.10,.46,C.ink,.1);shape(.29,.45,.42,.10,C.ink,.1)
 elseif kind=='startup' then
  shape(.14,.14,.72,.72,tint,.9,nil,true);shape(.44,.28,.12,.30,C.ink,.1);shape(.44,.48,.27,.10,C.ink,.1,25)
 elseif kind=='mining' then
  shape(.43,.10,.20,.42,tint,.04,28,true)
  shape(.25,.43,.50,.15,tint,.04,-5,true)
  shape(.34,.49,.20,.40,tint,.04,28,true)
 elseif kind=='laser' or kind=='relay' then
  shape(.16,.16,.31,.31,tint,.12,nil,true)
  shape(.40,.42,.47,.12,tint,.12,45,true)
  if kind=='relay' then shape(.44,.38,.39,.10,tint,.12,-16,true) end
 elseif kind=='hammer' then
  shape(.37,.38,.16,.48,tint,.12,30,true)
  shape(.24,.18,.57,.24,tint,.12,30,true)
 elseif kind=='seed' then
  shape(.22,.22,.32,.48,tint,.4,-34,true);shape(.48,.17,.29,.44,tint,.4,35,true)
  shape(.45,.48,.10,.34,C.ink,.15,12)
 elseif kind=='swarm' then
  shape(.31,.12,.38,.31,tint,.2,nil,true)
  shape(.10,.51,.34,.31,tint,.2,nil,true);shape(.56,.51,.34,.31,tint,.2,nil,true)
 elseif kind=='flight' then
  shape(.22,.39,.56,.20,tint,.15,nil,true);shape(.34,.20,.15,.6,C.ink,.1,42);shape(.56,.27,.15,.54,C.ink,.1,-42)
 else
  shape(.23,.22,.40,.60,tint,.06,24,true);shape(.52,.36,.27,.43,tint:Lerp(C.white,.2),.06,38,true)
  shape(.29,.26,.09,.32,C.white,.05,24)
 end
 return root
end
return U


end)()
local Packs = (function()
-- Delivery and hold timing shared by authority and presentation.
local Packs = {
 Range = 8,
 DeliveryTime = 1.7,
 DropTime = 1.27,
 DepartTime = 2.45,
 Tiers = {'Common', 'Rare', 'Epic', 'Legendary'},
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
local CardView = (function()
-- Presentation only. Two text elements per card: effect and target/terms.
-- The complete saved server choice remains the selection contract.
local CardView={HEIGHT=320,MIN_HEIGHT=212}

local function percent(value) return string.format('%g%%',math.floor(value*100+.5)) end
local function amount(value,label) return '+'..percent(value)..' '..label end
local function reach(choice,key,fallback)
 for _,row in ipairs(choice.preview or {}) do if type(row)=='table' and row.label==key and type(row.after)=='number' then return row.after end end
 return fallback
end

function CardView.summary(choice)
 local e=choice.effects or {};local lines={}
 local function add(key,text) if type(e[key])=='number' and e[key]>0 then table.insert(lines,text) end end
 add('orbitalLaser','Call an orbital strike on the biggest rock')
 add('scrapSwarm','Deploy tiny miners for 10 seconds')
 add('plotAuto','Drones choose stones for you')
 add('fullAuto',amount(e.fullAuto or 0,'courier speed'))
 add('mining',amount(e.mining or 0,'mining power'))
 add('combat',amount(e.combat or 0,'attack damage'))
 add('rate',amount(e.rate or 0,'attack speed'))
 add('health',amount(e.health or 0,'drone health'))
 add('reduction','Block '..percent(e.reduction or 0)..' damage')
 add('capacity',amount(e.capacity or 0,'backpack space'))
 add('speed',amount(e.speed or 0,'drone speed'))
 add('startup',amount(e.startup or 0,'laser startup speed'))
 add('yield',amount(e.yield or 0,'ore per crystal'))
 add('range',amount(e.range or 0,'attack range'))
 add('crit',percent(e.crit or 0)..' chance to hit twice')
 add('fork','Hit a nearby crystal for '..percent(e.fork or 0)..' damage')
 add('splash','Hit a nearby sentry for '..percent(e.splash or 0)..' damage')
 add('shield','Start fights with '..percent(e.shield or 0)..' shield')
 add('finisher',amount(e.finisher or 0,'damage to weak sentries'))
 add('geode',amount(e.geode or 0,'geode damage'))
 add('salvage','Kills repair '..percent(e.salvage or 0)..' health')
 return #lines>0 and table.concat(lines,'\n') or (choice.description or choice.title or 'Run upgrade')
end

function CardView.terms(choice,_targetOverride)
 local e=choice.effects or {};local target
 local work=(e.mining or 0)>0 or (e.startup or 0)>0 or (e.yield or 0)>0 or (e.fork or 0)>0 or (e.geode or 0)>0 or (e.plotAuto or 0)>0
 local allRoles=(e.speed or 0)>0 or (e.health or 0)>0 or (e.reduction or 0)>0 or (e.shield or 0)>0
 if (e.orbitalLaser or 0)>0 then target='Your orbital laser'
 elseif (e.scrapSwarm or 0)>0 then target='Your scrap bots'
 elseif e.fullAuto and e.fullAuto>0 and choice.scope=='Player' then target='Your couriers'
 elseif choice.scope=='Individual' then target=choice.targetName or 'One drone'
 elseif choice.scope=='Color' then target=(choice.type or '')..(work and not allRoles and ' mining drones' or ' drones')
 elseif choice.scope=='Player' then target='Your backpack'
 elseif e.capacity and e.capacity>0 then target='Drones + backpack'
 elseif work and not allRoles then target='Mining drones'
 else target='All drones' end
 if choice.workshop then
  local before=choice.stackBefore
  local count=before and (before>0 and (before..'× → '..(before+choice.level)..'×') or ('NEW · '..choice.level..'×')) or (choice.level..'×')
  return target..' · This run\n'..count..' · '..choice.rarity
 end
 local details={target..' · This run'}
 local losses={}
 for _,entry in ipairs({{'speed','drone speed'},{'mining','mining speed'},{'combat','attack damage'},{'health','drone health'},{'startup','startup speed'},{'yield','ore yield'},{'capacity','backpack space'}}) do
  local n=e[entry[1]];if type(n)=='number' and n<0 then table.insert(losses,'−'..percent(-n)..' '..entry[2]) end
 end
 if #losses>0 then table.insert(details,table.concat(losses,', ')) end
 if (e.finisher or 0)>0 then table.insert(details,'Weak = below 35% health') end
 if (e.fork or 0)>0 then table.insert(details,string.format('One crystal within %g studs',reach(choice,'Split reach',6+math.clamp(e.forkRange or 0,0,6)))) end
 if (e.splash or 0)>0 then table.insert(details,string.format('One sentry within %g studs',reach(choice,'Arc reach',6+math.clamp(e.chain or 0,0,16)))) end
 return table.concat(details,'\n')
end

-- ViewportFrame cannot render nested GuiObjects. The supported hierarchy is a
-- real camera-local card > SurfaceGui face > small ViewportFrame illustration.
-- Screen-space hitboxes retain ordinary touch, keyboard and controller input.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local GuiService=game:GetService('GuiService')
local UserInputService=game:GetService('UserInputService')
local serial=0
local bindPrefix='UpgradeCards'..game:GetService('HttpService'):GenerateGUID(false)
local FACE_PIXELS=3 -- Supersample the curved physical face; screen text stays native.

local function visualPart(parent,size,position,color,shape)
 local part=Instance.new('Part');part.Size=size;part.CFrame=CFrame.new(position);part.Color=color
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Material=Enum.Material.Plastic;part.Reflectance=0;part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 if shape then part.Shape=shape end
 part.Parent=parent;return part
end
-- Identity follows the mechanic, never a rainbow rarity assignment.
function CardView.identity(choice)
 local e=choice.effects or {}
 local function has(k) return type(e[k])=='number' and e[k]>0 end
 if has('orbitalLaser') then return 'orbital',Color3.fromRGB(219,58,35),Color3.fromRGB(255,223,82) end
 if has('scrapSwarm') then return 'swarm',Color3.fromRGB(103,49,209),Color3.fromRGB(191,255,98) end
 if has('plotAuto') then return 'scanner',Color3.fromRGB(0,119,114),Color3.fromRGB(142,255,153) end
 if has('fork') then return 'prism',Color3.fromRGB(42,75,203),Color3.fromRGB(88,244,255) end
 if has('capacity') or has('fullAuto') then return 'cargo',Color3.fromRGB(200,93,10),Color3.fromRGB(255,224,101) end
 if has('health') or has('reduction') or has('salvage') or has('shield') then return 'repair',Color3.fromRGB(12,125,65),Color3.fromRGB(164,255,180) end
 if has('combat') or has('rate') or has('crit') or has('splash') or has('finisher') or has('range') then return 'combat',Color3.fromRGB(178,30,80),Color3.fromRGB(255,161,198) end
 if has('speed') or has('startup') then return 'thrust',Color3.fromRGB(0,104,179),Color3.fromRGB(121,237,255) end
 return 'mineral',Color3.fromRGB(104,49,170),Color3.fromRGB(245,177,255)
end

-- One textured surface and one rounded border, shared by cards and packs.
-- Use Roblox's shipped stud atlas; no uploaded art or per-stud GUI objects.
function CardView.housing(U,root,color,_accent)
 local pixels=root.Parent:IsA('SurfaceGui') and FACE_PIXELS or 1
 root.BackgroundColor3=color
 local finish=Instance.new('UIGradient');finish.Name='GlossColor';finish.Rotation=90
 finish.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.42,Color3.fromRGB(220,228,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(85,87,130))});finish.Parent=root
 local corner=root:FindFirstChildOfClass('UICorner') or U.corner(root,20*pixels)
 corner.CornerRadius=UDim.new(0,20*pixels)
 local edge=U.stroke(root,Color3.fromRGB(16,28,55),3*pixels)
 edge.BorderStrokePosition=Enum.BorderStrokePosition.Inner;edge.ZIndex=root.ZIndex+5
 local texture=Instance.new('CanvasGroup');texture.Name='StudTexture';texture.BackgroundTransparency=1
 texture.Size=UDim2.fromScale(1,1);texture.ZIndex=root.ZIndex+1;texture.Parent=root;U.corner(texture,20*pixels)
 -- The shipped image is an atlas. Tile its first 512-pixel stud region in
 -- short bands; cropped ImageRects do not honor TileSize in the native UI.
 local band=96*pixels
 local bands=math.max(1,math.ceil(math.max(root.Size.Y.Offset,band)/band))
 for i=0,bands-1 do
  local tile=Instance.new('ImageLabel');tile.Name='StudBand';tile.BackgroundTransparency=1
  tile.Position=UDim2.fromOffset(0,i*band);tile.Size=UDim2.new(1,0,0,band)
  tile.Image='rbxasset://textures/studs.dds';tile.ScaleType=Enum.ScaleType.Tile
  tile.TileSize=UDim2.fromOffset(24*pixels,384*pixels)
  tile.ImageColor3=color:Lerp(Color3.new(1,1,1),.2);tile.ImageTransparency=.83
  tile.ZIndex=texture.ZIndex+1;tile.Parent=texture
 end
 return edge
end

local function mechanicVisual(parent,choice,compact)
 local viewport=Instance.new('ViewportFrame');viewport.Name='MechanicPreview';viewport.BackgroundTransparency=1;viewport.ZIndex=parent.ZIndex+4
 viewport.Position=UDim2.fromScale(.045,.022);viewport.Size=UDim2.fromScale(.91,compact and .32 or .46)
 viewport.Ambient=Color3.fromRGB(205,210,225);viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-2,-3);viewport.Parent=parent
 local world=Instance.new('WorldModel');world.Name='Mechanic';world.Parent=viewport
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.CFrame=CFrame.lookAt(Vector3.new(4,3,7),Vector3.new(0,-.1,0));camera.Parent=viewport;viewport.CurrentCamera=camera
 local identity,body,accent=CardView.identity(choice)
 local storage=game:GetService('ReplicatedStorage')
 local config=storage:FindFirstChild('Shared');config=config and config:FindFirstChild('DroneConfig')
 local roles=config and require(config)
 local function safe(model)
  for _,c in ipairs(model:GetDescendants()) do
   if c:IsA('LuaSourceContainer') or c:IsA('Sound') or c:IsA('BillboardGui') or c:IsA('SurfaceGui') then c:Destroy()
   elseif c:IsA('BasePart') then c.Anchored=true;c.CanCollide=false;c.CanTouch=false;c.CanQuery=false;c.CastShadow=false;c.Reflectance=0
   elseif c:IsA('Trail') or c:IsA('Beam') or c:IsA('ParticleEmitter') then c.Enabled=false end
  end
 end
 local function drone(role,size,position,rotation)
  local template=storage:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
  if not template or not template:IsA('Model') then return end
  local model=template:Clone();safe(model)
  if roles then
   roles.decorate(model,role)
  else
   local shell=model:FindFirstChild('Mesh')
   if shell and shell:IsA('BasePart') then shell.Color=Color3.fromRGB(66,87,111):Lerp(body,.25) end
  end
  safe(model)
  local _,bounds=model:GetBoundingBox();model:ScaleTo(model:GetScale()*size/math.max(bounds.X,bounds.Y,bounds.Z,.01))
  local box=model:GetBoundingBox();model:PivotTo(CFrame.new(position)*(rotation or CFrame.new())*box:Inverse()*model:GetPivot())
  model.Parent=world;return model
 end
 local function crystal(size,position,color,rotation)
  local original=storage:FindFirstChild('Crystal') or workspace:FindFirstChild('Crystal')
  local template=original and original:FindFirstChild('Mesh',true)
  if not template or not template:IsA('BasePart') then return end
  local part=template:Clone();safe(part)
  part.Size=template.Size*(size/math.max(template.Size.Y,.01));part.CFrame=CFrame.new(position)*(rotation or CFrame.new())
  part.Color=color;part.Material=Enum.Material.SmoothPlastic;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Reflectance=0;part.Parent=world
  return part
 end
 local function ray(a,b,width,color)
  local length=(b-a).Magnitude
  local halo=visualPart(world,Vector3.new(length,width*2.4,width*2.4),(a+b)/2,color,Enum.PartType.Cylinder);halo.Transparency=.68
  halo.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0)
  local core=visualPart(world,Vector3.new(length,width,width),(a+b)/2,color:Lerp(Color3.new(1,1,1),.7),Enum.PartType.Cylinder)
  core.CFrame=halo.CFrame
 end
 local function chips(position,color)
  for i=1,5 do
   local a=i*math.pi*2/5
   crystal(.35+i%2*.12,position+Vector3.new(math.cos(a)*.95,.1+i%2*.25,math.sin(a)*.65),color,CFrame.Angles(.2,a,.3))
  end
 end
 if identity=='orbital' then
  drone('Orbiter',2.6,Vector3.new(0,1.25,0))
  crystal(2,Vector3.new(0,-1.4,0),Color3.fromRGB(246,116,57),CFrame.Angles(0,.3,-.1))
  ray(Vector3.new(0,.75,0),Vector3.new(0,-.9,0),.2,accent)
  chips(Vector3.new(0,-1.65,0),accent)
 elseif identity=='swarm' then
  for i=1,3 do
   local x=(i-2)*1.45;local y=i==2 and .8 or .15
   drone('Scrapper',1.65,Vector3.new(x,y,0),CFrame.Angles(0,(i-2)*-.3,(i-2)*.15))
   ray(Vector3.new(x,y-.4,0),Vector3.new(x*.6,-1.1,0),.065,accent)
  end
  crystal(1.7,Vector3.new(0,-1.6,0),Color3.fromRGB(185,122,255),CFrame.Angles(0,.4,-.15));chips(Vector3.new(0,-1.5,0),accent)
 elseif identity=='prism' then
  drone('Striker',1.85,Vector3.new(0,1.25,0),CFrame.Angles(0,-.3,.08))
  local prism=visualPart(world,Vector3.new(.85,1.1,.85),Vector3.new(0,-.15,0),accent)
  prism.CFrame=CFrame.new(0,-.15,0)*CFrame.Angles(0,math.rad(45),math.rad(25))
  ray(Vector3.new(0,.65,0),Vector3.new(0,.2,0),.11,accent)
  for _,sign in ipairs({-1,1}) do
   local color=sign<0 and Color3.fromRGB(129,255,179) or Color3.fromRGB(255,154,222)
   crystal(1.6,Vector3.new(sign*1.25,-1.35,0),color,CFrame.Angles(0,sign*.5,sign*.12))
   ray(Vector3.new(0,-.15,0),Vector3.new(sign*1.25,-.75,0),.11,color)
  end
 elseif identity=='cargo' then
  drone('Courier',3.1,Vector3.new(.25,.45,0),CFrame.Angles(0,-.25,.08))
  for i=1,3 do crystal(1.05,Vector3.new((i-2)*.6,-1.2,.8),accent,CFrame.Angles(0,i*.7,-.15)) end
 elseif identity=='repair' then
  drone('Medic',3.3,Vector3.new(0,.15,0),CFrame.Angles(.1,-.2,-.15))
  for i=1,3 do
   local x=(i-2)*1.25;local y=i==2 and 1.6 or -.9
   visualPart(world,Vector3.new(.14,.55,.14),Vector3.new(x,y,.5),accent)
   visualPart(world,Vector3.new(.55,.14,.14),Vector3.new(x,y,.5),accent)
  end
 elseif identity=='thrust' then
  drone('Striker',2.75,Vector3.new(.7,.15,0),CFrame.Angles(0,-.3,-.22))
  for i=-1,1 do ray(Vector3.new(-2.3,i*.5,-.2),Vector3.new(-.55,i*.5+.3,-.2),.12,accent) end
 elseif identity=='scanner' then
  drone('Dart',2.5,Vector3.new(0,.95,0),CFrame.Angles(0,-.3,0))
  for i=-1,1 do crystal(1.4,Vector3.new(i*1.25,-1.1,0),i==0 and accent or body:Lerp(accent,.4),CFrame.Angles(0,i*.4,.1)) end
  ray(Vector3.new(0,.4,0),Vector3.new(-1.25,-.4,0),.07,accent);ray(Vector3.new(0,.4,0),Vector3.new(1.25,-.4,0),.07,accent)
 elseif identity=='combat' then
  drone('Charger',3.1,Vector3.new(0,.45,0),CFrame.Angles(0,-.4,-.22))
  for i=-1,1 do ray(Vector3.new(i*.6,-.45,.2),Vector3.new(i*.9,-1.65,.2),.12,accent) end
  chips(Vector3.new(0,-1.6,0),accent)
 else
  drone('Striker',2,Vector3.new(-.8,1.05,0),CFrame.Angles(0,-.25,-.1))
  crystal(2.7,Vector3.new(.45,-.7,0),accent,CFrame.Angles(0,.35,-.17))
  ray(Vector3.new(-.8,.6,0),Vector3.new(.1,.05,0),.11,accent);chips(Vector3.new(0,-1.5,0),body:Lerp(accent,.65))
 end
 -- Four offset black renders dilate the real model silhouette. Roblox's
 -- world Highlight is not required, and a frame outline cannot outline models.
 for _,offset in ipairs({{-1,-1},{-1,1},{1,-1},{1,1}}) do
  local outline=viewport:Clone();outline.Name='ArtworkSilhouette';outline.CurrentCamera=camera
  local copiedCamera=outline:FindFirstChildOfClass('Camera');if copiedCamera then copiedCamera:Destroy() end
  outline.ImageColor3=Color3.new(0,0,0);outline.Position=viewport.Position+UDim2.fromOffset(offset[1]*2.5*FACE_PIXELS,offset[2]*2.5*FACE_PIXELS)
  outline.ZIndex=viewport.ZIndex-1;outline.Parent=parent
 end
 return viewport,camera
end

-- Shipped radial light has transparent, feathered spokes and ends.
local function sunburst(_U,canvas,compact,color)
 local rays=Instance.new('ImageLabel');rays.Name='SpinningRays';rays.BackgroundTransparency=1
 rays.AnchorPoint=Vector2.new(.5,.5);rays.Position=UDim2.fromScale(.5,compact and .182 or .252)
 rays.Size=UDim2.fromScale(1,compact and .54 or .76);rays.Image='rbxasset://textures/glow.png'
 rays.ImageColor3=color:Lerp(Color3.new(1,1,1),.65);rays.ImageTransparency=.35;rays.ZIndex=canvas.ZIndex+2;rays.Parent=canvas
 local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.DominantAxis=Enum.DominantAxis.Height;aspect.Parent=rays
 return rays
end

-- Concentric alpha layers approximate a continuous Gaussian without a
-- particle texture's colored/opaque RGB contaminating the card enamel.
local function softGlow(U,parent,name,color)
 local glow=Instance.new('CanvasGroup');glow.Name=name;glow.BackgroundTransparency=1;glow.AnchorPoint=Vector2.new(.5,.5)
 glow.Size=UDim2.fromScale(1.1,.8);glow.Position=UDim2.fromScale(.5,.25);glow.GroupTransparency=1;glow.ZIndex=parent.ZIndex+1;glow.Parent=parent
 local previous=0
 for i=1,32 do
  local radius=1-(i-1)/32
  local opacity=.6*(math.exp(-radius*radius*4)-math.exp(-4))/(1-math.exp(-4))
  local alpha=(opacity-previous)/math.max(.001,1-previous);previous=opacity
  local disc=U.frame(glow,UDim2.fromScale((1-radius)/2,(1-radius)/2),UDim2.fromScale(radius,radius),color)
  disc.ZIndex=glow.ZIndex;disc.BackgroundTransparency=1-alpha;U.corner(disc,999)
 end
 return glow
end

local function shineLayer(U,canvas,rim)
 local shine=Instance.new('CanvasGroup');shine.Name='FaceLight';shine.BackgroundTransparency=1;shine.Size=UDim2.fromScale(1,1);shine.ZIndex=canvas.ZIndex+2;shine.Parent=canvas;U.corner(shine,20*FACE_PIXELS)
 local sweep=U.frame(shine,UDim2.fromScale(-.6,-.25),UDim2.fromScale(.7,1.5),Color3.new(1,1,1));sweep.Name='GlossSweep';sweep.Rotation=22;sweep.Visible=false
 local g=Instance.new('UIGradient');g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,1),NumberSequenceKeypoint.new(.35,.95),NumberSequenceKeypoint.new(.5,.78),NumberSequenceKeypoint.new(.65,.95),NumberSequenceKeypoint.new(.82,1),NumberSequenceKeypoint.new(1,1)});g.Parent=sweep
 local spot=softGlow(U,shine,'MouseHighlight',Color3.new(1,1,1))
 local ambient=softGlow(U,shine,'EnamelLight',rim:Lerp(Color3.new(1,1,1),.65));ambient.GroupTransparency=.82;ambient.Size=UDim2.fromScale(1.3,.9);ambient.Position=UDim2.fromScale(.4,.17)
 local flash=Instance.new('ImageLabel');flash.Name='RimFlash';flash.BackgroundTransparency=1;flash.Image='rbxasset://textures/particles/sparkles_main.dds';flash.ImageColor3=rim:Lerp(Color3.new(1,1,1),.65);flash.Size=UDim2.fromOffset(32*FACE_PIXELS,32*FACE_PIXELS);flash.AnchorPoint=Vector2.new(.5,.5);flash.ImageTransparency=1;flash.ZIndex=canvas.ZIndex+7;flash.Parent=canvas
 return sweep,spot,flash
end
local function visibleRect(root)
 local position,size=root.AbsolutePosition,root.AbsoluteSize
 local left,top,right,bottom=position.X,position.Y,position.X+size.X,position.Y+size.Y
 local ancestor=root
 while ancestor do
  if ancestor:IsA('GuiObject') then
   if not ancestor.Visible then return nil end
   if ancestor~=root and (ancestor.ClipsDescendants or ancestor:IsA('ScrollingFrame')) then
    local p,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize
    left=math.max(left,p.X);top=math.max(top,p.Y);right=math.min(right,p.X+s.X);bottom=math.min(bottom,p.Y+s.Y)
   end
  elseif ancestor:IsA('ScreenGui') and not ancestor.Enabled then return nil end
  ancestor=ancestor.Parent
 end
 if right-left<2 or bottom-top<2 or size.X<2 or size.Y<2 then return nil end
 return left,top,right,bottom
end
local function onPlane(camera,x,y,depth)
 -- AbsolutePosition and ScreenPointToRay both use CoreUISafeInsets coordinates.
 local ray=camera:ScreenPointToRay(x,y)
 local direction=camera.CFrame:VectorToObjectSpace(ray.Direction)
 return ray.Origin+ray.Direction*(depth/math.max(.001,-direction.Z))
end

function CardView.create(U,parent,choice,index,width,height,options)
 options=options or {};height=math.max(height or CardView.HEIGHT,CardView.MIN_HEIGHT)
 local compact=height<300
 local p=U.palette;local _,bodyColor,accentColor=CardView.identity(choice);local card=U.frame(parent,UDim2.fromOffset(0,0),UDim2.fromOffset(width,height),p.paper)
 card.Name='CardChoice'..tostring(index);card.LayoutOrder=index;card.BackgroundTransparency=1
 local choose=U.button(card,UDim2.fromScale(0,0),UDim2.fromScale(1,1),'',options.onChoose,p.paper)
 choose.Name='ChooseCard';U.unskin(choose);choose.TextTransparency=1;choose.BackgroundTransparency=1
 local outline=choose:FindFirstChildOfClass('UIStroke');if outline then outline.Enabled=false end
 local scale=choose:FindFirstChild('ButtonScale');if scale then scale:Destroy() end
 local selection=Instance.new('Frame');selection.Name='SelectionMask';selection.BackgroundTransparency=1;selection.Size=UDim2.fromScale(1,1);selection.Parent=choose
 choose.SelectionImageObject=selection -- The physical card border supplies focus, not a second square outline.
 local model=Instance.new('Folder');model.Name='LocalUpgradeCard';model.Parent=workspace
 local part=visualPart(model,Vector3.new(2,3,.05),Vector3.zero,Color3.fromRGB(74,83,88));part.Name='CardBody';part.Transparency=1
 local surface=Instance.new('SurfaceGui');surface.Name='UpgradeCardFace';surface.Adornee=part;surface.Face=Enum.NormalId.Front
 surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;surface.CanvasSize=Vector2.new(width*FACE_PIXELS,height*FACE_PIXELS)
 -- The current native renderer drops AlwaysOnTop faces, even on a minimal
 -- diagnostic part. Render these camera-local faces near the camera instead.
 surface.AlwaysOnTop=false;surface.LightInfluence=0;surface.Brightness=1;surface.MaxDistance=8;surface.Active=false;surface.Enabled=false;surface.ResetOnSpawn=false
 surface.ClipsDescendants=true;surface.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;surface.Parent=Players.LocalPlayer:WaitForChild('PlayerGui')
 local canvas=U.frame(surface,UDim2.fromOffset(0,0),UDim2.fromOffset(width*FACE_PIXELS,height*FACE_PIXELS),p.paper);canvas.Name='CardCanvas'
 local border=CardView.housing(U,canvas,bodyColor,accentColor)
 local rim=bodyColor:Lerp(Color3.new(1,1,1),.3)
 border.Color=bodyColor:Lerp(Color3.fromRGB(3,5,14),.75);border.Thickness=1.5*FACE_PIXELS
 -- Soft colored spill outside the bevel is drawn on a padded physical face.
 -- The enamel covers the overlapping centers, leaving only the feathered rim.
 local spill=Instance.new('Frame');spill.Name='RimGlow';spill.BackgroundTransparency=1;spill.Size=UDim2.fromScale(1,1);spill.ZIndex=canvas.ZIndex;spill.Parent=canvas
 for i=12,1,-1 do
  local spread=i*FACE_PIXELS
  local halo=U.frame(spill,UDim2.fromOffset(-spread,-spread),UDim2.new(1,spread*2,1,spread*2),bodyColor:Lerp(Color3.new(1,1,1),.12))
  halo.BackgroundTransparency=.965;halo.ZIndex=spill.ZIndex;U.corner(halo,20*FACE_PIXELS+spread)
 end
 local rimFace=U.frame(canvas,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1));rimFace.Name='RimBevel';rimFace.ZIndex=canvas.ZIndex;U.corner(rimFace,20*FACE_PIXELS)
 local inner=U.frame(rimFace,UDim2.fromOffset(5*FACE_PIXELS,5*FACE_PIXELS),UDim2.new(1,-10*FACE_PIXELS,1,-10*FACE_PIXELS),Color3.new(1,1,1));inner.Name='Enamel';inner.ZIndex=canvas.ZIndex;U.corner(inner,15*FACE_PIXELS)
 local enamel=Instance.new('UIGradient');enamel.Rotation=90;enamel.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,bodyColor:Lerp(Color3.new(1,1,1),.12)),ColorSequenceKeypoint.new(.28,bodyColor:Lerp(Color3.new(1,1,1),.025)),ColorSequenceKeypoint.new(.62,bodyColor),ColorSequenceKeypoint.new(1,bodyColor:Lerp(Color3.new(0,0,0),.33))});enamel.Parent=inner
 local rimLight=Instance.new('UIGradient');rimLight.Name='RimLight';rimLight.Rotation=118
 rimLight.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,bodyColor:Lerp(Color3.new(1,1,1),.88)),ColorSequenceKeypoint.new(.12,bodyColor:Lerp(Color3.new(1,1,1),.52)),ColorSequenceKeypoint.new(.40,bodyColor:Lerp(Color3.new(1,1,1),.12)),ColorSequenceKeypoint.new(.63,bodyColor:Lerp(Color3.new(0,0,0),.22)),ColorSequenceKeypoint.new(.85,bodyColor:Lerp(Color3.new(1,1,1),.12)),ColorSequenceKeypoint.new(1,bodyColor:Lerp(Color3.new(0,0,0),.34))});rimLight.Parent=rimFace
 local edge=U.stroke(inner,bodyColor:Lerp(Color3.new(1,1,1),.5),FACE_PIXELS);edge.Transparency=.5
 local texture=canvas:FindFirstChild('StudTexture');texture.Position=UDim2.fromOffset(5*FACE_PIXELS,5*FACE_PIXELS);texture.Size=UDim2.new(1,-10*FACE_PIXELS,1,-10*FACE_PIXELS);texture:FindFirstChildOfClass('UICorner').CornerRadius=UDim.new(0,15*FACE_PIXELS)
 local rays=sunburst(U,canvas,compact,accentColor)
 local sweep,spot,flash=shineLayer(U,canvas,rim)
 rays.Parent=canvas.FaceLight
 local _,artCamera=mechanicVisual(canvas,choice,compact)
 local summary=CardView.summary(choice)
 local function escape(v) return (tostring(v):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')) end
 local heading=escape(choice.title or 'Run upgrade')
 local bodyText=escape(summary)
 local display='<b>'..heading..'</b>\n'..bodyText
 -- Keep font rasterization and scrolling in the native screen layer. The
 -- body/art retain real perspective; near-camera SurfaceGui glyphs otherwise
 -- lose rows of pixels in the depth pass on the verified phone renderer.
 local effectY=compact and .37 or .48
 local termsY=compact and .72 or .80
 local effect=U.text(card,UDim2.new(0,12,effectY,0),UDim2.new(1,-24,compact and .33 or .30,0),display,compact and 16 or 18,p.white,true)
 effect.RichText=true;effect.Name='CardEffect';effect.TextXAlignment=Enum.TextXAlignment.Center
 effect.TextStrokeColor3=Color3.fromRGB(13,23,48);effect.TextStrokeTransparency=.5
 local terms=U.text(card,UDim2.new(0,12,termsY,0),UDim2.new(1,-24,compact and .24 or .16,0),CardView.terms(choice,options.target),16,p.white,false)
 terms.Name='CardTerms';terms.TextXAlignment=Enum.TextXAlignment.Center
 terms.TextStrokeColor3=Color3.fromRGB(13,23,48);terms.TextStrokeTransparency=.6
 local focused,pressed,blend=false,false,0
 local revealSpeed=math.clamp(options.revealSpeed or 1,1,4);local revealStart=os.clock()+(options.skipReveal and 0 or ((index-1)*.13)/revealSpeed)
 local reducedMotion=options.reducedMotion==true
 pcall(function() reducedMotion=GuiService.ReducedMotionEnabled end)
 local function motionReduced()
  return reducedMotion or options.reducedMotion==true or Players.LocalPlayer:GetAttribute('ReducedMotion')==true or Players.LocalPlayer:GetAttribute('MA_ReducedMotion')==true
 end
 local signals={}
 local function connect(signal,fn) table.insert(signals,signal:Connect(fn)) end
 connect(choose.MouseEnter,function() focused=true end);connect(choose.MouseLeave,function() focused=false;pressed=false end)
 connect(choose.SelectionGained,function() focused=true end);connect(choose.SelectionLost,function() focused=false;pressed=false end)
 connect(choose.MouseButton1Down,function() pressed=true end);connect(choose.MouseButton1Up,function() pressed=false end)
 pcall(function() connect(GuiService:GetPropertyChangedSignal('ReducedMotionEnabled'),function() reducedMotion=GuiService.ReducedMotionEnabled end) end)
 serial=serial+1;local stepName=bindPrefix..'Card'..serial
 local dead=false;local wasFocused=false;local focusAt=-10;local pointerX,pointerY=0,0
 local function dispose()
  if dead then return end;dead=true;RunService:UnbindFromRenderStep(stepName)
  for _,connection in ipairs(signals) do connection:Disconnect() end
  surface:Destroy();model:Destroy()
 end
 connect(card.Destroying,dispose)
 RunService:BindToRenderStep(stepName,Enum.RenderPriority.Camera.Value+8,function(dt)
  if dead then return end
  local camera=workspace.CurrentCamera;local left,top,right,bottom=visibleRect(card)
  if not camera or not left then surface.Enabled=false;part.Transparency=1;return end
  local clock=os.clock();local age=clock-revealStart;local quiet=motionReduced()
  local instant=quiet or options.skipReveal
  if not instant and age<0 then choose.Visible=false;effect.Visible=false;terms.Visible=false;surface.Enabled=false;return end
  local progress=instant and 1 or math.clamp(age/(.67/revealSpeed),0,1)
  local reveal=1-(1-progress)^3
  choose.Visible=progress>=.85
  local position,size=card.AbsolutePosition,card.AbsoluteSize
  local full=right-left>=size.X-.5 and bottom-top>=size.Y-.5
  local target=focused and choose.Active and 1 or 0
  if target==1 and not wasFocused then focusAt=clock end;wasFocused=target==1
  local nx,ny=0,0
  if target==1 and UserInputService.MouseEnabled then local mouse=UserInputService:GetMouseLocation();nx=math.clamp((mouse.X-position.X)/math.max(1,size.X)*2-1,-1,1);ny=math.clamp((mouse.Y-position.Y)/math.max(1,size.Y)*2-1,-1,1) end
  local response=1-math.exp(-14*math.min(dt,.1));pointerX+=(nx-pointerX)*response;pointerY+=(ny-pointerY)*response
  blend=quiet and target or blend+(target-blend)*(1-math.exp(-18*math.min(dt,.1)))
  local bob=not quiet and math.sin(clock*2.5+index*1.4)*3 or 0
  local lift=bob+(full and not quiet and blend*7 or 0)-(pressed and 2 or 0)
  effect.Position=UDim2.new(0,12,effectY,-lift);terms.Position=UDim2.new(0,12,termsY,-lift)
  effect.Visible=progress>=.79;terms.Visible=effect.Visible
  local bleed=full and 12 or 0
  local x,y=(left+right)/2,(top+bottom)/2
  local origin=options.origin or Vector2.new(x+(2-index)*size.X*.38,y+size.Y*.52)
  local travel=1-reveal
  local arc=math.sin(progress*math.pi)*math.min(46,size.Y*.14)
  local depth=1
  local center=onPlane(camera,x+(origin.X-x)*travel,y+(origin.Y-y)*travel-arc-lift,depth+.015)
  local scale=.34+.66*reveal
  local w=(onPlane(camera,right+bleed,y,depth)-onPlane(camera,left-bleed,y,depth)).Magnitude*scale
  local h=(onPlane(camera,x,top-bleed,depth)-onPlane(camera,x,bottom+bleed,depth)).Magnitude*scale
  local tilt=full and not quiet and math.rad((index-2)*1.5+pointerX*blend*9+(index==1 and -1 or 1)*64*travel) or 0
  local pitch=full and not quiet and math.rad(-pointerY*blend*5-23*travel) or 0
  local roll=not quiet and math.rad((index-2)*20*travel) or 0
  part.Size=Vector3.new(math.max(.01,w),math.max(.01,h),.02)
  part.CFrame=CFrame.new(center)*camera.CFrame.Rotation*CFrame.Angles(pitch,math.pi+tilt,roll)
  part.Transparency=1;surface.Enabled=true;local canvasSize=Vector2.new(math.floor((right-left+bleed*2)*FACE_PIXELS+.5),math.floor((bottom-top+bleed*2)*FACE_PIXELS+.5));if surface.CanvasSize~=canvasSize then surface.CanvasSize=canvasSize end
  canvas.Size=UDim2.fromOffset(size.X*FACE_PIXELS,size.Y*FACE_PIXELS);canvas.Position=UDim2.fromOffset((position.X-left+bleed)*FACE_PIXELS,(position.Y-top+bleed)*FACE_PIXELS)
  canvas.BackgroundColor3=pressed and bodyColor:Lerp(p.ink,.18) or bodyColor:Lerp(accentColor,blend*.12)
  rimFace.BackgroundColor3=Color3.new(1,1,1)
  inner.BackgroundColor3=pressed and Color3.fromRGB(190,190,190) or Color3.new(1,1,1)
  rimLight.Offset=Vector2.new(quiet and 0 or pointerX*.15,quiet and 0 or pointerY*.2)
  rays.Rotation=quiet and 0 or (clock*9+index*27)%360
  rays.ImageTransparency=quiet and .4 or .4-blend*.1
  local pulse=clock-focusAt;local opening=age*revealSpeed
  local shine=opening<.9 and opening/.9 or (pulse<.7 and pulse/.7 or 2)
  sweep.Visible=not quiet and full and shine>=0 and shine<=1
  if sweep.Visible then sweep.Position=UDim2.fromScale(-.65+shine*2.1,-.25) end
  spot.GroupTransparency=quiet and 1 or 1-blend*.7
  spot.Position=UDim2.fromScale(.5+pointerX*.32,.3+pointerY*.22)
  local wink=not quiet and full and pulse>=0 and pulse<.65
  flash.ImageTransparency=wink and (.15+.85*math.abs(pulse/.65-.5)*2) or 1
  flash.Position=UDim2.fromScale(pointerX<0 and .08 or .92,pointerY<0 and .08 or .92)
  artCamera.CFrame=CFrame.lookAt(Vector3.new(4+(quiet and 0 or pointerX*blend*.7),3+(quiet and 0 or -pointerY*blend*.35),7),Vector3.zero)
  effect.Text=choose.Text~='' and escape(choose.Text) or display
 end)
 return {root=card,button=choose}
end
return CardView

end)()
local PackView = (function()
-- Each observer animates the same delivery from server timestamps.
local RS=game:GetService('ReplicatedStorage')
local UIS=game:GetService('UserInputService')
local TweenService=game:GetService('TweenService')
local PackView={}
PackView.__index=PackView
local colors={
 Color3.fromRGB(121,211,248),
 Color3.fromRGB(255,213,82),
 Color3.fromRGB(86,255,141),
 Color3.fromRGB(185,110,255),
}
local idle=Color3.fromRGB(75,209,220)
local function block(parent,name,size,color,material)
 local part=Instance.new('Part')
 part.Name=name;part.Size=size;part.Color=color;part.Material=material
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Parent=parent
 return part
end

local function createCrate(parent)
 local model=Instance.new('Model');model.Name='LocalCompanyCrate'
 local shell=Color3.fromRGB(32,119,133)
 local body=block(model,'Shell',Vector3.new(1.88,1.12,1.58),shell,Enum.Material.Metal)
 local lid=block(model,'Lid',Vector3.new(1.94,.24,1.65),Color3.fromRGB(255,193,76),Enum.Material.Metal)
 body.Material=Enum.Material.CorrodedMetal;body.MaterialVariant='QuarryDrone_Ribbed'
 lid.Material=Enum.Material.Slate;lid.MaterialVariant='QuarryDrone_Painted'
 local seam=block(model,'Seal',Vector3.new(1.92,.055,1.62),idle,Enum.Material.Neon)
 local light=Instance.new('PointLight');light.Range=7;light.Color=idle;light.Parent=seam
 local sparks=Instance.new('ParticleEmitter')
 sparks.Name='SealSparks';sparks.Texture='rbxasset://textures/particles/sparkles_main.dds'
 sparks.Color=ColorSequence.new(idle);sparks.LightEmission=.85
 sparks.Lifetime=NumberRange.new(.3,.65);sparks.Speed=NumberRange.new(.8,2.4)
 sparks.Rate=5;sparks.SpreadAngle=Vector2.new(55,55);sparks.Drag=2
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.16),NumberSequenceKeypoint.new(1,0)})
 sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,1)})
 sparks.Parent=seam;model.PrimaryPart=body;model.Parent=parent
 return {model=model,body=body,lid=lid,seam=seam,light=light,sparks=sparks}
end

local function createDrone(parent,droneConfig)
 local template=workspace:FindFirstChild('Drone') or RS:FindFirstChild('Drone')
 if not template or not template:IsA('Model') then return nil end
 local drone=template:Clone()
 drone.Name='CompanyCourier'
 for _,item in ipairs(drone:GetDescendants()) do
  if item:IsA('LuaSourceContainer') or item:IsA('BillboardGui') or item:IsA('SurfaceGui')
   or item:IsA('Decal') or item:IsA('Texture') or item:IsA('Highlight') or item:IsA('Sound') then item:Destroy()
  elseif item:IsA('BasePart') then
   item.Anchored=true;item.CanCollide=false;item.CanTouch=false;item.CanQuery=false
   item.Material=Enum.Material.Metal;item.Color=Color3.fromRGB(116,123,133)
   if item:IsA('MeshPart') then item.TextureID='' end
  elseif item:IsA('SpecialMesh') then item.TextureId=''
  elseif item:IsA('Beam') or item:IsA('Trail') or item:IsA('ParticleEmitter') or item:IsA('Light') then item.Enabled=false end
 end
 drone:ScaleTo(drone:GetScale()*.69)
 if droneConfig then droneConfig.decorate(drone,'Courier',Color3.fromRGB(151,164,169)) end
 drone.Parent=parent
 return drone
end

function PackView.new(options)
 local self=setmetatable({options=options,records={}},PackView)
 local focus=Instance.new('DepthOfFieldEffect')
 focus.Name='PackWorldBlur';focus.FocusDistance=1.2;focus.InFocusRadius=.65
 focus.FarIntensity=0;focus.NearIntensity=0;focus.Parent=game:GetService('Lighting')
 self.focus=focus
 self.connections={UIS.WindowFocusReleased:Connect(function()
  for _,record in pairs(self.records) do if record.prompt then record.prompt:InputHoldEnd() end end
 end)}
 self.suppressed={}
 return self
end

function PackView:setFocus(active)
 if self.focusActive==active then return end
 self.focusActive=active
 if self.focusTween then self.focusTween:Cancel() end
 self.focusTween=TweenService:Create(self.focus,TweenInfo.new(.22),{FarIntensity=active and .95 or 0})
 self.focusTween:Play()
end

-- Keep Roblox's input/hold events; only the progress presentation is custom.
function PackView:bindPrompt(record,source)
 local prompt=source:FindFirstChild('OpenPack')
 if not prompt then return end
 record.prompt=prompt
 if source:GetAttribute('Owner')~=self.options.player.UserId then return end
 local gui=Instance.new('BillboardGui')
 gui.Name='PackOpeningPrompt';gui.Adornee=source;gui.Size=UDim2.fromOffset(220,62)
 gui.StudsOffsetWorldSpace=Vector3.new(0,2.3,0);gui.AlwaysOnTop=true;gui.Active=true;gui.Enabled=false
 local button=Instance.new('TextButton')
 button.Name='Hold';button.Size=UDim2.fromScale(1,1);button.BackgroundColor3=Color3.fromRGB(27,32,41)
 button.BackgroundTransparency=.12;button.BorderSizePixel=0;button.Text='';button.AutoButtonColor=false;button.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=button
 local label=Instance.new('TextLabel')
 label.Name='Action';label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(12,8)
 label.Size=UDim2.new(1,-24,0,28);label.Font=Enum.Font.GothamMedium;label.TextSize=17
 label.TextColor3=Color3.fromRGB(239,243,249);label.Text='[E]  Open pack';label.Parent=button
 local track=Instance.new('Frame');track.Name='Track';track.BorderSizePixel=0
 track.BackgroundColor3=Color3.fromRGB(69,77,90);track.Position=UDim2.fromOffset(12,44)
 track.Size=UDim2.new(1,-24,0,6);track.ClipsDescendants=true;track.Parent=button
 local fill=Instance.new('Frame');fill.Name='Progress';fill.BorderSizePixel=0
 fill.BackgroundColor3=idle;fill.Size=UDim2.fromScale(0,1);fill.Parent=track
 gui.Parent=self.options.player:WaitForChild('PlayerGui')
 record.indicator=gui;record.fill=fill
 local function finishPointer(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
 end
 record.connections={
  prompt.PromptShown:Connect(function(inputType)
   record.shown=true
   label.Text=inputType==Enum.ProximityPromptInputType.Touch and 'Hold to open pack'
    or inputType==Enum.ProximityPromptInputType.Gamepad and '[X]  Open pack' or '[E]  Open pack'
  end),
  prompt.PromptHidden:Connect(function() record.shown=false;gui.Enabled=false end),
  prompt.PromptButtonHoldBegan:Connect(function()
   record.holdAt=workspace:GetServerTimeNow();record.releaseAt=nil;record.completed=false
  end),
  prompt.PromptButtonHoldEnded:Connect(function() record.releaseAt=workspace:GetServerTimeNow()+.08 end),
  prompt.Triggered:Connect(function() record.completed=true end),
  button.InputBegan:Connect(function(input)
   if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then prompt:InputHoldBegin() end
  end),
  button.InputEnded:Connect(finishPointer),
  UIS.InputEnded:Connect(finishPointer),
 }
 -- Register visibility handlers before allowing the first PromptShown event.
 prompt.Enabled=false
end

local function disposeRecord(record)
 if record.connections then for _,connection in ipairs(record.connections) do connection:Disconnect() end end
 if record.indicator then record.indicator:Destroy() end
 record.model:Destroy()
 if record.courier then record.courier:Destroy() end
end

function PackView:origin(offerId)
 for part in pairs(self.records) do
  if part:GetAttribute('OfferId')==offerId then return part.Position+Vector3.new(0,.55,0) end
 end
end

function PackView:render(record,source,now,age,tier)
 local o=self.options
 local position=source.Position
 local side=source:GetAttribute('Approach') or Vector3.new(1,0,0)
 local top=position+Vector3.new(0,4.8,0)
 local dronePosition
 if age<Packs.DropTime then
  local q=math.clamp(age/Packs.DropTime,0,1)
  dronePosition=top-side*(19*(1-q)^3)+Vector3.new(0,6*(1-q)^2,0)
 elseif age<Packs.DepartTime then
  local q=(age-Packs.DropTime)/(Packs.DepartTime-Packs.DropTime)
  dronePosition=top+side*(20*q^2)+Vector3.new(0,9*q^2,0)
 end
 if dronePosition and not record.courier and not record.triedCourier then
  record.triedCourier=true;record.courier=createDrone(o.parent,o.droneConfig)
 end
 if record.courier then
  if dronePosition then record.courier:PivotTo(CFrame.lookAt(dronePosition,dronePosition+side))
  else record.courier:Destroy();record.courier=nil end
 end
 local boxPosition=position
 if age<Packs.DropTime then boxPosition=dronePosition-Vector3.new(0,1.25,0)
 elseif age<Packs.DeliveryTime then
  local q=(age-Packs.DropTime)/(Packs.DeliveryTime-Packs.DropTime)
  boxPosition=position+Vector3.new(0,3.55*(1-q*q),0)
 elseif age<Packs.DeliveryTime+.21 then
  local q=(age-Packs.DeliveryTime)/.21
  boxPosition=position+Vector3.new(0,math.sin(q*math.pi)*.16*(1-q),0)
 end
 if not record.landed and age>=Packs.DeliveryTime then
  record.landed=true
  if age<Packs.DeliveryTime+.22 then o.audio:play('pack_land',position);record.sparks:Emit(12) end
 end
 local holdAt=source:GetAttribute('HoldAt')
 local openedAt=source:GetAttribute('OpenedAt')
 local progress,stage=0,0
 if openedAt then progress,stage=1,tier
 elseif holdAt then progress,stage=Packs.sample(tier,now-holdAt) end
 local color=colors[stage] or idle
 if stage~=record.stage then
  record.stage=stage
  record.seam.Color=color;record.light.Color=color;record.sparks.Color=ColorSequence.new(color)
  if stage>0 and not openedAt then
   record.sparks:Emit(7+stage*3)
   o.audio:play('pack_step',position,{pitch=.78+stage*.16})
  end
 end
 local lift=0
 local fade=0
 if openedAt then
  local ageOpen=math.max(0,now-openedAt)
  if not record.opened then
   record.opened=true
   if ageOpen<.25 then
    o.audio:play('pack_open',position,{pitch=.9+tier*.075})
    record.sparks.Speed=NumberRange.new(4,8);record.sparks:Emit(12+tier*6)
   end
  end
  lift=math.clamp(ageOpen/.29,0,1)
  fade=math.clamp((ageOpen-.28)/.72,0,1)
 end
 local pose=CFrame.lookAt(boxPosition,boxPosition+side)
 record.body.CFrame=pose
 record.lid.CFrame=pose*CFrame.new(0,.66+.4*lift,0)*CFrame.Angles(-lift*1.28,0,0)
 record.seam.CFrame=pose*CFrame.new(0,.54,0)
 record.light.Brightness=(.4+progress*1.5)*(1-fade)
 record.sparks.Rate=openedAt and 0 or (stage>0 and 10+stage*5 or 5)
 record.body.Transparency=fade;record.lid.Transparency=fade;record.seam.Transparency=fade
 return progress,color,holdAt,openedAt
end

function PackView:update(now)
 local o=self.options
 local folder=o.world:FindFirstChild('PackDeliveries')
 local player=o.player
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 local camera=workspace.CurrentCamera
 self.target=nil
 if folder and camera then for _,source in ipairs(folder:GetChildren()) do
  local stamp,tier=source:GetAttribute('DeliveryAt'),source:GetAttribute('Tier')
  if stamp and colors[tier] and (camera.CFrame.Position-source.Position).Magnitude<100 then
   local record=self.records[source]
   if not record then record=createCrate(o.parent);self.records[source]=record end
   if not record.prompt then self:bindPrompt(record,source) end
   record.visible=true
   local age=now-stamp
   local _,_,_,openedAt=self:render(record,source,now,age,tier)
   if source:GetAttribute('Owner')==player.UserId and hr and hum and hum.Health>0 and not openedAt
    and age>=Packs.DeliveryTime and (hr.Position-source.Position).Magnitude<=Packs.Range and not o.hidden() then
    self.target=source

   end
  end
 end end
 for source,record in pairs(self.records) do
  if record.prompt then
   local enabled=source==self.target and not o.busy()
   record.prompt.Enabled=enabled
   if record.indicator then
    record.indicator.Enabled=enabled and record.shown==true
    if record.releaseAt and now>=record.releaseAt and not record.completed then record.holdAt=nil end
    if not enabled and not record.completed then record.holdAt=nil end
    local progress,stage=0,0
    if record.completed then progress,stage=1,source:GetAttribute('Tier')
    elseif record.holdAt then progress,stage=Packs.sample(source:GetAttribute('Tier'),now-record.holdAt) end
    record.fill.Size=UDim2.fromScale(progress,1)
    record.fill.BackgroundColor3=colors[stage] or idle
   end
  end
 end
 local map=o.world:FindFirstChild('Map')
 if self.target and map then
  if not self.suppressing then
   for _,prompt in ipairs(map:GetDescendants()) do
    if prompt:IsA('ProximityPrompt') then self.suppressed[prompt]=prompt.Enabled;prompt.Enabled=false end
   end
   self.suppressing=true
  end
 elseif self.suppressing then
  for prompt,enabled in pairs(self.suppressed) do if prompt.Parent then prompt.Enabled=enabled end end
  table.clear(self.suppressed);self.suppressing=false
 end
 for source,record in pairs(self.records) do
  if not record.visible then
   disposeRecord(record)
   self.records[source]=nil
  else record.visible=false end
 end
end

function PackView:destroy()
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 self.focus:Destroy()
 for prompt,enabled in pairs(self.suppressed) do if prompt.Parent then prompt.Enabled=enabled end end
 for _,record in pairs(self.records) do disposeRecord(record) end
 table.clear(self.records)
end
return PackView

end)()
local ShopView = (function()
-- Compact Roblox-style upgrade rows: recognizable icon, stack count, effect and price.
local V={}
local INK=Color3.fromRGB(29,48,74)
local BLUE=Color3.fromRGB(29,132,211)
local WHITE=Color3.fromRGB(255,255,255)
local function rounded(U,parent,pos,size,color,edge)
 local box=U.frame(parent,pos,size,color);U.corner(box,12);U.stroke(box,edge or Color3.fromRGB(170,197,218),2)
 return box
end
local function label(U,parent,pos,size,text,pixels,bold)
 local t=U.text(parent,pos,size,text,pixels,INK,bold)
 t.Font=bold and Enum.Font.FredokaOne or Enum.Font.SourceSansSemibold
 return t
end
local function action(U,parent,pos,size,text,callback,enabled,color)
 local b=U.button(parent,pos,size,text,callback,color or Color3.fromRGB(124,227,69))
 U.unskin(b);U.corner(b,10);U.stroke(b,Color3.fromRGB(48,95,47),2)
 U.setEnabled(b,enabled);b.BackgroundColor3=enabled and (color or Color3.fromRGB(124,227,69)) or Color3.fromRGB(224,232,238)
 b.TextColor3=enabled and Color3.fromRGB(28,66,37) or Color3.fromRGB(94,115,131)
 b.TextStrokeTransparency=1;b.Font=Enum.Font.FredokaOne;b.TextSize=15
 return b
end
local function percent(value) return string.format('%g%%',value*100) end
function V.effect(c)
 local e=c.effects;local parts={}
 if e.battery then table.insert(parts,'+'..e.battery..' battery') end
 if e.plotAuto then table.insert(parts,'Auto retarget') end
 for _,k in ipairs({'mining','startup','capacity','speed','yield','fork'}) do
  if e[k] then
   local names={mining='mining power',startup='startup rate',capacity='backpack',speed='flight speed',yield='ore yield',fork='nearby damage'}
   table.insert(parts,(k=='fork' and '' or '+')..percent(e[k])..' '..names[k])
  end
 end
 return table.concat(parts,' · ')
end
local function nextEffect(row)
 local r=row.next and row.next.preview and row.next.preview[1]
 if not r then return 'Fully stacked' end
 local unit=r.unit or '';if unit~='' and unit~='%' and unit~='×' then unit=' '..unit end
 return string.format('Next: %s %g → %g%s',r.label,r.before,r.after,unit)
end
function V.decorate(U,sheet,title,subtitle,close)
 U.unskin(sheet);sheet.BackgroundColor3=Color3.fromRGB(247,252,255);U.corner(sheet,20);U.stroke(sheet,INK,4)
 title.Font=Enum.Font.FredokaOne;title.Text='Upgrades!';title.TextSize=30
 title.TextColor3=BLUE;title.TextStrokeTransparency=1
 subtitle.TextColor3=INK;subtitle.Font=Enum.Font.SourceSansSemibold;subtitle.TextSize=16
 U.unskin(close);U.corner(close,10);U.stroke(close,Color3.fromRGB(116,34,58),3)
 close.BackgroundColor3=Color3.fromRGB(244,78,113);close.TextColor3=WHITE;close.Font=Enum.Font.FredokaOne;close.TextSize=25;close.TextStrokeTransparency=1
end
function V.render(U,parent,options)
 local p,width=options.profile,options.width;local narrow=width<500
 local rows={};for _,r in ipairs(p.workshop or {}) do rows[r.card.cardId]=r end
 local pending=p.run.pendingOffer;local price=Workshop.price(p);local balance=Shops.balance(p,'Quartz')
 local packHeight=narrow and 166 or 118
 local pack=rounded(U,parent,UDim2.fromOffset(2,2),UDim2.fromOffset(width-4,packHeight),Color3.fromRGB(225,245,255),BLUE);pack.Name='UpgradePack'
 U.icon(pack,'cards',UDim2.fromOffset(12,14),UDim2.fromOffset(narrow and 44 or 62,narrow and 44 or 62),Color3.fromRGB(63,171,243))
 local textX=narrow and 67 or 88
 label(U,pack,UDim2.fromOffset(textX,10),UDim2.fromOffset(width-textX-(narrow and 14 or 164),28),'UPGRADE PACK',narrow and 20 or 23,true)
 label(U,pack,UDim2.fromOffset(textX,40),UDim2.fromOffset(width-textX-(narrow and 14 or 164),38),'Choose 1 of 3 and earn 1–4 Stars.',15,false)
 local buyText=pending and (pending.opened==false and 'Open crate' or 'Choose upgrade') or ('Buy · '..price..' Quartz')
 local buy=action(U,pack,UDim2.fromOffset(narrow and 12 or width-164,narrow and 82 or 22),UDim2.fromOffset(narrow and width-28 or 148,44),buyText,options.onPack,options.canBuy and (pending~=nil or balance>=price))
 buy.Name='BuyWorkshopPack'
 label(U,pack,UDim2.fromOffset(12,narrow and 130 or 82),UDim2.fromOffset(width-28,28),'Rarity guarantees an upgrade of that tier. No extra charge.',narrow and 12 or 14,false)
 local y=packHeight+18
 if options.onStars then
  action(U,parent,UDim2.fromOffset(4,y),UDim2.fromOffset(width-8,42),'Star Shop  ·  '..(p.run.stars or 0)..' Stars',options.onStars,true,Color3.fromRGB(255,221,119))
  y+=53
 end
 label(U,parent,UDim2.fromOffset(4,y),UDim2.fromOffset(width-8,30),'YOUR UPGRADE POOL',18,true);y+=38
 local entries={}
 for _,entry in ipairs(Workshop.CATALOG) do if rows[entry.id] then table.insert(entries,entry) end end
 for _,entry in ipairs(Workshop.CATALOG) do if not rows[entry.id] then table.insert(entries,entry) end end
 for _,entry in ipairs(entries) do
  local row=rows[entry.id];local c=row and row.card;local color=Color3.fromRGB(unpack(entry.color))
  local h=narrow and (entry.tier>=3 and 154 or 134) or 88
  local card=rounded(U,parent,UDim2.fromOffset(2,y),UDim2.fromOffset(width-4,h),c and WHITE or Color3.fromRGB(238,245,250));card.Name='Upgrade_'..entry.id
  local icon=rounded(U,card,UDim2.fromOffset(10,14),UDim2.fromOffset(narrow and 46 or 54,narrow and 46 or 54),color:Lerp(WHITE,.65),color)
  U.icon(icon,entry.icon,UDim2.fromOffset(5,5),UDim2.fromOffset(narrow and 36 or 44,narrow and 36 or 44),color)
  local x=narrow and 67 or 78
  label(U,card,UDim2.fromOffset(x,9),UDim2.fromOffset(width-x-(narrow and 76 or 238),30),entry.title,narrow and 17 or 20,true)
  local count=rounded(U,card,UDim2.fromOffset(width-(narrow and 70 or 222),11),UDim2.fromOffset(54,29),c and color:Lerp(WHITE,.45) or WHITE,c and color or Color3.fromRGB(187,205,218))
  local number=label(U,count,UDim2.fromOffset(2,0),UDim2.new(1,-4,1,0),c and c.level..'×' or 'NEW',c and 20 or 13,true);number.TextXAlignment=Enum.TextXAlignment.Center
  local detail=c and V.effect(c) or V.effect(Workshop.card(entry,1))
  if not c then detail=Workshop.TIERS[entry.tier]..' · '..detail
  elseif entry.tier>=2 then detail=Workshop.TIERS[entry.tier]..' · '..detail end
  if c and not narrow and entry.tier<3 then detail..='\n'..nextEffect(row) end
  label(U,card,UDim2.fromOffset(x,39),UDim2.fromOffset(width-x-(narrow and 14 or 164),narrow and (entry.tier>=3 and 57 or 37) or 40),detail,14,false)
  local pos=UDim2.fromOffset(width-154,narrow and h-52 or 24)
  if c then
   local cost=row.next and ('+1 · '..row.cost..' Quartz') or 'MAX'
   local b=action(U,card,pos,UDim2.fromOffset(140,44),cost,function() options.onBuy(c,c.level) end,options.canBuy and not pending and row.next~=nil and balance>=row.cost)
   b.Name='AddStack_'..entry.id
   if narrow then label(U,card,UDim2.fromOffset(12,h-50),UDim2.fromOffset(width-176,40),row.next and 'Buy another stack' or 'Fully stacked',13,false) end
  else
   local t=label(U,card,pos,UDim2.fromOffset(140,44),'Find in packs',15,true);t.TextColor3=BLUE;t.TextXAlignment=Enum.TextXAlignment.Center
  end
  y+=h+9
 end
 local pre=p.prestigePreview or {};local earned=pre.earnings or 0;local needed=pre.saleRequired or Workshop.PRESTIGE_BASE
 local foot=rounded(U,parent,UDim2.fromOffset(2,y+5),UDim2.fromOffset(width-4,narrow and 128 or 83),Color3.fromRGB(242,233,255),Color3.fromRGB(166,124,213));foot.Name='PrestigeProgress'
 label(U,foot,UDim2.fromOffset(12,9),UDim2.fromOffset(width-(narrow and 28 or 172),25),'NEXT: +1 PERMANENT DRONE',narrow and 15 or 17,true)
 label(U,foot,UDim2.fromOffset(12,36),UDim2.fromOffset(width-(narrow and 28 or 172),25),earned..' / '..needed..' Quartz sold',15,false)
 local bar=rounded(U,foot,UDim2.fromOffset(12,65),UDim2.fromOffset(width-(narrow and 28 or 176),6),WHITE,WHITE)
 local fill=U.frame(bar,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(earned/math.max(1,needed),0,1),1),Color3.fromRGB(154,104,215));U.corner(fill,4)
 action(U,foot,UDim2.fromOffset(narrow and 12 or width-154,narrow and 78 or 20),UDim2.fromOffset(narrow and width-28 or 140,40),pre.eligible and 'Prestige ready!' or 'View reward',options.onPrestige,true,Color3.fromRGB(211,177,255))
end
function V.renderStars(U,parent,options)
 local p,width=options.profile,options.width
 local balance=p.run.stars or 0
 action(U,parent,UDim2.fromOffset(4,3),UDim2.fromOffset(width-8,42),'Back to Quartz Workshop',options.onBack,true,Color3.fromRGB(174,218,255))
 local y=56
 for _,entry in ipairs(Workshop.STAR_CATALOG) do
  local level=Workshop.starLevel(p,entry.id)
  local price=Workshop.starPrice(entry,level)
  local card=rounded(U,parent,UDim2.fromOffset(3,y),UDim2.fromOffset(width-6,102),Color3.fromRGB(255,250,226),Color3.fromRGB(218,186,99))
  label(U,card,UDim2.fromOffset(12,7),UDim2.fromOffset(width-26,24),entry.title,19,true)
  label(U,card,UDim2.fromOffset(12,33),UDim2.fromOffset(width-26,21),entry.description,15,false)
  label(U,card,UDim2.fromOffset(12,57),UDim2.fromOffset(width-146,36),level..' / '..entry.max..' owned',14,true)
  action(U,card,UDim2.fromOffset(width-124,57),UDim2.fromOffset(104,36),level>=entry.max and 'MAX' or price..' Stars',
   function() options.onBuy(entry.id,level) end,options.canBuy and level<entry.max and balance>=price,Color3.fromRGB(255,218,102))
  y+=111
 end
end
return V

end)()
local AbilityView = (function()
-- Compact gadget controls and smooth, all-observer scrap-bot rendering.
-- One activation sends intent. The server owns the charge, release, targets, damage and rewards.
local View={}
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local function enabled(profile,kind)
 return profile and profile.run and Shops.abilityUnlocked(profile,kind) or false
end

function View.start(options)
 local player=Players.LocalPlayer
 local U=options.interface;local root=options.parent
 local panel=U.panel(root,UDim2.fromOffset(16,160),UDim2.fromOffset(220,56),U.palette.panel,12)
 panel.Name='MiningGadgets';panel.Visible=false
 local state: any={cooldowns={}};local connections={};local dead=false;local lastSend=0
 local function connect(signal,fn) table.insert(connections,signal:Connect(fn)) end
 local function decode()
  local raw=player:GetAttribute('MA_Ability')
  if type(raw)=='string' then local ok,value=pcall(function() return Http:JSONDecode(raw) end);if ok and type(value)=='table' then state=value end end
 end
 decode();connect(player:GetAttributeChangedSignal('MA_Ability'),decode)
 local function nearestField(profile)
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  local world=workspace:FindFirstChild('MiningAway');local fields=world and world:FindFirstChild('Fields')
  local best,id=math.huge,nil
  if hr and fields and profile and not player:GetAttribute('MA_InAssault') then for _,field in ipairs(fields:GetChildren()) do
   local phase=field:GetAttribute('Phase')
   local unlocked=field:GetAttribute('AlwaysUnlocked') or Shops.unlocked(profile,field.Name)
   local cleared=phase=='Safe' or phase=='Cleared' or field.Name=='Quartz' or field.Name=='Ruby'
    or (profile.clearedFields and profile.clearedFields[field.Name])
   local floor=unlocked and cleared and (field:FindFirstChild('Field') or field:FindFirstChild('FieldFloor') or field:FindFirstChildWhichIsA('BasePart'))
   if floor then
    local point=floor.CFrame:PointToObjectSpace(hr.Position)
    if math.abs(point.X)<=floor.Size.X*.5+18 and math.abs(point.Z)<=floor.Size.Z*.5+18 and math.abs(point.Y)<=45 then
     local d=point.Magnitude;if d<best then best=d;id=field:GetAttribute('FieldId') or field:GetAttribute('Tier') end
    end
   end
  end end
  return id
 end
 local function activate(kind)
  if options.hidden() or os.clock()-lastSend<.15 then return end
  local profile=options.profile();if not enabled(profile,kind) or profile.pendingTransaction then return end
  local charge=state.runId==profile.run.id and state.charge or nil
  if charge then return end
  local fieldId=nearestField(profile);if not fieldId then return end
  lastSend=os.clock()
  options.command:FireServer('MiningAbility',{op='begin',kind=kind,fieldId=fieldId,runId=profile.run.id})
 end
 local orbital=U.button(panel,UDim2.fromOffset(8,7),UDim2.fromOffset(98,42),'Orbital [G]',function() activate('Orbital') end,Color3.fromRGB(208,47,70))
 orbital.Name='OrbitalGadget';orbital.TextSize=16
 local scrap=U.button(panel,UDim2.fromOffset(114,7),UDim2.fromOffset(98,42),'Scrap [B]',function() activate('Scrap') end,Color3.fromRGB(133,53,211))
 scrap.Name='ScrapGadget';scrap.TextSize=16
 connect(UIS.InputBegan,function(input,processed)
  if processed or UIS:GetFocusedTextBox() then return end
  if input.KeyCode==Enum.KeyCode.G then activate('Orbital') elseif input.KeyCode==Enum.KeyCode.B then activate('Scrap') end
 end)
 -- Server records carry poses only; each observer clones the original art locally.
 local visualRoot=Instance.new('Folder');visualRoot.Name='ScrapBotPresentation';visualRoot.Parent=workspace
 local bots={}
 local function remove(source,record)
  record.view:Destroy();record.beam:Destroy()
  -- The tiny tool retires immediately; its already emitted world-space motes
  -- get their full tail instead of being cut off at swarm expiry.
  record.core:Destroy();bots[source]=nil
 end
 local function observe(source)
  if bots[source] or not source:IsA('Folder') or source:GetAttribute('ScrapBot')~=true then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local reference=source.Parent and source.Parent:FindFirstChild('Template')
  local template=reference and reference.Value
  if not template or not template:IsA('Model') then return end
  local view=template:Clone();view.Name='LocalScrapBot'
  for _,node in ipairs(view:GetDescendants()) do
   if node:IsA('LuaSourceContainer') or node:IsA('BillboardGui') or node:IsA('SurfaceGui') or node:IsA('Sound') then node:Destroy()
   elseif node:IsA('Beam') or node:IsA('Trail') or node:IsA('ParticleEmitter') then node.Enabled=false
   elseif node:IsA('BasePart') then node.Anchored=true;node.CastShadow=false;node.Reflectance=0 end
  end
  view:ScaleTo(view:GetScale()*.18)
  if options.droneConfig then options.droneConfig.decorate(view,'Dart',Color3.fromRGB(179,176,113)) end
  for _,part in ipairs(view:GetDescendants()) do if part:IsA('BasePart') then part.LocalTransparencyModifier=0;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end end
  view.Parent=visualRoot;view:PivotTo(CFrame.new(position))
  local function beam(width,color)
   local part=Instance.new('Part');part.Name='TinyScrapChisel';part.Shape=Enum.PartType.Cylinder
   part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
   part.Material=Enum.Material.CorrodedMetal;part.MaterialVariant='QuarryDrone_Ribbed'
   part.Color=color;part.Transparency=1;part.Size=Vector3.new(.01,width,width);part.Parent=visualRoot;return part
  end
  local chisel=beam(.05,Color3.fromRGB(185,174,126))
  bots[source]={view=view,pos=position,beam=beam(.16,Color3.fromRGB(99,111,103)),core=chisel,alpha=0,yaw=0,samples={}}
 end
 local function scan()
  local folder=workspace:FindFirstChild('DroneRoleState')
  if folder then for _,group in ipairs(folder:GetChildren()) do if group:GetAttribute('ScrapSwarm') then for _,source in ipairs(group:GetChildren()) do observe(source) end end end end
 end
 local scanAt=0;local nearby=false
 connect(RunService.RenderStepped,function(dt)
  if dead then return end
  local now=workspace:GetServerTimeNow();local profile=options.profile()
  local hasOrbital,hasScrap=enabled(profile,'Orbital'),enabled(profile,'Scrap')
  panel.Visible=(hasOrbital or hasScrap) and nearby and not options.hidden()
  local short=root.AbsoluteSize.Y<390
  local compact=short and root.AbsoluteSize.X>=568
  local panelWidth=compact and 180 or 220
  panel.Position=UDim2.fromOffset(math.min(12,math.max(0,root.AbsoluteSize.X-panelWidth)),short and 64 or 160)
  orbital.Size=UDim2.fromOffset(compact and 78 or 98,42)
  scrap.Position=UDim2.fromOffset(compact and 94 or 114,7);scrap.Size=orbital.Size
  local charge=profile and state.runId==profile.run.id and state.charge or nil
  panel.Size=UDim2.fromOffset(panelWidth,56)
  local function paint(button,kind,unlocked,key)
   button.Visible=unlocked
   local remaining=math.max(0,math.ceil(((state.cooldowns or {})[kind] or 0)-now))
   local charging=charge and charge.kind==kind
   local busy=profile and profile.pendingTransaction
   U.setEnabled(button,unlocked and not busy and remaining==0 and not charge)
   button.Text=busy and 'Saving…' or charging and (kind..'…') or remaining>0 and (kind..' '..remaining..'s') or (kind..(UIS.TouchEnabled and '' or ' ['..key..']'))
  end
  paint(orbital,'Orbital',hasOrbital,'G');paint(scrap,'Scrap',hasScrap,'B')
  if now>=scanAt then scanAt=now+.2;nearby=(hasOrbital or hasScrap) and nearestField(profile)~=nil;scan() end
  for source,record in pairs(bots) do
   if not source.Parent or not source.Parent.Parent or now>=(source.Parent:GetAttribute('Expires') or 0) then remove(source,record)
   else
    local position=source:GetAttribute('Position') or record.pos
    local target=source:GetAttribute('TargetPosition') or position
    MotionBuffer.push(record.samples,source:GetAttribute('PoseAt'),CFrame.new(position))
    local pose=MotionBuffer.pose(record.samples,now)
    local nextPosition=pose and pose.Position or position
    local delta=nextPosition-record.pos
    record.pos=nextPosition
    if delta.X*delta.X+delta.Z*delta.Z>.001 then
     local yaw=math.atan2(-delta.X,-delta.Z);local diff=(yaw-record.yaw+math.pi)%(2*math.pi)-math.pi
     record.yaw+=diff*(1-math.exp(-math.min(dt,.1)*8))
    end
    record.view:PivotTo(CFrame.new(record.pos)*CFrame.Angles(0,record.yaw,0))
    local active=source:GetAttribute('Active')==true
    record.alpha+=( (active and 1 or 0)-record.alpha)*(1-math.exp(-math.min(dt,.1)*22))
    -- Solid miniature chisels tap on confirmed damage pulses; these bots do
    -- close mechanical work rather than projecting the miner's laser again.
    local serial=source:GetAttribute('Pulse') or 0
    if serial~=(record.serial or serial) then record.hitAt=now end
    record.serial=serial
    local tap=math.max(0,1-(now-(record.hitAt or -100))/.18)
    local height=math.min(1.3,math.max(.1,record.pos.Y-target.Y))
    local base=Vector3.new(record.pos.X,record.pos.Y-.18-tap*.14,record.pos.Z)
    local pose=CFrame.new(base-Vector3.new(0,height*.5,0))*CFrame.Angles(0,0,math.pi/2)
    record.beam.Size=Vector3.new(height,.065,.065);record.beam.CFrame=pose
    record.beam.Color=Color3.fromRGB(99,111,103);record.beam.Transparency=1-record.alpha
    record.core.Size=Vector3.new(.16,.22,.22);record.core.CFrame=CFrame.new(base-Vector3.new(0,height-.08,0))*CFrame.Angles(0,0,math.pi/2)
    record.core.Color=Color3.fromRGB(185,174,126);record.core.Transparency=1-record.alpha
    if active then record.view:PivotTo(CFrame.new(record.pos+Vector3.new(0,-tap*.08,0))*CFrame.Angles(0,record.yaw,0)) end
   end
  end
 end)
 return {destroy=function()
  if dead then return end;dead=true
  for _,connection in ipairs(connections) do connection:Disconnect() end
  for source,record in pairs(bots) do remove(source,record) end
  panel:Destroy();visualRoot:Destroy()
 end}
end
return View

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
local ToolArt = (function()
-- Small original tool silhouettes reused in-world, in hand and in hotbar icons.
local A={}
function A.create(kind,parent,projectile)
 local def=ToolRules.ITEMS[kind];local model=Instance.new('Model');model.Name=kind
 local function part(name,size,offset,color,shape)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=offset;p.Color=color
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Material=Enum.Material.Metal;if shape then p.Shape=shape end;p.Parent=model;return p
 end
 local color=Color3.fromRGB(table.unpack(def.color));local dark=Color3.fromRGB(24,27,38)
 if kind=='BowlingBall' then
  model.PrimaryPart=part('Ball',Vector3.one*2.1,CFrame.new(),color,Enum.PartType.Ball)
  for _,v in ipairs({Vector3.new(-.24,.73,-.69),Vector3.new(.24,.73,-.69),Vector3.new(0,.36,-.96)}) do
   part('FingerHole',Vector3.new(.23,.23,.14),CFrame.lookAt(v,v*2),dark,Enum.PartType.Ball)
  end
 elseif kind=='Greatsword' then
  model.PrimaryPart=part('Grip',Vector3.new(.29,.95,.29),CFrame.new(),dark)
  part('Guard',Vector3.new(1.6,.22,.42),CFrame.new(0,.55,0),Color3.fromRGB(244,188,86))
  local blade=part('Blade',Vector3.new(1.04,4.15,.22),CFrame.new(0,2.69,0),color)
  blade.Material=Enum.Material.Metal
  part('Edge',Vector3.new(.16,4.05,.25),CFrame.new(-.48,2.65,0),Color3.fromRGB(235,250,255))
  part('Point',Vector3.new(.72,.72,.22),CFrame.new(0,4.74,0)*CFrame.Angles(0,0,math.pi/4),color)
 elseif kind=='Sledgehammer' then
  model.PrimaryPart=part('Handle',Vector3.new(.24,3,.24),CFrame.new(),dark)
  part('Head',Vector3.new(1.95,.86,.9),CFrame.new(0,1.55,0),color)
  part('Strike Face',Vector3.new(.25,.91,.98),CFrame.new(.96,1.55,0),Color3.fromRGB(212,224,232))
 elseif kind=='MoltenTongs' then
  if projectile then
   model.PrimaryPart=part('MoltenSteel',Vector3.one*1.24,CFrame.new(),color,Enum.PartType.Ball)
   model.PrimaryPart.Material=Enum.Material.Neon
  else
   model.PrimaryPart=part('TongsPivot',Vector3.new(.44,.32,.38),CFrame.new(),dark)
   for _,side in ipairs({-1,1}) do
    part('Handle',Vector3.new(.14,2.2,.18),CFrame.new(side*.33,-.52,0)*CFrame.Angles(0,0,side*.2),dark)
    for i=0,6 do
     local a=math.pi*i/6+ (side==1 and -math.pi*.5 or math.pi*.5)
     part('CircularJaw',Vector3.new(.16,.34,.24),CFrame.new(math.cos(a)*.68,1.15+math.sin(a)*.68,0)*CFrame.Angles(0,0,a),Color3.fromRGB(150,161,175))
    end
   end
   local ball=part('MoltenSteel',Vector3.one*1.21,CFrame.new(0,1.15,0),color,Enum.PartType.Ball);ball.Material=Enum.Material.Neon
  end
 elseif kind=='Scrap' or kind=='Orbital' then
  model.PrimaryPart=part('Capsule',Vector3.new(1.18,.78,1.18),CFrame.new(),dark)
  local signal=part('Charge',Vector3.new(.78,.68,.78),CFrame.new(0,.39,0),color,Enum.PartType.Ball);signal.Material=Enum.Material.Neon
  if kind=='Orbital' then part('Beacon',Vector3.new(.14,.86,.14),CFrame.new(0,.86,0),color) end
 elseif kind=='Crowbar' then
  model.PrimaryPart=part('Shaft',Vector3.new(.23,2,.27),CFrame.new(),color)
  part('Grip',Vector3.new(.3,.85,.32),CFrame.new(0,-.5,0),dark)
  part('Hook',Vector3.new(.24,.6,.27),CFrame.new(.17,1.12,0)*CFrame.Angles(0,0,-.7),color)
  part('Claw',Vector3.new(.5,.16,.28),CFrame.new(.49,1.27,0),Color3.fromRGB(204,211,218))
 else
  model.PrimaryPart=part('Jelly',Vector3.one,CFrame.new(),color,Enum.PartType.Ball)
  model.PrimaryPart.Material=Enum.Material.SmoothPlastic;model.PrimaryPart.Transparency=.16
  part('Cap',Vector3.new(.42,.23,.42),CFrame.new(0,.5,0),dark)
  part('Fuse',Vector3.new(.09,.4,.09),CFrame.new(.12,.75,0)*CFrame.Angles(0,0,-.3),Color3.fromRGB(255,225,116))
 end
 model.Parent=parent;return model
end
function A.bar(part,hp,maxHP)
 local gui=Instance.new('BillboardGui');gui.Name='ToolDurability';gui.Adornee=part;gui.Size=UDim2.fromOffset(56,6)
 gui.StudsOffset=Vector3.new(0,1.7,0);gui.AlwaysOnTop=false;gui.MaxDistance=55;gui.Parent=part
 local track=Instance.new('Frame');track.Size=UDim2.fromScale(1,1);track.BackgroundColor3=Color3.fromRGB(28,29,38);track.BorderSizePixel=0;track.Parent=gui
 local fill=Instance.new('Frame');fill.Name='Remaining';fill.Size=UDim2.fromScale(hp/maxHP,1)
 fill.BackgroundColor3=Color3.fromRGB(156,231,102);fill.BorderSizePixel=0;fill.Parent=track
 return fill
end
-- Each pose gives the right shoulder pitch/yaw/roll, elbow pitch, wrist
-- pitch, and left shoulder pitch/roll. The model stays on the palm.
local function pose(x,y,z,elbow,wrist,left,spread)
 return {Vector3.new(x,y,z),Vector3.new(elbow,0,0),Vector3.new(wrist,0,0),Vector3.new(left or 0,0,spread or -8)}
end
local motions={
 BowlingBall={grip=Vector3.new(0,.61,-.75),tilt=-38,
  idle=pose(30,5,17,40,-10,21,12), load=pose(-34,-24,33,52,12,24,-16), strike=pose(86,6,9,12,-19,8,-20), recovery=.38},
 Crowbar={grip=Vector3.new(0,-.54,0),tilt=-83,
  idle=pose(24,2,13,32,0), load=pose(88,-38,36,67,-22,18,-17), strike=pose(66,28,-9,13,21,9,-14), recovery=.24},
 JellyGrenade={grip=Vector3.new(0,.03,-.44),tilt=-35,
  idle=pose(27,2,14,46,0), load=pose(97,-25,34,70,-26,13,-15), strike=pose(91,7,9,10,19,6,-16), recovery=.30},
 Greatsword={grip=Vector3.new(0,-.05,0),tilt=-91,
  idle=pose(28,12,19,39,-13,23,12), load=pose(70,-54,45,58,-19,48,10), strike=pose(77,43,-12,14,21,50,19), recovery=.37},
 Sledgehammer={grip=Vector3.new(0,-1.02,0),tilt=-89,
  idle=pose(27,10,18,40,-7,24,10), load=pose(111,-14,30,64,-11,94,15), strike=pose(42,9,9,8,-76,38,18), recovery=.36},
 MoltenTongs={grip=Vector3.new(.20,-1.14,0),tilt=-98,
  idle=pose(39,4,14,30,-8), load=pose(67,-12,21,42,-11,26,8), strike=pose(81,8,12,7,27,21,-5), recovery=.32},
 Scrap={grip=Vector3.new(0,-.22,-.45),tilt=-60,
  idle=pose(31,6,15,38,-4), load=pose(54,-12,23,60,-8), strike=pose(74,3,9,11,18), recovery=.28},
 Orbital={grip=Vector3.new(0,-.22,-.45),tilt=-64,
  idle=pose(36,7,14,38,-2), load=pose(69,-13,19,53,-16), strike=pose(81,4,8,10,17), recovery=.28},
}
local function smooth(x)
 x=math.clamp(x,0,1)
 return x*x*(3-2*x)
end
local function angles(v)
 return CFrame.Angles(math.rad(v.X),math.rad(v.Y),math.rad(v.Z))
end
function A.armRig(character)
 local joints={}
 local names={RightShoulder=1,RightElbow=2,RightWrist=3,LeftShoulder=4,['Right Shoulder']=1,['Left Shoulder']=4}
 for _,joint in ipairs(character:GetDescendants()) do
  local index=names[joint.Name]
  if index and (joint:IsA('Motor6D') or joint:IsA('AnimationConstraint')) and joint.Part0 then joints[index]=joint end
 end
 return joints
end
function A.poseArms(rig,kind,action,elapsed,heading,weight,applied)
 local motion=motions[kind]
 if not motion then return end
 local from,to,blend=motion.idle,motion.idle,0
 if action and elapsed<0 then
  local windup=ToolRules.ITEMS[kind].windup
  local progress=1+elapsed/windup
  local loadEnd=ToolRules.ITEMS[kind].melee and .70 or .77
  if progress<loadEnd then from,to,blend=motion.idle,motion.load,smooth(progress/loadEnd)
  else from,to,blend=motion.load,motion.strike,smooth((progress-loadEnd)/(1-loadEnd)) end
 elseif action then from,to,blend=motion.strike,motion.idle,smooth(elapsed/motion.recovery) end
 for i,joint in pairs(rig) do
  if not joint.Parent or not joint.Part0 then continue end
  local rotation=from[i]:Lerp(to[i],blend)
  if i==1 then
   rotation+=Vector3.new(rig[2] and 0 or from[2]:Lerp(to[2],blend).X*.42,heading,0)
  elseif i==4 then rotation+=Vector3.new(0,heading*.52,0) end
  local basis=joint.C0.Rotation
  local base=joint.Transform
  joint.Transform=base:Lerp(basis:Inverse()*angles(rotation)*basis,weight)
  applied[joint]=base
 end
end
function A.recovery(kind) return motions[kind] and motions[kind].recovery or 0 end
function A.grip(kind,hand)
 local motion=motions[kind]
 local attachment=hand:FindFirstChild('RightGripAttachment')
 local palm=CFrame.new(attachment and attachment.Position or Vector3.new(0,-hand.Size.Y*.40,0))
 return hand.CFrame*palm*CFrame.Angles(math.rad(motion.tilt),0,0)*CFrame.new(-motion.grip)
end
return A

end)()
local ToolView = (function()
-- Custom equipment hotbar, held tools and impact cues.
local V={};V.__index=V
function V.new(ctx)
 local UIS=game:GetService('UserInputService');local Http=game:GetService('HttpService')
 local players=game:GetService('Players');local player=players.LocalPlayer;local U=ctx.interface
 local self=setmetatable({ctx=ctx,player=player,players=players,uis=UIS,slots={},world={},held={},rigs={},posed={},connections={},state={slots={},selected=0}},V)
 local gui=Instance.new('Frame');gui.Name='TemporaryToolHotbar';gui.AnchorPoint=Vector2.new(.5,1);gui.BackgroundTransparency=1;gui.Active=true;gui.ZIndex=ctx.parent.ZIndex+2;gui.Parent=ctx.parent;self.gui=gui
 self.hint=U.text(gui,UDim2.fromOffset(0,-23),UDim2.new(1,0,0,20),'',13,U.palette.white,true);self.hint.TextXAlignment=Enum.TextXAlignment.Center
 for i=1,ToolRules.SLOTS do
  local b=U.button(gui,UDim2.fromOffset(0,0),UDim2.fromOffset(78,82),'',function() self:equip(i) end,U.palette.panel)
  b.Name='ToolSlot'..i
  local icon=Instance.new('ViewportFrame');icon.Name='ToolIcon';icon.BackgroundTransparency=1;icon.Size=UDim2.new(1,-8,0,46);icon.Position=UDim2.fromOffset(4,2);icon.Ambient=Color3.fromRGB(205,205,220);icon.LightColor=Color3.new(1,1,1);icon.ZIndex=b.ZIndex+2;icon.Parent=b
  local camera=Instance.new('Camera');camera.CFrame=CFrame.lookAt(Vector3.new(3,2.5,5),Vector3.zero);camera.FieldOfView=34;camera.Parent=icon;icon.CurrentCamera=camera
  local name=U.text(b,UDim2.fromOffset(3,47),UDim2.new(1,-6,0,17),'',12,U.palette.white,true);name.TextXAlignment=Enum.TextXAlignment.Center
  local count=U.text(b,UDim2.fromOffset(4,3),UDim2.fromOffset(20,16),tostring(i),12,U.palette.white,true)
  local bar=Instance.new('Frame');bar.Name='DurabilityTrack';bar.BorderSizePixel=0;bar.BackgroundColor3=Color3.fromRGB(28,29,38);bar.Size=UDim2.new(1,-12,0,5);bar.Position=UDim2.new(0,6,1,-11);bar.ZIndex=b.ZIndex+2;bar.Parent=b
  local fill=bar:Clone();fill.Name='Durability';fill.Size=UDim2.fromScale(1,1);fill.Position=UDim2.fromOffset(0,0);fill.BackgroundColor3=Color3.fromRGB(156,231,102);fill.Parent=bar
  self.slots[i]={button=b,icon=icon,name=name,fill=fill,key=count}
 end
 self.use=U.button(ctx.parent,UDim2.new(.5,-54,1,-180),UDim2.fromOffset(108,40),'Throw',function() self:activate() end,U.palette.accent);self.use.Name='UseTemporaryTool';self.use.Visible=false
 local function read()
  local ok,state=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_FieldTools') or '')
  self.state=ok and type(state)=='table' and state or {slots={},selected=0}
  for i,slot in ipairs(self.slots) do
   local item=self.state.slots[i];local kind=item and item.kind
   if kind~=slot.kind then
    if slot.model then slot.model:Destroy();slot.model=nil end
    if kind and ToolRules.ITEMS[kind] then slot.model=ToolArt.create(kind,slot.icon)
     local center,extent=slot.model:GetBoundingBox()
     local target=center.Position;local distance=math.max(5,extent.Magnitude*1.8)
     slot.icon.CurrentCamera.CFrame=CFrame.lookAt(target+Vector3.new(.44,.26,1).Unit*distance,target)
    end
    slot.kind=kind
   end
  end
 end
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_FieldTools'):Connect(read));read()
 local starter=game:GetService('StarterGui');local ok,enabled=pcall(function() return starter:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
 self.oldBackpack=ok and enabled
 pcall(function() starter:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end)
 local function add(part)
  if not part:IsA('BasePart') or self.world[part] or not ToolRules.ITEMS[part:GetAttribute('Kind')] then return end
  local kind=part:GetAttribute('Kind');local model=ToolArt.create(kind,ctx.localFX,part:GetAttribute('State')=='Flying')
  model:PivotTo(part.CFrame);part.LocalTransparencyModifier=1
  self.world[part]={model=model,fill=ToolArt.bar(model.PrimaryPart,part:GetAttribute('HP') or 1,part:GetAttribute('MaxHP') or 1),kind=kind}
 end
 local folder=ctx.world:WaitForChild('FieldTools');for _,p in ipairs(folder:GetChildren()) do add(p) end
 table.insert(self.connections,folder.ChildAdded:Connect(add))
 local effects=ctx.world:WaitForChild('ToolImpacts')
 table.insert(self.connections,effects.ChildAdded:Connect(function(p) self:impact(p) end))
 local run=game:GetService('RunService')
 table.insert(self.connections,run.PreAnimation:Connect(function() self:resetArms() end))
 table.insert(self.connections,run.PreSimulation:Connect(function(dt) self:poseArms(dt,workspace:GetServerTimeNow()) end))
 return self
end
function V:selected() return self.state.slots[self.state.selected or 0] end
function V:equip(slot)
 if self.ctx.hidden() or not self.state.runId then return end
 local item=self.state.slots[slot];if not item or item.state~='Held' then return end
 self.ctx.onSelect()
 self.ctx.command:FireServer('EquipFieldTool',{runId=self.state.runId,version=self.state.version,slot=self.state.selected==slot and 0 or slot})
end
function V:unequip()
 if (self.state.selected or 0)>0 then self.ctx.command:FireServer('EquipFieldTool',{runId=self.state.runId,version=self.state.version,slot=0}) end
end
function V:input(input,processed)
 if processed or self.uis:GetFocusedTextBox() or self.ctx.hidden() then return false end
 local key=input.KeyCode
 local keys={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8}
 if keys[key] then self:equip(keys[key]);return true end
 if key==Enum.KeyCode.Backspace or key==Enum.KeyCode.Escape or key==Enum.KeyCode.ButtonB then if self:selected() then self:unequip();return true end end
 if key==Enum.KeyCode.ButtonL1 then
  for n=1,ToolRules.SLOTS do local i=((self.state.selected or 0)+n-1)%ToolRules.SLOTS+1;local item=self.state.slots[i];if item and item.state=='Held' then self:equip(i);break end end;return true
 end
 if self:selected() and (key==Enum.KeyCode.ButtonR2 or input.UserInputType==Enum.UserInputType.MouseButton1) then self:activate();return true end
 return false
end
function V:contact(screen,range)
 local camera=workspace.CurrentCamera;local hr=self.player.Character and self.player.Character:FindFirstChild('HumanoidRootPart')
 if not camera or not hr then return end
 local pointer=screen or self.uis:GetMouseLocation()
 local last=self.uis:GetLastInputType();local center=not screen and (last==Enum.UserInputType.Touch or last==Enum.UserInputType.Gamepad1 or not self.uis.MouseEnabled)
 local ray=center and camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2) or camera:ScreenPointToRay(pointer.X,pointer.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={self.ctx.localFX,self.player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*180,params)
 if hit then return hit.Position,hit.Instance end
 local origin=hr.Position+Vector3.yAxis*1.3
 local distance=math.max(0,(origin-ray.Origin):Dot(ray.Direction))+range
 return ray.Origin+ray.Direction*distance
end
function V:activate(screen)
 local item=self:selected();if not item or item.state~='Held' or self.ctx.hidden() then return end
 if not screen and self.uis:GetLastInputType()==Enum.UserInputType.MouseButton1 and self.ctx.blocks(self.uis:GetMouseLocation()) then return end
 local point,target=self:contact(screen,ToolRules.ITEMS[item.kind].range);if not point then return end
 local id=target and target:GetAttribute('ResourceId')
 self.ctx.command:FireServer('UseFieldTool',{runId=self.state.runId,version=self.state.version,id=item.id,point=point,resourceId=id})
end
function V:click(screen) if not self:selected() then return false end;self:activate(screen);return true end
function V:blocks(point)
 if not self.gui.Visible then return false end
 local p,s=self.gui.AbsolutePosition,self.gui.AbsoluteSize
 return point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y
end
function V:impact(source)
 local now=workspace:GetServerTimeNow();local at=source:GetAttribute('StartedAt') or 0
 if now-at>.3 then return end
 local kind=source:GetAttribute('Kind');if type(kind)~='string' then return end
 local position=source.Position
 local camera=workspace.CurrentCamera;if not camera or (camera.CFrame.Position-position).Magnitude>120 then return end
 local color=source:GetAttribute('Color') or Color3.fromRGB(160,150,135)
 local cue=({ScrapWindup='tool_windup',OrbitalWindup='tool_windup',BowlingBallWindup='tool_windup',CrowbarWindup='tool_windup',GreatswordWindup='tool_windup',SledgehammerWindup='tool_windup',JellyGrenadeWindup='tool_windup',MoltenTongsWindup='tool_windup',
  BowlingBallRelease='tool_throw',JellyGrenadeRelease='tool_throw',MoltenTongsRelease='tool_throw',JellyStick='tool_stick'})[kind]
 if cue then self.ctx.audio:play(cue,position);return end
 if kind:sub(-5)=='Whiff' then
  self.ctx.audio:play('tool_throw',position,{pitch=kind=='CrowbarWhiff' and 1.25 or .84,level=.68})
  return
 end
 if kind:sub(-5)=='Probe' then
  self.ctx.audio:play('tool_stick',position,{level=.6})
  RoleVisuals.Pulse(position,color,.25,3,.42)
  return
 end
 if kind~='Drop' then
  local grenade=kind=='JellyGrenade';self.ctx.audio:play(grenade and 'impact' or kind=='BowlingBall' and 'breaker_contact' or kind=='Crowbar' and 'tool_pipe' or kind=='Greatsword' and 'tool_slice' or kind=='MoltenTongs' and 'tool_sizzle' or kind=='Sledgehammer' and 'breaker_contact' or kind=='Shatter' and 'rubble' or 'rock_clack',position,{pitch=grenade and .65 or .8,level=1})
  self.ctx.presentation:kick(position,grenade and .14 or .075,now)
 end
 local slab=source:GetAttribute('Slab');local size=source:GetAttribute('RockSize')
 local rockFrame=source:GetAttribute('RockFrame')
 local radius=size and math.clamp(math.max(size.X,size.Z)*.5,.8,8) or 1
 local reduced=BeamVFX.reduced()
 if slab and rockFrame then
  local frame=CFrame.new(position)*rockFrame.Rotation
  local scale=math.clamp(radius,1,6)
  -- One sweep across the selected cut plane. The detached volume is still
  -- together until the pressure at its center throws the six pieces outward.
  if not reduced then
   local left=(frame*CFrame.new(-slab.X*.62,-slab.Y*.5,.02)).Position
   local right=(frame*CFrame.new(slab.X*.62,-slab.Y*.5,.02)).Position
   RoleVisuals.Beam(left,right,Color3.fromRGB(178,232,255),.14*scale,.16,'Lance')
   RoleVisuals.Pulse(position,Color3.fromRGB(178,232,255),radius*.9,radius*3.1,.46)
  end
 end
 if kind=='JellyGrenade' then RoleVisuals.Pulse(position,color,radius*.65,24,.47)
 elseif kind=='BowlingBall' or kind=='Sledgehammer' then RoleVisuals.Pulse(position,Color3.fromRGB(238,203,154),radius*.8,radius*3.2,.37)
 elseif kind=='MoltenTongs' then RoleVisuals.Pulse(position,color,radius*.6,radius*2.25,.58) end
end
function V:layout(item,active)
 local size=self.ctx.parent.AbsoluteSize;local touch=self.uis.TouchEnabled and not self.uis.KeyboardEnabled
 local width=math.clamp(size.X-24,120,544);local columns=(size.X<450 and size.Y>=430) and 4 or ToolRules.SLOTS
 local cell=(width-(columns-1)*6)/columns;local height=size.Y<430 and 59 or 72
 local totalHeight=math.ceil(ToolRules.SLOTS/columns)*(height+6)-6
 local bottom=touch and (size.X<550 and 98 or 18) or 12
 self.gui.Size=UDim2.fromOffset(width,totalHeight);self.gui.Position=UDim2.new(.5,0,1,-bottom);self.gui.Visible=not self.ctx.hidden()
 for i,slot in ipairs(self.slots) do
  local entry=self.state.slots[i];slot.button.Size=UDim2.fromOffset(cell,height);slot.button.Position=UDim2.fromOffset(((i-1)%columns)*(cell+6),math.floor((i-1)/columns)*(height+6))
  slot.icon.Size=UDim2.new(1,-8,0,height-35);slot.name.Position=UDim2.fromOffset(3,height-33)
  slot.name.Text=entry and (entry.state=='Held' and ToolRules.ITEMS[entry.kind].short or entry.state=='Recover' and 'Touch ball' or entry.state=='Windup' and 'Winding up' or entry.state=='Deployed' and 'Deployed' or entry.state=='Molten' and 'Melting' or entry.state=='Stuck' and 'Fusing…' or 'Thrown') or '—'
  slot.fill.Size=UDim2.fromScale(entry and entry.hp/entry.maxHP or 0,1)
  slot.fill.BackgroundColor3=entry and entry.hp/entry.maxHP<=.25 and Color3.fromRGB(246,117,83) or Color3.fromRGB(156,231,102)
  slot.button.BackgroundColor3=self.state.selected==i and Color3.fromRGB(74,97,148) or Color3.fromRGB(45,49,63)
  slot.button.BackgroundTransparency=entry and .05 or .4
  slot.button.Selectable=entry and entry.state=='Held' or false
 end
 self.use.Visible=active==true and touch
 self.use.Text='Use';self.use.Position=UDim2.new(.5,-54,1,-bottom-totalHeight-68)
 self.hint.Text=active and ToolRules.ITEMS[item.kind].name or ''
end
function V:resetArms()
 for joint,base in pairs(self.posed) do if joint.Parent then joint.Transform=base end end
 table.clear(self.posed)
end
function V:poseArms(dt,now)
 local camera=workspace.CurrentCamera
 if not camera then return end
 for _,p in ipairs(self.players:GetPlayers()) do
  local character=p.Character
  local hr=character and character:FindFirstChild('HumanoidRootPart')
  local rig=self.rigs[p]
  if rig and rig.character~=character then self.rigs[p]=nil;rig=nil end
  if not hr or (p~=self.player and (camera.CFrame.Position-hr.Position).Magnitude>115) then continue end
  local held=p:GetAttribute('HeldFieldTool')
  local action=p:GetAttribute('ToolActionKind')
  local at=p:GetAttribute('ToolActionAt')
  local elapsed=at and now-at or math.huge
  if not ToolRules.ITEMS[action] or elapsed>=ToolArt.recovery(action) then action=nil end
  local kind=action or held
  if not kind and not rig then continue end
  if not rig then
   rig={character=character,joints=ToolArt.armRig(character),weight=0}
   self.rigs[p]=rig
  end
  if not rig.joints[1] then
   if now<(rig.retryAt or 0) then continue end
   rig.retryAt=now+.4;rig.joints=ToolArt.armRig(character)
  end
  if kind then rig.kind=kind end
  rig.weight+=( (kind and 1 or 0)-rig.weight)*(1-math.exp(-dt*22))
  if rig.weight<.012 then if not kind then self.rigs[p]=nil end;continue end
  local aim=p:GetAttribute('ToolAim')
  local heading=0
  if action and aim then
   local direction=hr.CFrame:PointToObjectSpace(aim)
   heading=math.clamp(math.deg(math.atan2(-direction.X,-direction.Z)),-90,90)*.70
   local weight=elapsed<0 and math.clamp(1+elapsed/ToolRules.ITEMS[action].windup,0,1) or math.clamp(1-elapsed/ToolArt.recovery(action),0,1)
   heading*=weight
  end
  ToolArt.poseArms(rig.joints,rig.kind,action,elapsed,heading,rig.weight,self.posed)
 end
 for p in pairs(self.rigs) do if not p.Parent then self.rigs[p]=nil end end
end
function V:step(dt,now)
 local item=self:selected();local active=type(item)=='table' and item.state=='Held' and not self.ctx.hidden()
 if now>=(self.hudAt or 0) then self.hudAt=now+.09;self:layout(item,active) end
 for source,r in pairs(self.world) do
  if not source.Parent then r.model:Destroy();self.world[source]=nil
  else
   local state=source:GetAttribute('State');local frame=source.CFrame
   local origin,velocity=source:GetAttribute('Origin'),source:GetAttribute('Velocity')
   if state=='Flying' and origin and velocity then
    local t=math.max(0,now-(source:GetAttribute('StartedAt') or now));local def=ToolRules.ITEMS[r.kind]
    frame=CFrame.new(ToolRules.position(origin,velocity,def.gravity,t))*CFrame.Angles(t*10,0,t*3)
   end
   r.model:PivotTo(frame);r.fill.Size=UDim2.fromScale((source:GetAttribute('HP') or 0)/(source:GetAttribute('MaxHP') or 1),1)
   if state=='Stuck' then local q=math.clamp(1-((source:GetAttribute('FuseAt') or now)-now)/ToolRules.ITEMS.JellyGrenade.fuse,0,1);r.model.PrimaryPart.Color=Color3.fromRGB(144,225,99):Lerp(Color3.fromRGB(255,245,155),math.sin(now*(12+q*18))*.5+.5) end
  end
 end
 for _,p in ipairs(self.players:GetPlayers()) do
  local kind=p:GetAttribute('HeldFieldTool');local hand=p.Character and (p.Character:FindFirstChild('RightHand') or p.Character:FindFirstChild('Right Arm'))
  local r=self.held[p]
  if r and (r.kind~=kind or not hand) then r.model:Destroy();self.held[p]=nil;r=nil end
  if kind and hand and ToolRules.ITEMS[kind] then
   if not r then r={kind=kind,model=ToolArt.create(kind,self.ctx.localFX)};self.held[p]=r end
   r.model:PivotTo(ToolArt.grip(kind,hand))
  end
 end
 for p,r in pairs(self.held) do if not p.Parent then r.model:Destroy();self.held[p]=nil end end

end
function V:destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 self:resetArms()
 for _,slot in ipairs(self.slots) do if slot.model then slot.model:Destroy() end end
 for _,r in pairs(self.world) do r.model:Destroy() end
 for _,r in pairs(self.held) do r.model:Destroy() end
 self.gui:Destroy();self.use:Destroy()
 if self.oldBackpack~=nil then pcall(function() game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,self.oldBackpack) end) end
end
return V

end)()
local PickupMotion = (function()
-- Render-only sampling of authoritative pickup snapshots. A short interpolation
-- buffer preserves acceleration, gravity and floor contacts without chasing a
-- succession of network targets. It never decides collection or grants ore.
-- Match the authoritative OreDrops trajectory when predicting between packets.
local M={DELAY=.1,MAX_PREDICTION=.12,GRAVITY=70,AIR_DRAG=.9,GROUND_DRAG=18}
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function axis(a,b,va,vb,t,span)
 local slope=(b-a)/span
 if math.abs(slope)<1e-6 then return a end
 -- Bound tangents so homing turns cannot make a buffered fragment jump past
 -- either server sample, even when a collision flips its velocity.
 va=va*slope>0 and math.min(math.abs(va),3*math.abs(slope))*(slope>0 and 1 or -1) or 0
 vb=vb*slope>0 and math.min(math.abs(vb),3*math.abs(slope))*(slope>0 and 1 or -1) or 0
 local a2,b2=va/slope,vb/slope;local magnitude=a2*a2+b2*b2
 if magnitude>9 then local k=3/math.sqrt(magnitude);va*=k;vb*=k end
 local t2,t3=t*t,t*t*t
 return (2*t3-3*t2+1)*a+(t3-2*t2+t)*span*va+(-2*t3+3*t2)*b+(t3-t2)*span*vb
end
function M.position(samples,now)
 local at=now-M.DELAY
 local first=samples[1];if not first then return nil end
 if at<=first.at then return first.x,first.y,first.z end
 for i=2,#samples do
  local b=samples[i];local a=samples[i-1]
  if at<=b.at then
   local span=math.max(.001,b.at-a.at);local t=clamp((at-a.at)/span,0,1)
   return axis(a.x,b.x,a.vx,b.vx,t,span),math.max(b.floor or -math.huge,axis(a.y,b.y,a.vy,b.vy,t,span)),axis(a.z,b.z,a.vz,b.vz,t,span)
  end
 end
 local s=samples[#samples];local dt=clamp(at-s.at,0,M.MAX_PREDICTION)
 local x,y,z
 if s.homing then x=s.x+s.vx*dt;y=s.y+s.vy*dt;z=s.z+s.vz*dt
 else
  local coefficient=(s.floor and s.y<=s.floor+.001 and math.abs(s.vy)<.8) and M.GROUND_DRAG or M.AIR_DRAG
  local drag=(1-math.exp(-coefficient*dt))/coefficient
  x=s.x+s.vx*drag;y=s.y+s.vy*dt-.5*M.GRAVITY*dt*dt;z=s.z+s.vz*drag
 end
 return x,math.max(s.floor or -math.huge,y),z
end
function M.opacity(now,fadeAt,expiresAt)
 if type(expiresAt)~='number' or type(fadeAt)~='number' then return 1 end
 local t=clamp((now-fadeAt)/math.max(.001,expiresAt-fadeAt),0,1)
 return 1-t*t*(3-2*t)
end
function M.tumble(age,landAge)
 age=math.max(0,age)
 -- Angular momentum carries across contact, then friction arrests the spin.
 -- Sampling absolute age keeps landing poses equal at all render rates.
 if type(landAge)~='number' or age<=landAge then return age*5.4 end
 return math.max(0,landAge)*5.4+(1-math.exp(-(age-landAge)*16))*.22
end
function M.supportHeight(sx,sy,sz,rx,ry,rz)
 -- Vertical extent of a box rotated Rx * Ry * Rz. Keep the collectible's
 -- authored mesh above its contact plane while it tumbles and settles.
 local a=math.cos(rx)*math.sin(rz)+math.sin(rx)*math.sin(ry)*math.cos(rz)
 local b=math.cos(rx)*math.cos(rz)-math.sin(rx)*math.sin(ry)*math.sin(rz)
 local c=-math.sin(rx)*math.cos(ry)
 return (math.abs(a)*sx+math.abs(b)*sy+math.abs(c)*sz)*.5
end
function M.collection(t)
 t=clamp(t,0,1)
 return t*t*(3-2*t),1-t*t
end
return M

end)()
local PickupView = (function()
-- Owner/run-bound ore. Smooth visuals observe server snapshots and receipts;
-- neither a magnet animation nor a disappearing view can grant backpack units.
local Players=game:GetService('Players')
local Http=game:GetService('HttpService')
local V={};V.__index=V
local function backpack(owner,fallback)
 local character=owner and owner.Character
 local torso=character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'))
 if torso then return torso.CFrame:PointToWorldSpace(Vector3.new(0,.3,.8)),torso end
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 return hr and hr.Position or fallback,nil
end
local function sample(r,source,now)
 local at=source:GetAttribute('SnapshotAt') or now
 if r.sampleAt and at<=r.sampleAt then return end
 local position=source:GetAttribute('Position') or source.Position
 local velocity=source:GetAttribute('Velocity') or Vector3.zero
 r.sampleAt=at
 table.insert(r.samples,{at=at,x=position.X,y=position.Y,z=position.Z,vx=velocity.X,vy=velocity.Y,vz=velocity.Z,
  floor=source:GetAttribute('FloorY'),homing=source:GetAttribute('Homing')==true})
 while #r.samples>5 do table.remove(r.samples,1) end
 r.velocity=velocity
 r.fadeAt=source:GetAttribute('FadeAt');r.expiresAt=source:GetAttribute('ExpiresAt')
end
function V.new(root,parent,audio)
 local player=Players.LocalPlayer
 local self=setmetatable({records={},byId={},parent=parent,root=root,connections={},audio=audio,lastSound=0},V)
 local function add(source)
  if self.closed then return end
  if not source:IsA('BasePart') or not source:GetAttribute('PickupId') or self.records[source] then return end
  if (source:GetAttribute('CollectedAt') or 0)>0 then return end
  local position=source:GetAttribute('Position');if typeof(position)~='Vector3' then return end
  local view=source:Clone();view.Name='CollectibleOre';view.LocalTransparencyModifier=0
  view.CanQuery=false;view.CanCollide=false;view.CanTouch=false;view.CastShadow=false;view.Parent=parent
  source.LocalTransparencyModifier=1
  local id=source:GetAttribute('PickupId')
  local r={view=view,pos=position,size=source.Size,seed=id,
   samples={},owner=source:GetAttribute('Owner'),born=source:GetAttribute('SpawnAt') or workspace:GetServerTimeNow()}
  local contactAt=source:GetAttribute('GroundImpactAt')
  if type(contactAt)=='number' and contactAt>0 then r.landAge=math.max(0,contactAt-r.born) end
  self.records[source]=r;self.byId[id]=r;sample(r,source,workspace:GetServerTimeNow())
 end
 for _,source in ipairs(root:GetDescendants()) do add(source) end
 table.insert(self.connections,root.DescendantAdded:Connect(function(source) task.defer(add,source) end))
 table.insert(self.connections,root.DescendantRemoving:Connect(function(source)
  local r=self.records[source]
  if r then r.removedAt=workspace:GetServerTimeNow() end
 end))
 table.insert(self.connections,player:GetAttributeChangedSignal('MA_Collect'):Connect(function()
  local ok,receipt=pcall(Http.JSONDecode,Http,player:GetAttribute('MA_Collect') or '')
  if not ok or type(receipt)~='table' or type(receipt.serial)~='number' or receipt.serial==self.lastReceipt then return end
  self.lastReceipt=receipt.serial
  local now=workspace:GetServerTimeNow()
  if math.abs(now-(receipt.at or 0))>.7 then return end
  local rootPart=player.Character and player.Character:FindFirstChild('HumanoidRootPart');if not rootPart then return end
  local r=self.byId[receipt.pickupId]
  if r and receipt.exhausted==true then r.collectAt=now;r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt) end
  local target=backpack(player,rootPart.Position)
  if audio and os.clock()-self.lastSound>.09 then
   local at=os.clock();self.pickupChain=at-self.lastSound<.6 and math.min(6,(self.pickupChain or 0)+1) or 0
   self.lastSound=at;audio:play('pickup',target,{pitch=1+self.pickupChain*.045})
  end
 end))
 return self
end
function V:update(dt,now)
 for source,r in pairs(self.records) do
  if not r.collectAt and source.Parent then
   local collectedAt=source:GetAttribute('CollectedAt')
   if type(collectedAt)=='number' and collectedAt>0 and now-collectedAt<.7 then
    r.collectAt=now;r.collectFrom=r.drawPosition or r.pos;r.collectOpacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
    r.collectTarget=source:GetAttribute('CollectedPosition')
   end
  end
  local opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt);local scale=1;local done=false
  if r.collectAt then
   local t=(now-r.collectAt)/.22;local ease,shrink=PickupMotion.collection(t)
   local owner=Players:GetPlayerByUserId(r.owner)
   local target=backpack(owner,r.collectTarget or r.collectFrom)
   r.pos=r.collectFrom:Lerp(target,ease)+Vector3.new(0,math.sin(math.clamp(t,0,1)*math.pi)*.18,0)
   opacity=(r.collectOpacity or 1)*(1-math.clamp((t-.7)/.3,0,1));scale=math.max(.04,shrink);done=t>=1
  elseif source.Parent and not r.removedAt then
   -- Landing pose is persistent state, even when its timestamp arrives too
   -- late to replay a sound. A streamed/stalled observer must still settle.
   local contactAt=source:GetAttribute('GroundImpactAt')
   if not r.landAge and type(contactAt)=='number' and contactAt>0 then
    r.landAge=math.max(0,contactAt-r.born)
   end
   sample(r,source,now)
   local x,y,z=PickupMotion.position(r.samples,now)
   if x then r.pos=Vector3.new(x,y,z) end
   opacity=PickupMotion.opacity(now,r.fadeAt,r.expiresAt)
  else
   r.removedAt=r.removedAt or now
   -- Destruction can replicate just before its receipt. Keep a tiny grace
   -- window, then fade in place for expiry/cleanup without inventing collection.
   opacity*=1-math.clamp((now-r.removedAt-.06)/.18,0,1);done=now-r.removedAt>=.28
  end
  if done then
   r.view:Destroy()
   self.byId[r.seed]=nil;self.records[source]=nil
  else
   local age=math.max(0,now-PickupMotion.DELAY-r.born)
   local tumble=PickupMotion.tumble(age,r.landAge)
   local rx,ry,rz=r.seed*.71+tumble,r.seed*.9+tumble*.6,r.seed*.43+tumble*.8
   local position=r.pos
   local latest=r.samples[#r.samples]
   if not r.collectAt and latest and latest.floor then
    local support=PickupMotion.supportHeight(r.size.X,r.size.Y,r.size.Z,rx,ry,rz)
    -- Lift the entire trajectory by the rotated support extent, preserving
    -- the small rebound instead of clamping it away under the visible mesh.
    position=Vector3.new(position.X,math.max(latest.floor,position.Y)+support-.22,position.Z)
   end
   r.drawPosition=position
   r.view.CFrame=CFrame.new(position)*CFrame.Angles(rx,ry,rz)
   r.view.Size=r.size*scale;r.view.Transparency=1-opacity

  end
 end
end
function V:destroy()
 if self.closed then return end;self.closed=true
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for source,r in pairs(self.records) do if source.Parent then source.LocalTransparencyModifier=0 end;r.view:Destroy() end
 self.records={};self.byId={}
end
return V

end)()
local CommandView = (function()
-- Click individual rocks or drag across them to paint a work queue.
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local V={};V.__index=V
local BLUE=Color3.fromRGB(135,218,255)
local GOLD=Color3.fromRGB(255,201,100)
local GREEN=Color3.fromRGB(136,235,163)
local RED=Color3.fromRGB(233,134,120)
function V.new(ctx)
 return setmetatable({ctx=ctx,pool={},pending={},queued={},queueJSON='',clock=0},V)
end
function V:beginDrag() self.dragging=true;self.visited={} end
function V:endDrag() self.dragging=false;self.visited=nil end
function V:request(id,paint)
 local profile=self.ctx.profile();if not profile or not profile.run then return end
 if self.visited then self.visited[id]=true end
 local at=os.clock();if self.pending[id] and at-self.pending[id].at<1 then return end
 local request=Http:GenerateGUID(false);self.pending[id]={at=at,request=request}
 self.ctx.command:FireServer('MineOre',{requestId=request,runId=profile.run.id,resourceId=id,toggle=not paint})
end
function V:reply(state)
 for id,pending in pairs(self.pending) do if pending.request==state.requestId then self.pending[id]=nil end end
 if state.resourceId then self.flash={id=state.resourceId,at=os.clock(),color=state.status=='accepted' and GREEN or state.status=='queued' and GOLD or RED} end
end
function V:update(dt,now)
 self.clock+=dt;if self.clock<.06 then return end;self.clock=0
 local ctx=self.ctx;local player=Players.LocalPlayer;local visible=not ctx.hidden()
 local queuedJSON=player:GetAttribute('QueuedOreIds') or '[]'
 if queuedJSON~=self.queueJSON then
  self.queueJSON=queuedJSON;self.queued={}
  local ok,list=pcall(Http.JSONDecode,Http,queuedJSON)
  if ok and type(list)=='table' then for index,id in ipairs(list) do self.queued[id]=index end end
 end
 local working={}
 for source in pairs(ctx.drones) do
  if source:GetAttribute('Owner')==player.UserId and (source:GetAttribute('HP') or 0)>0 then
   local id=source:GetAttribute('TargetId');if id and id~='' then working[id]=true end
  end
 end
 local hover;local camera=workspace.CurrentCamera
 if visible and camera and not UIS:GetFocusedTextBox() then
  local pointer=UIS:GetMouseLocation()
  local ray
  if UIS.GamepadEnabled and UIS:GetLastInputType()==Enum.UserInputType.Gamepad1 then
   ray=camera:ViewportPointToRay(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
  elseif UIS.MouseEnabled and not ctx.blocks(pointer) then ray=camera:ScreenPointToRay(pointer.X,pointer.Y) end
  if ray then
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={ctx.parent,player.Character}
   local hit=workspace:Raycast(ray.Origin,ray.Direction*240,params)
   if hit then
    local node=hit.Instance
    while node and node~=workspace do
     hover=hover or node:GetAttribute('ResourceId')
     node=node.Parent
    end
   end
  end
 end
 local marked={};local records=ctx.resources
 local hovered=hover and records[hover]
 local zone=hovered and hovered.source.Parent
 if zone and zone.Parent and zone.Parent.Name=='CrystalRun' then self:endDrag() end
 if not visible then self:endDrag() end
 if self.dragging and hover and records[hover] and not (self.visited and self.visited[hover]) and os.clock()>=(self.nextPaint or 0) then
  self.nextPaint=os.clock()+.12;self:request(hover,true)
 end
 if hover and records[hover] then table.insert(marked,hover) end
 for id in pairs(self.queued) do if id~=hover then table.insert(marked,id) end end
 for id in pairs(working) do if id~=hover and not self.queued[id] then table.insert(marked,id) end end
 for id,pending in pairs(self.pending) do
  if os.clock()-pending.at>3 then self.pending[id]=nil
  elseif id~=hover and not self.queued[id] and not working[id] then table.insert(marked,id) end
 end
 local flash=self.flash
 if flash and os.clock()-flash.at<.8 and flash.id~=hover and not working[flash.id] and not self.queued[flash.id] and not self.pending[flash.id] then table.insert(marked,flash.id) end
 local used=0
 for _,id in ipairs(marked) do
  local r=records[id]
  if visible and r and r.view.Parent and (r.source:GetAttribute('HP') or 0)>0 and used<24 then
   used+=1
   local h=self.pool[used]
   if not h then
    h=Instance.new('Highlight');h.Name='RockOrder';h.DepthMode=Enum.HighlightDepthMode.Occluded;h.OutlineTransparency=1;h.Parent=ctx.parent;self.pool[used]=h
   end
   local growing=now<(r.source:GetAttribute('ReadyAt') or 0)
   local busy=(r.source:GetAttribute('SlotsUsed') or 0)>=(r.source:GetAttribute('SlotCapacity') or 1)
   local color=working[id] and GREEN or self.queued[id] and GOLD or (growing or busy) and RED or BLUE
   local pulse=flash and flash.id==id and math.clamp(1-(os.clock()-flash.at)/.8,0,1) or 0
   if pulse>0 then color=flash.color end
   h.Adornee=r.view;h.Enabled=true;h.FillColor=color
   h.FillTransparency=(id==hover and .86 or .95)-pulse*.2

  end
 end
 for index=used+1,#self.pool do self.pool[index].Enabled=false end
 -- One contextual readout, never a field of floating health bars.
 local focused=hover and records[hover]
 if focused and visible and focused.view.Parent and (focused.source:GetAttribute('HP') or 0)>0 then
  if not self.meter then
   local gui=Instance.new('BillboardGui');gui.Name='FocusedRock';gui.Size=UDim2.fromOffset(132,34)
   gui.AlwaysOnTop=true;gui.MaxDistance=100;gui.Parent=ctx.parent
   local title=Instance.new('TextLabel');title.Name='Mineral';title.Size=UDim2.new(1,0,0,22)
   title.BackgroundTransparency=1;title.Font=Enum.Font.GothamBold;title.TextSize=13
   title.TextColor3=Color3.new(1,1,1);title.TextStrokeColor3=Color3.fromRGB(20,25,32);title.TextStrokeTransparency=.1;title.Parent=gui
   local track=Instance.new('Frame');track.Name='Health';track.Position=UDim2.fromOffset(5,24);track.Size=UDim2.new(1,-10,0,7)
   track.BackgroundColor3=Color3.fromRGB(25,31,38);track.BorderSizePixel=0;track.Parent=gui
   local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,4);round.Parent=track
   local fill=Instance.new('Frame');fill.Name='Remaining';fill.BorderSizePixel=0;fill.BackgroundColor3=GREEN;fill.Parent=track
   round:Clone().Parent=fill
   self.meter=gui;self.title=title;self.health=fill
  end
  local s=focused.source;local usedSlots=s:GetAttribute('SlotsUsed') or 0;local capacity=s:GetAttribute('SlotCapacity') or 1
  self.meter.Adornee=focused.view;self.meter.StudsOffsetWorldSpace=Vector3.new(0,focused.view.Size.Y*.65+.8,0);self.meter.Enabled=true
  self.title.Text=tostring(s:GetAttribute('JunkName') or s:GetAttribute('ZoneName') or s:GetAttribute('Mineral') or 'Rock')..(capacity>1 and (' · '..usedSlots..'/'..capacity) or '')
  self.health.Size=UDim2.fromScale(math.clamp((s:GetAttribute('HP') or 0)/math.max(1,s:GetAttribute('MaxHP') or 1),0,1),1)
 elseif self.meter then self.meter.Enabled=false end
end
function V:destroy()
 if self.meter then self.meter:Destroy() end
 for _,h in ipairs(self.pool) do h:Destroy() end
end
return V

end)()
local LogisticsView = (function()
-- The drone yard adds intent controls to the existing HUD; gameplay remains server-owned.
local View={}
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local function units(bag)
 local total=0;for _,value in pairs(type(bag)=='table' and bag or {}) do if type(value)=='number' then total=total+value end end;return total
end
local function compact(value)
 value=tonumber(value) or 0
 if value>=1e6 then return string.format('%.1fM',value/1e6) elseif value>=10000 then return string.format('%.1fk',value/1000) end
 return tostring(math.floor(value))
end
function View.start(ctx)
 local self: any={selected=nil,tab='Drones',loadCarrier=nil,draft={},open=false,connections={},visuals={},scanAt=0,message='',messageUntil=0}
 local U=ctx.interface;local C=U.palette;local root=ctx.parent;local player=Players.LocalPlayer
 local function profile() return ctx.profile() or {} end
 local function owned() return profile().logistics or {} end
 local function run() local p=profile();return p.run and p.run.logistics or {} end
 local function send(action,value)
  local p=profile();if not p.run or p.pendingTransaction then self.message='Wait for your current save to finish.';self.messageUntil=os.clock()+5;if ctx.notify then ctx.notify(self.message) end;return end
  ctx.command:FireServer(action,value)
 end
 local function say(message) self.message=message;self.messageUntil=os.clock()+5;if ctx.notify then ctx.notify(message) end end
 local function carrier(id)
  for _,record in ipairs(owned().carriers or {}) do if record.id==id then return record end end;return nil
 end
 local function state(id)
  local folder=player:FindFirstChild('MA_Logistics');local record=folder and folder:FindFirstChild(id)
  if record then return record:GetAttribute('State') or 'Home' end
  local published=profile().logisticsStates or {}
  local value=published[id]
  if type(value)=='table' then return value.state or value.State or 'Home' elseif type(value)=='string' then return value end
  return 'Home'
 end
 local function setOpen(value)
  self.open=value==true
  if self.layer then self.layer.Visible=self.open end
  if self.open and ctx.onOpen then ctx.onOpen() end
  if ctx.onVisibility then ctx.onVisibility() end
 end
 local targetCycle=U.button(root,UDim2.fromOffset(0,138),UDim2.fromOffset(100,36),'Fleet',function() self:cycle() end,C.accent)
 targetCycle.Name='CarrierTargetCycle';targetCycle.TextSize=15;targetCycle.Visible=false
 local carrierReturn=U.button(root,UDim2.fromOffset(0,180),UDim2.fromOffset(100,36),'Return carrier',function() self:recall() end,C.mineral)
 carrierReturn.Name='RecallSelectedCarrier';carrierReturn.TextSize=14;carrierReturn.Visible=false
 local bar=U.panel(root,UDim2.fromOffset(12,0),UDim2.fromOffset(360,42),C.panel,10);bar.Name='CarrierToolbar';bar.Visible=false
 local strip=Instance.new('ScrollingFrame');strip.BackgroundTransparency=1;strip.BorderSizePixel=0;strip.Position=UDim2.fromOffset(5,4);strip.Size=UDim2.new(1,-10,1,-8);strip.ScrollBarThickness=2;strip.ScrollingDirection=Enum.ScrollingDirection.X;strip.CanvasSize=UDim2.fromOffset(0,0);strip.Active=true;strip.ZIndex=bar.ZIndex+2;strip.Parent=bar
 local layer=U.frame(root,UDim2.fromScale(0,0),UDim2.fromScale(1,1),C.ink);layer.Name='DroneYardLayer';layer.BackgroundTransparency=1;layer.Visible=false;layer.Active=true;layer.ZIndex=70
 self.layer=layer
 local backdrop=Instance.new('TextButton');backdrop.Size=UDim2.fromScale(1,1);backdrop.BackgroundColor3=C.ink;backdrop.BackgroundTransparency=.3;backdrop.Text='';backdrop.AutoButtonColor=false;backdrop.ZIndex=71;backdrop.Parent=layer
 table.insert(self.connections,backdrop.Activated:Connect(function() setOpen(false) end))
 local sheet=U.panel(layer,UDim2.fromOffset(12,12),UDim2.fromOffset(480,540),C.panel,18);sheet.Name='DroneYard';sheet.ZIndex=72
 local title=U.text(sheet,UDim2.fromOffset(18,12),UDim2.new(1,-88,0,32),'DRONE YARD',25,C.text,true)
 U.icon(sheet,'drone',UDim2.fromOffset(18,49),UDim2.fromOffset(24,24),C.accent)
 local balance=U.text(sheet,UDim2.fromOffset(50,48),UDim2.new(1,-68,0,24),'',14,C.muted,true)
 U.button(sheet,UDim2.new(1,-56,0,12),UDim2.fromOffset(40,40),'X',function() setOpen(false) end,C.danger)
 local tabs={};local body=Instance.new('ScrollingFrame');body.Name='YardContents';body.BackgroundTransparency=1;body.BorderSizePixel=0;body.Active=true;body.ScrollBarThickness=3;body.ScrollBarImageColor3=C.muted;body.ZIndex=sheet.ZIndex+2;body.Parent=sheet
 local foot=U.text(sheet,UDim2.fromOffset(18,0),UDim2.new(1,-36,0,37),'Earn mining drones through prestige. Your permanent fleet stays with you.',13,C.muted)
 local width,height,contentWidth=480,540,444
 local signature='';local barSignature='';local purchases={};local launch,auto,storageSummary=nil,nil,nil
 local render
 local function chooseCarrier(id)
  self.loadCarrier=id;self.draft={}
  local record=carrier(id);for _,droneId in ipairs(record and record.droneIds or {}) do self.draft[droneId]=true end
 end
 local function row(y,h)
  return U.panel(body,UDim2.fromOffset(0,y),UDim2.fromOffset(contentWidth,h),C.paper,12)
 end
 local function text(parent,x,y,w,h,value,size,color)
  return U.text(parent,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),value,size or 15,color or C.text,true)
 end
 local function purchase(action,key)
  if action=='BuyCarrier' and #(owned().carriers or {})>=3 then say('Your yard already has three carriers.');return end
  send(action,key)
 end
 local function shopCard(y,name,description,price,color,duration,action,key,alreadyOwned)
  local cardHeight=contentWidth<340 and 178 or 154
  local card=row(y,cardHeight)
  local preview=action=='BuyDrone' and player:GetAttribute('MA_DevToolsEnabled')==true
  U.icon(card,'drone',UDim2.fromOffset(12,12),UDim2.fromOffset(32,32),color)
  text(card,54,10,contentWidth-(preview and 152 or 68),28,name,19)
  if preview then U.button(card,UDim2.fromOffset(contentWidth-86,8),UDim2.fromOffset(72,36),'Preview',function() send('DevAddDrone',{role=key=='Laser' and 'Striker' or key});say(name..' added to the temporary test crew.');setOpen(false) end,C.paper).TextSize=14 end
  U.text(card,UDim2.fromOffset(14,46),UDim2.fromOffset(contentWidth-28,cardHeight-96),description,15,C.muted)
  text(card,14,cardHeight-39,contentWidth-150,28,duration and string.format('%.1fs / cycle',duration) or 'Permanent equipment',13,color)
  local b=U.button(card,UDim2.fromOffset(contentWidth-136,cardHeight-44),UDim2.fromOffset(122,36),alreadyOwned and 'Owned' or compact(price)..' Quartz',function() purchase(action,key) end,color)
  b.TextSize=15;table.insert(purchases,{button=b,price=price,owned=alreadyOwned})
  return cardHeight
 end
 local pages={'Drones','Transport','Storage','Fleet','Cards'}
 for index,name in ipairs(pages) do
  tabs[name]=U.button(sheet,UDim2.fromOffset(0,82),UDim2.fromOffset(130,36),name,function()
   if name=='Fleet' or name=='Cards' then setOpen(false);local action=name=='Fleet' and ctx.openFleet or ctx.openCards;if action then action() end
   else self.tab=name;signature='' end
  end,name=='Drones' and C.accent or C.paper)
  tabs[name].LayoutOrder=index;tabs[name].Name='YardTab_'..name
 end
 render=function()
  for _,child in ipairs(body:GetChildren()) do child:Destroy() end
  purchases={};launch=nil;auto=nil;storageSummary=nil
  for name,b in pairs(tabs) do U.skin(b,name==self.tab and C.accent or C.paper,11,.92) end
  if self.tab=='Drones' then
   local pre=profile().prestigePreview or {}
   text(body,8,12,contentWidth-16,32,'GROW YOUR PERMANENT FLEET',19,C.accent)
   U.text(body,UDim2.fromOffset(8,54),UDim2.fromOffset(contentWidth-16,80),'Mine Quartz, open packs and stack your upgrades. Prestige adds a permanent mining drone and +25% base mining power.',17,C.text)
   text(body,8,143,contentWidth-16,32,tostring(pre.earnings or 0)..' / '..tostring(pre.saleRequired or 360)..' Quartz sold',18,C.mineral)
   U.button(body,UDim2.fromOffset(8,190),UDim2.fromOffset(contentWidth-16,44),'Open Quartz Workshop',function() setOpen(false);ctx.openWorkshop() end,C.mineral)
   U.button(body,UDim2.fromOffset(8,246),UDim2.fromOffset(contentWidth-16,44),'Review prestige reward',function() setOpen(false);ctx.openPrestige() end,C.accent)
   body.CanvasSize=UDim2.fromOffset(0,304)
  elseif self.tab=='Storage' then
   local card=row(0,160)
   text(card,14,10,contentWidth-28,28,'ORBITAL STORAGE',19,C.accent)
   storageSummary=U.text(card,UDim2.fromOffset(14,42),UDim2.fromOffset(contentWidth-28,62),'',16,C.text,true)
   launch=U.button(card,UDim2.fromOffset(14,112),UDim2.fromOffset(contentWidth-28,38),'Launch full storage [L]',function() send('LaunchStorage') end,C.mineral)
   U.button(body,UDim2.fromOffset(0,170),UDim2.fromOffset(contentWidth,40),'Deposit into storage',function() send('Deposit') end,C.accent)
   auto=U.button(body,UDim2.fromOffset(0,220),UDim2.fromOffset(contentWidth,40),'Auto-launch: OFF',function()
    send('AutoLaunch',not owned().autoLaunch)
   end,C.paper)
   local helpHeight=contentWidth<340 and 180 or 128
   U.text(body,UDim2.fromOffset(4,272),UDim2.fromOffset(contentWidth-8,helpHeight),'Ore keeps its mineral type. Full storage launches automatically and pays after liftoff. Carriers send ore to storage; the flying backpack fetches your full bag. Switch auto-launch off here if you want to launch capsules yourself.',15,C.muted)
   body.CanvasSize=UDim2.fromOffset(0,282+helpHeight)
  else
   local first=shopCard(0,'Carrier • four bays','Choose four permanent miners, send the carrier to a cleared field, and leave them working.',1500,C.accent,nil,'BuyCarrier',nil,false)
   local second=shopCard(first+8,'Flying Backpack','A flying backpack companion picks up your full bag and carries it to storage.',750,C.mineral,nil,'BuyBackpack',nil,owned().backpack==true)
   local y=first+second+16
   local records=owned().carriers or {}
   if not carrier(self.loadCarrier) then chooseCarrier(self.selected or (records[1] and records[1].id)) end
   text(body,4,y,contentWidth-8,28,'CARRIER LOADOUT • FOUR MINERS',16,C.accent);y=y+34
   if #records==0 then
    U.text(body,UDim2.fromOffset(4,y),UDim2.fromOffset(contentWidth-8,58),'Buy a carrier above to choose its miners. Carrier missions work in safe or cleared fields.',15,C.muted);y=y+64
   else
    for index,record in ipairs(records) do
     U.button(body,UDim2.fromOffset(0,y),UDim2.fromOffset(contentWidth,38),'Carrier '..index..' • '..state(record.id)..(record.id==self.loadCarrier and ' ✓' or ''),function() self.selected=record.id;chooseCarrier(record.id);signature='';barSignature='' end,record.id==self.loadCarrier and C.accent or C.paper);y=y+45
    end
    local count=0;for _ in pairs(self.draft) do count=count+1 end
    text(body,4,y,contentWidth-8,26,string.format('%d / 4 bays selected • edit at the depot',count),14,C.muted);y=y+32
    for _,drone in ipairs(profile().fleet or {}) do
     local role=drone.role or drone.type
     if role=='Striker' or role=='Charger' or DroneCatalog.Types[role] then
      local id=drone.id;local elsewhere=false
      for _,record in ipairs(records) do if record.id~=self.loadCarrier and table.find(record.droneIds or {},id) then elsewhere=true end end
      local entry=DroneCatalog.Types[role];local tint=entry and Color3.fromRGB(unpack(entry.Color)) or C.mineral
      U.button(body,UDim2.fromOffset(0,y),UDim2.fromOffset(contentWidth,40),(self.draft[id] and '✓ ' or '+ ')..drone.name..(elsewhere and ' • other carrier' or ''),function()
       if elsewhere then say('Unload this miner from its other carrier first.');return end
       if self.draft[id] then self.draft[id]=nil
       else local n=0;for _ in pairs(self.draft) do n=n+1 end;if n>=4 then say('A carrier has four bays. Remove a miner first.');return end;self.draft[id]=true end
       signature=''
      end,self.draft[id] and tint or C.paper);y=y+47
     end
    end
    U.button(body,UDim2.fromOffset(0,y+4),UDim2.fromOffset(contentWidth,40),'Save carrier loadout',function()
     if state(self.loadCarrier)~='Home' then say('Recall this carrier and wait for it to reach the depot before changing its miners.');return end
     local ids={};for id in pairs(self.draft) do table.insert(ids,id) end;table.sort(ids)
     send('LoadCarrier',{carrierId=self.loadCarrier,droneIds=ids})
    end,C.mineral);y=y+52
   end
   body.CanvasSize=UDim2.fromOffset(0,y)
  end
 end
 function self:isOpen() return self.open end
 function self:toggle() setOpen(not self.open) end
 function self:close() setOpen(false) end
 function self:cycle()
  local records=owned().carriers or {};local index=1
  for i,record in ipairs(records) do if record.id==self.selected then index=i+1 end end
  self.selected=records[index] and records[index].id or nil;barSignature=''
 end
 function self:dispatchField(fieldId)
  if not self.selected then return false end
  local record=carrier(self.selected)
  if not record or #(record.droneIds or {})==0 then say('Load miners in Drone yard → Transport before deploying this carrier.');return true end
  send('CarrierPatch',{carrierId=self.selected,patch=fieldId});return true
 end
 function self:recall()
  if not self.selected then return false end;send('RecallCarrier',self.selected);return true
 end
 function self:update(view,fighting)
  if ctx.hidden() and self.open then setOpen(false) end
  layer.Visible=self.open;bar.Visible=not ctx.hidden() and not self.open and #(owned().carriers or {})>0
  local touch=UIS.TouchEnabled;local short=view.Y<400
  local pockets=root:FindFirstChild('BackpackTools')
  local yardTop=pockets and pockets.Visible and (pockets.Position.Y.Offset+pockets.Size.Y.Offset+8) or 96
  local stored=units(run().storage);local capacity=profile().storageCapacity or 120
  local w=math.min(490,view.X-24);local h=math.min(568,view.Y-24)
  if w~=width or h~=height then
   width=w;height=h;contentWidth=w-36;signature=''
   sheet.Size=UDim2.fromOffset(w,h);sheet.Position=UDim2.fromOffset((view.X-w)/2,(view.Y-h)/2)
   title.Size=UDim2.new(1,-88,0,32);balance.Size=UDim2.new(1,-68,0,24)
   for i,name in ipairs(pages) do tabs[name].Position=UDim2.fromOffset(14+(i-1)*(w-28)/#pages,82);tabs[name].Size=UDim2.fromOffset((w-28)/#pages-4,40);tabs[name].TextSize=16 end
   local footerHeight=contentWidth<340 and 52 or 37
   body.Position=UDim2.fromOffset(14,128);body.Size=UDim2.fromOffset(w-28,math.max(32,h-128-footerHeight-20))
   foot.Position=UDim2.fromOffset(18,h-footerHeight-11);foot.Size=UDim2.new(1,-36,0,footerHeight)
  end
  local p=profile();local wallet=p.run and p.run.wallet or {};balance.Text=compact(wallet.Quartz or 0)..' Quartz · permanent fleet'
  local key={self.tab,tostring(w),tostring(h),tostring(owned().backpack),tostring(#(p.fleet or {})),tostring(self.loadCarrier),tostring(p.run and p.run.id),tostring(player:GetAttribute('MA_DevToolsEnabled'))}
  for _,record in ipairs(owned().carriers or {}) do table.insert(key,record.id..':'..state(record.id)..':'..table.concat(record.droneIds or {},',')) end
  for id in pairs(self.draft) do table.insert(key,id) end;table.sort(key)
  local current=table.concat(key,'|')
  if self.open and signature~=current then local scroll=body.CanvasPosition;signature=current;render();body.CanvasPosition=scroll end
  for _,item in ipairs(purchases) do U.setEnabled(item.button,not item.owned and not p.pendingTransaction and (wallet.Quartz or 0)>=item.price) end
  if storageSummary then
   local cargo=units(run().launchCargo);local hauler=units(run().backpackCargo)
   storageSummary.Text=compact(stored)..' / '..compact(capacity)..' ore stored'..(cargo>0 and string.format('\n%s in orbit • %.1fs',compact(cargo),run().launchRemaining or 0) or hauler>0 and '\nFlying backpack: '..compact(hauler)..' ore' or '\nFull capsules become mineral currency.')
   launch.Text=cargo>0 and 'Capsule in flight…' or stored>=capacity and 'Launch ready [L]' or 'Fill storage to launch'
   U.setEnabled(launch,stored>=capacity and cargo==0 and not p.pendingTransaction)
   auto.Text='Auto-launch: '..(owned().autoLaunch and 'ON' or 'OFF')
  end
  if self.selected and not carrier(self.selected) then self.selected=nil end
  local keys={tostring(self.selected)}
  for _,record in ipairs(owned().carriers or {}) do table.insert(keys,record.id..':'..state(record.id)..':'..#(record.droneIds or {})) end
  local nextBar=table.concat(keys,'|')
  if nextBar~=barSignature then
   barSignature=nextBar;for _,child in ipairs(strip:GetChildren()) do child:Destroy() end
   U.button(strip,UDim2.fromOffset(0,0),UDim2.fromOffset(80,34),'Fleet',function() self.selected=nil;barSignature='' end,not self.selected and C.mineral or C.paper)
   local x=87
   for i,record in ipairs(owned().carriers or {}) do
    U.button(strip,UDim2.fromOffset(x,0),UDim2.fromOffset(126,34),string.format('Carrier %d • %d/4',i,#(record.droneIds or {})),function() self.selected=record.id;chooseCarrier(record.id);barSignature='' end,self.selected==record.id and C.accent or C.paper);x=x+133
   end
   strip.CanvasSize=UDim2.fromOffset(x,0)
  end
  local anchor=view.Y-(touch and 108 or 12)
  if ctx.dock and ctx.dock.Visible then anchor=math.min(anchor,ctx.dock.Position.Y.Offset) end
  if ctx.context and ctx.context.Visible then anchor=math.min(anchor,ctx.context.Position.Y.Offset) end
  bar.Size=UDim2.fromOffset(math.min(500,view.X-24),42);bar.Position=UDim2.fromOffset((view.X-bar.Size.X.Offset)/2,anchor-50)
  local compactTarget=anchor-50<138
  if compactTarget then bar.Visible=false end
  targetCycle.Visible=compactTarget and not ctx.hidden() and not self.open and #(owned().carriers or {})>0
  targetCycle.Position=UDim2.fromOffset(view.X-112,yardTop+42)
  targetCycle.Text='Fleet'
  for index,record in ipairs(owned().carriers or {}) do if record.id==self.selected then targetCycle.Text='Carrier '..index;break end end
  carrierReturn.Visible=self.selected~=nil and not ctx.hidden() and not self.open
  carrierReturn.Position=UDim2.fromOffset(view.X-112,yardTop+(targetCycle.Visible and 84 or 42))
  sheet.Position=UDim2.fromOffset((view.X-w)/2,(view.Y-h)/2)
  foot.Text=os.clock()<self.messageUntil and self.message or self.selected and 'Carrier selected • click a field to deploy • [R] returns it • [C] changes target' or 'Earn mining drones through prestige. Your permanent fleet stays with you.'
 end
 -- All players render the same authoritative logistics poses through local clones.
 function self:step(now,dt)
  if self.selected and not self.open and not ctx.hidden() and now>=(self.hoverAt or 0) then
   self.hoverAt=now+.06
   local fieldId=nil
   local published=profile().logisticsStates or {};local selected=published[self.selected]
   if type(selected)=='table' then fieldId=selected.field end
   if UIS.MouseEnabled and not UIS:GetFocusedTextBox() then
    local pointer=UIS:GetMouseLocation();local camera=workspace.CurrentCamera
    if camera and (not ctx.blocks or not ctx.blocks(pointer)) then
     local ray=camera:ScreenPointToRay(pointer.X,pointer.Y);local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={ctx.localFX,player.Character}
     local hit=workspace:Raycast(ray.Origin,ray.Direction*300,params);local node=hit and hit.Instance
     while node and node~=workspace do fieldId=node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier') or fieldId;node=node.Parent end
    end
   end
   local floor=nil;local fields=ctx.world:FindFirstChild('Fields')
   if fields then for _,field in ipairs(fields:GetChildren()) do if (field:GetAttribute('FieldId') or field:GetAttribute('Tier'))==fieldId then floor=field:FindFirstChild('Field') or field:FindFirstChild('FieldFloor');break end end end
   if not self.fieldMark then self.fieldMark=Instance.new('Highlight');self.fieldMark.Name='CarrierFieldOrder';self.fieldMark.DepthMode=Enum.HighlightDepthMode.Occluded;self.fieldMark.FillColor=C.accent;self.fieldMark.FillTransparency=.92;self.fieldMark.OutlineTransparency=1;self.fieldMark.Parent=ctx.localFX end
   self.fieldMark.Adornee=floor;self.fieldMark.Enabled=floor~=nil
  elseif (not self.selected or self.open or ctx.hidden()) and self.fieldMark then self.fieldMark.Enabled=false end
  if now>=self.scanAt then
   self.scanAt=now+.2
   for _,source in ipairs(ctx.world:GetChildren()) do
    local class=source:GetAttribute('Class')
    local previous=self.visuals[source]
    if previous and previous.geometryDirty then
     for _,connection in ipairs(previous.connections) do connection:Disconnect() end
     previous.view:Destroy();for node,value in pairs(previous.hidden) do if node.Parent then node.LocalTransparencyModifier=value end end;self.visuals[source]=nil
    end
    if source:IsA('Model') and (class=='Carrier' or class=='Backpack' or class=='Capsule') and not self.visuals[source] and source:GetAttribute('Pose') then
     local clone=source:Clone();clone.Name='View_'..source.Name
     for _,node in ipairs(clone:GetDescendants()) do
      if node:IsA('LuaSourceContainer') or node:IsA('ProximityPrompt') or node:IsA('BillboardGui') then node:Destroy()
      elseif node:IsA('BasePart') then node.Anchored=true;node.CanCollide=false;node.CanTouch=false;node.CanQuery=false;node.LocalTransparencyModifier=0 end
     end
     clone.Parent=ctx.localFX;local hidden={}
     for _,node in ipairs(source:GetDescendants()) do if node:IsA('BasePart') then hidden[node]=node.LocalTransparencyModifier;node.LocalTransparencyModifier=1 end end
     local record={samples={},view=clone,pose=source:GetAttribute('Pose'),hidden=hidden,connections={},exhaust=clone:FindFirstChild('Exhaust',true),sourceExhaust=source:FindFirstChild('Exhaust',true)}
     local function changed() record.geometryDirty=true end
     table.insert(record.connections,source.DescendantAdded:Connect(changed));table.insert(record.connections,source.DescendantRemoving:Connect(changed))
     self.visuals[source]=record
    end
   end
  end
  for source,record in pairs(self.visuals) do
   if not source.Parent then
    for _,connection in ipairs(record.connections) do connection:Disconnect() end
    record.view:Destroy();self.visuals[source]=nil
   else
    local target=source:GetAttribute('Pose')
    if target then
     local reset=source:GetAttribute('Class')=='Capsule' and (source:GetAttribute('Manifest') or 0)==0
     MotionBuffer.push(record.samples,source:GetAttribute('PoseAt'),target,reset)
     record.pose=MotionBuffer.pose(record.samples,now) or target
     if record.drawnPose~=record.pose then record.view:PivotTo(record.pose);record.drawnPose=record.pose end
     local exhaust,original=record.exhaust,record.sourceExhaust
     if exhaust and original and exhaust:IsA('BasePart') then exhaust.Transparency=original.Transparency end
    end
   end
  end
 end
 function self:destroy()
  for _,connection in ipairs(self.connections) do connection:Disconnect() end
  for source,record in pairs(self.visuals) do
   for _,connection in ipairs(record.connections) do connection:Disconnect() end
   record.view:Destroy();if source.Parent then for node,value in pairs(record.hidden) do if node.Parent then node.LocalTransparencyModifier=value end end end
  end
  targetCycle:Destroy();carrierReturn:Destroy();bar:Destroy();layer:Destroy()
  if self.fieldMark then self.fieldMark:Destroy() end
 end
 return self
end
return View

end)()
local SelectorView = (function()
-- Local aiming, pinned command feedback and bounded crystal healing cues.
local V={}
V.__index=V
local idle=ColorSequence.new(Color3.fromRGB(106,218,255))
local active=ColorSequence.new(Color3.fromRGB(255,214,83))
local preview=ColorSequence.new(Color3.fromRGB(185,239,255))
local heights={.08,.32,.64,1.04,1.48}
local widths={.18,.32,.42,.48,.52}
local fades={.1,.35,.55,.74,.9}

local function marker(parent,isPreview)
 local anchor=Instance.new('Part')
 anchor.Name=isPreview and 'SelectorPreview' or 'MiningSelector'
 anchor.Size=Vector3.one;anchor.Anchored=true;anchor.Transparency=1
 anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Parent=parent
 local layers={}
 for i,height in ipairs(heights) do
  local layer={height=height,corners={},beams={}}
  for n=1,4 do
   local corner=Instance.new('Attachment');corner.Parent=anchor;layer.corners[n]=corner
  end
  for n=1,4 do
   local beam=Instance.new('Beam')
   beam.Attachment0=layer.corners[n];beam.Attachment1=layer.corners[n%4+1]
   beam.FaceCamera=true;beam.Segments=1;beam.LightEmission=.7;beam.LightInfluence=0
   beam.Width0=widths[i];beam.Width1=widths[i];beam.Enabled=false
   beam.Transparency=NumberSequence.new(isPreview and math.min(.98,fades[i]+.38) or fades[i])
   beam.Parent=anchor;layer.beams[n]=beam
  end
  layers[i]=layer
 end
 return {anchor=anchor,layers=layers}
end

local function show(mark,point,width,color)
 local visible=point~=nil
 if visible and mark.point~=point then mark.anchor.Position=point end
 if visible and mark.width~=width then
  local h=width*.5
  for _,layer in ipairs(mark.layers) do
   local y=layer.height
   for i,corner in ipairs(layer.corners) do
    corner.Position=Vector3.new((i==1 or i==4) and -h or h,y,i<=2 and -h or h)
   end
  end
  mark.width=width
 end
 if visible~=mark.visible or visible and color~=mark.color then
  for _,layer in ipairs(mark.layers) do for _,beam in ipairs(layer.beams) do
   beam.Enabled=visible
   if visible then beam.Color=color end
  end end
 end
 mark.visible=visible;mark.point=point;mark.color=color
end

function V.new(options)
 return setmetatable({options=options,cues={},clock=0},V)
end
function V:aim(ray)
 local o=self.options
 local run=o.world.Map:FindFirstChild('CrystalRun')
 if not run or o.hidden() then return nil end
 local character=o.player.Character
 local hr=character and character:FindFirstChild('HumanoidRootPart')
 if not hr then return nil end
 local filter=RaycastParams.new();filter.FilterType=Enum.RaycastFilterType.Exclude
 filter.FilterDescendantsInstances={character,o.parent}
 -- Crystal proxies remain queryable for laser contact, but don't intercept aim.
 filter.RespectCanCollide=true
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,filter)
 if not hit then return nil end
 local zone=hit.Instance.Parent
 if not zone or zone.Parent~=run then return nil end
 local bed=zone:FindFirstChild('Field')
 if hit.Instance~=bed then return nil end
 local point=Mining.selectorCenter(hit.Position,bed.CFrame,bed.Size)
 if not point then return nil end
 local delta=point-hr.Position
 local field=bed:GetAttribute('FieldId')
 if math.abs(delta.Y)>=16 or delta.X*delta.X+delta.Z*delta.Z>Mining.SELECTOR_RANGE^2 then return nil end
 return point,field
end
function V:commit(ray)
 local point,id=self:aim(ray)
 local profile=self.options.profile()
 if not point or not id or not profile then return false end
 self.options.command:FireServer('PlaceSelector',{fieldId=id,position=point,runId=profile.run.id})
 return true
end
function V:showAim(dt,ray)
 local o=self.options
 local profile=o.profile()
 local pin=not o.hidden() and o.player:GetAttribute('MA_Selector') or nil
 if not self.pinned and profile and o.world.Map:FindFirstChild('CrystalRun') then
  self.pinned=marker(o.parent,false);self.preview=marker(o.parent,true)
 end
 if not self.pinned or not profile then return end
 local width=Workshop.selectorWidth(profile)
 self.clock+=dt
 if not ray then self.aimPoint=nil
 elseif self.clock>=.033 then self.clock=0;self.aimPoint=self:aim(ray) end
 local point=self.aimPoint
 if point and pin and (point-pin).Magnitude<.8 then point=nil end
 show(self.pinned,pin,width,o.player:GetAttribute('MA_SelectorWorking') and active or idle)
 show(self.preview,point,width,preview)
end

function V:heal(view,now)
 local camera=workspace.CurrentCamera
 if not camera or (camera.CFrame.Position-view.Position).Magnitude>64 then return end
 for i=1,2 do
  local available
  for _,cue in ipairs(self.cues) do if not cue.at then available=cue;break end end
  if not available then
   if #self.cues>=16 then return end
   local gui=Instance.new('BillboardGui')
   gui.Name='CrystalHealing';gui.Size=UDim2.fromOffset(22,22);gui.LightInfluence=0;gui.MaxDistance=68
   gui.Parent=self.options.parent
   local plus=Instance.new('TextLabel')
   plus.Size=UDim2.fromScale(1,1);plus.BackgroundTransparency=1;plus.Font=Enum.Font.GothamBold
   plus.Text='+';plus.TextColor3=Color3.fromRGB(138,255,151);plus.TextSize=22;plus.Parent=gui
   available={gui=gui,text=plus};table.insert(self.cues,available)
  end
  available.at=now;available.side=i==1 and -1 or 1
  available.gui.Adornee=view;available.gui.Enabled=true
 end
end
function V:updateHealing(now)
 for _,cue in ipairs(self.cues) do
  if cue.at then
   local age=now-cue.at
   local view=cue.gui.Adornee
   if age>=.65 or not view or not view.Parent then
    cue.at=nil;cue.gui.Enabled=false;cue.gui.Adornee=nil
   else
    cue.gui.StudsOffsetWorldSpace=Vector3.new(cue.side*(.45+age*.55),view.Size.Y*.5+.4+age*2.5,cue.side*.3)
    cue.text.TextTransparency=math.clamp((age-.24)/.41,0,1)
   end
  end
 end
end
function V:destroy()
 if self.pinned then self.pinned.anchor:Destroy();self.preview.anchor:Destroy() end
 for _,cue in ipairs(self.cues) do cue.gui:Destroy() end
end
return V

end)()
-- Presentation and bounded intent only. Gameplay never reads these local viewmodels.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local TweenService=game:GetService('TweenService')
local player=Players.LocalPlayer
local world=workspace:WaitForChild('MiningAway')
local command=RS:WaitForChild('MiningAway'):WaitForChild('Command')
local localFX=Instance.new('Folder');localFX.Name='MiningAwayPresentation';localFX.Parent=workspace
local soundscape=Soundscape.new(localFX)
local presentation=Presentation.new({parent=localFX,audio=soundscape})
local rockDamage=RockDamage.new()
-- Renderer cues follow the same observed charge/release as the visual. Reuse
-- the bounded spatial audio mixer and existing reduced-motion camera path.
soundscape.chargeFromRenderer=true
BeamVFX.onCharge=function(r,position,now,q)
 soundscape:setLoop(r,'charge',position,.45+.5*q,.88+.12*q)
end
BeamVFX.onChargeEnd=function(r) soundscape:stopLoop(r) end
BeamVFX.onCue=function(kind,position,now)
 if kind=='launch' then
  soundscape:play('laser_start',position)
  presentation:kick(position,.028,now)
 end
end
local pickupView=PickupView.new(world,localFX,soundscape)
local roleEffectView=RoleEffectView.new()
local previousShake=CFrame.new();local shakeCamera=nil
local orbitalBurns={};local roleAudio={};local impactCues=setmetatable({},{__mode='k'});local burnShakeAt=0
RunService:BindToRenderStep('MiningAwayCameraRestore',Enum.RenderPriority.Camera.Value-1,function()
 if shakeCamera and workspace.CurrentCamera==shakeCamera then shakeCamera.CFrame=shakeCamera.CFrame*previousShake:Inverse() end
 previousShake=CFrame.new();shakeCamera=nil
end)
RunService:BindToRenderStep('MiningAwayCameraFeedback',Enum.RenderPriority.Camera.Value+1,function()
 local camera=workspace.CurrentCamera
 local now=workspace:GetServerTimeNow()
 for source,name in pairs(roleAudio) do
  if not source.Parent or now>(source:GetAttribute('AudioUntil') or 0) then soundscape:stopLoop(source);roleAudio[source]=nil
  else
   local progress=math.clamp((now-(source:GetAttribute('AudioAt') or now))/1.4,0,1)
   soundscape:setLoop(source,name,source.Position,.65+.35*progress,.75+.55*progress)
  end
 end
 for source,record in pairs(orbitalBurns) do
  if not source.Parent then soundscape:stopLoop(source);record.connection:Disconnect();orbitalBurns[source]=nil
  else
   local ended=source:GetAttribute('EndedAt')~=nil
   local active=not ended and now-(source:GetAttribute('ContactAt') or 0)<.3
   if active then soundscape:setLoop(source,'orbital_hum',source:GetAttribute('Position'),1,1)
   else soundscape:stopLoop(source) end
   local visibility=ended and 'fading' or active and 'active' or 'stale'
   if record.visibility~=visibility then
    record.visibility=visibility
    for _,part in ipairs(record.effects) do
     if part:IsA('BasePart') then part.LocalTransparencyModifier=(ended or active) and 0 or 1
     elseif part:IsA('ParticleEmitter') then part.Enabled=active end
    end
   end
   if active and now>=burnShakeAt then
    presentation:kick(source:GetAttribute('Position') or Vector3.zero,.13,now)
   end
  end
 end
 if now>=burnShakeAt then burnShakeAt=now+.075 end
 if camera and player:GetAttribute('ReducedMotion')~=true and player:GetAttribute('MA_ReducedMotion')~=true then
  previousShake=presentation:cameraOffset(workspace:GetServerTimeNow());shakeCamera=camera;camera.CFrame=camera.CFrame*previousShake
 end
end)
local function roleImpact(source)
 if source:IsA('BasePart') then
  local at=source:GetAttribute('AudioAt');local now=workspace:GetServerTimeNow()
  local loop=source:GetAttribute('AudioLoop')
  if (loop=='orbital_charge' or loop=='swarm_charge') and AudioFeedback.fresh(at,now,2.6) then roleAudio[source]=loop end
  local cue=source:GetAttribute('AudioCue')
  if cue=='plant' and AudioFeedback.fresh(at,now,.35) then soundscape:play(cue,source.Position) end
 end
 if source:IsA('Folder') and source:GetAttribute('OrbitalBurn') then
  if orbitalBurns[source] then return end
  local record={effects={}}
  local function track(part)
   if part:IsA('BasePart') or part:IsA('ParticleEmitter') then table.insert(record.effects,part);record.visibility=nil end
  end
  for _,part in ipairs(source:GetDescendants()) do track(part) end
  record.connection=source.DescendantAdded:Connect(track)
  orbitalBurns[source]=record
  if AudioFeedback.fresh(source:GetAttribute('ContactAt'),workspace:GetServerTimeNow(),.35) then soundscape:play('orbital',source:GetAttribute('Position')) end
 end
 if source:IsA('BasePart') and source:GetAttribute('MiningImpact') then
  local now=workspace:GetServerTimeNow();local at=source:GetAttribute('ImpactAt') or 0
  if now>=at and now-at<=.35 and not impactCues[source] then
   impactCues[source]=true
   local impact=source:GetAttribute('MiningImpact')
   if impact=='BreakerContact' then
    presentation:kick(source.Position,.09,now)
    soundscape:play('breaker_contact',source.Position)
   else
    presentation:kick(source.Position,impact=='Orbital' and .15 or .14,now)
    soundscape:play(impact=='Orbital' and 'orbital' or impact=='Breaker' and 'breaker_fracture' or 'mining',source.Position)
   end
  end
 end
end
local impactConnection=workspace.DescendantAdded:Connect(function(source)
 -- Cosmetic parts are parented beneath this local container; none carry
 -- authoritative role events. Do not schedule a task for every lens fragment.
 if source:IsDescendantOf(localFX) then return end
 if source:IsA('BasePart') or source:IsA('Folder') then task.defer(roleImpact,source) end
end)
local existingRoleFX=workspace:FindFirstChild('DroneRoleClientEffects')
if existingRoleFX then for _,source in ipairs(existingRoleFX:GetChildren()) do roleImpact(source) end end

local drones,resources,resourceIndex,turrets,connections={},{},{},{},{}
local droneIndex={}
local turretIndex={}
local hiddenParts={}
local pendingDroneSources={}
local templateRetryQueued=false
local profile=nil
local logisticsView=nil
local toolView=nil
local U=Interface
local palette=U.palette
local DroneConfig=require(RS:WaitForChild('Shared'):WaitForChild('DroneConfig'))
local TacticalHUD=require(RS.Shared:WaitForChild('TacticalHUD'))
local colors={Blue=Color3.fromRGB(99,198,246),Red=Color3.fromRGB(243,117,112),Green=Color3.fromRGB(122,219,163),Dart=Color3.fromRGB(87,220,255),Striker=Color3.fromRGB(255,210,86),Medic=Color3.fromRGB(99,255,164),Charger=Color3.fromRGB(255,112,72)}
for _,name in ipairs(DroneConfig.TypeOrder) do colors[name]=DroneConfig.Types[name].Color end
local gui=Instance.new('ScreenGui');gui.Name='MiningAwayHUD';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=12;gui.Parent=player:WaitForChild('PlayerGui')
soundscape:bindUI(gui)
local safeRoot=U.frame(gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1));safeRoot.Name='SafeContent';safeRoot.BackgroundTransparency=1
local historical={ScreenGui=true,IngameGui=true,lowPolyUI=true}
local function isolate(g) if g:IsA('ScreenGui') and historical[g.Name] then g.Enabled=false end end
for _,g in ipairs(gui.Parent:GetChildren()) do isolate(g) end
local function connect(signal,callback) local c=signal:Connect(callback);table.insert(connections,c);return c end
connect(gui.Parent.ChildAdded,isolate)
local function restoreCamera(ch)
 local hum=ch:WaitForChild('Humanoid',10)
 if hum and workspace.CurrentCamera then workspace.CurrentCamera.CameraType=Enum.CameraType.Custom;workspace.CurrentCamera.CameraSubject=hum end
end
connect(player.CharacterAdded,restoreCamera);if player.Character then task.spawn(restoreCamera,player.Character) end
local frame,label,corner=U.frame,U.text,U.corner
local function button(parent,pos,size,text,callback,color)
 local b=U.button(parent,pos,size,text,function() soundscape:play('click');if callback then callback() end end,color)
 b:SetAttribute('EnabledColor',color or palette.mineral);return b
end
local function enableAction(b,enabled) U.setEnabled(b,enabled) end
local openOffer,openPack,openPrestige,openFleet,openRunCards,openShop,openStars
local activeShop='Quartz'
local noticeUntil=0
local menuStation=nil
local hud=U.panel(safeRoot,UDim2.fromOffset(16,12),UDim2.fromOffset(290,64));hud.Name='Resources';hud.Active=true
local saveLabel=label(safeRoot,UDim2.new(1,-188,0,12),UDim2.fromOffset(172,22),'',16,palette.muted,true);saveLabel.Name='SaveStatus';saveLabel.Visible=false;saveLabel.TextXAlignment=Enum.TextXAlignment.Right
local cargoText=label(hud,UDim2.fromOffset(50,34),UDim2.new(1,-158,0,18),'Backpack 0 / 40',11,palette.muted,true)
local cargoTrack=frame(hud,UDim2.fromOffset(50,53),UDim2.new(1,-164,0,4),palette.paper);corner(cargoTrack,2)
local cargoFill=frame(cargoTrack,UDim2.fromScale(0,0),UDim2.fromScale(0,1),palette.mineral);corner(cargoFill,3)
local toast=U.panel(safeRoot,UDim2.fromOffset(0,170),UDim2.fromOffset(420,50),palette.panel,12);toast.Name='Feedback';toast.ZIndex=80;toast.Visible=false
local notice=label(toast,UDim2.fromOffset(14,6),UDim2.new(1,-28,1,-12),'',13,palette.text,true);notice.TextXAlignment=Enum.TextXAlignment.Center
local recall=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(118,44),'Recall [R]',function() if not (logisticsView and logisticsView:recall()) then command:FireServer('Recall') end end,Color3.fromRGB(66,177,91));recall.Name='Recall'
local context=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(420,72),palette.panel,14);context.Name='ContextAction';context.Active=true;context.Visible=false
local modal=frame(safeRoot,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(3,9,18));modal.Name='MenuLayer';modal.BackgroundTransparency=.22;modal.Visible=false;modal.ZIndex=20;modal.Active=true
local function menusVisible() return modal.Visible or (logisticsView and logisticsView:isOpen()) end
local selectorView=SelectorView.new({world=world,player=player,parent=localFX,command=command,profile=function() return profile end,
 hidden=function() return menusVisible() or (logisticsView and logisticsView.selected~=nil) or (toolView and toolView:selected()~=nil) end})
local sheet=U.panel(modal,UDim2.fromOffset(12,12),UDim2.fromOffset(1010,664),palette.panel,20);sheet.Name='MenuSheet';sheet.ZIndex=21
local sheetScale=Instance.new('UIScale');sheetScale.Parent=sheet
local modalEmblem=U.icon(sheet,'cards',UDim2.fromOffset(20,19),UDim2.fromOffset(54,54),palette.mineral)
local modalTitle=label(sheet,UDim2.fromOffset(90,18),UDim2.new(1,-158,0,39),'Build your next adventure',30,palette.text,true)
local modalSubtitle=label(sheet,UDim2.fromOffset(24,66),UDim2.new(1,-48,0,32),'',12,palette.muted)
local close=button(sheet,UDim2.new(1,-62,0,16),UDim2.fromOffset(44,44),'X',function() modal.Visible=false end,palette.danger);close.Name='CloseMenu';close.TextColor3=palette.white;close:FindFirstChildOfClass('UIGradient').Enabled=true
local body=Instance.new('ScrollingFrame');body.Name='MenuContent';body.Position=UDim2.fromOffset(24,112);body.Size=UDim2.new(1,-48,1,-136);body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=4;body.ScrollBarImageColor3=palette.muted;body.CanvasSize=UDim2.fromScale(0,0);body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.ZIndex=22;body.Parent=sheet
-- Native touch controls otherwise draw over the physical offer surface.
local previousTouchEnabled=nil
local function syncModalTouch()
 local controls=player.PlayerGui:FindFirstChild('TouchGui');if not controls then return end
 if menusVisible() then if previousTouchEnabled==nil then previousTouchEnabled=controls.Enabled end;controls.Enabled=false
 elseif previousTouchEnabled~=nil then controls.Enabled=previousTouchEnabled;previousTouchEnabled=nil end
end
connect(modal:GetPropertyChangedSignal('Visible'),syncModalTouch)
connect(player.PlayerGui.ChildAdded,function(child) if child.Name=='TouchGui' then syncModalTouch() end end)
local modalMode,modalSize=nil,nil
local actionPending=nil
local offerViews={};local offerIdentity=nil;local offerRenderSize=nil;local presentedOfferId=nil
local function clearBody() table.clear(offerViews);offerIdentity=nil;offerRenderSize=nil; for _,x in ipairs(body:GetChildren()) do x:Destroy() end;body.CanvasPosition=Vector2.zero end
local function tx() return Http:GenerateGUID(false) end
local function send(action,data)
 if not profile or not profile.run or actionPending or profile.pendingTransaction then return false end
 data=data or {};data.txId=tx();data.runId=profile.run.id
 actionPending={kind=action,at=os.clock(),runId=profile.run.id,packIndex=profile.run.packIndex,offerId=profile.run.pendingOffer and profile.run.pendingOffer.id,upgradeId=data.upgradeId,level=data.level,index=data.index}
 command:FireServer(action,data);return true
end
local function comma(n) local s=tostring(math.floor(tonumber(n) or 0));local r=s:reverse():gsub('(%d%d%d)','%1,'):reverse();return (r:gsub('^,','')) end
local function cargoUnits(p)
 local published=tonumber(p.cargoUnits);if published then return math.max(0,published) end
 local n=0;local run=p.run or {}
 local function add(cargo) for _,v in pairs(cargo or {}) do if type(v)=='number' then n=n+v end end end
 add(run.cargo)
 return n
end
local function pending() return profile and profile.run and profile.run.pendingOffer end
local packView=PackView.new({
 player=player,world=world,parent=localFX,interface=U,command=command,audio=soundscape,droneConfig=DroneConfig,
 hidden=menusVisible,busy=function() return not profile or profile.pendingTransaction or player:GetAttribute('MA_InAssault') end,
})
connect(modal:GetPropertyChangedSignal('Visible'),function() packView:setFocus(modal.Visible and modalMode=='offer') end)
connect(RunService.RenderStepped,function() packView:update(workspace:GetServerTimeNow()) end)
local function sealedPack()
 local offer=pending()
 return offer and offer.opened==false
end
local function fieldUnlocked(field)
 return profile and type(profile.clearedFields)=='table' and field and profile.clearedFields[field.Name]==true or false
end
local function viewport()
 local size=safeRoot.AbsoluteSize
 if size.X>1 and size.Y>1 then return size end
 local camera=workspace.CurrentCamera;return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function currentLayout() local v=viewport();return UILayout.calculate(v.X,v.Y,UIS.TouchEnabled and not UIS.KeyboardEnabled) end
local function layoutModal()
 local v=viewport();local l=currentLayout()
 if l.short then l.headerHeight=64;l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-l.panelPadding) end
 if modalMode=='shop' then
  l.panelWidth=math.min(740,v.X-24);l.panelHeight=math.min(650,v.Y-24);l.panelPadding=16;l.headerHeight=l.short and 64 or 100
  l.bodyWidth=l.panelWidth-32;l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-16);l.panelX=(v.X-l.panelWidth)/2;l.panelY=(v.Y-l.panelHeight)/2
 end
 if modalMode=='pack' then
  l.panelWidth=math.min(380,l.panelWidth);l.panelHeight=math.min(l.short and 132 or 166,l.panelHeight)
  l.panelPadding=16;l.headerHeight=l.short and 66 or 94
  l.bodyWidth=l.panelWidth-32;l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-16)
  l.panelX=(v.X-l.panelWidth)/2;l.panelY=(v.Y-l.panelHeight)/2
 end
 if modalMode=='offer' and l.short then
  l.headerHeight=64;l.panelPadding=12;l.bodyWidth=l.panelWidth-24
  l.bodyHeight=l.panelHeight-l.headerHeight-l.panelPadding;l.cardHeight=math.clamp(l.bodyHeight-2,212,256)
 end
 if modalMode=='offer' and l.cardColumns==3 then
  l.panelWidth=math.min(820,v.X-24);l.panelPadding=12;l.bodyWidth=l.panelWidth-24
  l.cardWidth=(l.bodyWidth-l.cardGap*2)/3;l.headerHeight=l.short and 64 or 100
  l.panelX=(v.X-l.panelWidth)/2
  l.panelHeight=math.min(l.panelHeight,l.headerHeight+l.cardHeight+32)
  l.bodyHeight=math.max(1,l.panelHeight-l.headerHeight-l.panelPadding)
  l.panelY=math.floor((v.Y-l.panelHeight)*.65)
 end
 sheet.Size=UDim2.fromOffset(l.panelWidth,l.panelHeight);sheet.Position=UDim2.fromOffset(l.panelX,l.panelY);modalSize=v
 body.Position=UDim2.fromOffset(l.panelPadding,l.headerHeight);body.Size=UDim2.fromOffset(l.bodyWidth,l.bodyHeight)
 modalTitle.TextSize=l.panelWidth<400 and 23 or 30
 modalTitle.Position=UDim2.fromOffset(l.panelWidth<400 and 74 or 90,16)
 modalTitle.Size=UDim2.new(1,l.panelWidth<400 and -136 or -158,0,43)
 modalEmblem.Size=UDim2.fromOffset(l.panelWidth<400 and 42 or 54,l.panelWidth<400 and 42 or 54)
 modalEmblem.Position=UDim2.fromOffset(18,18)
 modalSubtitle.Position=UDim2.fromOffset(l.panelPadding,l.short and 58 or 66)
 modalSubtitle.Size=UDim2.new(1,-l.panelPadding*2,0,l.short and 29 or 32)
 if l.short then
  modalEmblem.Size=UDim2.fromOffset(38,38);modalEmblem.Position=UDim2.fromOffset(18,10)
  local textX=l.panelWidth<400 and 74 or 90
  modalTitle.Position=UDim2.fromOffset(textX,6);modalTitle.Size=UDim2.new(1,l.panelWidth<400 and -136 or -158,0,32);modalTitle.TextSize=23
  modalSubtitle.Position=UDim2.fromOffset(textX,37);modalSubtitle.Size=UDim2.new(1,-textX-60,0,23)
 end
 return l
end
local menuTween=nil
local normalSubtitle=''
local function menu(mode,title,subtitle,icon)
 local entering=not modal.Visible or modalMode~=mode
 modalMode=mode;sheet:SetAttribute('MenuMode',mode);clearBody();local l=layoutModal();modalTitle.Text=title;modalSubtitle.Text=subtitle;normalSubtitle=subtitle
 if mode~='shop' then U.skin(sheet,palette.panel,20);U.skin(close,palette.danger,11) end
 local inOffer=mode=='offer';modal.BackgroundTransparency=inOffer and 1 or .22;sheet.BackgroundTransparency=inOffer and 1 or 0
 local colorful=true
 local texture=sheet:FindFirstChild('StudSurface');if texture then texture.Visible=not inOffer end
 body.ScrollBarThickness=inOffer and 0 or 4
 modalTitle.Visible=not inOffer
 modalSubtitle.TextXAlignment=inOffer and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
 close.BackgroundTransparency=inOffer and 1 or 0
 local closeEdge=close:FindFirstChildOfClass('UIStroke');if closeEdge then closeEdge.Enabled=not inOffer end
 close.TextStrokeTransparency=inOffer and .4 or 1
 modalTitle.TextColor3=colorful and palette.white or palette.text;modalTitle.TextStrokeColor3=Color3.fromRGB(13,23,48);modalTitle.TextStrokeTransparency=colorful and .4 or 1
 modalSubtitle.TextColor3=inOffer and Color3.fromRGB(215,240,255) or palette.muted
 sheet.BackgroundColor3=palette.panel
 local rounded=sheet:FindFirstChildOfClass('UICorner');if rounded then rounded.CornerRadius=UDim.new(0,inOffer and 28 or 20) end
 local border=sheet:FindFirstChildOfClass('UIStroke');if border then border.Transparency=inOffer and 1 or 0;border.Color=inOffer and Color3.fromRGB(6,8,17) or palette.ink;border.Thickness=inOffer and 5 or 2 end
 if l.panelWidth<400 then
  local shortTitles={shop='Quartz Workshop',pack='Pack shop',offer='Pick a card',fleet='Your crew',run='Run upgrades',prestige='Grow your fleet'}
  modalTitle.Text=shortTitles[mode] or title;modalTitle.TextSize=mode=='prestige' and 18 or 20
 end
 if modalEmblem then modalEmblem:Destroy() end
 modalEmblem=U.icon(sheet,icon,UDim2.fromOffset(18,l.short and 10 or 18),UDim2.fromOffset(l.short and 38 or l.panelWidth<400 and 42 or 54,l.short and 38 or l.panelWidth<400 and 42 or 54),colorful and Color3.fromRGB(255,210,85) or palette.mineral)
 local titles={shop='QUARTZ WORKSHOP',pack='PACK SHOP',offer='PICK A CARD',fleet='YOUR FLEET',run='RUN UPGRADES',prestige='GROW YOUR FLEET'};modalTitle.Text=titles[mode] or title
 if colorful then modalTitle.Font=Enum.Font.Arcade;modalTitle.TextColor3=palette.white;modalTitle.TextStrokeTransparency=.45;modalSubtitle.TextColor3=Color3.fromRGB(202,209,231) else modalTitle.Font=Enum.Font.SourceSansBold end
 modalEmblem.Visible=not inOffer
 if inOffer then
  modalSubtitle.Position=UDim2.fromOffset(52,l.headerHeight-37)
  modalSubtitle.Size=UDim2.new(1,-104,0,27);modalSubtitle.TextSize=17
 else modalSubtitle.TextSize=12 end
 if mode=='shop' or mode=='stars' then
  ShopView.decorate(U,sheet,modalTitle,modalSubtitle,close);body.ScrollBarImageColor3=Color3.fromRGB(29,132,211)
  if mode=='stars' then modalTitle.Text='Star Shop';modalTitle.TextColor3=Color3.fromRGB(139,91,17) end
 end
 modal.Visible=true
 packView:setFocus(inOffer)
 if entering then
  if menuTween then menuTween:Cancel() end
  sheetScale.Scale=.98;menuTween=TweenService:Create(sheetScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1});menuTween:Play()
 end
 return l
end
local function atHomeUI()
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart');local spawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
 local hub=world.Map:FindFirstChild('HubPad',true)
 local depot=world:GetAttribute('DepotHome') or (hub and hub.Position) or (spawn and spawn.Position)
 return hr and depot and (hr.Position-depot).Magnitude<30
end
local function availability(action)
 if not profile then return false,'Connecting…' end
 if actionPending or profile.pendingTransaction then return false,'Waiting for confirmation…' end
 if player:GetAttribute('MA_InAssault') then return false,'Recall your fighting drones first' end
 if action=='BuyUpgrade' or action=='BuyStarUpgrade' or action=='BuyPack' or action=='Prestige' then
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  for _,name in ipairs(action=='Prestige' and {'PackStation','QuartzShop','PrestigeStation'} or {'PackStation','QuartzShop'}) do
   local station=world.Map:FindFirstChild(name,true)
   if station and hr and (station.Position-hr.Position).Magnitude<20 then return true,'' end
  end
  return false,'Visit the Quartz Workshop'
 end
 local packStation=world.Map:FindFirstChild('PackStation',true)
 local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local quartz=world.Map:FindFirstChild('QuartzShop',true)
 local nearPack=hr and ((packStation and (hr.Position-packStation.Position).Magnitude<24) or (quartz and (hr.Position-quartz.Position).Magnitude<20))
 if action~='Prestige' and not atHomeUI() and not ((action=='BuyPack' or action=='ChooseCard') and nearPack) then return false,'Return to the depot' end
 local stationName=action=='BuyPack' and 'PackStation' or action=='Prestige' and 'PrestigeStation' or nil
 if stationName then
  local station=world.Map:FindFirstChild(stationName,true)
  local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  if not station or not hr or (hr.Position-station.Position).Magnitude>=20 then return false,action=='BuyPack' and 'Visit the Quartz Workshop' or 'Visit the fleet uplink to prestige' end
 end
 return true,''
end
local function canAct(action) return availability(action or 'ChooseCard') end
local function number(n)
 if math.abs(n)>=1000 then return comma(n) end
 if math.abs(n-math.floor(n+.5))<.001 then return tostring(math.floor(n+.5)) end
 return string.format('%.3g',n)
end
local function targetText(choice)
 if choice.cardId=='A02' then return 'YOUR COURIERS' end
 if choice.scope=='Individual' then return 'ONE DRONE / '..(choice.targetName or 'Assigned drone') end
 if choice.scope=='Color' then return 'ALL '..string.upper(choice.type or '')..' DRONES' end
 return choice.scope=='Player' and 'YOUR BACKPACK' or 'ENTIRE FLEET'
end
local function progress(parent,y,width,title,detail,fraction,color,dark)
 label(parent,UDim2.fromOffset(0,y),UDim2.fromOffset(width,22),title,17,dark and palette.white or palette.text,true)
 label(parent,UDim2.fromOffset(0,y+27),UDim2.fromOffset(width,27),detail,12,dark and Color3.fromRGB(202,209,231) or palette.muted)
 local track=frame(parent,UDim2.fromOffset(0,y+62),UDim2.fromOffset(width,10),palette.paper);track.ClipsDescendants=true;corner(track,3)
 local fill=frame(track,UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(fraction,0,1),1),color);corner(fill,3)
end
local function updateOfferControls()
 local usable,reason=availability('ChooseCard')
 local choosing=actionPending and actionPending.kind=='ChooseCard'
 normalSubtitle=choosing and 'Applying card…' or (not usable and reason or 'This run only')
 for index,view in ipairs(offerViews) do
  enableAction(view.button,usable)
  local text=choosing and (actionPending.index==index and 'Installing…' or 'Please wait') or ''
  if view.button.Text~=text then view.button.Text=text end
 end
end
openOffer=function()
 local offer=pending();if not offer then return end
 if offer.opened==false then
  modal.Visible=false;modalMode=nil
  return
 end
 local size=viewport()
 if modal.Visible and modalMode=='offer' and offerIdentity==offer.id and offerRenderSize and (offerRenderSize-size).Magnitude<1 then updateOfferControls();return end
 local skipReveal=presentedOfferId==offer.id
 local origin
 local camera=workspace.CurrentCamera
 local worldOrigin=not skipReveal and packView:origin(offer.id)
 if camera and worldOrigin then
  local screen,visible=camera:WorldToScreenPoint(worldOrigin)
  if visible then origin=Vector2.new(screen.X,screen.Y) end
 end
 local stars=offer.packTier or 1
 local l=menu('offer','PICK AN UPGRADE','Choose one upgrade · +'..stars..(stars==1 and ' Star' or ' Stars'),'cards')
 offerIdentity=offer.id;offerRenderSize=size;presentedOfferId=offer.id
 local list=Instance.new('UIListLayout');list.FillDirection=l.cardColumns==3 and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical;list.Padding=UDim.new(0,l.cardGap);list.HorizontalAlignment=Enum.HorizontalAlignment.Center;list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 for index,choice in ipairs(offer.choices) do
  local view=CardView.create(U,body,choice,index,l.cardColumns==3 and l.cardWidth-4 or math.min(460,l.cardWidth-6),l.cardHeight,{skipReveal=skipReveal,revealSpeed=profile.packSpeed or 1,origin=origin,target=targetText(choice),onChoose=function()
   if not pending() or pending().id~=offer.id or not canAct() then return end
   if send('ChooseCard',{offerId=offer.id,index=index}) then updateOfferControls() end
  end})
  offerViews[index]=view
 end
 updateOfferControls()
end
openPack=function()
 openShop('Quartz')
end
openShop=function(_key)
 if not profile or not profile.run.wallet then return end
 activeShop='Quartz'
 local allowed,reason=availability('BuyUpgrade')
 local l=menu('shop','Quartz Workshop',comma(Shops.balance(profile,'Quartz'))..' Quartz · Duplicates stack'..(allowed and '' or ' · '..reason),'crystal')
 ShopView.render(U,body,{profile=profile,shop='Quartz',width=l.bodyWidth-4,canBuy=allowed,
  onPack=function()
   if pending() then
    if sealedPack() then modal.Visible=false;modalMode=nil;notice.Text='Hold E on your delivered crate.';noticeUntil=os.clock()+4 else openOffer() end
   elseif canAct('BuyPack') and send('BuyPack',{packIndex=profile.run.packIndex}) then modal.Visible=false;modalMode=nil end
  end,
  onBuy=function(c,level)
   if canAct('BuyUpgrade') and send('BuyUpgrade',{upgradeId=c.cardId,level=level}) then openShop('Quartz') end
  end,onPrestige=function() openPrestige() end,onStars=function() openStars() end})
end
openStars=function()
 if not profile then return end
 local allowed,reason=availability('BuyStarUpgrade')
 local l=menu('stars','Star Shop',comma(profile.run.stars or 0)..' Stars · Resets on prestige'..(allowed and '' or ' · '..reason),'cards')
 ShopView.renderStars(U,body,{profile=profile,width=l.bodyWidth-4,canBuy=allowed,
  onBack=function() openShop('Quartz') end,onBuy=function(id,level)
   if canAct('BuyStarUpgrade') and send('BuyStarUpgrade',{upgradeId=id,level=level}) then openStars() end
  end})
end
local function statTile(parent,x,y,width,title,value,color)
 local tile=frame(parent,UDim2.fromOffset(x,y),UDim2.fromOffset(width,55),palette.panel);tile.BackgroundTransparency=1
 label(tile,UDim2.fromOffset(10,5),UDim2.new(1,-20,0,15),title,14,palette.muted,true)
 label(tile,UDim2.fromOffset(10,24),UDim2.new(1,-20,0,26),value,20,color or palette.text,true)
end
local function tabs(width,mode)
 local a=button(body,UDim2.fromOffset(3,3),UDim2.fromOffset((width-14)/2,44),'Permanent fleet',openFleet,mode=='fleet' and palette.mineral or palette.paper)
 local b=button(body,UDim2.fromOffset((width-14)/2+11,3),UDim2.fromOffset((width-14)/2,44),'This run · '..#profile.run.cards,openRunCards,mode=='run' and palette.accent or palette.paper)
 a.Name='FleetTab';b.Name='RunTab'
end
openFleet=function()
 if not profile then return end
 local crew=profile.activeFleet or profile.fleet
 local l=menu('fleet','Meet your crew',profile.activeFleet and ('Studio role test · '..#crew..' active drones · '..#profile.fleet..' permanent owned') or 'Your drones stay with you. Run upgrades change the stats below.','drone');local width=l.bodyWidth-6
 tabs(width,'fleet')
 local rosterY=64
 if player:GetAttribute('MA_TestingEnabled')==true then
  local half=(width-12)/2
  local reroll=button(body,UDim2.fromOffset(3,57),UDim2.fromOffset(half,44),'Random 2–5 [T]',function() command:FireServer('TestLoadout');modal.Visible=false end,palette.paper)
  reroll.Name='RerollTestCrew'
  local roles=button(body,UDim2.fromOffset(half+15,57),UDim2.fromOffset(half,44),profile.activeFleet and 'Permanent fleet' or 'All drone types',function() command:FireServer(profile.activeFleet and 'NormalLoadout' or 'RoleLoadout');modal.Visible=false end,palette.mineral);roles.Name='RestoreRoleCrew'
  if player:GetAttribute('MA_DevToolsEnabled')==true then
  local fill=button(body,UDim2.fromOffset(3,109),UDim2.fromOffset(width,40),'Fill backpack',function() command:FireServer('DevFillBag');modal.Visible=false end,palette.accent)
  fill.Name='DevFillBag'
  local choices={{'Striker','+ Miner'},{'Courier','+ Courier'},{'Medic','+ Healer'},{'Dart','+ Grower'},{'Charger','+ Smasher'},{'Orbiter','+ Orbital'},{'Scrapper','+ Swarm'}}
  local columns=width>=560 and 4 or 2;local gap=8;local cell=(width-gap*(columns-1))/columns
  for index,choice in ipairs(choices) do
   local b=button(body,UDim2.fromOffset(3+((index-1)%columns)*(cell+gap),157+math.floor((index-1)/columns)*46),UDim2.fromOffset(cell,38),choice[2],function()
    command:FireServer('DevAddDrone',{role=choice[1]});modal.Visible=false
   end,colors[choice[1]] or palette.paper)
   b.Name='DevAdd'..choice[1]
  end
  rosterY=157+math.ceil(#choices/columns)*46+10
  else rosterY=114 end
 end
 local columns=width>=650 and 2 or 1;local gap=14;local rowWidth=(width-gap*(columns-1))/columns
 for index,d in ipairs(crew or {}) do
  local stats=(profile.droneStats and profile.droneStats[d.id]) or d.effective or d.base or {}
  local x=((index-1)%columns)*(rowWidth+gap)+3;local y=rosterY+math.floor((index-1)/columns)*276
  local tint=colors[d.type] or palette.mineral
  local row=U.panel(body,UDim2.fromOffset(x,y),UDim2.fromOffset(rowWidth,258),tint:Lerp(palette.panel,.36),14);row.Name='FleetDrone'..index
  U.icon(row,'drone',UDim2.fromOffset(13,14),UDim2.fromOffset(62,62),tint)
  label(row,UDim2.fromOffset(87,14),UDim2.new(1,-102,0,33),d.name or ('Drone '..index),24,palette.text,true)
  local identity=label(row,UDim2.fromOffset(87,50),UDim2.new(1,-102,0,24),(profile.activeFleet and 'Test · ' or '')..(d.role or d.type or 'Blue'),16,palette.muted,true)
  local count=0;for _,c in ipairs(profile.run.cards) do if c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Color' and c.type==d.type) or (c.scope=='Individual' and c.targetDroneId==d.id) then count=count+1 end end
  identity.Text=identity.Text..' · '..tostring(count)..' upgrades'
  local tileWidth=(rowWidth-42)/2
  local role=(profile.droneRoles and profile.droneRoles[d.id]) or d.role or d.type
  if role=='Medic' then
   statTile(row,14,91,tileWidth,'REPAIR',tostring(DroneConfig.Types.Medic.HealAmount)..' health')
   statTile(row,tileWidth+28,91,tileWidth,'INTERVAL',tostring(DroneConfig.Types.Medic.AttackCooldown)..' sec')
  elseif role=='Courier' then
   statTile(row,14,91,tileWidth,'PARCEL',tostring(DroneConfig.Courier.BatchUnits)..' ore')
   statTile(row,tileWidth+28,91,tileWidth,'JOB','Haul to storage')
  elseif role=='Dart' then
   statTile(row,14,91,tileWidth,'JOB','Grow rocks')
   statTile(row,tileWidth+28,91,tileWidth,'COOLDOWN',number(stats.growCooldown or 5)..' sec')
  elseif role=='Charger' then
   statTile(row,14,91,tileWidth,'JOB','Dive + impact')
   statTile(row,tileWidth+28,91,tileWidth,'IMPACT',number((stats.miningDPS or 30)*2.4)..' base')
  elseif role=='Orbiter' then
   statTile(row,14,91,tileWidth,'JOB','Orbital strike')
   statTile(row,tileWidth+28,91,tileWidth,'CYCLE','45s cooldown')
  elseif role=='Scrapper' then
   statTile(row,14,91,tileWidth,'JOB','Launch bots')
   statTile(row,tileWidth+28,91,tileWidth,'SWARM','10 seconds')
  elseif DroneCatalog.Types[role] then
   local entry=DroneCatalog.Types[role]
   statTile(row,14,91,tileWidth,'CYCLE',number(entry.Duration)..' sec')
   statTile(row,tileWidth+28,91,tileWidth,'RECOVERY',number(entry.Yield or 1)..'× ore')
  else
   statTile(row,14,91,tileWidth,'MINING',number(stats.miningDPS or 30)..' /s')
   statTile(row,tileWidth+28,91,tileWidth,'COMBAT',number(stats.combatDPS or 12)..' /s')
  end
  statTile(row,14,153,tileWidth,'MAX HULL',number(stats.maxHealth or 80))
  statTile(row,tileWidth+28,153,tileWidth,'FLIGHT',number((stats.maxStep60 or .35)*60)..' studs/s')
  label(row,UDim2.fromOffset(15,211),UDim2.new(1,-30,0,40),DroneCatalog.Types[role] and DroneCatalog.Types[role].Description or Mining.description(role),16,palette.muted)
 end
 local audioY=rosterY+math.ceil(#crew/columns)*276
 local music=button(body,UDim2.fromOffset(3,audioY),UDim2.fromOffset((width-12)/2,44),soundscape.musicMuted and 'Music: off' or 'Music: on',function() soundscape:toggleMusic();openFleet() end,palette.paper)
 music.Name='ToggleMusic'
 local effects=button(body,UDim2.fromOffset((width-12)/2+15,audioY),UDim2.fromOffset((width-12)/2,44),soundscape.effectsMuted and 'Effects: off' or 'Effects: on',function() soundscape:toggleEffects();openFleet() end,palette.paper)
 effects.Name='ToggleEffects'
end
openRunCards=function()
 if not profile then return end
 local l=menu('run','Your current build','Your upgrades stack together until prestige. Find more in packs or buy another stack.','cards');local width=l.bodyWidth-6
 tabs(width,'run')
 if #profile.run.cards==0 then
  U.icon(body,'cards',UDim2.fromOffset(math.max(0,(width-90)/2),84),UDim2.fromOffset(90,90),palette.mineral)
  local title=label(body,UDim2.fromOffset(6,196),UDim2.fromOffset(width-12,38),'Your first upgrade is waiting',26,palette.text,true);title.TextXAlignment=Enum.TextXAlignment.Center
  local detail=label(body,UDim2.fromOffset(12,247),UDim2.fromOffset(width-24,64),'Mine Quartz and sell it at SELL ORE. Open a pack and pick an upgrade. Find it again or buy another stack to make it stronger.',14,palette.muted);detail.TextXAlignment=Enum.TextXAlignment.Center
  label(body,UDim2.fromOffset(6,334),UDim2.fromOffset(width-12,30),'Visit the Quartz Workshop',16,palette.muted)
 else
  for index,c in ipairs(profile.run.cards) do
   local y=63+(index-1)*145
   local _,tint=CardView.identity(c)
   local row=U.panel(body,UDim2.fromOffset(3,y),UDim2.fromOffset(width,130),tint:Lerp(palette.panel,.42),12)
   label(row,UDim2.fromOffset(16,12),UDim2.new(1,-32,0,55),CardView.summary(c),22,palette.text,true)
   label(row,UDim2.fromOffset(16,72),UDim2.new(1,-32,0,46),CardView.terms(c,targetText(c)),16,palette.muted)
  end
 end
end
openPrestige=function()
 if not profile then return end
 local l=menu('prestige','Prestige: a stronger new run','Keep every drone. Gain permanent mining power. Restart your upgrades.','prestige');local width=l.bodyWidth-6
 local narrow=width<400
 local pre=profile.prestigePreview or {};local before=pre.fleetBefore or #profile.fleet;local after=pre.fleetAfter or before+1
 local hero=U.panel(body,UDim2.fromOffset(3,3),UDim2.fromOffset(width,118),palette.accent:Lerp(palette.panel,.26),16)
 U.icon(hero,'drone',UDim2.fromOffset(18,25),UDim2.fromOffset(narrow and 48 or 62,narrow and 48 or 62),colors[pre.newType] or palette.mineral)
 label(hero,UDim2.fromOffset(narrow and 80 or 98,16),UDim2.new(1,narrow and -96 or -116,0,43),before..' → '..after..(narrow and ' drones' or ' permanent drones'),narrow and 21 or 30,palette.text,true)
 label(hero,UDim2.fromOffset(narrow and 18 or 98,narrow and 78 or 66),UDim2.new(1,narrow and -36 or -116,0,32),('+1 '..(pre.newRole or pre.newType or 'new')..' drone · permanent mining bonus\n+'..math.floor((pre.miningBonusBefore or 0)*100)..'% → +'..math.floor((pre.miningBonusAfter or .25)*100)..'%'),12,palette.text)
 local pair=width>=560;local half=pair and (width-18)/2 or width
 local keep=U.panel(body,UDim2.fromOffset(3,141),UDim2.fromOffset(half,119),palette.mineral:Lerp(palette.panel,.34),12)
 label(keep,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,24),'YOU KEEP',17,palette.text,true)
 label(keep,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,61),'Permanent drones, traits and stored tools\nCarriers, flying backpack and loadouts\nGuard clearances and prestige mining power',12,palette.text)
 local resetY=pair and 141 or 274
 local reset=U.panel(body,UDim2.fromOffset(pair and half+21 or 3,resetY),UDim2.fromOffset(half,119),palette.danger:Lerp(palette.panel,.34),12)
 label(reset,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,24),'YOU RESET',17,palette.text,true)
 label(reset,UDim2.fromOffset(14,43),UDim2.new(1,-28,0,61),'Run cards, stacks, Stars and Star Shop upgrades\nMineral balances and all cargo\nPack prices, field access and run sales',12,palette.text)
 local y=pair and 284 or 417
 local required=pre.saleRequired or 2000;local earnings=pre.earnings or profile.run.saleEarnings or 0
 local guardRequirement=(pre.winsRequired or 1)>0 and (' · '..(pre.field or 'Cobalt')..((pre.wins or 0)>0 and ' unlocked' or ' locked')) or ''
 progress(body,y,width,'Quartz sold toward prestige',comma(earnings)..' / '..comma(required)..' Quartz sold this run'..guardRequirement,earnings/math.max(1,required),palette.accent)
 local allowed,blocked=availability('Prestige')
 local can=pre.eligible==true and not pending() and allowed
 local reason=not allowed and blocked or (pending() and 'Choose your paid pack card first' or (can and 'Prestige · +1 drone and +25% base power' or 'Complete the prestige requirements'))
 local confirm
 confirm=button(body,UDim2.fromOffset(3,y+95),UDim2.fromOffset(width,50),reason,function()
  if can and canAct('Prestige') and send('Prestige',{confirm=true}) then confirm.Text='Starting new run…';enableAction(confirm,false) end
 end,palette.accent);confirm.Name='ConfirmPrestige';enableAction(confirm,can)
 label(body,UDim2.fromOffset(8,y+160),UDim2.fromOffset(width-10,31),'This confirmation begins a new run and clears the reset items above.',11,palette.muted)
end
local refreshSerial=0
local function refreshModal()
 if not modal.Visible then return end
 local savedScroll=body.CanvasPosition;local mode=modalMode
 refreshSerial=refreshSerial+1;local serial=refreshSerial
 if mode=='offer' then if pending() then openOffer() end
 elseif mode=='shop' then openShop(activeShop)
 elseif mode=='stars' then openStars()
 elseif mode=='pack' then openPack()
 elseif mode=='prestige' then openPrestige()
 elseif mode=='fleet' then openFleet()
 elseif mode=='run' then openRunCards() end
 task.defer(function()
  RunService.Heartbeat:Wait()
  if serial==refreshSerial and modal.Visible and modalMode==mode and body.Parent then
   body.CanvasPosition=Vector2.new(0,math.min(savedScroll.Y,math.max(0,body.AbsoluteCanvasSize.Y-body.AbsoluteWindowSize.Y)))
  end
 end)
end
do
 local lastOffer=nil
 local resourceAccess=''
 local function menuContentKey(p)
  if not p or not p.run then return '' end
  local run=p.run;local values={tostring(run.id),tostring(run.packIndex or 0),tostring(p.nextPackPrice or 0),tostring(p.capacity or 0),tostring(p.pendingTransaction),#(run.cards or {})}
  for _,key in ipairs(Shops.ORDER) do table.insert(values,Shops.balance(p,key));table.insert(values,tostring(Shops.unlocked(p,key))) end
  table.insert(values,run.stars or 0)
  for _,entry in ipairs(Workshop.STAR_CATALOG) do table.insert(values,Workshop.starLevel(p,entry.id)) end
  for _,c in ipairs(run.cards) do table.insert(values,tostring(c.cardId)..'='..tostring(c.level or 0)) end
  local pre=p.prestigePreview or {}
  for _,key in ipairs({'earnings','wins','eligible','saleRequired','newType','newRole','fleetBefore','fleetAfter'}) do table.insert(values,tostring(pre[key])) end
  for i,value in ipairs(values) do values[i]=tostring(value) end
  return table.concat(values,':')
 end
 local function readProfile()
  local raw=player:GetAttribute('MA_Profile');if type(raw)~='string' then return end
  local ok,p=pcall(function() return Http:JSONDecode(raw) end);if not ok or type(p)~='table' or type(p.run)~='table' then return end
  local oldProfile=profile
  local changedRun=profile and profile.run.id~=p.run.id
  soundscape:observeProfile(oldProfile,p)
  profile=p
  local access={p.run.id}
  for _,key in ipairs(Shops.ORDER) do table.insert(access,tostring(Shops.unlocked(p,key))) end
  local accessKey=table.concat(access,':')
  if accessKey~=resourceAccess then
   resourceAccess=accessKey
   for _,record in pairs(resources) do record.dirty=true end
  end
  if actionPending then
   local offer=p.run.pendingOffer
   if changedRun or (actionPending.kind=='ChooseCard' and (not offer or offer.id~=actionPending.offerId)) or (actionPending.kind=='BuyPack' and p.run.packIndex>actionPending.packIndex) or (actionPending.kind=='BuyUpgrade' and ((Workshop.find(p,actionPending.upgradeId) or {}).level or 0)>(actionPending.level or 0)) then actionPending=nil end
   if actionPending and actionPending.kind=='BuyStarUpgrade' and Workshop.starLevel(p,actionPending.upgradeId)>actionPending.level then actionPending=nil end
  end
  if changedRun and modalMode=='prestige' then modal.Visible=false end
  local offer=pending()
  if offer and offer.opened==false and (not oldProfile or not oldProfile.run.pendingOffer or oldProfile.run.pendingOffer.id~=offer.id) then
   if modalMode=='pack' then modal.Visible=false;modalMode=nil end
  elseif offer and offer.opened~=false and offer.id~=lastOffer then lastOffer=offer.id;openOffer()
  elseif not offer and modalMode=='offer' then openShop('Quartz')
  elseif modalMode=='offer' then -- A paid offer is immutable; cargo changes must not interrupt comparisons.
   updateOfferControls()
  elseif modalMode=='fleet' or modalMode=='run' then
   local oldMilestone=oldProfile and oldProfile.prestigePreview or {}
   local milestone=p.prestigePreview or {}
   local milestoneChanged=modalMode=='fleet' and (oldMilestone.earnings~=milestone.earnings or oldMilestone.wins~=milestone.wins or oldMilestone.eligible~=milestone.eligible)
   local oldCrew=oldProfile and (oldProfile.activeFleet or oldProfile.fleet) or {};local crew=p.activeFleet or p.fleet
   local crewChanged=#oldCrew~=#crew or (crew[1] and oldCrew[1] and crew[1].id~=oldCrew[1].id)
   if not oldProfile or changedRun or crewChanged or #oldProfile.fleet~=#p.fleet or #oldProfile.run.cards~=#p.run.cards or milestoneChanged then refreshModal() end
  elseif menuContentKey(oldProfile)~=menuContentKey(p) then refreshModal() end
 end
 connect(player:GetAttributeChangedSignal('MA_Profile'),readProfile);readProfile()
end
connect(player:GetAttributeChangedSignal('MA_Notice'),function()
 notice.Text=tostring(player:GetAttribute('MA_Notice') or '');noticeUntil=os.clock()+5;actionPending=nil;refreshModal()
end)

local abilityView=AbilityView.start({interface=U,parent=safeRoot,command=command,droneConfig=DroneConfig,profile=function() return profile end,hidden=menusVisible})
local crystalAudio=require(RS.Shared:WaitForChild('CrystalAudio')).new(localFX,soundscape.effectsGroup)
local function sanitize(model)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('SurfaceGui') then v:Destroy()
  elseif v:IsA('BasePart') then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
  elseif v:IsA('Beam') or v:IsA('Trail') or v:IsA('ParticleEmitter') or v:IsA('Light') then v.Enabled=false end
 end
end
local function hidePart(part)
 if not hiddenParts[part] then hiddenParts[part]=true;part.LocalTransparencyModifier=1 end
end
local function hideModel(model)
 for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then hidePart(v) elseif v:IsA('Beam') then v.Enabled=false end end
end
local function localPart(parent,name,pos)
 local p=Instance.new('Part');p.Name=name;p.Size=Vector3.new(.05,.05,.05);p.Position=pos;p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=parent;return p
end
local function createBeam(view,emitter)
 return presentation:createMiningBeam(view,emitter)
end
local function registerDrone(source)
 if drones[source] then return true end
 if not source:IsA('Model') then return false end
 local id=source:GetAttribute('DroneId');local pos=source:GetAttribute('Position');local kind=source:GetAttribute('Type')
 if not id or typeof(pos)~='Vector3' or not colors[kind] or type(source:GetAttribute('Role'))~='string' then return false end
 pendingDroneSources[source]=true
 -- Render from the complete preserved asset, never a partially streamed gameplay model.
 -- The historical drone is a Part body plus its nested emitter; it has no SpecialMesh.
 local template=RS:FindFirstChild('Drone') or workspace:FindFirstChild('Drone')
 local mesh=template and template:FindFirstChild('Mesh')
 local templateEmitter=mesh and mesh:FindFirstChild('Emmiter')
 local originalBeam=mesh and mesh:FindFirstChild('Beam')
 if not template or not template:IsA('Model') or not mesh or not mesh:IsA('BasePart')
  or not templateEmitter or not templateEmitter:IsA('BasePart') or not mesh:FindFirstChild('Attachment')
  or not mesh:FindFirstChild('WeldConstraint') or not originalBeam
  or not originalBeam:FindFirstChild('InnerBeam') or not originalBeam:FindFirstChild('OuterBeam') then
  -- Never make a gameplay drone invisible just because the optional presentation asset is unavailable.
  return false
 end
 local clone=template:Clone();if not clone then return false end;clone.Name='View_'..tostring(id);sanitize(clone)
 clone.PrimaryPart=clone.PrimaryPart or clone:FindFirstChild('Mesh') or clone:FindFirstChildWhichIsA('BasePart',true)
 clone:ScaleTo(clone:GetScale()*(source:GetAttribute('ModelScale') or DroneConfig.Swarm.ModelScale))
 local referenceMiner=source:GetAttribute('Role')=='Striker'
 if not referenceMiner then DroneConfig.decorate(clone,source:GetAttribute('Role') or kind) end
 pendingDroneSources[source]=nil
 local pivot=clone.PrimaryPart or clone:FindFirstChildWhichIsA('BasePart',true);if not pivot then clone:Destroy();return false end
 clone.PrimaryPart=pivot;clone.Parent=localFX
 local emitter=clone:FindFirstChild('Emmiter',true) or clone:FindFirstChild('MiningEmitter',true) or clone:FindFirstChild('Emitter',true)
 if not emitter or not emitter:IsA('BasePart') then clone:Destroy();pendingDroneSources[source]=true;return false end
 for _,part in ipairs(clone:GetDescendants()) do
  if part:IsA('BasePart') then part.Reflectance=0 end
 end
 local typeColor=colors[source:GetAttribute('Role')] or colors[source:GetAttribute('Type')]
 emitter.Color=typeColor or emitter.Color
 -- The original 1-stud emitter is enclosed by its 2-stud body; a restrained tint stays visible.
 if referenceMiner then
  pivot.Color=Color3.fromRGB(163,162,165);pivot.Material=Enum.Material.Plastic;pivot.MaterialVariant=''
  emitter.Color=pivot.Color;emitter.Material=pivot.Material;emitter.MaterialVariant=''
 elseif typeColor and not clone:GetAttribute('RoleGeometry') then
  pivot.Color=Color3.fromRGB(111,120,123):Lerp(typeColor,.18)
  -- Keep the authored shell/emitter; small case seams make its type readable in flight.
  local trim=localPart(clone,'LowerChassis',pivot.Position);trim.Size=Vector3.new(pivot.Size.X*1.015,.055,pivot.Size.Z*1.015);trim.Transparency=0;trim.Color=Color3.fromRGB(23,35,46);trim.Material=Enum.Material.Metal;trim.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.35,0)
  for _,side in ipairs({-1,1}) do
   local optic=localPart(clone,'TypeOptic',pivot.Position);optic.Size=Vector3.new(pivot.Size.X*.52,.035,.015);optic.Transparency=0;optic.Color=typeColor;optic.Material=Enum.Material.SmoothPlastic;optic.CFrame=pivot.CFrame*CFrame.new(0,-pivot.Size.Y*.24,side*(pivot.Size.Z*.5+.01))
  end
 end
 hideModel(source)
 local parts={};for _,p in ipairs(clone:GetDescendants()) do if p:IsA('BasePart') then parts[p]=p.Transparency end end
 local d={source=source,view=clone,emitter=emitter,pos=pos,velocity=source:GetAttribute('Velocity') or Vector3.zero,yaw=source:GetAttribute('Yaw') or 0,life=source:GetAttribute('Life'),parts=parts,lastState=source:GetAttribute('State'),beam=createBeam(clone,emitter)}
 d.specialMotion=SpecialDroneMotion.new(clone,source:GetAttribute('Role'))
 drones[source]=d;droneIndex[tostring(id)]=d
 clone:PivotTo(CFrame.new(pos)*CFrame.Angles(0,d.yaw,0))
 TacticalHUD.attachHealth(clone,source,typeColor or colors.Blue)
 presentation:registerDrone(d,workspace:GetServerTimeNow())
 return true
end
local function registerResource(source)
 if resources[source] or not source:IsA('BasePart') then return end
 local id=source:GetAttribute('ResourceId');if not id then return end
 hidePart(source)
 -- Initialize from a complete current snapshot so a late join cannot replay an old break.
 for _,attribute in ipairs({'HP','MaxHP','SpawnAt','ReadyAt','FullSize','FullPosition','Stage','BreakSerial','Kind'}) do
  if source:GetAttribute(attribute)==nil then return end
 end
 local view=source:Clone();view.Name='View_Resource_'..tostring(id)
 for _,v in ipairs(view:GetDescendants()) do if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') or v:IsA('Beam') or v:IsA('ParticleEmitter') or v:IsA('Light') then v:Destroy() end end
 view.Anchored=true;view.CanCollide=false;view.CanTouch=false;view.CanQuery=false;view.LocalTransparencyModifier=0
 view.Reflectance=source.Reflectance;view.Parent=localFX;hidePart(source)
 if source:GetAttribute('Kind')=='Junk' then
  for _,decal in ipairs(source:GetChildren()) do if decal:IsA('Decal') then hidePart(decal) end end
 end
 resources[source]={source=source,view=view,id=tostring(id),baseColor=source.Color,dirty=true,visual=Feel.newStagePresentation(source:GetAttribute('Stage') or 0,(source:GetAttribute('BreakSerial') or 0)>0 or (source:GetAttribute('HP') or 1)<=0,workspace:GetServerTimeNow(),source:GetAttribute('StageCount') or 3)}
 resourceIndex[tostring(id)]=resources[source]
 rockDamage:register(resources[source])
end
local function registerTurret(source)
 if turrets[source] or not source:IsA('Model') or not (source:GetAttribute('Turret') or source:GetAttribute('TurretId')) then return end
 local t=presentation:registerTurret(source,workspace:GetServerTimeNow())
 if t then turrets[source]=t;turretIndex[tostring(source:GetAttribute('TurretId'))]=source;hideModel(source);TacticalHUD.attachHealth(t.view,source,palette.danger,true) end
end
local observed={}
local function observe(source)
 if not source.Parent then return end
 if source:IsA('Decal') then
  local record=resources[source.Parent]
  if record and record.source:GetAttribute('Kind')=='Junk' then
   if not record.view:FindFirstChild(source.Name) then
    local clone=source:Clone();clone.LocalTransparencyModifier=record.view.Transparency;clone.Parent=record.view
   end
   hidePart(source)
  end
 end
 if source:IsA('BasePart') then
  local ancestor=source.Parent
  while ancestor and ancestor~=world do
   if ancestor:IsA('Model') then
    if ancestor:GetAttribute('DroneId') then if registerDrone(ancestor) then hidePart(source) end end
    if ancestor:GetAttribute('Turret') then registerTurret(ancestor);hidePart(source) end
   end
   ancestor=ancestor.Parent
  end
 end
 if source:IsA('Model') and (source:GetAttribute('DroneId') or source.Parent.Name=='Drones') then
  registerDrone(source)
  if not observed[source] then observed[source]=source.AttributeChanged:Connect(function() registerDrone(source) end) end
 elseif source:IsA('BasePart') and (source:GetAttribute('ResourceId') or source.Parent.Name=='Resources' or source.Parent:GetAttribute('FieldId')) then
  registerResource(source)
  if not observed[source] then observed[source]=source.AttributeChanged:Connect(function()
   local record=resources[source]
   if record then record.dirty=true else registerResource(source) end
  end) end
 elseif source:IsA('BasePart') and source.Parent:IsA('Model') and drones[source.Parent] then hidePart(source)
 end
 if source:IsA('Model') and (source:GetAttribute('Turret') or source:GetAttribute('TurretId') or source.Parent.Name=='Turrets' or source.Parent:GetAttribute('FieldId')) then
  registerTurret(source)
  if not observed[source] then observed[source]=source.AttributeChanged:Connect(function() registerTurret(source) end) end
 end
end
connect(world.DescendantAdded,function(source) task.defer(observe,source) end)
connect(RS.DescendantAdded,function()
 if next(pendingDroneSources) and not templateRetryQueued then
  templateRetryQueued=true;task.defer(function()
   templateRetryQueued=false
   for source in pairs(pendingDroneSources) do if source.Parent then registerDrone(source) else pendingDroneSources[source]=nil end end
  end)
 end
end)
for _,source in ipairs(world:GetDescendants()) do observe(source) end
local function destroyDrone(d)
 droneIndex[tostring(d.source:GetAttribute('DroneId'))]=nil
 if d.healBeam then d.healBeam:Destroy() end
 BeamVFX.destroy(d.healVFX)
 if d.healMuzzle then d.healMuzzle:Destroy() end
 if d.healTarget then d.healTarget:Destroy() end
 presentation:destroyDrone(d)
 presentation:destroyMiningBeam(d.beam);d.view:Destroy()
end
connect(world.DescendantRemoving,function(source)
 pendingDroneSources[source]=nil
 if drones[source] then destroyDrone(drones[source]);drones[source]=nil end
 if resources[source] then rockDamage:remove(resources[source]);resourceIndex[resources[source].id]=nil;resources[source].view:Destroy();resources[source]=nil end
 if turrets[source] then turretIndex[tostring(source:GetAttribute('TurretId'))]=nil;presentation:destroyTurret(turrets[source]);turrets[source]=nil end
 if observed[source] then observed[source]:Disconnect();observed[source]=nil end
 hiddenParts[source]=nil
end)
local function resourceById(id) return resourceIndex[tostring(id)] end
local function renderResource(r,now)
 -- Mature, unchanged rocks need no repeated attribute reads, trigonometry or
 -- geometry writes. Spawn growth is animated; mining size changes are snaps.
 if r.settled and not r.dirty then return end
 r.dirty=false
 local s=r.source;local view=r.view
 -- Locked fields remain visible destinations; the server still gates mining.
 local full=s:GetAttribute('FullSize') or s.Size
 if type(full)=='number' then full=Vector3.one*full end
 local final=s:GetAttribute('FullPosition') or s.Position
 local spawnAt=s:GetAttribute('SpawnAt') or now-2
 local readyAt=s:GetAttribute('ReadyAt') or spawnAt+2
 local junk=s:GetAttribute('Kind')=='Junk'
 local reference=s:GetAttribute('ReferenceCrystal')==true
 -- The open Mining Away uses the full-size crystal during its readiness delay.
 local growth=1
 if not junk and not reference then
  growth=Feel.growth(now,spawnAt)
  if readyAt-spawnAt~=2 then local g=math.clamp((now-spawnAt)/math.max(.01,readyAt-spawnAt),0,1);growth=1-(1-g)^2 end
 end
 local stageCount=s:GetAttribute('StageCount') or 3
 local authoritativeStage=math.clamp(s:GetAttribute('Stage') or 0,0,stageCount)
 local health=s:GetAttribute('HP') or 1
 local broken=(s:GetAttribute('BreakSerial') or 0)>0 or health<=0
 local healed=s:GetAttribute('RegrowAt') or 0
 if not broken and healed>0 then
  if authoritativeStage<r.visual.knownStage then
   r.visual=Feel.newStagePresentation(authoritativeStage,false,now,stageCount);r.crackHealth=nil
  end
  if healed~=(r.lastHeal or 0) and now-healed<.4 then selectorView:heal(view,now) end
  r.lastHeal=healed
 end
 local event=Feel.updateStagePresentation(r.visual,authoritativeStage,broken,now,stageCount)
 local stage=r.visual.stage
 local period=Feel.stageScale(stage,stageCount)
 if not r.visual.broken then
  view.Transparency=s:GetAttribute('Kind')=='Geode' and .04 or s.Transparency
  local heat=s:GetAttribute('MeltBand') or 0
  local displaySize=full*math.max(.005,growth*period)*Feel.rockShape(s:GetAttribute('SliceScale'),heat)
  view.Size=displaySize*(r.damageScale or Vector3.one)
  local start=s:GetAttribute('StartPosition') or Vector3.new(final.X,final.Y-2-full.Y/2,final.Z)
  local pos=start:Lerp(final,growth)
  local seed=s:GetAttribute('StageSeed') or 0
  local ground=s:GetAttribute('GroundY')
  local frame
  if type(ground)=='number' then frame=Feel.groundedRockFrame(pos,displaySize,ground,stage,seed,s:GetAttribute('CubicRock')==false)
  else frame=CFrame.new(pos)*CFrame.Angles(0,seed*.01,0) end
  if junk then
   if now<readyAt then
    frame=JunkField.fallPose(now-spawnAt,frame)
    if now<spawnAt then view.Transparency=1 end
   end
  end
  view.CFrame=frame*CFrame.new(displaySize*(r.damageOffset or Vector3.zero))
  local maxHealth=s:GetAttribute('MaxHP') or 1
  local color=r.baseColor:Lerp(Color3.fromRGB(237,105,46),heat*.11)
  if junk then
   view.Color=color:Lerp(Color3.new(0,0,0),Feel.junkDarkness(health,maxHealth,stage,stageCount))
  else
   -- Mining Away changes the size stage first and applies its new shade on the next hit.
   if event=='stage' then r.crackHealth=health end
   local shadeStage=r.crackHealth==health and stage-1 or stage
   local shadeHealth=shadeStage<stage and math.max(health,maxHealth*period) or health
   view.Color=color:Lerp(Color3.new(0,0,0),1-Feel.crystalShade(shadeHealth,maxHealth,shadeStage,stageCount))
  end
 else view.Transparency=1 end
 if junk then
  for _,decal in ipairs(view:GetChildren()) do
   if decal:IsA('Decal') then decal.LocalTransparencyModifier=view.Transparency end
  end
 end
 if event then crystalAudio:play(view.Position,event) end
 rockDamage:update(r,now)
 r.settled=now>=readyAt
end
local function resolveRenderedTarget(kind,id,allowBreaking)
 if type(id)~='string' or id=='' then return nil end
 if kind=='resource' then
  local r=resourceById(id)
  if r and r.source.Parent and (allowBreaking or ((r.source:GetAttribute('BreakSerial') or 0)==0 and (r.source:GetAttribute('HP') or 0)>0))
   and r.view.Parent and not r.visual.broken then return r.view,r.source,r end
 elseif kind=='turret' then
  for source,t in pairs(turrets) do
   if source.Parent and source:GetAttribute('TurretId')==id and source:GetAttribute('Dead')~=true and (source:GetAttribute('HP') or 0)>0
    and t.view and t.view.Parent then
    -- spawnEye is the original slightly larger visible eye shell around eye.
    local eye=t.view:FindFirstChild('spawnEye',true) or t.eye
    if eye and eye:IsA('BasePart') and eye.Parent and eye.Transparency<.99 then return eye,source,nil end
   end
  end
 end
 return nil
end
local function renderDrone(d,dt,now)
 local previousPosition=d.pos
 local s=d.source;local state=s:GetAttribute('State') or 'Follow'
 local referenceMiner=s:GetAttribute('Role')=='Striker'
 local logical=s:GetAttribute('Position');local goal=s:GetAttribute('Goal') or logical
 if typeof(logical)~='Vector3' or typeof(goal)~='Vector3' then return end
 d.lastState=state
 local life=s:GetAttribute('Life');local maxStep=s:GetAttribute('MaxStep60') or .35
 if life~=d.life then d.life=life;d.pos=logical;d.velocity=s:GetAttribute('Velocity') or Vector3.zero end
 local motionPaused=s:GetAttribute('MotionPaused')==true
 local owner=(referenceMiner or state=='Follow') and Players:GetPlayerByUserId(s:GetAttribute('Owner') or 0)
 local hr=owner and owner.Character and owner.Character:FindFirstChild('HumanoidRootPart')
 if state=='Follow' and not motionPaused then
  local slot=s:GetAttribute('FormationSlot');local count=s:GetAttribute('FleetCount')
  if hr and slot and count then
   goal=Feel.followGoal(hr.Position,slot,count,now,(s:GetAttribute('PhaseSeed') or maxStep*200)/200)
  end
 end
 if state=='Destroyed' or state=='Reprinting' then d.pos=logical;d.velocity=Vector3.zero
 elseif not motionPaused and (state=='BreakerDive' or state=='BreakerImpact') then
  -- A powered fall accelerates all the way into the surface. Evaluate the
  -- authoritative stroke directly: destination smoothing here brakes before
  -- contact and puts landing effects ahead of the visible weight.
  local impact=s:GetAttribute('BreakerImpact') or goal
  if state=='BreakerDive' then
   d.pos,d.velocity=Feel.powerDive(s:GetAttribute('BreakerDiveStart') or logical,impact,
    now-(s:GetAttribute('BreakerPhaseAt') or now),s:GetAttribute('BreakerDiveDuration') or .28)
  else
   -- The impact plane is a hard stop, followed by the server-owned weight hold.
   d.pos=impact;d.velocity=Vector3.zero
  end
 elseif not motionPaused then
  local workTravel=state=='Deliver' or state=='BreakerDive' or state=='BreakerRecover' or state=='Recover' or state=='Plant' or state=='GrowApproach' or (s:GetAttribute('TargetId') or '')~=''
  local error=logical-d.pos
  local correction=error.Magnitude>5 and error.Unit*math.min((error.Magnitude-5)*.8,maxStep*60*.25) or Vector3.zero
  if referenceMiner then d.pos,d.velocity=Feel.referenceFlight(d.pos,goal,maxStep,math.min(dt,.1),correction)
  else d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,maxStep,math.min(dt,.1),workTravel,correction) end
 end
 if not motionPaused then
  local targetYaw=referenceMiner and Feel.referenceYaw(previousPosition,goal,maxStep,hr and hr.CFrame.LookVector,d.yaw) or Feel.flightYaw(d.pos,goal,d.velocity,d.yaw)
  local difference=math.atan2(math.sin(targetYaw-d.yaw),math.cos(targetYaw-d.yaw))
  d.yaw=d.yaw+difference*Feel.turnAlpha(math.min(dt,.1))
 end
 local velocity=dt>0 and (d.pos-previousPosition)/dt or Vector3.zero
 local sideVelocity=CFrame.Angles(0,d.yaw,0):VectorToObjectSpace(velocity).X
 local desiredBank=(referenceMiner or state=='Mine' or state=='SpecialMine' or state=='BreakerDive' or state=='BreakerImpact' or state=='Destroyed' or state=='Reprinting' or motionPaused) and 0 or math.clamp(-sideVelocity*.005,-math.rad(3),math.rad(3))
 d.bank=state=='BreakerImpact' and 0 or (d.bank or 0)+(desiredBank-(d.bank or 0))*(1-math.exp(-math.min(dt,.1)*5))
 local grounded=state=='BreakerDive' or state=='BreakerImpact'
 local drift=(referenceMiner or state=='Destroyed' or state=='Reprinting' or motionPaused or grounded) and 0 or math.sin(now*1.6+(s:GetAttribute('PhaseSeed') or 0))*((state=='Mine' or state=='SpecialMine') and .05 or .10)
 -- The server issues one silent recall cue. A short lift and settling nod
 -- communicate the return before the familiar inertial following takes over.
 -- Reading server time makes every observer see the same hop, and late joins
 -- never replay an old recall.
 local recallAt=s:GetAttribute('RecallAt') or -100
 local recallAge=now-recallAt;local hop,recallPitch=0,0
 if not referenceMiner and not motionPaused and (state=='Follow' or state=='Return') and recallAge>=0 and recallAge<.72 then
  local p=recallAge/.72
  hop=math.sin(math.pi*p)^2*.9
  recallPitch=math.sin(2*math.pi*p)*math.rad(7)
 end
 d.view:PivotTo(CFrame.new(d.pos+Vector3.new(0,drift+hop,0))*CFrame.Angles(0,d.yaw,0)*CFrame.Angles(recallPitch,0,d.bank))
 if d.specialMotion then
  local target=resourceIndex[tostring(s:GetAttribute('TargetId') or '')]
  SpecialDroneMotion.step(d.specialMotion,s,target and target.source,now)
 end
 local reprintAt=s:GetAttribute('ReprintAt') or 0
 for part,original in pairs(d.parts) do
  if state=='Destroyed' then part.Transparency=1
  elseif state=='Reprinting' then part.Transparency=math.max(original,math.clamp((reprintAt-now)/2,0,1))
  else part.Transparency=original end
 end
 presentation:renderDrone(d,dt,now)
 local mining=s:GetAttribute('Mining')==true and s:GetAttribute('WorkPaused')~=true
 local attacking=state=='Attack' and s:GetAttribute('Firing')==true and s:GetAttribute('WorkPaused')~=true
 local alive=state~='Destroyed' and state~='Reprinting' and (s:GetAttribute('HP') or 1)>0
 local active=alive and (mining or attacking)
 local charging=alive and state=='Warmup' and not mining and s:GetAttribute('WorkPaused')~=true and (s:GetAttribute('WarmupStart') or 0)>0
 local beam=d.beam
 local kind=state=='Attack' and 'turret' or 'resource'
 local id=s:GetAttribute(kind=='turret' and 'CombatTargetId' or 'TargetId')
 if active and type(id)=='string' and id~='' then beam.lastKey=id;beam.lastKind=kind
 elseif not active and not charging and state~='SpecialMine' and beam.lastKey then id=beam.lastKey;kind=beam.lastKind end
 local part,source,resource=resolveRenderedTarget(kind,id)
 local procKind=state=='Attack' and 'turret' or 'resource'
 local procId=s:GetAttribute(procKind=='turret' and 'ChainTargetId' or 'ForkTargetId')
 local procUntil=s:GetAttribute(procKind=='turret' and 'ChainUntil' or 'ForkUntil') or 0
 local extra,extraSource
 if active and now<procUntil then extra,extraSource=resolveRenderedTarget(procKind,procId) end
 local beamSince=state=='Attack' and (s:GetAttribute('ShotAt') or now) or (s:GetAttribute('BeamSince') or now)
 local specialReleaseAt
 if state=='SpecialMine' and source and source:GetAttribute('EffectDrone')==s:GetAttribute('DroneId') then
  local started=source:GetAttribute('EffectStartedAt')
  if started and started>=now-.16 and started<=now then specialReleaseAt=started end
 end
 local breakAt,breakUntil
 -- A final hit retires the gameplay reservation immediately. Its short saved
 -- contact may finish the local fracture sequence while the drone moves on.
 -- A new active job wins, and no contact outlives either visible crystal.
 local finalAt=s:GetAttribute('MineBreakAt') or 0
 local finalUntil=s:GetAttribute('MineBreakUntil') or 0
 if alive and not active and not motionPaused and (s:GetAttribute('MineBreakSerial') or 0)>0
  and now>=finalAt and now<math.min(finalUntil,finalAt+.3) then
  local primaryId=s:GetAttribute('MineBreakPrimaryId')
  local finalPart,finalSource,finalResource=resolveRenderedTarget('resource',primaryId,true)
  if finalPart then
   part,source,resource=finalPart,finalSource,finalResource;id=primaryId;kind='resource';active=true
   procId=s:GetAttribute('MineBreakSecondaryId')
   extra,extraSource=resolveRenderedTarget('resource',procId,true)
   beamSince=s:GetAttribute('MineBreakBeamSince') or now;breakAt=finalAt;breakUntil=finalUntil
  end
 end
 presentation:queueMiningBeam(beam,{alive=alive,active=active,key=id,life=life,
  contact=active,
  isMining=kind=='resource',charging=charging,specialReleaseAt=specialReleaseAt,
  warmupStart=s:GetAttribute('WarmupStart') or 0,warmupDuration=s:GetAttribute('WarmupDuration') or .8,mineralColor=resource and resource.baseColor,
  style=state=='Attack' and 'Cutter' or s:GetAttribute('MiningStyle'),droneType=s:GetAttribute('Type'),droneRole=s:GetAttribute('Role'),paused=s:GetAttribute('MotionPaused')==true or s:GetAttribute('WorkPaused')==true,
  pulseSerial=s:GetAttribute('MinePulseSerial') or 0,pulseAt=s:GetAttribute('MinePulseAt') or 0,pulseKey=s:GetAttribute('MinePulseTargetId'),
  since=beamSince,breakContactAt=breakAt,breakContactUntil=breakUntil,
  part=part,serverSource=source,resource=resource,secondaryPart=extra,secondarySource=extraSource,
  secondaryKey=procId,secondaryColor=state=='Attack' and Color3.fromRGB(255,179,102) or nil},now)

end
-- Every observer draws repair beams between the current rendered emitters.
-- Surface queries rotate through active healers; stale visibility expires.
local healCursor=0
local function renderHealing(now)
 local candidates={}
 for _,d in pairs(drones) do
  local id=d.source:GetAttribute('HealTargetId');local target=type(id)=='string' and droneIndex[id]
  local active=(d.source:GetAttribute('Healing')==true or d.source:GetAttribute('State')=='RepairCharge') and d.source:GetAttribute('MotionPaused')~=true and d.source:GetAttribute('WorkPaused')~=true
   and (d.source:GetAttribute('HP') or 0)>0 and target and (target.source:GetAttribute('HP') or 0)>0
   and d.emitter.Parent and target.emitter.Parent
  if active then table.insert(candidates,{drone=d,target=target})
  else
   if d.healBeam then d.healBeam.Transparency=1 end
   BeamVFX.destroy(d.healVFX);d.healVFX=nil
  end
 end
 table.sort(candidates,function(a,b) return tostring(a.drone.source:GetAttribute('DroneId'))<tostring(b.drone.source:GetAttribute('DroneId')) end)
 local count=#candidates
 for n=1,math.min(4,count) do
  local item=candidates[(healCursor+n-1)%count+1];local d,target=item.drone,item.target
  local from,to=d.emitter.Position,target.emitter.Position
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
  local ignore={localFX,world:FindFirstChild('Drones') or d.source}
  for _,owner in ipairs(Players:GetPlayers()) do if owner.Character then table.insert(ignore,owner.Character) end end
  params.FilterDescendantsInstances=ignore;params.IgnoreWater=true
  d.healVisible=(to-from).Magnitude<=16 and not workspace:Raycast(from,to-from,params)
  d.healCheckedAt=now;d.healCheckedTarget=target
 end
 if count>0 then healCursor=(healCursor+math.min(4,count))%count end
 for _,item in ipairs(candidates) do
  local d,target=item.drone,item.target
  if not d.healBeam then d.healBeam=WorkEffects.newCylinder(d.view,'RepairBeam',Color3.fromRGB(141,209,151)) end
  local visible=d.healVisible==true and d.healCheckedTarget==target and now-(d.healCheckedAt or 0)<.2
  local charging=d.source:GetAttribute('State')=='RepairCharge'
  local q=charging and math.clamp((now-(d.source:GetAttribute('RepairChargeAt') or now))/(d.source:GetAttribute('RepairChargeDuration') or .4),0,1) or 1
  if visible then
   d.healVFX=d.healVFX or BeamVFX.new(d.view,'Repair',Color3.fromRGB(141,209,151))
   if d.healVFX then
    d.healBeam.Transparency=1
    BeamVFX.draw(d.healVFX,d.emitter.Position,target.emitter.Position,now,charging and .18+.25*q or 1,charging and q or nil,nil)
   else WorkEffects.drawCylinder(d.healBeam,d.emitter.Position,target.emitter.Position,charging and .01+.014*q or .052,charging and (.8-.35*q) or .12) end
  else d.healBeam.Transparency=1;BeamVFX.hide(d.healVFX,true) end
 end
end

-- The carried inventory belongs to the character. These local, non-colliding
-- props are drawn for every player and follow their torso, including late joins.
local backpacks={}
local function renderBackpacks()
 local present={}
 for _,owner in ipairs(Players:GetPlayers()) do
  present[owner]=true
  local character=owner.Character
  local torso=character and (character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'))
  local record=backpacks[owner]
  if record and (not torso or record.character~=character) then record.model:Destroy();backpacks[owner]=nil;record=nil end
  if torso and torso:IsA('BasePart') then
   if not record then
    local model=Instance.new('Model');model.Name='Backpack_'..owner.UserId;model.Parent=localFX
    local function piece(name,size,offset,color,material)
     local part=localPart(model,name,torso.Position);part.Size=size;part.Color=color;part.Material=material
     part.Reflectance=0;part.Transparency=0;part.CastShadow=true;part.CFrame=torso.CFrame*offset
     return {part=part,offset=offset}
    end
    record={model=model,character=character,parts={}}
    table.insert(record.parts,piece('Pack',Vector3.new(1.4,1.6,.65),CFrame.new(0,0,.8),Color3.fromRGB(88,97,76),Enum.Material.Fabric))
    table.insert(record.parts,piece('Flap',Vector3.new(1.46,.25,.71),CFrame.new(0,.65,.8),Color3.fromRGB(69,77,62),Enum.Material.Fabric))
    for _,side in ipairs({-1,1}) do table.insert(record.parts,piece('Strap',Vector3.new(.14,1.65,.08),CFrame.new(side*.46,0,1.16),Color3.fromRGB(52,56,48),Enum.Material.Fabric)) end
    backpacks[owner]=record
   end
   for _,item in ipairs(record.parts) do item.part.CFrame=torso.CFrame*item.offset end
  end
 end
 for owner,record in pairs(backpacks) do if not present[owner] then record.model:Destroy();backpacks[owner]=nil end end
end

local specialMiningFX=DroneFX.new(world,{resolve=function(source) local record=resources[source];return record and record.view end,
 focus=function() local hr=player.Character and player.Character:FindFirstChild('HumanoidRootPart');return hr and hr.Position end})
local laserShowcase=LaserShowcase.new(world,localFX,DroneConfig)
connect(RunService.RenderStepped,function(dt)
 local now=workspace:GetServerTimeNow()
 local map=world:FindFirstChild('Map')
 local reserve=map and map:FindFirstChild('LiminalReserve')
 local clouds=reserve and reserve:FindFirstChild('CloudBlocks')
 if clouds then
  -- Authored blocks stay at their centers in Edit. Animate locally from a
  -- shared clock so the scenery needs no replicated transform updates.
  for _,cloud in ipairs(clouds:GetChildren()) do
   local center=cloud:GetAttribute('DriftCenter')
   local drift=cloud:GetAttribute('DriftVector')
   local period=cloud:GetAttribute('DriftPeriod')
   if cloud:IsA('BasePart') and center and drift and period and period>0 then
    local phase=(now%period)/period*(2*math.pi)+(cloud:GetAttribute('DriftPhase') or 0)
    cloud.Position=center+drift*math.sin(phase)
   end
  end
 end
 roleEffectView:step(now)
 presentation:beginFrame()
 pickupView:update(dt,now)
 for _,r in pairs(resources) do renderResource(r,now) end
 selectorView:updateHealing(now)
 rockDamage:step(now)
 specialMiningFX:step(now,dt)
 for _,t in pairs(turrets) do
  if fieldUnlocked(t.source.Parent) and (t.source:GetAttribute('HP') or 0)>0 then
   t.view.Parent=nil;t.cue.Transparency=1;t.beam.Enabled=false;t.flare.Enabled=false;t.light.Brightness=0
  else
   if not t.view.Parent then t.view.Parent=localFX end
   presentation:renderTurret(t,dt,now)
  end
 end
 for _,d in pairs(drones) do renderDrone(d,dt,now) end
 renderHealing(now);renderBackpacks()
 presentation:flushMiningBeams()
 presentation:update(dt,now)
 laserShowcase:step(now,dt)
 if logisticsView then logisticsView:step(now,dt) end
 if toolView then toolView:step(dt,now) end
end)

local evade=button(safeRoot,UDim2.new(1,-136,1,-108),UDim2.fromOffset(118,38),'Evade  [Q]',function() command:FireServer('Evade') end,palette.accent);evade.Visible=false
local testLoadout=button(safeRoot,UDim2.new(1,-252,0,80),UDim2.fromOffset(236,44),'Random loadout · 2–5 [T]',function() command:FireServer('TestLoadout') end,Color3.fromRGB(139,83,224))
testLoadout.Name='RandomLoadoutTester';testLoadout.Visible=false
local function cargoAction()
 command:FireServer('Sell')
end
local unload=button(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(116,40),'Sell [U]',cargoAction,palette.paper)
unload.Name='ReturnCargo';unload.Visible=false
local enemyHUD=U.panel(safeRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(300,58),palette.panel,12);enemyHUD.Name='SentryHealth';enemyHUD.Visible=false
local enemyTitle=label(enemyHUD,UDim2.fromOffset(12,0),UDim2.new(1,-24,1,0),'PYRAMID SENTRY',12,palette.white,true)
local enemyHealth=frame(enemyHUD,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(53,55,57));enemyHealth.Name='HealthTrack';enemyHealth.ClipsDescendants=true;enemyHealth.BackgroundTransparency=1;corner(enemyHealth,3)
local enemyFill=frame(enemyHealth,UDim2.fromScale(0,0),UDim2.fromScale(1,1),palette.danger);enemyFill.Name='Fill';corner(enemyFill,3);U.gradient(enemyFill)
enemyTitle.ZIndex=enemyFill.ZIndex+2
local tacticalHUD=TacticalHUD.new({interface=U,root=safeRoot,gui=gui,modal=modal,recall=recall,unload=unload,test=testLoadout,evade=evade,resources=hud,context=context,enemy=enemyHUD,toast=toast,
 cargoText=cargoText,cargoTrack=cargoTrack,profile=function() return profile end,hidden=menusVisible})
logisticsView=LogisticsView.start({interface=U,parent=safeRoot,world=world,localFX=localFX,command=command,dock=tacticalHUD.dock,context=context,
 profile=function() return profile end,hidden=function() return modal.Visible end,
 blocks=function(point) return tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) end,
 onOpen=function() modal.Visible=false end,onVisibility=syncModalTouch,
 openFleet=openFleet,openWorkshop=openPack,openPrestige=openPrestige,openCards=function() if pending() and not sealedPack() then openOffer() else openRunCards() end end,
 notify=function(message) notice.Text=message;noticeUntil=os.clock()+5 end})
toolView=ToolView.new({interface=U,parent=safeRoot,world=world,localFX=localFX,command=command,
 audio=soundscape,presentation=presentation,hidden=menusVisible,
 blocks=function(point) return tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) or (toolView and toolView:blocks(point-game:GetService('GuiService'):GetGuiInset())) end,
 onSelect=function() logisticsView.selected=nil end})
local function ownerRoot() return player.Character and player.Character:FindFirstChild('HumanoidRootPart') end
local function stationAction(station)
 local kind=station:GetAttribute('Interaction')
 if kind=='Shop' then
  local key=station:GetAttribute('ShopKey')
  if key=='Quartz' and profile then return openPack,'Quartz Workshop','Open packs, stack upgrades, earn drones','Open' end
  return nil
 elseif kind=='Pack' then
  return openPack,'Quartz Workshop',pending() and 'Your upgrade pack is waiting' or 'Packs, repeat upgrades and prestige','Open'
 elseif kind=='Printer' then return function() logisticsView:toggle() end,'Drone yard','Manage your permanent fleet and transport','Browse'
 elseif kind=='Prestige' then return openPrestige,'Prestige','Keep your drones · gain permanent mining power','Review'
 elseif kind=='Sell' then
  return cargoAction,'Sell ore','Your backpack becomes spendable minerals immediately','Sell'
 end
 return nil
end
local lastStationUse=0
local function performStation(station)
 local action=stationAction(station)
 local hr=ownerRoot();local prompt=station:FindFirstChildOfClass('ProximityPrompt')
 if not hr or not prompt or not prompt.Enabled or (hr.Position-station.Position).Magnitude>prompt.MaxActivationDistance+1 then return end
 if menusVisible() or (station:GetAttribute('Interaction')=='Pack' and packView.target) then return end
 if action and os.clock()-lastStationUse>.25 then lastStationUse=os.clock();menuStation=station;action() end
end
connect(game:GetService('ProximityPromptService').PromptTriggered,function(prompt,who)
 if (not who or who==player) and prompt.Parent and prompt.Parent:IsA('BasePart') then performStation(prompt.Parent) end
end)
local function requestField(id)
 if menusVisible() then return end
 if logisticsView and logisticsView:dispatchField(id) then return end
 local fields=world:FindFirstChild('Fields')
 if fields then for _,field in ipairs(fields:GetChildren()) do
  if (field:GetAttribute('FieldId') or field:GetAttribute('Tier'))==id then
   command:FireServer('Patch',id)
   return
  end
 end end
end
local commandView=CommandView.new({parent=localFX,resources=resourceIndex,drones=drones,command=command,
 profile=function() return profile end,hidden=function() return menusVisible() or logisticsView.selected~=nil or (toolView and toolView:selected()~=nil) end,
 blocks=function(point) return tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) end})
connect(RunService.RenderStepped,function(dt) commandView:update(dt,workspace:GetServerTimeNow()) end)
connect(gui.Parent:GetAttributeChangedSignal('MA_CommandState'),function()
 local ok,state=pcall(Http.JSONDecode,Http,gui.Parent:GetAttribute('MA_CommandState') or '')
 if not ok or type(state)~='table' then return end
 commandView:reply(state)
 soundscape:play(state.status=='rejected' and 'denied' or 'command')
 if state.status=='rejected' then notice.Text=state.reason or '';noticeUntil=os.clock()+2.2 end
end)
local function assignField(target)
 if menusVisible() then return end
 local node=target
 while node and node~=workspace do
  local resourceId=node:GetAttribute('ResourceId')
  if type(resourceId)=='string' and resourceId~='' then
   if node.Parent and node.Parent.Parent and node.Parent.Parent.Name=='CrystalRun' then return end
   local fieldId=node:GetAttribute('FieldId')
   if type(fieldId)=='number' and logisticsView and logisticsView.selected then requestField(fieldId);return end
   commandView:request(resourceId)
   return
  end
  local owner=node:GetAttribute('Owner')
  if owner==player.UserId and node:GetAttribute('DroneId') then return end
  local field=node:GetAttribute('FieldId') or node:GetAttribute('Patch') or node:GetAttribute('Tier')
  if node:GetAttribute('CrystalZone') or (node.Parent and node.Parent.Name=='CrystalRun') then return end
  if type(field)=='number' then requestField(field);return end
  node=node.Parent
 end
end
local mouse=player:GetMouse()
connect(RunService.RenderStepped,function(dt)
 local camera=workspace.CurrentCamera
 local ray
 if camera and not menusVisible() then
  local touch=selectorView.touch
  if touch and touch.active then
   local point=touch.input.Position
   ray=camera:ViewportPointToRay(point.X,point.Y)
  elseif UIS.MouseEnabled and UIS:GetLastInputType()~=Enum.UserInputType.Touch then
   local point=UIS:GetMouseLocation()-game:GetService('GuiService'):GetGuiInset()
   if not tacticalHUD:blocksPoint(point) then ray=mouse.UnitRay end
  end
 end
 selectorView:showAim(dt,ray)
end)
connect(UIS.TouchTapInWorld,function(position,processed)
 if processed or menusVisible() or tacticalHUD:blocksPoint(position) then return end
 if toolView and toolView:click(position) then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local ray=camera:ScreenPointToRay(position.X,position.Y)
 if selectorView:commit(ray) then return end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={localFX,player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 if hit then assignField(hit.Instance) end
end)
connect(UIS.InputBegan,function(input,processed)
 if toolView and toolView:input(input,processed) then return end
 if input.KeyCode==Enum.KeyCode.Escape and logisticsView:isOpen() then logisticsView:close();return end
 if input.KeyCode==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false;return end
 if processed or UIS:GetFocusedTextBox() then return end
 if input.UserInputType==Enum.UserInputType.Touch then
  if selectorView.touch then selectorView.touch.active=false
  elseif not menusVisible() then selectorView.touch={input=input,start=input.Position,active=true} end
  return
 end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then
  local point=UIS:GetMouseLocation()
  if not tacticalHUD:blocksPoint(point-game:GetService('GuiService'):GetGuiInset()) then
   if selectorView:commit(mouse.UnitRay) then return end
   commandView:beginDrag();assignField(mouse.Target)
  end
  return
 end
 local key=input.KeyCode
 if menusVisible() and not modal.Visible then return end
 if key==Enum.KeyCode.Escape and modal.Visible then modal.Visible=false
 elseif not modal.Visible and (key==Enum.KeyCode.R or key==Enum.KeyCode.F or key==Enum.KeyCode.ButtonB) then if not logisticsView:recall() then command:FireServer('Recall') end
 elseif not modal.Visible and key==Enum.KeyCode.U then cargoAction()
 elseif not modal.Visible and key==Enum.KeyCode.L then command:FireServer('LaunchStorage')
 elseif not modal.Visible and key==Enum.KeyCode.C then logisticsView:cycle()
 elseif not modal.Visible and (key==Enum.KeyCode.Q or key==Enum.KeyCode.ButtonX) then command:FireServer('Evade')
 elseif not modal.Visible and (key==Enum.KeyCode.T or key==Enum.KeyCode.ButtonY) and player:GetAttribute('MA_TestingEnabled')==true then command:FireServer('TestLoadout')
 elseif key==Enum.KeyCode.ButtonR1 and not modal.Visible then
  local camera=workspace.CurrentCamera
  if camera then local ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2);if selectorView:commit(ray) then return end;local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={localFX,player.Character};local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params);if hit then assignField(hit.Instance) end end
 elseif not modal.Visible then
  -- Number keys belong to the custom tool hotbar. Field commands use rocks.
 end
end)
connect(UIS.InputChanged,function(input)
 local touch=selectorView.touch
 if touch and touch.input==input and (input.Position-touch.start).Magnitude>14 then touch.active=false end
end)
connect(UIS.InputEnded,function(input)
 if selectorView.touch and selectorView.touch.input==input then selectorView.touch=nil end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then commandView:endDrag() end
end)
local hudClock=0
local availabilitySignature=''
connect(RunService.Heartbeat,function(dt)
 hudClock=hudClock+dt;if hudClock<.2 then return end;hudClock=0
 local view=viewport();local l=currentLayout();local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 if menuStation then
  local hr=ownerRoot();local prompt=menuStation:FindFirstChildOfClass('ProximityPrompt')
  if not menuStation.Parent or not hr or not prompt or (hr.Position-menuStation.Position).Magnitude>prompt.MaxActivationDistance+3 then
   if modalMode~='offer' then modal.Visible=false end
   logisticsView:close();menuStation=nil
  end
 end
 recall.Position=UDim2.fromOffset(l.recallX,l.recallY);evade.Position=UDim2.fromOffset(l.evadeX,l.evadeY)
 recall.Size=UDim2.fromOffset(l.recallWidth,44);evade.Size=recall.Size
 recall.Text=touch and 'Recall' or 'Recall [R]';recall.Visible=not modal.Visible
 local testWidth=math.min(236,view.X-24)
 testLoadout.Size=UDim2.fromOffset(testWidth,44);testLoadout.Position=UDim2.fromOffset(view.X-testWidth-16,(view.X<680 or l.short) and 72 or 80)
 testLoadout.Text=touch and 'Random loadout · 2–5' or 'Random loadout · 2–5 [T]'
 testLoadout.Visible=player:GetAttribute('MA_TestingEnabled')==true and not modal.Visible
 if modal.Visible and (not modalSize or (modalSize-view).Magnitude>1) then refreshModal() end
 if modal.Visible and (modalMode=='offer' or modalMode=='pack' or modalMode=='prestige' or modalMode=='shop' or modalMode=='stars') then
  local action=modalMode=='offer' and 'ChooseCard' or modalMode=='pack' and 'BuyPack' or modalMode=='shop' and 'BuyUpgrade' or modalMode=='stars' and 'BuyStarUpgrade' or 'Prestige'
  local allowed,reason=availability(action);local signature=modalMode..':'..tostring(allowed)..':'..reason
  if signature~=availabilitySignature then availabilitySignature=signature;if modalMode=='offer' then updateOfferControls() else refreshModal() end end
 end
 if actionPending and os.clock()-actionPending.at>10 and not (profile and profile.pendingTransaction) then
  actionPending=nil;notice.Text='Still waiting for confirmation. You can retry.';noticeUntil=os.clock()+5;refreshModal()
 end
 if os.clock()>noticeUntil then notice.Text='' end
 local status=tostring(player:GetAttribute('MA_SaveStatus') or 'Loading'):lower()
 if status:find('preview') then saveLabel.Text=l.hudWidth<310 and 'UNSAVED PREVIEW' or 'PREVIEW · NOT SAVED'
 elseif status:find('loading') then saveLabel.Text='CONNECTING'
 elseif status:find('unavailable') then saveLabel.Text='PROFILE UNAVAILABLE'
 elseif status:find('saved') then saveLabel.Text='CREDITS · AUTOSAVED'
 else saveLabel.Text='SAVE PAUSED' end
 saveLabel.TextSize=12;saveLabel.Position=UDim2.new(1,-180,1,-24);saveLabel.Size=UDim2.fromOffset(168,20);saveLabel.TextXAlignment=Enum.TextXAlignment.Right
 saveLabel.Visible=not modal.Visible and (status:find('preview')~=nil or not status:find('saved'))
 saveLabel.TextColor3=status:find('preview') and Color3.fromRGB(255,211,96) or palette.muted
 if profile and profile.run then
  local amount=cargoUnits(profile);local capacity=profile.capacity or 40
  local packStation=world.Map:FindFirstChild('PackStation',true)
  local prompt=packStation and packStation:FindFirstChildOfClass('ProximityPrompt')
  if prompt then prompt.ActionText=Shops.packPromptText(profile.nextPackPrice or 0) end
  cargoText.Text=string.format('Backpack %s / %s',comma(amount),comma(capacity))
  cargoFill.Size=UDim2.fromScale(math.clamp(amount/math.max(1,capacity),0,1),1)
  cargoFill.BackgroundColor3=amount>=capacity and palette.accent or palette.mineral

 end
 local ownActive=false;local reprints={};local now=workspace:GetServerTimeNow()
 for source in pairs(drones) do
  if source:GetAttribute('Owner')==player.UserId then
   local state=source:GetAttribute('State');if state=='Attack' then ownActive=true end
   local at=source:GetAttribute('ReprintAt') or 0
   if at>now then table.insert(reprints,string.format('%s reprinting: %ds',source:GetAttribute('DroneName') or source:GetAttribute('Name') or 'Drone',math.ceil(at-now))) end
  end
 end
 evade.Visible=ownActive and not modal.Visible;evade.Text=touch and 'Evade shot' or 'Evade [Q]'
 soundscape:setContext(ownActive,modal.Visible)
 hud.Visible=not modal.Visible and not (l.short and ownActive)
 if not ownActive and (l.mobile or touch) and not l.actionAtTop then recall.Position=UDim2.fromOffset((view.X-l.recallWidth)/2,l.recallY) end
 if #reprints>0 and os.clock()>noticeUntil then notice.Text=#reprints>2 and tostring(#reprints)..' drones reprinting for free' or table.concat(reprints,' · ') end
 local hr=ownerRoot();local nearestEnemy,dist=nil,65
 if hr then for turret in pairs(turrets) do if turret.Parent then
  local hp=turret:GetAttribute('HP') or 0;local rootPart=turret.PrimaryPart or turret:FindFirstChildWhichIsA('BasePart',true)
  local n=rootPart and (rootPart.Position-hr.Position).Magnitude or math.huge
  if not fieldUnlocked(turret.Parent) and hp>0 and n<dist then nearestEnemy=turret;dist=n end
 end end end
 enemyHUD.Visible=nearestEnemy~=nil and ownActive and not modal.Visible
 local enemyWidth=math.min(300,view.X-24)
 enemyHUD.Size=UDim2.fromOffset(enemyWidth,58)
 enemyHUD.Position=(l.short or view.X<680) and UDim2.fromOffset(l.hudX,l.short and l.hudY or l.objectiveY) or UDim2.fromOffset(view.X-enemyWidth-16,12)
 if nearestEnemy then
  local hp=nearestEnemy:GetAttribute('HP') or 0;local maxHP=nearestEnemy:GetAttribute('MaxHP') or 1
  local charging=nearestEnemy:GetAttribute('Telegraph')
  enemyFill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,maxHP),0,1),1)
  enemyTitle.Text=charging and (touch and 'CHARGING · EVADE NOW' or 'CHARGING · EVADE [Q]') or string.format('PYRAMID SENTRY  %d / %d',math.ceil(hp),maxHP)
  enemyTitle.TextColor3=charging and Color3.fromRGB(255,195,195) or palette.white
 end
 local toastWidth=math.min(420,view.X-24)
 if l.short then toastWidth=l.hudWidth end
 toast.Size=UDim2.fromOffset(toastWidth,50)
 toast.Position=UDim2.fromOffset((view.X-toastWidth)/2,view.X>=1100 and 12 or (l.objectiveY+(enemyHUD.Visible and 66 or 0)))
 toast.Visible=notice.Text~='' and not modal.Visible and not (l.short and ownActive)
 if l.short then toast.Position=UDim2.fromOffset(l.hudX,l.hudY);if toast.Visible then hud.Visible=false end end
 if modal.Visible and notice.Text~='' and noticeUntil>os.clock() then
  modalSubtitle.Text=notice.Text;modalSubtitle.TextColor3=(modalMode=='offer' or modalMode=='pack') and palette.white or palette.text
 else modalSubtitle.Text=normalSubtitle;modalSubtitle.TextColor3=(modalMode=='offer' or modalMode=='pack') and Color3.fromRGB(202,209,231) or palette.muted end
 tacticalHUD:update(view,world,ownActive)
 unload.Text=touch and 'Sell' or 'Sell [U]'
 logisticsView:update(view,ownActive)
end)
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),refreshModal)
connect(gui.Destroying,function()
 local controls=player.PlayerGui:FindFirstChild('TouchGui');if controls and previousTouchEnabled~=nil then controls.Enabled=previousTouchEnabled end
 packView:destroy();commandView:destroy();selectorView:destroy();pickupView:destroy();rockDamage:destroy();roleEffectView:destroy();impactConnection:Disconnect()
 specialMiningFX:destroy();laserShowcase:destroy();logisticsView:destroy()
 for _,record in pairs(orbitalBurns) do record.connection:Disconnect() end
 orbitalBurns={}
 for source in pairs(roleAudio) do soundscape:stopLoop(source) end;roleAudio={}
 RunService:UnbindFromRenderStep('MiningAwayCameraRestore');RunService:UnbindFromRenderStep('MiningAwayCameraFeedback')
 if shakeCamera and workspace.CurrentCamera==shakeCamera then shakeCamera.CFrame=shakeCamera.CFrame*previousShake:Inverse() end
 abilityView.destroy()
 if toolView then toolView:destroy() end
 tacticalHUD:destroy()
 crystalAudio:destroy()
 soundscape:destroy()
 presentation:destroy()
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,c in pairs(observed) do c:Disconnect() end
 for part in pairs(hiddenParts) do if part.Parent then part.LocalTransparencyModifier=0 end end
 localFX:Destroy()
end)
