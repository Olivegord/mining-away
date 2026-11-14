# Distinct drone jobs — November 1, 2026

The owner reports that the healer's movement is good but the other drones look like copies of the same miner. This pass assigns mechanical work by explicit capability. Merely having positive saved mining base traits or a different color must never grant a drone the ordinary mining behavior.

| Role | Actual job | Ordinary mining beam? |
|---|---|---|
| Striker | Miner: approaches one rock and cuts continuously from directly overhead. | Yes |
| Courier | Backpack emptier: reserves its own parcel, flies to sell, returns. Two can cooperate without duplicating ore. | No |
| Medic | Healer: preserves the existing slow follow and attached repair behavior. | No |
| Dart | Scout: scans and marks ready rocks so the miner's next laser warmup is shorter. Does no direct mining damage. | No |
| Charger | Breaker: approaches, visibly winds up, dives, impacts once, then recovers. Prefers geode shells and cores. | No |
| Orbiter | Orbital controller: automatically charges and fires the existing largest-rock strike, then cools down. Manual timing input can still intervene. | No |
| Scrapper | Swarm fabricator: automatically deploys temporary mini miners, then waits to rebuild them. | No |

The requested Studio test crew is one Striker, two Couriers, one Medic, one Dart, one Charger, one Orbiter and one Scrapper: eight drones total. Every Studio player starts with it on their next Play. Fleet → Role crew restores it; Random 2–5 remains available. The preview miner retains the first permanent miner's ID/base so named cards still affect the real active miner. The other seven units are temporary test IDs. Permanent ownership still contains exactly one drone for a new profile.

Click an ore to choose the working field. The miner takes ordinary queued rock orders; the breaker independently selects heavy ready rocks after this first field choice. The scout marks other rocks, the orbital drone moves above its largest target and charges, and the fabricator stays near the player to release its swarm. Recall clears this shared work order, active charges and bots without resetting cooldowns. The ordinary miner still earns plot-wide targeting through Plot Scanner. The eight-role preview grants hardware, not run-card modifiers or shop access.

## Shared rules

`DroneRoles.lua` is a pure shared capability boundary. `isMiner` permits only Striker; `isWorker` and `combat` permit Striker/Charger. All support/specialist roles fail those checks. Legacy Blue/Red/Green role names map to Striker/Charger/Medic so the change does not require rerolling ownership. Unknown roles fail closed.

The scout selects a substantial, unmarked, ready eligible resource using stable target IDs. Its eight-second authoritative mark multiplies miner warmup by 0.35, subject to the ordinary minimum warmup. It cannot grant ore, reserve a mining slot or remove rock health. Its feedback uses small nested spheres over the selected target and a short scan pulse, with no laser or text label.

The breaker's pure phase state is `Approach → Windup → Dive → Impact → Recover → Complete`. Arrival is required before windup. Windup defaults to 0.8 seconds and uses the drone's upgraded/scout-assisted startup when supplied, with a 0.08-second minimum shared by timing and pose. A dive must actually reach its impact station before the server emits exactly one impact event. A dive that fails to arrive within 1.25 seconds recovers without damage. The impact holds for 0.12 seconds, then recovery lasts 0.65 seconds. Target loss, changed target or invalid work context cancels the cycle. `breakerPose` supplies bounded anticipation/dive/recovery factors; rendering never decides whether a hit happened.

The existing original drone shells remain. Scout rails, breaker drums, orbital focusing mast and scrap bays distinguish working hardware. Medic geometry and motion are intentionally preserved. Role-specific effects are replicated Parts with cleanup and the existing 256-primitive budget. The breaker has target anticipation, a short impact flash and three small slate chips, rather than another steady laser.

Two couriers collect from opposite sides of the backpack, each reserving at most eight real ore into its own manifest. Sales require arrival at the converter and are receipt protected. Orbital and swarm hardware use the same saved server cooldowns as manual gadgets (45 seconds orbital, 35 seconds swarm; orbital shop upgrade reduces it to 30). Automatic release follows a 1.4-second charge, letting the player tap the existing green timing window first for the precision benefit. Scrap lasts ten working seconds with four bots, or six on precision. Storage waits pause charge/swarm clocks and specialist phase clocks. Additional same-kind hardware currently shares the global gadget cooldown; long-run duplicate-role pacing remains a limitation.

Nonworkers publish zero effective mining/combat output and are excluded from rock queues and combat enrollment. The healer may accompany combat to repair. Breakers cannot receive mining-fork-only Individual upgrades, because impacts do not use the continuous laser fork path. Existing permanent base values and previously selected cards remain intact.

## Focused checks

```sh
python3 tools/test_gadgets.py /private/tmp/mining-away-luau
```

The runner now includes 18 direct production-role checks. They cover exclusive miner/worker/combat capability, support job identity, legacy aliases, unknown-role rejection, scout target/expiry rules, breaker target preference, eligibility, deterministic ties, arrival-gated windup, single-impact serialization, consequential startup upgrades, missed dives, cancellation, malformed clocks and bounded poses. It also compiles the updated role configuration/effect modules.

The ten new actual-server checks exercise the eight-role starter without changing permanent ownership, job-assignment exclusion, no-damage scout scans, real miner startup, physically reached single impacts/recovery through snapshots, storage pauses/recall, two conserved courier parcels and exactly-once sales, automatic orbital damage/saved cooldown, real ten-second scrap mining, and unchanged healer repairs. Together with the existing focused suites, 131 checks pass. [Recorded output](DRONE_ROLES_TEST_RESULTS.txt).

The existing place **136098934779395** was in Edit mode. Seven prior live Sources were guarded and backed up locally, four changed allowlisted Sources were applied, and every resulting Source was read back exactly. Quartz/spawn stayed at their established editable positions. [Integration record](DRONE_ROLES_STUDIO.json). The native local `build/Drone Blower revolution - editable workspace.rbxl` was refreshed through Download a Copy.

API doubles do not establish native asset appearance, engine collision/LOS, real networking, final-device readability or fun. No new Studio Play session or Roblox publishing was performed. The exact integrated candidate still requires the owner's engine playtest; the previously observed healer is not evidence for the new role branches.
