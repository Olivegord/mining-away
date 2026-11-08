# Quarry photo textures

The quarry's repeating color tiles use a saved **32×32 to 64×64 pixel** range. All current diffuse tiles are **64×64**. Keep source photos separately from the exported tiles, and do not upscale for upload. Flat roughness maps can be smaller. The tiles come from [Poly Haven's CC0 library](https://polyhaven.com/license) and CC0 photographs on Wikimedia Commons.

| Current tile | Source and treatment | Roblox image ID |
| --- | --- | --- |
| `grass-short.png` | [Grass Ground, Poly Haven](https://polyhaven.com/a/grass_ground); muted olive, short clumps, reduced broad mottling | `134439792116456` |
| `field-aggregate.png` | [Ganges River Pebbles, Poly Haven](https://polyhaven.com/a/ganges_river_pebbles); mid-gray rounded gravel for mining beds | `102016069607159` |
| `cliff-soft-strata.png` | Retained `cliff.png`; soft, broad warm strata | `85691036287394` |
| `stone-soft.png` | Retained `rock.png`; low-contrast cool stone | `140053828439773` |
| `paving-worn-joints.png` | Retained `paving.png`; distinct, low-glare paving joints | `129610805568567` |
| `ore-satin-vein.png` | Retained `ore-vein.png`; quieter host stone and visible veins, with the existing ore roughness | `84604323769040` |
| `accent-red-brick.png` | [Red Brick 03, Poly Haven](https://polyhaven.com/a/red_brick_03); 1K diffuse resized to 64×64 | `140062751462844` |
| `ruby-loam.png` | Retained `ruby-leaves.png`; restrained terracotta loam grade for Ruby's ground and transition shelves | `104200953297371` |

Download the two linked 1K diffuse JPEGs as `grass_ground.jpg` and `ganges_river_pebbles.jpg`, then run `swift tools/balance_quarry_textures.swift <photo-directory>` from the repository root. The authored scales, pattern modes, and mining-bed tints are recorded in [the Studio material pass](../../tools/studio_balance_quarry.lua). Grass uses organic tiling at 10–12 studs per tile; gravel uses a regular 17-stud tile to keep each stone readable. Herringbone, checker pads, and directional wood provide the stronger patterns in small areas.

The [contrast pass](../../tools/studio_quarry_contrast.lua) reuses the original strong vein photo for Quartz, Cobalt and the Impact field, and the older gravel on the Quartz bed. Eleven selected turf parts use the stronger grass grade. Drone panels reuse `stone-soft.png` at 0.92 studs per tile; working ribs use `metal.png` at 0.64 studs per tile, so the low-resolution patterns read on small hardware.

The [abstract palette pass](../../tools/studio_quarry_color_shapes.lua) uses the same saved 64×64 tiles. Rounded leaf clumps use the canopy and pebble grades. Fan leaves and tapered tiers use a tighter corrugation pattern. Striped forms and selected rock layers use the soft strata grade at a smaller scale. Checker, brick, herringbone, timber and ribbed finishes give the small shapes distinct patterns.

Earlier source tiles and grades are retained for provenance:

| File | Source | Roblox image ID |
| --- | --- | --- |
| `cliff.png` | [Rock Face](https://polyhaven.com/a/rock_face) | `90123363709602` |
| `rock.png` | [Rock 3](https://polyhaven.com/a/rock_3) | `102819978839821` |
| `gravel.png` | [Rock Ground](https://polyhaven.com/a/rock_ground) | `105262000720992` |
| `grass.png` | [Aerial Grass Rock](https://polyhaven.com/a/aerial_grass_rock) | `118972165990804` |
| `paving.png` | [Cobblestone Pavement](https://polyhaven.com/a/cobblestone_pavement) | `126040173011150` |
| `metal.png` | [Corrugated Iron](https://polyhaven.com/a/corrugated_iron) | `130262067528876` |
| `timber.png` | [Wooden Planks](https://polyhaven.com/a/wooden_planks) | `86358766199540` |
| `concrete.png` | [Concrete Floor](https://polyhaven.com/a/concrete_floor) | `108412286318300` |
| `canopy.png` | [Green Healthy Seamless Vegetation](https://commons.wikimedia.org/wiki/File:Green_healthy_seamless_vegetation_leaves_foliage_dense_hedge_shrub_texture.jpg) | `125617899060932` |
| `evergreen.png` | [Green Dark Vegetation](https://commons.wikimedia.org/wiki/File:Green_dark_vegetation_leaves_foliage_dense_bush_shrub_seamless_texture.jpg) | `133678056070638` |
| `bark.png` | [Tree Bark 03](https://polyhaven.com/a/tree_bark_03) | `132987628304161` |
| `ruby-leaves.png` | [Forest Leaves 03](https://polyhaven.com/a/forest_leaves_03), lifted and tinted for dawn | `116981632144499` |
| `grey-stone.png` | [Rock 01](https://polyhaven.com/a/rock_01) | `113935833702067` |
| `chalk-white.png` | [White Plaster Rough 01](https://polyhaven.com/a/white_plaster_rough_01), graded to cool white | `112016713025924` |
| `ore-vein.png` | [Covellite, pyrite and quartz, GeoDIL no. 2274](https://commons.wikimedia.org/wiki/File:Covellite,_pyrite_and_quartz_(GeoDIL_number_-_2274).jpg), cropped and graded | `101826947844494` |
| `ore-roughness.png` | Derived from the same GeoDIL photograph; bright mineral veins are smoother than the host stone | `134197243065883` |

These seven 64×64 grades keep the original photo detail. Cliff strata, grass, gravel, and paving use a wider range of tones. Canopy and evergreen lift the darkest pixels and reduce the contrast between individual leaves. Ruby's ground cover uses a scarlet and burnt-orange grade. Regenerate the local tiles from the retained originals with `swift tools/grade_quarry_textures.swift`.

| Earlier grade | Source photo | Roblox image ID |
| --- | --- | --- |
| `cliff-graded.png` | `cliff.png` | `110682071054939` |
| `grass-graded.png` | `grass.png` | `136005318797247` |
| `gravel-graded.png` | `gravel.png` | `83637161982243` |
| `paving-graded.png` | `paving.png` | `104656144918864` |
| `canopy-graded.png` | `canopy.png` | `87224951749815` |
| `evergreen-graded.png` | `evergreen.png` | `88408188951983` |
| `ruby-leaves-graded.png` | `ruby-leaves.png` | `100289458480761` |

Two other 64×64 photo tiles add a readable pattern on selected architectural surfaces. The larger hub pad and mining beds keep their quieter finishes.

| Pattern | CC0 source | Roblox image ID |
| --- | --- | --- |
| `herringbone.png` (market walks and shop apron) | [Brick Floor, Poly Haven](https://polyhaven.com/a/brick_floor) | `117231580478198` |
| `checker-tile.png` (three service station pads) | [Tiles 012, ambientCG](https://ambientcg.com/view?id=Tiles012) · [license](https://docs.ambientcg.com/license/) | `110730082505290` |

The scenery keeps its photo color maps. Three flat grayscale maps set the finish without adding extra surface detail or metalness:

| Roughness map | Used for | Roblox image ID |
| --- | --- | --- |
| `roughness-dry.png` (247/255) | Grass, gravel, sandstone dirt, foliage, bark, ruby leaves, and chalk | `78519593640803` |
| `roughness-weathered.png` (227/255) | Rock, slate, paving, concrete, timber, and corroded metal | `86284392582578` |
| `roughness-hardware.png` (184/255) | Diamond-plate hardware | `74787139837104` |

## Original patterned accents

These 64×64 tiles are drawn for DRONEREVOLUTION. Regenerate them from the repository root with `python3 tools/draw_quarry_motifs.py`. Their regular tile scales are recorded in [the Studio motif pass](../../tools/studio_quarry_motifs.lua).

| Tile | Roblox image ID |
| --- | --- |
| `motif-orange-stars.png` | `130509631570789` |
| `motif-violet-daisies.png` | `87001180278589` |
| `motif-blue-gingham.png` | `83914366857318` |
| `motif-red-gingham.png` | `111854869033768` |
| `motif-cream-pips.png` | `140704715063691` |
| `motif-blue-waves.png` | `109395106577220` |
| `motif-blue-knit.png` | `126905018997201` |
| `motif-gold-studs.png` | `107794782432490` |
| `motif-fired-brick.png` | `119317200148174` |
