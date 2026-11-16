# VFX instructions — owner feedback and implementation

## November 15 — reel from the moment of capture

The cable begins slack and shortens continuously from the grip. The cargo starts to slide as the flying Emptier takes up that slack. The shortening cable lifts the rock once it can no longer reach the ground. The standard clear test route begins lifting around two seconds. Seating still plays the mineral chips.

## November 15 — the rock trails on the ground before the reel

The grappling claw pulls the rock along a checked ground path behind the moving Emptier. The returning hull keeps turning and climbing during the two-second drag. The winch then draws the rock up to its moving cradle, where the existing seating chips play. The return arc keeps its exit velocity into regular delivery flight.

## November 15 — ground-only selection

The two-click preview still expands on the ground and highlights the stones inside it. Confirmation flashes the rocks and leaves the full footprint visible after the floor wash fades. The owner removed the custom hovering cursor, selection walls and wall particles, superseding the older selection effects below.

## November 14 — one continuous reel and a crystal-colored seating impact

A visible Roblox RopeConstraint follows the claw and hull. The approach and reel position the endpoints on the render clock so a physics handoff cannot tug them away from the visible drone. The confirmed grab starts the reel from the last drawn claw pose and carries the ore's resting rotation into the cradle. A small burst samples the mineral color at seating. It lasts up to 1.2 seconds and survives rope cleanup. Needler and Ballcaster load vertically and fire at the rock from overhead. Their original shot timing and flight recoil remain. Cut selection walls to two thirds of their former height while keeping their flash, visible floor, and edge sparks.

## November 14 — flash the selected rocks and leave the walls on the pin

The cursor uses a thin outline. On click, one white pulse drives the floor fill and the visible rocks whose authored centers sit inside that field and square. The accepted pin alone owns the full walls and border. Mining outlines share the same rock Highlight and keep pulsing independently. Walls rise on a fast fourth-power ease, stay bright for 0.12 seconds, then fade linearly for 0.46 seconds to a visible idle level, including up close. The upward edge burst lasts up to 1.24 seconds. Reduced Flashing softens the peak; Reduced Motion shows the full wall height immediately and skips the burst, and Reduced Effects also skips the burst. This supersedes the hover fill and zero visibility at close distance in the older entries.

## November 14 — grappling rope and winch

The fly-through pickup lowers the claw on a visible RopeConstraint. At the confirmed grab, the rock starts stationary on the same payload as the claw. The winch pulls them toward the moving body and the rope allows the payload to swing before it seats in the cradle.

## November 14 — swooping claw contact

The dotted pickup cue now tracks a moving approach. The claw closes as the drone passes the rock; a damped suspension reacts to capture and flight acceleration, swinging the grasped mineral with the same claw. The previous stationary scan and vertical grab are superseded.

## November 14 — gun recoil comes from flight

Needler and Ballcaster keep their loading motion, projectile timing and effects. The server pushes their actual hulls opposite the shot at release, with a stronger impulse for Ballcaster. Motion after release comes from momentum and the station controller. Do not restore the previous animated recoil of the hull and guns.

## November 14 — field click, attack and ore pickup cues

Pending field selection uses a faint surface fill. Click raises the fill immediately, then fades it over 0.27 seconds. The accepted square keeps a separate thin border; tall walls retain their distance fade. The only rock outlines added here indicate real attacks or recent damage, with a soft pulse and a steady reduced-motion/reduced-flashing setting. Emptiers stop about six studs above the claw's grab pose, show a short dotted line aimed at the ore, descend after the scan, close the claw at contact and lift before flying to the counter. The guide fades during descent and shares the existing per-drone cleanup. This leaves the existing mining beam and mineral effects in place.

## November 14 — correct compact finish inheritance and reject polygon spectrum

Owner screenshots reject the previous comparison and Diamond. Compact gems now take opacity, vertex alpha, material, texture, palette function and inclusion count/colors/sizes from their original description. Inclusions are remapped into the compact volume. Ruby's accidental .12 opacity is corrected to the original .72, with its 30 fixed specks restored. Violet's original .76 opacity and inclusions are restored; Quartz keeps its optical texture and blue/gold grains. Original non-Diamond cuts and appearances are unchanged by this correction.

The flat triangle spectrum and transparent cutouts are removed. Diamond retains broad external cutting planes but uses continuous spectral gradients, smoked body color, broad pale highlights and a deeper inset layer. Texture alpha is uniformly .94 so dark regions no longer appear as triangular holes. Both textured layers are Neon for the luminous spectral style, at .72 outer and .56 inset opacity. Detached rim ribbons are removed in both runtime and authored previews; localized flares remain. This is a stylized layered render, not physically simulated optics or a claimed photo match. Owner approval is pending.

Native checks now compare compact finishes directly to originals in addition to comparing each sample with its own drop template. This catches the material/opacity/palette/inclusion mismatch missed by the previous tests. Runtime screenshots show both Ruby cuts with the same red/peach body and white specks. No new Play session was started.

## November 14 — broad Diamond and compact comparison cuts

Diamond now uses twelve broad unequal cutting planes, a wider aspect, a thin SmoothPlastic outer surface and a separated reflective Glass inset with outward face normals. Native component inspection showed a Glass outer surface hiding the Glass inset, so the outer surface deliberately uses SmoothPlastic. The spectrum is a fixed straight-edged color field with clear dark windows, not noisy patches or eight abruptly swapped camera-angle patterns. Rims remain opaque and back faces culled. This is a stylized approximation, not physically simulated dispersion; the latest render still has a graphic geometric appearance and is not owner-approved as a photo match.

Amber, Quartz, Ruby and Violet receive stronger diagonal gradients while keeping their existing geometry. The second row has five 12-face rhombic compact cuts with each mineral's palette, placed seven studs behind the original row along the pad facing direction. GemCut=Compact selects their shared cached mesh templates. Both rows use the real PickupView launch/land/hover path, private negative IDs and no rewards. Production drops retain their usual cuts. The same description supplies durable Edit unions, which remain a coarse color approximation rather than exact runtime textures.

Native checks cover ten specimen/drop matches, equal compact geometry with twelve broad planes, child alignment over 120 poses, fixed texture selection, depth/material settings and reduced effects. No new Play/device test; temporal flicker, low graphics and multiplayer remain unverified.

## November 14 — angle-driven layered refraction

The owner rejected the opaque inner cut as painted on. Diamond restores the earlier spectrum structure with restrained fine noise, smoked transparent gaps and bright colored reflections. Texture alpha ranges from .30 in dark zones to .94 in saturated windows; the mesh opacity is .90. Inner and outer cut faces now share one MeshPart, so there are no two separate translucent body objects to exchange draw order. The inner faces retain offset UVs and lower vertex alpha. Opaque separated rims, back-face culling and removal of the extra white outline remain.

Eight cached 256² RGB/alpha patterns (about 2 MiB raw pixels before engine overhead) are created once. Each local gem selects a pattern from the camera direction in gem space, including pitch. A hysteresis margin prevents small movements from flipping back and forth at an angle boundary. Turning the gem or walking around it changes the pattern; returning to the same view restores it. No texture pixels are generated in the update loop. Shared textures are reused across diamonds; individual selection state uses weak instance keys. This is a discrete artistic refraction approximation, not physical ray tracing or a continuously deforming shader.

Native checks cover camera changes, rotation, tiny-motion stability, same-view repeatability and darker-zone transparency. The authored static preview uses coarsely sampled colors and overall translucent unions; only Play shows view-driven patterns. Previous preview is archived in ServerStorage.DiamondAngleArchive. Amber/Quartz are unchanged.

## November 14 — cleaner spectrum and stable depth

The owner approves the dark spectral Diamond but reports mottled texture and flickering edges/inner cut. The texture now retains broad dark/rainbow windows without fine grain, branching fracture noise or high-frequency hue distortion; only two faint planar fractures remain. Diamond texture alpha is fully opaque. The inset cut and rim meshes render opaque at full visibility; the outer shell alone remains translucent, and Diamond meshes cull their back faces. This avoids the overlapping translucent-part ordering documented by [Roblox BasePart](https://create.roblox.com/docs/reference/engine/classes/BasePart). The outer shell opacity is .80 so the inset stays visible.

Partial colored rims are slightly broader, moved farther off their facet planes, trimmed away from corners and deduplicated across shared edges. Diamond no longer stacks a Highlight outline over them. Existing timed sparkle/rays remain intentional animation. Native checks verify opaque aligned children through 120 sampled production poses, but do not prove a temporal flicker-free full Play session. Amber/Quartz geometry, color and texture are unchanged. Previous Diamond preview is retained in ServerStorage.DiamondStableArchive.

## November 14 — dark spectral Diamond replaces pale glass

The latest two owner references call for deep dark faces with bright rainbow reflections inside. Diamond now uses a cached 256² RGB optical texture: indigo shadows, localized spectral bands, sparse fine fractures and small cloudy variations. Unequal facet values and a complete inset cut with shifted texture coordinates create overlapping color planes and parallax. This is an authored approximation of internal refraction, not physical ray tracing. A failed texture allocation samples the same colors onto vertices. The thin highlights occupy selected partial edges; the previous continuous outline is removed. Existing facet rays/star flares and local spill remain, while Diamond rising dots are smaller/fainter. No per-frame texture generation or new asset upload.

Amber and Quartz geometry/colors/texture remain exact matches to the preceding revision. The authored Diamond preview uses coarsely sampled spectral colors on persistent unions; Play uses the full texture and shared pickup renderer. Only Diamond PreviewGeometry is replaced; its predecessor is retained in ServerStorage.DiamondSpectrumArchive.

## November 14 — luminous Diamond follow-up; preserve approved Amber

Diamond optical texture now stays pale rather than producing charcoal patches. Its internal reflections have lower opacity. Narrow mesh ribbons add pink/cyan/mint/peach facet rims; three normalized edge anchors carry white-to-color rays, small star/halo sprites and the existing four-point particle glint. A pooled, Diamond-only local light adds short-range spill. Hide/distance/Reduced Effects disable rays, flares and light; Reduced Motion keeps their intensity steady. No gameplay change. Amber and Quartz geometry/colors/texture were compared exactly against the prior revision.

The Diamond-only authored preview has a SmoothPlastic shell/cloud union to avoid the native Neon union washing out its vertex colors, plus Neon rims. Play retains the luminous textured mesh and effects. This static Edit approximation has no animated flare, and is not a pixel-exact representation of Play. Only Diamond PreviewGeometry is replaced; its predecessor is archived in ServerStorage.DiamondLightArchive.

## November 14 — rejected regular cuts and floating diamond patches

The owner rejected the first Amber / Quartz / Diamond pass. GemRefinement now derives their uneven planar cuts from half-space intersections. Amber has a tilted cut and a strong burnt-orange to honey gradient. Quartz has a broken crown, smaller blue grains contained inside its cut volume, a pale middle and gold base. Diamond replaces five floating patches with near-shell fracture surfaces, brighter pink/cyan/mint/peach planes and deterministic cloudy texture. Two cached EditableImages (256² Diamond, 128² Quartz) supply fine fixed optical detail; no per-frame texture generation or new uploaded asset. The existing Mesh/Image API permission applies. Image allocation failure retains the colored mesh and logs a texture fallback.

Ruby/Violet retain their palettes and general cuts with unequal sector widths/heights. The three optical stones keep the pickup display, with a fainter outline and smaller rising discs to expose their surfaces. Diamond keeps its short rays and four-point glints. Native Edit previews bake coarse texture samples into colored unions; Play uses the full image texture on the actual pickup mesh. Never describe that Edit approximation or an API-double pass as exact photorealism, gameplay acceptance or a multiplayer test.

## November 14 — distinct Amber, Quartz and Diamond finishes

The new five-field order is Amber, Ruby, Quartz, Violet, Diamond. Amber uses SmoothPlastic, low transparency and no interior specks. Quartz has a clear blue-to-gold shell, 76 blue/white crown dots and 85 much finer golden base grains. Diamond has pink/cyan/green/orange facets, five irregular triangulated translucent mineral clouds, sparse fixed grains, three short colored light rays and a faster small four-point sparkle cadence. Rays share the existing display pool and obey hide/distance/Reduced Effects; Reduced Motion holds their brightness steady. The GemKind attribute identifies the finish after PickupView renames the part.

The east plaza row uses these same production pickups in Play. Authored Edit shells/inclusions/clouds are static colored union approximations of the same geometry, without runtime EditableMesh serialization. Previous specimens remain in ServerStorage.RockVarietyArchive. Existing Cobalt/Emerald geometry and saved cargo values remain supported. Native component comparison verified all five sample/drop meshes, material/opacity and effects; no full Play or multiplayer test was started.

## November 14 — rejected string rays and preview mismatch

Revision **387e854** replaces the 22 parallel crack beams with two short, textured, fading shafts, tightens/tapers the actual shell openings, and lowers mote rate/speed. Preserve the inner core and surface occlusion. Plot boundary opacity uses camera-to-pin distance: hidden through 42 studs, smooth fade to full visibility by 70; the initial reveal and previous pin obey the same gate.

The five spawn specimens now enter the actual PickupView registration/update path with private negative local IDs. They cannot grant rewards or attract drones, and do not expire. Their mesh, opacity, hover, outline, ground glow, strand, motes and glints share the production renderer. The owner’s Play logs showed Emerald failing at CreateEditableMesh; each generated mesh is now converted to FixedSize and the dynamic allocation released before building the next. Cobalt no longer allocates an unused grain mesh. [Roblox fixed-size mesh memory guidance](https://create.roblox.com/docs/reference/engine/classes/AssetService#CreateEditableMeshAsync).

Durable Edit specimens bake the same transformed triangles and grain coordinates into nine colored unions, fixing the previous bismuth scaling mismatch and oversized Edit grains. They are static, discretized-color approximations in Edit; Play uses the exact pickup renderer. Native Edit component checks compared all five sample/drop meshes, materials, opacity and display rigs. No new full Play or multiplayer validation was performed.

## November 14 — open shell/core light and distinct specimen geometry

The latest owner request rejects the inset strips below. Preserve the existing rock silhouette while hollowing its center and cutting a thin, irregular opening through the shell. One smaller, solid luminous mineral sits inside. Native Beam fans project parallel, slightly varied rays from the lips of the crack, with a faint wider wash and slow round motes. The reference is the owner's attached light-shaft photograph. There is no emissive strip on the rock skin. Fourteen nearby rocks within 80 studs can show this local detail. Reduced Effects retains the inner core but disables rays/motes; Reduced Motion holds brightness steady and disables motes. All eight templates passed a native query proving that sight lines through the openings hit the inner core before the shell, plus pose/scale and cleanup checks.

Dropped mineral designs are now strongly different: three-point quartz cluster, broad ruby, metallic cobalt with hollow square bismuth terraces, a long narrow violet needle, and mostly black emerald with concentrated green/gold glow at its bottom. These derive from one shared GemGeometry description. Fixed interior grains remain in the four crystalline minerals; opaque metallic bismuth has geometric steps instead. Couriers use the same appearance and each mineral's own opacity.

Workspace.MiningAway.Map.MineralLineup is the requested authored row near spawn, from x=-18.5 to 18.5 at z=-12. It contains five labeled mineral specimens and a cracked-core sample. Native Part/WedgePart specimens derived from the geometry description persist in Edit and the canonical file. During Play, the client hides those baked specimens locally and uses the same cached meshes/gradients as actual pickups, with the existing slow hover/turn. The row has no PickupId, rewards, attraction, expiry or gameplay Scripts. Runtime teardown restores the authored presentation. Native component inspection and serialization round-trip passed; a full Play check remains separate.

## November 14 — mineral silhouettes, visible grains and inset channels

Latest owner request supersedes the all-red loose ore and mineable-rock modifier outlines below. Five cached gem meshes use different cuts and height/width proportions, broad vertical color gradients and 30 fixed white octahedral grains in a separate opaque interior mesh. The grain mesh follows the shell's exact pose, scale and lifetime; it does not sparkle or drift. Quartz uses mint/cyan/lilac, Ruby rose/coral, Cobalt blue/cyan/violet, Violet purple/pink/blue, Emerald green/gold/teal. Couriers carry the same gem appearance. Pressed blocks retain their existing presentation. Native mesh construction failure keeps the original pickup and logs the affected mineral.

Shape references reviewed on the owner's [Mines board](https://www.pinterest.com/soren460540/mines/) on November 14: [irregular silhouettes and cluster](https://www.pinterest.com/pin/968344357402992938/), [colored prism studies](https://www.pinterest.com/pin/968344357402992931/), [quartz shapes](https://www.pinterest.com/pin/968344357402992925/), and [warm crystal cluster](https://www.pinterest.com/pin/968344357402992924/). The original [volume/gradient/inclusion reference](https://www.pinterest.com/pin/968344357402992555/) remains the material target.

Mineable Crystal Run rocks draw from mineral-specific pairs of existing shapes. The server carves two irregular recessed channels once per cached shape using GeometryService, then stores normalized core positions. Existing crystal geometry and the fracture sequence remain. Nearby client effects place narrow emissive cores inside those channels, with soft outward rays and low-rate slow round motes. Twenty rocks within 76 studs can carry this detail. Reduced Effects retains the inset cores and disables rays/motes; Reduced Motion disables motes and the slow brightness modulation. Effects follow stage shrink/rotation and are destroyed on break, removal or leaving range. Modifier silhouette and ground outlines are removed from mineable rocks; white aiming highlights and other modifier particles remain.

Native Edit checks verify all five meshes, opaque grain depth/pose/fade/scale, all eight carved shapes, measured open space above the cores, channel following, reduced settings and cleanup. These are component checks, not a Play or multiplayer acceptance result.

## November 14 — reference-inspired gem volume and release particles

The owner selected https://www.pinterest.com/pin/968344357402992555/ as the primary gem reference. Fixed interior specks must keep their local positions as the gem turns. The implemented loose ruby uses one cached client mesh with individually shaded, gradient-colored facets, translucent emissive faces and 26 small embedded inclusions. Original pickups are the fallback when mesh creation is unavailable. Ordinary crystal breaks add a brief glint spray and slower colored discs. Pickup glints have a fast expansion and eased-looking decay, and rising motes drift laterally while cooling toward violet. Native Edit samples verified the geometry and finish. Gameplay motion and multiplayer remain unverified.

## November 14 — modifiers preserve mineral color

Keep the original mineral color, material and crystal silhouette for rocks and loose ore. A Frosted ruby remains red. Use native Roblox Highlights with transparent fill and layered ground outlines instead of attached pieces. The white selector highlight is confined to the live aiming preview. Charged sparks use tiny, fast, opaque rectangles that disappear at expiry. Cold vapor and rock dust are larger, softer background particles. Let the short arc, fracture spray and lingering smoke read as separate beats. [Riot Games’ visual effects guide](https://www.riotgames.com/en/artedu/visual-effects) · [Roblox ParticleEmitter reference](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)

## November 14 — stone debris and red dust

Take the tint and material for physical shavings from the rendered stone. Use soft, muted dust at contact and in the initial break burst. Tint the small flying rectangles and the lingering motes to the rock’s ore color. Begin darkening steadily as health falls, and cap the reduction at 38% through the split so the faces stay readable.

## November 13 — colored fracture and polished red drops

Keep the rock’s stone color visible through damage, Ramiel’s cluster contact, and the split. The matte sides and darker base remain readable as the rock shrinks. Raw crystal drops are glossy red with timed landing and idle glints. Preserve the separate chips and sparks on impact.

## November 13 — matte stone and neon ore contrast

Ordinary rocks have lightly mineral-tinted gray stone faces, a smooth darker base and no idle sun glints. Keep the existing shapes and let the damage tint carry the stone and its base shadow to black. Keep active contact effects and the larger neon drops.

## November 13 — rock opening and damage shade

At the release beat, show the last-stage silhouette opening from its foot into two black halves. Keep the existing chips, fireworks, and landing tails. Smooth the main rock shade toward black from the authoritative remaining work, and attenuate white hit flashes as the surface darkens. Keep discrete launch and hit feedback small. Reduce the stronger split shakes and let Ballcaster and Needler launch cues play even when their projectile head is outside the visual budget. Make the loose reward larger and neon.

## November 13 — local hitstop and bullet gradients

Hold the intact rock while the camera, characters, and surrounding action continue. Use about 17 ms for ordinary breaks, 33 ms for heavy breaks, and 55 ms for Nomad's cluster. Ramiel uses the 55 ms post-beam beat on its own. Release the split sound and fireworks with the actual break. Open projectile rings at fully opaque white, then transition through a continuous color and opacity gradient. Soften the initial flash when Reduced Flashing is enabled. Vary cue pitch around the authored pitch, with a smaller stable variation on sustained work loops.


## November 13 — Orbital and Ramiel ground-landing tendrils

The large strokes in the reference launch at impact, arc upward in world space, and bend back down to the ground. Let the glowing head draw the full trail before its tail starts to retract. Vary the height, reach, sideways hooks and arrival times. The thin impact flash and scattered sparks have their own timing.

## November 12 — layered silhouettes and particle variety

Use the supplied still for Inkbeam's visual composition: a warm luminous taper that ends in lime/cyan, a dark asymmetric sweep with broken angular offshoots, occasional bright contact glints and loose turquoise circles. Draw smooth changes in the underlying motion while letting individual silhouettes keep hard corners. Maintain the working point on the real crystal. Reuse the principle of distinct light, shadow, and particles on other attacks in their own palettes and rhythms. Preserve the regular mining sequence, the physical crystal break, and the restored specialist sequences.

## November 12 — shrink on one curve

When an effect shrinks away, use one continuous size curve from the start of its lifetime. Keep the rock shards' bounce and ground motion while their size changes. Dropped ore should bob on a stable 1.4-second cycle and send larger motes higher. Use the four-point star as the active mining laser's flare texture, with local light and normal world occlusion.

## November 12 — apply the supplied game-feel reference selectively

Reference: Design Diary, [10 Ways to Improve Game Feel](https://www.youtube.com/watch?v=qCj9CZoAvFY), especially particles (2:29), lighting (3:29), surface impacts (4:30), hit reactions (5:25), squash/stretch (6:51) and camera shake (8:02). Its demonstration comes from [Deepnight's game-feel tool](https://deepnight.net/games/game-feel/), which isolates cosmetic feedback without replacing the mechanics.

The simple abstract scene is deliberate. UI belongs to the owner. Preserve original models, precise laser paths, the existing mechanical gun recoil, projectile stretch, crystal hit reaction, final compression/split and level, reduced-motion-aware camera feedback. Do not add platformer movement, gun inaccuracy, rubber deformation to rigid drone hulls, scenery filler or global ambient-light changes to satisfy a checklist.

This pass gives ordinary crystal contact chips their source material/reflectance and a stronger mineral hue; they fall, briefly settle and then fade, with room reserved for the final fracture. Needler uses a rounded muzzle streak and a thin rounded contact flash instead of a cuboid. Needler/Ballcaster briefly light nearby surfaces on release and contact, bounded to six live flash lights and disabled by reduced flashing. Shot particles and trails retain their independent tails. Circular pressure fronts retain continuous opacity across their four internal joins and fade as one circle. These changes preserve the restored `44f061c` Nomad renderer and its attack behavior.

Production-code checks cover contact timing, landing before fading at 30/60/144 FPS, cleanup, fragment budgets, reduced flashing, circular joins, Nomad/Ramiel regression and the beam suite. They are not a native motion or visual-acceptance result.

## November 12 — corrected rollback: one revision earlier

The owner corrected the rollback: restore **`44f061c`**, the version immediately before `4bbbc70`. This supersedes the preceding visible-drone restoration selection. Use the smaller 14.2-stud hull, broad wing/ring/keel projector banks, original attack-only scanner cuts, original flight and immediate five-rock blast/mushroom effect. Do not retain the middle-teeth apertures, 2.5× enlargement, cruise scanning or larger delayed particle blast introduced by `4bbbc70`. Preserve unrelated later work.

## November 12 — current Nomad direction: historical visible-drone restoration

The owner explicitly confirmed returning Nomad to `4bbbc70f830f0b4009955b1319df67571b525208`. Restore its renderer exactly, with the corresponding visible model, cruise scanner, slow capped arc flight, physical projector attachments, 4.05-second windup, .95-second missile flight, 13-stud/up-to-five-rock blast and .50-second delayed shatter. Later Nomad patrol/field-fixed/camera compensation experiments and their timing are superseded. Keep later Ramiel, other attacks, map, UI and progression changes. This is a historical restoration, not a newly approved visual redesign.

Read this before changing drone beams, charge effects, launch effects, particle aftermath or their sound/camera feedback. It consolidates the owner's critiques in the November 4, 2026 beam iteration. Read [OWNER_REQUIREMENTS.md](OWNER_REQUIREMENTS.md) first; new explicit owner instructions override this snapshot. Historical review documents describe experiments, including rejected ones, and must not silently override the final direction below.

**November 12 Nomad rejection — rigid geometry and repeated cycling.** The owner rejected save 224's camera correction and the lost cycling. Remove camera-dependent deformation: world-vertical edges, equal widths at both ends, and the original pre-teeth glow from `44f061c`. Use the old 6.30-second phase clock for repeating hard pattern cuts during the slow inbound pass; approach distance must not stretch the pattern cadence. Finish once with keel sheets, two filaments, then exactly 1.8 seconds of darkness before the visible drop. Keep the off-screen patrol, slow movement, field blast and delayed shatter. Keep the wide banks aligned across the quarry fields' long X axis independently of side-entry direction. Native cosmetic replay verified repeated cuts and the 1.8-second cutoff-to-drop gap; full server-dispatched gameplay and owner visual acceptance remain separate.

**November 12 attack contact pass.** Keep the laser's short hot contact, Needler's narrow snap and Ballcaster's wide ripple distinct. Time specialist sparks and audio to each confirmed hit and use the floor rubble on depletion. Separate Breaker's touchdown grit and thud from the later crystal fracture. Keep Ramiel's thick pressure front on the firing beat and shatter on the later beat. Carry Nomad's ground dust outward with the field-sized blast. Keep Orbital's local tremor active during the burn and reserve its closing pulse for a completed strike. Scrap bots and field tools use smaller, material-specific contacts. Distance, particle budgets, stale-event checks and reduced-effects settings limit cosmetic work.

**November 12 Nomad's restored scanner and slower approach.** Use the old drone's fixed projector positions and widths for the outer, middle, rear, joined and keel banks. Keep each filament vertical and align the curtain between its edge filaments. Fade the visible column out above the field. Cap the visible sweep at 9 studs per second and keep the scanner audio, two-beam hold and blackout synced to the strike clock.

**November 12 instant slabs and Ramiel's aim.** Show the full tilted slab ring on the impact frame. Hold the slabs in place until they sink and fade. During Ramiel's charge, show a thin pink line and a small mark where the beam meets the selected crystal. Build the line's intensity through the charge and clear it on confirmed fire. Add a small late-charge tremor and stronger firing shake while keeping the camera level.

**November 11 Nomad's high patrol and field strike.** Nomad keeps its permanent slot and circles the map out of sight. During an inbound pass, the original broad rake, stagger and diagonal curtains sweep in from beyond the field. The three curtains keep fixed widths per arrangement, with pale edges, cobalt halos and lit ground rails. Cut to two filaments, then darkness, then the warm release light. Use a pulsing low rumble and a short electrical burst at each arrangement change. Cut the hum at blackout and follow the release with a descending turbine whine and an airy shriek. The arrival flashes once and shatters exposed eligible crystals across the field half a second later. The spatial cues use Creator Store audio. [Film sound design interview](https://www.asoundeffect.com/the-creator-film-sound/)

**November 11 Ramiel's wider beam and heavy impact rubble.** Start the wider red beam, pale core, broad glow and expanding ground shockwave together. Let the shockwave fade with the 0.42-second beam. On the confirmed cluster shatter 0.50 seconds after firing, play the deep crack once and throw sparks, dust and tilted ground-colored slabs around the strike. Let the uneven rim settle, then sink and fade over the next few seconds. Use the same grounded rubble for Nomad's delayed shatter, completed Orbital strikes, Breaker impacts and the other prestige mining drones' finishing hits. Scale the rim to the impact and sample the actual quarry floor. Keep the slabs local and noncolliding.

**November 11 Nomad cruise and impact.** The tracker cycles from the middle teeth while the enlarged hull is in flight. Keep the fixed projector banks and the pre-release blackout from the close-up. Approach in a slow, wide arc and settle over the selected rock. At contact, use one white screen flash and a fast fireball. Let a particle stem lift into rolling smoke and spread ground dust across the field. Hold the blackened rocks intact for half a second, then break the cluster together with its own crack, pressure ring and heavier level shake. [Cruise close-up](https://www.youtube.com/watch?v=S1Zffn_XO08&t=16s)

**November 11 Nomad's hull-mounted tracker.** The reference switches abruptly from the broad pattern around 30.18 seconds and replaces that arrangement with other fixed banks. The hull close-up around 31.5 shows paired sheets from the inner struts. The sheets and their outer edges disappear by 31.95, leaving two vertical inner lines. Both are dark by 32.11. A warm point appears under one wing around 32.62 and separates as the payload. Preserve fixed slit widths and world-vertical filaments during all pattern switches. Keep the brief dark beat before the starboard bay lights. [Frame-stepped sequence](https://www.youtube.com/watch?v=S1Zffn_XO08&t=29s)

**November 11 Ramiel's restored slab animation and quick shot.** Use the sampled slab tracks from `b4360f4`. The same facets pinch, pack in, open into crossed slabs, recoil, and close into the solid diamond. The red beam begins at peak visibility and fades over 0.42 seconds. Rocks blacken at contact and shatter together 0.50 seconds later with a stronger, level shake. [First transformation](https://www.youtube.com/watch?v=US5yoHbv-6Q&t=19s)

**November 11 polished gems and a firm landing.** Cut gems use SmoothPlastic at reflectance 1 for sky reflections on their faces. One small, transparent four-point glint peaks 45 ms after landing and repeats about every 2.65 seconds at rest. The gem falls quickly, stops on contact, plays one deeper spatial clink, and stays planted for 0.16 seconds before collection. [Roblox Reflectance](https://create.roblox.com/docs/reference/engine/classes/BasePart#Reflectance) · [Glint asset](https://create.roblox.com/store/asset/6997866346)

**November 11 Ramiel's cluster blast and heavy flight.** Show one solid glass diamond in travel. Ramiel has slower thrust, turns and top speed, and flies without a hover bob or recall hop. At beam contact, blacken every eligible rock within 11 studs of a ray contact. At the end of the brief post-beam pause, shatter the cluster together with deep sound, level camera shake and crimson debris and sparks.

**November 11 Ramiel's delayed break.** Keep hit rocks intact at their current health through the 2.55-second beam. At cutoff, end the beam's light, sparks, rumble and shake. Hold the first star at peak size as it flickers in opacity and fades. The smaller star flickers independently in size and opacity through the firing window.

**November 11 Ramiel's outward sweep and beam hold.** Keep the glass layers on a shared axis. Stagger their changes in width and rotation so the corners sweep outward. The diamond pinches into a column, closes around the core, then widens as the shoulders rotate into crossed slabs. Start the star's charge while the glass is still moving. Use a faster level camera tremor with the existing spatial rumble, contact light and sparks. Leave temporary char at confirmed ground hits. [First attack, including the outward sweep](https://www.youtube.com/watch?v=US5yoHbv-6Q&t=19)

**November 11 cut gem landing.** Dropped raw gems have reflective cut faces, an octagonal table and a tapered base. Flash one thin dotted four-point glint on a facet at a time. The higher arc falls faster and ends in one audible clink at a fixed pose on the floor. The floor is resolved before the server sends the trajectory, including drops over an edge.

**November 11 Ramiel's firing pose and flash.** Hold the intersecting blue slabs steady with jagged prisms clustered between the two halves. The pink-white cross accelerates into a brief scene-wide lighting flash. Its tapered rays continue turning as the pink pressure ring expands away from them. Use local light on the glass and client-side color correction and bloom for the flash. Reduced flashing skips the flash.

**November 11 Ramiel waves and beam reach.** The first and third waves roll outward through the glass layers. The middle wave packs inward and the lower stack follows slightly behind. The single red beam pierces eligible crystals along a server-traced line. The sustained sound and light linger through the beam, with a short heat tail.

**November 11 Ramiel morph timing.** Follow the first attack from about 19.04 through 24.04 seconds at the reference pace. Upper and lower equators, shoulders and caps use separately sampled inner and outer edge positions, radii, and rotation. The equator reaches its narrowest around 20.04, packs around the core by 20.84, then expands rapidly around 21.51–21.67. The smaller mirrors telescope in and out on their own track. Hold the settled shape before the flare, give the slices a brief outward impulse on contact, and let the local pressure rim continue after the core flare fades. [Reference playback](https://www.youtube.com/watch?v=US5yoHbv-6Q&t=19)

**November 11 Ramiel reference correction.** Use the first attack in the [short reference clip](https://www.youtube.com/watch?v=US5yoHbv-6Q&t=18). Six rigid cobalt glass slices separate and turn into two vertical stacks. Smaller mirrors turn around the red core between them. The core flare uses the timing sampled around 22.8–24.04 seconds in the clip. Keep the bloom near the aperture. The fine red beam holds for a 1.80-second envelope, and the stacks close after it. This replaces the earlier star transformation.

**November 11 large translucent circles.** Use the verified plain antialiased circle as the main cosmetic particle shape, with wider, sparser motes and moderate opacity. Keep inward charge, brief launch and surface contact, and separately timed fallout. Physical rock pieces, thin beam cores, sights, planes and the collectible's four-point glints retain their own shapes. The old advice to make attack particles mostly tiny streaks, cuboids or smoke textures is superseded. Six tiny chromatic accents still carry the ordinary laser's hard color cuts, and the larger launch discs carry the beam color.

**November 11 connected Ramiel rig and ore sound.** Keep the same glass facets from the closed diamond through the five-point firing shape and back. The usual charge lasts 2.48 seconds; the single red beam has a small gap and a transparency gradient at the aperture, a 0.67-second envelope, and a short translation-only camera kick. Ramiel has the largest idle hull and highest hover. Orbital, Singularity and Halver get a smaller size and lift increase, with ground work mounts kept at their normal height. Gun sights reveal world-spaced dashes whose brightness and position drift during aiming; clear them after firing. Ordinary scattered ore and large cargo both get one spatial clink at first landing, on the same buffered clock as the displayed arc. Do not consume the cue before the contact data arrives or replay stale landings.

**November 11 animation timing and scale.** Give each attack a readable preparation pose, a loaded hold, a faster release, and a settling motion. Ramiel pulls inward before it opens. The outer facets hold the firing shape while the core and aperture finish gathering light, then the single red beam fires. Needler cocks a round quickly. Ballcaster holds a brighter charged orb and recoils more heavily. Enlarge the cutter's focusing vanes, visible rock chips and impact sparks. [Motion study and timing](review/CRYSTAL_RUN_PAYOFF.md#anticipation-and-effect-size)

**November 11 beam hold and hovering ore.** Ordinary cutters retain the confirmed final contact until the rock splits. The collectible brakes into a steady hover 0.68 studs above its previous resting pose and gives off four-point glints. Heavier breakup debris falls faster, settles once, and plays a bright tick at release and small tinks at selected contacts. Needler and Ballcaster draw a thin red sight with unequal gaps and a contact dot while they have an assigned firing target.

**November 11 gameplay recording follow-up.** Crystal breaks use one small translation with zero camera roll, pitch or yaw. The larger split pieces, airborne sparks, dust and gem glints must read against a busy Ruby field. Orbital uses descending pressure rings, a bright initial ground impact and local fallout after shutdown. Ramiel has separately timed folding outer facets, a rotating inner aperture and a late build in light before the single red beam. See [the motion and gameplay review](review/CRYSTAL_RUN_PAYOFF.md#gameplay-recording-follow-up).

**November 11 hit stop and Ramiel:** finish the compression and hold the rock for about 90 ms. The visible split gets a deep impact under the original RockBreak sound, and a brief camera recoil for the nearby owner. The rising gem gets staggered glints and a separate chime. Use Ramiel’s five-pointed glass firing pose and single red beam from the Operation Yashima sequence. This supersedes the silent split and unfolding pane directions below. See [the payoff notes](review/CRYSTAL_RUN_PAYOFF.md).

**November 11 break payoff:** the last stretch of a cut warms the rock. An authoritative final hit leads to a grounded compression, outward split and pressure ring. Final-hit sound belongs to contact; the split itself stays silent. The gem follows the split by 25 ms, arcs and skids once, and then holds its pose. The regular laser keeps its inward motion and single hard color pop with four converging vanes and a visible native neon release. Ramiel opens glass panes before a confirmed lance; Orbital marks the target before the column arrives. See [the payoff notes](review/CRYSTAL_RUN_PAYOFF.md).

**November 11 work effects:** the ordinary miner uses the existing inward charge, single color pop and independent planar aftermath around the original beam. The launch rig releases its lease after ignition. Needler and Ballcaster have distinct wakes, muzzle sparks and contact effects tied to the server receipt. The Compactor closes around its docked inputs, holds pressure, and ejects cargo at 0.82 seconds. Its jaws reopen after ejection. See [the saved revision and verification limits](PROJECT_STATE.md#november-11--refine-pack-timing-crew-selection-and-work-effects).

**November 10 discrete-hit follow-up:** a confirmed projectile, specialist strike or Breaker contact gets a 70 ms whole-rock flash. An intermediate fracture can hold its prior shape for 45 ms before the original crack and shape change. A final impact can still play its own contact sound. The subsequent breakup is silent. Sustained laser contact keeps the slower opening flash and synchronized faint pulse. Reduced flashing lowers the white response independently of the fracture hold, which reduced motion skips.

**November 10 ore and beam follow-up:** remove projected crystal seams. Physical cargo arcs up and out, leaves a short tapered ribbon in its own color, lands, then can home. The first sustained contact fades across 0.30 seconds. The rock's faint subsequent white pulses and the hot contact light share a 0.34-second beat. The beam stays on between pulses. Coexisting contacts use the strongest tint, and reduced effects softens the flash and omits the trail.

**November 10 Crystal Run override:** accepted discrete shots get a brief white rock flash, planted jolt and layered spatial hit. Continuous cuts keep the fine original beam and add a white-hot contact, restrained vibration and chips. Health stages retain visible seams and progressive size changes. The final cut has a short local tension beat, several non-reward pieces and a distinct split sound; one separately tracked cargo object holds the reward. This overrides the earlier Crystal Run ban on cosmetic fragments and silent final break. No camera freeze or ordinary shot shake was added.

**November 8 closer cut:** the Mining Away primary pivot is three studs below the visible crystal center, so a ten-stud primary offset gives a seven-stud visual center offset. Preserve the shorter gap and the original warm core/soft halo at the contact. Play the intermediate crystal cracks from the primary position on the unprocessed crystal channel. The final break is silent. Keep world depth of field disabled.

**November 8 damage appearance:** use the enabled Mining Away server's shade calculation within each health band. The crystal carries the old band's darker shade through the shrink and turn, then uses the brighter new band on the next hit. The beam follows the visible surface. Fresh starter crystals use the reference's opaque red SmoothPlastic union. Gameplay models and rock targeting have no outlines. Targeting retains its fill cue.

**November 8 beam contact:** the owner wants the tip to follow the turning crystal like Mining Away. Primary mining beams on original crystal meshes aim at the reference's off-center marker, sample the visible surface beneath it, and keep the verified hit in crystal coordinates. That endpoint turns and shrinks with the rock immediately, while the muzzle stays attached to the drone. The ray budget, obstruction checks, width ramp and fade remain in use. Other contacts keep their existing aiming rules.

**November 8 crystal override:** the owner wants Mining Away's quick direction changes back. Original crystal meshes now snap to a seeded new facing at each damage stage and use the reference crack/break sounds. Only collectible ore fragments leave a mined rock; no decorative rock debris or traveling collapse fragments. See [crystal feedback](review/CRYSTAL_FEEDBACK.md).

**November 6 override for rocks:** the owner rejects shrinking/spinning animations. Resource size and grounded height snap to the authoritative stage immediately, with a fixed upright orientation; skipped stages and final breaks do not replay synthetic shrink steps. Keep the existing spawn growth and original drone charge sequence. Currency starts above/outside the current rock footprint, launches up/out, and cannot home during its initial arc. See [rock interactions](review/ROCK_INTERACTIONS.md). Historical settling/tilting directions below are superseded.

Implementation baseline: `b00e1d26f2c18a74644d5e6d7e04a5f94229a01a`. “Implemented” means a response was built and installed, not that the owner approved its visual quality. Numerical values below describe this revision; they are tuning choices, not independently requested requirements.

Subsequent broad overhaul: see [VFX overhaul](review/VFX_OVERHAUL.md) for the November 4 pass across specialist choreography, role pressure waves, contact particles, beam flow and flight trails. It preserves the resolved regular flash/charge/release direction below. The review records changed budgets, exact saved verification and remaining native validation limits; it is not owner approval.

Latest audio correction: the owner found the laser grating. Charge, ignition, cutting hum and stop now receive laser-only EQ (mid −9 dB, high −20 dB), lower pitch and volume. Ignition has a 70 ms fade-in; the charge pitch rises only from about 0.65× to 0.74×. The existing assets are retained but their timbre is filtered; unrelated sound templates are unchanged. Renderer-owned ignition suppresses the redundant state-observer cue. Audio/beam regression suites and saved Source equality are checked; this is not a listening endorsement. See `build/soft-laser-native.json` for the saved checksum.

Latest physical mining pass: Bubbler now removes visible spherical portions of the rock, Smasher leaves a progressively larger/deeper bowl, and ordinary shrinking settles with material chips/dust without blackening the rock. Preserve the shared cutter/bubble placement and the local cut MeshPart lifecycle; do not revert to changing only particles or substituting a primitive rock. Mining and pickup authority remain on the server. The accepted regular-laser sequence and audio above remain. See [physical mining integration and native captures](review/PHYSICAL_MINING.md) and [damage implementation](review/PHYSICAL_ROCK_DAMAGE.md) for the original union compatibility work and validation limits.

## What the owner is asking for

The effect should feel deliberate, forceful and physically connected from anticipation through aftermath. Study the reference in motion, especially its easing, suction, color contrast and handoff into the laser. The owner repeatedly rejected effects that were sloppy, choppy, floaty, weightless, unreadable or built from the same spinning beams and ugly parts. More geometry and more layers do not by themselves answer that criticism.

Primary reference: `/Users/sorenwidman/Downloads/sailent_sfx_7681643165253717261.mp4`. The owner said both “look at what makes the effect good and not just copy frames” and “just copy the video.” Apply these together: match its actual motion and sequence closely rather than inventing extra stages or reproducing disconnected still-frame shapes.

The owner also supplied a small image of dark/violet curls beneath a drone and said these could work if made more organic. Its original temporary path was `/var/folders/qd/j6sbn3793wb55vb8xvjtjzr80000gn/T/codex-clipboard-1965080f-0c20-4674-9b50-01c3ca9b51b4.png`; it may not survive cleanup. This request permits small organic curls, not a return to large spinning sculptures.

## Critiques, requirements and the responses implemented

| Owner's critique or request | Direction to preserve | Implemented response |
| --- | --- | --- |
| All the existing beams looked horrible and sloppy because of choppy spinning parts. | Smooth, readable motion; stop using rigid spinning decoration as the main effect. | Removed oversized looping sculptures, orbiting debris and the spherical launch treatment. Removed stepped beam-body opacity. Curved paths use continuous samples and pooled render objects. |
| The first implementation was best; subsequent revisions were worse. | Recover the preferred starting point without wiping out unrelated improvements. | Identified the other chat's first installation as `765a107`; restored smaller proportions and the inward/planar direction. That commit predates the chromatic lens, so it was not used as a whole-file rollback for the later flash request. |
| “The particles just swirl in and get sucked up and then it lasers”; no initial drift. | Inward motion must begin immediately and converge on the emitter. | `PullMotion` caches eight trajectories with inward and tangential initial velocity, central attraction and drag. Trails follow prior positions along those trajectories. No initial outward drift or prescribed endless orbit. |
| Be more creative and use physics-based pulls. | Shape motion through forces, momentum and capture, keeping the cost small. | Cosmetic point masses are simulated once and interpolated from authoritative charge progress. This is local force-based animation, not server physics, collidable debris or gameplay force. |
| All lasers should be much finer and skinnier. | Keep thin bodies and fine cores across laser families. | Narrowed beam layers, including support/specialist and orbital treatment. Shared beam width scale is `0.4`; the regular sustained body is about `0.12` studs at scale 1. |
| Remove the little jump animation. | No firing hop or recoil displacement of the drone. | Removed the added firing hop from gameplay flight and the home preview. The original subtle hover remains; it is separate from the removed firing jump. |
| Replace the explosion with a plane-based spread like the video. | Release should read as pressure across a circular plane. | `PlaneBurst` uses four fixed cubic quadrants perpendicular to the shot. The ring expands; its attachments do not orbit, and it does not billboard toward the camera. |
| Effects disappear at release, including the growing cloud; show the aftermath. | Smoke, ring and fragments need their own continuing lifetimes. | `LaunchAftermath` owns the launched tails independently of the charge lens and emitting drone. Ending a short attack or returning the lens to its pool does not erase an already launched tail. |
| Push the existing cloud away like real smoke when the laser starts. | Release must act on the cloud that was already gathering. | Existing smoke receives a short radial acceleration impulse and drag. It is not cleared and replaced at ignition. Sparse charge emission keeps the longer buildup from obscuring the pop. |
| Shoot tiny cubes/rectangles downward in a cone to carry the pop's color. | Small colored fragments should spread broadly around the shot direction. | Eighteen tiny cuboids launch with radial and axial velocity. Their sideways spread is greater than their downward travel; the result is a broad cone, not a straight downward column. |
| Reuse the physics-based particles for cheap electrical jitter. | Fast impulses with irregular lateral motion, not expensive physical objects. | Cached discharge trajectories receive small lateral velocity kicks and drag. Fragments are noncolliding local visual parts; no constraints or per-frame random rebuilding. |
| The disk and particles are too floaty; the disk must move much faster, brake faster and stay closer. | Decisive initial acceleration followed by strong braking, with compact travel. | Ring radius uses a rapid exponential expansion followed by a small continuing expansion. Dust launches at roughly 24–32 studs/second radially and 11–15.4 axially, then brakes strongly. |
| The particles fall; they should have no gravity. | Keep electrical dust suspended in a slowly moving outward cone after its initial impulse. | Removed gravity and ballistic falling. Drag approaches a small outward/downward current; downward displacement comes from the launch/current, not accumulating gravitational acceleration. |
| Sparks do not contain the pop's colors. This was raised repeatedly. | Preserve distinct saturated chromatic fragments; do not tint the entire spray beam-blue. | Dust uses blue, cyan, magenta, green, yellow and red. It includes the restored flash's yellow/cyan/magenta inputs; smoke and ring use the beam's palette separately. Native samples observed all six dust colors in the preceding retained aftermath revision. |
| Smoke and related effects should match the beam: blue. | Regular-laser smoke should be blue, not the earlier purple cloud. | Smoke takes the owning beam color; regular preview blue is RGB `(114,201,255)`. The ring uses that color with a small white mix. The requested dark/violet curls and multicolor pop/dust remain distinct accents. |
| The ring and downward particles should linger and keep moving. | Strong braking must not become a frozen tail or abrupt disappearance. | Ring continues expanding during its 1.1-second fade, ending near 2.52 studs radius at scale 1. Fragments continue moving and jittering for about 1.25–1.46 seconds. Smoke can persist up to 1.8 seconds. |
| Add tiny screen shake and sound; later, replace the sounds with something fitting a laser turning on. | Restrained, synchronized charge/ignition feedback. | Replaced generic pulse/pressure/crackle layers with a rising charge loop and laser ignition clip. Launch requests a `0.028`-stud camera impulse before distance attenuation, respecting reduced motion. Existing spatial mixing, cooldowns, mute controls and voice limits remain. |
| The whole animation can be longer, beginning with the inward swirl. | Give anticipation room without stretching the original brief color pop into a long glow. | Effective base warmup is 3.2 seconds through a runtime multiplier; saved base traits remain 0.8 seconds and startup cards still shorten warmup. The preview uses 3.2 seconds charge, 4.5 seconds attack and 0.2 seconds rest. Longer warmup adds pre-attack downtime; active DPS is unchanged. |
| “The color pop lost its point”; restore how the flash originally looked and its original timing, keeping all other changes. | Restore only the pop, not the whole effect system or an unrelated old build. | Recovered the original single flash curve from the saved pre-revision planar payload. Removed later repeated threshold/pulse redesigns. Restored its proportions and Glass/Highlight envelopes, with the original approximately 0.288-second duration independent of the longer inflow. |
| The pop must still have distinct colors and must not animate smoothly between them. | Hard color switches; smooth geometry does not imply blended color. | Removed color interpolation. Mask inputs switch yellow → cyan → magenta → yellow. The native distortion's visible output also depends on scene and renderer; property values alone do not prove the desired look. |
| Bring back the tiny swirling things, but make them organic. | Small irregular curls that deform and get pulled in. | Added three dark/violet tapered curls with separate arrival times, force-derived paths and smoothly varying breadth. They have no shared rigid rotation, spinning part or visible loop reset. |
| Start the beam and related animations before the color switching has fully finished so there is less of a gap. | Overlap anticipation and release instead of waiting for every charge layer to vanish. | Shifted the unchanged flash curve 80 ms later relative to ignition. Beam, planar ring, dust and launch feedback start while the final color cuts finish. Inward paths and charge audio end on release; only the lens remains for the brief overlap. |

## Color-pop history: do not confuse experiments with current instructions

The owner first described a medium swell/collapse, then a larger swell/collapse, then smaller/faster collapses to build anticipation. A three-peak version was implemented. They then asked for faster, shrink-only repetitions, with each new full-size reset smaller than the previous one. A six-pulse version was implemented and rejected as unreadable. They requested the old look revised so it could collapse and reset larger a few times; further thresholded and repeated-pop attempts were also rejected.

The final rollback instruction was explicit: restore the original flash and timing, keeping all the other work. The subsequent instructions retained distinct, unblended colors and added a short overlap with laser ignition. **The current baseline is the restored single flash, hard color cuts and ignition overlap. Do not reintroduce the three-, five- or six-pulse experiments based on earlier messages.** Their motivation—readable anticipation, contrast and a meaningful collapse—still matters, but their discarded implementations are not standing requirements.

The original single-flash envelope begins at normalized flash time `0.64`, peaks at `0.79`, and finishes at `1`. Its normal duration is 0.288 seconds, with regular maximum diameter about 1.8 studs. At the current baseline it begins approximately 0.208 seconds before ignition and finishes 0.080 seconds after ignition. The geometric easing remains smooth; palette changes are discrete. Charges shorter than 0.8 seconds compress the flash and overlap proportionally.

## Rules for the next VFX edit

November 7 texture pass: solid specialist chips keep the source ore finish, and Halver's moving jaws use the same ribbed finish as drone hardware. Treat smoke, glass and glowing energy separately from solid materials. Preserve the established timings, colors, thin beam bodies and independent aftermath.

November 7: The home demo and working specialists should carry their startup into the first work gesture. The Orbital uses a 2.4-second red sight and a pressure circle sized to the rock; its strike column stays grounded while contact particles follow the melting top. Gridcutter scores a three-by-three layer and separates the fitted blocks with an outward push. Halver sheds two wider ore pieces; the giant sword divides its detached slice into six. Keep the original rock surface on those pieces. See [effect and economy review](review/EFFECTS_AND_ECONOMY.md).

- Watch the supplied reference at normal speed and inspect easing around transitions. Identify which layer leads, follows, contracts, accelerates or survives release before changing it. Do not invent an initial drifting stage.
- Treat charge, ignition and aftermath as one connected sequence. Smoke displacement, the planar impulse, colored dust, audio and tiny shake should communicate the same release event.
- Preserve compact scale, thin lasers and readable silhouettes. Avoid large rotating structures, arbitrary orbiting parts, spherical release replacements, opaque clutter and broad featureless glow.
- Keep geometric motion continuous and organic while preserving deliberate hard color cuts. Do not “smooth” those color switches into a rainbow tween.
- Let the smoke and fragments outlive the flash and keep moving as they fade. Keep dust gravity-free, compact and broadly radial. Do not clear the existing smoke at ignition.
- Keep changes scoped to the requested layer. A color-pop rollback must not revert smoke, ring, dust, audio, charge duration, narrow beams, removed hop or unrelated game work.
- Preserve the original drone assets, gameplay feel and distinct specialist behavior. The ordinary laser's chromatic pop is not a blanket replacement for Bubbler/other specialist startup styles.
- Sample cosmetic motion locally from replicated authoritative timing. Do not move damage/rewards to the client or change gameplay timing accidentally to repair a visual handoff.
- Keep bounded reuse: four active rich charge rigs, six cached charge rigs, four active aftermath rigs and four cached aftermath rigs at this revision. Retain distance/reduced-effects handling, cancellation, idle disconnection and cleanup. Never replay missed bursts or audio cues for a late observer.
- Use the existing home preview to inspect repeat cycles without chasing drones. It is cosmetic; display rocks and drones must not affect fleet ownership, resource health, rewards or progression.
- Follow the root project rules: verify the exact shared place and connected roots, use Script Sync for routine changes, and refresh only the allowlisted Sources in `build/DRONE_GAME.rbxl`. Preserve unrelated edits. Use the local save and shared Edit checks for routine work. Publish only when the owner asks for a release.

## Where the implementation lives

| File | Responsibility |
| --- | --- |
| [BeamVFX.lua](../src/BeamVFX.lua) | Thin beam vocabulary, original flash, discrete color cuts, tiny curls, overlap, charge rig pooling and cue lifecycle. |
| [PullMotion.lua](../src/PullMotion.lua) | Cached inward attraction and gravity-free electrical discharge trajectories. |
| [PlaneBurst.lua](../src/PlaneBurst.lua) | Fixed circular plane, fast expansion, braking and continuing fade. |
| [LaunchAftermath.lua](../src/LaunchAftermath.lua) | Existing smoke pressure response, saturated cuboid cone and independent pooled tail lifetimes. |
| [StartupFX.lua](../src/StartupFX.lua) | Specialist startup vocabulary and inward motion. |
| [Presentation.lua](../src/Presentation.lua), [LaserShowcase.lua](../src/LaserShowcase.lua) | Gameplay/preview rendering and charge-duration handoff. |
| [Cards.lua](../src/Cards.lua) | Effective warmup scaling without rewriting permanent base traits. |
| [Client.lua](../src/Client.lua), [Soundscape.lua](../src/Soundscape.lua) | One renderer-owned charge loop, ignition cue and small camera impulse. Charge asset `139131445232833`; ignition asset `139620337204036`. |

## Verification and remaining limits

At baseline `b00e1d2`, `python3 tools/test_beam_vfx.py` passed 22 production behavior checks plus startup/repair checks and client/server compilation. These include path continuity, repeated reuse, discrete palette values, original flash envelope, ignition overlap, independent tails, no-gravity cone behavior, cancellation and cue lifecycle. They use API doubles; they do not establish visual quality.

The saved canonical native file matched all seven current allowlisted Sources. An 8.2-second Studio sample observed 491 rendered frames, five with beam and pop simultaneously enabled, the three exact unblended mask colors and enabled tiny curls. Console was empty. Earlier retained-aftereffect checks observed moving tails, all six dust hues and loaded/playing replacement audio. Those observations establish operation, not a subjective motion or listening endorsement. Full owner visual/audio acceptance, mobile/low-quality rendering and multiplayer appearance remain unverified.

Review a complete charge → ignition → aftermath → next-charge cycle in the actual engine, including ordinary viewing distance. Check color readability, gap-free overlap, attached endpoints, compact motion, persistent moving tails and absence of hop/spinning clutter. Inspect busy scenes and reduced-effects behavior when changing budgets or layering. Do not describe a screenshot, source inspection or passing automated check as a motion or multiplayer playtest.

Historical detail: [inward/planar changes](review/INWARD_PLANAR_BEAMS.md), [fast burst iteration](review/ELECTRIC_BEAM_POLISH.md), [longer charge and replacement sounds](review/REFERENCE_COLOR_POP.md), and [final flash rollback/overlap](review/ORIGINAL_FLASH_OVERLAP.md). The first three contain superseded settings; use the resolved direction in this file for future work.
