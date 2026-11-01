#!/usr/bin/env python3
"""Focused current mineral economy checks. Does not start Roblox Studio Play."""
import pathlib
import subprocess
import sys
import tempfile

from build import ROOT, bundle, client_bundle, editor_layout_script

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/luau')
for path in sorted((ROOT / 'src').glob('*.lua')):
    subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
subprocess.run([str(luau / 'luau-analyze'), *[str(ROOT / 'src' / f'{name}.lua') for name in ('Shops', 'Profile', 'Cards', 'DroneAbilities', 'Persistence')]], check=True)
for name in ('shops', 'mining', 'persistence'):
    subprocess.run([str(luau / 'luau'), str(ROOT / 'tests' / f'{name}.spec.lua')], check=True)
with tempfile.TemporaryDirectory(prefix='mineral-shop-tests-') as directory:
    for name, source in [('server', bundle()), ('client', client_bundle()), ('editor-layout', editor_layout_script())]:
        path = pathlib.Path(directory) / f'{name}.lua'
        path.write_text(source)
        subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
    server = pathlib.Path(directory) / 'shop-server.lua'
    server.write_text((ROOT / 'tests/mock-roblox.lua').read_text() + '\n' +
                      (ROOT / 'tests/gadget-server.setup.lua').read_text() + '\n' + bundle() + '\n' +
                      (ROOT / 'tests/shop-server.integration.lua').read_text())
    subprocess.run([str(luau / 'luau'), str(server)], check=True)
subprocess.run([sys.executable, str(ROOT / 'tests/live-build.spec.py')], check=True)
print('PASS current shop domain/server checks, all source and bundle syntax, deterministic live-capture preservation. Not Studio visual/multiplayer QA.')
