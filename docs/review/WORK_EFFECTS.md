# Work effects and anticipation

October 31, 2026. Same Drone Blower revolution place **136098934779395**, branch `codex/restore-feel-prestige`. No new UI panels or explanatory labels.

## Mining

The captured flat-map place had archived `MiningFX` in `ServerStorage.FlatTestBackup_1793407435`. Runtime initialization now clones that visual template back to ReplicatedStorage, removes only scripts from the disposable clone, and preserves the backup unchanged. The original `Largeparticles`, `Mainglow`, `MiningEffect` and `InnerMiningEffect` are reused. Impact/transport sparks use a shipped Roblox transparent texture; the origin retains the authored sprite.

Three nearly closed curved-beam circles and orbiting dots sit immediately below the rendered emitter. The circles contract through the first 78% of the real warmup and hold their charged radius until firing. Breakers repeat this buildup using the actual mining pulse interval/timestamps. Continuous cutters retain their continuous cadence. The outer halo is substantially wider and more opaque; the inner core narrows. The original two-second width envelope and 0.2-second fade remain.

Origin particles, verified-surface cutting sparks, layered original contact glows and mineral-colored fracture/break bursts communicate distinct steps. Contacts follow shrinking/rotating crystal surfaces. The existing fair bounded contact-ray scheduler remains in charge; new rings and particles do not spend additional surface rays. No beam or rock-impact effect precedes an authorized, verified hit. Warmup rings appear only at the emitter.

## Couriers and healers

A courier settles beside the backpack and holds for **0.55 seconds**, maintaining range and server line of sight. A thin amber pickup tether and closing circles indicate collection. Only a committed eight-unit manifest produces the parcel. A **0.25-second launch hold** transfers that larger studded parcel from the backpack to the drone, with a small lift/release and departure burst. Loaded flight has two brief amber trails.

At the actual converter, a **0.65-second unloading hold** visibly lowers the parcel toward the machine. The parcel remains visible until the durable sale is confirmed. Only a new confirmed sale serial produces the gold burst; failure/uncertainty cannot produce a success cue. These holds add 1.45 seconds to a complete courier cycle, excluding existing travel/cooldown and storage latency. The eight-unit batch, prices and backpack ownership remain unchanged.

Medics charge for **0.4 seconds**, displaying a small green capacitor effect and thin targeting beam, before the real ten-health repair and brighter beam pulse. Range/line of sight are rechecked throughout. Subsequent repairs keep the existing two-second cadence measured from charge start.

Server timestamps/life/state replicate these phases to every observer. Save pauses preserve charge/hold clocks. Death cancels transient phases while retaining any durable unsold courier manifest; a reprint must arrive and unload again. Late joins reconstruct current phases without replaying old sale bursts.

## Limits and review

Detailed effects are bounded: 16 mining emitters, 12 detailed courier sets, 12 healer capacitors and 14 short-lived burst anchors per client, with distance culling and short particle lifetimes. Additional couriers retain the parcel/tether while decorative rings/trails degrade. Primary mining and repair beams keep their existing visibility budgets. Objects, attachments and emitters clean up on inactivity, target/life changes, source removal or renderer destruction. Vertical aiming uses a nonparallel up vector.

Source review first covered authority, cancellation, save/reconnect and original timing, then readability, particle/instance limits, surface attachment and multiplayer reconstruction. Static compilation of modules and full generated controllers is the available verification. No automated gameplay tests, Studio Play session, motion recording or multiplayer test was run under the owner's standing instruction. Exact engine appearance, particle asset access, mobile/low graphics readability, performance and fun remain **NOT VERIFIED** until owner playtesting.

Build with `python3 tools/release.py` from the clean committed source; `build/revision.json` records exact commit/checksum. The seven live Source paths are unchanged. The same payload is integrated into the existing Studio Edit place with ScriptEditorService; no geometry or preserved asset is overwritten and nothing is published. Effects appear on the next Play, not in the Edit viewport.
