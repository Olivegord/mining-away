#!/usr/bin/env python3
"""Current Crystal Run work/reward audit. This is not a gameplay or fun test."""
import argparse
import subprocess
import tempfile
from pathlib import Path

from build import ROOT

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', type=Path, default=Path('/private/tmp/drone-luau/luau'))
args = parser.parse_args()
source = (ROOT / 'tests/mining-loop-audit.lua').read_text()
# Run next to the real modules so their relative requires resolve unchanged.
with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', prefix='audit-', dir=ROOT / 'tests') as script:
    script.write(source)
    script.flush()
    subprocess.run([str(args.luau), script.name], check=True, cwd=ROOT)
