-- Executes the actual extracted client renderDrone; API doubles are not Studio.
local passed=0
local function check(name,fn)
 local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS motion integration '..name)
end
local function create(state,paused,life)
 local source=Instance.new('Model');source:SetAttribute('State',state);source:SetAttribute('Position',Vector3.zero)
 source:SetAttribute('Goal',Vector3.new(100,0,0));source:SetAttribute('Life',life or 1);source:SetAttribute('MaxStep60',.368)
 source:SetAttribute('Owner',1);source:SetAttribute('FormationSlot',1);source:SetAttribute('FleetCount',1)
 source:SetAttribute('MotionPaused',paused);source:SetAttribute('HP',80)
 local view=Instance.new('Model');view.Parent=workspace
 return {source=source,view=view,pos=Vector3.zero,life=life or 1,yaw=0,parts={},beam={}}
end
for _,state in ipairs({'Travel','Follow','Mine'}) do
 check(state..' freezes position and yaw during a four-second save and resumes smoothly',function()
  local d=create(state,true);local start=d.pos;local yaw=d.yaw
  if state=='Mine' then d.source:SetAttribute('Mining',true);d.source:SetAttribute('TargetId','rock') end
  for i=1,240 do renderDrone(d,1/60,i/60);assert((d.pos-start).Magnitude<1e-8);assert(d.yaw==yaw) end
  if state=='Mine' then assert(presentation.lastBeam.active==true,'active beam should remain valid') end
  d.source:SetAttribute('MotionPaused',false);renderDrone(d,1/60,4+1/60)
  assert((d.pos-start).Magnitude<=.368*1.25+1e-6,'resume exceeds bounded step')
 end)
end
check('late join initializes a paused drone at its server position',function()
 local d=create('Travel',true);d.life=nil;d.pos=Vector3.new(77,0,0)
 d.source:SetAttribute('Position',Vector3.new(12,8,5));renderDrone(d,1/60,3)
 assert((d.pos-Vector3.new(12,8,5)).Magnitude<1e-8)
 for i=1,180 do renderDrone(d,1/60,3+i/60);assert((d.pos-Vector3.new(12,8,5)).Magnitude<1e-8) end
end)
check('large replication delay never creates a teleport on resume',function()
 local d=create('Travel',true);d.pos=Vector3.new(35,0,0)
 renderDrone(d,1/60,0);local prior=d.pos;d.source:SetAttribute('MotionPaused',false)
 for i=1,180 do renderDrone(d,1/60,i/60);assert((d.pos-prior).Magnitude<=.368*1.25+1e-6);prior=d.pos end
end)
check('idle roles share the exact ring independently of their work height and avoidance',function()
 for _,height in ipairs({4,7,10,12}) do
  local d=create('Follow',false);d.source:SetAttribute('FlightHeight',height)
  d.source:SetAttribute('SwarmOffset',Vector3.new(2,0,1))
  local goal=Feel.followGoal(ownerRoot.Position,1,1,1,.368)
  local expected=Feel.inertialApproach(Vector3.zero,goal,Vector3.zero,.368,1/60,false)
  renderDrone(d,1/60,1);assert((d.pos-expected).Magnitude<1e-8)
 end
end)
check('live role identity reaches the bounded beam renderer',function()
 local d=create('Mine',false);d.source:SetAttribute('Type','Charger');d.source:SetAttribute('MiningStyle','Percussion')
 renderDrone(d,1/60,1)
 assert(presentation.lastBeam.droneType=='Charger' and presentation.lastBeam.style=='Percussion')
end)
print(passed..' actual client renderDrone motion checks with API doubles; not a Studio or network test')
