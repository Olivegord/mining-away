#!/usr/bin/env python3
"""Dig Cube geometry and digging rules, run on the real module with the Luau CLI.

Checks: every layer tiles the full square (cell areas sum to the face area),
neighbors are symmetric, layers use different cut sizes, ore appears and gets
rarer-but-richer with depth, a simulated crew never cuts under a remaining
cell, digs craters (not one-cell drill shafts, not layer by layer), wedges and
panels are well formed, and the replicated removed-set string round-trips.

Dig roles (spec 7.1): STYLES holds exactly the 14 workers with unique codes;
the op grammar v2 round-trips and removes the right cells; replaying ops
equals removing the cells directly; pieces 'none' is one whole-cell piece,
'terrace' is unchanged (geometry fingerprint) and every part names its cell;
secret per-cell gems have the planned density, do not favour cell size, and
treasure holds 3 rich gems; gem size bounds; clusters and lines obey their
limits and never float a cell; picks honor weights, depth power and claimed
cells (counted as gone); deeper layers break smaller chunks (DEPTH_BITE).
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
-- ===== Dig roles (spec 7.1) =====
local function set(list) local s={} for _,id in ipairs(list) do s[id]=true end return s end
local function merged(a,b) local s={} for k in pairs(a) do s[k]=true end for k in pairs(b) do s[k]=true end return s end
-- 7.1.1 STYLES: exactly the 14 workers, unique codes, the code table is the inverse, RGB colors.
local WORKERS={'Striker','Charger','Ballcaster','Needler','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator','Ramiel','Nomad','Lancer'}
do
 local KERNELS=set({'beam','shot','slam','volley','pulse'})
 local PICKS=set({'cone','small','near','wall','deep','ore'})
 local n=0
 for role,style in pairs(D.STYLES) do
  n+=1
  check(table.find(WORKERS,role)~=nil,'unexpected style '..role)
  check(style.role==role,'style knows its role: '..role)
  check(type(style.code)=='string' and string.match(style.code,'^%u$')~=nil,'one-letter code: '..role)
  check(D.STYLES_BY_CODE[style.code]==style,'code table maps back: '..role)
  check(D.style(role)==style and D.style(style.code)==style,'D.style by role and by code: '..role)
  check(#style.color==3,'color has 3 channels: '..role)
  for _,v in ipairs(style.color) do check(type(v)=='number' and v>=0 and v<=255 and v==math.floor(v),'color in 0-255: '..role) end
  check(KERNELS[style.kernel],'kernel: '..role)
  check(PICKS[style.pick],'pick: '..role)
  check(style.pieces=='terrace' or style.pieces=='none','pieces mode: '..role)
  check(style.size==nil or D.CHUNK_SIZES[style.size]~=nil or style.size=='cell' or style.size=='line' or style.size=='cluster','size: '..role)
  check(type(style.power)=='number' and style.power>0 and style.power<=1,'power: '..role)
 end
 check(n==#WORKERS,'STYLES has exactly the '..#WORKERS..' workers, got '..n)
 local codes=0
 for code,style in pairs(D.STYLES_BY_CODE) do codes+=1;check(style.code==code and D.STYLES[style.role]==style,'inverse '..code) end
 check(codes==n,'codes are unique: '..codes..' codes for '..n..' styles')
 check(D.style('Nobody')==D.STYLES.Striker and D.style(nil)==D.STYLES.Striker,'unknown roles dig like a Striker')
 check(D.STYLES.Lancer.code=='Z' and D.STYLES.Lancer.kernel=='pulse' and D.STYLES.Lancer.pulse.bite==.36,'Lancer is the pulse laser')
 check(D.STYLES.Ramiel.volley.preferOre==true and D.STYLES.Gridcutter.line.max==6 and D.STYLES.Charger.slam.dive==.2 and D.STYLES.Charger.slam.windup==1.1,'nested style tables')
end
-- 7.1.2 Op grammar v2: format/parse round trip and the cells each flag removes.
do
 local ids={12,40,41}
 local cases={
  {flag='',removes={12,40,41}},
  {flag='S',arg=2,removes={},stage=2},
  {flag='K',removes={}},
  {flag='E',arg='12.40',removes={41},except={12,40}},
  {flag='C',arg=3,removes={12,40,41},seq=3},
  {flag='G',removes={12,40,41}},
  {flag='X',removes={12,40,41}},
  {flag='T',removes={12,40,41}},
  {flag='D',arg=4,removes={12,40,41}},
 }
 for _,case in ipairs(cases) do
  for _,code in ipairs({'B',false}) do
   local c=code or nil
   local s=D.formatOp(ids,c,2,case.flag,case.arg)
   local op=D.parseOp(s)
   check(op~=nil,'op parses: '..s)
   check(D.key(op.cells)==D.key(ids) and op.code==c and op.tier==2,'cells, code, tier: '..s)
   check(op.flag==case.flag and op.arg==tostring(case.arg or ''),'flag and arg: '..s)
   check(D.key(op.removes)==D.key(case.removes),'removes: '..s..' -> '..D.key(op.removes))
   check(D.formatOp(op.cells,op.code,op.tier,op.flag,op.arg)==s,'round trip: '..s)
   check(op.staged==(case.flag=='S') and op.sealed==(case.flag=='K'),'staged/sealed: '..s)
   check(op.geode==(case.flag=='G' or case.flag=='X') and op.treasure==(case.flag=='T' or case.flag=='X'),'geode/treasure: '..s)
   check(op.stage==case.stage and op.seq==case.seq,'stage/seq: '..s)
   if case.except then
    for _,id in ipairs(case.except) do check(op.except[id]==true,'except: '..s) end
    check(op.except[41]==nil,'except only the listed cells')
   else check(op.except==nil,'no except: '..s) end
  end
 end
 check(D.formatOp({12,40,41},'B',2,'E','12.40')=='c12.40.41~B|2|E12.40','E format')
 check(D.formatOp({5},'B',0)=='c5~B|0' and D.formatOp({5},nil,3,'G')=='c5|3|G' and D.formatOp({7},'G',0,'C',1)=='c7~G|0|C1','op strings')
 check(D.formatOp({5},'N',3,'K')=='c5~N|3|K' and D.formatOp({1,2},'L',0,'S',1)=='c1.2~L|0|S1','K and S strings')
 local legacy=D.parseOp('c1.2|0|S1')
 check(legacy and legacy.code==nil and legacy.staged and legacy.stage==1 and #legacy.removes==0 and D.key(legacy.cells)=='1.2','legacy stage op')
 local opened=D.parseOp('c5|3|G')
 check(opened and opened.geode and not opened.treasure and opened.tier==3 and D.key(opened.removes)=='5','legacy geode op')
 local piece=D.parseOp('c9.10|0|P2')
 check(piece and D.key(piece.removes)=='9.10','legacy piece op removes its cells')
 check(D.parseOp('c5~B')==nil,'the DigOp attribute is not an op')
 check(D.parseOp('x5|0')==nil and D.parseOp('c5|0|Q')==nil and D.parseOp('c|0')==nil,'malformed ops are rejected')
end
-- 7.1.3 applyOp replay equals removing the expected cells directly.
local replayCube=D.build(777)
do
 local direct=D.build(777)
 local L1=replayCube.layers[1].cells
 local a,b,c,d,e,f,g,h,i,j=L1[10],L1[11],L1[12],L1[20],L1[21],L1[22],L1[30],L1[31],L1[40],L1[41]
 local ops={
  D.formatOp({a,b,c},'L',0,'S',1),
  D.formatOp({a,b,c},'L',0),
  D.formatOp({d},'B',3,'K'),
  D.formatOp({d,e,f},'P',2,'E',D.key({d})),
  D.formatOp({g},'G',0,'C',1),
  D.formatOp({h},'G',0,'C',2),
  D.formatOp({d},nil,3,'G'),
  'c'..i..'|0|S1',
  'c'..i..'|2|D3',
  'c'..j..'|0|P1',
  D.formatOp({a},'L',0),
 }
 local got={}
 for k,s in ipairs(ops) do
  local removed=k%2==0 and D.applyOp(replayCube,s) or D.applyOp(replayCube,D.parseOp(s))
  for _,id in ipairs(removed) do table.insert(got,id) end
 end
 local expected={a,b,c,e,f,g,h,d,i,j}
 check(D.key(got)==D.key(expected),'applyOp returns what it removed: '..D.key(got))
 for _,id in ipairs(expected) do D.remove(direct,id) end
 check(replayCube.removedCount==direct.removedCount and D.encode(replayCube)==D.encode(direct),'replay equals direct removal')
 for id in pairs(direct.frontier) do check(replayCube.frontier[id],'same frontier') end
 for id in pairs(replayCube.frontier) do check(direct.frontier[id],'same frontier') end
 check(#D.applyOp(replayCube,nil)==0 and #D.applyOp(replayCube,'garbage')==0,'nothing to apply')
end
-- 7.1.4 Pieces: 'none' is one final whole-cell piece; 'terrace' is unchanged; every part names its cell.
local pieceSample=D.build(12345)
do
 local TERRACE=[[
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=71903.873946
1:0.25:5:5:0:false,2:0.55:11:19:0:false,3:1:31:31:6:true=218577.238529
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=82614.074502
1:0.25:6:6:0:false,2:0.55:13:23:0:false,3:1:35:35:7:true=278142.984333
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=83113.042397
1:0.25:3:3:0:false,2:0.55:8:15:0:false,3:1:28:28:5:true=203744.137014
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=53140.846008
1:0.25:8:8:0:false,2:0.55:16:23:0:false,3:1:36:36:8:true=186496.542228
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=58283.200572
1:0.25:3:3:0:false,2:0.55:10:21:0:false,3:1:36:36:7:true=192927.204625
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=55447.882225
1:0.25:5:5:0:false,2:0.55:12:22:0:false,3:1:35:35:7:true=188097.959565
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=68218.013589
1:0.25:4:4:0:false,2:0.55:9:16:0:false,3:1:28:28:5:true=166336.547138
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=72542.788166
1:0.25:4:4:0:false,2:0.55:10:19:0:false,3:1:31:31:6:true=216497.664942
1:0.25:1:1:0:false,2:0.55:2:7:0:false,3:1:13:13:1:true=63617.690954
1:0.25:5:5:0:false,2:0.55:12:20:0:false,3:1:34:34:7:true=195470.739879
1:0.4:1:1:0:false,2:1:7:7:1:true=24171.925337]]
 -- The same id lists and fingerprint the terrace code produced before the
 -- dig-roles change (commit 769110b): its geometry must not move.
 local lists={}
 for _,L in ipairs({1,4,10}) do
  for _,k in ipairs({3,50,120}) do
   local seed=pieceSample.layers[L].cells[k]
   table.insert(lists,{seed})
   local ids={seed}
   for _,n in ipairs(pieceSample.cells[seed].neighbors) do table.insert(ids,n) end
   table.sort(ids)
   table.insert(lists,ids)
  end
 end
 for _,c in ipairs(pieceSample.cells) do if c.area<9 then table.insert(lists,{c.id});break end end
 local prints={}
 local function partsName(ids,pieces)
  local inside=set(ids)
  for _,piece in ipairs(pieces) do
   for _,list in ipairs({piece.parts,piece.shell}) do
    for _,part in ipairs(list) do check(part.cell~=nil and inside[part.cell],'every part names a cell of the chunk') end
   end
  end
 end
 for _,ids in ipairs(lists) do
  local pieces=D.pieces(pieceSample,ids)
  partsName(ids,pieces)
  local again=D.pieces(pieceSample,ids,'terrace')
  check(#again==#pieces,'terrace is the default')
  local area=D.chunkArea(pieceSample,ids)
  check(#pieces==(area>=9 and 3 or 2),'2 stages when area >= 9, else 1: '..area..' -> '..#pieces)
  local S=0
  local shape={}
  for k,piece in ipairs(pieces) do
   table.insert(shape,string.format('%d:%s:%d:%d:%d:%s',piece.stage,tostring(piece.at),#piece.parts,#piece.shell,#piece.ids,tostring(piece.final==true)))
   S+=(piece.centerDepth or 0)*7.1
   for which,list in ipairs({piece.parts,piece.shell}) do
    for j,part in ipairs(list) do
     local f=k+j*.01+which*.37
     S+=(part.y0*.5+part.y1*.25)*f
     for v,p in ipairs(part.poly) do S+=(p[1]*1.000123+p[2]*.999877)*f*(1+v*.001) end
    end
   end
  end
  table.insert(prints,table.concat(shape,',')..'='..string.format('%.6f',S))
 end
 check(table.concat(prints,'\n')==TERRACE,'terrace pieces unchanged:\n'..table.concat(prints,'\n'))
 -- 'none': one final piece of the whole cells, also across layers (a volley cluster).
 local mixed={pieceSample.layers[1].cells[7],pieceSample.layers[1].cells[8],pieceSample.layers[2].cells[9]}
 for _,ids in ipairs({lists[2],lists[8],{lists[1][1]},mixed}) do
  local pieces=D.pieces(pieceSample,ids,'none')
  check(#pieces==1,'none: one piece')
  local p=pieces[1]
  check(p.final==true and p.stage==1 and p.at==1 and p.shell==p.parts and #p.parts==#ids,'none: the final piece')
  check(D.key(p.ids)==D.key(ids) and p.ids~=ids,'none: a copy of all the ids')
  for i,part in ipairs(p.parts) do
   local c=pieceSample.cells[ids[i]]
   check(part.cell==ids[i] and part.poly==c.poly and part.y0==c.y0 and part.y1==c.y1,'none: full cell polys')
  end
  partsName(ids,pieces)
 end
end
-- 7.1.5 Secret per-cell gems: density, no cell-size bias, treasure, randomness.
local gemDensity,gemRatio,gemCount
do
 local gems,vol,lowG,lowV,highG,highV=0,0,0,0,0,0
 for k,seed in ipairs({12345,777,4242}) do
  -- Gems depend only on the cells, not on what is dug.
  local g=seed==12345 and pieceSample or seed==777 and replayCube or D.build(4242)
  local placed=D.placeGems(g,D.rng(seed+1))
  local vols={}
  for id,c in ipairs(g.cells) do
   local v=D.cellVolume(g,id)
   check(math.abs(v-D.volume(g,{id}))<1e-9,'cell volume')
   vol+=v;table.insert(vols,{id=id,v=v})
   local gem=placed[id]
   if gem then
    gems+=1
    if g.treasure[id] then
     check(gem.treasure==true and gem.count==3 and gem.count==D.TREASURE_GEMS and gem.tier>=3 and gem.tier<=#D.ORES,'treasure holds 3 rich gems')
    else
     check(gem.treasure==false and gem.count==1 and gem.tier>=1 and gem.tier<=#D.ORES,'a cell gem')
     if c.ore>0 then check(gem.tier==c.ore,'an ore cell holds its own ore') end
    end
   end
  end
  for id in pairs(g.treasure) do check(placed[id]~=nil,'every treasure cell holds gems') end
  table.sort(vols,function(a,b) return a.v<b.v end)
  local q=math.floor(#vols/4)
  for i=1,q do local e=vols[i];lowV+=e.v;if placed[e.id] then lowG+=1 end end
  for i=#vols-q+1,#vols do local e=vols[i];highV+=e.v;if placed[e.id] then highG+=1 end end
  if k==1 then
   local other=D.placeGems(g,D.rng(seed+2))
   local same=true
   for id in pairs(placed) do if not other[id] then same=false end end
   for id in pairs(other) do if not placed[id] then same=false end end
   check(not same,'two random sources place gems differently')
   local repeatPlaced=D.placeGems(g,D.rng(seed+1))
   for id,gem in pairs(placed) do check(repeatPlaced[id] and repeatPlaced[id].tier==gem.tier,'same random, same gems') end
  end
 end
 gemCount=gems
 gemDensity=gems/vol*1000
 gemRatio=(lowG/lowV)/(highG/highV)
 check(gemDensity>=.8 and gemDensity<=1.1,'gems per 1000 cubic studs: '..gemDensity)
 check(gemRatio>=.75 and gemRatio<=1.33,'gems per volume, smallest quarter of cells vs largest: '..gemRatio)
end
-- 7.1.6 Gem size bounds.
check(math.abs(D.gemSize(0)-.75*1.4)<1e-9 and math.abs(D.gemSize(1e6)-1.35*1.4)<1e-9,'gem size bounds')
check(math.abs(D.gemSize(D.GEM_VOL)-D.GEM_VALUE_K)<1e-9 and D.gemSize(60)<D.gemSize(90),'gem size grows with the cell')
check(math.abs(D.chunkHp(cube,{1,2},1,function() return .6 end)-.6*D.chunkHp(cube,{1,2},1))<1e-9,'chunk HP multiplier (brittle)')
-- 7.1.7 Clusters (and claimed cells counted as gone across two concurrent jobs).
local clusterStats={n=0,cells=0}
local work=D.build(2024)
do
 local r=D.rng(11)
 local budget=150
 local mul=function(id) return id%5==0 and .6 or 1 end
 local pending={}
 for step=1,160 do
  -- As on the server: the other job's cells and sealed gem cells are taken.
  local claimed=merged(pending,work.sealed or {})
  local seed=D.pick(work,{focusX=W*.45,focusZ=W*.55,taken=claimed,random=r})
  if not seed then break end
  local ids=D.cluster(work,seed,{radius=9,maxCells=6,budget=budget,taken=claimed,preferOre=step%2==0,mul=mul})
  check(ids[1]==seed,'cluster: seed first')
  check(#ids<=6,'cluster: at most maxCells')
  local hp=0
  local seen={}
  local s=work.cells[seed]
  for _,id in ipairs(ids) do
   check(not seen[id],'cluster: no repeats');seen[id]=true
   check(not pending[id] and not work.removed[id] and not (work.sealed and work.sealed[id]),'cluster: free cells only')
   local c=work.cells[id]
   check(math.sqrt((c.cx-s.cx)^2+(c.cz-s.cz)^2)<=9,'cluster: within the radius')
   hp+=c.hp*mul(id)
  end
  check(#ids==1 or hp<=budget,'cluster: within the HP budget')
  -- In order, every cell can go with the cells before it and the other job's cells gone.
  local inside={}
  for _,id in ipairs(ids) do check(D.diggable(work,id,merged(inside,claimed)),'cluster: each cell diggable when added');inside[id]=true end
  clusterStats.n+=1;clusterStats.cells+=#ids
  -- The older job finishes; this one is now in flight. Every 7th job seals a gem cell.
  for id in pairs(pending) do D.remove(work,id) end
  pending={}
  for k,id in ipairs(ids) do
   if step%7==0 and k==#ids then work.sealed=work.sealed or {};work.sealed[id]=true else pending[id]=true end
  end
 end
 for id in pairs(pending) do D.remove(work,id) end
 check(clusterStats.n>=100 and clusterStats.cells/clusterStats.n>1.5,'clusters hold several cells: '..clusterStats.cells..'/'..clusterStats.n)
 local deepest=1
 for id in pairs(work.removed) do deepest=math.max(deepest,work.cells[id].layer) end
 check(deepest>=3,'clusters dig down: '..deepest)
 for _,cell in ipairs(work.cells) do
  if not work.removed[cell.id] and not (work.sealed and work.sealed[cell.id]) and cell.layer<#work.layers then
   check(D.supported(work,cell.id,0,nil),'after clusters, cell '..cell.id..' (layer '..cell.layer..') does not float')
  end
 end
end
-- 7.1.8 Lines.
local lineStats={n=0,long=0}
do
 for _,source in ipairs({pieceSample,work}) do
  local r=D.rng(5)
  for i=1,60 do
   local seed=D.pick(source,{random=r,taken=source.sealed})
   if not seed then break end
   local axis=i%2==0 and 'x' or 'z'
   local ids=D.line(source,seed,{axis=axis,sign=i%3==0 and -1 or 1,min=3,max=6,width=2})
   local s=source.cells[seed]
   check(#ids>=1 and #ids<=6 and table.find(ids,seed)~=nil,'line: holds its seed, at most max')
   local inside={}
   for k,id in ipairs(ids) do
    local c=source.cells[id]
    check(c.layer==s.layer,'line: same layer')
    check(math.abs((axis=='x' and c.cz-s.cz or c.cx-s.cx))<=2,'line: centres within 2 studs of the axis')
    check(not inside[id],'line: no repeats')
    if k>1 then check(table.find(c.neighbors,ids[k-1])~=nil,'line: contiguous neighbours') end
    check(D.diggable(source,id,inside),'line: each cell diggable with the line gone');inside[id]=true
   end
   -- On the intact top layer most lines reach their minimum (deep in a pit
   -- the same-layer neighbours are often still covered).
   if source==pieceSample then lineStats.n+=1;if #ids>=3 then lineStats.long+=1 end end
  end
 end
 check(lineStats.long>=lineStats.n*.75,'most top-layer lines reach their minimum: '..lineStats.long..'/'..lineStats.n)
end
-- 7.1.9 Picks: weights, depth power, and claimed cells counted as gone.
local meanLayer={}
do
 local target=D.pick(cube,{focusX=W*.3,focusZ=W*.4,random=D.rng(3)})
 check(target~=nil,'a cell to aim at')
 for k=1,25 do
  check(D.pick(cube,{focusX=W*.3,focusZ=W*.4,random=D.rng(k),weight=function(id) return id==target and 1 or 0 end})==target,'a weight of 0 rules cells out')
 end
 for _,pow in ipairs({1,2}) do
  local r=D.rng(21);local sum=0
  for _=1,400 do sum+=cube.cells[D.pick(cube,{focusX=W*.3,focusZ=W*.4,depthPow=pow,random=r})].layer end
  meanLayer[pow]=sum/400
 end
 check(meanLayer[2]>meanLayer[1]+.1,'depthPow 2 goes deeper: '..meanLayer[1]..' -> '..meanLayer[2])
 -- A constructed case: U (top layer) rests on exactly A and B below it,
 -- and is over neither one's core, so either can go alone but not both.
 local probe=D.build(31337)
 local found
 for _,u in ipairs(probe.layers[1].cells) do
  local below=D.below(probe,u)
  for i=1,#below do
   for j=i+1,#below do
    local a,b=below[i],below[j]
    local others={}
    for _,x in ipairs(below) do if x~=a and x~=b then others[x]=true end end
    if D.supported(probe,u,a,others) and D.supported(probe,u,b,others)
     and not table.find(D.shoulders(probe,a),u) and not table.find(D.shoulders(probe,b),u) then
     found={u=u,a=a,b=b,others=others};break
    end
   end
   if found then break end
  end
  if found then break end
 end
 check(found~=nil,'a top cell resting on exactly two cells')
 for _,id in ipairs(probe.layers[1].cells) do if id~=found.u then D.remove(probe,id) end end
 for x in pairs(found.others) do D.remove(probe,x) end
 local A,B=found.a,found.b
 check(D.diggable(probe,A) and D.diggable(probe,B),'either cell can go alone')
 check(not D.diggable(probe,B,{[A]=true}) and not D.diggable(probe,A,{[B]=true}),'but not both')
 local only=function(id) return (id==A or id==B) and 1 or 0 end
 local free=D.pick(probe,{weight=only,random=D.rng(1)})
 check(free==A or free==B,'pick takes one of the two')
 for k=1,20 do
  check(D.pick(probe,{weight=only,taken={[A]=true},random=D.rng(k)})==nil,'pick: a claimed cell counts as gone')
  check(D.pick(probe,{weight=only,gone={[A]=true},random=D.rng(k)})==nil,'pick: opts.gone counts as removed')
 end
 local reached=false
 for _,n in ipairs(probe.cells[B].neighbors) do
  if n~=A and not probe.removed[n] then
   if table.find(D.chunk(probe,n,3,nil),B) then reached=true end
   check(table.find(D.chunk(probe,n,3,{[A]=true}),B)==nil,'chunk: a claimed cell counts as gone')
   check(table.find(D.cluster(probe,n,{radius=20,maxCells=40,taken={[A]=true}}),B)==nil,'cluster: a claimed cell counts as gone')
   for _,axis in ipairs({'x','z'}) do
    for _,sign in ipairs({1,-1}) do
     check(table.find(D.line(probe,n,{axis=axis,sign=sign,min=12,max=12,width=50,taken={[A]=true}}),B)==nil,'line: a claimed cell counts as gone')
    end
   end
  end
 end
 check(reached,'without the claim a neighbour chunk does take B (the case is real)')
end
-- 7.1.10 Depth bite: the bottom layer breaks smaller chunks than the top.
local biteRatio
do
 local r1,r10=D.rng(5),D.rng(5)
 local a1,a10=0,0
 for i=1,60 do a1+=D.chunkArea(pieceSample,D.chunk(pieceSample,pieceSample.layers[1].cells[i*5],1.4,nil,r1)) end
 for L=1,9 do for _,id in ipairs(pieceSample.layers[L].cells) do D.remove(pieceSample,id) end end
 for i=1,60 do a10+=D.chunkArea(pieceSample,D.chunk(pieceSample,pieceSample.layers[10].cells[i*3],1.4,nil,r10)) end
 biteRatio=a10/a1
 check(biteRatio>=.45 and biteRatio<=.75,'mean chunk area L10/L1: '..biteRatio)
end
print(string.format('PASS dig roles: %d styles (%s), op grammar v2 round trip + replay, pieces none/terrace (terrace fingerprint unchanged)',#WORKERS,table.concat(WORKERS,' ')))
print(string.format('PASS gems: %d over 3 cubes, %.2f per 1000 cubic studs, small/large cell ratio %.2f; clusters avg %.1f cells, %d/%d lines reach 3; depthPow mean layer %.2f -> %.2f; depth bite L10/L1 %.2f',
 gemCount,gemDensity,gemRatio,clusterStats.cells/clusterStats.n,lineStats.long,lineStats.n,meanLayer[1],meanLayer[2],biteRatio))
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
