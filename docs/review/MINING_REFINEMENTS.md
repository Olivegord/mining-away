# Mining, energy and physical animation refinements

November 2, 2026. Existing **Drone Blower revolution**, place **136098934779395**, branch `codex/restore-feel-prestige`. The source revision and primary/native place checksums are stamped in `build/revision.json` after the clean commit. Roblox publication and a main merge were not performed.

## Behavior

Collectible ore scatters for 0.6 seconds with gravity, floor contact and bounded bounce, then accelerates toward available backpack space. Drops fade from 13 to 18 seconds and expire on the server at 18 seconds, including while the backpack is full or storage is busy. Coalescing rewards does not refresh the old fragment's lifetime. Owner/run checks, integer rewards, partial collection, obstruction checks and authoritative ground-impact sounds remain. The client buffers 0.1 seconds of snapshots and interpolates bounded tangents, avoiding repeated snapshot-chasing corrections. Its pose settles rather than continually pulsing size or hovering. Confirmed per-fragment collection finishes in a short pull-in arc; the exhausted source remains briefly for replication, with zero collectible units. Disappearance alone never grants ore.

Mining uses plain soft round energy sprites with bloom, gravity and differing spread/drag/noise: yellow cutting contacts, cheap miniature swarm chips, heavier turbulent orbital particles and a lingering afterglow. Ordinary cracks release three real authored mesh fragments; final breaks release nine with ballistic movement, landing cues and bounded cleanup. The fragment pool is capped at 48; detailed mining rigs and bursts also have caps. Original meshes and asset templates remain.

The orbital extends 260 studs and its local ramp continues above high cameras. A single white beam uses moving opaque/clear bands, with the old solid columns locally suppressed so they cannot wash out the gaps. Source visibility is restored at cleanup. Stale authoritative contact disables the local strike during a save/pause; fresh contact resumes it. End collapse lasts 0.48 seconds, followed by bounded energy afterglow. The initial native solid-column capture exposed the visibility problem; it was corrected after inspection.

Smasher progression is **anticipate → accelerating powered descent → sharp physical landing → one-second held weight → damaging fracture → recovery**. The original `p^2.6` fall was already accelerating, but feeding it through the client's arrival spring visibly braked before contact. The strike now evaluates the server-clock trajectory directly, ends with zero velocity, and stops at the actual model/rock surface without bank or bob. Follow flight retains its existing motion. Complete phase snapshots precede effects; physical contact and damaging fracture have separate timestamps/serials and fresh, deduplicated shake/audio receipts. Contact uses a lower short thud; fracture a different brighter rock sample. Character-distance attenuation preserves nearby shake when the camera is zoomed out, while reduced-motion settings still suppress it. The duplicate weightless ball-debris tweens were removed.

The longer hold is compensated with a 96-point base hit, retaining the existing shell advantage. An actual bundled-server steady-work probe measured the previous 72-hit/short-hold behavior at 27.34 DPS and the new 96-hit/one-second hold at 27.30 DPS. This is a mechanical comparison excluding initial travel, not a native feel or fun result. Cooperative rock shrink updates contact height; another worker breaking the target safely sends the smasher into recovery and preserves legitimate shell-to-core continuation.

Before Plot Scanner, clicking targets a single rock. After earning it, the same gesture targets/highlights the field. There is no extra Automate control, floating command instruction or unlock mode panel. Leaving the rotated field footprint plus 18 studs silently clears work, queued orders, abilities and reservations. Replicated recall timestamps produce a brief hop/nod before following; an immediate new work order cancels that flourish. Accepted orders no longer produce routine text notices. Rejections still explain failures.

Gadgets charge and release automatically. The timing track, cursor, precision window, TAP prompt and timing-dependent rewards are removed; equipment perks determine effects. Their shop terms were updated. Fleet now contains **Fill backpack** and **+ Miner / Courier / Healer / Grower / Smasher / Orbital / Swarm** buttons in Studio. Server and UI gate them to Studio; additions affect preview ownership only and preserve existing active drone jobs. The production profile still begins with one permanent drone.

## Reviews and regression evidence

Behavior/parity and separate pacing/presentation/multiplayer source reviews covered authority, ownership, saved offers, permanent identity, shared flight, original assets, pickup conservation/expiry, field bounds, interrupted phases and observer consistency. Findings repaired during review include a recall flourish overlapping a new strike, cooperative target retirement during held contact, inconsistent pickup prediction gravity, late receipt coalescing, contact/frame ordering, duplicated startup impact cues, braking caused by layered animation smoothing, camera-zoom shake suppression, and duplicate weightless debris.

Focused reproducible checks use pinned Luau 0.744 at `/private/tmp/mining-away-luau`:

```sh
python3 tools/test_refinement_client.py /private/tmp/mining-away-luau
python3 tools/test_energy_effects.py /private/tmp/mining-away-luau
python3 tools/test_audio.py /private/tmp/mining-away-luau
python3 tools/test_gadgets.py /private/tmp/mining-away-luau
python3 tools/test_mining_flight.py /private/tmp/mining-away-luau
python3 tools/test_shops.py /private/tmp/mining-away-luau
/private/tmp/mining-away-luau/luau tests/pickup-motion.spec.lua
```

These pass source/controller compilation, production domain logic, bundled server/client logic with API doubles, observer routing, physics/phase envelopes, pickup interpolation/expiry, current shop/persistence behavior and deterministic live-capture preservation. Logs are `build/refinement-*-tests.txt`. The broad historical runner is not claimed green: unchanged legacy fixtures still expect old formation radius, schema version and static typography. API doubles, analysis and binary checks do not render Studio, test networking or establish enjoyment.

## Native evidence

The existing Studio Edit place was checked against the exact previous generated source before installation. `ScriptEditorService:UpdateSourceAsync` handles the large controllers; all seven resulting Sources are compared by full equality. The other 39 scripts remain unchanged. Native local Save was performed and the saved editable file's seven Sources were read back and matched. The primary release still builds exclusively from the immutable verified live capture, changing only the exact seven Source paths. No source asset is overwritten.

A real production Play session, real ore order and read-only observers established:

- The timing widgets are absent. Fleet's eight dev buttons are present and render within its existing menu. **Fill backpack** reached **40/40**; a named addition changed active crew **8 → 9**, while permanent ownership remained **1 → 1**.
- Crossing padded field bounds cleared targets and the queue, published recall timestamps and left the notice unchanged. Couriers with already-held parcels continued legitimate delivery; workers followed.
- Before the final descent correction, actual server transitions held contact for about 1.0 seconds before each 96-point fracture. The final client observer records sharp contact at zero distance from the authoritative impact plane and different loaded contact/fracture sounds about one second apart. It samples the installed rendered drone, not a synthetic trajectory. `tests/heavy-impact-observer.studio.lua` reproduces this read-only observation after a normal order.
- Actual uncollected drop **117** had transparency **0.7366** at age **16.69 seconds**, then was removed after its **18-second** deadline without a collection receipt. The observer's first shorter recording ended before later drops' deadlines; that recording is not counted as expiry evidence.
- Native orbital inspection found the custom Beam's fully clear keypoints, moving phase, and both solid source columns locally hidden (`LocalTransparencyModifier=1`). The column extends beyond the ordinary view. A single screenshot cannot establish fast motion quality.
- Eleven actual engine audio/loading/lifecycle checks pass, including different loaded spatial contact/fracture clips, music-off startup, distant-camera audibility, voice caps and cleanup to zero. This harness is muted; these checks do not establish subjective listening approval. The production observer separately saw both real impact clips loaded during work.
- The final inspected console had no game script errors.

[Native Fleet/dev controls](REFINEMENT_DEV_TOOLS.png). The [initial orbital capture](REFINEMENT_ORBITAL_BEFORE_STRIPE_FIX.png) records the solid-column problem that prompted the band-visibility repair; it is diagnostic evidence, not a final visual approval.

Native install, initial work/expiry, heavy-observer and audio results are preserved under `build/refinement-native-*.json`. Desktop screenshots, local client observations and source review do **not** establish two-player/late-join visual quality, touch/controller activation, low/high graphics, real DataStore behavior, final listening comfort or player satisfaction. Those remain unverified.

## Integration and reproduction

The gameplay-audio chat reported clean baseline `a3dda1e3bb83fc66f492114ab47ac10802577f55` and ceded installation ownership to this chat. The subagents owned server/domain rules, controls/client animation, and energy/presentation respectively; the primary chat owned pickups, audio cue definitions, native installation, build and commit. The existing character-position audio listener, music-off default and unified card/HUD work are preserved. This coordination follows the owner's authorization in AGENTS.md.

For a fresh exact-baseline native install:

```sh
python3 tools/stage_studio_install.py --previous-commit a3dda1e
python3 -m http.server 8767 --bind 127.0.0.1 --directory build
# Execute build/refinement-studio-install.lua in the existing Studio Edit model.
# Native Save the existing editable .rbxl, then verify its Sources.
python3 tools/release.py
```

The guarded installer also accepts an exact previously installed staged payload for iterative local review. It stages both payloads before mutation, verifies every live source, preserves all unrelated scripts, rolls back on installation failure, and restores HTTP enablement immediately after its local transfer. `build/revision.json` records the clean integrated commit, immutable base hash and resulting place hashes.
