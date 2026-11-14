# Native meadow — October 25, 2026

The owner preferred the dense continuous meadow's appearance, but found the skinned version too slow and requested default Roblox grass with similar placement and variation. The active project is **Drone Blower revolution** (`136098934779395`); the single reproducible build retains the required filename `build/Mining Away.rbxl`.

`MapLayout.lua` now samples a native 4-stud terrain raster over the same broad meadow region, keeping the depot, nine walking routes, ore clearings and steep slopes clear. It creates 2,297 meadow cells: 2,032 Grass and 265 interspersed dry Ground. Coherent world-space tones create broad variations; sparse dry cells blend into green meadow instead of drawing isolated square lawns. A soil collar supports native voxel edges. The original faceted terrain, trees and gameplay assets remain.

`NativeMeadow.lua` runs once during world assembly and writes small terrain batches, yielding between them. It reads existing voxels before editing, preserves unplanted columns, and compensates for the smooth-terrain half-voxel height offset. Default terrain decoration/grass length remain those of the preserved source asset. Global wind provides native sway. There is no client foliage renderer, per-blade position payload, cloned grass mesh, grass octree, or per-frame script for foliage. The SkinnedGrass import was removed from the active place and generated build; source assets and the dense experiment remain archived in `reference/skinned-grass/`.

Native grass exposes one shared blade color, not a color per meadow region. The approximation uses a meadow-green blade color with green/gold blended ground materials. It does not claim independently tinted golden native blades or custom footstep bending.

## Evidence

- Applied to the owner-confirmed Drone Blower revolution Studio instance, with no Roblox publication or cloud save.
- Real client inspection: **zero Workspace bones**, no InteractiveGrass folder, no offscreen grass storage, and no replicated SkinnedGrass import. Native renderer attributes identify the grass cells above.
- Short native-client sample: 60 rendered frames, **16.83 ms mean**, **25.44 ms maximum**. This is a local Studio observation, not a hardware comparison or mobile/multiplayer benchmark.
- Real Studio geometry checks after the final soil collar: **3,120 walking-route samples across all nine routes, zero reported floor/body issues**. The query includes Terrain.
- Facet inspection: 280 samples, no issues, maximum height error 0.231 studs.
- Native floor inspection: 328 sample hits; nine near faceted slope transitions differ by over 1.25 studs from the nominal surface, maximum 2.087 studs. Smooth 4-stud terrain does not reproduce every faceted transition exactly. These edges remain supported by the original facets; the route probes above found no walking obstruction. Do not describe the native floor as exact geometric parity.
- Production source/domain/API-double suite, deterministic binary build and original-geometry preservation checks pass. API doubles do not establish rendering, network or physical walking behavior.

Reproduce with `python3 tools/test.py /private/tmp/mining-away-luau`, `python3 tests/binary.spec.py`, `python3 tests/geometry.spec.py`, and `python3 tools/release.py`. The latter stamps the exact source commit and checksum in `build/revision.json`. The native meadow appears when Play starts.
