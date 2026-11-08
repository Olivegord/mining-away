local Persistence=require('../src/Persistence')
local checks=0
local function check(name,fn)
 local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks=checks+1;print('PASS persistence '..name)
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function clone(v) return Persistence.clone(v) end
local function backend()
 local b={values={},calls=0,failBefore=0,failAfter=0,callbacks=1}
 function b:update(key,transform)
  self.calls=self.calls+1
  if self.failBefore>0 then self.failBefore=self.failBefore-1;error('unavailable before update') end
  local next
  for i=1,self.callbacks do next=transform(clone(self.values[key])) end
  if next~=nil then self.values[key]=clone(next) end
  if self.failAfter>0 then self.failAfter=self.failAfter-1;error('response lost after commit') end
  return clone(next)
 end
 return b
end
local function options(owner,clock)
 return {owner=owner,now=function() return clock.now end,wait=function(delay) table.insert(clock.waits,delay) end,
  leaseSeconds=30,maxAttempts=3,receiptLimit=8,
  newProfile=function(userId) return {schemaVersion=2,userId=userId,revision=0,credits=0,prestiges=0,fleet={'d1'},cargo=0} end,
  migrate=function(data,userId)
   if type(data)~='table' or (data.schemaVersion~=1 and data.schemaVersion~=2) or data.userId~=userId then return nil,'invalid-profile' end
   data=clone(data);data.schemaVersion=2;data.revision=data.revision or 0;data.cargo=data.cargo or 0;return data
  end,
  validate=function(data,userId)
   return type(data)=='table' and data.schemaVersion==2 and data.userId==userId and type(data.credits)=='number' and data.credits>=0 and type(data.fleet)=='table' and #data.fleet==data.prestiges+1
  end}
end
local function fixture()
 local b=backend();local c={now=100,waits={}};local m=Persistence.new(b,options('job-A',c));return m,b,c
end
check('fresh profile acquires locked durable session',function()
 local m,b=fixture();local s=assert(m:load(1));eq(#s.data.fleet,1);eq(s.mode,'Durable');eq(s.revision,0);eq(m:healthy(s),true)
 eq(b.values['player:1'].lock.token,s.token);eq(s.busy,false)
end)
check('duplicate server load rejected and active foreign session blocked',function()
 local m,b,c=fixture();assert(m:load(1));local s,e=m:load(1);eq(s,nil);eq(e,'already-loaded')
 local other=Persistence.new(b,options('job-B',c));local x,err=other:load(1);eq(x,nil);eq(err,'session-locked');eq(b.values['player:1'].lock.owner,'job-A')
end)
check('bounded ordered retries preserve exact candidate',function()
 local m,b,c=fixture();local s=assert(m:load(1));b.failBefore=2
 local invokes=0
 local ok,r=m:transaction(s,'purchase-1',function(p) invokes=invokes+1;p.credits=40;return {offer='frozen-offer'} end)
 eq(ok,true);eq(r.offer,'frozen-offer');eq(invokes,1);eq(#c.waits,2);eq(c.waits[1],.1);assert(c.waits[2]>.29 and c.waits[2]<.31)
 eq(s.data.credits,40);eq(s.revision,1)
end)
check('UpdateAsync callback retries do not reroll prepared mutation',function()
 local m,b=fixture();local s=assert(m:load(1));b.callbacks=4;local calls=0
 eq(m:transaction(s,'roll-1',function(p) calls=calls+1;p.offer={target='d1',seed=129};return p.offer end),true)
 eq(calls,1);eq(s.data.offer.seed,129);eq(s.revision,1)
end)
check('transaction is durable before local state is exposed',function()
 local m,b=fixture();local s=assert(m:load(1));local update=b.update
 function b:update(key,fn) eq(s.data.credits,0);return update(self,key,fn) end
 eq(m:transaction(s,'credit-1',function(p) p.credits=9;return {amount=9} end),true)
 eq(s.data.credits,9);eq(b.values['player:1'].data.credits,9)
end)
check('duplicate transaction returns original result without callback',function()
 local m=fixture();local s=assert(m:load(1));local calls=0
 eq(m:transaction(s,'prestige-1',function(p) calls=calls+1;p.prestiges=1;table.insert(p.fleet,'d2');return {drone='d2'} end),true)
 local ok,r=m:transaction(s,'prestige-1',function() error('must not run twice') end)
 eq(ok,true);eq(r.drone,'d2');eq(calls,1);eq(#s.data.fleet,2);eq(s.revision,1)
end)
check('mutation rejection and invalid staged schema never save',function()
 local m,b=fixture();local s=assert(m:load(1));local n=b.calls
 local ok,err=m:transaction(s,'bad-1',function() return nil,'not-eligible' end);eq(ok,false);eq(err,'not-eligible')
 eq(m:transaction(s,'bad-2',function(p) p.prestiges=8;return true end),false)
 eq(m:transaction(s,'bad-3',function() error('mutation failed') end),false)
 eq(s.data.prestiges,0);eq(s.revision,0);eq(b.calls,n);eq(s.busy,false)
end)
check('save and reentrant operations share one serialization gate',function()
 local m,b=fixture();local s=assert(m:load(1));s.data.cargo=35
 eq(m:transaction(s,'outer',function(p)
  local ok,err=m:save(s);eq(ok,false);eq(err,'profile-busy');p.credits=2;return true
 end),true)
 eq(s.data.cargo,35);eq(m:save(s),true);eq(b.values['player:1'].data.cargo,35)
end)
check('transient response loss reconciles same receipt exactly once',function()
 local m,b=fixture();local s=assert(m:load(1));b.failAfter=1;local calls=0
 eq(m:transaction(s,'once',function(p) calls=calls+1;p.credits=p.credits+50;return {paid=50} end),true)
 eq(calls,1);eq(s.data.credits,50);eq(s.revision,1);eq(#b.values['player:1'].receipts,1)
end)
check('uncertain committed write freezes until durable reconciliation',function()
 local m,b=fixture();local s=assert(m:load(1));b.failAfter=3
 local ok,err=m:transaction(s,'ambiguous',function(p) p.credits=100;return {paid=100} end)
 eq(ok,false);eq(err,'save-unavailable');eq(s.data.credits,0);eq(s.readOnly,true);eq(s.pending.id,'ambiguous')
 eq(m:transaction(s,'second',function(p) p.credits=999;return true end),false)
 local done,r=m:reconcile(s);eq(done,true);eq(r.paid,100);eq(s.data.credits,100);eq(s.revision,1);eq(s.readOnly,false)
end)
check('confirmed uncommitted failure preserves pre-transaction dirty cargo',function()
 local m,b=fixture();local s=assert(m:load(1));s.data.cargo=17;b.failBefore=3
 eq(m:transaction(s,'missed',function(p) p.credits=999;return true end),false)
 eq(s.data.credits,0);eq(s.data.cargo,17);local ok,r=m:reconcile(s);eq(ok,true);eq(r.committed,false)
 eq(s.data.cargo,17);eq(s.data.credits,0);eq(m:save(s),true);eq(b.values['player:1'].data.cargo,17)
end)
check('failed initial load never creates or overwrites defaults',function()
 local m,b=fixture();b.values['player:1']={schemaVersion=2,userId=1,revision=0,credits=999,prestiges=0,fleet={'d1'},cargo=42}
 b.failBefore=3;local s,err=m:load(1);eq(s,nil);eq(err,'load-unavailable');eq(b.values['player:1'].credits,999);eq(b.values['player:1'].cargo,42)
end)
check('malformed future and foreign profile refuse migration without data loss',function()
 for _,bad in ipairs({{schemaVersion=999,userId=1,credits=600},{schemaVersion=2,userId=8,credits=700},{storageVersion=8,data={credits=800}}}) do
  local m,b=fixture();b.values['player:1']=clone(bad);local s=m:load(1);eq(s,nil)
  if bad.storageVersion then eq(b.values['player:1'].storageVersion,8) else eq(b.values['player:1'].credits,bad.credits) end
 end
end)
check('explicit legacy migration retains owned fleet and progress',function()
 local m,b=fixture();b.values['player:1']={schemaVersion=1,userId=1,credits=319,prestiges=1,fleet={'old-a','old-b'}}
 local s=assert(m:load(1));eq(s.data.schemaVersion,2);eq(s.data.credits,319);eq(s.data.fleet[2],'old-b');eq(s.data.cargo,0)
end)
check('lease expiry permits takeover and fences old stale writes',function()
 local m,b,c=fixture();local old=assert(m:load(1));c.now=131;eq(m:healthy(old),false)
 local other=Persistence.new(b,options('job-B',c));local fresh=assert(other:load(1));fresh.data.credits=99;eq(other:save(fresh),true)
 old.data.credits=1000;local ok,err=m:save(old);eq(ok,false);eq(err,'session-lost');eq(old.lost,true);eq(b.values['player:1'].data.credits,99)
end)
check('unexpected profile revision cannot overwrite concurrent durable state',function()
 local m,b=fixture();local s=assert(m:load(1));b.values['player:1'].revision=10;b.values['player:1'].data.credits=881
 local ok,err=m:save(s);eq(ok,false);eq(err,'revision-conflict');eq(s.readOnly,true);eq(b.values['player:1'].data.credits,881)
end)
check('autosave renews lease and persists latest legitimate progress',function()
 local m,b,c=fixture();local s=assert(m:load(1));c.now=120;s.data.credits=71
 eq(m:save(s),true);eq(s.leaseUntil,150);eq(b.values['player:1'].data.credits,71);eq(s.revision,1)
end)
check('release saves and clears lock atomically before a new server loads',function()
 local m,b,c=fixture();local s=assert(m:load(1));s.data.credits=444;eq(m:release(s),true);eq(s.closed,true);eq(b.values['player:1'].lock,nil)
 local other=Persistence.new(b,options('job-B',c));local fresh=assert(other:load(1));eq(fresh.data.credits,444)
 eq(m:release(s),true);eq(b.values['player:1'].lock.owner,'job-B')
end)
check('ambiguous release is reconciled even after its lock was removed',function()
 local m,b=fixture();local s=assert(m:load(1));s.data.credits=63;b.failAfter=3
 eq(m:release(s),false);eq(s.closed,false);eq(s.readOnly,true);eq(b.values['player:1'].lock,nil)
 eq(m:reconcile(s),true);eq(s.closed,true);eq(s.data.credits,63)
end)
check('receipt ledger stays bounded and current retry remains available',function()
 local m,b=fixture();local s=assert(m:load(1))
 for i=1,20 do eq(m:transaction(s,'tx'..i,function(p) p.credits=i;return {n=i} end),true) end
 eq(#b.values['player:1'].receipts,8);eq(b.values['player:1'].receipts[1].id,'tx13')
 local ok,r=m:transaction(s,'tx20',function() error('replay') end);eq(ok,true);eq(r.n,20)
end)
check('serializability finite values and invalid identity fail safely',function()
 local m=fixture();eq(m:load(0),nil);eq(m:load(0/0),nil);eq(m:load('1'),nil)
 local s=assert(m:load(1));eq(m:transaction(s,string.rep('x',241),function() return true end),false)
 eq(m:transaction(s,'bad-fn',function(p) p.functionValue=function() end;return true end),false)
 eq(m:transaction(s,'bad-number',function(p) p.credits=math.huge;return true end),false);eq(s.busy,false)
end)
check('preview storage is explicitly labeled and namespace isolated',function()
 local c={now=100,waits={}};local a=Persistence.new(Persistence.previewAdapter('test-A'),options('preview',c))
 local s=assert(a:load(77));assert(string.find(s.mode,'not saved'));s.data.credits=90;eq(a:release(s),true)
 local b=Persistence.new(Persistence.previewAdapter('test-B'),options('preview',c));local different=assert(b:load(77));eq(different.data.credits,0)
 local again=Persistence.new(Persistence.previewAdapter('test-A'),options('preview',c));eq(assert(again:load(77)).data.credits,90)
end)
check('crash after commit reloads the durable result without repeating the grant',function()
 local m,b,c=fixture();local s=assert(m:load(1));b.failAfter=3
 eq(m:transaction(s,'prestige-crash',function(p) p.prestiges=1;table.insert(p.fleet,'d2');return {drone='d2'} end),false)
 c.now=131;local nextServer=Persistence.new(b,options('job-after-crash',c));local loaded=assert(nextServer:load(1))
 eq(loaded.data.prestiges,1);eq(#loaded.data.fleet,2)
 local ok,r=nextServer:transaction(loaded,'prestige-crash',function() error('duplicate permanent drone') end)
 eq(ok,true);eq(r.drone,'d2');eq(#loaded.data.fleet,2)
 eq(m:reconcile(s),false);eq(s.lost,true)
end)
check('failed final save keeps lock and previous data until reconciled',function()
 local m,b=fixture();local s=assert(m:load(1));s.data.cargo=88;b.failBefore=3
 eq(m:release(s),false);eq(s.closed,false);eq(b.values['player:1'].lock.token,s.token);eq(b.values['player:1'].data.cargo,0)
 eq(m:reconcile(s),true);eq(s.data.cargo,88);eq(m:release(s),true);eq(b.values['player:1'].data.cargo,88);eq(b.values['player:1'].lock,nil)
end)
check('corrupt lock cannot be interpreted as an unlocked valid profile',function()
 local m,b=fixture();local s=assert(m:load(1));local old=clone(b.values['player:1']);old.lock={owner='job-bad',token='bad',expiresAt='never'};b.values['player:1']=old
 local other=Persistence.new(b,options('job-other',{now=200,waits={}}));local loaded,err=other:load(1)
 eq(loaded,nil);eq(err,'corrupt-lock');eq(b.values['player:1'].data.userId,1);eq(s.data.userId,1)
end)
local Profile=require('../src/Profile')
local Cards=require('../src/Cards')
local function realOptions(owner,c)
 local o=options(owner,c);o.newProfile=function(uid) return Profile.new(uid,42) end;o.migrate=Profile.migrate;o.validate=Profile.validate;return o
end
check('actual Profile missing-target migration refund is durable before presentation',function()
 local b=backend();local c={now=100,waits={}};local profile=Profile.new(1,42);profile.run.wallet.Quartz=200
 local ok,offer=Cards.buy(profile,'migration-buy',profile.run.id,{atDepot=true,activeEncounter=false,combatVisible=true,expectedPackIndex=0});eq(ok,true)
 offer.choices[1]={cardId='D05',scope='Individual',targetDroneId='removed-drone',effects={startup=1},title='Lost target'}
 profile.run.pendingOffer=offer;local afterDebit=profile.run.wallet.Quartz;b.values['player:1']=clone(profile)
 local m=Persistence.new(b,realOptions('real-A',c));local s=assert(m:load(1))
 eq(s.data.run.pendingOffer,nil);eq(s.data.run.wallet.Quartz,afterDebit+offer.price);eq(b.values['player:1'].data.run.pendingOffer,nil)
 eq(b.values['player:1'].data.run.wallet.Quartz,s.data.run.wallet.Quartz);eq(s.data.run.packIndex,1)
 eq(m:release(s),true);local again=Persistence.new(b,realOptions('real-B',c));eq(assert(again:load(1)).data.run.wallet.Quartz,afterDebit+offer.price)
end)
check('actual Profile prestige crash retains identities and exactly one permanent grant',function()
 local b=backend();local c={now=100,waits={}};local m=Persistence.new(b,realOptions('real-A',c));local s=assert(m:load(1))
 local original=clone(s.data.fleet);s.data.run.saleEarnings=2000;s.data.run.quartzEarnings=2000;s.data.run.wins.Cobalt=1
 local runId=s.data.run.id;b.failAfter=3
 eq(m:transaction(s,'storage-prestige',function(p)
  local ok,r=Profile.prestige(p,'domain-prestige',runId,{atDepot=true,activeEncounter=false,confirmed=true})
  if ok then return r end;return nil,r
 end),false)
 eq(#s.data.fleet,4);eq(s.readOnly,true);c.now=131
 local freshStore=Persistence.new(b,realOptions('real-B',c));local loaded=assert(freshStore:load(1))
 eq(#loaded.data.fleet,5);eq(loaded.data.fleet[5].type,'Red')
 for i,d in ipairs(original) do eq(loaded.data.fleet[i].id,d.id);for trait,value in pairs(d.base) do eq(loaded.data.fleet[i].base[trait],value) end end
 local ok,r=freshStore:transaction(loaded,'storage-prestige',function() error('must not prestige twice') end);eq(ok,true);eq(r.fleetCount,5);eq(#loaded.data.fleet,5)
end)

check('signed Studio identities are accepted only by explicit isolated preview adapter',function()
 local c={now=100,waits={}}
 local preview=Persistence.new(Persistence.previewAdapter('signed-Studio-test'),realOptions('preview-owner',c))
 local one=assert(preview:load(-1));local two=assert(preview:load(-2));local zero=assert(preview:load(0))
 eq(one.data.userId,-1);eq(two.data.userId,-2);eq(zero.data.userId,0);eq(one.data.fleet[1].id,'-1:drone:1')
 local live=Persistence.new(backend(),realOptions('live-owner',c))
 eq(live:load(-1),nil);eq(live:load(-2),nil);eq(live:load(0),nil)
end)
print(checks..' FINAL persistence tests passed (deterministic storage adapter; live DataStore not executed)')
