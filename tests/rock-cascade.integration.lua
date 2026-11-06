-- Real server functions with API doubles; separate from native play evidence.
local checks=0
local function check(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));checks+=1;print('PASS cascade '..name) end
local uid=192000
RoleEffects.Ability=function()end;RoleEffects.ClearAbility=function()end;discoveries.TrySpawn=function()end
local function fixture()
 for id,s in pairs(fracture.shots) do s.part:Destroy();fracture.shots[id]=nil end
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=profiles[uid];local f=patches[1]
 for _,r in ipairs(f.resources) do r.hp=0;r.paid=true end
 pl.Character:PivotTo(CFrame.new(f.center+Vector3.new(0,3,0)))
 return pl,p,p.drones[1],f
end
local function node(f,x,z,hp)
 local r=makeResource(f,f.center+Vector3.new(x,0,z or 0),'Crystal',hp or 300,10,3);r.readyAt=now;return r
end
local function strike(d,r,amount,kind)
 release(d);d.target=r;d.targetSlot=1;d.field=r.field.id;r.slots[d.id]=1
 d.pos=Feel.mineGoal(r.position,1,false,r.fullSize)
 return hitResource(d,r,amount,false,nil,kind and d.pos or nil,kind)
end
local function step(seconds)
 for _=1,math.ceil(seconds/.025) do realTime+=.025;now=realTime;fracture:step() end
end
local function countShots()local n=0;for _ in pairs(fracture.shots)do n+=1 end;return n end
check('collapse launches a traveling chunk that chips an intact neighbor only on contact',function()
 local _,p,d,f=fixture();local a,b=node(f,0),node(f,9)
 assert(strike(d,a,1000));assert(countShots()==1 and b.hp==290)
 step(.05);assert(b.hp==290,'damage arrived before the flying chunk')
 step(1);assert(math.abs(b.hp-203)<1e-6 and not b.paid and b.stage==1)
 local hp=b.hp;step(2);assert(b.hp==hp and countShots()==0,'contact paid twice')
 assert(pendingOre(p)==11,'base collapse and neighbor extraction were not conserved')
end)
check('prepared rocks create a visible multi-hop collapse while separated rocks survive',function()
 local _,p,d,f=fixture();local a,b,c,isolated=node(f,0),node(f,12),node(f,24),node(f,50)
 assert(strike(d,b,230));assert(strike(d,c,230));assert(b.part:GetAttribute('Brittle') and c.part:GetAttribute('Brittle'))
 assert(strike(d,a,1000));step(.15);assert(not b.paid and not c.paid)
 step(.4);assert(b.paid and not c.paid,'second wave did not wait for travel')
 step(1);assert(c.paid and isolated.hp==290)
 assert(pendingOre(p)==30,'chain duplicated or discarded a rock reward')
end)
check('hard boulders resist small fragments and heavy breaks launch three instead of two',function()
 local _,_,d,f=fixture();local a=node(f,0);local b=node(f,9,0,3000);node(f,-9);node(f,0,9)
 d.role='Charger';assert(strike(d,a,1000,'Breaker'));assert(countShots()==3)
 step(1);assert(math.abs(b.hp-(2990-87))<1e-6 and not b.paid)
end)
check('branching chains have a shared hit budget and never revisit their own rocks',function()
 local _,p,d,f=fixture();local a=node(f,0);local targets={}
 for x=-2,2 do for z=-2,2 do if x~=0 or z~=0 then local r=node(f,x*7,z*7);assert(strike(d,r,230));table.insert(targets,r) end end end
 assert(strike(d,a,1000));local peak=0
 for _=1,160 do peak=math.max(peak,countShots());step(.025) end
 local broken=0;for _,r in ipairs(targets)do if r.paid then broken+=1 end end
 assert(broken>1 and broken<=RockCascade.MAX_HITS and peak<=RockCascade.MAX_OWNER_SHOTS)
 assert(pendingOre(p)==10+#targets*5+broken*5,'shared chain ledger duplicated base ore')
end)
check('foreign reservations at launch or contact protect another players work',function()
 local _,_,d,f=fixture();local a,b=node(f,0),node(f,9)
 uid+=1;local foreign=player(uid);players.PlayerAdded:Fire(foreign);local other=profiles[uid].drones[1]
 b.slots[other.id]=1;assert(strike(d,a,1000));assert(countShots()==0 and b.hp==290)
 b.slots[other.id]=nil;a=node(f,0);assert(strike(d,a,1000));assert(countShots()==1)
 b.slots[other.id]=1;step(1);assert(b.hp==290 and not b.paid)
end)
check('intervening geometry stops chunks and save uncertainty cancels unapplied contacts',function()
 local _,p,d,f=fixture();local a,b=node(f,0),node(f,9);assert(strike(d,a,1000))
 local ray=workspace.Raycast;local wall=Instance.new('Part');wall.Parent=workspace
 workspace.Raycast=function(_,from,delta)return {Instance=wall,Position=from+delta*.5}end
 step(.2);workspace.Raycast=ray;assert(b.hp==290 and countShots()==0)
 a=node(f,0);assert(strike(d,a,1000));p.busy=true;step(.2);p.busy=false;step(1)
 assert(b.hp==290 and countShots()==0)
end)
check('chain damage cannot compound discovery speed and consumable work cannot farm tools',function()
 local _,_,d,f=fixture();local a,b=node(f,0),node(f,9)
 local multiplier=discoveries.Multiplier;discoveries.Multiplier=function(_,_,kind)return kind=='Speed' and 20 or 1 end
 assert(strike(d,a,1000));step(1);assert(math.abs(b.hp-203)<1e-6)
 discoveries.Multiplier=multiplier
 local spawned=0;discoveries.TrySpawn=function()spawned+=1 end
 a=node(f,0);assert(strike(d,b,150));assert(b.hp<87 and not b.paid)
 assert(strike(d,a,1000,'Consumable'));step(1)
 assert(b.paid and b.consumableWorked and spawned==0,'tool-generated cascade manufactured another tool')
 discoveries.TrySpawn=function()end
end)
check('outbound ore clears small and large rocks before the magnet can turn it around',function()
 for _,size in ipairs({1,3,10}) do for index=1,4 do
  local x,y,z,vx,vy,vz=OreDrops.launch(index,index+31,size,size,size)
  local radius=math.sqrt(x*x+z*z);assert(radius>size/math.sqrt(2) and y>size*.5)
  local s={x=x,y=y,z=z,vx=vx,vy=vy,vz=vz,age=0,floor=.22};local top=y
  for _=1,16 do
   local reached=OreDrops.step(s,{x=0,y=2,z=0},.05,true)
   assert(not reached and not s.homing,'magnet swallowed the outbound arc')
   assert(math.sqrt(s.x*s.x+s.z*s.z)>=radius)
   top=math.max(top,s.y)
  end
  assert(top>y+2.5 and math.sqrt(s.x*s.x+s.z*s.z)>radius+5)
 end end
end)
print(checks..' cascade/extraction logic checks; not native visual, audio or multiplayer evidence')
