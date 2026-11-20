#!/usr/bin/env python3
"""Save the reviewed platform cuts, preserving unrelated native data and Sources.

Run with an export directory to produce stage.lua; execute it in shared Studio
Edit, extract shared.PlatformSurfaces.export into fill.b64, dry-run this saver,
apply/verify the Studio stage, then run with --write. Never publishes.
"""
import argparse
from hashlib import sha256
import json
from pathlib import Path
from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import Native, MAP, merge, patch_parts, write_snapshot, close
from restore_reference_look import Values

ROOT=Path(__file__).resolve().parent.parent
PLAN=ROOT/'docs/review/platform-surfaces-plan.json'
SCOPE={'fill':(MAP,{'PlatformSurfaceFill'},{'Folder','Part'})}


def build(base,directory,plan):
    assert sha256(base).hexdigest()==plan['baseline'], 'Canonical baseline changed'
    assert len(plan['edits'])==22 and len(plan['fills'])==14
    original=Native(base)
    def check(e):
        assert e['class']=='Part' and e['path'].startswith(MAP+'.')
        assert e['before'].keys()==e['after'].keys()<= {'position','size'}
        assert all(v>0 for v in e['after'].get('size',[1,1,1]))
    scoped,touched=patch_parts(original,plan['edits'],validate_edit=check)
    result,stats=merge(scoped,directory,addition=SCOPE)
    final=Native(result);values=Values(final)
    assert original.instances.items()<=final.instances.items()
    assert all(final.parents[r]==p for r,p in original.parents.items())
    assert touched=={k for k,v in original.props.items() if final.props[k]!=v}
    assert script_inventory(original.chunks)==script_inventory(final.chunks)
    root=MAP+'.PlatformSurfaceFill'
    assert len([p for p in final.paths if p.startswith(root+'.')])==14
    for f in plan['fills']:
        r=final.one(root+'.'+f['name'])
        assert close(values.get(r,'CFrame'),f['position'])
        assert close(values.get(r,'size'),f['size'])
        old=Values(original)
        candidates=[r for r in original.paths[f['source']] if close(old.get(r,'CFrame'),f['anchor'])]
        assert len(candidates)==1
        for prop in ('MaterialVariantSerialized','Color3uint8'):
            a,b=values.get(r,prop),old.get(candidates[0],prop)
            assert a==b or (prop=='Color3uint8' and close(a,b,1)), (f['source'],prop,a,b)
    return result,{**stats,'parts_updated':len(plan['edits']),'sha256':sha256(result).hexdigest()}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export_dir',type=Path)
    parser.add_argument('--write',action='store_true')
    args=parser.parse_args();args.export_dir.mkdir(parents=True,exist_ok=True)
    plan=json.loads(PLAN.read_text());base=CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest()==plan['baseline'], 'Canonical baseline changed'
    stage=(ROOT/'tools/studio_platform_surfaces.lua').read_text().replace('[==[PLAN_JSON]==]', '[==['+json.dumps(plan)+']==]')
    (args.export_dir/'stage.lua').write_text(stage)
    if not (args.export_dir/'fill.b64').exists():
        assert not args.write, 'Export and verify the Studio stage first'
        print('Prepared stage.lua; export the staged fill.b64 before checking/writing.');return
    result,stats=build(base,args.export_dir,plan)
    if args.write:write_snapshot(base,result)
    print(json.dumps({**stats,'wrote':args.write},indent=2))


if __name__=='__main__':main()
