-- Data-driven run modifiers. Complete resolved choices are saved before disclosure.
local C={CONTENT_VERSION=2,BASE_CAPACITY=120}
local function clone(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=clone(x) end;return o end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function finite(x) return type(x)=='number' and x==x and x>-math.huge and x<math.huge end
local function card(id,title,scope,effects,description,kind)
 return {cardId=id,title=title,scope=scope,effects=effects,description=description,type=kind,expires='This run'}
end
C.CATALOG={
 card('F01','Sharper Beams','Fleet',{mining=.15},'+15% mining output'),
 card('F02','Fast Rotors','Fleet',{speed=.20},'+20% flight speed'),
 card('F03','Combat Calibration','Fleet',{combat=.20},'+20% combat shot damage'),
 card('F04','Reinforced Frames','Fleet',{health=.20},'+20% maximum hull; heal only the added hull'),
 card('F05','Ceramic Plating','Fleet',{reduction=.10},'10 percentage points less turret damage'),
 card('F06','Cargo Lattice','Player',{capacity=.25},'+25% shared cargo capacity'),
 card('F07','Warm Emitters','Fleet',{startup=.30},'+30% laser startup rate'),
 card('F08','Clean Extraction','Fleet',{yield=.10},'+10% ore units; uses matching cargo space'),
 card('C01','Blue Afterburners','Color',{speed=1},'+100% Blue flight speed: 2× alone','Blue'),
 card('C02','Blue Lenses','Color',{mining=.35},'+35% Blue mining output','Blue'),
 card('C03','Red Targeting','Color',{combat=.45},'+45% Red combat shot damage','Red'),
 card('C04','Red Bulkheads','Color',{health=.40},'+40% Red maximum hull; heal only added hull','Red'),
 card('C05','Green Recovery','Color',{yield=.25},'+25% ore units awarded by Green drones','Green'),
 card('C06','Green Ignition','Color',{startup=.75},'+75% Green laser startup rate','Green'),
 card('D01','Diamond Tip','Individual',{mining=.65},'+65% mining output for this named drone'),
 card('D02','Battle Emitter','Individual',{combat=.75},'+75% combat shot damage for this named drone'),
 card('D03','Titanium Hull','Individual',{health=.75},'+75% maximum hull; heal only the added hull'),
 card('D04','Racing Rotors','Individual',{speed=.70},'+70% flight speed for this named drone'),
 card('D05','Instant Ignition','Individual',{startup=1},'+100% startup rate: half warmup alone; damage unchanged'),
 card('D06','Long Lens','Individual',{range=.40},'+40% combat working range; command radius unchanged'),
 card('D07','Turret Insulation','Individual',{reduction=.25},'25 percentage points less turret damage'),
 card('D08','Critical Optics','Individual',{crit=.15},'15% server-rolled chance of a double combat hit'),
 card('D09','Burst Splash','Individual',{splash=.25},'Combat hit splashes 25% to one eligible nearby turret'),
 card('D10','Fracture Fork','Individual',{fork=.20},'Mining tick forks 20% to one eligible nearby crystal'),
 card('D11','Entry Shield','Individual',{shield=.20},'Absorb 20% built-in hull once per fresh assault'),
 card('D12','Rapid Cycling','Individual',{rate=.35},'+35% combat firing rate; final DPS remains capped'),
 card('D13','Execution Lens','Individual',{finisher=.75},'+75% shot damage against sentries below 35% hull'),
 card('D14','Core Drill','Individual',{geode=.80,speed=-.15},'+80% mining damage to geode shells and cores; −15% flight speed'),
 card('D15','Salvage Reactor','Individual',{salvage=.30},'Destroy a sentry to repair 30% built-in hull on this drone'),
 card('D16','Arc Relay','Individual',{splash=.25,chain=16},'Arc 25% shot damage to one other sentry within 22 studs'),
 card('F09','Prism Splitter','Fleet',{fork=.20,forkRange=6},'Split 20% mining damage into one other crystal within 12 studs'),
 card('T01','Glass Cutter','Tradeoff',{mining=.35,health=-.15},'+35% mining output; −15% maximum hull'),
 card('T02','Battle Formation','Tradeoff',{combat=.30,mining=-.10},'+30% combat shot damage; −10% mining output'),
 card('T03','Heavy Cargo','Tradeoff',{capacity=.35,speed=-.10},'+35% cargo capacity; −10% flight speed'),
 card('T04','Hot Emitters','Tradeoff',{startup=.40,health=-.10},'+40% startup rate; −10% maximum hull'),
}
local fallback={
 card('R01','Mining Reserve','Fleet',{mining=.10},'+10% mining output; repeatable until cap'),
 card('R02','Combat Reserve','Fleet',{combat=.10},'+10% combat shot damage; repeatable until cap'),
 card('R03','Cargo Reserve','Player',{capacity=.10},'+10% cargo capacity; repeatable until cap'),
}
local combatEffects={combat=true,health=true,reduction=true,crit=true,splash=true,shield=true,rate=true,finisher=true,salvage=true,chain=true}
local function isCombat(c)
 for stat,n in pairs(c.effects) do if combatEffects[stat] and n>0 then return true end end;return false
end
local function affects(c,d)
 return c.scope=='Fleet' or c.scope=='Tradeoff' or (c.scope=='Color' and c.type==d.type) or (c.scope=='Individual' and c.targetDroneId==d.id)
end
local function sums(p,d,extra)
 local s={}
 local function add(c)
  if affects(c,d) then for k,n in pairs(c.effects) do s[k]=(s[k] or 0)+n end end
 end
 for _,c in ipairs(p.run.cards) do add(c) end
 if extra then add(extra) end
 return s
end
function C.capacity(p,extra)
 local n=0
 for _,c in ipairs(p.run.cards) do n=n+(c.effects.capacity or 0) end
 if extra then n=n+(extra.effects.capacity or 0) end
 return math.floor(C.BASE_CAPACITY*clamp(1+n,.25,3)+.000001)
end
function C.stats(p,d,extra)
 local b=d.base;local s=sums(p,d,extra)
 local speed=clamp(1+(s.speed or 0),.1,3)
 local interval=math.max(.15,b.shotInterval/math.max(.1,1+(s.rate or 0)))
 local damage=b.combatDPS*b.shotInterval*clamp(1+(s.combat or 0),.1,4)
 -- Cap the combined damage/rate product, rather than independently allowing 16×.
 local dps=math.min(b.combatDPS*4,damage/interval);damage=dps*interval
 return {miningDPS=b.miningDPS*clamp(1+(s.mining or 0),.1,4),combatDPS=dps,shotDamage=damage,shotInterval=interval,
  maxHealth=b.maxHealth*clamp(1+(s.health or 0),.1,4),maxStep60=b.maxStep60*speed,speedMultiplier=speed,
  warmup=math.max(.08,b.warmup/math.max(.1,1+(s.startup or 0))),range=b.range*clamp(1+(s.range or 0),.1,1.6),
  yieldMultiplier=clamp(1+(s.yield or 0),.1,2),damageReduction=clamp(s.reduction or 0,0,.5),critChance=clamp(s.crit or 0,0,.3),
  splashFraction=clamp(s.splash or 0,0,.25),splashRange=6+clamp(s.chain or 0,0,16),forkFraction=clamp(s.fork or 0,0,.2),forkRange=6+clamp(s.forkRange or 0,0,6),
  geodeMultiplier=1+clamp(s.geode or 0,0,.8),finisherMultiplier=1+clamp(s.finisher or 0,0,.75),salvageFraction=clamp(s.salvage or 0,0,.3),
  entryShield=b.maxHealth*clamp(s.shield or 0,0,.2),capacity=C.capacity(p,extra)}
end
function C.price(p)
 local n=p.run.packIndex;local prices={80,110,150,210,290,400}
 if n<6 then return prices[n+1] end
 local price=400;for _=7,n+1 do price=math.floor(price*1.3+.5);if price>1e12 then return 1e12 end end;return price
end
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
local statLabels={miningDPS='Mining / sec',combatDPS='Combat / sec',maxHealth='Hull',maxStep60='Flight speed',warmup='Laser warmup',range='Combat reach',yieldMultiplier='Ore yield',damageReduction='Damage blocked',critChance='Critical chance',splashFraction='Arc damage',splashRange='Arc reach',forkFraction='Split damage',forkRange='Split reach',geodeMultiplier='Geode damage',finisherMultiplier='Finishing damage',salvageFraction='Repair on kill',entryShield='Entry shield',shotInterval='Shot interval'}
local function vector(p,c)
 local out={capacity=C.capacity(p,c)}
 for _,d in ipairs(p.fleet) do
  local st=C.stats(p,d,c)
  for k in pairs(statLabels) do if k~='shotInterval' then out[d.id..':'..k]=k=='warmup' and -st[k] or st[k] end end
 end
 return out
end
local function countOwned(p,c)
 local n=0
 for _,owned in ipairs(p.run.cards) do if owned.cardId==c.cardId and (c.scope~='Individual' or owned.targetDroneId==c.targetDroneId) then n=n+1 end end
 return n
end
local function stackLimit(c)
 if c.cardId=='F09' then return 1 end
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
local function compatible(a,b)
 -- Avoid mechanically dominated subsets/supersets in a single equally priced offer.
 local age,bge,agt,bgt=true,true,false,false
 for k,x in pairs(a._vector) do
  local y=b._vector[k]
  if x<y-1e-8 then age=false;bgt=true elseif x>y+1e-8 then bge=false;agt=true end
 end
 return not ((age and agt) or (bge and bgt) or (age and bge))
end
local function category(c)
 if c.effects.combat or c.effects.rate or c.effects.crit or c.effects.splash or c.effects.finisher then return 'combat'
 elseif c.effects.health or c.effects.reduction or c.effects.shield or c.effects.salvage then return 'survival'
 elseif c.effects.capacity or c.effects.yield then return 'cargo'
 elseif c.effects.mining or c.effects.fork or c.effects.geode then return 'mining'
 elseif c.effects.startup then return 'startup' else return 'flight' end
end
local function preview(p,c)
 local lines={}
 if c.effects.capacity then table.insert(lines,{label='Shared cargo',before=C.capacity(p),after=C.capacity(p,c),unit='ore'}) end
 local target
 for _,d in ipairs(p.fleet) do if affects(c,d) then target=d;break end end
 if target then
  local before,after=C.stats(p,target),C.stats(p,target,c)
  for _,k in ipairs({'miningDPS','combatDPS','maxHealth','maxStep60','warmup','range','yieldMultiplier','damageReduction','critChance','splashFraction','splashRange','forkFraction','forkRange','geodeMultiplier','finisherMultiplier','salvageFraction','entryShield','shotInterval'}) do
   if math.abs(before[k]-after[k])>1e-8 then
    local scale=k=='maxStep60' and 60 or 1
    local unit=(k=='warmup' or k=='shotInterval') and 's' or (k=='maxStep60' and 'studs/s' or ((k=='range' or k=='splashRange' or k=='forkRange') and 'studs' or ''))
    if k=='damageReduction' or k=='critChance' or k=='splashFraction' or k=='forkFraction' or k=='salvageFraction' then scale=100;unit='%' end
    if k=='geodeMultiplier' or k=='finisherMultiplier' or k=='yieldMultiplier' then unit='×' end
    table.insert(lines,{label=statLabels[k],before=before[k]*scale,after=after[k]*scale,unit=unit})
   end
  end
 end
 return lines
end
local function resolve(p,entry,seed,combatVisible)
 if (isCombat(entry) or entry.effects.range) and not combatVisible then return nil end
 local c=clone(entry)
 if c.scope=='Color' then
  local exists=false;for _,d in ipairs(p.fleet) do if d.type==c.type then exists=true;break end end;if not exists then return nil end
 elseif c.scope=='Individual' then
  local eligible={}
  for _,d in ipairs(p.fleet) do c.targetDroneId=d.id;if beneficial(p,c) then table.insert(eligible,d) end end
  if #eligible==0 then return nil end
  table.sort(eligible,function(a,b) return a.id<b.id end)
  local d=eligible[rng(hash(tostring(seed)..':'..c.cardId..':target'))(#eligible)]
  c.targetDroneId=d.id;c.targetName=d.name;c.type=d.type
 end
 if not beneficial(p,c) then return nil end
 c.preview=preview(p,c);c._vector=vector(p,c);c._category=category(c);c.category=c._category
 local purposes={combat='Break through guarded fields',survival='Keep your assault alive',cargo='Bring home more each trip',mining='Clear crystals faster',startup='Less waiting between crystals',flight='Reach the next crystal faster'}
 local headlines={D13='FINISH THE FIGHT',D14='CRACK THE CORE',D15='KILLS REPAIR HULL',D16='CHAIN YOUR SHOTS',F09='MINE TWO AT ONCE',C01='+100% BASE FLIGHT SPEED',D05='+100% STARTUP RATE'}
 c.headline=headlines[c.cardId] or string.upper(c._category..' upgrade');c.purpose=purposes[c._category]
 c.tradeoff=(c.cardId=='D14' and '15% slower flight') or (c.cardId=='T01' and '15% less hull') or (c.cardId=='T02' and '10% slower mining') or (c.cardId=='T03' and '10% slower flight') or (c.cardId=='T04' and '10% less hull') or 'No drawback'
 c.stackText=stackLimit(c)==1 and 'Unique for this target · this run' or ('Copy '..(countOwned(p,c)+1)..' of '..stackLimit(c)..' · adds to base · this run')
 return c
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
function C.buy(p,tx,expectedRun,context)
 if not validID(tx) then return false,'Invalid transaction ID' end
 local replay=receipt(p,'Buy',tx);if replay then return true,replay end
 if expectedRun~=p.run.id then return false,'Stale run' end
 if p.run.pendingOffer then return true,clone(p.run.pendingOffer) end
 context=context or {}
 if context.expectedPackIndex~=p.run.packIndex then return false,'Stale pack index' end
 if context.atDepot~=true or context.activeEncounter then return false,'Resolve packs at the depot outside combat' end
 local price=C.price(p);if p.run.credits<price then return false,'Not enough credits' end
 local seed=hash(table.concat({p.seed,p.userId,p.run.index,p.run.packIndex+1,C.CONTENT_VERSION},':'))
 local random=rng(seed);local pool={}
 for _,entry in ipairs(C.CATALOG) do local c=resolve(p,entry,seed,context.combatVisible==true);if c then table.insert(pool,c) end end
 local function addFallback()
  for _,entry in ipairs(fallback) do local c=resolve(p,entry,seed,context.combatVisible==true);if c then table.insert(pool,c) end end
 end
 if #pool<6 then addFallback() end
 for i=#pool,2,-1 do local n=random(i);pool[i],pool[n]=pool[n],pool[i] end
 local chosen={}
 local function pairOK(c) for _,other in ipairs(chosen) do if c.cardId==other.cardId or not compatible(c,other) then return false end end;return true end
 local requireCombat=context.combatVisible and p.run.offersWithoutCombat>=2
 if requireCombat then for _,c in ipairs(pool) do if isCombat(c) then table.insert(chosen,c);break end end end
 -- Early packs always expose a behavior-changing build direction when eligible.
 -- The saved offer/target still comes entirely from this deterministic server pool.
 local function signature(c) local e=c.effects;return e.finisher or e.geode or e.salvage or e.chain or e.forkRange end
 if p.run.packIndex<3 then for _,c in ipairs(pool) do if signature(c) and pairOK(c) then table.insert(chosen,c);break end end end
 while #chosen<3 do
  local best,bestScore=nil,-math.huge
  for _,c in ipairs(pool) do
   if pairOK(c) then
    local score=0
    for _,other in ipairs(chosen) do if other._category~=c._category then score=score+3 end;if other.scope~=c.scope then score=score+1 end end
    if score>bestScore then best=c;bestScore=score end
   end
  end
  if not best then break end;table.insert(chosen,best)
 end
 -- If the first greedy choices conflict, bounded search finds a valid distinct triple.
 if #chosen<3 then
  chosen={}
  for i=1,#pool do
   for j=i+1,#pool do
    if compatible(pool[i],pool[j]) then
     for k=j+1,#pool do
      if compatible(pool[i],pool[k]) and compatible(pool[j],pool[k]) and (not requireCombat or isCombat(pool[i]) or isCombat(pool[j]) or isCombat(pool[k])) then chosen={pool[i],pool[j],pool[k]};break end
     end
    end
    if #chosen==3 then break end
   end
   if #chosen==3 then break end
  end
 end
 if #chosen~=3 then return false,'No three useful distinct choices remain; pursue your prestige objective' end
 local hasCombat=false
 for _,c in ipairs(chosen) do hasCombat=hasCombat or isCombat(c);c._vector=nil;c._category=nil end
 local offer={id=p.run.id..':pack:'..(p.run.packIndex+1),runId=p.run.id,contentVersion=C.CONTENT_VERSION,seed=seed,packIndex=p.run.packIndex+1,price=price,choices=chosen,expires='This run'}
 p.run.credits=p.run.credits-price;p.run.packIndex=p.run.packIndex+1;p.run.pendingOffer=clone(offer)
 if context.combatVisible then p.run.offersWithoutCombat=hasCombat and 0 or p.run.offersWithoutCombat+1 end
 record(p,'Buy',tx,offer);return true,clone(offer)
end
function C.select(p,offerId,index,tx,expectedRun,context)
 if not validID(tx) then return false,'Invalid transaction ID' end
 local replay=receipt(p,'Select',tx);if replay then return true,replay end
 if expectedRun~=p.run.id then return false,'Stale run' end
 context=context or {}
 if context.atDepot~=true or context.activeEncounter then return false,'Choose your card at the depot outside combat' end
 local offer=p.run.pendingOffer
 if not offer or offer.id~=offerId or offer.runId~=p.run.id then return false,'Offer is no longer pending' end
 if not finite(index) or index%1~=0 or index<1 or index>3 then return false,'Invalid card choice' end
 local c=clone(offer.choices[index]);if c.scope=='Individual' then
  local exists=false;for _,d in ipairs(p.fleet) do if d.id==c.targetDroneId then exists=true end end
  if not exists then return false,'Saved target missing; refund offer through migration' end
 end
 -- No mutable catalog lookup: the complete paid choice is the contract.
 table.insert(p.run.cards,c);p.run.pendingOffer=nil
 local result={offerId=offer.id,runId=p.run.id,card=clone(c),index=index}
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
 p.run.credits=p.run.credits+math.floor(o.price);p.run.pendingOffer=nil
 return true,'Full saved pack price refunded; no reroll'
end
return C
