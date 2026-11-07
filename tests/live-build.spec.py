"""Active capture builds change only the seven approved script Source values.
This is a binary preservation check, not a Studio playtest.
"""
import hashlib
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools'))
from build import (ACTIVE_BASE, ACTIVE_EXPECTED, ACTIVE_OUTPUT, ACTIVE_PLACE_ID,
                   LIVE_SOURCES, build, build_live, chunks, live_source_payload,
                   script_inventory, string)

original = ACTIVE_BASE.read_bytes()
assert hashlib.sha256(original).hexdigest() == ACTIVE_EXPECTED
before = list(chunks(original))
old_scripts = {item['ref']: item for item in script_inventory(before)}
payload = live_source_payload()
assert payload['place_id'] == ACTIVE_PLACE_ID == 124078027733625
assert payload['universe_id'] == 10774898335
assert payload['captured_from_place_id'] == 136098934779395
assert set(payload['sources']) == set(LIVE_SOURCES)

with tempfile.TemporaryDirectory() as temporary:
    directory = pathlib.Path(temporary)
    first, second = directory / 'first.rbxl', directory / 'second.rbxl'
    report = build_live(ACTIVE_BASE, first)
    build_live(ACTIVE_BASE, second)
    assert first.read_bytes() == second.read_bytes(), 'Nondeterministic active build'
    assert first.read_bytes()[:32] == original[:32], 'Header changed'
    after = list(chunks(first.read_bytes()))
    assert len(after) == len(before), 'Chunks appended or removed'
    changed_chunks = 0
    for (old_kind, old_data, old_raw), (new_kind, new_data, new_raw) in zip(before, after):
        assert old_kind == new_kind
        if old_raw != new_raw:
            changed_chunks += 1
            assert old_kind == b'PROP'
            assert string(old_data, 4)[0] == string(new_data, 4)[0] == 'Source'
    assert changed_chunks == report['changed_source_chunks']
    new_scripts = {item['ref']: item for item in script_inventory(after)}
    assert set(old_scripts) == set(new_scripts)
    seen = set()
    for ref, previous in old_scripts.items():
        current = new_scripts[ref]
        for key in ('path', 'class', 'cid', 'index'):
            assert previous[key] == current[key], (ref, key)
        path = current['path']
        if path in LIVE_SOURCES:
            assert path not in seen, 'Ambiguous allowlisted path'
            seen.add(path)
            assert current['source'] == payload['sources'][path]['source'].encode()
        else:
            assert previous['source'] == current['source'], 'Unrelated/backup Source changed: ' + path
    assert seen == set(LIVE_SOURCES)
    assert hashlib.sha256(ACTIVE_BASE.read_bytes()).hexdigest() == ACTIVE_EXPECTED
    invalid = directory / 'invalid.rbxl'
    invalid.write_bytes(original + b'changed')
    try:
        build_live(invalid, directory / 'invalid-output.rbxl')
    except AssertionError:
        pass
    else:
        raise AssertionError('Unverified active capture accepted')
    try:
        build(ACTIVE_BASE, ACTIVE_OUTPUT)
    except AssertionError:
        pass
    else:
        raise AssertionError('Historical builder accepted active destination')

print('PASS active capture: deterministic build, exact seven Source paths, all other chunks and backup Sources preserved; not Studio evidence')
