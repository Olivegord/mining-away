# Mining Away working rules

- This directory and https://github.com/Olivegord/mining-away are the single game project. Generated `.rbxl` files are builds, not independent projects.
- Read `docs/OWNER_REQUIREMENTS.md` first. It overrides the older design brief and rejected cloud-v1 presentation.
- Preserve the original drone and mining feel. Compare against `reference/original/src/` and `docs/ORIGINAL_FEEL_PARITY.md`; improve technical correctness without replacing the behavior.
- Keep original models, meshes, and world identity. Use the original segmented pyramid construct as a real turret. Do not replace distinctive user content with generic primitives when the original asset exists.
- Server owns gameplay, persistent state, card offers/selection, damage, rewards, encounters, and prestige. Clients may smoothly render all drones and effects from replicated authoritative intent/state.
- Permanent drone identity, type, base traits, and fleet survive prestige, death, disconnect, and server restart. All run card modifiers clear on prestige. Persistence must fail safely and must not overwrite a valid profile with defaults after load failure.
- The new player starts with exactly one permanent drone. Packs give three server-generated choices, choose one. No paid random packs or Robux purchasing is in scope.
- Keep UI compact and purposeful: no giant debug panels, excessive floating labels, placeholder typography, or stacked unrelated controls. Card choices appear only when relevant.
- Build from `assets/mining-away-base.rbxl` into `build/mining-away.rbxl`. Do not overwrite source assets, publish Roblox, or create another experience. GitHub commits and a review PR are authorized.
- Use `codex/restore-feel-prestige` for the overnight change. Review once for behavior/parity and again for pacing, visuals, and multiplayer correctness.
- Test the real logic where possible. Include a reproducible build and exact commit. Do not report mocks, structural checks, or lint as Studio visual/multiplayer playtests.
- A blocked integration is not a reason to abandon productive work. Continue available implementation, simulation, model design, review, or test work; document the exact remaining blocker and don't claim it passed.

