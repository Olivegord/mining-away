-- Render-only timeline. Never feeds a visual position back into gameplay.
local M={DELAY=.12,MAX_PREDICTION=.1}
function M.push(samples,at,pose,reset)
 if type(at)~='number' or not pose then return end
 local last=samples[#samples]
 if reset then table.clear(samples);last=nil end
 if last and at<=last.at then return end
 samples[#samples+1]={at=at,pose=pose}
 if #samples>6 then table.remove(samples,1) end
end
function M.pose(samples,now)
 local first=samples[1];if not first then return nil end
 local at=now-M.DELAY
 if at<=first.at then return first.pose end
 for i=2,#samples do
  local a,b=samples[i-1],samples[i]
  if at<=b.at then return a.pose:Lerp(b.pose,math.clamp((at-a.at)/(b.at-a.at),0,1)) end
 end
 local last=samples[#samples];local before=samples[#samples-1]
 if not before then return last.pose end
 local span=last.at-before.at
 local dt=math.clamp(at-last.at,0,M.MAX_PREDICTION)
 -- Bounded linear continuation bridges one late packet; long outages freeze.
 return last.pose+(last.pose.Position-before.pose.Position)*(dt/span)
end
return M
