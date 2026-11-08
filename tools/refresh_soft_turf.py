#!/usr/bin/env python3
"""Restore the earlier turf image and raise only the authored green patch parts."""
import argparse,json
from pathlib import Path
from hashlib import sha256
from build import CANONICAL_OUTPUT,chunk,chunks,packstr,string,u32,script_inventory
from refresh_native_scenery import Native,MAP,patch_parts,read_section,write_snapshot
from import_lighting import append_model
OLD={'QuarryPhoto_Grass','QuarryCourtyard_Turf','QuarryCourtyard_Garden','QuarryAccent_LushGrass'}
NEW={'QuarryRestoredTurf_'+n for n in ('Grass','Concrete','LeafyGrass')}
def validate(e):
    assert e['path'].startswith(MAP+'.') and e['before']['variant'] in OLD and e['after']['variant'] in NEW
    assert e['before'].keys()==e['after'].keys()
    if 'size' in e['after']:
        assert e['path'].startswith(MAP+'.QuarryMeadowLayers.') and .21<e['after']['size'][1]<.43
    else:assert e['after'].keys()=={'variant'}
def merge(data,directory):
    original=Native(data);e=json.loads((directory/'edits.json').read_text())
    result,changed=patch_parts(original,e['parts'],validate_edit=validate)
    n=Native(result);updates={}
    for f in e['flags']:
        assert f['path'].startswith(MAP+'.QuarryMeadowLayers.') and f['property'] in {'CanCollide','CanQuery','CastShadow'} and f['after'] is True
        cid,_,i,_=n.instances[n.one(f['path'])]
        key=(cid,f['property']);values=updates.setdefault(key,bytearray(n.prop(cid,f['property'],2)))
        assert bool(values[i])==f['before'];values[i]=1
    output=[result[:32]]
    for kind,payload,raw in n.chunks:
        if kind==b'PROP':
            name,off=string(payload,4);key=(u32(payload),name)
            if key in updates:raw=chunk(kind,payload[:off+1]+bytes(updates[key]))
        output.append(raw)
    result=b''.join(output);n=Native(result)
    model=read_section(directory,'variants');m=Native(model)
    assert {entry[3] for entry in m.instances.values()}==NEW and len(m.instances)==3
    result=append_model(result,model,n.one('MaterialService'),chunks,chunk,u32,string,packstr)
    final=Native(result)
    assert original.instances.items()<=final.instances.items() and original.parents.items()<=final.parents.items()
    assert {k for k,v in original.props.items() if final.props[k]!=v}<=changed|updates.keys()
    assert script_inventory(original.chunks)==script_inventory(final.chunks)
    return result,{'grass_parts':len(e['parts']),'raised_patches':len(e['flags'])//3,'preserved_sources':len(script_inventory(final.chunks))}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--write',action='store_true');a=p.parse_args()
    data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()=='54e71186a271d723f900a0f0fffcd73a3b8af142dbea1f795d82fc087a9606ed'
    result,report=merge(data,a.directory)
    if a.write:write_snapshot(data,result)
    print(json.dumps(dict(report,sha256=sha256(result).hexdigest(),wrote=a.write)))
