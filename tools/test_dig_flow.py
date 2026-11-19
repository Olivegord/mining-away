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
assert(holder:GetAttribute('Tessellation')==DigCube.DEFAULT_TESSELLATION,'tessellation replicates')
local pl=player(4813)
players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local W=DigCube.WIDTH
local top=dig.origin+Vector3.new(W*.3,dig.cube.height+3,W*.3)
pl.Character:PivotTo(CFrame.new(top))
tick(10)
assert(p.digging,'standing on the cube puts the crew to work')
local mining,opSeen=false,false
local kinds={}
for _=1,400 do
 tick(10)
 for _,d in ipairs(p.drones) do
  if d.model:GetAttribute('DigMining')==true then mining=true end
  local key=d.model:GetAttribute('DigOp')
  if type(key)=='string' and key~='' then opSeen=true;assert(DigCube.decodeOp(key),'drone op decodes: '..key);kinds[string.sub(key,1,1)]=true end
 end
 if #dig.ops>=8 then break end
end
assert(mining,'a drone publishes a dig beam')
assert(opSeen,'drones publish the cut they are making')
assert(#dig.ops>=8,'the crew makes cuts, got '..#dig.ops)
local kindCount=0;for _ in pairs(kinds) do kindCount+=1 end
assert(kindCount>=2,'different drones make different cuts')
tick(10)
-- Replication: a fresh cube replaying the published ops matches the server.
local count=holder:GetAttribute('OpCount')
assert(count>=8 and count<=#dig.ops,'op count replicates: '..tostring(count))
local replay=DigCube.build(holder:GetAttribute('Seed'),holder:GetAttribute('Tessellation'))
local n=0
for i=1,math.ceil(count/64) do
 for entry in string.gmatch(holder:GetAttribute('Ops'..i),'[^;]+') do
  n+=1;DigCube.apply(replay,DigCube.decodeOp(entry))
 end
end
assert(n==count,'every op is published')
local server=DigCube.build(holder:GetAttribute('Seed'),holder:GetAttribute('Tessellation'))
for i=1,count do DigCube.apply(server,DigCube.decodeOp(dig.ops[i])) end
assert(math.abs(replay.removedVolume-server.removedVolume)<1e-6,'replicated ops match the server op list')
local all=DigCube.build(holder:GetAttribute('Seed'),holder:GetAttribute('Tessellation'))
for _,op in ipairs(dig.ops) do DigCube.apply(all,DigCube.decodeOp(op)) end
assert(math.abs(all.removedVolume-dig.cube.removedVolume)<1e-6,'replaying the server op list rebuilds the server rock')
-- Cuts near the player went first.
local near,total=0,0
for id in pairs(dig.cube.touched) do
 total+=1
 local c=dig.cube.cells[id]
 if (c.cx-W*.3)^2+(c.cz-W*.3)^2<24*24 then near+=1 end
end
assert(near>=total*.7,'crew digs around the player: '..near..'/'..total)
-- A gem waits for the reveal pause, then drops owned by the player.
local pickups=root:FindFirstChild('OrePickups')
local held={at=now+DigCube.PAUSE,p=p,owner=pl.UserId,tier=2,volume=400,position=dig.origin+Vector3.new(30,40,30),floor=dig.origin.Y+38}
table.insert(dig.pending,held)
local spawned=0
local real=scene.digGem
scene.digGem=function(...) local args={...};if args[5]==held.position then spawned+=1 end;return real(...) end
tick(1)
assert(spawned==0 and table.find(dig.pending,held),'gem held during the pause')
local before=#pickups:GetChildren()
tick(math.ceil(DigCube.PAUSE/C.Tick)+2)
scene.digGem=real
assert(spawned==1 and not table.find(dig.pending,held),'gem appears at the reveal')
local gem
for _,c in ipairs(pickups:GetChildren()) do if c:GetAttribute('Owner')==pl.UserId and c:GetAttribute('RareGemReward')==true then gem=c end end
assert(gem,'gem belongs to the player')
-- A bigger cut stat plans bigger cuts.
local d1=p.drones[1]
local function avg(cut)
 d1.stats.cutSize=cut
 local v=0
 for _=1,8 do local job=scene.digPick(d1,p);d1.digJob=job;v+=DigCube.preview(dig.cube,job.op);scene.digDrop(d1) end
 return v/8
end
local small,big=avg(1),avg(2)
d1.stats.cutSize=1
assert(big>small*1.8,'cut size 2 plans bigger cuts: '..big..' vs '..small)
-- Tap the far corner: the crew's next cuts move there.
local corner=dig.origin+Vector3.new(W*.85,dig.cube.height,W*.85)
p.tokens=10;p.bucketAt=now
command.OnServerEvent:Fire(pl,'DigFocus',{point=corner})
assert(p.digFocus==corner,'tap sets the focus')
local seen={};for id in pairs(dig.cube.touched) do seen[id]=true end
local opsBefore=#dig.ops
for _=1,500 do tick(10);if #dig.ops>=opsBefore+6 then break end end
local moved,fresh=0,0
for id in pairs(dig.cube.touched) do
 if not seen[id] then
  fresh+=1
  local c=dig.cube.cells[id]
  if (c.cx-W*.85)^2+(c.cz-W*.85)^2<26*26 then moved+=1 end
 end
end
assert(fresh>=3 and moved>=fresh*.7,'tap moves the crew: '..moved..'/'..fresh)
p.tokens=10;p.bucketAt=now
command.OnServerEvent:Fire(pl,'DigFocus',{point=Vector3.new(0,5,0)})
assert(p.digFocus==corner,'tap outside the cube ignored')
-- Walk away: the crew is released.
pl.Character:PivotTo(CFrame.new(Vector3.new(0,6,10)))
tick(10)
assert(not p.digging,'leaving the cube ends digging')
for _,d in ipairs(p.drones) do assert(d.digJob==nil,'drone released') end
-- A spent cube starts over.
for _,c in ipairs(dig.cube.cells) do DigCube.apply(dig.cube,{kind='c',cells={c.id}}) end
dig.checkAt=0
tick(5)
tick(math.ceil(5/C.Tick))
assert(holder:GetAttribute('Generation')==2 and dig.cube.removedVolume==0 and holder:GetAttribute('OpCount')==0,'a dug-out cube is replaced')
print('PASS dig cube server: crew cuts around the player with several cutter shapes, ops replicate and replay to the same rock, gems wait for the reveal, cut size grows cuts, tap moves the crater, leaving releases, spent cube resets (API doubles; looks, feel and multiplayer NOT verified)')
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
