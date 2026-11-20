#!/usr/bin/env python3
"""Save clear daytime lighting with no scenery or source changes."""
import argparse,json
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT
from refresh_quarry_sunshine import merge
from refresh_native_scenery import write_snapshot
p=argparse.ArgumentParser();p.add_argument('export',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
e=json.loads(a.export.read_text());assert not e['parts']
allowed={'Lighting':{'TimeOfDay','GeographicLatitude','Brightness','ExposureCompensation','Ambient','OutdoorAmbient','EnvironmentDiffuseScale'},'Lighting.ColorCorrection':{'Brightness','Contrast','Saturation'}}
data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()=='28e4cd139b8c0895791790bf48229bc80b9dc5a2ca974640efe2d0d5d9861454'
result,report=merge(data,e,allowed_properties=allowed)
if a.write:write_snapshot(data,result)
print(json.dumps(dict(report,sha256=sha256(result).hexdigest(),wrote=a.write)))
