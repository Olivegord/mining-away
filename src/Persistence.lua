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
