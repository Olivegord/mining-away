# Owner requirements

## November 1 latest — mineral shops, tutorial UI and creative automation

The owner requests simpler Leaf Blower Revolution style progression in this same game. New players begin with Quartz only; the Quartz shop sells access to Ruby and its shop, continuing through the existing minerals. Each shop spends its own mineral currency. Keep the Packs stand and its server-generated three-choice, choose-one upgrades. Shop upgrades should mostly remove friction or unlock automation, including faster pack reveal animations. Use Roblox UI tutorials as concrete structure: compact equal-sized upgrade cells, a short description, Buy, and a separate Info action for full terms.

The owner explicitly requests a subagent for new drone types, smoother movement and drones separating/pushing past each other. Mining upgrades should create interesting actions rather than rely on generic money/damage multipliers: examples include an orbital laser that instantly breaks the biggest rock and a cute miniature scrap-bot swarm lasting ten seconds. The owner additionally names **N-Gon**, the web platformer, as a major inspiration for creative upgrades and combinations. Adapt these mechanics to authoritative Roblox mining; preserve original models and the permanent fleet. Do not copy another game's branding or artwork.

Current implementation choices (not additional verbatim requirements): sold ore deposits one unit of its matching currency; the Packs stand spends Quartz; shop access/upgrades and currency balances reset at prestige, while permanent drones and previously earned guard clearances stay. Orbiter/Scrapper roles also unlock their respective abilities. See [mineral shops](review/MINERAL_SHOPS.md) and [drone gadgets](review/DRONE_GADGETS.md). Prices, ability timings and progression still need owner playtesting. The standing restriction against new Studio Play sessions and publishing remains.

## October 31 latest — spheres, Part lasers and flight

The owner corrected the effect design: **three spheres of different sizes, oscillating in size with sine waves**, not rings. Mining lasers must be **transparent cylinder Parts**, always straight down, with smooth transitions. Every drone needs trails and a flying effect. The owner explicitly authorized one Play verification session after a renderer crash; this permits inspecting and replacing the client renderer within that same session, not publishing or claiming multiplayer/visual approval.

## October 31 latest — effects must communicate work

The owner requests substantially stronger effects and anticipation: visible charge-up, holding, release and recovery. Mining needs a wider outer beam, a thinner inner beam, particles, and the old three-circle style at the beam origin. Restore available original mining particle/contact assets from preserved backups. Courier/supply work must be understandable through motion, parcel transfer and beam/particle effects rather than explanatory UI. All effects follow authoritative work phases; visuals cannot invent mining hits, completed pickups, healing or sales. Preserve the existing game and standing no-publishing/no-new-Play-session instruction. See [work effects](review/WORK_EFFECTS.md).

## October 31 latest — Toolbox sound and Roblox presentation

Add varied background music and sound effects from the Toolbox to the same Drone Blower revolution game. Improve lighting and make the presentation feel more Roblox-like, preserving the original models, map identity, crystal audio and current backpack/swarm/card work. The owner authorized coordination between the audio/visual chat and “Update map, drones, and UI” to prevent overwrites; that chat owns the combined Source integration, commit, build and review PR update. No Roblox publishing or new Play/test sessions are authorized by this request. See [audio and lighting review](review/AUDIO_LIGHTING.md).

## October 31 latest — backpack, moving swarm and simple 3D cards

The owner's newest request supersedes the individual-drone cargo and elaborate card directions below. Apply this to **Drone Blower revolution**, place **136098934779395**, in the existing connected Studio instance and the source-only review build.

- Easiest plots are closest to spawn and selling, with increasing distance as difficulty rises.
- Reduce shine and use native Roblox material/surface variety, including metal and studs.
- Miners have no storage. Ore enters a backpack carried by the player, who brings it back to sell. A dedicated courier takes a small batch from the backpack, physically flies to sell it, and returns. A tiny slow healer follows and repairs other drones with an attached beam. Keep the designs simple, mechanical and unpersonified.
- Restore the preview random-loadout button with **2–5 drones**. It must not replace permanent saved ownership.
- Movement is central: uniformly regroup around the owner; jobs produce visible interactions, separation, passing and floating swarm behavior. Idle workers follow the player. Keep damage, healing, ore and sales authoritative.
- Cards have **two visible text elements maximum**, native Roblox-like fonts, and lead with the actual effect. The owner requested 3D SurfaceGui/ViewportFrame cards. Roblox does not render nested GUI objects inside a ViewportFrame, so use supported camera-local card Parts with SurfaceGui faces containing ViewportFrame visuals.

The prior instruction against test runs and starting Studio play sessions still applies. Edit-time integration, static source review, syntax compilation and reproducible builds do not establish visual or multiplayer acceptance. See [backpack and swarm review](review/BACKPACK_SWARM.md).

## October 31 latest direction — earn the automation

The owner rejected cosmetic mining changes and clarified the actual loop: start by clicking individual ores for drones to mine. Upgrade cards then remove specific chores: first permit drones to choose stones after a plot command, then automatically return each individually full drone to unload. Automation is earned progression, not the starting behavior. Keep individual drone cargo and make manual delivery available before the automation upgrade. These instructions supersede older unconditional plot selection/shared-cargo behavior.

The swarm should use smaller original drones working closer to the minerals, with the world visible behind a much smaller HUD. Reduce neon without treating effects as the gameplay fix. No test runs or new Studio play sessions; the owner will test.

Integration must also preserve the newer active Studio permanent plot-unlock implementation. Clearing guards unlocks that plot across prestige; the older timed-expedition and closed-roster descriptions below are historical.

## October 31 target correction — Drone Blower revolution

The owner clarified that the game is the existing **Drone Blower revolution**, Roblox place **136098934779395**. The older local Mining Away build was the wrong artifact. Continue in this same repository and existing experience; preserve the live map, assets, card UI, tactical HUD, role drones, crystal audio and discovery systems. The active Studio capture takes precedence over conflicting historical presentation/build instructions below.

The immutable native backup is `assets/drone-blower-revolution-base.rbxl`, SHA-256 `b08036b400c77451e609f5fa3a4f7f04cd5dcc2030f35a76de12ecc278f532cd`. Build it to `build/Drone Blower revolution.rbxl` by changing only the exact live controller/module Source allowlist. Preserve all other binary chunks, script enablement, backup copies, geometry, terrain, lighting and assets. Never rebuild the active game from the old `assets/mining-away-base.rbxl`; retain that file as historical reference. Do not create or publish another experience.

The owner's latest direction is to finish the implementation and let them test it themselves: stop additional test runs and Studio play sessions for this pass. Describe the resulting validation limits honestly; historical test results do not validate the newly integrated live-target build.

## October 31 mining gameplay priority

The owner wants mining to be substantially more fun and asks for research into the appeal of bouncing/merging-ball videos and rock-paper-scissors particle simulations. The highest priority is the gameplay loop: understandable rules, anticipation, meaningful choices, visible consequences and satisfying progression. Sound and visual feedback should communicate those mechanics. Presentation alone does not establish that the game is enjoyable.

Actively identify and fix mechanics that make play unsatisfying whenever working on this game. In particular, fields need meaningful crystal-hardness progression, including genuinely harder later resources, and permanent drone types need different mining behaviors rather than identical beams with cosmetic changes. Preserve quick early mining, the original overhead flight/mining feel and assets, server authority, permanent fleet identity, and the existing card/prestige loop. Evaluate difficulty together with rewards, travel, downtime and build choices so harder resources do not merely add waiting.

See [mining satisfaction research and candidate criteria](MINING_SATISFACTION.md). Its tuning and behavioral designs are implementation proposals, not additional verbatim owner requirements or proven retention results. Research informs the work; real playtests must establish whether it is satisfying. Existing final-build visual/multiplayer gates and the prohibition on Roblox publishing remain in force.

## October 28 owner rejection — visual rework required

The owner explicitly rejected actual 1c22606 screenshots: “this is so bad. bro.” This is a rejection of the presentation, not a near-finished visual pass. Preserve the existing game, source, original assets, server authority, progression and safety rules. Keep the PR draft and do not publish.

The card offer must closely adapt the selected Balatro physical-card hierarchy using original mechanic-specific artwork: identifiable laser lens or drone emitter, splitting prism and drone battle formation. Art should dominate, with concise readable name, target and benefit, full exact terms on focus, a clear focus/press state and an appropriate choose action. Lead with actual benefit and place penalties second; Battle Formation must show its combat benefit, and Long Lens is combat range rather than flight. Rarity is subordinate to card identity. Avoid repetitive rounded cream dashboards, generic icons, balloon tutorial panels, oversized padding and indiscriminate gradients. Keep native 16–18 px legibility. Use a recognizable lit original drone thumbnail and a compact utilitarian HUD/roster. Hide contextual controls behind menus and never offer mining when cargo is full.

Remove imported global depth of field, excessive bloom and exposure. Create sharp readable daytime, matte paths, distinct mineral shapes, a purposeful depot-to-first-field sightline and legible original pyramid landmark. Preserve grounded structures and validated collision fixes. Rework the spawn canopy so it does not block the initial view. Avoid empty mint planes, huge monotonous faces, white paving, bright point-light blobs, blank station faces, random clutter and indiscriminate tree placement.

Actual final-build Studio comparison at matching camera angles, in motion, at desktop/phone and low/high graphics remains mandatory. The independent art director has non-waivable veto; no passing tests, attractive source or old screenshots establish approval. The 1c build was rejected and the final visual gate is NOT VERIFIED until new evidence is reviewed.

## October 27 current direction and visual veto

The owner's newest instructions supersede conflicting older visual choices: keep this same game and source repository, but make the map intentionally retro Roblox and **parts-built**, with legible connected fields, grounded structures, landmarks and a coherent authored alien identity. Avoid the current low-poly/faceted filler terrain. Bee Swarm Simulator is a reference for field/route readability, not an asset or theme source. Preserve the original drone, crystal and segmented construct pyramid assets, original overhead mining and eased flight, real server authority, durable pending offers, free reprints and prestige.

Gameplay is the priority and the pack/card UI is the highest-priority visual concern. Adapt the concrete structure of the [official Balatro Celestial Pack screen](https://www.playbalatro.com/press-kit/Screenshots/Celestial%20Pack.png): three distinct small portrait cards in a spaced lower-center row, focused details just above the focused card, and a separate small choice control. Keep the world visible; do not copy copyrighted art, branding, poker HUD or background. Consult the [official Arcana Pack wrappers](https://www.playbalatro.com/press-kit/Screenshots/Arcana%20Packs.png) for tactile package reference, not color/illustration copying. The earned-currency pack should reveal exactly three already-saved server choices, choose exactly one, and feel compact, tactile and responsive; benefits, tradeoffs, named/type targets and this-run duration remain clear. Show a short opening and stagger, restrained hover/tap/focus lift, immediate press response, server-confirmed choice pulse and collapse, with a reduced-motion equivalent. These timings are implementation proposals, not measured claims about the reference. No fake near miss, paid Robux RNG or cosmetic reroll. Beam cores/halos, impacts, turret telegraphs, fractures and reprint transitions must remain readable, attached, bounded and clean for every observer.

An independent art director has veto authority and may not approve without **actual final-candidate Roblox engine motion evidence**. Reject clipped or detached beam layers/muzzle/impact, opaque square/noisy particles, effects through surfaces, snapping/jittering/clipping animations or broken transitions, floating/buried trees and props (including slopes), bad road joins, generic empty platforms, faceted filler, random clutter, giant dashboard UI or generic rainbow/gradient rarity piles. Inspect normal and close player viewpoints in motion, low/high graphics, desktop/phone and busy multiplayer; fix defects and obtain fresh evidence. If final evidence is unavailable the verdict is NOT VERIFIED and the full visual goal remains incomplete. Do not infer authorship from pixels or claim these patterns characterize most AI games.

See [independent visual quality gate](VISUAL_QUALITY_GATE.md), [visual acceptance](review/VISUAL_ACCEPTANCE.md), [art director report](review/ART_DIRECTOR_GATE.md), [negative prompt and positive alternatives](review/NEGATIVE_PROMPT.md), [exemplar research](EXEMPLAR_RESEARCH.md) and [public prompting research](ROBLOX_PROMPT_RESEARCH.md). Published suggestions and mockups are references, not proof of a polished game. No Roblox publishing or main merge.

## October 25 foundation

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


## Latest overnight acceptance refinements

The top visual priority is a compact, legible three-card selection using the spatial hierarchy of the owner-selected Balatro Arcana choice reference, with original Mining Away content. Essential targets and effects should aim for 18 px and supporting text 16 px at a 720p desktop baseline; compactness must not rely on 8–11 px microcopy. Compare all choices on touch, with focus and explicit confirmation. Individual owned-drone resource selection must show available slots and pending, accepted, rejected and canceled outcomes; repeat commands must preserve an existing job. Autosave must not discard reservations or warmup while saving, and must retain safe transaction isolation.

Retain the original inner beam's two-second width ramp and 0.2-second hide. Any charging cue must reflect authoritative warmup without changing that ramp. The independent art director has a non-waivable real-engine gate: clipped or detached beams, ugly or opaque particles, snapping animation, and floating or buried props are hard failures. Normal-speed final-build inspection must cover ordinary and busy scenes, low and high graphics, multiple viewports and camera angles. Without exact final-build evidence the verdict is NOT VERIFIED, not approval.

## Bounded multiplayer beam visibility

Beam surface verification must share the bounded per-frame ray budget fairly across eligible contacts, preserve primary readability while guaranteeing bounded fair service to gameplay fork and chain branches, stop consuming queries after an inactive beam's original 0.2-second fade, and expire unverified contacts so an obstruction cannot leave a ghost beam indefinitely. Test actual Presentation logic under changing populations at 30, 60 and 144 FPS, including inactive predecessors, secondary branches and new obstructions. Preserve the original two-second active ramp and 0.2-second hide. A finite budget can require explicit graceful overload degradation; do not silently starve a stable subset or claim API-double checks are Studio visual evidence.

Native Studio font metrics have also demonstrated context, objective, and 430px modal-title overflow. Reflow those areas without tiny text, and inspect actual production feedback and all three offer controls in the Studio harness. Final motion and interaction evidence for the exact build is still required.
