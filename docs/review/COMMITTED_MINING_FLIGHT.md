# Committed mining flight and vivid physical cards

Candidate built on `e92fcd20c5ddecd4240ccd9156b564204b38880f`, in the existing `codex/restore-feel-prestige` branch and PR #1. Existing game/place: **136098934779395**. This report supersedes older descriptions of storage freezing the entire fleet and client-side avoidance.

## Cause trace and implemented behavior

| Observed code path at the starting revision | Correction |
|---|---|
| Every courier/economy transaction and routine autosave set `MotionPaused`, then `droneStep` returned without moving. All observers froze with it. | Separate `WorkPaused` from unsafe-session `MotionPaused`. Healthy saves retain committed flight while freezing work clocks, damage, healing, planting, rewards and economy mutations. Uncertain/lost persistence still stops gameplay safely. |
| Client `BreakerImpact` assigned its position directly; `BreakerDive` assigned an analytic pose even if the phase packet arrived late. | Existing lives follow the stroke through bounded acceleration/speed and damped arrival. Only spawn/new life/death/reprint initializes a pose directly. Missing dive packets cannot teleport a living observer to contact. |
| Work flight changed caps/easing discontinuously at 16 studs; near-station pursuit and goal-facing could reverse a settled body. | One substepped damped arrival controller retains capped cruise and finite thrust, blends near-work response continuously and brakes lateral velocity. Heading follows actual horizontal velocity and holds at rest. The retained original `.03` approach/reference helpers are unchanged. This is a deliberate arrival-controller change, not a claim of exact original trajectory parity. |
| Client recomputed local avoidance from each observer's rendered crowd, on top of server steering. | Server chooses avoidance once. Clients consume its replicated offset while rendering smooth follow goals. Remove the extra per-frame client crowd grid. |
| Breaker recovery completed after `.65` seconds even when the drone was still below its overhead station. | Completion additionally requires physical return within `.7` studs and speed at most one stud/second. Separation yields near that station. No new windup while still returning. |
| Paid shell retirement discarded the manually ordered resource and sent its cutters away from the newly revealed core. | Stable-ID-ordered shell crew continues to real core/shard reservations. It still must travel, wait for actual two-second growth and warm up. This grants no unrelated plot automation or early reward. |
| Each completed node forced an idle second even with queued/automatic work. | Keep the one-second uncommanded finish, but release after `.2` seconds when next work was already requested. Explicit orders continue to cancel recovery immediately. |
| Cultivator cooldown called follow every tick between committed planting jobs. | When another replacement is needed, recover at the completed planting station instead of bouncing back to the owner during cooldown. Existing replacement-token, population, spacing, access and normal growth checks remain. |

Review caught and repaired two follow-on hazards before delivery: reapplying an already-offset goal during a yielding save accumulated steering offsets; freezing dive time while continuing flight could rewind the resumed dive. Canonical intent goals are now stored separately. A powered dive can physically finish during healthy storage, but its impact/damage waits for the transaction to finish. Repeated snapshots cannot reward it twice.

## Mining decisions and progression

Hardness stays 1 / 1.8 / 3.2 / 5.2 / 8 across the five real minerals. A cutter gains up to 35% efficiency through the exposed fracture layers. A breaker gains up to 2.5× contact effectiveness against intact high-hardness layers, tapering to base as they open; its existing 1.5× geode/core specialty remains. These are real server damage terms, not different-colored identical beams. Orbital and scrap damage do not inherit this new contact multiplier. Existing hardware upgrades, plot automation, mining while bags are full, physical pickups, couriers, shops and permanent-fleet/card progression remain.

Production-function work-only estimates for a median-size ordinary crystal, at 30 base DPS:

| Mineral | Base cutter | With +50% cutter DPS | Existing ore × sale value |
|---|---:|---:|---:|
| Quartz | 5.65 s | 3.77 s | 10 × 1 |
| Ruby | 10.13 s | 6.77 s | 12 × 2 |
| Cobalt | 17.97 s | 11.98 s | 15 × 4 |
| Violet | 29.18 s | 19.45 s | 16 × 7 |
| Emerald | 44.87 s | 29.92 s | 20 × 10 |

These exclude travel, warmup, collision/LOS, carrying/selling, missed hits, boulders, geodes and player decisions. They establish that difficulty and upgrades affect actual work. They do **not** establish full-loop pacing, a balanced economy, fun or retention. An unequipped lone cutter remains slow in deep fields; the intended choice is to develop hardware/crew, use breakers on hard outer layers, or harvest easier resources. Owner playtesting must assess those choices and numbers.

## Catch a Brainrot research and video limitation

Search distinguished the [Indieun × zv_u RPG](https://www.roblox.com/games/140063367098641/Catch-a-Brainrot) from several similarly named trap/enclosure games. Located and opened:

- [BemmyBlox — After MONTHS, its FINALLY HERE!](https://www.youtube.com/watch?v=J4T-p-EdNS8), July 10, 2026, 25:23 playback duration displayed.
- [revolver agz — Catch A Brainrot FULL Gameplay ACTUALLY LOOKS GOOD](https://www.youtube.com/watch?v=Kncx2lnfD0M), July 2, 2026, 29:03 duration displayed.

Both cloud-browser players reached the video after preroll, but remained black/buffering; the first accepted a seek to 5:04 and displayed captions/chapter text without playable visual frames. **Watching and visually analyzing the reference videos was blocked and is not completed.** No claims about observed UI motion, timing, composition or specific visual lessons are based on these inaccessible frames. Do not present this candidate as a completed Catch a Brainrot video study. A reviewer still needs to compare working footage to the candidate.

## Pack UI implementation

Retain camera-local card Parts → SurfaceGui faces → ViewportFrame original mechanic scenes and ordinary screen-space hitboxes. Keep existing reveal/hover/press, saved server choices, controller selection, touch scrolling and reduced-motion path. No rarity-driven recoloring of the HUD/world.

Nine mechanic families now have vivid distinct base/accent colors: red/gold orbital optics, violet/lime scrap swarm, teal/green scanner, blue/cyan split prism, orange/yellow cargo, green repair, magenta combat, blue thrust and purple mineral tools. Scanner and prism get new original instrument scenes; other existing scenes are recolored. Art grows from a fixed 84×56 screen-pixel preview to 88% card width and 41% height. Dark art stages, bright edge/focus accents and two text elements preserve the hierarchy: large benefit first, exact target/run duration/tradeoffs on a dark footer. There is no new uploaded art, Robux RNG or modified selection contract.

Automated text/palette checks evaluate all 45 production catalog entries, nine mechanic families, named-drone penalties and at least 3:1 base-color contrast for large benefit text. They cannot establish actual SurfaceGui sizing, wrapping, clipping, phone/controller usability or appearance.

## Two review passes

**Behavior/parity code review:** traced server movement, snapshot attributes, all-client renderDrone, reservation release/queue dispatch, warmup, shell retirement, breaker phases, grower recovery and yielding saves. Original assets/models, close overhead stations from the current live branch, quarter/larger-rock fracture behavior, two-second growth, original 2-second beam-width ramp and .2-second hide, audio, map, tactical HUD and discoveries are retained. Profile/Cards/Persistence schemas and permanent IDs/types/base traits were not replaced. Production starts with one permanent drone; the retained Studio preview crew is separate.

**Pacing/presentation/multiplayer code review:** checked the difficulty/role terms and payout path together, reservations on continuation, no work during saves, missed phase handling and deterministic steering authority. The yielding-store test executes actual server Heartbeat/persistence and two actual renderer bodies plus a late observer. It uses API doubles, not Roblox transport, engine physics or real DataStore service. No independent engine art-direction approval was possible.

## Reproduction and acceptance

Pinned official Luau **0.744**, ZIP SHA-256 `6506f0852c623aaffcb28494aac16c26dc04a269ea0e16cc0aafc8c8ac79f3ec`.

```sh
python3 tools/test_shops.py /path/to/luau
python3 tools/test_gadgets.py /path/to/luau
python3 tools/test_mining_flight.py /path/to/luau
python3 tools/release.py
```

The third runner includes actual server job regressions, a four-second yielding-save/two-observer/late-join check, 30/60/144 Hz arrival and missed-dive checks, catalog contrast/terms checks and production-function work estimates. CI now runs it before the release artifact upload. Current output is recorded in `COMMITTED_MINING_TEST_RESULTS.txt`.

Build only from immutable `assets/drone-blower-revolution-base.rbxl`, SHA-256 `b08036b400c77451e609f5fa3a4f7f04cd5dcc2030f35a76de12ecc278f532cd`, to `build/Drone Blower revolution.rbxl`. The binary regression builds twice and checks deterministic bytes, exact seven live Source paths, all unrelated raw chunks and every backup Source. `build/revision.json` stamps the exact clean source commit and generated-place checksum. Direct Git fetch lacked credentials; the connected GitHub API acquired all branch blobs, verified their Git hashes and restored the exact existing head/tree in the cloud checkout before committing changes. This is the existing repository, not a disconnected prototype.

**Final visual/motion/audio, desktop/touch/controller, busy multiplayer, actual DataStore/restart and independent art-director gate: NOT VERIFIED.** No Studio was available in this cloud task, no Roblox publishing or main merge occurred, and earlier native evidence does not approve this new build. The owner should test a 30+ stud order, final approach, warmup, sustained mining, shell reveal, queued completion, powered hit/recovery, recall, two observers and late join. Compare normal-speed final-candidate captures at low/high graphics and desktop/phone, and assess whether the difficulty/fleet choices feel worthwhile. Keep PR #1 draft pending that evidence.
