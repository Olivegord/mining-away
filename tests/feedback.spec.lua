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
check('mesh contact anchors follow translation and nonuniform resize',function()
 local a=assert(F.surfaceAnchor({X=.2,Y=1,Z=-.3},{X=2,Y=4,Z=3}))
 local x,y,z=F.surfaceComponents(a,{X=1,Y=2,Z=1.5})
 near(x,.1);near(y,.5);near(z,-.15)
 -- A world transform can move the exact same local contact without static world drift.
 local angle=math.rad(40);local tx,tz=5,-8
 local worldX=tx+math.cos(angle)*x+math.sin(angle)*z
 local worldZ=tz-math.sin(angle)*x+math.cos(angle)*z
 near(worldX-tx,math.cos(angle)*.1-math.sin(angle)*.15)
 near(worldZ-tz,-math.sin(angle)*.1-math.cos(angle)*.15)
end)
check('surface ratios reject invalid size and bound floating point jitter',function()
 assert(F.surfaceAnchor({X=0,Y=1,Z=0},{X=0,Y=1,Z=1})==nil)
 assert(F.surfaceAnchor({X=0/0,Y=1,Z=0},{X=1,Y=1,Z=1})==nil)
 local a=assert(F.surfaceAnchor({X=5,Y=-5,Z=0},{X=2,Y=2,Z=2}));near(a.x,.5);near(a.y,-.5)
 assert(F.surfaceComponents(a,{X=2,Y=-1,Z=2})==nil)
end)
local function beamSample(overrides)
 local q={now=0,alive=true,valid=true,active=true,key='rock-a',life=1,since=0}
 for k,v in pairs(overrides or {}) do q[k]=v end;return q
end
check('release is full width on its first frame at 30 60 120 and 144 fps',function()
 for _,rate in ipairs({30,60,120,144}) do
  local beam=F.newBeam();local q=beamSample({active=false})
  near(F.beamStep(beam,q),0)
  q.now=1/rate;q.active=true;q.since=q.now;near(F.beamStep(beam,q),1)
  for n=2,rate do q.now=n/rate;near(F.beamStep(beam,q),1) end
 end
end)
check('late join shows released contact without replaying warmup',function()
 local beam=F.newBeam();near(F.beamStep(beam,beamSample({now=11,since=10})),1)
end)
check('stop keeps the original 0.2-second fade and reactivation fires immediately',function()
 local beam=F.newBeam();local q=beamSample();near(F.beamStep(beam,q),1)
 q.now=1;q.active=false;near(F.beamStep(beam,q),1)
 q.now=1.1;near(F.beamStep(beam,q),.25)
 q.now=1.2;near(F.beamStep(beam,q),0)
 q.active=true;near(F.beamStep(beam,q),1)
end)
check('new targets death and invalid contacts never inherit a ghost beam',function()
 local beam=F.newBeam();local q=beamSample();near(F.beamStep(beam,q),1)
 q.key='rock-b';q.active=false;q.now=2.1;near(F.beamStep(beam,q),0)
 q.active=true;q.now=3;near(F.beamStep(beam,q),1)
 q.valid=false;near(F.beamStep(beam,q),0)
 q.valid=true;q.active=false;near(F.beamStep(beam,q),0)
 q.alive=false;near(F.beamStep(beam,q),0)
 q.alive=true;q.life=2;near(F.beamStep(beam,q),0)
 q.active=true;near(F.beamStep(beam,q),1)
 q.key=nil;near(F.beamStep(beam,q),0)
end)
check('card-modified charge hands directly to full beam with no second warmup',function()
 for _,duration in ipairs({2,1,.08}) do
  local beam=F.newBeam();local q=beamSample({active=false,now=10,since=10})
  near(F.beamStep(beam,q),0)
  q.now=10+duration-.001;near(F.beamStep(beam,q),0)
  q.now=10+duration;q.active=true;q.since=q.now;near(F.beamStep(beam,q),1)
 end
end)
check('interrupted charge and long pause never show a released beam',function()
 local beam=F.newBeam();local q=beamSample({active=false,now=10,since=10})
 near(F.beamStep(beam,q),0)
 q.now=100;near(F.beamStep(beam,q),0)
 q.now=101;q.active=true;q.since=101;near(F.beamStep(beam,q),1)
 q.alive=false;near(F.beamStep(beam,q),0)
 q.alive=true;q.valid=false;near(F.beamStep(beam,q),0)
end)
check('mining pulse follows authoritative timestamp and never invents a rhythm',function()
 local record={};local q={alive=true,active=true,key='a',life=1,pulseKey='a',pulseSerial=1,pulseAt=5}
 local strength,fresh=F.miningCue(record,q,5);near(strength,1);assert(not fresh,'late join replayed sound')
 strength,fresh=F.miningCue(record,q,5.3);near(strength,0);assert(not fresh)
 q.pulseSerial=2;q.pulseAt=6
 strength,fresh=F.miningCue(record,q,6.1);assert(strength>0 and strength<1 and fresh)
 strength,fresh=F.miningCue(record,q,6.11);assert(strength>0 and not fresh,'same hit sounded twice')
 strength,fresh=F.miningCue(record,q,600);near(strength,0);assert(not fresh)
end)
check('mining pulse rejects stale targets paused jobs and new lives',function()
 local record={};local q={alive=true,active=true,key='a',life=1,pulseKey='a',pulseSerial=1,pulseAt=5}
 F.miningCue(record,q,5)
 q.key='b';q.pulseSerial=2;local strength,fresh=F.miningCue(record,q,5.01);near(strength,0);assert(not fresh)
 q.pulseKey='b';q.life=2;q.pulseSerial=3;strength,fresh=F.miningCue(record,q,5.02);assert(not fresh)
 q.paused=true;q.pulseSerial=4;strength,fresh=F.miningCue(record,q,5.03);near(strength,0);assert(not fresh)
 q.paused=false;strength,fresh=F.miningCue(record,q,5.04);assert(not fresh,'resume replayed an old hit')
 q.alive=false;q.pulseSerial=5;strength,fresh=F.miningCue(record,q,5.05);near(strength,0);assert(not fresh)
end)
check('mining pulse rejects invalid and future server timestamps',function()
 local q={alive=true,active=true,key='a',life=1,pulseKey='a',pulseSerial=1,pulseAt=6}
 near(F.miningCue({},q,5),0)
 q.pulseAt=0/0;near(F.miningCue({},q,5),0)
 q.pulseAt=0;near(F.miningCue({},q,5),0)
end)
print(string.format('PASS %d cosmetic lifecycle/envelope tests (engine rendering still requires Studio)',passed))
