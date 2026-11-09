-- Delivery and hold timing shared by authority and presentation.
local Packs = {
 Range = 8,
 DeliveryTime = 1.08,
 DropTime = .73,
 DepartTime = 1.65,
 Tiers = {'Common', 'Rare', 'Epic', 'Legendary'},
 Palette = {{195,213,225},{89,208,255},{201,134,255},{255,205,78}},
}
local ends = {.42, 1.32, 2.65, 4.8}
local work = {.60, .22, .12, .06}

function Packs.roll(ticket)
 if ticket <= 66 then return 1 end
 if ticket <= 90 then return 2 end
 if ticket <= 98 then return 3 end
 return 4
end

function Packs.duration(tier)
 return ends[tier]
end

function Packs.stageDuration(stage)
 return ends[stage]-(ends[stage-1] or 0)
end

function Packs.sample(tier, elapsed)
 local start, filled, total = 0, 0, 0
 for i = 1, tier do total += work[i] end
 for i = 1, tier do
  local finish = ends[i]
  if elapsed < finish or i == tier then
   local fraction = math.clamp((elapsed-start)/(finish-start), 0, 1)
   return (filled+work[i]*fraction)/total, i
  end
  start, filled = finish, filled+work[i]
 end
 return 1, tier
end

return Packs
