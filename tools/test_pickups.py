#!/usr/bin/env python3
"""Physical pickup trajectories and renderer; API doubles are not native QA."""
import pathlib
import subprocess
import sys
import tempfile

from build import ROOT, module_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/mining-away-luau')
for name in ('OreDrops', 'PickupMotion', 'PickupView', 'TacticalHUD'):
    subprocess.run([str(luau / 'luau-compile'), str(ROOT / 'src' / f'{name}.lua')], check=True, stdout=subprocess.DEVNULL)
for name in ('ore-drops', 'pickup-motion'):
    subprocess.run([str(luau / 'luau'), str(ROOT / 'tests' / f'{name}.spec.lua')], check=True)
source = '\n'.join((
    (ROOT / 'tests/mock-roblox.lua').read_text(),
    (ROOT / 'tests/energy-effects.setup.lua').read_text(),
    module_bundle(('AudioFeedback', 'OreDrops', 'PickupMotion', 'PickupView')),
    (ROOT / 'tests/pickup-view.integration.lua').read_text(),
))
with tempfile.TemporaryDirectory(prefix='physical-pickups-') as directory:
    path = pathlib.Path(directory) / 'pickup-view.lua'
    path.write_text(source)
    subprocess.run([str(luau / 'luau'), str(path)], check=True)
print('PASS pickup math and production view checks. Native motion/audio and multiplayer NOT VERIFIED.')
