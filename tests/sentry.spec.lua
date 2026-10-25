local M=require('../src/SentryMotion')
local passed=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS sentry '..name) end
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or 1e-9),tostring(a)..' ~= '..tostring(b)) end
local function input(values)
 local result={dead=false,charging=false,charge=0,shotAge=100,hitAge=100}
 for k,v in pairs(values or {}) do result[k]=v end
 return result
end
check('idle patrol has visible sweep, pauses, seamless loop and independent phases',function()
 local a=M.idle(0,0);local b=M.idle(1,0)
 assert(math.abs(a-b)<.04)
 assert(math.abs(M.idle(5.5,0)-a)>1)
 assert(math.abs(M.idle(12-1e-5,0)-M.idle(12+1e-5,0))<1e-4)
 assert(math.abs(M.idle(3,0)-M.idle(3,1))>.1)
end)
check('late join reconstructs absolute idle and charge without replaying a shot',function()
 local a=M.new(1234,2.3);local b=M.new(1234,2.3)
 local p=M.step(a,0,1234,2.3,input({charging=true,charge=.5}))
 local q=M.step(b,0,1234,2.3,input({charging=true,charge=.5}))
 near(p.yaw,q.yaw);near(p.charge,.5);near(p.recoil,0)
end)
check('brief staggered idle blinks never obscure a live charge or shot',function()
 near(M.blink(.13,0),1);near(M.blink(1,0),0)
 local s=M.new(.13,0)
 assert(M.step(s,0,.13,0,input()).blink>.9)
 near(M.step(s,0,.13,0,input({charging=true,charge=.1})).blink,0)
 near(M.step(s,0,.13,0,input({shotAge=.1})).blink,0)
end)
check('stale server Aim cannot stop the idle after cooldown or reset',function()
 local a=M.new(0,0);local b=M.new(0,0)
 for n=1,180 do
  local p=M.step(a,1/60,n/60,0,input({aimYaw=2.6,aimPitch=.2}))
  local q=M.step(b,1/60,n/60,0,input())
  near(p.yaw,q.yaw);near(p.pitch,q.pitch)
 end
end)
check('charge acquires target and shot follow through releases back to patrol',function()
 local s=M.new(0,0)
 for n=1,60 do M.step(s,1/60,n/60,0,input({charging=true,charge=n/60,aimYaw=2,aimPitch=.8})) end
 near(s.yaw,2,.001);near(s.pitch,.3,.001);near(s.charge,1)
 local p=M.step(s,1/60,1.1,0,input({shotAge=.1,aimYaw=2}))
 assert(p.recoil>.1 and p.alert>.9)
 for n=1,180 do p=M.step(s,1/60,1.1+n/60,0,input({aimYaw=2})) end
 assert(p.alert<1e-7 and p.charge<1e-10 and p.recoil==0)
 assert(math.abs(p.yaw-2)>.3)
end)
check('heading wraps by the shortest arc',function()
 local s=M.new(0,0);s.yaw=math.pi-.01
 local p=M.step(s,1/60,0,0,input({charging=true,aimYaw=-math.pi+.01}))
 assert(p.yaw>math.pi-.01 or p.yaw< -math.pi+.01)
end)
check('death suppresses aim and cannot leave charge active',function()
 local s=M.new(0,0)
 for n=1,120 do M.step(s,1/60,n/60,0,input({dead=true,charging=true,charge=1,aimYaw=2})) end
 near(s.alert,0);near(s.charge,0)
end)
check('tracking converges consistently at 30 60 120 and 144 FPS',function()
 local results={}
 for _,fps in ipairs({30,60,120,144}) do
  local s=M.new(0,0)
  for n=1,fps do M.step(s,1/fps,n/fps,.4,input({charging=true,charge=.7,aimYaw=1.7,aimPitch=.2})) end
  table.insert(results,s)
 end
 for _,s in ipairs(results) do near(s.yaw,results[1].yaw);near(s.pitch,results[1].pitch);near(s.alert,results[1].alert);near(s.charge,results[1].charge) end
end)
check('shell has a travelling idle and stronger charge anticipation without moving plinth',function()
 local s=M.new(2,0);local idle=M.step(s,0,2,0,input())
 local lower=M.segment(1,2,0,idle,false);local upper=M.segment(3,2,0,idle,false)
 assert(upper.lift>.05 and upper.lift~=lower.lift)
 local windup=M.step(s,0,2,0,input({charging=true,charge=1}))
 local charged=M.segment(3,2,0,windup,false)
 assert(charged.lift-upper.lift>.4)
 local bottom=M.segment(0,2,0,windup,false);near(bottom.lift,0);near(bottom.back,0)
end)
check('all eye parts share one transform; recoil and flinch settle',function()
 local s=M.new(2,0)
 local p=M.step(s,1/60,2,0,input({shotAge=.06,hitAge=.03}))
 local eye=M.segment(1,2,0,p,true);assert(eye.back>.1 and math.abs(eye.roll)>.001)
 for _,rank in ipairs({0,1,2,3}) do local q=M.segment(rank,2,0,p,true);near(q.yaw,eye.yaw);near(q.pitch,eye.pitch);near(q.lift,eye.lift);near(q.back,eye.back) end
 p=M.step(s,1/60,3,0,input());near(p.recoil,0);near(p.flinch,0)
end)
check('long stalls are bounded and pose never integrates displacement',function()
 local a=M.new(0,0);local b=M.new(0,0)
 local p=M.step(a,99,99,.4,input({charging=true,aimYaw=2}))
 local q=M.step(b,.1,99,.4,input({charging=true,aimYaw=2}))
 near(p.yaw,q.yaw)
 for n=1,20000 do
  p=M.step(a,1/60,n/60,.4,input())
  for rank=0,3 do
   local piece=M.segment(rank,n/60,.4,p,false)
   assert(math.abs(piece.lift)<.9 and math.abs(piece.yaw)<1 and math.abs(piece.roll)<.1)
  end
 end
end)
print(string.format('PASS %d sentry animation logic tests (visuals require Studio)',passed))
