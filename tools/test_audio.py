#!/usr/bin/env python3
"""Reproducible production audio/contact checks; not a listening playtest."""
import pathlib
import subprocess
import sys
import tempfile

from build import ROOT, bundle, client_bundle, module_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/mining-away-luau')
for path in sorted((ROOT / 'src').glob('*.lua')):
    subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
for name in ('audio-feedback', 'ore-drops', 'feedback'):
    subprocess.run([str(luau / 'luau'), str(ROOT / 'tests' / (name + '.spec.lua'))], check=True)
mock = (ROOT / 'tests/mock-roblox.lua').read_text()
with tempfile.TemporaryDirectory(prefix='mining-audio-checks-') as directory:
    sources = {
        'server': bundle(),
        'client': client_bundle(),
        'pickups': mock + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' + (ROOT / 'tests/pickups-server.integration.lua').read_text(),
        'fragments': mock + '\n' + module_bundle(('Mining', 'Feedback', 'SentryMotion', 'WorkEffects', 'Presentation')) + '\n' + (ROOT / 'tests/audio-fragments.integration.lua').read_text(),
    }
    for name, source in sources.items():
        path = pathlib.Path(directory) / (name + '.lua')
        path.write_text(source)
        subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
        if name in ('pickups', 'fragments'):
            subprocess.run([str(luau / 'luau'), str(path)], check=True)
runtime = module_bundle(('AudioFeedback', 'Soundscape')) + '\n' + (ROOT / 'tests/audio.studio.lua').read_text()
(ROOT / 'build/audio-runtime-check.lua').write_text(runtime)
print('PASS production audio/contact checks and bundle compilation. Studio check generated; listening/multiplayer remain separate.')
