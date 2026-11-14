#!/usr/bin/env python3
"""Mirror the five decorative plot trim transparency changes from Studio Edit."""
import argparse
import json
from hashlib import sha256
from pathlib import Path

from build import CANONICAL_OUTPUT
from refresh_native_scenery import write_snapshot
from refresh_quarry_sunshine import merge

PATHS = {f'Workspace.MiningAway.Fields.{name}.Border'
         for name in ('Quartz', 'Ruby', 'Cobalt', 'Violet', 'Emerald')}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('export', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()

    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, 'Canonical file changed'
    edits = json.loads(args.export.read_text())
    properties = edits['properties']
    assert not edits['parts'] and len(properties) == len(PATHS)
    assert {entry['path'] for entry in properties} == PATHS
    assert all(entry == dict(path=entry['path'], property='Transparency', before=0, after=1)
               for entry in properties)
    result, report = merge(data, edits, allowed_properties={path: {'Transparency'} for path in PATHS})
    if args.write:
        write_snapshot(data, result)
    print(json.dumps(dict(report, sha256=sha256(result).hexdigest(), wrote=args.write)))


if __name__ == '__main__':
    main()
