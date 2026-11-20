# One canonical game

The only working/playable document is **`build/DRONE_GAME.rbxl`**. It is tracked in the shared `Olivegord/mining-away` repository so another computer gets the actual authored map. The shared Roblox destination is **DRONEREVOLUTION**, place **124078027733625**, universe **10774898335**.

The older **Drone Blower revolution** place **136098934779395** supplied the immutable capture. It is a separate cloud experience. Its old filename and IDs must not be used to infer which document is current or shared. See [project state](PROJECT_STATE.md) for exact delivery/publication status and [collaboration](COLLABORATION.md) for shared work.

## Validate or refresh

1. Identify the exact selected Studio document and canonical path. Preserve any unsaved or unique native edits before source installation or synchronization.
2. `python3 tools/build.py` validates the existing canonical file against current Sources. A missing canonical file must be restored from the shared repository, never rebuilt from a reference capture.
3. For a source change, supply the exact installed baseline: `python3 tools/build.py --previous-commit <installed-revision>` or `--previous-payload <exact-payload>`. Unknown editor changes stop the operation.
4. Source refresh changes only the seven allowlisted Sources. Every other chunk, authored map/asset and unrelated/backup Source remains intact. An offline refresh does not hot-reload an open Studio document.
5. Verify the changed Sources, save that same native file, and commit it together with the source changes. One contributor owns native integration at a time; binary conflicts require reconciliation.
6. Stop Play and close Studio when finished.

Historical payloads labeled with the capture's place ID remain accepted as exact **local source baselines** after their paths/classes/hashes are checked. Native installers accept only the shared destination or the verified canonical local document; historical baseline compatibility is not permission to edit the old cloud experience.

## Release and CI

After committing synchronized Sources and the native file, `python3 tools/release.py` verifies/packages that same document. The review ZIP contains exactly one `.rbxl`, the canonical file, together with source text and revision/preservation reports. The ZIP's legacy name, `drone-blower-revolution-review.zip`, is not a cloud destination. Metadata states the current destination IDs and that the command does not publish.

CI verifies that the tracked canonical native file matches current Sources, runs the preservation/consolidation fixtures, and exports a seven-Source JSON payload. It must never reconstruct a playable alternative from an immutable capture. CI and offline checks do not establish Studio visual, audio, multiplayer or enjoyment acceptance.

`assets/*.rbxl` stay immutable reference inputs. Recovery files such as `.rbxl.previous` are not working games. Do not open these as alternatives or include them as playables in a release.

## Old duplicate cleanup

`tools/consolidate_game.py` is a guarded legacy cleanup tool, not a routine onboarding step. It only removes recognized capture-derived duplicates after canonical-file validation and preservation of unique edits. Unknown native edits block deletion. Do not rerun an old example commit from historical instructions or delete either Roblox experience based on filename similarity.

Run `python3 tests/single-game.spec.py` for temporary-fixture coverage of the preservation and one-file packaging rules. Fixtures are not separate shipped game versions.
