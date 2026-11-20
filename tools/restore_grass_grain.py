#!/usr/bin/env python3
"""Remove the added grass grain overlays, preserving the original materials."""
import argparse,json,re
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT
from refresh_quarry_sunshine import merge
from refresh_native_scenery import write_snapshot
p=argparse.ArgumentParser();p.add_argument('export',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
edits=json.loads(a.export.read_text());assert not edits['parts']
allowed={}
for e in edits['properties']:
    assert re.fullmatch(r'Workspace\.MiningAway\.Map\.(QuarryMeadowLayers\.[^.]+\.TurfPatch\d+\.OffsetFineGrain|QuarryCourtyard\.GroundLayers\.[^.]+\.SecondaryGrain)',e['path'])
    assert e['property']=='Transparency' and e['after']==1
    allowed[e['path']]={'Transparency'}
data=CANONICAL_OUTPUT.read_bytes()
assert sha256(data).hexdigest()=='2b13719c8b9b2f2d55fc8e33f45fc4abaa3bedf1801c92a6b41cddde903ccb11'
result,report=merge(data,edits,allowed_properties=allowed)
if a.write:write_snapshot(data,result)
print(json.dumps(dict(report,sha256=sha256(result).hexdigest(),wrote=a.write)))
