#!/usr/bin/env python3
"""Current live-game special mining, permanent ownership, transport and launch checks.
Production source with API doubles is not Studio, networking, asset or fun validation.
"""
import pathlib
import subprocess
import sys
import tempfile
from build import ROOT, bundle, client_bundle

luau=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/luau')
for path in sorted((ROOT/'src').glob('*.lua')):
    subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(ROOT/'tests/special-logistics.spec.lua')],check=True)
with tempfile.TemporaryDirectory(prefix='special-logistics-checks-') as directory:
    fixtures={
        'server': (ROOT/'tests/mock-roblox.lua').read_text()+'\n'+(ROOT/'tests/gadget-server.setup.lua').read_text()+'\n'+bundle()+'\n'+(ROOT/'tests/special-logistics.integration.lua').read_text(),
        'preview': (ROOT/'tests/mock-roblox.lua').read_text()+'\n'+(ROOT/'tests/gadget-server.setup.lua').read_text()+'\nfunction runService:IsStudio() return true end\n'+bundle()+'\n'+(ROOT/'tests/special-logistics-preview.integration.lua').read_text(),
        'fx': (ROOT/'tests/special-fx.setup.lua').read_text()+'\nlocal DroneFX=(function()\n'+(ROOT/'src/DroneFX.lua').read_text()+'\nend)()\n'+(ROOT/'tests/special-fx.integration.lua').read_text(),
    }
    for name,source in fixtures.items():
        path=pathlib.Path(directory)/(name+'.lua');path.write_text(source)
        subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
        subprocess.run([str(luau/'luau'),str(path)],check=True)
    for name,source in [('server-bundle',bundle()),('client-bundle',client_bundle())]:
        path=pathlib.Path(directory)/(name+'.lua');path.write_text(source)
        subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
print('PASS current-game special/logistics source, domain, server and FX lifecycle checks. Studio visual/multiplayer/fun NOT VERIFIED.')
