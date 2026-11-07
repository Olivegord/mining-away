#!/usr/bin/env python3
"""Refresh, verify and package the single existing editable game.

A release never reconstructs the game from a historical capture and never puts
another playable place beside the canonical native Edit export.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

from build import (ROOT, ACTIVE_BASE, ACTIVE_EXPECTED, ACTIVE_OUTPUT, ACTIVE_PLACE_ID,
                   ACTIVE_UNIVERSE_ID, ACTIVE_EXPERIENCE_NAME, REFERENCE_PLACE_ID,
                   chunks, script_inventory, live_source_payload)
from refresh_editable import refresh


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def _inventory(data: bytes) -> list[dict]:
    return script_inventory(list(chunks(data)))


def validate_canonical(output: Path, *, require_current: bool = True) -> dict:
    """Verify exact live paths plus preserved native/archived script Sources."""
    data = output.read_bytes()
    reference = ACTIVE_BASE.read_bytes()
    if hashlib.sha256(reference).hexdigest() != ACTIVE_EXPECTED:
        raise RuntimeError('Immutable reference checksum mismatch; cannot verify preserved scripts')
    actual = _inventory(data)
    original = _inventory(reference)
    expected = live_source_payload()['sources']
    current = True
    for path, entry in expected.items():
        matches = [item for item in actual if item['path'] == path]
        if len(matches) != 1 or matches[0]['class'] != entry['class']:
            raise RuntimeError('Canonical game has a missing or ambiguous live script: ' + path)
        if matches[0]['source'] != entry['source'].encode():
            current = False
            if require_current:
                raise RuntimeError('Canonical game Source is stale: ' + path)
    # Compare multisets: two backups with the same hierarchy path must both
    # survive, even though only the seven unique live paths are refreshed.
    def fingerprint(item: dict) -> tuple:
        return item['path'], item['class'], hashlib.sha256(item['source']).hexdigest()
    preserved = Counter(fingerprint(item) for item in original if item['path'] not in expected)
    present = Counter(fingerprint(item) for item in actual if item['path'] not in expected)
    if preserved - present:
        raise RuntimeError('Canonical game is missing or has changed a preserved backup/unrelated script')
    extras = present - preserved
    if any(not path.startswith('ServerStorage.') for path, _, _ in extras):
        raise RuntimeError('Canonical game contains an unexpected active script')
    return {
        'sha256': hashlib.sha256(data).hexdigest(),
        'sources_current': current,
        'source_sha256': {path: entry['sha256'] for path, entry in expected.items()},
        'additional_archived_scripts': [
            {'path': path, 'class': cls, 'sha256': digest, 'copies': count}
            for (path, cls, digest), count in sorted(extras.items())
        ],
    }


def _previous_release_commit(output: Path, before_sha256: str) -> str | None:
    """Trust an old release only when it identifies these exact native bytes."""
    metadata_path = output.parent / 'revision.json'
    if not metadata_path.is_file():
        return None
    try:
        metadata = json.loads(metadata_path.read_text())
    except (ValueError, OSError):
        return None
    if not isinstance(metadata, dict):
        return None
    identifies_output = metadata.get('place') == output.name and metadata.get('place_sha256') == before_sha256
    # Allow a one-time transition from older metadata which listed the native
    # export alongside a competing generated file. Only the native hash counts.
    old_editable = metadata.get('editable_workspace')
    if isinstance(old_editable, dict):
        identifies_output = identifies_output or (old_editable.get('place') == output.name and old_editable.get('sha256') == before_sha256)
    revision = metadata.get('source_commit')
    if identifies_output and metadata.get('source_dirty') is False and isinstance(revision, str) and re.fullmatch(r'[0-9a-f]{40,64}', revision):
        return revision
    return None


def refresh_canonical(output: Path, previous_commit: str | None, previous_payload: Path | None) -> dict:
    """Use the existing guarded refresh, then independently verify its result."""
    before = output.read_bytes()
    inspected = validate_canonical(output, require_current=False)
    if not inspected['sources_current']:
        if previous_commit is None and previous_payload is None:
            previous_commit = _previous_release_commit(output, inspected['sha256'])
        if previous_commit is None and previous_payload is None:
            raise RuntimeError('Canonical game has unverified editor Sources. Supply --previous-commit or --previous-payload for its exact installed Sources; no alternate game will be created')
    refresh(previous_commit=previous_commit, previous_payload=previous_payload, destination=output)
    result = validate_canonical(output)
    after = output.read_bytes()
    before_chunks, after_chunks = list(chunks(before)), list(chunks(after))
    if before[:32] != after[:32] or len(before_chunks) != len(after_chunks):
        raise RuntimeError('Canonical refresh changed the native place header or chunk inventory')
    changed_chunks = 0
    for (kind, decoded, raw), (after_kind, _, updated) in zip(before_chunks, after_chunks):
        if raw != updated:
            from build import string
            if kind != after_kind or kind != b'PROP' or string(decoded, 4)[0] != 'Source':
                raise RuntimeError('Canonical refresh changed native geometry or another non-Source chunk')
            changed_chunks += 1
    # Every unrelated Source must also match the input native export, including
    # additional author backups not present in the original reference capture.
    old = {item['ref']: item for item in _inventory(before)}
    allowlist = result['source_sha256']
    for item in _inventory(after):
        if item['path'] not in allowlist and item != old.get(item['ref']):
            raise RuntimeError('Canonical refresh changed a native backup/unrelated script: ' + item['path'])
    return {
        'place_id': ACTIVE_PLACE_ID,
        'method': 'Source-only refresh of the existing canonical native Edit export',
        'canonical_place': output.name,
        'before_sha256': inspected['sha256'],
        'after_sha256': result['sha256'],
        'changed_source_chunks': changed_chunks,
        'source_sha256': result['source_sha256'],
        'additional_archived_scripts': result['additional_archived_scripts'],
        'preserved': 'All non-Source chunks, native geometry, hierarchy, assets and unrelated/backup Sources remain byte-identical to the canonical input',
        'studio_validation': 'Offline preservation verification only; no Studio or multiplayer test is implied',
    }


def _write_json(path: Path, value: dict) -> None:
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf8', dir=path.parent, prefix='.release-metadata-', delete=False) as temporary:
        json.dump(value, temporary, indent=2)
        temporary.write('\n')
        temporary_path = Path(temporary.name)
    temporary_path.replace(path)


def _is_place_file(relative: str) -> bool:
    name = relative.lower()
    return name.endswith(('.rbxl', '.rbxlx', '.rbxl.previous', '.rbxlx.previous'))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-dirty', action='store_true', help='Explicitly stamp an unfinished review build as dirty')
    previous = parser.add_mutually_exclusive_group()
    previous.add_argument('--previous-commit', help='Exact revision currently installed in the canonical native export')
    previous.add_argument('--previous-payload', type=Path, help='Exact installed seven-Source payload, including verified hashes')
    args = parser.parse_args()
    output = ACTIVE_OUTPUT
    if not output.is_file():
        raise RuntimeError('The existing canonical editable game is required: ' + str(output) + '. Restore that native export; release will not substitute a capture or create another game')
    if output.is_symlink() or output.resolve().is_relative_to((ROOT / 'assets').resolve()):
        raise RuntimeError('Canonical release must not overwrite a source asset or a symlink')
    try:
        revision = git("rev-parse", "HEAD")
        dirty = bool(git("status", "--porcelain", "--untracked-files=normal"))
        source_paths = git("ls-files").splitlines()
    except subprocess.CalledProcessError:
        revision, dirty = "uncommitted-bootstrap", True
        source_paths = []
    if dirty and not args.allow_dirty:
        raise RuntimeError('Commit the reviewed source before release, or use --allow-dirty for an explicitly unfinished build')
    report = refresh_canonical(output, args.previous_commit, args.previous_payload)
    metadata = {
        "project": "Olivegord/mining-away",
        "place_id": ACTIVE_PLACE_ID,
        "universe_id": ACTIVE_UNIVERSE_ID,
        "experience_name": ACTIVE_EXPERIENCE_NAME,
        "publication_status": "Local package only; Roblox publication is not performed or verified by this tool",
        "captured_from_place_id": REFERENCE_PLACE_ID,
        "target": "DRONE_GAME",
        "source_commit": revision,
        "source_dirty": dirty,
        "place": output.name,
        "place_sha256": report['after_sha256'],
        "reference_capture_sha256": ACTIVE_EXPECTED,
        "studio_validation": "Not established by this release command; see review report.",
        "delivery_policy": "One canonical native editable place; source assets/history are not alternate playable releases",
        "preservation_report": "canonical-source-report.json",
    }
    metadata_path = output.parent / "revision.json"
    report_path = output.parent / 'canonical-source-report.json'
    _write_json(metadata_path, metadata)
    _write_json(report_path, report)
    package = output.parent / "drone-blower-revolution-review.zip"
    with tempfile.NamedTemporaryFile(dir=output.parent, prefix='.canonical-release-', suffix='.zip', delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with zipfile.ZipFile(temporary_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(output, output.name)
            archive.write(metadata_path, "revision.json")
            archive.write(report_path, report_path.name)
            for relative in source_paths:
                path = ROOT / relative
                if path.is_file() and not path.is_symlink() and not relative.startswith("build/") and not _is_place_file(relative):
                    archive.write(path, "source/" + relative)
        temporary_path.replace(package)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()
    print(json.dumps({"metadata": metadata, "preservation": report, "package": str(package)}, indent=2))


if __name__ == "__main__":
    main()
