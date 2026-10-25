# Map reference — expanded Alabaster Valley

The map assembles on **Play** from `src/World.lua` and the pure terrain/route plan in `src/MapLayout.lua`. Build the original project with `python3 tools/release.py`. The historical edit scene and original asset base remain preserved.

The owner liked the first dense terrain overhaul but found it cramped. The current revision expands the horizontal landscape by **1.9× in both directions**, about **3.6× the planning footprint**, and enlarges mineral fields by 1.4× horizontally. It leaves a sparse central meadow around the original depot, with the fields between home and the outer wooded hills. Further decorative detail is deferred until scale and traversal are accepted.

## Layout

The generated terrain envelope is X −192.8…202.4 and Z −187.7…207.5, about 395×395 studs, with an irregular perimeter. The preserved baseplate extends beyond it. The central meadow has protected half-widths of 50 and 46 studs around home: terrain stays at ground level, and new tree canopies are excluded. The depot, printer, card console and prestige uplink remain in their original compact service area. The original Converter remains at (−86,4,−37.5).

```text
                            NORTH / −Z
                 Cobalt ─── high pass ─── Violet
                      ╲                        ╲
               open approach             Emerald ridge
                       ╲                     ╱
             Converter ─── HOME / OPEN MEADOW
                            ╲              ╱
                    Ruby ───── Quartz ───┘
                woodland/cliff     wider low field
                   overlook
                            SOUTH / +Z
```

The two loops and scenic Ruby overlook remain. The longer approaches preserve terrain variation at the edges without packing every biome directly against the spawn. These are walkable routes, not invisible unlock gates. Turret encounters still control mining permission, not physical traversal.

| ID | Field | Center XYZ | Size XYZ | Top Y | Node budget | Defense |
|---|---|---|---|---|---|---|
| 1 | Landing Quartz | 2.9, .5, 57.4 | 47.6×2×47.6 | 1.5 | 12 | Safe |
| 2 | Ruby Grove | −118.7, 12, 97.3 | 42×2×42 | 13 | 16 | Safe |
| 3 | Cobalt Ridge | −54.1, 19, −109.8 | 42×2×42 | 20 | 6 | 1 original construct |
| 4 | Violet Basin | 50.4, 29, −88.9 | 47.6×2×44.8 | 30 | 9 | 2 original constructs |
| 5 | Deep Emerald | 116.9, 39, 19.4 | 47.6×2×47.6 | 40 | 12 | 2 original constructs |

`Config.Fields` controls all field offsets/sizes, including the reused Ruby/Cobalt objects. Numeric IDs, mineral values, budgets and defenses remain stable. Geodes reserve five ordinary slots. Bounded random placement and separation checks may produce fewer visible objects than the budget. Crystals, damage, defense state, rewards and progression remain authoritative server logic.

## Plan and traversal

`MapLayout.Scale` is 1.9 and `FieldScale` is 1.4. Authored route coordinates retain their readable design space. `plan:point(x,z)` expands the landscape around the original spawn; `plan:biomePoint(id,x,z)` preserves the local relationship of grove/landmark clusters to their resized field. Endpoints inside a field are mapped with the field's scale to retain a full-height connection.

Nine routes are 10.8–14.4 studs wide. Quadratic bends round both horizontal position and elevation; solid earth supports close their undersides. Terrain cells scale to 15.2 studs and merge into broad strata. The plan conservatively lowers cells around the actual rounded routes, field boundaries, depot/Converter and Ruby mine recess. The original direct eased drone travel is unchanged; representative flight corridors clear the terrain.

Every `Trail` carries `RouteName`, `RouteSegment`, `RouteStart`, `RouteEnd` and `RouteWidth` metadata. `tests/map.studio.lua` checks real floor rays and upright body volumes; it excludes walk surfaces from body boxes because floor rays handle pitched roads. `tests/map.walk.studio.lua` stages an actual avatar at each route start and walks its chords without jumping; set `onlyRoute` for a repaired-route rerun. Neither script is multiplayer proof.

## Outer biomes and original assets

Ruby retains red/auburn forked trees, warm rock, an amber-lit timber mine entrance and a higher overlook. Cobalt has cyan groves; Violet lavender woodland; Emerald green forest and fern switchbacks. Larger open approaches separate these outer areas from the hub. The original segmented construct is moved intact onto a supported outer ridge; active guards remain clones of the original model.

Existing mine, trolley, aqueduct/waterfall, fungi and survey props move as complete local assemblies so their component spacing is preserved. No new decoration pass was added during the expansion. Current generated groves contain 41 trees after route/field/hub clearance filtering. This is a count, not a performance certification.

Keep the established low-poly palette: teal rock, pale chalk bands, cream trails, auburn/cyan/lavender/green biomes, dark machinery and restrained light accents. Daylight remains 13.8 hours with .22 atmosphere density and moderate color saturation. No Bee Swarm assets were imported.

The original base remains `assets/mining-away-base.rbxl`. The builder preserves all non-controller binary chunks and changes only controller sources/enabled states. Runtime archives old experiments and decals instead of deleting the original source content. Original drone/crystal/beam assets, construct meshes/rig and source animation history remain preserved.

## Validation

The 12 pure map checks cover expanded scale/open hub, grades, terrain/field and route clearance, field-entry heights, crossed foundations, folded road edges, representative flight, forest clearance, depot clearance and spawn metadata. Full source/domain/API-double and binary/original-asset suites pass. Actual Studio evidence includes 3,120 final floor/body samples with no issues and real-avatar coverage of all nine routes across the initial pass and repaired Grove rerun. See `docs/review/EXPANDED_MAP.md` and its JSON evidence for scope and remaining limits.
