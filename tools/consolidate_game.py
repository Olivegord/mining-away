#!/usr/bin/env python3
"""Keep the native editable workspace and remove only verified generated duplicates.

Never reconstruct a native map, replace source assets, publish, or silently
discard an unknown editor Source/geometry change. The canonical file must exist
before any duplicate can be removed.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import zipfile

from build import (ACTIVE_BASE, ACTIVE_EXPECTED, ACTIVE_PLACE_ID, CANONICAL_OUTPUT,
                   LEGACY_OUTPUT, LIVE_SOURCES, ROOT, chunks, live_source_payload,
                   script_inventory, string)
from refresh_editable import refresh, verified_previous_sources


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_generated_duplicate(data, base, payload, previous=None):
    """Prove a file contains only recognized Source edits to the immutable capture."""
    assert digest(base) == ACTIVE_EXPECTED, 'Immutable live capture checksum mismatch'
    assert data[:32] == base[:32], 'Competing place has an unknown header; preserve it for manual merge'
    original, candidate = list(chunks(base)), list(chunks(data))
    assert len(original) == len(candidate), 'Competing place has different native chunks; preserve it for manual merge'
    for (kind, decoded, raw), (other_kind, other_decoded, other_raw) in zip(original, candidate):
        assert kind == other_kind, 'Competing place has a different native chunk order; preserve it for manual merge'
        if raw != other_raw:
            assert kind == b'PROP' and string(decoded, 4)[0] == string(other_decoded, 4)[0] == 'Source', \
                'Competing place has geometry/properties outside Source; preserve it for manual merge'
    original_scripts = script_inventory(original)
    other_scripts = script_inventory(candidate)
    assert len(original_scripts) == len(other_scripts), 'Competing place has a different script inventory'
    old_by_ref = {entry['ref']: entry for entry in original_scripts}
    assert len(old_by_ref) == len(original_scripts), 'Ambiguous original script referents'
    seen = set()
    for entry in other_scripts:
        prior = old_by_ref.get(entry['ref'])
        assert prior and all(entry[key] == prior[key] for key in ('path', 'class', 'cid', 'index')), 'Competing place script identity differs'
        path = entry['path']
        if path in LIVE_SOURCES:
            assert path not in seen, 'Ambiguous competing live Source: ' + path
            seen.add(path)
            accepted = [payload[path]['source'].encode()]
            if previous is not None:
                accepted.append(previous[path]['source'].encode())
            assert entry['source'] in accepted, 'Competing place has unreviewed live Source; preserve it for manual merge: ' + path
        else:
            assert entry['source'] == prior['source'], 'Competing place has changed backup/unrelated Source; preserve it: ' + path
    assert seen == set(LIVE_SOURCES), 'Competing place is missing an allowlisted live Source'


def verify_archived_source(archive, item, previous_commit, previous):
    """Do not discard unbundled newer game code hidden beside a known place."""
    name = pathlib.PurePosixPath(item.filename)
    if len(name.parts) < 3 or name.parts[:2] != ('source', 'src') or name.suffix.lower() != '.lua':
        return
    assert '..' not in name.parts and item.file_size <= 16 * 1024 * 1024, 'Unexpected archived Source path/size'
    source = archive.read(item)
    relative = pathlib.PurePosixPath(*name.parts[1:])
    current = ROOT.joinpath(*relative.parts)
    if current.is_file() and not current.is_symlink() and current.read_bytes() == source:
        return
    if previous_commit is not None:
        stored = subprocess.run(['git', 'show', '--end-of-options', str(previous_commit) + ':' + str(relative)],
                                cwd=ROOT, capture_output=True)
        if stored.returncode == 0 and stored.stdout == source:
            return
    if previous is not None:
        # Bundling removes only these known lexical declarations. Compare the
        # complete module body with an exact, hash-validated previous payload.
        def body(value):
            result = value.replace(b'--!strict\n', b'')
            for dependency in ('Shops', 'DroneRoles', 'DroneCatalog'):
                result = result.replace(("local " + dependency + "=require('./" + dependency + "')\n").encode(), b'')
            return result
        candidate = body(source)
        if candidate.strip() and any(candidate in body(entry['source'].encode()) for entry in previous.values()):
            return
    raise AssertionError('Release archive has unreviewed unbundled game Source; preserve it for manual merge: ' + item.filename)


def consolidate(previous_commit=None, previous_payload=None, destination=CANONICAL_OUTPUT):
    """Refresh/validate the canonical native file, then preflight every deletion."""
    destination = pathlib.Path(destination)
    assert destination.is_file(), 'Canonical native editable workspace is required; refusing a capture fallback: ' + str(destination)
    assert not destination.is_symlink(), 'Refusing to consolidate a symlinked canonical place'
    canonical_before = destination.read_bytes()
    canonical_before_sha256 = digest(canonical_before)
    refreshed = refresh(previous_commit=previous_commit, previous_payload=previous_payload, destination=destination)
    assert canonical_before_sha256 == refreshed['before_sha256'], 'Canonical place changed before refresh; review the new native save before consolidation'
    canonical = destination.read_bytes()
    canonical_sha256 = digest(canonical)
    assert canonical_sha256 == refreshed['after_sha256'], 'Canonical place changed after refresh'
    payload = live_source_payload()['sources']
    previous = verified_previous_sources(previous_commit, previous_payload)
    duplicate = destination.parent / LEGACY_OUTPUT.name
    assert duplicate.resolve() != destination.resolve(), 'Canonical and competing paths must differ'
    base = None

    def verify(data):
        nonlocal base
        if base is None:
            base = ACTIVE_BASE.read_bytes()
        verify_generated_duplicate(data, base, payload, previous)

    pending = []
    if duplicate.exists():
        assert not duplicate.is_symlink() and duplicate.is_file(), 'Refusing a symlinked or non-file competing place'
        data = duplicate.read_bytes()
        verify(data)
        pending.append((duplicate, data, 'Verified Source-only generated duplicate of the immutable capture'))

    # Known release packages only. Never sweep arbitrary ZIPs or other native
    # exports: they may contain the only copy of a newer map or editor Source.
    package = destination.parent / 'drone-blower-revolution-review.zip'
    kept_packages = []
    if package.exists():
        assert not package.is_symlink() and package.is_file(), 'Refusing a symlinked release package'
        package_data = package.read_bytes()
        with zipfile.ZipFile(package) as archive:
            places = [item for item in archive.infolist() if pathlib.PurePosixPath(item.filename).suffix.lower() in ('.rbxl', '.rbxlx')]
            canonical_only = len(places) == 1 and places[0].filename == destination.name
            immutable_hashes = {ACTIVE_EXPECTED}
            historical = ROOT / 'assets/mining-away-base.rbxl'
            if historical.is_file():
                immutable_hashes.add(digest(historical.read_bytes()))
            # The reviewed pre-refresh native file can have newer geometry than
            # the immutable capture. Its exact bytes are safe in a stale ZIP:
            # refresh preserved that geometry and retained its previous Sources
            # in the non-playable recovery backup. Do not generalize this trust
            # to other native maps that merely share a filename or script set.
            known_native_hashes = {canonical_sha256, canonical_before_sha256}
            for item in places:
                assert item.file_size <= 128 * 1024 * 1024, 'Oversized native file in release package; preserve archive for review'
                archived = archive.read(item)
                archived_sha256 = digest(archived)
                if archived_sha256 in known_native_hashes or archived_sha256 in immutable_hashes:
                    pass
                else:
                    verify(archived)
                if item.filename != destination.name or archived != canonical:
                    canonical_only = False
            if canonical_only:
                kept_packages.append(str(package))
            elif places:
                for item in archive.infolist():
                    verify_archived_source(archive, item, previous_commit, previous)
                pending.append((package, package_data, 'Stale release package containing verified alternative native files'))

    # Validate the complete deletion set before removing any member. A newer
    # duplicate or archive therefore leaves all candidate files available.
    assert destination.read_bytes() == canonical, 'Canonical place changed during consolidation'
    for path, data, _ in pending:
        assert path.is_file() and not path.is_symlink() and path.read_bytes() == data, 'Competing artifact changed during consolidation: ' + str(path)
    deleted = []
    for path, data, reason in pending:
        assert destination.read_bytes() == canonical, 'Canonical place changed before deletion'
        assert path.read_bytes() == data, 'Competing artifact changed before deletion: ' + str(path)
        path.unlink()
        deleted.append({'path': str(path), 'sha256': digest(data), 'bytes': len(data), 'reason': reason})
    report = {'place_id': ACTIVE_PLACE_ID, 'canonical_place': str(destination),
              'canonical_sha256': canonical_sha256, 'canonical_before_sha256': canonical_before_sha256, 'refresh': refreshed,
              'deleted_paths': [item['path'] for item in deleted], 'deleted': deleted,
              'kept_canonical_packages': kept_packages,
              'policy': 'Canonical native map retained; only verified generated duplicates removed. Immutable source assets unchanged. No native map reconstruction or Roblox publication.'}
    (destination.parent / 'single-game-consolidation.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--previous-commit', help='Exact previously installed Git revision')
    group.add_argument('--previous-payload', type=pathlib.Path, help='Exact previously installed source payload')
    args = parser.parse_args()
    print(json.dumps(consolidate(previous_commit=args.previous_commit, previous_payload=args.previous_payload), indent=2))
