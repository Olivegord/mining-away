--!strict
return {
 Tick = 0.1, Speed = 24, Range = 17, DroneDPS = 8, Hull = 70,
 Fleet = 3, Capacity = 2000, Reprint = 10, Assembly = 2,
 Gather = 4, Disengage = 8, AssaultLimit = 90, Reset = 6, ClearWindow = 120,
 -- A finite locked fleet; no new identities/lives can join an active encounter.
 Tiers = {
  {Name='Ruby Meadow', Color={245,85,128}, HP=35, Reward=20, Count=16, Turrets=0, TurretHP=0, Damage=0, Power=0, Hull=0},
  {Name='Cobalt Shelf', Color={75,160,255}, HP=90, Reward=65, Count=9, Turrets=2, TurretHP=100, Damage=15, Power=1, Hull=1},
  {Name='Amber Bastion', Color={255,181,65}, HP=180, Reward=160, Count=10, Turrets=3, TurretHP=230, Damage=28, Power=3, Hull=3},
 },
 UpgradeCosts = {120,320,800,1800},
}
