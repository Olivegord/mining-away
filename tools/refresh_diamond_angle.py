#!/usr/bin/env python3
"""Replace only Diamond preview, preserving every original property and instance."""
import argparse
import json
import struct
from import_lighting import words, pack_words
from build import chunk, packstr, u32, string
from hashlib import sha256
from pathlib import Path
from build import CANONICAL_OUTPUT, script_inventory
from refresh_native_scenery import Native, MAP, MINERAL_LINEUP_SCOPE, write_parents, write_snapshot
from refresh_quarry_blockscape import append_export

def finish_preview(data):
    native=Native(data)
    replacements={}
    for name in ('FacetShell','MineralClouds'):
        ref=native.one(MAP+'.MineralLineup.Diamond.PreviewGeometry.'+name)
        cid,cls,index,_=native.instances[ref]
        assert cls=='UnionOperation'
        values=replacements.setdefault(cid,list(words(native.prop(cid,'Material',0x12),len(native.classes[cid][1]))))
        assert values[index] in (288,272)
        values[index]=272
    output=[data[:32]]
    for kind,decoded,raw in native.chunks:
        if kind==b'PROP' and u32(decoded) in replacements and string(decoded,4)[0]=='Material':
            cid=u32(decoded)
            raw=chunk(kind,struct.pack('<I',cid)+packstr('Material')+bytes([0x12])+pack_words(replacements[cid]))
        output.append(raw)
    result=b''.join(output)
    final=Native(result)
    assert final.instances==native.instances and final.parents==native.parents
    assert all(final.props[key]==value or key in {(cid,'Material') for cid in replacements} for key,value in native.props.items())
    assert script_inventory(final.chunks)==script_inventory(native.chunks)
    return result

def merge(data, directory):
    original = Native(data)
    old = original.one(MAP + '.MineralLineup.Diamond.PreviewGeometry')
    result = append_export(data, directory, 'archive', 'ServerStorage', 'DiamondAngleArchive', {'Folder'})
    current = Native(result)
    archive = current.one('ServerStorage.DiamondAngleArchive')
    result = write_parents(current, {**current.parents, old: archive})
    result = append_export(result, directory, 'scenery', MAP+'.MineralLineup.Diamond', 'PreviewGeometry', {'Folder','UnionOperation'})
    result = finish_preview(result)
    final = Native(result)
    assert original.instances.items() <= final.instances.items()
    assert original.props.items() <= final.props.items()
    assert all(final.parents[r] == (archive if r == old else parent) for r, parent in original.parents.items())
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    final.one(MAP + '.MineralLineup.Diamond.PreviewGeometry.PrismaticEdges')
    assert len(final.instances)==len(original.instances)+5
    return result, {'preserved_instances': len(original.instances), 'new_instances': len(final.instances)-len(original.instances), 'preserved_sources': len(script_inventory(final.chunks))}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export_dir',type=Path)
    parser.add_argument('--baseline-sha256',required=True)
    parser.add_argument('--write',action='store_true')
    args=parser.parse_args()
    data=CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest()==args.baseline_sha256, 'Canonical changed'
    result,stats=merge(data,args.export_dir)
    if args.write: write_snapshot(data,result)
    print(json.dumps({**stats,'wrote':args.write,'sha256':sha256(result).hexdigest()},indent=2))
if __name__=='__main__': main()
