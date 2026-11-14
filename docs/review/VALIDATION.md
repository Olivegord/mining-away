> Earlier validation snapshot. The latest visual/upgrade pass, exact new checks, and Studio observations are in [ALABASTER_UPGRADES.md](ALABASTER_UPGRADES.md).

# Validation and independent review

This report covers the restore-feel/card/prestige implementation and October 25 presentation pass. The old baseline's 47 checks were not reused as evidence. An intermediate polish build was reopened from disk and entered Play in local Roblox Studio; its world and HUD were inspected. The Mac then locked before gameplay checks. Final polish changes, true two-client sessions, touch and live DataStore remain unverified. See POLISH_PASS.md for exact limits.

## Executed checks

| Suite | Passing checks | What actually ran |
|---|---:|---|
| Original feel | 18 | Shared production equations versus original .03/cap/.1 oracle at 30/60/120/144 Hz, radius10, slow hover, exact overhead stations, two-second growth and quarter stages, including coalesced stage/break presentation queues |
| Encounter/resource rules | 35 | Finite run/life roster, contribution entitlement, all-defense reset, reprints, friend-preserving retirement, exact phase/run/encounter gates |
| Profile | 18 | One Blue, permanent identity/base invariants, material sale, cumulative progress, exact +1 prestige, duplicate/stale calls, migration/refund, signed Preview IDs, foreign-ID/corrupt-offer rejection |
| Cards | 20 | Actual 35-card modifier pipeline, scopes/targets, fixed three-choice offers, one debit/claim, replay, caps, offer protection across fixed seeds, six-drone target variation |
| Persistence | 28 | Actual session manager against deterministic/fault-injecting storage, UpdateAsync callback retries, revision/lease fences, load failure, lost responses, migration, preview isolation, leave/unlock |
| Cosmetic lifecycle | 8 | Pure event/timing helpers for one-shot death, reordered HP/state, late joins, shot/life reset, reconstruction and bounded ballistic fall; no renderer assertions |
| Progression model | 5 | Ten fixed seeds completing full first and second modeled runs, safe fallback, combat decisions and repeated weak failures |
| Actual-server integration | 35 | The assembled production server running against a synthetic Roblox API/asset/storage double; not copied gameplay logic |
| Binary preservation | 4 | Determinism, only Source/Disabled chunks changed, enabled entrypoints, rejection of wrong input |
| Original geometry | 4 | Read-only original binary hierarchy/mesh/editor-history verification |
| **Total** | **175** | Plus all-source and assembled Luau compilation, standalone lint and archive/build metadata checks |

Official Luau 0.744 tools were used. The runtime analyzer receives explicitly `any`-typed Roblox host bindings, so it checks normal Luau errors/lint but not Roblox API contracts. Synthetic named asset fixtures establish binding logic, not that a Roblox mesh loaded/rendered correctly. No visual or network claim follows from the API double.

Actual-server cases include strict one-stud arrival and warmup, readiness before mining, atomic geodes, original assets, one Blue, saved offers after reconnect, named reprint modifiers, prestige into two drones, lost-response postcommit rebuild, shared-run entitlement isolation, ten weak resets, deferred clear during a profile transaction, frozen telegraph evade, late-state snapshots and final-save cleanup. The active turret's editor-history omission is tested while the source/template retain it. This replaces old three-drone/power-shop expectations.

## Independent findings and fixes

Separate agents reviewed parity/world, client UI, domain/progression, persistence and shared encounters. The reviews found and implementation corrected:

- Double movement/yaw smoothing, side-offset mining, missing random grow-in and ineffective stage-only coloring.
- Duplicate Drones folders, incorrect Converter range, sunk pyramid bases, duplicate hitboxes and resource overlap with guards.
- Authored transparency loss and eye cues hidden behind original spawnEye.
- A committed prestige/card transaction recovering after a lost response without rebuilding its world fleet/stats.
- Encounter wins/entitlements being overwritten by an asynchronous profile write; clear deltas now queue and settle afterward.
- Missing startup-load guard and insufficient final-save reconciliation.
- Replica discovery/late geometry, narrow-screen UI widths, and original-template/type-tint visibility.
- 3,429 redundant editor objects copied per active guard; the full source/template history remains while runtime clones omit it.
- Flight cards accidentally changing original hover phase; the published phase now uses immutable base traits.

The geometry report records source dimensions/meshes and a labeled outside-engine map schematic. UI_REVIEW records measured source layout constraints and remaining engine checks. These independent source reviews are not substitutes for the pending Studio comparison.

## Progression evidence and limits

The corrected model enforces a fresh finite defense clear for each solo protected mining trip after recall. Across ten fixed seeds its first pack has median 54.95 seconds, first prestige 474.28 seconds, second-run first pack 35.38 seconds and second prestige 760.90 seconds. It uses actual Profile/Cards/Feel data and a disclosed route/card heuristic; it omits real input, occlusion, contention, network/save latency and geode/special-effect throughput. See PROGRESSION_SIMULATION.md for every assumption and the cargo/travel bottleneck at larger fleets. These are modeled results, not observed gameplay durations or optimal balance.

The first five thresholds remain provisional. First-run model duration is below the old 12–18-minute design hypothesis; no extra grind was added merely to match an unmeasured hypothesis. Later full runs and larger-fleet performance require Studio measurement.

## Remaining acceptance

Follow ../STUDIO_ACCEPTANCE.md for original-versus-repaired video, actual binary opening and mesh/audio permissions, traversal/scale, mobile text, two-client/late-join behavior and six-drone frame/network performance. Live-only RockCrack/RockBreak assets are absent in the historical source. Quiet engine-bundled impact fallbacks are now included; exact stock file presence was checked, audible playback remains pending. Real durable service operation is implemented but was not tested against live DataStore or enabled in Studio.

The source is the same repository/branch and preserved historical base, not an export of the unavailable live 2026 version. No Roblox publishing, main merge or new experience occurred. The release's revision.json identifies the exact pushed source commit; its source_dirty flag must be false.
