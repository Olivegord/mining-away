# Specialist mining rework

Applies to the seven new miners in **Drone Blower revolution**, place `136098934779395`. Includes the latest combined `bdb76e2f521f4c3728e855ff59ab95f75be77656` source, retaining its shared client timelines, particle refinements, preview crew, performance corrections, map, original assets and persistent fleet. This supersedes the fixed-duration whole-rock behavior in `SPECIAL_DRONES_LOGISTICS.md`.

## Damage and rewards

The previous special contact replaced its damage amount with all remaining resource health. A two-second gravity job could therefore remove a huge hard rock as easily as a small starter rock, then multiply its entire payout. Each specialist now repeats a finite work cycle against the same reserved rock.

One impact removes at most **25% of the target's initial effective health** (`maxHP - 10`), after discovery and other applicable damage bonuses. It is also bounded by a finite work budget: `base mining DPS × base cycle duration × role power`. Mining cards shorten the cycle, rather than also multiplying that budget a second time. Bigger and harder resources require additional work. Four impacts are the minimum for an intact rock; a damaged rock can still be finished by a smaller final hit. Geode shells retain their existing shared mining path.

| Specialist | Base cycle | Role power | Completion ore |
|---|---:|---:|---:|
| Bubbler | 2.8 s | 1.10 | 1.25× |
| Halver | 3.6 s | 1.25 | 1.50× |
| Gridcutter | 2.5 s | 1.20 | 1.20× |
| Singularity | 2.0 s | 1.50 | 1.50× |
| Starforge | 3.0 s | 1.20 | 1.60× |
| Frostbite | 2.4 s | 1.05 | 1.10× |
| Resonator | 2.6 s | 1.15 | 1.30× |

Damage lands at 68% of the gesture; the rest is recovery before another strike. Intermediate chunks give visible progress without ore payout; the existing final-break reward path pays once, with its fractional remainder accounting intact. Purchases, ownership, prices and saved base traits remain intact. All numerical values are provisional tuning for the owner's next play session, not measured fun or economy validation.

## Animation research and application

These implementation choices apply primary-source principles to this game's mechanical tools. They are our design choices, not published timing constants.

- [Animation Mentor: Anticipation](https://www.animationmentor.com/blog/anticipation-the-12-basic-principles-of-animation/) supports a readable preparation before release. Each action now builds toward one clear contact, rather than immediately transforming the whole rock.
- [Animation Mentor: Slow In and Slow Out](https://www.animationmentor.com/blog/slow-in-and-slow-out-the-12-basic-principles-of-animation/) explains deliberate spacing. Preparation accelerates smoothly, contact is decisive, and recovery settles over a longer interval; tool assemblies do not all share one constant-speed oscillation.
- [Animation Mentor: Arc](https://www.animationmentor.com/blog/arc-the-12-basic-principles-of--animation/) informs consistent chip paths and joint-driven cutters. Rails and pistons keep intentional straight strokes; chips use coherent lift, spiral or ballistic paths.
- [Animation Mentor: Follow-through and Overlapping Action](https://www.animationmentor.com/blog/follow-through-and-overlapping-action-the-12-basic-principles-of-animation/) informs delayed assembly motion and limited recoil. The existing smooth travel and level overhead work station remain independent of cosmetic tool action.
- [Riot: Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) emphasizes recognizable silhouettes, directional cues and restrained visual noise. Each specialist has a dominant working assembly and its effect acts on a bounded piece of the target, leaving the remaining rock readable.

| Specialist | Dominant hardware | Mining action |
|---|---|---|
| Bubbler | Pressure vessels and glass capture chamber | Inflates a small capture bubble, lifts loose chips, then pops and settles. |
| Halver | Broad opposing cutter jaws | Opens, aligns, shears a seam, then retracts with controlled overlap. |
| Gridcutter | Rectangular scanner gantry | Sweeps a scan plane, scores a face lattice, and ejects a bounded layer. |
| Singularity | Tilted containment ring and gravity core | Builds a small gravity well and draws chips inward along shrinking spirals. |
| Starforge | Tall furnace and heat fins | Builds heat in a seam, releases molten droplets, then cools. |
| Frostbite | Long cryogenic tanks and cooling fins | Grows a restrained surface shell, cracks it at contact, then vents. |
| Resonator | Three tuning fork assemblies | Builds staggered resonance, releases a coherent fracture pulse, then damps. |

The client reads server timestamps, target/drone identity, duration, impact fraction and serial. Visible poses evaluate on every render frame. Resource subscriptions ignore unrelated scenery, offscreen geometry is culled, and a shared part budget bounds active effects. Nonlethal contact returns the remaining rock to its ordinary fracture renderer. Completed/depleted effects and interrupted work have separate cleanup paths so survivors do not disappear or retired rocks flash back.

## Verification and delivery limits

Run `python3 tools/test_special_logistics.py /tmp/luau` for production damage/reward, interruption, persistence/logistics, preview defaults, geometry and animation timeline checks with API doubles. The build tools preserve the live capture outside its exact script Source allowlist.

The final specialist runner passes 10 profile/logistics domain checks, 21 production-server checks, four preview checks, 29 FX lifecycle/timeline checks, seven hardware/joint checks and the HUD activity check. Mining/observer, existing-role/ability, energy/fracture, client-refinement and performance regressions also pass. The integrated client-smoothing suite passes nine shared-state/timeline checks and the scrap-observer check. Luau 0.745 compiles all source and both generated bundles; the new Catalog, FX and tool-motion modules pass standalone lint with explicit host bindings. Both active-capture and historical asset-preservation checks pass. Full output is in [verification results](SPECIALIST_REWORK_TESTS.txt).

The broad legacy `tools/test.py` command stops on its existing HUD typography guard: an 11px Backpack label violates that guard's 16px rule. This exact failure reproduces on unchanged `33ea151`; it is not a specialist regression. Later legacy stages are not reported as passing. The old full-bundle standalone lint preamble also lacks Roblox type declarations required by the current role modules; new-module lint is recorded separately. The performance regression now requires motion on every display frame and keeps geometry/subscription/distance bounds, replacing its old 30Hz held-pose assertion.

This environment has no connected Roblox Studio tool. Automated source/API-double checks do **not** establish native visual quality, real multiplayer behavior or player satisfaction. No Roblox publication or Studio Play start is part of this pass. The generated source-preserving review build is available for the owner/integration chat to install. The other chat's broader client-role smoothing is integrated at `bdb76e2`; the specialist rework adds to those files without restoring server-driven cosmetic animation.
