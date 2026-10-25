# Deterministic progression model

Status: rerun locally on October 25, 2026 with official Luau 0.744 after the signature-card update. **These are model outputs, not Studio playtest times, observed player picks, visual evidence, or multiplayer results.** Reproduce with `luau tests/progression.spec.lua`. The script prints all ten fixed seeds, their exact chosen card IDs/targets, both run timings, and the one-through-six fleet comparison. It uses the actual `Profile`, `Cards`, `Feel`, `Rules` and `Config` modules; it does not run the Roblox engine or substitute a separate economy implementation.

## Scope and assumptions

- Seeds are exactly 1 through 10. Every seed completes a fresh one-Blue-drone run, prestiges to the same Blue plus one permanent Red, then completes that second run and prestiges to three units. Existing permanent IDs are asserted unchanged and run cards/cargo/credits are asserted cleared. No seed is discarded, rerolled or replaced.
- Offers and their individual targets come from production `Cards.buy`; the heuristic chooses exactly one of the three saved outcomes using `Cards.select`. The model never enumerates alternative offers or modifies their seeds. Prices, scopes, stacking, final caps, startup delays and cumulative sale milestones come from production functions.
- The worker starts in Landing Quartz until its first pack, then moves to safe Ruby until it can win Cobalt. All later mining in a guarded field requires this model's current finite-expedition entitlement. **A full-hold solo recall ends that entitlement. Each subsequent protected hold must defeat fresh complete defenses again.** The second-run requirement of two Cobalt wins means separate expeditions, not repeated victory credit for one roster.
- Ordinary nodes use configured field count, ore/value, width/depth and relative field offset. Health is seeded uniform integer 50–100, with HP-related height. Replacement nodes have their configured replenishment delay plus two seconds of growth; growing nodes cannot be scheduled as ready. Reservations are one node per worker. No grid or unlimited-node assumption is used.
- Travel follows the production `.03` eased/capped scalar helper at 60 Hz until within one stud. Path length is unobstructed Euclidean distance to the production-style overhead station. Each target then consumes its effective warmup plus `(maxHealth - 10) / effectiveMiningDPS`. Worker jobs finish in chronological order. Capacity is shared, integer yield/remainders are respected, overflow is discarded, and full cargo cancels remaining assignments.
- A field trip includes walking to its configured center at an assumed standard 16 studs/s. Return waits for the slower of player walking and the slowest worker's original eased/capped trip, then one second to sell. A pack choice adds two seconds. This is a deliberate repeatable route, not an optimal route; ordering from the edge of command range could shorten it. Network, persistence and human reaction time are not simulated.
- Combat is an unobstructed fixed-station 60 Hz model. It uses the actual finite `Rules` roster, contributions, wipe/timeout/clear transitions, base traits, saved card modifiers, shot damage/interval, critical rolls, hull, entry shield and turret resistance. Drone shots occur before turret shots as in the server. Sentries charge for 0.8 seconds, then use the configured cooldown. Sentries are spaced 17 studs apart, so six-stud splash does not apply. Arc Relay reaches 22 studs and can hit one other living sentry, additionally requiring that secondary to lie within the drone's working range. The spatial abstraction places the drone at the server's +11/14/8 X, +5 Y, +9 Z shot station relative to its current target; it skips travel between stations and assumes clear line of sight. Finisher damage applies at or below 35% remaining hull, before the critical roll, as in the server. Salvage applies only to a newly killed direct or secondary target, repairs built-in hull times the capped fraction, and never exceeds current maximum hull. All participating drones begin in range at full hull; no extra approach misses or repair delay is modeled. Times include the four-second muster.
- The model does **not** simulate skilled Evade commands, aiming/line-of-sight obstructions, exact triangle geometry, damage during approach, geodes, fork mining, other players, save latency, disconnects, frame stalls, rendering or replication. These omissions do not all bias in one direction: no dodging/geo rewards can slow modeled progress, while perfect route knowledge/no blockers/no failed paid attempts can speed it up.
- Choice heuristic: while the current fleet cannot win a static Cobalt fight, evaluate only the three actual offered choices against the same fixed combat seed and prefer winning, then defense damage/surviving hull, with a small mining-throughput tie-break. Once it can win, choose estimated nearby-target output/cargo improvement while rejecting choices that would lose that win. This is an informed deterministic policy, **not measured player behavior or proof of optimal balance**. It predicts an assault's outcome and avoids failing it; actual new players will pay additional learning/reprint time.

## First two complete runs

The summary uses the lower of the two center observations as the ten-seed median, matching the printed runner.

| Metric | Minimum | Median | Maximum |
|---|---:|---:|---:|
| Run 1 first pack | 52.70 s | 54.95 s | 57.69 s |
| Run 1 prestige, fleet 1 → 2 | 412.99 s | 474.28 s | 545.79 s |
| Run 1 packs chosen | 6 | 7 | 8 |
| Run 2 first pack | 34.18 s | 35.38 s | 37.85 s |
| Run 2 prestige, fleet 2 → 3 | 684.74 s | 760.90 s | 885.48 s |
| Run 2 packs chosen | 8 | 9 | 10 |

The median first pack accelerates from about 55 seconds to 35 seconds after permanent fleet growth. The first run's modeled prestige is about 7.9 minutes; the second is about 12.7 minutes despite its faster opening, reflecting 5,000 cumulative sale credits and two separate Cobalt wins. The earlier design's 12–18 and 15–22 minute ranges were hypotheses. Do not raise requirements merely to force these abstractions into those durations before testing the actual map and learning curve.

There is meaningful offer variance: the slowest first run takes about 9.1 modeled minutes rather than the median 7.9. Offer-protection tests separately ensure useful combat/survival options appear within three generated offers; this does not guarantee that a player chooses them or wins without learning telegraphs.

## Fleet growth and later requirements

This comparison holds cards at zero and fills one shared 120-unit Ruby hold, including travel/return/sale. It does not claim naked fleet worker DPS scales sublinearly; the fixed shared hold and trip overhead are the bottleneck.

| Permanent fleet | First Ruby hold | Sale | Current-run sale requirement | Guarded milestone |
|---:|---:|---:|---:|---|
| 1 | 49.12 s | 240 | 2,000 | Cobalt ×1 |
| 2 | 35.78 s | 240 | 5,000 | Cobalt ×2 |
| 3 | 29.12 s | 240 | 11,000 | Violet ×1 |
| 4 | 26.50 s | 240 | 22,000 | Violet ×2 |
| 5 | 25.21 s | 240 | 42,000 | Emerald ×1 |
| 6 | 23.30 s | 240 | 73,500 | Emerald ×2 |

Six naked workers improve this complete first-hold route only about 2.11× relative to one, because all share the same cargo and extraction trip. This is a concrete later-run pacing risk. Cargo cards can expand capacity to 360; richer minerals and stronger run builds must offset the sharply increasing milestone curve. The first two full runs were simulated; **runs 3–6 were not completed by this model**, so their listed threshold/difficulty comparison is not a completion-time estimate.

Naked finite-fight results with fixed seed 73, including muster:

| Fleet | Cobalt | Violet | Emerald |
|---:|---|---|---|
| 1 | Wipe, 116 turret HP left | Wipe | Wipe |
| 2 | Clear in 13.60 s | Wipe | Wipe |
| 3 | Clear in 10.40 s | Wipe, 446.40 HP left | Wipe |
| 4 | Clear in 8.80 s | Wipe, 40.56 HP left | Wipe |
| 5 | Clear in 8.00 s | Clear in 19.20 s | Wipe, 415.76 HP left |
| 6 | Clear in 7.20 s | Clear in 15.20 s | Clear in 35.20 s, only 46 hull left |

These results support the intended distinction: one naked starter cannot jump to Cobalt; two permanent units make the next run's early guard substantially easier; Violet at three and Emerald at five still call for combat/survival cards or skill. Geometry and player evasions can materially change these results in Studio.

## Executed assertions and recommendations

Five deterministic checks pass: all ten fixed seeds complete both run/prestige transitions; zero-card safe mining remains productive with correct material sale value; a pure mining buff cannot turn a weak Cobalt assault into a win while a combat/hull build can; signature finishers/arcs/bounded kill repair execute in the combat abstraction; and ten weak fresh attempts retain ownership and accumulate no protected cargo/earnings. The full server/API-double suite separately tests actual authoritative reward/encounter adapters, and the Profile/Cards suites cover persistence-safe transaction logic.

No gameplay tuning values were changed by this review. The prior two-hour seed-6 failure was a model blind spot: its heuristic and combat evaluator ignored the newly offered Execution Lens. After modeling its actual conditional damage, all ten unchanged seeds complete both runs. The catalog/offer change moves the first-run median from 437.25 to 474.28 seconds and the second-run median from 820.01 to 760.90 seconds in this policy; that is offer variance within this model, not evidence of a new hard progression block. Before increasing first-run grind, observe the original-feel slice in Studio. Then prioritize (1) whether fresh players understand choosing combat versus mining cards, (2) whether returning every 120 units interrupts larger fleets too frequently, and (3) third-through-sixth full-run timing. Candidate fixes to test are gentler later sale thresholds or modest permanent-fleet capacity scaling, rather than silently capping permanent ownership or compounding old run multipliers. Any change needs a rerun of this model and actual Studio playtests.
