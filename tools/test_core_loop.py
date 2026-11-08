"""The complete starter economy against production code, in both runtime modes."""
from pathlib import Path
import subprocess, tempfile
from build import ROOT, bundle, client_bundle
luau=Path('/private/tmp/mining-away-luau')
with tempfile.TemporaryDirectory(prefix='mining-core-loop-') as directory:
 for studio in (False,True):
  source='\n'.join([(ROOT/'tests/mock-roblox.lua').read_text(),(ROOT/'tests/gadget-server.setup.lua').read_text(),
   'function runService:IsStudio() return true end' if studio else '',bundle(),
   ';(function()\n'+(ROOT/'tests/core-loop.integration.lua').read_text()+'\nend)()'])
  path=Path(directory)/('studio.lua' if studio else 'production.lua');path.write_text(source)
  subprocess.run([str(luau/'luau'),str(path)],check=True)
 path=Path(directory)/'junk-clearing.lua'
 path.write_text('\n'.join([(ROOT/'tests/mock-roblox.lua').read_text(),(ROOT/'tests/gadget-server.setup.lua').read_text(),
  '''
function runService:IsStudio() return true end
local function addTechTemplates()
 local library=Instance.new('Folder');library.Name='JunkCubeTemplates';library.Parent=serverStorage
 local tech=Instance.new('Folder');tech.Name='Tech';tech.Parent=library
 for _,name in ipairs({'CartridgeFuses','Motherboard','RibbonCable','CircuitTraces','FuseBox','HeatSink'}) do
  local part=Instance.new('Part');part.Name=name;part.Size=Vector3.one*6;part.Parent=tech
 end
end
addTechTemplates()
''',
  bundle(),';(function()\n'+(ROOT/'tests/junk-clearing.integration.lua').read_text()+'\nend)()']))
 subprocess.run([str(luau/'luau'),str(path)],check=True)
 path=Path(directory)/'client.lua';path.write_text(client_bundle())
 subprocess.run([str(luau/'luau-compile'),str(path)],check=True,stdout=subprocess.DEVNULL)
