# Work together in the same project

The shared project is **https://github.com/Olivegord/mining-away**. Its integration branch is **`codex/restore-feel-prestige`**. Work in that repository; there is no second GitHub project or separate friend version.

## Open with Codex

1. Open the shared repository link and its current integration branch.
2. Use that repository as the project in Codex. For local desktop work, select its working folder; local changes must be committed and pushed back to this same shared repository. GitHub remains the shared source.
3. Start with this prompt:

   > Read AGENTS.md, docs/OWNER_REQUIREMENTS.md, docs/PROJECT_STATE.md and docs/COLLABORATION.md. Tell me the current game file, shared Roblox destination, last verified gameplay revision and publication status, then work on my requested change in this same project. Do not create another game or publish Roblox.

`AGENTS.md` supplies repository instructions to Codex; the linked handoff supplies the project's decisions and current state. The original private chat is not copied into another person's account. See [OpenAI's guidance on repository instructions](https://developers.openai.com/cookbook/examples/codex/iterating-development-workflows-with-codex#agents-and-plans).

The actual editable map is included at **`build/DRONE_GAME.rbxl`**. Open only that file in Studio. Do not use `assets/*.rbxl`, an old review ZIP, a differently named Home tile or another copy as the working game.

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
- Update `docs/PROJECT_STATE.md` with actual changes and validation limits. Stop Play, save the canonical document and close Studio when finished.

## Updating the shared Roblox game

Only after an explicit publication request, use the canonical document and **File → Publish As / Publish to Roblox As → DRONEREVOLUTION → existing start place 124078027733625 → Overwrite**. The universe must be **10774898335**. Check for newer collaborator edits before replacing the online contents.

Verify publication success and the destination, then record the exact Git revision/native hash, publication time and Roblox version or other direct verification evidence in `docs/PROJECT_STATE.md`. If publication is not observed, say **unverified**. Do not create a new game, change sharing permissions, or delete/archive either experience as part of an ordinary update.
