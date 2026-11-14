#!/usr/bin/env python3
"""Stage a guarded, Source-only native install. Serve build on localhost:8767,
then execute build/refinement-studio-install.lua in the connected Edit model.
No publication; HTTP is enabled only while reading the local payload and restored.
"""
import argparse
import importlib.util
import io
import json
import subprocess
import tarfile
import tempfile
from pathlib import Path
from build import ROOT, live_source_payload
from refresh_editable import validate_previous_payload

parser=argparse.ArgumentParser()
group=parser.add_mutually_exclusive_group(required=True)
group.add_argument('--previous-commit')
group.add_argument('--previous-payload',type=Path,help='Exact previously installed staged Sources')
args=parser.parse_args()
if args.previous_payload:
    previous_payload=json.loads(args.previous_payload.read_text())
    validate_previous_payload(previous_payload)
    (ROOT/'build/refinement-before-payload.json').write_text(json.dumps(previous_payload))
else:
    with tempfile.TemporaryDirectory(prefix='mining-install-baseline-') as directory:
        archive=subprocess.run(['git','archive',args.previous_commit,'src','tools'],cwd=ROOT,capture_output=True,check=True).stdout
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            for member in tar.getmembers():
                assert '..' not in Path(member.name).parts and (member.isdir() or member.isfile())
            tar.extractall(directory)
        spec=importlib.util.spec_from_file_location('mining_previous_build',Path(directory)/'tools/build.py')
        previous=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(previous)
        (ROOT/'build/refinement-before-payload.json').write_text(json.dumps(previous.live_source_payload()))
(ROOT/'build/refinement-source-payload.json').write_text(json.dumps(live_source_payload()))
(ROOT/'build/refinement-studio-install.lua').write_text((ROOT/'tools/studio_source_install.lua').read_text())
print('Staged exact previous/current Sources and checked native installer in build/')
