#!/usr/bin/env python3
"""Exercise field commands, natural pickup and seller choreography against the server."""
from pathlib import Path
import subprocess
import sys
import tempfile

from build import ROOT, bundle

luau = Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/drone-luau')
server = bundle().replace('World.placeStart(scene)\n', 'World.placeStart(scene)\nscene.runStart=scene.fields[1].center\n', 1)
source = '\n'.join([
    (ROOT / 'tests/mock-roblox.lua').read_text(),
    (ROOT / 'tests/gadget-server.setup.lua').read_text(),
    "do local nativeType=typeof; typeof=function(x) return getmetatable(x)==VM and 'Vector3' or nativeType(x) end end",
    server,
    ';(function()\n' + (ROOT / 'tests/field-pickup-flow.integration.lua').read_text() + '\nend)()',
])
with tempfile.TemporaryDirectory(prefix='field-pickup-flow-') as directory:
    fixture = Path(directory) / 'flow.lua'
    fixture.write_text(source)
    subprocess.run([str(luau / 'luau'), str(fixture)], check=True)
