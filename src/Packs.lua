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
local work = {.57, .18, .17, .08}

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
 local start, filled, total = 0, 0, 0
 for i = 1, tier do total += work[i] end
 for i = 1, tier do
  local finish = ends[i]
  if elapsed < finish or i == tier then
   local fraction = math.clamp((elapsed-start)/(finish-start), 0, 1)
   local eased=fraction*(1.24-.24*fraction)
   return (filled+work[i]*eased)/total, i
  end
  start, filled = finish, filled+work[i]
 end
 return 1, tier
end

function Packs.reel(elapsed,index,speed)
 local delay=(index-1)*.15
 local duration=.98+(index-1)*.24
 local t=math.clamp((elapsed*speed-delay)/duration,0,1)
 local travel=8+index
 return travel*(1-(1-t)^3), travel, t>=1, t>0
end

return Packs
