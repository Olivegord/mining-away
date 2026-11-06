-- Pure cosmetic event detection and time envelopes. These never advance gameplay.
local F={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function dead(s)
 return s.dead==true or s.state=='Destroyed' or s.state=='Reprinting' or (finite(s.hp) and s.hp<=0)
end
function F.new(snapshot)
 return {dead=dead(snapshot),state=snapshot.state,life=snapshot.life,hp=snapshot.hp,serial=snapshot.serial or 0}
end
function F.observe(previous,snapshot)
 local isDead=dead(snapshot)
 local changedLife=snapshot.life~=nil and previous.life~=nil and snapshot.life~=previous.life
 local serial=finite(snapshot.serial) and snapshot.serial or 0
 local event={
  died=isDead and not previous.dead,
  revived=not isDead and previous.dead,
  assembly=snapshot.state=='Reprinting' and previous.state~='Reprinting',
  hit=not changedLife and not previous.dead and not isDead and finite(snapshot.hp) and finite(previous.hp) and snapshot.hp<previous.hp-.001,
  shot=not isDead and not changedLife and serial>previous.serial,
 }
 previous.dead=isDead;previous.state=snapshot.state;previous.life=snapshot.life
 previous.hp=snapshot.hp;previous.serial=serial
 return event
end
function F.progress(now,start,duration)
 if not finite(now) or not finite(start) or not finite(duration) or duration<=0 then return 1 end
 return math.clamp((now-start)/duration,0,1)
end
function F.smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
function F.flash(age,duration)
 if not finite(age) or age<0 then return 0 end
 local t=math.clamp(age/(duration or .16),0,1)
 return (1-t)^2
end
function F.recoil(age)
 if not finite(age) or age<0 or age>=.28 then return 0 end
 -- A fast compression followed by a slower return, sampled from elapsed time.
 local t=age/.28
 return math.sin(math.pi*t)^2*(1-t)*1.8
end
function F.assembly(now,readyAt,duration)
 local p=math.clamp(1-(readyAt-now)/(duration or 2),0,1)
 return p,1-(1-p)^2
end
function F.fragment(age,groundDrop,vy,gravity)
 -- Deterministic ballistic fall, one floor sample at spawn; no per-frame raycasts.
 local floor=math.min(0,groundDrop)
 local impact=(vy+math.sqrt(vy*vy-2*gravity*floor))/gravity
 if age<impact then return vy*age-.5*gravity*age*age,false,age end
 return floor,true,impact
end
function F.rubble(age,groundDrop,vy,gravity)
 -- Piecewise ballistic arcs conserve downward speed at impact, then lose
 -- energy to restitution/friction. Sampling time directly is frame-rate safe.
 local floor=math.min(0,groundDrop);local y=0;local elapsed=0
 local travel=0;local horizontal=1;local lastImpact=0;local strength=0
 local function drift(t) return (1-math.exp(-.7*t))/.7 end
 for bounce=0,4 do
  local impact=(vy+math.sqrt(vy*vy+2*gravity*math.max(0,y-floor)))/gravity
  local t=math.max(0,age-elapsed)
  if t<impact then
   return y+vy*t-.5*gravity*t*t,travel+horizontal*drift(t),bounce,lastImpact,strength,false,0
  end
  travel+=horizontal*drift(impact);horizontal*=math.exp(-.7*impact)*.57
  elapsed+=impact;strength=math.max(0,gravity*impact-vy);lastImpact=elapsed
  y=floor;vy=strength*.32
  if vy<1.4 or bounce==4 then
   local rest=math.max(0,age-elapsed)
   return floor,travel+horizontal*(1-math.exp(-9*rest))/9,bounce+1,lastImpact,strength,true,rest
  end
 end
 return floor,travel,5,lastImpact,strength,true,0
end
-- Stable, size-normalised anchor on the *queried rendered part* surface.
-- A cached anchor transforms with crystal shrink and tilt between bounded raycasts.
function F.surfaceAnchor(point,size)
 if not point or not size then return nil end
 local function ratio(v,n)
  if not finite(v) or not finite(n) or n<=0 then return nil end
  return math.clamp(v/n,-.5,.5)
 end
 local x,y,z=ratio(point.X,size.X),ratio(point.Y,size.Y),ratio(point.Z,size.Z)
 if x==nil or y==nil or z==nil then return nil end
 return {x=x,y=y,z=z}
end
function F.surfaceComponents(anchor,size)
 if not anchor or not size or not finite(size.X) or not finite(size.Y) or not finite(size.Z)
  or size.X<=0 or size.Y<=0 or size.Z<=0 then return nil end
 return anchor.x*size.X,anchor.y*size.Y,anchor.z*size.Z
end
-- A percussion hit/resonance discharge must correspond to this life and target.
-- Late discovery reconstructs the short visual envelope but never replays audio.
function F.miningCue(previous,sample,now)
 local serial=finite(sample.pulseSerial) and sample.pulseSerial or 0
 local changed=previous.life~=sample.life or previous.key~=sample.key
 local fresh=previous.serial~=nil and not changed and serial>previous.serial
 previous.serial=serial;previous.life=sample.life;previous.key=sample.key
 local valid=sample.alive and sample.active and not sample.paused and serial>0
  and sample.pulseKey==sample.key and sample.key~=nil
  and finite(sample.pulseAt) and sample.pulseAt>0
 if not valid then return 0,false end
 local strength=F.flash(now-sample.pulseAt,.22)
 return strength,fresh and strength>0
end
-- One coherent envelope; never replay a stale contact across death/life/target changes.
function F.newBeam()
 return {key=nil,ever=false,active=false,width=0,life=nil,startAt=0,startWidth=0,hideAt=nil,hideWidth=0}
end
function F.beamStep(record: any,sample: any)
 local now: any=sample.now
 if type(now)~='number' or not finite(now) then return 0 end
 if not sample.alive or not sample.valid or not sample.key then
  record.key=nil;record.width=0;record.active=false;record.hideAt=nil;record.life=sample.life
  return 0
 end
 local changed=record.key~=sample.key or (record.life~=nil and sample.life~=record.life)
 if changed then
  record.key=sample.key;record.width=0;record.active=false;record.hideAt=nil
 end
 record.life=sample.life
 if sample.active then
  if not record.active then
   -- Charging already finished on the server. Release immediately, including
   -- late joins and new targets; do not append a second cosmetic warmup.
   local since=now
   if type(sample.since)=='number' and finite(sample.since) then since=math.min(sample.since,now) end
   record.startAt=record.ever and now or since
   record.startWidth=record.width;record.active=true;record.hideAt=nil;record.ever=true
  end
  record.width=1
 else
  if record.active or record.hideAt==nil then record.hideAt=now;record.hideWidth=record.width end
  record.active=false
  local t=math.clamp((now-record.hideAt)/.2,0,1)
  record.width=record.hideWidth*(1-t)^2
 end
 return record.width
end
return F
