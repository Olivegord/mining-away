-- Pure permanent ownership and run transactions. Durable storage commits working copies.
local P={SCHEMA=2,CONTENT=1}
local types={'Blue','Red','Green'}
local effectKeys={mining=true,speed=true,combat=true,health=true,reduction=true,capacity=true,startup=true,yield=true,range=true,crit=true,splash=true,fork=true,shield=true,rate=true}
local scopes={Fleet=true,Player=true,Color=true,Individual=true,Tradeoff=true}
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
 return {id=tostring(uid)..':run:'..index,index=index,credits=0,cargo={},saleEarnings=0,packIndex=0,cards={},pendingOffer=nil,offersWithoutCombat=0,wins={},entitlements={},yieldRemainders={}}
end
local function drone(uid,serial,kind,seed)
 local step=(20+((seed+serial*17)%31))/100
 local base=clone(P.BASE);local scale=P.TYPE_SCALES[kind]
 base.maxStep60=step*scale.speed;base.miningDPS=base.miningDPS*scale.mining;base.combatDPS=base.combatDPS*scale.combat
 return {id=tostring(uid)..':drone:'..serial,name=kind..' '..serial,type=kind,base=base}
end
function P.new(uid,seed)
 assert(finite(uid) and uid%1==0 and math.abs(uid)<1e14,'Invalid user ID')
 seed=integer(seed) and seed%2147483646 or (uid*7919+104729)%2147483646
 return {schemaVersion=P.SCHEMA,contentVersion=P.CONTENT,userId=uid,revision=0,prestiges=0,nextDroneSerial=2,seed=seed,fleet={drone(uid,1,'Blue',seed)},run=run(uid,1),receipts={},settings={}}
end
function P.validate(p,uid)
 if type(p)~='table' or p.schemaVersion~=P.SCHEMA or p.userId~=uid then return false,'Unsupported profile schema or owner' end
 if not integer(p.prestiges) or not integer(p.revision) or not integer(p.seed) or not integer(p.nextDroneSerial) then return false,'Invalid permanent counters' end
 if type(p.fleet)~='table' or #p.fleet~=p.prestiges+1 or #p.fleet<1 then return false,'Permanent fleet invariant violated' end
 local ids={}
 for serial,d in ipairs(p.fleet) do
  if type(d)~='table' or type(d.id)~='string' or #d.id>100 or ids[d.id] or type(d.name)~='string' or #d.name>80 or not table.find(types,d.type) or type(d.base)~='table' then return false,'Invalid permanent drone' end
  if d.id~=tostring(uid)..':drone:'..serial then return false,'Permanent drone ID does not match owner/serial' end
  ids[d.id]=true
  for _,k in ipairs({'miningDPS','combatDPS','maxHealth','maxStep60','warmup','range','shotInterval'}) do if not finite(d.base[k]) or d.base[k]<=0 or d.base[k]>1e6 then return false,'Invalid permanent base trait' end end
 end
 local r=p.run
 if type(r)~='table' or not integer(r.index) or r.index~=p.prestiges+1 or r.id~=tostring(uid)..':run:'..r.index then return false,'Invalid current run' end
 for _,k in ipairs({'credits','saleEarnings','packIndex','offersWithoutCombat'}) do if not integer(r[k]) then return false,'Invalid run counter '..k end end
 for _,k in ipairs({'cargo','cards','wins','entitlements','yieldRemainders'}) do if type(r[k])~='table' then return false,'Missing run state '..k end end
 for material,n in pairs(r.cargo) do if type(material)~='string' or #material>40 or not integer(n) then return false,'Invalid cargo' end end
 for field,n in pairs(r.wins) do if type(field)~='string' or not integer(n) then return false,'Invalid run wins' end end
 for material,n in pairs(r.yieldRemainders) do if type(material)~='string' or not finite(n) or n<0 or n>=1 then return false,'Invalid yield remainder' end end
 if #r.cards>500 then return false,'Invalid card count' end
 for _,c in ipairs(r.cards) do
  if type(c)~='table' or type(c.cardId)~='string' or type(c.effects)~='table' or not scopes[c.scope] then return false,'Invalid run card' end
  if c.scope=='Individual' and not ids[c.targetDroneId] then return false,'Missing permanent card target' end
  if c.scope=='Color' and not table.find(types,c.type) then return false,'Invalid card color' end
  for k,v in pairs(c.effects) do if not effectKeys[k] or not finite(v) or math.abs(v)>100 then return false,'Invalid modifier' end end
 end
 local offer=r.pendingOffer
 if offer~=nil then
  if type(offer)~='table' or type(offer.id)~='string' or offer.runId~=r.id or not integer(offer.price) or type(offer.choices)~='table' or #offer.choices~=3 then return false,'Invalid paid offer' end
  local seen={}
  for _,c in ipairs(offer.choices) do
   if type(c)~='table' or type(c.cardId)~='string' or seen[c.cardId] or type(c.effects)~='table' or not scopes[c.scope] then return false,'Invalid offer choice' end
   for effect,value in pairs(c.effects) do if not effectKeys[effect] or not finite(value) or math.abs(value)>100 then return false,'Invalid saved offer modifier' end end
   if c.scope=='Color' and not table.find(types,c.type) then return false,'Invalid saved offer color' end
   seen[c.cardId]=true
   if c.scope=='Individual' and not ids[c.targetDroneId] then return false,'Paid offer target missing' end
  end
 end
 if p.nextDroneSerial~=#p.fleet+1 then return false,'Invalid permanent serial' end
 if type(p.receipts)~='table' or #p.receipts>64 then return false,'Invalid receipt ledger' end
 for _,savedReceipt in ipairs(p.receipts) do if type(savedReceipt)~='table' or type(savedReceipt.operation)~='string' or type(savedReceipt.id)~='string' or #savedReceipt.id>128 or type(savedReceipt.result)~='table' then return false,'Invalid saved receipt' end end
 return true
end
function P.migrate(raw,uid,seed)
 if raw==nil then return nil,'No profile; explicit new-profile factory required' end
 if type(raw)~='table' then return nil,'Stored profile is not an object' end
 local p=clone(raw)
 if p.schemaVersion==1 then
  -- Supported v1 used the same permanent identities; do not reroll or multiply bases.
  if type(p.fleet)~='table' or not integer(p.prestiges) or type(p.run)~='table' then return nil,'Unsupported v1 ownership data' end
  p.schemaVersion=2;p.contentVersion=p.contentVersion or 1;p.revision=p.revision or 0;p.seed=p.seed or seed
  p.receipts=p.receipts or {};p.settings=p.settings or {};p.nextDroneSerial=p.nextDroneSerial or #p.fleet+1
  p.run.entitlements=p.run.entitlements or {};p.run.yieldRemainders=p.run.yieldRemainders or {};p.run.offersWithoutCombat=p.run.offersWithoutCombat or 0
 end
 -- A paid offer retains its full effect payload across catalog revisions. If its
 -- permanent target truly disappeared during a supported migration, refund the
 -- exact charged price atomically in this migrated working copy, never reroll.
 local pending=type(p.run)=='table' and p.run.pendingOffer
 if type(pending)=='table' and type(pending.choices)=='table' and type(p.fleet)=='table' then
  local ids={};for _,d in ipairs(p.fleet) do if type(d)=='table' then ids[d.id]=true end end
  local missing=false
  for _,choice in ipairs(pending.choices) do if type(choice)=='table' and choice.scope=='Individual' and not ids[choice.targetDroneId] then missing=true end end
  if missing then
   if not integer(pending.price) or not integer(p.run.credits) or p.run.credits+pending.price>=1e14 then return nil,'Cannot safely refund invalid saved offer' end
   p.run.credits=p.run.credits+pending.price;p.run.pendingOffer=nil;p.lastMigration='Refunded missing-target paid offer at full saved price'
  end
 end
 local ok,err=P.validate(p,uid);if not ok then return nil,err end
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
function P.cargoUnits(p) local total=0;for _,n in pairs(p.run.cargo) do total=total+n end;return total end
function P.addCargo(p,material,units,capacity)
 if type(material)~='string' or #material>40 or not integer(units) or not finite(capacity) or capacity<0 then return 0 end
 local accepted=math.min(units,math.max(0,math.floor(capacity)-P.cargoUnits(p)))
 p.run.cargo[material]=(p.run.cargo[material] or 0)+accepted;return accepted
end
function P.sell(p,prices,tx,expectedRun)
 local replay=P.receipt(p,'Sell',tx);if replay then return true,replay end
 if expectedRun~=p.run.id then return false,'Stale run' end
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid transaction ID' end
 local amount=0
 for material,n in pairs(p.run.cargo) do local value=prices[material];if not finite(value) or value<0 then return false,'Unknown material value' end;amount=amount+n*value end
 amount=math.floor(amount)
 if not integer(amount) or p.run.credits+amount>=1e14 or p.run.saleEarnings+amount>=1e14 then return false,'Sale limit exceeded' end
 p.run.cargo={};p.run.credits=p.run.credits+amount;p.run.saleEarnings=p.run.saleEarnings+amount
 local result={credits=amount,runId=p.run.id};P.record(p,'Sell',tx,result);return true,result
end
local milestones={{earnings=2000,field='Cobalt',wins=1},{earnings=5000,field='Cobalt',wins=2},{earnings=11000,field='Violet',wins=1},{earnings=22000,field='Violet',wins=2},{earnings=42000,field='Emerald',wins=1}}
P.MILESTONES=milestones
function P.milestone(p)
 local n=p.prestiges+1
 return clone(milestones[n] or {earnings=math.floor(42000*1.75^(n-5)),field='Emerald',wins=math.max(1,n-4)})
end
function P.nextType(p) return ({'Red','Green','Blue'})[(p.prestiges%3)+1] end
function P.prestigePreview(p)
 local m=P.milestone(p);local wins=p.run.wins[m.field] or 0
 local eligible=p.run.saleEarnings>=m.earnings and wins>=m.wins and p.run.pendingOffer==nil
 local reason=p.run.pendingOffer and 'Choose your purchased card before prestige' or (p.run.saleEarnings<m.earnings and 'Earn more cumulative sale credits' or (wins<m.wins and 'Complete the guarded-field objective' or 'Ready at the depot'))
 return {eligible=eligible,reason=reason,saleRequired=m.earnings,field=m.field,winsRequired=m.wins,wins=wins,earnings=p.run.saleEarnings,fleetBefore=#p.fleet,fleetAfter=#p.fleet+1,newType=P.nextType(p),cards=#p.run.cards,runId=p.run.id}
end
P.prestigeEligibility=P.prestigePreview
function P.prestige(p,tx,expectedRun,context)
 local replay=P.receipt(p,'Prestige',tx);if replay then return true,replay end
 if expectedRun~=p.run.id then return false,'Stale run' end
 if type(tx)~='string' or #tx<1 or #tx>128 then return false,'Invalid transaction ID' end
 context=context or {}
 if not context.atDepot or context.activeEncounter then return false,'Recall your own assault fleet and return to the depot' end
 if context.confirmed~=true then return false,'Explicit prestige confirmation required' end
 local preview=P.prestigePreview(p);if not preview.eligible then return false,preview.reason end
 local oldRun=p.run.id;local serial=p.nextDroneSerial;local awarded=drone(p.userId,serial,P.nextType(p),p.seed)
 table.insert(p.fleet,awarded);p.nextDroneSerial=serial+1;p.prestiges=p.prestiges+1;p.run=run(p.userId,p.prestiges+1)
 local result={oldRunId=oldRun,runId=p.run.id,droneId=awarded.id,droneType=awarded.type,fleetCount=#p.fleet,prestiges=p.prestiges}
 P.record(p,'Prestige',tx,result);return true,result
end
return P
