# Quartz workshop candidate — November 8, 2026

**Superseded:** the owner rejected the three-blueprint cap, workshop UI and rarity-as-extra-stacks rule. See [the implemented Quartz pool replacement](QUARTZ_POOL.md). This file preserves the earlier candidate's evidence and limits, not the current design.

Baseline: `9bed0b81c673abe36d82d1075252963d1713aff6`. Installed gameplay/native revision: `36c678db4fd54f87181c261f4d220bb53a959224`. A later handoff-only commit records this exact revision without changing the build. No Roblox publication.

## The small loop

Mine Quartz, sell it, buy a pack, choose one of three blueprints, buy repeated levels of that blueprint, and prestige into a larger permanent mining fleet. Both existing Quartz/pack counters open the same workshop. There are three blueprint slots per run, six possible mechanics, and no new mineral dependency. The other authored shops remain in the map with disabled prompts and “LATER” signs; legacy owned upgrades, drones and paid offers are preserved.

The official [Leaf Blower Revolution description](https://store.steampowered.com/app/1468260/) connects collecting, upgrades, automation and prestige. Its community [prestige reference](https://leafblowerrevolution.wiki.gg/wiki/Prestige) also describes repeatable upgrades and resets. Our design inference is to randomize which mechanics become available, then let the player deliberately invest in their chosen mechanics. This preserves the satisfaction of repeat purchases without reopening a large catalog after every sale. It is a candidate to playtest, not evidence that these exact prices are fun.

| Decision | Current rule |
| --- | --- |
| New player | Exactly one permanent drone, zero Quartz, capacity 40 in both Studio and production |
| Draft | Pay 20 / 45 / 80 Quartz for the next slot; server rolls three distinct useful unowned options, choose one |
| Rarity | Common / Rare / Epic / Legendary starts at level 1 / 2 / 3 / 4; existing 66% / 24% / 8% / 2% roll odds |
| Repeat purchases | From level 1 onward: 20, 34, 58, 98, 167 Quartz, subject to that mechanic's cap |
| Prestige | First run: 360 Quartz sold; later `floor(360 * (1 + prestiges)^1.35)`; buying upgrades never subtracts progress |
| Reward/reset | Add one permanent mining drone and +25% base mining power; keep fleet identities/traits, clear run cards/levels and currency |

Higher rarity grants real levels and skips their purchase costs. It does not add another menu or a new currency. A second blueprint competes with a cheaper upgrade to the first. A capped or ineffective level cannot charge the player, and a pack with fewer than three useful distinct options cannot charge them. Legacy modifiers can reach these caps, so those profiles may need to prestige before drafting again.

| Blueprint | Each level | Limit |
| --- | --- | --- |
| Power Cell | +50% additive mining power | 6 |
| Quick Ignition | +1 startup-rate multiplier, shortening warmup | 6 |
| Deep Pockets | +50% base backpack capacity | 4 |
| Quartz Polisher | +25% ore yield | 4 |
| Route Runner | +40% flight speed; level 1 also enables automatic retargeting in the commanded field | 5 |
| Prism Relay | +10% nearby fork damage; 12-stud reach, no recursive forks | 4 |

Prestige awards Red/Charger, Bubbler, Halver, Blue/Striker, Gridcutter and Singularity in a repeating sequence. All are actual mining workers. New direct drone purchases are disabled, while prior purchase receipts and permanent ownership remain valid. The yard points to the workshop and prestige review; existing transport management remains available. Cards and repeat purchases show their actual before/after effects. Teal, coral, gold, blue, green and violet panels replace the separate gray shop list; common crates now have cyan color.

## Authority and preservation

Server owns payments, choices, levels, damage and prestige. The paid offer is saved before presentation and is reused after reconnect. Repeated/stale requests cannot spend twice. Pending drafts must be resolved before leveling or prestige. v8 profiles migrate to v9 with prior sale progress grandfathered once; subsequent sales, courier deliveries and storage launches advance prestige only for Quartz. Existing run modifiers and already-paid legacy choices survive migration. Prestige retains exact existing drone identities and base traits.

Only the two bundled managed Sources changed. The seven-source native refresh preserves all unrelated Sources, backups and map geometry. The separate checked scenery patch modifies exactly 26 existing label/prompt properties, creating/deleting no instances. [Property plan](quartz-workshop-signs.json), [native verification](quartz-workshop-native.json). Canonical SHA-256: `dd6c8589d0be37bc892eb23c2b073d4e8bdfb87921447b1a133f742cc25e451f`.

## What was actually tested

`python3 tools/test_workshop.py /path/to/luau-tools` compiles every source and both production bundles, analyzes the pure changed logic, runs nine workshop groups (including 150 seeded three-draft sequences), six mining checks, 28 persistence checks, two full production-server loop configurations using Roblox API doubles, and actual mining-worker effect fixtures. The tests exercise saved delivery, reconnects, exactly-once spending/rewards, caps, schema migration, twelve prestige rewards, and preservation of the native file. [Captured passing output](quartz-workshop-tests.txt).

| Production worker test | Measured outcome |
| --- | --- |
| Baseline arrival-to-break | 8.867 seconds |
| Power Cell L1 / L2, same rock | 6.983 / 6.050 seconds |
| Quick Ignition L1 / L2, same rock | 7.267 / 6.733 seconds |
| Prism common / legendary, 30 primary damage | 3 / 12 secondary damage |
| Polisher common / legendary, two ten-ore rocks | 25 / 40 total ore |
| Route Runner | Mines a second ready rock without another command |

The full server fixture earns its pack, repeat level and 360-Quartz prestige through worker damage and pickups, without currency grants, in 350.74 seconds of simulated worker ticks. Station travel is supplied by the double: this is not measured player session length. A separate pacing model with 14-second sale trips estimates first-level throughput gains of 16.0% power, 11.3% ignition, 8.0% capacity and 18.4% yield. Route Runner's speed-only gain is 4.8%; its automatic-retargeting benefit is separately behavior-tested. The model excludes Prism's neighboring damage, human choice time and multiplayer contention.

Consumable/deployment tests, beam-VFX checks and all 18 single-game preservation/release tests pass. A final `tools/build.py` run reports no native changes needed. Broader existing checks are not all green: gadgets fail a contact-render assertion; energy effects fail an effect assertion; smooth animation fails a missing `droneConfig` fixture value; committed mining fails a missing `hp` fixture value. Each reproduces on an extracted, unchanged `9bed0b8` source/test baseline. Adding the Workshop module exposed a test-only Luau local-register limit; wrapping the appended mining fixture in a function fixes that compilation issue, after which it reaches the same baseline `hp` failure. Historical feel/radius and outbound-drop assertions also disagree with unchanged baseline behavior. These failures are recorded rather than treating the entire CI suite as passing or reverting accepted mining/VFX behavior.

## Native evidence and limits

Studio was already open. One short Play in the correct shared place verified one drone, zero Quartz, capacity 40 and the 360-Quartz goal. Reported memory reached **4322.6 MB**, so Play was stopped immediately under the owner's prior instruction to stop the activity around 4 GB. No further Play/device loop was run. The combined workshop UI, complete engine loop, touch/controller interaction, native multiplayer and subjective enjoyment remain unverified. TextService width checks are layout measurements, not visual acceptance. The brief console read showed two pre-existing asset-representation warnings; it was not a long-run error check.

The actual Edit screenshot shows the workshop signage on the preserved wooden stalls and retained textured reserve. Final direct verification: **DRONEREVOLUTION, place 124078027733625, universe 10774898335, loaded version 83, Play stopped**, all three roots `SyncedAsRoot`, all seven Source hashes match the canonical file, all 26 authored properties match the plan. Studio remains open in Edit. The next Play from this shared Edit document runs the new scripts; the public game has not been updated or independently checked. Loaded version 83 is not a publication receipt.

## Next human playtest, when memory testing is authorized

Observe whether the first pack arrives before mining feels repetitive, whether its three choices are understandable, and whether the first repeat purchase visibly changes the next few rocks. Compare a second blueprint with investing in the first, then verify that the first prestige's extra worker feels worth giving up the build. Check whether capacity/yield dominate power/ignition, whether automatic routing reduces busywork without removing useful drone decisions, and whether later prestige thresholds become excessive. Tune from those observations; passing worker tests alone does not answer those questions.
