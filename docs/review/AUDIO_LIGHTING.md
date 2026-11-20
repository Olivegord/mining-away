# Drone Blower revolution — Toolbox audio and daylight

October 31, 2026. Existing place **136098934779395**, branch `codex/restore-feel-prestige`.

## Audio

The client rotates three APM tracks with two-second fades at normal playback speed. Music starts quietly at 0.14 group volume, drops to 0.085 in menus and 0.055 during combat, and never delays input or drone rendering while loading. Missing tracks are skipped; if none load the game stays quiet and can recover when a track becomes available. The original unused soundtrack candidates remain preserved in ServerStorage.

The added clips were found through Studio's Toolbox/Creator Store search. MarketplaceService metadata confirmed each asset ID, name, Audio type and creator. The source uses the IDs directly, following Roblox's documented [Creator Store audio workflow](https://create.roblox.com/docs/audio/assets). No third-party model scripts are imported.

| Clip | Creator | Use |
| --- | --- | --- |
| [Bossa Me (a), 1837768517](https://create.roblox.com/store/asset/1837768517) | APMOfficial | Background playlist |
| [Heavenly Fields, 1835928951](https://create.roblox.com/store/asset/1835928951) | APMOfficial | Background playlist; preserved existing candidate |
| [The City, 1835929012](https://create.roblox.com/store/asset/1835929012) | APMOfficial | Background playlist; preserved existing candidate |
| [Synth Fx Small Synth Servos Click Short Bursts, 9126066421](https://create.roblox.com/store/asset/9126066421) | ProSoundEffects | Buttons, confirmed pack opening, sentry wake/ignition |
| [arcade_coin_get, 71803180596130](https://create.roblox.com/store/asset/71803180596130) | g_v8 | Server-confirmed sale |
| [UI synth_success, 91735091370012](https://create.roblox.com/store/asset/91735091370012) | WillShockwave | Confirmed card selection and prestige |
| [Rock Impacts Throwing Stones At A Big Rock 1, 9125871199](https://create.roblox.com/store/asset/9125871199) | ProSoundEffects | Percussion mining, drone hits/destruction, sentry landing |

The existing `ReplicatedStorage.CrystalSounds` bank is untouched. Crystal stage pops, break layers and pitch variation retain their current implementation and levels. They now share the optional Effects mute group. The fleet menu contains **Music: on/off** and **Effects: on/off**, keeping permanent HUD space available for gameplay. These settings last for the current client session.

Action audio has per-cue cooldowns, a 12-voice limit, local distance culling and spatial attenuation. Music is two-dimensional; world impacts use temporary invisible non-colliding anchors with bounded cleanup. Failed action loads use existing shipped Roblox clips. Music has no generic fallback. Destroying the HUD stops the soundtrack and its background task. Original crystal audio retains its own bounded voice pool.

Pack/card/prestige/sale accents compare confirmed replicated profile snapshots. Joining or reconnecting is silent, and an optimistic button press cannot play a reward accent. A pending transaction is held until confirmation, including when an intermediate snapshot already contains the resulting data.

## Lighting and Roblox materials

`Daylight.apply()` preserves the existing sky and effect instances. It changes dawn to 13:30 daylight, removes the yellow color shift, keeps neutral shadow fill, reduces environment specular to 0.12, and uses the engine's Soft lighting style when supported. Bloom, depth-of-field blur, sun rays and blur are disabled; mild neutral color correction and light distance atmosphere keep the small original workers and mineral shapes readable. A deferred startup application handles the preserved legacy script's one-time dawn setting.

The concurrent backpack/swarm update supplies the native material pass: Concrete, Pavement, DiamondPlate and Metal for working surfaces/machines; studded Plastic trim; distinct rough mineral beds. No replacement map, AI textures, new scenery pack or altered original drone/crystal/pyramid mesh is introduced by this audio/lighting pass. See [backpack/swarm review](BACKPACK_SWARM.md).

## Integration and review limits

`Daylight` is bundled into the existing authoritative controller and `Soundscape` into the existing client controller. The existing seven-path Source allowlist is unchanged. The immutable captured `.rbxl` retains every non-Source chunk and all backup scripts; runtime configuration supplies the new lighting and sounds. No source asset is overwritten and nothing is published to Roblox.

The “Update map, drones, and UI” chat owns the single combined Studio Source integration, commit, release build and draft PR update, under the owner's explicit coordination authorization. This chat's additional pre-edit backup is `build/audio-lighting/studio-source-snapshot.json`.

Source review covers original feel, authority, confirmed rewards and profile compatibility, followed by mix density, cleanup, loading failures and observer behavior. Syntax compilation is a static check. No game tests, new Studio Play sessions, listening auditions or multiplayer playtests were performed. Asset availability in a published server, final loudness/timing, final engine motion, low/high graphics, mobile and multiplayer remain **NOT VERIFIED** until the owner tests the combined candidate. An edit-mode lighting screenshot, if captured, is only a lighting preview and does not validate gameplay or runtime rendering.
