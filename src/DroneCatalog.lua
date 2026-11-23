-- Permanent miner identities. The server owns every chunk and repeat cycle.
-- Power is a finite base-work budget; Chunk is a final cap after all modifiers.
local Catalog = {
 Order = {'Laser','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator','Ramiel','Nomad'},
 Types = {
  Laser = {Name='Miner',Price=60,Duration=0,Color={90,230,255},Description='One more permanent mining drone. Works a second rock and stays after prestige. Each additional Miner costs more.'},
  Bubbler = {Name='Bubbler',Price=1800,Duration=2.8,Impact=.68,Power=1.1,Chunk=.25,Yield=1.25,Color={120,225,255},Description='Captures and pops a mineral chunk per bubble cycle. Up to 25% rock health per hit; 1.25× ore on completion.'},
  Halver = {Name='Halver',Price=900,Duration=3.6,Impact=.68,Power=1.25,Chunk=.25,Yield=1.5,Color={190,140,255},Description='Clamps, splits and grinds a chunk each cycle. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Gridcutter = {Name='Crescent',Price=1400,Duration=2.5,Impact=.68,Power=1.2,Chunk=.25,Yield=1.2,Color={196,150,255},Description='Cuts the rock with angled crescent slashes; each slash shears a piece loose. 1.2× ore on completion.'},
  Singularity = {Name='Singularity',Price=6500,Duration=2,Impact=.68,Power=1.5,Chunk=.25,Yield=1.5,Color={155,100,255},Description='Tears a chunk into a contained gravity well. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Starforge = {Name='Starfall',Price=2600,Duration=3,Impact=.68,Power=1.2,Chunk=.25,Yield=1.6,Color={110,150,255},Description='Launches a wandering star that bursts on the rock; gems it finds can rise a tier. 1.6× ore on completion.'},
  Frostbite = {Name='Frostbite',Price=650,Duration=2.4,Impact=.68,Power=1.05,Chunk=.25,Yield=1.1,Color={150,255,245},Description='Freezes and snaps a mineral chunk loose. Up to 25% rock health per hit; 1.1× ore on completion.'},
  Resonator = {Name='Stormcaller',Price=2100,Duration=2.6,Impact=.68,Power=1.15,Chunk=.25,Yield=1.3,Color={170,90,255},Description='Calls down living lightning; every break arcs on into small neighbouring cells. 1.3× ore on completion.'},
  Ramiel = {Name='Ramiel',Duration=2.80,CycleDuration=8.40,Impact=5/8.40,Power=4.4,Chunk=1,Yield=1.35,Projectile='Prism',Windup=4.94,Flight=.06,BeamHold=.42,BlackPause=.055,BeamRange=64,BeamStation=32,BeamTargets=4,BlastRadius=11,CorePower=1,Color={93,203,255},Description='Blackens crystals near the beam impact, then shatters them together for 35% extra ore.'},
  Nomad = {Name='Nomad',Duration=3,CycleDuration=9.20,Impact=5/9.20,Power=4,Chunk=1,Yield=1,Projectile='Nomad',Windup=4.05,Flight=.95,StationHeight=38,BlastRadius=13,BlastTargets=5,Color={101,194,255},Description='Sweeps the field from high above and drops a tiny rocket that shatters up to five nearby crystals.'},
  Orbiter = {Name='Orbital',Duration=0,Color={195,135,255},Description='Calls a sky laser onto the strongest available crystal and spills damage into a second nearby rock.'},
  Needler = {Name='Needler',Duration=.165,Impact=.55,Power=1.12,Chunk=.10,Projectile='Dart',Windup=.05,Flight=.04,Recovery=.025,CorePower=1.25,Color={255,195,94},Description='Fires a rapid stream of light darts. Deals 25% more damage after the first two layers of deep crystals.'},
  Ballcaster = {Name='Ballcaster',Duration=1.62,Impact=.51,Power=1.2,Chunk=.55,Projectile='Ball',Windup=.56,Flight=.26,ShellPower=1.5,Color={150,124,255},Description='Charges a heavy shot that deals 50% more damage through the first two layers of deep crystals.'},
  -- Pulse laser (owner's reference video). Earned through prestige, not in
  -- the shop Order; Impact/Power/Chunk only keep the field chunk scoring
  -- (DroneCatalog.cycle) defined: on the fields it mines like a Striker.
  Lancer = {Name='Lancer',Price=1500,Duration=.7,Impact=.5,Power=1,Chunk=.25,Color={255,236,170},Description='Fires short, punchy laser pulses: each pulse bites a big piece out of the rock.'},
 },
}
-- Every worker role can be earned (weights total 100). Each digs the Dig
-- Cube its own way (DigCube.STYLES).
Catalog.PrestigeRewards={
 {kind='Blue',name='Laser Miner',tier=1,weight=16,job='Steady crystal cutting'},
 {kind='Red',name='Breaker',tier=1,weight=14,job='Heavy hits on hard outer layers'},
 {kind='Ballcaster',name='Ballcaster',tier=1,weight=14,job='Charges one ball and pops a small cell in one hit'},
 {kind='Needler',name='Needler',tier=1,weight=10,job='Dart streams that spot hidden gems nearby'},
 {kind='Bubbler',name='Bubbler',tier=2,weight=10,job='Bubble cuts with 25% more ore'},
 {kind='Gridcutter',name='Crescent',tier=2,weight=8,job='Angled crescent slashes that shear pieces loose'},
 {kind='Frostbite',name='Frostbite',tier=2,weight=7,job='Freezes the rock around each cut so the crew breaks it faster'},
 {kind='Resonator',name='Stormcaller',tier=2,weight=6,job='Living lightning; each break arcs into small neighbouring cells'},
 {kind='Lancer',name='Lancer',tier=2,weight=6,job='Short laser pulses that bite big pieces out of the rock'},
 {kind='Halver',name='Halver',tier=3,weight=4,job='Heavy cuts with 50% more ore'},
 {kind='Starforge',name='Starfall',tier=3,weight=3,job='A wandering star that bursts on the rock and can raise a gem a tier'},
 {kind='Singularity',name='Singularity',tier=4,weight=2,job='Fast gravity pulses with 50% more ore'},
}
function Catalog.prestigeReward(seed,index)
 local prime=2147483647
 local state=(seed*48271+index%prime*69621)%prime
 local ticket=(state*48271)%prime%100+1
 for _,reward in ipairs(Catalog.PrestigeRewards) do
  ticket-=reward.weight
  if ticket<=0 then return reward end
 end
 error('Prestige reward weights must total 100')
end
-- Three distinct weighted choices, stable for a run across reconnects.
-- Owner, Nov 22: "only work on like 6 drones or less. all 14 is too much
-- of an undertaking before all the game is ready." Only these types are
-- offered for now; the rest stay in the code, dormant. Saved fleets keep
-- whatever they already own.
-- Owner follow-up: "keep ramiel for now".
-- Owner, Nov 22 (references): Crescent, Starfall and Stormcaller join,
-- replacing the dormant Gridcutter, Starforge and Resonator ideas.
Catalog.ACTIVE={Blue=true,Red=true,Lancer=true,Needler=true,Ballcaster=true,Frostbite=true,Ramiel=true,Gridcutter=true,Starforge=true,Resonator=true}
function Catalog.prestigeChoices(seed,index,owned)
 local prime=2147483647
 local state=(seed%prime*48271+index%prime*69621)%prime
 local pool={}
 for _,entry in ipairs(Catalog.PrestigeRewards) do if Catalog.ACTIVE[entry.kind] then table.insert(pool,entry) end end
 local choices={}
 for _=1,3 do
  -- A new mining behavior is a stronger early reward than a fourth identical
  -- chassis. Exhaust unowned roles first, then retain useful duplicate choices.
  local novel=false
  if owned then for _,entry in ipairs(pool) do if not owned[entry.kind] then novel=true;break end end end
  local total=0
  for _,entry in ipairs(pool) do if not novel or not owned[entry.kind] then total+=entry.weight end end
  state=(math.max(1,state)*48271)%prime
  local ticket=state%total+1
  for i,entry in ipairs(pool) do
   if novel and owned[entry.kind] then continue end
   ticket-=entry.weight
   if ticket<=0 then
    choices[#choices+1]={kind=entry.kind,name=entry.name,tier=entry.tier,job=entry.job}
    table.remove(pool,i);break
   end
  end
 end
 return choices
end
function Catalog.price(kind,fleet)
 local definition=Catalog.Types[kind];if not definition then return nil end
 if kind~='Laser' then return definition.Price end
 local miners=0
 for _,d in ipairs(fleet or {}) do if (d.role or d.type)=='Striker' or (not d.role and d.type=='Blue') then miners+=1 end end
 return math.floor(definition.Price*1.8^math.min(38,math.max(0,miners-1)))
end
local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end
function Catalog.cycle(kind,baseDPS,effectiveDPS)
 local definition=Catalog.Types[kind]
 if not definition or definition.Duration<=0 or not finite(baseDPS) or baseDPS<=0 or not finite(effectiveDPS) or effectiveDPS<=0 then return nil end
 -- Mining cards improve cycle rate once, rather than multiplying both damage
 -- and rate. A hard field still requires its full finite amount of work.
 local duration=(definition.CycleDuration or definition.Duration)/math.clamp(effectiveDPS/baseDPS,.25,4)
 return {duration=duration,impact=definition.Impact,damage=baseDPS*definition.Duration*definition.Power}
end
function Catalog.capDamage(kind,maxHP,damage)
 local definition=Catalog.Types[kind]
 if not definition or not definition.Chunk or not finite(maxHP) or not finite(damage) then return 0 end
 -- Ten HP is the original visual cutoff, not mineable work.
 return math.max(0,math.min(damage,math.max(0,maxHP-10)*definition.Chunk))
end
function Catalog.chunkTargetScore(kind,cycle,warmup,speed,node,distance)
 local damage=Catalog.capDamage(kind,node.maxHP,cycle.damage)
 if damage<=0 then return math.huge end
 local hits=math.max(1,math.ceil(node.hp/damage-1e-10))
 local travel=distance/math.max(1,speed*60)+math.log(1+distance)*.35
 return (travel+warmup+(hits-1+cycle.impact)*cycle.duration)/math.max(1,node.ore)
end
local SHELL_LAYERS=2
function Catalog.projectileTargetScore(kind,stats,node,distance)
 local travel=distance/math.max(1,stats.maxStep60*60)
 local rate=math.max(1,stats.miningDPS)
 local shellPower=Catalog.Types[kind].ShellPower
 if shellPower then
  -- Compare the time the heavier shot saves on the remaining shell with
  -- the time it takes to reach the deposit.
  local shellEnd=math.max(0,node.maxHP*(1-SHELL_LAYERS/(node.stageCount+1))-10)
  local shellWork=math.max(0,node.hp-shellEnd)
  return travel-shellWork/rate*(1-1/shellPower)
 end
 local shellEnd=math.max(0,node.maxHP*(1-SHELL_LAYERS/(node.stageCount+1))-10)
 local coreWork=math.min(node.hp,shellEnd)
 return travel+(node.hp-coreWork+coreWork/Catalog.Types[kind].CorePower)/rate
end
function Catalog.projectileLayerPower(kind,stage)
 local def=Catalog.Types[kind]
 return (stage<SHELL_LAYERS and def.ShellPower or stage>=SHELL_LAYERS and def.CorePower) or 1
end
return Catalog
