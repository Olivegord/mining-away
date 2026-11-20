-- Uses actual production work/stage/multiplier functions. These are work-only
-- estimates, excluding travel, LOS, missed hits, carrying/sales and player choice.
local M=require('../src/Mining');local F=require('../src/Feel');local C=require('../src/Config')
local function cut(hardness,boost)
 local r=M.resource(75,'Crystal',hardness);local hp=r.work;local t=0
 while hp>0 and t<200 do
  local stage=F.stage(hp+10,r.maxHP,3)
  hp-=30*boost*M.contactMultiplier('Striker','Crystal',hardness,stage,3)/60;t+=1/60
 end
 return t
end
print('Work-only feasibility seconds: median-size ordinary crystal; excludes travel/warmup/selling')
for _,field in ipairs(C.Fields) do if not field.TestField then
 local base=cut(field.Hardness,1);local upgraded=cut(field.Hardness,1.5)
 assert(base>0 and upgraded<base and base<100)
 print(string.format('%s hardness %.1f: base %.2fs / +50%% cutter %.2fs / %d ore at value %d',field.Key,field.Hardness,base,upgraded,field.Ore,field.Value))
end end
assert(cut(8,1)>cut(1,1)*6.5,'hardness lost its actual work bottleneck')
assert(M.contactMultiplier('Charger','Geode',8,0,3)*M.efficiency('Red','Geode')>M.contactMultiplier('Striker','Geode',8,0,3)*3,'hard-shell specialization is cosmetic')
print('PASS work difficulty and upgrade leverage. No retention, enjoyment or full-loop pacing claim.')
