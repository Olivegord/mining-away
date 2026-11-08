#!/usr/bin/env python3
"""Apply only the exported sunny lighting, ground grain and Quartz tree edits."""
import argparse
from collections import defaultdict
from hashlib import sha256
import json
from pathlib import Path
from build import CANONICAL_OUTPUT, chunk, script_inventory, string, u32
from refresh_native_scenery import Native, patch_parts, pack_vectors, unpack_vectors, close, write_snapshot, split_cframe
from refresh_quarry_courtyard import pack_floats, unpack_floats

PREFIX='Workspace.MiningAway.Map.QuarryCourtyard.'
ALLOWED={'Lighting':{'Brightness','ExposureCompensation','Ambient','OutdoorAmbient','ColorShift_Top','FogStart','FogEnd'},'Lighting.ColorCorrection':{'Contrast','Saturation','Brightness'}}
def validate_tree(e):
    assert e['path'] in {PREFIX+'Quartz.SteppedTree.'+n for n in ['Trunk','Canopy1','Canopy2','Canopy3']}
    assert e['before'].keys()==e['after'].keys()=={'position','size'}

def merge(data, edits, validate_part=validate_tree, allowed_properties=None):
    original=Native(data)
    result,changed=patch_parts(original,edits['parts'],validate_edit=validate_part)
    base=Native(result)
    updates=defaultdict(dict)
    for e in edits['properties']:
        path,name=e['path'],e['property']
        assert name in (allowed_properties or ALLOWED).get(path,set()) or (path.startswith(PREFIX+'GroundLayers.') and path.endswith('.SecondaryGrain') and name in {'Transparency','StudsPerTileU','StudsPerTileV','Color3'})
        assert base.paths[path]
        for ref in base.paths[path]:
            cid,cls,i,_=base.instances[ref]
            if e.get('anchor'):
                pcid,_,pi,_=base.instances[base.parents[ref]]
                _,coords=split_cframe(base.prop(pcid,'CFrame',0x10),len(base.classes[pcid][1]))
                pos=unpack_vectors(coords,len(base.classes[pcid][1]))[pi]
                if not close(pos,e['anchor']): continue
            pair=(e['before'],e['after'])
            assert i not in updates[cid,name] or updates[cid,name][i]==pair
            updates[cid,name][i]=pair
    output=[base.data[:32]]
    written=set()
    for kind,payload,raw in base.chunks:
        if kind==b'PROP':
            cid=u32(payload);name,off=string(payload,4);key=(cid,name)
            if key in updates:
                dtype=payload[off];count=len(base.classes[cid][1])
                assert dtype in (4,12)
                values=unpack_vectors(payload[off+1:],count) if dtype==12 else unpack_floats(payload[off+1:],count)
                for i,(old,new) in updates[key].items():
                    assert close(values[i],old) if dtype==12 else abs(values[i]-old)<.00001,(key,i,values[i],old)
                    values[i]=new
                encoded=pack_vectors(values) if dtype==12 else pack_floats(values)
                raw=chunk(kind,payload[:off+1]+encoded);written.add(key)
        output.append(raw)
    assert written==updates.keys()
    final=Native(b''.join(output))
    assert final.instances==original.instances and final.parents==original.parents
    assert {k for k,v in original.props.items() if final.props[k]!=v}<=changed|written
    assert script_inventory(final.chunks)==script_inventory(original.chunks)
    return final.data,{'tree_parts':len(edits['parts']),'property_edits':len(edits['properties']),'preserved_sources':len(script_inventory(final.chunks))}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('export',type=Path);p.add_argument('--baseline-sha256',required=True);p.add_argument('--write',action='store_true');a=p.parse_args()
    data=CANONICAL_OUTPUT.read_bytes();assert sha256(data).hexdigest()==a.baseline_sha256
    result,report=merge(data,json.loads(a.export.read_text()))
    if a.write: write_snapshot(data,result)
    print(json.dumps(dict(report,wrote=a.write,sha256=sha256(result).hexdigest())))
