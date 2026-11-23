#!/usr/bin/env python3
"""The client side of the chunked dig field: DigCubeView.new makes the field
view, which keeps one chunk view per DigField holder near the character (a
rendered chunk within FIELD.VIEW, an untouched one within FIELD.VIEW_IDLE),
builds each chunk from the world seed and its coordinates (spread over
frames, the same cells as the server), replays the ops published before it
saw the chunk, routes each drone's beam to its DigChunk (else the chunk under
it) and drops views when their holder goes or the character walks away.
Run on the real DigCubeView bundle with the Roblox doubles of
test_rock_chunks.py. Not engine QA: effects, frame time and memory on a
device need a Studio Play check.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from build import ROOT, module_bundle

luau = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/mining-away-luau") / "luau"
doubles = re.search(r"doubles = r'''(.*?)'''", (ROOT / "tools/test_rock_chunks.py").read_text(), re.S).group(1)
doubles += "\ntask.wait=function() end\n"

checks = r'''
local DigCube=DigCubeView.DigCube
local FIELD=DigCube.FIELD
local W=DigCube.WIDTH
local WS=424242
local world=Instance.new('Folder');world.Name='MiningAway';world.Parent=workspace
local folder=Instance.new('Folder');folder.Name='DigField';folder:SetAttribute('WorldSeed',WS);folder.Parent=world
local function holder(i,j,rendered,ops)
 local h=Instance.new('Folder');h.Name='C'..DigCube.chunkKey(i,j)
 local x0,z0=DigCube.chunkCorner(i,j)
 h:SetAttribute('Chunk',DigCube.chunkKey(i,j));h:SetAttribute('Seed',DigCube.chunkSeed(WS,i,j,1));h:SetAttribute('Generation',1)
 h:SetAttribute('Origin',Vector3.new(x0,DigCube.CENTER[2],z0));h:SetAttribute('Rendered',rendered)
 h:SetAttribute('OpCount',ops and #ops or 0)
 if ops then h:SetAttribute('Ops1',table.concat(ops,';')) end
 h.Parent=folder
 return h
end
-- The character stands 20 studs inside the west edge of chunk (2,0).
local x0,z0=DigCube.chunkCorner(2,0)
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Position=Vector3.new(x0+20,DigCube.GROUND+3,z0+W/2)
local character=Instance.new('Model');character.Name='Character';root.Parent=character
Players.LocalPlayer={UserId=7,Character=character,GetAttribute=function() return nil end,SetAttribute=function() end,
 GetAttributeChangedSignal=function() return {Connect=function() return {Disconnect=function() end} end} end}
-- Two cells of chunk (2,0) were cut before this client arrived.
local server=DigCube.buildChunk(WS,2,0,1)
local cutA,cutB=server.layers[1].cells[3],server.layers[1].cells[40]
local here=holder(2,0,true,{DigCube.formatOp({cutA},'L',0),DigCube.formatOp({cutB},'L',0)})
local west=holder(1,0,true)        -- rendered, 20 studs away
local east=holder(3,0,false)       -- untouched, 68 studs away: not built
local far=holder(9,9,true)         -- rendered, far away
local fired={}
local field=DigCubeView.new({world=world,command={FireServer=function(_,...) table.insert(fired,{...}) end},reduced=function() return false end})
assert(getmetatable(field)==DigCubeView.Field,'DigCubeView.new makes the field view')
field:scan()
local keys={}
for key in pairs(field.views) do table.insert(keys,key) end
table.sort(keys)
assert(table.concat(keys,',')=='1_0,2_0','views for the chunk underfoot and the rendered neighbour only: '..table.concat(keys,','))
for key,view in pairs(field.views) do
 local i,j=DigCube.parseChunkKey(key)
 local ref=DigCube.buildChunk(WS,i,j,1)
 assert(view.cube and view.cube.seed==view.holder:GetAttribute('Seed'),'chunk '..key..' builds the server seed')
 assert(#view.cube.cells==#ref.cells,'chunk '..key..' has the same cells')
 for id,c in ipairs(ref.cells) do
  local o=view.cube.cells[id]
  assert(o.layer==c.layer and o.cx==c.cx and o.cz==c.cz and #o.poly==#c.poly,'chunk '..key..' cell '..id..' matches the server')
 end
 assert((view.origin-view.holder:GetAttribute('Origin')).Magnitude<1e-9,'view origin')
end
assert(not field.building,'builds run one at a time and release the lock')
local v=field.views['2_0']
assert(v.cube.removed[cutA] and v.cube.removed[cutB] and v.cube.removedCount==2 and v.applied==2,'ops published before the client saw the chunk are replayed')
assert(not v.pad and not field.views['1_0'].pad,'only the Plot 1 chunk builds the launch pad')
-- Beams go to the drone's DigChunk, else to the chunk under it.
local drone=Instance.new('Model');drone:SetAttribute('DroneId','d1');drone:SetAttribute('DigChunk','1_0')
assert(field:viewFor(drone,root.Position)==field.views['1_0'],'a digging drone\'s beam goes to its DigChunk')
drone:SetAttribute('DigChunk','')
assert(field:viewFor(drone,root.Position)==field.views['2_0'],'an idle drone\'s beam goes to the chunk under it')
assert(field:viewFor(drone,Vector3.new(x0+W*7,0,z0))==nil,'no view, no beam')
-- The holder goes (the server dropped the chunk): so does its view.
west.Parent=nil
field:scan()
assert(field.views['1_0']==nil,'a dropped chunk\'s view goes')
-- Walking up to the untouched chunk builds it once within VIEW_IDLE.
root.Position=Vector3.new(x0+W-10,DigCube.GROUND+3,z0+W/2)
field:scan()
assert(field.views['3_0'] and field.views['3_0'].cube,'an untouched chunk is built once the character is within VIEW_IDLE')
-- Walking far away drops every view; the far chunk only builds when near.
root.Position=Vector3.new(x0+W*30,DigCube.GROUND+3,z0)
field:scan()
assert(next(field.views)==nil,'walking away drops the views')
-- A regrown chunk is a new holder with the same key: the view follows it.
root.Position=Vector3.new(x0+20,DigCube.GROUND+3,z0+W/2)
field:scan()
local old=field.views['2_0']
here.Parent=nil
local regrown=holder(2,0,true)
field:scan()
assert(field.views['2_0'] and field.views['2_0']~=old and field.views['2_0'].holder==regrown and old.dead,'a regrown chunk gets a fresh view')
assert(field.views['2_0'].cube.removedCount==0,'regrown rock is whole')
field:destroy()
print('PASS field client: views only for chunks near the character (rendered within '..FIELD.VIEW..', untouched within '..FIELD.VIEW_IDLE..'), built from the world seed to the server\'s cells, earlier ops replayed, beams routed by DigChunk, views follow dropped and regrown holders (doubles; effects and device cost NOT verified)')
'''

view = module_bundle(('DigCubeView',)).replace('--!strict\n', '')
view = view.replace("V.ROLE_FX=ROLE_FX", "V.ROLE_FX=ROLE_FX\nV.RockChunks=RockChunks\nV.DigCube=DigCube", 1)
source = "\n".join([doubles, view, ";(function()\n" + checks + "\nend)()"])
with tempfile.TemporaryDirectory(prefix="dig-field-client-") as directory:
    path = Path(directory) / "checks.lua"
    path.write_text(source)
    subprocess.run([str(luau), str(path)], check=True)
