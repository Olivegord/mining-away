#!/usr/bin/env python3
"""Execute current client intent/rendering with API doubles; not a Studio test."""
import pathlib
import subprocess
import sys
import tempfile
from build import ROOT, module_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/mining-away-luau')
client = (ROOT / 'src/Client.lua').read_text()
ability = (ROOT / 'src/AbilityView.lua').read_text()
mock = (ROOT / 'tests/mock-roblox.lua').read_text()
render = client[client.index('local function renderDrone(d,dt,now)'):client.index('-- Every observer draws repair beams')]
plot = client[client.index('local function requestPlot(id)'):client.index('local commandView=CommandView.new')]
assign = client[client.index('local function assignField(target)'):client.index('local mouse=player:GetMouse()')]
activate = ability[ability.index(' local function activate(kind)'):ability.index(' local orbital=')]
impact = client[client.index('local function roleImpact(source)'):client.index('local impactConnection=')]
with tempfile.TemporaryDirectory() as tmp:
    sources = {
        'motion': mock + '\n' + module_bundle(('Feel',)) + '\n' + (ROOT / 'tests/motion-setup.lua').read_text() + '\n' + render + '\n' + (ROOT / 'tests/client-refinement-motion.integration.lua').read_text(),
        'intent': mock + '\n' + (ROOT / 'tests/client-refinement-intent.setup.lua').read_text() + '\n' + plot + '\n' + assign + '\n' + activate + '\n' + (ROOT / 'tests/client-refinement-intent.integration.lua').read_text(),
        'impact': mock + '\n' + module_bundle(('AudioFeedback',)) + '\n' + (ROOT / 'tests/client-refinement-impact.setup.lua').read_text() + '\n' + impact + '\n' + (ROOT / 'tests/client-refinement-impact.integration.lua').read_text(),
        'highlight': mock + '\n' + (ROOT / 'tests/client-refinement-highlight.setup.lua').read_text() + '\n' + module_bundle(('CommandView',)) + '\n' + (ROOT / 'tests/client-refinement-highlight.integration.lua').read_text(),
    }
    for name, source in sources.items():
        path = pathlib.Path(tmp) / (name + '.lua')
        path.write_text(source)
        subprocess.run([str(luau / 'luau'), str(path)], check=True)
print('PASS current client refinements. API doubles; native visuals/input/multiplayer NOT VERIFIED.')
