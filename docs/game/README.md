# Mining Away handbook

This folder explains the editable game behind `build/Mining Away.rbxl`. Start here before asking an AI to change the place. The source of truth is the current `src/` code together with [owner requirements](../OWNER_REQUIREMENTS.md); generated place files are builds of this one project.

| File | Read it when you need… |
| --- | --- |
| [architecture.md](architecture.md) | A file index, runtime data flow, authority rules, build instructions, or the right place to make a change. |
| [map_reference.md](map_reference.md) | The map layout, routes, preserved assets, station locations, visual direction, and lighting without inspecting Studio first. |
| [game_design.md](game_design.md) | An explanation of the player loop, permanent fleet, mining, combat, multiplayer, cards, prestige, and saving as implemented. |
| [upgrades.md](upgrades.md) | How packs, targeting, stacking, stat limits, and builds work. |
| [upgrade_cards.md](upgrade_cards.md) | Every possible upgrade card and its exact effect, including special mechanics and fallback cards. You do not need to roll packs to discover the catalog. |
| [implementation_plan.md](implementation_plan.md) | The implementation order, source files, completed foundations, remaining acceptance work, and rules for future changes. |

For a quick AI handoff, supply this README, `architecture.md`, `map_reference.md`, and the relevant system section in `game_design.md`. Supply both upgrade documents for card or balance work. Read the corresponding source before editing; tables here describe the code and must be updated when the code changes.

## How to interpret status

“Implemented” means the behavior is present in source. A logic test, source inspection, or successful binary build does not establish how the game looks or feels in Studio. The final review must record its exact source revision, build hash, checks actually run, and remaining limitations in [the validation report](../review/VALIDATION.md). Use [Studio acceptance](../STUDIO_ACCEPTANCE.md) for engine, multiplayer, original-feel, touch, and persistence checks.

The historical base is a December 18, 2023 autosave. It is preserved at `assets/mining-away-base.rbxl`; it is not a current export of another open Studio place. The older [gameplay brief](../../Mining%20Away%20-%20Gameplay%20Design.md) and `reference/cloud-v1/` are historical context. They do not override [owner requirements](../OWNER_REQUIREMENTS.md) or [original-feel parity](../ORIGINAL_FEEL_PARITY.md).

## Keep the handbook useful

1. Change source and the affected reference document together. Keep the card table complete and map coordinates consistent with runtime assembly.
2. Put proposed mechanics in the implementation plan until they exist. Label observations, simulations, and unrun acceptance checks separately.
3. Keep executable rules in source. Documentation describes them; it must not become a second competing set of balance constants.
4. Preserve permanent identity, original art, server authority, and safe saves during every visual or balance change. Do not publish to Roblox as part of a build or documentation task.
