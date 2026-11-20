# Collectible mining, inertia and gentler feedback

November 1, 2026. Same Drone Blower revolution place `136098934779395` and existing `codex/restore-feel-prestige` branch. The newest owner request supersedes the previous immediate-backpack award, instant velocity changes and faster rock pacing.

Broken ordinary rocks, cores and shards now scatter four small copies of the original crystal mesh (fewer for rewards below four units). Their integer ore totals are conserved. A short scatter leads into a 30-stud owner-only magnet that catches a walking player. Only a server-confirmed arrival adds ore to the backpack; there is no client pickup remote. Full backpacks leave fragments available until space opens. Save uncertainty pauses them. Line of sight gates attraction and collection. Owner/run checks prevent stealing or carrying a previous run's ground loot into a new run. Uncollected fragments are world state, not durable inventory: disconnect, server shutdown or prestige removes them. Collected backpack ore keeps the existing persistence boundaries.

At most sixteen uncollected rock rewards per owner remain active; miners regroup instead of silently damaging through that limit. Each reward has at most four fragments. Per-fragment line-of-sight checks and pose publication have bounded intervals, with a fresh collection check. Every observer interpolates the complete replicated fragment state; rendering cannot collect or credit ore.

All drones, including the tiny scrap bots, now accelerate and brake with finite thrust. Server/client workers share the same inertia helper; replication corrections request velocity rather than applying a positional jump. Speed upgrades, reversals and nearby jobs retain momentum. Healers keep their trailing goals and real repair behavior, with the newest all-drone acceleration requirement applied. After completing a rock, miners hold station for one second. Breakers finish their physical recovery and the remainder of that hold. Queued work waits; explicit orders can cancel the hold. Death/reprint is an explicit lifecycle reset.

Rocks keep the original union/mesh and random size/placement. Their base now rests on the real field-bed top. Matte Rock/Slate materials replace the smooth plastic appearance. Growth, all three tilted fracture stages, server geometry, breaker contacts and gadget target surfaces use the same grounded pose calculation. This fixes the earlier floating center and the follow-up bug where only client visuals moved downward. A read-only Edit-mode comparison against Roblox CFrame axes found maximum extent error `1.61e-7` studs; that is geometry math, not visual acceptance.

Every rock's effective mining work is three times its prior value; visual size, yield, field unlock cost and pack prices are unchanged. At an unmodified 30 DPS, ordinary Quartz now requires 4–9 seconds of active cutting, before warmup, travel and the one-second recovery. Harder fields preserve their 1 / 1.8 / 3.2 / 5.2 / 8 multipliers. Orbital strikes still erase a large eligible rock and breakers retain their shell advantage. These timings are arithmetic, not measured player-session progression. Later-field downtime and the value of specialists need owner playtesting.

Cutters retain the straight downward cylinder laser and original ramp/fade. Contact sparks now emit from an exact surface attachment with short outward velocity streaks and gravity. Origin particles are quieter visually. Scrap bots work close to the rock with solid tapping chisels and small confirmed-hit chips. Breakers use their real impact cycle. Orbital charge places red brackets/crosshairs on the field around its selected rock, followed by a descending red/white strike from overhead; it does not use an ordinary drone beam. All effects follow accepted authoritative events and expire. Nearby real breaks/impacts produce bounded, spatially attenuated camera impulses; reduced-motion attributes disable them. Camera bindings, impact listeners and pickup views are cleaned up with the HUD.

The bright money clip is replaced by a quiet soft confirmation. Crystal fractures/breaks use short, lower-pitched rubble rather than the sharp pop and three-layer stack. Close cutting adds quiet positional texture; orbital/breaker impacts have separate positional cues. The action mix has lower volume, reduced high frequencies, peak compression, short attack/fade envelopes, distance falloff and voice limits. Preserved audio assets remain available. No listening or hearing-comfort approval is claimed.

## Role upgrades

All are standalone run upgrades, gated by the server's actual matching hardware. The Studio preview crew may buy for its temporary hardware without changing permanent ownership. Other roles do not inherit these effects.

| Mineral shop | Hardware | Upgrade |
| --- | --- | --- |
| Quartz | Miner | +100% base startup rate; half baseline laser warmup alone |
| Ruby | Backpack emptier | 8 → 32 ore per real delivery parcel; larger parcels are visible |
| Ruby | Breaker | +80% shell/core damage |
| Cobalt | Scout | Marks last 8 → 16 seconds |
| Violet | Healer | 10 → 20 hull per repair pulse |
| Emerald | Swarm fabricator | Four → six bots per ten-second deployment; precision still caps at six |

Courier manifests now validate up to 32 units and retain exactly-once saved delivery/sale receipts. Old eight-unit manifests remain valid. Purchase, recharge, mineral access and prestige reset rules are unchanged. New upgrades do not reroll a saved fleet or modify an already-paid card offer.

## Review and verification

Behavior/parity review checked fleet identity, one-drone production creation, original meshes, overhead mining/arrival permission, original laser envelope, reservation cleanup, save pauses, late-join state, role isolation and receipt-protected courier deliveries. It found and repaired moving-player magnet starvation, missing cleanup for the camera/pickup listeners and outdated ability surface heights.

Pacing/visual/multiplayer code review checked threefold work without inflated geometry or rewards, one-second recovery without skipping queued work, different specialist actions, full-backpack fragment retention, foreign ownership, walls, bounded particles/audio/ground loot, same-kind gadget cooldown sharing and readable standalone shop terms. These are code reviews; they do not satisfy the independent native motion/art gate.

Reproduce:

```sh
python3 tools/test_shops.py /private/tmp/mining-away-luau
python3 tools/test_gadgets.py /private/tmp/mining-away-luau
python3 tools/release.py
```

The focused runners pass 25 shop/profile/card, 6 mining, 28 persistence, 9 actual-server shop, 21 gadget-domain, 18 role, 4 pickup-trajectory, 15 steering, 5 actual-client inertia, 7 actual-server gadget, 7 actual-server pickup and 14 actual-server role checks, plus actual contact-emitter lifecycle checks, compilation and deterministic binary preservation. The server/client integrations use Roblox API doubles. [Full results](MINING_EXPERIENCE_TEST_RESULTS.txt).

Four allowlisted live Sources were updated in the existing Edit-mode place. All seven were read back exactly; 39 other script Sources were preserved. Prior Sources are backed up locally. ScriptEditorService was used for the large controllers; a direct Source assignment first hit Studio's string-size limit without altering them. HTTP was restored to disabled. The native editable local copy was refreshed with Download a Copy. [Integration record](MINING_EXPERIENCE_STUDIO.json). The release checks that copy's exact live and backup Sources and stamps the committed revision/checksum in `build/revision.json`.

**NOT VERIFIED:** native motion/particles/material appearance, listening comfort, two-player and late-join behavior, busy-scene performance, device layouts, real DataStore recovery and fun. No new Play session, Roblox publishing or main merge. The review PR remains draft for the owner's playtest.

Implementation references: Roblox [particle emitters](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter), [sound compression](https://create.roblox.com/docs/reference/engine/classes/CompressorSoundEffect), and [editor source updates](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService).
