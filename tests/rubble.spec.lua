local F=require('../src/Feedback')
for _,rate in ipairs({30,60,144}) do
 local previous=0;local contacts=0;local settled=false
 for frame=0,rate*4 do
  local y,travel,bounces,_,_,rest=F.rubble(frame/rate,-5,12,72)
  assert(y>=-5 and travel>=previous and bounces<=5)
  previous=travel;contacts=math.max(contacts,bounces);settled=rest
 end
 assert(contacts>=2 and settled,'rubble must bounce, lose energy and settle')
end
local _,a=F.rubble(3,-5,12,72);local _,b=F.rubble(10,-5,12,72)
assert(b-a<.001,'settled rubble must stop drifting')
print('PASS rubble gravity/restitution/friction/settling at 30, 60 and 144 Hz')
