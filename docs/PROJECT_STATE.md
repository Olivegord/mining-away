# Shared project context

Last substantive handoff: **November 8, 2026, America/Los_Angeles**. Read this with [owner requirements](OWNER_REQUIREMENTS.md) and [AGENTS.md](../AGENTS.md). Later verified changes should update this file, not create a competing project.

**Current implementation:** DRONEREVOLUTION uses the sunset, sky, checker floor, block grove and crystal mesh copied from the owner's open **mining away**. The four permanent starter miners travel and work like the reference; a click on the bare field sends the crew to separate rocks and keeps them working. The shared Quartz pack, upgrade and prestige loop remains. See [the parity handoff](review/MINING_AWAY_PARITY.md).

## Identity and delivery state

| Item | Exact value | Verified meaning |
| --- | --- | --- |
| Shared GitHub repository | `Olivegord/mining-away` | Existing repository; the owner requests public, shared access. No replacement repository or fork. |
| Integration branch | `codex/restore-feel-prestige` | Current code, native game and handoff. `git log -1` identifies the exact checkout revision. |
| Canonical editable file | `build/DRONE_GAME.rbxl` | This actual native file is tracked, including its authored map. |
| Native-file SHA-256 | `d69a8b3eb7c1f577afa1d02bc940212d746b3b7bdb97e655cc8785ac80e909a0` | Reference art and updated managed Sources; all 50 existing Source slots preserved. |
| Installed Edit revision | `git log -1 -- build/DRONE_GAME.rbxl` | The parity implementation commit; [seven actual Edit hashes](review/mining-away-native.json). |
| Shared Roblox experience | **DRONEREVOLUTION** | Place **124078027733625**, universe **10774898335**, owner OliveGord. |
| Roblox collaborator | **MideDibber** | Playtest and Edit both checked in Creator Hub on November 6. |
| Older separate experience | **Drone Blower revolution** | Place **136098934779395**, universe **10773006567**. Historical capture provenance, not the sharing destination. |
| Open Mining Away reference | **mining away**, place **14302916915**, universe **4945273529**, loaded version **1229** | Reference inspected in Edit; no changes saved to it. |
| Local association | `game.PlaceId == 0` when inspected | A filename is not proof of association with any cloud experience. |
| Shared Studio entry point | **Current in shared Edit, November 8, 2026** | The Mining Away transfer is installed in the exact shared place/universe. All seven managed Sources match the canonical snapshot by SHA-256; all three roots are `SyncedAsRoot`. The temporary crystal inspection was removed. Studio remains in Edit. Loaded version 90 is not publication evidence. |
| Roblox publication | **No publication for the Mining Away transfer** | The last documented publication receipt is v43 for `8e7ddaf688c7abf5db32b5cb7336425b919453db`. The current public release was not independently checked in this pass. |
| GitHub write invitation | **Pending the friend's GitHub username** | Roblox username/permissions are not GitHub identity/permissions. Public viewing does not grant push access. |

[DRONEREVOLUTION](https://www.roblox.com/games/124078027733625) · [verified collaborator page](https://create.roblox.com/dashboard/creations/experiences/10774898335/permissions) · [review PR](https://github.com/Olivegord/mining-away/pull/1)

## Earlier follow-up — packs include their reward; one shared upgrade pool

Both counters open the same bright upgrade shop. Packs cost 20/27/36/49/66… Quartz and include one of three server-generated choices. A Legendary pack always offers at least one useful Legendary upgrade, even when buying the pack leaves zero Quartz. Each new pick grants one copy, and duplicates merge into 2×/3× rows. There is no three-upgrade ownership cap. Buy another owned copy for 20/34/58/98/167… Quartz as its count rises. The 13-upgrade pool spans ordinary single-stat upgrades and rarer combinations such as Overdrive Core, Prismatic Core and Autonomous Fleet. Capped effects and strictly inferior alternatives are filtered from drafts. Individual stack limits remain.

First prestige is still 360 Quartz sold, independent of spending. It retains exact permanent drone identities, adds a mining worker and +25% base mining power, and clears the run build. Existing legacy paid offers retain their promised effects. Schema 10 migrates old profiles without discarding ownership or paid choices. Server-side saved receipts preserve payment/selection across reconnect and repeated requests.

The actual n-gon source and official Pet Simulator 99 upgrade-screen screenshots informed the pool and UI. The replacement uses light panels, dark outlines, colorful icons, count badges and green buttons. Native Interface/ShopView components were inspected in Studio Edit at 740×629 and 351×620 with a fixture profile; all labels and buttons fit. [Wide preview](review/quartz-pool-wide.jpg), [narrow preview](review/quartz-pool-narrow.jpg). The preview was removed before handoff. This was not a Play or device test.

The [passing test output](review/quartz-pool-tests.txt) covers twelve workshop groups, six mining checks, 28 persistence checks, five real production-server checks in each of two configurations using Roblox API doubles, plus actual worker-effect fixtures. A base rock takes 8.867 seconds after arrival; Power Cell 1×/2× takes 6.983/6.050, and Overdrive 1× takes 3.917. Prism damage, yield and automatic retargeting pass actual worker logic checks. Consumable/deployment/input regression checks also pass. These results show mechanical changes, not human enjoyment or native multiplayer. Prior unrelated broader fixture failures remain documented in the [superseded candidate review](review/QUARTZ_WORKSHOP.md).

Native Script Sync updated only the server/client bundles. The checked seven-Source refresh from `43daac9fa4ffc278fba9e5d99f677c1a6e359c4a` preserved every non-Source chunk and unrelated/backup Source in `build/DRONE_GAME.rbxl`. [Actual native verification](review/quartz-pool-native.json) confirms the exact shared destination, all three sync roots and all seven Source hashes against both modular inputs and the canonical snapshot. No authored map changes were made in this pass.

Studio was already open and remains open in **Edit** in **DRONEREVOLUTION**, place **124078027733625**, universe **10774898335**, loaded version **90**. The earlier Play reached **4322.6 MB**, so this task started no new Play/device run. A later externally started Play was observed after the Studio connection changed, stopped, and the exact shared Edit Sources/roots were reverified. Full native shop interaction, multiplayer and subjective fun remain unverified. The owner's normal shared Edit entry point now contains this implementation; the public release was not independently checked. This task performed no publication or access change. Canonical file: `build/DRONE_GAME.rbxl`; use the implementation commit above for reproduction.

## Earlier follow-up — platform overlap repair

On the `17b47807b14de2449c69878481164805b120e7bc` baseline, cut the six terrace turf surfaces around the mining beds. Their grass tops were only 0.025 studs below the beds. Split the hub's intersecting paths and the two garden corners beneath the decorative gravel court, keeping the original surface finishes. The original parts remain with reduced footprints, plus fourteen small surface fragments in `Map.PlatformSurfaceFill`; no instances or Sources were removed. Inset four older EarthMass blocks by 0.2 studs per side, resolve the buried Cobalt foundation edge, and stop NorthOverlook's earth from intersecting its turf. Raise the two short horizontal bridges and their worn strips by 0.16 studs to separate their overlapping ends from the adjoining floors.

All six field transforms/sizes, lighting, textures, regional colors, raised meadow patches, and the waterfront display (125 descendants) remain. The checked native save changes 22 existing part transforms/sizes and adds one folder with fourteen parts, preserving all 50 Sources and every original parent. The seven installed managed Source hashes match the snapshot, and all three Script Sync roots are `SyncedAsRoot`.

Verified 2,515 actual Edit architecture ray probes with no missing support. Twenty samples changed by at most 0.16 studs: the two bridge adjustments and removal of up to 0.08-stud invisible collision overlays below the decorative court. All other sampled heights remain within 0.003 studs. A separate scan found zero near-coplanar grass/bed overlaps across all six beds. Inspected the actual Edit map close to Quartz and from the hub overview. This is static Edit verification, not a Play, low-end-device, moving-camera or multiplayer test.

Studio was already open and remains open in Edit in **DRONEREVOLUTION**, place **124078027733625**, universe **10774898335**, loaded version **76**. The normal shared Studio entry point contains this repair; the public release was not changed or independently checked. No publication. The canonical file is `build/DRONE_GAME.rbxl`; `git log -1 -- build/DRONE_GAME.rbxl` identifies the integrated repair revision.

Reproduce from the baseline using `python3 tools/refresh_platform_surfaces.py <directory>` and [the reviewed plan](review/platform-surfaces-plan.json). Execute its generated `stage.lua` in the matching Edit map, save `shared.PlatformSurfaces.export` as `fill.b64`, run the saver without `--write`, then apply `shared.PlatformSurfaces.apply()` and inspect. After successful verification run the saver with `--write` and `python3 tools/build.py`. The stage rolls back if support verification fails. No local save dialog or publication is needed.

## Latest follow-up — livelier, restrained regional colors

Retinted the existing grass, raised patches and green foliage, giving Quartz fresher greens, Ruby warmer coral earth, Cobalt blue-green earth, Violet lavender, and Emerald pale jade/chalk. Mining beds use quieter complementary tints. Selected foliage groups blend toward a cooler green to give variation without new scenery. Every texture image, material assignment, authored transform, route, field and display object is preserved.

Advanced the sun from 08:30 to 10:15 to shorten the heavier shadows. Brightness is 2.35, exposure +0.12, with balanced cool shadow fill. Global saturation is slightly lower (+0.14 versus +0.18); the additional color comes from specific surface choices. No new lights, effects, geometry or scripts.

The checked background save changes 1,630 part colors and eight lighting properties, preserving all 50 Sources and all instance parents. It includes 36 raised patches, six beds, 30 terrace surfaces, 309 supporting turf parts and 1,249 existing foliage parts. The waterfront display retains its 125 descendants. `tools/build.py` reports no Source changes.

Studio was already open in Edit and remains open in Edit at place 124078027733625, universe 10774898335, loaded version 76. Inspected Quartz close and the six-area overview. All seven native Source SHA-256 values match the canonical file and all three Script Sync roots are connected. This is an Edit visual review, not a Play, mobile, multiplayer or performance test. No publication.

Reproduce from `f4d3b9d` with `python3 tools/refresh_lively_palette.py <directory>`. Run its generated `stage.lua` in shared Edit, apply `shared.LivelyPalette.apply()`, inspect, and rerun the Python command with `--write`. The saver permits only part colors and the specified lighting properties; it checks the baseline hash and preserves all geometry, textures and Sources.

## Earlier follow-up — rock mining and the earlier textured look

All playable fields initialize mineral rocks in both Studio preview and production. Removed the automatic Quartz Arts & Crafts and Ruby Tech activation. Their templates and the waterfront display remain. The prototype's isolated test fixture can still exercise its retained machinery without enabling it in the game. Current tool controls, persistent damage marks, health-based size, economy and the one-drone start are preserved.

Used `077b76a` (smooth grass and raised green patches, before the pale midday treatment) as the closest historical appearance reference for the owner's screenshot; the screenshot's exact originating revision is not independently known. Restored 604 surviving part appearances/newer turf finishes without reverting the island, paths or terrain. Kept the original sky and ore vein asset. The earlier 08:30 lighting has exposure +0.10 instead of +0.04 and ambient/outdoor fill lifted by 6/255. Archived the scattered motif samples, older patterned accents and added grass-gradient overlays under ServerStorage; the waterfront display's 125 descendants are unchanged.

Found a newer Studio placement of the fourteen-part original Quartz tree. Preserved its live transforms through a scoped native serialization reconciliation instead of replacing it with the older snapshot position. No other part geometry changed. All 50 Sources were preserved by the appearance save, then the seven-Source refresh changed only the server controller.

Studio was already open in Edit and remains open in Edit at place 124078027733625, universe 10774898335, loaded version 76. Inspected Quartz in Edit after the restoration and sample cleanup. Script Sync delivered the changed server Source; all seven SHA-256 values match the canonical snapshot and all three roots are `SyncedAsRoot`. The next test from the existing DRONEREVOLUTION Edit document runs the updated rock initialization. No Play, mobile or multiplayer session was started, so live ore appearance and gameplay feel remain for the owner to assess. No Roblox publication.

Core-loop checks passed in production and Studio configurations, including populated non-junk fields with the template library present in the prototype fixture. The 19 field-tool checks and 12 rock-damage checks passed; these use API doubles, not native visual playtests. `tools/build.py` verified no remaining Source changes.

Reproduce the appearance on `e1d127c` using `python3 tools/restore_reference_look.py <export-directory>`, execute its generated `stage.lua` in shared Edit, inspect the staged result, call `shared.ReferenceLook.apply()`, then run the same command with `--write`. The checked plan allows only appearance properties, three archive parent moves and the explicitly exported Quartz tree transforms. To preserve the observed tree placement, copy [the scoped tree export](review/reference-look-tree.b64) to `<export-directory>/tree.b64` before writing. Use Script Sync and `python3 tools/build.py --previous-commit e1d127c` for the Source update. Do not open an old native file as a second playable.

## Earlier follow-up — persistent tool marks and health-based size

A resource keeps up to eight distinct impact or heat marks for its lifetime. Close hits of the same kind deepen the existing mark without erasing other marks. At capacity the earlier marks stay. The server replicates the full history so another observer can reconstruct the same solid surface. Marks stay attached as a resource shrinks.

Junk and ore now use the same health-stage size rule for drone and tool damage. Sword slices and melt still change the shape of the top. Server and client use the same sizing equation and keep the resource grounded.

Verified in shared Edit at place 124078027733625, universe 10774898335, loaded version 76. An Edit fixture measured the same depth for the original dent after a second dent was added. Both marks survived resizing and reconstruction on a fresh view with the six photo decals. Removed the fixtures. Field-tool, rock-damage, core-loop and consumable tests passed, including equal-size comparisons and heat marks. No new Play or multiplayer session. No Roblox publication.

Script Sync delivered both controllers. All seven Source hashes and all three roots matched the canonical snapshot. The Source-only refresh preserved the island map and the backup scripts. Reproduce with `python3 tools/build.py --previous-commit 3982df59e023f32614a09793eab1877cfd94ed87`.

## Latest follow-up — tool marks on solid junk

Junk again renders physical tool impressions. Blunt hits press into the hit face, and heat leaves a shallow mark on top. The localized cuts use the existing client damage queue and one solid cube, with the pattern or photo decals retained. The previous hollow shell and separate interior remain removed. Sword slicing uses the existing path.

Studio was open in Play on entry and left open in Edit at place 124078027733625, universe 10774898335, loaded version 76. An Edit fixture rendered the actual daisy and motherboard templates and measured a 0.51-stud dent in both 5.4-stud cubes. Inspected the viewport, verified the motherboard kept all six decals, and removed the temporary fixtures. Rock damage, field-tool and core-loop checks passed. No new Play session, multiplayer test or Roblox publication.

Script Sync changed only ClientDroneControl. Verified all seven Edit Source hashes and the three sync roots. The native refresh preserved all non-Source data and backup scripts. Reproduce the canonical Source refresh with `python3 tools/build.py --previous-commit 96850ed8f033f318cb75ccbbbac08a74c6624ec9`.

## Latest follow-up — the island reserve

November 8 research addendum: inspected Roblox Charts with Entry-level Phone / United States selected, plus the existing shared Edit map at place 124078027733625 / universe 10774898335, loaded version 76. [The visual audit](LOW_END_VISUAL_DIRECTION.md) separates device-filtered rows from global Top Playing Now, records specific composition problems, and proposes a living maintenance-reserve direction using the existing photos. This was read-only in Studio, with no Play, native changes, publication or device benchmark. The active gameplay chat retained native/source ownership; the audit began at `96850ed` and observed its later `3982df5` revision.

The six terraces sit on a continuous island with grassy slopes, gravel beaches, rocky headlands, shallow turquoise water and an open horizon. The ocean is scenery. Archived the high enclosure and both older perimeter layers under `ServerStorage.IslandShoreArchive`. Lowered twelve existing shelf trees to their terrain. The cloud blocks and found props remain in the reserve.

Studio was open in Play when work began. Stopped the session and installed the island in Edit at place 124078027733625, universe 10774898335, loaded version 76 at handoff. The 303 protected field, route, hub and causeway samples matched, and 180 shoreline probes passed. Inspected the island from above and at the west shore in Edit. The scoped save preserved all 50 Sources and `python3 tools/build.py` verified the canonical snapshot. Studio remains in Edit. No new Play test or Roblox publication was performed.

Reproduce on `4a69c7b5c7f4174f7ab53608fd696cb481e1b02d` with [the Edit stage](../tools/studio_reserve_island.lua) and [the checked saver](../tools/refresh_reserve_island.py). Extract `shared.ReserveIsland.scenery`, `.archive`, and `.trees` to their matching `.b64` files. Run the saver with the verified baseline hash, apply the stage, then rerun the saver with `--write`.

## Earlier follow-up — the liminal nature reserve

The four-sided enclosure rises to roughly 180 studs at its tallest and leaves the original skybox visible. Six cloud-printed blocks hang low over the terraces. The installed client moves them back and forth from a shared clock. The blocks are decorative and sit at their centers in Edit.

Quartz remains a sparse meadow. Impact has dry grasses and sandstone, Ruby has repeated pine rows, Cobalt has a mushroom floor, Violet has a slate moor, and Emerald has pale chalk outcrops. Eighty-eight terrain and field surfaces were recolored. A freestanding door, oversized domino, lookout chair, maintenance dock, monitor, tiled stair and viewfinder sit along the approaches. The route and field geometry was preserved.

Studio was already open and remained in Edit at place 124078027733625, universe 10774898335, loaded version 70. Inspected Quartz, Ruby and Violet in the Edit viewport. All 174 protected ground samples matched, and 256 horizontal rays confirmed the enclosure. Ran the installed motion code against detached copies of all six native cloud blocks, including both ends of the drift and the missing-folder case. The client bundle compiled. Live cloud motion and multiplayer were not playtested. No Roblox release was published.

Reproduce with [the Edit stage](../tools/studio_liminal_reserve.lua) on `9ddcd1264ce66461a1c8d88562696d5ad987c0e5`. Export `shared.LiminalReserve.snapshot` as `scenery.b64` and `.tints` as `tints.b64`. Run [the checked saver](../tools/refresh_native_scenery.py) with `--liminal-reserve` and the previous canonical SHA-256, apply the stage in Studio, then rerun the saver with `--write`. The scenery step preserved all 50 Sources. Script Sync and the seven-Source refresh changed only the client controller Source.

## Earlier follow-up — flat junk and dropped-tool handling

Arts & Crafts and Tech junk keep their photo and pattern finishes on flat faces. This pass removed cavity geometry, including the former separate fabric, foam, cork and circuit interiors. The later tool-mark pass restored shallow dents in the solid cubes. Tool hits still damage junk, and sword slices and melting can lower its flat top. Ordinary ore keeps its existing damage geometry.

Players can click or drag over individual rocks and junk cubes to choose work. The Rock Scanner starts automatic follow-up after an explicit rock order. Five decorative border parts are now invisible in Edit and the runtime plot outlines are gone. The physical mining floors, resource spawning regions, mineral unlocks and guard encounters are retained. The themed clearings continue to run in Studio preview.

Usable clicks submit an aim point even over empty ground or sky. The server preserves a direct surface click, helps acquire nearby exposed rock and rechecks reach and cover at release. Empty swings play without using durability, thrown tools still launch, and an empty Scrap or Orbital use plays a placement pulse while retaining the item. Each tool has a palm grip and separate hold, windup, use and recovery poses for the avatar joints.

Studio was open in Play at entry. Stopped it and left the shared DRONEREVOLUTION session open in Edit at place 124078027733625, universe 10774898335, loaded version 70. Verified all five trim values, 150 unchanged ground-support samples and the Quartz viewport. Script Sync delivered both updated controllers and all seven Edit Source hashes match the native snapshot. No Roblox release was published. The last independently documented publication remains v43.

The field-tool, core-loop, rock-damage, consumable and native-file preservation suites passed. An Edit harness exercised all eight grips and pose transitions on both native joint types. Live gameplay, avatar appearance in motion, touch and controller feel, and multiplayer were not playtested in this pass.

The [checked saver](../tools/refresh_plot_borders.py) accepts only the five direct `Workspace.MiningAway.Fields.<mineral>.Border.Transparency` changes from 0 to 1. It applies the exported property values against the verified previous native hash while preserving the other properties and all 50 Sources. Use the prior commit `64beb6843798428aeb78aa6f09cc0c6e3d8c8ee2` as the exact Source baseline for `python3 tools/build.py --previous-commit`.

## Latest follow-up — Arts & Crafts and Tech

The waterfront pad has separated groups of 12 Arts & Crafts cubes, 8 Tech cubes, and 9 unassigned cubes under `Workspace.MiningAway.Map.JunkCubeAreas`. All 23 earlier samples are included. Six new 64×64 photo faces show a square chip on a green board, circuit traces, glass cartridge fuses, a fuse box, ribbon wires, and silver heatsink fins. The square crops rectify the component faces. The gumballs use one crop from Martial Bacquet's photo of a denser pile. Existing pattern scales and face assignments were preserved for all the other samples. [Sources and licenses](../assets/quarry-textures/README.md#junk-object-faces)

In Studio preview, Quartz draws its junk from the Arts & Crafts selection and Ruby from the six Tech templates under `ServerStorage.JunkCubeTemplates.Tech`. Ruby keeps its existing unlock, hardness, and mineral identity. The Tech clearing falls back to normal Ruby ore when the library is incomplete. The server dispatches jobs in both fields and keeps crew ordering monotonic between fields. The core-loop and junk-clearing checks passed in API doubles, including the Ruby unlock, template selection, crew dispatch, and Ruby reward identity.

Verified all 148 deck support samples and loaded the face assets in the actual DRONEREVOLUTION Edit viewport. Studio was open at entry and remained in Edit at place 124078027733625 / universe 10774898335, loaded version 70. There was no new native Play or Roblox publication. The checked scenery save replaced the previous display and updated the candy template while preserving all 50 Sources. Native Script Sync then installed the updated controllers and the canonical Source refresh preserved the map and backups.

Reproduce the map pass using `tools/studio_junk_areas.lua` and `tools/refresh_junk_areas.py` on the previous grid revision. Write the staged sections to `display.b64` and `tech.b64`, and write the candy asset URL to `gumballs.txt`.

## Latest follow-up — 64×64 photo textures and the Edit grid

The Gumballs cube uses a close crop of photographed gumballs on all six faces. Alphabet block, fan, aquarium, ice and key, and ticket box use photo crops or composites. Plywood and moving box use real wood and cardboard grain with added face details. See [texture sources and credits](../assets/quarry-textures/README.md#junk-object-faces).

The tan waterfront ServiceDeck has 23 anchored, noncollidable decorative cubes in a six-column grid at `Workspace.MiningAway.Map.JunkCubeLineup`. It includes all 13 Quartz junk types and 10 other authored patterned finishes. Verified all 115 deck support samples, the uploaded face images, and the grid in the actual Edit viewport. Studio was initially open and remained in Edit. The selected shared place was 124078027733625 / universe 10774898335 and reported loaded place version 70. This pass did not run Play or publish. The canonical file retains the unrelated Stud pack V1 reference, which is absent from the currently open Workspace.

The background save appended 72 instances and changed 36 face URLs, preserving all 50 Sources before the runtime name change. Script Sync installed the two updated controller bundles and all seven managed Sources matched the canonical file. To reproduce the scoped art install, run `tools/studio_junk_cube_lineup.lua` in Edit on the pre-display revision and save its staged exports as `lineup.b64` and `face-edits.json`. Run `tools/refresh_junk_cube_lineup.py <export-directory> --baseline-sha256 <verified-sha256>`, apply the stage in Studio, then rerun the saver with `--write`.

## Latest follow-up — falling junk in Quartz

Click the Quartz bed or a landed prop to order the crew. The starter miner needs no card. Up to four props fall per wave, with replenishment at two or fewer unclaimed objects and a cap of ten live objects including those in flight. The server chooses clear, supported landing spots and assigns single-object claims before flight. Crews without a job go first, with least-recently-served ordering within each active job count and up to two simultaneous jobs per crew. Recall, leaving the clearing, loss of the worker and disconnect release its claims.

The fall rotation includes the original pip, gingham, knit, timber and daisy props and the eight new native templates. Bowling-ball craters cut the shell and its inset core separately. Fabric, cork and foam interiors have separate finishes and carry through to the break debris. Collected salvage sells as Quartz through the existing converter and upgrade economy. This prototype activates only in preview on the authored quarry. The falling actors are runtime instances.

One native Play session from shared Edit, at place 124078027733625 and universe 10774898335, started with one worker and four junk objects. A normal bowling-ball remote produced one dent and a cream Fabric core in a separate client union. A normal clearing order broke the dented prop and selected another. A later batch included the suggestion box, gumball dispenser and alphabet block. Moving to the converter released the field claims, and Sell credited 25 Quartz for 25 collected units. Studio was open in Edit on entry and returned to Edit after the check. All seven native Edit Source hashes matched the generated bundles after Script Sync, with all three roots still connected. The canonical background refresh preserved the map and backup Sources. Public Roblox remains at the last verified v43.

Reproduce the API-double checks with `python3 tools/test_core_loop.py` and `python3 tools/test_field_tools.py`. These cover ready gating, late-join priority, exclusive claims, the cap, pickup and sell, and bowling-ball damage. There was no native multi-client run, visual comparison of the full fall animation across observers, or visual review of every template. Existing pickup, mining-flight and gadget regression suites also report baseline failures.

## Follow-up — textured junk cube templates

Installed eight single-part cube templates in `ServerStorage.JunkCubeTemplates` in the shared DRONEREVOLUTION Edit document. Suggestion box, gumball dispenser, alphabet block, box fan, aquarium, ice cube, ticket box, and moving box use 23 unique 64×64 face images, with six decals per cube. Plywood and cardboard use CC0 material crops. All 23 Roblox image IDs loaded in Studio Edit. See [texture sources](../assets/quarry-textures/README.md#junk-object-faces).

Studio was initially open in Play. Stopped it and verified place 124078027733625, universe 10774898335, in Edit with all three Script Sync roots reporting `SyncedAsRoot`. The checked background save appended exactly 57 instances and preserved every existing instance, property, parent, and all 50 Sources. The Quartz falling-junk gameplay Sources are integrated separately. This template pass did not start a Play session or publish a release.

Reproduce in shared Studio Edit with `tools/studio_junk_cube_templates.lua`. Save the staged export to `templates.b64` and run `tools/refresh_native_scenery.py <export-directory> --junk-cubes --baseline-sha256 <verified-sha256>` before applying the stage and rerunning with `--write`.

## Latest follow-up — grassy basin slopes and raised shelves

Added QuarryBasinFoothills: 11 broad grass slopes with solid foundations and raised plateaus, 41 grass rim caps, and 22 trees cloned from the existing native tree. Lowered three high wall sections while preserving their bottoms. Grass slopes meet outer field edges; existing tiered levels, materials, meadow gradients and selective bright patches remain. Final tree grounding lifted 12 shelf trees onto the actual visible terrain/wall crown.

All 11 slopes passed three Edit ray samples with upward normals greater than 0.70. All 412 protected bed/route samples retained their prior height. Inspected two actual Edit viewport angles. Scoped save added 417 instances and preserved all 50 Sources and unrelated properties. Studio was initially open and remains open in Edit, place 124078027733625 / universe 10774898335. No Play or multiplayer test. Public version remains v43; not published.

Helpers: tools/studio_basin_foothills.lua and tools/refresh_basin_foothills.py. Final export includes terrain-grounded shelf trees; the staging script alone precedes that final grounding adjustment. Source-refresh check via build.py refused GlobalDroneControl after concurrent gameplay build changes appeared; no forced Source overwrite was performed. The active falling-junk chat was informed and native ownership released. Its tools/build.py and src/JunkField.lua edits are outside this scenery commit.

## Earlier follow-up — softer meadow with selective bright patches

Restored the f838cce ground/earth palette rather than keeping the all-over green/orange pass. Seven of the 36 raised grass patches deliberately regain the earlier bright lime/yellow-green colors. Eighteen soft yellow-green blends fade across grass surfaces using lit SurfaceGui gradient strips; the original grass texture and physical patches remain. Global midday lighting is unchanged.

Added 204 plant groups from existing native assets: 16 tall tiered trees plus 3 tall Cobalt mushrooms, 21 small stepped trees, 30 bushes/small mushrooms, 77 grass tufts and 57 flower groups. Variable sizes and yaw, spacing reservations and planting near trees/bushes avoid uniform rows. Cobalt retains mushrooms instead of trees. Protected the mining beds, routes and station pads with placement margins; placement required five ground hits. All 204 final plant-group bottoms passed Edit ray checks within 0.65 studs. Decorative clones are anchored and have no collision/query/touch participation. Existing routes, level geometry and original models are retained.

Studio was already open in Edit and remains open in Edit, in DRONEREVOLUTION place 124078027733625 / universe 10774898335. Inspected Quartz close and wide views after the tree and gradient corrections. Verified exactly seven bright accent patches. No Play, multiplayer, mobile or performance test was run. The scoped background save appended 6,149 instances (including cloned model descendants and gradient UI), restored only the prior color properties, and preserved all 50 Sources. build.py reported no changes. Public release remains v43; not published.

Authoring helper: tools/studio_natural_meadow.lua. Saver: tools/refresh_natural_meadow.py with the f838cce canonical bytes as --previous-palette and exported scenery.b64/pops.json. Final tall-tree sizing was adjusted in Edit to preserve the originally reserved footprints. Studio export is the authoritative final geometry; fresh script generation is a deterministic starting layout rather than a byte-identical final export.

## Earlier follow-up — saturated green turf and warm earth

Re-tinted 130 grass parts, including the 36 physical patches, to saturated lime/leaf greens. Re-tinted 105 dirt, earth mass, foundation and basal cliff parts to varied brown-orange/ochre. Retained all material images, geometry, collision and 13:00 bright lighting. Inspected Quartz in the actual shared Studio Edit viewport and verified the grass tint and time. Studio was already open in Edit and remains open in Edit. No new Play test.

Saved through tools/studio_green_grass_warm_dirt.lua and tools/refresh_green_warm.py. Scope changes only Color3uint8; all 50 Sources, non-color properties and hierarchy were preserved, and build.py reported no Source change. Canonical file and shared DRONEREVOLUTION Edit entry point are current (place 124078027733625, universe 10774898335). Public release remains v43; not published.

## Earlier follow-up — clear daytime lighting and brighter colors with original textures

Moved the sun from 08:30 to 13:00, latitude 25, brightness 2, exposure 0.35, neutral ambient 190 and outdoor fill 210. Diffuse environment contribution is 0.45; post contrast is zero, brightness 0.025 and saturation 0.12. The actual sky already used engine daylight textures despite its misleading Simple Sunset Sky name; it was not replaced. Same-angle Quartz screenshots show shorter shadows and brighter shaded surfaces. Kept Realistic mode and sharp shadow edges.

The preceding color pass changed 166 surface finishes/tints: brighter colored stone faces, six mineral palettes and cream hub paths. Used gameplay screenshot references from https://www.ldplayer.net/blog/how-to-become-noob-to-pro-in-roblox-grow-garden.html and https://cellphones.com.vn/sforum/cach-choi-steal-egg-roblox . This is an interpretation of their color direction, not extracted lighting settings or a claim of exact recreation.

During work the owner imported Workspace.Stud pack V1 (320 instances including root). It contains no Lua code and was captured in the canonical file. The owner rejected copying its materials. All 222 affected foliage/bark parts were restored to their prior MaterialVariant identities; only brighter lime/amber part tints remain. Live verification found ZERO QuarryPack_* material assignments in MiningAway.Map. The two unused variants are retained but not applied. The imported reference pack itself retains its own materials. Its snapshot records placement at capture time; later manual movements were not included in this scoped foliage save.

Studio was open in Edit at entry and remains open in Edit, place 124078027733625 / universe 10774898335. Checked Quartz and hub views, then rechecked Quartz after restoring original textures. No new Play, multiplayer or traversal test. All scoped saves preserved 50 Sources, unrelated original properties and hierarchy. build.py reported no source change. Thirty-eight historical color values in the earlier stone pass required one-byte round-trip reconciliation; larger differences are rejected. Shared Edit has the new lighting and final textures. Public Roblox is still v43; not published.

Reproduction helpers: studio_quarry_color_world.lua / refresh_quarry_color_world.py; refresh_clear_day.py; studio_pack_palette.lua / refresh_pack_palette.py for the imported reference snapshot; refresh_pack_colors_only.py restores the rejected material experiment using the pre-pack native revision 077b76a. Do NOT rerun the pack material stage without the restoration step; it is rejected behavior.

## Earlier follow-up — earlier smooth turf material and raised patch slabs

Corrected the previous misunderstanding: 130 authored grass parts now use the earlier grass.png image 118972165990804 at a 17-stud organic tile scale, replacing grass-short.png 134439792116456. Three dedicated MaterialVariants preserve the existing Grass, Concrete and LeafyGrass base materials. The reference screenshot's precise asset identity cannot be established from pixels alone; this is the retained earlier grass image in the project's own provenance, visually checked against the desired smoother appearance.

All 36 green patches are now solid slabs raised 0.22, 0.32 or 0.42 studs above their underlying turf, with collision, ray queries and shadows enabled. Their colors and locations are retained. Brighter lighting is unchanged. Inspected the actual Quartz Edit viewport at a lower angle to check the smooth grain and shallow physical edges. Verified all 36 patch sizes, flags and image IDs in Edit. No Play traversal or multiplayer test was run.

Studio was already open in Edit and remains open in Edit, in the exact shared DRONEREVOLUTION place 124078027733625 / universe 10774898335. Background save through tools/refresh_soft_turf.py preserved all 50 Sources, unrelated properties and existing hierarchy; build.py reported no changes. Authoring script: tools/studio_restore_soft_turf.lua. Canonical file is current; public release remains v43 and was not published.

## Earlier follow-up — restore original grass grain

Disabled 52 added grass Texture overlays (36 patch fine-grain overlays and 16 broad turf overlays). The original grass ColorMap 134439792116456 is visible again; rectangular color patches, palette, lighting and gravel are retained. Applied to the exact shared DRONEREVOLUTION Edit document and saved to the canonical native file using tools/restore_grass_grain.py. Studio was already open in Edit and remains there. Inspected Quartz in Edit; no new Play test. Scoped save preserved all 50 Sources, hierarchy and unrelated properties; build.py reported no change. Public Roblox remains v43, not published.

## Earlier follow-up — rectangular meadow layers and fresh daylight

Added 36 broad rectangular turf patches across the authored ground, with varied greens and independent texture offsets. They preserve the original fine grass material and sit only 0.055 studs above the turf; all are noncollidable, nonqueryable, nontouchable and cast no shadows. Their placements passed five ground samples each before authoring. Six biome turf palettes and the hub now use fresher greens; existing cross flowers use stronger yellow, pink, cyan and coral. Reduced the broad grain opacity so it does not obscure the patch boundaries.

Consulted Roblox's global lighting and ColorCorrectionEffect documentation and searched gameplay references for Grow a Garden and Steal an Egg. Changed brightness to 2.6, exposure to 0.04, neutralized the warm top shift, reduced environment diffuse/specular contribution, and adjusted cool ambient fill. Kept the 8:30 sun direction, Realistic mode and 0.04 shadow softness. These are this project's authored settings, not claimed settings extracted from either referenced game. Sources: https://create.roblox.com/docs/environment/lighting and https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect .

Studio was already open in Edit at entry and remains open in Edit. Inspected actual Quartz and hub screenshots in the shared DRONEREVOLUTION document (place 124078027733625, universe 10774898335). Verified 36 patch parts and their physics flags in Edit. No new Play, multiplayer or mobile test was run. Background save changed 148 surface tints, 42 lighting/texture properties and appended 89 instances; it preserved all 50 Sources and all unrelated existing native properties. build.py reported no Source changes. Shared Edit is current; public Roblox remains v43, with no publication performed. Reproduction: tools/studio_quarry_meadow.lua and tools/refresh_quarry_meadow.py.

## Earlier follow-up — brighter reference treatment and visible Quartz tree

The owner rejected the prior look. At entry Studio was already open in Play; the actual Client had the courtyard and its previous lighting (brightness 1.78, exposure -0.055), so missing installation was not the cause. Stopped Play and edited the same shared DRONEREVOLUTION document (place 124078027733625, universe 10774898335).

Raised brightness to 2.3 and exposure to 0.10, lifted ambient fill, reduced post contrast, increased saturation slightly, and pushed fog onset from 85 to 260 studs. Kept the morning direction and sharp 0.04 shadow edges. Made all 27 secondary ground layers stronger and broader with separate grass/gravel tints. Enlarged the tiny Quartz stepped tree by 1.85 and moved it out from beside the tall tree into clear grass at (-126, 78). Corrected an intermediate yellow gravel tint and tree/prop overlap after inspecting screenshots.

Inspected the final Quartz Edit viewport. This is an incremental reference correction, not a verified pixel-perfect recreation or owner acceptance. No new Play or multiplayer test was run. The checked scoped saver preserved the hierarchy, every unrelated native property and all 50 Sources; build.py confirmed seven managed Sources unchanged. Studio remains open in Edit. The shared Edit entry point is current; the public release remains v43. Reproduce using tools/studio_quarry_sunshine.lua and tools/refresh_quarry_sunshine.py; their JSON export records exact before/after properties and parent anchors for duplicate-named texture carriers.

## Earlier follow-up — courtyard color and layered ground

The hub now has an olive grass border around gray gravel, with a rose-colored focal block, bright fired brick, plaid, smaller stepped trees, and cross flowers. Each field has its own turf, earth, and mining bed tints. Seven stepped trees and sixteen flower groups give the hub and clearings more color. Cobalt retains its mushroom canopy. A translucent texture layer uses wider tiles and offset coordinates over the finer base grain. The 27 grass and gravel layers are decorative and leave the authored ground and route geometry intact.

Lifted ambient fill, reduced post contrast and lower lamp brightness preserve the sharp 0.04 shadow edge with calmer light and shade. Inspected the hub and Quartz in the shared Studio Edit viewport. The background save preserved all 50 Sources and the original hierarchy. Studio was returned to Edit before installation, and this revision was not run in Play. The last verified public Roblox release is v43.

## Earlier follow-up — sharper quarry shadows

The authored Lighting service now uses Realistic lighting and shadow softness of 0.04. Global shadows, lighting quality priority, and the 8:30 sun direction retain their prior settings. The same Quartz camera angle in Studio Edit showed sharper outlines under the trees and cubes.

The scoped background save changed only the two Lighting properties and preserved all 50 Sources. A fresh Studio Play session from the shared entry point reported Realistic lighting, shadow softness of 0.04, an 8:30 sun, and all 69 motif props on both server and client. The canonical file was saved atomically during that test and its SHA-256 still matched the lighting revision. Studio was already open and was returned to Edit. The Play viewport and lower graphics levels were not visually checked. The last verified public Roblox release is v43.

## Earlier follow-up — visible quarry motifs

Sixty-nine decorative accents across the hub and all six fields include 15 gingham inlays, stars, daisies, pips, blue waves and knit, and gold studs, alongside the existing brick and timber. Eight original 64×64 tiles are checked into the repository with their generator and Roblox image IDs. The largest patterns face the spawn and field approaches. The props have no collision, touch, or ray-query participation, and their footprints clear the mining beds, walkable routes, lagoon crossing, and station pads.

All eight images preloaded successfully in the shared Studio Edit document. The hub and Quartz approach were inspected in the viewport. The scoped background save preserved all original instances and all 50 Sources. Studio was already open and was left in Edit. No Play test was run. The last verified public Roblox release is v43.

## Earlier follow-up — continuous ground and original detail

The owner rejected the sparse block pass because it removed detail while leaving jagged, overlapping turf. Fifteen flat slabs now form the six mining terraces. Extensions meet at the same height, with the original elevation changes at the ramps and clear terrace edges. Selected copies of 53 original details return trees, flowers, brush, rocks, and the authored blue trumpet and coral mushrooms. Fourteen small patterned accents provide color beside the quieter grass and gravel. The replaced ground and prior props are preserved in `ServerStorage.QuarryGroundArchive`.

Inspected Quartz from the angle that showed the original ground problem. In Edit, 735 ground samples and 100 samples on either side of same-level joins passed. All 629 protected field, route, and lagoon crossing probes matched their previous ground hits. The two landings of each of the eight routes were within 0.32 studs of their corresponding route ends. The background save preserved all 50 Sources. Studio was already open and was left in Edit. No Play test or performance measurement was run. The last verified Roblox publication is v43.

## Earlier follow-up — sparse block quarry

Seven rectangular landforms replace the faceted interior terraces. The outer walls keep their lower grass benches and open more of the skyline. The hub and all six biomes use a few widely spaced blocks and patterned pavers, with five simple mushrooms in Cobalt. Selected original trees, flowers, rocks and shop fixtures remain. Quartz uses a cooler, finer gravel and 88 existing turf surfaces use the quieter grass finish. The open map went from 12,837 to 2,365 BaseParts. Older scenery is recoverable from `ServerStorage.QuarryBlockscapeArchive`.

Studio was open and in Edit at the start and handoff. Inspected the Quartz and Cobalt clearings in the Edit viewport. All 629 ray probes over six mining fields, eight established routes and 31 lagoon causeway slabs matched the prior ground hits. The work changes the optional outer terrain. Walking, performance and multiplayer were not playtested. The background save preserved all 50 Sources. The last verified Roblox publication remains v43.

## Earlier follow-up — visible accents at spawn and field approaches

A cyan wedge and amber discs frame the view from spawn. Each field approach has a larger abstract shape. Quartz has a coral dotted block, a round crown with mint stippling, and a lime fan crown with ribs. The palette uses the existing 64×64 tiles.

The Quartz approach was inspected in Studio Edit. All 71 added parts are anchored and decorative, with projected clearance around every mining bed and authored walkable route. The background save added only the new group and preserved all 50 Sources. Studio was already open and remained in Edit. This pass did not run Play or performance tests. The last verified Roblox publication remains v43.

## Earlier follow-up — abstract colors and foliage shapes

Thirty abstract accents bring striped slabs, dotted cubes, offset discs, patterned squares and wedges to the six biomes and hub. Nine new trees use rounded leaves, fans or needle tiers. Cobalt keeps its mushroom canopy. The pass changes 1,415 existing foliage surfaces and 95 ground or rock surfaces. Six new material variants reuse the existing 64×64 color tiles at different scales.

Quartz was inspected in the existing Play preview. The final Edit audit confirmed seven accent groups, 171 anchored noncolliding parts, six variants, and the current positions and finishes of sampled trees. The checked background save copied in the Quartz and Impact woodland branches to retain their Studio placements and stored the previous copies in ServerStorage in the canonical snapshot. All 50 Sources were preserved. Studio was already open and was returned to Edit. Performance and full-map Play behavior were not tested. The last verified Roblox publication remains v43.

## Earlier follow-up — longer biome transitions

Seven extensions add 35 shelves to the six biomes, including two branches for Cobalt. The longest branch of each biome covers 75–93 studs between shelf centers. Quartz carries smaller broadleaf and evergreen trees, Impact has ochre ground and broken rock clusters, Ruby steps down through dark fins and rust loam, Violet uses split slate benches, and Emerald uses grass-capped chalk. Cobalt adds 30 scaled copies of the existing mushroom models. Each branch tapers from four or five forms on its first shelf to one on the far shelf.

Inspected the Cobalt and Emerald transition in Studio Edit and verified all 30 caps are upright. All 28 new shelf joins overlap, with adjacent heights differing by at most 0.74 studs. All 549 clearance probes over the six fields, eight established routes, and 31 lagoon causeway slabs passed. The background save added only the new scenery and preserved all 50 Sources. Studio was already open and remains in Edit. Walking and performance were not playtested. The last verified Roblox publication remains v43.

## Earlier follow-up — stepped block rim and tapered woodland

The five outer wall runs use 382 rectangular parts with staggered columns, inset stone courses, and broad grass benches. The seven existing interior terraces and south outlet remain. Tree spacing increases across the outer shelves. Quartz has 13 close trees, six on the middle shelves, and four on the outer shelves from the woodland pass. All five former rim sections and 47 thinned trees were moved to ServerStorage for recovery.

Inspected the Quartz clearing and its background walls in Studio Edit. All 270 clearance probes over six mining beds and eight established routes passed, and the new wall clears the positions of the 75 retained woodland trees. The background save preserved all 50 Sources. Studio was open at the start and remains in Edit. No runtime or performance test was run. This revision is saved locally. The last verified Roblox publication remains v43.

## Earlier follow-up — taller and denser woodland

Five new forest shelves extend Quartz, Impact, Ruby, Violet, and Emerald. The Quartz clearing has 39 new trees with staggered rows and taller crowns behind them. Across the quarry, 122 broadleaf and evergreen trees use the existing authored models and low-resolution materials. The tallest new tree is about 59 studs. Cobalt's mushroom grove has no ordinary trees. The trees are decorative and have no collision.

The Quartz canopy was inspected in the shared Studio Edit view. All 270 clearance probes over six mining beds and eight established routes passed. Raycasts found ground joins with less than 0.65 studs of elevation change on all five new shelves. The scoped background save added 2,588 instances and preserved all 50 Sources. Studio was already open and was left in Edit. Play movement and performance were not tested. The local integration branch records the revision, and the last verified Roblox publication remains v43.

## Earlier follow-up — walled quarry basin

Five connected rim sections frame the quarry in dark rock, with a lower gap at the south outlet. Seven terraced landforms sit closer to the fields. Their green caps and moss lips alternate with deep blue rock faces. Broad olive, lime, and jade patches run across the ledges and into 88 existing turf pieces. The scenery is authored in the shared Edit document and mirrored to the canonical file with the background saver. It adds 4,014 anchored terrain facets across 12 groups, with the highest crest around 197 studs above the world origin.

Inspected the result in Studio Edit. All 270 clearance probes over six mining beds and eight established routes passed, and three sampled joins from Quartz and Impact onto the lower shelves were continuous. The scoped save preserved all 50 Sources. Studio was open at the start and was left in Edit. This pass had no new playtest or performance measurement. Roblox remains at v43.

## Earlier follow-up — drone silhouettes and selective texture contrast

All 14 roles now use visible, tool-specific hulls over their preserved rigs. The starter miner is rounded, the seeder is a wedge, the breaker carries a cylindrical ram, the orbital relay uses a dish, and the courier has an open sling. Existing specialist joints and timings are retained. Painted panels and ribbed metal use the quarry photos at drone scale. Solid fragments inherit their ore finish; energy, glass and smoke retain distinct treatments. Card previews, company deliveries and small scrap miners use the same hull builder.

Quartz has the rougher warm field finish; eleven turf parts bring back richer grass variation. Quartz, Cobalt and Impact ore use strong veins while the other fields keep satin veins. The Quartz contrast mix was seen in the native Edit viewport, and the drone silhouettes were inspected in a temporary Edit lineup that was removed immediately. All 14 final rigs constructed with matching material variants in Studio; seven managed Sources matched both Studio and the saved file. The specialist/logistics, beam and core loop suites passed with API doubles. No fresh Play session, in-motion visual check, mobile test or multiplayer test was run. The update is locally committed; Roblox remains at v43.

## Earlier follow-up — quarry depth and background saves

Ruby has a continuous distant escarpment behind its original near outcrops. Cobalt extends onto connected outer forest shelves, with 16 additional canopy mushrooms and 48 smaller mushrooms. Four ordinary trees and three bushes were moved out of the playable forest and preserved in ServerStorage. Eighteen other authored trees were enlarged. Emerald has a deeper chalk backdrop and shoreline canopy; Violet has a separate slate ridge. Shared stone accents, gradual ground tints, and muted Ruby loam connect the approaches. Six fields now have patterned props or pavers.

The background save merged Studio's native binary scenery and material exports into `build/DRONE_GAME.rbxl` and verified 337 scoped part edits, seven archive moves and all 50 Sources, with no Studio file dialog. The shared Edit viewport was inspected at Quartz, Ruby, Cobalt and Emerald. All six original mining beds matched their baseline transforms and collision; 39 ground rays checked the new forest connection, and all 31 Emerald causeway slabs remained collidable. Both new 64×64 textures loaded. Studio was already open and was left in Edit. No fresh Play, mobile, multiplayer or performance check was run. Roblox remains at v43.

## Earlier follow-up — softer grass and distinct surface patterns

The noisy, high-contrast grass was replaced with a short olive turf photo grade. Organic tiling and a smaller 10–12 stud tile soften the repetition. Five mining beds use a tighter gray pebble pattern with individual field tints; Emerald retains its light chalk bed. Cliffs and common stone use broader, softer marks; paved routes keep visible joints and the market and station pads keep their stronger patterns. Cubic ore retains its polish and roughness map with quieter vein contrast. All six new diffuse files are 64×64; [the texture library](../assets/quarry-textures/README.md) records the 32–64 px range, sources, and reproduction command.

The shared desktop Edit viewport was inspected at Quartz before and after the changes, and all six new Roblox images returned `Success` through Studio's image preloader. The saved snapshot passed `python3 tools/build.py`, retained all 50 Sources, and matched the old native hierarchy and semantic object references. Studio confirmed the same transforms, sizes and physics for all 6,574 authored quarry parts, including six collidable mining beds. The live collaborator panel showed only OliveGord, and the integration branch had no newer remote commits when checked before editing.

At `2026-11-08T03:24:52Z`, Studio logged `Publish succeeded for placeId 124078027733625`, `Published new changes in "DRONEREVOLUTION" to Roblox.`, and `Add publish notes to v43`. A post-publish audit of the shared Studio entry point found the new material IDs and tints, verified all seven managed Sources and three `SyncedAsRoot` roots, and confirmed place **124078027733625**, universe **10774898335**, in Edit mode. The open session still reports its originally loaded `game.PlaceVersion` of 26; the publish receipt identifies v43. Studio was already open and remains open. The existing Play session was stopped; no fresh Play session, runtime ore appearance check, mobile test, or multiplayer test was run for this pass.

## Earlier follow-up — visible fog, readable textures, and current Edit Workspace

The v39 Atmosphere was too subtle at quarry distances. Its instance is preserved in ServerStorage and the map now uses blue distance fog from **85 to 440 studs**, tuned in the existing Play session after a 42–300 draft washed out landmarks. The bundled sun and fixed morning clock remain. Seven [photo grades](../assets/quarry-textures/README.md) separate warm cliffs and gravel from cool paving, moss, softer tree foliage, and scarlet Ruby ground. Four market surfaces use herringbone, three service pads use worn checker, and the broad hub and mining beds stay visually quieter.

The [composition pass](review/QUARRY_COMPOSITION.md) enlarged Cobalt's canopies and Ruby and Emerald's cliffs, added visible lanterns and connected Emerald's lagoon with a stone crossing. These changes were authored in the **shared Edit Workspace** and exported to `build/DRONE_GAME.rbxl`. `QuarrySceneryAuthored` prevents a second scenery build on server startup while retaining the material registry for runtime ore and debris. The original six mining beds remain collidable and unchanged in size and position. The authoring rule is in `AGENTS.md`.

The combined desktop Edit viewport showed the sun, visible separation between near and distant scenery, the textured ground, and the landmarks. Studio confirmed all nine new texture assets loaded. The lagoon contains terrain water, and 31 collidable slabs connect to the far bank; a terrain ray immediately beyond the last slab hit within 0.3 studs of its top. The final Ruby tint and jagged crowns were inspected in Edit. The full final revision was not restarted in Play after the single comparison session; multiplayer, mobile and performance were not measured. Core-loop checks passed in both configurations using API doubles.

All seven managed Sources matched the shared document after native Script Sync, and all three roots reported `SyncedAsRoot`. `python3 tools/build.py` verifies the canonical export and the saved document retains all 43 unmanaged Sources. At `2026-11-08T03:13:00Z`, Studio logged `Publish succeeded for placeId 124078027733625`, `Published new changes in "DRONEREVOLUTION" to Roblox.`, and `Add publish notes to v42`. The post-publish audit verified the same place and universe, seven Sources, six collidable mining beds, seven patterned surfaces, and 29 scoped native properties. Studio was open at the start and remains in Edit mode. Its originally loaded `game.PlaceVersion` remains 26; the receipt identifies the published revision.

## Earlier follow-up — brighter morning and matte quarry surfaces

The authored quarry uses soft morning lighting at **8:30**, a blue sky with Roblox's built-in sun, and pale distance fog through its Atmosphere. Open shadows and gentler contrast keep the nearby paths and mining fields readable. The old startup clock script is preserved and disabled in Lighting. The game no longer regrades this authored map at startup; Edit and Play use the same native lighting. The separate reference-layout fallback is unchanged.

Three [roughness maps](../assets/quarry-textures/README.md) cover 18 scenery variants. Dirt, gravel and foliage get the driest finish; weathered stone, wood and paving are slightly smoother; diamond plate retains some sheen. All three new images returned `Success` through Studio's image preloader. The existing polished ore and its vein roughness are unchanged.

The v37 baseline matched all seven Sources in the selected shared place and all three Script Sync roots reported `SyncedAsRoot`. The new server Source arrived through the same roots. `python3 tools/build.py` verifies the canonical Sources, and `python3 tools/test_core_loop.py` passed in production and Studio configurations using API doubles. The desktop Edit viewport rendered one unobstructed sun from spawn at about 34° elevation. No new Play session was run; the full textured scene in Play, mobile graphics, and multiplayer appearance were not tested during this pass.

At `2026-11-08T02:45:05Z`, Studio logged `Publish succeeded for placeId 124078027733625`, `Published new changes in "DRONEREVOLUTION" to Roblox.`, and `Add publish notes to v39`. The post-publish audit confirmed all seven Sources, the 61 scoped native properties, healthy Script Sync roots, and Edit mode in the same place and universe. The open document's loaded `game.PlaceVersion` still reports 26; the publication receipt identifies the live release. Studio was already open and remains open.

## Earlier follow-up — in-use effects, tools and useful upgrades

Orbital now aims for 2.4 seconds with a thin red sight and a rock-sized circle. The strike column remains at ground level while its sparks track the melting rock top. Gridcutter scores the rotated rock and ejects nine textured pieces; Halver separates two wider chunks and the sword divides its detached slice into six. Specialist warmup carries into the first work gesture. Rock contact waves and debris scale with their source. Temporary deployed gadgets only spend their charge once a hit is accepted.

Starter packs avoid guard-only upgrades until the player can prepare for a guarded field. The pack still offers three saved choices and allows one selection. Cobalt's old discount purchase now gives 25% ore yield per level; free packs stay free and old purchase levels carry over. Shops explain missing minerals or required drone types and refuse purchases that are already at their effect cap. [Effect and economy review](review/EFFECTS_AND_ECONOMY.md)

Before exporting, GitHub's integration branch matched `1106fdb` and the open shared document matched all 12 disk Sources, including the five unmanaged extras. Native Script Sync delivered the three changed Sources with all roots `SyncedAsRoot`. The final `(bytes, rolling fingerprint)` pairs, using seed 0 and multiplier 131 modulo 2147483647, are `(491168, 200801960)` for GlobalDroneControl, `(554556, 1982382348)` for ClientDroneControl and `(4851, 624427711)` for DroneRoleEffects.

The quarry chat published the verified combined document at `2026-11-08T02:35:44Z`. Studio logged `Publish succeeded for placeId 124078027733625`, `Add publish notes to v37`, and `Published new changes in "DRONEREVOLUTION" to Roblox.` A post-publish audit confirmed all the same Sources and roots, place **124078027733625**, universe **10774898335**, and Edit mode with one connected Studio user. The open document still reports its loaded `game.PlaceVersion` of 26; the log records the new live version. Studio was open initially and remained open.

Server/client compilation, the specialist and beam timelines, consumables and hazards, core loop in both configurations, shop logic and persistence passed. The update was installed and published without a new native test loop from this chat. Full effect appearance, mobile, multiplayer and listening quality remain unverified.

## Earlier follow-up — connected quarry biomes and polished ore

Emerald's causeway looks across a turquoise terrain lagoon framed by chalk rock formations and green banks. Cobalt has six blue and coral mushroom trees with cream rims. Ruby uses red leaf cover mixed into the green approaches and broken gray cliffs. The original mining beds, routes and rock geometry remain in place. Newly textured crowns and bark, cooler dawn fill and lights on depot fixtures and ramps restore contrast. The low-resolution ore photo adds mineral-colored veins and a roughness map. [Photo credits and asset IDs](../assets/quarry-textures/README.md)

The shared desktop Studio preview rendered the new lagoon, cliff forms, shoreline foliage, mushrooms, lights and mineral textures. The server reported actual terrain water at the Emerald basin and retained cubic resource bodies using the new ore variant in every field. The final source revision removes the secondary Cobalt basin that crowded the view and softens Ruby's red tint. Those two adjustments were checked through Source sync and compilation without another native Play loop. The core loop and specialist/logistics suites passed. Native multiplayer, mobile rendering and a full effect regression were not tested in this pass.

All seven Sources matched in the existing shared document with all three Script Sync roots `SyncedAsRoot`. Final `(bytes, rolling fingerprint)` pairs are `(486560, 1587287791)` for the server and `(546370, 1805193010)` for the client. The open document's loaded `game.PlaceVersion` remains 26. The original dawn sky, clock, and normal Studio start point remain in use.

## Earlier follow-up — photo textures, dawn sun, and ore motion

Eight CC0 photographs were resized to 64×64 and uploaded as diffuse-only textures. Twelve `QuarryPhoto_` variants live in the shared and canonical `MaterialService`. Startup applies the variants to the authored scenery, mineral fields and cubic rocks. The first Play attempt identified Roblox's restriction on writing `BaseMaterial` at runtime. Authoring the library in Studio Edit fixed startup. Studio serialized the twelve material instances for the canonical file, and the existing native import helper added them without replacing authored geometry or backup Sources. All eight image IDs returned `Success` in Studio. The renderer briefly reported that new compressed representations were still being generated, then the final Play view showed the photo textures in use. [Source photographs and asset IDs](../assets/quarry-textures/README.md)

The original sky, 7:00 clock, latitude, brightness, and atmosphere are preserved. The sun disc has an 8° angular size and the existing SunRays intensity is 0.17. Ore flies outward, falls with stronger gravity, and can home only after contact. It uses short speed-gated trails and sparse four-point glints. The reduced-effects setting suppresses those details. Fracture debris takes the same material as its source rock.

Native verification through the shared Studio entry point counted 2,079 textured terrace parts and zero legacy checker overlays. The sun disc rendered in the original sky. A normal `MineOre` order showed an enabled beam, ore impact near 25 studs/s, no homing before impact, 19 trail samples, no `Sparkles` instances, and a server-confirmed backpack receipt. The core loop, pickup, beam, temporary tools, rock damage and specialist/logistics suites passed. The old aggregate energy fixture's fracture count and the aggregate audio fixture's Luau register limit also fail at the pre-change baseline. Multiplayer, lower graphics settings, and every effect family in a live match remain unverified.

All seven final Sources matched over Script Sync with all three roots `SyncedAsRoot`. Server and client `(bytes, rolling fingerprint)` pairs were `(467554, 620832586)` and `(546353, 999504026)`. At `2026-11-08T01:38:42Z`, Studio logged `Publish succeeded for placeId 124078027733625`, `Add publish notes to v29`, and `Published new changes in "DRONEREVOLUTION" to Roblox.` The post-publish audit found the same installed Sources in Edit mode. The open document retains its loaded `game.PlaceVersion` of 26 until reopened. Studio was open when work began and remained open after Play was stopped.

## Earlier follow-up — weathered quarry textures

The existing authored map gets sandstone and slate strata, rocky cliff faces, muted grasses, paved paths, timber stalls, corroded metal, and gravel field beds. Server startup applies Roblox's built-in material textures to the live scenery and removes the 648 identified legacy checker overlays from the runtime copy. Existing contact properties are captured before changing a part's material. The canonical Edit map retains its authored geometry and source assets. Cubic ore rocks keep their shape and a subdued mineral tint. Drone hardware and courier parcels have smooth faces, and logistics overflow matches the concrete service deck.

The pre-export Git branch matched origin. The shared place opened at v25 with all seven baseline Sources matching the canonical file. Native Script Sync delivered the three changed Sources, and all seven final fingerprints matched with the three roots reporting `SyncedAsRoot`. The final `(bytes, rolling fingerprint)` pairs were `(466432, 1538555560)` for the server, `(546602, 1649114110)` for the client, and `(19914, 483666566)` for DroneConfig. Refresh the previous native snapshot with `python3 tools/build.py --previous-commit 176eb080d265311b5a5f24d7ec3b32a9fc8c9795`.

In one Studio Play session through DRONEREVOLUTION, the spawn view showed the textured cliffs, stalls, paths, and display rocks. The server found zero legacy checker overlays, zero remaining material variants, and zero studded top faces on visible terrace parts. All six field floors remained collidable, and a spawned quartz rock remained cubic and collidable. The three changed bundles compiled, and the core loop and logistics checks passed with API doubles. Visual inspection covered the spawn view on desktop. The standalone Roblox client and other graphics settings were not separately tested.

Play was stopped before publishing from the existing shared Edit document. At `2026-11-08T01:16:07Z`, Studio logged `Publish succeeded for placeId 124078027733625`, `Published new changes in "DRONEREVOLUTION" to Roblox.`, and `Add publish notes to v26`. The open document still reported its loaded `game.PlaceVersion` of 25. A final audit verified the installed Sources and Edit mode in the same place and universe, and Studio was closed to restore its initial state.

## Earlier follow-up — click the rock, heavier tools, shared hotbar

Equip a tool in slots **1–8**, then click the spot on a nearby rock. The server validates the rock, face point, range, cover, ownership and run; it retains the point through the windup. No arc preview or ground click auto-targeting. Bowling has a .44 s windup, quick downward flight and its three recoveries. Crowbar hits chip the selected face with a [Creator Store pipe impact](https://create.roblox.com/store/asset/9113500863). Jelly has a .42 s contact fuse and heat damage. The sword removes a grounded slice at the clicked height and launches the detached slab. Sledgehammer dents and chips nearby rocks. The circular tongs drop a hot steel ball above the chosen spot; contact burns the rock over 1.75 s. Orbital, molten steel, jelly and heat-producing drones share the bounded melt bands, glowing color, lower collider and top cavity.

Scrap Capsule and Orbital Laser drop as temporary hotbar items and use the existing six-bot and orbital deployments. Previously saved charges are still accessible in the same hotbar with their durable transaction rules. A fresh **Studio** playtest grants one each of the eight tools at initial spawn; production players earn drops from mining. The ore pickups now use neon mineral colors, nearby stars and glints, stronger bounded lights and a collection burst.

Validation: 15 tool/hazard logic scenarios and the core loop in both configurations pass with API doubles, including the real Studio-only starter grant, exact click bounds, delayed contact, slicer, molten steel and Orbital melt. Legacy gadget, rock damage, cascade, physical mining and five isolated pickup renderer checks pass. The aggregate pickup runner stops earlier at an unchanged ore magnet math assertion in the prior revision; this pass changes pickup appearance and leaves the ore trajectory code unchanged. No new native Play or device simulation was started. Visual feel, input and multiplayer still need a native test. Build preservation used `python3 tools/build.py --previous-commit 5f88114469dcebb914f7d454ce6643c41c1f1a68` and retained all authored map and backup scripts.

Native publication: the pre-export integration branch matched origin, and the open Studio document matched its seven Sources. An older Play session was stopped before the export. All three Script Sync roots reported `SyncedAsRoot`. New server and client length/fingerprint pairs were `(461655, 1810625032)` and `(546645, 1745913583)`. The Studio log at `2026-11-07T06:08:01Z` records `Publish succeeded for placeId 124078027733625`, `Add publish notes to v25` and `Published new changes in "DRONEREVOLUTION" to Roblox.` The same Studio entry point, universe **10774898335**, was confirmed in Edit. No Version History panel was used.

## Earlier follow-up — temporary mining tools and player damage

The second eligible drone-mined rock drops a **bowling ball**. Later breaks introduce the **crowbar** and **jelly grenade**, then vary the drop, with a six-break ceiling after the first. Drops hop out of rocks, last 75 seconds in the world, and are collected by their owner on contact into three hotbar slots with tool models and durability bars. Press **1–3** or select a slot; click to use it, use the touch action, or cycle with **LB** and use **RT** on a gamepad. The custom hotbar replaces the stock Roblox backpack interface. Existing Orbital Beacon and Scrap Capsule pockets and progression are retained. These field tools are temporary runtime gear; death, prestige and disconnect clear them without changing saved drone ownership.

- **Bowling ball:** the preview and swept server flight share a 420 studs/s² trajectory. Rock impact leaves a cavity at the contact face and throws short-lived rubble. The ball can be picked up after its first three throws, then shatters on impact after the fourth.
- **Jelly grenade:** sticks to the rock and follows its shrink; it detonates after 1.35 seconds. The explosion damages nearby eligible rocks and exposed players, including the thrower.
- **Crowbar:** twelve close-range strikes. A rejected hit does not spend durability.
- **Player contact:** ready rocks are solid and stop blocking immediately on collapse. Mining and combat beams, sentry fire, heavy impacts, and rubble can damage players. Cover, spawn shields and the depot protect players. All damage, durability, ownership, and mining rewards remain server-authoritative. Temporary tools cannot generate a drop loop or mine a locked rock or another player's reserved rock.

Verification: 11 production server tool/hazard scenarios passed with API doubles, including swept obstruction, version replay rejection, all three recoveries, grenade timing, durability, contact pickup, player damage and cleanup. Both Luau bundles compile. Core-loop checks passed in production and Studio configurations; consumables, rock cascade/damage, physical mining, client refinement and 18 canonical-file workflow checks passed. Native hotbar layout, throw and debris feel, input devices and multiplayer are unverified. No Play, device simulation, profiler or Version History was opened during this task. Reproduce the canonical Source refresh with `python3 tools/build.py --previous-commit 56c661b8a89395f8f182034238887d49c21fae52` on the previous canonical snapshot; `python3 tools/build.py` verifies a current snapshot.

The older aggregate performance runner passed its server, specialist rendering and logistics fixtures after repairs to the test setup. Its separate ordinary-fracture count assertion still fails; running that exact fixture against the unchanged pre-task `Presentation.lua` and mocks at `56c661b` reproduces the failure. No Studio performance measurement was run.

Publication evidence: the checked-out integration branch matched origin before export, no other game chat was active, and the seven pre-export Sources matched the open shared document. Native Script Sync delivered both changed controllers without a menu repair; all three roots stayed `SyncedAsRoot`. The installed server and client Source `(bytes, rolling fingerprint)` pairs were `(451525, 2070731895)` and `(556607, 1536391516)`, respectively, matching the canonical file and Git Sources above. Published from the existing Edit document for **place 124078027733625 / universe 10774898335**. At `2026-11-07T05:35:56Z` the Studio log recorded `Publish succeeded for placeId 124078027733625`, `Add publish notes to v24`, and `Published new changes in "DRONEREVOLUTION" to Roblox.` The open Edit document still reports its original loaded `game.PlaceVersion` of 18; the publish receipt identifies the released version. After publishing, the same Studio entry still contained both updated controllers and was confirmed in Edit mode. The separate historical Roblox place was not touched.

## Earlier follow-up — persistent mining outline, flat side HUD, Studio stopped

The owner rejected the preceding full-width wallet cards. The HUD is now a flat **160-pixel-wide side list**, with transparent rows, no padding panels or borders, and no permanent mining-status box. It starts with **Quartz + backpack** (160×48) and shows each additional mineral only after its corresponding area unlock. Recall/Evade remain small flat contextual controls on the side. The list sits above mobile movement controls. Physical progression prompts and visible locked-field rocks remain.

`CommandView` was creating a second `DispatchedWorker` Highlight on the same drone as its permanent outline. That competing highlight could override the permanent outline after a mining command, including once disabled. Removed the second drone highlight; accepted/queued/rejected feedback remains on the commanded rock. The permanent outline stays attached to the actual drone model. A production-client regression verifies a mining acceptance leaves exactly one enabled drone outline.

Native verification in the owner's normal **DRONEREVOLUTION** entry point: a real mining order traversed **Travel → Warmup → Mine**, with **269 rendered samples including 141 mining frames and zero outline failures**. The active mining outline was visually inspected. Initial side list showed only Quartz and backpack (160×48); a normal 80-Quartz Ruby unlock changed it to Quartz + Ruby + backpack (160×72), leaving Cobalt/Violet/Emerald hidden. Rows had no background panel or UIStroke. [Follow-up observations](review/drone-readability-followup-native.json).

All three native Script Sync roots initially entered error code 25. One explicit Resume Sync reconciled only the two intended newer disk Sources, preserving all other scripts and backups. All three roots then reported **SyncedAsRoot**. A subsequent HUD export arrived automatically with all roots still healthy. **The underlying code-25 cause and long-term unattended reliability are not established.** The owner explicitly rejected repeated menu repair; do not claim the sustainable-sync request is complete. Investigation should resume with bounded source/file-watcher diagnostics rather than repeated native menu work.

The owner then reported Studio at **4 GB RAM** and requested stopping the activity causing it. Play has been stopped; native state verified **Edit**; device simulation reset to **default**. No further native tests, profiling or menu repairs should run without renewed direction. The owner explicitly chose **Leave Studio open**. Keep it open in Edit mode; do not close or reopen it. The owner clarified that they want to understand the 4 GB idle memory use. An earlier automatic approval review rejected closing/reopening the shared document under that initial-open rule. No document was closed. The history panel was closed and the owner's permanent prohibition is recorded in AGENTS.md.

A single read-only idle memory snapshot reported **4179 MB total**, with RunService stopped and 25,144 instances. Reported tags: Internal 1067 MB, LuaHeap 643 MB, Script 244 MB, GraphicsTexture 78 MB, Instances 68 MB, Gui 50 MB. The tags do not account for the full process total. This identifies significant internal/Lua/script allocation; it does not identify a leaking plugin, prove a leak, or establish that the current map uses all 4 GB. No Play, profiler or menu was opened for this snapshot.

Canonical Source-only snapshot SHA-256: **`7ede00538cd4439d2748b0a87b408dfe8ef56c0c429d3a0f2484b39562f1d43c`**. All non-Source chunks and unrelated/backup Sources were preserved. The client refinement regression suite passes; prior core-loop, shop/profile/persistence and specialist checks remain as documented below. Latest follow-up publication is **unverified**. Remaining limits: native phone check after the final flat-list anchor, multiplayer/late join, production persistence, durable sync reliability and owner visual approval. Do not use the history panel to resolve publication.

## Drone readability, mineral visibility and station UI — latest follow-up

All gameplay drone types, display drones, company couriers, scrap bots, carriers and flying backpacks receive a clean dark silhouette outline on their actual client-rendered models. The outline is owned and destroyed with each model; it does not change geometry, movement, timing or damage. Capsules are not outlined.

The permanent HUD now contains all five named mineral wallets (Quartz, Ruby, Cobalt, Violet and Emerald) and backpack space. It uses compact dark panels and mineral accents, reflows on narrow screens, and retains contextual Recall/Evade and earned tool controls. Removed permanent Prestige, Shops, Fleet, Cards, Buy drones, next-objective and duplicate E-action panels, plus M/O menu shortcuts and clicking drones to open their roster remotely. Native prompts are the entry points: the existing Printer opens Drone yard with purchases, transport, storage, Fleet and Cards inside; Prestige has its own repaired prompt; each mineral shop opens only its own upgrades. Walking beyond a station closes its menus. The crate keeps its existing reveal/choice flow.

Locked-field rocks were explicitly hidden by the client; they are now rendered normally so the next minerals are visible goals. Unlock, ownership, line-of-sight and sentry rules remain server-enforced. Fixed station-distance mismatches: the printer's near side and far side both support purchases, and prestige validates the actual prestige station instead of also requiring the unrelated home radius.

Native single-player checks in the existing shared DRONEREVOLUTION session: five currencies visible; normal Ruby unlock/mining/converter sale paid **14 Ruby** and updated its HUD counter; a **60 Quartz** permanent Miner purchase at the printer (33.305 studs from home) added the second drone; a free Rare pack delivered, opened with one native E hold and claimed exactly one card; the real prestige prompt opened its review; menus closed after leaving and M/O stayed inactive. The final narrow viewport (515×339) had all mineral names fitting, **2/2 gameplay drone outlines**, no removed shortcut objects, and visible rocks in all five fields. Desktop (1167×653) and simulated phone (750×381) were inspected as well. Console was empty; simulator restored to default; Play stopped. See [native observations](review/drone-readability-native.json).

Production-logic checks: core loop passes nine scenarios in both production and Studio modes, now explicitly testing printer purchase and earned prestige outside the old home radius. Shop/profile/card, persistence, shop server, physical mining and client refinement suites pass. The shop harness now scopes its appended fixture to avoid Luau's 200-local limit. A stale Studio-preview assertion was updated to the already-authorized 100 starting Quartz; production still starts at zero. Native preservation verifies all non-Source chunks and unrelated/backup Sources are byte-identical to the previous canonical snapshot.

Release snapshot SHA-256: **`1eda8427de5a0926bed60d6caf623046a8dd57c7f7748f333ee91d9a04a21a40`**. All three Script Sync roots were connected; initial seven Source fingerprints matched Git before edits. No other game chat was active, and fetching origin found no newer collaborator Git revision. Publication is pending below. Limits: no native multiplayer/late-join, real touch/gamepad, production DataStore reconnect/restart or owner enjoyment approval. The independent full visual/multiplayer acceptance gate remains unverified.

## Free packs and direct purchase — latest follow-up

Packs now cost **0 Quartz** for every pack index via the temporary `Shops.PACKS_FREE=true` switch. The normal escalating/discount pricing remains behind that switch for later restoration. The native station prompt reads **Buy pack · FREE (0 Quartz)** and orders immediately on E; the intermediary BuyPack modal/button is removed. Delivery, saved/sealed choices, the continuous opening hold and choose-one card reveal remain unchanged. A pending offer and transaction quotes still prevent duplicate crates/rerolls. The client refreshes prompt price text from the server's nextPackPrice.

Studio was already open at task start and will remain open with Play stopped. All three Script Sync roots were connected in the existing DRONEREVOLUTION document. Verified sync arrival before the final fresh Play run (Script Sync can apply a file after export returns). One E press produced exactly one sealed free crate, no menu, and retained 100 Quartz. Opening and claiming a card worked; the next E press produced a second free crate, no menu, one active crate, and the same balance. The prompt used Default style and displayed the free price. Core-loop checks pass nine scenarios in production and Studio modes, including ordering with zero Quartz; all 26 shop/profile/card checks pass, including repeated free orders at pack indices 0, 10 and 1000 and preserved paid-mode discount behavior. Touch/gamepad, multiplayer and production DataStore reconnect remain unverified.

Canonical snapshot SHA-256: `eb7d2217fca91672917b9151c8e6d0d4c9cbddcad34bef61daf259169181e939`; all non-Source data and unrelated/backup Sources preserved. Source/native revision **`4f1bd48`** installed and published to existing DRONEREVOLUTION place **124078027733625**, universe **10774898335**. All seven installed Source lengths/fingerprints matched the local bundles before publication. Save to Roblox and File → Publish completed; native Version History shows **v19 Published**, version timestamp **8:02 PM Pacific November 6, 2026**, with v18 Previously Published. Studio remains open because it was initially open; final MCP state is **Edit**, with no Play/Run simulation active.

## Continuous pack slowdown — latest follow-up

The owner rejected the v16 circle restarts. The new implementation holds one native ProximityPrompt for the full rarity duration; HoldDuration never changes during the hold. A compact crate indicator uses the existing continuous weighted curve: 60%, 22%, 12%, 6% of Legendary progress over progressively longer intervals. Color boundaries do not reset input, time or fill. Native keyboard/gamepad events and native server validation remain; pointer/touch only forward button holds through InputHoldBegin/End. This uses Roblox's supported Custom prompt appearance, not a separate hold-command protocol. See [native prompt API](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt).

Installed through the three existing Script Sync roots in shared DRONEREVOLUTION (place 124078027733625, universe 10774898335). Native verification: an interrupted Common hold stayed sealed, then a runtime-only 4.8-second presentation probe recorded exactly one begin, one end, one trigger and zero fill regressions. Sampled fill rose from 64% at 0.67s to 84% at 1.60s, 95% at 2.93s and 99% at 4.40s. That probe extended an actual purchased Common crate's visible tier/duration only in Play; it was not a naturally rolled Legendary test. A card was claimed normally. A fresh Play with final Sources bought an actual Rare crate and opened it with a real pointer hold on the visible indicator. The indicator was visually inspected in Studio. All nine core-loop checks pass in both production and Studio configurations, including a single unchanged hold timestamp/duration and native End-before-Triggered ordering. Real touch/gamepad, multiplayer and production DataStore reconnect remain unverified.

Canonical snapshot SHA-256: `3519828953aeb5097658dc9a633838870c442caf4bb4fc3d1ab30f50968b8896`. Source-only refresh preserved authored map and unrelated/backup Sources. Play stopped after tests. Published source/native revision **`2ddef68`** as **v18** to existing DRONEREVOLUTION place **124078027733625**, universe **10774898335**. Native Version History shows v18 **Published**, OliveGord, **7:56 PM Pacific November 6, 2026**; v16 Previously Published. Before publication all seven installed Source lengths/fingerprints matched local bundles. Studio quit was confirmed by the app inventory after release.

## Native prompt and Script Sync — November 6 follow-up

The latest source/native-file revision is **`20b3c80`**. Installed into the existing shared Studio Edit document after exact baseline comparison. The native file SHA-256 is `21c3cba41088fbf76586b19e00b3ba593e53d4de1911e5863079c1b429fa42d8`. Publication of this follow-up is **verified as v16** in existing DRONEREVOLUTION, place **124078027733625**, universe **10774898335**. The owner replaced the obsolete chat-supplied restriction and explicitly reaffirmed publication permission. File → Publish completed; native Version History displays v16 **Published** with the 7:27 PM Pacific November 6, 2026 version timestamp and v14 Previously Published. Before publishing, the exact seven installed Source lengths/fingerprints matched the local bundles, all three Script Sync roots remained connected, and Git fetch showed no newer collaborator revision. No map or unrelated Source replacement was performed. Play was already stopped; Studio quit was observed after publication.

The custom input/progress GUI and PackHold remote protocol are removed. Server-owned native hold events validate owner, range, readiness and elapsed stage duration. A short deferred release handles Roblox firing HoldEnded before Triggered. The crate keeps the existing delivery/colors/sounds, saved offer and floating-card reveal. A real one-player Studio Epic purchase completed all three native hold stages with one continuous E hold; native event ordering and sealed-to-opened state were observed. No custom HoldToOpenPack GUI existed, and the shop prompt was suppressed. Play is stopped. The core-loop suite passes all nine scenarios in both production and Studio configurations, including unauthorized/early/interrupted events, stage timing, reconnect and one-card selection. Touch/gamepad, Legendary native playback, multiplayer and production DataStore reconnect remain unverified.

All three native Script Sync roots report SyncedAsRoot: `ServerScriptService`, `ReplicatedStorage.Shared`, and `StarterPlayer.StarterPlayerScripts`, mapped under `studio/`. A disposable `.luau` file created a ModuleScript, disk edits reached Studio, Studio edits reached disk, and disk deletion removed the instance. Existing backup LocalScripts remain disabled and the active ClientDroneControl remains enabled. Studio warns that some descendant properties are unsupported by Script Sync; it syncs scripts, not Disabled states or authored map properties. Those properties remain in the existing place and canonical snapshot. `tools/script_sync.py` exports the seven bundled Sources without opening or saving an `.rbxl`; optional `--watch` exports src changes. A conflict check preserves unknown edits. The exporter creation/no-op/conflict checks passed. Root connections are local to this workstation; other computers connect their roots once as described in COLLABORATION.md. F8 is assigned to Sync to... on this workstation.

## Standing publication permission and reconciliation

The owner grants continuing permission to publish routine updates to the existing DRONEREVOLUTION starting place until revoked. This is recorded in AGENTS.md. The shared authored map and its source adjustments were reconciled into the canonical file, including shop placement, daylight, logistics and preview positioning. The shared Studio session passed the current pack purchase, delivery, hold and claim flow with 100 starting Quartz and 60 remaining after purchase. Studio publication of revision `ef812b5` is verified as v14 at 7:09 PM Pacific on November 6, 2026. The final read-only Source fingerprint audit became unresponsive because it repeatedly retrieved large Source properties. That audit was stopped by closing the already-saved and published Studio process. Activity Monitor and the app inventory confirmed Studio closed. The final fingerprint audit did not complete; publication is supported by Version History and the shared Studio gameplay verification. The pack flow was tested through the shared Studio UI, including 100 starting Quartz, purchase for 40, delivery, hold and one selected card, with an empty console.

## What caused the confusion

Earlier instructions named the historical place as the sole destination and treated the local file and cloud titles as interchangeable. The actual current `.rbxl` was excluded from Git, so another checkout could have Sources and historical captures without the real authored document. This handoff corrects that: one tracked native file, one shared repository, explicit IDs, separate publication evidence, and a short durable context for other Codex sessions. Older review notes describe the revisions they tested; they do not override the identities above.

## What the owner wants

- A simple Roblox game with a clear **buy/sell/upgrade/prestige** loop. The newest request supersedes the earlier temporary direction away from progression.
- Directing drones, breaking rocks and collecting should feel satisfying and Roblox-like. Keep original models, segmented pyramid turret, map identity, compact colorful card UI and accepted audio/VFX.
- Cubic rocks must snap smaller, retaining orientation. Currency must arc up and away from the rock before attraction, so it is visible.
- Only one drone type may mine a given rock. Do not restore complementary-worker dependencies or factory-management complexity.
- Rocks can drop useful stored consumables, including a placeable orbital laser. Avoid substituting generic timed multipliers for meaningful actions.
- Bee Swarm Simulator is a reference for enjoyable play, not permission to copy its assets or introduce every mechanic it has.
- Do not mistake earlier ore/reward timing or cosmetic tweaks for proof of an improved core loop. Automated correctness is not proof of fun.
- Preserve the initial Studio open state: leave it open if it was already open when work began; close it after work only if the agent opened it from a closed state. Check initial state without launching Studio. Always stop Play/Run and verify Edit mode before handing back; Studio may remain open, but no playtest or simulation may remain running. Routine stop/install/save/restart and publication to the existing DRONEREVOLUTION place remain authorized. New experiences need an explicit request.

## Current implementation

An unmarked copy of the original drone delivers each paid upgrade pack between the buyer and the pack shop. The server saves the tier and the three choices with the debit, withholds the choices until the owner completes the hold near the crate, and saves the opened state before showing the cards. A reconnect redelivers a sealed pack with its original tier and choices. Previously disclosed offers remain available. The shop interaction reaches 14 studs and the landed crate hold reaches 8 studs. Keyboard, gamepad and pointer/touch now use a standard Roblox ProximityPrompt. The nearby owner crate suppresses map prompts locally so the shop cannot consume E.

| Crate | Box odds | Hold | Color progression |
| --- | ---: | ---: | --- |
| Common | 66% | 0.42 s | Grey |
| Rare | 24% | 1.32 s | Grey → yellow |
| Epic | 8% | 2.65 s | Grey → yellow → green |
| Legendary | 2% | 4.80 s | Grey → yellow → green → violet |

These timings, odds and the violet finish are tuning choices. One continuous bar fills quickly at first, then slows at each color boundary without resetting. A single native hold runs for the full rarity duration; the stock-circle restart workaround is superseded. Non-common boxes favor rarer existing cards among otherwise equally ranked offers. Cards rise from the crate when it is visible to the camera and retain the existing card effects and choice behavior. The reveal uses depth-of-field blur behind the cards.

Revision `88ba15d` connects the ordinary one-drone start to immediate selling, visible purchases and prestige:

- Converter Sell pays matching mineral wallets directly, without first filling the 120-unit launch storage.
- Mining power costs 20/40/80/160 Quartz and adds 50% base damage per level within the existing run cap.
- A permanent ordinary Miner starts at 60 Quartz and scales by 1.8 with owned Miners. Purchased drone IDs survive prestige.
- Prestige adds the existing earned drone and +25% permanent base mining power per prestige, clears run money/sales/modifiers, and retains permanent ownership.
- New Studio Play profiles start with one drone, 40 capacity and 100 Quartz for pack testing. Production profiles start at zero. Preview crews are explicit developer controls.
- Compact purchase/prestige guidance and the Buy drones action connect the UI. Two observed HUD overlaps were corrected.
- Stored Orbital/Scrap consumables, physical rock collapse interactions, snap-size cubic rocks, outward pickup arcs and one-type-per-rock behavior remain integrated.

Server owns damage, rewards, persistent state, cards, purchases and prestige. Clients render replicated intent. Preserve fail-safe persistence; a load failure must not overwrite a valid profile with defaults. See [core-loop report](review/CORE_LOOP.md), [consumables](review/CONSUMABLE_GAMEPLAY.md), [rock interactions](review/ROCK_INTERACTIONS.md), and [architecture](game/architecture.md).

## Pack Shop

The depot pack counter has its own Pack Shop sign and proximity prompt. Press E to order a crate directly; the prompt displays the price, currently FREE (0 Quartz). There is no pack purchase menu. Mineral shops continue to sell their level upgrades. The native refresh checked that all non-Source data and unrelated scripts matched the prior file. The delivery flow was played before merging the compact shop layout.

The five mineral shops now use compact upgrade tiles with a symbol, short name, effect, and one purchase or status button. Every catalog upgrade has a symbol, and field unlocks use their destination mineral color. Upgrade prices and transaction rules remain as before. Native Source preservation was verified offline. The updated shop layouts still need Studio visual and input verification.

## What was actually tested

The pack revision `eab05ef` completed a one-player Studio Play test before the shop merge. Normal mining and sale commands earned 40 Quartz, and the shop UI bought a Rare crate. Studio observed the crate grounded between shop and buyer. Releasing E early kept it sealed. A full hold advanced grey to yellow, disclosed the three cards, and showed all three card faces with world depth-of-field and transparent menu surfaces. Selecting Shard Harvester installed one card, cleared the pending offer and removed the crate and blur. The console was empty and Play was stopped. The canonical disk file was verified against the seven allowlisted Sources. The source-only refresh preserved map, other instances and backup Sources.

The core-loop suite passed in both configurations, including all four timing curves, sealed disclosure, cross-player rejection, interrupted holds, reconnect and exactly one claim. The native package/preservation suite passed. The legacy card price and HUD text assertions also fail on the baseline commit. Pack animation on touch, higher-tier visuals, listening quality, multiple Studio clients and production DataStore reconnects remain unverified. The reconciled release `ef812b5` was subsequently published as v14. Higher-tier native visual and multiplayer checks remain outstanding.

Production-logic checks covered sale transactions, purchase costs, ownership, prestige and preservation. The one-file packaging/preservation suite passed. Server/client bundles compiled.

An actual native single-player command-driven run used real mining, pickup, movement and normal command remotes: fill 40 → sell 40 → buy power for 20 → sell another 40 → buy a Miner for 60 → reach 160 lifetime sales → prestige. It retained both original owned drone IDs and added the third; run money and modifiers reset; permanent mining power increased. No money/cargo/damage/ownership grants were used. Console output was empty, Play was stopped, the canonical file was saved, and Studio was closed.

Limits: no final native multiplayer/late-join pass, real DataStore reconnect/server-restart validation, or owner enjoyment approval. The final expanded tool-pocket layout was compiled/installed but not separately played in Studio. See [native transaction observations](review/core-loop-native.json). Offline checks must never be reported as visual or multiplayer playtests.

## Next work

1. Add the friend's actual GitHub account as a collaborator when the owner supplies it. Use this shared repository.
2. For each completed game update, reconcile any newer shared-game edits, publish the canonical file to the existing DRONEREVOLUTION starting place, then record the actual published version/revision and verified destination here. Do not assume the instructions already completed this step.
3. Let the owner judge the simple loop in play. Prioritize meaningful mining and purchases over more decorative changes. Complete real multiplayer and durable-save checks before claiming those outcomes.
4. Keep Sources, the canonical native file and this handoff synchronized for every subsequent contribution. Never resolve a binary conflict by silently taking one contributor's map over another's.
