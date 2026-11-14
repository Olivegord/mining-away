# Large sentry animation revision — October 25, 2026

This supersedes the earlier subtle idle/recoil pass. The owner's requested
sequence is the presentation contract: a solid dormant pyramid; a full turn
while the layers spread far apart; a weighted settle into active spacing;
then eye ignition, a sound, a flash and a broad lens flare facing the player.
Dead pieces accelerate downward, thud on contact and remain embedded.

## Choreography and original geometry

- Dormant shell rims telescope together. Bounding-box contact alone left the
  authored lower shell's eye cutout open; overlapping the original rims closes
  the opening without adding substitute geometry. Eye and housing retract.
- A 2.8-second wake sequence spins the original meshes one full revolution.
  Each ring has its own launch/settle timing. The crown rises approximately
  26 studs from its closed position, opening a roughly six-stud stack to over
  thirty studs high, then settles into a roughly fifteen-stud active construct.
- After the turn, the eye and housing face the triggering player's replicated
  position. Ignition occurs at 2.15 seconds, during the existing four-second
  server muster and before firing. A mechanical wake sound precedes a sharper
  ignition sound, a white eye flash, local light and a 32-stud lens flare.
- Active layers float independently with staggered phases. Analytic underdamped
  yaw/pitch springs retain momentum. Charges draw the eye back; firing kicks it
  backward and drives a wave of compression through the rings. Damage makes
  the shell lurch, lean and recover. Recall/reset eases the construct shut.
- Death removes lift rather than playing an explosion. Four stone layers and
  the eye/socket assembly fall independently under 68 studs/s² gravity, with
  short staggered release times. Each hits once with a low-pitched thud and dust.
  Tilted stone bounds finish partly inside the field plane. No bounce, fade-out
  or perpetual jiggle follows contact. Ruins persist until encounter reset.

All seven original construct meshes remain. The plinth stays fixed. The eye,
secondary lens and housing share a pivot while alive and a rigid fall group
when destroyed. All transforms derive from immutable frames; simulation never
reads local cosmetic poses.

## Server and observer correctness

The server replicates `Awake`, `WakeAt`, `ActivateAt`, `WakeAim`, `WatchPosition`
and `DeathAt`. The first valid fresh muster sets wake timing once; a teammate
joining cannot restart the spectacle. The triggering player remains the watch
target, with another participant taking over if that player leaves. The live
telegraph and brief shot follow-through override watching to aim at the drone.
Reset clears wake, aim and death state. Direct and chained kills publish one
stable death timestamp.

A late join samples the current wake/settle pose from server time. Already-past
wake/ignition/impact audio is suppressed. Final ruin transforms are deterministic;
ground sampling uses the owning field plane, so shrinking crystals cannot hold
slabs in midair. A suspended frame skips old impact sounds instead of replaying
them together. Sounds and dust use the existing bounded cosmetic cleanup pool.
Original targeting, damage, health, anti-attrition, rewards and persistence remain
server-owned; no new client command or paid asset was introduced.

## Behavior/parity review

- Original geometry and binary-preservation tests pass. The original drone travel,
  overhead mining, staged crystals and fleet persistence paths are untouched.
- Fifteen standalone motion tests cover a completely still closed stack, large
  launch amplitude, full-turn completion, delayed eye reveal, timestamp sampling,
  a continuous launch/return velocity, independent recoil/flinch, shortest-arc tracking, 30/60/120/144 FPS spring
  convergence, charge release, staggered accelerated falls and immovable ruins.
- Added production-server/API-double regressions cover one wake per muster,
  triggering-player aim, observer snapshots, no shots during the opening,
  stable death timestamps and complete reset. These are not network playtests.

## Pacing, visual and multiplayer review

The production renderer was inspected in the connected Studio Client using
controlled authoritative snapshots at matching camera positions: closed stack,
wide spinning separation, ignition facing the camera/player, and grounded ruins.
The eye facing dot product at ignition was 0.99995. Studio measured a 26.3038-stud
crown excursion from the closed stack. A screenshot showed the broad horizontal
flare, white eye and surrounding light flash. Audio assets are installed engine
content; tests establish creation/timing, not subjective audio quality.

`tests/sentry.studio.lua` ran 44 assertions over 1,527 real-Instance/CFrame renderer
samples at simulated 30/60/144 FPS. It verified the large flare, one wake/ignition
pair, eye facing, layered threat beams, duplicate-shot suppression, flinches,
five separate impact sounds, exact post-impact immobility, reset to a closed
stack, living closure with a rigid socket, and silent late-join ruins. Base drift
was zero; maximum eye/housing relative-position error was 0.0000097 studs.
Fixtures were removed afterward.

Installed the complete current server/client bundles in Edit and started Play.
A normal Cobalt Fight command produced a 26.3028-stud crown rise, 23 visible-flare
frames, four actual server shots, 62 charging frames and 74 visible-beam frames.
Eye/player facing stayed at or above 0.99998 during activation. This exposed a
closing-only socket drift in independently interpolated world frames; the final
rigid assembly fix passed the expanded engine regression above. The Studio
console was empty. Studio was then released to the coordinated map review for
its final combined-source install and walking checks.

Controlled renderer samples are not measured rendering FPS or a two-player
session. Two-client synchronization, latency and subjective sound remain to be
verified. Nothing was published to Roblox.

## Reproduce

```sh
python3 tools/test.py /path/to/luau
python3 tests/binary.spec.py
python3 tests/geometry.spec.py
python3 tools/release.py
```

For the engine test, temporarily install a client ModuleScript named
`ReplicatedStorage.SentryReviewModules` containing
`module_bundle(('Feedback','SentryMotion','Presentation'))` from `tools/build.py`,
followed by `return {Presentation=Presentation,Motion=SentryMotion}`. Execute
`tests/sentry.studio.lua` in Client context and remove the temporary module.
The fixture cleans up its models and effects. Build only from
`assets/mining-away-base.rbxl` to `build/Mining Away.rbxl`; the release metadata
records its exact source revision and checksum.
