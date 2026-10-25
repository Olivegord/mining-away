-- Pure deterministic rules, shared by production and CLI tests. No yielding.
local R = {}
function R.finite(x)
 return type(x)=='number' and x==x and x>-math.huge and x<math.huge
end
function R.allowed(owner, caller, state)
 return owner==caller and state~='Destroyed' and state~='Reprinting'
end
function R.damage(resource, amount)
 if resource.paid or resource.hp<=0 or not R.finite(amount) or amount<=0 then return false end
 resource.hp=math.max(0,resource.hp-amount)
 if resource.hp==0 then resource.paid=true; return true end
 return false
end
function R.newEncounter(settings)
 settings=settings or {}
 return {gatherDuration=settings.Gather or 4, disengageDuration=settings.Disengage or 8, assaultDuration=settings.AssaultLimit or 90, resetDuration=settings.Reset or 6, clearDuration=settings.ClearWindow or 120,phase='Guarded', epoch=0, roster={}, users={}, spent={}, lastContact=0, deadline=0, untilTime=0, rewarded=false}
end
function R.gather(e, now)
 if e.phase~='Guarded' then return false end
 e.phase='Gathering'; e.untilTime=now+e.gatherDuration; e.epoch=e.epoch+1
 e.roster={}; e.users={}; e.spent={}; e.rewarded=false
 return true
end
function R.enroll(e, user, drones)
 if e.phase~='Gathering' or e.users[user] then return false end
 e.users[user]=true
 for _,d in ipairs(drones) do
  if d.hp>0 and d.state~='Reprinting' and d.state~='Destroyed' then
   e.roster[d.id]={user=user,life=d.life}
  end
 end
 return true
end
function R.participates(e,d)
 local r=e.roster[d.id]
 return e.phase=='Active' and r~=nil and r.life==d.life and not e.spent[d.id] and d.hp>0
end
function R.spend(e,id) e.spent[id]=true end
function R.reset(e,now)
 e.phase='Resetting'; e.untilTime=now+e.resetDuration
 e.roster={}; e.users={}; e.spent={}; e.rewarded=false
end
function R.step(e,now,alive,contact,defeated)
 if e.phase=='Gathering' and now>=e.untilTime then
  if alive==0 then R.reset(e,now); return 'reset' end
  e.phase='Active';e.deadline=now+e.assaultDuration;e.lastContact=now; return 'start'
 elseif e.phase=='Active' then
  -- Death/retreat is spent before this call. Wipe has priority over clear.
  if alive==0 or now>=e.deadline then R.reset(e,now);return 'reset' end
  if contact then e.lastContact=now end
  if now-e.lastContact>=e.disengageDuration then R.reset(e,now);return 'reset' end
  if defeated then
   e.phase='Cleared';e.untilTime=now+e.clearDuration
   if not e.rewarded then e.rewarded=true;return 'clear' end
  end
 elseif e.phase=='Cleared' and now>=e.untilTime then R.reset(e,now);return 'reset'
 elseif e.phase=='Resetting' and now>=e.untilTime then e.phase='Guarded';return 'guard'
 end
 return nil
end
function R.reprint(d, now, delay)
 d.hp=0;d.state='Destroyed';d.readyAt=now+delay;d.target=nil
end
function R.finishReprint(d, now, hull)
 if d.hp>0 or now<d.readyAt then return false end
 d.life=d.life+1;d.hp=hull;d.state='Follow';d.target=nil
 return true
end
return R
