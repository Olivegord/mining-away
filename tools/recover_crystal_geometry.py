#!/usr/bin/env python3
"""Recover the original crystal's saved convex surface; no Studio/native writes.

Optional reproduction dependencies: manifold3d==3.5.4 and numpy==2.0.2.
The game ships only the generated Luau coordinates, not these dependencies.
CSGPHS6 layout reference: krakow10/rbx_mesh/src/union_physics/v3.rs and v6.rs.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import struct

from build import ROOT, EXPECTED, chunks
from inspect_original import u32


def extract():
    data = (ROOT / 'assets/mining-away-base.rbxl').read_bytes()
    assert hashlib.sha256(data).hexdigest() == EXPECTED, 'Unexpected original capture'
    strings = []
    for kind, payload, _ in chunks(data):
        if kind != b'SSTR':
            continue
        assert u32(payload) == 0
        offset = 8
        for _ in range(u32(payload, 4)):
            length = u32(payload, offset + 16)
            offset += 20
            strings.append(payload[offset:offset + length])
            offset += length
        assert offset == len(payload)
    # Both original crystal instances reference shared string 8 for their
    # PhysicalConfigData; their cloud-only render mesh payload is empty.
    blob = strings[8]
    assert blob.startswith(b'CSGPHS\x06\0\0\0')
    offset = 50  # ten-byte signature followed by ten physics-property floats.
    hulls = []
    while offset < len(blob):
        transform = blob[offset:offset + 40]
        offset += 40
        identity = struct.pack('<I4fI4f', 16, 0, 0, 0, 0, 16, 0, 0, 0, 1)
        assert transform == identity, 'Unexpected hull-local transform'
        count, width = struct.unpack_from('<2I', blob, offset)
        offset += 8
        assert count % 3 == 0 and width == 4 and count < 10000
        vertices = [struct.unpack_from('<3f', blob, offset + i * 12) for i in range(count // 3)]
        offset += count * 4
        count = u32(blob, offset)
        offset += 4
        assert count % 3 == 0 and count < 30000
        faces = [struct.unpack_from('<3I', blob, offset + i * 12) for i in range(count // 3)]
        offset += count * 4
        hulls.append((vertices, faces))
    assert offset == len(blob) and len(hulls) == 36
    return hulls, hashlib.sha256(blob).hexdigest()


def surface():
    import itertools
    import manifold3d
    import numpy as np
    hulls, digest = extract()
    # Close numerical decomposition seams without changing the authored design.
    dilation, weld, simplify, inset = .001, .003, .001, .001
    corners = np.array(list(itertools.product((-dilation, dilation), repeat=3)))
    solids = [manifold3d.Manifold.hull_points(
        (np.array(hull[0])[:, None, :] + corners).reshape(-1, 3)) for hull in hulls]
    merged = manifold3d.Manifold.batch_boolean(solids, manifold3d.OpType.Add)
    assert merged.status() == manifold3d.Error.NoError
    # Discard only enclosed negative-volume voids. The external crystal remains
    # the original cluster; this is not a convex hull of the complete rock.
    exterior = max(merged.decompose(), key=lambda item: item.volume()).simplify(.00075)
    mesh = exterior.to_mesh()
    vertices = np.asarray(mesh.vert_properties)[:, :3]
    faces = np.asarray(mesh.tri_verts)
    distances = np.linalg.norm(vertices[:, None, :] - vertices[None, :, :], axis=2)
    parents = list(range(len(vertices)))

    def root(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    for a, b in zip(*np.where(np.triu(distances < weld, 1))):
        parents[root(int(b))] = root(int(a))
    remapped = []
    for face in faces:
        triangle = [root(int(index)) for index in face]
        if len(set(triangle)) == 3:
            remapped.append(triangle)
    lookup, compact_vertices, compact_faces = {}, [], []
    for triangle in remapped:
        result = []
        for index in triangle:
            if index not in lookup:
                lookup[index] = len(compact_vertices)
                compact_vertices.append(vertices[index])
            result.append(lookup[index])
        compact_faces.append(result)
    vertices = np.array(compact_vertices, dtype=np.float32)
    faces = np.array(compact_faces, dtype=np.uint32)
    # Reimport after welding: Manifold resolves vertex fans before simplifying
    # slivers, unlike a naive global weld which can leave pinched topology.
    exterior = manifold3d.Manifold(manifold3d.Mesh(vertices, faces))
    assert exterior.status() == manifold3d.Error.NoError
    mesh = exterior.simplify(simplify).to_mesh()
    vertices = np.asarray(mesh.vert_properties)[:, :3]
    faces = np.asarray(mesh.tri_verts)
    low, high = vertices.min(axis=0).astype(float), vertices.max(axis=0).astype(float)
    normalized = (vertices.astype(float) - (high + low) / 2) / (high - low)
    # The original decomposition has one zero-width tip-to-tip contact. Roblox
    # welds that position and rejects it as nonmanifold even with valid index
    # topology. Inset the two separate fans a tiny distance, not a fake bevel.
    coincident = collections.defaultdict(list)
    for index, vertex in enumerate(normalized):
        coincident[tuple(vertex)].append(index)
    for indices in coincident.values():
        if len(indices) == 1:
            continue
        for index in indices:
            incident = faces[np.any(faces == index, axis=1)]
            normal = np.sum(np.cross(normalized[incident[:, 1]] - normalized[incident[:, 0]],
                                     normalized[incident[:, 2]] - normalized[incident[:, 0]]), axis=0)
            normal /= np.linalg.norm(normal)
            normalized[index] -= normal * inset
    low, high = normalized.min(axis=0), normalized.max(axis=0)
    normalized = (normalized - (low + high) / 2) / (high - low)
    original = np.array([vertex for hull in hulls for vertex in hull[0]], dtype=float)
    size = original.max(axis=0) - original.min(axis=0)
    runtime = (normalized * 4).astype(np.float32)
    areas = np.linalg.norm(np.cross(runtime[faces[:, 1]] - runtime[faces[:, 0]],
                                   runtime[faces[:, 2]] - runtime[faces[:, 0]]), axis=1)
    distances = np.linalg.norm(runtime[:, None, :] - runtime[None, :, :], axis=2)
    distances += np.eye(len(runtime)) * 100
    assert areas.min() > .00003, 'Triangle too thin for native CSG'
    assert distances.min() > .002, 'Vertices too close for native CSG welding'
    edges = collections.Counter(tuple(sorted((int(face[i]), int(face[(i + 1) % 3]))))
                                for face in faces for i in range(3))
    assert set(edges.values()) == {2}, 'Open or nonmanifold result'
    # Check each vertex's incident faces form ONE fan, not two pinched shells.
    for index in range(len(vertices)):
        incident = [tuple(map(int, face)) for face in faces if index in face]
        adjacency = collections.defaultdict(set)
        for face in incident:
            a, b = [value for value in face if value != index]
            adjacency[a].add(b)
            adjacency[b].add(a)
        assert all(len(neighbors) == 2 for neighbors in adjacency.values())
        pending, seen = [next(iter(adjacency))], set()
        while pending:
            value = pending.pop()
            if value not in seen:
                seen.add(value)
                pending.extend(adjacency[value])
        assert len(seen) == len(adjacency), 'Pinched vertex fan'
    return {
        'vertices': normalized.tolist(), 'triangles': (faces + 1).tolist(),
        'originalSize': size.tolist(), 'sourceSha256': digest,
        'sourceHullCount': len(hulls), 'sourceVertexCount': sum(len(h[0]) for h in hulls),
        'sourceTriangleCount': sum(len(h[1]) for h in hulls), 'closedComponents': 1,
        'hullDilation': dilation, 'weldDistance': weld,
        'simplifyTolerance': simplify, 'pointContactInset': inset,
    }


def lua(data):
    lines = [
        '-- Recovered original crystal collision surface; do not replace with a primitive.',
        '-- Generated by tools/recover_crystal_geometry.py using manifold3d 3.5.4.',
        '-- Source: immutable assets/mining-away-base.rbxl / crystal PhysicalConfigData / SSTR 8.',
        '-- Original rendered mesh is cloud-only; this is its authored convex collision approximation.',
        '-- 36 closed hulls (471 vertices / 798 triangles) were boolean-unioned OFFLINE.',
        '-- Centered coordinates span [-.5,.5] on each axis; triangle indices are one-based.',
        '-- Hull dilation .001 stud; weld .003; simplify .001; point-contact inset .001 normalized.',
        '-- Exact original bounds restored. No coincident points or pinched vertex fans.',
        'local G={',
    ]
    for key in ('originalSize', 'sourceSha256', 'sourceHullCount', 'sourceVertexCount', 'sourceTriangleCount', 'closedComponents', 'hullDilation', 'weldDistance', 'simplifyTolerance', 'pointContactInset'):
        value = data[key]
        if isinstance(value, list):
            encoded = '{' + ','.join(format(v, '.17g') for v in value) + '}'
        else:
            encoded = json.dumps(value)
        lines.append(f' {key}={encoded},')
    for key in ('vertices', 'triangles'):
        lines.append(' ' + key + '={')
        for row in data[key]:
            lines.append('  {' + ','.join(format(v, '.17g') if isinstance(v, float) else str(v) for v in row) + '},')
        lines.append(' },')
    lines.extend(['}', 'return G', ''])
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path)
    args = parser.parse_args()
    data = surface()
    if args.output:
        args.output.write_text(lua(data))
    print(json.dumps({k: v for k, v in data.items() if k not in ('vertices', 'triangles')} | {
        'vertices': len(data['vertices']), 'triangles': len(data['triangles']), 'allEdgeIncidences': 2,
    }, indent=2))
