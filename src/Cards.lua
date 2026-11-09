local Workshop=require('./Workshop')
local Shops=require('./Shops')
local DroneRoles=require('./DroneRoles')
-- Data-driven run modifiers. Complete resolved choices are saved before disclosure.
local C={CONTENT_VERSION=14,BASE_CAPACITY=100,LASER_CHARGE_SCALE=4}
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
local workEffects={mining=true,startup=true,yield=true,fork=true,geode=true,forkRange=true,plotAuto=true}
local combatOnly={combat=true,rate=true,crit=true,splash=true,chain=true,range=true,finisher=true,salvage=true}
local function sums(p,d,extra)
 local s={}
 local function add(c)
  local applies=affects(c,d)
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
 return math.floor(C.BASE_CAPACITY*clamp(1+n,.25,3)+.000001)+10*Workshop.starLevel(p,'backpack')
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
 local speed=clamp(1+(s.speed or 0),.1,3)
 local cutter=DroneRoles.isMiner(d.role or d.type)
 local interval=math.max(.15,b.shotInterval/math.max(.1,1+(s.rate or 0)))
 local damage=b.combatDPS*b.shotInterval*clamp(1+(s.combat or 0),.1,4)
 -- Cap the combined damage/rate product, rather than independently allowing 16×.
 local dps=math.min(b.combatDPS*4,damage/interval);damage=dps*interval
 return {miningDPS=not support(d) and b.miningDPS*clamp(1+(s.mining or 0),.1,4)*(1+(p.prestiges or 0)*.25) or 0,combatDPS=not support(d) and dps or 0,shotDamage=not support(d) and damage or 0,shotInterval=interval,
  maxHealth=b.maxHealth*clamp(1+(s.health or 0),.1,4),maxStep60=b.maxStep60*speed,speedMultiplier=speed,
  warmup=math.max(cutter and .05 or .08,b.warmup*(cutter and .5 or C.LASER_CHARGE_SCALE)/math.max(.1,1+(s.startup or 0))),range=b.range*clamp(1+(s.range or 0),.1,1.6),
  yieldMultiplier=clamp(1+(s.yield or 0),.1,2),damageReduction=clamp(s.reduction or 0,0,.5),critChance=clamp(s.crit or 0,0,.3),
  splashFraction=clamp(s.splash or 0,0,.25),splashRange=6+clamp(s.chain or 0,0,16),forkFraction=DroneRoles.isMiner(d.role or d.type) and clamp(s.fork or 0,0,forkCap) or 0,forkRange=DroneRoles.isMiner(d.role or d.type) and (6+clamp(s.forkRange or 0,0,6)) or 0,
  geodeMultiplier=1+clamp(s.geode or 0,0,.8),finisherMultiplier=1+clamp(s.finisher or 0,0,.75),salvageFraction=clamp(s.salvage or 0,0,.3),
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
local statLabels={batteryCapacity='Battery capacity',miningDPS='Mining / sec',combatDPS='Combat / sec',maxHealth='Hull',maxStep60='Flight speed',warmup='Laser warmup',range='Combat reach',yieldMultiplier='Ore yield',damageReduction='Damage blocked',critChance='Critical chance',splashFraction='Arc damage',splashRange='Arc reach',forkFraction='Split damage',forkRange='Split reach',geodeMultiplier='Geode damage',deepCutMultiplier='Deep crystal damage',finisherMultiplier='Finishing damage',salvageFraction='Repair on kill',entryShield='Entry shield',shotInterval='Shot interval',plotAuto='Automatic targeting',fullAuto='Courier speed bonus'}
local function vector(p,c)
 local out={capacity=C.capacity(p,c),magnetBonus=C.magnetBonus(p,c),orbitalLaser=Shops.abilityUnlocked(p,'Orbital',c) and 1 or 0,scrapSwarm=Shops.abilityUnlocked(p,'Scrap',c) and 1 or 0}
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
 if c.effects.capacity then table.insert(lines,{label='Backpack space',before=C.capacity(p),after=C.capacity(p,c),unit='ore'}) end
 if c.effects.magnetRange then table.insert(lines,{label='Extra pickup reach',before=C.magnetBonus(p),after=C.magnetBonus(p,c),unit='studs'}) end
 local target
 -- A fleet card can benefit Red while an already capped first Blue gains
 -- nothing. Show a drone that actually changes, rather than an empty example.
 for _,d in ipairs(p.fleet) do if affects(c,d) or (c.scope=='Player' and c.effects.fullAuto and courier(d)) then
  local before,after=C.stats(p,d),C.stats(p,d,c)
  for k in pairs(statLabels) do if math.abs(before[k]-after[k])>1e-8 then target=d;break end end
  if target then break end
 end end
 if target then
  local before,after=C.stats(p,target),C.stats(p,target,c)
  for _,k in ipairs({'batteryCapacity','miningDPS','combatDPS','maxHealth','maxStep60','warmup','range','yieldMultiplier','damageReduction','critChance','splashFraction','splashRange','forkFraction','forkRange','geodeMultiplier','deepCutMultiplier','finisherMultiplier','salvageFraction','entryShield','shotInterval','plotAuto','fullAuto'}) do
   if math.abs(before[k]-after[k])>1e-8 then
    local scale=k=='maxStep60' and 60 or 1
    local unit=(k=='warmup' or k=='shotInterval') and 's' or (k=='maxStep60' and 'studs/s' or ((k=='range' or k=='splashRange' or k=='forkRange') and 'studs' or ''))
    if k=='damageReduction' or k=='critChance' or k=='splashFraction' or k=='forkFraction' or k=='salvageFraction' then scale=100;unit='%' end
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
  if count<entry.max and entry.tier<=tier and (not entry.crystalRun or crystalRun) and (not entry.sideFields or not crystalRun) then
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
 for i=1,#pool-2 do
  for j=i+1,#pool-1 do
   if compatible[i][j] then
    for k=j+1,#pool do
     local guaranteed=pool[i].upgradeTier==tier or pool[j].upgradeTier==tier or pool[k].upgradeTier==tier
     if compatible[i][k] and compatible[j][k] and guaranteed then
      local weight=pool[i].upgradeTier+pool[j].upgradeTier+pool[k].upgradeTier
      total+=weight;table.insert(triples,{i,j,k,weight})
     end
    end
   end
  end
 end
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
 local replay=receipt(p,'Select',tx);if replay then return replay.offerId==offerId and replay.index==index and replay.runId==expectedRun,replay end
 context=context or {}
 if context.atDepot~=true or context.activeEncounter then return false,'Choose your card at the depot outside combat' end
 local offer=p.run.pendingOffer
 if not offer or offer.id~=offerId or offer.runId~=p.run.id then return false,'Offer is no longer pending' end
 if offer.opened==false then return false,'Open your delivered pack first' end
 if not finite(index) or index%1~=0 or index<1 or index>3 then return false,'Invalid card choice' end
 local c=clone(offer.choices[index]);if c.scope=='Individual' then
  local exists=false;for _,d in ipairs(p.fleet) do if d.id==c.targetDroneId then exists=true end end
  if not exists then return false,'Saved target missing; refund offer through migration' end
 end
 if c.workshop then
  local owned=Workshop.find(p,c.cardId);local before=owned and owned.level or 0
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
 local result={stars=stars,offerId=offer.id,runId=p.run.id,card=clone(c),index=index}
 record(p,'Select',tx,result);return true,result
end
function C.refundInvalidOffer(p)
 local o=p.run.pendingOffer;if not o then return false end
 local valid=o.runId==p.run.id and type(o.choices)=='table' and #o.choices==3
 if valid then
  for _,c in ipairs(o.choices) do
   if type(c.effects)~='table' then valid=false;break end
   if c.scope=='Individual' then local found=false;for _,d in ipairs(p.fleet) do if d.id==c.targetDroneId then found=true end end;if not found then valid=false;break end end
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
