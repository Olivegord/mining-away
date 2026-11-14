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
-- The observer gets the same bar velocity just before and after a tier cue.
for _,at in ipairs({.20,.62,.90,1.32,2.08,3.25,4.76}) do
 local step=.0001
 local previous=Packs.sample(4,at-step)
 local here=Packs.sample(4,at)
 local after=Packs.sample(4,at+step)
 assert(math.abs((after-here)-(here-previous))/step<.002)
end
assert(Packs.sample(4,.1)<.09 and Packs.sample(4,4.76)>.96)
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
