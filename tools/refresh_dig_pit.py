#!/usr/bin/env python3
"""Save the Dig Cube pit (a hole in the ground plate, shaft lining and floor) into the canonical place.

Usage: python3 tools/refresh_dig_pit.py EXPORT.json --baseline-sha256 HASH [--write]
EXPORT.json is what tools/studio_dig_pit.lua returned in shared Edit.
Only the Baseplate's position and size change; Workspace.MiningAway.DigPit
(a Folder of Parts) is added. Nothing else, and no script, may change.
"""
import argparse
import json
import tempfile
from hashlib import sha256
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import MAP, Native, merge, patch_parts, write_snapshot

BASE = 'Workspace.MiningAway.Fields.Baseplate'


def validate(edit):
    assert edit['path'] == BASE, edit['path']
    assert edit['before'].keys() == edit['after'].keys() == {'position', 'size'}


def refresh(base, export):
    original = Native(base)
    assert len(export['edits']) == 1
    patched, touched = patch_parts(original, export['edits'], validate_edit=validate)
    with tempfile.TemporaryDirectory() as folder:
        directory = Path(folder)
        (directory/'scenery.b64').write_text(export['scenery'])
        staged, stats = merge(patched, directory, addition={'scenery': (MAP, {'DigPit'}, {'Folder', 'Part'})})
    final = Native(staged)
    assert original.instances.items() <= final.instances.items()
    assert all(final.parents[ref] == parent for ref, parent in original.parents.items())
    changed = {key for key, value in original.props.items() if final.props[key] != value}
    assert changed == set(touched), changed
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    assert stats['new_instances'] == 9, stats
    return final.data, dict(stats, baseplate_props=sorted(prop for _, prop in touched))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    base = CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest() == args.baseline_sha256, 'Reconcile the current canonical map first'
    result, stats = refresh(base, json.loads(args.export.read_text()))
    if args.write:
        write_snapshot(base, result)
    print(json.dumps(dict(stats, sha256=sha256(result).hexdigest(), written=args.write), indent=2))


if __name__ == '__main__':
    main()
