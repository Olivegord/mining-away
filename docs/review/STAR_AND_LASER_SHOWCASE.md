# Reference choreography and stationary preview

This follows the owner's rejection of the first cloud startup renderer and the truncated regular-laser ending. The regular laser and Bubbler star are separate effects.

## Actual reference inspection

Decoded the supplied local videos with AVFoundation and inspected image sequences, including 50 ms intervals around both charge/release transitions. The source frames remain in ignored `build/star-reference-lead`, `build/star-reference-timing`, and `build/beam-release-reference`.

- Star clip `sailent_sfx_7669407009757777182.mp4`, first animation only: central four-point flashes around 0.50, 0.70, 0.90 and 1.10 seconds, with genuinely dark gaps. A broad blue/dark sweep begins around 1.30 seconds. By 1.50–1.60 seconds the same star silhouette is reused, much larger, above and beside the sweep. The clip holds this view for several seconds; that edited hold is not a gameplay charge extension. The second animation is excluded.
- Regular-laser clip `sailent_sfx_7681643165253717261.mp4`: the colored lens visibly contracts between 4.00 and 4.40 seconds, leaving a tiny origin. A strong flash occurs at 4.50–4.55; by 4.60 the broad laser is present. The implementation compresses this sequence into the server's existing charge duration, retaining the collapse and the flash/beam overlap.

## Implementation

`StartupFX` now flashes one central native four-point shape four times, then reuses it at two larger positions during a smooth sweeping burst. It no longer substitutes three continuously orbiting sparkle sprites for the charge cue. Coil uses curved, tapering dark ribbons with bright edges, a surge and inward snap, replacing the segmented wire helix. Shared maximum remains four nearby charge rigs; no tasks, remote calls or catch-up emissions are created by the phase sampler.

The regular lens shrinks to a point through the end of its charge. Its bright spherical core and curved shock front continue across the firing boundary rather than disappearing with the Glass rig. They are separate from Bubbler's four-point star. Mining beams render at 2.4× scale, with a brief 35% launch-pressure surge. A bounded upward hull recoil settles within 0.4 seconds; the contact emits one fresh-release burst rather than increasing continuous particle counts. The continuous Striker can bridge at most 150 ms of the known server charge deadline with a cosmetic full-width beam, only for a valid verified contact and an alive, unpaused charge. This does not modify the authoritative envelope, damage, rewards, work particles or sound; specialists cannot use the bridge. Expiry and cancellation immediately stop the prediction.

`LaserShowcase` places six original-asset drones and permanent display rocks beside the home apron: regular laser, Bubbler, spiral, combat laser, Halver and Gridcutter. It calls the same production BeamVFX, DroneFX, WorkEffects and SpecialDroneMotion code. 5.5-second cycles are staggered, use the ordinary 0.8-second charge, and leave only 0.2 seconds after the attack before recharging. They never change the rocks' health. Displays live outside the server world/resource registry, are not query targets, and cannot produce money or permanent fleet entries. Effects are released beyond 85 studs or under Reduced Effects/Motion and reconstructed at the current phase on return. Static models remain visible.

## Validation

- Production VFX suite: 16 behavioral checks, first-frame full width, lens contraction and uninterrupted launch flash, bounded prediction/cancellation, shared caps, moving contacts, cleanup, and native bundle compilation.
- Startup phase tests: four separate central flashes, reused stars at release, spatial/instance bounds at 30/144 FPS and 200 interrupted-charge cleanups.
- Energy suite: 8 checks. Feedback: 19 checks. Canonical native workflow: 16 checks. Existing deterministic gameplay/performance call-count reductions retained.
- These automated checks use API doubles and do not establish visual quality or multiplayer performance. Native footage and measured cleanup results are recorded below after inspection.

The canonical `.rbxl` is refreshed only in its seven allowlisted Sources. Authored geometry, all non-Source chunks and unrelated backup scripts remain preserved. No publishing or experience creation.

## Native review evidence

The actual Studio preview ran through seven repeated cycles with all six rock health values unchanged. Observed display descendants varied between 248 and 373, without monotonic growth. Leaving the area released every BeamVFX rig and the special-effect folder (139 static descendants remained); returning rebuilt the effects with all six rocks intact. The server reported zero preview objects and the same 12 gameplay preview-crew drones. Console contained no game errors. The final stronger effects use the same instance caps and add no emitters; a second recording covers the shortened loop.

Recorded `build/home-effects-preview-final.mp4` from only the canonical Studio window. This is native renderer evidence, not a multiplayer playtest or visual approval. The current background session runs at an almost exact 15 FPS (about 66.7 ms); the capture and attempted foreground sample share that limit. Foreground/device performance is consequently **not verified**. Automated and native cleanup checks support bounded allocation, not a universal no-lag claim.

The native source-only refresh SHA256 before the final commit is `86ddd714521961e4a125a4e6adad890c6411f97a3cbef6e8798ab0c5f7e02e6e`. Previous payload: `build/lasers-showcase-final-payload.json`; final payload: `build/weighted-showcase-payload.json`. Reproduce from this revision using `python3 tools/build.py` against the canonical editable file; a stale file requires its exact prior payload/commit, never a substitute place.

Final shortened-loop native sample: 48 snapshots, all six rocks healthy throughout, 259–428 display descendants. Live Studio client Source matched the production bundle exactly; a current-only canonical rebuild reported `changed: false` for all seven allowlisted Sources. No game console errors. Normal camera control was restored and the preview player was placed beside the display for owner inspection. The owner canceled further recording and will review directly in Studio.
