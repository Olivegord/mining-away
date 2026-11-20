# UI references and direction

Research date: October 25, 2026. This is the reference brief for the Mining Away UI overhaul. The owner asked for Roblox examples; the examples below come from Roblox's own Creator Hub and are reference material, not imported art or code.

## Roblox examples

The [official UI and UX guide](https://create.roblox.com/docs/production/game-design/ui-ux-design) supplies the following concrete examples:

| Example and direct visual | Useful lesson | Application to Mining Away |
| --- | --- | --- |
| [Spellbound RPG: contextual Items menu](https://prod.docsiteassets.roblox.com/assets/game-design/ui-ux-design/ui-ux-design-2.png) | Secondary actions appear after opening the relevant menu. | Keep fleet details and the card collection behind deliberate navigation; preserve the world view during mining. |
| [Spellbound RPG: spell cards](https://prod.docsiteassets.roblox.com/assets/game-design/ui-ux-design/ui-ux-design-4.png) | A physical card metaphor makes an abstract ability understandable. | Give offers a recognizable card face, category emblem, obvious benefit, target, and one selection button. |
| [Winds of Fortune: player stats](https://prod.docsiteassets.roblox.com/assets/game-design/ui-ux-design/ui-ux-design-11.png) | Related stats use consistent icons and color. | Reuse the same mineral, cargo, fleet, and upgrade symbols across the HUD and menus, always with text. |
| [BotClash Simulator: buttons](https://prod.docsiteassets.roblox.com/assets/game-design/ui-ux-design/ui-ux-design-12.png) | Containment, highlights, and shadows make buttons feel tactile. | Use outlined raised buttons with readable labels and clear pressed/disabled states. |

A fifth reference is Roblox's [Plant reference project, UI and view handling](https://create.roblox.com/docs/resources/plant-reference-project#user-interface). It separates HUD and menu layers, uses reusable components, and displays one menu layer at a time. Mining Away should maintain a single focused modal with a consistent close path instead of allowing unrelated screens to overlap.

The linked images were identified in the official guide and its labeled examples. This research did not involve playing those experiences. No reference asset, UI pack, implementation, monetization layout, or game logo was copied.

## Project-specific visual direction

These are our design decisions, inferred from the references and the owner's requirement for a compact, purposeful HUD. They are not claims that the reference games use this palette or this exact layout.

- Use warm cream card faces and panels, dark teal/navy text and outlines, mint for constructive actions, amber for currency and consequential actions, and coral for tradeoffs or threats. Keep this UI related to the game's pale stone, turquoise minerals, warm paths, and original drone colors.
- Give panels rounded corners and restrained offset shadows. Reserve strong saturated fills for important actions and meaningful state. Avoid covering the world with translucent dashboard rectangles.
- Use bold, rounded headings with a quieter body face. A resource total and a card's main numeric effect should be readable before its explanatory text.
- Draw a small coherent family of original symbols from Roblox GUI primitives. Pair every unfamiliar symbol with a label. Do not substitute emoji, random toolbox images, or inconsistent stock packs for a visual system.
- Put currency and cargo together in the main resource HUD. Keep field/fleet status subordinate. Provide a small navigation group with labels instead of a wall of unexplained side icons.
- Keep the mining view open around the player and drones. Display station-specific instructions and relevant actions only when they can be used, without requiring the player to infer a command from decorative signage.

## Information and interaction contract

The offer panel must make three choices comparable in the same reading order: category and icon, card name, target, principal effect, tradeoff, stat preview, stacking limit, then selection. Use the real saved target and server-provided preview. Never present a temporary card as a permanent drone trait. A close action must leave a paid pending offer intact and make reopening it discoverable.

The fleet screen should distinguish a drone's permanent identity/type from its temporary run upgrades. The prestige screen must state that existing permanent drones persist, exactly one permanent drone is gained, and run progression/cards reset. A visual redesign cannot replace server eligibility or confirmation requirements.

Interaction needs readable hover, pressed, selected, unavailable, pending, and error states. A transaction remains pending until authoritative state confirms it. A save problem must remain visible when it affects purchases or prestige; the isolated Studio preview label must remain accurate and readable without becoming a giant debug panel.

The card catalog remains data-driven and inspectable in [the full card reference](../game/upgrade_cards.md). The UI should help the player compare the current three offers, while the documentation provides the exhaustive list the owner requested.

## Review requirements

Review the actual generated Roblox place at desktop and narrow/touch viewport sizes. Inspect HUD, depot, fleet, the longest three-card offer, pending offer reopening, unavailable actions, and prestige confirmation. Check outlines, text clipping, wrapping, touch target separation, modal scrolling, CoreGui/safe-area overlap, and whether the world remains readable.

Verify card selection, closing/reopening menus, and transactional feedback against real authoritative state. Automated source checks can help catch layout regressions but do not demonstrate visual quality, touch usability, multiplayer correctness, or Studio playtest success. Record those separately with the exact build revision and real evidence.
