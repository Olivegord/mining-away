#!/usr/bin/env python3
"""Dig Cube geometry and digging rules, run on the real module with the Luau CLI.

Checks: every layer tiles the full square (cell areas sum to the face area),
neighbors are symmetric, layers use different cut sizes, ore appears and gets
rarer-but-richer with depth, a simulated crew never cuts under a remaining
cell, digs craters (not one-cell drill shafts, not layer by layer), wedges and
panels are well formed, and the replicated removed-set string round-trips.
Not engine QA: looks, feel and performance need Studio.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/mining-away-luau") / "luau"
module = (ROOT / "src/DigCube.lua").read_text().replace("--!strict\n", "")
test = r"""
local D=(function()
""" + module + r"""
end)()
local function check(ok,msg) if not ok then error('FAIL '..msg,2) end end
local t0=os.clock()
local cube=D.build(12345)
local buildTime=os.clock()-t0
local W=D.WIDTH
check(#cube.layers==D.LAYERS,'layer count')
local sizes={}
for L,layer in ipairs(cube.layers) do
 local area=0
 for _,id in ipairs(layer.cells) do area+=cube.cells[id].area end
 check(math.abs(area-W*W)<W*W*.002,'layer '..L..' tiles the face: '..area)
 check(#layer.cells>=40 and #layer.cells<=600,'layer '..L..' cell count '..#layer.cells)
 sizes[#sizes+1]=layer.size
end
local smallest,largest=math.huge,0
for _,s in ipairs(sizes) do smallest=math.min(smallest,s);largest=math.max(largest,s) end
check(largest/smallest>1.1,'layers use different cell sizes')
-- Chunks: cut size grows them, halves cover the chunk, outline and split line exist.
local function polyArea(poly)
 local a=0
 for k=1,#poly do local p,q=poly[k],poly[k%#poly+1];a+=p[1]*q[2]-q[1]*p[2] end
 return math.abs(a)*.5
end
local chunkRnd=D.rng(7)
local avg={}
for _,cut in ipairs({1,2}) do
 local total=0
 for i=1,30 do
  local seed=cube.layers[1].cells[i*5]
  local ids=D.chunk(cube,seed,cut,nil,chunkRnd)
  check(ids[1]~=nil and table.find(ids,seed)~=nil,'chunk holds its seed')
  for _,id in ipairs(ids) do check(cube.cells[id].layer==1,'chunk stays in one layer') end
  local area=D.chunkArea(cube,ids)
  local sp=D.split(cube,ids)
  local halves=0
  for _,poly in ipairs(sp.a) do halves+=polyArea(poly) end
  for _,poly in ipairs(sp.b) do halves+=polyArea(poly) end
  check(math.abs(halves-area)<area*.01,'halves cover the chunk')
  check(#sp.a>0 and #sp.b>0 and #sp.chords>0,'chunk splits in two along a line')
  check(#D.outline(cube,ids)>=3,'chunk outline')
  check(D.key(D.parseKey(D.key(ids)))==D.key(ids),'chunk key round trip')
  total+=area
 end
 avg[cut]=total/30
end
check(avg[2]>avg[1]*2.5,'cut size 2 breaks much bigger chunks: '..avg[1]..' vs '..avg[2])
check(D.chunkHp(cube,{1,2},2)<D.chunkHp(cube,{1,2},1),'bigger cutters cut faster per area')
-- Gem roll: some chunks hold a gem, most do not.
local gems=0
local gemRnd=D.rng(3)
for i=1,400 do
 local ids=D.chunk(cube,cube.layers[1].cells[(i%#cube.layers[1].cells)+1],1,nil,gemRnd)
 if D.gemRoll(cube,ids,gemRnd)>0 then gems+=1 end
end
check(gems>10 and gems<200,'gem chance per chunk '..gems..'/400')
-- Tiles: every top cell sits under some top tile; outer walls are covered.
local tiles,cellTiles=D.tiles(cube)
for _,id in ipairs(cube.layers[1].cells) do check(#cellTiles[id]>0,'top cell under a tile') end
for _,cell in ipairs(cube.cells) do if cell.boundary then check(#cellTiles[cell.id]>0,'wall cell under a tile') end end
for _,cell in ipairs(cube.cells) do
 for _,n in ipairs(cell.neighbors) do
  check(table.find(cube.cells[n].neighbors,cell.id)~=nil,'neighbor symmetry '..cell.id..'-'..n)
  check(cube.cells[n].layer==cell.layer,'neighbor same layer')
 end
 check(#cell.poly>=3,'polygon')
end
-- Every cell below the top has something above it; every cell below overlaps.
for _,cell in ipairs(cube.cells) do
 if cell.layer>1 then check(#D.above(cube,cell.id)>0,'cell '..cell.id..' has cells above') end
end
-- Ore: present, and deeper ore is a higher tier on average.
local shallow,deep,sc,dc,ores=0,0,0,0,0
for _,cell in ipairs(cube.cells) do
 if cell.ore>0 then
  ores+=1
  if cell.layer<=3 then shallow+=cell.ore;sc+=1 elseif cell.layer>=8 then deep+=cell.ore;dc+=1 end
 end
end
check(ores>0.05*#cube.cells and ores<0.45*#cube.cells,'ore share '..ores..'/'..#cube.cells)
check(sc>0 and dc>0 and deep/dc>shallow/sc+1,'deeper ore is richer')
-- Wedges and panels.
local wedgeCount=0
for _,id in ipairs(cube.layers[1].cells) do
 local ws=D.wedges(cube.cells[id])
 check(#ws>=2,'cell has wedges')
 for _,w in ipairs(ws) do
  check(w.size[1]>3 and w.size[2]>0 and w.size[3]>0,'wedge size')
  check(math.abs(w.right[2])>.999,'wedges extrude vertically')
 end
 wedgeCount+=#ws
end
local panels=0
for _,cell in ipairs(cube.cells) do if cell.boundary then panels+=#D.panels(cell) end end
check(panels>0,'boundary panels')
-- Simulated crew: four drones, focus on a point, 300 cuts.
local rnd=D.rng(99)
local recent={}
local claims={}
local focusX,focusZ=W*.3,W*.4
local maxLayer=1
for step=1,200 do
 local taken,points={},{}
 for _,id in ipairs(claims) do taken[id]=true;table.insert(points,{cube.cells[id].cx,cube.cells[id].cz}) end
 local id=D.pick(cube,{focusX=focusX,focusZ=focusZ,taken=taken,takenPoints=points,recent=recent,now=step,random=rnd})
 check(id~=nil,'a cell is available at step '..step)
 -- Its core is open: every cell above its middle is already gone.
 for _,a in ipairs(D.shoulders(cube,id)) do check(cube.removed[a],'core open above') end
 table.insert(claims,id);if #claims>4 then table.remove(claims,1) end
 D.remove(cube,id);recent[id]=step
 maxLayer=math.max(maxLayer,cube.cells[id].layer)
 if step==180 then focusX,focusZ=W*.75,W*.7 end
end
-- No regular cell floats: a crew cutting whole chunks leaves every cell
-- resting on rock under its middle (owner, Nov 22; only sealed gem cells may float).
do
 local dug=D.build(4242)
 local r2=D.rng(7)
 for step=1,260 do
  local id=D.pick(dug,{focusX=W*.5,focusZ=W*.5,random=r2})
  if not id then break end
  -- Every 9th chunk seals one cell (a gem), as the server does.
  local ids=D.chunk(dug,id,1+(step%3)*.5,nil,r2)
  for k,cid in ipairs(ids) do
   if step%9==0 and k==1 then dug.sealed=dug.sealed or {};dug.sealed[cid]=true else D.remove(dug,cid) end
  end
 end
 local deepest=1
 for id in pairs(dug.removed) do deepest=math.max(deepest,dug.cells[id].layer) end
 check(deepest>=3,'float check digs down: '..deepest)
 for _,cell in ipairs(dug.cells) do
  if not dug.removed[cell.id] and not (dug.sealed and dug.sealed[cell.id]) and cell.layer<#dug.layers then
   check(D.supported(dug,cell.id,0,nil),'cell '..cell.id..' (layer '..cell.layer..') does not float')
  end
 end
 -- No mushroom caps either: few remaining cells overhang mostly empty space
 -- (over half of what lies under them dug out).
 local caps,exposed=0,0
 for _,cell in ipairs(dug.cells) do
  if not dug.removed[cell.id] and not (dug.sealed and dug.sealed[cell.id]) and cell.layer<#dug.layers then
   local under=D.below(dug,cell.id)
   local gone=0
   for _,b in ipairs(under) do if dug.removed[b] then gone+=1 end end
   if gone>0 then exposed+=1 end
   if #under>0 and gone/#under>.5 then caps+=1 end
  end
 end
 check(caps<=exposed*.08,'overhanging caps: '..caps..' of '..exposed..' cells at the pit edge')
end
-- A sealed cell may float: it does not stop the cell under it being cut.
do
 local probe=D.build(777)
 local top=probe.layers[1].cells[5]
 local under=D.below(probe,top)[1]
 for _,a in ipairs(D.shoulders(probe,under)) do if a~=top then D.remove(probe,a) end end
 for _,a in ipairs(D.above(probe,under)) do if a~=top then D.remove(probe,a) end end
 check(not D.diggable(probe,under),'a regular cell above blocks the cut')
 probe.sealed={[top]=true}
 check(D.diggable(probe,under),'a sealed gem cell may float')
end
local perLayer={}
local areaLayer={}
for id in pairs(cube.removed) do local L=cube.cells[id].layer;perLayer[L]=(perLayer[L] or 0)+1;areaLayer[L]=(areaLayer[L] or 0)+cube.cells[id].area end
-- Not layer by layer: the top layer is far from cleared while deeper layers are cut.
check(maxLayer>=4,'crew digs down (deepest layer '..maxLayer..')')
check((areaLayer[1] or 0)<W*W*.7,'top layer not cleared first')
-- Not a drill: each layer opened is wider than the next one (crater walls slope).
for L=2,maxLayer do check((areaLayer[L] or 0)<=(areaLayer[L-1] or 0)+1,'crater narrows with depth at layer '..L) end
check((perLayer[2] or 0)>=3,'pit wider than one cell')
-- Visibility: every removed cell's affected neighbors are now visible or removed.
for id in pairs(cube.removed) do
 for _,other in ipairs(D.affected(cube,id)) do check(cube.removed[other] or D.visible(cube,other),'exposed cell visible') end
end
-- Encode/decode.
local s=D.encode(cube)
local set=D.decode(cube,s)
local n=0;for id in pairs(set) do n+=1;check(cube.removed[id],'decoded id removed') end
check(n==cube.removedCount,'round trip count')
-- Deterministic.
local again=D.build(12345)
check(#again.cells==#cube.cells and again.cells[77].cx==cube.cells[77].cx,'deterministic')
local counts={}
for L=1,#cube.layers do counts[#counts+1]=string.format('%d%%',math.floor(100*(areaLayer[L] or 0)/(W*W))) end
-- Drone chunk sizes: tiny to huge, bigger chunks drop more rock.
local tinyN,hugeN=0,0
for i=1,20 do
 local seed=cube.layers[1].cells[i*3]
 tinyN+=D.rockDrops(D.volume(cube,D.chunk(cube,seed,D.CHUNK_SIZES.tiny,nil,chunkRnd)))
 hugeN+=D.rockDrops(D.volume(cube,D.chunk(cube,seed,D.CHUNK_SIZES.huge,nil,chunkRnd)))
end
check(hugeN>tinyN*2.5,'huge chunks drop more rock: '..hugeN..' vs '..tinyN)
local sizes={}
for slot=1,4 do sizes[D.chunkSize('Striker','x',slot)]=true end
check(sizes.tiny and sizes.medium and sizes.large and sizes.huge,'starter drones span chunk sizes')
check(D.chunkSize('Charger','x')=='huge' and D.chunkSize('Needler','x')=='tiny','typed drones keep their size')
-- Carving wedges overlap and cover each cell (area of wedge footprints >= cell area).
for _,id in ipairs({1,50,300}) do
 local ws=D.prismWedges(cube,{id})
 local a=0
 for _,w in ipairs(ws) do a+=w.size[2]*w.size[3]*.5 end
 check(a>=cube.cells[id].area,'carve wedges cover cell '..id)
end
print(string.format('PASS chunks: %.0f sq studs at cut 1, %.0f at cut 2; %d/400 chunks hold a gem',avg[1],avg[2],gems))
print(string.format('PASS dig cube: %d layers, %d cells (top %d cells, %d wedges), %d boundary panels, %d ore cells; build %.2fs',
 #cube.layers,#cube.cells,#cube.layers[1].cells,wedgeCount,panels,ores,buildTime))
print('PASS crater digging, share of each layer cut, top to bottom: '..table.concat(counts,' ')..' (core always open above, narrows with depth)')
"""
with tempfile.TemporaryDirectory() as folder:
    path = Path(folder) / "dig_cube_test.luau"
    path.write_text(test)
    result = subprocess.run([str(luau), str(path)], capture_output=True, text=True)
    print(result.stdout, end="")
    if result.returncode != 0 or "FAIL" in result.stdout + result.stderr:
        print(result.stderr, end="")
        sys.exit(1)
print("PASS DigCube module with the Luau CLI (no Roblox APIs). Looks, feel and performance NOT VERIFIED.")
