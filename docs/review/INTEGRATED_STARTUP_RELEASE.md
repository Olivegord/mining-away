# Integrated startup effects and direct beam release

The owner identified a second warmup in the November 4 gameplay recording: after the emitter circle finished, `Feedback.beamStep` still grew the active beam over two seconds. The active beam now begins at full width on its first authoritative firing frame. The additional visibility fade-in is also removed. Server charge duration, card modifiers, damage, contact validation and the existing 0.2-second stop fade remain authoritative and unchanged.

## Integration audit

GitHub returned four open draft PRs on November 4. PR #1 (`bdb76e2`) and #3 (`eaf65eb`) are ancestors of the current branch. PR #2 (`874b604`) is already present as `14fc896`, with the same stable patch ID. PR #4 (`1043bf6`) is present as `765a107`; its production sources match, with the local canonical-file naming correction retained in the build/release workflow. No draft PR requires another application.

The separate cloud chat **Add flashing star drone effect** completed commit `6deee8e9cc77fe2d2a44568e81e58a8579d1d399` without opening a PR or pushing it. Its recorded file diffs recover the complete `StartupFX.lua` and renderer tests. That task started from the obsolete `2dc18b0` prototype, so its old Server, Client, generated playable and build/release changes must not replace the current game.

The recovered renderer is integrated into the existing BeamVFX charge lifecycle: Bubbler and optional Starforge use cyan flashing stars, Halver uses amber ignition, Singularity and optional Resonator use violet coils, and the basic cutter retains the emitter Glass/color circle. These are actual mining roles with a replicated Warmup state; the support-only grower/healer and physical diving breaker do not use that laser phase. All use the existing replicated warmup timestamps. No extra 1.2-second server startup gate is imported. Each style replaces the rich charge decoration for that drone and shares its global four-rig limit, near-distance culling, reduced-effects opt-out and release/cancellation cleanup. Opacity sequences are cached to avoid allocation every frame.

## Reproduction and scope

Run `python3 tools/test_beam_vfx.py`, `/tmp/mining-away-luau/luau tests/feedback.spec.lua`, `python3 tools/test_energy_effects.py`, `python3 tools/test_smooth_animation.py`, `python3 tools/test_special_logistics.py /tmp/mining-away-luau`, `python3 tools/test_performance.py /tmp/mining-away-luau`, and `python3 tests/single-game.spec.py`.

Timing checks exercise actual production Feedback and Presentation, including the final circle sample followed by the first released frame, card-modified durations, late joins, target/life invalidation and stop fade. Recovered renderer checks cover three variants at 30/144 FPS and 200 interrupted charges. The shared cap is tested across mixed variants. These are API-double checks, not native visual or multiplayer acceptance. No Roblox publishing or main merge is performed.

## Native delivery

The canonical `build/DRONE_GAME.rbxl` was refreshed using its exact prior Sources, retaining every non-Source chunk and backup script. The final seven Sources match the working source payload. The open Studio document's complete client source was read back and compared to the final bundle. Native SHA-256: `3d2c7fc564afd0b5a82bee55ce2a9adf6adc914a9c37ee99fa505286b6232b7c`.

Studio started with the preserved 12-drone crew and no gameplay script errors. The Mac then locked, blocking visual playback/capture; the new native appearance and first-frame transition remain unverified. Play was stopped. The prior 59–60 FPS recording measures the preceding revision, not this one. Current deterministic performance checks retain 72,902 specialist visual writes and zero idle logistics work; these are not FPS measurements. A fresh native visual/performance check remains pending after unlock.
