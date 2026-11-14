# UI overhaul review — October 25, 2026

This replaces the historical interface direction in `docs/UI_REVIEW.md`. The design follows the owner’s compact-HUD and readable-card requirements, with research from Roblox’s own documented UI examples in [UI_REFERENCES.md](UI_REFERENCES.md). No reference artwork or UI pack was imported.

## Implemented

- Cream surfaces, deep teal text/outlines, mint and amber actions, coral tradeoffs, Fredoka One headings and Gotham body text. The small native icon family is built from Roblox GUI objects.
- Resources, cargo, save status and fleet/card access share one compact HUD. A nearby station or field supplies the relevant contextual action. Recall/Evade and a nearby sentry status stay subordinate to the world.
- A single focused modal handles fleet, run collection, packs, the three saved choices, and prestige. Close/Escape preserve paid choices; the HUD’s card button reopens them.
- Cards expose the actual resolved target, precise description, penalty, up to four changed-stat rows, stacking rule, and prestige expiry. Category labels classify positive benefits, so an upgrade with a hull penalty is not mislabeled as survival. Cards from older paid offers keep their original payload.
- Desktop cards adapt from 430 to 520 pixels so all three selection actions fit the review viewport. Narrow screens stack the full cards in a scroll surface. Small-screen cards omit only the redundant flavor headline.
- Fleet tiles show permanent identity/type and current effective stats. The next-crewmate tile and prestige screen show the sale/clear milestone. Prestige explicitly lists the permanent fleet retained, exactly one added drone, and cards/currency/cargo/run progression reset.
- Transactions disable repeated actions and wait for authoritative state. Client availability reflects distance, station, assault and pending-save state and refreshes while a menu stays open. The server independently enforces every condition. `MA_InAssault` is only a replicated presentation signal.
- Native safe insets, 44-pixel primary controls, compact landscape placement, and a 130-pixel touch-control reserve keep game actions away from movement/jump controls. Modal refreshes preserve scroll position.

Components live in `src/Interface.lua`, `src/UILayout.lua`, `src/CardView.lua`, and `src/Client.lua`; the normal build bundles them into the original client entrypoint. The original drone and crystal renderer remains in that same client.

## Evidence and limits

The full source suite passed with 235 checks, including 31 responsive geometry checks and 39 production-server checks using Roblox API doubles. Four binary checks and four original-asset structural checks also passed. The suite compiled all source and linted both bundles; the transcript is [UI_TEST_RESULTS.txt](UI_TEST_RESULTS.txt). These checks cover logic and geometry, not engine rendering, live persistence or multiplayer.

The final UI implementation is commit `b80370b` and is included in combined committed source `447da67`. Later map expansion work remains separate from the UI evidence below. `tests/ui.studio.lua` ran against the actual committed `Interface` and `CardView` code in a Studio Play client: **56 native cases, 3,138 assertions, zero failures**, with all temporary objects destroyed. Heights were 430/437/499/500/510/519/520 at widths 240/284, each with four catalog copy fixtures. Native `TextFits`/`TextBounds`, font faces, exact information, 44-pixel targets, and stat/stack/expiry separation all passed. This includes the 500–519-pixel footer regression found during source review.

Actual Studio observations were made in the connected review copy of this one project:

| Check | Observed result and scope |
| --- | --- |
| Native pack flow | Mined 120 Quartz, sold it through the real server command at the Converter, then clicked the new pack controls. The server charged 80 credits, left 40, and returned three saved choices (Core Drill, Clean Extraction, Battle Formation). A later coordinated combined-source session earned more normal Quartz, bought pack 2 for 110, and completed selection through the actual UI as described below. |
| Desktop three-card rendering | At native safe content 836 × 595, all three 44-pixel Choose targets fitted inside the 443-pixel scroll viewport. A controlled client-only profile fixture exercised a four-row card with a penalty; no durable/server profile was changed. No card TextLabel reported vertical text overflow. |
| Real paid-offer availability and selection | In the coordinated Studio session, the real paid pack `2481980029:run:1:pack:2` enabled all three choices at home (12.8701 studs from spawn, `MA_InAssault=false`). A server teleport to Quartz (47.6518 studs) disabled the same choices with “Return to the depot.” Native Close, server return home and native E reopened the identical offer with Choose enabled. Native mouse selection installed D12 Rapid Cycling, cards increased 1 → 2, pending offer cleared and credits stayed 50: no second debit. The UI chat subsequently inspected the real two-card/50-credit profile and captured its HUD. Reconnect was not tested. |
| Catalog text metrics | Native TextService measured all 41 standard descriptions and titles at four card widths (240/248/260/284). The longest measured description was 36 pixels high inside a 47-pixel area; none exceeded its measured area. This does not prove every menu or localization fits. |
| Phone landscape | The native iPhone 17 Pro simulator supplied 750 × 323 safe content with touch enabled and keyboard disabled. The HUD and top-right fleet commands stayed clear of the visible joystick/jump controls. Device emulation was reset afterward. |
| Phone portrait and rotation | Opened Fleet through the actual desktop button, then rotated the iPhone simulator to portrait: 401 × 720 safe content, one-column fleet/goal tiles, all 21 rendered text controls fit. The screenshot below records the scrollable menu. Native mouse injection did not activate Fleet while device simulation was on, so this establishes rendering/rotation, not real finger input. Device emulation was reset and the menu closed afterward. |

![Native desktop card rendering with a controlled offer fixture](images/ui-card-choices.png)

The screenshot is actual Studio UI rendering with production Cards/UI code and a temporary local rendering fixture. It is not evidence of a randomly earned offer or a multiplayer playtest. UI checks used a coherent committed gameplay/renderer baseline while concurrent map and large-sentry work was underway; the final combined build’s integration status must be read alongside the current map and [sentry report](SENTRY_ANIMATION.md).

![Real earned profile with the compact gameplay HUD](images/ui-gameplay-hud.png)

![Native iPhone portrait fleet rendering after rotation](images/ui-phone-fleet.png)

Still requiring acceptance: full enlarged-map desktop/touch walkthrough, real reconnect through the redesigned UI, rotation through every menu and actual finger interaction, gamepad navigation, large fleet/long-number text, real DataStore operation, and two-client/late-join/latency behavior. No publishing was performed. The release command records the exact committed source snapshot and place checksum in `build/revision.json`; it does not turn these remaining checks into passes. While map expansion is in progress, the canonical review build packages the last complete committed game rather than unfinished working-tree geometry.
