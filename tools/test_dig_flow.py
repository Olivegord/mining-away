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
local pl=player(4813)
players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local W=DigCube.WIDTH
local top=dig.origin+Vector3.new(W*.3,dig.cube.height+3,W*.3)
pl.Character:PivotTo(CFrame.new(top))
tick(10)
assert(p.digging,'standing on the cube puts the crew to work')
local mining=false
local chunkSeen=false
for _=1,300 do
 tick(10)
 for _,d in ipairs(p.drones) do
  if d.model:GetAttribute('DigMining')==true then mining=true end
  local key=d.model:GetAttribute('DigChunk')
  if type(key)=='string' and key~='' then chunkSeen=true;assert(#DigCube.parseKey(key)>=1,'chunk key lists cells') end
 end
 if dig.cube.removedCount>=6 then break end
end
assert(mining,'a drone publishes a dig beam')
assert(chunkSeen,'drones publish the chunk they cut')
local breaks=holder:GetAttribute('Breaks')
assert(type(breaks)=='string' and string.match(breaks,'^%d+:%d+:[%d%.]+'),'breaks replicate: '..tostring(breaks))
assert(dig.cube.removedCount>=6,'the crew breaks cells, got '..dig.cube.removedCount)
tick(10)
local encoded=holder:GetAttribute('Removed')
local count=0;for _ in pairs(DigCube.decode(dig.cube,encoded)) do count+=1 end
assert(count==dig.cube.removedCount,'removed set replicates: '..count..' vs '..dig.cube.removedCount)
-- Cells near the player went first.
local near=0
for id in pairs(dig.cube.removed) do
 local c=dig.cube.cells[id]
 if (c.cx-W*.3)^2+(c.cz-W*.3)^2<22*22 then near+=1 end
end
assert(near>=dig.cube.removedCount*.7,'crew digs around the player: '..near..'/'..dig.cube.removedCount)
-- An ore cell drops a gem owned by the player.
local ore
for _,c in ipairs(dig.cube.cells) do if c.ore>0 then ore=c;break end end
assert(ore,'cube has ore')
local pickups=root:FindFirstChild('OrePickups')
local before=#pickups:GetChildren()
scene.digGem(p,pl.UserId,{ore.id},ore.ore,ore.cx,ore.cz)
local after=pickups:GetChildren()
assert(#after==before+1,'ore cell drops a gem')
local gem=after[#after]
assert(gem:GetAttribute('Owner')==pl.UserId and gem:GetAttribute('RareGemReward')==true,'gem belongs to the player')
-- A winning roll waits for the reveal pause before the gem appears.
local held={at=now+DigCube.PAUSE,p=p,owner=pl.UserId,ids={ore.id},tier=2,cx=ore.cx,cz=ore.cz}
table.insert(dig.pending,held)
local spawned=0
local real=scene.digGem
scene.digGem=function(...) local args={...};if args[3]==held.ids then spawned+=1 end;return real(...) end
tick(1)
assert(spawned==0 and table.find(dig.pending,held),'gem held during the pause')
tick(math.ceil(DigCube.PAUSE/C.Tick)+2)
scene.digGem=real
assert(spawned==1 and not table.find(dig.pending,held),'gem appears at the reveal')
-- A bigger cut stat takes bigger chunks.
local d1=p.drones[1]
local small=scene.digPick(d1,p);scene.digDrop(d1)
d1.stats.cutSize=2
local sizes=0
for _=1,10 do local c=scene.digPick(d1,p);d1.digChunk=c;sizes+=#c.ids;scene.digDrop(d1) end
d1.stats.cutSize=1
assert(sizes/10>#small.ids+1,'cut size 2 picks bigger chunks: '..(sizes/10)..' vs '..#small.ids)
-- Tap the far corner: the crew's next cuts move there.
local corner=dig.origin+Vector3.new(W*.85,dig.cube.height,W*.85)
p.tokens=10;p.bucketAt=now
command.OnServerEvent:Fire(pl,'DigFocus',{point=corner})
assert(p.digFocus==corner,'tap sets the focus')
local seen={}
for id in pairs(dig.cube.removed) do seen[id]=true end
for _=1,400 do tick(10);if dig.cube.removedCount>=count+8 then break end end
local moved,total=0,0
for id in pairs(dig.cube.removed) do
 if not seen[id] then
  total+=1
  local c=dig.cube.cells[id]
  if (c.cx-W*.85)^2+(c.cz-W*.85)^2<24*24 then moved+=1 end
 end
end
assert(total>=3 and moved>=total*.7,'tap moves the crew: '..moved..'/'..total)
-- A tap outside the cube is ignored.
p.tokens=10;p.bucketAt=now
command.OnServerEvent:Fire(pl,'DigFocus',{point=Vector3.new(0,5,0)})
assert(p.digFocus==corner,'tap outside the cube ignored')
-- Walk away: the crew is released.
pl.Character:PivotTo(CFrame.new(Vector3.new(0,6,10)))
tick(10)
assert(not p.digging,'leaving the cube ends digging')
for _,d in ipairs(p.drones) do assert(d.digCell==nil,'drone released') end
-- A spent cube starts over.
for _,c in ipairs(dig.cube.cells) do DigCube.remove(dig.cube,c.id) end
dig.checkAt=0
tick(5)
tick(math.ceil(5/C.Tick))
assert(holder:GetAttribute('Generation')==2 and dig.cube.removedCount==0,'a dug-out cube is replaced')
print('PASS dig cube server: crew digs around the player, removed cells replicate, chunks and breaks replicate, gems wait for the reveal, cut size grows chunks, tap moves the crater, leaving releases, spent cube resets (API doubles; looks, feel and multiplayer NOT verified)')
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
