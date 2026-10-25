import pathlib,subprocess,sys,re,tempfile
from build import ROOT,bundle,client_bundle
luau=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/luau')
for p in sorted((ROOT/'src').glob('*.lua')):
 subprocess.run([str(luau/'luau-compile'),str(p)],stdout=subprocess.DEVNULL,check=True)
print('PASS all source Luau syntax checks')
subprocess.run([str(luau/'luau-analyze'),*[str(ROOT/'src'/f'{n}.lua') for n in ['Rules','Config','Profile','Cards','Persistence']]],check=True)
for name in ['feel','feedback','sentry','ui-layout','map-layout','rules','profile','cards','persistence','progression']:
 subprocess.run([str(luau/'luau'),str(ROOT/'tests'/f'{name}.spec.lua')],check=True)
f=ROOT/'tests/generated-server.spec.lua'
f.write_text((ROOT/'tests/mock-roblox.lua').read_text()+'\n'+bundle()+'\n'+(ROOT/'tests/server.integration.lua').read_text())
subprocess.run([str(luau/'luau-compile'),str(f)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(f)],check=True)

# Standalone Luau has no Roblox type definitions. Host bindings are explicitly any;
# this catches misspelled globals and normal lint errors, not API contract mistakes.
hosts=['game','workspace','Instance','Vector3','Vector2','CFrame','Color3','UDim2','UDim','TweenInfo','Enum','ColorSequence','NumberSequence','NumberSequenceKeypoint','NumberRange','RaycastParams','task','Random','typeof','warn','Region3']
with tempfile.TemporaryDirectory() as tmp:
 for name,source in [('server',bundle()),('client',client_bundle())]:
  used=[h for h in hosts if re.search(r'\b'+h+r'\b',source)]
  pre='\n'.join('local '+n+': any = nil' for n in used)+'\nlocal _hostBindings={'+','.join(used)+'}\n'
  path=pathlib.Path(tmp)/(name+'.lua');path.write_text(pre+source)
  result=subprocess.run([str(luau/'luau-analyze'),str(path)],capture_output=True,text=True)
  assert result.returncode==0 and not (result.stdout+result.stderr).strip(),result.stdout+result.stderr
print('PASS bundled server/client standalone lint with explicit any-typed Roblox host bindings (not API type validation)')
