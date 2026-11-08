#!/usr/bin/env python3
"""Merge an exact scoped Studio scenery export into the sole canonical place.

This workflow never opens Studio, uploads a place, or reserializes unrelated
instances. The export directory contains the four compressed base64 sections
produced by the companion Studio edit command.
"""
import argparse
import base64
from collections import defaultdict
from hashlib import sha256
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import tempfile

from build import CANONICAL_OUTPUT, chunks, chunk, packstr, script_inventory, string, string_values, u32
from import_lighting import append_model, pack_refs, pack_words, refs, words

MAP = "Workspace.MiningAway.Map"
TERRACES = MAP + ".DronerevolutionTerraces."
ARCHIVE = "ServerStorage.QuarryDormantVegetation"
SCOPE = {
    "scenery": (MAP, {"QuarryDepthPass"}, {"Folder", "Part", "WedgePart"}),
    "variants": ("MaterialService", {
        "QuarryAccent_Brick", "QuarryAccent_Checker", "QuarryAccent_Ribbed",
        "QuarryAccent_Timber", "QuarryBlend_RubyLoam",
    }, {"MaterialVariant"}),
    "archive": ("ServerStorage", {"QuarryDormantVegetation"}, {"Folder"}),
}


class Native:
    def __init__(self, data):
        self.data = data
        self.chunks = list(chunks(data))
        self.classes, self.props, self.parents = {}, {}, {}
        for kind, d, _ in self.chunks:
            if kind == b"INST":
                cls, end = string(d, 4)
                count = u32(d, end+1)
                self.classes[u32(d)] = (cls, refs(d[end+5:end+5+4*count], count))
            elif kind == b"PROP":
                name, end = string(d, 4)
                self.props[u32(d), name] = (d[end], d[end+1:])
            elif kind == b"PRNT":
                count = u32(d, 1)
                self.parents = dict(zip(refs(d[5:5+4*count], count), refs(d[5+4*count:], count)))
        self.instances = {}
        for cid, (cls, ids) in self.classes.items():
            names = string_values(self.prop(cid, "Name", 1), 0, len(ids))
            self.instances.update((ref, (cid, cls, i, name.decode())) for i, (ref, name) in enumerate(zip(ids, names)))
        assert self.instances.keys() == self.parents.keys(), "Native parent table is incomplete"
        self.paths = defaultdict(list)
        for ref in self.instances:
            self.paths[self.path(ref)].append(ref)

    def path(self, ref):
        names = []
        while ref >= 0:
            assert len(names) < 100, "Cyclic or unexpectedly deep native hierarchy"
            names.append(self.instances[ref][3])
            ref = self.parents[ref]
        return ".".join(reversed(names))

    def one(self, path):
        matches = self.paths.get(path, [])
        assert len(matches) == 1, f"Expected one {path}, found {len(matches)}"
        return matches[0]

    def prop(self, cid, name, expected):
        dtype, data = self.props[cid, name]
        assert dtype == expected, (cid, name, hex(dtype))
        return data


def split_cframe(data, count):
    end = len(data)-count*12
    cursor = 0
    for _ in range(count):
        cursor += 1 if data[cursor] else 37
    assert cursor == end, "Unexpected native CFrame encoding"
    return data[:end], data[end:]


def unpack_vectors(data, count):
    assert len(data) == count*12
    axes = []
    for i in range(3):
        axis = []
        for value in words(data[i*4*count:(i+1)*4*count], count):
            bits = ((value >> 1) | (value << 31)) & 0xffffffff
            axis.append(struct.unpack(">f", struct.pack(">I", bits))[0])
        axes.append(axis)
    return list(zip(*axes))


def pack_vectors(values):
    def rotate(f):
        bits = struct.unpack(">I", struct.pack(">f", f))[0]
        return ((bits << 1) | (bits >> 31)) & 0xffffffff
    return b"".join(pack_words([rotate(f) for f in axis]) for axis in zip(*values))


def unpack_colors(data, count):
    assert len(data) == count*3
    return list(zip(data[:count], data[count:2*count], data[2*count:]))


def close(first, second):
    return len(first) == len(second) and all(math.isclose(a, b, rel_tol=0, abs_tol=.0015) for a, b in zip(first, second))


def patch_parts(base, edits):
    batches = {}
    seen = set()
    equivalent = []
    mapping = {"position": ("CFrame", 0x10), "size": ("size", 0x0e),
               "color": ("Color3uint8", 0x1a), "variant": ("MaterialVariantSerialized", 1)}
    for edit in edits:
        path = edit["path"]
        assert path.startswith(TERRACES), f"Native edit outside authored terraces: {path}"
        assert edit["before"].keys() == edit["after"].keys() <= mapping.keys()
        candidates = []
        for ref in base.paths.get(path, []):
            cid, cls, index, _ = base.instances[ref]
            if cls != edit.get("class", "Part") or cls not in {"Part", "WedgePart"}:
                continue
            if cid not in batches:
                n = len(base.classes[cid][1])
                prefix, coords = split_cframe(base.prop(cid, "CFrame", 0x10), n)
                batches[cid] = {
                    "prefix": prefix, "old": {
                        "position": unpack_vectors(coords, n),
                        "size": unpack_vectors(base.prop(cid, "size", 0x0e), n),
                        "color": unpack_colors(base.prop(cid, "Color3uint8", 0x1a), n),
                        "variant": [v.decode() for v in string_values(base.prop(cid, "MaterialVariantSerialized", 1), 0, n)],
                    }, "edits": {},
                }
            before = batches[cid]["old"]
            if not close(before["position"][index], edit["anchor"]):
                continue
            for key, expected in edit["before"].items():
                value = before[key][index]
                matched = close(value, expected) if key in ("position", "size") else value == (tuple(expected) if key=="color" else expected)
                if not matched:
                    break
            else:
                candidates.append((cid, index))
        remaining = [entry for entry in candidates if entry not in seen]
        assert remaining, f"Could not reconcile {path} at {edit['anchor']} against its old properties"
        if len(candidates) > 1:
            # Some authored trees have identical overlapping parts. Every match
            # must be in the export and receive the same change.
            equivalent.append((candidates, edit["after"]))
        cid, index = remaining[0]
        seen.add((cid, index))
        for key in edit["before"]:
            batches[cid]["edits"].setdefault(key, {})[index] = edit["after"][key]

    for candidates, after in equivalent:
        for cid, index in candidates:
            assert (cid, index) in seen and all(
                batches[cid]["edits"].get(key, {}).get(index) == value for key, value in after.items()
            ), "Ambiguous native edit: overlapping parts have different changes"

    replacements = {}
    for cid, batch in batches.items():
        for key, edits in batch["edits"].items():
            values = batch["old"][key].copy()
            for i, value in edits.items():
                values[i] = value
            if key in ("position", "size"):
                assert all(math.isfinite(value) for row in values for value in row)
                raw = pack_vectors(values)
                if key == "position":
                    raw = batch["prefix"]+raw
            elif key == "color":
                raw = b"".join(bytes(axis) for axis in zip(*values))
            else:
                raw = b"".join(packstr(v) for v in values)
            prop, dtype = mapping[key]
            replacements[cid, prop] = chunk(b"PROP", struct.pack("<I", cid)+packstr(prop)+bytes([dtype])+raw)
    result = [base.data[:32]]
    for kind, decoded, raw in base.chunks:
        if kind == b"PROP":
            raw = replacements.get((u32(decoded), string(decoded, 4)[0]), raw)
        result.append(raw)
    return b"".join(result), set(replacements)


def reparent(data, moves):
    native = Native(data)
    parents = native.parents.copy()
    for move in moves:
        assert move["path"].startswith(TERRACES+"AssetScenery.CobaltScenery.")
        assert move["parent"] == ARCHIVE
        child, parent = native.one(move["path"]), native.one(move["parent"])
        assert native.instances[child][1] == "Model" and native.instances[parent][1] == "Folder"
        parents[child] = parent
    result = [data[:32]]
    for kind, _, raw in native.chunks:
        if kind == b"PRNT":
            raw = chunk(b"PRNT", b"\0"+struct.pack("<I", len(parents))+pack_refs(parents)+pack_refs(parents.values()))
        result.append(raw)
    return b"".join(result)


def read_section(directory, name):
    compressed = base64.b64decode((directory/(name+".b64")).read_bytes().strip(), validate=True)
    return subprocess.run(["zstd", "-d", "-q", "-c"], input=compressed, capture_output=True, check=True).stdout


def merge(base, directory):
    plan = json.loads(read_section(directory, "edits"))
    assert plan.keys() == {"edits", "moves"} and plan["edits"] and plan["moves"]
    original = Native(base)
    result, touched = patch_parts(original, plan["edits"])
    for name, (parent, roots, allowed) in SCOPE.items():
        model = read_section(directory, name)
        assert model.startswith(b"<roblox!\x89\xff\r\n\x1a\n"), "Expected Studio's native binary model export"
        scoped = Native(model)
        root_refs = [ref for ref, p in scoped.parents.items() if p == -1]
        assert len(root_refs) == len(roots) and {scoped.instances[ref][3] for ref in root_refs} == roots
        assert all(cls in allowed for cls, _ in scoped.classes.values()), f"Unexpected {name} model content"
        current = Native(result)
        assert all(parent+"."+root not in current.paths for root in roots), f"{name} already exists"
        result = append_model(result, model, current.one(parent), chunks, chunk, u32, string, packstr)
    result = reparent(result, plan["moves"])
    final = Native(result)
    # No original instance was reserialized, and no other property changed.
    assert original.instances.items() <= final.instances.items()
    assert set(touched) == {key for key, old in original.props.items() if final.props[key] != old}
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    moved = {original.one(move["path"]): final.one(move["parent"]) for move in plan["moves"]}
    assert all(final.parents[ref] == moved.get(ref, parent) for ref, parent in original.parents.items())
    return result, {
        "parts_updated": len(plan["edits"]), "archived_models": len(plan["moves"]),
        "new_instances": len(final.instances)-len(original.instances),
        "preserved_sources": len(script_inventory(final.chunks)),
    }


def write_snapshot(expected, result):
    assert CANONICAL_OUTPUT.read_bytes() == expected, "Concurrent canonical edit"
    mode = CANONICAL_OUTPUT.stat().st_mode & 0o777
    fd, pending = tempfile.mkstemp(prefix=".DRONE_GAME.", suffix=".pending", dir=CANONICAL_OUTPUT.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(result)
        os.chmod(pending, mode)
        os.replace(pending, CANONICAL_OUTPUT)
    finally:
        Path(pending).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true", help="Atomically update the canonical file after checks")
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, "Canonical file changed; reconcile before saving"
    result, stats = merge(data, args.export_dir)
    if args.write:
        write_snapshot(data, result)
    print(json.dumps({**stats, "wrote": args.write, "sha256": sha256(result).hexdigest()}, indent=2))


if __name__ == "__main__":
    main()
