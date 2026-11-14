# Physical pickups and compact HUD — November 4, 2026

This pass makes the ore reward read as a physical fragment: it launches, loses energy at contact, settles, and enters the actual backpack after a server-confirmed collection. It retains the original mineral mesh, ownership, run binding, capacity checks, line-of-sight checks and finite expiry.

## Physical changes

- `OreDrops` integrates gravity to the actual floor-contact time, applies 0.28 restitution and tangential friction, then consumes the remainder of the tick. Air drag is lower than floor friction, so fragments travel through the air and stop after landing instead of braking everywhere alike. Launch speeds vary deterministically from 4.8 to 6.6 studs/second.
- `PickupMotion` matches the new air/ground drag for bounded extrapolation. Angular momentum remains continuous at first contact, then damps to a fixed pose. Rotated mesh bounds provide the visible support height; the small rebound is preserved instead of disappearing beneath a floor clamp.
- `PickupView` lifts the visible trajectory by that support height, preventing the .58-stud-tall reward from sinking into its old .22-stud center plane. Confirmed collection ends at the rendered backpack on R6/R15 torsos rather than the middle of the character. The final collection arc is lower and shorter in height.
- The ground cue now waits for the 0.1-second interpolation delay. A stale/late event cannot replay old impacts. Persistent glints are capped at eight nearby fragments and point lights at two; reduced-effects attributes disable these and the trails.
- The server's `GroundImpactPosition` must use `drop.floor` for Y, because the new exact integration can already have advanced into the rebound at the end of its tick. The integrated server applies that adjustment.

This is authoritative lightweight trajectory simulation and local visual sampling, **not** replicated unconstrained physics bodies. The integrated server samples the actual map floor when a moving drop leaves its original field, at most four times per second and only after material horizontal movement. Walls block attraction/collection; drops do not bounce against arbitrary world walls or moving parts.

## HUD changes and references

The approved dark, studded, colorful UI and card presentation remain. The existing backpack meter gains a small bag icon, white numbers, a brief rim response to actual inventory increases, and a distinct full state. A full backpack now takes precedence over the ordinary assigned-worker message; previously the warning could be hidden while mining continued and expiring ore accumulated. Fleet/Card captions increase from 12 to 14 pixels inside the existing 44-pixel buttons. Narrow-screen counters drop redundant text and unnecessary `.0` suffixes.

Research informed hierarchy and restraint:

- [Roblox UI art-style curriculum](https://create.roblox.com/docs/tutorials/curriculums/user-interface-design/choose-an-art-style): use color consistently, combine it with symbols/text, and prioritize contrast against a changing 3D background. Applied as a bag symbol plus full-state text, not color alone.
- [Roblox layout curriculum](https://create.roblox.com/docs/tutorials/curriculums/user-interface-design/wireframe-your-layouts): account for core controls and touch space before adding UI. No new permanent panel was added.
- [BIG Games’ first-party Pet Simulator 99 UI examples](https://www.biggames.io/post/pet-simulator-99-update-99), including its inventory category/pinned-item screenshots: useful reference for recognizable icons, short labels and keeping secondary management inside menus. No art, branding, monetization flow or assets were copied.
- [Roblox device-emulation guidance](https://create.roblox.com/docs/tutorials/curriculums/user-interface-design/implement-designs-in-studio): final layout requires actual device checks; source dimensions do not establish legibility.

## Verification

`python3 tools/test_pickups.py` passes:

- Eight production trajectory checks, including integer reward conservation, walking-player catchup, blocked attraction, silent resting contacts, exact impact energy across 30/60/144 FPS, friction and expiry.
- Seven production sampling/math checks, including bounded prediction, floor limits, frame-rate-independent sampling, continuous angular motion, rotated support and terminal collection state.
- Five production `PickupView` checks with narrow Roblox API doubles: support height, buffered contact cue timing, backpack endpoint, bounded visual retirement, connection cleanup and a stale landing attribute settling silently.
- Compilation of `OreDrops`, `PickupMotion`, `PickupView` and `TacticalHUD`.

The integrated eleven-check server pickup suite passes, including raised-bed exit, conservation, ownership, capacity, expiry and contact receipts. Native motion, audibility, desktop/phone text layout, arbitrary geometry collision and two-client appearance are not established by these tests. No Studio document was changed by this subtask; no place was published.
