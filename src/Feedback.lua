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
return F
