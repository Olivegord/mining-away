-- Authoritative, bounded mining gadgets. No rewards, ownership, input timestamps
-- or client-selected targets are trusted here. Context owns the normal hit path.
local A={}
A.KINDS={Orbital={cooldown=45},Scrap={cooldown=35}}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function point(p)
 return {x=p.x or p.X or 0,y=p.y or p.Y or 0,z=p.z or p.Z or 0}
end
local function distance(a,b)
 local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z;return math.sqrt(x*x+y*y+z*z)
end
local function usable(r)
 return type(r)=='table' and type(r.id)=='string' and finite(r.hp) and r.hp>0 and finite(r.maxHP) and r.maxHP>0
  and finite(r.x) and finite(r.y) and finite(r.z)
end
local function targets(ctx,fieldId)
 local list={}
 for _,r in ipairs(ctx.targets(fieldId) or {}) do if usable(r) then table.insert(list,r) end end
 table.sort(list,function(a,b) if a.maxHP==b.maxHP then return a.id<b.id end;return a.maxHP>b.maxHP end)
 return list
end
local function event(ctx,kind,record)
 record=record or {};record.kind=kind;ctx.emit(record)
end
function A.new(savedCooldowns,runId)
 local cooldowns={}
 for kind in pairs(A.KINDS) do
  local saved=type(savedCooldowns)=='table' and savedCooldowns[kind]
  if finite(saved) and saved>=0 and saved<1e14 then cooldowns[kind]=saved end
 end
 return {sequence=0,cooldowns=cooldowns,runId=runId,charge=nil,swarm=nil}
end
function A.cancel(state,ctx)
 state.charge=nil;state.swarm=nil
 if ctx then event(ctx,'clear') end
end
function A.pause(state,dt)
 if not finite(dt) or dt<=0 then return end
 local charge=state.charge
 if charge then
  for _,key in ipairs({'started','sweetStart','sweetEnd','expires'}) do charge[key]+=dt end
 end
 if state.swarm then state.swarm.started+=dt;state.swarm.expires+=dt;state.swarm.nextPose=0 end
end
function A.begin(state,kind,now,ctx)
 if not finite(now) or not A.KINDS[kind] then return false,'Unknown mining gadget' end
 if state.runId~=ctx.runId then A.cancel(state,ctx);state.runId=ctx.runId;state.cooldowns={} end
 if not ctx.unlocked(kind) then return false,'Buy this gadget in its mineral shop first' end
 if state.charge then return false,'Finish the current gadget charge first' end
 if kind=='Scrap' and state.swarm then return false,'Scrap bots are already working' end
 if now<(state.cooldowns[kind] or 0) then return false,'Gadget cooling down' end
 if not ctx.valid(ctx.fieldId) or ctx.full() then return false,'Use this beside an unlocked, unguarded plot with backpack space' end
 local list=targets(ctx,ctx.fieldId)
 if #list==0 then return false,'No grown crystals are ready' end
 state.sequence+=1
 state.charge={kind=kind,fieldId=ctx.fieldId,targetId=list[1].id,target=point(list[1]),
  token=ctx.runId..':gadget:'..state.sequence,started=now,sweetStart=now+.7,sweetEnd=now+1.2,expires=now+2.5}
 event(ctx,'charge',{ability=kind,target=list[1],expires=now+2.5})
 return true,'Tap in the marked window for a precision effect'
end
function A.confirm(state,token,now,ctx)
 local charge=state.charge
 if state.runId~=ctx.runId or not charge or token~=charge.token or not finite(now) then return false,'Charge changed; try again' end
 if now>charge.expires then state.charge=nil;event(ctx,'clearCharge');return false,'Charge expired; no cooldown spent' end
 if now<charge.started+.08 then return false,'Let the gadget charge briefly' end
 if not ctx.unlocked(charge.kind) or not ctx.valid(charge.fieldId) or ctx.full() then
  state.charge=nil;event(ctx,'clearCharge');return false,'Gadget canceled; return to the plot with backpack space'
 end
 local list=targets(ctx,charge.fieldId);local target
 for _,r in ipairs(list) do if r.id==charge.targetId then target=r;break end end
 if not target then state.charge=nil;event(ctx,'clearCharge');return false,'That crystal was mined; no cooldown spent' end
 local precise=now>=charge.sweetStart and now<=charge.sweetEnd
 state.charge=nil
 local perks=ctx.perks or {}
 local cooldown=A.KINDS[charge.kind].cooldown
 if charge.kind=='Orbital' and perks.orbitalCycle then cooldown=30 end
 state.cooldowns[charge.kind]=now+cooldown
 if charge.kind=='Orbital' then
  -- The largest saved target is vaporized through the ordinary server hit path.
  -- A precision strike cracks nearby rocks; it never recursively triggers itself.
  local accepted=ctx.hit(target.id,target.hp+10,'Orbital',{x=target.x,y=target.y+34,z=target.z})
  if accepted then
   event(ctx,'orbital',{target=target,precise=precise})
   local relays=precise and 1 or 0
   for _,r in ipairs(list) do
    if relays>0 and r.id~=target.id and distance(target,r)<=14 and not ctx.full() then
     if ctx.hit(r.id,math.max(1,r.maxHP*.26),'OrbitalRelay',{x=r.x,y=r.y+9,z=r.z}) then event(ctx,'relay',{from=target,target=r});relays-=1 end
    end
   end
  else
   state.cooldowns[charge.kind]=now;event(ctx,'clearCharge')
   return false,'Orbital contact blocked; no cooldown spent'
  end
 else
  local origin=point(ctx.origin);local bots={}
  for i=1,math.min(6,(precise and 6 or 4)+math.clamp(perks.scrapBots or 0,0,2)) do
   local angle=i*2.399963
   table.insert(bots,{id=i,x=origin.x+math.cos(angle)*1.1,y=origin.y+.5,z=origin.z+math.sin(angle)*1.1,
    targetId=nil,charge=0,pulse=0,active=false})
  end
  state.swarm={fieldId=charge.fieldId,started=now,expires=now+10,bots=bots,nextPose=0}
  event(ctx,'scrapStart',{expires=now+10,count=#bots,precise=precise})
 end
 return true,precise and 'Precision! Gadget deployed' or 'Gadget deployed'
end
function A.step(state,now,dt,ctx)
 if not finite(now) or not finite(dt) or dt<=0 then return end
 if state.runId~=ctx.runId then A.cancel(state,ctx);state.runId=ctx.runId;state.cooldowns={};return end
 if state.charge and now>state.charge.expires then state.charge=nil;event(ctx,'clearCharge') end
 local swarm=state.swarm
 if not swarm then return end
 if now>=swarm.expires or not ctx.valid(swarm.fieldId) or ctx.full() or not ctx.unlocked('Scrap') then
  state.swarm=nil;event(ctx,'clearScrap');return
 end
 -- No catch-up burst after a stall. At most six normal hit callbacks per step.
 dt=math.min(dt,.1)
 local list=targets(ctx,swarm.fieldId);local byId={};for _,r in ipairs(list) do byId[r.id]=r end
 local taken={}
 for _,bot in ipairs(swarm.bots) do
  local target=byId[bot.targetId]
  if not target then
   local best=math.huge
   for _,r in ipairs(list) do if (taken[r.id] or 0)<2 then
    -- Small leftovers are useful prey; the orbital tool handles big rocks.
    local score=r.hp*.12+distance(bot,r)
    if score<best then best=score;target=r end
   end end
   if not target then target=list[#list] end
   bot.targetId=target and target.id or nil;bot.charge=0
  end
  bot.active=false;bot.target=nil
  if target and not ctx.full() then
   local slot=(taken[target.id] or 0)+1;taken[target.id]=slot
   local radius=finite(target.radius) and math.max(.1,target.radius) or .6
   local offset=math.min(.3,radius*.35)*(slot%2==0 and 1 or -1)
   local goal={x=target.x+offset,y=target.y+1.2+math.floor((slot-1)/2)*.45,z=target.z};local d=distance(bot,goal)
   local vx,vy,vz=bot.vx or 0,bot.vy or 0,bot.vz or 0
   local speed=math.min(12,d*5.5,math.sqrt(40*d));local scale=d>.001 and speed/d or 0
   local dx,dy,dz=(goal.x-bot.x)*scale-vx,(goal.y-bot.y)*scale-vy,(goal.z-bot.z)*scale-vz
   local change=math.sqrt(dx*dx+dy*dy+dz*dz);local thrust=change>.001 and math.min(1,20*dt/change) or 0
   local nx,ny,nz=vx+dx*thrust,vy+dy*thrust,vz+dz*thrust
   bot.x+=(vx+nx)*dt*.5;bot.y+=(vy+ny)*dt*.5;bot.z+=(vz+nz)*dt*.5
   bot.vx,bot.vy,bot.vz=nx,ny,nz
   if distance(bot,goal)<=math.min(.15,radius*.25) then
    bot.active=true;bot.target={x=goal.x,y=target.y,z=goal.z};bot.charge+=dt
    if bot.charge>=.25 then
     bot.charge-=.25
     -- A bounded chip of authored crystal work keeps tiny tools consequential
     -- in later fields. Paired bots cooperate rather than polishing many rocks
     -- for ten seconds without finishing one. Hardness still matters at the cap.
     local chip=math.max(2,math.min(8,target.maxHP/48))
     local accepted=ctx.hit(target.id,chip,'Scrap',point(bot))
     if accepted then
      bot.pulse+=1

     end
    end
   else bot.charge=0 end
  else bot.charge=0 end
 end
 if now>=swarm.nextPose then
  swarm.nextPose=now+.1;event(ctx,'scrapPose',{bots=swarm.bots,expires=swarm.expires})
 end
end
function A.view(state,_now)
 local view={runId=state.runId,cooldowns={Orbital=state.cooldowns.Orbital or 0,Scrap=state.cooldowns.Scrap or 0},swarmUntil=state.swarm and state.swarm.expires or 0}
 if state.charge then
  local c=state.charge;view.charge={kind=c.kind,token=c.token,started=c.started,sweetStart=c.sweetStart,sweetEnd=c.sweetEnd,expires=c.expires}
 end
 return view
end
return A
