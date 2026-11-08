#!/usr/bin/env python3
"""Save the owner-imported stud pack and match existing tree finishes."""
import argparse,json,re
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT,chunks,chunk,packstr,string,u32,script_inventory
from refresh_native_scenery import Native,MAP,read_section,write_snapshot,split_cframe,unpack_vectors,unpack_colors,close
from refresh_quarry_sunshine import merge as patch
from import_lighting import append_model
NEW={'QuarryPack_Leaf','QuarryPack_Trunk'}
def validate(e):
    path=e['path']
    assert path.startswith(MAP+'.QuarryContinuousGround.OriginalDetails.') or path.startswith(MAP+'.QuarryCourtyard.')
    assert e['before'].keys()==e['after'].keys() and e['after'].keys()<={'color','variant'}
    if 'variant' in e['after']:assert e['after']['variant'] in NEW

def merge(data,directory):
    edits=json.loads((directory/'edits.json').read_text());assert not edits['properties']
    result,report=patch(data,edits,validate)
    original=Native(result);model=read_section(directory,'variants');m=Native(model)
    assert len(m.instances)==2 and {v[3] for v in m.instances.values()}==NEW
    assert all(v[1]=='MaterialVariant' for v in m.instances.values())
    result=append_model(result,model,original.one('MaterialService'),chunks,chunk,u32,string,packstr)
    n=Native(result);pack=read_section(directory,'pack');pm=Native(pack)
    assert not n.paths.get('Workspace.Stud pack V1')
    roots=[r for r,parent in pm.parents.items() if parent<0]
    assert len(roots)==1 and pm.instances[roots[0]][3]=='Stud pack V1'
    assert not any(v[1] in {'Script','LocalScript','ModuleScript'} for v in pm.instances.values())
    result=append_model(result,pack,n.one('Workspace'),chunks,chunk,u32,string,packstr)
    report['preserved_pack_instances']=len(pm.instances)
    final=Native(result)
    assert original.instances.items()<=final.instances.items() and original.parents.items()<=final.parents.items()
    assert script_inventory(final.chunks)==script_inventory(original.chunks)
    report['surface_parts']=report.pop('tree_parts')
    return result,report
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
    data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()=='ab0dc1f7730c445b04339b5f396ed45f3be54358c925a73ddcbc713b0cf14182'
    result,report=merge(data,a.directory)
    if a.write:write_snapshot(data,result)
    print(json.dumps(dict(report,wrote=a.write,sha256=sha256(result).hexdigest())))
