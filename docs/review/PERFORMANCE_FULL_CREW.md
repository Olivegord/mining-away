# Full-crew performance pass

Baseline: `09e89298735fdaf7f0a4eae908398b1954b23eb6`, the 15-drone preview (nine miners and six support), automatic targeting and 120-unit backpack. All of those options remain. The map, original assets, permanent ownership, damage/reward authority and mining work durations remain intact. **Optimization verification remained offline; this pass issued no Play-start call.**

## Removed work

- Server drone motion still integrates at its original fixed rate. Physical proxy models now move with snapshots instead of every simulation step; clients continue their existing smooth local rendering. Breaker phase transitions still publish their exact pose immediately. Ordinary unchanged snapshot attributes are not rewritten; immediate pause/phase writes invalidate the cache so resuming cannot leave mining hidden.
- Orbital cooldown no longer surveys the field. Ready surveys are bounded by snapshot cadence. Active burns resolve their fixed target directly instead of sorting and raycasting all rocks on every damage tick. Each actual hit retains its fresh authoritative obstruction check. Idle ability state no longer creates per-step work contexts.
- Specialist startup/hold phases monitor obstructions at snapshot cadence instead of raycasting every simulation tick. Actual startup and completion force a fresh check, and the final damage resolver still validates its hit. An obstruction cannot turn a cached clear path into an accepted final hit.
- Currency physics, expiry and collection remain fixed-rate authoritative logic. Its physical proxy position/fade updates at the existing snapshot cadence, matching the separately rendered client trajectory.
- Multi-part specialist geometry updates at up to 30 Hz from elapsed authoritative time. Ordinary drone flight keeps its original render cadence. Effects subscribe only to resources and relevant effect attributes; scenery and currency no longer dirty the effect constructor. Waiting construction retries are bounded. Distant effects free geometry and restore their rock; nearby-owner work remains visible when zoomed out. Pause clock shifts reuse the existing geometry.
- Specialist jobs retain their own bubble/split/cube/shatter aftermath instead of receiving another generic shower for every hidden fracture stage. Ordinary rock fracture and break feedback remain, including authored mesh fragments; confirmed break shake and crystal audio remain.
- Stationary logistics models stop rewriting poses. Client logistics no longer walk descendant trees and search exhaust objects every frame. Actual streamed geometry changes invalidate the cached clone once; removal disconnects the associated listeners. In-flight launch progress no longer forces a complete profile publication every fixed tick.
- Published profiles reuse authoritative runtime stats and omit private receipts/seeds before copying. The build tool decodes with the installed Zstandard library in-process when available, retaining its CLI fallback; this removes one subprocess per compressed place chunk.

## Reproducible work-count comparison

Run `python3 tools/test_performance.py /tmp/mining-away-luau`. It executes the real baseline and optimized bundled server/FX/logistics methods under the same deterministic API doubles, with the full 15-drone preview. These are **API call counts**, not measured Studio frame rates or Energy Impact.

| Workload | Baseline | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Drone model moves, two seconds idle | 1,800 | 255 | 85.8% |
| Drone snapshot attribute writes, same workload | 22,695 | 3,960 | 82.6% |
| Field-survey rays, two seconds cooldown | 1,440 | 0 | 100% |
| Rays during two seconds of actual orbital burn logic | 1,560 | 120 | 92.3% |
| Rays for seven specialists during two seconds of startup/work | 840 | 126 | 85.0% |
| Specialist property writes, seven active types, one second at 144 callbacks/s | 90,492 | 17,594 | 80.6% |
| Idle client logistics descendant scans / pose writes, ten seconds | 650 / 600 | 0 / 0 | 100% |

The comparison also asserts real burn damage, pause/resume snapshot coherence, resource-only subscriptions with 1,000 unrelated scenery parts, bounded effect update cadence, distance leave/return, streamed logistics clone refresh and connection cleanup. The models and fleet were not removed to obtain these counts.

The former special-FX fixture embedded an old copy of the effect implementation. It now exercises the actual production `src/DroneFX.lua` supplied by its runner. Retained ordinary/breaker flight fixtures explicitly isolate their intended workers from the seven added specialists; all-type assignment remains covered separately.

## Validation and delivery

Current special/logistics/FX/HUD checks and focused client, energy, audio, gadget/role, mining flight and shop suites pass offline. Active-capture preservation checks verify deterministic output and the exact seven Source allowlist, with all other chunks and backup Sources byte-identical. The installed Zstandard decoder round-trips a real compressed fixture and rejects a corrupt chunk; binary preservation also exercises real place chunks.

The existing editable export is refreshed offline against the exact previously installed source payload, preserving its map and backups. `python3 tools/release.py` builds the primary verified live capture, the review ZIP and `build/revision.json` with the exact final commit and checksums. No source asset is overwritten and no Roblox publication occurs.

Studio initially reported no connected instance, then reconnected for the parallel particle chat's isolated Edit previews. That workflow unexpectedly encountered Play mode; only stop calls were issued, cleanup was repeated in Edit and no performance playtest was conducted. No new profiler capture, FPS/energy comparison, gameplay visual acceptance or multiplayer acceptance is claimed.

The final native Edit install updated only the three changed approved script paths. The client edit's automatic permission review timed out once and its permitted retry succeeded. Save was issued in the existing editable file; although the UI response timed out, the resulting native file was independently decoded and verified: all seven final Sources exactly match implementation `70c5986`, all 39 unrelated Sources and all 29 serialized script enablement values match the preserved export, and no preview modules remain. Preview objects had also been confirmed absent in Edit before Save. The final saved native file SHA-256 is `8ad24875374a85ef6656701b83c7858cb07f4c5b5c5444e1ea72ba703ba8d47f`. Studio subsequently disconnected. The saved optimized file and source-only release are ready for the owner's later test; no restart or publication was issued.
