#!/usr/bin/env python3
"""Compare actual bundled logic/API-call counts without starting Roblox Studio."""
import argparse
import importlib.util
import io
import json
import pathlib
import subprocess
import tarfile
import tempfile
from build import ROOT, bundle

parser=argparse.ArgumentParser()
parser.add_argument('luau',type=pathlib.Path)
parser.add_argument('--baseline',default='09e89298735fdaf7f0a4eae908398b1954b23eb6')
args=parser.parse_args()
mock=(ROOT/'tests/mock-roblox.lua').read_text()
setup=(ROOT/'tests/gadget-server.setup.lua').read_text()
server_check=(ROOT/'tests/performance-server.integration.lua').read_text()
fx_setup=(ROOT/'tests/special-fx.setup.lua').read_text()
fx_check=(ROOT/'tests/performance-fx.integration.lua').read_text()
view_check=(ROOT/'tests/performance-logistics-view.integration.lua').read_text()
presentation=(ROOT/'src/Presentation.lua').read_text()
impact=presentation[presentation.index('function P:resourceImpact('):presentation.index('function P:update(')]
results={}
with tempfile.TemporaryDirectory(prefix='mining-performance-') as directory:
    tmp=pathlib.Path(directory)
    archive=subprocess.run(['git','archive',args.baseline,'src','tools'],cwd=ROOT,capture_output=True,check=True).stdout
    base=tmp/'baseline';base.mkdir()
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for member in tar.getmembers():
            assert '..' not in pathlib.PurePosixPath(member.name).parts and (member.isdir() or member.isfile())
        tar.extractall(base)
    spec=importlib.util.spec_from_file_location('performance_baseline_build',base/'tools/build.py')
    old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
    for name,server,fx,view in [('before',old.bundle(),(base/'src/DroneFX.lua').read_text(),(base/'src/LogisticsView.lua').read_text()),('after',bundle(),(ROOT/'src/DroneFX.lua').read_text(),(ROOT/'src/LogisticsView.lua').read_text())]:
        metrics={}
        methods=view[view.index(' function self:step('):view.index(' return self\nend\nreturn View')]
        view_setup="\nlocal player={};local UIS={};local C={}\nlocal ctx={world=Instance.new('Folder'),localFX=Instance.new('Folder'),hidden=function()return false end}\nctx.world.Parent=workspace;ctx.localFX.Parent=workspace\nlocal self={visuals={},connections={},scanAt=0}\nlocal trigger,targetCycle,carrierReturn,bar,layer=Instance.new('Frame'),Instance.new('Frame'),Instance.new('Frame'),Instance.new('Frame'),Instance.new('Frame')\n"
        fixtures=[
            ('server',mock+'\nmath.randomseed(42)\n'+setup+'\nfunction runService:IsStudio()return true end\n'+server+'\n'+server_check),
            ('fx',fx_setup+'\nlocal DroneFX=(function()\n'+fx+'\nend)()\n'+fx_check),
            ('logistics',fx_setup+view_setup+'\n'+methods+'\n'+view_check),
        ]
        if name=='after':fixtures.append(('fracture',mock+'\nlocal P={}\n'+impact+'\n'+(ROOT/'tests/performance-fracture.integration.lua').read_text()))
        for kind,source in fixtures:
            path=tmp/(name+'-'+kind+'.lua');path.write_text(source)
            subprocess.run([str(args.luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
            run=subprocess.run([str(args.luau/'luau'),str(path)],capture_output=True,text=True)
            if run.returncode:raise RuntimeError(run.stdout+run.stderr)
            for line in run.stdout.splitlines():
                if line.startswith('METRIC\t'):
                    _,key,*values=line.split('\t');metrics[key]=[int(v) for v in values]
                else:print(name,line)
        results[name]=metrics
    before,after=results['before'],results['after']
    assert after['idle'][0]<=before['idle'][0]*.25,'server movement proxy publication did not fall'
    assert after['idle'][1]<=before['idle'][1]*.4,'snapshot attribute writes did not fall'
    assert after['cooldown'][2]<=before['cooldown'][2]*.25,'cooldown field surveys remain excessive'
    assert after['burn'][2]<=before['burn'][2]*.25,'burn still rescans the entire field'
    assert after['fx144'][0]<=before['fx144'][0]*.35,'FX property writes did not fall'
    assert after['logistics']==[0,0],'stationary logistics still perform traversal/pose writes'
print(json.dumps({'baseline':args.baseline,'metrics':results,'scope':'Deterministic API-double call counts, not Studio timing/FPS/energy'},indent=2))
