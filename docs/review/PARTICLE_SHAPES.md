# Smaller particles, smoke fractures and layered orbital

November 3, 2026. Latest owner direction supersedes the earlier all-circle treatment. Same Drone Blower revolution project; no publishing or Play startup.

Common work energy now peaks around 0.26 stud instead of 0.65. Cutting sparks peak at 0.22 instead of 0.55, utility bursts at 0.36 instead of 1.05, and pickup glints at 0.20 instead of 0.45. The preserved circle remains for neutral energy; built-in sparkle marks, stretched sparks, irregular smoke and the original crystal fragments distinguish jobs. Glow spheres and authored meshes remain intact.

Ordinary stage/break events now call a separate matte gray-brown smoke burst, lightly tinted by the mineral. It has 6/14 puffs, slow local rise, random rotation, no additive glow and a bounded tail. Breaker impact also uses smoke. Currency still has its own small bright glints. Completed specialist jobs retain the integration pass's suppression of duplicate ordinary fracture showers.

Work, pickup, grower, breaker, swarm and orbital particles explicitly reject global wind. Shared sideways noise acceleration was removed; random launch directions provide modest local variation. The world wind and unrelated original assets are unchanged.

Orbital retains its replicated physical core/halo alongside the client Beam. The Beam grows from 1.8 to 3.2 studs wide and uses two broad moving white/clear bands instead of three. At shutdown, a fixed 260-stud cylindrical volume emits 312 small motes with near-zero speed. One emitter replaces twelve sparse attachment bursts. The carrier does not shrink with the laser, remains for the full 4-second maximum particle tail, and is cleaned after 4.4 seconds. Rate is zero so it cannot continue accumulating particles.

Implementation follows Roblox's [particle emitter documentation](https://create.roblox.com/docs/effects/particle-emitters): Cylinder + Volume is parented to a BasePart, and WindAffectsDrag is disabled for localized effects. The rotated cylinder's local X/Right axis follows the vertical column.

## Verification

- `python3 tools/test_energy_effects.py /private/tmp/mining-away-luau`: 8 production logic checks pass, covering ordered ramp at 30/60/144 FPS, full tails, bounded pools, physical-source visibility, volumetric residue, smoke dispatch and preserved authored fragments.
- `python3 tools/test_refinement_client.py /private/tmp/mining-away-luau`: client motion, commands and contact cue regressions pass.
- `python3 tools/test_gadgets.py /private/tmp/mining-away-luau`: domain, contact renderer, authoritative roles, pickups and server regressions pass. The contact texture assertion now reflects the requested non-circular sparks.

These are API-double checks, not visual or multiplayer evidence. Native Edit-mode previews are being captured separately; Play remains stopped. Final integrated revision/build is recorded by the coordinating integration chat in `build/revision.json`.
