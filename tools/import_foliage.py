"""Prepare the pinned SkinnedGrass RBXM without executing any imported scripts."""
import struct


def prepare(model, source):
    # Delayed import avoids the builder/importer cycle.
    from build import chunks, chunk, u32, string, packstr
    cs = list(chunks(model)); classes = {}; names = {}
    for kind, d, _ in cs:
        if kind == b'INST':
            cid = u32(d); name, p = string(d, 4)
            classes[cid] = (name, u32(d, p+1))
        elif kind == b'PROP':
            cid = u32(d); prop, p = string(d, 4)
            if prop == 'Name':
                values = []; p += 1
                while p < len(d):
                    value, p = string(d, p); values.append(value)
                names[cid] = values
    output = [model[:32]]; disabled = set()
    for kind, d, raw in cs:
        if kind == b'PROP':
            cid = u32(d); prop, p = string(d, 4)
            cls, n = classes[cid]
            if cls == 'ModuleScript' and prop == 'Source':
                values = [(source / (name+'.lua')).read_text() for name in names[cid]]
                output.append(chunk(kind, d[:p+1]+b''.join(packstr(v) for v in values)))
                continue
            if cls in ('Script', 'LocalScript') and prop == 'Disabled':
                output.append(chunk(kind, d[:p+1]+b'\1'*n)); disabled.add(cid)
                continue
        if kind == b'PRNT':
            for cid, (cls, n) in classes.items():
                if cls in ('Script', 'LocalScript') and cid not in disabled:
                    output.append(chunk(b'PROP', struct.pack('<I', cid)+packstr('Disabled')+b'\2'+b'\1'*n))
        output.append(raw)
    return b''.join(output)
