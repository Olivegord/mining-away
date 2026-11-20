#!/usr/bin/env python3
"""Cut the owner's WAVs; preserve measured loudness ordering and reproducibility.

Requires numpy. No upload, Studio change, or modification of Downloads.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/downloads'
SOURCES = {
    'rock': '865325__artninja__rock_impact_crash_sounds_08022026.wav',
    'laser_start': '873747__the_elementus__low_mid_end_void_energy_blast_punch_01.wav',
    'ballcaster_fire': '877834__cat-fox_alex__space-ship-distoried-1_2.wav',
    'synth_explosion': '879282__qvantor__synthesized-explosion.wav',
    'cinematic_boom': '879905__woodbetweenstudio__cinematic-boom-impact.wav',
}


def read_wav(path):
    raw = path.read_bytes()
    assert raw[:4] == b'RIFF' and raw[8:12] == b'WAVE'
    chunks, offset = {}, 12
    while offset + 8 <= len(raw):
        size = struct.unpack_from('<I', raw, offset + 4)[0]
        chunks[raw[offset:offset+4]] = raw[offset+8:offset+8+size]
        offset += 8 + size + size % 2
    fmt = chunks[b'fmt ']
    tag, channels, rate, _, _, bits = struct.unpack_from('<HHIIHH', fmt)
    if tag == 65534:
        tag = struct.unpack_from('<H', fmt, 24)[0]
    data = chunks[b'data']
    if tag == 3:
        samples = np.frombuffer(data, dtype='<f4' if bits == 32 else '<f8')
    elif tag == 1 and bits == 24:
        a = np.frombuffer(data, np.uint8).reshape(-1, 3).astype(np.int32)
        a = a[:, 0] | a[:, 1] << 8 | a[:, 2] << 16
        samples = ((a ^ 0x800000) - 0x800000) / 8388608
    elif tag == 1 and bits == 16:
        samples = np.frombuffer(data, '<i2') / 32768
    else:
        raise ValueError((tag, bits))
    samples = samples.reshape(-1, channels).astype(np.float64)
    assert np.isfinite(samples).all()
    return rate, samples


def regions(samples, rate):
    # 10ms RMS windows, 180ms quiet separation. Preserve 15ms attack lead,
    # 120ms decay; never cut a second impact out of the same crash.
    step = rate // 100
    rms = np.array([np.sqrt(np.mean(samples[i:i+step] ** 2))
                    for i in range(0, len(samples), step)])
    result, start, last = [], None, 0
    for i, active in enumerate(rms > .008):
        if active:
            start = i if start is None else start
            last = i
        elif start is not None and i-last >= 18:
            result.append((max(0, start*.01-.015), min(len(samples)/rate, (last+1)*.01+.12)))
            start = None
    if start is not None:
        result.append((max(0, start*.01-.015), len(samples)/rate))
    return result


def export(name, samples, rate, gain, source, start=0):
    original_rms = float(np.sqrt(np.mean(samples ** 2)))
    peak = float(np.max(np.abs(samples)))
    rendered = samples.copy() * gain
    fade = min(round(rate*.003), len(rendered)//2)
    rendered[:fade] *= np.linspace(0, 1, fade)[:, None]
    rendered[-fade:] *= np.linspace(1, 0, fade)[:, None]
    assert np.max(np.abs(rendered)) < 1, 'Clipping'
    path = OUT / (name + '.wav')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(rendered.shape[1]); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(np.round(rendered*32767).astype('<i2').tobytes())
    return dict(name=name, file=path.name, source=source, start=round(start, 6),
                duration=round(len(samples)/rate, 6), rms_db=round(20*np.log10(max(1e-10, original_rms)), 3),
                peak=round(peak, 6), gain=round(gain, 8),
                sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--source', type=Path, default=Path.home()/'Downloads')
    args = parser.parse_args(); OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'sources': {}, 'clips': []}
    for key, filename in SOURCES.items():
        path = args.source / filename
        rate, samples = read_wav(path)
        manifest['sources'][key] = dict(file=filename, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                                       sample_rate=rate, channels=samples.shape[1])
        # Float rock master has peaks above full scale. One common attenuation
        # prevents integer clipping WITHOUT normalizing away its size dynamics.
        gain = min(1., .94/float(np.max(np.abs(samples))))
        if key == 'rock':
            cuts = regions(samples, rate)
            assert len(cuts) == 8, f'Expected eight distinct crashes, found {len(cuts)}'
            for i, (start, end) in enumerate(cuts):
                clip = export(f'rock_break_{i+1:02}', samples[round(start*rate):round(end*rate)], rate, gain, key, start)
                manifest['clips'].append(clip)
        else:
            manifest['clips'].append(export(key, samples, rate, gain, key))
    rocks = [c for c in manifest['clips'] if c['source'] == 'rock']
    for metric in ('duration', 'rms_db'):
        for rank, clip in enumerate(sorted(rocks, key=lambda c: c[metric])):
            clip[metric+'_rank'] = rank
    ranked = sorted(rocks, key=lambda c: (c['duration_rank'] + c['rms_db_rank'], c['rms_db']))
    for rank, clip in enumerate(ranked):
        clip['size_pool'] = 'small' if rank < 3 else 'medium' if rank < 6 else 'large'
    # One uploaded atlas holds the eight already-cut WAVs. Native Sound playback
    # regions isolate each cut; this needs five audio uploads instead of twelve.
    blocks, cursor = [], 0
    for clip in ranked:
        rate, samples = read_wav(OUT/clip['file'])
        clip['atlas_start'] = round(cursor/rate, 6)
        blocks.extend((samples, np.zeros((rate//4, samples.shape[1]))))
        cursor += len(samples) + rate//4
    atlas = export('rock_break_atlas', np.concatenate(blocks), rate, 1., 'rock')
    manifest['atlas'] = atlas
    (OUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    for c in sorted(rocks, key=lambda c: (c['duration_rank']+c['rms_db_rank'])):
        print(c['name'], c['size_pool'], c['duration'], c['rms_db'])


if __name__ == '__main__':
    main()
