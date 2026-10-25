# Game design: the implemented Mining Away loop

This is the source-backed design reference for the current game. “Implemented” describes code that exists; it does not claim an engine playtest has passed. [Owner requirements](../OWNER_REQUIREMENTS.md) take priority over this document. Read [the implementation plan](implementation_plan.md) for remaining acceptance and proposed work.

## Player experience and scope

The player commands a permanent fleet of small hovering drones on an alien mineral landscape. Mining funds temporary cards; a stronger run build defeats pyramid sentries protecting richer fields. An earned prestige resets the run and adds one permanent drone. The fleet carries the player's long-term growth while card choices create a different build inside each run.

The game preserves the original drone model, crystal union, segmented pyramid construct, parts-built trees, smooth eased flight and visible crystal fractures. The intended presentation is a readable connected working landscape: depot and machines, safe mining fields, guarded approaches and distinct mineral clearings. Consult [map_reference.md](map_reference.md) for actual geometry, routes, colors and lighting; this document does not invent a second map.

There are no paid random packs, Robux purchases, trading, PvP, manual drone purchases or permanent card upgrades in this implementation. The only implemented source of additional permanent drones is prestige. Field recommendations are guidance, not hard fleet-size unlocks.

## The run, step by step

1. A new profile receives exactly one permanent **Blue 1** drone, zero credits, no cargo and no cards.
2. Click/tap a field or press its number. The fleet travels there, chooses ready available crystals, settles over them, warms its lasers and mines.
3. Collected mineral units fill one shared cargo hold. Recall or allow the full-hold return, then walk to the original Converter and sell. Return does not sell automatically.
4. At the depot card machine, spend earned credits on a pack. The server saves three resolved choices before displaying them. Choose exactly one; the other two are not installed.
5. Use mining, cargo, movement, combat and survival cards to prepare for guarded fields. Their sentries must be defeated in a finite assault before that run may mine there.
6. Meet the cumulative sale-credit and guarded-victory milestone. At the prestige beacon review exactly what stays/resets, then confirm.
7. Keep every existing permanent drone, gain one new permanent drone and start a fresh run with no prior run cards or currency. Repeat with a larger fleet.

There is no separate auto-selling, idle/offline income or prestige currency system in current source. Reprints restore owned units for free; they do not grant another permanent unit.

## Controls and decisions

| Control | Behavior |
| --- | --- |
| Click/tap a field | Request assignment of living owned drones to that field. The server checks command distance and encounter state. |
| `1`–`5` | Request the corresponding field; the same server distance/eligibility gates apply. |
| `R` / Recall button | End your own field participation, release mining reservations and bring the fleet home. |
| `Q` / Evade button | Switch the assault flank of your participating drones. Server cooldown is two seconds. |
| `E`, contextual Use button, native station prompt | Sell at Converter or open the nearby card/prestige screen. Opening a screen does not bypass the station/range rules for a transaction. |
| Fleet button | Inspect permanent units and current effective stats. |
| Close / Escape | Close an offer/modal. A paid pending offer stays saved; closing cannot reroll or refund it. |

The current combat target selector automatically chooses the nearest live sentry for each drone. Manual sentry priority or a free-position command is not implemented. Existing combat decisions are card build, field choice, starting/joining a fresh muster, timing the flank switch against a frozen telegraph and retreating before a wipe.

## Permanent drones and base traits

Every owned drone has a stable ID such as `123:drone:1`, a readable name, a built-in type and saved base stats. Reprinting changes its runtime life number; it does not change permanent ID or reroll its traits. Base travel speed is generated once from the saved profile seed and serial. Effective card-modified stats are calculated separately from the saved base, preventing modifier multiplication after reconnect.

| Built-in type | Permanent identity / base specialization |
| --- | --- |
| Blue | Flight cap ×1.15; base mining/combat unchanged. The first drone is Blue. |
| Red | Base combat ×1.15; base mining ×0.95; ordinary flight cap. |
| Green | Base mining ×1.10; base combat ×0.95; ordinary flight cap. |

Common base stats before type scaling are 30 mining work/second, 12 nominal combat DPS, 80 hull, 0.8-second laser warmup, 18-stud combat working range and a 0.8-second shot interval. Generated travel caps begin at `0.20..0.50` studs per 60 Hz reference frame before the Blue bonus. A cap is a maximum; easing makes the final approach slower.

Prestige adds types in the permanent sequence **Red, Green, Blue**, then repeats. The first four owned types are therefore Blue, Red, Green, Blue. There is no permanent ownership cap in source. Visual/performance acceptance still has to establish the supported simultaneous population; an unlimited data model is not evidence of unlimited rendering capacity.

## Original flight and arrival

`Feel.lua` preserves the original 3% position easing and per-drone step cap at 60 Hz, corrected for elapsed time. Level yaw uses the original 10% turn blend with elapsed-time correction. Follow formation is a world-aligned radius-10 ring, seven studs above the owner, with a small one-third-stud hover and roughly 6.28-second period. Cards changing speed do not reroll the drone's saved hover phase.

Ordinary mining stations are directly over the assigned crystal X/Z at `crystal center + (0, 10, 0)`. The server requires the logical drone position within one stud of that station, an authorized field, a ready resource and a valid reservation/line of sight before warmup and mining. A beam passing close to a crystal or a client model visually reaching it cannot produce damage.

All clients render all drones smoothly from replicated authoritative goals/poses. Their local interpolation never replaces server range checks. The body stays level and yaws horizontally; its beam aims independently at the visible shrinking crystal surface.

## Fields and resource economy

`Config.Fields` is the tuning source. Field IDs follow this order. Values below are current code values, not a measured balance recommendation.

| Field | Maximum node budget | Ore / ordinary crystal | Credits / ore unit | Replenishment delay | Sentries | Hull / sentry | Sentry shot damage | Suggested fleet |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 Landing Quartz | 12 | 10 | 1 | 8 s | 0 | — | — | 1 |
| 2 Ruby Grove | 16 | 12 | 2 | 14 s | 0 | — | — | 1 |
| 3 Cobalt Ridge | 6 | 15 | 4 | 25 s | 1 | 260 | 19 | 1 |
| 4 Violet Basin | 9 | 16 | 6 | 35 s | 2 | 390 | 24 | 3 |
| 5 Deep Emerald | 12 | 20 | 8 | 45 s | 2 | 650 | 34 | 5 |

Replenishment delay starts on ordinary/core/shard depletion; replacement crystals then have a two-second grow-in before mining. A depleted visual remains briefly for break feedback. Placement can fail and retry when a field has no valid separated spawn candidate, so the budget is a ceiling, not a promise of every slot always being occupied.

Crystals have server-random positions inside the field, with at most 18 inset/separation attempts and turret clearance. Each otherwise valid candidate also requires a clear vertical center column through the current map's solid scenery: a server ray from 64 studs above field center to just above the field surface includes only `scene.map`. Decorative non-queryable geometry is excluded. A blocked candidate consumes no node budget; exhausted attempts defer placement rather than bury a resource. This column check is not a complete volume-overlap test. Rotated field sampling uses the field transform. Ordinary max health is randomly 50–100, and original union size scales with it: roughly 2–4 studs before fracture shrink. Randomness is selected once by the server and replicated, never rolled independently by viewers.

### Ordinary mining lifecycle

```text
Spawn → grow/rise for 2 seconds → ready → reserved → arrival/warmup
  → mining → 75% fracture → 50% fracture → 25% fracture → depleted
  → break feedback / cleanup → replenishment delay → next server-random spawn
```

An ordinary crystal supports one reservation. Drones choose nearby ready unfilled resources; if none exist they wait near the field. Warmup restarts after losing the arrival condition or target. Damage runs on the server's fixed simulation step, not on client frame count. The original ten-health depletion cutoff is normalized into effective work: a max-health-100 crystal needs 90 work; at base 30 mining/second this is three active laser seconds after arrival and warmup.

Three stages mean **three changes at 75%, 50%, 25% remaining displayed health**, followed by depletion. Render scale changes from intact to `0.75 → 0.50 → 0.25`, with deterministic stage rotation, crack feedback and break. If fast damage crosses several thresholds between packets, the cosmetic queue briefly shows each stage in order; gameplay rewards do not wait for that animation. A newly joining viewer initializes from current damage, without replaying old cracks.

Depletion is atomic: a resource can be paid only once. The finishing authorized drone's owner receives its mineral reward, even when multiple eligible drones helped mine it. Cargo bonuses award extra ore units and consume matching hold space. Fractional yields accumulate per mineral in saved run remainders, rather than rounding every bonus away. Cargo is truncated at available capacity; overflow is not banked as hidden ore.

### Geodes

Fields after Quartz may generate a geode when there are at least five free budget units; the server spawn roll is 12%. A shell reserves five population units and has triple ordinary health, larger size and up to three closely bounded overhead mining stations. Breaking its shell grants no direct ore. It opens one core (four times the ordinary field ore reward) and four shards (ordinary ore each). Those children must be mined to earn cargo.

Shell opening is one authoritative transition, so simultaneous finishing hits cannot duplicate the children. Replenishment consumes the corresponding population tokens. Geode/core-specialized cards affect real server damage; general crystal appearance and staged mining remain in use throughout the game.

### Cargo and selling

The base shared hold is 120 ore units. A fleet of three drones shares that hold rather than receiving three independent holds. Card capacity uses the same shared value. When full, the fleet releases assignments and returns; the player still visits the Converter to sell.

Sale value is the sum of authoritative mineral units × field unit value. A successful sale clears cargo, adds credits and increments cumulative sale earnings for that run. Pack purchases reduce credits but do not reduce cumulative sales. This distinction lets players buy cards without erasing milestone progress. Selling is an ordered profile transaction, rejected during the owner's active assault and outside Converter range.

## Packs, upgrades and build identity

[upgrades.md](upgrades.md) explains pricing, scopes, targeting, stacking and caps; [upgrade_cards.md](upgrade_cards.md) lists **every obtainable card**, including all signature mechanics, penalties and reserve fallback entries. These are the catalog references for reviewing upgrades without rolling packs in Studio.

Only earned in-game credits buy packs. The server calculates the price, eligible pool, three choices and any named individual target. It saves the complete choice payload and price before the owner sees an offer. Reconnect restores that same offer; choosing later reads the saved effect rather than silently substituting a changed catalog definition.

Cards affect the whole fleet, the shared player hold, owned drones of a built-in type, or one resolved permanent drone. An individual target is chosen from eligible owned units by the server during offer generation. The player chooses the card, not a new target afterward. A card for an absent type, an already exhausted stack or a fully capped zero-benefit outcome is excluded. If three useful distinct choices cannot be formed, purchase fails without a debit.

The current catalog contains 41 normal cards and three reserve fallbacks. Offer generation searches compatible triples and prefers both a combat/survival answer and an economic option, then an eligible signature mechanic in the first three packs, followed by category/scope variety. A seeded ordering breaks ties. This is a curated random-choice system, not equal drop odds or a rarity-tier loot box. Existing paid choices retain their complete saved effects when a later catalog version strengthens new cards.

Bonuses add against base stats before clamps. Startup rate is reciprocal warmup, so +100% rate halves warmup alone; it does not double active laser damage. Combat firing rate and damage share a nominal DPS cap. Signature cards can add finishing damage, geode specialization, kill repair, an arc to another sentry or a split mining hit; each still obeys server reach/line-of-sight/eligibility. The catalog documents which conditions make each effective.

Purchase, selection and prestige cannot run during the owner's assault. Installed hull bonuses heal only the newly added hull; they are not a full-heal loop. Tradeoffs can reduce other stats. Chosen modifiers survive reprint and ordinary reconnect inside the run, but all disappear on prestige.

## Sentries and finite cooperative assaults

Guarded fields use the original `Workspace.construct` segmented pyramid: `bottemseg`, `lowerseg`, `upperseg`, `topseg`, `eye`, `eyecase`, `spawnEye`. Their meshes define the visible enemy; an invisible query hitbox handles server targeting. Cosmetic eye/segment rotation, charge, recoil, collapse and restoration animate authored geometry without moving gameplay authority to the client.

### Encounter states

| State | Server behavior |
| --- | --- |
| `Safe` | Only unguarded fields; no clearance required. |
| `Guarded` | Full defense awaits a new attempt. First valid assignment begins gathering. |
| `Gathering` | Four-second enrollment window. A user/current run can enroll living drone lives once; their stats are snapshotted. |
| `Active` | Fixed roster fights. No replacement lives, late arrivals or new units reinforce it. Assault deadline is 90 seconds. |
| `Cleared` | Qualifying contributors receive current-run clearance and a milestone win. Only entitled crews may mine this expedition. |
| `Resetting` | Defense health/resources/clearances reset, then a six-second delay returns the field to `Guarded`. |

During `Active`, death, recall, disconnect, changing field or leaving valid participation retires a roster slot. A reprinted model has a newer life and cannot revive the spent slot. If the entire valid roster is gone, all turret damage resets. Abandonment also ends an attempt after the bounded eight-second disengagement window; a short re-entry cannot continuously create new lives in the old roster. The deadline and zero-living-roster conditions win a simultaneous final-hit race, preventing an empty crew's ghost victory.

Cooperation shares one field defense state; it does not automatically share mining rights with every observer. The current run of each enrolled user must make an authoritative combat contribution and must not have been removed by recall/disconnect/run change when the field clears. The attempt as a whole must retain a valid living roster member; a contributing user may have lost their own drones while a teammate finishes. Every qualifying user receives their own `(run, encounter, field)` entitlement and milestone win, rather than racing for last hit. An outsider joining after roster lock can watch and join a later fresh muster. Dead sentries alone never authorize that outsider to mine.

One player's retreat/disconnect/prestige removes that player's participation/entitlement. Other qualifying players may finish or continue mining. Cleared expedition defenses remain down while entitled active crews use the field; after all leave, the eight-second empty grace ends the expedition. Returning after that requires a fresh successful assault. Wins already credited to a run remain milestone progress; live mining entitlement expires with the encounter.

### Shots, evade and recovery

Sentries sleep as a tightly closed stack. The first fresh muster triggers a full
turn and wide separation of the original layers; they ease into floating active
spacing. At 2.15 seconds the eye faces the triggering player and ignites with a
sound, flash and broad lens flare. This happens inside the existing four-second
muster. Server timestamps let observers sample the same wake sequence. Each
layer retains independent weighted motion for charges, shots and damage. On
death the layers and eye assembly fall, thud on ground contact and stay embedded
until encounter reset; they do not bounce or disappear. Reset draws the original
pieces back into the closed stack. These are cosmetic poses, not damage sources.

Sentries select an eligible nearby roster drone and freeze a world-space aim point for a 0.8-second visible telegraph. At firing time the server checks proximity to that point, distance and line of sight. A flank switch during the telegraph can move the drone out of the danger point. Charge does not secretly retarget its final hit to the drone's corrected position. Current configured shot cooldowns are 1.8 seconds for Cobalt/Violet and 1.7 for Emerald after firing.

Drones approach a bounded attack station beside the nearest live sentry. They shoot only when their snapshotted combat range and server line of sight permit. Shot damage/interval, reduction, crit, splash/arc, entry shields, finishers and kill repair derive from server stats. Visual sparks, flashes, lasers or a visible hit cannot inflict extra damage.

Destroyed drones remain owned. They wait ten seconds, visibly reconstruct for two seconds at home, then rejoin the following fleet with a new runtime life and full effective hull. Their cards and permanent traits remain. Owned healthy drones near home heal gradually at eight hull/second. Neither free reprint nor home healing allows a replacement to re-enter a damaged active attempt.

Player character death ends the owner's active field participation and sends the fleet toward home; it does not delete permanent drones or run cards. Disconnect attempts final save/release. A loaded profile recreates the saved owned fleet; transient damage and a previous server's encounter entitlement are not portable progression.

## Prestige

Prestige is a concrete server transaction at the depot beacon, with an explicit UI preview/confirmation. It is not triggered by selling. Eligibility uses cumulative sales in the current run plus a guarded-victory requirement; spent credits still count toward sales.

| Prestige being earned | Cumulative sale credits required | Guarded-field objective | New type |
| --- | ---: | --- | --- |
| 1 | 2,000 | 1 Cobalt win | Red |
| 2 | 5,000 | 2 Cobalt wins | Green |
| 3 | 11,000 | 1 Violet win | Blue |
| 4 | 22,000 | 2 Violet wins | Red |
| 5 | 42,000 | 1 Emerald win | Green |
| `n > 5` | `floor(42000 × 1.75^(n−5))` | `max(1, n−4)` Emerald wins | Red/Green/Blue cycle |

A pending paid pack must be resolved first. The player must leave their own active assault and return to the beacon; teammates' separate continuing participation does not block them. Server checks run ID, station range, confirmation and current milestones again at commit.

| Keep | Reset / replace |
| --- | --- |
| Every existing permanent drone ID, type and base trait. | All installed run cards and their modifiers. |
| Existing permanent fleet; append exactly one new record. | Credits, cargo and fractional-yield remainders. |
| Prestige count increases; serial counter advances. | Cumulative run sales, run wins and live field clearances. |
| Profile seed and settings. | Pack index/prices, offer protection counter, pending-offer state (which must already be resolved). |
| Permanent ownership independent of transient destruction. | Fresh run ID/index and recreated runtime fleet. |

The permanent append, prestige increment and run replacement commit together. Save failure leaves the previous run usable or paused pending reconciliation; it cannot display a successful extra drone before durable confirmation. Retrying the same recent receipt returns its prior result. Old-run card/prestige requests fail the new run ID rather than modifying the fresh run. Prestige cleanup touches this owner, not teammates' fleets or shared victory state.

## Saving and safety

Production storage uses session-locked `UpdateAsync` transactions with validation, bounded receipts, revision fences, autosave, leave and shutdown handling. Only a genuinely absent stored profile invokes the new one-drone factory. A failed, corrupt, unsupported or uncertain load cannot replace valid ownership with defaults. Profile schema migrations preserve permanent IDs and base traits. A supported migration that finds a paid offer's permanent target missing refunds its exact saved price; it does not reroll a new free offer.

Studio/unpublished preview uses a clearly labeled isolated temporary adapter. It can test in-session behavior, but it is **not saving across server restarts**. Production failure never silently switches to this adapter. Real restart durability and simultaneous server access require a controlled live DataStore acceptance test, which is separate from local build permission.

Gameplay data stays server-owned. Commands are validated and rate limited; the client supplies bounded intent, run/offer IDs and choice indices, not rewards or damage. Pending transactions pause owner mutations, and uncertain outcomes reconcile before applying success presentation. See [architecture](architecture.md) and [persistence contract](../PERSISTENCE.md) for implementation details.

## Presentation and evidence boundaries

Permanent HUD content is credits, cargo, fleet count and save state plus a short current objective. Nearby machines expose one relevant action. Card, fleet and prestige details use deliberate modal screens rather than permanently stacked debug panels. Field identity and hazard guidance should be readable from the world, with text/shape cues as well as mineral colors. Bloom, haze and emissive material must preserve drone silhouettes, crystal fracture stages and sentry aim readability.

All observers should see the same logical fleet/resource/encounter state, with smooth local rendering and no duplicate historical events on late join. Effects use bounded pools and time-based cleanup. Their purpose is readable impact, growth, danger, death and recovery; effects do not hold up rewards or save transactions.

The test suite exercises domain rules, offer math, persistence failure paths, progression models, original movement equations, binary preservation and actual bundled server logic against an API double. Those checks do not establish Studio visuals, mesh/audio permissions, collisions, network behavior, touch usability or actual first-pack/prestige time. Final acceptance and evidence belong in [Studio acceptance](../STUDIO_ACCEPTANCE.md) and [validation](../review/VALIDATION.md). The balance constants above remain provisional until those observations are recorded.
