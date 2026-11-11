# Crystal Run: charge, split and reward

November 11, 2026. The owner described the break as something that “just does it.” The pass makes the last stretch of a cut signal what is about to happen, then separates the split, reward launch and landing so each can be read from the default camera.

[Riot's VFX style guide](https://nexus.leagueoflegends.com/wp-content/uploads/2017/10/VFX_Styleguide_final_public_hidpjqwx7lqyx0pjj3ss.pdf) prioritizes gameplay meaning and visual hierarchy. [Lin et al.](https://arxiv.org/abs/2208.06155) identify sound coherence, hit stop and camera control as likely contributors to impact feel in action games. Those findings suggest giving this break a compact pause, a clear directional release, and sound at the action that caused it. The pause affects the crystal presentation only. Mining jobs and the camera keep moving.

| Beat | What to look for |
| --- | --- |
| Mining laser | Four focusing vanes narrow toward a brighter emitter as the inward particles gather. The single hard color pop still overlaps the original thin beam. The base warmup and cut rate are unchanged. |
| Final cut | A near-empty rock warms as the beam works. A confirmed finish compresses it at its foot, holds the compressed pose for about 90 ms, then splits. The original rock crack and a low impact play on release. Nearby owners get one short camera recoil. |
| Reward | The gem starts 25 ms after the split. Three staggered glints and a chime mark the rise. The gem follows a tapered trail, lands once with a short skid and a clink, then sits still. A small glint can catch on its facets while it rests. |
| Field shapes | The original is the majority shape. Needle is a pointed, asymmetric prism. Crown has a wide, chipped top. Both retain mineral colors and the original footprint. Gem is a separate flatter, beveled cut. |
| Ramiel | The idle diamond turns toward the target and expands into a five-pointed blue glass star. The shape locks while the core brightens. One red beam fires from the center, and the glass returns to the diamond as the shot ends. Each pulse can remove up to 68% of a crystal’s mineable health and completion pays 35% extra ore. |
| Orbital | The targeting column appears first, with three marks converging on the selected rock. A wide purple sheath rises around the white beam and leaves a short afterglow. The owned drone burns its primary target for up to 1.25 seconds, can hit one nearby eligible crystal for 45% of its maximum health, then cools down for 14 seconds. Legacy tool timing remains separate. |

The Ramiel sequence follows the Operation Yashima shot around 2:58–3:04, reviewed in motion. It compresses the film's timing to fit the existing mining cycle. The break uses the original Mining Away RockBreak clip, with a second layer for weight and a separate short chime on the gem. [Evangelion 1.11 clip](https://www.bilibili.com/video/BV1ex411M7gj/?t=178) · [Rock breaking SFX](https://create.roblox.com/store/asset/7158347304) · [Gem chime](https://create.roblox.com/store/asset/9125644410)

The first prestige offer is unchanged. After the first prestige, one of the three choices is an unowned flagship until both are owned. The starter fleet, normal ore value, ownership, cargo receipts, and authored map remain intact. In a Studio Play session, use the crew controls to add a temporary Ramiel and Orbital. In the usual game loop, earn them through prestige.

## Revision record

| Gameplay revision | Shared Edit save | Changes recorded |
| --- | --- | --- |
| [8664954](https://github.com/Olivegord/mining-away/commit/86649541c7a927f64ab550723144f2cff8cb9231) | 184 | Added the laser focusing vanes, compression and split, stable gem trajectory, Needle and Crown shapes, and both permanent drones. |
| [b700519](https://github.com/Olivegord/mining-away/commit/b700519d5e560642cd3a60f13158376bf0cfddce) | 187 | Added the distinct hit stop, camera recoil, layered break sound and gem twinkles. Rebuilt Ramiel around the main beam attack seen in the moving footage. |

The shared Studio entry point is **DRONEREVOLUTION**, place **124078027733625**, universe **10774898335**. The canonical file is [DRONE_GAME.rbxl](../../build/DRONE_GAME.rbxl), with SHA-256 `e2be9561bd7a55f4ade9cfd7b60ed24bfbfaaf092900b60fc9ed6e2f5f653658`. Gameplay revision `b700519` is saved to shared Edit and unpublished to players.

## Verification

The single-client Ruby tests across these revisions observed the new crystal silhouettes, the held compression and split, the gem landing and resting pose, the screen recoil and sound playback, and confirmed Ramiel and Orbital strikes. The last Play test also caught the drone renderer resetting the visibility of Ramiel’s star. A detached Studio Edit check of the final correction verified that the five points stay visible through charge and release, then disappear as the body closes. Workshop, pickup, beam and contact clock checks passed. The final star correction has yet to run in a full Play session. The sound mix and multiplayer remain unverified.

For the visual check, pin a fresh Quartz or Ruby patch, watch a cutter on a nearly finished rock, and keep the camera on the drop through its first landing. Try both the original silhouette and a Needle or Crown. With the two flagships in Ruby or deeper, compare the prism's side shot with the vertical orbital warning and impact. Check whether the split still reads in a busy field with effects lowered. Enjoyment and the sound mix need an actual viewing/listening check.

## Gameplay recording follow-up

In the first gameplay clip, the break registered around 0:05, but small pink chips launched near the ground and read as more Ruby. The player and working drones partly covered the small drop. Ramiel's shot around 0:08 showed a quick opening and a nearly fixed star while the film has two reversals and separate front and back motion. The Orbit around 0:11 read as a straight vertical bar, with most of the 260-stud particle volume outside the viewport. Regular blue miners and the specialist tools had visibly different body scales in the same view.

### Ramiel's main shot

Reviewed consecutive timestamped playback samples from roughly 2:54.55 through 3:02. The effective sample spacing was about 0.07–0.13 seconds. The landmarks below are observed screen-space poses and lighting. The original rig curves, camera transform and depth of individual facets cannot be recovered exactly from one filmed view. The game keys separate rotation, reach, hinge angle and brightness tracks from those landmarks and uses shape-preserving cubic interpolation between them. [Operation Yashima playback](https://www.bilibili.com/video/BV1ex411M7gj/?t=174)

| Reference time | Observed motion |
| --- | --- |
| 2:54.59–2:55.22 | Diamond opens into a narrow flower, whips out, and reaches its first wide extension. |
| 2:55.33–2:55.75 | Outer blades turn back and draw inward while the front faces continue around the core. |
| 2:55.90–2:56.82 | Blades extend a second time, then the large silhouette briefly eases back. The smaller star remains readable as a separate layer. |
| 2:57.02–2:57.55 | Outer blades swing past one another and snap into the wide shooting shape. The inner facets continue rotating. |
| 2:57.83–2:59.30 | The shape settles while concentric light builds and the center shifts from dark red through pink. |
| 2:59.42–3:01.12 | Brightness climbs, hangs near the peak and kicks into the beam. The movie cuts away shortly after release. |

The normal game windup is 1.60 seconds inside the existing 2.80-second cycle, with the same damage and reward per shot. The confirmed hit draws one red beam with its own bright center. The firing pose holds through the beam's main body and closes after it. The idle visible hulls fit a longest dimension of about 2.65 studs, including Ramiel's closed diamond. The expanded firing pose still grows during the attack.

The split now throws eight bright faceted shards higher than the two large rock faces. A separate world-space carrier keeps warm sparks and dust alive past the split, and the gem glints are larger and staggered. The hit stop remains 90 ms. Rock feedback uses a 220 ms translation envelope with zero angular recoil and distance falloff. Cutter and projectile particles travel further from the contact point and fade over longer windows. Compactor press and ejection each emit a short burst on their existing cues. Orbital's wider sight and descending pressure rings lead into brighter ground contact. The beam leaves a 26-stud local column of embers and a second ground fallout burst.
