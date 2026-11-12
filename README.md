# DRONEREVOLUTION

**One shared repository:** [Olivegord/mining-away](https://github.com/Olivegord/mining-away). The current integration branch is **`codex/restore-feel-prestige`**.

**Normal test entry:** the existing shared **DRONEREVOLUTION** Studio Edit session. The candidate Sources are exported under `studio/` and installed in [`build/DRONE_GAME.rbxl`](build/DRONE_GAME.rbxl), the sole canonical map/recovery snapshot. Shared Edit installation of this cloud candidate is pending verification; the last verified native save is 219. See project state before starting Studio testing.

**Existing shared Roblox game:** [DRONEREVOLUTION](https://www.roblox.com/games/124078027733625), place **124078027733625**, universe **10774898335**. MideDibber has Playtest and Edit access, verified November 6, 2026. Publication of the latest local file to that game is **not yet verified**. GitHub updates do not publish Roblox.

**Drone Blower revolution** (place **136098934779395**) is a separate older Roblox experience. It supplied the historical reference capture. It is not another name for the shared game.

## Start here with Codex

Open this same repository in Codex and start with:

> Read AGENTS.md, docs/OWNER_REQUIREMENTS.md, docs/PROJECT_STATE.md and docs/COLLABORATION.md. Continue this existing game. Verify the current revision and canonical file before making changes. Do not create another game or publish to Roblox.

[Project state and prior decisions](docs/PROJECT_STATE.md) records the current implementation, exact native-file checksum, accepted direction, rejected approaches and remaining verification. [Collaboration](docs/COLLABORATION.md) explains shared access, contributions and native-file ownership. Codex's repository instructions live in [AGENTS.md](AGENTS.md).

## Current gameplay

The current candidate connects **mine Quartz → sell → buy a pack with one pick included → stack upgrades → prestige → grow your permanent fleet**:

- Crystal Run starts with three Laser Miners, Needler, Ballcaster, Vacuum and Compactor as permanent units, plus two run Emptiers. Existing saved fleets remain intact. The backpack starts with ten physical cargo slots.
- Pin a square over crystals. Miners finish their cuts, release physical ore, and preserve the current deep-field hardness and distinct attacks. Raw cargo homes from nine studs after landing; Emptiers sell real parcels at the counter.
- Buy a pack at the physical Pack Counter for 20, 27, 36, 49, 66… Quartz. Open the delivered crate and choose one of three saved upgrades; selection is included in the pack price. Repeat purchases stack eligible owned upgrades at increasing prices.
- The first three prestige goals are **160, 400 and 1,000 Quartz sold**. Buying packs never reduces that progress. Later existing thresholds are retained. The beacon previews three distinct permanent choices before eligibility and favors unowned roles when available.
- Prestige preserves the owned fleet, adds exactly one chosen permanent drone, and resets run cards, Stars, cargo and balances. The first three prestiges each add 50 percentage points of permanent base mining power; later prestiges add 25 points. Existing drone base traits and profile records are preserved.
- A compact `Next drone` readout shows sale progress. The initial view faces Crystal Run, and hulls fade locally when they obscure the avatar. The existing map, attack effects, pack reveal and original drone movement remain in place.
- Loose earned cargo receives bounded return-trip grace during depot visits, even with a partially filled bag. This uses the existing 180-second maximum rather than an unlimited stash.

See [this progression pass and verification limits](docs/review/PROGRESSION_OVERHAUL.md), [historical Quartz design and test evidence](docs/review/QUARTZ_POOL.md), [mining satisfaction criteria](docs/MINING_SATISFACTION.md), and [consolidated VFX direction](docs/VFX_INSTRUCTIONS.md). Implemented behavior and passing tests do not establish that the owner finds the game fun.

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
