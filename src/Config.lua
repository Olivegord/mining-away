--!strict
-- All numbers are provisional playtest tuning. No permanent fleet ownership cap.
local fields={
 {Name='Landing Quartz',Key='Quartz',Hardness=1,Color={255,0,0},ReferenceCrystals=true,Count=16,Ore=10,Value=1,Respawn=8,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Offset={58.9,0,68.4},Size={30,2,30}},
 {Name='Ruby Grove',Key='Ruby',Hardness=1.8,Color={226,75,112},Count=16,Ore=12,Value=2,Respawn=14,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Original='rubyPatch',Offset={-62.7,11.5,108.3},Size={42,2,42}},
 {Name='Cobalt Ridge',Key='Cobalt',Hardness=3.2,Color={89,150,234},Count=6,Ore=15,Value=4,Respawn=25,Turrets=1,TurretHP=260,Damage=19,ShotCooldown=1.8,RecommendedFleet=1,Original='cobaltPatch',Offset={1.9,18.5,-98.8},Size={42,2,42}},
 {Name='Violet Basin',Key='Violet',Hardness=5.2,Color={166,115,217},Count=9,Ore=16,Value=7,Respawn=35,Turrets=2,TurretHP=390,Damage=24,ShotCooldown=1.8,RecommendedFleet=3,Offset={106.4,28.5,-77.9},Size={47.6,2,44.8}},
 {Name='Deep Emerald',Key='Emerald',Hardness=8,Color={70,184,139},Count=12,Ore=20,Value=10,Respawn=45,Turrets=2,TurretHP=650,Damage=34,ShotCooldown=1.7,RecommendedFleet=5,Offset={172.9,38.5,30.4},Size={47.6,2,47.6}},
 {Name='Impact Test · 10x HP',Key='ImpactTest',Material='Quartz',AlwaysUnlocked=true,TestField=true,Hardness=1,HealthMultiplier=10,Color={180,225,213},Count=10,Ore=10,Value=1,Respawn=8,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Offset={132,0,76},Size={56,1,64}},
}
return {
 Tick=1/60, Snapshot=.1, MaxCatchup=6, Fleet=1, Capacity=120,
 MiningDPS=30, DroneDPS=12, Hull=80, Warmup=.8, Range=18,
 Reprint=10, Assembly=2, Grow=2, BreakCutoff=10, MinimumRockRespawn=65,
 CommandRadius=95, CommandGrace=3, TurretRange=42, Telegraph=.8,
 Fields=fields,Tiers=fields,
 -- Preview is permitted only in Studio; the production adapter never falls back after failure.
 DataStoreName='MiningAwayProfilesV2',ContentVersion=1,
}
