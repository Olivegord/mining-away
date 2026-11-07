# DRONEREVOLUTION

**One shared repository:** [Olivegord/mining-away](https://github.com/Olivegord/mining-away). The current integration branch is **`codex/restore-feel-prestige`**.

**Open this game file:** [`build/DRONE_GAME.rbxl`](build/DRONE_GAME.rbxl). It is checked into this repository and contains the authored map and installed game scripts.

**Existing shared Roblox game:** [DRONEREVOLUTION](https://www.roblox.com/games/124078027733625), place **124078027733625**, universe **10774898335**. MideDibber has Playtest and Edit access, verified November 6, 2026. Publication of the latest local file to that game is **not yet verified**. GitHub updates do not publish Roblox.

**Drone Blower revolution** (place **136098934779395**) is a separate older Roblox experience. It supplied the historical reference capture. It is not another name for the shared game.

## Start here with Codex

Open this same repository in Codex and start with:

> Read AGENTS.md, docs/OWNER_REQUIREMENTS.md, docs/PROJECT_STATE.md and docs/COLLABORATION.md. Continue this existing game. Verify the current revision and canonical file before making changes. Do not create another game or publish to Roblox.

[Project state and prior decisions](docs/PROJECT_STATE.md) records the current implementation, exact native-file checksum, accepted direction, rejected approaches and remaining verification. [Collaboration](docs/COLLABORATION.md) explains shared access, contributions and native-file ownership. Codex's repository instructions live in [AGENTS.md](AGENTS.md).

## Current gameplay

The current candidate connects **mine → sell → buy upgrades/miners → prestige**:

- A new player starts with one permanent drone and a 40-ore backpack.
- Sell at the existing Converter pays spendable mineral currency immediately.
- Mining power begins at 20 Quartz; a permanent Miner begins at 60 Quartz.
- Prestige adds an earned drone and +25% permanent base mining power; existing permanent drones survive.
- Rocks are cubic, snap smaller without spinning, and eject drops upward and outward. One drone type may work on a rock at a time.
- Orbital Beacons and Scrap Capsules are stored consumables, placed deliberately through backpack pockets.

See [core-loop changes and actual test evidence](docs/review/CORE_LOOP.md), [mining satisfaction criteria](docs/MINING_SATISFACTION.md), and [consolidated VFX direction](docs/VFX_INSTRUCTIONS.md). Implemented behavior and passing tests do not establish that the owner finds the game fun.

## Work on the same file

Edit the readable Luau in `src/`. Only seven allowlisted native Sources are refreshed into `build/DRONE_GAME.rbxl`; authored geometry, assets and backup scripts remain intact. `assets/*.rbxl` are immutable historical references, not playable alternatives. Follow the [single-game workflow](docs/SINGLE_GAME_WORKFLOW.md).

For Python tooling use Python 3.9+ and a Zstandard decoder (`zstd` or the Python `zstandard` package). Tests use official Luau 0.744 tools, pinned in [CI](.github/workflows/validate.yml).

```sh
python3 tools/build.py
python3 tools/test_core_loop.py /path/to/luau-tools
python3 tests/single-game.spec.py
```

`build.py` validates the tracked native document against current Sources. After changing Sources, refresh using the exact previous installed commit or payload; unknown native edits must be reconciled. Save and commit the same canonical native file with the source change. Stop Play and close Studio when finished.

After committing, `python3 tools/release.py` packages exactly that native file, source text and revision/preservation reports in `build/drone-blower-revolution-review.zip`. The historical ZIP name is an artifact name, not a Roblox destination. The command does not publish Roblox.

## Sharing and publishing

Share **this repository's URL** for code, context and the current `.rbxl`. Public visibility allows reading; direct contributions to the shared repository require a GitHub collaborator invitation. Roblox permissions and GitHub permissions are independent.

Updating the online game is a separate, explicitly authorized action: open `build/DRONE_GAME.rbxl`, choose **File → Publish As / Publish to Roblox As**, select the existing **DRONEREVOLUTION** experience and its starting place **124078027733625**, then **Overwrite**. Reconcile any newer collaborator edits first. Verify the resulting published version and update [project state](docs/PROJECT_STATE.md). Do not create a new experience/place or delete either existing cloud game as part of ordinary synchronization.

Additional references: [architecture](docs/game/architecture.md), [persistence](docs/PERSISTENCE.md), [original-feel parity](docs/ORIGINAL_FEEL_PARITY.md), [game handbook](docs/game/README.md), [Studio acceptance](docs/STUDIO_ACCEPTANCE.md).
