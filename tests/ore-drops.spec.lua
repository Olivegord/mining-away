local O=require('../src/OreDrops')
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS ore '..name) end
local function drop(x) return {x=x or 0,y=1,z=0,vx=0,vy=0,vz=0,age=0,floor=.2} end
check('partition conserves every integer reward without zero fragments',function()
 for n=0,1000 do local sum=0;local list=O.partition(n);assert(#list<=4)
  for _,units in ipairs(list) do assert(units>=1 and units%1==0);sum+=units end
  assert(sum==n)
 end
end)
check('scatter has a visible delay before collection',function()
 local s=drop();for _=1,7 do assert(not O.step(s,{x=0,y=1,z=0},.05,true)) end
end)
check('magnet catches a player moving at walking speed at 30 60 and 144 FPS',function()
 for _,fps in ipairs({30,60,144}) do
  local s=drop(-16);local picked=false
  for n=1,6*fps do if O.step(s,{x=n/fps*16,y=3,z=0},1/fps,true) then picked=true;break end end
  assert(picked,'magnet never catches walker at '..fps)
 end
end)
check('blocked or out-of-range pickups cannot arrive and never fall through bed',function()
 for _,blocked in ipairs({true,false}) do local s=drop()
  for _=1,300 do assert(not O.step(s,{x=50,y=1,z=0},1/60,not blocked));assert(s.y>=s.floor) end
 end
end)
check('real falls report contact speed while settled ore is silent',function()
 for _,fps in ipairs({30,60,144}) do
  local s=drop();s.y=4;s.vy=7
  local hits=0
  for _=1,4*fps do
   local before=s.vy;local _,speed=O.step(s,{x=70,y=1,z=0},1/fps,false)
   if speed and speed>0 then assert(before<1 and s.y==s.floor and s.vy>=0);hits+=1 end
  end
  assert(hits>=1 and hits<=3,'unbounded floor chatter at '..fps)
  for _=1,fps do local _,speed=O.step(s,{x=70,y=1,z=0},1/fps,false);assert(speed==0) end
 end
end)
print(checks..' production ore trajectory checks; not engine physics')
