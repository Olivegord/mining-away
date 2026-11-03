local checks=0
local function check(name,fn) fn();checks+=1;print('PASS refinement motion '..name) end
local function fixture()
 local s=Instance.new('Model');s:SetAttribute('State','Return');s:SetAttribute('Position',Vector3.zero);s:SetAttribute('Goal',Vector3.zero)
 s:SetAttribute('Life',1);s:SetAttribute('HP',80);s:SetAttribute('MaxStep60',.35);s:SetAttribute('PhaseSeed',0)
 local view=Instance.new('Model');view.Parent=workspace
 return {source=s,view=view,pos=Vector3.zero,velocity=Vector3.zero,life=1,yaw=0,parts={},beam={}}
end
check('recall hop is the same at server time for both observers and settles',function()
 local a,b=fixture(),fixture();a.source:SetAttribute('RecallAt',5);b.source:SetAttribute('RecallAt',5)
 renderDrone(a,1/60,5.36);renderDrone(b,1/144,5.36)
 local expected=.9+math.sin(5.36*1.6)*.10
 assert(math.abs(a.view.CFrame.Position.Y-expected)<1e-8)
 assert(math.abs(a.view.CFrame.Position.Y-b.view.CFrame.Position.Y)<1e-8)
 renderDrone(a,1/60,5.8)
 assert(math.abs(a.view.CFrame.Position.Y-math.sin(5.8*1.6)*.10)<1e-8)
end)
check('late observer does not replay an old recall and pause holds pose',function()
 local d=fixture();d.source:SetAttribute('RecallAt',5);renderDrone(d,1/60,8)
 assert(math.abs(d.view.CFrame.Position.Y-math.sin(8*1.6)*.10)<1e-8)
 d.source:SetAttribute('MotionPaused',true);renderDrone(d,1/60,5.36)
 assert(d.view.CFrame.Position.Y==d.pos.Y)
end)
check('a new mining order cancels the remaining recall flourish',function()
 local d=fixture();d.source:SetAttribute('RecallAt',5);d.source:SetAttribute('State','Mine')
 renderDrone(d,1/60,5.36)
 assert(math.abs(d.view.CFrame.Position.Y-math.sin(5.36*1.6)*.05)<1e-8)
end)
check('breaker fall accelerates into a hard contact at30/60/144Hz',function()
 for _,fps in ipairs({30,60,144}) do
  local d=fixture();local start,impact=Vector3.new(0,10,0),Vector3.new(0,3,0)
  local duration=.28
  d.pos=start;d.source:SetAttribute('State','BreakerDive');d.source:SetAttribute('BreakerImpact',impact)
  d.source:SetAttribute('BreakerDiveStart',start);d.source:SetAttribute('BreakerPhaseAt',5);d.source:SetAttribute('BreakerDiveDuration',duration)
  local count=math.ceil(fps*duration);local previous=start;local priorDistance=0
  for i=1,count do
   local elapsed=duration*i/count
   renderDrone(d,1/fps,5+elapsed)
   local expected=Feel.powerDive(start,impact,elapsed,duration)
   assert((d.pos-expected).Magnitude<1e-7,'renderer added braking or lag to the authoritative fall')
   local moved=(d.pos-previous).Magnitude
   assert(moved>priorDistance,'the weight eased out before impact')
   assert(d.pos.Y>=impact.Y and d.view.CFrame.Position.Y>=impact.Y,'body penetrated the contact plane')
   previous=d.pos;priorDistance=moved
  end
  renderDrone(d,1/fps,5+duration+.01)
  assert((d.pos-impact).Magnitude<1e-8 and d.velocity.Magnitude==0,'contact did not stop abruptly')
  -- A delayed Impact snapshot cannot restart movement or braking.
  d.source:SetAttribute('State','BreakerImpact');d.bank=.2
  renderDrone(d,1/fps,5+duration+.3)
  assert((d.view.CFrame.Position-impact).Magnitude<1e-8 and d.velocity.Magnitude==0 and d.bank==0)
 end
end)
check('replicated dive duration drives every observer without a second ease',function()
 local d=fixture();local start,impact=Vector3.new(0,10,0),Vector3.new(0,3,0)
 d.source:SetAttribute('State','BreakerDive');d.source:SetAttribute('BreakerImpact',impact);d.source:SetAttribute('BreakerDiveStart',start)
 d.source:SetAttribute('BreakerPhaseAt',5);d.source:SetAttribute('BreakerDiveDuration',.5)
 renderDrone(d,1/60,5.25)
 local expected=Feel.powerDive(start,impact,.25,.5)
 assert((d.pos-expected).Magnitude<1e-8)
end)
print(checks..' production client motion cases (API doubles)')
