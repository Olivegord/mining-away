-- FunFX runs against the API doubles: cube paint, per-frame step, confetti,
-- field motes and the color grade. Cosmetic only; not an engine visual check.
local root=Instance.new('Folder')
local view=Instance.new('Model')
local body=Instance.new('Part');body.Size=Vector3.one*3.4;body.CFrame=CFrame.new(0,10,0);body.Parent=view
local look=FunFX.paintCube(view,body,'3')
assert(look and look.color==FunFX.Palette[4],'numeric drone ids pick a stable palette color')
assert(body.Color==look.color,'hull takes the drone color')
assert(FunFX.colorFor('3')==FunFX.colorFor(3) and FunFX.colorFor('abc')==FunFX.colorFor('abc'),'colors are stable per id')
local seen={}
for id=1,8 do seen[FunFX.colorFor(id)]=true end
local distinct=0;for _ in pairs(seen) do distinct+=1 end
assert(distinct==8,'eight drones get eight different colors')
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
print('PASS FunFX cube colors, trail/sparkle step, confetti, field motes and color grade (API doubles)')
