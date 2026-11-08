# DRONEREVOLUTION

**One shared repository:** [Olivegord/mining-away](https://github.com/Olivegord/mining-away). The current integration branch is **`codex/restore-feel-prestige`**.

**Normal test entry:** the existing shared **DRONEREVOLUTION** Studio Edit session. Its seven managed Sources match the saved [`build/DRONE_GAME.rbxl`](build/DRONE_GAME.rbxl), the sole canonical map/recovery snapshot. See project state before testing: the latest short Play was stopped at about 4.3 GB RAM.

**Existing shared Roblox game:** [DRONEREVOLUTION](https://www.roblox.com/games/124078027733625), place **124078027733625**, universe **10774898335**. MideDibber has Playtest and Edit access, verified November 6, 2026. Publication of the latest local file to that game is **not yet verified**. GitHub updates do not publish Roblox.

**Drone Blower revolution** (place **136098934779395**) is a separate older Roblox experience. It supplied the historical reference capture. It is not another name for the shared game.

## Start here with Codex

Open this same repository in Codex and start with:

> Read AGENTS.md, docs/OWNER_REQUIREMENTS.md, docs/PROJECT_STATE.md and docs/COLLABORATION.md. Continue this existing game. Verify the current revision and canonical file before making changes. Do not create another game or publish to Roblox.

[Project state and prior decisions](docs/PROJECT_STATE.md) records the current implementation, exact native-file checksum, accepted direction, rejected approaches and remaining verification. [Collaboration](docs/COLLABORATION.md) explains shared access, contributions and native-file ownership. Codex's repository instructions live in [AGENTS.md](AGENTS.md).

## Current gameplay

The current candidate connects **mine Quartz → sell → draft a blueprint → buy its levels → prestige → grow your permanent fleet**:

- A new player starts with one permanent drone and a 40-ore backpack.
- Sell at the existing Converter pays spendable mineral currency immediately.
- Either workshop counter sells packs at 20, 45 and 80 Quartz. Choose one of three blueprints per pack, with three build slots per run.
- Common/Rare/Epic/Legendary blueprints start at levels 1/2/3/4. Buy more levels in the same shop, starting at 20 Quartz and increasing geometrically.
- Power, ignition, carrying capacity, yield, automatic routing and nearby Prism damage are the six mechanics. The shop shows the next level's actual effect.
- First prestige requires 360 Quartz sold; spending keeps progress. Prestige clears the run build, adds a permanent mining drone and +25% base mining power, and keeps the existing fleet. New direct drone purchases are retired.
- Rocks are cubic, snap smaller without spinning, and eject drops upward and outward. One drone type may work on a rock at a time.
- Orbital Beacons and Scrap Capsules are stored consumables, placed deliberately through backpack pockets.

See [Quartz design and actual test evidence](docs/review/QUARTZ_WORKSHOP.md), [mining satisfaction criteria](docs/MINING_SATISFACTION.md), and [consolidated VFX direction](docs/VFX_INSTRUCTIONS.md). Implemented behavior and passing tests do not establish that the owner finds the game fun.

## Work on the same file

Edit the readable Luau in `src/`. Only seven allowlisted native Sources are refreshed into `build/DRONE_GAME.rbxl`; authored geometry, assets and backup scripts remain intact. `assets/*.rbxl` are immutable historical references, not playable alternatives. Follow the [single-game workflow](docs/SINGLE_GAME_WORKFLOW.md).

For Python tooling use Python 3.9+ and a Zstandard decoder (`zstd` or the Python `zstandard` package). Tests use official Luau 0.744 tools, pinned in [CI](.github/workflows/validate.yml).

```sh
python3 tools/build.py
python3 tools/test_workshop.py /path/to/luau-tools
python3 tests/single-game.spec.py
```

`build.py` validates the tracked native document against current Sources. After changing Sources, reconcile Studio-origin edits, run `python3 tools/script_sync.py`, verify actual Source arrival and root status in shared Edit, then refresh the canonical file using the exact previous installed commit or payload. Unknown native edits must be reconciled. Stop Play at handoff; leave Studio open if it was already open, otherwise close the session you started.

After committing, `python3 tools/release.py` packages exactly that native file, source text and revision/preservation reports in `build/drone-blower-revolution-review.zip`. The historical ZIP name is an artifact name, not a Roblox destination. The command does not publish Roblox.

## Sharing and publishing

Share **this repository's URL** for code, context and the current `.rbxl`. Public visibility allows reading; direct contributions to the shared repository require a GitHub collaborator invitation. Roblox permissions and GitHub permissions are independent.

Publish only when the owner asks for a release. Reconcile newer collaborator edits, verify the selected shared document's place **124078027733625** and universe **10774898335**, then publish that existing document. Verify direct publication evidence without using Version History, and update [project state](docs/PROJECT_STATE.md). The [collaboration guide](docs/COLLABORATION.md) covers recovery from the canonical snapshot. Do not create a new experience/place or delete either cloud game as part of ordinary synchronization.

Additional references: [architecture](docs/game/architecture.md), [persistence](docs/PERSISTENCE.md), [original-feel parity](docs/ORIGINAL_FEEL_PARITY.md), [game handbook](docs/game/README.md), [Studio acceptance](docs/STUDIO_ACCEPTANCE.md).
