#!/usr/bin/env python3
"""Mirror the scoped flat-field Edit export into the existing native place."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

from build import CANONICAL_OUTPUT, chunk, chunks, packstr, script_inventory, string, u32
from import_lighting import append_model
from refresh_native_scenery import MAP, Native, read_section, write_parents, write_snapshot

ARCHIVE = "ServerStorage.FlatFieldsArchive"
VOXEL_PROPERTIES = {"PhysicsGrid", "SmoothGrid", "VoxelGridAssetContentMap"}
OLD_ROOTS = [
    *(f"{MAP}.{name}" for name in (
        "PlatformSurfaceFill", "QuarryContinuousGround", "MiningAwayReferenceGround",
        "CrystalRun", "DronerevolutionTerraces",
    )),
    "Workspace.MiningAway.Fields", "Workspace.Part",
    "Workspace.Terrain.MideDibber_Hats", "Workspace.Terrain.OliveGord_Hats",
]


def add(native, model, parent, root_name, classes):
    export = Native(model)
    assert [export.instances[ref][3] for ref, p in export.parents.items() if p < 0] == [root_name]
    assert {cls for cls, _ in export.classes.values()} <= classes
    result = append_model(native.data, model, native.one(parent), chunks, chunk, u32, string, packstr)
    return Native(result)


def terrain_props(native):
    cid = native.instances[native.one("Workspace.Terrain")][0] if "Workspace.Terrain" in native.paths else native.instances[native.one("Terrain")][0]
    return {name: (kind, value) for (cls, name), (kind, value) in native.props.items()
            if cls == cid and name in VOXEL_PROPERTIES}


def merge(data, staging):
    original = Native(data)
    moves = [original.one(path) for path in OLD_ROOTS]
    before = terrain_props(Native(read_section(staging, "terrainBefore")))
    assert before.keys() == VOXEL_PROPERTIES and before == terrain_props(original), "Studio terrain differs from canonical"
    # The compressed native export was created before moving the old Workspace roots.
    native = add(original, read_section(staging, "archive"), "ServerStorage",
                 "FlatFieldsArchive", {"Folder", "TerrainRegion"})
    archive = native.one(ARCHIVE)
    relocated = dict.fromkeys(moves, archive)
    native = Native(write_parents(native, {**native.parents, **relocated}))
    native = add(native, read_section(staging, "run"), MAP, "CrystalRun", {"Folder", "Part"})
    native = add(native, read_section(staging, "fields"), "Workspace.MiningAway", "Fields", {"Folder"})
    run = f"{MAP}.CrystalRun"
    for name in ("Quartz", "Ruby", "Cobalt", "Violet", "Emerald"):
        native.one(f"{run}.{name}.Field")
    assert original.instances.items() <= native.instances.items()
    assert all(native.parents[ref] == relocated.get(ref, parent) for ref, parent in original.parents.items())
    assert all(native.props[k] == v for k, v in original.props.items() if k[1] not in VOXEL_PROPERTIES
               and k[0] not in {native.instances[native.one(run)][0], native.instances[native.one(f"{run}.FlatGround")][0],
                                native.instances[archive][0]})
    assert script_inventory(original.chunks) == script_inventory(native.chunks)

    # Dry run checks the relocation and the live pre-clear grids. Write also
    # requires the actual empty Terrain export returned by the verified Edit apply.
    if not (staging / "terrainAfter.b64").exists():
        return None
    after = terrain_props(Native(read_section(staging, "terrainAfter")))
    assert after.keys() <= VOXEL_PROPERTIES and after["SmoothGrid"] != before["SmoothGrid"]
    terrain_cid = native.instances[native.one("Workspace.Terrain")][0]
    output = [native.data[:32]]
    for kind, prop, raw in native.chunks:
        if kind == b"PROP" and u32(prop) == terrain_cid:
            name, end = string(prop, 4)
            if name in VOXEL_PROPERTIES:
                if name not in after:
                    continue
                ty, value = after[name]
                assert ty == prop[end]
                raw = chunk(kind, prop[:end+1] + value)
        output.append(raw)
    result = b"".join(output)
    final = Native(result)
    assert terrain_props(final) == after
    assert final.parents == native.parents and final.instances == native.instances
    assert script_inventory(final.chunks) == script_inventory(original.chunks)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--baseline-sha256", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    data = CANONICAL_OUTPUT.read_bytes()
    assert sha256(data).hexdigest() == args.baseline_sha256, "Canonical file changed"
    result = merge(data, args.export_dir)
    if args.write:
        assert result is not None, "Apply the checked Studio stage and export terrainAfter first"
        write_snapshot(data, result)
    print(json.dumps({"archived_roots": len(OLD_ROOTS), "fields": 5, "wrote": args.write,
                      "sha256": sha256(result).hexdigest() if result else None}, indent=2))


if __name__ == "__main__":
    main()
