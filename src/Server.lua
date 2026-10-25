-- Bundler supplies Config, Rules, World as lexical modules. All gameplay runs here.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local C,R,W=Config,Rules,World
if workspace:FindFirstChild('MiningAwayV2') then error('MiningAwayV2 already running') end
local root=Instance.new('Folder');root.Name='MiningAwayV2';root.Parent=workspace
root:SetAttribute('Build','cloud-1.0');root:SetAttribute('Tick',C.Tick)
local net=Instance.new('Folder');net.Name='MiningAwayV2';net.Parent=RS
local command=Instance.new('RemoteEvent');command.Name='Command';command.Parent=net
local profiles,cache,drones,patches={},{},{},{}
local clock=0
local oldSpawn=workspace:FindFirstChildWhichIsA('SpawnLocation',true)
local origin=(oldSpawn and oldSpawn.Position or Vector3.zero)+Vector3.new(0,85,0)
local home=W.part(root,'Home',origin,Vector3.new(64,2,64),Color3.fromRGB(32,43,58));home.CanCollide=true;home.CanQuery=true
local spawn=Instance.new('SpawnLocation');spawn.Name='CloudSpawn';spawn.Anchored=true;spawn.Size=Vector3.new(8,1,8);spawn.Position=origin+Vector3.new(0,2,0);spawn.Neutral=true;spawn.Parent=root
local printer=W.part(root,'FreePrinter',origin+Vector3.new(15,2,0),Vector3.new(8,2,8),Color3.fromRGB(70,220,200),Enum.Material.Neon)
W.label(printer,'FREE REPRINT\n10s recovery + 2s assembly',Vector3.new(0,5,0))
W.label(home,'MINING AWAY\nMine Ruby → sell at home → upgrade power & hull',Vector3.new(0,8,0))
local template=RS:FindFirstChild('Drone')
local crystalTemplate=RS:FindFirstChild('Crystal')
local ambience=Instance.new('Sound');ambience.Name='HistoricalAmbience';ambience.SoundId='rbxassetid://1835928951';ambience.Volume=.06;ambience.Looped=true;ambience.Parent=game:GetService('SoundService');ambience:Play()
local crystalMesh=crystalTemplate and crystalTemplate:FindFirstChild('Mesh',true)
local function attr(d)
 d.model:SetAttribute('Pose',d.model:GetPivot());d.model:SetAttribute('Owner',d.owner);d.model:SetAttribute('DroneId',d.id);d.model:SetAttribute('State',d.state)
 d.model:SetAttribute('HP',d.hp);d.model:SetAttribute('MaxHP',d.maxHP);d.model:SetAttribute('Life',d.life)
 d.model:SetAttribute('ReprintAt',d.hp<=0 and workspace:GetServerTimeNow()+math.max(0,d.readyAt-clock) or 0)
 d.label.Text=string.format('%s • %s\n%d / %d',d.name,d.state,math.ceil(d.hp),d.maxHP)
end
local function updateProfile(p)
 local pl=p.player;if not pl or not pl.Parent then return end
 for k,v in pairs({Credits=p.credits,Ore=p.ore,Capacity=C.Capacity,Power=p.power,Hull=p.hull,Objective=p.objective or 'Mine Ruby, return and sell. Upgrade both systems before Cobalt.'}) do pl:SetAttribute('MA_'..k,v) end
end
local function inHome(p)
 local ch=p.player.Character;local hr=ch and ch:FindFirstChild('HumanoidRootPart')
 return hr and (hr.Position-origin).Magnitude<38
end
local function alivePlayer(p)
 local ch=p.player.Character;local h=ch and ch:FindFirstChildOfClass('Humanoid')
 return h and h.Health>0
end
local function release(d)
 if d.target and d.target.slots then d.target.slots[d.id]=nil end
 d.target=nil;W.setBeam(d.beam,false)
end
local function markSpent(d)
 for _,p in ipairs(patches) do if p.e.roster[d.id] then R.spend(p.e,d.id) end end
end
local function recall(d)
 release(d);markSpent(d);d.patch=nil;if d.hp>0 then d.state='Return' end
end
local function position(d,pos,look)
 pos=pos+Vector3.new(0,math.sin(clock*2+d.slot)*.25,0)
 local delta=pos-d.pos
 local n=delta.Magnitude
 if n>0.001 then d.pos=d.pos+delta.Unit*math.min(n,C.Speed*C.Tick) end
 local aim=look or (d.pos+Vector3.new(0,0,-1))
 if (aim-d.pos).Magnitude<.01 then aim=d.pos+Vector3.new(0,0,-1) end
 local cf=CFrame.lookAt(d.pos,aim)
 d.model:PivotTo(d.model:GetPivot():Lerp(cf,.5))
 -- Endpoint is not an input to physics; server positions the visual emitter explicitly.
 d.eye.Position=d.pos
 return n<2
end
local function createDrone(p,i)
 local id=tostring(p.player.UserId)..':'..i
 local pos=origin+Vector3.new(i*3-6,6,8)
 local model,part,eye=W.drone(root,template,pos,Color3.fromRGB(90,230,255))
 model.Name='Drone_'..id
 local d={id=id,owner=p.player.UserId,name=p.player.DisplayName..' '..i,model=model,part=part,eye=eye,pos=pos,life=1,hp=C.Hull,maxHP=C.Hull,state='Follow',readyAt=0,slot=i,patch=nil,target=nil,shotAt=0}
 d.beam=W.beam(eye,Color3.fromRGB(70,235,255));d.label=W.label(part,'',Vector3.new(0,3,0));drones[id]=d;table.insert(p.drones,d);attr(d)
 return d
end
local function kill(d)
 if d.hp<=0 then return end
 release(d);markSpent(d);d.patch=nil;R.reprint(d,clock,C.Reprint+C.Assembly)
 d.model:SetAttribute('BreakSerial',(d.model:GetAttribute('BreakSerial') or 0)+1)
 attr(d)
end
local function clearResources(p)
 for _,r in ipairs(p.resources) do
  for id in pairs(r.slots) do local d=drones[id];if d then release(d) end end
  if r.part.Parent then r.part:Destroy() end
 end
 p.resources={}
end
local function resource(p,pos,hp,reward,geode,child)
 local part
 if not geode and crystalMesh and crystalMesh:IsA('BasePart') then
  part=crystalMesh:Clone()
  for _,v in ipairs(part:GetDescendants()) do if v:IsA('LuaSourceContainer') or v:IsA('BillboardGui') then v:Destroy() elseif v:IsA('ParticleEmitter') or v:IsA('Beam') then v.Enabled=false end end
  part.Anchored=true;part.CanCollide=false;part.Size=Vector3.new(2,child and 3 or 5,2);part.Position=pos;part.Color=p.color;part.Parent=p.model
 else
  part=W.part(p.model,geode and 'GeodeShell' or 'Crystal',pos,geode and Vector3.new(7,6,7) or Vector3.new(2,4,2),geode and Color3.fromRGB(83,78,95) or p.color,geode and Enum.Material.Slate or Enum.Material.Neon)
  part.Shape=geode and Enum.PartType.Ball or Enum.PartType.Block
 end
 part.CanQuery=true;part.CanTouch=false;part.Name=geode and 'GeodeShell' or 'Crystal';part:SetAttribute('Resource',true);part:SetAttribute('Patch',p.id)
 local r={part=part,hp=hp,maxHP=hp,reward=reward,geode=geode,paid=false,slots={},limit=geode and 3 or 1}
 if geode then r.label=W.label(part,'GEODE • 3 mining slots\nShell '..hp..' HP',Vector3.new(0,6,0)) elseif child and reward==p.cfg.Reward*4 then r.label=W.label(part,'EXPOSED CORE • '..reward..' ore',Vector3.new(0,4,0)) end
 part:SetAttribute('HP',hp);part:SetAttribute('MaxHP',hp);part:SetAttribute('Slots',r.limit);part:SetAttribute('Fracture',0)
 table.insert(p.resources,r);return r
end
local function seed(p)
 clearResources(p)
 for i=1,p.cfg.Count do
  local x=((i-1)%4)*9-14;local z=math.floor((i-1)/4)*10-12
  resource(p,p.center+Vector3.new(x,4,z),p.cfg.HP,p.cfg.Reward,false,false)
 end
 resource(p,p.center+Vector3.new(12,5,17),p.cfg.HP*4,0,true,false)
end
local function restoreTurrets(p)
 for _,t in ipairs(p.turrets) do
  t.hp=p.cfg.TurretHP;t.nextShot=clock+1;t.lock=nil;t.fireAt=nil;t.part.Transparency=0
  t.part:SetAttribute('HP',t.hp);t.part:SetAttribute('Telegraph',false);t.part:SetAttribute('Dead',false)
  W.setBeam(t.beam,false)
 end
end
for i,cfg in ipairs(C.Tiers) do
 local color=Color3.fromRGB(unpack(cfg.Color));local center=origin+Vector3.new((i-1)*105,0,-105)
 local model=Instance.new('Model');model.Name='Patch'..i;model.Parent=root
 local floor=W.part(model,'PatchFloor',center,Vector3.new(66,3+i,66),color:Lerp(Color3.new(0,0,0),.72),i==1 and Enum.Material.Grass or Enum.Material.Rock);floor.CanCollide=true;floor.CanQuery=true
 floor:SetAttribute('Patch',i)
 local path=W.part(root,'Bridge'..i, i==1 and origin+Vector3.new(0,-.5,-53) or center+Vector3.new(-53,0,0),i==1 and Vector3.new(16,2,42) or Vector3.new(42,2,16),Color3.fromRGB(55,64,78));path.CanCollide=true;path.CanQuery=true
 local p={id=i,cfg=cfg,color=color,center=center,model=model,floor=floor,resources={},turrets={},e=R.newEncounter(C),refreshAt=0}
 p.label=W.label(floor,'',Vector3.new(0,13,0));model:SetAttribute('Tier',i);model:SetAttribute('Reward',cfg.Reward)
 if i==1 then p.e.phase='Safe' end
 for n=1,cfg.Turrets do
  local at=center+Vector3.new((n-2)*18,7,-23)
  local part=W.part(model,'Turret'..n,at,Vector3.new(5,7,5),Color3.fromRGB(237,86,71),Enum.Material.Metal)
  part.CanQuery=true;part:SetAttribute('MaxHP',cfg.TurretHP);local t={part=part,hp=cfg.TurretHP,nextShot=0,lock=nil,fireAt=nil}
  t.label=W.label(part,'',Vector3.new(0,5,0));t.beam=W.beam(part,Color3.fromRGB(255,85,65));table.insert(p.turrets,t)
 end
 table.insert(patches,p);restoreTurrets(p);seed(p)
end
local function canMine(p) return p.e.phase=='Safe' or p.e.phase=='Cleared' end
local function grant(d,amount)
 local p=profiles[d.owner];if not p then return end
 p.ore=math.min(C.Capacity,p.ore+amount);updateProfile(p)
end
local function hitResource(d,p,r,amount)
 if not canMine(p) or d.hp<=0 or not r.slots[d.id] then return end
 if R.damage(r,amount) then
  r.part:SetAttribute('BreakSerial',1);r.part:SetAttribute('HP',0)
  local pos=r.part.Position
  for id in pairs(r.slots) do if drones[id] then release(drones[id]) end end
  r.part.Transparency=1
  if r.geode then
   resource(p,pos,p.cfg.HP*1.5,p.cfg.Reward*4,false,true)
   for i=1,4 do resource(p,pos+Vector3.new(math.cos(i*math.pi/2)*5,-1,math.sin(i*math.pi/2)*5),p.cfg.HP*.4,p.cfg.Reward,false,true) end
  else grant(d,r.reward) end
  -- Keep the break attribute briefly so replicated clients can render bounded cosmetics.
  r.removeAt=clock+2
 else
  r.part:SetAttribute('HP',r.hp);r.part:SetAttribute('Fracture',math.min(3,math.floor((1-r.hp/r.maxHP)*4)))
  if r.label and r.geode then r.label.Text=string.format('GEODE • 3 mining slots\nShell %d / %d',math.ceil(r.hp),r.maxHP) end
 end
end
local function chooseResource(d,p)
 local best,dist=nil,math.huge
 for _,r in ipairs(p.resources) do
  if not r.paid then
   local n=0;for _ in pairs(r.slots) do n=n+1 end
   local distance=(r.part.Position-d.pos).Magnitude
   if n<r.limit and distance<dist then best=r;dist=distance end
  end
 end
 if best then best.slots[d.id]=true;d.target=best end
end
local function los(from,to,target)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 -- Drone geometry is CanQuery=false; resource/turret geometry remains queryable.
 local result=workspace:Raycast(from,to-from,params)
 return result==nil or result.Instance==target
end
local function eligible(p,d)
 local owner=profiles[d.owner]
 return owner and alivePlayer(owner) and d.hp>0 and d.patch==p.id and (d.pos-p.center).Magnitude<65
end
local function countRoster(p)
 local alive=0;local contact=false
 for id,r in pairs(p.e.roster) do
  local d=drones[id]
  if d and d.life==r.life and not p.e.spent[id] and eligible(p,d) then alive=alive+1;contact=true end
 end
 return alive,contact
end
local function resetPatch(p)
 restoreTurrets(p);seed(p)
 for _,d in pairs(drones) do if d.patch==p.id then recall(d) end end
end
local function tickEncounter(p)
 if p.id==1 then return end
 -- A roster member leaving encounter radius or changing objective is permanently spent.
 if p.e.phase=='Active' then
  for id,r in pairs(p.e.roster) do local d=drones[id];if not d or d.life~=r.life or not eligible(p,d) then R.spend(p.e,id) end end
 end
 local n,contact=countRoster(p);local defeated=true
 for _,t in ipairs(p.turrets) do if t.hp>0 then defeated=false end end
 local event=R.step(p.e,clock,n,contact,defeated)
 if event=='reset' then resetPatch(p)
 elseif event=='clear' then
  -- One bonus per successful encounter per enrolled identity, never per turret kill.
  for uid in pairs(p.e.users) do local profile=profiles[uid];if profile then profile.credits=profile.credits+p.cfg.Reward*2;profile.objective='Defenses cleared for 120 seconds. Mine and return before refresh.';updateProfile(profile) end end
 elseif event=='guard' then restoreTurrets(p) end
end
local function tickTurrets(p)
 if p.e.phase~='Active' then
  for _,t in ipairs(p.turrets) do W.setBeam(t.beam,false);t.lock=nil;t.fireAt=nil;t.part:SetAttribute('Telegraph',false) end
  return
 end
 for _,t in ipairs(p.turrets) do
  W.setBeam(t.beam,false)
  if t.hp>0 then
   if t.fireAt then
    local d=t.lock
    if not d or not R.participates(p.e,d) or not eligible(p,d) or (d.pos-t.part.Position).Magnitude>48 or not los(t.part.Position+Vector3.new(0,4,0),d.pos,d.part) then
     t.lock=nil;t.fireAt=nil;t.nextShot=clock+1;t.part:SetAttribute('Telegraph',false)
    elseif clock>=t.fireAt then
     for i,b in ipairs(t.beam.beams) do b.Width0=i==1 and .1 or .4;b.Width1=i==1 and .12 or .6;b.Transparency=NumberSequence.new(i==1 and .05 or .6) end
     W.setBeam(t.beam,true,d.pos);d.hp=math.max(.000001,d.hp) -- kill() guards once, including exact zero.
     if d.hp<=p.cfg.Damage then kill(d) else d.hp=d.hp-p.cfg.Damage end
     t.lock=nil;t.fireAt=nil;t.nextShot=clock+1.1;t.part:SetAttribute('Telegraph',false)
    else
     for _,b in ipairs(t.beam.beams) do b.Width0=.025;b.Width1=.025;b.Transparency=NumberSequence.new(.6) end
     W.setBeam(t.beam,true,d.pos)
    end
   elseif clock>=t.nextShot then
    local best,dist=nil,48
    for _,d in pairs(drones) do
     local n=(d.pos-t.part.Position).Magnitude
     if R.participates(p.e,d) and eligible(p,d) and n<dist and los(t.part.Position+Vector3.new(0,4,0),d.pos,d.part) then best=d;dist=n end
    end
    if best then t.lock=best;t.fireAt=clock+.8;t.part:SetAttribute('Telegraph',true);t.part:SetAttribute('Aim',best.pos) end
   end
  end
  t.part:SetAttribute('HP',t.hp);t.label.Text=string.format('SENTRY • %d / %d\n%s',math.ceil(t.hp),p.cfg.TurretHP,t.fireAt and 'CHARGING 0.8s' or 'Defense')
 end
end
local function tickDrone(d)
 local profile=profiles[d.owner];if not profile then return end
 W.setBeam(d.beam,false)
 if d.hp<=0 then
  d.state=clock>=d.readyAt-C.Assembly and 'Reprinting' or 'Destroyed'
  -- Printer is the only location for a replacement. No target reservation survives.
  d.pos=origin+Vector3.new(15+(d.slot-2)*2,5,0);d.model:PivotTo(CFrame.new(d.pos))
  for _,v in ipairs(d.model:GetDescendants()) do if v:IsA('BasePart') and v.Name~='Endpoint' then v.Transparency=d.state=='Reprinting' and .5 or 1 end end
  if R.finishReprint(d,clock,d.maxHP) then
   for _,v in ipairs(d.model:GetDescendants()) do if v:IsA('BasePart') and v.Name~='Endpoint' then v.Transparency=0 end end
  end
  attr(d);return
 end
 if not alivePlayer(profile) then recall(d) end
 local p=d.patch and patches[d.patch]
 if p then
  if p.e.phase=='Gathering' then
   d.state='Travel';position(d,p.center+Vector3.new((d.slot-2)*4,10,8))
  elseif p.e.phase=='Active' and R.participates(p.e,d) then
   local target,dist=nil,math.huge
   for _,t in ipairs(p.turrets) do local n=(t.part.Position-d.pos).Magnitude;if t.hp>0 and n<dist then target=t;dist=n end end
   if target then
    d.state='Attack';local at=target.part.Position+Vector3.new((d.slot-2)*3,5,10)
    position(d,at,target.part.Position)
    if (d.pos-target.part.Position).Magnitude<C.Range and los(d.pos,target.part.Position,target.part) then
     W.setBeam(d.beam,true,target.part.Position)
     target.hp=math.max(0,target.hp-C.DroneDPS*(1+profile.power*.8)*C.Tick)
     if target.hp==0 then target.part.Transparency=.8;target.part:SetAttribute('Dead',true);target.lock=nil;target.fireAt=nil end
    end
   end
  elseif canMine(p) then
   if profile.ore>=C.Capacity then recall(d)
   else
    if d.target and (d.target.paid or not d.target.part.Parent) then release(d) end
    if not d.target then chooseResource(d,p) end
    local r=d.target
    if r then
     local at=r.part.Position+Vector3.new((d.slot-2)*2,6,5)
     d.state='Travel';position(d,at,r.part.Position)
     if (d.pos-r.part.Position).Magnitude<C.Range and los(d.pos,r.part.Position,r.part) then d.state='Mine';W.setBeam(d.beam,true,r.part.Position);hitResource(d,p,r,C.DroneDPS*(1+profile.power*.8)*C.Tick) end
    else d.state='Follow';position(d,p.center+Vector3.new((d.slot-2)*4,9,12)) end
   end
  else recall(d) end
 else
  local ch=profile.player.Character;local hr=ch and ch:FindFirstChild('HumanoidRootPart')
  local at=d.state=='Return' and origin+Vector3.new(d.slot*3-6,6,7) or (hr and hr.Position or origin)+Vector3.new((d.slot-2)*4,6,6)
  if d.state~='Return' then d.state='Follow' end
  if position(d,at+Vector3.new(0,math.sin(clock*2+d.slot)*.35,0)) and d.state=='Return' then d.state='Follow' end
  -- Repairs only at base, outside any assault; retreat spends this life in all active rosters.
  if (d.pos-origin).Magnitude<25 then d.hp=math.min(d.maxHP,d.hp+10*C.Tick) end
 end
 attr(d)
end
local function commandPlayer(pl,action,value)
 local p=profiles[pl.UserId];if not p then return end
 -- Token bucket covers every input, including malformed values.
 local elapsed=math.max(0,clock-p.bucketAt);p.tokens=math.min(6,p.tokens+elapsed*3);p.bucketAt=clock
 if p.tokens<1 then return end;p.tokens=p.tokens-1
 if type(action)~='string' or not alivePlayer(p) then return end
 if action=='Recall' then for _,d in ipairs(p.drones) do recall(d) end
 elseif action=='Sell' then
  if not inHome(p) then return end
  p.credits=p.credits+p.ore;p.ore=0;updateProfile(p)
 elseif action=='Upgrade' then
  if not inHome(p) or (value~='power' and value~='hull') then return end
  for _,d in ipairs(p.drones) do if d.patch then return end end
  local level=p[value];local cost=C.UpgradeCosts[level+1];if not cost or p.credits<cost then return end
  p.credits=p.credits-cost;p[value]=level+1
  for _,d in ipairs(p.drones) do d.maxHP=C.Hull*(1+p.hull*.8);if d.hp>0 then d.hp=d.maxHP end end
  updateProfile(p)
 elseif action=='Patch' then
  if not R.finite(value) or value%1~=0 then return end
  local patch=patches[value];if not patch then return end
  local hr=p.player.Character and p.player.Character:FindFirstChild('HumanoidRootPart')
  if not hr or (hr.Position-patch.center).Magnitude>58 then return end
  if patch.e.phase=='Resetting' or patch.e.phase=='Active' then return end
  -- Claimed tier and recommended power/hull are never damage inputs. The actual fleet must win.
  if patch.e.phase=='Gathering' and (patch.e.users[pl.UserId] or clock>=patch.e.untilTime) then return end
  local fleet={}
  for _,d in ipairs(p.drones) do if R.allowed(d.owner,pl.UserId,d.state) and d.hp>0 then table.insert(fleet,d) end end
  if #fleet==0 then return end
  if patch.e.phase=='Guarded' then R.gather(patch.e,clock) end
  for _,d in ipairs(fleet) do release(d);markSpent(d);d.patch=value;d.state='Travel' end
  if patch.e.phase=='Gathering' then R.enroll(patch.e,pl.UserId,fleet) end
 end
end
command.OnServerEvent:Connect(commandPlayer)
local function addPlayer(pl)
 if profiles[pl.UserId] then return end
 local saved=cache[pl.UserId] or {credits=0,ore=0,power=0,hull=0}
 local p={player=pl,credits=saved.credits,ore=saved.ore,power=saved.power,hull=saved.hull,drones={},tokens=6,bucketAt=clock}
 profiles[pl.UserId]=p
 local function character(ch)
  local hr=ch:WaitForChild('HumanoidRootPart',10)
  if not hr or not pl.Parent then return end
  ch:PivotTo(CFrame.new(origin+Vector3.new(0,6,0)))
  for _,d in ipairs(p.drones) do recall(d) end
 end
 p.connection=pl.CharacterAdded:Connect(character)
 if pl.Character then task.spawn(character,pl.Character) end
 for i=1,C.Fleet do local d=createDrone(p,i);d.maxHP=C.Hull*(1+p.hull*.8);d.hp=d.maxHP end
 updateProfile(p)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(pl)
 local p=profiles[pl.UserId];if not p then return end
 cache[pl.UserId]={credits=p.credits,ore=p.ore,power=p.power,hull=p.hull}
 if p.connection then p.connection:Disconnect() end
 for _,d in ipairs(p.drones) do release(d);markSpent(d);d.model:Destroy();drones[d.id]=nil end
 profiles[pl.UserId]=nil
end)
for _,pl in ipairs(Players:GetPlayers()) do addPlayer(pl) end
local accumulator=0
RunService.Heartbeat:Connect(function(dt)
 -- At most three fixed simulation steps per heartbeat; stalled servers do not emit burst damage.
 accumulator=math.min(accumulator+dt,C.Tick*3)
 while accumulator>=C.Tick do
  accumulator=accumulator-C.Tick;clock=clock+C.Tick
  for _,p in ipairs(patches) do tickEncounter(p) end
  for _,d in pairs(drones) do tickDrone(d) end
  for _,p in ipairs(patches) do
   tickTurrets(p);tickEncounter(p)
   p.model:SetAttribute('Phase',p.e.phase);p.model:SetAttribute('Epoch',p.e.epoch)
   p.model:SetAttribute('PhaseEndsAt',workspace:GetServerTimeNow()+math.max(0,p.e.untilTime-clock))
   p.label.Text=string.format('T%d • %s • %s\n%d ore/crystal • Power %d / Hull %d',p.id,p.cfg.Name,p.e.phase,p.cfg.Reward,p.cfg.Power,p.cfg.Hull)
   local live=0
   for n=#p.resources,1,-1 do local r=p.resources[n];if not r.paid then live=live+1 elseif r.removeAt and clock>=r.removeAt then r.part:Destroy();table.remove(p.resources,n) end end
   if live==0 and canMine(p) then if p.refreshAt==0 then p.refreshAt=clock+12 elseif clock>=p.refreshAt then seed(p);p.refreshAt=0 end else p.refreshAt=0 end
  end
 end
end)
