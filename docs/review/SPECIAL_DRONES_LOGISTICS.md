# Special miners and orbital logistics

This candidate extends the existing Drone Blower revolution, place **136098934779395**, from source `8c4a15f35729115ecacbb4881902e8aab1ef5a52`. The cloud checkout initially contained the older bootstrap; that implementation was checkpointed locally and the feature was integrated again on the current game. The active build uses `assets/drone-blower-revolution-base.rbxl`, preserves the current map and all seven approved live script paths, and retains the existing cards, mineral shops, roles, discoveries, collectible ore, flight and audio. It does not publish Roblox or merge the earlier review branch.

## Permanent miners

Buy miners in **Drones [O]** at the depot using Quartz. Prices and work/yield tuning come from `src/DroneCatalog.lua`.

| Miner | Quartz | Work after startup | Ore recovered | Action |
| --- | ---: | ---: | ---: | --- |
| Frostbite | 650 | 5.5 s | 1× | Ice enclosure and sonic shatter. |
| Halver | 900 | 8.0 s | 3× | Levitate, stretch, recursively split, then ring-grind into dust. |
| Gridcutter | 1,400 | 5.0 s | 2× | Laser-grid scan followed by a nudged cube spill. |
| Bubbler | 1,800 | 4.2 s | 2× | Roblox Glass bubbles absorb the rock, float up, fall, and shatter into gold. |
| Resonator | 2,100 | 4.8 s | 3× | Three pulsing rings fracture the rock. |
| Starforge | 2,600 | 5.0 s | 4× | A miniature sun melts the rock into molten rain. |
| Singularity | 6,500 | 2.4 s | 3× | A tiny black hole absorbs the entire rock. |

Each completed specialist cycle destroys one ordinary rock or exposed geode fragment regardless of its remaining health. Shared geode shells retain ordinary three-slot mining so concurrent workers cannot overwrite a single special effect. Mining cards affect startup, work speed and yield. Recall, death, lost targets or obstruction cancel unfinished work; a teammate finishing the target early receives ordinary rewards and cancels the unfinished effect. Saving freezes special time instead of completing work during network waits. All damage and rewards remain server-owned.

Purchased identities, roles and base traits persist alongside earned prestige drones. Purchases do not shift the existing earned-role sequence. Schema 7 migrates existing profiles without changing their fleet, wallets, cards or paid offers. The existing persistence manager, data store and ordered transactions remain in use; this update does not introduce a separate profile store. Studio previews can temporarily spawn each specialist without granting ownership. Purchased specialists remain visible after preview preset changes and reconnects.

## Carriers, backpack and storage

- **Carrier: 1,500 Quartz.** Buy at the depot and assign up to four distinct owned mining workers. Three carriers may be owned. Support and gadget-only roles cannot occupy mining bays. Select a carrier in the toolbar, then click an unlocked safe or cleared field. It physically carries its miners there and deploys them to choose rocks without needing Plot Scanner. Walking away leaves them working; their ore goes directly to personal storage. Repeating the same dispatch keeps current work. Recall returns the carrier. A destroyed or replaced life stays home until its carrier returns, retaining ownership without teleporting reinforcements.
- **Flying backpack: 750 Quartz.** It flies to a full player backpack, collects only on arrival, flies to personal storage, and retains any ore that cannot fit. Existing Couriers now deliver their small parcels to storage too. They pause new pickups when storage is full.
- **Orbital storage: free personal building, 120 ore.** The actual starting backpack helper holds 40 ore, so the first capsule holds three initial bags. Deposit at personal storage or the existing Converter/depot. A full capsule snapshots exactly 120 typed ore, launches for six active seconds and pays each mineral into its matching shop balance once. The next capsule can fill during flight. Pending carrier and parcel overflow is saved and drains when space opens.
- **Useful extras.** After the first manual shipment, opt into automatic launches at the depot. Waiting workers resume existing orders when capacity returns. A physical full-storage beacon and the drawer's storage meter indicate readiness. Whole-field carrier targeting and touch-friendly target/return controls supplement the existing command UI.

Controls: **O** opens the drone yard, **C** cycles Fleet/carriers, **R** recalls the selected carrier or the fleet, **U** deposits, and **L** launches. Mouse and touch can select a carrier and target a field. Existing pack, shop, prestige, gadget and combat controls remain.

Carrier/backpack ownership, loadouts, auto-launch preference and first-launch unlock survive prestige. Mineral balances, all cargo including in-flight manifests, shop upgrades, cards and run earnings reset; the confirmation explicitly says so. Carrier missions run while the player remains connected, including when leaving the patch or respawning. This is not offline mining after disconnect.

Personal pads sample nine points from the game's terrain plan and use level foundations where terrain rises. This prevents the seventh and later multiplayer yards from being buried. Capsules have a clear path above their gantries. Cosmetic source poses publish at 10 Hz and render locally; special mining has a shared 360-part budget and cleanup on cancellation, stream-out and retirement.

## Validation and remaining engine review

The current feature runner passes **53 checks**: 10 profile/logistics domain checks, 16 actual bundled-server integration checks, 2 preview ownership/reconnect checks and 25 effect lifecycle checks. It compiles every source and both real bundles. These are deterministic API doubles, not a Roblox renderer or live DataStore test.

The seven retained focused runners also pass: `test_refinement_client.py`, `test_energy_effects.py`, `test_audio.py`, `test_gadgets.py`, `test_mining_flight.py`, `test_shops.py`, and `test_pickup_motion.py`. Fixture updates are limited to schema 7, the intentional storage economy, and the added menu dependencies. The broad historical `tools/test.py` suite contains other obsolete expectations and is not claimed entirely green.

`python3 tests/live-build.spec.py` passes deterministic active-capture builds, exact seven Source allowlists, and byte-identical preservation of every other chunk and backup Source. Research and decision evidence are in [DRONES_AND_LOGISTICS_RESEARCH.md](../DRONES_AND_LOGISTICS_RESEARCH.md). The release's `build/revision.json` records its exact source commit and place checksum.

No new native Studio session was available in this cloud environment. Visual choreography, real multiplayer/streaming, mobile glass readability, actual DataStore restart behavior, sound balance and gameplay pacing still require inspection in Studio. Existing screenshots and earlier native validation do not validate this feature. The work was not published to Roblox or installed into an already-running Play session.
