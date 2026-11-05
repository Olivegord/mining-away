-- Cosmetic point masses attracted to an emitter. Cache the force simulation
-- once; sample authoritative charge time without frame-dependent integration.
local Pull={}
local RATE=240
local paths={}
local ZERO=Vector3.zero
local function simulate(index)
 local angle=index*2.399963
 local radius=2.4+(index%3)*.55
 local position=Vector3.new(math.cos(angle)*radius,-.35-(index%4)*.35,math.sin(angle)*radius)
 local velocity=Vector3.new(-math.cos(angle)*.8-math.sin(angle)*5.5,.25,-math.sin(angle)*.8+math.cos(angle)*5.5)
 local mass=.85+(index%3)*.12
 local samples={{position=position,velocity=velocity}}
 local captured
 for step=1,RATE do
  local t=step/RATE
  if not captured then
   -- Softened attraction: increasing field strength bends initial momentum
   -- inward from the first sample. Drag removes angular momentum so
   -- each stream is captured instead of orbiting indefinitely.
   local distance2=position:Dot(position)
   local attraction=(160+620*t*t*t)/(mass*(distance2+.3)^1.5)
   local acceleration=-position*attraction-velocity*3.2
   velocity+=acceleration/RATE
   position+=velocity/RATE
   if position:Dot(position)<.2*.2 then captured=t;position=ZERO;velocity=ZERO end
  end
  samples[#samples+1]={position=position,velocity=velocity}
 end
 return {samples=samples,captured=captured or 1}
end
for i=1,8 do paths[i]=simulate(i) end
function Pull.sample(index,progress)
 local path=paths[(index-1)%#paths+1]
 local frame=math.clamp(progress*.82,0,1)*RATE
 local left=math.min(RATE,math.floor(frame))+1
 local a=path.samples[left]
 local b=path.samples[math.min(left+1,RATE+1)]
 local fraction=frame-math.floor(frame)
 return a.position:Lerp(b.position,fraction),a.velocity:Lerp(b.velocity,fraction),path.captured/.82
end
-- Reuse the same cached point-mass approach for the release. Small lateral
-- velocity kicks make an electrical spray without constraints or per-frame RNG.
local discharge={}
local OUT_RATE=120
for i=1,18 do
 local angle=i*2.399963;local speed=6+(i%5)*.7
 local p=Vector3.zero
 local v=Vector3.new(math.cos(angle)*(2.2+i%3*.65),-speed,math.sin(angle)*(2.2+i%3*.65))
 local points={p}
 for step=1,180 do
  local t=step/OUT_RATE
  if step%8==0 and t<.6 then
   local kick=angle+step*1.73
   v+=Vector3.new(math.cos(kick),0,math.sin(kick))*(1-t/.6)*2.4
  end
  v+=(Vector3.new(0,-5,0)-v*2.2)/OUT_RATE
  p+=v/OUT_RATE;points[#points+1]=p
 end
 discharge[i]=points
end
function Pull.discharge(index,age)
 local frame=math.clamp(age,0,1.5)*OUT_RATE
 local left=math.min(180,math.floor(frame))+1
 local points=discharge[(index-1)%#discharge+1]
 return points[left]:Lerp(points[math.min(left+1,181)],frame-math.floor(frame))
end
return Pull
