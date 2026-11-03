-- Shared-time client tool articulation. No gameplay position, reach or damage.
-- The authored chassis stays in level flight; the working hardware has its own
-- readable preparation, quick contact and longer mechanically damped recovery.
local Motion={}
local roles={Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true}
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function stroke(t,loaded,contact)
 if t<=.52 then return loaded*smooth((t-.12)/.4) end
 if t<=.68 then local release=math.clamp((t-.52)/.16,0,1)^3;return loaded+(contact-loaded)*release end
 return contact*(1-smooth((t-.68)/.32))
end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end

function Motion.new(model,role)
 if not roles[role] then return nil end
 local record={model=model,role=role,parts={},scale=model:GetScale()}
 local pivot=model:GetPivot()
 for _,part in ipairs(model:GetDescendants()) do
  local kind=part:GetAttribute('SpecialMotion')
  if part:IsA('BasePart') and kind then
   record.parts[#record.parts+1]={part=part,kind=kind,side=part:GetAttribute('MotionSide') or 1,base=pivot:ToObjectSpace(part.CFrame),size=part.Size}
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

function Motion.step(record,source,resource,now)
 if not record or not record.model.Parent then return end
 local state=source:GetAttribute('State')
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
