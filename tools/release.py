#!/usr/bin/env python3
"""Build the captured active place and stamp it with the exact source revision."""
from __future__ import annotations

import hashlib
import json
import subprocess
import zipfile
import argparse
from pathlib import Path

from build import (ROOT, build_live, ACTIVE_BASE, ACTIVE_OUTPUT, ACTIVE_PLACE_ID,
                   editor_layout_script, chunks, script_inventory, live_source_payload)


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--allow-dirty', action='store_true', help='Explicitly stamp an unfinished review build as dirty')
    args = parser.parse_args()
    try:
        revision = git("rev-parse", "HEAD")
        dirty = bool(git("status", "--porcelain", "--untracked-files=normal"))
        source_paths = git("ls-files").splitlines()
    except subprocess.CalledProcessError:
        revision, dirty = "uncommitted-bootstrap", True
        source_paths = []
    if dirty and not args.allow_dirty:
        raise RuntimeError('Commit the reviewed source before release, or use --allow-dirty for an explicitly unfinished build')
    output = ACTIVE_OUTPUT
    output.parent.mkdir(exist_ok=True)
    report = build_live(ACTIVE_BASE, output)
    layout_script = output.parent / 'apply-editable-workspace.lua'
    layout_script.write_text(editor_layout_script())
    editable = output.parent / 'Drone Blower revolution - editable workspace.rbxl'
    editable_metadata = None
    if editable.exists():
        # A native editor export includes authorized geometry edits. It must
        # contain this exact source revision and every preserved backup script.
        actual = {item['path']: item for item in script_inventory(list(chunks(editable.read_bytes())))}
        original = {item['path']: item for item in script_inventory(list(chunks(ACTIVE_BASE.read_bytes())))}
        expected = live_source_payload()['sources']
        if not set(original).issubset(actual):
            raise RuntimeError('Editable copy is missing preserved scripts')
        extra = sorted(set(actual)-set(original))
        if any(not path.startswith('ServerStorage.') for path in extra):
            raise RuntimeError('Editable copy contains an unexpected active script')
        for path, item in original.items():
            source = expected[path]['source'].encode() if path in expected else item['source']
            if actual[path]['source'] != source:
                raise RuntimeError('Refresh the native editable copy before release: '+path)
        editable_metadata = {'place': editable.name,
                             'sha256': hashlib.sha256(editable.read_bytes()).hexdigest(),
                             'additional_archived_scripts': [
                                 {'path': path, 'sha256': hashlib.sha256(actual[path]['source']).hexdigest()}
                                 for path in extra],
                             'validation': 'Native Edit export; exact live and backup Sources verified. Not a Play test.'}
        refresh = output.parent / 'editable-source-refresh.json'
        if refresh.exists():
            record = json.loads(refresh.read_text())
            if record['after_sha256'] == editable_metadata['sha256']:
                editable_metadata['validation'] = 'Preserved native Edit geometry; allowlisted Sources refreshed offline and all other chunks/backups verified. Existing Studio Play untouched. Not a Play test.'
    metadata = {
        "project": "Olivegord/mining-away",
        "place_id": ACTIVE_PLACE_ID,
        "target": "Drone Blower revolution",
        "source_commit": revision,
        "source_dirty": dirty,
        "place": output.name,
        "place_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "base_sha256": report["original_sha256"],
        "studio_validation": "Not established by this build command; see review report.",
        "editor_layout_script": layout_script.name,
        "editable_workspace": editable_metadata,
    }
    metadata_path = output.parent / "revision.json"
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    package = output.parent / "drone-blower-revolution-review.zip"
    with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.write(output, output.name)
        archive.write(metadata_path, "revision.json")
        archive.write(output.parent / "build-report.json", "build-report.json")
        archive.write(layout_script, layout_script.name)
        if editable_metadata:
            archive.write(editable, editable.name)
        for relative in source_paths:
            path = ROOT / relative
            if path.is_file() and not path.is_symlink() and not relative.startswith("build/"):
                archive.write(path, "source/" + relative)
    print(json.dumps({"metadata": metadata, "package": str(package)}, indent=2))


if __name__ == "__main__":
    main()

