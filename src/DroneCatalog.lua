-- Permanent miner identities. The server owns every chunk and repeat cycle.
-- Power is a finite base-work budget; Chunk is a final cap after all modifiers.
local Catalog = {
 Order = {'Laser','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'},
 Types = {
  Laser = {Name='Miner',Price=60,Duration=0,Color={90,230,255},Description='One more permanent mining drone. Works a second rock and stays after prestige. Each additional Miner costs more.'},
  Bubbler = {Name='Bubbler',Price=1800,Duration=2.8,Impact=.68,Power=1.1,Chunk=.25,Yield=1.25,Color={120,225,255},Description='Captures and pops a mineral chunk per bubble cycle. Up to 25% rock health per hit; 1.25× ore on completion.'},
  Halver = {Name='Halver',Price=900,Duration=3.6,Impact=.68,Power=1.25,Chunk=.25,Yield=1.5,Color={190,140,255},Description='Clamps, splits and grinds a chunk each cycle. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Gridcutter = {Name='Gridcutter',Price=1400,Duration=2.5,Impact=.68,Power=1.2,Chunk=.25,Yield=1.2,Color={255,100,130},Description='Cross-scans and shears a small cube lattice. Up to 25% rock health per hit; 1.2× ore on completion.'},
  Singularity = {Name='Singularity',Price=6500,Duration=2,Impact=.68,Power=1.5,Chunk=.25,Yield=1.5,Color={155,100,255},Description='Tears a chunk into a contained gravity well. Up to 25% rock health per hit; 1.5× ore on completion.'},
  Starforge = {Name='Starforge',Price=2600,Duration=3,Impact=.68,Power=1.2,Chunk=.25,Yield=1.6,Color={255,170,60},Description='Heats and pours a molten mineral chunk. Up to 25% rock health per hit; 1.6× ore on completion.'},
  Frostbite = {Name='Frostbite',Price=650,Duration=2.4,Impact=.68,Power=1.05,Chunk=.25,Yield=1.1,Color={150,255,245},Description='Freezes and snaps a mineral chunk loose. Up to 25% rock health per hit; 1.1× ore on completion.'},
  Resonator = {Name='Resonator',Price=2100,Duration=2.6,Impact=.68,Power=1.15,Chunk=.25,Yield=1.3,Color={125,255,160},Description='Builds resonance, then releases one fracture pulse. Up to 25% rock health per hit; 1.3× ore on completion.'},
  Needler = {Name='Needler',Duration=.82,Impact=.36,Power=1.05,Chunk=.40,Projectile='Dart',Color={255,195,94},Description='Fires quick darts from beside a crystal.'},
  Ballcaster = {Name='Ballcaster',Duration=1.62,Impact=.35,Power=1.2,Chunk=.55,Projectile='Ball',Color={150,124,255},Description='Throws a heavy energy ball into the side of a crystal.'},
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
return Catalog
