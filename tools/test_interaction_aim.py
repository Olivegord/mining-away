"""Exercise production aim selection with camera/input API doubles."""
import subprocess,tempfile
from pathlib import Path
from build import ROOT,module_bundle
source=(ROOT/'tests/mock-roblox.lua').read_text()+'\n'+module_bundle(('Mining','SelectorView'))+'\n'+(ROOT/'tests/interaction-aim.integration.lua').read_text()
with tempfile.TemporaryDirectory() as directory:
 path=Path(directory)/'aim.lua';path.write_text(source)
 subprocess.run(['/private/tmp/drone-luau/luau',str(path)],check=True)
