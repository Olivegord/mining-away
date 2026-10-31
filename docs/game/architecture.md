# Architecture and file navigation

Read [owner requirements](../OWNER_REQUIREMENTS.md) first. This is one game repository, `Olivegord/mining-away`. Edit source under `src/`, then regenerate `build/Mining Away.rbxl` from the unchanged asset base. Do not maintain separate game logic in a manually edited output place.

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

| Path | Purpose |
| --- | --- |
| [`assets/mining-away-base.rbxl`](../../assets/mining-away-base.rbxl) | Untouched historical source place, hash checked before building. Preserve it. |
| [`reference/original/src/`](../../reference/original/src/) | Extracted original controllers and experiments for behavior comparison. Historical scripts are reference material, not additional active simulators. |
| [`tools/build.py`](../../tools/build.py) | Reads the binary without executing embedded scripts; patches controller source and enabled states while preserving all other original chunks. |
| [`tools/test.py`](../../tools/test.py) | Compiles source, runs pure Luau and actual-server/API-double tests, then checks bundled standalone lint. |
| [`tools/release.py`](../../tools/release.py) | Builds the place, review ZIP, checksum report and Git revision metadata. |
| [`tools/inspect_original.py`](../../tools/inspect_original.py), [`tools/inspect_rbxl.py`](../../tools/inspect_rbxl.py) | Read-only inspection helpers for the source binary. |
| [`tests/`](../../tests/) | Pure domain, fault-injected persistence, server integration and binary/geometry checks. |
| [`.github/workflows/validate.yml`](../../.github/workflows/validate.yml) | CI validation/build pipeline. |
| `build/Mining Away.rbxl` | Generated review place. Existing output is backed up as `.rbxl.previous`. |
| `build/revision.json`, `build/build-report.json` | Exact source commit/dirty flag and generated asset hashes. |
| `build/mining-away-review.zip` | Generated place and tracked source handoff. Newly added source/docs must be tracked before the final release ZIP. |

The base SHA-256 is `480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b`. The builder refuses a different base and refuses identical input/output paths. It replaces `GlobalDroneControl` and `ClientDroneControl`, enables those two, and disables other historical Script/LocalScript controllers. Do not enable legacy `DroneControl` alongside the new simulation.

Server bundle order is `Config → Feel → Rules → Profile → Cards → Persistence → MapLayout → World → Server`. Client bundle order is `Feel → Feedback → SentryMotion → Presentation → UILayout → Interface → CardView → Client`. These names are local lexical values in the two generated controller scripts, not separately installed ModuleScripts. If you add a source dependency, update the builder order and test the generated bundles; a standalone file compiling does not establish a working bundle.

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
| `Patch` | Integer field ID. | Exists; owner is in command radius; eligible living fleet; current encounter enrollment/clearance. Assigns the fleet or opens a fresh muster. |
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

Profile schema is version 2; storage envelope version is separate. A session acquires a tokenized 180-second lease through `UpdateAsync`. Saves and transactions check owner/token/revision. Runtime autosave is every 30 seconds; leave and bounded shutdown handling attempt save/release. Pack purchase, selection, selling and prestige commit candidate state and receipts before publishing success. Failed or ambiguous writes pause mutations and reconcile the exact transaction outcome. See [persistence contract](../PERSISTENCE.md) for details.

Guarded-field wins are run progress. Mining entitlements refer to a specific server encounter and current run; they are cleared on connect and recomputed from that server's live encounter state. Rejoining cannot import another server's cleared defenses. A temporary expedition ending does not delete the already recorded milestone win.

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
