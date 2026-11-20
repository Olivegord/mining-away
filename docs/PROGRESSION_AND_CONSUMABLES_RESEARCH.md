# Progression that changes play

Research and implementation notes, November 5, 2026. Applies to the existing Drone Blower revolution, place `136098934779395`, and only `build/DRONE_GAME.rbxl`.

The owner asked for research into progression, tycoons and chance-based games, using Bee Swarm Simulator as one exemplar, and suggested consumable rock drops such as an orbital laser stored in a new backpack slot. The concrete item counts, probabilities and deployment rules below are implementation choices, not quotations from the owner or experimentally established optimums.

## Findings and their application

| Evidence | Useful lesson for this game |
| --- | --- |
| Bee Swarm's official description combines collecting/converting, quests, a growing swarm, access farther up the mountain, combat, hidden treasures and workers with different traits. [Onett's game page](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator) | My interpretation: give the player overlapping reasons to make the next trip. Immediate rock loot, a useful pack choice, a new route and a permanent worker should coexist. Copying the field layout or multiplying mining speed reproduces only a small part of that structure. |
| Factorio's designers criticized an introduction that delayed automation, constrained actions, assigned resource quotas without a meaningful purpose and overwhelmed players with messages. [Friday Facts 241](https://www.factorio.com/blog/post/fff-241) | Let the first minute demonstrate the interesting action. An early equipment drop can show the orbital system before a player grinds through several shops. Keep the learning in the field and avoid another tutorial panel. |
| Factorio's campaign reassessment emphasizes self-directed discovery of better methods and the cost of forcing players to restart their construction. [Friday Facts 329](https://www.factorio.com/blog/post/fff-329) | Allow players to recognize a bottleneck and choose its solution. Preserve the permanent fleet and stored tools through prestige, while clearly resetting run modifiers. Do not turn every manual step into forced automation. |
| Satisfactory describes player-built factories, expeditions for new resources, transport to distant outposts and reducing manual labor through logistics. [Official features](https://www.satisfactorygame.com/) | The transferable tycoon pleasure is seeing a working production system become more capable. This game's carriers, couriers, storage and launch capsule should visibly solve travel and capacity problems. A purchase should change a route or an operation, not just a number. |
| Slay the Spire's developer description combines changing routes and discoveries with deliberate card and route choices. [Mega Crit's Steam page](https://store.steampowered.com/app/646570/Slay_the_Spire/) | Randomness can present an opportunity; the player should decide how to exploit it. A found Orbital Beacon asks which hard rock deserves it. A found Scrap Capsule asks where a dense group of leftovers makes deployment worthwhile. |
| Balatro explicitly emphasizes discovering Jokers that transform play and combining their effects. [Official site](https://www.playbalatro.com/) | Interesting upgrades create visible consequences. Preserve this project's standalone-upgrade direction: a tool must be good on its own, without requiring a secret combination or copying another game's art. |
| Four studies linked perceived competence and autonomy with game enjoyment; the multiplayer study also supported relatedness. [Ryan, Rigby and Przybylski, 2006](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf) | Provide understandable decisions and reliable feedback. Choosing the deployment area, seeing the target and getting the promised result should make the player feel responsible for the outcome. These studies do not prove a particular drop rate improves retention. |
| Four reward studies found that uncertain reward magnitude could increase effort when attention was on pursuit; the effect did not hold when attention was on the outcome. [Shen, Fishbach and Hsee, 2015](https://luxi-shen-4unh.squarespace.com/s/2015_ShenFishbachHsee_Uncertainty_GoalPersuit_JCR.pdf) | This is limited evidence about motivation in reward tasks, not a recipe for fun or justification for worse payouts. Use surprise as an extra reward on top of reliable ore. Keep ordinary progression viable without luck. |
| A theoretical account connects enjoyment of uncertain success with learning and doing better than expected. It is a proposed explanatory model, not a controlled test of this game. [Deterding et al., 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9363017/) | Make outcomes learnable: a tough isolated rock favors the orbital, whereas nearby small remnants favor the bots. The player should get better at spotting good opportunities. |

Successful games are useful case studies, but popularity alone cannot identify which mechanic caused enjoyment. The implementations here are hypotheses informed by those sources. Mega Crit's own balancing talk describes using both metrics and community feedback while preserving feel and difficulty; that is the appropriate follow-through. [GDC, 2019](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics)

## Implemented loop

**Mine a rock → discover a physical equipment capsule → collect it into a tools pocket → choose an advantageous position → deploy it → collect the normal ore → invest in the fleet and logistics.**

The old ten-second `2x ORE` and `2x MINING` discoveries are replaced. Stored equipment does not auto-activate and does not occupy ore capacity. It survives death, orderly reconnects and prestige through the existing profile persistence. World capsules remain owner-bound, expire after 30 seconds and collect within seven studs with a clear path. Collected tools use ordinary profile saving; an abrupt failure before autosave can still lose newly unsaved rewards, as with other mining progress.

| Equipment | Actual action | Decision |
| --- | --- | --- |
| Orbital Beacon | Place within 60 studs in an unlocked, unguarded field. A 12-stud placement radius chooses the nearest ready, eligible rock. Following the existing 1.4-second charge, the existing orbital beam melts its remaining work over four accepted seconds. | Spend it on a particularly tough rock, or keep it for a deeper field. The preview outlines the candidate. Geodes reveal their existing core/shards rather than erasing the entire encounter. |
| Scrap Capsule | Place a beacon with a 16-stud work radius. Six miniature miners travel from the beacon and work for ten seconds using the real mining contact path. | Find closely spaced, partly mined rocks. Travel and contact time matter, and the bots cannot reach across the whole field. |

Both actions remain independent of owned Orbiter/Scrapper drones and purchased cooldown abilities. The original drone artwork, regular mining, specialist behavior, card offers, crystal feedback and world remain intact. A small numerical correction also prevents completed orbital burns leaving microscopic health residues.

Two compact pockets each hold three charges. On desktop, **Z / X** selects a pocket, then a world click places the tool; **Escape** cancels. On touch, select the pocket, tap a position, then use **Place tool**. On controller, D-pad left/right selects, R1/R2 places at the center aim, and B cancels. Counts come from the server; previews do not predict rewards or spend inventory.

The server validates the field, distance, placement bounds, line of sight, readiness, living worker and other players' reservations. It saves a versioned reservation before deployment, returns a tool canceled before any accepted contact, and recovers an unused saved reservation on reload. Once real mining begins, canceling does not refund it. One consumable deployment per player keeps the cost bounded. A rock touched by a consumable cannot generate another equipment drop; this also propagates through geode descendants.

## Chance and pacing

The first Orbital Beacon appears on the third eligible break. After collection, the first Scrap Capsule appears on the fifth eligible break. Subsequently, base chance is 18% in the first field, rising three percentage points per field to a 30% ceiling. The eighth eligible break guarantees a tool. The roll chooses an available pocket, so a full stack does not replace a usable reward with overflow.

An eligible break is a rewarded, fully depleted rock with an available equipment pocket, no existing world capsule for that owner, and no consumable contribution. Growth, unbroken geode shells and client requests do not advance the counter. A missed world capsule does not erase the earned guarantee. At two full pockets the counter pauses; use a tool to make room. There is no paid roll, near-miss animation or required rare drop.

A deterministic 20,000-break simulation per tier, immediately collecting and spending each drop, gives the following **opportunity counts**, not wall-clock session timings:

| Tier | Mean breaks per tool | Median | 90th percentile | Maximum |
| --- | ---: | ---: | ---: | ---: |
| 1 | 4.36 | 4 | 8 | 8 |
| 2 | 4.04 | 3 | 8 | 8 |
| 3 | 3.73 | 3 | 8 | 8 |
| 4 | 3.38 | 3 | 8 | 8 |
| 5 | 3.14 | 2 | 7 | 8 |

Travel, field hardness, collection, full pockets and deployment time will change the actual cadence. Higher-tier chance alone may not compensate for substantially longer rock times; measure useful tools and ore per minute together. The three-charge cap and predictable replenishment are intended to encourage use, but player behavior must establish whether they do.

## Next design priorities and playtest decisions

These are recommendations, not additional implemented features:

- **Make logistics purchases answer an experienced problem.** The first courier should remove a clearly felt selling trip; a carrier should create a useful second work site; orbital storage should make a profitable expedition visibly pay off. Measure time moving goods and time waiting before changing prices.
- **Make fields create different situations.** Durable isolated boulders, compact clusters and profitable guarded deposits can favor different crews/tools. Avoid increasing all health values while leaving reward, density and travel unchanged.
- **Keep goals at several distances.** An immediately useful drop, a near-term functional purchase and a longer-term permanent drone give a session several natural stopping and return points. Do not add large repeated quotas merely to extend playtime.

For the first real playtest, use the production one-drone start as well as the existing full preview crew. Record time to first drop, collection, first deployment and first useful purchase; no preview crew measurement should be presented as new-player pacing. Compare a hard rock and clustered remnants with and without the appropriate tool, including charge, travel, ore collection and selling. Ask the player to explain why they chose that position and whether the tool was worth using. Observe hoarding, empty deployments, stealing/obstruction frustration, and opportunities to use one tool more effectively than the other.

Inspect the exact saved build at desktop and phone sizes, with touch/controller and reduced graphics, then with two players and a late join. Check pocket legibility, placement radius, target correspondence, other-owner drops, all-observer beams/bots and cleanup. Successful automated checks do not establish enjoyment, engine appearance, input ergonomics or multiplayer behavior. See [implementation validation](review/CONSUMABLE_GAMEPLAY.md).
