# Owner requirements — October 25, 2026

These instructions supersede earlier concepts and the rejected first cloud build.

## Restore what made the original good

Restore near parity with original smooth eased/capped drone travel, hover and yaw. Drones mine directly ABOVE a crystal, with the original three visible fracture stages. Restore random crystal positions inside fields, health/size variation, and crystals growing into place over about two seconds. Preserve the original feel while correcting frame-rate dependence, cleanup, server authority, and replication. Server authority does not require jerky visual movement. Retain geodes but integrate them with the original mining presentation.

## Authoritative multiplayer and turret progression

All players see all drones, mining, combat, and regrowth, including late joiners. Enemy turrets actually fight drones and block mining in guarded fields until defeated. Reuse the original segmented pyramid model (`Workspace.construct`, segments `bottemseg`, `lowerseg`, `upperseg`, `topseg`, with `eye`/`eyecase`/`spawnEye`) as one turret type after verifying its actual geometry. Destroyed drones reprint for free at home without losing permanent drones or owned base traits. Weak fleets cannot brute-force stronger patches through indefinite reprint reinforcements or persistent chip damage.

## Card-run and prestige loop

1. New profile starts with ONE permanent drone.
2. Mine minerals and earn run currency. Mineral fields differ in value, respawn rate, maximum crystal population, and defenses.
3. Buy packs using earned in-game currency. Each pack offers THREE random cards and the player chooses ONE.
4. Cards create temporary run modifiers. Some target all drones of a built-in type (example: blue drones move twice as fast). Others target one server-selected random eligible drone (example: that drone's laser starts up twice as fast, meaning half warmup duration, not double damage).
5. Drones have permanent built-in identities, types, and base attributes; chosen temporary card modifiers must be represented separately. Persist pending offers/selected target IDs so reconnecting cannot reroll them.
6. Combat and mining cards compete for choices. Skill comes from which fleet build and route can reach profitable turret-guarded fields.
7. At a clear earned milestone, the player may prestige: lose all run-only cards/modifiers and run progression, gain ONE new permanent drone, keep the existing permanent fleet. Show exactly what resets and what persists before the action.
8. Repeat. A larger permanent fleet accelerates subsequent runs and allows deeper field progression. Balance permanent growth against pack/prestige costs, meaningful choices, encounter difficulty, visual/performance limits, and runaway modifier stacking.

Prestige and fleet/card state must survive real server restarts and reconnects. Add robust server persistence with migration, session locking/UpdateAsync, autosave and shutdown handling. In an unpublished/offline Studio session, use an isolated clearly labeled preview adapter, never silently treating temporary memory as durable saving. No real-money purchases are requested.

## Map and presentation

Keep the alien-world concept with super-simple shapes and parts-built trees. Take inspiration from Bee Swarm Simulator's readable fields and progression, while retaining this game's assets and identity. Rework the map into an intentional connected route: home/printing/cards/prestige, safe initial field, guarded progressively valuable fields, clear vistas/landmarks, good traversal, legible hazards. Keep original geometry as a preserved reference and integrate assets thoughtfully. No unrelated elevated test map laid over the original.

Replace the rejected cluttered UI with a small coherent HUD and deliberate, attractive three-card selection. Minimize permanent panels, debug text, billboard spam, and obstruction of the drones/world. Make card target, benefit, tradeoff, and stacking behavior readable.

## Quality and overnight work

Work in the existing cloud implementation chat and the single GitHub project; avoid another disconnected prototype. Produce a reproducible high-quality review build, readable source, meaningful tests and visual evidence where possible. Do not stop useful work if GitHub access, modeling, file opening or another integration blocks: continue independent code, math/simulation, models, documentation, review, and available playtests. A blocker must be stated accurately; passing automated checks is not evidence of polished visuals. Do not publish to Roblox without a separate request.

