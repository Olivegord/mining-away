-- Shared-time client tool articulation. No gameplay position, reach or damage.
-- The authored chassis stays in level flight; the working hardware has its own
-- readable preparation, quick contact and longer mechanically damped recovery.
local Motion={}
local roles={Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local fieldRoles={Needler=true,Ballcaster=true,Vacuum=true,Dart=true,Compactor=true}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function stroke(t,loaded,contact)
 if t<=.55 then return loaded*smooth((t-.07)/.34)*(1-.08*smooth((t-.42)/.13)) end
 if t<=.68 then return loaded*.92+(contact-loaded*.92)*smooth((t-.55)/.13) end
 local follow=smooth((t-.68)/.055)*(1-smooth((t-.735)/.23))
 return contact*(1-smooth((t-.68)/.32)+.17*follow)
end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end

function Motion.new(model,role)
 if not (roles[role] or fieldRoles[role]) then return nil end
 local record={model=model,role=role,parts={},scale=model:GetScale()}
 local pivot=model:GetPivot()
 for _,part in ipairs(model:GetDescendants()) do
  local kind=part:GetAttribute('SpecialMotion')
  local gun=role=='Needler' or role=='Ballcaster'
  if part:IsA('BasePart') and (kind or gun and part.Transparency<1) then
   record.parts[#record.parts+1]={part=part,kind=kind or 'GunBody',side=part:GetAttribute('MotionSide') or 1,base=pivot:ToObjectSpace(part.CFrame),size=part.Size}
  end
 end
 return record
end

-- Pure phase evaluation is also used by deterministic frame-rate checks.
function Motion.phase(resource,id,now)
 if not resource or resource:GetAttribute('EffectDrone')~=id then return nil end
 local serial=resource:GetAttribute('EffectSerial') or 0
 local started=resource:GetAttribute('EffectStartedAt')
 local duration=resource:GetAttribute('EffectDuration')
 if serial<=0 or (resource:GetAttribute('EffectCancelledSerial') or 0)>=serial or not finite(started) or not finite(duration) or duration<=0 or not finite(now) then return nil end
 local paused=resource:GetAttribute('EffectPausedAt') or 0
 if paused>0 then now=math.min(now,paused) end
 if now<started or now>started+duration+.15 then return nil end
 return math.clamp((now-started)/duration,0,1)
end

local function offset(record,item,t)
 local k,s=item.kind,item.side
 local scale=record.scale
 if k=='Jaw' then
  -- Rotate the whole rigid jaw around its actual aft hinge, not its center.
  local hinge=Vector3.new(s*.95,.12,.45)*scale
  return CFrame.new(hinge)*CFrame.Angles(0,s*stroke(t,.20,-.065),0)*CFrame.new(-hinge)
 elseif k=='Scanner' then
  local scan=stroke(t,-.78,.88)
  return CFrame.new(0,0,scan*scale)
 elseif k=='Bulb' then
  return CFrame.new(0,stroke(t,.055,-.045)*scale,0)
 elseif k=='Valve' then
  return CFrame.new(0,stroke(t,.10,-.025)*scale,0)
 elseif k=='Nozzle' then
  return CFrame.new(0,stroke(t,.06,-.18)*scale,0)
 elseif k=='Containment' then
  local hinge=Vector3.new(0,.85,0)*scale
  return CFrame.new(hinge)*CFrame.Angles(0,stroke(t,.25,-.08),stroke(t,-.12,.045))*CFrame.new(-hinge)
 elseif k=='GravityCore' then
  return CFrame.new(0,stroke(t,.14,-.055)*scale,0)
 elseif k=='FurnaceCore' then
  return CFrame.new(0,stroke(t,.12,-.04)*scale,0)
 elseif k=='FurnaceCap' then
  return CFrame.new(0,stroke(t,.18,.04)*scale,0)
 elseif k=='HeatFin' then
  local angle=s*math.pi/2;local spread=stroke(t,.12,.025)*scale
  return CFrame.new(math.cos(angle)*spread,0,math.sin(angle)*spread)
 elseif k=='CryoTank' then
  return CFrame.new(s*stroke(t,.08,-.035)*scale,0,0)
 elseif k=='CryoNozzle' then
  return CFrame.new(0,0,stroke(t,.13,-.24)*scale)
 elseif k=='Fork' then
  return CFrame.new(0,stroke(t,.07,-.025)*scale,0)
 elseif k=='Prong' then
  -- One bounded deflection and decaying follow-through, never a noisy shake.
  local decay=t>.68 and math.exp(-(t-.68)*14)*math.sin((t-.68)*23) or 0
  return CFrame.new((s%2==0 and -1 or 1)*(stroke(t,.055,-.018)+decay*.018)*scale,0,0)
 end
 return CFrame.new()
end

-- Read the same clock as the projectile. Each cue stops at the pose that
-- makes the next action legible, then releases with a fast stroke and drag.
local function gunPose(ball,now,shot)
 if not shot or not shot.Parent then return nil end
 local started=shot:GetAttribute('StartedAt')
 local windup=shot:GetAttribute('Windup')
 if not finite(started) or not finite(windup) or windup<=0 then return nil end
 local paused=shot:GetAttribute('PausedAt') or 0
 local age=(paused>0 and math.min(now,paused) or now)-started
 if age<0 then return nil end
 local pull=ball and .44 or .28
 local travel=ball and .54 or .32
 local settle=ball and .48 or .26
 if age<windup then
  local q=age/windup
  local cock=smooth((q-.02)/(ball and .56 or .54))
  local brace=cock*(1-.10*smooth((q-.62)/.38))
  return pull*brace,(ball and .20 or .14)*brace,smooth((q-.08)/.80)
 end
 local t=age-windup
 if t>=settle then return nil end
 local reset=1-smooth((t-.065)/(settle-.065))
 local strike=smooth(t/.026)*(1-smooth((t-.027)/.062))
 local kick=smooth((t-.021)/.047)*reset
 local spring=smooth((t-.14)/.08)*(1-smooth((t-.22)/math.max(.04,settle-.22)))
 local slide=pull*.90*(1-smooth(t/.032))-pull*.50*strike+travel*kick-travel*.16*spring
 local brace=(ball and .20 or .14)*.90*(1-smooth(t/.04))+.42*travel*kick
 return slide,brace,1-smooth(t/.052)
end

local function fieldStep(record,state,now,dt,shot,source)
 local ball=record.role=='Ballcaster'
 local gun=ball or record.role=='Needler'
 local slide,brace,load=0,0,0
 if gun then
  local active=state=='SpecialMine' or state=='Warmup' or state=='Recover'
   or ((source:GetAttribute('HP') or 1)>0 and shot and shot:GetAttribute('ContactAt')~=nil)
  local movement,lean,heat
  if active then movement,lean,heat=gunPose(ball,now,shot) end
  local fade=math.exp(-math.min(dt or 0,.1)*19)
  slide=movement or (record.slide or 0)*fade
  brace=lean or (record.brace or 0)*fade
  load=heat or (record.load or 0)*fade
  record.slide,record.brace,record.load=slide,brace,load
 end
 local engaging=(record.role=='Vacuum' and state=='Vacuum') or (record.role=='Dart' and state=='Plant') or (record.role=='Compactor' and (state=='Intake' or state=='Press'))
 local engagement=record.engagement or 0
 engagement+=((engaging and 1 or 0)-engagement)*(1-math.exp(-math.min(dt or 0,.1)*12))
 record.engagement=engagement
 local pivot=record.model:GetPivot()
 if gun then pivot*=CFrame.new(0,brace*.32,brace*record.scale)*CFrame.Angles(-brace*.29,0,0) end
 for _,item in ipairs(record.parts) do
  if not item.part.Parent then continue end
  local kind=item.kind
  local offset=Vector3.zero
  if kind=='DartSlide' or kind=='BallSlide' then offset=Vector3.new(0,0,slide)
  elseif kind=='BallReload' or kind=='DartLoad' then offset=Vector3.new(0,0,slide*.91)
  elseif kind=='Intake' then offset=Vector3.new(0,-.27*engagement,0)
  elseif kind=='PressFoot' then offset=Vector3.new(item.side*.18*engagement,-.80*engagement,0)
  elseif kind=='PressJaw' then
   local age=now-(source:GetAttribute('PressAt') or 0)
   local close=smooth((age-.065)/(Workshop.PRESS_CONTACT-.065))
   local reopen=smooth((age-Workshop.PRESS_EJECT)/(Workshop.PRESS_RESET-Workshop.PRESS_EJECT))
   local stroke=state=='Press' and close*(1-reopen) or 0
   offset=Vector3.new(-item.side*.69*stroke,-.22*stroke,0)
  elseif kind=='Canister' then offset=Vector3.new(item.side*.17*engagement,0,0)
  elseif kind=='Seeder' then offset=Vector3.new(item.side*.12*engagement,-.32*engagement,.12*engagement) end
  item.part.CFrame=pivot*CFrame.new(offset*record.scale)*item.base
  if kind=='BallReload' then
   item.part.Size=item.size*(.06+1.08*load)
  elseif kind=='DartLoad' then
   item.part.Size=item.size*(.06+.94*load)
  end
 end
end

function Motion.step(record,source,resource,now,dt,shot)
 if not record or not record.model.Parent then return end
 local state=source:GetAttribute('State')
 if fieldRoles[record.role] then fieldStep(record,state,now,dt,shot,source);return end
 local id=source:GetAttribute('DroneId')
 if resource and resource:GetAttribute('EffectDrone')==id then record.resource=resource end
 -- The final contact clears TargetId, but its mechanical recoil still finishes
 -- during the server's bounded Recover hold. An explicit order cancels it.
 local recovering=state=='Recover' and record.resource and record.resource:GetAttribute('EffectDepleted')==true
 local active=state=='SpecialMine' or recovering
 local t=active and Motion.phase(resource or record.resource,id,now) or nil
 if t then
  record.cancelAt=nil
 elseif record.active then
  record.cancelAt=now
  for _,item in ipairs(record.parts) do item.cancel=record.model:GetPivot():ToObjectSpace(item.part.CFrame) end
 end
 local pivot=record.model:GetPivot()
 for _,item in ipairs(record.parts) do
  if item.part.Parent then
   if t then
    item.part.CFrame=pivot*offset(record,item,t)*item.base
   elseif record.cancelAt and now-record.cancelAt<.2 then
    item.part.CFrame=pivot*item.cancel:Lerp(item.base,smooth((now-record.cancelAt)/.2))
   else item.part.CFrame=pivot*item.base end
   -- Scaling pressure/core light subtly is secondary to the assembly's action.
   local swell=t and (item.kind=='Bulb' or item.kind=='GravityCore' or item.kind=='FurnaceCore') and stroke(t,.055,-.025) or 0
   item.part.Size=item.size*(1+swell)
  end
 end
 record.active=t~=nil
end
return Motion
