#!/usr/bin/env python3
"""The chunked dig field (owner, Nov 23: "the entire map is now a dig cube ...
only spawning chunks when they are needed"), run on the real DigCube module
and the real server bundle with Roblox API doubles.

Checks:
  * determinism: a chunk's seed comes from the world seed, its grid
    coordinates and its generation; building it twice, or spread over frames
    with a yield, gives the same cells; neighbors differ; strata (layer
    heights) and color line up across chunk borders; chunk (0,0) is the
    Plot 1 cube; chunksNear/chunkAt agree
  * load/unload: only the pinned Plot 1 chunk exists at start; a player out
    on the field loads the chunks near them (holder Seed = the client's
    seed), a chunk renders only when a crew starts on it (64 rock columns,
    a floor, walls toward unrendered neighbors), the ground plates are cut
    around rendered chunks with no gap and no overlap, untouched chunks are
    dropped when everyone leaves, dug ones grow back after HEAL_AFTER and
    the original plates come back
  * cross-chunk cuts: a crew at a chunk border digs on both sides; every
    chunk's published ops replay (parseOp/applyOp on a client-built cube) to
    exactly that chunk's server removed set; each drone's DigChunk names its
    job's chunk; the wall between two rendered chunks goes and the columns at
    the border split into layers; the hub never loads a chunk
  * performance (API doubles, Luau CLI interpreter, CSG stubbed): server
    heartbeat time and dig-step time with four crews digging in four chunks,
    part counts (rock, walls, floors, ground pieces) and chunk build times.
Not engine QA: looks, seams in the real ground texture, CSG cost, client
frame time and real multiplayer need a Studio Play check.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from build import ROOT, bundle

luau = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/mining-away-luau") / "luau"

# ---------- Part 1: the DigCube module alone ----------
module = (ROOT / "src/DigCube.lua").read_text().replace("--!strict\n", "")
pure = r"""
local D=(function()
""" + module + r"""
end)()
local function check(ok,msg) if not ok then error('FAIL '..msg,2) end end
local function fingerprint(cube)
 local h=0
 for _,c in ipairs(cube.cells) do
  h=(h*31+math.floor(c.cx*1000)+math.floor(c.cz*7000)+c.layer*13+#c.poly)%2147483647
 end
 return h..':'..#cube.cells
end
local WS=918273645
-- Chunk (0,0) is the Plot 1 cube (D.CENTER), so the old pit and plot ring line up.
local x0,z0=D.chunkCorner(0,0)
check(x0==D.CENTER[1]-D.WIDTH/2 and z0==D.CENTER[3]-D.WIDTH/2,'chunk (0,0) is the Plot 1 cube')
check(D.chunkKey(-3,12)=='-3_12','chunk key')
local pi,pj=D.parseChunkKey('-3_12');check(pi==-3 and pj==12,'chunk key parses')
for _,p in ipairs({{0,0},{-1,0},{5,-7},{-12,3}}) do
 local cx,cz=D.chunkCorner(p[1],p[2])
 local i,j=D.chunkAt(cx+1,cz+D.WIDTH-1)
 check(i==p[1] and j==p[2],'chunkAt inverts chunkCorner')
end
local near=D.chunksNear(D.CENTER[1],D.CENTER[3],D.WIDTH*.5+1)
check(#near==5 and near[1][1]==0 and near[1][2]==0 and near[1][3]==0,'chunksNear: the chunk itself first, then its 4 side neighbours: '..#near)
check(#D.chunksNear(D.CENTER[1],D.CENTER[3],D.WIDTH*.5*math.sqrt(2)+1)==9,'and the diagonals once the radius reaches them')
check(#D.chunksNear(D.CENTER[1],D.CENTER[3],10)==1,'a point deep inside one chunk is near only it')
-- Seeds: deterministic, distinct per coordinates and generation.
local seen={}
for i=-3,3 do for j=-3,3 do
 local s=D.chunkSeed(WS,i,j,1)
 check(s==D.chunkSeed(WS,i,j,1),'seed is deterministic')
 check(not seen[s],'distinct seeds per chunk');seen[s]=true
end end
check(D.chunkSeed(WS,1,1,1)~=D.chunkSeed(WS,1,1,2),'a new generation is a new seed')
check(D.chunkSeed(WS,1,1,1)~=D.chunkSeed(WS+1,1,1,1),'a new world seed is a new seed')
check(D.chunkSeed(WS,1,2,1)~=D.chunkSeed(WS,2,1,1),'(i,j) and (j,i) differ')
-- Same chunk built twice, and spread over "frames" with a yield: identical.
local t0=os.clock()
local a=D.buildChunk(WS,2,-1,1)
local buildTime=os.clock()-t0
local yields=0
local b=D.buildChunk(WS,2,-1,1,function() yields+=1 end)
check(fingerprint(a)==fingerprint(b) and a.seed==b.seed,'a chunk is identical built twice (server and client)')
check(yields>=D.LAYERS*3,'the build yields between steps: '..yields)
for id,c in ipairs(a.cells) do
 local o=b.cells[id]
 check(o.layer==c.layer and #o.poly==#c.poly and o.hp==c.hp and o.ore==c.ore,'cell '..id..' matches')
 for k,v in ipairs(c.poly) do check(o.poly[k][1]==v[1] and o.poly[k][2]==v[2],'cell '..id..' vertex '..k) end
end
local c=D.buildChunk(WS,3,-1,1)
check(fingerprint(c)~=fingerprint(a),'neighbouring chunks differ')
-- Strata line up across borders: every chunk has the same layer heights.
for L=1,D.LAYERS do
 check(math.abs(a.layers[L].y0-c.layers[L].y0)<1e-9 and math.abs(a.layers[L].y1-c.layers[L].y1)<1e-9,'layer '..L..' heights match across chunks')
end
check(math.abs(a.layers[1].y1-D.HEIGHT)<1e-9,'the top meets the ground')
-- Color runs on across a border (world-space noise, one field seed).
local worst=0
for L=1,D.LAYERS,3 do
 for z=1,87,9 do
  local ca=D.layerColor(a,L,D.WIDTH,z)
  local cc=D.layerColor(c,L,0,z)
  for k=1,3 do worst=math.max(worst,math.abs(ca[k]-cc[k])) end
 end
end
check(worst<1e-6,'layer color is continuous across the border: '..worst)
-- The single-cube API is unchanged: D.build(seed) still builds the old cube.
local old=D.build(12345)
check(old.offsetX==0 and old.colorSeed==12345,'D.build(seed) keeps its own color seed')
-- pick returns its total weight (for the cross-chunk draw).
local id,total=D.pick(a,{random=function() return .5 end})
check(id~=nil and total>0,'pick returns the total weight')
collectgarbage('collect')
local mem0=collectgarbage('count')
local keep={}
for i=1,4 do keep[i]=D.buildChunk(WS,i,5,1) end
collectgarbage('collect')
local perChunk=(collectgarbage('count')-mem0)/4
print(string.format('PASS chunk determinism: seeds from world seed + coords + generation, identical builds (also yielded), aligned strata and colors; one chunk %d cells, build %.2f s in the Luau CLI (%d yields), about %.1f MB of Lua per built chunk',
 #a.cells,buildTime,yields,perChunk/1024))
"""
with tempfile.TemporaryDirectory(prefix="dig-field-pure-") as directory:
    path = Path(directory) / "pure.lua"
    path.write_text(pure)
    subprocess.run([str(luau), str(path)], check=True)

# ---------- Part 2: the server bundle ----------
crew_test = (ROOT / "tools/test_crew_loop.py").read_text()
fixture = re.search(r'fixture = """(.*?)"""', crew_test, re.S).group(1)
# The real map's ground: Fields.Baseplate west of x=96 and Map.PlotPit's four
# plates around the Plot 1 hole (tools/studio_flat_plots.lua), top at 3.8.
ground = r"""
do
 local root=workspace.MiningAway
 local base=fixturePart(root.Fields,'Baseplate',Vector3.new((-1024+96)/2,3.3,0),Vector3.new(96+1024,1,2048))
 local pit=Instance.new('Folder');pit.Name='PlotPit';pit.Parent=root.Map
 local x0,x1,z0,z1=116,204,-44,44
 fixturePart(pit,'GroundWest',Vector3.new((96+x0)/2,3.3,0),Vector3.new(x0-96,1,2048))
 fixturePart(pit,'GroundEast',Vector3.new((x1+1024)/2,3.3,0),Vector3.new(1024-x1,1,2048))
 fixturePart(pit,'GroundNorth',Vector3.new(160,3.3,(z1+1024)/2),Vector3.new(88,1,1024-z1))
 fixturePart(pit,'GroundSouth',Vector3.new(160,3.3,(z0-1024)/2),Vector3.new(88,1,1024+z0))
 fixturePart(pit,'ShaftNorth',Vector3.new(160,-18,z1+1),Vector3.new(92,42,2))
 fixturePart(pit,'ShaftFloor',Vector3.new(160,-41,0),Vector3.new(92,2,92))
end
"""
checks = r"""
local function tick(n) for _=1,n do realTime+=C.Tick;heartbeat:Fire(C.Tick) end end
local DigCube=Config.DigCube
local FIELD=DigCube.FIELD
local F=scene.digField
local W=DigCube.WIDTH
function IM:SubtractAsync(negatives)
 local p=Instance.new('Part');p.Size=self.Size;p.CFrame=self.CFrame
 return p
end
local function parsed(entry) local op=DigCube.parseOp(entry);assert(op,'op parses: '..tostring(entry));return op end
local function holderOps(holder)
 local list={}
 local count=holder:GetAttribute('OpCount') or 0
 for i=1,math.ceil(count/64) do for entry in string.gmatch(holder:GetAttribute('Ops'..i) or '','[^;]+') do table.insert(list,entry) end end
 assert(#list==count,'every published op is in an Ops attribute: '..#list..'/'..count)
 return list
end
local function chunk(i,j) return F.chunks[DigCube.chunkKey(i,j)] end
local function center(i,j) local x,z=DigCube.chunkCorner(i,j);return Vector3.new(x+W/2,DigCube.GROUND+3,z+W/2) end
local function loaded() local n=0;for _ in pairs(F.chunks) do n+=1 end;return n end
local function rendered() local n=0;for _,ch in pairs(F.chunks) do if ch.rendered then n+=1 end end;return n end
-- Ground plates: pieces tile each plate minus the rendered squares exactly.
local function checkGround(label)
 local squares={}
 for _,ch in pairs(F.chunks) do if ch.rendered then table.insert(squares,{ch.origin.X,ch.origin.Z,ch.origin.X+W,ch.origin.Z+W}) end end
 local pieces=0
 for _,pl in ipairs(F.ground.plates) do
  local want=(pl.hi.X-pl.lo.X)*(pl.hi.Y-pl.lo.Y)
  for _,s in ipairs(squares) do
   local ox=math.max(0,math.min(pl.hi.X,s[3])-math.max(pl.lo.X,s[1]))
   local oz=math.max(0,math.min(pl.hi.Y,s[4])-math.max(pl.lo.Y,s[2]))
   want-=ox*oz
  end
  local area=0
  for k,piece in ipairs(pl.pieces) do
   pieces+=1
   assert(piece.part.Parent==pl.parent,label..': a ground piece is in the map')
   local part=piece.part
   assert(math.abs(part.Position.Y-pl.y)<1e-6 and math.abs(part.Size.Y-pl.thick)<1e-6,label..': pieces keep the plate height (top at '..DigCube.GROUND..')')
   assert(math.abs(part.Size.X-(piece.hi.X-piece.lo.X))<1e-6 and math.abs(part.Size.Z-(piece.hi.Y-piece.lo.Y))<1e-6,label..': piece size')
   area+=(piece.hi.X-piece.lo.X)*(piece.hi.Y-piece.lo.Y)
   for _,s in ipairs(squares) do
    local ox=math.min(piece.hi.X,s[3])-math.max(piece.lo.X,s[1])
    local oz=math.min(piece.hi.Y,s[4])-math.max(piece.lo.Y,s[2])
    assert(not (ox>1e-6 and oz>1e-6),label..': no ground over a rendered chunk')
   end
   for m=k+1,#pl.pieces do
    local q=pl.pieces[m]
    local ox=math.min(piece.hi.X,q.hi.X)-math.max(piece.lo.X,q.lo.X)
    local oz=math.min(piece.hi.Y,q.hi.Y)-math.max(piece.lo.Y,q.lo.Y)
    assert(not (ox>1e-6 and oz>1e-6),label..': ground pieces never overlap')
   end
  end
  assert(math.abs(area-want)<1e-3,label..': the pieces cover the plate except rendered chunks: '..area..' vs '..want)
 end
 return pieces
end
-- Replaying a chunk's published ops on a cube the client builds gives the server's removed set.
local function replayMatches(ch,label)
 ch.publishAt=0;scene.digFlushOps()
 local replay=DigCube.buildChunk(root.DigField:GetAttribute('WorldSeed'),ch.i,ch.j,ch.holder:GetAttribute('Generation'))
 assert(replay.seed==ch.holder:GetAttribute('Seed'),label..': the client builds the server seed')
 for _,entry in ipairs(holderOps(ch.holder)) do DigCube.applyOp(replay,parsed(entry)) end
 assert(replay.removedCount==ch.cube.removedCount,label..': replayed '..replay.removedCount..' vs server '..ch.cube.removedCount)
 for id=1,#ch.cube.cells do assert((replay.removed[id]==true)==(ch.cube.removed[id]==true),label..': cell '..id..' differs') end
end

-- ===== Start: only the pinned Plot 1 chunk =====
assert(root:FindFirstChild('DigField') and type(root.DigField:GetAttribute('WorldSeed'))=='number','the field replicates its world seed')
assert(loaded()==1 and chunk(0,0) and chunk(0,0).rendered and chunk(0,0)==scene.dig,'at start only the pinned Plot 1 chunk exists, rendered')
assert(#F.ground.plates==5,'five ground plates (Fields.Baseplate and PlotPit Ground*)')
local startPieces=checkGround('start')
assert(startPieces==5,'nothing is cut while only Plot 1 (already a hole in the plates) is rendered')
assert(not workspace.MiningAway.Map.PlotPit:FindFirstChild('ShaftNorth'),'the old shaft walls are replaced by per-chunk walls')
assert(chunk(0,0).floor and chunk(0,0).floor.Parent==chunk(0,0).holder,'Plot 1 has its floor')
assert(not scene.digBlocked(-1,0) and not scene.digBlocked(0,0) and not scene.digBlocked(2,0),'only chunks off the field are blocked whole (mine anywhere)')
assert(scene.digBlocked(40,0),'off the field is blocked')
assert(scene.digInBlocked(0,0,4) and not scene.digInBlocked(100,0,0),'the hub (and only it) is never dug')
-- Loaded chunks look like the ground they replace: the top layer takes the plate's look.
assert(root.DigField:GetAttribute('TopColor')==root.Fields.Baseplate.Color,'the field publishes the ground color for the top layer')
for _,blk in ipairs(chunk(0,0).blocks) do
 assert(blk.part.Color==root.Fields.Baseplate.Color and blk.part.Material==root.Fields.Baseplate.Material,'untouched rock tops look like the ground plate')
end

-- ===== Load: a player out on the field =====
local function crew(p,roles)
 local keep={}
 for _,owned in ipairs(roleTestFleet(p,nil,roles)) do table.insert(keep,owned) end
 p.testFleet=keep;rebuildFleet(p)
end
local pl=player(5101);players.PlayerAdded:Fire(pl);local p=profiles[pl.UserId]
crew(p,{'Striker','Charger','Lancer','Needler'})
pl.Character:PivotTo(CFrame.new(center(2,0)))
tick(30)
local ch=chunk(2,0)
assert(ch and ch.ready and ch.holder.Parent==root.DigField,'the chunk under the player loads and replicates')
assert(ch.holder:GetAttribute('Seed')==DigCube.chunkSeed(root.DigField:GetAttribute('WorldSeed'),2,0,1),'its seed is the world seed + coordinates')
assert(ch.holder:GetAttribute('Origin')==Vector3.new(DigCube.chunkCorner(2,0)) or (ch.holder:GetAttribute('Origin')-ch.origin).Magnitude<1e-6,'origin replicates')
assert(not chunk(1,0) and not chunk(3,0),'chunks beyond FIELD.LOAD do not load')
assert(p.digging,'standing on the field puts the crew to work')
for _=1,600 do tick(5);if #ch.ops>=6 then break end end
assert(ch.rendered,'a chunk renders when its first job starts')
assert(#ch.ops>=6,'the crew breaks rock in the new chunk: '..#ch.ops)
local columns,layered=0,0
for _,b in ipairs(ch.blocks) do if b.column then columns+=1 else layered+=1 end end
assert(columns>0 and columns<64 and layered>0,'untouched tiles stay columns, cut ones split into layers: '..columns..' columns, '..layered..' blocks')
local skirts=0;for _ in pairs(ch.skirts) do skirts+=1 end
assert(skirts==4 and ch.floor,'walls toward its 4 unrendered neighbours and a floor')
checkGround('one chunk out on the field')
for _,d in ipairs(p.drones) do
 if d.digJob then assert(d.model:GetAttribute('DigChunk')==d.digJob.ch.key,'a drone publishes its job chunk (DigChunk)') end
end
replayMatches(ch,'chunk 2_0')
-- The reported bug: at Plot 1's west edge, toward the hub, the crew must dig
-- past the edge (chunk -1_0 reaches the hub: only the cells under it stay).
do
 local edge=player(5106);players.PlayerAdded:Fire(edge);local pe=profiles[edge.UserId]
 crew(pe,{'Striker','Striker','Needler','Lancer'})
 local ex,ez=DigCube.chunkCorner(0,0)
 edge.Character:PivotTo(CFrame.new(Vector3.new(ex-2,DigCube.GROUND+3,ez+W/2)))
 local west
 for _=1,900 do tick(5);west=chunk(-1,0);if west and #west.ops>=3 then break end end
 assert(west and #west.ops>=3,'a crew at the edge of Plot 1 digs past it, toward the hub: '..(west and #west.ops or 0))
 assert(west.fixedCount and west.fixedCount>0,'the cells under the hub are fixed')
 for id in pairs(west.cube.fixed) do assert(not west.cube.removed[id],'a fixed cell under the hub is never removed') end
 for id in pairs(west.cube.removed) do
  local c=west.cube.cells[id]
  assert(not scene.digInBlocked(west.origin.X+c.cx,west.origin.Z+c.cz,0),'nothing is dug inside the hub')
 end
 edge.Character:PivotTo(CFrame.new(Vector3.new(0,6,0)))
 print(string.format('PASS edge: at Plot 1\'s west edge the crew cut %d ops in chunk -1_0 toward the hub; %d cells under the hub stay fixed',#west.ops,west.fixedCount))
end
print(string.format('PASS load: only Plot 1 at start; the player\'s chunk loads (seed from world seed + coords), renders on its first job (%d columns + %d layer blocks, 4 walls, floor), ground cut with no gap or overlap; ops replay',columns,layered))

-- ===== Cross-chunk: a crew at a border digs both sides =====
local pl2=player(5102);players.PlayerAdded:Fire(pl2);local p2=profiles[pl2.UserId]
crew(p2,{'Striker','Striker','Needler','Lancer'})
local bx,bz=DigCube.chunkCorner(5,3)
local border=Vector3.new(bx,DigCube.GROUND+3,bz+W/2) -- between chunks (4,3) and (5,3)
pl2.Character:PivotTo(CFrame.new(border))
local a,b
for _=1,900 do
 tick(5)
 a,b=chunk(4,3),chunk(5,3)
 if a and b and #a.ops>=3 and #b.ops>=3 then break end
end
assert(a and b,'both chunks at the border load')
assert(#a.ops>=3 and #b.ops>=3,'the crew cuts on both sides of the border: '..#a.ops..' and '..#b.ops)
assert(a.rendered and b.rendered,'both render')
assert(not a.skirts[1] and not b.skirts[2],'no wall between two rendered chunks')
assert(a.skirts[2] and b.skirts[1],'walls stay toward unrendered ground')
-- The columns along the shared edge show their layers once the other side is cut.
local split=0
for _,blk in ipairs(a.blocks) do if not blk.column and blk.hi.X>=W-1e-6 then split+=1 end end
for _,blk in ipairs(b.blocks) do if not blk.column and blk.lo.X<=1e-6 then split+=1 end end
assert(split>0,'border columns split into layers')
replayMatches(a,'chunk 4_3');replayMatches(b,'chunk 5_3')
for _,d in ipairs(p2.drones) do
 if d.digJob then assert(d.model:GetAttribute('DigChunk')==d.digJob.ch.key,'DigChunk names the job chunk') end
end
checkGround('two neighbours at a border')
print(string.format('PASS cross-chunk: a crew at the 4_3|5_3 border cut %d and %d ops on either side, both replay exactly, no wall between, %d border blocks show their layers',#a.ops,#b.ops,split))

-- ===== Performance: four crews in four chunks =====
local pl3=player(5103);players.PlayerAdded:Fire(pl3);local p3=profiles[pl3.UserId]
crew(p3,{'Striker','Charger','Ballcaster','Frostbite'})
pl3.Character:PivotTo(CFrame.new(center(-4,3)))
local pl4=player(5104);players.PlayerAdded:Fire(pl4);local p4=profiles[pl4.UserId]
crew(p4,{'Striker','Lancer','Needler','Charger'})
pl4.Character:PivotTo(CFrame.new(center(0,0)+Vector3.new(10,0,-12)))
tick(120)
local times={}
-- Real time (the doubles' os.clock is game time): the dig step and chunk builds.
local stepTime,builds,buildTimes=0,0,{}
local realStep=scene.digStep
scene.digStep=function(...) local t=REAL_CLOCK();realStep(...);stepTime+=REAL_CLOCK()-t end
local realBuild=DigCube.buildChunk
DigCube.buildChunk=function(...) local t=REAL_CLOCK();local cube=realBuild(...);table.insert(buildTimes,REAL_CLOCK()-t);return cube end
local opsBefore=0;for _,c in pairs(F.chunks) do opsBefore+=#c.ops end
local N=1800
-- A fifth player walks across open field (16 studs/s) the whole time, so
-- chunks load, build and drop while the crews work.
local walker=player(5105);players.PlayerAdded:Fire(walker)
local walkFrom=Vector3.new(300,DigCube.GROUND+3,500)
walker.Character:PivotTo(CFrame.new(walkFrom))
local loadsBefore,dropsBefore=F.perf.loads,F.perf.drops
local peak=0
for k=1,N do
 walker.Character:PivotTo(CFrame.new(walkFrom+Vector3.new(16*C.Tick*k,0,0)))
 local t0=REAL_CLOCK()
 realTime+=C.Tick;heartbeat:Fire(C.Tick)
 times[k]=REAL_CLOCK()-t0
 peak=math.max(peak,loaded())
end
walker.Character:PivotTo(CFrame.new(Vector3.new(0,6,0)))
scene.digStep=realStep;DigCube.buildChunk=realBuild
local ops=-opsBefore;for _,c in pairs(F.chunks) do ops+=#c.ops end
table.sort(times)
local sum=0;for _,t in ipairs(times) do sum+=t end
local stepMean=stepTime/N
local stepNoBuild=0
local buildSum,buildMax=0,0;for _,t in ipairs(buildTimes) do buildSum+=t;buildMax=math.max(buildMax,t) end
stepNoBuild=(stepTime-buildSum)/N
local rock,walls,floors,blocks=0,0,0,0
for _,c in pairs(F.chunks) do
 if c.rendered then
  blocks+=#c.blocks
  for _,blk in ipairs(c.blocks) do if blk.part.Parent then rock+=1 end end
  for _ in pairs(c.skirts or {}) do walls+=1 end
  if c.floor then floors+=1 end
 end
end
local groundPieces=checkGround('four crews')
local working=0
for _,q in ipairs({p,p2,p3,p4}) do for _,d in ipairs(q.drones) do if d.digJob then working+=1 end end end
assert(rendered()>=5,'five rendered chunks with four crews: '..rendered())
assert(ops>0,'the crews keep breaking rock')
print(string.format('PERF four crews (16 drones, %d working) in %d loaded / %d rendered chunks, %d s of play: heartbeat mean %.2f ms, p50 %.2f ms, p95 %.2f ms, max %.2f ms (max includes a whole chunk build in one tick); dig field step %.3f ms/tick, %.3f without builds; %d break ops',
 working,loaded(),rendered(),math.floor(N*C.Tick),sum/N*1000,times[math.ceil(N*.5)]*1000,times[math.ceil(N*.95)]*1000,times[N]*1000,stepMean*1000,stepNoBuild*1000,ops))
print(string.format('PERF chunks: the walker crossed %d studs; %d chunks loaded and %d dropped in the window, at most %d loaded at once (about %.0f MB of chunk data at %.1f MB each)',
 math.floor(16*C.Tick*N),F.perf.loads-loadsBefore,F.perf.drops-dropsBefore,peak,peak*13.4,13.4))
print(string.format('PERF parts: %d rock blocks in %d rendered chunks (fully layered would be %d each), %d walls, %d floors, %d ground pieces; %d chunk builds in the window, mean %.2f s, max %.2f s of CPU (Luau CLI; here a build runs inside one tick, the game spreads it at 4 ms a frame)',
 rock,rendered(),64*DigCube.LAYERS,walls,floors,groundPieces,#buildTimes,buildSum/math.max(1,#buildTimes),buildMax))

-- ===== Unload: everyone back to the hub =====
FIELD.HEAL_AFTER=30;FIELD.HEAL_MIN=12
-- (Off the field: chunks at the hub's edge now load and dig too, so the hub is no empty spot.)
local OFF=Vector3.new(1500,6,1500)
for _,q in pairs(profiles) do q.player.Character:PivotTo(CFrame.new(OFF)) end
tick(math.ceil((FIELD.DROP_AFTER+2)/C.Tick))
for _,c in pairs(F.chunks) do assert(c.pinned or c.rendered,'untouched chunks drop when nobody is near: '..c.key) end
assert(rendered()>=5,'dug chunks stay a while')
tick(math.ceil((FIELD.HEAL_AFTER+2)/C.Tick))
assert(loaded()==1 and chunk(0,0),'dug chunks nobody came back to grow back; Plot 1 stays: '..loaded())
assert(not root.DigField:FindFirstChild('C2_0'),'a dropped chunk\'s holder goes')
local back=checkGround('after the field grew back')
for _,pl in ipairs(F.ground.plates) do
 assert(#pl.pieces==1 and pl.pieces[1].part==pl.template and pl.template.Parent==pl.parent,'each original plate is back in place')
end
assert(chunk(0,0).skirts[1] and chunk(0,0).skirts[2] and chunk(0,0).skirts[3] and chunk(0,0).skirts[4],'Plot 1 walls itself off again')
assert(not p.digging,'off the field nobody digs')
-- Coming back regrows the same chunk (same seed: generation starts over).
pl.Character:PivotTo(CFrame.new(center(2,0)))
tick(30)
assert(chunk(2,0) and chunk(2,0).holder:GetAttribute('Seed')==DigCube.chunkSeed(root.DigField:GetAttribute('WorldSeed'),2,0,1),'a regrown chunk is the same rock')
-- Memory cap: past MAX_CHUNKS the longest-idle chunks go first.
do
 local cap=FIELD.MAX_CHUNKS
 FIELD.MAX_CHUNKS=3
 for k=1,5 do pl.Character:PivotTo(CFrame.new(center(2,4+k)));tick(math.ceil(3/C.Tick)) end
 assert(loaded()<=4,'the field never keeps more than MAX_CHUNKS (+ the one just entered): '..loaded())
 assert(chunk(0,0),'the pinned chunk is never dropped by the cap')
 FIELD.MAX_CHUNKS=cap
end
print(string.format('PASS unload: untouched chunks drop after %ds, dug ones grow back after HEAL_AFTER, the original ground plates return (%d pieces) (API doubles: looks, ground texture seams and real multiplayer NOT verified)',FIELD.DROP_AFTER,back))
"""
source = "\n".join([
    "local REAL_CLOCK=os.clock -- the doubles replace os.clock with game time",
    (ROOT / "tests/mock-roblox.lua").read_text(),
    (ROOT / "tests/gadget-server.setup.lua").read_text(),
    fixture, ground, bundle(), ";(function()\n" + checks + "\nend)()",
])
with tempfile.TemporaryDirectory(prefix="dig-field-") as directory:
    path = Path(directory) / "checks.lua"
    path.write_text(source)
    subprocess.run([str(luau), str(path)], check=True)
