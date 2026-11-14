# Fast blue launch refinement

The owner rejected the floaty launch in cd21d85 and requested a short, strongly braked burst, a broad radial cone without gravity, matched blue effects, repeated shrink-only pulses, and small screen shake with sounds.

The disk now expands toward a 2.02-stud radius, reaches about 90% of its travel in 0.06 seconds, and fades within 0.26 seconds. The former radius was 3.78 studs with a 0.65-second tail. Fragments start with 24–32 studs/second radial speed and 11–15.4 studs/second axial speed, then lose momentum to strong drag. Cached lateral velocity kicks create electrical jitter; gravity is zero. They persist briefly in place after braking instead of falling. Smoke receives a stronger, shorter radial pressure impulse and higher drag without buoyancy.

Six lens pulses start at normalized charge progress 0.32, 0.51, 0.66, 0.78, 0.875 and 0.95. Each appears at its full size and only shrinks; each successive reset is smaller and its interval shorter. Shared beam-derived colors drive fragments, smoke and pulse tints. The existing above-one-transparency distortion uses the complementary mask input to produce the blue output hue; its chromatic refraction still depends on the native renderer and scene.

Quiet increasing-pitch pulse cues and short pressure/crackle release cues use the existing spatial Soundscape mixer, loaded assets, mute controls, range limits, cooldowns and voice budgets. The release requests a 0.028-stud maximum camera impulse before distance attenuation, through the existing camera restore/feedback path and reduced-motion opt-out. Visual charge receipts trigger each cue once; a late sample does not replay skipped pulses.

Validation:

- 22 production beam checks pass, including shrink-only monotonic intervals, decreasing resets, compact ring, cone width, fast initial impulse, near-zero late axial drift, common palette, one cue per pulse/release, independent tails, bounds and cleanup. Startup/repair, audio/contact and energy suites also pass. These are API-double checks, not visual or listening approval.
- The selected canonical Studio document matched the prior installed payload exactly before 14 client Source edits. All seven saved native Sources match the final working source. No other script or authored geometry was edited.
- Native Play sampled 678 frames over 11.5 seconds. The regular display's maximum ring radius was 2.0199 studs; fragments extended 1.7100 studs radially and 0.8983 studs down, confirming a broad compact cone rather than a falling column. Blue smoke and fragments were present. A native capture shows the blue/cyan charge beneath the regular emitter.
- All three new sound cues were loaded and playing, with nonzero measured PlaybackLoudness. This verifies engine playback, not a subjective listening assessment. Console was empty. Native multiplayer, mobile and owner visual/audio acceptance remain unverified.

Saved canonical native SHA256: `7274ed0584b6d020cf5a036bb57a9c518b3c0e7bfd97c75edec9e5eed3a6d255`. Exact payload: `build/electric-blue-payload.json`. Studio is left running beside the home preview. No recording or publishing.
