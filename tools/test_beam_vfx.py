#!/usr/bin/env python3
"""Production beam/timeline logic under API doubles; never a visual approval."""
import pathlib
import subprocess
import sys
import tempfile

from build import ROOT, bundle, client_bundle, module_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/mining-away-luau')
modules = ('BeamVFX', 'Mining', 'Feedback', 'SentryMotion', 'WorkEffects',
           'Presentation', 'MotionBuffer', 'DroneRoleEffects', 'RoleVisuals', 'RoleEffectView')
source = '\n'.join([
    (ROOT / 'tests/mock-roblox.lua').read_text(),
    (ROOT / 'tests/energy-effects.setup.lua').read_text(),
    (ROOT / 'tests/smooth-animation.setup.lua').read_text(),
    module_bundle(modules),
    (ROOT / 'tests/beam-vfx.integration.lua').read_text(),
    (ROOT / 'tests/startup-fx.spec.lua').read_text(),
])
client = (ROOT / 'src/Client.lua').read_text()
healing = client[client.index('local healCursor=0'):client.index('-- The carried inventory belongs')]
healing_source = '\n'.join([
    (ROOT / 'tests/mock-roblox.lua').read_text(),
    (ROOT / 'tests/energy-effects.setup.lua').read_text(),
    (ROOT / 'tests/smooth-animation.setup.lua').read_text(),
    module_bundle(('BeamVFX', 'WorkEffects')),
    "local Players=game:GetService('Players')\nlocal drones,droneIndex={},{}\nlocal localFX=Instance.new('Folder');localFX.Parent=workspace\nlocal world=Instance.new('Folder');world.Parent=workspace",
    healing,
    (ROOT / 'tests/beam-healing.integration.lua').read_text(),
])
with tempfile.TemporaryDirectory(prefix='beam-vfx-') as directory:
    for name, text in [('behavior', source), ('healing', healing_source), ('client', client_bundle()), ('server', bundle())]:
        path = pathlib.Path(directory) / (name + '.lua')
        path.write_text(text)
        subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
        if name in ('behavior', 'healing'):
            subprocess.run([str(luau / 'luau'), str(path)], check=True)
print('PASS production beams and both bundles; Studio rendering/multiplayer remains UNVERIFIED')
preview = module_bundle(('BeamVFX',)) + '\n' + (ROOT / 'tools/studio_beam_preview.lua').read_text()
path = ROOT / 'build/beam-vfx-edit-preview.lua'
path.write_text(preview)
subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
print('Generated native Edit component preview; not executed in this cloud workspace')
