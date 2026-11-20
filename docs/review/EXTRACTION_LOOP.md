# Extraction loop

The owner tried the controls/cubic-rock/physics/audio pass and still found the game unfun. They explicitly ruled out insufficient control over mining and cited Bee Swarm as an enjoyable example without requesting a copy. This candidate targets the connection between visible mining work and useful consequences.

## Observation and hypothesis

In the previous native session, the preview crew broke four rocks during a 15.93-second observation but collected zero further ore: the backpack and orbital storage each held 120 units, couriers were waiting, and all spendable mineral balances were zero despite 264 collected ore. The mandatory first manual storage launch had stalled the delivery loop. Separately, accepted rock-layer losses produced cosmetic material but no collectible ore until complete destruction.

The working hypothesis is that actual extraction should deliver small, useful results during the work and a distinct larger result at collapse. That is not a conclusion about the cause of the owner's dissatisfaction. More feedback or shorter waits alone may still leave the loop uninteresting.

## Behavior

- Real layer fractures release cumulative base ore up to half the node's original total. An ordinary 10-ore, three-stage rock releases 1, then 2, then 2 ore, with 5 retained for collapse. A hit crossing several stages releases the accumulated difference once. One-hit breaks retain the full payout.
- One server-owned extraction ledger belongs to the rock, so changing workers, replaying impacts, shared work and secondary damage cannot repay the same layers. Geode shells still pay nothing; revealed cores and shards retain their existing totals. Consumable discoveries still occur only at eligible final breaks.
- Card/discovery yield and fractional remainders use the existing award path. The final specialist bonus still applies to the original whole-rock ore amount. With one unchanged worker/multiplier, extraction plus collapse conserves the old total. When different workers finish a shared rock, each worker's modifiers apply to its awarded base share; the finisher owns its existing completion bonus.
- Extracted fragments emerge above the remaining rock and use the existing weighted scatter, floor contact, finite lifetime, owner-only attraction and confirmed collection. At most four uncollected fragments remain per owner/node; excess units coalesce without refreshing expiry. Deployed carrier workers send extracted ore through the existing typed storage/overflow path.
- New profiles start with automatic full-storage launching, including their first shipment. The capsule still takes six seconds and pays its saved, typed manifest once on arrival. Existing saved `autoLaunch=false` preferences remain manual, and players can choose either setting at the depot without a first-shipment unlock. No schema, capacity, price or permanent fleet changes.

## Verification

Production code with API doubles passes layer-before-death collection, repeated contacts, stage skipping, fractional yield, bounded full-bag fragments, specialist completion bonuses, geode/rejected-hit exclusion, existing pickup expiration/ownership, typed overflow, first-shipment auto-launch, refill during flight, manual selection, save uncertainty and reconnect checks. All seven specialist chunk cycles, original command behavior and consumable reservations remain covered. These are logic tests, not engine, audio, multiplayer or enjoyment evidence.

Reproduce:

```sh
python3 tools/test_physical_mining.py
python3 tools/test_special_logistics.py /private/tmp/mining-away-luau
python3 tools/test_core_gameplay.py
python3 tools/test_consumables.py
python3 tests/single-game.spec.py
```

On November 6 the existing canonical document was stopped, saved, closed, refreshed and reopened. All seven reopened Sources matched the expected byte counts and rolling checksums; offline validation independently matched their full Sources and preserved every non-Source chunk and unrelated script from the native save. The installed native SHA-256 is `901d906b4e2c4168cf0d42993c8beaadd85e85d6f0a1aa7ad5ea9dfd572d9997`.

An actual Studio Play session used the existing 12-role preview crew in Quartz. Character navigation and the normal client `Patch` command started field work; no ore, wallet balances or launch history were injected. During one 20.93-second observation, seven distinct rocks had positive extracted ore while still alive, five rocks collapsed, collection rose from 106 to 117, and the peak live pickup count was 19. A later observation found one completed automatic launch and 120 credited Quartz, with collection continuing from 278 to 294 while storage refilled. Console output was empty. This verifies live extraction/delivery in that preview scenario, not a one-drone new-player playtest, multiplayer, audio quality or enjoyment. The preserved native document remains running for owner evaluation.

The behavior/parity review checked shared payout ownership, specialist final bonuses, geode exclusion, original travel/charge timing, save boundaries and manual-setting preservation. The pacing/presentation/multiplayer code review checked a retained final payoff, finite pickups, bounded fragment counts, authoritative replicated state and owner-only collection. These reviews are not multiplayer playtests.

The exact integrated revision and canonical checksum are recorded in `build/revision.json`; only `build/DRONE_GAME.rbxl` is installed or packaged. The remaining human test is whether intermediate extraction and uninterrupted delivery make another minute of mining worth playing. Busy-field readability, sound balance, two-player/late-join behavior and player enjoyment remain unverified.
