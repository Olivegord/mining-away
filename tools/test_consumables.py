"""Production equipment rules, transactions, mining and input routing. No engine claim."""
import pathlib,subprocess,sys,tempfile
from build import ROOT,bundle,client_bundle,module_bundle
luau=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/private/tmp/mining-away-luau')
subprocess.run([str(luau/'luau'),str(ROOT/'tests/consumables.spec.lua')],check=True)
with tempfile.TemporaryDirectory(prefix='mining-consumables-') as directory:
    base=(ROOT/'tests/mock-roblox.lua').read_text()+'\n'+(ROOT/'tests/gadget-server.setup.lua').read_text()+'\n'+bundle()
    fixtures={
        'consumables':base+'\n;(function()\n'+(ROOT/'tests/consumables-server.integration.lua').read_text()+'\nend)()',
        'existing-gadgets':base+'\n;(function()\n'+(ROOT/'tests/gadget-server.integration.lua').read_text()+'\nend)()',
        'placement-input':(ROOT/'tests/mock-roblox.lua').read_text()+'\n'+(ROOT/'tests/consumables-client.setup.lua').read_text()+'\n'+module_bundle(('Shops','Consumables','ConsumableView'))+'\n'+(ROOT/'tests/consumables-client.integration.lua').read_text(),
        'client':client_bundle(),
    }
    for name,source in fixtures.items():
        path=pathlib.Path(directory)/(name+'.lua');path.write_text(source)
        subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
        if name!='client':subprocess.run([str(luau/'luau'),str(path)],check=True)
print('PASS production consumable and existing gadget behavior using API doubles; client bundle compiled. Studio play, visual, multiplayer and fun NOT VERIFIED.')
