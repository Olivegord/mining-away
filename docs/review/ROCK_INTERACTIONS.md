# Rock interactions

The owner rejected earlier ore release as merely changing when rewards arrive. They also explicitly rejected animated/spinning shrink and required currency to fly up and away visibly. This pass adds spatial consequences to rock collapse and fixes those presentation rules.

## Mining behavior

A completed rock throws up to two physical-looking chunks at eligible rocks within 18 studs. A Smasher's heavy break throws three. The chunks follow a shared ballistic path; server segment raycasts stop them at world geometry, and damage occurs at actual contact. They are simulated projectiles with client-sampled presentation, not Roblox rigid bodies or collision-authoritative client debris.

A contact deals 30% of the smaller rock's original work requirement. It can prepare an intact neighbor but cannot erase one. An already weakened rock can collapse and throw another wave. Brittle neighbors are preferred, and the existing hover readout identifies brittle rocks. The same chain has at most six contacts over three waves, cannot revisit a rock, and remains in its original field. Up to 12 projectiles per owner and 48 total bound simulation/render cost. Boulders resist chunks from smaller rocks because the hit budget is capped by source work.

A rock collapse changes the nearby field automatically. No special drone pairing, new button, purchase, progression layer or reward multiplier is required. These consequences are a design hypothesis, not evidence of enjoyment.

**One drone type per rock:** direct orders, painted queues, automatic miners and automatic Smashers respect the same server reservation rule. Autonomous orbital charges/burns and active scrap-bot targets also exclude workers of other types. Spare boulder slots accept only more workers of that same type and owner. A rejected reassignment preserves the worker's previous job. Once the last worker leaves, another type can take the rock. Physical collapse chunks and placed tools remain environmental impacts, not assigned worker slots.

## Applying the owner's automation article

The owner supplied [taw's automation-game essay](https://t-a-w.blogspot.com/2026/07/how-to-make-great-automation-game.html). Its process/bottleneck lens informed a proposed worker handoff, which the owner then explicitly rejected as too complicated for this Roblox game. That handoff was removed before the final revision. Do not restore complementary-worker choreography or infer a request for a factory game from the article.

Retain the narrower useful criterion: the rock's changing state and the consequences of a collapse should be easy to understand through play. More frequent rewards alone do not satisfy the requested mining-loop change. There is no added mandatory command rhythm, tech tree, crafting or logistics system.

The server retains all damage/reward authority. Foreign reservations are protected both at launch and contact. Unready, locked, depleted or invalid targets cannot receive damage. Walls block flight. Invalid profiles, save uncertainty, changed runs or reprinted/dead actors cancel unapplied projectiles. A deployed carrier worker can continue through its existing remote-field authority. Discovery speed/geode multipliers cannot multiply chain energy; consumable provenance propagates to prevent tool-generated chains producing tools. Each rock's existing extraction ledger conserves its own payout.

## Rock and currency presentation

- Resource stages snap immediately to their authoritative size and grounded height. Orientation stays upright with the same initial yaw. No shrink tween, interpolated tilt, artificial stage dwell or delayed replay remains. Spawn growth is retained.
- Final collapse hides the visual immediately and disables the server collider's query participation, so invisible retired rocks cannot intercept subsequent chunks or mining rays.
- Currency begins above and outside the entire rotated footprint, including large carved boulders. Initial speeds are 10.5–13.1 studs/s outward and 15.7–17.8 upward under existing gravity. Homing is inhibited for 0.85 seconds to preserve the visible outward arc. Floor physics, owner/run binding, finite lifetime and server-confirmed collection remain.
- Every observer samples collapse chunks from replicated origin, velocity and time. Late observers do not replay completed contacts. A contact uses the existing rock clack; it does not also pretend to be a continuous laser-cut tick. Accepted drone beam timing/audio remains intact.

## Checks and remaining evidence

Production-function tests cover delayed contact, intact-neighbor preparation, a prepared two-hop cascade, source-mass resistance, heavy volleys, shared chain budgets, foreign reservations, walls, uncertain saves, speed amplification exclusion, consumable provenance and outward currency arcs. Assignment tests exercise same-type helpers, rejection of mixed-type manual and automatic work, preserved previous jobs, and a queue skipping a nearer incompatible worker. Renderer checks cover immediate size changes, fixed yaw, coalesced updates and no duplicate effects. Existing mining, specialist, logistics, command and consumable checks are retained; one exact-ore gadget fixture is isolated from neighboring rocks because a legitimate cascade can now produce additional neighbor extraction.

Reproduce with `python3 tools/test_rock_cascade.py`, `python3 tools/test_physical_mining.py`, `python3 tools/test_special_logistics.py /private/tmp/mining-away-luau`, `python3 tools/test_core_gameplay.py`, `python3 tools/test_consumables.py` and `python3 tests/single-game.spec.py`.

The first native candidate produced eight launched chunks and eight accepted rock contacts in an 18.56-second sample, with live rock health falling at contact. Six sampled currency trajectories rose 2.93–3.27 studs and traveled 5.18–7.15 studs outward before attraction; no sampled drop began homing before the protected arc elapsed. This used ordinary plot orders with the 12-role Studio preview crew, not injected damage or ore. Depth-two cascades are covered by production-function tests but were not observed in that native sample. A mixed-specialist visual sampler was inconclusive because attribute replication and local rendering were sampled at different frame phases; it is not a zero-spin acceptance test.

The final native candidate matched all seven installed Source byte counts and hashes. In an 18.01-second client sample, 1,063 rendered frames included 16,501 observations of ready, visible, unscarred ordinary rocks: six size changes, zero sizes between legal stages and zero orientation mismatches. This avoids the earlier sampler's attribute/render-phase ambiguity and excludes specialist CSG geometry. Two flying chunk views were visible concurrently. In an 18.06-second server sample, the 12-role preview crew produced ten launched chunks and ten accepted contacts, including a depth-two cascade. The maximum number of assigned drone types on any one rock was one, with zero mixed-type samples across 295 samples. Console output was empty. Both samples followed an ordinary plot order; no ore, health or damage was injected.

Behavior/parity review checked unchanged movement/charge timing, same-type reservation checks on each assignment path, actual-contact damage, bounded chains and per-rock reward conservation. Pacing/visual/multiplayer code review checked source-mass resistance, finite projectile/visual lifetimes, no retired query colliders, no late impact replay, foreign-owner reservations and cancellation after invalid state. These code reviews and single-player observations do not establish listening quality, two-player/late-join presentation or fun. The owner asked to close the game after finishing; stop Play, save and close Studio after verification. Only the existing `build/DRONE_GAME.rbxl` is editable/playable; `build/revision.json` records the final integrated revision and checksum.
