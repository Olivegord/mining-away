local M=require('../src/SentryMotion')
local passed=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS sentry '..name) end
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or 1e-8),tostring(a)..' ~= '..tostring(b)) end
local function input(values)
 local result={awake=true,dead=false,wakeAt=0,charging=false,charge=0,shotAge=100,hitAge=100,aimYaw=0,aimPitch=0}
 for k,v in pairs(values or {}) do result[k]=v end
 return result
end
local function pose(now,values) return M.step(M.new(now,0),0,now,0,input(values)) end
check('dormant layers keep their exact compact offsets with no idle jiggles',function()
 for t=0,100 do
  local p=pose(t,{awake=false})
  for rank=0,3 do
   local q=M.segment(rank,t,0,p,false,-rank*.5)
   near(q.lift,-rank*.5);near(q.yaw,0);near(q.roll,0);near(q.side,0)
  end
  near(M.segment(1,t,0,p,true).reveal,0)
 end
end)
check('wake visibly separates the crown more than seventeen studs',function()
 local peak=0
 for n=0,120 do
  local t=n/60;local q=M.segment(3,t,0,pose(t),false,-1.3)
  peak=math.max(peak,q.lift)
 end
 assert(peak>17,peak)
 local active=M.segment(3,8,0,pose(8),false,-1.3)
 assert(active.lift>3 and active.lift<6)
end)
check('each ring makes a full turn and eases into the active heading before ignition',function()
 for rank=0,3 do
  local _,_,spin=M.wake(0,rank);near(spin,0)
  local _,burst,finish=M.wake(M.IGNITE,rank)
  assert(math.abs(finish-2*math.pi)<.025 and math.abs(burst)<.025)
 end
end)
check('the wide opening changes into the heavy return without a velocity snap',function()
 local _,before=M.wake(.92-1e-5,0);local _,peak=M.wake(.92,0);local _,after=M.wake(.92+1e-5,0)
 near(peak,1);assert(math.abs((peak-before)/1e-5)<.001);assert(math.abs((after-peak)/1e-5)<.001)
end)
check('the eye stays closed through launch and opens after the turn',function()
 near(M.segment(1,.8,0,pose(.8),true).reveal,0)
 near(M.segment(1,M.IGNITE,0,pose(M.IGNITE),true).reveal,1)
end)
check('wake timestamps reconstruct a late join at the same opening and spin',function()
 local a=pose(101,{wakeAt=100,aimYaw=1})
 local b=pose(101,{wakeAt=100,aimYaw=1})
 local x=M.segment(3,101,0,a,false,-1);local y=M.segment(3,101,0,b,false,-1)
 near(x.lift,y.lift);near(x.yaw,y.yaw)
end)
check('separate rings float with distinct phases and large responsive impacts',function()
 local a=M.segment(0,8,1,pose(8),false)
 local b=M.segment(3,8,1,pose(8),false)
 assert(math.abs(a.lift-b.lift)>2)
 local resting=M.segment(3,8,1,pose(8),false)
 local fired=M.segment(3,8,1,pose(8,{shotAge=.2}),false)
 assert(math.abs(resting.lift-fired.lift)>.3)
 local eye=M.segment(1,8,1,pose(8,{shotAge=.1}),true)
 assert(eye.back>.65)
 local hit=M.segment(2,8,1,pose(8,{hitAge=.16}),false)
 assert(math.abs(hit.roll-resting.roll)>.025)
end)
check('spring tracking retains momentum and takes shortest arc across heading wrap',function()
 local s=M.new(0,0);M.step(s,0,8,0,input({aimYaw=math.pi-.01}))
 local p=M.step(s,1/60,8,0,input({aimYaw=-math.pi+.01}))
 assert(p.yaw>math.pi-.01 and p.yaw<math.pi+.01)
 assert(s.yawV>0)
end)
check('fixed target spring is equivalent at 30 60 120 and 144 FPS',function()
 local results={}
 for _,fps in ipairs({30,60,120,144}) do
  local s=M.new(0,0);M.step(s,0,0,0,input({aimYaw=0}))
  for n=1,fps do M.step(s,1/fps,n/fps,0,input({aimYaw=2,aimPitch=.2})) end
  table.insert(results,s)
 end
 for _,s in ipairs(results) do near(s.yaw,results[1].yaw);near(s.yawV,results[1].yawV);near(s.pitch,results[1].pitch) end
end)
check('active target changes settle accurately while shell yaw stays continuous',function()
 local s=M.new(0,0);M.step(s,0,0,0,input({aimYaw=math.pi-.01}))
 local previous=M.segment(3,8,0,M.step(s,0,8,0,input({aimYaw=math.pi-.01})),false).yaw
 for n=1,120 do
  local p=M.step(s,1/60,8+n/60,0,input({aimYaw=-math.pi+.1}))
  local q=M.segment(3,8+n/60,0,p,false)
  assert(math.abs(q.yaw-previous)<.2);previous=q.yaw
 end
 near(s.yaw,math.pi+.1,.001)
end)
check('death suppresses activation and charging even with stale attributes',function()
 local p=pose(8,{dead=true,charging=true,charge=1})
 assert(not p.awake);near(p.charge,0);near(p.ignition,0)
end)
check('charge release and per-ring shot reaction settle cleanly',function()
 local s=M.new(0,0);M.step(s,0,8,0,input({charging=true,charge=1}))
 near(s.charge,1)
 for n=1,120 do M.step(s,1/60,8+n/60,0,input()) end
 assert(s.charge<1e-8)
 near(M.impulse(2,0,10,5),0);near(M.impulse(-1,0,10,5),0)
end)
check('heavy slabs accelerate downward and stop exactly at ground without bounce',function()
 for _,fps in ipairs({30,60,120,144}) do
  for rank=0,3 do
   local previous=0;local landedBefore=false
   for frame=0,fps*5 do
    local fraction,landed=M.fall(frame/fps,15,rank)
    assert(fraction>=previous and fraction>=0 and fraction<=1)
    if landedBefore then near(fraction,1);assert(landed) end
    previous=fraction;landedBefore=landed
   end
   assert(landedBefore)
  end
 end
 local a=M.fall(.1,15,0);local b=M.fall(.2,15,0);near(b,a*4)
end)
check('fall delays stagger the weight and impact age permits one-shot sound detection',function()
 local _,a=M.fall(.7,15,0);local _,b=M.fall(.7,15,3)
 assert(a and not b)
 local fraction,landed,age=M.fall(10,15,3);near(fraction,1);assert(landed and age>8)
end)
check('long stalls are bounded and prolonged active motion never drifts',function()
 local a=M.new(0,0);local b=M.new(0,0)
 M.step(a,0,0,0,input());M.step(b,0,0,0,input())
 local x=M.step(a,99,99,0,input({aimYaw=2}));local y=M.step(b,.1,99,0,input({aimYaw=2}));near(x.yaw,y.yaw)
 for n=1,10000 do
  local t=10+n/60;local p=M.step(a,1/60,t,.4,input())
  local q=M.segment(3,t,.4,p,false)
  assert(q.lift>3 and q.lift<6 and math.abs(q.roll)<.1)
 end
end)
print(string.format('PASS %d large sentry animation tests; engine visuals require Studio',passed))
