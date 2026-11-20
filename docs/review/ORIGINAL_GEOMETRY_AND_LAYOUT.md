# Original geometry and repaired layout review

This is a cloud source/geometry inspection, not a Roblox Studio screenshot or visual-parity playtest.

## What was verified from the binary

The source `assets/mining-away-base.rbxl` was parsed read-only. Parent referents identify `Workspace.construct` as a Model containing `basepart`, seven original MeshParts, an AnimationController/Animator, and the authored AnimSaves model. There is no source object literally named Turret or Pyramid.

| Actual segment | Mesh ID | Original world center (studs) | Original size (studs) |
|---|---|---|---|
| bottemseg | 14477420875 | 44.000, 2.368, 0.000 | 7.898, 2.737, 7.898 |
| lowerseg | 14477422793 | 43.792, 5.550, -0.124 | 5.965, 3.345, 6.103 |
| upperseg | 14477425917 | 44.048, 8.325, -0.005 | 2.798, 0.924, 2.886 |
| topseg | 14477427275 | 43.949, 9.829, -0.018 | 1.798, 0.939, 1.863 |
| eye | 14477430698 | 44.000, 3.698, 0.000 | 3.392, 3.392, 3.392 |
| eyecase | 14477428635 | 44.000, 3.698, 0.511 | 3.854, 3.854, 2.833 |
| spawnEye | 14477430698 | 44.000, 3.698, 0.000 | 3.400, 3.400, 3.400 |

`basepart` is a 10 × 1 × 10 Part at (44, 0.5, 0). Its stable pivot is used when cloning the real turret. `W.turret` requires every named original segment, retains the segment transforms and live rig/AnimationController/Animator, and adds only a transparent query hitbox. Full editor animation data remains untouched in the source construct and full ServerStorage template; only each redundant active-clone AnimSaves history is omitted. It never substitutes a primitive visible body. The actual `eye` is the emitter. The original construct remains at its source position as a dormant landmark; active guards are authored-model clones with one coherent server health state each.

The original drone is `ReplicatedStorage.Drone`, with its 2 × 2 × 2 `Mesh` Part and nested `Emmiter`. The ordinary crystal is `ReplicatedStorage.Crystal.Mesh`, an original UnionOperation (source dimensions approximately 3.135 × 6.567 × 4.487). Its underlying union is preserved; runtime isotropic size is based on the original health/25 rule. Original `MiningFX.Beam.InnerBeam` and `OuterBeam` are cloned when present. Historical source lacks live-only RockCrack/RockBreak assets; runtime sound handling must label that source limitation rather than inventing original audio IDs.

## Spatial decisions

The world starts from the original SpawnLocation (-56, 0.5, -11), not an elevated replacement. The Baseplate remains at source height with its top at Y=0. The original Converter remains at (-86, 4, -37.5), Ruby field at (-89, 12, 55), and Cobalt field at (-49, 0.5, -85). Original Ruby elevation is served by a broad two-segment uphill trail. New safe Quartz and guarded Violet/Emerald fields extend this existing ground-level landscape. Grounded field signs face the depot/approach instead of presenting a backside to the player.

| Landmark | Center X/Z | Walk relationship |
|---|---|---|
| Depot / spawn | -56 / -11 | Open-sided frame, compact three-station apron |
| Converter | -86 / -37.5 | About 40 studs from spawn, visible on short side trail |
| Landing Quartz | -26 / 32 | About 52 studs from depot, safe first assignment |
| Ruby Grove | -89 / 55 | About 74 studs from depot, original elevated field with gentle ramp |
| Cobalt Ridge | -49 / -85 | About 74 studs from depot, original field and first pyramid guard |
| Violet Basin | 29 / -68 | About 80 studs beyond Cobalt, paired pyramids |
| Deep Emerald | 91 / -26 | About 75 studs beyond Violet, stronger paired pyramids |

Field footprints remain 30–42 studs wide. The renderer's radius-10 following formation fits between the depot's side pillars. Printer/cards/prestige occupy separate small machines; there is no permanent per-crystal floating text. Sparse angular parts-built trees frame paths and leave fields open. Far monoliths and the dormant source construct provide long-view direction rather than additional HUD panels.

`WORLD_LAYOUT.svg` is a schematic drawn from these configured coordinates. It is an outside-engine layout aid, not evidence of rendered quality, collision correctness, original mesh appearance or multiplayer behavior.

## Parity evidence and remaining engine checks

`tests/feel.spec.lua` runs the actual shared pure helpers. At 60 Hz the position equation matches original `.03` capped movement to floating-point tolerance; yaw alpha equals `.1`. The 30/60/120/144 Hz fixed-goal paths agree within 0.12 studs at the cap/easing transition; uncapped elapsed-time paths are equal. The tests cover radius-10 formation, original slow ±1/3 hover, exact 75/50/25 health changes, all thresholds crossed in a large hit, and two-second Quad.Out grow-in readiness. These math checks do not establish visual parity.

Studio must still verify authored mesh loading/pivots, actual camera-scale readability, every trail/field edge, eye telegraph visibility, resource surface impact, local-model hiding, crack/shatter sounds, and simultaneous six-drone rendering. The source has been preserved for direct original-versus-repaired comparison; no Studio comparison is claimed here.

## Integration review findings sent to implementation

- A turret cloned with its `basepart` pivot placed exactly at the field center sinks its base into the field. Place its pivot at field top plus the original half-height (0.5 stud).
- Resource sampling must exclude the live pyramid footprint, not just other resources, so organic positions cannot appear inside its query body.
- Selling must use the original Converter's distance rather than a depot-center radius: the Converter is roughly 40 studs from the source spawn.
- Turret discovery must match the actual runtime `Turret=true` model attribute when guards are children of field models. Health/telegraph visibility cannot rely on an unassigned `TurretId` or a different parent folder.
- The source `basepart` is authored at Transparency 0.5. Restore per-part source transparency after a turret reset rather than making every original part opaque.
- The source `spawnEye` is opaque and is slightly larger than the colocated `eye`. Charge cues applied only to `eye` may be obscured; animate both eye surfaces while retaining silhouette.
- Avoid rendering a second `.1` yaw low-pass on top of a server-smoothed yaw; goal-derived level yaw permits a single original-feel render turn.

These were source-review findings, communicated before integration tests. Their resolution must be checked against the final implementation and in Studio; listing a finding is not a visual acceptance result.


## Final source review and bounded live geometry

Read-only binary traversal counted **3,444 instances** in the source construct, mostly editor history (1,671 IntValues, 1,412 Poses and 290 Keyframes). Replicating five full active copies would have added roughly 17,220 instances before actual gameplay objects. Active `W.turret` now clones the complete model first to preserve cross-child Motor6D links, removes only that clone's editor `AnimSaves`, and retains every original mesh, transform, runtime joint, AnimationController and Animator. The authored source construct and complete ServerStorage template retain their history. This is a structural optimization, not a measured Studio frame-rate result.

Final source review confirmed earlier placement and identity findings were fixed in integration: raised base pivot, shared existing DefenseHitbox, resource exclusions around guard footprint, Converter station range, per-part source transparency on reset, turret identity discovery, eye/spawnEye frozen-aim cues, and a single client yaw blend. Ordinary mining remains centered exactly over its assigned resource, with beam impact on the current shrinking/tilting visible surface.

Card layout was checked against actual configured descriptions and before/after previews. The 58-pixel effect area fits the present short catalog copy, 31-pixel preview fits the present maximum two stat lines, and named target/ID has two lines. Mobile cards stack rather than shrink type. Fixed HUD/context/notice widths on very narrow screens and delayed original-template descendants were sent back as additional findings before final handoff. Actual text measurement, touch selection, mesh pivot/render loading and camera-scale appearance remain Studio checks.

The final mobile-width correction was verified in source: HUD, contextual interaction and notice widths are clamped to the viewport rather than fixed at desktop dimensions. The drone renderer now waits for the complete original ReplicatedStorage template, including its nested emitter/attachment/weld/beam components, instead of cloning an incompletely replicated gameplay model. Its original Part body keeps shape/material and receives a restrained 25% type-color tint because the smaller emitter lies inside it. These are code-level resolutions; native Roblox rendering remains unexecuted.
