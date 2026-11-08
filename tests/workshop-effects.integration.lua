-- Exercise production worker ticks/secondary contacts, not just modifier arithmetic.
local uid=410000
local function fixture(card,level)
 uid+=1;local pl=player(uid);players.PlayerAdded:Fire(pl);local p=profiles[uid];local f=patches[1]
 for _,r in ipairs(f.resources) do r.hp=0;r.paid=true end
 if card then local entry=Workshop.BY_ID[card];local c=Workshop.card(entry,entry.tier);c.level=level or 1;c.effects=Workshop.effects(c,c.level);data(p).run.cards={c};refreshStats(p) end
 pl.Character:PivotTo(CFrame.new(f.center+Vector3.new(0,3,0)))
 return pl,p,p.drones[1],f
end
local function rock(f,x,hp)
 local r=makeResource(f,f.center+Vector3.new(x or 0,0,0),'Crystal',hp or 205,10,3);r.readyAt=now;return r
end
local function assign(d,r)
 release(d);d.target=r;d.targetSlot=1;d.field=r.field.id;r.slots[d.id]=1;d.pos=Feel.mineGoal(r.position,1,false,r.fullSize)
end
local function step(p)
 realTime+=C.Tick;now=realTime
 for _,d in ipairs(p.drones) do droneStep(d,C.Tick) end
 pickupStep(C.Tick)
end
local function jobTime(card,level)
 local pl,p,d,f=fixture(card,level);local r=rock(f,0);assign(d,r);local began=now
 for _=1,2000 do step(p);if r.paid then break end end
 assert(r.paid,'job did not finish')
 local duration=now-began;players.PlayerRemoving:Fire(pl);return duration
end
local baseline=jobTime()
local power1,power2=jobTime('Q_POWER',1),jobTime('Q_POWER',2)
local ignition1,ignition2=jobTime('Q_IGNITION',1),jobTime('Q_IGNITION',2)
assert(power1<baseline*.9 and power2<power1*.94)
assert(ignition1<baseline*.9 and ignition2<ignition1*.97)
print(string.format('PRODUCTION work from arrival: base %.3fs, power L1 %.3fs L2 %.3fs, ignition L1 %.3fs L2 %.3fs',baseline,power1,power2,ignition1,ignition2))
for _,tier in ipairs({1,4}) do
 local pl,p,d,f=fixture('Q_SPLIT',tier);local a,b=rock(f,0,1000),rock(f,8,1000);assign(d,a)
 local before=b.hp;assert(hitResource(d,a,30,false));local delta=before-b.hp
 assert(math.abs(delta-30*.1*tier)<1e-6,'stack count did not reach actual fork damage')
 assert(a.hp==960 and b.hp==990-delta,'fork damage recursed')
 print(string.format('PRODUCTION Prism stacks %d: %.1f secondary damage per 30 primary hit',tier,delta))
 players.PlayerRemoving:Fire(pl)
end
for _,tier in ipairs({1,4}) do
 local pl,p,d,f=fixture('Q_YIELD',tier);local a=rock(f,0);assign(d,a)
 assert(hitResource(d,a,1000,false));assert(pendingOre(p)==math.floor(10*(1+.25*tier)))
 local b=rock(f,18);assign(d,b);assert(hitResource(d,b,1000,false));assert(pendingOre(p)==20*(1+.25*tier),'fractional ore lost between rocks')
 print(string.format('PRODUCTION Polisher stacks %d: %.1f ore per two 10-ore rocks',tier,pendingOre(p)))
 players.PlayerRemoving:Fire(pl)
end
local pl,p,d,f=fixture('Q_SCANNER',1);local a,b=rock(f,0),rock(f,9)
command.OnServerEvent:Fire(pl,'MineOre',a.id)
for _=1,3000 do step(p);if b.paid then break end end
assert(a.paid and b.paid,'Route Runner failed to retarget without a second click')
players.PlayerRemoving:Fire(pl)
print('PASS production Route Runner mines a second ready rock without another command')

local overdrive=jobTime('Q_OVERDRIVE',1)
assert(overdrive<power1 and overdrive<ignition1,'Legendary Overdrive was not meaningfully stronger than a basic pick')
print(string.format('PRODUCTION Legendary Overdrive 1x: %.3fs vs baseline %.3fs',overdrive,baseline))
local lp,lprof,ld,lf=fixture('Q_PRISM_CORE',1);local primary,secondary=rock(lf,0,1000),rock(lf,8,1000);assign(ld,primary)
local before=secondary.hp;assert(hitResource(ld,primary,30,false));assert(math.abs(before-secondary.hp-6)<1e-6)
assert(ld.stats.yieldMultiplier==1.25);players.PlayerRemoving:Fire(lp)
print('PASS Legendary Prismatic Core applies 20% real nearby damage plus 25% yield in one copy')
local ap,aprofile,ad,af=fixture('Q_AUTONOMOUS',1);local first,second=rock(af,0),rock(af,9)
assert(Ca.capacity(data(aprofile))==60 and ad.stats.speedMultiplier==1.75)
command.OnServerEvent:Fire(ap,'MineOre',first.id)
for _=1,3000 do step(aprofile);if second.paid then break end end
assert(first.paid and second.paid);players.PlayerRemoving:Fire(ap)
print('PASS Legendary Autonomous Fleet retargets, flies 75% faster and carries 60 in one copy')
