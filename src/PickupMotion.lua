-- Render-only sampling of authoritative pickup snapshots. A short interpolation
-- buffer preserves acceleration, gravity and floor contacts without chasing a
-- succession of network targets. It never decides collection or grants ore.
local M={DELAY=.1,MAX_PREDICTION=.12,GRAVITY=38,AIR_DRAG=.9,GROUND_DRAG=14}
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function axis(a,b,va,vb,t,span)
 local slope=(b-a)/span
 if math.abs(slope)<1e-6 then return a end
 -- Bound tangents so homing turns cannot make a buffered fragment jump past
 -- either server sample, even when a collision flips its velocity.
 va=va*slope>0 and math.min(math.abs(va),3*math.abs(slope))*(slope>0 and 1 or -1) or 0
 vb=vb*slope>0 and math.min(math.abs(vb),3*math.abs(slope))*(slope>0 and 1 or -1) or 0
 local a2,b2=va/slope,vb/slope;local magnitude=a2*a2+b2*b2
 if magnitude>9 then local k=3/math.sqrt(magnitude);va*=k;vb*=k end
 local t2,t3=t*t,t*t*t
 return (2*t3-3*t2+1)*a+(t3-2*t2+t)*span*va+(-2*t3+3*t2)*b+(t3-t2)*span*vb
end
function M.position(samples,now)
 local at=now-M.DELAY
 local first=samples[1];if not first then return nil end
 if at<=first.at then return first.x,first.y,first.z end
 for i=2,#samples do
  local b=samples[i];local a=samples[i-1]
  if at<=b.at then
   local span=math.max(.001,b.at-a.at);local t=clamp((at-a.at)/span,0,1)
   return axis(a.x,b.x,a.vx,b.vx,t,span),math.max(b.floor or -math.huge,axis(a.y,b.y,a.vy,b.vy,t,span)),axis(a.z,b.z,a.vz,b.vz,t,span)
  end
 end
 local s=samples[#samples];local dt=clamp(at-s.at,0,M.MAX_PREDICTION)
 local x,y,z
 if s.homing then x=s.x+s.vx*dt;y=s.y+s.vy*dt;z=s.z+s.vz*dt
 else
  local coefficient=(s.floor and s.y<=s.floor+.001 and math.abs(s.vy)<.8) and M.GROUND_DRAG or M.AIR_DRAG
  local drag=(1-math.exp(-coefficient*dt))/coefficient
  x=s.x+s.vx*drag;y=s.y+s.vy*dt-.5*M.GRAVITY*dt*dt;z=s.z+s.vz*drag
 end
 return x,math.max(s.floor or -math.huge,y),z
end
function M.opacity(now,fadeAt,expiresAt)
 if type(expiresAt)~='number' or type(fadeAt)~='number' then return 1 end
 local t=clamp((now-fadeAt)/math.max(.001,expiresAt-fadeAt),0,1)
 return 1-t*t*(3-2*t)
end
function M.tumble(age,landAge)
 age=math.max(0,age)
 -- Angular momentum carries across contact, then friction arrests the spin.
 -- Sampling absolute age keeps landing poses equal at all render rates.
 if type(landAge)~='number' or age<=landAge then return age*4.8 end
 return math.max(0,landAge)*4.8+(1-math.exp(-(age-landAge)*8))*.6
end
function M.supportHeight(sx,sy,sz,rx,ry,rz)
 -- Vertical extent of a box rotated Rx * Ry * Rz. Keep the collectible's
 -- authored mesh above its contact plane while it tumbles and settles.
 local a=math.cos(rx)*math.sin(rz)+math.sin(rx)*math.sin(ry)*math.cos(rz)
 local b=math.cos(rx)*math.cos(rz)-math.sin(rx)*math.sin(ry)*math.sin(rz)
 local c=-math.sin(rx)*math.cos(ry)
 return (math.abs(a)*sx+math.abs(b)*sy+math.abs(c)*sz)*.5
end
function M.collection(t)
 t=clamp(t,0,1)
 return t*t*(3-2*t),1-t*t
end
return M
