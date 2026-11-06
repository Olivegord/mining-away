# Core mining feel

The owner clarified the target: directing drones, breaking rocks and collecting, with cubic rocks, physical debris and more satisfying rock audio. No new progression system is included.

## Implemented behavior

- Runtime resources are native block Parts. The original crystal template, authored map, drones and backups remain intact. Bubbler bites and Smasher dents subtract from the cube instead of rebuilding the historical crystal mesh.
- Clicking a rock remains an exact order after automation. Clicking field ground still assigns the plot. Holding the mouse and moving across rocks queues each once; it does not repeatedly toggle a queued order. Touch taps and controller aiming use the same precise command route.
- Boulders accept three workers. Repeated clicks recruit helpers without restarting existing work. Idle workers are preferred; explicit orders can redirect automatic travel/cutting. Manual jobs, committed slams and specialist jobs are preserved. Automatic workers resume their field afterward, and manual geode orders retain their shell-to-core continuation.
- One hover readout shows mineral, remaining health and the crew slots on a boulder. Exact rock outlines remain visible with automation. Assigned-field outlines are quieter.
- Resource spawning checks the actual world at the center and four footprint corners, including authored trees outside the Map container. A blocked Smasher releases its reservation and excludes that rock for six seconds. Ability line of sight uses the current collider center after shrink.
- Cubic local rubble uses gravity, restitution, friction, tumbling, two or more diminishing rebounds and a flat settling pose. Stage chips and final-break chunks have different weights/impulses. The shared debris cap remains 48. These are bounded cosmetic ballistic simulations against a sampled floor, not replicated rigid bodies or full wall-to-wall collisions.
- Cutting ticks follow real HP loss; crystal cracks follow authoritative stages; final breaks add a low stone body. Debris clacks occur at simulated contacts, with level based on impact speed. Existing verified rock clips vary in pitch and selection. Accepted laser timing/audio remains unchanged. Voice limits, spatial attenuation and effects mute remain in use.
- Confirmed pickup bursts step upward gently in pitch. A cumulative server collection counter drives a short `+N ore` readout, including multiple pickups that coalesce into one replication update. No animation awards ore. The compact backpack meter responds with a small spring, respecting reduced motion.
- At the depot, the same U/button action offers Launch when storage is full, then returns to Deposit. Existing storage capacity, flight, earnings and persistence rules remain unchanged.

## Verification and limits

Before the change, native inspection found a Smasher repeatedly contacting a Quartz rock while its damage ray hit `Workspace.Stud pack V1.Tree1.Part`. This was a real engine observation, not a mock result.

Production-function tests with Roblox API doubles cover helper recruitment, manual priority and automatic resumption, committed-job protection, foreign reservations, blocked Smasher release, world obstruction sampling, precise click/drag intent, cubic damage scheduling, mining/rewards and collection conservation. Ballistic sampling checks gravity, rebounds and settling at 30/60/144 Hz. Both full bundles compile. These tests establish behavior contracts, not visual quality, networking or fun.

The initial native installation was interrupted by macOS Screen Time. After the owner cleared the restriction, revision `3ecf9ae242ed75b58b424819e7f8f28c0ce116e4` was installed into the canonical native document and restarted on November 6. Startup inspection found 53 cubic resources, 53 client resource views, 12 three-worker resources, a loaded preview profile and no console errors. The saved native SHA-256 was `71a2dc84820551d985b24ff5cfb53efc5118ab88a88fa42c6b12d60d6345d689`. This supersedes the earlier installation blocker; it does not establish audio quality or fun. The owner subsequently reported the game still felt unfun; see [the extraction-loop follow-up](EXTRACTION_LOOP.md).

Still needed in Studio: inspect cube CSG topology and rubble settling; listen to the busy-field sound mix; try exact clicks, drag queue, repeated helper clicks and depot U; check two-player visibility/late joins and touch/controller hardware. No new native visual, audio, multiplayer or fun acceptance is claimed.

Reproduce: `python3 tools/test_core_gameplay.py`, `python3 tools/test_refinement_client.py`, `python3 tools/test_physical_mining.py`, `python3 tools/test_rock_damage.py /private/tmp/mining-away-luau`, `python3 tools/test_mining_flight.py /private/tmp/mining-away-luau`, `python3 tools/test_consumables.py`, and `python3 tests/single-game.spec.py`. `build/revision.json` records the exact release commit and native SHA-256.
