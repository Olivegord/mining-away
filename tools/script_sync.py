#!/usr/bin/env python3
"""Export the seven bundled Sources into Roblox Studio's native Script Sync roots."""
import argparse
import hashlib
import json
import pathlib
import time

from build import ROOT, live_source_payload

FILES = {
    'ServerScriptService.GlobalDroneControl': 'ServerScriptService/GlobalDroneControl.legacy.luau',
    'ServerScriptService.DroneRoleEffects': 'ServerScriptService/DroneRoleEffects.luau',
    'ServerScriptService.MiningDiscoveries': 'ServerScriptService/MiningDiscoveries.luau',
    'StarterPlayer.StarterPlayerScripts.ClientDroneControl': 'StarterPlayerScripts/ClientDroneControl.local.luau',
    'ReplicatedStorage.Shared.DroneConfig': 'Shared/DroneConfig.luau',
    'ReplicatedStorage.Shared.TacticalHUD': 'Shared/TacticalHUD.luau',
    'ReplicatedStorage.Shared.CrystalAudio': 'Shared/CrystalAudio.luau',
}
STATE = ROOT / 'build/script-sync-state.json'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def export():
    previous = json.loads(STATE.read_text()) if STATE.exists() else {}
    payload = live_source_payload()['sources']
    planned = []
    hashes = {}
    # Validate every managed file before changing any of them. Studio-origin edits
    # must be reconciled into src rather than overwritten by a bundled export.
    for instance, relative in FILES.items():
        path = ROOT / 'studio' / relative
        content = payload[instance]['source'].encode()
        expected = digest(content)
        current = digest(path.read_bytes()) if path.exists() else None
        if current is not None and current != expected and current != previous.get(relative):
            raise RuntimeError(f'Unreconciled Studio/disk edit: {path}. Merge it into src before exporting.')
        if current != expected:
            planned.append((path, content))
        hashes[relative] = expected
    for path, content in planned:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix('.tmp')
        temporary.write_bytes(content)
        temporary.replace(path)
        print(f'Synced {path.relative_to(ROOT)}', flush=True)
    STATE.parent.mkdir(parents=True, exist_ok=True)
    if previous != hashes:
        STATE.write_text(json.dumps(hashes, indent=2) + '\n')
    return len(planned)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--watch', action='store_true', help='Export source changes every half second; stop on a conflicting edit')
    args = parser.parse_args()
    try:
        export()
        print('Seven bundled Sources match disk. Native Studio Script Sync handles the open game.', flush=True)
        stamp = lambda: [(p, p.stat().st_mtime_ns) for p in sorted((ROOT / 'src').glob('*.lua'))]
        last = stamp()
        while args.watch:
            time.sleep(.5)
            current = stamp()
            if current != last:
                export()
                last = current
    except (RuntimeError, KeyboardInterrupt) as error:
        if isinstance(error, RuntimeError):
            parser.exit(1, f'{error}\n')
