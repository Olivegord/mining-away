-- Actual production renderResource against API doubles, not native profiling.
local source=Instance.new('UnionOperation');source.Parent=workspace
for key,value in pairs({FullSize=Vector3.one*3,FullPosition=Vector3.new(0,1.5,0),StartPosition=Vector3.zero,SpawnAt=0,ReadyAt=2,HP=300,MaxHP=300,Stage=0,StageCount=3,StageSeed=1,GroundY=0,Kind='Crystal',CubicRock=false}) do source:SetAttribute(key,value) end
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
local orientation=record.view.CFrame.LookVector
renderResource(record,63)
assert(record.view.Size.X==initial and record.view.Color.R==0 and #cues==0,'crack changed size or played audio before the black flash')
renderResource(record,63.101)
assert(record.settled and record.view.Size.X==initial*.5 and record.view.Color.R==1,'layer loss did not snap and restore color')
assert((record.view.CFrame.LookVector-orientation).Magnitude>.2,'crystal did not change facing')
local snapped=record.view.CFrame.LookVector
local late={source=source,view=source:Clone(),baseColor=source.Color,dirty=true,visual=Feel.newStagePresentation(2,false,63,3)}
renderResource(late,63.101);assert((late.view.CFrame.LookVector-snapped).Magnitude<1e-8,'late observer got a different facing')
renderResource(record,63.135);assert(record.view.Size.X==initial*.5 and (record.view.CFrame.LookVector-snapped).Magnitude<1e-8,'rock changed between damage stages')
for frame=1,30 do renderResource(record,63.101+frame/60) end
assert(record.settled and record.visual.stage==2 and #cues==1,'one observed fracture replayed extra animations')
source:SetAttribute('HP',0);source:SetAttribute('BreakSerial',1)
for frame=1,60 do renderResource(record,64+frame/60) end
assert(record.settled and record.visual.broken and record.view.Transparency==1)
assert(cues[#cues]=='break' and #cues==2,'break must occur exactly once')
before=reads;for frame=1,3600 do renderResource(record,66+frame/60) end
assert(reads==before and #cues==2)
-- Every crack flashes black at the old size and then exposes a smaller red crystal.
local fixed=source:Clone()
fixed:SetAttribute('ReferenceCrystal',true)
fixed.Color=Color3.fromRGB(255,0,0)
fixed:SetAttribute('MaxHP',100);fixed:SetAttribute('HP',100);fixed:SetAttribute('Stage',0);fixed:SetAttribute('BreakSerial',0)
fixed:SetAttribute('SpawnAt',70);fixed:SetAttribute('ReadyAt',72)
local fixedRecord={source=fixed,view=fixed:Clone(),baseColor=fixed.Color,dirty=true,visual=Feel.newStagePresentation(0,false,70,3)}
renderResource(fixedRecord,70)
local originalSize=fixedRecord.view.Size
local originalDirection=fixedRecord.view.CFrame.LookVector
assert(originalSize.X==3 and fixedRecord.view.Color.R==1 and not fixedRecord.settled)
fixed:SetAttribute('HP',90);fixedRecord.dirty=true
renderResource(fixedRecord,72.5)
assert(fixedRecord.view.Color.R>0 and fixedRecord.view.Color.R<1 and fixedRecord.view.Size.X==3)
for stage,hp in ipairs({75,50,25}) do
 local at=72+stage
 local oldDirection=fixedRecord.view.CFrame.LookVector
 fixed:SetAttribute('HP',hp);fixed:SetAttribute('Stage',stage);fixedRecord.dirty=true
 renderResource(fixedRecord,at)
 renderResource(fixedRecord,at+.05)
 assert(fixedRecord.view.Color.R==0 and fixedRecord.view.Size.X==originalSize.X*(1-(stage-1)*.25))
 assert((fixedRecord.view.CFrame.LookVector-oldDirection).Magnitude<1e-8)
 renderResource(fixedRecord,at+.101)
 assert(fixedRecord.view.Size.X==originalSize.X*(1-stage*.25))
 assert(fixedRecord.view.Color.R==1 and fixedRecord.view.Transparency<1)
 if stage==1 then assert((fixedRecord.view.CFrame.LookVector-originalDirection).Magnitude>.2) end
end
local lateFixed={source=fixed,view=fixed:Clone(),baseColor=fixed.Color,dirty=true,visual=Feel.newStagePresentation(3,false,76,3)}
renderResource(lateFixed,76)
assert(lateFixed.view.Color.R==1 and lateFixed.view.Size.X==fixedRecord.view.Size.X and not lateFixed.visual.crackAt)
print('PASS production resource renderer: immediate size snaps, replicated stage turns, idle fast path and no duplicate effects over 7200 stable frames')
