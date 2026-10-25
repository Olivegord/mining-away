-- Pure encounter and atomic resource rules. No yielding or Roblox dependencies.
-- The server supplies counts only after validating run/life/range and permanently
-- spending departed slots. Presentation state never authorizes combat or mining.
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
 return {
  gatherDuration=settings.Gather or 4,disengageDuration=settings.Disengage or 8,
  assaultDuration=settings.AssaultLimit or 90,resetDuration=settings.Reset or 6,
  prefix=settings.EncounterPrefix or 'encounter',phase='Guarded',epoch=0,id='',
  roster={},users={},spent={},entitlements={},lastContact=0,deadline=0,
  untilTime=0,rewarded=false,emptySince=nil,
 }
end

function R.gather(e,now)
 if e.phase~='Guarded' or not R.finite(now) then return false end
 e.phase='Gathering';e.untilTime=now+e.gatherDuration;e.epoch=e.epoch+1
 e.id=e.prefix..':'..tostring(e.epoch)
 e.roster={};e.users={};e.spent={};e.entitlements={};e.rewarded=false;e.emptySince=nil
 return true
end

-- One enrollment per user/run in this attempt, including if every original
-- participant has subsequently died. Reprinted lives never extend this roster.
function R.enroll(e,user,runId,drones)
 if e.phase~='Gathering' or e.users[user] or type(runId)~='string' or runId=='' or type(drones)~='table' then return false end
 local selected={}
 for _,d in ipairs(drones) do
  if type(d.id)=='string' and d.id~='' and not selected[d.id] and not e.roster[d.id]
   and (d.owner==nil or d.owner==user) and R.finite(d.hp) and d.hp>0
   and R.finite(d.life) and d.life>=1 and d.life%1==0
   and d.state~='Reprinting' and d.state~='Destroyed' then
   selected[d.id]={user=user,runId=runId,life=d.life,stats=clone(d.stats or {})}
  end
 end
 if next(selected)==nil then return false end
 e.users[user]={runId=runId,contributed=false,removed=false}
 for id,record in pairs(selected) do e.roster[id]=record end
 return true
end

function R.participates(e,d,runId)
 if not d then return false end
 local r=e.roster[d.id]
 local u=r and e.users[r.user]
 return e.phase=='Active' and r~=nil and u~=nil and not u.removed
  and r.runId==runId and u.runId==runId and (d.owner==nil or d.owner==r.user)
  and r.life==d.life and not e.spent[d.id] and R.finite(d.hp) and d.hp>0
  and d.state~='Destroyed' and d.state~='Reprinting'
end

function R.markContribution(e,user,runId)
 local u=e.users[user]
 if e.phase~='Active' or not u or u.removed or u.runId~=runId then return false end
 u.contributed=true;return true
end

function R.spend(e,id)
 if not e.roster[id] then return false end
 e.spent[id]=true;return true
end

-- Recall, disconnect or prestige removes only this player's participation.
-- The server's next ordinary step decides whether the entire expedition ended.
function R.removeUser(e,user,runId)
 local u=e.users[user]
 if not u or u.runId~=runId then return false end
 u.removed=true
 for id,r in pairs(e.roster) do if r.user==user and r.runId==runId then e.spent[id]=true end end
 local entitlement=e.entitlements[user]
 if entitlement and entitlement.runId==runId then e.entitlements[user]=nil end
 return true
end

function R.canMine(e,user,runId,encounterId)
 local entitlement=e.entitlements[user]
 return e.phase=='Cleared' and encounterId==e.id and entitlement~=nil
  and entitlement.runId==runId and entitlement.encounterId==encounterId
end

function R.reset(e,now)
 e.phase='Resetting';e.untilTime=now+e.resetDuration
 e.roster={};e.users={};e.spent={};e.entitlements={};e.rewarded=false;e.emptySince=nil
end

-- Counts represent currently eligible, unspent, living roster drones. A clear
-- additionally needs an actual contributor: empty/forged defeated flags cannot
-- mint entitlement. Expedition grace is based on active entitled crews, never a
-- global fixed countdown that respawns defenses over a legitimate mining crew.
function R.step(e,now,alive,contact,defeated,entitledActiveCount)
 if not R.finite(now) or not R.finite(alive) or alive<0 then return nil end
 if e.phase=='Gathering' and now>=e.untilTime then
  if alive==0 then R.reset(e,now);return 'reset' end
  e.phase='Active';e.deadline=now+e.assaultDuration;e.lastContact=now;return 'start'
 elseif e.phase=='Active' then
  -- Wipe/deadline wins a simultaneous final hit; no ghost crew victory.
  if alive==0 or now>=e.deadline then R.reset(e,now);return 'reset' end
  if contact then e.lastContact=now end
  if now-e.lastContact>=e.disengageDuration then R.reset(e,now);return 'reset' end
  if defeated then
   local entitled={}
   for user,u in pairs(e.users) do
    if u.contributed and not u.removed then entitled[user]={runId=u.runId,encounterId=e.id} end
   end
   if next(entitled)==nil then R.reset(e,now);return 'reset' end
   e.entitlements=entitled;e.phase='Cleared';e.untilTime=0;e.emptySince=nil
   if not e.rewarded then e.rewarded=true;return 'clear' end
  end
 elseif e.phase=='Cleared' then
  if R.finite(entitledActiveCount) and entitledActiveCount>0 then e.emptySince=nil
  elseif e.emptySince==nil then e.emptySince=now
  elseif now-e.emptySince>=e.disengageDuration then R.reset(e,now);return 'reset' end
 elseif e.phase=='Resetting' and now>=e.untilTime then
  e.phase='Guarded';return 'guard'
 end
 return nil
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
