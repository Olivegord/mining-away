#!/usr/bin/env python3
"""Run FunFX against the Roblox API doubles and compile both bundles; not engine QA."""
from pathlib import Path
import subprocess, sys, tempfile
from build import ROOT, bundle, client_bundle
luau=Path(sys.argv[1] if len(sys.argv)>1 else '/private/tmp/mining-away-luau')
mock=(ROOT/'tests/mock-roblox.lua').read_text()
fun='local NumberSequenceKeypoint=NumberSequenceKeypoint or {new=function(t,v) return {Time=t,Value=v} end}\nlocal FunFX=(function()\n'+(ROOT/'src/FunFX.lua').read_text()+'\nend)()\n'
with tempfile.TemporaryDirectory() as tmp:
 for name,code in {'client':client_bundle(),'server':bundle()}.items():
  path=Path(tmp)/(name+'.lua');path.write_text(code)
  subprocess.run([str(luau/'luau-compile'),str(path)],stdout=subprocess.DEVNULL,check=True)
 path=Path(tmp)/'fun.lua';path.write_text(mock+'\n'+fun+(ROOT/'tests/fun-fx.integration.lua').read_text())
 subprocess.run([str(luau/'luau'),str(path)],check=True)
