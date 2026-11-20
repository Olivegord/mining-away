# Implementation and acceptance plan

Use this plan alongside [game_design.md](game_design.md), [map_reference.md](map_reference.md), [upgrades.md](upgrades.md), and [upgrade_cards.md](upgrade_cards.md). The game already has the server/card/prestige foundations below; do not recreate it as a disconnected prototype. A task starts by checking the current source and final review log, then implements only the missing or requested change.

## Constraints that apply to every step

- [Owner requirements](../OWNER_REQUIREMENTS.md) override the older brief and rejected cloud-v1. Original behavior is specified in [feel parity](../ORIGINAL_FEEL_PARITY.md).
- Preserve the asset base, original drone/crystal silhouettes and segmented pyramid. Runtime decoration and safe recoloring must retain their identity.
- Server owns gameplay/persistence; clients may render smoothly. Keep permanent identity/base traits separate from temporary cards and transient lives.
- Build `assets/mining-away-base.rbxl` into the single `build/Mining Away.rbxl`. Do not publish Roblox or create another experience.
- Record automated, simulated and Studio evidence separately. A blocked tool does not stop available implementation or logic review, and must not be represented as a passed engine check.

## System-by-system implementation map

“Source implemented” means a current implementation exists. Its acceptance column defines how to prove a change preserved the design; it does not certify the final engine result.

| Order / system | Current foundation and owned files | Acceptance for changes |
| --- | --- | --- |
| 1. Preserve source and establish build | **Source implemented.** `tools/build.py`, untouched asset base, `reference/original/src/`, binary/geometry tests. Lexical modules patch the original two controllers. | Verified source checksum, exact revision/hash, deterministic artifact, only approved binary properties changed; no duplicate active simulator. |
| 2. Map and art direction | **Source implemented; final visual/walkthrough acceptance required.** `World.lua`, field geometry in `Config.lua`, [map reference](map_reference.md). | Grounded connected routes, readable home/machines/fields, original assets retained, no hidden blockers or floating supports; walk route and compare fixed-camera shots in Studio. |
| 3. Lighting/materials | **Runtime configuration exists; visual result requires review.** `World.lua`. Inspect any provided reference place read-only before adopting settings. | Drone/crystal/pyramid silhouettes survive sun, shadows, fog and bloom; modest emissive highlights; readable day/distance views. Report whether a reference place was actually inspected. |
| 4. Permanent profile | **Source implemented.** `Profile.lua`, validation/migration tests. | One new Blue; stable IDs/base traits through save/reload, reprint and prestige; exact `fleet = prestiges + 1` invariant; fail closed on corrupt/future data. |
| 5. Durable transaction boundary | **Source implemented, fault-injected logic tested; real service acceptance separate.** `Persistence.lua`, `Server.lua`. | One commit for buy/select/sell/prestige, retry after before/after-commit failure, no default overwrite, lease takeover fencing, bounded final release. Controlled live server/restart test remains necessary for a production claim. |
| 6. Original movement and crystals | **Source implemented.** `Feel.lua`, `Server.lua`, `Client.lua`, original reference controllers. | Reference-equation tests; observed ring/hover, eased 30+ stud flight, overhead arrival, two-second growth and all three fracture changes; no early mining, stale beams or duplicate rewards. |
| 7. Useful card choices | **Source implemented and extended with signature effects.** `Cards.lua`, `Server.lua`, `Client.lua`, `CardView.lua`, both upgrade documents. | Three distinct useful resolved choices, stable targets/price after reconnect, server-resolved before/after stats with correct units, only one installed result, visible cap/stacking/tradeoff behavior, specialty effect actually reaches an eligible second target. |
| 8. Sentry/assault gameplay | **Source implemented.** `Rules.lua`, `Server.lua`, `World.lua`, `Presentation.lua`, `SentryMotion.lua`, `Feedback.lua`. | Actual pyramid art; telegraph frozen before firing; correctly timed evade changes outcome; ten weak wipe/reprint attempts yield zero persistent sentry damage/protected ore; no replacements reinforce roster. |
| 9. Cooperative clearance | **Source implemented; two-client engine observation required.** `Rules.lua`, `Server.lua`, all-client renderer. | Both contributors receive their own entitlement; outsider cannot inherit it; one user leaving/prestiging does not reset a friend's live attempt; late join reconstructs current state. |
| 10. Prestige and repeat run | **Source implemented.** `Profile.lua`, `Cards.lua`, `Server.lua`, prestige UI. | Exact milestone preview/confirmation, pending-offer block, +1 permanent drone once, all run modifiers reset, existing IDs/base intact, old-run requests fail; complete a second cycle. |
| 11. Compact readable UI/effects | **UI overhaul source implemented; device/engine checks remain.** `UILayout.lua`, `Interface.lua`, `CardView.lua`, `Client.lua`; effects in `Presentation.lua`, `SentryMotion.lua`, `Feedback.lua`; server supplies `MA_InAssault`. [Reference brief](../review/UI_REFERENCES.md). | Native safe content respected; HUD/focused modal coherent; offers compare in a row where space permits and scroll in one column on phones; complete target/effect/tradeoff/preview/stacking/expiry; 44-pixel action targets clear native movement controls; availability reasons and pending states match authority; paid offer survives close/reopen; no text clipping, overlapping screens or world obstruction. Geometry tests are not visual/touch acceptance. |
| 12. Reproducible handoff | **Tooling implemented.** `tools/test.py`, `tools/release.py`, CI and `docs/review/`. | Relevant checks pass, final place reopened from disk, source commit clean/exact, ZIP includes new tracked docs, review log accurately states completed/unrun checks. |

## Practical sequence for a requested change

1. Read owner requirements and these system/map/card references. Inspect `git status` and the specific source paths before editing shared work.
2. Write a short implementation boundary: player-visible result, authoritative state touched, assets preserved, and how the result will be checked. Reuse existing modules and APIs.
3. For map/material work, establish coordinates and route clearances first. Apply a coherent palette and lighting pass next; then inspect from player height and combat/mining viewpoints. Update `map_reference.md` from the final code.
4. For a new card, define a concrete gameplay choice and its target/tradeoff, add data and capped stat math in `Cards.lua`, validation/migration support if required, the actual effect consumer in `Server.lua`, replicated effect data, and presentation in the client modules. Update both upgrade documents.
5. For UI changes, reuse `Interface` components and `CardView`; change safe-content geometry in `UILayout`. Keep offers, resolved targets, previews, eligibility and transactions server-owned. Preserve accurate preview/save labels, pending/retry feedback and the permanent/run distinction. Update the UI sections of the architecture and design references from final source.
6. For a profile change, define migration and failure behavior before a durable transaction. Never modify saved drone bases to bake in run buffs. Never repair uncertain load by saving a default profile.
7. Run the focused existing logic tests and applicable regression suite. Fix failures; do not count a mocked engine surface as a Studio result. `tests/ui-layout.spec.lua` exercises real geometry for safe bounds, control separation and scroll-reachable choices; text and native controls require direct engine inspection. For reversible cosmetic edits, prefer visual inspection over tests that merely mirror layout literals.
8. Review once for original behavior/server authority/persistence, then again for pacing/visuals/multiplayer. Address concrete findings before stamping the final build.
9. Generate/reopen the final place. Record exact evidence and limitations in the review log and build metadata. A final screenshot or test from an older intermediate build does not validate later edits.

## Remaining acceptance work

The source design is already integrated. Remaining product confidence comes from running the final build, particularly:

- Original-versus-current Studio comparison for flight, overhead mining, crystal growth, stages, break and recall at matching camera/scale.
- A full first-run and second-run walkthrough; measured first pack, first clear and first prestige times, with actual card picks. Existing deterministic progression models are estimates.
- Two clients plus a late join during growth, mining, sentry charge and reprint; no ghosts, stale beams, replayed rewards or outsider mining entitlement.
- Route walking and camera views after the latest world/atmosphere changes; original meshes, sounds and materials actually load with the test account.
- Safe-area HUD/menu layout at desktop, narrow phone and short landscape sizes; longest card copies and four-row stat previews; scrolling to every choice/confirmation; real touch controls and rotation. Check pack/select/prestige pending feedback, own-assault/station availability, paid-offer close/reopen and permanent/run tabs. Pure layout tests do not establish these engine results.
- Repeated lifecycle and a documented simultaneous visible drone/player count.
- Controlled production-like DataStore session/restart acceptance in a test namespace only when separately authorized. Preview persistence cannot prove this.

Track each as **executed/pass**, **executed/fail**, or **not executed + exact blocker** in [Studio acceptance](../STUDIO_ACCEPTANCE.md) / [validation](../review/VALIDATION.md). Continue available source review, logic work or build verification while an integration is unavailable.

## Focused follow-up improvements, not claimed as implemented

These are engineering/design follow-ups rather than hidden promised systems:

| Item | Reason and suggested boundary |
| --- | --- |
| Consolidate duplicated configuration | `Server.lua` still contains a hardcoded DataStore namespace and several timing/range constants also represented in `Config.lua`. Move tunable duplicates deliberately, preserving existing namespace and behavior; test consumers. |
| Measure upgrade choices | Record actual first-run offers/picks and compare resulting clear/mining time. Increase mechanically distinct choices only when they remain useful within current field geometry and caps. |
| Evaluate target-priority commands | Current drones auto-select nearest live turret. Add manual priority only if playtests show the existing flank/retreat/build decisions need it; validate owner/field/roster and replicate intent. This is not current behavior. |
| Establish supported fleet population | Run repeated sessions at increasing visible fleets/players, profile effect/viewmodel cost, then choose rendering budgets without deleting permanent ownership. |
| Maintain generated reference checks | If tuning frequently changes, derive card/field documentation from source or add a focused consistency check. Do not create a second manually maintained executable design table. |

No follow-up authorizes publication, new monetization, a second experience or replacement of the original assets.
