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
print(checks..' production steering checks passed using Vector API doubles; not a Studio collision/visual playtest')
