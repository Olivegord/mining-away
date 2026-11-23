#!/usr/bin/env python3
"""The Dig Cube on the real server bundle with Roblox API doubles.

Checks: the cube is created with its seed and origin, walking up to it puts the
crew to work digging (no field needed), every op parses with DigCube.parseOp and
replays (DigCube.applyOp) to exactly the server's removed set, drones publish
their chunk as c<ids>~<code>, a tap (DigFocus) moves the crew's work, leaving
releases the crew, and a spent cube resets. Then every one of the 14 worker
roles digs alone (its own op code, shots, slam beats, line sequence, brittle
cells, Needler hints, Lancer pulses), with a throughput table against a medium
Striker; secret per-cell gems seal (K) or burst out over the caps; geodes go
public; shots are carved ahead and always finish; a top-layer break cuts only
top-layer blocks; and ops publish in the same tick, at most 30 times a second.
Not engine QA: looks, feel, CSG timings, client building and real multiplayer
need a Studio playtest.
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
-- A geometry double for the carve: a cut returns a new part, unless the part
-- is marked to fail (as Roblox CSG sometimes does on much-cut parts). With
-- cutLog set, every cut records the cube-local Y range of the block it cut.
local cuts,failed=0,0
local cutLog=nil
local failAll=false
function IM:SubtractAsync(negatives)
 if self:GetAttribute('FailCut') or failAll then failed+=1;error('CSG operation failed: too complex') end
 -- Roblox now returns nil, with no error, when nothing is left of the part.
 if self:GetAttribute('EmptyCut') then cuts+=1;return nil end
 cuts+=1
 if cutLog then table.insert(cutLog,{y0=self.Position.Y-self.Size.Y*.5-dig.origin.Y,y1=self.Position.Y+self.Size.Y*.5-dig.origin.Y,n=#negatives}) end
 local p=Instance.new('Part');p.Size=self.Size;p.CFrame=self.CFrame
 return p
end
local function parsed(entry) local op=DigCube.parseOp(entry);assert(op,'op parses: '..tostring(entry));return op end
local function isFinal(op) return op.flag=='' or op.flag=='E' or op.flag=='C' end
local function holderOps(holder)
 local list={}
 local count=holder:GetAttribute('OpCount') or 0
 for i=1,math.ceil(count/64) do for entry in string.gmatch(holder:GetAttribute('Ops'..i) or '','[^;]+') do table.insert(list,entry) end end
 assert(#list==count,'every published op is in an Ops attribute: '..#list..'/'..count)
 return list
end
assert(dig and dig.cube,'the cube exists at startup')
local holder=dig.holder
assert(holder and holder.Parent==root:FindFirstChild('DigField') and holder:GetAttribute('Chunk')=='0_0','the pinned Plot 1 chunk replicates under DigField')
assert(holder:GetAttribute('Seed') and holder:GetAttribute('Generation')==1,'seed and generation replicate')
assert(holder:GetAttribute('Origin')==dig.origin,'origin replicates')
assert(holder:GetAttribute('Seed')==DigCube.chunkSeed(root.DigField:GetAttribute('WorldSeed'),0,0,1),'the chunk seed comes from the world seed and its grid coordinates')
-- Untouched rock is one column per tile; a carve splits what it reaches into layer blocks.
assert(#dig.blocks==64,'solid rock columns: '..#dig.blocks)
for _,b in ipairs(dig.blocks) do assert(b.column and b.hi.Y-b.lo.Y==dig.cube.height,'every untouched tile is one full-height column') end
local gemTotal=0;for _ in pairs(dig.gems) do gemTotal+=1 end
assert(gemTotal>#dig.cube.cells*.05 and gemTotal<#dig.cube.cells*.2,'secret gems placed per cell: '..gemTotal)
local pl=player(4813)
players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local W=DigCube.WIDTH
pl.Character:PivotTo(CFrame.new(dig.origin+Vector3.new(W*.3,dig.cube.height+3,W*.3)))
tick(10)
assert(p.digging,'standing on the cube puts the crew to work')
do
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
    assert(string.match(key,'^c[%d%.]+~L$'),'a Striker publishes its chunk with its code: '..key)
    sizes[d.model:GetAttribute('DigChunkSize')]=true
   end
  end
  if #dig.ops>=10 then break end
 end
 for _,c in ipairs(pickups:GetChildren()) do if c:GetAttribute('Owner')==pl.UserId and c:GetAttribute('StoneCargo')==true then stones+=1 end end
 assert(stones==0,'chunks leave rock dust, not floating rock pickups: '..stones)
 assert(holder:FindFirstChild('Dust'),'rock dust replicates')
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
end
tick(10)
-- Chunks break in nested stages first (flag S, no gem), then the final break.
-- Keep the crew working until a few chunks have fully broken.
local function finals()
 local n=0
 for _,entry in ipairs(dig.ops) do if isFinal(parsed(entry)) then n+=1 end end
 return n
end
for _=1,200 do if finals()>=3 then break end;tick(10) end
tick(3)
do
 local partial,final=0,0
 for _,entry in ipairs(dig.ops) do
  local op=parsed(entry)
  assert(op.code=='L' or op.geode,'Striker ops carry ~L: '..entry)
  if op.staged then partial+=1;assert(op.tier==0 and #op.removes==0,'a stage carries no gem and removes no cell: '..entry) elseif isFinal(op) then final+=1 end
 end
 assert(partial>=3 and final>=3,'chunks break in stages: '..partial..' stages, '..final..' final')
end
-- Replication: replaying the published ops gives the server's removed set.
local function replayMatches(label)
 dig.publishAt=0;scene.digFlushOps()
 local replay=DigCube.build(holder:GetAttribute('Seed'))
 for _,entry in ipairs(holderOps(holder)) do DigCube.applyOp(replay,parsed(entry)) end
 assert(replay.removedCount==dig.cube.removedCount,label..': replayed '..replay.removedCount..' vs server '..dig.cube.removedCount)
 for id=1,#dig.cube.cells do assert((replay.removed[id]==true)==(dig.cube.removed[id]==true),label..': cell '..id..' differs') end
end
replayMatches('Striker ops replay')
do
 local sample=DigCube.build(7)
 local seed=DigCube.pick(sample,{random=function() return .5 end})
 local ids=DigCube.chunk(sample,seed,1.9,nil,function() return .9 end)
 local pieces=DigCube.pieces(sample,ids)
 local last=0
 local thick=sample.cells[ids[1]].y1-sample.cells[ids[1]].y0
 for k,piece in ipairs(pieces) do
  assert(#piece.parts>=1 and piece.at>last,'stages are non-empty and in order')
  last=piece.at
  if k<#pieces then for _,part in ipairs(piece.parts) do assert(part.y1-part.y0<thick,'a stage is shallower than the layer') end end
 end
 assert(pieces[#pieces].final and #pieces[#pieces].ids==#ids and last==1 and #pieces>=2 and #pieces<=3,'stages end in the chunk itself: '..#pieces)
end
-- Depth milestones: the first break into a new layer always reveals a gem
-- (sealed: a K op; or burst out over the cap: a final op with a tier).
do
 local gem=false
 for _,entry in ipairs(dig.ops) do local op=parsed(entry);if op.sealed or (isFinal(op) and op.tier>0) or op.geode then gem=true end end
 assert(gem or dig.deepest==1,'the first chunk into a new layer pays a gem')
end
-- A failed cut no longer leaves the block standing over dug cells: the
-- block is rebuilt from a fresh box (floating layered slabs, owner Nov 22).
assert(cuts>0,'the carve cuts blocks')
do
 local columns=0;for _,b in ipairs(dig.blocks) do if b.column then columns+=1 end end
 assert(columns<64,'carving split the columns it reached: '..columns..' columns left')
end
-- The carve-failure checks below work on layer blocks: split every column.
scene.digSplitColumns(dig,Vector3.new(-1,0,-1),Vector3.new(W+1,0,W+1))
do
 local victim=dig.blocks[1]
 local lo,hi=victim.lo,victim.hi
 victim.part:SetAttribute('FailCut',true)
 local id
 for cid,c in ipairs(dig.cube.cells) do
  if not dig.cube.removed[cid] and c.cx>lo.X and c.cx<hi.X and c.cz>lo.Z and c.cz<hi.Z and c.y0>=lo.Y-.01 and c.y1<=hi.Y+.01 then id=cid;break end
 end
 assert(id,'a cell inside the failing block')
 DigCube.remove(dig.cube,id)
 local before=failed
 scene.digCarve({generation=dig.generation,ids={id},parts={}})
 assert(failed==before+1,'the cut failed')
 local stillThere=false
 for _,b in ipairs(dig.blocks) do if b==victim then stillThere=true end end
 assert(not stillThere,'the failed block is replaced')
 local covered=0
 for _,b in ipairs(dig.blocks) do if b.lo.X>=lo.X-.01 and b.hi.X<=hi.X+.01 and b.lo.Z>=lo.Z-.01 and b.hi.Z<=hi.Z+.01 and b.lo.Y==lo.Y then covered+=1 end end
 assert(covered>=1,'the region is rebuilt from a fresh box')
end
-- Floating rocks (owner, Nov 22; Studio log "carve failed ... nil"): an
-- empty cut is not a failure. The block just goes; nothing is rebuilt.
do
 local victim=dig.blocks[#dig.blocks]
 local lo,hi=victim.lo,victim.hi
 victim.part:SetAttribute('EmptyCut',true)
 local id
 for cid,c in ipairs(dig.cube.cells) do
  if not dig.cube.removed[cid] and c.cx>lo.X and c.cx<hi.X and c.cz>lo.Z and c.cz<hi.Z and c.y0>=lo.Y-.01 and c.y1<=hi.Y+.01 then id=cid;break end
 end
 DigCube.remove(dig.cube,id)
 local n=#dig.blocks;local before=failed
 scene.digCarve({generation=dig.generation,ids={id},parts={}})
 assert(failed==before,'an empty cut is not a failure')
 assert(#dig.blocks==n-1,'an empty block is dropped, not rebuilt: '..n..' -> '..#dig.blocks)
 for _,b in ipairs(dig.blocks) do assert(b~=victim,'the emptied block is gone') end
end
-- Every cut failing: the last resort never puts a box back. It builds only
-- the cells still there (not dug, not carved ahead), so nothing floats.
do
 local victim=dig.blocks[2]
 local lo,hi=victim.lo,victim.hi
 local inside={}
 for cid,c in ipairs(dig.cube.cells) do
  if not dig.cube.removed[cid] and c.cx>=lo.X and c.cx<hi.X and c.cz>=lo.Z and c.cz<hi.Z and (c.y0+c.y1)*.5>=lo.Y and (c.y0+c.y1)*.5<=hi.Y then table.insert(inside,cid) end
 end
 assert(#inside>=3,'cells in the block: '..#inside)
 DigCube.remove(dig.cube,inside[1])
 dig.carved[inside[2]]=true
 failAll=true
 scene.digCarve({generation=dig.generation,ids={inside[1]},parts={}})
 failAll=false
 dig.carved[inside[2]]=nil
 local boxes,wedges=0,0
 for _,b in ipairs(dig.blocks) do
  if b.part.Parent and b.lo.Y==lo.Y and b.lo.X>=lo.X-6 and b.hi.X<=hi.X+6 and b.lo.Z>=lo.Z-6 and b.hi.Z<=hi.Z+6 and b~=victim then
   if b.part:IsA('WedgePart') then wedges+=1
   else
    -- A box (an undug quarter) must not cover the dug or the carved-ahead cell.
    for _,cid in ipairs({inside[1],inside[2]}) do
     local c=dig.cube.cells[cid]
     if c.cx>b.lo.X and c.cx<b.hi.X and c.cz>b.lo.Z and c.cz<b.hi.Z then boxes+=1 end
    end
   end
  end
 end
 assert(boxes==0,'no box is put back over a dug or carved-ahead cell: '..boxes)
 assert(wedges>0,'the cells still there are rebuilt as wedges')
 for _,b in ipairs(dig.blocks) do
  if b.part:IsA('WedgePart') and b.part.Parent then
   local c1,c2=dig.cube.cells[inside[1]],dig.cube.cells[inside[2]]
   assert(not (b.lo.X==c1.minX and b.lo.Z==c1.minZ and b.lo.Y==c1.y0),'no rock rebuilt for the dug cell')
   assert(not (b.lo.X==c2.minX and b.lo.Z==c2.minZ and b.lo.Y==c2.y0),'no rock rebuilt for the carved-ahead cell')
  end
 end
 print(string.format('PASS no floating rock from the carve: an empty cut drops its block; a block every cut fails on is rebuilt from the cells still there (%d wedges), never over dug rock',wedges))
end
-- Treasure pockets exist, sit deep, hold several gems and always seal.
local pockets=0
for id in pairs(dig.cube.treasure) do
 pockets+=1;assert(dig.cube.cells[id].layer>=3,'treasure sits deep')
 local g=dig.gems[id];assert(dig.cube.removed[id] or (g and g.treasure and g.count==DigCube.TREASURE_GEMS and g.tier>=3),'a treasure cell holds rich gems')
end
assert(pockets==DigCube.TREASURES,'treasure pockets: '..pockets)
local tid=next(dig.cube.treasure)
local pendingBefore=#dig.pending
scene.digBreak({ids={tid},key=tostring(tid),cx=dig.cube.cells[tid].cx,cz=dig.cube.cells[tid].cz},p.drones[1],p)
local sealed=dig.geodes[tid]
assert(sealed and sealed.treasure and sealed.owner==pl.UserId and not dig.cube.removed[tid],'a gem cell stays sealed')
assert(dig.ops[#dig.ops]=='c'..tid..'~L|'..sealed.tier..'|K','a one-cell seal emits only the crack-seal op: '..dig.ops[#dig.ops])
assert(#dig.pending==pendingBefore,'no gem before the cell is opened')
assert(string.find(holder:GetAttribute('Geodes') or '',tostring(tid)..':',1,true),'sealed cells replicate')
local savedRoot=pl.Character.HumanoidRootPart.CFrame
do
 local c=dig.cube.cells[tid]
 local job=scene.digPick(p.drones[1],p)
 if job then for _,id in ipairs(job.ids) do assert(id~=tid,'drones leave sealed cells alone') end;scene.digDrop(p.drones[1]) end
 pl.Character:PivotTo(CFrame.new(dig.origin+Vector3.new(c.cx,c.y1+3,c.cz)))
 pl.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
 tick(2)
 assert(dig.geodes[tid] and not dig.cube.removed[tid],'standing on a sealed cell does not open it')
 pl.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(0,-20,0)
end
tick(2)
pl.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
assert(dig.geodes[tid]==nil and dig.cube.removed[tid],'landing on it from a jump opens the sealed cell')
do
 local found=false
 for i=#dig.ops,1,-1 do local op=parsed(dig.ops[i]);if op.cells[1]==tid and op.flag=='X' and op.code==nil then found=true;break end end
 assert(found,'treasure opening is flagged X with no code')
 local high=0
 for _,g in ipairs(dig.pending) do if g.high then high+=1 end end
 assert(high==DigCube.TREASURE_GEMS,'a treasure pays several gems, launched high: '..high)
end
do
 local other=next(dig.cube.treasure,tid)
 if other and not dig.cube.removed[other] then
  scene.digBreak({ids={other},key=tostring(other),cx=dig.cube.cells[other].cx,cz=dig.cube.cells[other].cz},p.drones[1],p)
  assert(dig.geodes[other],'second cell sealed')
  local c=dig.cube.cells[other]
  pl.Character:PivotTo(CFrame.new(dig.origin+Vector3.new(c.cx+40,c.y1+3,c.cz)))
  scene.digRequestOpen(p,{id=other})
  assert(dig.geodes[other],'a request from far away is refused')
  pl.Character:PivotTo(CFrame.new(dig.origin+Vector3.new(c.cx,c.y1+3,c.cz)))
  scene.digRequestOpen(p,{id=other})
  assert(dig.geodes[other]==nil and dig.cube.removed[other],'the owner landing (client request) opens it at once')
 end
end
pl.Character:PivotTo(savedRoot)
do
 local near=0
 for id in pairs(dig.cube.removed) do
  local c=dig.cube.cells[id]
  if (c.cx-W*.3)^2+(c.cz-W*.3)^2<22*22 then near+=1 end
 end
 assert(near>=(dig.cube.removedCount-1)*.7,'crew digs around the player: '..near..'/'..dig.cube.removedCount)
end
-- A gem waits for the reveal pause.
do
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
end
-- Chunk size: the slot-4 Striker cuts huge chunks, slot 1 tiny ones; upgrades grow them.
local d1=p.drones[1]
do
 local function avg(slot,cut)
  local saved=d1.slot;d1.slot=slot;d1.stats.cutSize=cut
  local n=0
  for _=1,8 do local job=scene.digPick(d1,p);n+=#job.ids;for _,id in ipairs(job.ids) do dig.claimed[id]=nil end end
  d1.slot=saved;d1.stats.cutSize=1
  return n/8
 end
 local tiny,huge,upgraded=avg(1,1),avg(4,1),avg(1,2)
 assert(huge>tiny*2,'huge-chunk drones take bigger chunks: '..huge..' vs '..tiny)
 assert(upgraded>tiny,'cut-size upgrades grow chunks')
end
-- A tap out of reach does not pull the crew away from the player.
local far=dig.origin+Vector3.new(W*.85,dig.cube.height,W*.85)
do
 p.tokens=10;p.bucketAt=now
 command.OnServerEvent:Fire(pl,'DigFocus',{point=far})
 local job=scene.digPick(d1,p)
 local l=pl.Character.HumanoidRootPart.Position-dig.origin
 assert(job and math.sqrt((job.cx-l.X)^2+(job.cz-l.Z)^2)<DigCube.MINE_RADIUS+6,'far taps are ignored')
 for _,id in ipairs(job.ids) do dig.claimed[id]=nil end
end
-- Walk to the far corner: the crew's next cuts move there with you.
do
 pl.Character:PivotTo(CFrame.new(far+Vector3.new(0,3,0)))
 local seen={};for id in pairs(dig.cube.removed) do seen[id]=true end
 local function freshCount() local f=0;for id in pairs(dig.cube.removed) do if not seen[id] then f+=1 end end;return f end
 for _=1,900 do tick(10);if freshCount()>=5 then break end end
 local moved,fresh=0,0
 for id in pairs(dig.cube.removed) do
  if not seen[id] then fresh+=1;local c=dig.cube.cells[id];if (c.cx-W*.85)^2+(c.cz-W*.85)^2<24*24 then moved+=1 end end
 end
 assert(fresh>=3 and moved>=fresh*.7,'walking moves the crew: '..moved..'/'..fresh)
end
-- Walk away: the crew is released.
pl.Character:PivotTo(CFrame.new(Vector3.new(0,6,10)))
tick(10)
assert(not p.digging and p.digLeftAt,'leaving the cube ends digging (and is stamped)')
for _,d in ipairs(p.drones) do assert(d.digJob==nil,'drone released') end
-- A spent cube starts over.
for _,c in ipairs(dig.cube.cells) do DigCube.remove(dig.cube,c.id) end
dig.checkAt=0
tick(5)
tick(math.ceil(5/C.Tick))
assert(holder:GetAttribute('Generation')==2 and dig.cube.removedCount==0 and holder:GetAttribute('OpCount')==0,'a dug-out cube is replaced')
print('PASS dig cube server: solid rock, Striker chunks (~L), stages, rock dust, ops replay through parseOp/applyOp, treasure seals and opens, reveal pause, chunk sizes, walking moves the crater, leaving releases, spent cube resets')

-- ===== Every worker role digs alone (spec 7.2.2, 7.2.3) =====
local pl2=player(4814)
players.PlayerAdded:Fire(pl2)
local p2=profiles[pl2.UserId]
pl2.Character:PivotTo(CFrame.new(Vector3.new(-20,6,-20)))
local spot=dig.origin+Vector3.new(W*.3,dig.cube.height+3,W*.3)
local function stateFolder() return workspace:FindFirstChild('DroneRoleState') end
local recordSeen={}
local function scanRecords(stats)
 local folder=stateFolder();if not folder then return end
 for _,node in ipairs(folder:GetChildren()) do
  if not recordSeen[node] then
   recordSeen[node]=true
   local kind=node:GetAttribute('Kind')
   if stats and kind=='MiningShot' and node:GetAttribute('Dig')==true then stats.shapes[node:GetAttribute('Shape')]=true end
   if stats and kind=='Breaker' then local phase=node:GetAttribute('Phase');stats.breakers[phase]=(stats.breakers[phase] or 0)+1 end
  end
  -- The Debris double does nothing: retire what Debris would (timed records
  -- and shots that made contact), so the 256-record cap is never reached.
  if node:GetAttribute('ContactAt') or node:GetAttribute('ExpiresAt') then node:Destroy() end
 end
end
local function liveShots()
 local n=0
 local folder=stateFolder()
 for _,node in ipairs(folder and folder:GetChildren() or {}) do
  if node:GetAttribute('Kind')=='MiningShot' and node:GetAttribute('Dig')==true and not node:GetAttribute('ContactAt') then n+=1 end
 end
 return n
end
local function freshCube()
 scene.digRelease(p)
 local folder=stateFolder()
 if folder then for _,c in ipairs(folder:GetChildren()) do c:Destroy() end end
 dig.random=Random.new(9157)
 scene.digReset()
 pl.Character:PivotTo(CFrame.new(spot))
end
local function useCrew(roles,slot)
 local keep={}
 local names={};for r in pairs(roles) do table.insert(names,r) end;table.sort(names)
 for _,owned in ipairs(roleTestFleet(p,nil,names)) do if roles[owned.role] then table.insert(keep,owned) end end
 p.testFleet=keep;rebuildFleet(p)
 if slot then p.drones[1].slot=slot end
 pl.Character:PivotTo(CFrame.new(spot))
end
do
 local crew=roleTestFleet(p,nil,true)
 local order={}
 for _,owned in ipairs(crew) do table.insert(order,owned.role) end
 -- A small random crew: the real first miner plus 3 different dig roles, named.
 local seen={}
 for i,r in ipairs(order) do assert(not seen[r] and (i==1 or r~='Striker'),'distinct dig crew roles: '..table.concat(order,','));seen[r]=true end
 assert(#order==4 and order[1]=='Striker','dig crew of 4: '..table.concat(order,','))
 local label=pl:GetAttribute('MA_TestLoadoutLabel')
 assert(crew[1].id==data(p).fleet[1].id and string.sub(label,1,10)=='Dig crew: ','the real first miner leads the dig crew: '..tostring(label))
end
local function gemCount() local n=0;for _ in pairs(dig.gems) do n+=1 end;return n end
local rocks=0
local realRock=scene.digRock
scene.digRock=function(pp,owner,ids,count,...) if owner==pl.UserId then rocks+=count end;return realRock(pp,owner,ids,count,...) end
local RUN=2400
local function runRole(role,slot)
 freshCube()
 useCrew({[role]=true},slot)
 local style=DigCube.style(role)
 local d=p.drones[1]
 assert(#p.drones==1 and d.role==role,'a crew of one '..role)
 local stats={role=role,shapes={},breakers={},dive=false,brittle=false,hints=nil,digMining=false,badKey=nil,pulse0=d.minePulseSerial}
 local gems0=gemCount();rocks=0
 for _=1,RUN do
  tick(1)
  scanRecords(stats)
  local m=d.model
  local key=m:GetAttribute('DigOp')
  if type(key)=='string' and key~='' and (not string.match(key,'^c[%d%.]+~%u$') or string.sub(key,-1)~=style.code) then stats.badKey=key end
  if m:GetAttribute('State')=='BreakerDive' then stats.dive=true end
  if m:GetAttribute('DigMining')==true then stats.digMining=true end
  if (holder:GetAttribute('Brittle') or '')~='' then stats.brittle=true end
  local h=pl:GetAttribute('DigHints');if type(h)=='string' and h~='' then stats.hints=h end
 end
 local minutes=RUN*C.Tick/60
 local vol=0
 for id in pairs(dig.cube.removed) do vol+=DigCube.cellVolume(dig.cube,id) end
 local breaks,last,consecutive=0,0,false
 for _,entry in ipairs(dig.ops) do
  local op=parsed(entry)
  assert(op.code==style.code or op.geode,role..' runs alone, so every op carries its code: '..entry)
  if isFinal(op) then breaks+=1 end
  if op.flag=='C' then
   if op.seq==last+1 and last>=1 then consecutive=true end
   last=op.seq
  end
 end
 stats.volume=vol/minutes;stats.breaks=breaks/minutes;stats.gems=(gems0-gemCount())/minutes;stats.rocks=rocks/minutes
 stats.finals=breaks;stats.consecutive=consecutive;stats.pulses=d.minePulseSerial-stats.pulse0
 stats.d=d
 return stats
end
local results={}
local base=runRole('Striker',2)
results.Striker=base
assert(base.finals>0 and base.volume>0,'the medium Striker baseline digs')
for _,role in ipairs({'Lancer','Charger','Ballcaster','Needler','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator','Ramiel','Nomad'}) do
 local s=runRole(role)
 results[role]=s
 local style=DigCube.style(role)
 assert(s.finals>0,role..' makes at least one final op with code '..style.code)
 assert(s.badKey==nil,role..' publishes DigOp as c<ids>~'..style.code..': '..tostring(s.badKey))
 assert(s.digMining==(style.kernel=='beam'),role..' DigMining only for beam roles')
 if style.shape then
  assert(s.shapes[style.shape],role..' fires Dig MiningShot records shaped '..style.shape)
  -- Release in the middle of a live shot: no uncontacted dig record stays.
  for _=1,900 do if liveShots()>0 then break end;tick(1);scanRecords(s) end
  assert(liveShots()>0,role..' has a shot in flight to release')
  scene.digRelease(p)
  assert(liveShots()==0,role..': releasing the crew leaves no dig shot without contact')
 end
 if role=='Charger' then
  assert(s.dive,'Charger dives (State BreakerDive)')
  assert((s.breakers.Windup or 0)>0 and (s.breakers.Dive or 0)>0,'Charger emits Windup and Dive beats')
  assert((s.breakers.Impact or 0)==0 and (s.breakers.Hold or 0)==0 and (s.breakers.Recover or 0)==0,'Charger never emits Impact/Hold/Recover records in the dig')
 elseif role=='Gridcutter' then
  assert(s.pulses>=3,'Crescent (Gridcutter) slashes as pulses (MinePulseSerial): '..s.pulses)
 elseif role=='Resonator' then
  assert(s.pulses>=2,'Stormcaller (Resonator) strikes as pulses (MinePulseSerial): '..s.pulses)
 elseif role=='Frostbite' then
  assert(s.brittle,'Frostbite leaves brittle cells (holder Brittle)')
 elseif role=='Needler' then
  assert(s.hints,'Needler hints at nearby gems (DigHints)')
  for part in string.gmatch(s.hints,'[^;]+') do
   local key,id,tier=string.match(part,'^([%-%d]+_[%-%d]+):(%d+):(%d+)$')
   assert(key=='0_0','DigHints names the chunk: '..part)
   assert(id and tonumber(tier)>=1 and tonumber(tier)<=#DigCube.ORES,'DigHints parses: '..s.hints)
  end
  assert((pl2:GetAttribute('DigHints') or '')=='','DigHints only on the owner Player')
 elseif role=='Lancer' then
  assert(s.pulses>=3,'Lancer fires pulses (MinePulseSerial): '..s.pulses)
 end
end
do
 local lines={string.format('%-12s %9s %6s %10s %9s %9s','role','vol/min','x base','breaks/min','gems/min','rock/min')}
 for _,role in ipairs({'Striker','Lancer','Charger','Ballcaster','Needler','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator','Ramiel','Nomad'}) do
  local s=results[role]
  local ratio=s.volume/base.volume
  table.insert(lines,string.format('%-12s %9.0f %6.2f %10.1f %9.2f %9.1f',role..(role=='Striker' and '(2)' or ''),s.volume,ratio,s.breaks,s.gems,s.rocks))
 end
 print('Throughput per role, one drone for '..(RUN*C.Tick)..' s on the same cube (API doubles, not a playtest):\n'..table.concat(lines,'\n'))
 for role,s in pairs(results) do
  local ratio=s.volume/base.volume
  assert(ratio>=.45 and ratio<=1.8,role..' rock volume/min is '..string.format('%.2f',ratio)..'x the medium Striker (band .45-1.8)')
 end
end
print('PASS 14 roles: own op codes, Dig shots released cleanly, Charger dive without Impact records, Crescent/Stormcaller pulses, Starfall star shots, Frostbite brittle, Needler hints, Lancer pulses, volume/min within .45-1.8x')

-- ===== Replay with every role at work (spec 7.2.5) =====
freshCube()
useCrew({Striker=true,Lancer=true,Charger=true,Ballcaster=true,Needler=true,Bubbler=true,Halver=true,Gridcutter=true,Singularity=true,Starforge=true,Frostbite=true,Resonator=true,Ramiel=true,Nomad=true})
assert(#p.drones==14,'the whole dig crew')
do
 local codes={}
 for _=1,1800 do
  tick(1);scanRecords(nil)
  for _,d in ipairs(p.drones) do
   local key=d.model:GetAttribute('DigOp')
   assert(type(key)=='string' and (key=='' or string.match(key,'^c[%d%.]+~%u$')),'DigOp format: '..tostring(key))
  end
 end
 tick(4)
 for _,entry in ipairs(dig.ops) do local op=parsed(entry);if op.code then codes[op.code]=true end end
 local n=0;for _ in pairs(codes) do n+=1 end
 assert(n>=10,'most roles broke rock together: '..n)
 replayMatches('every role, replayed')
 -- Regular cells never float: every cell left (not a sealed gem) above the
 -- bottom layer still rests on rock under its middle.
 local cube=dig.cube
 for id,c in ipairs(cube.cells) do
  if not cube.removed[id] and not (cube.sealed and cube.sealed[id]) and c.layer<#cube.layers then
   assert(DigCube.supported(cube,id,0),'cell '..id..' (layer '..c.layer..') floats')
   -- and at least RESTING_SHARE of it sits on rock (owner, Nov 22: no floating cells at all)
   assert(DigCube.resting(cube,id),'cell '..id..' (layer '..c.layer..') barely rests on rock')
  end
 end
 do
  local fallen,breaks=0,0
  for _,entry in ipairs(dig.ops) do local op=parsed(entry);if op and not op.partial then breaks+=1 end end
  print(string.format('PASS nothing floats: every regular cell left rests at least %d%% on rock (%d break ops)',math.floor(DigCube.RESTING_SHARE*100),breaks))
 end
 -- Nothing on the holder or the drones names a gem cell before it breaks.
 local allowed={Origin=true,Width=true,Height=true,Seed=true,Generation=true,OpCount=true,Geodes=true,Brittle=true,CarveLag=true,Chunk=true,Rendered=true}
 for name in pairs(holder:GetAttributes()) do assert(allowed[name] or string.match(name,'^Ops%d+$'),'unexpected holder attribute '..name) end
 for part in string.gmatch(holder:GetAttribute('Geodes') or '','[^;]+') do
  local id=tonumber(string.match(part,'^(%d+):'))
  assert(id and dig.geodes[id] and not dig.gems[id],'Geodes lists only sealed cells: '..part)
 end
 for _,d in ipairs(p.drones) do
  for name in pairs(d.model:GetAttributes()) do assert(not string.find(name,'Gem') and not string.find(name,'Hint'),'no gem attribute on drones: '..name) end
 end
 for _,d in ipairs(p.drones) do
  local style=DigCube.style(d.role)
  assert(style.role==d.role,'every dig crew role has a style: '..d.role)
 end
end
print('PASS replay: every op of 14 roles parses and replays (applyOp) to exactly the server removed set; no attribute reveals unsealed gem cells')

-- ===== Gems (spec 2 and 7.2.4) =====
freshCube()
useCrew({Ballcaster=true})
pl.Character:PivotTo(CFrame.new(Vector3.new(0,6,10)))
tick(2)
assert(not p.digging,'owner off the cube for the direct gem checks')
do
 local cube=dig.cube
 local d=p.drones[1]
 local function oneCell(id,code,style)
  return {ids={id},left={id},key=tostring(id),code=code,style=style,kernel=style.kernel,cx=cube.cells[id].cx,cz=cube.cells[id].cz,hp=0,maxHp=1,volume=DigCube.cellVolume(cube,id),volFrac=0}
 end
 local used={}
 local function freshTop()
  for _,id in ipairs(cube.layers[1].cells) do
   local c=cube.cells[id]
   if not used[id] and not cube.removed[id] and not (cube.sealed and cube.sealed[id]) and not dig.gems[id] and c.cx>12 and c.cx<W-12 and c.cz>12 and c.cz<W-12 then
    -- Keep the test cells apart (no shared neighbours).
    used[id]=true;for _,n in ipairs(c.neighbors) do used[n]=true end
    return id
   end
  end
  error('no fresh top cell')
 end
 local B=DigCube.STYLES.Ballcaster
 -- A one-cell gem: K only, the cell stays, Geodes lists it.
 local g1=freshTop();dig.gems[g1]={tier=2,count=1,treasure=false}
 local n=#dig.ops
 assert(scene.digBreak(oneCell(g1,'B',B),d,p)==1,'the gem cell seals')
 assert(#dig.ops==n+1 and dig.ops[#dig.ops]=='c'..g1..'~B|2|K','one-cell seal: '..tostring(dig.ops[#dig.ops]))
 assert(not cube.removed[g1] and cube.sealed[g1] and dig.gems[g1]==nil,'no removal; the gem leaves the secret list')
 assert(string.find(';'..holder:GetAttribute('Geodes')..';',';'..g1..':2:'..pl.UserId..':0;',1,true),'the Geodes attribute lists it')
 -- A multi-cell job with one gem: E<id> then K.
 local seed=freshTop()
 local ids=DigCube.chunk(cube,seed,1.6,{[g1]=true},function() return .9 end)
 assert(#ids>=2,'a multi-cell chunk')
 for _,id in ipairs(ids) do dig.gems[id]=nil;used[id]=true;for _,nb in ipairs(cube.cells[id].neighbors) do used[nb]=true end end
 local gem=ids[2];dig.gems[gem]={tier=3,count=1,treasure=false}
 local L=DigCube.STYLES.Striker
 n=#dig.ops
 scene.digBreak({ids=ids,left=table.clone(ids),key=DigCube.key(ids),code='L',style=L,kernel='beam',cx=0,cz=0,hp=0,maxHp=1,volume=DigCube.volume(cube,ids),volFrac=0,rock=1,rockPaid=0},d,p)
 assert(dig.ops[n+1]==DigCube.formatOp(ids,'L',0,'E',gem) and dig.ops[n+2]=='c'..gem..'~L|3|K' and #dig.ops==n+2,'E<id> then K: '..tostring(dig.ops[n+1])..' / '..tostring(dig.ops[n+2]))
 for _,id in ipairs(ids) do assert((id==gem)==(not cube.removed[id]),'the other cells break, the gem cell stays') end
 local e=parsed(dig.ops[n+1])
 assert(e.except[gem] and #e.removes==#ids-1,'E removes the cells minus the sealed one')
 -- Drones never break a gem open (owner, Nov 22): every gem seals, no cap.
 local g3,g4=freshTop(),freshTop()
 for _,id in ipairs({g3,g4}) do dig.gems[id]={tier=1,count=1,treasure=false};assert(scene.digBreak(oneCell(id,'B',B),d,p)==1,'seal') end
 local fifth=freshTop();dig.gems[fifth]={tier=4,count=1,treasure=false}
 local pending=#dig.pending
 assert(scene.digBreak(oneCell(fifth,'B',B),d,p)==1,'a fifth live gem still seals')
 assert(#dig.pending==pending and not cube.removed[fifth] and dig.geodes[fifth],'nothing bursts out on its own')
 local multi={}
 for k=1,4 do local id=freshTop();dig.gems[id]={tier=1,count=1,treasure=false};table.insert(multi,id) end
 assert(scene.digBreak({ids=multi,left=table.clone(multi),key=DigCube.key(multi),code='L',style=L,kernel='beam',cx=0,cz=0,hp=0,maxHp=1,volume=1,volFrac=0,rock=1,rockPaid=0},d,p)==4,'four gems in one break all seal')
 -- A treasure gem still seals, over the cap.
 local tid2=next(cube.treasure)
 assert(dig.gems[tid2] and dig.gems[tid2].treasure,'treasure gem placed')
 assert(scene.digBreak(oneCell(tid2,'B',B),d,p)==1 and dig.geodes[tid2] and dig.geodes[tid2].treasure and dig.geodes[tid2].count==DigCube.TREASURE_GEMS,'a treasure gem always seals')
 -- Its owner gone (a stale profile): that geode goes public (owner 0).
 p.digging=true
 dig.geodes[g3].p={};tick(1)
 assert(dig.geodes[g3].owner==0 and dig.geodes[g3].p==nil,'a geode whose owner left goes public')
 assert(dig.geodes[g1].owner==pl.UserId,'the others stay owned while the owner digs')
 assert(string.find(holder:GetAttribute('Geodes'),g3..':1:0:0',1,true),'Geodes publishes owner 0')
 -- The owner stopped digging 90 s ago: the rest go public too.
 tick(1)
 assert(not p.digging,'off the cube')
 p.digLeftAt=now-91
 tick(1)
 assert(dig.geodes[g1].owner==0 and dig.geodes[g1].p==nil,'an idle owner\'s geodes go public')
 -- A second player lands on a public geode: it opens for them and pays them.
 local c=cube.cells[g1]
 pl2.Character:PivotTo(CFrame.new(dig.origin+Vector3.new(c.cx,c.y1+3,c.cz)))
 pl2.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.new(0,-20,0)
 local pickups=root:FindFirstChild('OrePickups')
 local before={};for _,x in ipairs(pickups:GetChildren()) do before[x]=true end
 tick(1)
 pl2.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
 assert(dig.geodes[g1]==nil and cube.removed[g1],'the second player opened the public geode')
 local opened=false
 for i=#dig.ops,1,-1 do local o=parsed(dig.ops[i]);if o.cells[1]==g1 and o.flag=='G' and o.code==nil then opened=true;break end end
 assert(opened,'opening op c<id>|tier|G')
 tick(math.ceil(.2/C.Tick))
 local paid=false
 for _,x in ipairs(pickups:GetChildren()) do if not before[x] and x:GetAttribute('Owner')==pl2.UserId then paid=true end end
 assert(paid,'the gem is paid to the player who opened it')
 pl2.Character:PivotTo(CFrame.new(Vector3.new(-20,6,-20)))
 tick(1)
 -- A cube reset pays the sealed gems still owned by a present player.
 p.digLeftAt=nil
 local g6=freshTop();dig.gems[g6]={tier=2,count=1,treasure=false}
 assert(scene.digBreak(oneCell(g6,'B',B),d,p)==1 and dig.geodes[g6].owner==pl.UserId,'a fresh owned geode')
 local units=Pro.cargoUnits(data(p))
 local owned=0;for _,g in pairs(dig.geodes) do if g.owner==pl.UserId and g.p==p then owned+=g.count end end
 scene.digReset()
 assert(Pro.cargoUnits(data(p))==units+owned,'cube reset pays the owner\'s sealed gems: '..Pro.cargoUnits(data(p))..' vs '..(units+owned))
end
print('PASS gems: one-cell seal emits K only, multi-cell E<id>+K, every gem seals (no cap: drones never break one open), treasure always seals, idle/left owners make geodes public, another player opens and is paid, cube reset pays sealed gems')

-- ===== Carve-ahead (spec 3.5.3, 7.2.6) =====
freshCube()
dig.gems={}
useCrew({Ballcaster=true})
do
 local d=p.drones[1]
 local carvedAt={}
 local realCarve=scene.digCarve
 scene.digCarve=function(job) for _,id in ipairs(job.ids) do if carvedAt[id]==nil then carvedAt[id]=#dig.ops end end;return realCarve(job) end
 local job
 for _=1,1200 do tick(1);scanRecords(nil);job=d.digJob;if job and job.lockAt and now>=job.lockAt+.3 then break end end
 assert(job and job.lockAt and job.committed,'a Ballcaster commits its shot .25 s after the lock')
 local id=job.ids[1]
 assert(dig.carved[id] and carvedAt[id]~=nil,'its cell is carved ahead of the break')
 for _,entry in ipairs(dig.ops) do assert(not table.find(parsed(entry).removes,id),'carved before any break op for it') end
 -- Walk far away (still on the cube): the committed shot still lands, at once.
 pl.Character:PivotTo(CFrame.new(dig.origin+Vector3.new(W*.92,dig.cube.height+3,W*.92)))
 tick(1)
 local broke=false
 for _,entry in ipairs(dig.ops) do local op=parsed(entry);if isFinal(op) and table.find(op.removes,id) and op.code=='B' then broke=true end end
 assert(broke and dig.cube.removed[id] and not dig.carved[id],'walking away from a committed job breaks it on the next tick')
 assert(liveShots()==0,'and leaves no live shot')
 scene.digCarve=realCarve
 -- A forced rebuild keeps carved-ahead cells and stage pits cut.
 local cube=dig.cube
 local cid
 for _,cell in ipairs(cube.layers[1].cells) do if not cube.removed[cell] then local c=cube.cells[cell];if c.cx>20 and c.cx<30 and c.cz>60 and c.cz<70 then cid=cell;break end end end
 assert(cid,'a cell to carve ahead')
 dig.carved[cid]=true
 local sid
 for _,cell in ipairs(cube.layers[1].cells) do if not cube.removed[cell] then local c=cube.cells[cell];if c.cx>60 and c.cx<70 and c.cz>15 and c.cz<25 then sid=cell;break end end end
 local chunk=DigCube.chunk(cube,sid,1.9,nil,function() return .9 end)
 local pieces=DigCube.pieces(cube,chunk)
 assert(#pieces>=2,'a terrace chunk')
 local entry={ids=chunk,parts=pieces[1].parts}
 table.insert(dig.stageParts,entry)
 local prism,part=DigCube.prismWedges,DigCube.partWedges
 local loggedIds,loggedParts={},{}
 DigCube.prismWedges=function(c,ids,...) for _,x in ipairs(ids) do loggedIds[x]=true end;return prism(c,ids,...) end
 DigCube.partWedges=function(c,parts,...) for _,x in ipairs(parts) do loggedParts[x]=true end;return part(c,parts,...) end
 local function rebuildAt(x,z,layer)
  scene.digSplitColumns(dig,Vector3.new(x-.1,0,z-.1),Vector3.new(x+.1,0,z+.1))
  local L=cube.layers[layer]
  for i,b in ipairs(dig.blocks) do
   if b.lo.X<=x and b.hi.X>=x and b.lo.Z<=z and b.hi.Z>=z and math.abs(b.lo.Y-L.y0)<.01 then
    local out=scene.digRebuildBlock(b,{},0)
    table.remove(dig.blocks,i)
    for _,nb in ipairs(out) do table.insert(dig.blocks,nb) end
    return true
   end
  end
  return false
 end
 local cc=cube.cells[cid]
 assert(rebuildAt(cc.cx,cc.cz,1),'a block over the carved cell')
 assert(loggedIds[cid],'a rebuild subtracts cells carved ahead')
 local q=pieces[1].parts[1]
 local px,pz=0,0;for _,v in ipairs(q.poly) do px+=v[1];pz+=v[2] end;px/=#q.poly;pz/=#q.poly
 assert(rebuildAt(px,pz,1),'a block over the stage pit')
 assert(loggedParts[q],'a rebuild subtracts the remembered stage parts')
 DigCube.prismWedges,DigCube.partWedges=prism,part
 dig.carved[cid]=nil;table.remove(dig.stageParts,table.find(dig.stageParts,entry))
end
print('PASS carve-ahead: a committed Ballcaster cell is carved before its break op, walking away still breaks it next tick, rebuilds keep carved cells and stage pits')

-- ===== Carve-ahead for beam, slam and pulse roles (owner, Nov 22: the
-- rubble came before the hole): every stage pit and every final cell is cut
-- in an earlier tick than its break op, about the carve lead before it.
for _,role in ipairs({'Striker','Charger','Lancer','Singularity'}) do
 freshCube()
 dig.gems={}
 useCrew({[role]=true},role=='Striker' and 3 or nil)
 local style=DigCube.style(role)
 local cellAt,partAt={},{}
 local function sig(part) return string.format('%d:%.3f:%.3f:%.3f',part.cell or 0,part.y0,part.y1,part.poly[1][1]+part.poly[1][2]) end
 local realCarve=scene.digCarve
 scene.digCarve=function(job)
  for _,id in ipairs(job.ids) do if cellAt[id]==nil then cellAt[id]=now end end
  for _,part in ipairs(job.parts or {}) do local k=sig(part);if partAt[k]==nil then partAt[k]=now end end
  return realCarve(job)
 end
 local seen=#dig.ops
 local stages,finals,early,leads=0,0,0,{}
 -- One-piece types (pieces 'none') break once per chunk: run longer.
 local terrace=style.pieces=='terrace'
 for _=1,(terrace and 1800 or 4200) do
  tick(1);scanRecords(nil)
  while seen<#dig.ops do
   seen+=1
   local op=parsed(dig.ops[seen])
   if op.flag=='S' then
    stages+=1
    local piece=DigCube.pieces(dig.cube,op.cells,style.pieces)[op.stage]
    local first=math.huge
    for _,part in ipairs(piece.parts) do first=math.min(first,partAt[sig(part)] or math.huge) end
    if first<now then early+=1;table.insert(leads,now-first) end
   elseif isFinal(op) then
    finals+=1
    local first=math.huge
    for _,id in ipairs(op.removes) do first=math.min(first,cellAt[id] or math.huge) end
    if first<now then early+=1;table.insert(leads,now-first) end
   end
  end
 end
 scene.digCarve=realCarve
 local total=stages+finals
 table.sort(leads)
 local median=leads[math.max(1,math.ceil(#leads/2))] or 0
 assert(total>=(terrace and 4 or 2),role..' breaks something: '..total)
 assert(early>=total*.9,string.format('%s: %d/%d breaks carved ahead',role,early,total))
 assert(median>=.45,string.format('%s: median carve lead %.2f s',role,median))
 print(string.format('  %-12s %2d stages %2d finals, %d carved ahead, median lead %.2f s',role,stages,finals,early,median))
end
print('PASS carve-ahead for beam, slam and pulse: every stage pit and final cut is queued before its break op, near the carve lead (API doubles: real CSG time NOT measured)')

-- ===== Strict vertical overlap (spec 3.5.1, 7.2.7) =====
freshCube()
useCrew({Striker=true})
pl.Character:PivotTo(CFrame.new(Vector3.new(0,6,10)))
tick(2)
do
 local cube=dig.cube
 local id
 for _,cell in ipairs(cube.layers[1].cells) do if not cube.removed[cell] and not dig.gems[cell] then id=cell;break end end
 cutLog={}
 local L=DigCube.STYLES.Striker
 scene.digBreak({ids={id},left={id},key=tostring(id),code='L',style=L,kernel='beam',cx=0,cz=0,hp=0,maxHp=1,volume=DigCube.cellVolume(cube,id),volFrac=0,rock=1,rockPaid=0},p.drones[1],p)
 local log=cutLog;cutLog=nil
 assert(#log>=1 and #log<=4,'a top-layer cell break cuts 1-4 blocks: '..#log)
 for _,cut in ipairs(log) do assert(cut.y0>=cube.layers[1].y0-.01,'no layer-2 block is cut (block bottom '..cut.y0..')') end
end
print('PASS strict Y: a top-layer cell break cuts at most 4 blocks, none below its layer')

-- ===== Publish timing (spec 3.5.2, 7.2.8) =====
freshCube()
useCrew({Striker=true,Bubbler=true,Halver=true,Gridcutter=true,Resonator=true})
do
 local times,last={},holder:GetAttribute('OpCount')
 for _=1,1200 do
  tick(1)
  local count=holder:GetAttribute('OpCount')
  if count~=last then table.insert(times,now);last=count end
 end
 assert(#times>=5,'ops publish: '..#times)
 for i=2,#times do assert(times[i]-times[i-1]>=1/30-1e-6,'at most 30 publishes a second: '..(times[i]-times[i-1])) end
 local forced=false
 for _=1,1200 do
  tick(1)
  if now+C.Tick>dig.publishAt+1e-6 and not dig.dirty then
   for _,d in ipairs(p.drones) do
    local job=d.digJob
    if job and job.kernel=='beam' and d.state=='Mine' and job.hp>0 then
     local before=#dig.ops;local key=d.model:GetAttribute('DigOp')
     job.hp=1e-9
     tick(1)
     assert(#dig.ops>before,'the forced break happens in this tick')
     assert(holder:GetAttribute('OpCount')==#dig.ops,'an op made in tick t is published in tick t')
     assert(d.model:GetAttribute('DigOp')~=key,'the drone\'s next DigOp is published in the same tick, after the op')
     forced=true;break
    end
   end
  end
  if forced then break end
 end
 assert(forced,'found a beam drone mid-cut to force a break')
end
scene.digRock=realRock
print('PASS publish: an op made in tick t raises OpCount in tick t with the DigOp change, publishes at most every 1/30 s (API doubles; carving, looks, feel and multiplayer NOT verified)')
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
