#!/usr/bin/env python3
"""Current progression, pickup friction and source preservation. No native Play."""
import pathlib
import subprocess
import sys
import tempfile
from build import ROOT, bundle, client_bundle

luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/luau')
for path in sorted((ROOT / 'src').glob('*.lua')):
    subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
subprocess.run([str(luau / 'luau-analyze'), *[str(ROOT / 'src' / f'{name}.lua') for name in
    ('Workshop', 'Profile', 'Cards', 'DroneCatalog', 'OreDrops')]], check=True)
for name in ('progression-overhaul', 'workshop', 'mining', 'persistence'):
    subprocess.run([str(luau / 'luau'), str(ROOT / 'tests' / f'{name}.spec.lua')], check=True)
with tempfile.TemporaryDirectory(prefix='progression-overhaul-') as temporary:
    directory = pathlib.Path(temporary)
    for name, source in (('client', client_bundle()), ('server', bundle())):
        path = directory / f'{name}.lua'
        path.write_text(source)
        subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
    for studio in (False, True):
        setup = (ROOT / 'tests/mock-roblox.lua').read_text() + '\n' + (ROOT / 'tests/gadget-server.setup.lua').read_text()
        if studio:
            setup += '\nfunction runService:IsStudio() return true end\n'
        base_setup = setup
        setup += "\nlocal nativeType=typeof; local function typeof(x) return getmetatable(x)==VM and 'Vector3' or nativeType(x) end\n"
        controller = bundle().replace('World.placeStart(scene)\n', 'World.placeStart(scene)\nscene.runStart=scene.fields[1].center\n', 1)
        path = directory / ('studio-logic.lua' if studio else 'production-logic.lua')
        path.write_text(setup + '\n' + controller + '\n;(function()\n' +
            (ROOT / 'tests/progression-overhaul.integration.lua').read_text() + '\nend)()')
        subprocess.run([str(luau / 'luau'), str(path)], check=True)
        # Existing earned worker -> sale -> pack -> prestige path. The fixture
        # supplies station travel; printed durations are worker time, not playtime.
        controller = bundle().replace('World.placeStart(scene)\n', '''World.placeStart(scene)
do
 local stand=Instance.new('Model');stand.Name='LegendaryPreviewStand';stand.Parent=scene.map
 World.part(stand,'Counter',scene.packStation.Position+Vector3.new(0,0,-12.5),Vector3.new(5,3,3),Color3.new(1,.7,.3))
end
''', 1)
        path = directory / ('studio-earned-loop.lua' if studio else 'production-earned-loop.lua')
        path.write_text(base_setup + '\n' + controller + '\n;(function()\n' +
            (ROOT / 'tests/workshop.integration.lua').read_text() + '\nend)()')
        subprocess.run([str(luau / 'luau'), str(path)], check=True)
subprocess.run([sys.executable, str(ROOT / 'tests/live-build.spec.py')], check=True)
print('PASS focused overhaul; engine motion, shared Edit sync and multiplayer NOT VERIFIED')
