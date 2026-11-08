#!/usr/bin/env python3
"""Stage the live Mining Away art transfer and mirror its scoped exports to the canonical file."""
import argparse
import json
from pathlib import Path
from hashlib import sha256

from build import CANONICAL_OUTPUT, chunk, chunks, packstr, script_inventory, string, string_values, u32
from import_lighting import append_model, pack_words, words
from refresh_native_scenery import Native, MAP, close, read_section, write_parents, write_snapshot, unpack_colors
from refresh_quarry_courtyard import pack_floats, unpack_floats
from restore_reference_look import Values

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / 'docs/review/mining-away-reference.json'
BASELINE = '83159f31ab04bb552d32e6ce7b8905c34821888d4fe475977770fa4a7ccc039a'
TERRACE = MAP + '.DronerevolutionTerraces.'
ARCHIVE = 'ServerStorage.PreMiningAwayLook'
FIELDS = 'Workspace.MiningAway.Fields.'
MOVES = (
    *(MAP + '.' + n for n in (
        'QuarryLights', 'EmeraldChalkLagoon', 'QuarryLanterns', 'QuarryDepthPass',
        'LiminalReserve', 'QuarryArrivalAccents', 'ReserveIsland', 'QuarryCourtyard',
        'QuarryMeadowLayers', 'QuarryNaturalMeadow', 'QuarryBasinFoothills',
        'QuarryContinuousGround.OriginalDetails', 'JunkCubeAreas')),
    *(TERRACE + n for n in ('AssetScenery', 'IslandGround', 'GroundArt', 'MarketGardens', 'WoodenMarketStalls')),
    *(f'Lighting.{n}' for n in ('Bloom', 'ColorCorrection', 'DepthOfField', 'SunRays', 'Blur', 'Simple Sunset Sky')),
)
FINISH = {
    'Quartz': [168, 158, 132], 'Ruby': [180, 136, 127], 'Cobalt': [123, 133, 180],
    'Violet': [152, 138, 167], 'Emerald': [130, 158, 146], 'ImpactTest': [155, 149, 139],
}
SECTIONS = {
    'archive': ('ServerStorage', {'PreMiningAwayLook'}, {'Folder'}),
    'ground': (MAP, {'MiningAwayReferenceGround'}, {'Folder', 'Model', 'Part', 'Texture'}),
    'fx': ('Lighting', {'Bloom', 'DepthOfField', 'ColorCorrection', 'SunRays', 'Sky', 'Atmosphere'},
           {'BloomEffect', 'DepthOfFieldEffect', 'ColorCorrectionEffect', 'SunRaysEffect', 'Sky', 'Atmosphere'}),
    'hub': (MAP + '.SimpleFlatTestMap.HubPad', {'MiningAwayChecker'}, {'Texture'}),
    'crystal': ('ServerStorage', {'MiningAwayCrystal'}, {'UnionOperation'}),
}
PROPS = ('Color3uint8', 'MaterialVariantSerialized', 'Material', 'Reflectance')


def get(native, ref, key):
    cid, _, i, _ = native.instances[ref]
    dtype, raw = native.props[cid, key]
    n = len(native.classes[cid][1])
    if dtype == 18:
        return words(raw, n)[i]
    if dtype == 2:
        return bool(raw[i])
    return Values(native).get(ref, key)


def selected(path):
    return path.startswith((TERRACE, MAP + '.QuarryContinuousGround.Terraces.',
                           MAP + '.PlatformSurfaceFill.', MAP + '.SimpleFlatTestMap.', FIELDS)) or path in {
                               'Workspace.Converter', 'Workspace.SpawnLocation',
                               *(MAP + '.' + key + 'Shop' for key in FINISH),
                           }


def plan_for(base, reference):
    assert sha256(base).hexdigest() == BASELINE, 'Canonical snapshot changed; reconcile before applying'
    n = Native(base)
    values = Values(n)
    # Use the native enum value of the existing original Plastic material variant.
    plastic = 256  # Enum.Material.Plastic.Value
    finish = []
    cache = {}
    for path, refs in n.paths.items():
        if not selected(path) or any(path == m or path.startswith(m + '.') for m in MOVES):
            continue
        for ref in refs:
            cid, cls, index, name = n.instances[ref]
            if cls not in {'Part', 'WedgePart', 'SpawnLocation'}:
                continue
            if cid not in cache:
                count = len(n.classes[cid][1])
                cache[cid] = (words(n.prop(cid, 'Material', 18), count),
                              unpack_floats(n.prop(cid, 'Reflectance', 4), count))
            materials, reflectances = cache[cid]
            if materials[index] == 288:  # Neon status indicators still communicate interaction.
                continue
            color = [163, 162, 165]
            if name in {'Earth', 'EarthMass'}:
                color = [109, 106, 105]
            elif name == 'HubPad':
                color = [91, 91, 91]
            elif path.startswith(FIELDS) and name == 'Field':
                color = FINISH[path.split('.')[-2]]
            before = [values.get(ref, 'Color3uint8'), values.get(ref, 'MaterialVariantSerialized'),
                      materials[index], reflectances[index]]
            finish.append(dict(ref=ref, path=path, cls=cls, name=name,
                               pos=values.get(ref, 'CFrame'), size=values.get(ref, 'size'),
                               before=before, after=[color, '', plastic, 0]))
    lighting = [{ 'prop': p, 'before': get(n, n.one('Lighting'), p), 'after': v}
                for p, v in reference['lighting'].items() if p != 'LightingStyle']
    # Both docs already use Realistic; leave the saved renderer and hidden metadata intact.
    assert reference['lighting']['LightingStyle'] == 'Realistic'
    return dict(finish=finish, moves=MOVES, lighting=lighting, reference=reference)


def patch(base, plan):
    n = Native(base)
    changes = {}
    for row in plan['finish']:
        cid, _, i, _ = n.instances[row['ref']]
        for key, value in zip(PROPS, row['after']):
            changes.setdefault((cid, key), {})[i] = value
    cid, _, i, _ = n.instances[n.one('Lighting')]
    for row in plan['lighting']:
        changes[(cid, row['prop'])] = {i: row['after']}
    output = [base[:32]]
    for kind, data, raw in n.chunks:
        if kind == b'PROP':
            name, off = string(data, 4)
            cid = u32(data)
            if (cid, name) in changes:
                dtype, body = data[off], data[off + 1:]
                count = len(n.classes[cid][1])
                decode, encode = {
                    1: (lambda: [s.decode() for s in string_values(body, 0, count)],
                        lambda a: b''.join(packstr(x) for x in a)),
                    2: (lambda: list(body), bytes),
                    4: (lambda: unpack_floats(body, count), pack_floats),
                    12: (lambda: list(zip(*(unpack_floats(body[j * count * 4:(j + 1) * count * 4], count)
                                            for j in range(3)))),
                         lambda a: b''.join(pack_floats(axis) for axis in zip(*a))),
                    18: (lambda: words(body, count), pack_words),
                    26: (lambda: unpack_colors(body, count), lambda a: b''.join(bytes(axis) for axis in zip(*a))),
                }[dtype]
                values = decode()
                for i, value in changes[(cid, name)].items():
                    values[i] = value
                raw = chunk(kind, data[:off + 1] + encode(values))
        output.append(raw)
    return b''.join(output), set(changes)


def mirror(base, directory, plan):
    original = Native(base)
    result, changes = patch(base, plan)
    scope = list(SECTIONS.items())
    moves = {}
    for key, (parent, names, allowed) in scope:
        if key == 'fx':
            n = Native(result)
            moves = {n.one(path): n.one(ARCHIVE) for path in plan['moves']}
            result = write_parents(n, {**n.parents, **moves})
        model = read_section(directory, key)
        n, sub = Native(result), Native(model)
        assert {sub.instances[r][3] for r, p in sub.parents.items() if p == -1} == names
        assert all(cls in allowed for cls, _ in sub.classes.values()), (key, sub.classes.keys())
        assert all(not n.paths.get(parent + '.' + name) for name in names), key
        result = append_model(result, model, n.one(parent), chunks, chunk, u32, string, packstr)
    n = Native(result)
    assert original.instances.items() <= n.instances.items()
    assert all(n.parents[r] == moves.get(r, p) for r, p in original.parents.items())
    assert {k for k, v in original.props.items() if n.props[k] != v} <= changes
    assert script_inventory(original.chunks) == script_inventory(n.chunks)
    old, new = Values(original), Values(n)
    for path, refs in original.paths.items():
        if path.startswith(FIELDS) and path.endswith('.Field'):
            assert len(refs) == 1
            assert all(old.get(refs[0], k) == new.get(refs[0], k) for k in ('CFrame', 'size'))
    for row in plan['lighting']:
        actual, expected = get(n, n.one('Lighting'), row['prop']), row['after']
        assert (close(actual, expected) if isinstance(expected, list) else actual == expected), row['prop']
    return result, dict(native_sha256=sha256(result).hexdigest(), edited_finishes=len(plan['finish']),
                        archived_branches=len(moves), added_instances=len(n.instances)-len(original.instances),
                        preserved_sources=len(script_inventory(n.chunks)))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('directory', type=Path)
    ap.add_argument('--write', action='store_true')
    args = ap.parse_args()
    directory = args.directory
    directory.mkdir(parents=True, exist_ok=True)
    base = CANONICAL_OUTPUT.read_bytes()
    plan = plan_for(base, json.loads(REF.read_text()))
    if not all((directory / (k + '.b64')).exists() for k in SECTIONS):
        assert not args.write
        template = (ROOT / 'tools/studio_mining_away_look.lua').read_text()
        (directory / 'stage.lua').write_text(template.replace('[==[PLAN_JSON]==]', '[==[' + json.dumps(plan, separators=(',', ':')) + ']==]'))
        print(f"Prepared {len(plan['finish'])} finish edits and {len(plan['moves'])} archive moves")
        return
    result, stats = mirror(base, directory, plan)
    if args.write:
        assert (directory/'verified.json').is_file(), 'Verify the actual shared Edit apply before saving'
        receipt = json.loads((directory/'verified.json').read_text())
        assert receipt['place'] == 124078027733625 and receipt['universe'] == 10774898335
        assert receipt['fields'] == 6 and receipt['supportSamples'] > 300 and receipt['finish'] == len(plan['finish'])
        assert receipt['archiveBranches'] == len(plan['moves']) and receipt['displayParts'] == 125
        write_snapshot(base, result)
    print(json.dumps({**stats, 'written': args.write}, indent=2))


if __name__ == '__main__':
    main()
