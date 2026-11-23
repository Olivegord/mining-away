-- FunFX runs against the API doubles: cube paint, per-frame step, confetti,
-- field motes and the color grade. Cosmetic only; not an engine visual check.
local root=Instance.new('Folder')
local view=Instance.new('Model')
local body=Instance.new('Part');body.Size=Vector3.one*3.4;body.CFrame=CFrame.new(0,10,0);body.Parent=view
-- Owner, Nov 22: each drone TYPE looks different; every drone of a type
-- looks exactly the same (no per-drone palette color).
local function paint(id,role,primary)
 local v=Instance.new('Model')
 local b=Instance.new('Part');b.Name='Hull';b.Size=Vector3.one*3.4;b.CFrame=CFrame.new(0,10,0);b.Parent=v
 local l=FunFX.paintCube(v,b,id,primary,role)
 local names={}
 for _,c in ipairs(v:GetChildren()) do if string.sub(c.Name,1,4)=='Type' then table.insert(names,c.Name) end end
 table.sort(names)
 return l,b,table.concat(names,',')
end
local orange=Color3.fromRGB(255,159,24)
local a,ba,sa=paint('3','Striker',orange)
local b2,bb,sb=paint('97','Striker',orange)
local function same(x,y) return math.abs(x.X-y.X)+math.abs(x.Y-y.Y)+math.abs(x.Z-y.Z)<1e-9 end
assert(same(a.accent,b2.accent) and same(ba.Color,bb.Color) and same(ba.Size,bb.Size) and sa==sb,'two drones of one type look exactly the same')
assert(sa~='','a type has its own parts: '..sa)
local roles={'Striker','Charger','Ballcaster','Needler','Bubbler','Halver','Gridcutter','Singularity','Starforge','Frostbite','Resonator','Ramiel','Nomad','Lancer'}
local shapes,accents={},{}
for i,role in ipairs(roles) do
 assert(FunFX.LOOKS[role],'a look for '..role)
 local v=Instance.new('Model');local b=Instance.new('Part');b.Size=Vector3.one*3.4;b.CFrame=CFrame.new(0,10,0);b.Parent=v
 FunFX.LOOKS[role](v,b,orange,orange)  -- called directly: errors surface here
 local l,_,silhouette=paint(tostring(i),role,orange)
 assert(silhouette~='','parts for '..role)
 assert(not shapes[silhouette],role..' shares a silhouette with '..tostring(shapes[silhouette]))
 shapes[silhouette]=role
 accents[role]=l.accent
end
local look,_,_=paint('3',nil,nil)
assert(look.accent and look.color,'an unknown type still paints')
FunFX.stepCube(look,20,false,false,1)
assert(look.trail.Enabled and look.motes.Rate==0,'cruising shows the trail without mining sparkles')
FunFX.stepCube(look,0,true,false,1.1)
assert(not look.trail.Enabled and look.motes.Rate>0,'mining sheds sparkles and drops the trail')
FunFX.stepCube(look,30,true,true,1.2)
assert(not look.trail.Enabled and look.motes.Rate==0 and look.light.Brightness==0,'hidden drones show nothing')
assert(FunFX.mineralColor('RunRuby')==FunFX.ZoneColors[2] and FunFX.mineralColor('Nope')==nil)
local cleanup=nil;local spawn=task.spawn;task.spawn=function(f) cleanup=f end
FunFX.confetti(root,Vector3.new(0,1,0),FunFX.ZoneColors[1],1.5)
task.spawn=spawn
local pop=root:FindFirstChild('FunConfetti')
local emitted=0
for _,child in ipairs(pop and pop:GetChildren() or {}) do emitted+=child.Emitted or 0 end
assert(emitted>=30,'a break throws a visible confetti burst')
assert(cleanup);cleanup();assert(root:FindFirstChild('FunConfetti')==nil,'the burst cleans itself up')
FunFX.colorPop();FunFX.colorPop()
local map=Instance.new('Folder');map.Name='Map'
local world=Instance.new('Folder');map.Parent=world
local run=Instance.new('Folder');run.Name='CrystalRun';run:SetAttribute('WholeFields',true);run.Parent=map
local model=Instance.new('Model');model.Parent=run
local field=Instance.new('Part');field.Name='Field';field.Size=Vector3.new(32,1,32);field:SetAttribute('CrystalZone',3);field.Parent=model
FunFX.fieldMotes(root,world)
assert(FunFX.motesReady,'square fields get motes')
print('PASS FunFX one look per drone type (same type identical, 14 distinct silhouettes), trail/sparkle step, confetti, field motes and color grade (API doubles)')
