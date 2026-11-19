#!/usr/bin/env python3
"""The simple loop on the square fields, run on the real server with Roblox API doubles.

Checks: one field form (no classic strips), crew buttons charged by breaks,
Overdrive speeds up its own drones only, Shockwave damages open rocks around the
target and never another crew's claimed rock, and a full bag cashes out on the
field with an auto receipt. Not engine QA: feel, visuals and real multiplayer
need a Studio playtest.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

from build import ROOT, bundle

luau = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/mining-away-luau") / "luau"
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
  local bed=fixturePart(zone,'Field',Vector3.new((tier-1)*68,3.8,-82),Vector3.new(32,.8,32))
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
-- One field form: only the five square fields exist without the classic strips.
assert(scene.flatFields and #patches==5,'expected exactly the five square fields')
for _,field in ipairs(patches) do assert(field.cfg.WholeField) end
local function tick(n) for _=1,n do realTime+=C.Tick;heartbeat:Fire(C.Tick) end end
local function crew(pl) return game:GetService('HttpService'):JSONDecode(pl:GetAttribute('MA_Crew')) end
local pl=player(4812)
players.PlayerAdded:Fire(pl)
local p=profiles[pl.UserId]
local field=patches[1]
local p0=field.part.Position
pl.Character:PivotTo(CFrame.new(p0+Vector3.new(0,3,0)))
tick(30)
assert(p.miningSquare and p.miningSquare.field==field,'walking onto the field did not put the crew to work')
local view=crew(pl)
assert(#view==1 and view[1].role=='Striker' and view[1].kind=='Overdrive' and view[1].charge==0 and view[1].need==6,'starter crew needs one Overdrive button')
-- Not charged yet: nothing happens.
scene.crewAbility(p,{role='Striker',runId=data(p).run.id})
for _,d in ipairs(p.drones) do assert(not d.model:GetAttribute('OverdriveUntil')) end
-- Owned breaks fill the button.
for _=1,6 do scene.crewBreak(pl.UserId) end
tick(8)
view=crew(pl)
assert(view[1].charge==6,'six breaks should fill Overdrive')
scene.crewAbility(p,{role='Striker',runId=data(p).run.id})
for _,d in ipairs(p.drones) do
 assert(d.model:GetAttribute('OverdriveUntil')==now+6,'Overdrive did not mark its drones')
 assert(CrewAbilities.multiplier(p.crew,d.role,now)==3)
end
assert(CrewAbilities.multiplier(p.crew,'Striker',now+6.1)==1,'Overdrive must end')
tick(8)
assert(crew(pl)[1].charge==0 and crew(pl)[1].activeUntil,'button should drain and show it is active')
local fx=RS.MiningAway.CrewFX.clientMessages
assert(#fx==1 and fx[1].all and fx[1].payload.kind=='Overdrive','every player should see Overdrive')
-- A second player whose crew owns one rock.
local other=player(9001)
players.PlayerAdded:Fire(other)
local q=profiles[other.UserId]
-- Give the first player a Breaker so they earn a Shockwave button.
p.drones[2].role='Charger'
local roles=scene.crewRoles(p)
local buttons=CrewAbilities.buttons(roles)
assert(#buttons==2 and buttons[1]=='Striker' and buttons[2]=='Charger')
for _=1,8 do scene.crewBreak(pl.UserId) end
local open={}
for _,r in ipairs(field.resources) do if scene.crewRockOpen(p,r,p.miningSquare) then table.insert(open,r) end end
assert(#open>=3,'expected open rocks to blast')
local center=open[1]
p.miningSquare.focusId=center.id
-- Another crew claims one of the nearby rocks: the shockwave must skip it.
local near=CrewAbilities.shockTargets(open,center.position,12)
assert(#near>=2,'expected at least two rocks near the target')
local claimed=near[2]
claimed.slots[q.drones[1].id]=1
local before={}
for _,r in ipairs(field.resources) do before[r]=r.hp end
scene.crewAbility(p,{role='Charger',runId=data(p).run.id})
assert(p.crewShock and #p.crewShock.targets>=1,'shockwave did not pick targets')
for _,r in ipairs(p.crewShock.targets) do assert(r~=claimed,'shockwave targeted another crew\\'s rock') end
tick(40)
assert(not p.crewShock,'shockwave never landed')
local hurt=0
for r,hp in pairs(before) do
 if r.hp<hp or r.paid then hurt+=1 end
end
assert(hurt>=1,'shockwave did no damage')
assert(claimed.hp==before[claimed] and not claimed.paid,'claimed rock was hit by another crew')
assert(fx[#fx].payload.kind=='Shockwave' and fx[#fx].payload.position==center.position)
claimed.slots[q.drones[1].id]=nil
-- A full bag cashes out on the field.
local capacity=Ca.capacity(data(p))
local units=Pro.cargoUnits(data(p))
data(p).run.cargo=data(p).run.cargo or {}
local key=next(data(p).run.cargo) or 'Quartz'
data(p).run.cargo[key]=(data(p).run.cargo[key] or 0)+math.max(0,capacity-units)
assert(Pro.cargoUnits(data(p))>=capacity)
assert(scene.autoSellReady(p,data(p),Pro.cargoUnits(data(p))),'full bag should cash out on square fields')
tick(30)
local sales=RS.MiningAway.Sale.clientMessages
local last=sales[#sales]
assert(last and last.payload.auto==true and last.payload.full==false,'expected an automatic cash-out receipt')
assert(Pro.cargoUnits(data(p))==0,'bag should be empty after cash-out')
print('PASS square-field loop: one field form, crew buttons charge from breaks, Overdrive/Shockwave respect ownership, full bag cashes out on the field (API doubles; feel and real multiplayer NOT verified)')
"""
source = "\n".join([
    (ROOT / "tests/mock-roblox.lua").read_text(),
    (ROOT / "tests/gadget-server.setup.lua").read_text(),
    fixture, bundle(), ";(function()\n" + checks + "\nend)()",
])
with tempfile.TemporaryDirectory(prefix="crew-loop-") as directory:
    path = Path(directory) / "checks.lua"
    path.write_text(source)
    subprocess.run([str(luau), str(path)], check=True)

crew_view = (ROOT / "src/CrewView.lua").read_text().replace(
    "require('./CrewAbilities')", "(function()\n" + (ROOT / "src/CrewAbilities.lua").read_text() + "\nend)()")
prelude, body = (ROOT / "tests/crew-view.integration.lua").read_text().split("-- @module\n", 1)
client = "\n".join([
    (ROOT / "tests/mock-roblox.lua").read_text(),
    "local RoleVisuals={ImpactParticles=function() end}",
    prelude,
    "local CrewView=(function()\n" + crew_view + "\nend)()",
    body,
])
with tempfile.TemporaryDirectory(prefix="crew-view-") as directory:
    path = Path(directory) / "view.lua"
    path.write_text(client)
    subprocess.run([str(luau), str(path)], check=True)

from build import module_bundle
ledger = (ROOT / "src/SaleLedger.lua").read_text()
sale = (ROOT / "src/SaleView.lua").read_text().replace("require('./SaleLedger')", "(function()\n" + ledger + "\nend)()")
cash = "\n".join([
    (ROOT / "tests/mock-roblox.lua").read_text(),
    module_bundle(("Shops",)),
    "local RoleVisuals",
    "local SaleView=(function()\n" + sale + "\nend)()",
    (ROOT / "tests/cash-out.integration.lua").read_text(),
])
with tempfile.TemporaryDirectory(prefix="cash-out-") as directory:
    path = Path(directory) / "cash.lua"
    path.write_text(cash)
    subprocess.run([str(luau), str(path)], check=True)
