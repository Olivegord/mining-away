-- Deterministic economy/encounter MODEL using production domain modules.
-- Not Roblox Studio, a renderer, networking, collision, or measured player behavior.
local P=require('../src/Profile')
local Cards=require('../src/Cards')
local R=require('../src/Rules')
local Feel=require('../src/Feel')
local Mining=require('../src/Mining')
local Config=require('../src/Config')
local passed=0
local function test(name,f) local ok,err=pcall(f);assert(ok,name..': '..tostring(err));passed+=1;print('PASS progression '..name) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function rand(seed)
 local value=seed%2147483647
 return function(lo,hi) value=value*16807%2147483647;return lo+(hi-lo)*value/2147483647 end
end
local function travel(distance,step)
 local p,t=0,0
 while distance-p>1 do p=Feel.approachScalar(p,distance,step,1/60);t+=1/60;assert(t<120) end
 return t
end
local function length(a,b)
 local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
 return math.sqrt(x*x+y*y+z*z)
end
local home={x=0,y=7,z=0}
local function point(field,random)
 local roll=math.floor(random(50,101));local mineral=Mining.resource(roll,'Crystal',field.Hardness)
 local x=field.Offset[1]+random(-field.Size[1]/2+3,field.Size[1]/2-3)
 local z=field.Offset[3]+random(-field.Size[3]/2+3,field.Size[3]/2-3)
 return {x=x,y=field.Offset[2]+2+mineral.size/2+10,z=z},mineral.maxHP
end
local function encounter(p,field,seed)
 local e=R.newEncounter(Config);local fleet={};local random=rand(seed)
 for _,owned in ipairs(p.fleet) do
  local stats=Cards.stats(p,owned)
  table.insert(fleet,{id=owned.id,owner=p.userId,life=1,hp=stats.maxHealth,stats=stats,baseHull=owned.base.maxHealth,slot=#fleet+1,state='Attack',nextShot=4,shield=stats.entryShield})
 end
 R.gather(e,0);R.enroll(e,p.userId,p.run.id,fleet);R.step(e,4,#fleet,true,false)
 local turrets={};local trace={finisherShots=0,arcs=0,repairs=0,repairedHull=0}
 for n=1,field.Turrets do table.insert(turrets,{hp=field.TurretHP,x=(n-1)*17,y=0,z=0,nextShot=4,fireAt=nil,target=nil}) end
 local now=4
 while now<4+Config.AssaultLimit+.1 do
  -- Server fires drone shots before turretStep. Spatial model assumes in-range,
  -- unobstructed stationary stations and no dodge. Sentries stand 17 studs apart;
  -- the server's +11/14/8 X, +5 Y, +9 Z shot stations determine secondary reach.
  for _,d in ipairs(fleet) do
   if R.participates(e,d,p.run.id) and now+1e-7>=d.nextShot then
    local target
    for _,t in ipairs(turrets) do if t.hp>0 then target=t;break end end
    if target then
     local damage=d.stats.shotDamage
     if target.hp<=field.TurretHP*.35 then damage*=d.stats.finisherMultiplier;if d.stats.finisherMultiplier>1 then trace.finisherShots+=1 end end
     if d.stats.critChance>0 and random(0,1)<d.stats.critChance then damage*=2 end
     target.hp=math.max(0,target.hp-damage);R.markContribution(e,p.userId,p.run.id)
     local kills=target.hp<=0 and 1 or 0
     if d.stats.splashFraction>0 then
      local station={x=target.x+8+(d.slot%3)*3,y=5,z=9}
      for _,other in ipairs(turrets) do
       if other~=target and other.hp>0 and length(target,other)<=d.stats.splashRange and length(station,other)<=d.stats.range then
        other.hp=math.max(0,other.hp-damage*d.stats.splashFraction);trace.arcs+=1
        if other.hp<=0 then kills+=1 end
        break
       end
      end
     end
     if kills>0 and d.stats.salvageFraction>0 then
      local old=d.hp;d.hp=math.min(d.stats.maxHealth,d.hp+d.baseHull*d.stats.salvageFraction*kills)
      trace.repairs+=1;trace.repairedHull+=d.hp-old
     end
     d.nextShot=now+d.stats.shotInterval
    end
   end
  end
  for _,t in ipairs(turrets) do
   if t.hp>0 then
    if t.fireAt then
     if not t.target or t.target.hp<=0 then t.fireAt=nil;t.nextShot=now+1
     elseif now+1e-7>=t.fireAt then
      local d=t.target;local damage=field.Damage*(1-d.stats.damageReduction)
      local absorbed=math.min(d.shield,damage);d.shield-=absorbed;damage-=absorbed
      d.hp=math.max(0,d.hp-damage)
      if d.hp<=0 then R.spend(e,d.id) end
      t.fireAt=nil;t.nextShot=now+(field.ShotCooldown or 1.6)
     end
    elseif now+1e-7>=t.nextShot then
     -- Fixed deterministic nearest/slot tie-break in this spatial abstraction.
     local target
     for _,d in ipairs(fleet) do if d.hp>0 then target=d;break end end
     if target then t.target=target;t.fireAt=now+Config.Telegraph end
    end
   end
  end
  local alive=0;local remaining=0;local hp=0
  for _,d in ipairs(fleet) do if d.hp>0 then alive+=1;hp+=d.hp end end
  for _,t in ipairs(turrets) do remaining+=t.hp end
  local event=R.step(e,now,alive,true,remaining<=0)
  if event=='clear' then return true,now,hp,remaining,trace end
  if event=='reset' then return false,now,hp,remaining,trace end
  now+=1/60
 end
 return false,now,0,field.TurretHP*field.Turrets,trace
end
local function freshWorld(seed)
 local random=rand(seed);local fields={}
 for _,f in ipairs(Config.Fields) do
  local nodes={}
  for _=1,f.Count do local pos,hp=point(f,random);table.insert(nodes,{pos=pos,hp=hp,ready=Config.Grow,reserved=false}) end
  fields[f.Key]={cfg=f,nodes=nodes}
 end
 return {random=random,fields=fields,time=0,cargoRemainders={}}
end
local function mineHold(p,world,key)
 local wf=world.fields[key];local field=wf.cfg;local random=world.random
 local time=world.time;local capacity=Cards.capacity(p);local workers={}
 -- Walk to field center at normal 16 studs/s while drones leave depot.
 time+=math.sqrt(field.Offset[1]^2+field.Offset[3]^2)/16
 for _,owned in ipairs(p.fleet) do table.insert(workers,{owned=owned,stats=Cards.stats(p,owned),pos=home,at=time,target=nil}) end
 local function schedule(w)
  local best,score,completion;local readyAt=math.huge
  for _,n in ipairs(wf.nodes) do if not n.reserved then readyAt=math.min(readyAt,n.ready) end end
  local start=math.max(time,readyAt)
  for _,n in ipairs(wf.nodes) do
   if not n.reserved and n.ready<=start then
    local distance=length(w.pos,n.pos);local neighbors=0
    if w.owned.type=='Green' then for _,other in ipairs(wf.nodes) do if other~=n and other.ready<=start and length(n.pos,other.pos)<=Mining.RESONANCE_RANGE then neighbors+=1 end end end
    local node={kind='Crystal',hp=n.hp-Config.BreakCutoff,ore=field.Ore,hardness=field.Hardness,stage=0}
    local preference=Mining.targetScore(w.owned.type,w.stats,node,distance,neighbors)
    local finish=start+travel(distance,w.stats.maxStep60)+w.stats.warmup+Mining.duration(w.owned.type,'Crystal',node.hp,w.stats.miningDPS,w.stats.geodeMultiplier)
    if not score or preference<score then best=n;score=preference;completion=finish end
   end
  end
  if best then best.reserved=true;w.target=best;w.at=completion end
 end
 for _,w in ipairs(workers) do schedule(w) end
 local completions=0
 while P.cargoUnits(p)<capacity do
  local w
  for _,candidate in ipairs(workers) do if candidate.target and (not w or candidate.at<w.at) then w=candidate end end
  assert(w,'No modeled worker could reserve a crystal')
  time=w.at;local node=w.target;w.pos=node.pos;node.reserved=false
  local raw=field.Ore*w.stats.yieldMultiplier+(p.run.yieldRemainders[key] or 0)
  local units=math.floor(raw+.0000001);p.run.yieldRemainders[key]=raw-units
  P.addMiningCargo(p,key,units,capacity);completions+=1
  -- A broken ordinary node is unavailable for configured delay + 2s growth.
  node.pos,node.hp=point(field,random);node.ready=time+field.Respawn+Config.Grow
  w.target=nil
  if P.cargoUnits(p)<capacity then schedule(w) end
 end
 -- Cancel in-flight targets on a full hold; the last completed node is kept
 -- whole, including overfill, exactly as the production mining award rule.
 local returnTime=0
 for _,w in ipairs(workers) do
  if w.target then w.target.reserved=false;w.target=nil end
  returnTime=math.max(returnTime,travel(length(w.pos,home),w.stats.maxStep60))
 end
 local playerReturn=math.sqrt(field.Offset[1]^2+field.Offset[3]^2)/16
 world.time=time+math.max(returnTime,playerReturn)+1
 local prices={};for _,f in ipairs(Config.Fields) do prices[f.Key]=f.Value end
 local ok,result=P.sell(p,prices,'model-sale:'..p.run.id..':'..string.format('%.4f',world.time),p.run.id);assert(ok)
 return result.credits,completions
end
local function economicScore(p,choice)
 local total=0
 for _,owned in ipairs(p.fleet) do
  local stats=Cards.stats(p,owned,choice)
  -- Nearby 12-stud target metric uses original capped easing, not distance/speed.
  total+=1/(travel(12,stats.maxStep60)+stats.warmup+Mining.duration(owned.type,'Crystal',65,stats.miningDPS,stats.geodeMultiplier))*stats.yieldMultiplier
 end
 return total*(Cards.capacity(p,choice)/Cards.capacity(p))^.12
end
local function pick(p,offer,field,seed)
 local baseWin,_,baseHP,baseRemaining=encounter(p,field,seed)
 local best,bestScore=1,-math.huge
 for i,choice in ipairs(offer.choices) do
  local candidate=P.clone(p);table.insert(candidate.run.cards,P.clone(choice))
  local win,_,hp,remaining=encounter(candidate,field,seed)
  local score
  if not baseWin then
   -- Same combat seed for all three choices, no search across alternate packs.
   score=(win and 10000 or 0)+(baseRemaining-remaining)*10+(hp-baseHP)+economicScore(p,choice)
  else score=win and economicScore(p,choice) or -1e6 end
  if score>bestScore then bestScore=score;best=i end
 end
 return best
end
local function simulate(seed)
 local profile=P.new(4400+seed,seed*7919+31);local world=freshWorld(seed*104729+17)
 local reports={};local permanentIDs={profile.fleet[1].id}
 for runNumber=1,2 do
  local began=world.time;local firstPack=nil;local field='Quartz';local cleared=0;local packs=0;local attempts=0;local picked={};local entitled=false
  local required=P.milestone(profile)
  local needField=world.fields[required.field].cfg
  while world.time-began<7200 do
   local protected=world.fields[field].cfg.Turrets>0
   assert(not protected or entitled,'Model attempted mining without current expedition clearance')
   local _,broke=mineHold(profile,world,field);assert(broke>0)
   if protected then entitled=false end
   if profile.run.credits>=Cards.price(profile) and #profile.run.cards<12 then
    local ok,offer=Cards.buy(profile,'model-buy:'..profile.run.id..':'..packs,profile.run.id,{expectedPackIndex=profile.run.packIndex,combatVisible=true,atDepot=true})
    if ok then
     firstPack=firstPack or world.time-began;packs+=1
     local index=pick(profile,offer,needField,seed*101+runNumber)
     assert(Cards.select(profile,offer.id,index,'model-pick:'..offer.id,profile.run.id,{atDepot=true}))
     table.insert(picked,offer.choices[index].cardId..(offer.choices[index].targetDroneId and '@'..offer.choices[index].targetName or ''))
     world.time+=2
    end
   end
   -- After the first pack, use the higher-value safe Ruby option until a clear.
   if field=='Quartz' and packs>0 then field='Ruby' end
   local canWin,duration=encounter(profile,needField,seed*101+runNumber)
   if not canWin then field='Ruby' end
   if canWin and not P.prestigePreview(profile).eligible then
    if cleared>0 then world.time+=Config.ExpeditionGrace+Config.Reset end
    -- Fresh finite expedition restores every defense and resource population.
    local modeledField=world.fields[required.field];modeledField.nodes={}
    for _=1,needField.Count do local pos,hp=point(needField,world.random);table.insert(modeledField.nodes,{pos=pos,hp=hp,ready=world.time+Config.Grow,reserved=false}) end
    attempts+=1;world.time+=duration+2*math.sqrt(needField.Offset[1]^2+needField.Offset[3]^2)/16
    cleared+=1;profile.run.wins[required.field]=cleared;entitled=true
    field=required.field
   end
   if P.prestigePreview(profile).eligible then
    local old=profile.run.id
    assert(P.prestige(profile,'model-prestige:'..runNumber,old,{atDepot=true,confirmed=true}))
    eq(#profile.fleet,runNumber+1)
    for i,id in ipairs(permanentIDs) do eq(profile.fleet[i].id,id) end
    table.insert(permanentIDs,profile.fleet[#profile.fleet].id)
    eq(#profile.run.cards,0);eq(profile.run.credits,0);eq(P.cargoUnits(profile),0)
    table.insert(reports,{firstPack=firstPack,prestige=world.time-began,packs=packs,attempts=attempts,fleetBefore=runNumber,fleetAfter=#profile.fleet,cards=picked})
    break
   end
  end
  assert(#reports==runNumber,'Progression timed out at 2 model hours seed '..seed..' run '..runNumber)
 end
 return reports
end
local function summary(values)
 table.sort(values);return {minimum=values[1],median=values[math.ceil(#values/2)],maximum=values[#values]}
end
local reports={}
test('ten fixed seeds complete first prestige then a full two-drone second run',function()
 for seed=1,10 do local result=simulate(seed);reports[seed]=result;eq(result[1].fleetAfter,2);eq(result[2].fleetAfter,3) end
end)
test('safe field retains productive zero-card path and richer mineral values',function()
 local p=P.new(44,123);local w=freshWorld(9123);local credits,nodes=mineHold(p,w,'Quartz');eq(credits,120);assert(nodes>=12);assert(w.time>0)
 local ruby=P.new(44,123);local rubyWorld=freshWorld(9123);local sale=mineHold(ruby,rubyWorld,'Ruby');eq(sale,240)
end)
test('combat card changes finite Cobalt outcome while pure mining does not',function()
 local field=Config.Fields[3];local p=P.new(44,123);local naked=encounter(p,field,5);eq(naked,false)
 p.run.cards={{cardId='model-mining',scope='Fleet',effects={mining=2}}};eq(encounter(p,field,5),false)
 p.run.cards={{cardId='model-combat',scope='Fleet',effects={combat=.75,health=.75}}};eq(encounter(p,field,5),true)
end)
test('signature model resolves finishers, one eligible arc, and bounded built-in kill repair',function()
 local p=P.new(44,123)
 p.run.cards={{cardId='model-signature',scope='Fleet',effects={combat=3,health=3,reduction=.5,finisher=.75,salvage=.3,splash=.25,chain=16}}}
 local win,_,hull,_,trace=encounter(p,Config.Fields[4],7)
 eq(win,true);assert(trace.finisherShots>0);assert(trace.arcs>0);assert(trace.repairs>0 and trace.repairedHull>0)
 assert(trace.repairedHull<=p.fleet[1].base.maxHealth*.3*trace.repairs+.000001)
 assert(hull<=Cards.stats(p,p.fleet[1]).maxHealth)
 p.run.cards[1].effects.chain=nil
 local _,_,_,_,short=encounter(p,Config.Fields[4],7);eq(short.arcs,0)
end)
test('ten weak attempts reset all finite defenses without protected earnings',function()
 local p=P.new(44,123)
 for attempt=1,10 do local win=encounter(p,Config.Fields[3],attempt);eq(win,false);eq(p.run.saleEarnings,0);eq(P.cargoUnits(p),0);eq(#p.fleet,1) end
end)
test('mixed Burst Splash and pure Arc Relay both reach the real paired-guard spacing',function()
 local p=P.new(44,123);local target=p.fleet[1].id
 local function card(id)
  for _,entry in ipairs(Cards.CATALOG) do if entry.cardId==id then local c=P.clone(entry);c.targetDroneId=target;return c end end;error(id)
 end
 local defense={cardId='model-survival',scope='Fleet',effects={health=3,reduction=.5}}
 p.run.cards={P.clone(defense),card('D09')};local _,_,_,_,burst=encounter(p,Config.Fields[4],7)
 p.run.cards={P.clone(defense),card('D16')};local _,_,_,_,relay=encounter(p,Config.Fields[4],7)
 assert(burst.arcs>0,'Burst Splash never reached the 17-stud pair');assert(relay.arcs>0,'Arc Relay never reached the 17-stud pair')
end)
for run=1,2 do
 local packs,times,cardCounts={},{},{}
 for seed=1,10 do table.insert(packs,reports[seed][run].firstPack);table.insert(times,reports[seed][run].prestige);table.insert(cardCounts,reports[seed][run].packs) end
 local a,b,c=summary(packs),summary(times),summary(cardCounts)
 print(string.format('MODEL RUN %d FIRST_PACK_SECONDS min=%.2f median=%.2f max=%.2f PRESTIGE_SECONDS min=%.2f median=%.2f max=%.2f PACK_COUNT min=%d median=%d max=%d',run,a.minimum,a.median,a.maximum,b.minimum,b.median,b.maximum,c.minimum,c.median,c.maximum))
end
for seed=1,10 do
 for run=1,2 do local r=reports[seed][run];print(string.format('MODEL SEED %d RUN %d FIRST_PACK=%.2f PRESTIGE=%.2f PICKS=%s',seed,run,r.firstPack,r.prestige,table.concat(r.cards,','))) end
end
for n=1,6 do
 local p=P.new(77,123)
 for i=2,n do local m=P.milestone(p);p.run.saleEarnings=m.earnings;p.run.wins[m.field]=m.wins;assert(P.prestige(p,'fleet:'..i,p.run.id,{atDepot=true,confirmed=true})) end
 local w=freshWorld(9123);local credits=mineHold(p,w,'Ruby');local m=P.milestone(p)
 print(string.format('MODEL FLEET %d RUBY_FIRST_HOLD_SECONDS=%.2f CREDITS=%d PRESTIGE_SALES=%d REQUIREMENT=%s:%d',n,w.time,credits,m.earnings,m.field,m.wins))
 for fieldIndex=3,5 do
  local field=Config.Fields[fieldIndex];local win,time,hp,remaining=encounter(p,field,73)
  print(string.format('MODEL NAKED_COMBAT FLEET=%d FIELD=%s WIN=%s SECONDS=%.2f HULL_LEFT=%.2f TURRET_HP_LEFT=%.2f',n,field.Key,tostring(win),time,hp,remaining))
 end
end
print(passed..' progression model checks passed; shared hardness, type timing, selection estimate and whole-node cargo; no geodes, fork/echo damage, real collision, networking or Studio results')
