# Packs, builds and permanent growth

Use this overview to understand the upgrade loop. For every possible card and its exact numbers, scope, copy limit and edge condition, read [`upgrade_cards.md`](upgrade_cards.md). Authoritative tuning is in [`Cards.lua`](../../src/Cards.lua), [`Profile.lua`](../../src/Profile.lua) and [`Config.lua`](../../src/Config.lua).

## What the player does

1. Start with **one permanent Blue drone**, no run cards, zero currency and 120 shared ore capacity.
2. Assign a safe mineral field. Drones travel, warm their beam and break crystals; the fleet shares cargo. Bring it home and sell at the Converter.
3. Buy an earned-currency pack at the depot. It displays three saved, server-generated choices. Read each target, before/after change and drawback; choose one.
4. Combine mining, logistics and combat cards to earn faster and beat guarded fields. A high mining stat alone grants no right to mine through a living guard.
5. At the run's sale-and-clear milestone, confirm prestige at home. Every existing drone stays and **one new permanent drone** joins. Cards, cash, cargo and run progression clear. Repeat with a larger fleet.

There are no paid random packs, purchases with Robux, permanent card levels, level-up points or disappearing permanent drones. The permanent upgrade is fleet growth. Run build variety comes from the exact cards chosen for that expedition.

## What is permanent

Every drone stores its immutable ID, serial, type, name and base attributes in the profile. Death reprints the same drone free after ten seconds plus two seconds assembly; it does not remove a drone, reroll its traits, discard a named card or grant a fresh replacement to an already locked fight. Disconnect/reconnect also retains those identities and cards through the current run when persistence succeeds.

Prestige awards types in a repeating **Red → Green → Blue** sequence. The starter is Blue, so after the first two prestiges the fleet is Blue + Red + Green. Each prestige adds exactly one unit and preserves every earlier ID. There is no ownership cap; larger-fleet renderer performance still requires profiling.

| Built-in trait | Blue | Red | Green |
|---|---:|---:|---:|
| Mining DPS | 30 | 28.5 | 33 |
| Direct combat DPS | 12 | 13.8 | 11.4 |
| Hull | 80 | 80 | 80 |
| Laser warmup | .8 s | .8 s | .8 s |
| Combat shot interval | .8 s | .8 s | .8 s |
| Working range | 18 studs | 18 studs | 18 studs |
| Flight base | Seeded step ×1.15 | Seeded step ×1.00 | Seeded step ×1.00 |

The underlying base capped step is `(20 + ((profileSeed + serial × 17) % 31)) / 100`, a deterministic .20–.50 per 60 Hz reference step. Original eased approach, deceleration and hover still determine observed motion; this is not a constant-speed travel formula. Cards add against the stored type-adjusted base and never rewrite it. Startup-rate upgrades shorten only mining beam warmup; they do not double active damage.

## Pack economy and rules

| Pack number in this run | Price | Cumulative spend through this pack |
|---:|---:|---:|
| 1 | 80 | 80 |
| 2 | 110 | 190 |
| 3 | 150 | 340 |
| 4 | 210 | 550 |
| 5 | 290 | 840 |
| 6 | 400 | 1,240 |
| 7 | 520 | 1,760 |
| 8 | 676 | 2,436 |

Later prices repeatedly round the previous price ×1.30 to the nearest integer, capped at 1 trillion. Pack index and price reset on prestige. Buying a pack subtracts current credits, **never cumulative sale progress**. Prestige does not cost the sale requirement: it checks how much was earned from selling during the run. Starting from full safe-field cargo, Quartz pays 120 credits and Ruby 240 before yield/capacity upgrades.

The server accepts purchases/selection only at the depot while the player's own fleet is outside active combat. It checks run ID, request ID, expected pack index, funds, owned targets and useful options. The transaction commits before its result appears. A paid pending pack blocks a second purchase and prestige until the saved choice is resolved. Reopening it preserves all three cards and targets. Refunding a malformed offer is a narrowly validated migration/recovery operation, never a player reroll.

Current v4 offers draw from 41 standard cards plus 3 exhausted-pool reserves. They prefer a meaningful combat/survival answer, a productive economy answer, and an early conditional mechanic rather than three small variations of the same benefit. New cards carry a server-assigned Common, Uncommon or Rare tier. A seeded weighted candidate order uses relative weights 6, 3 and 1, but the compatibility, early-signature, economic and combat protections select the final triple, so tier is not a fixed drop percentage or a promise of stronger stats. Complete tier labels are saved with the offer; v3 or older saved offers without a tier remain unchanged and display no invented label. Limits exclude spent copies, absent drone types and benefits already entirely capped. All effects last until prestige; a new server does not extend them beyond the same persisted run.

## Build directions

These examples explain choices, not fixed loadouts or guaranteed draws. Actual saved offers may target a different named unit and all overlap is subject to caps.

| Direction | Useful cards | Decision / limitation |
|---|---|---|
| Fast safe miner | Blue Afterburners, Diamond Tip, Warm Emitters, Glass Cutter | Faster routes and breaks; Glass Cutter sacrifices hull for combat |
| Siege specialist | Battle Emitter, Siege Focus, Execution Lens, Pulse Cannon | Higher direct/finishing combat damage; Pulse Cannon loses mining and Siege Focus loses flight speed |
| Durable assault | Bulwark Network, Reinforced Frames, Ceramic Plating, Entry Shield | Hull + resistance + one shield improve survival; permanent traits still unchanged |
| Geode prospector | Core Drill or Prospector Rig, Long Lens, Shard Harvester | Cracks shells/cores and works clusters; geode damage does not buff ordinary crystals |
| Ore courier | Courier Network, Cargo Lattice, Clean Extraction, Green Recovery | More ore per break and more room; yield alone fills the same cargo sooner, it does not increase mineral value |
| Paired-guard breaker | Arc Relay, Long Lens, Salvage Reactor | One secondary hit can help clear a pair and kills restore hull; arc needs another nearby visible target, repair needs an actual kill |

Named specialist cards give a larger improvement to one drone; type/fleet cards spread an improvement across many. As the permanent fleet grows, Blue-only cards can reach several Blue drones, fleet cards reach everyone, and a single-target card may be less valuable for total throughput while still creating an assault specialist. Shared-cargo cards remain one player capacity increase, regardless of fleet count.

## Guarded progression

Safe Quartz and Ruby teach the loop and fund upgrades. Cobalt's single original pyramid is the first defense gate. Violet and Emerald field pairs demand more damage, survivability, arc positioning, a larger permanent fleet or effective evasion.

A four-second muster locks the exact owners/runs/drone IDs/lives and combat stats for an assault. Wipes, abandonment and the 90-second limit reset **all** turret damage and kills, followed by six seconds cooldown. Free reprints and late joins cannot reinforce that attempt. Partial kills grant no separate currency, so dying repeatedly cannot accumulate a clear. Only contributing current participants gain the guarded mining entitlement. Protected mining checks that entitlement per authoritative damage/reward; it ends as participants leave, and the cleared expedition closes after its eight-second grace.

Combat and mining choices compete because the player chooses only one card per pack. More ore on a safe route can fund the next pack, but the fleet still needs a finite successful assault to access richer fields and qualify for prestige. Q/Evade moves the assault flank; R/Recall ends participation. Skill can avoid a turret's locked-location telegraph without buying every defense card.

## Prestige milestones and exact reset

| Current permanent fleet / run | Cumulative sale credits required | Separate guarded clears required | Award |
|---:|---:|---|---|
| 1 | 2,000 | Cobalt ×1 | One permanent Red; fleet becomes 2 |
| 2 | 5,000 | Cobalt ×2 | One permanent Green; fleet becomes 3 |
| 3 | 11,000 | Violet ×1 | One permanent Blue; fleet becomes 4 |
| 4 | 22,000 | Violet ×2 | One permanent Red; fleet becomes 5 |
| 5 | 42,000 | Emerald ×1 | One permanent Green; fleet becomes 6 |

For run/fleet `n > 5`, required sales are `floor(42000 × 1.75^(n − 5))` and Emerald clears are `max(1, n − 4)`. The next type continues the Red/Green/Blue cycle. The beacon preview names the earned milestone, current/new fleet size and reset before explicit confirmation. An unresolved paid offer prevents prestige.

| Preserved | Reset |
|---|---|
| Every existing permanent drone ID, type, name, base traits and serial | All chosen run cards and modifiers, of every content version |
| Profile seed, permanent prestige count, settings, bounded transaction receipts | Current credits and material cargo |
| Newly earned additional permanent drone | Cumulative run sale earnings, pack index/prices and offer history |
| Durable ownership record | Current run's clear counts, mining entitlements and fractional yield remainders |

Profile and run identity advance atomically. The server rebuilds from permanent fleet ownership; stale old-run requests cannot apply an old choice to the new run. Shutdown/reconnect persistence and lease handling are described in [`PERSISTENCE.md`](../PERSISTENCE.md). Offline/unpublished Studio uses an explicitly labeled isolated temporary preview adapter. Load failures never overwrite valid profiles with starter defaults.

## Verification and pacing limits

Reproduce the production-domain card checks with `luau tests/cards.spec.lua`, the deterministic route/assault model with `luau tests/progression.spec.lua`, and the full source/server checks with `python3 tools/test.py /path/to/luau-tools`. Source/card behavior is covered by numerical tests; these are **not Studio visual or multiplayer playtests**.

Before the v3 upgrade change, the ten fixed modeled first runs required 6–8 choices and reached prestige in 413–546 seconds (median 474). With stronger baseline picks, six combo directions and deliberate offer variety, the same pre-map-refresh model completed with 4–6 choices in 390–513 seconds (median 416); second-run median moved from 761 to 744 seconds. The naked starter still loses Cobalt, and all ten seeds complete both prestige transitions. These are provisional **model outputs**, not claimed new-player timings. They omit skilled evasion, geodes/fork mining, scenery obstruction, networking, save latency and player decision time; later full runs are not modeled to completion. Final map coordinates can change these figures, so the current console output is authoritative over this comparison.

The pack prices, permanent bases, prestige thresholds, turret health/damage and direct-DPS cap were left unchanged by this card overhaul. The stronger picks make fewer choices feel useful sooner; the finite guard and sale requirements remain. The most useful remaining playtest questions are whether targets/tradeoffs are readable, whether paired guards make arc builds worthwhile, whether the shared hold interrupts later fleets too often, and how third-through-sixth full-run pacing feels.
