# Mining Away — exemplar research and implementation direction

Research date: October 27, 2026. Read `OWNER_REQUIREMENTS.md` and `ORIGINAL_FEEL_PARITY.md` first; they remain the behavior contract. The latest owner direction is gameplay first, a smaller interactive RNG/card UI, a retro parts-built map, excellent beams, and an independent reviewer who can reject the entire result for weak visual quality. See `VISUAL_QUALITY_GATE.md` for that gate.

## Evidence and limits

This brief uses creator-owned Roblox listings and Roblox's own design/engine documentation. It is **not** a live playtest of these games, an instrumented retention study, or proof that Mining Away looks good. Official promotional art cannot establish runtime readability. Obtain in-game camera references and compare the built game before visual approval. Exact timings, dimensions, layouts and pacing targets below are design proposals for Mining Away, not measured properties of an exemplar.

| Exemplar | Source-backed observation | Useful inference for Mining Away |
| --- | --- | --- |
| [Bee Swarm Simulator, Onett](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator) ([official localized description](https://www.roblox.com/de/games/1537690962/Bee-Swarm-Simulator?nl=true)) | The creator describes collecting pollen/making honey, growing a swarm, progressively exploring a mountain, fighting enemies, discovering treasures, and bees with individual traits. | Tie a larger permanent fleet to routes the player can see and aspire to reach. Let drone identity matter to both mining and combat. Use the owner's requested readable retro parts-built aesthetic; don't copy the mountain layout, bears, bees, names or assets. |
| [Super Bomb Survival, Polyhex Games](https://www.roblox.com/games/164051105/Super-Bomb-Survival?_escaped_fragment_=%2Fabout) | The creator describes physics-based survival under falling explosives, random events, and skills/perks that tailor a play style. | Randomness should create a situation requiring a readable decision. For Mining Away, telegraphed turret attacks and mining-versus-combat card choices should reward attention. This is not an instruction to add falling bombs or unrelated physics chaos. |
| [Spellbound RPG, documented by Roblox](https://create.roblox.com/docs/production/game-design/ui-ux-design) | Roblox illustrates an Items button that reveals related controls only when selected, plus spellcasting represented as drawing cards. Its guidance prioritizes contextual information and warns against excessive bright/moving elements. | A physical pack/cartridge metaphor fits drone upgrades. Keep the normal HUD small; reveal three cards only for an actual pending offer. Give the reveal a distinct beginning, readable choice state and short resolution. |

## 1. Build the playable decision loop first

The signature loop is **watch a recognizable drone work → choose an upgrade → attempt a visibly more profitable route → earn another permanent drone**. It must be satisfying with the initial single drone; a large starting fleet would conceal pacing problems and violate the requirements.

- Preserve eased/capped travel, level yaw, ring follow, directly overhead mining, original crystal geometry, three visible quarter-health fracture changes, and two-second growth. Improve correctness without changing these into a different mining game.
- First-run sequence: a clear safe field within sight of spawn; visible progress toward an affordable first pack; a meaningful mining/combat choice; a guarded field the player can inspect before attacking. Measure the time to each event in the actual build and adjust if the player spends long periods waiting without choosing or moving.
- Each card should answer a route question. Faster startup helps frequent short mining jobs; travel speed helps spread-out patches; combat power/survivability supports guarded patches. Avoid a catalog of numerically different cards where the same choice is always strongest.
- Show target identity, concrete stat change and current stack/cap. `Warmup 2s → 1s` is clearer than `+100% laser startup`. A type card must identify affected owned drones; a single-drone card must use the server-persisted target.
- Permanent identity and fleet survive prestige. The confirmation must enumerate the reset and show the one new permanent drone benefit. No paid packs, Robux hooks or client-generated outcomes.

## 2. A compact, tactile three-choice pack

Proposed default desktop composition: a small currency/progress cluster, one contextual interaction prompt, and brief event feedback. Fleet details expand on request. Start the offer tray near the lower middle with three evenly sized cards; at a 1280×720 viewport try roughly 560×230 pixels, then resize based on actual readability. On narrow screens reflow deliberately instead of shrinking text. These are starting experiments, not acceptance shortcuts.

Offer state machine: **requesting → persisted offer ready → reveal → choosing → confirming → applied**. Closing/reopening or reconnecting restores the same offer and targets. Persist the offer before showing its reveal; lock purchase/selection while a request is pending and make retries idempotent.

Proposed interaction choreography:

1. A press visibly depresses the pack control immediately; server wait has a quiet loading state.
2. Once the server returns the durable offer, a single 250–400ms pack opening reveals three card backs. A short stagger or deliberate tap exposes faces. Offer a skip/reveal-all action; never require repetitive clicking just to reach the decision.
3. Hover, keyboard/gamepad focus and touch selection share a crisp outline and slight lift. No endless wobble. All three benefits stay readable at once. A selected card shows its exact affected drone/type and stat delta; an explicit choose action commits it.
4. A short restrained burst travels toward the relevant fleet indicator or drone only after authoritative selection acknowledgment. Collapse the tray promptly; restore world visibility.

Rarity may change border/icon/sound strength, but should not obscure usefulness. Do not fabricate a roulette near-miss, show false odds, or imply clicking at the right instant changes the result. If displaying probabilities, derive them from the actual server catalog/eligibility rules. Prefer surprise plus a strategic choice over passive rolling.

[Roblox's button documentation](https://create.roblox.com/docs/ui/buttons) supports distinct hover/pressed states and `GuiButton.Activated` for interaction. Use this to make mouse, touch and gamepad behavior coherent. [Roblox accessibility guidance](https://create.roblox.com/docs/production/publishing/accessibility) documents `GuiService.ReducedMotionEnabled`, preferred transparency and text size. Respect those preferences: replace lifts/spins with a brief fade or immediate reveal, preserve readable contrast, and never make sound or color the sole carrier of outcome.

## 3. A parts-built world with deliberate routes

The requested retro aesthetic is a material and composition choice, not permission for an empty graybox. Use Parts for broad ground terraces, blocky retaining walls, steps, bridges, chunky trunks/canopies, path edging and purposeful industrial props. Prefer legible flat surfaces and restrained materials over faceted triangulated terrain, low-poly cone forests and decorative rock scatter. Keep existing distinctive meshes and original crystals; the new direction does not authorize deleting the owner's authored content.

Compose one connected ground-level route: home printer/card station → generous safe mining clearing → clearly signaled guarded fork → deeper profitable landmark. Preserve useful original geography and recognizable sightlines. The original segmented pyramid is the enemy landmark, not a substitute box. Place it so its silhouette and eye telegraph read from the approach. Show promising later areas through gaps, turns and changes in elevation; avoid disconnected floating test platforms.

Use a small consistent palette drawn from existing alien assets: quiet ground, one main path material, mineral-specific accents, and a distinct hostile warning color plus shape. Reserve bright emissive surfaces for actual resources, active machinery and attacks. Repetition belongs in construction details; routes and major landmarks need authored variation. Check the composition at normal player height, not just a flattering overhead view.

## 4. Beams should explain the work

[Roblox's Beam guide](https://create.roblox.com/docs/effects/beams) documents attachment endpoints, texture/color/transparency, endpoint widths and `FaceCamera`; it also warns that quality settings can affect appearance. Test the lowest and highest settings. These are implementation capabilities, not proof that any beam configuration is attractive.

Reuse the original `InnerBeam`/`OuterBeam` assets. Build a narrow luminous core, restrained softer halo and a precise impact cue. Attach origin to the rendered drone emitter; follow the current shrinking crystal surface at the other end. Keep the original soft warmup/hide feel, and make the warmup card shorten actual server warmup rather than silently increase damage.

Give mining a quiet sustained rhythm, each of the three fracture thresholds one clear crack cue, and depletion a brief larger release. Turret charge, shot and impact need a different readable rhythm. Avoid constant full-strength sparkle, giant light radii, screen-filling bloom and reward text per tick. Limit/pool cosmetic effects at large fleet sizes, reducing remote/distant detail before local interaction readability. Cosmetics must never grant damage/rewards or delay authoritative simulation.

## Completion evidence

The cloud implementation should deliver a reproducible build and exact commit, actual logic/pacing tests, and an independent review against `VISUAL_QUALITY_GATE.md`. Capture normal player-height traversal, the full pack flow, mining closeups through all fracture stages, and two-player visibility/late join separately. Evidence missing because Studio is unavailable means **visual/multiplayer approval pending**, not “passed by code inspection.” Continue useful implementation and tests while documenting the precise blocker. Do not publish Roblox or create another experience.
