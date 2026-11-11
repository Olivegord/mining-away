-- Delivery and hold timing shared by authority and presentation.
local Packs = {
 Range = 8,
 DeliveryTime = 1.08,
 DropTime = .73,
 DepartTime = 1.65,
 Tiers = {'Common', 'Rare', 'Epic', 'Legendary'},
 Palette = {{195,213,225},{89,208,255},{201,134,255},{255,205,78}},
}
-- The original event used progressively longer holds. These are the four
-- Crystal Run timings, with most of the visible movement at the beginning.
local ends = {.62, 1.32, 3.25, 6.85}
-- Sample points on the visible sweep. Keep the first fast push, the
-- shoulder just past half-full, and the long crawl through the last arc.
local times={0,.20,ends[1],.90,ends[2],2.08,ends[3],4.76,ends[4]}
local fill={0,.16,.57,.67,.75,.84,.92,.969,1}
local stops={3,5,7,9}
local slope={.48}
for i=2,#times-1 do
 local before,after=times[i]-times[i-1],times[i+1]-times[i]
 local left,right=(fill[i]-fill[i-1])/before,(fill[i+1]-fill[i])/after
 local a,b=2*after+before,after+2*before
 slope[i]=(a+b)/(a/left+b/right)
end
slope[#times]=.006

function Packs.roll(ticket)
 if ticket <= 66 then return 1 end
 if ticket <= 90 then return 2 end
 if ticket <= 98 then return 3 end
 return 4
end

function Packs.duration(tier)
 return ends[tier]
end

function Packs.holdTier(duration)
 for tier, seconds in ipairs(ends) do
  if math.abs(seconds-duration)<.01 then return tier end
 end
 return 1
end

function Packs.rarityTier(rarity)
 return table.find(Packs.Tiers,rarity) or (rarity=='Uncommon' and 2 or 1)
end

function Packs.sample(tier, elapsed)
 if elapsed<=0 then return 0,1 end
 if elapsed>=ends[tier] then return 1,tier end
 local stage=1
 while stage<tier and elapsed>=ends[stage] do stage+=1 end
 local last=stops[tier]
 for i=2,last do
  if elapsed<times[i] then
   local span=times[i]-times[i-1]
   local t=(elapsed-times[i-1])/span
   local t2,t3=t*t,t*t*t
   local value=(2*t3-3*t2+1)*fill[i-1]+(t3-2*t2+t)*span*slope[i-1]
     +(-2*t3+3*t2)*fill[i]+(t3-t2)*span*slope[i]
   return value/fill[last],stage
  end
 end
 return 1,tier
end

function Packs.reelFinish(index)
 return 1.22+(index-1)*.09
end

function Packs.reel(elapsed,index,speed)
 local delay=(index-1)*.035
 local duration=Packs.reelFinish(index)-delay
 local t=math.clamp((elapsed*speed-delay)/duration,0,1)
 local travel=8+index
 return travel*(1-(1-t)^3), travel, t>=1, t>0, t
end

return Packs
