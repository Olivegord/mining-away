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
check('a high launch must land even after the scatter timer elapses',function()
 local s=drop();s.y=15;s.vy=19
 local target={x=3,y=2,z=0}
 while s.age<O.SCATTER_TIME do O.step(s,target,.01,true) end
 assert(not s.landed and not s.homing and s.y>s.floor)
 local impact
 for _=1,100 do
  local _,speed=O.step(s,target,.01,true)
  if speed>0 then impact=speed;break end
  assert(not s.homing)
 end
 assert(impact and s.landed)
 O.step(s,target,.01,true);assert(s.homing)
end)
check('physical cargo rises, falls and settles briefly even with an owner close by',function()
 for _,block in ipairs({false,true}) do
  for _,fps in ipairs({30,60,144}) do
   local s=drop();s.y=3;s.raw=true
   s.vx,s.vy,s.vz=O.cargoLaunch(8,block)
   if not block then s.arc=O.rawArc(s.x,s.y,s.z,s.vx,s.vy,s.vz,s.floor) end
   local peak=s.y
   local landing=nil
   for _=1,math.ceil(1.2*fps) do
    local reached=O.step(s,{x=s.x,y=2,z=s.z},1/fps,true)
    peak=math.max(peak,s.y)
    if s.landed then landing=landing or s.firstLandedAge end
    if not landing or s.age-landing<(block and .075 or O.GEM_CONTACT_HOLD) then assert(not s.homing and not reached) end
    if reached then break end
   end
   assert(peak>=3+(block and 1.7 or 8.2),'cargo did not reach the intended apex')
   assert(landing and landing>(block and .50 or .62) and landing<(block and .70 or .71) and s.homing,
    'cargo never returned to collection in the intended window')
  end
 end
end)
check('gems hit once and lose all motion at contact at all step rates',function()
 local a=O.rawArc(2,3,-4,7.2,45,-1.5,.2)
 local x,y,z=O.rawPose(a,2)
 local beforeX,beforeY,beforeZ,_,fallSpeed=O.rawPose(a,a.contact-.0001)
 assert(math.abs(beforeX-x)<.001 and math.abs(beforeZ-z)<.001 and beforeY>y and fallSpeed<-45)
 local contactX,contactY,contactZ,vx,vy,vz=O.rawPose(a,a.contact)
 assert(contactX==x and contactY==y and contactZ==z and vx==0 and vy==0 and vz==0)
 for _,fps in ipairs({30,60,144}) do
  local s={x=2,y=3,z=-4,vx=7.2,vy=45,vz=-1.5,age=0,floor=.2,raw=true,arc=a}
  local hits=0
  for _=1,fps*2 do
   local _,speed=O.step(s,{x=70,y=1,z=0},1/fps,false)
   if speed>0 then
    hits+=1;assert(speed==a.speed and s.x==x and s.y==y and s.z==z and s.vx==0 and s.vy==0 and s.vz==0)
   end
   assert(s.y>=s.floor)
  end
  assert(hits==1 and s.firstLandedAge==a.contact and s.x==x and s.y==y and s.z==z)
  assert(s.vx==0 and s.vy==0 and s.vz==0)
  assert(O.step(s,{x=x,y=1,z=z},1/fps,true) and s.arcEnded)
 end
end)
check('magnet catches a player moving at walking speed at 30 60 and 144 FPS',function()
 for _,fps in ipairs({30,60,144}) do
  local s=drop(-2);s.landed=true;s.y=s.floor;s.age=1
  local picked=false
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
   if speed and speed>0 then assert(before<1 and s.y>=s.floor and s.y-s.floor<.25 and s.vy>=0);hits+=1 end
  end
  assert(hits>=1 and hits<=3,'unbounded floor chatter at '..fps)
  for _=1,fps do local _,speed=O.step(s,{x=70,y=1,z=0},1/fps,false);assert(speed==0) end
 end
end)
check('impact energy and scatter distance agree across frame rates',function()
 local reference
 for _,fps in ipairs({30,60,144}) do
  local s=drop();s.y=4;s.vx=6;s.vz=-2;s.vy=7
  local firstImpact
  for _=1,2*fps do local _,speed=O.step(s,{x=70,y=1,z=0},1/fps,false);if speed>0 then firstImpact=firstImpact or speed end end
  assert(firstImpact and math.abs(firstImpact-math.sqrt(7*7+2*O.GRAVITY*3.8))<1e-6)
  assert(s.y==s.floor and s.vy==0 and math.abs(s.vx)<.01 and math.abs(s.vz)<.01)
  if reference then assert(math.abs(s.x-reference)<.015,'contact friction varies with FPS') else reference=s.x end
 end
end)
check('ground friction stops fragments without silently erasing flight momentum',function()
 local s=drop();s.y=4;s.vx=6;s.vy=0
 O.step(s,{x=70,y=1,z=0},.05,false)
 assert(s.x>.29 and s.x<.3 and s.y<4)
 s.y=s.floor;s.vy=0
 local before=s.vx;O.step(s,{x=70,y=1,z=0},.05,false)
 assert(s.vx<before*.51 and s.y==s.floor)
end)
check('fade is monotonic and expiry never depends on attraction or bag space',function()
 local born=40;local before=0
 for age=0,O.LIFETIME do local fade=O.fade(born,born+age);assert(fade>=before and fade>=0 and fade<=1);before=fade end
 assert(O.fade(born,born+O.LIFETIME-O.FADE_SECONDS)<.00001 and O.fade(born,born+O.LIFETIME)==1)
 assert(not O.expired(born,born+O.LIFETIME-.001) and O.expired(born,born+O.LIFETIME))
end)
print(checks..' production ore trajectory checks; not engine physics')
