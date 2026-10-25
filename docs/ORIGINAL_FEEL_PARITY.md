# Original Mining Away feel: restoration contract

Restore the original game's movement, rock placement/growth, mining presentation and existing art while retaining authoritative multiplayer gameplay, geodes, guarded later patches and free reprinting. The previous cloud build changed too much of the original feel. Treat this as a targeted repair, not another world/art replacement.

## Evidence and source priority

1. The user's current requirements and the live Studio observations below take precedence.
2. `cloud-handoff/mining-away-source-bundle.json` contains the original historical `.rbxl` (base64, SHA-256 `480ce776e7e7c5bda5be57666490c8c9e203b35f8d9fa462de894230494ef78b`) and original Luau under `files`. It is the December 18, 2023 autosave, not a fresh export of live Studio.
3. `cloud-build/mining-away-cloud.rbxl` is the rejected first cloud result. Its replacement `GlobalDroneControl`/`ClientDroneControl` explain the regressions; retain useful security/combat rules but repair its presentation and movement.

Original bundle paths: `files.ClientDroneControl_3.lua`, `files.GlobalDroneControl_2.lua`, `files.MainModule_1.lua`. Original enabled paths: `StarterPlayer.StarterPlayerScripts.ClientDroneControl` and `ServerScriptService.GlobalDroneControl`. Legacy `StarterPlayer.StarterCharacterScripts.DroneControl` is disabled. Do not accidentally enable that second simulator. The original `Walltest` is an unrelated incomplete experiment and must not drive the repaired game.

Live Studio inspection confirmed quarter-health crystal changes with `RockCrack` and `RockBreak` sounds, ruby count 16, cobalt count 3 and cargo 2,000. Live notes report a `v.crystal.Scale = healthPeriod * maxHealth / 25` assignment; this appears to be a data-field assignment rather than an actual mesh resize and must not be copied blindly. The historical source explicitly writes `mesh.Size`. Preserve the intended visible staged mining, not an ineffective field or frame-dependent damage.

## What changed in the cloud build

| System | Original | Rejected cloud implementation | Required repair |
| --- | --- | --- | --- |
| Travel | `.03` position easing, capped per drone at `.2–.5` studs/frame | Constant 24 studs/s plus `.5` pose lerp at 10 Hz, then another client low-pass filter | Restore original ease/cap feel with dt correction; one visual interpolation layer |
| Follow | Radius-10 ring, +7 height; small slow hover | Straight row behind player, +6 height; faster bob | Restore ring and original hover amplitude/frequency |
| Mining station | Exactly crystal X/Z, crystal center +10 Y | `(slot-2)*2` X, +6 Y, +5 Z | Ordinary drone directly over its own rock, no sideways/rear offset |
| Mining start | Within 1 stud of assigned hover station | Within 17 studs of crystal, including during approach | Server arrival gate before mining, beam and reward progress |
| Facing | Horizontal yaw, smooth turn; never nose-dives at rock | `CFrame.lookAt(dronePos, rockPos)` pitches body down | Restore stable level flight and yaw smoothing |
| Crystal layout | Random patch X/Z each spawn | Fixed four-column grid | Server-random placements each spawn; stable replication |
| Crystal form | Original crystal union; random 50–100 health and proportional size | Fixed stretched `(2,5,2)` ordinary mesh; fixed tier HP | Preserve original silhouette and per-rock size variation |
| Arrival of rocks | Two-second growth/rise; unavailable until ready | Full-size instantaneous spawn | Restore growth and server readiness gate |
| Mining stages | Three quarter thresholds, staged size/rotation/crack sounds | Mostly highlight/color changes; decorative lines only on geodes | Restore three clearly visible changes on ordinary crystals too |
| Turret art | Existing segmented pyramid model | Generic red box | Bind enemy behavior to existing `Workspace.construct` art |

Do not remove the original scene or move the entire experience onto newly generated platforms as part of this repair. Integrate the later guarded patches into the original visual vocabulary. Avoid crowding the scene with permanently visible diagnostic labels; expose useful player information without obscuring the rock/drone animation.

## Exact original movement reference

Original creation:

```lua
speed = 0.03
maxStep60 = math.random(20, 50) / 100 -- 0.2..0.5 studs per 60 Hz frame
formationOffset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 10
angle = math.rad(360 / fleetCount * slot)
```

Original visual update takes 3% of remaining distance per frame, clamping that displacement to `maxStep60`. Rotation blends 10% per frame. At 60 FPS this means maximum travel speeds of 12–30 studs/second, with natural deceleration near the destination. The uncapped positional time constant is approximately 0.547 seconds (`-1 / (60 * log(.97))`); rotational time constant is approximately 0.158 seconds.

Use a shared pure movement helper, for example:

```lua
local function approach(originalPos, goal, maxStep60, dt)
    if dt <= 0 then return originalPos end
    local delta = goal - originalPos
    local distance = delta.Magnitude
    if distance < 1e-5 then return goal end
    local alpha = 1 - (1 - 0.03) ^ (60 * dt)
    local step = math.min(distance * alpha, maxStep60 * 60 * dt, distance)
    return originalPos + delta / distance * step
end
local turnAlpha = 1 - (1 - 0.10) ^ (60 * dt)
```

At `dt = 1/60` this is the original translation rule exactly. Other frame rates preserve its time scale and capped speed, with a small approximation near the cap/easing transition. If strict cross-rate path equality is required, run this helper on fixed `1/60` simulation substeps and compare paths at matching simulated times. Handle stalls with a bounded accumulator and an explicit catch-up policy; do not feed an unbounded frame stall into combat, skip gates, or run an unlimited catch-up loop. Test the policy rather than silently substituting a new travel model.

Original goals and hover:

```lua
-- Following (ring is world-aligned in the original source):
hover = math.sin(serverTime + maxStep60 * 200) / 3
followGoal = ownerRoot.Position + formationOffset + Vector3.new(0, 7 + hover, 0)
-- Assigned ordinary crystal (original has no mining bob):
mineGoal = assignedCrystalPosition + Vector3.new(0, 10, 0)
-- Waiting at patch:
idleGoal = patch.Position + formationOffset + Vector3.new(0, 10, 0)
```

The original hover amplitude is 1/3 stud and angular frequency 1 radian/second (period about 6.28 seconds), with per-drone phase `maxStep60*200`. The cloud's doubled-frequency bob, added once in the caller and again inside `position`, is not parity. For mining, first restore the original steady station. Any extra breathing hover must remain tiny and preserve exact X/Z alignment.

For ordinary mining, require logical position within 1 stud of `mineGoal`, valid reservation, ready resource and allowed defense state. Require the beam target to remain the same valid resource. The old 17-stud range check allows mining well before arrival and must not remain the sole arrival test.

For yaw, flatten the look target to the drone's current Y before creating `CFrame.lookAt`. If horizontal distance is nearly zero, retain the last valid yaw (or blend toward the owner's yaw, as the original close-arrival branch did); never create a zero-direction CFrame. Keep pitch/roll level. The beam aims down independently of body rotation. Multi-drone geodes may use tightly bounded slots over the geode footprint, not the rejected five-stud side/rear station for every resource.

## Authority and all-client smooth presentation

The server owns drone ID/life/owner, health, logical position, speed/phase seed, state, assignment, target, arrival permission, mining/combat damage and rewards. Clients request intent using validated IDs. Never restore the historical client's `.3` health subtraction or trust the local visual pose for reach or hits. The historical `.5` health subtraction per server Heartbeat becomes **30 health/second** at the 60 FPS reference; starting parity ordinary-rock break times are approximately `(maxHealth - 10) / 30`, or 1.33–3.0 seconds after arrival for health 50–100, excluding effects/network delays. Tune enemies separately.

Every client, including non-owners, should render the same server-owned drones smoothly. Replicate stable authoritative records/attributes or snapshots containing server time, logical position/heading, state, target ID, movement tuning, phase seed, health and lifecycle. Include a complete current snapshot for late joiners; do not rely only on past spawn/state-change events.

Avoid the existing double lag: the cloud server lerps its already-integrated logical pose by `.5` at 10 Hz, then clients lerp that result again. Publish logical poses directly; use one coherent buffered interpolation or the shared goal-driven presentation model with bounded reconciliation. All clients need the visual renderer, not just each drone's owner. Cosmetic interpolation can run every RenderStepped; server gameplay never reads those local transforms. Keep logical and rendered drone identity distinct enough that network transform replication does not fight local presentation every packet.

Beam start attaches to the existing drone emitter in the **rendered** pose, beam end to the assigned rock's current visible surface. Use `Attachment.WorldPosition`/proper object-space conversions; do not copy world `Emmiter.Position` into an attachment's local position as historical `CreateBeam` did. Reuse `ReplicatedStorage.MiningFX.Beam` (`InnerBeam`, `OuterBeam`) and `MiningEffect`/`InnerMiningEffect` when appropriate. Original show tween: inner width → .3 over 2 seconds; hide tween: both beam layers → 0 over .2 seconds. Preserve the soft build/hide feel while ensuring state changes cannot leave stale tweens or effects active. No gameplay waits on a cosmetic tween.

## Crystals: random placement, growing, three visible changes

Clone the original `ReplicatedStorage.Crystal.Mesh` union. Preserve its underlying shape/material and avoid replacing it with a generic prism. Randomize on the server once per spawned resource; publish the result, never re-roll independently on clients.

Historical placement/growth:

```lua
maxHealth = randomInteger(50, 100)
fullSize = Vector3.one * (maxHealth / 25) -- isotropic scale: 2..4 studs
x = patch.Position.X + random(-patch.Size.X / 2, patch.Size.X / 2)
z = patch.Position.Z + random(-patch.Size.Z / 2, patch.Size.Z / 2)
startPosition = Vector3.new(x, patch.Position.Y, z)
endPosition = Vector3.new(x, patch.Position.Y + 2 + fullSize.Y / 2, z)
-- Tween size from near-zero to fullSize and position start→end over 2 seconds.
-- Only then set server resource readiness true.
```

The original patch planes are sampled axis-aligned. For a rotated patch, sample local X/Z and transform through its CFrame. A small bounded separation/inset check is acceptable to avoid bad overlaps, but retain organic random spacing; no deterministic rows. Make growth late-join safe using server `spawnTime`/`readyAt`, final size/position and a consistent tween. Use a small positive minimum render size if zero is invalid. Clear reservations when a crystal retires.

**“Three stages” means three changes at 75%, 50%, and 25% remaining health**, after the initial intact rock, followed by depletion. It does not mean thirds of health. The original `healthPeriod` starts at 1 and decrements by .25 on each threshold. Historical visible size is `fullSize * healthPeriod`: intact 1.0 → .75 → .50 → .25. Its color between stages is `Color3.new((healthPercentage / healthPeriod) - (1 - healthPeriod)/4, 0, 0)`. Preserve material-aware colors for cobalt/other minerals while retaining this readable progression.

The live version also changes rotation randomly by roughly ±40 degrees on stage transitions and plays a cloned `ReplicatedStorage.RockCrack` parented to the rock, destroying the sound when it ends. On depletion it hides the mesh, grants 20 ore once and plays `RockBreak` similarly. Do not repeat the crack every tick. Keep crack/break cues on ordinary rocks, not only geodes. The original mining cutoff is `health <= 10`, rather than zero; either preserve this timing or explicitly normalize effective work to `maxHealth - 10` while keeping the same durations and threshold presentation.

Use server health to derive/publish monotonic fracture stage (0–3), growth readiness and one break serial. Process every threshold crossed by a large damage step in order, without duplicating rewards/effects. Do not require four frames to catch up as the old `if/else` did. Stage changes must visibly reshape/rotate or fracture the rock, not only add a faint highlight. Beam impact follows its current top surface (`rock.CFrame:PointToWorldSpace(Vector3.new(0, rock.Size.Y/2, 0))` for an unrotated-upright surface approximation; use a deliberate impact point for rotated geometry).

Keep ordinary individual respawn pacing close to original: hide/deplete, retain break audio briefly, remove at about 2 seconds, grow a replacement after roughly 6 more seconds, mineable after its 2-second growth. Live notes observed an additional 2.2-second reacquisition delay; avoid turning that incidental wait into mandatory dead time when a ready target already exists. New geodes can remain a bigger payoff without replacing ordinary crystal behavior.

## Existing pyramid enemy art

There is no instance literally named `Pyramid` or `Turret` in the original binary. The segmented construct is the strong matching candidate and is confirmed by the user's reference/live scene context:

```text
Workspace
  construct (Model)
    basepart (Part)
    bottemseg (MeshPart)  rbxassetid://14477420875
    lowerseg (MeshPart)   rbxassetid://14477422793
    upperseg (MeshPart)   rbxassetid://14477425917
    topseg (MeshPart)     rbxassetid://14477427275
    eye (MeshPart)        rbxassetid://14477430698
    eyecase (MeshPart)    rbxassetid://14477428635
    spawnEye (MeshPart)   rbxassetid://14477430698
    AnimationController
    AnimSaves (Model)
```

Preserve the exact `bottemseg` spelling when binding. Clone/store a template from the original model; retain mesh IDs, relative transforms, silhouette and existing authored appearance. Choose `basepart` or a deliberate stable pivot; bind health/targeting to an invisible queryable hitbox if necessary. Attach aiming, shot telegraph and damage effects to its eye. Do not replace its visible body with a red box, and do not delete animation data simply to make targeting convenient. If full rig playback is unavailable, a restrained eye/head yaw plus charging/firing animation is enough for this update. Verify its visual appearance in Studio before claiming the original art was reused correctly.

All turret decisions and damage remain server-owned. Preserve the first cloud build's useful anti-attrition rules: fixed eligible assault lives, no replacement drones entering a damaged encounter, complete turret reset on wipe/abandonment, and no mining until all defenses clear. Reprinting stays free and preserves ownership/hardware. Restore game feel without reintroducing client authority or brute-force progression exploits.

## Required validation

- Record a short original-versus-repaired Studio comparison: idle follow, a 30+ stud assignment, final approach, mining directly overhead, all three rock changes, break, random regrowth and recall. Use matching camera/scale. Identify any unavailable live-source details honestly.
- At 60 FPS, compare the shared helper against the original `.03`, `.2–.5`, `.1` reference for fixed goals; positions/turns should match to floating-point tolerance. Compare 30/60/120/144 FPS over equal elapsed time and document the small cap-transition tolerance (or use fixed substeps for equality).
- Follow goals form a radius-10 ring at +7 Y. Hover remains ±1/3 stud with ~6.28-second period. Moving/turning the player does not snap the drones or pitch them downward.
- For ordinary mining, each drone's settled X/Z is within a small rendering tolerance of its own crystal's X/Z; original +10-stud station is preserved. No mining damage/beam before the logical one-stud arrival gate. Impact stays on the shrinking rock.
- Spawn a representative set of rocks: positions vary on each refresh, remain inside intended patches, size varies with server-generated 50–100 health, and growth/rise lasts two seconds. A growing rock cannot be mined. No shared-client reroll or grid layout.
- For known max health, verify stage transitions exactly at 75/50/25%, one crack event each, then one break/reward. Test large damage crossing multiple stages and duplicate final-hit calls. Ordinary rocks must show stages as clearly as geodes.
- Two-player Studio test: each sees both fleets with comparable smoothness, stations, beams, rock growth/stages, pyramid firing and destroyed/reprinted drones. A late join during mining and growth receives correct current state without replaying old crack/reward events.
- Abuse intent remotes/forged owner IDs/targets and interrupt with recall, target destruction, disconnect or reprint: server remains authoritative, no duplicate reward, no stale beam/reservation, no restored retired life.
- Fail a high-tier assault several times: free reprints do not accumulate damage on turrets; reset health is full; no ore is mined behind live defenses. Retain existing anti-attrition tests.
- Verify the visible enemy is the original segmented `construct`, not a replacement primitive. Existing scene/assets remain recognizable. Report actual Studio results separately from static/CLI tests; a cloud job without Studio cannot claim visual parity has passed.
