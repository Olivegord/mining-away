"""Rebase an engine-exported RBXM without touching existing instance data.
Only header totals, shared-string table totals, and the combined parent table change.
All original referents and all existing shared-string bytes remain intact.
"""
import struct


def words(data, n):
    return [int.from_bytes(bytes(data[j*n+i] for j in range(4)), 'big') for i in range(n)]


def pack_words(values):
    raw = [struct.pack('>I', v & 0xffffffff) for v in values]
    return b''.join(bytes(v[j] for v in raw) for j in range(4))


def refs(data, n):
    total = 0
    out = []
    for v in words(data, n):
        total += (v >> 1) ^ -(v & 1)
        out.append(total)
    return out


def pack_refs(values):
    last = 0
    encoded = []
    for v in values:
        delta = v-last
        encoded.append((delta << 1) ^ (delta >> 31))
        last = v
    return pack_words(encoded)


def append_model(base, model, parent_ref, chunks, chunk, u32, string, packstr):
    old, new = list(chunks(base)), list(chunks(model))
    def inventory(cs):
        classes, identities, parents = {}, [], ([], [])
        shared = None
        for kind, d, _ in cs:
            if kind == b'INST':
                cid = u32(d); name, p = string(d, 4); n = u32(d, p+1)
                ids = refs(d[p+5:p+5+n*4], n)
                classes[cid] = (name, n); identities += ids
            elif kind == b'PRNT':
                n = u32(d, 1); parents = (refs(d[5:5+n*4], n), refs(d[5+n*4:], n))
            elif kind == b'SSTR':
                shared = d
        return classes, identities, parents, shared
    oc, oi, op, os = inventory(old)
    nc, ni, np, ns = inventory(new)
    cid_offset, ref_offset = max(oc)+1, max(oi)+1
    shared_offset = u32(os, 4) if os else 0
    imported = []
    for kind, d, _ in new:
        if kind == b'INST':
            cid = u32(d); _, p = string(d, 4); n = u32(d, p+1)
            assert d[p] == 0, 'Unexpected service in imported model'
            ids = refs(d[p+5:p+5+n*4], n)
            imported.append(chunk(kind, struct.pack('<I', cid+cid_offset)+d[4:p+5]+pack_refs([x+ref_offset for x in ids])+d[p+5+n*4:]))
        elif kind == b'PROP':
            cid = u32(d); _, p = string(d, 4); typ = d[p]; n = nc[cid][1]
            value = d[p+1:]
            if typ == 0x13:
                value = pack_refs([x+ref_offset if x >= 0 else x for x in refs(value, n)])
            elif typ == 0x1c:
                value = pack_words([x+shared_offset for x in words(value, n)])
            imported.append(chunk(kind, struct.pack('<I', cid+cid_offset)+d[4:p+1]+value))
    header = bytearray(base[:32])
    struct.pack_into('<II', header, 16, u32(base, 16)+len(nc), u32(base, 20)+len(ni))
    output = [bytes(header)]
    for kind, d, raw in old:
        if kind == b'SSTR' and ns:
            assert u32(d) == u32(ns) == 0
            output.append(chunk(kind, d[:4]+struct.pack('<I', u32(d, 4)+u32(ns, 4))+d[8:]+ns[8:]))
        elif kind == b'PRNT':
            if ns and not os:
                output.append(chunk(b'SSTR', ns))
            output += imported
            ids = op[0]+[x+ref_offset for x in np[0]]
            parents = op[1]+[x+ref_offset if x >= 0 else parent_ref for x in np[1]]
            output.append(chunk(kind, b'\0'+struct.pack('<I', len(ids))+pack_refs(ids)+pack_refs(parents)))
        else:
            output.append(raw)
    return b''.join(output)
