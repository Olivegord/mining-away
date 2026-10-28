# Owner requirements

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
