-- Executes production server functions and rendering helpers with Roblox API doubles.
-- No Roblox engine, networking, visual quality or fun is asserted.
local impactChecks=0
RoleEffects.Ability=function() end;RoleEffects.ClearAbility=function() end;RoleEffects.BreakerPhase=function() end
discoveries.TrySpawn=function() end
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));impactChecks+=1;print('PASS mining impact '..name) end
local uid=112000
local function fixture(fieldId)
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=profiles[uid];local field=patches[fieldId or 1]
 pl.Character:PivotTo(CFrame.new(field.center+Vector3.new(0,3,0)))
 return pl,p,p.drones[1],field
end
local function node(d,field,hp,stages)
 local r=makeResource(field,field.center,'Crystal',hp or 100,10,3,stages);r.readyAt=now
 release(d);d.pos=Feel.mineGoal(r.position,1,r.limit>1,r.fullSize);d.target=r;d.targetSlot=1;d.field=field.id;r.slots[d.id]=1
 return r
end
check('full bag accepts manual orders and continues actual miner damage',function()
 local pl,p,d,f=fixture();data(p).run.cargo={Quartz=Ca.capacity(data(p))};local r=node(d,f,500)
 release(d);p.tokens=7;p.bucketAt=now;command.OnServerEvent:Fire(pl,'MineOre',r.id)
 assert(d.target==r,'full bag rejected explicit mining order')
 d.pos=Feel.mineGoal(r.position,d.targetSlot,false,r.fullSize);d.velocity=Vector3.zero
 for _=1,math.ceil((d.stats.warmup+1)/C.Tick) do realTime+=C.Tick;now=realTime;mineDrone(d,p,f,C.Tick) end
 assert(r.hp<490 and d.mining,'mining stopped when backpack was full')
 assert(hitResource(d,r,10000));assert(pendingOre(p)==10 and Pro.cargoUnits(data(p))==40)
end)
check('ground rewards stay bounded and conserve ore after many full-bag breaks',function()
 local _,p,d,f=fixture();data(p).run.cargo={Quartz=40}
 for _=1,100 do local r=node(d,f,100);assert(hitResource(d,r,1000)) end
 local units,nodes=pendingOre(p);assert(units==1000 and nodes<=OreDrops.MAX_NODES)
 local parts=0;for _,drop in pairs(pickups) do if drop.owner==d.owner then parts+=1 end end;assert(parts<=64)
 data(p).run.cargo={Quartz=39}
 for _=1,150 do realTime+=C.Tick;now=realTime;pickupStep(C.Tick) end
 assert(Pro.cargoUnits(data(p))==40 and pendingOre(p)==999,'partial collection lost ore or exceeded capacity')
end)
check('test field is always open beside Quartz and all rock work is exactly tenfold',function()
 local _,p,d,f=fixture(6);assert(f.cfg.AlwaysUnlocked and playerCanMine(p,f))
 assert(f.part.Position.X>patches[1].part.Position.X and math.abs(f.part.Position.Z-patches[1].part.Position.Z)<.01)
 assert(f.part:GetAttribute('Mineral')=='Quartz' and f.model:GetAttribute('AlwaysUnlocked'))
 for _,kind in ipairs({'Crystal','Geode','Core','Shard'}) do
  local base=makeResource(patches[1],patches[1].center,kind,250,10,3)
  local test=makeResource(f,f.center,kind,250,10,3)
  assert(test.hp==base.hp*10 and (test.fullSize-base.fullSize).Magnitude<1e-9 and test.ore==base.ore)
 end
 local r=node(d,f,100,7);assert(hitResource(d,r,100));assert(r.hp==800)
end)
check('cubic boulders offer three work slots and seven monotonic size changes',function()
 local _,p,d,f=fixture();local boulder
 for _,r in ipairs(f.resources) do if r.stageCount==7 then boulder=r;break end end
 assert(boulder and boulder.fullSize.X>=5.2 and boulder.ore==f.cfg.Ore*3 and boulder.limit==3)
 local r=node(d,f,810,7);local size=r.part.Size.X
 for stage=1,7 do
  local nextActual=r.maxHP*(1-stage/8)-.01;local amount=r.hp+10-nextActual
  assert(hitResource(d,r,amount));assert(r.stage==stage and r.part.Size.X<size);size=r.part.Size.X
 end
 assert(r.part:GetAttribute('StageCount')==7 and r.stage==7)
end)
check('ordinary and large layers darken toward black and fracture without duplicate cues',function()
 for _,count in ipairs({3,7}) do
  assert(Feel.stageDarkness(100,100,0,count)==0)
  local almost=100*(1-.9/(count+1));assert(Feel.stageDarkness(almost,100,0,count)>0)
  assert(Feel.stageDarkness(100/(count+1),100,count,count)==1)
  local visual=Feel.newStagePresentation(0,false,0,count);local scorch,crack,broken=0,0,0
  for n=0,150 do
   local event=Feel.updateStagePresentation(visual,count,true,n*.02,count)
   if event=='scorch' then scorch+=1;assert(visual.scorched)
   elseif event=='stage' then crack+=1;assert(not visual.scorched)
   elseif event=='break' then broken+=1 end
  end
  assert(scorch==0 and crack==0 and broken==1,'a final break replayed fake intermediate mining stages')
  local late=Feel.newStagePresentation(count,false,0,count);assert(late.stage==count)
 end
end)
check('physical scar history belongs only to accepted server contacts',function()
 local _,p,d,f=fixture();local r=node(d,f,810,7)
 d.role='Charger'
 local before=r.hp
 assert(not hitResource(d,r,-1,false,nil,d.pos,'Breaker'))
 assert(r.part:GetAttribute('SmashDents')==nil and r.hp==before)
 for n=1,3 do
  assert(hitResource(d,r,12,false,nil,d.pos,'Breaker'))
  assert(r.part:GetAttribute('SmashDents')==n and r.part:GetAttribute('DamageAt')==now)
 end
 assert(r.part:GetAttribute('DamageDepth')>0 and r.part:GetAttribute('DamageDepth')<1)
 d.role='Bubbler'
 d.specialJob={targetId=r.id,startedAt=now-10,duration=1,impact=.5,damage=20,serial=1}
 assert(hitResource(d,r,99999,false,nil,nil,'Special'))
 assert(r.part:GetAttribute('BubbleBites')==1)
 assert(not hitResource(d,r,99999,false,nil,nil,'Special'))
 assert(r.part:GetAttribute('BubbleBites')==1,'replayed special made a phantom cavity')
end)
check('runtime cubes preserve the original native crystal template untouched',function()
 local _,_,d,f=fixture()
 local replicated=RS:FindFirstChild('Crystal');local saved=scene.crystalTemplate
 local native=replicated:Clone();native.Name='PhysicalOriginal';native.Parent=workspace
 scene.crystalTemplate=native;replicated.Parent=nil
 local r=node(d,f,100)
 assert(r.part.ClassName=='Part' and r.part:GetAttribute('CubicRock')==true)
 assert(native.ClassName==replicated.ClassName and native.Parent==workspace and scene.crystalTemplate==native,'native reference asset was changed')
 replicated.Parent=RS;scene.crystalTemplate=saved;native:Destroy()
end)
check('powered dive accelerates downwards at every render rate and stops at contact',function()
 local start,impact=Vector3.new(1,12,3),Vector3.new(1,2,3)
 for _,rate in ipairs({30,60,144}) do
  local previous=0
  for n=1,math.floor(.28*rate) do
   local pos,velocity=Feel.powerDive(start,impact,n/rate,.28)
   assert(pos.Y>=impact.Y and pos.Y<=start.Y and -velocity.Y>=previous);previous=-velocity.Y
  end
  local pos=Feel.powerDive(start,impact,1,.28);assert((pos-impact).Magnitude<1e-9)
 end
end)
print(impactChecks..' actual mining impact server/helper checks passed with API doubles; not native acceptance')
