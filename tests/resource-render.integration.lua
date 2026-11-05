-- Actual production renderResource against API doubles, not native profiling.
local source=Instance.new('Part');source.Parent=workspace
for key,value in pairs({FullSize=Vector3.one*3,FullPosition=Vector3.new(0,1.5,0),StartPosition=Vector3.zero,SpawnAt=0,ReadyAt=2,HP=300,MaxHP=300,Stage=0,StageCount=3,StageSeed=1,GroundY=0,Kind='Crystal'}) do source:SetAttribute(key,value) end
local record={source=source,view=source:Clone(),baseColor=source.Color,dirty=true,visual=Feel.newStagePresentation(0,false,0,3)}
record.view.Parent=workspace
local reads=0;local original=IM.GetAttribute
function IM:GetAttribute(key) if self==source then reads+=1 end;return original(self,key) end
source:GetAttributeChangedSignal('HP'):Connect(function()record.dirty=true end)
renderResource(record,0);assert(not record.settled)
renderResource(record,1);assert(not record.settled)
renderResource(record,2.1);assert(record.settled)
local before=reads
for frame=1,3600 do renderResource(record,2.1+frame/60) end
assert(reads==before,'mature unchanged rocks repeatedly read replicated attributes')
source:SetAttribute('HP',100);source:SetAttribute('Stage',2)
local initial=record.view.Size.X
renderResource(record,63);assert(not record.settled and not record.visual.scorched and record.view.Size.X==initial)
renderResource(record,63.035);assert(record.view.Size.X<initial and record.view.Size.X>initial*.75,'fracture snapped instead of settling')
for frame=1,30 do renderResource(record,63+frame/60) end
assert(record.settled and record.visual.stage==2 and #cues==2,'skipped or repeated settling stages')
source:SetAttribute('HP',0);source:SetAttribute('BreakSerial',1)
for frame=1,60 do renderResource(record,64+frame/60) end
assert(record.settled and record.visual.broken and record.view.Transparency==1)
assert(cues[#cues]=='break' and #cues==4,'break must occur exactly once after final fracture')
before=reads;for frame=1,3600 do renderResource(record,66+frame/60) end
assert(reads==before and #cues==4)
print('PASS production resource renderer: idle fast path, live HP invalidation, continuous shrink/break animation, no duplicate effects over 7200 stable frames')
