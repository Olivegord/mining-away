# Drone Blower revolution

Current November 1 work: [mineral shops and tutorial-based upgrade cells](docs/review/MINERAL_SHOPS.md), [Orbiter/Scrapper gadgets and smoother swarm movement](docs/review/DRONE_GADGETS.md). Fresh profiles start with Quartz; each mineral shop spends its own balance and sells the next field/shop. Packs spend Quartz. New focused checks run without Studio Play via `python3 tools/test_shops.py /path/to/luau` and `python3 tools/test_gadgets.py /path/to/luau`. The UI, busy multiplayer scenes and gameplay satisfaction still need the owner's engine playtest; historical validation below does not approve this new candidate.

The active game is the existing Roblox place **136098934779395**, in this same [Olivegord/mining-away repository](https://github.com/Olivegord/mining-away). The owner corrected the target on October 31: the older local Mining Away build is historical, not the current playable artifact. Preserve the captured live map, assets, card UI, tactical HUD, role drones, audio and discoveries.

The verified native capture is `assets/drone-blower-revolution-base.rbxl` (SHA-256 `b08036b400c77451e609f5fa3a4f7f04cd5dcc2030f35a76de12ecc278f532cd`). `python3 tools/build.py` builds `build/Drone Blower revolution.rbxl`. The builder changes only Source for the two live controllers and five exact-path live modules; all other raw chunks and untouched Source values remain byte-identical, including script enablement, geometry, terrain, lighting and ServerStorage backups. Names alone are unsafe because the capture contains same-name backup scripts.

For reproduction, use Python 3.9+ and the `zstd` command (verified installed version 1.5.7; alternatively the Python `zstandard` package). After committing the final source, `python3 tools/release.py` writes the same active place, `build/drone-blower-revolution-review.zip`, and `build/revision.json` with the source commit, capture checksum, output checksum and place ID. It refuses dirty releases unless `--allow-dirty` explicitly labels an unfinished review build. `python3 tools/build.py --source-payload /absolute/path/payload.json` exports the same seven exact-path sources for controlled edits to the existing Studio place. Neither command publishes or creates an experience.

The capture remains immutable. Rebuilding backs up an existing output as `.rbxl.previous` and atomically replaces the generated file. The historical asset and builder remain available only as explicit reference fixtures (`--legacy-reference`), with a separate reference output path; they must not replace the active game.

The owner will test this integrated candidate themselves and requested no further test runs. The latest backpack/swarm behavior is described immediately below; later historical sections retain obsolete hold/card descriptions for reference. New binary-preservation coverage is available in `tests/live-build.spec.py`, but has not been run for this live-target integration. Earlier tests and motion evidence below concern earlier artifacts and do not validate this candidate.

## Latest effects pass

Mining now has three differently sized sphere Parts pulsing with sine waves, transparent cylinder Part lasers with a wide halo/thin core, restored original particles/contact glows, cutting sparks and fracture bursts. Every drone has flight trails and exhaust. Couriers show pickup, committed parcel transfer, loaded flight, unloading and confirmed sale; Medics visibly charge before repairing. These are runtime effects in the existing place. See [work effects and validation limits](docs/review/WORK_EFFECTS.md).

## Latest owner changes: backpack and moving swarm

Toolbox audio adds a three-track APM background playlist, short action/reward cues, and Music/Effects controls inside the fleet menu. Neutral 13:30 daylight, softer shadows and reduced specular preserve clear native Roblox materials and the original sky. Existing crystal pops and crunches remain. See [audio, asset credits and validation limits](docs/review/AUDIO_LIGHTING.md). These changes join the same combined source-only review build.

Miners fill the player's 40-unit backpack, with no individual holds. Carry it to the Converter and use **Sell / U**. Finished miners regroup around you; leaving a plot brings your working swarm along, with orders resuming on return. Couriers collect at most eight units beside you, fly to the converter, sell after arrival, and return. Medics follow other drones and repair 10 health every two seconds through an attached beam. These support roles do not mine or attack.

The preview **Random loadout / T** button gives 2–5 drones with at least one miner. It changes no permanent saved ownership. Permanent types/IDs/base traits stay intact; a separate role distinguishes miners, breakers, healers and couriers. The first Blue remains the original mining drone, Red is a breaker, Green is a Medic, and alternating later Blues become Couriers.

The existing plot models are ordered by increasing distance from spawn and sell: Quartz, Ruby, Cobalt, Violet, Emerald. Native Concrete, Pavement, DiamondPlate, Metal, rough mineral beds and studded Plastic add variety with reduced specular shine.

The fleet uses centered uniform formations and bounded, neighbor-driven separation/passing through the original capped movement equations. Cards have two visible text elements and native SourceSans fonts. Supported 3D hierarchy: camera-local Part → SurfaceGui → ViewportFrame visual, with normal touch/controller hitboxes. See [current implementation and validation limits](docs/review/BACKPACK_SWARM.md).

## Historical project notes — superseded by the latest changes above

This branch originally restored the drone/mining presentation and implemented the one-drone → run cards → permanent fleet prestige loop. The following history is retained as reference; active builds use the captured Drone Blower revolution place described above.

[Draft review PR #1](https://github.com/Olivegord/mining-away/pull/1) remains unmerged pending owner/Studio review.

Current review branch: [`codex/restore-feel-prestige`](https://github.com/Olivegord/mining-away/tree/codex/restore-feel-prestige). Downloadable review builds, the original handoff and validation status are on the [source Page](https://chatgpt.com/space/page_80b705099bb481918ea713e1780329fe). Each release ZIP contains `revision.json` with its exact source commit and place checksum; it must say `source_dirty: false`. This candidate uses a retro parts-built map and a compact three-card comparison. Its independent [art-director gate](docs/review/ART_DIRECTOR_GATE.md) is **NOT VERIFIED** until the exact build is inspected in motion in Roblox Studio; historical screenshots do not validate it.

## Game handbook

Start with [docs/game/README.md](docs/game/README.md): [architecture](docs/game/architecture.md), [map reference](docs/game/map_reference.md), [full game design](docs/game/game_design.md), [implementation plan](docs/game/implementation_plan.md), [upgrades](docs/game/upgrades.md), and [every card](docs/game/upgrade_cards.md). The card catalog lists all 41 standard + 3 reserve outcomes, exact effects, targets, penalties, caps and saved legacy behavior; no pack grinding is needed to inspect it.

The [expanded valley and sparse hub review](docs/review/EXPANDED_MAP.md), [Alabaster Reach and upgrades review](docs/review/ALABASTER_UPGRADES.md), current [map reference](docs/game/map_reference.md), and [UI overhaul review](docs/review/UI_OVERHAUL.md) record the presentation passes and their evidence. Source-defined maps assemble when **Play** starts.

## Open the game

Use **build/Drone Blower revolution.rbxl**, or the existing connected **Drone Blower revolution** place (136098934779395). The immutable base is assets/drone-blower-revolution-base.rbxl. Studio uses isolated temporary Preview profiles. The owner will start the next run themselves.

A fresh profile owns one permanent drone. Click individual ores to assign work; additional explicit selections queue while workers are busy. Each worker has its own 40-unit starting hold. Click **Unload** (or U) to send loaded workers to the depot; payment occurs after their arrival. Recall cancels work. The first earned-currency pack costs 40 credits.

**Plot Scanner** unlocks plot commands and choosing the next stone automatically. **Auto Hauler** targets one named permanent drone: when its own hold fills it returns to unload, then resumes the assigned plot. Automation cards are run upgrades and clear on prestige. The smaller original drones work close to the minerals; manual work, full holds and delivery trips are visible without a permanent portrait bar.


At the depot's card machine, buy a pack with earned credits. Three saved choices appear; pick exactly one. Type cards affect the named built-in type; individual cards name the server-selected permanent drone. Every modifier says **This run**. Closing/rejoining keeps the identical paid offer, target and price. A startup-rate card halves its named drone's warmup when alone; it does not double damage.

Build a crew that can defeat Cobalt's original segmented pyramid. **Q / Evade** changes the crew's flank without retiring the assault roster; sentries visibly charge and fire at a frozen location, so moving before the shot can avoid it. **R / Recall** ends your participation. Destroyed drones reprint free at home after ten seconds plus two seconds of reconstruction, preserving identity, base traits and current-run cards. Reprinted drones retain their permanent identity and current run cards.

At 160 cumulative sale credits, optionally confirm the first prestige at the beacon; the second milestone is 400. These first two fleet additions do not require a guarded-field victory. The third requires 2,000 credits plus one Cobalt clear. Keep the existing Blue, add exactly one permanent Red, and reset credits, cargo, cards and offer progression. Unlocked plots stay unlocked. Begin the next run with both drones. Pack spending never subtracts from cumulative sale progress. There is no permanent fleet cap or discarded earned drone; six units are covered by math/identity tests, while engine performance at larger fleets remains unprofiled.

## Presentation pass

The review build uses an alabaster/teal alien landscape and a compact cream HUD with original native icons, rounded headings, tactile controls, and one focused menu at a time. Cards show their exact target, effect, drawback, stacking and before/after values; adaptive desktop cards keep all three actions visible, while phone choices scroll vertically. Fleet inspection separates permanent crew from run upgrades, and prestige shows what stays and resets. See the [UI references](docs/review/UI_REFERENCES.md) and [UI validation](docs/review/UI_OVERHAUL.md). Drones retain their original shell with type trim. Client-only effects include original crystal fractures, beam/impact effects, reconstruction, and segmented sentry motion; all gameplay remains server-owned. See the [sentry review](docs/review/SENTRY_ANIMATION.md) for current motion evidence.

## Mining satisfaction

The [research and design rationale](docs/MINING_SATISFACTION.md) prioritizes readable consequences and useful build choices. Blue drones cut continuously; Red drones deliver charged 0.8-second impacts with 50% extra shell/core damage; Green drones echo primary fractures into one eligible nearby resource. After Plot Scanner is earned, automatic target selection considers travel, work, payout and type strengths. Manual selection remains the starting behavior. Original assets and eased flight remain, with smaller low-flying workers, faster short work hops and server-owned gameplay. Final engine motion/audio and multiplayer validation remain required.

## Economy and tuning

| Field | Mining work | Maximum node budget | Units / ordinary node | Credits / unit | Regrowth delay | Defense |
|---|---:|---:|---:|---:|---:|---|
| Landing Quartz | 1× | 12 | 10 | 1 | 8 s | Safe |
| Ruby Grove | 1.8× | 16 | 12 | 2 | 14 s | Safe |
| Cobalt Ridge | 3.2× | 6 | 15 | 4 | 25 s | One original pyramid, 260 HP |
| Violet Basin | 5.2× | 9 | 16 | 7 | 35 s | Two pyramids, 390 HP each |
| Deep Emerald | 8× | 12 | 20 | 10 | 45 s | Two pyramids, 650 HP each |

A shell reserves five node-budget slots, then reveals one core and four smaller crystals. The core pays four ordinary-node yields; each shard pays one. Shell destruction pays nothing directly. Spawn separation, field insets and turret-footprint exclusion use bounded attempts; crowded fields retry rather than overlap. Ordinary growth is separate from regrowth delay. A growing resource cannot be reserved/mined.

The first pack costs 40 credits and each drone starts with 40 ore capacity. The early prestige milestones are 160 and 400 sold credits with no combat requirement; later milestones rejoin the Cobalt/Violet/Emerald progression. Exact subsequent pack prices and upgrade values live in Cards.lua; permanent milestones live in Profile.MILESTONES. These are provisional design values, not measured retention results.

The catalog includes Plot Scanner and Auto Hauler alongside the existing mining, combat, survival and cargo cards. New paid offers prioritize the next useful automation step while keeping three choices and one selection. Already-paid offers retain their original choices, effects and price. Server-owned per-drone cargo and delivery manifests preserve earned ore through save/reconnect boundaries; delivery crediting uses the same durable transaction/receipt system as purchases.


## Shared expedition rules

The current Studio implementation uses permanent plot unlocks. Clear a plot's guards once to retain access across prestige and reconnects. The merge preserves that newer behavior alongside manual ore orders and earned automation. Earlier timed-expedition descriptions and tests apply only to historical candidates.


## Persistence and authority

`Persistence.lua` uses UpdateAsync envelopes, unique server leases, revision fencing, bounded ordered retries and recent transaction receipts. Purchases, claims, sales and prestige commit before the UI/world report success. Lost responses reconcile the exact durable transaction, including postcommit fleet/stat rebuilds. Load/schema/lock failures spawn no default replacement profile and cannot overwrite established progress. See [docs/PERSISTENCE.md](docs/PERSISTENCE.md).

Stable drone IDs, types, base traits, prestige, run cards, credits, material cargo, sale progress, offer seeds/selection IDs and the complete pending offer persist. Ordinary newly mined cargo/wins autosave every 30 seconds and on leave/shutdown; a hard crash before that save can lose that most recent unsaved gameplay delta. Economy transactions include current dirty gameplay data in the durable write. An unresolved/uncertain save pauses the owner's simulation rather than granting speculative card/prestige effects. Corrupt paid-offer targets get the documented atomic full-price migration refund rather than a reroll.

Server models/logical positions, assignments, damage, resource slots, rewards, reprints and encounter gates remain authoritative. Clients render distinct local viewmodels from complete original templates using one elapsed-time-correct original movement layer; their transforms never authorize hits. Replicated attributes contain current goals, life, stages, growth timestamps and state for late joiners. Client profile snapshots omit RNG seeds and receipt ledgers. The one remote accepts bounded intent, not damage/reward multipliers or another owner's sale.

## Original art and reversible build

`assets/mining-away-base.rbxl` is the historical December 18, 2023 autosave, not an export of the live 2026 place. Its SHA256 is `480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b`. Original extracted scripts are in `reference/original/src/` for direct comparison.

The builder changes only the two controller source properties and Script/LocalScript enabled states. Every other binary asset/hierarchy/property chunk remains byte-identical. At runtime known experimental display props move into a preserved ServerStorage reference folder; original spawn, Converter, Ruby/Cobalt geometry and dormant construct integrate into the ground-level map. New trees/trails/depot stations extend that world instead of adding an elevated overlay. Original script/loader/plugin text is never executed by build tools.

Active guards clone the actual `construct` meshes (`bottemseg`, `lowerseg`, `upperseg`, `topseg`, `eye`, `eyecase`, `spawnEye`) and rig. The complete original/editor history remains in the source and full ServerStorage template. Only redundant editor `AnimSaves` history is omitted from live guard clones: the original construct has 3,444 instances, 3,429 of which are that editor hierarchy. This avoids replicating thousands of unused objects per enemy without deleting the source animation data.

Rollback is opening the unchanged asset base, or checking out the baseline commit. The builder refuses unknown base checksums and identical input/output paths, and backs up an existing generated place as `.rbxl.previous`. Do not patch the unavailable live place with this hash-locked builder.

## Reproduce and inspect

Use official pinned Luau 0.744 binaries (`luau`, `luau-compile`, `luau-analyze`). GitHub Actions downloads the pinned archive and verifies its SHA256.

```sh
python3 tools/test.py /path/to/luau-tools
python3 tests/binary.spec.py
python3 tests/geometry.spec.py
python3 tools/release.py
```

`release.py` builds the single `build/Mining Away.rbxl`, full tracked-source `build/mining-away-review.zip`, and exact `build/revision.json`. Source modules are bundled lexically into the preserved server/client entrypoints; they are not disconnected installer snippets.

The new tests cover original-equation 30/60/120/144 Hz motion, growth/three stages, all domain boundaries, actual-server/API-double behavior, real persistence logic with a fault-injecting storage double, source asset preservation and finite progression models. They replace the old three-drone baseline expectations. See [docs/review/VALIDATION.md](docs/review/VALIDATION.md), [progression model](docs/review/PROGRESSION_SIMULATION.md), [geometry/layout review](docs/review/ORIGINAL_GEOMETRY_AND_LAYOUT.md), and [UI review](docs/UI_REVIEW.md).

**Earlier Studio status (superseded by [latest review](docs/review/ALABASTER_UPGRADES.md)):** an intermediate polish build was reopened from disk and entered Play successfully; its depot, quarry lighting, material cleanup and HUD were inspected. Final gameplay, mesh/audio permissions, original-versus-repaired video, true visual parity, touch text layout, real DataStore operation, network latency and two-client/late-join behavior remain unverified. The Mac locked before the gameplay walkthrough; subsequent source fixes still need a final Studio pass. See [polish review](docs/review/POLISH_PASS.md). The historical source lacks the live-only RockCrack/RockBreak Sound objects; the renderer preserves those named references when available and otherwise uses quiet engine-bundled impact sounds verified in the installed Studio content directory. The outside-engine map schematic and API doubles are not screenshots or multiplayer proof. Follow [docs/STUDIO_ACCEPTANCE.md](docs/STUDIO_ACCEPTANCE.md) before release. Nothing was published to Roblox.
