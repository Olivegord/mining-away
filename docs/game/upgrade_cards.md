# Complete upgrade card reference

This is the complete current offer catalog: **41 normal cards and 3 reserve cards**, implemented in [`src/Cards.lua`](../../src/Cards.lua), content version **3**. It is a numerical reference you can review without opening Studio. The descriptions below cover every card, target rule, drawback, stack limit and conditional effect. They describe code behavior; judging animation quality, readability and combat feel still requires the game.

## Reading the numbers

Every card is temporary **for this run, until prestige**. Death, free reprinting, disconnecting and reconnecting preserve the chosen card and its exact permanent target. There are no permanent card upgrades, paid random packs, card rarity tiers, consumable rerolls or Robux purchases.

Unless a row says otherwise, `+X%` adds X percent of the drone's immutable, type-adjusted **base**, rather than multiplying its already upgraded stat. For example, Sharper Beams (+25%) plus Diamond Tip (+90%) gives that Blue drone `30 × (1 + .25 + .90) = 64.5` mining damage per second. Two Sharper Beams give +50%, not ×1.25². A negative modifier subtracts from that same base. Caps can reduce a card's realized benefit; the saved offer contains actual before/after values for one affected drone that gains a stat change, plus shared cargo where applicable. It saves that example drone’s name; a capped first fleet member is skipped when another drone benefits.

Scope meanings:

- **Fleet:** every permanent drone you currently own. Shared capacity is added once per card, even when bundled in a fleet card.
- **Type:** every drone of the specified permanent Blue/Red/Green type. A type you do not own cannot be offered.
- **Named:** exactly one permanent drone, chosen randomly by the server from eligible owned drones **before showing the pack**. The offer saves its ID, name and type. A target is eligible only if the card would improve an uncapped stat and its per-target copy limit is unused. Reprints and reconnects do not reroll it. There is one resolved target per named card in an offer, not a choice of targets.
- **Tradeoff:** fleet-wide benefits and penalties, except shared cargo still applies once to the player.

## Fleet and shared cargo cards

All these cards have **no stat penalty**. The maximum copies column is per run, across the player's fleet.

| ID | Card | Scope | Exact effect per copy | Maximum copies |
|---|---|---|---|---:|
| F01 | Sharper Beams | Fleet | +25% mining damage per second | 2 |
| F02 | Fast Rotors | Fleet | +30% flight speed/capped step | 2 |
| F03 | Combat Calibration | Fleet | +30% combat shot damage, before combined direct DPS cap | 2 |
| F04 | Reinforced Frames | Fleet | +35% maximum hull; restore only the added hull on a living drone | 2 |
| F05 | Ceramic Plating | Fleet | +15 percentage points incoming turret damage reduction | 2 |
| F06 | Cargo Lattice | Player | +35% shared capacity; 120 → 162 units alone, 204 with two | 2 |
| F07 | Warm Emitters | Fleet | +50% startup rate; `.8 / 1.5 = .5333…` seconds warmup alone | 2 |
| F08 | Clean Extraction | Fleet | +20% awarded ore units; uses matching cargo space | 2 |
| F09 | Prism Splitter | Fleet | Mining ticks also deal 20% mining DPS to one eligible secondary crystal within 12 studs of the primary | 1 |
| F10 | Bulwark Network | Fleet | +25% maximum hull **and** +10 percentage points turret damage reduction | 2 |
| F11 | Courier Network | Fleet/player cargo | +15% awarded ore, +20% flight speed **and** +20% shared capacity; 144 capacity alone | 2 |

Bulwark combines hull and resistance; it does not grant an entry shield. Courier capacity is a single shared increase, not +20% for each drone. Hull upgrades do not fully repair existing damage: a drone missing 30 hull remains missing 30 hull after the added maximum is restored.

## Built-in type cards

All these cards have **no stat penalty**, with **one copy per run**. They affect every drone of the named type, including multiple Blue drones in a later permanent fleet.

| ID | Card | Target | Exact effect |
|---|---|---|---|
| C01 | Blue Afterburners | All Blue | +100% base flight speed; ×2 alone |
| C02 | Blue Lenses | All Blue | +50% mining damage per second |
| C03 | Red Targeting | All Red | +65% combat shot damage |
| C04 | Red Bulkheads | All Red | +60% maximum hull; restore only the added hull |
| C05 | Green Recovery | All Green | +40% ore units awarded by Green drones |
| C06 | Green Ignition | All Green | +100% startup rate; halve warmup alone; active mining/combat damage unchanged |

## Named drone cards

All named cards have **one copy per permanent target per run**. Another copy of the same ID can be offered later only if a different owned drone is eligible. Positive conditional fractions still share the global stat caps below with fleet and other named cards.

| ID | Card | Exact effect | Drawback |
|---|---|---|---|
| D01 | Diamond Tip | +90% mining damage per second | None |
| D02 | Battle Emitter | +100% combat shot damage; ×2 alone | None |
| D03 | Titanium Hull | +100% maximum hull; restore only the added hull | None |
| D04 | Racing Rotors | +100% base flight speed; ×2 alone | None |
| D05 | Instant Ignition | +100% startup rate; `.8 → .4` seconds warmup alone | None; it does **not** double active damage |
| D06 | Long Lens | +40% working range; `18 → 25.2` studs alone | None; command radius remains 95 studs |
| D07 | Turret Insulation | +25 percentage points turret damage reduction | None |
| D08 | Critical Optics | +15 percentage points server-rolled critical chance; a crit doubles that combat hit | None |
| D09 | Burst Splash | +20% combat shot damage; one eligible secondary sentry receives 15% of hit damage within **22** studs of primary | None |
| D10 | Fracture Fork | One eligible secondary crystal receives 20% mining DPS within 6 studs of primary | None |
| D11 | Entry Shield | Absorb 20% of built-in hull (16 with normal 80 base hull) once per fresh assault | None; no refill during that assault |
| D12 | Rapid Cycling | +35% combat firing rate; `.8 / 1.35 = .59259…` seconds between shots alone | None; combined direct DPS stays capped |
| D13 | Execution Lens | +75% conditional combat hit damage when the primary sentry starts that hit at **≤35%** maximum hull | None |
| D14 | Core Drill | +80% mining damage to geode shells and cores; ×1.8 alone | −15% flight speed |
| D15 | Salvage Reactor | Each sentry killed by this drone's direct or secondary hit repairs 30% built-in hull (24 with 80 base), capped at its current maximum hull | None |
| D16 | Arc Relay | One eligible secondary sentry receives 25% hit damage within **22** studs of primary | None |
| D17 | Siege Focus | +45% combat shot damage **and** +50% conditional finishing damage at ≤35% sentry hull | −15% flight speed |
| D18 | Pulse Cannon | +50% combat firing rate **and** +15% combat shot damage; ×1.725 direct DPS alone before cap | −20% mining DPS |
| D19 | Prospector Rig | +60% geode-shell/core mining damage **and** +20% awarded ore | −15% flight speed |
| D20 | Shard Harvester | +25% mining DPS **and** split 20% mining DPS into one eligible secondary crystal within **12** studs | −15% maximum hull |

Battle Emitter + Pulse Cannon on one otherwise unmodified drone would calculate `(1 + 1 + .15) × (1 + .50) = 3.225` times base direct DPS, while taking Pulse Cannon's −20% mining. Diamond Tip + Shard Harvester calculate ×2.15 primary mining, with one secondary receiving 20% of that upgraded mining DPS if eligible.

## Fleet tradeoffs

Each is **one copy per run**. Both the benefit and penalty affect all owned drones, except the shared capacity benefit applies once.

| ID | Card | Benefit | Drawback |
|---|---|---|---|
| T01 | Glass Cutter | +60% fleet mining DPS | −20% fleet maximum hull |
| T02 | Battle Formation | +60% fleet combat shot damage | −20% fleet mining DPS |
| T03 | Heavy Cargo | +60% shared cargo; 120 → 192 alone | −15% fleet flight speed |
| T04 | Hot Emitters | +100% fleet startup rate; halve warmup alone | −20% fleet maximum hull |

Reducing maximum hull clamps current hull to the new maximum; it never kills a living drone during a stat refresh. A hull penalty can make the next turret fight substantially less forgiving.

## Exhausted-pool reserves

These are the only additional possible card IDs. They enter the candidate pool only if fewer than six useful normal resolved cards remain. They follow the same combat visibility and useful-choice rules. They are not a separate reward or a guaranteed pack outcome.

| ID | Card | Scope | Effect per copy | Copy limit |
|---|---|---|---|---:|
| R01 | Mining Reserve | Fleet | +10% mining DPS | 500, with useful-stat cap filtering |
| R02 | Combat Reserve | Fleet | +10% combat shot damage | 500, with useful-stat cap filtering |
| R03 | Cargo Reserve | Player | +10% shared capacity | 500, with useful-stat cap filtering |

The profile itself accepts at most 500 chosen run cards. In ordinary catalog play the useful-stat caps exhaust reserve choices much sooner. If three distinct useful choices cannot be formed, the purchase fails **before charging credits or increasing pack index** and directs the player toward prestige.

## Final stat caps and formulas

`sum` means the sum of matching chosen card effects. Permanent bases remain unchanged. These caps include all scope overlaps and combo cards.

| Stat | Calculation / final limit |
|---|---|
| Mining DPS | `baseMining × clamp(1 + sum(mining), .1, 4)` |
| Flight step/speed | `baseStep × clamp(1 + sum(speed), .1, 3)`; original eased/capped movement still applies |
| Maximum hull | `baseHull × clamp(1 + sum(health), .1, 4)` |
| Shared cargo | `floor(120 × clamp(1 + sum(capacity), .25, 3))`, normally 30–360 units |
| Warmup | `max(.08, baseWarmup / max(.1, 1 + sum(startup)))` seconds; no active-DPS bonus |
| Combat interval | `max(.15, baseInterval / max(.1, 1 + sum(rate)))` seconds |
| Direct combat | Nominal damage = `baseDPS × baseInterval × clamp(1 + sum(combat), .1, 4)`; final DPS = `min(4 × baseDPS, nominalDamage / finalInterval)`; actual shot damage = final DPS × final interval |
| Working range | `baseRange × clamp(1 + sum(range), .1, 1.6)`; 28.8 studs maximum with normal base 18 |
| Ore yield | `clamp(1 + sum(yield), .1, 2)`; at most twice the base ore units |
| Turret reduction | `clamp(sum(reduction), 0, .5)`; at most 50% incoming damage blocked |
| Critical chance | `clamp(sum(crit), 0, .3)`; at most 30% double-hit chance |
| Combat splash | `clamp(sum(splash), 0, .25)` to **one** eligible secondary sentry |
| Arc reach | `6 + clamp(sum(chain), 0, 16)` studs from primary; at most 22 |
| Mining fork | `clamp(sum(fork), 0, .2)` to **one** eligible secondary crystal |
| Fork reach | `6 + clamp(sum(forkRange), 0, 6)` studs from primary; at most 12 |
| Geode modifier | `1 + clamp(sum(geode), 0, .8)`; at most ×1.8 against shell/core |
| Finisher modifier | `1 + clamp(sum(finisher), 0, .75)`; at most ×1.75 below/at threshold |
| Kill repair | `baseHull × clamp(sum(salvage), 0, .3)` per newly killed sentry, capped by missing current hull |
| Entry shield | `baseHull × clamp(sum(shield), 0, .2)` per fresh assault; built-in hull, not card-expanded hull |

The ×4 direct DPS cap covers the shot damage/firing-rate combination. **Conditional finisher and critical multipliers apply after it**; secondary damage is separately capped. Therefore a conditional hit can exceed ×4 base DPS. Example: a capped direct attack can get ×1.75 finishing damage and a ×2 crit on the same hit; one secondary can then receive 25% of that resulting hit. The benefit vector and card text do not promise every shot is critical or that another target will exist.

## Conditional mechanics, precisely

- **Startup:** begins when the drone is settled above a ready crystal with line of sight. Moving out of its mining position clears that warmup. Startup changes this delay, not combat shot timing or damage to an already active crystal.
- **Ore:** the drone that breaks a paying ordinary crystal/core/shard supplies its yield modifier. Fractions accumulate per mineral in the run and award whole units. Full cargo clamps acceptance; overflow is discarded. A geode shell itself awards no ore; it exposes a core worth four ordinary-node yields plus four ordinary-yield shards.
- **Geode damage:** applies independently to shells and cores on primary or secondary mining hits. It does not improve ordinary/shard damage, shell drop count or cargo value. A geode multiplier and ordinary mining bonuses multiply because they modify different parts of the damage calculation.
- **Fork mining:** requires the primary still exists after its tick, the drone is settled above that primary, secondary is grown/alive in the same mineable field, secondary has a free reservation slot, secondary lies within fork reach of primary **and** within the drone's working range, and secondary line of sight succeeds. It does not fork a fork. No valid target means no bonus damage. It does not turn one crystal into two rewards.
- **Combat:** only the locked current-assault roster may deal turret damage. Its combat stat snapshot freezes for that attempt; cards can be chosen only at home outside the player's active encounter. A hit must satisfy working range and line of sight.
- **Finishing/critical hits:** the server checks primary HP against `maxHP × .35` before applying finishing damage, then rolls critical chance. A hit starting above 35% does not gain the bonus merely because it crosses the threshold. The secondary receives a fraction of this primary hit; it does not separately roll a critical or evaluate its own finisher threshold.
- **Splash/arc:** first eligible other living sentry in the same field, within arc reach of primary, within drone working range and line of sight. At most one secondary. No bounce recursion, tertiary damage, other player's drone damage or hit through scenery. D09 offers +20% direct shot damage and a 15% arc at 22 studs; D16 offers a stronger 25% arc at the same 22-stud reach. Combining them keeps +20% direct damage and caps the secondary at 25%, not 40%. A saved pre-v3 D09 retains its old 25%/6-stud payload.
- **Repair:** only the killing drone receives Salvage repair. A primary and secondary kill in the same attack can each grant one 30%-base-hull repair. No repair from surviving damage, recalled turrets or later reset; no repair above maximum hull.
- **Entry shield:** starts once at the gathering-to-active assault transition; incoming turret damage reduction applies before the remaining shield absorbs damage. It cannot regenerate through repeated dodging, reprints or joining late. New lives cannot reinforce that locked attempt.

## Offer generation and saved choices

The server seeds a deterministic shuffle from profile seed, owner ID, run index, next pack index and `CONTENT_VERSION`. It resolves eligible named targets, removes owned copy limits and cards with no uncapped benefit, then searches for a pairwise non-dominated triple. An equally priced option that improves every compared effective stat at least as much as another, or an exactly equivalent result, cannot share that pack with it. Conditional multipliers/reaches are compared as capabilities, not predictions of real encounter value. Dormant fork/arc range alone counts as zero benefit until the secondary damage exists.

Triple priority is: include useful combat/survival when combat is visible; include useful mining/travel/startup/cargo; include a conditional signature mechanic in the first three packs when a compatible triple permits it; then prefer different categories and scopes. Seeded order breaks equal scores. Thus cards have **no equal-probability or rarity odds**: ownership, type eligibility, caps, targets, compatibility and these variety rules affect which outcomes appear. If one lane is exhausted, useful valid triples remain possible without it. `offersWithoutCombat` still records the saved history.

All three complete choices, exact effects, previews, targets, price and content version are saved before disclosure. The player chooses exactly one. Closing a menu, a lost response, reconnecting, or buying again under a new request ID cannot reroll or charge that pending offer. Selection applies the **saved payload**, never a lookup in the newer catalog. Consequently a pre-v3 Sharper Beams card/paid offer remains its original +15%, and pre-v3 Cargo Lattice remains +25%; documentation above describes newly generated v3 offers. Prestige clears both old and new run cards.

Source and verification: [`Cards.lua`](../../src/Cards.lua), [`Profile.lua`](../../src/Profile.lua), [`Server.lua`](../../src/Server.lua), [`cards.spec.lua`](../../tests/cards.spec.lua), [`server.integration.lua`](../../tests/server.integration.lua). The card suite exercises randomized offer coverage, target persistence, caps, exact saved v2 offers, six new combo outcomes, disclosures and transactions; server integration executes production server logic with API doubles, not Roblox rendering/networking.
