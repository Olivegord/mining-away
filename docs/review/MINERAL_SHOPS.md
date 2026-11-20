# Mineral shops — November 1, 2026

See [the owner’s correction and current shop visibility fix](SHOP_VISIBILITY_CORRECTION.md). The separate shop stands now sit near the depot, and upgrades work independently. Explicit combo cards were removed.

Implemented in the existing Drone Blower revolution, place 136098934779395, on `codex/restore-feel-prestige`. This is a source-only update of the verified live capture. Original map/drone/crystal/pyramid assets, saved fleet identity, tactical HUD, audio and discoveries remain. No new experience, publishing or Studio Play session.

## Concrete tutorial references

The shop follows Roblox Creator Hub's [Grid and table layouts](https://create.roblox.com/docs/ui/grid-table-layouts): equal-sized cells, native UIGridLayout, explicit LayoutOrder and a scrollable inventory. The [Create interactive UI tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/interactive-ui) supplies the on-demand menu, Frame containment, constrained sizing and multi-platform Activated-button pattern. These structures are adapted to upgrades; the tutorial's settings sliders are not imported as pretend shop controls. Shop text uses native SourceSans at 16–18 px, 44 px Buy/Info targets, two columns when space permits and one column on narrow screens. Long terms open a separate scrollable Info view. This is a source implementation, not native rendering acceptance.

N-Gon's [original tech catalog](https://github.com/landgreen/n-gon/blob/master/js/tech.js) and [source project](https://github.com/landgreen/n-gon) inform conditional unlocks and interactions between upgrades. We wrote the Roblox implementation independently; no N-Gon code, art or branding was imported. Standalone orbital/scrap ability cards can grant the ability themselves; there are no combo-card prerequisites. Paid offers retain their complete saved effect payload across catalog changes.

## Actual progression and economy

| Shop | Buys next access with | Useful choices |
| --- | --- | --- |
| Quartz | 80 Quartz → Ruby | Plot scanner, larger carried backpack |
| Ruby | 144 Ruby → Cobalt | 2× pack reveal, faster drone/courier travel |
| Cobalt | 180 Cobalt → Violet | Timed orbital strike, future pack discount, secondary mining beam |
| Violet | 240 Violet → Emerald | Ten-second scrap swarm, faster courier trips |
| Emerald | Final existing mineral | Orbital cooldown capacitor, extended beam relay, 4× total pack reveal |

Selling deposits each ore unit into its matching wallet: Ruby never becomes Quartz. Field sale values still measure cumulative prestige progress, so harder resources retain value; that score cannot buy shop products. Packs currently cost Quartz. This is an explicit simple design choice, not a mineral-exchange system. Shop tabs and the HUD balance let players inspect inventory remotely; server proximity to the actual matching kiosk is mandatory to buy. Later resources are locally hidden until access is bought. The preserved world remains visible, and access does not defeat its guards.

Upgrades use server-authored costs, expected levels, run IDs and receipt IDs. A repeated request cannot charge another level; a stale level/run or wrong shop is rejected. Mixed deposits validate every balance before clearing cargo. Full final crystal drops remain intact, and couriers deposit their actual eight-unit manifest only after delivery. Capacity stays capped at 120. Already-owned card automation and a full capacity cap prevent redundant scanner/backpack purchases. Permanent Orbiter/Scrapper ownership includes its gadget, so its duplicate shop unlock is disabled.

Pack reveal purchases change actual card entrance/stagger duration (1× → 2× → 4×), without pretending to accelerate persistence/network time or changing saved outcomes. Reduced motion bypasses entrance motion. The discount affects future prices only. New Player-scope pack cards unlock the orbital laser or ten-second scrap swarm directly, with explicit ability targets on their card faces. The retired combo cards are no longer offered.

Prestige explicitly resets cards, shop upgrades/access, mineral balances, backpack and ability cooldowns. Permanent drones, built-in traits and permanent guard clearances remain. New fleets include Orbiter and Scrapper as the fourth/fifth earned drones and a Courier as the sixth; existing saved drones are never reassigned or rerolled. Schema 5 migration converts old unspent universal credits to Quartz, preserves unsold ore/paid offers and grants access through already reached legacy fields. Corrupt state fails closed rather than creating default progress.

## Review and evidence

Behavior/parity review: the isolated original `.03` capped travel equation, overhead station and existing crystal health stages remain. Server shop access is checked for direct ore requests, individual assignments and field assault commands. Gadget contacts use the existing damage/reward path while explicitly bypassing only the ordinary worker-arrival condition; no recursive gadget fork/echo is permitted. Foreign reservations, living worker, guard state, range, LOS and backpack capacity remain authoritative. Cooldowns are saved and rehydrated on reconnect. Save-busy periods pause gadget work instead of canceling a deployment.

Pacing/presentation/multiplayer review: early Quartz offers a genuine spend decision between packs, automation and the next mineral. Faster reveal is a real time-saving upgrade. Scrap bots cooperate on weaker rocks with bounded chips rather than spreading tiny damage without finishing anything. All observers get complete replicated scrap-bot state and interpolate it locally. New mining abilities do not consume permanent drones. These are reviewed mechanics and model checks, not proof of fun, real collision or legibility.

Reproduce automated checks:

```sh
python3 tools/test_shops.py /private/tmp/mining-away-luau
python3 tools/test_gadgets.py /private/tmp/mining-away-luau
python3 tools/release.py
```

The focused checks execute production shop/profile/card logic, the actual generated server using Roblox API doubles, and bounded steering/gadget logic. They compile all current sources and both controllers; native binary checks build twice, verify exact Source paths, and preserve every unrelated chunk and backup script. There are 96 passing domain/API-double checks: 23 shop/profile/card, 5 mining, 28 persistence, 4 actual server shop, 19 gadget, 10 steering and 7 actual server gadget checks, plus syntax and binary-preservation checks. Logs are preserved in `docs/review/MINERAL_SHOPS_TEST_RESULTS.txt`. The existing persistence migration regression now funds and asserts the Quartz wallet rather than its former universal credits. `build/revision.json` identifies the exact committed source and place checksum.

Edit-time integration changed four of the seven allowlisted Sources after matching all prior script bytes to commit `47fefdf`. `docs/review/MINERAL_SHOPS_STUDIO.json` records exact integrated source SHA-256 values. The actual pre-edit Sources remain in `build/studio-before-shops-20261101.json`. HTTP was enabled only for the local transfer and restored to its previous disabled value; no native geometry/assets or backup scripts were modified.

The older `tools/test.py` suite is not a current acceptance gate: its source typography guard and radius-10 formation assertions refer to superseded UI and pre-backpack movement. In this pass, its isolated travel/yaw checks passed before its old radius-10 assertion failed against the already-existing centered hex formation. The old rules suite also calls removed encounter APIs. We did not silently rewrite those historical expectations or call the full legacy suite green. CI now uses the focused current runners and the complete 28-check storage/persistence suite, and verifies the active capture rather than the historical Mining Away geometry fixture.

**NOT VERIFIED:** final native UI/text bounds, touch/gamepad interaction, kiosk terrain/collision placement, low/high graphics, real DataStore recovery, multiple clients/late join, busy swarm performance, sound/motion quality and player enjoyment. The owner will test; no new Play session was started. The draft PR must remain draft pending the existing real-engine visual gate.
