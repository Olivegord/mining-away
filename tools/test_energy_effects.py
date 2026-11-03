#!/usr/bin/env python3
"""Production energy/fragment logic with narrow API doubles, not visual QA."""
import pathlib
import subprocess
import sys
import tempfile

from build import ROOT, module_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/mining-away-luau')
modules = ('Mining', 'Feedback', 'SentryMotion', 'WorkEffects', 'Presentation')
for name in modules + ('DroneRoleEffects',):
    subprocess.run([str(luau / 'luau-compile'), str(ROOT / 'src' / (name + '.lua'))],
                   stdout=subprocess.DEVNULL, check=True)
source = '\n'.join((
    (ROOT / 'tests/mock-roblox.lua').read_text(),
    (ROOT / 'tests/energy-effects.setup.lua').read_text(),
    module_bundle(modules),
    (ROOT / 'tests/energy-effects.integration.lua').read_text(),
))
with tempfile.TemporaryDirectory(prefix='mining-energy-checks-') as directory:
    path = pathlib.Path(directory) / 'energy.lua'
    path.write_text(source)
    subprocess.run([str(luau / 'luau'), str(path)], check=True)
