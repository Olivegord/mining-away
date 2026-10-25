# Map reference

Read this instead of calling Studio MCP for routine layout questions. Coordinates below describe the deterministic runtime assembled by `src/World.lua` from `assets/mining-away-base.rbxl`. X/Z are horizontal studs; Y is up. These are source coordinates, not a collision or visual acceptance certificate. The historical place opens on its original edit scene; the composed map is assembled when Play starts.

## Route and landmarks

```text
                     NORTH / −Z

              Cobalt (−49,−85) ─── Violet (29,−68)
                    │                     ╲
              survey gate                  Emerald (91,−26)
                    │                           │
 Converter ─── Home / depot            dormant original construct
 (−86,−37.5)   (−56,−11)                       (44,0)
                   ╱  ╲
        Ruby (−89,55)   Quartz (−26,32)
         raised safe     first safe field

                     SOUTH / +Z
```

Home connects independently to the safe first field, richer Ruby and guarded Cobalt. Cobalt → Violet → Emerald forms the guarded route. There is no portal or invisible unlock wall: the shared sentry encounter controls mining permission. The player spawns facing Quartz.

| Landmark | Center XYZ | Physical / interaction notes |
|---|---|---|
| Original SpawnLocation / home | −56, 0.5, −11 | Original 12×1×12 pad; cream 40×34 apron at Y=.1; open service canopy at Y=12 |
| Card console | −68, 1, −13 | 6×2×5 machine; three physical slots; paid choose-one pack prompt |
| Free printer | −44, 1, −13 | Automatic free repair/reprint, open teal-lit gantry; no misleading manual prompt |
| Prestige uplink | −56, 1, −23 | Three stepped stacks, amber trim; explicit keep/reset confirmation |
| Original Converter | −86, 4, −37.5 | Existing tall machine, intake/ribs/collar; Sell cargo prompt; authoritative sale range is 18 studs |
| Original dormant construct | 44, 0.5, 0 base pivot | Preserved original segmented pyramid landmark, not an active enemy |
| Expedition gate | −51.2, 0, −57 | About 13.4-stud minimum clear gap between tilted chalk pylons (16 studs between their centers); amber bars distinguish the guarded route |

All proximity prompts are contextual. The game also offers a nearby HUD action. Field IDs are stable and are the numeric payload to `Command:FireServer('Patch', id)`; clients do not name arbitrary targets or award ore.

## Fields and elevations

Original Ruby and Cobalt parts retain their positions and underlying geometry. New field positions are offsets from the original spawn. The runtime renames each source field part `Field` and moves it into its named model.

| ID / key | Display name | Center XYZ | Size XYZ / top Y | Ordinary budget / regrowth | Units × sale value | Defense |
|---|---|---|---|---|---|---|
| 1 Quartz | Landing Quartz | −26, .5, 32 | 34×2×34 / 1.5 | 12 / 8s | 10 × 1 | Safe |
| 2 Ruby | Ruby Grove | −89, 12, 55 | 30×2×30 / 13 | 16 / 14s | 12 × 2 | Safe |
| 3 Cobalt | Cobalt Ridge | −49, .5, −85 | 30×2×30 / 1.5 | 6 / 25s | 15 × 4 | 1 × 260 HP; 19 damage; 1.8s interval |
| 4 Violet | Violet Basin | 29, 2, −68 | 40×2×38 / 3 | 9 / 35s | 16 × 6 | 2 × 390 HP; 24 damage; 1.8s interval |
| 5 Emerald | Deep Emerald | 91, 4, −26 | 42×2×42 / 5 | 12 / 45s | 20 × 8 | 2 × 650 HP; 34 damage; 1.7s interval |

The original Cobalt part is 30×2×30, as confirmed in the runtime; its fallback Config size is 34×2×34 and is not used while the original exists. Node budget includes geodes: one shell reserves five slots. Two-second growth is additional to the regrowth delay. Random server positions are inside local field bounds with an inset and resource/turret separation. They are not arranged in rows. Crystals use the original union and vary with 50–100 base health.

Guard base pivots sit half a stud above the field top. Their centers are at field-local Z = −0.32×field depth. Paired sentries are 17 studs apart along X. Those positions are excluded from crystal sampling. The visible shell is about 8 studs wide and 10 studs tall. An invisible 8×10×8 DefenseHitbox is queryable; cosmetic shell pieces are noncolliding. Active sentries remain visibly shared to all crews.

### Walk routes

Trails are collision-enabled pale sand slabs, normally 11–12 studs wide, with dark shoulders. Every section is pitched along the difference in endpoint Y, making actual ramps rather than decorative horizontal paths.

| Section | Endpoints XYZ | Width |
|---|---|---|
| Depot to Converter approach | (−67,.3,−19) → (−82,.4,−33) | 10 |
| Depot to Quartz approach | (−44,.3,−2) → (−36,1.64,22) | 12 |
| Ruby lower ramp | (−65,.3,3) → (−76,6,32) | 12 |
| Ruby upper ramp | (−76,6,32) → (−89,13.14,41) | 12 |
| Depot to Cobalt | (−56,.3,−27) → (−49,1.64,−71) | 12 |
| Cobalt to Violet | (−34,1.64,−82) → (11,3.14,−65) | 11 |
| Violet to Emerald | (47,3.14,−61) → (72,5.14,−31) | 11 |

Ruby has dark bedrock and a pale layered skirt extending to ground, with a chalk cap. Violet and Emerald also have supported raised beds. Small field corner brackets and survey pins identify the field footprint without enclosing the player. Short shoulder signs face the home or previous-field approach; signs and machine fascias carry the same short readout on both faces.

## Art direction and material recipe

**Alabaster Reach:** pale chalk shelves, dark teal cliff bodies, mint terrain, warm cream trails, coral Ruby foliage, cyan Cobalt foliage, lavender Violet foliage and saturated Emerald accents. This is an original direction for this game. Alabaster Harbor was not connected or found locally during this pass; no lighting/materials were copied from it.

`World.lua` owns the palette, lighting, map forms, trees, signs and machinery. `Presentation.lua` owns the moving sentry/drone/effect visuals, with pure sentry motion in `SentryMotion.lua`. `Client.lua` owns the compact ink/amber interface. Crystal/type accents in `Config.lua` remain a separate readability channel.

| Property | Value |
|---|---|
| ClockTime / latitude | 15.5 / 24 |
| Brightness / exposure | 2.4 / +.05 |
| Ambient | RGB 95,126,143 |
| OutdoorAmbient | RGB 153,176,181 |
| Diffuse / specular scale | .8 / .3 |
| Atmosphere density / offset | .30 / .18 |
| Atmosphere color / decay | RGB 199,224,215 / 104,157,172 |
| Atmosphere haze / glare | 1.55 / .08 |
| Color grade | +.01 brightness, .12 contrast, +.06 saturation; RGB 255,248,231 tint |
| Bloom | intensity .16, size 24, threshold 1.9 |
| Sun rays | intensity .025, spread .7 |
| Depth of field | Disabled for gameplay readability |

Baseplate, paths, field beds and most rock/foliage faces use SmoothPlastic for clear low-poly color instead of stretched legacy textures. Machines use dark Metal with mint/amber detail. Small light strips use Neon; the bloom threshold keeps broad surfaces from glowing. Physics never depends on visual pulses.

### Dressing locations

- Three shallow cosmetic mineral pools: (−113,−72), radius 10; (−2,3), radius 9; (51,27), radius 15. Pale circular banks and darker teal water are noncolliding; these are decoration, not an ore source or swim system.
- Parts-built trees and reeds frame field edges, leaving mining space and trails clear. The 19 authored map-tree coordinates and per-biome colors are listed in `World.initialize()` under `trees`/`foliage`.
- Original two-part southern trees remain the original objects. Runtime grounds them after removal of the old stair experiment and scales height to at most 18 studs, preserving proportions.
- Fourteen foreground layered outcrops and eleven distant ridgeline groups frame the route. Their exact `x,z,w,h,d,yaw` tables live under `rocks` and the following ridgeline loop. Chalk caps and sloped talus break up the silhouette.
- Three stepped survey monoliths near (140–154, −74…−64) mark the far edge. These are scenery; the enemy body always uses the original construct.

## Runtime hierarchy and preservation

```text
Workspace
  Baseplate, SpawnLocation, Converter, construct, original trees
  MiningAway
    Map                 -- depot, trails, outcrops, pools, trees, reeds, gate
    Fields
      Quartz/Ruby/Cobalt/Violet/Emerald
        Field           -- collision + selection part, FieldId/Patch attributes
        Wayfinding      -- grounded sign
        Pyramid_N       -- guarded fields only; original construct clone
        Crystal / ...   -- resource parts with authoritative IDs/stages/times
    Drones              -- authoritative logical drone models/attributes
    Resources, Turrets  -- reserved folders; actual nodes/guards belong to field models
  MiningAwayPresentation -- client-local views and bounded effects only
ServerStorage
  MiningAwayOriginalReference -- moved experiments + removed legacy decals/textures
  OriginalConstructTemplate   -- full original including editor history
```

The original `construct` uses `bottemseg`, `lowerseg`, `upperseg`, `topseg`, `eye`, `eyecase`, `spawnEye`, `basepart` and its live rig. Preserve the exact spelling `bottemseg`. Seven mesh IDs and original transforms are recorded in `../review/ORIGINAL_GEOMETRY_AND_LAYOUT.md`. Only cloned live guards omit redundant `AnimSaves` editor history; source history remains.

Old `FaceTest`, `Test`, `sphere`, `Mesh`, `Crystals`, `MiningEffect`, `Beam`, `Cat`, `potato`, unnamed top-level `Part` experiment blocks, and legacy surface decals are archived, never erased from the source binary. The builder changes only controller source/enabled properties. It rebuilds the same original game; runtime map edits must be made in source to survive the next build.

## How to change the map

1. Change field tuning/offsets in `src/Config.lua`; original Ruby/Cobalt locations come from the base and ignore offsets.
2. Change map composition in `World.initialize()`. Update this coordinate table and any affected trail endpoints/sign shoulders.
3. Keep depot interaction distances, the radius-10/+7 follow formation, crystal overhead +10 station, arrival gate, guard exclusion radii and command range in mind.
4. Compile and run domain/server tests, rebuild, then inspect actual Studio collisions, line of sight and readability. A coordinate table cannot establish those checks.
5. Record observed results in `../review/ALABASTER_UPGRADES.md`. See `../STUDIO_ACCEPTANCE.md` for outstanding two-player/late-join and persistence checks.
