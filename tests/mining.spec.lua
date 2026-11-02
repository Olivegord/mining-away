local M=require('../src/Mining')
local C=require('../src/Config')
local passed=0
local function test(name,fn) fn();passed+=1;print('PASS mining '..name) end
local function close(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
test('field hardness changes effective work while preserving authored footprint',function()
 local expected={1,1.8,3.2,5.2,8}
 for index,field in ipairs(C.Fields) do
  close(field.Hardness,expected[index])
  for _,roll in ipairs({50,75,100}) do
   for _,kind in ipairs({'Crystal','Geode','Core','Shard'}) do
    local original=M.resource(roll,kind,1);local hard=M.resource(roll,kind,field.Hardness)
    close(hard.work,original.work*field.Hardness);close(hard.maxHP,hard.work+10);close(hard.size,original.size)
   end
  end
 end
 close(M.duration('Blue','Crystal',65,30),65/30)
 close(M.duration('Blue','Crystal',65*8,30),65*8/30)
end)
test('harder fields increase mineral value per equivalent mining work',function()
 local previous=0
 for _,field in ipairs(C.Fields) do
  local creditsPerBaseWork=field.Ore*field.Value/field.Hardness
  assert(creditsPerBaseWork>previous,field.Key..' reduced raw mining returns despite harder work')
  previous=creditsPerBaseWork
 end
end)
test('percussion only pays charged active intervals at all supported rates',function()
 for _,fps in ipairs({30,60,120,144}) do
  local total,charge,pulses=0,0,0
  for _=1,8*fps do local damage,left,count=M.step('Red',charge,1/fps,30);total+=damage;charge=left;pulses+=count end
  close(total,240);close(charge,0);assert(pulses==10)
 end
 local damage,charge=M.step('Red',0,.79,30);close(damage,0)
 damage,charge=M.step('Red',charge,.01,30);close(damage,24);close(charge,0)
 local paused,left=M.step('Red',.4,0,30);close(paused,0);close(left,.4)
 close(M.duration('Red','Crystal',25,30),1.6)
 close(M.duration('Red','Core',25,30),.8)
 close(M.efficiency('Red','Shard'),1);close(M.efficiency('Red','Geode'),1.5)
end)
test('cutter and resonance retain continuous base output; fracture echoes have finite bounds',function()
 for _,kind in ipairs({'Blue','Green'}) do
  local damage,charge,pulses=M.step(kind,.7,.1,30);close(damage,3);close(charge,0);assert(pulses==0)
 end
 close(M.resonanceDamage(100,30,1),8.75)
 close(M.resonanceDamage(10000,30,1),24)
 close(M.resonanceDamage(10000,30,100),72)
 close(M.resonanceDamage(100,30,0),0)
end)
test('autonomous priorities value real work and a payable core instead of a free shell reward',function()
 local stats={maxStep60=.3,warmup=.8,miningDPS=30,geodeMultiplier=1}
 local crystal={kind='Crystal',hp=65,ore=12,hardness=1,stage=0}
 local shell={kind='Geode',hp=215,ore=12,hardness=1,stage=0}
 assert(M.targetScore('Blue',stats,crystal,8,0)<M.targetScore('Blue',stats,shell,8,0))
 assert(M.targetScore('Red',stats,shell,8,0)<M.targetScore('Red',stats,crystal,8,0))
 assert(M.targetScore('Green',stats,crystal,8,3)<M.targetScore('Green',stats,crystal,8,0))
 crystal.stage=2
 assert(M.style('Blue')=='Cutter' and M.style('Red')=='Percussion' and M.style('Green')=='Resonance')
 assert(string.find(M.description('Red'),'50%%'))
end)
test('all mineral work is three times the former health without inflating meshes',function()
 for _,kind in ipairs({'Crystal','Core','Shard','Geode'}) do
  local n=M.resource(75,kind,1)
  local mass=kind=='Geode' and 225 or 75
  close(n.work,(mass-10)*3);assert(n.size<=6)
 end
end)
print(passed..' mining rules checks passed; not Studio results')
