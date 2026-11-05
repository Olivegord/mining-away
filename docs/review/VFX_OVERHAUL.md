# VFX overhaul — November 4, 2026

Broad client presentation pass following `VFX_INSTRUCTIONS.md`, on top of `e0bec2bd82fe2fcb2c3dce2fc98f625dd061245f`. The restored regular flash, its hard colors and 80 ms ignition overlap are retained. No server gameplay, progression, audio asset, authored model or UI source changed.

## Result

- Shared four-curve pressure geometry replaces growing neon balls for role pulses and segmented polygon rings on Singularity, Frostbite and Resonator. Expansion launches fast and brakes; contracting telegraphs accelerate into contact. Circles stay in their physical plane.
- Specialist charge styles now differ in motion and silhouette: separated star flashes, a compressed ignition slit, and restrained coil light. All retain immediate inward motion. This does not reinstate the rejected repeated regular-laser color pops.
- Bubbler stretches with pressure and breaks sooner; chips remain hidden until its bubble pops. Halver accelerates into its shear. Gridcutter's cubes separate quickly before falling. Singularity extracts chips along cached force paths without rotating its ring. Frostbite's wave releases sharply; Resonator converges then releases staggered waves only after the server confirms contact. Starforge retains its furnace silhouette and receives the shared fine beam flow.
- Ordinary, combat, sentry, lance and heat beams carry small tapered flow marks with invisible wrap boundaries. Electrical dust aligns to its motion while preserving the six saturated colors, gravity-free paths and independent lifetime. Regular smoke remains beam-blue.
- Contact sparks, utility bursts and fracture smoke use faster initial impulses with substantially stronger drag. Bright particles are smaller and less frequent. Actual authored rock chunks retain gravity. Nozzle glows are quieter, flight trails shorter, and breaker exhaust clears sooner.
- Reduced-effects handling now covers work particles, repair charge detail, courier/flight trails, specialist geometry and role waves. Essential beam/parcel state remains available. Curved role waves have a 24-rig limit; specialist effects have eight slots in addition to the existing part budget. Cached rings explicitly hide their Beams.

## Behavior and parity review

All seven saved allowlisted Sources were compared exactly with the baseline before installation. Only the client bundle changed. The saved server bundle, configuration, HUD, crystal audio, role receipts and discoveries still match the baseline, preserving original motion, server timing, damage, resource progression, offers and persistence. Every unrelated/backup script remained unchanged. Other game chats were idle/not loaded at coordination discovery, so none were awakened.

The direct Studio installation checked exact old module text, held the complete previous client Source for a concurrent-edit guard, and verified the installed Source. HTTP installation was unavailable because the MCP connection lacks Network capability; no permission settings were changed. The selected window was verified as the existing `build/DRONE_GAME.rbxl`. No publication or competing playable was created.

## Presentation, pacing and observer review

No charge, impact or recovery gameplay duration was changed. New trajectories are absolute timestamp samples rather than accumulated per-frame displacement. Role fronts expire from their authoritative event time; old receipts do not restart a fresh front. Specialist extraction remains attached to confirmed chunk damage. Fine beam packets fade at both ends of their cycle, and the six original dust colors remain discrete.

The supplied reference was opened at normal playback speed and sampled at 0.2-second intervals. The implementation follows its inward lead, brief contrast event, decisive release and overlapping tails without copying its large debris field into this game's compact fleet.

## Verification

Passed with production Luau and API doubles:

- `python3 tools/test_beam_vfx.py`: 22 beam behavior checks, all startup/repair checks, arbitrary physical-plane geometry, specialist flash gaps, client/server compilation.
- `python3 tools/test_special_logistics.py /tmp/mining-away-luau`: domain/server/preview ownership tests, all seven specialist lifecycles and frame-rate checks, cached curved-wave shutdown, eight-slot crowd bound, original hardware articulation.
- `python3 tools/test_energy_effects.py`: eight energy/fragment checks, updated for fast impulse plus strong drag and complete tails.
- `python3 tools/test_smooth_animation.py`: authoritative observer timing and cleanup, continuous planar expansion at 30/60/144 FPS, receipt readiness, stale-cue suppression, 24-front cap and teardown.
- `git diff --check`.

Native Studio: the six existing home stations ran through repeated cycles. A 16-second render sample observed 681 frames, at most 157 preview Parts and 50 enabled preview Beams. Those are scene observations during recording, not a performance benchmark. The recording contains 461 frames over approximately 17 seconds. No game-script runtime error was observed. Final reduced-effects toggle verification observed 42 enabled preview Beams before, zero while reduced, and 28 after resumption (different cycle phases).

`build/vfx-overhaul-showcase.mp4` records the normal-effects pass before the final reduced-effects/budget guards; those guards do not change its normal appearance. The recording is silent. Support/impact pulses were checked by production API-double tests; a supplemental native receipt-injection attempt was refused because requiring the server module needs MCP Network capability. It did not run. Native visual approval of those support cues, mobile/low-quality rendering, listening acceptance, multiplayer and fun remain unverified.

Final saved native SHA256: `4aa9e13b120fd83f9e004cf885937f3e3b827f25d7c2b2d48e600e109af9a452`. `build/vfx-overhaul-native.json` and `build/vfx-overhaul-payload.json` record exact saved Source hashes; all seven match. Studio remains running for owner review.

To reproduce the source refresh, retain the actual canonical native game and run `python3 tools/refresh_editable.py --previous-commit e0bec2bd82fe2fcb2c3dce2fc98f625dd061245f`. This accepts only the exact baseline or current allowlisted Sources and preserves native content; it cannot manufacture a replacement game. Restart the same Studio document to load an offline refresh. Never save a stale open document over it.
