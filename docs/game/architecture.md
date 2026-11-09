# Architecture and file navigation

Read [owner requirements](../OWNER_REQUIREMENTS.md) first. The shared repository is `Olivegord/mining-away`. Edit source under `src/` and use the checked [Script Sync and native save workflow](../COLLABORATION.md#native-script-sync) for the single canonical file, `build/DRONE_GAME.rbxl`. The [state machine inventory](#state-machine-inventory) locates the owner, transitions and observable signals for each runtime lifecycle.

## Find the right file

| Source | Responsibility | Common changes |
| --- | --- | --- |
| [`src/Config.lua`](../../src/Config.lua) | Field definitions and shared simulation tuning. | Field populations, mineral values, defense strength, timing, command distance. Check the consuming runtime because some constants are still duplicated there. |
| [`src/MapLayout.lua`](../../src/MapLayout.lua) | Pure expanded-valley plan: sparse hub, field/landscape scales, connected routes, rounded bends, terrain cuts and outer groves. | Field/route clearance and terrain composition; run `map-layout.spec.lua` and the real Studio map checks. |
| [`src/World.lua`](../../src/World.lua) | Runtime map assembly, original asset integration, station props, paths, trees, scenery, materials, lighting; drone and turret cloning. | Map, atmosphere, palette, station placement, safe terrain, original pyramid appearance. |
| [`src/Feel.lua`](../../src/Feel.lua) | Pure original-motion equations, formation, hover, mining stations, growth and crystal-stage helpers. | Original-feel corrections. Preserve the contract and its equation tests. |
| [`src/Mining.lua`](../../src/Mining.lua) | Shared field hardness, type mining cadence/efficiency, bounded fracture echoes, target scoring and UI descriptions. | Mining behavior and pacing; use the same rules in server and model, preserve authority and original motion. |
| [`src/Rules.lua`](../../src/Rules.lua) | Pure finite encounter state machine, immutable-life eligibility, clearance, atomic depletion, free reprint transitions. | Anti-attrition, encounter lifecycle, contribution and ownership rules. |
| [`src/Profile.lua`](../../src/Profile.lua) | Permanent profile schema, base drone creation, validation/migration, cargo, selling, milestone and prestige transactions. | Permanent ownership, reset semantics, progression milestones, migration. |
| [`src/Cards.lua`](../../src/Cards.lua) | Catalog, additive stat evaluation, useful-offer filtering, deterministic target/offer generation, pack pricing, card purchase and selection. | Card effects, scopes, caps, offers, prices. A runtime effect also needs a consumer in `Server.lua`. |
| [`src/Persistence.lua`](../../src/Persistence.lua) | Storage adapters, session leases, revision fences, atomic transactions/receipts, retry/reconciliation, save/release. | Save correctness. Keep it independent of world presentation. |
| [`src/Server.lua`](../../src/Server.lua) | Server entrypoint: player lifecycle, validated commands, fixed-step gameplay, authoritative resource/combat simulation, runtime encounter integration and replication. | Damage, target selection, rewards, remote validation, world/profile integration. |
| [`src/Client.lua`](../../src/Client.lua) | Client entrypoint: HUD/menu orchestration, nearby station/field actions, local transaction feedback, all-player drone/resource rendering, beams, input and cleanup. | Controls, authoritative profile presentation, menu availability, visual interpolation, crystals and cleanup. |
| [`src/UILayout.lua`](../../src/UILayout.lua) | Pure pixel geometry for HUD, commands, modal and card columns inside the native safe content rectangle. No Roblox dependencies. | Phone/short-landscape layouts, touch-control clearance, modal bounds and scroll-reachable card actions; exercise `tests/ui-layout.spec.lua`. |
| [`src/Interface.lua`](../../src/Interface.lua) | Native Roblox visual kit: palette, Fredoka/Gotham typography, outlined rounded panels, tactile buttons, badges and original GUI-primitive icons. | Shared styling and enabled/hover/pressed feedback. Owns no gameplay or profile state and requires no uploaded art. |
| [`src/CardView.lua`](../../src/CardView.lua) | One offer card's presentation, category emblem, target, description, tradeoff, before/after rows, stacking, expiry and selection control. | Card readability and compact/roomy card variants. Receives the resolved choice and callbacks; does not generate offers, choose targets or apply stats. |
| [`src/SentryMotion.lua`](../../src/SentryMotion.lua) | Pure sentry choreography: closed dormant stack, full-turn expanding wake, weighted spring settling/tracking, independent recoil/flinch, and accelerated falls that stop at impact. Bundled before Presentation. | Sentry motion tuning; never combat decisions or damage. |
| [`src/Presentation.lua`](../../src/Presentation.lua) | Cosmetic authored-mesh animation for all drones and pyramid turrets, telegraphs, hit/death/rebuild effects, bounded fragments/audio. | Sentry animation, combat readability, destruction/reprint presentation. Never gameplay damage. |
| [`src/Feedback.lua`](../../src/Feedback.lua) | Pure cosmetic event detection and elapsed-time envelopes. | No-replay late-join feedback, flash/recoil/assembly/fall timing. |

These `.lua` files are editable module-shaped sources. The place builder bundles them lexically into the original two controllers; it does not install one ModuleScript for every file.

## Build and asset ownership

[The builder](../../tools/build.py) defines the current lexical bundle order and the seven exact native Source paths. [Script Sync](../../tools/script_sync.py) exports them to the three tracked `studio/` roots. The checked native refresh replaces only those Sources in the existing `build/DRONE_GAME.rbxl`. Compile both full bundles if you add or reorder a dependency. Use [the historical captures](../../assets/) and [original sources](../../reference/original/src/) as references.

## Runtime and replication

```text
Player input / contextual HUD
  → ReplicatedStorage.MiningAway.Command
  → Server validates caller, state, distance, cooldown, run and request shape
  → Server simulation OR ordered profile transaction
  → replicated world attributes + that player's MA_Profile
  → every client renders local original-art viewmodels and effects
```

`World.initialize()` integrates the original SpawnLocation, Converter, Ruby/Cobalt patch geometry and `Workspace.construct`; it creates `Workspace.MiningAway`. Runtime world records live under that root. Field Models contain their crystals and sentries. The root also creates `Map`, `Fields`, `Drones`, `Resources`, and `Turrets` folders; the last two are not promises that every resource/turret is parented there. Identify objects by authoritative attributes, not guessed folder locations.

Preserved experimental scene objects move into `ServerStorage.MiningAwayOriginalReference`. `ServerStorage.OriginalConstructTemplate` retains the complete original turret template. Active guard clones omit redundant `AnimSaves` editor history while keeping the real segmented mesh art. The untouched binary and stored template preserve that history.

The server owns logical drone position, yaw, permanent ID, spawn life, health, assignment, arrival, targets, damage, mining, cargo, currency, offers, clearance and prestige. It advances at a configured `1/60` step, with at most six catch-up steps; a long stall drops excess accumulated simulation time. It publishes drone snapshots roughly every `0.1` seconds. Combat deadlines and growth use server time.

Each client creates `Workspace.MiningAwayPresentation`, hides authoritative visible parts locally, and renders all players' drones and resources using their current attributes. Drone snapshots include `DroneId`, `Owner`, `Life`, `State`, `Position`, `Goal`, `Yaw`, movement tuning, `TargetId`, health, mining and effect timestamps. Resources include server-chosen position/size, `ResourceId`, health/stage, growth timestamps and break serial. Sentries include health, encounter identity, frozen `Aim`, `FireAt`, telegraph and shot serial. Late joiners reconstruct current state from these records, rather than depending only on historical remote events.

Local viewmodels are cosmetic. Their position and effects cannot authorize a hit, move cargo, change a saved drone or produce rewards. Feedback records initialize from the current state so joining beside a destroyed object does not replay its death payout/effect.

The owner receives `MA_Profile` JSON and `MA_SaveStatus`/`MA_Notice` attributes on their Player. The profile includes effective stats, next pack price, prestige preview and `pendingTransaction`; seeds and transaction ledgers are omitted from that client copy. The server also replicates `MA_InAssault` from `activeAssault(p)` for client availability messaging. This attribute is a presentation gate only: server command validation still decides whether any request is legal. Other clients observe the world snapshots, not a remote granting them authority over the owner's profile.

## Interface data flow and layout

`Client.lua` creates `PlayerGui.MiningAwayHUD` with `CoreUISafeInsets` and one full-size transparent `SafeContent` root. `UILayout.calculate()` receives that root's `AbsoluteSize`; camera dimensions are only an initialization fallback. Do not replace this with unconditional raw viewport sizing, which would measure a different rectangle around native Roblox UI and device insets.

The HUD contains credits, save state, shared cargo, permanent fleet/run-card shortcuts and a short objective. Nearby machines or fields supply a single contextual action. One `MenuLayer`/`MenuSheet` contains a vertically scrolling `MenuContent`; pack, three-choice offer, permanent fleet, run build and prestige screens reuse it. Opening a modal hides ordinary HUD/command surfaces. Escape or the fixed close control closes the menu without changing a paid saved offer. Profile/availability refreshes preserve the modal's scroll position, and ordinary cargo updates do not rebuild an immutable offer comparison.

Layout caps the modal at 1010 × 664 pixels with a 12-pixel outer margin. Three cards appear in a row when the safe content is at least 800 pixels wide and each card slot can receive at least 240 pixels; narrower layouts use a vertically scrollable one-column list. Row cards compact to a 430-pixel minimum height; stacked cards retain 520 pixels. The complete card includes category, real saved target, effect, explicit tradeoff, up to four server-generated before/after stat rows, stacking and the prestige expiry reminder. `Client.lua` formats units (including converting older saved 60 Hz flight-cap previews to studs/second); `CardView.lua` does not recompute card effects. Catalog details remain in [the card reference](upgrade_cards.md).

For touch-only input (`TouchEnabled` without `KeyboardEnabled`), geometry reserves the lower 130 pixels for native movement controls and keeps fleet/station commands above it. Recall, evade, context and card-choice buttons use 44-pixel-high targets. Short touch landscape at width ≥568 moves recall/evade to the top right; below 300 safe pixels tall, a visible context dock temporarily replaces resources. Short combat/notice states also suppress lower-priority HUD surfaces. These are implemented geometry rules, not a claim that native touch, wrapping or device rendering has been accepted.

`availability()` explains loading, local/server pending transaction, own active assault, home distance and relevant station distance. Buy/select/prestige buttons disable with a reason and refresh as availability changes. `send()` adds transaction/run IDs, locks duplicate local economy submissions and displays a pending state; authoritative profile changes/notices release it. A ten-second local retry message is allowed only when the replicated profile is no longer pending. The server's receipts, eligibility, range and transaction checks remain authoritative. Client labels or disabled controls cannot authorize an action.

## Command boundary

| Action | Client supplies | Server checks / resulting operation |
| --- | --- | --- |
| `Patch` | Integer field ID. | Exists; owner is in command radius; eligible living fleet; current encounter enrollment/clearance. Assigns eligible workers or enrolls a combat roster. |
| `PlaceSelector` | Run ID, field ID and candidate position. | Valid Crystal Run zone, snapped placement, range, line of sight, healthy owner and no active assault. Same-cell placement preserves the pin. |
| `Recall` | No economy payload. | Healthy owner/session. Retires that player's assault slots, releases targets and returns fleet. |
| `Evade` | No damage or position. | Two-second owner cooldown; only participating drone flanks toggle. |
| `Sell` | Intent only. | At Converter and outside own assault; server creates receipt ID and sells authoritative cargo. |
| `BuyPack` | Transaction ID, current run ID and expected pack index. | At home/card station, healthy session, no own assault, sufficient server credits, useful offer. |
| `ChooseCard` | Transaction/run ID, saved offer ID and choice index `1..3`. | Depot, saved pending offer/target and no own assault. Applies the saved choice once. |
| `Prestige` | Transaction/run ID and explicit confirmation. | Beacon/home, eligible milestones, no pending pack/own assault. Atomically resets run and appends exactly one permanent drone. |

Requests are rate limited with an owner token bucket (capacity seven, refill three/second). Caller identity comes from `OnServerEvent`; supplied damage, currency, target position, multipliers or another UserId are not gameplay inputs. A UI button being hidden or disabled is not an authorization rule.

## Persistence and transient state

Permanent state is `fleet` (IDs/types/base stats), prestige count, serial counter, seed/settings and profile version. Run state contains cargo, credits, cumulative sales, card selections, paid pending offers, pack index, wins and fractional-yield remainders. Runtime health, life/spawn generation, positions, reservations and encounter rosters are not stored as permanent hardware.

Production uses the `MiningAwayProfiles_v2` DataStore selected in `Server.lua`. `Config.DataStoreName` currently has a different unused spelling; do not change a live namespace casually. Studio and `game.GameId == 0` explicitly select an isolated Preview adapter labeled unsaved across restarts. A live storage failure never silently swaps to Preview or writes defaults over uncertain data.

Profile schema is version 12. The storage envelope has its own version. A session acquires a tokenized 180-second lease through `UpdateAsync`. Saves and transactions check owner/token/revision. Runtime autosave is every 30 seconds; leave and bounded shutdown handling attempt save/release. Pack purchase, selection, selling and prestige commit candidate state and receipts before publishing success. Failed or ambiguous writes pause mutations and reconcile the exact transaction outcome. See [persistence contract](../PERSISTENCE.md) for details.

Guarded-field participation is scoped to the current server, run and drone life. Earned `clearedFields` are permanent. The live field phase and a player's permanent clearance can differ.

## State machine inventory

Scope is the seven managed Sources of the canonical game, including their bundled modules. Each row describes a lifecycle with distinct behavior after an event, deadline or guard changes. State names in code font are actual values or fields. Plain-language phases describe state encoded across flags, IDs, timestamps or records. Pure calculations and authored scenery have no lifecycle here. Historical captures, disabled backups and Studio authoring scripts are outside this runtime inventory.

### Authoritative gameplay

| Lifecycle | Transitions and authority | What to inspect |
| --- | --- | --- |
| Player and character | Join → acquire session → spawn fleet and character → respawn or leave → dispose runtime and release lease. A replacement Player with the same user ID waits for the retiring session. Respawn clears field orders and temporary tools. | [Server](../../src/Server.lua) `addPlayer`, `removePlayer`, `character`, `pendingJoins`, `MA_SaveStatus` |
| Drone identity and hull | Follow or work → hull depleted → `Destroyed` → `Reprinting` → full hull and incremented `Life`. Permanent ID, role and base traits survive. Recall, docking, save pauses and death can preempt jobs. | [Server](../../src/Server.lua) `droneStep`, `kill`, `release`, `snapshotDrone` and [Rules](../../src/Rules.lua) `finishReprint` |
| Manual work queue and reservations | Remote validated → accepted, queued, canceled or rejected. Reservations bind a worker to a resource and slot. Repeating an active assignment preserves the job. Retirement, recall or invalid targets release slots. Field auto-orders choose another available resource. | [Server](../../src/Server.lua) `commandPlayer`, `chooseResource`, `assignOre`, `dispatchOreQueue`, `retireTarget`. Observe `MA_CommandState`, `QueuedOreIds`, `TargetId`, `SlotsUsed`. |
| Crystal Run selector | No pin → validated snapped pin → assigned workers or standby → repin or clear. A new pin can replace uncommitted travel. Committed work finishes at the previous target. Workers stay at the pin while the player leaves or fills the backpack. | [Server](../../src/Server.lua) `placeSquare`, `squareStep`, `committedWork`, `holdSquare`, `clearSquare`. Observe `MA_Selector`, `MA_SelectorStatus` and `MA_SelectorWorking`. |
| Ordinary mining | `Travel` → arrival and line of sight → `Warmup` → `Mine` pulses → release and short `Recover`. Obstruction interrupts the cut. The profile save lock suspends work and preserves eligible committed motion. | [Server](../../src/Server.lua) `mineDrone`, `miningWarmup`, `setMotionPaused`. Observe `State`, `MinePulseSerial`, `WorkPaused` and `MotionPaused`. |
| Battery | Committed work drains charge → empty releases target → `ToCharge` → `Charging` at pad → full resumes latest order. Carried drones are outside this charger path. | [Server](../../src/Server.lua) `droneStep`, `recharging`, `Battery`, `MaxBattery` |
| Specialist extraction | Ordinary approach/warmup → `SpecialMine` job → timed, once-only impact → recovery. Invalid target or obstruction cancels. Geode shells use the separate cut path. Bubbler, Halver, Gridcutter, Singularity, Starforge, Frostbite and Resonator share the job lifecycle with different timings and effects. | [Server](../../src/Server.lua) `specialDrone`, `hitResource`, `release`. Observe resource `EffectType`, `EffectStartedAt`, `EffectPausedAt`, `EffectCancelledSerial`. |
| Breaker | Approach → windup → powered dive → held impact → recover → complete. Target retirement during impact can lift the breaker without a delayed second hit. | [DroneRoles](../../src/DroneRoles.lua) `stepBreaker` and [Server](../../src/Server.lua) `breakerDrone` |
| Grower | Follow → `GrowApproach` → `Plant` against a verified vacancy → `GrowRecover` → cooldown and next search. | [Server](../../src/Server.lua) `growerDrone`, `growPlan`, `growAt` |
| Medic | `Follow` or `Support` → `RepairCharge` → `Heal` → cooldown. Range, health, line of sight and a living ally govern repair. | [Server](../../src/Server.lua) `supportDrone`, `RepairChargeAt`, `Healing` |
| Courier | Follow → `Collect` → `Pickup` hold → saved delivery manifest → `Launch` → `Deliver` → `Unload` → atomic storage deposit and pickup cooldown. Storage capacity gates collection. | [Server](../../src/Server.lua) `droneStep`, `serviceDeliveries` and [Profile](../../src/Profile.lua) `beginDelivery`. Inspect `run.deliveries` and drone `State`. |
| Orbital and Scrap abilities | Ready/survey → charge token → confirm or expire/cancel → burn or active swarm → cooldown. Orbital checks the live target and line of sight. Each scrap bot seeks a target, approaches, charges and pulses or retargets until expiry. Permanent drone abilities and placed tools have separate runtime records. | [DroneAbilities](../../src/DroneAbilities.lua) `begin`, `confirm`, `step` and [Server](../../src/Server.lua) `roleAbilityStep`. Observe `MA_Ability` and `DroneRoleState`. |
| Field encounter | `Safe` or `Guarded` → `Active` with roster tied to current run and drone life → `Guarded` if roster empties, or `Cleared` on defeat. Eligible clears can queue during saves and then become permanent unlocks. | [Rules](../../src/Rules.lua) `begin`, `enroll`, `participates` and [Server](../../src/Server.lua) `encounterStep`, `grantClear`. Inspect field `Phase` and profile `clearedFields`. |
| Sentry and attacker | Sentry sleeps → wakes → locks aim and telegraphs → fires → cooldown or death. Drones approach, shoot or charge, and can evade. Run, life and eligible roster gate hits. Avatar hazards have independent per-target hit cooldowns. | [Server](../../src/Server.lua) `turretStep`, `attackDrone`, `combatHit`, `wakeTurrets` and [PlayerHazards](../../src/PlayerHazards.lua). Observe `Awake`, `Telegraph`, `FireAt`, `ShotSerial`, `HP`. |
| Resource and replenishment | Spawn and grow → ready → reserved and damaged through fracture stages → heal when unattended in Crystal Run, or deplete and mark paid → retire → respawn when the field budget allows. Geode shell → core and shards is a separate reveal. Brittle secondary damage can arrive through a timed cascade. | [Server](../../src/Server.lua) `makeResource`, `hitResource`, `regrow`, `respawnQueue` and [RockCascade](../../src/RockCascade.lua). Observe `ReadyAt`, `Stage`, `HP`, `RegrowAt` and `BreakSerial`. |
| Ore pickup | Ballistic launch → ground contact or settle → home if owner has room and path is clear → partial collection or final collection. Otherwise the pile waits, fades and expires. Consolidation can renew its lifetime. The fragment and its payout are scoped to the owner's run. | [Server](../../src/Server.lua) `award`, `pickupStep`, [OreDrops](../../src/OreDrops.lua), `MA_Collect`, `CollectedOreTotal` |
| Discovery capsules | Per-owner pity/capacity gates → world capsule spawns → bounces, becomes collectible, fades → saved pocket or expiry. | [MiningDiscoveries](../../src/MiningDiscoveries.lua) `TrySpawn`, `Step` and [Consumables](../../src/Consumables.lua) `onRock`, `collect` |
| Consumable stock and deployment | Stored → transaction reserves one item → placed charge → burn/swarm accepts first mining contact and spends the item, or refunds a canceled or unused deployment. Pending stock is reconciled on profile migration/load. | [ConsumableService](../../src/ConsumableService.lua) `command`, `step`, `clear` and [Consumables](../../src/Consumables.lua). Observe `MA_ConsumableActive`. |
| Temporary field tools and projectiles | Drop → collect into a slot → equip → windup → hit, miss, deploy or throw. Flight can recover on the ground, melt or stick until fuse. Uses, expiry, death and run change determine cleanup. Stored gadgets use the consumable path. | [ToolService](../../src/ToolService.lua) `onRock`, `collect`, `release`, `impact`, `step`. Observe `MA_FieldTools`, `ToolActionAt`, and item state. |
| Transport fleet | Carrier `Home` → `Travel` → `Working` with an enrolled life roster, or `Return` on failed assignment/recall → `Home`. Carried miners dock, deploy or wait when storage fills. | [Logistics](../../src/Logistics.lua) `command`, `tick`, `station`, `view`. Inspect `MA_Profile.logisticsStates`. |
| Backpack assistant and orbital storage | Assistant `Follow` → `Collect` from full bag → `Deliver` or `StorageFull` → deposit. Storage accumulates and may drain overflow. Launch takes a saved manifest → timed flight → atomic credit and pad reset. Auto Launch uses the same transaction. | [Logistics](../../src/Logistics.lua) `pickupBackpack`, `beginLaunch`, `finishLaunch`, `tick`. Inspect `run.logistics` and capsule `Manifest`. |
| Conditional junk-field delivery | If a junk field is configured, vacancies → schedule drop → landing/placement after clearance checks → replenish. Active Crystal Run uses reference crystals, and the authored sample display has no mining lifecycle. | [Server](../../src/Server.lua) `dispatchJunk`, `replenishJunk` and [JunkField](../../src/JunkField.lua) |

### Durable progress and transactions

| Lifecycle | Transitions and authority | What to inspect |
| --- | --- | --- |
| Storage session and write | Load/migrate/validate → acquire lease → healthy → exclusive write candidate → commit with receipt, reject, or pause as uncertain → reconcile exact outcome. Lease loss fences writes. Leave/shutdown releases the session with a bounded retry path. | [Persistence](../../src/Persistence.lua) `load`, `_write`, `reconcile`, `release` and [Server](../../src/Server.lua) `transact`. Inspect session `readOnly`, `lost`, `closed` and player `MA_SaveStatus`. |
| Sell and purchase | Earned cargo → manual sale or Auto Sell → atomic credit/earnings update. Workshop, Star Shop, permanent hardware and side-shop purchases validate context, affordability and expected state before applying receipts. Capped tiers stop offering further purchases. | [Server](../../src/Server.lua) `sellBackpack`, `buyShopUpgrade`, `buyStarUpgrade`, [Profile](../../src/Profile.lua), [Cards](../../src/Cards.lua), [Shops](../../src/Shops.lua), [Workshop](../../src/Workshop.lua) |
| Saved pack offer and world delivery | No offer → paid sealed offer → world delivery arrives → owner holds to open or cancels the hold → open transaction → exactly three saved choices visible → one selected and Stars awarded → crate retires and offer clears. A reconnect can recreate the crate from the paid offer. | [Cards](../../src/Cards.lua), [PackDelivery](../../src/PackDelivery.lua), [Server](../../src/Server.lua) `chooseCard`. Inspect `pendingOffer`, crate `DeliveryAt`, `HoldAt`, `OpenedAt`, and `MA_OfferReceipt`. |
| Prestige and run identity | Earning milestone → eligible → player confirms and server checks gates → new run ID and one added permanent drone. Run balances, Stars and run upgrades reset. Permanent fleet, traits and field clears survive. Runtime work is rebuilt or invalidated by run mismatch. | [Profile](../../src/Profile.lua) `prestigePreview`, `prestige` and [Server](../../src/Server.lua) `executePrestige` |
| Studio preview | Isolated temporary session → optional preview crew or debug tools → restore/reset or session ends. Preview fleet can replace runtime assignments without replacing saved ownership. | [Server](../../src/Server.lua) `roleTestFleet`, `randomTestFleet`, `runtimeFleet`. Observe `MA_TestingEnabled` and `activeFleet`. |

### Client intent and presentation

| Lifecycle | Transitions and authority | What to inspect |
| --- | --- | --- |
| Aim and input arbitration | Idle → valid grid preview → input sends pin intent → authoritative pin arrives. Touch drag/multitouch, menus and blocked GUI input suppress aim. Side-field drag paints once per visited rock, shows pending, then reconciles with queue/receipt. Tool and carrier modes intercept their own world actions. | [Client](../../src/Client.lua), [SelectorView](../../src/SelectorView.lua), [CommandView](../../src/CommandView.lua), [ToolView](../../src/ToolView.lua), [LogisticsView](../../src/LogisticsView.lua) |
| Menus, prompts and pending actions | World → nearby station/shortcut → modal or logistics pane → focus, confirm or dismiss. A paid revealed offer survives dismissal. Local pending submission resolves on profile change, correlated offer receipt, notice, or eligible timeout. Prompt distance and character availability also close contextual views. Buttons render enabled/disabled, hover and press states. | [Client](../../src/Client.lua) `availability`, `actionPending`, `modalMode`, [Interface](../../src/Interface.lua), [CardView](../../src/CardView.lua), [PackView](../../src/PackView.lua) |
| Drone observer | Register proxy → buffer monotonic samples for current life → render travel, work, pause, death or assembly → reset on new life or destroy on removal. Snapshot serials suppress replay on late joins. | [Client](../../src/Client.lua) `registerDrone`, `renderDrone`, [MotionBuffer](../../src/MotionBuffer.lua), [Presentation](../../src/Presentation.lua), [Feedback](../../src/Feedback.lua) |
| Combat and work effects | Sentry dormant → wake → track → charge/fire → collapse. Drone warmup → ignition → beam/pulses → bounded release/fade. Surface contact has a separate sampled, occluded and stale/expired lifecycle. Specialist effects honor pause, completion and cancellation serials. Trails, effect records, particles and pooled rigs retire independently of gameplay. | [Presentation](../../src/Presentation.lua), [SentryMotion](../../src/SentryMotion.lua), [BeamVFX](../../src/BeamVFX.lua), [WorkEffects](../../src/WorkEffects.lua), [DroneFX](../../src/DroneFX.lua), [RoleEffectView](../../src/RoleEffectView.lua), [LaunchAftermath](../../src/LaunchAftermath.lua) |
| Resource and pickup observer | Resource proxy grows, changes stage or heals, then breaks and retires. Physical cut mesh requests have an active pose, queued rebuild and disposal path. Pickup proxies interpolate flight and homing, play collection after a receipt, and fade/clean up. | [Client](../../src/Client.lua) `renderResource`, [RockDamage](../../src/RockDamage.lua), [PickupView](../../src/PickupView.lua), [SelectorView](../../src/SelectorView.lua) healing cues |
| Tool, gadget and cargo observer | Selected tool or ability → aim/target marker → attack or charge progress → release, active effect, cooldown or cancel. Carrier selection and cargo views follow server flight/work/storage states. | [ToolView](../../src/ToolView.lua), [AbilityView](../../src/AbilityView.lua), [ConsumableView](../../src/ConsumableView.lua), [LogisticsView](../../src/LogisticsView.lua) |
| Audio and feedback | World/menu/combat context and toggles drive music mix. Fresh event serials trigger bounded one-shots. Work loops start, move, fade and retire with their source. Collection gain, notices and shake expire locally. Home laser showcase cycles independently of live jobs. | [Soundscape](../../src/Soundscape.lua), [AudioFeedback](../../src/AudioFeedback.lua), [CrystalAudio](../../src/CrystalAudio.lua), [TacticalHUD](../../src/TacticalHUD.lua), [LaserShowcase](../../src/LaserShowcase.lua) |

### Crystal Run status contract

The server derives `MA_SelectorStatus` from the same runtime records that control assignments. Read it alongside the presence of `MA_Selector`. The HUD uses the existing Recall row and hides the status with the dock. The existing `MA_SelectorWorking` cue still drives the yellow pin.

| Status in priority order | Guard while a pin exists |
| --- | --- |
| `Paused` | Profile work is gated or no living character root is available. |
| `Working` | At least one pin worker has committed to the current target, including warmup. |
| `FinishingCut` | A worker has a committed target from an earlier order and current-pin work has yet to commit. |
| `Moving` | At least one worker has reserved a target at the new pin and has yet to commit. |
| `NoMiners` | No living, non-carried workers are available. |
| `Recharging` | All living, non-carried workers are on the recharge path. |
| `Waiting` | The pin remains set without a current assignment in the phases above. This includes no eligible rock, a reservation held by another crew or a brief recovery. |
| Attribute absent | Recall, run reset or other pin cleanup removes the status with the pin. |

For future changes, start at the authority in the inventory. Derive feedback from the existing authoritative record and replicate it only when it changes. Introduce a separate state field only if transitions cannot be represented safely by the owner record. Extend the nearest production-path regression with the ordinary transition, its interruption or retry, and an invariant the player depends on. For the selector, run [the Crystal Run integration fixture](../../tests/crystal-run.integration.lua) through `python3 tools/test_workshop.py`. It exercises the production command, drone and status paths with API doubles.

## Reproduce and verify

Use the pinned official Luau `0.744` tools (`luau`, `luau-compile`, `luau-analyze`). The CI workflow records the archive checksum.

```sh
python3 tools/test.py /absolute/path/to/luau-tools
python3 tests/binary.spec.py
python3 tests/geometry.spec.py
python3 tools/release.py
```

`tests/generated-server.spec.lua` is generated by `tools/test.py` from the mock API, actual bundled server and integration assertions. The API double exercises real source logic; it is not Roblox engine validation. `tests/ui-layout.spec.lua` exercises real `UILayout` geometry for safe bounds, command separation, touch-strip clearance, card columns and reachable final-choice targets. It cannot measure text rendering or native controls. Standalone lint explicitly treats Roblox hosts as `any` and cannot validate their API contracts. Binary checks establish preservation/build properties. Original-geometry checks confirm named assets and hierarchy, not visual quality, route clearances or avatar traversal.

For final engine acceptance use [Studio acceptance](../STUDIO_ACCEPTANCE.md). Record evidence in [validation](../review/VALIDATION.md), linked to the generated revision. Source/design docs do not substitute for two-client observation, asset/audio permission checks, touch layout, real DataStore restart durability or measured pacing.
