local Packs=require('../src/Packs')
local earlier=0
for tier=1,#Packs.Tiers do
 local duration=Packs.duration(tier)
 assert(duration>earlier and Packs.holdTier(duration)==tier)
 local previous=0
 for tick=0,math.ceil(duration*144) do
  local progress,stage=Packs.sample(tier,tick/144)
  assert(progress>=previous and progress<=1 and stage<=tier)
  previous=progress
 end
 assert(previous==1)
 earlier=duration
end
local early=Packs.sample(4,1.32)
local late=Packs.sample(4,3.25)
assert(early>=.73 and early<=.77 and late>=.9 and late<=.94)
for _,speed in ipairs({1,2,4}) do
 local earlierStop=0
 for index=1,3 do
  local previous=0
  for tick=0,350 do
   local elapsed=tick/144
   local offset,stop,settled=Packs.reel(elapsed,index,speed)
   assert(offset>=previous and offset<=stop)
   previous=offset
   if settled then
    assert(elapsed>earlierStop and offset==stop)
    earlierStop=elapsed
    break
   end
  end
 end
end
print('PASS four continuous hold curves and staggered reel stops at 1×, 2× and 4×')
