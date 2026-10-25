# Mining Away: progression boundaries and acceptance

This is an implementation and test contract for the latest requested prototype. The latest user request takes precedence over older recommendations for three starting drones, contracts as the main progression, or postponing prestige. Numerical examples here are provisional tuning, **not an optimal economy or validated retention model**.

## Required loop and state ownership

Start with **one permanent drone**. Mine, sell, buy a pack with earned credits, choose one of three random cards, improve the current run, reach richer turret-guarded fields, and prestige for **exactly one additional permanent drone**. Repeat with the larger starting fleet. No paid packs, trading, or purchases with Robux are required by this scope.

Keep these separate in the saved player profile:

| State | Survives destruction/reprint | Survives prestige |
| --- | --- | --- |
| Permanent drone records: stable ID and base type/template | Yes | Yes |
| Permanent drone count and completed prestige count | Yes | Yes, increment once |
| Tutorial completion and accessibility preferences | Yes | Yes |
| Current-run selected card modifiers and their target IDs/types | Yes | No |
| Current-run credits, unsold cargo, pack-price index and offer-protection counter | Yes | No |
| Current-run zone unlocks and prestige eligibility progress | Yes | No |
| Unchosen purchased pack offer | Yes; same offer after reconnect | No; see confirmation rule below |
| This player's spawned models, reservations, projectiles and encounter membership | Reconstructed/reset appropriately | No; other players' shared encounter state is preserved |

`PermanentDroneCount = 1 + CompletedPrestiges` is the default invariant. If the implementation allows any other source of permanent drones, it must explicitly update this invariant and its tests. Reprints never create a new owned drone, increment that count, or reroll a base type. A stable permanent drone ID identifies an owned unit across model destruction, reprint, reconnect, and prestige. A separate spawn generation identifies a particular model lifetime and rejects stale effects/hits.

Do not accidentally serialize derived movement/damage values as the new base stats. Compute effective stats from the immutable template plus the current run's validated modifier set. Loading or reprinting the same drone ten times must not apply its modifiers ten times.

## Packs: three server-owned offers, one durable choice

1. The client requests a purchase; the server derives the player, price and allowed location/state. Serialize all purchases, selections, sales and prestige operations for that profile. Rate limiting supplements these guards; it does not replace them.
2. Check sufficient credits, no unresolved purchased offer, and a viable pool of at least three distinct eligible outcomes after the catalog's documented bounded fallback. Reject without charging when these conditions fail. Do not charge repeatedly for rerolls or silently substitute duplicates.
3. Generate a server-only seed and stable transaction/offer ID. Resolve all three cards and any random target drone **at offer creation**. Save the complete resolved offer, its catalog version, charged price and debit in one atomic profile transition. A seed alone is insufficient because the catalog may change.
4. Publish the durable offer. Each card states exactly which type or named drone it affects, its present and resulting stat, and that it expires at prestige. An offer must never imply that a random-drone effect applies fleet-wide.
5. The client submits only `offerId` and one of its three card IDs/indices. Validate ownership, current run ID, pending status and eligibility. Atomically record the selected card, apply its modifier once and close the offer. A retry returns the previously committed result; it cannot choose a different card.
6. Restore the identical pending offer after disconnect/crash. Closing the UI, dying, reprinting, changing servers, or retrying a request never regenerates its seed, target or alternatives.

A random target must be an owned permanent drone, not an arbitrary Workspace instance or a different player's unit. Target eligibility includes destroyed/reprinting units because they remain owned; label that selection clearly and apply it when that same unit respawns. Do not reroll onto a living unit. Type-wide cards affect the specified base type during this run, including that type's reprinted models. A prestige-created drone starts the new run without the previous run's type buff.

If a catalog migration invalidates a pending card or its permanent target truly no longer exists, execute a documented atomic migration or full pack-price refund; never silently debit and abandon the offer. Deletion of owned drones is outside this slice.

All pack IDs and receipts here are internal economy transactions. If paid products are introduced later, they need a separate authoritative purchase-receipt flow and product-specific review; do not infer that client purchase UI proves payment.

## Offer quality, caps and mathematical sanity

Preserve the requested card meanings: **blue drones fly twice as fast**; **one randomly selected eligible drone's laser starts twice as fast, meaning half the warmup duration**. The warmup card does not double laser damage, tick rate, or firing frequency after startup. Reassignment and target changes use the documented normal warmup rule, so spam-clicking cannot bypass warmup.

Use the catalog in `docs/ROGUELIKE_PRESTIGE_DESIGN.md`: `effectiveStat = typeAdjustedBase * (1 + sum(cardPercentages))`. Type-wide and individual contributions add against that base rather than multiplying each other. Startup cards add to startup rate: `effectiveDelay = max(0.08, baseDelay / (1 + startupRateBonus))`. Thus the individual +100% rate card halves delay **when alone**; with a pre-existing +30% rate it changes `baseDelay / 1.3` to `baseDelay / 2.3`, not a further halving. Preview the actual before/after value.

Fleet cards allow at most two picks per card ID; color/tradeoff cards once per card ID; individual cards once per `(cardId, droneId)`. Apply the catalog's limits: speed 3x baseline; mining/combat/health 4x; yield 2x; cargo 3x; range 1.6x; critical chance 30%; damage reduction 50%; firing interval at least 0.15 seconds. The implementation must state whether baseline means common template or type-adjusted base and use it consistently. Ensure the advertised combat cap includes the combined shot-damage and firing-rate calculation, rather than independently capping both at 4x and accidentally producing 16x DPS. Bound splash/crit separately and include their expected value in balancing. Never offer a card whose whole benefit is saturated, and never turn repeated picks into unbounded `2^k` multiplication. Tradeoff reductions must keep living health and all functional rates positive.

Evaluate eligibility against both current modifiers and all three resolved outcomes. Do not offer a strictly weaker subset beside an otherwise identical superset at the same cost: for example, one blue unit gets 2x flight versus every blue unit gets 2x flight. Avoid three cosmetic variants of the same mechanical outcome. Prefer at least two meaningful categories in each offer. Once Cobalt is visible, never generate more than two consecutive offers without a useful eligible combat-damage, health, shield or turret-resistance option: force one into the third offer when available. Track generated offers, not which card the player chooses; reopening does not advance or reset this counter. This is offer protection, not a hidden increase in rare-card odds. Show the rules and persist the counter.

An unlucky series must not make the starter field unprofitable, remove access to all useful upgrades, or permanently lock the player outside the progression path. If every relevant stat is capped, disable pack purchase with an explanation; do not take credits for useless choices. Ordinary currency growth must not depend on a rare card.

An illustrative throughput check shows why card values depend on the map. Let one completed target consume `T = travel + warmup + mining` seconds and give a fixed reward. With four equally assigned drones, two blue, compare blue-wide 2x flight with half warmup on one drone:

| Illustrative target | Travel / warmup / mining seconds | Fleet output gain: blue flight | Fleet output gain: one warmup |
| --- | --- | --- | --- |
| Travel-heavy ordinary targets | 6 / 2 / 8 | 11.54% | 1.67% |
| Nearby small targets | 1 / 2 / 1 | 7.14% | 8.33% |
| Long hard-shell engagement | 1 / 2 / 40 | 0.59% | 0.60% |

These are arithmetic examples, not simulated Roblox results. They normalize all drones to identical pre-card timings to isolate the card comparison; the catalog's mild built-in type differences are omitted. They assume no contention, shared cargo bottleneck, defense time, return trip or simultaneous geode effects. The formula is `sum(1 / T_i)`; reward scaling cancels. Warmup is weak when each drone starts once on a long target, while flight is stronger with long travel or more blue units. If every actual target resembles the first row, the desired choice is poorly balanced even if the card text sounds exciting. Keep small nearby deposits and meaningful travel choices, then measure actual picks, output and combat success in playtests.

Permanent fleet growth must remain approximately linear in independent worker capacity, not compound all historical pack multipliers. A naked fleet of N otherwise identical independent drones should approach N times one drone's unconstrained output, before pathing, cargo or available-target limits. Check cargo and sell-trip scaling so a larger fleet is not mainly a more frequent interruption. Do not silently impose a permanent ownership cap that breaks the promised +1 prestige reward; document the tested fleet size and performance limits.

Prestige eligibility and pack prices must be data driven. Use the design document's illustrative first 2,000-sale-earnings plus Cobalt-clear milestone, and the subsequent stated thresholds as starting data. `runSaleEarnings` is cumulative verified sales, not current spendable credits: buying a pack must never move the prestige goal backward. Never use one forever-fixed, trivially farmable prestige threshold without checking later fleets. Publish exact live thresholds and prices in the implementation README. The proposed first five thresholds grow faster than fleet size, so richer fields and better builds must actually offset the growth; otherwise later runs will become increasingly slow. Do not present the listed durations as measured outcomes.

## Prestige: atomic reset with an explicit preview

At the depot, show the exact eligibility requirement, the resulting permanent fleet size, and which run resources/upgrades will reset. The player explicitly confirms this concrete reset. Do not trigger prestige on an ordinary sell interaction.

Resolve or refund a pending pack before allowing prestige; do not discard a paid-for unchosen offer without warning. Require the player to have ended their own active encounter participation; other players' continuing encounters do not block this player's prestige. Clear ordinary assignments safely. If death/reprint or another request races prestige, the profile transaction queue decides one valid ordered result.

Commit eligibility validation, permanent drone creation, `CompletedPrestiges += 1`, new run ID, run reset and transaction receipt **as one durable profile update**. Reset credits and cargo to zero; remove run cards, run pack-price progression, offer-protection counter, temporary unlocks and run milestones. Preserve the existing permanent drone IDs and append one new unique record. Derive its configured base type on the server. Do not accidentally roll a new type on every load.

Only after successful commit rebuild the fleet and update the UI. Save failure leaves the previous run usable and grants no extra drone. A crash after commit but before presentation must load the new run correctly. Retrying the same prestige ID returns that result, never a second drone. Old run requests arriving afterward fail against the new run ID. Keep a bounded recent-receipt ledger plus a monotonic profile revision/run ID; do not depend on an unbounded transaction history.

Persistence must guard concurrent server sessions and stale overwrites. On uncertain load failure, do not substitute an empty one-drone profile and save it over existing progress. On uncertain transaction outcome, reload/reconcile the durable transaction ID before retrying; local UI success does not prove durable commit.

## Combat: skill, free reprints and no attrition bypass

Guarded fields must have readable turret fire/aim telegraphs and at least one useful command decision: target priority, timing a retreat/reposition, or exploiting a clearly exposed attack opportunity. Health and DPS purchases alone do not satisfy the requested skill element. A shot already telegraphed must not instantly track the player's corrected position without communicating that tracking behavior.

Preserve the existing finite cooperative/shared encounter implementation when present; do not replace it with a broad owner-isolated overhaul solely for this update. Freeze each attempt's eligible participants as `(UserId, runId, permanentDroneId)` and snapshot their loadouts. Only this roster can deal damage. Destroyed members remain out until the encounter ends; reprints, late arrivals and newly created model IDs cannot enter it. No mid-assault pack selection, uncapped healing, or replacement entry. A participating player must retreat/end their own participation before prestige.

Maintain an explicit clearance entitlement for each qualifying `(UserId, runId, fieldId, encounterId)`; visible world turret death by itself does not authorize every nearby player to mine. Define the participation/credit condition in the README, using authoritative roster/contribution rather than a last-hit race. Mining checks the requesting owner's current-run entitlement at assignment and each tick. Late joiners can see the battle and join the next attempt; they cannot inherit the current attempt's victory without its documented eligibility. If no shared encounter exists in the supplied implementation, document the chosen finite roster rule before adding one; do not mix incompatible personal and shared health models.

When the entire fixed eligible roster is wiped or disengaged beyond the bounded timeout, reset **all** turret health and retire that attempt's entitlements before admitting a fresh roster. Short re-entry must not reset the abandonment clock forever. One player's retreat, disconnect or prestige removes their own participation/clearance; it does not reset an encounter or resource expedition that other eligible players are still using. Survivors may finish the original attempt with no replacements. Repeated failed attempts yield no protected ore and do not accumulate defense damage or repeated partial-kill payouts. Success and zone resource access share the same encounter lifecycle; a refreshed defense cannot retain stale mining permission. Prestige never resets other players' world state or grants its new run the old run's clearance.

Free reprinting restores the existing unit and its current-run modifiers after a visible delay. It costs time rather than permanent ownership. Reprinting cannot copy a drone, duplicate hardware, retain an unfinished assault's turret damage, reset a random card target, or alter the saved count.

## Replication and visual parity

Server authority covers owned fleet records, movement/positions relevant to gameplay, combat, mining, cargo, currency, cards, packs, prestige, targets, defense clearance and reprinting. Clients request bounded intent IDs. Validate invoking player ownership, run/spawn generation, state transitions, target existence, range, unlocks, cooldowns and request rate; ignore supplied damage, credits, multipliers, positions and user IDs.

All players must see other players' drones and meaningful follow/travel/attack/mine/return/destroy/reprint states. Replicate enough current state that joining late reconstructs the fleet, health, encounter status and active beams without replaying old rewards. Cosmetic interpolation cannot authorize damage or alter mining yield. Document the shared roster and per-player/run clearance rules; globally visible turret damage alone never establishes an outsider's entitlement.

Restore the original prototype's recognizable feel using the latest provided source as the reference: smooth following and flight, hovering above the actual rock surface instead of clipping its center, staged mining damage with **three readable stages**, random crystal placement, and visible crystal growth. Preserve random variation while generating authoritative target identity and placement on the server. Reject overlapping/out-of-bounds or unreachable spawn candidates with a bounded retry/fallback. A client cannot choose a richer spawn seed.

The simple alien map should make the depot/Converter, starter field, guarded richer fields, pyramid turret and routes visually distinct. Keep drone silhouettes, beam endpoints, crystal stages, danger telegraphs and health readable against terrain and bloom. Route boundaries must communicate where guards engage and where retreat ends an assault. Use labels/icons as well as color for drone types and protected/unlocked states. Do not replace existing movement or random growth with a static demo solely to make server migration easier.

## Acceptance matrix

Record each check as executed/pass, executed/fail, or not executed with the exact limitation. Static source review does not establish multiplayer, gameplay pacing or visual parity.

| Check | Required result |
| --- | --- |
| Fresh profile | Exactly one owned/spawned permanent drone, starter credits/cargo as configured, no run cards; first sale and first pack reachable without a rare drop. |
| Pack debit and retry | Simultaneous purchase requests create one pending offer and one debit; reconnect restores exactly its three cards and resolved target IDs. |
| Selection race | Two conflicting selections, or ten duplicate requests, apply one chosen card once; all clients/UI agree on the committed result. |
| Offer coverage | No absent type, foreign drone, nonexistent target, zero-effect capped buff or duplicate outcome; guarantee counter persists across reconnect. |
| Flight card | Matching blue units move at the promised effective speed, other types retain their stats, and all viewers see comparable movement. |
| Startup card | Only its labeled permanent unit has half warmup, within floor; mining damage per active second is unchanged. Reprint preserves the same target and effect. |
| Cap/overlap | Repeated offers and type/individual overlap cannot exceed configured limits or produce exponential multipliers; exhausted pools cannot debit. |
| Save/load | Repeated load/reprint preserves base stats and applies run modifiers once; failed load cannot overwrite established progress. |
| Prestige normal | Eligible confirmation gives exactly +1 permanent drone and the documented fresh run; prior units keep IDs/types and lose run mods. |
| Prestige failure/retry | Failure before commit preserves the run. Crash after commit restores the new run. Duplicate receipt and stale old-run calls never add another drone. |
| Prestige boundaries | Ineligible, insufficient objective progress, active assault or unresolved pack cannot silently reset the run. Sell/purchase/reprint races settle in one consistent order. |
| Defense gate | No protected crystal damage, ore, or mining reward before valid clearance; legitimate victory automatically enables the documented expedition. |
| Weak fleet | Ten wipe/reprint attempts start with full defenses, preserve drone ownership, and accumulate zero protected ore or defense damage. |
| Partial casualties | Original survivors can finish; reprinted drones cannot join until reset; a newly spawned model cannot bypass roster identity. |
| Combat skill | A tester can identify a telegraph and improve an otherwise identical attempt with timing/priority/repositioning, without purchasing extra stats. |
| Invalid requests | Unknown/foreign target IDs, stale generations, forged stats, bad strings/tables, NaN/infinite/huge/negative numbers, and spam reject without exceptions or state mutation. |
| Mining parity | Original-like smooth movement, rock-top hover, all three mining stages, random placement and growth observed in Studio; beams stop on recall/death/target loss. |
| Geode race | Multiple finishing hits open the shell once, spawn one core set and award each authoritative target once; reservations and effects stay bounded. |
| Multiplayer | Two clients observe correct fleets and states; eligible cooperative participants receive their own run entitlement, outsiders cannot inherit it, and one player's retreat/disconnect/prestige never resets the others' continuing encounter. |
| Late join | Joining mid-mining, mid-assault and during a reprint reconstructs current state without phantom models, missing beams or replayed payouts. |
| Timing | Equivalent elapsed time across varied server/client frame rates yields comparable travel, warmup, mining and combat results; large dt cannot skip gates. |
| Map readability | A new tester can locate selling, the first safe job, the richer guarded field and the pyramid turret; danger and extraction feedback remain legible. |
| Lifecycle/performance | Repeated target switches, deaths, reprints, prestige and reconnects leave no duplicate models, stale locks, reservations, beams or ever-growing connections; document tested fleet size. |

## Handoff evidence

Deliver the updated place or complete importable source bundle, tuning/catalog definitions, persistence schema/version and migration policy, controls and integration instructions, plus a candid validation log. Preserve the source place separately. List which tests need Studio/networked clients and remain unrun. Include measured first-pack/first-prestige time and card picks only when actually observed; mathematical examples above are not those measurements.
