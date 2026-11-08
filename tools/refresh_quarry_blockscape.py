#!/usr/bin/env python3
"""Check and mirror the shared Edit blockscape without rewriting original instances."""
import argparse
from collections import defaultdict
from functools import cache
from hashlib import sha256
import json
from pathlib import Path
import re

from build import CANONICAL_OUTPUT, chunk, chunks, packstr, script_inventory, string, u32
from import_lighting import append_model
from refresh_native_scenery import MAP, QUARTZ, TERRACES, Native, close, patch_parts, read_section, split_cframe
from refresh_native_scenery import unpack_vectors, write_parents, write_snapshot

SCENERY = "QuarryBlockscape"
ARCHIVE = "QuarryBlockscapeArchive"
WHOLE_SECTIONS = {
    MAP + "." + name for name in (
        "QuarryBasin", "CobaltMushroomGrove", "RubyCrimsonBluffs", "QuarryColorShapes",
        "QuarryDepthPass.MaterialSamples", "QuarryDepthPass.RubyEscarpment", "QuarryDepthPass.VioletRidge",
        "QuarryDepthPass.EmeraldShoreTerraces", "QuarryDepthPass.CobaltForestExtension.Canopy",
        "QuarryDepthPass.CobaltForestExtension.Understory",
    )
} | {TERRACES + name for name in (
    "StudPackCliffs", "GroundArt.MineralSurfaceVariation", "GroundArt.MeadowPatches",
)}
ALLOWED_MOVES = tuple(re.compile(re.escape(prefix) + pattern) for prefix, pattern in (
    (MAP + ".QuarryBlockRim.", r"(?:WestEscarpment|NorthCrown|EastChalkRim|SouthwestGate|SoutheastGate)\."
     r"(?:Escarpment|ShoulderGrass|CrownRock|CrownGrass|FracturedColumn|ColumnMoss|RockStratum|FootBlock)"),
    (MAP + ".QuarryArrivalAccents.", r"(?!SpawnCyanWedge$|SpawnAmberDiscs$)\w+"),
    (MAP + ".QuarryWoodlands.", r"(?:Quartz|Impact|Ruby|Violet|Emerald)Woodland\.(?:CanopyTree|Evergreen)"),
    (MAP + ".QuarryBiomeReaches.", r"(?:Quartz|Impact|Ruby|Cobalt|Violet|Emerald)\.Shelf[12]_[1-5]\.Signature"),
    (MAP + ".EmeraldChalkLagoon.", r"(?:LeafyShelf|WindBentTrunk|WindBentBranch|WaterReed|ReedLight)"),
    (TERRACES + "AssetScenery.", r"(?:Quartz|ImpactTest|Ruby|Cobalt|Violet|Emerald)Scenery\.\d\d_\w+"),
    (TERRACES + "MarketGardens.", r"(?:Rock|Tree2|Grass1|Flowers|Bush)"),
))
BASE_PARTS = {"Part", "WedgePart", "MeshPart", "UnionOperation"}
ALLOWED_ARCHIVE_CLASSES = BASE_PARTS | {"Model", "Folder", "SpecialMesh", "PointLight", "Weld"}


def resolve_archive(native, moves):
    children = defaultdict(list)
    for ref, parent in native.parents.items():
        children[parent].append(ref)

    @cache
    def positions(cid):
        count = len(native.classes[cid][1])
        _, coords = split_cframe(native.prop(cid, "CFrame", 0x10), count)
        return unpack_vectors(coords, count)

    def anchored_at(ref, anchor):
        cid, cls, index, _ = native.instances[ref]
        return cls in BASE_PARTS and close(positions(cid)[index], anchor)

    def subtree(ref):
        yield ref
        for child in children[ref]:
            yield from subtree(child)

    moved, seen, expected_paths = set(), set(), set()
    archived_parts = 0
    for move in moves:
        path, cls = move["path"], move["class"]
        assert path in WHOLE_SECTIONS or any(rule.fullmatch(path) for rule in ALLOWED_MOVES), path
        expected_paths.add(path)
        matches = []
        for ref in native.paths.get(path, []):
            if ref in moved or native.instances[ref][1] != cls:
                continue
            if "part" in move:
                if not any(native.instances[child][3] == move["part"] and anchored_at(child, move["anchor"])
                           for child in children[ref]):
                    continue
            elif "anchor" in move and not anchored_at(ref, move["anchor"]):
                continue
            if sum(1 for _ in subtree(ref)) == move["descendants"] + 1:
                matches.append(ref)
        assert matches, f"Could not reconcile {move}"
        # Some authored decoration copies occupy exactly the same transform.
        # Require the plan to relocate every matching copy before accepting it.
        ref = matches[0]
        if len(matches) > 1:
            seen.update(matches)
        contents = list(subtree(ref))
        assert len(contents) == move["descendants"] + 1, f"Unreconciled descendants in {path}"
        count = 0
        for child in contents:
            cid, child_class, index, _ = native.instances[child]
            assert child_class in ALLOWED_ARCHIVE_CLASSES, (path, child_class)
            if child_class in BASE_PARTS:
                assert native.prop(cid, "Anchored", 2)[index] == 1, path
                if path != MAP + ".QuarryBasin" and not path.startswith(MAP + ".QuarryBlockRim."):
                    assert native.prop(cid, "CanCollide", 2)[index] == 0, path
                count += 1
        assert count == move["parts"], path
        archived_parts += count
        moved.add(ref)
    assert WHOLE_SECTIONS <= expected_paths
    assert seen <= set(moved), "Ambiguous native archive moves"
    assert not (set(moved) & {p for ref in moved for p in subtree(ref) if p != ref}), "Nested archive moves"
    return moved, archived_parts


def append_export(data, directory, name, parent, root, allowed):
    model = read_section(directory, name)
    assert model.startswith(b"<roblox!\x89\xff\r\n\x1a\n")
    export = Native(model)
    assert [export.instances[ref][3] for ref, p in export.parents.items() if p < 0] == [root]
    assert all(cls in allowed for cls, _ in export.classes.values())
    native = Native(data)
    assert parent + "." + root not in native.paths
    return append_model(data, model, native.one(parent), chunks, chunk, u32, string, packstr)


def merge(data, directory):
    original = Native(data)
    moves, archived_parts = resolve_archive(original, json.loads(read_section(directory, "moves")))
    finishes = json.loads(read_section(directory, "finishes"))
    assert sum(edit["path"] == QUARTZ for edit in finishes) == 1
    for edit in finishes:
        path, old, new = edit["path"], edit["before"]["variant"], edit["after"]["variant"]
        if path == QUARTZ:
            assert (old, new) == ("QuarryAccent_RoughBed", "QuarryPhoto_Pebble")
        else:
            assert path.startswith(TERRACES) and path.endswith(".Turf")
            assert old in {"QuarryPhoto_Grass", "QuarryAccent_LushGrass"} and new == "QuarryPhoto_Grass"
    result, touched = patch_parts(original, finishes, contrast=True)
    result = append_export(result, directory, "scenery", MAP, SCENERY, {"Folder", "Part"})
    result = append_export(result, directory, "archive", "ServerStorage", ARCHIVE, {"Folder"})
    native = Native(result)
    relocated = dict.fromkeys(moves, native.one("ServerStorage." + ARCHIVE))
    final = Native(write_parents(native, {**native.parents, **relocated}))
    assert original.instances.items() <= final.instances.items()
    assert touched == {key for key, value in original.props.items() if final.props[key] != value}
    assert all(final.parents[ref] == relocated.get(ref, p) for ref, p in original.parents.items())
    assert script_inventory(original.chunks) == script_inventory(final.chunks)
    return final.data, {
        "archived_roots": len(moves),
        "archived_parts": archived_parts,
        "new_parts": sum(ref not in original.instances and cls == "Part"
                         for ref, (_, cls, _, _) in final.instances.items()),
        "finish_edits": len(finishes),
        "preserved_sources": len(script_inventory(final.chunks)),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, "Canonical file changed"
    result, stats = merge(data, args.export_dir)
    if args.write:
        write_snapshot(data, result)
    print(json.dumps({**stats, "wrote": args.write, "sha256": sha256(result).hexdigest()}, indent=2))


if __name__ == "__main__":
    main()
