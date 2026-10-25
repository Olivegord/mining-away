# Map reference — compact Alabaster Valley

The current map is assembled on Play by `src/World.lua`, using the pure, deterministic terrain plan in `src/MapLayout.lua`. Build the single original project with `python3 tools/release.py`. The historical edit scene is intentionally retained in the binary; it is not the runtime map.

The October 25 compact-map overhaul supersedes the earlier sparse Alabaster Reach layout. It preserves chalk bands, dark teal rock, simple parts-built trees, original drone/crystal meshes, the original Converter and the segmented construct. The original Ruby/Cobalt field **objects** are now deliberately repositioned with the other fields; the old coordinates are no longer current.

## Composition

The depot sits inside a continuous stepped valley. Paths bend around cliff shoulders, rise through tree groves, and reconnect rather than radiating toward isolated platforms. Five mineral clearings sit within 100 horizontal studs of the original spawn. The generated terrain footprint is bounded by X −128…80 and Z −104…104, with an irregular perimeter. The preserved original baseplate and historical trees extend beyond this composed area.

```text
                           NORTH / −Z
                waterfall / aqueduct
             Cobalt ─── high pass ─── Violet
                ╲                         ╲
                 winding ascent       Emerald ridge
                      ╲                  ╱
       Converter ─── DEPOT          fern switchbacks
                     ╱  ╲              ╱
          Ruby woodland ──── Quartz ──┘
             cliff mine
             ╲ switchback / overlook
                           SOUTH / +Z
```

The two loops are Depot → Quartz → Ruby → Depot and Depot → Cobalt → Violet → Emerald → lower grove loop → Quartz → Depot. A Ruby overlook is a deliberate scenic spur. Field IDs, mining permissions, defenses, rewards and card/prestige rules are unchanged by the map overhaul. Routes are physical traversal, not invisible progression locks.

## Fields

Coordinates are XYZ; Y is up. Field surface Y is center Y + 1.

| ID | Field | Center | Size | Surface | Ordinary node budget | Defense |
|---|---|---|---|---|---|---|
| 1 | Landing Quartz | −25, .5, 25 | 34×2×34 | 1.5 | 12 | Safe |
| 2 | Ruby Grove | −89, 12, 46 | 30×2×30 | 13 | 16 | Safe |
| 3 | Cobalt Ridge | −55, 19, −63 | 30×2×30 | 20 | 6 | 1 original construct turret |
| 4 | Violet Basin | 0, 29, −52 | 34×2×32 | 30 | 9 | 2 original construct turrets |
| 5 | Deep Emerald | 35, 39, 5 | 34×2×34 | 40 | 12 | 2 original construct turrets |

Geodes reserve five ordinary slots. Random samples, separation, guard exclusions and bounded server map-obstruction queries can produce fewer visible objects than the node budget. Crystal growth, fracture stages, permanent identities, replicated state and turret combat remain authoritative server logic.

`Config.Fields[*].Offset` and `Size` now govern **all** field positions and dimensions, including the original patch objects. They are offsets from the existing SpawnLocation. Numeric field IDs and keys remain stable.

## Traversal and terrain

`MapLayout.Routes` contains the exact authored waypoints for nine routes. `MapLayout.rounded` turns the sharp polyline corners into continuous quadratic bends in horizontal position and elevation. Runtime path segments use those rounded samples, not overlapping full-width landing discs. Paths are 9–12 studs wide; the tested planned grades are below 35°. Continuous solid earth supports fill their undersides.

The terrain is made of merged 8-stud cells with solid dark rock, narrow chalk strata, and biome-colored topsoil. Before creating geometry, the plan conservatively cuts down any cells near the real route samples or field footprints. Clearings have solid beds and skirts tied into the surrounding landform. This approach prevents a later terrain edit from silently burying a path or mining surface.

Every emitted `Trail` part carries `RouteName`, `RouteStart`, `RouteEnd`, and `RouteWidth` attributes for repeatable Studio inspection. These are metadata, not screen labels or client authority. Run `tests/map.studio.lua` on the actual Studio server after Play for collision ray probes. Those probes do not substitute for walking an avatar or testing multiple clients.

## Landmarks and dressing

- Home remains at (−56,.5,−11), with the existing printer, run-card console and prestige uplink arranged around its compact sheltered apron.
- The original Converter remains at (−86,4,−37.5), reached along a short service lane. Its sale range and prompt are unchanged.
- Ruby has tall red/auburn forked trees, warm soil, a timber-framed walk-in cliff recess at roughly (−88,13,66), amber work lamps, rails and sleepers. The actual crystal clearing remains outside the roof so mining drones stay visible. The cliff steps up behind the mine toward a 34-stud overlook at (−65,34,77).
- Cobalt uses cyan foliage along a winding ascent to its 20-stud ridge. A short survey gate marks the climb, without adding another UI panel.
- Violet rises to 30 studs beneath lavender trees. The high pass has a small aqueduct and mineral waterfall along the northern skyline.
- Emerald rises to 40 studs with green forest and a descending fern route. The original dormant `Workspace.construct` is moved intact onto a supported ridge plinth at (62,40.5,9), so it is visible rather than buried under the raised terrain. Active enemies remain separate original-model clones.
- Flower/fern/fungus clusters, a small ore trolley, survey crates, giant flat-capped alien fungi and branching tree trunks fill the route shoulders. Trees are filtered away from field interiors and path centers. Cosmetic foliage does not intercept mining queries; the landform supplies the maze walls.

Tree positions, heights and biome assignments are authored in `MapLayout.Trees`, then filtered against actual fields/routes. The final number is replicated on `MiningAway.TreeCount`; the route count is nine. These counts are not a performance certification.

## Visual recipe

Keep the clean low-poly vocabulary: SmoothPlastic rock/canopies, teal geological bodies, pale chalk bands, cream trails, warm auburn Ruby, cyan Cobalt, lavender Violet and saturated green Emerald. Machines retain dark metal with small accent lights. Broad surfaces do not glow.

Lighting uses 13.8-hour daylight, cool ambient fill, .22 atmosphere density, 1.1 haze, +.16 color-grade saturation and restrained bloom. There is no gameplay depth of field. The reference screenshot guided compactness, color, layering and small-part density; no Bee Swarm assets were imported.

## Preservation and validation

The verified original asset remains `assets/mining-away-base.rbxl`. The builder changes only the two controller sources/enabled states, preserving original non-script asset/property chunks. Runtime archives the old construction experiments and legacy surface decals in `ServerStorage.MiningAwayOriginalReference`. Original drone/crystal/FX meshes, construct segments and complete source editor history are preserved.

Run `python3 tools/test.py /path/to/luau`, `python3 tests/binary.spec.py` and `python3 tests/geometry.spec.py`. The ten pure map checks cover compactness, grades, terrain/field clearance, path clearance, field entry heights, crossed foundations, representative direct drone flight corridors, forest clearance, depot preservation and translation. Domain/API-double tests cover gameplay logic; they do not establish visual polish, avatar traversal, live saving or multiplayer behavior. Consult the latest `docs/review/COMPACT_MAP.md` for actual engine evidence and remaining limitations.
