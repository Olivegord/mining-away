# Mining Away — gameplay direction

**The pitch:** Command a growing crew of mining drones, discover valuable deposits, crack enormous geodes, and turn each haul into new ways to work the mine.

The feeling to aim for: **“One more haul and I can build the drone that cracks that deposit.”**

This is a proposed design, grounded in the existing prototype. All pacing and economy numbers below are starting targets for playtesting, not measured results or promises of retention.

## What is already there

I inspected the `mining away` scene and the live `ServerScriptService.GlobalDroneControl` script in Roblox Studio. I also inspected extracted scripts from historical local saves at `/Users/sorenwidman/Documents/Roblox/server.rbxl` and `/Users/sorenwidman/Documents/Roblox/ScriptAutosaves/Place_AutoRecovery_4.rbxl`. The live script takes precedence where tuning differs.

Verified in the live controller:

- Players receive a random two to five drones, with following formations and flight movement.
- Drones can be assigned to a patch, reserve an available crystal, mine it, and automatically seek another.
- Ruby supports 16 crystals and cobalt supports three. Both currently award 20 generic ore per broken crystal.
- Mining has staged crystal changes and crack/break audio, with beam infrastructure.
- Storage caps at 2,000 ore. Full storage recalls the drones; selling converts ore into currency at 1:1.
- Individual crystals replenish after a short delay, allowing a patch to be farmed continuously.

The historical client dispatches every owned drone when a patch is clicked and sells through the Converter prompt. No purchase, upgrade, contract, zone-unlock, or saving systems appeared in the scripts inspected. The historical saves differ from the live version, so absence there does not establish absence from every live object.

I opened a local play session and viewed the running scene. Computer controls could not complete the mining/selling interaction, so this review does not claim a verified end-to-end playthrough. I stopped the test and returned Studio to edit mode. No prototype scripts or place files were edited.

## The core loop

**Pick a goal → scout deposits → assign the crew → mine and crack → bank the haul → change the fleet → reach a new mining problem.**

1. **Pick a goal at the depot.** One short contract gives the outing a purpose: deliver ruby, extract a cobalt core, or clear a surveyed vein. Contracts persist without expiration.
2. **Scout a compact mining area.** See two or three plausible jobs: a broad crystal field, a dense geode, or a distant rich seam. A brief scanner interaction reveals what makes a deposit valuable.
3. **Assign drones.** One tap sends the crew automatically; a simple fleet strip lets the player split or recall part of it. Drones keep choosing their own individual targets inside their assignment.
4. **Work the deposit.** While drones mine, the player surveys a nearby seam, prioritizes a target, explores the next pocket, or brings more drones to a geode. Stay close enough to see the crew and its progress.
5. **Bank the haul.** Return when cargo fills, the contract is ready, or a purchase becomes affordable. The Converter gives one clear payout and automatically applies material deliveries to the selected contract.
6. **Make a visible improvement.** Buy an attachment, improve cargo or travel, or earn a new fleet slot. The next outing should immediately demonstrate the change.

Keep controls to a small set: **assign, split, recall, scan**. Use large world targets and touch-friendly buttons; precise repeated clicking should not drive normal mining.

## The signature moment: cracking a geode

A huge mineral shell sits among ordinary crystals. It visibly accepts up to three drones, making concentrated mining useful. Its cracks spread, the sound builds, and the shell bursts apart to reveal a core surrounded by smaller crystals. Drones then fan out across the new targets automatically.

This gives the swarm a readable sequence: **converge → synchronized beams → enormous break → scatter → gather.** Reuse the existing beam, fracture-stage, crystal-spawn, and targeting systems.

The player chooses whether to commit three drones for an earlier breakthrough or leave some collecting reliable contract ore elsewhere. Geodes provide distinctive contract progress and discoveries; they should not always beat ordinary crystals on credits per drone-second.

For the first version, an exposed core remains available until mined. A timing bonus can be tested later on occasional special geodes, with advance warning and no loss of the base haul. The foundation should work without compulsory reaction windows.

**Required change:** Ordinary crystals can keep one mining slot. Geodes need multiple explicit slots and diminishing benefit beyond their displayed limit. The current exclusive reservation system cannot support focus mining as written.

## Keep the player involved

The player is the crew's surveyor and dispatcher. The scanner exposes a rich seam or identifies a useful property; it does not need to be held against every crystal. A single scan should inform a decision that stays useful for the rest of that deposit.

While mining continues, the player can:

- Find the next deposit within the local working area.
- Reveal and prioritize a rich seam.
- Shift a spare drone from a nearly finished pocket to a geode.
- Decide whether to finish the pocket or return for an affordable upgrade.

Idle mining can remain productive. Active scouting should offer better routes and discoveries without multiplying normal income so much that scanning becomes a compulsory chore.

Patches should be finite jobs. Replace continuous crystal-by-crystal replenishment with a visible depleted pocket and a refresh after players have had reason to work elsewhere. Always provide fresh nearby alternatives. Tune refresh against travel time and server population; avoid making players wait for respawns.

## Make deposits change the plan

| Deposit | What makes it different | Useful response |
| --- | --- | --- |
| Ruby field | Many small, brittle crystals close together | Spread the crew; use a splitter attachment |
| Cobalt geode | A few armored shells with valuable cores | Concentrate drills; bring a core-drill attachment |
| Mixed vein | Ordinary crystals surround a surveyed rich seam | Scan, prioritize the seam, then choose whether to finish |

Keep the mechanics understandable from silhouette, beam response, labels, and sound. Ruby and cobalt need different extraction behavior and contract uses, beyond different colors or sale prices.

## Drones and upgrades

Start everyone with **three reliable drones**. Consistent starting strength makes early choices and balance legible. Let players name and recolor drones, and make hardware changes visible on their models.

Use a modest active fleet cap: three initially, a fourth during early progression, and perhaps six later. Extra drones are major milestones because they improve throughput and parallel coverage together. Most upgrades should create interesting choices at the same fleet size.

Each drone begins with one attachment slot. Purchased attachments can be swapped freely at a depot:

| Attachment | Behavior | Tradeoff |
| --- | --- | --- |
| Splitter | A beam splashes into nearby brittle crystals | Less effective on armored shells |
| Core drill | Efficiently breaks geode armor | Gives up the splitter's field-clearing benefit |
| Survey lens, later | Improves extraction from a revealed rich seam | Requires surveying and target choice to pay off |

Ordinary travel, drill-power, and cargo upgrades support this system. Group purchases into changes players can feel rather than a long series of tiny percentage increases. Cargo should grow alongside fleet strength so earning more drones does not simply create constant selling trips.

Later management upgrades can add a second queued local job or a saved loadout. Avoid unlimited distant work queues that remove scouting and assignment from the loop.

## Economy and progression

Use **one spendable currency: credits**. Cargo tracks mineral types so contracts can ask for ruby or cobalt. Banking automatically pays credits and records the relevant delivery; players do not need a separate crafting wallet in the first version.

- Credits purchase upgrades and attachments.
- A small number of clear contracts unlock blueprints, fleet slots, and region permits directly.
- Discoveries fill a survey journal with named deposits, drone appearances, and optional challenge goals.

Show one next goal prominently: **“Deliver two cobalt cores to unlock the Core Drill blueprint.”** Preview the reward and the deposit it will help with.

Short progression: a better haul or a useful attachment. Session progression: a drone slot, blueprint, or new region. Long progression: complete the mine's survey, develop different fleet loadouts, and master new extraction problems.

Each region introduces one new behavior. A surface quarry teaches basic assignments; a cobalt cavern teaches shell cracking; a later linked-crystal area rewards working neighboring targets together. Preserve earlier hardware choices as alternatives. Delay any prestige/reset system until the expedition loop has proven enjoyable through several sessions.

## First ten minutes

| Time target | Experience | What the player learns |
| --- | --- | --- |
| 0–1 minute | Spawn beside the depot with three drones. Tap a nearby ruby pocket and see immediate flight, beams, cracks, and ore. | Commands produce visible action. |
| 1–2 minutes | Bank a first haul. Purchase an attachment with a short preview; make the first useful purchase affordable after this trip. | Selling changes the next outing. |
| 2–4 minutes | Choose between a broad field and a tougher pocket. Try splitting or concentrating the crew. | Loadout and allocation matter. |
| 4–6 minutes | Survey a rich seam and complete a short delivery contract. | The player can find better opportunities. |
| 6–8 minutes | Crack a guaranteed introductory geode and watch the crew fan out. Earn meaningful blueprint or fleet-slot progress. | There are larger payoffs to seek. |
| 8–10 minutes | See the entrance to the next region, its distinctive deposits, and the exact permit requirement. | There is a concrete next goal. |

These events should respond to player progress rather than a hidden timer. The introductory geode is guaranteed tutorial content, not a rare roll needed to progress.

## Social play and replayability

Ordinary mining must retain personal entitlement: another player's faster fleet cannot take the crystal you were about to harvest. The current shared reservation model needs a deliberate multiplayer reward rule before scaling up.

Later, add optional shared mother lodes with visible contribution, a reasonable reward for each participant, and a maximum required commitment. Let advanced players show their unusual attachments and fleet appearances in the shared depot. Cooperative mining should be an opportunity players can join when convenient.

Replayability comes from changing local deposit layouts, choosing contracts, finding rare variants, and trying different loadouts. Keep progression rewards reachable through explicit goals. Reserve rarity primarily for discoveries and cosmetic expression.

## Build order

**First playable slice:** One compact area, three fixed starting drones, a clear assignment/recall interface, one finite ruby pocket, one multi-drone cobalt geode, one Converter, one meaningful attachment choice, one short contract, and saved progress. The geode should turn into mineable smaller targets using the existing spawning system.

**Second pass:** Split assignments, one scanner interaction, both attachment behaviors, a clear fourth-drone milestone, and a second region preview. Adjust cargo, travel, rewards, and prices together.

**Expansion after playtests:** A second extraction problem, more loadouts, discoveries, and finally cooperative mother lodes.

Resolve the following prototype constraints while building the slice:

- Mining damage currently subtracts a fixed amount per Heartbeat. Use elapsed time so server frame rate does not decide mining speed.
- Separate single-slot crystal reservation from multi-slot geode assignment. Release old reservations when switching jobs or disconnecting.
- Store ore by material while retaining one readable cargo-capacity bar.
- Keep mining rewards, selling, upgrades, and contract completion authoritative on the server. Derive the seller from the invoking Player rather than trusting a client-supplied player ID; validate assignment targets and requests. This follows [Roblox's client/server security guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).
- Add persistence before treating repeat-session progression as tested.

## What would prove the loop works

Watch a small playtest before adding more content:

- Can a new player command drones and reach the first sale without help?
- Does the first attachment visibly change what they choose to mine?
- After cracking one geode, do they independently seek another?
- Do players voluntarily scout or reassign while drones work?
- After selling, can they name something specific they want to earn or try next?
- Does anyone have to compete with other players just to make ordinary progress?

If players stand at one patch and wait, improve deposit choices and the geode payoff before expanding the map. If they constantly babysit drones, simplify commands and preserve automatic targeting.

The structure follows Roblox's distinction between moment-to-moment actions, a repeated reward loop, and a progression engine; the drone mechanics and tuning proposed here are original recommendations for this prototype. See [Roblox Creator Hub: Core loops](https://create.roblox.com/docs/production/game-design/core-loops).
