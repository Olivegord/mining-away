"""Execute temporary equipment and damage against actual server functions, with API doubles."""
from pathlib import Path
import subprocess, tempfile
from build import ROOT, bundle, client_bundle

luau = Path('/private/tmp/mining-away-luau')
setup = '''
function typeof(v)
 if getmetatable(v)==VM and v.R==nil then return 'Vector3' end
 return type(v)
end
'''
with tempfile.TemporaryDirectory(prefix='mining-field-tools-') as directory:
 source='\n'.join([(ROOT/'tests/mock-roblox.lua').read_text(),setup,
  (ROOT/'tests/gadget-server.setup.lua').read_text(),bundle(),
  ';(function()\n'+(ROOT/'tests/field-tools.integration.lua').read_text()+'\nend)()'])
 path=Path(directory)/'server.lua';path.write_text(source)
 subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
 subprocess.run([str(luau/'luau'),str(path)],check=True)
 path=Path(directory)/'client.lua';path.write_text(client_bundle())
 subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
print('PASS temporary equipment production logic; native rendering, collision and multiplayer are NOT verified.')
