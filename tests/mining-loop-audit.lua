-- Production equations, with explicitly bounded assumptions. These numbers
-- exclude flight, warmup, recharge, target choice, selling and manual opening.
local W=require('../src/Workshop')
local M=require('../src/Mining')
local P=require('../src/Profile')
local Cards=require('../src/Cards')
local p=P.new(889901,120)
local base=0
for _,d in ipairs(p.fleet) do base+=Cards.stats(p,d).miningDPS end
local double=W.card(W.BY_ID.Q_DOUBLE_BEAM,2,0)
double.targetDroneId=p.fleet[1].id
local doublePower=0
for _,d in ipairs(p.fleet) do doublePower+=Cards.stats(p,d,double).miningDPS end
local power=W.card(W.BY_ID.Q_POWER,1,0)
local powerTotal=0
for _,d in ipairs(p.fleet) do powerTotal+=Cards.stats(p,d,power).miningDPS end
assert(#p.fleet==3 and base==90 and doublePower==120 and powerTotal==135)
print('# Current Crystal Run work/reward audit')
print('Three basic miners; unmodified cargo; roll 75. Work-only bounds, not elapsed gameplay.')
print('The listed cut time is work / rated DPS, before exposed-layer bonuses.')
print('The geode requirement is the initial four-second check; layer bonuses can help actual contacts.')
print('| Field | Work | Single miner seconds | Focused three seconds | Stone cash | Gem cash | Geode cash (6 gems) | Geode required DPS |')
print('|---|---:|---:|---:|---:|---:|---:|---:|')
for _,tier in ipairs(W.CRYSTAL_TIERS) do
 local r=M.fieldCrystal(75,tier.hardness,10,tier.cracks)
 local g=M.geode(75,tier.hardness,10)
 local stone=math.floor(r.ore*tier.value*.3)
 local gem=math.floor(r.ore*tier.value*8)
 -- Round-trip through the actual cargo pricing format, including zero modifiers.
 local stoneKey=W.saleCargo(tier.material,stone,true,r.ore*W.PITY_PERCENT,r.ore*100,0,'Original')
 local gemKey=W.saleCargo(tier.material,gem,false,r.ore*100,0,0,'Original')
 assert(W.saleItem(stoneKey).cash==stone and W.saleItem(gemKey).cash==gem)
 print(string.format('| %s | %.0f | %.2f | %.2f | %d | %d | %d | %.1f |',
  tier.name,r.work,r.work/30,r.work/base,stone,gem,gem*6,g.work*.1))
end
print('\n## First purchase and variance')
print(string.format('First pack: %d cash. First prestige: %d cumulative sold cash.',W.price(p),W.prestigeGoal(0)))
print(string.format('Three basic miners: %.0f rated DPS. One Double Beam: %.0f. One Power Cell: %.0f.',base,doublePower,powerTotal))
print(string.format('Ordinary-roll gem chance: %.0f%%. Ten independent ordinary rocks with no gem: %.1f%%.',W.CRYSTAL_CHANCE*100,(1-W.CRYSTAL_CHANCE)^10*100))
local amber=M.fieldCrystal(75,1,10,3)
local stone=math.floor(amber.ore*.3)
local gem=math.floor(amber.ore*8)
local expected=stone*(1-W.CRYSTAL_CHANCE)+gem*W.CRYSTAL_CHANCE
print(string.format('Median Amber: %d plain stones fund the first pack; %d fund first prestige without gems.',math.ceil(W.price(p)/stone),math.ceil(W.prestigeGoal(0)/stone)))
print(string.format('Gems contribute %.1f%% of expected ordinary-rock cash at this fixed size. Expected cash is not a guaranteed payout.',gem*W.CRYSTAL_CHANCE/expected*100))
print('Excluded: starter gift cargo, modifiers, guns, utility drones, tool drops, card echoes, flight, warmup, batteries, player routing, pack UI and selling.')
print('Use real Play observations for elapsed progression, clarity, reward satisfaction and enjoyment.')
