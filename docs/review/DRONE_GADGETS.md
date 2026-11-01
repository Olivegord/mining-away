# Mining gadgets and drone steering — November 1, 2026

This is an implementation candidate for the existing Drone Blower revolution game. No new Studio Play session, Roblox publish or new experience was started. Engine motion, mobile clipping, multiplayer appearance and enjoyment remain **NOT VERIFIED**.

## Behavior

- Orbiter and Scrapper are new mechanical roles on the existing authored drone shell. Their focusing mast / mini-drone bays make their jobs distinguishable. They retain the permanent drone's color, ID, base traits and ownership. Obtaining one enables the corresponding gadget; mineral-shop purchases can enable it earlier.
- Orbital selects the largest currently grown eligible rock, saves its ID during charge, and vaporizes it through the normal authoritative damage/reward path. Tap during the server's marked precision window to fracture one nearby rock. The Fracture Relay card permits up to three nearby fractures. Nothing recursively triggers another orbital strike.
- Scrap deploys four miniature clones of the original drone for ten seconds; precision launches six. Pairs cooperate on the weakest nearby rocks. Each bot physically travels to a small slot inside the crystal footprint, settles within at most 0.15 studs, warms its tiny laser and applies a bounded chip of `max(2, min(8, maxHP / 48))` every quarter second through the normal authoritative hit path. The cap preserves later-field difficulty while preventing a ten-second deployment from polishing several fresh Violet rocks without finishing any. Scrap Reclamation extends a swarm by two seconds once, following a confirmed finishing hit.
- Gadgets require a living mining worker, an unlocked field, cleared guards, a nearby owner and backpack space. They cannot steal resources reserved by another player's worker. LOS and all existing award rules still apply. No rewards depend on the local visual clone.
- Server-owned cooldown timestamps survive reconnect through the run profile. The short charge and temporary bots are runtime state. Prestige clears run progress and gadget cooldowns alongside run cards. Selling/save transactions pause gadget work without discarding a deployment.

## Movement and presentation

The original elapsed-time `.03` capped approach and yaw remain intact for isolated drones. Shared frozen spatial buckets now estimate intent velocity and closest approach 0.45 seconds ahead. A deterministic pair tangent produces opposite passing lanes before overlap. Steering pressure is smoothed separately from position; settled miners immediately disable steering and retain their exact overhead station.

Scrap bot sources replicate complete pose, target and work attributes at 10 Hz. Every observer interpolates a separate local clone each render frame. Late joiners reconstruct current work from those attributes. The miniature source geometry retains the original asset. Lasers use two transparent cylinder Parts pointing vertically down. One swarm per connected owner is bounded to six bot sources; there is no first-eight-player omission. Transient role effect primitives remain capped at 256 and cleaned by Debris. The gadget control panel is 220×110, hides with menus and away from fields, disables while saving, and moves to the center on short viewports. Actual device readability remains unverified.

## Reference and adaptation

The owner named N-Gon as an inspiration. Its [primary tech source](https://github.com/landgreen/n-gon/blob/master/js/tech.js) implements conditional tech eligibility, temporary bots, expiration/refit, and systemic interactions between upgrades. These ideas informed the bounded relay/reclaim choices here; the implementation and retained game assets are this project's own. Numbers above are provisional tuning, not measured fun or optimal balance.

## Reproduce focused checks

```sh
python3 tools/test_gadgets.py /private/tmp/mining-away-luau
```

This compiles the six touched/new Luau modules and runs:

- 19 production gadget-domain checks: unlock/range/capacity gates, stable largest-target selection, server timing, replay protection, bounded precision relay, blocked contact refund, persisted cooldown hydration, temporary movement and lifetime, stall bounds, weak-target pairing, late-field chip bounds/payoff, exact finishing-hit recycle and run cleanup.
- 10 production steering checks using Vector API doubles: original isolated trajectory, symmetric overlap escape, anticipation/passing, co-moving neighbors, zero settled steering, equal elapsed-time steering at 30/60/144 Hz, frozen snapshot, iteration stability, destroyed neighbors and crowded bounds.
- 7 checks appended to the actual generated production server with API doubles: real command validation, ordinary `hitResource`/award execution once, foreign reservations, owner range/full bag, living-worker gate, real scrap hit dispatch, save-busy pause and cooldown persistence/hydration.

The server fixture stubs effect rendering and discovery pickup UI. It does not simulate Roblox raycast geometry, mesh rendering, network transport, rigid-body collision, native font metrics or player preferences. Existing historical ring-formation tests predate the already-approved hex layout and are not rewritten to manufacture a passing legacy suite.
