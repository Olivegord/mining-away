# Shared project context

Last substantive handoff: **November 6, 2026, America/Los_Angeles**. Read this with [owner requirements](OWNER_REQUIREMENTS.md) and [AGENTS.md](../AGENTS.md). Later verified changes should update this file, not create a competing project.

## Identity and delivery state

| Item | Exact value | Verified meaning |
| --- | --- | --- |
| Shared GitHub repository | `Olivegord/mining-away` | Existing repository; the owner requests public, shared access. No replacement repository or fork. |
| Integration branch | `codex/restore-feel-prestige` | Current code, native game and handoff. `git log -1` identifies the exact checkout revision. |
| Canonical editable file | `build/DRONE_GAME.rbxl` | This actual native file is tracked, including its authored map. |
| Native-file SHA-256 | `d388ff671c44e244a2f7f1c494e06a6184ec1a55e9299caba2191757c8b156c7` | Hash of the integrated pack delivery and shop build. |
| Installed gameplay revision | `git log -1 -- build/DRONE_GAME.rbxl` | The integration commit that installs the pack delivery Sources identifies the exact local revision. |
| Shared Roblox experience | **DRONEREVOLUTION** | Place **124078027733625**, universe **10774898335**, owner OliveGord. |
| Roblox collaborator | **MideDibber** | Playtest and Edit both checked in Creator Hub on November 6. |
| Older separate experience | **Drone Blower revolution** | Place **136098934779395**, universe **10773006567**. Historical capture provenance, not the sharing destination. |
| Local association | `game.PlaceId == 0` when inspected | A filename is not proof of association with any cloud experience. |
| Shared Studio gameplay | **Verified November 6, 2026** | The cloud Edit session for place 124078027733625 contains the mine/sell/upgrade/prestige gameplay. Five allowlisted Sources matched the canonical build by length and fingerprint; the other two matched apart from authored map integration and effects preview placement. No overwrite was needed. |
| Published Roblox version | **v4** | Studio Version History marks v4 published by OliveGord at 5:12 PM Pacific on November 6. Later versions through v11 were autosaves. The published v4 Sources were not independently inspected; gameplay verification above applies to the current shared Edit session. |
| GitHub write invitation | **Pending the friend's GitHub username** | Roblox username/permissions are not GitHub identity/permissions. Public viewing does not grant push access. |

[DRONEREVOLUTION](https://www.roblox.com/games/124078027733625) · [verified collaborator page](https://create.roblox.com/dashboard/creations/experiences/10774898335/permissions) · [review PR](https://github.com/Olivegord/mining-away/pull/1)

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
- Close Studio after work to avoid lag. Routine stop/install/save/restart is authorized; publishing and new experiences still need an explicit request.

## Current implementation

An unmarked copy of the original drone delivers each paid upgrade pack between the buyer and the pack shop. The server saves the tier and the three choices with the debit, withholds the choices until the owner completes the hold near the crate, and saves the opened state before showing the cards. A reconnect redelivers a sealed pack with its original tier and choices. Previously disclosed offers remain available. The shop interaction reaches 14 studs and the landed crate hold reaches 8 studs. Keyboard, gamepad and pointer/touch use the custom crate bar.

| Crate | Box odds | Hold | Color progression |
| --- | ---: | ---: | --- |
| Common | 66% | 0.42 s | Grey |
| Rare | 24% | 1.32 s | Grey → yellow |
| Epic | 8% | 2.65 s | Grey → yellow → green |
| Legendary | 2% | 4.80 s | Grey → yellow → green → violet |

These timings, odds and the violet finish are tuning choices. Colored stages progressively reduce bar speed. Non-common boxes favor rarer existing cards among otherwise equally ranked offers. Cards rise from the crate when it is visible to the camera and retain the existing card effects and choice behavior. The reveal uses depth-of-field blur behind the cards.

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

The core-loop suite passed in both configurations, including all four timing curves, sealed disclosure, cross-player rejection, interrupted holds, reconnect and exactly one claim. The native package/preservation suite passed. The legacy card price and HUD text assertions also fail on the baseline commit. Pack animation on touch, higher-tier visuals, listening quality, multiple Studio clients and production DataStore reconnects remain unverified. This pack revision has no Roblox publication. The version evidence above refers to the earlier shared build.

Production-logic checks covered sale transactions, purchase costs, ownership, prestige and preservation. The one-file packaging/preservation suite passed. Server/client bundles compiled.

An actual native single-player command-driven run used real mining, pickup, movement and normal command remotes: fill 40 → sell 40 → buy power for 20 → sell another 40 → buy a Miner for 60 → reach 160 lifetime sales → prestige. It retained both original owned drone IDs and added the third; run money and modifiers reset; permanent mining power increased. No money/cargo/damage/ownership grants were used. Console output was empty, Play was stopped, the canonical file was saved, and Studio was closed.

Limits: no final native multiplayer/late-join pass, real DataStore reconnect/server-restart validation, or owner enjoyment approval. The final expanded tool-pocket layout was compiled/installed but not separately played in Studio. See [native transaction observations](review/core-loop-native.json). Offline checks must never be reported as visual or multiplayer playtests.

## Next work

1. Add the friend's actual GitHub account as a collaborator when the owner supplies it. Use this shared repository.
2. If the owner explicitly requests an online update, reconcile any newer shared-game edits, publish the canonical file to the existing DRONEREVOLUTION starting place, then record the actual published version/revision and verified destination here. Do not assume the instructions already completed this step.
3. Let the owner judge the simple loop in play. Prioritize meaningful mining and purchases over more decorative changes. Complete real multiplayer and durable-save checks before claiming those outcomes.
4. Keep Sources, the canonical native file and this handoff synchronized for every subsequent contribution. Never resolve a binary conflict by silently taking one contributor's map over another's.
