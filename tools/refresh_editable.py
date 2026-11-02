#!/usr/bin/env python3
"""Refresh only allowlisted Sources in the previous native Edit export.
Keeps its authored map while the owner's existing Play session stays running.
Never operates on source assets, publishes, or claims to hot-reload Studio.
"""
import argparse
import hashlib
import importlib.util
import io
import json
import pathlib
import shutil
import struct
import subprocess
import tarfile
import tempfile

from build import ROOT, LIVE_SOURCES, chunks, script_inventory, live_source_payload, string_values, string, u32, chunk


def refresh(previous_commit):
    destination = ROOT / 'build/Drone Blower revolution - editable workspace.rbxl'
    assert destination.is_file(), 'A preserved native Edit export is required'
    # Build the expected previous Sources from its exact Git revision. Refuse to
    # overwrite someone else's newer editor changes or an unknown place.
    archive = subprocess.run(['git', 'archive', previous_commit, 'src', 'tools/build.py'], cwd=ROOT, check=True, capture_output=True).stdout
    with tempfile.TemporaryDirectory(prefix='mining-previous-sources-') as directory:
        temporary = pathlib.Path(directory)
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            for member in tar.getmembers():
                assert (member.name in ('src', 'tools') or member.name.startswith(('src/', 'tools/'))) and '..' not in pathlib.PurePosixPath(member.name).parts
                assert member.isdir() or member.isfile()
            tar.extractall(temporary)
        spec = importlib.util.spec_from_file_location('previous_mining_build', temporary / 'tools/build.py')
        old = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(old)
        expected = old.live_source_payload()['sources']
    data = destination.read_bytes()
    before = list(chunks(data)); inventory = script_inventory(before)
    payload = live_source_payload()['sources']; edits = {}
    for path, entry in payload.items():
        matches = [item for item in inventory if item['path'] == path]
        assert len(matches) == 1 and matches[0]['class'] == entry['class'], path
        item = matches[0]
        assert item['source'] in (expected[path]['source'].encode(), entry['source'].encode()), 'Unreviewed editor Source: ' + path
        edits[item['cid'], item['index']] = entry['source'].encode()
    result = [data[:32]]
    for kind, decoded, raw in before:
        if kind == b'PROP':
            cid = u32(decoded); name, offset = string(decoded, 4)
            if name == 'Source' and any(key[0] == cid for key in edits):
                assert decoded[offset] == 1
                values = string_values(decoded, offset + 1, sum(item['cid'] == cid for item in inventory))
                replacement = [edits.get((cid, index), value) for index, value in enumerate(values)]
                if values != replacement:
                    result.append(chunk(kind, decoded[:offset + 1] + b''.join(struct.pack('<I', len(value)) + value for value in replacement)))
                    continue
        result.append(raw)
    built = b''.join(result); after = list(chunks(built))
    assert len(before) == len(after)
    for (kind, decoded, raw), (_, _, updated) in zip(before, after):
        if raw != updated:
            assert kind == b'PROP' and string(decoded, 4)[0] == 'Source'
    previous = {item['ref']: item for item in inventory}
    for item in script_inventory(after):
        path = item['path']
        assert item['source'] == (payload[path]['source'].encode() if path in LIVE_SOURCES else previous[item['ref']]['source']), path
    shutil.copy2(destination, destination.with_suffix('.rbxl.previous'))
    with tempfile.NamedTemporaryFile(dir=destination.parent, prefix='.editable-refresh-', delete=False) as output:
        output.write(built); temporary = pathlib.Path(output.name)
    temporary.replace(destination)
    report = {'method': 'Offline Source-only refresh of preserved native Edit export', 'previous_source_commit': previous_commit,
              'before_sha256': hashlib.sha256(data).hexdigest(), 'after_sha256': hashlib.sha256(built).hexdigest(),
              'source_sha256': {path: entry['sha256'] for path, entry in payload.items()},
              'preserved': 'All non-Source chunks and all unrelated/backup Sources byte-identical to prior native export',
              'studio': 'Existing Play untouched; these changes are not loaded in that session'}
    (ROOT / 'build/editable-source-refresh.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--previous-commit', required=True)
    refresh(parser.parse_args().previous_commit)
