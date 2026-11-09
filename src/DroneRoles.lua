-- Pure capabilities and work phases. Color/ownership never grants an implicit
-- mining beam: a drone must have the actual mechanical job that performs it.
local R={}
R.BREAKER={windup=.8,impactHold=1,recovery=.65,diveLimit=1.25,diveDuration=.28}
R.GROWER={plantSeconds=1.1,cooldown=5}
local legacy={Blue='Striker',Red='Charger',Green='Medic'}
local definitions={
 Striker={job='Miner',worker=true,miner=true,combat=true},
 Charger={job='Breaker',worker=true,combat=true},
 Dart={job='Rock grower',grower=true},
 Courier={job='Backpack emptier',courier=true},
 Medic={job='Healer',healer=true},
 Orbiter={job='Orbital controller',ability='Orbital'},
 Scrapper={job='Swarm fabricator',ability='Scrap'},
 Bubbler={job='Bubble extractor',worker=true,combat=true,special='Bubbler'},
 Halver={job='Ring grinder',worker=true,combat=true,special='Halver'},
 Gridcutter={job='Grid cutter',worker=true,combat=true,special='Gridcutter'},
 Singularity={job='Gravity extractor',worker=true,combat=true,special='Singularity'},
 Starforge={job='Solar refiner',worker=true,combat=true,special='Starforge'},
 Frostbite={job='Cryogenic shatterer',worker=true,combat=true,special='Frostbite'},
 Resonator={job='Resonance extractor',worker=true,combat=true,special='Resonator'},
 Needler={job='Dart thrower',worker=true,special='Needler'},
 Ballcaster={job='Energy ball thrower',worker=true,special='Ballcaster'},
 Vacuum={job='Collects loose ore'},
}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function R.canonical(role) return legacy[role] or role end
local function capability(role,key)
 local definition=definitions[R.canonical(role)]
 return definition and definition[key]==true or false
end
function R.isWorker(role) return capability(role,'worker') end
function R.special(role)
 local definition=definitions[R.canonical(role)];return definition and definition.special or nil
end
function R.isSpecial(role) return R.special(role)~=nil end
function R.isMiner(role) return capability(role,'miner') end
function R.combat(role) return capability(role,'combat') end
function R.isGrower(role) return capability(role,'grower') end
function R.isCourier(role) return capability(role,'courier') end
function R.isHealer(role) return capability(role,'healer') end
function R.ability(role)
 local definition=definitions[R.canonical(role)];return definition and definition.ability or nil
end
function R.job(role)
 local definition=definitions[R.canonical(role)];return definition and definition.job or 'Unknown'
end
local function xyz(value)
 if type(value)~='table' then return nil end
 local p=value.position or value
 local x,y,z=p.x or p.X,p.y or p.Y,p.z or p.Z
 if finite(x) and finite(y) and finite(z) then return x,y,z end
 return nil
end
function R.chooseTarget(role,nodes,origin,now)
 role=R.canonical(role)
 if role~='Charger' then return nil end
 local x,y,z=xyz(origin);if not x or not finite(now) then return nil end
 local chosen,best=nil,-math.huge
 for _,node in ipairs(nodes or {}) do
  local nx,ny,nz=xyz(node)
  local ready=node.readyAt==nil or (finite(node.readyAt) and node.readyAt<=now)
  if nx and type(node.id)=='string' and finite(node.hp) and node.hp>0 and finite(node.maxHP) and node.maxHP>0
   and ready and node.paid~=true and node.eligible~=false then
   local distance=math.sqrt((nx-x)^2+(ny-y)^2+(nz-z)^2)
   local score
   do
    -- The impact specialist takes shells first, then substantial remaining work.
    local shell=node.kind=='Geode' and 120 or (node.kind=='Core' and 80 or 0)
    score=shell+math.min(node.hp,1000)*.08-distance*.7
   end
   if score and (score>best or (score==best and (not chosen or node.id<chosen.id))) then chosen=node;best=score end
  end
 end
 return chosen
end
local function breakerWindup(state)
 return finite(state.windup) and state.windup>0 and math.clamp(state.windup,.08,10) or R.BREAKER.windup
end
function R.newBreaker(targetId,now,windup)
 assert(type(targetId)=='string' and finite(now),'A breaker requires a server target and clock')
 return {targetId=targetId,phase='Approach',phaseAt=now,impactSerial=0,windup=windup}
end
function R.stepBreaker(state,now,context)
 if not finite(now) or now<state.phaseAt then return state.phase,nil end
 context=context or {}
 if state.phase=='Complete' or state.phase=='Canceled' then return state.phase,nil end
 if context.valid~=true or (context.targetId and context.targetId~=state.targetId) then
  state.phase='Canceled';state.phaseAt=now;return state.phase,'canceled'
 end
 local phase,event=state.phase,nil
 if phase=='Approach' and context.arrived==true then phase,event='Windup','windup'
 elseif phase=='Windup' and now-state.phaseAt>=breakerWindup(state) then phase,event='Dive','dive'
 elseif phase=='Dive' then
  if context.impactReached==true then
   phase,event='Impact','contact'
  elseif now-state.phaseAt>=R.BREAKER.diveLimit then phase,event='Recover','missed' end
 elseif phase=='Impact' and now-state.phaseAt>=R.BREAKER.impactHold then
  phase,event='Recover','impact';state.impactSerial+=1
 elseif phase=='Recover' and context.recovered~=false and now-state.phaseAt>=R.BREAKER.recovery then phase,event='Complete','complete' end
 if phase~=state.phase then state.phase=phase;state.phaseAt=now end
 return phase,event
end
function R.breakerPose(state,now)
 local t=finite(now) and math.max(0,now-state.phaseAt) or 0
 if state.phase=='Windup' then
  local p=math.clamp(t/breakerWindup(state),0,1);return {lift=(1-(1-p)^2)*1.2,dive=0,progress=p}
 elseif state.phase=='Dive' then
  local p=math.clamp(t/R.BREAKER.diveDuration,0,1);return {lift=1.2*(1-p),dive=p,progress=p}
 elseif state.phase=='Impact' then return {lift=0,dive=1,progress=1}
 elseif state.phase=='Recover' then
  local p=math.clamp(t/R.BREAKER.recovery,0,1);return {lift=0,dive=1-(1-(1-p)^2),progress=p}
 end
 return {lift=0,dive=0,progress=0}
end
return R
