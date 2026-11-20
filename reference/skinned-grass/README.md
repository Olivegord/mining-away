# SkinnedGrass by xander22

Historical reference only. Retired from the active game and build after the owner preferred native grass for performance. The accepted dense placement/look experiment is preserved in `DenseMeadow.lua`; current implementation is `src/NativeMeadow.lua` and `docs/review/NATIVE_GRASS.md`.

Source: https://devforum.roblox.com/t/skinnedgrass-performant-interactive-foliage/3364812
Creator Store: https://create.roblox.com/store/asset/87377915371959/SkinnedGrass

Downloaded October 25, 2026 from the author's first-post attachment:
`https://devforum.roblox.com/secure-uploads/uploads/original/5X/8/1/a/a/81aa90e693a6a86da7bb49e91c136915959937b8.rbxm`

Original attachment SHA-256: `b43dfe3e064d0d2130e31f39732e9b76c94ef0890796e85db3b1b117ef7ed887`.
The unchanged RBXM retains both original rigged mesh variants, bindings, decals and original scripts. The author explicitly permits modifying and using it in projects. Octree credit belongs to Quenty; original module credit headers remain.

`src/` contains readable extracted sources. Only `SkinnedGrass.lua` is patched: constructor defaults preserve explicit `false`; initial mesh storage uses the configured folder; zero-length collision directions use a finite fallback. The deterministic importer replaces ModuleScript sources from this directory and disables both demonstration runners. No downloaded script executes in the builder.

`DenseMeadow.lua` archives the former client integration. It uses the Studio mesh, normalizes its rotated pivot, scales from blade-root bounds rather than the deliberately oversized bounding box, grounds bones against the existing floor, uses matte green instead of the template's Neon material, and owns culling/storage/cleanup. All current player characters can bend it, including after respawn. It never authorizes gameplay or modifies terrain collision.
