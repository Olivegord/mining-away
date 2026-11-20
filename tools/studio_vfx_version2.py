#!/usr/bin/env python3
"""Build Workspace["VERSION 2"] (the Pressure Strike showcase) in the open DRONEREVOLUTION Edit session.

    python3 tools/studio_vfx_version2.py            rebuild the model from tools/vfx_version2/
    python3 tools/studio_vfx_version2.py --wait 900 wait up to 15 minutes for the owner to leave Play
    python3 tools/studio_vfx_version2.py --save     also save the place afterwards (never publishes)

It only replaces its own model. It never starts or stops Play.
"""
import argparse
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import studio_apply as apply

SOURCES = pathlib.Path(__file__).resolve().parent / 'vfx_version2'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--wait', type=int, default=0)
    parser.add_argument('--save', action='store_true')
    args = parser.parse_args()
    code = (SOURCES / 'build_stage.lua').read_text()
    code = code.replace('__MODULE__', apply.long_string((SOURCES / 'PressureStrikeV2.lua').read_text()))
    code = code.replace('__REPLAY__', apply.long_string((SOURCES / 'Replay.client.lua').read_text()))
    studio = apply.Studio()
    try:
        waited = 0
        while studio.select_game() != 'Edit':
            if waited >= args.wait:
                raise apply.Stop('Studio is in Play. Nothing was changed; run again in Edit or pass --wait SECONDS.')
            if waited == 0:
                print('Studio is in Play; waiting for Edit...', flush=True)
            time.sleep(10)
            waited += 10
        print(studio.luau(code))
        if args.save:
            print('Save: ' + studio.call('save_place', {}, timeout=300)[:200])
    except apply.Stop as stop:
        print('STOPPED: ' + str(stop))
        sys.exit(2)
    finally:
        studio.close()


if __name__ == '__main__':
    main()
