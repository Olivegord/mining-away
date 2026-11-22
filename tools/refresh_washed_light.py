#!/usr/bin/env python3
"""Save the washed, bright daylight with no scenery or source changes.

Usage: python3 tools/refresh_washed_light.py EXPORT.json --baseline-sha256 HASH [--write]
EXPORT.json is what tools/studio_washed_light.lua returned in shared Edit.
"""
import argparse,json
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT
from refresh_quarry_sunshine import merge
from refresh_native_scenery import write_snapshot
p=argparse.ArgumentParser();p.add_argument('export',type=Path);p.add_argument('--baseline-sha256',required=True);p.add_argument('--write',action='store_true');a=p.parse_args()
e=json.loads(a.export.read_text());assert not e['parts']
allowed={'Lighting':{'TimeOfDay','Brightness','ExposureCompensation','Ambient','OutdoorAmbient','ColorShift_Top','ColorShift_Bottom','EnvironmentDiffuseScale','EnvironmentSpecularScale','ShadowSoftness'},'Lighting.QuarryAir':{'Density','Offset','Haze','Glare','Color','Decay'},'Lighting.ColorCorrection':{'Brightness','Contrast','Saturation','TintColor'},'Lighting.Bloom':{'Intensity','Size','Threshold'},'Lighting.SunRays':{'Intensity'}}
data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()==a.baseline_sha256
result,report=merge(data,e,allowed_properties=allowed)
if a.write:write_snapshot(data,result)
print(json.dumps(dict(report,sha256=sha256(result).hexdigest(),wrote=a.write)))
