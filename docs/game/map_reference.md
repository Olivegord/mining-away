# Map reference — parts-built Alabaster Valley

The map assembles on **Play** from `src/World.lua` and the pure terrain/route plan in `src/MapLayout.lua`. Build the original project with `python3 tools/release.py`. The historical edit scene and original asset base remain preserved.

The current candidate retains the expanded 1.9× route plan but rebuilds its ground from studded square Part terraces, adds depot connections and landmarks, and grounds trees on sampled footings. It is a source implementation awaiting actual visual and traversal review; see [the retro world report](../review/RETRO_WORLD.md).

## Layout

The generated terrain envelope is X −192.8…202.4 and Z −187.7…207.5, about 395×395 studs, with an irregular perimeter. The preserved baseplate extends beyond it. The central open depot has protected half-widths of 50 and 46 studs around home: terrain stays at ground level, and new tree canopies are excluded. The depot, printer, card console and prestige uplink remain in their original compact service area. The original Converter remains at (−86,4,−37.5).

```text
                            NORTH / −Z
                 Cobalt ─── high pass ─── Violet
                      ╲                        ╲
               open approach             Emerald ridge
                       ╲                     ╱
             Converter ─── HOME / OPEN DEPOT
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

Existing mine, trolley, aqueduct/waterfall, fungi and survey props move as complete local assemblies so their component spacing is preserved. No new decoration pass was added during the expansion. Current generated groves contain 34 trees after route, field, hub and footing-clearance filtering. This is a count, not a performance certification.

The candidate uses a retro parts-built material vocabulary: green and stone terraces, pale connected trails, mineral-colored accents, dark machinery and restrained lighting. No Bee Swarm assets were imported. Native meadow and faceted terrain code are retained as references but are not invoked for the current ground.

The original base remains `assets/mining-away-base.rbxl`. The builder preserves all non-controller binary chunks and changes only controller sources/enabled states. Runtime archives old experiments and decals instead of deleting the original source content. Original drone/crystal/beam assets, construct meshes/rig and source animation history remain preserved.

## Validation

Fifteen pure map checks cover geometry, clearance, depot links and tree footing samples. Earlier Studio floor and avatar results in `docs/review/EXPANDED_MAP.md` concern the historical map, not this candidate. The new candidate requires fresh in-engine traversal, contact and visual checks; `tests/terrain-surface.studio.lua` has not been run.
