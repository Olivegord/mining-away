-- Permanent miner identities. The server owns every chunk and repeat cycle.
-- Power is a finite base-work budget; Chunk is a final cap after all modifiers.
local Catalog = {
 Order = {'Laser','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator','Ramiel'},
 Types = {
  Laser = {Name='Miner',Price=60,Duration=0,Color={90,230,255},Description='One more permanent mining drone. Works a second rock and stays after prestige. Each additional Miner costs more.'},
  Bubbler = {Name='Bubbler',Price=1800,Duration=2.8,Impact=.68,Power=1.1,Chunk=.25,Yield=1.25,Color={120,225,255},Description='Captures and pops a mineral chunk per bubble cycle. Up to 25% rock health per hit; 1.25× ore on completion.'},
  Halver = {Name='Halver',Price=900,Duration=3.6,Impact=.68,Power=1.25,Chunk=.25,Yield=1.5,Color={190,140,255},Description='Clamps, splits and grinds a chunk each cycle. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Gridcutter = {Name='Gridcutter',Price=1400,Duration=2.5,Impact=.68,Power=1.2,Chunk=.25,Yield=1.2,Color={255,100,130},Description='Cross-scans and shears a small cube lattice. Up to 25% rock health per hit; 1.2× ore on completion.'},
  Singularity = {Name='Singularity',Price=6500,Duration=2,Impact=.68,Power=1.5,Chunk=.25,Yield=1.5,Color={155,100,255},Description='Tears a chunk into a contained gravity well. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Starforge = {Name='Starforge',Price=2600,Duration=3,Impact=.68,Power=1.2,Chunk=.25,Yield=1.6,Color={255,170,60},Description='Heats and pours a molten mineral chunk. Up to 25% rock health per hit; 1.6× ore on completion.'},
  Frostbite = {Name='Frostbite',Price=650,Duration=2.4,Impact=.68,Power=1.05,Chunk=.25,Yield=1.1,Color={150,255,245},Description='Freezes and snaps a mineral chunk loose. Up to 25% rock health per hit; 1.1× ore on completion.'},
  Resonator = {Name='Resonator',Price=2100,Duration=2.6,Impact=.68,Power=1.15,Chunk=.25,Yield=1.3,Color={125,255,160},Description='Builds resonance, then releases one fracture pulse. Up to 25% rock health per hit; 1.3× ore on completion.'},
  Ramiel = {Name='Ramiel',Duration=2.80,Impact=.71,Power=4.4,Chunk=.68,Yield=1.35,Projectile='Prism',Windup=1.94,Flight=.06,CorePower=1,Color={93,203,255},Description='Unfolds a glass aperture and fires a heavy prism lance. Each pulse can cut up to 68% of a crystal and pays 35% extra ore on completion.'},
  Orbiter = {Name='Orbital',Duration=0,Color={195,135,255},Description='Calls a sky laser onto the strongest available crystal and spills damage into a second nearby rock.'},
  Needler = {Name='Needler',Duration=.66,Impact=.55,Power=1.12,Chunk=.40,Projectile='Dart',Windup=.20,Flight=.16,CorePower=1.25,Color={255,195,94},Description='Fires quick darts. Deals 25% more damage after the first two layers of deep crystals.'},
  Ballcaster = {Name='Ballcaster',Duration=1.62,Impact=.51,Power=1.2,Chunk=.55,Projectile='Ball',Windup=.56,Flight=.26,ShellPower=1.5,Color={150,124,255},Description='Charges a heavy shot that deals 50% more damage through the first two layers of deep crystals.'},
 },
}
Catalog.PrestigeRewards={
 {kind='Blue',name='Laser Miner',tier=1,weight=45,job='Steady crystal cutting'},
 {kind='Red',name='Breaker',tier=1,weight=25,job='Heavy hits on hard outer layers'},
 {kind='Bubbler',name='Bubbler',tier=2,weight=15,job='Bubble cuts with 25% more ore'},
 {kind='Gridcutter',name='Gridcutter',tier=2,weight=9,job='Quick passes with 20% more ore'},
 {kind='Halver',name='Halver',tier=3,weight=5,job='Heavy cuts with 50% more ore'},
 {kind='Singularity',name='Singularity',tier=4,weight=1,job='Fast gravity pulses with 50% more ore'},
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
function Catalog.prestigeChoices(seed,index)
 local prime=2147483647
 local state=(seed%prime*48271+index%prime*69621)%prime
 local pool=table.clone(Catalog.PrestigeRewards)
 local choices={}
 for _=1,3 do
  local total=0
  for _,entry in ipairs(pool) do total+=entry.weight end
  state=(math.max(1,state)*48271)%prime
  local ticket=state%total+1
  for i,entry in ipairs(pool) do
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
 local duration=definition.Duration/math.clamp(effectiveDPS/baseDPS,.25,4)
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
