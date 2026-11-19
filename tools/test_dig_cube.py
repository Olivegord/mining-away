#!/usr/bin/env python3
"""Dig Cube 3D Voronoi geometry and digging rules, run on the real module with the Luau CLI.

Checks: cell volumes fill the box exactly, shared faces are symmetric, a
simulated crew never cuts a cell with another resting on it (nothing floats),
digs craters (deep, not layer by layer, not a one-cell shaft), blasts grow with
cut size, a split gives two closed halves with the cell's volume, crack lines
exist, tiles cover the outer surface, gems are rare, encoding round-trips and
generation is deterministic. Not engine QA: looks, feel and performance need Studio.
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
local W,H=D.WIDTH,D.HEIGHT
local vol=0
for _,cell in ipairs(cube.cells) do
 vol+=cell.volume
 check(#cell.faces>=4,'closed cell '..cell.id)
 for _,n in ipairs(cell.neighbors) do check(table.find(cube.cells[n].neighbors,cell.id)~=nil,'neighbor symmetry') end
end
check(math.abs(vol-W*W*H)<W*W*H*.001,'cells fill the box: '..vol)
check(#cube.cells>=250 and #cube.cells<=1200,'cell count '..#cube.cells)
local ores=0;for _,c in ipairs(cube.cells) do if c.ore>0 then ores+=1 end end
check(ores>0.04*#cube.cells and ores<0.45*#cube.cells,'ore share '..ores)
-- Simulated crew: focus on a point, 150 cuts, then move the focus.
local rnd=D.rng(99);local recent={};local claims={}
local deepest=0
local topAtDepth=nil
for step=1,150 do
 local taken,points={},{}
 for _,id in ipairs(claims) do taken[id]=true;table.insert(points,{cube.cells[id].cx,cube.cells[id].cz}) end
 local fx,fz=step<=110 and W*.3 or W*.72,step<=110 and W*.4 or W*.7
 local id=D.pick(cube,{focusX=fx,focusZ=fz,taken=taken,takenPoints=points,recent=recent,now=step,random=rnd})
 check(id~=nil,'a cell is available at step '..step)
 for _,u in ipairs(cube.cells[id].up) do check(cube.removed[u],'nothing rests on a cut cell') end
 table.insert(claims,id);if #claims>4 then table.remove(claims,1) end
 D.remove(cube,id);recent[id]=step
 deepest=math.max(deepest,H-cube.cells[id].minY)
 if deepest>=H*.45 and not topAtDepth then
  topAtDepth=0
  for _,cell in ipairs(cube.cells) do if cell.maxY>H-.01 and cube.removed[cell.id] then topAtDepth+=1 end end
 end
end
check(deepest>=H*.45,'crew digs down: '..deepest)
local topCells,topCut=0,0
for _,cell in ipairs(cube.cells) do
 if cell.maxY>H-.01 then topCells+=1;if cube.removed[cell.id] then topCut+=1 end end
end
check(topAtDepth and topAtDepth<topCells*.45,'reaches half depth before clearing the top: '..tostring(topAtDepth)..'/'..topCells)
-- Not a drill: removed volume spreads wider near the top than at depth.
local band={0,0,0,0}
for id in pairs(cube.removed) do local c=cube.cells[id];local b=math.clamp(math.floor((H-c.cy)/H*4)+1,1,4);band[b]+=c.volume end
check(band[1]>=band[3],'crater narrows with depth')
-- Blasts.
local r2=D.rng(5)
local one,big=0,0
for i=1,20 do
 local seed=next(cube.frontier)
 local id
 for k in pairs(cube.frontier) do if D.diggable(cube,k) then id=k;break end end
 check(#D.chunk(cube,id,1,nil,r2)==1,'cut size 1 is one cell')
 local blast=D.chunk(cube,id,2,nil,r2)
 local inBlast={};for _,m in ipairs(blast) do inBlast[m]=true end
 for _,m in ipairs(blast) do for _,u in ipairs(cube.cells[m].up) do check(cube.removed[u] or inBlast[u],'a blast leaves nothing floating') end end
 big+=#blast
end
check(big/20>=3,'cut size 2 blasts several cells: '..(big/20))
-- Split halves keep the volume.
for id=1,40 do
 local sp=D.split(cube,id)
 local function hv(faces)
  local v=0
  local ref={0,0,0};local n=0
  for _,f in ipairs(faces) do for _,p in ipairs(f.verts) do ref[1]+=p[1];ref[2]+=p[2];ref[3]+=p[3];n+=1 end end
  ref={ref[1]/n,ref[2]/n,ref[3]/n}
  for _,f in ipairs(faces) do
   for i=2,#f.verts-1 do
    local a,b,c=f.verts[1],f.verts[i],f.verts[i+1]
    local ax,ay,az=a[1]-ref[1],a[2]-ref[2],a[3]-ref[3]
    local bx,by,bz=b[1]-ref[1],b[2]-ref[2],b[3]-ref[3]
    local cx,cy,cz=c[1]-ref[1],c[2]-ref[2],c[3]-ref[3]
    v+=math.abs(ax*(by*cz-bz*cy)-ay*(bx*cz-bz*cx)+az*(bx*cy-by*cx))/6
   end
  end
  return v
 end
 local total=hv(sp.a)+hv(sp.b)
 check(math.abs(total-cube.cells[id].volume)<cube.cells[id].volume*.01,'halves keep the volume of cell '..id)
 local cut=0;for _,f in ipairs(sp.a) do if f.label==0 then cut+=1 end end
 check(cut==1,'half has one cut face')
end
-- Cracks and wedges.
local open
for id in pairs(cube.frontier) do if not cube.removed[id] then open=id;break end end
local cr=D.cracks(cube,open)
check(#cr.edges>=3 and cr.reach>0,'crack edges')
local wedges=0
for _,f in ipairs(cube.cells[open].faces) do
 for _,w in ipairs(D.faceWedges(f)) do check(w.size[2]>0 and w.size[3]>0,'wedge size');wedges+=1 end
end
check(wedges>0,'cell wedges')
-- Tiles cover every outer face of every cell except the bottom.
local tiles,faceTiles=D.tiles(cube)
for _,cell in ipairs(cube.cells) do
 for fi,f in ipairs(cell.faces) do if f.label<-1 then check(#faceTiles[cell.id][fi]>0,'outer face under a tile') end end
end
-- Gems: some cuts hold one, most do not.
local gems=0;local g=D.rng(8)
for i=1,400 do if D.gemRoll(cube,{(i%#cube.cells)+1},g)>0 then gems+=1 end end
check(gems>15 and gems<180,'gem chance per cut '..gems..'/400')
-- Encode/decode and determinism.
local set=D.decode(cube,D.encode(cube))
local n=0;for id in pairs(set) do n+=1;check(cube.removed[id],'decoded id removed') end
check(n==cube.removedCount,'round trip count')
local again=D.build(12345)
check(#again.cells==#cube.cells and again.cells[77].cx==cube.cells[77].cx,'deterministic')
print(string.format('PASS dig cube 3D: %d cells (avg %.0f cubic studs), volume exact, %d ore cells; build %.2fs',#cube.cells,vol/#cube.cells,ores,buildTime))
print(string.format('PASS digging: 150 cuts reach %.0f of %d studs deep, %d/%d top cells cut on reaching half depth, nothing ever floats; blast at cut 2 = %.1f cells; %d/400 cuts hold a gem',deepest,H,topAtDepth,topCells,big/20,gems))
"""
with tempfile.TemporaryDirectory() as folder:
    path = Path(folder) / "dig_cube3d_test.luau"
    path.write_text(test)
    result = subprocess.run([str(luau), str(path)], capture_output=True, text=True)
    print(result.stdout, end="")
    if result.returncode != 0 or "FAIL" in result.stdout + result.stderr:
        print(result.stderr, end="")
        sys.exit(1)
print("PASS DigCube module with the Luau CLI (no Roblox APIs). Looks, feel and performance NOT VERIFIED.")
