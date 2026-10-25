# Sentry animation pass — October 25, 2026

The original seven-mesh construct now has a deliberate idle patrol: sweep, observe,
hold, glance, return. The eye pitches slightly, occasionally blinks, and moves as
one assembly with its housing and secondary lens. Higher shell segments hover
and counter-turn in a staggered wave. Position-derived phases keep neighboring
sentries from performing identical motions together.

A live telegraph interrupts idle and acquires the frozen server aim. The eye
focuses, the shell extends, and the existing narrow two-layer threat beam and
ground cue remain legible. Shots compress the shell and kick the eye backward,
then settle into patrol. Damage produces a short damped flinch. Collapse starts
from the actual animated pose; reset reassembles the original pieces. A stale
`Aim` attribute cannot leave a sentry tracking its previous target indefinitely.

`src/SentryMotion.lua` contains the pure animation driver; `src/Presentation.lua`
applies its transforms to client-only copies. Transforms derive from original
frames each render, preventing accumulated drift. The eye components share one
pivot. The anchored plinth stays fixed. Original assets, server targeting, hit
tests, damage, encounter rules, rewards and persistent state retain their roles.
No new gameplay remotes, marketplace assets or permanent UI were introduced.

## Review 1: behavior and original-art parity

- Verified all seven authored construct meshes remain in the live viewmodel.
- Real Studio client inspection confirmed eye/housing alignment and a fixed base.
- Existing original drone/mining feel tests pass; this animation does not alter
  drone simulation or mining behavior.
- Charge uses server `FireAt`; shot and damage cues use authoritative snapshots.
  No transform is read back into server simulation.

## Review 2: timing, visuals and multiplayer boundaries

- Inspected before/after idle in the connected Studio Play session with a matched
  camera. The shell and eye visibly move; the glowing eye reads within the
  original ceramic construct. Blink is suppressed during charge and discharge.
- Exercised the normal Cobalt command in single-player Studio. A 240-sample
  observation recorded four server shots, 60 charging samples, 71 visible-beam
  samples, peak charge brightness 1.0988, and maximum eye/housing drift
  0.0000242 studs. The Studio console was empty after the test.
- `tests/sentry.studio.lua` exercised the production renderer with real Roblox
  Instances/CFrames and controlled snapshots: 24 assertions across 468 samples
  at simulated 30/60/144 FPS. Charge, layered beams, damage, duplicate-shot
  suppression, collapse, reassembly, silent late-join ruins and source immutability
  passed. Maximum socket drift was 0.0000551 studs; base drift was zero.
- Eleven standalone animation tests cover patrol continuity, independent phases,
  blink interruption, stale aim, shortest-arc turns, frame-rate convergence,
  release/recovery, dead-state suppression and long-running bounded poses.
- Controlled renderer samples are not measured rendering FPS or a two-client
  test. Real two-player/late-join synchronization and network latency remain
  unverified. The original-versus-repaired full mining video remains outside
  this focused animation pass.

## Reproduce

```sh
python3 tools/test.py /path/to/luau
python3 tests/binary.spec.py
python3 tests/geometry.spec.py
python3 tools/release.py
```

For the engine renderer test, install a temporary client ModuleScript named
`ReplicatedStorage.SentryReviewModules` containing
`module_bundle(('Feedback','SentryMotion','Presentation'))` from `tools/build.py`,
then `return {Presentation=Presentation}`. Execute `tests/sentry.studio.lua` in
Client context and remove the temporary ModuleScript. The fixture cleans up its
own models and effects. The reviewed live client was refreshed from source;
these tests did not restart, save over or publish the place.

The release is built from `assets/mining-away-base.rbxl` into
`build/Mining Away.rbxl`. `build/revision.json` identifies the exact source commit
and build checksum. The working folder also contains pre-existing/concurrent
map, card and documentation edits; they are preserved, and a release made while
they remain uncommitted is explicitly marked `source_dirty: true`. Its ZIP holds
the actual source snapshot. This is not a claim of a clean committed release.
