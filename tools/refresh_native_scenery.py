#!/usr/bin/env python3
"""Merge an exact scoped Studio scenery export into the sole canonical place.

This workflow never opens Studio, uploads a place, or reserializes unrelated
instances. The export directory contains compressed base64 sections produced
by the corresponding Studio edit command.
"""
import argparse
import base64
from collections import Counter, defaultdict
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
QUARTZ = "Workspace.MiningAway.Fields.Quartz.Field"
SCOPE = {
    "scenery": (MAP, {"QuarryDepthPass"}, {"Folder", "Part", "WedgePart"}),
    "variants": ("MaterialService", {
        "QuarryAccent_Brick", "QuarryAccent_Checker", "QuarryAccent_Ribbed",
        "QuarryAccent_Timber", "QuarryBlend_RubyLoam",
    }, {"MaterialVariant"}),
    "archive": ("ServerStorage", {"QuarryDormantVegetation"}, {"Folder"}),
}
CONTRAST_SCOPE = {
    "variants": ("MaterialService", {
        "QuarryOre_Veined", "QuarryAccent_LushGrass", "QuarryAccent_RoughBed",
        "QuarryDrone_Painted", "QuarryDrone_Ribbed",
    }, {"MaterialVariant"}),
}
BASIN_SCOPE = {
    "scenery": (MAP, {"QuarryBasin"}, {"Folder", "WedgePart"}),
}
WOODLAND_SCOPE = {
    "scenery": (MAP, {"QuarryWoodlands"}, {"Folder", "Model", "Part", "WedgePart"}),
}
BIOME_REACH_SCOPE = {
    "scenery": (MAP, {"QuarryBiomeReaches"}, {"Folder", "Model", "Part"}),
}
ARRIVAL_SCOPE = {
    "scenery": (MAP, {"QuarryArrivalAccents"}, {"Folder", "Part", "WedgePart"}),
}
MOTIF_SCOPE = {
    "scenery": (MAP, {"QuarryMotifScenery"}, {"Folder", "Part"}),
    "variants": ("MaterialService", {
        f"QuarryMotif_{name}" for name in
        ("Stars", "Daisies", "BlueGingham", "RedGingham", "Pips", "Waves", "Knit", "Studs")
    }, {"MaterialVariant"}),
}
PALETTE_VARIANTS = {f"QuarryPalette_{name}" for name in
                    ("LeafClumps", "LeafStipple", "LeafRibs", "Tufts", "Strata", "Pebbles")}
PALETTE_SCOPE = {
    "scenery": (MAP, {"QuarryColorShapes"}, {"Folder", "Part", "WedgePart"}),
    "variants": ("MaterialService", PALETTE_VARIANTS, {"MaterialVariant"}),
}
RIM_SCOPE = {
    "rim": (MAP, {"QuarryBlockRim"}, {"Folder", "Part"}),
    "archive": ("ServerStorage", {"QuarryRimArchive"}, {"Folder"}),
}
RIM_WALLS = {"WestEscarpment", "NorthCrown", "EastChalkRim", "SouthwestGate", "SoutheastGate"}
WOODLANDS = {f"{name}Woodland" for name in ("Quartz", "Ruby", "Violet", "Emerald", "Impact")}
PALETTE_WOODLANDS = {"QuartzWoodland", "ImpactWoodland"}


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


def close(first, second, tolerance=.0015):
    return len(first) == len(second) and all(math.isclose(a, b, rel_tol=0, abs_tol=tolerance)
                                              for a, b in zip(first, second))


def check_palette_edit(edit):
    path, before, after = edit["path"], edit["before"], edit["after"]
    assert before.keys() == after.keys() == {"color", "variant"}
    old = before["variant"]
    new = after["variant"]
    if old in {"QuarryFoliage_Canopy", "QuarryFoliage_Evergreen"}:
        assert path.startswith((TERRACES+"AssetScenery.", MAP+".QuarryWoodlands.",
                                MAP+".QuarryBiomeReaches.Quartz.", MAP+".EmeraldChalkLagoon.",
                                MAP+".QuarryDepthPass.EmeraldShoreTerraces."))
        assert new == old or new in {"QuarryPalette_LeafClumps", "QuarryPalette_LeafStipple", "QuarryPalette_LeafRibs"}
    elif path.startswith(MAP+".QuarryBiomeReaches."):
        assert path.endswith((".TerraceSurface", ".LowerGrassBench"))
        assert old in {"QuarryPhoto_Grass", "QuarryBlend_RubyLoam"}
        assert new == old or new == "QuarryPalette_Tufts"
    else:
        assert path.startswith(MAP+".QuarryBlockRim.") and path.endswith(".RockStratum")
        assert old == "QuarryPhoto_Slate" and new == "QuarryPalette_Strata"


def patch_parts(base, edits, contrast=False, basin=False, palette=False):
    batches = {}
    seen = set()
    equivalent = []
    mapping = {"position": ("CFrame", 0x10), "size": ("size", 0x0e),
               "color": ("Color3uint8", 0x1a), "variant": ("MaterialVariantSerialized", 1)}
    for edit in edits:
        path = edit["path"]
        if palette:
            check_palette_edit(edit)
        else:
            assert path.startswith(TERRACES) or (contrast and path == QUARTZ), f"Native edit outside authored terraces: {path}"
        if contrast:
            assert edit["after"].keys() <= {"color", "variant"}, "Contrast pass cannot alter geometry"
        if basin:
            assert path.endswith(".Turf") and edit["after"].keys() == {"color"}, "Basin only re-tints existing turf"
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
            if "anchorSize" in edit and not close(before["size"][index], edit["anchorSize"]):
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


def rim_moves(native, moves):
    wall_moves = set()
    positions = {}
    for move in moves:
        parent_path, name = move["path"].rsplit(".", 1)
        if move["parent"] == "ServerStorage.QuarryRimArchive.FormerRim":
            assert parent_path == MAP+".QuarryBasin" and name in RIM_WALLS
            child = native.one(move["path"])
            assert native.instances[child][1] == "Folder"
            wall_moves.add(name)
        else:
            assert move["parent"] == "ServerStorage.QuarryRimArchive.OuterTrees"
            assert parent_path.rsplit(".", 1)[0] == MAP+".QuarryWoodlands"
            assert parent_path.rsplit(".", 1)[1] in WOODLANDS and name in {"CanopyTree", "Evergreen"}
            candidates = set(native.paths[move["path"]])
            assert candidates and all(native.instances[ref][1] == "Model" for ref in candidates)
            matches = set()
            for ref in native.paths[move["path"]+"."+move["part"]]:
                cid, cls, index, _ = native.instances[ref]
                if cls != "Part" or native.parents[ref] not in candidates:
                    continue
                if cid not in positions:
                    count = len(native.classes[cid][1])
                    _, coords = split_cframe(native.prop(cid, "CFrame", 0x10), count)
                    positions[cid] = unpack_vectors(coords, count)
                if close(positions[cid][index], move["anchor"]):
                    matches.add(native.parents[ref])
            assert len(matches) == 1, f"Could not identify woodland tree {move}"
            child = matches.pop()
        yield child, native.one(move["parent"])
    assert wall_moves == RIM_WALLS, "Expected the five previous rim sections"


def reparent(data, moves, block_rim=False):
    native = Native(data)
    parents = native.parents.copy()
    if block_rim:
        relocated = dict(rim_moves(native, moves))
    else:
        relocated = {}
        for move in moves:
            assert move["path"].startswith(TERRACES+"AssetScenery.CobaltScenery.")
            assert move["parent"] == ARCHIVE
            child, parent = native.one(move["path"]), native.one(move["parent"])
            assert native.instances[child][1] == "Model" and native.instances[parent][1] == "Folder"
            relocated[child] = parent
    assert len(relocated) == len(moves)
    parents.update(relocated)
    return write_parents(native, parents), relocated


def write_parents(native, parents):
    result = [native.data[:32]]
    for kind, _, raw in native.chunks:
        if kind == b"PRNT":
            raw = chunk(b"PRNT", b"\0"+struct.pack("<I", len(parents))+pack_refs(parents)+pack_refs(parents.values()))
        result.append(raw)
    return b"".join(result)


def read_section(directory, name):
    compressed = base64.b64decode((directory/(name+".b64")).read_bytes().strip(), validate=True)
    return subprocess.run(["zstd", "-d", "-q", "-c"], input=compressed, capture_output=True, check=True).stdout


def surface_inventory(native, prefix):
    vectors = {}
    rows = Counter()
    for ref, (cid, cls, index, _) in native.instances.items():
        path = native.path(ref)
        if not path.startswith(prefix) or cls not in {"Part", "WedgePart"}:
            continue
        if cid not in vectors:
            count = len(native.classes[cid][1])
            _, coords = split_cframe(native.prop(cid, "CFrame", 0x10), count)
            vectors[cid] = (unpack_vectors(coords, count), unpack_vectors(native.prop(cid, "size", 0x0e), count),
                            unpack_colors(native.prop(cid, "Color3uint8", 0x1a), count),
                            string_values(native.prop(cid, "MaterialVariantSerialized", 1), 0, count))
        pos, size, color, variant = (values[index] for values in vectors[cid])
        rows[path.removeprefix(prefix), cls, pos, size, color, variant.decode()] += 1
    return rows


def palette_woodland(original, directory, edits):
    model = read_section(directory, "woodland")
    assert model.startswith(b"<roblox!\x89\xff\r\n\x1a\n")
    live = Native(model)
    roots = [ref for ref, parent in live.parents.items() if parent == -1]
    assert len(roots) == 2 and {live.instances[ref][3] for ref in roots} == PALETTE_WOODLANDS
    assert all(cls in {"Folder", "Model", "Part", "WedgePart"} for cls, _ in live.classes.values())
    prefix = MAP+".QuarryWoodlands."
    relocated, remaining, reconciled = {}, edits.copy(), 0
    archive = original.one("ServerStorage.QuarryRimArchive")
    for name in PALETTE_WOODLANDS:
        assert "ServerStorage.QuarryRimArchive."+name not in original.paths
        old_root, new_root = original.one(prefix+name), live.one(name)
        assert original.instances[old_root][1] == live.instances[new_root][1] == "Folder"
        old_children = Counter((original.instances[ref][1], original.instances[ref][3])
                               for ref, parent in original.parents.items() if parent == old_root)
        new_children = Counter((live.instances[ref][1], live.instances[ref][3])
                               for ref, parent in live.parents.items() if parent == new_root)
        assert old_children == new_children and ("Folder", "ForestShelf") in new_children
        ground = name+".ForestShelf."
        assert surface_inventory(original, prefix+ground) == surface_inventory(live, ground)
        rows = surface_inventory(live, name+".")
        for edit in edits:
            if not edit["path"].startswith(prefix+name+"."):
                continue
            check_palette_edit(edit)
            relative = edit["path"].removeprefix(prefix+name+".")
            color, variant = tuple(edit["after"]["color"]), edit["after"]["variant"]
            matches = [key for key, count in rows.items() if count and key[:2] == (relative, edit["class"])
                       and key[-1] == variant and close(key[-2], color, 1) and close(key[2], edit["anchor"])]
            assert matches, f"Woodland export does not contain the edited foliage: {edit}"
            rows[matches[0]] -= 1
            remaining.remove(edit)
            reconciled += 1
        relocated[old_root] = archive
    return model, remaining, relocated, reconciled


def merge(base, directory, contrast=False, basin=False, addition=None, block_rim=False, palette=False):
    original = Native(base)
    moved, reconciled = {}, 0
    if addition or block_rim:
        moves = json.loads(read_section(directory, "moves")) if block_rim else []
        plan = {"edits": [], "moves": moves}
        result, touched = base, set()
        scope = RIM_SCOPE if block_rim else addition
    else:
        plan = json.loads(read_section(directory, "edits"))
        assert plan.keys() == {"edits", "moves"} and plan["edits"]
        assert bool(plan["moves"]) == (not contrast and not basin and not palette), "Unexpected archive operation for this pass"
        edits = plan["edits"]
        if palette and (directory/"woodland.b64").is_file():
            woodland, edits, moved, reconciled = palette_woodland(original, directory, edits)
        result, touched = patch_parts(original, edits, contrast, basin, palette)
        scope = PALETTE_SCOPE if palette else BASIN_SCOPE if basin else CONTRAST_SCOPE if contrast else SCOPE
    for name, (parent, roots, allowed) in scope.items():
        model = read_section(directory, name)
        assert model.startswith(b"<roblox!\x89\xff\r\n\x1a\n"), "Expected Studio's native binary model export"
        scoped = Native(model)
        root_refs = [ref for ref, p in scoped.parents.items() if p == -1]
        assert len(root_refs) == len(roots) and {scoped.instances[ref][3] for ref in root_refs} == roots
        assert all(cls in allowed for cls, _ in scoped.classes.values()), f"Unexpected {name} model content"
        current = Native(result)
        assert all(parent+"."+root not in current.paths for root in roots), f"{name} already exists"
        result = append_model(result, model, current.one(parent), chunks, chunk, u32, string, packstr)
    if moved:
        current = Native(result)
        result = write_parents(current, {**current.parents, **moved})
        current = Native(result)
        result = append_model(result, woodland, current.one(MAP+".QuarryWoodlands"), chunks, chunk, u32, string, packstr)
    if plan["moves"]:
        result, moved = reparent(result, plan["moves"], block_rim)
    final = Native(result)
    # No original instance was reserialized, and no other property changed.
    assert original.instances.items() <= final.instances.items()
    assert set(touched) == {key for key, old in original.props.items() if final.props[key] != old}
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    assert all(final.parents[ref] == moved.get(ref, parent) for ref, parent in original.parents.items())
    stats = {
        "parts_updated": len(plan["edits"]), "archived_models": len(plan["moves"]),
        "new_instances": len(final.instances)-len(original.instances),
        "preserved_sources": len(script_inventory(final.chunks)),
    }
    if reconciled:
        stats["woodland_foliage_reconciled"] = reconciled
    return result, stats


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
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--contrast", action="store_true", help="Use the quarry contrast pass allowlist")
    scope.add_argument("--basin", action="store_true", help="Use the quarry basin pass allowlist")
    scope.add_argument("--woodlands", dest="addition", action="store_const", const=WOODLAND_SCOPE,
                       help="Append only the authored woodland scenery")
    scope.add_argument("--biome-reaches", dest="addition", action="store_const", const=BIOME_REACH_SCOPE,
                       help="Append only the authored biome extensions")
    scope.add_argument("--arrival-accents", dest="addition", action="store_const", const=ARRIVAL_SCOPE,
                       help="Append only the spawn and biome approach accents")
    scope.add_argument("--quarry-motifs", dest="addition", action="store_const", const=MOTIF_SCOPE,
                       help="Append the eight original quarry patterns and their props")
    scope.add_argument("--block-rim", action="store_true", help="Add the block rim and archive replaced scenery")
    scope.add_argument("--color-shapes", action="store_true", help="Save quarry palette and abstract accents")
    parser.add_argument("--write", action="store_true", help="Atomically update the canonical file after checks")
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, "Canonical file changed; reconcile before saving"
    result, stats = merge(data, args.export_dir, args.contrast, args.basin, args.addition, args.block_rim, args.color_shapes)
    if args.write:
        write_snapshot(data, result)
    print(json.dumps({**stats, "wrote": args.write, "sha256": sha256(result).hexdigest()}, indent=2))


if __name__ == "__main__":
    main()
