-- Run once in the reconciled shared Edit document after Script Sync. Only
-- static scenery is authored; this does not execute the server controller.
assert(game.PlaceId==124078027733625 and game.GameId==10774898335,'Wrong shared place')
assert(not game:GetService('RunService'):IsRunning(),'Stop Play before authoring scenery')
local root=assert(workspace:FindFirstChild('MiningAway'))
assert(root:GetAttribute('DronerevolutionMapVersion'),'Missing authored quarry')
assert(not root:GetAttribute('QuarrySceneryAuthored'),'Quarry already authored; edit the existing map')
local map=assert(root:FindFirstChild('Map'))
local fields=assert(root:FindFirstChild('Fields'))
local names={'QuarryLights','QuarryLanterns','RubyCrimsonBluffs','CobaltMushroomGrove','EmeraldChalkLagoon'}
for _,name in ipairs(names) do assert(not map:FindFirstChild(name),'Reconcile existing scenery: '..name) end

local controller=assert(game:GetService('ServerScriptService'):FindFirstChild('GlobalDroneControl'))
local source=game:GetService('ScriptEditorService'):GetEditorSource(controller)
assert(source:find("if scene.root:GetAttribute('QuarrySceneryAuthored') then return true end",1,true),'Sync the authored scenery guard first')
local function moduleSection(first,nextSection)
 local start=assert(source:find('\nlocal '..first..' = (function()\n',1,true),'Missing bundled '..first)
 local finish=assert(source:find('\nlocal '..nextSection..' = (function()\n',start+1,true),'Missing bundled '..nextSection)
 return source:sub(start,finish-1)
end
local code=moduleSection('Config','Feel')..moduleSection('Facets','NativeMeadow')
 ..moduleSection('World: any','Logistics')..'\nreturn {Config=Config,World=World}'

local history=game:GetService('ChangeHistoryService')
-- The Studio execution tool already owns an undo recording.
history:SetWaypoint('Before authored quarry scenery')
local temporary=Instance.new('ModuleScript');temporary.Name='TemporaryQuarryAuthoring'
local ok,report=pcall(function()
 temporary.Source=code;temporary.Parent=game:GetService('ServerStorage')
 local modules=require(temporary)
 local scene={root=root,map=map,converter=workspace:FindFirstChild('Converter'),fields={}}
 for id,cfg in ipairs(modules.Config.Fields) do
  local model=assert(fields:FindFirstChild(cfg.Key),cfg.Key)
  local part=assert(model:FindFirstChild('Field'),cfg.Key)
  scene.fields[id]={model=model,part=part,cfg=cfg,center=part.Position,frame=part.CFrame,size=part.Size,solid=part.CanCollide}
 end
 assert(modules.World.applyQuarryTextures(scene),'Scenery was not authored')
 for _,field in ipairs(scene.fields) do
  assert(field.part.CFrame==field.frame and field.part.Size==field.size and field.part.CanCollide==field.solid,'Mining field geometry changed')
 end
 local counts={}
 for _,name in ipairs(names) do counts[name]=#assert(map:FindFirstChild(name),name):GetDescendants();assert(counts[name]>0,name) end
 root:SetAttribute('QuarrySceneryAuthored',true)
 return counts
end)
temporary:Destroy()
assert(ok,report)
history:SetWaypoint('Authored quarry scenery')
return report
