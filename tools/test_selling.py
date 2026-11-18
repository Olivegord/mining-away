"""Authoritative sale rewards and client receipt flow using API doubles."""
import subprocess,sys,tempfile
from pathlib import Path
from build import ROOT,bundle,client_bundle,module_bundle
luau=Path(sys.argv[1] if len(sys.argv)>1 else '/private/tmp/drone-luau')
for spec in ['selling','workshop','persistence']:
 subprocess.run([str(luau/'luau'),str(ROOT/'tests'/f'{spec}.spec.lua')],check=True)
with tempfile.TemporaryDirectory(prefix='selling-') as directory:
 for name,source in [('server',bundle()),('client',client_bundle())]:
  path=Path(directory)/(name+'.lua');path.write_text(source)
  subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
 for fixture in ['selling']:
  source='\n'.join([(ROOT/'tests/mock-roblox.lua').read_text(),(ROOT/'tests/gadget-server.setup.lua').read_text(),
   "do local nativeType=typeof; typeof=function(x) return getmetatable(x)==VM and 'Vector3' or nativeType(x) end end",bundle(),
   ';(function()\n'+(ROOT/'tests'/f'{fixture}.integration.lua').read_text()+'\nend)()'])
  path=Path(directory)/(fixture+'.lua');path.write_text(source)
  subprocess.run([str(luau/'luau'),str(path)],check=True)
 ledger=(ROOT/'src/SaleLedger.lua').read_text()
 sale=(ROOT/'src/SaleView.lua').read_text().replace("require('./SaleLedger')",'(function()\n'+ledger+'\nend)()')
 source='\n'.join(((ROOT/'tests/mock-roblox.lua').read_text(),module_bundle(('Shops',)),
  'local SaleView=(function()\n'+sale+'\nend)()',
  (ROOT/'tests/sale-ledger.integration.lua').read_text()))
 path=Path(directory)/'counter-sale.lua';path.write_text(source)
 subprocess.run([str(luau/'luau'),str(path)],check=True)
