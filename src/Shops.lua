-- Pure mineral economy. Catalog prices are provisional playtest tuning;
-- ownership, quoted levels, spending and receipts are server transactions.
local S={ORDER={'Quartz','Ruby','Cobalt','Violet','Emerald'},PACK_CURRENCY='Quartz'}
S.COLORS={Quartz={180,225,213},Ruby={226,75,112},Cobalt={89,150,234},Violet={166,115,217},Emerald={70,184,139}}
local function item(id,shop,title,description,info,cost,max,effects,unlock,role)
 return {id=id,shop=shop,title=title,description=description,info=info,cost=cost,max=max or 1,effects=effects or {},unlock=unlock,role=role}
end
S.CATALOG={
 item('quartz_power','Quartz','Mining power','+50% base mining power per level','Adds 50% of base mining power to every mining drone per level. Four levels; stacks with cards up to the 4× run cap. Permanent prestige power applies on top. Resets on prestige.',20,4,{mining=.5}),
 item('quartz_scanner','Quartz','Auto target','Miners pick rocks in the selected field','Earn automatic target selection. Click a cleared field once; workers keep choosing ready crystals until you recall or leave. Does not empty your backpack.',40,1,{plotAuto=1}),
 item('quartz_backpack','Quartz','Bigger backpack','+20 ore capacity per level','Adds 50% of the starting 40-unit backpack per level. Shared with capacity cards; total capacity is capped at 120. Whole final crystal drops are preserved.',30,3,{capacity=.5}),
 item('quartz_ruby','Quartz','Unlock Ruby','Opens the Ruby field and shop','Spend Quartz once to open Ruby for this run. Ruby purchases then spend Ruby. Guard clearances remain permanent.',80,1,nil,'Ruby'),
 item('ruby_cobalt','Ruby','Unlock Cobalt','Opens the Cobalt field and shop','Opens Cobalt this run. Its pyramid guard must still be defeated before mining; buying access never bypasses combat.',144,1,nil,'Cobalt'),
 item('ruby_pack_speed','Ruby','Fast pack reveal','2× faster card reveal','Halves the reveal and stagger of your three saved cards. Does not change prices, odds, saved choices or network/save time. You still choose one.',48,1,{packSpeed=1}),
 item('ruby_rotors','Ruby','Faster drones','+25% flight speed per level','Faster travel and courier trips, with the original eased arrival. Adds to speed cards up to the existing 3× flight cap.',36,2,{speed=.25}),
 item('cobalt_violet','Cobalt','Unlock Violet','Opens the Violet field and shop','Opens Violet this run. Its stronger guards remain a separate fleet challenge.',180,1,nil,'Violet'),
 item('cobalt_orbital','Cobalt','Orbital laser','Strike the biggest ready rock','Unlocks a mining ability. Charge above a cleared field, then automatically melt its biggest ready rock over four seconds. Server cooldown and field limits apply.',60,1,{orbitalLaser=1}),
 item('cobalt_pack_discount','Cobalt','Cheaper packs','15% off packs per level','Reduces future Quartz pack prices by 15 percentage points per level, up to 30%. Already-paid offers keep their exact saved price and three choices.',45,2,{packDiscount=.15}),
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
function S.reason(p,entry,context)
 if not S.unlocked(p,entry.shop) then return 'Unlock '..entry.shop..' first' end
 if entry.id=='cobalt_orbital' and S.abilityUnlocked(p,'Orbital') then return 'Orbital laser already installed' end
 if entry.id=='violet_scrap' and S.abilityUnlocked(p,'Scrap') then return 'Scrap swarm already installed' end
 if entry.id=='ruby_pack_speed' and S.packSpeed(p)>=2 then return 'Pack reveal already accelerated' end
 if entry.id=='quartz_scanner' then for _,c in ipairs(p.run.cards) do if (c.effects.plotAuto or 0)>0 then return 'Plot targeting already installed' end end end
 if entry.id=='quartz_backpack' then
  local capacity=S.effects(p).capacity or 0
  for _,c in ipairs(p.run.cards) do capacity=capacity+(c.effects.capacity or 0) end
  if capacity>=2 then return 'Backpack already at 120 ore' end
 end
 if entry.role then
  local aliases={Blue='Striker',Red='Charger',Green='Medic'};local found=false
  for _,d in ipairs((context and context.fleet) or p.activeFleet or p.fleet) do if (aliases[d.role or d.type] or d.role or d.type)==entry.role then found=true end end
  if not found then return 'Requires '..entry.role..' hardware' end
 end
 if entry.id=='violet_courier' then
  local found=false;for _,d in ipairs(p.fleet) do if d.role=='Courier' then found=true end end
  if not found then return 'Requires a Courier drone' end
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
