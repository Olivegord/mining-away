#!/usr/bin/env python3
"""Dig Cube geometry, cutters and digging rules, run on the real module with the Luau CLI.

For every tessellation (3D Voronoi, strata, bricks): cells fill the box exactly
and neighbors agree. For every cutter (cell crack-out, round blast, trench,
core bore): a cut removes what its preview said, a box fully inside the rock
removes exactly its own volume, rock volume is conserved across hundreds of
mixed cuts, crack-outs never leave a cell resting on a removed one, the crew
digs craters (deep before the top is cleared), cut outlines exist, halves keep
the removed volume, ops encode/decode losslessly, and two cubes replaying the
same ops end up identical (what keeps server and clients in sync).
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
local function piecesVolume(c) local v=0;for _,p in pairs(c.pieces) do v+=p.volume end;return v end
local function pieceCount(c) local n=0;for _ in pairs(c.pieces) do n+=1 end;return n end
local W,H=D.WIDTH,D.HEIGHT
local lines={}
for _,kind in ipairs(D.TESSELLATIONS) do
 local t0=os.clock()
 local cube=D.build(12345,kind)
 local buildTime=os.clock()-t0
 check(cube.tessellation==kind,'tessellation '..kind)
 local vol=0
 for _,cell in ipairs(cube.cells) do
  vol+=cell.volume
  for _,n in ipairs(cell.neighbors) do check(table.find(cube.cells[n].neighbors,cell.id)~=nil,kind..' neighbor symmetry') end
 end
 check(math.abs(vol-W*W*H)<W*W*H*.001,kind..' cells fill the box: '..vol)
 -- A crew mixing all four cutters.
 local rnd=D.rng(99);local recent={}
 local kinds={'cell','sphere','box','core'}
 local deepest,topAtDepth=0,nil
 local topCells=0;for _,cell in ipairs(cube.cells) do if cell.maxY>H-.01 then topCells+=1 end end
 local t1=os.clock()
 local mismatch=0
 for step=1,160 do
  local fx,fz=step<=120 and W*.3 or W*.72,step<=120 and W*.4 or W*.7
  local id=D.pick(cube,{focusX=fx,focusZ=fz,recent=recent,now=step,random=rnd})
  check(id~=nil,kind..' a cell is available at step '..step)
  local cutter=kinds[step%4+1]
  local op=D.decodeOp(D.encodeOp(D.planCut(cube,cutter,id,1+(step%5==0 and 1 or 0),step*.9,nil,rnd)))
  check(op~=nil,'op round trip')
  if op.kind=='c' then for _,cid in ipairs(op.cells) do for _,u in ipairs(cube.cells[cid].up) do check(cube.removed[u] or table.find(op.cells,u),kind..' crack-out leaves nothing resting on it') end end end
  local predicted=D.preview(cube,op)
  local result=D.apply(cube,op)
  if math.abs(predicted-result.volume)>math.max(predicted*.35,8) and op.kind=='c' then mismatch+=1 end
  for _,cid in ipairs(result.cells) do recent[cid]=step;deepest=math.max(deepest,H-cube.cells[cid].minY) end
  if deepest>=H*.45 and not topAtDepth then
   topAtDepth=0;for _,cell in ipairs(cube.cells) do if cell.maxY>H-.01 and cube.touched[cell.id] then topAtDepth+=1 end end
  end
 end
 local cutTime=(os.clock()-t1)/160
 check(mismatch==0,kind..' crack-out preview matches')
 check(math.abs(piecesVolume(cube)+cube.removedVolume-W*W*H)<W*W*H*.002,kind..' rock volume conserved: '..(piecesVolume(cube)+cube.removedVolume))
 check(deepest>=H*.4,kind..' crew digs down: '..deepest)
 check(topAtDepth==nil or topAtDepth<topCells*.5,kind..' deep before the top is cleared: '..tostring(topAtDepth)..'/'..topCells)
 table.insert(lines,string.format('%s: %d cells, build %.2fs, %.1f ms per cut, %d pieces after 160 mixed cuts, %.0f studs deep',kind,#cube.cells,buildTime,cutTime*1000,pieceCount(cube),deepest))
end
-- Exact shapes: a box fully inside fresh rock removes exactly its volume;
-- a round blast removes about a ball; previews match.
local cube=D.build(7)
local box={kind='b',x=44,y=40,z=44,yaw=.7,sx=8,sy=3.2,sz=3.4}
check(math.abs(D.preview(cube,box)-8*3.2*3.4)<.05,'box preview is its volume')
local r=D.apply(cube,box)
check(r.volume>=8*3.2*3.4-.05 and r.volume<=8*3.2*3.4+6*D.MIN_PIECE,'box removes its volume (plus crumbled slivers): '..r.volume)
check(#r.added>0 and #r.removed>0,'box splits pieces into kept parts and the cut')
local sphere={kind='s',x=30,y=30,z=30,r=4}
local pv=D.preview(cube,sphere)
local sr=D.apply(cube,sphere)
local ball=4/3*math.pi*64
check(sr.volume>=pv-.05 and sr.volume<=pv+18*D.MIN_PIECE and sr.volume>ball*.95 and sr.volume<ball*1.45,'round blast removes about a ball: '..sr.volume)
local core={kind='y',x=60,y=30,z=60,r=2.8,h=5}
local cr=D.apply(cube,core)
check(cr.volume>math.pi*2.8^2*5*.95 and cr.volume<math.pi*2.8^2*5*1.1,'core bore removes about a cylinder: '..cr.volume)
-- Halves keep the removed volume.
local A,B=D.splitChunks(r.removed,r.center,D.splitPlane(box,r.center))
local hv=0
for _,list in ipairs({A,B}) do for _,chunk in ipairs(list) do
 local v=0
 local ref={0,0,0};local n=0
 for _,f in ipairs(chunk.faces) do for _,q in ipairs(f.verts) do ref[1]+=q[1];ref[2]+=q[2];ref[3]+=q[3];n+=1 end end
 ref={ref[1]/n,ref[2]/n,ref[3]/n}
 for _,f in ipairs(chunk.faces) do for i=2,#f.verts-1 do
  local a,b,c=f.verts[1],f.verts[i],f.verts[i+1]
  local ax,ay,az=a[1]-ref[1],a[2]-ref[2],a[3]-ref[3];local bx,by,bz=b[1]-ref[1],b[2]-ref[2],b[3]-ref[3];local cx,cy,cz=c[1]-ref[1],c[2]-ref[2],c[3]-ref[3]
  v+=math.abs(ax*(by*cz-bz*cy)-ay*(bx*cz-bz*cx)+az*(bx*cy-by*cx))/6
 end end
 hv+=v
end end
check(math.abs(hv-r.volume)<r.volume*.01,'halves keep the cut volume')
check(#A>0 and #B>0,'cut splits into two halves')
-- Outlines: a round blast on the top surface traces a closed ring of cracks.
local fresh=D.build(7)
local top={kind='s',x=44,y=H-1,z=44,r=4}
local ring=D.outline(fresh,top,{44,H,44})
check(#ring.edges>=6 and ring.reach>2,'round blast outline: '..#ring.edges)
local trench=D.outline(fresh,{kind='b',x=20,y=H-1,z=20,yaw=0,sx=8,sy=3.2,sz=3.4},{20,H,20})
check(#trench.edges>=4,'trench outline')
-- Same ops, same rock: replaying an op list reproduces the geometry exactly.
local a,b=D.build(4242),D.build(4242)
local rr=D.rng(1)
local ops={}
for step=1,60 do
 local id=D.pick(a,{focusX=40,focusZ=40,random=rr})
 local op=D.encodeOp(D.planCut(a,({'cell','sphere','box','core'})[step%4+1],id,1,step,nil,rr))
 D.apply(a,D.decodeOp(op));table.insert(ops,op)
end
for _,op in ipairs(ops) do D.apply(b,D.decodeOp(op)) end
check(pieceCount(a)==pieceCount(b) and math.abs(piecesVolume(a)-piecesVolume(b))<1e-6,'replayed ops give identical rock')
-- Cutters by drone: Strikers spread over all four; typed drones keep theirs.
local seen={}
for i=1,40 do seen[D.cutterFor('Striker','drone'..i)]=true end
check(seen.cell and seen.sphere and seen.box and seen.core,'Strikers get every cutter')
check(D.cutterFor('Charger','x')=='sphere' and D.cutterFor('Gridcutter','x')=='box','typed cutters')
-- Gem rate per single cut.
local gems=0;local g=D.rng(8);local gc=D.build(99)
for i=1,300 do
 local id=D.pick(gc,{random=g});if not id then break end
 local res=D.apply(gc,D.planCut(gc,'cell',id,1,0,nil,g))
 if D.gemRoll(gc,res,g)>0 then gems+=1 end
end
check(gems>15 and gems<130,'gem chance per cut '..gems..'/300')
for _,l in ipairs(lines) do print('PASS '..l) end
print(string.format('PASS exact cutters: box %.2f/%.2f cubic studs, round blast %.0f (ball %.0f), core %.0f; halves keep volume; outlines; replay identical; %d/300 cuts hold a gem',r.volume,8*3.2*3.4,sr.volume,ball,cr.volume,gems))
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
