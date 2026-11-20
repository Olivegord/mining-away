# VFX instructions — owner feedback and implementation

## November 19 — VERSION 2: the Pressure Strike showcase

Owner: recreate one attack from the [Wind Moveset video](https://www.youtube.com/watch?v=-RYr9ZNJPGM), looking closely at how the layers progress, as a second version built without collaborating with the chat doing Version 1. The first pick (the green whirlwind at 25.7 s) was rejected because it is built around the character. **Pick effects that land on a spot in the world.** Version 2 is the ranged strike at 30.07–33.30 s. It lives in `Workspace["VERSION 2"]` at (0, 3.8, 135), on the open baseplate south of the hub, and replays by itself for anyone within 420 studs.

What the video does, read at 30 frames per second (`t` = video time − 30.07 s):

| t | What happens |
| --- | --- |
| 0.05–0.66 s | Five pulses about 0.135 s apart. Each: a pale drum (radius ~10.5, 4.6 tall) is faint and high, bright as it passes head height, soft as it lands; a curtain of pointed streaks hangs under it; a thin ground ring flashes and holds faintly. The ring grows from 4.5 to 8 studs across the five, and the last two curtains are dark. |
| 0.66–0.86 s | Nothing. |
| 0.86–0.96 s | A larger faint drum falls from about 27 studs; core flame, dark tube and sky halo for two frames; **one frame** of a huge white tulip of streak sheets; then only a thin shock ring (21 → 31 studs), a dark spike crown and thrown rock. |
| 1.13–2.73 s | Seven follow-up hits at 1.13, 1.33, 1.73, 2.12, 2.33, 2.53 and 2.73 s, each a ground ring with some of: a thin white pillar, a faint tulip, a sky halo one frame early. A second full tulip at 1.93 s. Low sparks at 1.23 and 2.36 s. |
| 2.80–3.25 s | A white column drops; a bright puck lands (radius 11.5) and runs out as one ring: 16.5 at +0.04 s, 22.5 at +0.07, 30 at +0.10, 37 at +0.14, 47 at +0.21, 52 at +0.27. The spike crown sinks away after it. |

The red boxes that blink during the pulses in the video are the author's hitbox display and are left out.

**Implementation.** `tools/vfx_version2/PressureStrikeV2.lua` draws every layer from the time alone (`rig:Seek(t)`), so any moment can be posed in Edit and compared with its video frame; `rig:Step(t)` adds the only particles (pale specks, one smoke curl). Rings and arcs are curved Beams (`Ribbon`), everything upright is a camera-facing Beam (`Streak`), rocks are 28 anchored Parts on a ballistic path. No uploaded textures or meshes. One strike costs about 1.6 ms a frame with 224 beams. `Replay.client.lua` loops it with a 1.6 s rest. `python3 tools/studio_vfx_version2.py` rebuilds the model in Edit (`--wait` for Play, `--save` to save); it replaces only its own model. Edit shows the strike frozen at 1.74 s (`EditPreview`), which the replay script removes at run time.

Checked in Studio Edit by posing at 0.20, 0.90, 0.93, 0.97, 1.14, 1.335, 2.81, 2.865, 2.905 and 2.97 s against the video frames, and by one real-time run of `Step` in Edit with no errors. **Not seen in Play**, so real-time pacing, the particles and how it reads from a player's camera are unverified. Things learned: a Beam with `FaceCamera=false` is as wide along its attachments' Y axis; `TextureSpeed` defaults to 1 and scrolls even a stretched glow; a glossy floor mirrors the strike light as a long smear, so the stage is Concrete.

## November 18 — ordinary rock breaks get the full older break again

Owner: get the older Codex rock-break effects with lots of different types back. Since `4679617` (Nov 15) rocks whose cargo is Stone skipped the gem-release glint spray and slow colored discs and the release chime, and got a burst at 0.52 instead of 0.83. That gating is removed in `src/CrystalImpactView.lua`: every ordinary break plays chips, split spark, floor pulse, full `CrystalBreak` burst, release spray, colored discs and chime. The confetti layer from `6c631ff` is gone too. Do not tone ordinary breaks down again without a request.

## November 18 — all mining and rock particles back to the original

Owner, after the partial restore below: "those are the new ones. i want the circles, the sparks, all that". By "rock breaking" they meant the laser working the rock as well as the final break. `src/WorkEffects.lua` and `src/RoleVisuals.lua` are byte-identical to 95bff48 again (the round contact discs at full size and rate, origin sparks and glow, contact glow balls; no added smoke or streak layers), `EnergyDisc` scaling is neutral (`SCALE=1`, no cap, no fade), and the cube belly sparkles and confetti twinkle have their original size and rate. **The owner's first request ("too busy, large circles") is withdrawn in practice: do not shrink, fade or replace these particles again unless asked for a specific one.** Only the drone charge and its release burst are new.

## November 18 — rock-break particles back to the original

Owner: "get back the old particle effects please for rock breaking". Rock breaks and impact bursts (`RoleVisuals` `ImpactParticles`, `WorkEffects:burst`) run inside `EnergyDisc.full`, which restores the original full-size, full-opacity discs for that call. The confetti twinkle is back to 0.9. Only continuous effects (mining contact, cube belly sparkles, the charge) keep the toned-down discs. Do not shrink or fade break bursts again.

## November 18 — no crossfades

Owner, right after the fifth pass: "no crossfades". The glitch colors are exact palette entries again and switch outright; **do not blend between colors**. The switch is timed to the moment the blotches and wisps have melted away. Everything else from the fifth pass stays: eased sizes, melting blotches, blended handovers of size and radius, feathered spikes, eased release. Read "no hard edges or linear cuts" as being about motion, size and opacity, not color.

## November 18 — fifth pass: no hard edges or cuts anywhere; invisible-drone work

Owner: "tune the effect so there are no hard edges or linear cuts ANYWHERE", and some drones are still occasionally invisible. **This replaces the older "hard color cuts, never blend" rule.** Nothing in the charge or release may appear, vanish, change color or change size in a single step, and fades use eased curves rather than straight lines.

- (Superseded for color, see above.) Glitch colors crossfaded into the next palette frame; blotches and the RGB-split offset melt out and grow back (`h.melt`). Each pop grows out of what the previous one shrank to. Wisps melt with the blotches.
- The build-up hands over to the glitch through one blend weight (`glitching`), used for void size and ring radius as well as opacity. Rings, wisps and spikes bow out (`final`) before the flash instead of being switched off at ignition.
- Spikes have a feathered base and tip. Bolt and ribbon heads use the soft glow image.
- Release: lightning forks swell and fade and overlap by half a beat; shock arcs ease in; cube shrink, flash, void and fragment fades are eased.
- **Invisible drones.** One cause was the dark backdrop: it sat three studs behind each charging drone and blacked out any drone farther from the camera, worst when the crew charges together. `B.voidPlacement` now puts it up to twelve studs back along the view line (never below the rock), enlarged to look the same, at 78% opacity. Any remaining cause is unknown; the client now writes a `[DroneVisibility]` line to the output once per affected cube (state, hull opacity, camera fade, size, distance from its server position), which can be read after a playtest.

## November 18 — fourth pass: expressive motion, a release burst, a shorter charge, no bucking

Owner on the third pass: "pretty good", but some effects were too linear, everything just disappeared when the beam started, the whole thing was a little too much for tiny drones, and the drones bucked constantly in flight.

- **Where the energy goes.** At ignition the reference throws the lifted cubes outward with a flash, lightning, shock arcs and lingering smoke. `LaunchAftermath.drawBlast` now does this on its own clock: the cubes continue from where the charge left them (hard launch, heavy braking, spin, shrink out by 0.85 s), a soft flash blooms and tints to the beam color, two lightning forks re-strike for 0.3 s, three shock arcs run out across the firing plane for 0.5 s, the dark void blows open, and nine smoke puffs linger. A quick re-ignite gets a small flash and puff only. Up to eight tails run at once (`A.LIMIT`).
- **Less linear.** The core and its glow beat like a heart that quickens (`q²`), and flare each time a bolt lands. Cubes swirl faster as the charge builds, tremble, breathe in and out, and are sucked toward the core in the last 5% before being thrown. Rings speed up. Each glitch pop lands with a 20% overshoot and the orb shakes slightly per frame.
- **Shorter, not faster.** The first ignition is 1.9 s (`scene.FIRST_CHARGE`). The sequence is authored for 2.6 s (`B.DESIGN_CHARGE`) and aligned to ignition, so a shorter charge trims the opening (the lone core and first bolts) and every remaining element moves at its authored speed. The orb is 1.05 studs in radius and the void about 15% smaller.
- **Bucking.** Cube lean was 3.2× the raw acceleration between snapshots, up to 16°/13°. It is now low-pass filtered with a dead zone and capped at 6° bank and 5° pitch; the hover bob is one slow wave of 0.12 studs. Server side, the flock's home radius and trail offset used to jump when the player crossed 0.5 studs/s; both now blend in.

`tools/studio_vfx_preview.py --release 0.02,0.07,0.15,0.4` renders the burst. [Preview sheet](review/media/charge-preview.png) is from this revision.

## November 18 — third pass: the charge finally checked in Studio

Owner feedback on the second pass: "really bad, and choppy", "no anticipation and cool effects like the original video", and "some drones are like invisible". **Read this entry first; it supersedes the sizes and timings in the entry below (the video stage table there is still right).**

What was actually wrong, found by rendering it in Studio Edit (`python3 tools/studio_vfx_preview.py OUT_DIR`; see [the preview sheet](review/media/charge-preview.png)):

- **No time.** In the square fields a laser miner's warmup is 0.1–0.4 s per rock. The whole sequence was being squeezed into that, which is the choppiness and the missing anticipation. Now the server gives a miner's **first ignition after six seconds without a beam a 2.6 s charge** (`scene.FIRST_CHARGE`, `scene.FIRST_CHARGE_REST`); moving to the next rock keeps the short warmup. The client plays the full sequence only for charges of 1.4 s or longer (`B.FULL_CHARGE`) and a compact single-pop re-ignite for shorter ones. Never compress the long sequence into a short charge.
- **Daylight ate the glow.** Additive beams vanish over a bright field. A soft dark "void" circle now grows behind the charge, always facing the camera, with a soft colored aura on the core. Colored glows use low `LightEmission` so they keep their color in daylight. This is a local backdrop, not a screen effect.
- **Hidden inside the cube.** The charge gathers at `B.focus`: up to 1.7 studs below the emitter on the beam line.
- **Single-frame flicks.** Slashes, bolts, spikes and the pops ease in and out. Bolts are comets that fall in faster as the charge builds.
- **Too small.** Sizes are in studs: orb up to 2.5 across, cubes hover 2.3–4.3 studs out, bolts start 5.5–8 studs out, void up to about 13 across. Up to eight drones get the full rig.
- Beams with a transparency gradient need more than one segment (the flares were invisible with `Segments=1`).

**Invisible drones.** The client fades hulls that sit between the camera and the avatar by up to 86%. With the flock behavior, cubes cross that line constantly. Cubes now fade to 40% of that at most. This is the likely cause; it was not reproduced in Play.

**Rule for future VFX work:** render it with the preview tool and look at the screenshots before installing. API-double tests passed for both rejected passes.

## November 18 — quieter circles, and a startup rebuilt from the video frame by frame

Owner feedback on the first pass (6228027): a regression. The particles were simplified far too much, the screen flash was unwanted, and the charge was "NOTHING like the video". The owner **likes the circle particles**; they were only overpowering. Do not replace the discs with streaks or smoke again, and do not add full-screen flashes.

**Particles.** `EnergyDisc.configure` draws the same round discs as before at 55% size (cap 1.25 studs) and 0.14 more transparent (`Disc.SCALE`, `Disc.MAX`, `Disc.FADE`). Smoke and little sparks are *additional* layers: `EnergyDisc.smoke` and `EnergyDisc.sparks`. The mining contact has round discs (rate 4, 2 when crowded), fine hot streaks and stone-tinted rising smoke. The contact glow balls stay smaller.

**What the video does** (read at 15 frames per second; sheets can be regenerated from the owner's file). Use this list, not quarter-second stills:

| Video time | What happens |
| --- | --- |
| 0.2–1.0 s | Tiny dark core with a violet aura. Dark cubes lift off the floor in a wide ring and tumble. Short crescent slashes flick around the core for a few frames each. Fat white bolts shoot *into* the core from far away; these keep coming for the whole charge. |
| 1.1–1.8 s | Long cyan ribbons with dotted glitter arc through the air and spiral into the core. |
| 2.1–2.9 s | A blue and a violet horizontal lens flare orbit on opposite sides and close in. Thin rings circle the core. |
| 3.0–3.5 s | The core swells into a black orb with a bright rim, throws white wedge spikes, and shrinks. |
| 3.5–4.4 s | The neon glitch is a series of **pops**: the orb jumps to full size in one frame as a flat two-color posterized ball (yellow/red, pink/black, green/black, blue/green), shrinks over about three frames, then pops again in new colors, each pop a little smaller. Wedge spikes flash at each low point and blue wisps swirl around it. |
| 4.47–4.53 s | Two full-screen threshold frames. **Not implemented: the owner rejected screen flashes.** |

**Implementation** (`BeamVFX` rich charge, all driven by normalized charge time `q`, so shorter charges compress): cubes from `q` 0.02, slashes 0.03–0.76, bolts 0.10–0.985, ribbons 0.20–0.56, flares 0.42–0.76, rings from 0.48, black-orb swell 0.64–0.78, four pops starting at `B.GLITCH_STARTS` = 0.78, 0.835, 0.89, 0.94 with sizes `B.GLITCH_AMPS`. Each pop shows two flat frames from `B.GLITCH_PAIRS`; colors never blend. The last pop keeps collapsing for 60 ms over the beam. `B.ChargeScale` (2.2) sets the overall size for ordinary drones: the orb peaks at about 1.8 studs across, cubes hover within about 5 studs and bolts start about 6.5 studs out. Reduced Flashing shows one translucent frame per pop. The earlier slow curls, focus vanes, Glass lens and single slow-shrinking ball are gone.

Verification: beam suite (29 checks, rewritten for the pops), fun, flat-field, rock-damage, pickup, geode, flight, field-pickup and selling suites pass with API doubles, and a numeric dump of the rig at 13 charge times matches the table above. **None of this has been seen in Studio.** Scale, brightness and busyness with several drones charging at once need the owner's eyes.

## November 18 — colorful cubes, confetti breaks and field motes

Owner direction: more colorful, less flat, very simple, more particles. Cubes keep the cube silhouette but each takes a vivid palette color with a light top cap, a glowing belly, simple eyes, a cruise trail and mining sparkles; its laser uses the same color. Rock breaks add a field-colored confetti and twinkle burst on top of the existing two-piece split, chips and audio. Square fields get slow colored motes; a mild client color grade lifts saturation. All of it lives in `src/FunFX.lua`, is client-only, bounded and disabled by Reduced Motion. Do not restore the plain gray cube shells.

## November 17 — overhead cube laser assignment

The original quarry's helper offsets can sit beyond a rock's footprint while still contributing damage. Cube laser miners reserve one overhead spot per rock and start cutting close to that spot in both routes. Native rays against the original union hit every sampled center station and missed every sampled helper offset. See [project state](PROJECT_STATE.md) for the verification limits.

## November 17 — continuous contact through short mining interruptions

A cube laser that briefly loses and regains the same contact merges back into one line at the current taper width. When the target actually changes, the old beam can finish its taper while the new target begins. A saved fracture contact yields to a newly active target. Cube render clones clear their inherited local visibility override, and the emitters level out during warmup before firing.

## November 17 — vertical cube miner lasers and field-scoped battery display

Cube miner lasers use the emitter's X and Z for the visible contact, including each Double Beam ray. The laser taper and particle tails still finish after the cut. In the square fields, hide the over-drone battery and the player's battery HUD row while retaining real charge behavior. Keep the battery indicators in the original quarry.

## November 17 — finish mining beams and particle tails

Mining lasers narrow to zero when work stops. A retiring beam can finish its taper in world space if a target, branch or drone disappears first. Stop mining particle emission when work ends, and allow existing sparks, contact dust and charge smoke to complete their lifetimes. Keep drone shells simple gray cubes for the flat-field test. See the flat-field entry in [project state](PROJECT_STATE.md) for verification.

## November 17 — restore the two-piece rock release

Ordinary field rocks and sealed geodes open with the original two solid halves swinging outward from the bottom seam. Use the last rendered size and pose of the rock and the matching fracture cut. The sealed geode keeps its irregular exterior, anticipation and player-controlled opening. Drop trajectories, dust, chips and reward timing still use the existing gameplay paths.

## November 16 — restore every drop arc; reject hinges and oversized prompts

All field stone and gem cargo uses the full existing launch arc. Sealed geodes use the original irregular rock cut and a visible 0.75-second launch, with restrained warm motes/light, no spherical hinged shell or giant halo. Opening trembles briefly and shatters into the existing reward effects; ordinary stone shatters directly. Contents stay hidden until the server accepts opening after landing. The field E prompt is 132×34 px, aim-selected, with the existing white object highlight and selection burst. Thinking means holding position with a tiny float; only that state gets a spinner. Batteries stay visible throughout the accepted plot. This supersedes the shallow stone hops, hinged shell treatment and broad busy-state spinner rules below. Final live visual/motion acceptance remains unverified.

## November 16 — sealed discoveries and object-anchored E prompts

This supersedes the continuous-field power-test/hinged-mining direction below. Ordinary rocks finish and break automatically, with occasional smaller sealed geode drops. Their neutral shell and soft light do not expose the rolled contents. The shell stays nearly closed until the player's 0.85-second opening anticipation; existing field gem geometry, launch particles and audio reveal the actual rewards. Field E prompts sit above their rendered target with a dark compact caption, white keycap and white target highlight. Interaction emits a short bounded burst of white sparkles; reduced-effects mode lowers its count. This is interaction feedback, not client authority to grant a reward. Native component behavior passed; final in-Play appearance, touch and motion remain unverified.

## November 16 — geode shells and ready rewards

Geodes use two spherical native CSG halves sharing a lower hinge. Their dimensions stay fixed while the opening grows to about 24 degrees per half. The field stone finish is lightly shifted; the mineral-colored core appears through the opening. Progressive seams emit small counts of the existing chip, streak/ember, spark, glint, afterglow and dust families. Rejection reverses the hinge quickly and uses a distinct low impact cue plus bounded shake. A ready gem/geode has a large camera-facing glow, local light and spatial hum. E starts a 0.24-second gem or 0.85-second geode anticipation before the server releases the reward. Geodes use the stronger existing split camera envelope and a dedicated lower, longer break cue, followed by gem sounds. Reduced effects/flashing and reduced motion remain respected; loops and shells are cleaned up on removal and at range. No Fortnite audio is copied.

The native Edit component check verifies actual spherical CSG, increasing hinge angle, unchanged size, one recoil cue, ready glow and the requested hum/windup calls with muted audio doubles. It does not establish live sound balance, multiplayer appearance or player satisfaction.

## November 16 — rock gallery, selected value and footer receipts

The owner rejected the preceding separate-panel pass. Use a gallery in which each real rock has its name, final money value and modifier names directly beneath it. Before selling, click a rock to inspect its base money, actual rounded multiplier/bonus and named material rewards in one consistent detail area. Preview footer totals show the quoted complete bag; confirmation resets the cosmetic adding receipts to zero. Each currency retains its own stack, rule and total across the footer, with earlier addends rolled into the subtotal. Narrow screens scroll currencies horizontally. Bags over ten rendered pieces page through the gallery; the animation follows the active page automatically.

While selling, emphasize the active rock and expose its base amount before its modifier. A meaningful bonus appears after 0.22 seconds, and its rock breaks at 0.58 seconds; plain rocks break after 0.24 seconds. Then final currency amounts travel for 0.32 seconds and post together, with only 0.04 seconds before appraisal of the next rock. Keep the 80 ms break, surrounding gem particles, damped number impact and velocity-preserving currency pull. Screen-space impact also moves the gallery itself, since camera-relative ore otherwise cancels world camera motion. Ordinary sale cracks now use the approved imported rock recording with bounded natural-tail sample regions; the old short cue started fading after about 50 ms. Gem and credit tails are longer too. No new audio uploads.

Native Edit validation drove the production update loop continuously: three mixed rocks completed in 2.83 seconds, the modifier preceded its break by 0.35 seconds, and cosmetic currency tokens peaked at six. The actual rock sale voice used a 1.735-second bounded cut from asset 96292866549392. The audio check was muted; this does not claim a listening test. The actual three- and ten-item preview layouts were inspected in Studio, including the prices, modifiers, selected detail and non-overlapping footer. This layout and timing supersede the rejected panel arrangement below. Existing research links remain rationale, not proof of satisfaction.

## November 16 — itemized sale stacks and payout impact

The owner rejected the flat sale and shared addition rule. Each currency now has its own name, separated stack, colored rule and total. Ore captions stay beside the actual field models, the active piece gets a marker, and its name/modifiers remain readable through its payout. Every addend names its source ore. Earlier/hidden terms roll into a displayed subtotal, so the visible arithmetic remains explainable. Short layouts show fewer individual terms with that subtotal; unusually varied cargo can scroll. The world stays visible beneath a light darkening layer.

The design follows proximity grouping and redundant text/color identification: [NN/g proximity](https://www.nngroup.com/articles/gestalt-proximity/), [Microsoft game accessibility metadata](https://learn.microsoft.com/en-us/gaming/game-publishing/concepts/metadata-accessibility). The pacing interpretation follows [Lin et al.'s impact-feedback study](https://arxiv.org/abs/2208.06155), [Fabre et al.'s Juicy Text](https://arxiv.org/abs/2512.13695), and [Kao et al.'s action/feedback experiment](https://people.csail.mit.edu/dkao/pdf/3613904.3642656.pdf). These support coherent action-outcome feedback and readable text; they do not establish that this specific sale is fun or prescribe its timings.

Keep the 0.58-second lead-in and 80 ms break. Anticipation compresses the next rock over 150 ms, followed by a brief outward expansion and collapse. Break sound, bounded camera beat and the existing gem particles coincide. Plain payouts travel for 0.48 seconds. Modified payouts expose the base for 0.30 seconds, then hold the multiplier/travel beat for 0.58 seconds. After posting, wait 0.24 seconds before the next break (plus gem windup). Coins and distinct material flecks burst outward with exponential drag, then use a Hermite pull retaining their outgoing velocity; trails derive length from speed rather than frame count. They arrive at their named addition stack, with no authority to grant money. The total has a damped scale impulse, the addend kicks upward, and the rule thickens briefly with the louder credit tick. Slightly stronger break shake remains limited to manual sales; reduced motion/effects suppress the relevant motion and particles. Final totals persist until E/Close.

Verification: automated sale/persistence checks and native Edit component checks cover exact credit, delayed addition, multiplier separation, token-path continuity, cleanup and separate named stacks. Actual Studio overlay inspected at preview and multiplier phases without starting Play. Live sound balance, continuous gameplay motion, small-device usability and multiplayer satisfaction still need an owner Play check.

## November 16 — handwritten sale totals and glowing ore

Manual sales keep the backdrop in the world. A loose cluster on the left uses the pickup renderer for the field cut, shade, outline, glints and modifier effects, with a camera-facing glow so the ore reads at sale-camera distance. Portrait screens stack the receipt below the rocks. Each roughly 80 ms break triggers the shared gem particles. The base addend appears in its currency column. A modified payout gets a detached, tilted name and multiplier, which fades as the adjusted value posts. The prior addends slide up and the total sits beneath the rule. The payout chime and HUD balance tick coincide with the addition. The totals remain visible until **E** or Close. Automatic sales keep the compact token flights.

## November 15 — sale pacing and larger payout text

The strongest cue should explain the action and its value. Kao and colleagues found in their action RPG experiment that success-dependent feedback helped, while stronger amplification alone reduced the measured motives. Fabre and colleagues found that animated text conveyed feedback reliably in their experiment with text and particle effects. Lin and colleagues identified hit stops, coherent sounds and camera control as important candidates for impact in their observational study. The working interpretation for selling is to put the amount at the center of the break, use a brief windup, and save the strongest accents for gems and the final counter arrival. [CHI feedback experiment](https://people.csail.mit.edu/dkao/pdf/3613904.3642656.pdf), [Juicy Text](https://arxiv.org/abs/2512.13695), [impact-feedback study](https://arxiv.org/abs/2208.06155).

A manual sale waits 0.58 seconds after confirmation and compresses the next rock over its last 0.15 seconds. A normal ten-piece bag uses 0.23 seconds between breaks, with up to 0.115 seconds of extra windup for a gem. Each rock still breaks in roughly 80 milliseconds. Payouts target 33–39 px for cash and 23–27 px for materials, with short mineral names on narrow cells. Amounts hold fully readable for about 1.3 seconds, then fade by 1.68 seconds. The same gem sparks linger longer. Coins drift for 0.31–0.45 seconds before a slower pull. Materials follow in 0.23-second waves after the last break. The final real arrival has a deeper cue and a longer HUD pulse. Treat these timings as game-specific tuning for the next Play test, not results from the cited studies.

## November 15 — currency token flight and arrival

Colored payout amounts linger beside their rock for 0.92 seconds. Green round coins and tinted angular material flecks drift independently of the text and existing gem shatter. Random launch angles, speeds, spins and curves vary the trajectory. A decaying drift carries velocity into the pull. Coins start pulling first, and after the final break the material flecks leave in resource waves. The final motion aims at the current digits of the corresponding HUD counter. Arrival plays a coin tick or material chime and advances the displayed balance by the token's share of the confirmed reward.

## November 15 — sequential sale breaks and gem particles

Each sale rock shrinks and fades in about 65 milliseconds. The grid advances only after that rock is gone, including when the renderer has a slow frame. The existing gem reveal's colored discs and four-point glints replace the sale's square particles. Sale particles use a smaller spread in world space and live for 0.6 to 1.17 seconds, independent of the rock. The reward amounts still pause before flying to the HUD.

## November 15 — selling anticipation and gem reveal

A sale opens a large grid and waits for E. After server confirmation, hold the grid for 0.38 seconds, then cascade through it. Each sale has an impact pose, a camera beat, colored particles and its own crack. Reward icons hold for 0.38 seconds before departing. Courier and automatic transactions retain compact notifications. Reduced Motion removes the shake and particles.

Ordinary rocks hop from near the floor immediately, with a quiet clack and muted break debris. The rare gem keeps its taller arc, launch trail, resting effects and mineral geometry. A distinct reveal sound and mineral-colored launch burst signal the drop, followed by a separate shimmering landing cue. Ballcaster's projectile renderer plays its charge, imported spaceship release, and heavier impact at the corresponding authoritative phases.

## November 15 — owner-supplied rock and weapon audio

Use the Downloads artninja crashes as eight randomized size-aware break cuts,
classified jointly by duration and loudness. Choose size from the full rock,
not its depleted visual stage. Elementus low-mid replaces laser ignition;
distorted spaceship replaces only Ballcaster firing. Preserve Ramiel's base
blast and Orbital's base cue and add synthesized explosion plus cinematic boom
to both. Keep native bounded clip regions, spatial/mute/voice limits, natural
decay and existing authoritative event timing. Nomad remains unchanged. Asset
provenance, measurements and upload receipts are in `assets/audio/downloads/`.

## November 15 — rapid selling grid and immediate field stone

Sell over the actual world with a mild far-depth blur. Raise the sorted ore into a camera-facing grid, then burst and sell each cell in reading order. Small money and material icons travel from the actual cell to its HUD counter. Manual/backpack sales use a short camera beat per piece; the small courier receipt skips blur and camera beats so automated trips do not repeatedly interrupt mining. Honor Reduced Motion and Reduced Effects. Material counters fade after receipt and can be revealed by hovering the wallet area.

Ordinary field rocks appear at rest immediately, with a mineral-specific stone tint and outline. They do not use the crystal launch arc, trail, or idle sparkle. Rare crystals retain their accepted mineral geometry and launch treatment. Emptiers retain the stone appearance while carrying it; Compactor outputs preserve both currency and material yields. The owner-requested Compactor ejection arc remains separate from the instant ordinary mining drop.

## November 15 — two continuous grapples and a visible pickup outline

Use a separate cable from each Compactor winch to a claw on its own rock. Keep both cables drawn through the buffered reel and remove them at seating. Add screen shake when the claws latch, the jaws press and the larger gem ejects. Use the actual ejection point for the burst. Temporarily render highlighted gem shells opaque so the native white or amber outline draws around their faceted shape.

## November 15 — Compactor grapples and the rapid Needler

The Compactor reaches clear space before marking the pair. Two cables cast together and reel the real drops in. When the merge bar fills, eject the larger gem in its normal rising and falling arc, with existing trailing particles and landing effects. Needler fires four times as often with smaller hits, recoil and camera beats. Keep Ballcaster's slower release and heavier contact. The selected plot floor stays white; status color belongs on the edges.

## November 15 — direct reel on capture

Use a taut cable and lift the rock straight into the cradle on capture. The courier keeps climbing and turning while reeling in. The owner removed the slack and dragging effect.

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
| [BeamVFX.lua](../src/BeamVFX.lua) | Thin beam vocabulary, charge (core, lifted cubes, slashes, incoming bolts, glitter ribbons, orbiting flares, rings, wedge spikes), popping neon glitch orb, charge rig pooling and cue lifecycle. |
| [EnergyDisc.lua](../src/EnergyDisc.lua) | Shared particle look: round discs (toned down), plus separate spark and smoke helpers. |
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
