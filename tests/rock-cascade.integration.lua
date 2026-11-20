-- Authoritative crystal stages and reward-only drops using Roblox API doubles.
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS crystal '..name) end
discoveries.TrySpawn=function()end
local pl=player(192001);players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId];local f=patches[1];local d=p.drones[1]
pl.Character:PivotTo(CFrame.new(f.center+Vector3.new(0,3,0)))
local template=Instance.new('UnionOperation');template.Size=Vector3.new(3.135,6.5669,4.4872);scene.classicCrystal=template
local function node(x)
 local r=makeResource(f,f.center+Vector3.new(x,0,0),'Crystal',100,10,3)
 r.readyAt=now
 return r
end
check('three stage turns preserve grounded geometry; only claimable fragments leave the rock',function()
 local a,b=node(0),node(9)
 assert(assignOre(p,d,a));d.pos=committedStation(d,a)
 local direction=a.part.CFrame.LookVector
 for stage=1,3 do
  assert(hitResource(d,a,25))
  assert(a.stage==stage and (a.part.CFrame.LookVector-direction).Magnitude>.5)
  direction=a.part.CFrame.LookVector
  assert(math.abs(a.part.CFrame.Position.Y-a.part.Size.Y*.5-(a.part:GetAttribute('GroundY')-.06))<1e-5)
 end
 assert(hitResource(d,a,1000) and a.paid)
 assert(b.hp==90 and not root:FindFirstChild('RockFragments'),'break created an uncollectible projectile')
 assert(pendingOre(p)==10)
 local total=0
 for _,drop in ipairs(pickupFolder:GetChildren()) do
  local units=drop:GetAttribute('Units')
  assert(drop.Name=='OreFragment' and drop:GetAttribute('PickupId') and drop:GetAttribute('Owner')==pl.UserId)
  assert(units>0 and drop:GetAttribute('Mineral')=='Quartz' and drop.Material==Enum.Material.Ice)
  total+=units
 end
 assert(total==10)
end)
check('outbound ore clears small and large rocks before the magnet can turn it around',function()
 for _,size in ipairs({1,3,10}) do for index=1,4 do
  local x,y,z,vx,vy,vz=OreDrops.launch(index,index+31,size,size,size)
  local radius=math.sqrt(x*x+z*z);assert(radius>size/math.sqrt(2) and y>size*.5)
  local s={x=x,y=y,z=z,vx=vx,vy=vy,vz=vz,age=0,floor=.22};local top=y
  for _=1,math.floor((OreDrops.SCATTER_TIME-.001)/.05) do
   local reached=OreDrops.step(s,{x=0,y=2,z=0},.05,true)
   assert(not reached and not s.homing,'magnet swallowed the outbound arc')
   assert(math.sqrt(s.x*s.x+s.z*s.z)>=radius)
   top=math.max(top,s.y)
  end
  assert(top>y and math.sqrt(s.x*s.x+s.z*s.z)>radius)
 end end
end)
print(checks..' crystal/extraction logic checks; not native visual, audio or multiplayer evidence')
