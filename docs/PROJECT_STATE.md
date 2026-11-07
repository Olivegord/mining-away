# Shared project context

Last substantive handoff: **November 6, 2026, America/Los_Angeles**. Read this with [owner requirements](OWNER_REQUIREMENTS.md) and [AGENTS.md](../AGENTS.md). Later verified changes should update this file, not create a competing project.

## Identity and delivery state

| Item | Exact value | Verified meaning |
| --- | --- | --- |
| Shared GitHub repository | `Olivegord/mining-away` | Existing repository; the owner requests public, shared access. No replacement repository or fork. |
| Integration branch | `codex/restore-feel-prestige` | Current code, native game and handoff. `git log -1` identifies the exact checkout revision. |
| Canonical editable file | `build/DRONE_GAME.rbxl` | This actual native file is tracked, including its authored map. |
| Native-file SHA-256 | `3519828953aeb5097658dc9a633838870c442caf4bb4fc3d1ab30f50968b8896` | Continuous slowdown snapshot; geometry and unrelated Sources preserved. |
| Installed gameplay revision | `git log -1 -- build/DRONE_GAME.rbxl` | The integration commit that installs the pack delivery Sources identifies the exact local revision. |
| Shared Roblox experience | **DRONEREVOLUTION** | Place **124078027733625**, universe **10774898335**, owner OliveGord. |
| Roblox collaborator | **MideDibber** | Playtest and Edit both checked in Creator Hub on November 6. |
| Older separate experience | **Drone Blower revolution** | Place **136098934779395**, universe **10773006567**. Historical capture provenance, not the sharing destination. |
| Local association | `game.PlaceId == 0` when inspected | A filename is not proof of association with any cloud experience. |
| Shared Studio gameplay | **Verified November 6, 2026** | Existing shared Edit document matches all seven Sources of `2ddef68`. Continuous keyboard test and final Rare pointer-hold test passed before v18 publication. Script Sync retained. |
| Published Roblox version | **v18** | Existing DRONEREVOLUTION File → Publish completed; native Version History shows v18 **Published**, OliveGord, 7:56 PM Pacific November 6, 2026. Source/native revision `2ddef68`; snapshot SHA-256 `3519828953aeb5097658dc9a633838870c442caf4bb4fc3d1ab30f50968b8896`. |
| GitHub write invitation | **Pending the friend's GitHub username** | Roblox username/permissions are not GitHub identity/permissions. Public viewing does not grant push access. |

[DRONEREVOLUTION](https://www.roblox.com/games/124078027733625) · [verified collaborator page](https://create.roblox.com/dashboard/creations/experiences/10774898335/permissions) · [review PR](https://github.com/Olivegord/mining-away/pull/1)

## Continuous pack slowdown — latest follow-up

The owner rejected the v16 circle restarts. The new implementation holds one native ProximityPrompt for the full rarity duration; HoldDuration never changes during the hold. A compact crate indicator uses the existing continuous weighted curve: 60%, 22%, 12%, 6% of Legendary progress over progressively longer intervals. Color boundaries do not reset input, time or fill. Native keyboard/gamepad events and native server validation remain; pointer/touch only forward button holds through InputHoldBegin/End. This uses Roblox's supported Custom prompt appearance, not a separate hold-command protocol. See [native prompt API](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt).

Installed through the three existing Script Sync roots in shared DRONEREVOLUTION (place 124078027733625, universe 10774898335). Native verification: an interrupted Common hold stayed sealed, then a runtime-only 4.8-second presentation probe recorded exactly one begin, one end, one trigger and zero fill regressions. Sampled fill rose from 64% at 0.67s to 84% at 1.60s, 95% at 2.93s and 99% at 4.40s. That probe extended an actual purchased Common crate's visible tier/duration only in Play; it was not a naturally rolled Legendary test. A card was claimed normally. A fresh Play with final Sources bought an actual Rare crate and opened it with a real pointer hold on the visible indicator. The indicator was visually inspected in Studio. All nine core-loop checks pass in both production and Studio configurations, including a single unchanged hold timestamp/duration and native End-before-Triggered ordering. Real touch/gamepad, multiplayer and production DataStore reconnect remain unverified.

Canonical snapshot SHA-256: `3519828953aeb5097658dc9a633838870c442caf4bb4fc3d1ab30f50968b8896`. Source-only refresh preserved authored map and unrelated/backup Sources. Play stopped after tests. Published source/native revision **`2ddef68`** as **v18** to existing DRONEREVOLUTION place **124078027733625**, universe **10774898335**. Native Version History shows v18 **Published**, OliveGord, **7:56 PM Pacific November 6, 2026**; v16 Previously Published. Before publication all seven installed Source lengths/fingerprints matched local bundles. Studio quit was confirmed by the app inventory after release.

## Native prompt and Script Sync — November 6 follow-up

The latest source/native-file revision is **`20b3c80`**. Installed into the existing shared Studio Edit document after exact baseline comparison. The native file SHA-256 is `21c3cba41088fbf76586b19e00b3ba593e53d4de1911e5863079c1b429fa42d8`. Publication of this follow-up is **verified as v16** in existing DRONEREVOLUTION, place **124078027733625**, universe **10774898335**. The owner replaced the obsolete chat-supplied restriction and explicitly reaffirmed publication permission. File → Publish completed; native Version History displays v16 **Published** with the 7:27 PM Pacific November 6, 2026 version timestamp and v14 Previously Published. Before publishing, the exact seven installed Source lengths/fingerprints matched the local bundles, all three Script Sync roots remained connected, and Git fetch showed no newer collaborator revision. No map or unrelated Source replacement was performed. Play was already stopped; Studio quit was observed after publication.

The custom input/progress GUI and PackHold remote protocol are removed. Server-owned native hold events validate owner, range, readiness and elapsed stage duration. A short deferred release handles Roblox firing HoldEnded before Triggered. The crate keeps the existing delivery/colors/sounds, saved offer and floating-card reveal. A real one-player Studio Epic purchase completed all three native hold stages with one continuous E hold; native event ordering and sealed-to-opened state were observed. No custom HoldToOpenPack GUI existed, and the shop prompt was suppressed. Play is stopped. The core-loop suite passes all nine scenarios in both production and Studio configurations, including unauthorized/early/interrupted events, stage timing, reconnect and one-card selection. Touch/gamepad, Legendary native playback, multiplayer and production DataStore reconnect remain unverified.

All three native Script Sync roots report SyncedAsRoot: `ServerScriptService`, `ReplicatedStorage.Shared`, and `StarterPlayer.StarterPlayerScripts`, mapped under `studio/`. A disposable `.luau` file created a ModuleScript, disk edits reached Studio, Studio edits reached disk, and disk deletion removed the instance. Existing backup LocalScripts remain disabled and the active ClientDroneControl remains enabled. Studio warns that some descendant properties are unsupported by Script Sync; it syncs scripts, not Disabled states or authored map properties. Those properties remain in the existing place and canonical snapshot. `tools/script_sync.py` exports the seven bundled Sources without opening or saving an `.rbxl`; optional `--watch` exports src changes. A conflict check preserves unknown edits. The exporter creation/no-op/conflict checks passed. Root connections are local to this workstation; other computers connect their roots once as described in COLLABORATION.md. F8 is assigned to Sync to... on this workstation.

## Standing publication permission and reconciliation

The owner grants continuing permission to publish routine updates to the existing DRONEREVOLUTION starting place until revoked. This is recorded in AGENTS.md. The shared authored map and its source adjustments were reconciled into the canonical file, including shop placement, daylight, logistics and preview positioning. The shared Studio session passed the current pack purchase, delivery, hold and claim flow with 100 starting Quartz and 60 remaining after purchase. Studio publication of revision `ef812b5` is verified as v14 at 7:09 PM Pacific on November 6, 2026. The final read-only Source fingerprint audit became unresponsive because it repeatedly retrieved large Source properties. That audit was stopped by closing the already-saved and published Studio process. Activity Monitor and the app inventory confirmed Studio closed. The final fingerprint audit did not complete; publication is supported by Version History and the shared Studio gameplay verification. The pack flow was tested through the shared Studio UI, including 100 starting Quartz, purchase for 40, delivery, hold and one selected card, with an empty console.

## What caused the confusion

Earlier instructions named the historical place as the sole destination and treated the local file and cloud titles as interchangeable. The actual current `.rbxl` was excluded from Git, so another checkout could have Sources and historical captures without the real authored document. This handoff corrects that: one tracked native file, one shared repository, explicit IDs, separate publication evidence, and a short durable context for other Codex sessions. Older review notes describe the revisions they tested; they do not override the identities above.

## What the owner wants

- A simple Roblox game with a clear **buy/sell/upgrade/prestige** loop. The newest request supersedes the earlier temporary direction away from progression.
- Directing drones, breaking rocks and collecting should feel satisfying and Roblox-like. Keep original models, segmented pyramid turret, map identity, compact colorful card UI and accepted audio/VFX.
- Cubic rocks must snap smaller, retaining orientation. Currency must arc up and away from the rock before attraction, so it is visible.
- Only one drone type may mine a given rock. Do not restore complementary-worker dependencies or factory-management complexity.
- Rocks can drop useful stored consumables, including a placeable orbital laser. Avoid substituting generic timed multipliers for meaningful actions.
- Bee Swarm Simulator is a reference for enjoyable play, not permission to copy its assets or introduce every mechanic it has.
- Do not mistake earlier ore/reward timing or cosmetic tweaks for proof of an improved core loop. Automated correctness is not proof of fun.
- Close Studio after work to avoid lag. Routine stop/install/save/restart is authorized; routine publication to the existing DRONEREVOLUTION place has standing authorization. New experiences need an explicit request.

## Current implementation

An unmarked copy of the original drone delivers each paid upgrade pack between the buyer and the pack shop. The server saves the tier and the three choices with the debit, withholds the choices until the owner completes the hold near the crate, and saves the opened state before showing the cards. A reconnect redelivers a sealed pack with its original tier and choices. Previously disclosed offers remain available. The shop interaction reaches 14 studs and the landed crate hold reaches 8 studs. Keyboard, gamepad and pointer/touch now use a standard Roblox ProximityPrompt. The nearby owner crate suppresses map prompts locally so the shop cannot consume E.

| Crate | Box odds | Hold | Color progression |
| --- | ---: | ---: | --- |
| Common | 66% | 0.42 s | Grey |
| Rare | 24% | 1.32 s | Grey → yellow |
| Epic | 8% | 2.65 s | Grey → yellow → green |
| Legendary | 2% | 4.80 s | Grey → yellow → green → violet |

These timings, odds and the violet finish are tuning choices. One continuous bar fills quickly at first, then slows at each color boundary without resetting. A single native hold runs for the full rarity duration; the stock-circle restart workaround is superseded. Non-common boxes favor rarer existing cards among otherwise equally ranked offers. Cards rise from the crate when it is visible to the camera and retain the existing card effects and choice behavior. The reveal uses depth-of-field blur behind the cards.

Revision `88ba15d` connects the ordinary one-drone start to immediate selling, visible purchases and prestige:

- Converter Sell pays matching mineral wallets directly, without first filling the 120-unit launch storage.
- Mining power costs 20/40/80/160 Quartz and adds 50% base damage per level within the existing run cap.
- A permanent ordinary Miner starts at 60 Quartz and scales by 1.8 with owned Miners. Purchased drone IDs survive prestige.
- Prestige adds the existing earned drone and +25% permanent base mining power per prestige, clears run money/sales/modifiers, and retains permanent ownership.
- New Studio Play profiles start with one drone, 40 capacity and 100 Quartz for pack testing. Production profiles start at zero. Preview crews are explicit developer controls.
- Compact purchase/prestige guidance and the Buy drones action connect the UI. Two observed HUD overlaps were corrected.
- Stored Orbital/Scrap consumables, physical rock collapse interactions, snap-size cubic rocks, outward pickup arcs and one-type-per-rock behavior remain integrated.

Server owns damage, rewards, persistent state, cards, purchases and prestige. Clients render replicated intent. Preserve fail-safe persistence; a load failure must not overwrite a valid profile with defaults. See [core-loop report](review/CORE_LOOP.md), [consumables](review/CONSUMABLE_GAMEPLAY.md), [rock interactions](review/ROCK_INTERACTIONS.md), and [architecture](game/architecture.md).

## Pack Shop

The depot pack counter now has its own Pack Shop sign and prompt. The compact shop screen shows the Quartz balance and a single purchase button with the price. The purchase places an order for a crate. Mineral shops continue to sell their level upgrades. The native refresh checked that all non-Source data and unrelated scripts matched the prior file. The delivery flow was played before merging the compact shop layout.

The five mineral shops now use compact upgrade tiles with a symbol, short name, effect, and one purchase or status button. Every catalog upgrade has a symbol, and field unlocks use their destination mineral color. Upgrade prices and transaction rules remain as before. Native Source preservation was verified offline. The updated shop layouts still need Studio visual and input verification.

## What was actually tested

The pack revision `eab05ef` completed a one-player Studio Play test before the shop merge. Normal mining and sale commands earned 40 Quartz, and the shop UI bought a Rare crate. Studio observed the crate grounded between shop and buyer. Releasing E early kept it sealed. A full hold advanced grey to yellow, disclosed the three cards, and showed all three card faces with world depth-of-field and transparent menu surfaces. Selecting Shard Harvester installed one card, cleared the pending offer and removed the crate and blur. The console was empty and Play was stopped. The canonical disk file was verified against the seven allowlisted Sources. The source-only refresh preserved map, other instances and backup Sources.

The core-loop suite passed in both configurations, including all four timing curves, sealed disclosure, cross-player rejection, interrupted holds, reconnect and exactly one claim. The native package/preservation suite passed. The legacy card price and HUD text assertions also fail on the baseline commit. Pack animation on touch, higher-tier visuals, listening quality, multiple Studio clients and production DataStore reconnects remain unverified. The reconciled release `ef812b5` was subsequently published as v14. Higher-tier native visual and multiplayer checks remain outstanding.

Production-logic checks covered sale transactions, purchase costs, ownership, prestige and preservation. The one-file packaging/preservation suite passed. Server/client bundles compiled.

An actual native single-player command-driven run used real mining, pickup, movement and normal command remotes: fill 40 → sell 40 → buy power for 20 → sell another 40 → buy a Miner for 60 → reach 160 lifetime sales → prestige. It retained both original owned drone IDs and added the third; run money and modifiers reset; permanent mining power increased. No money/cargo/damage/ownership grants were used. Console output was empty, Play was stopped, the canonical file was saved, and Studio was closed.

Limits: no final native multiplayer/late-join pass, real DataStore reconnect/server-restart validation, or owner enjoyment approval. The final expanded tool-pocket layout was compiled/installed but not separately played in Studio. See [native transaction observations](review/core-loop-native.json). Offline checks must never be reported as visual or multiplayer playtests.

## Next work

1. Add the friend's actual GitHub account as a collaborator when the owner supplies it. Use this shared repository.
2. For each completed game update, reconcile any newer shared-game edits, publish the canonical file to the existing DRONEREVOLUTION starting place, then record the actual published version/revision and verified destination here. Do not assume the instructions already completed this step.
3. Let the owner judge the simple loop in play. Prioritize meaningful mining and purchases over more decorative changes. Complete real multiplayer and durable-save checks before claiming those outcomes.
4. Keep Sources, the canonical native file and this handoff synchronized for every subsequent contribution. Never resolve a binary conflict by silently taking one contributor's map over another's.
