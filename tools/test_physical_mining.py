#!/usr/bin/env python3
"""Execute production physical-mining boundaries with API doubles; not engine QA."""
from pathlib import Path
import subprocess, sys, tempfile
from build import ROOT, bundle, client_bundle, module_bundle
luau=Path(sys.argv[1] if len(sys.argv)>1 else '/private/tmp/mining-away-luau')
mock=(ROOT/'tests/mock-roblox.lua').read_text()
client=(ROOT/'src/Client.lua').read_text()
render=client[client.index('local function renderResource(r,now)'):client.index('local function resolveRenderedTarget')]
with tempfile.TemporaryDirectory() as tmp:
 for name,code in {'client':client_bundle(),'server':bundle()}.items():
  path=Path(tmp)/(name+'.lua');path.write_text(code)
  subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
 fixtures={'resource-render':mock+'\n'+module_bundle(('Feel', 'RockFinish'))+'\n'+(ROOT/'tests/resource-render.setup.lua').read_text()+'\n'+render+'\n'+(ROOT/'tests/resource-render.integration.lua').read_text()}
 for name in ('mining-impact-server','pickups-server','gadget-server'):
  fixtures[name]=mock+'\n'+(ROOT/'tests/gadget-server.setup.lua').read_text()+'\n'+bundle()+'\n;(function()\n'+(ROOT/'tests'/(name+'.integration.lua')).read_text()+'\nend)()'
 for name,code in fixtures.items():
  path=Path(tmp)/(name+'.lua');path.write_text(code)
  subprocess.run([str(luau/'luau'),str(path)],check=True)
print('PASS physical mining source/authority/shrink/pickup/ability regressions; API doubles, not engine visuals or multiplayer')
