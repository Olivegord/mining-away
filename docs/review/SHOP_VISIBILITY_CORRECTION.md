# Shop visibility and standalone upgrades

November 1, 2026. The owner could not find the shops and clarified that N-Gon is creative inspiration only: **standalone upgrades, no explicit upgrade combos**.

## Cause and correction

Read-only inspection of the owner's already-running Play session confirmed that all five shop Parts existed on both server and client. Quartz was at `(-56, 2.5, 164)`, about 175 studs from spawn, on the field's far edge. The shop shortcut was an empty, transparent hitbox over the currency meter. Locked shops also disappeared from the UI tabs. These were discovery/design defects; the server did not fail to create the shops.

`ShopStands.mount` now creates/reuses five named counters at the depot, using the captured PackStation shell. Raised signs name the mineral on both sides; the layout leaves the center approach clear. Re-mounting retains the same station Instances and therefore existing authoritative distance-check references. The original machines, map and assets remain untouched.

Quartz is also moved as its original full assembly onto the depot’s central approach. Spawn sits ten studs before its near edge and faces the field; the real CharacterAdded/respawn handler uses that point. A short paved connector fills the hub-to-field gap. The depot’s stored origin stays fixed for packs, selling and prestige distance checks. Quartz’s shop is beside the new spawn. Later fields retain their positions and are farther away. Native edit-time queries also showed that the hub top is Y=1 while the old machines extend down to Y=0; new counters use the actual pad top and fit within its footprint.

The HUD has a visible 44-pixel **Shops** button and keyboard shortcut M. All five shop tabs can be inspected; locked tabs identify the previous shop that sells access and disable purchases. A locked kiosk opens that same preview. Each shop still spends its own mineral, and the server still requires unlock, matching kiosk proximity, exact level, run ID and a durable receipt. Narrow-screen HUD meters reserve room for the third button. The preview-save label moves below the meters instead of overlapping menu buttons.

## Standalone upgrades

Orbital Fracture Relay and Scrap Reclamation are removed from the offer catalog. Their extra relay/recycle bonuses no longer operate. The replacement pack choices grant a complete Orbital Laser or ten-second Scrap-bot Swarm directly. Intrinsic precise-timing effects remain part of those abilities; they require no other upgrade.

Emerald upgrades also work independently: Rapid Orbital Laser includes its own ability and 30-second cooldown, Wide Beam Relay includes both split damage and reach, and Instant Pack Press gives 4× original reveal speed without buying the Ruby version first. Normal numeric caps still apply; redundant basic ability purchases are disabled.

Schema 6 converts selected retired combo cards into standalone ability cards without losing permanent ownership. A pending offer containing a retired combo receives its exact entire saved Quartz price back atomically instead of silently changing its disclosed choices. Repeated migration cannot refund it again. Other paid offers remain intact.

## Validation and Studio state

The counter/button repair was applied and visually inspected in the owner's existing Play session. The owner explicitly authorized stopping that session so the full source correction could be saved. The saved candidate is verified in Edit mode; no new Play session was started and nothing was published. It still needs an owner-run final native UI/interaction and multiplayer test.

101 production-domain/API-double checks pass: 24 shop/profile/card, 5 mining, 28 persistence, 8 actual server shop, 19 gadget, 10 steering and 7 actual server gadget checks. Counter/start tests now cover central Quartz, nearest-field ordering, initial spawn and subsequent real character respawns, depot distance, actual hub-top grounding, both sign faces, central path clearance, no duplicate stands and preservation of original machines and live handler references. Standalone tests cover ability grants without prerequisites, fixed swarm lifetime, ignored retired combo flags and exact one-time offer refunds. All sources and both bundles compile. Binary checks retain the exact live Source allowlist and every unrelated chunk/backup script.

Reproduce with `python3 tools/test_shops.py /private/tmp/mining-away-luau` and `python3 tools/test_gadgets.py /private/tmp/mining-away-luau`. Evidence: [test output](SHOP_CORRECTION_TEST_RESULTS.txt), [shop correction hashes](SHOP_CORRECTION_STUDIO.json), [latest Quartz/spawn integration hashes](QUARTZ_START_STUDIO.json). Actual pre-edit Sources are backed up in `build/studio-before-shops-correction-20261101.json` and `build/studio-before-quartz-start-20261101.json`. `python3 tools/release.py` stamps the clean source commit and final native place checksum in `build/revision.json`.
