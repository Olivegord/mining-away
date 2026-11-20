-- Real catalog and sale functions: changing appearances must preserve saved ore.
local W=require('../src/Workshop')
local S=require('../src/Shops')
local P=require('../src/Profile')
local expected={'Amber','Ruby','Quartz','Violet','Diamond'}
for i,tier in ipairs(W.CRYSTAL_TIERS) do
 assert(tier.name==expected[i])
 assert(tier.hardness==3^(i-1) and tier.value==4^(i-1))
 for _,pressed in ipairs({false,true}) do
  local key=W.cargoKey(tier.material,43,pressed)
  local material,value,block=W.crystalCargo(key)
  assert(material==tier.material and value==43 and block==pressed)
  assert(S.quartzValue(key)==43)
 end
end
local profile=P.new(71001,123)
for material,value in pairs({Quartz=1,RunRuby=4,RunCobalt=16,RunViolet=64,RunEmerald=256}) do
 assert(S.quartzValue(material)==value)
 local key=W.cargoKey(material,97,false)
 assert(S.quartzValue(key)==97)
 profile.run.cargo[key]=1
end
for _,tier in ipairs(W.CRYSTAL_TIERS) do profile.run.cargo[W.cargoKey(tier.material,7,false)]=1 end
assert(P.validate(profile,profile.userId))
local restored,err=P.migrate(P.clone(profile),profile.userId);assert(restored,err)
for key,count in pairs(profile.run.cargo) do assert(restored.run.cargo[key]==count) end
print('PASS five mineral tiers, hardness/value curve, old/new raw and pressed cargo, profile save/load preservation')
