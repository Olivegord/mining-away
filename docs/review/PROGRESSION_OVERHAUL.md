# Progression overhaul — first pass, November 12, 2026

The recent native starter-loop report identifies stranded ore, an opening camera pointed away from mining, and crew hulls obstructing the avatar. This pass also addresses a slow opening prestige and a reward that can feel small after abandoning several run upgrades. It builds on integration revision `d85e5eb7aa1bd2672a80f4a312f97a0cd6798cfb`, preserving the current game rather than the older main-branch prototype.

## Changes and intended decisions

| Friction | Candidate behavior |
| --- | --- |
| Too much selling before permanent growth | First three sale goals: 160, 400, 1,000 Quartz. Spending never subtracts progress. Later historical goals stay intact, so no already eligible player is relocked. |
| Weak or unknowable permanent reward | Preview the three choices before eligibility; prefer roles the player does not own. First three prestiges add 50 percentage points of base mining power each, followed by 25 points per later prestige. Confirmation still grants exactly one drone. |
| Progress hidden until visiting the beacon | One readonly `Next drone` percentage/ready row in the existing mineral HUD. Physical station proximity still owns purchases and prestige. |
| Visible ore remains outside normal reach | Raw cargo homes from nine studs after its real landing, rather than five. Pickup bonuses still extend reach. No remote collection, instant credit or skipped arc. |
| Shopping erases work left behind | Extend dropped cargo through a real depot visit even with a partial bag. Keep the existing 180-second ceiling, owner/run binding and obstruction checks. Cache route checks once per player per second. |
| Initial view and hull obstruction hide mining | Face Crystal Run once after camera initialization. Fade only view hulls between the camera and avatar, and restore normal opacity during inspection. Keep all existing flight and attack effects. |

The new opening permanent multiplier is 1 / 1.5 / 2 / 2.5 / 2.75 across prestige counts 0–4. It is derived at runtime and never overwrites saved base traits. All run upgrades and Stars still reset. The current seven permanent starters plus two Emptiers, accepted pack/card presentation, Compactor, Needler/Ballcaster behaviors, nonlinear deep hardness and over-one-minute regrowth remain unchanged. Vacuum remains disabled under the prior direction; this pass does not silently activate it.

## Executed checks

Reproduce the targeted domain, controller and binary checks with official Luau 0.744:

```sh
python3 tools/test_progression_overhaul.py .tools/luau-0.744
python3 tools/test_pickups.py .tools/luau-0.744
python3 tests/single-game.spec.py
python3 tools/build.py
```

The targeted runner compiles every source and both bundles, analyzes changed domain modules, runs the workshop/mining/persistence groups, and executes the real server in production and isolated Studio-preview configurations. It checks a real crystal's dropped cargo landing and homing from eight studs without granting sale money; partial-bag depot grace; real worker mining, selling, paid crate opening and one-card selection; spending-independent prestige; one permanent grant and reconnect; early stable distinct rewards; modifier reset; and original 60-Hz travel. Fixtures supply API/storage behavior and scripted station positions. They are not Roblox networking, asset or visual tests.

The existing controller fixture's opening loop falls from 82.25 seconds of worker time at the baseline to 40.05 seconds with this milestone. That fixture uses three ordinary miners and supplies travel to stations. The actual Crystal Run starts with its curated nine actors. Do not label these figures real playtime, retention evidence or a measurement that the game is fun. The focused Crystal Run fixture separately confirms that its entire current starter roster is retained.

The pickup trajectory and production PickupView groups pass. All 18 single-game preservation/packaging checks pass. The canonical native refresh preserves all non-Source chunks and every unrelated or backup Source. `studio/` exports and the canonical seven Sources match disk.

Broader historical suites are not green: the baseline workshop runner exceeds Luau's 200-local register limit in its large Crystal Run fixture; the unchanged extracted client renderer fixture lacks `DroneConfig.Prominent`; the old Feel fixture expects the superseded geode slot height/radius; and the source typography guard rejects the existing cargo label before TacticalHUD's runtime styling. These are recorded limitations, not passing native checks. The new focused runner is additive and does not mask those CI checks.

## Review and remaining engine gate

Behavior/parity review: no base-trait mutation, no paid-offer regeneration, no change to authority, reset boundaries, attack sequences or original travel. Repeated prestige requests and reconnect preserve exactly one reward. Pure offer tests sample 120 deterministic seeds and test the all-roles-owned fallback.

Pacing/presentation/multiplayer review: new early goals reduce the wait for permanent growth, while late requirements stay at their existing values. Ore remains collectible only by its owner and current run after an unobstructed landed approach. Depot grace is bounded and does not reroll or duplicate drops. Hull fading creates no additional geometry or world raycasts. It does not move gameplay actors or change their damage gates.

Native engine motion, mobile text/layout, camera initialization, local fade quality, live DataStore and multiplayer are **NOT VERIFIED**. This executor has no Studio process or Roblox Studio tools. It did not start Play, touch an owner's session or open Version History. The exported sources and refreshed native file are prepared; shared Edit arrival, root status, exact seven-Source equality and a shared save must be verified on the connected workstation before owner testing. The last verified shared save remains 219 (`d85e5eb`). No Roblox publication occurred.

Canonical file: `build/DRONE_GAME.rbxl`. Native SHA-256: `f65fbb07db696e75e39ae85e16e3fd882342e497c85d85a9450beeeede1a296a`. Destination: **DRONEREVOLUTION**, place **124078027733625**, universe **10774898335**. Release metadata records the exact candidate Git commit.

For the next owner playtest, time the first paid pack and prestige, compare a familiar first pin immediately after resetting, and ask what each selected upgrade changed. Check whether collection still requires irritating repositioning, whether protected ore remains when returning from the counter, and whether the new drone is understandable in motion. Those observations should guide the next pass.
