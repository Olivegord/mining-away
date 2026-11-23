#!/usr/bin/env python3
"""Pose the three painted attacks (StrikeArt) in Studio Edit and save real screenshots. No Play.

    python3 tools/studio_strike_preview.py OUT_DIR

Bundles the working-tree StrikeArt, builds the Crescent slash, the Stormcaller bolt and the
Starfall star (with its blue Pressure Strike impact) on open ground, poses each at several
moments side by side, and captures the Edit viewport. Everything it makes is Archivable=false
under one temporary folder that is removed afterwards; the camera is put back; nothing is saved.
Motion, the star's trail growth and particles are only approximated in stills.
"""
import argparse, base64, pathlib, sys, time
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import studio_apply as apply
from build import module_bundle

SETUP = r'''
assert(not game:GetService('RunService'):IsRunning(),'Preview only in Edit')
local old=workspace:FindFirstChild('StrikePreviewTmp');if old then old:Destroy() end
local root=Instance.new('Folder');root.Name='StrikePreviewTmp';root.Archivable=false;root.Parent=workspace
StrikeArt.prepare(true)
local base=Vector3.new(%f,%f,%f)
local cam=workspace.CurrentCamera
shared.StrikePreview={A=StrikeArt,root=root,base=base,camCF=cam.CFrame,slashes={},bolts={}}
return 'ready'
'''
SLASHES = r'''
local P=shared.StrikePreview;local A=P.A
for _,r in ipairs(P.slashes) do r.host:Destroy() end;P.slashes={}
local times={%s}
for i,t in ipairs(times) do
 local rig=A.newSlash(P.root);table.insert(P.slashes,rig)
 local hit=P.base+Vector3.new((i-(#times+1)/2)*8.5,0,0)
 A.fireSlash(rig,hit,Vector3.new(1,0,.35),math.rad(%f)*(i%%2==0 and -1 or 1),7.2,0,true)
 A.stepSlash(rig,t)
end
local c=workspace.CurrentCamera;c.CFrame=CFrame.lookAt(P.base+Vector3.new(0,%f,%f),P.base+Vector3.new(0,1.5,0))
return 'ok'
'''
BOLTS = r'''
local P=shared.StrikePreview;local A=P.A
for _,r in ipairs(P.slashes) do r.host:Destroy() end;P.slashes={}
for _,r in ipairs(P.bolts) do r.host:Destroy() end;P.bolts={}
local times={%s}
for i,t in ipairs(times) do
 local rig=A.newBolt(P.root);table.insert(P.bolts,rig)
 local hit=P.base+Vector3.new((i-(#times+1)/2)*8,0,0)
 math.randomseed(40+i)
 A.fireBolt(rig,hit+Vector3.new(1.5,10,0),hit,0,true,1)
 A.stepBolt(rig,t)
end
local c=workspace.CurrentCamera;c.CFrame=CFrame.lookAt(P.base+Vector3.new(0,6,22),P.base+Vector3.new(0,4,0))
return 'ok'
'''
STAR = r'''
local P=shared.StrikePreview;local A=P.A
for _,r in ipairs(P.bolts) do r.host:Destroy() end;P.bolts={}
P.star=P.star or A.newStar(P.root)
local from,to=P.base+Vector3.new(-3,9,0),P.base
local pos=A.stepStar(P.star,from,to,%f,.9,.72,2.5,%f)
local c=workspace.CurrentCamera;c.CFrame=CFrame.lookAt(P.base+Vector3.new(4,7,17),P.base+Vector3.new(-1,4,0))
return 'ok'
'''
IMPACT = r'''
local P=shared.StrikePreview;local A=P.A
if P.star then A.hideStar(P.star) end
if not P.impact then A.starImpact(P.root,P.base,0,1);P.impact=true end
A.stepImpacts(%f)
local c=workspace.CurrentCamera;c.CFrame=CFrame.lookAt(P.base+Vector3.new(0,5,13),P.base+Vector3.new(0,1,0))
return 'ok'
'''
CLEAN = "local P=shared.StrikePreview;if P then workspace.CurrentCamera.CFrame=P.camCF;P.root:Destroy();shared.StrikePreview=nil end return 'clean'"

def capture(studio, out, name):
    result = studio.request('tools/call', {'name': 'screen_capture', 'arguments': {'studio_id': studio.studio_id, 'capture_id': name}})
    for part in result.get('content', []):
        if part.get('type') == 'image':
            target = out / (name + '.png'); target.write_bytes(base64.b64decode(part['data'])); print(target)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('out', type=pathlib.Path)
    parser.add_argument('--at', default='-60,3.8,-70', help='open ground for the stage (x,y,z)')
    parser.add_argument('--only', default='slash,bolt,star,impact')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    x, y, z = (float(v) for v in args.at.split(','))
    only = set(args.only.split(','))
    with apply.machine_lock(600):
        studio = apply.Studio()
        try:
            for _ in range(10):
                try: mode = studio.select_game(); break
                except apply.Stop: time.sleep(3)
            if mode != 'Edit':
                raise apply.Stop('Studio is not in Edit; the preview does not run during Play.')
            studio.luau(module_bundle(('StrikeArt',)) + SETUP % (x, y, z), timeout=300)
            try:
                if 'slash' in only:
                    studio.luau(SLASHES % ('0.02,0.05,0.09,0.15,0.22,0.29', 22, 7, 22)); capture(studio, args.out, 'crescent-sequence')
                    studio.luau(SLASHES % ('0.09', 22, 4, 12)); capture(studio, args.out, 'crescent-close')
                if 'bolt' in only:
                    studio.luau(BOLTS % '0.04,0.12,0.24,0.42'); capture(studio, args.out, 'stormcaller-sequence')
                    studio.luau(BOLTS % '0.14'); capture(studio, args.out, 'stormcaller-close')
                if 'star' in only:
                    studio.luau(STAR % (0.6, 0.6)); capture(studio, args.out, 'starfall-charge')
                    age = 0.9
                    while age < 0.9 + 0.72 * 0.62:
                        studio.luau(STAR % (age, age)); time.sleep(0.03); age += 0.035
                    capture(studio, args.out, 'starfall-flight')
                if 'impact' in only:
                    for t in (0.04, 0.12, 0.26):
                        studio.luau(IMPACT % t); capture(studio, args.out, f'starfall-impact-{int(t*1000):03d}ms')
            finally:
                print(studio.luau(CLEAN))
        except apply.Stop as stop:
            print('STOPPED: ' + str(stop)); sys.exit(2)
        finally:
            studio.close()
