"""Real command/worker functions with API doubles, plus ballistic debris maths."""
import pathlib, subprocess, tempfile
from build import ROOT, bundle
luau=pathlib.Path('/private/tmp/mining-away-luau/luau')
subprocess.run([str(luau),str(ROOT/'tests/rubble.spec.lua')],check=True)
source='\n'.join([(ROOT/'tests/mock-roblox.lua').read_text(),(ROOT/'tests/gadget-server.setup.lua').read_text(),
    'function runService:IsStudio() return true end',bundle(),
    ';(function()\n'+(ROOT/'tests/core-gameplay.integration.lua').read_text()+'\nend)()'])
with tempfile.TemporaryDirectory() as tmp:
    path=pathlib.Path(tmp)/'core.lua';path.write_text(source)
    subprocess.run([str(luau),str(path)],check=True)
