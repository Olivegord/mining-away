-- Cosmetic mechanics in seconds/radians/studs. No gameplay decisions.
local M={WAKE_DURATION=2.8,IGNITE=2.15}
local pi=math.pi
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function wrap(a) return math.atan2(math.sin(a),math.cos(a)) end
-- Exact underdamped spring for a fixed target over dt; separate velocities retain inertia.
function M.spring(value,velocity,target,frequency,damping,dt)
 if dt<=0 then return value,velocity end
 local w=frequency;local d=damping*w;local wd=w*math.sqrt(1-damping*damping)
 local offset=value-target;local b=(velocity+d*offset)/wd
 local c,s=math.cos(wd*dt),math.sin(wd*dt);local decay=math.exp(-d*dt)
 local y=offset*c+b*s
 return target+decay*y,decay*((-offset*wd*s+b*wd*c)-d*y)
end
function M.new(_now,_phase)
 return {yaw=0,pitch=0,yawV=0,pitchV=0,charge=0,initialized=false}
end
function M.wake(age,rank)
 local t=age-rank*.045
 local opening=smooth((t-.12)/.8)
 local burst
 if t<.92 then burst=smooth((t-.12)/.8)
 else
  local settle=t-.92
  -- Start the return at zero velocity; the slab accelerates into its settle.
  burst=math.exp(-settle*3.8)*(math.cos(settle*5.2)+(3.8/5.2)*math.sin(settle*5.2))
 end
 local spin=2*pi*smooth(t/1.7)
 if t>1.7 then spin+=math.sin((t-1.7)*9)*math.exp(-(t-1.7)*7)*.16 end
 return opening,burst,spin
end
function M.impulse(age,delay,frequency,decay)
 local t=age-(delay or 0)
 if t<0 or t>1.6 then return 0 end
 return math.sin(t*frequency)*math.exp(-t*decay)
end
function M.step(state,dt,now,phase,input)
 dt=math.clamp(dt,0,.1)
 local awake=input.awake==true and not input.dead
 local targetYaw=awake and (input.aimYaw or state.yaw) or 0
 local targetPitch=awake and math.clamp(input.aimPitch or 0,-.35,.35) or 0
 if not state.initialized then state.yaw=targetYaw;state.pitch=targetPitch;state.initialized=true end
 targetYaw=state.yaw+wrap(targetYaw-state.yaw)
 state.yaw,state.yawV=M.spring(state.yaw,state.yawV,targetYaw,11,.68,dt)
 state.pitch,state.pitchV=M.spring(state.pitch,state.pitchV,targetPitch,9,.7,dt)
 local charge=awake and input.charging and smooth(input.charge or 0) or 0
 state.charge=charge>state.charge and charge or charge+(state.charge-charge)*math.exp(-dt*10)
 local age=awake and math.max(0,now-(input.wakeAt or now-M.WAKE_DURATION)) or -10
 return {awake=awake,wakeAge=age,yaw=state.yaw,pitch=state.pitch,charge=state.charge,
  shotAge=input.shotAge,hitAge=input.hitAge,phase=phase,now=now,
  ignition=awake and M.impulse(age-M.IGNITE,0,22,6) or 0}
end
function M.segment(rank,now,phase,pose,eye,compact)
 if not pose.awake then return {yaw=0,pitch=0,roll=0,lift=compact or 0,back=0,side=0,reveal=0} end
 local opening,burst,spin=M.wake(pose.wakeAge,eye and .5 or rank)
 local delayed=now-rank*.16
 local shot=M.impulse(pose.shotAge,rank*.035,17-rank,5-rank*.35)
 local hit=M.impulse(pose.hitAge,rank*.045,19-rank*1.5,5)
 local settled=smooth((pose.wakeAge-1.1)/1.1)
 local breathe=math.sin(delayed*1.5+phase)
 if eye then
  return {yaw=pose.yaw+spin,pitch=pose.pitch*settled+hit*.25,
   roll=hit*.22,lift=(compact or 0)*(1-opening)+opening*1.25+burst*6.5
    +breathe*.3*settled-shot*.9,back=pose.charge*.65+shot*2.25,side=hit*.65,
   reveal=smooth((pose.wakeAge-1.6)/.4)}
 end
 local weight=(rank+1)/4
 return {yaw=spin+pose.yaw*opening+math.sin(delayed*.9+phase)*.17*settled
   +burst*(rank%2==0 and 1 or -1)*.55+hit*.3,
  pitch=hit*.22*weight,roll=math.sin(delayed*1.2+phase)*.055*settled+hit*.28*weight,
  lift=(compact or 0)*(1-opening)+opening*(.55+rank*1.25)+burst*(rank+1)*4.4
   +breathe*(.24+rank*.09)*settled+pose.charge*(rank+1)*.3-shot*(.9+rank*.5)+hit*.65*weight,
  back=shot*.4*weight,side=math.sin(delayed*.7+phase)*.16*settled+hit*.75*weight,reveal=1}
end
-- Dropped slabs accelerate, strike once and stay embedded. No bounce or wobble.
function M.fall(age,drop,rank)
 local delay=rank*.065;local t=math.max(0,age-delay);local height=math.max(0,drop)
 local duration=math.sqrt(2*height/68)
 local landed=age>=delay+duration
 local fraction=height>.0001 and math.clamp(34*t*t/height,0,1) or 1
 return fraction,landed,t-duration
end
return M
