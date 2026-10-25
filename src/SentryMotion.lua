-- Pure client animation driver. Seconds/radians/studs; never used for gameplay.
local M={}
local pi=math.pi
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function wrap(a) return math.atan2(math.sin(a),math.cos(a)) end
function M.idle(now,phase)
 local t=(now+phase*2.7)%12
 -- Deliberate observe / sweep / hold / glance / return, rather than a metronome.
 local yaw
 if t<2 then yaw=-.58
 elseif t<5 then yaw=-.58+1.16*smooth((t-2)/3)
 elseif t<6.4 then yaw=.58
 elseif t<8 then yaw=.58-.78*smooth((t-6.4)/1.6)
 elseif t<9 then yaw=-.2
 else yaw=-.2-.38*smooth((t-9)/3) end
 return yaw+math.sin(now*.81+phase)*.035,
  math.sin(now*.64+phase)*.075,math.sin(now*1.3+phase)
end
function M.new(now,phase)
 local yaw,pitch=M.idle(now,phase)
 return {yaw=yaw,pitch=pitch,alert=0,charge=0}
end
function M.blink(now,phase)
 local t=(now+phase*1.9)%9.7
 if t<.11 then return smooth(t/.11) end
 if t<.16 then return 1 end
 if t<.38 then return 1-smooth((t-.16)/.22) end
 return 0
end
function M.step(state,dt,now,phase,input)
 dt=math.clamp(dt,0,.1)
 local idleYaw,idlePitch,breath=M.idle(now,phase)
 -- A previous Aim survives the server's cooldown/reset. Only a live telegraph
 -- or a brief shot follow-through may aim at it; then the sentry resumes patrol.
 local engaged=not input.dead and (input.charging or input.shotAge<.55)
 local yaw=engaged and input.aimYaw or nil
 local targetYaw=yaw or idleYaw
 local targetPitch=yaw and math.clamp(input.aimPitch or 0,-.3,.3) or idlePitch
 local turn=1-math.exp(-dt*(engaged and 13 or 3.4))
 state.yaw=wrap(state.yaw+wrap(targetYaw-state.yaw)*turn)
 state.pitch+=(targetPitch-state.pitch)*turn
 state.alert+=((engaged and 1 or 0)-state.alert)*(1-math.exp(-dt*7))
 -- Timestamp sampling reconstructs mid-charge joins; soften only the release.
 local charge=not input.dead and input.charging and smooth(input.charge or 0) or 0
 state.charge=charge>state.charge and charge or charge+(state.charge-charge)*math.exp(-dt*13)
 local shotAge=input.shotAge
 local recoil=shotAge>=0 and shotAge<.6 and math.sin(math.min(1,shotAge/.055)*pi*.5)*math.exp(-shotAge*9) or 0
 local hitAge=input.hitAge
 local flinch=hitAge>=0 and hitAge<.4 and math.sin(hitAge*45)*math.exp(-hitAge*12) or 0
 local idle=1-state.alert*.85
 return {yaw=state.yaw,pitch=state.pitch,breath=breath,idle=idle,alert=state.alert,
  charge=state.charge,recoil=recoil,flinch=flinch,
  blink=engaged and 0 or M.blink(now,phase)*idle*idle,
  focus=state.charge*state.charge*math.sin(now*47+phase)*.012}
end
function M.segment(rank,now,phase,pose,eye)
 local headYaw: number=pose.yaw
 if eye then
  return {yaw=pose.yaw,pitch=pose.pitch+pose.flinch*.045,
   roll=pose.flinch*.035,lift=pose.breath*.065*pose.idle-pose.recoil*.08,
   back=pose.charge*.12+pose.recoil*.38}
 end
 local weight=rank/3
 -- The anchored plinth stays fixed. Shell rings counter-turn and breathe in a
 -- travelling wave; higher pieces anticipate a shot then compress on discharge.
 -- Periodic head influence prevents a shell snap when aiming crosses ±pi.
 return {yaw=math.sin(headYaw)*(.08+weight*.14)+math.sin(now*.72+phase-rank*.65)*(.025+weight*.075)*pose.idle,
  pitch=pose.flinch*weight*.04,roll=math.sin(now*.9+phase-rank*.7)*weight*.018*pose.idle,
  lift=weight*(.15+math.sin(now*1.3+phase-rank*.7)*.13)*pose.idle
   +pose.charge*weight*.48-pose.recoil*weight*.36,
  back=pose.recoil*weight*.06}
end
return M
