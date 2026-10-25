# Mining Away

One Roblox game, one source repository: **https://github.com/Olivegord/mining-away**.

The repository owns editable code, the original asset place, design requirements, build tooling, and tests. `build/mining-away.rbxl` is a generated review artifact of this game. It is not a separate project or a new published Roblox experience.

## Current work

The first cloud implementation is imported as a development baseline. Its movement, crystal generation, mining presentation, and UI were rejected by the owner. Do not treat its visuals or behavior as the desired reference. The original source under `reference/original/src/` defines the feel to restore.

The next update must restore near parity with the original smooth drone movement, directly overhead mining, three fracture stages, random crystal placement, and two-second crystal growth. It then adds a one-drone start, run-only choice-of-three card packs, permanent drones earned through prestige, enemy turret progression, and a simple-shape alien map using the existing segmented pyramid as a turret.

The latest owner requirements in `docs/OWNER_REQUIREMENTS.md` override the older design document and the first cloud build. The supporting parity, card, progression, and acceptance documents are in `docs/`.

## Editable files and build

- `src/`: editable server, client, world, config, and rule source.
- `assets/mining-away-base.rbxl`: immutable original asset/hierarchy baseline; SHA-256 `480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b`.
- `reference/original/src/`: extracted original controllers for visual and motion parity. These are reference data, not extra runtime entrypoints.
- `reference/cloud-v1/`: audit notes and checks from the first, rejected cloud presentation.
- `tools/`: deterministic, asset-preserving builder and validation.
- `tests/`: rule, server, and asset-preservation checks.
- `build/mining-away.rbxl`: generated from the files above, ignored by Git.

```sh
python3 tools/build.py assets/mining-away-base.rbxl --output build/mining-away.rbxl
python3 tests/binary.spec.py
# With official Luau binaries installed:
python3 tools/test.py /path/to/luau-binaries
```

Open the generated place in Studio. Edit source in this repository and rebuild; avoid editing a second standalone place and letting it drift. The original asset file must never be overwritten by a generated build. Until live Studio sync is added, source changes require a rebuild and reopen. GitHub alone does not live-sync an open Studio session.

## Working and reviewing

Use `main` for a known source checkpoint and `codex/restore-feel-prestige` for the next update. Include the exact commit in build metadata and downloadable review packages. Do not publish a Roblox place or create another Roblox experience as part of an overnight update.

Preserve existing models and base-world identity. Report engine/visual tests honestly. Pure Luau tests and API doubles cannot establish that the game looks good or that real networking works.

