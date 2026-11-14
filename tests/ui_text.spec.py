"""Source guard for essential production UI text and responsive disclosure.

This catches obvious sub-16px regressions; only native Studio rendering can
validate TextBounds, clipping, device readability, focus, or interactions.
"""
from pathlib import Path
import re
s = (Path(__file__).resolve().parents[1] / 'src/Client.lua').read_text()
start = s.index('local hud=U.panel')
end = s.index('local refreshSerial=0')
for lineno, line in enumerate(s[start:end].splitlines(), 1):
    if 'label(' not in line:
        continue
    for match in re.finditer(r',\s*(\d+(?:\.\d+)?)\s*,\s*(?:palette\.|nil\b)', line):
        assert float(match.group(1)) >= 16, f'essential UI text below 16px (slice line {lineno}): {line}'
for name in ('titleHeight=wrappedHeight', 'targetHeight=wrappedHeight',
             'effectHeight=wrappedHeight', 'keepHeight=wrappedHeight',
             'resetHeight=wrappedHeight', 'nameHeight=wrappedHeight',
             'identityHeight=wrappedHeight', 'subtitleHeight=math.max',
             "sheet:SetAttribute('MenuMode',mode)"):
    assert name in s, f'missing production reflow/inspection hook: {name}'
assert "saveLabel.Text='NOT SAVED'" in s, 'preview must clearly disclose no durable save'
assert "saveLabel.Text='LOAD FAILED'" in s, 'load failure must be visible'
print('PASS source guard for essential UI typography and measured disclosure reflow; Studio rendering still required')
