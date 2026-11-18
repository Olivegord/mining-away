#!/usr/bin/env python3
"""Render the drone charge in Studio Edit and save real screenshots. No Play needed.

    python3 tools/studio_vfx_preview.py OUT_DIR                  long first ignition (2.6 s)
    python3 tools/studio_vfx_preview.py OUT_DIR --duration 0.3   quick re-ignite
    python3 tools/studio_vfx_preview.py OUT_DIR --at 0.3,0.6,0.8

It bundles the working-tree BeamVFX (uncommitted edits included), draws one charge under a
stand-in cube above a square field at each requested moment, and captures the Edit viewport.
The Edit camera is moved for the shots and put back; the temporary parts are removed and
nothing is saved. Geometry is exact; particles and motion are not shown in stills.
"""
import argparse
import base64
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import studio_apply as apply
from build import module_bundle

SETUP = r'''
assert(not game:GetService('RunService'):IsRunning(),'Preview only in Edit')
local old=workspace:FindFirstChild('VFXPreviewTmp');if old then old:Destroy() end
local root=Instance.new('Folder');root.Name='VFXPreviewTmp';root.Archivable=false;root.Parent=workspace
local field
for _,d in ipairs(workspace:GetDescendants()) do if d.Name=='Field' and d:IsA('BasePart') and d:GetAttribute('CrystalZone') then field=d break end end
local base=field and (field.Position+Vector3.new(0,field.Size.Y/2,0)) or Vector3.new(0,10,0)
local from=base+Vector3.new(0,12,0)
local cube=Instance.new('Part');cube.Anchored=true;cube.Size=Vector3.one*1.9;cube.Color=Color3.fromRGB(66,196,255);cube.Position=from+Vector3.new(0,.95,0);cube.Parent=root
local rock=Instance.new('Part');rock.Anchored=true;rock.Size=Vector3.new(3,2.4,3);rock.Color=Color3.fromRGB(120,110,105);rock.Position=base+Vector3.new(0,1.2,0);rock.Parent=root
local cam=workspace.CurrentCamera
shared.VFXPreview={camCF=cam.CFrame,B=BeamVFX,root=root,from=from,to=base+Vector3.new(0,2.4,0),rig=BeamVFX.new(root,'Cutter',Color3.fromRGB(66,196,255))}
cam.CFrame=CFrame.lookAt(from+Vector3.new(9,5,13),from+Vector3.new(0,-2,0))
return 'ready'
'''
DRAW = "local P=shared.VFXPreview;P.B.draw(P.rig,P.from,P.to,%f,0,%f,nil,1,%f) return 'ok'"
CLEAN = "local P=shared.VFXPreview;if P then workspace.CurrentCamera.CFrame=P.camCF;P.B.destroy(P.rig);P.root:Destroy();shared.VFXPreview=nil end return 'clean'"

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('out', type=pathlib.Path)
    parser.add_argument('--duration', type=float, default=2.6)
    parser.add_argument('--at', default='0.12,0.25,0.38,0.5,0.6,0.68,0.74,0.8,0.86,0.92,0.98')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    studio = apply.Studio()
    try:
        if studio.select_game() != 'Edit':
            raise apply.Stop('Studio is not in Edit; the preview does not run during Play.')
        studio.luau(module_bundle(('BeamVFX',)) + SETUP)
        try:
            for q in (float(x) for x in args.at.split(',')):
                studio.luau(DRAW % (q * args.duration, q, args.duration))
                name = f'charge-{args.duration:g}s-{int(q * 1000):03d}'
                result = studio.request('tools/call', {'name': 'screen_capture', 'arguments': {
                    'studio_id': studio.studio_id, 'capture_id': name}})
                for part in result.get('content', []):
                    if part.get('type') == 'image':
                        target = args.out / (name + '.png')
                        target.write_bytes(base64.b64decode(part['data']))
                        print(target)
        finally:
            studio.luau(CLEAN)
    except apply.Stop as stop:
        print('STOPPED: ' + str(stop)); sys.exit(2)
    finally:
        studio.close()
