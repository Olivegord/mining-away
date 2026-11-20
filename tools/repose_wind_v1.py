#!/usr/bin/env python3
"""Mirror only the changed drawing properties on the existing Version 1 rig."""
import argparse
from hashlib import sha256
from pathlib import Path
import struct

from build import CANONICAL_OUTPUT, chunk, chunks, packstr, string, u32
from refresh_native_scenery import Native, read_section, write_snapshot
from refresh_wind_v1 import ROOT, check

POSE = {
    "Beam": {"Brightness", "Color", "CurveSize0", "CurveSize1", "Enabled", "FaceCamera",
             "LightEmission", "LightInfluence", "Transparency", "Width0", "Width1"},
    "Attachment": {"CFrame"},
    "Part": {"CFrame", "Transparency"},
}


def reorder(data, kind, order):
    """Reorder one serialized property from scoped Studio order to existing place order."""
    n = len(order)
    if kind == 2:  # booleans
        assert len(data) == n
        return bytes(data[i] for i in order)
    if kind == 4:  # interleaved float words
        assert len(data) == 4 * n
        return b"".join(bytes(data[k*n+i] for i in order) for k in range(4))
    if kind == 16:  # rotation tags/matrices, then three float columns
        pos = 0
        rows = []
        for _ in range(n):
            end = pos + (1 if data[pos] else 37)
            rows.append(data[pos:end])
            pos = end
        assert len(data)-pos == 12*n
        return b"".join(rows[i] for i in order) + b"".join(
            reorder(data[pos+k*4*n:pos+(k+1)*4*n], 4, order) for k in range(3))
    assert kind in (21, 22)  # number / color sequences
    stride = 12 if kind == 21 else 20
    pos = 0
    rows = []
    for _ in range(n):
        end = pos + 4 + stride*u32(data,pos)
        rows.append(data[pos:end])
        pos = end
    assert pos == len(data)
    return b"".join(rows[i] for i in order)


def pose_properties(scope, target):
    values = {}
    for cid, (cls, ids) in scope.classes.items():
        if cls not in POSE:
            continue
        references = [target.one("Workspace."+scope.path(ref)) for ref in ids]
        target_cid = target.instances[references[0]][0]
        assert all(target.instances[r][:2] == (target_cid, cls) for r in references)
        existing = target.classes[target_cid][1]
        assert set(existing) == set(references), "Property group mixes Version 1 with other instances"
        index = {ref: i for i, ref in enumerate(references)}
        order = [index[r] for r in existing]
        for name in POSE[cls]:
            kind, blob = scope.props[cid, name]
            assert target.props[target_cid, name][0] == kind
            values[target_cid, name] = (kind, reorder(blob, kind, order))
    return values


def mirror(base, before_bytes, after_bytes):
    target, before, after = Native(base), Native(before_bytes), Native(after_bytes)
    def tree(n):
        return {n.path(r): entry[1] for r, entry in n.instances.items()}
    expected = {k.removeprefix("Workspace."): target.instances[target.one(k)][1]
                for k in target.paths if k == ROOT or k.startswith(ROOT+".")}
    assert tree(before) == tree(after) == expected
    old, new = pose_properties(before,target), pose_properties(after,target)
    changed = {k: v for k,v in new.items() if v != old[k]}
    assert changed
    out = [base[:32]]
    for tag, d, raw in chunks(base):
        if tag == b"PROP":
            name,_ = string(d,4)
            key = (u32(d),name)
            if key in changed:
                assert target.props[key] == old[key], f"Canonical pose differs from shared Edit at {key}"
                kind,blob=changed[key]
                raw=chunk(tag,struct.pack("<I",key[0])+packstr(name)+bytes([kind])+blob)
        out.append(raw)
    result=b"".join(out)
    final=Native(result)
    assert final.instances==target.instances and final.parents==target.parents
    assert final.props == {**target.props,**changed}
    check(result)
    return result, len(changed)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory",type=Path)
    parser.add_argument("--baseline-sha256",required=True)
    parser.add_argument("--write",action="store_true")
    args=parser.parse_args()
    base=CANONICAL_OUTPUT.read_bytes()
    assert sha256(base).hexdigest()==args.baseline_sha256
    after=read_section(args.directory,"after")
    result,count=mirror(base,read_section(args.directory,"before"),after)
    if args.write:
        # Studio re-serialized the actual live model after the pose was applied.
        verified, _=mirror(base,read_section(args.directory,"before"),read_section(args.directory,"verified"))
        assert verified==result
        write_snapshot(base,result)
    print(f"Verified {count} scoped property columns. Canonical SHA-256 {sha256(result).hexdigest()}")


if __name__=="__main__":
    main()
