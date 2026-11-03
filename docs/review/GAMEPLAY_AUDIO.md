# Gameplay sound feedback

November 2, 2026. Same Drone Blower revolution game, place **136098934779395**, branch `codex/restore-feel-prestige`.

The owner requests substantially more relevant sounds, particularly falling rock fragments and drones charging. Existing music and `CrystalAudio` are preserved. This pass adds:

- Spatial rock landing sounds with three rubble variants. Collectible landings use fresh, increasing server contact receipts containing exact contact position and speed. Resting floor clamps stay silent. Cosmetic stone chips and broken drone parts sound once when their ballistic animation reaches the floor; old contacts after a suspended frame are skipped. Chips now survive long enough to reach the ground.
- Rising mining, breaker, combat, healer, grower, orbital and swarm charge sounds; a sustained cutting texture, speed-sensitive flight servos, healing and parcel transfer beds; breaker dive, laser release/recovery, confirmed crystal planting, courier latch/unload/sale, shots, shield hits and reconstructed-drone cues. Orbital burn audio follows fresh authoritative contacts and stops when the burn ends or loses contact.
- Shared button feedback, accepted/rejected command cues, a single backpack-full warning, and sounds for confirmed shop upgrades. Pack/card/prestige/sale accents still wait for confirmed profiles; joining or reconnecting does not invent rewards.

## Asset provenance

Free Toolbox / Creator Store search results from ProSoundEffects; all seven new assets loaded successfully in the existing Studio client. Existing crystal samples and music remain unchanged.

| Asset | Use |
| --- | --- |
| [Rock Hitting Rock / Debris 6, 9125869504](https://create.roblox.com/store/asset/9125869504) | Rubble landing variant |
| [Rock Hitting Rock / Debris 7, 9125869495](https://create.roblox.com/store/asset/9125869495) | Rubble landing variant |
| [Rock Hitting Rock / Debris 3, 9125869138](https://create.roblox.com/store/asset/9125869138) | Rubble landing variant |
| [Synth Power Up Multi Tone Wind Ups Rise 2, 9119816710](https://create.roblox.com/store/asset/9119816710) | Charging capacitors |
| [Servo Motor 1, 9118941667](https://create.roblox.com/store/asset/9118941667) | Flying, transfer and dive motors |
| [Servo Motor 2, 9118941971](https://create.roblox.com/store/asset/9118941971) | Grower, healer and mechanism details |
| [Giant Servo Motor Powering Up 2, 9114583503](https://create.roblox.com/store/asset/9114583503) | Heavy breaker/swarm windup |

The mixer supports six sustained spatial beds and at most 22 total action voices, with four rubble voices at a time. Priority and proximity favor significant work over distant motors. Sounds fade, attenuate with distance and share the existing Effects mute. Stale loops expire after 0.3 seconds without renewal, even when a renderer misses cleanup. Missing sustained clips remain silent instead of repeating a generic fallback. One-shot fallbacks remain available. Destruction/mute clears owned anchors and sounds. Button event connections belong to the buttons and do not accumulate historical menu references.

## Two source reviews

Behavior/parity: audio observes current authoritative states and fresh serials. No damage, reward, targeting, ore trajectory, fleet, persistence, card-selection or original flight equations are replaced. The trajectory's extra return value reports downward contact without changing its existing positions/velocities or pickup result. Crystal audio and all preserved assets/backups remain intact.

Pacing/presentation/multiplayer: charge precedes release; sounds follow work and ground contact, rather than guessed client damage. Mix caps, distance limits, old-event suppression, pause/death cleanup, late-join baselines, stalled-frame handling and bounded lifetimes were reviewed. Only cosmetic fragment lifetime changes. These checks do not establish mix quality or multiplayer acceptance.

## Reproduction and evidence

Run `python3 tools/test_audio.py /private/tmp/mining-away-luau`, `python3 tools/test_gadgets.py /private/tmp/mining-away-luau`, and `python3 tools/test_mining_flight.py /private/tmp/mining-away-luau` with the repository's pinned Luau 0.744 binaries. The audio command compiles all source files and both real generated controllers, runs 6 audio event checks, 5 pickup trajectory checks, 20 existing feedback checks, 8 real bundled-server pickup checks with API doubles, and 3 real cosmetic-fragment checks with API doubles. It writes `build/audio-runtime-check.lua`, which can be executed on an existing Studio Client.

The actual Studio client passed eight **muted** API/loading/lifecycle checks: spatial charge reuse, pause release, six-bed priority/cap, distance culling, loaded rubble variants/four-voice cap, effects mute, stale-loop expiry and dynamic native-button binding. Destruction returned action voice count to zero. These are engine checks of the audio module, not an auditory audition or a full-game playtest. Logs are in `build/audio-tests.txt`, `build/audio-gadgets-tests.txt`, `build/audio-flight-tests.txt` and `build/audio-engine-check.json`.

The broad legacy `tools/test.py` run stops on existing HUD typography (`Backpack` at 11 px), and then on the existing radius-10 formation assertion if that first guard is bypassed. Neither is caused by this audio pass; the focused production suites above pass. Do not report the broad suite as green.

Build from the immutable verified live capture using `python3 tools/release.py`. `build/revision.json` records the exact committed source and output checksum. Concurrent UI changes in the shared workspace must be preserved and excluded from an audio-only commit. A running Play session does not hot-load a saved controller automatically.

Final listening/mix balance, the complete installed gameplay path, busy two-player/late-join behavior, mobile speaker/headphone balance and published-server asset permissions remain **NOT VERIFIED**. Nothing is published to Roblox and no new experience is created.
