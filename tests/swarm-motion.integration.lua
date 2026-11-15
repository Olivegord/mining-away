-- Append to mock-roblox.lua + production Feel bundle. Vector API doubles only;
-- this does not establish engine appearance, collisions or multiplayer quality.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS swarm '..name) end
local function close(a,b,e) assert((a-b).Magnitude<(e or 1e-8),tostring((a-b).Magnitude)) end
local function record(id,x,z,gx,gz)
 return {id=id,pos=Vector3.new(x,0,z),goal=gx and Vector3.new(gx,0,gz or 0) or nil,maxStep60=.35,hp=80}
end
check('isolated drones have zero avoidance and preserve original capped travel',function()
 local d=record('a',0,0,30,0);local grid=Feel.swarmGrid({d});close(Feel.swarmOffset(d.pos,d.id,grid),Vector3.zero)
 local actual,original=Vector3.zero,0
 for _=1,180 do
  actual=Feel.approach(actual,Vector3.new(30,0,0),.35,1/60)
  original+=math.min((30-original)*.03,.35)
 end
 assert(math.abs(actual.X-original)<1e-10)
end)
check('exact overlaps escape with equal opposite deterministic steering',function()
 local a,b=record('a',0,0),record('b',0,0);local grid=Feel.swarmGrid({a,b})
 local left,right=Feel.swarmOffset(a.pos,a.id,grid),Feel.swarmOffset(b.pos,b.id,grid)
 assert(left.Magnitude>0);close(left+right,Vector3.zero)
 close(left,Feel.swarmOffset(a.pos,a.id,Feel.swarmGrid({b,a})))
end)
check('head-on approach anticipates contact before positional crowding',function()
 local a,b=record('a',-2,0,20,0),record('b',2,0,-20,0)
 local moving=Feel.swarmOffset(a.pos,a.id,Feel.swarmGrid({a,b}))
 a.goal=nil;b.goal=nil
 local still=Feel.swarmOffset(a.pos,a.id,Feel.swarmGrid({a,b}))
 assert(moving.Magnitude>still.Magnitude*2)
 assert(math.abs(moving.Z)>math.abs(still.Z),'passing lane must be stronger during approach')
end)
check('parallel co-moving neighbors do not invent a collision',function()
 local a,b=record('a',-2,0,20,0),record('b',2,0,24,0)
 local moving=Feel.swarmOffset(a.pos,a.id,Feel.swarmGrid({a,b}))
 a.goal=nil;b.goal=nil
 close(moving,Feel.swarmOffset(a.pos,a.id,Feel.swarmGrid({a,b})))
end)
check('pair avoidance conserves center and chooses opposite passing lanes',function()
 local a,b=record('a',-2,0,20,0),record('b',2,0,-20,0);local grid=Feel.swarmGrid({a,b})
 local left,right=Feel.swarmOffset(a.pos,a.id,grid),Feel.swarmOffset(b.pos,b.id,grid)
 close(left+right,Vector3.zero);assert(left.Z*right.Z<0)
end)
check('settled mining can disable steering and retain exact overhead station',function()
 local a,b=record('a',0,0),record('b',0,0);local grid=Feel.swarmGrid({a,b})
 close(Feel.swarmOffset(a.pos,a.id,grid,0),Vector3.zero)
 local goal=Feel.mineGoal(Vector3.new(10,2,15),1,false,Vector3.new(2,2,2))
 assert(goal.X==10 and goal.Z==15)
end)
check('steering pressure smoothing is continuous and rate-correct at 30/60/144Hz',function()
 local desired=Vector3.new(1.5,.1,-1)
 for _,fps in ipairs({30,60,144}) do
  local value=Vector3.zero
  for _=1,fps do value=Feel.smoothSwarm(value,desired,1/fps) end
  close(value,desired*(1-math.exp(-10)),1e-8)
 end
 local first=Feel.smoothSwarm(Vector3.zero,desired,1/60)
 assert(first.Magnitude>0 and first.Magnitude<desired.Magnitude*.2)
end)
check('frozen grid ignores sequential updates and caller iteration order',function()
 local a,b=record('a',-1,0,20,0),record('b',1,0,-20,0);local grid=Feel.swarmGrid({a,b})
 local force=Feel.swarmOffset(a.pos,a.id,grid)
 b.pos=Vector3.new(100,0,0);b.goal=Vector3.new(120,0,0)
 close(force,Feel.swarmOffset(a.pos,a.id,grid))
end)
check('large stacked crowds remain bounded, finite and reproducible',function()
 local crowd={};for n=1,500 do table.insert(crowd,record('d'..n,0,0,n%2==0 and 20 or -20,n%3)) end
 local grid=Feel.swarmGrid(crowd)
 for n=1,25 do
  local d=crowd[n];local f=Feel.swarmOffset(d.pos,d.id,grid)
  assert(f.X==f.X and f.Y==f.Y and f.Z==f.Z and f.Magnitude<=Feel.SwarmMaxOffset+1e-8)
  close(f,Feel.swarmOffset(d.pos,d.id,grid))
 end
end)
check('destroyed neighbors exert no pressure',function()
 local a,b=record('a',0,0),record('b',0,0);b.hp=0
 close(Feel.swarmOffset(a.pos,a.id,Feel.swarmGrid({a,b})),Vector3.zero)
end)
check('flight thrust bounds acceleration from rest and through a reversal',function()
 local pos,velocity=Vector3.zero,Vector3.zero;local dt=1/60;local acceleration=.35*60*1.6
 for n=1,180 do
  local goal=Vector3.new(n<=60 and 80 or -80,0,0);local previous=velocity
  pos,velocity=Feel.inertialApproach(pos,goal,velocity,.35,dt,false)
  assert((velocity-previous).Magnitude<=acceleration*dt+1e-8,'instant change in velocity')
  assert(velocity.Magnitude<=21+1e-8,'cruise cap exceeded')
  if n==1 then assert(velocity.Magnitude<1 and pos.X<.01,'launch should build thrust') end
  if n==61 then assert(velocity.X>0,'reversal must first brake the previous direction') end
 end
 assert(velocity.X<0,'reversal never completes')
end)
check('decreasing cruise speed brakes without discarding momentum',function()
 local pos,velocity=Vector3.zero,Vector3.new(21,0,0)
 local nextPos,nextVelocity=Feel.inertialApproach(pos,Vector3.new(100,0,0),velocity,.1,1/60,false)
 assert(nextVelocity.X>20 and nextVelocity.X<21,'a speed downgrade snapped to its new cap')
 assert(nextPos.X>.3,'retained momentum must remain visible')
end)
check('flight settles over the target at 30 60 and 144 Hz',function()
 local result={}
 for _,fps in ipairs({30,60,144}) do
  local pos,velocity=Vector3.zero,Vector3.zero;local goal=Vector3.new(30,4,15)
  for _=1,fps*10 do pos,velocity=Feel.inertialApproach(pos,goal,velocity,.35,1/fps,true) end
  close(pos,goal,.001);assert(velocity.Magnitude<.001)
  table.insert(result,pos)
 end
 close(result[1],result[3],.001)
end)
check('zero time and long frame stalls do not invent unbounded catch-up',function()
 local pos,velocity=Vector3.zero,Vector3.new(3,0,0)
 local same,speed=Feel.inertialApproach(pos,Vector3.new(100,0,0),velocity,.35,0,false)
 close(same,pos);close(speed,velocity)
 local stalled,stalledSpeed=Feel.inertialApproach(pos,Vector3.new(100,0,0),velocity,.35,5,false)
 local bounded,boundedSpeed=Feel.inertialApproach(pos,Vector3.new(100,0,0),velocity,.35,.1,false)
 close(stalled,bounded);close(stalledSpeed,boundedSpeed)
end)
check('replication correction shares the same thrust limit',function()
 local pos,velocity=Vector3.zero,Vector3.new(8,0,0)
 local _,nextVelocity=Feel.inertialApproach(pos,Vector3.new(30,0,0),velocity,.35,1/60,false,Vector3.new(-100,0,0))
 assert((nextVelocity-velocity).Magnitude<=.35*60*1.6/60+1e-8)
end)
check('fast head-on flight passes with room for two starter hulls',function()
 local crew={record('a',-24,0,50,0),record('b',24,0,-50,0)}
 crew[1].velocity=Vector3.xAxis*30;crew[2].velocity=-Vector3.xAxis*30
 local minimum=math.huge
 for _=1,140 do
  local grid=Feel.swarmGrid(crew)
  for _,d in ipairs(crew) do
   d.steer=Feel.smoothSwarm(d.steer,Feel.swarmOffset(d.pos,d.id,grid)*Feel.SwarmForce,1/60)
   d.pos,d.velocity=Feel.inertialApproach(d.pos,d.goal,d.velocity,.5,1/60,false,nil,1,1,d.steer)
  end
  minimum=math.min(minimum,(crew[1].pos-crew[2].pos).Magnitude)
 end
 assert(minimum>2.75 and crew[1].pos.X>0 and crew[2].pos.X<0,'minimum clearance '..minimum)
end)
check('moving escort opens into independently seeded lanes and settles back into a ring',function()
 local low,high,minRadius,maxRadius,minSpeed,maxSpeed=math.huge,-math.huge,math.huge,0,math.huge,0
 for slot=1,9 do
  local traits=Feel.swarmTraits('owner:starter:'..slot)
  local point,cruise=Feel.swarmFollow(Vector3.zero,Vector3.xAxis*16,slot,9,20,19,traits,1,1/60)
  local radius=Vector3.new(point.X,0,point.Z).Magnitude
  low=math.min(low,point.Y);high=math.max(high,point.Y);minRadius=math.min(minRadius,radius);maxRadius=math.max(maxRadius,radius)
  minSpeed=math.min(minSpeed,traits.speed);maxSpeed=math.max(maxSpeed,traits.speed)
  for n=1,240 do point,cruise=Feel.swarmFollow(Vector3.zero,Vector3.zero,slot,9,20+n/60,19,traits,cruise,1/60) end
  assert(math.abs(Vector3.new(point.X,0,point.Z).Magnitude-12)<.12)
 end
 assert(high-low>4 and maxRadius-minRadius>4 and maxSpeed-minSpeed>.12)
end)
check('loaded courier needs longer to accelerate and cruises slower',function()
 local goal=Vector3.xAxis*80
 local bareMass,bareSpeed=Feel.courierLoad(0);local heavyMass,heavySpeed=Feel.courierLoad(1)
 local empty,loaded,emptyV,loadV=Vector3.zero,Vector3.zero,Vector3.zero,Vector3.zero
 for _=1,80 do
  empty,emptyV=Feel.inertialApproach(empty,goal,emptyV,.4*bareSpeed,1/60,false,nil,1,bareMass)
  loaded,loadV=Feel.inertialApproach(loaded,goal,loadV,.4*heavySpeed,1/60,false,nil,1,heavyMass)
 end
 assert(heavyMass>bareMass and loaded.X<empty.X*.8 and loadV.X<emptyV.X*.81)
end)
check('a crowded crew settles without circulating and keeps neighboring space',function()
 for _,fps in ipairs({30,60,144}) do
  local crew={}
  for i=1,9 do
   local angle=i*.13
   crew[i]={id='idle:'..i,hp=80,state='Follow',pos=Vector3.new(math.cos(angle)*12,18,math.sin(angle)*12),velocity=Vector3.zero,traits=Feel.swarmTraits('idle:'..i)}
  end
  local lateSpeed=0
  local ring
  for frame=1,fps*35 do
   ring=Feel.ringGoals(crew,Vector3.zero,ring,function() return 18 end);local grid=Feel.swarmGrid(crew)
   for i,d in ipairs(crew) do
    local goal=Feel.swarmFollow(Vector3.zero,Vector3.zero,i,9,frame/fps,18,d.traits,0,1/fps,ring[d.id])
    d.steer=Feel.smoothSwarm(d.steer,Feel.swarmOffset(d.pos,d.id,grid)*Feel.SwarmForce*.22,1/fps)
    d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,.35,1/fps,false,nil,1,1.4,d.steer)
    if frame>fps*30 then lateSpeed=math.max(lateSpeed,d.velocity.Magnitude) end
   end
  end
  assert(lateSpeed<.05,'crew never settled: '..lateSpeed)
  for i=1,#crew do for j=i+1,#crew do assert((crew[i].pos-crew[j].pos).Magnitude>7,'crowded resting hulls') end end
 end
end)
check('moving, turning and stopping do not sustain oscillation',function()
 local crew={}
 for i=1,9 do
  local a=i*2*math.pi/9
  crew[i]={id='trip:'..i,hp=80,state='Follow',pos=Vector3.new(math.cos(a)*12,18,math.sin(a)*12),velocity=Vector3.zero,traits=Feel.swarmTraits('trip:'..i)}
 end
 local center=Vector3.zero;local peak=0
 local goals
 for frame=1,60*24 do
  local ownerVelocity=frame<240 and Vector3.xAxis*16 or frame<480 and Vector3.zAxis*16 or Vector3.zero
  center+=ownerVelocity/60
  goals=Feel.ringGoals(crew,center,goals,function() return 18 end);local grid=Feel.swarmGrid(crew)
  for i,d in ipairs(crew) do
   local goal
   local delta=d.pos-center
   local slot=goals[d.id] or {angle=math.atan2(delta.Z,delta.X),radius=12}
   goal,d.cruise=Feel.swarmFollow(center,ownerVelocity,i,9,frame/60,18,d.traits,d.cruise,1/60,slot)
   d.steer=Feel.smoothSwarm(d.steer,Feel.swarmOffset(d.pos,d.id,grid)*Feel.SwarmForce*.22,1/60)
   d.pos,d.velocity=Feel.inertialApproach(d.pos,goal,d.velocity,.35,1/60,false,nil,1,1.4,d.steer)
   if frame>60*20 then peak=math.max(peak,d.velocity.Magnitude) end
  end
 end
 assert(peak<.1,'sustained motion after stop: '..peak)
end)
check('a returning carrier only makes room in the ring within ten studs of it',function()
 local height=function() return 16 end
 local crew={}
 for i=1,10 do
  local a=i*2*math.pi/10
  crew[i]={id=i,hp=80,state='Follow',pos=Vector3.new(math.cos(a)*12,16,math.sin(a)*12)}
 end
 local center=Vector3.zero
 local initial=Feel.ringGoals(crew,center,nil,height)
 local courier={id=11,role='Courier',hp=80,state='Follow',pos=Vector3.new(22.1,16,0)}
 crew[11]=courier
 local waiting=Feel.ringGoals(crew,center,initial,height)
 assert(not waiting[11])
 for i=1,10 do assert(initial[i].angle==waiting[i].angle and initial[i].radius==waiting[i].radius) end
 courier.pos=Vector3.new(12,27,0)
 assert(not Feel.ringGoals(crew,center,waiting,height)[11],'a high carrier counted as arrived')
 courier.pos=Vector3.new(21.9,16,0)
 local joined=Feel.ringGoals(crew,center,waiting,height)
 assert(joined[11] and joined[1].radius>waiting[1].radius)
 courier.state='Deliver'
 local left=Feel.ringGoals(crew,center,joined,height)
 assert(not left[11] and left[1].radius==initial[1].radius)
end)
check('steady transit has no time-driven circling or vertical weaving',function()
 local traits=Feel.swarmTraits('worker')
 local a=Feel.swarmFollow(Vector3.zero,Vector3.xAxis*16,1,9,0,18,traits,1,1/60)
 for t=1,60 do close(a,Feel.swarmFollow(Vector3.zero,Vector3.xAxis*16,1,9,t,18,traits,1,1/60)) end
end)
print(checks..' production steering checks passed using Vector API doubles; not a Studio collision/visual playtest')
