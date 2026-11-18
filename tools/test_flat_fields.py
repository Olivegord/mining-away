#!/usr/bin/env python3
"""Exercise whole-field selection and the four-miner startup with Roblox API doubles."""
from pathlib import Path
import subprocess
import sys
import tempfile

from build import ROOT, bundle, module_bundle

luau = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/drone-luau") / "luau"
fixture = """
do
 local root=Instance.new('Folder');root.Name='MiningAway';root.Parent=workspace
 root:SetAttribute('EditableMap',true);root:SetAttribute('DronerevolutionMapVersion',1)
 for _,name in ipairs({'Map','Fields','Resources','Drones','Turrets'}) do
  local f=Instance.new('Folder');f.Name=name;f.Parent=root
 end
 fixturePart(root.Map,'HubPad',Vector3.new(0,3.5,0),Vector3.new(100,1,96))
 fixturePart(root.Map,'Printer',Vector3.new(-16,5,0),Vector3.new(5,2,5))
 fixturePart(root.Map,'PackStation',Vector3.new(0,5,0),Vector3.new(5,2,5))
 fixturePart(root.Map,'PrestigeStation',Vector3.new(16,5,0),Vector3.new(5,2,5))
 local run=Instance.new('Folder');run.Name='CrystalRun';run.Parent=root.Map
 run:SetAttribute('WholeFields',true)
 fixturePart(run,'ChargingStation',Vector3.new(0,4,25),Vector3.new(9,1,6))
 for tier,name in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do
  fixturePart(root.Map,name..'Shop',Vector3.new((tier-3)*18,5,-30),Vector3.new(6,3,4))
  local zone=Instance.new('Folder');zone.Name=name;zone.Parent=run
  local bed=fixturePart(zone,'Field',Vector3.new((tier-1)*68,3.8,-82),Vector3.new(46,.8,46))
  bed:SetAttribute('CrystalZone',tier);bed:SetAttribute('WholeField',true)
 end
 local stock=game.GetService
 function game:GetService(name)
  if name=='MaterialService' then return Instance.new('Folder') end
  return stock(self,name)
 end
 local nativeType=typeof
 typeof=function(x) return getmetatable(x)==VM and 'Vector3' or nativeType(x) end
end
"""
checks = """
assert(scene.flatFields and #patches==5 and patches[1].id==#Config.Fields+1)
for _,field in ipairs(patches) do
 assert(scene.patchById[field.id]==field)
 assert(#field.resources>=8 and #field.resources<=14,'sparse or excessive rock population')
end
local pl=player(4812)
players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
assert(#data(p).fleet==4 and #p.drones==4)
for _,d in ipairs(p.drones) do
 assert(d.role=='Striker' and d.model:GetAttribute('CubeDrone') and d.body.Size.X==3.4)
 assert(#d.model:GetChildren()==2 and d.emitter.Transparency==1 and not d.owned.beamVariant)
 local first=scene.followGoal(d,Vector3.new(0,4,0),4,Vector3.zero,C.Tick)
 local jumping=scene.followGoal(d,Vector3.new(0,16,0),4,Vector3.new(4,5,0),C.Tick)
 assert(first.Y==jumping.Y,'cruise plane follows the character jump')
end
local field=patches[1]
local p0=field.part.Position
local click=p0+Vector3.new(20,.4,-20)
pl.Character:PivotTo(CFrame.new(p0+Vector3.new(15,3,18)))
local oldRay=workspace.Raycast
workspace.Raycast=function() return {Position=click,Instance=field.part} end
local sent=0
local selector=SelectorView.new({world=scene.root,parent=Instance.new('Folder'),player=pl,
 profile=function() return data(p) end,hidden=function() return false end,
 command={FireServer=function(_,action,payload)
  assert(action=='PlaceSelector');sent+=1;scene.placeSquare(p,payload)
 end}})
assert(selector:aimPreview({Origin=p0+Vector3.yAxis*10,Direction=-Vector3.yAxis}))
assert(sent==1 and not selector.draft and p.miningSquare.field==field)
assert(p.miningSquare.half==23 and p.miningSquare.center.X==p0.X and p.miningSquare.center.Z==p0.Z)
assert(scene.rockInSquare(p.miningSquare,{field=field,position=p0+Vector3.new(-21,0,21)}))
workspace.Raycast=oldRay
for _=1,240 do
 realTime+=C.Tick;heartbeat:Fire(C.Tick)
end
local cut=false
for _,d in ipairs(p.drones) do if d.beamSince>0 then cut=true end end
assert(cut,'the field command never reached authoritative cutting')
print('PASS five populated rock fields, one-click whole-field mining, four cube miners, and shared low cruise plane')
"""
source = "\n".join([
    (ROOT / "tests/mock-roblox.lua").read_text(),
    (ROOT / "tests/gadget-server.setup.lua").read_text(),
    fixture, bundle(), ";(function()\n" + module_bundle(("SelectorView",)) + checks + "\nend)()",
])
with tempfile.TemporaryDirectory(prefix="flat-fields-") as directory:
    path = Path(directory) / "checks.lua"
    path.write_text(source)
    subprocess.run([str(luau), str(path)], check=True)
