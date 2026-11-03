-- Permanent miner identities. Work duration is authoritative, choreography is cosmetic.
local Catalog = {
 Order = {'Laser','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator'},
 Types = {
  Laser = {Name='Laser',Price=0,Duration=0,Color={90,230,255},Description='The original overhead mining beam. Reliable and steady.'},
  Bubbler = {Name='Bubbler',Price=1800,Duration=4.2,Yield=2,Color={120,225,255},Description='Glass bubbles swallow a rock, rise, fall, and shatter into gold. 2× ore.'},
  Halver = {Name='Halver',Price=900,Duration=8,Yield=3,Color={190,140,255},Description='Stretches, halves, and slowly ring-grinds a rock. Recovers 3× ore.'},
  Gridcutter = {Name='Gridcutter',Price=1400,Duration=5,Yield=2,Color={255,100,130},Description='Scans a laser grid, then nudges a rock into a spill of cubes. 2× ore.'},
  Singularity = {Name='Singularity',Price=6500,Duration=2.4,Yield=3,Color={155,100,255},Description='A tiny black hole swallows the entire rock. Extremely fast. 3× ore.'},
  Starforge = {Name='Starforge',Price=2600,Duration=5,Yield=4,Color={255,170,60},Description='A miniature sun melts a rock into molten rain. Refines 4× ore.'},
  Frostbite = {Name='Frostbite',Price=650,Duration=5.5,Color={150,255,245},Description='Flash-freezes a rock, then a sonic shockwave shatters its ice shell.'},
  Resonator = {Name='Resonator',Price=2100,Duration=4.8,Yield=3,Color={125,255,160},Description='Three pulsing resonance rings shake a rock into dust. Recovers 3× ore.'},
 },
}
return Catalog
