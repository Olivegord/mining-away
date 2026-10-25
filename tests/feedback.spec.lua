local F=require('../src/Feedback')
local passed=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS feedback '..name) end
local function near(a,b) assert(math.abs(a-b)<1e-9,tostring(a)..' ~= '..tostring(b)) end
check('late join initializes death and old shots silently',function()
 local state=F.new({state='Destroyed',life=1,hp=0,serial=19})
 local e=F.observe(state,{state='Destroyed',life=1,hp=0,serial=19})
 assert(not e.died and not e.hit and not e.shot and not e.revived)
end)
check('one death across reordered HP and state snapshots',function()
 local state=F.new({state='Attack',life=1,hp=30,serial=2})
 local a=F.observe(state,{state='Attack',life=1,hp=0,serial=2})
 local b=F.observe(state,{state='Destroyed',life=1,hp=0,serial=2})
 local c=F.observe(state,{state='Reprinting',life=1,hp=0,serial=2})
 assert(a.died and not a.hit and not b.died and not c.died and c.assembly)
end)
check('damage and server shot serials trigger once per new snapshot',function()
 local state=F.new({state='Attack',life=1,hp=100,serial=3})
 local a=F.observe(state,{state='Attack',life=1,hp=85,serial=4})
 local b=F.observe(state,{state='Attack',life=1,hp=85,serial=4})
 assert(a.hit and a.shot and not b.hit and not b.shot)
end)
check('new life and encounter serial resets do not replay old shots',function()
 local state=F.new({state='Destroyed',life=1,hp=0,serial=8})
 local a=F.observe(state,{state='Follow',life=2,hp=80,serial=0})
 assert(a.revived and not a.hit and not a.shot)
 assert(F.observe(state,{state='Attack',life=2,hp=80,serial=1}).shot)
 local turret=F.new({dead=true,hp=0,serial=12})
 local b=F.observe(turret,{dead=false,hp=100,serial=0})
 assert(b.revived and not b.hit and not b.shot)
end)
check('continuous authoritative damage does not require local timers',function()
 local state=F.new({hp=150,serial=0})
 for hp=149,1,-1 do local e=F.observe(state,{hp=hp,serial=0});assert(e.hit and not e.died) end
 assert(F.observe(state,{hp=0,serial=0}).died)
end)
check('reconstruction is timestamp based including mid print joins',function()
 local raw,eased=F.assembly(10,12);near(raw,0);near(eased,0)
 raw,eased=F.assembly(11,12);near(raw,.5);near(eased,.75)
 raw,eased=F.assembly(12,12);near(raw,1);near(eased,1)
 near(F.assembly(100,102),0)
end)
check('hit and shot envelopes return cleanly at every frame rate',function()
 for _,rate in ipairs({30,60,120,144}) do
  local age=0
  for _=1,rate do
   local hit=F.flash(age);local recoil=F.recoil(age)
   assert(hit>=0 and hit<=1 and recoil>=0 and recoil<=1.1)
   age+=1/rate
  end
  near(F.flash(age),0);near(F.recoil(age),0)
 end
 near(F.flash(-1),0);near(F.recoil(-1),0)
end)
check('fragment trajectories land once and never sink or bounce forever',function()
 for _,rate in ipairs({30,60,120,144}) do
  local landed=false
  for frame=0,rate*3 do
   local y,nowLanded=F.fragment(frame/rate,-8,3,26)
   assert(y>=-8)
   if landed then near(y,-8);assert(nowLanded) end
   landed=nowLanded
  end
  assert(landed)
 end
end)
print(string.format('PASS %d cosmetic lifecycle/envelope tests (engine rendering still requires Studio)',passed))
