# First field: Mining Away's ruby patch

The first field in **DRONEREVOLUTION** now has the **30 × 2 × 30** dimensions and 80% transparency of the ruby patch in the owner's open **mining away** (place 14302916915, universe 4945273529). The tinted top sits 0.06 studs above the original checker baseplate so it stays walkable and clickable. The previous slabs, bridge, curbs and field billboard are preserved under `ServerStorage.PreMiningAwayLook`. The baseplate provides the ground immediately outside the patch. The other five fields and their fixtures were not edited.

At runtime, the first field uses the original-size crystal mesh with the reference's red Ice finish and 20% transparency. Twelve upright crystals fit in the smaller patch using sixteen sites with randomized selection and position offsets. Spacing still accounts for each crystal's horizontal footprint. Four miners can take separate targets and continue to the next group. Each crystal still pays Quartz, and packs, upgrades, specialist drones and prestige keep their current rules.

[Studio Edit preview with temporary crystal samples](starter-patch-edit.jpg) · [Native verification and source hashes](starter-patch-native.json)

The shared Edit verification tested 1,089 ground rays: 225 hit the patch and 864 hit only the checker baseplate. The preview was removed. Workshop, placement and rock-damage tests passed using actual Luau with API doubles. Both server configurations populated all twelve crystals in 24 seeded layouts, kept their reward as Quartz, and passed the four-drone field order, pack, upgrade and prestige checks. No new Play test or multiplayer test was run.

The already-open **DRONEREVOLUTION** Studio document (place 124078027733625, universe 10774898335, loaded version 90) was returned to Edit. All three Script Sync roots were verified and all seven Sources match the canonical `build/DRONE_GAME.rbxl`. No Roblox publication. The implementation revision is the latest commit touching that file.

To reproduce the scoped map change from `5d6dc9f5bb9af1c44de5982f61466b18f3e437fb`, run `python3 tools/refresh_starter_patch.py <export-dir>`, execute its generated `stage.lua` in shared Edit, and store the JSON result of `shared.StarterPatch.apply()` as `verified.json` in the same directory. Run the saver again with `--write`, then sync with `python3 tools/script_sync.py` and refresh the native Sources with `python3 tools/build.py --previous-commit 5d6dc9f`.
