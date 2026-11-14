-- Executes the production renderDrone body with API doubles, never Studio.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS client inertia '..name) end
local function fixture()
 local source=Instance.new('Model');source:SetAttribute('State','Travel');source:SetAttribute('Role','Striker')
 source:SetAttribute('Position',Vector3.zero);source:SetAttribute('Goal',Vector3.new(100,0,0))
 source:SetAttribute('Life',1);source:SetAttribute('MaxStep60',.35);source:SetAttribute('HP',80)
 local view=Instance.new('Model');view.Parent=workspace
 return {source=source,view=view,pos=Vector3.zero,velocity=Vector3.zero,life=1,yaw=0,parts={},beam={}}
end
check('launch and replicated goal reversals retain continuous velocity',function()
 local d=fixture();renderDrone(d,1/60,0)
 assert(d.pos.X>0 and d.pos.X<.01 and d.velocity.Magnitude<1)
 for n=1,30 do renderDrone(d,1/60,n/60) end
 local velocity=d.velocity;d.source:SetAttribute('Goal',Vector3.new(-100,0,0));d.source:SetAttribute('Position',d.pos)
 renderDrone(d,1/60,1)
 assert(d.velocity.X>0 and (d.velocity-velocity).Magnitude<=.35*60*1.6/60+1e-8)
end)
check('a delayed authoritative position is corrected through thrust',function()
 local d=fixture();d.pos=Vector3.new(35,0,0);d.velocity=Vector3.new(8,0,0)
 local prior=d.velocity;renderDrone(d,1/60,0)
 assert((d.velocity-prior).Magnitude<=.35*60*1.6/60+1e-8)
 assert((d.pos-Vector3.new(35,0,0)).Magnitude<.15,'reconciliation added a positional jump')
end)
check('save pause freezes the pose and resumes with retained momentum',function()
 local d=fixture();d.velocity=Vector3.new(8,0,0);d.source:SetAttribute('MotionPaused',true)
 for n=1,120 do renderDrone(d,1/60,n/60) end
 assert(d.pos.Magnitude==0 and d.velocity.X==8)
 d.source:SetAttribute('MotionPaused',false);renderDrone(d,1/60,3)
 assert(d.velocity.X>8 and d.velocity.X<9)
end)
check('reprint resets motion and a new life seeds authoritative velocity',function()
 local d=fixture();d.velocity=Vector3.new(20,0,0);d.source:SetAttribute('State','Destroyed')
 renderDrone(d,1/60,0);assert(d.velocity.Magnitude==0)
 d.source:SetAttribute('Life',2);d.source:SetAttribute('State','Travel');d.source:SetAttribute('Velocity',Vector3.new(6,0,0))
 renderDrone(d,1/60,1);assert(d.velocity.X>=6 and d.velocity.X<7)
end)
check('healers retain their trailing goal with the same finite acceleration',function()
 local d=fixture();d.source:SetAttribute('Role','Medic')
 local expected=Feel.inertialApproach(d.pos,d.source:GetAttribute('Goal'),Vector3.zero,.35,1/60,false)
 renderDrone(d,1/60,0);assert((d.pos-expected).Magnitude<1e-8 and d.velocity.Magnitude<1)
end)
print(checks..' production client inertia checks with API doubles; engine motion/network quality not verified')
