local M=require('../src/PickupMotion')
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS pickup render '..name) end
local function s(t,x,y,vx,vy) return {at=t,x=x,y=y,z=0,vx=vx,vy=vy,vz=0,floor=0,homing=false} end
check('buffered falling motion retains a weighted arc and exact sample contacts',function()
 local samples={s(10,0,2,5,8),s(10.1,.45,2.68,4,5.6),s(10.2,.82,3.12,3,3.2)}
 local x,y=M.position(samples,10.2);assert(math.abs(x-.45)<1e-6 and math.abs(y-2.68)<1e-6)
 local previous=0
 for i=1,60 do local xx,yy=M.position(samples,10.1+i/600);assert(xx>=previous and yy>=2 and yy<=2.68);previous=xx end
end)
check('velocity reversal never overshoots floor or segment and settled ore stays still',function()
 local samples={s(10,0,.2,10,-20),s(10.1,.3,0,0,4),s(10.2,.3,0,0,0)}
 for i=0,200 do local x,y=M.position(samples,10.1+i/1000);assert(x>=0 and x<=.3+1e-8 and y>=0) end
 local x,y=M.position(samples,50);assert(x==.3 and y==0)
end)
check('network stalls bound extrapolation and never tunnel through ground',function()
 local samples={s(10,0,1,30,-20)}
 local x,y=M.position(samples,10.22);local farX,farY=M.position(samples,40)
 assert(math.abs(x-farX)<1e-8 and math.abs(y-farY)<1e-8 and y==0 and x<4)
end)
check('old resting packets do not stretch a new move across idle time',function()
 local samples={s(10,0,0,0,0),s(100.1,1,1,10,10)}
 samples[2].homing=true
 local x,y=M.position(samples,100.09);assert(x==0 and y==0)
 x,y=M.position(samples,100.15);assert(x>0 and x<1 and y>0 and y<1)
 x,y=M.position(samples,100.2);assert(math.abs(x-1)<1e-8 and math.abs(y-1)<1e-8)
end)
check('a socketed rock holds its pose through a long packet gap',function()
 local socket=s(10,1,5,0,0);socket.seated=true
 local x,y=M.position({socket},100)
 assert(M.isResting(socket) and x==1 and y==5)
end)
check('snapshot sampling is independent of render frame rate',function()
 local samples={s(10,0,1,12,4),s(10.1,1,1.28,8,1.6),s(10.2,1.7,1.32,6,-.8)}
 for _,fps in ipairs({30,60,144}) do
  local x,y
  for frame=1,fps do x,y=M.position(samples,10.2+frame/fps*.06) end
  local expectedX,expectedY=M.position(samples,10.26)
  assert(math.abs(x-expectedX)<1e-8 and math.abs(y-expectedY)<1e-8)
 end
end)
check('expiry fades monotonically to invisibility and collection settles exactly',function()
 local previous=1
 for i=0,100 do local opacity=M.opacity(13+i*.05,13,18);assert(opacity>=0 and opacity<=previous);previous=opacity end
 assert(M.opacity(12,13,18)==1 and M.opacity(19,13,18)==0)
 local start,scale=M.collection(0);assert(start==0 and scale==1)
 local finish,zero=M.collection(1);assert(finish==1 and zero==0)
end)
check('angular momentum is continuous at landing and then stops',function()
 local landed=.7
 assert(math.abs(M.tumble(landed,landed)-M.tumble(landed,nil))<1e-8)
 assert(math.abs(M.tumble(landed+.00001,landed)-M.tumble(landed,landed))<.0001)
 assert(M.tumble(landed+.1,landed)>M.tumble(landed,landed))
 assert(math.abs(M.tumble(5,landed)-M.tumble(10,landed))<1e-8)
end)
check('rotated reward fragments keep their lowest corner above the floor',function()
 assert(math.abs(M.supportHeight(.48,.58,.44,0,0,0)-.29)<1e-8)
 assert(math.abs(M.supportHeight(.48,.58,.44,math.pi*.5,0,0)-.22)<1e-8)
 assert(math.abs(M.supportHeight(.48,.58,.44,0,0,math.pi*.5)-.24)<1e-8)
 for i=1,100 do
  local height=M.supportHeight(.48,.58,.44,i*.17,i*.28,i*.31)
  assert(height>=.22-1e-8 and height<=math.sqrt(.48*.48+.58*.58+.44*.44)*.5+1e-8)
 end
end)
print(checks..' production render-trajectory checks; not native visual acceptance')
