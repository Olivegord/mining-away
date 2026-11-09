-- Pure mining rules shared by the authoritative server, UI and pacing model.
-- Drone types are permanent; these behaviors do not rewrite saved base traits.
local M={PULSE_INTERVAL=.8,RESONANCE_RANGE=10,HEALTH_MULTIPLIER=1,BOULDER_CHANCE=.2,BOULDER_WORK=3,BOULDER_SIZE=2.6,EXTRACTION_SHARE=.5}
M.SELECTOR_RANGE=44
local SELECTOR_GRID=2
function M.selectorCenter(position,frame,size)
 local point=frame:PointToObjectSpace(Vector3.new(position.X,frame.Position.Y,position.Z))
 local halfX,halfZ=size.X*.5,size.Z*.5
 if math.abs(point.X)>halfX or math.abs(point.Z)>halfZ then return nil end
 local maxX,maxZ=math.floor(halfX/SELECTOR_GRID),math.floor(halfZ/SELECTOR_GRID)
 local x=math.clamp(math.round(point.X/SELECTOR_GRID),-maxX,maxX)*SELECTOR_GRID
 local z=math.clamp(math.round(point.Z/SELECTOR_GRID),-maxZ,maxZ)*SELECTOR_GRID
 return frame:PointToWorldSpace(Vector3.new(x,size.Y*.5,z))
end
-- Horizontal separating axes for the square and the crystal's current body.
-- A crystal touching the boundary is eligible even if its center is outside.
function M.selectorTouches(center,half,frame,size)
 local x,z=center.X-frame.Position.X,center.Z-frame.Position.Z
 local right,back=frame.RightVector,-frame.LookVector
 local rx,rz=right.X,right.Z
 local bx,bz=back.X,back.Z
 local sx,sz=size.X*.5,size.Z*.5
 return math.abs(x)<=half+math.abs(rx)*sx+math.abs(bx)*sz
  and math.abs(z)<=half+math.abs(rz)*sx+math.abs(bz)*sz
  and math.abs(x*rx+z*rz)<=sx+half*(math.abs(rx)+math.abs(rz))
  and math.abs(x*bx+z*bz)<=sz+half*(math.abs(bx)+math.abs(bz))
end
local roleKinds={Dart='Blue',Striker='Blue',Medic='Green',Charger='Red',Orbiter='Blue',Scrapper='Blue'}
function M.kind(kind: string): string return roleKinds[kind] or kind end
local styles={Blue='Cutter',Red='Percussion',Green='Resonance'}
local descriptions={
 Blue='Cutter · steady single-crystal mining',
 Red='Percussion · charged hits; +50% shell/core damage',
 Green='Healer · repairs nearby drones for 10 health every 2 seconds',
}
function M.style(kind: string): string return styles[M.kind(kind)] or 'Cutter' end
function M.description(kind: string): string
 local roles={Dart='Cultivator · plants replacement rocks in depleted fields',Striker='Miner · cuts one crystal with a continuous laser',Medic='Healer · follows allies; 10 health every 2 seconds',Courier='Backpack emptier · carries 8 ore to storage, then returns',Charger='Breaker · winds up, dives, hits, then recovers',Orbiter='Orbital · charges, then melts the biggest rock over time',Scrapper='Swarm · launches tiny miners for 10 seconds'}
 return roles[kind] or descriptions[M.kind(kind)] or descriptions.Blue
end
function M.workRole(kind: string): string
 return ({Dart='Rock grower',Striker='Miner',Medic='Healer',Courier='Backpack emptier',Charger='Breaker',Orbiter='Orbital controller',Scrapper='Swarm fabricator',Blue='Miner',Red='Breaker',Green='Healer'})[kind] or 'Cutter'
end
function M.resource(roll: number,kind: string,hardness: number?)
 -- The original random size remains 2–4 studs. Hardness increases work, never
 -- the footprint, height or station of an otherwise identical mineral.
 local mass=roll*(kind=='Geode' and 3 or 1)
 local work=(mass-10)*(hardness or 1)*M.HEALTH_MULTIPLIER
 local size=mass/(kind=='Geode' and 37.5 or 25)*(kind=='Shard' and .8 or 1)
 return {maxHP=work+10,work=work,size=size,mass=mass}
end
-- Cumulative base ore released by real layer fractures. The rest belongs to
-- the final collapse; crossing several layers at once never duplicates ore.
function M.extractedOre(ore: number,stage: number,count: number): number
 return math.floor(ore*M.EXTRACTION_SHARE*math.clamp(stage/math.max(1,count),0,1))
end
function M.efficiency(kind: string,nodeKind: string): number
 return M.kind(kind)=='Red' and (nodeKind=='Geode' or nodeKind=='Core') and 1.5 or 1
end
-- Outer hard layers reward a physical breaker; exposed inner layers reward
-- steady cutters. This changes the best fleet/target pairing, without a timer
-- gate or invalidating the existing continuous hit and fracture rules.
function M.contactMultiplier(role,_nodeKind,hardness,stage,count)
 local progress=math.clamp((stage or 0)/math.max(1,count or 3),0,1)
 if role=='Charger' then
  local resistance=math.clamp(((hardness or 1)-1)/7,0,1)
  return 1+resistance*(1-progress)*1.5
 end
 if (role=='Striker' or role=='Blue') and (hardness or 1)>1 then return 1+progress*.35 end
 return 1
end
function M.step(kind: string,charge: number?,dt: number,dps: number): (number,number,number)
 if dt<=0 then return 0,charge or 0,0 end
 if M.kind(kind)~='Red' then return dps*dt,0,0 end
 local elapsed=(charge or 0)+dt
 local count=math.floor((elapsed+1e-9)/M.PULSE_INTERVAL)
 return count*M.PULSE_INTERVAL*dps,math.max(0,elapsed-count*M.PULSE_INTERVAL),count
end
function M.duration(kind: string,nodeKind: string,work: number,dps: number,geodeMultiplier: number?): number
 if work<=0 then return 0 end
 local rate=dps*M.efficiency(kind,nodeKind)
 if nodeKind=='Geode' or nodeKind=='Core' then rate=rate*(geodeMultiplier or 1) end
 local seconds=work/math.max(.001,rate)
 if M.kind(kind)=='Red' then seconds=math.ceil(seconds/M.PULSE_INTERVAL-1e-9)*M.PULSE_INTERVAL end
 return seconds
end
function M.resonanceDamage(maxHP: number,dps: number,crossed: number): number
 -- At most three quarters on one primary hit, one destination, no recursive
 -- echoes. Hard minerals cannot turn a fracture into unbounded burst damage.
 return math.min(maxHP*.25*.35,dps*.8)*math.clamp(crossed,0,3)
end
function M.targetScore(kind: string,stats: any,node: any,distance: number,neighbors: number?): number
 local role=kind
 kind=M.kind(kind)
 -- An estimate for autonomous selection, not an authority/reach test. Actual
 -- movement remains the original eased/capped flight and exact arrival gate.
 local travel=distance/math.max(1,stats.maxStep60*60)+math.log(1+distance)*.35
 local seconds=travel+stats.warmup+M.duration(kind,node.kind,node.hp,stats.miningDPS,stats.geodeMultiplier)
 local yield=math.max(1,node.ore)
 if node.kind=='Geode' then
  -- A shell itself pays nothing: include the growing core, a fresh warmup and
  -- its work before valuing the first 4× payout. No speculative shard windfall.
  seconds=seconds+2+stats.warmup+M.duration(kind,'Core',65*(node.hardness or 1),stats.miningDPS,stats.geodeMultiplier)
  yield=yield*4
  if kind=='Blue' then seconds=seconds*1.25 end
 elseif kind=='Green' then
  seconds=seconds/(1+math.min(neighbors or 0,3)*.10+math.min(node.stage or 0,3)*.08)
 end
 if role=='Dart' then seconds=seconds*(node.kind=='Shard' and .75 or 1)+distance*.035 end
 if role=='Medic' and node.kind=='Shard' then seconds=seconds*.7 end
 return seconds/yield
end
return M
