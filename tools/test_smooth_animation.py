#!/usr/bin/env python3
"""Production animation receipts and timelines, without starting Studio."""
import pathlib
import subprocess
import sys
import tempfile
from build import ROOT, module_bundle, client_bundle, bundle
luau=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/private/tmp/mining-away-luau')
source='\n'.join([
 (ROOT/'tests/mock-roblox.lua').read_text(),
 (ROOT/'tests/energy-effects.setup.lua').read_text(),
 (ROOT/'tests/smooth-animation.setup.lua').read_text(),
 module_bundle(('BeamVFX','MotionBuffer','DroneRoleEffects','RoleVisuals','RoleEffectView')),
 (ROOT/'tests/smooth-animation.integration.lua').read_text(),
])
ability=(ROOT/'src/AbilityView.lua').read_text()
observe=ability[ability.index(" local visualRoot="):ability.index(" local scanAt=")]
start=ability.index("  for source,record in pairs(bots) do")
render=ability[start:ability.index("\n end)\n return",start)]
scrap='\n'.join([
 (ROOT/'tests/mock-roblox.lua').read_text(),
 (ROOT/'tests/energy-effects.setup.lua').read_text(),
 (ROOT/'tests/smooth-animation.setup.lua').read_text(),
 "local Debris=game:GetService('Debris')\nfunction IM:GetScale()return 1 end\nfunction IM:ScaleTo(scale)self.Scale=scale end",
 module_bundle(('DroneOutline','MotionBuffer','DroneRoleEffects')),
 observe,
 'local function renderBots(dt,now)\n'+render+'\nend',
 (ROOT/'tests/scrap-view.integration.lua').read_text(),
])
with tempfile.TemporaryDirectory(prefix='mining-smooth-') as directory:
 for name,code in [('timeline',source),('scrap',scrap),('client',client_bundle()),('server',bundle())]:
  path=pathlib.Path(directory)/(name+'.lua');path.write_text(code)
  subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
  if name in ('timeline','scrap'):subprocess.run([str(luau/'luau'),str(path)],check=True)
