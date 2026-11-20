#!/usr/bin/env python3
"""Save the scoped quarry palette without changing gameplay or physical geometry."""
import argparse,json,re
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT,chunks,chunk,packstr,string,u32,script_inventory
from refresh_native_scenery import Native,MAP,read_section,write_snapshot,split_cframe,unpack_vectors,unpack_colors,close
from refresh_quarry_sunshine import merge as patch
from import_lighting import append_model
NEW={'QuarryColorStone_Slate','QuarryColorStone_Sandstone'}
def validate(e):
    path=e['path']
    assert path.startswith(MAP+'.') or re.fullmatch(r'Workspace.MiningAway.Fields.(Quartz|ImpactTest|Ruby|Cobalt|Violet|Emerald).Field',path)
    assert e['before'].keys()==e['after'].keys() and e['after'].keys()<={'color','variant'}
    if 'variant' in e['after']:assert e['after']['variant'] in NEW

def merge(data,directory):
    edits=json.loads((directory/'edits.json').read_text());assert not edits['properties']
    # Studio round-trip quantizes a few historical uint8 tints by one level.
    native=Native(data); reconciled=0; positions={}; colors={}
    for e in edits['parts']:
        for r in native.paths[e['path']]:
            cid,_,i,_=native.instances[r];count=len(native.classes[cid][1])
            if cid not in positions:
                _,coords=split_cframe(native.prop(cid,'CFrame',16),count)
                positions[cid]=unpack_vectors(coords,count)
                colors[cid]=unpack_colors(native.prop(cid,'Color3uint8',26),count)
            if not close(positions[cid][i],e['anchor']):continue
            color=list(colors[cid][i])
            if color!=e['before']['color']:
                assert max(abs(a-b) for a,b in zip(color,e['before']['color']))<=1,(e['path'],color,e['before'])
                e['before']['color']=color;reconciled+=1
            break
    result,report=patch(data,edits,validate)
    report['one_byte_color_reconciliations']=reconciled
    original=Native(result);model=read_section(directory,'variants');m=Native(model)
    assert len(m.instances)==2 and {v[3] for v in m.instances.values()}==NEW
    assert all(v[1]=='MaterialVariant' for v in m.instances.values())
    result=append_model(result,model,original.one('MaterialService'),chunks,chunk,u32,string,packstr)
    final=Native(result)
    assert original.instances.items()<=final.instances.items() and original.parents.items()<=final.parents.items()
    assert script_inventory(final.chunks)==script_inventory(original.chunks)
    report['surface_parts']=report.pop('tree_parts')
    return result,report
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
    data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()=='8265ce0259140c59a78bcecf2e199b492d9cd59edd862a8b03fb76fe474baffe'
    result,report=merge(data,a.directory)
    if a.write:write_snapshot(data,result)
    print(json.dumps(dict(report,wrote=a.write,sha256=sha256(result).hexdigest())))
