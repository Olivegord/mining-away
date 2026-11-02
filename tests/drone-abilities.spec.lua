-- Executes production gadget state/target/movement logic, not Roblox rendering.
local A=require('../src/DroneAbilities')
local passed=0
local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS gadget '..name) end
local function setup()
 local rocks={
  {id='big',hp=100,maxHP=100,x=0,y=0,z=0},
  {id='small',hp=20,maxHP=50,x=4,y=0,z=0},
  {id='near',hp=30,maxHP=60,x=7,y=0,z=0},
  {id='far',hp=30,maxHP=70,x=100,y=0,z=0},
 }
 local hits,events={},{}
 local ctx={runId='run:1',fieldId=1,origin={x=0,y=3,z=0},perks={},denied=false,blocked=false,isFull=false}
 ctx.unlocked=function() return not ctx.denied end
 ctx.valid=function(id) return not ctx.blocked and id==1 end
 ctx.full=function() return ctx.isFull end
 ctx.targets=function() local list={};for _,r in ipairs(rocks) do if r.hp>0 then table.insert(list,table.clone(r)) end end;return list end
 ctx.hit=function(id,damage,kind,origin)
  if ctx.blocked then return false end
  for _,r in ipairs(rocks) do if r.id==id and r.hp>0 then
   table.insert(hits,{id=id,damage=damage,kind=kind,origin=origin});r.hp=math.max(0,r.hp-damage);return true,r.hp<=0
  end end
  return false
 end
 ctx.emit=function(e) table.insert(events,e) end
 return A.new(),ctx,rocks,hits,events
end
local function begin(state,ctx,kind,now)
 assert(A.begin(state,kind or 'Orbital',now or 10,ctx));return state.charge.token
end
test('shop/permanent unlock is required and failures never hit',function()
 local s,c,_,h=setup();c.denied=true;assert(not A.begin(s,'Orbital',10,c));assert(#h==0 and not s.charge)
end)
test('unknown gadget, NaN time and locked plot are rejected',function()
 local s,c=setup();assert(not A.begin(s,'Fake',10,c));assert(not A.begin(s,'Orbital',0/0,c));c.blocked=true;assert(not A.begin(s,'Orbital',10,c))
end)
test('full backpack does not prevent sustained mining abilities',function()
 local s,c,r,h=setup();c.isFull=true;local token=begin(s,c);assert(A.confirm(s,token,10.9,c));assert(s.burn and #h==0)
 A.step(s,11,.1,c);assert(#h==1 and r[1].hp>0 and r[1].hp<100)
end)
test('largest grown eligible crystal is selected with stable ID tie break',function()
 local s,c,r=setup();r[4].maxHP=100;r[4].id='aaa';begin(s,c);assert(s.charge.targetId=='aaa')
end)
test('server timing rejects premature and expired input without spending cooldown',function()
 local s,c,_,h=setup();local token=begin(s,c);assert(not A.confirm(s,token,10.01,c));assert(s.charge)
 assert(not A.confirm(s,token,12.6,c));assert(not s.charge and not s.cooldowns.Orbital and #h==0)
end)
test('unrecognized/replayed tokens cannot fire twice',function()
 local s,c,_,h=setup();local token=begin(s,c);assert(not A.confirm(s,'spoof',10.9,c));assert(A.confirm(s,token,10.5,c));A.step(s,10.6,.1,c);assert(#h==1)
 assert(not A.confirm(s,token,11,c));assert(#h==1)
end)
local function burn(s,c,start,seconds)
 for n=1,math.ceil((seconds or 4.1)*60) do A.step(s,start+n/60,1/60,c) end
end
test('ordinary orbital melts one biggest rock over four seconds',function()
 local s,c,r,h=setup();local token=begin(s,c);assert(A.confirm(s,token,10.5,c));assert(r[1].hp==100 and #h==0)
 burn(s,c,10.5,2);assert(r[1].hp>45 and r[1].hp<55 and #h==120 and s.burn)
 burn(s,c,12.5,2.1);assert(r[1].hp<1e-6 and not s.burn)
 for _,hit in ipairs(h) do assert(hit.id=='big' and hit.damage<1 and hit.origin.y==34) end
 assert(s.cooldowns.Orbital==55.5 and not A.begin(s,'Orbital',15,c))
end)
test('precision burn fractures one neighbor on completion, never during charge',function()
 for _,retired in ipairs({false,true}) do
  local s,c,r,h=setup();c.perks.orbitalRelay=retired;local token=begin(s,c);assert(A.confirm(s,token,10.9,c));assert(#h==0)
  burn(s,c,10.9,4.1);local relays=0
  for _,hit in ipairs(h) do if hit.kind=='OrbitalRelay' then relays+=1;assert(hit.id~='far') end end
  assert(relays==1 and not s.burn)
 end
end)
test('lost target cancels and first blocked contact refunds cooldown',function()
 local s,c,r,h=setup();local token=begin(s,c);r[1].hp=0;assert(not A.confirm(s,token,10.9,c));assert(not s.cooldowns.Orbital and #h==0)
 s,c=setup();token=begin(s,c);c.hit=function() return false end;assert(A.confirm(s,token,10.9,c))
 A.step(s,11,.1,c);assert(not s.burn and s.cooldowns.Orbital<=11)
end)
test('burn loss of eligibility and save pauses cannot catch up damage',function()
 local s,c,r,h=setup();local token=begin(s,c);A.confirm(s,token,10.9,c)
 A.step(s,11,.1,c);local hp=r[1].hp;local remaining=s.burn.remaining;A.pause(s,3)
 assert(r[1].hp==hp and s.burn.remaining==remaining)
 A.step(s,14,30,c);assert(hp-r[1].hp<=2.51,'stall caused a burst')
 c.blocked=true;A.step(s,14.1,.1,c);assert(not s.burn)
end)
test('cycle upgrade changes the orbital cooldown only',function()
 local s,c=setup();c.perks.orbitalCycle=true;local token=begin(s,c);A.confirm(s,token,10.9,c);assert(s.cooldowns.Orbital==40.9)
end)
test('saved cooldown hydrates without aliasing and reconnect cannot refresh a strike',function()
 local _,c=setup();local saved={Orbital=40,Scrap=60};local s=A.new(saved,c.runId)
 assert(not A.begin(s,'Orbital',10,c));assert(not A.begin(s,'Scrap',59,c));assert(A.begin(s,'Orbital',41,c))
 s.cooldowns.Orbital=80;assert(saved.Orbital==40)
 local reloaded=A.new(s.cooldowns,c.runId);assert(not A.begin(reloaded,'Orbital',42,c))
 local invalid=A.new({Orbital=0/0,Scrap=-1},c.runId);assert(next(invalid.cooldowns)==nil)
end)
test('scrap deploys four bots or six on precision for ten seconds',function()
 local s,c=setup();local token=begin(s,c,'Scrap');A.confirm(s,token,10.5,c);assert(#s.swarm.bots==4 and s.swarm.expires==20.5)
 s,c=setup();token=begin(s,c,'Scrap');A.confirm(s,token,10.9,c);assert(#s.swarm.bots==6 and s.swarm.expires==20.9)
end)
test('scrap bots must physically travel and charge before any mining hits',function()
 local s,c,r,h=setup();for _,rock in ipairs(r) do rock.x+=50 end
 local token=begin(s,c,'Scrap');A.confirm(s,token,10.5,c)
 for n=1,15 do A.step(s,10.5+n/60,1/60,c) end
 assert(#h==0)
 for n=16,550 do A.step(s,10.5+n/60,1/60,c) end
 assert(#h>0)
 for _,hit in ipairs(h) do assert(hit.origin and hit.kind=='Scrap') end
end)
test('gadget tick work is bounded and does not catch up a long frame',function()
 local s,c,_,h=setup();local token=begin(s,c,'Scrap');A.confirm(s,token,10.9,c)
 for _,bot in ipairs(s.swarm.bots) do bot.x=0;bot.y=3;bot.z=0 end
 A.step(s,11,.1,c);local before=#h;A.step(s,11.1,30,c);assert(#h-before<=6)
end)
test('scrap pairs cooperate on weak rocks and late-field chips remain capped',function()
 local s,c,r,h=setup();r[1].hp=450;r[1].maxHP=450;r[1].x=1
 r[2].hp=240;r[2].maxHP=240;r[2].x=0;r[3].hp=250;r[3].maxHP=250;r[3].x=0
 r[4].hp=800;r[4].maxHP=800;r[4].x=0
 local token=begin(s,c,'Scrap');A.confirm(s,token,10.5,c)
 for n=1,120 do A.step(s,10.5+n/60,1/60,c) end
 local counts={};for _,bot in ipairs(s.swarm.bots) do counts[bot.targetId]=(counts[bot.targetId] or 0)+1 end
 assert(counts.small==2 and counts.near==2,'four bots should pair on the two weak targets')
 assert(#h>0)
 for _,hit in ipairs(h) do assert(hit.damage>=2 and hit.damage<=8) end
 local before=r[2].hp+r[3].hp
 for n=121,540 do A.step(s,10.5+n/60,1/60,c) end
 assert(r[2].hp==0 or r[3].hp==0,'a late-field deployment should finish a paired target')
 assert(r[2].hp+r[3].hp<before)
end)
test('leaving field and expiry tear down bots; filling backpack preserves work',function()
 for _,failure in ipairs({'blocked','full','expired'}) do
  local s,c,_,h,e=setup();local token=begin(s,c,'Scrap');A.confirm(s,token,10.9,c)
  if failure=='blocked' then c.blocked=true elseif failure=='full' then c.isFull=true end
  A.step(s,failure=='expired' and 21 or 11,1/60,c)
  if failure=='full' then assert(s.swarm) else assert(not s.swarm and #h==0 and e[#e].kind=='clearScrap') end
 end
end)
test('scrap duration stays ten seconds even with a retired combo flag',function()
 local s,c,r=setup();c.perks.scrapRecycle=true;r[2].hp=1
 local token=begin(s,c,'Scrap');A.confirm(s,token,10.5,c)
 for n=1,500 do A.step(s,10.5+n/60,1/60,c) end
 assert(s.swarm and s.swarm.expires==20.5)
 A.step(s,20.6,1/60,c);assert(not s.swarm)
end)
test('run changes clear charges, swarms and runtime cooldowns',function()
 local s,c=setup();local token=begin(s,c,'Scrap');A.confirm(s,token,10.9,c);c.runId='run:2';A.step(s,11,1/60,c)
 assert(not s.swarm and not s.charge and next(s.cooldowns)==nil and s.runId=='run:2')
end)
test('view publishes complete current state without target or client mutation rights',function()
 local s,c=setup();begin(s,c);local v=A.view(s,10.2)
 assert(v.runId==c.runId and v.charge.token==s.charge.token and v.charge.sweetStart==10.7 and not v.target)
 v.charge.token='changed';assert(s.charge.token~='changed')
end)
test('storage pauses preserve charge windows and ten seconds of working swarm time',function()
 local s,c=setup();begin(s,c);local started=s.charge.started;local expires=s.charge.expires
 A.pause(s,3);assert(s.charge.started==started+3 and s.charge.expires==expires+3)
 A.confirm(s,s.charge.token,13.9,c);assert(s.cooldowns.Orbital)
 local swarmState,ctx=setup();local token=begin(swarmState,ctx,'Scrap');A.confirm(swarmState,token,10.5,ctx)
 local deadline=swarmState.swarm.expires;local cooldown=swarmState.cooldowns.Scrap
 A.pause(swarmState,4);assert(swarmState.swarm.expires==deadline+4 and swarmState.swarm.expires-swarmState.swarm.started==10 and swarmState.cooldowns.Scrap==cooldown)
end)
test('tiny miners also accelerate continuously when targets change',function()
 local s,c=setup();local token=begin(s,c,'Scrap');A.confirm(s,token,10.5,c)
 local bot=s.swarm.bots[1];local previous={x=0,y=0,z=0}
 for n=1,90 do
  A.step(s,10.5+n/60,1/60,c)
  local dx,dy,dz=(bot.vx or 0)-previous.x,(bot.vy or 0)-previous.y,(bot.vz or 0)-previous.z
  assert(math.sqrt(dx*dx+dy*dy+dz*dz)<=20/60+1e-7)
  previous={x=bot.vx,y=bot.vy,z=bot.vz}
 end
end)
print(passed..' production gadget domain checks passed; not Studio or multiplayer evidence')
