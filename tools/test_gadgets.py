#!/usr/bin/env python3
"""Focused production gadget/steering checks. API doubles are not Studio QA."""
import pathlib
import subprocess
import sys
import tempfile

from build import ROOT, bundle, module_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/luau')
for name in ('DroneRoles', 'DroneAbilities', 'AbilityView', 'DroneConfig', 'DroneRoleEffects', 'Feel', 'Mining'):
    subprocess.run([str(luau / 'luau-compile'), str(ROOT / 'src' / f'{name}.lua')], check=True, stdout=subprocess.DEVNULL)
subprocess.run([str(luau / 'luau'), str(ROOT / 'tests/drone-abilities.spec.lua')], check=True)
subprocess.run([str(luau / 'luau'), str(ROOT / 'tests/drone-roles.spec.lua')], check=True)
mock = (ROOT / 'tests/mock-roblox.lua').read_text()
with tempfile.TemporaryDirectory(prefix='mining-gadget-tests-') as directory:
    fixtures = {
        'swarm': mock + '\n' + module_bundle(('Feel',)) + '\n' + (ROOT / 'tests/swarm-motion.integration.lua').read_text(),
        'server': mock + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/gadget-server.integration.lua').read_text(),
        'roles-server': mock + '\nfunction runService:IsStudio() return true end\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/drone-role-server.integration.lua').read_text(),
    }
    for name, source in fixtures.items():
        path = pathlib.Path(directory) / f'{name}.lua'
        path.write_text(source)
        subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
        subprocess.run([str(luau / 'luau'), str(path)], check=True)
print('PASS gadget source compilation + production domain/steering/server logic using API doubles. Studio visual/multiplayer/fun not verified.')
