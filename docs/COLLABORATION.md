# Work together in the same project

The shared project is **https://github.com/Olivegord/mining-away**. Its integration branch is **`codex/restore-feel-prestige`**. Work in that repository; there is no second GitHub project or separate friend version.

## Open with Codex

1. Open the shared repository link and its current integration branch.
2. Use that repository as the project in Codex. For local desktop work, select its working folder; local changes must be committed and pushed back to this same shared repository. GitHub remains the shared source.
3. Start with this prompt:

   > Read AGENTS.md, docs/OWNER_REQUIREMENTS.md, docs/PROJECT_STATE.md and docs/COLLABORATION.md. Tell me the current game file, shared Roblox destination, last verified gameplay revision and publication status, then work on my requested change in this same project. Keep the existing DRONEREVOLUTION place current under the standing publication permission.

`AGENTS.md` supplies repository instructions to Codex; the linked handoff supplies the project's decisions and current state. The original private chat is not copied into another person's account. See [OpenAI's guidance on repository instructions](https://developers.openai.com/cookbook/examples/codex/iterating-development-workflows-with-codex#agents-and-plans).

The canonical map/recovery snapshot is **`build/DRONE_GAME.rbxl`**. Normal script work uses the existing shared **DRONEREVOLUTION** cloud document with native Script Sync; do not reopen/overwrite a local file for each source change. Do not use `assets/*.rbxl`, an old review ZIP or another game as a working copy.

## Native Script Sync

Studio is connected to the three tracked folders under `studio/`: **ServerScriptService**, **Shared** (ReplicatedStorage.Shared), and **StarterPlayerScripts**. Run `python3 tools/script_sync.py` after editing `src/`, or keep `python3 tools/script_sync.py --watch` running. It bundles only the seven managed Sources, refuses unmerged disk/Studio edits, and leaves additional files alone. Merge edits to generated bundles back into `src/` before exporting again. Commit generated Sources with their modular inputs. The ignored `build/script-sync-state.json` records the last exported hashes locally.

On another computer, open the existing shared place, select each corresponding service/folder, choose **Sync to...**, and select the repository's `studio` directory. Confirm existing-file merge choices only after comparing Sources. Verify `InstanceFileSyncService:GetStatus(root) == Enum.InstanceFileSyncStatus.SyncedAsRoot`. Sync paths are machine-local and require this initial connection per checkout. This workstation has F8 assigned to **Sync to...**.

Files can create scripts directly: `.legacy.luau` is a Legacy Script, `.local.luau` a LocalScript, and `.luau` a ModuleScript. New server/client RunContext scripts may use `.server.luau`/`.client.luau`. Deleting/renaming files also changes Studio instances. Existing disabled backup LocalScripts remain disabled; do not recreate or enable them. The three roots were verified, and disposable ModuleScript creation, disk-to-Studio editing, Studio-to-disk editing and deletion were tested in the actual shared Edit session. See [Roblox Script Sync](https://create.roblox.com/docs/scripting/sync).

Script Sync updates the open Edit document; a new Play session runs the changed server code. It does **not** publish the game. Publish the existing shared place after tests and verify the successful publish in the Studio log, including the exact place ID. The owner has prohibited opening the Version History panel. The canonical native snapshot must still preserve authored map and unrelated scripts; never replace shared map edits with an older local snapshot.

## Read access and contribution access

The owner requests a public repository so the project and context can be read from one link. To push changes and work as a collaborator in the same repository, the friend needs a GitHub invitation with Write access. The owner will supply their GitHub username; do not assume it is MideDibber just because that is their Roblox account.

Roblox and GitHub access are independent. MideDibber's Playtest/Edit access to DRONEREVOLUTION was verified, but that does not add their GitHub account. Do not make a new repository or require a fork to work around a pending invitation.

## Avoid overwriting each other

- Start from the current integration revision and inspect local modifications before synchronizing. Preserve each contributor's uncommitted work.
- Keep code changes in `src/`, with relevant verification and a concise handoff. Use a `codex/` contribution branch and review PR in this repository when working concurrently; branch ownership is not a separate project.
- Only one contributor at a time saves/refreshes the native `.rbxl` or publishes. Agree who owns that step before editing the shared map. Code-only tasks can proceed independently.
- Before editing Sources, retain the exact currently installed Git revision or a `tools/build.py --source-payload` export as the refresh baseline. Use `python3 tools/build.py --previous-commit <installed-revision>` or `--previous-payload <exact-payload>` to apply changes to the canonical file. Never guess a baseline for unknown Studio edits.
- Commit the synchronized Sources and **the same** `build/DRONE_GAME.rbxl` together. A normal save to disk is not a GitHub update; a GitHub push is not a Roblox publication.
- If the native binary conflicts, preserve both contributors' edits for reconciliation in the canonical document. Do not text-merge the binary or silently pick a side.
- Update `docs/PROJECT_STATE.md` with actual changes and validation limits. Check and record whether Roblox Studio is already running before starting work, without launching it just to check. If it was already open, leave it open when finished. If it was closed and you open it for the task, close it when finished. Always stop Play/Run before the handoff and verify Studio is in Edit mode; never leave a playtest or simulation running, even when Studio must remain open. Save changes as needed before the handoff. This replaces the older unconditional close-Studio rule.

## Updating the shared Roblox game

The owner grants standing permission to publish completed updates to this existing destination. Reconcile newer shared edits, verify the selected shared document IDs, then use **File → Publish** in that existing shared Studio document. Use Publish As only when recovering from the canonical native snapshot, targeting **DRONEREVOLUTION → existing start place 124078027733625 → Overwrite**. The universe must be **10774898335**. Check for newer collaborator edits before replacing the online contents.

Verify publication success and the destination, then record the exact Git revision/native hash, publication time and Roblox version or other direct verification evidence in `docs/PROJECT_STATE.md`. If publication is not observed, say **unverified**. Do not create a new game, change sharing permissions, or delete/archive either experience as part of an ordinary update.
