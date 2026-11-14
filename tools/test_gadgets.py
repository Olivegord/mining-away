#!/usr/bin/env python3
"""Focused production gadget/steering checks. API doubles are not Studio QA."""
import pathlib
import subprocess
import sys
import tempfile

from build import ROOT, bundle, module_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/luau')
for name in ('DroneRoles', 'DroneAbilities', 'AbilityView', 'DroneConfig', 'DroneRoleEffects', 'Feel', 'Mining', 'OreDrops', 'PickupView', 'CommandView'):
    subprocess.run([str(luau / 'luau-compile'), str(ROOT / 'src' / f'{name}.lua')], check=True, stdout=subprocess.DEVNULL)
subprocess.run([str(luau / 'luau'), str(ROOT / 'tests/drone-abilities.spec.lua')], check=True)
subprocess.run([str(luau / 'luau'), str(ROOT / 'tests/drone-roles.spec.lua')], check=True)
subprocess.run([str(luau / 'luau'), str(ROOT / 'tests/ore-drops.spec.lua')], check=True)
mock = (ROOT / 'tests/mock-roblox.lua').read_text()
client = (ROOT / 'src/Client.lua').read_text()
render = client[client.index('local function renderDrone(d,dt,now)'):client.index('-- Every observer draws repair beams', client.index('local function renderDrone(d,dt,now)'))]
resource_render = client[client.index('local function renderResource(r,now)'):client.index('local function resolveRenderedTarget', client.index('local function renderResource(r,now)'))]
crystal_frame = client[client.index(' for _,r in pairs(resources) do\n  if impactFreeze:holds(r)'):client.index(' selectorView:updateHealing(now)')]
crystal_clock_setup = """
local BeamVFX={near=function() return true end,reduced=function() return false end}
local splitParticles=0
local RoleVisuals={setTime=function() end,step=function() end,destroy=function() end,Pulse=function() end,PrismImpact=function() end,
 ImpactParticles=function(_,_,_,kind) if kind=='CrystalBreak' then splitParticles+=1 end end}
local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local NumberSequence={new=function(a,b) return b and {NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(1,b)} or a end}
local ColorSequence={new=function(a,b) return b and {ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(1,b)} or a end}
function IM:Emit(count) self.Emitted=(self.Emitted or 0)+count end
local nativeType=typeof
local function typeof(value) return getmetatable(value)==VM and 'Vector3' or nativeType(value) end
local getService=game.GetService
function game:GetService(name)
 if name=='GuiService' then return {ReducedMotionEnabled=false} end
 return getService(self,name)
end
"""
with tempfile.TemporaryDirectory(prefix='mining-gadget-tests-') as directory:
    fixtures = {
        'resource-render': mock + '\n' + module_bundle(('Feel', 'RockFinish')) + '\n' + (ROOT / 'tests/resource-render.setup.lua').read_text() + '\n' + resource_render + '\n' + (ROOT / 'tests/resource-render.integration.lua').read_text(),
        'contact-render': mock + '\n' + (ROOT / 'tests/mining-contact.integration.lua').read_text() + '\n' + module_bundle(('BeamVFX','Mining','WorkEffects')) + '\n' + (ROOT / 'tests/mining-contact.assert.lua').read_text(),
        'crystal-clock': mock + '\n' + (ROOT / 'tests/resource-render.setup.lua').read_text() + crystal_clock_setup +
        module_bundle(('Feel', 'Feedback', 'PickupMotion', 'ImpactFreeze', 'RockFinish', 'CrystalImpactView', 'DroneCatalog', 'PlaneBurst', 'RoleEffectView')) + '\n' + resource_render +
        '\nlocal impactFreeze=ImpactFreeze.new({})\nlocal function crystalFrame(resources,now)\n' + crystal_frame + '\nend\n' +
        (ROOT / 'tests/crystal-contact-clock.integration.lua').read_text(),
        'prism-server': mock + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/prism-server.integration.lua').read_text(),
        'nomad-view': mock + '\n' + (ROOT / 'tests/nomad-view.setup.lua').read_text() + '\n' + module_bundle(('Feel','EnergyDisc','NomadView')) + '\n' + (ROOT / 'tests/nomad-view.integration.lua').read_text(),
        'nomad-server': mock + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/nomad-server.integration.lua').read_text(),
        'swarm': mock + '\n' + module_bundle(('Feel',)) + '\n' + (ROOT / 'tests/swarm-motion.integration.lua').read_text(),
        'client-inertia': mock + '\n' + module_bundle(('Feel',)) + '\n' + (ROOT / 'tests/motion-setup.lua').read_text() + '\n' + render + '\n' + (ROOT / 'tests/client-inertia.integration.lua').read_text(),
        'server': mock + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/gadget-server.integration.lua').read_text(),
        'pickups-server': mock + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/pickups-server.integration.lua').read_text(),
        'mining-impact': mock + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/mining-impact-server.integration.lua').read_text(),
        'roles-server': mock + '\nfunction runService:IsStudio() return true end\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/drone-role-server.integration.lua').read_text(),
    }
    for name, source in fixtures.items():
        path = pathlib.Path(directory) / f'{name}.lua'
        path.write_text(source)
        subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
        subprocess.run([str(luau / 'luau'), str(path)], check=True)
print('PASS gadget source compilation + production domain/steering/server logic using API doubles. Studio visual/multiplayer/fun not verified.')
