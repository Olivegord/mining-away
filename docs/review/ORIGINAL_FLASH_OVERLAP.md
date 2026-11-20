# Original flash with overlapping ignition

Supersedes only the color-pop treatment in REFERENCE_COLOR_POP.md. Original single flash recovered from the saved pre-revision planar payload: .64/.79/1 envelope, .025 + 4.475 radius multiplier, glass opacity envelope and maximum 2.2 highlight transparency. Its original 0.288-second duration stays independent of the longer 3.2-second charge. Yellow, cyan and magenta now switch without interpolation.

The owner subsequently requested ignition before the pop finishes. The unchanged flash curve moves 80 ms later relative to release; beam, planar ring, electric dust and ignition audio begin while its last color cuts finish. Charge audio and inward paths end at release, and the remaining lens lease is released after 80 ms (proportionally shorter for charges below 0.8 seconds). Gameplay clocks and damage are unchanged.

Three small dark/violet tapered curls use staggered arrivals on the cached attraction trajectories. Their widths and shapes deform continuously; they have no rigid orbit angle, spinning parts or visible loop reset. Existing four-active/six-cached rich-rig limits and cancellation handling apply. Every other previous effect change is preserved.

Validation: `python3 tools/test_beam_vfx.py` passes all 22 production behavior checks, startup checks, repair checks and client/server compilation. Checks include hard palette values, original curve timing, overlapping ignition, immediate inflow shutdown, one launch sound, repeated reuse and continuous path positions. These tests use API doubles and are not visual approval.

Installed by comparing the entire previous native client source before exact edits; saved only the canonical `build/DRONE_GAME.rbxl`. All seven allowlisted saved Sources match the current payload `build/overlap-hard-pop-payload.json`. Saved native SHA256: `ad223c709664e3676ef0e1f850fe324c0cb76bf0313f81337c28d6f0c6abd49c`.

Native Studio sampling over 8.2 seconds observed 491 rendered frames, 5 frames with the beam and chromatic mask simultaneously enabled, all three exact unblended colors, and 789 enabled tendril samples. Studio console was empty. A native screenshot confirms the thin beam in the preserved preview scene; a still does not prove motion quality. Play is running for owner review. No final visual acceptance or multiplayer test is claimed.
