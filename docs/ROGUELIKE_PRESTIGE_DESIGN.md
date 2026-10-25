# Mining Away — run cards and permanent drone prestige

Status: implementation specification for the next prototype update. Numbers below are illustrative playtest starting points, not measured or optimal balance. This document supersedes conflicting economy, starting-fleet, progression, encounter-default, and presentation suggestions in the earlier gameplay design and cloud handoff. Retain server authority, multiplayer visibility, finite encounter participation, cleanup, and free-reprint safeguards. Preserve the existing shared cooperative assault implementation when practical, with the per-run entitlement rules below.

## 1. The game in one paragraph

Start with one permanent drone. Assign it to resource fields, watch it fly and mine, bring ore to the Converter, and spend credits on upgrade packs. A pack presents three random cards; choose exactly one modifier for the current run. Build around your permanent drones' colors, individual strengths, mining efficiency, and combat capability. Richer fields have different node counts, values, replenishment times, and turret defenses. Reach the run's prestige milestone, explicitly confirm the reset, and receive one additional permanent drone while losing every run card and other temporary run progress. Start again with the larger permanent fleet and build a different combination of cards.

The repeatable decision is: **buy another pack to improve this run, attempt a richer guarded field, or prestige now to expand the next run's fleet.** Buying packs must never move the prestige earnings requirement backward.

## 2. Preserve the prototype's feel first

1. Restore the supplied original drone following, flight, orbit/hover, assignment travel, and target approach. Restore original crystal appearance, growth, staged cracking, breaking, and replenishment. Use the supplied original source/place as the reference; inspect enabled scripts before replacing behavior. Existing broken or unsafe client authority need not be restored.
2. Keep those movement and crystal behaviors recognizable while moving authoritative state to the server. Cards change explicit parameters, not the animation vocabulary or whole movement algorithm. Presentation interpolation may remain client-side.
3. Retain the physical assign → fly → beam → crystal break → cargo → Converter route. Do not replace it with menus, instant currency collection, or an auto-battler screen.
4. The existing pyramid becomes a turret. Reuse its silhouette with a readable emitter, aiming, firing, damage feedback, and destruction. Do not require external art.
5. Build a simple alien clearing from Roblox parts: readable colored mineral fields, original-style crystals, several stylized trees, gentle terrain height changes, and a recognizable safe depot. Take the compact, approachable field layout and clear workspaces associated with Bee Swarm as spatial inspiration, without copying its assets or UI.
6. Validate the one-drone mining loop before adding prestige, elaborate map decoration, or more card content. If the drone flight or crystal growth looks worse than the original, fix that first.

## 3. Permanent fleet and built-in attributes

Each account starts with exactly **one permanent blue drone**. Never randomize the initial drone count. Prestige adds one drone and retains all existing permanent drones. No pack grants a permanent drone and no run purchase adds a temporary drone in this slice.

Use stable owned-drone IDs and short readable names. Ownership records survive the destruction/reprinting of their world models. Every drone has a built-in color/type, base mining DPS, combat DPS, maximum health, travel speed, laser startup delay, and working range. Baseline values come from the restored prototype and are normalized before applying modifiers.

| Type | Built-in identity, relative to the common baseline | Main use |
| --- | --- | --- |
| Blue / Scout | Travel speed ×1.15; other baseline attributes unchanged | Traversal and spreading assignments |
| Red / Sentry | Combat DPS ×1.15; mining DPS ×0.95 | Turret clearance |
| Green / Extractor | Mining DPS ×1.10; combat DPS ×0.95 | Productive mining |

These are deliberately mild, **provisional and configurable** differences; the user has not fixed the built-in attribute roster or exact values. Keep the same drone body where appropriate; color accents and a small type icon suffice. Existing intentional drone-specific attributes can be retained if they fit this model and are documented. Permanent ownership must not depend on these particular tuning constants remaining unchanged.

New prestige drones follow a disclosed deterministic sequence: Red, Green, Blue, repeating. Record the awarded drone ID/type atomically with the prestige transaction so retries never award duplicates. At least the first six owned drones must visibly function together. Do not silently discard, cap away, or stop simulating newly earned permanent drones; broader fleet performance limits can be decided after profiling.

## 4. Run and reset boundaries

Maintain a monotonically increasing `runIndex`, a run ID, and a content version. Store run cards separately from permanent drone records.

| State | On prestige |
| --- | --- |
| Existing permanent drone IDs, colors, base attributes | Keep |
| New permanent drone | Add exactly one |
| Prestige count, lifetime statistics, settings | Keep/increment as applicable |
| Every fleet, color, individual, and tradeoff card | Delete; no exceptions |
| Unspent credits, carried ore/material quantities | Set to zero |
| Run sale-earnings total, pack count, chosen-card history | Reset |
| Open/unclaimed card offer | Resolve the paid choice before prestige can confirm; clear its pending record during reset |
| Run field entitlements and run milestones | Reset for this player only |
| Shared turret encounter/world state | Never reset another player's active combat or earned entitlement merely because this player prestiges |
| World drone health/assignments/effects/reservations | End current activities; restore full fleet at safe depot |
| Permanent access requirement based on fleet/prestige count | Re-evaluate from permanent state |

Cards are tied to logical drone IDs, not models. A destroyed drone retains its run modifications when freely reprinted during the same run. A reprint is not a prestige and awards no new drone.

Preserve run state across disconnect/rejoin. Do not treat reconnecting as a free reroll, prestige, or reset. On first implementation, clearly report if persistence is unavailable; do not silently pretend a session-only implementation saves progress.

## 5. Mining, selling, and fields

The server records material type and ore quantity in cargo; the HUD can still show one capacity total. Different types sell for different values. Selling at the Converter atomically empties cargo, pays credits, and increases `runSaleEarnings` by the actual sale proceeds. Pack spending does not reduce that cumulative value. Turret kills and administrative test grants do not count as sale earnings.

Keep only **one spendable currency: credits**. No separate crafting wallet, mandatory contract board, delivery quest chain, or permit grind is needed for this update. Existing automatic material milestones may be retained if already useful, but the field defense and prestige milestones provide enough progression for the slice.

Illustrative field settings, expressed as design targets to tune against the actual restored mining speed:

| Field | Nodes | Ore units/node | Credits/ore unit | Replenishment after break | Defense / access |
| --- | ---: | ---: | ---: | ---: | --- |
| Landing Quartz | 12 | 10 | 1 | 8 s | Safe; always available |
| Ruby Grove | 16 | 12 | 2 | 14 s | Safe; available from the start |
| Cobalt Ridge | 6 | 15 | 4 | 25 s | One pyramid turret; first prestige objective |
| Violet Basin | 9 | 16 | 6 | 35 s | Two pyramid turrets; visible goal for fleet of 3+ |
| Deep Emerald | 12 | 20 | 8 | 45 s | Stronger paired turrets; later fleet target |

Use the turret difficulty itself as the main access gate. Keep Cobalt and its combat objective visible early, making combat cards understandable. Later-field fleet recommendations can be soft guidance; if a hard requirement is needed for this prototype, use an automatic owned-fleet milestone rather than an additional quest chain. Clearly label any such requirement. All fields still require a valid current-run clearance before guarded mining.

Do not replace the original crystal growth with instant spawning. Replenishment delay is separate from the visible growth animation. Keep a productive safe option available during every failed combat attempt. Show field identity, value category, defense state, and recommended strength near its entrance; keep full tuning numbers out of world labels.

Start cargo capacity around 120 ore units and make the first pack achievable after roughly one to two minutes of actual play. Tune capacity, values, and restored mining rates together. A full hold recalls drones using the original recognizable return behavior. Do not keep mining into a hidden overflow balance.

## 6. Cards and packs

Buying a pack spends credits, creates one persistent offer, and presents **three distinct eligible card choices**. Selecting one applies it once and closes the offer. The other two disappear. Do not grant all three. No paid rerolls, pack-opening delay, elaborate animation, or rarity machinery is needed for this prototype.

Suggested first-run pack price sequence: 80, 110, 150, 210, 290, 400 credits; then `round(previousPrice * 1.30)`. This curve resets on prestige. Keep the first packs equally affordable in later runs so the larger fleet's acceleration is immediately noticeable.

### Scopes and modifier math

- **Fleet:** affects all owned drones this run, or a named player stat such as cargo capacity.
- **Color:** affects all owned drones with that built-in color this run.
- **Individual:** affects exactly the drone selected by the server while generating that offered choice. Preview the drone's name, color, and identity on the card. Picking the card does not trigger another target roll.
- **Tradeoff:** a fleet-wide benefit and drawback shown together.

Use one explicit modifier pipeline. For each stat, add percentage contributions to the built-in baseline rather than multiplying arbitrary card stacks: `effectiveStat = typeAdjustedBase * (1 + sum(cardPercentages))`. Thus a +100% blue speed card and a +20% fleet speed card yield 2.20× that blue drone's built-in speed. In descriptions, “2× startup speed” means +100% startup **rate**, dividing the original startup delay by 2; it must not double the delay.

Allow fleet cards up to two picks per card ID; color/tradeoff cards once per card ID; individual cards once per `(cardId, droneId)`. Clamp prototype movement to 3× baseline, mining/combat/health to 4×, ore yield to 2×, capacity to 3×, range to 1.6×, critical chance to 30%, and effective startup delay to at least 0.08 seconds. Exclude choices whose entire benefit is already saturated. Show the actual effective change in the choice preview when a cap limits it.

Ore yield increases server-awarded units and consumes the corresponding cargo space. A fractional remainder may be tracked deterministically per player/material; never award fractional units by trusting clients. Splash and chained damage obey the same defense gate, range, ownership, target-death, reservation, and reward rules as ordinary damage.

### Initial 30-card catalog

“+X%” means an additive contribution in the pipeline above. Every value is a tuning starting point. All cards last only until prestige.

| ID / title | Scope | Exact effect |
| --- | --- | --- |
| F01 Sharper Beams | Fleet | +15% mining DPS |
| F02 Fast Rotors | Fleet | +20% travel speed |
| F03 Combat Calibration | Fleet | +20% combat DPS |
| F04 Reinforced Frames | Fleet | +20% maximum health; heal only the newly added max-health amount |
| F05 Ceramic Plating | Fleet | Reduce incoming turret damage by 10 percentage points; total damage reduction cap 50% |
| F06 Cargo Lattice | Player | +25% cargo capacity |
| F07 Warm Emitters | Fleet | +30% laser startup rate |
| F08 Clean Extraction | Fleet | +10% ore units awarded per crystal |
| C01 Blue Afterburners | Blue | +100% travel speed, equivalent to 2× speed alone |
| C02 Blue Lenses | Blue | +35% mining DPS |
| C03 Red Targeting | Red | +45% combat DPS |
| C04 Red Bulkheads | Red | +40% maximum health; heal only the added max-health amount |
| C05 Green Recovery | Green | +25% ore units awarded by these drones |
| C06 Green Ignition | Green | +75% laser startup rate |
| D01 Diamond Tip | One random eligible drone | +65% mining DPS |
| D02 Battle Emitter | One random eligible drone | +75% combat DPS |
| D03 Titanium Hull | One random eligible drone | +75% maximum health; heal only the added max-health amount |
| D04 Racing Rotors | One random eligible drone | +70% travel speed |
| D05 Instant Ignition | One random eligible drone | +100% laser startup rate, equivalent to half the delay alone |
| D06 Long Lens | One random eligible drone | +40% working range; does not increase assignment/command radius |
| D07 Turret Insulation | One random eligible drone | 25 percentage points less incoming turret damage, under the shared 50% cap |
| D08 Critical Optics | One random eligible drone | 15% chance per scheduled combat hit to deal 2× damage; server seeded |
| D09 Burst Splash | One random eligible drone | Combat hits also deal 25% damage to at most one other eligible turret within 6 studs |
| D10 Fracture Fork | One random eligible drone | Mining ticks also deal 20% damage to at most one other eligible crystal within 6 studs; never instant extra rewards |
| D11 Entry Shield | One random eligible drone | Absorb turret damage equal to 20% of built-in max health once per newly started encounter; no refresh on target switch |
| D12 Rapid Cycling | One random eligible drone | +35% combat firing rate; minimum firing interval 0.15 seconds |
| T01 Glass Cutter | Fleet | +35% mining DPS, −15% maximum health |
| T02 Battle Formation | Fleet | +30% combat DPS, −10% mining DPS |
| T03 Heavy Cargo | Player + fleet | +35% cargo capacity, −10% fleet travel speed |
| T04 Hot Emitters | Fleet | +40% laser startup rate, −10% maximum health |

For combat, separate damage per shot from shots per second: F03/D02/T02 modify shot damage; D12 modifies firing rate. Calculate advertised effective combat DPS from both and apply the final 4× combat-DPS cap after combining them. Health reductions clamp current HP to the new maximum and never kill an otherwise living drone. Do not sell a health card as a repeatable full heal. Pack purchasing/selection occurs at the depot outside active combat; if an old pending offer exists, resolve or postpone it outside the encounter rather than changing an encounter's snapshotted combat stats mid-fight.

### Eligibility and deterministic offers

An offer must never contain a color the fleet does not own, an already-owned unique modifier on its target, an exhausted stack, or a combat-only effect before the player can see an accessible guarded field. Individual target selection is random among eligible owned IDs sorted stably; it is not always the best drone and cannot be changed by reopening the UI. Initially expose straightforward mining, movement, cargo, and startup choices; enable combat choices as Cobalt Ridge and its objective become visible.

Generate offers on the server from a stable hash of `(serverSeed, UserId, runIndex, packIndex, cardContentVersion)`, using a dedicated RNG stream. Use an additional stable sub-seed for each individual-card target. Persist the generated three `(cardId, targetDroneId)` choices and charged price with the pending offer. Do not reconstruct a pending offer using a newly changed catalog. Selection validates that the offer belongs to the current run, that the selected choice is one of the persisted choices, and that it has not been claimed. Buying, charging, selecting, and prestige each require idempotent transaction IDs. Only one pending offer per player.

Prefer three different scopes when eligible, but do not force this when it would make a starter offer useless. Use uniform weights within eligible content for the first slice. Once the Cobalt objective is visible, guarantee at least one direct combat-damage, health, shield, or turret-resistance choice in every third offer if an eligible useful option exists: never generate more than two consecutive offers without one. Persist this generation counter and make deterministic replacement of a choice obey the same distinct-choice/eligibility rules; reopening or declining a combat choice does not alter the offer history. This protects against an unlucky sequence preventing a viable first assault.

If fewer than three valid choices remain, use a deliberately defined repeatable fallback (+10% mining, +10% combat, or +10% capacity, subject to caps); never hang the shop or charge for an empty offer. If all useful caps are reached, stop selling packs and explain the available prestige objective.

## 7. Turrets make the build matter

Assigned drones fight a field's turret defenses before mining its resources. Mining-focused cards increase earnings and pack access; combat/health cards make valuable defended fields attainable. Color and individual cards encourage mixed specialization without requiring a separate loadout editor.

Prefer the existing **shared, finite cooperative encounter**. A visible patch has one coherent turret roster, health state, and encounter ID. Lock eligible participant `(UserId, runId)` pairs and their committed drone IDs when an assault begins; outsiders, late arrivals, newly earned drones, and replacements cannot reinforce that locked attempt. No mining or ore rewards while its defense gate is closed. On victory, participating eligible player/run pairs receive a clearance entitlement, and their surviving crew naturally transitions to mining. A late arrival cannot freely mine another crew's cleared field: show that an expedition is in progress and allow them to join the next fresh assault.

A destroyed drone reprints free at the depot with ownership and current-run cards intact, but its replacement cannot re-enter that unfinished attempt. A complete eligible-roster wipe or complete disengagement/abandonment ends the shared attempt and resets all unfinished turret health. One player's retreat/disconnect ends that player's participation, but surviving eligible teammates may continue; it must not reset their shared fight. Repeated free respawns never add combat capacity to the same attempt or gradually wear down an unbeatable patch.

Successful clearance lasts for the current shared field expedition, bound to its encounter and each entitled player's run ID. Resource replenishment alone does not respawn defenses on top of an active mining crew. End/reset the shared expedition when all entitled crews finish/leave under the documented existing grace rule; clear its defense/resource entitlement consistently. **Prestige removes only that player's entitlement and participation. It never resets other players' combat, health, access, or world targets.** Validate `(player, currentRunId, encounterId)` at every guarded mining tick so stale pre-prestige access cannot survive.

If technical constraints force owner-isolated encounters, document the choice and a coherent visible representation: separate physical instance/area or a clearly owner-labeled encounter, rather than coincident duplicate pyramids with contradictory health bars. Do not combine private clearance with globally shared damaged turrets. This fallback is not a request to replace a working shared system.

Stay within a modest command radius around the player, approximately 70–100 studs after testing the original map scale. Existing follower radius is a separate setting. Permit one active field assignment per drone; no indefinite multi-field job queue. Scouting within that working area is allowed. Leaving the command radius for a short grace period recalls the affected crew and ends that player's participation; the shared encounter ends only when its shared wipe/disengagement rule is met. This bounds offscreen activity while preserving the original follow/assign feel.

## 8. Prestige milestones and pacing targets

Requirements use cumulative sale proceeds in this run and explicit encounter wins. They never require hoarding unspent credits. Mark eligible prestige prominently but allow the player to keep playing the current run. No forced reset.

| Prestige about to earn | Fleet before → after | Illustrative run sale requirement | Other run milestone | Illustrative active duration |
| --- | --- | ---: | --- | --- |
| 1 | 1 → 2 | 2,000 credits | Clear Cobalt Ridge once | 12–18 min |
| 2 | 2 → 3 | 5,000 | Clear Cobalt twice in separate expeditions | 15–22 min |
| 3 | 3 → 4 | 11,000 | Clear Violet Basin once | 18–25 min |
| 4 | 4 → 5 | 22,000 | Clear Violet twice | 20–30 min |
| 5 | 5 → 6 | 42,000 | Clear Deep Emerald once | 25–35 min |

These durations are hypotheses to test, not promises. If the first run needs excessive safe-field farming before a useful combat pack, adjust prices and first turret health before adding grind rewards. Tune early post-prestige minutes to feel substantially faster because two or three drones act visibly in parallel. Later milestone increases and richer field requirements keep permanent fleet growth from instantly completing the next run.

Prestige confirmation states the exact exchange: “Gain one permanent Red drone. Keep your existing 1 drone. Reset credits, cargo, field clearance, and all 6 run cards.” Use actual values and awarded type. Confirm only from the safe depot, after resolving any purchased pending offer, with that player's drones outside an active encounter. Server validation repeats eligibility and completes the reset and permanent grant atomically. Double-clicking cannot gain two drones, and another player's encounter must continue undisturbed.

## 9. Minimal HUD, shop, and choice presentation

- **HUD:** one compact credits value; cargo fill and amount; small permanent-fleet count; one current objective/prestige line. Use the original game's visual vocabulary where present. Avoid generic dashboards, translucent panel stacks, large empty cards, or long floating labels.
- **Shop:** a physical, clearly labeled pack machine at the depot. One interaction displays the next price and “Open pack.” A minimal panel is acceptable; a fullscreen storefront is unnecessary.
- **Pack choice:** three compact cards side by side on desktop and a readable stacked/scrolling arrangement on mobile. Each shows title, type/color or named drone target, one precise effect, drawback if any, and “This run.” Select once, confirm visibly, return to play promptly. Do not use ambiguous “2× startup” wording.
- **Drone inspection:** clicking a drone/compact fleet control shows its color, base identity, current effective key stats, and unique run mods. No full-screen inventory is required.
- **World feedback:** readable laser origin/endpoint, original crack stages, visible ore pickup/cargo response, one turret health indicator during combat, and clear drone damage/destruction/reprint feedback. Keep permanent fleet ownership distinct from temporarily active drone count.
- **Style:** simple light text, strong mineral/type colors, small solid dark backgrounds only where needed for contrast, consistent spacing, ordinary Roblox-friendly typography. No invented rarity gradients or decorative UI unrelated to the world.

## 10. Implementation order and acceptance

1. Compare the latest implementation to the original source and restore drone movement/crystal behavior. Produce a playable one-blue-drone safe mining → full cargo recall → sell loop in the alien parts-and-trees map.
2. Add permanent owned-drone records, authoritative run state, correct material values, and the pack price curve.
3. Implement pending three-choice offers and modifier aggregation. First exercise F01, F06, C01, D05, D02, and T01 end to end; then enable the full catalog through data entries.
4. Integrate the existing pyramid turret, combat gating, free reprint, and full failed-attempt reset. Show the accessible combat objective early enough that combat cards have context.
5. Add milestone validation and atomic prestige. Replay a complete second run with two visible, effective permanent drones and fresh card offers.
6. Polish only the compact HUD/card choice and essential world feedback. Expand fields/art only after the core loop passes.

Required validation:

- A brand-new account starts with exactly one permanent blue drone. It visibly follows, travels, mines, and watches crystals grow/break in the restored style.
- A purchased pack spends the displayed price once, presents three valid choices, and grants precisely one. Repeated requests, reopening, reconnecting, and late UI delivery never reroll or double-claim it.
- C01 affects all and only blue drones; D05 affects the offered named drone and halves baseline startup delay when alone; its effect survives a same-run free reprint.
- Combat card values change actual authoritative encounter outcomes. A mining-heavy build can still safely earn credits after a failed assault.
- Different field types produce the configured material/value/replenishment behavior. Sale proceeds, capacity, and prestige earnings agree.
- Repeated weak-fleet wipes and reprints never accumulate turret damage or guarded ore. Successful clearance leads directly into mining, and expedition end resets the gate consistently.
- Prestige leaves every old permanent drone, adds exactly one of the disclosed type, deletes every run modifier including hidden individual effects, and resets exactly the state in the reset table. Another player's active shared fight and entitlement survive unchanged.
- Repeated prestige requests award only one drone. A pending offer from an earlier run cannot apply to the new run. Rejoin preserves legitimate run progress.
- Two eligible players can cooperate against one coherent visible turret roster, with finite locked drone participation and separate credits/cards/fleet ownership. A late joiner sees correct fleets/effects but cannot reinforce or inherit mining access without an entitlement. Pre-prestige entitlements fail after the owner's run ID changes.
- Desktop and touch controls permit assigning, recalling, selling, buying, reading all three choices, and selecting a card without text clipping.

Cloud work should return the updated place/source and a candid validation report. If Studio, persistence credentials, or multiplayer execution are unavailable, still finish source integration, local checks, data validation, and exact Studio verification steps. Distinguish executed checks from unexecuted ones. Do not publish the experience, purchase assets, or claim visual/multiplayer success from static inspection.
