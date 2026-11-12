local W=require('../src/Workshop')
local P=require('../src/Profile')
local C=require('../src/Cards')
local Catalog=require('../src/DroneCatalog')
local O=require('../src/OreDrops')
local F=require('../src/Feel')
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS overhaul '..name) end
check('earned milestones expose a nearer first reward and grow through deep fields',function()
 local p=P.new(1,99)
 for index,goal in ipairs({160,400,1000}) do
  p.prestiges=index-1
  assert(P.milestone(p).earnings==goal)
 end
 for completed=0,40 do p.prestiges=completed;assert(P.milestone(p).earnings<=math.floor(360*(1+completed)^1.35)) end
 assert(W.permanentMiningBonus(0)==0 and W.permanentMiningBonus(1)==.5 and W.permanentMiningBonus(2)==1
  and W.permanentMiningBonus(3)==1.5 and W.permanentMiningBonus(4)==1.75)
end)
check('prestige choices are visible early, stable, novel when possible, and never grant early',function()
 for seed=1,120 do
  local p=P.new(seed,seed)
  local preview=P.prestigePreview(p)
  assert(not preview.eligible and #preview.droneChoices==3 and preview.miningBonusAfter==.5)
  local again=P.prestigePreview(assert(P.migrate(P.clone(p),seed)))
  local seen={}
  for i,choice in ipairs(preview.droneChoices) do
   assert(choice.kind~='Blue' and not seen[choice.kind]);seen[choice.kind]=true
   assert(again.droneChoices[i].kind==choice.kind)
  end
  local before=#p.fleet
  assert(not P.prestige(p,'too-early',p.run.id,{atDepot=true,confirmed=true,droneType=preview.droneChoices[1].kind}))
  assert(#p.fleet==before)
 end
 local owned={};for _,entry in ipairs(Catalog.PrestigeRewards) do owned[entry.kind]=true end
 local choices=Catalog.prestigeChoices(1,10,owned);assert(#choices==3)
end)
check('spending preserves prestige, reward is once, and run two starts visibly stronger',function()
 local p=P.new(11,13);local first=p.fleet[1];local base=C.stats(p,first).miningDPS
 p.run.cargo={Quartz=160};assert(P.sell(p,{Quartz=1},'earned',p.run.id))
 assert(C.buy(p,'pack',p.run.id,{atDepot=true,expectedPackIndex=0,crystalRun=true}))
 local offer=p.run.pendingOffer;assert(P.prestigePreview(p).earnings==160 and not P.prestigePreview(p).eligible)
 assert(C.open(p,offer.id));assert(C.select(p,offer.id,2,'pick',p.run.id,{atDepot=true}))
 local preview=P.prestigePreview(p);assert(preview.eligible)
 local oldRun=p.run.id;local id=first.id;local kind=preview.droneChoices[1].kind;local count=#p.fleet
 assert(P.prestige(p,'prestige',oldRun,{atDepot=true,confirmed=true,droneType=kind}))
 assert(#p.fleet==count+1 and p.fleet[1].id==id and C.stats(p,p.fleet[1]).miningDPS==base*1.5)
 assert(p.run.wallet.Quartz==0 and #p.run.cards==0 and p.run.stars==0 and p.run.packIndex==0)
 assert(P.prestige(p,'prestige',oldRun,{atDepot=true,confirmed=true,droneType=kind}));assert(#p.fleet==count+1)
 assert(P.validate(p,p.userId))
end)
check('pickup reach keeps a visible landed approach and preserves upgrade value',function()
 assert(O.CARGO_REACH==9)
 local function drop() return {x=8,y=0,z=0,vx=0,vy=0,vz=0,floor=0,age=1,raw=true,landed=true,firstLandedAge=.5} end
 local s=drop();local collected=false
 for _=1,60 do if O.step(s,{x=0,y=0,z=0},1/60,true,O.CARGO_REACH) then collected=true;break end end
 assert(collected,'nearby cargo remained stranded')
 s=drop();s.x=10;O.step(s,{x=0,y=0,z=0},1/60,true,O.CARGO_REACH);assert(not s.homing)
 O.step(s,{x=0,y=0,z=0},1/60,true,O.CARGO_REACH+12*W.ORE_REACH_SCALE);assert(s.homing)
 s=drop();s.landed=false;s.age=.1;s.y=2;s.vy=10
 O.step(s,{x=0,y=0,z=0},1/60,true,O.CARGO_REACH);assert(not s.homing,'pickup skipped its visible landing')
end)
check('body fade clears the avatar without fading the rest of the fleet',function()
 local function v(x,y,z) return {X=x,Y=y,Z=z} end
 assert(F.cameraObstruction(v(0,0,20),v(0,0,0),v(0,0,10),2)==.86)
 assert(F.cameraObstruction(v(0,0,20),v(0,0,0),v(5,0,10),2)==0)
 assert(F.cameraObstruction(v(0,0,20),v(0,0,0),v(0,0,-3),2)==0)
 assert(F.cameraObstruction(v(0,0,20),v(0,0,0),v(0,0,25),2)==0)
 assert(F.cameraObstruction(v(0,0,0),v(0,0,0),v(0,0,0),2)==0)
end)
check('flight keeps the original capped 60Hz approach after the view-only change',function()
 for _,cap in ipairs({.2,.35,.5}) do
  local actual,original=0,0
  for _=1,360 do
   actual=F.approachScalar(actual,60,cap,1/60)
   original+=math.min((60-original)*.03,cap)
   assert(math.abs(actual-original)<1e-10)
  end
 end
end)
print(checks..' focused progression overhaul checks passed; no native-play claims')
