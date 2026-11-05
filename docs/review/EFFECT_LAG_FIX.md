# Effect allocation and lag investigation — 2026-11-04

The owner reported severe lag spikes after the six home preview stations were added. This pass preserves the attack timing, gameplay particles, emitter-local Glass lens, authored world and permanent fleet rules. No video was recorded and nothing was published.

The original native client recreated charge assemblies and specialist display geometry on each cycle. Temporary timing instrumentation recorded 12,576 workspace descendant additions and 10,488 removals over 1,140 frames (approximately 76 seconds). The showcase callback reached 10.67 ms; startup also produced a 291 ms frame. Descendant events measure scene-tree churn, not necessarily allocations; subsequent measurements tracked object identity to distinguish reuse from creation.

Changes integrated with the active beam-animation chat:

- BeamVFX caches at most six detached charge assemblies, separately limiting active rich charges to four. Hidden charges release active leases, stop and clear particles, and reset emission clocks. Six cached assemblies accommodate overlapping regular charges plus Stars, Coil and Ignition; a four-entry cache repeatedly evicted the next needed style. Startup glints and straight beam bodies use one segment; curved ribbons retain twelve.
- Only the fixed preview stations opt into DroneFX geometry reuse. Hidden cached parts and beams remain charged against the existing geometry budget. Source removal and showcase suspension destroy retained geometry. Production resource/depletion ownership remains unchanged.
- Preview base beam detail and specialist scan detail remain allocated while nearby. Leaving the preview releases these rigs and clears unused charge cache entries.
- Removed the preview's second world-orbital update, which could duplicate production orbital visuals. Mining emitters still use the production work renderer.
- Reuse unchanged impact ColorSequences and skip deferred role-impact work for the local presentation container's cosmetic descendants.

Native validation used canonical Studio instance `06274abd-da75-4726-88fd-4d1d2ff89091`, document `build/DRONE_GAME.rbxl`. After removing all temporary timing instrumentation, a final 20-second native sample discarded the first seven seconds for cache warmup. The remaining 13 seconds contained 774 frames: median 16.68 ms, p99 26.53 ms, maximum 46.45 ms. There were no newly created RefractionChoreography, Glass lens or StartupFX assemblies in that window. Remaining new objects were three base detail sets and 16 flight sounds with their attachments. The console was empty. This short native sample is not a guarantee against every future spike or a multiplayer/mobile performance test.

Earlier samples frequently ran at exactly 15 FPS, with occasional tool/window-interaction stalls. Those samples cannot substantiate foreground frame-rate improvement. The early ~20% showcase CPU reduction was not stable enough across these different conditions to claim as a final controlled benchmark. LibMP capture access failed with a Network-capability restriction; no GPU attribution was obtained and no capability settings were changed.

Native distance-culling check: moving away left 139 static preview descendants and zero preview beam rigs. Returning restored the effects and all six infinite-health rocks. Clean Studio client Source exactly matched the generated production bundle; no profiling code or EffectPerf attribute remained after restart. The canonical native file was refreshed only through the seven allowlisted Sources, preserving every non-Source chunk and unrelated/backup Source.

Validation passed: 19 beam behavior checks including 100 mixed six-station cycles without new charge-rig identity after warmup; startup and repair checks; 29 specialist lifecycle checks plus repeated preview reuse/visibility/budget/stream-out/suspension checks; production special/logistics integration and bundle compilation; eight energy-effects checks; 16 single-game preservation checks. These automated checks use API doubles where noted and do not substitute for the native timing sample above.

The combined source includes beam commits through `0bbca5c` and the performance changes committed with this document. Final payload: `build/lagfix-final-payload.json`. Canonical native SHA256: `3e182e22b93bf0610ffba868a27eadb303cc53b017b3edbf60d27bf11bd1bd33`. Client Source SHA256: `c88cb70f84ae3cf74f4503ec76760ab927c69ddda7ce5f87298b9324175d4c90`. Play is left running beside the preview for owner inspection.
