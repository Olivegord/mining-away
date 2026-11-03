# Smooth animation on every observer

The server now publishes role-effect state and timestamps. Clients create and animate the role geometry themselves. This removes server tweens, replicated moving orbital Parts and server-created scrap-bot geometry. Each client uses the same authoritative start/end times; joining mid-effect evaluates its current phase, and old contact impacts are not replayed.

`DroneRoleEffects` contains bounded state receipts only. `RoleEffectView` observes them on every client, and `RoleVisuals` retains the existing particle shapes, physical orbital column, charge cues and effects. Short-lived state is cleaned up; sustained effects retain current state for late joins and end on cancellation, disconnect or timeout. Partial receipts wait for required fields. Overlapping effects use distinct identities, so cleanup of an old charge cannot remove its successor.

Carriers, flying backpacks, launch capsules, scrap bots and orbital contacts use a 120 ms render buffer instead of repeatedly easing toward the latest packet. Prediction is limited to 100 ms during a missing update. Transport publishes a final stationary sample at arrival; capsule reset clears its buffer. The server still owns logical movement, collision/spatial proxies, mining, damage, cargo, rewards and persistence. Those hidden spatial proxies retain bounded position publication; they do not drive visible animation.

All seven special-miner choreographies now evaluate every render frame, including their aftermath. The previous 30 Hz hold has been removed. Ring unit coordinates and unchanged visual properties are cached; scenery filtering, distance cleanup and pause behavior remain. The orbital transparency pattern also advances every render frame.

## Offline verification

- `python3 tools/test_smooth_animation.py /tmp/mining-away-luau`: nine production receipt/timeline checks plus the actual scrap observer/frame loop. Covers no server effect geometry, matching observer phases, late joins, 30/60/144 FPS frame advancement, cancellation, partial replication, buffer prediction/arrival/reset, original miniature artwork, confirmed chips and cleanup.
- `python3 tools/test_performance.py /tmp/mining-away-luau`: actual bundled server/renderer logic under deterministic API doubles. Existing server reductions remain: 255 versus 1,800 idle model updates, 120 versus 1,560 orbital burn queries, and 126 versus 840 specialist hold queries in their two-second cases. Idle logistics still performs zero descendant scans/pose writes. Seven continuous special effects produce 62,129 counted property writes versus 90,492 in the original all-crew baseline at 144 callbacks/sec. The earlier 81% FX reduction depended on 30 Hz stepping and is superseded by this continuous-motion result.
- Energy/particle, refinement, gadgets, audio, mining-flight, special/logistics and shop regression suites pass. These execute production logic and compile the current bundles with API doubles; they are not engine tests.
- Build validation preserves every non-Source chunk and unrelated/backup script from the verified live base. The editable native map is refreshed offline with only allowlisted Sources changed.

## Native verification boundary

Studio reported no connected instances. No Studio opening, Play start or gameplay execution was performed during this change. The saved build contains the changes, but final appearance, network transport, FPS and multiplayer smoothness still require the owner's engine test. No Roblox publication or new experience was created.
