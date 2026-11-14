# Drone Blower revolution — backpack and moving swarm

October 31, 2026. Target: existing place **136098934779395**, branch `codex/restore-feel-prestige`. The owner will perform playtesting. No tests or new Studio play sessions were started for this pass.

## Resulting behavior

- The original plot models move at runtime to Quartz (−56,129), Ruby (−176,129), Cobalt (64,149), Violet (−296,129), Emerald (184,169), X/Z studs. Distances from spawn to plot centers are 140, 184.39, 200, 277.85, 300 studs; from converter they are 112, 164.15, 178.39, 264.85, 284.08. Nearest plot edges are strictly ordered too. Existing lanes/assets remain; a paved approach closes the moved Emerald gap.
- Native Concrete hub, Pavement lanes, DiamondPlate machine pads/converter, Metal machines, studded Plastic baseplate/spawn/borders, and Sandstone/Ground/Slate/Rock/Grass field beds. Reflectance is zero on map parts; the map uses low environment specular, combined with the coordinated neutral daylight preset.
- One player backpack, starting at 40 units; capacity cards enlarge that backpack. Miners never own holds. Complete final-node rewards are preserved even if they pass capacity; further damage waits for space. Bring the backpack to within 18 studs of the converter and press Sell/U.
- Working miners follow the player away from the plot rather than mining remotely into a backpack beside the converter. The field work radius is 70 studs. Orders/reservations resume when the player returns; warmup starts again. Idle/full workers regroup around the player.
- Courier: simple box/two lift drums. Collect at most eight units within four studs of the owner, physically fly to the converter, sell through durable receipt-based transactions only after arrival within ten studs, return, wait two seconds before another pickup. No ore is created/lost during pickup, sale or preview reroll. A parcel is temporary delivery escrow, not a mining hold. Delivery slots remain within six studs of the station regardless of fleet size.
- Medic: tiny mechanical disc, slow following, 10 HP repair every two seconds, within 12 studs and server line of sight. It follows damaged living allies and never mines or attacks. All observers render a beam attached to the two current rendered emitters; client occlusion queries are capped/fair and stale contacts expire.
- Existing permanent IDs, types and base traits are unchanged. A saved role distinguishes function: starter Blue/Striker miner, Red/Charger breaker, Green/Medic healer; alternating later Blues (serials 4,10,...) are Couriers. Prestige/death/reconnect retain those roles. Original mining shells, emitter and segmented pyramid assets stay in use. Support geometry exists only in disposable runtime clones.
- Preview Random loadout/T gives 2–5 random drones, always including a miner. It uses separate test IDs and never replaces permanent ownership. Old preview parcel escrow returns to the backpack before reroll.
- Centered hex formations give uniform nearby spacing. An immutable six-stud spatial grid reads a bounded neighborhood per drone. Soft separation, tangential passing and small vertical lanes depend on actual nearby positions, including other players' drones. The force changes authoritative goals through the original capped easing; it fades near job arrival to preserve the one-stud mining gate. Client follow prediction shares the helper, while job goals use server offsets once. Visual banking is capped at three degrees and levels for mining.
- Cards use native SourceSans fonts and at most two visible text elements: effect, then target/duration/necessary penalty. Thin camera-local Parts carry SurfaceGui faces; each face contains a small WorldModel/ViewportFrame mechanic visual. This inversion is required because Roblox ViewportFrames do not render nested GUI objects. Transparent ordinary GUI hitboxes retain touch/controller selection; scrolling crops faces, and destruction/closing cleans up camera objects and bindings. New courier upgrades increase courier speed; no card restores miner holds.

## Profile compatibility

Schema 4 preserves permanent ownership/base data. It validates and transfers all old per-drone holds and unsold old full-load delivery manifests into the backpack, without awarding sale credits. Existing schema-4 courier escrow remains durable and bounded at eight units. Unknown/corrupt data fails closed; there is no default-profile overwrite.

The obsolete selected Auto Hauler card is retained as an explicit Backpack Retrofit: +35% backpack capacity and +30% drone speed for the run. Its old payload is retained as metadata. An unchosen paid offer containing obsolete Auto Hauler is refunded at its exact saved full pack price, with no reroll. Other paid offer choices retain their saved payloads and targets.

## Review and verification limits

Two independent source reviews covered behavior/parity, then pacing/presentation/multiplayer. Their findings fixed legacy oversized delivery escrow, unbounded delivery positions, converter-camping remote mining, idle workers failing to regroup, obsolete paid-card no-ops, and healer beam cursor starvation between synchronized pulses.

Static Luau compilation of changed sources and complete generated controllers succeeded. The reproducible builder checks the immutable live capture checksum and permits only the seven exact live Source paths; all other chunks and backup scripts remain byte-identical. These checks are not gameplay tests. Historical tests expecting individual holds/old cards are obsolete and were not run.

Exact engine appearance, projection/font layout, movement feel, low/high graphics, mobile interaction, real DataStore operation and two-player/late-join behavior remain **NOT VERIFIED**. Automated correctness or code review does not establish fun. No Roblox publishing or main merge is authorized.

## Build and edit-time integration

Run `python3 tools/release.py` from a clean committed checkout. `build/revision.json` records exact source commit and place SHA-256; `build/Drone Blower revolution.rbxl` is built only from immutable `assets/drone-blower-revolution-base.rbxl`. The earlier Mining Away asset is historical reference.

Before editing the connected Studio instance, the seven live script Sources were preserved in `build/studio-before-backpack-20261031.json`. Integration stages the same generated payload, verifies place ID/class and each pre-edit source checksum before mutation, changes Source only, and verifies the resulting source checksums. It does not start Play or publish. Runtime map/material changes appear on the owner's next run; edit-time geometry remains preserved.
