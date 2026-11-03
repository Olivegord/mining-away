# Drone Blower revolution overnight implementation goal

Prepared November 2, 2026 for the existing game in `Olivegord/mining-away`, Roblox place `136098934779395`.

## Start here

**Implement this plan. Edit the actual project files, build the game, test real behavior, review the result, fix the problems you find, and deliver a reviewable integrated revision. This is an implementation assignment, not a request to write another plan.**

The owner wants a substantial overnight improvement from a good prototype into a coherent, appealing Roblox mining game. The scope includes the map, mining choices, drone roles, progression, mineral shops, a persistent earned master currency with exciting rewards, lighting, presentation, and performance. The owner has capacity for sustained work tonight and explicitly wants repeated checking and refinement. Spend that effort on implemented improvements and evidence, rather than expansive brainstorming without delivery or repeatedly running checks that cannot reveal anything new.

Read `AGENTS.md`, then `docs/OWNER_REQUIREMENTS.md`, before changing anything. This brief adds the owner's November 2 request for the broader overnight pass; it does not revoke preservation, persistence, multiplayer, or publishing rules. Use `codex/restore-feel-prestige` and the latest integrated source on that branch. Do not start from old main or the rejected cloud presentation.

The desired result is immediately recognizable: the player spawns beside real Quartz, sees a compact useful depot and a deliberately built Roblox landscape, gives a clear mining order, watches drones perform different useful jobs, earns an understandable upgrade, explores a more demanding field, and can name a worthwhile long-term reward. The world, rewards and interfaces must reinforce that same loop.

All proposed new names, costs, timings, layouts and rewards below are design starting points. Implement the strongest coherent version after inspecting the current code. Preserve existing paid offers, owned drones, valid profiles and the latest approved work. Document material deviations with reasons and evidence.

## Nonnegotiable boundaries

- This is the existing Drone Blower revolution game and repository. Preserve original drone and crystal meshes, the segmented pyramid construct, current role identities, discoveries, crystal audio, compact tactical HUD, and approved card movement and outlines.
- Build `build/Drone Blower revolution.rbxl` from the immutable `assets/drone-blower-revolution-base.rbxl`, whose expected SHA-256 is `b08036b400c77451e609f5fa3a4f7f04cd5dcc2030f35a76de12ecc278f532cd`. Only the exact live script Source allowlist may change in this source-only artifact. Preserve every other binary chunk and every backup script. Never use `assets/mining-away-base.rbxl` as the release base.
- The owner also expects the finished map in editable Workspace. Produce a reproducible Edit-mode application and a separately saved native editable artifact when Studio is available. Runtime-only scenery is not sufficient evidence of an editable map.
- No Roblox publishing, new experience, main merge, Robux purchase flow, paid random packs, or copied commercial game branding/artwork. GitHub commits and a review PR are authorized.
- New production profiles start with exactly one permanent drone. Each prestige grants exactly one new permanent drone. Fleet identities, types and base traits survive prestige, death, disconnect and server restart. Keep preview loadouts isolated.
- Server authority covers access, offers, selections, mining, damage, encounters, growth, rewards, purchases, prestige and persistence. Clients render intent smoothly; they do not decide rewards or hits.
- A failed profile load cannot produce and save defaults over a valid profile. New economy features must use the existing durable receipt and transaction architecture.
- Keep the latest full-backpack behavior: mining may continue; collection waits for space. Drops have finite lifetimes and visible fade. Walking outside the padded field footprint recalls work silently with the approved hop/follow behavior.
- Keep music off by default. Preserve audible charge, work, physical contact, delayed fracture and collection events. Avoid adding sound clutter.

## Current integration context

The preparation chat inspected the project without editing game source or Studio geometry. Earlier HEAD was `a3dda1e3bb83fc66f492114ab47ac10802577f55`; the gameplay chat subsequently reported integrated refinement revision `768721ef7cdbf37ecf07ac2220aa46a27b80686f`, committed and pushed, with a further particle/bloom visibility correction underway. These are orientation points, not permission to reset newer work. Fetch and inspect the latest branch before implementation and again before final integration. Preserve newer commits.

The active gameplay chat owns the ongoing particle/audio correction, especially `WorkEffects`, `DroneRoleEffects`, `AbilityView`, `PickupView` and client integration. Begin productive map layout, economy design, pure modules and tests without overwriting those changes. Integrate the newer correction before touching overlapping presentation code. Do not make launching or beginning independent implementation depend on prolonged chat coordination.

The actual source has both an editable captured-map path and an older generated valley path. `World.initialize()` uses the captured map when `Workspace.MiningAway` has `EditableMap`. Therefore editing only `MapLayout.lua` or old `Config.Fields.Offset` values can leave the actual game unchanged. Implement against the active path and make the Edit and runtime layouts agree.

## Verified map anchors

These values came from a read-only inspection of the local native editable copy on November 2. That local copy reports place ID zero, as a local file can; it was named `Drone Blower revolution - editable workspace.rbxl`. The production target remains `136098934779395`. Reconfirm identity from the full scene and preserved sources before any install.

| Object | Center XYZ in studs | Size XYZ in studs | Treatment |
|---|---|---|---|
| Depot HubPad | -56, 0.5, -11 | 84, 1, 76 | Preserve origin and service identity |
| SpawnLocation | -56, 1.5, 23 | 12, 1, 12 | Beside Quartz, facing it |
| Landing Quartz | -56, 0.5, 65 | 64, 1, 64 | Central first field |
| Ruby Grove | -176, 0.5, 129 | 64, 1, 64 | Safe western field |
| Cobalt Ridge | 64, 0.5, 149 | 64, 1, 64 | First guarded eastern field |
| Violet Basin | -296, 0.5, 129 | 64, 1, 64 | Far western field |
| Deep Emerald | 184, 0.5, 169 | 64, 1, 64 | Far eastern field |
| ImpactTest | 12, 0.5, 65 | 56, 1, 64 | Always open, Quartz currency, tenfold equivalent rock work |
| Converter | -56, 3.92857, 17 | 3.42857, 7.85714, 3 | Preserve real selling station |
| Printer | -56, 1.5, -38 | 10, 3, 10 | Preserve original assembly |
| PackStation | -84, 1.5, -11 | 10, 3, 10 | Preserve earned three-choice packs |
| PrestigeStation | -28, 1.5, -11 | 10, 3, 10 | Preserve fleet milestone identity |

Shop centers are Quartz `(-72,2.5,21)`, Ruby `(-76,2.5,7)`, Cobalt `(-44,2.5,7)`, Violet `(-32,2.5,7)`, Emerald `(-20,2.5,7)`. Each counter is 6 by 3 by 4 studs. They already have two-sided signs and proximity interactions. Keep them discoverable at the depot; hiding shops again at distant field edges would repeat a rejected design.

The old `docs/game/map_reference.md` describes a prior valley and its coordinates are not the current editable-map baseline. Use it for historical context only where consistent with the latest scene. Field IDs 1 through 5 must remain Quartz, Ruby, Cobalt, Violet, Emerald. ImpactTest stays ID 6 and outside the normal access chain.

## Map concept and route structure

Build a compact, parts-built alien mining basin around the existing anchors. The depot and Quartz are the center of activity; two readable landscape arms reach toward more demanding resources. Low terraces, native studs, authored trees and original hardware give it a recognizable Roblox character. Avoid both the current empty test plane and an oversized decorative world that adds walking without decisions.

```text
                             DEPOT
               Packs     Printer     Prestige
                 Mineral shops and Converter
                              |
                         SPAWN / QUARTZ ---- IMPACT TEST
                          /         \
                 RUBY GROVE         COBALT RIDGE
                    |                    |
               VIOLET BASIN          DEEP EMERALD

      Physical routes have two arms. Shop progression remains:
      Quartz -> Ruby -> Cobalt -> Violet -> Emerald.
```

The alternating access sequence is deliberate: the player returns to the familiar depot to sell and choose an expedition. Do not imply that simply walking from Ruby to Violet unlocks Violet. Grounded signs and the relevant shop describe the real requirement. Keep travel physically open where current rules allow; entitlement and guard clearance control mining, not invisible walls.

Preserve the field centers initially. Improve their surroundings, approaches, framing and useful space before considering large relocations. A relocation needs a concrete gain in walking time, visibility or interaction and must move the entire original assembly, update dependent coordinates, and remain reproducible. Never exchange one recognizable asset for a generic substitute.

### Paths and clear space

- Give Quartz an obvious short paved approach from spawn. Its near edge is Z=33, ten studs ahead of the current spawn center. Keep that view free of opaque signs, canopies and new machinery.
- Main routes should offer approximately 14–18 studs of clear walking width. Short secondary paths may narrow to 10–12. These are authoring targets, not proven performance requirements. At junctions make room for two players and following fleets to pass.
- Provide a western route to Ruby and onward to Violet, and an eastern route to Cobalt and onward to Emerald. Connect approaches into a small useful loop around central mining activity, rather than building a long empty perimeter promenade.
- Route the Cobalt approach around ImpactTest. The test field must not become a mandatory obstacle or look like the next normal tier.
- Use field-edge portals as anchors: Quartz north `(-56,33)` and south `(-56,97)`; Ruby north `(-176,97)`; Cobalt north `(64,117)`; Violet north `(-296,97)`; Emerald north `(184,137)`. These are X/Z surface locations, not final path polylines. Fit connecting curves to actual station, tree, collision and spawn clearances.
- Preserve both depot access and an unobstructed return to the real Converter. Check route lengths from spawn and from the Converter separately. Quartz must be closest; successive ordinary tiers should not accidentally get easier to reach than earlier ones.
- Use broad gentle ramps for any new terrain height. No required jumping, thin bridges, sharp road lips, stair collisions or decorative holes on the core route. Optional lookout steps must not gate resources.
- Keep ordinary working plots flat and unobstructed. Shape terrain beyond them. Do not create a high ridge across the straight travel line between a working fleet, its owner and the Converter.
- Reserve an open vertical work volume above every resource. Ordinary lasers point straight down, breakers physically touch the surface, and orbital effects extend above the camera. Roofed mines and tree canopies over live rocks are inappropriate.
- Current working source uses an 18-stud horizontal margin around field bounds and 45 studs vertically for silent recall. Author attractive standing and collection space inside that envelope. Verify current values before implementation; scenery must not become a hidden source of order cancellations.

Measure actual avatar traversal after authoring. Track field-to-Converter round trips, time spent walking versus mining, dead ends and unintended recalls. Shorten bad routes before compensating with faster movement, inflated rewards or free teleports.

### Depot composition

Keep the compact original machines. Use a restrained concrete apron, studded trim, metal machinery and clear dark readable sign faces. Avoid a giant white platform. Give each station a modest physical identity that survives low graphics: intake and bins for selling, the original pack stand for choices, a printer bay, and the existing prestige device.

Create a readable service circuit: spawn and first mineral order; nearby sell interaction; Quartz shop and Packs; then fleet/prestige inspection when earned. Keep all five mineral counters visible. Preserve their actual instance references when updating them, since server distance checks may retain those references.

The persistent reward currency belongs in one compact Foundry section of the existing shop interface and a modest physical extension to the depot, not another giant floating dashboard. Place it only after checking the current hub footprint and collision. The Converter currently sits close behind spawn; avoid adding a collision or prompt pile at that point.

No first-spawn modal tour. Explain the next real action with the existing contextual interaction and world highlighting. The player should find Quartz and sell without reading a wall of instructions.

## Field designs

### Landing Quartz

Use warm neutral ground, pale mineral color, low studded retaining corners and an open sky. Keep the first few targets easy to see from spawn. Frame the far edge with a small cluster of original-style parts-built trees, without branches hanging into the work volume. Keep selling and the Quartz shop visible on the return glance.

This field teaches one action at a time: select a rock, see the drone arrive and work, collect real fragments, sell, choose an upgrade. Use existing variation in size and health. A larger boulder should be visibly distinct and optional; it must not dominate the easiest first orders. Do not force the first player into a long shell-to-core sequence before earning a satisfying small payout.

Preserve random placement. If adding encounter-aware placement regions, sample bounded random positions within them; do not create a repetitive crystal grid or guaranteed perfect card-combo arrangement. Keep a usable walk lane without reducing the practical population to a nearly empty field.

### Ruby Grove

Create a warm red and auburn perimeter grove with a readable timber-and-rock mine landmark behind the clearing. The landmark can suggest a mine entrance, but the actual mining field remains outside under open sky. Use a few large authored tree groups, not an even scatter of identical trees.

Ruby introduces greater commitment and backpack pressure while remaining unguarded. Preserve its fuller population and make it a useful field to return to. Arrange visual framing so the player can distinguish ordinary quick rocks from substantial work, and leave room to watch the courier depart for the depot. A stand-alone upgrade here should remove a frustration the player has already experienced.

### Cobalt Ridge

Use cool slate ground, restrained blue hardware and low stepped rock shoulders. A modest original-style relay landmark behind the field should be visible from its approach. Put the first real original segmented pyramid in a clear battle space, with its eye and charge readable before the player commits.

Provide a safe observation apron outside the actual engagement radius and a clear retreat. Do not promise cover unless line-of-sight and hit logic actually support it. Do not allow scenery to become an exploit for infinite safe chip damage. A permanent clearance and this run's mineral access are different states and should remain distinguishable.

After the first clear, Cobalt should feel like earned industrial territory, not merely Quartz in blue. Its lower population and higher work make picking targets, protecting workers and managing replenishment meaningful. Keep the rock grower useful without minting extra population or ignoring replacement tokens.

### Violet Basin

Use muted lavender ground accents, offset low stone ribs and a broad open mining bowl. Keep field surface height stable unless there is a tested reason to move it; a basin can be made by raising surrounding shoulders. Two original pyramids must read as two separate threats, with distinct silhouettes and unobstructed telegraphs.

The field should support several workable standing positions inside the recall envelope. Make movement between clusters understandable, and avoid using deep fog or colored lights to hide targets. Exposed inner layers and large shells should let sustained cutters and breakers contribute differently. A small overlook can reveal the field before commitment, but should not become a dominant safe attack position.

### Deep Emerald

Use darker green peripheral vegetation, exposed pale rock, and one strong machine/construct-related skyline composition. Keep the center visually quieter than the perimeter so a developed fleet remains readable. Build the late-field identity from scale, arrangement and original assets, not enormous glowing crystals everywhere.

This is a test of the player's developed operation. Higher hardness must buy a meaningful reward or achievement, rather than multiplying idle observation. Preserve paired guard threats and give the player useful target decisions after clearing them. Leave space for a larger swarm, multiple players, boulders and orbital work without visual collapse.

### Impact Test

Preserve the field eight studs east of Quartz's edge, its tenfold work multiplier, unchanged equivalent rock rewards, and always-open entitlement. Mark it with a small grounded two-sided sign: Impact Test and 10x rock health. Give it a distinct industrial test-bed finish. It is optional practice and effect inspection, not a required progression step or a secretly lucrative alternate starter route.

## Mining and drone design

The original mining feel is a design asset. Preserve eased and capped travel, stable overhead mining stations, level yaw, smooth follow/separation, original rock geometry, grow-in and fracture staging. Read `docs/ORIGINAL_FEEL_PARITY.md`, `docs/MINING_SATISFACTION.md` and the original sources. Preserve the latest accelerating breaker descent, surface landing, roughly one-second hold, delayed fracture and separate contact/fracture feedback.

Current field hardness values are 1, 1.8, 3.2, 5.2 and 8. At a representative ordinary mass of 75, `Mining.resource` currently gives 195 times hardness units of work. Dividing by the configured base 30 DPS produces 6.5, 11.7, 20.8, 33.8 and 52 seconds of raw work before role modifiers. These are arithmetic baselines only: real arrival, charge, layers, multiple workers, abilities, drops, selling and contention change results. Do not mistake these estimates for measured fun or actual break times.

Measure useful outcomes per complete trip. Balance harder fields against their currency's useful purchases and earned milestones, not only their numeric Value field. Different mineral wallets are not automatically interchangeable income. Preserve the current finite pickup lifetime; do not make selling and returning to recover expired drops the expected loop.

### New roles should solve jobs

The owner separately rejected gimmicky drone concepts and clarified that they should remain drones with lasers and useful science-fiction machinery, comparable to mini-drone swarms and orbital equipment. Effects such as chain lightning or a different colored beam do not justify a whole permanent role.

Audit the existing Miner, Breaker, Healer, Backpack Emptier, Rock Grower, Orbital Controller and Swarm Fabricator first. Fix a weak existing role before adding another nearly identical one. Keep the grower's saved Dart identity and current role migration intact.

Brainstorm at least eight plausible additions internally, compare them by job, target, tradeoff, readability, server complexity and overlap, then implement the strongest small set. Aim for two complete new roles rather than eight partially working ones. Record rejected candidates briefly so the next pass does not repeat the exercise.

| Candidate | Useful job | Real tradeoff | Implementation direction |
|---|---|---|---|
| Heavy Miner | Sustained work on very hard single targets | Slower relocation and longer setup; wasteful on tiny rocks | Original mechanical drone silhouette with a substantial emitter; continuous vertical work and readable vent/recovery |
| Harvester | Several small rocks worked at once | Fixed total power split across a small bounded target count; poor against hard shells | A wider original-derived frame with separate downward emitters; server reserves each actual target |
| Power Drone | Reduces workers' repeated charge downtime | Support opportunity cost and limited service rate | Physically flies to an eligible worker and transfers one bounded preparation benefit; cannot stack unlimited instant starts |
| Gunship | Dedicated anti-guard combat | No ordinary mining; occupies a real fleet role | Recognizable drone with actual server-owned repeated shots and clear target acquisition |
| Recovery Drone | Retrieves endangered allies before destruction | Limited rescue opportunity; less productive than a worker | Consider only if encounter anti-attrition rules remain intact |
| Survey Drone | Helps identify profitable actual targets | Information must change a real decision, not add labels | Consider an earned utility upgrade first; do not recreate the rejected ineffective scout |
| Shield Support | Protects a nearby committed crew | Limited duration, coverage and recharge | Consider only if it produces a readable decision distinct from the healer |
| Logistics Carrier | Handles a genuinely different hauling job | Payload or travel tradeoff | Reject if it simply duplicates the existing backpack emptier |

Prefer Heavy Miner and Harvester if they test as distinct and worthwhile. Power Drone and Gunship are strong alternatives if the actual bottlenecks justify them. Do not add elemental damage types, recipe crafting, drone personalities or arbitrary rock-paper-scissors rules merely to populate the catalog.

For each implemented role, specify acquisition, target preference, phases, cancel conditions, death/reprint behavior, authoritative reservations, visual silhouette, sound priority and expected strengths/weaknesses. Test with the same fleet budget against small rocks, boulders, shells, depleted fields and guarded fields. A role should win some comparisons and lose others. Preserve original models by deriving hardware carefully, not replacing the whole fleet with generic spheres or humanoids.

## Progression and better shops

Keep three complementary progression layers: this run's mineral income and shop purchases; temporary pack choices; permanent fleet growth and earned master rewards. The player should understand what resets without studying an economy spreadsheet.

Keep the sequential mineral access chain and permanent guard clearance distinction. Buying access does not defeat guards. Prestige resets run cards, mineral wallets and run shop progression as current rules specify; permanent drones and earned guard clearance remain. Show the exact reset summary before confirmation, including the new persistent currency and permanent licenses.

Audit the first 5, 15, 30 and 60 minutes through reproducible economy simulations and actual play where available. Targets for review: first successful mining order within seconds of control; first meaningful purchase after a small number of successful trips; one visible change in how the operation works early; first permanent milestone within a session that feels achievable. Derive actual numerical targets from the current baseline instead of silently restoring historical timings.

Early upgrades should remove specific chores after the player experiences them: individual orders become field orders, hauling becomes less intrusive, planting repairs depleted work, pack reveal becomes faster. Automation is earned. Avoid opening every system at spawn or selling an upgrade whose effect is impossible to notice.

### Shop interface

- Retain one compact window using the approved simple colorful textured skin, native Roblox fonts, clear rounded shapes, existing object outlines and meaningful artwork.
- Show all mineral tabs, including locked ones. A locked tab states which previous shop unlocks it. Do not hide the route forward.
- Use equal-sized upgrade cells with a short benefit, price in the matching mineral, Buy and a separate Info action for full terms. Keep the primary action visible on touch.
- Group access, automation and role equipment sensibly. Put the next relevant purchase early; do not cover the screen with every future upgrade.
- Show current and next behavior concretely: parcel capacity, target count, charge seconds, planting cooldown or reveal speed. Avoid unsupported vague claims such as much stronger.
- Explain owned, capped, unavailable, insufficient funds and stale-price states distinctly. A pending request must not look like a second purchasable copy.
- Keep upgrades useful alone. Do not introduce an explicit combo dependency tree; the owner rejected that interpretation of N-Gon inspiration.
- Persist transactions before reporting success. Test repeated clicks, reconnect after payment, old run IDs, changed levels, locked minerals and the response-loss path.
- Preserve current server-generated packs with three saved choices and one selection. Do not use the master currency to reroll a paid offer or create another random pack economy.

## Persistent master currency and worthwhile rewards

Introduce one earned persistent currency, working name **Cores**. The desired quality borrowed from the owner's gem analogy is a clear scarce currency that leads to memorable rewards. It does not imply Robux sales, copied visuals, premium pressure, random paid chests, login streaks or time-limited offers.

Cores survive prestige and reconnect. They come from verified achievements and substantial milestones in the actual mining loop. They should not drop from every rock, convert automatically from endless Quartz, or reward idling and repeatable prestige loops that can be farmed without meaningful work.

### Initial earning model

Implement a small explicit first-clear ledger. Candidate milestones are the first meaningful sold-Quartz total, first Ruby access plus real Ruby sales, first Cobalt guard clearance, first Violet clearance, first Emerald clearance, and genuinely new prestige milestones. Existing profiles must receive appropriate one-time credit for verifiable historical achievements; do not guess missing history or grant an unbounded backfill.

Start tuning around a visible early award of 2–3 Cores, midgame milestones of 3–5, and major frontier achievements of 6–10. A first meaningful reward around 6–8 Cores and a major prototype around 12–20 are initial modeling values, not approved final balance. Simulate a starter player, a skilled returning player and an exploit-seeking repeated-reset player. Adjust the complete earning/spending curve before shipping it.

The first award should preview a concrete attainable reward. The UI must state the next available source and exact remaining cost. Use a brief contextual celebration at a real accomplishment, not a permanent shower of effects or constant exclamation marks.

### Reward catalog

1. **Prototype licenses:** choose a clearly described new drone role for a future earned prestige grant. Unlocking a license does not instantly add a second starting drone or grant extra drones. The next valid prestige still adds exactly one permanent drone. The player deliberately chooses an eligible unlocked role through a durable choice; preserve already-pending grants and legacy deterministic guarantees.
2. **Permanent role sidegrades:** a small, inspectable specialization with a genuine tradeoff, attached separately from immutable base traits. Implement only if it remains understandable and bounded. Prefer one equipped specialization per drone over an unlimited permanent multiplier stack. Show the exact tradeoff and let the player change an already-owned sidegrade without repurchasing it.
3. **Visible fleet rewards:** an original-derived emitter/hardware finish, bounded landing or reprint flourish, and perhaps a meaningful depot display of earned achievements. These give a desirable spend without erasing balance or cluttering the world.

Launch with a small finished catalog, including at least one reward that changes future play and one attractive visible reward. A currency with nothing compelling to buy is not complete. Do not sell ordinary run access, skip the first guard challenge, bypass all manual mining at spawn, or make permanent power mandatory to recover acceptable starter pacing.

Keep two currencies visually distinct: the current mineral is immediate operating income; Cores are a scarce long-term balance visible in the Foundry and compact HUD when relevant. Do not add tickets, fragments, keys and crafting dust on top.

### Persistence and transaction requirements

Add a versioned profile migration with nonnegative integer balance, a claimed-milestone set, permanent licenses, equipped sidegrades if implemented, and pending reward choice state. Use the existing update/receipt machinery. Award-and-mark-claimed is one atomic operation; debit-and-grant is one atomic operation. Include transaction IDs and run/lifetime scope. Failed loads, stale sessions and save uncertainty cannot grant or spend optimistically.

Test duplicate award events, simultaneous award/purchase, response loss after commit, reconnect before display, purchase retries, stale price/catalog version, prestige during a pending selection, malformed balances and migration replay. Verify existing profiles retain every drone ID/base trait and every paid pending offer. Avoid irreversible migrations without a preserved input fixture and explicit compatibility checks.

## Lighting and the Roblox finish

Make the game look intentionally built in Roblox. Use strong simple silhouettes, real studs where appropriate, native Plastic/SmoothPlastic/Concrete/Metal/Slate/Ground variety, restrained bevel-like edge construction, and coherent ground-to-building contact. Match the current colorful textured interface without turning the entire map into glossy neon.

Use clear daytime lighting as the baseline. Retain useful shadows and separation between rocks, drones and floor. Avoid heavy depth of field, excessive exposure, milky fog, white clipped paths, indistinct mint terrain and over-shiny plastic. Keep a restrained environmental palette and let active work effects carry the brightest accents.

Gameplay energy still needs visible bloom and role-specific behavior, per the latest owner request. Improve the material, brightness, emitter placement and local effect composition together; do not wash out the whole scene just to make one effect glow. Preserve the current particle-visibility correction when integrating. At low graphics, clear shapes, motion and contact must still communicate the event even if bloom is reduced.

Differentiate fields with ground material, perimeter silhouettes, two or three supporting colors and a landmark. Do not rely solely on hue. Ordinary rocks, blackening layers, warm orbital contact, white downward streaks, pickups and selection highlights must all remain legible against the background.

Inspect at the real starting camera, normal zoom and close range. Check from both directions on every path. Look for floating trees, buried feet, unsupported terraces, mismatched road heights, canopy clipping, sign backs, repeated prop spacing, empty station faces and expensive clutter. Fix composition at the camera scale the player actually uses.

## Technical implementation route

Use current repository conventions. Likely touch points are `World.lua`, `MapLayout.lua`, `Config.lua`, `ShopStands.lua`, `Shops.lua`, `ShopView.lua`, `Profile.lua`, `Persistence.lua`, `DroneRoles.lua`, `DroneConfig.lua`, `Mining.lua`, `Server.lua`, `Client.lua`, lighting modules and the relevant presentation modules. Inspect their actual interfaces before choosing files. Keep new pure economy and layout rules separate enough to test meaningfully.

Author one deterministic layout specification consumed by both editable application and runtime initialization. Do not maintain two unrelated coordinate tables that drift. Reapplying the layout must update existing generated objects, preserve original identities, avoid accumulating scenery, and leave unrelated instances and backup scripts untouched. Track a layout version without relying on repeated relative offsets.

The current build allowlist contains seven live Sources: `ServerScriptService.GlobalDroneControl`, `StarterPlayer.StarterPlayerScripts.ClientDroneControl`, `ReplicatedStorage.Shared.DroneConfig`, `ReplicatedStorage.Shared.TacticalHUD`, `ReplicatedStorage.Shared.CrystalAudio`, `ServerScriptService.DroneRoleEffects`, and `ServerScriptService.MiningDiscoveries`. Do not expand this allowlist casually or patch scripts by name alone; backups may share names. Bundle new modules through the established live entry points where appropriate.

Keep generated scenery anchored and simple. Decorative details should not receive a per-frame loop. Use bounded pools and existing budgets for lights, particles, contacts, pickups and highlights. Keep invisible decoration out of raycast and collision work where appropriate. Never copy the original construct's thousands of editor-history instances into every live guard; preserve the source template while using the existing active-clone behavior.

Check repeated layout application, respawn, prestige, field exhaustion, late joins and long sessions for growth in connections, instances, effects or work queues. Measure before optimizing. Avoid a large rewrite of working movement or persistence just because a new feature needs one hook.

## Work sequence

1. Establish current branch and integrated baseline. Read owner requirements, inspect active map path, inventory assets, run relevant baseline checks and record existing failures. Save a concise implementation checklist.
2. Build the connected map with the existing anchors and original assets. Finish the depot-to-Quartz experience and one strong field slice, inspect it, then apply the learned construction language to the other fields. Make the Edit application idempotent.
3. Audit mining pacing and current role usefulness. Implement and validate the strongest two new drone jobs, or document a tested reason to substitute one candidate. Integrate acquisition through earned progression.
4. Improve shop clarity and standalone upgrades. Keep existing purchases/offers compatible. Tune first-session choices against actual complete-trip measurements.
5. Implement Cores, its durable ledger, first rewards and compact Foundry presentation. Finish earning, spending, recovery, reset explanations and acquisition together.
6. Refine lighting, field composition, effects visibility, sound mix and UI consistency on the integrated candidate. Preserve current approved movement and the latest local refinements.
7. Perform the separate reviews below, fix findings, rerun affected checks, and capture fresh final evidence. Repeat until no known blocking defects remain; do not stop after the first visually plausible version.
8. Produce the reproducible build, exact commit, review PR and final evidence report. Keep implementation gaps explicit instead of calling a partial feature complete.

If Studio or another integration is unavailable, keep implementing and testing all available logic and build work. Produce the exact native validation procedure and list the unavailable evidence. A missing renderer does not justify abandoning productive work, and a schematic is not a Roblox screenshot.

## Repeated review and completion gate

The owner's phrase flawless means a high bar and persistent defect fixing. It is not permission to claim perfection without evidence. Maintain a concrete issue ledger with severity, reproduction, fix, verification and exact revision. Each iteration should eliminate a real problem or answer an unresolved question.

### Review one for behavior and preservation

Verify original assets and movement, real downward contact, distinct role behavior, target arrival gates, earned automation, full-bag semantics, finite drop lifetime, one starting drone, exactly one prestige grant, permanent identity and traits, free reprints, permanent guard clearances, three saved pack choices, run resets, migration safety and server validation. Inspect malicious/repeated/stale requests as well as the happy path.

Test actual production modules and integrations. API doubles can establish branches and bounds, but do not label them native visual or multiplayer playtests. Preserve baseline fixture coverage and add tests for consequential new logic, not tests that merely repeat a constant or assert your implementation's shape.

### Review two for pacing and enjoyment

Run comparable sessions with a fresh profile, an early returning fleet and a developed fleet. Record crew, upgrades, field, target choices, mining/warmup/travel shares, sold mineral per minute, first purchase, first changed behavior, first Core reward and first new permanent role. Separate failures and guard attempts from mining throughput.

Ask whether the player can explain why they picked a rock, field, drone and purchase. Check for a universally dominant role, useless shop items, long empty trips, reward stockpiling, depleted-field waiting, mandatory oversized boulders, confusing currency purposes and prestige that feels like losing everything. Fix those problems before adding more decorative content.

### Review three for native visual quality

Inspect actual Roblox engine output from spawn, every approach, each field, selling, shopping, packs and prestige. Include normal motion, close contacts, orbital strikes, breaker landing and fracture, new drone jobs, busy fleets, reduced motion, low/high graphics, desktop and narrow touch layouts.

Reject floating or buried props, bad ground joins, clipping beams, effects through solid surfaces, invisible particles, bright opaque particle squares, snapping motion, too much shake, unreadable card/shop text, giant debug panels and generic empty platforms. The existing independent art-direction gate applies. Source quality, mocked screenshots and old screenshots cannot approve the final revision.

### Review four for multiplayer and durability

Use at least two players and a late join when the environment supports real Studio testing. Observe the same mining, guard, growth and ability events on both clients. Check contested resources, independent entitlements, owner-bound drops, new Harvester reservations, cooperative/noncooperative proximity, disconnected owners and duplicated reward requests. Profile a busy session and a longer soak for accumulation.

After a fix, rerun the checks affected by it and refresh final-candidate evidence. Do not repeat an unchanged suite indefinitely just to consume tokens. Continue until the issue ledger has no known blocking failures and every required deliverable is complete, or identify the exact external capability that prevents the remaining verification.

## Required delivery

- Actual source changes implementing the map and broader game improvements, with clear commits on the authorized branch and a review PR.
- `build/Drone Blower revolution.rbxl` built from the verified active capture and a revision manifest with exact source commit, dirty/clean state and output hash.
- Reproducible Edit-mode layout script and, if Studio is available, a saved native editable Workspace copy with sources matching the integrated revision.
- A concise design/results report explaining new roles, progression, shop changes, Core earning and rewards, balance assumptions, and any deliberate deviations from this brief.
- Test results identifying what ran as production logic, API doubles, real Studio gameplay, visual inspection, multiplayer and persistence checks.
- Fresh actual screenshots and motion evidence for the final integrated candidate where available. Clearly distinguish NOT VERIFIED items.
- A brief owner test route: spawn, mine, sell, buy, choose a pack, try the new role, reach a guarded field, earn/spend Cores and inspect prestige. Include how to use isolated preview controls without modifying permanent ownership.

The final answer should lead with what changed and how to open/review it. Include the exact integrated revision, the largest remaining limitation, and concrete evidence. Do not publish, merge main, fabricate visual approval, or finish with only a brainstorm and an offer to implement later.
