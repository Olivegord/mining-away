# Physical rock damage — November 4, 2026

The owner requests missing rock volume under Bubbler's bubbles, progressively larger Smasher dents, readable shrinking and mineral colors that never become black. This change is part of the same canonical game and does not alter permanent ownership or authoritative health/rewards.

## Implementation

- `RockDamage.lua` consumes persistent server `BubbleBites` and `SmashDents` counts, capped at six each. It reconstructs the latest complete damage shape for observers, including a late join, instead of replaying old contacts.
- Bubbler uses up to six spherical subtraction stencils on the upper sides of the authored crystal. `RockDamage.bite()` supplies both the boolean stencil and the bubble center/diameter. Glass grows into contact, lifts ore-colored contents and ruptures; the contents then fall under local ballistic gravity.
- Smasher uses one nested ellipsoid. Repeated accepted strikes increase its width and depth at the same contact, preserving the lower foot of the crystal.
- After six contacts, six quantized authoritative `DamageDepth` bands gently enlarge the existing cavities so hard rocks keep changing. A single-specialist resource has at most twelve geometry states; mixed Bubbler/Smasher history can have eighteen. Cutter count remains fixed.
- Geometry operations are asynchronous, operate on local unparented clones, coalesce pending state and allow only one concurrent operation per client. Unchanged frames do not recompute CSG. Requests beyond 160 studs wait for the observer to return. Stream-out, depletion and shutdown invalidate unfinished results.
- The first accepted cut replaces only the local UnionOperation view with the actual returned MeshPart, preserving the logical resource record, appearance/visibility metadata, attributes and attachments. Later cuts use `ApplyMesh` on that stable MeshPart. Ongoing specialist effects resolve the updated view without dropping their tails. Result size ratios and offsets preserve the cut geometry instead of stretching it back into an intact bounding box. Neither the replicated resource nor damage/reward state is modified by the renderer.
- Failed, incompatible or obviously malformed geometry preserves the current authored render. There is no substitute primitive rock.
- Local-only `PhysicalDamageError` records template, subtraction, bounds or substitution failures without adding UI. Successful geometry clears it. Local operand/view pivots are reset to identity; the source's legacy pivot remains untouched.

The root integration owns server count publication, source-template lookup, tint, smooth stage transitions and material-loss fracture feedback. Final native installation and observations are recorded in [the integrated review](PHYSICAL_MINING.md).

## Native asset issue discovered during integration

The root agent found that the native crystal template lives under `Workspace.Crystal.Mesh`, while the old spawn path searched only `ReplicatedStorage.Crystal`. That lookup failure had silently fallen back to plain cube rocks. The original mesh is a URL-backed `UnionOperation`, asset `284197383`, with empty inline rendered mesh and child data in both canonical and historical captures.

Native engine capability tests show `GeometryService:SubtractAsync` and `PartOperation:SubstituteGeometry` are callable. However, direct CSG on this particular old asset returns bounds that do not match the visible faceted crystal. Re-unioning with no operands then resizing gives plausible bounds but a **plain box** in the root agent's screenshot. That normalization path was removed. It must not be used to claim missing-volume damage on the authored crystal.

`tools/recover_crystal_geometry.py` recovers the original asset's 36 saved convex collision hulls from the immutable capture, unions/conditions them offline and emits `CrystalGeometry.lua`. This is an approximation from the authored collision surface, not a claim to recover the cloud-only rendered mesh. Its exact source bounds are retained. Native CSG initially rejected microscopic hull seams as non-manifold; the final conditioned candidate is 345 vertices and 690 triangles and passed the root agent's native subtraction test in approximately 94 ms. The renderer lazily constructs one cached local MeshPart from that surface and keeps its backing EditableMesh alive until shutdown. Intact rocks keep the original render.

Native inspection also found that `UnionOperation:SubstituteGeometry(MeshPart)` reports success but keeps the old render geometry. Directly displaying the returned MeshPart showed the carved bowl. The implementation therefore converts the local view once and uses stable `MeshPart:ApplyMesh` afterward. CSG output uses precise convex collision decomposition so contact raycasts can follow cavities; the unparented input template uses cheap box collision.

An offline boolean check against the recovered surface guided stencil placement so bubbles actually intersect the faceted cluster. Four successive bubble cuts retain approximately 92%, 79%, 73% and 69% of the recovered volume. Six nested dent sizes remove approximately 3% through 15%. These are cosmetic volume proportions, not gameplay damage amounts or engine visual acceptance. The root integration must still inspect actual final cut appearance and shape preservation.

## Research used

Roblox's [solid modeling documentation](https://create.roblox.com/docs/parts/solid-modeling) supports runtime subtraction, unparented operands, client-created local geometry and in-place geometry replacement. It cautions against issuing many asynchronous boolean operations in quick succession. That motivates the single worker, bounded cutter set and coalescing.

Roblox staff's [in-experience CSG API guidance](https://devforum.roblox.com/t/in-experience-csg-performance-and-robustness-improvements/3096491/53) confirms the newer GeometryService API supports local-script operations. The [SubstituteGeometry engine issue](https://devforum.roblox.com/t/substitutegeometry-appears-not-to-work/4084434) also illustrates why successful calls alone cannot establish a visible result; the staff response says that reported rendering bug was fixed, but the native asset above still requires direct inspection.

## Verification

`python3 tools/test_rock_damage.py` passes ten production-code behavior groups: monotonic bounded cutter plans; source/render ownership; original frame/scale preservation; no per-frame recompute; coalescing across yielding calls; failure/malformed-output preservation; late observer reconstruction; stream-out/depletion/shutdown cleanup; cached recovered-mesh construction/lifetime with one-time view conversion and stable later updates; and bounded depth progression after the initial cut count. Checks also cover legacy local pivot cleanup while preserving the source and preserving replacement-view metadata.

`python3 tools/test_special_logistics.py /tmp/mining-away-luau` passes the domain, actual server logic, preview ownership, specialist hardware and FX lifecycle suites. Its FX fixture includes the new RockDamage module; 30 specialist animation/lifecycle checks cover 30/60/144 Hz sampling, bounded reuse and one-time view conversion during an active bubble tail. Both new/modified modules compile with the pinned Luau toolchain.

These tests use Roblox API doubles. They do not establish boolean topology, visual appearance, engine performance, multiplayer replication, sound quality or fun. The integration owner subsequently inspected the actual final cut surfaces during mining in Studio; see [native observations and captures](PHYSICAL_MINING.md#native-verification-and-delivery) for that separate evidence and its limits.
