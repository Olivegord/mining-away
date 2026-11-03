# Particle visibility correction

November 2, 2026. Existing Drone Blower revolution, place 136098934779395. This corrects the particles in source 768721e without changing mining authority, the map, original models, smasher timing, ownership or the card UI.

The owner reported that the requested particles with bloom were not visible. The failure was real: an actual Studio Client ContentProvider:PreloadAsync returned **AssetFetchStatus.Failure** for rbxasset://textures/particles/flare_main.dds. That file is absent from the installed Studio asset bundle. The earlier API-double tests checked the path string but could not fetch or render it; those tests missed this defect. Bloom itself was present and enabled (Intensity 1.25, Threshold 1.1, Size 32), so increasing the post effect alone would not restore the missing sprite.

The same Client returned **AssetFetchStatus.Success** for rbxasset://textures/ui/VR/circleWhite.png. Inspection of the installed PNG confirmed a plain antialiased white disc on transparent background. Every affected energy path—ordinary mining, breaks, grower, smasher, orbital, swarm and collectible glints—now uses it. Original particle templates and authored assets remain preserved.

A second native finding was Largeparticles.TimeScale = 0.2 in the template cloned by WorkEffects. Energy now uses fresh ParticleEmitters with explicit TimeScale 1, no flipbook, no attachment locking and zero velocity inheritance. Ordinary contact discs peak at 0.8 stud, with small size variation, additive emission, Brightness 6 and gravity; break discs peak at 1.05 stud. Swarm particles remain deliberately tiny. Existing emission/rig/burst caps remain. Nearby-player proximity also preserves work particles at distant camera zoom. Bloom settings were retained for this correction; the change does not globally raise world bloom.

Before the application became blocked, a real accepted Striker assignment produced visible round glowing energy after its existing live emitter was switched to the verified disc and full-speed particles. The [native preview](PARTICLE_TEXTURE_REPAIR_PREVIEW.png) records that actual mining session. This was a temporary live-emitter diagnostic, not a screenshot of every final tuned source path.

The corrected generated Sources were subsequently installed in Studio Edit with exact previous/current equality checks; three allowlisted Sources changed and all 39 unrelated scripts remained untouched. A macOS **Screen Time / Time Limit** dialog then blocked the native Save and final runtime review. The time restriction was not bypassed. The preserved native editable file was refreshed offline with exact prior-source guards, preserving its geometry, every non-Source chunk and unrelated/backup scripts. That is an offline saved artifact, not a successful native Save or final Play check. Final tuned density, bloom appearance, orbital interaction and multiplayer visibility remain unverified until Studio is available.

Validation:

- python3 tools/test_energy_effects.py /private/tmp/mining-away-luau: six production effect checks with API doubles, including fresh emitter configuration, readable size bounds, zoom-independent proximity and bounded cleanup. It generates build/energy-asset-check.lua from all four production texture paths.
- build/energy-asset-check.lua: run in a real Studio Client to assert actual texture-fetch success and inspect live energy emitters. This gate would reject the old missing path. It proves loading, while native screenshots establish appearance.
- python3 tools/test_audio.py /private/tmp/mining-away-luau: all source and controller compilation plus existing audio/contact/fragment regressions pass.
- The current gadget suite passes, including the actual contact renderer. Current shop/persistence and deterministic binary-preservation checks are recorded in build/particle-build-tests.txt.
- python3 tools/refresh_editable.py --previous-commit 768721e saves the guarded offline source refresh; python3 tools/release.py stamps the exact clean revision and both native-place hashes in build/revision.json.

Roblox documents additive LightEmission, Brightness with LightInfluence 0, texture loading and emitter properties in the [official ParticleEmitter reference](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter). No Roblox publication or new experience was performed.
