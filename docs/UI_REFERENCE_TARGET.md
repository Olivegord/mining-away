# Concrete UI reference: Balatro pack selection

The owner's latest direction is explicit: **UI is the main concern; find an existing UI to copy.** Use one coherent reference, not a collage of unrelated interfaces.

## Chosen reference

**Closely adapt Balatro's Arcana/booster-pack card-selection composition and interaction model.** Three physical card objects are a strong fit for Mining Away's existing server-generated three-choice/choose-one rule. Keep the normal world HUD small and separate. Bee Swarm remains the world/field-progression reference, not an instruction to imitate every aspect of its HUD.

Primary reference material:

- [Official Balatro press kit](https://www.playbalatro.com/press-kit), with original screenshots, GIFs and trailer.
- [Official Arcana Packs screenshot](https://www.playbalatro.com/press-kit/Screenshots/Arcana%20Packs.png).
- [Official Celestial Pack screenshot](https://www.playbalatro.com/press-kit/Screenshots/Celestial%20Pack.png).
- [Three-card Arcana selection screenshot in Shacknews's review](https://www.shacknews.com/article/138994/balatro-review-score); use as an additional composition reference, not technical authority.

Research found and opened the official image URLs and reviewed image-search descriptions of the selection screen. This handoff is **not a frame-by-frame animation inspection or live Balatro playtest**. The implementer and independent reviewer must open the actual reference images and footage before claiming close visual fidelity. Proposed dimensions/timings below are Mining Away design choices, not measured Balatro values.

## What to copy closely

1. A discrete row of physical cards, with consistent portrait proportions and meaningful illustrated faces. Keep space between their silhouettes. Avoid a giant panel containing three nested dashboard panels.
2. Strong card identity: small title, one clear illustration/symbol, concise effect. Use Mining Away's original drone silhouettes and authored icon vocabulary. Every card face must be intentionally composed rather than a generic icon over a gradient.
3. One clearly active card at a time. Hover/focus raises it slightly and exposes a compact attached detail treatment; touch uses first tap to inspect and a separate explicit choose action. Preserve access to all three choices.
4. Restrained tactile feedback for opening, revealing, focusing, pressing and applying. The card object responds to the player's input; idle wobble and constant sparkle are not a substitute.
5. A small, unambiguous choose-one instruction and an action visually attached to the selected card. After authoritative acknowledgment, the chosen card resolves into the fleet/build and the others leave cleanly.

## Adaptation to this game

- Anchor a compact tray in the lower center while leaving the drones and field visible. At 1280×720, start around a 560–650 pixel wide row and test readable card faces; do not treat these suggested values as acceptance. Keep at least the upper half of the world unobstructed during ordinary card comparison.
- Use a modest dark outline, flat restrained card surface, purposeful type color and crisp custom icons. Give cards a small physical edge/shadow rather than a giant soft floating shadow. Keep heading sizes proportionate to the tray.
- Show effect, target, tradeoff and “This run” before commitment. Focused details can show exact before/after values and stack cap; essential tradeoffs must never exist only in a hover tooltip unavailable to touch.
- Show the server's saved three outcomes. Opening animation begins after the durable offer arrives; skip/reveal-all only accelerates presentation. Closing/rejoining preserves the same offer. No simulated reroll, fake near-miss, or chance-changing timing trick.
- A short proposed sequence is press feedback → 250–400 ms opening → brief staggered reveal → stable comparison → confirm → acknowledgment. Respect reduced motion and allow reveal-all. Tune from real interaction, not from a written animation description.
- Use a deliberate phone composition that preserves readable choices and a reachable confirmation control. Never scale the desktop tray until text becomes tiny.

## What not to import

Do not copy the entire full-screen poker table, large statistics sidebar, purple swirl, card illustrations, logos, poker labels or Balatro typography wholesale. Use the reference's layout and interaction grammar with this game's own art and content. Do not add a Skip button that discards the paid saved offer: this game's close action preserves it. Do not introduce extra targets or deck-selection complexity that the server rules do not require.

Do not “modernize” it into a generic AI dashboard: no glassmorphism, purple-blue mesh gradients, pill badges everywhere, emoji icons, huge title, redundant subtitles, equal-weight grids of statistics, massive rounded containers, animated background blobs or permanent explanatory paragraphs. A cream reskin of the same dashboard also fails. These constraints serve an authored card interface; they do not prohibit a color merely because other AI designs have used it.

## Independent acceptance

Give the visual reviewer the exact reference screenshots alongside actual final-build desktop/phone captures and uninterrupted pack interaction footage. Require comparison of hierarchy, density, card proportions, hover/focus/press, transition quality, legibility and preserved world visibility. Any clipped text, overlapping input, floating effects, abrupt motion, stale offer UI or attractive-but-unusable phone layout is a rejection. Source code, mocks and previous screenshots cannot pass this gate. See `VISUAL_QUALITY_GATE.md` for the full veto and repair/re-review rules.
