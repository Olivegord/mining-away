# Laser reference and review — November 4

## Reference analysis

Source: owner-supplied `/Users/sorenwidman/Downloads/sailent_sfx_7681643165253717261.mp4`. Local study frames are in `build/reference-beam-study/`; times below are approximate, sampled every 0.25 seconds. The outro starts around 8.5 seconds.

| Clip time | Dominant action | Layer relationship |
| --- | --- | --- |
| 0.25–2.75 s | Small origin core, inward curved streaks, lifting debris | Bright moving heads lead thin tails; the core remains small. |
| 3.0–4.25 s | Brief expansion and contraction of the color-distortion lens | The circle replaces the small-core silhouette at the emitter. It is not a permanent impact bubble. |
| About 4.5 s | Release flash | Charging silhouette yields to the beam. |
| 4.75–7.0 s | Broad tapered beam, dark interiors, bright violet/white boundaries | Smoke, electrical branches and swept shapes support the directional beam. |
| About 7.25–8.25 s | Rapid needle collapse, residual wisps | Main energy ends before the final particles. |

The rejected first local pass incorrectly combined all layers continuously around the orbital impact. It was removed. The revision uses an authoritative normalized charge window: inflow first; lens only from 64% through 95%; peak at 76%; contraction; no lens or rich charge rig during firing or aftermath. Ordinary mining rigs use their actual moving emitter. The orbital charge is at its sky source, while its red ground marker remains a targeting cue.

## Native implementation

Glass plus a Highlight reproduces scene-color distortion in the current desktop Studio renderer. A controlled native comparison verified it; ordinary tinted Glass did not reproduce the reference. One surface changes from clear distortion to chromatic distortion and back, avoiding nested transparent shells hiding each other. The Glass/Highlight above-one transparency technique is engine-dependent, not a supported cross-device shader contract. It is described in the creator's [Glass distortion experiment](https://devforum.roblox.com/t/hidden-glass-distortion-effect-with-real-time-reflections-tutorial/2338789). [Roblox materials documentation](https://create.roblox.com/docs/parts/materials) says Glass refraction is not supported on mobile. Mobile and low-quality visual acceptance remain unverified.

The larger choreography has at most four simultaneous leases, within the existing 64 total / 12 detailed beam caps. Reduced-effects settings and distance culling release the extra geometry. Hidden curves skip pose writes, particle emission never catches up missed frames, and ordinary mining no longer hides and re-enables its entire beam every frame. Gameplay time, damage and persistent identity remain server-owned.

Mining stations are three studs higher (7.2 minimum height, 5 studs of clearance above the original rock volume). Most following drones receive a runtime 1.8-stud lift; Courier and Breaker retain their functional low positions. Permanent traits are not rewritten. The default preview crew is 12 drones / 6 miners; the explicit all-types developer loadout and purchases still expose the optional specialists. Production still starts with one permanent drone.

## Verification

- Production beam, healing, energy and smooth-timeline suites pass with API doubles; these are not native or multiplayer evidence.
- Specialist/logistics ownership, all-types behavior, curated preview loadout and lifecycle suites pass.
- Deterministic full-crew performance suite passes, retaining its historical baseline and explicitly selecting all 15 roles for stress coverage. Continuous specialist visual writes: 72,902 versus 90,492 historical, unchanged from the pre-reference 72,902 after excluding the rock-centered Singularity well from emitter-only lenses. These counts are not FPS.
- Native source-only installation verifies all seven allowlisted Sources and 39 untouched scripts. Binary comparison preserves every non-Source chunk.
- Native recall cleanup returned zero charge lenses and zero rich rigs after five seconds.
- Native unrecorded timing sample: 1,196 frames, 16.72 ms average (59.8 FPS), 24.41 ms p95, 35.73 ms maximum. The first recording averaged 16.96 ms across 2,360 frames; 581 frames with a visible lens averaged 16.70 ms. Occasional longer frames remain; these are single-machine Studio measurements, not a universal no-lag guarantee.
- Roblox MicroProfiler sampled 39 complete frames: client script scopes totaled 2.59 ms median / 5.37 ms p95 per sampled frame, before the final hide/show and gravity-well exclusions. Capture range: frame 4406 (absolute 2779739) through 4444 (absolute 2779777). Inclusive script scope totals are not GPU time.

Final native recording and measured frame data are stored with the review artifacts in `build/`. The video is actual Studio gameplay with a presentation camera, not a synthetic animation or offline mock. It is captured from the Studio window alone. Visual acceptance belongs to the owner; native multiplayer and low-end hardware remain untested.

Final recording: `build/completed-lasers.mp4`, 44.1 seconds, native window capture at 30 FPS. Final-build render sampling during capture: 2,367 frames, 16.90 ms mean (59.2 FPS), 24.72 ms p95, 50.03 ms maximum. The basic miner’s chromatic charge is visible around 20.2 seconds, at its emitter, followed by release. Native cleanup again returned zero lens/charge rigs with the 12-drone crew.

Canonical native SHA-256: `fe7a9c0b4ea8f7224ed66ea67f82e3383ff3a96112d4c56d20693f9f89a1c8ed`. All seven Sources match the working source payload; only two native Source chunks differ from the installed PR #4 baseline.
