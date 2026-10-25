--!strict
-- All numbers are provisional playtest tuning. No permanent fleet ownership cap.
local fields={
 {Name='Landing Quartz',Key='Quartz',Color={180,225,213},Count=12,Ore=10,Value=1,Respawn=8,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Offset={30,0,43},Size={34,2,34}},
 {Name='Ruby Grove',Key='Ruby',Color={226,75,112},Count=16,Ore=12,Value=2,Respawn=14,Turrets=0,TurretHP=0,Damage=0,RecommendedFleet=1,Original='rubyPatch',Offset={-33,11.5,66},Size={30,2,30}},
 {Name='Cobalt Ridge',Key='Cobalt',Color={89,150,234},Count=6,Ore=15,Value=4,Respawn=25,Turrets=1,TurretHP=260,Damage=19,ShotCooldown=1.8,RecommendedFleet=1,Original='cobaltPatch',Offset={7,0,-74},Size={34,2,34}},
 {Name='Violet Basin',Key='Violet',Color={166,115,217},Count=9,Ore=16,Value=6,Respawn=35,Turrets=2,TurretHP=390,Damage=24,ShotCooldown=1.8,RecommendedFleet=3,Offset={85,1.5,-57},Size={40,2,38}},
 {Name='Deep Emerald',Key='Emerald',Color={70,184,139},Count=12,Ore=20,Value=8,Respawn=45,Turrets=2,TurretHP=650,Damage=34,ShotCooldown=1.7,RecommendedFleet=5,Offset={147,3.5,-15},Size={42,2,42}},
}
return {
 Tick=1/60, Snapshot=.1, MaxCatchup=6, Fleet=1, Capacity=120,
 MiningDPS=30, DroneDPS=12, Hull=80, Warmup=.8, Range=18,
 Reprint=10, Assembly=2, Grow=2, BreakCutoff=10,
 Gather=4, Disengage=8, AssaultLimit=90, Reset=6, ExpeditionGrace=8,
 CommandRadius=95, CommandGrace=3, TurretRange=42, Telegraph=.8,
 Fields=fields,Tiers=fields,
 -- Preview is permitted only in Studio; the production adapter never falls back after failure.
 DataStoreName='MiningAwayProfilesV2',ContentVersion=1,
}
