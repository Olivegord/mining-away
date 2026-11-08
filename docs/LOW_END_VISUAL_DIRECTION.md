# A living reserve with low-resolution photographs

Research and read-only Edit audit, November 8, 2026. These are design recommendations, not installed changes, measured performance results, or owner acceptance.

**Later owner correction:** restore rock mining and the attached earlier photo-textured palette, slightly brighter. Keep random texture objects in the display only. The junk-centered recommendations below are historical and must not override that choice; see PROJECT_STATE.md for the implemented restoration.

## What the charts actually show

Inspected [Roblox Charts](https://www.roblox.com/charts?device=low_end_phone&country=us) in the browser with **Entry-level Phone / United States** visibly selected. The first seven entries in each visible row were:

| Chart | Entries in displayed order |
| --- | --- |
| Top Trending | DONT SPLASH; Ragdoll Physics; Throw Food For Animals; +1 Spider Arm; Ragdoll Research; Fatal Baboons; Say Cheese! |
| Top Revisited | Dandy's World; Adopt Me!; Jujutsu Shenanigans; Fling Things and People; My Movie; Murder Mystery 2; Blox Fruits |
| Fun with Friends | SPTS Classic; 3008; Tap Simulator REBORN; Make a Pancake!; Pet Simulator 99; Catalog Avatar Creator; Brookhaven |

The **Top Playing Now** row explicitly says “Results for all devices and locations.” Its leading games were Steal An Egg, Brookhaven, Murder Mystery 2, Blox Fruits, Adopt Me!, Throw Food For Animals, and RIVALS. Do not relabel that row as low-end-phone rankings. Rankings change; displayed player totals are not device-specific benchmarks. Chart inclusion does not establish stable frame rates on a particular phone.

## Lessons to transfer

These are interpretations of the verified game descriptions and reference presentation, not claims about why their retention is high. Official game-page promotional images were inspected for DONT SPLASH and Dandy's World; those images are not gameplay captures or proof of low-quality rendering.

| Reference and evidence | Useful lesson for this game |
| --- | --- |
| [DONT SPLASH](https://www.roblox.com/games/119958473240233/DONT-SPLASH) names Poolrooms and House of the Locust as inspirations. Its official art uses cream tiles, blue-green water, repeated simple architecture and an unmistakable threat. | A limited material vocabulary can establish a strong place. Give the reserve a readable relationship between quiet landscape and an unusual event; don't add horror merely because this reference is horror. |
| [Dandy's World](https://www.roblox.com/games/16116270224/Dandys-World) combines distinctive collectible Toons, machines, cooperation and descent through Gardenview. | Give drones and the machinery people use stronger identity than background decoration. Different tools should be recognizable in silhouette and in their actions. |
| [3008](https://www.roblox.com/games/2768379856/3008) makes familiar furniture into base-building material in an uncanny store. | Familiar objects feel consequential when their placement and use matter. Our photo-covered junk, found props and maintenance equipment already offer a coherent vocabulary. |
| [Throw Food For Animals](https://www.roblox.com/games/120219252362013/Throw-Food-For-Animals) describes a direct throw, attract, collect, earn, improve, reach-new-areas loop. | Show an obvious action and visible consequence. Junk arrival, drone attack, salvage release, sale and improvement should read as one chain. |
| [Bee Swarm Simulator](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator) describes swarm growth, pollen-to-honey conversion, bee traits and further mountain exploration. It appeared in the global popular list, not the inspected phone rows. | Visible workers and attainable destinations can explain progression in the world. Keep the existing one-drone start and simple economy. |

The [Roblox creator interview with the 99 Nights team](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940) specifically describes keeping part, vertex and instance counts low for mobile. This is direct developer testimony about their approach, not a benchmark of our game. Its useful lesson is to spend geometry on recognizable structures and silhouettes before small decoration.

## What is wrong in the current view

Inspected the existing DRONEREVOLUTION Edit session, place 124078027733625 / universe 10774898335, loaded version 76. Studio was already open and stayed in Edit. Captured the current wide view and a Quartz approach at camera (-39, 11, 133), looking toward (-77, 8, 91). No Play or simulation was started.

- The map is bright already: ClockTime 13, Brightness 2, exposure +0.35, Ambient 190/255 and OutdoorAmbient 210/255. The large pale walls and paths have little separation from other light surfaces. More exposure is not a sufficient answer.
- Quartz presents a broad noisy gravel foreground, a nearly uninterrupted brown terrace face, and scattered small patterned objects. Those objects do not create a strong main subject from this approach.
- The cloud-printed blocks are a distinctive idea, but their pale blue faces blend into the existing pale blue sky. Their undersides and edges need clearer separation while retaining that skybox.
- The scene has several equally small visual attractions. A larger found-object silhouette with grouped supporting props would be easier to read than more evenly scattered decoration.
- Large field labels dominate the Edit captures. Audit the actual runtime handling before altering UI: the Edit capture also shows old Ore/Currency overlays and is not proof of the current runtime HUD.
- Empty Edit fields are expected because playable junk is spawned at runtime. Do not confuse that with a demonstrated lack of gameplay activity. Source inspection confirms cloud drift already exists in Client.lua; its motion was not evaluated in this pass.

## Proposed direction

Make this a sunlit, slightly uncanny municipal nature reserve whose old maintenance machines are still working. Keep the island, six areas, skybox, original models and 64×64 photographs. Distinguish activity from scenery through composition and behavior.

1. **Compose the first clearing.** Keep the sparse meadow. Frame its edge with a few existing taller trees, preserve the open approach, and group selected found props beside a maintenance landmark. The first useful drone/junk interaction must remain visible. Avoid filling the mining floor or widening the terrain scope while the other chat owns it.
2. **Separate surfaces by value.** Keep olive/sage turf, warm cream equipment panels and darker brown/charcoal bases. Use small amber, faded red and turquoise accents at machinery and points of interaction. Existing colorful craft junk can be the strongest local accent. Judge actual engine views before choosing exact lighting values; avoid global saturation or dark fog.
3. **Give photographs different jobs.** Quiet turf and stone cover large areas; bark, ribs and brick articulate structures; recognizable component photographs belong on junk. Preserve broad plaid scale. Adjust material-specific contrast and repetition only where needed rather than replacing every texture or overlaying more fine grain.
4. **Make the sky props legible.** Keep the cloud photographs and slow drift; differentiate the underside and side edge enough that a cloud block reads as a physical, deliberately fake object. Do not cover the sky with more blocks.
5. **Tie visible motion to real work.** Prioritize the existing junk fall, committed drone attack, tool contact, salvage arc and converter delivery. A maintenance fan, a turning indicator or a small shoreline motion can support quiet moments. Use a few local, distance-limited motions; never animate every plant or add fake reward signals.
6. **Make nearby places sound different.** Low surf near the shore, a restrained machine hum at the depot, and clear material contact at the clearing can establish presence. Audit existing soundscape first; do not stack loops or change accepted laser/crystal audio without its requirements.

The first candidate should cover the spawn-to-Quartz view and one working station, then be assessed before spreading across all six areas. Success means a player can identify where work happens, recognize the drone/junk against the ground, and see what changed after an action. Another layer of decorations does not establish success.

## Low-end constraints and verification

[Roblox's performance guidance](https://create.roblox.com/docs/performance-optimization/design) recommends baseline-device testing, reusing meshes/textures, controlling transparency overdraw and reducing unnecessary per-frame work. Its example draw-call and triangle counts are illustrative, not universal budgets.

- Reuse the existing image IDs and native models. Tiny source images help texture scope but do not eliminate the cost of parts, decals, surfaces, physics or draw calls.
- Prefer opaque simple forms; avoid large overlapping translucent gradients, particle blankets and many shadow-casting local lights.
- Keep decorative motion local, bounded and distance-aware. Keep gameplay authority on the server. Workspace streaming is already enabled in the inspected Edit document.
- Preserve readability without bloom, strong reflections or distant shadows, which may differ at low graphics quality.
- Later verification must use actual low graphics and a real baseline device, including a busy mining scene. Studio's device emulator cannot establish phone memory performance. No new tests were started under the owner's existing restriction on repeated native testing.

## Handoff

Research began on Git 96850ed8f033f318cb75ccbbbac08a74c6624ec9; the active gameplay chat advanced the checkout to 3982df59e023f32614a09793eab1877cfd94ed87 during the audit. That chat retains native/source ownership for its persistent damage follow-up. This research changes no Sources, map, lighting, or native snapshot.

Canonical file: build/DRONE_GAME.rbxl. Shared destination: DRONEREVOLUTION, place 124078027733625, universe 10774898335. No publication was performed or independently verified here. The last documented publication receipt remains v43; loaded Edit version 76 is not evidence that this research or the latest local work was published. Current collaborator permissions were not rechecked because no access change or release was performed.
