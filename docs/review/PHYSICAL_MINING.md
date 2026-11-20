# Physical mining and quarry integration — November 4, 2026

This revision belongs to Drone Blower revolution, place 136098934779395, in the single canonical `build/DRONE_GAME.rbxl`. The current native map, models, UI, crystal audio, roles, permanent ownership and persistence remain. No experience was created or published.

## Visible consequences and actual causes

A native inspection found that resource creation ignored `scene.crystalTemplate` and only searched ReplicatedStorage. The editable map stores the original crystal in Workspace; all live rocks had silently fallen back to cubes. The server now uses the supplied authored template, preserving its faceted shape.

Bubbler records accepted bites and Smasher records accepted dents on the authoritative resource. Clients reconstruct missing volume using bounded local CSG. The old union's cloud operands regenerate an unrelated box; recovered authored collision geometry supplies the cut surface instead. Intact crystals keep their original render. This is an explicitly documented approximation of the authored mesh, not generic replacement art. Engine validation also caught a successful-but-visually-ineffective UnionOperation/MeshPart substitution: the implementation now converts only the local view to the returned cut MeshPart and updates continuing specialist effects to that reference.

Six cutters plus bounded depth bands support continued physical progress on hard rocks. Material loss does not also collapse a carved rock to a tiny quarter-size remnant. Its remaining body settles modestly, with a baseline captured at the first physical hit so switching tools cannot enlarge an already chipped rock. Smasher contact follows the resulting bowl floor; the server retains authority and its original query collider.

Ordinary mining retains staged shrinking, but the transitions settle continuously and shed weighted chips/dust. Mineral tint retains at least 91.68% of its base channels. The former full-black stage is gone. Fresh rocks displace a small dust burst once during their original two-second growth, with no late-join replay.

## Loop, world and UI

Random spawn spacing reserves both complete rock footprints, including tilt and future geode shards. Growers retain the sampled mineral size with their planted position and revalidate it at completion. Attempts and depletion retry budgets remain bounded.

Ore uses gravity, contact-time integration, restitution and ground friction. Rotated chips stay above the ground, settle quietly after delayed replication, and enter the visible backpack after server-confirmed collection. Drops leaving raised fields sample the actual map floor. Full bags, ownership, walls, save uncertainty and expiry cannot duplicate or steal rewards.

The existing map receives green ground, warm mineral beds, part-built quarry terraces and groves, a Cobalt pond and a compatible blue/cloud sky. Authored geometry is preserved; landscaping is a bounded runtime extension. The existing colorful UI gains a clearer bag meter and short full-bag status rather than another panel.

Research and first-party examples are cited in the linked focused reviews: [world](PHYSICAL_WORLD.md), [pickups/UI](PHYSICAL_PICKUPS_UI.md), [damage/API](PHYSICAL_ROCK_DAMAGE.md), and [authored geometry](CRYSTAL_GEOMETRY_RECOVERY.md).

## Validation

Production logic and rendering code run under the focused API-double suites: physical mining, pickup trajectories/views/server receipts, ability targeting against carved bodies, rock damage queues/replacement/lifecycle, specialist/logistics, random placement, and recovered mesh topology. These establish correctness and bounded behavior; they are not Studio visual or multiplayer evidence. `tools/test_physical_mining.py`, `tools/test_pickups.py`, `tools/test_rock_damage.py` and `tools/test_special_logistics.py` are the reproduction entry points, using the pinned local Luau tools. The final six-command run passed; [exact commands and output](PHYSICAL_MINING_TEST_RESULTS.txt) include the standalone placement and topology checks.

A legacy broad gadget runner still contains pre-overhaul particle expectations, and the legacy UI text source check reads the superseded 11px pre-skin HUD declaration. Those checks fail and are not reported as passes. Focused checks execute the current implementations.

## Native verification and delivery

The only connected Studio document was `DRONE_GAME.rbxl`. Its seven live Sources were compared against the prior installed revision before replacement; all 39 unrelated/backup script Sources were compared before and after and preserved. Play used the normal preview fleet and actual mouse dispatch into Quartz and the existing tenfold-health ImpactTest field. No remote command was injected and no production profile was changed.

Actual mining produced local MeshPart cavities, including Bubbler state `6:0:3` and Smasher `0:6:5`, demonstrating continued shape progression after the first six contacts. Close-up native captures show the bubble aligned with removed rock volume and a deep Smasher bowl. The console was empty and no local `PhysicalDamageError` was present. The original faceted resources, revised ground/sky, compact full-bag meter and physical effects were inspected together in Play.

The final clean startup after the ability-target correction produced 53 local resource views, 242 landscape parts and the intended Sky, with no errors. Studio was left stopped. [Native record](PHYSICAL_MINING_STUDIO.json) includes exact installed Source hashes and timing samples.

Native captures: [Bubbler](PHYSICAL_BUBBLER.jpg), [Smasher](PHYSICAL_SMASHER.jpg), [quarry overview](PHYSICAL_WORLD.jpg). These are actual game screenshots, not concept images. They show the existing authored structures and development preview HUD as well as the new work.

An isolated native subtraction took approximately 94 ms. A five-second active-mining sample recorded 300 Heartbeats, no Heartbeat over 33.3 ms, a maximum of 19.61 ms and physics at 60 FPS. The same sample had only 75 rendered frames (15 FPS). Background Studio throttling is a plausible explanation, but its protected setting could not be read, so sustained viewport/device performance is **not** certified. The earlier 15 FPS render-only measurement must not be confused with the simulation rate.

The macOS session was locked, preventing the native Save UI. The existing canonical native file was instead refreshed through the guarded Source-only binary path: all non-Source chunks, geometry, hierarchy, assets and backup Sources remain byte-identical. The same seven Sources were separately installed and checked in the selected Studio document. `build/revision.json` records the exact committed source and canonical SHA-256; `build/canonical-source-report.json` records preservation. Reproduce the package with `python3 tools/release.py` from that clean revision and the existing canonical native file. The review ZIP contains exactly one playable `.rbxl`.

No true two-client/late-join session, phone layout, owner listening assessment or enjoyment study is claimed. API-double tests and single-client native inspection do not substitute for those checks.
