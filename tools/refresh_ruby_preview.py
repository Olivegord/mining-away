#!/usr/bin/env python3
"""Mirror just the restored Ruby preview in the canonical native place."""
import argparse
from hashlib import sha256
from pathlib import Path

from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import Native, MAP, write_parents, write_snapshot
from refresh_quarry_blockscape import append_export


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--baseline-sha256', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, 'Canonical changed'
    native = Native(data)
    ruby = MAP + '.MineralLineup.Ruby'
    archive = native.one('ServerStorage.MineralLineupArchive')
    assert not native.paths.get('ServerStorage.MineralLineupArchive.PreviewGeometry')
    old = native.one(ruby + '.PreviewGeometry')
    moved = write_parents(native, {**native.parents, old: archive})
    result = append_export(moved, args.directory, 'ruby', ruby, 'PreviewGeometry', {'Folder', 'UnionOperation'})
    final = Native(result)
    assert native.instances.items() <= final.instances.items()
    assert native.props.items() <= final.props.items()
    assert all(final.parents[r] == (archive if r == old else parent) for r, parent in native.parents.items())
    assert script_inventory(native.chunks) == script_inventory(final.chunks)
    assert len(final.instances) == len(native.instances) + 3
    final.one(ruby + '.PreviewGeometry.FacetShell')
    final.one(ruby + '.PreviewGeometry.FixedInclusions')
    if args.write:
        write_snapshot(data, result)
    print(f'Ruby preview {"written" if args.write else "checked"}: {sha256(result).hexdigest()}')


if __name__ == '__main__':
    main()
