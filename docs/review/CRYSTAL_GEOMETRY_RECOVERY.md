# Original crystal geometry recovery

The preserved `Workspace.Crystal.Mesh` is an original UnionOperation whose visible surface loads from asset **284197383**. Its inline `MeshData`, `MeshData2`, `ChildData` and `ChildData2` are empty in both immutable reference captures and the canonical game. Parent integration observed that both current and legacy CSG regeneration produce a box from that union, even after successfully preloading the correct asset. Restoring its displayed bounds does not repair its shape. No normalized-box replacement is acceptable.

The same original object has substantial authored collision geometry saved in `PhysicalConfigData`. The historical `assets/mining-away-base.rbxl` contains that payload as shared string 8, a 17,150-byte CSGPHS6 record. Both original crystal instances point to it. Its SHA-256 is `7a126b8c311857fcfae37fbe19508840409de4460c8454b2edcda33e6efb4be9`.

`tools/recover_crystal_geometry.py` extracts those 36 convex hulls (471 vertices and 798 triangles) directly from the immutable reference file. Their combined bounds are exactly the original visible part dimensions: **3.134999752 × 6.566901445 × 4.487230778 studs**. This recovers the original authored collision approximation, not a newly designed primitive and not a claim of exact rendered triangle identity.

A direct offline boolean of the saved floating-point hulls leaves narrow seams and point contacts. The first conditioned candidate had closed triangle-index topology but still failed native CSG with error **-33, non-manifold mesh part**. Native CSG welds coincident geometry, so edge incidence alone was insufficient.

The final recovery expands each authored hull by **0.001 stud**, unions them offline, keeps the exterior shell (filling an enclosed collision-only cavity), welds points within **0.003 stud**, then reimports and simplifies with **0.001-stud tolerance**. One remaining tip-to-tip contact is separated by moving each of its two independent surface fans inward **0.001 normalized unit** along its surface normal. The exact original overall bounds are restored. The final [CrystalGeometry source](../../src/CrystalGeometry.lua) has **345 vertices and 690 triangles in one consistently wound, closed connected surface**. At canonical Size 4, the minimum distance between any vertex pair is **0.00230065 stud** and minimum doubled triangle area is **0.0000326852 square studs**. All positions are unique and every vertex has one manifold incident-face fan.

Coordinates are centered and normalized to `[-0.5, 0.5]` per axis, with one-based triangle indices. Runtime construction and cache lifetime belong to `RockDamage`; the geometry module contains data only. The authored silhouette is retained with these small geometric conditioning changes; this remains a collision-derived approximation of the original rendered asset.

The parent verified that current Studio supports `CreateEditableMesh`, `CreateMeshPartAsync(Content.fromObject(mesh))` and GeometryService subtraction on MeshParts. A later native screenshot established that `UnionOperation:SubstituteGeometry(MeshPart)` can return successfully while retaining the original rendered Union shape; it must not be used as proof that the cut was installed. `RockDamage` therefore replaces the **local cosmetic view** with the actual cut MeshPart and updates renderer references. The authoritative source, original template, assets and untouched appearance before the first cut remain preserved. This recovery does not grant rewards, damage, permissions, publishing access, or gameplay authority to clients.

## Reproduce and verify

The source capture remains unchanged. This script only reads it and writes a specified Luau file:

```sh
python3 -m pip install --target /private/tmp/mining-crystal-mesh-libs manifold3d==3.5.4 numpy==2.0.2
PYTHONPATH=/private/tmp/mining-crystal-mesh-libs python3 tools/recover_crystal_geometry.py --output /private/tmp/CrystalGeometry.lua
/private/tmp/mining-away-luau/luau tests/crystal-geometry.spec.lua
```

The recovery checks manifold status, two incident faces per edge, minimum point separation and triangle area after native-equivalent float32 conversion at Size 4, and a single incident-face fan at every vertex. The standalone Luau test checks the actual shipped data's provenance, original bounds, valid indices, numerical conditioning, consistent winding, closed topology, connectedness, and retained normalized volume. These checks passed. A fresh reproduction was also compared to the exact native-accepted candidate: vertex and triangle sections were byte-identical.

**Native operational result reported by parent integration:** the final candidate completed MeshPart subtraction successfully in **0.0944 seconds**, using PreciseConvexDecomposition. The returned MeshPart had size `4, 3.2592883, 4` and identity CFrame/PivotOffset. Parent inspection also confirmed that the actual returned MeshPart visibly renders a carved bowl. This establishes that the conditioned authored geometry can actually be cut and rendered by the current engine. It is an isolated operation, not a complete gameplay, visual-quality or multiplayer acceptance result.

The current mesh reconstruction must still be judged alongside the actual original rendered crystal at ordinary game scale. Its collision hulls may differ in small concavities from the cloud render mesh. The native subtraction and playback checks for the exact integrated revision are the responsibility of the parent review.

## Sources and rejected routes

- The CSGPHS6 binary layout follows the original [rbx_mesh parser](https://github.com/krakow10/rbx_mesh/blob/master/src/union_physics/v6.rs), together with its [shared hull layout](https://github.com/krakow10/rbx_mesh/blob/master/src/union_physics/v3.rs). The recovery parser is a small independent Python implementation of that layout.
- [Roblox solid modeling documentation](https://create.roblox.com/docs/parts/solid-modeling) documents GeometryService input/output behavior and asynchronous cost. Only one bounded local template construction is needed; no hull reconstruction or Python library runs in the game.
- [AssetService documentation](https://create.roblox.com/docs/reference/engine/classes/AssetService) describes the supported EditableMesh/MeshPart creation APIs. Parent native capability checks provide the relevant operational evidence here.
- The [CSG-to-EditableMesh plugin author's explanation](https://devforum.roblox.com/t/csg-to-editablemesh-plugin/3942570) says it first unions a clone to localize cloud data. That would pass through the same broken authored CSG operands in this case, so it was not used.
- A direct read of the exact public asset-delivery URL returned HTTP 401. Parent native `CreateEditableMeshAsync` of that asset URI reported missing permission. No credentials or restrictions were bypassed. The already-preserved collision payload was used instead.
