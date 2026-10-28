import pathlib,subprocess,sys,re,tempfile
from build import ROOT,bundle,client_bundle,module_bundle
luau=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/luau')
for p in sorted((ROOT/'src').glob('*.lua')):
 subprocess.run([str(luau/'luau-compile'),str(p)],stdout=subprocess.DEVNULL,check=True)
print('PASS all source Luau syntax checks')
subprocess.run([sys.executable,str(ROOT/'tests/ui_text.spec.py')],check=True)
subprocess.run([str(luau/'luau-analyze'),*[str(ROOT/'src'/f'{n}.lua') for n in ['Rules','Config','Profile','Cards','Persistence']]],check=True)
for name in ['feel','feedback','sentry','ui-layout','map-layout','rules','profile','cards','persistence','progression']:
 subprocess.run([str(luau/'luau'),str(ROOT/'tests'/f'{name}.spec.lua')],check=True)
f=ROOT/'tests/generated-server.spec.lua'
f.write_text((ROOT/'tests/mock-roblox.lua').read_text()+'\n'+bundle()+'\n'+(ROOT/'tests/server.integration.lua').read_text())
subprocess.run([str(luau/'luau-compile'),str(f)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(f)],check=True)
fern=ROOT/'tests/generated-world-fern.spec.lua'
fern.write_text((ROOT/'tests/mock-roblox.lua').read_text()+'\n'+(ROOT/'tests/world-fern.setup.lua').read_text()+'\n'+module_bundle(('Config','MapLayout','HarborLighting','World'))+'\n'+(ROOT/'tests/world-fern.integration.lua').read_text())
subprocess.run([str(luau/'luau-compile'),str(fern)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(fern)],check=True)
beam=ROOT/'tests/generated-beam.spec.lua'
beam.write_text((ROOT/'tests/mock-roblox.lua').read_text()+'\n'+module_bundle(('Feedback','SentryMotion','Presentation'))+'\n'+(ROOT/'tests/beam.integration.lua').read_text())
subprocess.run([str(luau/'luau-compile'),str(beam)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(beam)],check=True)
client=(ROOT/'src/Client.lua').read_text()
# Execute the actual client dispatch and input routing with command/GUI doubles.
select_drone=client[client.index('beginDroneSelection=function(d)'):client.index('cycleCandidate=function()',client.index('beginDroneSelection=function(d)'))]
cycle_candidate=client[client.index('cycleCandidate=function()'):client.index('submitCandidate=function()',client.index('cycleCandidate=function()'))]
field_name=client[client.index('local function fieldName(id)'):client.index("connect(gui.Parent:GetAttributeChangedSignal('MA_CommandState')")]
receipt=client[client.index("connect(gui.Parent:GetAttributeChangedSignal('MA_CommandState')"):client.index("connect(modal:GetPropertyChangedSignal('Visible')",client.index("connect(gui.Parent:GetAttributeChangedSignal('MA_CommandState')"))]
dispatch=client[client.index('local function queueFieldTimeout(request)'):client.index('local mouse=player:GetMouse()',client.index('local function queueFieldTimeout(request)'))]
input_handler=client[client.index('connect(UIS.InputBegan,function(input,processed)'):client.index('local hudClock=0',client.index('connect(UIS.InputBegan,function(input,processed)'))]
context_line=next(line.strip().split(';contextTitle',1)[0] for line in client.splitlines() if 'contextAction=function() requestField(id) end;contextTitle' in line)
intent=ROOT/'tests/generated-client-intent.spec.lua'
intent.write_text(module_bundle(('UILayout',))+'\n'+(ROOT/'tests/client-intent.setup.lua').read_text()+'\n'+select_drone+'\n'+cycle_candidate+'\n'+field_name+'\n'+receipt+'\n'+dispatch+'\nlocal function contextSelect(id) '+context_line+' end\n'+input_handler+'\n'+(ROOT/'tests/client-intent.integration.lua').read_text())
subprocess.run([str(luau/'luau-compile'),str(intent)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(intent)],check=True)
render=client[client.index('local function renderDrone(d,dt,now)'):client.index('connect(RunService.RenderStepped',client.index('local function renderDrone(d,dt,now)'))]
motion=ROOT/'tests/generated-motion.spec.lua'
motion.write_text((ROOT/'tests/mock-roblox.lua').read_text()+'\n'+module_bundle(('Feel',))+'\n'+(ROOT/'tests/motion-setup.lua').read_text()+'\n'+render+'\n'+(ROOT/'tests/motion.integration.lua').read_text())
subprocess.run([str(luau/'luau-compile'),str(motion)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(motion)],check=True)
server_motion=ROOT/'tests/generated-server-motion.spec.lua'
server_motion.write_text((ROOT/'tests/mock-roblox.lua').read_text()+'\n'+bundle()+'\n'+(ROOT/'tests/motion-setup.lua').read_text()+'\n'+render+'\n'+(ROOT/'tests/server-motion.integration.lua').read_text())
subprocess.run([str(luau/'luau-compile'),str(server_motion)],stdout=subprocess.DEVNULL,check=True)
subprocess.run([str(luau/'luau'),str(server_motion)],check=True)

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
