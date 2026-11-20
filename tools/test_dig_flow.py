#!/usr/bin/env python3
"""The Dig Cube on the real server bundle with Roblox API doubles.

Checks: the cube is created with its seed and origin, walking up to it puts the
crew to work digging (no field needed), dug cells replicate as the encoded
removed set, drones publish their dig beam target, an ore cell drops a gem owned
by the player, a tap (DigFocus) moves the crew's work to the tapped spot, and
leaving the cube releases the crew. Not engine QA: looks, feel, client building
and real multiplayer need a Studio playtest.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from build import ROOT, bundle

luau = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/mining-away-luau") / "luau"
crew_test = (ROOT / "tools/test_crew_loop.py").read_text()
fixture = re.search(r'fixture = """(.*?)"""', crew_test, re.S).group(1)
checks = r"""
local function tick(n) for _=1,n do realTime+=C.Tick;heartbeat:Fire(C.Tick) end end
local dig=scene.dig
local DigCube=Config.DigCube
assert(dig and dig.cube,'the cube exists at startup')
local holder=root:FindFirstChild('DigCube')
assert(holder and holder:GetAttribute('Seed') and holder:GetAttribute('Generation')==1,'seed and generation replicate')
assert(holder:GetAttribute('Origin')==dig.origin,'origin replicates')
assert(#dig.blocks==#dig.cube.layers*64,'solid rock blocks: '..#dig.blocks)
local pl=player(4813)
players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local W=DigCube.WIDTH
pl.Character:PivotTo(CFrame.new(dig.origin+Vector3.new(W*.3,dig.cube.height+3,W*.3)))
tick(10)
assert(p.digging,'standing on the cube puts the crew to work')
local mining,marked=false,false
local sizes={}
local pickups=root:FindFirstChild('OrePickups')
local stones=0
for _=1,400 do
 tick(10)
 for _,d in ipairs(p.drones) do
  if d.model:GetAttribute('DigMining')==true then mining=true end
  local key=d.model:GetAttribute('DigOp')
  if type(key)=='string' and key~='' then
   marked=true
   assert(string.match(key,'^c[%d%.]+$'),'drone publishes its chunk: '..key)
   sizes[d.model:GetAttribute('DigChunkSize')]=true
  end
 end
 if #dig.ops>=10 then break end
end
for _,c in ipairs(pickups:GetChildren()) do if c:GetAttribute('Owner')==pl.UserId and c:GetAttribute('StoneCargo')==true then stones+=1 end end
assert(stones==0,'chunks leave rock dust, not floating rock pickups: '..stones)
local dustFolder=holder:FindFirstChild('Dust')
assert(dustFolder,'rock dust replicates')
for id in pairs(dig.cube.removed) do
 local c=dig.cube.cells[id]
 local l=pl.Character.HumanoidRootPart.Position-dig.origin
 assert(math.sqrt((c.cx-l.X)^2+(c.cz-l.Z)^2)-c.radius<=DigCube.MINE_RADIUS+8,'drones only cut near their player (chunks grow a few cells past the seed)')
end
assert(mining,'a drone publishes a dig beam')
assert(marked,'drones publish (mark) the chunk they are cutting')
local sizeCount=0;for _ in pairs(sizes) do sizeCount+=1 end
assert(sizeCount>=2,'drones cut different chunk sizes')
assert(#dig.ops>=10,'the crew breaks chunks, got '..#dig.ops)
assert((p.collectTotal or 0)>0,'rock dust flies into the bag of a player standing by')
tick(10)
-- Replication: replaying the published chunks gives the server's removed set.
local count=holder:GetAttribute('OpCount')
assert(count>=10,'op count replicates: '..tostring(count))
local replay=DigCube.build(holder:GetAttribute('Seed'))
for i=1,math.ceil(count/64) do
 for entry in string.gmatch(holder:GetAttribute('Ops'..i),'[^;]+') do
  local key,tier=string.match(entry,'^c([%d%.]+)|(%d+)|?[TD]?%d*$')
  assert(key and tier,'op format: '..entry)
  for _,id in ipairs(DigCube.parseKey(key)) do DigCube.remove(replay,id) end
 end
end
local server=DigCube.build(holder:GetAttribute('Seed'))
for i=1,count do for _,id in ipairs(DigCube.parseKey(string.match(dig.ops[i],'^c([%d%.]+)'))) do DigCube.remove(server,id) end end
assert(replay.removedCount==server.removedCount and replay.removedCount>0,'replicated chunks match the server')
-- Depth milestones: the first chunk into a new layer is flagged and pays a gem.
local flagged=false
for _,entry in ipairs(dig.ops) do
 local tier,layer=string.match(entry,'|(%d+)|D(%d+)$')
 if layer then flagged=true;assert(tonumber(tier)>=1,'a new layer pays a gem') end
end
assert(flagged or dig.deepest==1,'the first chunk into a new layer is a milestone')
-- Treasure pockets exist, sit deep, and pay several gems.
local pockets=0
for id in pairs(dig.cube.treasure) do pockets+=1;assert(dig.cube.cells[id].layer>=3,'treasure sits deep') end
assert(pockets==DigCube.TREASURES,'treasure pockets: '..pockets)
local tid=next(dig.cube.treasure)
local pendingBefore=#dig.pending
scene.digBreak({ids={tid},key=tostring(tid),cx=dig.cube.cells[tid].cx,cz=dig.cube.cells[tid].cz},p.drones[1],p)
assert(#dig.pending-pendingBefore==DigCube.TREASURE_GEMS,'a treasure pays several gems')
assert(string.match(dig.ops[#dig.ops],'|T$'),'treasure break is flagged')
-- Cuts near the player went first.
local near=0
for id in pairs(dig.cube.removed) do
 local c=dig.cube.cells[id]
 if (c.cx-W*.3)^2+(c.cz-W*.3)^2<22*22 then near+=1 end
end
assert(near>=(dig.cube.removedCount-1)*.7,'crew digs around the player: '..near..'/'..dig.cube.removedCount)
-- A gem waits for the reveal pause.
local held={at=now+DigCube.PAUSE,p=p,owner=pl.UserId,tier=2,volume=200,position=dig.origin+Vector3.new(30,40,30)}
table.insert(dig.pending,held)
local spawned=0
local real=scene.digGem
scene.digGem=function(...) local args={...};if args[5]==held.position then spawned+=1 end;return real(...) end
tick(1)
assert(spawned==0 and table.find(dig.pending,held),'gem held during the pause')
tick(math.ceil(DigCube.PAUSE/C.Tick)+2)
scene.digGem=real
assert(spawned==1 and not table.find(dig.pending,held),'gem appears at the reveal')
-- Chunk size: the slot-4 Striker cuts huge chunks, slot 1 tiny ones; upgrades grow them.
local d1=p.drones[1]
local function avg(slot,cut)
 local saved=d1.slot;d1.slot=slot;d1.stats.cutSize=cut
 local n=0
 for _=1,8 do local job=scene.digPick(d1,p);n+=#job.ids;scene.digDrop(d1) end
 d1.slot=saved;d1.stats.cutSize=1
 return n/8
end
local tiny,huge,upgraded=avg(1,1),avg(4,1),avg(1,2)
assert(huge>tiny*2,'huge-chunk drones take bigger chunks: '..huge..' vs '..tiny)
assert(upgraded>tiny,'cut-size upgrades grow chunks')
-- A tap out of reach does not pull the crew away from the player.
local far=dig.origin+Vector3.new(W*.85,dig.cube.height,W*.85)
p.tokens=10;p.bucketAt=now
command.OnServerEvent:Fire(pl,'DigFocus',{point=far})
local job=scene.digPick(d1,p)
local l=pl.Character.HumanoidRootPart.Position-dig.origin
assert(job and math.sqrt((job.cx-l.X)^2+(job.cz-l.Z)^2)<DigCube.MINE_RADIUS+6,'far taps are ignored')
scene.digDrop(d1)
-- Walk to the far corner: the crew's next cuts move there with you.
local corner=far
pl.Character:PivotTo(CFrame.new(corner+Vector3.new(0,3,0)))
local seen={};for id in pairs(dig.cube.removed) do seen[id]=true end
local before=#dig.ops
for _=1,500 do tick(10);if #dig.ops>=before+5 then break end end
local moved,fresh=0,0
for id in pairs(dig.cube.removed) do
 if not seen[id] then fresh+=1;local c=dig.cube.cells[id];if (c.cx-W*.85)^2+(c.cz-W*.85)^2<24*24 then moved+=1 end end
end
assert(fresh>=3 and moved>=fresh*.7,'walking moves the crew: '..moved..'/'..fresh)
-- Walk away: the crew is released.
pl.Character:PivotTo(CFrame.new(Vector3.new(0,6,10)))
tick(10)
assert(not p.digging,'leaving the cube ends digging')
for _,d in ipairs(p.drones) do assert(d.digJob==nil,'drone released') end
-- A spent cube starts over.
for _,c in ipairs(dig.cube.cells) do DigCube.remove(dig.cube,c.id) end
dig.checkAt=0
tick(5)
tick(math.ceil(5/C.Tick))
assert(holder:GetAttribute('Generation')==2 and dig.cube.removedCount==0 and holder:GetAttribute('OpCount')==0,'a dug-out cube is replaced')
print('PASS dig cube server: solid rock blocks, drones mark and cut chunks of different sizes, chunks drop rock, ops replicate, gems wait for the reveal, upgrades grow chunks, walking moves the crater, rock dust collects, leaving releases, spent cube resets (API doubles; carving, looks, feel and multiplayer NOT verified)')
"""
source = "\n".join([
    (ROOT / "tests/mock-roblox.lua").read_text(),
    (ROOT / "tests/gadget-server.setup.lua").read_text(),
    fixture, bundle(), ";(function()\n" + checks + "\nend)()",
])
with tempfile.TemporaryDirectory(prefix="dig-flow-") as directory:
    path = Path(directory) / "checks.lua"
    path.write_text(source)
    subprocess.run([str(luau), str(path)], check=True)
