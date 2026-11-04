# One canonical game

The only working/playable document is:

`build/DRONE_GAME.rbxl`

The owner renamed the retained editable document **DRONE_GAME** after installing PR #3. It belongs to the existing **Drone Blower revolution** Roblox place `136098934779395`. Keep this document's native map and all authored assets. The plain `Drone Blower revolution.rbxl` was a generated copy built from an older capture. It is retired. Do not open or regenerate it as another working game.

## Consolidate the local Studio files

First identify the editable workspace document in Studio by its exact local file path. Keep its native map and reconcile any unsaved or unique edits from the other open document into it. A matching place ID or controller name alone does not distinguish the two copies. Save the editable document to its existing canonical path and close the redundant Studio document.

First bring the reviewed source and consolidation tooling from PR #3 into that same local repository, preserving any other local edits. Then apply the current Sources and remove the verified generated duplicate:

```sh
python3 tools/consolidate_game.py --previous-commit bdb76e2
```

`bdb76e2` is the last combined client-animation revision before the specialist rework. Use the actual installed revision or its exact previously staged payload if the native document has since changed. If the canonical file already contains current Sources, run `python3 tools/consolidate_game.py` without a baseline.

The command requires the actual native editable file. It refreshes only the seven allowlisted Sources, preserving every other chunk and unrelated/backup script. It checks that the redundant plain file contains only recognized Source changes to the immutable live capture before deleting it. It also removes the known old review ZIP only when every embedded native file is verified. Unknown geometry or script edits preserve the competing file for reconciliation; a missing canonical document creates nothing and deletes nothing. The consolidation report records deleted paths, hashes and the retained canonical hash.

The command cannot close an already open Studio document or install code into a running session. Native installation must target the canonical document and save back to that same path. Source refresh on disk does not hot-reload an open game.

## Future updates

- `python3 tools/build.py` validates the existing canonical document. With an exact `--previous-commit` or `--previous-payload`, it refreshes that document in place.
- After committing, `python3 tools/release.py` validates/refreshes and packages that same file only. A stale document needs a verified previous baseline; it never falls back to an old capture.
- The review ZIP contains exactly one `.rbxl`: the canonical file. Source text and revision/preservation reports accompany it. Immutable binary source assets are excluded from this distributable.
- CI validates source and preservation/consolidation fixtures, then exports a seven-Source JSON payload. CI has no native editable document and therefore does not manufacture a playable alternative.
- A `.rbxl.previous` recovery file is not a separate working game. Never open it as an alternate development branch.
- `assets/*.rbxl` remain immutable history/reference inputs. Binary fixture builders require explicit temporary outputs and cannot write games into `build/` or overwrite source assets.

## This cloud checkout

The specialist source at `bbc4692` is committed and pushed. Its earlier plain generated artifact was a review delivery, not an installation into the Mac's editable Studio document. The actual native editable file is absent from this cloud checkout, and this chat has no tool for closing or deleting the Mac's open Studio copies. Local Studio consolidation and installing the latest Sources therefore require access to that existing native file; this workflow intentionally refuses to fabricate a replacement.

Run `python3 tests/single-game.spec.py` for temporary-fixture coverage of the one-file workflow. These checks verify file preservation and packaging; they are not Studio visual or multiplayer tests.
