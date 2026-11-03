-- Production automatic charge/work logic; no Roblox renderer or network claims.
local A=require('../src/DroneAbilities')
local passed=0
local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS gadget '..name) end
local function setup()
 local rocks={{id='big',hp=100,maxHP=100,x=0,y=0,z=0},{id='small',hp=20,maxHP=50,x=4,y=0,z=0},{id='near',hp=30,maxHP=60,x=7,y=0,z=0},{id='far',hp=30,maxHP=70,x=100,y=0,z=0}}
 local hits,events={},{}
 local ctx={runId='run:1',fieldId=1,origin={x=0,y=3,z=0},perks={},denied=false,blocked=false,isFull=false}
 ctx.unlocked=function() return not ctx.denied end
 ctx.valid=function(id) return not ctx.blocked and id==1 end
 ctx.targets=function() local out={};for _,r in ipairs(rocks) do if r.hp>0 then table.insert(out,table.clone(r)) end end;return out end
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
local function begin(s,c,kind,t) assert(A.begin(s,kind or 'Orbital',t or 10,c));return s.charge.token end
local function deploy(s,c,kind,t)
 t=t or 10;begin(s,c,kind,t);A.step(s,t+A.CHARGE_SECONDS,.001,c);assert(not s.charge)
 return t+A.CHARGE_SECONDS
end
local function burn(s,c,start,seconds) for n=1,math.ceil((seconds or 4.1)*60) do A.step(s,start+n/60,1/60,c) end end

test('unknown gadgets invalid clocks unlock and eligibility fail closed without damage',function()
 local s,c,_,h=setup();c.denied=true;assert(not A.begin(s,'Orbital',10,c));c.denied=false
 assert(not A.begin(s,'Fake',10,c) and not A.begin(s,'Orbital',0/0,c));c.blocked=true
 assert(not A.begin(s,'Orbital',10,c) and not s.charge and #h==0)
end)
test('largest eligible target has a stable ID tie break',function()
 local s,c,r=setup();r[4].maxHP=100;r[4].id='aaa';begin(s,c);assert(s.charge.targetId=='aaa')
end)
test('one activation completes its fixed anticipation without a second input or timing window',function()
 local s,c,r,h=setup();begin(s,c);s.charge.actorId='orbiter:one'
 A.step(s,11.39,.01,c);assert(s.charge and not s.burn and #h==0)
 A.step(s,11.4,.01,c);assert(not s.charge and s.burn and s.burn.actorId=='orbiter:one')
 assert(#h==1 and r[1].hp<100)
 local v=A.view(s,11.4);assert(not v.charge)
end)
test('charge view has no token or precision targets and cannot mutate authority',function()
 local s,c=setup();begin(s,c);local v=A.view(s,10.2)
 assert(v.charge.readyAt==11.4 and not v.charge.token and not v.charge.sweetStart and not v.target)
 v.charge.started=0;assert(s.charge.started==10)
end)
test('early forged and replayed confirm cannot accelerate or repeat work',function()
 local s,c,_,h=setup();local token=begin(s,c)
 assert(not A.confirm(s,token,10.9,c) and not A.confirm(s,'spoof',11.4,c));assert(#h==0 and s.charge)
 assert(A.confirm(s,token,11.4,c));A.step(s,11.5,.1,c);assert(#h==1)
 assert(not A.confirm(s,token,12,c) and #h==1)
end)
test('lost target canceled eligibility and expired charge do not spend cooldown',function()
 for _,failure in ipairs({'target','blocked','expired'}) do
  local s,c,r,h=setup();local token=begin(s,c)
  if failure=='target' then r[1].hp=0 elseif failure=='blocked' then c.blocked=true end
  assert(not A.confirm(s,token,failure=='expired' and 12.6 or 11.4,c))
  assert(not s.charge and not s.cooldowns.Orbital and #h==0)
 end
end)
test('four seconds of accepted orbital work melts one biggest rock',function()
 local s,c,r,h=setup();local token=begin(s,c);assert(A.confirm(s,token,11.4,c));assert(#h==0)
 burn(s,c,11.4,2);assert(r[1].hp>45 and r[1].hp<55 and #h==120 and s.burn)
 burn(s,c,13.4,2.1);assert(r[1].hp<1e-6 and not s.burn)
 for _,hit in ipairs(h) do assert(hit.id=='big' and hit.damage<1 and hit.origin.y==34) end
 assert(s.cooldowns.Orbital==56.4 and not A.begin(s,'Orbital',15,c))
end)
test('player timing no longer grants neighboring hits or bonus bots',function()
 for _,time in ipairs({11.4,11.8,12.2}) do
  local s,c,_,h=setup();local token=begin(s,c);A.confirm(s,token,time,c);burn(s,c,time,4.1)
  for _,hit in ipairs(h) do assert(hit.kind~='OrbitalRelay') end
  s,c=setup();token=begin(s,c,'Scrap');A.confirm(s,token,time,c);assert(#s.swarm.bots==4)
 end
end)
test('equipment upgrades alter actual cooldown and bot count',function()
 local s,c=setup();c.perks.orbitalCycle=true;deploy(s,c);assert(s.cooldowns.Orbital==41.4)
 s,c=setup();c.perks.scrapBots=2;deploy(s,c,'Scrap');assert(#s.swarm.bots==6)
end)
test('saved cooldown hydrating and reconnect cannot refresh a strike',function()
 local _,c=setup();local saved={Orbital=40,Scrap=60};local s=A.new(saved,c.runId)
 assert(not A.begin(s,'Orbital',10,c) and not A.begin(s,'Scrap',59,c) and A.begin(s,'Orbital',41,c))
 s.cooldowns.Orbital=80;assert(saved.Orbital==40)
 local reloaded=A.new(s.cooldowns,c.runId);assert(not A.begin(reloaded,'Orbital',42,c))
 assert(next(A.new({Orbital=0/0,Scrap=-1},c.runId).cooldowns)==nil)
end)
test('full backpack permits burn while lost eligibility cancels it',function()
 local s,c,r,h=setup();c.isFull=true;local start=deploy(s,c);assert(s.burn and #h==1)
 local hp=r[1].hp;A.step(s,start+.1,.1,c);assert(r[1].hp<hp)
 c.blocked=true;A.step(s,start+.2,.1,c);assert(not s.burn)
end)
test('first blocked orbital contact refunds cooldown',function()
 local s,c=setup();c.hit=function() return false end;deploy(s,c);assert(not s.burn and s.cooldowns.Orbital<=11.4)
end)
test('storage pause preserves charge anticipation and remaining work without catch-up damage',function()
 local s,c,r=setup();begin(s,c);A.pause(s,3);assert(s.charge.readyAt==14.4 and s.charge.started==13)
 A.step(s,14.3,.1,c);assert(s.charge);A.step(s,14.4,.1,c);assert(s.burn)
 local hp=r[1].hp;local remaining=s.burn.remaining;A.pause(s,3)
 assert(r[1].hp==hp and s.burn.remaining==remaining)
 A.step(s,17.4,30,c);assert(hp-r[1].hp<=2.51)
end)
test('scrap auto deployment preserves hardware actor and lasts ten seconds',function()
 local s,c=setup();begin(s,c,'Scrap');s.charge.actorId='scrapper:one';A.step(s,11.4,.001,c)
 assert(s.swarm.actorId=='scrapper:one' and #s.swarm.bots==4 and s.swarm.expires==21.4)
 A.step(s,21.4,.1,c);assert(not s.swarm)
end)
test('mini miners must travel and charge before mining; per-step contacts are bounded',function()
 local s,c,r,h=setup();for _,rock in ipairs(r) do rock.x+=50 end
 local start=deploy(s,c,'Scrap');for n=1,15 do A.step(s,start+n/60,1/60,c) end;assert(#h==0)
 for n=16,550 do A.step(s,start+n/60,1/60,c) end;assert(#h>0)
 for _,hit in ipairs(h) do assert(hit.origin and hit.kind=='Scrap') end
 local before=#h;A.step(s,start+9.3,30,c);assert(#h-before<=6)
end)
test('mini miners pair on weaker rocks and cap late-field chip work',function()
 local s,c,r,h=setup();r[1].hp=450;r[1].maxHP=450;r[1].x=1
 r[2].hp=240;r[2].maxHP=240;r[2].x=0;r[3].hp=250;r[3].maxHP=250;r[3].x=0;r[4].hp=800;r[4].maxHP=800;r[4].x=0
 local start=deploy(s,c,'Scrap');for n=1,120 do A.step(s,start+n/60,1/60,c) end
 local counts={};for _,bot in ipairs(s.swarm.bots) do counts[bot.targetId]=(counts[bot.targetId] or 0)+1 end
 assert(counts.small==2 and counts.near==2 and #h>0)
 for _,hit in ipairs(h) do assert(hit.damage>=2 and hit.damage<=8) end
 for n=121,540 do A.step(s,start+n/60,1/60,c) end
 assert(r[2].hp==0 or r[3].hp==0)
end)
test('swarm movement accelerates continuously instead of snapping on target changes',function()
 local s,c=setup();local start=deploy(s,c,'Scrap');local bot=s.swarm.bots[1];local previous={x=bot.vx or 0,y=bot.vy or 0,z=bot.vz or 0}
 for n=1,90 do A.step(s,start+n/60,1/60,c)
  local dx,dy,dz=(bot.vx or 0)-previous.x,(bot.vy or 0)-previous.y,(bot.vz or 0)-previous.z
  assert(math.sqrt(dx*dx+dy*dy+dz*dz)<=20/60+1e-7);previous={x=bot.vx,y=bot.vy,z=bot.vz}
 end
end)
test('swarm eligibility expiry run changes and save pauses preserve correct lifetime',function()
 local s,c=setup();local start=deploy(s,c,'Scrap');local deadline=s.swarm.expires;local cooldown=s.cooldowns.Scrap
 A.pause(s,4);assert(s.swarm.expires==deadline+4 and math.abs(s.swarm.expires-s.swarm.started-10)<1e-7 and s.cooldowns.Scrap==cooldown)
 c.blocked=true;A.step(s,start+5,.1,c);assert(not s.swarm)
 s,c=setup();deploy(s,c,'Scrap');c.runId='run:2';A.step(s,12,.1,c)
 assert(not s.swarm and not s.charge and not next(s.cooldowns) and s.runId=='run:2')
end)
print(passed..' production automatic gadget domain checks passed; not Studio or multiplayer evidence')
