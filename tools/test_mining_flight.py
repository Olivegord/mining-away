#!/usr/bin/env python3
"""Execute actual mining jobs/rendering with API doubles; no engine claims."""
import pathlib, subprocess, sys, tempfile
from build import ROOT, bundle, module_bundle
luau=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/luau')
mock=(ROOT/'tests/mock-roblox.lua').read_text()
client=(ROOT/'src/Client.lua').read_text()
render=client[client.index('local function renderDrone(d,dt,now)'):client.index('-- Every observer draws repair beams',client.index('local function renderDrone(d,dt,now)'))]
cards=(ROOT/'src/CardView.lua').read_text()
card_domain=cards[:cards.index('local Players=')]+'\n'+cards[cards.index('function CardView.identity(choice)'):cards.index('local function mechanicVisual')]
with tempfile.TemporaryDirectory() as tmp:
 for name,source in {
  'cards':mock+'\n'+module_bundle(('Shops','DroneRoles','Cards'))+'\n'+card_domain+'\n'+(ROOT/'tests/card-color.integration.lua').read_text(),
  'server':mock+'\n'+(ROOT/'tests/gadget-server.setup.lua').read_text()+'\nfunction runService:IsStudio() return true end\n'+bundle()+'\n;(function()\n'+(ROOT/'tests/mining-flight.integration.lua').read_text()+'\nend)()',
  'observers':mock+'\n'+(ROOT/'tests/gadget-server.setup.lua').read_text()+'\n'+bundle()+'\n;(function()\n'+(ROOT/'tests/motion-setup.lua').read_text()+'\n'+render+'\n'+(ROOT/'tests/mining-flight-observers.integration.lua').read_text()+'\nend)()',
  'client':mock+'\n'+module_bundle(('Feel',))+'\n'+(ROOT/'tests/motion-setup.lua').read_text()+'\n'+render+'\n'+(ROOT/'tests/mining-flight-client.integration.lua').read_text(),
 }.items():
  path=pathlib.Path(tmp)/(name+'.lua');path.write_text(source)
  subprocess.run([str(luau/'luau'),str(path)],check=True)
subprocess.run([str(luau/'luau'), str(ROOT/'tests/mining-pacing.spec.lua')],check=True)
print('PASS committed mining + observer regressions. Engine motion/UI/multiplayer/fun NOT VERIFIED.')
