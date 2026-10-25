# Mining Away

The single source project is [Olivegord/mining-away](https://github.com/Olivegord/mining-away). This branch restores the original drone/mining presentation and implements the one-drone → run cards → permanent fleet prestige loop. It builds the same game from its preserved original assets. It does not create or publish another Roblox experience.

[Draft review PR #1](https://github.com/Olivegord/mining-away/pull/1) remains unmerged pending owner/Studio review.

Current review branch: [`codex/restore-feel-prestige`](https://github.com/Olivegord/mining-away/tree/codex/restore-feel-prestige). Downloadable review builds, the original handoff and validation status are on the [source Page](https://chatgpt.com/space/page_80b705099bb481918ea713e1780329fe). Each release ZIP contains `revision.json` with its exact source commit and place checksum; it must say `source_dirty: false`.

## Run the review copy

Open `build/mining-away.rbxl` in Studio and Play. Studio/unpublished sessions use an explicitly labeled **isolated temporary Preview adapter**, including negative local-test user IDs. Preview is not durable storage. The published-server code contains a real UpdateAsync/session-lock adapter; this cloud pass did not enable API access, touch live player data or publish to Roblox.

A fresh profile owns one permanent Blue drone. Walk toward Landing Quartz or Ruby Grove, then click a field or use its contextual assignment button. Drones follow in the original radius-10 ring, ease and decelerate in flight, settle directly above a rock, warm their laser, and mine. Crystals use the original union, organic server-random positions, 50–100 base HP, two-second growth and 75/50/25% shrink/tilt stages. Cargo fills and the crew recalls. Use the original Converter to sell.

At the depot's card machine, buy a pack with earned credits. Three saved choices appear; pick exactly one. Type cards affect the named built-in type; individual cards name the server-selected permanent drone. Every modifier says **This run**. Closing/rejoining keeps the identical paid offer, target and price. A startup-rate card halves its named drone's warmup when alone; it does not double damage.

Build a crew that can defeat Cobalt's original segmented pyramid. **Q / Evade** changes the crew's flank without retiring the assault roster; sentries visibly charge and fire at a frozen location, so moving before the shot can avoid it. **R / Recall** ends your participation. Destroyed drones reprint free at home after ten seconds plus two seconds of reconstruction, preserving identity, base traits and current-run cards. Replacements cannot reinforce a locked assault.

At 2,000 cumulative sale credits plus one Cobalt clear, optionally confirm prestige at the beacon. Keep the existing Blue, add exactly one permanent Red, and reset credits, cargo, cards, offer progression and your run's field rights. Begin the next run with both drones. Pack spending never subtracts from cumulative sale progress. There is no permanent fleet cap or discarded earned drone; six units are covered by math/identity tests, while engine performance at larger fleets remains unprofiled.

## Presentation pass

The review build now uses a weathered quarry/depot palette, warm sun and cool shadows, grounded field geology and readable route signs. A 72-pixel instrument HUD gives the next useful action; cards show their exact target, effect, drawback, stacking and before/after values. Drones retain their original shell with type trim. Client-only animation adds impact flashes, shot recoil, tumbling authored drone debris, printer reconstruction, segmented sentry aiming/charge/collapse/revival, mineral chips, shield/repair pulses and visible fork/arc beams. All gameplay remains server-owned. See [polish review](docs/review/POLISH_PASS.md) for actual verification and limitations.

## Economy and tuning

| Field | Maximum node budget | Units / ordinary node | Credits / unit | Regrowth delay | Defense |
|---|---:|---:|---:|---:|---|
| Landing Quartz | 12 | 10 | 1 | 8 s | Safe |
| Ruby Grove | 16 | 12 | 2 | 14 s | Safe |
| Cobalt Ridge | 6 | 15 | 4 | 25 s | One original pyramid, 260 HP |
| Violet Basin | 9 | 16 | 6 | 35 s | Two pyramids, 390 HP each |
| Deep Emerald | 12 | 20 | 8 | 45 s | Two pyramids, 650 HP each |

A shell reserves five node-budget slots, then reveals one core and four smaller crystals. The core pays four ordinary-node yields; each shard pays one. Shell destruction pays nothing directly. Spawn separation, field insets and turret-footprint exclusion use bounded attempts; crowded fields retry rather than overlap. Ordinary growth is separate from regrowth delay. A growing resource cannot be reserved/mined.

Packs cost 80, 110, 150, 210, 290, 400 credits, then grow by rounded ×1.30. Cargo starts at 120 units. The first five prestige sale targets are 2,000 / 5,000 / 11,000 / 22,000 / 42,000 with Cobalt×1 / Cobalt×2 / Violet×1 / Violet×2 / Emerald×1 respectively; later targets scale ×1.75 with increasing Emerald wins. These are provisional curves, not measured retention targets.

Authoritative tuning lives in `src/Config.lua` for fields/encounters/timing, `Profile.BASE`, `Profile.TYPE_SCALES` and `Profile.MILESTONES` for permanent traits/milestones, and `Cards.lua` for catalog, pack prices, capacity and caps. All 35 catalog entries are implemented, including bounded critical hits, split mining, chained shots, once-per-attempt shields, geode drilling, finishing damage, kill repair and shot-rate changes. Early packs expose a behavior-changing option when eligible. Pending paid offers keep their original payload across this catalog revision. Contributions add against immutable type-adjusted bases; the direct combat DPS cap applies **after** shot damage × shot rate. Crit and one-target splash are separately bounded, not unlimited chain effects. See the design and simulation reports before tuning.

## Shared expedition rules

Guarded fields have one coherent visible turret roster. A four-second muster locks `(player, run, permanent drone, life)` and combat stats. No new player, reprint, reconnect or prestige-created unit can join that active attempt. Dead units lose reservations and combat immediately. A wipe, abandonment or 90-second limit resets **all** defenses, including destroyed turrets, before a six-second cooldown. Partial kills pay no separate reward and leave no chip damage for the next attempt.

Only a non-retired participating player/run that actually dealt turret damage earns the victory entitlement. An outsider sees the same battle but cannot inherit mining permission. Every protected mining hit/reward checks the current run and exact shared encounter ID. A cleared expedition remains open to its entitled crews until all finish/leave plus eight seconds; resource regrowth never respawns guards over a mining crew. Recall/disconnect/prestige removes only that player's participation/permission. A teammate's continuing fight or expedition is not reset. Clearing wins are counted once per encounter, with a bounded deduplication ledger.

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

`release.py` builds the single `build/mining-away.rbxl`, full tracked-source `build/mining-away-review.zip`, and exact `build/revision.json`. Source modules are bundled lexically into the preserved server/client entrypoints; they are not disconnected installer snippets.

The new tests cover original-equation 30/60/120/144 Hz motion, growth/three stages, all domain boundaries, actual-server/API-double behavior, real persistence logic with a fault-injecting storage double, source asset preservation and finite progression models. They replace the old three-drone baseline expectations. See [docs/review/VALIDATION.md](docs/review/VALIDATION.md), [progression model](docs/review/PROGRESSION_SIMULATION.md), [geometry/layout review](docs/review/ORIGINAL_GEOMETRY_AND_LAYOUT.md), and [UI review](docs/UI_REVIEW.md).

**Studio status:** an intermediate polish build was reopened from disk and entered Play successfully; its depot, quarry lighting, material cleanup and HUD were inspected. Final gameplay, mesh/audio permissions, original-versus-repaired video, true visual parity, touch text layout, real DataStore operation, network latency and two-client/late-join behavior remain unverified. The Mac locked before the gameplay walkthrough; subsequent source fixes still need a final Studio pass. See [polish review](docs/review/POLISH_PASS.md). The historical source lacks the live-only RockCrack/RockBreak Sound objects; the renderer preserves those named references when available and otherwise uses quiet engine-bundled impact sounds verified in the installed Studio content directory. The outside-engine map schematic and API doubles are not screenshots or multiplayer proof. Follow [docs/STUDIO_ACCEPTANCE.md](docs/STUDIO_ACCEPTANCE.md) before release. Nothing was published to Roblox.
