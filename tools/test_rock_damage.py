#!/usr/bin/env python3
"""Production damage plans, async ownership and bounded CSG scheduling."""
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
luau = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/mining-away-luau')
source = '\n'.join([
    (ROOT / 'tests/special-fx.setup.lua').read_text(),
    'local CrystalGeometry\nlocal Content={fromObject=function(object) return object end}',
    'local RockDamage=(function()\n' + (ROOT / 'src/RockDamage.lua').read_text() + '\nend)()',
    (ROOT / 'tests/rock-damage.integration.lua').read_text(),
])
with tempfile.TemporaryDirectory(prefix='rock-damage-') as directory:
    path = pathlib.Path(directory) / 'behavior.lua'
    path.write_text(source)
    subprocess.run([str(luau / 'luau-compile'), str(path)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([str(luau / 'luau'), str(path)], check=True)
