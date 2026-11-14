"""Production crystal stages and reward-only drops, using the shared Roblox API double."""
import pathlib, subprocess, tempfile
from build import ROOT, bundle
luau=pathlib.Path('/private/tmp/mining-away-luau')
code='\n'.join([(ROOT/'tests/mock-roblox.lua').read_text(),(ROOT/'tests/gadget-server.setup.lua').read_text(),bundle(),
 ';(function()\n'+(ROOT/'tests/rock-cascade.integration.lua').read_text()+'\nend)()'])
with tempfile.TemporaryDirectory() as tmp:
 p=pathlib.Path(tmp)/'cascade.lua';p.write_text(code)
 subprocess.run([str(luau/'luau-compile'),str(p)],stdout=subprocess.DEVNULL,check=True)
 subprocess.run([str(luau/'luau'),str(p)],check=True)
