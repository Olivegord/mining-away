#!/usr/bin/env python3
"""Mirror the verified Edit change to Lighting.DepthOfField.Enabled."""
import argparse
from hashlib import sha256
from pathlib import Path

from build import CANONICAL_OUTPUT, chunk, string, u32
from refresh_native_scenery import Native, write_snapshot


def disable(base):
    original = Native(base)
    ref = original.one('Lighting.DepthOfField')
    cid, cls, index, _ = original.instances[ref]
    assert cls == 'DepthOfFieldEffect'
    values = original.prop(cid, 'Enabled', 2)
    assert values[index] == 1, 'Expected the enabled authored effect'
    output = [base[:32]]
    for kind, data, raw in original.chunks:
        if kind == b'PROP' and u32(data) == cid:
            name, off = string(data, 4)
            if name == 'Enabled':
                raw = chunk(kind, data[:off+1] + values[:index] + b'\0' + values[index+1:])
        output.append(raw)
    result = Native(b''.join(output))
    assert result.parents == original.parents and result.instances == original.instances
    assert {k for k,v in original.props.items() if result.props[k] != v} == {(cid, 'Enabled')}
    assert result.prop(cid,'Enabled',2)[index] == 0
    return result.data


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true', help='Mirror after verifying the effect is disabled in shared Edit')
    args = parser.parse_args()
    base = Path(CANONICAL_OUTPUT).read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Canonical file changed; reconcile first'
    result = disable(base)
    if args.write:
        write_snapshot(base, result)
    print(f'Lighting.DepthOfField.Enabled=false; wrote={args.write}; SHA-256 {sha256(result).hexdigest()}')
