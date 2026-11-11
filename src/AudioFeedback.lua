-- Pure audio event gating. Replicated state authorizes cues, never the reverse.
local A={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function A.fresh(at,now,age)
 return finite(at) and at>0 and finite(now) and now-at>=-.1 and now-at<=(age or .6)
end
function A.serial(record,key,serial,at,now)
 local before=record[key];record[key]=serial
 return finite(before) and finite(serial) and serial>before and A.fresh(at,now,.35)
end
local work={
 Warmup='charge',BreakerWindup='breaker_charge',RepairCharge='repair_charge',
 Plant='grow_charge',
 Heal='healing',Pickup='transfer',Unload='transfer',
}
local transition={Mine='laser_start',BreakerDive='dive',Heal='heal',Launch='parcel_latch',
 Unload='unload',SwarmActive='swarm_launch'}
function A.drone(record,s,now)
 local previous=record.sample;record.sample=table.clone(s)
 local audible=not s.dead and not s.paused and A.fresh(s.at,now)
 local mode=audible and work[s.state] or nil
 if s.physical and s.state=='Unload' then mode=nil end
 if audible and s.state=='Attack' and finite(s.chargeAt) and s.chargeAt>now then mode='combat_charge' end
 local cues={}
 if audible and previous and previous.life==s.life and not previous.dead and not previous.paused
  and A.fresh(previous.at,now,.7) then
  if previous.state~=s.state and transition[s.state] and not (s.physical and s.state=='Unload') then
   table.insert(cues,transition[s.state])
  end
  if A.serial(record,'sale',s.sale,s.saleAt,now) then
   if not s.physical then table.insert(cues,'courier_sale')
   elseif not s.ownCourier then table.insert(cues,'counter_settle') end
  end
 else record.sale=s.sale end
 return cues,mode
end
return A
