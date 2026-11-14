-- Server-owned guard participation and atomic resource damage.
-- Plot clears are permanent profile unlocks; no timed expeditions or closed rosters.
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
 return {phase='Guarded',id=(settings.EncounterPrefix or 'plot')..':guards',roster={},users={}}
end
function R.begin(e)
 if e.phase=='Guarded' then e.phase='Active';return true end
 return false
end
function R.enroll(e,user,runId,drones)
 if e.phase~='Active' or type(runId)~='string' or type(drones)~='table' then return false end
 local selected={}
 for _,d in ipairs(drones) do
  if type(d.id)=='string' and d.owner==user and R.finite(d.hp) and d.hp>0
   and R.finite(d.life) and d.life>=1 and d.life%1==0
   and d.state~='Destroyed' and d.state~='Reprinting' then
   selected[d.id]={user=user,runId=runId,life=d.life,stats=clone(d.stats or {})}
  end
 end
 if next(selected)==nil then return false end
 e.users[user]={runId=runId,contributed=false}
 for id,record in pairs(selected) do e.roster[id]=record end
 return true
end
function R.participates(e,d,runId)
 if not d then return false end
 local r=e.roster[d.id];local u=r and e.users[r.user]
 return e.phase=='Active' and r~=nil and u~=nil and r.runId==runId and u.runId==runId
  and d.owner==r.user and r.life==d.life and R.finite(d.hp) and d.hp>0
  and d.state~='Destroyed' and d.state~='Reprinting'
end
function R.markContribution(e,user,runId)
 local u=e.users[user]
 if e.phase~='Active' or not u or u.runId~=runId then return false end
 u.contributed=true;return true
end
function R.spend(e,id)
 local present=e.roster[id]~=nil;e.roster[id]=nil;return present
end
function R.removeUser(e,user,runId)
 local u=e.users[user]
 if not u or u.runId~=runId then return false end
 e.users[user]=nil
 for id,r in pairs(e.roster) do if r.user==user then e.roster[id]=nil end end
 return true
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
