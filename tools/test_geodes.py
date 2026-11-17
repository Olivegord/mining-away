#!/usr/bin/env python3
"""Exercise real geode server transactions using the existing Roblox API doubles."""
import subprocess
import tempfile
from pathlib import Path
from build import ROOT, bundle, client_bundle
luau=Path('/private/tmp/drone-luau')
server=bundle().replace('World.placeStart(scene)\n','World.placeStart(scene)\nscene.runStart=scene.fields[1].center\n',1)
with tempfile.TemporaryDirectory(prefix='geodes-') as directory:
    root=Path(directory)
    for name,code in [('server',server),('client',client_bundle())]:
        path=root/(name+'.lua');path.write_text(code)
        subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
    source='\n'.join([(ROOT/'tests/mock-roblox.lua').read_text(),(ROOT/'tests/gadget-server.setup.lua').read_text(),
        "do local nativeType=typeof; typeof=function(x) return getmetatable(x)==VM and 'Vector3' or nativeType(x) end end",server,
        ';(function()\n'+(ROOT/'tests/geodes.integration.lua').read_text()+'\nend)()'])
    path=root/'integration.lua';path.write_text(source)
    subprocess.run([str(luau/'luau'),str(path)],check=True)
