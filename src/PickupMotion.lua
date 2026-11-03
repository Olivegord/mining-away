-- Render-only sampling of authoritative pickup snapshots. A short interpolation
-- buffer preserves acceleration, gravity and floor contacts without chasing a
-- succession of network targets. It never decides collection or grants ore.
local M={DELAY=.1,MAX_PREDICTION=.12,GRAVITY=38}
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
  local drag=(1-math.exp(-4*dt))/4
  x=s.x+s.vx*drag;y=s.y+s.vy*dt-.5*M.GRAVITY*dt*dt;z=s.z+s.vz*drag
 end
 return x,math.max(s.floor or -math.huge,y),z
end
function M.opacity(now,fadeAt,expiresAt)
 if type(expiresAt)~='number' or type(fadeAt)~='number' then return 1 end
 local t=clamp((now-fadeAt)/math.max(.001,expiresAt-fadeAt),0,1)
 return 1-t*t*(3-2*t)
end
function M.collection(t)
 t=clamp(t,0,1)
 return t*t*(3-2*t),1-t*t
end
return M
