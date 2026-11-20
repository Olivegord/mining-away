# Physical mining pass — quarry environment

November 4, 2026. Source changes: `src/World.lua`, `src/Daylight.lua`. These changes are part of the existing Drone Blower revolution game, not a new map file or experience. Native installation, combined revision and final screenshots are owned by the parent integration chat.

## What changed

The canonical document has `EditableMap=true`. That path previously returned before the historical landscape generator, leaving the current 720 × 360 grey baseplate and widely separated flat fields with no surrounding landscape. The richer old `MapLayout` terrain was not the landscape the owner was seeing. This pass decorates the actual current field footprints after the Quartz start placement finishes.

- Grass-green baseplate, warm sandstone routes and depot concrete, and distinct sandstone/terracotta/blue-slate/violet/green mineral beds replace the dominant grey wash. Field identities, dimensions, original instances and mineral gameplay remain intact.
- A bounded additive `QuarryLandscape` contains rectangular earth terraces with exposed strata, grass shelves and small groves using the existing forked parts-built tree vocabulary. The starting field receives a side embankment; later fields receive rear quarry cuts. A shallow Cobalt settling pond supplies a contrasting landmark without a deep-water trap.
- Landscape placement checks the actual original fields, routes, map structures, converter and baseplate edges. It reserves the client-only home effect display apron explicitly; those stations do not exist yet when the server initializes the map. No decorative part is placed inside a resource footprint. Trees and brush are noncolliding; the grounded terraces are collidable.
- The mismatched `Simple Sunset Sky` is moved into a runtime ServerStorage archive, then a blue/cloud `Sky` using engine-bundled default textures is installed. Clear soft afternoon lighting and a light blue atmospheric horizon match the greener world. Repeated application reuses one sky and atmosphere. Captured native sky objects remain untouched on disk because only allowlisted script Sources are refreshed.

No terrain voxels, field positions, permanent assets, authored mesh models or backup scripts are replaced. `MapLayout`, `HarborLighting` and `NativeMeadow` are unchanged. The landscape is built once with anchored parts and no update loop, joints, emitters or moving physics objects.

## References and interpretation

The official [Bee Swarm Simulator experience](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator) remains the owner-selected reference for a readable resource-field route. Public map images were inspected through image search for the relationship between distinct colored fields, paths and bordering scenery; no imagery or models were imported. Our application is field framing and a visible material hierarchy, not its branding or assets.

Roblox's [outdoor lighting tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments) explains how a sky's palette, terrain palette and atmospheric treatment should support each other. Its [global lighting documentation](https://create.roblox.com/docs/environment/lighting) distinguishes the softer retro rendering style from Realistic. This pass uses Soft with restrained specular response to preserve the existing parts-built language. The [Sky documentation](https://create.roblox.com/docs/environment/skybox) establishes the six-face sky mechanism and celestial controls. The six default `rbxasset://textures/sky/sky512_*.tex` values were read from a temporary unparented native Sky, and their shipped files were confirmed in Studio's PlatformContent directory; no unverified external sky assets were added.

These are design interpretations. Documentation and image references do not prove that this candidate looks good in motion.

## Validation

- `src/World.lua` and `src/Daylight.lua` compile with pinned Luau tooling.
- `python3 tools/test_shops.py /private/tmp/mining-away-luau` passed, including actual bundled server shop/start-layout behavior under API doubles, all source/bundle syntax checks, and seven-Source native capture preservation.
- A focused disposable harness (`/private/tmp/quarry-layout-review.lua`) ran the actual landscape function against measured native baseplate/hub/lane/field dimensions: 242 anchored generated parts; none of the tested bank/shelf/soil/pond footprints intersects a mining field; Cobalt pond exists; repeated landscape and daylight application does not accumulate objects or skies. This uses API doubles, not Roblox rendering/collision validation.
- Native measurements were read from the connected `DRONE_GAME.rbxl` Play server. No Studio world mutation or native file save was performed by this environment subtask.

Parent integration must inspect ordinary-distance views, travel around field edges, the preview apron and fresh startup. Low/high graphics, phone views and multiplayer rendering remain unverified. The part count is bounded but is not a device performance measurement.
