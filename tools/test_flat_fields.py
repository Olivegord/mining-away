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
 local classic=Instance.new('Folder');classic.Name='CrystalRun';classic.Parent=root.Fields
 local run=Instance.new('Folder');run.Name='CrystalRun';run.Parent=root.Map
 run:SetAttribute('WholeFields',true)
 fixturePart(run,'ChargingStation',Vector3.new(0,4,25),Vector3.new(9,1,6))
 for tier,name in ipairs({'Quartz','Ruby','Cobalt','Violet','Emerald'}) do
  fixturePart(root.Map,name..'Shop',Vector3.new((tier-3)*18,5,-30),Vector3.new(6,3,4))
  local zone=Instance.new('Folder');zone.Name=name;zone.Parent=run
  local bed=fixturePart(zone,'Field',Vector3.new((tier-1)*68,3.8,-82),Vector3.new(32,.8,32))
  bed:SetAttribute('CrystalZone',tier);bed:SetAttribute('WholeField',true)
  local oldZone=Instance.new('Folder');oldZone.Name=name;oldZone.Parent=classic
  local oldBed=fixturePart(oldZone,'Field',Vector3.new(30,3.74,158+(tier-1)*64),Vector3.new(216,.6,64))
  oldBed:SetAttribute('CrystalZone',tier)
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
assert(scene.flatFields and #patches==10 and patches[1].id==#Config.Fields+1)
for i,field in ipairs(patches) do
 assert(scene.patchById[field.id]==field and field.id==#Config.Fields+i)
 if i<=5 then
  assert(not field.cfg.WholeField and field.part.Position.Z>0 and #field.resources>9)
 else
  assert(field.cfg.WholeField and field.part.Position.Z<0 and #field.resources==9)
  for slot,r in ipairs(field.resources) do
   local expectedX=((slot-1)%3-1)*field.part.Size.X/3+field.part.Position.X
   local expectedZ=(math.floor((slot-1)/3)-1)*field.part.Size.Z/3+field.part.Position.Z
   assert(r.gridSlot==slot and math.abs(r.position.X-expectedX)<.001 and math.abs(r.position.Z-expectedZ)<.001)
  end
 end
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
local field=patches[6]
local previous=field.resources[4]
previous.paid=true;previous.part:Destroy()
assert(scene.spawnReplacement(field,'Crystal',{gridSlot=4,position=previous.position}))
local replacement=field.resources[#field.resources]
assert(replacement.gridSlot==4 and replacement.position.X==previous.position.X and replacement.position.Z==previous.position.Z)
local p0=field.part.Position
local click=p0+Vector3.new(14,.4,-14)
pl.Character:PivotTo(CFrame.new(p0+Vector3.new(9,3,12)))
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
assert(p.miningSquare.half==16 and p.miningSquare.center.X==p0.X and p.miningSquare.center.Z==p0.Z)
assert(scene.rockInSquare(p.miningSquare,{field=field,position=p0+Vector3.new(-15,0,15)}))
workspace.Raycast=oldRay
for _=1,480 do
 realTime+=C.Tick;heartbeat:Fire(C.Tick)
end
local cut=false
for _,d in ipairs(p.drones) do if d.beamSince>0 then cut=true end end
assert(cut,'the field command never reached authoritative cutting')
assert(pl:GetAttribute('MA_InSquareField')==true)
local d=p.drones[1]
d.pos=p0+Vector3.yAxis*7;snapshotDrone(d)
assert(d.model:GetAttribute('HideBattery')==true,'square field still shows drone battery')
local classic=patches[1]
d.pos=classic.center+Vector3.yAxis*7;snapshotDrone(d)
assert(d.model:GetAttribute('HideBattery')==false,'classic route lost its drone battery')
pl.Character:PivotTo(CFrame.new(classic.center+Vector3.yAxis*4))
selector:reply({requestId=selector.pending.requestId,status='accepted'})
workspace.Raycast=function() return {Position=classic.center,Instance=classic.part} end
assert(selector:aimPreview({Origin=classic.center+Vector3.yAxis*10,Direction=-Vector3.yAxis}))
assert(sent==1 and selector.draft and selector.draft.field==classic.id,'classic field lost its two-step command')
assert(selector:confirm() and sent==2 and p.miningSquare.field==classic)
print('PASS the classic route, nine evenly spaced rocks and in-place respawn, one-click mining, and field-scoped battery UI')
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
