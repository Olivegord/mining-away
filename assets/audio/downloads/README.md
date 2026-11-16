# Owner-supplied rock and weapon audio

Prepared November 15, 2026 from the owner's Downloads WAVs. Originals remain
untouched. Credits are taken from their filenames; no additional license or
redistribution terms are inferred. These files are game assets, not another place.

| Source credit / download | Use | Roblox audio |
| --- | --- | --- |
| artninja — 865325 rock impact crash sounds | Eight randomized, size-selected break cuts | 96292866549392 |
| the_elementus — 873747 low mid end void energy blast punch 01 | Laser ignition | 88808719170718 |
| cat-fox_alex — 877834 space ship distoried 1_2 | Purple Ballcaster shot | 136064510893795 |
| qvantor — 879282 synthesized explosion | Ramiel and Orbital additional layer | 116172612398887 |
| woodbetweenstudio — 879905 cinematic boom impact | Ramiel and Orbital additional layer | 73460664261612 |

Both Elementus downloads have identical SHA-256 hashes. Only one is used. The
unrequested kick-breaking-something download is untouched.

`manifest.json` records input hashes, cut times, duration, original RMS loudness,
peak, output gain and output hashes. The floating-point rock master has peaks
above full scale. A common attenuation preserves its relative dynamics without
clipping when converted to 16-bit PCM. Each cut has a 3 ms edge fade.

The eight crashes are ranked equally by duration and RMS loudness. The combined
rank assigns three small, three medium and two large variants. This balances
the two measurements: some quiet crashes have longer rubble tails. The small
pool contains cuts 05, 03, 02; medium 01, 07, 06; large 08, 04.

The standalone cuts are retained here. One atlas packs them with 250 ms gaps,
so the complete request uses five uploads rather than twelve. Each native
Sound enables PlaybackRegion with exact cut start/end times; a delayed cleanup
cannot play the neighboring cut. Random selection avoids consecutive repeats
within a size pool. Original bounding-box volume determines size, expressed as
an equivalent cube edge: under 4.5 studs, 4.5–7 studs, and 7+ studs. Damage-stage
shrinkage cannot turn a large rock into a small sounding one.

Ramiel keeps its original blast. Orbital keeps its original cue. Both add the
synthesized explosion and boom with independent spatial voice limits and the
existing effects mute. Nomad keeps its old audio. Imported tails are timed using
the actual playback speed. Unavailable added layers stay silent.

All five assets were uploaded under creator 2481980029 for DRONEREVOLUTION,
universe 10774898335 / place 124078027733625. Operations completed and native
Edit preload returned Success with nonzero duration for all five. This uploads
audio assets; it does **not** publish the Roblox experience. Upload receipts
are in `uploads.json`.

Rebuild with `python3 tools/prepare_download_audio.py --source <Downloads>`
(requires NumPy). This only renders WAVs and measurements; it does not upload.
Run `python3 tools/test_gadgets.py /private/tmp/drone-luau crystal-clock` and
`/private/tmp/drone-luau/luau tests/audio-feedback.spec.lua` for event checks.
Prepend the production AudioFeedback/Soundscape bundle to
`tools/studio_download_audio_checks.lua` for muted native Edit checks.
These verify loading, all eight regions, repeat avoidance, layer routing,
voice limits and mute. They do not establish listening quality or multiplayer.
