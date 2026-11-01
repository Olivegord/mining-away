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
  if ctx.blocked or ctx.isFull then return false end
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
test('full backpack cannot start or fire a gadget',function()
 local s,c,_,h=setup();c.isFull=true;assert(not A.begin(s,'Orbital',10,c));c.isFull=false;local token=begin(s,c);c.isFull=true
 assert(not A.confirm(s,token,10.9,c));assert(#h==0 and not s.charge and not s.cooldowns.Orbital)
end)
test('largest grown eligible crystal is selected with stable ID tie break',function()
 local s,c,r=setup();r[4].maxHP=100;r[4].id='aaa';begin(s,c);assert(s.charge.targetId=='aaa')
end)
test('server timing rejects premature and expired input without spending cooldown',function()
 local s,c,_,h=setup();local token=begin(s,c);assert(not A.confirm(s,token,10.01,c));assert(s.charge)
 assert(not A.confirm(s,token,12.6,c));assert(not s.charge and not s.cooldowns.Orbital and #h==0)
end)
test('unrecognized/replayed tokens cannot fire twice',function()
 local s,c,_,h=setup();local token=begin(s,c);assert(not A.confirm(s,'spoof',10.9,c));assert(A.confirm(s,token,10.5,c));assert(#h==1)
 assert(not A.confirm(s,token,11,c));assert(#h==1)
end)
test('ordinary orbital vaporizes one biggest rock and starts cooldown',function()
 local s,c,r,h=setup();local token=begin(s,c);assert(A.confirm(s,token,10.5,c));assert(r[1].hp==0 and #h==1 and h[1].id=='big')
 assert(h[1].origin.y==34 and s.cooldowns.Orbital==55.5);assert(not A.begin(s,'Orbital',11,c))
end)
test('precision strike has one intrinsic neighbor fracture and ignores retired combo perks',function()
 local s,c,_,h=setup();local token=begin(s,c);assert(A.confirm(s,token,10.9,c));assert(#h==2)
 s,c,_,h=setup();c.perks.orbitalRelay=true;token=begin(s,c);assert(A.confirm(s,token,10.9,c));assert(#h==2)
 for _,hit in ipairs(h) do assert(hit.id~='far') end
end)
test('lost original target or blocked authoritative contact refunds cooldown',function()
 local s,c,r,h=setup();local token=begin(s,c);r[1].hp=0;assert(not A.confirm(s,token,10.9,c));assert(not s.cooldowns.Orbital and #h==0)
 s,c=setup();token=begin(s,c);c.hit=function() return false end;assert(not A.confirm(s,token,10.9,c));assert(s.cooldowns.Orbital<=10.9)
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
test('leaving field, filling backpack and expiry tear down bots without further damage',function()
 for _,failure in ipairs({'blocked','full','expired'}) do
  local s,c,_,h,e=setup();local token=begin(s,c,'Scrap');A.confirm(s,token,10.9,c)
  if failure=='blocked' then c.blocked=true elseif failure=='full' then c.isFull=true end
  A.step(s,failure=='expired' and 21 or 11,1/60,c)
  assert(not s.swarm and #h==0 and e[#e].kind=='clearScrap')
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
print(passed..' production gadget domain checks passed; not Studio or multiplayer evidence')
