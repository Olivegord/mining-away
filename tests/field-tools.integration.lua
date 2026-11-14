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
local function input(p,action,extra,hold)
 local s=tools:state(p);local payload={runId=s.runId,version=s.version}
 for k,v in pairs(extra or {}) do payload[k]=v end
 p.tokens=7;command.OnServerEvent:Fire(p.player,action,payload)
 if not hold and s.attack then advance(s.attack.at-now+.001);tools:step(.016) end
 return payload
end
local function contact(item,r,point)
 return {id=item.id,resourceId=r.id,point=point or r.part.Position+Vector3.new(0,r.part.Size.Y*.5,0)}
end
local function equip(p,item)
 local s=tools:state(p);for slot=1,ToolRules.SLOTS do if s.slots[slot]==item then input(p,'EquipFieldTool',{slot=slot});assert(s.selected==slot);return end end
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
 advance(1);input(p,'UseFieldTool',contact(ball,r));assert(ball.state=='Flying')
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
 local target=node(8)
 for throw=1,4 do
  advance(1);input(p,'UseFieldTool',contact(ball,target))
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
 advance(1);input(p,'UseFieldTool',contact(ball,r));tools:impact(p,ball,origin,Vector3.new(0,1,0),r)
 local scars=Http:JSONDecode(r.part:GetAttribute('ToolScars'))
 assert(r.hp<hp and r.consumableWorked and #scars==1 and scars[1][2]==.5)
 assert(pendingOre(p)>0)
 local found=tools:state(p).found;rock(p,r);assert(tools:state(p).found==found)
end)
check('jelly sticks, waits for its fuse, damages nearby rocks once and disappears',function()
 local _,p=fixture();local jelly=collect(p,discover(p,'JellyGrenade'));equip(p,jelly)
 local a,b,far=node(2),node(8),node(28);local ah,bh,fh=a.hp,b.hp,far.hp
 advance(1);input(p,'UseFieldTool',contact(jelly,a));assert(jelly.hp==0 and jelly.state=='Flying')
 tools:impact(p,jelly,a.part.Position+Vector3.new(0,a.part.Size.Y*.5+.01,0),Vector3.new(0,1,0),a)
 advance(.18);tools:step(.05);assert(a.hp==ah and b.hp==bh and jelly.state=='Stuck')
 advance(.5);tools:step(.05);assert(a.hp<ah and b.hp<bh and far.hp==fh and not tools.items[jelly.id])
 ah,bh=a.hp,b.hp;advance(2);tools:step(.05);assert(a.hp==ah and b.hp==bh)
end)
check('crowbar only wears on a valid reachable hit and breaks after twelve',function()
 local _,p=fixture();local bar=collect(p,discover(p,'Crowbar'));equip(p,bar)
 local r=node(2,100000);local hp=r.hp
 input(p,'UseFieldTool',{id=bar.id,aim=r.part.Position,resourceId='unknown'});assert(bar.hp==12)
 for i=1,12 do advance(.6);input(p,'UseFieldTool',contact(bar,r)) end
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
 tools:clear(p);local held=collect(p,discover(p,'BowlingBall'));data(p).run.id='next-run';tools:step(.05);assert(not tools.items[held.id])
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
check('a near-miss acquires a rock and windup preserves the chosen face point',function()
 local _,p=fixture();tools:previewLoadout(p);local s=tools:state(p);local r=node(3);local ball=s.slots[1];equip(p,ball)
 local assist=tools:target(p,p.player.Character.PrimaryPart,ToolRules.ITEMS.BowlingBall,nil,r.part.Position+Vector3.new(0,0,2))
 assert(assist==r,'a click just beside the rock should assist')
 local point=r.part.CFrame:PointToWorldSpace(r.part.Size*Vector3.new(.28,.5,.2))
 input(p,'UseFieldTool',contact(ball,r,point),true);assert(s.attack and math.abs(s.attack.offset.X-.28)<1e-6 and ball.hp==4)
 advance(.2);tools:step(.016);assert(ball.state=='Held' and ball.hp==4)
 advance(.3);tools:step(.016);assert(ball.state=='Flying' and ball.hp==3)
end)
check('all eight tools act on an empty click',function()
 for i,kind in ipairs(ToolRules.ORDER) do
  local _,p=fixture();tools:previewLoadout(p);local s=tools:state(p);local item=s.slots[i];equip(p,item)
  local point=p.player.Character.PrimaryPart.Position+Vector3.new(4,-2,0)
  input(p,'UseFieldTool',{id=item.id,point=point,version=s.version-1},true)
  assert(s.attack and s.attack.target==nil and p.player:GetAttribute('ToolActionKind')==kind)
  advance(1);tools:step(.016)
  local def=ToolRules.ITEMS[kind]
  if def.gravity then assert(item.state=='Flying' and item.hp==def.uses-1)
  else
   assert(item.state=='Held' and item.hp==def.uses)
   assert(tools.effects:FindFirstChild(kind..(def.gadget and 'Probe' or 'Whiff')))
  end
 end
end)
check('assist skips blocked rocks and releases even if a target disappears',function()
 local _,p=fixture();tools:previewLoadout(p);local s=tools:state(p);local ball=s.slots[1];equip(p,ball)
 local r=node(7);local hr=p.player.Character.PrimaryPart;local def=ToolRules.ITEMS.BowlingBall
 local clear=tools.ctx.clear;tools.ctx.clear=function(_,_,_,target) return target~=r.part end
 assert(not tools:target(p,hr,def,r.id,r.part.Position+Vector3.new(0,1.5,0)))
 tools.ctx.clear=clear
 input(p,'UseFieldTool',contact(ball,r),true);assert(s.attack.target==r)
 r.paid=true;advance(1);tools:step(.016);assert(ball.state=='Flying' and ball.hp==3)
end)
check('sword removes a real slice at click height and keeps its foot grounded',function()
 local _,p=fixture();tools:previewLoadout(p);local sword=tools:state(p).slots[4];equip(p,sword)
 local r=node(3);local size=r.part.Size;local foot=r.part.Position.Y-size.Y*.5
 local point=r.part.CFrame:PointToWorldSpace(size*Vector3.new(.5,-.1,0))
 input(p,'UseFieldTool',contact(sword,r,point))
 assert(sword.hp==2 and math.abs(r.slice-.4)<1e-6 and r.part.Size.Y<=size.Y*.4)
 assert(math.abs(r.part.Position.Y-r.part.Size.Y*.5-foot)<.001)
end)
check('molten steel damages only after contact, and lowers the rock with heat',function()
 local _,p=fixture();tools:previewLoadout(p);local molten=tools:state(p).slots[8];equip(p,molten)
 local r=node(3);local original=r.hp;local h=r.part.Size.Y
 input(p,'UseFieldTool',contact(molten,r));assert(molten.state=='Flying' and r.hp==original)
 tools:impact(p,molten,r.part.Position+Vector3.new(0,h*.5,0),Vector3.new(0,1,0),r)
 advance(.25);tools:step(.016);advance(.25);tools:step(.016)
 assert(r.hp<original and r.part.Size.Y<h and r.part:GetAttribute('MeltBand')>0)
end)
check('tool hits retain old marks and use the same health sizing as drone hits',function()
 local _,p=fixture()
 local a,b=node(5,1000),node(-5,1000)
 local function strike(r,amount,kind,point)
  local contact=r.part.CFrame:PointToWorldSpace(r.part.Size*point)
  assert(tools.ctx.hit(p,r,amount,contact+Vector3.new(0,1,0),kind,contact))
 end
 strike(a,140,'Crowbar',Vector3.new(.5,0,0))
 strike(a,180,'BowlingBall',Vector3.new(0,.5,0))
 local scars=Http:JSONDecode(a.part:GetAttribute('ToolScars'))
 assert(#scars==2 and scars[1][1]==.5 and scars[2][2]==.5)
 local old=scars[1][4]
 strike(a,60,'Crowbar',Vector3.new(.5,0,0))
 scars=Http:JSONDecode(a.part:GetAttribute('ToolScars'))
 assert(#scars==2 and scars[1][4]>old and scars[2][2]==.5)
 assert(hitResource(p.drones[1],b,380,false,nil,b.part.Position+Vector3.new(0,8,0)))
 assert(a.stage==b.stage and a.stage>0 and (a.part.Size-b.part.Size).Magnitude<1e-6)
 assert(math.abs(a.part.Position.Y-a.part.Size.Y*.5-(a.part:GetAttribute('GroundY')-.06))<.001)
 strike(a,50,'Melt',Vector3.new(-.26,.5,0))
 strike(a,50,'Melt',Vector3.new(.26,.5,0))
 scars=Http:JSONDecode(a.part:GetAttribute('ToolScars'))
 assert(#scars==4 and scars[1][1]==.5 and scars[2][2]==.5 and scars[3][7] and scars[4][7])
 local history={}
 for _,x in ipairs({-.3,.3}) do for _,y in ipairs({-.3,.3}) do for _,z in ipairs({-.5,.5}) do
  assert(ToolRules.addScar(history,Vector3.new(x,y,z),.475,.37,false))
 end end end
 assert(not ToolRules.addScar(history,Vector3.new(.5,0,0),.475,.37,false) and #history==8 and history[1][1]==-.3)
end)
check('one inventory contains all eight preview items; dropped gadgets use the existing effects',function()
 local _,p=fixture();tools:previewLoadout(p)
 local s=tools:state(p);for i,kind in ipairs(ToolRules.ORDER) do assert(s.slots[i].kind==kind) end
 local orbital=s.slots[6];equip(p,orbital);local r=node(4);local point=r.part.Position+Vector3.new(.2,r.part.Size.Y*.5,0)
 input(p,'UseFieldTool',contact(orbital,r,point))
 assert(p.supply and p.supply.temporary and p.supply.targetId==r.id and p.supply.position.X==point.X and orbital.state=='Deployed')
 assert(not data(p).consumables.pending)
 local emit=RoleEffects.Ability;RoleEffects.Ability=function() end
 local hp=r.hp;consumableService:step(p,.016)
 advance(1.6)
 for _=1,20 do advance(.05);consumableService:step(p,.05) end
 RoleEffects.Ability=emit
 assert(r.hp<hp and (r.part:GetAttribute('MeltBand') or 0)>0 and not s.slots[6],'first mining contact must melt the rock and spend the deployed tool')
end)
check('an interrupted orbital returns the same temporary tool before its first contact',function()
 local pl,p=fixture();tools:previewLoadout(p)
 local s=tools:state(p);local orbital=s.slots[6];local r=node(3)
 equip(p,orbital);input(p,'UseFieldTool',contact(orbital,r));consumableService:step(p,.016)
 assert(p.supply and orbital.state=='Deployed')
 local hp=r.hp;pl.Character:PivotTo(CFrame.new(home));advance(.2);consumableService:step(p,.016)
 assert(not p.supply and s.slots[6]==orbital and orbital.state=='Held' and orbital.hp==1 and r.hp==hp)
end)
check('runtime rocks become solid after growth and stop blocking on depletion',function()
 local _,p=fixture();local r=node(18);r.readyAt=now+.2
 assert(not r.part.CanCollide);advance(.3);heartbeat:Fire(.11);assert(r.part.CanCollide and r.part.CanTouch)
 rock(p,r);assert(not r.part.CanCollide and not r.part.CanQuery and not r.part.CanTouch)
end)
print(checks..' actual-server temporary tool and hazard checks; no native play/render claim')
