# Simple core loop — November 6, 2026

The owner identifies the missing foundation as **buy, sell, upgrade, prestige**. This pass connects that loop in the existing game. It preserves the map, original drones, card choices, discoveries, cube rocks, snap-size damage, outward currency arcs and one drone type per rock.

## What changes for a new player

1. Start with one permanent Miner, a 40-ore backpack and no free money, targeting automation or transport. Studio now starts with this same economy. Temporary crews are explicit Fleet developer controls; returning to the permanent fleet removes their runtime perks. Prestige also ends the temporary crew.
2. Mine and collect normally. At the existing **SELL ORE** converter, E, U or the Sell button exchanges any backpack amount directly for its matching mineral balances. No 120-ore storage requirement or launch delay. Optional carriers, couriers, flying backpacks and storage still work through their existing separate controls.
3. The Quartz shop offers **Mining power** for 20, 40, 80 and 160 Quartz. Each level adds 50% of base mining damage. The starter goes from 30 to 45 damage per second after the first purchase. Bag upgrades start at 30 Quartz; targeting automation costs 40. Run mining modifiers still share their existing 4× cap.
4. **Buy drones** now includes the ordinary permanent Miner, initially 60 Quartz. Additional Miner prices grow by 1.8× with owned Miners. This creates a useful early permanent purchase alongside the existing specialist drones and three-choice card packs. Bought Miners retain unique IDs and base traits through prestige and reconnect.
5. A compact **Prestige** shortcut shows cumulative sales progress and opens the existing explicit reset confirmation. The first milestone remains 160 sales value and the second 400; spending earned minerals does not erase progress. Each prestige keeps all bought drones, adds its existing earned drone, and grants another **+25% permanent base mining power**, applied after run modifiers. Upgrades, cards, balances, cargo and run sales reset. The menu explains the reset and permanent reward.

No premium purchases, paid random packs, new experience, map replacement or publishing are involved. Prices and permanent bonuses are tuning decisions, not evidence that the game is fun.

## Correctness and parity review

The server validates selling distance, combat state, balances, purchase level, run identity and permanent ownership. Sales and purchases use the existing durable transaction boundary. Retried purchase receipts cannot buy another drone or charge the increasing price twice. Empty Sell does not create receipts or money. A response lost after a committed sale pays once. Mixed minerals enter matching wallets; the old `credits` compatibility alias stays equal to Quartz, as in the current launch and purchase paths. Prestige reads cumulative sales value, not the remaining wallet.

The permanent bonus is derived from the saved prestige counter; it never rewrites a drone's base traits or saved identity. Existing profiles need no migration. Preview perks are runtime-only and no longer apply to every Studio player. Adding a developer drone refreshes the whole temporary crew consistently.

Movement, arrival gates, original overhead mining stations, beam timing, physics, audio and role behaviors are unchanged. Same-type sharing, field access, obstruction checks, owner-only pickups and persistent carrier/storage inventories remain in place.

## Automated evidence

`PYTHONDONTWRITEBYTECODE=1 python3 tools/test_core_loop.py` executes the production server bundle under the shared Roblox API doubles in both production and Studio configuration. Seven checks run in each configuration:

- Real worker ticks break ordinary Quartz work and real pickup ticks fill the 40-ore bag; no balance or cargo injection in the starter-to-prestige sequence.
- Remote selling is rejected; selling at the converter pays immediately and exactly once, including a simulated lost commit response.
- An earned 20-Quartz upgrade changes runtime mining damage, and repeated quoted purchases cannot charge twice.
- Earned money buys a permanent second Miner; its next price is 108, repeat receipts are safe and insufficient funds fail.
- Four earned base-bag sales reach the first 160 milestone even after spending. Prestige preserves both original and bought IDs, resets run upgrades, adds a permanent drone and raises the starter's unmodified mining damage to 37.5.
- Reconnect restores the permanent fleet and bonus; mining and selling fund the first upgrade again, producing 56.25 damage per second.
- Mixed-mineral sales conserve typed wallets and leave optional stored cargo intact; stale receipt reuse and overflow fail safely.

Other current regression runners: `tools/test_special_logistics.py /private/tmp/mining-away-luau`, `tools/test_core_gameplay.py`, `tools/test_physical_mining.py` and `tools/test_rock_cascade.py`. The physical-mining test runner now scopes each appended fixture inside a function to avoid exhausting Luau's top-level local-register limit; it executes the same assertions. Source/bundle compilation is included. These are logic and API-double checks, not live DataStore, native multiplayer, visual, audio or enjoyment tests.

## Native validation and playtest criteria

The canonical `build/DRONE_GAME.rbxl` was opened and its seven installed Sources compared with the source payload before Play. Native one-player Play completed the full loop through normal command remotes, real worker damage, actual ore pickups, Humanoid movement and the Studio character-navigation tool. No currency, cargo, damage or ownership grants were used. The [native transaction observations](core-loop-native.json) record:

- One permanent Miner, 40 capacity, no automatic targeting or free transport. The first bag filled in 48.8 seconds across four rocks in this observed sample; this is not a general benchmark.
- First Sell: 40 ore became 40 Quartz immediately; stored/launch cargo was not required.
- Mining power: 20 Quartz spent, 20 left, runtime mining damage rose from 30 to 45.
- Second Sell: 80 cumulative sales and 60 Quartz available. Buying the 60-Quartz Miner produced two permanent drones and zero balance.
- Third/fourth bags: 120 then 160 cumulative sales, with 80 Quartz remaining after prior purchases. Prestige became eligible.
- Prestige: three permanent drones, both prior IDs retained, zero run balance/sales/power-upgrade level, and starter mining damage 37.5. Two earned Orbital and two Scrap charges survived the reset.

The first scripted Sell attempt reached the client distance threshold before movement had replicated; the server rejected it. Retrying after arrival sold once. Straight-line test movement also encountered the authored converter geometry; the navigation tool completed the path around it. Neither issue was bypassed by changing the server guards or granting progress.

Native screenshots and GUI bounds exposed two presentation overlaps: the preview-save label with Prestige, and earned tool pockets with Buy drones. The label was moved and verified in native Play; the yard/carrier buttons now sit below the visible tool panel, including its expanded placement state. That final layout adjustment was compiled, installed into the canonical document, and its full Source checksum verified; the expanded layout was not separately playtested. Console output was empty. Play was stopped, the canonical document was saved, and Studio was confirmed closed. This is a native single-player command-driven check, not a mouse-only usability test, live DataStore check, multiplayer pass or enjoyment verdict.

The target Roblox experience was independently checked through MarketplaceService: **Drone Blower revolution**, place **136098934779395**, creator OliveGord. The local document has PlaceId 0 and its Collaborators window says to save to Roblox before collaborating. This pass has not published or shared it on Roblox. The local master and the older saved experience are distinct storage states of this one project.

The owner's assessment remains necessary: does each return trip enable a useful purchase; is walking/collecting worth the time; is the first reset understandable and appealing; does a second run feel meaningfully stronger? Automated correctness cannot answer these questions.
