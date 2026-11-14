-- Shared ballistic sampling only. The server chooses contacts and damage.
local C={RANGE=18,SHARE=.30,GRAVITY=64,MAX_HITS=6,MAX_DEPTH=3,MAX_OWNER_SHOTS=12,MAX_SHOTS=48,LIFETIME=1.25}
function C.damage(sourceHP,targetHP)
 return math.min(math.max(0,sourceHP-10),math.max(0,targetHP-10))*C.SHARE
end
function C.brittle(hp,maxHP) return hp>0 and hp<=math.max(1,maxHP-10)*C.SHARE end
function C.launch(from,to)
 local duration=math.clamp((to-from).Magnitude/30,.38,.72)
 return (to-from)/duration+Vector3.new(0,C.GRAVITY*duration*.5,0),duration
end
function C.position(from,velocity,t)
 return from+velocity*t-Vector3.new(0,C.GRAVITY*t*t*.5,0)
end
-- Segment against the current oriented collider, including its real shrink.
-- Raycasts handle intervening world geometry; this also handles a segment
-- starting inside the intended rock and crossing it between server ticks.
function C.contact(from,to,frame,size)
 local a,b=frame:PointToObjectSpace(from),frame:PointToObjectSpace(to)
 local low,high=0,1
 for _,axis in ipairs({'X','Y','Z'}) do
  local delta=b[axis]-a[axis];local half=size[axis]*.5
  if math.abs(delta)<1e-7 then if math.abs(a[axis])>half then return nil end
  else
   local near,far=(-half-a[axis])/delta,(half-a[axis])/delta
   if near>far then near,far=far,near end
   low=math.max(low,near);high=math.min(high,far)
   if low>high then return nil end
  end
 end
 return from:Lerp(to,low)
end
return C
