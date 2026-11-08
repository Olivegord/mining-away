-- Exercise the real Quartz job dispatcher and economy against Roblox API doubles.
local field=patches[1]
for _,r in ipairs(field.resources) do resources[r.id]=nil;r.part:Destroy() end
field.resources={};field.respawnQueue={}
field.junk=Instance.new('Folder')
for _,spec in ipairs(JunkField.Props) do
 local prop=Instance.new('Part');prop.Name=spec.template;prop.MaterialVariant=spec.template;prop.Parent=field.junk
end
function workspace:Raycast(from,delta)
 if delta.Y< -50 and math.abs(delta.X)+math.abs(delta.Z)<1e-6 then return {Instance=field.part,Position=Vector3.new(from.X,field.part.Position.Y+field.part.Size.Y/2,from.Z)} end
 return nil
end
local function move(pl,position)
 pl.Character:PivotTo(CFrame.new(position+Vector3.new(0,3,0)))
end
local function join(id)
 local pl=player(id);players.PlayerAdded:Fire(pl);move(pl,field.center)
 return pl,assert(profiles[id])
end
local function input(pl,action,payload)
 local p=profiles[pl.UserId];p.tokens=7;p.bucketAt=now;command.OnServerEvent:Fire(pl,action,payload)
end
local function advance(seconds)
 for _=1,math.ceil(seconds/C.Tick) do realTime+=C.Tick;heartbeat:Fire(C.Tick) end
end
local function jobs(p)
 local count=0;for _,d in ipairs(p.drones) do if d.target then count+=1 end end
 return count
end

local starter,p=join(310003)
assert(#p.drones==1 and p.drones[1].stats.plotAuto==0)
scene.replenishJunk(field)
assert(#field.resources==JunkField.BatchSize)
for _,r in ipairs(field.resources) do
 assert(r.kind=='Junk' and r.limit==1 and not r.part.CanQuery and now<r.readyAt)
 assert(r.part.MaterialVariant~='' and r.part:GetAttribute('JunkInterior')~=nil)
end
input(starter,'Patch',field.id);advance(.4)
assert(jobs(p)==0,'falling junk cannot be claimed')
advance(1.7)
local first=assert(p.drones[1].target,'starter needs no card or clicked target')
assert(first.part:GetAttribute('SlotsUsed')==1)
for _=1,550 do
 advance(C.Tick)
 if first.paid and p.drones[1].target and p.drones[1].target~=first and Pro.cargoUnits(data(p))>0 then break end
end
assert(first.paid and p.drones[1].target~=nil and p.drones[1].target~=first,'one order must mine and select again')
assert(Pro.cargoUnits(data(p))>0,'ordinary pickup must add salvage to the bag')
input(starter,'Recall')
assert(not p.drones[1].target and not p.drones[1].autoField and not next(first.slots))
move(starter,scene.converter.Position);input(starter,'Sell')
assert(data(p).run.wallet.Quartz>0 and Pro.cargoUnits(data(p))==0)
print('PASS Quartz starter waits for landing, continues autonomously, and sells collected salvage')

local fast,fleet=join(310004)
for i=2,4 do
 local owned=Pro.clone(fleet.drones[1].owned);owned.id='junk-test-drone-'..i;spawnDrone(fleet,owned,i)
end
local second,q=join(310005)
input(fast,'Patch',field.id);input(second,'Patch',field.id);advance(.2)
assert(jobs(q)==1 and jobs(fleet)<=JunkField.CrewCap)
assert(fleet.junkTurn>q.junkTurn or jobs(fleet)==1)
local reservations={}
for _,r in ipairs(field.resources) do if not r.paid then
 local id=next(r.slots)
 if id then
  assert(not next(r.slots,id) and not reservations[id]);reservations[id]=true
 end
end end
-- Reduce the available set to simulate a field whose existing jobs are all claimed.
for _,r in ipairs(field.resources) do if not r.paid and not next(r.slots) then r.readyAt=now+30 end end
local late,l=join(310006);input(late,'Patch',field.id)
scene.dispatchJunk(field);assert(jobs(l)==0)
local fresh=makeResource(field,field.center+Vector3.new(0,0,8),'Junk',74,12,5,3,{name='New Plaid',template='BlueGinghamPaver',order=1,interior='Wool'})
fresh.readyAt=now
scene.dispatchJunk(field)
assert(l.drones[1].target==fresh and fresh.slots[l.drones[1].id]==1)
input(fast,'MineOre',fresh.id)
assert(l.drones[1].target==fresh and not next(fleet.oreQueue))
local contact=fresh.part.Position+Vector3.new(0,fresh.fullSize.Y*.5,0)
assert(not scene.fieldTools.ctx.eligible(fleet,fresh,field.center),'a foreign bowling ball may not steal this job')
assert(scene.fieldTools.ctx.hit(l,fresh,20,contact+Vector3.new(0,5,0),'BowlingBall',contact))
assert(fresh.part:GetAttribute('BallDentPoint').Y>.48 and fresh.part:GetAttribute('JunkInterior')=='Wool')
assert(fresh.part.Size.Y==fresh.fullSize.Y)
players.PlayerRemoving:Fire(late)
assert(not next(fresh.slots),'disconnect releases the prop')
move(second,field.center+Vector3.new(0,0,150));advance(.2)
assert(jobs(q)==0,'leaving the clearing releases the claim')
for _=1,6 do advance(2.6);assert(nodeUsage(field)<=JunkField.Cap) end
print('PASS Quartz fair claims, late-join priority, bowling damage, release and field cap')
