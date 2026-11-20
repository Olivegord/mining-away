# Stored mining equipment

November 5, 2026. Existing Drone Blower revolution, Roblox place `136098934779395`, branch `codex/restore-feel-prestige`. This candidate extends integrated revision `b01815cbd01602a8ec947cfc9885140a1110428c`. The final exact source revision is recorded in the review package's `revision.json`; this document does not claim an engine playtest.

## Changed behavior

Rocks now discover equipment the player can keep and deliberately place. The previous ten-second ore/mining multiplier discoveries are removed. An **Orbital Beacon** melts the nearest eligible rock within its 12-stud placement radius after the existing charge. A **Scrap Capsule** sends six miniature miners through a 16-stud area for ten seconds. Both use the existing authoritative mining/contact path and original orbital/scrap presentation. Ordinary ore remains the reward; consumable-touched rocks and their geode descendants cannot generate more equipment.

Two compact backpack pockets store three charges apiece, separately from ore cargo. They appear after the first collection. Desktop uses **Z / X**, then a world click; **Escape** cancels. Touch selects a pocket, taps a location and uses **Place tool**. Controller uses D-pad left/right, R1/R2 at the center aim and B to cancel. An area preview and orbital target outline support choosing a useful position. Stored charges survive prestige and normal reconnects; run cards still reset. Newly collected rewards share the existing autosave limitation during an abrupt crash.

The first Orbital appears on the third eligible break, then the first Scrap appears five eligible breaks after collection. Subsequent chance rises from 18% to 30% with field tier and guarantees a discovery by the eighth eligible break. Full pockets and an already-present world case suspend rolling; missed/expired cases do not erase the earned guarantee. Equipment uses a 30-second world lifetime, owner-only collection, clear reach and the existing save-health gate.

The [research](../PROGRESSION_AND_CONSUMABLES_RESEARCH.md) compares Bee Swarm, Factorio, Satisfactory, Slay the Spire and Balatro with motivation research. It distinguishes source evidence from design hypotheses and records the drop simulation and remaining playtest decisions.

## Authority and persistence review

The first review followed behavior and original-feel parity. Existing permanent worker movement, meshes, cards, mineral payouts, specialist unlocks/cooldowns, guards, crystal audio and map are retained. Consumables use separate ability state and effect identifiers. Default permanent Orbital selection still chooses the largest reachable rock; only a placed tool uses the nearest candidate. A numerical correction prevents a completed burn leaving a microscopic positive-health residue.

Schema 8 adds the separate inventory, validates bounded counts and reservation data, and migrates schema 7 without replacing existing progress. A versioned durable transaction reserves the tool before any world damage. Uncertain saves pause the deployment. Cancellation before accepted contact returns exactly one charge, including recovery of a saved unfinished reservation. Accepted contact clears the refund reservation. Placement checks run, field access, bounds, range and line of sight; target checks repeat ownership, living-worker eligibility, readiness and obstruction during mining. Client aim and clicks never authorize damage or rewards.

The second review covered pacing, visual clarity and multiplayer rules. One world case and one active deployment per owner bound added objects/work. Existing all-observer effect rendering is reused, with a separate namespace so permanent abilities continue independently. Preview excludes replicated foreign reservations and guarded fields; the server remains authoritative when replication is stale. These are code-level findings. Real rendering, replication, input comfort and enjoyment remain unverified.

## Executed checks

Use official Luau 0.744 binaries. The following passed on this candidate:

| Command | Evidence |
| --- | --- |
| `python3 tools/test_consumables.py /path/to/luau` | 9 rule/profile checks; 11 actual-server consumable checks; 11 retained actual-server gadget checks; 7 placement/input checks; full client/server bundle compilation. Server/client tests use Roblox API doubles. |
| `python3 tools/test_special_logistics.py /path/to/luau` | Existing specialist ownership, carrier/storage, preview, effect lifecycle, motion and HUD checks; all source compilation. Test-only closures prevent fixture local-register exhaustion after bundling the new modules. |
| `python3 tools/test_refinement_client.py /path/to/luau` | Existing movement, intent routing, highlights and impact checks. |
| `python3 tools/test_shops.py /path/to/luau` | Shop/mining/persistence rules, selected pure-module analysis, actual-server shop checks, all-source/bundle syntax and immutable-capture preservation. |
| `python3 tools/test_mining_flight.py /path/to/luau` | Existing committed work, delayed observer snapshots, movement and work-only difficulty model. |
| `python3 tests/single-game.spec.py` | 16 sole-game refresh, unknown-edit refusal and release-packaging cases. |

The deterministic 20,000-break simulation per tier produced average discovery gaps of 4.36 eligible breaks at tier 1 and 3.14 at tier 5, with no gap over eight. This measures the implemented distribution, not minutes played, retention or fun.

The broad gadget runner still stops in the unchanged `tests/mining-contact.assert.lua` particle assertions, before its later fixtures. The legacy profile suite still expects schema 2; the starting revision reproduces its `7 ~= 2` failure. Neither aggregate is reported as passing. The current-feature persistence checks and the independently executed gadget server cases above pass. A whole-bundle analysis attempt with incomplete Roblox host type stubs is also not a successful lint result.

## Canonical file and remaining review

The existing `build/DRONE_GAME.rbxl` was refreshed using its verified pre-change seven-Source payload. Native SHA-256 changed from `ce39f9c27771f2790a3d800f17c79b7903b852b62890181c3b7427990008825f` to `b8fb19a6bc47becc2408e8f08cb367bcedef06feffb258c16b51ebce1df772a5`. All non-Source chunks and unrelated/backup Sources remain byte-identical to the canonical input. No alternative playable or replacement capture was created. After committing source, `python3 tools/release.py` packages that same file with its clean source revision; the ZIP contains exactly one `.rbxl`.

Studio discovery returned zero connected instances. No live session was installed, opened, started or visually tested. Follow the research document's production one-drone playtest, including desktop/phone layouts, touch/controller, hard-rock versus cluster use, two players and a late join. Check all-observer effects, obstacles, refund feedback and whether players use or hoard the tools. The current cap and drop rates are provisional until that evidence exists. Nothing was published to Roblox.
