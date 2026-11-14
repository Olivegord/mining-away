# Reference-driven beam overhaul

November 4, 2026. Source implementation for the existing **Drone Blower revolution**, place **136098934779395**. Visual acceptance: **UNVERIFIED**.

## Revision and delivery

- Base: `eaf65eb5b10fe7da924daaaa7cd07f9d43846ee1`, `codex/rework-special-drones`. Fresh remote refs and all three existing PRs were inspected before editing. This base contains the seven-specialist rework and shared client animation; those systems were not recreated.
- Branch: `codex/reference-beam-overhaul`. The final commit is recorded in the PR and the delivery sidecar `build/beam-overhaul-validation.json`, which also records the payload's SHA-256. The standard seven-Source payload format itself has no commit field; generate it after committing and keep its sidecar with it.
- Install artifact: `build/source-payload.json`, containing exactly the existing seven allowlisted Sources. `BeamVFX` is bundled into the existing client Source; it does not add an eighth install path.
- The actual `build/Drone Blower revolution - editable workspace.rbxl` is absent here. No substitute native file was created, opened, refreshed, or packaged. Old generated files already present in the cloud seed are not this delivery.
- No Roblox publication, main merge, new experience, Studio Play start, or authored geometry changes.

## Complete beam inventory

| Family | Previous presentation | Implemented presentation |
| --- | --- | --- |
| Cutter / ordinary laser | Uniform transparent cylinder core and halo | Narrow original physical core plus tapered colored ribbon, bright needle, broken outer strip, rim and normally blended dark seam. Quiet sustain; two hooked arcs during charge/ignition. Original three breathing source spheres remain. |
| Percussion | Pulsing cylinder | Broader tapered strike, short four-point ignition keyed to the existing pulse timestamp, compact charge hooks and controlled recoil scale. |
| Resonance | Colored cylinder | Narrow center and paired longitudinal curved wave filaments, fixed at both contacts. Slower charge, gentler silhouette. |
| Drone combat | Straight cylinder layers | Sharp short spear, white needle, brief cardinal star and source hooks. Mining and combat retain their own styles. |
| Fork / chain branches | One thin cylinder | Two tapered layers with no orbit/star detail. Existing fair verification and temporary proc hold remain authoritative for visibility. |
| Pyramid sentry | Thin telegraph and white Beam core | Original thin warning line retained, with hot tapered firing core and a short ignition star at the moving rendered eye. |
| Medic repair | Single cylinder between rendered emitters | Restrained green taper and paired gentle streams. Actual charge fraction drives width and source anticipation. Contact still depends on the existing four-ray shared verification loop. |
| Courier pickup | Thin gold cylinder | Tapered gold tether and two short ticks travelling toward the actual parcel mount. The physical parcel, latch, launch motion and original source spheres remain. |
| Short role / scrap-related shot receipts | One fading rectangular Part | Fast lance expansion, controlled contraction, a separate thin trace, one residual four-point star and two small flecks with decelerating drift and shrink. |
| Heal / Charger role bursts | Same rectangular Part | Quiet green repair vocabulary versus sharp orange combat vocabulary. Their authoritative events and damage/healing times remain unchanged. |
| Orbital relay | One fading vertical cylinder | Blue tapered resonance lance and fine wave filaments, with a separately timed residual star/flecks. |
| Orbital charge | Red target disk | Disk retained; elevated dark charged core, two tightening hooked ribbons, angular cuts, compression, then a compact four-point pre-ignition. Uses the real 1.4-second gadget charge duration sent by the server. |
| Orbital strike | Physical white core/halo plus descending white/clear bands | Those physical layers and bands remain. Violet tapered outer body, white needle, dark longitudinal seam, broken strip, source hooks and an elevated release star add contrast. The release star is 2.5 studs above contact. |
| Orbital aftermath | Collapsing column and 312 local white motes | Existing independent 0.48-second column collapse and 4.4-second carrier lifetime retained. New geometry follows the same shutdown clock; it does not truncate the particle cylinder. |
| Gridcutter scan / six scoring lines | Thin rectangular lines | Sharp two-layer scanning and scoring lances, fixed to the existing swept face coordinates. Only the scanner may acquire secondary detail. The cube spill remains. |
| Halver shear edge | Thin rectangular seam | A crisp cyan layered lance across the existing jaw cut. Jaw motion, slabs and bounded damage remain. |
| Starforge three heat rays | Thin orange lines | Three tapered orange/white heat lances feeding the existing contained sun. Heat envelope and molten droplets remain. |
| Singularity containment | Segmented ring and inward chips | Original dark event horizon, ring and inward chips retained, with tightening violet hooks, angular cuts and a brief confirmed-impact glint. Smaller than orbital. |

Bubbler's glass capture, Frostbite's ice shell and Resonator's mechanical wave rings have no projected mining laser in this base. Their existing silhouettes and choreography are preserved. Scrap mini-miners' rods are physical chisels, explicitly not another laser; they remain mechanical tools. Breaker pressure waves, Cultivator seed particles, currency, flight trails and preserved disabled legacy beam templates were inspected and retain their separate jobs.

## Phase and attachment system

`src/BeamVFX.lua` owns reusable local geometry and styling. Curved Beams follow explicit attachment paths; attachment **X axes** define the Bézier tangents. Native tapered Beam triangles make the concave four-cardinal star, without an uploaded sprite, flipbook, soft particle substitute, or opaque texture card.

Charge evaluates elapsed authoritative time: gather through 76% of warmup, compress from 76–90%, then a restrained pre-ignition through the real release. These fractions are an adaptation, not measured reference frame boundaries. There is no extra gameplay delay. Gadget charge receipts now include their existing authoritative duration.

Ordinary work retains `Feedback.beamStep` unchanged: the original two-second eased width ramp and 0.2-second hide. New ribbons use that same envelope; the original thin physical core still follows it. Primary rays remain vertically aligned for mining and terminate at the verified, rendered shrinking surface. Fork/chain verification, its 12-ray per-frame budget, fair scheduling and stale-contact expiration are unchanged. New visual layers perform no queries.

Short role bursts expand over at most 35 ms of their existing duration, contract during the final 38%, then stop the main body. A fine trace ends over 140 ms; the small star and flecks shrink over the style's 0.45–0.8-second recovery. Generic Beam receipts remain available for that visual tail. Late observers evaluate the original timestamp and do not replay ignition. Future receipts wait for their timestamp; partial receipts still wait for complete required fields.

Orbital uses its original start time for release, rather than replaying a flash on each contact update. Stale contact streams hide its physical beam, stop new particle emission and hide the new layers; fresh contacts resume them. Already emitted particles finish independently. Mining pauses likewise stop emission without clearing the existing tail; a retired drone life can still invalidate its particles.

The apparent distortion is an approximation using curved silhouettes, dark cuts and broken outer strips. There is no scene refraction, lighting inversion, FOV change or new full-screen flash. Bloom intensity is unchanged. Essential beam centers remain readable without the new detail.

## Bounds and fallback

- At most 64 beam rigs, with four slots reserved for orbital/gravity effects. At most 12 detailed rigs, with two detail slots reserved for those major effects.
- A base rig has one invisible non-queryable carrier, two attachments and two Beams. A detailed rig adds four paths and four star rays, with bounded attachments and an optional dark core.
- Secondary detail releases on distance culling, reduced effects, interruption and parent destruction. Ordinary detail distance is 110 studs; orbital permits 340. Original work/courier/repair/fragment limits remain.
- ReducedMotion / MA_ReducedMotion and ReducedEffects / MA_ReducedEffects disable curves and ignition detail while preserving a clear primary center and contact.
- Body opacity profiles are precomputed and reused. Animation evaluates time at render cadence; it does not advance by frame count. No server visual transforms or per-frame VFX remotes were added.
- Original simple primary geometry provides an overload fallback for mining, branches, sentries, repair, courier and role shots. New specialist lances retain their old line if no rig slot is available. Orbital retains its physical column and band Beam.

## Source and asset changes

Core implementation: `BeamVFX`, `Presentation`, `WorkEffects`, `RoleVisuals`, `RoleEffectView`, `Client`, and specialist beam calls in `DroneFX`. `DroneAbilities` only includes the already-established charge duration in a cosmetic event; `DroneRoleEffects` adds that duration to receipts and keeps generic Beam receipts long enough for their tail.

No economy, damage formula, server hit timing, health, rewards, cards, persistent profile, specialist work budget, map, drone hardware, audio mix or original asset is changed. No proprietary reference assets were copied. No new texture upload is required; existing built-in particle textures remain.

The client bundler and affected fixture builders load `BeamVFX` before its consumers. CI now runs beam, energy and shared-animation suites. New tests execute production code, including the actual client healing loop. The performance counter now includes Beam width, curve and enablement writes, rather than counting only older Part properties.

## Validation

Official Luau **0.744**, matching CI, was downloaded and verified against SHA-256 `6506f0852c623aaffcb28494aac16c26dc04a269ea0e16cc0aafc8c8ac79f3ec`. Luau 0.745 was also used during development.

Passed:

```sh
python3 tools/test_beam_vfx.py /tmp/beam-luau-0744
python3 tools/test_energy_effects.py /tmp/beam-luau-0744
python3 tools/test_smooth_animation.py /tmp/beam-luau-0744
python3 tools/test_special_logistics.py /tmp/beam-luau-0744
python3 tools/test_refinement_client.py /tmp/beam-luau-0744
python3 tools/test_gadgets.py /tmp/beam-luau-0744
python3 tools/test_mining_flight.py /tmp/beam-luau-0744
python3 tools/test_audio.py /tmp/beam-luau-0744
python3 tools/test_shops.py /tmp/beam-luau-0744
python3 tools/test_performance.py /tmp/beam-luau-0744
python3 tests/single-game.spec.py
```

The beam suite includes 11 production lifecycle/style checks plus the actual healing loop: 30/60/144 FPS phase agreement, compression, independent tails, no late ignition replay, future/partial receipts, 64/12 caps and priority reserves, distance release, reduced effects, parent removal, repeated activation, real mining envelope/surface/life behavior, stale orbital emission, and courier transfer cleanup. Existing suites cover specialist cancellation, depletion, repeated cycles, distance return, shared motion, persistence and server authority. All 48 source modules and both production bundles compile. Single-game tests pass 16 temporary preservation/consolidation cases; they do not imply the owner's actual native file was installed.

The performance fixture counts 72,902 selected visual property writes for the seven-specialist workload at 144 callbacks/s, including new Beam width/curve/enablement writes, versus 90,492 in its historical `09e8929` baseline. Existing server checks remain at 255 idle proxy moves, 120 orbital burn rays and 126 specialist monitoring rays in their defined workloads. These are deterministic API-double counts, **not** measured GPU work, frame times, Studio FPS or a claim of improvement over the immediate base.

Failed, reproduced before editing:

```sh
python3 tools/test.py /tmp/beam-luau-0744
```

The aggregate stops at `tests/ui_text.spec.py`: the existing 11px Backpack label violates its 16px guard. The unchanged base reproduces that failure. Later aggregate stages are not reported as passed. Focused suites above were run independently.

Not run: native asset loading for this revision, Studio Edit preview, Studio gameplay, low/high graphics comparison, real two-client/late-join sessions, measured FPS, final visual approval or a complete source-video comparison. No claim that these checks passed follows from compilation or API doubles.

## Reference evidence and comparison gate

The three supplied TikTok pages loaded and their captions/player metadata were read. Their normal player media URLs returned HTTP 403; no video was decoded or inspected frame by frame. A normal Chromium attempt also failed certificate validation. Automatic approval review rejected registering the environment proxy certificate in the browser's persistent NSS trust store because that changes browser trust. No certificate trust change or TLS-verification bypass was made. The two `libfile_…` images are not attached here and no Library materialization tool is available; their pixels were not inspected.

Official [Beam API](https://create.roblox.com/docs/reference/engine/classes/Beam), [ParticleEmitter API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter), [beam tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/laser-traps-with-beams), [trails](https://create.roblox.com/docs/effects/trails), [post-processing](https://create.roblox.com/docs/environment/post-processing-effects) and [performance guidance](https://create.roblox.com/docs/performance-optimization/improve) were fetched and consulted. The Riot VFX landing page loaded; linked videos/tutorials were not fully watched. Beam control-point axes, normal versus additive blending, sequence/segment requirements, independent particle lifetime and transparent overdraw informed the implementation.

The brief's recorded observations remain the motion-study basis: A's dark orb/hooks/sharp release, B's contracting lances and separate aftermath, and C's concave four-point ignition. Attribution remains @sailent.sfx for the posted sound-design references; visual authorship is not asserted.

The owner explicitly requested comparing the result with the videos and revising if the references are substantially better. That gate is **pending**, and has not been replaced by a code-quality verdict. Without native renders and playable reference footage, this implementation cannot honestly earn a visual PASS. The independent final art review remains pending too.

## Exact next native steps

1. In the same local repository, obtain this PR's exact committed revision. Verify Studio is showing **`build/Drone Blower revolution - editable workspace.rbxl`** for the existing game. Install the seven Source payload into that same document using the single-game workflow and the exact installed baseline. Preserve authored geometry and backup scripts.
2. Keep Play stopped under the current scope. `tools/test_beam_vfx.py` generates `build/beam-vfx-edit-preview.lua`: paste it into the stopped canonical document's Command Bar for a 24-second temporary native component preview. It creates only `MiningAwayBeamReview`, keeps the camera/lighting, cleans itself up and does not install Sources. Do not save while it exists. This is a component preview, not proof of full-game contact or multiplayer.
3. Obtain directly playable copies of references A/B/C or normal browser playback, and inspect the specific first effects. Capture native before/after at matching gameplay scale: quiet charge, compression, ignition, sustain, shutdown and complete aftermath for every inventory row. Report exact commit, viewport, graphics and time for each capture.
4. Judge silhouette and motion against the references: readable hooks and hard gaps, a dark center that survives bloom, a crisp concave star, decisive release, colored tapered body and independently drifting tail. Reject weak/generic forms and revise the actual renderer, then capture again. Extra particle density or brighter bloom cannot substitute for that comparison.
5. With permission for the later gameplay acceptance pass, inspect moving/shrinking contacts, walls, recall, target/drone destruction, respawn, crowds and two real observers including a late join. Sweep camera angles, low/high graphics, bloom off and reduced effects. Record actual frame times. A normal-speed recording and independent reviewer are required before visual approval.

Implementation review one checked lifecycle, original envelopes, authority and attachments. Review two checked hierarchy, style differences, crowd fallback and surface clearance; it led to reserved major-effect slots, an elevated orbital star, separate star attachment centers, a quiet Cutter sustain and a stronger stale-contact stop. Those source reviews do not waive the missing native gate.
