local A=require('../src/AudioFeedback')
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS audio '..name) end
local function sample(state)
 return {state=state,life=1,at=100,dead=false,paused=false,sale=0,saleAt=0}
end
check('late join reconstructs a sustained charge without replaying an action',function()
 local r={};local cues,mode=A.drone(r,sample('Warmup'),100)
 assert(#cues==0 and mode=='charge')
 cues=A.drone(r,sample('Warmup'),100.1);assert(#cues==0)
end)
check('charge release sounds once for the real state transition',function()
 local r={};A.drone(r,sample('Warmup'),100)
 local cues,mode=A.drone(r,sample('Mine'),100.1)
 assert(#cues==1 and cues[1]=='laser_start' and mode==nil)
 cues=A.drone(r,sample('Mine'),100.2);assert(#cues==0)
end)
check('every working drone has the correct sustained phase',function()
 for state,expected in pairs({Warmup='charge',BreakerWindup='breaker_charge',RepairCharge='repair_charge',Plant='grow_charge',Heal='healing',Pickup='transfer',Unload='transfer'}) do
  local _,mode=A.drone({},sample(state),100);assert(mode==expected,state)
 end
 local s=sample('Attack');s.chargeAt=100.4
 local _,mode=A.drone({},s,100);assert(mode=='combat_charge')
end)
check('pause death stale snapshots and new lives cannot replay old actions',function()
 for _,mutate in ipairs({function(s) s.paused=true end,function(s) s.dead=true end,function(s) s.at=90 end,function(s) s.life=2 end}) do
  local r={};A.drone(r,sample('Warmup'),100);local s=sample('Mine');mutate(s)
  local cues,mode=A.drone(r,s,100.1);assert(#cues==0 and mode==nil)
 end
 local r={};local s=sample('Warmup');s.paused=true;A.drone(r,s,100)
 local cues=A.drone(r,sample('Mine'),100.1);assert(#cues==0)
end)
check('courier sale requires an increasing fresh server receipt',function()
 local r={};A.drone(r,sample('Unload'),100)
 local s=sample('Follow');s.sale=1;s.saleAt=100.1
 local cues=A.drone(r,s,100.1);assert(#cues==1 and cues[1]=='courier_sale')
 cues=A.drone(r,s,100.2);assert(#cues==0)
 s.sale=2;s.saleAt=98;cues=A.drone(r,s,100.3);assert(#cues==0)
 s.saleAt=100.4;cues=A.drone(r,s,100.4);assert(#cues==0,'consumed stale serial must not replay')
end)
check('a physical unload is silent until confirmation and plays its world cue only for observers',function()
 for _,own in ipairs({true,false}) do
  local r={};local s=sample('Deliver');s.physical=true;s.ownCourier=own
  A.drone(r,s,100)
  s.state='Unload'
  local cues,mode=A.drone(r,s,100.1);assert(#cues==0 and mode==nil)
  s.state='Follow';s.sale=1;s.saleAt=100.2
  cues=A.drone(r,s,100.2)
  if own then assert(#cues==0) else assert(#cues==1 and cues[1]=='counter_settle') end
  assert(#A.drone(r,s,100.3)==0)
  assert(#A.drone({},s,100.3)==0,'late join replayed a sale')
 end
end)
check('ground receipts ignore initial state duplicates old timestamps and invalid numbers',function()
 local r={};assert(not A.serial(r,'ground',1,100,100))
 assert(not A.serial(r,'ground',1,100,100.1))
 assert(A.serial(r,'ground',2,100.2,100.2))
 assert(not A.serial(r,'ground',3,90,100.2))
 assert(not A.serial(r,'ground',3,100.3,100.3))
 assert(not A.fresh(0/0,100) and not A.fresh(math.huge,100) and not A.fresh(101,100))
end)
print(checks..' production audio event checks; not a listening or multiplayer test')
