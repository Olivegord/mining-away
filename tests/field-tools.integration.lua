local checks=0;local uid=620000;local tools=scene.fieldTools
tools.ctx.random=function() return 0 end
local function check(name,f) local ok,err=pcall(f);assert(ok,name..': '..tostring(err));checks+=1;print('PASS field tools '..name) end
local function fixture()
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=profiles[uid]
 pl.Character:PivotTo(CFrame.new(patches[1].center+Vector3.new(0,3,0)))
 for _,r in ipairs(patches[1].resources) do r.paid=true;r.hp=0 end
 return pl,p
end
local function node(x,hp)
 local f=patches[1];local r=makeResource(f,f.center+Vector3.new(x or 0,0,0),'Crystal',hp or 800,10,3);r.readyAt=now;return r
end
local function advance(t) realTime+=t;now=realTime end
local function rock(p,r)
 local d=p.drones[1];assert(hitResource(d,r,1e6,false,nil,r.part.Position+Vector3.new(0,40,0)))
end
local function itemOf(p,kind)
 for _,v in pairs(tools.items) do if v.owner==p.player.UserId and v.kind==kind then return v end end
end
local function discover(p,kind)
 for _=1,24 do rock(p,node());local item=itemOf(p,kind);if item then return item end end
 error('No '..kind..' drop')
end
local function collect(p,item)
 advance(.7);p.player.Character:PivotTo(CFrame.new(item.part.Position));assert(tools:collect(p,item));return item
end
local function input(p,action,extra)
 local s=tools:state(p);local payload={runId=s.runId,version=s.version}
 for k,v in pairs(extra or {}) do payload[k]=v end
 p.tokens=7;command.OnServerEvent:Fire(p.player,action,payload);return payload
end
local function equip(p,item)
 local s=tools:state(p);for slot=1,3 do if s.slots[slot]==item then input(p,'EquipFieldTool',{slot=slot});assert(s.selected==slot);return end end
 error('item not in inventory')
end
check('first bowling drop, contact ownership and full ore bag remain independent',function()
 local a,p=fixture();rock(p,node());assert(not itemOf(p,'BowlingBall'));rock(p,node())
 local ball=assert(itemOf(p,'BowlingBall'));local _,other=fixture();advance(.7)
 other.player.Character:PivotTo(CFrame.new(ball.part.Position));assert(not tools:collect(other,ball))
 data(p).run.cargo.Quartz=Ca.capacity(data(p));collect(p,ball)
 assert(ball.hp==4 and ball.state=='Held' and Pro.cargoUnits(data(p))==Ca.capacity(data(p)))
 assert(Http:JSONDecode(a:GetAttribute('MA_FieldTools')).slots[1].maxHP==4)
end)
check('heavy arc reaches its clamped target and falls fast without client speed input',function()
 local from=Vector3.new(0,5,0);local aim=Vector3.new(40,0,0)
 local v,t=ToolRules.launch('BowlingBall',from,aim);local finish=ToolRules.position(from,v,420,t)
 assert((finish-aim).Magnitude<1e-6 and v.Y-420*t<-120)
 for _,bad in ipairs({Vector3.new(0/0,1,1),Vector3.new(math.huge,0,0)}) do assert(not ToolRules.launch('BowlingBall',from,bad)) end
 assert(not ToolRules.launch('BowlingBall',from,Vector3.new(1e38,0,0)))
 local far=Vector3.new(8000,0,0);v,t=ToolRules.launch('BowlingBall',from,far)
 assert(math.abs(ToolRules.position(from,v,420,t).X-42)<1e-6)
end)
check('swept flight takes the first blocking surface, never mines past a wall',function()
 local _,p=fixture();local ball=collect(p,discover(p,'BowlingBall'));equip(p,ball)
 local r=node(8);local wall=Instance.new('Part');wall.Parent=workspace
 advance(1);input(p,'UseFieldTool',{id=ball.id,aim=r.part.Position});assert(ball.state=='Flying')
 local old=workspace.Spherecast;local casts=0
 workspace.Spherecast=function(_,from,radius,delta)
  assert(radius==ToolRules.ITEMS.BowlingBall.radius and delta.Magnitude<20);casts+=1
  if casts==3 then return {Position=from+delta*.5,Normal=Vector3.new(-1,0,0),Instance=wall} end
 end
 local before=r.hp;advance(.2);tools:step(.05);workspace.Spherecast=old;wall:Destroy()
 assert(casts>=3 and ball.state=='Recover' and r.hp==before)
end)
check('ball permits exactly three touch recoveries then shatters on fourth impact',function()
 local _,p=fixture();local ball=collect(p,discover(p,'BowlingBall'));equip(p,ball)
 local from=p.player.Character.PrimaryPart.Position
 for throw=1,4 do
  advance(1);input(p,'UseFieldTool',{id=ball.id,aim=from+Vector3.new(10,-2,0)})
  assert(ball.state=='Flying' and ball.hp==4-throw)
  local before=ball.hp;input(p,'UseFieldTool',{id=ball.id,aim=from});assert(ball.hp==before,'duplicate spent durability')
  tools:impact(p,ball,from+Vector3.new(8,-2,0),Vector3.new(0,1,0),nil)
  if throw<4 then assert(ball.state=='Recover');assert(not tools:collect(p,ball));collect(p,ball)
  else assert(not tools.items[ball.id] and not ball.part) end
 end
 assert(not tools:state(p).slots[1] and tools:state(p).selected==0)
end)
check('bowling contact dents the real rock, yields ore and never farms equipment',function()
 local _,p=fixture();local ball=collect(p,discover(p,'BowlingBall'));equip(p,ball)
 local r=node(4);local origin=r.part.Position+Vector3.new(0,3,0);local hp=r.hp
 advance(1);input(p,'UseFieldTool',{id=ball.id,aim=r.part.Position});tools:impact(p,ball,origin,Vector3.new(0,1,0),r)
 assert(r.hp<hp and r.consumableWorked and r.part:GetAttribute('BallDents')==1 and r.part:GetAttribute('BallDentPoint').Y>.48)
 assert(pendingOre(p)>0)
 local found=tools:state(p).found;rock(p,r);assert(tools:state(p).found==found)
end)
check('jelly sticks, waits for its fuse, damages nearby rocks once and disappears',function()
 local _,p=fixture();local jelly=collect(p,discover(p,'JellyGrenade'));equip(p,jelly)
 local a,b,far=node(2),node(8),node(28);local ah,bh,fh=a.hp,b.hp,far.hp
 advance(1);input(p,'UseFieldTool',{id=jelly.id,aim=a.part.Position});assert(jelly.hp==0 and jelly.state=='Flying')
 tools:impact(p,jelly,a.part.Position+Vector3.new(0,a.part.Size.Y*.5+.01,0),Vector3.new(0,1,0),a)
 advance(1);tools:step(.05);assert(a.hp==ah and b.hp==bh and jelly.state=='Stuck')
 advance(.5);tools:step(.05);assert(a.hp<ah and b.hp<bh and far.hp==fh and not tools.items[jelly.id])
 ah,bh=a.hp,b.hp;advance(2);tools:step(.05);assert(a.hp==ah and b.hp==bh)
end)
check('crowbar only wears on a valid reachable hit and breaks after twelve',function()
 local _,p=fixture();local bar=collect(p,discover(p,'Crowbar'));equip(p,bar)
 local r=node(2,100000);local hp=r.hp
 input(p,'UseFieldTool',{id=bar.id,aim=r.part.Position,resourceId='unknown'});assert(bar.hp==12)
 for i=1,12 do advance(.6);input(p,'UseFieldTool',{id=bar.id,aim=r.part.Position,resourceId=r.id}) end
 assert(r.hp<hp and not tools.items[bar.id] and r.consumableWorked)
end)
check('stale versions, stale runs, foreign reservations and blocked hits are rejected',function()
 local _,p=fixture();local ball=collect(p,discover(p,'BowlingBall'));equip(p,ball)
 local s=tools:state(p);local position=p.player.Character.PrimaryPart.Position
 input(p,'UseFieldTool',{id=ball.id,aim=position,version=s.version-1});assert(ball.hp==4)
 input(p,'UseFieldTool',{id=ball.id,aim=position,runId='old'});assert(ball.hp==4)
 local _,other=fixture();local r=node();r.slots[other.drones[1].id]=1
 assert(not tools.ctx.hit(p,r,100,r.part.Position+Vector3.new(0,10,0),'BowlingBall'))
 r.slots={};local ray=workspace.Raycast;workspace.Raycast=function()return {Instance=home and scene.map,Position=Vector3.zero}end
 assert(not tools.ctx.hit(p,r,100,r.part.Position+Vector3.new(0,10,0),'BowlingBall'));workspace.Raycast=ray
end)
check('death, prestige, disconnect and expiry clear temporary gear while fleet survives',function()
 local _,p=fixture();local ball=collect(p,discover(p,'BowlingBall'));local permanent=data(p).fleet[1].id
 p.player.Character:FindFirstChildOfClass('Humanoid').Health=0;tools:step(.05);assert(not p.fieldTools and not tools.items[ball.id])
 assert(data(p).fleet[1].id==permanent)
 p.player.Character:FindFirstChildOfClass('Humanoid').Health=100
 local drop=discover(p,'BowlingBall');advance(ToolRules.WORLD_LIFETIME+1);tools:step(.05);assert(not tools.items[drop.id])
 local held=collect(p,discover(p,'BowlingBall'));data(p).run.id='next-run';tools:step(.05);assert(not tools.items[held.id])
 local held2=collect(p,discover(p,'BowlingBall'));players.PlayerRemoving:Fire(p.player);assert(not tools.items[held2.id])
end)
check('lasers and explosions hurt players including the owner, with cover and shields',function()
 local _,p=fixture();local hr=p.player.Character.PrimaryPart;local h=p.player.Character:FindFirstChildOfClass('Humanoid')
 local from=hr.Position+Vector3.new(0,6,0);scene.hazards:beam(from,hr.Position-Vector3.new(0,4,0),10);assert(h.Health==100,'spawn shield failed')
 p.player.Character:FindFirstChildOfClass('ForceField'):Destroy()
 scene.hazards:beam(from,hr.Position-Vector3.new(0,4,0),10);assert(h.Health==90)
 scene.hazards:beam(from,hr.Position,10);assert(h.Health==90,'beam spam bypassed interval')
 advance(.4);local ray=workspace.Raycast;local wall=Instance.new('Part');wall.Parent=workspace
 workspace.Raycast=function()return {Instance=wall,Position=from}end
 scene.hazards:blast(hr.Position,12,40);assert(h.Health==90,'explosion ignored cover');workspace.Raycast=ray
 scene.hazards:blast(hr.Position,12,40);assert(h.Health==50 and hr.LastImpulse,'owner explosion or impulse missing')
 hr.Position=home;advance(.4);scene.hazards:blast(home,12,40);assert(h.Health==50,'home safe area missing')
end)
check('runtime rocks become solid after growth and stop blocking on depletion',function()
 local _,p=fixture();local r=node(18);r.readyAt=now+.2
 assert(not r.part.CanCollide);advance(.3);heartbeat:Fire(.11);assert(r.part.CanCollide and r.part.CanTouch)
 rock(p,r);assert(not r.part.CanCollide and not r.part.CanQuery and not r.part.CanTouch)
end)
print(checks..' actual-server temporary tool and hazard checks; no native play/render claim')
