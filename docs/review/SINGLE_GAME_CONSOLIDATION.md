# Single-game consolidation status

Canonical game: `build/Drone Blower revolution - editable workspace.rbxl`, existing Roblox place `136098934779395`.

The specialist runtime Sources are retained in committed revision `bbc4692`. The obsolete cloud-generated plain artifact, historical generated copies and competing review ZIPs were verified reproducible/source-backed before removal. No immutable source asset was deleted.

Removed from this cloud checkout:

- `build/Drone Blower revolution.rbxl` — SHA-256 `0d1793dd8c052e22f1175c64bcb59cc10d09846465ede7c7159ff5a75b266faa`.
- `build/mining-away.rbxl` — SHA-256 `a1cde389efbbf99dce1e900a5fa7ae26cd1b37e39c170223f20aad1559150958`.
- `build/mining-away.rbxl.previous` — SHA-256 `a1cde389efbbf99dce1e900a5fa7ae26cd1b37e39c170223f20aad1559150958`.
- `build/drone-blower-revolution-review.zip` — SHA-256 `64951753743472cf4195f650a3703a745b21e91c636c80fc8dc8b8e07a112953`.
- `build/mining-away-review.zip` — SHA-256 `75065ab925ffb6b657cb6684deb08987dfda19e0c6660438dee63c1947ff679e`.
- `build/revision.json` — SHA-256 `c829930d494ba4c023fe7e592c6ca01de653a2d26b48df163b19c6523b4e9c00`.
- `build/build-report.json` — SHA-256 `d4eb62ab2e840298151a78339662708c8b9225ce27e7cdc8f0115574f25c382d`.

Tooling now requires the existing canonical native file; default build/release/consolidation commands cannot substitute a reference capture. Release ZIPs contain one playable `.rbxl` only. CI emits Sources instead of manufacturing a game.

Validation: 16 disposable-project workflow checks passed, covering native geometry and backup preservation, exact prior payload/commit refresh, unknown edits, missing-native refusal, one-place ZIP contents, safe duplicate deletion, and unknown archived map/source preservation. Active-capture and historical binary tests also passed. Python syntax and diff checks passed. This is file/source verification, not Studio or multiplayer evidence.

The actual canonical editable file and the two open Studio instances are on the Mac. This cloud chat has no local Studio/filesystem tool, so it has **not** installed the specialist Sources into that document, closed either Mac window, or deleted the Mac duplicate. Those local actions remain outstanding. The canonical file is absent here and is intentionally not fabricated. See [local consolidation procedure](../SINGLE_GAME_WORKFLOW.md).
