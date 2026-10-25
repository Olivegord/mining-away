# Mining Away cloud prototype

Open **mining-away-cloud.rbxl** in Roblox Studio, then Play. This is a new, downloadable copy of the verified December 18, 2023 autosave. It does not contain the unavailable 2026 live Studio source. Nothing was published or changed in the live Roblox place.

## Play the build

You start at an elevated home platform with three drones. Walk over the bridge to Ruby Meadow and click its floor/crystals, or press **1** while nearby. Drones travel, reserve crystals, mine, and collect ore. Geodes allow three drones on the shell; breaking the shell exposes one valuable core and four smaller crystals. Walk home, press **R** to recall, then **E** or the Sell button to exchange ore for credits at 1:1. Buy Power and Hull at home. Walk to Cobalt or Amber, then click the patch or press **2** or **3**. Other players have four seconds to join the muster before the fleet roster locks.

| Patch | Crystals | Ore per crystal | Defenses | Suggested Power / Hull |
|---|---:|---:|---|---|
| Ruby Meadow | 16 + geode | 20 | Safe | 0 / 0 |
| Cobalt Shelf | 9 + geode | 65 | 2 × 100 HP sentries | 1 / 1 |
| Amber Bastion | 10 + geode | 160 | 3 × 230 HP sentries | 3 / 3 |

Each upgrade costs 120, 320, 800, then 1800 credits. Power and Hull have separate levels. Every level adds 80% of the starting damage or hull. Base fleet: three drones, 8 DPS and 70 HP each. Shell HP is four ordinary crystals; its core pays four crystals and its four small crystals each pay one. Ore capacity is 2000, shared by the player's fleet; full fleets return home. Shell breaks pay no direct reward, preventing a shell plus core double payment.

## Implemented systems

- Original drone and crystal templates are reused when present. The original scene, meshes, materials, animations, UI and script source assets remain in the place. New platforms sit above the old prototype and are built when the server starts.
- Server-owned anchored drone models travel and aim at 10 Hz with continuous replicated beams: bright core, soft glow, visible impacts, bounded client sparks/debris, hover, shell fracture marks and final shatter. Every observer interpolates replicated server poses cosmetically while keeping beam targets in world space. There are no added point lights and no per-frame RemoteEvent broadcasts. Original ambience reference `1835928951` is reused quietly; a packaged Roblox ping is requested for breaks. Audio permissions/playback need Studio verification.
- Ordinary crystals have one mining reservation; geodes have three. Damage, shell transitions, reservations, rewards and exposed crystals are server-owned and processed without yielding. Shell/crystal destruction cannot reward two concurrent hits.
- Turrets choose eligible drones, check range and line of sight, charge a visible thin targeting beam for 0.8 seconds, then shoot on a cooldown. Both sides' damage is server-owned. Health readouts, phase indicators and printer countdowns replicate.
- Drones move through Follow, Travel, Attack, Mine, Return, Destroyed and Reprinting. Death cancels mining/combat/reservations immediately. Ten seconds of recovery plus two seconds of visible printer assembly precede replacement at home. The same owned slot and upgrades return for free; player ore and credits stay intact.
- A single rate-limited input remote accepts only Patch, Recall, Sell and Upgrade. Player identity is the invoking Player. The client cannot submit drone IDs, damage, rewards, cargo amounts, turret health, sale recipients or upgrades for another player. Patch IDs must be finite integers, orders require the player within 58 studs of the patch, and upgrades/sales require the player at home. Dead characters cannot issue actions.
- All gameplay instances, beam endpoints, health, states, ownership and timers are replicated Workspace models/attributes. Joining clients read current instances; cosmetic listeners attach to existing and newly replicated content. The HUD never initializes the simulation or moves authoritative models.

## Assault contract

1. A guarded patch opens a four-second muster only after a valid fleet requests entry. Each user enrolls once with their currently living drone identities and life numbers. No one can join an active assault.
2. Each roster slot is one life. Death, recall, character death, changing patch, leaving the 65-stud encounter radius, or disconnect spends that slot. Returning/reprinting/reconnecting cannot restore it, even while a friend keeps fighting. Replacements start at home and receive a new life number.
3. A wipe, eight seconds without eligible contact, or a hard 90-second assault limit triggers a reset. All defenses immediately restore, including previously destroyed turrets; resources and reservations reset. Mining and new assaults remain locked for a six-second reset cooldown. Old telegraphs/shot locks are cleared. No turret kill pays credits independently.
4. A living locked fleet defeating every turret earns one encounter bonus (two crystal rewards) for each enrolled connected player. The patch opens globally for **120 seconds**, including cooperative mining and new arrivals. Exhausted resources regrow after 12 seconds within that window. When it expires, all defenses and resources reset and fleets are recalled before the next guarded encounter. Ruby is always safe.
5. Range, cooldown, roster life and encounter phase checks are server rules. A new life can participate in a later reset encounter, with every turret at full health. A disconnect into a different server also faces that server's complete defenses; it does not transfer chip damage.

## Source and reversible migration

`src/Config.lua`, `Rules.lua`, and `World.lua` are small source modules; `Server.lua` and `Client.lua` contain the runtime adapters. The deterministic builder bundles the three modules lexically into the existing `ServerScriptService.GlobalDroneControl` entrypoint and replaces `StarterPlayerScripts.ClientDroneControl`. Native ModuleScripts were not injected into the binary hierarchy. Edit the readable files, then rebuild.

Only four binary property chunks change: Script/LocalScript `Source` and `Disabled`. Every other chunk, including all instance declarations, parenting, asset references and geometry, stays byte-identical. The other historical Script/LocalScript controllers (including the loader, client drone movers, camera scripts and readme/sinewave scripts) are disabled. The two unrelated original ModuleScripts remain inert and are never required. At runtime only the three named historical ScreenGuis are hidden locally, including on character respawn. Third-party plugin/loader source was never executed in the cloud.

The complete original is included as **mining-away-original-autosave.rbxl**, alongside the extracted original scripts and prior design document. Rollback: close the build without saving over your original and open that included autosave. Generated runtime objects disappear on Stop. The builder refuses an input with a different checksum and refuses an identical input/output path. If an output already exists, it saves that output as `.rbxl.previous` before rebuilding. Do not run this hash-locked patcher against the live 2026 place.

```sh
python3 tools/build.py mining-away-original-autosave.rbxl --output mining-away-cloud.rbxl
```

Original bytes: 220660. Original SHA256: `480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b`. The attached JSON was verified at 373893 bytes, SHA256 `3e9526a0005107e1af251d1357a0ca5389dd26aa760d1db1607b5abffb27fd2a`. See `SOURCE.md` for the persistent source reference.

## Historical versus live integration differences

The observed live tuning was Ruby 16, Cobalt 3, random 2–5 starting drones, capacity 2000, 20 ore per crystal and a 1:1 converter. The historical source used capacity 200 and different patch tuning. This build uses a deterministic three-drone fleet, capacity 2000 and the same 1:1 sale ratio; Ruby stays at 16 crystals and 20 ore, while guarded Cobalt intentionally expands to nine crystals at 65 ore, and Amber is new. Drone randomization is removed to make progression reproducible. A minimal home shop funds fleet power/hull. The old camera/loader/UI are isolated in favor of standard character controls and a compact HUD. Existing islands and original content are retained below the elevated test route.

**Prototype persistence:** inventory and upgrades survive drone destruction, character respawn and reconnect to the same running server via a numeric profile cache. There is no DataStore or cross-server/restart save system in this build. No real currency, public publishing, external loader or live save migration is involved. This matches the historical session prototype rather than pretending to migrate unavailable production player data.

## Validation status

Cloud checks use official Luau CLI 0.744. All five source files and the assembled server compile. Config and Rules pass standalone analyzer checks. The complete bundled server/client pass standalone lint with Roblox host bindings explicitly typed as `any`; this catches misspelled globals and normal lint errors but is not Roblox API type validation.

**47 automated checks:** 20 pure Luau rule tests, 23 integration tests executing the actual bundled server against deterministic Roblox API doubles, and 4 Python binary build/preservation tests. Integration tests exercise commands, real reservation/reward code, reprints, encounters, repeated weak attacks, co-op roster restrictions, disconnect, line of sight and fixed-step bounds. These doubles do not simulate Roblox rendering, networking, physics, asset permissions or engine serialization loading.

In the unobstructed API-double scenario, Amber at level 0 wipes after about 8.6 seconds; three repeat weak attempts wipe with all defenses fully restored. Cobalt at level 1 clears after about 9.4 seconds and Amber at level 3 clears after about 13.7 seconds (both include muster). Actual Studio timings can differ with geometry/line of sight. See `test-results.txt` and `STUDIO-CHECKLIST.md`.

```sh
# Get the official luau, luau-compile and luau-analyze executables, then:
python3 tools/test.py /path/to/luau-binary-directory
python3 tests/binary.spec.py
```

**Roblox Studio was not available in the cloud.** The edited binary has been structurally parsed and compared, but has not been opened by the Roblox engine. A real two-client/late-join session, original mesh pivots/scale, visual/audio polish, character traversal and respawn must be checked in Studio before treating this as release-ready.
