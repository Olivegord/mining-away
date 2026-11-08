local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS flight observer '..name) end
local function fixture()
 local source=Instance.new('Model');source:SetAttribute('State','Travel');source:SetAttribute('Position',Vector3.zero);source:SetAttribute('Goal',Vector3.new(30,0,0));source:SetAttribute('Life',1);source:SetAttribute('HP',80);source:SetAttribute('MaxStep60',.35)
 local view=Instance.new('Model');view.Parent=workspace
 return {source=source,view=view,pos=Vector3.zero,velocity=Vector3.zero,life=1,yaw=0,parts={},beam={}}
end
check('a missed dive snapshot enters the authoritative contact hold without braking',function()
 for _,fps in ipairs({30,60,144}) do
  local d=fixture();d.pos=Vector3.new(0,10,0);d.velocity=Vector3.new(0,-30,0)
  d.source:SetAttribute('State','BreakerImpact');d.source:SetAttribute('BreakerImpact',Vector3.zero)
  renderDrone(d,1/fps,1)
  assert(d.pos.Magnitude==0 and d.velocity.Magnitude==0,'contact must stop at the server plane, without easing out')
  for n=1,fps do renderDrone(d,1/fps,1+n/fps);assert(d.pos.Magnitude==0 and d.velocity.Magnitude==0) end
 end
end)
check('settled station and heading remain stable across stale same-life snapshots',function()
 local d=fixture();local goal=Vector3.new(12,8,10);d.pos=goal;d.yaw=1.2;d.source:SetAttribute('Goal',goal);d.source:SetAttribute('Position',goal);d.source:SetAttribute('State','Warmup');d.source:SetAttribute('TargetId','stone')
 for n=1,900 do renderDrone(d,1/60,n/60);assert((d.pos-goal).Magnitude<1e-8 and d.yaw==1.2) end
end)
check('work pause keeps flying while withholding mining presentation',function()
 local d=fixture();d.source:SetAttribute('WorkPaused',true);d.source:SetAttribute('State','Mine');d.source:SetAttribute('Mining',true);d.source:SetAttribute('TargetId','stone')
 renderDrone(d,1/60,1);assert(d.pos.X>0 and not presentation.lastBeam.active)
end)
check('arrival remains bounded and converges across frame rates',function()
 local results={}
 for _,fps in ipairs({30,60,144}) do
  local pos,velocity=Vector3.new(-30,5,-8),Vector3.new(10,0,3);local goal=Vector3.zero;local arrived=false
  for n=1,10*fps do
   local old=velocity;pos,velocity=Feel.inertialApproach(pos,goal,velocity,.35,1/fps,true)
   assert((velocity-old).Magnitude<=.35*60*1.6/fps+1e-7)
   if pos.Magnitude<.5 then arrived=true end
   if arrived then assert(pos.Magnitude<.51,'arrival crossed and reversed out of the station') end
  end
  assert(pos.Magnitude<.01 and velocity.Magnitude<.02);table.insert(results,pos)
 end
 assert((results[1]-results[3]).Magnitude<.01)
end)
check('reference flight uses a 10-stud ring and the original cruise and ease',function()
 local offsets={Vector3.new(0,7,10),Vector3.new(-10,7,0),Vector3.new(0,7,-10),Vector3.new(10,7,0)}
 for slot,expected in ipairs(offsets) do
  local offset=Feel.followGoal(Vector3.zero,slot,4,0,0)
  assert((offset-expected).Magnitude<1e-7)
  assert(math.abs((offset-offsets[slot%4+1]).Magnitude-math.sqrt(200))<1e-7)
 end
 for _,fps in ipairs({30,60,144}) do
  local dt=1/fps;local near,far=Vector3.zero,Vector3.zero
  for _=1,fps do
   near=Feel.referenceFlight(near,Vector3.new(1,0,0),.35,dt)
   far=Feel.referenceFlight(far,Vector3.new(100,0,0),.35,dt)
  end
  assert(math.abs(near.X-(1-.97^60))<1e-7 and math.abs(far.X-21)<1e-7)
 end
end)
print(checks..' production observer/shared-flight checks; native motion and network transport NOT VERIFIED')
